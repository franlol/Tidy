-------------------------------------------------------------------------------
-- Tidy - Action bars
-- The buttons come from LibActionButton-1.0 (icon, cooldown, range, charges,
-- secure clicks). Tidy only does:
--   * layout: buttons, rows, padding, scale, alpha, position
--   * paging: a state driver per bar (bar 1 follows stance/form, vehicle,
--     override and bonus bars like Blizzard's main bar)
--   * keybinds: your Blizzard binds point to these buttons (override binds)
--   * hiding Blizzard's action bars
-- Bar N shows action page N (actions (N-1)*12+1 ... N*12).
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local BUTTON = 45 -- size of a Blizzard action button
-- Every action page a bar can use. Page 11 is left out: it is the game's
-- bonus bar 5 (C_ActionBar.GetBonusBarIndexForSlot(121) returns 11).
local BAR_IDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15 }
ns.BAR_IDS = BAR_IDS

-- Blizzard binding names for each bar (their keys are reused here)
local COMMANDS = {
    [1] = "ACTIONBUTTON", [6] = "MULTIACTIONBAR1BUTTON", [5] = "MULTIACTIONBAR2BUTTON",
    [3] = "MULTIACTIONBAR3BUTTON", [4] = "MULTIACTIONBAR4BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON", [14] = "MULTIACTIONBAR6BUTTON", [15] = "MULTIACTIONBAR7BUTTON",
}

