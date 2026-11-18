-- Run from the addon directory with Lua or Fengari. No real chat is sent.
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local now, frames, timers, messages, roster, shift, dungeon, combat, chatLock
local unitTraits
local secret = setmetatable({}, {
    __eq = function() error("secret comparison") end,
    __lt = function() error("secret comparison") end,
    __tostring = function() error("secret conversion") end,
})
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
function issecretvalue(value) return rawequal(value, secret) end
function GetTime() return now end
function IsShiftKeyDown() return shift end
function InCombatLockdown() return combat end
local function inChatMessagingLockdown()
    if type(chatLock) == "string" and chatLock == "error" then error("lock check unavailable") end
    return chatLock
end
function GetInstanceInfo()
    return "Test Dungeon", dungeon.kind or "none", dungeon.difficulty or 0,
        "Difficulty", 5, 0, false, dungeon.mapID or 0
end
function GetDifficultyInfo(difficulty)
    return "Difficulty", "party", false, difficulty == 8 or dungeon.challengeDifficulty
end
C_ChallengeMode = { IsChallengeModeActive = function() return dungeon.activeKey end }
C_EncounterJournal = { GetInstanceForGameMap = function(mapID)
    check(mapID == dungeon.mapID, "journal must use current map")
    return dungeon.journalID
end }
function EJ_GetEncounterInfoByIndex(index, journalID)
    check(journalID == dungeon.journalID, "read journal by explicit instance ID")
    local encounter = dungeon.bosses and dungeon.bosses[index]
    if encounter then return "Boss", "", index + 500, nil, nil, journalID, encounter end
    return nil, nil, dungeon.zeroTerminator and 0 or nil
