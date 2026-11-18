-- Delayed greetings. Group identity and recipient membership are checked again
-- when each timer fires; roster refreshes alone never count as a new join.
local driver = CreateFrame("Frame")
local HOME = LE_PARTY_CATEGORY_HOME or 1
local INSTANCE = LE_PARTY_CATEGORY_INSTANCE or 2
local categories = { HOME, INSTANCE }
local groups = {}
local ready = false
local lastActiveCategory
local lastSent = -math.huge
local dungeonContext
local pendingEntry
local CHAT_RECHECK_INTERVAL = 0.5
local MAX_CHAT_LOCK_WAIT = 60
local MAX_JOIN_ROSTER_WAIT = 60
local FULL_PARTY_KEY = "autoGreetFullParty"

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function enabled(key)
    return type(MimQoLDB) == "table" and MimQoLDB.autoGreet == true
        and (not key or MimQoLDB[key] == true)
end

local function manualMode()
    return type(MimQoLDB) == "table" and MimQoLDB.greetManualMode == true
end

local function overlay(method, ...)
    local api = _G.MimQoLGreetingOverlay
    if api and type(api[method]) == "function" then api[method](...) end
end

local function bypassed()
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
end

local function chatLocked()
    local check = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    if type(check) == "function" then
        local ok, locked = pcall(check)
        -- The chat-specific lock can remain active outside player combat.
        -- A failed/unknown check is not permission to call the protected API.
        return not ok or isSecret(locked) or locked ~= false
    end
    if type(InCombatLockdown) == "function" then
        local locked = InCombatLockdown()
        return isSecret(locked) or locked
    end
    return false
end

local function groupType(category)
    if type(IsInRaid) == "function" and IsInRaid(category) then return "raid" end
    if type(IsInGroup) == "function" and IsInGroup(category) then return "party" end
    return "solo"
end

local function activeCategory()
    if groupType(INSTANCE) ~= "solo" then return INSTANCE end
    if groupType(HOME) ~= "solo" then return HOME end
end

local function hasRecipients(category)
    if type(GetNumGroupMembers) ~= "function" then return false end
    local count = GetNumGroupMembers(category)
    -- Finder listings can keep group state with only the player present.
    -- This roster count includes the player, but not their pet.
    return not isSecret(count) and type(count) == "number" and count > 1
end

local function npcGroup(category)
    if C_LFGInfo and type(C_LFGInfo.IsInLFGFollowerDungeon) == "function" then
        local follower = C_LFGInfo.IsInLFGFollowerDungeon()
        if isSecret(follower) or follower == true then return true end
    end
    if type(GetInstanceInfo) == "function" then
        local _, _, difficulty = GetInstanceInfo()
        local followerDifficulty = DifficultyUtil and DifficultyUtil.ID
            and DifficultyUtil.ID.FollowerDungeon or 205
        if isSecret(difficulty) or difficulty == followerDifficulty then return true end
    end
    -- Unit tokens refer to the active group only. Check fixed roster slots so
    -- NPC detection also works while subgroup counts are still loading.
    if category ~= activeCategory() then return true end
    local raid = groupType(category) == "raid"
    local humanCheck = type(UnitIsHumanPlayer) == "function" and UnitIsHumanPlayer or UnitIsPlayer
    for index = 1, raid and 40 or 4 do
        local unit = (raid and "raid" or "party") .. index
        if type(UnitInPartyIsAI) == "function" then
            local ai = UnitInPartyIsAI(unit)
            if isSecret(ai) or ai == true then return true end
        end
        if type(UnitIsNPCAsPlayer) == "function" then
            local npc = UnitIsNPCAsPlayer(unit)
            if isSecret(npc) or npc == true then return true end
        end
        if type(UnitExists) == "function" and type(humanCheck) == "function" then
            local exists = UnitExists(unit)
            if isSecret(exists) then return true end
            if exists then
                local human = humanCheck(unit)
                if isSecret(human) or human == false then return true end
            end
        end
    end
    return false
end

