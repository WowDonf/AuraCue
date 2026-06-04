-- =====================================================================
-- AuraCue - Core
-- =====================================================================
-- Aura cue layer for World of Warcraft: Midnight (12.x).
-- Translates the player's OWN auras into configurable cues — a sound,
-- spoken name, and/or an on-screen flash — for proc alerts, missing-buff
-- reminders, and debuff warnings.
--
-- DESIGN CONSTRAINT (Midnight "Secret Values"). Inside raid encounters,
-- M+, and PvP the client masks combat data from addons: tainted code may
-- not read, compare, or do arithmetic on a "secret" value. The player's
-- OWN auras and casts are explicitly NON-secret, so AuraCue deliberately
-- stays on the safe side of that wall by tracking only player-owned data.
-- Every value that *could* ever be secret is still routed through
-- IsSecret() / Reveal() so a later enemy/whitelist phase can extend the
-- engine without risking "attempt to perform arithmetic on a secret
-- value" errors. The full API feasibility map lives in the project notes.
-- =====================================================================

local addonName, ns = ...
ns.addonName = addonName

-- Chat helper: prefixes addon-originated lines with a teal [AuraCue] tag.
-- Use for prefixed lines; raw print() for indented continuation lines.
local function chatPrint(msg)
    print("|cff33ddbb[AuraCue]|r " .. msg)
end
ns.chatPrint = chatPrint

-- ---------------------------------------------------------------------
-- Secret-value safety (Midnight 12.0+)
-- ---------------------------------------------------------------------
-- issecretvalue() exists only on clients running the secret-values
-- regime; it's nil on older builds, where nothing is secret. Never test
-- or read a possibly-secret value except through these two helpers.
local issecret = _G.issecretvalue
local function IsSecret(v)
    if issecret then return issecret(v) end
    return false
end
ns.IsSecret = IsSecret

-- Return v if it is safe to read, otherwise `fallback`. Guards every
-- field we pull off an aura/cast payload.
local function Reveal(v, fallback)
    if v == nil or IsSecret(v) then return fallback end
    return v
end
ns.Reveal = Reveal

-- ---------------------------------------------------------------------
-- Storage model:
--   AuraCueDB (account-wide) = {
--     seen     = { ... },                  -- WoW-wide catalog of observed auras
--     profiles = { [key] = PROFILE, ... }, -- per-character tracked settings
--   }
-- The catalog is shared across all characters; tracked settings (cues,
-- windows, channel, toggles) live in a per-character profile. Per-spec
-- profiles + import/export build on this in a later step.
-- ---------------------------------------------------------------------

-- Defaults for one profile (the personal, per-character settings).
local PROFILE_DEFAULTS = {
    enabled = true,
    channel = "Master",          -- default audio channel for cues
    audioEnabled = true,         -- master switch for sound cues
    trackBuffs = true,           -- fire cues for helpful auras
    trackDebuffs = true,         -- fire cues for harmful auras
    combineByName = false,       -- treat every same-named aura as one alert
    ttsRate = 0,                 -- text-to-speech rate (-10..10)
    ttsVolume = 100,             -- text-to-speech volume (0..100)
    ttsVoice = nil,              -- chosen TTS voice id (nil = first available)
    -- Separate on-screen window per kind, so buffs and debuffs can have
    -- their own size / position / color / duration.
    visual = {
        buff = {
            enabled   = true,
            color      = { r = 0.20, g = 0.86, b = 0.75 },   -- gained: teal
            colorFaded = { r = 0.45, g = 0.55, b = 0.70 },   -- faded: muted blue-gray
            scale     = 1.0,
            duration  = 1.5,
            locked    = true,
            position  = nil,      -- { point, relativePoint, x, y }
            edgeFlash = false,    -- also flash the screen edges
            edgeThickness = 160,  -- how far the glow reaches inward (px)
            edgeIntensity = 0.7,  -- peak opacity of the glow (0..1)
        },
        debuff = {
            enabled   = true,
            color      = { r = 1.00, g = 0.45, b = 0.30 },   -- gained: warm red-orange
            colorFaded = { r = 0.65, g = 0.40, b = 0.55 },   -- faded: muted mauve
            scale     = 1.2,
            duration  = 2.0,
            locked    = true,
            position  = nil,
            edgeFlash = false,
            edgeThickness = 200,
            edgeIntensity = 0.8,
        },
    },
    -- Watched auras, keyed by spellID-as-string -> cue config.
    cues = {},
}

-- Defaults for the account-wide DB.
local DB_DEFAULTS = {
    -- Registry of auras observed on the player, keyed by spellID-as-string
    -- -> { name, icon, kind, dungeon, source }. Account-wide (WoW-wide) so
    -- it accumulates across every character and can be shared.
    seen = {},
    profiles = {},
    -- Spell IDs the player has been seen to cast (account-wide). Used to mark
    -- catalog auras as cast-trackable (i.e. they work in instances).
    castable = {},
    -- Spell IDs the player chose to hide from the picker (account-wide), so the
    -- catalog can be pruned of toys / food / world buffs and other clutter.
    ignored = {},
    -- Custom picker group labels, keyed by spellID-as-string -> name. These
    -- override the automatic buckets so you can file auras under your own
    -- headings ("Druid CDs", "World buffs", ...). Account-wide.
    groups = {},
    -- LibDBIcon's button state (position + hide); account-wide.
    minimap = { hide = false },
}

-- The active profile (resolved on login). All tracked-setting reads go
-- through this; `AuraCueDB.seen` stays account-wide.
local activeProfile
local function P() return activeProfile end
ns.P = P

-- The spec/spellbook query globals were deprecated in 11.2.0 and moved into
-- C_SpecializationInfo / C_SpellBook. Prefer the namespaced form; fall back to
-- the old global so the addon also runs on pre-11.2 clients.
local GetSpec     = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo

-- "Does the player know this spell?"  C_SpellBook.IsSpellKnown alone is too
-- strict: it returns false for passive talents and for any spell that
-- overrides a base spell, which is most class abilities. IsPlayerSpell is the
-- broad, correct check ("can cast this, or something that overrides it"), so
-- prefer it and fall back through the namespaced variants for robustness.
local function SpellKnown(id)
    if not id then return false end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    local cb = C_SpellBook
    if cb then
        if cb.IsSpellKnownOrOverridesKnown and cb.IsSpellKnownOrOverridesKnown(id) then return true end
        if cb.IsSpellKnown and cb.IsSpellKnown(id) then return true end
    end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

-- Profile keys. CharKey identifies the character; ProfileKey adds the
-- current specialization, so each spec keeps its own tracked auras and
-- window setup.
local function CharKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Realm")
end

local function CurrentSpecID()
    local idx = GetSpec and GetSpec()
    if idx then
        local id = GetSpecInfo and GetSpecInfo(idx)
        if id then return id end
    end
    return 0   -- no spec yet (low level) or API missing
end

local function ProfileKey()
    return CharKey() .. "|" .. CurrentSpecID()
end

function ns.CurrentSpecName()
    local idx = GetSpec and GetSpec()
    if idx and GetSpecInfo then
        local _, name = GetSpecInfo(idx)
        if name then return name end
    end
    return "No spec"
end

-- Deep-merge defaults into the saved table without clobbering user
-- values; type mismatches (corrupt SV) fall back to the default. The
-- user-owned `cues` map is left untouched (defaults.cues is empty).
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        local defaultType = type(v)
        local savedType = type(target[k])
        if defaultType == "table" then
            if savedType ~= "table" then target[k] = {} end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        elseif savedType ~= defaultType then
            target[k] = v
        end
    end
    return target
end

-- Migrate the pre-v0.8 single `visual` table into per-kind buff/debuff
-- windows, carrying the old settings into both. No-op once migrated.
local function MigrateVisual(db)
    local v = db.visual
    if type(v) == "table" and v.enabled ~= nil and v.buff == nil then
        local function clone()
            local c = v.color
            return {
                enabled  = v.enabled,
                scale    = v.scale,
                duration = v.duration,
                locked   = (v.locked ~= false),
                color    = (type(c) == "table") and { r = c.r, g = c.g, b = c.b } or nil,
                position = (type(v.position) == "table") and {
                    point = v.position.point, relativePoint = v.position.relativePoint,
                    x = v.position.x, y = v.position.y,
                } or nil,
            }
        end
        db.visual = { buff = clone(), debuff = clone() }
    end
end
ns.MigrateVisual = MigrateVisual

local DEFAULT_COLORS = {
    buff   = { r = 0.20, g = 0.86, b = 0.75 },
    debuff = { r = 1.00, g = 0.45, b = 0.30 },
}
local DEFAULT_COLORS_FADED = {
    buff   = { r = 0.45, g = 0.55, b = 0.70 },
    debuff = { r = 0.65, g = 0.40, b = 0.55 },
}