-- Default settings of a bar (a similar layout to Blizzard's)
local function Pos(point, x, y) return { point = point, x = x, y = y } end
local DEFAULT_POS = {
    [1] = Pos("BOTTOM", -281, 60), [6] = Pos("BOTTOM", -281, 108), [5] = Pos("BOTTOM", -281, 156),
    [3] = Pos("RIGHT", -50, 270), [4] = Pos("RIGHT", -97, 270),
}
-- Settings every bar has (action bars and holders)
function ns.CommonBarDefaults(t)
    t.growH = "RIGHT"        -- buttons fill to the right / left
    t.growV = "DOWN"         -- rows fill down / up
    t.clickThrough = false
    -- visibility
    t.fade = false           -- fade out when the mouse is not over it
    t.fadeAlpha = 0.2
    t.fadeDelay = 0.5        -- seconds before fading
    t.hideCombat = false
    t.hideNoCombat = false
    t.hidePet = false
    t.hideNoPet = false
    t.hideVehicle = false
    t.hideStance = false     -- in any stance / form (stealth, bear, shadowform...)
    t.custom = ""            -- macro conditions; replaces the options above
    return t
end

function ns.BarDefaults(id)
    -- pet, stance, micro menu, bags...: Holders.lua
    if type(id) == "string" then return ns.HolderDefaults(id) end
    local vertical = id == 3 or id == 4
    return ns.CommonBarDefaults({
        enabled = id == 1 or id == 3 or id == 4 or id == 5 or id == 6,
        buttons = 12,
        rows = vertical and 12 or 1,
        padding = 2,
        scale = 1,
        alpha = 1,
        showGrid = false,
        pos = DEFAULT_POS[id] or Pos("CENTER", -281, 200 - id * 30),
        -- paging
        page = id,               -- page shown normally
        stancePaging = id == 1,  -- change page with stance / form
        ctrlPage = 0,            -- page while Ctrl / Alt / Shift is held (0 = none)
        altPage = 0,
        shiftPage = 0,
        -- buttons
        buttonWidth = BUTTON,
        buttonHeight = BUTTON,
        iconFit = "cover",       -- cover (crop) / contain (whole icon) / stretch
        hideMacro = false,
        hideHotkey = false,
        hideEquipped = false,
        flyout = vertical and "LEFT" or "UP",
    })
end

local B          -- ns.P.bars (profile in use)
local bars = {}  -- [id] = header
ns.bars = bars

-- Settings of a bar, with the missing keys filled from the defaults
function ns.BarConfig(id)
    local list = B.list
    local c = list[id]
    if not c then
        c = {}
        list[id] = c
    end
    for k, v in pairs(ns.BarDefaults(id)) do
        if c[k] == nil then c[k] = ns.Copy(v) end
    end
    return c
end

-------------------------------------------------------------------------------
-- Hiding Blizzard's bars (kept alive, only reparented to a hidden frame)
-------------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()

-- Blizzard bars are only moved into a hidden frame (their events keep
-- running, like when Edit Mode hides a bar), so they can be given back
-- without a reload
local moved = {} -- frame -> original parent

local function HideFrame(f)
    if not f or moved[f] then return end
    moved[f] = f:GetParent()
    f:SetParent(hider)
end

local BLIZZ_BARS = { "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7" }

-- Other Blizzard frames that may hang from the main bar: moved to UIParent
-- so hiding the main bar does not take them along
local KEEP = { "MicroMenuContainer", "MicroMenu", "MicroButtonAndBagsBar", "BagsBar",
    "StatusTrackingBarManager", "StanceBar", "PetActionBar", "PossessActionBar",
    "MainMenuBarVehicleLeaveButton", "ExtraActionBarFrame", "ZoneAbilityFrame" }

-- Blizzard's buttons are never touched (attributes, methods): anything an
-- addon writes on them taints them, and this client then refuses them the
-- cooldown data ("secret values"). Being inside a hidden frame is enough:
-- they cannot be seen or clicked, and the keybinds go to Tidy's buttons.

-- Frames moved off the main bar (KEEP): original parent and points, to put
-- them back exactly when Tidy's bars are turned off
local kept = {}

local function ShowBlizzard()
    for f, parent in pairs(moved) do f:SetParent(parent) end
    wipe(moved)
    for f, o in pairs(kept) do
        f:SetParent(o.parent)
        f:ClearAllPoints()
        for _, p in ipairs(o.points) do pcall(f.SetPoint, f, unpack(p)) end
    end
    wipe(kept)
end

local function HideBlizzard()
    for _, mainName in ipairs({ "MainMenuBar", "MainActionBar" }) do
        local main = _G[mainName]
        for _, name in ipairs(KEEP) do
            local f = _G[name]
            if f and main and f:GetParent() == main and not kept[f] then
                local points = {}
                for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
                kept[f] = { parent = main, points = points }
                f:SetParent(UIParent)
                f:ClearAllPoints()
                for _, p in ipairs(points) do f:SetPoint(unpack(p)) end
            end
        end
    end
    for _, name in ipairs(BLIZZ_BARS) do HideFrame(_G[name]) end
end

-------------------------------------------------------------------------------
-- Paging
-------------------------------------------------------------------------------
-- Bar 1: like Blizzard's main bar (ActionBarController). Stances/forms use
-- the bonus bars: warrior battle/def/berserker 7/8/9, druid cat 7 (prowl 8),
-- bear 9, moonkin 10, rogue stealth 7, priest shadowform 7. Bonus bar 5 is
-- page 11 (the game's own page: C_ActionBar.GetBonusBarIndexForSlot(121)).
-- Order: vehicle, override, temporary shapeshift, bonus bar 5 (bar 1),
-- Ctrl/Alt/Shift pages, Shift+number pages (bar 1), stance/form pages, the
-- bar's own page.
local function PageDriver(id, c)
    local s = ""
    if id == 1 then
        s = "[vehicleui]vehicle;[overridebar]override;[shapeshift]shapeshift;[bonusbar:5]11;"
    end
    for _, mod in ipairs({ "ctrl", "alt", "shift" }) do
        local p = c[mod .. "Page"]
        if p and p > 0 then s = s .. ("[mod:%s]%d;"):format(mod, p) end
    end
    if id == 1 then s = s .. "[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;" end
    if c.stancePaging then
        s = s .. "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;"
    end
    return s .. tostring(c.page or id)
end

-------------------------------------------------------------------------------
-- Visibility (action bars and holders): hide conditions, or the user's own
-- macro conditions. base: what to do when nothing hides it.
-------------------------------------------------------------------------------
function ns.VisibilityDriver(c, base)
    local custom = c.custom and strtrim(c.custom) or ""
    if custom ~= "" then return custom end
    local s = ""
    if c.hideVehicle then s = s .. "[vehicleui][overridebar][possessbar][petbattle] hide;" end
    if c.hideCombat then s = s .. "[combat] hide;" end
    if c.hideNoCombat then s = s .. "[nocombat] hide;" end
    if c.hidePet then s = s .. "[pet] hide;" end
    if c.hideNoPet then s = s .. "[nopet] hide;" end
    if c.hideStance then s = s .. "[stance] hide;" end
    return s .. (base or "show")
end

-------------------------------------------------------------------------------
-- Fade out: one light timer (10 times a second) for every faded bar
-------------------------------------------------------------------------------
local fader = CreateFrame("Frame")
local faded = {} -- header -> last time the mouse was over it

local function FadeTick(_, elapsed)
    fader.t = (fader.t or 0) + elapsed
    if fader.t < 0.1 then return end
    fader.t = 0
    local now = GetTime()
    for h in pairs(faded) do
        local c = ns.BarConfig(h.id)
        -- always full while unlocked or binding keys
        if not B.locked or ns.bindMode or (h:IsVisible() and h:IsMouseOver()) then
            faded[h] = now
            h:SetAlpha(c.alpha)
        elseif now - faded[h] >= c.fadeDelay then
            h:SetAlpha(c.fadeAlpha)
        end
    end
end

function ns.SetFade(h, c)
    if c.fade and c.enabled then
        faded[h] = faded[h] or 0
    else
        faded[h] = nil
        h:SetAlpha(c.alpha)
    end
    fader:SetScript("OnUpdate", next(faded) and FadeTick or nil)
end

-- secure: the game's page for the vehicle / override / temporary shapeshift
-- bars, then tells the buttons
local ON_PAGE = [[
    if newstate == "vehicle" then newstate = GetVehicleBarIndex()
    elseif newstate == "override" then newstate = GetOverrideBarIndex()
    elseif newstate == "shapeshift" then newstate = GetTempShapeshiftBarIndex() end
    newstate = tonumber(newstate) or 1
    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
]]

-------------------------------------------------------------------------------
-- Buttons: LibActionButton-1.0 (BSD). It works
-- with this client's protected cooldown data ("secret values"), which
-- Blizzard's own template does not allow from an addon.
-- Each button has one action per page ("state"): state N = page N.
-------------------------------------------------------------------------------
local LAB = LibStub("LibActionButton-1.0")
-- enough pages for the vehicle / override / temp shapeshift bars, whose
-- page numbers depend on the client (31-33 on Forever)
local function PageCount()
    return math.max(18, C_ActionBar.GetVehicleBarIndex(), C_ActionBar.GetOverrideBarIndex(),
        C_ActionBar.GetTempShapeshiftBarIndex())
end
-- Short form of a key: SHIFT-1 -> S1, BUTTON4 -> M4, NUMPAD3 -> N3...
local SHORT = {
    { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" }, { "META%-", "M" },
    { "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" }, { "MIDDLEMOUSE", "M3" },
    { "BUTTON", "M" }, { "NUMPAD", "N" }, { "PAGEUP", "PU" }, { "PAGEDOWN", "PD" },
    { "SPACE", "Sp" }, { "INSERT", "Ins" }, { "DELETE", "Del" }, { "HOME", "Hm" }, { "END", "End" },
}
local function ShortKey(key)
    for _, r in ipairs(SHORT) do key = key:gsub(r[1], r[2]) end
    return key
end

-- The key shown on the button, short
local function GetHotkey(self)
    local key = GetBindingKey(self.tidyCommand or ("CLICK " .. self:GetName() .. ":Keybind"))
    return key and ShortKey(key)
end

-- A text of the button (key, count, macro name) for LibActionButton
local function TextConfig(t)
    local p = t.point
    return {
        font = { font = t.font, size = t.size, flags = t.outline },
        color = { t.color.r, t.color.g, t.color.b, t.color.a or 1 },
        position = { anchor = p, relAnchor = p, offsetX = t.x, offsetY = t.y },
        justifyH = p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"),
    }
end

-- Settings LibActionButton reads (anything missing: its defaults)
local function ButtonConfig(b, c)
    local G = B.buttons
    return {
        -- unlocked: every slot shows, like the samples of the other bars
        showGrid = c.showGrid or not B.locked,
        keyBoundTarget = b.tidyCommand or false,
        keyBoundClickButton = "Keybind",
        actionButtonUI = true,
        outOfRangeColoring = G.range,
        tooltip = G.tooltip,
        colors = {
            range = { G.rangeColor.r, G.rangeColor.g, G.rangeColor.b, G.rangeColor.a or 1 },
            mana = { G.manaColor.r, G.manaColor.g, G.manaColor.b, G.manaColor.a or 1 },
        },
        hideElements = { macro = c.hideMacro, hotkey = c.hideHotkey, equipped = c.hideEquipped },
        flyoutDirection = c.flyout,
        spellCastVFX = G.castVFX and G.castStyle == "blizzard", -- flat: Tidy's own (below)
        text = { hotkey = TextConfig(G.texts.hotkey), count = TextConfig(G.texts.count), macro = TextConfig(G.texts.macro) },
    }
end

-- Countdown shown or hidden by Tidy, over the game's "cooldown numbers"
-- option. LibActionButton's cooldownCount setting is lost (its default is
-- nil, its merge skips it) and it sets the game's choice again on every
-- cooldown type change and option change, so every set is corrected here.
local function KeepCountdown(cd)
    if cd.tidyCounting or not B then return end
    cd.tidyCounting = true
    cd:SetHideCountdownNumbers(not B.buttons.texts.cooldown.show)
    cd.tidyCounting = nil
end

-- The cooldown countdown: the game draws it (its times are secret), Tidy
-- gives it a font and a place on the button
local countdownFont
local function StyleCountdown(b)
    local cd = b.cooldown
    if not cd then return end
    KeepCountdown(cd)
    local t = B.buttons.texts.cooldown
    local c = t.color
    if cd.SetCountdownFont then
        countdownFont = countdownFont or CreateFont("TidyCountdownFont")
        countdownFont:SetFont(t.font, t.size, t.outline)
        countdownFont:SetTextColor(c.r, c.g, c.b, c.a or 1)
        cd:SetCountdownFont("TidyCountdownFont")
    end
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        if not cd.SetCountdownFont then
            fs:SetFont(t.font, t.size, t.outline)
            fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
        end
        fs:ClearAllPoints()
        fs:SetPoint(t.point, b, t.point, t.x, t.y)
    end
end

-- Secure attributes: button lock and casting helpers (out of combat)
local function ButtonAttributes(b)
    local K = B.casting
    b:SetAttribute("buttonlock", B.buttons.lock or nil)
    -- with "cast on key down", a mouse press would cast before a drag can
    -- start: while buttons are not locked, mouse clicks cast on release
    -- (keys still cast on press)
    b:SetAttribute("unlockedpreventdrag", true)
    b:SetAttribute("checkselfcast", K.selfCast or nil)
    b:SetAttribute("checkfocuscast", K.focusCast or nil)
    b:SetAttribute("checkmouseovercast", K.mouseover or nil)
    b:SetAttribute("*unit2", K.rightClickSelf and "player" or nil)
end

-- Icon inside a button of any width / height, like CSS object-fit:
--   cover   : fills the button, the icon is cropped to keep its shape
--   contain : the whole icon, as big as fits, centered
--   stretch : fills the button, the icon is deformed
-- z: extra crop of the icon edge (the square icons' zoom).
-- The cooldown, highlight and flash follow the icon.
function ns.FitIcon(b, z)
    local f, icon = b.tidyFit, b.icon
    if not f or not icon then return end
    z = z or 0
    local w, h = f.w, f.h
    local l, r, t, bo = z, 1 - z, z, 1 - z
    local span = 1 - 2 * z
    if f.mode == "cover" and w ~= h then
        if w > h then
            t, bo = 0.5 - span * h / w / 2, 0.5 + span * h / w / 2
        else
            l, r = 0.5 - span * w / h / 2, 0.5 + span * w / h / 2
        end
    end
    icon:SetTexCoord(l, r, t, bo)
    -- re-anchored every time: LibActionButton moves the cooldown and the
    -- highlight back to its own sizes when the action changes
    icon:ClearAllPoints()
    if f.mode == "contain" then
        local m = math.min(w, h)
        icon:SetSize(m, m)
        icon:SetPoint("CENTER", b, "CENTER")
    else
        icon:SetAllPoints(b)
    end
    -- the cooldown covers the icon; highlight, pressed, checked, flash and
    -- the equipped border cover the whole button (its size never changes)
    -- (numeric loops: some of these may not exist, ipairs would stop there)
    local onIcon = { b.cooldown, b.chargeCooldown }
    for i = 1, 2 do
        local region = onIcon[i]
        if region then
            pcall(region.ClearAllPoints, region)
            pcall(region.SetAllPoints, region, icon)
        end
    end
    local onButton = { b:GetHighlightTexture(), b:GetPushedTexture(), b:GetCheckedTexture(),
        b.Flash, b.NewActionTexture, b.Border }
    for i = 1, 6 do
        local region = onButton[i]
        if region then
            pcall(region.ClearAllPoints, region)
            pcall(region.SetAllPoints, region, b)
        end
    end
end

-- Zoom of the square icons, if they are on for action bars
local function IconZoom()
    local I = ns.P.icons
    return I.enabled and I.actionbars and I.zoom or 0
end

-- After every update of a Tidy button: the icon fit again (own key for the
-- callback, Icons.lua has its own)
local fitKey = {}
LAB.RegisterCallback(fitKey, "OnButtonUpdate", function(_, b)
    if b.tidyFit then ns.FitIcon(b, IconZoom()) end
end)

-- Cooldown flags: the times are secret on this client, only the flags
-- (active, on the global cooldown) are read; anything unreadable is "no"
local function Readable(v)
    if v == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end

local function CooldownInfo(b)
    local ok, info = pcall(b.GetCooldownInfo, b)
    return ok and type(info) == "table" and info or nil
end

-- The button's cooldown is only the global cooldown (nil: unknown)
local function OnlyGCD(b)
    local info = CooldownInfo(b)
    if info and Readable(info.isOnGCD) then return info.isOnGCD and true or false end
end

-- Cooldown darkness: the swipe over the icon never goes over the chosen
-- darkness (a lighter one for the global cooldown). After the cast
-- animation the library leaves it fully opaque black on that button (it hid
-- the icon until the spell was moved away); the color stays (red for loss
-- of control), only its opacity is capped.
local function SwipeMax(cd)
    local G = B.buttons
    if cd.tidyGCD then return G.gcdAlpha or 0.5 end
    return G.cooldownAlpha or 0.8
end

local function CapSwipe(cd, r, g, bl, a)
    if cd.tidyCapping then return end
    cd.tidyRGB = { r or 0, g or 0, bl or 0 }
    local max = SwipeMax(cd)
    if (a or 1) > max then
        cd.tidyCapping = true
        cd:SetSwipeColor(r or 0, g or 0, bl or 0, max)
        cd.tidyCapping = nil
    end
end

-- The chosen darkness for what the cooldown is now (also raises it: CapSwipe
-- only lowers)
local function ApplySwipe(b)
    local cd = b.cooldown
    if not cd then return end
    cd.tidyGCD = OnlyGCD(b)
    local c = cd.tidyRGB or { 0, 0, 0 }
    cd.tidyCapping = true
    cd:SetSwipeColor(c[1], c[2], c[3], SwipeMax(cd))
    cd.tidyCapping = nil
    -- spark on the global cooldown: the game's edge line, which follows the
    -- swipe (the times are secret, it is the only thing that can follow it);
    -- otherwise the edge the library asked for (loss of control)
    local spark = B.buttons.gcdSpark and cd.tidyGCD
    cd.tidyEdging = true
    cd:SetDrawEdge(spark or cd.tidyLibEdge or false)
    cd.tidyEdging = nil
    -- the spark's color (white keeps the library's edge as it is)
    local sc = spark and B.buttons.gcdSparkColor
    if cd.SetEdgeColor then
        if sc then cd:SetEdgeColor(sc.r, sc.g, sc.b, sc.a or 1) else cd:SetEdgeColor(1, 1, 1, 1) end
    elseif sc then
        pcall(cd.SetEdgeTexture, cd, "Interface\\Cooldown\\edge", sc.r, sc.g, sc.b, sc.a or 1)
    end
end

-- The edge the library asks for, kept to give it back after the spark
local function KeepLibEdge(cd, on)
    if not cd.tidyEdging then cd.tidyLibEdge = on and true or false end
end

-- Not usable: the library greys the icon with a fixed 0.4; Tidy's color
-- goes over it
local function TintUnusable(icon, r, g, bl)
    if icon.tidyTinting or not B then return end
    if r == 0.4 and g == 0.4 and bl == 0.4 then
        local c = B.buttons.unusableColor
        icon.tidyTinting = true
        icon:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        icon.tidyTinting = nil
    end
end

-- Pressed on cooldown / on the global cooldown / while not usable: a short
-- flash of a color. "cd": a real cooldown, "gcd": only the global one.
local function OnCooldown(b)
    local info = CooldownInfo(b)
    if not info or not Readable(info.isActive) or not info.isActive then return false end
    local only = OnlyGCD(b)
    if only ~= nil then return only and "gcd" or "cd" end
    local gcd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(61304)
    if gcd and Readable(gcd.isActive) and gcd.isActive then return "gcd" end
    return "cd"
end

-- out of range, not enough power or not usable now
local function CannotUse(b)
    if b.outOfRange then return true end
    local ok, usable = pcall(b.IsUsable, b)
    return ok and Readable(usable) and not usable
end

-- Every flash: its on/off setting and its color
local FLASH_COLOR = { cdPress = "cdPressColor", gcdPress = "gcdPressColor", failPress = "failPressColor",
    emptyPress = "emptyPressColor", interruptFlash = "interruptColor", readyFlash = "readyColor" }

-- key: a FLASH_COLOR key. mark: false for flashes that are not a press
-- answer (ready). A press answer whose flash is off still counts as
-- answered, so the game's error does not flash another color instead.
local function Flash(b, key, mark)
    local G = B and B.buttons
    if not G then return end
    if mark ~= false then b.tidyAnswered = true end -- this press has its answer
    local c = G[key] and G[FLASH_COLOR[key]]
    if not c or (c.a or 1) <= 0 then return end
    local t = b.tidyPressFlash
    if not t then
        t = b:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetAllPoints(b)
        t:SetAlpha(0)
        local ag = t:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0)
        a:SetDuration(0.35)
        a:SetSmoothing("OUT")
        t.anim = ag
        b.tidyPressFlash = t
    end
    t:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    t.anim:Stop()
    t.anim:Play()
end

-- Any other reason (no target, wrong target, facing, moving...): the game's
-- red error right after a press flashes that button. Not while only the
-- global cooldown runs (pressing during it gives "not ready yet").
local ERROR_WINDOW = 0.4
local lastPress, lastPressT
local function GCDRunning()
    local gcd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(61304)
    return gcd and Readable(gcd.isActive) and gcd.isActive or false
end
local errorWatch = CreateFrame("Frame")
errorWatch:RegisterEvent("UI_ERROR_MESSAGE")
errorWatch:SetScript("OnEvent", function()
    local b = lastPress
    if not b or not B or GetTime() - lastPressT > ERROR_WINDOW then return end
    lastPress = nil
    if b.tidyAnswered or GCDRunning() then return end
    Flash(b, "failPress")
end)

-- A key on an empty slot: the button is there but invisible (alpha 0 when
-- empty buttons are not shown), so the flash lives on its own frame over it
local function FlashEmpty(b)
    if not B.buttons.emptyPress then return end
    local c = B.buttons.emptyPressColor
    if not c or (c.a or 1) <= 0 or not b:IsVisible() then return end
    local f = b.tidyEmptyFlash
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints(b)
        f:EnableMouse(false)
        f:SetAlpha(0)
        f.tex = f:CreateTexture(nil, "OVERLAY")
        f.tex:SetAllPoints()
        local ag = f:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0)
        a:SetDuration(0.35)
        a:SetSmoothing("OUT")
        f.anim = ag
        b.tidyEmptyFlash = f
    end
    f:SetFrameStrata(b:GetFrameStrata())
    f:SetFrameLevel(b:GetFrameLevel() + 10)
    f.tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
    f.anim:Stop()
    f.anim:Play()
