local e = dofile("tests/cooldown_reminder_fixture.lua")
local api, checks = e.api, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
assert(loadfile("CooldownReminderConfig.lua"))()
e.reset("")
api.ApplySettings()
SlashCmdList.MIMQOL("cd")
local window = MimQoLCooldownConfig
check(window and window:IsShown(), "slash command opens actual settings")
local function field(setting)
    for _, frame in ipairs(e.frames) do if frame.setting == "cooldownReminder" .. setting then return frame end end
end
local function button(text, parent)
    for _, frame in ipairs(e.frames) do
        if frame.kind == "Button" and frame.text == text and (not parent or frame.parent == parent) then return frame end
    end
    error("missing button " .. text)
end
local function click(text, parent)
    local btn = button(text, parent)
    btn.scripts.OnClick(btn)
    return btn
end
local function input(box, value, event)
    box:SetFocus(); box:SetText(value); box.scripts.OnTextChanged(box, true)
    if event ~= false then box.scripts[event or "OnEnterPressed"](box) end
end
local function toggle(key, value)
    local cb = field(key); cb:SetChecked(value); cb.scripts.OnClick(cb)
end
toggle("", false)
check(MimQoLDB.cooldownReminder == false, "master setting handler disables feature")
toggle("", true)
toggle("CombatOnly", true)
check(MimQoLDB.cooldownReminderCombatOnly, "combat-only handler")
toggle("CombatOnly", false)
input(field("Seconds"), "9.5")
check(MimQoLDB.cooldownReminderSeconds == 9.5, "fractional advance time saved")
input(field("Seconds"), "bad")
check(MimQoLDB.cooldownReminderSeconds == 9.5, "invalid number preserves previous time")
input(field("Seconds"), "999")
check(MimQoLDB.cooldownReminderSeconds == 60, "advance time clamped")
input(field("Duration"), "-1", "OnEditFocusLost")
check(MimQoLDB.cooldownReminderDuration == 1, "duration lower bound and focus-save")
click("준비 완료만")
check(MimQoLDB.cooldownReminderTiming == "ready", "ready-only button")
click("N초 전 우선")
check(MimQoLDB.cooldownReminderTiming == "soon", "advance timing button closure")
local register = button("스킬 ID 등록")
local idBox
for _, frame in ipairs(e.frames) do
    if frame.kind == "EditBox" and frame.parent == register.parent and not frame.setting then idBox = frame end
