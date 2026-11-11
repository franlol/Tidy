-------------------------------------------------------------------------------
-- Tidy - Options window (LibFlatyUI-1.0)
--
--   General  : everything global: bars on/off, snap, presets,
--              minimap, language (unlock / keybinding mode: window header)
--   Bars     : one bar at a time (dropdown, or click it on screen):
--              layout · visibility · actions
--   Buttons  : every action button: behaviour (with casting) · look (with texts)
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
local WHERE = { "enabled", "actionbars", "playerAuras", "unitAuras", "raidAuras", "items" }
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
-- ({ key, label, build }). The tabs never move; the open tab is remembered.
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
            defs[key][3](UI.Page(f, 2))
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
        L["Your spells and keybinds, on bars you place. Replaces Blizzard's action bars."]))
    gen:Add(UI.Switch(gen, L["Enabled"], function() return ns.P.bars.enabled end, function(v)
        ns.P.bars.enabled = v
        ns.SetBarsActive(v)
    end))

    -- unlocking and keybinding mode: the buttons in the window header
    local edit = page:Add(1, UI.Card(page.content, L["Editing"],
        L["Unlock bars (top of the window) and drag a bar to move it, or click it to edit it."]))
    edit:Add(UI.Check(edit, L["Snap while moving"], function() return ns.P.bars.snap end,
        function(v) ns.P.bars.snap = v end, { enableIf = active,
            tip = L["A bar you drag sticks to the edges and centers of other bars, the screen center lines and the screen borders."] }))

    -- presets are actions: one button each, asking to confirm
    local pre = page:Add(2, UI.Card(page.content, L["Presets"],
        L["Places the action bars 1 and 3-6 in a ready layout (position, rows, padding, scale). The other settings stay."]))
    local presets = UI.Buttons(pre, {
        { L["Blizzard-like"], function() ns.ApplyPreset("blizzard") UI.RefreshAll() end, "danger" },
        { L["Compact"], function() ns.ApplyPreset("compact") UI.RefreshAll() end, "danger" },
        { L["Split"], function() ns.ApplyPreset("split") UI.RefreshAll() end, "danger" },
    }, { enableIf = active })
    for _, b in ipairs(presets.buttons) do UI.Confirm(b) end
    pre:Add(presets)

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
    -- 1-10: the usual pages (7-10 are also the stance / form pages);
    -- 13-15: the pages of the extra bars 13-15 (11 and 12 are the game's
    -- vehicle / possess pages, not for free use)
    for _, p in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }) do
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
                    tip = L["Where button 1 is and which way the others follow. The bar does not move."] }))
            local vg, vs = BB("growV")
            card:Add(UI.Segmented(card, nil, { { "DOWN", L["Downwards"] }, { "UP", L["Upwards"] } },
                vg, vs, { enableIf = When(SeveralRows),
                    tip = L["Which row comes first. Only with more than one row."] }))
            local ig, is = BB("iconFit")
            card:Add(UI.Segmented(card, L["Icon"], {
                { "cover", L["Cover"] }, { "contain", L["Contain"] }, { "stretch", L["Stretch"] },
            }, ig, is, { enableIf = When(IsAction),
                tip = L["Cover: fills the button, cropped. Contain: the whole icon, centered. Stretch: fills it, deformed."] }))
            local cg, cs = BB("clickThrough")
            card:Add(UI.Check(card, L["Click-through"], cg, cs, { enableIf = When(HasRows),
                tip = L["The mouse goes through the buttons (keybinds still work)."] }))

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
                    tip = L["From the bottom left corner of the screen to the top left corner of the bar."] }))
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
                tip = L["Every setting of this bar back to its default, position included."] })
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
                tip = L["The decorative frame around the extra button and the zone ability."] }))
            card:Add(UI.Check(card, L["Gryphons"], function() return ns.P.bars.gryphons end,
                function(v) ns.P.bars.gryphons = v if ns.UpdateGryphons then ns.UpdateGryphons() end end,
                { enableIf = When(Only(1)), tip = L["Blizzard's gryphons (wyverns for the Horde) at the sides of bar 1."] }))
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
                tip = L["Macro conditions, e.g. [combat] show; hide. When set, they replace the options above."] }))
        end },

        { "actions", L["Actions"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Paging"],
                L["Which page of actions the bar shows. Action bars only."]))
            local pg, ps = BB("page")
            card:Add(UI.Dropdown(card, L["Page"], PAGE_OPTIONS(false), pg, ps, { enableIf = When(IsAction) }))
            local sg, ss = BB("stancePaging")
            card:Add(UI.Check(card, L["Change page with stance / form"], sg, ss, { enableIf = When(IsAction),
                tip = L["Warrior stances, druid forms, rogue stealth, priest shadowform: pages 7 to 10."] }))

            card = page:Add(1, UI.Card(page.content, L["Modifier keys"],
                L["While the key is held, the bar shows another page."]))
            for _, mod in ipairs({ { "ctrlPage", "Page with Ctrl" }, { "altPage", "Page with Alt" }, { "shiftPage", "Page with Shift" } }) do
                local g, s = BB(mod[1])
                card:Add(UI.Dropdown(card, L[mod[2]], PAGE_OPTIONS(true), g, s, { enableIf = When(IsAction) }))
            end

            card = page:Add(2, UI.Card(page.content, L["This bar's buttons"],
                L["What the buttons of this bar show. Action bars only."]))
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
-- Buttons: every action button
-------------------------------------------------------------------------------
local function BuildButtons(container)
    local function G() return ns.P.bars.buttons end
    local function GB(key)
        return function() return G()[key] end, function(v) G()[key] = v ApplyAllBars() end
    end
    local K = function() return ns.P.bars.casting end
    local function KB(key, also)
        return function() return K()[key] end, function(v) K()[key] = v if also then also(v) end ApplyAllBars() end
    end

    Tabbed(container, "buttons", {
        { "behaviour", L["Behaviour"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Behaviour"],
                L["For every button of Tidy's action bars."]))
            local tg, ts = GB("tooltip")
            card:Add(UI.Segmented(card, L["Tooltips"], {
                { "enabled", L["Always"] }, { "nocombat", L["Out of combat"] }, { "disabled", L["Never"] },
            }, tg, ts))
            local lg, ls = GB("lock")
            card:Add(UI.Check(card, L["Lock buttons"], lg, ls, { tip = L["Spells cannot be dragged off the bars (Shift + drag still can)."] }))
            card:Add(UI.Check(card, L["Cast on key down"], function() return GetCVarBool("ActionButtonUseKeyDown") end,
                function(v) SetCVar("ActionButtonUseKeyDown", v and "1" or "0") end, { tip = L["A game setting: for every bar."] }))

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
        end },

        { "look", L["Look"], function(page)
            local card = page:Add(1, UI.Card(page.content, L["Cooldowns"]))
            local cg, cs = GB("cooldownAlpha")
            card:Add(UI.Slider(card, L["Cooldown darkness"], 0, 1, 0.05, cg, cs, { format = UI.pct,
                tip = L["How dark the cooldown is over the icon. Lower it to see the icon better."] }))
            local gg, gs = GB("gcdAlpha")
            card:Add(UI.Slider(card, L["Global cooldown darkness"], 0, 1, 0.05, gg, gs, { format = UI.pct,
                tip = L["How dark the global cooldown alone is, so a real cooldown stands out. If the game does not tell which one it is, the cooldown darkness is used."] }))
            local sg, ss = GB("gcdSpark")
            card:Add(UI.Check(card, L["Global cooldown spark"], sg, ss,
                { tip = L["A bright line that follows the global cooldown as it turns."] }))
            -- sub-options (sub = true) sit right under their checkbox
            card:Add(UI.Swatch(card, L["Color"], function() return G().gcdSparkColor end, ApplyAllBars,
                { alpha = true, sub = true, enableIf = function() return G().gcdSpark end }))
            local vg, vs = GB("castVFX")
            card:Add(UI.Check(card, L["Cast animation"], vg, vs))
            local castOn = function() return G().castVFX end
            local flatOn = function() return G().castVFX and G().castStyle == "flat" end
            local stg, sts = GB("castStyle")
            card:Add(UI.Segmented(card, L["Style"], { { "flat", L["Flat"] }, { "blizzard", L["Blizzard"] } }, stg, sts,
                { sub = true, enableIf = castOn, tip = L["Flat: the button fills as the cast goes (a channel empties); its interrupt flash is in Colors. Blizzard: the game's animation."] }))
            card:Add(UI.Swatch(card, L["Casting fill"], function() return G().castFillColor end, ApplyAllBars,
                { alpha = true, sub = true, enableIf = flatOn }))

            card = page:Add(1, UI.Card(page.content, L["Colors"]))
            local rg, rs = GB("range")
            card:Add(UI.Segmented(card, L["Out of range"], {
                { "button", L["Button"] }, { "hotkey", L["Keybind"] }, { "none", L["Nothing"] },
            }, rg, rs, { tip = L["What turns red when the target is out of range: the button or its keybind."] }))
            card:Add(UI.Swatch(card, L["Out of range color"], function() return G().rangeColor end, ApplyAllBars,
                { alpha = true, sub = true, enableIf = function() return G().range ~= "none" end }))
            card:Add(UI.Swatch(card, L["Out of mana color"], function() return G().manaColor end, ApplyAllBars, { alpha = true }))
            card:Add(UI.Swatch(card, L["Not usable color"], function() return G().unusableColor end, ApplyAllBars,
                { alpha = true, tip = L["The icon when it cannot be used now (wrong form, needs a target, no reagents...)."] }))
            -- every flash: an on/off, its color right under it
            local function FlashRow(key, colorKey, label, tip, also)
                local fg, fs = GB(key)
                card:Add(UI.Check(card, label, fg, fs, { tip = tip, enableIf = also }))
                card:Add(UI.Swatch(card, L["Color"], function() return G()[colorKey] end, ApplyAllBars,
                    { alpha = true, sub = true, enableIf = function() return G()[key] and (not also or also()) end }))
            end
            FlashRow("cdPress", "cdPressColor", L["Pressed on cooldown"],
                L["A short flash when you press a button that is on cooldown."])
            FlashRow("gcdPress", "gcdPressColor", L["Pressed on global cooldown"],
                L["A short flash when you press a button while only the global cooldown runs."])
            FlashRow("failPress", "failPressColor", L["Pressed when not usable"],
                L["A short flash when you press a button and it fails: no target, out of range, not enough power, not usable..."])
            FlashRow("emptyPress", "emptyPressColor", L["Pressed on an empty slot"],
                L["A short flash where you press a key whose slot has no spell, even if empty slots are hidden."])
            FlashRow("readyFlash", "readyColor", L["Ready flash"],
                L["A short flash when a cooldown of 2 seconds or more ends and the button is ready again."])
            FlashRow("interruptFlash", "interruptColor", L["Interrupted"],
                L["A short flash when the cast is interrupted (flat cast animation)."], flatOn)

            -- one card: pick a text, then its look
            local which = { key = "hotkey" }
            local function T() return G().texts[which.key] end
            local function TB(key)
                return function() return T()[key] end, function(v) T()[key] = v ApplyAllBars() end
            end
            card = page:Add(2, UI.Card(page.content, L["Texts"], L["Choose a text, then its look."]))
            card:Add(UI.Dropdown(card, nil, { { "hotkey", L["Keybind"] }, { "count", L["Count"] }, { "macro", L["Macro name"] }, { "cooldown", L["Cooldown"] } },
                function() return which.key end, function(v) which.key = v UI.RefreshAll() end))
            local shg, shs = TB("show")
            card:Add(UI.Check(card, L["Show"], shg, shs,
                { tip = L["Off: this text is hidden on every bar. Keybind, count and macro name can also be hidden per bar (Bars, Actions tab)."] }))
            local shown = function() return T().show end
            local fg, fs = TB("font")
            card:Add(UI.Dropdown(card, L["Font"], Fonts, fg, fs, { enableIf = shown, sub = true }))
            local zg, zs = TB("size")
            card:Add(UI.Slider(card, L["Size"], 6, 30, 1, zg, zs, { format = UI.px, enableIf = shown, sub = true }))
            local og, os = TB("outline")
            card:Add(UI.Segmented(card, L["Outline"], OUTLINES(), og, os, { enableIf = shown, sub = true }))
            card:Add(UI.Swatch(card, L["Color"], function() return T().color end, ApplyAllBars, { alpha = true, enableIf = shown, sub = true }))
            local pg, ps = TB("point")
            card:Add(UI.Dropdown(card, L["Position"], POINTS, pg, ps, { enableIf = shown, sub = true }))
            local xg, xs = TB("x")
            card:Add(UI.Slider(card, L["X offset"], -20, 20, 1, xg, xs, { format = UI.px, enableIf = shown, sub = true }))
            local yg, ys = TB("y")
            card:Add(UI.Slider(card, L["Y offset"], -20, 20, 1, yg, ys, { format = UI.px, enableIf = shown, sub = true }))

            -- like every reset: red, and a second click to confirm
            card = page:Add(2, UI.Card(page.content, L["Defaults"]))
            local reset = UI.Buttons(card, { { L["Defaults"], function()
                local D = ns.defaults.bars
                for _, key in ipairs({ "buttons", "casting" }) do
                    local t = ns.P.bars[key]
                    wipe(t)
                    for k, v in pairs(ns.Copy(D[key])) do t[k] = v end
                end
                ApplyAllBars()
                UI.RefreshAll()
            end, "danger" } }, { tip = L["Every setting of this page (both tabs) back to its default."] })
            UI.Confirm(reset.buttons[1])
            card:Add(reset)
        end },
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
        { alpha = true, enableIf = on, tip = L["Seen on empty buttons. Lower its opacity to make it lighter or invisible."] }))
    local zg, zs = IB("zoom", true)
    look:Add(UI.Slider(look, L["Zoom"], 0, 0.15, 0.01, zg, zs, { format = UI.pct, enableIf = on,
        tip = L["How much of the icon edge is cut off. Blizzard icons have a bevel around 8%."] }))
    local dg, ds = IB("debuffColor", true)
    look:Add(UI.Check(look, L["Debuff type color"], dg, ds, { enableIf = on,
        tip = L["Debuff border by type (magic, curse, poison...) instead of the chosen color."] }))
    local qg, qs = IB("qualityColor", true)
    look:Add(UI.Check(look, L["Item quality color"], qg, qs, { enableIf = on,
        tip = L["Item border by rarity (green, blue, purple...) instead of the chosen color."] }))

    -- action buttons: hover / pressed / active
    local states = page:Add(2, UI.Card(page.content, L["Button states"],
        L["How action buttons look when hovered, pressed or active (auto attack, current stance)."]))
    local stg, sts = IB("states", true)
    states:Add(UI.Segmented(states, nil, { { "flat", L["Flat"] }, { "blizzard", L["Blizzard"] } },
        stg, sts, { enableIf = on }))
    local flat = function() return on() and O().states ~= "blizzard" end
    for _, def in ipairs({ { "hoverColor", "Hover" }, { "pushColor", "Pressed" }, { "checkColor", "Active" } }) do
        states:Add(UI.Swatch(states, L[def[2]], function() return O()[def[1]] end, ns.ApplyIcons,
            { alpha = true, enableIf = flat, sub = true }))
    end
    -- like every reset: red, and a second click to confirm
    local reset = UI.Buttons(look, { { L["Defaults"], function()
        local keep = {}
        for _, k in ipairs(WHERE) do keep[k] = ns.P.icons[k] end
        ns.ResetModule("icons")
        for k, v in pairs(keep) do ns.P.icons[k] = v end
        ns.ApplyIcons()
        UI.RefreshAll()
    end, "danger" } }, { tip = L["Look and button states back to their defaults (the places stay)."] })
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
    end, { tip = L["Type a name and press Enter: a new profile with the default settings."] }))

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