-- Clamp/heal one {r,g,b} field on `v` against a default, returning the table.
local function HealColor(v, field, dc)
    local c = v[field]
    if type(c) ~= "table" then
        v[field] = { r = dc.r, g = dc.g, b = dc.b }
    else
        c.r = (type(c.r) == "number") and math.max(0, math.min(1, c.r)) or dc.r
        c.g = (type(c.g) == "number") and math.max(0, math.min(1, c.g)) or dc.g
        c.b = (type(c.b) == "number") and math.max(0, math.min(1, c.b)) or dc.b
    end
    return v[field]
end

local function ValidateRanges(db)
    if type(db.visual) ~= "table" then db.visual = {} end
    for _, key in ipairs({ "buff", "debuff" }) do
        local v = db.visual[key]
        if type(v) ~= "table" then v = {}; db.visual[key] = v end

        if type(v.scale) ~= "number" then v.scale = 1.0 end
        v.scale = math.max(0.5, math.min(3.0, v.scale))

        if type(v.duration) ~= "number" then v.duration = (key == "debuff") and 2.0 or 1.5 end
        v.duration = math.max(0.5, math.min(8.0, v.duration))

        if type(v.edgeThickness) ~= "number" then v.edgeThickness = 160 end
        v.edgeThickness = math.max(40, math.min(500, v.edgeThickness))

        if type(v.edgeIntensity) ~= "number" then v.edgeIntensity = 0.7 end
        v.edgeIntensity = math.max(0.1, math.min(1.0, v.edgeIntensity))

        HealColor(v, "color", DEFAULT_COLORS[key])
        HealColor(v, "colorFaded", DEFAULT_COLORS_FADED[key])
    end

    local validChannel = false
    for _, ch in ipairs(ns.CHANNELS) do
        if db.channel == ch then validChannel = true; break end
    end
    if not validChannel then db.channel = "Master" end
end
ns.ValidateRanges = ValidateRanges

-- ---------------------------------------------------------------------
-- Bundled sound choices.
-- v0 uses built-in SOUNDKIT entries so the addon ships with zero audio
-- assets and loads everywhere. Distinct custom .ogg cues come in a later
-- phase via tools/. `key` is the stable DB value.
-- ---------------------------------------------------------------------
-- Bundled cue tones (generated by tools/make_sounds.py), chosen to be easy
-- to tell apart by ear. `key` is the stable DB value; `file` is the shipped
-- .mp3 under Sounds/.
ns.SOUNDS = {
    { key = "speak",  label = "Speak the name (TTS)" },   -- special: text-to-speech
    { key = "rise",   label = "Rise (two-tone up)",   file = "Interface\\AddOns\\AuraCue\\Sounds\\rise.mp3" },
    { key = "fall",   label = "Fall (two-tone down)", file = "Interface\\AddOns\\AuraCue\\Sounds\\fall.mp3" },
    { key = "ping",   label = "Ping (high)",          file = "Interface\\AddOns\\AuraCue\\Sounds\\ping.mp3" },
    { key = "beep",   label = "Beep (mid)",           file = "Interface\\AddOns\\AuraCue\\Sounds\\beep.mp3" },
    { key = "double", label = "Double beep",          file = "Interface\\AddOns\\AuraCue\\Sounds\\double.mp3" },
    { key = "triple", label = "Triple beep",          file = "Interface\\AddOns\\AuraCue\\Sounds\\triple.mp3" },
    { key = "chirp",  label = "Chirp (sweep up)",     file = "Interface\\AddOns\\AuraCue\\Sounds\\chirp.mp3" },
    { key = "thud",   label = "Thud (low)",           file = "Interface\\AddOns\\AuraCue\\Sounds\\thud.mp3" },
}

ns.CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog" }

-- Resolve a sound key to (playable, isFile): a SOUNDKIT numeric id, or a
-- file path for future bundled .ogg cues.
local function ResolveSound(key)
    if not key then return nil, false end
    for _, e in ipairs(ns.SOUNDS) do
        if e.key == key then
            if e.file then return e.file, true end
            if e.kit  then return SOUNDKIT[e.kit], false end
            return nil, false
        end
    end
    return nil, false
end

local function PlaySoundEntry(key, channel)
    local playable, isFile = ResolveSound(key)
    if not playable then return false end
    if isFile then
        return (PlaySoundFile(playable, channel or "Master"))
    end
    return (PlaySound(playable, channel or "Master"))
end
ns.PlaySoundEntry = PlaySoundEntry

-- ---------------------------------------------------------------------
-- Visual overlay frames (non-secure: combat lockdown doesn't touch them).
-- One per kind — buffs and debuffs each get their own movable, sizable,
-- colorable window. A frame's fade state lives on the frame itself.
-- ---------------------------------------------------------------------
local REPOSITION_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

local overlays = {}

-- The per-kind visual config table (buff/debuff). Normalizes anything that
-- isn't "debuff" to "buff".
local function VisCfg(kind)
    return activeProfile.visual[kind == "debuff" and "debuff" or "buff"]
end
ns.VisCfg = VisCfg

local function MakeOverlay(kind)
    local suffix = (kind == "debuff") and "Debuff" or "Buff"
    local f = CreateFrame("Frame", "AuraCueOverlay" .. suffix, UIParent, "BackdropTemplate")
    f.kind = kind
    f:SetSize(560, 90)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    f:EnableMouse(false)        -- click-through until reposition turns it on
    f:SetMovable(true)
    f:Hide()
    f.fadeElapsed, f.fadeDuration = 0, 0

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.text:SetAllPoints()
    f.text:SetJustifyH("CENTER")
    f.text:SetJustifyV("MIDDLE")

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if activeProfile and not VisCfg(self.kind).locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        VisCfg(self.kind).position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetSize(28, 28)
    f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 4, 4)
    f.closeBtn:Hide()
    f.closeBtn:SetScript("OnClick", function()
        ns.SetRepositionMode(f.kind, false)
        ns.OpenOptions()
    end)

    -- Hold full alpha for the first 60% of the duration, then fade out.
    f:SetScript("OnUpdate", function(self, dt)
        if self.fadeDuration <= 0 then return end
        self.fadeElapsed = self.fadeElapsed + dt
        local fadeStart = self.fadeDuration * 0.6
        if self.fadeElapsed >= self.fadeDuration then
            self.fadeDuration = 0
            self:SetAlpha(0)
            self:Hide()
        elseif self.fadeElapsed <= fadeStart then
            self:SetAlpha(1)
        else
            self:SetAlpha((self.fadeDuration - self.fadeElapsed) / (self.fadeDuration - fadeStart))
        end
    end)

    overlays[kind] = f
    return f
end

local function RestorePosition(kind)
    local f = overlays[kind]
    f:ClearAllPoints()
    local p = activeProfile and VisCfg(kind).position
    if p and p.point then
        f:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, (kind == "debuff") and 40 or 160)
    end
end
ns.RestorePosition = RestorePosition

-- Optional full-screen edge glow, shared by both kinds. Built from four
-- gradient strips we color ourselves (edge -> transparent inward), so the
-- glow is EXACTLY the cue/text colour — not tinted by a baked-in texture.
-- Click-through; the whole frame's alpha is faded out.
local edge = CreateFrame("Frame", "AuraCueEdge", UIParent)
edge:SetAllPoints(UIParent)
edge:SetFrameStrata("FULLSCREEN_DIALOG")
edge:EnableMouse(false)
edge:Hide()

local function MkStrip() local t = edge:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(1, 1, 1, 1); return t end
local eL, eR, eT, eB = MkStrip(), MkStrip(), MkStrip(), MkStrip()
eL:SetPoint("TOPLEFT");     eL:SetPoint("BOTTOMLEFT");     eL:SetWidth(160)
eR:SetPoint("TOPRIGHT");    eR:SetPoint("BOTTOMRIGHT");    eR:SetWidth(160)
eT:SetPoint("TOPLEFT");     eT:SetPoint("TOPRIGHT");       eT:SetHeight(120)
eB:SetPoint("BOTTOMLEFT");  eB:SetPoint("BOTTOMRIGHT");    eB:SetHeight(120)

edge.fadeElapsed, edge.fadeDuration = 0, 0
edge:SetScript("OnUpdate", function(self, dt)
    if self.fadeDuration <= 0 then return end
    self.fadeElapsed = self.fadeElapsed + dt
    local remain = self.fadeDuration - self.fadeElapsed
    if remain <= 0 then
        self.fadeDuration = 0
        self:Hide()
    else
        self:SetAlpha(remain / self.fadeDuration)
    end
end)

local function ShowEdge(color, duration, intensity, thickness)
    local r, g, b = color.r, color.g, color.b
    local A = intensity or 0.7
    local th = thickness or 160
    eL:SetWidth(th); eR:SetWidth(th); eT:SetHeight(th); eB:SetHeight(th)
    local solid, clear = CreateColor(r, g, b, A), CreateColor(r, g, b, 0)
    eL:SetGradient("HORIZONTAL", solid, clear)   -- bright at left edge, fading right
    eR:SetGradient("HORIZONTAL", clear, solid)   -- bright at right edge
    eT:SetGradient("VERTICAL",   clear, solid)   -- bright at top
    eB:SetGradient("VERTICAL",   solid, clear)   -- bright at bottom
    edge:SetAlpha(1)
    edge.fadeElapsed, edge.fadeDuration = 0, (duration or 1.0)
    edge:Show()
