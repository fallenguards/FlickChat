local _, ns = ...
local L = ns.L
local D = ns.Dict
-- Helpers that came after the file reached Lua's 200 locals, in one table.
local Fit = { UNDER = 90, CLEAR = 12 }

-- The chat box's keyboard on the controller. Each letter is one flick of a stick toward its group (four groups a
-- stick, straight directions only) and the word list works out the word: the best guess sits highlighted in the
-- chat box, three more wait on the d-pad. While it is up it takes the controller, so the character stays put.

-- A plain flick types a group's first: . , ? ! on the left stick.
local SYMBOLS = { ".:;", ",'\"", "?/-", "!()", "1234", "5678", "90+=", "@#%&" }
-- These close up to the word before and take a space after.
local ATTACH = { ["."] = true, [","] = true, ["?"] = true, ["!"] = true }
-- Guess slots by d-pad button; new guesses fill them in this order.
local SLOT_KEYS = { "PADDUP", "PADDLEFT", "PADDRIGHT", "PADDDOWN" }
local SLOT_OF = { PADDUP = 1, PADDLEFT = 2, PADDRIGHT = 3, PADDDOWN = 4 }

-- A stick's spring-back past the middle: the opposite way, within 80 ms, and weak. A flick swung straight from one
-- side to the other (r to y in "trying") goes far past this tilt and counts.
local SNAPBACK, BOUNCE_PEAK = 0.08, 0.7
-- Rolled round the rim from one direction into the next (right then up in one move, Skate style): out at RIM, past
-- TURN degrees from the first direction's middle the first counts and the next begins, once the first had settled
-- within SETTLED degrees of its middle (a flick landing between two directions only re-aims).
local RIM, TURN, SETTLED = 0.8, 60, 30
local DIR_DEGREES = { 90, 0, -90, 180 }
local HOLD_DELAY, HOLD_REPEAT, DOUBLE_TAP, FLASH = 0.45, 0.25, 0.4, 0.18
local FLICK_TIP_USES = 30
-- The symbols page's line shows, hints hidden or not, until the player has held a box and picked from it this often.
local PICK_TIP_USES = 3
-- A pause this long on flicks no whole word fits: the player may think the word done, so say how to spell it.
local MISSING_PAUSE = 1.2
-- The first-run lesson types "anyone need a healer" with each box lit (words that take a few flicks before the
-- d-pad has them); its flicks, taken at a light tilt, set the player's own.
-- The lesson's three lines, word by word: flicks and the d-pad, then a line ending on a question mark, then sending.
-- A line ends after the steps in LESSON_LINE_END (the box is cleared for the next one).
-- Each typing language has its own, all of one shape (the steps name each letter): four
-- words, the fourth the chain drill's; three and a question mark; a short thanks and a smiley.
local LESSON = {}
LESSON.lines = {
    enUS = "anyone need a healer which dungeon tonight ? ty : )",
    ptBR = "precisamos de um healer qual masmorra hoje ? vlw : )",
    frFR = "on cherche un healer quel donjon demain ? merci : )",
    deDE = "wir brauchen einen heiler welcher dungeon heute ? danke : )",
    itIT = "ci serve un healer quale dungeon stasera ? grazie : )",
    esES = "se busca un healer hacemos una mazmorra ? gracias : )",
    ruRU = "мы этот данж знаем кто пойдёт сегодня ? спасибо : )",
}
function LESSON.Use(code)
    local i = 0
    for step in (LESSON.lines[code] or LESSON.lines.enUS):gmatch("%S+") do
        i = i + 1
        LESSON[i] = step
    end
    LESSON.last = LESSON[9] .. " :)"
end
LESSON.Use("enUS")
-- The word that teaches chained flicks (its first five letters are all on one stick), as a drill: its first two
-- letters in one move, then four, then all five (the fifth a swing straight across the middle). A stage not
-- done in one move is asked again, as often as it takes (Y skips the lesson).
LESSON.roll, LESSON.stages = 4, { 2, 4, 5 }
local LESSON_LINE_END, LESSON_LINE_START = { [4] = true, [8] = true }, { [5] = "LESSON_LINE2", [9] = "LESSON_LINE3" }
-- A d-pad slot's direction word (DIR_n): up, left, right, down.
local SLOT_DIR = { 1, 4, 2, 3 }
local LESSON_ARM, LESSON_MIN_FLICKS = 0.4, 8
local NAME_GROUP, NAME_KNOWN, NAME_PLACE = 0.002, 0.0003, 0.0005

