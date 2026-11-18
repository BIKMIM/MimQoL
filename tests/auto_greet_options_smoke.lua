-- Exercise the actual options handlers and SavedVariables defaults without WoW.
local checks, frames, applies = 0, {}, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function noop() end
local Frame = {}
Frame.__index = function(_, key)
    if Frame[key] then return Frame[key] end
    if key:match("^Set") or key:match("^Enable") or key:match("^Register")
        or key:match("^Clear") or key:match("^Update") then return noop end
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent,
        scripts = {}, events = {}, shown = true, text = "" }, Frame)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function Frame:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Frame:GetText() return self.text end
function Frame:SetFocus()
    for _, frame in ipairs(frames) do
        if frame ~= self and frame.kind == "EditBox" then frame:ClearFocus() end
    end
    self.focus = true
end
function Frame:HighlightText() end
function Frame:GetStringHeight() return 28 end
function Frame:GetFrameLevel() return 1 end
function Frame:GetVerticalScrollRange() return 1000 end
function Frame:GetVerticalScroll() return 0 end
function Frame:HasFocus() return self.focus == true end
function Frame:ClearFocus()
    local focused = self.focus
    self.focus = false
    if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function Frame:SetChecked(value) self.checked = value end
function Frame:GetChecked() return self.checked end
function Frame:IsEnabled() return true end
function Frame:IsShown() return self.shown end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:GetFontString() return self:CreateFontString() end
function Frame:GetHighlightTexture() return self:CreateTexture() end
function Frame:GetCheckedTexture() return self:CreateTexture() end
function Frame:GetThumbTexture() return self:CreateTexture() end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
UIParent = CreateFrame("Frame")
StaticPopupDialogs, SlashCmdList, UISpecialFrames = {}, {}, {}
function StaticPopup_Show(name, _, _, callback)
    StaticPopupDialogs[name].OnAccept(nil, callback)
end
function UnitClass() return "사냥꾼", "HUNTER" end
function MimQoLAutoGreet_ApplySettings() applies = applies + 1 end
MimQoLDB = { autoGreet = false, autoGreetPartyMessage = "기존 문구",
    autoGreetRaidMessage = "", autoGreetPartyDelay = 0,
    autoRepair = false, lootDelay = 0.8 }
assert(loadfile("MimQoL.lua"))("MimQoL")
SlashCmdList.MIMQOL("")
check(MimQoLDB.autoGreet == false, "preserve saved disabled setting")
check(MimQoLDB.autoRepair == false and MimQoLDB.lootDelay == 0.8, "preserve unrelated settings")
check(MimQoLDB.autoGreetPartyMessage == "기존 문구", "preserve saved text")
check(MimQoLDB.autoGreetRaidMessage == "", "preserve saved blank text")
check(MimQoLDB.autoGreetPartyDelay == 0, "preserve saved zero delay")
check(MimQoLDB.autoGreetWelcomeMessage == "어서오세요", "initialize missing text")
check(MimQoLDB.autoGreetCompleteDelay == 3, "initialize missing delay")
check(MimQoLDB.autoGreetFullParty == false, "full party announcement is opt-in")
check(MimQoLDB.dungeonPortal == true, "new portal feature defaults on independently of greetings")
local portalApplies, portalPreviews = 0, 0
MimQoLDungeonPortal = {
    ApplySettings = function() portalApplies = portalApplies + 1 end,
    Preview = function() portalPreviews = portalPreviews + 1 end,
    SetMoving = function() return false end,
    IsMoving = function() return false end,
    StopMoving = function() end,
}
SlashCmdList.MIMQOL("portal")
check(MimQoLDB.dungeonPortal == false and portalApplies == 1, "portal slash toggle applies setting")
SlashCmdList.MIMQOL("portaltest")
check(portalPreviews == 1, "portal preview slash dispatches")
local portalPreviewButton
for _, frame in ipairs(frames) do
    if frame.text == "포탈 버튼 미리보기" then portalPreviewButton = frame end
