-- =====================================================================
-- CueSense - Options panel (scrollable canvas)
-- =====================================================================
-- Canvas categories don't clip or scroll their content; a ScrollFrame
-- inside the canvas does. Same layout pattern as DontRelease/OutOfRange.
-- All tracked-setting reads go through ns.P() (the active profile); the
-- account-wide seen catalog is reached via ns.GetSeenAuras().
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
    function() return ns.P().enabled end,
    function(v) ns.P().enabled = v end)
AddCheckbox("Track buffs (helpful auras)",
    function() return ns.P().trackBuffs end,
    function(v) ns.P().trackBuffs = v end)
AddCheckbox("Track debuffs (harmful auras)",
    function() return ns.P().trackDebuffs end,
    function(v) ns.P().trackDebuffs = v end)

-- (Visual-window appearance is configured per-kind, under the Buffs /
-- Debuffs tabs further down.)

-- ---------------------------------------------------------------------
-- Audio cue
-- ---------------------------------------------------------------------
AddHeader("Audio cue")

AddCheckbox("Play sound cues",
    function() return ns.P().audioEnabled end,
    function(v) ns.P().audioEnabled = v end)

AddDescription("Master switch for all cue sounds. Each aura's sound (or no sound) " ..
    "is set per-row below; this is the audio channel they route through, so blind / " ..
    "low-vision players can balance cue volume against game audio.")

