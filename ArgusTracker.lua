--------------------------------------------------------------------------------
-- MimQoL - Demonology: Argus portal tracker
-- Counts the demons pulled from the portal during Summon Demonic Tyrant.
-- 아르거스의 지배자 (1276166) starts at 1 stack; every Hand of Gul'dan
-- toggles it 1 -> 2 -> 1 and the return to 1 opens the portal.
--
-- Hand of Gul'dan casts (UNIT_SPELLCAST_SUCCEEDED, whose spell ID is never
-- secret) are the only counting source: every second cast is one demon.
--
-- In instanced combat this buff is secret: the by-spell lookup returns
-- nothing and the instance ID itself is secret, so "no result" there means
-- "unknown", never "gone". The segment then starts at the Tyrant cast and
-- its end is estimated from the buff length (learned whenever the buff is
-- readable, or set by the user). The time is labelled as an estimate until
-- a real duration object is actually bound to the text.
--------------------------------------------------------------------------------

local ARGUS_BUFF = 1276166
local HAND_OF_GULDAN = 105174
-- Confirmed replacements counted without having to learn them first.
-- Ruination (434635, Diabolist) replaces Hand of Gul'dan while the Pit Lord is
-- out; hotfix 2026-03-18: "Fixed an issue where Ruination would not count
-- towards Dominion of Argus."
local KNOWN_ALIASES = { [434635] = 105174 }
-- A buff that reads as absent must stay absent this long before the count
-- ends: a stack change may drop and re-add the buff (new instance) at once.
local ABSENT_CONFIRM = 0.5
local DEMONIC_TYRANT = 265187
local DEMONOLOGY = 266
-- After the Tyrant cast the buff may arrive a moment later; a readable
-- "absent" inside this window does not end the segment.
local START_GRACE = 1
local PREVIEW_SECONDS = 8
-- Past the estimated end, a still-visible same buff extends it this much at a time.
local EXTEND_STEP = 0.5
local SAMPLE = { progress = 1, demons = 3, sample = true }

