local ADDON_NAME = ...

if ADDON_NAME ~= "MimQoL" then
    return
end

local Keeper = {}

local ACTIONS_PER_BAR = 12
local MAX_ACTION_SLOT = 180
local RESTORE_DELAY = 0.85
local CAPTURE_DELAY = 0.65
local unpackTable = unpack or table.unpack

local state = {
    initialized = false,
    classProfile = nil,
    classKey = nil,
    className = nil,
    candidates = {},
    currentCandidate = nil,
    restoring = false,
    captureDepth = 0,
    transition = false,
    restoreToken = 0,
    captureToken = 0,
    pendingRestoreReason = nil,
    pendingCapture = false,
    pendingMissing = false,
    suppressCaptureUntil = 0,
    lastSpecID = nil,
    lastConfigID = nil,
    selectionFinished = nil,
}

local function trim(value)
    if type(value) ~= "string" then
        return value
    end
    return value:match("^%s*(.-)%s*$")
end

local function printMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb06cff[MimQoL]|r " .. tostring(message))
    end
end

local function getActionText(slot)
    if C_ActionBar and C_ActionBar.GetActionText then
        return C_ActionBar.GetActionText(slot)
    end
    if GetActionText then
        return GetActionText(slot)
    end
end

local function getSpecializationIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end
    if GetSpecialization then
        return GetSpecialization()
    end
end

local function getSpecializationID()
    local index = getSpecializationIndex()
    if not index then
        return nil
    end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(index)
    end
    if GetSpecializationInfo then
        return GetSpecializationInfo(index)
    end
end

local function getActiveConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return C_ClassTalents.GetActiveConfigID()
    end
end

local function getCurrentIdentity()
    return getSpecializationID(), getActiveConfigID()
end

local function syncIdentity()
    state.lastSpecID, state.lastConfigID = getCurrentIdentity()
end

local function identityChanged()
    local specID, configID = getCurrentIdentity()
    return specID ~= state.lastSpecID or configID ~= state.lastConfigID
end

local function getLegacyCharacterKey()
    local guid = UnitGUID("player")
    if guid then
        return guid
    end
    local name, realm = UnitFullName("player")
    if not name then
        return nil
    end
    return name .. "-" .. (realm or GetRealmName() or "")
end

local function getClassKey()
    local localizedName, classFile, classID = UnitClass("player")
    if classFile then
        return classFile, localizedName
    end
    if classID then
        return tostring(classID), localizedName
    end
end

local function initializeDatabase()
    MimQoLDB = type(MimQoLDB) == "table" and MimQoLDB or {}
    MimQoLDB.actionBarKeeper = type(MimQoLDB.actionBarKeeper) == "table"
        and MimQoLDB.actionBarKeeper or {}

    local root = MimQoLDB.actionBarKeeper
    root.version = 2
    root.classes = type(root.classes) == "table" and root.classes or {}

    local classKey, className = getClassKey()
    if not classKey then
        return false
    end

    local classProfile = root.classes[classKey]
    if type(classProfile) ~= "table" then
        classProfile = {}
        root.classes[classKey] = classProfile
    end
    local legacyKey = getLegacyCharacterKey()
    if legacyKey and not classProfile.migratedFromCharacterV1 then
        local legacy = type(root.characters) == "table"
            and root.characters[legacyKey]
        local hasClassBars = type(classProfile.bars) == "table"
            and next(classProfile.bars) ~= nil
        local hasLegacyBars = type(legacy) == "table"
            and type(legacy.bars) == "table" and next(legacy.bars) ~= nil
        if not hasClassBars and hasLegacyBars then
            classProfile = legacy
            root.classes[classKey] = classProfile
        end
        classProfile.migratedFromCharacterV1 = true
    end
    classProfile.bars = type(classProfile.bars) == "table" and classProfile.bars or {}
    state.classProfile = classProfile
    state.classKey = classKey
    state.className = className or classKey
    state.initialized = true
    syncIdentity()
    return true
end

local function isEmptyAction(action)
    return action == nil or action == false or type(action) ~= "table" or action.type == nil
end

local function normalizeSpellID(spellID)
    if type(spellID) ~= "number" then
        return spellID
    end
    if FindBaseSpellByID then
        local baseSpellID = FindBaseSpellByID(spellID)
        if baseSpellID then
            return baseSpellID
        end
    end
    if C_Spell and C_Spell.GetBaseSpell then
        local baseSpellID = C_Spell.GetBaseSpell(spellID)
        if baseSpellID then
            return baseSpellID
        end
    end
    return spellID
end

