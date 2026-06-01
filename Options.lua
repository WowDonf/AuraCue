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
AddCheckbox("Track buffs (helpful auras)",
    function() return CueSenseDB.trackBuffs end,
    function(v) CueSenseDB.trackBuffs = v end)
AddCheckbox("Track debuffs (harmful auras)",
    function() return CueSenseDB.trackDebuffs end,
    function(v) CueSenseDB.trackDebuffs = v end)

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

AddCheckbox("Play sound cues",
    function() return CueSenseDB.audioEnabled end,
    function(v) CueSenseDB.audioEnabled = v end)

AddDescription("Master switch for all cue sounds. Each aura's sound (or no sound) " ..
    "is set per-row below; this is the audio channel they route through, so blind / " ..
    "low-vision players can balance cue volume against game audio.")

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
-- Watched auras (in-panel editor)
-- ---------------------------------------------------------------------
-- The list below is rebuilt on demand from CueSenseDB.cues. Rows are
-- pooled (created once, reused) and the scroll content height is
-- recomputed from the editor's bottom each rebuild. Forward-declare the
-- pieces that reference each other (rows reference RebuildList to refresh
-- after a remove; RebuildList builds rows via MakeRow).
local ROW_H = 30
local HEADER_H = 22
local rows = {}
local headers = {}
local RebuildList
local MakeRow
local MakeHeader

AddHeader("Watched auras")

local watchInfo = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
watchInfo:SetPoint("TOPLEFT", LEFT, y)
watchInfo:SetWidth(520)
watchInfo:SetJustifyH("LEFT")
y = y - 22
watchInfo.Refresh = function()
    local n = ns.CueCount()
    watchInfo:SetText("Watching |cffffd200" .. n .. "|r aura" .. (n == 1 and "" or "s")
        .. ".   |cff808080A = gained · F = faded · V = visual · Group = a category you type|r")
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
local pickLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
pickLabel:SetPoint("TOPLEFT", LEFT, y)
pickLabel:SetText("Add an aura:")

local addDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
addDD:SetPoint("LEFT", pickLabel, "RIGHT", 12, 0)
addDD:SetSize(280, 30)
addDD:SetDefaultText("Choose an aura you've had")
addDD:SetupMenu(function(_, root)
    -- SetupMenu populates once at load, before ADDON_LOADED creates the
    -- saved variables. Bail until the DB exists; the menu regenerates on
    -- every open, so it fills in normally once the player is logged in.
    if not CueSenseDB then return end
    -- Cap the menu height so a long list scrolls instead of running off
    -- the bottom of the screen (reported at 1920x1080).
    if root.SetScrollMode then root:SetScrollMode(GetScreenHeight() * 0.6) end
    local auras = ns.GetSeenAuras()
    if #auras == 0 then
        root:CreateButton("|cff808080No auras seen yet — get buffed or fight, then reopen|r", function() end)
        return
    end
    for _, sp in ipairs(auras) do
        local sid = sp.spellID
        local icon = sp.icon or 134400
        local label = string.format("|T%d:16:16:0:0|t %s", icon, sp.name or ("Spell " .. sid))
        if CueSenseDB.cues[tostring(sid)] then
            label = label .. "  |cff808080(watching)|r"
        end
        if sp.secret then
            label = label .. "  |cffff6060(may be hidden in instances)|r"
        end
        root:CreateButton(label, function()
            if CueSenseDB.cues[tostring(sid)] then
                addStatus:SetText("|cffffd200Already watching " .. (sp.name or sid) .. ".|r")
                return
            end
            ns.AddCue(sid)
            addStatus:SetText("|cff60ff60Added " .. (sp.name or sid) .. ".|r")
            if watchInfo.Refresh then watchInfo.Refresh() end
            RebuildList()
        end)
    end
end)
y = y - 38

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
    if CueSenseDB.cues[tostring(id)] then
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
groupHint:SetText("Auras are grouped by Buffs / Debuffs. Type a Group name (e.g. a dungeon) on any " ..
    "row to file it under your own heading instead.")
y = y - 26

-- Column headers above the list
local function ColHeader(text, xoff)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", LEFT + xoff, y)
    fs:SetText(text)