local channelDropdown = AddDropdown("Audio channel", 200)
channelDropdown:SetDefaultText("Choose a channel")
channelDropdown:SetupMenu(function(_, root)
    for _, c in ipairs(ns.CHANNELS) do
        local key = c
        root:CreateRadio(key,
            function() return ns.P() and ns.P().channel == key end,
            function()
                if not ns.P() then return end
                ns.P().channel = key
                C_Timer.After(0, function() channelDropdown:GenerateMenu() end)
            end)
    end
end)
channelDropdown.Refresh = function() channelDropdown:GenerateMenu() end
widgets[#widgets + 1] = channelDropdown

AddButton("Play test cue", 160, function() ns.PlayTestCue() end)

-- ---------------------------------------------------------------------
-- Watched auras (in-panel editor)
-- ---------------------------------------------------------------------
-- The list below is rebuilt on demand from ns.P().cues. Rows are
-- pooled (created once, reused) and the scroll content height is
-- recomputed from the editor's bottom each rebuild. Forward-declare the
-- pieces that reference each other (rows reference RebuildList to refresh
-- after a remove; RebuildList builds rows via MakeRow).
local ROW_H = 54   -- two lines: name/toggles/group on top, sounds below
local HEADER_H = 22
local rows = {}
local headers = {}
local activeTab = "buff"   -- which kind the editor is currently showing
local RebuildList
local MakeRow
local MakeHeader
local UpdateTabs

-- The visual-window config for the tab currently being edited.
local function ActiveVis() return ns.P().visual[activeTab] end

AddHeader("Watched auras")

local watchInfo = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
watchInfo:SetPoint("TOPLEFT", LEFT, y)
watchInfo:SetWidth(520)
watchInfo:SetJustifyH("LEFT")
y = y - 22
watchInfo.Refresh = function()
    local n = ns.CueCount()
    watchInfo:SetText("Watching |cffffd200" .. n .. "|r aura" .. (n == 1 and "" or "s")
        .. " total.   |cff808080A = gained · F = faded · V = visual · hover a row for its source|r")
end
widgets[#widgets + 1] = watchInfo

-- Feedback line (declared first so the picker / by-ID closures below can
-- reference it).
local addStatus = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
addStatus:SetWidth(500)
addStatus:SetJustifyH("LEFT")

-- Primary "Add": pick from auras seen on you, shown with icon + name.
-- Only auras you've actually had appear here, so everything listed
-- genuinely tracks (abilities that put no aura on you never show up).
local pickerSearch = ""
local pickerMineOnly = false   -- filter the picker to auras the player cast

local pickLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
pickLabel:SetPoint("TOPLEFT", LEFT, y)
pickLabel:SetText("Add an aura:")

local addDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
addDD:SetPoint("LEFT", pickLabel, "RIGHT", 12, 0)
addDD:SetSize(240, 30)
addDD:SetDefaultText("Choose an aura you've had")

-- Search field: filters the picker by name or spell ID.
local searchLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
searchLabel:SetPoint("LEFT", addDD, "RIGHT", 16, 0)
searchLabel:SetText("Search")
local searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
searchBox:SetSize(140, 22)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("ChatFontNormal")

-- Live results popup: shows matching auras as you type (the list shrinks as
-- you narrow the search), so you can pick without opening the dropdown. It
-- floats over the content below and hides when the search is cleared.
local MAX_RESULTS = 10
local RESULT_H = 20
local resultBtns = {}
local searchResults = CreateFrame("Frame", nil, content, "BackdropTemplate")
searchResults:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -3)
searchResults:SetWidth(320)
searchResults:SetFrameLevel(content:GetFrameLevel() + 20)
searchResults:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
searchResults:SetBackdropColor(0, 0, 0, 0.92)
searchResults:Hide()

local moreText = searchResults:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
moreText:SetJustifyH("LEFT")

local UpdateSearchResults   -- forward (result buttons reference it)

local function MakeResultBtn(i)
    local b = CreateFrame("Button", nil, searchResults)
    b:SetHeight(RESULT_H)
    b:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 6, -6 - (i - 1) * RESULT_H)
    b:SetPoint("TOPRIGHT", searchResults, "TOPRIGHT", -6, -6 - (i - 1) * RESULT_H)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b:SetScript("OnClick", function(self)
        if not self.spellID then return end
        if ns.P().cues[tostring(self.spellID)] then
            addStatus:SetText("|cffffd200Already watching " .. (self.auraName or self.spellID) .. ".|r")
        else
            ns.AddCue(self.spellID)
            addStatus:SetText("|cff60ff60Added " .. (self.auraName or self.spellID) .. ".|r")
            if watchInfo.Refresh then watchInfo.Refresh() end
            RebuildList()
        end
        UpdateSearchResults()   -- refresh the (watching) markers
    end)
    b:SetScript("OnEnter", function(self)
        if self.spellID and GameTooltip.SetSpellByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    resultBtns[i] = b
    return b
end

UpdateSearchResults = function()
    if pickerSearch == "" or not ns.P() then searchResults:Hide(); return end
    local auras = ns.GetSeenAuras()
    local shown, more = 0, 0
    for _, sp in ipairs(auras) do
        local nm = sp.name or ("Spell " .. sp.spellID)
        local matchText = nm:lower():find(pickerSearch, 1, true) or tostring(sp.spellID):find(pickerSearch, 1, true)
        if matchText and (not pickerMineOnly or sp.mine) then
            if shown < MAX_RESULTS then
                shown = shown + 1
                local b = resultBtns[shown] or MakeResultBtn(shown)
                b.spellID = sp.spellID
                b.auraName = nm
                b.icon:SetTexture(sp.icon or 134400)
                local mark = ns.P().cues[tostring(sp.spellID)] and "  |cff808080(watching)|r" or ""
                b.text:SetText(nm .. mark)
                b:Show()
            else
                more = more + 1
            end
        end
    end
    for i = shown + 1, #resultBtns do resultBtns[i]:Hide() end
    if shown == 0 then searchResults:Hide(); return end
    local h = 12 + shown * RESULT_H
    if more > 0 then
        moreText:ClearAllPoints()
        moreText:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 8, -6 - shown * RESULT_H)
        moreText:SetText("…and " .. more .. " more — keep typing")
        moreText:Show()
        h = h + 16
    else
        moreText:Hide()
    end
    searchResults:SetHeight(h)
    searchResults:Show()
    searchResults:Raise()
end

searchBox:SetScript("OnTextChanged", function(self)
    pickerSearch = (self:GetText() or ""):lower():trim()
    UpdateSearchResults()
    addDD:GenerateMenu()   -- keep the dropdown filtered too, if opened
end)
searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
    searchResults:Hide()
end)

