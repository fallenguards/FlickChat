local addonName, ns = ...

-- Strings: each locale file fills its own table and ns.locale picks one; a missing one shows English, never its key.
ns.locales, ns.locale = {}, GetLocale()
ns.L = setmetatable({}, { __index = function(_, key)
    local own = ns.locales[ns.locale]
    return own and own[key] or ns.EN and ns.EN[key] or key
end })

-- Lua's lower and upper leave accented letters as they are: these know the Latin ones (two bytes, the first 195;
-- the oe ligature and the y with dots have 197's).
local UTF8 = "[%z\1-\127\194-\244][\128-\191]*"
local function Shift(by) return function(c) return "\195" .. string.char(c:byte() + by) end end
local DownOne, UpOne = Shift(32), Shift(-32)

function ns.Lower(text)
    text = text:lower()
    if not text:find("[\195\197]") then return text end
    return (text:gsub("\195([\128-\150\152-\158])", DownOne):gsub("\197\146", "\197\147"):gsub("\197\184", "\195\191"))
end

function ns.Upper(text)
    text = text:upper()
    if not text:find("[\195\197]") then return text end
    return (text:gsub("\195([\160-\182\184-\190])", UpOne):gsub("\197\147", "\197\146"):gsub("\195\191", "\197\184"))
end

