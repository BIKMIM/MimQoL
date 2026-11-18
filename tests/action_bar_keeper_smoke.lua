local now = 100
local configID = 1
local cursor
local cursorX, cursorY = 520, 220
local pickupActionCalls = 0
local unavailableSpells = {}
local frames = {}
local actions = {
    [25] = { type = "spell", id = 1001, subType = "spell" },
    [26] = { type = "macro", id = 1 },
    [27] = { type = "item", id = 2001 },
}

local Frame = {}
Frame.__index = Frame

function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetPoint() end
function Frame:SetFrameStrata() end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end
function Frame:RegisterForClicks() end
function Frame:SetAllPoints() end
function Frame:SetHeight(height) self.height = height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetColorTexture() end
function Frame:SetText() end
function Frame:SetTextColor() end
function Frame:SetShadowOffset() end
function Frame:ClearAllPoints() end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetEffectiveScale() return self.effectiveScale or 1 end
function Frame:IsVisible() return self.shown ~= false end
function Frame:IsShown() return self.shown == true end
function Frame:GetLeft() return self.left end
function Frame:GetRect() return self.left, self.bottom, self.width, self.height end
function Frame:SetScript(script, callback) self.scripts[script] = callback end
function Frame:CreateTexture()
    return setmetatable({ shown = true, scripts = {} }, Frame)
end
function Frame:CreateFontString()
    return setmetatable({ shown = true, scripts = {} }, Frame)
end
function Frame:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end

UIParent = setmetatable({ shown = true, scripts = {}, left = 0, bottom = 0, width = 1920, height = 1080 }, Frame)
UISpecialFrames = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

function CreateFrame(frameType, name, parent)
    local frame = setmetatable({
        frameType = frameType,
        name = name,
        parent = parent or UIParent,
        shown = true,
        scripts = {},
        left = 0,
        bottom = 0,
        width = 1,
        height = 1,
    }, Frame)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

MultiBarRight = CreateFrame("Frame", "MultiBarRight", UIParent)
MultiBarRight.left, MultiBarRight.bottom = 625, 250
MultiBarRight.width, MultiBarRight.height = 600, 50
MultiBarRight.effectiveScale = 0.8
MultiBarRight.actionButtons = {}
for index = 1, 12 do
    local button = CreateFrame("Button", "MultiBarRightButton" .. index, MultiBarRight)
    button.left, button.bottom = 625 + ((index - 1) * 50), 250
    button.width, button.height = 47.5, 47.5
    button.effectiveScale = 0.8
    button.action = 24 + index
    MultiBarRight.actionButtons[index] = button
end

local ellesmereMainBar = CreateFrame("Frame", "EABBar_MainBar", UIParent)
ellesmereMainBar.left, ellesmereMainBar.bottom = 100, 100
ellesmereMainBar.width, ellesmereMainBar.height = 480, 40
local ellesmereMainButtons = {}
for index = 1, 12 do
    local button = CreateFrame("Button", nil, ellesmereMainBar)
    button.left, button.bottom = 100 + ((index - 1) * 40), 100
    button.width, button.height = 38, 38
    button.action = index
    ellesmereMainButtons[index] = button
end
EllesmereUI = {
    _ModuleNS = {
        EllesmereUIActionBars = {
            barButtons = { MainBar = ellesmereMainButtons },
        },
    },
}

function UnitGUID() return "Player-test" end
function UnitFullName() return "Tester", "Realm" end
function UnitClass() return "흑마법사", "WARLOCK", 9 end
function GetRealmName() return "Realm" end
function InCombatLockdown() return false end
function GetTime() return now end
function GetServerTime() return 123456 end
function GetCursorPosition() return cursorX, cursorY end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 267 end
function GetActionText(slot) return actions[slot] and ("Action" .. slot) end
function GetActionInfo(slot)
    local action = actions[slot]
    if not action then return nil end
    return action.type, action.id, action.subType
end
function GetCursorInfo()
    if not cursor then return nil end
    return cursor.type, cursor.id, cursor.subType
end
function ClearCursor() cursor = nil end
function PickupAction(slot)
    pickupActionCalls = pickupActionCalls + 1
    local oldCursor = cursor
    cursor = actions[slot]
    actions[slot] = oldCursor
end
function PlaceAction(slot)
    local oldAction = actions[slot]
    actions[slot] = cursor
    cursor = oldAction
