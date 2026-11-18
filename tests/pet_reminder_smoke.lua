-- Run from the addon directory with a Lua interpreter.
local frames, state = {}, {}
local now, checks = 0, 0
local secret = setmetatable({}, {
    __lt = function() error("compared a restricted value") end,
    __le = function() error("compared a restricted value") end,
    __div = function() error("divided a restricted value") end,
})
local function noop() end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
UIParent = {}
Enum = { LuaCurveType = { Step = 1 } }
function issecretvalue(value) return rawequal(value, secret) end
function CreateFrame()
    local frame = { events = {}, scripts = {}, shown = true, alpha = 1 }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event, unit) self.events[event] = unit end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(name, handler) self.scripts[name] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetAlpha(alpha)
        assert(alpha ~= nil, "nil alpha")
        self.alpha = alpha
    end
    function frame:CreateFontString(_, _, template)
        local text = { template = template }
        function text:GetFont() return "Fonts\\2002.TTF", 16, "" end
        function text:SetFont(path) self.font = path end
        function text:SetText(value) self.value = value end
        return setmetatable(text, { __index = function() return noop end })
    end
    setmetatable(frame, { __index = function() return noop end })
    frames[#frames + 1] = frame
    return frame
end
function GetTime() return now end
function UnitClass() return "class", state.class end
function GetSpecialization() return state.spec end
function UnitExists(unit)
    if unit == "pet" then return state.pet end
    if unit == "pettarget" then return state.target end
    if unit == "target" then return state.enemy ~= false end
end
function UnitIsDeadOrGhost(unit)
    if unit == "player" then return state.playerDead end
    if unit == "target" then return state.enemyDead == true end
    return state.dead
end
function UnitCanAttack() return state.enemyHostile ~= false end
function UnitAffectingCombat(unit)
    if unit == "target" then
        if state.enemyCombat == "secret" then return secret end
        return state.enemyCombat ~= false
    end
end
function IsMounted() return state.mounted end
function UnitOnTaxi() return state.taxi end
function UnitInVehicle() return state.vehicle end
function UnitHasVehicleUI() return state.vehicleUI end
function UnitIsFeignDeath() return state.feign end
function IsShiftKeyDown() return state.shift end
function InCombatLockdown() return state.combat end
function UnitHealth() return state.health end
function UnitHealthMax() return state.maximum end
C_PetBattles = { IsInBattle = function() return state.petBattle end }
C_SpellBook = { IsSpellKnown = function(id) return state.known == id end }
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeNodes = function() return { 1 } end,
    GetNodeInfo = function()
        return { activeRank = state.talent and 1 or 0, activeEntry = { entryID = 1 } }
    end,
    GetEntryInfo = function() return { definitionID = 1 } end,
    GetDefinitionInfo = function() return { spellID = state.talent } end,
}
C_CurveUtil = { CreateCurve = function()
    local curve = { points = {} }
    function curve:SetType(kind) assert(kind == Enum.LuaCurveType.Step) end
    function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
    return curve
end }
local function healthPercent(_, _, curve)
    if state.curveError then error("API temporarily unavailable") end
    if state.secretAlpha then return secret end
    local result = curve.points[1][2]
    for _, point in ipairs(curve.points) do
        if state.health / state.maximum >= point[1] then result = point[2] end
    end
    return result
end
UnitHealthPercent = healthPercent
local function defaults()
    state = { class = "HUNTER", spec = 1, pet = true, target = true,
        dead = false, playerDead = false, health = 100, maximum = 100 }
    MimQoLDB = { petReminder = true, petReminderMissing = true,
        petReminderAttack = true, petReminderHealth = true }
end
defaults()
assert(loadfile("PetReminder.lua"))("MimQoL")
local driver = frames[1]
local function fire(event, unit)
    assert(driver.events[event], "unregistered event: " .. event)
    driver.scripts.OnEvent(driver, event, unit)
end
local function advance(seconds)
    for _ = 1, math.ceil(seconds / 0.25) do
        now = now + 0.25
        if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, 0.25) end
    end
end
fire("PLAYER_LOGIN")
local status, health = frames[2], frames[3]
local function statusContains(text)
    return status.shown and status.text.value:find(text, 1, true)
