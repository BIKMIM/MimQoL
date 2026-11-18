-- Simulates protected UI operations, not actual hardware casting/taint rules.
local checks, frames = 0, {}
local inCombat, shift, count, inGroup, raid, instance = false, false, 1, false, false, false
local active, results, known, ai, running, now = nil, {}, true, false, false, 0
local secret = {}
local function check(value, message) checks = checks + 1; assert(value, message) end
local function guard(frame) assert(not inCombat or not frame.protected, "protected operation in combat") end
local Frame = {}
Frame.__index = function(_, key)
    if Frame[key] then return Frame[key] end
    if key:match("^Set") or key:match("^RegisterFor") or key == "Clear" then
        return function(self) guard(self) end
    end
end
function CreateFrame(kind, name, parent, template)
    local protected = (template and template:find("Secure", 1, true)) or (parent and parent.protected)
    assert(not inCombat or not protected, "secure creation in combat")
    local frame = setmetatable({ kind = kind, template = template or "", protected = protected,
        scripts = {}, events = {}, attributes = {}, shown = true, parent = parent }, Frame)
    frames[#frames + 1] = frame
    return frame
end
function Frame:SetScript(event, callback)
    guard(self)
    assert(event ~= "OnClick" or not self.template:find("SecureAction", 1, true), "secure click overwritten")
    self.scripts[event] = callback
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:SetAttribute(key, value) guard(self); self.attributes[key] = value end
function Frame:SetText(text) self.text = text end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:Show() guard(self); self.shown = true end
function Frame:Hide() guard(self); self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:ClearAllPoints() guard(self); self.point = nil end
function Frame:SetPoint(...) guard(self); self.point = { ... } end
function Frame:EnableMouse(value) guard(self); self.mouse = value end
function Frame:StartMoving() guard(self); self.dragging = true end
function Frame:StopMovingOrSizing() self.dragging = nil end
function Frame:GetCenter() return self.cx, self.cy end
function Frame:GetTop() return self.top end
function Frame:GetWidth() return self.width end
function RegisterStateDriver(frame, state, condition)
    guard(frame)
    check(state == "visibility" and condition == "[combat] hide; show", "secure combat-only visibility")
    frame.visibility = condition
    frame.shown = not inCombat
end
function UnregisterStateDriver(frame) guard(frame); frame.visibility = nil end
local function secureVisibility()
    for _, frame in ipairs(frames) do
        if frame.visibility then frame.shown = not inCombat end
    end
end
UIParent = CreateFrame("Frame")
UIParent.width, UIParent.top = 1920, 1080
function InCombatLockdown() return inCombat end
function IsShiftKeyDown() return shift end
function IsInGroup(category) if category == 2 then return false end; return inGroup end
function IsInRaid() return raid end
function IsInInstance() return instance end
function GetNumGroupMembers() return count end
function UnitInPartyIsAI() return ai end
function IsPlayerSpell() return known end
function issecretvalue(value) return value == secret end
function GetTime() return now end
local activities = {
    [1] = { isMythicPlusActivity = true, fullName = "하늘탑 (쐐기돌)" },
    [2] = { isMythicPlusActivity = false, fullName = "하늘탑 (일반)" },
    [3] = { isMythicPlusActivity = true, fullName = "Ruby Life Pools (Mythic Keystone)" },
    [4] = { isMythicPlusActivity = true, fullName = "지원하지 않는 던전" },
}
C_LFGList = {
    GetActiveEntryInfo = function() return active end,
    GetActivityInfoTable = function(id) return activities[id] end,
    GetSearchResultInfo = function(id) return results[id] end,
}
C_ChallengeMode = { IsChallengeModeActive = function() return running end }
C_Spell = { GetSpellInfo = function() return { iconID = 123 } end,
    GetSpellCooldownDuration = function() return secret end }
MimQoLDB = { dungeonPortal = true, autoGreet = false }
assert(loadfile("DungeonPortal.lua"))()
local driver = frames[2]
local function event(name, ...)
    if driver.events[name] then driver.scripts.OnEvent(driver, name, ...) end
end
local function portal()
    for _, frame in ipairs(frames) do
        if frame.template:find("SecureActionButtonTemplate", 1, true) then return frame end
    end
end
event("PLAYER_LOGIN")
check(not portal(), "solo never creates portal")
inGroup, count, active = true, 4, { activityIDs = { 1 } }
event("GROUP_ROSTER_UPDATE")
check(not portal(), "four members do not prompt")
count = 5
event("GROUP_ROSTER_UPDATE")
local p = assert(portal())
check(p:IsShown() and p.attributes.type1 == "spell" and p.attributes.spell1 == 159898,
    "leader gets learned portal at five independently of automatic greetings")
active = nil
event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(p:IsShown(), "delisting retains confirmed destination")
p.close.scripts.OnClick()
event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "closing survives repeated roster events")
count = 4; event("GROUP_ROSTER_UPDATE")
count = 5; event("GROUP_ROSTER_UPDATE")
check(p:IsShown(), "new full-party transition can prompt again")
shift = true; secureVisibility()
check(p:IsShown() and not driver.events.MODIFIER_STATE_CHANGED, "shift no longer hides portal")
shift = false; secureVisibility()
check(p.point and p.point[1] == "TOP" and p.point[4] == 0 and p.point[5] == -180, "default position")
inCombat = true; secureVisibility()
check(not p:IsShown(), "combat securely hides existing button")
count = 4; event("GROUP_ROSTER_UPDATE")
MimQoLDB.dungeonPortal = false; MimQoLDungeonPortal.ApplySettings()
check(not driver.events.GROUP_ROSTER_UPDATE, "disabled stops tracking")
inCombat = false; secureVisibility(); event("PLAYER_REGEN_ENABLED")
check(not p:IsShown() and p.attributes.type1 == nil, "disable in combat clears action after combat")
MimQoLDB.dungeonPortal = true; MimQoLDungeonPortal.ApplySettings()
active, count = { activityIDs = { 1 } }, 5
inCombat = true; event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "new full party during combat waits")
inCombat = false; event("PLAYER_REGEN_ENABLED")
check(p:IsShown(), "valid party shown after combat")
inCombat = true; secureVisibility()
active, count, inGroup = nil, 0, false; event("GROUP_LEFT", 1)
inCombat = false; secureVisibility(); event("PLAYER_REGEN_ENABLED")
check(not p:IsShown(), "leaving in combat cancels pending destination")