local function partyMembers(category)
    if type(GetNumSubgroupMembers) ~= "function"
        or type(UnitGUID) ~= "function" then return nil end
    local count = GetNumSubgroupMembers(category)
    if isSecret(count) or type(count) ~= "number" or count < 0 or count > 4 then
        return nil
    end
    -- The total can update before subgroup data during a real group join.
    if count == 0 and hasRecipients(category) then return nil end
    -- Keep an empty baseline so the first real applicant can be welcomed.
    local members = {}
    for index = 1, count do
        local guid = UnitGUID("party" .. index)
        -- An incomplete/secret roster must not erase a known baseline.
        if isSecret(guid) or type(guid) ~= "string" then return nil end
        members[guid] = true
    end
    return members
end

local function groupCount(category)
    if type(GetNumGroupMembers) ~= "function" then return end
    local count = GetNumGroupMembers(category)
    if not isSecret(count) and type(count) == "number" and count >= 0 then return count end
end

local function fullPartyEntryBaseline(group)
    if not group then return end
    -- Preserve an unresolved comparison across duplicate/late join events.
    if group.entryBaseline then return group.entryBaseline end
    if group.kind ~= "party" or group.pendingJoin or group.pending.autoGreetParty
        or group.pending.autoGreetRaid or not group.members then return end
    local count = 0
    for _ in pairs(group.members) do count = count + 1 end
    if count == 4 then return group.members end
end

local function sameMembers(left, right)
    for guid in pairs(left) do if not right[guid] then return false end end
    for guid in pairs(right) do if not left[guid] then return false end end
    return true
end

local function leadsHomeParty()
    if activeCategory() ~= HOME or groupType(HOME) ~= "party"
        or type(UnitIsGroupLeader) ~= "function" then return false end
    local leader = UnitIsGroupLeader("player", HOME)
    return not isSecret(leader) and leader == true
end

local function keystoneRunActive()
    if not C_ChallengeMode or type(C_ChallengeMode.IsChallengeModeActive) ~= "function" then return false end
    local active = C_ChallengeMode.IsChallengeModeActive()
    return isSecret(active) or active == true
end

local function mythicListingActivity()
    if not C_LFGList or type(C_LFGList.GetActiveEntryInfo) ~= "function"
        or type(C_LFGList.GetActivityInfoTable) ~= "function" then return end
    local entry = C_LFGList.GetActiveEntryInfo()
    if isSecret(entry) or type(entry) ~= "table" then return end
    local ids = entry.activityIDs
    if isSecret(ids) or type(ids) ~= "table" then return end
    local unknown = false
    for _, id in ipairs(ids) do
        if isSecret(id) or type(id) ~= "number" then return end
        local info = C_LFGList.GetActivityInfoTable(id)
        if isSecret(info) or type(info) ~= "table" or isSecret(info.isMythicPlusActivity) then
            unknown = true
        elseif info.isMythicPlusActivity == true then
            return id
        end
    end
    if not unknown then return false end -- A confirmed different activity cancels the notice.
end

local function ownedKeystoneLink()
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemLink) ~= "function" then return end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        if not isSecret(slots) and type(slots) == "number" and slots >= 0 and slots <= 100 then
            for slot = 1, slots do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if not isSecret(link) and type(link) == "string"
                    and link:match("|Hkeystone:[^|]+|h%[.-%]|h") then return link end
            end
        end
    end
end

local function messageText(key, maxBytes)
    local text = MimQoLDB and MimQoLDB[key .. "Message"]
    if isSecret(text) or type(text) ~= "string" then return "" end
    text = text:gsub("[%c]", " "):match("^%s*(.-)%s*$")
    -- Chat has a byte limit. Never split a Korean (UTF-8) character.
    maxBytes = maxBytes or 255
    if #text > maxBytes then
        local cut = maxBytes + 1
        while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do
            cut = cut - 1
        end
        text = text:sub(1, cut - 1)
    end
    return text
end