local driver = CreateFrame("Frame")
local frame, moving, onMoving, tracking, preview, lastTyrantAt, debugCasts, lastLearn
local aliases = {}
-- How long a completed pair shows as ●● before the dots reset.
local FLASH_SECONDS = 0.6
local state = {}
local segments = 0

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function readable(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or isSecret(value) then return nil end
    if type(value) == "table" and type(issecrettable) == "function" and issecrettable(value) then return nil end
    return value
end

-- A plain field of an aura table; nil when the field is restricted.
local function field(data, key)
    local ok, value = pcall(function() return data[key] end)
    if not ok or isSecret(value) then return nil end
    return value
end

local function setting(key, fallback)
    local value = type(MimQoLDB) == "table" and MimQoLDB[key]
    if value == nil then return fallback end
    return value
end

local function enabled()
    return setting("argusTracker", true) == true
end

local function buffLength()
    local value = tonumber(setting("argusTrackerDuration", 25)) or 25
    return math.max(3, math.min(60, value))
end

local function isDemonology()
    local api = C_SpecializationInfo or {}
    local index = readable(api.GetSpecialization or GetSpecialization)
    if type(index) ~= "number" or index < 1 then return false end
    local specID = readable(api.GetSpecializationInfo or GetSpecializationInfo, index)
    return specID == DEMONOLOGY
end

local function now()
    return GetTime()
end

local function spellName(spellID)
    local api = C_Spell or {}
    local name = readable(api.GetSpellName, spellID)
    if type(name) ~= "string" then
        local info = readable(api.GetSpellInfo, spellID)
        name = type(info) == "table" and field(info, "name") or nil
    end
    return type(name) == "string" and name or "?"
end

-- Diagnostics (/mq argusdebug, session only). Only plain values are formatted.
local function log(format, ...)
    if not debugCasts then return end
    print("|cffffd100[MimQoL 아르거스]|r " .. string.format(format, ...))
end

-- Spell IDs that stand in for Hand of Gul'dan or the Tyrant (overrides).
-- Learned while the replacement is live (cast sent/started, aura or spell
-- changes) and kept in SavedVariables so a /reload does not forget them.
local function loadAliases()
    aliases = {}
    for id, base in pairs(KNOWN_ALIASES) do aliases[id] = base end
    local saved = type(MimQoLDB) == "table" and MimQoLDB.argusTrackerAliases
    if type(saved) ~= "table" then return end
    for id, base in pairs(saved) do
        if type(id) == "number" and (base == HAND_OF_GULDAN or base == DEMONIC_TYRANT) then
            aliases[id] = base
        end
    end
end

local function rememberAlias(spellID, base, how)
    if type(spellID) ~= "number" or spellID == base or aliases[spellID] == base then return end
    aliases[spellID] = base
    if type(MimQoLDB) == "table" then
        if type(MimQoLDB.argusTrackerAliases) ~= "table" then MimQoLDB.argusTrackerAliases = {} end
        MimQoLDB.argusTrackerAliases[spellID] = base
    end
    log("대체 주문 기억: %d %s = %s (%s)", spellID, spellName(spellID),
        base == HAND_OF_GULDAN and "굴단의 손" or "악마폭군", how)
end

-- What currently replaces each base spell, read while the replacement is live.
local function learnOverrides(how)
    local api = C_Spell or {}
    for _, base in ipairs({ HAND_OF_GULDAN, DEMONIC_TYRANT }) do
        local override = readable(api.GetOverrideSpell, base)
        if type(override) == "number" and override ~= base then rememberAlias(override, base, how) end
    end
end

--------------------------------------------------------------------------------
-- Aura access
--------------------------------------------------------------------------------

-- True unless the client says plainly that this buff is readable now.
local function restricted()
    if type(C_Secrets) ~= "table" then return false end
    local checks = { { C_Secrets.ShouldSpellAuraBeSecret, ARGUS_BUFF }, { C_Secrets.ShouldAurasBeSecret } }
    for _, check in ipairs(checks) do
        if type(check[1]) == "function" then
            local ok, value = pcall(check[1], check[2])
            if not ok or isSecret(value) or value ~= false then return true end
        end
    end
    return false
end

-- table = present, false = confirmed absent, nil = unknown (restricted).
local function readAura()
    if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return nil end
    local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, ARGUS_BUFF)
    if not ok or isSecret(data) then return nil end
    if type(data) == "table" then return data end
    if data == nil and not restricted() then return false end
    return nil
end

-- The raw instance ID (possibly secret) and, when readable, its plain value.
local function instanceOf(aura)
    local ok, value = pcall(function() return aura.auraInstanceID end)
    if not ok or value == nil then return nil, nil end
    if isSecret(value) then return value, nil end
    return value, value
end

-- Only ever handed to the text binding. Id-keyed calls may error under
-- restrictions, so a failure simply leaves the estimate in place.
local function auraDuration(instanceID)
    if instanceID == nil or not (C_UnitAuras and type(C_UnitAuras.GetAuraDuration) == "function") then return nil end
    local ok, object = pcall(C_UnitAuras.GetAuraDuration, "player", instanceID)
    if ok and object ~= nil then return object end
    return nil
end

local function removedHas(updateInfo, instanceID)
    if instanceID == nil or type(updateInfo) ~= "table" then return false end
    local list = field(updateInfo, "removedAuraInstanceIDs")
    if type(list) ~= "table" then return false end
    for _, id in ipairs(list) do
        if not isSecret(id) and id == instanceID then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Display
--------------------------------------------------------------------------------

local function buildFormatter()
    if not (C_StringUtil and type(C_StringUtil.CreateNumericRuleFormatter) == "function"
        and Enum and Enum.NumericRuleFormatRounding) then return nil end
    local rounding = Enum.NumericRuleFormatRounding
    if not rounding.Nearest then return nil end
    local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not ok or not formatter then return nil end
    if not pcall(formatter.SetBreakpoints, formatter,
        { { threshold = 0, format = "%.1f", rounding = rounding.Nearest } }) then return nil end
    return formatter
end