local function captureAction(slot)
    local actionType, id, subType = GetActionInfo(slot)
    if not actionType then
        return false
    end

    if subType == "assistedcombat" then
        id = 1229376
        subType = "spell"
    end

    if actionType == "spell" then
        id = normalizeSpellID(id)
    elseif actionType == "macro" then
        if not id or id == 0 then
            return false
        end
    end

    local action = {
        type = actionType,
        id = id,
        subType = subType,
        name = getActionText(slot),
    }

    if actionType == "macro" then
        action.macroText = trim(GetMacroBody(id) or "")
        local macroName = GetMacroInfo(id)
        action.name = macroName or action.name
    end

    return action
end

local function captureSlots(slots)
    if InCombatLockdown() or GetCursorInfo() then
        return nil
    end

    state.captureDepth = state.captureDepth + 1
    local ok, actions = pcall(function()
        local result = {}
        for index, slot in ipairs(slots) do
            result[index] = captureAction(slot)
        end
        return result
    end)
    state.captureDepth = math.max(0, state.captureDepth - 1)
    if not ok then
        ClearCursor()
        return nil
    end
    return actions
end

local function actionsEqual(first, second)
    if isEmptyAction(first) or isEmptyAction(second) then
        return isEmptyAction(first) and isEmptyAction(second)
    end
    if first.type ~= second.type or first.subType ~= second.subType then
        return false
    end
    if first.type == "macro" then
        if first.id and second.id and first.id == second.id then
            return true
        end
        local firstBody = trim(first.macroText or "")
        local secondBody = trim(second.macroText or "")
        if firstBody ~= "" and secondBody ~= "" then
            return firstBody == secondBody
        end
        return first.name == second.name
    end
    return first.id == second.id
end

local function snapshotsEqual(first, second)
    if type(first) ~= "table" or type(second) ~= "table" then
        return false
    end
    for index = 1, ACTIONS_PER_BAR do
        if not actionsEqual(first[index], second[index]) then
            return false
        end
    end
    return true
end

local function findMacro(action)
    local wantedBody = trim(action.macroText or "")
    local globalCount, characterCount = GetNumMacros()

    if wantedBody ~= "" then
        for index = 1, globalCount do
            if trim(GetMacroBody(index) or "") == wantedBody then
                return index
            end
        end
        local firstCharacterMacro = (MAX_ACCOUNT_MACROS or 120) + 1
        for index = firstCharacterMacro, firstCharacterMacro + characterCount - 1 do
            if trim(GetMacroBody(index) or "") == wantedBody then
                return index
            end
        end
    end

    if action.name and GetMacroIndexByName then
        local index = GetMacroIndexByName(action.name)
        if index and index > 0 then
            return index
        end
    end

    if action.id and GetMacroInfo(action.id) then
        return action.id
    end
end

local function pickupBagItem(itemID)
    if not C_Container then
        return false
    end

    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local bagItemID = info and info.itemID
            if bagItemID == itemID then
                C_Container.PickupContainerItem(bag, slot)
                if GetCursorInfo() then
                    return true
                end
            end
        end
    end
    return false
end

local function findSpellBookItem(wantedType, wantedID)
    if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then
        return nil
    end

    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local numLines = C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetNumSpellBookSkillLines() or 0

    for line = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo then
            local firstIndex = (lineInfo.itemIndexOffset or 0) + 1
            local lastIndex = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
            for index = firstIndex, lastIndex do
                local info = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if info then
                    local isFlyout = Enum and Enum.SpellBookItemType
                        and info.itemType == Enum.SpellBookItemType.Flyout
                    local isSpell = Enum and Enum.SpellBookItemType
                        and info.itemType == Enum.SpellBookItemType.Spell
                    if wantedType == "flyout" and isFlyout and info.actionID == wantedID then
                        return index, bank
                    elseif wantedType == "spell" and isSpell
                        and normalizeSpellID(info.spellID or info.actionID) == wantedID then
                        return index, bank
                    end
                end
            end
        end
    end
end

local function pickupMount(mountID)
    if not C_MountJournal then
        return false
    end
    if mountID == 0xFFFFFFF then
        C_MountJournal.Pickup(0)
        return GetCursorInfo() ~= nil
    end

    local displayedCount = C_MountJournal.GetNumDisplayedMounts()
    for index = 1, displayedCount do
        local displayedMountID = select(12, C_MountJournal.GetDisplayedMountInfo(index))
        if displayedMountID == mountID then
            C_MountJournal.Pickup(index)
            if GetCursorInfo() then
                return true
            end
        end
    end

    local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
    if spellID and C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(spellID)
        return GetCursorInfo() ~= nil
    end
    return false
end