addDD:SetupMenu(function(_, root)
    -- SetupMenu populates once at load, before ADDON_LOADED creates the
    -- saved variables. Bail until the DB exists; the menu regenerates on
    -- every open, so it fills in normally once the player is logged in.
    if not ns.P() then return end
    -- Cap the menu height so a long list scrolls instead of running off
    -- the bottom of the screen (reported at 1920x1080).
    if root.SetScrollMode then root:SetScrollMode(GetScreenHeight() * 0.6) end
    local auras = ns.GetSeenAuras()
    local shown = 0
    for _, sp in ipairs(auras) do
        local sid = sp.spellID
        local nm = sp.name or ("Spell " .. sid)
        local matchText = pickerSearch == ""
            or nm:lower():find(pickerSearch, 1, true)
            or tostring(sid):find(pickerSearch, 1, true)
        if matchText and (not pickerMineOnly or sp.mine) then
            shown = shown + 1
            local icon = sp.icon or 134400
            local label = string.format("|T%d:16:16:0:0|t %s", icon, nm)
            if ns.P().cues[tostring(sid)] then
                label = label .. "  |cff808080(watching)|r"
            end
            if sp.secret then
                label = label .. "  |cffff6060(may be hidden in instances)|r"
            end
            local btn = root:CreateButton(label, function()
                if ns.P().cues[tostring(sid)] then
                    addStatus:SetText("|cffffd200Already watching " .. nm .. ".|r")
                    return
                end
                ns.AddCue(sid)
                addStatus:SetText("|cff60ff60Added " .. nm .. ".|r")
                if watchInfo.Refresh then watchInfo.Refresh() end
                RebuildList()
            end)
            -- Show the spell's own tooltip while the entry is highlighted.
            if btn and btn.SetTooltip then
                btn:SetTooltip(function(tooltip)
                    if tooltip and tooltip.SetSpellByID then tooltip:SetSpellByID(sid) end
                end)
            end
        end
    end
    if shown == 0 then
        root:CreateButton(
            (#auras == 0) and "|cff808080No auras seen yet — get buffed or fight, then reopen|r"
            or "|cff808080No matches for that search|r",
            function() end)
    end
end)
y = y - 38

AddCheckbox("Only show auras I cast",
    function() return pickerMineOnly end,
    function(v)
        pickerMineOnly = v
        addDD:GenerateMenu()
        UpdateSearchResults()
    end)

-- Secondary "Add": by raw spell ID, for an aura you haven't had yet (so
-- it isn't in the list above) — a boss debuff, a proc, another player's
-- buff. The list above fills in on its own as auras appear on you.
local addLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
addLabel:SetPoint("TOPLEFT", LEFT, y)
addLabel:SetText("…or by spell ID:")

local addBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
addBox:SetPoint("LEFT", addLabel, "RIGHT", 12, 0)
addBox:SetSize(90, 22)
addBox:SetAutoFocus(false)
addBox:SetNumeric(true)
addBox:SetFontObject("ChatFontNormal")

local addBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
addBtn:SetPoint("LEFT", addBox, "RIGHT", 8, 0)
addBtn:SetSize(60, 22)
addBtn:SetText("Add")

local function DoAdd()
    local txt = (addBox:GetText() or ""):trim()
    local id = tonumber(txt)
    if not id then
        addStatus:SetText("|cffff6060Enter a spell ID number.|r")
        return
    end
    if ns.P().cues[tostring(id)] then
        addStatus:SetText("|cffffd200Already watching that.|r")
        return
    end
    local nm = C_Spell.GetSpellName(id)
    if not nm then
        addStatus:SetText("|cffff6060Unknown spell ID " .. id .. ".|r")
        return
    end
    ns.AddCue(id)
    addBox:SetText("")
    local note = ns.IsSpellAuraSecret(id) and "  |cffff6060(may be hidden in instances)|r" or ""
    addStatus:SetText("|cff60ff60Added " .. nm .. ".|r" .. note)
    if watchInfo.Refresh then watchInfo.Refresh() end
    RebuildList()
end
addBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoAdd() end)
addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
addBtn:SetScript("OnClick", DoAdd)
y = y - 28

addStatus:SetPoint("TOPLEFT", LEFT, y)
y = y - 20

