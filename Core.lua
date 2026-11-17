-------------------------------------------------------------------------------
-- Tidy - Saved settings, profiles, language and slash command
--
-- TidyDB = {
--     language  = "enUS" (default) | "esES",
--     profiles  = { [name] = { icons = {...}, bars = {...} } },
--     profileOf = { [character] = profile name },
-- }
-- One profile holds every setting. ns.P is the one in use; switching
-- profile is applied at once (secure parts after combat).
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

-- From the TOC; "dev" when running from the repository (not packaged)
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or ""
if ns.version:find("^@") then ns.version = "dev" end

ns.defaults = {
    icons = {
        enabled = true,
        -- where
        actionbars = true,
        playerAuras = true,
        unitAuras = true,
        raidAuras = true,
        items = true,
        -- look
        size = 1,                              -- border thickness, px
        color = { r = 0, g = 0, b = 0, a = 1 },
        background = { r = 0, g = 0, b = 0, a = 0.4 }, -- behind the icon (empty buttons)
        zoom = 0.08,                           -- how much of the icon edge is cut
        debuffColor = false,                   -- border colored by debuff type
        qualityColor = true,                   -- border colored by item quality
        -- action buttons with the square look: hover / pressed / active
        -- (set in Buttons > States; kept here, they cover every action bar)
        hoverShow = true, hoverColor = { r = 1, g = 1, b = 1, a = 0.15 },
        pushShow = true, pushColor = { r = 0, g = 0, b = 0, a = 0.35 },
        checkShow = true, checkColor = { r = 1, g = 0.82, b = 0, a = 0.3 },
    },
    bars = {
        enabled = false,  -- replaces Blizzard's action bars
        locked = true,
        snap = true,      -- moving a bar sticks it to other bars and screen lines
        gryphons = false, -- Blizzard's gryphons / wyverns at the sides of bar 1
        list = {},        -- [bar id] = settings; missing keys come from ns.BarDefaults
        -- every action button
        buttons = {
            tooltip = "enabled",  -- enabled / nocombat / disabled
            -- states: shown or not, and their color
            rangeShow = true,
            range = "button",     -- out of range tints: button / hotkey
            rangeColor = { r = 0.8, g = 0.1, b = 0.1, a = 1 },
            manaShow = true,
            manaColor = { r = 0.5, g = 0.5, b = 1, a = 1 },
            unusableShow = true,
            attackShow = true,    -- Auto Attack while attacking (the button flashes)
            attackColor = { r = 1, g = 0.2, b = 0.2, a = 1 },
            autoRepeatShow = true, -- Auto Shot, Shoot... while repeating
            autoRepeatColor = { r = 1, g = 0.2, b = 0.2, a = 1 },
            equipShow = true,     -- border of an equipped item
            equipColor = { r = 0, g = 1, b = 0, a = 0.35 },
            castVFX = true,       -- cast animation on the button
            castStyle = "flat",   -- flat: Tidy's border and flash / blizzard: the game's animation
            castFillColor = { r = 1, g = 0.82, b = 0.2, a = 0.35 },   -- fill while casting (flat; its edge is opaque)
            interruptFlash = true, -- flash when the cast is interrupted (flat)
            interruptColor = { r = 1, g = 0.15, b = 0.15, a = 0.6 },
            cooldownAlpha = 0.8,  -- darkness of the cooldown swipe over the icon
            gcdAlpha = 0.5,       -- darkness of the swipe on the global cooldown only
            gcdSpark = false,     -- a bright line following the global cooldown swipe
            gcdSparkColor = { r = 1, g = 1, b = 1, a = 1 },
            readyFlash = true,    -- flash when a cooldown ends
            readyColor = { r = 0.3, g = 1, b = 0.4, a = 0.6 },
            unusableColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }, -- icon when it cannot be used now
            -- flashes when a button is pressed: on cooldown / on the global
            -- cooldown / not usable / on an empty slot
            cdPress = true, cdPressColor = { r = 1, g = 0.15, b = 0.15, a = 0.55 },
            gcdPress = true, gcdPressColor = { r = 1, g = 0.85, b = 0.1, a = 0.55 },
            failPress = true, failPressColor = { r = 1, g = 0.55, b = 0, a = 0.5 },
            emptyPress = true, emptyPressColor = { r = 1, g = 1, b = 1, a = 0.3 },
            lock = false,         -- no dragging spells off (Shift drags)
            texts = {
                hotkey = { show = true, font = "Fonts\\ARIALN.TTF", size = 14, outline = "OUTLINE", point = "TOPRIGHT", x = -2, y = -4,
                    color = { r = 0.75, g = 0.75, b = 0.75, a = 1 } },
                count = { show = true, font = "Fonts\\ARIALN.TTF", size = 16, outline = "OUTLINE", point = "BOTTOMRIGHT", x = -2, y = 4,
                    color = { r = 1, g = 1, b = 1, a = 1 } },
                macro = { show = true, font = "Fonts\\FRIZQT__.TTF", size = 10, outline = "OUTLINE", point = "BOTTOM", x = 0, y = 2,
                    color = { r = 1, g = 1, b = 1, a = 1 } },
                -- the game's cooldown countdown (Tidy only styles it: its times are secret)
                cooldown = { show = true, font = "Fonts\\ARIALN.TTF", size = 16, outline = "OUTLINE", point = "CENTER", x = 0, y = 0,
                    color = { r = 1, g = 1, b = 1, a = 1 } },
            },
        },
        casting = {
            selfCast = true,       -- self-cast key (the game's SELFCAST modifier)
            focusCast = true,      -- focus-cast key (FOCUSCAST)
            mouseover = false,     -- cast on the unit under the mouse
            rightClickSelf = false, -- right click casts on yourself
        },
    },
}