end

local function PressFeedback(b, key)
    local ok, has = pcall(b.HasAction, b)
    if not ok then return end
    if not has then
        if key then FlashEmpty(b) end
        return
    end
    local cd = OnCooldown(b)
    if cd == "cd" then
        Flash(b, "cdPress")
    elseif cd == "gcd" then
        Flash(b, "gcdPress")
    elseif CannotUse(b) then
        Flash(b, "failPress")
    end
end

-------------------------------------------------------------------------------
-- Cast animation, flat style: the buttons of the spell being cast fill from
-- left to right as the cast goes (a channel empties), and flash on interrupt.
-- The fill follows the best the game gives: plain times (usually your own
-- casts), else the game's duration object (StatusBar:SetTimerDuration), else
-- it is shown full. The Blizzard style is LibActionButton's own.
-------------------------------------------------------------------------------
local function FlatCast()
    return B and B.buttons.castVFX and B.buttons.castStyle == "flat"
end

-- the cast going on: drain (channel), mode (manual / timer / static), times
local cast = {}

local function CastFill(b, on)
    local f = b.tidyCastFill
    if not on then
        if f then f:Hide() end
        b.tidyCastSpell = nil
        return
    end
    if not f then
        f = CreateFrame("StatusBar", nil, b)
        f:SetAllPoints(b)
        f:EnableMouse(false)
        f:SetOrientation("HORIZONTAL")
        f:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        -- a bright line on the moving edge
        f.edge = f:CreateTexture(nil, "OVERLAY")
        f.edge:SetPoint("TOPRIGHT", f:GetStatusBarTexture(), "TOPRIGHT")
        f.edge:SetPoint("BOTTOMRIGHT", f:GetStatusBarTexture(), "BOTTOMRIGHT")
        f.edge:SetWidth(2)
        b.tidyCastFill = f
    end
    local c = B.buttons.castFillColor
    f:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    f.edge:SetColorTexture(c.r, c.g, c.b, 1)
    f:SetFrameLevel(b:GetFrameLevel() + 5)
    f:Show()