-- Brief grouping tip
local groupHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
groupHint:SetPoint("TOPLEFT", LEFT, y)
groupHint:SetWidth(520)
groupHint:SetJustifyH("LEFT")
groupHint:SetText("Buffs and debuffs have separate tabs. Debuffs file under the dungeon they were " ..
    "first seen in; type a Group on any row to re-file it. (Hover a row for its source mob — " ..
    "often hidden by the game inside instances.)")
y = y - 34

-- Buffs / Debuffs tabs — filter the list below by kind.
local buffsTab = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
buffsTab:SetPoint("TOPLEFT", LEFT, y)
buffsTab:SetSize(130, 24)
local debuffsTab = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
debuffsTab:SetPoint("LEFT", buffsTab, "RIGHT", 8, 0)
debuffsTab:SetSize(130, 24)
y = y - 30

UpdateTabs = function()
    local b, d = 0, 0
    if ns.P() then
        for _, cue in pairs(ns.P().cues) do
            if cue.kind == "debuff" then d = d + 1 else b = b + 1 end
        end
    end
    buffsTab:SetText("Buffs (" .. b .. ")")
    debuffsTab:SetText("Debuffs (" .. d .. ")")
    if activeTab == "debuff" then
        debuffsTab:LockHighlight(); buffsTab:UnlockHighlight()
    else
        buffsTab:LockHighlight(); debuffsTab:UnlockHighlight()
    end
end
-- Switching tabs re-points the per-kind window settings below at the other
-- kind and refilters the list, so a full refresh is what we want here.
buffsTab:SetScript("OnClick", function() activeTab = "buff"; ns.RefreshOptions() end)
debuffsTab:SetScript("OnClick", function() activeTab = "debuff"; ns.RefreshOptions() end)
UpdateTabs()

-- ---------------------------------------------------------------------
-- Window appearance for the active tab's kind (buffs or debuffs). One set
-- of widgets bound to the active kind's config; they re-read on tab switch.
-- ---------------------------------------------------------------------
AddCheckbox("Show on-screen flash for these",
    function() return ActiveVis().enabled end,
    function(v) ActiveVis().enabled = v end)

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
    local c = ActiveVis().color
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
    local c = ActiveVis().color
    swatch:SetColorTexture(c.r, c.g, c.b)
