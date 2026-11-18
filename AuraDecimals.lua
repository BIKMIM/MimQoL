-- EllesmereUI compatibility: aura timers show tenths below a few seconds
-- ("2.9", "0.4") instead of a rounded-up "1" that vanishes at expiry.
-- EllesmereUI asks EllesmereUI.AuraKit.GetDurationFormatter for an engine-side
-- number formatter when it creates an aura button; remaining times can be
-- secret in combat, so only that formatter (never Lua) may turn them into text.
-- This wraps that one function and leaves EllesmereUI untouched otherwise.
local DECIMAL_SECONDS = 3
local driver = CreateFrame("Frame")
local cache = {}
local installed = false

local function enabled()
    return type(MimQoLDB) ~= "table" or MimQoLDB.ellesmereAuraDecimals ~= false
end

-- Same bands as EllesmereUI's own aura text (whole seconds rounded up, then
-- m / m:ss / h / d), with a tenths band in front. The tenths band follows the
-- shape EllesmereUI's cooldown manager already uses for its decimal timers.
local function buildFormatter(showSecondsUnit, preciseThreshold)
    if not (C_StringUtil and type(C_StringUtil.CreateNumericRuleFormatter) == "function"
        and Enum and Enum.NumericRuleFormatRounding) then return nil end
    local rounding = Enum.NumericRuleFormatRounding
    local Up, Down, Nearest = rounding.Up, rounding.Down, rounding.Nearest
    if not (Up and Down and Nearest) then return nil end
    local points = {
        { threshold = 0, format = showSecondsUnit and "%.1fs" or "%.1f", rounding = Nearest },
        { threshold = DECIMAL_SECONDS, format = showSecondsUnit and "%ds" or "%d", step = 1, rounding = Up },
    }
    local precise = tonumber(preciseThreshold)
    if precise and precise > 0 then
        precise = math.max(60, math.floor(precise + 0.5))
        if precise >= 3600 then precise = 3599.0001 end
    end
    if precise and precise > 60 then
        points[#points + 1] = { threshold = 60, format = "%d:%02d", step = 1, rounding = Up,
            components = { { div = 60 }, { mod = 60 } } }
        points[#points + 1] = { threshold = precise, format = "%dm", step = 1, rounding = Down,
            components = { { div = 60 } } }
    else
        points[#points + 1] = { threshold = 60, format = "%dm", step = 1, rounding = Up, components = { { div = 60 } } }
        points[#points + 1] = { threshold = 61, format = "%dm", step = 1, rounding = Down, components = { { div = 60 } } }
    end
    points[#points + 1] = { threshold = 3600, format = "%dh", step = 1, rounding = Down, components = { { div = 3600 } } }
    points[#points + 1] = { threshold = 86400, format = "%dd", step = 1, rounding = Down, components = { { div = 86400 } } }
    local okCreate, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not okCreate or not formatter then return nil end
    -- A rejected table means this client does not accept the shape; fall back.
    if not pcall(formatter.SetBreakpoints, formatter, points) then return nil end
    return formatter
end

local function decimalFormatter(showSecondsUnit, preciseThreshold)
    local key = (showSecondsUnit and "s" or "b") .. tostring(tonumber(preciseThreshold) or 0)
    if cache[key] == nil then cache[key] = buildFormatter(showSecondsUnit, preciseThreshold) or false end
    return cache[key] or nil
end

local function install()
    if installed then return true end
    local auraKit = type(EllesmereUI) == "table" and EllesmereUI.AuraKit
    if type(auraKit) ~= "table" or type(auraKit.GetDurationFormatter) ~= "function" then return false end
    local original = auraKit.GetDurationFormatter
    auraKit.GetDurationFormatter = function(showSecondsUnit, preciseThreshold, ...)
        if enabled() then
            local formatter = decimalFormatter(showSecondsUnit, preciseThreshold)
            if formatter then return formatter end
        end
        return original(showSecondsUnit, preciseThreshold, ...)
    end
    installed = true
    return true
end

-- EllesmereUI normally loads first (alphabetical, no dependency). Install as
-- early as possible so its aura buttons are created with the new formatter.
if not install() then
    driver:RegisterEvent("ADDON_LOADED")
    driver:SetScript("OnEvent", function(self, _, name)
        if name == "EllesmereUI" and install() then self:UnregisterAllEvents() end
    end)
end

_G.MimQoLAuraDecimals = {
    IsInstalled = function() return installed end,
    Seconds = DECIMAL_SECONDS,
}