end

-- puts one fill where the cast is now
local function PlaceFill(f)
    if cast.mode == "manual" then
        f:SetMinMaxValues(0, cast.finish - cast.start)
        local now = math.min(GetTime(), cast.finish)
        f:SetValue(cast.drain and (cast.finish - now) or (now - cast.start))
    elseif cast.mode == "timer" then
        local ok = pcall(function()
            local d = (cast.channelInfo and UnitChannelDuration or UnitCastingDuration)("player")
            local E = Enum.StatusBarTimerDirection
            f:SetTimerDuration(d, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0,
                cast.drain and E.RemainingTime or E.ElapsedTime)
        end)
        if not ok then f:SetMinMaxValues(0, 1) f:SetValue(1) end
    else
        f:SetMinMaxValues(0, 1)
        f:SetValue(1)
    end
end

-- reads the cast's times (a new cast, or pushed back)
local function ReadCast()
    local _, _, _, startMs, endMs = (cast.channelInfo and UnitChannelInfo or UnitCastingInfo)("player")
    if Readable(startMs) and Readable(endMs) and startMs and endMs and endMs > startMs then
        cast.mode, cast.start, cast.finish = "manual", startMs / 1000, endMs / 1000
    elseif (cast.channelInfo and UnitChannelDuration or UnitCastingDuration) and Enum.StatusBarTimerDirection then
        cast.mode = "timer"
    else
        cast.mode = "static"
    end
end

local function SpellOf(b)
    local ok, id = pcall(b.GetSpellId, b)
    if ok and Readable(id) then return id end
end

local function ForTidyButtons(fn)
    for _, h in pairs(bars) do
        if h.buttons then
            for _, b in ipairs(h.buttons) do fn(b) end
        end
    end
end

local function ForLit(fn)
    ForTidyButtons(function(b)
        if b.tidyCastSpell and b.tidyCastFill then fn(b) end
    end)
end

local castWatch = CreateFrame("Frame")

-- only the manual mode is moved by Tidy; the timer one moves by itself
local function CastOnUpdate()
    ForLit(function(b) PlaceFill(b.tidyCastFill) end)
end

-- the player casts one spell at a time: a stop or an interrupt ends them all
local castSpell, castEndT -- last spell cast with a cast time, when it stopped
local function CastStart(spellID, channelInfo, drain)
    if not Readable(spellID) or not spellID then return end
    castSpell, castEndT = spellID, nil
    if not FlatCast() then return end
    cast.channelInfo, cast.drain = channelInfo, drain
    ReadCast()
    ForTidyButtons(function(b)
        if b:IsVisible() and SpellOf(b) == spellID then
            CastFill(b, true)
            b.tidyCastSpell = spellID
            PlaceFill(b.tidyCastFill)
        end
    end)
    castWatch:SetScript("OnUpdate", cast.mode == "manual" and CastOnUpdate or nil)
end

-- pushback / a channel made longer
local function CastUpdate()
    if not castSpell or castEndT or not FlatCast() then return end
    ReadCast()
    ForLit(function(b) PlaceFill(b.tidyCastFill) end)
    castWatch:SetScript("OnUpdate", cast.mode == "manual" and CastOnUpdate or nil)