end
widgets[#widgets + 1] = colorBtn

AddSlider("Flash size", 0.5, 3.0, 0.05, "%.2fx",
    function() return ActiveVis().scale end,
    function(v) ActiveVis().scale = v end)

AddSlider("On-screen time", 0.5, 8.0, 0.1, "%.1fs",
    function() return ActiveVis().duration end,
    function(v) ActiveVis().duration = v end)

AddSideBySideButtons(
    "Move window", function()
        ns.SetRepositionMode(activeTab, true)
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    end,
    "Reset position", function()
        ActiveVis().position = nil
        ns.RestorePosition(activeTab)
    end)

AddButton("Test this window", 160, function() ns.TestWindow(activeTab) end)

-- Column headers above the list
local function ColHeader(text, xoff)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", LEFT + xoff, y)
    fs:SetText(text)
end
ColHeader("Aura", 4)
ColHeader("A", 248)
ColHeader("F", 278)
ColHeader("V", 308)
ColHeader("Group", 338)
y = y - 14

-- Editor container; rows are anchored inside it.
local editorTopY = y
local editor = CreateFrame("Frame", nil, content)
editor:SetPoint("TOPLEFT", LEFT, editorTopY)
editor:SetPoint("TOPRIGHT", -18, editorTopY)
editor:SetHeight(ROW_H)

local emptyText = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
emptyText:SetPoint("TOPLEFT", LEFT + 4, editorTopY - 7)
emptyText:SetText("No auras watched yet — add one above.")

-- Section header (one per category group); pooled, anchored in RebuildList.
MakeHeader = function(i)
    local fs = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetTextColor(1, 0.82, 0)
    fs:SetJustifyH("LEFT")
    headers[i] = fs
    return fs
end

MakeRow = function(i)
    local row = CreateFrame("Frame", nil, editor)
    row:SetHeight(ROW_H)
    row:SetWidth(540)   -- anchored by RebuildList (grouped layout)

    -- Faint divider along the bottom so the two-line entries don't blur
    -- together.
    row.sep = row:CreateTexture(nil, "BACKGROUND")
    row.sep:SetColorTexture(1, 1, 1, 0.08)
    row.sep:SetHeight(1)
    row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 2)
    row.sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)

    -- Hover the row to see the aura's source (mob / dungeon) when known.
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local cue = self.spellID and ns.P().cues[self.spellID]
        if not cue then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local sid = tonumber(self.spellID)
        if sid and GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(sid)          -- the spell's own tooltip
        else
            GameTooltip:SetText(cue.label or "Aura", 1, 1, 1)
        end
        if cue.source then GameTooltip:AddLine("Source: " .. cue.source, 0.8, 0.8, 0.8) end
        if cue.dungeon then GameTooltip:AddLine("Dungeon: " .. cue.dungeon, 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Line 1: name, A/F/V toggles, Group, remove.
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -6)
    row.name:SetWidth(232)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    local function MkCheck(xoff, field)
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", row, "TOPLEFT", xoff, -3)
        cb:SetScript("OnClick", function(self)
            local cue = row.spellID and ns.P().cues[row.spellID]
            if cue then cue[field] = self:GetChecked() and true or false end
        end)
        return cb
    end
    row.applied = MkCheck(244, "applied")
    row.faded   = MkCheck(274, "faded")
    row.visual  = MkCheck(304, "visual")

    -- A sound dropdown bound to a given cue field (soundApplied / soundFaded);
    -- "None" makes that event silent (false). Audio stays optional per event.
    local function MkSoundDD(xoff, yoff, field)
        local dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", row, "TOPLEFT", xoff, yoff)
        dd:SetSize(150, 26)
        dd:SetupMenu(function(_, rootMenu)
            rootMenu:CreateRadio("None (silent)",
                function()
                    local c = row.spellID and ns.P().cues[row.spellID]
                    return c and not c[field]
                end,
                function()
                    local c = row.spellID and ns.P().cues[row.spellID]
                    if not c then return end
                    c[field] = false
                    C_Timer.After(0, function() dd:GenerateMenu() end)
                end)
            for _, item in ipairs(ns.SOUNDS) do
                local key = item.key
                rootMenu:CreateRadio(item.label,
                    function()
                        local c = row.spellID and ns.P().cues[row.spellID]
                        return c and c[field] == key
                    end,
                    function()
                        local c = row.spellID and ns.P().cues[row.spellID]
                        if not c then return end
                        c[field] = key
                        ns.PlaySoundEntry(key, c.channel or ns.P().channel)
                        C_Timer.After(0, function() dd:GenerateMenu() end)
                    end)
            end
        end)
        return dd
    end

    local function MkPreview(xoff, yoff, eventKind)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(24, 22)
        b:SetPoint("TOPLEFT", row, "TOPLEFT", xoff, yoff)
        b:SetText(">")
        b:SetScript("OnClick", function()
            if row.spellID then ns.PreviewCue(row.spellID, eventKind) end
        end)
        return b
    end

    -- Line 2: "Gained" sound + preview, "Faded" sound + preview.
    local gainLbl = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    gainLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -34)
    gainLbl:SetText("Gained")
    row.soundApplied = MkSoundDD(58, -30, "soundApplied")
    row.previewA = MkPreview(212, -30, "applied")

    local fadeLbl = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fadeLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 250, -34)
    fadeLbl:SetText("Faded")
    row.soundFaded = MkSoundDD(296, -30, "soundFaded")
    row.previewF = MkPreview(450, -30, "faded")

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(24, 24)
    row.remove:SetPoint("TOPLEFT", row, "TOPLEFT", 496, -3)
    row.remove:SetScript("OnClick", function()
        if not row.spellID then return end
        ns.RemoveCue(row.spellID)
        if watchInfo.Refresh then watchInfo.Refresh() end
        RebuildList()
    end)

    -- Free-text group/category; type a dungeon name etc. to re-file the aura.
    row.cat = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.cat:SetPoint("TOPLEFT", row, "TOPLEFT", 338, -5)
    row.cat:SetSize(150, 22)
    row.cat:SetAutoFocus(false)
    row.cat:SetFontObject("ChatFontNormal")
    -- Commit on focus loss only; rebuild solely when the value actually
    -- changed (avoids a rebuild — and re-entrant focus events — when the
    -- box is left untouched).
    row.cat:SetScript("OnEditFocusLost", function(self)
        local cue = row.spellID and ns.P().cues[row.spellID]
        if not cue then return end
        local t = (self:GetText() or ""):trim()
        local newCat = (t ~= "" and t) or ((cue.kind == "debuff") and "Debuffs" or "Buffs")
        if newCat == cue.category then return end
        cue.category = newCat
        RebuildList()
    end)
    row.cat:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    row.cat:SetScript("OnEscapePressed", function(self)
        local cue = row.spellID and ns.P().cues[row.spellID]
        self:SetText(cue and cue.category or "")
        self:ClearFocus()
    end)

    rows[i] = row
    return row
