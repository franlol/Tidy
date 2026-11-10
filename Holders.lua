-------------------------------------------------------------------------------
-- Tidy - Holders for the rest of Blizzard's bars
-- Pet bar, stance bar, micro menu, bags, XP/reputation, extra button, leave
-- vehicle and queue status. Native and light: Blizzard's own buttons and
-- frames keep working as always (events, updates, clicks); Tidy only moves
-- them into its own frame ("holder"), which is moved, snapped, scaled and
-- selected exactly like the action bars (see Bars.lua).
--   * button groups (pet, stance, micro, bags): Tidy lays the buttons out
--     in rows with a padding
--   * single frames (XP, extra, vehicle, queue): the frame sits in the
--     holder; when Blizzard re-anchors it, it is put back
-- Everything taken is remembered and given back when the bars are turned
-- off, without a reload.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local bars = ns.bars

ns.HOLDER_IDS = { "pet", "stance", "micro", "bags", "status", "extra", "vehicle", "queue" }
local NAMES = {
    pet = "Pet bar", stance = "Stance bar", micro = "Micro menu", bags = "Bags",
    status = "XP / reputation", extra = "Extra button", vehicle = "Leave vehicle", queue = "Queue status",
}
function ns.HolderName(id) return L[NAMES[id]] end

local function Names(prefix, n)
    local t = {}
    for i = 1, n do t[i] = prefix .. i end
    return t
end

local MICRO = MICRO_BUTTONS or {
    "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "LegacyMicroButton", "QuestLogMicroButton", "SocialsMicroButton", "GuildMicroButton",
    "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "StoreMicroButton",
    "MainMenuMicroButton", "HelpMicroButton",
}

-- How each holder is made
local HIDE_IN_VEHICLE = "[petbattle][overridebar][vehicleui][possessbar] hide; "
local DEFS = {
    pet = { group = Names("PetActionButton", 10), secure = true, padding = 2,
        visibility = HIDE_IN_VEHICLE .. "[pet] show; hide" },
    stance = { group = Names("StanceButton", 10), secure = true, padding = 2,
        count = function() return GetNumShapeshiftForms and GetNumShapeshiftForms() or 0 end,
        visibility = HIDE_IN_VEHICLE .. "show" },
    micro = { group = MICRO, padding = 0, packShown = true },
    bags = { group = { "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot",
        "CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton", "KeyRingButton" },
        padding = 2, packShown = true },
    status = { frame = "StatusTrackingBarManager", width = true },
    extra = { frame = ExtraAbilityContainer and "ExtraAbilityContainer" or "ExtraActionBarFrame", secure = true, size = { 128, 128 } },
    vehicle = { frame = "MainMenuBarVehicleLeaveButton", size = { 32, 32 } },
    queue = { frame = "QueueStatusButton", size = { 32, 32 } },
}

function ns.HolderDefaults(id)
    local d = DEFS[id] or {}
    return ns.CommonBarDefaults({
        enabled = true,
        rows = 1,
        padding = d.padding or 0,
        scale = 1,
        alpha = 1,
        width = 571, -- XP / reputation only
        -- pos: taken from where Blizzard has it the first time
    })
end

-------------------------------------------------------------------------------
-- Taking and giving back Blizzard regions
-------------------------------------------------------------------------------
local taken = {} -- region -> { parent, points, overrides }
local busy       -- true while Tidy itself moves things (hooks ignore it)

local function Points(r)
    local list = {}
    for i = 1, r:GetNumPoints() do list[i] = { r:GetPoint(i) } end
    return list
end

-- Edit Mode puts its own ClearAllPoints/SetPoint/SetScale on its frames;
-- the plain ones are used while Tidy holds the frame (and given back after)
local OVERRIDES = { "ClearAllPoints", "SetPoint", "SetScale" }

-- unlock: drop Edit Mode's overrides (single frames only; buttons have none,
-- and their raw SetPoint is Tidy's own hook)
local function Take(r, parent, unlock)
    if not taken[r] then
        local o = { parent = r:GetParent(), points = Points(r), overrides = {} }
        if unlock then
            for _, m in ipairs(OVERRIDES) do
                local f = rawget(r, m)
                if f then
                    o.overrides[m] = f
                    r[m] = nil
                end
            end
        end
        taken[r] = o
    end
    if r:GetParent() ~= parent then r:SetParent(parent) end
end

local function Give(r)
    local o = taken[r]
    if not o then return end
    taken[r] = nil
    for m, f in pairs(o.overrides) do r[m] = f end
    r:SetParent(o.parent)
    r:ClearAllPoints()
    for _, p in ipairs(o.points) do pcall(r.SetPoint, r, unpack(p)) end
end

