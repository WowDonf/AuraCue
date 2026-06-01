-- =====================================================================
-- CueSense - Core
-- =====================================================================
-- Accessibility cue layer for World of Warcraft: Midnight (12.x).
-- Translates the player's OWN auras into configurable cues — a sound,
-- an on-screen visual flash, or both — so a player who can't perceive
-- one channel still gets the other. This is the audio<->visual bridge.
--
-- DESIGN CONSTRAINT (Midnight "Secret Values"). Inside raid encounters,
-- M+, and PvP the client masks combat data from addons: tainted code may
-- not read, compare, or do arithmetic on a "secret" value. The player's
-- OWN auras and casts are explicitly NON-secret, so CueSense deliberately
-- stays on the safe side of that wall by tracking only player-owned data.
-- Every value that *could* ever be secret is still routed through
-- IsSecret() / Reveal() so a later enemy/whitelist phase can extend the
-- engine without risking "attempt to perform arithmetic on a secret
-- value" errors. The full API feasibility map lives in the project notes.
-- =====================================================================

local addonName, ns = ...
ns.addonName = addonName

-- Chat helper: prefixes addon-originated lines with a teal [CueSense] tag.
-- Use for prefixed lines; raw print() for indented continuation lines.
local function chatPrint(msg)
    print("|cff33ddbb[CueSense]|r " .. msg)
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
--   CueSenseDB (account-wide) = {
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
    -- Separate on-screen window per kind, so buffs and debuffs can have
    -- their own size / position / color / duration.
    visual = {
        buff = {
            enabled  = true,
            color    = { r = 0.20, g = 0.86, b = 0.75 },   -- teal
            scale    = 1.0,
            duration = 1.5,
            locked   = true,
            position = nil,      -- { point, relativePoint, x, y }
        },
        debuff = {
            enabled  = true,
            color    = { r = 1.00, g = 0.45, b = 0.30 },   -- warm red-orange
            scale    = 1.2,
            duration = 2.0,
            locked   = true,
            position = nil,
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
}

-- The active profile (resolved on login). All tracked-setting reads go
-- through this; `CueSenseDB.seen` stays account-wide.
local activeProfile
local function P() return activeProfile end
ns.P = P

-- Per-character profile key. (Per-spec keying is a later step.)
local function ProfileKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Realm"
    return name .. "-" .. realm
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

local function ValidateRanges(db)
    if type(db.visual) ~= "table" then db.visual = {} end
    for _, key in ipairs({ "buff", "debuff" }) do
        local v = db.visual[key]
        if type(v) ~= "table" then v = {}; db.visual[key] = v end

        if type(v.scale) ~= "number" then v.scale = 1.0 end
        v.scale = math.max(0.5, math.min(3.0, v.scale))

        if type(v.duration) ~= "number" then v.duration = (key == "debuff") and 2.0 or 1.5 end
        v.duration = math.max(0.5, math.min(8.0, v.duration))

        local dc = DEFAULT_COLORS[key]
        local c = v.color
        if type(c) ~= "table" then
            v.color = { r = dc.r, g = dc.g, b = dc.b }
        else
            c.r = (type(c.r) == "number") and math.max(0, math.min(1, c.r)) or dc.r
            c.g = (type(c.g) == "number") and math.max(0, math.min(1, c.g)) or dc.g
            c.b = (type(c.b) == "number") and math.max(0, math.min(1, c.b)) or dc.b
        end
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
    { key = "rise",   label = "Rise (two-tone up)",   file = "Interface\\AddOns\\CueSense\\Sounds\\rise.mp3" },
    { key = "fall",   label = "Fall (two-tone down)", file = "Interface\\AddOns\\CueSense\\Sounds\\fall.mp3" },
    { key = "ping",   label = "Ping (high)",          file = "Interface\\AddOns\\CueSense\\Sounds\\ping.mp3" },
    { key = "beep",   label = "Beep (mid)",           file = "Interface\\AddOns\\CueSense\\Sounds\\beep.mp3" },
    { key = "double", label = "Double beep",          file = "Interface\\AddOns\\CueSense\\Sounds\\double.mp3" },
    { key = "triple", label = "Triple beep",          file = "Interface\\AddOns\\CueSense\\Sounds\\triple.mp3" },
    { key = "chirp",  label = "Chirp (sweep up)",     file = "Interface\\AddOns\\CueSense\\Sounds\\chirp.mp3" },
    { key = "thud",   label = "Thud (low)",           file = "Interface\\AddOns\\CueSense\\Sounds\\thud.mp3" },
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
    local f = CreateFrame("Frame", "CueSenseOverlay" .. suffix, UIParent, "BackdropTemplate")
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

local function ShowVisual(kind, message)
    local f = overlays[kind]
    local v = VisCfg(kind)
    f.text:SetText(message)
    f.text:SetTextColor(v.color.r, v.color.g, v.color.b)
    f:SetScale(v.scale or 1.0)
    f:SetAlpha(1)
    f.fadeElapsed, f.fadeDuration = 0, (v.duration or 1.5)
    f:Show()
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
        f.text:SetText("CueSense " .. (kind == "debuff" and "debuffs" or "buffs") .. " — drag to move, X to close")
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
-- Cue dispatch
-- ---------------------------------------------------------------------
local function FireCue(cue, spellName, eventKind)
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
        PlaySoundEntry(snd, cue.channel or activeProfile.channel)
    end
    local kind = (cue.kind == "debuff") and "debuff" or "buff"
    if cue.visual and VisCfg(kind).enabled and not ns.testMode then
        ShowVisual(kind, label .. " " .. verb)
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
    if snd then PlaySoundEntry(snd, cue.channel or activeProfile.channel) end
    if cue.visual then
        local kind = (cue.kind == "debuff") and "debuff" or "buff"
        ShowVisual(kind, (cue.label or "Aura") .. " " .. (eventKind == "faded" and "faded" or "gained"))
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
    if not CueSenseDB.seen then CueSenseDB.seen = {} end
    local key = tostring(sid)
    local harmful = Reveal(data.isHarmful) and true or false
    local existing = CueSenseDB.seen[key]
    if existing then
        -- Backfill provenance we couldn't capture on first sighting (e.g.
        -- first seen in the open world, later re-seen inside a dungeon).
        if not existing.dungeon then existing.dungeon = CurrentDungeon() end
        if not existing.source then existing.source = ResolveSource(data, harmful) end
        return
    end
    CueSenseDB.seen[key] = {
        name    = Reveal(data.name) or C_Spell.GetSpellName(sid),
        icon    = Reveal(data.icon),
        kind    = harmful and "debuff" or "buff",
        dungeon = CurrentDungeon(),
        source  = ResolveSource(data, harmful),
    }
end

local function ScanPlayerAuras()
    if not activeProfile or not activeProfile.enabled then return end
    local cues = activeProfile.cues
    local now = {}

    local function handle(data)
        if not data then return false end
        local sid = Reveal(data.spellId)        -- non-secret for the player's own auras
        if sid then
            RecordSeen(sid, data)
            if cues[tostring(sid)] then now[sid] = true end
        end
        return false                            -- never early-out; scan all
    end

    -- usePackedAura=true -> handler receives an aura-data table
    AuraUtil.ForEachAura("player", "HELPFUL", nil, handle, true)
    AuraUtil.ForEachAura("player", "HARMFUL", nil, handle, true)

    for sid in pairs(now) do
        if not present[sid] then
            local cue = cues[tostring(sid)]
            if cue and cue.applied then FireCue(cue, C_Spell.GetSpellName(sid), "applied") end
        end
    end
    for sid in pairs(present) do
        if not now[sid] then
            local cue = cues[tostring(sid)]
            if cue and cue.faded then FireCue(cue, C_Spell.GetSpellName(sid), "faded") end
        end
    end
    present = now
end
ns.ScanPlayerAuras = ScanPlayerAuras

-- Re-seed `present` without firing, so adding a cue for an aura that's
-- already up doesn't instantly announce it.
local function SeedPresent()
    present = {}
    local cues = activeProfile and activeProfile.cues or {}
    local function handle(data)
        if not data then return false end
        local sid = Reveal(data.spellId)
        if sid then
            RecordSeen(sid, data)
            if cues[tostring(sid)] then present[sid] = true end
        end
        return false
    end
    AuraUtil.ForEachAura("player", "HELPFUL", nil, handle, true)
    AuraUtil.ForEachAura("player", "HARMFUL", nil, handle, true)
end

-- ---------------------------------------------------------------------
-- Watch-list mutation (driven by slash commands; the in-panel editor is
-- a later phase)
-- ---------------------------------------------------------------------
function ns.AddCue(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local name = C_Spell.GetSpellName(spellID)
    local seen = CueSenseDB.seen[tostring(spellID)]
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
    SeedPresent()
    return true, name
end

function ns.RemoveCue(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false end
    local existed = activeProfile.cues[tostring(spellID)] ~= nil
    activeProfile.cues[tostring(spellID)] = nil
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
    local seen = CueSenseDB and CueSenseDB.seen or {}
    for key, info in pairs(seen) do
        local sid = tonumber(key)
        out[#out + 1] = {
            spellID = sid,
            name    = info.name or C_Spell.GetSpellName(sid) or ("Spell " .. key),
            icon    = info.icon or 134400,
            secret  = ns.IsSpellAuraSecret(sid),
            kind    = info.kind or "buff",
        }
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

local SETTING_KEYS = { "enabled", "channel", "audioEnabled",
    "trackBuffs", "trackDebuffs", "visual", "cues" }

-- Resolve (and on first run build) this character's profile. Deferred to
-- PLAYER_LOGIN so UnitName/GetRealmName are reliable for the profile key.
local function InitProfile()
    local key = ProfileKey()

    -- Migrate a pre-v0.10 flat layout (tracked settings at the DB top level)
    -- into this character's profile — detected by any old setting key still
    -- sitting at the top level. The `seen` catalog stays account-wide.
    local hasFlat = false
    for _, k in ipairs(SETTING_KEYS) do
        if CueSenseDB[k] ~= nil then hasFlat = true; break end
    end
    if hasFlat then
        local prof = CueSenseDB.profiles[key] or {}
        for _, k in ipairs(SETTING_KEYS) do
            if CueSenseDB[k] ~= nil then prof[k] = CueSenseDB[k]; CueSenseDB[k] = nil end
        end
        CueSenseDB.profiles[key] = prof
    end

    CueSenseDB.profiles[key] = CueSenseDB.profiles[key] or {}
    activeProfile = CueSenseDB.profiles[key]
    MigrateVisual(activeProfile)
    MergeDefaults(activeProfile, PROFILE_DEFAULTS)
    ValidateRanges(activeProfile)

    -- Backfill kind/category onto cues created before v0.5.0, and remap any
    -- sound key that no longer exists (e.g. the pre-v0.7 SOUNDKIT keys) onto
    -- a bundled tone. `false` (None / silent) is preserved.
    for _, cue in pairs(activeProfile.cues) do
        if not cue.kind then cue.kind = "buff" end
        if not cue.category then
            cue.category = (cue.kind == "debuff") and "Debuffs" or "Buffs"
        end
        -- v0.9: split the single `sound` into separate gained/faded sounds.
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

    RestorePosition("buff")
    RestorePosition("debuff")
    ns.InitOptions()
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        CueSenseDB = CueSenseDB or {}
        MergeDefaults(CueSenseDB, DB_DEFAULTS)

    elseif event == "PLAYER_LOGIN" then
        InitProfile()
        chatPrint("loaded. Type |cffffd200/cue|r for commands.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        SeedPresent()

    elseif event == "UNIT_AURA" then
        ScanPlayerAuras()
    end
end)

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------
SLASH_CUESENSE1 = "/cue"
SLASH_CUESENSE2 = "/cuesense"

SlashCmdList["CUESENSE"] = function(msg)
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
            CueSenseDB.seen = {}
            chatPrint("cleared the remembered-aura list (it refills as auras appear on you).")
            ns.RefreshOptions()

        elseif cmd == "status" then
            local seenN = 0
            for _ in pairs(CueSenseDB.seen) do seenN = seenN + 1 end
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

        else
            chatPrint("commands:")
            print("  |cffffd200/cue|r                 open options")
            print("  |cffffd200/cue test|r            preview a cue")
            print("  |cffffd200/cue add <spellID>|r   watch an aura")
            print("  |cffffd200/cue remove <spellID>|r stop watching")
            print("  |cffffd200/cue list|r            list watched auras")
            print("  |cffffd200/cue toggle|r          enable/disable")
            print("  |cffffd200/cue move|r [|cffffd200debuff|r] / |cffffd200lock|r   move a window")
            print("  |cffffd200/cue reset|r           reset window positions")
            print("  |cffffd200/cue forget|r          clear the remembered-aura list")
            print("  |cffffd200/cue status|r          print current settings")
        end
    end)
    if not ok then
        chatPrint("slash error: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------
-- Addon compartment hooks (wired via the AddonCompartmentFunc* TOC fields)
-- ---------------------------------------------------------------------
function CueSense_OnCompartmentClick(_, button)
    if button == "RightButton" then
        activeProfile.enabled = not activeProfile.enabled
        chatPrint(activeProfile.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
    else
        ns.OpenOptions()
    end
end

function CueSense_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("CueSense", 0.2, 0.86, 0.75)
    GameTooltip:AddLine(activeProfile.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r", 1, 1, 1)
    GameTooltip:AddLine("Watching " .. ns.CueCount() .. " aura(s)", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffd200Left-click:|r options", 1, 1, 1)
    GameTooltip:AddLine("|cffffd200Right-click:|r toggle enabled", 1, 1, 1)
    GameTooltip:Show()
end

function CueSense_OnCompartmentLeave()
    GameTooltip:Hide()
end
