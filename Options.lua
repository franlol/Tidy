-------------------------------------------------------------------------------
-- Tidy - Options window (LibFlatyUI-1.0)
--
--   General  : everything global: bars on/off, snap, presets,
--              minimap, language (unlock / keybinding mode: window header)
--   Bars     : one bar at a time (dropdown, or click it on screen):
--              layout · visibility · actions
--   Buttons  : every action button: behaviour (with casting) · states ·
--              timers · flashes · texts
--   Icons    : square icons
--   Profiles : profiles, export / import
-- Every change is applied at once. Controls that do not apply are greyed
-- out, never hidden (no layout jumps).
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = LibStub("LibFlatyUI-1.0"):New({ accent = { 0.44, 0.76, 1 } })
UI.OnChange = function() UI.RefreshAll() end
local STRINGS = { confirm = "Click again to confirm", search = "Search...", accept = "Accept", cancel = "Cancel" }
UI.strings = setmetatable({}, { __index = function(_, key) return L[STRINGS[key]] end })

local win
-- Icons settings its Defaults keeps: the places, and the button states
-- (they are set in Buttons > States, which has its own Defaults)
local KEEP_ICONS = { "enabled", "actionbars", "playerAuras", "unitAuras", "raidAuras", "items",
    "hoverShow", "hoverColor", "pushShow", "pushColor", "checkShow", "checkColor" }
local active = function() return ns.barsActive end

-- Re-applies every bar (button looks, casting, lock...)
local function ApplyAllBars()
    if ns.barsActive then ns.ApplyBars() end
end

local POINTS = function()
    return {
        { "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] },
        { "LEFT", L["Left"] }, { "CENTER", L["Center"] }, { "RIGHT", L["Right"] },
        { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] },
    }
end

local OUTLINES = function()
    return { { "", L["None"] }, { "OUTLINE", L["Outline"] }, { "THICKOUTLINE", L["Thick outline"] } }
end

