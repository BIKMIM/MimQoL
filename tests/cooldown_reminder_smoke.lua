local e = dofile("tests/cooldown_reminder_fixture.lua")
local api, checks = e.api, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
check(MimQoLDB.cooldownReminder == false, "saved disabled setting preserved")
check(MimQoLDB.cooldownReminderSeconds == 7.5 and MimQoLDB.cooldownReminderSoundFile == "kept.mp3", "saved choices preserved")
check(MimQoLDB.cooldownReminderTiming == "soon" and MimQoLDB.cooldownReminderIconEnabled, "missing defaults initialized")
e.reset("")
api.ApplySettings()
check(not api.Add("spell", "oops"), "invalid ID rejected")
check(not api.Add("spell", 999) and not api.Add("spell", 998), "unknown and passive spells rejected")
check(not api.Add("item", 999) and not api.Add("item", 998), "unknown and non-trinket items rejected")
check(api.Add("spell", 101), "manual spell ID accepted")
check(not api.Add("spell", 101), "duplicate ID rejected")
e.cursor = { "spell", 9, "spell", 102 }
check(api.AddFromCursor() and api.GetEntries()[2].id == 102, "spell drop uses fourth cursor result")
check(e.cleared == 1, "successful drop clears cursor")
e.cursor = { "item", 201 }
check(api.AddFromCursor() and e.requestedItem == 201, "item drop and asynchronous data request")
e.combat = true
e.cursor = { "spell", 7, "spell", 103 }
check(not api.AddFromCursor() and e.cleared == 2, "combat rejection preserves cursor")
e.combat = false
e.cursor = { "macro", 4 }
check(not api.AddFromCursor() and e.cleared == 2, "unsupported drop preserves cursor")
api.Remove("spell", 102)
check(#api.GetEntries() == 2 and api.GetEntries()[2].id == 201, "removal preserves other entries")
for id = 301, 498 do check(api.Add("spell", id), "entry capacity") end
check(not api.Add("spell", 499) and #api.GetEntries() == 200, "200 entry limit")
MimQoLDB.cooldownReminderEntries = "spell:101\nspell:00101\nspell:0\nbad\nitem:201"
check(#api.GetEntries() == 2, "saved entries normalized and sanitized")

e.reset()
local state = e.spell(101, 20)
api.ApplySettings()
e.event("SPELL_UPDATE_COOLDOWN")
local card = e.card()
check(card.time.fontSize == 22 and card.time.fontFlags == "OUTLINE", "time number has size and outline")
check(#e.sounds == 0 and card.alpha == 0, "initial active cooldown is silent and transparent")
state.remaining = 5; e.tick()
check(#e.sounds == 1 and card.alpha == 1, "public threshold plays once and displays")
state.remaining = 4; e.tick()
check(#e.sounds == 1, "threshold sound does not repeat")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 1 and card.time:GetText() == "준비", "finish displayed without double audio")
e.tick(4)
check(card.alpha == 0, "ready message expires")
state.remaining, state.active = 30, true; e.event("SPELL_UPDATE_COOLDOWN")
state.remaining, state.active = 0, false; e.tick()
check(#e.sounds == 2, "cooldown reset triggers ready without waiting original duration")

e.reset()
state = e.spell(101, 20, true)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining = 4; e.tick()
check(rawequal(card.alpha, e.secret) and rawequal(card.time.formattedValue, e.secret), "secret curve and time sent directly to native UI")
check(#e.sounds == 0, "secret remaining time never triggers early audio")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 1 and card.time:GetText() == "준비", "public active transition triggers restricted cooldown completion")
e.event("SPELL_UPDATE_COOLDOWN"); e.tick()
check(#e.sounds == 1, "duplicate cooldown event cannot repeat completion")

e.reset()
state = e.spell(101, 1, true); state.gcd = true
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining, state.active, state.gcd = 0, false, false; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 0, "GCD alone never arms completion")
state.remaining, state.active = 20, true; e.event("SPELL_UPDATE_COOLDOWN")
state.gcd = true; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 0, "GCD event cannot finish an active cooldown")
state.gcd, state.active, state.remaining = false, false, 0; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 1, "genuine finish after GCD")

e.reset()
state = e.spell(101, 1, true); state.gcd = nil
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.active, state.remaining = false, 0; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 1, "missing GCD flag is a real cooldown, as reported in game")
state.active, state.gcd, state.remaining = e.secret, e.secret, 20; e.event("SPELL_UPDATE_COOLDOWN")
state.active, state.gcd, state.remaining = false, false, 0; e.event("SPELL_UPDATE_COOLDOWN")
check(#e.sounds == 1, "unexpected secret status fields are not treated as usable booleans")
local savedAPI = C_Spell.GetSpellCooldownDuration
C_Spell.GetSpellCooldownDuration = function() error("unsupported") end
e.tick(4)
check(not card:IsShown() and #e.sounds == 1, "unavailable duration API fails silently")
C_Spell.GetSpellCooldownDuration = savedAPI

e.reset()
state = e.spell(101, 20, true, true)
api.ApplySettings(); e.event("SPELL_UPDATE_CHARGES")
state.remaining = 20; e.event("SPELL_UPDATE_CHARGES")
check(#e.sounds == 0, "restricted intermediate charge not guessed from event")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_CHARGES")
check(#e.sounds == 1, "restricted full recharge signals completion")

e.reset()
state = e.spell(101, 20, false, 1)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining = 4; e.tick()
check(#e.sounds == 1 and card.alpha == 1, "one-charge table still warns from the ordinary cooldown")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
check(card.time:GetText() == "준비" and e.pulse(), "one-charge table still completes from the ordinary cooldown")

e.reset()
state = e.spell(101, 20, true)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining, state.active = 0, false
e.event("PLAYER_ENTERING_WORLD")
check(#e.sounds == 0, "world entry clears previous completion tracking")

for _, suppression in ipairs({ "shift", "dead", "combatOnly" }) do
    e.reset()
    state = e.spell(101, 20, true)
    api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
    if suppression == "combatOnly" then MimQoLDB.cooldownReminderCombatOnly = true else e[suppression] = true end
    state.remaining, state.active = 0, false; e.tick()
    check(#e.sounds == 0 and not card:IsShown() and not e.pulse(), "suppressed completion is silent: " .. suppression)
    e.shift, e.dead, e.combat = false, false, true; e.tick()
    check(#e.sounds == 0 and card.time:GetText() ~= "준비", "no deferred completion: " .. suppression)
end

e.reset("item:201")
e.inventory[13] = 201
e.items[201] = { start = e.now, duration = 20 }
api.ApplySettings()
e.tick(16)
check(#e.sounds == 1 and card.alpha == 1, "equipped trinket early warning")
e.tick(4)
check(#e.sounds == 1 and card.time:GetText() == "준비", "trinket ready has no double sound")
e.items[201] = { start = e.now, duration = 20 }; e.tick()
e.inventory[13] = nil; e.event("PLAYER_EQUIPMENT_CHANGED")
e.tick(25)
check(#e.sounds == 1 and not card:IsShown(), "unequipped trinket cannot produce completion")
e.inventory[13] = 201; e.items[201] = { secret = true }; e.event("PLAYER_EQUIPMENT_CHANGED")
check(#e.sounds == 1 and not card:IsShown(), "restricted trinket time is unknown, not ready")

e.reset()
state = e.spell(101, 20, true)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
api.Remove("spell", 101); api.Add("spell", 101)
state.remaining, state.active = 0, false; e.tick()
check(#e.sounds == 0, "removed entry cannot retain an armed completion")
state.remaining, state.active = 20, true; e.event("SPELL_UPDATE_COOLDOWN")
MimQoLDB.cooldownReminder = false; api.ApplySettings()
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN"); e.tick()
check(#e.sounds == 0 and not card:IsShown(), "disable removes visible and event effects")
MimQoLDB.cooldownReminder = true; api.ApplySettings()
check(#e.sounds == 0, "re-enabling ready ability is silent")
state.remaining, state.active = 20, true; e.event("SPELL_UPDATE_COOLDOWN")
e.known[101] = false; e.event("SPELLS_CHANGED")
state.remaining, state.active = 0, false; e.tick()
check(#e.sounds == 0 and not card:IsShown(), "unlearned or other-spec ability cannot signal")

e.reset()
e.override = { [101] = 103 }
state = e.spell(103, 20, true)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining, state.active = 0, false; e.tick()
check(#e.sounds == 1, "known override tracked for registered base spell")
e.reset()
e.override = { [101] = 103 }
state = e.spell(101, 120)
local ability = e.spell(103, 15)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
ability.remaining = 4; e.tick()
check(#e.sounds == 0 and card.alpha == 0, "temporary override countdown is not shown for the registered spell")
ability.remaining, ability.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN"); e.tick()
check(#e.sounds == 0 and not e.pulse() and card.time:GetText() ~= "준비",
    "temporary override finishing cannot complete the registered cooldown")
e.override = nil
state.remaining = 4; e.tick()
check(#e.sounds == 1 and card.alpha == 1, "registered cooldown still warns after the override ends")
state.remaining, state.active = 0, false; e.tick()
check(e.pulse() and card.time:GetText() == "준비", "registered cooldown completes after the override ends")
e.reset()
state = e.spell(101, 20)
MimQoLDB.cooldownReminderTiming = "ready"
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
state.remaining = 4; e.tick()
check(#e.sounds == 0 and not card:IsShown(), "ready-only mode suppresses early warning")
state.remaining, state.active = 0, false; e.tick()
check(#e.sounds == 1 and card:IsShown(), "ready-only completion")
MimQoLDB.cooldownReminderIconEnabled, MimQoLDB.cooldownReminderTextEnabled = false, false
api.ApplySettings()
check(not card:IsShown(), "sound-only mode hides card")

e.reset()
state = e.spell(101, 20, true)
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
check(api.Preview() and #e.sounds == 1 and card.alpha == 1 and e.pulse(), "preview demonstrates configured UI, pulse and sound")
state.remaining, state.active = 0, false
e.tick(6)
check(#e.sounds == 1 and card.time:GetText() ~= "준비" and not e.pulse(), "preview expiry does not replay missed completion")
e.combat = true
check(not api.SetMoving(true), "moving cannot start in combat")
e.combat = false
check(api.SetMoving(true) and api.IsMoving(), "explicit moving mode")
api.ClosePreview()
check(not api.IsMoving(), "close locks movement")

e.reset()
state = e.spell(101, 20, true)
MimQoLDB.cooldownReminderPulseSize, MimQoLDB.cooldownReminderPulseOpacity = 100, 80
MimQoLDB.cooldownReminderPulseSpeed = 2
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
check(not e.pulse(), "running cooldown does not pulse")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
local pulse = e.pulse()
check(pulse and pulse.icon.texture == 101 and pulse.alpha == 0 and pulse.width == 100,
    "restricted completion starts a transparent pulse with the entry icon")
e.tick(0.1)
check(pulse.alpha == 0.8 and pulse.width > 100 and pulse.width == pulse.height, "pulse holds configured opacity while growing")
e.event("SPELL_UPDATE_COOLDOWN")
local running = 0
for _, frame in ipairs(e.frames) do if frame.peak and frame:IsShown() then running = running + 1 end end
check(running == 1, "duplicate cooldown event cannot repeat pulse")
e.tick(0.4)
check(not pulse:IsShown() and not pulse.scripts.OnUpdate, "pulse hides itself after the animation")
state.remaining, state.active = 20, true; e.event("SPELL_UPDATE_COOLDOWN")
MimQoLDB.cooldownReminderPulse = false; api.ApplySettings()
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
check(not e.pulse() and #e.sounds == 2 and card.time:GetText() == "준비", "pulse toggle off keeps other completion outputs")
MimQoLDB.cooldownReminderPulse = true; api.ApplySettings()
state.remaining, state.active = 20, true; e.event("SPELL_UPDATE_COOLDOWN")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN")
check(e.pulse(), "re-enabled pulse resumes on completion")
MimQoLDB.cooldownReminder = false; api.ApplySettings()
check(not e.pulse(), "disabling the feature hides a running pulse")

e.reset("spell:101:6\nitem:201:6\nspell:102:0")
state = e.spell(101, 15, true)
e.castCounts = { [101] = e.secret }
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
local list = api.GetEntries()
check(list[1].count == 6 and list[2].count == nil and list[3].count == nil, "count minimum parsed for spells only")
check(not card:IsShown() and card.stack.minimum == 5 and card.stack.maximum == 6,
    "count-gated spell hidden on cooldown with a one-step bar range")
state.remaining, state.active = 0, false; e.event("SPELL_UPDATE_COOLDOWN"); e.tick()
check(card:IsShown() and rawequal(card.stack.value, e.secret), "ready count-gated spell hands the restricted count to the bar")
check(#e.sounds == 0 and not e.pulse() and not card.time:IsShown() and not card.label:IsShown(),
    "count-gated spell has no sound, pulse or text")
state.active, state.gcd = true, true; e.event("SPELL_UPDATE_COOLDOWN"); e.tick()
check(card:IsShown(), "GCD alone keeps a count-gated spell visible")
state.gcd = nil; e.tick()
check(not card:IsShown(), "real cooldown hides a count-gated spell")
state.active = false
MimQoLDB.cooldownReminderTiming = "ready"; api.ApplySettings()
check(card:IsShown() and card.stack:IsShown(), "ready-only timing does not hide a count-gated spell")
e.shift = true; e.tick()
check(not card:IsShown(), "Shift hides a count-gated spell")
e.shift = false
api.SetCount("spell", 101, "")
check(MimQoLDB.cooldownReminderEntries == "spell:101\nitem:201\nspell:102" and not card.stack:IsShown()
    and card.icon:IsShown(), "clearing the minimum restores an ordinary entry")
api.SetCount("item", 201, 6); api.SetCount("spell", 102, 250)
check(MimQoLDB.cooldownReminderEntries == "spell:101\nitem:201\nspell:102:99", "minimum is spell-only and clamped")

e.reset("spell:101\nspell:102")
e.spell(101, 20, true); e.spell(102, 20, true)
api.ApplySettings()
local second = e.card(2)
check(second.point[1] == "TOPLEFT" and second.point[4] == 240 and not second.mouse, "default grid slot ignores the mouse")
second.scripts.OnDragStart(second); second.scripts.OnDragStop(second)
check(not second.dragging and MimQoLDB.cooldownReminderPositions == "", "locked alerts cannot be dragged")
check(api.SetMoving(true) and second.mouse == true, "move mode lets a single alert be dragged")
check(second.hitInsets[1] == 94 and second.hitInsets[2] == 94 and second.hitInsets[3] == 0 and second.hitInsets[4] == 74,
    "only the icon can be grabbed, so neighbouring alerts do not cover each other")
MimQoLDB.cooldownReminderIconEnabled = false; api.ApplySettings()
check(api.IsMoving() and second.hitInsets[1] == 0 and second.hitInsets[4] == 66, "text-only alerts are grabbed by the text block")
MimQoLDB.cooldownReminderIconEnabled = true; api.ApplySettings()
e.combat = true
second.scripts.OnDragStart(second); second.scripts.OnDragStop(second)
check(not second.dragging and MimQoLDB.cooldownReminderPositions == "", "alerts cannot be dragged in combat")
e.combat = false
second.scripts.OnDragStart(second)
second.centerX, second.top = 630.4, 349.4
second.scripts.OnDragStop(second)
check(MimQoLDB.cooldownReminderPositions == "spell:102=130,-51" and second.point[1] == "TOP"
    and second.point[4] == 130 and second.point[5] == -51, "dropped alert keeps its own spot from the group center")
api.ClosePreview()
check(second.mouse == false, "locking stops alerts from intercepting clicks")
api.ApplySettings()
check(second.point[4] == 130 and e.card(1).point[1] == "TOPLEFT", "saved spot survives a refresh and leaves other alerts in the grid")
api.Remove("spell", 102)
check(MimQoLDB.cooldownReminderPositions == "", "removing an entry drops its saved spot")
MimQoLDB.cooldownReminderEntries = "spell:101\nspell:102"
MimQoLDB.cooldownReminderPositions = "spell:101=5,6\nbad\nspell:102=-7,8"; api.ApplySettings()
check(e.card(1).point[4] == 5 and second.point[4] == -7 and second.point[5] == 8, "saved spots are parsed and sanitized")
api.ResetPositions()
check(MimQoLDB.cooldownReminderPositions == "" and second.point[1] == "TOPLEFT", "reset returns every alert to the grid")

e.reset("spell:101\nspell:102")
local first, other = e.spell(101, 20), e.spell(102, 20)
MimQoLDB.cooldownReminderEntryOptions = "spell:101|seconds=10|size=64|soundType=id|soundID=123|bogus=1\nspell:102|soundType=none"
api.ApplySettings(); e.event("SPELL_UPDATE_COOLDOWN")
local card1, card2 = e.card(1), e.card(2)
check(card1.icon.width == 64 and card2.icon.width == 48, "own icon size, others follow the shared size")
first.remaining, other.remaining = 9, 9; e.tick()
check(#e.sounds == 1 and e.sounds[1][1] == "kit" and e.sounds[1][2] == 123 and card1.alpha == 1 and card2.alpha == 0,
    "own warning time and own sound")
other.remaining = 4; e.tick()
check(#e.sounds == 1 and card2.alpha == 1, "muted alert still shows but stays silent")
check(api.TestSound({ kind = "spell", id = 101 }) and not api.TestSound({ kind = "spell", id = 102 })
    and api.TestSound(), "sound test follows each alert's own sound")
api.SetEntryOption("spell", 101, "x", "15"); api.SetEntryOption("spell", 101, "y", "-30")
api.SetEntryOption("spell", 102, "x", 15); api.SetEntryOption("spell", 102, "y", -30)
check(MimQoLDB.cooldownReminderPositions == "spell:101=15,-30\nspell:102=15,-30"
    and card1.point[4] == 15 and card2.point[4] == 15 and card1.point[5] == -30 and card2.point[5] == -30,
    "typed X/Y can stack several alerts on one spot")
api.SetEntryOption("spell", 101, "size", "999"); api.SetEntryOption("spell", 101, "seconds", "")
check(api.GetEntryOptions("spell", 101).size == 200 and api.GetEntryOptions("spell", 101).seconds == nil
    and api.GetEntryOptions("spell", 101).x == 15, "own size clamped, emptied field follows the shared value")
api.SetEntryOption("spell", 101, "x", "")
check(MimQoLDB.cooldownReminderPositions == "spell:102=15,-30" and card1.point[1] == "TOPLEFT", "emptied X returns to the grid")
api.ResetEntry("spell", 102)
check(MimQoLDB.cooldownReminderPositions == "" and not MimQoLDB.cooldownReminderEntryOptions:find("102"), "reset clears one alert")
api.Remove("spell", 101)
check(MimQoLDB.cooldownReminderEntryOptions == "", "removing an entry drops its own settings")

e.reset("spell:101")
MimQoLDB.cooldownReminderProfiles = nil
MimQoLDB.cooldownReminderEntryOptions = "spell:101|size=60"
api.ApplySettings()
local hunter = MimQoLDB.cooldownReminderProfiles.HUNTER
check(hunter.cooldownReminderEntries == "spell:101" and hunter.cooldownReminderEntryOptions == "spell:101|size=60",
    "first run keeps the old list for the current class")
local realClass = UnitClass
UnitClass = function() return "흑마법사", "WARLOCK" end
api.ApplySettings()
check(MimQoLDB.cooldownReminderEntries == "" and MimQoLDB.cooldownReminderEntryOptions == ""
    and MimQoLDB.cooldownReminderY == 40, "a new class starts with its own empty list")
api.Add("spell", 202); api.SetEntryOption("spell", 202, "seconds", 8)
UnitClass = realClass; api.ApplySettings()
check(MimQoLDB.cooldownReminderEntries == "spell:101" and MimQoLDB.cooldownReminderEntryOptions == "spell:101|size=60",
    "returning to a class restores its list")
UnitClass = function() return "흑마법사", "WARLOCK" end
api.ApplySettings()
check(MimQoLDB.cooldownReminderEntries == "spell:202" and MimQoLDB.cooldownReminderEntryOptions == "spell:202|seconds=8",
    "characters of one class share one list and its settings")
UnitClass = realClass; api.ApplySettings()

-- Specializations: each spec sees only its own list; the old class list seeds new specs.
local spec, specLoaded = 1, true
GetSpecialization = function() if specLoaded then return spec end end
GetSpecializationInfo = function(index) return 252 + index, "전문화" .. index end
api.ApplySettings()
check(MimQoLDB.cooldownReminderEntries == "spell:101" and api.GetSpecName() == "전문화1",
    "first spec starts from the old class list")
api.Remove("spell", 101); api.Add("spell", 301)
spec = 2; e.event("PLAYER_SPECIALIZATION_CHANGED")
check(MimQoLDB.cooldownReminderEntries == "spell:101", "another spec does not see the first spec's changes")
api.Add("spell", 302)
specLoaded = false; api.ApplySettings()
check(MimQoLDB.cooldownReminderEntries == "spell:101\nspell:302", "unknown spec keeps the bound list")
specLoaded, spec = true, 1; e.event("PLAYER_SPECIALIZATION_CHANGED")
check(MimQoLDB.cooldownReminderEntries == "spell:301", "returning to a spec restores its own list")
check(#api.GetEntries() == 1 and api.GetEntries()[1].id == 301, "settings list shows the current spec only")
GetSpecialization, GetSpecializationInfo = nil, nil
MimQoLDB.cooldownReminderProfiles = nil
api.ApplySettings()

-- Moving/preview shows only alerts this spec can use; they take the grid slots.
e.reset("spell:401\nspell:402")
e.spell(402, 0)
api.ApplySettings()
api.SetMoving(true)
check(not e.card(1):IsShown() and e.card(2):IsShown(), "move mode hides an unlearned spell")
check(e.card(2).point[4] == 0 and e.card(2).point[5] == 0, "usable alert takes the first grid slot")
api.SetMoving(false)
e.known[402] = false; api.ApplySettings(); api.SetMoving(true)
check(e.card(1):IsShown() and e.card(2):IsShown(), "with nothing usable every alert is shown to place")
api.SetMoving(false)


e.reset("")
api.ApplySettings()
api.TestPulse()
check(e.pulse() and e.pulse().icon.texture == 134400, "pulse test works without entries")
MimQoLDB.cooldownReminderSoundType = "id"
MimQoLDB.cooldownReminderSoundID = 123
check(api.TestSound() and e.sounds[1][1] == "kit" and e.sounds[1][3] == "Dialog", "sound kit uses Dialog")
MimQoLDB.cooldownReminderSoundID = 600001
check(api.TestSound() and e.sounds[2][1] == "file", "large sound ID uses FileDataID")
MimQoLDB.cooldownReminderSoundType, MimQoLDB.cooldownReminderSoundFile = "custom", "mine.mp3"
e.soundMatch = "Interface\\AddOns\\MimDice\\sounds\\mine.mp3"
check(api.TestSound(), "MimDice bundled filename fallback")
check(e.sounds[3][2] == "sound\\mine.mp3" and e.sounds[4][2] == "sounds\\mine.mp3", "external sound lookup order")
MimQoLDB.cooldownReminderSoundFile = "sound\\direct.mp3"
e.soundMatch = "sound\\direct.mp3"
local count = #e.sounds
check(api.TestSound() and #e.sounds == count + 1, "explicit path not prefixed")
e.muted = true; count = #e.sounds
check(not api.TestSound() and #e.sounds == count, "muted Dialog is reported without changing CVars")
e.muted = false
MimQoLDB.cooldownReminderSoundType, MimQoLDB.cooldownReminderSoundID = "id", "bad"
check(not api.TestSound(), "invalid sound ID rejected")
print("cooldown_reminder_smoke: " .. checks .. " checks passed")
