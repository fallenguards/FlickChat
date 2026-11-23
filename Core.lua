local addonName, ns = ...

-- Strings: each locale file fills its own table and ns.locale picks one; a missing one shows English, never its key.
ns.locales, ns.locale = {}, GetLocale()
ns.L = setmetatable({}, { __index = function(_, key)
    local own = ns.locales[ns.locale]
    return own and own[key] or ns.EN and ns.EN[key] or key
end })

-- Lua's lower and upper only know ASCII: handle Latin accents and the Russian alphabet explicitly.
local UTF8 = "[%z\1-\127\194-\244][\128-\191]*"
local function Shift(by) return function(c) return "\195" .. string.char(c:byte() + by) end end
local DownOne, UpOne = Shift(32), Shift(-32)
local CYRILLIC_LOWER, CYRILLIC_UPPER = {}, {}
do
    local upper = ("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"):gmatch(UTF8)
    for lower in ("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"):gmatch(UTF8) do
        local capital = upper()
        CYRILLIC_LOWER[capital], CYRILLIC_UPPER[lower] = lower, capital
    end
end

-- Letter positions, not byte offsets (chat box cursor and highlight offsets still use bytes).
function ns.Characters(text)
    local letters = {}
    for c in text:gmatch(UTF8) do letters[#letters + 1] = c end
    return letters
end

function ns.Lower(text)
    text = text:lower()
    text = text:gsub("[\208\209][\128-\191]", CYRILLIC_LOWER)
    if not text:find("[\195\197]") then return text end
    return (text:gsub("\195([\128-\150\152-\158])", DownOne):gsub("\197\146", "\197\147"):gsub("\197\184", "\195\191"))
end

function ns.Upper(text)
    text = text:upper()
    text = text:gsub("[\208\209][\128-\191]", CYRILLIC_UPPER)
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
ns.LANGUAGES = { "enUS", "ptBR", "frFR", "deDE", "itIT", "esES", "ruRU" }
ns.LANGUAGE_NAMES = { enUS = "English", ptBR = "Português", frFR = "Français", deDE = "Deutsch", itIT = "Italiano",
    esES = "Español", ruRU = "Русский" }
-- A game language typed with another's words: Latin American Spanish with Spanish's.
local SAME_WORDS = { esMX = "esES" }
local function GameLanguage() return SAME_WORDS[ns.locale] or ns.locale end
ns.wordLists = {}
function FlickChat_AddWords(code, data) ns.wordLists[code] = data end
local LoadAddOn = C_AddOns.LoadAddOn

-- The account's (ns.db): learned: word -> times sent; pairs: "word next" -> times ("<s>" starts a message); forms: a
-- word's own capitals; uses: how often each hint's action was used (a hint goes once learned); arm/rearm: a flick's
-- tilt out and back; wordsOf: whose learned words the four tables above are; others: the other languages' learned
-- words, by language; profiles: the settings, by profile name.
local DEFAULTS = { learned = {}, pairs = {}, forms = {}, forgot = {}, uses = {}, arm = 0.55, rearm = 0.3, lessonDone = false,
    others = {}, profiles = {} }
-- Profiles, as WoW addons keep settings: every setting the player picks is a profile's (ns.profile), and each
-- character is on one, named in its own saved table (FlickChatCharDB.profile; none is Default, the profile every
-- character shares at first). What is typed and learned, the stick's measured reach and the one-time notes stay
-- the account's. phrases: the quick phrases by slot (an empty slot is the language's default); language: the
-- language typed in (none: the game's own).
local PROFILE_DEFAULTS = { enabled = true, layout = "letters", size = 100, phrases = {}, wheelSize = 100, wordRoom = 100,
    textSize = 100, backOpacity = 90 }
-- a profile's other settings: off (nil) until set
local PROFILE_KEYS = { "lowercase", "matureFilter", "phraseFill", "hideLine", "hintsToggle", "guideOff", "stickTipsOff",
    "hintBoxOff",
    "shape", "language", "moveX", "moveY", "guideX", "guideY" }
local DEFAULT_PROFILE = "Default"
ns.DEFAULT_PROFILE = DEFAULT_PROFILE
local DB_VERSION = 3
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
    if (db.dbVersion or 0) < 3 then
        -- the settings were the account's: they are the Default profile's now, which every character is on
        db.profiles = db.profiles or {}
        local default = db.profiles[DEFAULT_PROFILE] or {}
        db.profiles[DEFAULT_PROFILE] = default
        local function Move(key)
            if db[key] ~= nil then default[key], db[key] = db[key], nil end
        end
        for key in pairs(PROFILE_DEFAULTS) do Move(key) end
        for _, key in ipairs(PROFILE_KEYS) do Move(key) end
    end
    db.dbVersion = DB_VERSION
end

-- Login notes: the typing languages, once; a newer version heard from someone in the guild or group, at each
-- login until this one is as new (forgotten after a month unheard).
local PREFIX, UPDATE_URL, HEARD_FOR = "FlickChat", "curseforge.com/wow/addons/flickchat", 30 * 86400
local FEEDBACK_URL, FEEDBACK_LINK = "https://github.com/fallenguards/FlickChat/issues", "addon:FlickChat:feedback"
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

-- Thanks and where to leave feedback, the logo before the name; [here] shows the address to copy (the game
-- opens no web page).
function ns.SayFeedback()
    local name = "|TInterface\\AddOns\\" .. addonName .. "\\media\\icon:0|t |cff2e8fe6" .. ns.L["TITLE"] .. "|r"
    local here = "|cff2e8fe6|H" .. FEEDBACK_LINK .. "|h[" .. ns.L["FEEDBACK_HERE"] .. "]|h|r"
    print(ns.L["FEEDBACK"]:format(name, here))
end

hooksecurefunc("SetItemRef", function(link)
    if link == FEEDBACK_LINK then ns.ShowAddress(FEEDBACK_URL) end
end)

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
    if db.feedbackTold ~= OWN_VERSION then
        db.feedbackTold = OWN_VERSION
        ns.SayFeedback()
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
    if wheelTold or not own or not controller or not ns.profile.enabled then return end
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
    if event == "CHAT_MSG_CHANNEL_NOTICE" then return ns.JoinHeard() end
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
    -- this character's own: the profile it is on
    FlickChatCharDB = FlickChatCharDB or {}
    ns.char = FlickChatCharDB
    ns.UseProfile(ns.char.profile, true)
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
    local code = ns.profile.language or GameLanguage()
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
            if code == GameLanguage() then ns.profile.language = nil else ns.profile.language = code end
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

-- The keyboard's place and size, or the button guide's place: set with the sticks the next time it opens.
function ns.MoveNext(button, guide)
    ns.moveNext = guide and "guide" or true
    ns.Tell(ns.L[guide and "MOVE_GUIDE_NEXT" or "MOVE_NEXT"], button)
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

-- What cannot be done, or did not go: the game's red error text, never chat. Chat says nothing of what the player
-- just did and can see (his rule for every addon; FlickChat's last such lines went 2026-11-23).
function ns.Refuse(text)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.1, 0.1) end
end

-- What a settings button set going: a chat line, and the pressed button's own text says it where the player is
-- looking. Never a dialog: a StaticPopup shown by addon code over the Settings window leaves the game's
-- controller bindings tainted, and closing the window is then refused.
function ns.Tell(text, button)
    ns.Say(text)
    if button and button.SetText then button:SetText(ns.L["OPT_ARMED"]) end
end

-- Profiles (see PROFILE_DEFAULTS). A profile's missing settings are its defaults.
local function Fill(profile)
    for key, value in pairs(PROFILE_DEFAULTS) do
        if profile[key] == nil then profile[key] = type(value) == "table" and {} or value end
    end
    return profile
end

local function Copy(from)
    local out = {}
    for key, value in pairs(from) do out[key] = type(value) == "table" and Copy(value) or value end
    return out
end

-- Where a saved key lives: this character's profile for a setting, else the account's (the dev addon keeps and
-- puts back keys of both).
function ns.Holder(key)
    if PROFILE_DEFAULTS[key] ~= nil then return ns.profile end
    for _, setting in ipairs(PROFILE_KEYS) do
        if setting == key then return ns.profile end
    end
    return ns.db
end

function ns.ProfileName() return ns.char.profile or DEFAULT_PROFILE end
-- As the settings show it: Default in the player's language, the others as named.
function ns.ProfileLabel(name)
    name = name or ns.ProfileName()
    return name == DEFAULT_PROFILE and ns.L["PROFILE_DEFAULT"] or name
end

-- Default first, the rest by name.
function ns.ProfileNames()
    local names = {}
    for name in pairs(ns.db.profiles) do
        if name ~= DEFAULT_PROFILE then names[#names + 1] = name end
    end
    table.sort(names)
    table.insert(names, 1, DEFAULT_PROFILE)
    return names
end

-- This character onto a profile (none, or one deleted meanwhile: Default); the keyboard and the typing lines take
-- its settings at once. loading: at the addon's load, with nothing built yet.
function ns.UseProfile(name, loading)
    local profiles = ns.db.profiles
    if not name or not profiles[name] then name = DEFAULT_PROFILE end
    profiles[name] = Fill(profiles[name] or {})
    ns.char.profile = name ~= DEFAULT_PROFILE and name or nil
    ns.profile = profiles[name]
    if loading then return end
    if ns.Relayout then ns.Relayout() end
    if ns.Relanguage then ns.Relanguage() end
    if ns.FadeLines then ns.FadeLines() end
end

-- The settings row: on (by 1) or back (by -1) to the next profile, round to Default.
function ns.NextProfile(by)
    local names, at = ns.ProfileNames(), 1
    for i, name in ipairs(names) do
        if name == ns.ProfileName() then at = i end
    end
    ns.UseProfile(names[(at - 1 + (by or 1)) % #names + 1])
end

-- What New profile offers to name it: the character and its realm, as profile addons name a character's own.
function ns.CharacterProfileName()
    local name, realm = UnitName("player"), GetRealmName and GetRealmName()
    return realm and realm ~= "" and ("%s - %s"):format(name or "", realm) or name or ""
end

-- New profile: a copy of the one this character is on, under the name typed, and this character onto it. A name
-- already there: onto that profile, as it is.
function ns.NewProfile(name)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then return end
    if not ns.db.profiles[name] then ns.db.profiles[name] = Copy(ns.profile) end
    ns.UseProfile(name)
end

-- Copy from: every setting of another profile into this character's, in place (characters on it share the change).
function ns.CopyProfile(from)
    local source = ns.db.profiles[from]
    if not source or source == ns.profile then return end
    local settings = Copy(source)
    wipe(ns.profile)
    for key, value in pairs(settings) do ns.profile[key] = value end
    ns.UseProfile(ns.ProfileName())
end

function ns.ResetProfile()
    wipe(ns.profile)
    ns.UseProfile(ns.ProfileName())
end

-- Delete: this character's profile goes and it is on Default; another character on it goes to Default at its next
-- login. Default stays.
function ns.DeleteProfile()
    local name = ns.ProfileName()
    if name == DEFAULT_PROFILE then return ns.Refuse(ns.L["PROFILE_KEEP_DEFAULT"]) end
    ns.db.profiles[name] = nil
    ns.UseProfile(DEFAULT_PROFILE)
end

-- Quick phrases by slot (1-4 the left stick's up, right, down, left; 5-8 the right's): the profile's, else the
-- language's default. A phrase emptied or set back to its default is the default again.
local function DefaultPhrase(slot)
    local i = 0
    for phrase in ns.L["PHRASES"]:gmatch("[^|]+") do
        i = i + 1
        if i == slot then return phrase end
    end
end

function ns.Phrase(slot) return ns.profile.phrases[slot] or DefaultPhrase(slot) end

function ns.SetPhrase(slot, text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" or text == DefaultPhrase(slot) then text = nil end
    ns.profile.phrases[slot] = text
end

function ns.ResetPhrases() wipe(ns.profile.phrases) end

-- In the game's controller mode its Menu wheel's Chat shows the typing line (and so the keyboard) only with the IM
-- chat style; with Classic nothing opens, the game's own chat included.
function ns.NeedsIMStyle()
    local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    return controller == true and GetCVar("chatStyle") ~= "im"
end

-- What the settings window (Options.lua) and the first-login notice keep.
local options = {}

local function HidesBar() return ns.profile.hintsToggle == nil or ns.profile.hintsToggle == "bar" end
local function HidesGuide() return ns.profile.hintsToggle == nil or ns.profile.hintsToggle == "guide" end

local function SetHides(bar, guide)
    if bar and guide then
        ns.profile.hintsToggle = nil
    else
        ns.profile.hintsToggle = bar and "bar" or guide and "guide" or "none"
    end
end

-- What each row reads and writes, over the saved settings' own shapes (nil for off, the hidden flag turned round).
local ROWS = {
    lowercase = { function() return ns.profile.lowercase == true end, function(on) ns.profile.lowercase = on or nil end },
    -- What the right stick press hides: hintsToggle is nil for both, "bar", "guide" or "none".
    -- IM style's typing line out of sight until chat opens, as Classic style's is.
    hideLine = { function() return ns.profile.hideLine == true end, function(on)
        ns.profile.hideLine = on or nil
        if ns.FadeLines then ns.FadeLines() end
    end },
    stickTips = { function() return not ns.profile.stickTipsOff end, function(on)
        if on then ns.profile.stickTipsOff = nil else ns.profile.stickTipsOff = true end
    end },
    -- the hint lines in a box like the button guide's; hintBoxOff: the bare lines
    hintBox = { function() return not ns.profile.hintBoxOff end, function(on)
        if on then ns.profile.hintBoxOff = nil else ns.profile.hintBoxOff = true end
        if ns.Restyle then ns.Restyle() end
    end },
    phraseSend = { function() return not ns.profile.phraseFill end, function(on)
        if on then ns.profile.phraseFill = nil else ns.profile.phraseFill = true end
    end },
    matureFilter = { function() return ns.profile.matureFilter == true end, function(on) ns.profile.matureFilter = on or nil end },
    hideBar = { function() return HidesBar() end, function(on) SetHides(on, HidesGuide()) end },
    hideGuide = { function() return HidesGuide() end, function(on) SetHides(HidesBar(), on) end },
    size = { function() return ns.profile.size end, function(value)
        ns.profile.size = value
        if ns.Restyle then ns.Restyle() end
    end },
    wordRoom = { function() return ns.profile.wordRoom end, function(value)
        ns.profile.wordRoom = value
        if ns.Restyle then ns.Restyle() end
    end },
    textSize = { function() return ns.profile.textSize end, function(value)
        ns.profile.textSize = value
        if ns.Restyle then ns.Restyle() end
    end },
    backOpacity = { function() return ns.profile.backOpacity end, function(value)
        ns.profile.backOpacity = value
        if ns.Restyle then ns.Restyle() end
    end },
    wheelSize = { function() return ns.profile.wheelSize end, function(value) ns.profile.wheelSize = value end },
}
ns.optionRows = ROWS

-- The keyboard's shape: wide (a stick either side of the guess words, no pick saved), or stacked, the sticks side
-- by side with the words over them ("above") or under them ("below").
function ns.Stacked()
    local shape = ns.profile.shape
    return (shape == "above" or shape == "below") and shape or nil
end

function ns.ShapeName()
    local shape = ns.Stacked()
    return ns.L[shape == "above" and "SHAPE_ABOVE" or shape == "below" and "SHAPE_BELOW" or "SHAPE_WIDE"]
end

function ns.NextShape()
    local shape = ns.Stacked()
    if shape == "above" then
        ns.profile.shape = "below"
    elseif shape == "below" then
        ns.profile.shape = nil
    else
        ns.profile.shape = "above"
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

-- A web address picked in a box for Ctrl+C, "Copied" under it after. Nothing to type: an edit puts it back; Enter,
-- Escape or a click away shut it.
function ns.ShowAddress(url)
    local copy = options.copy
    if not copy then
        copy = CreateFrame("Frame", "FlickChatAddress", UIParent)
        copy:Hide()
        copy:SetFrameStrata("DIALOG")
        copy:SetSize(440, 10)
        copy:SetPoint("TOP", 0, -160)
        copy:EnableMouse(true)
        ns.Dress(copy)
        copy.title = copy:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        copy.title:SetPoint("TOP", 0, -22)
        copy.title:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title"))
        copy.title:SetTextColor(ns.BLUE[1], ns.BLUE[2], ns.BLUE[3])
        copy.hint = copy:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        copy.hint:SetPoint("TOP", copy.title, "BOTTOM", 0, -12)
        copy.hint:SetPoint("LEFT", 24, 0)
        copy.hint:SetPoint("RIGHT", -24, 0)
        local edit = CreateFrame("EditBox", nil, copy)
        edit:SetAutoFocus(false)
        edit:SetFontObject(GameFontHighlight)
        edit:SetTextInsets(8, 8, 0, 0)
        edit:SetHeight(28)
        edit:SetPoint("TOP", copy.hint, "BOTTOM", 0, -12)
        edit:SetPoint("LEFT", 24, 0)
        edit:SetPoint("RIGHT", -24, 0)
        local rim = edit:CreateTexture(nil, "BACKGROUND", nil, -2)
        rim:SetAllPoints()
        rim:SetColorTexture(1, 0.82, 0, 1)
        local fill = edit:CreateTexture(nil, "BACKGROUND", nil, -1)
        fill:SetPoint("TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", -1, 1)
        fill:SetColorTexture(0.05, 0.05, 0.06, 1)
        local function Shut() copy:Hide() end
        edit:SetScript("OnTextChanged", function(self, typed)
            if typed then
                self:SetText(copy.url)
                self:HighlightText()
            end
        end)
        edit:SetScript("OnEnterPressed", Shut)
        edit:SetScript("OnEscapePressed", Shut)
        edit:SetScript("OnEditFocusLost", Shut)
        copy.copied = copy:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        copy.copied:SetPoint("TOP", edit, "BOTTOM", 0, -8)
        copy.copied:Hide()
        local fade = copy.copied:CreateAnimationGroup()
        local out = fade:CreateAnimation("Alpha")
        out:SetFromAlpha(1)
        out:SetToAlpha(0)
        out:SetStartDelay(0.8)
        out:SetDuration(0.8)
        fade:SetScript("OnFinished", function() copy.copied:Hide() end)
        edit:SetScript("OnKeyDown", function(_, key)
            if key ~= "C" or not IsControlKeyDown() then return end
            fade:Stop()
            copy.copied:SetAlpha(1)
            copy.copied:Show()
            fade:Play()
        end)
        copy.edit = edit
        ns.addressBox = edit
        options.copy = copy
    end
    copy.url = url
    copy.hint:SetText(ns.L["COPY_HINT"])
    copy.copied:SetText(ns.L["COPIED"])
    copy.copied:Hide()
    copy:SetHeight(22 + copy.title:GetStringHeight() + 12 + copy.hint:GetStringHeight() + 12 + 28 + 8
        + copy.copied:GetStringHeight() + 18)
    copy:Show()
    copy.edit:SetText(url)
    copy.edit:SetFocus()
    copy.edit:HighlightText()
end

-- One box for whichever typing row was pressed (slot: a phrase's, "words" the player's words, "profile" a new
-- profile's name): exactly over that row's button and opaque, so it is typed in the button's place.
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
            elseif self.slot == "profile" then
                ns.NewProfile(self:GetText())
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
    -- what the row shows once the box goes, what the box starts with, how long it may be
    local text, most
    if slot == "words" then
        edit.shows, text, most = ns.MyWordsText, ns.db.myWords or "", 400
    elseif slot == "profile" then
        edit.shows, text, most = function() return ns.L["OPT_PROFILE_NEW_BUTTON"] end, ns.CharacterProfileName(), 48
    else
        edit.shows, text, most = function() return ns.Phrase(slot) or "" end, ns.Phrase(slot) or "", 120
    end
    edit:SetMaxLetters(most)
    edit:ClearAllPoints()
    edit:SetAllPoints(button)
    edit:SetText(text)
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
        -- A setting stepped by tens, the keyboard under the window as the preview: its sentence, then right after it
        -- on its middle line the lower button's glyph, minus, plus and the higher one's.
        local function Stepper(above, gap, spec)
            local row = { line = Text("GameFontNormal"), less = Text(), more = Text() }
            row.line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
            row.less:SetPoint("LEFT", row.line, "RIGHT", 14, 0)
            function row.Tell()
                row.line:SetText(L[spec.format]:format(ns.profile[spec.key] or 100))
                row.less:SetText(Glyph(spec.keys[1]))
                row.more:SetText(Glyph(spec.keys[2]))
            end
            local function Step(name, label, by, after)
                local button = CreateFrame("Button", name, notice, "UIPanelButtonTemplate")
                button:SetSize(26, 22)
                button:SetText(label)
                button:SetPoint("LEFT", after, "RIGHT", 6, 0)
                button:SetScript("OnClick", function()
                    ns.profile[spec.key] = math.max(spec.low, math.min(spec.high, (ns.profile[spec.key] or 100) + by))
                    row.Tell()
                    if ns.Restyle then ns.Restyle() end
                end)
                return button
            end
            row.minus = Step(spec.names[1], "-", -10, row.less)
            row.plus = Step(spec.names[2], "+", 10, row.minus)
            row.more:SetPoint("LEFT", row.plus, "RIGHT", 6, 0)
            return row
        end
        -- The keyboard's size on the triggers and its backing on the bumpers under them, as they sit on the pad;
        -- the text's own size on the d-pad's left and right.
        local STEPPERS = {
            { key = "size", low = 70, high = 200, format = "NOTICE_SIZE", keys = { "PADLTRIGGER", "PADRTRIGGER" },
                names = { "FlickChatNoticeSmaller", "FlickChatNoticeLarger" } },
            { key = "backOpacity", low = 0, high = 100, format = "NOTICE_BACK", keys = { "PADLSHOULDER", "PADRSHOULDER" },
                names = { "FlickChatNoticeBackLess", "FlickChatNoticeBackMore" } },
            { key = "textSize", low = 70, high = 150, format = "NOTICE_TEXT_SIZE", keys = { "PADDLEFT", "PADDRIGHT" },
                names = { "FlickChatNoticeTextSmaller", "FlickChatNoticeTextLarger" } },
        }
        local steppers, PRESSES, above = {}, {}, text
        for i, spec in ipairs(STEPPERS) do
            local row = Stepper(above, i == 1 and 18 or 14, spec)
            steppers[i], above = row, row.line
            PRESSES[spec.keys[1]], PRESSES[spec.keys[2]] = row.minus, row.plus
        end
        -- The keyboard's shape under them, the same way: its name, Y, the button that turns to the other.
        local shape = Text("GameFontNormal")
        shape:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -14)
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
            local rowsH = 0
            for _, row in ipairs(steppers) do
                row.Tell()
                rowsH = rowsH + row.line:GetStringHeight() + 14
            end
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
            -- the first row 18 under the welcome, the others and the shape 14 apart
            local height = 22 + title:GetStringHeight() + 12 + text:GetStringHeight() + 4 + rowsH + 14
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
        local BOUND = { PAD1 = "FlickChatNoticeSwap", PAD2 = "FlickChatNoticeClose", PAD4 = "FlickChatNoticeShape" }
        for _, spec in ipairs(STEPPERS) do
            BOUND[spec.keys[1]], BOUND[spec.keys[2]] = spec.names[1], spec.names[2]
        end
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
        -- On IM style: the steps, the box and closing are the window's own pad presses.
        notice:SetScript("OnGamePadButtonDown", function(self, button)
            if PRESSES[button] then
                PRESSES[button]:GetScript("OnClick")(PRESSES[button])
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
            -- Button names read before the game counts the controller in use are plain numbers (Y as 4): told
            -- again once it does.
            self:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
            self.Pad(true)
            if ns.PreviewKeyboard then ns.PreviewKeyboard(self, Lift) end
        end)
        notice:SetScript("OnHide", function(self)
            ns.db.welcomed = true
            self:UnregisterEvent("GAME_PAD_ACTIVE_CHANGED")
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
local RECENT, CLOSE_BY, FRIEND, GUILDIE, OFFLINE = 0.5, 0.4, 0.3, 0.1, 0.05

-- A friend in this game only (Battle.net's third friend level, after BattleTag and Real ID) no Battle.net whisper
-- reaches: the game whispers their character instead, and so does the wheel.
local TITLE = Enum and Enum.BattleNetFriendLevel and Enum.BattleNetFriendLevel.Title

-- The character the game whispers for a Battle.net name that is a friend in this game only, else nil.
local function TitleTarget(name)
    local Get = ChatFrameUtil.GetCharacterWhisperTargetIfTitleFriend
    local target = Get and Get(name)
    return type(target) == "string" and target ~= "" and target or nil
end

-- The character a Battle.net friend plays in this game now, as a whisper target: the game's own for a friend in
-- this game only, else named as its friends list names them (no realm on ours). Nil when they play none here.
local function CharacterOf(info)
    local game = info.gameAccountInfo
    if not (game and game.isOnline) then return nil end
    local Own = C_BattleNet.GetDefaultTitleWhisperTarget
    local own = Own and info.bnetAccountID and Own(info.bnetAccountID)
    if type(own) == "string" and own ~= "" then return own end
    if game.clientProgram ~= BNET_CLIENT_WOW or game.wowProjectID ~= WOW_PROJECT_ID or not game.isInCurrentRegion then
        return nil
    end
    local name, realm = game.characterName, game.realmName
    if type(name) ~= "string" or name == "" then return nil end
    if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then return nil end
    if type(realm) ~= "string" or realm == "" or (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled())
        or realm == (GetNormalizedRealmName and GetNormalizedRealmName()) then
        return name
    end
    return name .. "-" .. realm
end

-- The channel wheel's pages, eight slices each from the top going clockwise: where to talk; who to whisper (the
-- target, the newest whisper partners, friends online and the characters Battle.net friends play here, then a name
-- search); the same by Battle.net, friends online first, then those offline (a Battle.net whisper reaches them too;
-- the page is there while the player has a Battle.net friend); the numbered channels and the zone's ones to join. A
-- slice the player cannot use now stays in its place, marked off.
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
    -- whispers to a character on one page, Battle.net whispers on the next: seven people each, then a name search
    local people, bnet, seen = {}, {}, {}
    -- Battle.net friends offline, by account: their slices are greyed as the game's friends list greys them
    local names, away = ns.WhisperNames(), {}
    for _, friend in ipairs(names) do
        if friend.offline then away[friend.tellTarget] = true end
    end
    local function Keep(list, label, chatType, target)
        if seen[target] or #list >= 7 then return end
        seen[target] = true
        list[#list + 1] = { label = label, chatType = chatType, tellTarget = target,
            offline = chatType == "BN_WHISPER" and away[target] or nil }
    end
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local target = GetUnitName("target", true)
        if target and not (issecretvalue and issecretvalue(target)) then
            Keep(people, target:match("^[^%-]+"), "WHISPER", target)
        end
    end
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    local walked = {}
    while name and name ~= "" and not walked[name] do
        walked[name] = true
        local character = kind == "BN_WHISPER" and TitleTarget(name)
        if character then
            Keep(people, character:match("^[^%-]+"), "WHISPER", character)
        elseif kind == "BN_WHISPER" then
            Keep(bnet, name:match("^[^%-]+") or name, "BN_WHISPER", name)
        else
            Keep(people, name:match("^[^%-]+") or name, "WHISPER", name)
        end
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    local anyBnet, offline = false, {}
    for _, friend in ipairs(names) do
        local byBnet = friend.chatType == "BN_WHISPER"
        anyBnet = anyBnet or byBnet
        if friend.offline then
            offline[#offline + 1] = friend
        elseif friend.chance >= FRIEND then
            Keep(byBnet and bnet or people, friend.label, friend.chatType, friend.tellTarget)
        end
    end
    -- Battle.net friends offline after those online: favourites first, then the most lately online
    table.sort(offline, function(a, b)
        if a.favorite ~= b.favorite then return a.favorite end
        return a.lastOnline > b.lastOnline
    end)
    for _, friend in ipairs(offline) do Keep(bnet, friend.label, friend.chatType, friend.tellTarget) end
    people[#people + 1] = { label = L["WHISPER_SOMEONE"], naming = "WHISPER" }
    bnet[#bnet + 1] = { label = L["WHISPER_SOMEONE"], naming = "BN_WHISPER" }
    local channels, list = {}, { GetChannelList() }
    for i = 1, #list, 3 do
        if not list[i + 2] and #channels < 8 then
            channels[#channels + 1] = { label = list[i] .. ". " .. list[i + 1], chatType = "CHANNEL",
                channelTarget = list[i], channelName = list[i + 1] }
        end
    end
    -- a join's button and bindings are a fight's to refuse
    local full = InCombatLockdown() or ChatFrameUtil.CanAddChannel and not ChatFrameUtil.CanAddChannel()
    for _, zone in ipairs(ns.ChannelsToJoin()) do
        if #channels >= 8 then break end
        channels[#channels + 1] = { label = L["JOIN_SLICE"]:format(zone), chatType = "CHANNEL", join = zone, off = full }
    end
    -- The addon's own page: its settings window, and the keyboard's place.
    local own = { { label = L["SETTINGS_SLICE"], settings = true }, { label = L["MOVE_SLICE"], move = true } }
    local pages = { { title = L["WHEEL_TALK"], picks = talk }, { title = L["WHEEL_WHISPERS"], picks = people } }
    if anyBnet then pages[#pages + 1] = { title = L["WHEEL_BNET"], picks = bnet } end
    pages[#pages + 1] = { title = L["WHEEL_CHANNELS"], picks = channels }
    pages[#pages + 1] = { title = L["TITLE"], picks = own }
    return pages
end

-- Everyone a whisper can reach now, for the name search: Battle.net friends by BattleTag and by the character they
-- play (a Battle.net whisper; none for a friend in this game only), those offline by BattleTag too (the game's
-- friends list whispers any Battle.net friend; they count least), the characters Battle.net friends play here (a
-- whisper to the character), WoW friends, the guild, the group, the target; the newest whisper partners count most.
-- Given a kind ("WHISPER" or "BN_WHISPER"), only the whispers of that kind.
function ns.WhisperNames(only)
    local list, seen, recent = {}, {}, {}
    local name, kind = ChatFrameUtil.GetLastTellTarget()
    local rank = 0
    while name and name ~= "" and rank < 10 and not recent[name] do
        rank = rank + 1
        recent[name] = RECENT / rank
        name, kind = ChatFrameUtil.GetNextTellTarget(name, kind)
    end
    local function Add(label, chatType, target, chance)
        if only and chatType ~= only then return end
        if type(label) ~= "string" or type(target) ~= "string" or label == "" then return end
        if issecretvalue and (issecretvalue(label) or issecretvalue(target)) then return end
        local key = ns.Lower(label) .. "\0" .. target
        if seen[key] then return end
        seen[key] = true
        local entry = { label = label, chatType = chatType, tellTarget = target,
            chance = math.max(chance, recent[target] or 0) }
        list[#list + 1] = entry
        return entry
    end
    for i = 1, BNGetNumFriends and BNGetNumFriends() or 0 do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        local game = info and info.gameAccountInfo
        local online = game and game.isOnline
        if info and not (TITLE and info.friendLevel == TITLE) then
            local entry = Add(info.battleTag and info.battleTag:match("^[^#]+"), "BN_WHISPER", info.accountName,
                online and FRIEND or OFFLINE)
            if entry and not online then
                entry.offline, entry.favorite = true, info.isFavorite == true
                entry.lastOnline = type(info.lastOnlineTime) == "number" and info.lastOnlineTime or 0
            end
            if online then Add(game.characterName, "BN_WHISPER", info.accountName, FRIEND) end
        end
        if online then
            local character = CharacterOf(info)
            if character then
                local label = type(game.characterName) == "string" and game.characterName ~= "" and game.characterName
                    or character:match("^[^%-]+")
                Add(label, "WHISPER", character, FRIEND)
            end
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
    if not pick or pick.join or not box.GetChatType or box:GetChatType() ~= pick.chatType then return false end
    if pick.tellTarget then return box:GetTellTarget() == pick.tellTarget end
    if pick.channelTarget then return tonumber(box:GetChannelTarget()) == pick.channelTarget end
    return true
end

-- The zone's own channels by their rows in the game's ChatChannels table, the ones that join by themselves and
-- LookingForGroup: General, Trade, LocalDefense, LookingForGroup, Services, TradeLocal, OOC. The server's list
-- also holds test discussions and Chromie Time, no player's pick.
local ZONE_CHANNELS = { 1, 2, 22, 26, 42, 46, 47 }

-- Those the server has here and the player is not in.
function ns.ChannelsToJoin()
    local here, list = {}, {}
    for _, name in ipairs(EnumerateServerChannels and { EnumerateServerChannels() } or {}) do here[name] = true end
    for _, id in ipairs(ZONE_CHANNELS) do
        local name = C_ChatInfo.GetChannelShortcutForChannelID(id)
        if name and here[name] and (GetChannelName(name) or 0) == 0 then list[#list + 1] = name end
    end
    return list
end

-- A join waits for A: the game's own /join runs from a secure button on the player's press, so the chat window
-- lists the channel in the game's name (written by our code, its lines would run in ours). Any other pad button
-- gives up. Bindings and the button's text are a fight's to refuse: no join waits in one.
local JOIN_KEYS = { "PAD2", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADDUP",
    "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PADLSTICK", "PADRSTICK", "PADBACK", "PADFORWARD" }
local join = {}

function ns.DisarmJoin()
    local armed = join.armed
    join.armed = nil
    if not join.cancel then return armed end
    if InCombatLockdown() then
        join.cancel:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        ClearOverrideBindings(join.cancel)
    end
    return armed
end

-- pressed() once A has run the join, gaveUp() on any other button; false in a fight.
function ns.ArmJoin(name, pressed, gaveUp)
    if InCombatLockdown() then return false end
    if not join.button then
        -- starts shown: binding targets, a pixel off the screen, as ClassicUIForever's pad buttons
        join.button = CreateFrame("Button", "FlickChatJoin", UIParent, "SecureActionButtonTemplate")
        join.cancel = CreateFrame("Button", "FlickChatJoinCancel", UIParent)
        for _, target in ipairs({ join.button, join.cancel }) do
            target:SetSize(1, 1)
            target:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
            target:EnableMouse(false)
        end
        join.button:RegisterForClicks("AnyDown")
        join.button:SetAttribute("type", "macro")
        join.button:SetAttribute("useOnKeyDown", true)
        join.button:SetScript("PostClick", function()
            local armed = ns.DisarmJoin()
            if armed then armed.pressed() end
        end)
        join.cancel:SetScript("OnClick", function()
            local armed = ns.DisarmJoin()
            if armed then armed.gaveUp() end
        end)
        join.cancel:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            if not join.armed then ClearOverrideBindings(self) end
        end)
    end
    join.armed = { pressed = pressed, gaveUp = gaveUp }
    join.button:SetAttribute("macrotext", "/join " .. name)
    SetOverrideBindingClick(join.cancel, true, "PAD1", "FlickChatJoin")
    for _, key in ipairs(JOIN_KEYS) do SetOverrideBindingClick(join.cancel, true, key, "FlickChatJoinCancel") end
    return true
end

-- done(number) once the game has numbered the channel, done() if it has not after a few seconds.
local awaiting
local function AwaitEnd(id)
    local done = awaiting.done
    awaiting.timer:Cancel()
    awaiting = nil
    ns.events:UnregisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    done(id)
end

function ns.AwaitChannel(name, done)
    if awaiting then awaiting.timer:Cancel() end
    awaiting = { name = name, done = done }
    awaiting.timer = C_Timer.NewTimer(5, function()
        local id = GetChannelName(name) or 0
        AwaitEnd(id ~= 0 and id or nil)
    end)
    ns.events:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    local id = GetChannelName(name) or 0
    if id ~= 0 then AwaitEnd(id) end
end

function ns.JoinHeard()
    local id = awaiting and GetChannelName(awaiting.name)
    if id and id ~= 0 then AwaitEnd(id) end
end

SLASH_FLICKCHAT1 = "/flick"
SLASH_FLICKCHAT2 = "/flickchat"
SLASH_FLICKCHAT3 = "/fc"
SlashCmdList.FLICKCHAT = function(msg)
    -- every setting a slash command sets is the profile's
    local db = ns.profile
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
