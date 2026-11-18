-- Item level text on equipment in the default bag frames. Hooks are installed
-- once on first use; while the option is off they only hide their own text.
local driver = CreateFrame("Frame")
local labels = setmetatable({}, { __mode = "k" })
local hooked, pending = false, false
-- Equippable slots whose item level means nothing.
local IGNORED_SLOTS = { [""] = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_BAG = true,
    INVTYPE_QUIVER = true, INVTYPE_TABARD = true, INVTYPE_BODY = true }

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function readable(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(func, ...)
    if not ok or isSecret(a) then return nil end
    return a, b, c, d, e, f
end

local function enabled()
    return type(MimQoLDB) == "table" and MimQoLDB.bagItemLevel == true
end

local function bagFrames()
    local list = {}
    if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
    if ContainerFrameContainer and type(ContainerFrameContainer.ContainerFrames) == "table" then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do list[#list + 1] = frame end
    end
    return list
end

local function equipmentLevel(bag, slot)
    if not (C_Item and ItemLocation and type(bag) == "number" and type(slot) == "number") then return nil end
    local location = readable(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
    if not location or readable(C_Item.DoesItemExist, location) ~= true then return nil end
    local itemID = readable(C_Item.GetItemID, location)
    if not itemID then return nil end
    local _, _, _, equipLoc, _, classID = readable(C_Item.GetItemInfoInstant, itemID)
    if (classID ~= 2 and classID ~= 4) or isSecret(equipLoc) or type(equipLoc) ~= "string"
        or IGNORED_SLOTS[equipLoc] then return nil end
    if readable(C_Item.IsItemDataCached, location) == false then
        -- Upgrades change the level, so wait for the real data instead of guessing.
        readable(C_Item.RequestLoadItemData, location)
        pending = true
        return nil
    end
    local level = readable(C_Item.GetCurrentItemLevel, location)
    if type(level) ~= "number" or level <= 1 then return nil end
    return level, readable(C_Item.GetItemQuality, location)
end

local function updateButton(button)
    local text = labels[button]
    local level, quality
    if enabled() then
        local ok, bag, slot = pcall(function() return button:GetBagID(), button:GetID() end)
        if ok then level, quality = equipmentLevel(bag, slot) end
    end
    if not level then
        if text then text:Hide() end
        return
    end
    if not text then
        text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        text:SetDrawLayer("OVERLAY", 7)
        text:SetPoint("BOTTOM", 0, 2)
        labels[button] = text
    end
    text:SetFormattedText("%d", level)
    local r, g, b = 1, 1, 1
    if type(quality) == "number" and C_Item and type(C_Item.GetItemQualityColor) == "function" then
        local qr, qg, qb = readable(C_Item.GetItemQualityColor, quality)
        if type(qr) == "number" then r, g, b = qr, qg, qb end
    end
    text:SetTextColor(r, g, b)
    text:Show()
end

local function updateFrame(frame)
    if not enabled() or type(frame.EnumerateValidItems) ~= "function" then return end
    local ok, iterator, state, first = pcall(frame.EnumerateValidItems, frame)
    if not ok or type(iterator) ~= "function" then return end
    for _, button in iterator, state, first do updateButton(button) end
end

local function refresh()
    pending = false
    if not enabled() then
        for _, text in pairs(labels) do text:Hide() end
        return
    end
    for _, frame in ipairs(bagFrames()) do
        if frame:IsShown() then updateFrame(frame) end
    end
end

local function applySettings()
    driver:UnregisterAllEvents()
    if enabled() then
        if not hooked then
            hooked = true
            for _, frame in ipairs(bagFrames()) do
                if type(frame.UpdateItems) == "function" then hooksecurefunc(frame, "UpdateItems", updateFrame) end
            end
        end
        driver:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end
    refresh()
end

driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        applySettings()
    elseif pending then
        -- Several items usually arrive together; redraw once on the next frame.
        pending = false
        C_Timer.After(0, refresh)
    end
end)
driver:RegisterEvent("PLAYER_LOGIN")

_G.MimQoLBagItemLevel = { ApplySettings = applySettings }