end

local function CastEnd()
    castEndT = castEndT or GetTime()
    castWatch:SetScript("OnUpdate", nil)
    ForTidyButtons(function(b)
        if b.tidyCastSpell then CastFill(b, false) end
    end)
end

-- the interrupt can come just before or just after the stop: it flashes the
-- buttons of the spell that was being cast
local function CastInterrupted(spellID)
    local recent = castSpell and (not castEndT or GetTime() - castEndT < 0.5)
    CastEnd()
    if not recent or not FlatCast() or not Readable(spellID) or spellID ~= castSpell then return end
    castSpell = nil -- once
    ForTidyButtons(function(b)
        if b:IsVisible() and SpellOf(b) == spellID then Flash(b, "interruptFlash") end
    end)
end

for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_UPDATE" }) do
    pcall(castWatch.RegisterUnitEvent, castWatch, e, "player") -- empower: not on every client
end
castWatch:SetScript("OnEvent", function(_, event, _, _, spellID, complete)
    if event == "UNIT_SPELLCAST_START" then
        CastStart(spellID, false, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        CastStart(spellID, true, true)
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        CastStart(spellID, true, false) -- empowering fills up
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        CastUpdate()
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or (event == "UNIT_SPELLCAST_EMPOWER_STOP" and not complete) then
        CastInterrupted(spellID)
    else
        CastEnd()
    end
end)

-- the page changed during a cast: the fill leaves a slot that now holds
-- another spell
local castKey = {}
LAB.RegisterCallback(castKey, "OnButtonUpdate", function(_, b)
    if b.tidyCastSpell and SpellOf(b) ~= b.tidyCastSpell then CastFill(b, false) end
end)

-------------------------------------------------------------------------------
-- Ready flash: a button whose real cooldown (not the global one) has just
-- ended flashes once. The times are secret: only the "active" flag is read,
-- on the cooldown events and every 0.1 s while a cooldown runs (the game
-- does not always send an event when one ends).
-------------------------------------------------------------------------------
local READY_MIN = 2 -- shorter cooldowns do not flash (seconds)
local readyWatch = CreateFrame("Frame")
local readyTicker

local function ReadyCheck()
    local tracking = false
    ForTidyButtons(function(b)
        local spell = b:IsVisible() and SpellOf(b)
        local state = spell and OnCooldown(b)
        if b.tidyCDSpell and b.tidyCDSpell ~= spell then
            b.tidyCDSpell = nil -- another spell in the slot (page, drag): no flash
        end
        if state == "cd" then
            if not b.tidyCDSpell then b.tidyCDSpell, b.tidyCDStart = spell, GetTime() end
            tracking = true
        elseif state == "gcd" and b.tidyCDSpell then
            -- unsure: the game may only say "global cooldown" while both run
            tracking = true
        elseif b.tidyCDSpell then
            if GetTime() - b.tidyCDStart >= READY_MIN and B and B.buttons.readyFlash then
                Flash(b, "readyFlash", false)
            end
            b.tidyCDSpell = nil
        end
    end)
    if tracking and not readyTicker then
        readyTicker = C_Timer.NewTicker(0.1, ReadyCheck)
    elseif not tracking and readyTicker then
        readyTicker:Cancel()
        readyTicker = nil
    end
end

for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES" }) do
    pcall(readyWatch.RegisterEvent, readyWatch, e)
end
readyWatch:SetScript("OnEvent", function() ReadyCheck() end)

-- A key held on the button: the pressed look until it is released (at most
-- KEY_HOLD seconds: a release can go to another binding if a modifier
-- changed meanwhile)
local KEY_HOLD = 1
local function KeyPressed(b, on)
    b.tidyKeyToken = (b.tidyKeyToken or 0) + 1
    if ns.ShowPressed then ns.ShowPressed(b, on) end
    if on then
        local token = b.tidyKeyToken
        C_Timer.After(KEY_HOLD, function()
            if b.tidyKeyToken == token then KeyPressed(b, false) end
        end)
    end
end

-- PreClick: before the cast (after it the spell is on cooldown). Clicks come
-- on press and on release: the release after a press gives no feedback.
-- Keys click with "Keybind" (keyBoundClickButton).
local function OnPreClick(self, mouse, down)
    local key = mouse == "Keybind"
    -- the cast happens on press or on release (game setting, mouse drag
    -- protection): both count for the game's error
    lastPress, lastPressT = self, GetTime()
    if down ~= false or not self.tidyDownSeen then
        self.tidyAnswered = nil -- a new press
    end
    if down == false then
        if key then KeyPressed(self, false) end
        if self.tidyDownSeen then
            self.tidyDownSeen = nil
            return
        end
    elseif down then
        if key then KeyPressed(self, true) end
        self.tidyDownSeen = true
    end
    PressFeedback(self, key)
end

local function CreateButton(header, id, i)
    local b = LAB:CreateButton((id - 1) * 12 + i, "TidyBar" .. id .. "Button" .. i, header)
    b.tidyCommand = COMMANDS[id] and (COMMANDS[id] .. i) -- Blizzard binding it uses
    b.GetHotkey = GetHotkey
    b:HookScript("PreClick", OnPreClick)
    if b.icon then hooksecurefunc(b.icon, "SetVertexColor", TintUnusable) end
    if b.cooldown then
        hooksecurefunc(b.cooldown, "SetSwipeColor", CapSwipe)
        -- no edge until the library asks for one (loss of control): the
        -- template draws it by default, and with duration objects the
        -- library never turns it off
        b.cooldown.tidyLibEdge = false
        hooksecurefunc(b.cooldown, "SetDrawEdge", KeepLibEdge)
        hooksecurefunc(b.cooldown, "SetHideCountdownNumbers", KeepCountdown)
        for _, m in ipairs({ "SetCooldown", "SetCooldownFromDurationObject", "SetCooldownDuration" }) do
            if b.cooldown[m] then hooksecurefunc(b.cooldown, m, function() ApplySwipe(b) end) end
        end
        CapSwipe(b.cooldown, 0, 0, 0, 1)
    end
    for page = 1, PageCount() do b:SetState(page, "action", (page - 1) * 12 + i) end
    b:SetState(0, "action", (id - 1) * 12 + i)
    return b
end

-------------------------------------------------------------------------------
-- Bars
-------------------------------------------------------------------------------
local function SavePosition(h)
    local s = h:GetScale()
    local c = ns.BarConfig(h.id)
    c.pos = { point = "BOTTOMLEFT", x = h:GetLeft() * s, y = h:GetTop() * s }
end

local function Place(h, c)
    local s = c.scale
    h:SetScale(s)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", UIParent, c.pos.point, c.pos.x / s, c.pos.y / s)
end

-- Grid of buttons: rows x columns, from the top left
local function Layout(h, c)
    local n = math.max(1, math.min(12, c.buttons))
    local rows = math.max(1, math.min(n, c.rows))
    local cols = math.ceil(n / rows)
    local pad = c.padding
    local bw, bh = c.buttonWidth or BUTTON, c.buttonHeight or BUTTON
    local zoom = IconZoom()
    for i, b in ipairs(h.buttons) do
        b:ClearAllPoints()
        if i <= n then
            local r, col = math.floor((i - 1) / cols), (i - 1) % cols
            if c.growH == "LEFT" then col = cols - 1 - col end
            if c.growV == "UP" then r = rows - 1 - r end
            b:SetPoint("TOPLEFT", h, "TOPLEFT", col * (bw + pad), -r * (bh + pad))
            b:SetSize(bw, bh)
            b.tidyFit = { w = bw, h = bh, mode = c.iconFit or "cover" }
            -- a button hidden before (fewer buttons) comes back; if it is
            -- empty and empty buttons are not shown, LibActionButton hides it
            -- again just below (UpdateConfig)
            b:SetAttribute("statehidden", nil)
            b:Show()
            b:EnableMouse(not c.clickThrough)
            ButtonAttributes(b)
            b:UpdateConfig(ButtonConfig(b, c))
            ApplySwipe(b)
            StyleCountdown(b)
            if not FlatCast() then CastFill(b, false) end
            -- texts turned off for every bar (the per-bar hides are in the
            -- config); by alpha, as LibActionButton shows and hides them itself
            local T = B.buttons.texts
            if b.HotKey then b.HotKey:SetAlpha(T.hotkey.show and 1 or 0) end
            if b.Count then b.Count:SetAlpha(T.count.show and 1 or 0) end
            if b.Name then b.Name:SetAlpha(T.macro.show and 1 or 0) end
            ns.FitIcon(b, zoom)
        else
            b:SetAttribute("statehidden", true)
            b:Hide()
        end
    end
    h:SetSize(cols * bw + (cols - 1) * pad, rows * bh + (rows - 1) * pad)
    h.mover:SetShown(not B.locked and c.enabled)
end

-------------------------------------------------------------------------------
-- Dragging with snap: the bar sticks to the edges and centers of the other
-- bars, to the screen center lines and to the screen borders. All the math
-- is in UIParent units; a guide line shows what it snapped to.
-------------------------------------------------------------------------------
local SNAP = 10 -- distance (UIParent units) that pulls the bar

-- Guide lines while dragging: every snap line is shown faint, the one the
-- bar is stuck to is bright. Textures are reused between drags.
local guideFrame
local guideLines = { v = {}, h = {} } -- vertical / horizontal, [i] = { tex, pos }
local FAINT, MID, BRIGHT = 0.18, 0.4, 0.95 -- other lines / screen middle / stuck to

local function GuideLine(kind, i)
    if not guideFrame then
        guideFrame = CreateFrame("Frame", nil, UIParent)
        guideFrame:SetAllPoints()
        guideFrame:SetFrameStrata("TOOLTIP")
    end
    local list = guideLines[kind]
    local l = list[i]
    if not l then
        l = { tex = guideFrame:CreateTexture(nil, "OVERLAY") }
        list[i] = l
    end
    return l
end

-- Places the lines at the given positions (UIParent units), hidden
local function ShowGuides(tx, ty)
    -- the screen's own middle (as rounded in SnapTargets)
    local mid = { v = math.floor(UIParent:GetWidth() / 2 + 0.5), h = math.floor(UIParent:GetHeight() / 2 + 0.5) }
    for kind, positions in pairs({ v = tx, h = ty }) do
        for i, pos in ipairs(positions) do
            local l = GuideLine(kind, i)
            local t = l.tex
            l.pos = pos
            l.center = pos == mid[kind]
            local size = l.center and 3 or 1
            t:ClearAllPoints()
            if kind == "v" then
                t:SetWidth(size)
                t:SetPoint("TOP", UIParent, "TOPLEFT", pos, 0)
                t:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", pos, 0)
            else
                t:SetHeight(size)
                t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, pos)
                t:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, pos)
            end
            t:SetColorTexture(0.44, 0.76, 1, l.center and MID or FAINT)
            -- hidden until the bar comes near it (LightGuides); the
            -- screen's middle lines show the whole drag
            t:SetShown(l.center)
        end
        for i = #positions + 1, #guideLines[kind] do guideLines[kind][i].tex:Hide() end
    end