-- Engine-side text: the duration object is handed over once and the engine
-- redraws the text and its colour; Lua never reads the remaining time.
local function buildBinding(fontString)
    if not (C_DurationUtil and type(C_DurationUtil.CreateDurationTextBinding) == "function") then return nil end
    local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
    if not ok or not binding then return nil end
    if not pcall(binding.SetFontString, binding, fontString) then return nil end
    local formatter = buildFormatter()
    if formatter then pcall(binding.SetFormatter, binding, formatter) end
    if C_CurveUtil and type(C_CurveUtil.CreateColorCurve) == "function" and type(CreateColor) == "function"
        and Enum and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration then
        local okCurve, curve = pcall(C_CurveUtil.CreateColorCurve)
        if okCurve and curve then
            pcall(curve.SetType, curve, Enum.LuaCurveType and Enum.LuaCurveType.Step or 2)
            -- Under 1.5 s the time turns red: squeezing one more cast in is doubtful.
            pcall(curve.AddPoint, curve, 0, CreateColor(1, 0.3, 0.3, 1))
            pcall(curve.AddPoint, curve, 1.5, CreateColor(1, 1, 1, 1))
            pcall(binding.SetTextColorCurve, binding, curve, Enum.DurationTextBindingProperty.RemainingDuration)
        end
    end
    return binding
end

local function placeFrame()
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
        tonumber(setting("argusTrackerX", 0)) or 0, tonumber(setting("argusTrackerY", 120)) or 120)
end

local function applyFont()
    if not frame then return end
    local size = tonumber(setting("argusTrackerSize", 32)) or 32
    size = math.max(12, math.min(96, size))
    local font = frame.count:GetFont()
    if font then
        frame.count:SetFont(font, size, "OUTLINE")
        frame.next:SetFont(font, math.max(12, math.floor(size * 0.7 + 0.5)), "OUTLINE")
        frame.time:SetFont(font, math.max(12, math.floor(size * 0.7 + 0.5)), "OUTLINE")
        frame.tag:SetFont(font, math.max(10, math.floor(size * 0.4 + 0.5)), "OUTLINE")
    end
    frame:SetSize(math.max(220, size * 8), size * 2.4)
end

local function createFrame()
    if frame then return end
    frame = CreateFrame("Frame", nil, UIParent)
    -- Below windows such as the map and bags; above the world only.
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.count:SetPoint("TOP", 0, 0)
    frame.count:SetTextColor(0.75, 0.45, 1)
    -- Second row: progress dots right of centre-left, remaining time after them.
    frame.next = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.time = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.time:SetPoint("TOPLEFT", frame.count, "BOTTOM", 6, -2)
    frame.next:SetPoint("RIGHT", frame.time, "LEFT", -12, 0)
    frame.time:SetTextColor(1, 1, 1)
    frame.tag = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.tag:SetPoint("LEFT", frame.time, "RIGHT", 4, 0)
    frame.tag:SetTextColor(0.7, 0.7, 0.7)
    for _, text in ipairs({ frame.count, frame.next, frame.time, frame.tag }) do
        text:SetShadowColor(0, 0, 0, 0.9)
        text:SetShadowOffset(2, -2)
    end
    frame.binding = buildBinding(frame.time)
    frame:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not moving then return end
        local x, y = self:GetCenter()
        local px, py = UIParent:GetCenter()
        if x and y and px and py then
            MimQoLDB.argusTrackerX = math.floor(x - px + 0.5)
            MimQoLDB.argusTrackerY = math.floor(y - py + 0.5)
        end
        placeFrame()
        if onMoving then onMoving(true) end
    end)
    frame:Hide()
    applyFont()
    placeFrame()
end

local function bindingEnabled(value)
    if frame and frame.binding then pcall(frame.binding.SetEnabled, frame.binding, value) end
end

local function localDurationUntil(endAt)
    if not (C_DurationUtil and type(C_DurationUtil.CreateDuration) == "function") then return nil end
    local ok, object = pcall(C_DurationUtil.CreateDuration)
    if not ok or not object then return nil end
    if not pcall(object.SetTimeFromStart, object, now(), math.max(0, endAt - now())) then return nil end
    return object
end

