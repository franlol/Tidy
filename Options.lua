-------------------------------------------------------------------------------
-- Tidy - Options window (LibFlatyUI-1.0)
--
--   General  : bars on/off, lock, snap, keybinding mode, presets, minimap
--   Bars     : one bar at a time (dropdown, or click it on screen):
--              layout · visibility · paging and buttons
--   Buttons  : look of every action button and casting helpers
--   Icons    : square icons
--   Profiles : profiles, export / import
-- Every change is applied at once. Controls that do not apply are greyed
-- out, never hidden (no layout jumps). The only reload left: switching from
-- Bartender4 (the game cannot turn an addon off without one).
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

local function UpdateStatus()
    if not win then return end
    win:SetStatus(ns.barsConflict and L["Bartender4 is loaded: disable it and reload to use Tidy's bars."] or "")
end

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
-- General
-------------------------------------------------------------------------------
local function BuildGeneral(container)
    local page = UI.Page(container, 2)

    local gen = page:Add(1, UI.Card(page.content, L["Action bars"],
        L["Your spells and keybinds, on bars you place. Replaces Blizzard's action bars."]))
    gen:Add(UI.Switch(gen, L["Enabled"], function() return ns.P.bars.enabled end, function(v)
        ns.P.bars.enabled = v
        -- Bartender's settings are only readable while it is loaded
        if v and not ns.P.bars.imported and Bartender4DB then ns.ImportBartender() end
        ns.SetBarsActive(v)
    end))
    gen:Add(UI.Note(gen, L["Coming from Bartender4: turn it off in the addon list and reload, only once."]))
    gen:Add(UI.Buttons(gen, { { L["Reload interface"], ReloadUI, "accent" } },
        { enableIf = function() return ns.barsConflict and true or false end }))
    gen:Add(UI.Buttons(gen, {
        { L["Copy Bartender4 layout"], function()
            if ns.ImportBartender() then
                ns.Print(L["Bartender4 layout copied."])
                ApplyAllBars()
            end
            UI.RefreshAll()
        end },
    }, { enableIf = function() return Bartender4DB ~= nil end,
        tip = L["Positions, rows, padding, scale and alpha. Only while Bartender4 is loaded."] }))

    local edit = page:Add(1, UI.Card(page.content, L["Editing"]))
    edit:Add(UI.Buttons(edit, {
        { L["Lock / unlock bars"], function() ns.SetBarsLocked(not ns.P.bars.locked) UI.RefreshAll() end },
        { L["Keybinding mode"], function() ns.SetBindMode(not ns.bindMode) UI.RefreshAll() end },
    }, { enableIf = active }))
    edit:Add(UI.Check(edit, L["Snap while moving"], function() return ns.P.bars.snap end,
        function(v) ns.P.bars.snap = v end, { enableIf = active,
            tip = L["A bar you drag sticks to the edges and centers of other bars, the screen center lines and the screen borders."] }))
    edit:Add(UI.Note(edit, L["Unlocked: drag a bar to move it, click it to edit it. Keybinding mode: hover a button and press a key."]))

    local look = page:Add(2, UI.Card(page.content, L["Layout"]))
    local preset = {}
    look:Add(UI.Dropdown(look, L["Preset"], {
        { "blizzard", L["Blizzard-like"] }, { "compact", L["Compact"] }, { "split", L["Split"] },
    }, function() return preset.name end, function(v) preset.name = v end, { enableIf = active }))
    local apply = UI.Buttons(look, { { L["Apply preset"], function()
        if preset.name then ns.ApplyPreset(preset.name) UI.RefreshAll() end
    end, "accent" } }, { enableIf = function() return active() and preset.name ~= nil end,
        tip = L["Moves the action bars 1 and 3-6 to a ready layout. The other settings stay."] })
    UI.Confirm(apply.buttons[1])
    look:Add(apply)
    look:Add(UI.Check(look, L["Gryphons on bar 1"], function() return ns.P.bars.gryphons end,
        function(v) ns.P.bars.gryphons = v if ns.UpdateGryphons then ns.UpdateGryphons() end end,
        { enableIf = active }))

    local misc = page:Add(2, UI.Card(page.content, L["Minimap"]))
    misc:Add(UI.Check(misc, L["Minimap button"], function() return not ns.db.minimap.hide end,
        function(v) ns.db.minimap.hide = not v ns.UpdateMinimapButton() end))
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
    for p = 1, 10 do list[#list + 1] = { p, (L["Page %d"]):format(p) } end
    return list
end

local function BuildBars(container)
    local page = UI.Page(container, 2)

    -- Layout
    local card = page:Add(1, UI.Card(page.content, L["Bar"]))
    card:Add(UI.Dropdown(card, nil, BarOptions(), function() return selected end, Select))
    local eg, es = BB("enabled")
    card:Add(UI.Check(card, L["Show this bar"], eg, es, { enableIf = active }))
    local function S(c, label, key, minV, maxV, step, fmt, applies)
        local g, s = BB(key)
        c:Add(UI.Slider(c, label, minV, maxV, step, g, s, { format = fmt, enableIf = When(applies) }))
    end
    S(card, L["Buttons"], "buttons", 1, 12, 1, nil, IsAction)
    S(card, L["Rows"], "rows", 1, 12, 1, nil, HasRows)
    S(card, L["Padding"], "padding", -5, 10, 0.1, function(v) return ("%.1f px"):format(v) end, HasRows)
    S(card, L["Scale"], "scale", 0.5, 2, 0.05, UI.pct)
    S(card, L["Opacity"], "alpha", 0, 1, 0.05, UI.pct)
    S(card, L["Width"], "width", 200, 1500, 1, UI.px, function() return selected == "status" end)
    local hg, hs = BB("growH")
    card:Add(UI.Segmented(card, L["Fill"], { { "RIGHT", L["To the right"] }, { "LEFT", L["To the left"] } },
        hg, hs, { enableIf = When(HasRows) }))
    local vg, vs = BB("growV")
    card:Add(UI.Segmented(card, nil, { { "DOWN", L["Downwards"] }, { "UP", L["Upwards"] } },
        vg, vs, { enableIf = When(HasRows) }))
    local cg, cs = BB("clickThrough")
    card:Add(UI.Check(card, L["Click-through"], cg, cs, { enableIf = When(HasRows),
        tip = L["The mouse goes through the buttons (keybinds still work)."] }))
    card:Add(UI.Input(card, L["X position"], function() return tostring((ns.BarXY(selected))) end,
        function(v) local n = tonumber(v) if n then ns.SetBarXY(selected, n, nil) end end, { enableIf = When() }))
    card:Add(UI.Input(card, L["Y position"], function() return tostring(select(2, ns.BarXY(selected))) end,
        function(v) local n = tonumber(v) if n then ns.SetBarXY(selected, nil, n) end end,
        { enableIf = When(), tip = L["From the bottom left corner of the screen to the top left corner of the bar."] }))

    -- Visibility
    card = page:Add(2, UI.Card(page.content, L["Visibility"]))
    local fg, fs = BB("fade")
    card:Add(UI.Check(card, L["Fade out when the mouse is not over it"], fg, fs, { enableIf = When() }))
    local fadeOn = function() return ns.BarConfig(selected).fade end
    S(card, L["Faded opacity"], "fadeAlpha", 0, 1, 0.05, UI.pct, fadeOn)
    S(card, L["Delay"], "fadeDelay", 0, 3, 0.1, function(v) return ("%.1f s"):format(v) end, fadeOn)
    local noCustom = function() return strtrim(ns.BarConfig(selected).custom or "") == "" end
    for _, def in ipairs({
        { "hideCombat", "Hide in combat" }, { "hideNoCombat", "Hide out of combat" },
        { "hidePet", "Hide with a pet" }, { "hideNoPet", "Hide without a pet" },
        { "hideVehicle", "Hide in vehicles" },
    }) do
        local g, s = BB(def[1])
        card:Add(UI.Check(card, L[def[2]], g, s, { enableIf = When(noCustom) }))
    end
    local xg, xs = BB("custom")
    card:Add(UI.Input(card, L["Custom conditions"], xg, xs, { enableIf = When(),
        tip = L["Macro conditions, e.g. [combat] show; hide. When set, they replace the options above."] }))

    -- Paging and buttons (action bars)
    card = page:Add(2, UI.Card(page.content, L["Paging and buttons"]))
    local pg, ps = BB("page")
    card:Add(UI.Dropdown(card, L["Page"], PAGE_OPTIONS(false), pg, ps, { enableIf = When(IsAction) }))
    local sg, ss = BB("stancePaging")
    card:Add(UI.Check(card, L["Change page with stance / form"], sg, ss, { enableIf = When(IsAction),
        tip = L["Warrior stances, druid forms, rogue stealth, priest shadowform: pages 7 to 10."] }))
    for _, mod in ipairs({ { "ctrlPage", "Page with Ctrl" }, { "altPage", "Page with Alt" }, { "shiftPage", "Page with Shift" } }) do
        local g, s = BB(mod[1])
        card:Add(UI.Dropdown(card, L[mod[2]], PAGE_OPTIONS(true), g, s, { enableIf = When(IsAction) }))
    end
    local gg, gs = BB("showGrid")
    card:Add(UI.Check(card, L["Show empty buttons"], gg, gs, { enableIf = When(IsAction) }))
    for _, def in ipairs({ { "hideMacro", "Hide macro names" }, { "hideHotkey", "Hide keybinds" },
        { "hideEquipped", "Hide equipped border" } }) do
        local g, s = BB(def[1])
        card:Add(UI.Check(card, L[def[2]], g, s, { enableIf = When(IsAction) }))
    end
    local og, os = BB("flyout")
    card:Add(UI.Dropdown(card, L["Flyout direction"], {
        { "UP", L["Up"] }, { "DOWN", L["Down"] }, { "LEFT", L["Left"] }, { "RIGHT", L["Right"] },
    }, og, os, { enableIf = When(IsAction) }))
end

-------------------------------------------------------------------------------
-- Buttons: every action button
-------------------------------------------------------------------------------
local function BuildButtons(container)
    local page = UI.Page(container, 2)
    local function G() return ns.P.bars.buttons end
    local function GB(key)
        return function() return G()[key] end, function(v) G()[key] = v ApplyAllBars() end
    end

    local card = page:Add(1, UI.Card(page.content, L["Behaviour"]))
    local tg, ts = GB("tooltip")
    card:Add(UI.Dropdown(card, L["Tooltips"], {
        { "enabled", L["Always"] }, { "nocombat", L["Out of combat"] }, { "disabled", L["Never"] },
    }, tg, ts))
    local rg, rs = GB("range")
    card:Add(UI.Dropdown(card, L["Out of range"], {
        { "button", L["Color the button"] }, { "hotkey", L["Color the keybind"] }, { "none", L["Nothing"] },
    }, rg, rs))
    card:Add(UI.Swatch(card, L["Out of range color"], function() return G().rangeColor end, ApplyAllBars))
    card:Add(UI.Swatch(card, L["Out of mana color"], function() return G().manaColor end, ApplyAllBars))
    local lg, ls = GB("lock")
    card:Add(UI.Check(card, L["Lock buttons"], lg, ls, { tip = L["Spells cannot be dragged off the bars (Shift + drag still can)."] }))
    local vg, vs = GB("castVFX")
    card:Add(UI.Check(card, L["Cast animation"], vg, vs))
    card:Add(UI.Check(card, L["Cast on key down"], function() return GetCVarBool("ActionButtonUseKeyDown") end,
        function(v) SetCVar("ActionButtonUseKeyDown", v and "1" or "0") end, { tip = L["A game setting: for every bar."] }))

    -- Casting helpers
    card = page:Add(1, UI.Card(page.content, L["Casting"]))
    local K = function() return ns.P.bars.casting end
    local function KB(key, also)
        return function() return K()[key] end, function(v) K()[key] = v if also then also(v) end ApplyAllBars() end
    end
    local MODS = { { "ALT", "Alt" }, { "CTRL", "Ctrl" }, { "SHIFT", "Shift" }, { "NONE", L["None"] } }
    local function ModDropdown(label, click, enable)
        card:Add(UI.Dropdown(card, label, MODS, function() return GetModifiedClick(click) end, function(v)
            SetModifiedClick(click, v)
            SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
        end, { enableIf = enable }))
    end
    local g, s = KB("selfCast")
    card:Add(UI.Check(card, L["Self-cast with a key"], g, s))
    ModDropdown(L["Self-cast key"], "SELFCAST", function() return K().selfCast end)
    g, s = KB("focusCast")
    card:Add(UI.Check(card, L["Focus-cast with a key"], g, s))
    ModDropdown(L["Focus-cast key"], "FOCUSCAST", function() return K().focusCast end)
    g, s = KB("mouseover", function(v) SetCVar("enableMouseoverCast", v and "1" or "0") end)
    card:Add(UI.Check(card, L["Mouse-over casting"], g, s, { tip = L["Spells go to the unit under the mouse."] }))
    ModDropdown(L["Mouse-over key"], "MOUSEOVERCAST", function() return K().mouseover end)
    g, s = KB("rightClickSelf")
    card:Add(UI.Check(card, L["Right click casts on yourself"], g, s))

    -- Texts on the buttons
    card = page:Add(2, UI.Card(page.content, L["Texts"]))
    local which = { key = "hotkey" }
    card:Add(UI.Segmented(card, nil, { { "hotkey", L["Keybind"] }, { "count", L["Count"] }, { "macro", L["Macro name"] } },
        function() return which.key end, function(v) which.key = v UI.RefreshAll() end))
    local function T() return G().texts[which.key] end
    local function TB(key)
        return function() return T()[key] end, function(v) T()[key] = v ApplyAllBars() end
    end
    local fg, fs = TB("font")
    card:Add(UI.Dropdown(card, L["Font"], Fonts, fg, fs))
    local zg, zs = TB("size")
    card:Add(UI.Slider(card, L["Size"], 6, 30, 1, zg, zs))
    local og, os = TB("outline")
    card:Add(UI.Dropdown(card, L["Outline"], OUTLINES, og, os))
    card:Add(UI.Swatch(card, L["Color"], function() return T().color end, ApplyAllBars))
    local pg, ps = TB("point")
    card:Add(UI.Dropdown(card, L["Position"], POINTS, pg, ps))
    local xg, xs = TB("x")
    card:Add(UI.Slider(card, L["X offset"], -20, 20, 1, xg, xs))
    local yg, ys = TB("y")
    card:Add(UI.Slider(card, L["Y offset"], -20, 20, 1, yg, ys))
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
        { "actionbars", "Action bars", "Tidy, Blizzard and Bartender4 bars, pet and stance bars." },
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
    look:Add(UI.Buttons(look, { { L["Defaults"], function()
        local keep = {}
        for _, k in ipairs(WHERE) do keep[k] = ns.P.icons[k] end
        ns.ResetModule("icons")
        for k, v in pairs(keep) do ns.P.icons[k] = v end
        ns.ApplyIcons()
        UI.RefreshAll()
    end } }))
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
        width = 680, height = 520, navWidth = 110 })
    win:AddNav("general", L["General"], BuildGeneral, active)
    win:AddNav("bars", L["Bars"], BuildBars)
    win:AddNav("buttons", L["Buttons"], BuildButtons)
    win:AddNav("icons", L["Icons"], BuildIcons, function() return ns.P.icons.enabled end)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle((L["Profile: %s"]):format(ns.profileName or ""))
        UpdateStatus()
    end
    ns.OnBindMode = function() UI.RefreshAll() end
    win:Select("general")
end

function ns.ToggleOptions()
    if not win then Build() win:Show() return end
    win:Toggle()
end