end

local function HideGuides()
    for _, list in pairs(guideLines) do
        for _, l in ipairs(list) do l.tex:Hide() end
    end
end

-- Only the lines near the moving bar are drawn (the rest of the screen stays
-- clean): faint when an edge or the center is within NEAR, bright for the
-- one it is stuck to. edges: positions of the bar's edges and center.
local NEAR = 60
local function LightGuides(kind, pos, edges, count)
    local list = guideLines[kind]
    for i = 1, count do
        local l = list[i]
        local near = false
        for _, e in ipairs(edges) do
            if math.abs(l.pos - e) <= NEAR then near = true break end
        end
        local stuck = pos and l.pos == pos
        local show = near or stuck or l.center
        l.tex:SetShown(show)
        if show then l.tex:SetColorTexture(0.44, 0.76, 1, stuck and BRIGHT or (l.center and MID or FAINT)) end
    end
end

-- Edges of a bar in UIParent units: left, right, top, bottom
local function Box(h)
    local s = h:GetScale()
    local l, b, w, ht = h:GetRect()
    if not l then return end
    return l * s, (l + w) * s, (b + ht) * s, b * s
end

-- Best target for any of the moving edges; returns the shift and the line
local function Snap(edges, targets)
    local best, line
    for _, e in ipairs(edges) do
        for _, t in ipairs(targets) do
            local d = t - e
            if math.abs(d) <= SNAP and (not best or math.abs(d) < math.abs(best)) then
                best, line = d, t
            end
        end
    end
    return best or 0, line
end