-- Binds one timer source to the time text; the key avoids rebinding the same
-- source on every redraw. Returns whether the source was actually bound.
local function setTimer(key, object, localEnd, staticText)
    if frame.timerKey == key then return frame.timerBound end
    frame.timerKey, frame.manualEnd, frame.timerBound = key, nil, false
    if object and frame.binding and pcall(frame.binding.SetDuration, frame.binding, object) then
        bindingEnabled(true)
        frame.timerBound = true
        return true
    end
    bindingEnabled(false)
    if localEnd then
        -- Plain local number only (never a secret): Lua countdown fallback.
        frame.manualEnd = localEnd
        frame.time:SetFormattedText("%.1f", math.max(0, localEnd - now()))
        frame.timerBound = true
    else
        frame.time:SetText(staticText or "")
    end
    return frame.timerBound
end

local onUpdate

local function current()
    if state.active or state.holdUntil then return state end
    if preview or moving then return SAMPLE end
    return nil
end

local function render()
    local shown = current()
    if not shown then
        if frame then
            setTimer(nil)
            frame:Hide()
        end
        driver:SetScript("OnUpdate", nil)
        return
    end
    createFrame()
    local suffix = shown.countUnknown and " 이상" or ""
    if shown.mismatch then suffix = suffix .. " (확인 필요)" end
    frame.tag:SetText("")
    if shown.holdUntil then
        frame.count:SetFormattedText("이번 폭군 %d마리%s", shown.demons, suffix)
        frame.next:SetText("")
        setTimer(nil)
    else
        frame.count:SetFormattedText("%d마리%s", shown.demons, suffix)
        -- ○○: two more Hand of Gul'dan casts; ●○ (green): the next one
        -- summons; ●● (gold) briefly: a demon was just summoned.
        if shown.flashUntil and now() < shown.flashUntil then
            frame.next:SetText("●●")
            frame.next:SetTextColor(1, 0.82, 0.2)
        elseif shown.progress >= 1 then
            frame.next:SetText("●○")
            frame.next:SetTextColor(0.35, 1, 0.35)
        else
            frame.next:SetText("○○")
            frame.next:SetTextColor(0.85, 0.85, 0.85)
        end
        local bound = false
        if shown.sample then
            setTimer("sample", nil, nil, "2.4")
            bound = true
        elseif shown.realObject then
            -- Only a duration object that actually binds replaces the estimate.
            bound = setTimer("real" .. shown.id .. ":" .. (shown.realSerial or 0), shown.realObject)
            if not bound then shown.realObject, shown.realFailed = nil, true end
        end
        shown.realBound = bound and not shown.sample
        if not bound then
            if shown.endAt then
                setTimer("local" .. shown.id .. ":" .. shown.endAt, localDurationUntil(shown.endAt), shown.endAt)
                if not shown.endPrecise then frame.tag:SetText("(추정)") end
            else
                setTimer(nil)
            end
        end
    end
    frame:Show()
    driver:SetScript("OnUpdate", onUpdate)
end

--------------------------------------------------------------------------------
-- Tracking
--------------------------------------------------------------------------------

local function learnLength(seconds)
    if type(seconds) ~= "number" or seconds < 3 or seconds > 60 then return end
    MimQoLDB.argusTrackerDuration = math.floor(seconds * 10 + 0.5) / 10
end

local function startSegment(source)
    segments = segments + 1
    state = { active = true, id = segments, source = source, startedAt = now(),
        progress = 0, demons = 0, endAt = now() + buffLength(), endPrecise = false }
    log("구간 시작: %s", source == "cast" and "폭군 시전" or "버프 발견")
end

local function endSegment(reason)
    if not state.active then return end
    log("구간 종료: %s (%d마리)", reason or "?", state.demons or 0)
    state.absentSince, state.absentSnapshot, state.absentReason = nil, nil, nil
    local hold = tonumber(setting("argusTrackerHold", 5)) or 5
    if hold <= 0 then
        state = {}
    else
        state.active = false
        state.holdUntil = now() + hold
    end
    render()
end

local function reset(reason)
    if state.active then log("구간 초기화: %s (%d마리)", reason or "?", state.demons or 0) end
    state = {}
    render()
end

-- Without a readable expiration the end is derived, never stored once: a
-- corrected buff length moves it, and so does a confirmed extension.
local function settleEnd()
    if not state.active or state.endPrecise then return end
    state.endAt = math.max(state.startedAt + buffLength(), state.extendedUntil or 0)