end
check(portalPreviewButton ~= nil, "portal settings preview is available")
portalPreviewButton.scripts.OnClick(portalPreviewButton)
check(portalPreviews == 2, "portal settings preview dispatches")
check(MimQoLDB.autoGreetFullPartyMessage == "풀파입니다. 이동 부탁드립니다."
    and MimQoLDB.autoGreetFullPartyDelay == 3, "initialize full party message and delay")

local fields, count = {}, 0
for _, frame in ipairs(frames) do
    if frame.setting then fields[frame.setting] = frame; count = count + 1 end
end
check(count == 23, "five message/delay pairs, four display fields, four chat sound fields and five Argus tracker fields; no multiline preset editor")
check(MimQoLDB.greetManualMode == false, "existing users keep automatic mode")
check(MimQoLDB.greetEntryPhrases == "안녕하세요", "entry phrase default")
check(MimQoLDB.greetOverlayChars == 8, "short label default")
check(MimQoLDB.greetGeneralPhrases == "안쓰는 아이템 나눔될까요?", "general phrase default")
local function input(setting, text, script)
    local edit = fields[setting]
    edit.focus = true
    edit:SetText(text)
    edit.scripts.OnTextChanged(edit, true)
    edit.scripts[script or "OnEnterPressed"](edit)
    return edit
end
input("autoGreetPartyMessage", "  반갑습니다!  ")
check(MimQoLDB.autoGreetPartyMessage == "반갑습니다!", "Enter saves Korean text")
check(applies == 1, "text changes cancel queued greetings")
input("autoGreetRaidMessage", "공격대 인사", "OnEditFocusLost")
check(MimQoLDB.autoGreetRaidMessage == "공격대 인사", "focus loss saves text")
input("autoGreetWelcomeMessage", "", "OnHide")
check(MimQoLDB.autoGreetWelcomeMessage == "", "hidden input saves blank")
input("autoGreetCompleteMessage", "취소될 문구", "OnEscapePressed")
check(MimQoLDB.autoGreetCompleteMessage == "수고하셨습니다", "Escape cancels text edit")
input("autoGreetPartyDelay", "7.5")
check(MimQoLDB.autoGreetPartyDelay == 7.5, "decimal seconds saved")
input("autoGreetPartyDelay", "oops")
check(MimQoLDB.autoGreetPartyDelay == 7.5, "invalid delay preserves saved setting")
input("autoGreetRaidDelay", "100")
check(MimQoLDB.autoGreetRaidDelay == 60, "delay upper bound")
input("autoGreetWelcomeDelay", "-3")
check(MimQoLDB.autoGreetWelcomeDelay == 0, "delay lower bound")
input("autoGreetCompleteDelay", "4.26")
check(MimQoLDB.autoGreetCompleteDelay == 4.3, "delay precision")
input("autoGreetFullPartyMessage", "  모두 이동해 주세요!  ")
check(MimQoLDB.autoGreetFullPartyMessage == "모두 이동해 주세요!", "full party custom message saves")
input("autoGreetFullPartyDelay", "6.5")
check(MimQoLDB.autoGreetFullPartyDelay == 6.5, "full party decimal delay saves")
input("autoGreetFullPartyDelay", "bad")
check(MimQoLDB.autoGreetFullPartyDelay == 6.5, "full party invalid delay preserves previous value")
local function phraseField(setting, index)
    for _, frame in ipairs(frames) do
        if frame.phraseSetting == setting and frame.phraseIndex == index and frame:IsShown() then return frame end
    end
end
local function phraseInput(setting, index, text, script)
    local edit = assert(phraseField(setting, index), "missing individual phrase field")
    edit:SetFocus()
    edit:SetText(text)
    edit.scripts.OnTextChanged(edit, true)
    if script then edit.scripts[script](edit) end
    return edit