end

-- The flash uses a different color for "gained" vs "faded" so the two
-- events read distinctly. Pre-colorFaded configs fall back to `color`.
local function VisColor(v, eventKind)
    if eventKind == "faded" and v.colorFaded then return v.colorFaded end
    return v.color
end

local function ShowVisual(kind, message, eventKind)
    local f = overlays[kind]
    local v = VisCfg(kind)
    local c = VisColor(v, eventKind)
    f.text:SetText(message)
    f.text:SetTextColor(c.r, c.g, c.b)
    f:SetScale(v.scale or 1.0)
    f:SetAlpha(1)
    f.fadeElapsed, f.fadeDuration = 0, (v.duration or 1.5)
    f:Show()
    if v.edgeFlash then ShowEdge(c, v.duration, v.edgeIntensity, v.edgeThickness) end
end
ns.ShowVisual = ShowVisual

-- Reposition / preview mode for one kind's window: pins it open and
-- mouse-interactive so it can be dragged, then re-locks on exit.
function ns.SetRepositionMode(kind, on)
    local f = overlays[kind]
    local v = VisCfg(kind)
    ns.testMode = on and kind or nil
    if on then
        v.locked = false
        f.fadeDuration = 0
        f:SetBackdrop(REPOSITION_BACKDROP)
        f:SetBackdropColor(0, 0, 0, 0.6)
        f:SetBackdropBorderColor(v.color.r, v.color.g, v.color.b, 1)
        f:EnableMouse(true)
        f.text:SetText("AuraCue " .. (kind == "debuff" and "debuffs" or "buffs") .. " — drag to move, X to close")
        f.text:SetTextColor(v.color.r, v.color.g, v.color.b)
        f:SetScale(v.scale or 1.0)
        f:SetAlpha(1)
        RestorePosition(kind)
        f.closeBtn:Show()
        f:Show()
    else
        v.locked = true
        f.closeBtn:Hide()
        f:SetBackdrop(nil)
        f:EnableMouse(false)
        f.fadeDuration = 0
        f:Hide()
    end
end

MakeOverlay("buff")
MakeOverlay("debuff")

-- ---------------------------------------------------------------------
-- Text-to-speech
-- ---------------------------------------------------------------------
local ttsVoiceCached
local function DefaultTtsVoice()
    if ttsVoiceCached ~= nil then return ttsVoiceCached end
    ttsVoiceCached = false
    local C = C_VoiceChat
    if C and C.GetTtsVoices then
        local voices = C.GetTtsVoices()
        if voices and voices[1] then ttsVoiceCached = voices[1].voiceID end
    end
    return ttsVoiceCached
end
ns.GetTtsVoices = function()
    local C = C_VoiceChat
    return (C and C.GetTtsVoices and C.GetTtsVoices()) or {}
end

function ns.Speak(text)
    local C = C_VoiceChat
    if not (C and C.SpeakText) or not text then return end
    local p = activeProfile or {}
    local voice = p.ttsVoice or DefaultTtsVoice()
    if not voice then return end
    -- 12.0.0 dropped the `destination` argument: SpeakText(voiceID, text, rate, volume[, overlap]).
    pcall(C.SpeakText, voice, text, p.ttsRate or 0, p.ttsVolume or 100)
end

-- Play a cue's sound key, or speak `text` if the key is the special "speak".
local function PlayOrSpeak(snd, channel, text)
    if not snd then return end
    if snd == "speak" then ns.Speak(text) else PlaySoundEntry(snd, channel) end
end

-- ---------------------------------------------------------------------
-- Cue dispatch
-- ---------------------------------------------------------------------
-- Per-cue "when" condition: always / only in combat / only in instances /
-- only in the open world.
local function ConditionMet(when)
    if when == "combat" then return InCombatLockdown() and true or false
    elseif when == "instance" then return (IsInInstance()) and true or false
    elseif when == "world" then return not IsInInstance()
    end
    return true
end
ns.ConditionMet = ConditionMet

local function FireCue(cue, spellName, eventKind)
    if not ConditionMet(cue.when) then return end
    -- Respect the per-kind master switches (buffs vs debuffs).
    if cue.kind == "debuff" then
        if not activeProfile.trackDebuffs then return end
    elseif not activeProfile.trackBuffs then
        return
    end
    local verb = (eventKind == "applied") and "gained" or "faded"
    local label = cue.label or spellName or "Aura"
    local snd = (eventKind == "applied") and cue.soundApplied or cue.soundFaded
    if activeProfile.audioEnabled and snd then
        PlayOrSpeak(snd, cue.channel or activeProfile.channel, label .. " " .. verb)
    end
    local kind = (cue.kind == "debuff") and "debuff" or "buff"
    if cue.visual and VisCfg(kind).enabled and not ns.testMode then
        ShowVisual(kind, label .. " " .. verb, eventKind)
    end
end

-- Preview one cue's gained-or-faded event exactly as it would fire: that
-- event's sound (if any) and, when the cue's visual is on, a flash on its
-- kind's window. Used by the per-row test buttons. Ignores the per-kind
-- window "enabled" toggle so a test always shows something.
function ns.PreviewCue(spellKey, eventKind)
    local cue = activeProfile.cues[spellKey]
    if not cue then return end
    eventKind = (eventKind == "faded") and "faded" or "applied"
    local snd = (eventKind == "applied") and cue.soundApplied or cue.soundFaded
    local verb = (eventKind == "faded") and "faded" or "gained"
    PlayOrSpeak(snd, cue.channel or activeProfile.channel, (cue.label or "Aura") .. " " .. verb)
    if cue.visual then
        local kind = (cue.kind == "debuff") and "debuff" or "buff"
        ShowVisual(kind, (cue.label or "Aura") .. " " .. (eventKind == "faded" and "faded" or "gained"), eventKind)
    end
end

-- Preview a whole kind's window (test button under each tab).
function ns.TestWindow(kind)
    kind = (kind == "debuff") and "debuff" or "buff"
    PlaySoundEntry("rise", activeProfile.channel)
    ShowVisual(kind, (kind == "debuff" and "Debuff" or "Buff") .. " test")
end

-- General test (/cue test, Audio panel button): a sound plus a flash on
-- both windows so you can see where each one sits.
function ns.PlayTestCue()
    PlaySoundEntry("rise", activeProfile.channel)
    ShowVisual("buff", "Buff test")
    ShowVisual("debuff", "Debuff test")
end

-- ---------------------------------------------------------------------
-- Player aura tracking engine
-- ---------------------------------------------------------------------
-- `present` is the set of watched spellIDs currently on the player. On
-- every UNIT_AURA we rescan and diff: newly-present -> "applied",
-- newly-absent -> "faded". A full rescan (vs. parsing UNIT_AURA's
-- incremental updateInfo) is simpler and plenty fast for a small watch
-- list, and is robust to refreshes and stack changes.
local present = {}
local castFade = {}      -- spellID -> token, for cast-driven faded timers
local lastGained = {}    -- spellID -> GetTime() of last fired "gained" (debounce)
local castConfirmed = {} -- spellID -> true once a read has seen the cast aura up
local aliasOwner = {}    -- alt-spellID-as-string -> primary cue key (one alert,
                         -- many trigger ids, e.g. base + proc Avenging Wrath)
local cueAlts = {}       -- primary cue key -> merged list of alt ids (the cue's
                         -- hand-added ids plus, if matchName, same-named catalog
                         -- ids). Runtime-only; rebuilt by RebuildAliases.

-- Record an aura we've seen on the player into the registry the picker
-- draws from. Only the first sighting matters; later sightings are cheap
-- no-ops. Name/icon are Reveal-guarded (non-secret for player auras).
-- Localized instance name if we're in one, else nil. Not secret.
-- Accepts any PvE instance — dungeons, raids, scenarios, AND Delves (which
-- ride the scenario tech and may report "scenario" or a delve-specific
-- type depending on the patch). Excludes the open world and PvP.
local function CurrentDungeon()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType ~= "none" and instanceType ~= "pvp" and instanceType ~= "arena" then
        return (GetInstanceInfo())   -- first return is the instance name
    end
    return nil
end

-- Best-effort source mob name. The aura's sourceUnit is frequently a
-- secret value in instanced content, so this is often nil exactly where
-- dungeon debuffs occur; fall back to the current target for harmful
-- auras (a heuristic — you're usually targeting what's debuffing you).
local function ResolveSource(data, harmful)
    local src = Reveal(data.sourceUnit)
    if src and UnitExists(src) then
        local n = Reveal(UnitName(src))
        if n then return n end
    end
    if harmful and UnitExists("target") then
        return Reveal(UnitName("target"))
    end
    return nil
