-- Protected-operation model only: real WoW hardware/taint enforcement needs
-- in-game verification. This test never sends chat or runs actual macros.
local checks, frames, macros = 0, {}, {}
local combat, secure, party, shift = false, false, true, false
local function check(value, message) checks = checks + 1; assert(value, message) end
local function guard(frame)
    assert(not combat or secure or not frame.protected, "insecure protected operation in combat")
end
local function snippet(code, frame, ...)
    if not code then return end
    local previous = secure
    secure = true
    local compile = loadstring or load
    local callback = assert(compile("return function(self, button, down, message) " .. code .. " end"))()
    local first, second = callback(frame, ...)
    secure = previous
    return first, second
end
local Frame = {}
Frame.__index = Frame
local failFrameRef
local function setFrameRef(self, key, value)
    guard(self)
    if key == failFrameRef then
        failFrameRef = nil
        error("injected frame-reference initialization failure")
    end
    self.refs[key] = value
end
local function noop() end
for _, method in ipairs({ "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse",
    "RegisterForDrag", "RegisterForClicks", "SetNormalFontObject", "SetHighlightFontObject",
    "SetHighlightTexture", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetAlpha" }) do
    Frame[method] = function(self) guard(self) end
end
function CreateFrame(kind, name, parent, template)
    local isSecure = template and template:find("Secure", 1, true) ~= nil
    assert(not combat or not isSecure, "created secure frame in combat")
    local frame = setmetatable({ kind = kind, parent = parent, template = template or "",
        protected = isSecure or (parent and parent.protected), shown = true,
        scripts = {}, hooks = {}, events = {}, attributes = {}, refs = {} }, Frame)
    frames[#frames + 1] = frame
    -- Template OnLoad scripts use the last inherited handler. Backdrop after
    -- SecureHandler therefore suppresses the helper-method initialization.
    local lastOnLoad
    for inherited in frame.template:gmatch("[^,]+") do
        if inherited == "BackdropTemplate" then lastOnLoad = "backdrop"
        elseif inherited:find("SecureHandler", 1, true) then lastOnLoad = "secure" end
    end
    if lastOnLoad == "secure" then frame.SetFrameRef = setFrameRef end
    if frame.template:find("SecureActionButtonTemplate", 1, true) then
        frame.actionButton = true
        frame.scripts.OnClick = function(self, mouseButton)
            if mouseButton == "LeftButton" and self.attributes.type1 == "macro" then
                macros[#macros + 1] = self.attributes.macrotext1
            end
        end
    elseif frame.template:find("SecureHandlerClickTemplate", 1, true) then
        frame.scripts.OnClick = function(self, mouseButton, down)
            snippet(self.attributes._onclick, self, mouseButton, down)
        end
    end
    return frame
end
function Frame:SetScript(event, callback)
    guard(self)
    assert(not self.actionButton or event ~= "OnClick", "overwrote secure action OnClick")
    self.scripts[event] = callback
end
function Frame:HookScript(event, callback) self.hooks[event] = callback end
function Frame:Run(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    if self.hooks[event] then self.hooks[event](self, ...) end
end
function Frame:SetAttribute(key, value) guard(self); self.attributes[key] = value end
function Frame:GetAttribute(key) return self.attributes[key] end
function Frame:GetFrameRef(key)
    assert(secure, "GetFrameRef is a restricted-snippet method")
    return self.refs[key]
end
function Frame:SetSize(width, height) guard(self); self.width, self.height = width, height end
function Frame:SetScale(scale) guard(self); self.scale = scale end
function Frame:ClearAllPoints() guard(self); self.point = nil end
function Frame:SetPoint(...) guard(self); self.point = { ... } end
function Frame:GetParent() return self.parent end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameLevel(level) guard(self); self.level = level end
function Frame:SetBackdrop(value) guard(self); self.backdrop = value end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetCenter() return 1000, 500 end
function Frame:GetEffectiveScale() return self.scale or 1 end
function Frame:StartMoving() guard(self); self.moving = true end
function Frame:StopMovingOrSizing() guard(self); self.moving = false end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:IsShown() return self.shown end
function Frame:Show()
    guard(self)
    local changed = not self.shown
    self.shown = true
    if changed then self:Run("OnShow") end
end
function Frame:Hide()
    guard(self)
    local changed = self.shown
    self.shown = false
    if changed then self:Run("OnHide") end
end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:CreateFontString()
    local font = CreateFrame("FontString", nil, self)
    font.protected = false
    return font
end
function Frame:GetHighlightTexture()
    local texture = CreateFrame("Texture", nil, self)
    texture.protected = false
    return texture
end
function Frame:RegisterEvent(event) self.events[event] = true end
function SecureHandlerWrapScript(frame, event, _, pre, post)
    guard(frame)
    local previous = frame.scripts[event]
    frame.scripts[event] = function(self, button, down)
        local result, message = snippet(pre, self, button, down)
        if result == false then return end
        if previous then previous(self, button, down) end
        if post and message ~= nil then snippet(post, self, button, down, message) end
    end
end
function RegisterStateDriver(frame, state, condition)
    guard(frame)
    check(state == "visibility" and (condition == "[group:party] show; hide" or condition == "[combat] hide; show"), "valid secure visibility")
    frame.driver = true
    frame:SetShown(condition == "[group:party] show; hide" and party or condition == "[combat] hide; show" and not combat)
end
function UnregisterStateDriver(frame) guard(frame); frame.driver = false end
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function IsInGroup() return party end
function SendChatMessage() error("manual mode must never call chat API from addon Lua") end
C_ChatInfo = { SendChatMessage = SendChatMessage }
UIParent = CreateFrame("Frame")
UIParent:SetSize(1920, 1080)
GameTooltip = { SetOwner = noop, AddLine = noop, Show = noop, Hide = noop,
    SetText = function(self, text) self.text = text end }
MimQoLDB = { autoGreet = true, greetManualMode = false,
    greetEntryPhrases = "안녕하세요 반갑습니다\n\n두 번째 문구\n   \n세 번째\n네 번째",
    greetCompletePhrases = "수고하셨습니다\r\n감사합니다\r즐거웠어요",
    greetGeneralPhrases = "안쓰는 아이템 나눔될까요?\n잠시만 기다려주세요",
    greetOverlayScale = 100, greetOverlayChars = 5, greetOverlayX = 24, greetOverlayY = -80 }
assert(loadfile("GreetingOverlay.lua"))("MimQoL")
local api = MimQoLGreetingOverlay
local driver = frames[2]
api.ApplySettings()
check(#frames == 2, "automatic mode creates no manual UI")
MimQoLDB.greetManualMode = true
api.ApplySettings()
local root
for _, frame in ipairs(frames) do
    if frame.refs.entry and frame.parent == UIParent then root = frame; break end
end
check(root ~= nil, "manual mode creates complete shared anchor")
local entry, complete, general = root.refs.entry, root.refs.complete, root.refs.general
local mover
for _, frame in ipairs(frames) do
    if frame.parent == root and frame.scripts.OnDragStart then mover = frame end
end
check(mover and not mover:IsShown(), "movement handle hidden until explicitly enabled")
check(not root.backdrop and not entry.backdrop and not complete.backdrop and not general.backdrop,
    "normal UI has no surrounding background or border")
local chrome = 0
for _, frame in ipairs(frames) do
    if (frame.parent == root or frame.parent == entry or frame.parent == complete or frame.parent == general)
        and (frame.kind == "FontString" or (frame.kind == "Button" and not frame.actionButton)) then chrome = chrome + 1 end
end
check(chrome == 0, "no titles tabs close buttons or empty-list labels")
check(#entry.buttons == 4 and #complete.buttons == 3 and #general.buttons == 2,
    "one button per saved nonblank phrase")
check(root.height == 1 and root.width == 180, "anchor remains fixed height")
check(entry.point[2] == root and complete.point[2] == root and general.point[2] == root,
    "all categories share one position anchor")
check(entry.point[5] == -64 and complete.point[5] == -64 and general.point[5] == 0,
    "situational choices occupy the same rows below common phrases")
check(entry.buttons[1].point[2] == 0 and entry.buttons[1].point[3] == 0
    and entry.buttons[2].point[2] == 0 and entry.buttons[2].point[3] == -32,
    "buttons form one vertical column")
check(entry.buttons[1].text == "안녕하세요…", "Korean labels shorten by character")
entry.buttons[1]:Run("OnEnter")
check(GameTooltip.text == "안녕하세요 반갑습니다", "tooltip keeps the full phrase")
check(entry.buttons[1]:GetAttribute("macrotext1") ==
    "/stopmacro [nogroup][group:raid][mod:shift]\n/i 안녕하세요 반갑습니다", "only left click has a guarded full-text macro")
check(general:IsShown() and not entry:IsShown() and not complete:IsShown(), "only common buttons shown between situations")
api.Prompt("entry")
check(entry:IsShown() and general:IsShown() and #macros == 0, "entry event shows choices without sending")
entry.buttons[2]:Run("OnClick", "LeftButton", false)
check(#macros == 1 and macros[1]:find("두 번째 문구", 1, true), "only the selected phrase is sent")
check(not entry:IsShown() and general:IsShown(), "selecting an entry phrase retains common buttons")
api.Prompt("complete")
check(complete:IsShown() and not entry:IsShown(), "completion replaces entry at the same anchor")
local previousCount = #macros
complete.buttons[1]:Run("OnClick", "RightButton", false)
check(#macros == previousCount and not complete:IsShown(), "right click dismisses without sending")
MimQoLDB.autoGreet = false
api.ApplySettings()
check(root:IsShown() and general:IsShown(), "manual controls work without automatic mode")

combat = true
api.Prompt("complete")
check(not complete:IsShown(), "combat never insecurely opens a new protected list")
general.buttons[1]:Run("OnClick", "LeftButton", false)
check(general:IsShown() and #macros == previousCount + 1, "prepared common phrases remain clickable in combat")
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(complete:IsShown(), "pending completion opens after combat even if a common phrase was used")
combat = true
complete.buttons[1]:Run("OnClick", "LeftButton", false)
check(not complete:IsShown() and #macros == previousCount + 2, "already visible choices send and close in combat")
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(not complete:IsShown(), "consumed situation does not reopen")
combat = true
api.Dismiss()
api.Prompt("entry")
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(entry:IsShown(), "new prompt survives an earlier deferred dismissal")
api.Dismiss()
combat = true
api.Prompt("complete")
api.Dismiss()
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(not complete:IsShown(), "leaving/reset cancels the deferred prompt")

local previous = entry.buttons[1]:GetAttribute("macrotext1")
combat = true
MimQoLDB.greetEntryPhrases = "변경 문구"
MimQoLDB.greetOverlayScale = 150
api.ApplySettings()
check(entry.buttons[1]:GetAttribute("macrotext1") == previous and root.scale == 1,
    "combat settings do not mutate protected attributes or scale")
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(root.scale == 1.5 and entry.buttons[1]:GetAttribute("macrotext1"):find("변경 문구", 1, true),
    "saved changes apply after combat")
check(not entry.buttons[2]:IsShown() and entry.buttons[2]:GetAttribute("macrotext1") == nil,
    "removed phrases clear recycled buttons")

local moves = 0
api.Open("entry")
previousCount = #macros
entry.buttons[1]:Run("OnClick", "LeftButton", false)
general.buttons[1]:Run("OnClick", "LeftButton", false)
check(#macros == previousCount, "screen previews never send chat even in a party")
api.Open("entry")
check(api.SetMoving(true, function() moves = moves + 1 end), "position control enables movement")
check(mover:IsShown() and mover.height == 92, "movement cover spans the visible button stack")
mover:Run("OnDragStart")
check(root.moving, "only movement handle starts dragging")
mover:Run("OnDragStop")
check(moves == 1 and MimQoLDB.greetOverlayX == 540 and MimQoLDB.greetOverlayY == 210,
    "drag saves scaled shared coordinates and refreshes options")
check(entry.buttons[1]:GetAttribute("type1") == nil, "movement cannot accidentally send a message")
api.SetMoving(false)
check(not mover:IsShown() and not api.IsMoving(), "movement locks again after finishing")
api.ClosePreview()
check(not entry:IsShown() and general:IsShown() and general.buttons[1]:GetAttribute("type1") == "macro",
    "closing settings restores live common buttons")
mover:Run("OnDragStart")
check(not root.moving, "ordinary mode does not allow dragging")
MimQoLDB.greetOverlayX, MimQoLDB.greetOverlayY = -200, 100
api.ApplySettings()
check(root.point[4] == -200 / 1.5 and root.point[5] == 100 / 1.5, "numeric position applies to the same anchor")

api.Open("entry")
combat = true
api.ClosePreview()
api.Prompt("complete")
check(entry.buttons[1]:GetAttribute("type1") == nil, "closing a preview in combat keeps its non-sending attributes")
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(complete:IsShown() and complete.buttons[1]:GetAttribute("type1") == "macro",
    "deferred preview cleanup preserves a pending completion")
api.Dismiss()
combat = true
api.Prompt("entry")
MimQoLDB.greetManualMode = false
api.ApplySettings()
combat = false
driver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(not root:IsShown() and not root.driver and not entry:IsShown(), "disable removes UI and pending choices")
api.Open("entry")
check(root:IsShown() and entry.buttons[1]:GetAttribute("type1") == nil, "disabled feature may be safely previewed")
api.ClosePreview()
check(not root:IsShown(), "closing preview restores disabled state")

MimQoLDB.greetManualMode = true
MimQoLDB.greetEntryPhrases = "\n \n\t"
api.ApplySettings()
api.Prompt("entry")
check(not entry:IsShown() and not entry.buttons[1]:IsShown(), "empty list shows no empty popup")
shift = true
api.Prompt("complete")
check(not complete:IsShown(), "Shift skips popup")
shift = false
MimQoLDB.greetEntryPhrases = string.rep("가", 90)
api.ApplySettings()
check(#entry.buttons[1].fullText == 255, "UTF-8 chat byte limit")
MimQoLDB.greetEntryPhrases = "|abc|def"
MimQoLDB.greetOverlayChars = 2
api.ApplySettings()
check(entry.buttons[1].text == "||a…", "plain-text pipe escaping")
party = false
api.ApplySettings()
check(not root:IsShown(), "solo hides the common button stack")
api.Open("entry")
check(root:IsShown(), "solo can preview the shared position")
api.ClosePreview()
check(not root:IsShown(), "preview exit restores party-only visibility")
party = true
api.ApplySettings()

-- The original partial-initialization regression remains covered.
assert(loadfile("GreetingOverlay.lua"))("MimQoL")
local retryApi = MimQoLGreetingOverlay
local firstDraftIndex = #frames + 1
failFrameRef = "entry"
local initialized, failure = pcall(retryApi.ApplySettings)
check(not initialized and failure:find("injected frame-reference", 1, true), "initialization failure reproduced")
local draft = frames[firstDraftIndex]
check(not draft:IsShown() and draft.refs.complete == nil, "incomplete draft stays hidden")
retryApi.Dismiss()
MimQoLDB.greetManualMode = false
retryApi.ApplySettings()
MimQoLDB.greetManualMode = true
local retryIndex = #frames + 1
retryApi.ApplySettings()
local recovered = frames[retryIndex]
check(recovered ~= draft and recovered.refs.entry and recovered.refs.complete and recovered.refs.general,
    "retry rebuilds the entire stack")
retryApi.Prompt("complete")
check(recovered.refs.complete:IsShown(), "recovered completion works")
local finishedCount = #frames
retryApi.ApplySettings()
check(#frames == finishedCount, "finished initialization is reused")
combat = true
assert(loadfile("GreetingOverlay.lua"))("MimQoL")
local reloadDriver = frames[#frames]
local count = #frames
MimQoLGreetingOverlay.ApplySettings()
check(#frames == count, "combat reload creates no protected UI")
combat = false
reloadDriver:Run("OnEvent", "PLAYER_REGEN_ENABLED")
check(#frames > count, "combat reload initializes safely after regen")
print("greeting_overlay_smoke: " .. checks .. " checks passed")