end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(key, callback) self.scripts[key] = callback end
    frames[#frames + 1] = frame
    return frame
end
function IsInGroup(category) return roster[category or (roster[2] and 2 or 1)] ~= nil end
function IsInRaid(category)
    local group = roster[category or (roster[2] and 2 or 1)]
    return group and group.kind == "raid" or false
end
function UnitIsGroupLeader(unit, category)
    assert(unit == "player", "only inspect the player's group role")
    local current = roster[category]
    return current and current.leader or false
end
function GetNumSubgroupMembers(category)
    local group = roster[category or (roster[2] and 2 or 1)]
    return group and (group.count or #group.members) or 0
end
function GetNumGroupMembers(category)
    local group = roster[category or (roster[2] and 2 or 1)]
    if not group then return 0 end
    if group.total ~= nil then return group.total end
    return (group.count or #group.members) + 1
end
function UnitGUID(unit)
    if unit == "player" then return "Player-Self" end
    if unit == "pet" then return "Pet-Self" end
    local group = roster[roster[2] and 2 or 1]
    local index = tonumber(unit:match("%d+"))
    return group and group.members[index]
end
local function unitTrait(unit, key, default)
    local traits = unitTraits[unit]
    if traits and traits[key] ~= nil then return traits[key] end
    return default
end
local function unitExists(unit) return UnitGUID(unit) ~= nil end
local function unitIsHuman(unit) return unitTrait(unit, "human", true) end
local function unitIsPlayer(unit) return unitTrait(unit, "player", true) end
local function unitIsAI(unit) return unitTrait(unit, "ai", false) end
local function unitIsNPC(unit) return unitTrait(unit, "npc", false) end
local function inFollowerDungeon() return dungeon.follower or false end
local function sendChat(text, channel)
    assert(not issecretvalue(chatLock) and chatLock == false,
        "protected chat was called during chat lockdown")
    if not C_ChatInfo.InChatMessagingLockdown then
        assert(not combat, "protected chat was called during fallback combat lockdown")
    end
    messages[#messages + 1] = { text = text, channel = channel, time = now }
end
SendChatMessage = function() error("modern chat API should take priority") end
C_ChatInfo = { SendChatMessage = sendChat, InChatMessagingLockdown = inChatMessagingLockdown }
C_Timer = { After = function(delay, callback)
    assert(delay >= 0 and delay <= 60, "invalid timer delay")
    timers[#timers + 1] = { time = now + delay, callback = callback }
end }
local function fire(event, ...)
    local frame = frames[1]
    if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
end
local function advance(seconds)
    local target = now + seconds
    while true do
        local chosen
        for index, timer in ipairs(timers) do
            if timer.time <= target and (not chosen or timer.time < timers[chosen].time) then
                chosen = index
            end
        end
        if not chosen then break end
        local timer = table.remove(timers, chosen)
        now = timer.time
        timer.callback()
    end
    now = target
end
local function group(kind, ...)
    return { kind = kind, members = { ... } }
end
local function reset(home, instance, disabled)
    now, shift = 100, false
    combat, chatLock = false, false
    C_ChatInfo.InChatMessagingLockdown = inChatMessagingLockdown
    dungeon = {}
    unitTraits = {}
    UnitExists, UnitIsHumanPlayer, UnitIsPlayer = unitExists, unitIsHuman, unitIsPlayer
    UnitInPartyIsAI, UnitIsNPCAsPlayer = unitIsAI, unitIsNPC
    C_LFGInfo = { IsInLFGFollowerDungeon = inFollowerDungeon }
    DifficultyUtil = nil
    frames, timers, messages, roster = {}, {}, {}, { [1] = home, [2] = instance }
    MimQoLDB = { autoGreet = not disabled }
    for _, key in ipairs({ "Party", "Raid", "Welcome", "Complete" }) do
        MimQoLDB["autoGreet" .. key] = true
        MimQoLDB["autoGreet" .. key .. "Delay"] = 3
    end
    MimQoLDB.autoGreetPartyMessage = "안녕하세요"
    MimQoLDB.autoGreetRaidMessage = "안녕하세요"
    MimQoLDB.autoGreetWelcomeMessage = "어서오세요"
    MimQoLDB.autoGreetCompleteMessage = "수고하셨습니다"
    assert(loadfile("AutoGreet.lua"))("MimQoL")
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD", true, false)
end
local function join(kind, ...)
    roster[1] = group(kind, ...)
    fire("GROUP_JOINED", 1, "Party-A")
    fire("GROUP_ROSTER_UPDATE")
end
local function expect(count, text, channel, label)
    check(#messages == count, label .. ": message count " .. #messages)
    if text then
        check(messages[count].text == text, label .. ": text")
        check(messages[count].channel == channel, label .. ": channel")
    end
end

-- A finder listing can retain group state with only the player and their pet.
for _, category in ipairs({ 1, 2 }) do
    for _, kind in ipairs({ "party", "raid" }) do
        reset()
        roster[category] = group(kind)
        check(UnitGUID("pet") == "Pet-Self", "pet is present in solo listing")
        fire("GROUP_JOINED", category, "Solo-Listing")
        fire("GROUP_ROSTER_UPDATE")
        advance(5)
        expect(0, nil, nil, "solo listing must not greet: " .. category .. kind)
        check(#timers == 0, "solo listing must not queue chat")
    end
end

reset()
join("party")
roster[1].leader = true -- Own finder listing, then another player joins it.
advance(5)
roster[1].members[1] = "A"
fire("GROUP_ROSTER_UPDATE")
advance(2.9)
expect(0, nil, nil, "first applicant welcome respects delay")
advance(0.1)
expect(1, "어서오세요", "PARTY", "first real applicant is welcomed once")
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(1, nil, nil, "first applicant roster refresh does not repeat welcome")

reset()
join("party")
roster[1].leader = true
advance(90)
roster[1].members = { "Applicant" }
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "어서오세요", "PARTY", "own listing still welcomes its first applicant after a long wait")

reset()
roster[1] = { kind = "party", members = {}, count = 0, total = 2 }
fire("GROUP_JOINED", 1, "Loading-Group")
roster[1].count = nil
roster[1].members = { "A" }
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(1, "안녕하세요", "PARTY", "delayed subgroup count does not double greet")

-- Joining someone else's party can precede both total and subgroup counts.
for _, category in ipairs({ 1, 2 }) do
    for _, initialCount in ipairs({ 0, 1, secret, "unknown" }) do
        reset()
        MimQoLDB.autoGreetPartyDelay = 6
        roster[category] = group("party")
        roster[category].total = initialCount
        fire("GROUP_JOINED", category, "Loading-Party")
        fire("GROUP_ROSTER_UPDATE")
        advance(1)
        check(#timers == 0, "wait for recipients before scheduling entry chat")
        roster[category].members = { "Leader", "A", "B", "C" }
        roster[category].total = nil
        fire("GROUP_ROSTER_UPDATE")
        fire("GROUP_JOINED", category, "Loading-Party")
        advance(5.9)
        expect(0, nil, nil, "delayed self join preserves configured delay")
        advance(0.1)
        expect(1, "안녕하세요", category == 2 and "INSTANCE_CHAT" or "PARTY",
            "delayed self join greets existing members, not welcomes them")
        fire("GROUP_ROSTER_UPDATE")
        advance(10)
        expect(1, nil, nil, "delayed self join is handled only once")
    end
end

for _, cancel in ipairs({ "Shift", "party disabled", "disabled", "reload", "leave", "expired" }) do
    reset()
    shift = cancel == "Shift"
    if cancel == "party disabled" then MimQoLDB.autoGreetParty = false end
    join("party")
    shift = false
    if cancel == "disabled" then
        MimQoLDB.autoGreet = false
        MimQoLAutoGreet_ApplySettings()
    elseif cancel == "reload" then
        fire("PLAYER_ENTERING_WORLD", false, true)
    elseif cancel == "leave" then
        roster[1] = nil
        fire("GROUP_LEFT", 1, "Party-A")
    elseif cancel == "expired" then
        advance(61)
    end
    if roster[1] then
        roster[1].members = { "Leader", "A" }
        fire("GROUP_ROSTER_UPDATE")
    end
    advance(10)
    -- Reload rebaselines the group: test only that it does not greet our join.
    for _, message in ipairs(messages) do
        check(message.text ~= "안녕하세요", "cancel delayed self join: " .. cancel)
    end
    if cancel ~= "reload" then
        expect(0, nil, nil, "do not misclassify cancelled self join as welcome: " .. cancel)
    end
end

reset()
join("party")
roster[1].total = 5 -- The recipient count can arrive before any UnitGUIDs.
fire("GROUP_ROSTER_UPDATE")
roster[1].members = { "Leader", "A", "B", "C" }
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "안녕하세요", "PARTY", "total count before unit data still greets once")

reset()
join("party")
roster[1].members = { "Leader", "A" }
roster[1].leader = secret
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(0, nil, nil, "secret leader state cannot classify the delayed join")
roster[1].leader = false
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "안녕하세요", "PARTY", "delayed join resumes when role is readable")

reset()
join("party")
chatLock = true
roster[1].members = { "Leader", "A" }
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(0, nil, nil, "delayed join still respects chat lockdown")
chatLock = false
advance(0.5)
expect(1, "안녕하세요", "PARTY", "delayed join resumes after chat unlock")

reset()
join("party")
roster[1].kind, roster[1].members = "raid", { "Leader", "A" }
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "안녕하세요", "RAID", "deferred self join follows party to raid conversion")

for _, key in ipairs({ "Party", "Raid", "Welcome", "Complete" }) do
    reset((key == "Welcome" or key == "Complete") and group("party", "A") or nil)
    if key == "Party" then join("party", "A")
    elseif key == "Raid" then join("raid", "A")
    elseif key == "Welcome" then
        roster[1].members[2] = "B"; fire("GROUP_ROSTER_UPDATE")
    else fire("CHALLENGE_MODE_COMPLETED") end
    -- The group can persist after everyone leaves, before a roster event arrives.
    roster[1].members = {}
    advance(5)
    expect(0, nil, nil, "send time rejects player-only group: " .. key)
    check(#timers == 0, "player-only group cancels pending chat: " .. key)
end

reset(group("party"))
fire("CHALLENGE_MODE_COMPLETED")
advance(5)
expect(0, nil, nil, "solo party completion must not greet")

for _, count in ipairs({ 0, 1, secret, "unknown", 0/0 }) do
    reset()
    roster[1] = group("party", "A")
    roster[1].total = count
    fire("GROUP_JOINED", 1, "Unconfirmed-Group")
    advance(5)
    expect(0, nil, nil, "unconfirmed group count must not greet")
end

reset()
join("party", "A", "B")
advance(2.9)
expect(0, nil, nil, "party delay")
advance(0.1)
expect(1, "안녕하세요", "PARTY", "self party join")
fire("GROUP_ROSTER_UPDATE")
fire("GROUP_JOINED", 1, "Party-A")
advance(10)
expect(1, nil, nil, "duplicate join events")

reset()
MimQoLDB.autoGreetRaidMessage = "반갑습니다!"
MimQoLDB.autoGreetRaidDelay = 7.5
join("raid", "A", "B")
advance(7.4)
expect(0, nil, nil, "custom raid delay")
advance(0.1)
expect(1, "반갑습니다!", "RAID", "custom raid greeting")
roster[1].members[3] = "C"
fire("GROUP_ROSTER_UPDATE")
advance(10)
expect(1, nil, nil, "other raid joins ignored")

reset(group("party", "A", "B"))
fire("PLAYER_ENTERING_WORLD", false, true)
fire("PLAYER_ENTERING_WORLD", false, false)
roster[1].members = { "B", "A" }
fire("GROUP_ROSTER_UPDATE")
advance(10)
expect(0, nil, nil, "login reload zoning roster reorder")
roster[1].kind = "raid"
fire("GROUP_ROSTER_UPDATE")
advance(5)
roster[1].kind = "party"
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(0, nil, nil, "party raid conversions")

reset()
join("party", "A")
advance(1)
roster[1].kind = "raid"
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "안녕하세요", "RAID", "pending join follows conversion")

reset(group("party", "A"))
MimQoLDB.autoGreetWelcomeMessage = "어서 오세요 :)"
MimQoLDB.autoGreetWelcomeDelay = 4
roster[1].members = { "A", "B" }
fire("GROUP_ROSTER_UPDATE")
advance(1)
roster[1].members[3] = "C"
fire("GROUP_ROSTER_UPDATE")
advance(2.9)
expect(0, nil, nil, "welcome delay")
advance(0.1)
expect(1, "어서 오세요 :)", "PARTY", "coalesced welcomes")
roster[1].members = { "A", "D", "C" }
fire("GROUP_ROSTER_UPDATE")
advance(4)
expect(2, "어서 오세요 :)", "PARTY", "same size replacement")
roster[1].members = { "A" }
fire("GROUP_ROSTER_UPDATE")
advance(4)
expect(2, nil, nil, "departures ignored")

reset(group("party", "A"))
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(1)
roster[1].members[2] = nil
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(0, nil, nil, "departed newcomer")

reset(group("party", "A"))
MimQoLDB.autoGreetCompleteMessage = "모두 고생하셨어요!"
MimQoLDB.autoGreetCompleteDelay = 6
fire("CHALLENGE_MODE_COMPLETED")
fire("CHALLENGE_MODE_COMPLETED_REWARDS")
advance(5.9)
expect(0, nil, nil, "completion delay")
advance(0.1)
expect(1, "모두 고생하셨어요!", "PARTY", "completion text")
fire("CHALLENGE_MODE_COMPLETED")
advance(20)
expect(1, nil, nil, "completion duplicate after long interval")
fire("CHALLENGE_MODE_START")
fire("CHALLENGE_MODE_COMPLETED")
advance(6)
expect(2, nil, nil, "next run completion")
fire("CHALLENGE_MODE_START")
fire("CHALLENGE_MODE_COMPLETED")
fire("CHALLENGE_MODE_RESET")
advance(6)
expect(2, nil, nil, "reset cancels completion")

for _, kind in ipairs({ "solo", "raid" }) do
    reset(kind == "raid" and group("raid", "A") or nil)
    fire("CHALLENGE_MODE_COMPLETED")
    advance(10)
    expect(0, nil, nil, "completion outside party: " .. kind)
end

reset()
MimQoLDB.autoGreetPartyMessage = "  안녕! 즐겁게 해봐요.  "
join("party", "A")
advance(3)
expect(1, "안녕! 즐겁게 해봐요.", "PARTY", "custom party text")

reset()
join("party", "A")
advance(1)
roster[1] = nil
fire("GROUP_LEFT", 1, "Party-A")
roster[1] = group("party", "B")
fire("GROUP_JOINED", 1, "Party-B")
advance(2)
expect(0, nil, nil, "old group timer invalidated")
advance(1)
expect(1, "안녕하세요", "PARTY", "new group timer")

reset()
join("party", "A")
advance(1)
roster[1] = group("party", "B")
fire("GROUP_JOINED", 1, "Party-B")
advance(2)
expect(0, nil, nil, "same kind new group identity")
advance(1)
expect(1, nil, nil, "new identity greets once")

reset()
join("party", "A")
roster[1] = nil -- Also revalidate when the leave event has not arrived yet.
advance(5)
expect(0, nil, nil, "send time group check")

reset()
join("party", "A")
MimQoLDB.autoGreet = false
MimQoLAutoGreet_ApplySettings()
check(not frames[1].events.GROUP_ROSTER_UPDATE, "disabled roster event")
check(not frames[1].events.CHALLENGE_MODE_COMPLETED, "disabled completion event")
MimQoLDB.autoGreet = true
MimQoLAutoGreet_ApplySettings()
advance(5)
expect(0, nil, nil, "disable reenable cancels pending and rebaselines")

reset(nil, nil, true)
join("party", "A")
MimQoLDB.autoGreet = true
MimQoLAutoGreet_ApplySettings()
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "어서오세요", "PARTY", "enable after disabled login")

for _, key in ipairs({ "autoGreetParty", "autoGreetRaid", "autoGreetWelcome", "autoGreetComplete" }) do
    if key == "autoGreetWelcome" or key == "autoGreetComplete" then
        reset(group("party", "A"))
    else
        reset()
    end
    MimQoLDB[key] = false
    if key == "autoGreetParty" then join("party", "A")
    elseif key == "autoGreetRaid" then join("raid", "A")
    elseif key == "autoGreetWelcome" then
        roster[1].members[2] = "B"; fire("GROUP_ROSTER_UPDATE")
    else fire("CHALLENGE_MODE_COMPLETED") end
    advance(10)
    expect(0, nil, nil, "scenario disabled: " .. key)
end

reset()
shift = true
join("party", "A")
shift = false
advance(5)
expect(0, nil, nil, "Shift at trigger")
reset()
join("party", "A")
shift = true
advance(5)
expect(0, nil, nil, "Shift at send")

reset(group("party", "A"))
roster[1].members = { secret }
fire("GROUP_ROSTER_UPDATE")
roster[1].members = { "A" }
fire("GROUP_ROSTER_UPDATE")
roster[1].count = 2 -- Delayed UnitGUID data.
fire("GROUP_ROSTER_UPDATE")
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(1, "어서오세요", "PARTY", "secret and incomplete rosters preserve baseline")

reset()
roster[1] = { kind = "party", members = {}, count = 2 }
fire("GROUP_ROSTER_UPDATE")
roster[1].members = { "A", "B" }
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(1, "안녕하세요", "PARTY", "initial incomplete roster does not welcome existing members")

reset(group("party", "Home-A"))
roster[2] = group("party", "Instance-A")
fire("GROUP_JOINED", 2, "Instance-Group")
advance(3)
expect(1, "안녕하세요", "INSTANCE_CHAT", "instance party channel")
roster[2] = nil
fire("GROUP_LEFT", 2, "Instance-Group")
fire("GROUP_ROSTER_UPDATE")
advance(5)
expect(1, nil, nil, "return to home group does not regreet")

reset()
roster[2] = group("raid", "A")
fire("GROUP_JOINED", 2, "Instance-Raid")
advance(3)
expect(1, "안녕하세요", "INSTANCE_CHAT", "instance raid channel")

reset(group("party", "A"))
MimQoLDB.autoGreetWelcomeDelay = 0
MimQoLDB.autoGreetCompleteDelay = 0
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
fire("CHALLENGE_MODE_COMPLETED")
advance(0)
expect(1, nil, nil, "overlapping chat throttle")
advance(1)
expect(2, nil, nil, "throttle postpones rather than discards")
check(messages[2].time - messages[1].time >= 1, "chat spacing")

for _, text in ipairs({ "", "   \n\t " }) do
    reset()
    MimQoLDB.autoGreetPartyMessage = text
    join("party", "A")
    advance(5)
    expect(0, nil, nil, "blank message")
end
reset()
MimQoLDB.autoGreetPartyMessage = string.rep("가", 100)
join("party", "A")
advance(3)
expect(1, string.rep("가", 85), "PARTY", "UTF8 byte boundary")

for _, case in ipairs({ { -5, 0 }, { 0, 0 }, { 999, 60 }, { "bad", 3 }, { 0/0, 3 } }) do
    reset()
    MimQoLDB.autoGreetPartyDelay = case[1]
    join("party", "A")
    if case[2] > 0 then
        advance(case[2] - 0.1)
        expect(0, nil, nil, "validated delay not early")
        advance(0.1)
    else advance(0) end
    expect(1, nil, nil, "validated delay sends")
end

reset()
C_ChatInfo.SendChatMessage = nil
SendChatMessage = sendChat
join("party", "A")
advance(3)
expect(1, "안녕하세요", "PARTY", "legacy API fallback")
C_ChatInfo.SendChatMessage = sendChat

local function enterDungeon(difficulty, mapID, kind)
    dungeon = { kind = kind or "party", difficulty = difficulty,
        mapID = mapID or 2000, journalID = 200, bosses = { 101, 102, 103 } }
    fire("PLAYER_ENTERING_WORLD", false, false)
end
local function encounter(id, success)
    fire("ENCOUNTER_END", id, "Boss", dungeon.difficulty, 5, success)
end

-- A full premade keeps the same recipients when entering an instance, even
-- when the client reports another category/GUID or loads unit data late.
for _, transition in ipairs({ "category", "guid" }) do
    for _, firstEvent in ipairs({ "GROUP_JOINED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        for _, lateRoster in ipairs({ false, true }) do
            reset()
            join("party", "A", "B", "C", "D")
            advance(3)
            expect(1, "안녕하세요", "PARTY", "full premade initial greeting")
            local category = transition == "category" and 2 or 1
            roster[category] = group("party", "D", "C", "B", "A")
            if lateRoster then roster[category].members, roster[category].total = {}, 5 end
            if firstEvent == "PLAYER_ENTERING_WORLD" then enterDungeon(2)
            else fire(firstEvent, category, "Dungeon-Party") end
            fire("GROUP_JOINED", category, "Dungeon-Party")
            enterDungeon(2)
            advance(5)
            expect(1, nil, nil, "instance transition must not repeat entry: " .. transition .. firstEvent)
            roster[category].members, roster[category].total = { "D", "C", "B", "A" }, nil
            fire("GROUP_ROSTER_UPDATE")
            advance(5)
            expect(1, nil, nil, "late roster must not repeat entry")
            fire("LFG_COMPLETION_REWARD")
            advance(3)
            expect(2, "수고하셨습니다", category == 2 and "INSTANCE_CHAT" or "PARTY",
                "same premade still sends dungeon completion")
        end
    end
end

for _, transition in ipairs({ "category", "guid" }) do
    reset()
    join("party", "A", "B", "C", "D")
    advance(1)
    local category = transition == "category" and 2 or 1
    roster[category] = group("party", "D", "C", "B", "A")
    fire("GROUP_JOINED", category, "Dungeon-Party")
    enterDungeon(2)
    advance(10)
    expect(1, "안녕하세요", category == 2 and "INSTANCE_CHAT" or "PARTY",
        "unsent initial greeting survives instance transition")
end

for _, changed in ipairs({ "different party", "partial premade", "leave and rejoin" }) do
    reset()
    join("party", "A", "B", "C", "D")
    advance(3)
    if changed == "leave and rejoin" then
        roster[1] = nil
        fire("GROUP_LEFT", 1, "Party-A")
    end
    roster[2] = changed == "different party" and group("party", "E", "F", "G", "H")
        or changed == "partial premade" and group("party", "A", "B", "C", "E")
        or group("party", "A", "B", "C", "D")
    fire("GROUP_JOINED", 2, "New-Party")
    enterDungeon(2)
    advance(3)
    expect(2, "안녕하세요", "INSTANCE_CHAT", "real new join still greets: " .. changed)
end

for _, previous in ipairs({ "login", "reload", "Shift", "welcome", "home removed" }) do
    reset(previous == "login" and group("party", "A", "B", "C", "D") or nil)
    if previous ~= "login" then
        shift = previous == "Shift"
        join("party", "A", "B", "C", "D")
        shift = false
        advance(3)
    end
    if previous == "reload" then fire("PLAYER_ENTERING_WORLD", false, true) end
    if previous == "welcome" then
        roster[1].members[4] = nil
        fire("GROUP_ROSTER_UPDATE")
        roster[1].members[4] = "E"
        fire("GROUP_ROSTER_UPDATE")
        advance(3)
    end
    local sent = #messages
    roster[2] = group("party", "A", "B", "C", previous == "welcome" and "E" or "D")
    if previous == "home removed" then
        roster[1] = nil
        fire("GROUP_LEFT", 1, "Party-A")
    end
    fire("GROUP_JOINED", 2, "Dungeon-Party")
    enterDungeon(2)
    advance(5)
    expect(sent, nil, nil, "existing full party keeps entry baseline: " .. previous)
    roster[2].members[4] = "Newcomer"
    fire("GROUP_ROSTER_UPDATE")
    advance(3)
    expect(sent + 1, "어서오세요", "INSTANCE_CHAT", "newcomers are still welcomed after transition")
end

for _, resolution in ipairs({ "different party", "secret", "unavailable" }) do
    reset()
    join("party", "A", "B", "C", "D")
    advance(3)
    roster[2] = group("party")
    roster[2].total = 5
    fire("GROUP_JOINED", 2, "Dungeon-Party")
    advance(5)
    expect(1, nil, nil, "incomplete roster cannot prove a new party")
    if resolution == "different party" then
        roster[2].members = { "E", "F", "G", "H" }
    elseif resolution == "secret" then
        roster[2].members = { "A", "B", "C", secret }
    end
    fire("GROUP_ROSTER_UPDATE")
    advance(65)
    expect(resolution == "different party" and 2 or 1, nil, nil,
        "late roster comparison is bounded and respects restricted GUIDs: " .. resolution)
    check(#timers == 0, "roster comparison stops after the existing greeting expiry")
end

reset(nil, group("party", "A"))
enterDungeon(2)
MimQoLDB.autoGreetCompleteMessage = "다들 고생하셨어요!"
MimQoLDB.autoGreetCompleteDelay = 1.5
fire("LFG_COMPLETION_REWARD")
advance(1.4)
expect(0, nil, nil, "5 player completion uses configured decimal delay")
advance(0.1)
expect(1, "다들 고생하셨어요!", "INSTANCE_CHAT", "matched dungeon common text")
encounter(103, 1)
fire("LFG_COMPLETION_REWARD")
advance(5)
expect(1, nil, nil, "reward and final boss duplicate completion")
enterDungeon(2, 2001)
fire("LFG_COMPLETION_REWARD")
advance(1.5)
expect(2, nil, nil, "same group next dungeon")
fire("LFG_PROPOSAL_SUCCEEDED")
fire("PLAYER_ENTERING_WORLD", false, false)
fire("LFG_COMPLETION_REWARD")
advance(1.5)
expect(3, nil, nil, "same group requeues for the same dungeon map")

for _, difficulty in ipairs({ 1, 2, 23, 24 }) do
    reset(group("party", "A"))
    enterDungeon(difficulty)
    encounter(101, 1)
    encounter(102, 1)
    encounter(103, 0)
    advance(5)
    expect(0, nil, nil, "middle bosses and wipe: difficulty " .. difficulty)
    encounter(103, 1)
    advance(3)
    expect(1, "수고하셨습니다", "PARTY", "premade dungeon final boss: " .. difficulty)
    fire("LFG_COMPLETION_REWARD")
    advance(3)
    expect(1, nil, nil, "boss followed by reward is deduplicated")
end

reset(group("party", "A"))
enterDungeon(8)
dungeon.activeKey = true
encounter(103, 1)
fire("LFG_COMPLETION_REWARD")
advance(5)
expect(0, nil, nil, "key final boss before enemy forces finished")
dungeon.activeKey = false
encounter(103, 1)
advance(3)
expect(0, nil, nil, "keystone difficulty guard after active flag clears")
fire("CHALLENGE_MODE_COMPLETED")
advance(3)
expect(1, "수고하셨습니다", "PARTY", "key completion common text")
fire("LFG_COMPLETION_REWARD")
encounter(103, 1)
advance(5)
expect(1, nil, nil, "key and normal events do not double greet")

for _, kind in ipairs({ "none", "raid", "scenario", "pvp", "arena" }) do
    reset(group("party", "A"))
    enterDungeon(2, 2000, kind)
    fire("LFG_COMPLETION_REWARD")
    encounter(103, 1)
    advance(5)
    expect(0, nil, nil, "ordinary completion excluded: " .. kind)
end

reset(group("raid", "A"))
enterDungeon(2)
fire("LFG_COMPLETION_REWARD")
encounter(103, 1)
advance(5)
expect(0, nil, nil, "raid group excluded from ordinary completion")

reset(group("party", "A"))
enterDungeon(1)
encounter(103, secret)
encounter(secret, 1)
dungeon.bosses[3] = secret
encounter(103, 1)
dungeon.bosses = nil
encounter(103, 1)
advance(5)
expect(0, nil, nil, "restricted or incomplete encounter data skipped")
fire("LFG_COMPLETION_REWARD")
advance(3)
expect(1, nil, nil, "finder completion works without journal data")

reset(group("party", "A"))
enterDungeon(23)
dungeon.zeroTerminator = true
encounter(103, 1)
advance(3)
expect(1, nil, nil, "zero journal terminator")
dungeon.kind = "none"
fire("PLAYER_ENTERING_WORLD", false, false)
enterDungeon(23)
encounter(103, 1)
advance(3)
expect(2, nil, nil, "same map after leaving and resetting")

reset(group("party", "A"))
enterDungeon(2)
fire("LFG_COMPLETION_REWARD")
enterDungeon(2, 2001)
advance(3)
expect(0, nil, nil, "next dungeon cancels previous completion timer")

reset(group("party", "A"))
enterDungeon(2)
MimQoLDB.autoGreetComplete = false
fire("LFG_COMPLETION_REWARD")
encounter(103, 1)
advance(3)
expect(0, nil, nil, "shared toggle disables normal completion")
reset(group("party", "A"))
enterDungeon(2)
shift = true
fire("LFG_COMPLETION_REWARD")
shift = false
advance(3)
expect(0, nil, nil, "normal completion Shift bypass")

reset(group("party", "A"))
enterDungeon(2)
fire("LFG_COMPLETION_REWARD")
MimQoLDB.autoGreet = false
MimQoLAutoGreet_ApplySettings()
check(not frames[1].events.LFG_COMPLETION_REWARD and not frames[1].events.ENCOUNTER_END,
    "disable unregisters ordinary dungeon events")
advance(3)
expect(0, nil, nil, "disable cancels ordinary completion")

-- Protected-action regression: chat lockdown and combat are separate states.
reset(group("party", "A"))
enterDungeon(8)
combat, chatLock = true, true
fire("CHALLENGE_MODE_COMPLETED")
advance(3)
expect(0, nil, nil, "completion cannot call protected chat while locked")
combat = false
advance(2)
expect(0, nil, nil, "combat ended but chat remains locked")
chatLock = false
advance(0.5)
expect(1, "수고하셨습니다", "PARTY", "completion resumes after chat unlock")
advance(5)
expect(1, nil, nil, "unlock sends only once")
check(#timers == 0, "no polling remains after send")

for _, key in ipairs({ "Party", "Raid", "Welcome", "Complete" }) do
    reset((key == "Welcome" or key == "Complete") and group("party", "A") or nil)
    chatLock = true
    if key == "Party" then join("party", "A")
    elseif key == "Raid" then join("raid", "A")
    elseif key == "Welcome" then
        roster[1].members[2] = "B"; fire("GROUP_ROSTER_UPDATE")
    else fire("CHALLENGE_MODE_COMPLETED") end
    advance(4)
    expect(0, nil, nil, "all greeting types respect lock: " .. key)
    chatLock = false
    advance(0.5)
    expect(1, nil, nil, "all greeting types resume: " .. key)
end

reset()
MimQoLDB.autoGreetPartyDelay = 7.5
chatLock = true
join("party", "A")
advance(1)
chatLock = false
advance(6.4)
expect(0, nil, nil, "unlock never shortens configured delay")
advance(0.1)
expect(1, nil, nil, "original decimal deadline is preserved")

reset()
combat = true
join("party", "A")
advance(3)
expect(1, nil, nil, "chat API can permit chat independently of player combat")

reset()
C_ChatInfo.InChatMessagingLockdown = nil
combat = true
join("party", "A")
advance(3)
expect(0, nil, nil, "missing chat API uses combat fallback")
combat = false
advance(0.5)
expect(1, nil, nil, "fallback resumes when combat ends")

for _, lockValue in ipairs({ secret, "error" }) do
    reset()
    chatLock = lockValue
    join("party", "A")
    advance(4)
    expect(0, nil, nil, "unknown lock state cannot permit protected chat")
    chatLock = false
    advance(0.5)
    expect(1, nil, nil, "lock API recovers")
end

for _, cancel in ipairs({ "disabled", "leave", "Shift", "settings" }) do
    reset()
    chatLock = true
    join("party", "A")
    advance(4)
    if cancel == "disabled" then
        MimQoLDB.autoGreet = false; MimQoLAutoGreet_ApplySettings()
    elseif cancel == "leave" then
        roster[1] = nil; fire("GROUP_LEFT", 1, "Party-A")
    elseif cancel == "Shift" then shift = true
    else
        MimQoLDB.autoGreetPartyMessage = "Changed"; MimQoLAutoGreet_ApplySettings()
    end
    chatLock = false
    advance(2)
    expect(0, nil, nil, "blocked greeting cancelled: " .. cancel)
    check(#timers == 0, "cancelled job stops polling: " .. cancel)
end

reset(group("party", "A"))
chatLock = true
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(4)
roster[1].members[2] = nil
fire("GROUP_ROSTER_UPDATE")
chatLock = false
advance(1)
expect(0, nil, nil, "departed newcomer is not welcomed after unlocking")

reset()
chatLock = true
join("party", "A")
advance(63)
expect(0, nil, nil, "expired greeting is dropped without calling chat")
check(#timers == 0, "long lockdown stops polling after expiry")
chatLock = false
advance(5)
expect(0, nil, nil, "old greeting cannot arrive after a long encounter")

reset(group("party", "A"))
enterDungeon(2)
chatLock = true
fire("LFG_COMPLETION_REWARD")
advance(4)
enterDungeon(2, 2001)
chatLock = false
advance(1)
expect(0, nil, nil, "blocked completion cannot leak into next dungeon")

reset(group("party", "A"))
chatLock = true
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
fire("CHALLENGE_MODE_COMPLETED")
advance(3)
chatLock = false
advance(0.5)
expect(1, nil, nil, "unlock burst sends one greeting first")
advance(1)
expect(2, nil, nil, "unlock burst preserves queued greetings")
check(messages[2].time - messages[1].time >= 1, "unlock retains chat spacing")

local prompts, dismissals = {}, 0
MimQoLGreetingOverlay = {
    ApplySettings = function() end,
    Prompt = function(kind) prompts[#prompts + 1] = kind end,
    Dismiss = function() dismissals = dismissals + 1 end,
}
reset()
MimQoLDB.greetManualMode = true
MimQoLDB.autoGreet = false
MimQoLAutoGreet_ApplySettings()
join("party", "A")
advance(10)
expect(0, nil, nil, "manual mode never auto sends on group join")
enterDungeon(2)
check(#prompts == 1 and prompts[1] == "entry", "dungeon entry opens manual choices")
fire("PLAYER_ENTERING_WORLD", false, false)
check(#prompts == 1, "same zone notification does not reopen choices")
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(10)
expect(0, nil, nil, "manual mode never auto welcomes")
fire("LFG_COMPLETION_REWARD")
fire("LFG_COMPLETION_REWARD")
check(#prompts == 2 and prompts[2] == "complete", "ordinary dungeon opens one completion popup")
advance(10)
expect(0, nil, nil, "manual completion never auto sends")
fire("PLAYER_ENTERING_WORLD", false, true)
check(#prompts == 2, "reload does not open an entry popup")
fire("CHALLENGE_MODE_START")
enterDungeon(8)
fire("ENCOUNTER_END", 200, "Boss", 8, 5, 1)
local before = #prompts
fire("CHALLENGE_MODE_COMPLETED")
check(#prompts == before + 1 and prompts[#prompts] == "complete", "M+ uses same manual completion choices")
check(dismissals > 0, "zone/reset changes dismiss stale overlay")
shift = true
enterDungeon(2, 999)
fire("LFG_COMPLETION_REWARD")
check(#prompts == before + 1, "Shift skips entry and completion popups")
shift = false
MimQoLDB.greetManualMode = false
MimQoLAutoGreet_ApplySettings()
enterDungeon(2, 998)
fire("LFG_COMPLETION_REWARD")
check(#prompts == before + 1, "disabled feature never prompts")
reset()
join("party", "A")
MimQoLDB.greetManualMode = true
advance(5)
expect(1, "안녕하세요", "PARTY", "enabling manual mode does not suppress automatic sending")

prompts = {}
reset()
MimQoLDB.greetManualMode = true
MimQoLAutoGreet_ApplySettings()
join("party", "A")
enterDungeon(2)
check(#prompts == 1 and prompts[1] == "entry", "combined mode opens entry choices")
advance(3)
expect(1, "안녕하세요", "PARTY", "combined mode retains automatic party greeting")
roster[1].members[2] = "B"
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(2, "어서오세요", "PARTY", "combined mode retains automatic newcomer welcome")
fire("LFG_COMPLETION_REWARD")
fire("LFG_COMPLETION_REWARD")
check(#prompts == 2 and prompts[2] == "complete", "combined mode opens one completion popup")
check(#messages == 2, "popup itself does not send the automatic message early")
advance(3)
expect(3, "수고하셨습니다", "PARTY", "combined completion also sends configured automatic message")
check(#prompts == 2, "automatic send does not dismiss or duplicate manual choices")

prompts = {}
reset(group("party", "A"))
enterDungeon(2)
fire("LFG_COMPLETION_REWARD")
advance(3)
check(#prompts == 0, "automatic-only mode never opens manual popup")
expect(1, "수고하셨습니다", "PARTY", "automatic-only completion unchanged")

prompts = {}
reset()
MimQoLDB.autoGreet = false
MimQoLDB.greetManualMode = true
MimQoLAutoGreet_ApplySettings()
enterDungeon(2)
check(#prompts == 0, "wait for roster after dungeon loading")
join("party", "A")
check(#prompts == 1 and prompts[1] == "entry", "late group roster still opens entry popup")
fire("GROUP_ROSTER_UPDATE")
check(#prompts == 1, "late roster popup appears only once")
advance(3)
expect(0, nil, nil, "manual-only popup does not auto send even after roster delay")

prompts = {}
reset()
MimQoLDB.autoGreet = false
MimQoLDB.greetManualMode = true
MimQoLAutoGreet_ApplySettings()
enterDungeon(2)
dungeon = {}
fire("PLAYER_ENTERING_WORLD", false, false)
join("party", "A")
check(#prompts == 0, "leaving dungeon cancels pending entry popup")

-- Full Mythic+ party announcements use a real bag link and the shared chat queue.
local keyLink = "|cffa335ee|Hkeystone:180653:600:10:0:0:0:0|h[날로라크의 소굴 (10)]|h|r"
local listing, activityInfo, bagLink
C_LFGList = {
    GetActiveEntryInfo = function() return listing end,
    GetActivityInfoTable = function(id)
        assert(id == 100 or id == 101, "activity ID must come from the listing")
        return activityInfo
    end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemLink = function(bag, slot)
        assert(bag == 0 and slot == 1, "read the actual keystone bag slot")
        return bagLink
    end,
}
local function prepareFullParty(alreadyFull)
    listing = { activityIDs = { 100 } }
    activityInfo = { isMythicPlusActivity = true }
    bagLink = keyLink
    reset(group("party", "A", "B", "C"))
    roster[1].leader = true
    if alreadyFull then roster[1].members[4] = "D" end
    MimQoLDB.autoGreetParty, MimQoLDB.autoGreetWelcome, MimQoLDB.autoGreetComplete = false, false, false
    MimQoLDB.autoGreetFullParty = true
    MimQoLDB.autoGreetFullPartyMessage = "풀파입니다. 이동 부탁드립니다."
    MimQoLDB.autoGreetFullPartyDelay = 1.5
    MimQoLAutoGreet_ApplySettings()
end
local function fillParty()
    roster[1].members[4] = "D"
    fire("GROUP_ROSTER_UPDATE")
end
local fullText = keyLink .. " 풀파입니다. 이동 부탁드립니다."

prepareFullParty()
check(frames[1].events.LFG_LIST_ACTIVE_ENTRY_UPDATE and frames[1].events.PARTY_LEADER_CHANGED,
    "full party watches listing and leadership changes")
fillParty()
advance(1.4)
expect(0, nil, nil, "full party decimal delay")
advance(0.1)
expect(1, fullText, "PARTY", "full party prepends the real clickable keystone")
fire("GROUP_ROSTER_UPDATE")
fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
advance(10)
expect(1, nil, nil, "repeated full party events do not resend")
roster[1].members[4] = nil
fire("GROUP_ROSTER_UPDATE")
fillParty()
advance(1.5)
expect(2, fullText, "PARTY", "refilling the party starts a new notice")

for _, situation in ipairs({ "ordinary", "unlisted", "not leader", "raid", "instance", "disabled", "blank", "Shift", "already full" }) do
    prepareFullParty(situation == "already full")
    if situation == "ordinary" then
        activityInfo.isMythicPlusActivity = false
    elseif situation == "unlisted" then
        listing = nil
        MimQoLDB.autoGreetFullParty = false; MimQoLAutoGreet_ApplySettings()
        MimQoLDB.autoGreetFullParty = true; MimQoLAutoGreet_ApplySettings()
    elseif situation == "not leader" then roster[1].leader = false
    elseif situation == "raid" then roster[1].kind = "raid"
    elseif situation == "instance" then roster[2] = group("party", "I")
    elseif situation == "disabled" then MimQoLDB.autoGreetFullParty = false
    elseif situation == "blank" then MimQoLDB.autoGreetFullPartyMessage = "  "
    elseif situation == "Shift" then shift = true end
    fillParty()
    shift = false
    advance(5)
    expect(0, nil, nil, "full party excludes: " .. situation)
end

for _, cancel in ipairs({ "leave", "leader", "raid", "listing", "different key group", "disabled", "master disabled", "Shift", "reload", "settings", "start" }) do
    prepareFullParty()
    fillParty()
    advance(1)
    if cancel == "leave" then roster[1].members[4] = nil
    elseif cancel == "leader" then roster[1].leader = false
    elseif cancel == "raid" then roster[1].kind = "raid"
    elseif cancel == "listing" then activityInfo.isMythicPlusActivity = false
    elseif cancel == "different key group" then listing.activityIDs = { 101 }
    elseif cancel == "disabled" then MimQoLDB.autoGreetFullParty = false
    elseif cancel == "master disabled" then MimQoLDB.autoGreet = false
    elseif cancel == "Shift" then shift = true
    elseif cancel == "reload" then fire("PLAYER_ENTERING_WORLD", false, true)
    elseif cancel == "settings" then MimQoLAutoGreet_ApplySettings()
    else fire("CHALLENGE_MODE_START") end
    advance(5)
    expect(0, nil, nil, "cancel pending full notice: " .. cancel)
end

prepareFullParty()
fillParty()
advance(1)
roster[1].members[4] = nil
fire("GROUP_ROSTER_UPDATE")
fillParty()
advance(0.5)
expect(0, nil, nil, "replacement cancels the original deadline")
advance(1)
expect(1, fullText, "PARTY", "replacement waits the full configured delay")

prepareFullParty()
listing = nil -- The listing can disappear as the final applicant joins.
fillParty()
advance(1.5)
expect(1, fullText, "PARTY", "recently observed Mythic+ listing survives delisting")

prepareFullParty()
MimQoLDB.autoGreetFullParty = false; MimQoLAutoGreet_ApplySettings()
listing = nil
MimQoLDB.autoGreetFullParty = true; MimQoLAutoGreet_ApplySettings()
fillParty()
listing = { activityIDs = { 100 } }
fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
advance(1.5)
expect(1, fullText, "PARTY", "late listing data resolves a pending full transition")

prepareFullParty()
chatLock = true
fillParty()
advance(2)
expect(0, nil, nil, "full notice waits through chat lockdown")
chatLock = false
advance(0.5)
expect(1, fullText, "PARTY", "full notice resumes after chat unlock")

for _, missing in ipairs({ "missing", "secret", "ordinary item" }) do
    prepareFullParty()
    bagLink = missing == "secret" and secret or (missing == "ordinary item" and "|Hitem:123|h[Item]|h" or nil)
    fillParty()
    advance(2)
    expect(0, nil, nil, "never sends a fabricated or unavailable key: " .. missing)
    bagLink = keyLink
    advance(0.5)
    expect(1, fullText, "PARTY", "late keystone information recovers: " .. missing)
end

prepareFullParty()
bagLink = nil
fillParty()
advance(62)
check(#timers == 0, "missing keystone retry stops after expiry")
bagLink = keyLink
advance(1)
expect(0, nil, nil, "missing keystone does not send a stale notice later")

prepareFullParty()
MimQoLDB.autoGreetFullPartyMessage = string.rep("가", 100)
fillParty()
advance(1.5)
expect(1, keyLink .. " " .. string.rep("가", math.floor((255 - #keyLink - 1) / 3)), "PARTY",
    "chat byte limit preserves the complete link and Korean characters")

prepareFullParty()
MimQoLDB.autoGreetWelcome = true
MimQoLDB.autoGreetWelcomeDelay = 1.5
fillParty()
advance(1.5)
expect(1, "어서오세요", "PARTY", "welcome and full notice share chat spacing")
advance(1)
expect(2, fullText, "PARTY", "full notice follows welcome without being dropped")

prepareFullParty()
MimQoLDB.autoGreetFullParty = false
MimQoLAutoGreet_ApplySettings()
check(not frames[1].events.LFG_LIST_ACTIVE_ENTRY_UPDATE and not frames[1].events.PARTY_LEADER_CHANGED,
    "disabled full party feature removes its extra events")

prepareFullParty()
dungeon.activeKey = true
fillParty()
advance(3)
expect(0, nil, nil, "do not send travel instructions during an active keystone run")

prepareFullParty()
activityInfo.isMythicPlusActivity = false
fillParty()
activityInfo.isMythicPlusActivity = true
fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
advance(3)
expect(0, nil, nil, "a full ordinary party changing its listing is not a new full transition")

prepareFullParty()
MimQoLDB.autoGreetFullParty = false; MimQoLAutoGreet_ApplySettings()
listing = nil
MimQoLDB.autoGreetFullParty = true; MimQoLAutoGreet_ApplySettings()
fillParty()
roster[1].total = secret
fire("PLAYER_ENTERING_WORLD", false, true)
roster[1].total = nil
listing = { activityIDs = { 100 } }
fire("GROUP_ROSTER_UPDATE")
advance(3)
expect(0, nil, nil, "reload with an unreadable count cancels pending full detection")

for _, restricted in ipairs({ "count", "leader", "listing", "activity IDs", "activity flag" }) do
    prepareFullParty()
    if restricted == "count" then roster[1].total = secret
    elseif restricted == "leader" then roster[1].leader = secret
    elseif restricted == "listing" then listing = secret
    elseif restricted == "activity IDs" then listing.activityIDs = secret
    else activityInfo.isMythicPlusActivity = secret end
    fillParty()
    advance(3)
    -- Cached public listing information is usable, but secret values are not inspected.
    if restricted == "count" or restricted == "leader" then
        expect(0, nil, nil, "restricted group state cannot authorize full notice: " .. restricted)
    else
        expect(1, fullText, "PARTY", "public cached activity survives restricted listing: " .. restricted)
    end
end

local function prepareNPCScenario(key, category)
    category = category or 1
    if key == "FullParty" then
        prepareFullParty()
        return fillParty
    end
    local existing = (key == "Welcome" or key == "Complete") and group("party", "A") or nil
    reset(category == 1 and existing or nil, category == 2 and existing or nil)
    if key == "Complete" then
        enterDungeon(2)
        return function() fire("LFG_COMPLETION_REWARD") end
    end
    return function()
        if key == "Welcome" then
            roster[category].members[2] = "B"
            fire("GROUP_ROSTER_UPDATE")
        else
            roster[category] = group(key == "Raid" and "raid" or "party", "A", "B")
            fire("GROUP_JOINED", category, "NPC-Test")
            fire("GROUP_ROSTER_UPDATE")
        end
    end
end

-- Every automatic message shares the exclusion, including mixed human/NPC parties.
for _, key in ipairs({ "Party", "Raid", "Welcome", "Complete", "FullParty" }) do
    for _, condition in ipairs({ "follower API", "follower difficulty", "party AI", "NPC as player", "nonhuman", "secret AI", "secret human" }) do
        local trigger = prepareNPCScenario(key)
        local unit = key == "Raid" and "raid1" or "party1"
        if condition == "follower API" then dungeon.follower = true
        elseif condition == "follower difficulty" then
            C_LFGInfo = nil
            dungeon.difficulty = 205
        elseif condition == "party AI" then unitTraits[unit] = { ai = true }
        elseif condition == "NPC as player" then unitTraits[unit] = { npc = true }
        elseif condition == "nonhuman" then unitTraits[unit] = { human = false }
        elseif condition == "secret AI" then unitTraits[unit] = { ai = secret }
        else unitTraits[unit] = { human = secret } end
        trigger()
        check(#timers == 0, "excluded group must not queue " .. key .. ": " .. condition)
        advance(5)
        expect(0, nil, nil, "excluded group must not send " .. key .. ": " .. condition)
    end
    for _, late in ipairs({ "follower", "NPC" }) do
        local trigger = prepareNPCScenario(key)
        trigger()
        check(#timers > 0, "human group initially queues " .. key)
        if late == "follower" then dungeon.follower = true
        else unitTraits[key == "Raid" and "raid1" or "party1"] = { npc = true } end
        -- No roster event: dispatch itself must detect the changed group.
        advance(5)
        expect(0, nil, nil, "late " .. late .. " cancels pending " .. key)
        check(#timers == 0, "cancelled NPC greeting stops its timers")
    end
end

for _, key in ipairs({ "Party", "Raid", "Welcome", "Complete" }) do
    local trigger = prepareNPCScenario(key, 2)
    unitTraits[key == "Raid" and "raid1" or "party1"] = { ai = true }
    trigger()
    advance(5)
    expect(0, nil, nil, "instance NPC group excludes " .. key)
end

local trigger = prepareNPCScenario("Party")
unitTraits.party2 = { human = false } -- A real player in party1 must not authorize NPC parties.
trigger()
advance(5)
expect(0, nil, nil, "mixed human and NPC party is excluded")

trigger = prepareNPCScenario("Party")
UnitIsHumanPlayer, UnitInPartyIsAI, UnitIsNPCAsPlayer = nil, nil, nil
unitTraits.party1 = { player = false }
trigger()
advance(5)
expect(0, nil, nil, "legacy player check still rejects ordinary NPC members")

trigger = prepareNPCScenario("Party")
C_LFGInfo, UnitIsHumanPlayer, UnitInPartyIsAI, UnitIsNPCAsPlayer = nil, nil, nil, nil
trigger()
advance(3)
expect(1, "안녕하세요", "PARTY", "human party still works without newer NPC APIs")

trigger = prepareNPCScenario("Party")
unitTraits.party4 = { human = false }
trigger()
advance(3)
expect(1, "안녕하세요", "PARTY", "empty roster slots are not NPC members")

trigger = prepareNPCScenario("Party")
DifficultyUtil = { ID = { FollowerDungeon = 999 } }
dungeon.difficulty = 999
trigger()
advance(5)
expect(0, nil, nil, "use the client's follower difficulty constant when available")

trigger = prepareNPCScenario("Party")
dungeon.follower = secret
trigger()
advance(5)
expect(0, nil, nil, "restricted follower flag cannot authorize automatic chat")

trigger = prepareNPCScenario("Party")
chatLock = true
trigger()
advance(3)
dungeon.follower = true
advance(0.5)
chatLock = false
advance(1)
expect(0, nil, nil, "entering follower mode while chat is locked cancels the old greeting")
check(#timers == 0, "follower cancellation stops chat lock polling")

reset(nil, group("party", "A", "B"))
enterDungeon(205)
fire("LFG_COMPLETION_REWARD")
encounter(103, 1)
advance(5)
expect(0, nil, nil, "follower reward and final boss cannot send completion greetings")

reset()
dungeon.follower = true
join("party", "NPC")
advance(3)
roster[1] = nil
fire("GROUP_LEFT", 1, "Party-A")
dungeon = {}
join("party", "Human")
advance(3)
expect(1, "안녕하세요", "PARTY", "a later human party still greets normally")

print("auto_greet_smoke: " .. checks .. " checks passed")
