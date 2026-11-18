-- Independent full-party portal prompt. SolaQoL was used to identify the
-- listing/join flow and portal spell IDs; no chat or greeting state is shared.
local driver = CreateFrame("Frame")
local HOME = LE_PARTY_CATEGORY_HOME or 1
local INSTANCE = LE_PARTY_CATEGORY_INSTANCE or 2
local button, preview
local destination, dismissed, joinedResult, joinExpires
local applications = {}
local ready, wasGrouped = false, false
local moving, onMoving
local update

-- Dungeon names and portal spell IDs from the installed SolaQoL season table.
-- Match Blizzard activity names, never player-written listing titles.
local portals = {
    { 1254551, "삼두정의 권좌", "Seat of the Triumvirate" },
    { 1254555, "사론의 구덩이", "Pit of Saron" },
    { 159898, "하늘탑", "Skyreach" },
    { 1254400, "윈드러너 첨탑", "Windrunner Spire" },
    { 1254572, "마법학자의 정원", "Magister's Terrace" },
    { 1254563, "공결탑 제나스", "Nexus-Point Xenas" },
    { 1254559, "마이사라 동굴", "Maisara Caverns" },
    { 393273, "알게타르 대학", "Algeth'ar Academy" },
    { 1286809, "죽음의 골목", "Murder Row" },
    { 1286807, "날로라크의 소굴", "Den of Nalorakk" },
    { 1286801, "눈부신 골짜기", "The Blinding Vale" },
    { 1286804, "공허흉터 투기장", "Voidscar Arena" },
    { 1286812, "송곳니의 제단", "Altar of Fangs" },
    { 1286828, "세스랄리스 사원", "Temple of Sethraliss" },
    { 1286831, "왕들의 안식처", "King's Rest" },
    { 393256, "루비 생명의 웅덩이", "Ruby Life Pools" },
}

local function public(value)
    return type(issecretvalue) ~= "function" or not issecretvalue(value)
end

local function enabled()
    return type(MimQoLDB) == "table" and MimQoLDB.dungeonPortal == true
end

local function combat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function grouped()
    return type(IsInGroup) == "function" and IsInGroup(HOME)
end

local function resolve(entry)
    if not public(entry) or type(entry) ~= "table" then return nil end
    local ids = entry.activityIDs
    if not public(ids) or type(ids) ~= "table" then return nil end
    if not C_LFGList or type(C_LFGList.GetActivityInfoTable) ~= "function" then return nil end
    local found, unknown
    for _, id in ipairs(ids) do
        if not public(id) or type(id) ~= "number" then return nil end
        local info = C_LFGList.GetActivityInfoTable(id)
        if not public(info) or type(info) ~= "table" or not public(info.isMythicPlusActivity) then
            unknown = true
        elseif info.isMythicPlusActivity == true then
            local match
            for _, portal in ipairs(portals) do
                for _, key in ipairs({ "fullName", "shortName" }) do
                    local name = info[key]
                    if public(name) and type(name) == "string"
                        and (name:find(portal[2], 1, true) or name:find(portal[3], 1, true)) then
                        match = portal
                        break
                    end
                end
                if match then break end
            end
            -- Unknown or multiple different destinations must not pick a portal.
            if not match or (found and found ~= match) then return false end
            found = match
        end
    end
    if unknown then return nil end
    return found or false
end

local function searchDestination(id)
    if not public(id) or type(id) ~= "number" or not C_LFGList
        or type(C_LFGList.GetSearchResultInfo) ~= "function" then return nil end
    return resolve(C_LFGList.GetSearchResultInfo(id))
end

local function setDestination(value)
    if value ~= nil and destination ~= value then
        destination, dismissed = value, nil
    end
end

local function clearParty()
    destination, dismissed, joinedResult, joinExpires = nil, nil, nil, nil
    applications = {}
end

local function eligible()
    if not enabled() or not destination or dismissed or not grouped() then return false end
    if type(IsInRaid) == "function" and IsInRaid() then return false end
    if type(IsInGroup) == "function" and IsInGroup(INSTANCE) then return false end
    if type(IsInInstance) == "function" and IsInInstance() then return false end
    if type(GetNumGroupMembers) ~= "function" then return false end
    local count = GetNumGroupMembers(HOME)
    if not public(count) or count ~= 5 then return false end
    if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function"
        and C_ChallengeMode.IsChallengeModeActive() then return false end
    if C_LFGInfo and type(C_LFGInfo.IsInLFGFollowerDungeon) == "function"
        and C_LFGInfo.IsInLFGFollowerDungeon() then return false end
    for index = 1, 4 do
        local unit = "party" .. index
        for _, check in ipairs({ UnitInPartyIsAI or false, UnitIsNPCAsPlayer or false }) do
            if type(check) == "function" then
                local value = check(unit)
                if not public(value) or value then return false end
            end
        end
    end
    return true
