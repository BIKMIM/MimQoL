-- Plays a short sound when guild chat or a chosen channel receives a message
-- from someone else. Chat arguments may be restricted; anything unreadable is
-- treated as "not mine" and "no channel match".
local driver = CreateFrame("Frame")
local lastPlayed = -math.huge

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function readable(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or isSecret(value) then return nil end
    return value
end

local function text(value)
    if isSecret(value) or type(value) ~= "string" then return nil end
    return value
end

local function guildEnabled()
    return type(MimQoLDB) == "table" and MimQoLDB.chatSoundGuild == true
end

local function channelEnabled()
    return type(MimQoLDB) == "table" and MimQoLDB.chatSoundChannel == true
end

local function partyEnabled()
    return type(MimQoLDB) == "table" and MimQoLDB.chatSoundParty == true
end

-- Channel names typed by the user, lower-cased, split on commas or newlines.
local function wantedChannels()
    local result = {}
    local saved = MimQoLDB and MimQoLDB.chatSoundChannels
    if isSecret(saved) or type(saved) ~= "string" then return result end
    for name in saved:gmatch("[^,\r\n]+") do
        name = name:match("^%s*(.-)%s*$"):lower()
        if name ~= "" then result[#result + 1] = name end
    end
    return result
end

local function channelMatches(channelName, channelNumber, baseName)
    local wanted = wantedChannels()
    if #wanted == 0 then return false end
    local full = text(channelName)
    local base = text(baseName)
    -- "2. 거래 - 오그리마" (or a community "5. 와박령 - 일반") also matches
    -- "거래 - 오그리마", "거래" and "2".
    local unnumbered = full and (full:gsub("^%d+%.%s*", ""))
    local stripped = unnumbered and (unnumbered:gsub("%s*%-%s.*$", ""))
    local number = not isSecret(channelNumber) and tonumber(channelNumber)
    for _, name in ipairs(wanted) do
        if (base and base:lower() == name) or (stripped and stripped:lower() == name)
            or (unnumbered and unnumbered:lower() == name)
            or (full and full:lower() == name) or (number and tostring(number) == name) then
            return true
        end
    end
    return false
end

local function isOwnMessage(sender, guid)
    local mine = readable(UnitGUID, "player")
    if mine and not isSecret(guid) and type(guid) == "string" and guid ~= "" then return guid == mine end
    local name = text(sender)
    if not name then return false end
    local player = readable(UnitName, "player")
    if not player then return false end
    local realm = readable(GetNormalizedRealmName)
    return name == player or (realm and name == player .. "-" .. realm) or false
end

local WHISPER_FILE = 567421
local SOUND_DIR = "Interface\\AddOns\\MimQoL\\sounds\\"

-- Chat picks start with the sounds copied from Prat (see sounds\CREDITS.txt),
-- then the shared built-in list. A preset is { name, sound ID or file path }.
local PRAT_SOUNDS = {
    { "Prat - 동전 (Kachink)", "Kachink.ogg" }, { "Prat - 하트 (Heart)", "Heart.ogg" },
    { "Prat - 문자 1 (Text1)", "Text1.ogg" }, { "Prat - 문자 2 (Text2)", "Text2.ogg" },
    { "Prat - 팝업 (Link)", "Link.ogg" }, { "Prat - 메신저 (IM)", "IM.ogg" },
    { "Prat - 알림 (Info)", "Info.ogg" }, { "Prat - 종 (Bell)", "Bell.ogg" },
    { "Prat - 차임 (Chime)", "Chime.ogg" }, { "Prat - 실로폰 (Xylo)", "Xylo.ogg" },
}
local presets

local function chatPresets()
    if presets then return presets end
    presets = {}
    for _, sound in ipairs(PRAT_SOUNDS) do presets[#presets + 1] = { sound[1], SOUND_DIR .. sound[2] } end
    local reminder = rawget(_G, "MimQoLCooldownReminder")
    for _, preset in ipairs(type(reminder) == "table" and type(reminder.Presets) == "table" and reminder.Presets or {}) do
        presets[#presets + 1] = preset
    end
    return presets
end

-- Only our own copied files are accepted as a saved path.
local function bundledFile(key)
    return type(key) == "string" and key:sub(1, #SOUND_DIR) == SOUND_DIR and key:find("..", 1, true) == nil
end

local function pratMutesWhisper()
    local prat = rawget(_G, "Prat")
    if type(prat) ~= "table" or type(prat.GetModule) ~= "function" then return false end
    local ok, module = pcall(prat.GetModule, prat, "Sounds", true)
    if not ok or type(module) ~= "table" or type(module.IsEnabled) ~= "function" then return false end
    local okEnabled, on = pcall(module.IsEnabled, module)
    return okEnabled and on == true
end

-- Three ways to pick the sound, like MimDice: built-in list, file name or ID.
local function playSound()
    local mode = MimQoLDB.chatSoundType
    if mode == "custom" then
        local file = MimQoLDB.chatSoundFile
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
            if readable(PlaySoundFile, path, "Master") == true then return true, "재생했습니다." end
        end
        return false, "소리 파일을 찾지 못했습니다. 파일명과 위치를 확인하세요."
    end
    if mode ~= "id" and bundledFile(MimQoLDB.chatSoundKey) then
        if readable(PlaySoundFile, MimQoLDB.chatSoundKey, "Master") == true then return true, "재생했습니다." end
        return false, "소리 파일을 재생하지 못했습니다. 새 소리 파일은 게임을 완전히 재시작해야 쓸 수 있습니다."
    end
    local id = tonumber(mode == "id" and MimQoLDB.chatSoundID or MimQoLDB.chatSoundKey)
    if not id or id ~= id or id < 1 or id ~= math.floor(id) then return false, "소리 ID를 확인하세요." end
    -- Prat's Sounds module mutes the whisper file (MuteSoundFile) while it is on.
    local muted = id == WHISPER_FILE and pratMutesWhisper()
    local func = id > 500000 and PlaySoundFile or PlaySound
    if readable(func, id, "Master") == true then
        if muted then return true, "Prat 소리 모듈이 이 소리(귓속말)를 음소거해서 들리지 않습니다. 다른 소리를 고르세요." end
        return true, "재생했습니다."
    end
    return false, "소리 ID와 와우 소리 설정을 확인하세요."
end

local function applySettings()
    driver:UnregisterAllEvents()
    driver:RegisterEvent("PLAYER_LOGIN")
    if guildEnabled() then driver:RegisterEvent("CHAT_MSG_GUILD") end
    if partyEnabled() then
        -- Dungeon finder groups talk on instance chat.
        for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
            driver:RegisterEvent(event)
        end
    end
    if channelEnabled() and #wantedChannels() > 0 then
        -- Community channels (e.g. "5. 와박령 - 일반") arrive on their own event.
        driver:RegisterEvent("CHAT_MSG_CHANNEL")
        driver:RegisterEvent("CHAT_MSG_COMMUNITIES_CHANNEL")
    end
end

driver:SetScript("OnEvent", function(_, event, _, sender, _, channelName, _, _, _, channelNumber, baseName, _, _, guid)
    if event == "PLAYER_LOGIN" then applySettings(); return end
    if (event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_COMMUNITIES_CHANNEL")
        and not channelMatches(channelName, channelNumber, baseName) then return end
    if isOwnMessage(sender, guid) then return end
    local gap = tonumber(MimQoLDB and MimQoLDB.chatSoundGap) or 1
    if GetTime() - lastPlayed < gap then return end
    lastPlayed = GetTime()
    playSound()
end)
driver:RegisterEvent("PLAYER_LOGIN")

_G.MimQoLChatSound = { ApplySettings = applySettings, TestSound = playSound, Presets = chatPresets }
