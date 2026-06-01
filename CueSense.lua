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
-- Saved variable defaults (account-wide: accessibility needs don't
-- change per character or spec).
-- ---------------------------------------------------------------------
local defaults = {
    enabled = true,
    channel = "Master",          -- default audio channel for cues
    audioEnabled = true,         -- master switch for sound cues
    trackBuffs = true,           -- fire cues for helpful auras
    trackDebuffs = true,         -- fire cues for harmful auras
    visual = {
        enabled  = true,
        color    = { r = 0.20, g = 0.86, b = 0.75 },
        scale    = 1.0,
        duration = 1.5,          -- seconds the flash text stays up
        locked   = true,
        position = nil,          -- { point, relativePoint, x, y }
    },
    -- Watched auras, keyed by spellID-as-string -> cue config:
    --   { applied=bool, faded=bool, sound=key|nil, channel=key|nil,
    --     visual=bool, label=str }
    cues = {},
    -- Registry of auras actually observed on the player, keyed by
    -- spellID-as-string -> { name, icon }. Powers the "add" picker so it
    -- only ever offers auras that genuinely track.
    seen = {},
}

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

local function ValidateRanges(db)
    local v = db.visual
    if type(v) ~= "table" then v = {}; db.visual = v end

    if type(v.scale) ~= "number" then v.scale = 1.0 end
    v.scale = math.max(0.5, math.min(3.0, v.scale))

    if type(v.duration) ~= "number" then v.duration = 1.5 end
    v.duration = math.max(0.5, math.min(8.0, v.duration))

    local c = v.color
    if type(c) ~= "table" then
        v.color = { r = 0.20, g = 0.86, b = 0.75 }
    else
        c.r = (type(c.r) == "number") and math.max(0, math.min(1, c.r)) or 0.20
        c.g = (type(c.g) == "number") and math.max(0, math.min(1, c.g)) or 0.86
        c.b = (type(c.b) == "number") and math.max(0, math.min(1, c.b)) or 0.75
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
-- Visual overlay frame (non-secure: combat lockdown doesn't touch it).
-- A single center-screen flash line, reused by every cue, the test
-- button, and reposition mode.
-- ---------------------------------------------------------------------
local overlay = CreateFrame("Frame", "CueSenseOverlay", UIParent, "BackdropTemplate")
ns.overlay = overlay
overlay:SetSize(560, 90)
overlay:SetFrameStrata("FULLSCREEN_DIALOG")
overlay:SetFrameLevel(200)
overlay:SetClampedToScreen(true)
overlay:EnableMouse(false)   -- click-through until reposition mode turns it on
overlay:SetMovable(true)
overlay:Hide()

overlay.text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
overlay.text:SetAllPoints()
overlay.text:SetJustifyH("CENTER")
overlay.text:SetJustifyV("MIDDLE")

overlay:RegisterForDrag("LeftButton")
overlay:SetScript("OnDragStart", function(self)
    if CueSenseDB and not CueSenseDB.visual.locked then self:StartMoving() end
end)
overlay:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    CueSenseDB.visual.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end)

-- Close button shown only while repositioning, so the overlay can be
-- locked from the screen (mirrors the OutOfRange movable frame). Sits in
-- the top-right corner and rides along with the overlay (child frame).
overlay.closeBtn = CreateFrame("Button", nil, overlay, "UIPanelCloseButton")
overlay.closeBtn:SetSize(28, 28)
overlay.closeBtn:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 4, 4)
overlay.closeBtn:Hide()
overlay.closeBtn:SetScript("OnClick", function()
    ns.SetRepositionMode(false)
    ns.OpenOptions()
end)

-- Backdrop applied only in reposition mode, so the box is visible to grab;
-- live cues draw as plain text with no border.
local REPOSITION_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function RestorePosition()
    overlay:ClearAllPoints()
    local p = CueSenseDB and CueSenseDB.visual and CueSenseDB.visual.position
    if p and p.point then
        overlay:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
    else
        overlay:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    end
end
ns.RestorePosition = RestorePosition

