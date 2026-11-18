-- Native API boundaries are simulated; this cannot prove Retail taint behavior.
local env = { frames = {}, now = 100, sounds = {}, spells = {}, items = {}, inventory = {}, known = {} }
local unpackValues = unpack or table.unpack
local function noop() end
local function forbidden() error("restricted value used by Lua") end
env.secret = setmetatable({}, { __add = forbidden, __sub = forbidden, __lt = forbidden,
    __le = forbidden, __mul = forbidden, __div = forbidden, __tostring = forbidden })
function issecretvalue(value) return rawequal(value, env.secret) end
function issecrettable() return false end
local Frame = {}
Frame.__index = function(_, key)
    if Frame[key] then return Frame[key] end
    if key:match("^Set") or key:match("^Enable") or key:match("^Register")
        or key:match("^Clear") or key:match("^Update") then return noop end
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, scripts = {},
        events = {}, shown = true, text = "", alpha = 1 }, Frame)
    env.frames[#env.frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:HookScript(name, callback)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end; callback(...) end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetText(value)
    self.text = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Frame:SetFormattedText(format, value)
    self.formattedValue = value
    self.text = issecretvalue(value) and value or string.format(format, value)
end
function Frame:GetText() return self.text end
function Frame:SetAlpha(value) self.alpha = value end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetTexture(value) self.texture = value end
function Frame:SetValue(value) self.value = value end
function Frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function Frame:SetFocus() self.focus = true end
function Frame:HasFocus() return self.focus == true end
function Frame:ClearFocus()
    local previous = self.focus
    self.focus = false
    if previous and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function Frame:HighlightText() end
function Frame:GetStringHeight() return 28 end
function Frame:GetFrameLevel() return 1 end
function Frame:GetVerticalScrollRange() return 1000 end
function Frame:GetVerticalScroll() return 0 end
function Frame:SetFont(font, size, flags)
    self.fontFile = font
    self.fontSize = size
    self.fontFlags = flags
end
function Frame:GetFont() return self.fontFile or "Fonts\\2002.TTF", self.fontSize or 14, self.fontFlags or "" end
function Frame:GetCenter() return self.centerX or 500, self.centerY or 400 end
function Frame:GetTop() return self.top or 0 end
function Frame:SetScale(value) self.scale = value end
function Frame:GetScale() return self.scale or 1 end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:EnableMouse(value) self.mouse = value end
function Frame:SetHitRectInsets(...) self.hitInsets = { ... } end
function Frame:StartMoving() self.dragging = true end
function Frame:StopMovingOrSizing() self.dragging = false end
function Frame:SetChecked(value) self.checked = value end
function Frame:GetChecked() return self.checked end
function Frame:IsEnabled() return true end
function Frame:IsShown() return self.shown end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:GetFontString() return self:CreateFontString() end
function Frame:GetHighlightTexture() return self:CreateTexture() end
function Frame:GetCheckedTexture() return self:CreateTexture() end
function Frame:GetThumbTexture() return self:CreateTexture() end
UIParent = CreateFrame("Frame")
StaticPopupDialogs, SlashCmdList, UISpecialFrames = {}, {}, {}
function StaticPopup_Show(name, _, _, callback) StaticPopupDialogs[name].OnAccept(nil, callback) end
function UnitClass() return "사냥꾼", "HUNTER" end
function InCombatLockdown() return env.combat == true end
function IsShiftKeyDown() return env.shift == true end
function UnitIsDeadOrGhost() return env.dead == true end
function GetTime() return env.now end
function GetCVar() return env.muted and "0" or "1" end
function GetCursorInfo() return unpackValues(env.cursor or {}) end
function ClearCursor() env.cleared = (env.cleared or 0) + 1; env.cursor = nil end
function GetInventoryItemID(_, slot) return env.inventory[slot] end
local function sound(kind, id, channel)
    env.sounds[#env.sounds + 1] = { kind, id, channel }
    return not env.soundMatch or env.soundMatch == id
end
function PlaySoundFile(id, channel) return sound("file", id, channel) end
function PlaySound(id, channel) return sound("kit", id, channel) end
Enum = { LuaCurveType = { Step = 2 } }
C_CurveUtil = { CreateCurve = function()
    return { SetType = noop, points = {}, AddPoint = function(self, x, y)
        self.points[#self.points + 1] = { x, y }
    end }
end }
local function duration(id, idle)
    local state = env.spells[id]
    if not state then return nil end
    local function remaining() return idle and 0 or state.remaining end
    return {
        GetRemainingDuration = function() return state.secret and env.secret or remaining() end,
        EvaluateRemainingDuration = function(_, curve)
            if state.secret then return env.secret end
            local result = 0
            for _, point in ipairs(curve.points) do if remaining() >= point[1] then result = point[2] end end
            return result
        end,
    }
end
C_SpellBook = { IsSpellKnown = function(id) return env.known[id] == true end }
C_Spell = {
    GetSpellInfo = function(id) if id ~= 999 then return { name = "스킬" .. id, iconID = id } end end,
    IsSpellPassive = function(id) return id == 998 end,
    GetOverrideSpell = function(id) return env.override and env.override[id] or id end,
    GetSpellCharges = function(id)
        local s = env.spells[id]
        if not s or not s.charges then return nil end
        -- charges == 1: an ordinary cooldown reported as an idle one-charge table.
        local single = s.charges == 1
        return { isActive = not single and s.active, currentCharges = env.secret, maxCharges = single and 1 or 2 }
    end,
    GetSpellCooldown = function(id)
        local s = env.spells[id]
        if not s then return nil end
        return { isActive = s.active, isOnGCD = s.gcd,
            isEnabled = s.enabled ~= false, startTime = env.secret, duration = env.secret }
    end,
    GetSpellCastCount = function(id) return env.castCounts and env.castCounts[id] or 0 end,
    GetSpellChargeDuration = function(id)
        local s = env.spells[id]
        if s and s.charges then return duration(id, s.charges == 1) end
    end,
    GetSpellCooldownDuration = function(id, ignoreGCD)
        assert(ignoreGCD == true, "duration display must exclude GCD")
        if env.spells[id] and env.spells[id].gcd then return nil end
        return duration(id)
    end,
}
C_Item = {
    GetItemNameByID = function(id) return "장신구" .. id end,
    GetItemIconByID = function(id) return id end,
    DoesItemExistByID = function(id) return id ~= 999 end,
    GetItemInfoInstant = function(id) return id, "", "", id == 998 and "INVTYPE_HEAD" or "INVTYPE_TRINKET" end,
    RequestLoadItemDataByID = function(id) env.requestedItem = id end,
    GetItemCooldown = function(id)
        local s = env.items[id]
        if not s then return 0, 0, true end
        if s.secret then return env.secret, env.secret, true end
        return s.start, s.duration, s.enabled ~= false
    end,
}
function env.event(event)
    local snapshot = {}
    for _, frame in ipairs(env.frames) do snapshot[#snapshot + 1] = frame end
    for _, frame in ipairs(snapshot) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event) end
    end
end
function env.tick(delta)
    env.now = env.now + (delta or 0.2)
    for _, frame in ipairs(env.frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, delta or 0.2) end
    end
end
function env.card(index)
    local count = 0
    for _, frame in ipairs(env.frames) do
        if frame.normalText then count = count + 1; if count == (index or 1) then return frame end end
    end
end
function env.pulse()
    for _, frame in ipairs(env.frames) do
        if frame.peak and frame:IsShown() then return frame end
    end
end
function env.spell(id, remaining, restricted, charges)
    env.known[id] = true
    env.spells[id] = { remaining = remaining, active = remaining > 0, secret = restricted, charges = charges, gcd = false }
    return env.spells[id]
end
MimQoLDB = { cooldownReminder = false, cooldownReminderSeconds = 7.5,
    cooldownReminderSoundFile = "kept.mp3", autoRepair = false }
assert(loadfile("MimQoL.lua"))("MimQoL")
SlashCmdList.MIMQOL("cd") -- Initialize the actual DEFAULTS before the module is loaded.
assert(loadfile("CooldownReminder.lua"))()
env.api = MimQoLCooldownReminder
function env.reset(saved)
    MimQoLDB.cooldownReminder = false
    env.api.ApplySettings()
    env.now = env.now + 10
    env.sounds, env.spells, env.known, env.items, env.inventory = {}, {}, {}, {}, {}
    env.shift, env.dead, env.combat, env.muted, env.soundMatch, env.override = false, false, false, false, nil, nil
    env.castCounts = nil
    MimQoLDB.cooldownReminder = true
    MimQoLDB.cooldownReminderEntries = saved or "spell:101"
    MimQoLDB.cooldownReminderTiming = "soon"
    MimQoLDB.cooldownReminderSeconds = 5
    MimQoLDB.cooldownReminderSoundEnabled = true
    MimQoLDB.cooldownReminderIconEnabled = true
    MimQoLDB.cooldownReminderTextEnabled = true
    MimQoLDB.cooldownReminderCombatOnly = false
    MimQoLDB.cooldownReminderSoundType = "preset"
    MimQoLDB.cooldownReminderPulse = true
    MimQoLDB.cooldownReminderPositions = ""
end
return env