end
local function visibleHealth() return health.shown and health.alpha == 1 end
local function reset()
    defaults()
    UnitHealthPercent = healthPercent
    MimQoLPetReminder_ApplySettings()
    fire("PLAYER_ENTERING_WORLD")
    advance(1)
end
advance(2)
check(not status.shown and not visibleHealth(), "healthy attacking pet warned")
check(status.text.font == "Fonts\\2002.TTF", "locale font was not preserved")

state.pet = false
fire("UNIT_PET", "player")
advance(1)
check(not status.shown, "missing alert ignored summon grace")
advance(1)
check(statusContains("야수를 소환"), "missing hunter pet did not warn")
state.pet = true
fire("UNIT_PET", "player")
check(not status.shown, "summon did not clear alert")

state.dead = true
fire("UNIT_HEALTH", "pet")
check(statusContains("야수 되살리기"), "dead hunter pet needs revive guidance")
state.pet, state.dead = false, false
fire("UNIT_PET", "player")
check(statusContains("야수 되살리기"), "vanished dead hunter pet lost revive guidance")
state.pet, state.health = true, 5
fire("UNIT_PET", "player")
check(not status.shown and not health.shown, "revive grace was not respected")
advance(1)
check(visibleHealth() and health.text.value:find("동물 치료", 1, true), "hunter healing guidance missing")
state.health = 30
fire("UNIT_HEALTH", "pet")
check(not visibleHealth(), "30 percent should not warn")
state.health = 29
fire("UNIT_HEALTH", "pet")
check(visibleHealth(), "health below 30 percent should warn")

reset()
state.target = false
advance(4)
check(not status.shown, "idle pet warned outside combat")
state.combat = true
fire("PLAYER_REGEN_DISABLED")
advance(2.75)
check(not status.shown, "attack warning fired too early")
advance(0.25)
check(statusContains("공격 명령"), "idle pet in combat did not warn")
state.target = true
advance(0.25)
check(not status.shown, "pet target did not clear idle warning")
state.target = false
advance(2)
state.target = true
advance(0.25)
state.target = false
advance(2)
check(not status.shown, "target switch grace did not restart")
state.combat = false
fire("PLAYER_REGEN_ENABLED")
check(not status.shown, "combat exit did not clear warning")

-- Still flagged in combat, but not fighting anything the pet should attack.
for _, case in ipairs({
    { "enemyDead", true, "target already dead (combat lingering after a kill)" },
    { "enemy", false, "no target (group in combat elsewhere)" },
    { "enemyHostile", false, "friendly target" },
    { "enemyCombat", false, "target not in combat" },
}) do
    reset()
    state.combat, state.target = true, false
    state[case[1]] = case[2]
    advance(4)
    check(not status.shown, "idle warning while " .. case[3])
end
reset()
state.combat, state.target, state.enemyCombat = true, false, "secret"
advance(4)
check(statusContains("공격 명령"), "unreadable target combat state does not block the warning")

for _, field in ipairs({ "mounted", "taxi", "vehicle", "vehicleUI", "playerDead", "feign", "petBattle", "shift" }) do
    reset()
    state.pet = false
    advance(3)
    check(status.shown, "suppression setup failed")
    state[field] = true
    advance(0.25)
    check(not status.shown and not health.shown, field .. " did not suppress alerts")
    state[field] = false
    advance(3)
    check(status.shown, field .. " did not resume alerts")
end

reset()
state.spec, state.pet = 2, false
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
advance(3)
check(not status.shown, "petless marksman warned")
state.talent = 1223323
fire("PLAYER_TALENT_UPDATE")
advance(3)
check(statusContains("야수를 소환"), "marksman pet talent was not detected")
state.talent, state.known = nil, 1223323
fire("SPELLS_CHANGED")
advance(3)
check(status.shown, "spell book talent was not detected")

reset()
state.class, state.spec, state.pet = "WARLOCK", 3, false
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
advance(3)
check(statusContains("악마를 소환"), "warlock summon guidance missing")
state.talent = 108503
fire("PLAYER_TALENT_UPDATE")
check(not status.shown, "sacrifice build warned about missing demon")
state.spec = 2
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
advance(3)
check(statusContains("악마를 소환"), "demonology must require a demon")
state.pet, state.dead = true, true
fire("UNIT_PET", "player")
check(statusContains("다시 소환"), "dead demon needs resummon guidance")
state.dead, state.health = false, 20
fire("UNIT_HEALTH", "pet")
advance(1)
check(visibleHealth() and health.text.value:find("생명력 집중", 1, true), "warlock healing guidance missing")

