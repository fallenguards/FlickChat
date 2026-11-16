local _, ns = ...
local L = ns.L

-- Typing practice: a minute of everyday words to type, shown over the chat window's lines so it takes no room of
-- its own and the typing line under it is the real one. Nothing typed here is sent or learned. The keyboard hands
-- over each kept word (Typed), the first flick (Flick), A (Again) and its closing (Stop) while ns.practice is set.

local SECONDS, COMMON, ROWS_SHOWN = 60, 300, 2
local GREEN, RED, YELLOW, WHITE, GREY = "|cff59d96b", "|cffff5a4d", "|cfff0e342", "|cffffffff", "|cff8c8c8c"

local pane, run

local function Build()
    pane = CreateFrame("Frame", "FlickChatPractice", UIParent)
    pane:Hide()
    local back = pane:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.04, 0.04, 0.05, 1)
    pane.title = pane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pane.title:SetPoint("TOPLEFT", 10, -8)
    pane.title:SetText(L["PRACTICE_TITLE"])
    pane.clock = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    pane.clock:SetPoint("TOPRIGHT", -10, -6)
    pane.words = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    pane.words:SetPoint("LEFT", 10, 0)
    pane.words:SetPoint("RIGHT", -10, 0)
    pane.words:SetJustifyH("LEFT")
    pane.words:SetSpacing(6)
    pane.foot = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pane.foot:SetPoint("BOTTOMLEFT", 10, 8)
    pane.foot:SetPoint("BOTTOMRIGHT", -10, 8)
    pane.foot:SetJustifyH("LEFT")
    -- measures a word for the rows
    pane.ruler = pane:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    pane.ruler:Hide()
end

-- A run's words in rows that fit the pane: far more than a minute holds.
local function Rows(width)
    local pool = {}
    for i = 1, COMMON do
        local word = ns.Dict.PracticeWord(i)
        if word then pool[#pool + 1] = word end
    end
    pane.ruler:SetText(" ")
    local space = pane.ruler:GetStringWidth()
    local rows, row, used = {}, {}, 0
    for _ = 1, 400 do
        local word = pool[math.random(#pool)]
        pane.ruler:SetText(word)
        local wide = pane.ruler:GetStringWidth()
        if used + wide > width and #row > 0 then
            rows[#rows + 1] = row
            row, used = {}, 0
        end
        row[#row + 1] = { word = word }
        used = used + wide + space
    end
    return rows
end

local function Score(elapsed)
    local minutes = math.max(elapsed, 1) / 60
    local right = run.tried > 0 and run.right / run.tried * 100 or 100
    return math.floor(run.chars / 5 / minutes + 0.5), math.floor(right + 0.5)
end

local function Paint()
    if not run then return end
    local left = run.started and math.max(0, SECONDS - (GetTime() - run.started)) or SECONDS
    pane.clock:SetText(("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)))
    local lines = {}
    for r = run.row, math.min(run.row + ROWS_SHOWN - 1, #run.rows) do
        local parts = {}
        for i, entry in ipairs(run.rows[r]) do
            local color = entry.right == true and GREEN or entry.right == false and RED
                or (r == run.row and i == run.at and not run.over) and YELLOW or WHITE
            parts[#parts + 1] = color .. entry.word .. "|r"
        end
        lines[#lines + 1] = table.concat(parts, " ")
    end
    pane.words:SetText(table.concat(lines, "\n"))
    if run.over then
        local wpm, right = Score(SECONDS)
        pane.foot:SetText(L["PRACTICE_DONE"]:format(wpm, right, ns.db.practiceBest or wpm) .. "\n"
            .. GREY .. L["PRACTICE_KEYS"]:format(GetBindingText("PAD1", 1), GetBindingText("PAD2", 1)) .. "|r")
    elseif run.started then
        pane.foot:SetText(L["PRACTICE_LIVE"]:format(Score(GetTime() - run.started)))
    else
        pane.foot:SetText(L["PRACTICE_HINT"])
    end
end

local function Finish()
    run.over = true
    if run.ticker then run.ticker:Cancel() end
    run.ticker = nil
    local wpm = Score(SECONDS)
    if wpm > (ns.db.practiceBest or 0) then ns.db.practiceBest = wpm end
    Paint()
end

local function Begin()
    if run and run.ticker then run.ticker:Cancel() end
    run = { rows = Rows(pane:GetWidth() - 20), row = 1, at = 1, tried = 0, right = 0, chars = 0 }
    Paint()
end

local practice = {}

-- The first flick starts the clock.
function practice.Flick()
    if run.started or run.over then return end
    run.started = GetTime()
    run.ticker = C_Timer.NewTicker(0.25, function()
        if GetTime() - run.started >= SECONDS then Finish() else Paint() end
    end)
end

-- A word kept on the keyboard: right or wrong against the lit one, then on to the next.
function practice.Typed(word)
    if run.over then return end
    practice.Flick()
    local entry = run.rows[run.row][run.at]
    entry.right = ns.Lower(word) == entry.word
    run.tried = run.tried + 1
    if entry.right then
        run.right = run.right + 1
        run.chars = run.chars + #ns.Characters(entry.word) + 1
    end
    run.at = run.at + 1
    if run.at > #run.rows[run.row] then
        run.row, run.at = run.row + 1, 1
        if run.row > #run.rows then return Finish() end
    end
    Paint()
end

-- A: once the minute is up, another one.
function practice.Again()
    if run.over then Begin() end
end

function practice.Stop()
    if run and run.ticker then run.ticker:Cancel() end
    run, ns.practice = nil, nil
    if pane then pane:Hide() end
end

-- Over the chat window's own lines, at its size, a level above them.
function ns.StartPractice(edit)
    local chat = edit.chatFrame
    if not chat or chat:IsForbidden() then return end
    if not pane then Build() end
    -- Over the whole chat window (its background runs a little past its text area), and a strata above it: the
    -- chat's own lines are drawn by child frames that stand over anything at the window's own level.
    local back = chat.GetName and _G[(chat:GetName() or "") .. "Background"]
    pane:ClearAllPoints()
    pane:SetAllPoints(back and not back:IsForbidden() and back or chat)
    pane:SetFrameStrata("DIALOG")
    pane:SetFrameLevel(1)
    pane:Show()
    ns.practice = practice
    Begin()
end

-- /flick practice or the settings row: the next time chat opens.
function ns.PracticeNext(button)
    ns.practiceNext = true
    ns.Tell(L["PRACTICE_NEXT"], button)
end
