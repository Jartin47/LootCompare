-- Loot Compare for WoW: Forever
-- Shows a small window comparing newly looted gear against what you have equipped.
--   Equip button      : equips the item shown (into the slot it's compared against)
--   Right-click window: dismisses just the item shown
--   X button          : dismisses everything

local ADDON_NAME = ...
local MAX_QUEUE = 20
local PREFIX = "|cffffd100Loot Compare|r "

---------------------------------------------------------------------------
-- Slot mapping
---------------------------------------------------------------------------
local SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3},
    INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged",
    INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged",
}

local function RangedSlots()
    local ok, id = pcall(GetInventorySlotInfo, "RangedSlot")
    if ok and id then return {id} end
    return {16}
end

local function ItemLevel(link)
    if not link then return 0 end
    return C_Item.GetDetailedItemLevelInfo(link) or 0
end

local function EquipLoc(link)
    if not link then return nil end
    return select(4, C_Item.GetItemInfoInstant(link))
end

local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function Quality(link)
    if not link then return nil end
    local _, _, quality = GetInfo(link)
    return quality
end

local function MinLevel(link)
    if not link then return 0 end
    local _, _, _, _, minLevel = GetInfo(link)
    return minLevel or 0
end

local function CanDW()
    return CanDualWield and CanDualWield()
end

local function InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