-- Text sizes in pixels on a 1080-line screen at size 100: base at text size 100, the rest at the player's (Restyle).
local TEXT = { base = { letter = 18, guess = 18, hint = 13, channel = 14, lesson = 18 } }
for key, size in pairs(TEXT.base) do TEXT[key] = size end
-- The font: a typing language whose letters a game in another alphabet's standard font lacks has its own.
TEXT.font, TEXT.fonts = STANDARD_TEXT_FONT, { ruRU = "Fonts\\FRIZQT___CYR.TTF" }
-- The button guide is its own box above the keyboard (as the game's controller legend is); R3 shows or hides it,
-- and a free line over the top right of the whole stack always says so.
local TOGGLE_GAP = 4
local NOTHING = {}
-- The guesses: a d-pad cross of button marks between the two sticks, each word reaching out from its own.
local CELL_H, HUB_R, DOT, GAP, PAD = 34, 20, 12, 6, 16
local CROSS_W, CROSS_H, MARK_X, MARK_Y = 250, 104, 18, 16
-- The middle's width: the room the guess words have, by the settings page's percent, wider for larger text.
local function CrossW()
    return CROSS_W * (ns.profile.wordRoom or 100) / 100 * math.max(1, (ns.profile.textSize or 100) / 100)
end
-- A side word too long for its arm shrinks to fit, down to this share of its size; past that it is cut.
local SIDE_SHRINK = 2 / 3
-- The letter boxes and their hub: the game's own controller menu art (flat boxes where a client lacks it).
local BOX_ART, LIT_ART, FOCUS_ART = "gamepad-radialgamemenu-txtbox-default", "gamepad-radialgamemenu-txtbox-selected",
    "gamepad-radialgamemenu-txtbox-focus"
local HUB_BG_ART, HUB_ART, DOT_ART = "gamepad-radialgamemenu-ring-bg", "gamepad-radialgamemenu-ring-default",
    "gamepad-radialgamemenu-cursorbg-neutral"
-- The box art's bevel, kept unstretched; the lit art's glow reaches this far past the box.
local BOX_EDGE, LIT_GLOW = 12, 7
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local YELLOW, BLUE, IDLE = { 0.94, 0.89, 0.26 }, { 0.34, 0.71, 0.91 }, { 0.82, 0.82, 0.82 }
local LETTER_COLOR = { 1, 1, 1 }
local FORGET_COLOR = { 1, 0.3, 0.25 }

local UTF8_LAST = "[%z\1-\127\194-\244][\128-\191]*$"
local GetBindingText, GetTime, IsUsingGamepad = _G.GetBindingText, _G.GetTime, _G.IsUsingGamepad

local kb, box
local S = { committed = "", written = "", flicks = "", guesses = {}, stems = {}, shown = 0, slots = {} }
local sticks = { Left = { base = 0 }, Right = { base = 4 } }
sticks.Left.other, sticks.Right.other = sticks.Right, sticks.Left
local Paint, WheelStick, PlaceBy, PlaceGuide

local function Glyph(key) return GetBindingText(key, 1) end

local function Use(action)
    local uses = ns.db.uses
    if (uses[action] or 0) <= FLICK_TIP_USES then uses[action] = (uses[action] or 0) + 1 end
end

local function Groups() return S.symbols and SYMBOLS or ns.LAYOUTS[ns.profile.layout] or ns.LAYOUTS.letters end

local function EndsSentence(text) return text:match("^%s*$") or text:match("[%.!?]%s*$") end

local function PrevLow()
    if EndsSentence(S.committed) then return "<s>" end
    local word = S.committed:match("([%a\128-\255']+)[^%a\128-\255']*$")
    return word and ns.Lower(word) or "<s>"
end

local function Lead()
    return (S.committed ~= "" and not S.committed:find("[%s%(%[/\"'%-@#]$")) and " " or ""
end

local function Cap(word)
    if S.capsLock then return ns.Upper(word) end
    -- Always lowercase: the player's setting, or a dev run's.
    local lowercase = ns.profile.lowercase or (ns.dev and ns.dev.lowercase) or ns.practice ~= nil
    if lowercase then word = ns.Lower(word) end
    if S.caps or (not lowercase and EndsSentence(S.committed)) then return ns.Capital(word) end
    return word
end

-- Flicks no word fits: each group's first letter, so the count still shows.
local function Fallback()
    local groups = ns.LAYOUTS[ns.profile.layout] or ns.LAYOUTS.letters
    return (S.flicks:gsub("%d", function(d) return ns.Characters(groups[tonumber(d)])[1] end))
end

-- What the chat box shows: one letter per flick (stems: the likeliest letters so far, RT steps through them).
local function Word()
    if S.literal then return S.literal end
    if S.flicks ~= "" then return S.stems[S.shown] or Fallback() end
end

local function Show()
    local word = Word()
    local pending = word and (Lead() .. Cap(word)) or ""
    local text = S.committed .. pending
    S.written = text
    box:SetText(text)
    box:SetCursorPosition(#text)
    if pending ~= "" then box:HighlightText(#S.committed, #text) else box:HighlightText(0, 0) end
    Paint()
end

-- Typing outside the keyboard (a key, a linked item) becomes the text; the keyboard's own word is dropped.
local function Sync()
    local text = box:GetText()
    if text == S.written then return end
    S.committed, S.written, S.flicks, S.literal, S.undo, S.autoSpace = text, text, "", nil, nil, false
end

-- Whole-word guesses by rank on the d-pad: up, left, right, down.
local function Place(guesses, stems, shown)
    S.guesses, S.stems, S.shown = guesses, stems, shown
    -- The best on top; the longest of the rest at the bottom, where a word has the cross's whole width.
    local long = 0
    for i = 2, #guesses do
        if long == 0 or #guesses[i] > #guesses[long] then long = i end
    end
    local side = 2
    for i = 1, #SLOT_KEYS do S.slots[i] = nil end
    S.slots[1] = guesses[1]
    for i = 2, #guesses do
        if i ~= long then
            S.slots[side] = guesses[i]
            side = side + 1
        end
    end
    if long > 0 then S.slots[#SLOT_KEYS] = guesses[long] end
end

local function WatchMissing(guesses)
    if S.missTimer then S.missTimer:Cancel() end
    S.missing, S.missTimer = false, nil
    if #S.flicks < 2 then return end
    for _, word in ipairs(guesses) do
        if D.KeyOf(word) == S.flicks then return end
    end
    S.missTimer = C_Timer.NewTimer(MISSING_PAUSE, function()
        S.missing, S.missTimer = true, nil
        if kb:IsShown() then Paint() end
    end)
end

local function Guess()
    local guesses = NOTHING
    -- the passed-through flick, while it is still among the flicks
    if S.pass and (S.flicks == "" or S.pass > #S.flicks) then S.pass = nil end
    if S.flicks ~= "" then
        local stems
        guesses, stems = D.Decode(S.flicks, PrevLow(), S.pass)
        Place(guesses, stems, 1)
    elseif S.literal then
        Place({}, {}, 0)
    else
        Place(D.Next(PrevLow()), {}, 0)
    end
    WatchMissing(guesses)
end

local function FinishLesson()
    local peaks = S.lesson.peaks
    if #peaks >= LESSON_MIN_FLICKS then
        table.sort(peaks)
        local arm = math.max(0.4, math.min(0.6, peaks[math.ceil(#peaks / 2)] * 0.7))
        ns.db.arm, ns.db.rearm = arm, math.max(0.2, math.min(0.3, arm * 0.5))
    end
    ns.db.lessonDone, S.lesson = true, nil
end

-- The lesson's step done: the next one; a line's last word empties the box for the next line.
local function LessonStep(done)
    local lesson = S.lesson
    if not lesson or ns.Lower(done) ~= LESSON[lesson.at] then return end
    -- A line done: the box is emptied for the next.
    if LESSON_LINE_END[lesson.at] then S.committed, S.autoSpace, S.undo = "", false, nil end
    -- Past the last word the lesson waits for the send (Send ends it).
    lesson.at, lesson.rolls = lesson.at + 1, 0
    lesson.asked, lesson.missed, lesson.praise = nil, false, false
end

local function Commit(word, space)
    local before = S.committed
    if S.literal then
        local low = ns.Lower(S.literal)
        ns.db.learned[low] = (ns.db.learned[low] or 0) + 1
        ns.db.forgot[low] = nil
        if S.literal ~= low then ns.db.forms[low] = S.literal end
        D.Refresh(S.names)
    end
    -- An elided word (l') is written onto the next: no space after it.
    if space and D.Joins(ns.Lower(word)) then space = false end
    S.committed = before .. Lead() .. Cap(word) .. (space and " " or "")
    S.undo = { committed = before, flicks = S.flicks, literal = S.literal, shown = S.shown, after = S.committed }
    S.flicks, S.literal, S.caps, S.autoSpace = "", nil, false, space
    -- Practice takes each kept word and the line starts empty again.
    if ns.practice then
        ns.practice.Typed(word)
        S.committed, S.undo, S.autoSpace = "", nil, false
    end
    LessonStep(word)
end

local function TypeSymbol(c)
    local word = Word()
    if word then Commit(word, false) end
    if ATTACH[c] then
        if S.autoSpace then S.committed = S.committed:gsub(" $", "") end
        S.committed = S.committed .. c .. " "
        S.autoSpace = true
    else
        S.committed = S.committed .. c
        S.autoSpace = false
    end
    S.undo = nil
    LessonStep(c)
    Guess()
    Show()
end

local function Flash(digit)
    local cell = kb.cells[digit]
    if not cell then return end
    cell.flashUntil = GetTime() + FLASH
    C_Timer.After(FLASH + 0.02, function() if kb:IsShown() then Paint() end end)
end

-- The quick phrases, one per flick direction (1-4 the left stick's up, right, down, left; 5-8 the right's).
local function PhrasePicks()
    local picks = {}
    for slot = 1, 8 do
        local phrase = ns.Phrase(slot)
        picks[slot] = phrase and { label = phrase } or nil
    end
    return picks
end

-- The message typed so far, the pending word as the box shows it, trimmed.
local function Message()
    local word = Word()
    local text = S.committed .. (word and (Lead() .. Cap(word)) or "")
    return text:match("^%s*(.-)%s*$")
end

-- The phrase page: opened by holding A (or a flick with A down) and up until A is held again, so both sticks are
-- free to flick phrases.
local function OpenPhrases()
    if S.aTimer then S.aTimer:Cancel() end
    S.aTimer, S.phrases, S.phraseList, S.phraseKeep = nil, true, PhrasePicks(), false
    Paint()
end

-- A held again on the page: back to letters, what is typed kept.
function Fit.ClosePhrases()
    S.phrases, S.phraseSave, S.phraseNoText, S.phraseKeep = false, false, false, false
    Paint()
end

-- Whether the next phrase flicked goes at once: on an empty line, unless RT came first (phraseKeep) or the setting
-- has phrases always join the line.
function Fit.PhraseSends()
    return not ns.profile.phraseFill and not S.phraseKeep and not (Word() or S.committed:find("%S"))
end

-- draft: an unsent chat message closed with B, back in the box the next time chat opens empty.
local Send, draft

-- Save mode (X on the phrase page): the message replaces the flicked slot's phrase and the box empties.
local function SavePhrase(digit)
    local text = Message()
    ns.SetPhrase(digit, text)
    ns.Say(L["PHRASE_SAVED"]:format(L["PHRASE_SLOT_" .. digit], text))
    S.committed, S.flicks, S.literal, S.undo, S.autoSpace = "", "", nil, nil, false
    S.phraseSave, S.phraseList = false, PhrasePicks()
    Flash(digit)
    Guess()
    Show()
end

-- Phrases join the message as words; one flicked on an empty line goes at once (Fit.PhraseSends).
local function SayPhrase(pick, digit)
    S.phraseNoText = false
    if not pick then return end
    S.phraseUsed = true
    Flash(digit)
    Use("phrase")
    local now = Fit.PhraseSends()
    local word = Word()
    if word then Commit(word, true) end
    -- As written: "ty" stays "ty" at a sentence's start.
    local before = S.committed
    S.committed = before .. Lead() .. pick.label .. " "
    S.undo = { committed = before, flicks = "", shown = 0, after = S.committed }
    S.autoSpace = true
    if now then return Send() end
    Guess()
    Show()
end

local function SwitchTo(pick, digit)
    if not pick then return end
    if pick.move then return ns.StartMove() end
    if pick.naming then
        -- the page's kind of whisper: characters on one, Battle.net friends on the other
        local names = ns.WhisperNames(pick.naming)
        S.naming = { flicks = "", names = names, found = D.MatchNames(names, "") }
        return Paint()
    end
    ns.SwitchChannel(box, pick)
    Use("channel")
    if digit then Flash(digit) end
    Paint()
end

-- Whispering someone new: flicks spell the name, the d-pad holds the people it fits.
local function NameFlick(digit)
    local naming = S.naming
    naming.flicks = naming.flicks .. digit
    naming.found = D.MatchNames(naming.names, naming.flicks)
    Flash(digit)
    Paint()
end

local function TakeName(slot)
    local pick = S.naming.found[slot]
    if not pick then return end
    ns.SwitchChannel(box, pick)
    S.naming = nil
    Paint()
end

-- Exact letters: a flick picks a box, the next flick its letter (four letters sit on either stick's directions,
-- more run on across both).
local function ExactFlick(digit)
    if not S.box then
        S.box = digit
        Flash(digit)
        return Paint()
    end
    local letters = D.Box(S.box)
    local c = letters[#letters <= 4 and (digit - 1) % 4 + 1 or digit]
    if not c then return end
    S.literal, S.box = (S.literal or "") .. c, nil
    Use("exact")
    Flash(digit)
    Guess()
    Show()
end

local function Emit(digit)
    Sync()
    S.forget, S.draftBack = nil, nil
    if ns.practice then ns.practice.Flick() end
    if S.aDown and not S.phrases then
        OpenPhrases()
    elseif S.aDown and S.aTimer then
        -- a phrase flicked with A down on the page: no going back, no send when it is let go
        S.aTimer:Cancel()
        S.aTimer = nil
    end
    if S.phrases then
        if S.phraseSave then return SavePhrase(digit) end
        return SayPhrase(S.phraseList[digit], digit)
    end
    if S.symbols then return TypeSymbol(SYMBOLS[digit]:sub(1, 1)) end
    if S.naming then return NameFlick(digit) end
    if S.exact then return ExactFlick(digit) end
    if S.literal then Commit(S.literal, true) end
    if S.flicks == "" then S.pass = nil end
    S.flicks = S.flicks .. digit
    if S.lesson then
        S.lesson.linked = S.lesson.linked or {}
        S.lesson.linked[#S.flicks] = S.lesson.linkNext == true
        S.lesson.linkNext = nil
    end
    Use("flick")
    Flash(digit)
    Guess()
    Show()
end

-- /flick sticks: every stick reading and button press for a while and what became of them
-- (FlickChatDB.stickProbe), so a missed flick or a cut-short hold can be read back. No letters or text.
local probe
local PROBE_LINES = 6000

function ns.StartStickProbe(seconds)
    local now = GetTime()
    probe = { stop = now + seconds, start = now, lines = {} }
    ns.db.stickProbe = { arm = ns.db.arm, rearm = ns.db.rearm, lesson = S.lesson ~= nil, lines = probe.lines,
        padUI = InputUtil ~= nil and InputUtil.IsGamepadUIEnabled() or false, shift = C_CVar.GetCVar("GamePadEmulateShift"),
        ctrl = C_CVar.GetCVar("GamePadEmulateCtrl"), alt = C_CVar.GetCVar("GamePadEmulateAlt") }
end

local function Note(text)
    local now = GetTime()
    if now > probe.stop or #probe.lines >= PROBE_LINES then
        probe = nil
        return
    end
    probe.lines[#probe.lines + 1] = string.format("%.3f %s", now - probe.start, text)
end

-- After an LT press: what the pad itself reads for 2.5 s (buttons down, axes off rest, the game's Shift).
function ns.LookAtPad()
    if probe.looking then return end
    probe.looking = true
    local function Read(state, Name)
        local out = {}
        for i, on in pairs(state and (state.buttons or state.rawButtons) or {}) do
            -- the list counts from 1, the game's button index from 0
            if on == true then out[#out + 1] = Name and (Name(i - 1) or tostring(i)) or tostring(i) end
        end
        for i, v in pairs(state and (state.axes or state.rawAxes) or {}) do
            if math.abs(v) > 0.05 then out[#out + 1] = ("a%d=%.2f"):format(i, v) end
        end
        return table.concat(out, " ")
    end
    local looks, ticker = 0, nil
    ticker = C_Timer.NewTicker(0.1, function()
        looks = looks + 1
        if not probe or looks > 25 then
            ticker:Cancel()
            if probe then probe.looking = nil end
            return
        end
        local id = C_GamePad.GetActiveDeviceID()
        Note(("pad: LT index %s, device %s; mapped {%s}; raw {%s}; shift %s"):format(
            tostring(C_GamePad.ButtonBindingToIndex("PADLTRIGGER")), tostring(id),
            Read(C_GamePad.GetDeviceMappedState(), C_GamePad.ButtonIndexToBinding),
            Read(id and C_GamePad.GetDeviceRawState(id)), tostring(IsShiftKeyDown())))
    end)
end

local function Dir4(x, y)
    if math.abs(y) >= math.abs(x) then return y > 0 and 1 or 3 end
    return x > 0 and 2 or 4
end

-- On the symbols page a group held with one stick, the other stick picks any of its symbols.
local function Pick(digit, x, y)
    Sync()
    local i = Dir4(x, y)
    local c = SYMBOLS[digit]:sub(i, i)
    if c ~= "" then
        Use("pick")
        TypeSymbol(c)
    end
end

local function Release(st, now)
    local other = st.other
    if st.held then
        st.held = false
        return Paint()
    end
    local dir = st.dir or Dir4(st.px, st.py)
    local bounce = st.lastDir and (dir - st.lastDir) % 4 == 2 and st.at - st.lastAt < SNAPBACK
        and st.peak < BOUNCE_PEAK
    if probe then Note(string.format("release %d peak %.2f %s", st.base + dir, st.peak, bounce and "BOUNCE" or "")) end
    st.lastDir, st.lastAt = dir, now
    if not bounce then
        if S.lesson then table.insert(S.lesson.peaks, st.peak) end
        if S.symbols and other.out and other.at < st.at then
            other.held = true
            Pick(other.base + Dir4(other.px, other.py), st.px, st.py)
        elseif other.out and other.at < st.at and not other.held then
            -- the other stick went out first: its letter goes first
            st.waiting = st.base + dir
            return
        else
            Emit(st.base + dir)
        end
    end
    if other.waiting then
        local digit = other.waiting
        other.waiting = nil
        Emit(digit)
    end
end

-- Move mode (/flick move or the settings row, then the next time the keyboard opens): the left stick carries the
-- keyboard, the right stick sizes it. A keeps it there, B puts it back, Y gives the place and size it came with.
-- For the button guide (its own settings row) the left stick carries the guide, and the size stays.
local Move = { SPEED = 520, SIZE_STEP = 5, SIZE_EVERY = 0.12, DEAD = 0.25 }

function Move.End()
    if S.move then S.move.ticker:Cancel() end
    S.move = nil
    Paint()
end

-- Where the piece being moved goes: the keyboard by its chat line, the guide by its own place.
function Move.Place()
    if S.move.guide then PlaceGuide() else PlaceBy(box) end
end

function Move.Start(guide)
    -- the places and the size are the profile's
    local db = ns.profile
    local keyX, keyY = guide and "guideX" or "moveX", guide and "guideY" or "moveY"
    local move = { guide = guide, keyX = keyX, keyY = keyY, x = db[keyX] or 0, y = db[keyY] or 0, size = db.size,
        lx = 0, ly = 0, ry = 0, last = GetTime(), sized = 0 }
    S.move = move
    move.ticker = C_Timer.NewTicker(0.02, function()
        local now = GetTime()
        local dt = math.min(0.1, now - move.last)
        move.last = now
        if not box or not kb:IsShown() then return Move.End() end
        if move.lx ~= 0 or move.ly ~= 0 then
            local piece = guide and kb.guide or kb
            local wasX, wasY, left, bottom = db[keyX] or 0, db[keyY] or 0, piece:GetLeft(), piece:GetBottom()
            db[keyX], db[keyY] = wasX + move.lx * Move.SPEED * dt, wasY + move.ly * Move.SPEED * dt
            Move.Place()
            -- At the screen's edge the game holds it: a push it did not follow is not kept.
            if move.lx ~= 0 and piece:GetLeft() == left then db[keyX] = wasX end
            if move.ly ~= 0 and piece:GetBottom() == bottom then db[keyY] = wasY end
        end
        if not guide and math.abs(move.ry) > 0.5 and now - move.sized >= Move.SIZE_EVERY then
            move.sized = now
            db.size = math.max(70, math.min(200, db.size + (move.ry > 0 and Move.SIZE_STEP or -Move.SIZE_STEP)))
            ns.Restyle()
            PlaceBy(box)
        end
    end)
    Paint()
end

ns.StartMove = Move.Start

function Move.Stick(which, x, y, len)
    local move = S.move
    if len < Move.DEAD then x, y = 0, 0 end
    if which == "Left" then move.lx, move.ly = x, y else move.ry = y end
end

function Move.Press(button)
    local db, move = ns.profile, S.move
    if button == "PAD1" then
        Move.End()
        ns.Say(L[move.guide and "MOVE_GUIDE_SAVED" or "MOVE_SAVED"])
    elseif button == "PAD2" or button == "PAD4" then
        local back = button == "PAD2"
        db[move.keyX], db[move.keyY] = back and move.x or 0, back and move.y or 0
        if not move.guide then db.size = back and move.size or 100 end
        ns.Restyle()
        Move.Place()
        if back then Move.End() end
    end
end

local function Off(degrees, dir) return math.abs((degrees - DIR_DEGREES[dir] + 180) % 360 - 180) end

-- On the rim: which direction the stick holds, and a roll into the next one counted as a flick of its own.
local function Roll(st, x, y, len)
    local degrees, dir = math.deg(math.atan2(y, x)), Dir4(x, y)
    if not st.dir or (dir ~= st.dir and not st.settled) then
        st.dir, st.settled = dir, Off(degrees, dir) <= SETTLED
    elseif dir == st.dir then
        st.settled = st.settled or Off(degrees, dir) <= SETTLED
    elseif Off(degrees, st.dir) >= TURN then
        local now = GetTime()
        if probe then Note(string.format("roll %d -> %d", st.base + st.dir, st.base + dir)) end
        if S.lesson then S.lesson.rolls = (S.lesson.rolls or 0) + 1 end
        -- The box being left was only passed through when it was rolled into, left again within a moment, and
        -- lies between two opposite boxes: a swing across that bowed out along the rim looks just like that
        -- (measured: the stick stays at the rim either way), so the word finder is told and decides.
        local passed = st.rolledIn and st.cameFrom and (st.cameFrom - dir) % 4 == 2 and now - st.at < 0.12
        local was, flicks = st.dir, #S.flicks
        Release(st, now)
        if passed and #S.flicks == flicks + 1 and flicks > 0 then
            S.pass = #S.flicks
            Guess()
            Show()
        end
        st.cameFrom, st.rolledIn = was, true
        if S.lesson then S.lesson.linkNext = true end
        st.at, st.px, st.py, st.peak, st.held = now, x, y, len, false
        st.dir, st.settled = dir, Off(degrees, dir) <= SETTLED
    end
end

-- The chained flicks drill, judged as a stick comes back to rest: the stage's letters and no others, all but the
-- first of them rolled to. Done, the next stage starts from an empty word (the last keeps its letters); missed,
-- the same stage again.
function LESSON.Drill(late)
    local lesson = S.lesson
    if lesson.wait then
        lesson.wait:Cancel()
        lesson.wait = nil
    end
    if S.flicks == "" then return end
    local stage = lesson.stage or 1
    local want = D.KeyOf(LESSON[LESSON.roll]):sub(1, LESSON.stages[stage])
    -- A swing straight across passes through rest: with the box across still to come, a moment's wait for it.
    local last, coming = tonumber(S.flicks:sub(-1)), tonumber(want:sub(#S.flicks + 1, #S.flicks + 1))
    if not late and coming and want:sub(1, #S.flicks) == S.flicks and (last - coming) % 4 == 2 then
        lesson.wait = C_Timer.NewTimer(0.4, function()
            lesson.wait = nil
            if S.lesson == lesson and lesson.at == LESSON.roll and not lesson.chained then LESSON.Drill(true) end
        end)
        return
    end
    -- A swing straight across that bowed out through a box on the way picked that box up too: one flick too
    -- many, between two opposite boxes. Forgiven here: the move was the right one.
    if #S.flicks == #want + 1 then
        for k = 2, #want do
            local across = (tonumber(want:sub(k, k)) - tonumber(want:sub(k - 1, k - 1))) % 4 == 2
            if across and S.flicks:sub(1, k - 1) .. S.flicks:sub(k + 1) == want then S.flicks = want end
        end
    end
    -- Rolled: every step to the box next door (a swing across is no roll).
    local rolls = 0
    for i = 2, #want do
        if (tonumber(want:sub(i, i)) - tonumber(want:sub(i - 1, i - 1))) % 2 == 1 then rolls = rolls + 1 end
    end
    local good = S.flicks == want and (lesson.rolls or 0) >= rolls
    if good then
        lesson.stage, lesson.missed, lesson.praise = stage + 1, false, true
        lesson.chained = stage == #LESSON.stages
        if not lesson.chained then S.flicks = "" end
    else
        lesson.missed, lesson.praise = true, false
        S.flicks = ""
    end
    lesson.rolls, S.literal = 0, nil
    Guess()
    Show()
end

-- A chain the lesson asked for, judged as a stick comes back to rest: all of its letters, each after the first
-- joined to the one before. Not so, its flicks come back out and it is asked again. A word that reached the
-- d-pad meanwhile is the d-pad's to take: no judging then.
function LESSON.Run(late)
    local lesson = S.lesson
    local asked, target = lesson.asked, LESSON[lesson.at]
    if lesson.wait then
        lesson.wait:Cancel()
        lesson.wait = nil
    end
    local key, m = target and D.KeyOf(target), #S.flicks
    if not key or m < asked.a - 1 then
        lesson.asked = nil
        return
    end
    if key:sub(1, m) ~= S.flicks or m < asked.a then return end
    for slot = 1, #SLOT_KEYS do
        if ns.Lower(S.slots[slot] or "") == target then
            lesson.asked, lesson.missed = nil, false
            return
        end
    end
    -- A swing straight across passes through rest: a moment's wait for it.
    local last, coming = tonumber(key:sub(m, m)), tonumber(key:sub(m + 1, m + 1))
    if not late and m < asked.b and (last - coming) % 4 == 2 then
        lesson.wait = C_Timer.NewTimer(0.4, function()
            lesson.wait = nil
            if S.lesson == lesson and lesson.asked == asked then LESSON.Run(true) end
        end)
        return
    end
    local good = m >= asked.b
    for k = asked.a + 1, math.min(m, asked.b) do good = good and lesson.linked[k] end
    lesson.asked, lesson.missed = nil, not good
    if not good then
        S.flicks, S.literal = key:sub(1, asked.a - 1), nil
        Guess()
        Show()
    end
end

local function OnStick(_, which, x, y, len)
    local st = sticks[which]
    if not st or not box then return end
    st.len = len
    if S.joinWait then return end
    if kb.viewHold then
        if which == "Right" then kb.viewHold.y = y end
        return
    end
    if S.move then return Move.Stick(which, x, y, len) end
    if S.wheel then return WheelStick(which, x, y) end
    if st.rest then
        if len > ns.db.rearm then return end
        st.rest = nil
    end
    st.x, st.y = x, y
    if probe then Note(string.format("%s %.2f %.2f %.2f", which, x, y, len)) end
    local arm = S.lesson and LESSON_ARM or ns.db.arm
    local rolling = len >= RIM and not S.symbols and not S.phrases
    if not st.out then
        if len >= arm then
            -- out again right after letting go: a swing straight across, one move with the flick before
            if S.lesson and st.lastAt and GetTime() - st.lastAt < 0.4 then S.lesson.linkNext = true end
            st.out, st.at, st.px, st.py, st.peak, st.held = true, GetTime(), x, y, len, false
            st.cameFrom, st.rolledIn = nil, false
            st.dir, st.settled = nil, false
            -- A fast flick can reach the rim on its first reading: that is its direction.
            if rolling then Roll(st, x, y, len) end
            -- The box the stick points at lights as the stick gets there, not when its flick is counted.
            Paint()
        end
    elseif len <= ns.db.rearm then
        st.out = false
        Release(st, GetTime())
        if S.lesson and S.lesson.at == LESSON.roll and not S.lesson.chained then
            LESSON.Drill()
        elseif S.lesson and S.lesson.asked then
            LESSON.Run()
        end
        Paint()
    else
        local was = st.dir or Dir4(st.px, st.py)
        if len > st.peak then st.px, st.py, st.peak = x, y, len end
        -- The symbols page holds a group on one stick and the phrases take one flick: no rolls there.
        if rolling and not st.held then Roll(st, x, y, len) end
        if (st.dir or Dir4(st.px, st.py)) ~= was then Paint() end
    end
    local dot = kb.roses[st.base == 0 and 1 or 2].dot
    dot:SetPoint("CENTER", dot:GetParent(), "CENTER", x * HUB_R, y * HUB_R)
end

local function Accept()
    if S.naming then return TakeName(1) end
    S.symbols = false
    local word = Word()
    if word then
        Commit(word, true)
        Use("take")
    elseif S.autoSpace and S.committed:find("[%w\128-\255'] $") then
        -- a second space in a row ends the sentence
        S.committed, S.autoSpace = (S.committed:gsub(" $", ". ")), false
    else
        S.committed, S.autoSpace = S.committed .. " ", false
        Use("space")
    end
    Guess()
    Show()
end

local function DeleteLast(text)
    local link = text:match(".*()|c%x%x%x%x%x%x%x%x|H")
    if link and text:sub(link):match("^|c%x+|H.-|h.-|h|r$") then return text:sub(1, link - 1) end
    return (text:gsub(UTF8_LAST, ""))
end

local function Undo()
    if S.naming then
        S.naming.flicks = S.naming.flicks:sub(1, -2)
        S.naming.found = D.MatchNames(S.naming.names, S.naming.flicks)
        return Paint()
    end
    if S.box then
        S.box = nil
        return Paint()
    end
    if S.literal then
        S.literal = S.literal:gsub(UTF8_LAST, "")
        if S.literal == "" then S.literal = nil end
        Use("undo")
    elseif S.flicks ~= "" then
        S.flicks = S.flicks:sub(1, -2)
        Use("undo")
    elseif S.undo and S.undo.after == S.committed then
        local u = S.undo
        S.committed, S.flicks, S.literal, S.undo, S.autoSpace = u.committed, u.flicks, u.literal, nil, false
        Guess()
        if u.flicks ~= "" then S.shown = math.max(1, math.min(u.shown, #S.stems)) end
        return Show()
    else
        S.committed = DeleteLast(S.committed)
        Use("delete")
    end
    S.autoSpace = false
    Guess()
    Show()
end

local function DeleteWord()
    if probe then Note(string.format("delete word (box %s, naming %s)", tostring(box ~= nil), tostring(S.naming ~= nil))) end
    if not box or S.naming then return end
    Sync()
    if Word() then
        S.flicks, S.literal = "", nil
    else
        local text = S.committed:gsub("%s+$", "")
        if text:find("|h|r$") then
            S.committed = DeleteLast(text)
        else
            S.committed = text:gsub("[^%s]*$", "")
        end
    end
    S.undo, S.autoSpace = nil, false
    Guess()
    Show()
end

local function StopHold()
    if S.holdTimer then S.holdTimer:Cancel() end
    if S.holdTicker then S.holdTicker:Cancel() end
    S.holdTimer, S.holdTicker = nil, nil
end

local function StartHold()
    StopHold()
    S.holdTimer = C_Timer.NewTimer(HOLD_DELAY, function()
        S.holdTimer = nil
        if probe then Note("hold fired") end
        DeleteWord()
        S.holdTicker = C_Timer.NewTicker(HOLD_REPEAT, DeleteWord)
    end)
end

local function NextGuess()
    if S.flicks == "" or #S.stems < 2 then return end
    S.shown = S.shown % #S.stems + 1
    Use("next")
    Show()
end

local function StopSlotHold()
    if S.slotTimer then S.slotTimer:Cancel() end
    S.slotTimer = nil
end

-- A d-pad word held on: it comes back out of the message and the player is asked whether to forget it.
local function HoldToForget(word)
    StopSlotHold()
    S.slotTimer = C_Timer.NewTimer(HOLD_DELAY, function()
        S.slotTimer = nil
        local u = S.undo
        if not box or not u or u.after ~= S.committed then return end
        S.committed, S.flicks, S.literal, S.undo, S.autoSpace = u.committed, u.flicks, u.literal, nil, false
        Guess()
        if u.flicks ~= "" then S.shown = math.max(1, math.min(u.shown, #S.stems)) end
        S.forget = word
        Show()
    end)
end

local function TakeSlot(slot)
    if S.naming then return TakeName(slot) end
    local word = S.slots[slot]
    if not word then return end
    if S.lesson then S.lesson.dpadTold = true end
    Commit(word, true)
    Use("slot")
    Guess()
    Show()
    if not S.lesson then HoldToForget(word) end
end

local function Capital()
    local now = GetTime()
    if S.capsLock then
        S.capsLock, S.caps = false, false
    elseif S.caps and now - (S.lastCap or 0) < DOUBLE_TAP then
        S.capsLock, S.caps = true, false
    else
        S.caps = not S.caps
    end
    S.lastCap = now
    Show()
end

local function Reset(text)
    S.committed, S.written, S.flicks, S.literal = text, text, "", nil
    S.guesses, S.stems, S.shown, S.slots, S.undo = {}, {}, 0, {}, nil
    S.autoSpace, S.caps, S.capsLock, S.symbols, S.wheel = false, false, false, false, nil
    S.exact, S.box, S.naming, S.phrases, S.aDown = false, nil, nil, false, false
    S.phraseSave, S.phraseNoText, S.phraseKeep, S.forget = false, false, false, nil
    if S.move then
        S.move.ticker:Cancel()
        S.move = nil
    end
    StopSlotHold()
    for _, st in pairs(sticks) do st.out, st.held, st.waiting, st.lastDir = false, false, nil, nil end
end

Send = function()
    if ns.practice then return ns.practice.Again() end
    if S.lesson then
        local last = S.lesson.at == #LESSON and ns.Lower(Word() or "") == LESSON[#LESSON]
        if last or S.lesson.at > #LESSON then
            FinishLesson()
            Reset("")
            box:SetText("")
            ns.Say(L["LESSON_DONE"])
            Guess()
        end
        return Show()
    end
    local word = Word()
    if word then Commit(word, false) end
    local text = S.committed:gsub("%s+$", "")
    draft = nil
    if ns.dev and ns.dev.Send and ns.dev.Send(text) then
        box:SetText("")
        Reset("")
        Guess()
        return Show()
    end
    box:SetText(text)
    S.written = text
    if text:find("%S") then ns.Learn(text) end
    if S.lesson then FinishLesson() end
    Use("send")
    -- Another window's box (mail, a search): the text stays in it and the box lets go, so the game's own cursor
    -- is where it was and moves on from there. Its Enter is never pressed: that steps the typing to the next box
    -- and leaves the cursor behind, and a many-line box has none.
    if not box.chatFrame and not box.flickOwn then
        box:ClearFocus()
        return ns.Shut()
    end
    local enter = box:GetScript("OnEnterPressed")
    if enter then enter(box) end
    if box then
        Reset(box:GetText())
        Guess()
        Show()
    end
end

local function ClearAll()
    if S.naming then
        S.naming = nil
        return Paint()
    end
    S.committed, S.flicks, S.literal, S.undo, S.autoSpace = "", "", nil, nil, false
    Use("clear")
    Guess()
    Show()
end

local function Close()
    if S.naming then
        S.naming = nil
        return Paint()
    end
    -- Another window's box: B puts back what it held and lets go. Its Escape is never pressed (a dialog's shuts
    -- the dialog, a many-line box has none).
    if not box.chatFrame and not box.flickOwn and not ns.practice then
        box:SetText(S.openedText or "")
        box:ClearFocus()
        return ns.Shut()
    end
    -- B leaves chat and keeps the message for the next time it opens; View is what empties a line.
    if ns.practice then
        ns.practice.Stop()
    elseif box.chatFrame and not S.lesson and S.written:find("%S") then
        draft = S.written
    end
    -- In a fight the game refuses a chat box's focus dropped by addon code (its controller state stays on chat):
    -- the keyboard steps back and the pad is the game's again, whose own Back shuts chat.
    if box.chatFrame and InCombatLockdown() then return ns.Shut() end
    local edit = box
    local escape = edit:GetScript("OnEscapePressed")
    if not escape then return end
    escape(edit)
    -- The game's Escape only empties a line with text on it: once more, so B leaves chat in one press.
    if GetCurrentKeyBoardFocus() == edit then escape(edit) end
end

-- The channel wheel: Y opens it over the keyboard and it works as the game's own Menu wheel does: point either stick
-- at a slice, let the stick go to pick it, LB and RB turn the page, Y or B closes it. The game's wheel art.
local WHEEL_SCALE, SLICE_OUT = 0.7, 150
-- Past this (squared) a stick points at a slice; back under this it picks it (the game's own wheel's numbers).
local POINT_SQ, LETGO_SQ = 0.25, 0.04
local OFF_COLOR, PICK_COLOR = { 0.45, 0.45, 0.45 }, { 1, 1, 1 }
local wheel

-- Slice i's direction: 1 at the top, then clockwise.
local function SliceAngle(i) return math.rad(90 - (i - 1) * 45) end

local function WheelArt(texture, atlas, size, color)
    if C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas, true)
    else
        texture:SetTexture(DISC)
        texture:SetSize(size, size)
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

local function BuildWheel()
    wheel = CreateFrame("Frame", nil, kb)
    -- Never past the screen's edge: a keyboard low on the screen pushes the wheel up.
    wheel:SetClampedToScreen(true)
    wheel:SetFrameLevel(kb:GetFrameLevel() + 20)

    wheel:SetSize(560, 640)
    wheel:SetPoint("CENTER", kb, "CENTER")
    wheel.shade = wheel:CreateTexture(nil, "BACKGROUND", nil, -2)
    wheel.shade:SetAllPoints(kb)
    wheel.shade:SetColorTexture(0, 0, 0, 0.7)
    -- The wheel art is see-through between its slices: a dark disc behind it keeps what is under it out.
    wheel.back = wheel:CreateTexture(nil, "BACKGROUND", nil, -1)
    wheel.back:SetTexture(DISC)
    wheel.back:SetVertexColor(0.02, 0.02, 0.03, 0.88)
    wheel.bg = wheel:CreateTexture(nil, "BACKGROUND")
    WheelArt(wheel.bg, "gamepad-radial-menu-wheelbg", 520, { 0.08, 0.08, 0.09, 0.95 })
    wheel.bg:SetPoint("CENTER", 0, 20)
    wheel.back:SetPoint("CENTER", wheel.bg, "CENTER")
    wheel.back:SetSize(500, 500)
    wheel.lit = wheel:CreateTexture(nil, "ARTWORK")
    WheelArt(wheel.lit, "gamepad-radial-menu-selected", 160, { YELLOW[1], YELLOW[2], YELLOW[3], 0.35 })
    wheel.slices = {}
    for i = 1, 8 do
        local angle = SliceAngle(i)
        local x, y = math.cos(angle) * SLICE_OUT, math.sin(angle) * SLICE_OUT
        local off = wheel:CreateTexture(nil, "BORDER")
        WheelArt(off, "gamepad-radial-menu-disabled", 160, { 0, 0, 0, 0.5 })
        off:SetPoint("CENTER", wheel.bg, "CENTER", x, y)
        off:SetRotation(angle - math.rad(270))
        local label = wheel:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
        label:SetSize(130, 48)
        label:SetWordWrap(true)
        label:SetPoint("CENTER", wheel.bg, "CENTER", x, y)
        wheel.slices[i] = { off = off, label = label, x = x, y = y, angle = angle }
    end
    wheel.title = wheel:CreateFontString(nil, "OVERLAY")
    wheel.title:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
    wheel.title:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
    wheel.title:SetPoint("CENTER", wheel.bg, "CENTER", 0, 12)
    wheel.page = wheel:CreateFontString(nil, "OVERLAY")
    wheel.page:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
    wheel.page:SetPoint("TOP", wheel.title, "BOTTOM", 0, -8)
    wheel.info = wheel:CreateFontString(nil, "OVERLAY")
    wheel.info:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
    wheel.info:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
    wheel.info:SetPoint("TOPLEFT", wheel.bg, "BOTTOMLEFT", 0, -6)
    wheel.info:SetPoint("TOPRIGHT", wheel.bg, "BOTTOMRIGHT", 0, -6)
    wheel.info:SetWordWrap(true)
    -- A join or a leave asks on the wheel itself, over its middle: the question, then A and B.
    wheel.ask = wheel:CreateFontString(nil, "OVERLAY")
    wheel.ask:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
    wheel.ask:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
    wheel.ask:SetPoint("LEFT", wheel.bg, "LEFT", 70, 34)
    wheel.ask:SetPoint("RIGHT", wheel.bg, "RIGHT", -70, 34)
    wheel.ask:SetWordWrap(true)
    wheel.answer = wheel:CreateFontString(nil, "OVERLAY")
    wheel.answer:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
    wheel.answer:SetPoint("TOP", wheel.ask, "BOTTOM", 0, -16)
    wheel:Hide()
end

local function PaintWheel()
    local w = S.wheel
    local picks = w.pages[w.page].picks
    -- asking: the slice asked about stays lit, the other labels give the question room
    local ask = w.confirm
    for i, slice in ipairs(wheel.slices) do
        local pick = picks[i]
        slice.label:SetText(pick and pick.label or "")
        slice.label:SetShown(not ask)
        local color = (not pick or pick.off) and OFF_COLOR or ns.IsChannel(box, pick) and YELLOW or PICK_COLOR
        slice.label:SetTextColor(color[1], color[2], color[3])
        slice.off:SetShown(pick ~= nil and pick.off == true)
    end
    local at = ask and ask.at or w.at
    local lit = at > 0 and picks[at]
    if at > 0 then
        local slice = wheel.slices[at]
        wheel.lit:ClearAllPoints()
        wheel.lit:SetPoint("CENTER", wheel.bg, "CENTER", slice.x, slice.y)
        wheel.lit:SetRotation(slice.angle - math.rad(270))
        wheel.lit:SetDesaturated(not lit or lit.off == true)
    end
    wheel.lit:SetShown(at > 0)
    wheel.title:SetShown(not ask)
    wheel.page:SetShown(not ask)
    wheel.ask:SetShown(ask ~= nil)
    wheel.answer:SetShown(ask ~= nil)
    if ask then
        wheel.ask:SetText(L[ask.leave and "LEAVE_ASK" or "JOIN_ASK"]:format(ask.name))
        wheel.answer:SetText(L[ask.leave and "LEAVE_ANSWER" or "JOIN_ANSWER"]:format(Glyph("PAD1"), Glyph("PAD2")))
        return wheel.info:SetText(L["ASK_ELSE"])
    end
    wheel.title:SetText(w.pages[w.page].title)
    wheel.page:SetText(("%s  %d / %d  %s"):format(Glyph("PADLSHOULDER"), w.page, #w.pages, Glyph("PADRSHOULDER")))
    if lit then
        local key = lit.off and "WHEEL_OFF" or lit.join and "WHEEL_JOIN" or lit.channelName and "WHEEL_CHANNEL"
            or "WHEEL_LETGO"
        wheel.info:SetText(L[key]:format(lit.join or lit.label, Glyph(lit.channelName and "PAD3" or "PAD1")))
    else
        wheel.info:SetText(L["HINT_WHEEL"]:format(Glyph("PAD4"), Glyph("PAD2")))
    end
end

local function OpenWheel()
    -- Channels are a chat box's: none while a settings box is typed in.
    if not box.chatFrame then return end
    if not wheel then BuildWheel() end
    local pages, page = ns.WheelPages(), 1
    for p, each in ipairs(pages) do
        for _, pick in ipairs(each.picks) do
            if not pick.naming and ns.IsChannel(box, pick) then page = p end
        end
    end
    S.wheel = { pages = pages, page = page, at = 0 }
    wheel:SetScale(WHEEL_SCALE * (ns.profile.wheelSize or 100) / 100)
    for _, st in pairs(sticks) do st.out, st.held, st.waiting = false, false, nil end
    if SOUNDKIT and SOUNDKIT.GAMEPAD_RADIAL_MENU_OPEN then PlaySound(SOUNDKIT.GAMEPAD_RADIAL_MENU_OPEN) end
    wheel:Show()
    PaintWheel()
    Paint()
end

local function CloseWheel()
    S.wheel = nil
    if wheel then wheel:Hide() end
    -- a stick still out as the wheel goes types nothing until it is back at rest
    for _, st in pairs(sticks) do st.rest = (st.len or 0) > ns.db.rearm end
    if box or S.preview then Paint() end
end

-- A join asks on the wheel: A runs the game's own /join (ns.ArmJoin), and the pad's buttons are the game's until
-- then. The line types there once the game has numbered the channel.
local function AskJoin(w, pick, at)
    local joiner, name = box, pick.join
    local function Back(joined)
        S.joinWait, w.confirm = nil, nil
        if kb:IsShown() and not kb.viewHold then kb:EnableGamePadButton(true) end
        if joined then
            CloseWheel()
        elseif S.wheel == w then
            PaintWheel()
        end
    end
    local armed = ns.ArmJoin(name, function()
        Back(true)
        ns.AwaitChannel(name, function(id)
            if not id then return ns.Say(L["JOIN_FAILED"]:format(name)) end
            if box ~= joiner then return end
            ns.SwitchChannel(box, { chatType = "CHANNEL", channelTarget = id })
            Use("channel")
            Paint()
        end)
    end, function() Back(false) end)
    if armed then
        S.joinWait, w.confirm = name, { name = name, at = at }
        kb:EnableGamePadButton(false)
    end
    PaintWheel()
end

WheelStick = function(which, x, y)
    local w = S.wheel
    if w.confirm then return end
    local sq = x * x + y * y
    if sq > POINT_SQ then
        local degrees = math.deg(math.atan2(y, x))
        local i = math.floor(((90 - degrees) % 360 + 22.5) / 45) % 8 + 1
        w.stick = which
        if w.at ~= i then
            w.at = i
            if SOUNDKIT and SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT then PlaySound(SOUNDKIT.GAMEPAD_RADIAL_MENU_HIGHLIGHT) end
            PaintWheel()
        end
    elseif sq < LETGO_SQ and w.stick == which and w.at > 0 then
        local at = w.at
        local pick = w.pages[w.page].picks[at]
        w.at, w.stick = 0, nil
        if pick and not pick.off then
            if pick.join then return AskJoin(w, pick, at) end
            CloseWheel()
            if pick.settings then
                -- Chat shuts first; the window comes once the typing line has let go.
                Close()
                return C_Timer.After(0.1, function()
                    if not (kb and kb:IsShown()) then ns.OpenOptions() end
                end)
            end
            return SwitchTo(pick)
        end
        PaintWheel()
    end
end

local function WheelPress(button)
    local w = S.wheel
    local ask = w.confirm
    if ask then
        -- a leave asked on the wheel (a join's buttons are the game's): A leaves, any other button goes back
        w.confirm = nil
        if button ~= "PAD1" then return PaintWheel() end
        local typedThere = ns.IsChannel(box, { chatType = "CHANNEL", channelTarget = ask.number })
        LeaveChannelByName(ask.name)
        if typedThere then ns.SwitchChannel(box, { chatType = "SAY" }) end
        return CloseWheel()
    end
    local pointed = w.at > 0 and w.pages[w.page].picks[w.at]
    if button == "PAD3" and pointed and pointed.channelName then
        w.confirm = { leave = true, name = pointed.channelName, number = pointed.channelTarget, at = w.at }
        w.at, w.stick = 0, nil
        return PaintWheel()
    end
    if button == "PADLSHOULDER" or button == "PADRSHOULDER" then
        w.page = (w.page + (button == "PADRSHOULDER" and 1 or -1) - 1) % #w.pages + 1
        w.at, w.stick = 0, nil
        PaintWheel()
    elseif button == "PAD4" or button == "PAD2" then
        CloseWheel()
    end
end

-- The chat tabs either side of the shown one, as the bumpers' clicks while View is held (none past either end).
function Fit.TabTargets()
    local tabs, dock = Fit.tabKeys, GENERAL_CHAT_DOCK
    if not tabs or InCombatLockdown() or not dock or dock:IsForbidden() or not FCFDock_GetSelectedWindow then return end
    local docked, shown, before, after = dock.DOCKED_CHAT_FRAMES or {}, FCFDock_GetSelectedWindow(dock), nil, nil
    for i, frame in ipairs(docked) do
        if frame == shown then before, after = docked[i - 1], docked[i + 1] end
    end
    tabs.Prev:SetAttribute("clickbutton", before and _G[before:GetName() .. "Tab"] or nil)
    tabs.Next:SetAttribute("clickbutton", after and _G[after:GetName() .. "Tab"] or nil)
end

-- A tab clicked while View is held, outside the game's controller interface: the game hides the tab left, and its
-- typing line with it, which shuts chat (2026-11-21: "hides the chat controls"). Inside that interface it gives the
-- new tab the pad's focus and its line opens; here the new tab's line is opened as a click on it opens it, so the
-- keyboard is back at once and typing goes on there.
function Fit.TabFollow()
    local hold, dock = kb and kb.viewHold, GENERAL_CHAT_DOCK
    if not (hold and hold.tabs) or not dock or dock:IsForbidden() or not FCFDock_GetSelectedWindow then return end
    local shown = FCFDock_GetSelectedWindow(dock)
    local edit = shown and shown.editBox
    if edit and not edit:IsForbidden() and not edit:HasFocus() then edit:SetFocus() end
end

-- View held outside the game's controller interface: LB and RB flip the chat tabs. The game's own bumpers on its
-- tabs are there only inside that interface, and a tab selected by our code is refused, so two secure buttons click
-- the tab before and after the shown one, bound to the bumpers while View is held (priority bindings, over another
-- addon's plain ones) and out of a fight. A fight clears them from secure code, by the owner's state driver.
function Fit.TabKeys(on)
    if InCombatLockdown() or not GENERAL_CHAT_DOCK then return end
    local tabs = Fit.tabKeys
    if not tabs then
        local owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        owner:SetAttribute("_onstate-fight", [[ if newstate == "on" then self:ClearBindings() end ]])
        if RegisterStateDriver then RegisterStateDriver(owner, "fight", "[combat] on; off") end
        tabs = { owner = owner }
        for _, way in ipairs({ "Prev", "Next" }) do
            local button = CreateFrame("Button", "FlickChatTab" .. way, UIParent, "SecureActionButtonTemplate")
            button:SetSize(1, 1)
            button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
            button:EnableMouse(false)
            button:SetAttribute("type", "click")
            -- one click a press, on the press: View let go before the bumper is would leave a release unheard
            button:SetAttribute("useOnKeyDown", true)
            button:RegisterForClicks("AnyDown", "AnyUp")
            -- the tab shown has changed: its line opens, and the next press's targets follow it
            button:SetScript("PostClick", function()
                Fit.TabFollow()
                Fit.TabTargets()
            end)
            tabs[way] = button
        end
        Fit.tabKeys = tabs
    end
    ClearOverrideBindings(tabs.owner)
    if not on then return end
    Fit.TabTargets()
    SetOverrideBindingClick(tabs.owner, true, "PADLSHOULDER", "FlickChatTabPrev", "LeftButton")
    SetOverrideBindingClick(tabs.owner, true, "PADRSHOULDER", "FlickChatTabNext", "LeftButton")
end

-- View held: the pad's buttons go to the game until it is let go, so LB and RB flip the chat tabs by the game's own
-- keys (a tab shown by our code is refused), and the right stick scrolls the chat (Fit.ScrollChat). No bumper or
-- scroll while it was down: it was a tap, which clears the line.
local function HoldView()
    if kb.viewHold then return end
    local hold = { bumper = false, y = 0, carry = 0 }
    kb.viewHold = hold
    kb:EnableGamePadButton(false)
    hold.tabs = box and box.chatFrame and not (InputUtil and InputUtil.IsGamepadUIEnabled()) or nil
    if hold.tabs then Fit.TabKeys(true) end
    local function Index(binding) return C_GamePad.ButtonBindingToIndex(binding) or -1 end
    local view, left, right = Index("PADBACK"), Index("PADLSHOULDER"), Index("PADRSHOULDER")
    local base
    hold.ticker = C_Timer.NewTicker(0.03, function()
        local state = C_GamePad.GetDeviceMappedState()
        local buttons = state and state.buttons
        -- the buttons list starts at 0 or 1: whichever shows View down on the first look
        if buttons and base == nil then base = buttons[view] and 0 or buttons[view + 1] and 1 or nil end
        if buttons and base and buttons[view + base] then
            hold.bumper = hold.bumper or buttons[left + base] or buttons[right + base] or false
            return Fit.ScrollChat(hold)
        end
        hold.ticker:Cancel()
        kb.viewHold = nil
        if hold.tabs then Fit.TabKeys(false) end
        -- a stick still out as View goes types nothing until it is back at rest
        for _, st in pairs(sticks) do st.rest = (st.len or 0) > ns.db.rearm end
        if kb:IsShown() then
            kb:EnableGamePadButton(true)
            if not hold.bumper and box then ClearAll() end
        end
    end)
end

local function Press(button)
    if not box then return end
    Sync()
    S.draftBack = nil
    if S.move then return Move.Press(button) end
    if S.wheel then return WheelPress(button) end
    if S.forget then
        -- A forgets the word; any other button keeps it and does nothing else.
        local word = S.forget
        S.forget = nil
        if button == "PAD1" then
            ns.Forget(word)
            D.Refresh(S.names)
            Guess()
            ns.Say(L["FORGOT"]:format(ns.Lower(word)))
        end
        return Show()
    end
    if (button == "PADLTRIGGER" or button == "PADRTRIGGER") and Fit.Trigger(button) then return end
    if button == "PADRTRIGGER" and S.phrases and Fit.PhraseSends() then
        -- The next phrases join the line, to go with A, instead of each going at once.
        S.phraseKeep = true
        Paint()
    elseif button == "PADRTRIGGER" then
        Accept()
    elseif button == "PADLTRIGGER" and S.phraseSave then
        S.phraseSave = false
        Paint()
    elseif button == "PADLTRIGGER" and S.ltModifier then
        -- the game's tap on letting go; right after a hold off the pad (Fit.WatchLT) it is not one more erase
        if GetTime() >= (S.ltQuiet or 0) then Undo() end
    elseif button == "PADLTRIGGER" then
        Undo()
        StartHold()
    elseif button == "PADRSHOULDER" then
        NextGuess()
    elseif button == "PADLSHOULDER" then
        S.exact, S.box = not S.exact, nil
        if S.exact and S.flicks ~= "" then S.literal, S.flicks = Word(), "" end
        Use("exact")
        Guess()
        Show()
    elseif SLOT_OF[button] then
        TakeSlot(SLOT_OF[button])
    elseif button == "PADRSTICK" then
        ns.profile.guideOff = not ns.profile.guideOff or nil
        Paint()
    elseif button == "PADLSTICK" then
        Capital()
    elseif button == "PAD3" and (S.aDown or S.phrases) then
        -- X on the phrase page (or with A held): the next flick saves the message as that slot's phrase.
        if not S.phrases then OpenPhrases() end
        local typed = Message() ~= ""
        S.phraseSave, S.phraseNoText = typed, not typed
        Paint()
    elseif button == "PAD3" then
        S.symbols = not S.symbols
        Use(S.symbols and "symbols" or "letters")
        Paint()
    elseif button == "PAD4" and S.lesson then
        FinishLesson()
        Paint()
    elseif button == "PAD4" then
        OpenWheel()
    elseif button == "PAD1" then
        -- Tap: send. Held: the phrase page, or from it back to letters. A flick with A down opens it too.
        S.aDown, S.phraseUsed = true, false
        local onPage = S.phrases
        if S.aTimer then S.aTimer:Cancel() end
        S.aTimer = C_Timer.NewTimer(HOLD_DELAY, function()
            S.aTimer = nil
            if not (S.aDown and box) then return end
            if onPage then Fit.ClosePhrases() else OpenPhrases() end
        end)
    elseif button == "PADBACK" then
        HoldView()
    elseif button == "PAD2" then
        if ns.dev and ns.dev.Stopped then ns.dev.Stopped() end
        Close()
    end
end

local function Unpress(button)
    if (button == "PADLTRIGGER" or button == "PADRTRIGGER") and not Fit.trig[button].modifier then
        Fit.TriggerUp(button)
    end
    if SLOT_OF[button] then
        StopSlotHold()
    elseif button == "PADLTRIGGER" then
        StopHold()
    elseif button == "PAD1" and S.aDown then
        local tapped = S.aTimer ~= nil
        if S.aTimer then S.aTimer:Cancel() end
        S.aDown, S.aTimer = false, nil
        -- A tap sends, on the phrase page as on letters; the page stays up until A is held again.
        if tapped and box then return Send() end
        if box or S.preview then Paint() end
    end
end

-- Paint: the roses' groups (or a held group's letters round the other stick), the guess slots and the hint.


local function GroupText(text)
    if S.capsLock or S.caps then return ns.Upper(text) end
    return text
end

local function Holding(st) return S.symbols and st.out end

local function PaintRose(rose, st)
    local groups = Groups()
    local holder = st.other
    local picking = Holding(holder) and groups[holder.base + Dir4(holder.px, holder.py)]
    local latched = S.exact and S.box and D.Box(S.box)
    local now, lit = GetTime(), S.lesson and S.lesson.next
    local ring = S.phrases and S.phraseList or nil
    for dir, cell in ipairs(rose.cells) do
        local digit = st.base + dir
        local pick = ring and ring[digit]
        if rose.wheel ~= (ring ~= nil) then
            cell.text:SetFont(TEXT.font, ring and TEXT.channel or TEXT.letter, "OUTLINE")
        end
        if ring then
            cell.text:SetText(pick and pick.label or "")
        elseif latched then
            cell.text:SetText(GroupText(latched[#latched <= 4 and dir or digit] or ""))
        else
            cell.text:SetText(picking and "" or GroupText(groups[digit]))
        end
        -- A box held on the other stick: its symbols stand in this stick's boxes, marked as the ones to pick from.
        local choice = not ring and not latched and picking and #picking <= 4 and picking:sub(dir, dir) or ""
        if choice ~= "" then cell.text:SetText(GroupText(choice)) end
        local pointed = st.out and not S.symbols and (st.dir or Dir4(st.px, st.py)) == dir
        local gold = (cell.flashUntil or 0) > now or digit == lit or pointed
        cell.lit:SetShown(gold)
        cell.focus:SetShown(choice ~= "" or not gold and Holding(st) and Dir4(st.px, st.py) == dir)
        local color = gold and YELLOW or choice ~= "" and BLUE or LETTER_COLOR
        cell.text:SetTextColor(color[1], color[2], color[3])
    end
    rose.wheel = ring ~= nil
    for i, label in ipairs(rose.picks) do
        local c = ""
        if picking then
            if #picking <= 4 then
                c = ""
            else
                c = picking:sub(i, i)
            end
            if S.capsLock or S.caps then c = ns.Upper(c) end
        end
        label:SetText(c)
    end
end

-- The chat box against the lesson's line. What is kept there should be the line's words up to the one being
-- typed: a word of the line missing again puts the lesson back on it; anything else is returned as the text to
-- take back (nil when all is well).
function LESSON.Check()
    local lesson = S.lesson
    local first = 1
    for i = 1, #LESSON do
        if LESSON_LINE_END[i] and i < lesson.at then first = i + 1 end
    end
    local function Plain(text) return (ns.Lower(text):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end
    local have = Plain(S.committed)
    -- the line as it stands after each of its steps
    local text, fits = "", first
    if have == "" then return end
    for i = first, math.min(lesson.at - 1, #LESSON) do
        local entry = LESSON[i]
        local joins = entry == "?" or (i > first and not D.KeyOf(entry) and not D.KeyOf(LESSON[i - 1]))
        text = text .. ((text == "" or joins) and "" or " ") .. entry
        if have == text then
            if i < lesson.at - 1 then lesson.at, lesson.stage, lesson.chained = i + 1, nil, nil end
            return
        end
        if have:sub(1, #text + 1) == text .. " " then fits = #text + 2 end
    end
    return Plain(S.committed):sub(fits == first and 1 or fits)
end

-- The lesson's line for where the player is now, and the box to light (lesson.next).
local function LessonText()
    local lesson = S.lesson
    lesson.next, lesson.slot = nil, nil
    -- Something in the chat box that is not in the line: how to take it back comes before anything else.
    local wrong = LESSON.Check()
    if wrong then return L["LESSON_FIX"]:format(wrong, Glyph("PADLTRIGGER"), wrong) end
    local target = LESSON[lesson.at]
    if not target then return L["LESSON_SEND"]:format(LESSON.last, Glyph("PAD1")) end
    -- A symbol: the page first; then a flick for a box's first symbol, the hold and pick for any other.
    if not D.KeyOf(target) then
        if not S.symbols then return L["LESSON_SYMBOLS"]:format(target, Glyph("PAD3")) end
        local box, place
        for g, symbols in ipairs(SYMBOLS) do
            local at = symbols:find(target, 1, true)
            if at then box, place = g, at end
        end
        lesson.next = box
        local left = box <= 4
        local stick, way = L[left and "STICK_LEFT" or "STICK_RIGHT"], L["DIR_" .. ((box - 1) % 4 + 1)]
        if place == 1 then return L["LESSON_SYMBOL_FLICK"]:format(stick, way, target) end
        return L["LESSON_SYMBOL_HOLD"]:format(target, SYMBOLS[box], stick, way,
            L[left and "STICK_RIGHT" or "STICK_LEFT"], L["DIR_" .. place], target)
    end
    local key, targetLetters = D.KeyOf(target), ns.Characters(target)
    if lesson.at == LESSON.roll and not lesson.chained then
        local stage = lesson.stage or 1
        local letters, ways = {}, {}
        for j = 1, LESSON.stages[stage] do
            letters[j] = targetLetters[j]
            ways[j] = L["DIR_" .. ((tonumber(key:sub(j, j)) - 1) % 4 + 1)]
        end
        lesson.next = tonumber(key:sub(#S.flicks + 1, #S.flicks + 1))
        local stick = L[tonumber(key:sub(1, 1)) <= 4 and "STICK_LEFT" or "STICK_RIGHT"]
        local text
        if stage == 1 then
            text = L["LESSON_CHAIN_1"]:format(stick, ways[1], letters[1], ways[2], letters[2])
        else
            text = L[stage == #LESSON.stages and "LESSON_CHAIN_ALL" or "LESSON_CHAIN_MORE"]:format(
                table.concat(letters, ", "), stick, table.concat(ways, ", "))
        end
        local before = lesson.missed and L["LESSON_CHAIN_MISS"] or lesson.praise and L["LESSON_CHAIN_GOOD"]
        return before and before .. "\n\n" .. text or text
    end
    if key:sub(1, #S.flicks) ~= S.flicks then
        -- What went wrong at the first flick that missed: the other stick, another direction, or one flick too many.
        local i = 1
        while key:sub(i, i) == S.flicks:sub(i, i) do i = i + 1 end
        local want, got = tonumber(key:sub(i, i)), tonumber(S.flicks:sub(i, i))
        local back = Glyph("PADLTRIGGER")
        if not want then return L["LESSON_TOO_MANY"]:format(target, back) end
        local how = { targetLetters[i], Groups()[want], L[want <= 4 and "STICK_LEFT" or "STICK_RIGHT"],
            L["DIR_" .. ((want - 1) % 4 + 1)], back }
        local sameStick, sameDir = (want <= 4) == (got <= 4), (want - got) % 4 == 0
        if sameDir and not sameStick then return L["LESSON_WRONG_STICK"]:format(unpack(how)) end
        if sameStick then return L["LESSON_WRONG_DIR"]:format(unpack(how)) end
        return L["LESSON_WRONG"]:format(Groups()[got], unpack(how))
    end
    local shown = ns.Lower(Word() or "")
    local intro = #S.flicks == 0 and LESSON_LINE_START[lesson.at]
    intro = intro and L[intro] .. "\n\n" or ""
    local rolling = lesson.at == LESSON.roll
    -- The drill just done: a word of praise before the rest of the word.
    if rolling and lesson.praise then intro = L["LESSON_CHAIN_GOOD"] .. " " end
    -- A word standing over the d-pad is taken there, however much of it was flicked and whatever the player's own
    -- words put there: watching for it is the habit to teach. Only a word the box already shows is left to RT.
    if #S.flicks < #key or shown ~= target then
        for slot = 1, #SLOT_KEYS do
            if ns.Lower(S.slots[slot] or "") == target
                and (#S.flicks > 0 or lesson.at < #LESSON)
                and (not rolling or lesson.chained) then
                local line = lesson.dpadTold and "LESSON_DPAD" or "LESSON_DPAD_FIRST"
                lesson.slot = slot
                return intro .. L[line]:format(target, L["DIR_" .. SLOT_DIR[slot]])
            end
        end
    end
    if lesson.at == #LESSON and shown == target and #S.flicks == #key then
        return L["LESSON_SEND"]:format(target, Glyph("PAD1"))
    end
    if #S.flicks < #key then
        local i = #S.flicks + 1
        local digit = tonumber(key:sub(i, i))
        lesson.next = digit
        local opens = lesson.at == 1 or LESSON_LINE_END[lesson.at - 1]
        -- A word's first flick names the word (the line's first word, or the next); its later ones carry on.
        local line = L[i > 1 and "LESSON_FLICK_ON" or opens and "LESSON_FLICK_FIRST" or "LESSON_FLICK"]:format(target, targetLetters[i], Groups()[digit],
            L[digit <= 4 and "STICK_LEFT" or "STICK_RIGHT"], L["DIR_" .. ((digit - 1) % 4 + 1)])
        -- Once the drill is done, letters in a row on one stick are asked for as one move (never the same box
        -- twice running: that takes a return to rest).
        if lesson.at > LESSON.roll then
            local letters, ways, j = {}, {}, i
            while j <= #key do
                local d, before = tonumber(key:sub(j, j)), j > i and tonumber(key:sub(j - 1, j - 1))
                if (d <= 4) ~= (digit <= 4) or before == d then break end
                local way = L["DIR_" .. ((d - 1) % 4 + 1)]
                letters[#letters + 1] = targetLetters[j]
                ways[#ways + 1] = before and (before - d) % 4 == 2 and L["LESSON_ACROSS"]:format(way) or way
                j = j + 1
            end
            if #letters > 1 then
                line = L["LESSON_CHAIN_RUN"]:format(target, table.concat(letters, ", "),
                    L[digit <= 4 and "STICK_LEFT" or "STICK_RIGHT"], table.concat(ways, ", "))
                -- held to (LESSON.Run): the flicks from i to the run's last, in one move
                lesson.asked = lesson.asked or { a = i, b = i + #letters - 1 }
                if lesson.missed then line = L["LESSON_CHAIN_MISS"] .. "\n\n" .. line end
            end
        end
        if lesson.at == 1 and i == 1 then return L["LESSON_START"] .. "\n\n" .. line end
        if intro ~= "" then return intro .. line end
        if shown ~= table.concat(targetLetters, "", 1, #S.flicks) and not lesson.missed then
            return L["LESSON_GUESSING"]:format(Word(), Groups()[tonumber(key:sub(i - 1, i - 1))]) .. "\n\n" .. line
        end
        return line
    end
    if shown ~= target then return L["LESSON_NEXT"]:format(Word(), Glyph("PADRSHOULDER"), target) end
    return L["LESSON_TAKE"]:format(target, Glyph("PADRTRIGGER"))
end

-- The line over the legend: what to do right now.
local function Hint()
    if S.lesson then return LessonText() end
    if S.wheel then return "" end
    if S.move then return L[S.move.guide and "HINT_MOVE_GUIDE" or "HINT_MOVE"]:format(Glyph("PAD1"), Glyph("PAD2"), Glyph("PAD4")) end
    if S.draftBack then return L["DRAFT_BACK"]:format(Glyph("PADBACK")) end
    if S.forget then return L["FORGET_ASK"]:format(ns.Lower(S.forget), Glyph("PAD1")) end
    if S.phrases then
        if S.phraseSave then return L["HINT_PHRASE_SAVE"]:format(Glyph("PADLTRIGGER")) end
        if S.phraseNoText then return L["PHRASE_NEED_TEXT"]:format(Glyph("PAD1"), Glyph("PAD3")) end
        if not Fit.PhraseSends() then
            return L["HINT_PHRASES_FILL"]:format(Glyph("PAD1"), Glyph("PAD3"), Glyph("PAD1"))
        end
        return L["HINT_PHRASES"]:format(Glyph("PADRTRIGGER"), Glyph("PAD3"), Glyph("PAD1"))
    end
    if S.naming then
        if S.naming.flicks ~= "" and #S.naming.found == 0 then return L["NAMING_NONE"] end
        return L["HINT_NAMING"]
    end
    if S.symbols then return L["HINT_SYMBOLS"] end
    if S.exact then return S.box and L["HINT_EXACT_PICK"] or L["HINT_EXACT"] end
    -- Flicks no word fits show each box's first letter: say so, or it reads as the keyboard making junk.
    if S.flicks ~= "" and #S.stems == 0 then return L["NO_WORD"] end
    if S.missing then return L["HINT_MISSING"] end
    -- Mid-word, until the player has kept a good few: one flick per letter, never the same box over and over.
    if S.flicks ~= "" and (ns.db.uses.take or 0) < FLICK_TIP_USES then return L["HINT_NEXT"] end
    if not Word() and (ns.db.uses.flick or 0) < FLICK_TIP_USES then return L["HINT_FLICK"] end
    return ""
end

-- Every button with the game's own icon. The guide box (R3 hides it) holds the shoulders as the pad holds them, each
-- hand's trigger over its bumper over its middle button; the face buttons sit in a bar under the chat line, where
-- the game's controller mode keeps its own chat buttons. Menu stays the game's; A sends. CHORD: LT and RT together.
local COLUMNS = { { "PADLTRIGGER", "PADLSHOULDER", "PADBACK" }, { "PADRTRIGGER", "PADRSHOULDER", "CHORD" } }
local FACE = { "PAD1", "PAD3", "PAD4", "PAD2" }
local ON_BAR = { PAD1 = true, PAD3 = true, PAD4 = true, PAD2 = true }
-- The bar: its height, the room inside its ends, and between two buttons.
-- The guide, the bar and the hints line draw at the game's own interface scale with its own numbers, so they read
-- as its controller legend (GamepadPersistentInputLegend: 18 px icons, 24 px rows, 20 px margins) and its chat
-- buttons (24 px icons, the label 4 px on) do: GameFontNormal throughout.
local GUIDE_ICON, GUIDE_ROW, GUIDE_EDGE, GUIDE_COL = 18, 24, 20, 24
local BAR_ICON, BAR_H, BAR_PAD, BAR_GAP, LABEL_GAP = 24, 34, 10, 16, 4
local labels = {}

local function Labels()
    labels.PADLSHOULDER = S.exact and L["GUESSING"] or L["EXACT"]
    labels.PADLTRIGGER, labels.PADBACK = L["ERASE"], L["CLEAR"]
    -- RB names the reading it would put in the box next.
    local upNext = S.flicks ~= "" and #S.stems >= 2 and S.stems[S.shown % #S.stems + 1]
    labels.PADRSHOULDER = upNext and L["NEXT_IS"]:format(Cap(upNext)) or L["NEXT"]
    labels.PADRTRIGGER, labels.CHORD = L["KEEP"], L["SLASH"]
    labels.PAD4 = S.lesson and L["LESSON_SKIP"] or L["CHANNEL"]
    labels.PAD3 = S.phrases and L["SAVE_PHRASE"] or S.symbols and L["LETTERS"] or L["SYMBOLS"]
    -- In a fight the game lets no addon close chat: B puts the keyboard away and the game's own B closes it.
    labels.PAD2, labels.PAD1 = L[InCombatLockdown() and "CLOSE_FIGHT" or "CLOSE"], L[S.phrases and "SEND_LETTERS" or "SEND_PHRASES"]
    -- A settings box: A saves what is typed, B leaves it as it was; no channels there.
    if box and not box.chatFrame then
        labels.PAD1, labels.PAD2, labels.PAD4 = L["SAVE"], L["CANCEL"], ""
    end
    if S.move then
        labels.PAD1, labels.PAD2, labels.PAD4, labels.PAD3 = L["SAVE"], L["CANCEL"], L["MOVE_RESET"], ""
    end
    if ns.practice then labels.PAD1 = L["PRACTICE_AGAIN"] end
    return labels
end

-- The icon inside the game's own text for a button, at its 64 px size when there is one; plain text when none.
local function SetIcon(prompt, key)
    local text = GetBindingText(key, 1) or ""
    if prompt.glyph == text then return end
    prompt.glyph = text
    local atlas, file = text:match("|A:([^:|]+)"), text:match("|T([^:|]+)")
    if atlas then
        local big = atlas:gsub("_%d+$", "_64")
        prompt.icon:SetAtlas(C_Texture.GetAtlasInfo(big) and big or atlas)
    elseif file then
        prompt.icon:SetTexture(file)
    end
    prompt.icon:SetShown(atlas ~= nil or file ~= nil)
    prompt.plain = not (atlas or file) and text or nil
    prompt.text = nil
end

local function PlacePrompt(prompt, parent, x, y)
    prompt.icon:ClearAllPoints()
    prompt.icon:SetPoint("CENTER", parent, "BOTTOMLEFT", x, y)
    local last = prompt.icon
    if prompt.second then
        prompt.second.icon:ClearAllPoints()
        prompt.second.icon:SetPoint("LEFT", prompt.icon, "RIGHT", 2, 0)
        last = prompt.second.icon
    end
    prompt.label:ClearAllPoints()
    prompt.label:SetPoint("LEFT", last, "RIGHT", LABEL_GAP, 0)
end

-- The guide's columns as wide as their longest label; the bar's buttons one after another.
local function PlacePrompts()
    local P = kb.prompts
    -- RB's label changes with every flick: it keeps room for a longish reading so nothing else moves.
    local rt = P.PADRSHOULDER
    local now = rt.label:GetText()
    rt.label:SetText(L["NEXT_IS"]:format(string.rep("w", 6)))
    rt.width = math.ceil(rt.label:GetUnboundedStringWidth())
    rt.label:SetText(now)
    rt.label:SetWidth(rt.width)
    rt.label:SetJustifyH("LEFT")
    local function Widest(keys)
        local most = 0
        for _, key in ipairs(keys) do
            local width = P[key].width or P[key].label:GetStringWidth()
            most = math.max(most, width + (P[key].second and GUIDE_ICON + 2 or 0))
        end
        return most
    end
    local x2 = GUIDE_EDGE + GUIDE_ICON + LABEL_GAP + Widest(COLUMNS[1]) + GUIDE_COL
    -- the game's own box height for three rows: its last row's spare room comes off the bottom margin
    local height = GUIDE_ROW * 3 + GUIDE_EDGE * 2 - (GUIDE_ROW - GUIDE_ICON)
    kb.guide:SetSize(x2 + GUIDE_ICON + LABEL_GAP + Widest(COLUMNS[2]) + GUIDE_EDGE, height)
    for c, keys in ipairs(COLUMNS) do
        for row, key in ipairs(keys) do
            PlacePrompt(P[key], kb.guide, (c == 1 and GUIDE_EDGE or x2) + GUIDE_ICON / 2,
                height - GUIDE_EDGE - (row - 1) * GUIDE_ROW - GUIDE_ICON / 2)
        end
    end
    local x = BAR_PAD
    for _, key in ipairs(FACE) do
        -- A button with nothing to say here is left off the bar.
        local used = P[key].text ~= ""
        P[key].icon:SetAlpha(used and 1 or 0)
        if used then
            PlacePrompt(P[key], kb.bar, x + BAR_ICON / 2, BAR_H / 2)
            local label = P[key].label
            local width = label:GetStringWidth()
            -- X's label flips between two words: room for the longer, so what follows it never shifts.
            if key == "PAD3" and not S.phrases and not S.move then
                local shown = label:GetText()
                label:SetText(L["SYMBOLS"])
                width = math.max(width, label:GetStringWidth())
                label:SetText(L["LETTERS"])
                width = math.max(width, label:GetStringWidth())
                label:SetText(shown)
            end
            x = x + BAR_ICON + LABEL_GAP + width + BAR_GAP
        end
    end
    kb.bar:SetSize(x - BAR_GAP + BAR_PAD, BAR_H)
end

local function PaintPrompts()
    -- R3 hides the hints picked on the settings page: both (the default), the bar or the guide alone.
    local reach = ns.profile.hintsToggle or "both"
    -- the guide being moved shows, whatever the player hid
    local moving = S.move ~= nil and S.move.guide == true
    kb.guide:SetShown(not S.preview and (moving or not (ns.profile.guideOff and (reach == "both" or reach == "guide"))))
    -- Under a settings box the bar always shows: it is the only word on how to save or leave.
    kb.bar:SetShown(not S.preview
        and ((box ~= nil and not box.chatFrame) or not (ns.profile.guideOff and (reach == "both" or reach == "bar"))))
    Fit.ScrollMarks(ns.profile.guideOff and (reach == "both" or reach == "bar"))
    local toggle = kb.toggle
    SetIcon(toggle, "PADRSTICK")
    local text = L[ns.profile.guideOff and "HINTS_SHOW" or "HINTS_HIDE"]
    if toggle.plain then text = toggle.plain .. " " .. text end
    toggle.label:SetText(text)
    -- Over the guide while it shows above the keyboard, else over the keyboard itself.
    local over = (not kb.guide:IsShown() or kb.guideCorner or kb.guideOverChat) and kb or kb.guide
    -- Its mirror on the left: the left stick press, a capital (twice, all capitals).
    local caps = kb.capsTip
    SetIcon(caps, "PADLSTICK")
    local capsText = L[S.capsLock and "CAPS_LOCKED" or "CAPS_TIP"]
    if caps.plain then capsText = caps.plain .. " " .. capsText end
    caps.label:SetText(capsText)
    -- Over a keyboard too narrow for both on one line (the stacked shape at a small size): the left one a line up.
    local room = kb:GetWidth() * kb:GetEffectiveScale() / kb.hints:GetEffectiveScale()
    local two = over == kb
        and caps.label:GetStringWidth() + toggle.label:GetStringWidth() + 2 * (GUIDE_ICON + LABEL_GAP) + 28 > room
    if toggle.over ~= over or toggle.two ~= two then
        toggle.label:ClearAllPoints()
        toggle.label:SetPoint("BOTTOMRIGHT", over, "TOPRIGHT", -6, TOGGLE_GAP)
        -- The label is what stands on the line, as the right one's does; the icon hangs on it.
        caps.label:ClearAllPoints()
        caps.label:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 6 + GUIDE_ICON + LABEL_GAP, TOGGLE_GAP + (two and 18 or 0))
        toggle.over, toggle.two = over, two
    end
    -- Both reminders go with the player's box on the settings page.
    local tips = not ns.profile.stickTipsOff
    toggle.label:SetShown(tips)
    toggle.icon:SetShown(tips and toggle.plain == nil)
    caps.label:SetShown(tips)
    caps.icon:SetShown(tips and caps.plain == nil)
    local moved = kb.promptsMoved
    for key, name in pairs(Labels()) do
        local prompt = kb.prompts[key]
        SetIcon(prompt, prompt.second and "PADLTRIGGER" or key)
        if prompt.second then
            SetIcon(prompt.second, "PADRTRIGGER")
            if prompt.second.plain then name = prompt.second.plain .. " " .. name end
        end
        if prompt.plain then name = prompt.plain .. (prompt.second and "+" or " ") .. name end
        if prompt.text ~= name then
            moved = moved or not prompt.width or (prompt.text == "") ~= (name == "")
            prompt.label:SetText(name)
            prompt.text = name
        end
    end
    if moved then PlacePrompts() end
    kb.promptsMoved = false
end

local function Layout()
    kb:SetHeight(PAD + kb.bodyH + PAD)
end

Paint = function()
    if not kb or not (box or S.preview) then return end
    local text = Hint()
    PaintRose(kb.roses[1], sticks.Left)
    PaintRose(kb.roses[2], sticks.Right)
    local shown = ns.Lower(Word() or "")
    local list = S.naming and S.naming.found
    for i, slot in ipairs(kb.slots) do
        local entry = (list or NOTHING)[i]
        local word = entry and entry.label or not list and S.slots[i]
        slot:SetText(word and (entry and word or Cap(word)) or "")
        if slot.room then
            local size = TEXT.guess
            local width = slot:GetStringWidth()
            if width > slot.room then size = math.max(math.floor(size * SIDE_SHRINK), math.floor(size * slot.room / width)) end
            if slot.size ~= size then
                slot:SetFont(TEXT.font, size, "OUTLINE")
                slot.size = size
            end
        end
        local lit
        if entry then
            lit = S.naming and i == 1
        else
            lit = word and ns.Lower(word) == shown
        end
        -- While the lesson points at a d-pad word, that one alone is yellow (not the one the box shows too).
        local color = lit and not (S.lesson and S.lesson.slot) and YELLOW or IDLE
        if S.forget and word and ns.Lower(word) == ns.Lower(S.forget) then color = FORGET_COLOR end
        -- The lesson's "it is over the d-pad": that word beats, so the eye finds it.
        local beat = S.lesson ~= nil and S.lesson.slot == i
        if beat then color = YELLOW end
        if beat ~= (slot.beating or false) then
            slot.beating = beat
            if beat and not slot.beat then
                slot.beat = slot:CreateAnimationGroup()
                slot.beat:SetLooping("BOUNCE")
                local fade = slot.beat:CreateAnimation("Alpha")
                fade:SetFromAlpha(1)
                fade:SetToAlpha(0.25)
                fade:SetDuration(0.45)
                fade:SetSmoothing("IN_OUT")
            end
            if beat then
                slot.beat:Play()
            elseif slot.beat then
                slot.beat:Stop()
                slot:SetAlpha(1)
            end
        end
        slot:SetTextColor(color[1], color[2], color[3])
        kb.marks[i]:SetAlpha(word and 1 or 0.35)
    end
    PaintPrompts()
    local size = S.lesson and TEXT.lesson or TEXT.hint
    if kb.hintSize ~= size then
        kb.hint:SetFont(TEXT.font, size, "OUTLINE")
        kb.hintSize = size
    end
    -- Under the window, and gone with the hints the player hid; the lesson's lines always show.
    kb.hint:SetText(text ~= "" and (S.lesson or S.forget or S.move or not ns.profile.guideOff or S.symbols and (ns.db.uses.pick or 0) < PICK_TIP_USES) and text or nil)
    -- The lesson's lines stand over the keyboard on a dark strip (chat sits low on most screens), clear of the
    -- guide and the reminders there; with the keyboard high on the screen they stay under it.
    -- Under the lesson's lines a row of its own for the skip reminder, with a little air between.
    local row = S.lesson and size + 10 or 0
    local lift = false
    if S.lesson and (kb:GetTop() or 0) * kb:GetEffectiveScale() < UIParent:GetHeight() * UIParent:GetEffectiveScale() * 0.7 then
        lift = 14
        if kb.toggle.over == kb.guide then lift = lift + kb.guide:GetHeight() + 4 end
        if not ns.profile.stickTipsOff then lift = lift + TOGGLE_GAP + (kb.toggle.two and 36 or 18) end
        lift = lift + row
    end
    if kb.hintLift ~= lift then
        kb.hintLift = lift
        kb.hint:ClearAllPoints()
        if lift then
            -- as wide as over the wide shape, whatever the shape (centred): the lesson's lines break the same
            local out = (kb.wideW - kb.baseW) / 2
            kb.hint:SetPoint("BOTTOMLEFT", kb, "TOPLEFT", 14 - out, lift)
            kb.hint:SetPoint("BOTTOMRIGHT", kb, "TOPRIGHT", out - 14, lift)
        else
            -- Under the button bar when that hangs on the keyboard (a box with no footer of the game's to stand
            -- in for). The bar keeps the screen's scale, the hint the keyboard's: the bar's height in the hint's.
            local drop = 4
            if box and not box.chatFrame and not kb.barOver and kb.bar:IsShown() then
                drop = kb.bar:GetHeight() * kb.bar:GetEffectiveScale() / kb:GetEffectiveScale() + 6
            end
            kb.hint:SetPoint("TOPLEFT", kb, "BOTTOMLEFT", 6, -drop)
            kb.hint:SetPoint("TOPRIGHT", kb, "BOTTOMRIGHT", -6, -drop)
        end
    end
    kb.hintBack:SetPoint("BOTTOMRIGHT", kb.hint, "BOTTOMRIGHT", 8, -7 - row)
    kb.hintBack:SetShown(lift ~= false and kb.hint:GetText() ~= nil)
    if kb.skipSize ~= size then
        kb.hintSkip:SetFont(TEXT.font, size, "OUTLINE")
        kb.skipSize = size
    end
    kb.hintSkip:SetText(S.lesson and (Glyph("PAD4") .. " " .. L["LESSON_SKIP"]) or "")
    -- Over the step, centred, the goal: the whole line being typed, white, its finished words greyed.
    local goal = ""
    if S.lesson then
        local at, first, words = S.lesson.at, 1, {}
        for i = 1, #LESSON do
            if LESSON_LINE_END[i] and i < at then first = i + 1 end
        end
        for i = first, #LESSON do
            local word = (i < at and "|cff8c8c8c" or "|cffffffff") .. D.Form(LESSON[i]) .. "|r"
            -- a question mark closes its word, a symbol after a symbol joins it (the smiley)
            local joins = #words > 0 and (LESSON[i] == "?" or (not D.KeyOf(LESSON[i]) and not D.KeyOf(LESSON[i - 1])))
            if joins then words[#words] = words[#words] .. word else words[#words + 1] = word end
            if LESSON_LINE_END[i] then break end
        end
        goal = L["LESSON_GOAL"]:format(table.concat(words, " "))
    end
    -- A font before any text, the lesson running or not: text set on a fontless string is an error.
    if kb.goalSize ~= size then
        kb.hintGoal:SetFont(TEXT.font, size + 2, "OUTLINE")
        kb.goalSize = size
    end
    kb.hintGoal:SetText(goal)
    kb.hintBack:SetPoint("TOPLEFT", kb.hint, "TOPLEFT", -8, 7 + (goal ~= "" and size + 14 or 0))
    Layout()
end

-- Built once; sizes in 1080-line pixels, the frame's scale doing the rest.

-- A box piece in the game's art, its bevel kept as the box stretches; a flat color where the client lacks the art.
local function BoxArt(texture, atlas, color)
    if C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
        texture:SetTextureSliceMargins(BOX_EDGE, BOX_EDGE, BOX_EDGE, BOX_EDGE)
        texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    else
        texture:SetColorTexture(color[1], color[2], color[3], color[4])
    end
end

local function HubArt(texture, atlas, size, color)
    if C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
    else
        texture:SetTexture(DISC)
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    return texture
end

local function Rose(index)
    local rose = CreateFrame("Frame", nil, kb)
    rose.cells, rose.picks = {}, {}
    rose.hub = CreateFrame("Frame", nil, rose)
    rose.hub:SetSize(HUB_R * 2, HUB_R * 2)
    rose.hub:SetPoint("CENTER")
    HubArt(rose.hub:CreateTexture(nil, "BACKGROUND"), HUB_BG_ART, HUB_R * 2 + 6, { 0.1, 0.1, 0.11, 0.95 })
    HubArt(rose.hub:CreateTexture(nil, "BORDER"), HUB_ART, HUB_R * 2, { 0.2, 0.2, 0.22, 1 })
    rose.dot = HubArt(rose.hub:CreateTexture(nil, "OVERLAY"), DOT_ART, DOT, { YELLOW[1], YELLOW[2], YELLOW[3], 1 })
    for dir = 1, 4 do
        local cell = CreateFrame("Frame", nil, rose)
        cell.fill = cell:CreateTexture(nil, "BACKGROUND")
        cell.fill:SetAllPoints()
        BoxArt(cell.fill, BOX_ART, { 0.13, 0.13, 0.15, 0.85 })
        cell.lit = cell:CreateTexture(nil, "BORDER")
        cell.lit:SetPoint("TOPLEFT", -LIT_GLOW, LIT_GLOW)
        cell.lit:SetPoint("BOTTOMRIGHT", LIT_GLOW, -LIT_GLOW)
        BoxArt(cell.lit, LIT_ART, { YELLOW[1], YELLOW[2], YELLOW[3], 0.35 })
        cell.lit:Hide()
        cell.focus = cell:CreateTexture(nil, "BORDER")
        cell.focus:SetPoint("TOPLEFT", -LIT_GLOW, LIT_GLOW)
        cell.focus:SetPoint("BOTTOMRIGHT", LIT_GLOW, -LIT_GLOW)
        BoxArt(cell.focus, FOCUS_ART, { BLUE[1], BLUE[2], BLUE[3], 0.35 })
        cell.focus:Hide()
        cell.text = cell:CreateFontString(nil, "ARTWORK")
        cell.text:SetPoint("CENTER")
        kb.cells[(index - 1) * 4 + dir] = cell
        rose.cells[dir] = cell
    end
    for i = 1, 8 do
        rose.picks[i] = rose:CreateFontString(nil, "OVERLAY")
    end
    return rose
end

function ns.Restyle()
    if not kb then return end
    local size = (ns.profile.size or 100) / 100
    kb:SetScale(768 / 1080 * size / UIParent:GetEffectiveScale())
    -- The text's own size: the boxes grow to hold larger letters, the guesses' middle to hold larger words.
    local textScale = (ns.profile.textSize or 100) / 100
    for key, base in pairs(TEXT.base) do TEXT[key] = math.floor(base * textScale + 0.5) end
    local cellH = math.max(CELL_H, TEXT.letter + 16)
    local crossH = CROSS_H + 2.5 * math.max(0, TEXT.guess - TEXT.base.guess)
    -- the dark backing at the player's opacity, none at 0; the border stays solid
    local opacity = (ns.profile.backOpacity or 90) / 100
    for _, frame in ipairs({ kb, kb.guide }) do
        frame.back:SetAlpha(opacity)
        frame.back:SetShown(opacity > 0)
    end
    TEXT.font = TEXT.fonts[ns.WantedLanguage()] or STANDARD_TEXT_FONT
    kb.skipSize, kb.goalSize = nil, nil
    local font = TEXT.font
    local widest = 0
    kb.measure:SetFont(font, TEXT.letter, "OUTLINE")
    for _, set in ipairs({ ns.LAYOUTS[ns.profile.layout] or ns.LAYOUTS.letters, SYMBOLS }) do
        for _, letters in ipairs(set) do
            kb.measure:SetText(ns.Upper(letters))
            widest = math.max(widest, kb.measure:GetStringWidth())
        end
    end
    local cellW = math.ceil(widest) + 20
    local reachX, reachY = HUB_R + 6 + cellW / 2, HUB_R + 4 + cellH / 2
    local roseW, roseH = 2 * (HUB_R + 6 + cellW), 2 * (HUB_R + 4 + cellH)
    -- Wide: a stick either side of the guesses. Stacked: the sticks side by side and the guesses over or under
    -- them, with the keyboard's whole width for their own. middle: the guess cross's own, down from the
    -- keyboard's top.
    local crossW, between = CrossW(), 28
    kb.wideW = PAD * 2 + roseW * 2 + crossW + GAP * 2
    local roseX, roseY, middle
    local stacked = ns.Stacked()
    if stacked then
        crossW = roseW * 2 + between
        kb.bodyH, kb.baseW = roseH + GAP + crossH, PAD * 2 + crossW
        roseX = (between + roseW) / 2
        if stacked == "above" then
            middle, roseY = -(PAD + crossH / 2), -(PAD + crossH + GAP + roseH / 2)
        else
            roseY, middle = -(PAD + roseH / 2), -(PAD + roseH + GAP + crossH / 2)
        end
    else
        kb.bodyH, kb.baseW = math.max(roseH, crossH), kb.wideW
        middle = -(PAD + kb.bodyH / 2)
        roseX, roseY = crossW / 2 + GAP + roseW / 2, middle
    end
    kb:SetWidth(kb.baseW)
    local spots = { { 0, reachY }, { reachX, 0 }, { 0, -reachY }, { -reachX, 0 } }
    for i, rose in ipairs(kb.roses) do
        rose:SetSize(roseW, roseH)
        rose:ClearAllPoints()
        rose:SetPoint("CENTER", kb, "TOP", (i == 1 and -1 or 1) * roseX, roseY)
        for dir, cell in ipairs(rose.cells) do
            cell:SetSize(cellW, cellH)
            cell:SetPoint("CENTER", rose, "CENTER", spots[dir][1], spots[dir][2])
            cell.text:SetFont(font, S.phrases and TEXT.channel or TEXT.letter, "OUTLINE")
            cell.text:SetTextColor(LETTER_COLOR[1], LETTER_COLOR[2], LETTER_COLOR[3])
            cell.text:SetWidth(cellW - 6)
            cell.text:SetWordWrap(false)
        end
        for k, label in ipairs(rose.picks) do
            local angle = math.rad((k - 1) * 45)
            label:SetFont(font, TEXT.letter + 4, "OUTLINE")
            label:SetTextColor(1, 1, 1)
            label:SetPoint("CENTER", rose, "CENTER", math.sin(angle) * (reachX + 4), math.cos(angle) * (reachY + 4))
        end
    end
    local markSpots = { { 0, MARK_Y }, { -MARK_X, 0 }, { MARK_X, 0 }, { 0, -MARK_Y } }
    -- each word's anchor on its mark, the mark's side it reaches from, and how far
    local reach = { { "BOTTOM", "TOP", 0, 2 }, { "RIGHT", "LEFT", -6, 0 }, { "LEFT", "RIGHT", 6, 0 },
        { "TOP", "BOTTOM", 0, -2 } }
    for i, slot in ipairs(kb.slots) do
        local mark = kb.marks[i]
        -- the d-pad marks are icons: the keyboard's size, not the text's
        mark:SetFont(font, TEXT.base.guess, "")
        mark:SetText(Glyph(SLOT_KEYS[i]))
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", kb, "TOP", markSpots[i][1], middle + markSpots[i][2])
        slot:SetFont(font, TEXT.guess, "OUTLINE")
        slot.size = TEXT.guess
        slot:ClearAllPoints()
        -- Up and down have the cross's whole width; a side word its half past the mark.
        local width = (i == 1 or i == 4) and crossW or crossW / 2 - MARK_X - 10
        slot:SetWidth(width)
        slot.room = (i == 2 or i == 3) and width or nil
        slot:SetJustifyH(i == 2 and "RIGHT" or i == 3 and "LEFT" or "CENTER")
        slot:SetPoint(reach[i][1], mark, reach[i][2], reach[i][3], reach[i][4])
        slot:SetWordWrap(false)
    end
    kb.hint:SetFont(font, TEXT.hint, "OUTLINE")
    kb.hintSize = TEXT.hint
    for _, piece in ipairs({ kb.guide, kb.bar, kb.hints }) do
        piece:SetIgnoreParentScale(true)
        piece:SetScale(UIParent:GetEffectiveScale())
    end
    for key, prompt in pairs(kb.prompts) do
        local icon = ON_BAR[key] and BAR_ICON or GUIDE_ICON
        prompt.icon:SetSize(icon, icon)
        if prompt.second then prompt.second.icon:SetSize(icon, icon) end
        prompt.label:SetFontObject(GameFontNormal)
        prompt.text = nil
    end
    kb.promptsMoved = true
    local toggle = kb.toggle
    toggle.icon:SetSize(GUIDE_ICON, GUIDE_ICON)
    toggle.icon:ClearAllPoints()
    toggle.icon:SetPoint("RIGHT", toggle.label, "LEFT", -LABEL_GAP, 0)
    -- Free over the game world: outlined, no backing.
    toggle.label:SetFontObject(GameFontNormal)
    toggle.glyph, toggle.over = nil, nil
    local caps = kb.capsTip
    caps.icon:SetSize(GUIDE_ICON, GUIDE_ICON)
    caps.icon:ClearAllPoints()
    caps.icon:SetPoint("RIGHT", caps.label, "LEFT", -LABEL_GAP, 0)
    caps.label:SetFontObject(GameFontNormal)
    caps.glyph = nil
    kb.hint:ClearAllPoints()
    kb.hint:SetPoint("TOPLEFT", kb, "BOTTOMLEFT", 6, -4)
    kb.hint:SetPoint("TOPRIGHT", kb, "BOTTOMRIGHT", -6, -4)
    kb.hintLift = false
    if box or S.preview then Paint() end
    if S.preview then ns.SeatPreview() end
end

-- The typing language changed: its list, and the word under way dropped.
function ns.Relanguage()
    if not (kb and box) then return end
    D.Build()
    LESSON.Use(D.Code())
    D.Refresh(S.names)
    S.flicks, S.literal = "", nil
    ns.Restyle()
    Guess()
    Show()
end

function ns.Relayout()
    if D.Built() then D.SetLayout(ns.profile.layout) end
    ns.Restyle()
    if kb and box then
        S.flicks = ""
        Guess()
        Show()
    end
end

-- The game's controller mode puts its own chat buttons under the box (what the game would do with A, X, Y, B) and
-- LB/RB marks on the chat tabs. While the keyboard is up those buttons are ours: the pieces hide (each kept hidden if
-- the game shows it again) and come back as the keyboard goes, when the game still has them up.
local TAB_HINT_ICON, TAB_HINT_OUT = 16, 4
local stepAside = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })

local function StepAside(piece, owner)
    if not piece or not owner or piece:IsForbidden() then return end
    stepAside[piece] = owner
    if not watched[piece] then
        watched[piece] = true
        piece:HookScript("OnShow", function(self)
            if kb and kb:IsShown() and stepAside[self] then self:Hide() end
        end)
    end
    piece:Hide()
end

local function GameChatButtons(edit)
    -- The chat's own pieces: only while it is chat that is typed in. In another window's box the tabs cannot be
    -- flipped, and the game's marks on them stay the game's.
    local chat = edit.chatFrame
    local footer = chat and chat.footer
    StepAside(footer and footer.inputLegend, footer)
    local dock = chat and GENERAL_CHAT_DOCK
    StepAside(dock and dock.LeftTabHint, dock and dock.footer)
    StepAside(dock and dock.RightTabHint, dock and dock.footer)
    -- In their places: View with the bumper, the pair that flips the tabs while typing. On a frame at the chat's
    -- own depth, so a window standing over the chat covers them as it covers the tabs.
    local hints = kb.tabHints
    if not hints then
        hints = { holder = CreateFrame("Frame", nil, kb) }
        -- At the screen's own scale, as the other hint pieces: the keyboard's size never sizes them.
        hints.holder:SetIgnoreParentScale(true)
        hints.holder:SetScale(UIParent:GetEffectiveScale())
        kb.tabHints = hints
        for i = 1, 4 do
            hints[i] = { icon = hints.holder:CreateTexture(nil, "OVERLAY") }
            hints[i].icon:SetSize(TAB_HINT_ICON, TAB_HINT_ICON)
        end
    end
    if dock and not dock:IsForbidden() then
        hints.holder:SetFrameStrata(dock:GetFrameStrata())
        hints.holder:SetFrameLevel(dock:GetFrameLevel() + 10)
    end
    local game = dock and InputUtil ~= nil and InputUtil.IsGamepadUIEnabled()
    -- Outside the game's controller interface its hint frames are not laid out: the pairs go beside the first docked
    -- tab and the last one shown (or the dock's right end, its last tabs scrolled out of sight).
    local first, last
    local docked = dock and not game and not dock:IsForbidden() and dock.DOCKED_CHAT_FRAMES
    if docked and docked[1] then
        first, last = _G[docked[1]:GetName() .. "Tab"], _G[docked[#docked]:GetName() .. "Tab"]
        if last and not last:IsVisible() then last = dock end
    end
    for i, key in ipairs({ "PADBACK", "PADLSHOULDER", "PADBACK", "PADRSHOULDER" }) do
        local hint = game and (i <= 2 and dock.LeftTabHint or dock.RightTabHint)
        local beside = not game and (i <= 2 and first or last)
        local icon = hints[i].icon
        if hint and not hint:IsForbidden() then
            SetIcon(hints[i], key)
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", hint, "CENTER",
                (i % 2 == 1 and -1 or 1) * TAB_HINT_ICON / 2 + (i <= 2 and -TAB_HINT_OUT or TAB_HINT_OUT), 0)
        elseif beside and not beside:IsForbidden() then
            -- View then the bumper, reading outward from the tabs
            SetIcon(hints[i], key)
            icon:ClearAllPoints()
            local out = TAB_HINT_OUT + (i % 2 == 1 and 0.5 or 1.5) * TAB_HINT_ICON
            if i <= 2 then
                icon:SetPoint("CENTER", beside, "LEFT", -(TAB_HINT_OUT + (i == 1 and 1.5 or 0.5) * TAB_HINT_ICON), 0)
            else
                icon:SetPoint("CENTER", beside, "RIGHT", out, 0)
            end
        else
            icon:Hide()
        end
    end
end

-- The game's controller legend (its top left box) names what its own buttons would do: while typing, the guide
-- takes its corner and it steps aside. Outside the game's controller mode the guide sits over the keyboard.
local LEGEND_OWNER = { isShown = true }

PlaceGuide = function()
    local legend = GamepadPersistentInputLegend
    kb.guide:ClearAllPoints()
    kb.guideCorner = legend ~= nil and not legend:IsForbidden() and legend:IsShown()
        and InputUtil ~= nil and InputUtil.IsGamepadUIEnabled()
    -- Outside it, over chat's tabs: the keyboard's top and the lesson's lines over it stay free.
    local chat = not kb.guideCorner and box and box.chatFrame
    kb.guideOverChat = chat and not chat:IsForbidden() or nil
    -- plus how far the player carried it (the settings' Button guide place)
    local x, y = ns.profile.guideX or 0, ns.profile.guideY or 0
    if kb.guideCorner then
        kb.guide:SetPoint("TOPLEFT", legend, "TOPLEFT", x, y)
        StepAside(legend, LEGEND_OWNER)
    elseif kb.guideOverChat then
        local name = chat:GetName()
        local tab = name and _G[name .. "Tab"]
        local tabTop, chatTop = tab and tab:GetTop(), chat:GetTop()
        local over = tabTop and chatTop
            and (tabTop * tab:GetEffectiveScale() - chatTop * chat:GetEffectiveScale()) / kb.guide:GetEffectiveScale() or 30
        kb.guide:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", x, y + math.max(0, over) + 4)
    else
        kb.guide:SetPoint("BOTTOMLEFT", kb, "TOPLEFT", x, y + 4)
    end
    kb.toggle.over = nil
end

local function GameChatButtonsBack()
    for piece, owner in pairs(stepAside) do
        stepAside[piece] = nil
        if owner.isShown then piece:Show() end
    end
end

-- A dark backing (frame.back) in the game's dialog border, as its controller legend box is drawn. Solid in itself:
-- its alpha is the whole of its see-through (the keyboard's, the player's opacity).
local function Dress(frame)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetPoint("TOPLEFT", 4, -4)
    frame.back:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.back:SetColorTexture(0.03, 0.03, 0.04, 1)
    frame.back:SetAlpha(0.92)
    if NineSliceUtil and NineSliceLayouts and NineSliceLayouts.Dialog then
        NineSliceUtil.ApplyLayoutByName(frame, "Dialog")
    end
end

ns.Dress = Dress

local function Build()
    kb = CreateFrame("Frame", "FlickChatKeyboard", UIParent)
    kb:SetFrameStrata("DIALOG")
    kb:SetClampedToScreen(true)
    kb:EnableMouse(true)
    kb:Hide()
    Dress(kb)
    kb.guide = CreateFrame("Frame", nil, kb)
    kb.guide:SetClampedToScreen(true)
    kb.guide:SetPoint("BOTTOMLEFT", kb, "TOPLEFT", 0, 4)
    Dress(kb.guide)
    kb.measure = kb:CreateFontString(nil, "ARTWORK")
    kb.measure:SetAlpha(0)
    kb.cells, kb.roses, kb.slots = {}, {}, {}
    kb.roses[1], kb.roses[2] = Rose(1), Rose(2)
    kb.marks = {}
    for i = 1, #SLOT_KEYS do
        kb.slots[i] = kb:CreateFontString(nil, "ARTWORK")
        kb.marks[i] = kb:CreateFontString(nil, "ARTWORK")
    end
    kb.hint = kb:CreateFontString(nil, "ARTWORK")
    kb.hint:SetTextColor(1, 0.82, 0)
    -- behind the lesson's lines when they stand over the keyboard
    kb.hintBack = kb:CreateTexture(nil, "BACKGROUND")
    kb.hintBack:SetColorTexture(0, 0, 0, 0.78)
    kb.hintBack:SetPoint("TOPLEFT", kb.hint, "TOPLEFT", -8, 7)
    kb.hintBack:SetPoint("BOTTOMRIGHT", kb.hint, "BOTTOMRIGHT", 8, -7)
    kb.hintBack:Hide()
    -- the lesson's way out, apart from its lines: at the right end of their last row
    kb.hintSkip = kb:CreateFontString(nil, "ARTWORK")
    kb.hintSkip:SetTextColor(0.82, 0.82, 0.82)
    kb.hintSkip:SetPoint("TOPRIGHT", kb.hint, "BOTTOMRIGHT", 0, -8)
    kb.hintGoal = kb:CreateFontString(nil, "ARTWORK")
    kb.hintGoal:SetTextColor(1, 0.82, 0)
    kb.hintGoal:SetPoint("BOTTOM", kb.hint, "TOP", 0, 10)
    kb.bar = CreateFrame("Frame", nil, kb)
    kb.bar:SetClampedToScreen(true)
    -- Over the game's own footer when the bar stands in its place: all of it out of sight, whatever its size.
    kb.barCover = kb.bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    kb.barCover:SetColorTexture(0.03, 0.03, 0.04, 1)
    kb.barCover:Hide()
    local slot = kb.bar:CreateTexture(nil, "BACKGROUND")
    slot:SetAllPoints()
    local edge = kb.bar:CreateTexture(nil, "BORDER")
    edge:SetAllPoints()
    if C_Texture.GetAtlasInfo("gamepad-footer-slot-bg") then
        slot:SetAtlas("gamepad-footer-slot-bg")
        edge:SetAtlas("gamepad-footer-slot-frameneutral")
    else
        slot:SetColorTexture(0.03, 0.03, 0.04, 0.92)
    end
    kb.prompts = {}
    for key in pairs(Labels()) do
        local parent = ON_BAR[key] and kb.bar or kb.guide
        local prompt = { icon = parent:CreateTexture(nil, "ARTWORK"), label = parent:CreateFontString(nil, "ARTWORK") }
        prompt.label:SetWordWrap(false)
        kb.prompts[key] = prompt
    end
    kb.prompts.CHORD.second = { icon = kb.guide:CreateTexture(nil, "ARTWORK") }
    kb.hints = CreateFrame("Frame", nil, kb)
    kb.hints:SetAllPoints(kb)
    kb.toggle = { icon = kb.hints:CreateTexture(nil, "ARTWORK"), label = kb.hints:CreateFontString(nil, "ARTWORK") }
    kb.capsTip = { icon = kb.hints:CreateTexture(nil, "ARTWORK"), label = kb.hints:CreateFontString(nil, "ARTWORK") }
    kb.hint:SetJustifyH("LEFT")
    kb.hint:SetWordWrap(true)
    kb:SetScript("OnGamePadStick", OnStick)
    kb:SetScript("OnGamePadButtonDown", function(_, button)
        if probe then
            Note(("down %s%s%s%s"):format(button, IsShiftKeyDown() and " shift" or "", IsControlKeyDown() and " ctrl" or "",
                IsAltKeyDown() and " alt" or ""))
            if probe and button == "PADLTRIGGER" then ns.LookAtPad() end
        end
        Press(button)
    end)
    kb:SetScript("OnGamePadButtonUp", function(_, button)
        if probe then Note("up " .. button) end
        Unpress(button)
    end)
    -- The controller is the keyboard's while it shows: no walking, jumping or casting under the typing.
    kb:SetScript("OnShow", function(self)
        self:EnableGamePadButton(not self.viewHold and not S.preview)
        self:EnableGamePadStick(not S.preview)
    end)
    kb:SetScript("OnHide", function(self)
        if probe then Note("keyboard hidden") end
        if S.joinWait then
            S.joinWait = nil
            ns.DisarmJoin()
        end
        self:EnableGamePadButton(false)
        self:EnableGamePadStick(false)
        StopHold()
        S.wheel = nil
        box = nil
        GameChatButtonsBack()
    end)
    ns.Restyle()
end

local function Names()
    local names = {}
    local function Add(name, chance)
        if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return end
        name = name:match("^[^%-%s]+")
        if name and (names[name] or 0) < chance then names[name] = chance end
    end
    local unit = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do Add(UnitName(unit .. i), NAME_GROUP) end
    Add(UnitName("target"), NAME_GROUP)
    for _, name in ipairs(ns.whispers) do Add(name, NAME_GROUP) end
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            Add(info and info.name, NAME_KNOWN)
        end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers then
        for i = 1, GetNumGuildMembers() do Add((GetGuildRosterInfo(i)), NAME_KNOWN) end
    end
    for word in ((GetZoneText() or "") .. " " .. (GetSubZoneText() or "")):gmatch("[%a\128-\255']+") do
        Add(word, NAME_PLACE)
    end
    for _, class in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do Add(class, NAME_PLACE) end
    return names
end

-- Beside the chat box on the side with more room, bottoms level.
-- Placing by a text box that is not chat, and finding such boxes (Fit, at the top).

-- The window a text box belongs to: its last parent before the screen.
function Fit.WindowOf(edit)
    -- Our own box laid over one of the game's (Direct.lua): that box's window.
    local frame = edit.flickFor or edit
    while true do
        local parent = frame:GetParent()
        if not parent or parent == UIParent or parent:IsForbidden() then return frame end
        frame = parent
    end
end

-- The game's own button footer for the window a text box is in (A Select, B Back under the mail window), when it
-- is up: the first frame up from the box that keeps one. Only read, never changed.
function Fit.Footer(edit)
    local frame = edit.flickFor or edit
    for _ = 1, 8 do
        frame = frame:GetParent()
        if not frame or frame == UIParent or frame:IsForbidden() then return nil end
        local footer = frame.gamepadFooter or frame.footer
        local legend = type(footer) == "table" and footer.inputLegend
        if legend and legend.IsShown and not legend:IsForbidden() and legend:IsShown() then return legend end
    end
end

-- Whether two frames lie on each other, in screen pixels; unplaced counts as no.
function Fit.Overlap(a, b)
    local sa, sb = a:GetEffectiveScale(), b:GetEffectiveScale()
    local al, ar, at, ab = a:GetLeft(), a:GetRight(), a:GetTop(), a:GetBottom()
    local bl, br, bt, bb = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
    if not (al and ar and at and ab and bl and br and bt and bb) then return false end
    return al * sa < br * sb and ar * sa > bl * sb and ab * sa < bt * sb and at * sa > bb * sb
end

-- Fit.UNDER: under the keyboard, the button bar and two lines of hint, kept clear as well.

-- A text box that is not chat (mail, a search box): the keyboard stands beside that box's window, never on it. To
-- its right if the screen has the room, else its left, else over or under it. In the screen's own units.
function Fit.ByWindow(edit)
    local window = Fit.WindowOf(edit)
    local UNDER, CLEAR = Fit.UNDER, Fit.CLEAR
    local unit = UIParent:GetEffectiveScale()
    local scale = window:GetEffectiveScale() / unit
    local left, right, top, bottom = window:GetLeft(), window:GetRight(), window:GetTop(), window:GetBottom()
    if not (left and right and top and bottom) then return false end
    left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
    local own = kb:GetScale()
    local wide, tall = kb:GetWidth() * own, kb:GetHeight() * own
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    -- The guide over the keyboard (not in the game's corner) needs its height above.
    local above = kb.guideCorner and 0 or kb.guide:GetHeight() * own + 8
    local x, y
    if screenW - right >= wide + CLEAR then
        x, y = right + CLEAR, top
    elseif left >= wide + CLEAR then
        x, y = left - CLEAR - wide, top
    elseif screenH - top >= tall + UNDER + above + CLEAR then
        x, y = left, top + CLEAR + UNDER + tall
    else
        x, y = left, bottom - CLEAR - above
    end
    x = math.max(0, math.min(screenW - wide, x))
    y = math.max(tall + UNDER, math.min(screenH - above, y))
    kb:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / own, y / own)
    return true
end

PlaceBy = function(edit)
    kb:ClearAllPoints()
    if not edit.chatFrame and Fit.ByWindow(edit) then return end
    local x = edit:GetCenter()
    local left = x and x * edit:GetEffectiveScale() < UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
    -- Beside the chat line, plus how far the player carried it (kept in screen units, whatever its size).
    local scale = kb:GetScale()
    local dx, dy = (ns.profile.moveX or 0) / scale, (ns.profile.moveY or 0) / scale
    -- Stacked (tall): its bottom corner on the chat window's own, the messages' (the typing line is under them).
    local chat = ns.Stacked() and edit.chatFrame
    if chat then
        if left then
            kb:SetPoint("BOTTOMLEFT", chat, "BOTTOMRIGHT", 12 + dx, dy)
        else
            kb:SetPoint("BOTTOMRIGHT", chat, "BOTTOMLEFT", -12 + dx, dy)
        end
        return
    end
    -- Off the typing line's top corner, with room under it for two lines of hint: those then stand beside the
    -- typing line, clear of the button bar under it.
    dy = dy + 36
    if left then
        kb:SetPoint("BOTTOMLEFT", edit, "TOPRIGHT", 12 + dx, dy)
    else
        kb:SetPoint("BOTTOMRIGHT", edit, "TOPLEFT", -12 + dx, dy)
    end
end

-- /flick chatprobe: for a while, every chat focus change and keyboard show or hide with the code that caused it,
-- plus the focus and shown state whenever it changes (FlickChatDB.chatProbe). No text is kept.
local chatProbe

local function ChatNote(text)
    if not chatProbe then return end
    local lines = chatProbe.lines
    if #lines < 2000 then lines[#lines + 1] = string.format("%.2f %s", GetTime() - chatProbe.start, text) end
end

local function Caller()
    return ((debugstack(3, 5, 0) or ""):gsub("Interface/AddOns/", ""):gsub("\n", " | "))
end

local function ChatState()
    local focus = GetCurrentKeyBoardFocus()
    local name = not focus and "none" or focus:IsForbidden() and "forbidden" or focus:GetName() or "unnamed"
    local edit = ChatFrame1EditBox
    return ("focus %s; chat 1 shown %s; its edit box shown %s, alpha %.2f; keyboard %s"):format(name,
        tostring(ChatFrame1 and ChatFrame1:IsShown()), tostring(edit and edit:IsShown()),
        edit and edit:GetAlpha() or -1, tostring(kb ~= nil and kb:IsShown()))
end

function ns.StartChatProbe(seconds)
    if chatProbe then chatProbe.ticker:Cancel() end
    local now = GetTime()
    chatProbe = { start = now, lines = {}, last = "" }
    ns.db.chatProbe = chatProbe.lines
    local ui = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    ChatNote(("start: game controller UI %s, using the pad %s"):format(tostring(ui), tostring(IsUsingGamepad())))
    chatProbe.ticker = C_Timer.NewTicker(0.1, function()
        if GetTime() - now > seconds then
            chatProbe.ticker:Cancel()
            ChatNote("end")
            chatProbe = nil
            return
        end
        local state = ChatState()
        if state ~= chatProbe.last then
            chatProbe.last = state
            ChatNote(state)
        end
    end)
end

-- What a dev addon (never shipped) needs to drive the keyboard through its own handlers. ns.dev, when a dev addon
-- sets it: lowercase (lines typed in lowercase), Send(text) (true: the line was taken, nothing is sent),
-- Opened() and Stopped().
function ns.DevTools()
    return { OnStick = OnStick, Press = Press, Unpress = Unpress, Word = Word, PrevLow = PrevLow, Guess = Guess,
        state = S, dict = D, slotKeys = SLOT_KEYS, dirDegrees = DIR_DEGREES, lesson = LESSON,
        Keyboard = function() return kb end, Box = function() return box end, PlaceBy = PlaceBy,
        Wheel = function() return wheel end }
end

-- View held, the right stick scrolls the chat window: up for older lines, faster the further it leans. The window's
-- scroll calls are the game's secure ones (ScrollingMessageFrameSecureMixin), run as its own from here.
Fit.SCROLL_LINES, Fit.SCROLL_DEAD = 20, 0.25

function Fit.ScrollChat(hold)
    local chat = box and box.chatFrame and SELECTED_CHAT_FRAME
    local now, y = GetTime(), hold.y
    local seconds = now - (hold.at or now)
    hold.at = now
    if not chat or math.abs(y) < Fit.SCROLL_DEAD then
        hold.carry = 0
        return
    end
    hold.bumper = true
    local lean = (math.abs(y) - Fit.SCROLL_DEAD) / (1 - Fit.SCROLL_DEAD)
    hold.carry = hold.carry + (y > 0 and 1 or -1) * lean * lean * Fit.SCROLL_LINES * seconds
    local whole = hold.carry > 0 and math.floor(hold.carry) or math.ceil(hold.carry)
    if whole == 0 then return end
    local before = chat:GetScrollOffset()
    chat:ScrollByAmount(whole)
    -- at either end the lean is not saved up
    hold.carry = chat:GetScrollOffset() == before and 0 or hold.carry - whole
end

-- View and the right stick scroll: the View icon in the middle of the chat window's left button column, empty in
-- the game's own window (its arrows are on the scroll bar), the stick pushed up over it and pushed down under it.
-- The game hides that column in its controller interface: placed by screen position, the same in both. Gone under a
-- settings box, in the preview, and with the button bar when the player hid that.
function Fit.ScrollMarks(hidden)
    local marks = kb.scrollMarks
    if not marks then
        marks = CreateFrame("Frame", nil, kb)
        marks:Hide()
        marks:SetIgnoreParentScale(true)
        marks:SetAllPoints(UIParent)
        for _, key in ipairs({ "view", "up", "down" }) do marks[key] = { icon = marks:CreateTexture(nil, "ARTWORK") } end
        -- the stick's art fills under half its square (room for the arrow): drawn larger, its empty edge tucked in
        marks.up.icon:SetPoint("BOTTOM", marks.view.icon, "TOP", 0, -5)
        marks.down.icon:SetPoint("TOP", marks.view.icon, "BOTTOM", 0, 5)
        kb.scrollMarks = marks
    end
    local chat = box and box.chatFrame
    if hidden or S.preview or not chat or not chat:GetTop() then return marks:Hide() end
    local scale = UIParent:GetEffectiveScale()
    marks:SetScale(scale)
    marks:SetFrameStrata(kb:GetFrameStrata())
    -- the column's middle when it has a place, else as far left of the window as it stands
    local column, x = chat.buttonFrame
    if type(column) == "table" and column.GetCenter and column:GetCenter() then
        x = column:GetCenter() * column:GetEffectiveScale() / scale
    else
        x = chat:GetLeft() * chat:GetEffectiveScale() / scale - 16
    end
    local middle = (chat:GetTop() + chat:GetBottom()) / 2 * chat:GetEffectiveScale() / scale
    SetIcon(marks.view, "PADBACK")
    SetIcon(marks.up, "PADRSTICKUP")
    SetIcon(marks.down, "PADRSTICKDOWN")
    marks.view.icon:SetSize(GUIDE_ICON, GUIDE_ICON)
    for _, stick in ipairs({ marks.up, marks.down }) do stick.icon:SetSize(GUIDE_ICON * 2.2, GUIDE_ICON * 2.2) end
    marks.view.icon:ClearAllPoints()
    marks.view.icon:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, middle)
    marks:Show()
end

-- LT and RT down together type "/". A trigger that acted on its press has that taken back when the other comes
-- within CHORD seconds; a modifier trigger's tap, which comes on letting go, is dropped after a chord.
Fit.CHORD = 0.3
Fit.SNAP = { "committed", "flicks", "literal", "undo", "autoSpace", "symbols", "box", "shown", "exact" }
Fit.trig = { PADLTRIGGER = { at = 0 }, PADRTRIGGER = { at = 0 } }

function Fit.Chordable()
    return box and not (S.move or S.wheel or S.forget or S.phrases or S.naming or S.lesson or S.joinWait
        or S.preview or kb.viewHold)
end

function Fit.TriggerDown(button)
    local t = Fit.trig[button]
    local other = Fit.trig[button == "PADLTRIGGER" and "PADRTRIGGER" or "PADLTRIGGER"]
    t.down, t.at, t.snap, t.swallow = true, GetTime(), nil, nil
    if S.chord or not other.down or t.at - other.at > Fit.CHORD or not Fit.Chordable() then return false end
    local snap = other.snap
    if snap then
        for _, key in ipairs(Fit.SNAP) do S[key] = snap[key] end
        Guess()
        if snap.flicks ~= "" then S.shown = math.max(1, math.min(snap.shown or 1, #S.stems)) end
    end
    StopHold()
    S.chord = true
    for _, each in pairs(Fit.trig) do each.swallow = each.modifier or nil end
    TypeSymbol("/")
    return true
end

function Fit.TriggerUp(button)
    Fit.trig[button].down = false
    if not Fit.trig.PADLTRIGGER.down and not Fit.trig.PADRTRIGGER.down then S.chord = nil end
end

-- A trigger's press as the keyboard hears it: true when it is spent (a chord, or a modifier's tap after one).
function Fit.Trigger(button)
    local t = Fit.trig[button]
    if t.modifier then
        local spent = t.swallow
        t.swallow = nil
        return spent or false
    end
    if Fit.TriggerDown(button) then return true end
    local snap = {}
    for _, key in ipairs(Fit.SNAP) do snap[key] = S[key] end
    t.snap = snap
    return false
end

-- Outside the game's controller interface its settings can make LT and RT modifier keys (Shift and Ctrl by
-- default): a tap then comes as a press and release together on letting go, and a hold never comes at all
-- (/flick sticks, 2026-11-16). While the keyboard is up such a trigger is read off the pad itself.
function Fit.WatchLT()
    if Fit.ltTicker then Fit.ltTicker:Cancel() end
    Fit.ltTicker, S.ltModifier, S.ltQuiet, S.chord = nil, nil, nil, nil
    local padUI = InputUtil ~= nil and InputUtil.IsGamepadUIEnabled()
    local watched = {}
    for key, t in pairs(Fit.trig) do
        t.index, t.down, t.at, t.snap, t.swallow = C_GamePad.ButtonBindingToIndex(key), false, 0, nil, nil
        t.modifier = t.index ~= nil and not padUI and (C_CVar.GetCVar("GamePadEmulateShift") == key
            or C_CVar.GetCVar("GamePadEmulateCtrl") == key or C_CVar.GetCVar("GamePadEmulateAlt") == key)
        if t.modifier then watched[#watched + 1] = t end
    end
    if #watched == 0 then return end
    S.ltModifier = Fit.trig.PADLTRIGGER.modifier or nil
    local index = Fit.trig.PADLTRIGGER.index
    local since, nextAt
    Fit.ltTicker = C_Timer.NewTicker(0.05, function()
        if not box or not kb:IsShown() then
            Fit.ltTicker:Cancel()
            Fit.ltTicker, S.ltModifier = nil, nil
            return
        end
        local state = C_GamePad.GetDeviceMappedState()
        local now = GetTime()
        -- the list counts from 1, the game's button index from 0
        for key, t in pairs(Fit.trig) do
            local down = t.modifier and state and state.buttons[t.index + 1] or false
            if t.modifier and down and not t.down then
                Fit.TriggerDown(key)
            elseif t.modifier and t.down and not down then
                Fit.TriggerUp(key)
            end
        end
        if not S.ltModifier or not (state and state.buttons[index + 1]) or S.chord or kb.viewHold or S.move
            or S.wheel or S.forget or S.phraseSave then
            since, nextAt = nil, nil
            return
        end
        since = since or now
        nextAt = nextAt or since + HOLD_DELAY
        if now >= nextAt then
            if probe then Note("LT held, read off the pad") end
            DeleteWord()
            nextAt = nextAt + HOLD_REPEAT
        end
        if nextAt > since + HOLD_DELAY then S.ltQuiet = now + 0.3 end
    end)
end

local function Open(edit)
    S.preview = nil
    if not kb then Build() end
    D.Build()
    LESSON.Use(D.Code())
    box = edit
    S.names = Names()
    D.Refresh(S.names)
    local text = edit:GetText()
    S.lesson = not ns.db.lessonDone and { at = 1, peaks = {} } or nil
    local back = draft and edit.chatFrame and text == "" and not S.lesson and not ns.dev and not ns.practiceNext
    if back then text, draft = draft, nil end
    Reset(text)
    S.openedText = text
    -- A numbers-only box (a price, an amount) opens on the digits.
    if not edit.chatFrame and edit.IsNumeric and edit:IsNumeric() then S.symbols = true end
    S.draftBack = back or nil
    ns.Restyle()
    kb.bar:ClearAllPoints()
    kb.barCover:Hide()
    kb.barOver = nil
    if edit.chatFrame then
        kb.bar:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -2)
    else
        -- In the place of the window's own button footer, as under chat: those buttons are the keyboard's while
        -- it is up. The game's footer is not touched; a dark backing of ours lies over all of it. A window with
        -- no footer: under the keyboard (under the box the bar would lie on the box's own window).
        local legend = Fit.Footer(edit)
        if legend then
            kb.barOver = legend
            kb.bar:SetPoint("LEFT", legend, "LEFT", 0, 0)
            kb.barCover:ClearAllPoints()
            kb.barCover:SetAllPoints(legend)
            kb.barCover:Show()
        else
            kb.bar:SetPoint("TOPLEFT", kb, "BOTTOMLEFT", 0, -2)
        end
    end
    -- Under chat, in front of the action bars. Held on screen: where that pushes it up into the chat, behind the
    -- chat, as the game's own chat buttons.
    local chat = edit.chatFrame or edit:GetParent()
    if not edit.chatFrame then
        kb.bar:SetFrameStrata("TOOLTIP")
    elseif (edit:GetBottom() or 0) * edit:GetEffectiveScale() >= (BAR_H + 2) * UIParent:GetEffectiveScale() then
        kb.bar:SetFrameStrata("DIALOG")
    elseif chat and not chat:IsForbidden() then
        kb.bar:SetFrameStrata(chat:GetFrameStrata())
        kb.bar:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
    end
    -- Over a settings box it stands above the game's controller cursor, which marks the window under it.
    kb:SetFrameStrata(edit.chatFrame and "DIALOG" or "TOOLTIP")
    kb:Show()
    Fit.WatchLT()
    GameChatButtons(edit)
    PlaceGuide()
    -- The guide in the game's corner would lie on a window standing there: over the keyboard then.
    if not edit.chatFrame and kb.guideCorner and Fit.Overlap(kb.guide, Fit.WindowOf(edit)) then
        kb.guideCorner = false
        kb.guide:ClearAllPoints()
        kb.guide:SetPoint("BOTTOMLEFT", kb, "TOPLEFT", 0, 4)
    end
    -- Once the guide has its place: the keyboard's own depends on it.
    PlaceBy(edit)
    kb.hintLift = nil
    Guess()
    Show()
    if ns.moveNext and edit.chatFrame and not S.lesson then
        local guide = ns.moveNext == "guide"
        ns.moveNext = nil
        Move.Start(guide)
    end
    if ns.practiceNext and edit.chatFrame and not S.lesson then
        ns.practiceNext = nil
        ns.StartPractice(edit)
    end
    if ns.dev and ns.dev.Opened then ns.dev.Opened() end
end

-- The window the preview hangs under goes up by what the keyboard lacks in room under it, as far as the screen's
-- top lets it. Fit.lift: the window's own way up, given with it (lift(0) is its place); without one it stays.
Fit.PREVIEW_GAP = 44
function ns.SeatPreview()
    local under, lift = S.preview, Fit.lift
    if not lift then return end
    lift(0)
    local unit = under:GetEffectiveScale()
    local bottom, top = under:GetBottom(), under:GetTop()
    if not (bottom and top) then return end
    local need = (Fit.PREVIEW_GAP + kb:GetHeight()) * kb:GetEffectiveScale() / unit + 8
    local spare = UIParent:GetHeight() * UIParent:GetEffectiveScale() / unit - top - 8
    if need > bottom then lift(math.max(0, math.min(need - bottom, spare))) end
end

-- The keyboard as a picture of itself under a window (the first-login notice's size picker): at the player's
-- size, a few words over the d-pad, no pad input taken. Called again with nothing, it goes.
function ns.PreviewKeyboard(under, lift)
    if not under then
        if S.preview then
            S.preview, Fit.lift = nil, nil
            if kb and not box then kb:Hide() end
        end
        return
    end
    if not kb then Build() end
    -- Not while chat is really being typed in. A chat box left set with the keyboard hidden (an open that never
    -- finished) is let go, and so is a lesson left unfinished: the preview is the bare keyboard.
    if box and kb:IsShown() then return end
    box, S.lesson = nil, nil
    D.Build()
    D.Refresh()
    S.preview, Fit.lift = under, lift
    Reset("")
    S.slots = D.Next("<s>")
    kb:ClearAllPoints()
    kb:SetPoint("TOP", under, "BOTTOM", 0, -Fit.PREVIEW_GAP)
    kb:SetFrameStrata("FULLSCREEN_DIALOG")
    ns.Restyle()
    kb:Show()
    Paint()
end

function ns.Shut()
    if ns.practice then ns.practice.Stop() end
    if kb then kb:Hide() end
end

-- Each chat box: the keyboard comes with its typing focus while the controller is in use, and goes with it. Focus,
-- not showing: with the IM chat style the box never hides, it only fades.
local edits = {}

-- IM style leaves an unused typing line faded in sight; with the player's box ticked it goes out of sight, as
-- Classic style's does. Alpha only: showing or hiding a chat box from our code is refused in controller mode.
local IM_FADED = 0.35

local function FadeLine(edit)
    if edit:HasFocus() or GetCVar("chatStyle") ~= "im" then return end
    edit:SetAlpha(ns.profile.hideLine and 0 or IM_FADED)
end

function ns.FadeLines()
    for edit in pairs(edits) do
        if edit.chatFrame then FadeLine(edit) end
    end
end

local function Watch(edit)
    edits[edit] = true
    edit:HookScript("OnEditFocusGained", function()
        if chatProbe then ChatNote(("%s gained focus (pad %s) by %s"):format(edit:GetName() or "box",
            tostring(IsUsingGamepad()), Caller())) end
        -- A chat box still set with the keyboard hidden is a leftover (an open that did not finish): open anew.
        local function Try()
            if ns.profile.enabled and IsUsingGamepad() and edit:HasFocus() and (box ~= edit or not kb or not kb:IsShown()) then
                Open(edit)
            end
        end
        Try()
        -- Chat opened by a pad press right after the keys were in use: the game says "controller" a moment later.
        C_Timer.After(0.15, Try)
    end)
    edit:HookScript("OnEditFocusLost", function()
        if edit.chatFrame then C_Timer.After(0, function() FadeLine(edit) end) end
        if chatProbe then ChatNote(("%s lost focus by %s"):format(edit:GetName() or "box", Caller())) end
        if box == edit then ns.Shut() end
    end)
end

ns.Watch = Watch

-- The controller picked up while a chat box has focus: the keyboard comes up then.
function ns.PadActive(active)
    if not active or not ns.profile.enabled or (box and kb and kb:IsShown()) then return end
    local focus = GetCurrentKeyBoardFocus()
    if focus and edits[focus] then Open(focus) end
end

-- Any other text box the controller is put in (mail, the auction house's search, a name asked in a dialog): the
-- keyboard comes up for it as for chat. Such a box takes the typing focus by the game's own controller cursor, with
-- no word to an addon, so the focus is looked at ten times a second, only while that cursor is up. Nothing is
-- hooked on such a box: a script of ours on a box inside a window the game's cursor walks would run in the
-- middle of that walk, and the game then refuses the cursor's next step as an addon's. Fit.loose: the box the
-- keyboard is up for this way.
function Fit.Seek()
    ns.DirectCheck()
    local focus = GetCurrentKeyBoardFocus()
    if Fit.loose then
        -- It let go, or its window went.
        if box == Fit.loose and focus == box then return end
        local was = Fit.loose
        Fit.loose = nil
        if box == was then return ns.Shut() end
    end
    if not ns.profile.enabled or not IsUsingGamepad() then return end
    if not focus or edits[focus] or focus == box or focus == ns.addressBox or focus:IsForbidden()
        or not focus:IsObjectType("EditBox") then return end
    -- A box whose text the game must never get from an addon (Direct.lua): typed into a box of ours over it,
    -- or left alone.
    local direct = ns.DirectFor(focus, Fit.WindowOf(focus))
    if direct == false then return end
    if direct then return ns.DirectOpen(focus, direct) end
    Fit.loose = focus
    Open(focus)
end

function Fit.SeekBoxes(on)
    if Fit.seeker then
        Fit.seeker:Cancel()
        Fit.seeker = nil
    end
    if on then
        Fit.seeker = C_Timer.NewTicker(0.1, Fit.Seek)
    else
        -- The cursor went (the window shut): the keyboard and our own box over a box go with it.
        ns.DirectCheck(true)
        local was = Fit.loose
        Fit.loose = nil
        if was and box == was then ns.Shut() end
    end
end

function ns.Ready()
    local cursor = SmartNavigation
    if cursor and cursor.HookScript then
        cursor:HookScript("OnShow", function() Fit.SeekBoxes(true) end)
        cursor:HookScript("OnHide", function() Fit.SeekBoxes(false) end)
        if cursor:IsShown() then Fit.SeekBoxes(true) end
    end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit then Watch(edit) end
    end
    if ns.profile.hideLine then ns.FadeLines() end
    -- A tab picked shows its own typing line faded again: after the game's pick, ours go out of sight once more.
    if FCFDock_SelectWindow then
        hooksecurefunc("FCFDock_SelectWindow", function()
            C_Timer.After(0, function()
                ns.FadeLines()
                if kb and kb.viewHold then
                    Fit.TabFollow()
                    Fit.TabTargets()
                end
            end)
        end)
    end
end
