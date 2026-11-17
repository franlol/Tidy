-------------------------------------------------------------------------------
-- Tidy - Square icons
-- Crops every icon to a square, removes Blizzard's round masks and frames and
-- draws a flat border behind it (thickness, color and zoom in the options).
-- Covers: action bars (Blizzard, Tidy and any LibActionButton bar), pet
-- and stance bars, your buffs/debuffs and item buttons (bags, bank, loot,
-- merchant, character...). Target, focus and raid frame auras are drawn by
-- the game's native aura containers, which give addons no icons to style.
--
-- Everything is live: what Tidy changes on a frame is remembered, so turning
-- a place off puts Blizzard's look back without a reload.
-- Cost: no OnUpdate. Auras and items are styled once; action buttons only
-- redo what Blizzard puts back when it redraws them.
-------------------------------------------------------------------------------

local _, ns = ...

-- frame -> skin: { icon, bd, kind, cat, tc, typed, hidden = {region = alpha},
--                  masks = {...}, points = {...}, off }
local skins = setmetatable({}, { __mode = "k" })
local O -- ns.P.icons (profile in use)

local function On(cat) return O.enabled and O[cat] end

local function Zoom(icon)
    local z = O.zoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
end

-- Tidy's bar buttons can be any width / height: the bars fit the icon
-- (cover / contain / stretch) with the zoom on top
local function ZoomSkin(s)
    if s.frame.tidyFit and ns.FitIcon then ns.FitIcon(s.frame, O.zoom) else Zoom(s.icon) end
end

-- Hides a Blizzard region, remembering its alpha to give it back
local function Hide(s, region)
    if not region or not region.SetAlpha then return end
    if s.hidden[region] == nil then s.hidden[region] = region:GetAlpha() end
    if region:GetAlpha() ~= 0 then region:SetAlpha(0) end
end

local function RemoveMasks(s)
    local icon = s.icon
    if not icon.GetNumMaskTextures then return end
    local n = icon:GetNumMaskTextures()
    for i = n, 1, -1 do
        local m = icon:GetMaskTexture(i)
        if m then
            icon:RemoveMaskTexture(m)
            s.masks[m] = true
        end
    end
end

local SetPoint = PixelUtil and PixelUtil.SetPoint or function(r, ...) r:SetPoint(...) end

-- Border: four edges around the icon (outside it). Background: behind the
-- icon, only seen on empty buttons or through transparent icons.
local EDGES = {
    top = { "TOPLEFT", "TOPLEFT", -1, 1, "BOTTOMRIGHT", "TOPRIGHT", 1, 0 },
    bottom = { "TOPLEFT", "BOTTOMLEFT", -1, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1 },
    left = { "TOPLEFT", "TOPLEFT", -1, 0, "BOTTOMRIGHT", "BOTTOMLEFT", 0, 0 },
    right = { "TOPLEFT", "TOPRIGHT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 1, 0 },
}

local function Place(s)
    local n = O.size
    -- Tidy's own buttons: around the whole button (with "contain" the icon
    -- is smaller than the button, the button keeps its size); the rest:
    -- around the icon, which fills its button
    local box = s.frame.tidyFit and s.frame or s.icon
    for side, e in pairs(s.edges) do
        local d = EDGES[side]
        e:ClearAllPoints()
        SetPoint(e, d[1], box, d[2], d[3] * n, d[4] * n)
        SetPoint(e, d[5], box, d[6], d[7] * n, d[8] * n)
    end
    s.bg:ClearAllPoints()
    s.bg:SetAllPoints(box)
end

-- Border color: the debuff type / item quality one (if enabled and known) or
-- the chosen color
local function Paint(s)
    if s.off then return end
    local c = O.color
    if s.typed and s.tc.r and ((s.kind == "aura" and O.debuffColor) or (s.kind == "item" and O.qualityColor)) then
        c = s.tc
    end
    for _, e in pairs(s.edges) do e:SetColorTexture(c.r, c.g, c.b, c.a or 1) end
    local b = O.background
    s.bg:SetColorTexture(b.r, b.g, b.b, b.a or 1)
end

local function ShowBorder(s, on)
    for _, e in pairs(s.edges) do e:SetShown(on) end
    s.bg:SetShown(on)
    -- flat states of action buttons: off with the square look (Blizzard's
    -- own come back with their alpha)
    if s.states and not on then
        s.states.push:Hide()
        s.states.check:Hide()
        s.states.hover:SetAlpha(0)
    end
