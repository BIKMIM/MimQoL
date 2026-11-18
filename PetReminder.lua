--------------------------------------------------------------------------------
-- MimQoL - hunter and warlock pet reminders
-- SentinelHunterTools was consulted for behaviour and petless talent exceptions.
-- This module uses its own state tracking and Blizzard UI only.
--------------------------------------------------------------------------------

local CHECK_INTERVAL = 0.25
local MISSING_DELAY = 2
local ATTACK_DELAY = 3
local HEALTH_LIMIT = 0.30
local UNBREAKABLE_BOND = 1223323
local GRIMOIRE_OF_SACRIFICE = 108503

local driver = CreateFrame("Frame")
local statusFrame, healthFrame, healthCurve
local playerClass, needsPet
local missingSince, idleSince, aliveSince, wasDead, previewUntil
local elapsedSinceCheck = 0

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

-- Unknown or restricted data must not be interpreted as a missing pet.
local function readValue(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or isSecret(value) then return nil end
    if type(value) == "table" and type(issecrettable) == "function"
        and issecrettable(value) then return nil end
    return value
end

local function optionEnabled(key)
    return type(MimQoLDB) == "table" and MimQoLDB[key] ~= false
end

local function supportedClass()
    return playerClass == "HUNTER" or playerClass == "WARLOCK"
end

local function selectedTalent(spellID)
    local spellBook = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown
    if readValue(spellBook, spellID) == true then return true end

    -- Passive choice talents are not always represented in the spell book.
    local configID = readValue(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    if not configID or not C_Traits then return nil end
    local config = readValue(C_Traits.GetConfigInfo, configID)
    if not config or type(config.treeIDs) ~= "table" then return nil end
    for _, treeID in ipairs(config.treeIDs) do
        local nodes = readValue(C_Traits.GetTreeNodes, treeID)
        if not nodes then return nil end
        for _, nodeID in ipairs(nodes) do
            local node = readValue(C_Traits.GetNodeInfo, configID, nodeID)
            if not node then return nil end
            if node.activeRank and node.activeRank > 0 and node.activeEntry then
                local entry = readValue(C_Traits.GetEntryInfo,
                    configID, node.activeEntry.entryID)
                local definition = entry and readValue(C_Traits.GetDefinitionInfo,
                    entry.definitionID)
                if not definition then return nil end
                if definition.spellID == spellID then return true end
            end
        end
    end
    return false
end

local function refreshPetRequirement()
    local ok, _, class = pcall(UnitClass, "player")
    playerClass = ok and not isSecret(class) and class or nil
    needsPet = nil
    if not supportedClass() then return end
    local spec = readValue(GetSpecialization)
    if not spec then return end
    if playerClass == "HUNTER" then
        if spec == 2 then
            needsPet = selectedTalent(UNBREAKABLE_BOND)
        else
            needsPet = true
        end
    elseif spec == 2 then
        needsPet = true -- Demonology always needs its permanent demon.
    else
        local sacrifice = selectedTalent(GRIMOIRE_OF_SACRIFICE)
        if sacrifice ~= nil then needsPet = not sacrifice end
    end
end

local function makeAlert(offsetY, red, green, blue)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(780, 48)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("CENTER")
    -- Inherit the locale's font; an English-only font breaks Korean glyphs.
    local font = frame.text:GetFont()
    if font then frame.text:SetFont(font, 30, "OUTLINE") end
    frame.text:SetTextColor(red, green, blue)
    frame.text:SetShadowColor(0, 0, 0, 0.8)
    frame.text:SetShadowOffset(2, -2)
    frame:Hide()
    return frame
end

local function createAlerts()
    if statusFrame then return end
    statusFrame = makeAlert(180, 1, 0.85, 0.15)
    healthFrame = makeAlert(136, 1, 0.35, 0.15)
end

local function hideAlerts()
    if statusFrame then statusFrame:Hide() end
    if healthFrame then healthFrame:Hide() end
end

local function resetTracking()
    missingSince, idleSince, aliveSince = nil, nil, nil
end

local function suppressed()
    return readValue(UnitIsDeadOrGhost, "player") ~= false
        or readValue(IsMounted) == true
        or readValue(UnitOnTaxi, "player") == true
        or readValue(UnitInVehicle, "player") == true
        or readValue(UnitHasVehicleUI, "player") == true
        or readValue(UnitIsFeignDeath, "player") == true
        or readValue(C_PetBattles and C_PetBattles.IsInBattle) == true
        or readValue(IsShiftKeyDown) == true
end

local function showStatus(message)
    if message then
        statusFrame.text:SetText(message)
        statusFrame:Show()
    else
        statusFrame:Hide()
    end
end

local function healingMessage()
    if playerClass == "WARLOCK" then
        return "악마 체력 부족! 생명력 집중으로 치유하세요"
    end
    return "야수 체력 부족! 동물 치료를 사용하세요"
end

local function updateHealth()
    healthFrame.text:SetText(healingMessage())
    if type(UnitHealthPercent) == "function" and C_CurveUtil
        and type(C_CurveUtil.CreateCurve) == "function"
        and Enum and Enum.LuaCurveType then
        -- Send a numeric curve's result straight to the UI. Never read back or
        -- branch on secret health/alpha, including inside restricted instances.
        local ok = pcall(function()
            if not healthCurve then
                local curve = C_CurveUtil.CreateCurve()
                curve:SetType(Enum.LuaCurveType.Step)
                curve:AddPoint(0, 1)
                curve:AddPoint(HEALTH_LIMIT, 0)
                healthCurve = curve
            end
            healthFrame:SetAlpha(UnitHealthPercent("pet", false, healthCurve))
        end)
        if ok then
            healthFrame:Show()
            return
        end
    end

    -- Fallback only for clients/API states with readable numeric health.
    local health = readValue(UnitHealth, "pet")
    local maximum = readValue(UnitHealthMax, "pet")
    if type(health) == "number" and type(maximum) == "number"
        and maximum > 0 and health > 0 and health / maximum < HEALTH_LIMIT then
        healthFrame:SetAlpha(1)
        healthFrame:Show()
    else
        healthFrame:Hide()
    end
end

-- The player is actually fighting something the pet should be on. Combat
-- lingers for seconds after a kill and spreads from the group, so the combat
-- flag alone is not enough. A value that cannot be read does not block.
local function fightingTarget()
    if readValue(UnitExists, "target") ~= true then return false end
    if readValue(UnitIsDeadOrGhost, "target") == true then return false end
    if readValue(UnitCanAttack, "player", "target") == false then return false end
    if readValue(UnitAffectingCombat, "target") == false then return false end
    return true
end

local function updateAlerts()
    if not optionEnabled("petReminder") or not supportedClass() or suppressed() then
        previewUntil = nil
        resetTracking()
        hideAlerts()
        return
    end

    createAlerts()
    local now = GetTime()
    if previewUntil and now < previewUntil then return end
    previewUntil = nil

    local exists = readValue(UnitExists, "pet")
    -- Check death even when UnitExists is false: a dead hunter pet can vanish.
    local dead = readValue(UnitIsDeadOrGhost, "pet")
    if dead == true then wasDead = true end
    if exists == true and dead == false then wasDead = false end

    if exists == nil or dead == nil then
        resetTracking()
        hideAlerts()
        return
    end

    if exists == false or dead == true then
        idleSince, aliveSince = nil, nil
        healthFrame:Hide()
        missingSince = missingSince or now
        local message
        if needsPet == true and optionEnabled("petReminderMissing") then
            if wasDead then
                message = playerClass == "HUNTER"
                    and "야수가 죽었습니다! 야수 되살리기를 사용하세요"
                    or "악마가 죽었습니다! 다시 소환하세요"
            elseif now - missingSince >= MISSING_DELAY then
                message = playerClass == "HUNTER"
                    and "야수가 없습니다! 야수를 소환하세요"
                    or "악마가 없습니다! 악마를 소환하세요"
            end
        end
        showStatus(message)
        return
    end

    missingSince = nil
    aliveSince = aliveSince or now
    local message
    if optionEnabled("petReminderAttack")
        and readValue(InCombatLockdown) == true
        and readValue(UnitExists, "pettarget") == false
        and fightingTarget() then
        idleSince = idleSince or now
        if now - idleSince >= ATTACK_DELAY then
            message = playerClass == "HUNTER"
                and "야수가 공격하지 않습니다! 공격 명령을 내려주세요"
                or "악마가 공격하지 않습니다! 공격 명령을 내려주세요"
        end
    else
        idleSince = nil
    end
    showStatus(message)

    -- Allow summon/revive health to settle before evaluating the health row.
    if optionEnabled("petReminderHealth") and now - aliveSince >= 1 then
        updateHealth()
    else
        healthFrame:Hide()
    end
end

local function onUpdate(_, elapsed)
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    if elapsedSinceCheck >= CHECK_INTERVAL then
        elapsedSinceCheck = 0
        updateAlerts()
    end
end

local function applySettings()
    driver:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    previewUntil = nil
    resetTracking()
    hideAlerts()
    refreshPetRequirement()
    if not optionEnabled("petReminder") or not supportedClass() then return end

    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    driver:RegisterEvent("PLAYER_TALENT_UPDATE")
    driver:RegisterEvent("SPELLS_CHANGED")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:RegisterUnitEvent("UNIT_PET", "player")
    driver:RegisterUnitEvent("UNIT_HEALTH", "pet")
    driver:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
    driver:SetScript("OnUpdate", onUpdate)
    elapsedSinceCheck = 0
    updateAlerts()
end

driver:SetScript("OnEvent", function(_, event, unit)
    if isSecret(unit) then return end
    if event == "PLAYER_LOGIN" then
        applySettings()
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        wasDead = nil
        resetTracking()
        refreshPetRequirement()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit ~= "player" then return end
        wasDead = nil
        resetTracking()
        refreshPetRequirement()
    elseif event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        refreshPetRequirement()
    end
    updateAlerts()
end)
driver:RegisterEvent("PLAYER_LOGIN")

_G.MimQoLPetReminder_ApplySettings = applySettings
_G.MimQoLPetReminder_Test = function()
    if not optionEnabled("petReminder") or not supportedClass() then
        print("|cffffd100[MimQoL]|r 사냥꾼·흑마법사에서 소환수 알림을 켠 뒤 테스트하세요.")
        return
    end
    if suppressed() then
        print("|cffffd100[MimQoL]|r 탈것·사망 등 알림 숨김 상태를 해제한 뒤 테스트하세요.")
        return
    end
    createAlerts()
    previewUntil = GetTime() + 6
    showStatus("소환수 알림 테스트: 소환 · 부활 · 공격 명령")
    healthFrame.text:SetText(healingMessage())
    healthFrame:SetAlpha(1)
    healthFrame:Show()
end