end
function GetNumMacros() return 1, 0 end
function GetMacroBody(index) return index == 1 and "/cast Test Spell" or nil end
function GetMacroInfo(index) return index == 1 and "Test Macro" or nil end
function GetMacroIndexByName(name) return name == "Test Macro" and 1 or 0 end
function PickupMacro(index) cursor = { type = "macro", id = index } end
function PickupItem(itemID) cursor = { type = "item", id = itemID } end

MAX_ACCOUNT_MACROS = 120
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
C_Timer = { After = function(_, callback) callback() end }
C_ActionBar = { GetActionText = GetActionText }
C_Spell = {
    PickupSpell = function(spellID)
        if not unavailableSpells[spellID] then
            cursor = { type = "spell", id = spellID, subType = "spell" }
        end
    end,
}
C_ClassTalents = { GetActiveConfigID = function() return configID end }
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then return { itemID = 2001 } end
    end,
    PickupContainerItem = function() cursor = { type = "item", id = 2001 } end,
}

local chunk = assert(loadfile("ActionBarKeeper.lua"))
chunk("MimQoL")

assert(MimQoLActionBarKeeper_GetCount() == 0, "initial shared bar count")
assert(MimQoLDB.actionBarKeeper.classes.WARLOCK.migratedFromCharacterV1,
    "legacy character data migration should be marked complete")
local selectionFinished = false
assert(MimQoLActionBarKeeper_StartSelection(function()
    selectionFinished = true
end), "UI selection should start")
MimQoLActionBarSelector.scripts.OnUpdate(MimQoLActionBarSelector, 0.1)

local overlay
for _, frame in ipairs(frames) do
    if frame.scripts.OnClick then
        overlay = frame
        break
    end
end
assert(overlay, "selector overlay frame")
assert(overlay:IsShown(), "hover selector should highlight the action bar")
overlay.scripts.OnClick(overlay, "LeftButton")
assert(MimQoLActionBarKeeper_GetCount() == 1, "selected shared bar count")
assert(pickupActionCalls == 0, "capturing a macro must not pick up its action slot")

cursorX, cursorY = 120, 120
MimQoLActionBarSelector.scripts.OnUpdate(MimQoLActionBarSelector, 0.1)
assert(overlay:IsShown(), "EllesmereUI main bar should be highlighted")
overlay.scripts.OnClick(overlay, "LeftButton")
assert(MimQoLActionBarKeeper_GetCount() == 2, "EllesmereUI main bar should be selectable")
local selectedStatus = MimQoLActionBarKeeper_GetUIStatus()
local foundMainBar = false
for _, bar in ipairs(selectedStatus.bars) do
    if bar.label == "행동 단축바 1" then
        foundMainBar = true
        break
    end
end
assert(foundMainBar, "EllesmereUI main bar should be labeled as action bar 1")
MimQoLActionBarSelector:Hide()
assert(selectionFinished, "closing selection should return to the settings UI")

local eventFrame
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent then
        eventFrame = frame
        break
    end
end
assert(eventFrame, "event frame")

now = 102
actions[25] = { type = "spell", id = 1002, subType = "spell" }
eventFrame.scripts.OnEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED", 25)
assert(pickupActionCalls == 0, "background capture must remain read-only")

now = 104
configID = 2
actions[25] = { type = "spell", id = 9999, subType = "spell" }
actions[26] = nil
actions[27] = nil
eventFrame.scripts.OnEvent(eventFrame, "TRAIT_CONFIG_UPDATED")

assert(actions[25] and actions[25].id == 1002, "learned spell should be restored")
assert(actions[26] and actions[26].type == "macro", "macro should be restored")
assert(actions[27] and actions[27].type == "item", "item should be restored")
assert(MimQoLDB.actionBarKeeper.classes.WARLOCK.backup, "restore backup should exist")
local uiStatus = MimQoLActionBarKeeper_GetUIStatus()
assert(uiStatus.className == "흑마법사" and uiStatus.count == 2, "class-scoped UI status")

MimQoLActionBarKeeper_Undo()
assert(actions[25] and actions[25].id == 9999, "undo should restore the pre-restore spell")
assert(actions[26] == nil and actions[27] == nil, "undo should restore empty slots")

now = 106
configID = 3
unavailableSpells[9999] = true
actions[25] = { type = "spell", id = 8888, subType = "spell" }
eventFrame.scripts.OnEvent(eventFrame, "TRAIT_CONFIG_UPDATED")
assert(actions[25] == nil, "an unavailable saved spell should leave the target slot empty")

print("ActionBarKeeper smoke test: OK")