-- Snap lines for a drag (the other bars do not move meanwhile): screen
-- borders and center lines, and the edges and centers of the other bars.
-- Rounded and without repeats, so a shared line is drawn once.
local function SnapTargets(h)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local tx, ty, seenX, seenY = {}, {}, {}, {}
    local function AddX(v) v = math.floor(v + 0.5) if not seenX[v] then seenX[v] = true tx[#tx + 1] = v end end
    local function AddY(v) v = math.floor(v + 0.5) if not seenY[v] then seenY[v] = true ty[#ty + 1] = v end end
    AddX(0) AddX(sw / 2) AddX(sw)
    AddY(0) AddY(sh / 2) AddY(sh)
    for id, other in pairs(bars) do
        if other ~= h and other:IsShown() and ns.BarConfig(id).enabled then
            local l, r, t, b = Box(other)
            if l then
                AddX(l) AddX(r) AddX((l + r) / 2)
                AddY(t) AddY(b) AddY((t + b) / 2)
            end
        end
    end
    return tx, ty
end

local function DragUpdate(h)
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local s = h:GetScale()
    local w, ht = h:GetWidth() * s, h:GetHeight() * s
    local left, top = cx - h.grabX, cy - h.grabY
    local lineX, lineY
    if h.tx then
        local dx, dy
        dx, lineX = Snap({ left, left + w, left + w / 2 }, h.tx)
        dy, lineY = Snap({ top, top - ht, top - ht / 2 }, h.ty)
        left, top = left + dx, top + dy
    end
    -- always inside the screen
    left = math.max(0, math.min(sw - w, left))
    top = math.max(ht, math.min(sh, top))
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
    if h.tx then
        LightGuides("v", lineX, { left, left + w, left + w / 2 }, #h.tx)
        LightGuides("h", lineY, { top, top - ht, top - ht / 2 }, #h.ty)
    end
end

local function StopDrag(h)
    h.mover:SetScript("OnUpdate", nil)
    h.tx, h.ty = nil, nil
    HideGuides()
    SavePosition(h)
    Place(h, ns.BarConfig(h.id))
    if ns.OnBarMoved then ns.OnBarMoved() end
end

-- Overlay to drag the bar while unlocked
local function CreateMover(h)
    local m = CreateFrame("Frame", nil, h, "BackdropTemplate")
    m:SetAllPoints()
    m:SetFrameStrata("HIGH")
    m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    m:SetBackdropColor(0.44, 0.76, 1, 0.25)
    m:SetBackdropBorderColor(0.44, 0.76, 1, 0.9)
    -- the name sits just above the box (never inside: it would overflow small
    -- bars and hide the buttons), on a small dark tag; the box is the bar
    local tag = m:CreateTexture(nil, "BACKGROUND")
    tag:SetColorTexture(0.06, 0.06, 0.08, 0.85)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.text:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 3, 3)
    m.text:SetText(h.label or (L["Bar %d"]):format(h.id))
    tag:SetPoint("TOPLEFT", m.text, "TOPLEFT", -3, 2)
    tag:SetPoint("BOTTOMRIGHT", m.text, "BOTTOMRIGHT", 3, -2)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        -- where the cursor holds the bar, from its top left corner
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local l, _, t = Box(h)
        h.grabX, h.grabY = cx / scale - l, cy / scale - t
        if B.snap then
            h.tx, h.ty = SnapTargets(h)
            ShowGuides(h.tx, h.ty)
        end
        m:SetScript("OnUpdate", function()
            if InCombatLockdown() then StopDrag(h) return end
            DragUpdate(h)
        end)
    end)
    m:SetScript("OnDragStop", function()
        if m:GetScript("OnUpdate") then StopDrag(h) end
        h.dragged = true
    end)
    -- a click (not a drag) selects the bar in the options
    m:SetScript("OnMouseDown", function() h.dragged = nil end)
    m:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and not h.dragged and ns.SelectBar then ns.SelectBar(h.id) end
    end)
    -- the name tag works like the box: drag moves the bar, click selects it
    local grip = CreateFrame("Frame", nil, m)
    grip:SetPoint("TOPLEFT", tag, "TOPLEFT")
    grip:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT")
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    for _, event in ipairs({ "OnDragStart", "OnDragStop", "OnMouseDown", "OnMouseUp" }) do
        grip:SetScript(event, function(_, ...) m:GetScript(event)(m, ...) end)
    end
    -- nudge arrows beside the name, only on the selected bar: 0.5 per click
    -- (Shift: 5), for what a drag cannot place exactly
    local pad = CreateFrame("Frame", nil, m)
    pad:SetSize(4 * 14 + 3, 14)
    pad:SetPoint("LEFT", tag, "RIGHT", 2, 0)
    -- { dx, dy, chevron line 1, chevron line 2 } (lines from the button center)
    local CHEVRONS = {
        { -1, 0, { 1.5, -3, -1.5, 0 }, { 1.5, 3, -1.5, 0 } },    -- left
        { 0, 1, { -3, -1.5, 0, 1.5 }, { 3, -1.5, 0, 1.5 } },     -- up
        { 0, -1, { -3, 1.5, 0, -1.5 }, { 3, 1.5, 0, -1.5 } },    -- down
        { 1, 0, { -1.5, -3, 1.5, 0 }, { -1.5, 3, 1.5, 0 } },     -- right
    }
    for i, d in ipairs(CHEVRONS) do
        local b = CreateFrame("Button", nil, pad)
        b:SetSize(14, 14)
        b:SetPoint("LEFT", (i - 1) * 15, 0)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.06, 0.08, 0.85)
        for k = 3, 4 do
            local p = d[k]
            local line = b:CreateLine(nil, "OVERLAY")
            line:SetThickness(2)
            line:SetColorTexture(0.44, 0.76, 1, 1)
            line:SetStartPoint("CENTER", b, p[1], p[2])
            line:SetEndPoint("CENTER", b, p[3], p[4])
        end
        b:SetScript("OnEnter", function(self)
            bg:SetColorTexture(0.18, 0.18, 0.22, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Move 0.5 px. Shift-click: 5 px."], 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            bg:SetColorTexture(0.06, 0.06, 0.08, 0.85)
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local step = IsShiftKeyDown() and 5 or 0.5
            local x, y = ns.BarXY(h.id)
            ns.SetBarXY(h.id, x + d[1] * step, y + d[2] * step)
            if ns.OnBarMoved then ns.OnBarMoved() end
        end)
    end
    pad:SetShown(ns.selectedBar == h.id)
    m.nudge = pad
    m:Hide()
    h.mover = m
end

local function CreateBar(id)
    local h = CreateFrame("Frame", "TidyBar" .. id, UIParent, "SecureHandlerStateTemplate")
    h.id = id
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    h:SetAttribute("_onstate-page", ON_PAGE)
    h.kind = "action"
    h.buttons = {}
    for i = 1, 12 do h.buttons[i] = CreateButton(h, id, i) end
    CreateMover(h)
    bars[id] = h
    return h
end

-- shared with Holders.lua (same moving, snapping and placing)
ns.CreateMover, ns.PlaceBar, ns.SaveBarPosition = CreateMover, Place, SavePosition

-- Applies the settings of one bar (out of combat)
function ns.ApplyBar(id)
    if type(id) == "string" then return ns.ApplyHolder(id) end
    ns.RunOOC("bar" .. id, function()
        local c = ns.BarConfig(id)
        local h = bars[id]
        if not c.enabled then
            if h then
                UnregisterStateDriver(h, "page")
                UnregisterStateDriver(h, "visibility")
                ns.SetFade(h, c)
                h:Hide()
            end
            return
        end
        h = h or CreateBar(id)
        Place(h, c)
        h:SetAlpha(c.alpha)
        Layout(h, c)
        RegisterStateDriver(h, "page", PageDriver(id, c))
        -- unlocked: always visible, to move it
        RegisterStateDriver(h, "visibility", B.locked and ns.VisibilityDriver(c) or "show")
        ns.SetFade(h, c)
        if id == 1 then ns.UpdateGryphons(h) end
    end)
end

-------------------------------------------------------------------------------
-- Gryphons (wyverns for the Horde) at the sides of bar 1, Blizzard's art
-------------------------------------------------------------------------------
function ns.UpdateGryphons(h)
    h = h or bars[1]
    if not h then return end
    if not h.art then
        h.art = CreateFrame("Frame", nil, h)
        h.art:SetAllPoints()
        h.art:SetFrameLevel(math.max(0, h:GetFrameLevel() + 6))
        h.art.left = h.art:CreateTexture(nil, "OVERLAY")
        h.art.right = h.art:CreateTexture(nil, "OVERLAY")
    end
    local horde = UnitFactionGroup("player") == "Horde"
    local kind = horde and "wyvern" or "gryphon"
    local a = h.art
    a.left:SetAtlas("ui-hud-actionbar-" .. kind .. "-left", false)
    a.right:SetAtlas("ui-hud-actionbar-" .. kind .. "-right", false)
    a.left:SetSize(100, 62)
    a.right:SetSize(100, 62)
    a.left:ClearAllPoints()
    a.left:SetPoint("BOTTOMRIGHT", h, "BOTTOMLEFT", 22, -8)
    a.right:ClearAllPoints()
    a.right:SetPoint("BOTTOMLEFT", h, "BOTTOMRIGHT", -22, -8)
    a:SetShown(B.gryphons and true or false)
end

function ns.ApplyBars()
    -- mouse-over casting needs the game setting too (it is per account)
    if B.casting.mouseover then SetCVar("enableMouseoverCast", "1") end
    for _, id in ipairs(BAR_IDS) do ns.ApplyBar(id) end
    for _, id in ipairs(ns.HOLDER_IDS) do ns.ApplyHolder(id) end
    ns.UpdateBinds()
    -- new buttons get the square look if it is on
    if ns.RefreshIcons then ns.RefreshIcons() end
end

-- The bar selected in the options stands out while unlocked
function ns.HighlightBar(id)
    ns.selectedBar = id
    for bid, h in pairs(bars) do
        local on = bid == id
        h.mover.nudge:SetShown(on)
        h.mover:SetBackdropColor(0.44, 0.76, 1, on and 0.55 or 0.25)
        h.mover:SetBackdropBorderColor(on and 1 or 0.44, on and 1 or 0.76, 1, on and 1 or 0.9)
    end
end

function ns.SetBarsLocked(locked)
    B.locked = locked
    for id, h in pairs(bars) do
        -- the name in the language in use
        h.mover.text:SetText(h.kind == "holder" and ns.HolderName(id) or (L["Bar %d"]):format(id))
        h.mover:SetShown(not locked and ns.BarConfig(id).enabled)
    end
    -- hidden bars show while unlocked (visibility drivers), and back after
    if ns.barsActive then
        for _, id in ipairs(BAR_IDS) do ns.ApplyBar(id) end
        for _, id in ipairs(ns.HOLDER_IDS) do ns.ApplyHolder(id) end
    end
    if ns.OnBarsLocked then ns.OnBarsLocked() end
end

-------------------------------------------------------------------------------
-- Exact position: X / Y of the top left corner from the bottom left of the
-- screen (UIParent units)
-------------------------------------------------------------------------------
-- rounded to half units (fractional offsets are valid)
local function Half(v) return math.floor(v * 2 + 0.5) / 2 end

function ns.BarXY(id)
    local h = bars[id]
    if h and h:GetLeft() then
        local s = h:GetScale()
        return Half(h:GetLeft() * s), Half(h:GetTop() * s)
    end
    local p = ns.BarConfig(id).pos
    if p and p.point == "BOTTOMLEFT" then return Half(p.x), Half(p.y) end
    return 0, 0
end

function ns.SetBarXY(id, x, y)
    local c = ns.BarConfig(id)
    local cx, cy = ns.BarXY(id)
    c.pos = { point = "BOTTOMLEFT", x = x or cx, y = y or cy }
    ns.ApplyBar(id)
end

-- Centers the bar on the screen, horizontally or vertically
function ns.CenterBar(id, axis)
    local h = bars[id]
    if not h or not h:GetLeft() then return end
    local s = h:GetScale()
    local w, ht = h:GetWidth() * s, h:GetHeight() * s
    if axis == "x" then
        ns.SetBarXY(id, math.floor((UIParent:GetWidth() - w) / 2 + 0.5), nil)
    else
        ns.SetBarXY(id, nil, math.floor((UIParent:GetHeight() + ht) / 2 + 0.5))
    end
end

-------------------------------------------------------------------------------
-- Presets: one click layouts for the action bars (positions and rows)
-------------------------------------------------------------------------------
local PRESETS = {
    -- Blizzard-like: three bars at the bottom, two at the right
    blizzard = {
        [1] = { true, 1, Pos("BOTTOM", -281, 60) }, [6] = { true, 1, Pos("BOTTOM", -281, 108) },
        [5] = { true, 1, Pos("BOTTOM", -281, 156) }, [3] = { true, 12, Pos("RIGHT", -50, 270) },
        [4] = { true, 12, Pos("RIGHT", -97, 270) },
    },
    -- Compact: three bars at the bottom center, nothing at the sides
    compact = {
        [1] = { true, 1, Pos("BOTTOM", -281, 40) }, [6] = { true, 1, Pos("BOTTOM", -281, 88) },
        [5] = { true, 1, Pos("BOTTOM", -281, 136) }, [3] = { false }, [4] = { false },
    },
    -- Two blocks of 6x2 at each side of the bottom center
    split = {
        [1] = { true, 2, Pos("BOTTOM", -290, 108) }, [6] = { true, 2, Pos("BOTTOM", 10, 108) },
        [5] = { true, 1, Pos("BOTTOM", -281, 156) }, [3] = { false }, [4] = { false },
    },
}

function ns.ApplyPreset(name)
    local p = PRESETS[name]
    if not p then return end
    for _, id in ipairs(BAR_IDS) do
        local c = ns.BarConfig(id)
        local d = p[id]
        if d then
            c.enabled = d[1]
            if d[1] then
                c.buttons, c.rows, c.padding, c.scale = 12, d[2], 2, 1
                c.pos = ns.Copy(d[3])
            end
        elseif id ~= 1 then
            c.enabled = false
        end
    end
    if ns.barsActive then ns.ApplyBars() end
end

-------------------------------------------------------------------------------
-- Keybinds: the keys of Blizzard's bindings click these buttons
-------------------------------------------------------------------------------
local bindOwner = CreateFrame("Frame")
function ns.UpdateBinds()
    ns.RunOOC("binds", function()
        ClearOverrideBindings(bindOwner)
        for id, h in pairs(bars) do
            if h.kind == "action" and ns.BarConfig(id).enabled then
                for _, b in ipairs(h.buttons) do
                    if b.tidyCommand then
                        -- "Keybind": LibActionButton's click for keys (cast
                        -- on key down / up as the game setting says)
                        for _, key in ipairs({ GetBindingKey(b.tidyCommand) }) do
                            SetOverrideBindingClick(bindOwner, false, key, b:GetName(), "Keybind")
                        end
                    end
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Start
-------------------------------------------------------------------------------
-- Other action bar addons: with one loaded, Tidy's bars stay off (both
-- would take the same keybinds)
local OTHER_BARS = { "Bartender4", "Dominos" }
local function OtherBarAddon()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    for _, name in ipairs(OTHER_BARS) do
        if loaded(name) then return name end
    end
