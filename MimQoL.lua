--------------------------------------------------------------------------------
-- MimQoL - focused quality-of-life features for the default UI
--------------------------------------------------------------------------------

local ADDON_NAME = ...
local ADDON_VERSION = "0.8.17"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    ADDON_VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        or ADDON_VERSION
end

local DEFAULTS = {
    cursorTooltip = false,
    autoSellJunk = true,
    autoRepair = true,
    guildRepair = false,
    vendorSummary = false,
    auctionCurrentExpansion = true,
    autoAcceptQuests = true,
    autoCompleteQuests = true,
    showBestQuestReward = true,
    wowheadLink = false,
    hideQuestTrackerInInstances = false,
    discordLinks = true,
    softInteractObjects = true,
    quickHideDeadNameplates = true,
    hideInstanceErrors = true,
    ellesmereAuraDecimals = true,
    keepAudioSynced = true,
    chatSoundGuild = true,
    chatSoundChannel = false,
    chatSoundParty = true,
    chatSoundChannels = "",
    chatSoundType = "preset",
    chatSoundKey = 567428,   -- "동전". The whisper sound (567421) is muted by Prat's Sounds module.
    chatSoundID = 567421,
    chatSoundFile = "",
    chatSoundGap = 1,
    dungeonPortal = true,
    dungeonPortalX = 0,
    dungeonPortalY = -180,
    petReminder = true,
    petReminderMissing = true,
    petReminderAttack = true,
    petReminderHealth = true,
    argusTracker = true,
    argusTrackerX = 0,
    argusTrackerY = 120,
    argusTrackerSize = 32,
    argusTrackerHold = 5,
    argusTrackerDuration = 25,
    cooldownReminder = true,
    cooldownReminderCombatOnly = false,
    cooldownReminderEntries = "",
    cooldownReminderSeconds = 5,
    cooldownReminderScale = 100,
    cooldownReminderX = 0,
    cooldownReminderY = 40,
    cooldownReminderIconEnabled = true,
    cooldownReminderTextEnabled = true,
    cooldownReminderSoundEnabled = true,
    cooldownReminderTiming = "soon",
    cooldownReminderDuration = 3,
    cooldownReminderIconSize = 48,
    cooldownReminderNumberSize = 22,
    cooldownReminderFontSize = 22,
    cooldownReminderMessage = "{이름} 곧 준비!",
    cooldownReminderReadyMessage = "{이름} 준비 완료!",
    cooldownReminderColorR = 1,
    cooldownReminderColorG = 0.82,
    cooldownReminderColorB = 0,
    cooldownReminderSoundType = "preset",
    cooldownReminderSoundKey = 567458,
    cooldownReminderSoundID = 567458,
    cooldownReminderSoundFile = "",
    cooldownReminderPulse = true,
    cooldownReminderPulseSize = 180,
    cooldownReminderPulseOpacity = 50,
    cooldownReminderPulseSpeed = 1,
    cooldownReminderPulseX = 0,
    cooldownReminderPulseY = 0,
    cooldownReminderPositions = "",
    cooldownReminderEntryOptions = "",
    autoGreet = true,
    greetManualMode = false,
    greetEntryPhrases = "안녕하세요",
    greetCompletePhrases = "수고하셨습니다",
    greetGeneralPhrases = "안쓰는 아이템 나눔될까요?",
    greetOverlayScale = 100,
    greetOverlayChars = 8,
    greetOverlayX = 0,
    greetOverlayY = -120,
    autoGreetParty = true,
    autoGreetPartyMessage = "안녕하세요",
    autoGreetPartyDelay = 3,
    autoGreetRaid = true,
    autoGreetRaidMessage = "안녕하세요",
    autoGreetRaidDelay = 3,
    autoGreetWelcome = true,
    autoGreetWelcomeMessage = "어서오세요",
    autoGreetWelcomeDelay = 3,
    autoGreetFullParty = false,
    autoGreetFullPartyMessage = "풀파입니다. 이동 부탁드립니다.",
    autoGreetFullPartyDelay = 3,
    autoGreetComplete = true,
    autoGreetCompleteMessage = "수고하셨습니다",
    autoGreetCompleteDelay = 3,
    fasterLoot = false,
    easyItemDestroy = false,
    bagItemLevel = true,
    lootDelay = 0.3,
}

local LABELS = {
    dungeonPortal = "쐐기 풀파티 포탈 버튼",
    cursorTooltip = "커서 오른쪽 툴팁",
    autoSellJunk = "회색 아이템 자동 판매",
    autoRepair = "자동 수리",
    guildRepair = "길드 자금 우선 수리",
    vendorSummary = "자동 수리 결과 표시",
    auctionCurrentExpansion = "경매장 현행 확장팩 자동 선택",
    autoAcceptQuests = "퀘스트 자동 수락",
    autoCompleteQuests = "퀘스트 자동 완료",
    showBestQuestReward = "가장 비싼 선택 보상 테두리",
    wowheadLink = "퀘스트 와우헤드 링크",
    hideQuestTrackerInInstances = "레이드·쐐기에서 퀘스트 목록 숨김",
    discordLinks = "Discord 주소 클릭 복사",
    softInteractObjects = "채집물 이름과 상호작용 아이콘",
    quickHideDeadNameplates = "죽은 대상 이름표 즉시 숨김",
    hideInstanceErrors = "던전·공격대 행동 오류 숨김",
    ellesmereAuraDecimals = "엘스미어 오라 시간 소수점",
    keepAudioSynced = "오디오 동기화 유지",
    chatSoundGuild = "길드 채팅 소리",
    chatSoundChannel = "지정 채널 채팅 소리",
    chatSoundParty = "파티 대화 소리",
    petReminder = "사냥꾼·흑마법사 소환수 알림",
    petReminderMissing = "소환수 미소환·사망 알림",
    petReminderAttack = "소환수 미공격 알림",
    petReminderHealth = "소환수 체력 30% 미만 알림",
    argusTracker = "악마 흑마법사 아르거스 차원문 추적",
    cooldownReminder = "쿨타임 알림 사용",
    cooldownReminderCombatOnly = "전투 중에만 표시",
    autoGreet = "자동 인사 사용",
    greetManualMode = "문구 버튼 사용 (수동 전송)",
    autoGreetParty = "내가 파티에 참여할 때",
    autoGreetRaid = "내가 공격대에 참여할 때",
    autoGreetWelcome = "다른 사람이 파티에 참여할 때",
    autoGreetFullParty = "내 쐐기 파티가 5명이 되었을 때",
    autoGreetComplete = "5인·쐐기 던전을 완료했을 때",
    fasterLoot = "빠른 전리품 획득",
    easyItemDestroy = "간편한 아이템 파괴",
    bagItemLevel = "가방 장비 아이템 레벨 표시",
}

local DESCRIPTIONS = {
    dungeonPortal = "파티 찾기로 모집하거나 지원한 쐐기 파티가 5명이 되면 해당 던전 포탈 버튼을 표시합니다. 배운 포탈만 클릭해 시전할 수 있습니다. 던전 안이나 전투 중에는 숨깁니다. /mq portaltest로 모양을 확인합니다.",
    cursorTooltip = "아이템이나 버튼을 가리키면 설명 창을 마우스 커서 오른쪽에 붙여 보여줍니다.",
    autoSellJunk = "상인을 열면 가방에 있는 회색 품질 아이템을 자동으로 모두 팝니다. Shift를 누른 채 상인을 열면 이번에는 건너뜁니다.",
    autoRepair = "수리할 수 있는 상인을 열면 착용 장비와 가방 속 장비를 자동으로 모두 수리합니다. Shift를 누른 채 열면 이번에는 건너뜁니다.",
    guildRepair = "자동 수리할 때 길드 자금을 사용할 수 있으면 길드 자금을 먼저 씁니다. 부족한 금액은 내 돈으로 수리합니다.",
    vendorSummary = "자동 수리가 끝나면 사용한 금액을 채팅창에 알려줍니다.",
    auctionCurrentExpansion = "경매장을 열 때 검색 필터의 '현행 확장팩 전용'을 자동으로 선택합니다. 다른 레벨·품질 필터는 그대로 유지합니다.",
    autoAcceptQuests = "NPC와 대화하면 받을 수 있는 퀘스트를 자동으로 선택하고 수락합니다. Shift를 누른 채 대화하면 이번에는 건너뛰며, PvP 확인 퀘스트는 자동 수락하지 않습니다.",
    autoCompleteQuests = "완료 가능한 퀘스트를 자동으로 넘깁니다. 보상 선택지가 없거나 하나뿐일 때만 최종 완료하며, 비용이 들거나 보상을 골라야 하면 멈춥니다. Shift를 누른 채 대화하면 이번에는 건너뜁니다.",
    showBestQuestReward = "선택 보상 아이템의 개수까지 포함한 상점 판매가를 비교해 가장 비싼 보상에 초록색 테두리를 표시합니다. 화폐 보상은 비교에서 제외합니다.",
    wowheadLink = "세계 지도에서 퀘스트 상세 내용을 열면 위쪽에 해당 퀘스트의 와우헤드 주소를 보여줍니다.",
    hideQuestTrackerInInstances = "공격대 인스턴스와 진행 중인 쐐기 던전에서 일반·대장정 퀘스트 목록만 숨깁니다. 쐐기 진행도 같은 다른 목표는 유지하며, 밖으로 나오면 다시 표시합니다.",
    discordLinks = "일반 채팅과 공격대 경보에 올라온 Discord 초대 주소를 클릭하면 복사 창을 엽니다.",
    softInteractObjects = "약초나 광맥 같은 게임 오브젝트를 바라보면 이름과 상호작용 아이콘을 표시합니다. 활성 이름표 애드온이 이름을 숨기는 경우에만 MimQoL이 이름을 보완합니다.",
    quickHideDeadNameplates = "몹이 죽으면 축소 애니메이션을 기다리지 않고 이름표를 바로 숨깁니다.",
    hideInstanceErrors = "던전과 공격대 안에서 스킬 버튼을 눌렀을 때 '아직 준비되지 않았습니다'처럼 화면 위쪽에 뜨는 빨간 행동 오류 문구를 숨깁니다. DBM과 블리자드 우두머리 경고에는 영향을 주지 않습니다.",
    ellesmereAuraDecimals = "EllesmereUI 의 보스·대상·주시·내 버프·공격대 프레임 오라 시간이 3초 미만이면 2.9처럼 소수점으로 보입니다. 끄거나 켠 뒤에는 /reload 해야 모든 아이콘에 적용됩니다. EllesmereUI가 없으면 아무 일도 하지 않습니다.",
    keepAudioSynced = "컴퓨터의 소리 출력 장치가 바뀌면 와우도 기본 출력 장치를 다시 사용하도록 맞춥니다. 영상 재생 중에는 소리를 다시 시작하지 않습니다.",
    chatSoundGuild = "다른 사람이 길드 채팅에 글을 올리면 짧은 소리를 냅니다. 내 글에는 울리지 않습니다.",
    chatSoundChannel = "아래에 적은 채널(예: 거래, 2)에 글이 올라오면 소리를 냅니다. 여러 채널은 쉼표로 나눕니다.",
    chatSoundParty = "파티 대화(던전 찾기의 인스턴스 대화 포함)에 다른 사람이 글을 올리면 소리를 냅니다. 내 글에는 울리지 않습니다.",
    petReminder = "사냥꾼과 흑마법사의 소환수 상태를 화면 중앙 위에 표시합니다. 탈것·비행·차량 이용, 애완동물 대전, 플레이어 사망 중에는 숨깁니다. Shift를 누르는 동안 잠시 숨길 수 있습니다. /mq pettest로 표시를 확인합니다.",
    petReminderMissing = "소환수가 없으면 소환을, 죽으면 사냥꾼은 야수 되살리기를, 흑마법사는 악마 재소환을 안내합니다. 펫을 쓰지 않는 사격 특성이나 희생의 흑마법서 특성에서는 미소환 알림을 생략합니다.",
    petReminderAttack = "전투 중에 내 대상이 살아 있고 공격할 수 있는 전투 중인 적인데, 살아 있는 소환수에게 공격 대상이 3초간 없으면 공격 명령을 내리도록 안내합니다. 처치 직후나 파티원만 싸우는 동안에는 알리지 않습니다. 대상의 상태를 읽을 수 없는 경우(일부 인스턴스 제한)에는 그 조건을 건너뛰고 알릴 수 있습니다.",
    petReminderHealth = "소환수 체력이 30% 미만이면 사냥꾼은 동물 치료를, 흑마법사는 생명력 집중을 안내합니다.",
    argusTracker = "악마 전문화에서 악마폭군 소환 중 아르거스의 지배자(1276166) 버프가 있는 동안, 굴단의 손 시전 성공 두 번마다 차원문 악마 1마리로 세어 지금 몇 마리째인지, 다음 악마까지 굴단의 손이 몇 번 남았는지, 버프 남은 시간을 소수점으로 보여줍니다. 인스턴스 전투 중에는 버프가 비밀 값이라 폭군 시전부터 아래 '버프 시간'으로 끝을 추정하고 시간 옆에 (추정)을 붙입니다. 버프를 읽을 수 있을 때 실제 길이를 보면 이 값을 자동으로 고칩니다. /mq argustest로 미리 봅니다.",
    cooldownReminder = "등록한 스킬과 착용 중인 장신구의 쿨타임 임박·준비 완료를 알려줍니다. 아래 세부 설정에서 아이콘·문구·소리·완료 펄스를 각각 켤 수 있습니다. Shift를 누르는 동안 알림을 생략합니다.",
    cooldownReminderCombatOnly = "전투 중에만 쿨타임 화면·소리 알림을 사용합니다. 끄면 전투 밖에서도 알립니다.",
    autoGreet = "아래에서 설정한 문구를 지정한 대기 시간 뒤에 자동으로 전송합니다. 추종자 던전과 NPC가 포함된 파티에서는 보내지 않습니다.",
    greetManualMode = "버튼을 눌러 전송합니다. 기타 문구는 상시, 인사는 입장·완료 때 표시됩니다.",
    autoGreetParty = "파티 채팅으로 인사합니다. 접속·/reload 때 이미 속한 파티에는 다시 인사하지 않습니다.",
    autoGreetRaid = "공격대 채팅으로 인사합니다. 파티와 공격대 사이의 단순 전환이나 다른 공격대원의 합류에는 인사하지 않습니다.",
    autoGreetWelcome = "새 파티원을 파티 채팅으로 반깁니다. 대기 중 여러 명이 합류하면 한 번만 보내며, 새로 온 사람이 모두 나가면 취소합니다.",
    autoGreetFullParty = "파티 찾기에 쐐기로 등록한 파티에서 내가 파티장이고 5명이 되면, 내 가방의 쐐기돌 링크 뒤에 아래 문구를 붙여 파티 채팅으로 보냅니다. 인원이 줄거나 파티장이 바뀌면 취소하며, 접속·/reload 때 이미 5명인 파티에는 보내지 않습니다. Shift로 건너뛸 수 있습니다.",
    autoGreetComplete = "5인 던전과 쐐기에서 같은 문구와 대기 시간을 사용합니다. 5인 던전은 완료 보상 또는 던전 도감의 마지막 우두머리 처치 시, 쐐기는 제한 시간과 관계없이 실제 완료 시 한 번 보냅니다. 중간 우두머리 처치나 전멸에는 보내지 않습니다.",
    fasterLoot = "자동 획득 조건이 맞을 때 전리품 칸을 바로 처리하여 줍는 시간을 줄입니다.",
    easyItemDestroy = "좋은 품질의 아이템을 버릴 때 DELETE를 직접 입력하지 않고 확인 버튼을 바로 누를 수 있게 합니다.",
    bagItemLevel = "기본 가방 창에서 무기·방어구 아이콘 아래에 실제 아이템 레벨을 품질 색으로 표시합니다. 가방 애드온이 가방 창을 바꾸면 보이지 않을 수 있습니다.",
}

local FEATURE_OPTIONS = {
    "dungeonPortal",
    "cursorTooltip",
    "autoSellJunk",
    "autoRepair",
    "guildRepair",
    "vendorSummary",
    "auctionCurrentExpansion",
    "autoAcceptQuests",
    "autoCompleteQuests",
    "showBestQuestReward",
    "wowheadLink",
    "hideQuestTrackerInInstances",
    "discordLinks",
    "softInteractObjects",
    "quickHideDeadNameplates",
    "hideInstanceErrors",
    "ellesmereAuraDecimals",
    "keepAudioSynced",
    "chatSoundGuild",
    "chatSoundChannel",
    "chatSoundParty",
    "petReminder",
    "petReminderMissing",
    "petReminderAttack",
    "petReminderHealth",
    "argusTracker",
    "cooldownReminder",
    "cooldownReminderCombatOnly",
    "autoGreet",
    "greetManualMode",
    "autoGreetParty",
    "autoGreetRaid",
    "autoGreetWelcome",
    "autoGreetFullParty",
    "autoGreetComplete",
    "fasterLoot",
    "easyItemDestroy",
    "bagItemLevel",
}