end

RebuildList = function()
    if not ns.P() then return end

    -- Group cues by category. Buffs/Debuffs are the default groups; a
    -- user-typed category re-files an aura under its own heading.
    local groups, total = {}, 0
    for sid, cue in pairs(ns.P().cues) do
        local k = (cue.kind == "debuff") and "debuff" or "buff"
        if k == activeTab then
            local cat = cue.category or ((k == "debuff") and "Debuffs" or "Buffs")
            groups[cat] = groups[cat] or {}
            local g = groups[cat]
            g[#g + 1] = sid
            total = total + 1
        end
    end
    local cats = {}
    for cat in pairs(groups) do cats[#cats + 1] = cat end
    local rank = { Buffs = 1, Debuffs = 2 }
    table.sort(cats, function(a, b)
        local ra, rb = rank[a] or 3, rank[b] or 3
        if ra ~= rb then return ra < rb end
        return a < b
    end)

    -- Lay out header + rows top-to-bottom, reusing pooled widgets.
    local yOff, rowIdx, hdrIdx = 0, 0, 0
    for _, cat in ipairs(cats) do
        hdrIdx = hdrIdx + 1
        local hdr = headers[hdrIdx] or MakeHeader(hdrIdx)
        hdr:ClearAllPoints()
        hdr:SetPoint("TOPLEFT", editor, "TOPLEFT", 2, -yOff)
        hdr:SetText(cat .. "  |cff808080(" .. #groups[cat] .. ")|r")
        hdr:Show()
        yOff = yOff + HEADER_H

        local sids = groups[cat]
        table.sort(sids, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
        for _, sid in ipairs(sids) do
            rowIdx = rowIdx + 1
            local row = rows[rowIdx] or MakeRow(rowIdx)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, -yOff)
            row.spellID = sid
            local cue = ns.P().cues[sid]
            local nm = cue.label or C_Spell.GetSpellName(tonumber(sid)) or "Unknown"
            row.name:SetText(nm .. "  |cff808080(" .. sid .. ")|r")
            row.applied:SetChecked(cue.applied and true or false)
            row.faded:SetChecked(cue.faded and true or false)
            row.visual:SetChecked(cue.visual and true or false)
            row.cat:SetText(cue.category or "")
            row.soundApplied:GenerateMenu()
            row.soundFaded:GenerateMenu()
            row:Show()
            yOff = yOff + ROW_H
        end
    end
    for i = rowIdx + 1, #rows do rows[i]:Hide() end
    for i = hdrIdx + 1, #headers do headers[i]:Hide() end

    local listH = math.max(yOff, ROW_H)
    editor:SetHeight(listH)
    if total == 0 then
        emptyText:SetText(activeTab == "debuff" and "No debuffs watched yet." or "No buffs watched yet.")
        emptyText:Show()
    else
        emptyText:Hide()
    end
    if UpdateTabs then UpdateTabs() end

    -- Recompute scroll content height from the editor's bottom.
    content:SetHeight(-editorTopY + listH + 30)
end
ns.RebuildList = RebuildList

-- ---------------------------------------------------------------------
-- Refresh + registration
-- ---------------------------------------------------------------------
local function RefreshAll()
    if not ns.P() then return end
    for _, w in ipairs(widgets) do
        if w.Refresh then w.Refresh() end
    end
    if RebuildList then RebuildList() end
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