reset()
state.pet = secret
advance(3)
check(not status.shown and not health.shown, "unknown pet existence treated as missing")
state.pet, state.dead = true, secret
advance(3)
check(not status.shown and not health.shown, "unknown death state produced warning")
state.dead, state.secretAlpha = false, true
advance(2)
check(health.shown and rawequal(health.alpha, secret), "secret alpha did not reach UI unchanged")
UnitHealthPercent = nil
state.health = secret
advance(0.25)
check(not health.shown, "restricted fallback health was used")
state.health, state.maximum = 20, secret
advance(0.25)
check(not health.shown, "restricted maximum health was used")
state.maximum = 100
advance(0.25)
check(visibleHealth(), "readable fallback health did not warn")
UnitHealthPercent = healthPercent
state.curveError = true
advance(0.25)
check(visibleHealth(), "curve API error did not fall back safely")

reset()
state.pet = false
advance(3)
MimQoLDB.petReminderMissing = false
MimQoLPetReminder_ApplySettings()
advance(3)
check(not status.shown, "disabled missing option still warned")
state.pet, state.combat, state.target, state.health = true, true, false, 10
MimQoLDB.petReminderAttack, MimQoLDB.petReminderHealth = false, false
MimQoLPetReminder_ApplySettings()
advance(4)
check(not status.shown and not health.shown, "disabled child options still warned")
MimQoLPetReminder_Test()
check(status.shown and visibleHealth(), "preview was not displayed")
advance(6)
check(not status.shown and not health.shown, "preview did not expire")
MimQoLPetReminder_Test()
MimQoLDB.petReminder = false
MimQoLPetReminder_ApplySettings()
check(not status.shown and not health.shown, "disable left a preview visible")
check(next(driver.events) == nil and driver.scripts.OnUpdate == nil, "disable left monitoring active")
MimQoLDB.petReminder = true
MimQoLPetReminder_ApplySettings()
check(driver.events.UNIT_HEALTH == "pet" and driver.scripts.OnUpdate, "re-enable did not restore monitoring")

reset()
state.class = "MAGE"
MimQoLPetReminder_ApplySettings()
check(not status.shown and not health.shown and next(driver.events) == nil
    and driver.scripts.OnUpdate == nil, "unsupported class should not monitor")

-- Load the real settings module and exercise initialization via its slash entry.
-- No extracted/reimplemented defaults or migration code is used by this test.
StaticPopupDialogs, SlashCmdList = {}, {}
assert(loadfile("MimQoL.lua"))("MimQoL")
local oldProfile = { marker = "preserve action bars" }
MimQoLDB = { lustReminder = true, lustReminderAllClasses = false,
    lustReminderDungeonPull = true, lustReminderDebuffExpiry = false,
    autoSellJunk = false, actionBarKeeper = oldProfile, petReminderHealth = false }
local previewCalls = 0
MimQoLPetReminder_Test = function() previewCalls = previewCalls + 1 end
SlashCmdList.MIMQOL("pettest")
check(previewCalls == 1, "pettest command was not connected")
check(MimQoLDB.petReminder == true and MimQoLDB.petReminderMissing == true
    and MimQoLDB.petReminderAttack == true, "new defaults were not initialized")
check(MimQoLDB.petReminderHealth == false and MimQoLDB.autoSellJunk == false
    and MimQoLDB.actionBarKeeper == oldProfile, "existing settings were overwritten")
check(MimQoLDB.lustReminder == nil and MimQoLDB.lustReminderAllClasses == nil
    and MimQoLDB.lustReminderDungeonPull == nil and MimQoLDB.lustReminderDebuffExpiry == nil,
    "obsolete bloodlust settings were not removed")
local applyCalls = 0
MimQoLPetReminder_ApplySettings = function() applyCalls = applyCalls + 1 end
SlashCmdList.MIMQOL("pet")
check(MimQoLDB.petReminder == false and applyCalls == 1, "pet command did not disable module")
SlashCmdList.MIMQOL("pet")
check(MimQoLDB.petReminder == true and applyCalls == 2, "pet command did not re-enable module")
print("pet_reminder_smoke: " .. checks .. " checks passed")
