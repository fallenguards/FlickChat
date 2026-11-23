date = os.date
-- lua tools/tests/smoke_test.lua <addon dir>: loads every file the toc lists under stubbed game frames, then
-- drives the keyboard through its own stick and button handlers and checks what comes of it.
local dir = arg[1]
math.atan2 = math.atan2 or math.atan
local now = 100
function GetTime() return now end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetLocale() return "enUS" end
function GetBindingText(key) return "[" .. key .. "]" end
function IsUsingGamepad() return true end
-- the mouse pointer, standing still unless a test moves it
function GetCursorPosition() return 0, 0 end
focus = nil
function GetCurrentKeyBoardFocus() return focus end
function GetNumGroupMembers() return 2 end
function IsInRaid() return false end
function UnitName(u) if u == "party1" then return "Arthas" end end
function IsInGuild() return false end
function GetZoneText() return "Elwynn Forest" end
function GetSubZoneText() return "Goldshire" end
issecretvalue = function() return false end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_CHAT_WINDOWS = 1
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior" }
SlashCmdList = {}
GameFontNormal = {}
Enum = Enum or { UITextureSliceMode = { Stretched = 0 } }
C_Texture = { GetAtlasInfo = function() return { width = 32, height = 32 } end }
-- the game's border: one piece of it, to see it is left alone
NineSliceLayouts = { Dialog = {} }
NineSliceUtil = { ApplyLayoutByName = function(frame)
    frame.TopEdge = frame:CreateTexture(nil, "BORDER")
    -- a corner at its art's own size, as the game's layout sets it
    frame.TopLeftCorner = frame:CreateTexture(nil, "BORDER")
    frame.TopLeftCorner:SetSize(32, 32)
end }
MinimalSliderWithSteppersMixin = { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
SOUNDKIT = {}
-- the game's red error text, where a refusal goes: what it was asked to say
red = {}
UIErrorsFrame = { AddMessage = function(_, text) red[#red + 1] = text end }
function PlaySound() end
local cvars = { GamePadEnable = "1", GamePadEmulateCtrl = "PADRSHOULDER", GamePadEmulateShift = "NONE" }
function GetCVar(k) return cvars[k] end
function GetCVarBool(k) return cvars[k] == "1" end
bindings = { ["CTRL-PADBACK"] = "TOGGLEWORLDMAP" }
function GetBindingAction(k) return bindings[k] or "" end
function GetBindingKey(a) local out = {} for k, v in pairs(bindings) do if v == a then out[#out + 1] = k end end return unpack(out) end
function SetBinding(k, a) bindings[k] = a end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function InCombatLockdown() return false end
overrides = {}
function hooksecurefunc(name, fn) if type(name) == 'string' then local old = _G[name] _G[name] = function(...) old(...) fn(...) end end end
function SetItemRef() end
function ClearOverrideBindings() overrides = {} end
function SetOverrideBindingClick(owner, priority, key, button) overrides[key] = button end
unpack = unpack or table.unpack
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.dead = true end } timers[#timers + 1] = t return t end,
    NewTicker = function(_, fn) lastTick = fn return { Cancel = function() end } end,
}
padDown = {}
C_GamePad = { ButtonBindingToIndex = function(b) return ({ PADBACK = 4, PADLTRIGGER = 6, PADRTRIGGER = 7, PADLSHOULDER = 9, PADRSHOULDER = 10 })[b] end,
    GetDeviceMappedState = function() return { buttons = padDown, axes = { 0, -1 } } end,
    GetActiveDeviceID = function() return 1 end, ButtonIndexToBinding = function(i) return i == 6 and "PADLTRIGGER" or nil end,
    -- like the game's, the mapped list counts from 1
    GetDeviceRawState = function() return { rawButtons = { true }, rawAxes = { 0.5 } } end }
C_CVar = { GetCVar = function(name) return cvars[name] end }
function IsShiftKeyDown() return true end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
C_FriendList = { GetNumFriends = function() return 1 end,
    GetFriendInfoByIndex = function() return { name = "Arnold-Realm", connected = true } end }
-- Battle.net friends online: one by BattleTag, playing a character here; one a friend in this game only, whom the
-- game whispers by character (its own target for them)
BNET_CLIENT_WOW, WOW_PROJECT_ID = "WoW", 99
Enum.BattleNetFriendLevel = { BattleTag = 1, RealID = 2, Title = 3 }
local bnetFriends = {
    { bnetAccountID = 1, battleTag = "Aragorn#1234", accountName = "|Kq1|k", friendLevel = 1,
        gameAccountInfo = { isOnline = true, characterName = "Strider", realmName = "Rivendell", clientProgram = "WoW",
            wowProjectID = 99, isInCurrentRegion = true } },
    { bnetAccountID = 2, battleTag = "Legolas#5678", accountName = "|Kq2|k", friendLevel = 3,
        gameAccountInfo = { isOnline = true, characterName = "Greenleaf", realmName = "Mirkwood", clientProgram = "WoW",
            wowProjectID = 99, isInCurrentRegion = true } },
    -- offline: a Battle.net whisper reaches them still (the game's friends list whispers any Battle.net friend)
    { bnetAccountID = 3, battleTag = "Gimli#4321", accountName = "|Kq3|k", friendLevel = 1, lastOnlineTime = 100,
        gameAccountInfo = { isOnline = false } },
    { bnetAccountID = 4, battleTag = "Boromir#2468", accountName = "|Kq4|k", friendLevel = 1, lastOnlineTime = 200,
        gameAccountInfo = { isOnline = false } },
    { bnetAccountID = 5, battleTag = "Frodo#1357", accountName = "|Kq5|k", friendLevel = 1, lastOnlineTime = 50,
        isFavorite = true, gameAccountInfo = { isOnline = false } },
}
function BNGetNumFriends() return #bnetFriends end
C_BattleNet = { GetFriendAccountInfo = function(i) return bnetFriends[i] end,
    GetDefaultTitleWhisperTarget = function(id) return id == 2 and "Greenleaf-Mirkwood" or nil end }
LE_PARTY_CATEGORY_INSTANCE = 2
function IsInGroup() return false end
function UnitIsPlayer(u) return u == "target" end
function UnitIsUnit() return false end
function GetUnitName() return "Varian" end
function GetChannelList() return 1, "General", false, 2, "Trade", false, 3, "Muted", true end
-- the zone's channels: two to join and one no player's pick; a join is numbered only when the test says so
local channelNumbers = { General = 1, Trade = 2, Muted = 3 }
function GetChannelName(name) return channelNumbers[name] or 0 end
function EnumerateServerChannels() return "General", "Trade", "LookingForGroup", "ChromieTime", "Services" end
local channelsLeft = {}
function LeaveChannelByName(name) channelsLeft[#channelsLeft + 1] = name end
CHAT_MSG_SAY, CHAT_MSG_PARTY, CHAT_MSG_GUILD, CHAT_MSG_RAID = "Say", "Party", "Guild", "Raid"
local tells, tellKinds = { "Jaina", "Thrall" }, {}
ChatFrameUtil = {
    GetLastTellTarget = function() return tells[1], tells[1] and (tellKinds[tells[1]] or "WHISPER") end,
    GetNextTellTarget = function(name)
        for i, t in ipairs(tells) do
            if t == name then return tells[i + 1], tells[i + 1] and (tellKinds[tells[i + 1]] or "WHISPER") end
        end
    end,
    -- the game's: the character it whispers for a Battle.net name that is a friend in this game only
    GetCharacterWhisperTargetIfTitleFriend = function(name)
        for _, friend in ipairs(bnetFriends) do
            if friend.accountName == name then return C_BattleNet.GetDefaultTitleWhisperTarget(friend.bnetAccountID) end
        end
    end,
}

local openedCategory
Settings = {
    RegisterVerticalLayoutCategory = function(name)
        return { name = name, GetID = function() return 77 end }, { AddInitializer = function() end }
    end,
    RegisterCanvasLayoutSubcategory = function(category, frame) category.frame = frame end,
    RegisterCanvasLayoutCategory = function(frame, name) return { name = name, frame = frame } end,
    RegisterProxySetting = function(_, variable, kind, name, default, get, set)
        local key = variable:match("_(%a+)$")
        Settings.rows[key] = { tbl = setmetatable({}, { __index = function() return get() end,
            __newindex = function(_, _, v) set(v) end }) }
        return Settings.rows[key]
    end,
    rows = {},
    CreateCheckbox = function() end, CreateDropdown = function() end, CreateSlider = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function() return { Add = function() end, GetData = function() return {} end } end,
    RegisterAddOnCategory = function(category) Settings.registered = category end,
    OpenToCategory = function(id) openedCategory = id end,
}
addonSent = {}
C_ChatInfo = { RegisterAddonMessagePrefix = function() end, InChatMessagingLockdown = function() return false end,
    SendAddonMessage = function(prefix, text, kind) addonSent[#addonSent + 1] = prefix .. " " .. text .. " " .. kind end,
    GetChannelShortcutForChannelID = function(id)
        return ({ [1] = "General", [2] = "Trade", [22] = "LocalDefense", [26] = "LookingForGroup", [42] = "Services",
            [36] = "ChromieTime" })[id] or ""
    end }
time = os.time
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "1.2.0" or "FlickChat" end,
    -- a language folder (Packs/<name>): its files run, as the game loads it on demand
    LoadAddOn = function(name)
        local toc = io.open(dir .. "/Packs/" .. name .. "/" .. name .. ".toc")
        if not toc then return false, "MISSING" end
        for line in toc:lines() do
            line = line:gsub("\r", "")
            if line ~= "" and line:sub(1, 1) ~= "#" then assert(loadfile(dir .. "/Packs/" .. name .. "/" .. line))(name, {}) end
        end
        toc:close()
        return true
    end }

local frames = {}
local generic = {}
function generic.SetScript(self, name, fn) self.scripts[name] = fn end
function generic.GetScript(self, name) return self.scripts[name] end
function generic.HookScript(self, name, fn) self.hooks = self.hooks or {}; self.hooks[name] = fn end
function generic.Show(self) if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function generic.Hide(self) if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function generic.IsShown(self) return self.shown end
function generic.SetText(self, t) self.text = t end
function generic.SetShown(self, on) if on then generic.Show(self) else generic.Hide(self) end end
function generic.SetVerticalScroll(self, v) self.scrolled = v end
function generic.GetVerticalScroll(self) return self.scrolled or 0 end
function generic.GetText(self) return self.text end
function generic.GetStringWidth(self) return #(self.text or "") * 12 end
function generic.GetStringHeight(self) return 16 end
function generic.GetUnboundedStringWidth(self) return #(self.text or "") * 12 end
function generic.GetFontString(self) self.fs = self.fs or setmetatable({ text = "" }, { __index = generic }) return self.fs end
function generic.SetChecked(self, v) self.checked = v end
function generic.GetChecked(self) return self.checked end
function generic.SetValue(self, v) self.value = v end
function generic.SetWidth(self, w) assert(type(w) == "number", "SetWidth " .. tostring(w)) self.w = w end
function generic.SetHeight(self, h) assert(type(h) == "number", "SetHeight " .. tostring(h)) self.h = h end
function generic.SetSize(self, w, h) generic.SetWidth(self, w) generic.SetHeight(self, h) end
function generic.GetWidth(self) return self.w or 100 end
function generic.GetEffectiveScale() return 1 end
function generic.GetScale() return 1 end
function generic.CreateAnimationGroup(self)
    local anim = { played = false }
    local piece = setmetatable({}, { __index = function() return function() end end })
    return setmetatable(anim, { __index = function(t, k)
        if k == "CreateAnimation" then return function() return piece end end
        if k == "Play" then return function(a) a.played = true end end
        if k == "Stop" then return function(a) a.played = false end end
        return function() end
    end })
end
function generic.GetHeight(self) return self.h or 20 end
function generic.GetTop() return 300 end
function generic.GetLeft() return 0 end
function generic.GetBottom() return 0 end
function generic.GetFrameLevel() return 1 end
function generic.GetCenter() return 300, 100 end
function generic.GetParent(self) return self.parent end
function generic.SetFont(self, f, size) assert(type(size) == "number") self.font, self.fontSize, self.fontPath = true, size, f end
function generic.SetAlpha(self, alpha) self.alpha = alpha end
function generic.SetColorTexture(self, r, g, b, a) self.color = { r, g, b, a or 1 } end
function generic.SetPoint(self, ...) for i = 1, select("#", ...) do local v = select(i, ...) assert(v ~= nil or i > 1, "nil point arg") end end
function generic.SetTextColor(self, r, g, b) assert(r and g and b, "color") self.textColor = { r, g, b } end
function generic.GetTextColor(self)
    local c = self.textColor or { 1, 1, 1 }
    return c[1], c[2], c[3]
end
function generic.SetAttribute(self, key, value) self.attrs = self.attrs or {} self.attrs[key] = value end
function generic.EnableGamePadButton(self, on) self.padButtons = on end
local function Obj(parent)
    local o = { scripts = {}, shown = false, text = "", parent = parent }
    return setmetatable(o, { __index = function(t, k)
        if generic[k] then return generic[k] end
        if k == "CreateTexture" or k == "CreateFontString" or k == "CreateMaskTexture" then
            return function(self)
                local c = Obj(self)
                c.shown = true
                self.regions = self.regions or {}
                self.regions[#self.regions + 1] = c
                return c
            end
        end
        if k == "RegisterEvent" then return function(self, event) self.events = self.events or {} self.events[event] = true end end
        if k == "UnregisterEvent" then return function(self, event) if self.events then self.events[event] = nil end end end
        -- any other method of the game's: there on every frame, and it wants its frame (a field of ours named
        -- like one, called with a dot, is an error in the game)
        if k:match("^%u") then
            return function(self) assert(type(self) == "table", k .. " called without its frame") end
        end
    end })
end
function CreateSettingsButtonInitializer() return {} end
function CreateFrame(_, name, parent)
    local f = Obj(parent)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = Obj()
function UIParent.GetWidth() return 1920 end
function UIParent.GetHeight() return 1080 end
function generic.HasFocus(self) return focus == self end

local sent = {}
local box = Obj(UIParent)
box.shown = false
box.scripts.OnEnterPressed = function(self) sent[#sent + 1] = self.text; self.text = ""; generic.Hide(self) end
box.scripts.OnEscapePressed = function(self) if (self.text or "") ~= "" then self.text = "" else generic.Hide(self) end end
function box.HighlightText(self, a, b) self.hl = { a, b } end
function box.GetTextInsets() return 40, 13, 0, 0 end
function box.GetFont() return "Fonts\\FRIZQT__.TTF", 14, "" end
box.attr = { chatType = "SAY" }
function box.SetChatType(self, v) self.attr.chatType = v end
function box.GetChatType(self) return self.attr.chatType end
function box.SetTellTarget(self, v) self.attr.tellTarget = v end
function box.GetTellTarget(self) return self.attr.tellTarget end
function box.SetChannelTarget(self, v) self.attr.channelTarget = v end
function box.GetChannelTarget(self) return self.attr.channelTarget or 0 end
function box.UpdateHeader(self) self.header = self.attr.chatType .. ":" .. tostring(self.attr.tellTarget or self.attr.channelTarget or "") end
ChatFrame1EditBox = box
-- the game's controller cursor, there before the addon loads
SmartNavigation = Obj(UIParent)

local ns = {}
-- every file the toc lists, in its order
local loaded = 0
for line in io.lines(dir .. "/FlickChat.toc") do
    line = line:gsub("\r", ""):gsub("\\", "/")
    if line ~= "" and line:sub(1, 1) ~= "#" then
        assert(loadfile(dir .. "/" .. line))("FlickChat", ns)
        loaded = loaded + 1
    end
end
assert(loaded >= 5, "the toc lists too few files")
ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "FlickChat")
ns.db.lessonDone = true
-- the hint line's tip for the R3 hold has checks of its own
ns.db.uses.move = 3

local function Open()
    box.text = ""
    generic.Show(box)
    focus = box
    box.hooks.OnEditFocusGained(box)
end
local kb = _G.FlickChatKeyboard
local function Hidden()
    focus = nil
    box.hooks.OnEditFocusLost(box)
end
box.scripts.OnHide = Hidden

local VEC = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
local function Flick(digit)
    local d = tonumber(digit)
    local stick = d <= 4 and "Left" or "Right"
    local v = VEC[(d - 1) % 4 + 1]
    local kbf = _G.FlickChatKeyboard
    now = now + 0.05
    kbf.scripts.OnGamePadStick(kbf, stick, v[1] * 0.5, v[2] * 0.5, 0.5)
    kbf.scripts.OnGamePadStick(kbf, stick, v[1], v[2], 1)
    now = now + 0.05
    kbf.scripts.OnGamePadStick(kbf, stick, 0, 0, 0)
    now = now + 0.2
end
local function Type(word) for d in ns.Dict.KeyOf(word):gmatch("%d") do Flick(d) end end
local function Press(b)
    local kbf = _G.FlickChatKeyboard
    lastTick = nil
    kbf.scripts.OnGamePadButtonDown(kbf, b)
    -- View: one look with it down, then let go
    if b == "PADBACK" and lastTick then padDown[5] = true lastTick() padDown[5] = nil lastTick() end
    kbf.scripts.OnGamePadButtonUp(kbf, b)
end

local failed = 0
local function Is(what, got, want)
    if got == want then
        print("ok    " .. what)
    else
        failed = failed + 1
        print(("FAIL  %s: got %s, wanted %s"):format(what, tostring(got), tostring(want)))
    end
end
local function Has(what, text, piece)
    Is(what .. " (" .. piece .. ")", tostring(text):find(piece, 1, true) ~= nil, true)
end
-- what fn writes to chat, its lines joined
local function ChatDuring(fn)
    local lines, before = {}, print
    print = function(text) lines[#lines + 1] = tostring(text) end
    local ok, err = pcall(fn)
    print = before
    assert(ok, err)
    return table.concat(lines, " | ")
end
local function Down(b) kb.scripts.OnGamePadButtonDown(kb, b) end
local function Up(b) kb.scripts.OnGamePadButtonUp(kb, b) end
local function Told() return (kb.hint.text or ""):gsub("%s*\n%s*", " / ") end
local T = ns.DevTools()
local function SlotOf(word)
    for i = 1, 4 do
        if (T.state.slots[i] or ""):lower() == word then return ({ "PADDUP", "PADDLEFT", "PADDRIGHT", "PADDDOWN" })[i] end
    end
end
-- the left stick along the rim from one angle to another, then let go
local function Roll(from, to)
    for deg = from, to, to > from and 15 or -15 do
        local r = math.rad(deg)
        kb.scripts.OnGamePadStick(kb, "Left", math.cos(r), math.sin(r), 1)
        now = now + 0.03
    end
    kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
    now = now + 0.2
end

-- the typing line belongs to a chat window, with the game's own controller footer on it
local legend = setmetatable({ scripts = {}, shown = true, hooks = {} }, { __index = function(_, k) return generic[k] or function() end end })
legend.HookScript = function(self, name, fn) self.hooks[name] = fn end
legend.IsForbidden = function() return false end
box.chatFrame = setmetatable({ footer = { inputLegend = legend, isShown = true } }, { __index = function(_, k)
    if k == "IsForbidden" then return function() return false end end
    if k == "GetFrameStrata" then return function() return "LOW" end end
    if k == "GetID" then return function() return 1 end end
    return generic[k] or function() end
end })

-- words learned before languages were kept apart: there after the first open, as the first language's own
ns.db.learned.oldword = 5
Open()
Is("words learned before stay through the first open", ns.db.learned.oldword, 5)
Is("as the words of the language typed in", ns.db.wordsOf, "enUS")
ns.db.learned.oldword = nil
Press("PAD2")

-- a word, kept, sent
Open()
kb = _G.FlickChatKeyboard
Is("the keyboard comes with chat", kb.shown, true)
Type("hello")
Is("flicks spell a word", box.text, "Hello")
Press("PADRTRIGGER")
Is("RT keeps it with a space", box.text, "Hello ")
Type("there")
Press("PAD1")
Is("A sends the line", sent[#sent], "Hello there")

-- the symbols page stays up after any symbol: X or RT leaves it
Open()
Type("hello")
Press("PAD3")
Flick(3)
Flick(4)
Is("the symbols page stays after ? and !", T.state.symbols, true)
Is("marks follow one another", box.text, "Hello?! ")
Press("PAD3")
Is("X leaves the symbols page", T.state.symbols, false)
Press("PAD3")
Press("PADRTRIGGER")
Is("RT leaves the symbols page", T.state.symbols, false)
Press("PAD2")

-- a zone channel not joined: the Channels page offers it; letting go asks on the wheel, A runs the game's own
-- /join, and the line types there once the game has numbered the channel
local function WheelTo(title)
    for _ = 1, 6 do
        local w = T.state.wheel
        if w.pages[w.page].title == title then return w.pages[w.page].picks end
        Press("PADRSHOULDER")
    end
    return {}
end
local function WheelFlick(x, y)
    kb.scripts.OnGamePadStick(kb, "Left", x, y, 1)
    now = now + 0.05
    kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
    now = now + 0.2
end
local function JoinArmed()
    Press("PAD4")
    local picks = WheelTo("Channels")
    WheelFlick(1, 0)
    return picks
end
Open()
local picks = JoinArmed()
local wheelFrame = T.Wheel()
Is("the Channels page offers a channel not joined", picks[3] and picks[3].label, "Join LookingForGroup")
Is("and the next one", picks[4] and picks[4].label, "Join Services")
Is("a channel the server lists that is no player's pick is left off", #picks, 4)
Is("letting go on it keeps the wheel up to ask", T.state.wheel ~= nil, true)
Has("the wheel asks", wheelFrame.ask.text, "Join LookingForGroup?")
Is("over its middle, in the title's place", wheelFrame.ask.shown and not wheelFrame.title.shown, true)
Has("with A to join", wheelFrame.answer.text, "[PAD1]")
Has("and B to go back", wheelFrame.answer.text, "[PAD2]")
Is("the other labels make room", wheelFrame.slices[1].label.shown, false)
local joinButton, joinCancel = _G.FlickChatJoin, _G.FlickChatJoinCancel
Is("the game's own /join waits on the button", joinButton and joinButton.attrs.macrotext, "/join LookingForGroup")
Is("for the press of A", joinButton and joinButton.attrs.useOnKeyDown, true)
Is("A is bound to it", overrides.PAD1, "FlickChatJoin")
Is("any other button gives up", overrides.PAD2 == "FlickChatJoinCancel" and overrides.PADBACK == "FlickChatJoinCancel", true)
Is("the keyboard lets the pad's buttons go meanwhile", kb.padButtons, false)
local typedBefore = box.text
Flick(1)
Is("the sticks type nothing meanwhile", box.text, typedBefore)
Is("the line stays put", box.attr.channelTarget == 4, false)
joinButton.scripts.PostClick(joinButton, "LeftButton", true)
Is("A closes the wheel", T.state.wheel, nil)
Is("takes the bindings away", next(overrides), nil)
Is("and gives the keyboard the pad's buttons again", kb.padButtons, true)
Is("the game's channel notices are heard until the channel is numbered", ns.events.events.CHAT_MSG_CHANNEL_NOTICE, true)
channelNumbers.LookingForGroup = 4
ns.events.scripts.OnEvent(ns.events, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED")
Is("then the line types there", box.header, "CHANNEL:4")
Is("and the notices are let go", ns.events.events.CHAT_MSG_CHANNEL_NOTICE, nil)
Is("a channel to join is never the one typed in", ns.IsChannel(box, { chatType = "CHANNEL", join = "Services" }), false)
picks = JoinArmed()
Is("a joined channel leaves the slices to join", picks[3] and picks[3].label, "Join Services")
joinCancel.scripts.OnClick(joinCancel)
Is("another button goes back to the wheel", T.state.wheel ~= nil and T.state.wheel.confirm == nil, true)
Is("with its labels", wheelFrame.slices[1].label.shown and wheelFrame.title.shown and not wheelFrame.ask.shown, true)
Is("and takes the bindings away", next(overrides), nil)
Is("the keyboard has the pad's buttons again", kb.padButtons, true)
Is("and the line stays where it was", box.header, "CHANNEL:4")
Press("PAD2")
JoinArmed()
joinButton.scripts.PostClick(joinButton, "LeftButton", true)
local joinSaid = ChatDuring(function()
    for i = #timers, 1, -1 do
        -- the newest live timer is the wait for the number
        if type(timers[i]) == "table" and not timers[i].dead then timers[i].fn() break end
    end
end)
Has("a channel the game never numbers is said in the red error text", red[#red], "Could not join Services")
Is("and not in chat", joinSaid, "")
Is("and the line stays where it was", box.header, "CHANNEL:4")
JoinArmed()
generic.Hide(box)
Is("chat shut while the wheel asks takes the bindings away", next(overrides), nil)
Is("and the join with them", T.state.joinWait, nil)
box.attr.chatType, box.attr.channelTarget = "SAY", nil

-- a channel the player is in: pointing at it, X asks to leave it on the wheel; A leaves, and a line typed there
-- goes to Say
Open()
box.attr.chatType, box.attr.channelTarget = "CHANNEL", 1
Press("PAD4")
WheelTo("Channels")
kb.scripts.OnGamePadStick(kb, "Left", 0, 1, 1)
Has("pointing at a channel says X leaves it", wheelFrame.info.text, "[PAD3]")
Press("PAD3")
Has("X asks on the wheel", wheelFrame.ask.text, "Leave General?")
Has("with A to leave", wheelFrame.answer.text, "[PAD1]")
Press("PAD2")
Is("B goes back to the wheel", T.state.wheel ~= nil and T.state.wheel.confirm == nil, true)
Is("leaving nothing", #channelsLeft, 0)
kb.scripts.OnGamePadStick(kb, "Left", 0, 0.9, 0.9)
Press("PAD3")
Press("PAD1")
Is("A leaves it", channelsLeft[#channelsLeft], "General")
Is("and closes the wheel", T.state.wheel, nil)
Is("the line typed there goes to Say", box.attr.chatType, "SAY")
local held = box.text
kb.scripts.OnGamePadStick(kb, "Left", 0, 1, 1)
kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
Is("the stick still out as the wheel went types nothing", box.text, held)
Flick(1)
Is("once back at rest it types again", box.text ~= held, true)
Press("PAD2")

-- whispers to a character on one page, Battle.net whispers on the next (2026-11-22, asked on GitHub: a friend in
-- this game only is no Battle.net whisper's to reach, and the game whispers their character instead)
local function Slice(picks, label)
    for i, pick in ipairs(picks) do if pick.label == label then return i, pick end end
end
local function Titles()
    local out = {}
    for i, page in ipairs(ns.WheelPages()) do out[i] = page.title end
    return table.concat(out, ",")
end
Is("a Battle.net page after the Whispers page", Titles(), "Talk,Whispers,Battle.net,Channels,FlickChat")
local pages = ns.WheelPages()
local whispers, bnetPage = pages[2].picks, pages[3].picks
local _, strider = Slice(whispers, "Strider")
Is("a Battle.net friend's character here is on the Whispers page", strider and strider.tellTarget, "Strider-Rivendell")
Is("as a whisper to the character", strider and strider.chatType, "WHISPER")
local _, greenleaf = Slice(whispers, "Greenleaf")
Is("a friend in this game only: the character the game whispers", greenleaf and greenleaf.tellTarget,
    "Greenleaf-Mirkwood")
local bnetOnWhispers = false
for _, pick in ipairs(whispers) do bnetOnWhispers = bnetOnWhispers or pick.chatType == "BN_WHISPER" end
Is("no Battle.net whisper on the Whispers page", bnetOnWhispers, false)
local _, aragorn = Slice(bnetPage, "Aragorn")
Is("the Battle.net page whispers the friend by Battle.net", aragorn and (aragorn.chatType .. " " .. aragorn.tellTarget),
    "BN_WHISPER |Kq1|k")
Is("never a friend in this game only", Slice(bnetPage, "Legolas") == nil and Slice(bnetPage, "Greenleaf") == nil, true)
Is("each page's search keeps to its kind", bnetPage[#bnetPage].naming .. " " .. whispers[#whispers].naming,
    "BN_WHISPER WHISPER")
local kinds = {}
for _, name in ipairs(ns.WhisperNames("BN_WHISPER")) do kinds[name.chatType] = true end
Is("the Battle.net search finds Battle.net whispers alone", kinds.BN_WHISPER and not kinds.WHISPER, true)
kinds = {}
for _, name in ipairs(ns.WhisperNames("WHISPER")) do kinds[name.chatType] = true end
Is("the character search finds whispers to characters alone", kinds.WHISPER and not kinds.BN_WHISPER, true)
-- the wheel: letting go on a slice sets the line's whisper
local function WheelSlice(i)
    local angle = math.rad(90 - (i - 1) * 45)
    WheelFlick(math.cos(angle), math.sin(angle))
end
Open()
Press("PAD4")
WheelSlice(Slice(WheelTo("Battle.net"), "Aragorn"))
Is("Aragorn on the Battle.net page: a Battle.net whisper", box.attr.chatType .. " " .. tostring(box.attr.tellTarget),
    "BN_WHISPER |Kq1|k")
Press("PAD4")
Is("the wheel opens on the page of the whisper typed to", T.state.wheel.pages[T.state.wheel.page].title, "Battle.net")
WheelSlice(Slice(WheelTo("Whispers"), "Strider"))
Is("Strider on the Whispers page: a whisper to the character",
    box.attr.chatType .. " " .. tostring(box.attr.tellTarget), "WHISPER Strider-Rivendell")
Press("PAD4")
local bnetPicks = WheelTo("Battle.net")
WheelSlice(#bnetPicks)
local searched = T.state.naming and T.state.naming.names or {}
kinds = {}
for _, name in ipairs(searched) do kinds[name.chatType] = true end
Is("the Battle.net page's search lists Battle.net friends alone", #searched > 0 and not kinds.WHISPER, true)
Press("PAD2")
Press("PAD2")
box.attr.chatType, box.attr.tellTarget = "SAY", nil
-- a friend in this game only, whispered last by Battle.net: on the Whispers page by character
tells[1], tellKinds["|Kq2|k"] = "|Kq2|k", "BN_WHISPER"
pages = ns.WheelPages()
local _, back = Slice(pages[2].picks, "Greenleaf")
Is("a friend in this game only whispered last: by character", back and (back.chatType .. " " .. back.tellTarget),
    "WHISPER Greenleaf-Mirkwood")
Is("not on the Battle.net page", Slice(pages[3].picks, "|Kq2|k") == nil, true)
-- the target whispered last: the partners before them still listed
tells[1] = "Varian"
Is("the target whispered last leaves the other partners listed", Slice(ns.WheelPages()[2].picks, "Thrall") ~= nil, true)
tells[1], tellKinds["|Kq2|k"] = "Jaina", nil
-- Battle.net friends offline: on the Battle.net page after those online, favourites first, then the most lately
-- online (2026-11-22: "you can send messages to people even while they're offline... ofc prio online ppl")
local order = {}
for _, pick in ipairs(ns.WheelPages()[3].picks) do order[#order + 1] = pick.label end
Is("online first, then offline: favorites, then the most lately online", table.concat(order, ","),
    "Aragorn,Frodo,Boromir,Gimli,Find a name")
-- greyed on the wheel as the game's friends list greys them ("yes do that")
Open()
Press("PAD4")
WheelTo("Battle.net")
local function LabelColor(i) return table.concat(wheelFrame.slices[i].label.textColor, " ") end
Is("an offline friend's slice is the friends list's gray", LabelColor(4), "0.486 0.518 0.541")
Is("one online stays white", LabelColor(1), "1 1 1")
Is("so does the name search", LabelColor(5), "1 1 1")
Press("PAD2")
Press("PAD2")
local offlineFound = false
for _, name in ipairs(ns.WhisperNames("BN_WHISPER")) do offlineFound = offlineFound or name.label == "Gimli" end
Is("the Battle.net search finds a friend offline", offlineFound, true)
kinds = {}
for _, name in ipairs(ns.WhisperNames("WHISPER")) do kinds[name.label] = true end
Is("no whisper to a character for a friend offline", kinds.Gimli, nil)
bnetFriends[1].gameAccountInfo.isOnline = false
Is("every Battle.net friend offline: the page stays", Titles(), "Talk,Whispers,Battle.net,Channels,FlickChat")
-- no Battle.net friend at all but one in this game only (no Battle.net whisper's): no Battle.net page
local kept = { unpack(bnetFriends) }
for i = #bnetFriends, 1, -1 do
    if bnetFriends[i].friendLevel ~= 3 then table.remove(bnetFriends, i) end
end
Is("only a friend in this game only: no Battle.net page", Titles(), "Talk,Whispers,Channels,FlickChat")
for i, friend in ipairs(kept) do bnetFriends[i] = friend end
bnetFriends[1].gameAccountInfo.isOnline = true

-- LT held erases word by word, from its press and release (the game's controller interface)
Open()
for _ = 1, 6 do Type("hello") Press("PADRTRIGGER") end
Is("LT is no modifier key here: no watch on the pad", T.state.ltModifier, nil)
Down("PADLTRIGGER")
local before = box.text
T.state.holdTimer.fn()
local once = box.text
Is("LT held erases a word", #once < #before, true)
lastTick()
Is("and another while it stays down", #box.text < #once, true)
Up("PADLTRIGGER")
Is("its release ends it", T.state.holdTicker, nil)
Press("PADBACK")
Press("PAD2")

-- Outside it the game's settings make LT its Shift: a tap comes on letting go, a hold not at all; the keyboard
-- reads the hold off the pad (its list counts from 1: LT's index 6 is entry 7)
cvars.GamePadEmulateShift = "PADLTRIGGER"
lastTick = nil
Open()
local watch = lastTick
Is("LT as the game's Shift is watched on the pad", T.state.ltModifier == true and watch ~= nil, true)
for _ = 1, 6 do Type("hello") Press("PADRTRIGGER") end
before = box.text
padDown[7] = true
watch()
now = now + 0.3
watch()
Is("held under the hold time, nothing goes", box.text, before)
now = now + 0.2
watch()
once = box.text
Is("held past it, a word goes", #once < #before, true)
now = now + 0.25
watch()
Is("and another while it stays down", #box.text < #once, true)
padDown[7] = nil
now = now + 0.05
watch()
local left = box.text
now = now + 0.05
Down("PADLTRIGGER")
Up("PADLTRIGGER")
Is("the game's tap that comes with letting go is no extra erase", box.text, left)
now = now + 1
Down("PADLTRIGGER")
Up("PADLTRIGGER")
Is("a tap erases", #box.text < #left, true)
Is("and starts no timer of its own", T.state.holdTimer, nil)
-- /flick sticks: LT's press has the pad read for a while
ns.StartStickProbe(40)
padDown[7] = true
lastTick = nil
Down("PADLTRIGGER")
Up("PADLTRIGGER")
lastTick()
padDown[7] = nil
Has("the stick probe reads the pad", table.concat(ns.db.stickProbe.lines, "\n"),
    "mapped {PADLTRIGGER a2=-1.00}; raw {1 a1=0.50}; shift true")
now = now + 60
lastTick()
Press("PADBACK")
Press("PAD2")
watch()
Is("the watch ends with the keyboard", T.state.ltModifier, nil)
cvars.GamePadEmulateShift = "NONE"

-- LT and RT down together type "/": in the controller interface each acts on its press, so the first one's
-- erase or kept word is taken back when the other comes
Open()
Has("the guide's RT column ends on LT and RT together", kb.prompts.CHORD.label:GetText(), "[PADLTRIGGER]+[PADRTRIGGER] Type /")
Type("hello")
local word = box.text
now = now + 1
Down("PADLTRIGGER")
Is("LT alone erases at once", box.text ~= word, true)
now = now + 0.1
Down("PADRTRIGGER")
Up("PADLTRIGGER")
Up("PADRTRIGGER")
Is("LT then RT together type a slash after the word, the erase taken back", box.text, word .. "/")
Is("its hold stopped", T.state.holdTimer, nil)
now = now + 1
Press("PADLTRIGGER")
Is("a later LT alone erases the slash", box.text, word)
now = now + 1
Down("PADRTRIGGER")
now = now + 0.1
Down("PADLTRIGGER")
Up("PADRTRIGGER")
Up("PADLTRIGGER")
Is("RT then LT the same, the kept word's space taken back", box.text, word .. "/")
Press("PADBACK")
Type("hello")
now = now + 1
Down("PADLTRIGGER")
now = now + 0.5
Down("PADRTRIGGER")
Up("PADLTRIGGER")
Up("PADRTRIGGER")
Is("half a second apart, each does its own", box.text:find("/", 1, true), nil)
Press("PADBACK")
Press("PAD2")

-- outside it, as the game's Shift and Ctrl, both are read off the pad and their taps on letting go are dropped
cvars.GamePadEmulateShift, cvars.GamePadEmulateCtrl = "PADLTRIGGER", "PADRTRIGGER"
lastTick = nil
Open()
watch = lastTick
Type("hello")
word = box.text
padDown[7] = true
watch()
now = now + 0.1
padDown[8] = true
watch()
Is("both down on the pad type a slash", box.text, word .. "/")
now = now + 1
watch()
Is("held on, LT's hold erases nothing", box.text, word .. "/")
padDown[7], padDown[8] = nil, nil
watch()
Down("PADLTRIGGER")
Up("PADLTRIGGER")
Down("PADRTRIGGER")
Up("PADRTRIGGER")
Is("the game's two taps on letting go do nothing more", box.text, word .. "/")
now = now + 1
Down("PADLTRIGGER")
Up("PADLTRIGGER")
Is("a later LT tap erases", box.text, word)
Press("PADBACK")
Press("PAD2")
watch()
cvars.GamePadEmulateShift, cvars.GamePadEmulateCtrl = "NONE", "PADRSHOULDER"

-- a word off the d-pad before it is fully flicked
Open()
local key = ns.Dict.KeyOf("anyone")
for i = 1, #key do
    if SlotOf("anyone") then break end
    Flick(key:sub(i, i))
end
Is("a long word reaches the d-pad early", SlotOf("anyone") ~= nil and #T.state.flicks < #key, true)
Press(SlotOf("anyone") or "PADDUP")
Is("the d-pad takes it", box.text, "Anyone ")

-- B keeps an unsent message; View clears it
Press("PAD2")
Is("B closes the keyboard", kb.shown, false)
Open()
Is("the unsent message is back", box.text, "Anyone ")
Press("PADBACK")
Is("View clears the line", box.text, "")

-- View held, the right stick scrolls the chat window by its own scroll calls, faster the further it leans; the line
-- stays, and a stick still out as View goes types nothing
local window = { offset = 0, max = 100 }
function window.GetScrollOffset(self) return self.offset end
function window.ScrollByAmount(self, n) self.offset = math.max(0, math.min(self.max, self.offset + n)) end
SELECTED_CHAT_FRAME = window
Type("hello")
local line = box.text
lastTick = nil
Down("PADBACK")
local view = lastTick
padDown[5] = true
view()
local kbf = _G.FlickChatKeyboard
kbf.scripts.OnGamePadStick(kbf, "Right", 0, 1, 1)
now = now + 0.5
view()
Is("full up for half a second scrolls ten lines up", window.offset, 10)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, -0.625, 0.625)
now = now + 1
view()
Is("leaning half the way down for a second, a quarter of the speed back", window.offset, 5)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, 0, 0)
view()
kbf.scripts.OnGamePadStick(kbf, "Left", 0, 1, 1)
now = now + 0.5
view()
Is("the left stick scrolls nothing and types nothing", window.offset == 5 and box.text == line, true)
kbf.scripts.OnGamePadStick(kbf, "Left", 0, 0, 0)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, -0.7, 0.7)
padDown[5] = nil
now = now + 0.05
view()
Up("PADBACK")
Is("letting go of View after a scroll keeps the line", box.text, line)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, 0, 0)
Is("the right stick still out as View went types nothing", box.text, line)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, -0.7, 0.7)
kbf.scripts.OnGamePadStick(kbf, "Right", 0, 0, 0)
Is("once back at rest it types again", box.text ~= line, true)
SELECTED_CHAT_FRAME = nil
Press("PADBACK")

-- outside the game's controller interface (its own bumpers on the tabs are there only inside it), View held binds LB
-- and RB to secure clicks on the chat tabs either side of the shown one; let go, the bumpers are the game's again
local tabFrames = {}
for i = 1, 3 do
    local chatFrame = Obj(UIParent)
    rawset(chatFrame, "GetName", function() return "ChatFrame" .. i end)
    _G["ChatFrame" .. i .. "Tab"] = Obj(UIParent)
    tabFrames[i] = chatFrame
end
GENERAL_CHAT_DOCK = Obj(UIParent)
GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = tabFrames
function FCFDock_GetSelectedWindow() return tabFrames[2] end
Type("hello")
line = box.text
lastTick = nil
Down("PADBACK")
local held = lastTick
padDown[5] = true
held()
Is("View held: LB clicks the tab before the shown one", overrides.PADLSHOULDER == "FlickChatTabPrev"
    and _G.FlickChatTabPrev.attrs.clickbutton == _G.ChatFrame1Tab, true)
Is("and RB the one after it", overrides.PADRSHOULDER == "FlickChatTabNext"
    and _G.FlickChatTabNext.attrs.clickbutton == _G.ChatFrame3Tab, true)
Is("each click on the press, once", _G.FlickChatTabNext.attrs.type == "click"
    and _G.FlickChatTabNext.attrs.useOnKeyDown == true, true)
-- RB's click: the game shows the next tab and hides the one left, its typing line shut with it; the new tab's line
-- opens, and the bumpers' next clicks follow the tab now shown
local opened = false
rawset(tabFrames[3], "editBox", { HasFocus = function() return false end, IsForbidden = function() return false end,
    SetFocus = function() opened = true end })
function FCFDock_GetSelectedWindow() return tabFrames[3] end
_G.FlickChatTabNext.scripts.PostClick(_G.FlickChatTabNext)
Is("after a flip the new tab's typing line opens", opened, true)
Is("and LB now clicks the tab it came from, RB nothing past the last", _G.FlickChatTabPrev.attrs.clickbutton == _G.ChatFrame2Tab
    and _G.FlickChatTabNext.attrs.clickbutton == nil, true)
padDown[10] = true
held()
padDown[10], padDown[5] = nil, nil
held()
Up("PADBACK")
Is("let go, the bumpers are the game's again", overrides.PADLSHOULDER == nil and overrides.PADRSHOULDER == nil, true)
Is("a bumper used, the line stays", box.text, line)
GENERAL_CHAT_DOCK, FCFDock_GetSelectedWindow = nil, nil
Press("PADBACK")

-- beside the chat window, in its left column: View, the stick pushed up over it and pushed down under it
Press("PADBACK")
local marks = kb.scrollMarks
Is("typing in chat shows the scroll marks", marks.shown, true)
Is("the stick up, View, the stick down", marks.up.plain .. marks.view.plain .. marks.down.plain, "[PADRSTICKUP][PADBACK][PADRSTICKDOWN]")
for _ = 1, 6 do Type("hello") Press("PADRTRIGGER") end
Is("a long line leaves them be", marks.shown, true)
Press("PADBACK")
Press("PADRSTICK")
Is("hidden hints hide them", marks.shown, false)
Press("PADRSTICK")
Is("and bring them back", marks.shown, true)

-- R3 held: the sticks move and size the keyboard from where it is; a tap hides or shows the hints as before (players
-- did not find the settings' Keyboard place and size, 2026-11-23)
do
    Has("R3's label says a hold moves the keyboard", kb.toggle.label:GetText(), "(hold: move)")
    local x0, size0 = ns.profile.moveX, ns.profile.size
    kb.GetLeft = function() return ns.profile.moveX or 0 end
    local function Push()
        local tick = lastTick
        kb.scripts.OnGamePadStick(kb, "Left", 1, 0, 1)
        now = now + 0.05
        tick()
        kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
    end
    Down("PADRSTICK")
    local hold = timers[#timers]
    Is("held, nothing moves before the hold time", T.state.move, nil)
    lastTick = nil
    hold.fn()
    Is("past it, the sticks move the keyboard", T.state.move ~= nil and not T.state.move.guide, true)
    Has("the line says how", Told(), "move the keyboard")
    Up("PADRSTICK")
    Is("letting go after the hold leaves the hints as they were", marks.shown, true)
    Is("and the move goes on", T.state.move ~= nil, true)
    Push()
    Is("the left stick carries it", (ns.profile.moveX or 0) > (x0 or 0), true)
    local said, Print = {}, print
    print = function(line) said[#said + 1] = line end
    Press("PAD1")
    print = Print
    Is("A keeps it there", T.state.move == nil and (ns.profile.moveX or 0) > (x0 or 0), true)
    Is("and says nothing in chat", #said, 0)
    Is("the keyboard stays open", kb:IsShown(), true)
    local kept = ns.profile.moveX
    Down("PADRSTICK")
    lastTick = nil
    timers[#timers].fn()
    Up("PADRSTICK")
    Push()
    Press("PAD2")
    Is("held again, then B: back where it was", T.state.move == nil and ns.profile.moveX == kept, true)
    Is("and the keyboard still open", kb:IsShown(), true)
    Press("PADRSTICK")
    Is("a tap still hides the hints", marks.shown, false)
    Press("PADRSTICK")
    Is("and shows them", marks.shown, true)
    kb.GetLeft = nil
    ns.profile.moveX, ns.profile.moveY, ns.profile.size = x0, nil, size0
end

-- The hint lines in a box like the button guide's (the settings' Hint box, on unless turned off), and the hold told
-- on that line until the player has used it (2026-11-23: bare lines were hard to read over the action bars, and
-- nothing he saw told of the hold).
do
    local uses = ns.db.uses
    local was = { move = uses.move, flick = uses.flick, take = uses.take }
    uses.move, uses.flick, uses.take = 0, 99, 99
    Press("PADRSTICK")
    Press("PADRSTICK")
    Has("the hint line tells of the hold", Told(), "to move or size the keyboard")
    Is("in a box", kb.hintBox:IsShown(), true)
    Is("never lower than its border's two corners", kb.hintBox:GetHeight() >= 64, true)
    Is("its lines over it", kb.hint.parent, kb.hintLayer)
    for _ = 1, 3 do
        Down("PADRSTICK")
        lastTick = nil
        timers[#timers].fn()
        Up("PADRSTICK")
        Press("PAD2")
    end
    Is("held three times, the line says it no more", (Told():find("move or size", 1, true)), nil)
    Has("R3's label still does", kb.toggle.label:GetText(), "(hold: move)")
    Is("Hint box is a setting", ns.optionRows.hintBox[1](), true)
    ns.optionRows.hintBox[2](false)
    Down("PADRSTICK")
    lastTick = nil
    timers[#timers].fn()
    Up("PADRSTICK")
    Has("Hint box off: the line still says what to do", Told(), "move the keyboard")
    Is("bare, as before", kb.hintBox:IsShown(), false)
    Is("and kept in the profile", ns.profile.hintBoxOff, true)
    ns.optionRows.hintBox[2](true)
    Is("on again: in the box", kb.hintBox:IsShown(), true)
    Press("PAD2")
    uses.move, uses.flick, uses.take = was.move, was.flick, was.take
end

-- quick phrases: holding A opens their page, up until A is held again, so both sticks are free (2026-11-21)
local function HoldA()
    Down("PAD1")
    local hold = timers[#timers]
    if type(hold) == "table" and not hold.dead then hold.fn() end
    Up("PAD1")
end
Open()
local count = #sent
HoldA()
Is("holding A opens the phrase page and it stays when A is let go", T.state.phrases == true and #sent == count, true)
Has("its hint says a phrase goes at once", Told(), "sends at once")
Has("and that holding A goes back", Told(), "Hold [PAD1] to go back")
Flick(5)
Is("on an empty line a phrase flicked with the right stick goes at once", #sent, count + 1)
Is("as itself", (sent[#sent] or ""):lower(), ns.Phrase(5):lower())
Open()
count = #sent
HoldA()
Press("PADRTRIGGER")
Has("after RT the hint says A sends the line", Told(), "[PAD1] sends it")
Flick(1)
Flick(6)
Is("after RT phrases join the line, nothing sent", #sent, count)
Press("PAD1")
Is("a tap of A sends them as one message", #sent, count + 1)
Has("with both phrases in it", (sent[#sent] or ""):lower(), ns.Phrase(6):lower())
Open()
count = #sent
Type("hello")
HoldA()
Flick(2)
Is("with text on the line a phrase joins it, nothing sent", #sent, count)
Has("the line holds it", (box.text or ""):lower(), ns.Phrase(2):lower())
HoldA()
Is("holding A again goes back to letters", T.state.phrases, false)
Has("the line kept", (box.text or ""):lower(), "hello")
Down("PAD1")
Flick(3)
Up("PAD1")
Is("a flick with A down still opens the page and says the phrase, and the page stays", T.state.phrases == true
    and (box.text or ""):lower():find(ns.Phrase(3):lower(), 1, true) ~= nil and #sent == count, true)
Press("PAD1")
Is("then a tap of A sends the line", #sent, count + 1)

-- profiles (GitHub issue #2; as WoW addons keep settings): each character on one, Default shared by all at first
local toc = io.open(dir .. "/FlickChat.toc"):read("*a")
Has("the toc saves a table per character", toc, "## SavedVariablesPerCharacter: FlickChatCharDB")
Is("the per character table is that one", ns.char ~= nil and ns.char == FlickChatCharDB, true)
Is("a character starts on Default", ns.ProfileName(), "Default")
Is("the settings are Default's", ns.profile == FlickChatDB.profiles.Default, true)
Is("the account keeps no setting of its own", FlickChatDB.size == nil and FlickChatDB.phrases == nil, true)
ns.SetPhrase(1, "for the horde")
local size = ns.profile.size
ns.NewProfile("  Thrall - Realm  ")
Is("a new profile: this character is on it, by the name trimmed", ns.ProfileName(), "Thrall - Realm")
Is("saved as this character's", FlickChatCharDB.profile, "Thrall - Realm")
Is("it starts as a copy of the one it came from", ns.Phrase(1) == "for the horde" and ns.profile.size == size, true)
Is("a copy, not the same tables", ns.profile.phrases ~= FlickChatDB.profiles.Default.phrases, true)
Open()
count = #sent
Type("hello")
Down("PAD1")
Press("PAD3")
Is("saving a phrase says nothing in chat (its slot shows it)", ChatDuring(function() Flick(1) Up("PAD1") end), "")
Is("a phrase saved from the keyboard (A held, X, a flick) goes into this profile", (ns.Phrase(1) or ""):lower(), "hello")
Is("Default keeps its own", FlickChatDB.profiles.Default.phrases[1], "for the horde")
Is("saving sends nothing", #sent, count)
ns.optionRows.size[2](size + 20)
ns.NextProfile(1)
Is("the next profile round from the last is Default", ns.ProfileName(), "Default")
Is("on Default its phrase and size are back", ns.Phrase(1) == "for the horde" and ns.profile.size == size, true)
Is("Default is no name kept for the character", FlickChatCharDB.profile, nil)
ns.NextProfile(-1)
Is("back the other way: Thrall's, its settings with it", ns.ProfileName() == "Thrall - Realm" and ns.profile.size == size + 20, true)
ns.NewProfile("Default")
Is("a new profile named as one already there turns to it", ns.ProfileName(), "Default")
ns.UseProfile("Thrall - Realm")
Is("copy from says nothing in chat", ChatDuring(function() ns.CopyProfile("Default") end), "")
Is("copy from: Default's settings into this profile", ns.Phrase(1) == "for the horde" and ns.profile.size == size, true)
Is("still on this profile", ns.ProfileName(), "Thrall - Realm")
ns.SetPhrase(1, "lok'tar")
Is("a reset says nothing in chat", ChatDuring(ns.ResetProfile), "")
Is("a reset: every setting of this profile back to its default", ns.Phrase(1) == "hi" and ns.profile.size == 100, true)
Is("Default untouched by it", FlickChatDB.profiles.Default.phrases[1], "for the horde")
Is("a delete says nothing in chat", ChatDuring(ns.DeleteProfile), "")
Is("a delete: the profile gone and the character on Default",
    FlickChatDB.profiles["Thrall - Realm"] == nil and ns.ProfileName() == "Default", true)
Is("deleting Default: not in chat", ChatDuring(ns.DeleteProfile), "")
Is("Default stays", FlickChatDB.profiles.Default ~= nil and ns.ProfileName() == "Default", true)
Is("refused in the red error text", red[#red], "Default cannot be deleted.")
-- a character on a profile another deleted: on Default at its next load
FlickChatCharDB.profile = "Gone"
ns.UseProfile(FlickChatCharDB.profile, true)
Is("a profile no longer there: Default", ns.ProfileName() == "Default" and FlickChatCharDB.profile == nil, true)
ns.ResetPhrases()
Is("a phrase reset clears this profile's phrases", next(ns.profile.phrases), nil)
-- the settings of a save from before profiles: Default's at the first load of this version
local older = { dbVersion = 2, size = 140, phrases = { "yo" }, shape = "above", learned = { hello = 3 }, arm = 0.5 }
ns.Migrate(older)
local moved = older.profiles and older.profiles.Default or {}
Is("an older save: its settings are Default's", moved.size == 140 and moved.phrases[1] == "yo" and moved.shape == "above", true)
Is("gone from the account, its learned words and stick reach kept",
    older.size == nil and older.shape == nil and older.learned.hello == 3 and older.arm == 0.5, true)

-- a box only passed through on a swing across is read as maybe not meant
local words = table.concat(ns.Dict.Decode("321432", "<s>", 5), " "):lower()
Has("the word finder drops a passed-through box", words, "heal")

-- the lesson: a wrong word kept is pointed out, and the chaining drill holds to one move
Hidden()
ns.db.lessonDone = false
Open()
Is("the lesson starts", T.state.lesson ~= nil, true)
Flick(1) Flick(5) Flick(8)
Press("PADRTRIGGER")
Has("a word that is not in the line is pointed out", Told(), "not in the line")
for _ = 1, 4 do Press("PADLTRIGGER") end
T.state.lesson.at = 4
Press("PADBACK")
Flick(3) Flick(2)
Is("two flicks apart do not pass the drill", T.state.lesson.stage or 1, 1)
Roll(-90, 0)
Is("one move passes its first stage", T.state.lesson.stage, 2)
Roll(-90, 180)
Is("and its second", T.state.lesson.stage, 3)
Roll(-90, 180)
Flick(2)
Is("the last stage ends on the swing across", T.state.lesson.chained, true)
ns.db.lessonDone = true

-- typing practice scores a right word and a wrong one, and sends nothing
Hidden()
count = #sent
SlashCmdList.FLICKCHAT("practice")
Open()
local pane = _G.FlickChatPractice
Is("practice opens over chat", pane ~= nil and pane.shown, true)
local first = (pane.words.text or ""):match("|cfff0e342(%a+)|r")
ns.practice.Typed(first)
Has("a right word counts", pane.foot.text, "100%")
ns.practice.Typed("zzz")
Has("a wrong one halves it", pane.foot.text, "50%")
Press("PAD2")
Is("B ends practice", ns.practice, nil)
Is("nothing was sent", #sent, count)

-- the first-login window comes up with the keyboard under it as the preview
Hidden()
local padUI = false
InputUtil = { IsGamepadUIEnabled = function() return padUI end }
cvars.chatStyle = "im"
ns.db.welcomed = nil
-- before the game counts the controller in use, it names its buttons by number (Y is 4)
local padNamed = false
local BindingNames = GetBindingText
GetBindingText = function(key) if padNamed then return BindingNames(key) end return (key:gsub("^PAD", "")) end
-- the game's controller interface off (its setting at keyboard and mouse) is no reason to skip it
ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
Is("a new player gets the window at login, the game's controller interface off", _G.FlickChatNotice ~= nil and _G.FlickChatNotice.shown, true)
local function NoticeSays(text)
    for _, region in ipairs(_G.FlickChatNotice.regions or {}) do
        if region.text == text then return true end
    end
    return false
end
Is("the window waits for the game to count the controller in use", (_G.FlickChatNotice.events or {}).GAME_PAD_ACTIVE_CHANGED, true)
padNamed = true
_G.FlickChatNotice.scripts.OnEvent(_G.FlickChatNotice, "GAME_PAD_ACTIVE_CHANGED", true)
Is("and then names Y as the game's Y, not 4", NoticeSays("[PAD4]") and not NoticeSays("4"), true)
GetBindingText = BindingNames
padUI = true
Is("with the keyboard as the preview", kb.shown, true)
-- Y in the window turns the keyboard's shape, the preview with it
local notice = _G.FlickChatNotice
local wideW, wideH = kb.w, kb.h
notice.scripts.OnGamePadButtonDown(notice, "PAD4")
Is("Y in the window stacks the keyboard, the guess words on top", ns.profile.shape, "above")
Is("narrower and taller", kb.w < wideW and kb.h > wideH, true)
local stackedW, stackedH = kb.w, kb.h
notice.scripts.OnGamePadButtonDown(notice, "PAD4")
Is("Y again puts the words below, the same size", ns.profile.shape == "below" and kb.w == stackedW and kb.h == stackedH, true)
notice.scripts.OnGamePadButtonDown(notice, "PAD4")
Is("and once more it is wide again, with no pick kept", ns.profile.shape == nil and kb.w == wideW and kb.h == wideH, true)
-- the triggers step the keyboard's size, the bumpers under them its background, the d-pad's left and right the text
notice.scripts.OnGamePadButtonDown(notice, "PADRTRIGGER")
Is("RT in the window makes the keyboard larger", ns.profile.size, 110)
notice.scripts.OnGamePadButtonDown(notice, "PADLTRIGGER")
Is("LT takes it back", ns.profile.size, 100)
Is("a new player's background starts at 90", ns.profile.backOpacity == 90 and kb.back.alpha == 0.9, true)
notice.scripts.OnGamePadButtonDown(notice, "PADLSHOULDER")
Is("LB fades the keyboard's background from its 90 to 80", ns.profile.backOpacity == 80 and kb.back.alpha == 0.8
    and kb.guide.back.alpha == 0.8, true)
for _ = 1, 8 do notice.scripts.OnGamePadButtonDown(notice, "PADLSHOULDER") end
Is("its border stays solid, even with no background", kb.TopEdge ~= nil and kb.TopEdge.alpha == nil
    and kb.TopEdge.shown ~= false and kb.guide.TopEdge.alpha == nil, true)
Is("down to none it is gone", ns.profile.backOpacity == 0 and not kb.back.shown, true)
for _ = 1, 10 do notice.scripts.OnGamePadButtonDown(notice, "PADRSHOULDER") end
Is("RB brings it back, up to full: solid, nothing seen through it", ns.profile.backOpacity == 100 and kb.back.shown
    and kb.back.alpha == 1 and kb.back.color[4] == 1, true)
local letter = kb.roses[1].cells[1].text
local letterWas = letter.fontSize
notice.scripts.OnGamePadButtonDown(notice, "PADDRIGHT")
Is("d-pad right in the window makes the text larger", ns.profile.textSize == 110 and letter.fontSize > letterWas, true)
Is("the keyboard's size stays, its middle widens for the larger words", ns.profile.size == 100 and kb.w > wideW, true)
notice.scripts.OnGamePadButtonDown(notice, "PADDLEFT")
Is("d-pad left takes it back", ns.profile.textSize == 100 and letter.fontSize == letterWas and kb.w == wideW, true)
generic.Hide(_G.FlickChatNotice)
Is("closing it puts the preview away", kb.shown, false)
-- the preview under any other window, one with no way up of its own: it hangs there and nothing is asked of it
local plain = Obj(UIParent)
ns.PreviewKeyboard(plain)
Is("the preview hangs under a plain window too", kb.shown, true)
ns.profile.shape = "above"
ns.Restyle()
Is("and takes a new shape there", kb.h > wideH, true)
ns.profile.shape = nil
ns.PreviewKeyboard()
Is("and goes when asked", kb.shown, false)
Is("and it is not shown twice", ns.db.welcomed, true)

-- the settings are a window of the addon's own, worked by the pad; nothing goes on the game's Settings window
Is("no row on the game's Settings window", next(Settings.rows), nil)
local listed = Settings.registered
Is("its name is on the game's AddOns list, a page of its own", listed ~= nil and listed.frame ~= nil, true)
-- that page shown (the game's cursor picked the name): the settings window opens over it
listed.frame.IsVisible = function() return true end
generic.Show(listed.frame)
local soon = timers[#timers]
if type(soon) == "function" then soon() end
local own = _G.FlickChatOptions
Is("picking it there opens the settings", own ~= nil and own.shown, true)
-- on the page a controller cursor walks the rows (the game's; an addon's window walk outside the controller
-- interface): its arrow lights the row it comes to, and going back to the list takes the light with it
local rowList = {}
for _, f in ipairs(frames) do
    if f.lit and f.parent and f.parent.parent == own.scroll then rowList[#rowList + 1] = f end
end
Is("on the page the pad is the cursor's, not the window's", own.padButtons, false)
rowList[3].OnSmartNavSelect(rowList[3])
Is("a cursor's arrow coming to a row lights it", rowList[3].lit.shown, true)
rowList[3].OnSmartNavDeselect(rowList[3])
Is("going back to the list takes the light with it", rowList[3].lit.shown, false)
rowList[5].OnSmartNavSelect(rowList[5])
rowList[7].scripts.OnEnter(rowList[7])
Is("a row the arrow's scrolling brings under a pointer standing still takes no focus", rowList[5].lit.shown, true)
rowList[5].OnSmartNavDeselect(rowList[5])
-- the walk scrolls nothing and stops only on rows in view: the next stop each way stays in sight
local last = #rowList
rowList[last - 1].OnSmartNavSelect(rowList[last - 1])
Is("near the end the row after the arrow's is in view", last * 26 <= (own.scroll.scrolled or 0) + 15 * 26, true)
rowList[21].OnSmartNavSelect(rowList[21])
Is("back up, the stop before it is in view, the title between with it", (19 - 1) * 26 >= (own.scroll.scrolled or 0), true)
generic.Hide(own)
generic.Hide(listed.frame)
SlashCmdList.FLICKCHAT("options")
Is("/flick options opens them too", own.shown, true)
rowList[2].OnSmartNavSelect(rowList[2])
rowList[2].OnSmartNavDeselect(rowList[2])
Is("on its own the window keeps its light when a cursor leaves", rowList[2].lit.shown, true)
-- the first row is the typing language: A turns to the next whose words are there, and round to the game's own
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("A on the first row turns to the next language", ns.profile.language, "ptBR")
Is("the row names it", ns.LanguageName(), "Português")
for _ = 2, #ns.LANGUAGES do own.scripts.OnGamePadButtonDown(own, "PAD1") end
Is("round them all it follows the game's language again", ns.profile.language, nil)
-- the first box is under it
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
local was = ns.profile.lowercase
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("A flips the first box", ns.profile.lowercase == true, not was)
own.scripts.OnGamePadButtonDown(own, "PAD1")
local size = ns.profile.size
for _ = 1, 8 do own.scripts.OnGamePadButtonDown(own, "PADDDOWN") end
own.scripts.OnGamePadButtonDown(own, "PADDRIGHT")
Is("d-pad down to the size, right adds to it", ns.profile.size, size + 5)
own.scripts.OnGamePadButtonDown(own, "PADDLEFT")
-- the keyboard's background under the size, then the text's own size, each leaving the size as it is
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
own.scripts.OnGamePadButtonDown(own, "PADDLEFT")
Is("the background is the next row: left fades it", ns.profile.backOpacity == 95 and kb.back.alpha == 0.95
    and ns.profile.size == size, true)
own.scripts.OnGamePadButtonDown(own, "PADDRIGHT")
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
own.scripts.OnGamePadButtonDown(own, "PADDRIGHT")
Is("the text size is the row under it, apart from the keyboard's size", ns.profile.textSize == 105 and ns.profile.size == size, true)
own.scripts.OnGamePadButtonDown(own, "PADDLEFT")
-- the shape under that; stacked, the word room row under it says why it changes nothing
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("A on the next row turns the keyboard's shape", ns.profile.shape, "above")
Is("the row names it", ns.ShapeName(), "Words on top")
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
Has("stacked, the word room row says it is the wide shape's", own.tip.text, "wide shape")
own.scripts.OnGamePadButtonDown(own, "PADDUP")
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("A again puts the words below", ns.ShapeName(), "Words below")
own.scripts.OnGamePadButtonDown(own, "PAD1")
Is("and once more it is wide", ns.profile.shape, nil)
-- a shape this version does not know (a saved pick from another build) is the wide one
ns.profile.shape = "stacked"
Is("an unknown saved shape reads as wide", ns.ShapeName(), "Wide")
ns.profile.shape = nil
own.scripts.OnGamePadButtonDown(own, "PADDDOWN")
Is("wide, that row has nothing to add", own.tip.text, "")
-- the last section: this character's profile, a new one, copy from, reset, delete (the last three: A twice)
local function Showing(text)
    for _, f in ipairs(frames) do
        if f.value and f.value.text == text then return true end
    end
    return false
end
local realUnitName = UnitName
UnitName = function(unit) if unit == "player" then return "Zaffa" end return realUnitName(unit) end
GetRealmName = function() return "Argent Dawn" end
local function Pad(button) own.scripts.OnGamePadButtonDown(own, button) end
for _ = 1, 10 do Pad("PADRSHOULDER") end
for _ = 1, 4 do Pad("PADDUP") end
Has("four rows over the last is this character's profile", own.tip.text, "belong to a profile")
Is("it shows Default", Showing("Default"), true)
Pad("PADDDOWN")
Pad("PAD1")
local nameBox
for _, f in ipairs(frames) do
    if f.slot == "profile" and f.shown then nameBox = f end
end
Is("A on New profile: a box with the character and realm in it", nameBox and nameBox.text, "Zaffa - Argent Dawn")
nameBox.text = "Raid"
nameBox.scripts.OnEnterPressed(nameBox)
Is("Enter there: the new profile, this character on it", ns.ProfileName(), "Raid")
Pad("PADDUP")
Is("the profile row names it", Showing("Raid"), true)
Pad("PADDLEFT")
Is("left: the profile before it, Default", ns.ProfileName(), "Default")
Pad("PADDRIGHT")
Is("right: Raid again", ns.ProfileName(), "Raid")
ns.SetPhrase(1, "pull in 5")
Pad("PADDDOWN")
Pad("PADDDOWN")
Has("then copy from", own.tip.text, "copies all its settings")
Is("it offers the other profile", Showing("Default"), true)
Pad("PAD1")
Is("one A only asks again", ns.Phrase(1) == "pull in 5" and Showing("[PAD1] again to confirm"), true)
Pad("PAD1")
Is("the second copies Default in", ns.Phrase(1), "hi")
ns.SetPhrase(1, "pull in 5")
Pad("PADDDOWN")
Pad("PAD1")
Pad("PADDDOWN")
Pad("PADDUP")
Pad("PAD1")
Is("moving off the reset asks from the start", ns.Phrase(1), "pull in 5")
Pad("PAD1")
Is("then A twice resets the profile", ns.Phrase(1), "hi")
Pad("PADDDOWN")
Pad("PAD1")
Pad("PAD1")
Is("A twice on delete: Raid gone, this character on Default",
    FlickChatDB.profiles.Raid == nil and ns.ProfileName() == "Default", true)
Is("on Default the delete row says it stays", Showing("Default stays"), true)
Pad("PAD1")
Is("and A there deletes nothing", FlickChatDB.profiles.Default ~= nil, true)
-- a row the d-pad scrolled under a pointer standing still takes no focus (2026-11-21, /fcdev profile); moved, it does
local pointer = { 500, 300 }
local realPointer = GetCursorPosition
GetCursorPosition = function() return pointer[1], pointer[2] end
Pad("PADDUP")
local tipBefore, under = own.tip.text, nil
for _, f in ipairs(frames) do
    if f.lit and f.scripts.OnEnter and not f.lit.shown then
        under = f
        break
    end
end
under.scripts.OnEnter(under)
Is("a row coming under a pointer standing still takes no focus", own.tip.text == tipBefore and not under.lit.shown, true)
pointer[1] = 520
under.scripts.OnEnter(under)
Is("once the pointer moves, the row under it has the focus", under.lit.shown, true)
GetCursorPosition = realPointer
UnitName, GetRealmName = realUnitName, nil
own.scripts.OnGamePadButtonDown(own, "PAD2")
Is("B shuts it", own.shown, false)

-- a chat window whose controller focus function another addon replaced: said once, naming who the game blames
local said = {}
local realPrint = print
FloatingChatFrameMixin = { SetGamepadFocus = function() end }
ChatFrame1 = { SetGamepadFocus = function() end }
function issecurevariable() return false, "SomeChatAddon" end
print = function(text) said[#said + 1] = text end
ns.events.scripts.OnEvent(ns.events, "GAME_PAD_ACTIVE_CHANGED", true)
timers[#timers]()
ns.events.scripts.OnEvent(ns.events, "GAME_PAD_ACTIVE_CHANGED", true)
timers[#timers]()
print = realPrint
Is("the switched-off menu Chat is said once", #said, 1)
Has("naming the addon the game blames", said[1], "SomeChatAddon")

-- a text box that is not chat (mail's To line): focused by the game's cursor, the keyboard comes up for it
Hidden()
generic.Hide(kb)
local mail = Obj(UIParent)
mail.shown = true
function mail.IsObjectType(_, kind) return kind == "EditBox" end
function mail.IsForbidden() return false end
SmartNavigation.hooks.OnShow(SmartNavigation)
local seek = lastTick
focus = mail
seek()
Is("the keyboard opens for another text box", kb.shown, true)
function mail.ClearFocus() focus = nil end
Is("nothing is hooked on such a box", mail.hooks, nil)
mail.scripts.OnEnterPressed = function(self) self.entered = true end
mail.scripts.OnEscapePressed = function(self) self.escaped = true end
Type("hi")
Press("PAD1")
Is("A keeps the text in the box", mail.text, "Hi")
Is("lets the box go, so the game's cursor is where it was", kb.shown, false)
Is("and never presses the box's Enter", mail.entered, nil)
-- back in, more typed, then B: what it held comes back
seek()
focus = mail
seek()
Type("no")
Press("PAD2")
Is("B puts back what the box held", mail.text, "Hi")
Is("and lets go without the box's Escape", kb.shown == false and mail.escaped == nil, true)
-- the game's cursor leaving the box (its focus gone by the game's hand) shuts the keyboard on the next look
seek()
focus = mail
seek()
Is("up again on the next Select", kb.shown, true)
focus = nil
seek()
Is("and gone when the game takes the focus away", kb.shown, false)

-- the auction house's search: the game's box is never written; the search is asked of the game directly
local query
local written = 0
AuctionHouseFrame = Obj(UIParent)
local searchBox = Obj(AuctionHouseFrame)
searchBox.shown = true
function searchBox.SetText() written = written + 1 end
function searchBox.IsObjectType(_, kind) return kind == "EditBox" end
function searchBox.IsForbidden() return false end
AuctionHouseFrame.SearchBar = { SearchBox = searchBox,
    FilterButton = { CalculateFiltersArray = function() return { 7 } end, GetLevelRange = function() return 10, 20 end } }
function AuctionHouseFrame.GetCategoriesList() return { GetCategoryFilterData = function() return { "cloth" }, 9 end } end
function AuctionHouseFrame.GetCategorySearchContext() return 1 end
g_auctionHouseSortsBySearchContext = { [1] = { "bySaved" } }
C_AuctionHouse = { SendBrowseQuery = function(q) query = q end, IsThrottledMessageSystemReady = function() return true end }
local search = ns.DirectFor(searchBox, AuctionHouseFrame)
Is("the auction search box is typed into over the top", type(search), "function")
Is("another box of that window is left alone", ns.DirectFor(mail, AuctionHouseFrame), false)
Is("a box of any other window is an ordinary one", ns.DirectFor(mail, mail), nil)
focus = searchBox
seek()
Is("the keyboard does not open on the game's box itself", written, 0)
search("linen")
Is("the search goes to the game with the typed text", query and query.searchString, "linen")
Is("with the picked category, filters, levels and sort", query.itemClassFilters[1] == "cloth" and query.filters[2] == 9
    and query.minLevel == 10 and query.maxLevel == 20 and query.sorts[1] == "bySaved", true)
Is("and the game's own box was never written", written, 0)
-- Buy Now: the cover is taken off the game's cursor once; the page behind the dialog while the dialog is up
local ignored, cleared = {}, {}
AuctionHouseFrame.DialogOverlay = Obj(AuctionHouseFrame)
AuctionHouseFrame.BuyDialog = Obj(AuctionHouseFrame)
AuctionHouseFrame.CommoditiesBuyFrame = Obj(AuctionHouseFrame)
function SmartNavigation_MarkFrameIgnored(frame, alone) ignored[#ignored + 1] = { frame, alone } end
function SmartNavigation_ClearIgnoreStatus(frame) cleared[#cleared + 1] = frame end
seek()
seek()
Is("the Buy Now cover is marked as not the cursor's, once", #ignored == 1 and ignored[1][1] == AuctionHouseFrame.DialogOverlay
    and ignored[1][2] == true, true)
AuctionHouseFrame.BuyDialog.shown = true
seek()
seek()
Is("with the dialog up the page behind it is marked too, once", #ignored == 2 and ignored[2][1] == AuctionHouseFrame.CommoditiesBuyFrame, true)
AuctionHouseFrame.BuyDialog.shown = false
seek()
seek()
Is("and given back when the dialog goes", #cleared == 1 and cleared[1] == AuctionHouseFrame.CommoditiesBuyFrame, true)
-- from one item's page the window is sent back to its list; on the list it is not touched
local shownMode, sets = "item", 0
AuctionHouseFrameDisplayMode = { Buy = "list" }
function AuctionHouseFrame.GetDisplayMode() return shownMode end
function AuctionHouseFrame.SetDisplayMode(_, mode) shownMode = mode; sets = sets + 1 end
search("wool")
Is("a search from an item's page never changes the window", sets, 0)
Is("and the results still go out", query.searchString, "wool")
focus = nil

-- every typing language: its folder's words become the keyboard's, an accented word comes out whole, its lesson's
-- words are lowercase letters its list offers, the drill word rolls three boxes and swings across, and its folder
-- carries the addon's version
local D = ns.Dict
local function Version(path)
    for line in io.lines(path) do
        local version = line:match("^## Version:%s*(%S+)")
        if version then return version end
    end
end
local ACCENTED = { enUS = "hello", ptBR = "não", frFR = "où", deDE = "für", itIT = "più", esES = "también", ruRU = "ещё" }
for _, code in ipairs(ns.LANGUAGES) do
    ns.profile.language, ns.db.wordsOf, ns.db.others = code, code, {}
    ns.db.learned, ns.db.pairs, ns.db.forms, ns.db.forgot = {}, {}, {}, {}
    Open()
    Is(code .. ": its words are the keyboard's", D.Code(), code)
    Type(ACCENTED[code])
    Press("PAD1")
    Is(code .. ": a word with its accent", sent[#sent], ns.Capital(ACCENTED[code]))
    local steps, wrong, prev = {}, {}, "<s>"
    for step in T.lesson.lines[code]:gmatch("%S+") do steps[#steps + 1] = step end
    Is(code .. ": the lesson has eleven steps", #steps, 11)
    for _, step in ipairs(steps) do
        if D.KeyOf(step) then
            local guesses, stems = D.Decode(D.KeyOf(step), prev)
            local there = false
            for _, word in ipairs(guesses) do there = there or ns.Lower(word) == step end
            for _, word in ipairs(stems) do there = there or ns.Lower(word) == step end
            if ns.Lower(step) ~= step or #D.KeyOf(step) ~= #ns.Characters(step) then
                wrong[#wrong + 1] = step .. " (lowercase letters only)"
            end
            if not there then wrong[#wrong + 1] = step .. " (not offered)" end
            prev = step
        end
    end
    Is(code .. ": the lesson's words are offered", table.concat(wrong, ", "), "")
    local key, moves = D.KeyOf(steps[4]), {}
    for i = 1, 4 do
        local a, b = tonumber(key:sub(i, i)), tonumber(key:sub(i + 1, i + 1))
        moves[i] = (a <= 4) == (b <= 4) and (b - a) % 4 or "other stick"
    end
    local rolls = (moves[1] == 1 or moves[1] == 3) and (moves[2] == 1 or moves[2] == 3) and (moves[3] == 1 or moves[3] == 3)
    Is(code .. ": the drill word rolls three boxes, then swings across", rolls and moves[4] == 2, true)
    Press("PAD2")
    if code ~= "enUS" then
        Is(code .. ": its folder carries the addon's version",
            Version(dir .. "/Packs/FlickChat_" .. code .. "/FlickChat_" .. code .. ".toc"), Version(dir .. "/FlickChat.toc"))
    end
end
-- Cyrillic is handled as letters, not bytes: case, exact input, fallback, practice and both layouts.
local russianLower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local russianUpper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
Is("every Russian capital has a lowercase", ns.Lower(russianUpper), russianLower)
Is("every Russian letter has a capital", ns.Upper(russianLower), russianUpper)
Is("mixed Latin and Cyrillic case is kept", ns.Lower("ЁЖ Hello ÉTÉ"), "ёж hello été")
Is("Russian title case changes one whole letter", ns.Capital("ёлка"), "Ёлка")
ns.profile.language = "ruRU"
Open()
Is("Russian uses Cyrillic letter groups", ns.LAYOUTS.letters[1], "абвг")
-- drawn in the game's Cyrillic font: an English game's standard font has no Russian letters (they show as boxes)
local cyrillicFont = "Fonts\\FRIZQT___CYR.TTF"
Is("Russian letters are drawn in the game's Cyrillic font", kb.roses[1].cells[1].text.fontPath == cyrillicFont
    and kb.slots[1].fontPath == cyrillicFont and kb.hint.fontPath == cyrillicFont, true)
Is("a Russian capital types the same as lowercase", D.KeyOf("ПРИВЕТ"), D.KeyOf("привет"))
local allLetters = {}
for group = 1, 8 do
    for _, c in ipairs(D.Box(group)) do
        allLetters[#allLetters + 1] = c
        Is("one whole Russian letter in a box: " .. c, #ns.Characters(c), 1)
    end
end
Is("all 33 Russian letters can be typed exactly", table.concat(allLetters), russianLower)
local wrongKeys, rareWords = 0, 0
for _, lines in pairs(ns.wordLists.ruRU.rare) do
    for key, word in lines:gmatch("\n(%d+) (%S+) %d+") do
        rareWords = rareWords + 1
        if D.KeyOf(word) ~= key then wrongKeys = wrongKeys + 1 end
    end
end
Is("the Russian pack has a full dictionary, not just chat phrases", rareWords > 10000, true)
Is("Russian precomputed rare keys match the runtime alphabet", wrongKeys, 0)
Type("привет")
Press("PAD1")
Is("Russian predictive typing sends a whole word", sent[#sent], "Привет")
Is("Russian sent words are learned in lowercase", ns.db.learned["привет"] ~= nil, true)
Open()
Press("PADLSTICK")
Press("PADLSTICK")
Type("привет")
Press("PAD1")
Is("caps lock handles Cyrillic", sent[#sent], "ПРИВЕТ")
Open()
Press("PADLSHOULDER")
for _, c in ipairs(ns.Characters("жюёъ")) do
    local group = tonumber(D.KeyOf(c))
    Flick(group)
    for i, letter in ipairs(D.Box(group)) do if letter == c then Flick(i) break end end
end
Is("exact input includes ё and hard sign", box.text, "Жюёъ")
Press("PADLTRIGGER")
Is("backspace removes one Cyrillic letter, not one byte", box.text, "Жюё")
Press("PAD1")
Open()
for _ = 1, 21 do Flick(8) end
Is("unknown flicks fall back to whole Cyrillic letters", T.Word(), string.rep("ы", 21))
Press("PADBACK")
Press("PAD2")
ns.profile.layout = "vowels"
Open()
Type("спасибо")
Press("PAD1")
Is("Russian predictions work on the vowels layout", sent[#sent], "Спасибо")
Is("Russian vowels are on the left stick", ns.LAYOUTS.vowels[4], "ыэюя")
Press("PAD2")
ns.profile.layout = "letters"
ns.PracticeNext()
Open()
Is("typing practice opens with Cyrillic words", ns.practice ~= nil, true)
local russianPractice = _G.FlickChatPractice.words.text:match("|c%x%x%x%x%x%x%x%x(.-)|r")
Is("practice offers a Russian word", russianPractice:find("[\208\209]") ~= nil, true)
ns.practice.Typed(ns.Upper(russianPractice))
now = now + 1
lastTick()
Has("Russian practice counts characters, not bytes", _G.FlickChatPractice.foot.text,
    tostring((#ns.Characters(russianPractice) + 1) * 12) .. " words a minute")
Press("PAD2")
ns.db.lessonDone = false
Open()
Has("the Russian lesson names its first word", Told(), "мы")
Has("the Russian lesson displays a whole first letter", Told(), "м")
Has("the Russian lesson separates words in the goal", kb.hintGoal.text, "мы|r |cffffffffэтот")
Type("мы")
Press("PADRTRIGGER")
Is("the Russian lesson advances after its first word", T.state.lesson.at, 2)
Is("a Russian lesson line is checked as words, not symbols", T.lesson.Check(), nil)
Press("PADBACK")
T.state.lesson.at = 4
Press("PADBACK")
Has("the Russian chain lesson names whole letters", Told(), "з")
Roll(-90, -180)
Is("Russian chaining passes its first stage", T.state.lesson.stage, 2)
Roll(-90, -360)
Is("Russian chaining passes its second stage", T.state.lesson.stage, 3)
Roll(-90, -360)
Flick(4)
Is("Russian chaining ends with the swing across", T.state.lesson.chained, true)
Press("PAD4")
Press("PADBACK")
Press("PAD2")
ns.db.lessonDone = true
local learnedRussian = ns.db.learned["привет"]
ns.profile.language = "enUS"
Open()
Is("switching back restores the Latin layout", ns.LAYOUTS.letters[1], "abc")
Is("and the game's standard font", kb.roses[1].cells[1].text.fontPath, STANDARD_TEXT_FONT)
Is("English does not inherit Russian learned words", ns.db.learned["привет"], nil)
Type("hello")
Press("PAD1")
Is("a cached English dictionary restores its letter map", sent[#sent], "Hello")
Open()
ns.profile.language = "ruRU"
ns.Relanguage()
Is("switching an open keyboard restores Cyrillic groups", ns.LAYOUTS.letters[1], "абвг")
Is("and the Cyrillic font, the lesson lines' too", kb.roses[1].cells[1].text.fontPath == cyrillicFont
    and kb.hintSkip.fontPath == cyrillicFont and kb.hintGoal.fontPath == cyrillicFont, true)
Is("switching back restores Russian learned words", ns.db.learned["привет"], learnedRussian)
Type("привет")
Press("PAD1")
Is("a cached Russian dictionary restores its letter map", sent[#sent], "Привет")
Press("PAD2")
ns.locale, ns.profile.language = "ruRU", nil
Is("a Russian game automatically selects Russian", ns.WantedLanguage(), "ruRU")
Is("a Russian game shows translated settings", ns.L.OPT_LANGUAGE, "Язык ввода")
Is("a Russian game has Russian quick phrases", ns.Phrase(1), "привет")
ns.PreviewKeyboard(UIParent)
Is("a Russian keyboard preview uses Cyrillic groups", ns.LAYOUTS.letters[1], "абвг")
Is("a Russian keyboard preview uses Russian guesses", T.state.slots[1]:find("[\208\209]") ~= nil, true)
ns.PreviewKeyboard()
local missingRussian = {}
for key in pairs(ns.EN) do
    if ns.locales.ruRU[key] == nil then missingRussian[#missingRussian + 1] = key end
end
Is("every interface string is translated to Russian", table.concat(missingRussian, ", "), "")
ns.locale = "enUS"

-- a language whose folder is not there: said once, and English's words
local lines = {}
local printWas = print
print = function(text) lines[#lines + 1] = text end
ns.LANGUAGE_NAMES.xxXX, ns.profile.language = "Test", "xxXX"
Open()
Press("PAD2")
Open()
Press("PAD2")
print = printWas
Is("a language with no folder types English", D.Code(), "enUS")
Is("and says so once", #lines, 1)
ns.LANGUAGE_NAMES.xxXX, ns.profile.language = nil, nil
-- each language keeps what it learned: another's turn puts these aside, and its own turn brings them back
ns.db.learned.zug = 3
ns.profile.language = "ptBR"
Open()
Is("another language starts with nothing learned", next(ns.db.learned), nil)
Is("the first one's learned words wait", ns.db.others.enUS.learned.zug, 3)
Press("PAD2")
ns.profile.language = nil
Open()
Is("and come back with its turn", ns.db.learned.zug, 3)
Press("PAD2")
ns.db.learned.zug = nil
-- the other letter layout on another language's words
ns.profile.language, ns.profile.layout = "frFR", "vowels"
Open()
Type("merci")
Press("PAD1")
Is("a French word on the vowels layout", sent[#sent], "Merci")
Press("PAD2")
ns.profile.language, ns.profile.layout = nil, "letters"
-- by a chat window: stacked, the keyboard's bottom corner on the chat window's own (the messages', not the typing
-- line under them); wide, by the typing line as before
local chatWindow = Obj(UIParent)
local chatBox = Obj(chatWindow)
chatBox.chatFrame = chatWindow
local placed
kb.SetPoint = function(_, ...) placed = { ... } end
for _, shape in ipairs({ "above", "below" }) do
    ns.profile.shape = shape
    T.PlaceBy(chatBox)
    Is("words " .. shape .. ": the keyboard's bottom left on the chat window's bottom right", placed[1] == "BOTTOMLEFT"
        and placed[2] == chatWindow and placed[3] == "BOTTOMRIGHT" and placed[5] == (ns.profile.moveY or 0), true)
end
ns.profile.shape = nil
T.PlaceBy(chatBox)
Is("wide: by the typing line as before", placed[1] == "BOTTOMLEFT" and placed[2] == chatBox and placed[3] == "TOPRIGHT", true)
kb.SetPoint = nil
-- the game's controller interface off: the button guide over the chat window, the keyboard's top left free
local guidePlaced
kb.guide.SetPoint = function(_, ...) guidePlaced = { ... } end
padUI = false
Open()
Is("controller interface off: the button guide over the chat window", guidePlaced[1] == "BOTTOMLEFT"
    and guidePlaced[2] == box.chatFrame and guidePlaced[3] == "TOPLEFT", true)
Press("PAD2")
-- the hint bar under chat in front of the action bars; held up into the chat (no room under it), behind the chat
local barStrata
kb.bar.SetFrameStrata = function(_, strata) barStrata = strata end
box.GetBottom = function() return 300 end
Open()
Is("the hint bar under chat stands in front of the action bars", barStrata, "DIALOG")
Press("PAD2")
box.GetBottom = nil
Open()
Is("with no room under the chat line it stays behind the chat", barStrata, "LOW")
Press("PAD2")
kb.bar.SetFrameStrata = nil
-- the button guide carried from its settings row: the left stick moves it, the keyboard's place and size stay
ns.MoveNext(nil, true)
Open()
local guideTick = lastTick
Has("the line says the left stick moves the button guide", kb.hint.text, "button guide")
kb.guide.GetLeft = function() return ns.profile.guideX or 0 end
local kbX, kbSize = ns.profile.moveX, ns.profile.size
kb.scripts.OnGamePadStick(kb, "Left", 1, 0, 1)
kb.scripts.OnGamePadStick(kb, "Right", 0, 1, 1)
now = now + 0.05
guideTick()
Is("the left stick carries the guide", (ns.profile.guideX or 0) > 0 and guidePlaced[4] == ns.profile.guideX, true)
Is("and leaves the keyboard's place and size", ns.profile.moveX == kbX and ns.profile.size == kbSize, true)
kb.scripts.OnGamePadStick(kb, "Left", 0, 0, 0)
kb.scripts.OnGamePadStick(kb, "Right", 0, 0, 0)
Press("PAD2")
Is("B puts it back", ns.profile.guideX, 0)
Press("PAD2")
kb.guide.GetLeft, kb.guide.SetPoint = nil, nil
ns.profile.guideX, ns.profile.guideY = nil, nil
padUI = true
-- the stacked shapes type as the wide one does (the letters layout back first: the lines above left the other on)
for _, shape in ipairs({ "above", "below" }) do
    ns.profile.shape = shape
    ns.Relayout()
    Open()
    Type("hello")
    Press("PAD1")
    Is("typing is the same with the words " .. shape, sent[#sent], "Hello")
    Press("PAD2")
end
ns.profile.shape = nil
ns.Restyle()
-- a Latin American Spanish game types with Spanish's words, and Spanish there is the game's own, no pick
ns.locale = "esMX"
Is("a Latin American Spanish game types Spanish", ns.WantedLanguage(), "esES")
ns.profile.language = "itIT"
ns.NextLanguage()
Is("where Spanish is followed, not picked", ns.profile.language, nil)
-- saved settings from before Spanish had a list, on a Spanish game: what was learned is Spanish's
local old = { dbVersion = 1, languagesTold = true, wordsOf = "enUS" }
ns.Migrate(old)
Is("words learned on a Spanish game before its list are Spanish's", old.wordsOf, "esES")
Is("the five languages told before count as told", old.languagesTold, 5)
local picked = { dbVersion = 1, language = "enUS", wordsOf = "enUS" }
ns.Migrate(picked)
Is("a picked English keeps its words", picked.wordsOf, "enUS")
ns.locale = "enUS"
local english = { dbVersion = 1, wordsOf = "enUS" }
ns.Migrate(english)
Is("as does an English game", english.wordsOf, "enUS")

-- login notes: the typing languages once; a newer version heard from another player, until this one is as new
local notes = {}
local function Heard(fn, ...)
    print = function(text) notes[#notes + 1] = text end
    fn(...)
    print = printWas
end
local function Addon(prefix, text) ns.events.scripts.OnEvent(ns.events, "CHAT_MSG_ADDON", prefix, text) end
ns.db.languagesTold, ns.db.newest, ns.db.newestAt, ns.db.feedbackTold = nil, nil, nil, "1.2.0"
Heard(ns.LoginNotes)
Is("the typing languages are told at login", #notes, 1)
Has("each by its own name", notes[1], "Português, Français, Deutsch, Italiano")
Heard(ns.LoginNotes)
Is("once only", #notes, 1)
Heard(Addon, "FlickChat", "v1.2.0")
Heard(Addon, "FlickChat", "v1.1.9")
Heard(Addon, "FlickChat", "junk")
Heard(Addon, "Other", "v9.9.9")
Is("a version no newer, a broken one and another addon's say nothing", #notes, 1)
Heard(Addon, "FlickChat", "v1.2.1")
Is("a newer version from another player is said", #notes, 2)
Has("with both versions", notes[2], "1.2.1 is out (you have 1.2.0)")
Has("and where to get it", notes[2], "curseforge.com/wow/addons/flickchat")
Has("in red after the addon's blue name", notes[2], "|cff2e8fe6FlickChat|r |cffff4040version")
Is("the languages note is not red", notes[1]:find("|cffff4040", 1, true), nil)
Heard(Addon, "FlickChat", "v1.4.0")
Is("once a session", #notes, 2)
Is("the newest heard is kept", ns.db.newest, "1.4.0")
Heard(ns.LoginNotes)
Has("and said again at the next login", notes[3], "1.4.0 is out")
ns.db.newestAt = time() - 40 * 86400
Heard(ns.LoginNotes)
Is("unheard for a month it is forgotten", ns.db.newest, nil)
ns.db.newest, ns.db.newestAt = "1.2.0", time()
Heard(ns.LoginNotes)
Is("as is one this version has caught up with", ns.db.newest, nil)
Is("neither is said", #notes, 3)
local wasInGuild = IsInGuild
IsInGuild = function() return true end
addonSent = {}
Heard(ns.LoginNotes)
IsInGuild = wasInGuild
Is("this version goes out to the guild at login", addonSent[1], "FlickChat v1.2.0 GUILD")
-- a language added after the note was told: told once more, by itself
local toldBefore = #notes
ns.db.languagesTold = #ns.LANGUAGES - 1
Heard(ns.LoginNotes)
Heard(ns.LoginNotes)
Is("a language added since is told once", #notes, toldBefore + 1)
Has("by itself", notes[#notes], "words in " .. ns.LANGUAGE_NAMES[ns.LANGUAGES[#ns.LANGUAGES]] .. ".")
-- feedback: once a version at login; its [here] shows the address picked in a box
ns.db.feedbackTold = "1.1.0"
toldBefore = #notes
Heard(ns.LoginNotes)
Heard(ns.LoginNotes)
Is("the feedback line is said once a version", #notes, toldBefore + 1)
Has("thanking the player, the logo before the name", notes[#notes],
    "Thank you for using |TInterface\\AddOns\\FlickChat\\media\\icon:0|t |cff2e8fe6FlickChat|r! Have suggestions?")
Has("with a link to click", notes[#notes], "Click |cff2e8fe6|Haddon:FlickChat:feedback|h[here]|h|r.")
SetItemRef("item:19019", "[Thunderfury]", "LeftButton")
Is("another link shows no address", _G.FlickChatAddress, nil)
SetItemRef("addon:FlickChat:feedback", "[here]", "LeftButton")
local address = _G.FlickChatAddress
Is("the link shows the address", address.shown, true)
Is("in a box to copy", ns.addressBox.text, "https://github.com/fallenguards/FlickChat/issues")
ns.addressBox.text = "https://github.com/fallenguards/FlickChat/issuesx"
ns.addressBox.scripts.OnTextChanged(ns.addressBox, true)
Is("typing leaves it as it was", ns.addressBox.text, "https://github.com/fallenguards/FlickChat/issues")
local copied = address.copied
ns.addressBox.scripts.OnKeyDown(ns.addressBox, "C")
Is("C alone says nothing", copied.shown, false)
IsControlKeyDown = function() return true end
ns.addressBox.scripts.OnKeyDown(ns.addressBox, "C")
IsControlKeyDown = function() return false end
Is("Ctrl+C says it is copied", copied.shown and copied.text, "Copied")
ns.addressBox.scripts.OnEscapePressed(ns.addressBox)
Is("Escape shuts it", address.shown, false)

-- every language's strings: none English lacks, and the same %s and %d in the same order as English's
local function Blanks(text)
    local out = {}
    for blank in text:gsub("%%%%", ""):gmatch("%%[%d%.%-]*%a") do out[#out + 1] = blank end
    return table.concat(out, " ")
end
local codes = {}
for code in pairs(ns.locales) do codes[#codes + 1] = code end
table.sort(codes)
Is("the other languages are loaded", #codes >= 5, true)
for _, code in ipairs(codes) do
    local wrong = {}
    for key, text in pairs(ns.locales[code]) do
        if ns.EN[key] == nil then
            wrong[#wrong + 1] = key .. " (not in English)"
        elseif Blanks(text) ~= Blanks(ns.EN[key]) then
            wrong[#wrong + 1] = key .. " (" .. Blanks(text) .. " for " .. Blanks(ns.EN[key]) .. ")"
        end
    end
    table.sort(wrong)
    Is(code .. ": strings fit English's", table.concat(wrong, ", "), "")
    -- as on that language's game: its own text where it has one, English where it has none
    ns.locale = code
    Is(code .. ": its title shows", ns.L.TITLE, ns.locales[code].TITLE or ns.EN.TITLE)
end
ns.locale = "enUS"
Is("English shows English", ns.L.TITLE, ns.EN.TITLE)

-- Chat is for what the player cannot see: a line for someone new, an update, the answer to a typed /flick, a
-- result out of sight. What they just did and can see is never said (his rule for every addon; FlickChat's last
-- such lines went 2026-11-23), and a refusal goes to the red error text (ns.Refuse). Every chat line in the
-- shipped files is one listed here with why; a new one fails until it is listed or cut.
do
    local CHAT = {
        TITLE = "the addon's name before each line (ns.Say itself)",
        NEWS_LANGUAGES = "for someone new: the languages to type in, once",
        UPDATE_OUT = "an update reminder",
        FEEDBACK = "where to report, once a version",
        WHEEL_CHAT_OFF = "another addon switched off the menu's Chat: nothing on screen says so",
        ANOTHER_ADDON = "part of WHEEL_CHAT_OFF",
        LANG_MISSING = "a language's words are not installed: nothing on screen says so",
        SEARCH_BEHIND = "the new results wait behind the item's page, out of sight",
        FORGOT_BACK = "the settings button's only answer: the words come back out of sight",
        MOVE_NEXT = "what the next chat open does (settings button or /flick move)",
        MOVE_GUIDE_NEXT = "what the next chat open does (settings button)",
        LESSON_AGAIN = "what the next keyboard open does (settings button or /flick lesson)",
        PRACTICE_NEXT = "what the next chat open does (settings button or /flick practice)",
        SIZE = "the answer to /flick size",
        LAYOUT_ = "the answer to /flick layout",
        PROBE_CHAT = "the answer to /flick chatprobe",
        PROBE_STICKS = "the answer to /flick sticks",
        PHRASES_RESET = "the answer to /flick phrases reset",
        USAGE = "the answer to a /flick it does not know",
        LOWER_ON = "the answer to /flick lowercase",
        LOWER_OFF = "the answer to /flick lowercase",
        ON = "the answer to /flick",
        OFF = "the answer to /flick",
    }
    -- the two lines that pass a line on
    local KEYLESS = { ["ns.Say(text)"] = true, ["function ns.Tell(text, button)"] = true }
    local found, wrong = {}, {}
    local function Scan(path)
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            local code = line:gsub("\r", ""):match("^%s*(.-)%s*$")
            local chat = code:sub(1, 2) ~= "--" and (code:find("ns%.Say%(") or code:find("ns%.Tell%(")
                or (" " .. code):find("[^%w_.:]print%(")
                or (code:find("AddMessage%(") and not code:find("UIErrorsFrame:AddMessage", 1, true)))
            if chat then
                local where, keys = ("%s:%d"):format(path:match("[^/]+$"), n), 0
                for key in code:gmatch('"([%u_][%u%d_]*)"') do
                    keys, found[key] = keys + 1, true
                    if not CHAT[key] then wrong[#wrong + 1] = where .. " " .. key end
                end
                if keys == 0 and not KEYLESS[code] then wrong[#wrong + 1] = where .. " " .. code end
            end
        end
    end
    for line in io.lines(dir .. "/FlickChat.toc") do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line ~= "" and line:sub(1, 1) ~= "#" then Scan(dir .. "/" .. line) end
    end
    for code in pairs(ns.locales) do
        local name = "FlickChat_" .. code
        local toc = io.open(dir .. "/Packs/" .. name .. "/" .. name .. ".toc")
        if toc then
            for line in toc:lines() do
                line = line:gsub("\r", "")
                if line ~= "" and line:sub(1, 1) ~= "#" then Scan(dir .. "/Packs/" .. name .. "/" .. line) end
            end
            toc:close()
        end
    end
    table.sort(wrong)
    Is("every chat line in the shipped files is listed with why (CHAT in the smoke test), or cut",
        table.concat(wrong, ", "), "")
    local stale = {}
    for key in pairs(CHAT) do
        if not found[key] then stale[#stale + 1] = key end
    end
    table.sort(stale)
    Is("and every one listed is still said", table.concat(stale, ", "), "")
end

print(failed == 0 and "all checks passed" or (failed .. " check(s) failed"))
os.exit(failed == 0 and 0 or 1)