-- Hold-then-fade animation driven by OnUpdate (full alpha for the first
-- 60% of the duration, linear fade for the rest).
local fadeElapsed, fadeDuration = 0, 0
overlay:SetScript("OnUpdate", function(self, dt)
    if fadeDuration <= 0 then return end          -- idle / reposition mode
    fadeElapsed = fadeElapsed + dt
    local fadeStart = fadeDuration * 0.6
    if fadeElapsed >= fadeDuration then
        fadeDuration = 0
        self:SetAlpha(0)
        self:Hide()
    elseif fadeElapsed <= fadeStart then
        self:SetAlpha(1)
    else
        self:SetAlpha((fadeDuration - fadeElapsed) / (fadeDuration - fadeStart))
    end
end)

local function ShowVisual(message)
    local v = CueSenseDB.visual
    overlay.text:SetText(message)
    overlay.text:SetTextColor(v.color.r, v.color.g, v.color.b)
    overlay:SetScale(v.scale or 1.0)
    overlay:SetAlpha(1)
    fadeElapsed, fadeDuration = 0, (v.duration or 1.5)
    overlay:Show()
end
ns.ShowVisual = ShowVisual

-- Reposition / preview mode: pins the overlay open and mouse-interactive
-- so the user can drag it, then re-locks on exit.
function ns.SetRepositionMode(on)
    ns.testMode = on and true or false
    if on then
        CueSenseDB.visual.locked = false
        fadeDuration = 0
        overlay:SetBackdrop(REPOSITION_BACKDROP)
        overlay:SetBackdropColor(0, 0, 0, 0.6)
        overlay:SetBackdropBorderColor(0.20, 0.86, 0.75, 1)
        overlay:EnableMouse(true)
        overlay.text:SetText("CueSense — drag to move, X to close")
        overlay.text:SetTextColor(CueSenseDB.visual.color.r, CueSenseDB.visual.color.g, CueSenseDB.visual.color.b)
        overlay:SetScale(CueSenseDB.visual.scale or 1.0)
        overlay:SetAlpha(1)
        RestorePosition()
        overlay.closeBtn:Show()
        overlay:Show()
    else
        CueSenseDB.visual.locked = true
        overlay.closeBtn:Hide()
        overlay:SetBackdrop(nil)
        overlay:EnableMouse(false)
        fadeDuration = 0
        overlay:Hide()
    end
end

-- ---------------------------------------------------------------------
-- Cue dispatch
-- ---------------------------------------------------------------------
local function FireCue(cue, spellName, eventKind)
    -- Respect the per-kind master switches (buffs vs debuffs).
    if cue.kind == "debuff" then
        if not CueSenseDB.trackDebuffs then return end
    elseif not CueSenseDB.trackBuffs then
        return
    end
    local verb = (eventKind == "applied") and "gained" or "faded"
    local label = cue.label or spellName or "Aura"
    if CueSenseDB.audioEnabled and cue.sound then
        PlaySoundEntry(cue.sound, cue.channel or CueSenseDB.channel)
    end
    if cue.visual and CueSenseDB.visual.enabled and not ns.testMode then
        ShowVisual(label .. " " .. verb)
    end
end

