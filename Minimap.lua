-------------------------------------------------------------------------------
-- Tidy - Minimap button: click opens the options, drag moves it around the
-- minimap (the angle is saved, for the whole account)
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local btn = CreateFrame("Button", "TidyMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("AnyUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local atan2 = math.atan2 or atan2

local function Place()
    local a = math.rad(ns.db.minimap.angle)
    local r = Minimap:GetWidth() / 2 + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimap.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
    Place()
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
    GameTooltip:Hide()
end)
btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" and ns.SetBarsLocked and ns.barsActive then
        ns.SetBarsLocked(not ns.P.bars.locked)
    else
        ns.ToggleOptions()
    end
end)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("Tidy", "v" .. ns.version, 0.44, 0.76, 1, 0.5, 0.5, 0.5)
    GameTooltip:AddDoubleLine(L["Profile"], ns.profileName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Right click"], L["Lock / unlock bars"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Drag"], L["Move this button"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateMinimapButton()
    btn:SetShown(not ns.db.minimap.hide)
end

btn:RegisterEvent("PLAYER_LOGIN")
btn:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Place()
    ns.UpdateMinimapButton()
end)