-- Returns: list of equipped links to compare against, a short label,
-- and the inventory slot the new item would be equipped into.
local function ResolveCompare(equipLoc)
    local slots = SLOTS[equipLoc]
    if slots == "ranged" then slots = RangedSlots() end
    if not slots then return {}, "", nil end

    local mh = GetInventoryItemLink("player", 16)
    local oh = GetInventoryItemLink("player", 17)
    local mhIs2H = EquipLoc(mh) == "INVTYPE_2HWEAPON"
    local mhLabel = mhIs2H and "Two-Hand" or "Main Hand"

    -- Two-hander vs main hand + off hand combined
    if equipLoc == "INVTYPE_2HWEAPON" then
        if mh and oh then return {mh, oh}, "Main + Off Hand", 16 end
        return {mh}, mhLabel, 16
    end

    -- Off-hand slot items (shield, held, off-hand weapon)
    if #slots == 1 and slots[1] == 17 then
        if not oh and mhIs2H then return {mh}, "Two-Hand", 17 end
        return {oh}, "Off Hand", 17
    end

    if equipLoc == "INVTYPE_WEAPONMAINHAND" then
        return {mh}, mhLabel, 16
    end

    -- One-handers: only compare against both hands if dual wielding weapons
    if equipLoc == "INVTYPE_WEAPON" then
        local ohLoc = EquipLoc(oh)
        local ohIsWeapon = ohLoc == "INVTYPE_WEAPON" or ohLoc == "INVTYPE_WEAPONOFFHAND"
        if mhIs2H or not CanDW() or (oh and not ohIsWeapon) then
            return {mh}, mhLabel, 16
        end
    end

    if #slots == 2 then
        local a = GetInventoryItemLink("player", slots[1])
        local b = GetInventoryItemLink("player", slots[2])
        if not a then return {}, "Empty slot", slots[1] end
        if not b then return {}, "Empty slot", slots[2] end
        -- Compare against the weaker of the two (the one you'd replace)
        if ItemLevel(b) < ItemLevel(a) then return {b}, "Weaker of pair", slots[2] end
        return {a}, "Weaker of pair", slots[1]
    end

    return {GetInventoryItemLink("player", slots[1])}, "Equipped", slots[1]
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------
local function StatsFor(links)
    local total = {}
    for i = 1, 2 do
        local link = links[i]
        if link then
            local s = C_Item.GetItemStats(link)
            if s then
                for k, v in pairs(s) do total[k] = (total[k] or 0) + v end
            end
        end
    end
    return total
end

local function StatName(key)
    local name = _G[key]
    if type(name) == "string" and name ~= "" then return name end
    return (key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "))
end

local function FormatNum(v)
    if math.abs(v - math.floor(v + 0.5)) > 0.05 then
        return string.format("%.1f", v)
    end
    return tostring(math.floor(v + 0.5))
end

local function BuildDiffLines(newStats, oldStats)
    local keys, seenKey = {}, {}
    for k in pairs(newStats) do if not seenKey[k] then seenKey[k] = true; keys[#keys + 1] = k end end
    for k in pairs(oldStats) do if not seenKey[k] then seenKey[k] = true; keys[#keys + 1] = k end end

    local ups, downs = {}, {}
    for _, k in ipairs(keys) do
        local d = (newStats[k] or 0) - (oldStats[k] or 0)
        if math.abs(d) > 0.05 then
            local line = { name = StatName(k), d = d }
            if d > 0 then ups[#ups + 1] = line else downs[#downs + 1] = line end
        end
    end
    table.sort(ups, function(a, b) return a.name < b.name end)
    table.sort(downs, function(a, b) return a.name < b.name end)

    local out = {}
    for _, l in ipairs(ups) do out[#out + 1] = "|cff20ff20+" .. FormatNum(l.d) .. " " .. l.name .. "|r" end
    for _, l in ipairs(downs) do out[#out + 1] = "|cffff4040" .. FormatNum(l.d) .. " " .. l.name .. "|r" end
    return out
end

---------------------------------------------------------------------------
-- Class usability: the game paints anything your class can't use in red on
-- the tooltip (wrong armor type, untrained weapon type, "Classes:" line).
-- Level requirements are ignored so gear you'll grow into still shows.
---------------------------------------------------------------------------
local function ToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%d", "%%d+"):gsub("%%s", ".+")
    return "^" .. fmt .. "$"
end
local IGNORE_RED = {}
for _, g in ipairs({ "ITEM_MIN_LEVEL", "ITEM_LEVEL_RANGE", "ITEM_LEVEL_RANGE_CURRENT" }) do
    local p = ToPattern(_G[g])
    if p then IGNORE_RED[#IGNORE_RED + 1] = p end
end

local function IsRed(r, g, b)
    return r and g and b and r > 0.9 and g < 0.2 and b < 0.2
end

local function IsIgnoredLine(text)
    if not text then return true end
    for _, p in ipairs(IGNORE_RED) do
        if text:match(p) then return true end
    end
    return false
end

local function LineBlocks(text, r, g, b)
    return text and text ~= "" and IsRed(r, g, b) and not IsIgnoredLine(text)
end

local scanTip
local function ClassCanUse(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        if data and data.lines then
            local sawColor = false
            for _, line in ipairs(data.lines) do
                local lc, rc = line.leftColor, line.rightColor
                if type(lc) ~= "table" then lc = nil end
                if type(rc) ~= "table" then rc = nil end
                if lc or rc then sawColor = true end
                if lc and LineBlocks(line.leftText, lc.r, lc.g, lc.b) then return false end
                if rc and LineBlocks(line.rightText, rc.r, rc.g, rc.b) then return false end
            end
            -- Some Forever builds return tooltip lines without colours. In
            -- that case we learned nothing, so use the scan tooltip below.
            if sawColor then return true end
        end
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "LootCompareScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    for i = 1, scanTip:NumLines() do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = _G["LootCompareScanTip" .. side .. i]
            if fs and fs:IsShown() and LineBlocks(fs:GetText(), fs:GetTextColor()) then
                scanTip:Hide()
                return false
            end
        end
    end
    scanTip:Hide()
    return true
end

---------------------------------------------------------------------------
-- Bag helpers
---------------------------------------------------------------------------
local seen = {}   -- item GUIDs we've already noticed in bags

local function FindInBags(guid)
    if not guid then return nil end
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if C_Item.DoesItemExist(loc) and C_Item.GetItemGUID(loc) == guid then
                return bag, slot
            end
        end
    end
end

local function EquippedGUIDs()
    local set = {}
    for slot = 1, 19 do
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        if C_Item.DoesItemExist(loc) then
            local g = C_Item.GetItemGUID(loc)
            if g then set[g] = slot end
        end
    end
    return set
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local queue, current = {}, 0
local frame = CreateFrame("Frame", "LootCompareFrame", UIParent, "BackdropTemplate")
frame:SetSize(300, 160)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
frame:SetBackdropBorderColor(0.65, 0.55, 0.35, 1)
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

local Render

-- X button: dismiss everything
local function DismissAll()
    wipe(queue)
    current = 0
    frame:Hide()
end

local function RemoveAt(i)
    table.remove(queue, i)
    if #queue == 0 then DismissAll() return end
    if i < current or current > #queue then current = math.max(1, current - 1) end
    if current > #queue then current = #queue end
end

-- Right-click: dismiss only the item being shown
local function DismissCurrent()
    if current == 0 then return end
    RemoveAt(current)
    if #queue > 0 then Render() end
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    LootCompareDB.point = { p, rp, x, y }
end)
frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then DismissCurrent() end
end)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
close:SetScript("OnClick", DismissAll)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("Loot Compare")

local counter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
counter:SetPoint("LEFT", title, "RIGHT", 6, 0)

local function MakeRow(yOff, label)
    local r = {}
    r.label = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.label:SetPoint("TOPLEFT", 12, yOff)
    r.label:SetText(label)

    r.icon = CreateFrame("Button", nil, frame)
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("TOPLEFT", 12, yOff - 13)
    r.tex = r.icon:CreateTexture(nil, "ARTWORK")
    r.tex:SetAllPoints()
    r.icon:SetScript("OnEnter", function(self)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    r.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- let right-click on the icon dismiss the current item too
    r.icon:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then DismissCurrent() end
    end)

    r.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    r.ilvl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.ilvl:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    return r
end

local newRow = MakeRow(-30, "LOOTED")
local oldRow = MakeRow(-78, "EQUIPPED")

local diffHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
diffHeader:SetPoint("TOPLEFT", 12, -128)
diffHeader:SetText("IF YOU EQUIP IT")

local diffText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
diffText:SetPoint("TOPLEFT", diffHeader, "BOTTOMLEFT", 0, -4)
diffText:SetWidth(276)
diffText:SetJustifyH("LEFT")
diffText:SetSpacing(2)

local function NavButton(text, point, x)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(26, 20)
    b:SetText(text)
    b:SetPoint("BOTTOM" .. point, x, 8)
    return b
end
local prevBtn = NavButton("<", "LEFT", 10)
local nextBtn = NavButton(">", "RIGHT", -10)

local equipBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
equipBtn:SetSize(140, 20)
equipBtn:SetPoint("BOTTOM", 0, 8)
equipBtn:SetText("Equip")

prevBtn:SetScript("OnClick", function()
    if current > 1 then current = current - 1; Render() end
end)
nextBtn:SetScript("OnClick", function()
    if current < #queue then current = current + 1; Render() end
end)

local function EquipCurrent()
    local entry = queue[current]
    if not entry then return end
    if InCombatLockdown() then
        print(PREFIX .. "can't equip gear during combat.")
        return
    end
    local bag, slot = FindInBags(entry.guid)
    if not bag then
        print(PREFIX .. "that item is no longer in your bags.")
        DismissCurrent()
        return
    end
    local _, _, target = ResolveCompare(EquipLoc(entry.link))
    if not target then return end

    -- Whatever comes off goes back into your bags; don't pop it up as "loot".
    for guid in pairs(EquippedGUIDs()) do seen[guid] = true end

    ClearCursor()
    C_Container.PickupContainerItem(bag, slot)
    EquipCursorItem(target)
    -- The entry is removed once PLAYER_EQUIPMENT_CHANGED confirms it's on.
    -- (Bind-on-equip items show the normal "bind it?" confirmation first.)
end
equipBtn:SetScript("OnClick", EquipCurrent)

local function ShouldHide()
    return LootCompareDB.hideInCombat and InCombat()
end

Render = function()
    local entry = queue[current]
    if not entry then DismissAll() return end

    local link = entry.link
    local equipLoc = EquipLoc(link)
    local oldLinks, oldLabel = ResolveCompare(equipLoc)
    local firstOld = oldLinks[1]

    -- Looted row
    local newIlvl = ItemLevel(link)
    local oldIlvl = ItemLevel(firstOld)
    local secondIlvl = oldLinks[2] and ItemLevel(oldLinks[2])
    newRow.icon.link = link
    newRow.tex:SetTexture(C_Item.GetItemIconByID(link) or 134400)
    newRow.name:SetText(link)
    -- Replacing two weapons with one: compare against their average
    local d = newIlvl - (secondIlvl and (oldIlvl + secondIlvl) / 2 or oldIlvl)
    local dTxt = ""
    if firstOld and math.abs(d) > 0.05 then
        dTxt = d > 0 and ("  |cff20ff20(+" .. FormatNum(d) .. ")|r")
            or ("  |cffff4040(" .. FormatNum(d) .. ")|r")
    end
    newRow.ilvl:SetText("Item Level " .. newIlvl .. dTxt)

    -- Equipped row
    oldRow.label:SetText("EQUIPPED  |cff808080" .. oldLabel .. "|r")
    oldRow.icon.link = firstOld
    if firstOld then
        oldRow.tex:SetTexture(C_Item.GetItemIconByID(firstOld) or 134400)
        local nameText = firstOld
        if oldLinks[2] then nameText = firstOld .. " + " .. oldLinks[2] end
        oldRow.name:SetText(nameText)
        oldRow.ilvl:SetText("Item Level " .. oldIlvl .. (secondIlvl and (" + " .. secondIlvl) or ""))
    else
        oldRow.tex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        oldRow.name:SetText("|cff808080(nothing equipped)|r")
        oldRow.ilvl:SetText("|cff20ff20Free upgrade!|r")
    end

    -- Stat differences
    local newStats, oldStats = StatsFor({link}), StatsFor(oldLinks)
    if oldLinks[2] then
        -- Adding main hand + off hand DPS together isn't a real number
        newStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = nil
        oldStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = nil
    end
    local lines = BuildDiffLines(newStats, oldStats)
    if #lines == 0 then
        diffText:SetText("|cffaaaaaaNo stat change|r")
    else
        diffText:SetText(table.concat(lines, "\n"))
    end

    -- Buttons / counter
    local multi = #queue > 1
    counter:SetText(multi and (current .. " of " .. #queue) or "")
    prevBtn:SetShown(multi)
    nextBtn:SetShown(multi)
    prevBtn:SetEnabled(current > 1)
    nextBtn:SetEnabled(current < #queue)
    local minLevel = MinLevel(link)
    if InCombatLockdown() then
        equipBtn:SetText("In combat")
        equipBtn:Disable()
    elseif minLevel > UnitLevel("player") then
        equipBtn:SetText("Requires level " .. minLevel)
        equipBtn:Disable()
    else
        equipBtn:SetText("Equip")
        equipBtn:Enable()
    end

    frame:SetHeight(128 + 16 + diffText:GetStringHeight() + 36)

    if ShouldHide() then
        frame:Hide()      -- will reappear when combat ends
    else
        frame:Show()
    end
end

-- Upgrade filter, judged per slot against what is equipped there, so it
-- tightens by itself as your gear improves. An item is shown when:
--   * the slot is empty, or
--   * it has a higher item level and is at most one quality tier lower, or
--   * it is higher quality and its item level is not lower.
local function PassesFilter(link)
    if not LootCompareDB.filter then return true end
    local oldLinks = ResolveCompare(EquipLoc(link))
    if not oldLinks[1] then return true end
    local newQ, newIlvl = Quality(link), ItemLevel(link)
    if not newQ then return true end
    for i = 1, 2 do
        local old = oldLinks[i]
        if old then
            local q, ilvl = Quality(old) or 0, ItemLevel(old)
            if (newIlvl > ilvl and newQ >= q - 1) or (newQ > q and newIlvl >= ilvl) then
                return true
            end
        end
    end
    return false
end

-- Returns true if the item was added. force skips the upgrade filter.
local function Enqueue(link, guid, force)
    if not link then return false end
    local equipLoc = EquipLoc(link)
    if not (equipLoc and SLOTS[equipLoc]) then return false end
    if not ClassCanUse(link) then return false end
    if not force and not PassesFilter(link) then return false end
    for _, e in ipairs(queue) do
        if guid and e.guid == guid then return false end
    end

    if #queue >= MAX_QUEUE then
        table.remove(queue, 1)
        if current > 1 then current = current - 1 end
    end
    queue[#queue + 1] = { link = link, guid = guid }

    -- Only jump to the new item if nothing was being shown;
    -- otherwise stay put and just bump the "x of y" counter.
    if current == 0 then current = #queue end
    Render()
    return true
end

---------------------------------------------------------------------------
-- Loot detection: watch bags for new equippable items
---------------------------------------------------------------------------
local ready = false

-- Returns the set of item GUIDs currently in the bags.
local function ScanBags(announce)
    local present = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if C_Item.DoesItemExist(loc) then
                local guid = C_Item.GetItemGUID(loc)
                if guid then present[guid] = true end
                if guid and not seen[guid] then
                    seen[guid] = true
                    if announce and LootCompareDB.enabled
                        and C_NewItems.IsNewItem(bag, slot) then
                        local item = Item:CreateFromItemLocation(loc)
                        item:ContinueOnItemLoad(function()
                            local link = item:GetItemLink()
                            if link and C_Item.IsEquippableItem(link) then
                                Enqueue(link, guid)
                            end
                        end)
                    end
                end
            end
        end
    end
    return present
end

-- Drop queued items that have left the bags (sold, banked, traded, destroyed)
local function PruneMissing(present)
    local changed = false
    for i = #queue, 1, -1 do
        local g = queue[i].guid
        if g and not present[g] then
            RemoveAt(i)
            changed = true
        end
    end
    if changed and #queue > 0 then Render() end
end

-- Drop any queued items that are now equipped (by our button or manually)
local function PruneEquipped()
    if #queue == 0 then return end
    local equipped = EquippedGUIDs()
    for i = #queue, 1, -1 do
        local g = queue[i].guid
        if g and equipped[g] then RemoveAt(i) end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        LootCompareDB = LootCompareDB or {}
        if LootCompareDB.enabled == nil then LootCompareDB.enabled = true end
        if LootCompareDB.hideInCombat == nil then LootCompareDB.hideInCombat = true end
        if LootCompareDB.filter == nil then LootCompareDB.filter = true end
        frame:ClearAllPoints()
        local p = LootCompareDB.point
        if p then
            frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 300, 100)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Remember everything already in the bags so we only react to new loot
        ScanBags(false)
        ready = true
    elseif event == "BAG_UPDATE_DELAYED" and ready then
        PruneMissing(ScanBags(true))
    elseif event == "PLAYER_LEVEL_UP" then
        -- A level-locked item may now be equippable
        C_Timer.After(0.5, function()
            if #queue > 0 then Render() end
        end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        PruneEquipped()
        if #queue > 0 then Render() end   -- refresh "equipped" side
    elseif event == "PLAYER_REGEN_DISABLED" then
        if #queue > 0 then Render() end   -- hides (option) / disables Equip
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- InCombatLockdown can lag a frame behind this event
        C_Timer.After(0.1, function()
            if #queue > 0 then Render() end
        end)
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_LOOTCOMPARE1 = "/lootcompare"
SLASH_LOOTCOMPARE2 = "/lcomp"
SlashCmdList.LOOTCOMPARE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "toggle" then
        LootCompareDB.enabled = not LootCompareDB.enabled
        print(PREFIX .. (LootCompareDB.enabled and "enabled" or "disabled"))
    elseif msg == "combat" then
        LootCompareDB.hideInCombat = not LootCompareDB.hideInCombat
        print(PREFIX .. "hide during combat: " .. (LootCompareDB.hideInCombat and "ON" or "OFF"))
        if #queue > 0 then Render() end
    elseif msg == "filter" then
        LootCompareDB.filter = not LootCompareDB.filter
        print(PREFIX .. "upgrade filter: " .. (LootCompareDB.filter
            and "ON (only likely upgrades pop up)" or "OFF (all usable gear pops up)"))
    elseif msg == "reset" then
        LootCompareDB.point = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 100)
        print(PREFIX .. "window position reset")
    elseif msg == "test" then
        local added = 0
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link and C_Item.IsEquippableItem(link) and SLOTS[EquipLoc(link) or ""] then
                    local guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
                    if Enqueue(link, guid, true) then
                        added = added + 1
                        if added >= 3 then return end
                    end
                end
            end
        end
        if added == 0 then
            print(PREFIX .. "no gear in your bags that your class can equip")
        end
    else
        print(PREFIX .. "commands:")
        print("  /lcomp test   - preview using up to 3 items from your bags")
        print("  /lcomp combat - toggle hiding the window during combat (currently "
            .. (LootCompareDB.hideInCombat and "ON" or "OFF") .. ")")
        print("  /lcomp filter - toggle the upgrade filter (currently "
            .. (LootCompareDB.filter and "ON" or "OFF") .. ")")
        print("  /lcomp toggle - turn popups on/off")
        print("  /lcomp reset  - reset window position")
    end
end