end

local function hideButton()
    if combat() or not button then return end
    if type(UnregisterStateDriver) == "function" then UnregisterStateDriver(button, "visibility") end
    button:Hide()
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
end

local function position()
    local x = type(MimQoLDB) == "table" and tonumber(MimQoLDB.dungeonPortalX) or 0
    local y = type(MimQoLDB) == "table" and tonumber(MimQoLDB.dungeonPortalY) or -180
    return math.max(-10000, math.min(10000, x)), math.max(-10000, math.min(10000, y))
end

local function place(panel)
    local x, y = position()
    panel:ClearAllPoints()
    panel:SetPoint("TOP", UIParent, "TOP", x, y)
end

local function closePreview()
    local wasMoving = moving
    moving = false
    if preview then
        preview:StopMovingOrSizing()
        preview:EnableMouse(false)
        preview:Hide()
    end
    if wasMoving and onMoving then onMoving(false) end
end

local function makePanel(secure)
    local panel = CreateFrame(secure and "Button" or "Frame", nil, UIParent,
        secure and "BackdropTemplate,SecureActionButtonTemplate" or "BackdropTemplate")
    panel:Hide()
    panel:SetSize(340, 76)
    place(panel)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.055, 0.055, 0.065, 0.96)
    panel:SetBackdropBorderColor(0.50, 0.42, 0.22, 1)
    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(44, 44)
    panel.icon:SetPoint("LEFT", 12, 0)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 68, -15)
    panel.title:SetWidth(245)
    panel.title:SetJustifyH("LEFT")
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.hint:SetPoint("TOPLEFT", 68, -42)
    panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.close:SetSize(24, 24)
    panel.close:SetPoint("TOPRIGHT", 0, 0)
    panel.close:SetScript("OnClick", function()
        if combat() and secure then return end
        if secure then dismissed = true; hideButton() else closePreview(); update() end
    end)
    return panel
end