function ns.Capital(word)
    local first = word:match("^" .. UTF8)
    return first and ns.Upper(first) .. word:sub(#first + 1) or word
end

-- Typing languages. English's words are the addon's own; each other language's are a load-on-demand folder
-- beside it (FlickChat_ptBR), which hands them over with FlickChat_AddWords as it loads.
-- New ones go last: the login note names those past the ones it has told.
ns.LANGUAGES = { "enUS", "ptBR", "frFR", "deDE", "itIT", "esES" }
ns.LANGUAGE_NAMES = { enUS = "English", ptBR = "Português", frFR = "Français", deDE = "Deutsch", itIT = "Italiano",
    esES = "Español" }
-- A game language typed with another's words: Latin American Spanish with Spanish's.
local SAME_WORDS = { esMX = "esES" }
local function GameLanguage() return SAME_WORDS[ns.locale] or ns.locale end
ns.wordLists = {}
function FlickChat_AddWords(code, data) ns.wordLists[code] = data end
local LoadAddOn = C_AddOns.LoadAddOn

-- learned: word -> times sent; pairs: "word next" -> times ("<s>" starts a message); forms: a word's own capitals;
-- uses: how often each hint's action was used (a hint goes once learned); arm/rearm: a flick's tilt out and back;
-- phrases: the player's own quick phrases by slot (an empty slot is the language's default).
-- language: the language typed in (none: the game's own); wordsOf: whose learned words the four tables above
-- are; others: the other languages' learned words, by language.
local DEFAULTS = { enabled = true, learned = {}, pairs = {}, forms = {}, forgot = {}, uses = {}, layout = "letters", size = 100,
    arm = 0.55, rearm = 0.3, lessonDone = false, phrases = {}, wheelSize = 100, wordRoom = 100, others = {} }
local DB_VERSION = 2
local LEARN_CAP, PAIR_CAP = 2000, 4000
local WHISPERS_KEPT = 10

ns.whispers = {}

-- 0 (the ring keyboard) carries over as is: its learned counts keep their meaning.
function ns.Migrate(db)
    if (db.dbVersion or 0) < 2 then
        -- languagesTold was a plain yes for the first five; now how many of LANGUAGES the login note has named
        if db.languagesTold == true then db.languagesTold = 5 end
        -- a Spanish game typed with English's list before Spanish had one: what it learned there is Spanish
        if GameLanguage() == "esES" and not db.language and db.wordsOf == "enUS" then db.wordsOf = "esES" end
    end
    db.dbVersion = DB_VERSION
end

-- Login notes: the typing languages, once; a newer version heard from someone in the guild or group, at each
-- login until this one is as new (forgotten after a month unheard).
local PREFIX, UPDATE_URL, HEARD_FOR = "FlickChat", "curseforge.com/wow/addons/flickchat", 30 * 86400
local OWN_VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
local SendAddonMessage, InLockdown = C_ChatInfo.SendAddonMessage, C_ChatInfo.InChatMessagingLockdown
local updateTold, announced, grouped = false, 0, 0

local function VersionNumber(version)
    local major, minor, patch = (version or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    return major and major * 1e6 + minor * 1e3 + patch
end

-- told: how many of LANGUAGES an earlier note named (none: all but English).
function ns.SayLanguages(told)
    local names = {}
    for i = (told or 1) + 1, #ns.LANGUAGES do names[#names + 1] = ns.LANGUAGE_NAMES[ns.LANGUAGES[i]] end
    ns.Say(ns.L["NEWS_LANGUAGES"]:format(table.concat(names, ", ")))
end

-- In red after the addon's blue name: the one note that asks the player to act.
function ns.SayUpdate(newest)
    ns.Say("|cffff4040" .. ns.L["UPDATE_OUT"]:format(newest, OWN_VERSION, UPDATE_URL) .. "|r")
end

-- Another player's version, as their addon sent it: a newer one is said once a session.
local function Heard(version)
    local db = ns.db
    local theirs, mine = VersionNumber(version), VersionNumber(OWN_VERSION)
    if not theirs or not mine or theirs <= mine then return end
    db.newestAt = time()
    if theirs > (VersionNumber(db.newest) or 0) then db.newest = version end
    if not updateTold then
        updateTold = true
        ns.SayUpdate(db.newest)
    end
end

-- This version to the group, and at login to the guild.
local function Announce(guild)
    if InLockdown and InLockdown() then return end
    announced = GetTime()
    local message = "v" .. OWN_VERSION
    if guild and IsInGuild() then SendAddonMessage(PREFIX, message, "GUILD") end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SendAddonMessage(PREFIX, message, "INSTANCE_CHAT")
    elseif IsInGroup() then
        SendAddonMessage(PREFIX, message, IsInRaid() and "RAID" or "PARTY")
    end
end

function ns.LoginNotes()
    local db = ns.db
    local told = db.languagesTold or 1
    if told < #ns.LANGUAGES then
        db.languagesTold = #ns.LANGUAGES
        ns.SayLanguages(told)
    end
    local newest, mine = VersionNumber(db.newest), VersionNumber(OWN_VERSION)
    if newest and mine and newest > mine and time() - (db.newestAt or 0) < HEARD_FOR then
        updateTold = true
        ns.SayUpdate(db.newest)
    else
        db.newest, db.newestAt = nil, nil
    end
    Announce(true)
end

ns.events = CreateFrame("Frame")
ns.events:RegisterEvent("ADDON_LOADED")
-- The game's controller menu opens chat by a chat window's own SetGamepadFocus. An addon that replaced it (some
-- chat addons empty it) leaves the menu's Chat doing nothing, and the keyboard never opens: said once a session,
-- naming the addon the game itself blames for the changed function.
local wheelTold = false
local function WarnWheelOff()
    local mixin = FloatingChatFrameMixin
    local own = mixin and mixin.SetGamepadFocus
    local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    if wheelTold or not own or not controller or not ns.db.enabled then return end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chat = _G["ChatFrame" .. i]
        if chat and chat.SetGamepadFocus ~= own then
            local _, by = issecurevariable(chat, "SetGamepadFocus")
            wheelTold = true
            -- In red: nothing of the keyboard works until that addon is off.
            return ns.Say("|cffff4040" .. ns.L["WHEEL_CHAT_OFF"]:format(by or ns.L["ANOTHER_ADDON"]) .. "|r")
        end
    end
end

-- Every new player once at login, whatever the game's interface setting: the keyboard's size and shape. And the
-- chat style when it is the one the keyboard cannot open in, at each login until changed.
local function Welcome()
    if ns.db.welcomed and not ns.NeedsIMStyle() then return end
    -- the window holds a secure button: a fight waits
    if InCombatLockdown() then return ns.events:RegisterEvent("PLAYER_REGEN_ENABLED") end
    ns.StyleNotice()
end

ns.events:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        Welcome()
        return
    end
    if event == "GAME_PAD_ACTIVE_CHANGED" then
        if ns.PadActive then ns.PadActive(arg1) end
        -- The controller picked up after login: looked at again then.
        if arg1 then C_Timer.After(1, WarnWheelOff) end
        return
    end
    if event == "CHAT_MSG_ADDON" then
        if arg1 == PREFIX and type(arg2) == "string" and not (issecretvalue and issecretvalue(arg2)) then
            Heard(arg2:match("^v(.+)$"))
        end
        return
    end
    if event == "GROUP_ROSTER_UPDATE" then
        -- Someone new in the group hears this version too, ten seconds apart at the least.
        local count = GetNumGroupMembers()
        if count > grouped and GetTime() - announced > 10 then Announce() end
        grouped = count
        return
    end
    if event == "PLAYER_LOGIN" then
        C_Timer.After(8, ns.LoginNotes)
        -- A pad chord an earlier build bound to Open Chat is let go (the game's controller mode opens chat itself).
        local db = ns.db
        if db.chatChord and not InCombatLockdown() then
            if GetBindingAction(db.chatChord) == "OPENCHAT" then
                SetBinding(db.chatChord)
                SaveBindings(GetCurrentBindingSet())
            end
            db.chatChord, db.chatChordOffered = nil, nil
        end
        -- The same for the button the settings once put on Open Chat: the game's controller mode never reads it.
        if db.chatKey and not InCombatLockdown() then
            if GetBindingAction(db.chatKey) == "OPENCHAT" then
                SetBinding(db.chatKey)
                SaveBindings(GetCurrentBindingSet())
            end
            db.chatKey = nil
        end
        -- The game's controller mode shows chat's typing line only with the IM chat style: a notice says so.
        db.imStyleTold = nil
        Welcome()
        -- Other addons set their chat windows up as they log in too: looked at once they have.
        C_Timer.After(5, WarnWheelOff)
        return
    end
    if event == "CHAT_MSG_WHISPER" then
        local name = type(arg2) == "string" and not (issecretvalue and issecretvalue(arg2)) and arg2:match("^[^%-]+")
        if name then
            for i = #ns.whispers, 1, -1 do
                if ns.whispers[i] == name then table.remove(ns.whispers, i) end
            end
            table.insert(ns.whispers, 1, name)
            ns.whispers[WHISPERS_KEPT + 1] = nil
        end
        return
    end
    if event ~= "ADDON_LOADED" or arg1 ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    FlickChatDB = FlickChatDB or {}
    local db = FlickChatDB
    ns.Migrate(db)
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = type(value) == "table" and {} or value end
    end
    ns.db = db
    -- the dev addon's /fcdev locale: the addon as on another language's game
    if db.devLocale then ns.locale = db.devLocale end
    if ns.ListOptions then ns.ListOptions() end
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    if ns.Ready then ns.Ready() end
end)

-- The language the player types in: their pick, else the game's own where there is a list for it.
function ns.WantedLanguage()
    local code = ns.db.language or GameLanguage()
    return ns.LANGUAGE_NAMES[code] and code or "enUS"
end

-- The saved learned words are one language's at a time; another's turn puts these aside and brings its own.
local OWN = { "learned", "pairs", "forms", "forgot" }
local function OwnWords(code)
    local db = ns.db
    if db.wordsOf == code then return end
    -- Words learned before languages were kept apart stay with the first one typed in.
    if not db.wordsOf then
        db.wordsOf = code
        return
    end
    local away = {}
    for _, key in ipairs(OWN) do away[key] = db[key] end
    db.others[db.wordsOf] = away
    local back = db.others[code] or {}
    for _, key in ipairs(OWN) do db[key] = back[key] or {} end
    db.others[code], db.wordsOf = nil, code
end

local function Loaded(code)
    if code ~= "enUS" and not ns.wordLists[code] then LoadAddOn("FlickChat_" .. code) end
    return code == "enUS" or ns.wordLists[code] ~= nil
end

-- The language whose words are there to type with: the wanted one, its folder loaded; English where that
-- folder is missing or switched off (said once).
local missing = {}
function ns.TypingLanguage()
    local code = ns.WantedLanguage()
    if not Loaded(code) then
        if not missing[code] then
            missing[code] = true
            ns.Say(ns.L["LANG_MISSING"]:format(ns.LANGUAGE_NAMES[code], "FlickChat_" .. code))
        end
        code = "enUS"
    end
    OwnWords(code)
    return code
end

-- The settings row: on to the next language whose words are there.
function ns.NextLanguage()
    local at = 1
    for i, code in ipairs(ns.LANGUAGES) do
        if code == ns.WantedLanguage() then at = i end
    end
    for step = 1, #ns.LANGUAGES do
        local code = ns.LANGUAGES[(at + step - 1) % #ns.LANGUAGES + 1]
        if Loaded(code) then
            -- the game's own language is no pick: it is followed
            if code == GameLanguage() then ns.db.language = nil else ns.db.language = code end
            break
        end
    end
    if ns.Relanguage then ns.Relanguage() end
end

function ns.LanguageName() return ns.LANGUAGE_NAMES[ns.WantedLanguage()] end

-- Over its cap a count table halves: rare entries go, the player's habits stay.
local function Trim(counts, cap)
    local n = 0
    for _ in pairs(counts) do n = n + 1 end
    if n <= cap then return end
    for key, count in pairs(counts) do
        counts[key] = count > 1 and math.floor(count / 2) or nil
    end
end

-- A word dropped off the d-pad: its counts go and it is never guessed, until the player spells it out again.
function ns.Forget(word)
    local db, low = ns.db, ns.Lower(word)
    db.forgot[low] = true
    db.learned[low], db.forms[low] = nil, nil
    for pair in pairs(db.pairs) do
        local prev, after = pair:match("^(%S+) (%S+)$")
        if prev == low or after == low then db.pairs[pair] = nil end
    end
end

-- The keyboard's place and size: set with the sticks the next time it opens.
function ns.MoveNext(button)
    ns.moveNext = true
    ns.Tell(ns.L["MOVE_NEXT"], button)
end

function ns.ForgottenBack()
    wipe(ns.db.forgot)
    ns.Say(ns.L["FORGOT_BACK"])
end

-- A sent message's words and word pairs, so guesses learn the player's words and how they follow each other.
function ns.Learn(text)
    local db = ns.db
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h.-|h", " "):gsub("{.-}", " ")
    local prev, first = "<s>", true
    for word in text:gmatch("[%a\128-\255']+") do
        word = word:gsub("^'+", ""):gsub("'+$", "")
        if word ~= "" then
            local low = ns.Lower(word)
            if not first and word ~= low and not ns.Dict.Known(low) then db.forms[low] = word end
            db.learned[low] = (db.learned[low] or 0) + 1
            local pair = prev .. " " .. low
            db.pairs[pair] = (db.pairs[pair] or 0) + 1
            prev, first = low, false
        end
    end
    Trim(db.learned, LEARN_CAP)
    Trim(db.pairs, PAIR_CAP)
end

-- The addon's own blue, its icon's: its name in chat and on its windows.
ns.BLUE = { 0.18, 0.56, 0.90 }
function ns.Say(text) print("|cff2e8fe6" .. ns.L["TITLE"] .. "|r " .. text) end

-- What a settings button set going: a chat line, and the pressed button's own text says it where the player is
-- looking. Never a dialog: a StaticPopup shown by addon code over the Settings window leaves the game's
-- controller bindings tainted, and closing the window is then refused.
function ns.Tell(text, button)
    ns.Say(text)
    if button and button.SetText then button:SetText(ns.L["OPT_ARMED"]) end
end

-- Quick phrases by slot (1-4 the left stick's up, right, down, left; 5-8 the right's): the player's own, else the
-- language's default. A phrase emptied or set back to its default is the default again.
local function DefaultPhrase(slot)
    local i = 0
    for phrase in ns.L["PHRASES"]:gmatch("[^|]+") do
        i = i + 1
        if i == slot then return phrase end
    end
end

function ns.Phrase(slot) return ns.db.phrases[slot] or DefaultPhrase(slot) end

function ns.SetPhrase(slot, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" or text == DefaultPhrase(slot) then text = nil end
    ns.db.phrases[slot] = text
end

function ns.ResetPhrases() wipe(ns.db.phrases) end

-- In the game's controller mode its Menu wheel's Chat shows the typing line (and so the keyboard) only with the IM
-- chat style; with Classic nothing opens, the game's own chat included.
function ns.NeedsIMStyle()
    local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    return controller == true and GetCVar("chatStyle") ~= "im"
end

-- What the settings window (Options.lua) and the first-login notice keep.
local options = {}

local function HidesBar() return ns.db.hintsToggle == nil or ns.db.hintsToggle == "bar" end
local function HidesGuide() return ns.db.hintsToggle == nil or ns.db.hintsToggle == "guide" end

local function SetHides(bar, guide)
    if bar and guide then
        ns.db.hintsToggle = nil
    else
        ns.db.hintsToggle = bar and "bar" or guide and "guide" or "none"
    end
end

-- What each row reads and writes, over the saved settings' own shapes (nil for off, the hidden flag turned round).
local ROWS = {
    lowercase = { function() return ns.db.lowercase == true end, function(on) ns.db.lowercase = on or nil end },
    -- What the right stick press hides: hintsToggle is nil for both, "bar", "guide" or "none".
    -- IM style's typing line out of sight until chat opens, as Classic style's is.
    hideLine = { function() return ns.db.hideLine == true end, function(on)
        ns.db.hideLine = on or nil
        if ns.FadeLines then ns.FadeLines() end
    end },
    stickTips = { function() return not ns.db.stickTipsOff end, function(on)
        if on then ns.db.stickTipsOff = nil else ns.db.stickTipsOff = true end
    end },
    phraseSend = { function() return not ns.db.phraseFill end, function(on)
        if on then ns.db.phraseFill = nil else ns.db.phraseFill = true end
    end },
    matureFilter = { function() return ns.db.matureFilter == true end, function(on) ns.db.matureFilter = on or nil end },
    hideBar = { function() return HidesBar() end, function(on) SetHides(on, HidesGuide()) end },
    hideGuide = { function() return HidesGuide() end, function(on) SetHides(HidesBar(), on) end },
    size = { function() return ns.db.size end, function(value)
        ns.db.size = value
        if ns.Restyle then ns.Restyle() end
    end },
    wordRoom = { function() return ns.db.wordRoom end, function(value)
        ns.db.wordRoom = value
        if ns.Restyle then ns.Restyle() end
    end },
    wheelSize = { function() return ns.db.wheelSize end, function(value) ns.db.wheelSize = value end },
}
ns.optionRows = ROWS

-- The keyboard's shape: wide (a stick either side of the guess words, no pick saved), or stacked, the sticks side
-- by side with the words over them ("above") or under them ("below").
function ns.Stacked()
    local shape = ns.db.shape
    return (shape == "above" or shape == "below") and shape or nil
end

function ns.ShapeName()
    local shape = ns.Stacked()
    return ns.L[shape == "above" and "SHAPE_ABOVE" or shape == "below" and "SHAPE_BELOW" or "SHAPE_WIDE"]
end

function ns.NextShape()
    local shape = ns.Stacked()
    if shape == "above" then
        ns.db.shape = "below"
    elseif shape == "below" then
        ns.db.shape = nil
    else
        ns.db.shape = "above"
    end
    if ns.Restyle then ns.Restyle() end
end

-- The player's own words for the guesses: letters and apostrophes, a space between, each once.
function ns.SetMyWords(text)
    local seen, list = {}, {}
    for word in text:gmatch("[%a\128-\255']+") do
        if not seen[ns.Lower(word)] and #list < 60 then
            seen[ns.Lower(word)] = true
            list[#list + 1] = word
        end
    end
    ns.db.myWords = #list > 0 and table.concat(list, " ") or nil
end

function ns.MyWordsText()
    local words = ns.db.myWords
    return words and words ~= "" and words or ns.L["WORDS_NONE"]
end

-- One box for whichever phrase row was pressed: exactly over that row's button and opaque, so the phrase is typed
-- in the button's place.
local function EditPhrase(button, slot)
    local edit = options.phraseEdit
    if not edit then
        edit = CreateFrame("EditBox", nil, UIParent)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(120)
        edit:SetFrameStrata("TOOLTIP")
        edit:SetFontObject(GameFontHighlight)
        edit:SetTextInsets(8, 8, 0, 0)
        local rim = edit:CreateTexture(nil, "BACKGROUND", nil, -2)
        rim:SetAllPoints()
        rim:SetColorTexture(1, 0.82, 0, 1)
        local fill = edit:CreateTexture(nil, "BACKGROUND", nil, -1)
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(0.05, 0.05, 0.06, 1)
        edit:SetScript("OnEnterPressed", function(self)
            if self.slot == "words" then
                ns.SetMyWords(self:GetText())
            else
                ns.SetPhrase(self.slot, self:GetText())
            end
            if self.button:IsVisible() then self.button:SetText(self.shows()) end
            self:Hide()
        end)
        edit:SetScript("OnEscapePressed", edit.Hide)
        edit:SetScript("OnEditFocusLost", edit.Hide)
        -- Our own box: its Enter saves and its Escape drops, as the keyboard's A and B press them.
        edit.flickOwn = true
        ns.Watch(edit)
        options.phraseEdit = edit
    end
    edit.slot, edit.button = slot, button
    edit.shows = slot == "words" and ns.MyWordsText or function() return ns.Phrase(slot) or "" end
    edit:SetMaxLetters(slot == "words" and 400 or 120)
    edit:ClearAllPoints()
    edit:SetAllPoints(button)
    edit:SetText(slot == "words" and (ns.db.myWords or "") or ns.Phrase(slot) or "")
    edit:Show()
    edit:SetFocus()
    edit:HighlightText()
    return edit
end
ns.EditPhrase = EditPhrase

-- The first-time typing lesson comes back the next time the keyboard opens.
function ns.RunLessonAgain(button)
    ns.db.lessonDone = false
    ns.Tell(ns.L["LESSON_AGAIN"], button)
end

-- The notice for a player on the Classic chat style in the game's controller mode: why nothing opens, where the
-- game's setting is, and the box that hides IM style's typing line as Classic does. A flips the box, B shuts it.
function ns.StyleNotice()
    local L = ns.L
    local notice = options.notice
    if not notice then
        notice = CreateFrame("Frame", "FlickChatNotice", UIParent)
        notice:Hide()
        notice:SetFrameStrata("FULLSCREEN_DIALOG")
        notice:SetSize(520, 10)
        -- up from its place by what the keyboard under it needs (the keyboard's preview asks)
        local function Lift(by)
            notice:ClearAllPoints()
            notice:SetPoint("CENTER", 0, 150 + by)
        end
        Lift(0)
        notice:EnableMouse(true)
        ns.Dress(notice)
        local EDGE = 24
        -- A button's icon at a size that reads in a sentence (the game's own inline size is small).
        local function Glyph(key)
            local text = GetBindingText(key, 1) or ""
            local atlas, file = text:match("|A:([^:|]+)"), text:match("|T([^:|]+)")
            if atlas then
                local big = atlas:gsub("_%d+$", "_64")
                return "|A:" .. (C_Texture.GetAtlasInfo(big) and big or atlas) .. ":21:21|a"
            elseif file then
                return "|T" .. file .. ":21:21|t"
            end
            return text
        end
        local function Text(font)
            local text = notice:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
            text:SetJustifyH("LEFT")
            return text
        end
        -- Under another line, the window's width.
        local function Line(above, gap, font)
            local line = Text(font)
            line:SetPoint("TOP", above, "BOTTOM", 0, -gap)
            line:SetPoint("LEFT", notice, "LEFT", EDGE, 0)
            line:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
            return line
        end
        local title = notice:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -22)
        title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))
        title:SetTextColor(ns.BLUE[1], ns.BLUE[2], ns.BLUE[3])
        -- top right: B closes (a button, for the mouse too)
        local close = CreateFrame("Button", "FlickChatNoticeClose", notice)
        close.text = close:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        close.text:SetPoint("RIGHT")
        close:SetPoint("TOPRIGHT", -EDGE + 4, -14)
        close:SetScript("OnClick", function() notice:Hide() end)
        local text = Line(title, 12)
        text:SetText(L["NOTICE_WELCOME"])
        -- The keyboard's size, the keyboard itself under the window as the preview: LB - + RB at the right.
        local size = Text("GameFontNormal")
        size:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
        -- right after the sentence, on its middle line: LB, minus, plus, RB
        local smaller = Text()
        smaller:SetPoint("LEFT", size, "RIGHT", 14, 0)
        local function Step(name, label, by, after)
            local button = CreateFrame("Button", name, notice, "UIPanelButtonTemplate")
            button:SetSize(26, 22)
            button:SetText(label)
            button:SetPoint("LEFT", after, "RIGHT", 6, 0)
            button:SetScript("OnClick", function()
                ns.db.size = math.max(70, math.min(200, (ns.db.size or 100) + by))
                size:SetText(L["NOTICE_SIZE"]:format(ns.db.size))
                if ns.Restyle then ns.Restyle() end
            end)
            return button
        end
        local minus = Step("FlickChatNoticeSmaller", "-", -10, smaller)
        local plus = Step("FlickChatNoticeLarger", "+", 10, minus)
        local larger = Text()
        larger:SetPoint("LEFT", plus, "RIGHT", 6, 0)
        -- The keyboard's shape under the size, the same way: its name, Y, the button that turns to the other.
        local shape = Text("GameFontNormal")
        shape:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -14)
        local shapeKey = Text()
        shapeKey:SetPoint("LEFT", shape, "RIGHT", 14, 0)
        local turn = CreateFrame("Button", "FlickChatNoticeShape", notice, "UIPanelButtonTemplate")
        turn:SetPoint("LEFT", shapeKey, "RIGHT", 6, 0)
        local note = Line(shape, 14, "GameFontDisableSmall")
        note:SetText(L["NOTICE_SIZE_NOTE"])
        -- The hide-line box, X at the end of its line.
        local check = CreateFrame("CheckButton", "FlickChatNoticeCheck", notice, "UICheckButtonTemplate")
        check:Hide()
        check:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -10)
        check:SetScript("OnClick", function(self)
            ROWS.hideLine[2](self:GetChecked() == true)
            self:SetChecked(ROWS.hideLine[1]())
        end)
        local label = Text()
        label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -4)
        label:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
        -- The Classic chat style, in a section of its own at the bottom: what it means in red, then the switch.
        local rule = notice:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(0.6, 0.45, 0.2, 0.7)
        rule:SetHeight(1)
        rule:SetPoint("LEFT", notice, "LEFT", EDGE, 0)
        rule:SetPoint("RIGHT", notice, "RIGHT", -EDGE, 0)
        rule:SetPoint("TOP", note, "BOTTOM", 0, -16)
        local warn = Line(rule, 14, "GameFontNormal")
        warn:SetJustifyH("CENTER")
        -- The switch itself: the game's own console command, run by a secure button on the player's press, so
        -- the change is the player's (a setting written by addon code is refused its chat changes). On
        -- UIParent: under the notice it would make the notice a protected frame.
        local swap = CreateFrame("Button", "FlickChatNoticeSwap", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
        swap:Hide()
        swap:SetFrameStrata("FULLSCREEN_DIALOG")
        swap:SetFrameLevel(notice:GetFrameLevel() + 5)
        swap:SetSize(310, 36)
        swap:RegisterForClicks("AnyUp", "AnyDown")
        swap:SetAttribute("type", "macro")
        swap:SetAttribute("macrotext", "/console chatStyle im")
        -- What the window says for the chat style as it is now; whether the switch is offered.
        local function Tell()
            local classic = GetCVar("chatStyle") ~= "im"
            local section = classic or notice.switched
            close.text:SetText(L["NOTICE_KEY_CLOSE"]:format(Glyph("PAD2")))
            close:SetSize(close.text:GetStringWidth() + 4, 28)
            size:SetText(L["NOTICE_SIZE"]:format(ns.db.size or 100))
            smaller:SetText(Glyph("PADLSHOULDER"))
            larger:SetText(Glyph("PADRSHOULDER"))
            shape:SetText(L["NOTICE_SHAPE"]:format(ns.ShapeName()))
            shapeKey:SetText(Glyph("PAD4"))
            turn:SetText(L["NOTICE_SHAPE_TURN"])
            turn:SetSize(turn:GetFontString():GetStringWidth() + 28, 22)
            -- X right after the box's sentence
            label:SetText(L["OPT_HIDE_LINE"] .. "  " .. Glyph("PAD3"))
            swap:SetText(L["NOTICE_SWAP"] .. "   " .. Glyph("PAD1"))
            rule:SetShown(section)
            warn:SetShown(section)
            -- The hide-line box is IM style's: there from the start on IM style, under the section once switched.
            check:SetShown(not classic)
            label:SetShown(not classic)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", section and warn or note, "BOTTOMLEFT", -4, -10)
            if classic then
                warn:SetText(L["NOTICE_STYLE"])
                warn:SetTextColor(1, 0.25, 0.2)
            else
                warn:SetText(L["NOTICE_SWAPPED"])
                warn:SetTextColor(0.4, 0.9, 0.4)
            end
            local height = 22 + title:GetStringHeight() + 12 + text:GetStringHeight() + 18 + size:GetStringHeight() + 14
                + shape:GetStringHeight() + 14 + note:GetStringHeight()
            if section then height = height + 16 + 1 + 14 + warn:GetStringHeight() + (classic and 14 + 36 or 0) end
            if not classic then height = height + 10 + 32 + math.max(0, label:GetStringHeight() - 18) end
            notice:SetHeight(height + 22)
            return classic
        end
        turn:SetScript("OnClick", function()
            ns.NextShape()
            Tell()
        end)
        swap:SetScript("PostClick", function()
            C_Timer.After(0.3, function()
                if not notice:IsShown() then return end
                notice.switched = GetCVar("chatStyle") == "im"
                notice.Pad(true)
            end)
        end)
        -- On Classic style the pad buttons are key bindings to the window's own buttons, and the window takes
        -- no pad presses itself: the switch needs a press the game counts as the player's, and a press the
        -- window took never reaches it (measured). The game's controller mode sets its own pad bindings over
        -- ours as it goes, so ours go back whenever it does. On IM style the window reads the pad itself.
        local BOUND = { PAD1 = "FlickChatNoticeSwap", PAD2 = "FlickChatNoticeClose", PADLSHOULDER = "FlickChatNoticeSmaller",
            PADRSHOULDER = "FlickChatNoticeLarger", PAD4 = "FlickChatNoticeShape" }
        local function Bind()
            notice.binding = true
            for key, button in pairs(BOUND) do SetOverrideBindingClick(notice, true, key, button) end
            notice.binding = false
        end
        hooksecurefunc("SetOverrideBindingClick", function(owner, _, key)
            if notice.bound and not notice.binding and owner ~= notice and BOUND[key] and not InCombatLockdown() then Bind() end
        end)
        -- Bindings and the secure button are a fight's to refuse: both wait one out.
        function notice.Pad(on)
            local classic = Tell()
            if InCombatLockdown() then
                notice:RegisterEvent("PLAYER_REGEN_ENABLED")
                swap:SetAlpha(on and classic and 1 or 0)
                return
            end
            notice:UnregisterEvent("PLAYER_REGEN_ENABLED")
            swap:SetAlpha(1)
            swap:SetShown(on and classic)
            notice.bound = on and classic
            ClearOverrideBindings(notice)
            notice:EnableGamePadButton(on and not classic)
            if on and classic then
                swap:ClearAllPoints()
                -- to the window itself: a secure button cannot hang on a piece of text
                swap:SetPoint("BOTTOM", notice, "BOTTOM", 0, 22)
                Bind()
            end
        end
        -- On IM style: the size, the box and closing are the window's own pad presses.
        notice:SetScript("OnGamePadButtonDown", function(self, button)
            if button == "PADLSHOULDER" then
                minus:GetScript("OnClick")(minus)
            elseif button == "PADRSHOULDER" then
                plus:GetScript("OnClick")(plus)
            elseif button == "PAD3" then
                check:SetChecked(not check:GetChecked())
                check:GetScript("OnClick")(check)
            elseif button == "PAD4" then
                turn:GetScript("OnClick")(turn)
            elseif button == "PAD2" then
                self:Hide()
            end
        end)
        notice:SetScript("OnEvent", function(self) self.Pad(self:IsShown()) end)
        notice:SetScript("OnShow", function(self)
            self.switched = false
            check:SetChecked(ROWS.hideLine[1]())
            self.Pad(true)
            if ns.PreviewKeyboard then ns.PreviewKeyboard(self, Lift) end
        end)
        notice:SetScript("OnHide", function(self)
            ns.db.welcomed = true
            self.Pad(false)
            if ns.PreviewKeyboard then ns.PreviewKeyboard() end
        end)
        options.notice = notice
    end
    notice:Show()
end

-- Where the chat box can send, by flick (1-4 the left stick's up, right, down, left; 5-8 the right's): Say, Party,
-- Guild and the group on the left, the newest whisper partners (the target player second) on the right.
local function Named(key) return _G["CHAT_MSG_" .. key] or key end

-- How likely each kind of person is the one meant, for the name search and the whispers page.
local RECENT, CLOSE_BY, FRIEND, GUILDIE = 0.5, 0.4, 0.3, 0.1

-- The channel wheel's pages, eight slices each from the top going clockwise: where to talk, who to whisper (the
-- target, the newest whisper partners, friends online, then a name search), the numbered channels. A slice the player
-- cannot use now stays in its place, marked off.
function ns.WheelPages()
    local L = ns.L
    local instance, guild = IsInGroup(LE_PARTY_CATEGORY_INSTANCE), IsInGuild()
    local group = instance and "INSTANCE_CHAT" or "RAID"
    local talk = {
        { label = Named("SAY"), chatType = "SAY" },
        { label = Named("PARTY"), chatType = "PARTY", off = not IsInGroup() },
        { label = Named(group), chatType = group, off = not (IsInRaid() or instance) },
        { label = Named("GUILD"), chatType = "GUILD", off = not guild },
        { label = Named("OFFICER"), chatType = "OFFICER", off = not guild },
        { label = Named("YELL"), chatType = "YELL" },
        { label = Named("EMOTE"), chatType = "EMOTE" },
        -- The last slice is no channel: the sticks then carry and size the keyboard.
        { label = L["MOVE_SLICE"], move = true },
    }
    local people, seen = {}, {}
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local target = GetUnitName("target", true)
        if target and not (issecretvalue and issecretvalue(target)) then
            seen[target] = true
            people[1] = { label = target:match("^[^%-]+"), chatType = "WHISPER", tellTarget = target }
        end
    end
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    while name and name ~= "" and #people < 7 and not seen[name] do
        seen[name] = true
        people[#people + 1] = { label = name:match("^[^%-]+") or name, chatType = kind or "WHISPER", tellTarget = name }
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    for _, friend in ipairs(ns.WhisperNames()) do
        if #people >= 7 then break end
        if friend.chance >= FRIEND and not seen[friend.tellTarget] then
            seen[friend.tellTarget] = true
            people[#people + 1] = { label = friend.label, chatType = friend.chatType, tellTarget = friend.tellTarget }
        end
    end
    people[#people + 1] = { label = L["WHISPER_SOMEONE"], naming = true }
    local channels, list = {}, { GetChannelList() }
    for i = 1, #list, 3 do
        if not list[i + 2] and #channels < 8 then
            channels[#channels + 1] = { label = list[i] .. ". " .. list[i + 1], chatType = "CHANNEL",
                channelTarget = list[i] }
        end
    end
    -- The addon's own page: its settings window, and the keyboard's place.
    local own = { { label = L["SETTINGS_SLICE"], settings = true }, { label = L["MOVE_SLICE"], move = true } }
    return { { title = L["WHEEL_TALK"], picks = talk }, { title = L["WHEEL_WHISPERS"], picks = people },
        { title = L["WHEEL_CHANNELS"], picks = channels }, { title = L["TITLE"], picks = own } }
end

-- Everyone a whisper can reach now, for the name search: battle.net friends by BattleTag and by the character they
-- play, WoW friends, the guild, the group, the target; the newest whisper partners count most.
function ns.WhisperNames()
    local list, seen, recent = {}, {}, {}
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    local rank = 0
    while name and name ~= "" and rank < 10 and not recent[name] do
        rank = rank + 1
        recent[name] = RECENT / rank
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    local function Add(label, chatType, target, chance)
        if type(label) ~= "string" or type(target) ~= "string" or label == "" then return end
        if issecretvalue and (issecretvalue(label) or issecretvalue(target)) then return end
        local key = ns.Lower(label) .. "\0" .. target
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = { label = label, chatType = chatType, tellTarget = target,
            chance = math.max(chance, recent[target] or 0) }
    end
    for i = 1, BNGetNumFriends and BNGetNumFriends() or 0 do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        local game = info and info.gameAccountInfo
        if game and game.isOnline then
            Add(info.battleTag and info.battleTag:match("^[^#]+"), "BN_WHISPER", info.accountName, FRIEND)
            Add(game.characterName, "BN_WHISPER", info.accountName, FRIEND)
        end
    end
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then Add(info.name:match("^[^%-]+"), "WHISPER", info.name, FRIEND) end
    end
    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local full, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if full and online then Add(full:match("^[^%-]+"), "WHISPER", full, GUILDIE) end
        end
    end
    local unit = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local full = GetUnitName(unit .. i, true)
        if full and not UnitIsUnit(unit .. i, "player") then Add(full:match("^[^%-]+"), "WHISPER", full, CLOSE_BY) end
    end
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local full = GetUnitName("target", true)
        if full then Add(full:match("^[^%-]+"), "WHISPER", full, CLOSE_BY) end
    end
    for target, chance in pairs(recent) do
        if not target:find("|K", 1, true) then Add(target:match("^[^%-]+"), "WHISPER", target, chance) end
    end
    return list
end

-- The chat box sends there from now on; its header shows where.
function ns.SwitchChannel(box, pick)
    if not pick or not box.SetChatType then return end
    box:SetChatType(pick.chatType)
    if pick.tellTarget then box:SetTellTarget(pick.tellTarget) end
    if pick.channelTarget then box:SetChannelTarget(pick.channelTarget) end
    box:UpdateHeader()
end

function ns.IsChannel(box, pick)
    if not pick or not box.GetChatType or box:GetChatType() ~= pick.chatType then return false end
    if pick.tellTarget then return box:GetTellTarget() == pick.tellTarget end
    if pick.channelTarget then return tonumber(box:GetChannelTarget()) == pick.channelTarget end
    return true
end

SLASH_FLICKCHAT1 = "/flick"
SLASH_FLICKCHAT2 = "/flickchat"
SLASH_FLICKCHAT3 = "/fc"
SlashCmdList.FLICKCHAT = function(msg)
    local db = ns.db
    if not db then return end
    local cmd, value = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if cmd == "size" and tonumber(value) then
        db.size = math.max(70, math.min(200, math.floor(tonumber(value))))
        ns.Say(ns.L["SIZE"]:format(db.size))
        if ns.Restyle then ns.Restyle() end
    elseif cmd == "layout" and ns.LAYOUTS[value] then
        db.layout = value
        ns.Say(ns.L["LAYOUT_" .. value:upper()])
        if ns.Relayout then ns.Relayout() end
    elseif cmd == "lesson" then
        ns.RunLessonAgain()
    elseif cmd == "move" then
        ns.MoveNext()
    elseif cmd == "practice" then
        ns.PracticeNext()
    elseif cmd == "new" then
        -- What a new player on the Classic chat style meets at login, whatever the style is now.
        ns.StyleNotice()
    elseif cmd == "chatprobe" then
        ns.StartChatProbe(30)
        ns.Say(ns.L["PROBE_CHAT"])
    elseif cmd == "sticks" then
        ns.StartStickProbe(40)
        ns.Say(ns.L["PROBE_STICKS"])
    elseif cmd == "phrases" and value == "reset" then
        ns.ResetPhrases()
        ns.Say(ns.L["PHRASES_RESET"])
    elseif cmd == "phrases" or cmd == "options" or cmd == "settings" then
        if not ns.OpenOptions() then ns.Say(ns.L["USAGE"]) end
    elseif cmd == "lowercase" then
        db.lowercase = not db.lowercase or nil
        ns.Say(db.lowercase and ns.L["LOWER_ON"] or ns.L["LOWER_OFF"])
    elseif cmd == "" then
        db.enabled = not db.enabled
        ns.Say(db.enabled and ns.L["ON"] or ns.L["OFF"])
        if not db.enabled and ns.Shut then ns.Shut() end
    else
        ns.Say(ns.L["USAGE"])
    end
end

-- The dev addon (never shipped) is handed the addon's table.
function FlickChat_AttachDevTools(attach) attach(ns) end
