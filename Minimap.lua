-- =====================================================================
-- CueSense - Minimap.lua
-- =====================================================================
-- LibDataBroker launcher + LibDBIcon minimap button.
--
-- The libraries are NOT committed to this repo. The BigWigs packager
-- fetches them fresh at build time (see the `externals` block in .pkgmeta),
-- so they're present in released builds but absent in a local dev checkout.
-- When they're absent the button simply doesn't appear and nothing errors —
-- the rest of the addon is unaffected.
-- =====================================================================
local _, ns = ...

local ICON_NAME = "CueSense"

local LDB     = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0",      true)

-- Defined even without the libraries so the options "Show minimap button"
-- checkbox still toggles the saved preference in a lib-less dev checkout.
function ns.SetMinimapShown(shown)
    if not (CueSenseDB and CueSenseDB.minimap) then return end
    CueSenseDB.minimap.hide = not shown
    if LDBIcon then
        if shown then LDBIcon:Show(ICON_NAME) else LDBIcon:Hide(ICON_NAME) end
    end
end

function ns.IsMinimapShown()
    return not (CueSenseDB and CueSenseDB.minimap and CueSenseDB.minimap.hide)
end

if not LDB or not LDBIcon then return end   -- no libraries: no button, no error

local launcher = LDB:NewDataObject(ICON_NAME, {
    type = "launcher",
    text = "CueSense",
    icon = "Interface\\AddOns\\CueSense\\Icon.png",

    OnClick = function(_, button)
        if button == "RightButton" then
            local p = ns.P and ns.P()
            if p then
                p.enabled = not p.enabled
                if ns.chatPrint then
                    ns.chatPrint(p.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
                end
                if ns.RefreshOptions then ns.RefreshOptions() end
            end
        elseif ns.ToggleOptions then
            ns.ToggleOptions()
        elseif ns.OpenOptions then
            ns.OpenOptions()
        end
    end,

    OnTooltipShow = function(tt)
        tt:AddLine("CueSense", 0.20, 0.86, 0.75)
        local p = ns.P and ns.P()
        if p then
            tt:AddLine(p.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
        end
        if ns.CueCount then
            tt:AddLine("Watching " .. ns.CueCount() .. " aura(s)", 0.8, 0.8, 0.8)
        end
        tt:AddLine(" ")
        tt:AddLine("|cffffd200Left-click|r: open / close options", 0.7, 0.7, 0.7)
        tt:AddLine("|cffffd200Right-click|r: toggle on / off", 0.7, 0.7, 0.7)
    end,
})

-- LibDBIcon stores its position/hide state in the db table we pass, so it
-- must be persistent. Register on PLAYER_LOGIN (after the account-wide DB
-- exists).
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    CueSenseDB = CueSenseDB or {}
    CueSenseDB.minimap = CueSenseDB.minimap or { hide = false }
    LDBIcon:Register(ICON_NAME, launcher, CueSenseDB.minimap)
end)