end

-- The same buff instance is still readable on the player right now.
local function sameBuffVisible()
    if state.instanceID == nil then return false end
    local aura = readAura()
    if type(aura) ~= "table" then return false end
    local _, plain = instanceOf(aura)
    return plain == state.instanceID
end

-- Ends a segment whose end has passed. An estimated end is only pushed back
-- while the very same buff is still seen; unknown means it ends on time.
local function expireIfDue()
    if not (state.active and state.endAt and now() >= state.endAt) then return end
    if not state.endPrecise and sameBuffVisible() then
        state.extendedUntil = now() + EXTEND_STEP
        settleEnd()
        -- The estimated timer is keyed by its end time: redraw to follow it.
        render()
        return
    end
    endSegment(state.endPrecise and "버프 만료 시각" or "추정 종료 시각")
end

local function refresh()
    render()
    local before = state.endAt
    settleEnd()
    if state.endAt ~= before then render() end
    expireIfDue()
end

-- A readable buff: exact end, learned length, real timer and stack check.
local function confirmAura(aura)
    state.source = "aura"
    local expires, length = field(aura, "expirationTime"), field(aura, "duration")
    if type(expires) == "number" and expires > 0 then
        state.endAt, state.endPrecise = expires, true
    end
    learnLength(length)
    local raw, plain = instanceOf(aura)
    if plain ~= nil and plain ~= state.instanceID then
        if state.instanceID ~= nil then
            -- Same Tyrant: a stack change may re-apply the buff. Keep the count.
            log("버프 인스턴스 변경 %d→%d, 집계 유지 (%d마리, 진행 %d)", state.instanceID, plain,
                state.demons or 0, state.progress or 0)
        end
        state.instanceID, state.realObject, state.realFailed = plain, nil, nil
    end
    if not state.realObject and not state.realFailed and raw ~= nil then
        -- Kept only if it binds; see render().
        state.realObject = auraDuration(raw)
        if state.realObject then state.realSerial = (state.realSerial or 0) + 1 end
    end
    -- Readable stacks only verify the cast parity; they never count.
    local stacks = field(aura, "applications")
    if type(stacks) == "number" then
        if stacks ~= state.progress + 1 then
            state.pendingMismatch = (state.pendingMismatch or 0) + 1
            -- The aura update can land before its cast event; one
            -- disagreement is forgiven, two in a row are shown.
            state.mismatch = state.pendingMismatch >= 2
        else
            state.pendingMismatch, state.mismatch = 0, false
        end
    end
end

-- A buff whose start was not seen (enabled or reloaded mid-buff, or its
-- data arrived late): the demons so far are unknown, but readable stacks
-- still give the progress toward the next one.
local function beginFromAura(aura)
    startSegment("aura")
    -- Its Tyrant was just cast (the cast event beat the buff): a known start.
    state.countUnknown = not (lastTyrantAt and now() - lastTyrantAt <= START_GRACE)
    local stacks = field(aura, "applications")
    if type(stacks) == "number" and stacks >= 2 then state.progress = 1 end
    confirmAura(aura)
end

local function restoreFromAura()
    local aura = readAura()
    if type(aura) == "table" then beginFromAura(aura) end
end

-- Absence is only final after ABSENT_CONFIRM. Casts in between are kept
-- provisionally and rolled back if the buff really ended when it vanished.
local function markAbsent(reason)
    if state.absentSince then return end
    state.absentSince, state.absentReason = now(), reason
    state.absentSnapshot = { progress = state.progress, demons = state.demons }
    log("%s, %.1f초 확인 대기 (%d마리, 진행 %d)", reason, ABSENT_CONFIRM, state.demons or 0, state.progress or 0)
end

local function confirmAbsence()
    if not (state.active and state.absentSince) or now() - state.absentSince < ABSENT_CONFIRM then return end
    local snapshot = state.absentSnapshot
    state.progress, state.demons = snapshot.progress, snapshot.demons
    endSegment(state.absentReason .. " (확정)")
end

