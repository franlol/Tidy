-------------------------------------------------------------------------------
-- Tidy - Action bars
-- The buttons come from LibActionButton-1.0 (icon, cooldown, range, charges,
-- secure clicks). Tidy only does:
--   * layout: buttons, rows, padding, scale, alpha, position
--   * paging: a state driver per bar (bar 1 follows stance/form, possess,
--     vehicle and override like Blizzard's main bar)
--   * keybinds: your Blizzard binds point to these buttons (override binds)
--   * hiding Blizzard's action bars
-- Bar N shows action page N (actions (N-1)*12+1 ... N*12), like Bartender.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local BUTTON = 45 -- size of a Blizzard action button
local BAR_IDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }
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

-- Blizzard bars Tidy does not replace yet: if they hang from the main bar,
-- move them to UIParent so hiding it does not take them along
local KEEP = { "MicroMenuContainer", "MicroMenu", "MicroButtonAndBagsBar", "BagsBar",
    "StatusTrackingBarManager", "StanceBar", "PetActionBar", "PossessActionBar",
    "MainMenuBarVehicleLeaveButton", "ExtraActionBarFrame", "ZoneAbilityFrame" }

-- Blizzard's buttons are never touched (attributes, methods): anything an
-- addon writes on them taints them, and this client then refuses them the
-- cooldown data ("secret values"). Being inside a hidden frame is enough:
-- they cannot be seen or clicked, and the keybinds go to Tidy's buttons.
local function ShowBlizzard()
    for f, parent in pairs(moved) do f:SetParent(parent) end
    wipe(moved)
end

local function HideBlizzard()
    for _, main in ipairs({ MainMenuBar, MainActionBar }) do
        for _, name in ipairs(KEEP) do
            local f = _G[name]
            if f and main and f:GetParent() == main then
                local points = {}
                for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
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
-- Bar 1: like Blizzard's main bar. Stances/forms use the bonus bars:
-- warrior battle/def/berserker 7/8/9, druid cat 7 (prowl 8), bear 9,
-- moonkin 10, rogue stealth 7, priest shadowform 7.
-- Order: possess/vehicle (bar 1), Ctrl/Alt/Shift pages, Shift+number
-- pages (bar 1), stance/form pages, the bar's own page.
local function PageDriver(id, c)
    local s = ""
    if id == 1 then s = "[overridebar][possessbar][vehicleui][shapeshift][bonusbar:5]possess;" end
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

-- secure: picks the real page for "possess" and tells the buttons
local ON_PAGE = [[
    if newstate == "possess" then
        if HasVehicleActionBar and HasVehicleActionBar() then newstate = GetVehicleBarIndex()
        elseif HasOverrideActionBar and HasOverrideActionBar() then newstate = GetOverrideBarIndex()
        elseif HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() then newstate = GetTempShapeshiftBarIndex()
        elseif HasBonusActionBar and HasBonusActionBar() then newstate = GetBonusBarIndex()
        else newstate = 12 end
    end
    newstate = tonumber(newstate) or 1
    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
]]

-------------------------------------------------------------------------------
-- Buttons: LibActionButton-1.0 (BSD), the engine Bartender uses. It works
-- with this client's protected cooldown data ("secret values"), which
-- Blizzard's own template does not allow from an addon.
-- Each button has one action per page ("state"): state N = page N.
-------------------------------------------------------------------------------
local LAB = LibStub("LibActionButton-1.0")
local PAGES = 18
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
        color = { t.color.r, t.color.g, t.color.b },
        position = { anchor = p, relAnchor = p, offsetX = t.x, offsetY = t.y },
        justifyH = p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"),
    }
end

-- Settings LibActionButton reads (anything missing: its defaults)
local function ButtonConfig(b, c)
    local G = B.buttons
    return {
        showGrid = c.showGrid,
        keyBoundTarget = b.tidyCommand or false,
        keyBoundClickButton = "Keybind",
        actionButtonUI = true,
        outOfRangeColoring = G.range,
        tooltip = G.tooltip,
        colors = {
            range = { G.rangeColor.r, G.rangeColor.g, G.rangeColor.b },
            mana = { G.manaColor.r, G.manaColor.g, G.manaColor.b },
        },
        hideElements = { macro = c.hideMacro, hotkey = c.hideHotkey, equipped = c.hideEquipped },
        flyoutDirection = c.flyout,
        spellCastVFX = G.castVFX,
        text = { hotkey = TextConfig(G.texts.hotkey), count = TextConfig(G.texts.count), macro = TextConfig(G.texts.macro) },
    }
