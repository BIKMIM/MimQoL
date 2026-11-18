-- Personal cooldown warnings. Restricted spell times go straight from duration
-- curves to the UI; never compare them or use visibility to trigger Lua actions.
local driver = CreateFrame("Frame")
local MAX_ENTRIES = 12
local INTERVAL = 0.1
local cards, entries = {}, {}
local elapsed, previewUntil = 0, nil
local curves, options = {}, {}
local applySettings
local soundStates, lastSound = {}, -math.huge
local readyStates, readyUntil, earlyPlayed = {}, {}, {}
local anchor, moving = nil, false
local pulses = {}
local positions = {}
local presets = {
    { "공격대 경고", 567397 }, { "작업 완료", 558132 },
    { "경매장 열기", 567482 }, { "경매장 닫기", 567499 },
    { "동전", 567428 }, { "퀘스트 수락", 567400 },
    { "퀘스트 실패", 567459 }, { "퀘스트 완료", 567439 },
    { "레벨업", 567431 }, { "알람", 567458 },
    { "귓속말", 567421 }, { "파티 초대", 567451 },
    { "던전 진입", 567419 }, { "무작매칭실패", 567420 },
    { "미니맵 핑", 567416 }, { "무두질", 567417 },
    { "친구 접속", 567402 }, { "PVP 깃발", 567427 },
    { "준비완료", 558137 }, { "준비해요", 543388 },
    { "준비됐습니다", 544136 }, { "너흰 아직 준비가 안됐다", 552503 },
    { "당신을 정화하겠어요", 617323 }, { "어둠이여 사라져라", 617325 },
    { "어째서 포기하지 않죠?", 573086 }, { "그래 나도 자네를 구할 수 있어 기쁘네", 544345 },
    { "거기서 봐요 삼촌", 635496 }, { "드디어 제가 바라던 모습을 보여주네요", 635498 },
    { "미안하지만 당신은 눈에 띄어요", 635562 }, { "또~ 죽지마세요", 563125 },
    { "아 결국 오실 줄 알았어요", 3049656 },
}

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function readable(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or isSecret(value) then return nil end
    if type(value) == "table" and type(issecrettable) == "function"
        and issecrettable(value) then return nil end
    return value
end

local function number(value, fallback, minimum, maximum)
    if isSecret(value) then return fallback end
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function enabled()
    return type(MimQoLDB) == "table" and MimQoLDB.cooldownReminder == true
end

-- Registrations, their own settings and the group position belong to the
-- class and specialization, so alts of one class share each spec's list and
-- another spec never shows it. The flat keys are the working copy.
local CLASS_DEFAULTS = { cooldownReminderEntries = "", cooldownReminderPositions = "",
    cooldownReminderEntryOptions = "", cooldownReminderX = 0, cooldownReminderY = 40 }
local boundKey, boundTarget, specName

-- Returns the spec ID, false when the client has no spec API (class-wide list),
-- or nil while the spec is not known yet.
local function currentSpec()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return false
    end
    local ok, index = pcall(GetSpecialization)
    if not ok or isSecret(index) or type(index) ~= "number" or index < 1 then return nil end
    local ok2, id, name = pcall(GetSpecializationInfo, index)
    if not ok2 or isSecret(id) or type(id) ~= "number" or id <= 0 then return nil end
    return id, (not isSecret(name) and type(name) == "string") and name or nil
end

local function syncClassProfile()
    if type(MimQoLDB) ~= "table" or type(MimQoLDB.cooldownReminderEntries) ~= "string"
        or type(UnitClass) ~= "function" then return boundKey ~= nil end
    local ok, className, class = pcall(UnitClass, "player")
    if not ok or isSecret(class) or type(class) ~= "string" or class == "" then return boundKey ~= nil end
    local spec, name = currentSpec()
    if spec == nil then
        -- The spec is not loaded yet; keep saving into the list already bound.
        if boundTarget then
            for key in pairs(CLASS_DEFAULTS) do boundTarget[key] = MimQoLDB[key] end
        end
        return boundKey ~= nil
    end
    local profiles = MimQoLDB.cooldownReminderProfiles
    -- The first run keeps the old account-wide list for the current class only.
    local migrating = type(profiles) ~= "table"
    if migrating then
        profiles = {}
        MimQoLDB.cooldownReminderProfiles = profiles
    end
    local profile = type(profiles[class]) == "table" and profiles[class] or {}
    profiles[class] = profile
    if migrating then
        for key in pairs(CLASS_DEFAULTS) do profile[key] = MimQoLDB[key] end
    end
    local target, key = profile, class
    if spec then
        if type(profile.specs) ~= "table" then profile.specs = {} end
        key = class .. ":" .. spec
        target = profile.specs[spec]
        if type(target) ~= "table" then
            -- A spec seen for the first time starts from the old class-wide list
            -- (empty for a new class) so nothing registered before is lost.
            target = {}
            for field, value in pairs(CLASS_DEFAULTS) do
                local saved = profile[field]
                target[field] = type(saved) == type(value) and saved or value
            end
            profile.specs[spec] = target
        end
    end
    if boundKey ~= key then
        if boundKey or not migrating or spec then
            for field, value in pairs(CLASS_DEFAULTS) do
                local saved = target[field]
                MimQoLDB[field] = type(saved) == type(value) and saved or value
            end
        end
        boundKey, boundTarget = key, target
    end
    specName = spec and (name or ("전문화 " .. spec)) or (not isSecret(className) and className or class)
    for field in pairs(CLASS_DEFAULTS) do target[field] = MimQoLDB[field] end
    return true
end

local function seconds()
    return number(MimQoLDB and MimQoLDB.cooldownReminderSeconds, 5, 1, 60)
end

-- An entry's own value wins; an unset one follows the shared setting.
local function entrySeconds(entry)
    local own = options[entry.kind .. ":" .. entry.id]
    return own and own.seconds or seconds()
end

local function playSound(entry)
    if readable(GetCVar, "Sound_EnableDialog") == "0" then
        return false, "와우 소리 설정에서 대화 소리를 켜 주세요."
    end
    local own = entry and options[entry.kind .. ":" .. entry.id]
    if not own or not own.soundType then own = {} end
    local mode = own.soundType or MimQoLDB.cooldownReminderSoundType
    if mode == "none" then return false, "이 알림은 소리를 내지 않습니다." end
    if mode == "custom" then
        local file = own.soundFile or MimQoLDB.cooldownReminderSoundFile
        if type(file) ~= "string" or file == "" then return false, "파일명을 입력하세요." end
        local paths
        if file:find("\\", 1, true) or file:find("/", 1, true) then
            paths = { file }
        else
            paths = { "sound\\" .. file, "sounds\\" .. file,
                "Interface\\AddOns\\MimQoL\\sounds\\" .. file,
                "Interface\\AddOns\\MimDice\\sounds\\" .. file }
        end
        for _, path in ipairs(paths) do
            if readable(PlaySoundFile, path, "Dialog") == true then return true, "재생했습니다." end
        end
        return false, "파일 경로와 소리 설정을 확인하세요. 새 파일은 게임 재시작이 필요할 수 있습니다."
    end
    local id
    if mode == "id" then id = own.soundID or MimQoLDB.cooldownReminderSoundID
    else id = own.soundKey or MimQoLDB.cooldownReminderSoundKey end
    id = tonumber(id)
    if not id or id ~= id or id < 1 or id ~= math.floor(id) then return false, "소리 ID를 확인하세요." end
    local func = id > 500000 and PlaySoundFile or PlaySound
    if readable(func, id, "Dialog") == true then return true, "재생했습니다." end
    return false, "소리 ID와 와우 소리 설정을 확인하세요."
end

local function updateSound(entry, remaining)
    local key = entry.kind .. ":" .. entry.id
    if isSecret(remaining) or type(remaining) ~= "number" or remaining ~= remaining then
        soundStates[key] = nil
        return
    end
    if remaining > entrySeconds(entry) then
        soundStates[key] = true
    elseif remaining <= 0 then
        soundStates[key] = nil
    elseif soundStates[key] then
        soundStates[key] = nil
        if MimQoLDB.cooldownReminderTiming ~= "ready" and MimQoLDB.cooldownReminderSoundEnabled then
            earlyPlayed[key] = true
            if GetTime() - lastSound >= 0.4 then playSound(entry); lastSound = GetTime() end
        end
    end
end

local function readEntries()
    local result, seen = {}, {}
    local saved = MimQoLDB and MimQoLDB.cooldownReminderEntries
    if isSecret(saved) or type(saved) ~= "string" then return result end
    for line in saved:gmatch("[^\r\n]+") do
        -- An optional third field is the minimum cast count of a count-gated spell.
        local kind, id, count = line:match("^(%a+):(%d+):?(%d*)$")
        id, count = tonumber(id), tonumber(count)
        local key = id and (tostring(kind) .. ":" .. id)
        if (kind == "spell" or kind == "item") and id and id > 0
            and id < 2147483648 and not seen[key] and #result < MAX_ENTRIES then
            if kind ~= "spell" or not count or count < 1 or count > 99 then count = nil end
            result[#result + 1] = { kind = kind, id = id, count = count }
            seen[key] = true
        end
    end
    return result
end

local function saveEntries(list)
    local lines = {}
    for _, entry in ipairs(list) do
        lines[#lines + 1] = entry.kind .. ":" .. entry.id .. (entry.count and ":" .. entry.count or "")
    end
    MimQoLDB.cooldownReminderEntries = table.concat(lines, "\n")
    applySettings()
end

local function describe(entry)
    if entry.kind == "spell" then
        local info = readable(C_Spell and C_Spell.GetSpellInfo, entry.id)
        if info then return info.name, info.iconID end
    elseif C_Item then
        local name = readable(C_Item.GetItemNameByID, entry.id)
        local icon = readable(C_Item.GetItemIconByID, entry.id)
        if name then return name, icon end
    end
    return (entry.kind == "spell" and "스킬 " or "장신구 ") .. entry.id, 134400
end

local function add(kind, value)
    if not MimQoLDB then return false, "설정을 아직 불러오지 못했습니다." end
    if not syncClassProfile() then return false, "전문화 정보를 불러오는 중입니다. 잠시 뒤 다시 시도하세요." end
    if readable(InCombatLockdown) then return false, "전투가 끝난 뒤 등록하세요." end
    if isSecret(value) then return false, "ID를 확인하세요." end
    local id = tonumber(value)
    if (kind ~= "spell" and kind ~= "item") or not id or id ~= id
        or id < 1 or id >= 2147483648 or id ~= math.floor(id) then
        return false, "스킬 또는 장신구의 숫자 ID를 입력하세요."
    end
    if kind == "spell" then
        if not readable(C_Spell and C_Spell.GetSpellInfo, id) then
            return false, "스킬을 찾지 못했습니다. ID를 확인하세요."
        end
        if readable(C_Spell and C_Spell.IsSpellPassive, id) then
            return false, "지속 효과가 아닌 사용 스킬을 등록하세요."
        end
    else
        if readable(C_Item and C_Item.DoesItemExistByID, id) == false then
            return false, "아이템을 찾지 못했습니다. ID를 확인하세요."
        end
        if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
            local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, id)
            if ok and not isSecret(equipLoc) and equipLoc and equipLoc ~= "INVTYPE_TRINKET" then
                return false, "장신구 아이템을 등록하세요."
            end
        end
    end
    local list = readEntries()
    for _, entry in ipairs(list) do
        if entry.kind == kind and entry.id == id then return false, "이미 등록되어 있습니다." end
    end
    if #list >= MAX_ENTRIES then return false, "최대 12개까지 등록할 수 있습니다." end
    list[#list + 1] = { kind = kind, id = id }
    saveEntries(list)
    if kind == "item" and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        C_Item.RequestLoadItemDataByID(id)
    end
    return true, "등록했습니다."
end

local function addFromCursor()
    if type(GetCursorInfo) ~= "function" then return false, "드래그 정보를 읽을 수 없습니다." end
    if readable(InCombatLockdown) then return false, "전투가 끝난 뒤 등록하세요." end
    local kind, id, _, spellID = GetCursorInfo()
    if isSecret(kind) then return false, "스킬이나 장신구를 놓아 주세요." end
    if kind == "spell" then id = spellID end
    local ok, message = add(kind, id)
    -- Only consume a supported, successfully saved drop. Never move an action.
    if ok and type(ClearCursor) == "function" then ClearCursor() end
    return ok, message
end

local function readPositions()
    local result = {}
    local saved = MimQoLDB and MimQoLDB.cooldownReminderPositions
    if isSecret(saved) or type(saved) ~= "string" then return result end
    for key, x, y in saved:gmatch("(%a+:%d+)=(%-?%d+),(%-?%d+)") do
        result[key] = { tonumber(x), tonumber(y) }
    end
    return result
end

local function savePositions()
    local lines = {}
    for key, position in pairs(positions) do
        lines[#lines + 1] = key .. "=" .. position[1] .. "," .. position[2]
    end
    table.sort(lines)
    MimQoLDB.cooldownReminderPositions = table.concat(lines, "\n")
end

-- Per-entry overrides are saved as "kind:id|name=value|..." lines.
local OPTION_NAMES = { "seconds", "size", "soundType", "soundKey", "soundID", "soundFile" }

local function cleanOption(name, value)
    if name == "seconds" or name == "size" then
        value = tonumber(value)
        if not value or value ~= value then return nil end
        if name == "size" then return math.floor(math.max(24, math.min(200, value)) + 0.5) end
        return math.floor(math.max(1, math.min(60, value)) * 10 + 0.5) / 10
    elseif name == "soundType" then
        return (value == "preset" or value == "custom" or value == "id" or value == "none") and value or nil
    elseif name == "soundKey" or name == "soundID" then
        value = tonumber(value)
        return value and value >= 1 and value < 2147483648 and value == math.floor(value) and value or nil
    elseif name == "soundFile" and type(value) == "string" then
        value = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
        return value ~= "" and value or nil
    end
end

local function readOptions()
    local result = {}
    local saved = MimQoLDB and MimQoLDB.cooldownReminderEntryOptions
    if isSecret(saved) or type(saved) ~= "string" then return result end
    for line in saved:gmatch("[^\r\n]+") do
        local key, rest = line:match("^(%a+:%d+)(.*)$")
        local own = {}
        for name, value in (rest or ""):gmatch("|(%a+)=([^|]*)") do own[name] = cleanOption(name, value) end
        if key and next(own) then result[key] = own end
    end
    return result
end

local function saveOptions()
    local lines = {}
    for key, own in pairs(options) do
        local line = key
        for _, name in ipairs(OPTION_NAMES) do
            local value = own[name]
            if type(value) == "number" and value == math.floor(value) then value = string.format("%d", value) end
            if value ~= nil then line = line .. "|" .. name .. "=" .. tostring(value) end
        end
        if line ~= key then lines[#lines + 1] = line end
    end
    table.sort(lines)
    MimQoLDB.cooldownReminderEntryOptions = table.concat(lines, "\n")
end

-- x and y place the alert from the group's center; clearing either returns it
-- to the grid. Every other name clears back to the shared setting.
local function setOption(kind, id, name, value)
    if isSecret(value) then return end
    local key = kind .. ":" .. id
    if name == "x" or name == "y" then
        value = tonumber(value)
        if not value or value ~= value then
            positions[key] = nil
        else
            local position = positions[key] or { 0, 0 }
            position[name == "x" and 1 or 2] = math.floor(math.max(-10000, math.min(10000, value)) + 0.5)
            positions[key] = position
        end
        savePositions()
    else
        local own = options[key] or {}
        own[name] = cleanOption(name, value)
        options[key] = next(own) and own or nil
        saveOptions()
    end
    applySettings()
end

local function clearOptions(kind, id)
    positions[kind .. ":" .. id], options[kind .. ":" .. id] = nil, nil
    savePositions()
    saveOptions()
end

local function remove(kind, id)
    local list = readEntries()
    for index, entry in ipairs(list) do
        if entry.kind == kind and entry.id == id then
            table.remove(list, index)
            clearOptions(kind, id)
            saveEntries(list)
            return
        end
    end
end

local function setCount(kind, id, value)
    if isSecret(value) then return end
    value = tonumber(value)
    if kind ~= "spell" or not value or value < 1 then value = nil end
    if value then value = math.floor(math.min(value, 99)) end
    local list = readEntries()
    for _, entry in ipairs(list) do
        if entry.kind == kind and entry.id == id then
            if entry.count == value then return end
            entry.count = value
            local key = kind .. ":" .. id
            readyStates[key], readyUntil[key], soundStates[key], earlyPlayed[key] = nil, nil, nil, nil
            saveEntries(list)
            return
        end
    end
end

-- A dragged alert keeps its own spot, measured from the group's center to the
-- top of its icon so resizing the group or the alert does not move it.
local function placeCard(card)
    local x, top = card:GetCenter(), card:GetTop()
    local cx, cy = anchor:GetCenter()
    local scale = card:GetScale()
    if not (x and top and cx and cy and scale and scale > 0 and card.entry) then return end
    x, top = math.floor(x - cx / scale + 0.5), math.floor(top - cy / scale + 0.5)
    positions[card.entry.kind .. ":" .. card.entry.id] = { x, top }
    savePositions()
    syncClassProfile()
    card:ClearAllPoints()
    card:SetPoint("TOP", anchor, "CENTER", x, top)
    local api = _G.MimQoLCooldownReminder
    if api and api.RefreshConfig then api.RefreshConfig() end
end

local function createCard(index)
    local card = CreateFrame("Frame", nil, anchor)
    card:SetSize(236, 108)
    card:SetFrameStrata("LOW")
    card:EnableMouse(false)
    card:SetMovable(true)
    card:SetClampedToScreen(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(self)
        if moving and readable(InCombatLockdown) ~= true then
            self.placing = true
            self:StartMoving()
        end
    end)
    card:SetScript("OnDragStop", function(self)
        if not self.placing then return end
        self.placing = nil
        self:StopMovingOrSizing()
        placeCard(self)
    end)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(48, 48)
    card.icon:SetPoint("TOP", 0, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.time = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.time:SetPoint("CENTER", card.icon, "CENTER", 0, 0)
    card.time:SetTextColor(1, 0.85, 0.2)
    card.time:SetShadowOffset(1, -1)
    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.label:SetPoint("TOP", card.icon, "BOTTOM", 0, -5)
    card.label:SetWidth(232)
    card.label:SetMaxLines(2)
    card:Hide()
    cards[index] = card
    return card
end

local function createAnchor()
    if anchor then return end
    anchor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    anchor:SetFrameStrata("LOW")
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:EnableMouse(false)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    anchor:SetBackdropBorderColor(1, 0.82, 0, 0)
    anchor:SetScript("OnDragStart", function(self)
        if moving and readable(InCombatLockdown) ~= true then self:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and y and cx and cy then
            MimQoLDB.cooldownReminderX = math.floor(x - cx + 0.5)
            MimQoLDB.cooldownReminderY = math.floor(y - cy + 0.5)
            syncClassProfile()
        end
    end)
end

-- Alerts never intercept clicks; only the explicit move mode enables the mouse.
local function applyMoving()
    if not anchor then return end
    anchor:StopMovingOrSizing()
    anchor:EnableMouse(moving)
    anchor:SetBackdropBorderColor(1, 0.82, 0, moving and 1 or 0)
    for _, card in ipairs(cards) do
        card:StopMovingOrSizing()
        card:EnableMouse(moving)
    end
end

local function hideAll()
    for _, card in ipairs(cards) do card:Hide() end
end

local function hidePulses()
    for _, frame in ipairs(pulses) do
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

local function animatePulse(self)
    local progress = (GetTime() - self.started) / self.total
    if progress >= 1 then
        self:SetScript("OnUpdate", nil)
        self:Hide()
        return
    end
    -- Fade in, hold, then fade out while the icon grows to 140%.
    local fade = progress < 0.2 and progress / 0.2 or progress < 0.5 and 1 or (1 - progress) / 0.5
    self:SetAlpha(self.peak * fade)
    local size = self.size * (1 + 0.4 * progress)
    self:SetSize(size, size)
end

local function startPulse(entry)
    local frame
    for _, candidate in ipairs(pulses) do
        if not candidate:IsShown() then frame = candidate; break end
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("LOW")
        frame:EnableMouse(false)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetAllPoints()
        frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        pulses[#pulses + 1] = frame
    end
    local icon
    if entry then icon = select(2, describe(entry)) end
    frame.icon:SetTexture(icon or 134400)
    frame.size = number(MimQoLDB.cooldownReminderPulseSize, 180, 40, 500)
    frame.peak = number(MimQoLDB.cooldownReminderPulseOpacity, 50, 10, 100) / 100
    frame.total = 0.8 / number(MimQoLDB.cooldownReminderPulseSpeed, 1, 0.3, 2.5)
    frame.started = GetTime()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", number(MimQoLDB.cooldownReminderPulseX, 0, -10000, 10000),
        number(MimQoLDB.cooldownReminderPulseY, 0, -10000, 10000))
    frame:SetSize(frame.size, frame.size)
    frame:SetAlpha(0)
    frame:Show()
    frame:SetScript("OnUpdate", animatePulse)
end

local function suppressed()
    return readable(IsShiftKeyDown) == true
        or readable(UnitIsDeadOrGhost, "player") == true
        or (MimQoLDB.cooldownReminderCombatOnly == true and readable(InCombatLockdown) ~= true)
end

local function resolvedSpell(id)
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    local override = readable(C_Spell and C_Spell.GetOverrideSpell, id)
    if type(override) ~= "number" or override <= 0 then override = id end
    if readable(known, id) ~= true and readable(known, override) ~= true then return nil end
    id = override
    return id
end

-- GetSpellCharges also returns a one-charge table for ordinary cooldown spells
-- whose recharge flag never activates; only maxCharges > 1 is a charge spell.
local function spellCharges(id)
    local charges = readable(C_Spell and C_Spell.GetSpellCharges, id)
    if not charges then return nil end
    local maximum = charges.maxCharges
    if isSecret(maximum) or type(maximum) ~= "number" or maximum <= 1 then return nil end
    return charges
end

local function spellDuration(entry)
    local id = resolvedSpell(entry.id)
    if not id then return nil end
    -- Keep showing the registered spell while its own cooldown is tracked.
    if readyStates[entry.kind .. ":" .. entry.id] == entry.id then id = entry.id end
    -- Charge spells warn about the next recharge, including when one is usable.
    if spellCharges(id) then
        local duration = readable(C_Spell and C_Spell.GetSpellChargeDuration, id)
        if duration then return duration end
    end
    return readable(C_Spell and C_Spell.GetSpellCooldownDuration, id, true)
end

-- isOnGCD is true only while the GCD is all that remains; a real cooldown
-- reports nil in game, so nil must count as "not the GCD".
local function onCooldown(id)
    local info = readable(C_Spell and C_Spell.GetSpellCooldown, id)
    return info ~= nil and not isSecret(info.isEnabled) and info.isEnabled == true
        and not isSecret(info.isActive) and info.isActive == true
        and not isSecret(info.isOnGCD) and info.isOnGCD ~= true
end

-- An armed spell remembers the spell ID its cooldown was seen on.
local function setActive(entry, active, canArm, source)
    if isSecret(active) or type(active) ~= "boolean" then return end
    local key = entry.kind .. ":" .. entry.id
    if active then
        if canArm == false then return end
        if not readyStates[key] then earlyPlayed[key], readyUntil[key] = nil, nil end
        readyStates[key] = source or true
    else
        if readyStates[key] and not previewUntil and not moving and not suppressed() then
            readyUntil[key] = GetTime() + number(MimQoLDB.cooldownReminderDuration, 3, 1, 15)
            if MimQoLDB.cooldownReminderPulse == true then startPulse(entry) end
            if MimQoLDB.cooldownReminderSoundEnabled and not earlyPlayed[key]
                and GetTime() - lastSound >= 0.4 then
                playSound(entry)
                lastSound = GetTime()
            end
        end
        readyStates[key] = false
        earlyPlayed[key], soundStates[key] = nil, nil
    end
end

local function refreshSpellState(entry, cooldownEvent)
    -- Count-gated entries are a standing indicator, not a completion alert.
    if entry.count then return end
    local id = resolvedSpell(entry.id)
    local key = entry.kind .. ":" .. entry.id
    if not id then readyStates[key], readyUntil[key] = nil, nil; return end
    -- A temporary override (such as a summoned pet's ability) has its own
    -- cooldown, so the registered spell's cooldown wins once it is seen running.
    if id ~= entry.id and (readyStates[key] == entry.id or (cooldownEvent and onCooldown(entry.id))) then
        id = entry.id
    end
    local charges = spellCharges(id)
    if charges then
        -- isActive is NeverSecret. When charge counts/times are restricted,
        -- the unambiguous completion is full recharge, not an invented count.
        setActive(entry, charges.isActive, true, id)
        return
    end
    local info = readable(C_Spell and C_Spell.GetSpellCooldown, id)
    if not info or isSecret(info.isEnabled) or info.isEnabled ~= true then return end
    if cooldownEvent then
        -- Arm only from settled event state; other moments can misreport the GCD.
        if isSecret(info.isOnGCD) or isSecret(info.isActive) then return end
        -- A GCD flag must never turn an already tracked cooldown into a finish.
        if info.isActive == false or info.isOnGCD ~= true then
            setActive(entry, info.isActive, true, id)
        end
    else
        -- Poll for the finish, but never arm a new cooldown from a possible GCD.
        setActive(entry, info.isActive, false)
    end
end

local function itemRemaining(id)
    local equipped = false
    for slot = 13, 14 do
        if readable(GetInventoryItemID, "player", slot) == id then equipped = true; break end
    end
    if not equipped or not C_Item or type(C_Item.GetItemCooldown) ~= "function" then return nil end
    local ok, start, duration, active = pcall(C_Item.GetItemCooldown, id)
    -- Item times are normally readable. Unknown/restricted values are not ready.
    if not ok or isSecret(start) or isSecret(duration) or isSecret(active)
        or type(start) ~= "number" or type(duration) ~= "number" or active ~= true then return nil end
    if start == 0 or duration == 0 then return 0 end
    if start < 0 or duration < 0 then return nil end
    return math.max(0, start + duration - GetTime())
end

-- Usable now: a spell this spec knows, or a trinket that is equipped.
local function usable(entry)
    if entry.kind == "spell" then return resolvedSpell(entry.id) ~= nil end
    for slot = 13, 14 do
        if readable(GetInventoryItemID, "player", slot) == entry.id then return true end
    end
    return false
end

local function update()
    if not enabled() then hideAll(); return end
    if previewUntil and GetTime() >= previewUntil then previewUntil = nil end
    if not previewUntil and not moving and suppressed() then
        -- Keep observing completion while suppressed, so releasing Shift or
        -- entering combat cannot announce an old completion.
        soundStates, readyUntil = {}, {}
        for _, entry in ipairs(entries) do
            if entry.kind == "spell" then
                refreshSpellState(entry, false)
            else
                local remaining = itemRemaining(entry.id)
                if remaining then setActive(entry, remaining > 0, true) end
            end
        end
        hideAll()
        return
    end
    for index, entry in ipairs(entries) do
        local card = cards[index]
        if (previewUntil or moving) and not card.usable then
            card:Hide()
        elseif previewUntil or moving then
            card:SetAlpha(1)
            if entry.count then card.stack:SetValue(entry.count) end
            if MimQoLDB.cooldownReminderTiming == "ready" then
                card.time:SetText("준비")
                card.label:SetText(card.readyText)
            else
                card.time:SetFormattedText("%.1f", card.seconds)
                card.label:SetText(card.normalText)
            end
            card:Show()
        elseif entry.count then
            -- The cast count (e.g. Wild Imps on Implosion) is restricted: Lua only
            -- checks the public cooldown state and the bar's range does the rest.
            local id = resolvedSpell(entry.id)
            local ok, count
            if id and not onCooldown(id) and C_Spell and type(C_Spell.GetSpellCastCount) == "function" then
                ok, count = pcall(C_Spell.GetSpellCastCount, id)
            end
            if ok and (isSecret(count) or type(count) == "number")
                and pcall(card.stack.SetValue, card.stack, count) then
                card:SetAlpha(1)
                card:Show()
            else
                card:Hide()
            end
        elseif entry.kind == "spell" then
            refreshSpellState(entry, false)
            local duration = spellDuration(entry)
            if duration and card.curve then
                local ok = pcall(function()
                    card:SetAlpha(duration:EvaluateRemainingDuration(card.curve))
                    card.time:SetFormattedText("%.1f", duration:GetRemainingDuration())
                end)
                if ok then card:Show() else card:Hide() end
                -- Only public numeric times can trigger audio. Do not read
                -- curve output, frame alpha or formatted text back into Lua.
                updateSound(entry, readable(duration.GetRemainingDuration, duration))
            else
                card:Hide()
                updateSound(entry, nil)
            end
        else
            local remaining = itemRemaining(entry.id)
            if remaining then
                setActive(entry, remaining > 0, true)
            else
                local key = entry.kind .. ":" .. entry.id
                readyStates[key], readyUntil[key] = nil, nil
            end
            updateSound(entry, remaining)
            if remaining and remaining > 0 and remaining <= card.seconds then
                card:SetAlpha(1)
                card.time:SetFormattedText("%.1f", remaining)
                card:Show()
            else
                card:Hide()
            end
        end
        if not previewUntil and not moving and not entry.count then
            local untilTime = readyUntil[entry.kind .. ":" .. entry.id]
            if untilTime and GetTime() < untilTime then
                card:SetAlpha(1)
                card.time:SetText("준비")
                card.label:SetText(card.readyText)
                card:Show()
            else
                card.label:SetText(card.normalText)
                if MimQoLDB.cooldownReminderTiming == "ready" then card:Hide() end
            end
        end
        if not MimQoLDB.cooldownReminderIconEnabled and not MimQoLDB.cooldownReminderTextEnabled then
            card:Hide()
        end
    end
end

-- One step curve per distinct warning time: visible only inside the window.
local function curveFor(span)
    if not curves[span] and C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function"
        and Enum and Enum.LuaCurveType then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint(0.001, 1)
        curve:AddPoint(span + 0.001, 0)
        curves[span] = curve
    end
    return curves[span]
end

applySettings = function()
    driver:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    hideAll()
    previewUntil, curves, elapsed = nil, {}, 0
    -- Until the spec is known, nothing from another spec's list is shown.
    entries = syncClassProfile() and readEntries() or {}
    positions = readPositions()
    options = readOptions()
    local retained = {}
    for _, entry in ipairs(entries) do retained[entry.kind .. ":" .. entry.id] = true end
    for _, state in ipairs({ soundStates, readyStates, readyUntil, earlyPlayed }) do
        for key in pairs(state) do if not retained[key] then state[key] = nil end end
    end
    if not enabled() or #entries == 0 or MimQoLDB.cooldownReminderPulse ~= true then hidePulses() end
    if not enabled() or #entries == 0 then
        moving, soundStates, readyStates, readyUntil, earlyPlayed = false, {}, {}, {}, {}
        if anchor then anchor:Hide() end
        applyMoving()
        return
    end
    createAnchor()
    -- Alerts this spec cannot use take no grid slot and stay out of the
    -- preview/move view; if none is usable, all are shown so they can be placed.
    local usableFlags, usableCount = {}, 0
    for index, entry in ipairs(entries) do
        usableFlags[index] = usable(entry)
        if usableFlags[index] then usableCount = usableCount + 1 end
    end
    local showAll = usableCount == 0
    local gridCount = showAll and #entries or usableCount
    local scale = number(MimQoLDB.cooldownReminderScale, 100, 50, 200) / 100
    local x = number(MimQoLDB.cooldownReminderX, 0, -10000, 10000)
    local y = number(MimQoLDB.cooldownReminderY, 40, -10000, 10000)
    local columns = math.min(3, gridCount)
    local iconSize = number(MimQoLDB.cooldownReminderIconSize, 48, 24, 96)
    local numberSize = number(MimQoLDB.cooldownReminderNumberSize, 22, 12, 48)
    local fontSize = number(MimQoLDB.cooldownReminderFontSize, 22, 12, 36)
    local rowHeight = iconSize + fontSize * 2 + 30
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
    anchor:SetSize(columns * 240 * scale, math.ceil(gridCount / 3) * rowHeight * scale)
    anchor:Show()
    local slot = 0
    for index, entry in ipairs(entries) do
        local card = cards[index] or createCard(index)
        card.entry = entry
        card.usable = showAll or usableFlags[index]
        local gridIndex
        if card.usable then
            slot = slot + 1
            gridIndex = slot
        else
            gridIndex = gridCount + (index - slot)
        end
        card:ClearAllPoints()
        card:SetScale(scale)
        local key = entry.kind .. ":" .. entry.id
        local position, own = positions[key], options[key] or {}
        if position then
            card:SetPoint("TOP", anchor, "CENTER", position[1], position[2])
        else
            card:SetPoint("TOPLEFT", anchor, "TOPLEFT", ((gridIndex - 1) % 3) * 240,
                -math.floor((gridIndex - 1) / 3) * rowHeight)
        end
        local size = own.size or iconSize
        local height = size + fontSize * 2 + 30
        card:SetHeight(height)
        card.seconds = entrySeconds(entry)
        card.curve = curveFor(card.seconds)
        local name, icon = describe(entry)
        -- A message the user emptied shows no text; only a missing one falls back.
        local message = MimQoLDB.cooldownReminderMessage
        if type(message) ~= "string" then message = "{이름} 곧 준비!" end
        card.normalText = message:gsub("{이름}", function() return name end)
        local readyMessage = MimQoLDB.cooldownReminderReadyMessage
        if type(readyMessage) ~= "string" then readyMessage = "{이름} 준비 완료!" end
        card.readyText = readyMessage:gsub("{이름}", function() return name end)
        card.label:SetText(card.normalText)
        card.label:SetTextColor(number(MimQoLDB.cooldownReminderColorR, 1, 0, 1),
            number(MimQoLDB.cooldownReminderColorG, 0.82, 0, 1),
            number(MimQoLDB.cooldownReminderColorB, 0, 0, 1))
        local font = card.label:GetFont()
        if font then card.label:SetFont(font, fontSize, "OUTLINE") end
        local timeFont = card.time:GetFont()
        if timeFont then card.time:SetFont(timeFont, numberSize, "OUTLINE") end
        card.icon:SetSize(size, size)
        card.icon:SetTexture(icon)
        local iconShown = MimQoLDB.cooldownReminderIconEnabled == true
        -- Only the icon (the text block when icons are off) can be grabbed or
        -- clamped, so alerts placed close together stay separately movable.
        local side = iconShown and (236 - size) / 2 or 0
        local below = iconShown and height - size or size + 18
        card:SetHitRectInsets(side, side, 0, below)
        card:SetClampRectInsets(side, -side, 0, below)
        card.icon:SetShown(iconShown and not entry.count)
        card.time:SetShown(iconShown and not entry.count)
        card.label:SetShown(MimQoLDB.cooldownReminderTextEnabled == true and not entry.count)
        if entry.count then
            -- The fill texture is the icon: empty below the minimum, full from it.
            if not card.stack then
                card.stack = CreateFrame("StatusBar", nil, card)
                card.stack:SetAllPoints(card.icon)
            end
            card.stack:SetStatusBarTexture(icon or 134400)
            card.stack:SetMinMaxValues(entry.count - 1, entry.count)
            card.stack:SetValue(entry.count - 1)
        end
        if card.stack then card.stack:SetShown(iconShown and entry.count ~= nil) end
        card.label:ClearAllPoints()
        card.label:SetPoint("TOP", 0, MimQoLDB.cooldownReminderIconEnabled and -(size + 6) or -6)
    end
    applyMoving()
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT", "SPELL_UPDATE_COOLDOWN",
        "SPELL_UPDATE_CHARGES" }) do
        driver:RegisterEvent(event)
    end
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= INTERVAL then elapsed = 0; update() end
    end)
    update()
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= nil and unit ~= "player" then return end
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        for _, entry in ipairs(entries) do
            if entry.kind == "spell" then refreshSpellState(entry, event == "SPELL_UPDATE_COOLDOWN") end
        end
        update()
    else
        if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
            or event == "PLAYER_SPECIALIZATION_CHANGED" then
            if event == "PLAYER_SPECIALIZATION_CHANGED" then moving = false end
            readyStates, readyUntil, soundStates, earlyPlayed = {}, {}, {}, {}
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            for _, entry in ipairs(entries) do
                if entry.kind == "item" then
                    local key = "item:" .. entry.id
                    readyStates[key], readyUntil[key], soundStates[key], earlyPlayed[key] = nil, nil, nil, nil
                end
            end
        end
        applySettings()
        local api = _G.MimQoLCooldownReminder
        if api and api.RefreshConfig then api.RefreshConfig() end
    end
end)
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- What the settings list shows under each entry, from public state only.
local function entryStatus(entry)
    if entry.kind == "spell" then
        if not resolvedSpell(entry.id) then return "이 전문화에서 배우지 않음", false end
        if entry.count then return "버튼 숫자 " .. entry.count .. " 이상일 때 표시", true end
        return entrySeconds(entry) .. "초 전 알림", true
    end
    for slot = 13, 14 do
        if readable(GetInventoryItemID, "player", slot) == entry.id then
            return "착용 중 · " .. entrySeconds(entry) .. "초 전 알림", true
        end
    end
    return "착용하지 않음", false
end

_G.MimQoLCooldownReminder = {
    ApplySettings = applySettings,
    Add = add,
    AddFromCursor = addFromCursor,
    Remove = remove,
    SetCount = setCount,
    SetEntryOption = setOption,
    GetEntryOptions = function(kind, id)
        local key = kind .. ":" .. id
        local result, position = {}, positions[key]
        for name, value in pairs(options[key] or {}) do result[name] = value end
        result.x, result.y = position and position[1], position and position[2]
        return result
    end,
    ResetEntry = function(kind, id)
        clearOptions(kind, id)
        applySettings()
    end,
    GetEntries = function()
        if not syncClassProfile() then return {} end
        return readEntries()
    end,
    GetSpecName = function()
        syncClassProfile()
        return specName
    end,
    Status = entryStatus,
    Describe = describe,
    Presets = presets,
    TestSound = playSound,
    IsMoving = function() return moving end,
    SetMoving = function(value)
        if value and (readable(InCombatLockdown) == true or not enabled() or #entries == 0) then return false end
        moving = value == true
        readyStates, readyUntil, soundStates, earlyPlayed = {}, {}, {}, {}
        applyMoving()
        update()
        return moving
    end,
    ResetPositions = function()
        positions = {}
        savePositions()
        applySettings()
    end,
    Preview = function()
        if not enabled() or #entries == 0 then return false end
        previewUntil = GetTime() + 5
        readyStates, readyUntil, soundStates, earlyPlayed = {}, {}, {}, {}
        if MimQoLDB.cooldownReminderSoundEnabled then playSound() end
        if MimQoLDB.cooldownReminderPulse == true then startPulse(entries[1]) end
        update()
        return true
    end,
    TestPulse = function() startPulse(entries[1]) end,
    ClosePreview = function()
        previewUntil, moving = nil, false
        readyStates, readyUntil, soundStates, earlyPlayed = {}, {}, {}, {}
        applyMoving()
        update()
    end,
}