-- Account-wide (not in profiles)
local ACCOUNT = {
    minimap = { hide = false, angle = 200 },
}

-- Fills the missing keys of t with the defaults (without touching the rest)
local function Fill(t, def)
    for k, v in pairs(def) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            Fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
end

-- Older settings in the current form (before the defaults fill the rest)
local function Migrate(p)
    local b = type(p.bars) == "table" and p.bars.buttons
    -- out of range "none" became its own on/off
    if type(b) == "table" and b.range == "none" then
        b.range = "button"
        b.rangeShow = false
    end
    -- the flat / Blizzard choice of the button states is gone: each state
    -- has its own on/off now
    if type(p.icons) == "table" then p.icons.states = nil end
end

local function FillProfile(p)
    Migrate(p)
    Fill(p, ns.defaults)
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end
ns.Copy = Copy

-------------------------------------------------------------------------------
-- Modules: start() once at login, apply() when the profile changes
-------------------------------------------------------------------------------
ns.modules = {}
function ns.Module(start, apply)
    table.insert(ns.modules, { start = start, apply = apply })
end

local function ApplyAll()
    for _, m in ipairs(ns.modules) do
        if m.apply then m.apply() end
    end
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
-- Forever: characters have a surname and can share the first name, so it is
-- part of the key
local function CharKey()
    local name, surname = UnitName("player")
    if surname and surname ~= "" then name = name .. " " .. surname end
    return (name or "?") .. " - " .. (GetRealmName() or "?")
end

local DEFAULT = "Default"

local function SetProfile(name)
    local db = ns.db
    if not db.profiles[name] then db.profiles[name] = {} end
    db.profileOf[ns.charKey] = name
    ns.profileName = name
    ns.P = db.profiles[name]
    FillProfile(ns.P)
end

-- Switches this character to another profile (created if it does not exist)
function ns.UseProfile(name)
    SetProfile(name)
    ApplyAll()
end