local function delaySeconds(key)
    local value = MimQoLDB and MimQoLDB[key .. "Delay"]
    if isSecret(value) then return 3 end
    local delay = tonumber(value)
    if not delay or delay ~= delay then return 3 end
    return math.max(0, math.min(60, delay))
end

local function queueGreeting(category, key, newcomers)
    if not enabled(key) or bypassed() or not hasRecipients(category) or npcGroup(category) or messageText(key) == ""
        or not C_Timer or type(C_Timer.After) ~= "function" then return end
    local group = groups[category]
    if key == FULL_PARTY_KEY and (not leadsHomeParty() or groupCount(HOME) ~= 5 or keystoneRunActive()
        or not group.keystoneActivity) then return end
    local existing = group.pending[key]
    if existing then
        for guid in pairs(newcomers or {}) do existing.newcomers[guid] = true end
        return
    end
    local delay = delaySeconds(key)
    local job = { kind = group.kind, newcomers = newcomers or {},
        expiresAt = GetTime() + delay + MAX_CHAT_LOCK_WAIT,
        entryBaseline = key == "autoGreetParty" and group.entryBaseline or nil,
        keystoneActivity = key == FULL_PARTY_KEY and group.keystoneActivity or nil }
    group.pending[key] = job
    local function send()
        if group.pending[key] ~= job then return end
        if GetTime() >= job.expiresAt or not enabled(key) or bypassed() or activeCategory() ~= category
            or groupType(category) ~= job.kind or not hasRecipients(category) or npcGroup(category) then
            group.pending[key] = nil
            return
        end
        if job.entryBaseline then
            local members = partyMembers(category)
            -- Loading unit data cannot establish that these are new recipients.
            if not members then C_Timer.After(CHAT_RECHECK_INTERVAL, send); return end
            local same = sameMembers(job.entryBaseline, members)
            job.entryBaseline, group.entryBaseline = nil, nil
            if same then group.pending[key] = nil; return end
        end
        if key == FULL_PARTY_KEY then
            local activity = mythicListingActivity()
            if not leadsHomeParty() or groupCount(HOME) ~= 5 or group.completed or keystoneRunActive()
                or group.keystoneActivity ~= job.keystoneActivity
                or (activity ~= nil and activity ~= job.keystoneActivity) then
                group.pending[key] = nil
                return
            end
        end
        -- Do not try SendChatMessage (even inside pcall) while locked: the
        -- client reports a blocked-action event rather than a Lua exception.
        -- Recheck only while this job is pending, so no permanent polling runs.
        if chatLocked() then
            C_Timer.After(CHAT_RECHECK_INTERVAL, send)
            return
        end
        if key == "autoGreetWelcome" then
            local members = partyMembers(category)
            local stillHere = false
            for guid in pairs(job.newcomers) do
                if members and members[guid] then stillHere = true; break end
            end
            if not stillHere then group.pending[key] = nil; return end
        end
        -- Space overlapping situations without silently dropping a greeting.
        local wait = lastSent + 1 - GetTime()
        if wait > 0 then C_Timer.After(wait, send); return end
        local text = messageText(key)
        if text == "" then group.pending[key] = nil; return end
        if key == FULL_PARTY_KEY then
            local link = ownedKeystoneLink()
            if not link then C_Timer.After(CHAT_RECHECK_INTERVAL, send); return end
            -- Keep the real clickable link intact; only shorten the custom text.
            if #link >= 254 then group.pending[key] = nil; return end
            text = link .. " " .. messageText(key, 255 - #link - 1)
        end
        group.pending[key] = nil
        local sendChat = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        if type(sendChat) ~= "function" then return end
        local channel = category == INSTANCE and "INSTANCE_CHAT"
            or (job.kind == "raid" and "RAID" or "PARTY")
        sendChat(text, channel)
        lastSent = GetTime()
    end
    C_Timer.After(delay, send)
end

local function updateFullParty(baseline)
    local group = groups[HOME]
    local count = groupCount(HOME)
    if not count then return end
    local previous = group.fullPartyCount
    group.fullPartyCount = count
    if not leadsHomeParty() or not enabled(FULL_PARTY_KEY) or group.completed or keystoneRunActive() then
        group.keystoneActivity, group.fullPartyWaiting = nil, nil
        group.pending[FULL_PARTY_KEY] = nil
        return
    end
    local activity = mythicListingActivity()
    -- Keep the observed Mythic+ activity if the listing disappears when full.
    -- A different listing, loss of leadership, leaving, or starting the run clears it.
    if activity ~= nil then group.keystoneActivity = activity or nil end
    if baseline or count ~= 5 then
        group.fullPartyWaiting = nil
        group.pending[FULL_PARTY_KEY] = nil
        return
    end
    if previous and previous < 5 then
        group.fullPartyWaiting = activity ~= false and not bypassed()
            and (GetTime() + MAX_JOIN_ROSTER_WAIT) or nil
    end
    if group.fullPartyWaiting then
        if bypassed() or GetTime() >= group.fullPartyWaiting then
            group.fullPartyWaiting = nil
        elseif group.keystoneActivity then
            group.fullPartyWaiting = nil
            queueGreeting(HOME, FULL_PARTY_KEY)
        end
    end
end

local function resetGroup(category)
    local group = groups[category]
    group.kind, group.members, group.guid = "solo", nil, nil
    group.entryBaseline = nil
    group.pendingJoin = nil
    group.pending = {}
    group.completed = false
    group.fullPartyCount = 0
    group.keystoneActivity, group.fullPartyWaiting = nil, nil
end

for _, category in ipairs(categories) do
    groups[category] = {}
    resetGroup(category)
end

local function snapshot()
    local active = activeCategory()
    lastActiveCategory = active
    for _, category in ipairs(categories) do
        local group = groups[category]
        group.pending = {}
        group.pendingJoin = nil
        group.entryBaseline = nil
        group.fullPartyCount, group.fullPartyWaiting = groupCount(category), nil
        group.kind = groupType(category)
        group.members = category == active and group.kind == "party"
            and partyMembers(category) or nil
    end
    updateFullParty(true)
end

local function finishPendingJoin(category, members)
    local group = groups[category]
    local join = group.pendingJoin
    if not join then return false end
    local roleUnknown = false
    if category == HOME and type(UnitIsGroupLeader) == "function" then
        local leader = UnitIsGroupLeader("player", category)
        roleUnknown = isSecret(leader) or type(leader) ~= "boolean"
        if not roleUnknown and leader == true then
            -- Our own finder listing: the first applicant gets the normal
            -- welcome instead of treating us as a guest joining their party.
            group.pendingJoin = nil
            return false
        end
    end
    if GetTime() >= join.expiresAt then
        group.pendingJoin, group.members = nil, members
        return true
    end
    if not hasRecipients(category) or roleUnknown then return true end
    -- GROUP_JOINED/IsInGroup may arrive before the recipient count. Keep the
    -- self-join until it can be queued, and baseline the existing party members
    -- so they are not mistaken for newcomers on the next roster refresh.
    group.pendingJoin, group.members = nil, members
    if not join.bypassed then queueGreeting(category, "autoGreetParty") end
    return true
end

local function updateRoster()
    if not ready then return end
    local active = activeCategory()
    if active and active ~= lastActiveCategory and groups[active].kind == "solo" then
        -- The same full premade can acquire an instance category. Capture the
        -- old roster before inactive-group cleanup loses its unit baseline.
        groups[active].entryBaseline = groups[active].entryBaseline
            or fullPartyEntryBaseline(groups[lastActiveCategory])
    end
    lastActiveCategory = active
    for _, category in ipairs(categories) do
        local group = groups[category]
        local kind = groupType(category)
        local members = category == active and kind == "party"
            and partyMembers(category) or nil
        if kind ~= group.kind then
            local wasSolo = group.kind == "solo"
            local deferredJoin = group.pendingJoin
            local hadJoin = deferredJoin or group.pending.autoGreetParty or group.pending.autoGreetRaid
            group.pending = {}
            group.pendingJoin = nil
            group.kind, group.members = kind, members
            if kind == "solo" then
                resetGroup(category)
            elseif category == active and (wasSolo or hadJoin) then
                if kind == "party" and not hasRecipients(category) then
                    group.pendingJoin = deferredJoin or {
                        bypassed = bypassed(), expiresAt = GetTime() + MAX_JOIN_ROSTER_WAIT,
                    }
                elseif not deferredJoin or (not deferredJoin.bypassed and GetTime() < deferredJoin.expiresAt) then
                    queueGreeting(category, kind == "raid" and "autoGreetRaid" or "autoGreetParty")
                end
            end
        elseif category ~= active then
            -- Unit tokens describe only the active group. Rebaseline on return.
            group.pending, group.members, group.pendingJoin = {}, nil, nil
        elseif kind == "party" and not finishPendingJoin(category, members) and members then
            if group.members then
                local newcomers = {}
                for guid in pairs(members) do
                    if not group.members[guid] then newcomers[guid] = true end
                end
                if next(newcomers) then queueGreeting(category, "autoGreetWelcome", newcomers) end
            end
            group.members = members
        end
    end
    updateFullParty()
end

local function dungeonInfo()
    if type(GetInstanceInfo) ~= "function" then return end
    local _, kind, difficulty, _, _, _, _, mapID = GetInstanceInfo()
    if isSecret(kind) or isSecret(difficulty) or isSecret(mapID)
        or kind ~= "party" or type(difficulty) ~= "number"
        or type(mapID) ~= "number" or mapID <= 0 then return end
    return mapID, difficulty
end

local function refreshDungeonContext()
    local mapID, difficulty = dungeonInfo()
    local context = mapID and (mapID .. ":" .. difficulty) or nil
    if context ~= dungeonContext then
        dungeonContext = context
        pendingEntry = nil
        overlay("Dismiss")
        for _, group in pairs(groups) do
            group.completed = false
            group.pending.autoGreetComplete = nil
        end
        return context ~= nil
    end
    return false
end

local function promptEntry()
    if not pendingEntry then return end
    if not manualMode() or bypassed() or pendingEntry ~= dungeonContext then
        pendingEntry = nil
        return
    end
    local active = activeCategory()
    if active and groupType(active) == "party" then
        pendingEntry = nil
        overlay("Prompt", "entry")
    end
end

local function completeDungeon()
    refreshDungeonContext()
    updateRoster()
    local active = activeCategory()
    local group = active and groups[active]
    if group and group.kind == "party" and not group.completed then
        group.completed = true
        group.keystoneActivity, group.fullPartyWaiting = nil, nil
        group.pending[FULL_PARTY_KEY] = nil
        pendingEntry = nil
        if manualMode() and not bypassed() then
            overlay("Prompt", "complete")
        end
        queueGreeting(active, "autoGreetComplete")
    end
end

local function ordinaryDungeonMap()
    local mapID, difficulty = dungeonInfo()
    if not mapID or difficulty == 8 then return end
    if type(GetDifficultyInfo) == "function" then
        local _, _, _, challenge = GetDifficultyInfo(difficulty)
        if isSecret(challenge) or challenge then return end
    end
    if C_ChallengeMode and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
        local active = C_ChallengeMode.IsChallengeModeActive()
        if isSecret(active) or active then return end
    end
    return mapID
end

local function isFinalDungeonEncounter(mapID, encounterID)
    if isSecret(encounterID) or type(encounterID) ~= "number" then return false end
    local getJournal = C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap
        or EJ_GetInstanceForMap
    if type(getJournal) ~= "function"
        or type(EJ_GetEncounterInfoByIndex) ~= "function" then return false end
    local journalID = getJournal(mapID)
    if isSecret(journalID) or type(journalID) ~= "number" or journalID <= 0 then
        return false
    end
    -- Read the instance's ordered boss list without changing the open journal's
    -- instance/difficulty selection. Match encounter IDs, never localized names.
    local finalEncounter
    for index = 1, 32 do
        local _, _, bossID, _, _, _, dungeonEncounterID =
            EJ_GetEncounterInfoByIndex(index, journalID)
        if isSecret(bossID) or isSecret(dungeonEncounterID) then return false end
        if not bossID or bossID == 0 then return finalEncounter == encounterID end
        if type(dungeonEncounterID) ~= "number" or dungeonEncounterID <= 0 then return false end
        finalEncounter = dungeonEncounterID
    end
    return false
end

local function applySettings()
    driver:UnregisterAllEvents()
    snapshot()
    if not manualMode() then pendingEntry = nil end
    overlay("ApplySettings")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    if not enabled() and not manualMode() then return end
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("GROUP_JOINED")
    driver:RegisterEvent("GROUP_LEFT")
    if enabled(FULL_PARTY_KEY) then
        driver:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        driver:RegisterEvent("PARTY_LEADER_CHANGED")
    end
    driver:RegisterEvent("CHALLENGE_MODE_START")
    driver:RegisterEvent("CHALLENGE_MODE_RESET")
    driver:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    driver:RegisterEvent("LFG_COMPLETION_REWARD")
    driver:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
    driver:RegisterEvent("ENCOUNTER_END")
end

driver:SetScript("OnEvent", function(_, event, category, guid, difficulty, size, success)
    if event == "PLAYER_LOGIN" then
        applySettings()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local entered = refreshDungeonContext()
        overlay("ApplySettings")
        if not ready or category or guid then
            -- The first two payload values are initialLogin / reloadingUI.
            ready = true
            pendingEntry = nil
            snapshot()
        else
            updateRoster()
            if entered and manualMode() and not bypassed() then
                pendingEntry = dungeonContext
                promptEntry()
            end
        end
    elseif ready then
        if event == "GROUP_LEFT" then
            pendingEntry = nil
            if not isSecret(category) and groups[category] then
                local active = activeCategory()
                if category == lastActiveCategory and active and active ~= category
                    and groups[active].kind == "solo" then
                    groups[active].entryBaseline = fullPartyEntryBaseline(groups[category])
                end
                resetGroup(category)
            end
            overlay("Dismiss")
            overlay("ApplySettings")
        elseif event == "GROUP_JOINED" then
            if isSecret(category) or isSecret(guid) then return end
            local group = groups[category]
            if group and type(guid) == "string" then
                if group.guid and group.guid ~= guid then
                    local baseline = fullPartyEntryBaseline(group)
                    resetGroup(category)
                    group.entryBaseline = baseline
                end
                group.guid = guid
            end
            updateRoster()
            overlay("ApplySettings")
            promptEntry()
        elseif event == "GROUP_ROSTER_UPDATE" then
            updateRoster()
            promptEntry()
            local active = activeCategory()
            if not active or groupType(active) ~= "party" then overlay("Dismiss") end
        elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "PARTY_LEADER_CHANGED" then
            updateRoster()
        elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET"
            or event == "LFG_PROPOSAL_SUCCEEDED" then
            -- A group may queue for the same dungeon again without disbanding
            -- or visiting a different map between runs.
            for _, group in pairs(groups) do
                group.completed = false
                group.pending.autoGreetComplete = nil
                group.pending[FULL_PARTY_KEY] = nil
                group.keystoneActivity, group.fullPartyWaiting = nil, nil
            end
            overlay("Dismiss")
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            completeDungeon()
        elseif event == "LFG_COMPLETION_REWARD" then
            if ordinaryDungeonMap() then completeDungeon() end
        elseif event == "ENCOUNTER_END" then
            if isSecret(success) or success ~= 1 then return end
            local mapID = ordinaryDungeonMap()
            if mapID and isFinalDungeonEncounter(mapID, category) then
                completeDungeon()
            end
        end
    end
end)
driver:RegisterEvent("PLAYER_LOGIN")

_G.MimQoLAutoGreet_ApplySettings = applySettings