local FEATURE_CATEGORIES = {
    {
        key = "dungeons",
        title = "쐐기 던전",
        description = "5인 파티가 준비되면 모집한 던전으로 이동할 포탈을 표시합니다.",
        options = { "dungeonPortal" },
    },
    {
        key = "greetings",
        title = "인사·문구",
        description = "직접 눌러 보낼 문구 버튼을 설정합니다.",
        options = { "greetManualMode" },
    },
    {
        key = "greetAutomatic",
        title = "자동 인사 문구",
        description = "각 상황의 문구 하나를 0~60초 뒤에 자동 전송합니다. 대기 시간에는 1.5처럼 소수점도 입력할 수 있습니다. Enter 또는 다른 입력칸을 클릭하면 저장하며, 빈 문구는 보내지 않습니다.",
        options = {
            "autoGreet",
            "autoGreetParty", "autoGreetRaid",
            "autoGreetWelcome", "autoGreetFullParty", "autoGreetComplete",
        },
    },
    {
        key = "vendor",
        title = "상점",
        description = "상인을 열었을 때 자동으로 처리할 일을 모아 둔 곳입니다.",
        options = {
            "autoSellJunk", "autoRepair", "guildRepair", "vendorSummary",
            "auctionCurrentExpansion",
        },
    },
    {
        key = "quests",
        title = "퀘스트",
        description = "퀘스트 자동 처리와 표시를 조정하고 선택 보상의 상점가를 비교합니다.",
        options = {
            "autoAcceptQuests", "autoCompleteQuests",
            "showBestQuestReward", "wowheadLink",
            "hideQuestTrackerInInstances",
        },
    },
    {
        key = "display",
        title = "화면과 링크",
        description = "설명 창의 위치와 채팅 링크 및 행동 오류 표시를 바꿉니다.",
        options = {
            "cursorTooltip", "discordLinks", "softInteractObjects",
            "quickHideDeadNameplates", "hideInstanceErrors",
            "ellesmereAuraDecimals",
        },
    },
    {
        key = "combat",
        title = "전투 알림",
        description = "사냥꾼과 흑마법사의 소환·부활, 공격 명령, 소환수 치유가 필요한 상태를 알려주고, 악마 흑마법사의 폭군 중 차원문 악마 수를 셉니다.",
        options = {
            "petReminder", "petReminderMissing",
            "petReminderAttack", "petReminderHealth",
            "argusTracker",
        },
    },
    {
        key = "cooldowns",
        title = "쿨타임 알림",
        description = "본섭 시험 기능: 스킬·장신구를 최대 12개 등록해 임박·완료 알림을 받습니다. 목록은 같은 직업 캐릭터끼리 공유하며, 현재 배운 스킬과 착용한 장신구만 알립니다. 실제 전투에서 표시와 소리를 확인해 주세요.",
        options = { "cooldownReminder", "cooldownReminderCombatOnly" },
    },
    {
        key = "items",
        title = "전리품과 아이템",
        description = "아이템을 줍거나 버릴 때 필요한 단계를 줄이고, 가방 속 장비의 아이템 레벨을 보여줍니다.",
        options = { "fasterLoot", "easyItemDestroy", "bagItemLevel" },
    },
    {
        key = "audio",
        title = "소리",
        description = "컴퓨터의 소리 장치가 바뀌었을 때 와우 소리를 맞춥니다.",
        options = { "keepAudioSynced" },
    },
    {
        key = "chatSound",
        title = "채팅 소리",
        description = "길드·파티 대화와 지정한 채널에 글이 올라오면 소리로 알립니다. 1초 안에 여러 글이 와도 한 번만 울립니다.",
        options = { "chatSoundGuild", "chatSoundParty", "chatSoundChannel" },
    },
}

local REMOVED_SETTINGS = {
    "chatSoundWhisper",
    "lustReminder",
    "lustReminderAllClasses",
    "lustReminderDungeonPull",
    "lustReminderDebuffExpiry",
    "enableNameplateFeatures",
    "thickTargetBorder",
    "showNameplateName",
    "showInteractObjectName",
    "showNameplateHealth",
    "showNameplateHealthPercent",
    "nameplateWidth",
    "nameplateHeight",
    "nameplateSpacing",
}

local DELETE_POPUPS = {
    DELETE_ITEM = true,
    DELETE_GOOD_ITEM = true,
    DELETE_QUEST_ITEM = true,
    DELETE_GOOD_QUEST_ITEM = true,
}

local DEFAULTS_CONFIRM_POPUP = "MIMQOL_CONFIRM_DEFAULTS_RESTORE"
StaticPopupDialogs[DEFAULTS_CONFIRM_POPUP] = {
    text = "%s 설정을 기본값으로 복원하시겠습니까?\n\n현재 설정값이 변경됩니다.",
    button1 = "복원",
    button2 = "취소",
    OnAccept = function(_, callback)
        if type(callback) == "function" then
            callback()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function confirmDefaultsRestore(label, callback)
    StaticPopup_Show(DEFAULTS_CONFIRM_POPUP, label, nil, callback)
end

local eventFrame = CreateFrame("Frame")
local dbLoaded = false
local cursorHooked = false
local questLinkBox
local questHooksInstalled = false
local questRewardHookInstalled = false
local lastLootTime = 0
local optionsFrame
local actionBarOptionsRefresh
local autoGreetOptionsRefresh
local optionChecks = {}
local applyFeatureChange
local refreshFeatureEvents
local discordChatFiltersInstalled = false
local discordLinkHandlerInstalled = false
local discordRaidWarningButton
local discordRaidWarningSerial = 0
local recentQuestActions = {}
local pendingQuestRewardItems = {}
local questRewardAdviceSerial = 0
local pendingNameplateCVarApply = false
local softInteractNameFrame
local softInteractNameUnit
local softInteractRefreshSerial = 0
local instanceErrorsSuppressed = false
local hiddenQuestTrackerRegions = {}
local pendingQuestTrackerVisibilityUpdate = false
local questTrackerUpdateSerial = 0

local ENHANCEQOL_CHAT_HISTORY_BROKEN_VERSION = "12.3.0"

local function setupEnhanceQoLChatHistoryCompat()
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata
    if type(getMetadata) ~= "function" then
        getMetadata = GetAddOnMetadata
    end
    if type(getMetadata) ~= "function" then
        return
    end

    local version = getMetadata("EnhanceQoLChatSocial", "Version")
    if version ~= ENHANCEQOL_CHAT_HISTORY_BROKEN_VERSION then
        return
    end

    local enhanceQoL = _G.EnhanceQoL
    local channelHistory = enhanceQoL and enhanceQoL.ChatIM
        and enhanceQoL.ChatIM.ChannelHistory
    if not channelHistory or type(channelHistory.Store) ~= "function"
        or channelHistory.__mimQoLCommunityHistoryCompat then
        return
    end

    local originalStore = channelHistory.Store
    channelHistory.Store = function(self, event, ...)
        if event == "CHAT_MSG_COMMUNITIES_CHANNEL"
            and type(select(18, ...)) == "table" then
            local argumentCount = select("#", ...)
            local arguments = { ... }

            -- WoW 12.1 supplies message-info data here. EnhanceQoL 12.3.0
            -- treats it as a string community ID while building its history key.
            arguments[18] = nil
            if type(arguments[19]) ~= "string"
                and type(arguments[19]) ~= "number" then
                arguments[19] = nil
            end

            return originalStore(self, event,
                unpack(arguments, 1, argumentCount))
        end

        return originalStore(self, event, ...)
    end
    channelHistory.__mimQoLCommunityHistoryCompat = true
end

local function printMessage(message)
    print("|cffffd100[MimQoL]|r " .. tostring(message))
end

local function isSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function loadDB()
    MimQoLDB = type(MimQoLDB) == "table" and MimQoLDB or {}
    -- Before 0.8.15 autoGreet was a master switch and manual mode suppressed
    -- automatic sends. Preserve the effective old mode once, then allow both.
    if not MimQoLDB.greetModesIndependent then
        if MimQoLDB.greetManualMode == true then
            MimQoLDB.greetManualMode = MimQoLDB.autoGreet ~= false
            MimQoLDB.autoGreet = false
        end
        MimQoLDB.greetModesIndependent = true
    end
    -- Chat sounds were an ID with an optional overriding file before the
    -- built-in/file/ID choice existed. Keep whatever was actually playing.
    if MimQoLDB.chatSoundType == nil and MimQoLDB.chatSoundGuild ~= nil then
        if type(MimQoLDB.chatSoundFile) == "string" and MimQoLDB.chatSoundFile ~= "" then
            MimQoLDB.chatSoundType = "custom"
        elseif MimQoLDB.chatSoundID ~= nil and MimQoLDB.chatSoundID ~= DEFAULTS.chatSoundID then
            MimQoLDB.chatSoundType = "id"
        end
    end
    -- The Argus buff lasts 25 s; the first release guessed 15. Replace that
    -- unedited guess once, keeping any other value the user typed.
    if not MimQoLDB.argusTrackerDuration25 then
        if MimQoLDB.argusTrackerDuration == 15 then MimQoLDB.argusTrackerDuration = 25 end
        MimQoLDB.argusTrackerDuration25 = true
    end
    for key, value in pairs(DEFAULTS) do
        if MimQoLDB[key] == nil then
            MimQoLDB[key] = value
        end
    end

    -- A short-lived whisper sound option muted the game's own whisper ding
    -- (file 567421) while it was on. Release that mute once as it goes away.
    if MimQoLDB.chatSoundWhisper == true and type(UnmuteSoundFile) == "function" then
        pcall(UnmuteSoundFile, 567421)
    end
    for _, key in ipairs(REMOVED_SETTINGS) do
        MimQoLDB[key] = nil
    end

    dbLoaded = true
end

local function enabled(key)
    return dbLoaded and MimQoLDB[key] ~= false
end

local function setEvent(event, shouldRegister)
    if shouldRegister then
        eventFrame:RegisterEvent(event)
    else
        eventFrame:UnregisterEvent(event)
    end
end

local function refreshRegenEventRegistration()
    setEvent("PLAYER_REGEN_ENABLED", pendingNameplateCVarApply
        or pendingQuestTrackerVisibilityUpdate)
end

local function inDungeonOrRaid()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local inInstance, instanceType = IsInInstance()
    if isSecretValue(inInstance) or isSecretValue(instanceType) then
        return false
    end
    return inInstance == true
        and (instanceType == "party" or instanceType == "raid")
end

local function inRaidOrMythicPlus()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local inInstance, instanceType = IsInInstance()
    if isSecretValue(inInstance) or isSecretValue(instanceType)
        or inInstance ~= true then
        return false
    end
    if instanceType == "raid" then
        return true
    end
    if instanceType ~= "party" then
        return false
    end

    if C_ChallengeMode
        and type(C_ChallengeMode.IsChallengeModeActive) == "function" then
        local ok, active = pcall(C_ChallengeMode.IsChallengeModeActive)
        if ok and not isSecretValue(active) and active == true then
            return true
        end
    end
    if C_ChallengeMode
        and type(C_ChallengeMode.GetActiveChallengeMapID) == "function" then
        local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
        if ok and not isSecretValue(mapID)
            and type(mapID) == "number" and mapID > 0 then
            return true
        end
    end
    if C_ChallengeMode
        and type(C_ChallengeMode.HasSlottedKeystone) == "function" then
        local ok, hasSlottedKeystone = pcall(
            C_ChallengeMode.HasSlottedKeystone)
        if ok and not isSecretValue(hasSlottedKeystone)
            and hasSlottedKeystone == true then
            return true
        end
    end

    if type(GetInstanceInfo) == "function" then
        local ok, _, _, difficultyID = pcall(GetInstanceInfo)
        local challengeDifficultyID = Enum and Enum.Difficulty
            and Enum.Difficulty.DungeonChallenge or 8
        if ok and not isSecretValue(difficultyID)
            and difficultyID == challengeDifficultyID then
            return true
        end
    end
    return false
end

local function updateInstanceErrorMessages()
    local errorsFrame = _G.UIErrorsFrame
    if not errorsFrame then
        return
    end

    local shouldSuppress = enabled("hideInstanceErrors")
        and inDungeonOrRaid()
    if shouldSuppress then
        if not instanceErrorsSuppressed
            and type(errorsFrame.UnregisterEvent) == "function" then
            local isRegistered = true
            if type(errorsFrame.IsEventRegistered) == "function" then
                isRegistered = errorsFrame:IsEventRegistered("UI_ERROR_MESSAGE")
            end
            if isRegistered then
                errorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
                instanceErrorsSuppressed = true
            end
        end
    elseif instanceErrorsSuppressed then
        if type(errorsFrame.RegisterEvent) == "function" then
            errorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
        end
        instanceErrorsSuppressed = false
    end
end

local QUEST_TRACKER_MODULES = {
    "QuestObjectiveTracker",
    "CampaignQuestObjectiveTracker",
}

-- Do not remove modules from ObjectiveTrackerManager here. That forces the
-- UIParent managed-frame layout and can reach protected unit frames in combat.
local function regionIsShown(region)
    if not region or type(region.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(region.IsShown, region)
    return ok and shown == true
end

local function setRegionShown(region, shown)
    if not region then
        return
    end
    local method = shown and region.Show or region.Hide
    if type(method) == "function" then
        pcall(method, region)
    end
end

local function hideQuestTrackerModule(name)
    local module = _G[name]
    if not module then
        return false
    end

    local header = module.Header
    local contents = module.ContentsFrame
    if not header and not contents then
        return false
    end

    if not hiddenQuestTrackerRegions[name] then
        hiddenQuestTrackerRegions[name] = {
            headerShown = regionIsShown(header),
            contentsShown = regionIsShown(contents),
        }
    end
    setRegionShown(header, false)
    setRegionShown(contents, false)
    return true
end

local function restoreQuestTrackerModule(name)
    local saved = hiddenQuestTrackerRegions[name]
    if not saved then
        return true
    end

    local module = _G[name]
    if not module then
        hiddenQuestTrackerRegions[name] = nil
        return true
    end

    setRegionShown(module.Header, saved.headerShown)
    setRegionShown(module.ContentsFrame, saved.contentsShown)
    hiddenQuestTrackerRegions[name] = nil
    return true
end

local function updateQuestTrackerVisibility()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        pendingQuestTrackerVisibilityUpdate = true
        refreshRegenEventRegistration()
        return
    end

    pendingQuestTrackerVisibilityUpdate = false
    local shouldHide = enabled("hideQuestTrackerInInstances")
        and inRaidOrMythicPlus()
    for _, name in ipairs(QUEST_TRACKER_MODULES) do
        if shouldHide then
            hideQuestTrackerModule(name)
        else
            restoreQuestTrackerModule(name)
        end
    end
    refreshRegenEventRegistration()
end

local function queueQuestTrackerVisibilityUpdate()
    questTrackerUpdateSerial = questTrackerUpdateSerial + 1
    local serial = questTrackerUpdateSerial
    updateQuestTrackerVisibility()

    if not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end
    local function updateIfCurrent()
        if serial == questTrackerUpdateSerial then
            updateQuestTrackerVisibility()
        end
    end
    C_Timer.After(0, updateIfCurrent)
    C_Timer.After(1, updateIfCurrent)
end

--------------------------------------------------------------------------------
-- Nameplate quality of life
--------------------------------------------------------------------------------

local NAMEPLATE_CVAR_GROUPS = {
    softInteractObjects = {
        { "SoftTargetInteract", "3" },
        { "SoftTargetIconGameObject", "1" },
        { "SoftTargetIconInteract", "1" },
        { "SoftTargetNameplateInteract", "0" },
    },
    quickHideDeadNameplates = {
        { "nameplateRemovalAnimation", "0" },
    },
}

local function getCVarValue(cvar)
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) ~= "function" then
        return nil
    end

    local ok, value = pcall(getter, cvar)
    if not ok or isSecretValue(value) then
        return nil
    end
    return value
end

local function setCVarValue(cvar, value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then
        return
    end

    local current = getCVarValue(cvar)
    if current ~= nil and tostring(current) == tostring(value) then
        return
    end
    pcall(setter, cvar, value)
end

local function applyNameplateCVarGroup(key, definitions)
    MimQoLDB.nameplateCVarBackups =
        type(MimQoLDB.nameplateCVarBackups) == "table"
        and MimQoLDB.nameplateCVarBackups or {}
    local backups = MimQoLDB.nameplateCVarBackups

    if enabled(key) then
        local groupBackup = backups[key]
        if type(groupBackup) ~= "table" then
            groupBackup = {}
            backups[key] = groupBackup
            for _, definition in ipairs(definitions) do
                local cvar = definition[1]
                local value = getCVarValue(cvar)
                if value ~= nil then
                    groupBackup[cvar] = value
                end
            end
        end

        for _, definition in ipairs(definitions) do
            setCVarValue(definition[1], definition[2])
        end
    else
        local groupBackup = backups[key]
        if type(groupBackup) == "table" then
            for cvar, value in pairs(groupBackup) do
                setCVarValue(cvar, value)
            end
            backups[key] = nil
        end
    end
end

local function applyNameplateCVars()
    if not dbLoaded then
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        pendingNameplateCVarApply = true
        refreshRegenEventRegistration()
        return
    end

    pendingNameplateCVarApply = false
    for key, definitions in pairs(NAMEPLATE_CVAR_GROUPS) do
        applyNameplateCVarGroup(key, definitions)
    end
    refreshRegenEventRegistration()
end

local function hideSoftInteractObjectName()
    softInteractNameUnit = nil
    if softInteractNameFrame then
        softInteractNameFrame:Hide()
        softInteractNameFrame:ClearAllPoints()
        softInteractNameFrame:SetParent(UIParent)
    end
end

local function getSoftInteractNameFrame()
    if softInteractNameFrame then
        return softInteractNameFrame
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(260, 24)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetWidth(260)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    frame.Text = text
    frame:Hide()
    softInteractNameFrame = frame
    return frame
end

local function isForbiddenObject(object)
    if isSecretValue(object) or not object then
        return true
    end

    local checker = object.IsForbidden
    if isSecretValue(checker) then
        return true
    end
    if type(checker) ~= "function" then
        return false
    end

    local ok, forbidden = pcall(checker, object)
    if not ok or isSecretValue(forbidden) then
        return true
    end
    return forbidden == true
end

local function frameHasVisibleName(frame, unitName, depth)
    if isSecretValue(frame) or not frame
        or frame == softInteractNameFrame or depth > 5
        or isForbiddenObject(frame) then
        return false
    end

    if type(frame.GetRegions) == "function" then
        local regionResults = { pcall(frame.GetRegions, frame) }
        if regionResults[1] then
            for index = 2, #regionResults do
                local region = regionResults[index]
                if not isSecretValue(region) and region
                    and not isForbiddenObject(region)
                    and type(region.IsVisible) == "function"
                    and type(region.GetText) == "function" then
                    local visibleOK, isVisible = pcall(region.IsVisible, region)
                    if visibleOK and not isSecretValue(isVisible) and isVisible then
                        local textOK, text = pcall(region.GetText, region)
                        if textOK and not isSecretValue(text)
                            and type(text) == "string" and text == unitName then
                            return true
                        end
                    end
                end
            end
        end
    end

    if type(frame.GetChildren) == "function" then
        local childResults = { pcall(frame.GetChildren, frame) }
        if childResults[1] then
            for index = 2, #childResults do
                if frameHasVisibleName(childResults[index], unitName, depth + 1) then
                    return true
                end
            end
        end
    end
    return false
end

local function findSoftInteractGameObject()
    if type(UnitIsUnit) ~= "function" or type(UnitIsGameObject) ~= "function" then
        return nil
    end

    for index = 1, 40 do
        local unit = "nameplate" .. index
        local isSoftInteract = UnitIsUnit(unit, "softinteract")
        if not isSecretValue(isSoftInteract) and isSoftInteract then
            local isGameObject = UnitIsGameObject(unit)
            if not isSecretValue(isGameObject) and isGameObject then
                return unit
            end
        end
    end
    return nil
end

local function updateSoftInteractObjectName()
    hideSoftInteractObjectName()
    if not enabled("softInteractObjects") or not C_NamePlate
        or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
        return
    end

    local unit = findSoftInteractGameObject()
    if not unit then
        return
    end

    local unitName = UnitName(unit)
    if isSecretValue(unitName) or type(unitName) ~= "string" or unitName == "" then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if isSecretValue(nameplate) or not nameplate
        or isForbiddenObject(nameplate)
        or frameHasVisibleName(nameplate, unitName, 0) then
        return
    end

    local frame = getSoftInteractNameFrame()
    frame:SetParent(nameplate)
    frame:SetFrameLevel((nameplate:GetFrameLevel() or 0) + 50)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", nameplate, "TOP", 0, 4)
    frame.Text:SetText(unitName)
    frame:Show()
    softInteractNameUnit = unit
end

local function queueSoftInteractObjectName()
    softInteractRefreshSerial = softInteractRefreshSerial + 1
    local serial = softInteractRefreshSerial
    if not enabled("softInteractObjects") then
        hideSoftInteractObjectName()
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if serial == softInteractRefreshSerial then
                updateSoftInteractObjectName()
            end
        end)
    else
        updateSoftInteractObjectName()
    end
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

local function setupCursorTooltip()
    if cursorHooked then
        return
    end
    cursorHooked = true

    if WorldFrame then
        if type(WorldFrame.SetMouseMotionEnabled) == "function" then
            WorldFrame:SetMouseMotionEnabled(true)
        elseif type(WorldFrame.EnableMouseMotion) == "function" then
            WorldFrame:EnableMouseMotion(true)
        end
    end

    if type(GameTooltip_SetDefaultAnchor) == "function" then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            if not enabled("cursorTooltip") or not tooltip
                or type(tooltip.SetOwner) ~= "function" then
                return
            end

            tooltip:SetOwner(parent or WorldFrame or UIParent,
                "ANCHOR_CURSOR_RIGHT", 0, 0)
        end)
    end