end

-------------------------------------------------------------------------------
-- Flat states for action buttons: Blizzard's hover / pressed / active
-- frames are drawn for its round-cornered buttons (bigger, off-center on a
-- square one). With the square look they are hidden and these square,
-- button-sized overlays are used instead. Hooks are installed once and only
-- act while the button is styled.
-------------------------------------------------------------------------------
-- Pressed overlays shown (states -> { b = button, mouse = mouse button }):
-- hidden as soon as that mouse button is up or the mouse is off the button
local pushed = {}
local pushWatch = CreateFrame("Frame")
local function PushTick()
    for st, p in pairs(pushed) do
        if not IsMouseButtonDown(p.mouse) or not p.b:IsVisible() or not p.b:IsMouseOver() then
            st.push:Hide()
            pushed[st] = nil
        end
    end
    if not next(pushed) then pushWatch:SetScript("OnUpdate", nil) end
end

-- Pressed look from a key (Bars.lua): Tidy's flat overlay (if the pressed
-- state is on), or Blizzard's pushed state without the square look
function ns.ShowPressed(b, on)
    local s = skins[b]
    local st = s and s.states
    if st and not s.off then
        st.push:SetShown(on and O.pushShow and true or false)
    else
        pcall(b.SetButtonState, b, on and "PUSHED" or "NORMAL")
    end
end

local function FlatStates(b, s)
    local st = s.states
    if not st then
        st = {}
        s.states = st
        -- hover: the HIGHLIGHT layer shows by itself while the mouse is over
        st.hover = b:CreateTexture(nil, "HIGHLIGHT")
        -- pressed (mouse) and active (auto attack, current stance...)
        st.push = b:CreateTexture(nil, "OVERLAY", nil, 6)
        st.push:Hide()
        st.check = b:CreateTexture(nil, "OVERLAY", nil, 5)
        st.check:Hide()
        for _, t in ipairs({ st.hover, st.push, st.check }) do t:SetAllPoints(b) end
        -- pressed: only while the mouse button is held; cleared on release,
        -- when the mouse leaves and when hidden (never stays). The game does
        -- not send OnMouseUp once a drag started (a click while moving the
        -- mouse), so a watcher also checks the mouse button itself.
        b:HookScript("OnMouseDown", function(_, mouse)
            if O.pushShow and not s.off then
                st.push:Show()
                pushed[st] = { b = b, mouse = mouse }
                pushWatch:SetScript("OnUpdate", PushTick)
            end
        end)
        local function Release() st.push:Hide(); pushed[st] = nil end
        -- (not PostClick: with "cast on key down" the click happens on the
        -- press itself, the overlay would never show)
        for _, script in ipairs({ "OnMouseUp", "OnLeave", "OnHide" }) do
            if b:HasScript(script) then b:HookScript(script, Release) end
        end
        if type(b.SetChecked) == "function" then
            hooksecurefunc(b, "SetChecked", function(_, on)
                st.check:SetShown(O.checkShow and not s.off and on and true or false)
            end)
        end
    end
    -- Blizzard's own frames stay hidden with the square look; each state
    -- shows its flat overlay only if it is on
    local function C(t, c) t:SetColorTexture(c.r, c.g, c.b, c.a or 1) end
    C(st.hover, O.hoverColor)
    C(st.push, O.pushColor)
    C(st.check, O.checkColor)
    st.hover:SetAlpha(O.hoverShow and 1 or 0)
    if not O.pushShow then st.push:Hide() end
    st.check:SetShown(O.checkShow and b.GetChecked and b:GetChecked() and true or false)
    Hide(s, b:GetHighlightTexture())
    Hide(s, b:GetPushedTexture())
    if b.GetCheckedTexture then Hide(s, b:GetCheckedTexture()) end
end

local function IconOf(f)
    local icon = f.icon or f.Icon or f.IconTexture
    if icon then return icon end
    local name = f.GetName and f:GetName()
    return name and (_G[name .. "Icon"] or _G[name .. "IconTexture"])
end

local function GetSkin(f, icon, kind, cat)
    local s = skins[f]
    if s then return s end
    s = { frame = f, icon = icon, kind = kind, cat = cat, tc = {}, hidden = {}, masks = {}, edges = {} }
    s.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    for side in pairs(EDGES) do s.edges[side] = f:CreateTexture(nil, "BACKGROUND", nil, -7) end
    skins[f] = s
    return s