local function syncAura(updateInfo)
    -- A segment already past its end must not absorb a newer buff.
    expireIfDue()
    confirmAbsence()
    local aura = readAura()
    if aura == nil then
        -- Unknown: only a recorded, readable instance ID can end it.
        if state.active and removedHas(updateInfo, state.instanceID) then markAbsent("버프 제거 확인") end
        return
    end
    if aura == false then
        -- Once seen, absence counts; before that, allow the buff a moment to land.
        if state.active and (state.source == "aura" or now() - state.startedAt >= START_GRACE) then
            markAbsent("버프 없음 확인")
        end
        return
    end
    if state.absentSince then
        log("버프 다시 보임, 집계 유지 (%d마리, 진행 %d)", state.demons or 0, state.progress or 0)
        state.absentSince, state.absentSnapshot, state.absentReason = nil, nil, nil
    end
    if state.active then confirmAura(aura) else beginFromAura(aura) end
    refresh()
end

-- A cast of `base` itself or of a spell replacing it. Replacements are
-- normally learned before the cast lands (see learnOverrides); the lookups
-- here are a last chance for one that was never seen live.
local function castIs(spellID, base)
    if spellID == base or aliases[spellID] == base then return true end
    local api = C_Spell or {}
    if readable(api.GetOverrideSpell, base) == spellID then
        rememberAlias(spellID, base, "시전 성공 시 대체 확인")
        return true
    end
    if readable(api.GetBaseSpell, spellID) == base then
        rememberAlias(spellID, base, "기본 주문 확인")
        return true
    end
    return false
end

local function debugCast(spellID, verdict, before)
    log("시전 성공 %d %s → %s (진행 %s→%d, %d마리)", spellID, spellName(spellID), verdict,
        before or "-", state.progress or 0, state.demons or 0)
end

local function onCast(spellID)
    if isSecret(spellID) then log("시전 성공 (비밀 ID) → 판별 불가"); return end
    if type(spellID) ~= "number" then return end
    local isTyrant = castIs(spellID, DEMONIC_TYRANT)
    local isHand = not isTyrant and castIs(spellID, HAND_OF_GULDAN)
    if isTyrant then
        lastTyrantAt = now()
        expireIfDue()
        confirmAbsence()
        if state.active and state.source == "aura" and state.demons == 0 and state.progress == 0
            and now() - state.startedAt <= START_GRACE then
            -- The buff's update beat this cast event: it is this Tyrant's
            -- buff, so nothing before it is unknown. Keep its instance.
            state.countUnknown, state.startedAt = nil, now()
            refresh()
            debugCast(spellID, "폭군: 버프가 먼저 도착, 이번 폭군의 시작으로 확인")
            return
        end
        -- Its cooldown outlasts the buff: any Tyrant is a new count.
        startSegment("cast")
        refresh()
        debugCast(spellID, "폭군: 새 집계")
    elseif isHand then
        -- A cast after the (estimated) end belongs to no segment.
        expireIfDue()
        confirmAbsence()
        if not state.active then debugCast(spellID, "굴단: 구간 밖, 무시"); return end
        local before = tostring(state.progress)
        state.progress = state.progress + 1
        if state.progress >= 2 then
            state.progress = 0
            state.demons = state.demons + 1
            state.flashUntil = now() + FLASH_SECONDS
        end
        if state.pendingMismatch == 1 then state.pendingMismatch = 0 end
        render()
        debugCast(spellID, "굴단: 집계", before)
    else
        debugCast(spellID, state.active and "다른 주문" or "다른 주문 (구간 밖)")
    end
end

onUpdate = function()
    local time = now()
    if state.active and (not lastLearn or time - lastLearn >= 0.25) then
        lastLearn = time
        learnOverrides("집계 중 확인")
    end
    if state.active and state.endAt and time >= state.endAt then
        expireIfDue()
        if not state.active then return end
    end
    if state.active and state.absentSince then
        confirmAbsence()
        if not state.active then return end
    end
    local changed = false
    if state.holdUntil and time >= state.holdUntil then state = {}; changed = true end
    if state.flashUntil and time >= state.flashUntil then state.flashUntil = nil; changed = true end
    if preview and not moving and time >= preview then preview = nil; changed = true end
    if changed then render(); return end
    if frame and frame.manualEnd then
        frame.time:SetFormattedText("%.1f", math.max(0, frame.manualEnd - time))
    end