end
local first = phraseInput("greetEntryPhrases", 1, "안녕하세요 반갑습니다")
check(first.previewButton:GetText() == "안녕하세요 반갑…", "preview updates immediately with Korean character shortening")
check(MimQoLDB.greetEntryPhrases == "안녕하세요", "typing preview does not overwrite before committing")
first.scripts.OnEnterPressed(first)
check(MimQoLDB.greetEntryPhrases == "안녕하세요 반갑습니다", "one Enter saves one phrase")
check(phraseField("greetEntryPhrases", 2):HasFocus(), "Enter opens the next individual field")
phraseInput("greetEntryPhrases", 2, "두 번째 인사", "OnEnterPressed")
phraseInput("greetEntryPhrases", 3, "세 번째 인사", "OnEditFocusLost")
check(MimQoLDB.greetEntryPhrases == "안녕하세요 반갑습니다\n두 번째 인사\n세 번째 인사", "three fields map to three saved buttons")
local removed = phraseField("greetEntryPhrases", 2)
removed.removeButton.scripts.OnClick(removed.removeButton)
check(MimQoLDB.greetEntryPhrases == "안녕하세요 반갑습니다\n세 번째 인사", "delete removes one phrase and preserves order")
check(phraseField("greetEntryPhrases", 3) == nil, "deleted surplus field is hidden")
local add
for _, frame in ipairs(frames) do if frame.phraseAddSetting == "greetEntryPhrases" then add = frame end end
add.scripts.OnClick(add)
check(phraseField("greetEntryPhrases", 3):HasFocus(), "add button creates and focuses one new field")
phraseInput("greetEntryPhrases", 3, "새 인사", "OnHide")
phraseInput("greetEntryPhrases", 1, "취소", "OnEscapePressed")
check(MimQoLDB.greetEntryPhrases:find("안녕하세요 반갑습니다", 1, true) == 1, "Escape preserves saved phrase")
phraseInput("greetCompletePhrases", 1, "수고하셨습니다", "OnEnterPressed")
phraseInput("greetCompletePhrases", 2, "즐거웠어요", "OnEditFocusLost")
phraseInput("greetGeneralPhrases", 1, "안쓰는 아이템 나눔될까요?", "OnEnterPressed")
phraseInput("greetGeneralPhrases", 2, "잠시만요", "OnEditFocusLost")
check(MimQoLDB.greetCompletePhrases == "수고하셨습니다\n즐거웠어요"
    and MimQoLDB.greetGeneralPhrases == "안쓰는 아이템 나눔될까요?\n잠시만요", "all three individual lists save independently")
first = phraseField("greetEntryPhrases", 1)
first.previewButton.scripts.OnClick(first.previewButton)
check(first:HasFocus(), "preview button selects its corresponding input without sending chat")
first:ClearFocus()
input("greetOverlayScale", "500")
check(MimQoLDB.greetOverlayScale == 200, "scale upper bound")
input("greetOverlayChars", "1")
check(MimQoLDB.greetOverlayChars == 2, "label lower bound")
input("greetOverlayX", "-220")
input("greetOverlayY", "140")
check(MimQoLDB.greetOverlayX == -220 and MimQoLDB.greetOverlayY == 140, "position inputs")

SlashCmdList.MIMQOL("greet")
check(MimQoLDB.autoGreet == true, "slash toggles greeting on")
local settingsPanel = fields.autoGreetPartyMessage.parent.parent
local resetButton
for _, frame in ipairs(frames) do
    if frame.parent == settingsPanel and frame.text == "이 카테고리 기본값 복원" then
        resetButton = frame
    end
end
check(resetButton ~= nil, "greeting category reset control")
for _, edit in pairs(fields) do edit:ClearFocus() end
resetButton.scripts.OnClick(resetButton)
check(MimQoLDB.autoGreetPartyMessage == "안녕하세요", "category reset restores messages")
check(MimQoLDB.autoGreetPartyDelay == 3 and MimQoLDB.autoGreetRaidDelay == 3,
    "category reset restores delays")
check(fields.autoGreetWelcomeMessage:GetText() == "어서오세요", "category reset refreshes inputs")
check(MimQoLDB.autoGreetFullParty == false and MimQoLDB.autoGreetFullPartyDelay == 3
    and fields.autoGreetFullPartyMessage:GetText() == "풀파입니다. 이동 부탁드립니다.",
    "automatic category reset restores full party options")