end

local function Points(r)
    local list = {}
    for i = 1, r:GetNumPoints() do list[i] = { r:GetPoint(i) } end
    return list
end

local function SetPoints(r, list)
    r:ClearAllPoints()
    for _, p in ipairs(list) do r:SetPoint(unpack(p)) end
end

-- Common part of styling: zoom, no masks, our border
local function Style(s)
    s.off = nil
    ZoomSkin(s)
    RemoveMasks(s)
    Place(s)
    ShowBorder(s, true)
    Paint(s)
end

-- Puts Blizzard's look back
local function Unstyle(f, s)
    if s.off then return end
    s.off = true
    ShowBorder(s, false)
    s.icon:SetTexCoord(0, 1, 0, 1)
    if f.tidyFit and ns.FitIcon then ns.FitIcon(f, 0) end
    for m in pairs(s.masks) do s.icon:AddMaskTexture(m) end
    wipe(s.masks)
    for region, a in pairs(s.hidden) do region:SetAlpha(a) end
    wipe(s.hidden)
    if s.points and not InCombatLockdown() then
        SetPoints(s.icon, s.points.icon)
        if s.points.cd then SetPoints(f.cooldown, s.points.cd) end
        s.points = nil
    end
end

-- Follows the color Blizzard gives a texture we hide (debuff type border,
-- item quality border) and paints our border with it. Hooked once per frame.
local function FollowColor(f, s, src, shownMatters)
    if not src or not src.SetVertexColor then return end
    Hide(s, src)
    if s.following then return end
    s.following = true
    local tc = s.tc
    tc.r, tc.g, tc.b = src:GetVertexColor()
    s.typed = not shownMatters or src:IsShown()
    hooksecurefunc(src, "SetVertexColor", function(_, r, g, b)
        tc.r, tc.g, tc.b = r, g, b
        Paint(s)
    end)
    if shownMatters then
        hooksecurefunc(src, "Show", function() s.typed = true Paint(s) end)
        hooksecurefunc(src, "Hide", function() s.typed = false Paint(s) end)
        if src.SetShown then
            hooksecurefunc(src, "SetShown", function(_, on) s.typed = on and true or false Paint(s) end)
        end
    end
end

