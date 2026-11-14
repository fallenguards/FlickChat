local addonName, ns = ...

-- The settings: a window of the addon's own, worked wholly from the controller and by the mouse. Two ways in:
-- on its own in the middle of the screen (the keyboard's wheel, /flick options), where it takes the pad itself
-- (d-pad, A, B); and laid into its page on the game's Options, AddOns list, where it takes nothing: its rows are
-- the game's own cursor's to walk, so right goes in from the list, left goes back, and the game's arrow stands
-- on the row.
-- Nothing of it is on the game's Settings window: rows there mark that window's list as an addon's, and the
-- game's own drop-downs on it then fail.

local WIDTH, ROW_H, SHOWN, EDGE = 600, 26, 15, 24
local VALUE_W = 230
local STEP = 5
local window, rows, focus
local specs

local function Glyph(key) return GetBindingText(key, 1) or "" end

-- The rows in order. head: a section's title. check and slider read and write through Core's ROWS.
local function Specs()
    local L, R = ns.L, ns.optionRows
    local list = {}
    local function Head(text) list[#list + 1] = { head = text } end
    local function Check(key, label) list[#list + 1] = { check = R[key], label = label } end
    local function Slider(key, label, low, high, tip)
        list[#list + 1] = { slider = R[key], label = label, low = low, high = high, tip = tip }
    end
    local function Button(label, text, press, tip) list[#list + 1] = { press = press, label = label, text = text, tip = tip } end
    Head(L["OPT_HEAD_OPTIONS"])
    Button(L["OPT_LANGUAGE"], ns.LanguageName, function() ns.NextLanguage() end, L["OPT_LANGUAGE_TIP"])
    Check("lowercase", L["OPT_LOWERCASE"])
    Check("matureFilter", L["OPT_MATURE"])
    Check("phraseSend", L["OPT_PHRASE_SEND"])
    Check("hideLine", L["OPT_HIDE_LINE"])
    Check("hideBar", L["OPT_HIDE_BAR"])
    Check("hideGuide", L["OPT_HIDE_GUIDE"])
    Check("stickTips", L["OPT_STICK_TIPS"])
    Head(L["OPT_HEAD_SIZE"])
    Slider("size", L["OPT_SIZE"], 70, 200)
    Button(L["OPT_SHAPE"], ns.ShapeName, function() ns.NextShape() end, L["OPT_SHAPE_TIP"])
    -- stacked, the words have the keyboard's whole width already: the row says why it changes nothing
    Slider("wordRoom", L["OPT_WORD_ROOM"], 70, 160, function() return ns.Stacked() and L["OPT_WORD_ROOM_STACKED"] or "" end)
    Slider("wheelSize", L["OPT_WHEEL_SIZE"], 50, 150)
    Button(L["OPT_MOVE"], L["OPT_MOVE_BUTTON"], function(well) ns.MoveNext(well) end, L["OPT_MOVE_TIP"])
    Head(L["OPT_HEAD_PRACTICE"])
    Button(L["OPT_PRACTICE"], L["OPT_PRACTICE_BUTTON"], function(well) ns.PracticeNext(well) end, L["OPT_PRACTICE_TIP"])
    Button(L["OPT_LESSON"], L["OPT_LESSON_BUTTON"], function(well) ns.RunLessonAgain(well) end)
    Head(L["OPT_HEAD_WORDS"])
    Button(L["OPT_WORDS"], ns.MyWordsText, function(well) return ns.EditPhrase(well, "words") end, L["OPT_WORDS_TIP"])
    Button(L["OPT_FORGOT"], L["OPT_FORGOT_BUTTON"], function() ns.ForgottenBack() end, L["OPT_FORGOT_TIP"])
    Head(L["OPT_HEAD_PHRASES"])
    for slot = 1, 8 do
        Button(L["PHRASE_SLOT_" .. slot], function() return ns.Phrase(slot) or "" end,
            function(well) return ns.EditPhrase(well, slot) end, L["OPT_PHRASE_TIP"])
    end
    Button(L["OPT_PHRASES"], L["OPT_RESET"], function() ns.ResetPhrases() end)
    return list
end

local function ValueText(spec)
    if spec.slider then return ns.L["SIZE_VALUE"]:format(spec.slider[1]() or 100) end
    if type(spec.text) == "function" then return spec.text() end
    return spec.text or ""
end

local function Refresh()
    for i, row in ipairs(rows) do
        local spec = specs[i]
        if spec.check then
            row.mark:SetShown(spec.check[1]() == true)
        elseif not spec.head then
            row.value:SetText(ValueText(spec))
        end
        row.lit:SetShown(i == focus)
    end
    local spec = specs[focus]
    local tip = spec and spec.tip
    if type(tip) == "function" then tip = tip() end
    window.tip:SetText(tip or "")
end

-- The focused row kept in sight.
local function Follow()
    local scroll = window.scroll
    local top, bottom = (focus - 1) * ROW_H, focus * ROW_H
    local at, room = scroll:GetVerticalScroll(), SHOWN * ROW_H
    -- A section's first row brings its title in with it.
    if focus > 1 and specs[focus - 1].head then top = top - ROW_H end
    if top < at then at = top elseif bottom > at + room then at = bottom - room end
    scroll:SetVerticalScroll(math.max(0, math.min(#specs * ROW_H - room, at)))
end

local function Focus(i)
    focus = i
    Follow()
    Refresh()
end

local function Step(by)
    local i = focus
    repeat
        i = i + by
    until not specs[i] or not specs[i].head
    if specs[i] then
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        Focus(i)
    end
end

-- A row worked: A (by 0) flips a box or presses a button; left and right (by -1, 1) move a slider.
local function Act(i, by)
    local spec, row = specs[i], rows[i]
    if not spec or spec.head then return end
    if spec.check then
        if by ~= 0 then return end
        spec.check[2](not spec.check[1]())
    elseif spec.slider then
        if by == 0 then return end
        local value = (spec.slider[1]() or 100) + by * STEP
        spec.slider[2](math.max(spec.low, math.min(spec.high, value)))
    elseif by == 0 then
        local edit = spec.press(row.well)
        -- A typing box over the row: the pad is the keyboard's until the box goes.
        if edit and edit.IsShown and edit:IsShown() then
            window:EnableGamePadButton(false)
            if not window.editHooked then
                window.editHooked = true
                edit:HookScript("OnHide", function()
                    if window:IsShown() then
                        window:EnableGamePadButton(window.over == nil)
                        Refresh()
                    end
                end)
            end
            return
        end
        Refresh()
        -- What the press set going stays on the row for a moment (ns.Tell writes it there).
        return
    end
    Refresh()
end

local PRESSES = {
    PADDUP = function() Step(-1) end,
    PADDDOWN = function() Step(1) end,
    PADDLEFT = function() Act(focus, -1) end,
    PADDRIGHT = function() Act(focus, 1) end,
    PADLSHOULDER = function() for _ = 1, 6 do Step(-1) end end,
    PADRSHOULDER = function() for _ = 1, 6 do Step(1) end end,
    PAD1 = function() Act(focus, 0) end,
    PAD2 = function() window:Hide() end,
}

local function BuildRow(parent, i, spec)
    -- A section's title is no button: the game's cursor stops on every button it finds.
    local row = CreateFrame(spec.head and "Frame" or "Button", nil, parent)
    row:SetSize(WIDTH - 2 * EDGE, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW_H)
    local label = row:CreateFontString(nil, "ARTWORK", spec.head and "GameFontNormal" or "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(spec.head or spec.label)
    row.lit = row:CreateTexture(nil, "BACKGROUND")
    row.lit:SetAllPoints()
    row.lit:SetColorTexture(1, 0.82, 0, 0.18)
    row.lit:Hide()
    if spec.head then
        label:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 4)
        label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local rule = row:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(0.6, 0.45, 0.2, 0.7)
        rule:SetHeight(1)
        rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
        rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
        row:EnableMouse(false)
        return row
    end
    if spec.check then
        local box = row:CreateTexture(nil, "ARTWORK")
        box:SetSize(24, 24)
        box:SetPoint("LEFT", row, "LEFT", 2, 0)
        box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        row.mark = row:CreateTexture(nil, "OVERLAY")
        row.mark:SetAllPoints(box)
        row.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    else
        -- The value's place at the right: a button's words, a slider's number. A typing box lies over it.
        local well = CreateFrame("Frame", nil, row)
        well:SetSize(VALUE_W, ROW_H - 4)
        well:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        local back = well:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(1, 1, 1, 0.06)
        row.value = well:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.value:SetPoint("LEFT", well, "LEFT", 6, 0)
        row.value:SetPoint("RIGHT", well, "RIGHT", -6, 0)
        row.value:SetWordWrap(false)
        function well.SetText(_, text) row.value:SetText(text) end
        row.well = well
        if spec.slider then
            -- Less and more at the value's two ends: stops of their own for the game's cursor, and for the mouse.
            for _, side in ipairs({ { "LEFT", -1, "-" }, { "RIGHT", 1, "+" } }) do
                local step = CreateFrame("Button", nil, well)
                step:SetSize(ROW_H - 4, ROW_H - 4)
                step:SetPoint(side[1], well, side[1], 0, 0)
                local mark = step:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
                mark:SetPoint("CENTER")
                mark:SetText(side[3])
                local glow = step:CreateTexture(nil, "HIGHLIGHT")
                glow:SetAllPoints()
                glow:SetColorTexture(1, 0.82, 0, 0.3)
                step:SetScript("OnEnter", function() Focus(i) end)
                step:SetScript("OnClick", function()
                    focus = i
                    Act(i, side[2])
                end)
            end
        end
        label:SetPoint("LEFT", row, "LEFT", 6, 0)
        label:SetPoint("RIGHT", well, "LEFT", -8, 0)
    end
    -- The mouse: over a row is its focus; a click is A, on a slider left adds and right takes away.
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function() Focus(i) end)
    row:SetScript("OnClick", function(_, button)
        focus = i
        if spec.slider then Act(i, button == "RightButton" and -1 or 1) else Act(i, 0) end
    end)
    return row
end

local function Build()
    local L = ns.L
    window = CreateFrame("Frame", "FlickChatOptions", UIParent)
    window:Hide()
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetToplevel(true)
    window:SetSize(WIDTH, 22 + 24 + 12 + SHOWN * ROW_H + 12 + 34 + 18 + 22)
    window:SetPoint("CENTER", 0, 40)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    ns.Dress(window)
    local title = window:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))
    title:SetTextColor(ns.BLUE[1], ns.BLUE[2], ns.BLUE[3])
    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", EDGE, -(22 + 24 + 12))
    scroll:SetSize(WIDTH - 2 * EDGE, SHOWN * ROW_H)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, #specs * ROW_H - SHOWN * ROW_H)
        self:SetVerticalScroll(math.max(0, math.min(most, self:GetVerticalScroll() - delta * ROW_H * 2)))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 2 * EDGE, #specs * ROW_H)
    scroll:SetScrollChild(content)
    window.scroll = scroll
    rows = {}
    for i, spec in ipairs(specs) do rows[i] = BuildRow(content, i, spec) end
    -- Under the list: the focused row's note, then the buttons that work the window.
    window.tip = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    window.tip:SetJustifyH("LEFT")
    window.tip:SetJustifyV("TOP")
    window.tip:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -12)
    window.tip:SetPoint("TOPRIGHT", scroll, "BOTTOMRIGHT", 0, -12)
    window.tip:SetHeight(34)
    window.keys = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    window.keys:SetPoint("BOTTOM", window, "BOTTOM", 0, 20)
    window.keys:SetPoint("LEFT", window, "LEFT", EDGE, 0)
    window.keys:SetPoint("RIGHT", window, "RIGHT", -EDGE, 0)
    window.keys:SetWordWrap(false)
    window:SetScript("OnGamePadButtonDown", function(_, button)
        local press = PRESSES[button]
        if press then press() end
    end)
    window:SetScript("OnShow", function(self)
        self.keys:SetText(L["OPT_KEYS"]:format(Glyph("PADDUP"), Glyph("PADDDOWN"), Glyph("PAD1"), Glyph("PADDLEFT"),
            Glyph("PADDRIGHT"), Glyph("PAD2")))
        self.scroll:SetVerticalScroll(0)
        if self.over then
            self:EnableGamePadButton(false)
            self.keys:SetText("")
            focus = 0
            Refresh()
        else
            self:EnableGamePadButton(true)
            Focus(2)
        end
    end)
    window:SetScript("OnHide", function(self) self:EnableGamePadButton(false) end)
end

-- over: the frame it is centred on (the page on the game's Options window); none, the middle of the screen.
local function Show(on, over)
    if not ns.db then return false end
    if not window then
        specs = Specs()
        Build()
    end
    if on then
        window.over = over
        window:ClearAllPoints()
        if over then
            -- Part of the page, so its rows are among what the game's cursor walks there. Under the page's own
            -- two lines of words, centred across it.
            window:SetParent(over)
            window:SetToplevel(false)
            window:SetFrameStrata(over:GetFrameStrata())
            window:SetFrameLevel(over:GetFrameLevel() + 5)
            window:SetPoint("TOP", over, "TOP", 0, -60)
        else
            window:SetParent(UIParent)
            window:SetFrameStrata("FULLSCREEN_DIALOG")
            window:SetToplevel(true)
            window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        end
    end
    window:SetShown(on)
    -- Laid into the page: the game's cursor reads a window's buttons as the window opens, before these rows were
    -- part of it. It is asked to read them again, by its own call for that (which runs as the game's); it refuses
    -- one in a fight.
    local cursor = SmartNavigation
    if on and over and cursor and cursor.UpdateParent and not InCombatLockdown() then cursor:UpdateParent(window) end
    return true
end

-- /flick options, or the keyboard's wheel: the window, or shut if it is up.
function ns.OpenOptions()
    return Show(not (window and window:IsShown()))
end

-- The way in with no chat and no typing: the addon's name on the game's Options, AddOns list, which the game's
-- controller cursor reaches. Its page is a frame of the addon's own (no row of the game's list is used, so that
-- list stays the game's); as the page shows, the settings window opens over it and takes the pad until B.
function ns.ListOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local page = CreateFrame("Frame")
    page:Hide()
    local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 16, -16)
    text:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    text:SetJustifyH("LEFT")
    text:SetText(ns.L["OPT_PAGE"])
    -- The game's own list of settings rows stays in place under an addon's page, and its cursor still stops on
    -- those rows (the first right from the list landed on one, its tooltip showing). While our page is up that
    -- list is marked as not the cursor's, by the game's call for it; given back as the page goes. Out of a fight
    -- only, so a giving back owed is tried again each second until it is done.
    local hushed = false
    local function Hush(on)
        local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
        if not list or not SmartNavigation_MarkFrameIgnored or not SmartNavigation_ClearIgnoreStatus then return end
        if InCombatLockdown() then
            if not on and hushed then C_Timer.After(1, function() if not page:IsVisible() then Hush(false) end end) end
            return
        end
        if on and not hushed and not list.smartNavigationIgnored then
            hushed = true
            SmartNavigation_MarkFrameIgnored(list)
        elseif not on and hushed then
            hushed = false
            SmartNavigation_ClearIgnoreStatus(list)
        end
    end
    page:SetScript("OnShow", function()
        C_Timer.After(0, function()
            if not page:IsVisible() then return end
            Hush(true)
            Show(true, page)
        end)
    end)
    -- Another page picked, or the Options window shut: the settings opened from here go with it.
    page:SetScript("OnHide", function()
        Hush(false)
        if window and window:IsShown() and window.over == page then window:Hide() end
    end)
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(page, C_AddOns.GetAddOnMetadata(addonName, "Title")))
end
