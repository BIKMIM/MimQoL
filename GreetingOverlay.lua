-- One shared anchor, with only vertically stacked phrase buttons visible.
-- Secure actions are prepared out of combat; events never send manual chat.
local driver = CreateFrame("Frame")
local root, mover
local panels = {}
local pendingSettings, pendingPrompt, pendingHide, pendingPreviewClose
local preview, moving, onMoved = false, false, nil
local api = {}
local kinds = { "general", "entry", "complete" }
local keys = { entry = "greetEntryPhrases", complete = "greetCompletePhrases", general = "greetGeneralPhrases" }
local backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function enabled()
    return type(MimQoLDB) == "table" and MimQoLDB.greetManualMode == true
end

local function number(key, default, low, high)
    local value = tonumber(MimQoLDB and MimQoLDB[key])
    if not value or value ~= value then value = default end
    return math.max(low, math.min(high, value))
end

local function phrases(key)
    local text = MimQoLDB and MimQoLDB[key]
    if type(text) ~= "string" then return {} end
    local result = {}
    for line in (text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("[%c]", " "):match("^%s*(.-)%s*$")
        if #line > 255 then
            local cut = 256
            while cut > 1 and line:byte(cut) >= 128 and line:byte(cut) < 192 do cut = cut - 1 end
            line = line:sub(1, cut - 1)
        end
        if line ~= "" then result[#result + 1] = line end
    end
    return result
end

local function shortText(text, length)
    local count, finish = 0, #text
    for index in text:gmatch("()[%z\1-\127\194-\244]") do
        count = count + 1
        if count > length then finish = index - 1; break end
    end
    return text:sub(1, finish):gsub("|", "||") .. (finish < #text and "…" or "")
end

local function style(frame)
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(0.055, 0.055, 0.065, 0.96)
    frame:SetBackdropBorderColor(0.50, 0.42, 0.22, 1)
end

local function createOverlay()
    if root then return end
    -- Publish only complete initialization. Keep unfinished drafts hidden.
    local newRoot = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    local newPanels = {}
    newRoot:Hide()
    newRoot:SetFrameStrata("DIALOG")
    newRoot:SetClampedToScreen(true)
    newRoot:SetMovable(true)
    newRoot:EnableMouse(false)
    for _, kind in ipairs(kinds) do
        local panel = CreateFrame("Frame", nil, newRoot, "SecureHandlerBaseTemplate")
        panel.buttons = {}
        panel:Hide()
        newPanels[kind] = panel
        newRoot:SetFrameRef(kind, panel)
    end
    local newMover = CreateFrame("Frame", nil, newRoot, "BackdropTemplate")
    newMover:Hide()
    newMover:SetPoint("TOPLEFT", newRoot, "TOPLEFT", 0, 0)
    newMover:SetFrameLevel(newRoot:GetFrameLevel() + 20)
    newMover:EnableMouse(true)
    newMover:RegisterForDrag("LeftButton")
    style(newMover)
    newMover:SetBackdropColor(0.15, 0.13, 0.05, 0.85)
    local text = newMover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText("드래그하여 이동")
    newMover:SetScript("OnDragStart", function()
        if moving and not inCombat() then newRoot:StartMoving() end
    end)
    newMover:SetScript("OnDragStop", function()
        if not moving or inCombat() then return end
        newRoot:StopMovingOrSizing()
        local x, y = newRoot:GetCenter()
        local scale = newRoot:GetEffectiveScale() / UIParent:GetEffectiveScale()
        MimQoLDB.greetOverlayX = x * scale - UIParent:GetWidth() / 2
        MimQoLDB.greetOverlayY = y * scale - UIParent:GetHeight() / 2
        if onMoved then onMoved() end
    end)
    SecureHandlerWrapScript(newRoot, "OnHide", newRoot, [[
        self:GetFrameRef("entry"):Hide()
        self:GetFrameRef("complete"):Hide()
    ]])
    root, panels, mover = newRoot, newPanels, newMover
end

local function hideSituations()
    panels.entry:Hide()
    panels.complete:Hide()
end

local function updateMover()
    local height = panels.general.count * 32
    if panels.entry:IsShown() then height = height + panels.entry.count * 32 end
    if panels.complete:IsShown() then height = height + panels.complete.count * 32 end
    mover:SetSize(root:GetWidth(), math.max(28, height - 4))
end

local function configure()
    createOverlay()
    local scale = number("greetOverlayScale", 100, 50, 200) / 100
    local length = math.floor(number("greetOverlayChars", 8, 2, 20))
    local width = math.max(180, length * 12 + 20)
    -- Anchor height stays fixed so switching lists never shifts the top row.
    root:SetSize(width, 1)
    root:SetScale(scale)
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER",
        number("greetOverlayX", 0, -10000, 10000) / scale,
        number("greetOverlayY", -120, -10000, 10000) / scale)
    for _, kind in ipairs(kinds) do
        local panel = panels[kind]
        local list = phrases(keys[kind])
        panel.count = #list
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", root, "TOPLEFT", 0,
            kind == "general" and 0 or -panels.general.count * 32)
        panel:SetSize(width, math.max(1, #list * 32 - 4))
        for index, text in ipairs(list) do
            local item = panel.buttons[index]
            if not item then
                item = CreateFrame("Button", nil, panel, "BackdropTemplate,SecureActionButtonTemplate")
                item:RegisterForClicks("AnyUp")
                item:SetNormalFontObject("GameFontHighlightSmall")
                item:SetHighlightFontObject("GameFontNormalSmall")
                item:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
                item:GetHighlightTexture():SetAlpha(0.12)
                style(item)
                item:SetAttribute("useOnKeyDown", false)
                -- Right click dismisses situational choices without sending.
                SecureHandlerWrapScript(item, "OnClick", root, [[
                    if button == "RightButton" then
                        self:GetParent():GetParent():GetFrameRef("entry"):Hide()
                        self:GetParent():GetParent():GetFrameRef("complete"):Hide()
                        return false
                    end
                    return nil, true
                ]], [[
                    local panel = self:GetParent()
                    if panel:GetAttribute("situation") then panel:Hide() end
                ]])
                item:HookScript("OnClick", function(_, mouseButton)
                    if mouseButton == "RightButton" or (kind ~= "general" and pendingPrompt == kind) then
                        pendingPrompt = nil
                    end
                end)
                item:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(self.fullText:gsub("|", "||"), 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                item:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                panel.buttons[index] = item
            end
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", 0, -(index - 1) * 32)
            item:SetSize(width, 28)
            item.fullText = text
            item:SetText(shortText(text, length))
            -- Previews and movement never send chat, including in a party.
            item:SetAttribute("type", nil)
            item:SetAttribute("type1", not preview and not moving and "macro" or nil)
            item:SetAttribute("macrotext1", not preview and not moving
                and ("/stopmacro [nogroup][group:raid][mod:shift]\n/i " .. text) or nil)
            item:Show()
        end
        for index = #list + 1, #panel.buttons do
            local item = panel.buttons[index]
            item:SetAttribute("type1", nil)
            item:SetAttribute("macrotext1", nil)
            item:Hide()
        end
        panel:SetAttribute("situation", kind ~= "general")
        if kind == "general" then panel:SetShown(#list > 0)
        elseif #list == 0 then panel:Hide() end
    end
    updateMover()
end

function api.Dismiss()
    pendingPrompt, pendingHide = nil, true
    if inCombat() then return end
    if root then hideSituations() end
    pendingHide = nil
end

function api.Prompt(kind)
    if not keys[kind] or not enabled() then return end
    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then return end
    pendingPrompt, pendingHide = kind, nil
    if inCombat() then return end
    if preview then api.ClosePreview() end
    if not root then api.ApplySettings() end
    if not root then return end
    hideSituations()
    panels[kind]:SetShown(panels[kind].count > 0)
    pendingPrompt = nil
end

function api.ApplySettings()
    if inCombat() then
        pendingSettings = true
        if not enabled() then pendingPrompt = nil end
        return
    end
    pendingSettings = nil
    if not enabled() and not preview then
        api.Dismiss()
        moving, onMoved = false, nil
        if root then
            if type(UnregisterStateDriver) == "function" then
                UnregisterStateDriver(root, "visibility")
                UnregisterStateDriver(mover, "visibility")
            end
            mover:Hide()
            root:Hide()
        end
        return
    end
    configure()
    if preview then
        if type(UnregisterStateDriver) == "function" then UnregisterStateDriver(root, "visibility") end
        root:Show()
    elseif type(RegisterStateDriver) == "function" then
        RegisterStateDriver(root, "visibility", "[group:party] show; hide")
    else
        root:SetShown(type(IsInGroup) == "function" and IsInGroup())
    end
    if moving and type(RegisterStateDriver) == "function" then
        RegisterStateDriver(mover, "visibility", "[combat] hide; show")
    else
        if type(UnregisterStateDriver) == "function" then UnregisterStateDriver(mover, "visibility") end
        mover:SetShown(moving)
    end
end

function api.Open(kind)
    if not keys[kind] then return end
    if inCombat() then
        print("|cffd6b85aMimQoL:|r 전투가 끝나면 미리볼 수 있습니다.")
        return
    end
    preview = true
    api.ApplySettings()
    hideSituations()
    panels[kind]:SetShown(panels[kind].count > 0)
    updateMover()
end

function api.SetMoving(value, callback)
    if inCombat() then
        print("|cffd6b85aMimQoL:|r 전투가 끝나면 위치를 이동할 수 있습니다.")
        return moving
    end
    if value and not root then api.Open("entry") end
    if not root then return false end
    root:StopMovingOrSizing()
    moving, onMoved = value == true, callback
    if moving then preview = true end
    api.ApplySettings()
    return moving
end

function api.IsMoving() return moving end

function api.ClosePreview()
    if not preview then return end
    if inCombat() then pendingPreviewClose, pendingSettings = true, true; return end
    root:StopMovingOrSizing()
    pendingPreviewClose = nil
    preview, moving, onMoved = false, false, nil
    hideSituations()
    api.ApplySettings()
end

driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function()
    if inCombat() then return end
    if pendingSettings then
        if pendingPreviewClose then api.ClosePreview() else api.ApplySettings() end
    end
    if pendingHide then api.Dismiss() end
    if pendingPrompt then api.Prompt(pendingPrompt) end
end)

_G.MimQoLGreetingOverlay = api