end

-- Turns Tidy's bars on or off while playing (out of combat)
function ns.SetBarsActive(on)
    ns.barsConflict = on and OtherBarAddon() or nil
    if ns.barsConflict then on = false end
    ns.RunOOC("barsActive", function()
        if on == (ns.barsActive or false) then return end
        ns.barsActive = on
        if on then
            HideBlizzard()
            ns.ApplyBars()
        else
            for _, h in pairs(bars) do
                if h.kind == "action" then
                    UnregisterStateDriver(h, "page")
                    UnregisterStateDriver(h, "visibility")
                    ns.SetFade(h, { fade = false, alpha = 1 })
                    h:Hide()
                    if h.art then h.art:Hide() end
                end
            end
            ns.ReleaseHolders()
            ClearOverrideBindings(bindOwner)
            ShowBlizzard()
        end
    end)
end

ns.Module(function()
    B = ns.P.bars
    ns.SetBarsActive(B.enabled)

    -- (empty buttons while dragging a spell: LibActionButton does it)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UPDATE_BINDINGS")
    ev:SetScript("OnEvent", function()
        if ns.barsActive then ns.UpdateBinds() end
    end)
end, function()
    -- another profile: its bars (on/off, layout, lock)
    B = ns.P.bars
    ns.SetBarsActive(B.enabled)
    -- already on: lay out the new profile's bars (the lock is in it too)
    if ns.barsActive then ns.ApplyBars() end
end)