end
idBox:SetText("101"); register.scripts.OnClick(register)
check(#api.GetEntries() == 1 and api.GetEntries()[1].id == 101, "spell ID UI registration")
idBox:SetText("201"); click("장신구 ID 등록")
check(#api.GetEntries() == 2 and api.GetEntries()[2].kind == "item", "item ID UI registration")
e.cursor = { "spell", 9, "spell", 102 }
local drop = button("+  주문책의 스킬이나 장신구를 여기로 끌어 놓으세요")
drop.scripts.OnReceiveDrag(drop)
check(#api.GetEntries() == 3 and e.cleared == 1, "actual drop handler")
local remove
for _, frame in ipairs(e.frames) do
    if frame.remove and frame.entry and frame.entry.id == 201 then remove = frame.remove end
end
remove.scripts.OnClick(remove)
check(#api.GetEntries() == 2 and api.GetEntries()[2].id == 102, "row deletion removes its own entry")
local settingsButton
for _, frame in ipairs(e.frames) do
    if frame.settings and frame.entry and frame.entry.id == 101 and frame:IsShown() then settingsButton = frame.settings end
end
settingsButton.scripts.OnClick(settingsButton)
local panel = button("개별 설정 초기화").parent
check(panel:IsShown(), "row button opens that alert's own settings")
local function panelBox(option)
    for _, frame in ipairs(e.frames) do
        if frame.option == option and frame.parent == panel then return frame end
    end
end
-- The stack condition now lives in the alert's own panel, with a label.
local function selectRow(id)
    for _, frame in ipairs(e.frames) do
        if frame.settings and frame.entry and frame.entry.id == id and frame:IsShown() then
            frame.scripts.OnClick(frame); return
        end
    end
end
selectRow(102)
check(panel:IsShown() and panel.entry.id == 102, "clicking another row switches the panel")
local countBox = panelBox("count")
input(countBox, "6")
check(MimQoLDB.cooldownReminderEntries == "spell:101\nspell:102:6" and countBox:GetText() == "6", "panel stack box saves a minimum")
input(countBox, "9", "OnEscapePressed")
check(api.GetEntries()[2].count == 6 and countBox:GetText() == "6", "Escape cancels a count edit")
input(countBox, "")
check(MimQoLDB.cooldownReminderEntries == "spell:101\nspell:102", "empty stack box clears the minimum")
selectRow(101)
check(panel:IsShown() and panel.entry.id == 101, "panel follows the selected row")
input(panelBox("x"), "10"); input(panelBox("y"), "-20", "OnEditFocusLost")
input(panelBox("size"), "64"); input(panelBox("seconds"), "8")
check(MimQoLDB.cooldownReminderPositions == "spell:101=10,-20"
    and MimQoLDB.cooldownReminderEntryOptions == "spell:101|seconds=8|size=64", "own position, size and warning time")
click("끔", panel)
check(MimQoLDB.cooldownReminderEntryOptions == "spell:101|seconds=8|size=64|soundType=none", "own sound can be muted")
click("파일", panel)
input(panelBox("soundFile"), "mine.ogg")
check(MimQoLDB.cooldownReminderEntryOptions:find("soundFile=mine.ogg", 1, true), "own sound file")
click("내장", panel)
click("알람", panel) -- The preset button shows the sound now in effect.
click("레벨업")
check(MimQoLDB.cooldownReminderEntryOptions:find("soundKey=567431", 1, true) and e.sounds[#e.sounds][2] == 567431
    and MimQoLDB.cooldownReminderSoundKey ~= 567431, "own preset leaves the shared sound alone")
click("공통", panel)
check(not MimQoLDB.cooldownReminderEntryOptions:find("soundType", 1, true), "shared choice clears the own sound type")
click("개별 설정 초기화")
check(MimQoLDB.cooldownReminderPositions == "" and MimQoLDB.cooldownReminderEntryOptions == "", "panel reset")
api.Remove("spell", 101); window.Refresh()
check(not panel:IsShown(), "panel closes when its entry is removed")
MimQoLDB.cooldownReminderEntries = "spell:101\nspell:102"; api.ApplySettings()

click("모양·소리")
toggle("IconEnabled", false); toggle("TextEnabled", false); toggle("SoundEnabled", false)
check(not MimQoLDB.cooldownReminderIconEnabled and not MimQoLDB.cooldownReminderTextEnabled
    and not MimQoLDB.cooldownReminderSoundEnabled, "three independent output toggles")
toggle("IconEnabled", true); toggle("TextEnabled", true); toggle("SoundEnabled", true)
input(field("Message"), " {이름} 곧! ")
input(field("ReadyMessage"), "완료: {이름}", "OnHide")
check(MimQoLDB.cooldownReminderMessage == "{이름} 곧!" and e.card().readyText == "완료: 스킬101", "localized messages and name substitution")
input(field("Message"), "취소", "OnEscapePressed")
check(MimQoLDB.cooldownReminderMessage == "{이름} 곧!", "Escape cancels edit")
input(field("Message"), "   "); input(field("ReadyMessage"), "")
check(MimQoLDB.cooldownReminderMessage == "" and e.card().normalText == "" and e.card().readyText == "",
    "emptied messages show no text instead of the default")
input(field("Message"), "{이름} 곧!")
input(field("Scale"), "900")
input(field("IconSize"), "1")
input(field("NumberSize"), "1")
check(MimQoLDB.cooldownReminderScale == 200 and MimQoLDB.cooldownReminderIconSize == 24
    and MimQoLDB.cooldownReminderNumberSize == 12, "appearance bounds")
input(field("NumberSize"), "99")
check(MimQoLDB.cooldownReminderNumberSize == 48, "number size upper bound")
input(field("NumberSize"), "28")
check(MimQoLDB.cooldownReminderNumberSize == 28 and e.card().time.fontSize == 28, "number size custom value")
local bar = field("IconSize").slider
bar.scripts.OnValueChanged(bar, 63.6)
check(MimQoLDB.cooldownReminderIconSize == 64 and tonumber(field("IconSize"):GetText()) == 64, "slider saves a stepped value and syncs the box")
bar.syncing = true; bar.scripts.OnValueChanged(bar, 30); bar.syncing = nil
check(MimQoLDB.cooldownReminderIconSize == 64, "programmatic slider sync does not save")
input(field("X"), "-200"); input(field("Y"), "150")
check(MimQoLDB.cooldownReminderX == -200 and MimQoLDB.cooldownReminderY == 150, "position inputs")
click("파일")
local soundBox
for _, frame in ipairs(e.frames) do
    if frame.kind == "EditBox" and frame.parent == field("Message").parent and not frame.setting then soundBox = frame end
end
input(soundBox, "mine.mp3", false)
click("ID") -- Changing mode while the field still has focus must save the old type first.
check(MimQoLDB.cooldownReminderSoundFile == "mine.mp3" and MimQoLDB.cooldownReminderSoundType == "id", "sound mode commits old file before switching")
input(soundBox, "123")
click("▶")
check(MimQoLDB.cooldownReminderSoundID == 123 and e.sounds[#e.sounds][1] == "kit", "sound ID input and preview")
click("파일")
check(soundBox:GetText() == "mine.mp3", "file choice survives other sound modes")
click("내장")
click("알람")
click("퀘스트 완료")
check(MimQoLDB.cooldownReminderSoundKey == 567439 and e.sounds[#e.sounds][2] == 567439, "preset picker saves selected row and previews it")
click("완료 펄스")
toggle("Pulse", false)
check(MimQoLDB.cooldownReminderPulse == false, "pulse toggle handler")
toggle("Pulse", true)
input(field("PulseSize"), "9999"); input(field("PulseOpacity"), "0"); input(field("PulseSpeed"), "1.5")
check(MimQoLDB.cooldownReminderPulseSize == 500 and MimQoLDB.cooldownReminderPulseOpacity == 10
    and MimQoLDB.cooldownReminderPulseSpeed == 1.5, "pulse appearance bounds")
input(field("PulseX"), "-50"); input(field("PulseY"), "120", false)
click("펄스 테스트")
check(MimQoLDB.cooldownReminderPulseX == -50 and MimQoLDB.cooldownReminderPulseY == 120, "pulse test commits pending position")
check(e.pulse() and e.pulse().icon.texture == 101 and e.pulse().width == 500, "pulse test button uses first entry and saved size")
click("모양·소리")
click("위치 이동")
check(api.IsMoving(), "position unlock handler")
click("이동 완료")
check(not api.IsMoving(), "position lock handler")
MimQoLDB.cooldownReminderPositions = "spell:101=10,20"; api.ApplySettings()
click("알림별 위치 초기화")
check(MimQoLDB.cooldownReminderPositions == "", "per-alert position reset button")
click("화면·소리 테스트")
check(e.card():IsShown() and e.card().alpha == 1, "preview handler uses actual reminder")
click("닫기", window)
check(not window:IsShown() and not api.IsMoving(), "closing settings ends preview and movement")
SlashCmdList.MIMQOL("cooldown")
check(MimQoLDB.cooldownReminder == false, "feature slash toggle")
SlashCmdList.MIMQOL("cooldown")

-- Verify the real main settings category reset includes all new scalar fields.
SlashCmdList.MIMQOL("")
local open = button("스킬·장신구 등록 / 모양·소리 설정")
local panel = open.parent.parent
local reset = button("이 카테고리 기본값 복원", panel)
reset.scripts.OnClick(reset)
check(MimQoLDB.cooldownReminderEntries == "" and MimQoLDB.cooldownReminderSeconds == 5, "category reset clears registrations and restores timing")
check(MimQoLDB.cooldownReminderMessage == "{이름} 곧 준비!" and MimQoLDB.cooldownReminderSoundFile == "", "category reset covers detailed fields")
check(MimQoLDB.cooldownReminderPulse == true and MimQoLDB.cooldownReminderPulseSize == 180
    and MimQoLDB.cooldownReminderPulseX == 0, "category reset covers pulse fields")
check(MimQoLDB.autoRepair == false, "category reset preserves unrelated saved setting")
open.scripts.OnClick(open)
check(window:IsShown() and field("Seconds"):GetText() == "5", "main category opens refreshed detailed settings")
print("cooldown_reminder_options_smoke: " .. checks .. " checks passed")