local function pickupDescriptor(action)
    if isEmptyAction(action) then
        return true
    end

    ClearCursor()
    local ok = pcall(function()
        if action.type == "macro" then
            local macroID = findMacro(action)
            if macroID then
                PickupMacro(macroID)
            end
        elseif action.type == "spell" then
            if action.subType == "pet" and PickupPetSpell then
                PickupPetSpell(action.id)
            elseif C_Spell and C_Spell.PickupSpell then
                C_Spell.PickupSpell(action.id)
            elseif PickupSpell then
                PickupSpell(action.id)
            end
        elseif action.type == "item" then
            if not pickupBagItem(action.id) then
                if C_Item and C_Item.PickupItem then
                    C_Item.PickupItem(action.id)
                elseif PickupItem then
                    PickupItem(action.id)
                end
            end
        elseif action.type == "summonmount" then
            pickupMount(action.id)
        elseif action.type == "summonpet" then
            if C_PetJournal and C_PetJournal.PickupPet then
                C_PetJournal.PickupPet(action.id)
            end
        elseif action.type == "companion" then
            if C_Spell and C_Spell.PickupSpell then
                C_Spell.PickupSpell(action.id)
            elseif PickupSpell then
                PickupSpell(action.id)
            end
        elseif action.type == "equipmentset" then
            if C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then
                local equipmentSetID = C_EquipmentSet.GetEquipmentSetID
                    and C_EquipmentSet.GetEquipmentSetID(action.id) or action.id
                C_EquipmentSet.PickupEquipmentSet(equipmentSetID)
            end
        elseif action.type == "flyout" then
            local index, bank = findSpellBookItem("flyout", action.id)
            if index and C_SpellBook and C_SpellBook.PickupSpellBookItem then
                C_SpellBook.PickupSpellBookItem(index, bank)
            end
        end
    end)

    return ok and GetCursorInfo() ~= nil
end

local function cursorSignature()
    local cursorType, id, subType, extra = GetCursorInfo()
    return table.concat({
        tostring(cursorType or ""),
        tostring(id or ""),
        tostring(subType or ""),
        tostring(extra or ""),
    }, ":")
end

local function clearSlot(slot)
    local actionType = GetActionInfo(slot)
    if not actionType then
        return true
    end
    local ok = pcall(function()
        ClearCursor()
        PickupAction(slot)
        ClearCursor()
    end)
    return ok and GetActionInfo(slot) == nil
end

local function setSlot(slot, action, currentAction)
    if isEmptyAction(action) then
        return clearSlot(slot), false
    end
    if actionsEqual(action, currentAction) then
        return true, false
    end

    if not pickupDescriptor(action) then
        clearSlot(slot)
        return false, true
    end

    local before = cursorSignature()
    local placed = pcall(PlaceAction, slot)
    local after = cursorSignature()
    ClearCursor()

    if not placed or before == after then
        clearSlot(slot)
        return false, true
    end
    return true, false
end

local function selectedBarCount()
    if not state.classProfile or type(state.classProfile.bars) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(state.classProfile.bars) do
        count = count + 1
    end
    return count
end

local function hasSelectedSlot(slot)
    if not state.classProfile then
        return false
    end
    if type(slot) ~= "number" or slot <= 0 then
        return selectedBarCount() > 0
    end
    for _, bar in pairs(state.classProfile.bars) do
        for _, selectedSlot in ipairs(bar.slots or {}) do
            if selectedSlot == slot then
                return true
            end
        end
    end
    return false
end

local scheduleRestore
local scheduleCapture

