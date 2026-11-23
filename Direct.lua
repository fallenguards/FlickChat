local _, ns = ...

-- Text boxes of the game's whose text must never be written by an addon. Text an addon writes into a box is the
-- addon's to the game: whatever the game then does with it runs as the addon's. The auction house builds its
-- result list from its search text, and the game's controller cursor refuses to step into a list built that way
-- (taint log, 2026-11-13). So for such a box the typing goes into a box of our own laid over it, the game's box is
-- never written, and what the text was for is asked of the game directly; its answer comes back in an event of
-- the game's own, and the list it builds from that is clean.

local proxy, target, run

-- The auction house's search: the query its own Search button would send (the picked category, filters, level
-- range and sort order, all only read here), with the typed text.
local function AuctionSearch(text)
    local house = AuctionHouseFrame
    local api = C_AuctionHouse
    if not (house and api and api.SendBrowseQuery) then return end
    if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
        return ns.Refuse(ns.L["SEARCH_WAIT"])
    end
    local filters, minLevel, maxLevel
    local button = house.SearchBar and house.SearchBar.FilterButton
    if button and button.CalculateFiltersArray then
        filters = button:CalculateFiltersArray()
        minLevel, maxLevel = button:GetLevelRange()
    end
    local classFilters
    local categories = house.GetCategoriesList and house:GetCategoriesList()
    if categories and categories.GetCategoryFilterData then
        local implicit
        classFilters, implicit = categories:GetCategoryFilterData()
        if implicit and filters then filters[#filters + 1] = implicit end
    end
    local context = house.GetCategorySearchContext and house:GetCategorySearchContext()
    local saved = g_auctionHouseSortsBySearchContext
    local sorts = saved and context and saved[context]
    if not sorts and Enum.AuctionHouseSortOrder then
        sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
            { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
    end
    api.SendBrowseQuery({ searchString = text, sorts = sorts or {}, minLevel = minLevel, maxLevel = maxLevel,
        filters = filters, itemClassFilters = classFilters })
    -- On one item's page (the Back button's page) the new results wait behind it. The window is never sent back
    -- to its list from here: that writes the window's own state as an addon's, and the game then refuses the
    -- purchase made from it. Said instead; the game's Back shows them.
    local modes = AuctionHouseFrameDisplayMode
    if modes and modes.Buy and house.GetDisplayMode and house:GetDisplayMode() ~= modes.Buy then
        ns.Say(ns.L["SEARCH_BEHIND"])
    end
end

-- What to do with a text box of another window: a function (type into our own box over it, then run this with
-- the text), false (leave the box alone: nothing can be typed there cleanly), nil (an ordinary box).
function ns.DirectFor(edit, window)
    local house = AuctionHouseFrame
    if not house or window ~= house then return nil end
    if house.SearchBar and edit == house.SearchBar.SearchBox then return AuctionSearch end
    return false
end

local function Build()
    proxy = CreateFrame("EditBox", nil, UIParent)
    proxy:Hide()
    proxy:SetAutoFocus(false)
    proxy:SetMaxLetters(64)
    proxy:SetFrameStrata("DIALOG")
    proxy:SetFontObject(GameFontHighlightSmall)
    proxy:SetTextInsets(18, 18, 0, 0)
    local fill = proxy:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 14, -3)
    fill:SetPoint("BOTTOMRIGHT", -16, 3)
    fill:SetColorTexture(0.02, 0.02, 0.03, 1)
    proxy:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        self.kept = text
        self:ClearFocus()
        if run then run(text) end
    end)
    proxy:SetScript("OnEscapePressed", function(self)
        self:SetText(self.kept or "")
        self:ClearFocus()
    end)
    -- Typed and done, it stays as the box's words; empty, the game's box shows through again.
    proxy:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self:Hide() end
    end)
    -- Ours: the keyboard's A presses its Enter and B its Escape.
    proxy.flickOwn = true
    ns.Watch(proxy)
end

-- Our own box over the game's, taking the typing from it.
function ns.DirectOpen(edit, handler)
    if not proxy then Build() end
    if target ~= edit then
        proxy.kept = ""
        proxy:SetText("")
    end
    target, run = edit, handler
    -- The keyboard stands beside the window of the box it is laid over.
    proxy.flickFor = edit
    proxy:ClearAllPoints()
    proxy:SetAllPoints(edit)
    proxy:Show()
    proxy:SetFocus()
end

-- The auction house's Buy Now. Its confirm dialog lies over the item's page, and the game's controller cursor is
-- not kept to the dialog: it still counts everything under it. The amount box of the page stands right behind
-- Buy Now and a see-through cover of the game's lies over the whole window, and each is nearer for the cursor
-- than Buy Now, so the arrow shows on Buy Now while the cursor is on what lies behind it and A does nothing (buy
-- probe, 2026-11-13: price quoted, Buy Now on, cursor on the cover, then on the amount box, never on Buy Now).
-- So the cover is marked as not the cursor's for good, and the page behind the dialog for as long as the dialog
-- is up. The marks are made by the game's own call for it, which writes them as the game's; out of a fight only.
local mend = { cover = false, page = nil }
local function MendBuyNow()
    local house = AuctionHouseFrame
    if not house or not SmartNavigation_MarkFrameIgnored or not SmartNavigation_ClearIgnoreStatus or InCombatLockdown() then
        return
    end
    if not mend.cover and house.DialogOverlay then
        mend.cover = true
        SmartNavigation_MarkFrameIgnored(house.DialogOverlay, true)
    end
    local dialog, page = house.BuyDialog, house.CommoditiesBuyFrame
    if not dialog or not page then return end
    local up = dialog:IsShown() and true or false
    if up and not mend.page then
        -- Never a page the game itself has marked: that mark is not ours to take off again.
        if page.smartNavigationIgnored then return end
        mend.page = page
        SmartNavigation_MarkFrameIgnored(page)
    elseif not up and mend.page then
        SmartNavigation_ClearIgnoreStatus(mend.page)
        mend.page = nil
    end
end

-- Its box gone from sight (the window shut), or the game's cursor gone: ours goes too.
function ns.DirectCheck(gone)
    MendBuyNow()
    if not proxy or not proxy:IsShown() then return end
    if gone or not target or target:IsForbidden() or not target:IsVisible() then
        proxy:ClearFocus()
        proxy:Hide()
    end
end