end

local function setControlEnabled(control, shouldEnable)
    if not control then
        return
    end
    if type(control.SetEnabled) == "function" then
        control:SetEnabled(shouldEnable)
    elseif shouldEnable and type(control.Enable) == "function" then
        control:Enable()
    elseif not shouldEnable and type(control.Disable) == "function" then
        control:Disable()
    end
end

local function refreshOptionsFrame()
    if not optionsFrame then
        return
    end

    for key, check in pairs(optionChecks) do
        check:SetChecked(enabled(key))
    end
    if actionBarOptionsRefresh then
        actionBarOptionsRefresh()
    end
    if autoGreetOptionsRefresh then
        autoGreetOptionsRefresh()
    end
    if _G.MimQoLCooldownReminder and _G.MimQoLCooldownReminder.RefreshConfig then
        _G.MimQoLCooldownReminder.RefreshConfig()
    end
end

local function saveOptionsPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    MimQoLDB.windowPoint = point
    MimQoLDB.windowRelativePoint = relativePoint
    MimQoLDB.windowX = x
    MimQoLDB.windowY = y
end

local function attachOptionsWindowDrag(window, target)
    target:EnableMouse(true)
    target:RegisterForDrag("LeftButton")
    target:SetScript("OnDragStart", function()
        window:StartMoving()
    end)
    target:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        saveOptionsPosition(window)
    end)
end

--------------------------------------------------------------------------------
-- Options window skin
--------------------------------------------------------------------------------

local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local FLAT_BACKDROP = {
    bgFile = FLAT_TEXTURE,
    edgeFile = FLAT_TEXTURE,
    edgeSize = 1,
}
local FLAT_STYLE = {
    window = { 0.04, 0.04, 0.06, 0.88 },
    panel = { 0.02, 0.02, 0.035, 0.55 },
    field = { 0.025, 0.025, 0.04, 0.82 },
    button = { 0.08, 0.07, 0.10, 0.78 },
    hover = { 0.18, 0.15, 0.06, 0.88 },
    selected = { 0.14, 0.11, 0.03, 0.95 },
    border = { 0.32, 0.28, 0.16, 1 },
    borderMuted = { 0.16, 0.15, 0.13, 0.85 },
    gold = { 1, 0.82, 0, 1 },
    text = { 0.90, 0.90, 0.92, 1 },
    mutedText = { 0.68, 0.68, 0.72, 1 },
}

local function setBackdropColors(frame, background, border)
    frame:SetBackdrop(FLAT_BACKDROP)
    frame:SetBackdropColor(
        background[1], background[2], background[3], background[4])
    frame:SetBackdropBorderColor(
        border[1], border[2], border[3], border[4])
end

local function createFlatPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetFrameLevel(parent:GetFrameLevel())
    setBackdropColors(panel, FLAT_STYLE.panel, FLAT_STYLE.borderMuted)
    panel:EnableMouse(false)
    return panel
end

local function refreshFlatButton(button)
    local background = FLAT_STYLE.button
    local border = FLAT_STYLE.borderMuted
    local text = FLAT_STYLE.text
    if button.MimQoLSelected then
        background = FLAT_STYLE.selected
        border = FLAT_STYLE.gold
        text = FLAT_STYLE.gold
    elseif button.MimQoLPressed or button.MimQoLHovered then
        background = FLAT_STYLE.hover
        border = FLAT_STYLE.border
    end

    setBackdropColors(button, background, border)
    if button.MimQoLLabel then
        button.MimQoLLabel:SetTextColor(text[1], text[2], text[3], text[4])
    end
end

local function styleFlatButton(button, fontObject)
    local label = button:CreateFontString(
        nil, "OVERLAY", fontObject or "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    button:SetFontString(label)
    button.MimQoLLabel = label
    button:SetScript("OnEnter", function(self)
        self.MimQoLHovered = true
        refreshFlatButton(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.MimQoLHovered = false
        self.MimQoLPressed = false
        refreshFlatButton(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        self.MimQoLPressed = true
        refreshFlatButton(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.MimQoLPressed = false
        refreshFlatButton(self)
    end)
    refreshFlatButton(button)
end

local function setFlatButtonSelected(button, selected)
    button.MimQoLSelected = selected and true or false
    refreshFlatButton(button)
end

local function styleFlatEditBox(editBox)
    setBackdropColors(editBox, FLAT_STYLE.field, FLAT_STYLE.borderMuted)
    editBox:SetTextColor(
        FLAT_STYLE.text[1], FLAT_STYLE.text[2], FLAT_STYLE.text[3],
        FLAT_STYLE.text[4])
    editBox:HookScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(
            FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3],
            FLAT_STYLE.gold[4])
    end)
    editBox:HookScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(
            FLAT_STYLE.borderMuted[1], FLAT_STYLE.borderMuted[2],
            FLAT_STYLE.borderMuted[3], FLAT_STYLE.borderMuted[4])
    end)
end

local function styleFlatCheckButton(check)
    setBackdropColors(check, FLAT_STYLE.field, FLAT_STYLE.borderMuted)
    check:SetCheckedTexture(FLAT_TEXTURE)
    local checked = check:GetCheckedTexture()
    checked:ClearAllPoints()
    checked:SetPoint("TOPLEFT", 4, -4)
    checked:SetPoint("BOTTOMRIGHT", -4, 4)
    checked:SetVertexColor(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 1)

    check:SetHighlightTexture(FLAT_TEXTURE)
    local highlight = check:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", 1, -1)
    highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    highlight:SetVertexColor(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.18)
end

local function createFlatScrollBar(parent, scrollFrame)
    local scrollBar = CreateFrame(
        "Slider", "MimQoLOptionsDetailScrollBar", parent,
        "BackdropTemplate")
    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -17, -45)
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -17, 20)
    scrollBar:SetWidth(8)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(1)
    setBackdropColors(scrollBar, FLAT_STYLE.field, FLAT_STYLE.borderMuted)
    scrollBar:SetThumbTexture(FLAT_TEXTURE)
    local thumb = scrollBar:GetThumbTexture()
    thumb:SetSize(12, 34)
    thumb:SetVertexColor(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.85)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
        scrollBar:SetValue(offset)
    end)
    scrollFrame.ScrollBar = scrollBar
    return scrollBar
end

