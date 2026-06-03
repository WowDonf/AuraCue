-- =====================================================================
-- CueSense - Options panels (Settings canvas + subcategories)
-- =====================================================================
-- Three registered panels: a main "CueSense" page (General + Audio) and
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

-- Every panel registers a refresh function here; ns.RefreshOptions runs
-- them all (used by slash commands and cross-panel updates).
local refreshers = {}
local function RefreshAllPanels()
    if not ns.P() then return end
    for _, fn in ipairs(refreshers) do fn() end
end
ns.RefreshOptions = RefreshAllPanels
ns.RebuildList = RefreshAllPanels

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

    function ctx.Check(label, getter, setter)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", LEFT, ctx.y)
        cb:SetSize(26, 26)
        local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        fs:SetText(label)
        cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
        cb.Refresh = function() cb:SetChecked(getter() and true or false) end
        widgets[#widgets + 1] = cb
        ctx.y = ctx.y - 30
        return cb
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
-- A colour-swatch button bound to a color table getter.
-- ---------------------------------------------------------------------
local function AddColorButton(ctx, getColor)
    local colorBtn = ctx.Button("Flash color...", 140, function() end)
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
    ctx.widgets[#ctx.widgets + 1] = colorBtn
end

-- ---------------------------------------------------------------------
-- Main panel: General + Audio.
-- ---------------------------------------------------------------------
local main = NewPanel("CueSense")
do
    local content, LEFT = main.content, main.LEFT

    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, main.y)
    titleFS:SetText("CueSense")
    main.y = main.y - 22
    local subFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subFS:SetPoint("TOPLEFT", LEFT, main.y)
    subFS:SetText("Turn your own auras into sound and/or on-screen cues. Configure buffs and debuffs in the sections to the left.")
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

    main.Header("General")
    main.Check("Enable CueSense",
        function() return ns.P().enabled end,
        function(v) ns.P().enabled = v end)
    main.Check("Track buffs (helpful auras)",
        function() return ns.P().trackBuffs end,
        function(v) ns.P().trackBuffs = v end)
    main.Check("Track debuffs (harmful auras)",
        function() return ns.P().trackDebuffs end,
        function(v) ns.P().trackDebuffs = v end)
    main.Check("Show minimap button",
        function() return not ns.IsMinimapShown or ns.IsMinimapShown() end,
        function(v) if ns.SetMinimapShown then ns.SetMinimapShown(v) end end)

    main.Header("Audio cue")
    main.Check("Play sound cues",
        function() return ns.P().audioEnabled end,
        function(v) ns.P().audioEnabled = v end)
    main.Desc("Master switch for all cue sounds. Each aura's gained / faded sound is set in " ..
        "its section; this is the audio channel they route through, so blind / low-vision " ..
        "players can balance cue volume against game audio.")
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
        "CueSense say its name aloud. These settings control the voice.")
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
    main.Button("Test speech", 160, function() ns.Speak("CueSense speech test") end)

    -- Sharing: export the current spec's profile or the whole catalog to a
    -- string, or paste one in to import.
    main.Header("Sharing")
    main.Desc("Export this spec's profile or the whole aura catalog to a string to save or share, " ..
        "or paste one below and Import. Click the box, then Ctrl+A and Ctrl+C to copy.")

    local boxBG = CreateFrame("Frame", nil, content, "BackdropTemplate")
    boxBG:SetPoint("TOPLEFT", LEFT, main.y)
    boxBG:SetSize(520, 58)
    boxBG:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    boxBG:SetBackdropColor(0, 0, 0, 0.6)
    local shareBox = CreateFrame("EditBox", nil, boxBG)
    shareBox:SetMultiLine(true)
    shareBox:SetPoint("TOPLEFT", 8, -6)
    shareBox:SetPoint("BOTTOMRIGHT", -8, 6)
    shareBox:SetAutoFocus(false)
    shareBox:SetFontObject("ChatFontNormal")
    shareBox:SetMaxLetters(0)
    shareBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    main.y = main.y - 66

    local shareStatus = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

    main.SideBySide(
        "Export profile", function()
            shareBox:SetText(ns.ExportProfile()); shareBox:SetFocus(); shareBox:HighlightText()
            shareStatus:SetText("|cff808080Profile string ready — Ctrl+A, Ctrl+C to copy.|r")
        end,
        "Export catalog", function()
            shareBox:SetText(ns.ExportCatalog()); shareBox:SetFocus(); shareBox:HighlightText()
            shareStatus:SetText("|cff808080Catalog string ready — Ctrl+A, Ctrl+C to copy.|r")
        end)
    main.Button("Import from box", 160, function()
        local oki, msg = ns.ImportShare(shareBox:GetText() or "")
        shareStatus:SetText((oki and "|cff60ff60" or "|cffff6060") .. (msg or "") .. "|r")
    end)

    shareStatus:SetPoint("TOPLEFT", LEFT, main.y)
    shareStatus:SetWidth(520)
    shareStatus:SetJustifyH("LEFT")
    main.y = main.y - 18

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
    local function Vis() return ns.P().visual[kind] end

    -- Title
    local titleFS = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", LEFT, ctx.y)
    titleFS:SetText(label)
    ctx.y = ctx.y - 24

    -- Window appearance for this kind.
    ctx.Header(label .. " window")
    ctx.Check("Show on-screen flash",
        function() return Vis().enabled end,
        function(v) Vis().enabled = v end)
    AddColorButton(ctx, function() return Vis().color end)
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
    local pickerSearch, pickerMineOnly, pickerInstanceOnly = "", false, false

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
    searchLabel:SetText("Search")
    local searchBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetSize(140, 22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")

    -- True if an aura belongs in this panel and passes the filters.
    local function passes(sp)
        if ((sp.kind == "debuff") and "debuff" or "buff") ~= kind then return false end
        if pickerMineOnly and not sp.mine then return false end
        if pickerInstanceOnly and not sp.instanceable then return false end
        return true
    end

    -- Live results popup under the search box.
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
        if pickerSearch == "" or not ns.P() then searchResults:Hide(); return end
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
        addDD:GenerateMenu()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus(); searchResults:Hide()
    end)

    addDD:SetupMenu(function(_, root)
        if not ns.P() then return end
        if root.SetScrollMode then root:SetScrollMode(GetScreenHeight() * 0.6) end
        local shown = 0
        for _, sp in ipairs(ns.GetSeenAuras()) do
            local sid = sp.spellID
            local nm = sp.name or ("Spell " .. sid)
            local matchText = pickerSearch == ""
                or nm:lower():find(pickerSearch, 1, true)
                or tostring(sid):find(pickerSearch, 1, true)
            if matchText and passes(sp) then
                shown = shown + 1
                local txt = string.format("|T%d:16:16:0:0|t %s", sp.icon or 134400, nm)
                if ns.P().cues[tostring(sid)] then txt = txt .. "  |cff808080(watching)|r" end
                if sp.secret then txt = txt .. "  |cffff6060(may be hidden in instances)|r" end
                local btn = root:CreateButton(txt, function()
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
                    end)
                end
            end
        end
        if shown == 0 then
            root:CreateButton("|cff808080No " .. label:lower() .. " match — type, or add by spell ID|r", function() end)
        end
    end)
    ctx.y = ctx.y - 38

    ctx.Check("Only show auras I cast",
        function() return pickerMineOnly end,
        function(v) pickerMineOnly = v; addDD:GenerateMenu(); UpdateSearchResults() end)
    ctx.Check("Only show ones trackable in instances",
        function() return pickerInstanceOnly end,
        function(v) pickerInstanceOnly = v; addDD:GenerateMenu(); UpdateSearchResults() end)

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
            if cue.source then GameTooltip:AddLine("Source: " .. cue.source, 0.8, 0.8, 0.8) end
            if cue.dungeon then GameTooltip:AddLine("Dungeon: " .. cue.dungeon, 0.8, 0.8, 0.8) end
            if cue.castSeen then
                GameTooltip:AddLine("Tracked by: your cast — works in instances.", 0.5, 0.85, 0.5)
            else
                GameTooltip:AddLine("Tracked by: aura read — open world only. Cast it once to switch to cast tracking.", 0.75, 0.72, 0.45)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
                            if key == "speak" then ns.Speak("CueSense") else ns.PlaySoundEntry(key, c.channel or ns.P().channel) end
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
        local groups, total = {}, 0
        for sid, cue in pairs(ns.P().cues) do
            local k = (cue.kind == "debuff") and "debuff" or "buff"
            if k == kind then
                local cat = cue.category or label
                groups[cat] = groups[cat] or {}
                local g = groups[cat]
                g[#g + 1] = sid
                total = total + 1
            end
        end
        local cats = {}
        for cat in pairs(groups) do cats[#cats + 1] = cat end
        table.sort(cats, function(a, b)
            local ra, rb = (a == label) and 0 or 1, (b == label) and 0 or 1
            if ra ~= rb then return ra < rb end
            return a < b
        end)

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
        if total == 0 then emptyText:Show() else emptyText:Hide() end
        content:SetHeight(-editorTopY + listH + 30)
    end

    ctx.rebuild = RebuildList
    return ctx
end

local buffPanel = BuildKindPanel("buff")
local debuffPanel = BuildKindPanel("debuff")

-- ---------------------------------------------------------------------
-- Registration: main category + Buffs / Debuffs subcategories.
-- ---------------------------------------------------------------------
local mainCategory
if Settings and Settings.RegisterCanvasLayoutCategory then
    mainCategory = Settings.RegisterCanvasLayoutCategory(main.panel, "CueSense")
    Settings.RegisterAddOnCategory(mainCategory)
    if Settings.RegisterCanvasLayoutSubcategory then
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, buffPanel.panel, "Buffs")
        Settings.RegisterCanvasLayoutSubcategory(mainCategory, debuffPanel.panel, "Debuffs")
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