end

local function RecordSeen(sid, data)
    if not AuraCueDB.seen then AuraCueDB.seen = {} end
    local key = tostring(sid)
    local harmful = Reveal(data.isHarmful) and true or false
    -- isFromPlayerOrPlayerPet is a never-secret field: it tells us the aura
    -- was applied by the player (or pet), i.e. "cast by myself".
    local mine = Reveal(data.isFromPlayerOrPlayerPet) and true or false
    -- A boss aura is a harmful aura a boss applied to YOU — so it can't be one
    -- of your own auras, and it's never a buff. Gating on (harmful and not
    -- mine) stops self-buffs/passives (e.g. a Shaman's Reincarnation) being
    -- mislabelled as boss debuffs just because the raw flag was set.
    local boss = (Reveal(data.isBossAura) and harmful and not mine) and true or false
    -- Permanent auras report a 0 duration; anything else is timed.
    local permanent = (Reveal(data.duration) or 0) == 0
    -- Whether the game tags this aura as relevant to a combat role.
    local roleAura = (Reveal(data.isDPSRoleAura) or Reveal(data.isHealerRoleAura)
        or Reveal(data.isTankRoleAura)) and true or false
    -- Your class, for an aura that's one of your own known spells (not a
    -- mount). This is what files Avenging Wrath etc. under "Paladin" — and it
    -- works whether the ability was cast or procced, since it's derived from
    -- the aura, not from a cast event.
    local GM = C_MountJournal and C_MountJournal.GetMountFromSpell
    local className = (mine and SpellKnown and SpellKnown(sid) and not (GM and GM(sid)))
        and (UnitClass("player")) or nil
    local existing = AuraCueDB.seen[key]
    if existing then
        -- Backfill provenance we couldn't capture on first sighting (e.g.
        -- first seen in the open world, later re-seen inside a dungeon).
        if not existing.dungeon then existing.dungeon = CurrentDungeon() end
        if not existing.source then existing.source = ResolveSource(data, harmful) end
        if existing.mine == nil then existing.mine = mine end
        if boss and not existing.boss then existing.boss = true end
        -- Self-heal a wrong boss flag if we now see it's yours or not harmful.
        if existing.boss and (mine or not harmful) then existing.boss = false end
        if existing.permanent == nil then existing.permanent = permanent end
        if roleAura and not existing.roleAura then existing.roleAura = true end
        if className and not existing.className then existing.className = className end
        return
    end
    AuraCueDB.seen[key] = {
        name    = Reveal(data.name) or C_Spell.GetSpellName(sid),
        icon    = Reveal(data.icon),
        kind    = harmful and "debuff" or "buff",
        dungeon = CurrentDungeon(),
        source  = ResolveSource(data, harmful),
        mine    = mine,
        boss    = boss,
        permanent = permanent,
        roleAura  = roleAura,
        className = className,
    }
end

-- Presence test for ONE watched aura, by its known spell ID. We query the
-- ID we already have rather than reading spellIds off the aura list, because
-- in combat those spellIds are secret values — reading them fails, which made
-- every watched aura look "faded" the moment combat started. Querying a known
-- ID is the sanctioned path and works in and out of combat.
local GetPlayerAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID

-- Read one watched aura's state by its known id: "present", "absent", or
-- "unknown" (the read came back masked / secret). Querying a known id is the
-- sanctioned path, but the game can still hide the result in combat.
local function ReadAura(sid)
    if not sid then return "absent" end
    if GetPlayerAura then
        local a = GetPlayerAura(sid)
        if a == nil then return "absent" end
        if IsSecret(a) then return "unknown", a end
        return "present", a
    end
    -- Fallback for clients without the API (reads spellIds; out-of-combat only).
    local found = false
    local function h(data)
        if data and Reveal(data.spellId) == sid then found = true; return true end
        return false
    end
    AuraUtil.ForEachAura("player", "HELPFUL", nil, h, true)
    if not found then AuraUtil.ForEachAura("player", "HARMFUL", nil, h, true) end
    return found and "present" or "absent"
end
ns.ReadAura = ReadAura

-- Catalogue auras currently readable on the player (for the picker). This
-- still reads spellIds, so it's best-effort and mostly fills out of combat;
-- it does NOT drive cues.
local function CatalogVisibleAuras()
    local function handle(data)
        if not data then return false end
        local sid = Reveal(data.spellId)
        if sid then RecordSeen(sid, data) end
        return false
    end
    AuraUtil.ForEachAura("player", "HELPFUL", nil, handle, true)
    AuraUtil.ForEachAura("player", "HARMFUL", nil, handle, true)
end

-- Combined read across a primary id and a list of alias ids: "present" if any
-- is up, "unknown" if a read was masked and none were up, else "absent". This
-- is what lets one alert cover several spell ids (base + proc versions).
local function CueRead(sid, alts)
    local state, data = ReadAura(sid)
    if state == "present" then return state, data end
    local best = state
    if alts then
        for _, alt in ipairs(alts) do
            local s, d = ReadAura(alt)
            if s == "present" then return "present", d end
            if s == "unknown" then best = "unknown" end
        end
    end
    return best
end

local function ScanPlayerAuras()
    if not activeProfile or not activeProfile.enabled then return end

    -- Aura reads are masked during instanced combat. Rather than guess (which
    -- caused storms and combat-end bursts), freeze read-tracked auras while
    -- masked and re-sync silently when combat ends. Cast-tracked auras are
    -- driven by cast events and keep working here.
    if IsInInstance() and InCombatLockdown() then return end

    local cues = activeProfile.cues
    local newPresent = {}
    for key, cue in pairs(cues) do
        local sid = tonumber(key)
        if cue.castSeen then
            -- Cast-tracked: "gained" fires from the cast event. For "faded" we
            -- read, but only trust an "absent" once a read has CONFIRMED the
            -- aura was up since the cast — so a cast buff whose aura id differs
            -- from the cast id (read never finds it) never falsely fades, while
            -- a normal same-id buff fades correctly when it drops.
            local state, data = CueRead(sid, cueAlts[key])
            if state == "present" then
                castConfirmed[sid] = true
                newPresent[sid] = true
                if data then
                    local d = Reveal(data.duration)
                    if d and d > 0 then cue.castDuration = d end
                end
            elseif state == "unknown" then
                newPresent[sid] = present[sid]
            elseif castConfirmed[sid] and present[sid] and cue.faded then
                FireCue(cue, C_Spell.GetSpellName(sid), "faded")
                castConfirmed[sid] = nil
            else
                newPresent[sid] = present[sid]   -- not confirmed yet: hold
            end
        else
            local state, data = CueRead(sid, cueAlts[key])
            if state == "present" then
                newPresent[sid] = true
                if data then
                    local d = Reveal(data.duration)   -- learn duration for cast timing
                    if d and d > 0 then cue.castDuration = d end
                end
                if not present[sid] and cue.applied then
                    FireCue(cue, C_Spell.GetSpellName(sid), "applied")
                end
            elseif state == "unknown" then
                newPresent[sid] = present[sid]   -- secret-masked: hold
            elseif present[sid] and cue.faded then
                FireCue(cue, C_Spell.GetSpellName(sid), "faded")
            end
        end
    end
    present = newPresent

    CatalogVisibleAuras()
end
ns.ScanPlayerAuras = ScanPlayerAuras

-- Re-seed `present` without firing, so adding a cue for an aura that's
-- already up doesn't instantly announce it.
local function SeedPresent()
    present = {}
    local cues = activeProfile and activeProfile.cues
    if not cues then return end
    for key in pairs(cues) do
        if CueRead(tonumber(key), cueAlts[key]) == "present" then present[tonumber(key)] = true end
    end
end

-- Schedule the duration-based "faded" timer for a cast-tracked cue. The latest
-- call wins (token), so calling it again with a freshly-learned duration just
-- replaces the earlier estimate.
local function ScheduleFade(cue, pid, dur)
    if not (cue.faded and dur and dur > 0) then return end
    castFade[pid] = (castFade[pid] or 0) + 1
    local token = castFade[pid]
    C_Timer.After(dur + 0.2, function()
        -- Only fire if this is still the latest cast and the aura isn't
        -- readably still up (a refresh in the open world would show it).
        if castFade[pid] == token and present[pid] and CueRead(pid, cueAlts[tostring(pid)]) ~= "present" then
            FireCue(cue, C_Spell.GetSpellName(pid), "faded")
            present[pid] = nil
        end
    end)
end