local function createOptionsWindow()
    if optionsFrame then
        return
    end

    local frame = CreateFrame(
        "Frame", "MimQoLOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(780, 620)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    setBackdropColors(frame, FLAT_STYLE.window, FLAT_STYLE.border)
    attachOptionsWindowDrag(frame, frame)

    if MimQoLDB.windowPoint and tonumber(MimQoLDB.windowX)
        and tonumber(MimQoLDB.windowY) then
        frame:SetPoint(
            MimQoLDB.windowPoint, UIParent,
            MimQoLDB.windowRelativePoint or MimQoLDB.windowPoint,
            MimQoLDB.windowX, MimQoLDB.windowY)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local titleBackground = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    titleBackground:SetColorTexture(0.08, 0.065, 0.025, 0.82)
    titleBackground:SetPoint("TOPLEFT", 1, -1)
    titleBackground:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -1, -34)

    local titleLine = frame:CreateTexture(nil, "ARTWORK")
    titleLine:SetColorTexture(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.42)
    titleLine:SetPoint("TOPLEFT", 1, -34)
    titleLine:SetPoint("TOPRIGHT", -1, -34)
    titleLine:SetHeight(1)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -9)
    title:SetTextColor(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 1)
    title:SetText("MimQoL 설정  |cffb8b8b8v" .. ADDON_VERSION .. "|r")
    frame.TitleText = title

    local closeButton = CreateFrame(
        "Button", nil, frame, "BackdropTemplate")
    closeButton:SetPoint("TOPRIGHT", -6, -5)
    closeButton:SetSize(24, 24)
    styleFlatButton(closeButton, "GameFontNormalLarge")
    closeButton:SetText("X")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local sidebar = createFlatPanel(frame)
    sidebar:SetPoint("TOPLEFT", 12, -38)
    sidebar:SetPoint("BOTTOMLEFT", 12, 12)
    sidebar:SetWidth(180)
    attachOptionsWindowDrag(frame, sidebar)

    local detailPanel = createFlatPanel(frame)
    detailPanel:SetPoint("TOPLEFT", 204, -38)
    detailPanel:SetPoint("BOTTOMRIGHT", -12, 12)
    attachOptionsWindowDrag(frame, detailPanel)

    local searchLabel = frame:CreateFontString(
        nil, "ARTWORK", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", 24, -42)
    searchLabel:SetText("설정 검색")

    local searchBox = CreateFrame(
        "EditBox", "MimQoLOptionsSearchBox", frame, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", 20, -60)
    searchBox:SetSize(164, 24)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(_G.GameFontHighlightSmall)
    searchBox:SetTextInsets(8, 8, 0, 0)
    styleFlatEditBox(searchBox)

    local instructions = searchBox:CreateFontString(
        nil, "ARTWORK", "GameFontDisableSmall")
    instructions:SetPoint("LEFT", 8, 0)
    instructions:SetText("이름이나 설명 검색")
    searchBox.Instructions = instructions
    local function updateSearchInstructions(self)
        instructions:SetShown(not self:HasFocus() and self:GetText() == "")
    end
    searchBox:HookScript("OnTextChanged", updateSearchInstructions)
    searchBox:HookScript("OnEditFocusGained", updateSearchInstructions)
    searchBox:HookScript("OnEditFocusLost", updateSearchInstructions)

    local categoryLabel = frame:CreateFontString(
        nil, "ARTWORK", "GameFontNormal")
    categoryLabel:SetPoint("TOPLEFT", 24, -100)
    categoryLabel:SetText("카테고리")

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(
        FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.30)
    divider:SetPoint("TOPLEFT", 196, -35)
    divider:SetPoint("BOTTOMLEFT", 196, 14)
    divider:SetWidth(1)

    local scrollFrame = CreateFrame(
        "ScrollFrame", "MimQoLOptionsDetailScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", 212, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 14)
    scrollFrame:EnableMouseWheel(true)
    attachOptionsWindowDrag(frame, scrollFrame)
    local scrollBar = createFlatScrollBar(frame, scrollFrame)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(520, 1)
    scrollFrame:SetScrollChild(content)

    local categoryViews = {}
    local categoryByKey = {}
    local categoryButtons = {}
    local selectedCategoryKey = "actionbar"
    local layoutOptionsContent

    local noResults = content:CreateFontString(
        nil, "ARTWORK", "GameFontHighlight")
    noResults:SetPoint("TOPLEFT", 12, -18)
    noResults:SetWidth(490)
    noResults:SetJustifyH("LEFT")
    noResults:SetText("검색 결과가 없습니다.")
    noResults:Hide()

    local function normalizedSearchText(value)
        value = type(value) == "string" and value or ""
        value = value:match("^%s*(.-)%s*$") or ""
        return value:lower()
    end

    local function restoreDefaultValues(keys)
        local changed = {}
        if keys then
            for _, key in ipairs(keys) do
                MimQoLDB[key] = DEFAULTS[key]
                changed[key] = true
            end
        else
            for key, value in pairs(DEFAULTS) do
                MimQoLDB[key] = value
                changed[key] = true
            end
        end

        for _, key in ipairs(FEATURE_OPTIONS) do
            if changed[key] then
                applyFeatureChange(key)
            end
        end
        refreshOptionsFrame()
    end

    local function createCategory(
        key, titleText, descriptionText, defaultKeys)
        local panel = CreateFrame("Frame", nil, content)
        panel:SetWidth(520)
        panel:Hide()

        local title = panel:CreateFontString(
            nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 0, 0)
        title:SetText(titleText)

        local description = panel:CreateFontString(
            nil, "ARTWORK", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", 0, -27)
        description:SetWidth(500)
        description:SetJustifyH("LEFT")
        description:SetTextColor(0.78, 0.78, 0.78, 1)
        description:SetText(descriptionText)

        local category = {
            key = key,
            titleText = titleText,
            descriptionText = descriptionText,
            panel = panel,
            title = title,
            description = description,
            entries = {},
            defaultKeys = defaultKeys,
        }

        local defaultButton = CreateFrame(
            "Button", nil, panel, "BackdropTemplate")
        defaultButton:SetSize(180, 28)
        styleFlatButton(defaultButton)
        defaultButton:SetText("이 카테고리 기본값 복원")
        defaultButton:SetScript("OnClick", function()
            confirmDefaultsRestore(category.titleText, function()
                restoreDefaultValues(category.defaultKeys)
                printMessage(
                    category.titleText .. " 기본값을 복원했습니다.")
            end)
        end)
        defaultButton:Hide()
        category.defaultButton = defaultButton

        table.insert(categoryViews, category)
        categoryByKey[key] = category
        return category
    end

    local function addEntry(category, row, height, searchText)
        row:SetSize(520, height)
        local entry = {
            row = row,
            height = height,
            searchText = normalizedSearchText(
                category.titleText .. " " .. searchText),
        }
        table.insert(category.entries, entry)
        return entry
    end

    local featureCheckIndex = 0

    local function addCheck(category, option, checkTable, frameName, onClick)
        local row = CreateFrame("Frame", nil, category.panel)
        local hoverBackground = row:CreateTexture(nil, "BACKGROUND")
        hoverBackground:SetAllPoints()
        hoverBackground:SetColorTexture(
            FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.10)
        hoverBackground:Hide()

        local hoverAccent = row:CreateTexture(nil, "BORDER")
        hoverAccent:SetPoint("TOPLEFT", 0, 0)
        hoverAccent:SetPoint("BOTTOMLEFT", 0, 0)
        hoverAccent:SetWidth(3)
        hoverAccent:SetColorTexture(
            FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.90)
        hoverAccent:Hide()

        local check = CreateFrame(
            "CheckButton", frameName, row, "BackdropTemplate")
        check:SetPoint("TOPLEFT", 8, -4)
        check:SetSize(22, 22)
        check:SetHitRectInsets(-8, -462, -4, -24)
        styleFlatCheckButton(check)

        check.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        check.Text:SetPoint("TOPLEFT", check, "TOPRIGHT", 9, -1)
        check.Text:SetWidth(461)
        check.Text:SetJustifyH("LEFT")
        check.Text:SetText(option.label)

        local description = row:CreateFontString(
            nil, "ARTWORK", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", check, "TOPRIGHT", 9, -22)
        description:SetWidth(461)
        description:SetJustifyH("LEFT")
        description:SetTextColor(0.72, 0.72, 0.72, 1)
        description:SetText(option.description)

        local function setRowHovered(hovered)
            hoverBackground:SetShown(hovered)
            hoverAccent:SetShown(hovered)
            if hovered then
                check:SetBackdropBorderColor(
                    FLAT_STYLE.gold[1], FLAT_STYLE.gold[2],
                    FLAT_STYLE.gold[3], 0.85)
                check.Text:SetTextColor(
                    FLAT_STYLE.gold[1], FLAT_STYLE.gold[2],
                    FLAT_STYLE.gold[3], 1)
                description:SetTextColor(0.86, 0.80, 0.52, 1)
            else
                check:SetBackdropBorderColor(
                    FLAT_STYLE.borderMuted[1], FLAT_STYLE.borderMuted[2],
                    FLAT_STYLE.borderMuted[3], FLAT_STYLE.borderMuted[4])
                check.Text:SetTextColor(
                    FLAT_STYLE.text[1], FLAT_STYLE.text[2],
                    FLAT_STYLE.text[3], FLAT_STYLE.text[4])
                description:SetTextColor(0.72, 0.72, 0.72, 1)
            end
        end
        check:SetScript("OnEnter", function()
            setRowHovered(true)
        end)
        check:SetScript("OnLeave", function()
            setRowHovered(false)
        end)

        check:SetScript("OnClick", function(self)
            MimQoLDB[option.key] = self:GetChecked() and true or false
            onClick(option.key)
            refreshOptionsFrame()
        end)
        checkTable[option.key] = check

        local rowHeight = math.max(
            52, 30 + math.max(14, description:GetStringHeight()))
        addEntry(
            category, row, rowHeight,
            option.label .. " " .. option.description)
    end

    local function addFeatureOption(category, key)
        featureCheckIndex = featureCheckIndex + 1
        addCheck(category, {
            key = key,
            label = LABELS[key],
            description = DESCRIPTIONS[key],
        }, optionChecks, "MimQoLOptionCheck" .. featureCheckIndex,
        function(changedKey)
            applyFeatureChange(changedKey)
        end)
    end

    local actionBarCategory = createCategory(
        "actionbar", "공용 행동단축바",
        "현재 직업의 전문화나 특성을 바꿔도 그대로 유지할 행동단축바를 정합니다.",
        nil)
    actionBarCategory.hideDefaultButton = true

    local actionBarRow = CreateFrame("Frame", nil, actionBarCategory.panel)
    local contextText = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontNormalLarge")
    contextText:SetPoint("TOPLEFT", 8, -4)
    contextText:SetWidth(492)
    contextText:SetJustifyH("LEFT")

    local scopeText = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontHighlightSmall")
    scopeText:SetPoint("TOPLEFT", contextText, "BOTTOMLEFT", 0, -7)
    scopeText:SetWidth(492)
    scopeText:SetJustifyH("LEFT")
    scopeText:SetTextColor(0.72, 0.72, 0.72, 1)

    local countText = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontNormal")
    countText:SetPoint("TOPLEFT", 8, -62)
    countText:SetWidth(492)
    countText:SetJustifyH("LEFT")

    local selectBarsButton = CreateFrame(
        "Button", nil, actionBarRow, "BackdropTemplate")
    selectBarsButton:SetPoint("TOPLEFT", 8, -88)
    selectBarsButton:SetSize(250, 32)
    styleFlatButton(selectBarsButton)
    selectBarsButton:SetText("화면에서 행동단축바 선택")

    local selectionHint = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontHighlightSmall")
    selectionHint:SetPoint("LEFT", selectBarsButton, "RIGHT", 12, 0)
    selectionHint:SetWidth(225)
    selectionHint:SetJustifyH("LEFT")
    selectionHint:SetTextColor(0.72, 0.72, 0.72, 1)
    selectionHint:SetText("바를 클릭해 지정하고 ESC로 돌아옵니다.")

    local listTitle = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 8, -142)
    listTitle:SetText("현재 공용으로 지정된 바")

    local emptyText = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", 18, -172)
    emptyText:SetText("아직 지정된 행동단축바가 없습니다.")

    local selectedBarRows = {}
    for index = 1, 13 do
        local barRow = CreateFrame("Frame", nil, actionBarRow)
        barRow:SetPoint("TOPLEFT", 8, -166 - (index - 1) * 30)
        barRow:SetSize(492, 27)

        local background = barRow:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.08, 0.08, 0.12, 0.72)

        local accent = barRow:CreateTexture(nil, "BORDER")
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("BOTTOMLEFT")
        accent:SetWidth(3)
        accent:SetColorTexture(
            FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 0.80)

        local label = barRow:CreateFontString(
            nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", 12, 0)
        label:SetWidth(390)
        label:SetJustifyH("LEFT")

        local removeButton = CreateFrame(
            "Button", nil, barRow, "BackdropTemplate")
        removeButton:SetPoint("RIGHT", -3, 0)
        removeButton:SetSize(66, 22)
        styleFlatButton(removeButton, "GameFontHighlightSmall")
        removeButton:SetText("해제")
        removeButton:SetScript("OnClick", function(self)
            if self.barKey and _G.MimQoLActionBarKeeper_RemoveBar then
                _G.MimQoLActionBarKeeper_RemoveBar(self.barKey)
                refreshOptionsFrame()
                if layoutOptionsContent then
                    layoutOptionsContent(false)
                end
            end
        end)

        barRow.Label = label
        barRow.RemoveButton = removeButton
        selectedBarRows[index] = barRow
    end

    local restoreButton = CreateFrame(
        "Button", nil, actionBarRow, "BackdropTemplate")
    restoreButton:SetSize(156, 30)
    styleFlatButton(restoreButton)
    restoreButton:SetText("지금 다시 적용")
    restoreButton:SetScript("OnClick", function()
        if _G.MimQoLActionBarKeeper_RestoreNow then
            _G.MimQoLActionBarKeeper_RestoreNow()
            refreshOptionsFrame()
        end
    end)

    local undoButton = CreateFrame(
        "Button", nil, actionBarRow, "BackdropTemplate")
    undoButton:SetSize(184, 30)
    styleFlatButton(undoButton)
    undoButton:SetText("마지막 복원 되돌리기")
    undoButton:SetScript("OnClick", function()
        if _G.MimQoLActionBarKeeper_Undo then
            _G.MimQoLActionBarKeeper_Undo()
            refreshOptionsFrame()
        end
    end)

    local safetyText = actionBarRow:CreateFontString(
        nil, "ARTWORK", "GameFontHighlightSmall")
    safetyText:SetWidth(492)
    safetyText:SetJustifyH("LEFT")
    safetyText:SetTextColor(0.68, 0.68, 0.68, 1)
    safetyText:SetText(
        "평소 이 바의 내용을 바꾸면 새 공용 상태로 자동 반영됩니다. 전투 중에는 변경하지 않습니다.")

    local actionBarEntry = addEntry(
        actionBarCategory, actionBarRow, 300,
        "행동 단축바 공용 전문화 특성 선택 복원 되돌리기")

    selectBarsButton:SetScript("OnClick", function()
        local startSelection = _G.MimQoLActionBarKeeper_StartSelection
        if not startSelection then
            printMessage("공용 행동단축바 모듈을 불러오지 못했습니다.")
            return
        end
        local started = startSelection(function()
            refreshOptionsFrame()
            frame:Show()
        end)
        if started then
            frame:Hide()
        end
    end)

    -- Class-shared character macros (MacroKeeper.lua)
    local macroRow = CreateFrame("Frame", nil, actionBarCategory.panel)
    local macroTitle = macroRow:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    macroTitle:SetPoint("TOPLEFT", 8, -4)
    macroTitle:SetText("직업 공용 매크로")
    local macroText = macroRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    macroText:SetPoint("TOPLEFT", 8, -30)
    macroText:SetWidth(492)
    macroText:SetJustifyH("LEFT")
    local macroStatus = macroRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    macroStatus:SetPoint("TOPLEFT", 8, -128)
    macroStatus:SetWidth(492)
    macroStatus:SetJustifyH("LEFT")
    macroStatus:SetTextColor(FLAT_STYLE.gold[1], FLAT_STYLE.gold[2], FLAT_STYLE.gold[3], 1)
    local function macroCall(name)
        local keeper = _G.MimQoLMacroKeeper
        if not keeper or not keeper[name] then return end
        local _, message = keeper[name]()
        macroStatus:SetText(message or "")
        refreshOptionsFrame()
    end
    StaticPopupDialogs["MIMQOL_MACRO_APPLY"] = {
        text = "저장된 직업 공용 매크로를 이 캐릭터에 적용할까요?\n이름이 같은 캐릭터 전용 매크로는 저장된 내용으로 바뀌고, 없는 것은 새로 만듭니다. 적용 전 상태는 되돌릴 수 있게 보관합니다.",
        button1 = "적용",
        button2 = "취소",
        OnAccept = function() macroCall("Apply") end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    local macroSaveButton = CreateFrame("Button", nil, macroRow, "BackdropTemplate")
    macroSaveButton:SetPoint("TOPLEFT", 8, -88)
    macroSaveButton:SetSize(180, 30)
    styleFlatButton(macroSaveButton)
    macroSaveButton:SetText("이 캐릭터 매크로 저장")
    macroSaveButton:SetScript("OnClick", function() macroCall("Save") end)
    local macroApplyButton = CreateFrame("Button", nil, macroRow, "BackdropTemplate")
    macroApplyButton:SetPoint("LEFT", macroSaveButton, "RIGHT", 10, 0)
    macroApplyButton:SetSize(156, 30)
    styleFlatButton(macroApplyButton)
    macroApplyButton:SetText("이 캐릭터에 적용")
    macroApplyButton:SetScript("OnClick", function() StaticPopup_Show("MIMQOL_MACRO_APPLY") end)
    local macroUndoButton = CreateFrame("Button", nil, macroRow, "BackdropTemplate")
    macroUndoButton:SetPoint("LEFT", macroApplyButton, "RIGHT", 10, 0)
    macroUndoButton:SetSize(136, 30)
    styleFlatButton(macroUndoButton)
    macroUndoButton:SetText("적용 되돌리기")
    macroUndoButton:SetScript("OnClick", function() macroCall("Undo") end)
    addEntry(actionBarCategory, macroRow, 150, "매크로 공용 직업 부캐 복사 저장 적용 되돌리기")

    local function refreshMacroRow()
        local keeper = _G.MimQoLMacroKeeper
        local status = keeper and keeper.GetStatus() or {}
        local className = status.className or "현재 직업"
        local source = status.savedBy and (status.savedBy:match("^([^%-]+)") or status.savedBy) or nil
        if (status.savedCount or 0) > 0 then
            macroText:SetText(string.format(
                "%s 공용 매크로 |cffffd200%d개|r (저장한 캐릭터: %s). 이 캐릭터의 전용 매크로 %d개.\n같은 직업 부캐에서 [이 캐릭터에 적용]을 누르면 같은 매크로가 됩니다. 이어서 위의 [지금 다시 적용]으로 공용 행동단축바도 맞추세요. 계정 공용 매크로는 원래 함께 쓰므로 건드리지 않습니다.",
                className, status.savedCount, source or "?", status.currentCount or 0))
        else
            macroText:SetText(string.format(
                "기준이 될 %s 캐릭터에서 [이 캐릭터 매크로 저장]을 누르면, 그 캐릭터 전용 매크로를 같은 직업 부캐에 복사할 수 있습니다. 계정 공용 매크로는 원래 함께 쓰므로 건드리지 않습니다.",
                className))
        end
        local canApply = (status.savedCount or 0) > 0 and not status.isSource
        setControlEnabled(macroApplyButton, canApply)
        macroApplyButton:SetAlpha(canApply and 1 or 0.45)
        setControlEnabled(macroUndoButton, status.canUndo == true)
        macroUndoButton:SetAlpha(status.canUndo and 1 or 0.45)
    end

    actionBarOptionsRefresh = function()
        refreshMacroRow()
        local getStatus = _G.MimQoLActionBarKeeper_GetUIStatus
        local status = getStatus and getStatus() or {
            className = select(1, UnitClass("player")) or "현재 직업",
            bars = {},
            count = 0,
            canUndo = false,
        }
        local specText = status.specName and (" · 현재 " .. status.specName) or ""
        contextText:SetText((status.className or "현재 직업") .. specText)
        scopeText:SetText(string.format(
            "%s의 모든 전문화와 특성 구성에서 같은 내용으로 유지됩니다.",
            status.className or "현재 직업"))
        countText:SetText(string.format(
            "공용 행동단축바 |cffffd200%d개|r", status.count or 0))

        for index, barRow in ipairs(selectedBarRows) do
            local bar = status.bars and status.bars[index]
            barRow:SetShown(bar ~= nil)
            if bar then
                barRow.Label:SetText(bar.label)
                barRow.RemoveButton.barKey = bar.key
            else
                barRow.RemoveButton.barKey = nil
            end
        end
        emptyText:SetShown((status.count or 0) == 0)

        local listRows = math.max(1, status.count or 0)
        local controlsY = 174 + listRows * 30 + 12
        restoreButton:ClearAllPoints()
        restoreButton:SetPoint("TOPLEFT", 8, -controlsY)
        undoButton:ClearAllPoints()
        undoButton:SetPoint("LEFT", restoreButton, "RIGHT", 10, 0)
        safetyText:ClearAllPoints()
        safetyText:SetPoint("TOPLEFT", 8, -(controlsY + 45))

        local rowHeight = controlsY + 86
        actionBarEntry.height = rowHeight
        actionBarRow:SetHeight(rowHeight)
        setControlEnabled(restoreButton, (status.count or 0) > 0)
        restoreButton:SetAlpha((status.count or 0) > 0 and 1 or 0.45)
        setControlEnabled(undoButton, status.canUndo)
        undoButton:SetAlpha(status.canUndo and 1 or 0.45)
    end

    local greetingFields = {}
    local phraseEditors = {}
    local moveGreetingButton
    local movePortalButton
    local function phraseButtonLabel(text)
        text = text:gsub("[%c]", " "):match("^%s*(.-)%s*$")
        if text == "" then return "미리보기" end
        local length = tonumber(MimQoLDB.greetOverlayChars) or 8
        local count, finish = 0, #text
        for index in text:gmatch("()[%z\1-\127\194-\244]") do
            count = count + 1
            if count > length then finish = index - 1; break end
        end
        return text:sub(1, finish):gsub("|", "||") .. (finish < #text and "…" or "")
    end
    local greetingScenarios = { autoGreetParty = true, autoGreetRaid = true,
        autoGreetWelcome = true, autoGreetFullParty = true, autoGreetComplete = true }
    local overlayKeys = { "greetEntryPhrases", "greetCompletePhrases", "greetGeneralPhrases", "greetOverlayScale",
        "greetOverlayChars", "greetOverlayX", "greetOverlayY" }
    local function addOverlayOptions(category)
        local function addPhrases(setting, titleText)
            local row = CreateFrame("Frame", nil, category.panel)
            local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("TOPLEFT", 12, -4)
            label:SetText(titleText)
            local previewLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            previewLabel:SetPoint("TOPLEFT", 296, -4)
            previewLabel:SetText("버튼 미리보기")
            local editor = { rows = {}, texts = {}, rebuilding = false }
            local entry = addEntry(category, row, 78, titleText .. " 문구 입력 버튼 미리보기 추가 삭제")
            local function commit()
                MimQoLDB[setting] = table.concat(editor.texts, "\n")
                applyFeatureChange("autoGreet")
            end
            local function relayout()
                if layoutOptionsContent then layoutOptionsContent(false) end
            end
            function editor:HasFocus()
                for _, item in ipairs(self.rows) do if item.edit:HasFocus() then return true end end
                return false
            end
            function editor:ClearFocus()
                for _, item in ipairs(self.rows) do item.edit:ClearFocus() end
            end
            function editor:Add()
                self:ClearFocus()
                if #self.texts == 0 or self.texts[#self.texts] ~= "" then
                    self.texts[#self.texts + 1] = ""
                end
                self:Render()
                relayout()
                self.rows[#self.texts].edit:SetFocus()
            end
            function editor:Render()
                self.rebuilding = true
                for index, text in ipairs(self.texts) do
                    local item = self.rows[index]
                    if not item then
                        item = {}
                        self.rows[index] = item
                        item.edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
                        local edit = item.edit
                        edit.phraseSetting, edit.phraseIndex = setting, index
                        edit:SetSize(274, 28)
                        edit:SetPoint("TOPLEFT", 12, -30 - (index - 1) * 34)
                        edit:SetAutoFocus(false)
                        edit:SetFontObject(_G.GameFontHighlightSmall)
                        edit:SetTextInsets(8, 8, 0, 0)
                        edit:SetMaxBytes(255)
                        styleFlatEditBox(edit)
                        item.preview = CreateFrame("Button", nil, row, "BackdropTemplate")
                        item.preview:SetPoint("TOPLEFT", 296, -30 - (index - 1) * 34)
                        item.preview:SetSize(172, 28)
                        styleFlatButton(item.preview)
                        edit.previewButton = item.preview
                        item.preview:SetScript("OnClick", function() edit:SetFocus(); edit:HighlightText() end)
                        item.preview:SetScript("OnEnter", function(button)
                            if not GameTooltip then return end
                            GameTooltip:SetOwner(button, "ANCHOR_TOP")
                            GameTooltip:SetText(edit:GetText():gsub("|", "||"), 1, 1, 1, 1, true)
                            GameTooltip:Show()
                        end)
                        item.preview:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                        local function save()
                            if editor.rebuilding or not edit.dirty then return end
                            edit.dirty = false
                            local value = edit:GetText():gsub("[%c]", " "):match("^%s*(.-)%s*$")
                            editor.texts[index] = value
                            edit:SetText(value)
                            commit()
                        end
                        edit:SetScript("OnTextChanged", function(self, userInput)
                            item.preview:SetText(phraseButtonLabel(self:GetText()))
                            if userInput then self.dirty = true end
                        end)
                        edit:SetScript("OnEnterPressed", function(self)
                            save(); self:ClearFocus()
                            if index == #editor.texts then editor:Add()
                            else editor.rows[index + 1].edit:SetFocus() end
                        end)
                        edit:SetScript("OnEscapePressed", function(self)
                            self.dirty = false
                            self:SetText(editor.texts[index] or "")
                            self:ClearFocus()
                        end)
                        edit:HookScript("OnEditFocusLost", save)
                        edit:SetScript("OnHide", function(self) save(); self:ClearFocus() end)
                        item.remove = CreateFrame("Button", nil, row, "BackdropTemplate")
                        item.remove:SetPoint("TOPLEFT", 476, -30 - (index - 1) * 34)
                        item.remove:SetSize(28, 28)
                        styleFlatButton(item.remove)
                        item.remove:SetText("×")
                        edit.removeButton = item.remove
                        item.remove:SetScript("OnClick", function()
                            editor:ClearFocus()
                            table.remove(editor.texts, index)
                            if #editor.texts == 0 then editor.texts[1] = "" end
                            commit()
                            editor:Render()
                            relayout()
                        end)
                    end
                    item.edit.dirty = false
                    item.edit:SetText(text)
                    item.edit:SetCursorPosition(0)
                    item.edit:Show(); item.preview:Show(); item.remove:Show()
                end
                for index = #self.texts + 1, #self.rows do
                    local item = self.rows[index]
                    item.edit.dirty = false
                    item.edit:Hide(); item.preview:Hide(); item.remove:Hide()
                end
                entry.height = 40 + #self.texts * 34
                row:SetHeight(entry.height)
                self.rebuilding = false
            end
            function editor:RefreshValue()
                self.texts = {}
                local saved = MimQoLDB[setting]
                if type(saved) ~= "string" then saved = "" end
                for text in (saved:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("([^\n]*)\n") do
                    if text:find("%S") then self.texts[#self.texts + 1] = text end
                end
                if #self.texts == 0 then self.texts[1] = "" end
                self:Render()
            end
            local add = CreateFrame("Button", nil, row, "BackdropTemplate")
            add.phraseAddSetting = setting
            add:SetPoint("TOPRIGHT", -16, 0)
            add:SetSize(94, 24)
            styleFlatButton(add)
            add:SetText("+ 문구 추가")
            add:SetScript("OnClick", function() editor:Add() end)
            table.insert(phraseEditors, editor)
        end
        addPhrases("greetEntryPhrases", "입장 문구")
        addPhrases("greetCompletePhrases", "종료 문구")
        addPhrases("greetGeneralPhrases", "기타 문구")
        local row = CreateFrame("Frame", nil, category.panel)
        local specs = {
            { "greetOverlayScale", "크기 (%)", 50, 200 },
            { "greetOverlayChars", "표시 글자 수", 2, 20 },
            { "greetOverlayX", "위치 X", -10000, 10000 },
            { "greetOverlayY", "위치 Y", -10000, 10000 },
        }
        for index, spec in ipairs(specs) do
            local setting, labelText, low, high = spec[1], spec[2], spec[3], spec[4]
            local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", 12 + (index - 1) * 122, -3)
            label:SetText(labelText)
            local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            edit:SetPoint("TOPLEFT", 12 + (index - 1) * 122, -22)
            edit:SetSize(108, 26)
            edit:SetAutoFocus(false)
            edit:SetFontObject(_G.GameFontHighlightSmall)
            edit:SetTextInsets(8, 8, 0, 0)
            edit:SetMaxBytes(8)
            styleFlatEditBox(edit)
            edit.setting = setting
            local function refresh()
                edit:SetText(tostring(MimQoLDB[setting] or DEFAULTS[setting]))
                edit:SetCursorPosition(0)
            end
            local function save()
                if not edit.dirty then return end
                edit.dirty = false
                local value = tonumber(edit:GetText())
                if value and value == value then
                    MimQoLDB[setting] = math.floor(math.max(low, math.min(high, value)) + 0.5)
                    applyFeatureChange("autoGreet")
                    if setting == "greetOverlayChars" then
                        for _, editor in ipairs(phraseEditors) do
                            if not editor:HasFocus() then editor:RefreshValue() end
                        end
                    end
                end
                refresh()
            end
            edit:SetScript("OnTextChanged", function(self, userInput)
                if userInput then self.dirty = true end
            end)
            edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
            edit:SetScript("OnEscapePressed", function(self)
                self.dirty = false; refresh(); self:ClearFocus()
            end)
            edit:HookScript("OnEditFocusLost", save)
            edit:SetScript("OnHide", function(self) save(); self:ClearFocus() end)
            edit.RefreshValue = refresh
            table.insert(greetingFields, edit)
        end
        local openLabels = { entry = "입장 보기", complete = "종료 보기", general = "기타 보기" }
        for index, kind in ipairs({ "entry", "complete", "general" }) do
            local open = CreateFrame("Button", nil, row, "BackdropTemplate")
            open:SetPoint("TOPLEFT", 12 + (index - 1) * 122, -60)
            open:SetSize(112, 28)
            styleFlatButton(open)
            open:SetText(openLabels[kind])
            open:SetScript("OnClick", function()
                for _, edit in ipairs(greetingFields) do edit:ClearFocus() end
                for _, editor in ipairs(phraseEditors) do editor:ClearFocus() end
                if _G.MimQoLGreetingOverlay then _G.MimQoLGreetingOverlay.Open(kind) end
            end)
        end
        moveGreetingButton = CreateFrame("Button", nil, row, "BackdropTemplate")
        moveGreetingButton:SetPoint("TOPLEFT", 378, -60)
        moveGreetingButton:SetSize(122, 28)
        styleFlatButton(moveGreetingButton)
        moveGreetingButton:SetText("위치 이동")
        moveGreetingButton:SetScript("OnClick", function(self)
            local overlay = _G.MimQoLGreetingOverlay
            if not overlay then return end
            for _, edit in ipairs(greetingFields) do edit:ClearFocus() end
            for _, editor in ipairs(phraseEditors) do editor:ClearFocus() end
            local active = overlay.SetMoving(not overlay.IsMoving(), function()
                for _, edit in ipairs(greetingFields) do
                    if edit.setting == "greetOverlayX" or edit.setting == "greetOverlayY" then edit.RefreshValue() end
                end
            end)
            self:SetText(active and "이동 완료" or "위치 이동")
        end)
        addEntry(category, row, 104, "수동 버튼 크기 위치 X Y 글자 축약 이동 미리보기")
    end
    -- Text fields for the chat sound category. Saved on Enter, focus loss or hide.
    local function addArgusFields(category)
        local row = CreateFrame("Frame", nil, category.panel)
        local limits = {
            argusTrackerX = { -3000, 3000, 1 }, argusTrackerY = { -3000, 3000, 1 },
            argusTrackerSize = { 12, 96, 1 }, argusTrackerHold = { 0, 30, 10 },
            argusTrackerDuration = { 3, 60, 10 },
        }
        local function addField(setting, labelText, x, y, width)
            local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", x, y)
            label:SetText(labelText)
            local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            edit:SetPoint("TOPLEFT", x, y - 19)
            edit:SetSize(width, 26)
            edit:SetAutoFocus(false)
            edit:SetFontObject(_G.GameFontHighlightSmall)
            edit:SetTextInsets(8, 8, 0, 0)
            edit:SetMaxBytes(16)
            styleFlatEditBox(edit)
            edit.setting = setting
            local function refresh()
                local value = MimQoLDB[setting]
                if value == nil then value = DEFAULTS[setting] end
                edit:SetText(tostring(value))
                edit:SetCursorPosition(0)
            end
            local function save()
                if not edit.dirty then return end
                edit.dirty = false
                local value = tonumber(edit:GetText())
                if not value or value ~= value then refresh(); return end
                local limit = limits[setting]
                value = math.max(limit[1], math.min(limit[2], value))
                value = math.floor(value * limit[3] + 0.5) / limit[3]
                MimQoLDB[setting] = value
                -- Layout only: a running count must survive this edit.
                local tracker = _G.MimQoLArgusTracker
                if tracker and tracker.ApplyLayout then tracker.ApplyLayout() end
                refresh()
            end
            edit:SetScript("OnTextChanged", function(self, userInput)
                if userInput then self.dirty = true end
            end)
            edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
            edit:SetScript("OnEscapePressed", function(self)
                self.dirty = false
                refresh()
                self:ClearFocus()
            end)
            edit:HookScript("OnEditFocusLost", save)
            edit:SetScript("OnHide", function(self) save(); self:ClearFocus() end)
            edit.RefreshValue = refresh
            table.insert(greetingFields, edit)
            return edit
        end
        addField("argusTrackerX", "X (화면 중앙 기준)", 40, -3, 110)
        addField("argusTrackerY", "Y", 160, -3, 110)
        addField("argusTrackerSize", "글자 크기", 280, -3, 90)
        addField("argusTrackerHold", "종료 후 결과 유지(초)", 40, -53, 150)
        addField("argusTrackerDuration", "버프 시간(초, 전투 중 추정용)", 200, -53, 200)
        local function closeFields()
            for _, edit in ipairs(greetingFields) do
                if edit.setting and edit.setting:match("^argusTracker") then edit:ClearFocus() end
            end
        end
        local preview = CreateFrame("Button", nil, row, "BackdropTemplate")
        preview:SetPoint("TOPLEFT", 40, -106)
        preview:SetSize(150, 30)
        styleFlatButton(preview)
        preview:SetText("화면 미리보기")
        preview:SetScript("OnClick", function()
            closeFields()
            local tracker = _G.MimQoLArgusTracker
            if tracker and not tracker.Preview() then
                printMessage("아르거스 차원문 추적을 켠 뒤 미리보기를 사용하세요.")
            end
        end)
        local move = CreateFrame("Button", nil, row, "BackdropTemplate")
        move:SetPoint("LEFT", preview, "RIGHT", 8, 0)
        move:SetSize(122, 30)
        styleFlatButton(move)
        move:SetText("추적창 위치 이동")
        move:SetScript("OnClick", function(self)
            closeFields()
            local tracker = _G.MimQoLArgusTracker
            if not tracker then return end
            local function label(active)
                self:SetText(active and "이동 완료" or "추적창 위치 이동")
                for _, edit in ipairs(greetingFields) do
                    if edit.RefreshValue and edit.setting and edit.setting:match("^argusTracker") then edit:RefreshValue() end
                end
            end
            label(tracker.SetMoving(not tracker.IsMoving(), label))
        end)
        addEntry(category, row, 146, "아르거스 차원문 악마 폭군 굴단의 손 위치 X Y 글자 크기 버프 시간 미리보기 위치 이동")
    end

    local function addChatSoundFields(category)
        local row = CreateFrame("Frame", nil, category.panel)
        local function addField(setting, labelText, x, y, width, numeric)
            if labelText then
                local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                label:SetPoint("TOPLEFT", x, y)
                label:SetText(labelText)
            end
            local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            edit:SetPoint("TOPLEFT", x, y - 19)
            edit:SetSize(width, 26)
            edit:SetAutoFocus(false)
            edit:SetFontObject(_G.GameFontHighlightSmall)
            edit:SetTextInsets(8, 8, 0, 0)
            edit:SetMaxBytes(255)
            styleFlatEditBox(edit)
            edit.setting = setting
            local function refresh()
                local value = MimQoLDB[setting]
                if value == nil then value = DEFAULTS[setting] end
                edit:SetText(tostring(value))
                edit:SetCursorPosition(0)
            end
            local function save()
                if not edit.dirty then return end
                edit.dirty = false
                local value = edit:GetText()
                if numeric then
                    value = tonumber(value)
                    if not value or value ~= value then refresh(); return end
                    if setting == "chatSoundGap" then
                        value = math.floor(math.max(0, math.min(30, value)) * 10 + 0.5) / 10
                    else
                        value = math.floor(math.max(1, math.min(2147483647, value)))
                    end
                else
                    value = value:gsub("[%c|]", " "):match("^%s*(.-)%s*$")
                end
                MimQoLDB[setting] = value
                applyFeatureChange("chatSoundChannel")
                refresh()
            end
            edit:SetScript("OnTextChanged", function(self, userInput)
                if userInput then self.dirty = true end
            end)
            edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
            edit:SetScript("OnEscapePressed", function(self)
                self.dirty = false
                refresh()
                self:ClearFocus()
            end)
            edit:HookScript("OnEditFocusLost", save)
            edit:SetScript("OnHide", function(self) save(); self:ClearFocus() end)
            edit.RefreshValue = refresh
            table.insert(greetingFields, edit)
            return edit
        end
        addField("chatSoundChannels", "소리를 낼 채널 이름 또는 번호 (쉼표로 구분, 예: 거래, 2)", 40, -3, 460, false)
        local status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        local function playTest()
            for _, edit in ipairs(greetingFields) do if edit.setting and edit.setting:match("^chatSound") then edit:ClearFocus() end end
            local chat = _G.MimQoLChatSound
            if not chat then return end
            local _, message = chat.TestSound()
            status:SetText(message or "")
        end

        -- Sound: [내장] [파일] [ID] like MimDice and the cooldown reminder.
        local soundLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        soundLabel:SetPoint("TOPLEFT", 40, -58)
        soundLabel:SetText("소리 (내장 목록 / 파일 / 소리 ID)")
        local modeButtons, refreshMode = {}, nil
        local fileBox = addField("chatSoundFile", nil, 236, -58, 150, false)
        local idBox = addField("chatSoundID", nil, 236, -58, 150, true)
        local presetButton = CreateFrame("Button", nil, row, "BackdropTemplate")
        presetButton:SetPoint("TOPLEFT", 236, -77)
        presetButton:SetSize(150, 26)
        styleFlatButton(presetButton, "GameFontHighlightSmall")
        local picker
        presetButton:SetScript("OnClick", function()
            local chat = _G.MimQoLChatSound
            local presets = chat and chat.Presets and chat.Presets()
            if type(presets) ~= "table" then return end
            if not picker then
                picker = CreateFrame("Frame", nil, row, "BackdropTemplate")
                picker:SetSize(250, 300)
                picker:SetPoint("TOPLEFT", presetButton, "BOTTOMLEFT", 0, -2)
                picker:SetFrameStrata("DIALOG")
                picker:EnableMouse(true)
                setBackdropColors(picker, FLAT_STYLE.window, FLAT_STYLE.border)
                local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
                scroll:SetPoint("TOPLEFT", 6, -6)
                scroll:SetPoint("BOTTOMRIGHT", -26, 6)
                local list = CreateFrame("Frame", nil, scroll)
                list:SetSize(216, #presets * 26)
                scroll:SetScrollChild(list)
                for index, preset in ipairs(presets) do
                    local item = CreateFrame("Button", nil, list, "BackdropTemplate")
                    item:SetPoint("TOPLEFT", 0, -(index - 1) * 26)
                    item:SetSize(216, 24)
                    styleFlatButton(item, "GameFontHighlightSmall")
                    item:SetText(preset[1])
                    item:SetScript("OnClick", function()
                        MimQoLDB.chatSoundKey = preset[2]
                        picker:Hide()
                        refreshMode()
                        playTest()
                    end)
                end
                picker:Hide()
            end
            picker:SetShown(not picker:IsShown())
        end)
        local hint = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 40, -110)
        hint:SetWidth(460)
        hint:SetJustifyH("LEFT")
        hint:SetTextColor(FLAT_STYLE.mutedText[1], FLAT_STYLE.mutedText[2], FLAT_STYLE.mutedText[3])
        refreshMode = function()
            local mode = MimQoLDB.chatSoundType
            if mode ~= "custom" and mode ~= "id" then mode = "preset" end
            for _, button in ipairs(modeButtons) do setFlatButtonSelected(button, button.mode == mode) end
            presetButton:SetShown(mode == "preset")
            fileBox:SetShown(mode == "custom")
            idBox:SetShown(mode == "id")
            if picker and mode ~= "preset" then picker:Hide() end
            local name = "내장 소리 선택"
            local chat = _G.MimQoLChatSound
            for _, preset in ipairs(chat and chat.Presets and chat.Presets() or {}) do
                if preset[2] == MimQoLDB.chatSoundKey then name = preset[1]; break end
            end
            presetButton:SetText(name)
            if mode == "custom" then
                hint:SetText("파일명 예: MySound.mp3 (_retail_ 의 sound 또는 sounds 폴더, MimDice 동봉 파일명도 됩니다)")
            elseif mode == "id" then
                hint:SetText("500000 초과는 파일 ID, 나머지는 사운드 키트 ID로 재생합니다.")
            else
                hint:SetText("내장 목록에서 고르면 바로 들려줍니다.")
            end
        end
        for index, spec in ipairs({ { "preset", "내장" }, { "custom", "파일" }, { "id", "ID" } }) do
            local button = CreateFrame("Button", nil, row, "BackdropTemplate")
            button:SetPoint("TOPLEFT", 40 + (index - 1) * 64, -77)
            button:SetSize(60, 26)
            styleFlatButton(button, "GameFontHighlightSmall")
            button:SetText(spec[2])
            button.mode = spec[1]
            button:SetScript("OnClick", function()
                fileBox:ClearFocus()
                idBox:ClearFocus()
                MimQoLDB.chatSoundType = spec[1]
                refreshMode()
            end)
            modeButtons[index] = button
        end
        -- The options refresh walks the text fields; keep the mode buttons in step with it.
        local refreshFile = fileBox.RefreshValue
        fileBox.RefreshValue = function() refreshFile(); refreshMode() end
        refreshMode()

        addField("chatSoundGap", "최소 간격 초", 402, -58, 98, true)
        local test = CreateFrame("Button", nil, row, "BackdropTemplate")
        test:SetPoint("TOPLEFT", 40, -134)
        test:SetSize(150, 28)
        styleFlatButton(test)
        test:SetText("소리 듣기")
        status:SetPoint("LEFT", test, "RIGHT", 10, 0)
        status:SetWidth(300)
        status:SetJustifyH("LEFT")
        test:SetScript("OnClick", playTest)
        addEntry(category, row, 172, "채팅 소리 채널 길드 사운드 내장 ID 파일 간격")
    end

    local function addGreetingFields(category, key)
        local row = CreateFrame("Frame", nil, category.panel)
        local function addField(suffix, labelText, x, width)
            local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", x, -3)
            label:SetText(labelText)
            local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            edit:SetPoint("TOPLEFT", x, -22)
            edit:SetSize(width, 26)
            edit:SetAutoFocus(false)
            edit:SetFontObject(_G.GameFontHighlightSmall)
            edit:SetTextInsets(8, 8, 0, 0)
            edit:SetMaxBytes(suffix == "Message" and 255 or 6)
            styleFlatEditBox(edit)
            local setting = key .. suffix
            edit.setting = setting
            local function refresh()
                edit:SetText(tostring(MimQoLDB[setting] or DEFAULTS[setting]))
                edit:SetCursorPosition(0)
            end
            local function save()
                if not edit.dirty then return end
                edit.dirty = false
                local value = edit:GetText()
                if suffix == "Delay" then
                    value = tonumber(value)
                    if not value or value ~= value then refresh(); return end
                    value = math.floor(math.max(0, math.min(60, value)) * 10 + 0.5) / 10
                else
                    value = value:gsub("[%c]", " "):match("^%s*(.-)%s*$")
                end
                MimQoLDB[setting] = value
                applyFeatureChange("autoGreet")
                refresh()
            end
            edit:SetScript("OnTextChanged", function(self, userInput)
                if userInput then self.dirty = true end
            end)
            edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
            edit:SetScript("OnEscapePressed", function(self)
                self.dirty = false
                refresh()
                self:ClearFocus()
            end)
            edit:HookScript("OnEditFocusLost", save)
            edit:SetScript("OnHide", function(self) save(); self:ClearFocus() end)
            edit.RefreshValue = refresh
            table.insert(greetingFields, edit)
        end
        addField("Message", key == "autoGreetFullParty"
            and "쐐기돌 링크 뒤에 붙일 문구 (비우면 보내지 않음)"
            or "보낼 문구 (비우면 보내지 않음)", 40, 340)
        addField("Delay", "대기 초 (예: 1.5)", 392, 108)
        addEntry(category, row, 64, LABELS[key] .. " 문구 메시지 대기 시간 지연 초")
    end
    autoGreetOptionsRefresh = function()
        for _, edit in ipairs(greetingFields) do
            if not edit:HasFocus() then
                edit.dirty = false
                edit.RefreshValue()
            end
        end
        for _, editor in ipairs(phraseEditors) do
            if not editor:HasFocus() then editor:RefreshValue() end
        end
        if moveGreetingButton then
            local overlay = _G.MimQoLGreetingOverlay
            moveGreetingButton:SetText(overlay and overlay.IsMoving() and "이동 완료" or "위치 이동")
        end
        if movePortalButton then
            local portal = _G.MimQoLDungeonPortal
            movePortalButton:SetText(portal and portal.IsMoving() and "이동 완료" or "위치 이동")
        end
        if layoutOptionsContent then layoutOptionsContent(false) end
    end

    for _, definition in ipairs(FEATURE_CATEGORIES) do
        local defaultKeys = {}
        for _, key in ipairs(definition.options) do
            table.insert(defaultKeys, key)
            if greetingScenarios[key] then
                table.insert(defaultKeys, key .. "Message")
                table.insert(defaultKeys, key .. "Delay")
            end
        end
        if definition.key == "greetings" then
            for _, key in ipairs(overlayKeys) do table.insert(defaultKeys, key) end
        end
        if definition.key == "dungeons" then
            table.insert(defaultKeys, "dungeonPortalX")
            table.insert(defaultKeys, "dungeonPortalY")
        end
        if definition.key == "combat" then
            for _, key in ipairs({ "argusTrackerX", "argusTrackerY", "argusTrackerSize", "argusTrackerHold",
                "argusTrackerDuration" }) do
                table.insert(defaultKeys, key)
            end
        end
        if definition.key == "chatSound" then
            for _, key in ipairs({ "chatSoundChannels", "chatSoundType", "chatSoundKey",
                "chatSoundID", "chatSoundFile", "chatSoundGap" }) do
                table.insert(defaultKeys, key)
            end
        end
        if definition.key == "cooldowns" then
            for key in pairs(DEFAULTS) do
                if key:match("^cooldownReminder") and key ~= "cooldownReminder"
                    and key ~= "cooldownReminderCombatOnly" then table.insert(defaultKeys, key) end
            end
        end
        local category = createCategory(
            definition.key, definition.title, definition.description,
            defaultKeys)
        for _, key in ipairs(definition.options) do
            addFeatureOption(category, key)
            if key == "dungeonPortal" then
                local row = CreateFrame("Frame", nil, category.panel)
                local preview = CreateFrame("Button", nil, row, "BackdropTemplate")
                preview:SetPoint("TOPLEFT", 12, -4)
                preview:SetSize(220, 30)
                styleFlatButton(preview)
                preview:SetText("포탈 버튼 미리보기")
                preview:SetScript("OnClick", function()
                    if _G.MimQoLDungeonPortal then _G.MimQoLDungeonPortal.Preview() end
                end)
                movePortalButton = CreateFrame("Button", nil, row, "BackdropTemplate")
                movePortalButton:SetPoint("LEFT", preview, "RIGHT", 8, 0)
                movePortalButton:SetSize(122, 30)
                styleFlatButton(movePortalButton)
                movePortalButton:SetText("위치 이동")
                movePortalButton:SetScript("OnClick", function(self)
                    local portal = _G.MimQoLDungeonPortal
                    if not portal then return end
                    local function label(active) self:SetText(active and "이동 완료" or "위치 이동") end
                    label(portal.SetMoving(not portal.IsMoving(), label))
                end)
                addEntry(category, row, 48, "쐐기 던전 포탈 미리보기 위치 이동")
            end
            if key == "cooldownReminder" then
                local row = CreateFrame("Frame", nil, category.panel)
                local open = CreateFrame("Button", nil, row, "BackdropTemplate")
                open:SetPoint("TOPLEFT", 12, -4)
                open:SetSize(360, 30)
                styleFlatButton(open)
                open:SetText("스킬·장신구 등록 / 모양·소리 설정")
                open:SetScript("OnClick", function()
                    local reminder = _G.MimQoLCooldownReminder
                    if reminder and reminder.ToggleConfig then reminder.ToggleConfig() end
                end)
                addEntry(category, row, 48, "쿨타임 스킬 장신구 아이디 ID 드래그 소리 문구 아이콘 위치 펄스")
            end
            if key == "greetManualMode" then addOverlayOptions(category) end
            if key == "chatSoundChannel" then addChatSoundFields(category) end
            if key == "argusTracker" then addArgusFields(category) end
            if greetingScenarios[key] then
                addGreetingFields(category, key)
            end
        end
    end

    local function layoutCategory(category, query)
        local searching = query ~= ""
        local y = 0
        local matchCount = 0
        category.defaultButton:Hide()

        category.title:ClearAllPoints()
        category.title:SetPoint("TOPLEFT", category.panel, "TOPLEFT", 0, 0)
        category.title:Show()
        y = y + 26

        if searching then
            category.description:Hide()
        else
            category.description:ClearAllPoints()
            category.description:SetPoint(
                "TOPLEFT", category.panel, "TOPLEFT", 0, -y)
            category.description:Show()
            y = y + math.max(
                14, category.description:GetStringHeight()) + 14
        end

        for _, entry in ipairs(category.entries) do
            local matches = not searching
                or entry.searchText:find(query, 1, true) ~= nil
            entry.row:SetShown(matches)
            if matches then
                entry.row:ClearAllPoints()
                entry.row:SetPoint(
                    "TOPLEFT", category.panel, "TOPLEFT", 0, -y)
                y = y + entry.height
                matchCount = matchCount + 1
            end
        end

        if matchCount == 0 then
            category.panel:Hide()
            return false, 0
        end

        y = y + 4
        if not category.hideDefaultButton then
            category.defaultButton:ClearAllPoints()
            category.defaultButton:SetPoint(
                "TOPRIGHT", category.panel, "TOPRIGHT", -20, -y)
            category.defaultButton:Show()
            y = y + 36
        end

        category.panel:SetHeight(math.max(1, y + 4))
        category.panel:Show()
        return true, y + 4
    end

    local function setSelectedButton(searching)
        for key, button in pairs(categoryButtons) do
            setFlatButtonSelected(
                button, not searching and key == selectedCategoryKey)
        end
    end

    layoutOptionsContent = function(resetScroll)
        local query = normalizedSearchText(searchBox:GetText())
        local searching = query ~= ""
        local y = 0
        local visibleCount = 0

        noResults:Hide()
        for _, category in ipairs(categoryViews) do
            category.panel:Hide()
            category.panel:ClearAllPoints()
        end

        if searching then
            for _, category in ipairs(categoryViews) do
                local shown, height = layoutCategory(category, query)
                if shown then
                    category.panel:SetPoint(
                        "TOPLEFT", content, "TOPLEFT", 0, -y)
                    y = y + height + 14
                    visibleCount = visibleCount + 1
                end
            end
        else
            local category = categoryByKey[selectedCategoryKey]
                or categoryViews[1]
            if category then
                selectedCategoryKey = category.key
                local shown, height = layoutCategory(category, "")
                if shown then
                    category.panel:SetPoint(
                        "TOPLEFT", content, "TOPLEFT", 0, 0)
                    y = height
                    visibleCount = 1
                end
            end
        end

        if visibleCount == 0 then
            noResults:Show()
            y = 60
        end

        content:SetHeight(math.max(1, y))
        setSelectedButton(searching)
        if type(scrollFrame.UpdateScrollChildRect) == "function" then
            scrollFrame:UpdateScrollChildRect()
        end
        local maximum = math.max(0, scrollFrame:GetVerticalScrollRange())
        scrollBar:SetMinMaxValues(0, maximum)
        scrollBar:SetShown(maximum > 1)
        if resetScroll then
            scrollFrame:SetVerticalScroll(0)
        else
            scrollBar:SetValue(math.min(
                maximum, scrollFrame:GetVerticalScroll()))
        end
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maximum = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(
            0, math.min(maximum, current - delta * 45)))
    end)

    searchBox:HookScript("OnTextChanged", function()
        layoutOptionsContent(true)
    end)
    searchBox:HookScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:HookScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    for index, category in ipairs(categoryViews) do
        local buttonCategory = category
        local button = CreateFrame(
            "Button", nil, frame, "BackdropTemplate")
        button:SetPoint("TOPLEFT", 20, -120 - (index - 1) * 36)
        button:SetSize(164, 30)
        styleFlatButton(button)
        button:SetText(buttonCategory.titleText)
        button:SetScript("OnClick", function()
            selectedCategoryKey = buttonCategory.key
            searchBox:ClearFocus()
            if normalizedSearchText(searchBox:GetText()) ~= "" then
                searchBox:SetText("")
            else
                layoutOptionsContent(true)
            end
        end)
        categoryButtons[buttonCategory.key] = button
    end

    local defaultsButton = CreateFrame(
        "Button", nil, frame, "BackdropTemplate")
    defaultsButton:SetPoint("BOTTOMLEFT", 20, 20)
    defaultsButton:SetSize(164, 30)
    styleFlatButton(defaultsButton)
    defaultsButton:SetText("기본값 복원")
    defaultsButton:SetScript("OnClick", function()
        confirmDefaultsRestore("전체", function()
            restoreDefaultValues(nil)
            printMessage("전체 설정을 기본값으로 복원했습니다.")
        end)
    end)

    frame:SetScript("OnShow", function()
        refreshOptionsFrame()
        layoutOptionsContent(false)
    end)
    frame:SetScript("OnHide", function()
        if _G.MimQoLGreetingOverlay then _G.MimQoLGreetingOverlay.ClosePreview() end
        if _G.MimQoLDungeonPortal then _G.MimQoLDungeonPortal.StopMoving() end
    end)
    optionsFrame = frame
    table.insert(UISpecialFrames, "MimQoLOptionsFrame")
    refreshOptionsFrame()
    layoutOptionsContent(true)
    frame:Hide()
end

--------------------------------------------------------------------------------
-- Merchant
--------------------------------------------------------------------------------

local function coinText(amount)
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCoinText) == "function" then
        return C_CurrencyInfo.GetCoinText(amount)
    elseif type(GetCoinTextureString) == "function" then
        return GetCoinTextureString(amount)
    end
    return tostring(amount)
end

local function startSellingJunk()
    if not enabled("autoSellJunk") or IsShiftKeyDown()
        or not C_MerchantFrame
        or type(C_MerchantFrame.SellAllJunkItems) ~= "function" then
        return
    end

    if type(C_MerchantFrame.IsSellAllJunkEnabled) == "function"
        and not C_MerchantFrame.IsSellAllJunkEnabled() then
        return
    end
    C_MerchantFrame.SellAllJunkItems()
end

local function repairItems()
    if not enabled("autoRepair") or IsShiftKeyDown()
        or type(CanMerchantRepair) ~= "function" or not CanMerchantRepair() then
        return
    end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then
        return
    end

    if enabled("guildRepair") and IsInGuild() and CanGuildBankRepair() then
        RepairAllItems(true)
        RepairAllItems()
    else
        RepairAllItems()
    end

    if enabled("vendorSummary") then
        printMessage("자동 수리: " .. coinText(cost))
    end
end

--------------------------------------------------------------------------------
-- Auction House
--------------------------------------------------------------------------------

local function enableCurrentExpansionAuctionFilter()
    if not enabled("auctionCurrentExpansion") then
        return
    end

    local currentExpansionFilter = Enum and Enum.AuctionHouseFilter
        and Enum.AuctionHouseFilter.CurrentExpansionOnly
    if isSecretValue(currentExpansionFilter)
        or type(currentExpansionFilter) ~= "number" then
        return
    end

    local searchBar = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    local filterButton = searchBar and searchBar.FilterButton
    if not filterButton or type(filterButton.GetFilters) ~= "function" then
        return
    end

    local filters = filterButton:GetFilters()
    if isSecretValue(filters) or type(filters) ~= "table" then
        return
    end
    local isSelected = filters[currentExpansionFilter]
    if isSecretValue(isSelected) or isSelected then
        return
    end

    if type(filterButton.ToggleFilter) == "function" then
        filterButton:ToggleFilter(currentExpansionFilter)
    else
        filters[currentExpansionFilter] = true
        if type(searchBar.UpdateClearFiltersButton) == "function" then
            searchBar:UpdateClearFiltersButton()
        end
    end
end

local function queueCurrentExpansionAuctionFilter()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, enableCurrentExpansionAuctionFilter)
    else
        enableCurrentExpansionAuctionFilter()
    end
end

--------------------------------------------------------------------------------
-- Quest automation and choice reward vendor prices
--------------------------------------------------------------------------------

local QUEST_ACTION_COOLDOWN = 2

local function safeNumber(value)
    if isSecretValue(value) or type(value) ~= "number" then
        return
    end
    return value
end

local function questAutomationBypassed()
    if type(IsShiftKeyDown) ~= "function" then
        return false
    end
    local shiftDown = IsShiftKeyDown()
    return isSecretValue(shiftDown) or shiftDown
end

local function questActionKey(action, questID)
    questID = safeNumber(questID)
    if type(action) ~= "string" or not questID or questID <= 0 then
        return
    end
    return action .. ":" .. questID
end

local function rememberQuestAction(action, questID)
    local actionKey = questActionKey(action, questID)
    if not actionKey or type(GetTime) ~= "function" then
        return
    end
    local currentTime = safeNumber(GetTime())
    if currentTime then
        recentQuestActions[actionKey] = currentTime
    end
end

local function questActionWasRecent(action, questID)
    local actionKey = questActionKey(action, questID)
    if not actionKey or type(GetTime) ~= "function" then
        return false
    end

    local actionTime = recentQuestActions[actionKey]
    local currentTime = safeNumber(GetTime())
    if not actionTime or not currentTime then
        return false
    end
    return (currentTime - actionTime) < QUEST_ACTION_COOLDOWN
end

local function handleGossipQuests()
    if questAutomationBypassed() or not C_GossipInfo then
        return
    end

    if enabled("autoCompleteQuests")
        and type(C_GossipInfo.GetActiveQuests) == "function"
        and type(C_GossipInfo.SelectActiveQuest) == "function" then
        local activeQuests = C_GossipInfo.GetActiveQuests()
        if type(activeQuests) == "table" and not isSecretValue(activeQuests) then
            for _, questInfo in ipairs(activeQuests) do
                if type(questInfo) == "table" and not isSecretValue(questInfo) then
                    local questID = safeNumber(questInfo.questID)
                    local isComplete = questInfo.isComplete
                    if questID and questID > 0 and not isSecretValue(isComplete)
                        and isComplete
                        and not questActionWasRecent("active", questID) then
                        rememberQuestAction("active", questID)
                        C_GossipInfo.SelectActiveQuest(questID)
                        return
                    end
                end
            end
        end
    end

    if enabled("autoAcceptQuests")
        and type(C_GossipInfo.GetAvailableQuests) == "function"
        and type(C_GossipInfo.SelectAvailableQuest) == "function" then
        local availableQuests = C_GossipInfo.GetAvailableQuests()
        if type(availableQuests) == "table"
            and not isSecretValue(availableQuests) then
            for _, questInfo in ipairs(availableQuests) do
                if type(questInfo) == "table" and not isSecretValue(questInfo) then
                    local questID = safeNumber(questInfo.questID)
                    local isIgnored = questInfo.isIgnored
                    if questID and questID > 0 and not isSecretValue(isIgnored)
                        and not isIgnored
                        and not questActionWasRecent("available", questID) then
                        rememberQuestAction("available", questID)
                        C_GossipInfo.SelectAvailableQuest(questID)
                        return
                    end
                end
            end
        end
    end
end

local function handleQuestGreeting()
    if questAutomationBypassed() then
        return
    end

    if enabled("autoCompleteQuests")
        and type(GetNumActiveQuests) == "function"
        and type(GetActiveTitle) == "function"
        and type(SelectActiveQuest) == "function" then
        local activeCount = safeNumber(GetNumActiveQuests())
        if activeCount and activeCount >= 0 then
            for index = 1, activeCount do
                local _, isComplete = GetActiveTitle(index)
                local questID = type(GetActiveQuestID) == "function"
                    and safeNumber(GetActiveQuestID(index)) or nil
                if not isSecretValue(isComplete) and isComplete
                    and not questActionWasRecent("active", questID) then
                    rememberQuestAction("active", questID)
                    SelectActiveQuest(index)
                    return
                end
            end
        end
    end

    if enabled("autoAcceptQuests")
        and type(GetNumAvailableQuests) == "function"
        and type(SelectAvailableQuest) == "function" then
        local availableCount = safeNumber(GetNumAvailableQuests())
        if availableCount and availableCount > 0 then
            for index = 1, availableCount do
                local questID
                if type(GetAvailableQuestInfo) == "function" then
                    questID = safeNumber(select(5, GetAvailableQuestInfo(index)))
                end
                if not questActionWasRecent("available", questID) then
                    rememberQuestAction("available", questID)
                    SelectAvailableQuest(index)
                    return
                end
            end
        end
    end
end

local function handleQuestDetail(questStartItemID)
    if not enabled("autoAcceptQuests") or questAutomationBypassed() then
        return
    end

    if questStartItemID ~= nil then
        questStartItemID = safeNumber(questStartItemID)
        if not questStartItemID or questStartItemID ~= 0 then
            return
        end
    end

    if type(QuestIsFromAdventureMap) == "function" then
        local fromAdventureMap = QuestIsFromAdventureMap()
        if isSecretValue(fromAdventureMap) or fromAdventureMap then
            return
        end
    end
    if type(QuestIsFromAreaTrigger) == "function" then
        local fromAreaTrigger = QuestIsFromAreaTrigger()
        if isSecretValue(fromAreaTrigger) or fromAreaTrigger then
            return
        end
    end
    if type(QuestFlagsPVP) == "function" then
        local isPVP = QuestFlagsPVP()
        if isSecretValue(isPVP) or isPVP then
            return
        end
    end

    local questID = type(GetQuestID) == "function"
        and safeNumber(GetQuestID()) or nil
    if questActionWasRecent("accept", questID) then
        return
    end
    rememberQuestAction("accept", questID)

    local autoAccept = type(QuestGetAutoAccept) == "function"
        and QuestGetAutoAccept()
    if isSecretValue(autoAccept) then
        return
    end
    if autoAccept and type(AcknowledgeAutoAcceptQuest) == "function" then
        AcknowledgeAutoAcceptQuest()
    elseif type(AcceptQuest) == "function" then
        AcceptQuest()
    end
end

local function handleQuestProgress()
    if not enabled("autoCompleteQuests") or questAutomationBypassed()
        or type(IsQuestCompletable) ~= "function"
        or type(CompleteQuest) ~= "function" then
        return
    end

    local completable = IsQuestCompletable()
    if not isSecretValue(completable) and completable then
        CompleteQuest()
    end
end

local function resetQuestRewardDecorations()
    local rewardsFrame = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    local rewardButtons = rewardsFrame and rewardsFrame.RewardButtons
    if type(rewardButtons) ~= "table" then
        return
    end

    for _, button in pairs(rewardButtons) do
        local decoration = button and button.MimQoLVendorPriceDecoration
        if decoration then
            for _, texture in ipairs(decoration.edges) do
                texture:Hide()
            end
        end
    end
end

local function hideQuestRewardAdvisor()
    questRewardAdviceSerial = questRewardAdviceSerial + 1
    for itemID in pairs(pendingQuestRewardItems) do
        pendingQuestRewardItems[itemID] = nil
    end
    resetQuestRewardDecorations()
end

local function getQuestRewardDecoration(button)
    local decoration = button.MimQoLVendorPriceDecoration
    if decoration then
        return decoration
    end

    local edges = {}
    for index = 1, 4 do
        local texture = button:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetColorTexture(0.15, 1, 0.2, 0.95)
        edges[index] = texture
    end
    edges[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(2)
    edges[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(2)
    edges[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(2)
    edges[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(2)

    decoration = { edges = edges }
    button.MimQoLVendorPriceDecoration = decoration
    return decoration
end

local function requestQuestRewardItem(itemID)
    if not pendingQuestRewardItems[itemID] and C_Item
        and type(C_Item.RequestLoadItemDataByID) == "function" then
        pendingQuestRewardItems[itemID] = true
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function getChoiceRewardCandidate(index)
    local lootType = 0
    if type(GetQuestItemInfoLootType) == "function" then
        lootType = GetQuestItemInfoLootType("choice", index)
        if isSecretValue(lootType) or type(lootType) ~= "number" then
            return nil, false
        end
    end
    if lootType ~= 0 then
        return nil, true
    end

    local _, _, quantity, _, _, itemID = GetQuestItemInfo("choice", index)
    itemID = safeNumber(itemID)
    if not itemID or itemID <= 0 or isSecretValue(quantity) then
        return nil, false
    end
    quantity = safeNumber(quantity) or 1

    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return nil, false
    end
    local itemName, _, _, _, _, _, _, _, _, _, sellPrice =
        C_Item.GetItemInfo(itemID)
    if isSecretValue(itemName) then
        return nil, false
    end
    if not itemName then
        requestQuestRewardItem(itemID)
        return nil, false
    end
    if isSecretValue(sellPrice) or type(sellPrice) ~= "number" then
        return nil, false
    end

    return {
        index = index,
        totalPrice = sellPrice * quantity,
    }, true
end

local function markChoiceReward(candidate)
    local rewardsFrame = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    local rewardButtons = rewardsFrame and rewardsFrame.RewardButtons
    if type(rewardButtons) ~= "table" then
        return
    end

    for _, button in pairs(rewardButtons) do
        local buttonID = button and type(button.GetID) == "function"
            and button:GetID()
        if button and button.type == "choice" and button.objectType == "item"
            and not isSecretValue(buttonID) and buttonID == candidate.index then
            local decoration = getQuestRewardDecoration(button)
            for _, texture in ipairs(decoration.edges) do
                texture:Show()
            end
            return
        end
    end
end

local function updateQuestRewardAdvisor()
    resetQuestRewardDecorations()
    if not enabled("showBestQuestReward") or not QuestFrameRewardPanel
        or not QuestFrameRewardPanel:IsShown()
        or type(GetNumQuestChoices) ~= "function"
        or type(GetQuestItemInfo) ~= "function" then
        return
    end

    local choiceCount = safeNumber(GetNumQuestChoices())
    if not choiceCount or choiceCount < 2 then
        return
    end

    local bestPrice = -1
    local bestCandidates = {}
    for index = 1, choiceCount do
        local candidate, ready = getChoiceRewardCandidate(index)
        if not ready then
            return
        end
        if candidate then
            if candidate.totalPrice > bestPrice then
                bestPrice = candidate.totalPrice
                bestCandidates = { candidate }
            elseif candidate.totalPrice == bestPrice then
                table.insert(bestCandidates, candidate)
            end
        end
    end
    if bestPrice < 0 or #bestCandidates == 0 then
        return
    end

    for _, candidate in ipairs(bestCandidates) do
        markChoiceReward(candidate)
    end
end

local function queueQuestRewardAdvisor()
    questRewardAdviceSerial = questRewardAdviceSerial + 1
    local serial = questRewardAdviceSerial
    local function update()
        if serial == questRewardAdviceSerial then
            updateQuestRewardAdvisor()
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, update)
    else
        update()
    end
end

local function setupQuestRewardAdvisor()
    if questRewardHookInstalled
        or type(QuestInfo_ShowRewards) ~= "function" then
        return
    end
    questRewardHookInstalled = true
    hooksecurefunc("QuestInfo_ShowRewards", queueQuestRewardAdvisor)
end

local function finishQuestIfSafe()
    if not enabled("autoCompleteQuests") or questAutomationBypassed()
        or type(GetNumQuestChoices) ~= "function"
        or type(GetQuestReward) ~= "function" then
        return
    end

    local choiceCount = safeNumber(GetNumQuestChoices())
    if not choiceCount or choiceCount < 0 or choiceCount > 1 then
        return
    end

    if type(GetQuestMoneyToGet) == "function" then
        local requiredMoney = safeNumber(GetQuestMoneyToGet())
        if not requiredMoney or requiredMoney > 0 then
            return
        end
    end

    local questID = type(GetQuestID) == "function"
        and safeNumber(GetQuestID()) or nil
    rememberQuestAction("available", questID)
    GetQuestReward(choiceCount == 1 and 1 or 0)
end

local function handleQuestComplete()
    local bypassed = questAutomationBypassed()
    queueQuestRewardAdvisor()
    if not enabled("autoCompleteQuests") or bypassed then
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, finishQuestIfSafe)
    else
        finishQuestIfSafe()
    end
end

--------------------------------------------------------------------------------
-- Wowhead quest link
--------------------------------------------------------------------------------

local WOWHEAD_HOSTS = {
    deDE = "de.wowhead.com",
    esMX = "mx.wowhead.com",
    esES = "es.wowhead.com",
    frFR = "fr.wowhead.com",
    itIT = "it.wowhead.com",
    ptBR = "pt.wowhead.com",
    ruRU = "ru.wowhead.com",
    koKR = "ko.wowhead.com",
    zhCN = "cn.wowhead.com",
    zhTW = "tw.wowhead.com",
}

local WOWHEAD_POPUP = "MIMQOL_WOWHEAD_LINK"
local DISCORD_POPUP = "MIMQOL_DISCORD_LINK"

local function getPopupEditBox(dialog)
    if dialog and type(dialog.GetEditBox) == "function" then
        local editBox = dialog:GetEditBox()
        if editBox then
            return editBox
        end
    end
    return dialog and (dialog.EditBox or dialog.editBox)
end

StaticPopupDialogs[WOWHEAD_POPUP] = {
    text = "와우헤드 퀘스트 링크\n\n주소가 전체 선택되어 있습니다.\nCtrl+C를 눌러 복사하세요.",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 360,
    OnShow = function(self, url)
        self.url = url
        local editBox = getPopupEditBox(self)
        if not editBox then
            return
        end
        editBox:SetText(url or "")
        editBox:SetFocus()
        editBox:HighlightText()
    end,
    OnHide = function(self)
        self.url = nil
    end,
    EditBoxOnTextChanged = function(self)
        local url = self:GetParent().url
        if url and self:GetText() ~= url then
            self:SetText(url)
        end
        self:HighlightText()
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs[DISCORD_POPUP] = {
    text = "Discord 초대 주소\n\n주소가 전체 선택되어 있습니다.\nCtrl+C를 눌러 복사하세요.",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 360,
    OnShow = function(self, url)
        self.url = url
        local editBox = getPopupEditBox(self)
        if not editBox then
            return
        end
        editBox:SetText(url or "")
        editBox:SetFocus()
        editBox:HighlightText()
    end,
    OnHide = function(self)
        self.url = nil
    end,
    EditBoxOnTextChanged = function(self)
        local url = self:GetParent().url
        if url and self:GetText() ~= url then
            self:SetText(url)
        end
        self:HighlightText()
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function validQuestID(value)
    local questID = tonumber(value)
    if questID and questID > 0 then
        return questID
    end
end

local function currentQuestID()
    local detailsFrame = QuestMapFrame and QuestMapFrame.DetailsFrame
    if not detailsFrame or not detailsFrame:IsShown() then
        return
    end

    if C_QuestLog and type(C_QuestLog.GetSelectedQuest) == "function" then
        local questID = validQuestID(C_QuestLog.GetSelectedQuest())
        if questID then
            return questID
        end
    end

    local questID = validQuestID(detailsFrame.questID or detailsFrame.questId)
    if questID then
        return questID
    end

    if type(QuestMapFrame_GetDetailQuestID) == "function" then
        return validQuestID(QuestMapFrame_GetDetailQuestID())
    end
end

local function updateQuestLink()
    if not questLinkBox then
        return
    end

    if not enabled("wowheadLink") then
        questLinkBox.url = nil
        questLinkBox:SetText("")
        questLinkBox:Hide()
        StaticPopup_Hide(WOWHEAD_POPUP)
        return
    end

    local questID = currentQuestID()
    if not questID then
        questLinkBox.url = nil
        questLinkBox:SetText("")
        questLinkBox:Hide()
        return
    end

    local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
    local host = WOWHEAD_HOSTS[locale] or "www.wowhead.com"
    local url = "https://" .. host .. "/quest=" .. questID
    questLinkBox.url = url
    questLinkBox:SetText(url)
    questLinkBox:Show()
end

local function queueQuestLinkUpdate()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, updateQuestLink)
    else
        updateQuestLink()
    end
end

local function setupQuestLink()
    if questLinkBox then
        updateQuestLink()
        return true
    end
    if not WorldMapFrame or not QuestMapFrame then
        return false
    end

    local borderFrame = WorldMapFrame.BorderFrame or WorldMapFrame
    local parent = borderFrame.TitleContainer or borderFrame
    local box = CreateFrame("Button", "MimQoLWowheadQuestLink", parent)
    box:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    box:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", -72, -4)
    box:SetSize(310, 18)
    box:EnableMouse(true)
    box:RegisterForClicks("LeftButtonUp")

    local urlText = box:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall")
    urlText:SetDrawLayer("OVERLAY", 7)
    urlText:SetAllPoints()
    urlText:SetJustifyH("RIGHT")
    urlText:SetTextColor(1, 0.82, 0)
    urlText:SetShadowColor(0, 0, 0, 1)
    urlText:SetShadowOffset(1, -1)
    box:SetFontString(urlText)
    box.Text = urlText

    box:SetScript("OnClick", function(self)
        if self.url then
            StaticPopup_Show(WOWHEAD_POPUP, nil, nil, self.url)
        end
    end)
    box:SetScript("OnEnter", function(self)
        self.Text:SetTextColor(1, 1, 1)
    end)
    box:SetScript("OnLeave", function(self)
        self.Text:SetTextColor(1, 0.82, 0)
    end)
    box:RegisterEvent("SUPER_TRACKING_CHANGED")
    box:RegisterEvent("QUEST_LOG_UPDATE")
    box:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    box:SetScript("OnEvent", queueQuestLinkUpdate)
    questLinkBox = box

    if not questHooksInstalled then
        questHooksInstalled = true
        local detailsFrame = QuestMapFrame.DetailsFrame
        if detailsFrame then
            detailsFrame:HookScript("OnShow", queueQuestLinkUpdate)
            detailsFrame:HookScript("OnHide", updateQuestLink)
        end
        WorldMapFrame:HookScript("OnShow", queueQuestLinkUpdate)
        WorldMapFrame:HookScript("OnHide", function()
            box:Hide()
            StaticPopup_Hide(WOWHEAD_POPUP)
        end)
        if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
            hooksecurefunc(C_QuestLog, "SetSelectedQuest", queueQuestLinkUpdate)
        end
        if type(QuestMapFrame_ShowQuestDetails) == "function" then
            hooksecurefunc("QuestMapFrame_ShowQuestDetails", queueQuestLinkUpdate)
        end
        if type(QuestMapFrame_CloseQuestDetails) == "function" then
            hooksecurefunc("QuestMapFrame_CloseQuestDetails", updateQuestLink)
        end
    end

    updateQuestLink()
    return true
end

--------------------------------------------------------------------------------
-- Click-to-copy Discord links
--------------------------------------------------------------------------------

local DISCORD_LINK_TYPE = "mimqoldiscord"
local DISCORD_LINK_COLOR = "|cff5865f2"
local DISCORD_URL_PATTERNS = {
    "https?://discord%.gg/[^%s|<>]+",
    "https?://www%.discord%.gg/[^%s|<>]+",
    "https?://discord%.com/invite/[^%s|<>]+",
    "https?://www%.discord%.com/invite/[^%s|<>]+",
    "https?://discordapp%.com/invite/[^%s|<>]+",
    "https?://www%.discordapp%.com/invite/[^%s|<>]+",
    "discord%.gg/[^%s|<>]+",
    "www%.discord%.gg/[^%s|<>]+",
    "discord%.com/invite/[^%s|<>]+",
    "www%.discord%.com/invite/[^%s|<>]+",
    "discordapp%.com/invite/[^%s|<>]+",
    "www%.discordapp%.com/invite/[^%s|<>]+",
}
local DISCORD_CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
}

local function trimDiscordURL(url)
    return (url:gsub("[%.%,!%?%;%:%)%]%}%>\"']+$", ""))
end

local function findNextDiscordURL(text, startAt)
    if isSecretValue(text) or type(text) ~= "string" then
        return
    end

    local lowerText = text:lower()
    local bestStart
    local bestEnd
    for _, pattern in ipairs(DISCORD_URL_PATTERNS) do
        local foundStart, foundEnd = lowerText:find(pattern, startAt or 1)
        while foundStart do
            local preceding = foundStart > 1
                and lowerText:sub(foundStart - 1, foundStart - 1)
            if not preceding or not preceding:match("[%w_%.%-]") then
                break
            end
            foundStart, foundEnd = lowerText:find(pattern, foundStart + 1)
        end

        if foundStart and (not bestStart or foundStart < bestStart
            or (foundStart == bestStart and foundEnd > bestEnd)) then
            bestStart = foundStart
            bestEnd = foundEnd
        end
    end

    if not bestStart then
        return
    end

    local url = trimDiscordURL(text:sub(bestStart, bestEnd))
    if url == "" then
        return
    end
    return bestStart, bestStart + #url - 1, url
end

local function isDiscordURL(value)
    if isSecretValue(value) or type(value) ~= "string" then
        return false
    end
    local startPosition, endPosition = findNextDiscordURL(value, 1)
    return startPosition == 1 and endPosition == #value
end

local function formatDiscordHyperlink(url)
    if LinkUtil and type(LinkUtil.FormatLink) == "function" then
        local displayText = DISCORD_LINK_COLOR .. url .. "|r"
        return LinkUtil.FormatLink(DISCORD_LINK_TYPE, displayText, url)
    end
    return url
end

local function linkifyDiscordPlainText(text)
    local parts = {}
    local cursor = 1
    local firstURL
    local changed = false

    while cursor <= #text do
        local urlStart, urlEnd, url = findNextDiscordURL(text, cursor)
        if not urlStart then
            parts[#parts + 1] = text:sub(cursor)
            break
        end

        parts[#parts + 1] = text:sub(cursor, urlStart - 1)
        parts[#parts + 1] = formatDiscordHyperlink(url)
        firstURL = firstURL or url
        changed = true
        cursor = urlEnd + 1
    end

    if cursor == 1 then
        return text
    end
    return table.concat(parts), firstURL, changed
end

local function appendDiscordPlainText(parts, text, firstURL)
    local linkedText, foundURL, changed = linkifyDiscordPlainText(text)
    parts[#parts + 1] = linkedText
    return firstURL or foundURL, changed
end

local function linkifyDiscordMessage(message)
    if isSecretValue(message) or type(message) ~= "string"
        or message == "" then
        return message
    end

    local parts = {}
    local cursor = 1
    local firstURL
    local changed = false
    local messageLength = #message

    while cursor <= messageLength do
        local linkStart = message:find("|H", cursor, true)
        if not linkStart then
            local segmentChanged
            firstURL, segmentChanged = appendDiscordPlainText(
                parts, message:sub(cursor), firstURL)
            changed = changed or segmentChanged
            break
        end

        local firstMarkerStart, firstMarkerEnd = message:find(
            "|h", linkStart + 2, true)
        local secondMarkerStart, secondMarkerEnd
        if firstMarkerEnd then
            secondMarkerStart, secondMarkerEnd = message:find(
                "|h", firstMarkerEnd + 1, true)
        end

        if not firstMarkerStart or not secondMarkerStart then
            local segmentChanged
            firstURL, segmentChanged = appendDiscordPlainText(
                parts, message:sub(cursor), firstURL)
            changed = changed or segmentChanged
            break
        end

        local segmentChanged
        firstURL, segmentChanged = appendDiscordPlainText(
            parts, message:sub(cursor, linkStart - 1), firstURL)
        changed = changed or segmentChanged
        parts[#parts + 1] = message:sub(linkStart, secondMarkerEnd)
        cursor = secondMarkerEnd + 1
    end

    if not changed then
        return message, firstURL, false
    end
    return table.concat(parts), firstURL, true
end

local function discordChatFilter(_, _, message, author, ...)
    if not enabled("discordLinks") then
        return false
    end

    local linkedMessage, _, changed = linkifyDiscordMessage(message)
    if not changed then
        return false
    end
    return false, linkedMessage, author, ...
end

local function hideRaidWarningDiscordLink()
    discordRaidWarningSerial = discordRaidWarningSerial + 1
    if discordRaidWarningButton then
        discordRaidWarningButton.url = nil
        discordRaidWarningButton:Hide()
    end
end

local function createRaidWarningDiscordButton()
    if discordRaidWarningButton then
        return discordRaidWarningButton
    end

    local button = CreateFrame(
        "Button", "MimQoLRaidWarningDiscordLink", UIParent,
        "BackdropTemplate")
    button:SetSize(560, 28)
    button:SetPoint("TOP", UIParent, "TOP", 0, -165)
    button:SetFrameStrata("DIALOG")
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp")
    styleFlatButton(button, "GameFontNormalLarge")
    button.MimQoLLabel:SetWidth(530)
    button.MimQoLLabel:SetWordWrap(false)
    button:SetScript("OnClick", function(self)
        if self.url then
            StaticPopup_Show(DISCORD_POPUP, nil, nil, self.url)
        end
    end)
    button:Hide()
    discordRaidWarningButton = button
    return button
end

local function showRaidWarningDiscordLink(message)
    if not enabled("discordLinks") or isSecretValue(message)
        or type(message) ~= "string" then
        return
    end

    local _, _, url = findNextDiscordURL(message, 1)
    if not url then
        return
    end

    local button = createRaidWarningDiscordButton()
    discordRaidWarningSerial = discordRaidWarningSerial + 1
    local serial = discordRaidWarningSerial
    button.url = url
    button:SetText("Discord 주소 복사  |  " .. url)
    button:Show()

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(15, function()
            if serial == discordRaidWarningSerial then
                hideRaidWarningDiscordLink()
            end
        end)
    end
end


local function setupDiscordLinks()
    if not discordLinkHandlerInstalled and LinkUtil
        and type(LinkUtil.RegisterLinkHandler) == "function" then
        discordLinkHandlerInstalled = true
        LinkUtil.RegisterLinkHandler(DISCORD_LINK_TYPE,
            function(_, _, linkData)
                local url = linkData and linkData.options
                if enabled("discordLinks") and isDiscordURL(url) then
                    StaticPopup_Show(DISCORD_POPUP, nil, nil, url)
                end
            end)
    end

    if discordChatFiltersInstalled then
        return
    end

    local addMessageEventFilter = ChatFrameUtil
        and ChatFrameUtil.AddMessageEventFilter
    if type(addMessageEventFilter) ~= "function" then
        addMessageEventFilter = ChatFrame_AddMessageEventFilter
    end
    if type(addMessageEventFilter) ~= "function" then
        return
    end

    discordChatFiltersInstalled = true
    for _, event in ipairs(DISCORD_CHAT_EVENTS) do
        addMessageEventFilter(event, discordChatFilter)
    end
end

--------------------------------------------------------------------------------
-- Audio, loot, and item destruction
--------------------------------------------------------------------------------

local function syncAudioOutput()
    if enabled("keepAudioSynced") then
        SetCVar("Sound_OutputDriverIndex", "0")
    end
end

local function restartAudioIfSafe()
    if not enabled("keepAudioSynced") then
        return
    end

    local cinematicShown = CinematicFrame and CinematicFrame:IsShown()
    local movieShown = MovieFrame and MovieFrame:IsShown()
    if not cinematicShown and not movieShown then
        syncAudioOutput()
        Sound_GameSystem_RestartSoundSystem()
    end
end

local function fastLoot()
    if not enabled("fasterLoot") then
        return
    end

    local now = GetTime()
    local delay = tonumber(MimQoLDB.lootDelay) or DEFAULTS.lootDelay
    if now - lastLootTime < delay then
        return
    end
    lastLootTime = now

    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        for slot = GetNumLootItems(), 1, -1 do
            LootSlot(slot)
        end
        lastLootTime = GetTime()
    end
end

local function findDeletePopup()
    if type(StaticPopup_FindVisible) == "function" then
        for which in pairs(DELETE_POPUPS) do
            local popup = StaticPopup_FindVisible(which)
            if popup then
                return popup
            end
        end
    end

    local count = STATICPOPUP_NUMDIALOGS or 4
    for index = 1, count do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.which and DELETE_POPUPS[popup.which]
            and popup:IsShown() then
            return popup
        end
    end
end

local function popupChild(popup, field, suffix)
    if popup[field] then
        return popup[field]
    end
    local name = popup.GetName and popup:GetName()
    return name and _G[name .. suffix]
end

local function escapePattern(text)
    return (text:gsub("([^%w])", "%%%1"))
end

local function deleteInstructionText()
    if type(DELETE_GOOD_ITEM) ~= "string" then
        return
    end
    local encoded = DELETE_GOOD_ITEM:gsub("[\r\n]", "@")
    local suffix = encoded:match("^[^@]*@(.+)$")
    return suffix and suffix:gsub("@", "")
end

local function simplifyDeletePopup()
    if not enabled("easyItemDestroy") then
        return
    end

    local popup = findDeletePopup()
    if not popup then
        return
    end

    local editBox = popupChild(popup, "editBox", "EditBox")
    local button = popupChild(popup, "button1", "Button1")
    local textRegion = popupChild(popup, "text", "Text")
    local requiredTyping = editBox and editBox:IsShown()

    if editBox then
        editBox:Hide()
    end
    if button and type(button.Enable) == "function" then
        button:Enable()
    end

    if requiredTyping and textRegion and type(textRegion.GetText) == "function" then
        local text = textRegion:GetText() or ""
        local instruction = deleteInstructionText()
        if instruction and instruction ~= "" then
            text = text:gsub(escapePattern(instruction), "")
        end

        local link = select(3, GetCursorInfo())
        if link and not text:find(link, 1, true) then
            text = text:gsub("%s+$", "") .. "\n\n" .. link
        end
        textRegion:SetText(text)
    end
end

--------------------------------------------------------------------------------
-- Events and commands
--------------------------------------------------------------------------------

refreshFeatureEvents = function()
    if not dbLoaded then
        return
    end

    setEvent("MERCHANT_SHOW", enabled("autoSellJunk") or enabled("autoRepair"))
    setEvent("AUCTION_HOUSE_SHOW", enabled("auctionCurrentExpansion"))
    setEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED", enabled("keepAudioSynced"))
    setEvent("LOOT_READY", enabled("fasterLoot"))
    setEvent("DELETE_ITEM_CONFIRM", enabled("easyItemDestroy"))
    setEvent("CHAT_MSG_RAID_WARNING", enabled("discordLinks"))
    local softInteractObjects = enabled("softInteractObjects")
    local nameplateCVars = softInteractObjects
        or enabled("quickHideDeadNameplates")
    local hideInstanceErrors = enabled("hideInstanceErrors")
    local hideQuestTracker = enabled("hideQuestTrackerInInstances")
    setEvent("PLAYER_ENTERING_WORLD",
        nameplateCVars or hideInstanceErrors or hideQuestTracker)
    setEvent("ZONE_CHANGED_NEW_AREA", hideInstanceErrors or hideQuestTracker)
    setEvent("CHALLENGE_MODE_START", hideQuestTracker)
    setEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED", hideQuestTracker)
    setEvent("CHALLENGE_MODE_COMPLETED", hideQuestTracker)
    setEvent("CHALLENGE_MODE_RESET", hideQuestTracker)
    setEvent("PLAYER_SOFT_INTERACT_CHANGED", softInteractObjects)
    setEvent("NAME_PLATE_UNIT_ADDED", softInteractObjects)
    setEvent("NAME_PLATE_UNIT_REMOVED", softInteractObjects)
    local questAutomation = enabled("autoAcceptQuests")
        or enabled("autoCompleteQuests")
    local questFeatures = questAutomation or enabled("showBestQuestReward")
    setEvent("GOSSIP_SHOW", questAutomation)
    setEvent("QUEST_GREETING", questAutomation)
    setEvent("QUEST_DETAIL", enabled("autoAcceptQuests"))
    setEvent("QUEST_PROGRESS", enabled("autoCompleteQuests"))
    setEvent("QUEST_COMPLETE", enabled("autoCompleteQuests")
        or enabled("showBestQuestReward"))
    setEvent("QUEST_FINISHED", questFeatures)
    setEvent("QUEST_ITEM_UPDATE", enabled("showBestQuestReward"))
    setEvent("GET_ITEM_INFO_RECEIVED", enabled("showBestQuestReward"))
    setEvent("ITEM_DATA_LOAD_RESULT", enabled("showBestQuestReward"))
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            loadDB()
            refreshFeatureEvents()
            updateInstanceErrorMessages()
            queueQuestTrackerVisibilityUpdate()
            applyNameplateCVars()
            queueSoftInteractObjectName()
            setupCursorTooltip()
            createOptionsWindow()
            syncAudioOutput()
            setupQuestLink()
            setupQuestRewardAdvisor()
            setupDiscordLinks()
            setupEnhanceQoLChatHistoryCompat()
        elseif arg1 == "EnhanceQoLChatSocial" then
            setupEnhanceQoLChatHistoryCompat()
        elseif dbLoaded and arg1 == "Blizzard_WorldMap" then
            setupQuestLink()
        elseif dbLoaded and arg1 == "Blizzard_UIPanels_Game" then
            setupQuestRewardAdvisor()
        elseif dbLoaded and arg1 == "Blizzard_ObjectiveTracker" then
            queueQuestTrackerVisibilityUpdate()
        end
    elseif event == "PLAYER_LOGIN" then
        updateInstanceErrorMessages()
        queueQuestTrackerVisibilityUpdate()
        applyNameplateCVars()
        queueSoftInteractObjectName()
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(1, applyNameplateCVars)
        end
        setupQuestLink()
        setupQuestRewardAdvisor()
        setupDiscordLinks()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        updateInstanceErrorMessages()
        queueQuestTrackerVisibilityUpdate()
        applyNameplateCVars()
        queueSoftInteractObjectName()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        updateInstanceErrorMessages()
        queueQuestTrackerVisibilityUpdate()
    elseif event == "CHALLENGE_MODE_START"
        or event == "CHALLENGE_MODE_KEYSTONE_SLOTTED"
        or event == "CHALLENGE_MODE_COMPLETED"
        or event == "CHALLENGE_MODE_RESET" then
        queueQuestTrackerVisibilityUpdate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingNameplateCVarApply then
            applyNameplateCVars()
        end
        if pendingQuestTrackerVisibilityUpdate then
            queueQuestTrackerVisibilityUpdate()
        end
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED"
        or event == "NAME_PLATE_UNIT_ADDED" then
        queueSoftInteractObjectName()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if arg1 == softInteractNameUnit then
            hideSoftInteractObjectName()
        end
    elseif event == "MERCHANT_SHOW" then
        repairItems()
        startSellingJunk()
    elseif event == "AUCTION_HOUSE_SHOW" then
        queueCurrentExpansionAuctionFilter()
    elseif event == "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" then
        restartAudioIfSafe()
    elseif event == "LOOT_READY" then
        fastLoot()
    elseif event == "DELETE_ITEM_CONFIRM" then
        simplifyDeletePopup()
    elseif event == "CHAT_MSG_RAID_WARNING" then
        showRaidWarningDiscordLink(arg1)
    elseif event == "GOSSIP_SHOW" then
        handleGossipQuests()
    elseif event == "QUEST_GREETING" then
        handleQuestGreeting()
    elseif event == "QUEST_DETAIL" then
        handleQuestDetail(arg1)
    elseif event == "QUEST_PROGRESS" then
        handleQuestProgress()
    elseif event == "QUEST_COMPLETE" then
        handleQuestComplete()
    elseif event == "QUEST_ITEM_UPDATE"
        or event == "GET_ITEM_INFO_RECEIVED"
        or event == "ITEM_DATA_LOAD_RESULT" then
        queueQuestRewardAdvisor()
    elseif event == "QUEST_FINISHED" then
        hideQuestRewardAdvisor()
    end
end)

local COMMANDS = {
    cursor = "cursorTooltip",
    sell = "autoSellJunk",
    repair = "autoRepair",
    auction = "auctionCurrentExpansion",
    accept = "autoAcceptQuests",
    complete = "autoCompleteQuests",
    reward = "showBestQuestReward",
    wowhead = "wowheadLink",
    questhide = "hideQuestTrackerInInstances",
    discord = "discordLinks",
    interact = "softInteractObjects",
    deadhide = "quickHideDeadNameplates",
    errors = "hideInstanceErrors",
    auradecimal = "ellesmereAuraDecimals",
    audio = "keepAudioSynced",
    guildsound = "chatSoundGuild",
    channelsound = "chatSoundChannel",
    partysound = "chatSoundParty",
    loot = "fasterLoot",
    destroy = "easyItemDestroy",
    ilvl = "bagItemLevel",
    pet = "petReminder",
    argus = "argusTracker",
    greet = "autoGreet",
    cooldown = "cooldownReminder",
    portal = "dungeonPortal",
}

local function stateText(value)
    return value and "켜짐" or "꺼짐"
end

applyFeatureChange = function(key)
    refreshFeatureEvents()

    if key == "dungeonPortal" then
        if _G.MimQoLDungeonPortal then _G.MimQoLDungeonPortal.ApplySettings() end
    elseif key == "autoGreet" or key == "greetManualMode" or key == "autoGreetParty" or key == "autoGreetRaid"
        or key == "autoGreetWelcome" or key == "autoGreetFullParty" or key == "autoGreetComplete" then
        if _G.MimQoLAutoGreet_ApplySettings then
            _G.MimQoLAutoGreet_ApplySettings()
        end
    elseif key == "bagItemLevel" then
        if _G.MimQoLBagItemLevel then _G.MimQoLBagItemLevel.ApplySettings() end
    elseif key == "argusTracker" then
        if _G.MimQoLArgusTracker then _G.MimQoLArgusTracker.ApplySettings() end
    elseif key == "cooldownReminder" or key == "cooldownReminderCombatOnly" then
        if _G.MimQoLCooldownReminder then _G.MimQoLCooldownReminder.ApplySettings() end
    elseif key == "petReminder"
        or key == "petReminderMissing"
        or key == "petReminderAttack"
        or key == "petReminderHealth" then
        if _G.MimQoLPetReminder_ApplySettings then
            _G.MimQoLPetReminder_ApplySettings()
        end
    elseif key == "wowheadLink" then
        setupQuestLink()
        updateQuestLink()
    elseif key == "auctionCurrentExpansion" and enabled(key) then
        queueCurrentExpansionAuctionFilter()
    elseif key == "showBestQuestReward" then
        setupQuestRewardAdvisor()
        if enabled(key) then
            queueQuestRewardAdvisor()
        else
            hideQuestRewardAdvisor()
        end
    elseif key == "discordLinks" then
        setupDiscordLinks()
        if not enabled(key) then
            hideRaidWarningDiscordLink()
            StaticPopup_Hide(DISCORD_POPUP)
        end
    elseif key == "softInteractObjects" then
        applyNameplateCVars()
        queueSoftInteractObjectName()
    elseif key == "quickHideDeadNameplates" then
        applyNameplateCVars()
    elseif key == "hideInstanceErrors" then
        updateInstanceErrorMessages()
    elseif key == "ellesmereAuraDecimals" then
        -- EllesmereUI binds the formatter when an aura icon is created.
        printMessage("엘스미어 오라 시간 소수점은 /reload 후 모든 아이콘에 적용됩니다.")
    elseif key == "hideQuestTrackerInInstances" then
        queueQuestTrackerVisibilityUpdate()
    elseif key == "chatSoundGuild" or key == "chatSoundChannel"
        or key == "chatSoundParty" then
        if _G.MimQoLChatSound then _G.MimQoLChatSound.ApplySettings() end
    elseif key == "keepAudioSynced" and enabled(key) then
        syncAudioOutput()
    end
end

local function showStatus()
    printMessage("v" .. ADDON_VERSION)
    for _, key in ipairs(FEATURE_OPTIONS) do
        printMessage(LABELS[key] .. ": " .. stateText(enabled(key)))
    end
    if _G.MimQoLActionBarKeeper_GetCount then
        printMessage(string.format("공용 행동단축바: %d개 (설정 창에서 관리)",
            _G.MimQoLActionBarKeeper_GetCount()))
    end
    printMessage("설정: /mq, /ㅁㅋ, /ㅡㅂ, /밈큐오엘 또는 /mimqol")
end

SLASH_MIMQOL1 = "/mimqol"
SLASH_MIMQOL2 = "/mq"
SLASH_MIMQOL3 = "/밈큐오엘"
SLASH_MIMQOL4 = "/ㅁㅋ"
SLASH_MIMQOL5 = "/ㅡㅂ"
SlashCmdList["MIMQOL"] = function(input)
    if not dbLoaded then
        loadDB()
    end

    local command = (input or ""):match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "options" then
        createOptionsWindow()
        if optionsFrame:IsShown() then
            optionsFrame:Hide()
        else
            refreshOptionsFrame()
            optionsFrame:Show()
        end
        return
    end

    if command == "cd" or command == "cdtest" then
        local reminder = _G.MimQoLCooldownReminder
        if reminder then
            if command == "cdtest" then
                if not reminder.Preview() then printMessage("쿨타임 알림을 켜고 스킬 또는 장신구를 등록하세요.") end
            elseif reminder.ToggleConfig then reminder.ToggleConfig() end
        end
        return
    end

    if command == "portaltest" then
        if _G.MimQoLDungeonPortal then _G.MimQoLDungeonPortal.Preview() end
        return
    end

    if command == "argusdebug" then
        local tracker = _G.MimQoLArgusTracker
        if tracker and tracker.ToggleDebug then
            printMessage(tracker.ToggleDebug() and "아르거스 시전 기록을 켰습니다. 폭군 중 시전한 주문 ID가 채팅에 나옵니다."
                or "아르거스 시전 기록을 껐습니다.")
        end
        return
    end

    if command == "argustest" then
        local tracker = _G.MimQoLArgusTracker
        if not tracker or not tracker.Preview() then printMessage("아르거스 차원문 추적을 켠 뒤 미리보기를 사용하세요.") end
        return
    end

    if command == "pettest" then
        if _G.MimQoLPetReminder_Test then
            _G.MimQoLPetReminder_Test()
        else
            printMessage("소환수 알림 모듈을 불러오지 못했습니다.")
        end
        return
    end

    local key = COMMANDS[command]
    if not key then
        showStatus()
        return
    end

    MimQoLDB[key] = not enabled(key)
    applyFeatureChange(key)
    refreshOptionsFrame()
    printMessage(LABELS[key] .. ": " .. stateText(enabled(key)))
end