end

--------------------------------------------------------------------------------
-- Settings, preview and moving
--------------------------------------------------------------------------------

local function stopMoving(notify)
    if not moving then return end
    local callback = onMoving
    moving, onMoving = false, nil
    if frame then frame:EnableMouse(false) end
    if notify and callback then callback(false) end
end

-- Position, font and hold only; never touches the running count.
local function applyLayout()
    if frame then
        applyFont()
        placeFrame()
        frame.timerKey = nil
    end
    refresh()
end

local function applySettings()
    if not enabled() then
        stopMoving(true)
        preview = nil
    end
    local want = enabled() and isDemonology()
    if want == tracking then applyLayout(); return end
    tracking = want
    state = {}
    driver:UnregisterAllEvents()
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    if want then
        driver:RegisterEvent("PLAYER_DEAD")
        driver:RegisterEvent("PLAYER_REGEN_ENABLED")
        driver:RegisterEvent("SPELLS_CHANGED")
        for _, event in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT",
            "UNIT_SPELLCAST_START", "UNIT_AURA" }) do
            if type(driver.RegisterUnitEvent) == "function" then
                driver:RegisterUnitEvent(event, "player")
            else
                driver:RegisterEvent(event)
            end
        end
        loadAliases()
        learnOverrides("켜짐")
        restoreFromAura()
    end
    applyLayout()
end

driver:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if event == "PLAYER_LOGIN" then applySettings(); return end
    if isSecret(unit) then return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == "player" or unit == nil then applySettings() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The spec may not have been readable at login. A running count is
        -- kept: loading screens and /reload do not end the buff.
        if tracking ~= (enabled() and isDemonology()) then
            applySettings()
        elseif tracking and not state.active then
            restoreFromAura()
            refresh()
        end
    elseif not tracking then
        return
    elseif event == "PLAYER_DEAD" then
        reset("사망")
    elseif event == "SPELLS_CHANGED" then
        learnOverrides("주문 변경")
    elseif event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_START" then
        -- The replacement is certainly live while it is being cast.
        if unit == "player" then
            local spellID = event == "UNIT_SPELLCAST_SENT" and arg4 or arg3
            learnOverrides("시전 시작")
            if not isSecret(spellID) and type(spellID) == "number" and not aliases[spellID]
                and spellID ~= HAND_OF_GULDAN and spellID ~= DEMONIC_TYRANT then
                local base = readable(C_Spell and C_Spell.GetBaseSpell, spellID)
                if base == HAND_OF_GULDAN or base == DEMONIC_TYRANT then rememberAlias(spellID, base, "시전 시작 기본 주문") end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if state.active then syncAura(nil) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then onCast(arg3) end
    elseif event == "UNIT_AURA" then
        if unit == "player" then
            learnOverrides("버프 변화")
            syncAura(arg2)
        end
    end
end)
driver:RegisterEvent("PLAYER_LOGIN")

_G.MimQoLArgusTracker = {
    ApplySettings = applySettings,
    ApplyLayout = applyLayout,
    -- A running or held count stays on screen; the sample shows otherwise.
    Preview = function()
        if not enabled() then return false end
        if preview and not moving then
            preview = nil
        else
            preview = now() + PREVIEW_SECONDS
        end
        render()
        return true
    end,
    SetMoving = function(value, callback)
        if not value then
            stopMoving(false)
            preview = nil
            render()
            return false
        end
        if not enabled() then return false end
        moving, onMoving = true, callback
        render()
        frame:EnableMouse(true)
        return true
    end,
    IsMoving = function() return moving == true end,
    -- Session only: prints every player cast while tracking, with the verdict.
    ToggleDebug = function()
        debugCasts = not debugCasts
        return debugCasts
    end,
    -- For tests and the status line.
    GetState = function()
        return { active = state.active == true, progress = state.progress or 0, demons = state.demons or 0,
            countUnknown = state.countUnknown == true, mismatch = state.mismatch == true,
            holding = state.holdUntil ~= nil, source = state.source, endAt = state.endAt,
            endPrecise = state.endPrecise == true, realTimer = state.realBound == true }
    end,
}
