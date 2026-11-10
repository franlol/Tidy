-------------------------------------------------------------------------------
-- Tidy - Keybinding mode
-- Hover a button and press a key (or a mouse button / wheel) to bind it.
-- Esc leaves the mode, Delete / Backspace clears the keys of that button.
-- Action bars 1, 3-6 and 13-15 use Blizzard's own bindings (so the keys also
-- work without Tidy); the other bars, "click" bindings to Tidy's buttons.
-- Pet and stance buttons use Blizzard's pet / stance bindings.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

-- The binding a button uses
local function Command(b)
    if b.tidyCommand then return b.tidyCommand end
    local name = b:GetName()
    local pet = name and name:match("^PetActionButton(%d+)$")
    if pet then return "BONUSACTIONBUTTON" .. pet end
    local stance = name and name:match("^StanceButton(%d+)$")
    if stance then return "SHAPESHIFTBUTTON" .. stance end
    return name and ("CLICK " .. name .. ":Keybind")
end

local IGNORE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    UNKNOWN = true, LeftButton = true, RightButton = true }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local binder, notice, current

local function Modifiers()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function KeysText(cmd)
    local keys = { GetBindingKey(cmd) }
    for i, k in ipairs(keys) do keys[i] = GetBindingText(k) end
    return #keys > 0 and table.concat(keys, ", ") or L["no key"]
end

local function ShowTip()
    if not current then return end
    GameTooltip:SetOwner(binder, "ANCHOR_TOP")
    GameTooltip:SetText(L["Press a key to bind it"], 1, 1, 1)
    GameTooltip:AddLine(KeysText(Command(current)), 0.44, 0.76, 1)
    GameTooltip:AddLine(L["Esc: leave · Delete: clear"], 0.65, 0.65, 0.65)
    GameTooltip:Show()
end

local function Save()
    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
end

local function Bind(key)
    if not current or InCombatLockdown() then return end
    if key == "ESCAPE" then ns.SetBindMode(false) return end
    local cmd = Command(current)
    if key == "DELETE" or key == "BACKSPACE" then
        for _, k in ipairs({ GetBindingKey(cmd) }) do SetBinding(k) end
    else
        SetBinding(Modifiers() .. key, cmd)
    end
    Save()
    ShowTip()
end

local function CreateBinder()
    binder = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    binder:SetFrameStrata("TOOLTIP")
    binder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    binder:SetBackdropColor(0.44, 0.76, 1, 0.3)
    binder:SetBackdropBorderColor(0.44, 0.76, 1, 1)
    binder:EnableKeyboard(true)
    binder:EnableMouseWheel(true)
    if binder.SetPropagateKeyboardInput then binder:SetPropagateKeyboardInput(false) end
    binder:RegisterForClicks("AnyUp")
    binder:SetScript("OnKeyDown", function(_, key) if not IGNORE[key] then Bind(key) end end)
    binder:SetScript("OnMouseDown", function(_, button) if MOUSE[button] then Bind(MOUSE[button]) end end)
    binder:SetScript("OnMouseWheel", function(_, d) Bind(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    binder:SetScript("OnLeave", function(self)
        self:Hide()
        current = nil
        GameTooltip:Hide()
    end)
    binder:Hide()

    notice = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    notice:SetSize(420, 40)
    notice:SetPoint("TOP", 0, -120)
    notice:SetFrameStrata("DIALOG")
    notice:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    notice:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    notice:SetBackdropBorderColor(0.44, 0.76, 1, 1)
    local t = notice:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("CENTER")
    t:SetText(L["Keybinding mode: hover a button and press a key. Esc to leave."])
    notice:Hide()
end

-- Hovering a button while the mode is on puts the binder over it
local hooked = setmetatable({}, { __mode = "k" })
local function OnEnter(b)
    if not ns.bindMode or InCombatLockdown() then return end
    current = b
    binder:ClearAllPoints()
    binder:SetAllPoints(b)
    binder:Show()
    ShowTip()
end

local function HookButtons()
    local list = {}
    for _, h in pairs(ns.bars) do
        if h.kind == "action" then
            for _, b in ipairs(h.buttons) do list[#list + 1] = b end
        end
    end
    for i = 1, 10 do
        list[#list + 1] = _G["PetActionButton" .. i]
        list[#list + 1] = _G["StanceButton" .. i]
    end
    for _, b in pairs(list) do
        if b and not hooked[b] then
            hooked[b] = true
            b:HookScript("OnEnter", OnEnter)
        end
    end
end

function ns.SetBindMode(on)
    if on and InCombatLockdown() then return end
    if not binder then CreateBinder() end
    ns.bindMode = on and true or nil
    if on then HookButtons() end
    notice:SetShown(on and true or false)
    if not on then
        binder:Hide()
        current = nil
        GameTooltip:Hide()
    end
    if ns.OnBindMode then ns.OnBindMode() end
end

-- Combat ends the mode (binding is not allowed in combat)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function() if ns.bindMode then ns.SetBindMode(false) end end)