-- Cast-driven tracking. Your own casts are NOT secret even in instances, so
-- when you cast a watched aura's spell we can fire its "gained" cue (and,
-- using the duration we learned in the open world, schedule its "faded")
-- even where reading the aura directly is blocked. Assumes the cast spell id
-- matches the aura spell id (true for most self-buffs).
local function OnSelfCast(spellID)
    if not activeProfile then return end
    -- The cast id may be the cue's primary id OR one of its aliases; in either
    -- case drive the cue under its PRIMARY id so all tracking state stays keyed
    -- consistently with ScanPlayerAuras.
    local cue = activeProfile.cues[tostring(spellID)]
    local pid = spellID
    if not cue then
        local owner = aliasOwner[tostring(spellID)]
        if owner then cue = activeProfile.cues[owner]; pid = tonumber(owner) end
    end
    if not cue then return end
    -- Once we've seen its cast, this cue is cast-tracked from now on.
    cue.castSeen = true
    castConfirmed[pid] = nil   -- require a fresh read to confirm before fading
    -- Fire "gained" on each cast (debounced ~1s), so repeated casts re-cue
    -- even when we can't detect the buff dropping in between.
    local now = GetTime()
    if cue.applied and (now - (lastGained[pid] or 0)) > 0.8 then
        lastGained[pid] = now
        FireCue(cue, C_Spell.GetSpellName(pid), "applied")
    end
    present[pid] = true

    -- Schedule the faded timer now using any previously-learned duration (so it
    -- works in instances where reads are blocked), then re-learn the duration
    -- just after the cast and reschedule with the fresh value. The reschedule
    -- supersedes the first, and crucially this also schedules a timer on the
    -- very first cast — when castDuration wasn't known yet.
    ScheduleFade(cue, pid, cue.castDuration)
    C_Timer.After(0.1, function()
        local _, data = CueRead(pid, cueAlts[tostring(pid)])
        if data then
            local d = Reveal(data.duration)
            if d and d > 0 then cue.castDuration = d; ScheduleFade(cue, pid, d) end
        end
    end)
end

