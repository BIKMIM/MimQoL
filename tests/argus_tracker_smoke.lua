-- Argus portal tracker: cast-based demon count, restricted (secret) buff
-- lookups, estimated vs real timer, reload restore, layout/preview isolation,
-- moving and feature toggles. Native taint behaviour is not proven here.
local env = dofile("tests/cooldown_reminder_fixture.lua")

local checks = 0
local function check(condition, message)
    checks = checks + 1
    if not condition then error("check " .. checks .. " failed: " .. message, 2) end
end

local Frame = getmetatable(CreateFrame("Frame"))
function Frame:RegisterUnitEvent(event, unit) self.events[event] = unit or true end
function Frame:SetFormattedText(format, ...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then self.text = "secret"; return end
    end
    self.text = string.format(format, ...)
end

-- Environment knobs.
local specID = 266
C_SpecializationInfo = {
    GetSpecialization = function() return 2 end,
    GetSpecializationInfo = function() return specID end,
}
local secretAuras = false -- in instanced combat: true
local aura                -- nil = absent, table = present
C_Secrets = {
    ShouldSpellAuraBeSecret = function(id) assert(id == 1276166); return secretAuras end,
    ShouldAurasBeSecret = function() return secretAuras end,
}
local durationMode = "ok" -- "ok", "nil", "unbindable"
local durationRequests = 0
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
        assert(id == 1276166, "only the Argus buff is looked up")
        -- Blizzard: a restricted aura lookup returns nothing.
        if secretAuras then return nil end
        return aura
    end,
    GetAuraDuration = function(unit, instanceID)
        durationRequests = durationRequests + 1
        if issecretvalue(instanceID) then error("restricted aura instance") end
        if durationMode == "nil" then return nil end
        return { kind = "aura", id = instanceID, bad = durationMode == "unbindable" }
    end,
}
C_DurationUtil = {
    CreateDurationTextBinding = function()
        local binding = { enabled = false }
        function binding:SetFontString(text) self.fontString = text end
        function binding:SetFormatter(formatter) self.formatter = formatter end
        function binding:SetTextColorCurve(curve, property) self.curve, self.property = curve, property end
        function binding:SetDuration(object)
            if object.bad then error("not a duration") end
            self.duration = object
        end
        function binding:SetEnabled(value) self.enabled = value end
        return binding
    end,
    CreateDuration = function()
        return { kind = "local", SetTimeFromStart = function(self, start, seconds) self.start, self.seconds = start, seconds end }
    end,
}
C_StringUtil = { CreateNumericRuleFormatter = function()
    return { SetBreakpoints = function(self, points) self.points = points end }
end }
C_CurveUtil.CreateColorCurve = function()
    return { SetType = function() end, points = {}, AddPoint = function(self, x, color) self.points[#self.points + 1] = { x, color } end }
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
Enum.NumericRuleFormatRounding = { Up = 1, Down = 2, Nearest = 3 }
Enum.DurationTextBindingProperty = { RemainingDuration = 1 }

check(MimQoLDB.argusTracker == true and MimQoLDB.argusTrackerHold == 5 and MimQoLDB.argusTrackerDuration == 25, "defaults present")
-- The old 15 s guess is replaced once; a typed value is kept.
do
    local saved = MimQoLDB
    MimQoLDB = { argusTrackerDuration = 15 }
    SlashCmdList = {}
    assert(loadfile("MimQoL.lua"))("MimQoL")
    SlashCmdList.MIMQOL("status")
    check(MimQoLDB.argusTrackerDuration == 25 and MimQoLDB.argusTrackerDuration25, "old 15 s default migrated to 25 s")
    MimQoLDB.argusTrackerDuration = 15
    SlashCmdList = {}
    assert(loadfile("MimQoL.lua"))("MimQoL")
    SlashCmdList.MIMQOL("status")
    check(MimQoLDB.argusTrackerDuration == 15, "migration runs once; a later 15 is the user's choice")
    MimQoLDB = { argusTrackerDuration = 18 }
    SlashCmdList = {}
    assert(loadfile("MimQoL.lua"))("MimQoL")
    SlashCmdList.MIMQOL("status")
    check(MimQoLDB.argusTrackerDuration == 18, "typed value kept")
    MimQoLDB = saved
    SlashCmdList = {}
    assert(loadfile("MimQoL.lua"))("MimQoL")
    SlashCmdList.MIMQOL("status")
end
MimQoLDB.argusTrackerDuration = 15

local driver, api
local function load()
    local before = #env.frames
    dofile("ArgusTracker.lua")
    driver = env.frames[before + 1]
    api = _G.MimQoLArgusTracker
end
load()
check(type(api) == "table" and type(api.ApplyLayout) == "function", "public API")

local function fire(event, ...) driver.scripts.OnEvent(driver, event, ...) end
local function tick(delta)
    env.now = env.now + (delta or 0.1)
    if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, delta or 0.1) end
end
local function display()
    for i = #env.frames, 1, -1 do
        local frame = env.frames[i]
        if frame.count and frame.next and frame.time and frame.tag then return frame end
    end
end
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", id) end
local function auraEvent(info) fire("UNIT_AURA", "player", info or {}) end
local function settle() tick(1); tick(30) end
local TYRANT, HOG = 265187, 105174

-- 1. Other spec: no combat events.
specID = 267
fire("PLAYER_LOGIN")
check(not driver.events.UNIT_SPELLCAST_SUCCEEDED and not driver.events.UNIT_AURA, "destruction registers nothing")
check(driver.events.PLAYER_SPECIALIZATION_CHANGED, "waits for a spec change")

-- 2. Instanced combat: the buff is secret, so the lookup returns nothing.
specID = 266
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
check(driver.events.UNIT_SPELLCAST_SUCCEEDED == "player" and driver.events.UNIT_AURA == "player", "player unit events")
secretAuras = true
aura = nil
cast(TYRANT)
local frame = display()
check(frame and frame:IsShown(), "Tyrant cast shows the tracker")
check(frame.count.text == "0마리" and frame.next.text == "○○", "starts at zero")
check(frame.tag.text == "(추정)" and frame.binding.duration.kind == "local"
    and frame.binding.duration.seconds == 15 and frame.binding.enabled, "estimated timer from the buff length")
-- Codex 1: a restricted lookup is unknown, not "ended".
auraEvent({ updatedAuraInstanceIDs = { env.secret } })
auraEvent({ removedAuraInstanceIDs = { env.secret } })
check(api.GetState().active, "restricted lookup does not end the segment")
cast(HOG)
check(frame.count.text == "0마리" and frame.next.text == "●○", "one cast in")
cast(HOG)
check(frame.count.text == "1마리" and frame.next.text == "●●", "second cast is a demon, shown as a full pair")
tick(0.7)
check(frame.next.text == "○○", "the pair resets after the flash")
cast(HOG)
cast(686); cast(env.secret)
check(api.GetState().demons == 1 and api.GetState().progress == 1, "other and secret spell IDs ignored")
-- Codex 7: a cast processed after the estimated end, before OnUpdate, is not counted.
env.now = env.now + 15
cast(HOG)
check(not api.GetState().active and api.GetState().holding and api.GetState().demons == 1, "late cast ends instead of counting")
check(frame.count.text == "이번 폭군 1마리" and frame.next.text == "" and frame.tag.text == "", "result held")
check(frame.binding.enabled == false, "binding released")
tick(5.1)
check(not frame:IsShown() and not api.GetState().holding, "hidden after the hold")

-- 3. Readable buff (outside restrictions): exact end, learned length, real timer, stack check.
secretAuras = false
durationMode = "ok"
cast(TYRANT)
aura = { auraInstanceID = 77, applications = 1, duration = 13, expirationTime = env.now + 13 }
auraEvent({ addedAuras = {} })
local s = api.GetState()
check(s.source == "aura" and s.endPrecise and s.endAt == env.now + 13, "readable expiration gives the exact end")
check(MimQoLDB.argusTrackerDuration == 13, "buff length learned for later estimates")
check(s.realTimer and frame.binding.duration.kind == "aura" and frame.binding.duration.id == 77
    and frame.tag.text == "", "real duration bound, no estimate label")
cast(HOG)
aura.applications = 2
auraEvent({ updatedAuraInstanceIDs = { 77 } })
check(not api.GetState().mismatch, "stack 2 agrees with one cast")
cast(HOG)
aura.applications = 1
auraEvent({ updatedAuraInstanceIDs = { 77 } })
check(frame.count.text == "1마리", "stack back to 1 after the second cast")
aura.applications = 2
auraEvent({ updatedAuraInstanceIDs = { 77 } }) -- arrives before its cast
cast(HOG)
auraEvent({ updatedAuraInstanceIDs = { 77 } })
check(not api.GetState().mismatch, "single early update forgiven")
aura.applications = 1
auraEvent({}); auraEvent({})
check(api.GetState().mismatch and frame.count.text == "1마리 (확인 필요)", "two disagreements flagged")
aura = nil
auraEvent({ removedAuraInstanceIDs = { 77 } })
check(api.GetState().active, "a vanished buff is not final at once")
tick(0.6)
check(not api.GetState().active and api.GetState().holding, "confirmed absence ends it")
settle()

-- 4. Grace after the Tyrant cast: a readable "absent" right away is the buff not applied yet.
MimQoLDB.argusTrackerDuration = 15
cast(TYRANT)
auraEvent({})
check(api.GetState().active, "absent inside the grace window is ignored")
tick(1.1)
auraEvent({})
tick(0.6)
check(not api.GetState().active, "absent after the grace window ends it (talent not taken)")
settle()

-- 5. Codex 2: a visible buff whose time cannot be bound keeps the estimate, and still ends.
cast(TYRANT)
aura = { auraInstanceID = env.secret, applications = env.secret, duration = env.secret, expirationTime = env.secret }
auraEvent({})
check(api.GetState().source == "aura" and not api.GetState().realTimer and frame.tag.text == "(추정)",
    "secret instance ID: estimate kept")
durationMode = "unbindable"
aura = { auraInstanceID = 80, applications = 1 }
local requestsBefore = durationRequests
auraEvent({})
check(durationRequests == requestsBefore + 1 and not api.GetState().realTimer and frame.tag.text == "(추정)"
    and frame.binding.duration.kind == "local", "unbindable duration: estimate kept")
auraEvent({}); auraEvent({})
check(durationRequests == requestsBefore + 1, "a failed instance is not retried")
durationMode = "ok"
secretAuras = true
tick(14.9)
check(api.GetState().active, "still running just before the estimated end")
tick(0.15)
check(not api.GetState().active and api.GetState().holding, "estimated segment still ends on time")
settle()

-- 6. Codex 3 + 4: /reload with the buff at 2 stacks. Real event order on a fresh load.
secretAuras = false
aura = { auraInstanceID = 90, applications = 2, duration = 15, expirationTime = env.now + 9 }
load()
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", false, true)
auraEvent({ updatedAuraInstanceIDs = { 90 } })
frame = display()
s = api.GetState()
check(s.active and s.countUnknown and s.progress == 1, "restore keeps unknown past and the stack progress")
check(frame.count.text == "0마리 이상" and frame.next.text == "●○",
    "one cast to the next demon: " .. tostring(frame.next.text))
cast(HOG)
aura.applications = 1
auraEvent({ updatedAuraInstanceIDs = { 90 } })
check(api.GetState().demons == 1 and frame.count.text == "1마리 이상" and not api.GetState().mismatch,
    "next cast completes the pair")
fire("PLAYER_ENTERING_WORLD", false, false)
check(api.GetState().active and api.GetState().demons == 1, "a loading screen keeps the count")

-- 7. Codex 5: layout edits, re-applying settings and preview keep the running count.
api.ApplyLayout()
check(api.GetState().demons == 1 and api.GetState().countUnknown, "layout change keeps the count")
api.ApplySettings()
check(api.GetState().demons == 1 and api.GetState().active, "settings re-apply keeps the count")
check(api.Preview() == true and frame.count.text == "1마리 이상", "preview shows the real count, not the sample")
cast(HOG); cast(HOG)
check(api.GetState().demons == 2 and frame.count.text == "2마리 이상", "casts during preview keep counting")
-- The real settings field saves through the layout path.
SlashCmdList.MIMQOL("")
local sizeField
for _, f in ipairs(env.frames) do if f.setting == "argusTrackerSize" then sizeField = f end end
check(sizeField, "font size field exists")
sizeField:SetText("40"); sizeField.dirty = true
sizeField.scripts.OnEnterPressed(sizeField)
check(MimQoLDB.argusTrackerSize == 40 and api.GetState().demons == 2 and api.GetState().active,
    "font size edit in the settings window keeps the count")
aura = nil
auraEvent({})
settle()

-- 8. Idle preview: sample, then hides.
check(api.Preview() == true and frame:IsShown() and frame.count.text == "3마리" and frame.time.text == "2.4",
    "idle preview shows the sample")
tick(8.1)
check(not frame:IsShown(), "preview ends")

-- 9. Codex 6: moving, then the feature is switched off.
local labels = {}
check(api.SetMoving(true, function(active) labels[#labels + 1] = active end) and api.IsMoving() and frame.mouse,
    "moving starts")
frame.centerX, frame.centerY = 540, 330
frame.scripts.OnDragStop(frame)
check(MimQoLDB.argusTrackerX == 40 and MimQoLDB.argusTrackerY == -70 and labels[1] == true, "drag saved X/Y")
MimQoLDB.argusTracker = false
api.ApplySettings()
check(not api.IsMoving() and frame.mouse == false and not frame:IsShown() and labels[2] == false,
    "switching off ends moving, mouse and the window")
check(not driver.events.UNIT_SPELLCAST_SUCCEEDED and not driver.events.UNIT_AURA, "events dropped when off")
check(api.Preview() == false and api.SetMoving(true) == false, "preview and moving refused when off")
cast(TYRANT)
check(not frame:IsShown(), "nothing shown when off")
MimQoLDB.argusTracker = true
api.ApplySettings()
check(driver.events.UNIT_AURA == "player", "re-enabled")

-- 10. Death clears; leaving combat re-checks a readable buff.
secretAuras = true
cast(TYRANT); cast(HOG); cast(HOG)
fire("PLAYER_DEAD")
check(not api.GetState().active and not frame:IsShown(), "death clears")
cast(TYRANT)
secretAuras = false
aura = nil
tick(2)
fire("PLAYER_REGEN_ENABLED")
tick(0.6)
check(not api.GetState().active, "out of combat the buff reads as gone and the segment ends")
settle()

-- 11. Hold 0 hides immediately.
MimQoLDB.argusTrackerHold = 0
secretAuras = true
cast(TYRANT)
tick(15.1)
check(not frame:IsShown() and not api.GetState().holding, "hold 0 hides at once")
MimQoLDB.argusTrackerHold = 5

-- 13. Codex follow-up 1: the end follows a corrected buff length and a bound real timer.
secretAuras = true
MimQoLDB.argusTrackerDuration = 15
local started = env.now
cast(TYRANT)
check(api.GetState().endAt == started + 15, "estimated end from 15 s")
MimQoLDB.argusTrackerDuration = 13
api.ApplyLayout()
check(api.GetState().endAt == started + 13 and frame.binding.duration.seconds == 13, "edited length moves the running end and timer")
tick(13.05)
check(not api.GetState().active, "ends at the corrected time")
settle()
secretAuras = false
durationMode = "nil"
MimQoLDB.argusTrackerDuration = 15
started = env.now
cast(TYRANT)
aura = { auraInstanceID = 301, applications = 1, duration = 13, expirationTime = env.secret }
auraEvent({})
check(MimQoLDB.argusTrackerDuration == 13 and api.GetState().endAt == started + 13 and frame.tag.text == "(추정)",
    "learned length moves the running end")
aura = nil
auraEvent({})
settle()
durationMode = "ok"
MimQoLDB.argusTrackerDuration = 15
started = env.now
cast(TYRANT)
aura = { auraInstanceID = 302, applications = 1, duration = env.secret, expirationTime = env.secret }
auraEvent({})
check(api.GetState().realTimer and frame.tag.text == "", "real timer bound without a readable expiration")
tick(16)
check(api.GetState().active, "a bound real timer is not cut at the 15 s estimate")
cast(HOG); cast(HOG)
check(api.GetState().demons == 1, "casts after 15 s still count while the real buff runs")
aura = nil
auraEvent({ removedAuraInstanceIDs = { 302 } })
tick(0.6)
check(not api.GetState().active and api.GetState().holding, "removal of the bound instance ends it")
settle()

-- 14. Codex follow-up 3: a new instance rebinds the real timer.
cast(TYRANT)
aura = { auraInstanceID = 401, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
check(frame.binding.duration.id == 401, "first instance bound")
aura = { auraInstanceID = 402, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
check(frame.binding.duration.id == 402 and api.GetState().realTimer, "new instance rebound")
aura = nil
auraEvent({})
settle()

-- 15. Codex follow-up 4: a Tyrant processed after the previous end, before OnUpdate.
cast(TYRANT)
aura = { auraInstanceID = 501, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
check(api.GetState().source == "aura" and api.GetState().endPrecise, "buff-confirmed segment")
secretAuras = true
env.now = env.now + 70
cast(TYRANT)
check(api.GetState().active and api.GetState().source == "cast" and api.GetState().demons == 0, "expired segment replaced by the new Tyrant")
cast(HOG); cast(HOG)
check(api.GetState().demons == 1 and frame.count.text == "1마리", "following casts count")
tick(15.1)
settle()
-- The buff update beats the Tyrant cast event: still a fresh, known start.
secretAuras = false
aura = { auraInstanceID = 502, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
check(api.GetState().countUnknown, "a buff seen without its start is unknown at first")
cast(TYRANT)
check(not api.GetState().countUnknown and frame.count.text == "0마리", "its Tyrant right after makes the start known")
aura = nil
auraEvent({})
settle()

-- 16. Codex follow-up 2: /reload where the buff data arrives after login.
aura = nil
load()
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", false, true)
frame = display()
check(not api.GetState().active, "nothing known at login")
aura = { auraInstanceID = 310, applications = 2, duration = 15, expirationTime = env.now + 6 }
auraEvent({ addedAuras = {} })
frame = display()
check(api.GetState().countUnknown and api.GetState().progress == 1, "late buff restored with its progress")
check(frame.count.text == "0마리 이상" and frame.next.text == "●○", "late restore display: " .. tostring(frame.next.text))
aura = nil
auraEvent({})
settle()

-- 17. Codex follow-up B1: an expired segment must not absorb the next buff.
secretAuras = false
durationMode = "ok"
MimQoLDB.argusTrackerDuration = 15
cast(TYRANT)
aura = { auraInstanceID = 600, applications = 1, duration = env.secret, expirationTime = env.secret }
auraEvent({})
for _ = 1, 6 do cast(HOG) end
check(api.GetState().demons == 3, "three demons in the first Tyrant")
aura = nil
secretAuras = true -- the end is not seen
env.now = env.now + 70
secretAuras = false
aura = { auraInstanceID = 601, applications = 1, duration = env.secret, expirationTime = env.secret }
auraEvent({}) -- new buff first, then its Tyrant cast event
cast(TYRANT)
cast(HOG); cast(HOG)
check(api.GetState().demons == 1 and not api.GetState().countUnknown and frame.count.text == "1마리",
    "new Tyrant starts from zero: " .. tostring(frame.count.text))
aura = nil
auraEvent({})
settle()
-- A different instance during a running segment is a new buff.
cast(TYRANT)
aura = { auraInstanceID = 610, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
cast(HOG); cast(HOG)
tick(2)
aura = { auraInstanceID = 611, applications = 1, duration = 15, expirationTime = env.now + 15 }
auraEvent({})
check(api.GetState().demons == 1 and api.GetState().progress == 0 and not api.GetState().countUnknown,
    "instance change within the same Tyrant keeps the count")
aura = nil
auraEvent({})
settle()

-- 18. Codex follow-up B2: real timer bound, end not readable: ends at the estimate.
MimQoLDB.argusTrackerDuration = 13
cast(TYRANT)
aura = { auraInstanceID = 700, applications = 1, duration = env.secret, expirationTime = env.secret }
auraEvent({})
check(api.GetState().realTimer and api.GetState().endAt ~= nil, "real timer bound")
secretAuras = true -- restricted: no lookup, no readable removal
aura = nil
auraEvent({ removedAuraInstanceIDs = { env.secret } })
tick(13.05)
check(not api.GetState().active, "unknown end: segment ends at the estimate")
cast(HOG); cast(HOG)
check(api.GetState().demons == 0, "casts after the buff are not counted")
settle()
MimQoLDB.argusTrackerDuration = 15

-- 19. Codex follow-up C: an extension also moves the on-screen estimated timer.
secretAuras = false
durationMode = "nil" -- no real duration object: the estimate is on screen
MimQoLDB.argusTrackerDuration = 13
cast(TYRANT)
aura = { auraInstanceID = 800, applications = 1, duration = env.secret, expirationTime = env.secret }
auraEvent({})
check(not api.GetState().realTimer and frame.tag.text == "(추정)", "estimated timer on screen")
tick(13.05)
check(api.GetState().active, "same buff still visible: extended")
check(frame.manualEnd == nil and frame.binding.duration.kind == "local"
    and math.abs(frame.binding.duration.seconds - 0.5) < 0.01, "timer rebound to the extended end: " .. tostring(frame.binding.duration.seconds))
tick(0.55)
check(api.GetState().active and math.abs(frame.binding.duration.seconds - 0.5) < 0.01, "each extension rebinds")
aura = nil
tick(0.55)
check(not api.GetState().active, "ends once the buff is gone")
settle()
durationMode = "ok"
MimQoLDB.argusTrackerDuration = 15

-- 20. A Hand of Gul'dan replaced by another spell ID still counts.
local function sent(id) fire("UNIT_SPELLCAST_SENT", "player", "target", "cast-guid", id) end
secretAuras = true
MimQoLDB.argusTrackerAliases = nil
api.ApplySettings() -- tracking unchanged; aliases stay as loaded
local OVERRIDE = 1299999
C_Spell.GetBaseSpell = function(id) if id == OVERRIDE then return HOG end return id end
cast(TYRANT)
cast(HOG)
cast(OVERRIDE)
check(api.GetState().demons == 1 and api.GetState().progress == 0, "override found by its base spell completes the pair")
check(MimQoLDB.argusTrackerAliases and MimQoLDB.argusTrackerAliases[OVERRIDE] == HOG, "alias saved")
C_Spell.GetBaseSpell = nil
cast(HOG); cast(OVERRIDE)
check(api.GetState().demons == 2 and api.GetState().progress == 0, "remembered alias keeps counting")
-- Live at success time via GetOverrideSpell.
local OVERRIDE2 = 1299998
cast(HOG)
env.override = { [HOG] = OVERRIDE2 }
cast(OVERRIDE2)
env.override = nil
check(api.GetState().demons == 3 and api.GetState().progress == 0, "override live at success counts")
-- Codex: first-seen ID whose relation is gone by the success event. Learned when sent.
local OVERRIDE3 = 1299997
cast(HOG)
env.override = { [HOG] = OVERRIDE3 }
sent(OVERRIDE3)
env.override = nil
cast(OVERRIDE3)
check(api.GetState().demons == 4 and api.GetState().progress == 0, "relation learned at cast start counts even if gone at success")
-- Learned from an aura change while the replacement is live.
local OVERRIDE4 = 1299996
cast(HOG)
env.override = { [HOG] = OVERRIDE4 }
auraEvent({})
env.override = nil
cast(OVERRIDE4)
check(api.GetState().demons == 5, "relation learned on an aura change counts")
-- Learned by the periodic check while a segment runs.
local OVERRIDE5 = 1299995
cast(HOG)
env.override = { [HOG] = OVERRIDE5 }
tick(0.3)
env.override = nil
cast(OVERRIDE5)
check(api.GetState().demons == 6, "relation learned by the running check counts")
-- An unrelated spell is never counted.
cast(686)
check(api.GetState().demons == 6 and api.GetState().progress == 0, "unrelated spell ignored")
-- Codex: /reload keeps learned aliases.
tick(30)
settle()
load()
fire("PLAYER_LOGIN")
frame = display()
cast(TYRANT)
cast(HOG); cast(OVERRIDE3)
check(api.GetState().demons == 1, "aliases survive a reload")
-- Junk in the saved table is ignored.
MimQoLDB.argusTrackerAliases = { [42] = 999, x = HOG, [OVERRIDE] = HOG }
tick(30)
settle()
load()
fire("PLAYER_LOGIN")
frame = display()
cast(TYRANT)
cast(HOG); cast(42)
check(api.GetState().demons == 0 and api.GetState().progress == 1, "invalid saved alias ignored")

-- Ruination (434635) replaces Hand of Gul'dan and counts (hotfix 2026-03-18),
-- with no API help and no saved alias: a fresh install in restricted combat.
tick(30)
settle()
local RUINATION = 434635
MimQoLDB.argusTrackerAliases = nil
env.override, C_Spell.GetBaseSpell = nil, nil
load()
fire("PLAYER_LOGIN")
frame = display()
cast(TYRANT)
cast(HOG); cast(RUINATION)
check(api.GetState().demons == 1 and api.GetState().progress == 0, "Ruination completes a pair without learning")
cast(RUINATION); cast(RUINATION)
check(api.GetState().demons == 2, "Ruination pairs count")

-- Codex: the same Tyrant's buff dropped and re-added on a stack change keeps the count.
tick(30)
settle()
secretAuras = false
cast(TYRANT)
aura = { auraInstanceID = 1001, applications = 1, duration = 25, expirationTime = env.now + 25 }
auraEvent({})
cast(HOG)
aura = nil
auraEvent({ removedAuraInstanceIDs = { 1001 } }) -- removed...
tick(0.1)
aura = { auraInstanceID = 1002, applications = 2, duration = 25, expirationTime = env.now + 24 }
auraEvent({ addedAuras = {} })                    -- ...and re-added
check(api.GetState().active and api.GetState().progress == 1 and not api.GetState().countUnknown,
    "drop and re-add keeps the progress")
cast(HOG)
check(api.GetState().demons == 1 and api.GetState().progress == 0, "second Hand completes the pair: " ..
    api.GetState().demons .. "/" .. api.GetState().progress)
-- A real end rolls back a cast that landed while the absence was being confirmed.
cast(HOG)
aura = nil
auraEvent({})
tick(0.2)
cast(HOG) -- after the buff was really gone
tick(0.4)
check(not api.GetState().active and api.GetState().demons == 1, "cast after the real end is rolled back")
settle()
secretAuras = true

-- Codex: diagnostics cover arrivals outside a segment, verdicts, progress and reasons.
tick(30)
settle()
local printed = {}
local realPrint = print
print = function(text) printed[#printed + 1] = tostring(text) end
cast(686)
check(#printed == 0, "no debug output by default")
SlashCmdList.MIMQOL("argusdebug")
cast(686)
cast(TYRANT)
cast(HOG)
cast(434635)
cast(env.secret)
fire("PLAYER_DEAD")
-- Buff update first, then its Tyrant cast event: still logged.
secretAuras = false
aura = { auraInstanceID = 990, applications = 1, duration = 25, expirationTime = env.now + 25 }
auraEvent({})
cast(TYRANT)
aura = nil
auraEvent({})
secretAuras = true
print = realPrint
SlashCmdList.MIMQOL("argusdebug")
local all = table.concat(printed, " | ")
check(all:find("686", 1, true) and all:find("구간 밖", 1, true), "cast outside a segment is logged")
check(all:find("구간 시작: 폭군 시전", 1, true), "segment start reason logged")
check(all:find("굴단: 집계 (진행 0→1", 1, true), "verdict with progress before and after")
check(all:find("비밀 ID", 1, true), "secret ID logged without its value")
check(all:find("구간 초기화: 사망", 1, true), "reset reason logged")
check(all:find("434635", 1, true) and all:find("굴단: 집계", 1, true), "Ruination logged as counted")
check(all:find("버프가 먼저 도착", 1, true), "Tyrant after its buff update is logged")
settle()

-- 12. Slash toggle.
SlashCmdList.MIMQOL("argus")
check(MimQoLDB.argusTracker == false, "/mq argus toggles")
SlashCmdList.MIMQOL("argus")
check(MimQoLDB.argusTracker == true, "/mq argus toggles back")

print("argus_tracker_smoke: " .. checks .. " checks passed")