local function applyDesiredActions(reason, overrideBars)
    if not state.initialized and not initializeDatabase() then
        return false
    end
    if InCombatLockdown() then
        state.pendingRestoreReason = reason or "대기 중"
        return false
    end
    if GetCursorInfo() then
        state.pendingRestoreReason = reason or "대기 중"
        C_Timer.After(0.5, function()
            if not GetCursorInfo() and state.pendingRestoreReason then
                scheduleRestore(state.pendingRestoreReason, 0)
            end
        end)
        return false
    end

    local bars = overrideBars or state.classProfile.bars
    if type(bars) ~= "table" then
        return true
    end

    local desiredBySlot = {}
    local currentBySlot = {}
    local backupBars = {}
    local different = false

    for key, bar in pairs(bars) do
        if type(bar.slots) == "table" and type(bar.actions) == "table" then
            local currentActions = captureSlots(bar.slots)
            if not currentActions then
                state.pendingRestoreReason = reason or "대기 중"
                return false
            end
            backupBars[key] = {
                label = bar.label,
                provider = bar.provider,
                slots = { unpackTable(bar.slots) },
                actions = currentActions,
            }
            if not snapshotsEqual(currentActions, bar.actions) then
                different = true
            end
            for index, slot in ipairs(bar.slots) do
                desiredBySlot[slot] = bar.actions[index]
                currentBySlot[slot] = currentActions[index]
            end
        end
    end

    if not different then
        state.pendingRestoreReason = nil
        state.transition = false
        state.pendingMissing = false
        syncIdentity()
        return true
    end

    if not overrideBars and reason ~= "사용 가능 동작 재확인" then
        state.classProfile.backup = {
            createdAt = GetServerTime and GetServerTime() or time(),
            reason = reason,
            bars = backupBars,
        }
    end

    local slots = {}
    for slot in pairs(desiredBySlot) do
        slots[#slots + 1] = slot
    end
    table.sort(slots)

    state.restoring = true
    local failures = 0
    for _, slot in ipairs(slots) do
        local _, unavailable = setSlot(slot, desiredBySlot[slot], currentBySlot[slot])
        if unavailable then
            failures = failures + 1
        end
    end
    state.restoring = false
    state.suppressCaptureUntil = GetTime() + 1.25
    state.pendingRestoreReason = nil
    state.transition = false
    state.pendingMissing = failures > 0
    syncIdentity()

    if failures > 0 then
        printMessage(string.format(
            "공용 행동단축바 복원 중 %d칸은 현재 사용할 수 없어 비워 두었습니다.", failures))
    end
    return true
end

scheduleRestore = function(reason, delay)
    state.pendingRestoreReason = reason or state.pendingRestoreReason or "자동 복원"
    state.restoreToken = state.restoreToken + 1
    local token = state.restoreToken
    C_Timer.After(delay == nil and RESTORE_DELAY or delay, function()
        if token ~= state.restoreToken then
            return
        end
        applyDesiredActions(state.pendingRestoreReason)
    end)
end

local function beginTransition(reason)
    if selectedBarCount() == 0 then
        syncIdentity()
        return
    end
    state.transition = true
    state.pendingCapture = false
    state.captureToken = state.captureToken + 1
    scheduleRestore(reason or "특성 변경", RESTORE_DELAY)
end

local function captureSelectedBars()
    if not state.initialized or selectedBarCount() == 0 then
        state.pendingCapture = false
        return
    end
    if state.restoring or state.transition or GetTime() < state.suppressCaptureUntil then
        scheduleCapture(CAPTURE_DELAY)
        return
    end
    if identityChanged() then
        beginTransition("특성 변경")
        return
    end
    if InCombatLockdown() or GetCursorInfo() then
        state.pendingCapture = true
        return
    end

    for _, bar in pairs(state.classProfile.bars) do
        local actions = captureSlots(bar.slots or {})
        if actions then
            bar.actions = actions
        end
    end
    state.pendingCapture = false
    state.pendingMissing = false
end

scheduleCapture = function(delay)
    state.pendingCapture = true
    state.captureToken = state.captureToken + 1
    local token = state.captureToken
    C_Timer.After(delay == nil and CAPTURE_DELAY or delay, function()
        if token == state.captureToken then
            captureSelectedBars()
        end
    end)
end

local function resolveButtonSlot(button)
    if not button then
        return nil
    end

    local slot = tonumber(button._state_action) or tonumber(button.action)
    if slot and slot > 0 and slot <= MAX_ACTION_SLOT then
        return slot
    end

    if button.GetAttribute then
        local ok, attribute = pcall(button.GetAttribute, button, "action")
        slot = ok and tonumber(attribute) or nil
        if slot and slot > 0 and slot <= MAX_ACTION_SLOT then
            return slot
        end
    end

    if button.GetAction then
        local ok, actionType, actionID = pcall(button.GetAction, button)
        if ok and actionType == "action" then
            slot = tonumber(actionID)
            if slot and slot > 0 and slot <= MAX_ACTION_SLOT then
                return slot
            end
        end
    end
end

local function isFrameVisible(frame)
    if not frame or not frame.IsVisible then
        return false
    end
    local ok, visible = pcall(frame.IsVisible, frame)
    return ok and visible
end

local function getFrameRect(frame)
    if not isFrameVisible(frame) or not frame.GetLeft then
        return nil
    end
    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom or not width or not height then
        return nil
    end

    -- GetRect() uses the frame's effective coordinate scale.  Action-bar addons
    -- commonly scale each bar independently, while the selector is anchored to
    -- UIParent. Convert every rectangle into UIParent coordinates first.
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scale = parentScale > 0 and (frameScale / parentScale) or 1
    left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale

    if width >= 8 and height >= 8 then
        return left, bottom, left + width, bottom + height
    end
end

local function getCandidateBounds(frame, buttons)
    local left, bottom, right, top
    local visibleButtons = 0
    for _, button in ipairs(buttons or {}) do
        local buttonLeft, buttonBottom, buttonRight, buttonTop = getFrameRect(button)
        if buttonLeft then
            left = left and math.min(left, buttonLeft) or buttonLeft
            bottom = bottom and math.min(bottom, buttonBottom) or buttonBottom
            right = right and math.max(right, buttonRight) or buttonRight
            top = top and math.max(top, buttonTop) or buttonTop
            visibleButtons = visibleButtons + 1
        end
    end
    if visibleButtons >= 2 then
        return left, bottom, right, top
    end
    return getFrameRect(frame)
end

local function commonParent(buttons)
    local parent
    for _, button in ipairs(buttons or {}) do
        if button and button.GetParent then
            local buttonParent = button:GetParent()
            if not parent then
                parent = buttonParent
            elseif parent ~= buttonParent then
                return parent
            end
        end
    end
    return parent
end

local function pageSlots(page)
    local slots = {}
    local firstSlot = ((page - 1) * ACTIONS_PER_BAR) + 1
    for index = 0, ACTIONS_PER_BAR - 1 do
        slots[#slots + 1] = firstSlot + index
    end
    return slots
end

local function resolvePage(buttons, fallbackPage)
    local pages = {}
    local bestPage, bestCount
    for _, button in ipairs(buttons or {}) do
        local slot = resolveButtonSlot(button)
        if slot then
            local page = math.floor((slot - 1) / ACTIONS_PER_BAR) + 1
            pages[page] = (pages[page] or 0) + 1
            if not bestCount or pages[page] > bestCount then
                bestPage, bestCount = page, pages[page]
            end
        end
    end
    if bestCount and bestCount >= 2 then
        return bestPage
    end
    return fallbackPage
end

local function addCandidate(list, seen, provider, label, frame, buttons, fallbackPage)
    local page = resolvePage(buttons, fallbackPage)
    if not page or page < 1 or page > 15 or (page > 10 and page < 13) then
        return
    end

    local key = "page:" .. page
    if seen[key] then
        return
    end

    local left, bottom, right, top = getCandidateBounds(frame, buttons)
    if not left or right <= left or top <= bottom then
        return
    end

    seen[key] = true
    list[#list + 1] = {
        key = key,
        provider = provider,
        label = label,
        page = page,
        slots = pageSlots(page),
        left = left,
        bottom = bottom,
        right = right,
        top = top,
        area = (right - left) * (top - bottom),
    }
end

local function collectEllesmereCandidates(list, seen)
    local bars = {
        { key = "MainBar", label = "행동 단축바 1", page = 1 },
        { key = "Bar2", label = "행동 단축바 2", page = 6 },
        { key = "Bar3", label = "행동 단축바 3", page = 5 },
        { key = "Bar4", label = "행동 단축바 4", page = 3 },
        { key = "Bar5", label = "행동 단축바 5", page = 4 },
        { key = "Bar6", label = "행동 단축바 6", page = 13 },
        { key = "Bar7", label = "행동 단축바 7", page = 14 },
        { key = "Bar8", label = "행동 단축바 8", page = 15 },
        { key = "Bar9", label = "행동 단축바 9", page = 2 },
        { key = "Bar10", label = "행동 단축바 10", page = 10 },
    }

    local ellesmere = _G.EllesmereUI
    local moduleNamespace = ellesmere and ellesmere._ModuleNS
        and ellesmere._ModuleNS.EllesmereUIActionBars
    local registeredButtons = moduleNamespace and moduleNamespace.barButtons

    for _, info in ipairs(bars) do
        local buttons = {}
        local registered = registeredButtons and registeredButtons[info.key]
        if type(registered) == "table" then
            for _, button in pairs(registered) do
                if button and button.GetRect then
                    buttons[#buttons + 1] = button
                end
            end
        end

        local bar = _G["EABBar_" .. info.key]
        if #buttons == 0 and bar then
            local barButtons = bar.buttons or bar.actionButtons
            if type(barButtons) == "table" then
                for _, button in pairs(barButtons) do
                    if button and button.GetRect then
                        buttons[#buttons + 1] = button
                    end
                end
            end
        end

        -- Compatibility with older EllesmereUI builds that exposed buttons by
        -- their Blizzard action slot instead of the MainBar/BarN registry.
        if #buttons == 0 then
            local firstSlot = ((info.page - 1) * ACTIONS_PER_BAR) + 1
            for slot = firstSlot, firstSlot + ACTIONS_PER_BAR - 1 do
                local button = _G["EABButton" .. slot]
                if button then
                    buttons[#buttons + 1] = button
                end
            end
        end
        if #buttons > 0 then
            addCandidate(list, seen, "EllesmereUI", info.label,
                bar or commonParent(buttons), buttons, info.page)
        end
    end
end

local function collectElvUICandidates(list, seen)
    local barIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }
    for _, barID in ipairs(barIDs) do
        local bar = _G["ElvUI_Bar" .. barID]
        if bar then
            local buttons = bar.buttons or {}
            addCandidate(list, seen, "ElvUI", "행동 단축바 " .. barID,
                bar, buttons, barID)
        end
    end
end

local function collectBartenderCandidates(list, seen)
    if not Bartender4 or not Bartender4.GetModule then
        return
    end
    local ok, module = pcall(Bartender4.GetModule, Bartender4, "ActionBars", true)
    if not ok or not module or type(module.actionbars) ~= "table" then
        return
    end
    local visualMap = module.BLIZZARD_BAR_MAP or {
        [6] = 2, [5] = 3, [3] = 4, [4] = 5, [13] = 6, [14] = 7, [15] = 8,
    }
    for page, bar in pairs(module.actionbars) do
        local visualID = visualMap[page] or page
        addCandidate(list, seen, "Bartender4", "행동 단축바 " .. visualID,
            bar, bar.buttons or {}, page)
    end
end

local function collectDominosCandidates(list, seen)
    local buttonsTable = Dominos and Dominos.ActionButtons and Dominos.ActionButtons.buttons
    if type(buttonsTable) ~= "table" then
        return
    end
    local grouped = {}
    for button in pairs(buttonsTable) do
        local slot = resolveButtonSlot(button)
        if slot then
            local page = math.floor((slot - 1) / ACTIONS_PER_BAR) + 1
            grouped[page] = grouped[page] or {}
            grouped[page][#grouped[page] + 1] = button
        end
    end
    for page, buttons in pairs(grouped) do
        addCandidate(list, seen, "Dominos", "행동 단축바 " .. page,
            commonParent(buttons), buttons, page)
    end
end

local function collectBlizzardCandidates(list, seen)
    local bars = {
        { "행동 단축바 1", 1, _G.MainActionBar or _G.MainMenuBar, "ActionButton" },
        { "행동 단축바 2", 6, _G.MultiBarBottomLeft, "MultiBarBottomLeftButton" },
        { "행동 단축바 3", 5, _G.MultiBarBottomRight, "MultiBarBottomRightButton" },
        { "행동 단축바 4", 3, _G.MultiBarRight, "MultiBarRightButton" },
        { "행동 단축바 5", 4, _G.MultiBarLeft, "MultiBarLeftButton" },
        { "행동 단축바 6", 13, _G.MultiBar5, "MultiBar5Button" },
        { "행동 단축바 7", 14, _G.MultiBar6, "MultiBar6Button" },
        { "행동 단축바 8", 15, _G.MultiBar7, "MultiBar7Button" },
    }
    for _, info in ipairs(bars) do
        local buttons = info[3] and info[3].actionButtons or {}
        if #buttons == 0 then
            buttons = {}
            for index = 1, ACTIONS_PER_BAR do
                local button = _G[info[4] .. index]
                if button then
                    buttons[#buttons + 1] = button
                end
            end
        end
        if #buttons > 0 then
            addCandidate(list, seen, "Blizzard", info[1], info[3], buttons, info[2])
        end
    end
end

local function rebuildCandidates()
    local list, seen = {}, {}
    collectEllesmereCandidates(list, seen)
    collectElvUICandidates(list, seen)
    collectBartenderCandidates(list, seen)
    collectDominosCandidates(list, seen)
    collectBlizzardCandidates(list, seen)
    state.candidates = list
end

local selector = CreateFrame("Frame", "MimQoLActionBarSelector", UIParent)
selector:SetSize(1, 1)
selector:SetPoint("CENTER")
selector:Hide()

local banner = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
banner:SetSize(560, 54)
banner:SetPoint("TOP", UIParent, "TOP", 0, -110)
banner:SetFrameStrata("DIALOG")
banner:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
banner:SetBackdropColor(0.04, 0.04, 0.06, 0.94)
banner:SetBackdropBorderColor(0.69, 0.42, 1, 1)
banner:Hide()

local bannerText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
bannerText:SetPoint("TOP", 0, -9)
bannerText:SetText("공용으로 유지할 행동 단축바를 클릭하세요")
local bannerHint = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bannerHint:SetPoint("TOP", bannerText, "BOTTOM", 0, -4)
bannerHint:SetText("여러 개 선택할 수 있습니다. 다시 클릭하면 해제 · ESC로 완료")

local overlay = CreateFrame("Button", nil, UIParent)
overlay:SetFrameStrata("TOOLTIP")
overlay:RegisterForClicks("LeftButtonUp")
overlay:Hide()

local overlayFill = overlay:CreateTexture(nil, "BACKGROUND")
overlayFill:SetAllPoints()
local overlayEdges = {}
for index = 1, 4 do
    overlayEdges[index] = overlay:CreateTexture(nil, "OVERLAY")
end
overlayEdges[1]:SetPoint("TOPLEFT")
overlayEdges[1]:SetPoint("TOPRIGHT")
overlayEdges[1]:SetHeight(3)
overlayEdges[2]:SetPoint("BOTTOMLEFT")
overlayEdges[2]:SetPoint("BOTTOMRIGHT")
overlayEdges[2]:SetHeight(3)
overlayEdges[3]:SetPoint("TOPLEFT")
overlayEdges[3]:SetPoint("BOTTOMLEFT")
overlayEdges[3]:SetWidth(3)
overlayEdges[4]:SetPoint("TOPRIGHT")
overlayEdges[4]:SetPoint("BOTTOMRIGHT")
overlayEdges[4]:SetWidth(3)

local overlayLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
overlayLabel:SetPoint("BOTTOM", overlay, "TOP", 0, 7)
overlayLabel:SetShadowOffset(1, -1)

local function setOverlayColor(selected)
    local red, green, blue = 1, 0.68, 0.08
    if selected then
        red, green, blue = 0.18, 1, 0.34
    end
    overlayFill:SetColorTexture(red, green, blue, 0.13)
    for _, edge in ipairs(overlayEdges) do
        edge:SetColorTexture(red, green, blue, 1)
    end
    overlayLabel:SetTextColor(red, green, blue)
end

local function updateOverlay(candidate)
    if not candidate then
        state.currentCandidate = nil
        overlay:Hide()
        return
    end

    state.currentCandidate = candidate
    local selected = state.classProfile and state.classProfile.bars[candidate.key] ~= nil
    setOverlayColor(selected)
    overlayLabel:SetText(candidate.label .. (selected and "  |  공용 (클릭하여 해제)" or "  |  클릭하여 공용으로 설정"))
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", candidate.left - 3, candidate.bottom - 3)
    overlay:SetSize((candidate.right - candidate.left) + 6, (candidate.top - candidate.bottom) + 6)
    overlay:Show()
end

local function findCandidateAtCursor()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    local best
    for _, candidate in ipairs(state.candidates) do
        if cursorX >= candidate.left and cursorX <= candidate.right
            and cursorY >= candidate.bottom and cursorY <= candidate.top
            and (not best or candidate.area < best.area) then
            best = candidate
        end
    end
    return best
end

local function toggleCandidate(candidate)
    if not candidate or not state.classProfile then
        return
    end
    if InCombatLockdown() then
        printMessage("전투 중에는 공용 행동단축바를 설정할 수 없습니다.")
        return
    end
    if GetCursorInfo() then
        printMessage("마우스 커서에 들고 있는 동작을 내려놓은 뒤 다시 시도해 주세요.")
        return
    end

    if state.classProfile.bars[candidate.key] then
        state.classProfile.bars[candidate.key] = nil
        printMessage("공용 행동단축바 설정이 해제되었습니다.")
    else
        local actions = captureSlots(candidate.slots)
        if not actions then
            printMessage("현재 행동단축바를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.")
            return
        end
        state.classProfile.bars[candidate.key] = {
            label = candidate.label,
            provider = candidate.provider,
            page = candidate.page,
            slots = { unpackTable(candidate.slots) },
            actions = actions,
        }
        printMessage("공용 행동단축바로 설정되었습니다.")
    end
    updateOverlay(candidate)
end

overlay:SetScript("OnClick", function()
    toggleCandidate(state.currentCandidate)
end)

selector:SetScript("OnShow", function(self)
    self.elapsed = 0
    rebuildCandidates()
    banner:Show()
    printMessage("공용으로 유지할 행동단축바를 클릭하세요. ESC를 누르면 완료됩니다.")
end)

selector:SetScript("OnHide", function()
    banner:Hide()
    overlay:Hide()
    state.currentCandidate = nil
    local callback = state.selectionFinished
    state.selectionFinished = nil
    if callback then
        C_Timer.After(0, callback)
    end
end)

selector:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        rebuildCandidates()
    end
    updateOverlay(findCandidateAtCursor())
end)

if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = selector:GetName()
end

function Keeper.StartSelection(onFinished)
    if not state.initialized and not initializeDatabase() then
        printMessage("캐릭터 정보를 불러온 뒤 다시 시도해 주세요.")
        return false
    end
    if InCombatLockdown() then
        printMessage("전투가 끝난 뒤 공용 행동단축바를 설정해 주세요.")
        return false
    end
    state.selectionFinished = type(onFinished) == "function" and onFinished or nil
    if not selector:IsShown() then
        selector:Show()
    end
    return true
end

function Keeper.ToggleSelection()
    if selector:IsShown() then
        selector:Hide()
        return
    end
    Keeper.StartSelection()
end

function Keeper.RestoreNow()
    if InCombatLockdown() then
        state.pendingRestoreReason = "수동 복원"
        printMessage("전투가 끝나면 공용 행동단축바를 복원합니다.")
        return
    end
    if applyDesiredActions("수동 복원") then
        printMessage("공용 행동단축바를 확인했습니다.")
    else
        printMessage("마우스 커서를 비우면 공용 행동단축바를 확인합니다.")
    end
end

function Keeper.Undo()
    if not state.initialized and not initializeDatabase() then
        return
    end
    local backup = state.classProfile.backup
    if not backup or type(backup.bars) ~= "table" then
        printMessage("되돌릴 행동단축바 백업이 없습니다.")
        return
    end
    if InCombatLockdown() or GetCursorInfo() then
        printMessage("전투를 마치고 마우스 커서를 비운 뒤 다시 시도해 주세요.")
        return
    end

    if applyDesiredActions("되돌리기", backup.bars) then
        for key, backupBar in pairs(backup.bars) do
            local selectedBar = state.classProfile.bars[key]
            if selectedBar then
                selectedBar.actions = backupBar.actions
            end
        end
        state.classProfile.backup = nil
        state.suppressCaptureUntil = GetTime() + 1.25
        printMessage("마지막 자동 복원 전 상태로 되돌렸습니다.")
    end
end

function Keeper.GetUIStatus()
    if not state.initialized then
        initializeDatabase()
    end

    local specName
    local specIndex = getSpecializationIndex()
    if specIndex then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            specName = select(2, C_SpecializationInfo.GetSpecializationInfo(specIndex))
        elseif GetSpecializationInfo then
            specName = select(2, GetSpecializationInfo(specIndex))
        end
    end

    local bars = {}
    if state.classProfile then
        for key, bar in pairs(state.classProfile.bars) do
            bars[#bars + 1] = {
                key = key,
                label = bar.label or ("행동 단축바 " .. tostring(bar.page or "")),
                page = bar.page or 0,
            }
        end
    end
    table.sort(bars, function(first, second)
        if first.page == second.page then
            return first.key < second.key
        end
        return first.page < second.page
    end)

    return {
        className = state.className or select(1, UnitClass("player")) or "현재 직업",
        specName = specName,
        bars = bars,
        count = #bars,
        canUndo = state.classProfile and state.classProfile.backup ~= nil or false,
    }
end

function Keeper.RemoveBar(key)
    if not state.initialized and not initializeDatabase() then
        return false
    end
    if type(key) ~= "string" or not state.classProfile.bars[key] then
        return false
    end
    state.classProfile.bars[key] = nil
    printMessage("공용 행동단축바 설정이 해제되었습니다.")
    return true
end

_G.MimQoLActionBarKeeper_Toggle = Keeper.ToggleSelection
_G.MimQoLActionBarKeeper_StartSelection = Keeper.StartSelection
_G.MimQoLActionBarKeeper_GetUIStatus = Keeper.GetUIStatus
_G.MimQoLActionBarKeeper_RemoveBar = Keeper.RemoveBar
_G.MimQoLActionBarKeeper_RestoreNow = Keeper.RestoreNow
_G.MimQoLActionBarKeeper_Undo = Keeper.Undo
_G.MimQoLActionBarKeeper_GetCount = function()
    if not state.initialized then
        initializeDatabase()
    end
    return selectedBarCount()
end

local eventFrame = CreateFrame("Frame")
local events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "TRAIT_CONFIG_LIST_UPDATED",
    "SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "UPDATE_MACROS",
    "EQUIPMENT_SETS_CHANGED",
    "BAG_UPDATE_DELAYED",
    "CURSOR_CHANGED",
    "PLAYER_REGEN_ENABLED",
}
for _, event in ipairs(events) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME and not state.initialized then
            initializeDatabase()
        elseif selector:IsShown() then
            rebuildCandidates()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if initializeDatabase() and selectedBarCount() > 0 then
            state.transition = true
            scheduleRestore("접속", 1.5)
        end
        return
    end

    if not state.initialized and not initializeDatabase() then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if selectedBarCount() > 0 then
            state.transition = true
            scheduleRestore("화면 전환", 1.25)
        else
            syncIdentity()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if not unit or unit == "player" then
            beginTransition("전문화 변경")
        end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
        beginTransition("특성 변경")
    elseif event == "SPELLS_CHANGED" then
        if state.transition then
            scheduleRestore(state.pendingRestoreReason or "특성 변경", RESTORE_DELAY)
        elseif identityChanged() then
            beginTransition("특성 변경")
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        if state.restoring or state.captureDepth > 0 or GetTime() < state.suppressCaptureUntil then
            return
        end
        if InCombatLockdown() then
            return
        end
        if state.transition then
            scheduleRestore(state.pendingRestoreReason or "특성 변경", RESTORE_DELAY)
        elseif identityChanged() then
            beginTransition("특성 변경")
        elseif hasSelectedSlot(tonumber(slot)) then
            scheduleCapture(CAPTURE_DELAY)
        end
    elseif event == "UPDATE_MACROS" or event == "EQUIPMENT_SETS_CHANGED" then
        if selectedBarCount() > 0 and not state.transition then
            scheduleCapture(CAPTURE_DELAY)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if state.pendingMissing and not state.transition then
            scheduleRestore("사용 가능 동작 재확인", 0.5)
        end
    elseif event == "CURSOR_CHANGED" then
        if state.captureDepth == 0 and not state.restoring and not GetCursorInfo() then
            if state.pendingRestoreReason then
                scheduleRestore(state.pendingRestoreReason, 0.2)
            elseif state.pendingCapture then
                scheduleCapture(0.2)
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if state.pendingRestoreReason then
            scheduleRestore(state.pendingRestoreReason, 0.2)
        elseif state.pendingCapture then
            scheduleCapture(0.2)
        end
    end
end)