results[11] = { activityIDs = { 3 } }
event("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "applied")
results[11] = nil
event("LFG_LIST_JOINED_GROUP", 11)
check(not p:IsShown(), "join waits for roster")
inGroup, count = true, 5; event("GROUP_ROSTER_UPDATE")
check(p:IsShown() and p.attributes.spell1 == 393256, "member uses accepted listing cache after result vanishes")
known = false; event("SPELLS_CHANGED")
check(p:IsShown() and p.attributes.type1 == nil and p.hint.text:find("배우지", 1, true), "unlearned portal is informational")
known = true; event("SPELLS_CHANGED")
event("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast", 393256)
check(p:IsShown(), "other player's cast does not dismiss")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 393256)
check(not p:IsShown(), "successful player teleport dismisses")
count = 4; event("GROUP_ROSTER_UPDATE"); count = 5; event("GROUP_ROSTER_UPDATE")
instance = true; event("PLAYER_ENTERING_WORLD")
check(not p:IsShown(), "instance entry hides")
instance = false; event("PLAYER_ENTERING_WORLD")
raid = true; event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "raid never prompts")
raid, ai = false, true; event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "AI group never prompts")
ai = false
results[11] = { activityIDs = { 3 } }
active = { activityIDs = { 2 }, name = "하늘탑 쐐기" }; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "normal dungeon and player-written title cannot enable portal")
active = nil; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "removed replacement listing cannot revive original joined destination")
results[11] = nil
active = { activityIDs = { 1, 3 } }; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "ambiguous destinations suppressed")
active = { activityIDs = { 4 } }; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "unknown dungeon suppressed")
active = secret; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "secret listing ignored")
active = { activityIDs = { 1 } }; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
active = { activityIDs = { 5 } }; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(not p:IsShown(), "changed listing with delayed activity data hides old destination")
activities[5] = activities[3]; event("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check(p:IsShown() and p.attributes.spell1 == 393256, "late activity data resolves new destination")
count = secret; event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "secret member count suppressed")
count = 5; event("GROUP_ROSTER_UPDATE")
MimQoLDungeonPortal.Preview()
check(not p:IsShown(), "preview hides real action")
local sample
for _, frame in ipairs(frames) do
    if frame.title and frame ~= p then sample = frame end
end
check(sample and sample:IsShown() and sample.attributes.type1 == nil and not sample.protected,
    "preview cannot cast")
MimQoLDungeonPortal.Preview()
check(not sample:IsShown() and p:IsShown(), "preview toggle restores eligible portal")
local movingState
check(MimQoLDungeonPortal.SetMoving(true, function(value) movingState = value end), "move mode starts")
check(sample:IsShown() and sample.mouse and not p:IsShown(), "move mode shows draggable preview only")
sample.scripts.OnDragStart(sample)
check(sample.dragging, "move mode drags preview")
sample.cx, sample.top = 1060, 900
sample.scripts.OnDragStop(sample)
check(MimQoLDB.dungeonPortalX == 100 and MimQoLDB.dungeonPortalY == -180 and movingState == true,
    "drag saves top-relative position")
inCombat = true
MimQoLDungeonPortal.StopMoving()
check(not MimQoLDungeonPortal.IsMoving() and movingState == false and not sample:IsShown(),
    "closing move mode in combat only hides insecure preview")
inCombat = false; secureVisibility(); event("PLAYER_REGEN_ENABLED")
check(p:IsShown() and p.point[4] == 100 and p.point[5] == -180, "real button uses saved position after combat")
inCombat = true
check(not MimQoLDungeonPortal.SetMoving(true) and not sample:IsShown(), "move mode refused in combat")
inCombat = false
MimQoLDungeonPortal.SetMoving(true)
sample.scripts.OnDragStart(sample)
MimQoLDungeonPortal.Preview()
check(not MimQoLDungeonPortal.IsMoving() and not sample.dragging and p:IsShown(), "preview toggle ends move mode")
MimQoLDB.dungeonPortalX, MimQoLDB.dungeonPortalY = nil, nil
MimQoLDungeonPortal.ApplySettings()
check(p.point[4] == 0 and p.point[5] == -180, "missing saved position falls back to default")
running, active = true, nil; event("CHALLENGE_MODE_START")
check(not p:IsShown(), "challenge start clears destination")
running = false; event("CHALLENGE_MODE_COMPLETED")
event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "completed run does not resurrect old destination")

-- Confirm a changed application cannot resurrect a previously valid portal.
inGroup, count = false, 0; event("GROUP_LEFT", 1)
results[12] = { activityIDs = { 1 } }; event("LFG_LIST_APPLICATION_STATUS_UPDATED", 12, "applied")
results[12] = { activityIDs = { 2 } }; event("LFG_LIST_SEARCH_RESULT_UPDATED", 12)
results[12] = nil; event("LFG_LIST_JOINED_GROUP", 12)
inGroup, count = true, 5; event("GROUP_ROSTER_UPDATE")
check(not p:IsShown(), "confirmed non-mythic application replaces cached destination")
print("dungeon_portal_smoke: " .. checks .. " checks passed")
