-- =====================================================================
-- CueSense - Options panel (scrollable canvas)
-- =====================================================================
-- Canvas categories don't clip or scroll their content; a ScrollFrame
-- inside the canvas does. Same layout pattern as DontRelease/OutOfRange.
--
-- v0.1.0 exposes the global cue settings (visual look, audio channel)
-- and a test/reposition path. The per-aura watch list is managed via
-- /cue add|remove|list for now; an in-panel editor is a later phase.
-- =====================================================================
local _, ns = ...

-- ---------------------------------------------------------------------
-- Panel + scroll container
-- ---------------------------------------------------------------------
local panel = CreateFrame("Frame", "CueSenseOptionsPanel")
panel.name = "CueSense"

local scroll = CreateFrame("ScrollFrame", "CueSenseOptionsScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 10, -10)
scroll:SetPoint("BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(580, 100)
scroll:SetScrollChild(content)
scroll:SetScript("OnSizeChanged", function(_, w)
    if w and w > 0 then content:SetWidth(w) end
end)

-- ---------------------------------------------------------------------
-- Layout helpers (running y cursor)
-- ---------------------------------------------------------------------
local LEFT = 18
local y = -14
local widgets = {}

local function AddHeader(text)
    y = y - 8
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", LEFT, y)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    y = y - 22
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.12)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", LEFT, y)
    line:SetPoint("TOPRIGHT", -18, y)
    y = y - 12
end

local function AddDescription(text)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", LEFT, y)
    fs:SetWidth(520)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    y = y - (fs:GetStringHeight() + 10)
end

local function AddCheckbox(label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", LEFT, y)
    cb:SetSize(26, 26)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb.Refresh = function() cb:SetChecked(getter() and true or false) end
    widgets[#widgets + 1] = cb
    y = y - 30
    return cb
end

local function AddSlider(label, minV, maxV, step, fmt, getter, setter)
    y = y - 4
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", LEFT, y)
    title:SetText(label)
    local valFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    y = y - 18

    local s = CreateFrame("Slider", nil, content)
    s:SetPoint("TOPLEFT", LEFT + 4, y)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(360, 18)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(20, 20) end
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.45)
    track:SetHeight(6)
    track:SetPoint("LEFT", 4, 0)
    track:SetPoint("RIGHT", -4, 0)
    valFS:SetPoint("LEFT", s, "RIGHT", 14, 0)
    s:SetScript("OnValueChanged", function(_, v)
        local stepped = math.floor((v / step) + 0.5) * step
        valFS:SetText(fmt and string.format(fmt, stepped) or tostring(stepped))
        setter(stepped)
    end)
    s.Refresh = function()
        local v = getter() or minV
        s:SetValue(v)
        valFS:SetText(fmt and string.format(fmt, v) or tostring(v))
    end
    widgets[#widgets + 1] = s
    y = y - 32
    return s
end

local function AddDropdown(label, width)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", LEFT, y)
    title:SetText(label)
    y = y - 22
    local dd = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", LEFT + 6, y)
    dd:SetSize(width or 280, 30)
    y = y - 40
    return dd
end

local function AddButton(label, width, onClick)
    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", LEFT + 6, y)
    b:SetSize(width or 160, 24)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    y = y - 32
    return b
end

local function AddSideBySideButtons(...)
    local args = {...}
    local count = #args / 2
    local x = LEFT + 6
    for i = 1, count do
        local label = args[(i - 1) * 2 + 1]
        local onClick = args[(i - 1) * 2 + 2]
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", x, y)
        b:SetSize(180, 24)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        x = x + 188
    end
    y = y - 32
end

local function AddGap(px)
    y = y - (px or 10)
end

-- ---------------------------------------------------------------------
-- Title / subtitle
-- ---------------------------------------------------------------------
local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", LEFT, y)
title:SetText("CueSense")
y = y - 22

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", LEFT, y)
subtitle:SetText("Turn your own auras into sound and/or on-screen cues.")
y = y - 14

-- ---------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------
AddHeader("General")

AddCheckbox("Enable CueSense",
    function() return CueSenseDB.enabled end,
    function(v) CueSenseDB.enabled = v end)

-- ---------------------------------------------------------------------
-- Visual cue
-- ---------------------------------------------------------------------
AddHeader("Visual cue")
AddDescription("The on-screen flash shown when a watched aura is gained or fades. " ..
    "This is the channel deaf / hard-of-hearing players rely on.")

AddCheckbox("Show on-screen flash",
    function() return CueSenseDB.visual.enabled end,
    function(v) CueSenseDB.visual.enabled = v end)

-- Flash color
local colorBtn = AddButton("Flash color...", 140, function() end)
local swatch = colorBtn:CreateTexture(nil, "OVERLAY")
swatch:SetSize(14, 14)
swatch:SetPoint("LEFT", colorBtn, "LEFT", 8, 0)
local colorBtnText = colorBtn:GetFontString()
if colorBtnText then
    colorBtnText:ClearAllPoints()
    colorBtnText:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    colorBtnText:SetPoint("RIGHT", colorBtn, "RIGHT", -8, 0)
end
colorBtn:SetScript("OnClick", function()
    local c = CueSenseDB.visual.color
    local function apply(prev)
        local nr, ng, nb
        if prev then
            nr, ng, nb = prev.r or prev[1], prev.g or prev[2], prev.b or prev[3]
        else
            nr, ng, nb = ColorPickerFrame:GetColorRGB()
        end
        if not (nr and ng and nb) then return end
        c.r, c.g, c.b = nr, ng, nb
        swatch:SetColorTexture(nr, ng, nb)
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = c.r, g = c.g, b = c.b,
        swatchFunc = function() apply() end,
        cancelFunc = function(prev) apply(prev) end,
        hasOpacity = false,
    })
end)
colorBtn.Refresh = function()
    local c = CueSenseDB.visual.color
    swatch:SetColorTexture(c.r, c.g, c.b)
end
widgets[#widgets + 1] = colorBtn

AddSlider("Flash size", 0.5, 3.0, 0.05, "%.2fx",
    function() return CueSenseDB.visual.scale end,
    function(v) CueSenseDB.visual.scale = v end)

AddSlider("On-screen time", 0.5, 8.0, 0.1, "%.1fs",
    function() return CueSenseDB.visual.duration end,
    function(v) CueSenseDB.visual.duration = v end)

AddSideBySideButtons(
    "Move overlay", function()
        ns.SetRepositionMode(true)
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    end,
    "Reset position", function()
        CueSenseDB.visual.position = nil
        ns.RestorePosition()
    end)

-- ---------------------------------------------------------------------
-- Audio cue
-- ---------------------------------------------------------------------
AddHeader("Audio cue")
AddDescription("The sound played when a watched aura changes. Per-aura sounds are set " ..
    "with /cue; this is the audio channel they route through (so blind / low-vision " ..
    "players can balance cue volume against game audio).")

local channelDropdown = AddDropdown("Audio channel", 200)
channelDropdown:SetDefaultText("Choose a channel")
channelDropdown:SetupMenu(function(_, root)
    for _, c in ipairs(ns.CHANNELS) do
        local key = c
        root:CreateRadio(key,
            function() return CueSenseDB and CueSenseDB.channel == key end,
            function()
                if not CueSenseDB then return end
                CueSenseDB.channel = key
                C_Timer.After(0, function() channelDropdown:GenerateMenu() end)
            end)
    end
end)
channelDropdown.Refresh = function() channelDropdown:GenerateMenu() end
widgets[#widgets + 1] = channelDropdown

AddButton("Play test cue", 160, function() ns.PlayTestCue() end)

-- ---------------------------------------------------------------------
-- Watched auras
-- ---------------------------------------------------------------------
AddHeader("Watched auras")

local watchInfo = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
watchInfo:SetPoint("TOPLEFT", LEFT, y)
watchInfo:SetWidth(520)
watchInfo:SetJustifyH("LEFT")
y = y - 20
watchInfo.Refresh = function()
    local n = ns.CueCount()
    watchInfo:SetText("Currently watching |cffffd200" .. n .. "|r aura" .. (n == 1 and "" or "s") .. ".")
end
widgets[#widgets + 1] = watchInfo

AddDescription("Add an aura by its spell ID: |cffffd200/cue add <spellID>|r  (e.g. /cue add 2825 for Bloodlust). " ..
    "Remove with |cffffd200/cue remove <spellID>|r and review with |cffffd200/cue list|r. " ..
    "A point-and-click editor for per-aura sound and applied/faded triggers is on the way.")

AddButton("Print watched list to chat", 220, function()
    SlashCmdList["CUESENSE"]("list")
end)

AddGap(16)

-- Lock content height so the scrollbar appears on overflow.
content:SetHeight(-y + 20)

-- ---------------------------------------------------------------------
-- Refresh + registration
-- ---------------------------------------------------------------------
local function RefreshAll()
    if not CueSenseDB then return end
    for _, w in ipairs(widgets) do
        if w.Refresh then w.Refresh() end
    end
end
ns.RefreshOptions = RefreshAll

panel:SetScript("OnShow", RefreshAll)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "CueSense")
    Settings.RegisterAddOnCategory(category)
end

function ns.InitOptions() RefreshAll() end

function ns.OpenOptions()
    if not category then return end
    RefreshAll()
    C_Timer.After(0, function()
        Settings.OpenToCategory(category:GetID())
    end)
end