-- Copies another profile into the one in use
function ns.CopyProfile(from)
    local src = ns.db.profiles[from]
    if not src or from == ns.profileName then return end
    wipe(ns.P)
    for k, v in pairs(Copy(src)) do ns.P[k] = v end
    FillProfile(ns.P)
    ApplyAll()
end

function ns.DeleteProfile(name)
    if name == ns.profileName then return end
    ns.db.profiles[name] = nil
    for char, p in pairs(ns.db.profileOf) do
        if p == name then ns.db.profileOf[char] = nil end
    end
end

function ns.ResetProfile()
    wipe(ns.P)
    FillProfile(ns.P)
    ApplyAll()
end

-- One module of the profile back to its defaults
-- (in place: modules keep a reference to their table)
function ns.ResetModule(key)
    local t = ns.P[key]
    wipe(t)
    for k, v in pairs(Copy(ns.defaults[key])) do t[k] = v end
end

function ns.ProfileNames()
    local list = {}
    for name in pairs(ns.db.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-------------------------------------------------------------------------------
-- Export / import: the profile as Lua text, read back in an empty
-- environment (no access to the game)
-------------------------------------------------------------------------------
local function Serialize(v, out)
    local t = type(v)
    if t == "table" then
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            out[#out + 1] = "["
            Serialize(k, out)
            out[#out + 1] = "]="
            Serialize(v[k], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        out[#out + 1] = ("%q"):format(v):gsub("\n", "n")
    elseif t == "number" or t == "boolean" then
        out[#out + 1] = tostring(v)
    else
        out[#out + 1] = "nil"
    end
    return out
end

function ns.ExportProfile()
    return "TIDY1:" .. table.concat(Serialize(ns.P, {}))
end

-- Returns true, or false and the reason
function ns.ImportProfile(text)
    local body = text and text:match("^%s*TIDY1:(.+)$")
    if not body then return false, L["This is not a Tidy profile."] end
    local chunk = loadstring("return " .. body)
    if not chunk then return false, L["The text is damaged."] end
    setfenv(chunk, {})
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return false, L["The text is damaged."] end
    wipe(ns.P)
    for k, v in pairs(data) do ns.P[k] = v end
    FillProfile(ns.P)
    ApplyAll()
    return true
end

-------------------------------------------------------------------------------
-- Combat: secure changes wait for the end of combat
-------------------------------------------------------------------------------
-- Runs func now, or after combat. Calls with the same key while waiting
-- replace each other.
local pending, order = {}, {}
function ns.RunOOC(key, func)
    if not InCombatLockdown() then return func() end
    if not pending[key] then table.insert(order, key) end
    pending[key] = func
end

-------------------------------------------------------------------------------
-- Loading
-------------------------------------------------------------------------------
-- English unless Spanish was chosen
local function ApplyLanguage()
    ns.SetLanguage(ns.db.language or "enUS")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        TidyDB = TidyDB or {}
        ns.db = TidyDB
        Fill(ns.db, ACCOUNT)
        ApplyLanguage()
    elseif event == "PLAYER_LOGIN" then
        local db = ns.db
        db.profiles = db.profiles or {}
        db.profileOf = db.profileOf or {}
        ns.charKey = CharKey()
        SetProfile(db.profileOf[ns.charKey] or DEFAULT)
        for _, m in ipairs(ns.modules) do m.start() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local list = order
        order = {}
        for _, key in ipairs(list) do
            local f = pending[key]
            pending[key] = nil
            if f then f() end
        end
    end
end)

-- lang: "enUS" or "esES"
function ns.SetLanguagePref(lang)
    ns.db.language = lang
    ApplyLanguage()
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------
SLASH_TIDY1 = "/tidy"
SlashCmdList.TIDY = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local lang = msg:match("^lang%s+(%a+)$")
    if lang == "es" or lang == "en" then
        ns.db.language = lang == "es" and "esES" or "enUS"
        ApplyLanguage()
    else
        ns.ToggleOptions()
    end
end
