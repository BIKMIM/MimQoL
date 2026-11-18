-- Class-shared character macros: save one character's own (character-specific)
-- macros for its class, then apply them on another character of the same class.
-- Account macros are shared by the game already and are never touched.
-- Applying edits same-named macros and creates missing ones; macros that only
-- exist on the target are kept. The target's previous macros are backed up so
-- the last apply can be undone. Nothing runs in combat.
local ADDON_NAME = ...
if ADDON_NAME ~= "MimQoL" then return end

local QUESTION_MARK_ICON = 134400

local function readable(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c = pcall(func, ...)
    if not ok then return nil end
    return a, b, c
end

local function inCombat()
    return readable(InCombatLockdown) == true
end

local function classInfo()
    local localized, classFile = readable(UnitClass, "player")
    return classFile, localized or classFile
end

local function characterKey()
    local name = readable(UnitName, "player")
    if type(name) ~= "string" then return nil end
    local realm = readable(GetNormalizedRealmName)
    return realm and (name .. "-" .. realm) or name
end

local function root()
    if type(MimQoLDB) ~= "table" then return nil end
    local data = type(MimQoLDB.macroKeeper) == "table" and MimQoLDB.macroKeeper or {}
    MimQoLDB.macroKeeper = data
    data.version = 1
    data.classes = type(data.classes) == "table" and data.classes or {}
    data.backups = type(data.backups) == "table" and data.backups or {}
    return data
end

local function firstCharacterIndex()
    return (tonumber(MAX_ACCOUNT_MACROS) or 120) + 1
end

local function characterLimit()
    return tonumber(MAX_CHARACTER_MACROS) or 30
end

-- Current character-specific macros in game order: { name, icon, body }.
local function characterMacros()
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return nil end
    local _, count = readable(GetNumMacros)
    count = tonumber(count) or 0
    local first, list = firstCharacterIndex(), {}
    for index = first, first + count - 1 do
        local name, icon, body = readable(GetMacroInfo, index)
        if type(name) == "string" then
            body = type(body) == "string" and body or ""
            -- "#showtooltip" macros keep the question-mark icon so the button
            -- still follows the shown spell; GetMacroInfo may report that spell.
            if body:match("^%s*#show") then icon = QUESTION_MARK_ICON end
            list[#list + 1] = { name = name, icon = icon or QUESTION_MARK_ICON, body = body }
        end
    end
    return list
end

-- Index of the nth character macro with this name (duplicate names are matched in order).
local function findNth(name, nth)
    local _, count = readable(GetNumMacros)
    local first, seen = firstCharacterIndex(), 0
    for index = first, first + (tonumber(count) or 0) - 1 do
        if readable(GetMacroInfo, index) == name then
            seen = seen + 1
            if seen == nth then return index end
        end
    end
    return nil
end

local function writeMacros(list)
    local edited, created, unchanged, skipped, createdNames = 0, 0, 0, 0, {}
    local seen = {}
    for _, macro in ipairs(list) do
        seen[macro.name] = (seen[macro.name] or 0) + 1
        local index = findNth(macro.name, seen[macro.name])
        if index then
            local _, icon, body = readable(GetMacroInfo, index)
            -- "#show" macros display the spell icon, so only their text has to match.
            if (body or "") == macro.body and (macro.body:match("^%s*#show") or icon == macro.icon) then
                unchanged = unchanged + 1
            elseif pcall(EditMacro, index, macro.name, macro.icon, macro.body) then
                edited = edited + 1
            else
                skipped = skipped + 1
            end
        else
            local _, count = readable(GetNumMacros)
            if (tonumber(count) or 0) >= characterLimit() then
                skipped = skipped + 1
            elseif pcall(CreateMacro, macro.name, macro.icon, macro.body, true) then
                created = created + 1
                createdNames[#createdNames + 1] = macro.name
            else
                skipped = skipped + 1
            end
        end
    end
    return edited, created, unchanged, skipped, createdNames
end

local function save()
    if inCombat() then return false, "전투가 끝난 뒤 저장하세요." end
    local data, classFile, className = root(), classInfo()
    local list = characterMacros()
    if not data or not classFile or not list then return false, "매크로 정보를 읽지 못했습니다." end
    data.classes[classFile] = { macros = list, savedBy = characterKey(), savedAt = time and time() or 0 }
    return true, string.format("%s 캐릭터 전용 매크로 %d개를 %s 공용으로 저장했습니다.",
        characterKey() or "현재", #list, className)
end

local function apply()
    if inCombat() then return false, "전투가 끝난 뒤 적용하세요." end
    local data, classFile, className = root(), classInfo()
    local saved = data and classFile and data.classes[classFile]
    if type(saved) ~= "table" or type(saved.macros) ~= "table" or #saved.macros == 0 then
        return false, (className or "이 직업") .. " 공용으로 저장된 매크로가 없습니다."
    end
    if type(EditMacro) ~= "function" or type(CreateMacro) ~= "function" then
        return false, "이 클라이언트에서는 매크로를 바꿀 수 없습니다."
    end
    local key = characterKey()
    if key and key == saved.savedBy then return false, "매크로를 저장한 캐릭터입니다. 다른 캐릭터에서 적용하세요." end
    local before = characterMacros() or {}
    local edited, created, unchanged, skipped, createdNames = writeMacros(saved.macros)
    if key and (edited > 0 or created > 0) then
        data.backups[key] = { macros = before, createdNames = createdNames, at = time and time() or 0 }
    end
    local wanted = {}
    for _, macro in ipairs(saved.macros) do wanted[macro.name] = (wanted[macro.name] or 0) + 1 end
    local extra = 0
    for _, macro in ipairs(before) do
        wanted[macro.name] = (wanted[macro.name] or 0) - 1
        if wanted[macro.name] < 0 then extra = extra + 1 end
    end
    local message = string.format("매크로 적용: 바꿈 %d, 새로 만듦 %d, 같음 %d", edited, created, unchanged)
    if skipped > 0 then message = message .. string.format(", 못 함 %d (캐릭터 매크로 칸 부족 등)", skipped) end
    if extra > 0 then message = message .. string.format(". 이 캐릭터에만 있던 매크로 %d개는 그대로 둠", extra) end
    return true, message .. "."
end

local function undo()
    if inCombat() then return false, "전투가 끝난 뒤 되돌리세요." end
    local data, key = root(), characterKey()
    local backup = data and key and data.backups[key]
    if type(backup) ~= "table" then return false, "되돌릴 적용 기록이 없습니다." end
    -- Remove what the apply created, then put the earlier bodies back.
    for i = #(backup.createdNames or {}), 1, -1 do
        local name, last = backup.createdNames[i], nil
        local nth = 1
        while true do
            local index = findNth(name, nth)
            if not index then break end
            last, nth = index, nth + 1
        end
        if last then pcall(DeleteMacro, last) end
    end
    writeMacros(backup.macros or {})
    data.backups[key] = nil
    return true, "마지막 매크로 적용을 되돌렸습니다."
end

local function status()
    local data, classFile, className = root(), classInfo()
    local saved = data and classFile and data.classes[classFile]
    local key = characterKey()
    return {
        className = className,
        savedCount = type(saved) == "table" and type(saved.macros) == "table" and #saved.macros or 0,
        savedBy = type(saved) == "table" and saved.savedBy or nil,
        isSource = type(saved) == "table" and key ~= nil and saved.savedBy == key,
        canUndo = data ~= nil and key ~= nil and type(data.backups[key]) == "table",
        currentCount = #(characterMacros() or {}),
    }
end

_G.MimQoLMacroKeeper = { Save = save, Apply = apply, Undo = undo, GetStatus = status }