end

-- Secure attributes: button lock and casting helpers (out of combat)
local function ButtonAttributes(b)
    local K = B.casting
    b:SetAttribute("buttonlock", B.buttons.lock or nil)
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
    local key = w .. ":" .. h .. ":" .. f.mode
    if b.tidyFitKey == key then return end
    b.tidyFitKey = key
    icon:ClearAllPoints()
    if f.mode == "contain" then
        local m = math.min(w, h)
        icon:SetSize(m, m)
        icon:SetPoint("CENTER", b, "CENTER")
    else
        icon:SetAllPoints(b)
    end
    for _, region in ipairs({ b.cooldown, b.chargeCooldown, b:GetHighlightTexture(), b:GetPushedTexture(),
        b:GetCheckedTexture(), b.Flash, b.NewActionTexture, b.Border }) do
        if region then
            pcall(region.ClearAllPoints, region)
            pcall(region.SetAllPoints, region, icon)
        end
    end
end

local function CreateButton(header, id, i)
    local b = LAB:CreateButton((id - 1) * 12 + i, "TidyBar" .. id .. "Button" .. i, header)
    b.tidyCommand = COMMANDS[id] and (COMMANDS[id] .. i) -- Blizzard binding it uses
    b.GetHotkey = GetHotkey
    for page = 1, PAGES do b:SetState(page, "action", (page - 1) * 12 + i) end
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
    local zoom = ns.P.icons.enabled and ns.P.icons.actionbars and ns.P.icons.zoom or 0
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
local FAINT, BRIGHT = 0.18, 0.95

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

-- Shows the lines at the given positions (UIParent units), all faint
local function ShowGuides(tx, ty)
    for kind, positions in pairs({ v = tx, h = ty }) do
        for i, pos in ipairs(positions) do
            local l = GuideLine(kind, i)
            local t = l.tex
            l.pos = pos
            t:ClearAllPoints()
            if kind == "v" then
                t:SetWidth(1)
                t:SetPoint("TOP", UIParent, "TOPLEFT", pos, 0)
                t:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", pos, 0)
            else
                t:SetHeight(1)
                t:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, pos)
                t:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, pos)
            end
            t:SetColorTexture(0.44, 0.76, 1, FAINT)
            t:Show()
        end
        for i = #positions + 1, #guideLines[kind] do guideLines[kind][i].tex:Hide() end
    end
end

local function HideGuides()
    for _, list in pairs(guideLines) do
        for _, l in ipairs(list) do l.tex:Hide() end
    end
end

-- The line at pos (if any) bright, the rest faint
local function LightGuides(kind, pos)
    for _, l in ipairs(guideLines[kind]) do
        if l.tex:IsShown() then
            l.tex:SetColorTexture(0.44, 0.76, 1, (pos and l.pos == pos) and BRIGHT or FAINT)
        end
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
        LightGuides("v", lineX)
        LightGuides("h", lineY)
    end
end

local function StopDrag(h)
    h.mover:SetScript("OnUpdate", nil)
    h.tx, h.ty = nil, nil
    HideGuides()
    SavePosition(h)
    Place(h, ns.BarConfig(h.id))
end

-- Overlay to drag the bar while unlocked
local function CreateMover(h)
    local m = CreateFrame("Frame", nil, h, "BackdropTemplate")
    m:SetAllPoints()
    m:SetFrameStrata("HIGH")
    m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    m:SetBackdropColor(0.44, 0.76, 1, 0.25)
    m:SetBackdropBorderColor(0.44, 0.76, 1, 0.9)
    m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m.text:SetPoint("CENTER")
    m.text:SetText(h.label or (L["Bar %d"]):format(h.id))
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
    for _, id in ipairs(BAR_IDS) do ns.ApplyBar(id) end
    for _, id in ipairs(ns.HOLDER_IDS) do ns.ApplyHolder(id) end
    ns.UpdateBinds()
    -- new buttons get the square look if it is on
    if ns.RefreshIcons then ns.RefreshIcons() end