-------------------------------------------------------------------------------
-- Action buttons: Blizzard puts the round art and mask back when it redraws
-- them, so that part is redone each time (cheap: only what changed)
-------------------------------------------------------------------------------
local function ActionArt(b)
    if not b then return end
    local s = skins[b]
    if not On("actionbars") then
        if s then Unstyle(b, s) end
        return
    end
    local icon = s and s.icon or IconOf(b)
    if not icon then return end
    s = s or GetSkin(b, icon, "action", "actionbars")
    Style(s)
    Hide(s, b:GetNormalTexture())
    Hide(s, b.NormalTexture)
    Hide(s, b.SlotArt)
    Hide(s, b.SlotBackground)
    Hide(s, b.FloatingBG)
    Hide(s, b.RightDivider)
    Hide(s, b.BottomDivider)
    FlatStates(b, s)
    -- icon fills the whole button and the cooldown follows it: out of
    -- combat only (the button is protected); the old points are kept
    -- (Tidy's own buttons: the bar places icon and cooldown, FitIcon)
    if not b.tidyFit and not s.points and not InCombatLockdown() then
        s.points = { icon = Points(icon), cd = b.cooldown and Points(b.cooldown) }
        icon:ClearAllPoints()
        icon:SetAllPoints(b)
        if b.cooldown then
            pcall(b.cooldown.ClearAllPoints, b.cooldown)
            pcall(b.cooldown.SetAllPoints, b.cooldown, b)
        end
    end
end

local hooked = setmetatable({}, { __mode = "k" })
local function HookBlizzardAction(b)
    if not b then return end
    if not hooked[b] then
        hooked[b] = true
        if type(b.UpdateButtonArt) == "function" then
            hooksecurefunc(b, "UpdateButtonArt", ActionArt)
        elseif type(b.Update) == "function" then
            hooksecurefunc(b, "Update", ActionArt)
        end
    end
    ActionArt(b)
end

local ACTION_NAMES = {}
for _, prefix in ipairs({
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton",
    "PossessButton", "OverrideActionBarButton", "ShapeshiftButton",
}) do
    for i = 1, 12 do ACTION_NAMES[#ACTION_NAMES + 1] = prefix .. i end
end

local classicActionHook, labHooked
local function SkinAllActionButtons()
    for _, n in ipairs(ACTION_NAMES) do
        local b = _G[n]
        if b then
            if classicActionHook then ActionArt(b) else HookBlizzardAction(b) end
        end
    end
    -- any LibActionButton bar: its callback fires after each
    -- update, so its buttons are not hooked twice
    local LAB = LibStub and LibStub("LibActionButton-1.0", true)
    if LAB then
        if not labHooked and LAB.RegisterCallback then
            labHooked = true
            LAB.RegisterCallback(ns, "OnButtonCreated", function(_, b) ActionArt(b) end)
            LAB.RegisterCallback(ns, "OnButtonUpdate", function(_, b) ActionArt(b) end)
        end
        if LAB.GetAllButtons then
            for b in pairs(LAB:GetAllButtons()) do ActionArt(b) end
        end
    end
end

-------------------------------------------------------------------------------
-- Auras (styled once per frame: Blizzard reuses them without resetting it)
-------------------------------------------------------------------------------
local function SkinAura(f, cat)
    if not f then return end
    local s = skins[f]
    if s and not s.off then return end
    if not On(cat) then return end
    local icon = s and s.icon or IconOf(f)
    if not icon or not icon.SetTexCoord then return end
    s = s or GetSkin(f, icon, "aura", cat)
    Style(s)
    Hide(s, f.TempEnchantBorder)
    local name = f:GetName()
    FollowColor(f, s, f.Border or f.DebuffBorder or (name and _G[name .. "Border"]))
end

local function PlayerAura(f) SkinAura(f, "playerAuras") end

-- Frames named Prefix1, Prefix2...: stops at the first one that does not
-- exist yet (Blizzard creates them in order); names are cached
local nameCache = {}
local function NamedFrames(prefix, max, fn)
    local list = nameCache[prefix]
    if not list then
        list = {}
        for i = 1, max do list[i] = prefix .. i end
        nameCache[prefix] = list
    end
    for i = 1, max do
        local f = _G[list[i]]
        if not f then return end
        fn(f)
    end
end

local modernPlayerAuras = BuffFrame and BuffFrame.auraFrames ~= nil

local function PlayerAuras()
    if not On("playerAuras") then return end
    if modernPlayerAuras then
        for _, frameName in ipairs({ "BuffFrame", "DebuffFrame" }) do
            local frame = _G[frameName]
            if frame and frame.auraFrames then
                for _, f in ipairs(frame.auraFrames) do PlayerAura(f) end
            end
        end
    else
        NamedFrames("BuffButton", 40, PlayerAura)
        NamedFrames("DebuffButton", 40, PlayerAura)
        NamedFrames("TempEnchant", 3, PlayerAura)
    end
end

-------------------------------------------------------------------------------
-- Item buttons (bags, bank, loot, merchant, character, quest rewards...)
-------------------------------------------------------------------------------
-- Bag slots show SlotHighlightTexture while their bag is open (or empty):
-- with the square look it is hidden and the flat "active" overlay mirrors
-- it, like an active action button. Hooked once per button.
local function ActiveSlot(b, s)
    local t = b.SlotHighlightTexture
    if not t then return end
    Hide(s, t)
    if not s.syncActive then
        s.syncActive = function()
            local st = s.states
            if st then st.check:SetShown(O.checkShow and not s.off and t:IsShown() and true or false) end
        end
        hooksecurefunc(t, "Show", s.syncActive)
        hooksecurefunc(t, "Hide", s.syncActive)
        if t.SetShown then hooksecurefunc(t, "SetShown", s.syncActive) end
    end
    s.syncActive()
end

-- Same hover / pressed / active look as the action buttons. Blizzard puts
-- its highlight back when a bag slot redraws (UpdateTextures), so this is
-- redone with the zoom.
local function ItemStates(b, s)
    FlatStates(b, s)
    ActiveSlot(b, s)
end

local function SkinItem(b)
    if not b then return end
    local s = skins[b]
    -- already styled: Blizzard resets the icon crop on every texture change
    -- (SetTexCoord 0, 1, 0, 1), so the zoom is put back
    if s and not s.off then
        ZoomSkin(s)
        ItemStates(b, s)
        return
    end
    if not On("items") then return end
    local icon = s and s.icon or IconOf(b)
    if not icon or not icon.SetTexCoord then return end
    s = s or GetSkin(b, icon, "item", "items")
    Style(s)
    Hide(s, b.GetNormalTexture and b:GetNormalTexture())
    Hide(s, b.NormalTexture)
    -- the quality border is shown only for good items: follow it
    FollowColor(b, s, b.IconBorder, true)
    ItemStates(b, s)
end

-- Bag bar: drawn before Tidy starts (so the item hook misses it), and the
-- backpack and key ring set their icon in UpdateTextures, never through
-- SetItemButtonTexture. Every button redraws there: hooked once.
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
    "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }

-- Blizzard's dividers on the right edge of each bag (BagsBar:UpdateDividers)
-- are drawn for its round slots and its own layout: hidden with the square
-- look, and while Tidy's bag holder lays the bags out (by alpha, the bar
-- acquires and places them itself)
local function BagDividers()
    local bar = BagsBar
    if not bar then return end
    local a = (On("items") or (ns.BagsHeld and ns.BagsHeld())) and 0 or 1
    for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
        local pool = bar[key]
        if pool then
            for d in pool:EnumerateActive() do d:SetAlpha(a) end
        end
    end
end

ns.BagDividers = BagDividers

local function BagBar()
    BagDividers()
    for _, n in ipairs(BAG_BUTTONS) do
        local b = _G[n]
        if b then
            if not hooked[b] and type(b.UpdateTextures) == "function" then
                hooked[b] = true
                hooksecurefunc(b, "UpdateTextures", SkinItem)
            end
            SkinItem(b)
        end
    end
end

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------
-- Look changed: applied to every styled icon
function ns.ApplyIcons()
    for _, s in pairs(skins) do
        if not s.off then
            ZoomSkin(s)
            Place(s)
            Paint(s)
            if s.kind == "action" then FlatStates(s.frame, s)
            elseif s.kind == "item" then ItemStates(s.frame, s) end
        end
    end
end

-- A place was turned on or off: style what is on screen / give back
-- Blizzard's look. Items turned on get styled the next time they update.
function ns.RefreshIcons()
    for f, s in pairs(skins) do
        if not On(s.cat) then Unstyle(f, s) end
    end
    SkinAllActionButtons()
    PlayerAuras()
    BagBar()
    for f, s in pairs(skins) do
        if s.off and On(s.cat) then
            if s.kind == "item" then SkinItem(f)
            elseif s.kind == "aura" then SkinAura(f, s.cat) end
        end
    end
end

-------------------------------------------------------------------------------
-- Start: hooks (only for the parts that exist in this game version). Hooks
-- are always installed; each one checks its option, so they can be turned
-- on later without a reload.
-------------------------------------------------------------------------------
ns.Module(function()
    O = ns.P.icons

    classicActionHook = type(ActionButton_Update) == "function"
    if classicActionHook then hooksecurefunc("ActionButton_Update", ActionArt) end

    if modernPlayerAuras then
        for _, frameName in ipairs({ "BuffFrame", "DebuffFrame" }) do
            local frame = _G[frameName]
            if frame then
                local m = (type(frame.UpdateAuraButtons) == "function" and "UpdateAuraButtons")
                    or (type(frame.Update) == "function" and "Update")
                if m then hooksecurefunc(frame, m, PlayerAuras) end
            end
        end
    else
        for _, fn in ipairs({ "BuffFrame_UpdateAllBuffAnchors", "BuffFrame_Update", "AuraButton_Update" }) do
            if type(_G[fn]) == "function" then
                hooksecurefunc(fn, PlayerAuras)
                break
            end
        end
    end

    if type(SetItemButtonTexture) == "function" then
        hooksecurefunc("SetItemButtonTexture", SkinItem)
    end
    if BagsBar and type(BagsBar.UpdateDividers) == "function" then
        hooksecurefunc(BagsBar, "UpdateDividers", BagDividers)
    end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED") -- finish what was skipped in combat
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            ns.RefreshIcons()
        else
            SkinAllActionButtons()
        end
    end)
end, function()
    -- another profile: its places and its look
    O = ns.P.icons
    ns.RefreshIcons()
    ns.ApplyIcons()
end)