-- ---------------------------------------------------------------------
-- Private-aura debuff sounds.
-- ---------------------------------------------------------------------
-- Most boss/mob debuffs in instances are "private auras", which normal aura
-- reads can't see — but C_UnitAuras.AddPrivateAuraAppliedSound CAN play a
-- sound when one is applied to you, even in instanced combat. So for every
-- watched DEBUFF with a gained sound we register that sound. This is
-- sound-only on apply (no visual, no faded — the API gives no Lua callback).
local privAuraSoundIDs = {}
local function RefreshPrivateAuras()
    local A = C_UnitAuras
    if not (A and A.AddPrivateAuraAppliedSound and A.RemovePrivateAuraAppliedSound) then return end
    for _, id in ipairs(privAuraSoundIDs) do
        pcall(A.RemovePrivateAuraAppliedSound, id)
    end
    wipe(privAuraSoundIDs)
    if not activeProfile or not AuraCueDB or not AuraCueDB.audioEnabled then return end
    if not activeProfile.trackDebuffs then return end
    for key, cue in pairs(activeProfile.cues) do
        -- "speak" can't be registered as a private-aura sound (no TTS hook),
        -- and a "world"-only cue shouldn't fire in instances.
        if cue.kind == "debuff" and cue.applied and cue.soundApplied
           and cue.soundApplied ~= "speak" and cue.when ~= "world" then
            local playable, isFile = ResolveSound(cue.soundApplied)
            -- The private-aura API only accepts a sound file (soundFileName /
            -- soundFileID FileDataID), not a SOUNDKIT id, so kit-based sounds
            -- can't be registered here. All shipped cues are file-based.
            if playable and isFile then
                -- Register for the cue's primary id and each (merged) alias id.
                local ids = { tonumber(key) }
                if cueAlts[key] then for _, a in ipairs(cueAlts[key]) do ids[#ids + 1] = a end end
                for _, sid in ipairs(ids) do
                    if sid then
                        local opts = {
                            unitToken = "player",
                            spellID = sid,
                            outputChannel = string.lower(cue.channel or activeProfile.channel or "master"),
                            soundFileName = playable,
                        }
                        local ok, id = pcall(A.AddPrivateAuraAppliedSound, opts)
                        if ok and id then privAuraSoundIDs[#privAuraSoundIDs + 1] = id end
                    end
                end
            end
        end
    end
end
ns.RefreshPrivateAuras = RefreshPrivateAuras

-- ---------------------------------------------------------------------
-- Watch-list mutation (driven by slash commands and the in-panel editor)
-- ---------------------------------------------------------------------
-- Rebuild the merged alias list per cue (hand-added ids + same-named catalog
-- ids when matchName is on) and the alt -> primary-cue lookup.
local function RebuildAliases()
    wipe(aliasOwner)
    wipe(cueAlts)
    if not activeProfile or not activeProfile.cues then return end
    local seen = AuraCueDB and AuraCueDB.seen or {}
    for key, cue in pairs(activeProfile.cues) do
        local merged, used = {}, { [key] = true }
        local function add(v)
            local n = tonumber(v)
            if n and not used[tostring(n)] then
                used[tostring(n)] = true
                merged[#merged + 1] = n
                aliasOwner[tostring(n)] = key
            end
        end
        if cue.alts then for _, a in ipairs(cue.alts) do add(a) end end
        -- Auto-combine: every catalogued aura sharing this cue's name (when the
        -- global setting is on, or this cue opted in).
        if (activeProfile.combineByName or cue.matchName) and cue.label then
            for sidStr, info in pairs(seen) do
                if info.name == cue.label then add(sidStr) end
            end
        end
        cueAlts[key] = (#merged > 0) and merged or nil
    end
end
ns.RebuildAliases = RebuildAliases

-- Set the extra spell ids that also trigger one cue (so e.g. base and proc
-- Avenging Wrath are a single alert). Pass a list of numbers/strings.
function ns.SetCueAlts(spellKey, list)
    local cue = activeProfile and activeProfile.cues[tostring(spellKey)]
    if not cue then return end
    local clean, used = {}, { [tostring(spellKey)] = true }
    for _, v in ipairs(list or {}) do
        local n = tonumber(v)
        if n and not used[tostring(n)] then used[tostring(n)] = true; clean[#clean + 1] = n end
    end
    cue.alts = (#clean > 0) and clean or nil
    RebuildAliases()
    SeedPresent()
    RefreshPrivateAuras()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Turn name-combining on/off for one cue. When turning it ON, absorb any other
-- watched cues that share the name (they're now redundant — this one alert
-- already covers their ids), so you end up with a single entry.
function ns.SetMatchName(spellKey, on)
    local cues = activeProfile and activeProfile.cues
    local cue = cues and cues[tostring(spellKey)]
    if not cue then return end
    cue.matchName = on and true or nil
    if on and cue.label then
        for k, c in pairs(cues) do
            if k ~= tostring(spellKey) and c.label == cue.label then cues[k] = nil end
        end
    end
    RebuildAliases()
    SeedPresent()
    RefreshPrivateAuras()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- True if a watched cue name-combines this aura's name (so the picker can stop
-- offering the same-named variants as separate adds).
function ns.IsNameCombined(name)
    if not name or not activeProfile then return false end
    local global = activeProfile.combineByName
    for _, c in pairs(activeProfile.cues) do
        if (global or c.matchName) and c.label == name then return true end
    end
    return false
end

-- Flip a watched cue between buff and debuff (so a self-debuff that came in as
-- a "buff" can be moved to the Debuffs side). Keeps the catalog entry in sync.
function ns.SetCueKind(spellKey, kind)
    local key = tostring(spellKey)
    local cue = activeProfile and activeProfile.cues[key]
    if not cue then return end
    kind = (kind == "debuff") and "debuff" or "buff"
    if cue.kind == kind then return end
    cue.kind = kind
    -- Move it out of the old kind's default category heading.
    if cue.category == "Buffs" or cue.category == "Debuffs" then
        cue.category = (kind == "debuff") and "Debuffs" or "Buffs"
    end
    if AuraCueDB.seen and AuraCueDB.seen[key] then AuraCueDB.seen[key].kind = kind end
    RebuildAliases()
    SeedPresent()
    RefreshPrivateAuras()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Global toggle: combine every same-named aura into a single alert. Turning it
-- ON absorbs duplicate cues (keeps one per name).
function ns.SetCombineByName(on)
    if not activeProfile then return end
    activeProfile.combineByName = on and true or nil
    if on then
        local cues, kept = activeProfile.cues, {}
        for k, c in pairs(cues) do
            local nm = c.label
            if nm then
                if kept[nm] then cues[k] = nil else kept[nm] = k end
            end
        end
    end
    RebuildAliases()
    SeedPresent()
    RefreshPrivateAuras()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.AddCue(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local name = C_Spell.GetSpellName(spellID)
    local seen = AuraCueDB.seen[tostring(spellID)]
    local kind = (seen and seen.kind) or "buff"
    local dungeon = seen and seen.dungeon
    local source = seen and seen.source
    -- Debuffs file under the dungeon they came from (the useful grouping);
    -- buffs default to a single "Buffs" group. Either can be retyped.
    local category
    if kind == "debuff" then
        category = dungeon or "Other"
    else
        category = "Buffs"
    end
    activeProfile.cues[tostring(spellID)] = {
        applied      = true,
        faded        = true,
        soundApplied = "rise",   -- played when the aura is gained
        soundFaded   = "fall",   -- played when it fades (false = silent)
        channel      = nil,      -- nil = follow the global default channel
        visual       = true,
        label    = name,
        kind     = kind,
        category = category,
        dungeon  = dungeon,
        source   = source,
    }
    RebuildAliases()
    SeedPresent()
    RefreshPrivateAuras()
    return true, name
end

function ns.RemoveCue(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local existed = activeProfile.cues[tostring(spellID)] ~= nil
    activeProfile.cues[tostring(spellID)] = nil
    RebuildAliases()
    RefreshPrivateAuras()
    return existed
end

function ns.CueCount()
    local n = 0
    for _ in pairs(activeProfile.cues) do n = n + 1 end
    return n
end

-- Pre-check whether a spell's aura would be a secret value (masked from
-- addons) in restricted content — usable before any aura exists, so the
-- picker can flag spells whose cues may not fire reliably in instances.
-- Degrades to false when the regime/API is absent (older clients), and
-- pcall-guards the predicate in case its signature differs on live.
-- NOTE: player-own auras are non-secret regardless, so this mainly flags
-- arbitrary by-ID additions (enemy/boss debuffs, others' buffs).
function ns.IsSpellAuraSecret(spellID)
    local S = C_Secrets
    if not (S and S.HasSecretRestrictions and S.HasSecretRestrictions()) then
        return false
    end
    if S.ShouldSpellAuraBeSecret then
        local ok, res = pcall(S.ShouldSpellAuraBeSecret, spellID)
        if ok then return res and true or false end
    end
    return false
end

-- List auras we've actually seen on the player, with icon + name, for the
-- "add" picker. Because every entry was a real aura on the player, every
-- entry genuinely tracks — spellbook abilities that apply no self-aura
-- (interrupts, direct damage, target debuffs) never show up. Sorted by
-- name. Returns { spellID, name, icon, secret }.
function ns.GetSeenAuras()
    local out = {}
    local seen = AuraCueDB and AuraCueDB.seen or {}
    local castable = (AuraCueDB and AuraCueDB.castable) or {}
    local ignored = (AuraCueDB and AuraCueDB.ignored) or {}
    local groups = (AuraCueDB and AuraCueDB.groups) or {}
    local GetMount = C_MountJournal and C_MountJournal.GetMountFromSpell
    for key, info in pairs(seen) do
        local sid = tonumber(key)
        local kind = info.kind or "buff"
        -- "Instance-trackable": debuffs (private-aura sound works in instances)
        -- and buffs that cast-track. We know a buff cast-tracks if we've seen
        -- you cast that exact spell; C_SpellBook.IsSpellKnown is a best-effort
        -- fallback (unreliable when the aura id differs from the cast id, which
        -- is why the cast record is the primary signal).
        local instanceable = (kind == "debuff")
            or (castable[key] and true)
            or (SpellKnown and SpellKnown(sid) and true)
            or false
        out[#out + 1] = {
            spellID = sid,
            name    = info.name or C_Spell.GetSpellName(sid) or ("Spell " .. key),
            icon    = info.icon or 134400,
            secret  = ns.IsSpellAuraSecret(sid),
            kind    = kind,
            mine    = info.mine and true or false,
            -- A spell in your spellbook -> a class/spec ability, as opposed to
            -- a toy / food / world buff (whose aura id isn't a known spell).
            known   = (SpellKnown and SpellKnown(sid)) and true or false,
            ignored = ignored[key] and true or false,
            mount   = (GetMount and GetMount(sid)) and true or false,
            boss    = info.boss and true or false,
            permanent = info.permanent and true or false,
            roleAura  = info.roleAura and true or false,
            className = info.className,
            group   = groups[key],
            dungeon = info.dungeon,
            instanceable = instanceable,
        }
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- Hide / unhide a catalogued aura from the picker (account-wide).
function ns.SetAuraIgnored(spellID, on)
    if not AuraCueDB then return end
    AuraCueDB.ignored = AuraCueDB.ignored or {}
    AuraCueDB.ignored[tostring(spellID)] = on and true or nil
end

-- Assign (or clear, with a blank name) a catalogued aura's custom group.
function ns.SetAuraGroup(spellID, name)
    if not AuraCueDB then return end
    AuraCueDB.groups = AuraCueDB.groups or {}
    if type(name) == "string" then name = name:trim() end
    if not name or name == "" then name = nil end
    AuraCueDB.groups[tostring(spellID)] = name
end

-- Remove an aura from the catalog entirely (and any group / hidden / cast
-- record for it). Does not touch watched cues that reference it.
function ns.ForgetAura(spellID)
    if not AuraCueDB then return end
    local key = tostring(spellID)
    if AuraCueDB.seen then AuraCueDB.seen[key] = nil end
    if AuraCueDB.groups then AuraCueDB.groups[key] = nil end
    if AuraCueDB.ignored then AuraCueDB.ignored[key] = nil end
    if AuraCueDB.castable then AuraCueDB.castable[key] = nil end
end

-- Distinct custom group names currently in use (sorted) — for suggestions.
function ns.GetAuraGroupNames()
    local set, out = {}, {}
    for _, name in pairs((AuraCueDB and AuraCueDB.groups) or {}) do
        if type(name) == "string" and name ~= "" and not set[name] then
            set[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

function ns.ResetIgnored()
    if AuraCueDB then AuraCueDB.ignored = {} end
end

-- Rename a custom group everywhere (newName blank/nil deletes the group).
function ns.RenameAuraGroup(oldName, newName)
    if not (AuraCueDB and AuraCueDB.groups and oldName) then return end
    if type(newName) == "string" then newName = newName:trim() end
    if newName == "" then newName = nil end
    for k, v in pairs(AuraCueDB.groups) do
        if v == oldName then AuraCueDB.groups[k] = newName end
    end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.DeleteAuraGroup(name)
    ns.RenameAuraGroup(name, nil)
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- combat ended: re-sync
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

local SETTING_KEYS = { "enabled", "channel", "audioEnabled",
    "trackBuffs", "trackDebuffs", "visual", "cues" }

-- Heal a cue table: backfill kind/category, split the old single sound into
-- gained/faded, and remap any unknown sound key onto a bundled tone (`false`
-- = None / silent is preserved). Shared by login and profile import.
local function BackfillCues(cues)
    for _, cue in pairs(cues) do
        if not cue.kind then cue.kind = "buff" end
        if not cue.category then
            cue.category = (cue.kind == "debuff") and "Debuffs" or "Buffs"
        end
        if cue.sound ~= nil and cue.soundApplied == nil and cue.soundFaded == nil then
            cue.soundApplied = cue.sound
            cue.soundFaded = cue.sound
            cue.sound = nil
        end
        if cue.soundApplied == nil then cue.soundApplied = "rise" end
        if cue.soundFaded == nil then cue.soundFaded = "fall" end
        for _, field in ipairs({ "soundApplied", "soundFaded" }) do
            local v = cue[field]
            if v then
                local known = false
                for _, e in ipairs(ns.SOUNDS) do
                    if e.key == v then known = true; break end
                end
                if not known then cue[field] = (field == "soundFaded") and "fall" or "rise" end
            end
        end
    end
end
ns.BackfillCues = BackfillCues

-- Point activeProfile at the current character+spec profile, creating it (or
-- migrating an older per-character profile into it) as needed. Heals it with
-- defaults / validation / cue backfill. Used at login and on spec change.
local function SetActiveProfile()
    local key = ProfileKey()

    -- Migrate a pre-per-spec profile (keyed by character only) into the
    -- current spec the first time we see this spec.
    local charKey = CharKey()
    if AuraCueDB.profiles[charKey] and not AuraCueDB.profiles[key] then
        AuraCueDB.profiles[key] = AuraCueDB.profiles[charKey]
        AuraCueDB.profiles[charKey] = nil
    end

    AuraCueDB.profiles[key] = AuraCueDB.profiles[key] or {}
    activeProfile = AuraCueDB.profiles[key]
    MigrateVisual(activeProfile)
    MergeDefaults(activeProfile, PROFILE_DEFAULTS)
    ValidateRanges(activeProfile)
    BackfillCues(activeProfile.cues)
    RebuildAliases()
    RefreshPrivateAuras()
end
ns.SetActiveProfile = SetActiveProfile

-- Full init at PLAYER_LOGIN (player + spec are reliable here).
local function InitProfile()
    -- Migrate a pre-v0.10 flat layout (tracked settings at the DB top level)
    -- into this character's per-character profile; SetActiveProfile then moves
    -- it into the current spec.
    local hasFlat = false
    for _, k in ipairs(SETTING_KEYS) do
        if AuraCueDB[k] ~= nil then hasFlat = true; break end
    end
    if hasFlat then
        local charKey = CharKey()
        local prof = AuraCueDB.profiles[charKey] or {}
        for _, k in ipairs(SETTING_KEYS) do
            if AuraCueDB[k] ~= nil then prof[k] = AuraCueDB[k]; AuraCueDB[k] = nil end
        end
        AuraCueDB.profiles[charKey] = prof
    end

    SetActiveProfile()
    RestorePosition("buff")
    RestorePosition("debuff")
    ns.InitOptions()
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        -- One-time carry-over from the addon's former name. CueSenseDB is
        -- still listed in the TOC SavedVariables so the old data loads (this
        -- only works if the old SavedVariables file was renamed to match the
        -- new addon folder); this adopts it, then clears it. The extra
        -- SavedVariables entry can be dropped in a later version.
        if not AuraCueDB and CueSenseDB then
            AuraCueDB = CueSenseDB
            CueSenseDB = nil
            ns.migratedFromCueSense = true
        end
        AuraCueDB = AuraCueDB or {}
        MergeDefaults(AuraCueDB, DB_DEFAULTS)

        -- One-time cleanup: clear boss flags that can't be real (your own
        -- auras, or anything that isn't a debuff) from catalogs built before
        -- the boss check was tightened.
        if not AuraCueDB.bossSanitized then
            for _, v in pairs(AuraCueDB.seen or {}) do
                if v.boss and (v.mine or v.kind ~= "debuff") then v.boss = false end
            end
            AuraCueDB.bossSanitized = true
        end

    elseif event == "PLAYER_LOGIN" then
        InitProfile()
        chatPrint("loaded. Type |cffffd200/cue|r for commands.")
        if ns.migratedFromCueSense then
            chatPrint("Imported your previous settings and aura catalog from CueSense.")
        end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Fires for group members too; only react to our own change, and
        -- only once the addon has finished its login init.
        local unit = ...
        if unit and unit ~= "player" then return end
        if not activeProfile then return end
        SetActiveProfile()
        present = {}
        SeedPresent()
        RestorePosition("buff")
        RestorePosition("debuff")
        if ns.RefreshOptions then ns.RefreshOptions() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        SeedPresent()

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended: reads are reliable again. Re-sync silently (no cues)
        -- so we don't fire a burst for changes that happened while masked.
        SeedPresent()

    elseif event == "UNIT_AURA" then
        ScanPlayerAuras()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID then
            if AuraCueDB then
                AuraCueDB.castable = AuraCueDB.castable or {}
                AuraCueDB.castable[tostring(spellID)] = true
            end
            OnSelfCast(spellID)
            -- Catalog the aura this cast applies. The aura list can't be read
            -- in combat (its spell ids are secret), but querying this known id
            -- works in and out of combat — so buffs/debuffs you cast in a fight
            -- still make it into the picker (when the aura shares the cast id).
            C_Timer.After(0.1, function()
                local seen = AuraCueDB and AuraCueDB.seen
                if not seen then return end
                local key = tostring(spellID)
                local known = SpellKnown(spellID) and true or false
                local GM = C_MountJournal and C_MountJournal.GetMountFromSpell
                local isMount = (GM and GM(spellID)) and true or false
                local state, data = ReadAura(spellID)
                if state == "present" and data then
                    -- The cast applied a same-id aura we can read: record it with
                    -- its real kind / fields.
                    RecordSeen(spellID, data)
                elseif not seen[key] and known and not isMount then
                    -- A known ability you cast that applies no readable same-id
                    -- aura (no aura, or a proc with a different id). Offer it
                    -- anyway so castable abilities aren't missing from the picker;
                    -- it'll be cast-tracked. Kind is a best guess (buff).
                    local GT = C_Spell.GetSpellTexture
                    seen[key] = {
                        name = C_Spell.GetSpellName(spellID),
                        icon = (GT and GT(spellID)) or nil,
                        kind = "buff",
                        mine = true,
                        castOnly = true,
                    }
                end
                -- Tag the casting class on an ability you cast (known player
                -- spell, not a mount), so the picker files it under your class
                -- (e.g. Earth Shield -> Shaman). Other classes' auras can't be
                -- derived — the game has no spell->class lookup.
                local entry = seen[key]
                if entry and not entry.className and known and not isMount then
                    entry.className = UnitClass("player")
                end
            end)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Import / export + catalog gathering
-- ---------------------------------------------------------------------
-- Self-contained (no libraries): a data-only serializer + base64, so a
-- profile or the catalog can be shared as a single copy-pasteable string.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64R

local function base64enc(data)
    local out, i, len = {}, 1, #data
    while i <= len do
        local c1, c2, c3 = data:byte(i), data:byte(i + 1), data:byte(i + 2)
        local n = c1 * 65536 + (c2 or 0) * 256 + (c3 or 0)
        out[#out + 1] = B64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = B64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = c2 and B64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = c3 and B64:sub(n % 64 + 1, n % 64 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

local function base64dec(data)
    if not B64R then
        B64R = {}
        for i = 1, #B64 do B64R[B64:sub(i, i)] = i - 1 end
    end
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out, i, len = {}, 1, #data
    while i <= len do
        local s1, s2 = data:sub(i, i), data:sub(i + 1, i + 1)
        local s3, s4 = data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
        local n1, n2, n3, n4 = B64R[s1], B64R[s2], B64R[s3], B64R[s4]
        if not n1 or not n2 then return nil end
        local n = n1 * 262144 + n2 * 4096 + (n3 or 0) * 64 + (n4 or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if s3 ~= "=" and n3 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if s4 ~= "=" and n4 then out[#out + 1] = string.char(n % 256) end
        i = i + 4
    end
    return table.concat(out)
end

-- Serialize data only (numbers / booleans / strings / nested tables with
-- string or number keys). Functions and other types are skipped.
local function serialize(v)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.6g", v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            local kt, vs = type(k), serialize(val)
            if vs then
                if kt == "string" then
                    parts[#parts + 1] = "[" .. string.format("%q", k) .. "]=" .. vs
                elseif kt == "number" then
                    parts[#parts + 1] = "[" .. string.format("%d", k) .. "]=" .. vs
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return nil
end

-- Parse a serialized literal back to a table, in an EMPTY environment so the
-- chunk can only build data (no globals, no function calls).
local function deserialize(str)
    local f = loadstring and loadstring("return " .. str)
    if not f then return nil end
    setfenv(f, {})
    local ok, res = pcall(f)
    if not ok or type(res) ~= "table" then return nil end
    return res
end

local PROFILE_MAGIC = "CSP1!"
local CATALOG_MAGIC = "CSC1!"

function ns.ExportProfile()
    if not activeProfile then return "" end
    return PROFILE_MAGIC .. base64enc(serialize(activeProfile))
end

function ns.ExportCatalog()
    return CATALOG_MAGIC .. base64enc(serialize(AuraCueDB.seen or {}))
end

-- Import either a profile or a catalog string. Returns (ok, message).
function ns.ImportShare(str)
    str = (str or ""):gsub("%s", "")
    if str == "" then return false, "Nothing to import." end
    local magic = str:sub(1, 5)
    if magic ~= PROFILE_MAGIC and magic ~= CATALOG_MAGIC then
        return false, "That isn't a AuraCue string."
    end
    local payload = base64dec(str:sub(6))
    if not payload then return false, "Could not decode the string." end
    local data = deserialize(payload)
    if not data then return false, "The string is corrupt or invalid." end

    if magic == PROFILE_MAGIC then
        MigrateVisual(data)
        MergeDefaults(data, PROFILE_DEFAULTS)
        ValidateRanges(data)
        if type(data.cues) ~= "table" then data.cues = {} end
        BackfillCues(data.cues)
        AuraCueDB.profiles[ProfileKey()] = data
        activeProfile = data
        RebuildAliases()
        RestorePosition("buff")
        RestorePosition("debuff")
        present = {}
        SeedPresent()
        RefreshPrivateAuras()
        if ns.RefreshOptions then ns.RefreshOptions() end
        local n = 0
        for _ in pairs(data.cues) do n = n + 1 end
        return true, "Imported a profile (" .. n .. " auras) into this spec."
    else
        AuraCueDB.seen = AuraCueDB.seen or {}
        local added = 0
        for k, v in pairs(data) do
            if type(v) == "table" and AuraCueDB.seen[k] == nil then
                AuraCueDB.seen[k] = v
                added = added + 1
            end
        end
        if ns.RefreshOptions then ns.RefreshOptions() end
        return true, "Merged " .. added .. " new aura(s) into the catalog."
    end
end

function ns.SeenCount()
    local n = 0
    if AuraCueDB and AuraCueDB.seen then
        for _ in pairs(AuraCueDB.seen) do n = n + 1 end
    end
    return n
end

-- Harvest auras from nearby units into the catalog. Enemy aura spellIDs are
-- secret in instanced content (Reveal returns nil), so this gathers mostly in
-- the open world / on target dummies. Returns the number of NEW auras added.
function ns.GatherAuras()
    if not AuraCueDB then return 0 end
    AuraCueDB.seen = AuraCueDB.seen or {}
    local before = ns.SeenCount()
    local function rec(data, harmful)
        if not data then return false end
        local sid = Reveal(data.spellId)
        if sid and not AuraCueDB.seen[tostring(sid)] then
            AuraCueDB.seen[tostring(sid)] = {
                name = Reveal(data.name) or C_Spell.GetSpellName(sid),
                icon = Reveal(data.icon),
                kind = harmful and "debuff" or "buff",
                mine = Reveal(data.isFromPlayerOrPlayerPet) and true or false,
            }
        end
        return false
    end
    local units = { "player", "pet", "target", "targettarget", "focus", "mouseover" }
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
    for _, u in ipairs(units) do
        if UnitExists(u) then
            AuraUtil.ForEachAura(u, "HELPFUL", nil, function(d) return rec(d, false) end, true)
            AuraUtil.ForEachAura(u, "HARMFUL", nil, function(d) return rec(d, true) end, true)
        end
    end
    return ns.SeenCount() - before
end

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------
SLASH_AURACUE1 = "/cue"
SLASH_AURACUE2 = "/auracue"

SlashCmdList["AURACUE"] = function(msg)
    local ok, err = pcall(function()
        msg = (msg or ""):lower():trim()
        local cmd, rest = msg:match("^(%S+)%s*(.-)$")
        cmd = cmd or ""

        if cmd == "" or cmd == "config" or cmd == "options" then
            ns.OpenOptions()

        elseif cmd == "test" then
            ns.PlayTestCue()

        elseif cmd == "add" then
            local okAdd, name = ns.AddCue(rest)
            if okAdd then
                chatPrint("watching |cffffd200" .. rest .. "|r" .. (name and (" (" .. name .. ")") or "") .. ".")
                ns.RefreshOptions()
            else
                chatPrint("usage: |cffffd200/cue add <spellID>|r")
            end

        elseif cmd == "remove" or cmd == "rem" then
            if ns.RemoveCue(rest) then
                chatPrint("stopped watching |cffffd200" .. rest .. "|r.")
                ns.RefreshOptions()
            else
                chatPrint("not watching spell |cffffd200" .. tostring(rest) .. "|r.")
            end

        elseif cmd == "list" then
            local n = ns.CueCount()
            chatPrint("watching " .. n .. " aura" .. (n == 1 and "" or "s") .. ":")
            for sid, cue in pairs(activeProfile.cues) do
                local modes = {}
                if cue.soundApplied or cue.soundFaded then modes[#modes + 1] = "sound" end
                if cue.visual then modes[#modes + 1] = "visual" end
                print(string.format("  |cffffd200%s|r  %s  [%s]", sid,
                    cue.label or (C_Spell.GetSpellName(tonumber(sid)) or "?"),
                    table.concat(modes, "+")))
            end

        elseif cmd == "toggle" then
            activeProfile.enabled = not activeProfile.enabled
            chatPrint(activeProfile.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
            ns.RefreshOptions()

        elseif cmd == "lock" then
            ns.SetRepositionMode("buff", false)
            ns.SetRepositionMode("debuff", false)
            chatPrint("overlays |cffff0000locked|r.")

        elseif cmd == "unlock" or cmd == "move" then
            local kind = (rest == "debuff") and "debuff" or "buff"
            ns.SetRepositionMode(kind, true)
            chatPrint((kind == "debuff" and "debuff" or "buff")
                .. " overlay |cff00ff00unlocked|r — drag to move, then |cffffd200/cue lock|r."
                .. "  (use |cffffd200/cue move debuff|r for the other one.)")

        elseif cmd == "reset" then
            activeProfile.visual.buff.position = nil
            activeProfile.visual.debuff.position = nil
            RestorePosition("buff")
            RestorePosition("debuff")
            chatPrint("overlay positions reset.")

        elseif cmd == "forget" then
            AuraCueDB.seen = {}
            chatPrint("cleared the remembered-aura list (it refills as auras appear on you).")
            ns.RefreshOptions()

        elseif cmd == "gather" then
            local added = ns.GatherAuras()
            chatPrint("gathered " .. added .. " new aura(s) from nearby units ("
                .. ns.SeenCount() .. " in the catalog).")
            ns.RefreshOptions()

        elseif cmd == "tts" then
            local C = C_VoiceChat
            local voices = ns.GetTtsVoices()
            local v = (activeProfile and activeProfile.ttsVoice) or (voices[1] and voices[1].voiceID)
            chatPrint("TTS: SpeakText=" .. tostring(C and C.SpeakText ~= nil)
                .. ", voices=" .. #voices .. ", using voiceID=" .. tostring(v))
            local TS = C_TTSSettings
            if TS and TS.GetSpeechVolume then
                local okv, vol = pcall(TS.GetSpeechVolume)
                chatPrint("  Game speech volume = " .. (okv and tostring(vol) or "?")
                    .. "  (if 0, speech is silent no matter what AuraCue sends)")
            end
            if C and C.SpeakText and v then
                -- 12.0.0 signature: SpeakText(voiceID, text, rate, volume).
                local ok, err = pcall(C.SpeakText, v, "AuraCue speech test", 0, 100)
                chatPrint("  SpeakText ok=" .. tostring(ok) .. (err and (" err=" .. tostring(err)) or ""))
            end

        elseif cmd == "debug" then
            -- Reports what the game returns for each watched aura, so we can
            -- see whether reads are masked in combat. Run it in and out of
            -- combat and report the difference.
            local GP = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
            chatPrint("aura reads (combat=" .. tostring(InCombatLockdown())
                .. ", GetPlayerAuraBySpellID=" .. tostring(GP ~= nil) .. "):")
            for key in pairs(activeProfile.cues) do
                local sid = tonumber(key)
                local a = GP and GP(sid)
                local d = (a == nil) and "|cffff6060nil|r"
                    or (IsSecret(a) and "|cffffd200secret|r" or "|cff60ff60readable|r")
                print("  " .. key .. " " .. (C_Spell.GetSpellName(sid) or "?") .. ": " .. d)
            end

        elseif cmd == "status" then
            local seenN = 0
            for _ in pairs(AuraCueDB.seen) do seenN = seenN + 1 end
            chatPrint("status:")
            print("  enabled:        " .. tostring(activeProfile.enabled))
            print("  watched auras:  " .. ns.CueCount())
            print("  auras seen:     " .. seenN)
            local vb, vd = activeProfile.visual.buff, activeProfile.visual.debuff
            print("  buff window:    " .. tostring(vb.enabled)
                  .. " (scale " .. vb.scale .. ", " .. vb.duration .. "s)")
            print("  debuff window:  " .. tostring(vd.enabled)
                  .. " (scale " .. vd.scale .. ", " .. vd.duration .. "s)")
            print("  audio channel:  " .. activeProfile.channel)
            print("  secret regime:  " .. tostring(issecret ~= nil))

        else  -- "help" and anything unrecognized
            chatPrint("commands:")
            print("  |cffffd200/cue|r                 open options")
            print("  |cffffd200/cue test|r            preview a cue")
            print("  |cffffd200/cue add <spellID>|r   watch an aura")
            print("  |cffffd200/cue remove <spellID>|r stop watching")
            print("  |cffffd200/cue list|r            list watched auras")
            print("  |cffffd200/cue toggle|r          enable/disable")
            print("  |cffffd200/cue move|r [|cffffd200debuff|r] / |cffffd200lock|r   move a window")
            print("  |cffffd200/cue reset|r           reset window positions")
            print("  |cffffd200/cue gather|r          catalog auras on nearby units")
            print("  |cffffd200/cue forget|r          clear the remembered-aura list")
            print("  |cffffd200/cue tts|r             diagnose text-to-speech")
            print("  |cffffd200/cue status|r          print current settings")
            print("  |cffffd200/cue help|r            show this list")
        end
    end)
    if not ok then
        chatPrint("slash error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------
-- Addon compartment hooks (wired via the AddonCompartmentFunc* TOC fields)
-- ---------------------------------------------------------------------
function AuraCue_OnCompartmentClick(_, button)
    if button == "RightButton" then
        activeProfile.enabled = not activeProfile.enabled
        chatPrint(activeProfile.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
    else
        ns.OpenOptions()
    end
end

function AuraCue_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("AuraCue", 0.2, 0.86, 0.75)
    GameTooltip:AddLine(activeProfile.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r", 1, 1, 1)
    GameTooltip:AddLine("Watching " .. ns.CueCount() .. " aura(s)", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffd200Left-click:|r options", 1, 1, 1)
    GameTooltip:AddLine("|cffffd200Right-click:|r toggle enabled", 1, 1, 1)
    GameTooltip:Show()
end

function AuraCue_OnCompartmentLeave()
    GameTooltip:Hide()
end