-- Blizzard's fonts, plus LibSharedMedia's if another addon loads it
local function Fonts()
    local list = {
        { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, { "Fonts\\ARIALN.TTF", "Arial Narrow" },
        { "Fonts\\skurri.ttf", "Skurri" }, { "Fonts\\MORPHEUS.ttf", "Morpheus" },
    }
    local lsm = LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local seen = {}
        for _, o in ipairs(list) do seen[o[1]:lower()] = true end
        local extra = {}
        for name, path in pairs(lsm:HashTable("font")) do
            if type(path) == "string" and not seen[path:lower()] then extra[#extra + 1] = { path, name } end
        end
        table.sort(extra, function(a, b) return a[2] < b[2] end)
        for _, o in ipairs(extra) do list[#list + 1] = o end
    end
    for _, o in ipairs(list) do o[3] = o[1] end -- each option drawn in its font
    return list
end

-------------------------------------------------------------------------------
-- Page with tabs: a row of tabs at the top and, under it, one page per tab
-- (two columns, built the first time it is opened). top(strip): fixed
-- controls under the tabs (the bar selector), the same on every tab
-- ({ key, label, build, split }). split = true: a list on the left and its
-- editor on the right, build(left, right). The tabs never move; the open
-- tab is remembered.
-------------------------------------------------------------------------------
local lastTab = {}
local TABS_H, STRIP_H = 34, 32

local function Tabbed(container, name, tabs, top)
    local strip
    if top then
        strip = CreateFrame("Frame", nil, container)
        strip:SetPoint("TOPLEFT", 0, -TABS_H)
        strip:SetPoint("TOPRIGHT", -12, -TABS_H)
        strip:SetHeight(24)
        top(strip)
    end
    local frames, defs, list = {}, {}, {}
    for _, t in ipairs(tabs) do
        list[#list + 1] = { t[1], t[2] }
        defs[t[1]] = t
    end
    local bar = UI.Tabs(container, list, function(key)
        lastTab[name] = key
        for k, f in pairs(frames) do f:SetShown(k == key) end
        if not frames[key] then
            local f = CreateFrame("Frame", nil, container)
            f:SetPoint("TOPLEFT", 0, -TABS_H - (strip and STRIP_H or 0))
            f:SetPoint("BOTTOMRIGHT")
            frames[key] = f
            if defs[key][4] then
                defs[key][3](UI.Split(f, 200))
            else
                defs[key][3](UI.Page(f, 2))
            end
        end
        UI.RefreshAll()
    end)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", -12, 0)
    bar:Select(lastTab[name] or tabs[1][1])
end

-------------------------------------------------------------------------------
-- General: everything that is not about one bar
-------------------------------------------------------------------------------
local function BuildGeneral(container)
    local page = UI.Page(container, 2)

    local gen = page:Add(1, UI.Card(page.content, L["Action bars"],
        L["Replaces Blizzard's action bars."]))
    gen:Add(UI.Switch(gen, L["Enabled"], function() return ns.P.bars.enabled end, function(v)
        ns.P.bars.enabled = v
        ns.SetBarsActive(v)
    end))

    -- unlocking and keybinding mode: the buttons in the window header
    local edit = page:Add(1, UI.Card(page.content, L["Editing"],
        L["Unlock bars (window header): drag a bar to move it, click it to edit it."]))
    edit:Add(UI.Check(edit, L["Snap while moving"], function() return ns.P.bars.snap end,
        function(v) ns.P.bars.snap = v end, { enableIf = active,
            tip = L["Bars stick to other bars, the screen center and the screen edges."] }))

    local misc = page:Add(2, UI.Card(page.content, L["Addon"]))
    misc:Add(UI.Check(misc, L["Minimap button"], function() return not ns.db.minimap.hide end,
        function(v) ns.db.minimap.hide = not v ns.UpdateMinimapButton() end))
    misc:Add(UI.Segmented(misc, L["Language"], { { "enUS", "English" }, { "esES", "Español" } },
        function() return ns.db.language or "enUS" end, function(v)
            ns.SetLanguagePref(v)
            -- the window is built again in the new language, on the same page
            -- (the old window and every control in it are forgotten: they
            -- would keep refreshing and answering for the new one)
            local page = win.current
            local point, _, relPoint, x, y = win:GetPoint(1)
            win:Hide()
            win = nil
            wipe(UI.widgets)
            wipe(UI.pages)
            ns.ToggleOptions()
            -- in the same place on screen
            win:ClearAllPoints()
            win:SetPoint(point, UIParent, relPoint, x, y)
            win:Select(page)
        end))
end

-------------------------------------------------------------------------------
-- Bars: one bar at a time
-------------------------------------------------------------------------------
local selected = 1

local function Select(id)
    selected = id
    if ns.HighlightBar then ns.HighlightBar(id) end
    UI.RefreshAll()
end

-- Clicking an unlocked bar on screen: opens the options on that bar
function ns.SelectBar(id)
    if not win then ns.ToggleOptions() end
    if not win:IsShown() then win:Show() end
    win:Select("bars")
    Select(id)
end

local function BarOptions()
    local list = {}
    for _, id in ipairs(ns.BAR_IDS) do list[#list + 1] = { id, (L["Bar %d"]):format(id) } end
    for _, id in ipairs(ns.HolderIDs()) do list[#list + 1] = { id, ns.HolderName(id) } end
    return list
end

local GROUPS = { pet = true, stance = true, micro = true, bags = true }
local function IsAction() return type(selected) == "number" end
local function HasRows() return IsAction() or GROUPS[selected] or false end
local function BarOn() return ns.BarConfig(selected).enabled end

local function BB(key)
    return function() return ns.BarConfig(selected)[key] end,
        function(v)
            ns.BarConfig(selected)[key] = v
            if ns.barsActive then
                ns.ApplyBar(selected)
                if key == "enabled" and IsAction() then ns.UpdateBinds() end
            end
        end
end

-- control helpers: on = the bar is shown and the control applies to it
local function When(applies)
    return function() return active() and BarOn() and (not applies or applies()) end
end

local function PAGE_OPTIONS(withNone)
    local list = {}
    if withNone then list[1] = { 0, L["None"] } end
    -- the same pages as the bars (7-10 are also the stance / form pages)
    for _, p in ipairs(ns.BAR_IDS) do
        list[#list + 1] = { p, (L["Page %d"]):format(p) }
    end
    return list
end

local function S(c, label, key, minV, maxV, step, fmt, applies, sub)
    local g, s = BB(key)
    c:Add(UI.Slider(c, label, minV, maxV, step, g, s, { format = fmt, enableIf = When(applies), sub = sub }))
end

local function BuildBars(container)
    -- above the tabs: which bar, and whether it is shown
    local function Top(strip)
        local dd = UI.Dropdown(strip, nil, BarOptions(), function() return selected end, Select)
        dd:SetPoint("TOPLEFT")
        dd:SetWidth(220)
        local eg, es = BB("enabled")
        local show = UI.Check(strip, L["Show this bar"], eg, es)
        show:SetPoint("LEFT", dd, "RIGHT", 16, 0)
        show:SetWidth(180)
        if show.OnWidth then show.OnWidth(180) end
    end

    Tabbed(container, "bars", {
        { "layout", L["Layout"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Size"]))
            S(card, L["Buttons"], "buttons", 1, 12, 1, nil, IsAction)
            S(card, L["Rows"], "rows", 1, 12, 1, nil, HasRows)
            S(card, L["Padding"], "padding", -10, 50, 0.5, function(v) return ("%.1f px"):format(v) end, HasRows)
            S(card, L["Button width"], "buttonWidth", 16, 100, 1, UI.px, IsAction)
            S(card, L["Button height"], "buttonHeight", 16, 100, 1, UI.px, IsAction)
            S(card, L["Width"], "width", 200, 1500, 1, UI.px, function() return selected == "status" end)
            S(card, L["Scale"], "scale", 0.5, 2, 0.05, UI.pct)
            S(card, L["Opacity"], "alpha", 0, 1, 0.05, UI.pct)

            card = page:Add(2, UI.Card(page.content, L["Arrangement"]))
            -- each direction only matters with more than one column / row
            local function Count()
                local c = ns.BarConfig(selected)
                return IsAction() and c.buttons or 12
            end
            local function SeveralCols()
                return HasRows() and Count() > ns.BarConfig(selected).rows
            end
            local function SeveralRows()
                return HasRows() and ns.BarConfig(selected).rows > 1 and Count() > 1
            end
            local hg, hs = BB("growH")
            card:Add(UI.Segmented(card, L["Fill"], { { "RIGHT", L["To the right"] }, { "LEFT", L["To the left"] } },
                hg, hs, { enableIf = When(SeveralCols),
                    tip = L["Side where button 1 starts. The bar stays in place."] }))
            local vg, vs = BB("growV")
            card:Add(UI.Segmented(card, nil, { { "DOWN", L["Downwards"] }, { "UP", L["Upwards"] } },
                vg, vs, { enableIf = When(SeveralRows),
                    tip = L["Side where row 1 starts."] }))
            local ig, is = BB("iconFit")
            card:Add(UI.Segmented(card, L["Icon"], {
                { "cover", L["Cover"] }, { "contain", L["Contain"] }, { "stretch", L["Stretch"] },
            }, ig, is, { enableIf = When(IsAction),
                tip = L["Cover: fills, cropped. Contain: whole icon, may leave gaps. Stretch: fills, distorted."] }))
            local cg, cs = BB("clickThrough")
            card:Add(UI.Check(card, L["Click-through"], cg, cs, { enableIf = When(HasRows),
                tip = L["Clicks pass through. Keybinds still work."] }))

            card = page:Add(2, UI.Card(page.content, L["Position"]))
            -- half steps: offsets can be fractional, which matters at UI scales other than 1
            local function halfPx(v) return ((v % 1 == 0) and "%d px" or "%.1f px"):format(v) end
            card:Add(UI.Slider(card, L["X position"], 0, math.ceil(UIParent:GetWidth()), 0.5,
                function() return (ns.BarXY(selected)) end,
                function(v) ns.SetBarXY(selected, v, nil) end, { format = halfPx, enableIf = When() }))
            card:Add(UI.Slider(card, L["Y position"], 0, math.ceil(UIParent:GetHeight()), 0.5,
                function() return select(2, ns.BarXY(selected)) end,
                function(v) ns.SetBarXY(selected, nil, v) end,
                { format = halfPx, enableIf = When(),
                    tip = L["From the screen's bottom-left corner to the bar's top-left corner."] }))
            card:Add(UI.Buttons(card, {
                { L["Center horizontally"], function() ns.CenterBar(selected, "x") UI.RefreshAll() end },
                { L["Center vertically"], function() ns.CenterBar(selected, "y") UI.RefreshAll() end },
            }, { enableIf = When() }))
            local reset = UI.Buttons(card, { { L["Reset this bar"], function()
                ns.P.bars.list[selected] = nil
                -- Blizzard bars: their default place (not where they are now)
                if not IsAction() then ns.BarConfig(selected).pos = ns.HolderDefaultPos(selected) end
                -- bar 1's gryphons are in its options: they go back too
                if selected == 1 then
                    ns.P.bars.gryphons = ns.defaults.bars.gryphons
                    if ns.UpdateGryphons then ns.UpdateGryphons() end
                end
                if ns.barsActive then ns.ApplyBar(selected) if IsAction() then ns.UpdateBinds() end end
                UI.RefreshAll()
            end, "danger" } }, { enableIf = active,
                tip = L["Resets every setting of this bar, position included."] })
            UI.Confirm(reset.buttons[1])
            card:Add(reset)

            -- options only one bar has (greyed out for the rest)
            card = page:Add(1, UI.Card(page.content, L["This bar only"]))
            local function Only(id) return function() return selected == id end end
            local og, os = BB("oneBag")
            card:Add(UI.Check(card, L["Only the backpack"], og, os, { enableIf = When(Only("bags")) }))
            if KeyRingButton then
                local kg, ks = BB("keyring")
                card:Add(UI.Check(card, L["Keyring"], kg, ks, { enableIf = When(Only("bags")) }))
            end
            local ag, as = BB("hideArt")
            card:Add(UI.Check(card, L["Hide the artwork"], ag, as, { enableIf = When(Only("extra")),
                tip = L["The frame around the extra button and the zone ability."] }))
            card:Add(UI.Check(card, L["Gryphons"], function() return ns.P.bars.gryphons end,
                function(v) ns.P.bars.gryphons = v if ns.UpdateGryphons then ns.UpdateGryphons() end end,
                { enableIf = When(Only(1)), tip = L["At the sides of bar 1. Wyverns for the Horde."] }))
        end },

        { "visibility", L["Visibility"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Fade"]))
            local fg, fs = BB("fade")
            card:Add(UI.Check(card, L["Fade out when the mouse is not over it"], fg, fs, { enableIf = When() }))
            local fadeOn = function() return ns.BarConfig(selected).fade end
            S(card, L["Faded opacity"], "fadeAlpha", 0, 1, 0.05, UI.pct, fadeOn, true)
            S(card, L["Delay"], "fadeDelay", 0, 3, 0.1, function(v) return ("%.1f s"):format(v) end, fadeOn, true)

            card = page:Add(2, UI.Card(page.content, L["Hide"]))
            local noCustom = function() return strtrim(ns.BarConfig(selected).custom or "") == "" end
            for _, def in ipairs({
                { "hideCombat", "Hide in combat" }, { "hideNoCombat", "Hide out of combat" },
                { "hidePet", "Hide with a pet" }, { "hideNoPet", "Hide without a pet" },
                { "hideVehicle", "Hide in vehicles" }, { "hideStance", "Hide in a stance or form" },
            }) do
                local g, s = BB(def[1])
                card:Add(UI.Check(card, L[def[2]], g, s, { enableIf = When(noCustom) }))
            end
            local xg, xs = BB("custom")
            card:Add(UI.Input(card, L["Custom conditions"], xg, xs, { enableIf = When(),
                tip = L["Macro conditions, e.g. [combat] show; hide. Overrides the options above."] }))
        end },

        { "actions", L["Actions"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Paging"]))
            local pg, ps = BB("page")
            card:Add(UI.Dropdown(card, L["Page"], PAGE_OPTIONS(false), pg, ps, { enableIf = When(IsAction) }))
            local sg, ss = BB("stancePaging")
            card:Add(UI.Check(card, L["Change page with stance / form"], sg, ss, { enableIf = When(IsAction),
                tip = L["Warrior stances, druid forms, rogue stealth, priest shadowform: pages 7 to 10."] }))

            card = page:Add(1, UI.Card(page.content, L["Modifier keys"],
                L["Hold the key to switch the bar to that page."]))
            for _, mod in ipairs({ { "ctrlPage", "Page with Ctrl" }, { "altPage", "Page with Alt" }, { "shiftPage", "Page with Shift" } }) do
                local g, s = BB(mod[1])
                card:Add(UI.Dropdown(card, L[mod[2]], PAGE_OPTIONS(true), g, s, { enableIf = When(IsAction) }))
            end

            card = page:Add(2, UI.Card(page.content, L["This bar's buttons"]))
            local gg, gs = BB("showGrid")
            card:Add(UI.Check(card, L["Show empty buttons"], gg, gs, { enableIf = When(IsAction) }))
            for _, def in ipairs({ { "hideMacro", "Hide macro names" }, { "hideHotkey", "Hide keybinds" },
                { "hideEquipped", "Hide equipped border" } }) do
                local g, s = BB(def[1])
                card:Add(UI.Check(card, L[def[2]], g, s, { enableIf = When(IsAction) }))
            end

            card = page:Add(2, UI.Card(page.content, L["Flyouts"],
                L["Menus that open from a button (portals, totems, pets...)."]))
            local og, os = BB("flyout")
            card:Add(UI.Dropdown(card, L["Flyout direction"], {
                { "UP", L["Up"] }, { "DOWN", L["Down"] }, { "LEFT", L["Left"] }, { "RIGHT", L["Right"] },
            }, og, os, { enableIf = When(IsAction) }))
        end },
    }, Top)
end

-------------------------------------------------------------------------------
-- Buttons: every action button. Behaviour, then one tab per kind of look:
-- states (while something is true), timers, flashes (a moment) and texts.
-- Each look tab: a list on the left (each one's on/off and color), the one
-- picked on the right, with a sample button.
-------------------------------------------------------------------------------
local PREVIEW = 44

local function Paint(t, c) t:SetColorTexture(c.r, c.g, c.b, c.a or 1) end

-- Sample icons: the first spells on your bar 1 (action slots 1-12); where it
-- has fewer, bright spells of every client (Fireball, Frostbolt, Holy
-- Light, Rejuvenation, Arcane Intellect), asked to the game; the question
-- mark if one is missing
local SAMPLES = 5
local SAMPLE_SPELLS = { 133, 116, 635, 774, 1459 }
local SAMPLE_GAP = 8

local function SpellIcon(id)
    local ok, tex
    if C_Spell and C_Spell.GetSpellTexture then ok, tex = pcall(C_Spell.GetSpellTexture, id) end
    if not (ok and tex) and GetSpellTexture then ok, tex = pcall(GetSpellTexture, id) end
    return ok and tex or nil
end

local function SampleIcons()
    local list = {}
    for slot = 1, 12 do
        if #list == SAMPLES then break end
        local ok, tex = pcall(C_ActionBar.GetActionTexture, slot)
        if ok and tex then list[#list + 1] = tex end
    end
    for _, id in ipairs(SAMPLE_SPELLS) do
        if #list == SAMPLES then break end
        list[#list + 1] = SpellIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return list
end

-- One sample button: an icon with the pieces the real buttons use
local function SampleButton(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(PREVIEW, PREVIEW)
    local edge = p:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.cd = CreateFrame("Cooldown", nil, p, "CooldownFrameTemplate")
    p.cd:SetAllPoints()
    p.cd:SetHideCountdownNumbers(true)
    -- the sample cooldown starts again when it ends
    p.cd:SetScript("OnCooldownDone", function(self)
        if self.loop then self:SetCooldown(GetTime(), self.loop) end
    end)
    -- the rest over the cooldown, like on the buttons
    local top = CreateFrame("Frame", nil, p)
    top:SetAllPoints()
    top:SetFrameLevel(p.cd:GetFrameLevel() + 2)
    -- casting fill: built like the buttons' one (Bars.lua, CastFill)
    p.fill = CreateFrame("StatusBar", nil, top)
    p.fill:SetAllPoints()
    p.fill:SetOrientation("HORIZONTAL")
    p.fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    p.fill:SetMinMaxValues(0, 1)
    p.fill.edge = p.fill:CreateTexture(nil, "OVERLAY")
    p.fill.edge:SetPoint("TOPRIGHT", p.fill:GetStatusBarTexture(), "TOPRIGHT")
    p.fill.edge:SetPoint("BOTTOMRIGHT", p.fill:GetStatusBarTexture(), "BOTTOMRIGHT")
    p.fill.edge:SetWidth(2)
    p.overlay = top:CreateTexture(nil, "ARTWORK", nil, 1)
    p.overlay:SetAllPoints()
    p.flash = top:CreateTexture(nil, "ARTWORK", nil, 2)
    p.flash:SetAllPoints()
    p.flash:SetTexture("Interface\\Buttons\\UI-QuickslotRed")
    p.flash:SetDesaturated(true)
    p.border = top:CreateTexture(nil, "OVERLAY")
    p.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    p.border:SetBlendMode("ADD")
    p.border:SetPoint("CENTER")
    p.border:SetSize(PREVIEW * 1.75, PREVIEW * 1.75)
    p.text = top:CreateFontString(nil, "OVERLAY")
    return p
end

-- A row of sample buttons, centered. draw(p) puts one look on each with the
-- current settings.
local function Preview(parent, draw)
    local r = UI.Row(parent, PREVIEW + 12)
    local width = SAMPLES * PREVIEW + (SAMPLES - 1) * SAMPLE_GAP
    local list = {}
    for i = 1, SAMPLES do
        local p = SampleButton(r)
        p:SetPoint("TOPLEFT", r, "TOP", -width / 2 + (i - 1) * (PREVIEW + SAMPLE_GAP), -6)
        list[i] = p
    end
    r.Refresh = function()
        local icons = SampleIcons()
        for i, p in ipairs(list) do
            p.icon:SetTexture(icons[i])
            p.icon:SetVertexColor(1, 1, 1, 1)
            p.cd.loop = nil
            p.cd:Clear()
            p.fill:SetScript("OnUpdate", nil)
            p.fill:Hide()
            p.overlay:Hide()
            p.flash:Hide()
            p.border:Hide()
            p.text:Hide()
            draw(p)
        end
    end
    table.insert(UI.widgets, r)
    return r
end

-- Sample pieces
local function Tint(p, c) p.icon:SetVertexColor(c.r, c.g, c.b, c.a or 1) end
local function Overlay(p, c) Paint(p.overlay, c) p.overlay:Show() end
local function SampleText(p, t, text, color)
    local c = color or t.color
    p.text:SetFont(t.font, t.size, t.outline)
    p.text:SetTextColor(c.r, c.g, c.b, c.a or 1)
    p.text:ClearAllPoints()
    p.text:SetPoint(t.point, p, t.point, t.x, t.y)
    p.text:SetText(text)
    p.text:Show()
end
-- a sample cast: fills in CAST_TIME seconds, then starts again (only runs
-- while the sample is on screen)
local CAST_TIME = 2
local function CastTick(f)
    f:SetValue((GetTime() % CAST_TIME) / CAST_TIME)
end
local function SampleCast(p, c, spark)
    p.fill:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    if spark then p.fill.edge:SetColorTexture(spark.r, spark.g, spark.b, spark.a or 1) end
    p.fill.edge:SetShown(spark and true or false)
    p.fill:SetScript("OnUpdate", CastTick)
    CastTick(p.fill)
    p.fill:Show()
end
local function SampleCooldown(p, alpha, seconds)
    p.cd:SetSwipeColor(0, 0, 0, alpha)
    p.cd.loop = seconds
    p.cd:SetCooldown(GetTime(), seconds)
end

-- One look tab. items: { label, t = the settings table, show = on/off key,
-- color = color key, icons = true (Icons' settings), enable() (only
-- when it can be seen), colorIf() (only when its color is used), note
-- (the editor's subtitle, like other cards), draw(p), extra(card, on) }.
-- keys: what its Defaults puts back ({ table, defaults, list of keys }).
local function LookTab(left, right, title, items, keys)
    local sel = 1
    local function Apply(it)
        if it.icons then ns.ApplyIcons() else ApplyAllBars() end
    end

    local card = left:Add(1, UI.Card(left.content, title))
    card:Add(UI.List(card, {
        rows = #items,
        items = function() return items end,
        label = function(it) return it.label end,
        lead = "swatch",
        color = function(it)
            local c = it.color and it.t()[it.color]
            return c and { c.r, c.g, c.b }
        end,
        checked = function(it)
            if it.show then return it.t()[it.show] and true or false end
        end,
        onCheck = function(it, v) it.t()[it.show] = v Apply(it) end,
        off = function(it) return it.enable and not it.enable() end,
        selected = function(_, i) return i == sel end,
        onSelect = function(i) sel = i UI.RefreshAll() end,
    }))
    -- like every reset: red, and a second click to confirm
    local reset = UI.Buttons(card, { { L["Defaults"], function()
        for _, k in ipairs(keys) do
            local t, d = k[1](), k[2]()
            for _, key in ipairs(k[3]) do t[key] = ns.Copy(d[key]) end
        end
        ApplyAllBars()
        ns.ApplyIcons()
        UI.RefreshAll()
    end, "danger" } }, { tip = L["Resets every setting in this tab."] })
    UI.Confirm(reset.buttons[1])
    card:Add(reset)

    for i, it in ipairs(items) do
        local ed = right:Add(1, UI.Card(right.content, it.label, it.note))
        ed.showIf = function() return sel == i end
        local function on()
            return (not it.show or it.t()[it.show]) and (not it.enable or it.enable()) and true or false
        end
        ed:Add(Preview(ed, function(p) if on() then it.draw(p) end end))
        if it.color then
            ed:Add(UI.Swatch(ed, L["Color"], function() return it.t()[it.color] end,
                function() Apply(it) end, { alpha = true,
                    enableIf = function() return on() and (not it.colorIf or it.colorIf()) end }))
        end
        if it.extra then it.extra(ed, on) end
    end
end

local function BuildButtons(container)
    local function G() return ns.P.bars.buttons end
    local function I() return ns.P.icons end
    local function GB(key)
        return function() return G()[key] end, function(v) G()[key] = v ApplyAllBars() end
    end
    local K = function() return ns.P.bars.casting end
    local function KB(key, also)
        return function() return K()[key] end, function(v) K()[key] = v if also then also(v) end ApplyAllBars() end
    end
    local function DG() return ns.defaults.bars.buttons end
    local function DI() return ns.defaults.icons end
    -- hover / pressed / active are drawn by the square look
    local function Square() return I().enabled and I().actionbars and true or false end
    local flatOn = function() return G().castVFX and G().castStyle == "flat" end

    Tabbed(container, "buttons", {
        { "behaviour", L["Behaviour"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Behaviour"],
                L["For every button of Tidy's action bars."]))
            local tg, ts = GB("tooltip")
            card:Add(UI.Segmented(card, L["Tooltips"], {
                { "enabled", L["Always"] }, { "nocombat", L["Out of combat"] }, { "disabled", L["Never"] },
            }, tg, ts))
            local lg, ls = GB("lock")
            card:Add(UI.Check(card, L["Lock buttons"], lg, ls, { tip = L["Spells can't be dragged off. Shift-drag still works."] }))
            card:Add(UI.Check(card, L["Cast on key down"], function() return GetCVarBool("ActionButtonUseKeyDown") end,
                function(v) SetCVar("ActionButtonUseKeyDown", v and "1" or "0") end, { tip = L["Game setting: also affects Blizzard's bars."] }))

            local MODS = { { "ALT", "Alt" }, { "CTRL", "Ctrl" }, { "SHIFT", "Shift" }, { "NONE", L["None"] } }
            local function ModDropdown(c, label, click, enable)
                c:Add(UI.Dropdown(c, label, MODS, function() return GetModifiedClick(click) end, function(v)
                    SetModifiedClick(click, v)
                    SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
                end, { enableIf = enable, sub = true }))
            end

            card = page:Add(1, UI.Card(page.content, L["Focus"]))
            local g, s = KB("focusCast")
            card:Add(UI.Check(card, L["Focus-cast with a key"], g, s))
            ModDropdown(card, L["Focus-cast key"], "FOCUSCAST", function() return K().focusCast end)

            card = page:Add(2, UI.Card(page.content, L["Self-cast"]))
            g, s = KB("selfCast")
            card:Add(UI.Check(card, L["Self-cast with a key"], g, s))
            ModDropdown(card, L["Self-cast key"], "SELFCAST", function() return K().selfCast end)
            g, s = KB("rightClickSelf")
            card:Add(UI.Check(card, L["Right click casts on yourself"], g, s))

            card = page:Add(2, UI.Card(page.content, L["Mouse-over"]))
            g, s = KB("mouseover", function(v) SetCVar("enableMouseoverCast", v and "1" or "0") end)
            card:Add(UI.Check(card, L["Mouse-over casting"], g, s, { tip = L["Spells go to the unit under the mouse."] }))
            ModDropdown(card, L["Mouse-over key"], "MOUSEOVERCAST", function() return K().mouseover end)

            -- like every reset: red, and a second click to confirm
            card = page:Add(2, UI.Card(page.content, L["Defaults"]))
            local reset = UI.Buttons(card, { { L["Defaults"], function()
                G().tooltip, G().lock = DG().tooltip, DG().lock
                local t = K()
                wipe(t)
                for k, v in pairs(ns.Copy(ns.defaults.bars.casting)) do t[k] = v end
                ApplyAllBars()
                UI.RefreshAll()
            end, "danger" } }, { tip = L["Resets every setting in this tab."] })
            UI.Confirm(reset.buttons[1])
            card:Add(reset)
        end },

        { "states", L["States"], function(left, right)
            local function State(label, t, show, color, draw, more)
                local it = { label = label, t = t, show = show, color = color, draw = draw }
                for k, v in pairs(more or {}) do it[k] = v end
                return it
            end
            local function Flashing(key)
                return function(p)
                    local c = G()[key]
                    p.flash:SetVertexColor(c.r, c.g, c.b, c.a or 1)
                    p.flash:Show()
                end
            end
            -- drawn by the square look; without it, Blizzard's own
            local SQUARE = { icons = true, enable = Square, note = L["Needs square icons on action bars (Icons page)."] }
            LookTab(left, right, L["States"], {
                State(L["Hover"], I, "hoverShow", "hoverColor", function(p) Overlay(p, I().hoverColor) end, SQUARE),
                State(L["Pressed"], I, "pushShow", "pushColor", function(p) Overlay(p, I().pushColor) end, SQUARE),
                State(L["Active"], I, "checkShow", "checkColor", function(p) Overlay(p, I().checkColor) end, SQUARE),
                State(L["Attacking"], G, "attackShow", "attackColor", Flashing("attackColor")),
                State(L["Auto-repeat"], G, "autoRepeatShow", "autoRepeatColor", Flashing("autoRepeatColor")),
                State(L["Out of range"], G, "rangeShow", "rangeColor", function(p)
                    if G().range == "hotkey" then SampleText(p, G().texts.hotkey, "1", G().rangeColor)
                    else Tint(p, G().rangeColor) end
                end, { extra = function(card, on)
                    local rg, rs = GB("range")
                    card:Add(UI.Segmented(card, L["Tints"], { { "button", L["Button"] }, { "hotkey", L["Keybind"] } },
                        rg, rs, { enableIf = on }))
                end }),
                State(L["Out of mana"], G, "manaShow", "manaColor", function(p) Tint(p, G().manaColor) end),
                State(L["Not usable"], G, "unusableShow", "unusableColor", function(p) Tint(p, G().unusableColor) end),
                State(L["Equipped"], G, "equipShow", "equipColor", function(p)
                    local c = G().equipColor
                    p.border:SetVertexColor(c.r, c.g, c.b, c.a or 1)
                    p.border:Show()
                end),
            }, {
                { G, DG, { "rangeShow", "range", "rangeColor", "manaShow", "manaColor", "unusableShow", "unusableColor",
                    "attackShow", "attackColor", "autoRepeatShow", "autoRepeatColor", "equipShow", "equipColor" } },
                { I, DI, { "hoverShow", "hoverColor", "pushShow", "pushColor", "checkShow", "checkColor" } },
            })
        end, true },

        { "timers", L["Timers"], function(left, right)
            LookTab(left, right, L["Timers"], {
                { label = L["Cooldown"], t = G, draw = function(p) SampleCooldown(p, G().cooldownAlpha, 12) end,
                    extra = function(card)
                        local cg, cs = GB("cooldownAlpha")
                        card:Add(UI.Slider(card, L["Darkness"], 0, 1, 0.05, cg, cs, { format = UI.pct }))
                    end },
                { label = L["Global cooldown"], t = G, draw = function(p)
                    SampleCooldown(p, G().gcdAlpha, 1.5)
                    p.cd:SetDrawEdge(G().gcdSpark and true or false)
                    local c = G().gcdSparkColor
                    if p.cd.SetEdgeColor then p.cd:SetEdgeColor(c.r, c.g, c.b, c.a or 1) end
                end, extra = function(card)
                    local gg, gs = GB("gcdAlpha")
                    card:Add(UI.Slider(card, L["Darkness"], 0, 1, 0.05, gg, gs, { format = UI.pct,
                        tip = L["When the game doesn't flag the GCD, Cooldown darkness is used."] }))
                    local sg, ss = GB("gcdSpark")
                    card:Add(UI.Check(card, L["Spark"], sg, ss,
                        { tip = L["Bright line on the sweep edge."] }))
                    card:Add(UI.Swatch(card, L["Color"], function() return G().gcdSparkColor end, ApplyAllBars,
                        { alpha = true, sub = true, enableIf = function() return G().gcdSpark end }))
                end },
                { label = L["Casting"], t = G, show = "castVFX", color = "castFillColor", colorIf = flatOn,
                    note = L["Blizzard style has no preview: it only plays on a real cast."],
                    draw = function(p)
                        if G().castStyle == "flat" then
                            SampleCast(p, G().castFillColor, G().castSpark and G().castSparkColor)
                        end
                    end, extra = function(card, on)
                    local stg, sts = GB("castStyle")
                    card:Add(UI.Segmented(card, L["Style"], { { "flat", L["Flat"] }, { "blizzard", L["Blizzard"] } }, stg, sts,
                        { enableIf = on, tip = L["Flat: the button fills during a cast, empties during a channel. Blizzard: the game's animation."] }))
                    local sg, ss = GB("castSpark")
                    card:Add(UI.Check(card, L["Spark"], sg, ss, { enableIf = flatOn,
                        tip = L["Bright line on the fill edge."] }))
                    card:Add(UI.Swatch(card, L["Color"], function() return G().castSparkColor end, ApplyAllBars,
                        { alpha = true, sub = true, enableIf = function() return flatOn() and G().castSpark end }))
                end },
            }, {
                { G, DG, { "cooldownAlpha", "gcdAlpha", "gcdSpark", "gcdSparkColor", "castVFX", "castStyle", "castFillColor",
                    "castSpark", "castSparkColor" } },
            })
        end, true },

        { "flashes", L["Flashes"], function(left, right)
            local function FlashItem(label, key, colorKey, note, enable)
                return { label = label, t = G, show = key, color = colorKey, enable = enable, note = note,
                    draw = function(p) Overlay(p, G()[colorKey]) end }
            end
            LookTab(left, right, L["Flashes"], {
                FlashItem(L["Pressed on cooldown"], "cdPress", "cdPressColor"),
                FlashItem(L["Pressed on global cooldown"], "gcdPress", "gcdPressColor"),
                FlashItem(L["Pressed when not usable"], "failPress", "failPressColor",
                    L["No target, out of range, not enough power, not usable..."]),
                FlashItem(L["Pressed on an empty slot"], "emptyPress", "emptyPressColor",
                    L["Works on hidden empty slots too."]),
                FlashItem(L["Pressed while active"], "activePress", "activePressColor",
                    L["Queued next-swing spell, auto attack, current stance."]),
                FlashItem(L["Ready"], "readyFlash", "readyColor",
                    L["When a cooldown of 2 seconds or more ends."]),
                FlashItem(L["Interrupted"], "interruptFlash", "interruptColor",
                    L["Needs the Flat style (Timers > Casting)."], flatOn),
            }, {
                { G, DG, { "cdPress", "cdPressColor", "gcdPress", "gcdPressColor", "failPress", "failPressColor",
                    "emptyPress", "emptyPressColor", "activePress", "activePressColor", "readyFlash", "readyColor", "interruptFlash", "interruptColor" } },
            })
        end, true },

        { "texts", L["Texts"], function(left, right)
            local SAMPLE = { hotkey = "1", count = "3", macro = L["Macro"], cooldown = "8" }
            local function TextItem(key, label)
                local function T() return G().texts[key] end
                local function TB(field)
                    return function() return T()[field] end, function(v) T()[field] = v ApplyAllBars() end
                end
                return { label = label, t = T, show = "show", color = "color",
                    note = key ~= "cooldown" and L["Per-bar hide: Bars > Actions."] or nil,
                    draw = function(p) SampleText(p, T(), SAMPLE[key]) end,
                    extra = function(card, on)
                        local fg, fs = TB("font")
                        card:Add(UI.Dropdown(card, L["Font"], Fonts, fg, fs, { enableIf = on }))
                        local zg, zs = TB("size")
                        card:Add(UI.Slider(card, L["Size"], 6, 30, 1, zg, zs, { format = UI.px, enableIf = on }))
                        local og, os = TB("outline")
                        card:Add(UI.Segmented(card, L["Outline"], OUTLINES(), og, os, { enableIf = on }))
                        local pg, ps = TB("point")
                        card:Add(UI.Dropdown(card, L["Position"], POINTS, pg, ps, { enableIf = on }))
                        local xg, xs = TB("x")
                        card:Add(UI.Slider(card, L["X offset"], -20, 20, 1, xg, xs, { format = UI.px, enableIf = on, sub = true }))
                        local yg, ys = TB("y")
                        card:Add(UI.Slider(card, L["Y offset"], -20, 20, 1, yg, ys, { format = UI.px, enableIf = on, sub = true }))
                    end }
            end
            LookTab(left, right, L["Texts"], {
                TextItem("hotkey", L["Keybind"]),
                TextItem("count", L["Count"]),
                TextItem("macro", L["Macro name"]),
                TextItem("cooldown", L["Cooldown"]),
            }, {
                { G, DG, { "texts" } },
            })
        end, true },
    })
end

-------------------------------------------------------------------------------
-- Icons
-------------------------------------------------------------------------------
local function IB(key, look)
    return function() return ns.P.icons[key] end,
        function(v)
            ns.P.icons[key] = v
            if look then ns.ApplyIcons() else ns.RefreshIcons() end
        end
end

local function BuildIcons(container)
    local page = UI.Page(container, 2)
    local O = function() return ns.P.icons end
    local on = function() return O().enabled end

    local where = page:Add(1, UI.Card(page.content, L["Where"], L["Square icons with a flat border."]))
    where:Add(UI.Switch(where, L["Enabled"], IB("enabled")))
    for _, def in ipairs({
        { "actionbars", "Action bars", "Tidy and Blizzard bars, pet and stance bars." },
        { "playerAuras", "Your buffs and debuffs" },
        { "unitAuras", "Target and focus auras" },
        { "raidAuras", "Raid and party frame auras", "Blizzard's frames (Tile draws its own)." },
        { "items", "Items", "Bags, bank, loot, merchant, character..." },
    }) do
        local get, set = IB(def[1])
        where:Add(UI.Check(where, L[def[2]], get, set, { enableIf = on, tip = def[3] and L[def[3]] }))
    end

    local look = page:Add(2, UI.Card(page.content, L["Look"]))
    local sg, ss = IB("size", true)
    look:Add(UI.Slider(look, L["Border thickness"], 1, 4, 1, sg, ss, { format = UI.px, enableIf = on }))
    look:Add(UI.Swatch(look, L["Border color"], function() return O().color end, ns.ApplyIcons,
        { alpha = true, enableIf = on }))
    look:Add(UI.Swatch(look, L["Background"], function() return O().background end, ns.ApplyIcons,
        { alpha = true, enableIf = on, tip = L["Shown on empty buttons. Opacity 0 hides it."] }))
    local zg, zs = IB("zoom", true)
    look:Add(UI.Slider(look, L["Zoom"], 0, 0.15, 0.01, zg, zs, { format = UI.pct, enableIf = on,
        tip = L["Crops the icon edge. Blizzard icons have a ~8% bevel."] }))
    local dg, ds = IB("debuffColor", true)
    look:Add(UI.Check(look, L["Debuff type color"], dg, ds, { enableIf = on,
        tip = L["Debuff border by type (magic, curse, poison...) instead of the chosen color."] }))
    local qg, qs = IB("qualityColor", true)
    look:Add(UI.Check(look, L["Item quality color"], qg, qs, { enableIf = on,
        tip = L["Item border by rarity (green, blue, purple...) instead of the chosen color."] }))

    -- like every reset: red, and a second click to confirm
    local reset = UI.Buttons(look, { { L["Defaults"], function()
        local keep = {}
        for _, k in ipairs(KEEP_ICONS) do keep[k] = ns.P.icons[k] end
        ns.ResetModule("icons")
        for k, v in pairs(keep) do ns.P.icons[k] = v end
        ns.ApplyIcons()
        UI.RefreshAll()
    end, "danger" } }, { tip = L["Resets the look. Where is kept."] })
    UI.Confirm(reset.buttons[1])
    look:Add(reset)
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
local function ProfileList(excludeCurrent)
    local out = {}
    for _, name in ipairs(ns.ProfileNames()) do
        if not (excludeCurrent and name == ns.profileName) then out[#out + 1] = { name, name } end
    end
    return out
end

local function BuildProfiles(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["This character"],
        L["One profile holds every setting. Several characters can share it."]))
    card:Add(UI.Dropdown(card, L["Profile in use"], function() return ProfileList(false) end,
        function() return ns.profileName end, function(v) ns.UseProfile(v) UI.RefreshAll() end))
    local newName = { text = "" }
    card:Add(UI.Input(card, L["New profile"], function() return newName.text end, function(v)
        v = strtrim(v or "")
        if v == "" then return end
        ns.UseProfile(v)
        newName.text = ""
        UI.RefreshAll()
    end, { tip = L["Type a name, press Enter. Starts with default settings."] }))

    card = page:Add(1, UI.Card(page.content, L["Copy and reset"]))
    local copy = {}
    card:Add(UI.Dropdown(card, L["Copy from"], function() return ProfileList(true) end,
        function() return copy.from end, function(v) copy.from = v end))
    card:Add(UI.Buttons(card, {
        { L["Copy into this profile"], function()
            if copy.from then ns.CopyProfile(copy.from) UI.RefreshAll() end
        end },
    }, { enableIf = function() return copy.from ~= nil end }))
    local reset = UI.Buttons(card, {
        { L["Reset this profile"], function() ns.ResetProfile() UI.RefreshAll() end, "danger" },
    })
    UI.Confirm(reset.buttons[1])
    card:Add(reset)
    local del = {}
    card:Add(UI.Dropdown(card, L["Delete profile"], function() return ProfileList(true) end,
        function() return del.name end, function(v) del.name = v end))
    local delBtn = UI.Buttons(card, {
        { L["Delete"], function()
            if del.name then ns.DeleteProfile(del.name) del.name = nil UI.RefreshAll() end
        end, "danger" },
    }, { enableIf = function() return del.name ~= nil end })
    UI.Confirm(delBtn.buttons[1])
    card:Add(delBtn)

    card = page:Add(2, UI.Card(page.content, L["Share"], L["Export this profile as text, or paste one to import it."]))
    local box = card:Add(UI.CodeBox(card, 160))
    -- the message line is always there (empty or not): no layout jumps
    local status = card:Add(UI.Note(card, " "))
    card:Add(UI.Buttons(card, {
        { L["Export"], function()
            box.edit:SetText(ns.ExportProfile())
            box.edit:SetFocus()
            box.edit:HighlightText()
            status.text:SetText(L["Copied to the box: press Ctrl+C."])
        end, "accent" },
        { L["Import"], function()
            UI.Dialog(L["This replaces every setting of the profile in use. Continue?"], L["Import"], function()
                local ok, err = ns.ImportProfile(box.edit:GetText())
                status.text:SetText(ok and ("|cff6bd66b" .. L["Profile imported."] .. "|r") or ("|cffff6b61" .. err .. "|r"))
                UI.RefreshAll()
            end)
        end },
    }))

    -- presets are actions: one button each, asking to confirm
    card = page:Add(2, UI.Card(page.content, L["Presets"],
        L["Sets position, rows, padding and scale of bars 1 and 3-6. Nothing else changes."]))
    local presets = UI.Buttons(card, {
        { L["Blizzard-like"], function() ns.ApplyPreset("blizzard") UI.RefreshAll() end, "danger" },
        { L["Compact"], function() ns.ApplyPreset("compact") UI.RefreshAll() end, "danger" },
        { L["Split"], function() ns.ApplyPreset("split") UI.RefreshAll() end, "danger" },
    }, { enableIf = active })
    for _, b in ipairs(presets.buttons) do UI.Confirm(b) end
    card:Add(presets)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function Build()
    win = UI.Window({ name = "TidyOptions", title = "Tidy", version = ns.version,
        logo = "Interface\\AddOns\\Tidy\\Media\\Icon",
        width = 680, height = 520, navWidth = 110 })
    -- header buttons, lit while on (any page)
    local bindBtn = win:AddHeaderButton(L["Keybinding mode"], function()
        if ns.barsActive then ns.SetBindMode(not ns.bindMode) end
        UI.RefreshAll()
    end, function() return ns.bindMode and true or false end, L["Hover a button and press a key. Esc to leave."])
    local lockBtn = win:AddHeaderButton(L["Unlock bars"], function()
        if ns.barsActive then ns.SetBarsLocked(not ns.P.bars.locked) end
        UI.RefreshAll()
    end, function() return not ns.P.bars.locked end, L["Drag a bar to move it, click it to edit it."])
    -- both only work on Tidy's bars: greyed while they are off
    for _, b in ipairs({ bindBtn, lockBtn }) do
        local paint = b.Refresh
        b.Refresh = function(self)
            paint(self)
            UI.SetEnabled(self, ns.barsActive and true or false)
        end
    end
    win:AddNav("general", L["General"], BuildGeneral)
    win:AddNav("bars", L["Bars"], BuildBars, active)
    win:AddNav("buttons", L["Buttons"], BuildButtons)
    win:AddNav("icons", L["Icons"], BuildIcons, function() return ns.P.icons.enabled end)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle((L["Profile: %s"]):format(ns.profileName or ""))
        win:SetStatus(ns.barsConflict and L["%s is loaded: Tidy's bars stay off. Disable one of them and reload."]:format(ns.barsConflict) or "")
    end
    -- changes made outside the window (minimap, Esc, combat) refresh it
    ns.OnBindMode = function() UI.RefreshAll() end
    ns.OnBarsLocked = function() UI.RefreshAll() end
    ns.OnBarMoved = function() UI.RefreshAll() end
    win:Select("general")
end

function ns.ToggleOptions()
    if not win then Build() win:Show() return end
    win:Toggle()
end