end

-- The bar selected in the options stands out while unlocked
function ns.HighlightBar(id)
    for bid, h in pairs(bars) do
        local on = bid == id
        h.mover:SetBackdropColor(0.44, 0.76, 1, on and 0.55 or 0.25)
        h.mover:SetBackdropBorderColor(on and 1 or 0.44, on and 1 or 0.76, 1, on and 1 or 0.9)
    end
end

function ns.SetBarsLocked(locked)
    B.locked = locked
    for id, h in pairs(bars) do
        h.mover:SetShown(not locked and ns.BarConfig(id).enabled)
    end
    -- hidden bars show while unlocked (visibility drivers), and back after
    if ns.barsActive then
        for _, id in ipairs(BAR_IDS) do ns.ApplyBar(id) end
        for _, id in ipairs(ns.HOLDER_IDS) do ns.ApplyHolder(id) end
    end
end

-------------------------------------------------------------------------------
-- Exact position: X / Y of the top left corner from the bottom left of the
-- screen (UIParent units)
-------------------------------------------------------------------------------
function ns.BarXY(id)
    local h = bars[id]
    if h and h:GetLeft() then
        local s = h:GetScale()
        return math.floor(h:GetLeft() * s + 0.5), math.floor(h:GetTop() * s + 0.5)
    end
    local p = ns.BarConfig(id).pos
    if p and p.point == "BOTTOMLEFT" then return math.floor(p.x + 0.5), math.floor(p.y + 0.5) end
    return 0, 0
end

function ns.SetBarXY(id, x, y)
    local c = ns.BarConfig(id)
    local cx, cy = ns.BarXY(id)
    c.pos = { point = "BOTTOMLEFT", x = x or cx, y = y or cy }
    ns.ApplyBar(id)
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
ns.PRESET_IDS = { "blizzard", "compact", "split" }

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
-- Copy the layout of Bartender4 (once, or from the options)
-------------------------------------------------------------------------------
function ns.ImportBartender()
    local db = Bartender4DB
    local mod = db and db.namespaces and db.namespaces.ActionBars
    if not mod then return false end
    -- Forever: UnitName gives (name, surname) and Bartender's profile is
    -- "<name> <surname>"; the classic "<name> - <realm>" is tried too
    local name, surname = UnitName("player")
    local profiles = mod.profiles or {}
    local keys = db.profileKeys or {}
    local prof
    for _, k in ipairs({ surname and (name .. " " .. surname), name .. " - " .. GetRealmName(), name }) do
        prof = profiles[keys[k] or k]
        if prof then break end
    end
    local list = prof and prof.actionbars
    if not list then return false end
    for _, id in ipairs(BAR_IDS) do
        local src = list[id]
        if src then
            local c = ns.BarConfig(id)
            c.enabled = src.enabled ~= false and (id <= 6 or src.enabled == true)
            c.buttons = src.buttons or 12
            c.rows = src.rows or 1
            c.padding = src.padding or 2
            local p = src.position
            c.scale = (p and p.scale) or src.scale or 1
            c.alpha = src.alpha or 1
            c.showGrid = src.showgrid or false
            if p and p.point then
                c.pos = { point = p.point, x = p.x or 0, y = p.y or 0 }
            end
        end
    end
    B.imported = true
    return true
end

-------------------------------------------------------------------------------
-- Start
-------------------------------------------------------------------------------
local function BartenderLoaded()
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f and f("Bartender4") and true or false
end
ns.BartenderLoaded = BartenderLoaded

-- Turns Tidy's bars on or off while playing (out of combat). With Bartender4
-- loaded they stay off: both would fight over the binds.
function ns.SetBarsActive(on)
    ns.barsConflict = on and BartenderLoaded() or nil
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
    if B.enabled and not B.imported then ns.ImportBartender() end
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
    if ns.barsActive then
        ns.ApplyBars()
        ns.SetBarsLocked(B.locked)
    end
end)