check(MimQoLDB.autoRepair == false and MimQoLDB.lootDelay == 0.8, "category reset scoped")
check(MimQoLDB.greetOverlayScale == 200 and MimQoLDB.greetEntryPhrases:find("세 번째 인사", 1, true),
    "automatic category reset preserves manual popup choices")
local manualPanel = fields.greetOverlayScale.parent.parent
check(manualPanel ~= settingsPanel, "manual choices and automatic messages have separate categories")
local manualReset
for _, frame in ipairs(frames) do
    if frame.parent == manualPanel and frame.text == "이 카테고리 기본값 복원" then manualReset = frame end
end
check(manualReset ~= nil, "manual category has reset control")
manualReset.scripts.OnClick(manualReset)
check(MimQoLDB.greetOverlayScale == 100 and MimQoLDB.greetOverlayChars == 8,
    "category reset restores overlay appearance")
check(MimQoLDB.greetEntryPhrases == "안녕하세요" and MimQoLDB.greetCompletePhrases == "수고하셨습니다",
    "category reset restores multiline presets")
check(MimQoLDB.greetGeneralPhrases == "안쓰는 아이템 나눔될까요?", "manual category resets general phrases")
local automaticCheck, manualCheck, fullPartyCheck
for _, frame in ipairs(frames) do
    if frame.kind == "CheckButton" and frame.Text then
        if frame.Text:GetText() == "자동 인사 사용" then automaticCheck = frame end
        if frame.Text:GetText() == "문구 버튼 사용 (수동 전송)" then manualCheck = frame end
        if frame.Text:GetText() == "내 쐐기 파티가 5명이 되었을 때" then fullPartyCheck = frame end
    end
end
check(automaticCheck and manualCheck, "two independent mode controls are present")
check(automaticCheck.parent.parent == settingsPanel, "automatic toggle belongs to automatic settings")
check(manualCheck.parent.parent == manualPanel, "manual toggle belongs to manual settings")
local function clickMode(frame, value)
    frame:SetChecked(value)
    frame.scripts.OnClick(frame)
end
check(fullPartyCheck and fullPartyCheck.parent.parent == settingsPanel,
    "full party toggle belongs to automatic greeting settings")
local beforeFullPartyApply = applies
clickMode(fullPartyCheck, true)
check(MimQoLDB.autoGreetFullParty == true and applies == beforeFullPartyApply + 1,
    "full party toggle applies event registration")
manualReset.scripts.OnClick(manualReset)
check(MimQoLDB.autoGreetFullParty == true, "manual reset preserves full party setting")
clickMode(manualCheck, true)
check(MimQoLDB.autoGreet == true and MimQoLDB.greetManualMode == true, "UI enables combined mode")
clickMode(automaticCheck, false)
check(MimQoLDB.autoGreet == false and MimQoLDB.greetManualMode == true, "UI enables manual-only mode")
clickMode(manualCheck, false)
check(MimQoLDB.autoGreet == false and MimQoLDB.greetManualMode == false, "UI can disable both modes")
clickMode(automaticCheck, true)
check(MimQoLDB.autoGreet == true and MimQoLDB.greetManualMode == false, "UI enables automatic-only mode")
clickMode(automaticCheck, false)
manualReset.scripts.OnClick(manualReset)
check(MimQoLDB.autoGreet == false, "manual category reset preserves automatic toggle")
clickMode(manualCheck, true)
resetButton.scripts.OnClick(resetButton)
check(MimQoLDB.autoGreet == true and MimQoLDB.greetManualMode == true,
    "automatic category reset restores automatic toggle and preserves manual toggle")
