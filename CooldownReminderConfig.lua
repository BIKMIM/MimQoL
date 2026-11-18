-- MimDice-style controls, kept independent so the reminder can be moved later.
local Reminder = _G.MimQoLCooldownReminder
local window
local PREFIX = "cooldownReminder"
local TEXTURE = "Interface\\Buttons\\WHITE8X8"
local GREY = { 0.72, 0.72, 0.72 }

local function get(key) return MimQoLDB[PREFIX .. key] end
local function put(key, value)
    MimQoLDB[PREFIX .. key] = value
    Reminder.ApplySettings()
end

local function skin(frame, selected)
    frame:SetBackdrop({ bgFile = TEXTURE, edgeFile = TEXTURE, edgeSize = 1 })
    frame:SetBackdropColor(selected and 0.18 or 0.055, selected and 0.14 or 0.055, 0.06, 0.96)
    frame:SetBackdropBorderColor(selected and 1 or 0.3, selected and 0.82 or 0.3, selected and 0 or 0.3, 1)
end

local function label(parent, text, x, y, width, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width or 470)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function hint(parent, text, x, y, width)
    local fs = label(parent, text, x, y, width)
    fs:SetTextColor(GREY[1], GREY[2], GREY[3])
    return fs
end

local function button(parent, text, x, y, width, callback)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetSize(width, 26)
    skin(btn)
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetText(text)
    btn:SetScript("OnClick", callback)
    btn:SetScript("OnEnter", function(self) skin(self, true) end)
    btn:SetScript("OnLeave", function(self) skin(self, self.selected) end)
    return btn
end

