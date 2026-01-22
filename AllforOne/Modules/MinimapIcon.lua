----------------------------------------------------------------------
--  All for One - Minimap Icon Module
--  Adds a minimap button to open the addon menu (LibDBIcon-style)
----------------------------------------------------------------------

local addonName, BR = ...

local MinimapIcon = {
    button = nil,
    officerButton = nil,
    isDragging = false,
}

local defaultPosition = 220
local rad, cos, sin, sqrt, max, min = math.rad, math.cos, math.sin, math.sqrt, math.max, math.min
local deg, atan2 = math.deg, math.atan2

-- Minimap shape handling (like LibDBIcon)
local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function updatePosition(button, position)
    local angle = rad(position or 225)
    local x, y, q = cos(angle), sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[minimapShape] or minimapShapes["ROUND"]
    -- Use half minimap width + small offset for proper edge positioning
    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5
    if quadTable[q] then
        x, y = x * w, y * h
    else
        local diagRadiusW = sqrt(2 * (w)^2) - 10
        local diagRadiusH = sqrt(2 * (h)^2) - 10
        x = max(-w, min(x * diagRadiusW, w))
        y = max(-h, min(y * diagRadiusH, h))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapIcon:OnInitialize()
    BR:Debug("MinimapIcon module initialized")
end

function MinimapIcon:OnEnable()
    self:CreateButton()
    -- Create officer button after a delay to ensure guild info is loaded
    C_Timer.After(3, function()
        MinimapIcon:RefreshOfficerButton()
    end)
end

function MinimapIcon:OnDisable()
    if self.button then
        self.button:Hide()
    end
    if self.officerButton then
        self.officerButton:Hide()
    end
end

function MinimapIcon:RefreshOfficerButton()
    if BR:IsGuildOfficer() then
        self:CreateOfficerButton()
        if self.officerButton then
            self.officerButton:Show()
        end
    elseif self.officerButton then
        self.officerButton:Hide()
    end
end

function MinimapIcon:CreateButton()
    if self.button then return end
    
    local button = CreateFrame("Button", "AllforOneMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    
    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
    button.bg = bg
    
    -- Icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\AllforOne\\media\\icon-allforone.png")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon
    
    -- Border overlay
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
    button.border = border
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, self:GetHeight())
        GameTooltip:ClearLines()
        GameTooltip:AddLine(BR.Colors.Guild .. "All for One - Guildfound|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFLinksklick:|r Addon-Menü öffnen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFFFFRechtsklick:|r Einstellungen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        local status = BR:GetSetting("Enabled") and "|cFF00FF00Aktiv|r" or "|cFFFF4444Inaktiv|r"
        GameTooltip:AddLine("Status: " .. status)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnClick", function(self, btn)
        GameTooltip:Hide()
        if btn == "LeftButton" then
            BR:ShowWelcomeScreen()
        elseif btn == "RightButton" then
            BR:OpenConfig()
        end
    end)
    
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        MinimapIcon.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local pos = deg(atan2(py - my, px - mx)) % 360
            AllforOneDB.MinimapIconAngle = pos
            updatePosition(self, pos)
        end)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        MinimapIcon.isDragging = false
    end)
    
    self.button = button
    
    -- Load saved position
    local pos = AllforOneDB.MinimapIconAngle or defaultPosition
    updatePosition(button, pos)
end

----------------------------------------------------------------------
--  Officer Minimap Button (nur für Offiziere sichtbar)
----------------------------------------------------------------------

function MinimapIcon:CreateOfficerButton()
    if self.officerButton then return end
    if not BR:IsGuildOfficer() then return end
    
    local button = CreateFrame("Button", "AllforOneOfficerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture(136477)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    
    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER", 0, 0)
    bg:SetTexture(136467)
    button.bg = bg
    
    -- Icon texture - use addon icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\AllforOne\\media\\icon-allforone")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon
    
    -- Border overlay
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture(136430)
    button.border = border
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT", 0, self:GetHeight())
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cFFFFCC00Offizier-Übersicht|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFFFFFLinksklick:|r Übersicht öffnen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        -- Count addon users who are actually online in guild
        local onlineCount = 0
        local onlineGuildMembers = {}
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local fullName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            if fullName and isOnline then
                local shortName = strsplit("-", fullName)
                onlineGuildMembers[shortName:lower()] = true
            end
        end
        if AllforOneDB.AddonUsers then
            for name, data in pairs(AllforOneDB.AddonUsers) do
                if data and data.status == "ENABLED" and onlineGuildMembers[name:lower()] then
                    onlineCount = onlineCount + 1
                end
            end
        end
        GameTooltip:AddLine("Online mit Addon: |cFF00FF00" .. onlineCount .. "|r")
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    button:SetScript("OnClick", function(self, btn)
        GameTooltip:Hide()
        if btn == "LeftButton" then
            BR:OpenAddonOverview()
        elseif btn == "RightButton" then
            BR:OpenConfig()
        end
    end)
    
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        MinimapIcon.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local pos = deg(atan2(py - my, px - mx)) % 360
            AllforOneDB.OfficerMinimapIconAngle = pos
            updatePosition(self, pos)
        end)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        MinimapIcon.isDragging = false
    end)
    
    self.officerButton = button
    
    -- Load saved position (default offset from main button)
    local pos = AllforOneDB.OfficerMinimapIconAngle or (defaultPosition + 30)
    updatePosition(button, pos)
end

BR:RegisterModule("MinimapIcon", MinimapIcon)