local opened, moving, closed = nil, false, false
MimQoLGreetingOverlay = {
    Open = function(kind) opened = kind end,
    IsMoving = function() return moving end,
    SetMoving = function(value, callback)
        moving = value
        if value then
            MimQoLDB.greetOverlayX, MimQoLDB.greetOverlayY = 33, -44
            callback()
        end
        return moving
    end,
    ClosePreview = function() closed = true end,
}
local moveButton, entryPreview
for _, frame in ipairs(frames) do
    if frame.kind == "Button" and frame.text == "위치 이동" then moveButton = frame end
    if frame.kind == "Button" and frame.text == "입장 보기" then entryPreview = frame end
end
entryPreview.scripts.OnClick(entryPreview)
check(opened == "entry", "settings can preview entry button stack")
moveButton.scripts.OnClick(moveButton)
check(moving and moveButton:GetText() == "이동 완료", "explicit movement control unlocks positioning")
check(fields.greetOverlayX:GetText() == "33" and fields.greetOverlayY:GetText() == "-44",
    "drag position callback updates X and Y inputs")
moveButton.scripts.OnClick(moveButton)
check(not moving and moveButton:GetText() == "위치 이동", "movement control relocks positioning")
MimQoLOptionsFrame.scripts.OnHide(MimQoLOptionsFrame)
check(closed, "closing options ends screen preview")
MimQoLGreetingOverlay = nil

local function loadMode(db)
    MimQoLDB = db
    assert(loadfile("MimQoL.lua"))("MimQoL")
    SlashCmdList.MIMQOL("")
end
loadMode({ autoGreet = true, greetManualMode = true,
    greetEntryPhrases = "저장한 입장 문구\n두 번째 저장 문구", greetCompletePhrases = "", greetOverlayScale = 125 })
check(MimQoLDB.autoGreet == false and MimQoLDB.greetManualMode == true,
    "legacy manual-only mode stays manual-only during migration")
check(MimQoLDB.greetEntryPhrases == "저장한 입장 문구\n두 번째 저장 문구" and MimQoLDB.greetCompletePhrases == ""
    and MimQoLDB.greetOverlayScale == 125, "migration preserves saved phrases and appearance")
local loadedCount = 0
for _, frame in ipairs(frames) do
    if frame.phraseSetting == "greetEntryPhrases" and frame:GetText() == "두 번째 저장 문구" then loadedCount = loadedCount + 1 end
end
check(loadedCount == 1, "legacy multiline storage opens as separate single-line fields")
MimQoLDB.autoGreet = true
loadMode(MimQoLDB)
check(MimQoLDB.autoGreet == true and MimQoLDB.greetManualMode == true,
    "combined mode survives reload without repeated legacy migration")
loadMode({ autoGreet = false, greetManualMode = true })
check(MimQoLDB.autoGreet == false and MimQoLDB.greetManualMode == false,
    "legacy disabled master keeps both features disabled")
loadMode({ autoGreet = true, greetManualMode = false })
check(MimQoLDB.autoGreet == true and MimQoLDB.greetManualMode == false,
    "legacy automatic mode stays automatic-only")
loadMode({ autoGreet = false, greetManualMode = true, greetModesIndependent = true })
check(MimQoLDB.autoGreet == false and MimQoLDB.greetManualMode == true,
    "new manual-only mode survives reload")
loadMode({ autoGreetFullParty = false, autoGreetFullPartyMessage = "저장한 문구", autoGreetFullPartyDelay = 0 })
check(MimQoLDB.autoGreetFullParty == false and MimQoLDB.autoGreetFullPartyMessage == "저장한 문구"
    and MimQoLDB.autoGreetFullPartyDelay == 0, "reload preserves full party opt-out, text, and zero delay")
loadMode({ autoGreetFullParty = true, autoGreetFullPartyMessage = "", autoGreetFullPartyDelay = 6.5 })
check(MimQoLDB.autoGreetFullParty == true and MimQoLDB.autoGreetFullPartyMessage == ""
    and MimQoLDB.autoGreetFullPartyDelay == 6.5, "reload preserves full party opt-in, blank text, and decimal delay")
loadMode({ dungeonPortal = false })
check(MimQoLDB.dungeonPortal == false, "reload preserves portal opt-out")
print("auto_greet_options_smoke: " .. checks .. " checks passed")
