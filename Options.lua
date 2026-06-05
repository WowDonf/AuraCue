-- =====================================================================
-- AuraCue - Options panels (Settings canvas + subcategories)
-- =====================================================================
-- Three registered panels: a main "AuraCue" page (General + Audio) and
-- two subcategories in the left list, "Buffs" and "Debuffs", each holding
-- that kind's window appearance and its watched-aura editor. All tracked-
-- setting reads go through ns.P() (the active profile); the account-wide
-- seen catalog is reached via ns.GetSeenAuras().
-- =====================================================================
local _, ns = ...

local ROW_H = 64        -- two-line editor row (toggles/group, then sounds) + divider gap
local HEADER_H = 22
local MAX_RESULTS = 10
local RESULT_H = 20

-- Apply a typed group name to one aura (data.sid) or many (data.sids).
local function ApplyGroupFromDialog(data, text)
    if not data then return end
    if data.sids then
        for _, sid in ipairs(data.sids) do ns.SetAuraGroup(sid, text) end
    elseif data.sid then
        ns.SetAuraGroup(data.sid, text)
    end
    if data.after then data.after() end
end

-- Dialog for assigning catalogued auras to a custom picker group. The opener
-- passes { sid=<id> | sids={...}, current, after } as the data argument.
StaticPopupDialogs["AURACUE_SET_GROUP"] = {
    text = "Custom group for %s:\n(leave blank to remove from any custom group)",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 40,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox
        if eb then eb:SetText((data and data.current) or ""); eb:HighlightText() end
    end,
    OnAccept = function(self, data)
        local eb = self.EditBox or self.editBox
        ApplyGroupFromDialog(data, eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(editBox)
        local dialog = editBox:GetParent()
        ApplyGroupFromDialog(dialog and dialog.data, editBox:GetText() or "")
        if dialog then dialog:Hide() end
    end,
}

-- Generic confirmation for destructive actions. Opener passes the warning as
-- text_arg1 and { onaccept } as data.
StaticPopupDialogs["AURACUE_CONFIRM"] = {
    text = "%s",
    button1 = "Yes",
    button2 = "Cancel",
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function(_, data) if data and data.onaccept then data.onaccept() end end,
}

-- A copyable link dialog (addons can't open a browser, so we hand the user a
-- URL to copy). Opener passes { url } as data.
StaticPopupDialogs["AURACUE_LINK"] = {
    text = "Copy this link (Ctrl+C), then open it in your web browser:",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 350,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox
        if eb then
            eb:SetText((data and data.url) or "")
            eb:SetCursorPosition(0)
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(editBox) local d = editBox:GetParent(); if d then d:Hide() end end,
    EditBoxOnEscapePressed = function(editBox) local d = editBox:GetParent(); if d then d:Hide() end end,
}

-- Apply comma/space-separated spell ids from the alias dialog to a cue.
local function ApplyAltsFromDialog(data, text)
    if not data or not data.key then return end
    local list = {}
    for tok in (text or ""):gmatch("[^,%s]+") do list[#list + 1] = tok end
    ns.SetCueAlts(data.key, list)
    if data.after then data.after() end
end

-- Edit the extra spell ids that also trigger one cue (one alert, many ids).
StaticPopupDialogs["AURACUE_ALTS"] = {
    text = "Other spell IDs that also trigger %s\n(comma-separated; leave blank to clear):",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 260,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox
        if eb then eb:SetText((data and data.current) or ""); eb:HighlightText(); eb:SetFocus() end
    end,
    OnAccept = function(self, data)
        local eb = self.EditBox or self.editBox
        ApplyAltsFromDialog(data, eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(editBox)
        local d = editBox:GetParent()
        ApplyAltsFromDialog(d and d.data, editBox:GetText() or "")
        if d then d:Hide() end
    end,
}

-- Rename (or, if blank, delete) a whole custom group. Opener passes { old }.
StaticPopupDialogs["AURACUE_RENAME_GROUP"] = {
    text = "Rename group \"%s\" to (blank = delete the group):",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 220,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        local eb = self.EditBox or self.editBox
        if eb then eb:SetText((data and data.old) or ""); eb:HighlightText(); eb:SetFocus() end
    end,
    OnAccept = function(self, data)
        local eb = self.EditBox or self.editBox
        if data then ns.RenameAuraGroup(data.old, eb and eb:GetText() or ""); if data.after then data.after() end end
    end,
    EditBoxOnEnterPressed = function(editBox)
        local d = editBox:GetParent()
        local data = d and d.data
        if data then ns.RenameAuraGroup(data.old, editBox:GetText() or ""); if data.after then data.after() end end
        if d then d:Hide() end
    end,
}

-- Percent-encode a search term for a URL query.
local function urlencode(s)
    return (tostring(s or ""):gsub("[^%w]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- Every panel registers a refresh function here; ns.RefreshOptions runs
-- them all (used by slash commands and cross-panel updates).
-- Per-cue "when" condition cycle (compact button on each row).
local COND_ORDER = { "always", "combat", "instance", "world" }
local COND_LABEL = { always = "Any", combat = "Cbt", instance = "Inst", world = "Wld" }

-- Display order for the automatic group buckets; custom/class/dungeon groups
-- sort above these. Shared by the picker submenus and the watched list so they
-- always group the same way.
local BUCKET_ORDER = { ["Boss"] = 0, ["From you / your pet"] = 1, ["Mounts"] = 2, ["World & other"] = 3, ["Other"] = 4 }
local function sortGroupKeys(keys)
    table.sort(keys, function(a, b)
        local oa, ob = BUCKET_ORDER[a], BUCKET_ORDER[b]
        if oa and ob then return oa < ob end
        if oa or ob then return ob ~= nil end   -- custom/class/dungeon first
        return a < b
    end)
end

local refreshers = {}
local function RefreshAllPanels()
    if not ns.P() then return end
    for _, fn in ipairs(refreshers) do fn() end
end
ns.RefreshOptions = RefreshAllPanels

-- ---------------------------------------------------------------------
-- Panel factory: a scrollable canvas with a running-y layout cursor and
-- the Add* helpers bound to it.
-- ---------------------------------------------------------------------
local function NewPanel(name)
    local panel = CreateFrame("Frame")
    panel.name = name
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, 100)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then content:SetWidth(w) end end)

    local LEFT = 18
    local widgets = {}
    local ctx = { panel = panel, content = content, widgets = widgets, LEFT = LEFT, y = -14 }

    function ctx.Header(text)
        ctx.y = ctx.y - 8
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", LEFT, ctx.y)
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0)
        ctx.y = ctx.y - 22
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.12)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", LEFT, ctx.y)
        line:SetPoint("TOPRIGHT", -18, ctx.y)
        ctx.y = ctx.y - 12
    end

    function ctx.Desc(text)
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", LEFT, ctx.y)
        fs:SetWidth(520)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        -- GetStringHeight under-reports before the panel is first shown;
        -- reserve the larger of measured and a char-count estimate.
        local measured = fs:GetStringHeight() or 0
        local approx = math.ceil(#text / 64) * 13
        ctx.y = ctx.y - (math.max(measured, approx) + 12)
    end

    -- A checkbox at a given x on the current row (doesn't advance y).
    local function checkAt(x, label, getter, setter)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, ctx.y)
        cb:SetSize(26, 26)
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        fs:SetText(label)
        cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
        cb.Refresh = function() cb:SetChecked(getter() and true or false) end
        widgets[#widgets + 1] = cb
        return cb
    end

    function ctx.Check(label, getter, setter)
        local cb = checkAt(LEFT, label, getter, setter)
        ctx.y = ctx.y - 30
        return cb
    end

    -- Two checkboxes side by side on one row.
    function ctx.CheckRow(l1, g1, s1, l2, g2, s2)
        checkAt(LEFT, l1, g1, s1)
        checkAt(LEFT + 210, l2, g2, s2)
        ctx.y = ctx.y - 30
    end

    function ctx.Slider(label, minV, maxV, step, fmt, getter, setter)
        ctx.y = ctx.y - 4
        local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        titleFS:SetPoint("TOPLEFT", LEFT, ctx.y)
        titleFS:SetText(label)
        local valFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        ctx.y = ctx.y - 18
        local s = CreateFrame("Slider", nil, content)
        s:SetPoint("TOPLEFT", LEFT + 4, ctx.y)
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
        ctx.y = ctx.y - 32
        return s
    end

    function ctx.Dropdown(label, width)
        local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        titleFS:SetPoint("TOPLEFT", LEFT, ctx.y)
        titleFS:SetText(label)
        ctx.y = ctx.y - 22
        local dd = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", LEFT + 6, ctx.y)
        dd:SetSize(width or 280, 30)
        ctx.y = ctx.y - 40
        return dd
    end

    function ctx.Button(label, width, onClick)
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", LEFT + 6, ctx.y)
        b:SetSize(width or 160, 24)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        ctx.y = ctx.y - 32
        return b
    end

    function ctx.SideBySide(...)
        local args = {...}
        local x = LEFT + 6
        for i = 1, #args / 2 do
            local label = args[(i - 1) * 2 + 1]
            local onClick = args[(i - 1) * 2 + 2]
            local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            b:SetPoint("TOPLEFT", x, ctx.y)
            b:SetSize(180, 24)
            b:SetText(label)
            b:SetScript("OnClick", onClick)
            x = x + 188
        end
        ctx.y = ctx.y - 32
    end

    function ctx.Refresh()
        if not ns.P() then return end
        for _, w in ipairs(widgets) do
            if w.Refresh then w.Refresh() end
        end
        if ctx.rebuild then ctx.rebuild() end
        if ns.RefreshPrivateAuras then ns.RefreshPrivateAuras() end
    end

    refreshers[#refreshers + 1] = ctx.Refresh
    panel:SetScript("OnShow", ctx.Refresh)
    return ctx
end

-- ---------------------------------------------------------------------
-- Colour-swatch buttons bound to a color table getter.
-- ---------------------------------------------------------------------
local function MakeColorButton(parent, getColor, label, width)
    local colorBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    colorBtn:SetSize(width or 160, 24)
    colorBtn:SetText(label or "Flash color...")
    local swatch = colorBtn:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(14, 14)
    swatch:SetPoint("LEFT", colorBtn, "LEFT", 8, 0)
    local txt = colorBtn:GetFontString()
    if txt then
        txt:ClearAllPoints()
        txt:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        txt:SetPoint("RIGHT", colorBtn, "RIGHT", -8, 0)
    end
    colorBtn:SetScript("OnClick", function()
        local c = getColor()
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
        local c = getColor()
        swatch:SetColorTexture(c.r, c.g, c.b)
    end
    return colorBtn
end

-- Two colour-swatch buttons on a single row.
local function AddColorPair(ctx, getA, labelA, getB, labelB)
    local W = 210
    local a = MakeColorButton(ctx.content, getA, labelA, W)
    a:SetPoint("TOPLEFT", ctx.LEFT + 6, ctx.y)
    local b = MakeColorButton(ctx.content, getB, labelB, W)
    b:SetPoint("TOPLEFT", ctx.LEFT + 6 + W + 12, ctx.y)
    ctx.widgets[#ctx.widgets + 1] = a
    ctx.widgets[#ctx.widgets + 1] = b
    ctx.y = ctx.y - 32
end

-- ---------------------------------------------------------------------
-- A bordered, scrollable multi-line edit box (used by the Sharing panel).
-- The export/import strings are long and wrap over many lines, so the box
-- scrolls internally and the wheel scrolls the text rather than the panel.
-- ---------------------------------------------------------------------
local function AddShareBox(ctx, height)
    local content, LEFT = ctx.content, ctx.LEFT
    local boxBG = CreateFrame("Frame", nil, content, "BackdropTemplate")
    boxBG:SetPoint("TOPLEFT", LEFT, ctx.y)
    boxBG:SetSize(520, height)
    boxBG:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    boxBG:SetBackdropColor(0, 0, 0, 0.6)

    local scroll = CreateFrame("ScrollFrame", nil, boxBG, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetWidth(480)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetMaxLetters(0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local top, bottom = -y, -y + h
        local view = scroll:GetHeight()
        local s = scroll:GetVerticalScroll()
        if top < s then scroll:SetVerticalScroll(top)
        elseif bottom > s + view then scroll:SetVerticalScroll(bottom - view) end
    end)
    scroll:SetScrollChild(box)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        local new = math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 24))
        self:SetVerticalScroll(new)
    end)
    ctx.y = ctx.y - (height + 8)
    return box, scroll
end

-- A left-aligned status line for inline feedback; returns the FontString.
local function AddStatusLine(ctx)
    local fs = ctx.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", ctx.LEFT, ctx.y)
    fs:SetWidth(520)
    fs:SetJustifyH("LEFT")
    ctx.y = ctx.y - 20
    return fs
end

-- ---------------------------------------------------------------------
-- Main panel: General + Audio.
-- ---------------------------------------------------------------------
local main = NewPanel("AuraCue")
do
    local content, LEFT = main.content, main.LEFT

    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, main.y)
    titleFS:SetText("AuraCue")
    main.y = main.y - 22
    local subFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subFS:SetPoint("TOPLEFT", LEFT, main.y)
    subFS:SetText("Turn your own buffs and debuffs into sound, speech, and/or on-screen flashes. Configure them in the sections to the left.")
    main.y = main.y - 18

    -- Per-spec profile indicator.
    local profFS = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profFS:SetPoint("TOPLEFT", LEFT, main.y)
    profFS:SetWidth(520)
    profFS:SetJustifyH("LEFT")
    profFS.Refresh = function()
        local spec = ns.CurrentSpecName and ns.CurrentSpecName() or "?"
        profFS:SetText("Tracked auras and settings are saved per character and spec. Editing: |cffffd200" .. spec .. "|r.")
    end
    main.widgets[#main.widgets + 1] = profFS
    main.y = main.y - 18

    main.Header("Global Settings")
    main.Check("Enable AuraCue",
        function() return ns.P().enabled end,
        function(v) ns.P().enabled = v end)
    main.Check("Track buffs (helpful auras)",
        function() return ns.P().trackBuffs end,
        function(v) ns.P().trackBuffs = v end)
    main.Check("Track debuffs (harmful auras)",
        function() return ns.P().trackDebuffs end,
        function(v) ns.P().trackDebuffs = v end)
    main.Check("Combine auras with the same name",
        function() return ns.P().combineByName end,
        function(v) ns.SetCombineByName(v) end)
    main.Desc("Treat every aura that shares a name as one alert (e.g. a spell and its " ..
        "proc version). Merges duplicate watched rows and hides the same-named variants in the pickers.")
    main.Check("Show minimap button",
        function() return not ns.IsMinimapShown or ns.IsMinimapShown() end,
        function(v) if ns.SetMinimapShown then ns.SetMinimapShown(v) end end)

    main.Header("Audio cue")
    main.Check("Play sound cues",
        function() return ns.P().audioEnabled end,
        function(v) ns.P().audioEnabled = v end)
    main.Desc("Master switch for all cue sounds. Each aura's gained / faded sound is set in " ..
        "its section; this is the audio channel they route through, so you can balance cue " ..
        "volume against game audio.")
    local channelDropdown = main.Dropdown("Audio channel", 200)
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
    main.widgets[#main.widgets + 1] = channelDropdown
    main.Button("Play test cue", 160, function() ns.PlayTestCue() end)

    main.Desc("Spoken cues: pick \"Speak the name (TTS)\" as a buff's or debuff's sound to have " ..
        "AuraCue say its name aloud. These settings control the voice.")
    local voiceDD = main.Dropdown("Speech voice", 240)
    voiceDD:SetDefaultText("Default voice")
    voiceDD:SetupMenu(function(_, root)
        if not ns.P() then return end
        local voices = ns.GetTtsVoices()
        if #voices == 0 then
            root:CreateButton("|cff808080No speech voices available|r", function() end)
            return
        end
        for _, v in ipairs(voices) do
            local vid, vname = v.voiceID, v.name
            root:CreateRadio(vname,
                function() return ns.P().ttsVoice == vid end,
                function()
                    ns.P().ttsVoice = vid
                    ns.Speak(vname)
                    C_Timer.After(0, function() voiceDD:GenerateMenu() end)
                end)
        end
    end)
    voiceDD.Refresh = function() voiceDD:GenerateMenu() end
    main.widgets[#main.widgets + 1] = voiceDD
    main.Slider("Speech rate", -10, 10, 1, "%d",
        function() return ns.P().ttsRate end,
        function(v) ns.P().ttsRate = v end)
    main.Slider("Speech volume", 0, 100, 5, "%d",
        function() return ns.P().ttsVolume end,
        function(v) ns.P().ttsVolume = v end)
    main.Button("Test speech", 160, function() ns.Speak("AuraCue speech test") end)

    content:SetHeight(-main.y + 20)
end

-- ---------------------------------------------------------------------
-- Build one kind's subcategory: window appearance + add UI + editor,
-- everything filtered to `kind` ("buff" or "debuff").
-- ---------------------------------------------------------------------
local function BuildKindPanel(kind)
    local label = (kind == "debuff") and "Debuffs" or "Buffs"
    local ctx = NewPanel(label)
    local content, LEFT = ctx.content, ctx.LEFT

    -- Title
    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, ctx.y)
    titleFS:SetText(label)
    ctx.y = ctx.y - 24

    -- (Window appearance lives on the separate "Appearance" page now, so this
    -- page is just the watched list + the add controls.)

    -- Watched-aura editor.
    ctx.Header("Watched " .. label:lower())

    local watchInfo = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    watchInfo:SetPoint("TOPLEFT", LEFT, ctx.y)
    watchInfo:SetWidth(520)
    watchInfo:SetJustifyH("LEFT")
    ctx.y = ctx.y - 22
    watchInfo.Refresh = function()
        local n = 0
        if ns.P() then
            for _, cue in pairs(ns.P().cues) do
                local k = (cue.kind == "debuff") and "debuff" or "buff"
                if k == kind then n = n + 1 end
            end
        end
        watchInfo:SetText("Watching |cffffd200" .. n .. "|r " .. (n == 1 and label:lower():gsub("s$", "") or label:lower())
            .. ".   |cff808080A = gained · F = faded · V = visual · hover a row for its tooltip|r")
    end
    ctx.widgets[#ctx.widgets + 1] = watchInfo

    -- Inline feedback line (positioned next to the Add button below).
    local addStatus = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addStatus:SetWidth(250)
    addStatus:SetJustifyH("LEFT")

    -- Forward-declare the editor pieces that reference each other.
    local rows, headers = {}, {}
    local RebuildList, MakeRow, MakeHeader, UpdateSearchResults
    local pickerSearch = ""
    local pickerMineOnly, pickerKnownOnly, pickerInstanceOnly, pickerShowHidden = false, false, false, false
    local pickerBossOnly, pickerRoleOnly = false, false
    local pickerPermOnly, pickerTimedOnly = false, false
    local pickerHideMounts, pickerUngroupedOnly = false, false

    -- Primary "Add": pick from catalogued auras of this kind.
    local pickLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pickLabel:SetPoint("TOPLEFT", LEFT, ctx.y)
    pickLabel:SetText("Add a " .. (kind == "debuff" and "debuff" or "buff") .. ":")

    local addDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    addDD:SetPoint("LEFT", pickLabel, "RIGHT", 12, 0)
    addDD:SetSize(220, 30)
    addDD:SetDefaultText("Choose one you've had")

    local searchLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchLabel:SetPoint("LEFT", addDD, "RIGHT", 16, 0)
    searchLabel:SetText("Search / hide")
    local searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetSize(140, 22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    local searchFocused = false
    local RES_HEAD = 16   -- header row height inside the results popup

    -- True if an aura belongs in this panel and passes the filters.
    local function passes(sp)
        if ((sp.kind == "debuff") and "debuff" or "buff") ~= kind then return false end
        if sp.ignored and not pickerShowHidden then return false end
        -- Auras you already track are never offered for adding again, and
        -- neither are variants a name-combining cue already covers.
        if ns.P().cues[tostring(sp.spellID)] then return false end
        if ns.IsNameCombined and ns.IsNameCombined(sp.name) then return false end
        if pickerMineOnly and not sp.mine then return false end
        if pickerKnownOnly and not sp.known then return false end
        if pickerBossOnly and not sp.boss then return false end
        if pickerRoleOnly and not sp.roleAura then return false end
        if pickerInstanceOnly and not sp.instanceable then return false end
        if pickerHideMounts and sp.mount then return false end
        if pickerUngroupedOnly and sp.group and sp.group ~= "" then return false end
        if pickerPermOnly and not sp.permanent then return false end
        if pickerTimedOnly and sp.permanent then return false end
        return true
    end

    -- Live results popup. Anchored to the panel's left margin (not the search
    -- box, which sits far right) with a contained width, so the per-row hide /
    -- group buttons can't run off the right edge of the options panel.
    local resultBtns = {}
    local searchResults = CreateFrame("Frame", nil, content, "BackdropTemplate")
    -- Anchor below the whole picker row (the dropdown / search box are taller
    -- than the label, so anchoring to the label's bottom overlapped them).
    searchResults:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, ctx.y - 30)
    searchResults:SetWidth(520)
    -- A higher strata so it sits cleanly above the panel's own widgets (the
    -- watched-row close buttons / dropdowns were poking through otherwise).
    searchResults:SetFrameStrata("FULLSCREEN_DIALOG")
    searchResults:SetFrameLevel(content:GetFrameLevel() + 20)
    searchResults:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    searchResults:SetBackdropColor(0, 0, 0, 0.97)
    searchResults:Hide()
    local resHeader = searchResults:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    resHeader:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 8, -5)
    resHeader:SetPoint("TOPRIGHT", searchResults, "TOPRIGHT", -8, -5)
    resHeader:SetJustifyH("LEFT")
    resHeader:SetText("|cff808080Click a name to add. Note icon sets a group; the button on the right hides / restores.|r")
    local moreText = searchResults:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    moreText:SetJustifyH("LEFT")

    local function MakeResultBtn(i)
        local b = CreateFrame("Button", nil, searchResults)
        b:SetHeight(RESULT_H)
        b:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 6, -6 - RES_HEAD - (i - 1) * RESULT_H)
        b:SetPoint("TOPRIGHT", searchResults, "TOPRIGHT", -6, -6 - RES_HEAD - (i - 1) * RESULT_H)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
        b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -40, 0)
        b.text:SetJustifyH("LEFT")
        -- A "set custom group" control (note icon), left of the hide toggle.
        b.tag = CreateFrame("Button", nil, b)
        b.tag:SetSize(14, 14)
        b.tag:SetPoint("RIGHT", b, "RIGHT", -20, 0)
        b.tag:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        b.tag:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.tag:SetScript("OnClick", function()
            if not b.spellID then return end
            StaticPopup_Show("AURACUE_SET_GROUP", b.auraName or tostring(b.spellID), nil, {
                sid = b.spellID,
                current = b.group or "",
                after = function() addDD:GenerateMenu(); UpdateSearchResults() end,
            })
        end)
        b.tag:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Set a custom group")
            GameTooltip:Show()
        end)
        b.tag:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- A small toggle that hides this aura from the picker, or restores it
        -- when it's already hidden (so a mis-hidden ability is one click back).
        -- Its icon/state is set per row in UpdateSearchResults via b.hidden.
        b.hide = CreateFrame("Button", nil, b)
        b.hide:SetSize(14, 14)
        b.hide:SetPoint("RIGHT", b, "RIGHT", -3, 0)
        b.hide:SetScript("OnClick", function()
            if not b.spellID then return end
            local restore = b.hidden                  -- currently hidden -> restore
            ns.SetAuraIgnored(b.spellID, not restore)
            addStatus:SetText(restore
                and ("|cff60ff60Restored " .. (b.auraName or b.spellID) .. " to the list.|r")
                or  ("|cff808080Hid " .. (b.auraName or b.spellID) .. " from the list.|r"))
            addDD:GenerateMenu()
            UpdateSearchResults()
        end)
        b.hide:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(b.hidden and "Restore to the list" or "Hide from this list")
            GameTooltip:Show()
        end)
        b.hide:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if not self.spellID then return end
            if ns.P().cues[tostring(self.spellID)] then
                addStatus:SetText("|cffffd200Already watching " .. (self.auraName or self.spellID) .. ".|r")
            else
                ns.AddCue(self.spellID)
                addStatus:SetText("|cff60ff60Added " .. (self.auraName or self.spellID) .. ".|r")
                RefreshAllPanels()
            end
            UpdateSearchResults()
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
        -- Show the list while typing OR while the box is focused (so the hide
        -- ✕ / restore + controls are reachable without having to type first).
        if not ns.P() or (pickerSearch == "" and not searchFocused) then searchResults:Hide(); return end
        local shown, more = 0, 0
        for _, sp in ipairs(ns.GetSeenAuras()) do
            local nm = sp.name or ("Spell " .. sp.spellID)
            local matchText = nm:lower():find(pickerSearch, 1, true) or tostring(sp.spellID):find(pickerSearch, 1, true)
            if matchText and passes(sp) then
                if shown < MAX_RESULTS then
                    shown = shown + 1
                    local b = resultBtns[shown] or MakeResultBtn(shown)
                    b.spellID = sp.spellID
                    b.auraName = nm
                    b.group = sp.group
                    b.icon:SetTexture(sp.icon or 134400)
                    b.hidden = sp.ignored
                    if sp.ignored then
                        b.hide:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                        b.hide:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                    else
                        b.hide:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                        b.hide:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
                    end
                    local mark = ns.P().cues[tostring(sp.spellID)] and "  |cff808080(watching)|r" or ""
                    if sp.group and sp.group ~= "" then mark = mark .. "  |cff80c0ff[" .. sp.group .. "]|r" end
                    if sp.ignored then mark = mark .. "  |cffff6060(hidden)|r" end
                    b.text:SetText(nm .. mark)
                    b:Show()
                else
                    more = more + 1
                end
            end
        end
        for i = shown + 1, #resultBtns do resultBtns[i]:Hide() end
        if shown == 0 then searchResults:Hide(); return end
        local h = 12 + RES_HEAD + shown * RESULT_H
        if more > 0 then
            moreText:ClearAllPoints()
            moreText:SetPoint("TOPLEFT", searchResults, "TOPLEFT", 8, -6 - RES_HEAD - shown * RESULT_H)
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
        addDD:GenerateMenu()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus(); searchResults:Hide()
    end)
    searchBox:SetScript("OnEditFocusGained", function()
        searchFocused = true
        UpdateSearchResults()
    end)
    searchBox:SetScript("OnEditFocusLost", function()
        searchFocused = false
        -- Defer so a click on a result button still registers; only close the
        -- empty (browse-all) list, and only if the cursor has left the popup.
        C_Timer.After(0.2, function()
            if not searchFocused and pickerSearch == "" and not searchResults:IsMouseOver() then
                searchResults:Hide()
            end
        end)
    end)

    -- Open the custom-group dialog for one aura, refreshing the picker after.
    local function PromptGroup(sid, nm, current)
        StaticPopup_Show("AURACUE_SET_GROUP", nm, nil, {
            sid = sid, current = current or "",
            after = function() addDD:GenerateMenu(); UpdateSearchResults() end,
        })
    end

    -- Create an "add this aura" entry under `parent` (the root or a submenu).
    -- Plain click adds; Shift-click hides/restores; Ctrl-click sets a group —
    -- so the same management is reachable from the dropdown, not just search.
    local function AddAuraButton(parent, sp)
        local sid = sp.spellID
        local nm = sp.name or ("Spell " .. sid)
        local txt = string.format("|T%d:16:16:0:0|t %s", sp.icon or 134400, nm)
        if ns.P().cues[tostring(sid)] then txt = txt .. "  |cff808080(watching)|r" end
        if sp.group and sp.group ~= "" then txt = txt .. "  |cff80c0ff[" .. sp.group .. "]|r" end
        if sp.ignored then txt = txt .. "  |cffff6060(hidden)|r" end
        if sp.secret then txt = txt .. "  |cffff6060(may be hidden in instances)|r" end
        local btn = parent:CreateButton(txt, function()
            if IsControlKeyDown() then
                PromptGroup(sid, nm, sp.group)
                return MenuResponse and MenuResponse.Refresh or nil
            elseif IsShiftKeyDown() then
                ns.SetAuraIgnored(sid, not sp.ignored)
                addStatus:SetText(sp.ignored
                    and ("|cff60ff60Restored " .. nm .. ".|r")
                    or  ("|cff808080Hid " .. nm .. ".|r"))
                addDD:GenerateMenu(); UpdateSearchResults()
                return MenuResponse and MenuResponse.Refresh or nil
            end
            if ns.P().cues[tostring(sid)] then
                addStatus:SetText("|cffffd200Already watching " .. nm .. ".|r")
                return
            end
            ns.AddCue(sid)
            addStatus:SetText("|cff60ff60Added " .. nm .. ".|r")
            RefreshAllPanels()
        end)
        if btn and btn.SetTooltip then
            btn:SetTooltip(function(tooltip)
                if tooltip and tooltip.SetSpellByID then tooltip:SetSpellByID(sid) end
                if tooltip and tooltip.AddLine then
                    tooltip:AddLine(" ")
                    tooltip:AddLine("Click: add   Shift-click: " .. (sp.ignored and "restore" or "hide")
                        .. "   Ctrl-click: set group", 0.6, 0.6, 0.6)
                end
            end)
        end
    end

    -- Which submenu an aura belongs in. A custom group always wins; otherwise
    -- fall back to reliable auto-buckets (debuffs by dungeon; buffs by mount /
    -- cast-by-me / world). The auto-buckets have a fixed display order and sit
    -- below any custom groups.
    local function GroupOf(sp) return ns.GroupFor(sp.spellID) end

    addDD:SetupMenu(function(_, root)
        if not ns.P() then return end
        if root.SetScrollMode then root:SetScrollMode(GetScreenHeight() * 0.6) end

        local matches = {}
        for _, sp in ipairs(ns.GetSeenAuras()) do
            local nm = sp.name or ("Spell " .. sp.spellID)
            local matchText = pickerSearch == ""
                or nm:lower():find(pickerSearch, 1, true)
                or tostring(sp.spellID):find(pickerSearch, 1, true)
            if matchText and passes(sp) then matches[#matches + 1] = sp end
        end

        if #matches == 0 then
            root:CreateButton("|cff808080No " .. label:lower() .. " match — type, or add by spell ID|r", function() end)
            return
        end

        -- While searching, a flat list scans faster than nested submenus.
        if pickerSearch ~= "" then
            for _, sp in ipairs(matches) do AddAuraButton(root, sp) end
            return
        end

        -- Otherwise bucket into groups.
        local groups, order = {}, {}
        for _, sp in ipairs(matches) do
            local g = GroupOf(sp)
            if not groups[g] then groups[g] = {}; order[#order + 1] = g end
            local t = groups[g]
            t[#t + 1] = sp
        end
        -- One group only -> show it flat; no point in a single submenu.
        if #order == 1 then
            for _, sp in ipairs(groups[order[1]]) do AddAuraButton(root, sp) end
            return
        end
        -- Custom groups first (alphabetical); the auto-buckets follow in their
        -- fixed order.
        sortGroupKeys(order)
        for _, g in ipairs(order) do
            local list = groups[g]
            local sub = root:CreateButton(string.format("%s  |cff808080(%d)|r", g, #list))
            for _, sp in ipairs(list) do AddAuraButton(sub, sp) end
        end
    end)
    ctx.y = ctx.y - 38

    -- Combinable filters to wrangle the catalog, plus a button to clear the
    -- hidden list. The "abilities I know" filter drops toys / food / world
    -- buffs (their aura isn't a known spell), which is most of the clutter.
    local filterLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    filterLabel:SetPoint("TOPLEFT", LEFT, ctx.y)
    filterLabel:SetText("Show:")
    local filterDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    filterDD:SetPoint("LEFT", filterLabel, "RIGHT", 12, 0)
    filterDD:SetSize(240, 30)

    local function FilterText()
        local n = 0
        for _, on in ipairs({ pickerMineOnly, pickerKnownOnly, pickerBossOnly, pickerRoleOnly,
                              pickerInstanceOnly, pickerUngroupedOnly, pickerPermOnly, pickerTimedOnly,
                              pickerHideMounts, pickerShowHidden }) do
            if on then n = n + 1 end
        end
        return (n == 0) and "All auras I've seen" or ("Filters: " .. n .. " on")
    end
    local function ApplyFilters()
        filterDD:SetDefaultText(FilterText())
        addDD:GenerateMenu()
        UpdateSearchResults()
    end
    filterDD:SetDefaultText(FilterText())

    local function FilterToggle(root, text, get, set)
        root:CreateCheckbox(text, get, function()
            set(not get())
            ApplyFilters()
            return MenuResponse and MenuResponse.Refresh or nil
        end)
    end
    filterDD:SetupMenu(function(_, root)
        FilterToggle(root, "Only auras from me / my pet",
            function() return pickerMineOnly end, function(v) pickerMineOnly = v end)
        FilterToggle(root, "Only abilities I know (hides toys / food)",
            function() return pickerKnownOnly end, function(v) pickerKnownOnly = v end)
        FilterToggle(root, "Only boss auras",
            function() return pickerBossOnly end, function(v) pickerBossOnly = v end)
        FilterToggle(root, "Only role auras (Tank / Healer / DPS)",
            function() return pickerRoleOnly end, function(v) pickerRoleOnly = v end)
        FilterToggle(root, "Only ones trackable in instances",
            function() return pickerInstanceOnly end, function(v) pickerInstanceOnly = v end)
        FilterToggle(root, "Only un-grouped auras",
            function() return pickerUngroupedOnly end, function(v) pickerUngroupedOnly = v end)
        root:CreateDivider()
        -- Permanent / timed are mutually exclusive.
        FilterToggle(root, "Only permanent auras",
            function() return pickerPermOnly end,
            function(v) pickerPermOnly = v; if v then pickerTimedOnly = false end end)
        FilterToggle(root, "Only timed auras",
            function() return pickerTimedOnly end,
            function(v) pickerTimedOnly = v; if v then pickerPermOnly = false end end)
        root:CreateDivider()
        FilterToggle(root, "Hide mounts",
            function() return pickerHideMounts end, function(v) pickerHideMounts = v end)
        FilterToggle(root, "Show hidden auras",
            function() return pickerShowHidden end, function(v) pickerShowHidden = v end)
    end)

    local resetHidden = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetHidden:SetPoint("LEFT", filterDD, "RIGHT", 12, 0)
    resetHidden:SetSize(110, 22)
    resetHidden:SetText("Reset hidden")
    resetHidden:SetScript("OnClick", function()
        StaticPopup_Show("AURACUE_CONFIRM",
            "Un-hide every aura you've hidden? This clears the whole hidden-aura list.", nil,
            { onaccept = function()
                ns.ResetIgnored()
                addStatus:SetText("|cff808080Hidden-aura list cleared.|r")
                addDD:GenerateMenu()
                UpdateSearchResults()
            end })
    end)
    ctx.y = ctx.y - 36

    -- Secondary "Add": by raw spell ID.
    local addLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    addLabel:SetPoint("TOPLEFT", LEFT, ctx.y)
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
        local id = tonumber((addBox:GetText() or ""):trim())
        if not id then addStatus:SetText("|cffff6060Enter a spell ID number.|r"); return end
        if ns.P().cues[tostring(id)] then addStatus:SetText("|cffffd200Already watching that.|r"); return end
        local nm = C_Spell.GetSpellName(id)
        if not nm then addStatus:SetText("|cffff6060Unknown spell ID " .. id .. ".|r"); return end
        ns.AddCue(id)
        addBox:SetText("")
        local note = ns.IsSpellAuraSecret(id) and "  |cffff6060(may be hidden in instances)|r" or ""
        addStatus:SetText("|cff60ff60Added " .. nm .. ".|r" .. note)
        RefreshAllPanels()
    end
    addBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoAdd() end)
    addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addBtn:SetScript("OnClick", DoAdd)
    addStatus:SetPoint("LEFT", addBtn, "RIGHT", 14, 0)
    ctx.y = ctx.y - 30

    -- Don't know the ID? Type a spell name and get a copyable Wowhead search
    -- link (the addon can't browse the web, so you look it up in a browser).
    local whLabel = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    whLabel:SetPoint("TOPLEFT", LEFT, ctx.y)
    whLabel:SetText("Find an ID:")
    local whBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    whBox:SetPoint("LEFT", whLabel, "RIGHT", 12, 0)
    whBox:SetSize(150, 22)
    whBox:SetAutoFocus(false)
    whBox:SetFontObject("ChatFontNormal")
    local whBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    whBtn:SetPoint("LEFT", whBox, "RIGHT", 8, 0)
    whBtn:SetSize(130, 22)
    whBtn:SetText("Search Wowhead")
    local function DoWowhead()
        local term = (whBox:GetText() or ""):trim()
        local url = (term ~= "")
            and ("https://www.wowhead.com/search?q=" .. urlencode(term))
            or "https://www.wowhead.com/spells"
        StaticPopup_Show("AURACUE_LINK", nil, nil, { url = url })
    end
    whBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoWowhead() end)
    whBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    whBtn:SetScript("OnClick", DoWowhead)
    local whHint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    whHint:SetPoint("LEFT", whBtn, "RIGHT", 12, 0)
    whHint:SetText("|cff808080On the page, the ID is in the URL (…/spell=12345).|r")
    ctx.y = ctx.y - 30

    local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", LEFT, ctx.y)
    hint:SetWidth(520)
    hint:SetJustifyH("LEFT")
    if kind == "debuff" then
        hint:SetText("Debuffs file under the dungeon they were first seen in; type a Group on any " ..
            "row to re-file it. Inside instances the game only exposes debuffs to addons as a sound " ..
            "on apply, so there a debuff cue plays its Gained sound only (no visual / no faded).")
    else
        hint:SetText("Type a Group on any row to file an aura under your own heading. Hover a row " ..
            "for the spell tooltip.")
    end
    ctx.y = ctx.y - 34

    -- Column headers
    local function ColHeader(text, xoff)
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", LEFT + xoff, ctx.y)
        fs:SetText(text)
    end
    ColHeader("Aura", 4)
    ColHeader("A", 248)
    ColHeader("F", 278)
    ColHeader("V", 308)
    ColHeader("Group", 338)
    ctx.y = ctx.y - 14

    local editorTopY = ctx.y
    local editor = CreateFrame("Frame", nil, content)
    editor:SetPoint("TOPLEFT", LEFT, editorTopY)
    editor:SetPoint("TOPRIGHT", -18, editorTopY)
    editor:SetHeight(ROW_H)
    local emptyText = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", LEFT + 4, editorTopY - 7)
    emptyText:SetText("No " .. label:lower() .. " watched yet — add one above.")

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
        row:SetWidth(540)

        row.sep = row:CreateTexture(nil, "BACKGROUND")
        row.sep:SetColorTexture(1, 1, 1, 0.08)
        row.sep:SetHeight(1)
        row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 2)
        row.sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local cue = self.spellID and ns.P().cues[self.spellID]
            if not cue then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local sid = tonumber(self.spellID)
            if sid and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(sid)
            else
                GameTooltip:SetText(cue.label or "Aura", 1, 1, 1)
            end
            if cue.matchName or ns.P().combineByName then
                GameTooltip:AddLine("Auto-combining auras named \"" .. (cue.label or "?") .. "\".", 0.6, 0.8, 1)
            end
            if cue.alts and #cue.alts > 0 then
                local parts = {}
                for _, a in ipairs(cue.alts) do
                    local an = C_Spell.GetSpellName(a)
                    parts[#parts + 1] = a .. (an and (" " .. an) or "")
                end
                GameTooltip:AddLine("Also triggers on: " .. table.concat(parts, ", "), 0.6, 0.8, 1)
            end
            GameTooltip:AddLine("Right-click for combine options (same name / other IDs).", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnMouseUp", function(self, button)
            if button ~= "RightButton" or not self.spellID then return end
            local key = self.spellID
            local cue = ns.P().cues[key]
            if not cue then return end
            local function openDialog()
                local cur = cue.alts and table.concat(cue.alts, ", ") or ""
                StaticPopup_Show("AURACUE_ALTS", cue.label or key, nil,
                    { key = key, current = cur, after = function() RefreshAllPanels() end })
            end
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle(cue.label or "Aura")
                    root:CreateButton(
                        cue.kind == "debuff" and "Treat as a buff" or "Treat as a debuff",
                        function() ns.SetCueKind(key, cue.kind == "debuff" and "buff" or "debuff") end)
                    root:CreateDivider()
                    root:CreateCheckbox("Auto-combine auras with the same name",
                        function() return cue.matchName end,
                        function() ns.SetMatchName(key, not cue.matchName) end)
                    root:CreateButton("Add other spell IDs by hand…", openDialog)
                    if cue.alts and #cue.alts > 0 then
                        root:CreateButton("Clear hand-added IDs", function() ns.SetCueAlts(key, {}) end)
                    end
                end)
            else
                openDialog()
            end
        end)

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
                if cue then
                    cue[field] = self:GetChecked() and true or false
                    if ns.RefreshPrivateAuras then ns.RefreshPrivateAuras() end
                end
            end)
            return cb
        end
        row.applied = MkCheck(244, "applied")
        row.faded   = MkCheck(274, "faded")
        row.visual  = MkCheck(304, "visual")

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
                        if ns.RefreshPrivateAuras then ns.RefreshPrivateAuras() end
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
                            if key == "speak" then ns.Speak("AuraCue") else ns.PlaySoundEntry(key, c.channel or ns.P().channel) end
                            if ns.RefreshPrivateAuras then ns.RefreshPrivateAuras() end
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

        -- "When" cycle: Any -> Combat -> Instance -> World.
        row.cond = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.cond:SetSize(56, 22)
        row.cond:SetPoint("TOPLEFT", row, "TOPLEFT", 480, -30)
        row.cond:SetScript("OnClick", function()
            local cue = row.spellID and ns.P().cues[row.spellID]
            if not cue then return end
            local cur, idx = cue.when or "always", 1
            for ci, v in ipairs(COND_ORDER) do if v == cur then idx = ci break end end
            cue.when = COND_ORDER[(idx % #COND_ORDER) + 1]
            row.cond:SetText(COND_LABEL[cue.when])
        end)
        row.cond:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Fire this cue:", 1, 1, 1)
            GameTooltip:AddLine("Any — everywhere", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Cbt — only while in combat", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Inst — only in instances", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Wld — only in the open world", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Click to cycle.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row.cond:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.remove:SetSize(24, 24)
        row.remove:SetPoint("TOPLEFT", row, "TOPLEFT", 496, -3)
        row.remove:SetScript("OnClick", function()
            if not row.spellID then return end
            ns.RemoveCue(row.spellID)
            RefreshAllPanels()
        end)

        row.cat = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.cat:SetPoint("TOPLEFT", row, "TOPLEFT", 338, -5)
        row.cat:SetSize(150, 22)
        row.cat:SetAutoFocus(false)
        row.cat:SetFontObject("ChatFontNormal")
        row.cat:SetScript("OnEditFocusLost", function(self)
            if not row.spellID then return end
            local t = (self:GetText() or ""):trim()
            if t == (ns.GetAuraGroup(row.spellID) or "") then return end
            ns.SetAuraGroup(row.spellID, t)   -- refreshes all panels (the unified group)
        end)
        row.cat:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        row.cat:SetScript("OnEscapePressed", function(self)
            self:SetText((row.spellID and ns.GetAuraGroup(row.spellID)) or "")
            self:ClearFocus()
        end)

        rows[i] = row
        return row
    end

    RebuildList = function()
        if not ns.P() then return end
        local groups, total = {}, 0
        for sid, cue in pairs(ns.P().cues) do
            local k = (cue.kind == "debuff") and "debuff" or "buff"
            if k == kind then
                local cat = ns.GroupFor(sid)
                groups[cat] = groups[cat] or {}
                local g = groups[cat]
                g[#g + 1] = sid
                total = total + 1
            end
        end
        local cats = {}
        for cat in pairs(groups) do cats[#cats + 1] = cat end
        sortGroupKeys(cats)

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
                local altMark = ""
                if cue.matchName or ns.P().combineByName then altMark = altMark .. "  |cff60a0ffname|r" end
                if cue.alts and #cue.alts > 0 then altMark = altMark .. "  |cff60a0ff+" .. #cue.alts .. "|r" end
                row.name:SetText(nm .. "  |cff808080(" .. sid .. ")|r" .. altMark)
                row.applied:SetChecked(cue.applied and true or false)
                row.faded:SetChecked(cue.faded and true or false)
                row.visual:SetChecked(cue.visual and true or false)
                row.cat:SetText(ns.GetAuraGroup(sid) or "")
                row.cond:SetText(COND_LABEL[cue.when or "always"])
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
        if total == 0 then emptyText:Show() else emptyText:Hide() end
        content:SetHeight(-editorTopY + listH + 30)
    end

    ctx.rebuild = RebuildList
    return ctx
end

local buffPanel = BuildKindPanel("buff")
local debuffPanel = BuildKindPanel("debuff")

-- ---------------------------------------------------------------------
-- Appearance subcategory: the on-screen window look for both kinds, kept
-- off the Buffs/Debuffs pages so those stay focused on the aura list.
-- ---------------------------------------------------------------------
local function BuildAppearanceSection(ctx, kind)
    local label = (kind == "debuff") and "Debuffs" or "Buffs"
    local function Vis() return ns.P().visual[kind] end
    ctx.Header(label .. " window")
    ctx.CheckRow(
        "Show on-screen flash", function() return Vis().enabled end, function(v) Vis().enabled = v end,
        "Flash the screen edges", function() return Vis().edgeFlash end, function(v) Vis().edgeFlash = v end)
    ctx.Slider("Edge thickness", 40, 400, 10, "%d",
        function() return Vis().edgeThickness end,
        function(v) Vis().edgeThickness = v end)
    ctx.Slider("Edge intensity", 0.1, 1.0, 0.05, "%.2f",
        function() return Vis().edgeIntensity end,
        function(v) Vis().edgeIntensity = v end)
    AddColorPair(ctx,
        function() return Vis().color end, "Gained flash color...",
        function() return Vis().colorFaded end, "Faded flash color...")
    ctx.Slider("Flash size", 0.5, 3.0, 0.05, "%.2fx",
        function() return Vis().scale end,
        function(v) Vis().scale = v end)
    ctx.Slider("On-screen time", 0.5, 8.0, 0.1, "%.1fs",
        function() return Vis().duration end,
        function(v) Vis().duration = v end)
    ctx.SideBySide(
        "Move window", function()
            ns.SetRepositionMode(kind, true)
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        end,
        "Reset position", function()
            Vis().position = nil
            ns.RestorePosition(kind)
        end)
    ctx.Button("Test this window", 160, function() ns.TestWindow(kind) end)
end

local appearancePanel = NewPanel("Appearance")
do
    local content, LEFT = appearancePanel.content, appearancePanel.LEFT
    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, appearancePanel.y)
    titleFS:SetText("Appearance")
    appearancePanel.y = appearancePanel.y - 24
    appearancePanel.Desc("How the on-screen flash looks for each kind. Use \"Move window\" to drag a " ..
        "window into place and \"Test this window\" to preview it.")
    BuildAppearanceSection(appearancePanel, "buff")
    BuildAppearanceSection(appearancePanel, "debuff")
    content:SetHeight(-appearancePanel.y + 20)
end

-- ---------------------------------------------------------------------
-- Sharing subcategory: export (profile / catalog) and import, each with
-- its own scrollable box.
-- ---------------------------------------------------------------------
local sharePanel = NewPanel("Sharing")
do
    local content, LEFT = sharePanel.content, sharePanel.LEFT

    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, sharePanel.y)
    titleFS:SetText("Sharing")
    sharePanel.y = sharePanel.y - 24

    -- Copy from another character/spec on this account (no string needed).
    sharePanel.Header("Copy from another character")
    sharePanel.Desc("Replace this character and spec's profile with a copy of another saved profile " ..
        "on this account. A copy is made, so the two stay independent afterward.")
    local copyLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    copyLabel:SetPoint("TOPLEFT", LEFT, sharePanel.y)
    copyLabel:SetText("Profile:")
    local selectedProfile, selectedLabel
    local copyDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    copyDD:SetPoint("LEFT", copyLabel, "RIGHT", 12, 0)
    copyDD:SetSize(260, 26)
    copyDD:SetDefaultText("Choose a profile")
    copyDD:SetupMenu(function(_, root)
        local list = ns.ListProfiles and ns.ListProfiles() or {}
        if #list == 0 then
            root:CreateButton("|cff808080No other characters' profiles yet|r", function() end)
            return
        end
        for _, p in ipairs(list) do
            local key, lbl = p.key, p.label
            root:CreateRadio(lbl,
                function() return selectedProfile == key end,
                function() selectedProfile = key; selectedLabel = lbl; copyDD:SetText(lbl); copyDD:GenerateMenu() end)
        end
    end)
    sharePanel.y = sharePanel.y - 34
    local copyStatus = AddStatusLine(sharePanel)
    sharePanel.Button("Copy here", 160, function()
        if not selectedProfile then copyStatus:SetText("|cffff6060Pick a profile first.|r"); return end
        local nm = selectedLabel or "that profile"
        StaticPopup_Show("AURACUE_CONFIRM",
            "Replace this character/spec's AuraCue profile with a copy of \"" .. nm .. "\"? " ..
            "Your current watch list and settings here are overwritten.",
            nil, { onaccept = function()
                local ok, res = ns.CopyProfileFrom(selectedProfile)
                copyStatus:SetText(ok
                    and ("|cff60ff60Copied " .. tostring(res) .. " aura(s) from " .. nm .. ".|r")
                    or  ("|cffff6060" .. tostring(res) .. "|r"))
            end })
    end)

    -- Export.
    sharePanel.Header("Export")
    sharePanel.Desc("Export this spec's profile, or the whole aura catalog, to a string you can save " ..
        "or share. The string appears below — click the box, then Ctrl+A and Ctrl+C to copy it.")
    local exportBox, exportScroll = AddShareBox(sharePanel, 130)
    local exportStatus = AddStatusLine(sharePanel)
    sharePanel.SideBySide(
        "Export profile", function()
            exportBox:SetText(ns.ExportProfile()); exportScroll:SetVerticalScroll(0)
            exportBox:SetFocus(); exportBox:HighlightText()
            exportStatus:SetText("|cff808080Profile string ready — Ctrl+A, Ctrl+C to copy.|r")
        end,
        "Export catalog", function()
            exportBox:SetText(ns.ExportCatalog()); exportScroll:SetVerticalScroll(0)
            exportBox:SetFocus(); exportBox:HighlightText()
            exportStatus:SetText("|cff808080Catalog string ready — Ctrl+A, Ctrl+C to copy.|r")
        end)

    -- Import.
    sharePanel.Header("Import")
    sharePanel.Desc("Paste a profile or catalog string into the box below, then click Import. " ..
        "A profile replaces this spec's tracked auras and settings; a catalog merges into your aura list.")
    local importBox = AddShareBox(sharePanel, 130)
    local importStatus = AddStatusLine(sharePanel)
    sharePanel.Button("Import", 160, function()
        local oki, msg = ns.ImportShare(importBox:GetText() or "")
        importStatus:SetText((oki and "|cff60ff60" or "|cffff6060") .. (msg or "") .. "|r")
        if oki then importBox:SetText("") end
    end)

    content:SetHeight(-sharePanel.y + 20)
end

-- Localized class names (built once), for the detail dialog's class dropdown.
local CLASS_NAMES
local function getClassNames()
    if not CLASS_NAMES then
        CLASS_NAMES = {}
        local n = (GetNumClasses and GetNumClasses()) or 0
        for i = 1, n do
            local nm = GetClassInfo and GetClassInfo(i)
            if nm then CLASS_NAMES[#CLASS_NAMES + 1] = nm end
        end
        table.sort(CLASS_NAMES)
    end
    return CLASS_NAMES
end

-- A dialog to edit a catalogued aura's stored details (name, dungeon, source,
-- class, kind, boss). Created lazily; reused for each row. `sp` is a GetSeenAuras
-- entry.
local detailDialog
local function OpenDetailDialog(sp, after)
    if not sp then return end
    local sid = sp.spellID
    if not detailDialog then
        local d = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        d:SetSize(380, 350)
        d:SetPoint("CENTER")
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:EnableMouse(true)
        d:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        d.title = d:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        d.title:SetPoint("TOP", 0, -16)
        local function field(labelText, yoff)
            local lbl = d:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            lbl:SetPoint("TOPLEFT", 24, yoff)
            lbl:SetText(labelText)
            local eb = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
            eb:SetPoint("TOPLEFT", 28, yoff - 18)
            eb:SetSize(310, 20)
            eb:SetAutoFocus(false)
            eb:SetFontObject("ChatFontNormal")
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            return eb
        end
        d.dungeonBox = field("Dungeon", -44)
        d.sourceBox = field("Discovered by (source)", -94)
        d.groupBox = field("Custom group", -144)

        local classLbl = d:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        classLbl:SetPoint("TOPLEFT", 24, -194)
        classLbl:SetText("Class")
        d.classDD = CreateFrame("DropdownButton", nil, d, "WowStyle1DropdownTemplate")
        d.classDD:SetPoint("TOPLEFT", 28, -212)
        d.classDD:SetSize(180, 26)
        d.classDD:SetupMenu(function(_, root)
            root:CreateRadio("(none)",
                function() return not d.selClass end,
                function() d.selClass = nil; d.classDD:SetText("(none)"); d.classDD:GenerateMenu() end)
            for _, cn in ipairs(getClassNames()) do
                root:CreateRadio(cn,
                    function() return d.selClass == cn end,
                    function() d.selClass = cn; d.classDD:SetText(cn); d.classDD:GenerateMenu() end)
            end
        end)

        d.kindCheck = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
        d.kindCheck:SetPoint("TOPLEFT", 24, -250); d.kindCheck:SetSize(24, 24)
        local kindFS = d:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        kindFS:SetPoint("LEFT", d.kindCheck, "RIGHT", 2, 1); kindFS:SetText("Treat as a debuff")

        d.save = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        d.save:SetSize(100, 24); d.save:SetText("Save")
        d.save:SetPoint("BOTTOMRIGHT", -20, 16)
        d.cancel = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        d.cancel:SetSize(100, 24); d.cancel:SetText("Cancel")
        d.cancel:SetPoint("RIGHT", d.save, "LEFT", -8, 0)
        d.cancel:SetScript("OnClick", function() d:Hide() end)
        d:Hide()
        detailDialog = d
    end
    local d = detailDialog
    d.title:SetText(sp.name or ("Spell " .. tostring(sid)))
    d.dungeonBox:SetText(sp.dungeon or "")
    d.sourceBox:SetText(sp.source or "")
    d.groupBox:SetText(sp.group or "")
    d.selClass = sp.className
    d.classDD:SetText(sp.className or "(none)")
    d.classDD:GenerateMenu()
    d.kindCheck:SetChecked(sp.kind == "debuff")
    d.save:SetScript("OnClick", function()
        ns.SetAuraGroup(sid, d.groupBox:GetText())
        ns.SetAuraDetail(sid, {
            dungeon   = d.dungeonBox:GetText(),
            source    = d.sourceBox:GetText(),
            className = d.selClass or "",
            kind      = d.kindCheck:GetChecked() and "debuff" or "buff",
        })
        d:Hide()
        if after then after() end
    end)
    d:Show()
    d:Raise()
end

-- ---------------------------------------------------------------------
-- "Manage Auras" subcategory: an edit list over the whole account-wide
-- catalog — set custom groups, hide clutter, or remove entries, one at a
-- time or in bulk via the row checkboxes.
-- ---------------------------------------------------------------------
local managePanel = NewPanel("Manage Auras")
do
    local content, LEFT = managePanel.content, managePanel.LEFT
    local ROW, MAX_ROWS = 24, 200

    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, managePanel.y)
    titleFS:SetText("Manage Auras")
    managePanel.y = managePanel.y - 24
    managePanel.Desc("Your whole aura catalog (account-wide). Set a custom group, hide clutter, or " ..
        "remove an entry. Tick rows to act on several at once. Removing an aura just forgets it here; " ..
        "it returns to the list if you see it again.")

    local search, showHidden = "", false
    local kindFilter, hideMounts, ungroupedOnly = "all", false, false
    local classFilter = "all"
    local selected = {}
    local rows, Rebuild = {}, nil

    -- Search box.
    local sLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sLabel:SetPoint("TOPLEFT", LEFT, managePanel.y)
    sLabel:SetText("Search")
    local sBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    sBox:SetPoint("LEFT", sLabel, "RIGHT", 12, 0)
    sBox:SetSize(220, 22)
    sBox:SetAutoFocus(false)
    sBox:SetFontObject("ChatFontNormal")
    sBox:SetScript("OnTextChanged", function(self) search = (self:GetText() or ""):lower():trim(); Rebuild() end)
    sBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    managePanel.y = managePanel.y - 30

    -- Filters.
    local kindLbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    kindLbl:SetPoint("TOPLEFT", LEFT, managePanel.y)
    kindLbl:SetText("Kind")
    local KIND_LABEL = { all = "All", buff = "Buffs only", debuff = "Debuffs only" }
    local kindDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    kindDD:SetPoint("LEFT", kindLbl, "RIGHT", 12, 0)
    kindDD:SetSize(140, 26)
    kindDD:SetupMenu(function(_, root)
        for _, k in ipairs({ "all", "buff", "debuff" }) do
            root:CreateRadio(KIND_LABEL[k],
                function() return kindFilter == k end,
                function() kindFilter = k; kindDD:SetText(KIND_LABEL[k]); kindDD:GenerateMenu(); Rebuild() end)
        end
    end)
    kindDD:SetText(KIND_LABEL[kindFilter])

    local classLbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classLbl:SetPoint("LEFT", kindDD, "RIGHT", 20, 0)
    classLbl:SetText("Class")
    local classDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    classDD:SetPoint("LEFT", classLbl, "RIGHT", 12, 0)
    classDD:SetSize(150, 26)
    classDD:SetupMenu(function(_, root)
        root:CreateRadio("All classes",
            function() return classFilter == "all" end,
            function() classFilter = "all"; classDD:SetText("All classes"); classDD:GenerateMenu(); Rebuild() end)
        root:CreateRadio("(untagged)",
            function() return classFilter == "none" end,
            function() classFilter = "none"; classDD:SetText("(untagged)"); classDD:GenerateMenu(); Rebuild() end)
        for _, cn in ipairs(getClassNames()) do
            root:CreateRadio(cn,
                function() return classFilter == cn end,
                function() classFilter = cn; classDD:SetText(cn); classDD:GenerateMenu(); Rebuild() end)
        end
    end)
    classDD:SetText("All classes")
    managePanel.y = managePanel.y - 32

    managePanel.CheckRow(
        "Show hidden auras", function() return showHidden end, function(v) showHidden = v; Rebuild() end,
        "Hide mounts", function() return hideMounts end, function(v) hideMounts = v; Rebuild() end)
    managePanel.Check("Only un-grouped auras",
        function() return ungroupedOnly end,
        function(v) ungroupedOnly = v; Rebuild() end)

    -- Selection + bulk actions.
    local selFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    selFS:SetPoint("TOPLEFT", LEFT, managePanel.y)
    selFS:SetJustifyH("LEFT")
    managePanel.y = managePanel.y - 20

    local function SelectedList()
        local out = {}
        for key in pairs(selected) do out[#out + 1] = tonumber(key) end
        return out
    end
    local function UpdateSelFS()
        local n = 0
        for _ in pairs(selected) do n = n + 1 end
        selFS:SetText("|cffffd200" .. n .. "|r selected — actions below apply to ticked rows")
    end

    local function smallBtn(label, w, onClick)
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end
    local bx = LEFT
    local function placeBtn(b) b:SetPoint("TOPLEFT", bx, managePanel.y); bx = bx + b:GetWidth() + 6 end

    local bGroup = smallBtn("Group…", 70, function()
        local list = SelectedList()
        if #list == 0 then return end
        StaticPopup_Show("AURACUE_SET_GROUP", #list .. " selected auras", nil,
            { sids = list, current = "", after = function() RefreshAllPanels() end })
    end)
    local bHide = smallBtn("Hide", 56, function()
        for _, sid in ipairs(SelectedList()) do ns.SetAuraIgnored(sid, true) end
        RefreshAllPanels()
    end)
    local bShow = smallBtn("Restore", 64, function()
        for _, sid in ipairs(SelectedList()) do ns.SetAuraIgnored(sid, false) end
        RefreshAllPanels()
    end)
    local bRemove = smallBtn("Remove", 70, function()
        local list = SelectedList()
        if #list == 0 then return end
        StaticPopup_Show("AURACUE_CONFIRM",
            "Permanently remove " .. #list .. " selected aura(s) from your saved catalog? " ..
            "Any custom group and hide settings for them are lost too. They only return if you see them again.",
            nil, { onaccept = function()
                for _, sid in ipairs(list) do ns.ForgetAura(sid); selected[tostring(sid)] = nil end
                RefreshAllPanels()
            end })
    end)
    -- "Clear selection" only un-ticks the rows; it changes no saved data.
    local bClear = smallBtn("Clear selection", 110, function() wipe(selected); RefreshAllPanels() end)
    placeBtn(bGroup); placeBtn(bHide); placeBtn(bShow); placeBtn(bRemove); placeBtn(bClear)
    managePanel.y = managePanel.y - 30

    -- Custom-group management: rename or delete a whole group at once.
    local selectedGroup
    local grpLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    grpLabel:SetPoint("TOPLEFT", LEFT, managePanel.y)
    grpLabel:SetText("Custom groups:")
    local grpDD = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    grpDD:SetPoint("LEFT", grpLabel, "RIGHT", 12, 0)
    grpDD:SetSize(180, 26)
    grpDD:SetDefaultText("Pick a group")
    grpDD:SetupMenu(function(_, root)
        local names = ns.GetAuraGroupNames and ns.GetAuraGroupNames() or {}
        if #names == 0 then root:CreateButton("|cff808080(no custom groups)|r", function() end); return end
        for _, gnm in ipairs(names) do
            root:CreateRadio(gnm,
                function() return selectedGroup == gnm end,
                function() selectedGroup = gnm; grpDD:SetText(gnm); grpDD:GenerateMenu() end)
        end
    end)
    local function clearGroupSel()
        selectedGroup = nil; grpDD:SetText("Pick a group"); grpDD:GenerateMenu()
    end
    local grpRename = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    grpRename:SetPoint("LEFT", grpDD, "RIGHT", 8, 0); grpRename:SetSize(80, 22); grpRename:SetText("Rename…")
    grpRename:SetScript("OnClick", function()
        if not selectedGroup then return end
        StaticPopup_Show("AURACUE_RENAME_GROUP", selectedGroup, nil,
            { old = selectedGroup, after = clearGroupSel })
    end)
    local grpDelete = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    grpDelete:SetPoint("LEFT", grpRename, "RIGHT", 6, 0); grpDelete:SetSize(70, 22); grpDelete:SetText("Delete")
    grpDelete:SetScript("OnClick", function()
        if not selectedGroup then return end
        local g = selectedGroup
        StaticPopup_Show("AURACUE_CONFIRM",
            "Delete the group \"" .. g .. "\"? The auras stay; they just lose this group.",
            nil, { onaccept = function() ns.DeleteAuraGroup(g); clearGroupSel() end })
    end)
    managePanel.y = managePanel.y - 32

    local countFS = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    countFS:SetPoint("TOPLEFT", LEFT, managePanel.y)
    countFS:SetJustifyH("LEFT")
    managePanel.y = managePanel.y - 18

    local listTop = managePanel.y

    local function MakeManageRow(i)
        local r = CreateFrame("Frame", nil, content)
        r:SetHeight(ROW)
        r:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, listTop - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, listTop - (i - 1) * ROW)
        r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.cb:SetSize(22, 22)
        r.cb:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.cb:SetScript("OnClick", function(self)
            if not r.sid then return end
            selected[tostring(r.sid)] = self:GetChecked() and true or nil
            UpdateSelFS()
        end)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", r.cb, "RIGHT", 2, 0)
        r.remove = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.remove:SetSize(64, 20); r.remove:SetText("Remove")
        r.remove:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.remove:SetScript("OnClick", function()
            if not r.sid then return end
            local nm = r.auraName or tostring(r.sid)
            StaticPopup_Show("AURACUE_CONFIRM",
                "Permanently remove " .. nm .. " from your saved catalog? " ..
                "It only returns if you see it again.",
                nil, { onaccept = function()
                    ns.ForgetAura(r.sid); selected[tostring(r.sid)] = nil; RefreshAllPanels()
                end })
        end)
        r.hide = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.hide:SetSize(54, 20)
        r.hide:SetPoint("RIGHT", r.remove, "LEFT", -6, 0)
        r.hide:SetScript("OnClick", function()
            if not r.sid then return end
            ns.SetAuraIgnored(r.sid, not r.ignored)
            RefreshAllPanels()
        end)
        r.group = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.group:SetSize(58, 20); r.group:SetText("Group")
        r.group:SetPoint("RIGHT", r.hide, "LEFT", -6, 0)
        r.group:SetScript("OnClick", function()
            if not r.sid then return end
            StaticPopup_Show("AURACUE_SET_GROUP", r.auraName or tostring(r.sid), nil,
                { sid = r.sid, current = r.group_name or "", after = function() RefreshAllPanels() end })
        end)
        r.edit = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.edit:SetSize(44, 20); r.edit:SetText("Edit")
        r.edit:SetPoint("RIGHT", r.group, "LEFT", -6, 0)
        r.edit:SetScript("OnClick", function()
            if not r.sp then return end
            OpenDetailDialog(r.sp, function() RefreshAllPanels() end)
        end)
        r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.text:SetPoint("RIGHT", r.edit, "LEFT", -8, 0)
        r.text:SetJustifyH("LEFT")
        r:SetScript("OnEnter", function()
            if r.sid and GameTooltip.SetSpellByID then
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(r.sid); GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:EnableMouse(true)
        rows[i] = r
        return r
    end

    Rebuild = function()
        if not ns.P() then return end
        UpdateSelFS()
        local shown, total = 0, 0
        for _, sp in ipairs(ns.GetSeenAuras()) do
            -- Checked "Show hidden" lists exactly the hidden auras; otherwise
            -- the non-hidden ones. Then the kind / mount / group filters.
            local hasClass = sp.className and sp.className ~= ""
            local classOk = (classFilter == "all")
                or (classFilter == "none" and not hasClass)
                or (sp.className == classFilter)
            local pass = ((sp.ignored and true or false) == showHidden)
                and (kindFilter == "all" or sp.kind == kindFilter)
                and classOk
                and not (hideMounts and sp.mount)
                and not (ungroupedOnly and sp.group and sp.group ~= "")
            if pass then
                local nm = sp.name or ("Spell " .. sp.spellID)
                if search == "" or nm:lower():find(search, 1, true) or tostring(sp.spellID):find(search, 1, true) then
                    total = total + 1
                    if shown < MAX_ROWS then
                        shown = shown + 1
                        local r = rows[shown] or MakeManageRow(shown)
                        r.sid = sp.spellID
                        r.auraName = nm
                        r.ignored = sp.ignored
                        r.group_name = sp.group
                        r.sp = sp
                        r.icon:SetTexture(sp.icon or 134400)
                        r.cb:SetChecked(selected[tostring(sp.spellID)] and true or false)
                        r.hide:SetText(sp.ignored and "Show" or "Hide")
                        local tag = (sp.kind == "debuff") and "  |cffff8080[debuff]|r" or ""
                        if sp.boss then tag = tag .. "  |cffff4040[boss]|r" end
                        if sp.group and sp.group ~= "" then tag = tag .. "  |cff80c0ff[" .. sp.group .. "]|r" end
                        if sp.ignored then tag = tag .. "  |cffff6060(hidden)|r" end
                        r.text:SetText(nm .. tag)
                        r:Show()
                    end
                end
            end
        end
        for i = shown + 1, #rows do rows[i]:Hide() end
        if total == 0 then
            countFS:SetText("|cff808080No auras match — see some in play, or clear the search.|r")
        elseif total > shown then
            countFS:SetText("Showing " .. shown .. " of " .. total .. " — search to narrow.")
        else
            countFS:SetText(total .. " aura(s).")
        end
        content:SetHeight(-(listTop - shown * ROW) + 24)
    end

    managePanel.rebuild = Rebuild
end

-- ---------------------------------------------------------------------
-- Registration: main category + Buffs / Debuffs subcategories.
-- ---------------------------------------------------------------------
local mainCategory
if Settings and Settings.RegisterCanvasLayoutCategory then
    mainCategory = Settings.RegisterCanvasLayoutCategory(main.panel, "AuraCue")
    Settings.RegisterAddOnCategory(mainCategory)
    if Settings.RegisterCanvasLayoutSubcategory then
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, appearancePanel.panel, "Appearance")
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, buffPanel.panel, "Buffs")
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, debuffPanel.panel, "Debuffs")
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, managePanel.panel, "Manage Auras")
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, sharePanel.panel, "Sharing")
    end
end

function ns.InitOptions() RefreshAllPanels() end

function ns.OpenOptions()
    if not mainCategory then return end
    RefreshAllPanels()
    C_Timer.After(0, function()
        Settings.OpenToCategory(mainCategory:GetID())
    end)
end

-- Open if closed, close if already open (used by the minimap left-click).
function ns.ToggleOptions()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    else
        ns.OpenOptions()
    end
end
