-- Luacheck configuration for CueSense.
-- Run from repo root: luacheck *.lua

std = "lua51"

-- WoW addon UI strings often need to fit a single readable line.
max_line_length = 200

-- Globals the addon defines, owns, or writes to.
globals = {
    -- Saved variables (managed by WoW from the TOC's SavedVariables field)
    "CueSenseDB",
    -- Slash command registration
    "SLASH_CUESENSE1",
    "SLASH_CUESENSE2",
    -- Addon compartment hooks (must be globals; referenced from the TOC's
    -- AddonCompartmentFunc* fields)
    "CueSense_OnCompartmentClick",
    "CueSense_OnCompartmentEnter",
    "CueSense_OnCompartmentLeave",
    -- Blizzard tables we mutate
    "SlashCmdList",   -- /cue handler registration
}

-- Blizzard / WoW API globals the addon only reads from.
read_globals = {
    -- Frame + UI infrastructure
    "CreateFrame", "UIParent", "GetScreenHeight",
    "Settings", "SettingsPanel", "HideUIPanel",
    "ColorPickerFrame",
    "GameTooltip",
    -- Sound
    "PlaySound", "PlaySoundFile", "SOUNDKIT",
    -- Auras / spell data
    "C_UnitAuras", "AuraUtil", "C_Spell",
    -- Instance / unit identity (cue provenance: dungeon + source mob)
    "IsInInstance", "GetInstanceInfo", "UnitExists", "UnitName",
    -- Character identity (per-character profile key)
    "GetRealmName",
    -- Secret-value regime (Midnight 12.0+); nil on older clients
    "issecretvalue", "C_Secrets",
    -- Timing
    "C_Timer",
    -- Combat / protected-frame state
    "InCombatLockdown",
    -- Tables / misc
    "wipe", "ReloadUI",
}