-- Play a one-off sample using the global defaults (test button / slash).
function ns.PlayTestCue()
    PlaySoundEntry("rise", CueSenseDB.channel)
    if CueSenseDB.visual.enabled then ShowVisual("CueSense test") end
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
    if not CueSenseDB or not CueSenseDB.enabled then return end
    local cues = CueSenseDB.cues
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
    local cues = CueSenseDB and CueSenseDB.cues or {}
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
    CueSenseDB.cues[tostring(spellID)] = {
        applied  = true,
        faded    = true,
        sound    = "rise",
        channel  = nil,        -- nil = follow the global default channel
        visual   = true,
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
    local existed = CueSenseDB.cues[tostring(spellID)] ~= nil
    CueSenseDB.cues[tostring(spellID)] = nil
    return existed
end

function ns.CueCount()
    local n = 0
    for _ in pairs(CueSenseDB.cues) do n = n + 1 end
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
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        CueSenseDB = CueSenseDB or {}
        MergeDefaults(CueSenseDB, defaults)
        ValidateRanges(CueSenseDB)
        -- Backfill kind/category onto cues created before v0.5.0, and remap
        -- any sound key that no longer exists (e.g. the pre-v0.7 SOUNDKIT
        -- keys) onto a bundled tone. `false` (None / silent) is preserved.
        for _, cue in pairs(CueSenseDB.cues) do
            if not cue.kind then cue.kind = "buff" end
            if not cue.category then
                cue.category = (cue.kind == "debuff") and "Debuffs" or "Buffs"
            end
            if cue.sound then
                local known = false
                for _, e in ipairs(ns.SOUNDS) do
                    if e.key == cue.sound then known = true; break end
                end
                if not known then cue.sound = "rise" end
            end
        end
        RestorePosition()
        ns.InitOptions()
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
            for sid, cue in pairs(CueSenseDB.cues) do
                local modes = {}
                if cue.sound  then modes[#modes + 1] = "sound" end
                if cue.visual then modes[#modes + 1] = "visual" end
                print(string.format("  |cffffd200%s|r  %s  [%s]", sid,
                    cue.label or (C_Spell.GetSpellName(tonumber(sid)) or "?"),
                    table.concat(modes, "+")))
            end

        elseif cmd == "toggle" then
            CueSenseDB.enabled = not CueSenseDB.enabled
            chatPrint(CueSenseDB.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
            ns.RefreshOptions()

        elseif cmd == "lock" then
            ns.SetRepositionMode(false)
            chatPrint("overlay |cffff0000locked|r.")

        elseif cmd == "unlock" or cmd == "move" then
            ns.SetRepositionMode(true)
            chatPrint("overlay |cff00ff00unlocked|r — drag to move, then |cffffd200/cue lock|r.")

        elseif cmd == "reset" then
            CueSenseDB.visual.position = nil
            RestorePosition()
            chatPrint("overlay position reset.")

        elseif cmd == "forget" then
            CueSenseDB.seen = {}
            chatPrint("cleared the remembered-aura list (it refills as auras appear on you).")
            ns.RefreshOptions()

        elseif cmd == "status" then
            local seenN = 0
            for _ in pairs(CueSenseDB.seen) do seenN = seenN + 1 end
            chatPrint("status:")
            print("  enabled:        " .. tostring(CueSenseDB.enabled))
            print("  watched auras:  " .. ns.CueCount())
            print("  auras seen:     " .. seenN)
            print("  visual:         " .. tostring(CueSenseDB.visual.enabled)
                  .. " (scale " .. CueSenseDB.visual.scale
                  .. ", " .. CueSenseDB.visual.duration .. "s)")
            print("  audio channel:  " .. CueSenseDB.channel)
            print("  secret regime:  " .. tostring(issecret ~= nil))

        else
            chatPrint("commands:")
            print("  |cffffd200/cue|r                 open options")
            print("  |cffffd200/cue test|r            preview a cue")
            print("  |cffffd200/cue add <spellID>|r   watch an aura")
            print("  |cffffd200/cue remove <spellID>|r stop watching")
            print("  |cffffd200/cue list|r            list watched auras")
            print("  |cffffd200/cue toggle|r          enable/disable")
            print("  |cffffd200/cue unlock|r / |cffffd200lock|r   move the overlay")
            print("  |cffffd200/cue reset|r           reset overlay position")
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
        CueSenseDB.enabled = not CueSenseDB.enabled
        chatPrint(CueSenseDB.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
    else
        ns.OpenOptions()
    end
end

function CueSense_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("CueSense", 0.2, 0.86, 0.75)
    GameTooltip:AddLine(CueSenseDB.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r", 1, 1, 1)
    GameTooltip:AddLine("Watching " .. ns.CueCount() .. " aura(s)", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffd200Left-click:|r options", 1, 1, 1)
    GameTooltip:AddLine("|cffffd200Right-click:|r toggle enabled", 1, 1, 1)
    GameTooltip:Show()
end

function CueSense_OnCompartmentLeave()
    GameTooltip:Hide()
end
