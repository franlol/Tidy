-------------------------------------------------------------------------------
-- Tidy - Minimap button (LibDBIcon): click opens the options, right click
-- locks / unlocks the bars, drag moves it around the minimap (saved for the
-- whole account). Also the addon compartment entry, named in the TOC.
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

local DBI = LibStub("LibDBIcon-1.0")

-- LibDBIcon's settings (minimapPos, hide, lock). Older versions saved the
-- position as "angle": same degrees, so it carries over as it is.
local function Settings()
    local m = ns.db.minimap
    if m.angle then
        m.minimapPos = m.angle
        m.angle = nil
    end
    return m
end

local function OnClick(button)
    if button == "RightButton" and ns.SetBarsLocked and ns.barsActive then
        ns.SetBarsLocked(not ns.P.bars.locked)
    else
        ns.ToggleOptions()
    end
end

-- compartment = shown for the addon compartment (no drag there)
local function FillTooltip(tt, compartment)
    tt:AddDoubleLine("Tidy", "v" .. ns.version, 0.44, 0.76, 1, 0.5, 0.5, 0.5)
    tt:AddDoubleLine(L["Profile"], ns.profileName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
    tt:AddLine(" ")
    tt:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    tt:AddDoubleLine(L["Right click"], L["Lock / unlock bars"], 1, 0.82, 0, 1, 1, 1)
    if not compartment and not Settings().lock then
        tt:AddDoubleLine(L["Drag"], L["Move this button"], 1, 0.82, 0, 1, 1, 1)
    end
end

local broker = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON, {
    type = "launcher",
    icon = "Interface\\AddOns\\Tidy\\Media\\IconRound",
    OnClick = function(_, button) OnClick(button) end,
    OnTooltipShow = function(tt) FillTooltip(tt) end,
})

-- Show or hide it as the options say
function ns.UpdateMinimapButton()
    DBI:Refresh(ADDON, Settings())
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if broker and not DBI:IsRegistered(ADDON) then
        DBI:Register(ADDON, broker, Settings())
    end
end)

-- Named in the TOC (AddonCompartmentFunc...)
function Tidy_OnCompartmentClick(_, button) OnClick(button) end
function Tidy_OnCompartmentEnter(_, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    FillTooltip(GameTooltip, true)
    GameTooltip:Show()
end
function Tidy_OnCompartmentLeave() GameTooltip:Hide() end