-- Where a region is now (UIParent units): left, top
local function TopLeft(r)
    local l, t = r:GetLeft(), r:GetTop()
    if not l then return end
    local k = r:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * k, t * k
end

-------------------------------------------------------------------------------
-- Holders
-------------------------------------------------------------------------------
local holders = {} -- [id] = holder (also in ns.bars, for moving/snapping)

local function GroupButtons(def)
    local list = {}
    for _, name in ipairs(def.group) do
        local b = _G[name]
        if b then list[#list + 1] = b end
    end
    return list
end

local function Content(def)
    return def.frame and _G[def.frame]
end

local function Exists(id)
    local def = DEFS[id]
    if def.group then return #GroupButtons(def) > 0 end
    return Content(def) ~= nil
end

-- Buttons in rows: cell = biggest button, each one centered in its cell
local function LayoutGroup(h, c, def)
    local list = GroupButtons(def)
    local shown = {}
    local count = def.count and def.count() or #list
    for i, b in ipairs(list) do
        if i <= count and (not def.packShown or b:IsShown()) then shown[#shown + 1] = b end
    end
    local cw, ch = 1, 1
    for _, b in ipairs(shown) do
        local w, hh = b:GetSize()
        cw, ch = math.max(cw, w), math.max(ch, hh)
    end
    local n = math.max(1, #shown)
    local rows = math.max(1, math.min(n, c.rows))
    local cols = math.ceil(n / rows)
    local pad = c.padding
    busy = true
    for i, b in ipairs(shown) do
        local r, col = math.floor((i - 1) / cols), (i - 1) % cols
        if c.growH == "LEFT" then col = cols - 1 - col end
        if c.growV == "UP" then r = rows - 1 - r end
        b:EnableMouse(not c.clickThrough)
        b:ClearAllPoints()
        b:SetPoint("CENTER", h, "TOPLEFT", col * (cw + pad) + cw / 2, -r * (ch + pad) - ch / 2)
    end
    busy = nil
    h:SetSize(math.max(1, cols * cw + (cols - 1) * pad), math.max(1, rows * ch + (rows - 1) * pad))
end

-- XP / reputation: the two Blizzard containers stacked, as wide as chosen
local function LayoutStatus(h, c, f)
    local main, second = f.MainStatusTrackingBarContainer, f.SecondaryStatusTrackingBarContainer
    local height = 14
    busy = true
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT")
    f:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT")
    if main and second then
        for _, bar in ipairs({ main, second }) do
            Take(bar, f, true)
            bar:SetClampedToScreen(false)
        end
        main:ClearAllPoints()
        main:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
        main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
        second:ClearAllPoints()
        second:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, -6)
        second:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 0, -6)
        height = math.max(14, (main:GetHeight() or 0) + (second:GetHeight() or 0) - 6)
    end
    busy = nil
    h:SetSize(c.width, height)
end

local function LayoutFrame(h, c, def, f)
    local w, hh
    if def.size then
        w, hh = def.size[1], def.size[2]
    else
        w, hh = f:GetSize()
    end
    busy = true
    f:ClearAllPoints()
    f:SetPoint("CENTER", h, "CENTER")
    busy = nil
    h:SetSize(math.max(1, w or 1), math.max(1, hh or 1))
end

local function Layout(id)
    local h, def = holders[id], DEFS[id]
    if not h or not h.active then return end
    local c = ns.BarConfig(id)
    if def.group then
        for _, b in ipairs(GroupButtons(def)) do Take(b, h) end
        LayoutGroup(h, c, def)
    else
        local f = Content(def)
        Take(f, h, true)
        -- Blizzard's manager of bottom frames must leave it alone
        local mgr = UIParentBottomManagedFrameContainer
        if mgr and mgr.showingFrames then mgr.showingFrames[f] = nil end
        if def.width then LayoutStatus(h, c, f) else LayoutFrame(h, c, def, f) end
    end
    h.mover:SetShown(not ns.P.bars.locked)
end

-- Blizzard moved something of ours: put it back (after combat if secure)
local function Relayout(id)
    if busy then return end
    local h = holders[id]
    if not h or not h.active then return end
    if DEFS[id].secure then ns.RunOOC("holder" .. id, function() Layout(id) end) else Layout(id) end
end

-- Hooks: installed once, they only act while the holder is active
local function Hook(id)
    local def = DEFS[id]
    local function Again() Relayout(id) end
    local function HookMethod(obj, m) if obj and type(obj[m]) == "function" then hooksecurefunc(obj, m, Again) end end
    if def.group then
        for _, b in ipairs(GroupButtons(def)) do
            hooksecurefunc(b, "SetPoint", Again)
            if def.packShown then
                b:HookScript("OnShow", Again)
                b:HookScript("OnHide", Again)
            end
            -- micro buttons go to the vehicle / pet battle bar and come back
            -- through SetParent: take them again only when they come back
            if id == "micro" then
                hooksecurefunc(b, "SetParent", function(_, parent)
                    if busy or not (holders.micro and holders.micro.active) then return end
                    if parent == MicroMenu or parent == MicroMenuContainer or parent == UIParent then Again() end
                end)
            end
        end
        if id == "stance" then
            local ev = CreateFrame("Frame")
            ev:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
            ev:SetScript("OnEvent", Again)
        end
        if id == "micro" and type(UpdateMicroButtons) == "function" then hooksecurefunc("UpdateMicroButtons", Again) end
        if id == "bags" then HookMethod(BagsBar, "Layout") end
    else
        -- no SetPoint hook here (it would be a raw field, mixed up with
        -- Edit Mode's overrides): the places where Blizzard re-anchors
        local f = Content(def)
        HookMethod(f, "ApplySystemAnchor")
        HookMethod(f, "UpdatePosition")
        HookMethod(f, "Update")
        HookMethod(EditModeManagerFrame, "UpdateBottomActionBarPositions")
        HookMethod(UIParentBottomManagedFrameContainer, "Layout")
        if type(UIParent_ManageFramePositions) == "function" then
            hooksecurefunc("UIParent_ManageFramePositions", Again)
        end
    end
end

local function CreateHolder(id)
    local h = CreateFrame("Frame", "TidyHolder_" .. id, UIParent, "SecureHandlerStateTemplate")
    h.id, h.kind, h.label = id, "holder", ns.HolderName(id)
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    h.buttons = {}
    ns.CreateMover(h)
    holders[id] = h
    bars[id] = h
    Hook(id)
    return h
end

-- First time: the holder starts where Blizzard has the bar now
local function CapturePosition(id, c)
    if c.pos then return end
    local def = DEFS[id]
    local regions = def.group and GroupButtons(def) or { Content(def) }
    local left, top
    for _, r in ipairs(regions) do
        local l, t = TopLeft(r)
        if l then
            left = left and math.min(left, l) or l
            top = top and math.max(top, t) or t
        end
    end
    c.pos = left and { point = "BOTTOMLEFT", x = left, y = top }
        or { point = "CENTER", x = 0, y = 0 }
end

-- Applies one holder (out of combat)
function ns.ApplyHolder(id)
    if not Exists(id) then return end
    ns.RunOOC("holder" .. id, function()
        local c = ns.BarConfig(id)
        local h = holders[id]
        if not c.enabled then
            if h and h.active then ns.ReleaseHolder(id) end
            return
        end
        CapturePosition(id, c)
        h = h or CreateHolder(id)
        h.active = true
        ns.PlaceBar(h, c)
        h:SetAlpha(c.alpha)
        Layout(id)
        -- the user's hide conditions first, then the bar's own (pet: only
        -- with a pet...); unlocked: always visible, to move it
        local vis = "show"
        if ns.P.bars.locked then vis = ns.VisibilityDriver(c, DEFS[id].visibility) end
        RegisterStateDriver(h, "visibility", vis)
        ns.SetFade(h, c)
    end)
end

-- Gives everything of one holder back to Blizzard
function ns.ReleaseHolder(id)
    local h = holders[id]
    if not h or not h.active then return end
    h.active = nil
    UnregisterStateDriver(h, "visibility")
    ns.SetFade(h, { fade = false, alpha = 1 })
    h:Hide()
    for r in pairs(taken) do
        if r:GetParent() == h or (id == "status" and r:GetParent() == Content(DEFS.status)) then Give(r) end
    end
    -- let Blizzard lay its bars out again
    local function Call(obj, m) if obj and type(obj[m]) == "function" then pcall(obj[m], obj) end end
    if id == "pet" then Call(PetActionBar, "UpdateGridLayout") end
    if id == "stance" then Call(StanceBar, "UpdateGridLayout") end
    if id == "micro" then Call(MicroMenu, "Layout") end
    if id == "bags" then Call(BagsBar, "Layout") end
    if id == "status" or id == "extra" or id == "vehicle" then
        Call(EditModeManagerFrame, "UpdateBottomActionBarPositions")
        if UIParent_ManageFramePositions then pcall(UIParent_ManageFramePositions) end
    end
end

function ns.ReleaseHolders()
    for _, id in ipairs(ns.HOLDER_IDS) do ns.ReleaseHolder(id) end
end

-- Holders that exist in this game version (for the options)
function ns.HolderIDs()
    local list = {}
    for _, id in ipairs(ns.HOLDER_IDS) do
        if Exists(id) then list[#list + 1] = id end
    end
    return list
end