update = function()
    if not ready then return end
    local inGroup = grouped()
    if wasGrouped and not inGroup then clearParty() end
    wasGrouped = inGroup
    if joinExpires and GetTime() > joinExpires then
        if not inGroup then clearParty() end
        joinExpires = nil
    end
    if enabled() then
        local hasActiveEntry = false
        if C_LFGList and type(C_LFGList.GetActiveEntryInfo) == "function" then
            local entry = C_LFGList.GetActiveEntryInfo()
            hasActiveEntry = not public(entry) or type(entry) == "table"
            local value = resolve(entry)
            -- A present listing with incomplete activity data must not keep an
            -- older destination clickable. A removed listing retains its cache.
            if public(entry) and type(entry) == "table" and value == nil then value = false end
            if public(entry) and type(entry) == "table" then joinedResult = nil end
            setDestination(value)
        end
        if not hasActiveEntry and joinedResult and not destination then
            setDestination(searchDestination(joinedResult))
        end
    end
    local count = type(GetNumGroupMembers) == "function" and GetNumGroupMembers(HOME)
    if public(count) and type(count) == "number" and count < 5 then dismissed = nil end
    -- The secure visibility driver hides the entire button during combat.
    -- All Lua UI changes wait, then recompute eligibility from current state.
    if combat() then return end
    if not eligible() or (preview and preview:IsShown()) then hideButton(); return end
    if not button then
        button = makePanel(true)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        button:SetScript("OnEnter", function(self)
            if GameTooltip and self.spellID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    place(button)
    local spellID = destination[1]
    local known = (type(IsPlayerSpell) == "function" and IsPlayerSpell(spellID))
        or (type(IsSpellKnown) == "function" and IsSpellKnown(spellID))
    known = public(known) and known == true
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    button.spellID = spellID
    button.title:SetText(destination[2] .. " 포탈")
    button.hint:SetText(known and "클릭하면 포탈을 시전합니다" or "아직 배우지 않은 포탈입니다")
    button.icon:SetTexture(info and info.iconID or 134400)
    button.icon:SetDesaturated(not known)
    button:SetAttribute("type1", known and "spell" or nil)
    button:SetAttribute("spell1", known and spellID or nil)
    if button.cooldown.Clear then button.cooldown:Clear() end
    if known and C_Spell and type(C_Spell.GetSpellCooldownDuration) == "function"
        and type(button.cooldown.SetCooldownFromDurationObject) == "function" then
        local duration = C_Spell.GetSpellCooldownDuration(spellID)
        if duration then button.cooldown:SetCooldownFromDurationObject(duration) end
    end
    if type(RegisterStateDriver) == "function" then
        RegisterStateDriver(button, "visibility", "[combat] hide; show")
    else
        button:Show()
    end
end

local events = { "GROUP_ROSTER_UPDATE", "GROUP_LEFT", "LFG_LIST_ACTIVE_ENTRY_UPDATE",
    "LFG_LIST_APPLICATION_STATUS_UPDATED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_LIST_JOINED_GROUP",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "SPELLS_CHANGED",
    "SPELL_UPDATE_COOLDOWN", "UNIT_SPELLCAST_SUCCEEDED" }

local function applySettings()
    if not ready then return end
    for _, event in ipairs(events) do
        if enabled() or event == "PLAYER_REGEN_ENABLED" then driver:RegisterEvent(event)
        else driver:UnregisterEvent(event) end
    end
    if not enabled() then
        clearParty()
        closePreview()
    end
    if preview then place(preview) end
    update()
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        ready, wasGrouped = true, grouped()
        applySettings()
        return
    elseif event == "GROUP_LEFT" then
        if arg1 == nil or arg1 == HOME then clearParty() end
    elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        clearParty()
    elseif event == "PLAYER_ENTERING_WORLD" then
        closePreview()
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        if public(arg1) and type(arg1) == "number" and public(arg2) then
            if arg2 == "applied" or arg2 == "invited" or arg2 == "inviteaccepted" then
                local value = searchDestination(arg1)
                if value ~= nil then applications[arg1] = value
                elseif applications[arg1] == nil then applications[arg1] = false end
            else applications[arg1] = nil end
        end
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        if public(arg1) and type(arg1) == "number" then
            if applications[arg1] ~= nil then
                local value = searchDestination(arg1)
                if value ~= nil then applications[arg1] = value end
            end
        end
    elseif event == "LFG_LIST_JOINED_GROUP" then
        if public(arg1) and type(arg1) == "number" then
            destination, dismissed = nil, nil
            joinedResult, joinExpires = arg1, GetTime() + 60
            local value = searchDestination(arg1)
            if value == nil then value = applications[arg1] end
            setDestination(value)
            applications = {}
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if public(arg1) and arg1 == "player" and public(arg3) and destination and arg3 == destination[1] then
            dismissed = true
        else return end
    end
    update()
end)

local function showPreview(move)
    if combat() then
        print("|cffffd100MimQoL:|r 포탈 미리보기와 위치 이동은 전투가 끝난 뒤 사용할 수 있습니다.")
        return false
    end
    hideButton()
    if not preview then
        preview = makePanel(false)
        preview:SetMovable(true)
        preview:RegisterForDrag("LeftButton")
        preview:SetScript("OnDragStart", function(self)
            if moving then self:StartMoving() end
        end)
        preview:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if not moving then return end
            local x = self:GetCenter()
            local top = self:GetTop()
            if x and top and UIParent:GetTop() then
                MimQoLDB.dungeonPortalX = math.floor(x - UIParent:GetWidth() / 2 + 0.5)
                MimQoLDB.dungeonPortalY = math.floor(top - UIParent:GetTop() + 0.5)
            end
            place(self)
            if onMoving then onMoving(true) end
        end)
    end
    place(preview)
    preview:EnableMouse(move)
    preview.title:SetText(move and "쐐기 던전 포탈 · 위치 이동" or "쐐기 던전 포탈 · 미리보기")
    preview.hint:SetText(move and "드래그하여 옮긴 뒤 '이동 완료'를 누르세요"
        or "실제 버튼은 배운 포탈을 클릭하여 시전합니다")
    preview.icon:SetTexture(135757)
    preview:Show()
    return true
end

_G.MimQoLDungeonPortal = {
    ApplySettings = applySettings,
    Preview = function()
        if preview and preview:IsShown() then closePreview(); update(); return end
        showPreview(false)
    end,
    -- The callback receives the current moving state after a drag or close.
    SetMoving = function(value, callback)
        if not value then closePreview(); update(); return false end
        if not showPreview(true) then return moving end
        moving, onMoving = true, callback
        return true
    end,
    IsMoving = function() return moving end,
    StopMoving = function()
        if moving then closePreview(); update() end
    end,
}