local function edit(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(width, 25)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(7, 7, 0, 0)
    box:SetMaxBytes(255)
    skin(box)
    return box
end

local function slider(parent, x, y, width, low, high, step)
    local bar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    bar:SetPoint("TOPLEFT", x, y)
    bar:SetSize(width, 12)
    bar:SetOrientation("HORIZONTAL")
    bar:SetMinMaxValues(low, high)
    bar:SetValueStep(step)
    bar:SetObeyStepOnDrag(true)
    bar:SetBackdrop({ bgFile = TEXTURE, edgeFile = TEXTURE, edgeSize = 1 })
    bar:SetBackdropColor(0.1, 0.1, 0.1, 1)
    bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    bar:SetThumbTexture(TEXTURE)
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetSize(10, 18)
        thumb:SetVertexColor(1, 0.82, 0, 1)
    end
    return bar
end

local function create()
    if window then return end
    window = CreateFrame("Frame", "MimQoLCooldownConfig", UIParent, "BackdropTemplate")
    window:SetSize(540, 680)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    skin(window)
    local title = label(window, "쿨타임 알림", 16, -14, 200, "GameFontNormalLarge")
    title:SetTextColor(1, 0.82, 0)
    local specText = label(window, "", 190, -17, 300, "GameFontHighlight")
    specText:SetJustifyH("RIGHT")
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", -42, 0)
    drag:SetHeight(40)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() window:StartMoving() end)
    drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    button(window, "×", 500, -10, 26, function() window:Hide() end)
    local status = label(window, "", 16, -604, 508)
    status:SetTextColor(1, 0.82, 0)
    local fields, checks, listRows, tabs = {}, {}, {}, {}
    local activeTab = 1
    local pages = { CreateFrame("Frame", nil, window), CreateFrame("Frame", nil, window),
        CreateFrame("Frame", nil, window) }
    for _, page in ipairs(pages) do
        page:SetPoint("TOPLEFT", 0, -80)
        page:SetPoint("BOTTOMRIGHT", 0, 80)
    end
    local function refreshTabs()
        for index, page in ipairs(pages) do
            page:SetShown(index == activeTab)
            tabs[index].selected = index == activeTab
            skin(tabs[index], index == activeTab)
        end
    end
    for index, name in ipairs({ "알림 목록", "모양·소리", "완료 펄스" }) do
        tabs[index] = button(window, name, 16 + (index - 1) * 172, -44, 164, function()
            activeTab = index
            refreshTabs()
        end)
    end

    -- A number setting. With a step it also gets a slider; the box stays for exact values.
    local function settingBox(parent, key, caption, x, y, width, low, high, step)
        label(parent, caption, x, y, width)
        local box = edit(parent, step and (x + width - 56) or x, y - 18, step and 56 or width)
        box.setting = PREFIX .. key
        local bar
        if step then
            bar = slider(parent, x, y - 25, width - 66, low, high, step)
        end
        local function refresh()
            box:SetText(tostring(get(key) or ""))
            box:SetCursorPosition(0)
            local value = tonumber(get(key))
            if bar and value then
                bar.syncing = true
                bar:SetValue(value)
                bar.syncing = nil
            end
        end
        local function save(value)
            value = math.floor(math.max(low, math.min(high, value)) * 10 + 0.5) / 10
            put(key, value)
            refresh()
        end
        local function commit()
            if not box.dirty then return end
            box.dirty = false
            local value = box:GetText()
            if low then
                value = tonumber(value)
                if not value or value ~= value then refresh(); return end
                save(value)
            else
                value = value:gsub("[%c]", " "):match("^%s*(.-)%s*$")
                put(key, value)
                refresh()
            end
        end
        if bar then
            bar:SetScript("OnValueChanged", function(self, value)
                if self.syncing or type(value) ~= "number" then return end
                value = math.floor(value / step + 0.5) * step
                if value == tonumber(get(key)) then return end
                box.dirty = false
                save(value)
            end)
        end
        box:SetScript("OnTextChanged", function(_, user) if user then box.dirty = true end end)
        box:SetScript("OnEnterPressed", function(self) commit(); self:ClearFocus() end)
        box:SetScript("OnEditFocusLost", commit)
        box:SetScript("OnEscapePressed", function(self) self.dirty = false; refresh(); self:ClearFocus() end)
        box:SetScript("OnHide", function(self) commit(); self:ClearFocus() end)
        box.RefreshValue = refresh
        box.slider = bar
        fields[#fields + 1] = box
        return box
    end

    local function checkbox(parent, key, caption, x, y)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb:SetSize(24, 24)
        cb.setting = PREFIX .. key
        label(parent, caption, x + 27, y - 6, 160)
        cb:SetScript("OnClick", function(self) put(key, self:GetChecked() and true or false) end)
        checks[key] = cb
    end

    local function clearFocus()
        for _, box in ipairs(fields) do box:ClearFocus() end
    end

    ----------------------------------------------------------------- 알림 목록
    local page = pages[1]
    checkbox(page, "", "알림 사용", 16, -2)
    checkbox(page, "CombatOnly", "전투 중에만", 200, -2)
    local scopeHint = hint(page, "", 16, -32, 508)
    local function addCursor()
        local _, message = Reminder.AddFromCursor()
        status:SetText(message)
        window.Refresh()
    end
    local drop = button(page, "+  주문책의 스킬이나 장신구를 여기로 끌어 놓으세요", 16, -52, 508, addCursor)
    drop:SetHeight(40)
    drop:RegisterForDrag("LeftButton")
    drop:SetScript("OnReceiveDrag", addCursor)
    local idBox = edit(page, 16, -100, 236)
    idBox:SetNumeric(true)
    idBox:SetMaxBytes(10)
    local idHint = hint(idBox, "또는 ID 직접 입력", 8, -7, 200)
    idBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    idBox:HookScript("OnTextChanged", function(self) idHint:SetShown((self:GetText() or "") == "") end)
    local function addID(kind)
        local ok, message = Reminder.Add(kind, idBox:GetText())
        if ok then idBox:SetText(""); idBox:ClearFocus() end
        status:SetText(message)
        window.Refresh()
    end
    button(page, "스킬 ID 등록", 260, -100, 128, function() addID("spell") end)
    button(page, "장신구 ID 등록", 396, -100, 128, function() addID("item") end)
    idBox:SetScript("OnEnterPressed", function() addID("spell") end)
    local count = label(page, "등록 목록", 16, -138, 200, "GameFontNormal")
    hint(page, "항목을 누르면 위치·크기·소리·스택 조건을 따로 정합니다.", 200, -140, 324)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -158)
    scroll:SetSize(484, 252)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(482, 1)
    scroll:SetScrollChild(list)
    local empty = hint(list, "아직 등록한 스킬·장신구가 없습니다.\n위 칸에 주문책의 스킬이나 장신구를 끌어 놓으세요.", 8, -12, 460)
    local modeButtons = {}
    label(page, "알림 시점", 16, -428, 100)
    for index, spec in ipairs({ { "soon", "N초 전 우선" }, { "ready", "준비 완료만" } }) do
        local mode = spec[1]
        modeButtons[index] = button(page, spec[2], 110 + (index - 1) * 210, -422, 204, function()
            put("Timing", mode)
            window.Refresh()
        end)
        modeButtons[index].mode = mode
    end
    settingBox(page, "Seconds", "미리 알릴 시간 (초)", 16, -460, 246, 1, 60, 0.5)
    settingBox(page, "Duration", "완료 표시 시간 (초)", 278, -460, 246, 1, 15, 0.5)

    ----------------------------------------------------------------- 모양·소리
    page = pages[2]
    checkbox(page, "IconEnabled", "아이콘 표시", 16, -2)
    checkbox(page, "TextEnabled", "문구 표시", 190, -2)
    checkbox(page, "SoundEnabled", "소리 재생", 364, -2)
    label(page, "공통 소리", 16, -40, 80)
    local soundTypes, soundTypeButtons = { "preset", "custom", "id" }, {}
    local soundLabels = { "내장", "파일", "ID" }
    local soundBox = edit(page, 270, -34, 204)
    soundBox:SetMaxBytes(255)
    local soundEditType
    local function commitSound()
        if not soundBox.dirty then return end
        soundBox.dirty = false
        local value = soundBox:GetText():match("^%s*(.-)%s*$")
        if soundEditType == "id" then
            local id = tonumber(value)
            if id and id > 0 and id < 2147483648 and id == math.floor(id) then put("SoundID", id) end
        elseif soundEditType == "custom" then put("SoundFile", value) end
    end
    soundBox:SetScript("OnTextChanged", function(_, user) if user then soundBox.dirty = true end end)
    soundBox:SetScript("OnEnterPressed", function(self) commitSound(); self:ClearFocus() end)
    soundBox:SetScript("OnEditFocusLost", commitSound)
    soundBox:SetScript("OnEscapePressed", function(self)
        self.dirty = false; self:ClearFocus(); window.Refresh()
    end)
    for index, mode in ipairs(soundTypes) do
        soundTypeButtons[index] = button(page, soundLabels[index], 86 + (index - 1) * 60, -34, 56, function()
            commitSound()
            soundBox:ClearFocus()
            put("SoundType", mode)
            window.Refresh()
        end)
    end
    -- One preset list serves the shared sound and every alert's own sound.
    local picker, pickerOwner, pickerSelect
    local function togglePicker(owner, onSelect)
        if not picker then
            picker = CreateFrame("Frame", nil, window, "BackdropTemplate")
            picker:SetSize(360, 304)
            picker:SetPoint("TOPRIGHT", window, "TOPLEFT", -6, -40)
            picker:SetClampedToScreen(true)
            picker:SetFrameStrata("DIALOG")
            picker:EnableMouse(true)
            skin(picker)
            label(picker, "내장 사운드 선택 · 누르면 바로 들려줍니다", 14, -12, 300, "GameFontNormal")
            button(picker, "×", 320, -8, 26, function() picker:Hide() end)
            local soundScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
            soundScroll:SetPoint("TOPLEFT", 12, -40)
            soundScroll:SetSize(314, 250)
            local sounds = CreateFrame("Frame", nil, soundScroll)
            sounds:SetSize(310, #Reminder.Presets * 30)
            soundScroll:SetScrollChild(sounds)
            for index, preset in ipairs(Reminder.Presets) do
                button(sounds, preset[1], 0, -(index - 1) * 30, 310, function()
                    picker:Hide()
                    pickerSelect(preset[2])
                end)
            end
            picker:Hide()
        end
        if picker:IsShown() and pickerOwner == owner then picker:Hide(); return end
        pickerOwner, pickerSelect = owner, onSelect
        picker:Show()
    end
    local presetButton = button(page, "내장 소리 선택", 270, -34, 204, function()
        commitSound()
        togglePicker("shared", function(id)
            put("SoundKey", id)
            window.Refresh()
            local _, message = Reminder.TestSound()
            status:SetText(message)
        end)
    end)
    button(page, "▶", 484, -34, 40, function()
        commitSound()
        local _, message = Reminder.TestSound()
        status:SetText(message)
    end)
    local soundHint = hint(page, "", 16, -66, 508)
    settingBox(page, "Message", "임박 문구 · {이름}은 스킬·장신구 이름으로 바뀝니다. 비우면 문구 없음", 16, -100, 508)
    settingBox(page, "ReadyMessage", "완료 문구", 16, -152, 508)
    settingBox(page, "IconSize", "아이콘 크기", 16, -210, 246, 24, 96, 1)
    settingBox(page, "NumberSize", "아이콘 안 숫자 크기", 278, -210, 246, 12, 48, 1)
    settingBox(page, "FontSize", "문구 글자 크기", 16, -262, 246, 12, 36, 1)
    settingBox(page, "Scale", "전체 배율 (%)", 278, -262, 246, 50, 200, 5)
    local color = button(page, "문구 색상", 16, -330, 160, function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local r, g, b = get("ColorR"), get("ColorG"), get("ColorB")
        local function set(r2, g2, b2)
            MimQoLDB.cooldownReminderColorR, MimQoLDB.cooldownReminderColorG,
                MimQoLDB.cooldownReminderColorB = r2, g2, b2
            Reminder.ApplySettings()
            window.Refresh()
        end
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() set(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() set(r, g, b) end,
        })
    end)
    settingBox(page, "X", "묶음 위치 X", 192, -312, 158, -10000, 10000)
    settingBox(page, "Y", "묶음 위치 Y", 366, -312, 158, -10000, 10000)
    hint(page, "위치는 아래 [위치 이동]을 눌러 화면에서 직접 끄는 편이 쉽습니다. 노란 테두리 안 빈 곳을 끌면 묶음 전체가, 아이콘 하나를 끌면 그 알림만 움직입니다.", 16, -372, 508)
    button(page, "알림별 위치 초기화", 16, -416, 200, function()
        Reminder.ResetPositions()
        status:SetText("알림별 위치를 기본 배치(3열)로 되돌렸습니다.")
    end)

    ----------------------------------------------------------------- 완료 펄스
    page = pages[3]
    checkbox(page, "Pulse", "완료 펄스 사용", 16, -2)
    hint(page, "쿨타임이 돌아오면 아이콘이 화면에 크게 나타났다 사라집니다. 아이콘·문구 표시와 따로 켤 수 있고, 소리는 '모양·소리'의 설정을 함께 씁니다.", 16, -34, 508)
    settingBox(page, "PulseSize", "아이콘 크기", 16, -80, 246, 40, 500, 10)
    settingBox(page, "PulseOpacity", "불투명도 (%)", 278, -80, 246, 10, 100, 5)
    settingBox(page, "PulseSpeed", "속도 (배)", 16, -132, 246, 0.3, 2.5, 0.1)
    settingBox(page, "PulseX", "위치 X (화면 중앙 기준)", 16, -190, 246, -10000, 10000)
    settingBox(page, "PulseY", "위치 Y (화면 중앙 기준)", 278, -190, 246, -10000, 10000)
    button(page, "펄스 테스트", 16, -248, 508, function()
        clearFocus()
        Reminder.TestPulse()
    end)
    hint(page, "테스트는 첫 번째로 등록한 스킬·장신구의 아이콘으로 보여 줍니다. 펄스는 클릭을 가로채지 않습니다.", 16, -284, 508)

    ----------------------------------------------------------- 알림별 설정 창
    -- Each alert's own settings. An empty field follows the shared setting.
    local panel
    local soundModes = { { "shared", "공통" }, { "preset", "내장" }, { "custom", "파일" },
        { "id", "ID" }, { "none", "끔" } }
    local function presetName(id)
        for _, info in ipairs(Reminder.Presets) do if info[2] == id then return info[1] end end
        return "내장 소리 선택"
    end
    local function createPanel()
        panel = CreateFrame("Frame", nil, window, "BackdropTemplate")
        panel:SetSize(320, 470)
        panel:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, 0)
        panel:SetClampedToScreen(true)
        panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true)
        skin(panel)
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(28, 28)
        panel.icon:SetPoint("TOPLEFT", 14, -10)
        panel.title = label(panel, "", 50, -12, 226, "GameFontNormal")
        panel.title:SetTextColor(1, 0.82, 0)
        panel.status = hint(panel, "", 50, -28, 226)
        button(panel, "×", 284, -8, 26, function() panel:Hide() end)
        panel.hint = hint(panel, "", 14, -50, 292)
        panel.boxes = {}
        local function field(option, caption, x, y, width)
            if caption then label(panel, caption, x, y, width) end
            local box = edit(panel, x, y - (caption and 18 or 0), width)
            box.option = option
            local function commit()
                if not box.dirty then return end
                box.dirty = false
                if box.option == "count" then
                    Reminder.SetCount(panel.entry.kind, panel.entry.id, box:GetText())
                else
                    Reminder.SetEntryOption(panel.entry.kind, panel.entry.id, box.option, box:GetText())
                end
                window.Refresh()
            end
            box:SetScript("OnTextChanged", function(_, user) if user then box.dirty = true end end)
            box:SetScript("OnEnterPressed", function(self) commit(); self:ClearFocus() end)
            box:SetScript("OnEditFocusLost", commit)
            box:SetScript("OnEscapePressed", function(self) self.dirty = false; self:ClearFocus(); panel.Refresh() end)
            panel.boxes[#panel.boxes + 1] = box
            return box
        end
        local function commitAll()
            for _, box in ipairs(panel.boxes) do box:ClearFocus() end
        end
        field("x", "위치 X", 14, -84, 138)
        field("y", "위치 Y", 168, -84, 138)
        field("size", "아이콘 크기 (24~200)", 14, -138, 138)
        field("seconds", "미리 알릴 시간 (1~60초)", 168, -138, 138)
        panel.countLabel = label(panel, "스택 조건 (1~99)", 14, -192, 292)
        panel.count = field("count", nil, 14, -210, 80)
        panel.count:SetNumeric(true)
        panel.count:SetMaxLetters(2)
        panel.countHint = hint(panel, "버튼 숫자가 이 값 이상이고 쿨이 돌아왔을 때만 아이콘을 띄웁니다. 비우면 일반 쿨타임 알림입니다.", 102, -208, 204)
        label(panel, "소리", 14, -250, 100)
        panel.modeButtons = {}
        for index, spec in ipairs(soundModes) do
            local btn = button(panel, spec[2], 14 + (index - 1) * 59, -268, 55, function()
                commitAll()
                Reminder.SetEntryOption(panel.entry.kind, panel.entry.id, "soundType",
                    spec[1] == "shared" and "" or spec[1])
                window.Refresh()
            end)
            btn.mode = spec[1]
            panel.modeButtons[index] = btn
        end
        panel.soundBox = field("soundFile", nil, 14, -302, 242)
        panel.preset = button(panel, "내장 소리 선택", 14, -302, 242, function()
            commitAll()
            local entry = panel.entry
            togglePicker(entry, function(id)
                Reminder.SetEntryOption(entry.kind, entry.id, "soundKey", id)
                window.Refresh()
                local _, message = Reminder.TestSound(entry)
                status:SetText(message)
            end)
        end)
        button(panel, "▶", 266, -302, 40, function()
            commitAll()
            local _, message = Reminder.TestSound(panel.entry)
            status:SetText(message)
        end)
        panel.soundHint = hint(panel, "", 14, -334, 292)
        hint(panel, "위치는 알림 묶음의 중심 기준입니다. 여러 알림에 같은 X·Y를 넣으면 한자리에 겹칩니다. X나 Y를 비우면 기본 배치로 돌아갑니다.",
            14, -360, 292)
        button(panel, "개별 설정 초기화", 14, -424, 140, function()
            Reminder.ResetEntry(panel.entry.kind, panel.entry.id)
            window.Refresh()
            status:SetText("이 알림의 개별 설정을 공통 설정으로 되돌렸습니다.")
        end)
        button(panel, "목록에서 삭제", 166, -424, 140, function()
            Reminder.Remove(panel.entry.kind, panel.entry.id)
            status:SetText("삭제했습니다.")
            window.Refresh()
        end)
        function panel.Refresh()
            local entry = panel.entry
            local own = Reminder.GetEntryOptions(entry.kind, entry.id)
            local name, icon = Reminder.Describe(entry)
            panel.title:SetText(name)
            panel.icon:SetTexture(icon)
            panel.status:SetText(Reminder.Status(entry))
            panel.hint:SetText(string.format("빈 칸은 공통 설정을 따릅니다. (공통: 크기 %s, %s초)",
                tostring(get("IconSize")), tostring(get("Seconds"))))
            local mode = own.soundType or "shared"
            panel.soundBox.option = mode == "id" and "soundID" or "soundFile"
            own.count = entry.count
            for _, box in ipairs(panel.boxes) do
                if not box:HasFocus() then
                    box.dirty = false
                    box:SetText(own[box.option] ~= nil and tostring(own[box.option]) or "")
                end
            end
            local spell = entry.kind == "spell"
            panel.countLabel:SetShown(spell)
            panel.count:SetShown(spell)
            panel.countHint:SetShown(spell)
            for _, btn in ipairs(panel.modeButtons) do
                btn.selected = btn.mode == mode
                skin(btn, btn.selected)
            end
            panel.soundBox:SetShown(mode == "custom" or mode == "id")
            panel.preset:SetShown(mode == "preset")
            panel.preset:SetText(presetName(own.soundKey or get("SoundKey")))
            if mode == "shared" then
                panel.soundHint:SetText("'모양·소리' 탭의 공통 소리를 씁니다.")
            elseif mode == "none" then
                panel.soundHint:SetText("이 알림만 소리를 내지 않습니다.")
            elseif mode == "custom" then
                panel.soundHint:SetText("파일명 예: MySound.mp3")
            elseif mode == "id" then
                panel.soundHint:SetText("소리 ID 숫자를 입력합니다.")
            else
                panel.soundHint:SetText("내장 소리를 고르면 바로 들려줍니다.")
            end
        end
        panel:SetScript("OnHide", function() window.Refresh() end)
        panel:Hide()
    end
    local function openPanel(entry)
        if not panel then createPanel() end
        if panel:IsShown() and panel.entry and panel.entry.kind == entry.kind and panel.entry.id == entry.id then
            panel:Hide()
            return
        end
        panel.entry = entry
        panel:Show()
        panel.Refresh()
        window.Refresh()
    end

    local function createRow(index)
        local row = CreateFrame("Button", nil, list, "BackdropTemplate")
        row:SetSize(482, 40)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 42)
        skin(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.nameText = label(row, "", 44, -5, 330, "GameFontHighlight")
        row.statusText = hint(row, "", 44, -22, 330)
        row.settings = button(row, "설정", 384, -7, 56, function() openPanel(row.entry) end)
        row.remove = button(row, "×", 446, -7, 28, function()
            Reminder.Remove(row.entry.kind, row.entry.id)
            status:SetText("삭제했습니다.")
            window.Refresh()
        end)
        row:SetScript("OnClick", function() openPanel(row.entry) end)
        row:SetScript("OnEnter", function(self) skin(self, true) end)
        row:SetScript("OnLeave", function(self) skin(self, self.selected) end)
        listRows[index] = row
        return row
    end

    function window.Refresh()
        for key, cb in pairs(checks) do cb:SetChecked(get(key) == true) end
        for _, box in ipairs(fields) do if not box:HasFocus() then box.RefreshValue() end end
        local listEntries = Reminder.GetEntries()
        local spec = Reminder.GetSpecName and Reminder.GetSpecName()
        specText:SetText(spec and ("현재 전문화: |cffffd100" .. spec .. "|r") or "전문화 확인 중…")
        scopeHint:SetText((spec and ("'" .. spec .. "' 전용 목록입니다. ") or "")
            .. "전문화를 바꾸면 그 전문화의 목록이 따로 보입니다. 같은 직업 캐릭터끼리는 공유합니다.")
        count:SetText("등록 목록 (" .. #listEntries .. "/12)")
        empty:SetShown(#listEntries == 0)
        for _, row in ipairs(listRows) do row:Hide() end
        local current
        for index, entry in ipairs(listEntries) do
            local row = listRows[index] or createRow(index)
            row.entry = entry
            local name, icon = Reminder.Describe(entry)
            local text, active = Reminder.Status(entry)
            row.nameText:SetText(name .. "  |cff888888" .. (entry.kind == "spell" and "스킬" or "장신구")
                .. " " .. entry.id .. "|r")
            row.statusText:SetText(text)
            if active then
                row.statusText:SetTextColor(GREY[1], GREY[2], GREY[3])
            else
                row.statusText:SetTextColor(1, 0.45, 0.35)
            end
            row.icon:SetTexture(icon)
            if row.icon.SetDesaturated then row.icon:SetDesaturated(not active) end
            row.selected = panel and panel:IsShown() and panel.entry
                and panel.entry.kind == entry.kind and panel.entry.id == entry.id or false
            if row.selected then current = entry end
            skin(row, row.selected)
            row:Show()
        end
        list:SetHeight(math.max(42, #listEntries * 42))
        if panel and panel:IsShown() then
            -- Entries are rebuilt on save, so follow the fresh copy (its count may have changed).
            if current then panel.entry = current; panel.Refresh() else panel:Hide() end
        end
        for _, btn in ipairs(modeButtons) do
            btn.selected = get("Timing") == btn.mode
            skin(btn, btn.selected)
        end
        for index, btn in ipairs(soundTypeButtons) do
            btn.selected = get("SoundType") == soundTypes[index]
            skin(btn, btn.selected)
        end
        if not soundBox:HasFocus() then
            soundEditType = get("SoundType")
            soundBox.dirty = false
            soundBox:SetText(tostring(get(soundEditType == "id" and "SoundID" or "SoundFile") or ""))
        end
        local preset = get("SoundType") == "preset"
        soundBox:SetShown(not preset)
        presetButton:SetShown(preset)
        for _, info in ipairs(Reminder.Presets) do
            if info[2] == get("SoundKey") then presetButton:SetText(info[1]); break end
        end
        if get("SoundType") == "custom" then
            soundHint:SetText("예: MySound.mp3 · _retail_\\sound 또는 sounds 폴더. MimDice 동봉 파일명도 사용할 수 있습니다.")
        elseif get("SoundType") == "id" then
            soundHint:SetText("500000 초과는 파일 ID, 나머지는 사운드 키트 ID로 재생합니다.")
        else soundHint:SetText("내장 소리를 고르거나 ▶ 버튼으로 미리 듣습니다. 와우의 대화 소리 채널을 사용합니다.") end
        color:SetBackdropBorderColor(get("ColorR"), get("ColorG"), get("ColorB"), 1)
        window.lock:SetText(Reminder.IsMoving() and "이동 완료" or "위치 이동")
        window.lock.selected = Reminder.IsMoving()
        skin(window.lock, window.lock.selected)
        refreshTabs()
    end

    -- Always-visible actions: try it out, move it, close.
    button(window, "화면·소리 테스트", 16, -638, 180, function()
        commitSound()
        clearFocus()
        if Reminder.Preview() then
            status:SetText("5초 동안 등록한 알림을 화면에 보여 줍니다.")
        else
            status:SetText("알림을 켜고 스킬 또는 장신구를 먼저 등록하세요.")
        end
    end)
    window.lock = button(window, "위치 이동", 204, -638, 180, function()
        local wanted = not Reminder.IsMoving()
        local value = Reminder.SetMoving(wanted)
        if value then
            status:SetText("화면의 알림을 끌어 옮긴 뒤 [이동 완료]를 누르세요.")
        elseif wanted then
            status:SetText("전투 밖에서, 알림을 켜고 하나 이상 등록한 뒤 옮길 수 있습니다.")
        else
            status:SetText("위치를 저장했습니다.")
        end
        window.Refresh()
    end)
    window:SetScript("OnShow", window.Refresh)
    window:SetScript("OnHide", function()
        commitSound()
        soundBox:ClearFocus()
        Reminder.ClosePreview()
        if picker then picker:Hide() end
        if panel then
            for _, box in ipairs(panel.boxes) do box:ClearFocus() end
            panel:Hide()
        end
    end)
    button(window, "닫기", 420, -638, 104, function() window:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "MimQoLCooldownConfig") end
    window:Hide()
end

function Reminder.ToggleConfig()
    create()
    window:SetShown(not window:IsShown())
end

function Reminder.RefreshConfig()
    if window and window:IsShown() then window.Refresh() end
end