end
ColHeader("Aura", 4)
ColHeader("A", 138)
ColHeader("F", 166)
ColHeader("V", 194)
ColHeader("Sound", 222)
ColHeader("Group", 398)
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

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name:SetWidth(126)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    local function MkCheck(xoff, field)
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("LEFT", row, "LEFT", xoff, 0)
        cb:SetScript("OnClick", function(self)
            local cue = row.spellID and CueSenseDB.cues[row.spellID]
            if cue then cue[field] = self:GetChecked() and true or false end
        end)
        return cb
    end
    row.applied = MkCheck(136, "applied")
    row.faded   = MkCheck(164, "faded")
    row.visual  = MkCheck(192, "visual")

    row.sound = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.sound:SetPoint("LEFT", row, "LEFT", 220, 0)
    row.sound:SetSize(118, 26)
    row.sound:SetupMenu(function(_, rootMenu)
        -- "None" makes this cue silent (visual-only); audio is optional.
        rootMenu:CreateRadio("None (silent)",
            function()
                local c = row.spellID and CueSenseDB.cues[row.spellID]
                return c and not c.sound
            end,
            function()
                local c = row.spellID and CueSenseDB.cues[row.spellID]
                if not c then return end
                c.sound = false
                C_Timer.After(0, function() row.sound:GenerateMenu() end)
            end)
        for _, item in ipairs(ns.SOUNDS) do
            local key = item.key
            rootMenu:CreateRadio(item.label,
                function()
                    local c = row.spellID and CueSenseDB.cues[row.spellID]
                    return c and c.sound == key
                end,
                function()
                    local c = row.spellID and CueSenseDB.cues[row.spellID]
                    if not c then return end
                    c.sound = key
                    ns.PlaySoundEntry(key, c.channel or CueSenseDB.channel)
                    C_Timer.After(0, function() row.sound:GenerateMenu() end)
                end)
        end
    end)

    row.preview = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.preview:SetSize(24, 22)
    row.preview:SetPoint("LEFT", row, "LEFT", 342, 0)
    row.preview:SetText(">")
    row.preview:SetScript("OnClick", function()
        local cue = row.spellID and CueSenseDB.cues[row.spellID]
        if cue and cue.sound then ns.PlaySoundEntry(cue.sound, cue.channel or CueSenseDB.channel) end
    end)

    row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.remove:SetSize(24, 24)
    row.remove:SetPoint("LEFT", row, "LEFT", 368, 0)
    row.remove:SetScript("OnClick", function()
        if not row.spellID then return end
        ns.RemoveCue(row.spellID)
        if watchInfo.Refresh then watchInfo.Refresh() end
        RebuildList()
    end)

    -- Free-text group/category; type a dungeon name etc. to re-file the aura.
    row.cat = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.cat:SetPoint("LEFT", row, "LEFT", 398, 0)
    row.cat:SetSize(128, 22)
    row.cat:SetAutoFocus(false)
    row.cat:SetFontObject("ChatFontNormal")
    -- Commit on focus loss only; rebuild solely when the value actually
    -- changed (avoids a rebuild — and re-entrant focus events — when the
    -- box is left untouched).
    row.cat:SetScript("OnEditFocusLost", function(self)
        local cue = row.spellID and CueSenseDB.cues[row.spellID]
        if not cue then return end
        local t = (self:GetText() or ""):trim()
        local newCat = (t ~= "" and t) or ((cue.kind == "debuff") and "Debuffs" or "Buffs")
        if newCat == cue.category then return end
        cue.category = newCat
        RebuildList()
    end)
    row.cat:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    row.cat:SetScript("OnEscapePressed", function(self)
        local cue = row.spellID and CueSenseDB.cues[row.spellID]
        self:SetText(cue and cue.category or "")
        self:ClearFocus()
    end)

    rows[i] = row
    return row
end

RebuildList = function()
    if not CueSenseDB then return end

    -- Group cues by category. Buffs/Debuffs are the default groups; a
    -- user-typed category re-files an aura under its own heading.
    local groups, total = {}, 0
    for sid, cue in pairs(CueSenseDB.cues) do
        local cat = cue.category or ((cue.kind == "debuff") and "Debuffs" or "Buffs")
        groups[cat] = groups[cat] or {}
        local g = groups[cat]
        g[#g + 1] = sid
        total = total + 1
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
            local cue = CueSenseDB.cues[sid]
            local nm = cue.label or C_Spell.GetSpellName(tonumber(sid)) or "Unknown"
            row.name:SetText(nm .. "  |cff808080(" .. sid .. ")|r")
            row.applied:SetChecked(cue.applied and true or false)
            row.faded:SetChecked(cue.faded and true or false)
            row.visual:SetChecked(cue.visual and true or false)
            row.cat:SetText(cue.category or "")
            row.sound:GenerateMenu()
            row:Show()
            yOff = yOff + ROW_H
        end
    end
    for i = rowIdx + 1, #rows do rows[i]:Hide() end
    for i = hdrIdx + 1, #headers do headers[i]:Hide() end

    local listH = math.max(yOff, ROW_H)
    editor:SetHeight(listH)
    if total == 0 then emptyText:Show() else emptyText:Hide() end

    -- Recompute scroll content height from the editor's bottom.
    content:SetHeight(-editorTopY + listH + 30)
end
ns.RebuildList = RebuildList

-- ---------------------------------------------------------------------
-- Refresh + registration
-- ---------------------------------------------------------------------
local function RefreshAll()
    if not CueSenseDB then return end
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
