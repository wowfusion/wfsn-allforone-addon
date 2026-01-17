----------------------------------------------------------------------
--  All for One - Security Check Module
--  Detects if addon was disabled and shows permanent warning
----------------------------------------------------------------------

local addonName, BR = ...

local SecurityCheck = {
    timeRequested = false,
    startServerTime = nil,
    warningFrame = nil,
}

function SecurityCheck:OnInitialize()
    BR:Debug("SecurityCheck module initialized")
    self:SetupEvents()
end

function SecurityCheck:OnEnable()
    BR:Debug("SecurityCheck enabled")
end

function SecurityCheck:OnDisable()
    BR:Debug("SecurityCheck disabled")
end

function SecurityCheck:Refresh()
    -- Nothing to refresh
end

function SecurityCheck:SetupEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:RegisterEvent("TIME_PLAYED_MSG")
    
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Request played time on login
            SecurityCheck.startServerTime = time()
            RequestTimePlayed()
            SecurityCheck.timeRequested = true
        elseif event == "PLAYER_LEAVING_WORLD" then
            -- Save current session time before logout
            SecurityCheck:SaveSessionTime()
        elseif event == "TIME_PLAYED_MSG" then
            if SecurityCheck.timeRequested then
                local totalTimePlayed = ...
                SecurityCheck:CheckSessionStatus(totalTimePlayed)
                SecurityCheck.timeRequested = false
            end
        end
    end)
    
    self.eventFrame = frame
    
    -- Set up periodic time saving (every 30 seconds)
    C_Timer.NewTicker(30, function()
        SecurityCheck:UpdateSessionTime()
    end)
end

function SecurityCheck:GetCharKey()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    return playerName .. "-" .. realmName
end

function SecurityCheck:GetCharData()
    local charKey = self:GetCharKey()
    
    -- Ensure AllforOneCharDB exists
    if not AllforOneCharDB then
        AllforOneCharDB = {}
    end
    
    -- Initialize security data if needed
    if not AllforOneCharDB.SecurityData then
        AllforOneCharDB.SecurityData = {
            totalTimePlayed = 0,
            sessionActive = false,
            wasDisabled = false,
            lastUpdate = 0,
        }
    end
    
    return AllforOneCharDB.SecurityData
end

function SecurityCheck:CheckSessionStatus(totalTimePlayed)
    local charData = self:GetCharData()
    local charKey = self:GetCharKey()
    
    BR:Debug("SecurityCheck: Checking session for " .. charKey)
    BR:Debug("SecurityCheck: Current played time: " .. totalTimePlayed)
    BR:Debug("SecurityCheck: Saved played time: " .. (charData.totalTimePlayed or 0))
    
    -- First time initialization
    if charData.totalTimePlayed == 0 then
        charData.totalTimePlayed = totalTimePlayed
        charData.sessionActive = true
        charData.lastUpdate = time()
        BR:Debug("SecurityCheck: First time initialization")
        return
    end
    
    -- Calculate time difference
    local timeDiff = totalTimePlayed - charData.totalTimePlayed
    BR:Debug("SecurityCheck: Time difference: " .. timeDiff .. " seconds")
    
    -- If time difference is more than 120 seconds, addon was likely disabled
    -- (allowing some tolerance for loading time, etc.)
    if timeDiff > 15 then
        charData.wasDisabled = true
        BR:Debug("SecurityCheck: ADDON WAS DISABLED! Difference: " .. timeDiff)
        BR:Print("WARNUNG: Addon war deaktiviert! Zeitdifferenz: " .. timeDiff .. " Sekunden", "error")
    end
    
    -- Update stored time
    charData.totalTimePlayed = totalTimePlayed
    charData.sessionActive = true
    charData.lastUpdate = time()
    self.startServerTime = time()
    
    -- Check if warning should be shown
    if charData.wasDisabled then
        self:ShowWarningWindow()
    end
end

function SecurityCheck:SaveSessionTime()
    local charData = self:GetCharData()
    
    if self.startServerTime then
        local sessionDuration = time() - self.startServerTime
        charData.totalTimePlayed = charData.totalTimePlayed + sessionDuration
        charData.lastUpdate = time()
        charData.sessionActive = true
        BR:Debug("SecurityCheck: Saved session time. Total: " .. charData.totalTimePlayed)
    end
end

function SecurityCheck:UpdateSessionTime()
    local charData = self:GetCharData()
    
    if self.startServerTime then
        local sessionDuration = time() - self.startServerTime
        charData.totalTimePlayed = charData.totalTimePlayed + sessionDuration
        charData.lastUpdate = time()
        self.startServerTime = time()
    end
end

function SecurityCheck:ShowWarningWindow()
    if self.warningFrame and self.warningFrame:IsShown() then
        return -- Already showing
    end
    
    local isOfficer = BR:IsGuildOfficer()
    local frameHeight = 140
    
    -- Create warning frame (not movable)
    local frame = CreateFrame("Frame", "AllforOneSecurityWarning", UIParent, "BackdropTemplate")
    frame:SetSize(420, frameHeight)
    frame:SetPoint("TOP", 0, -100)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    
    -- Use popup-style backdrop with red border
    frame:SetBackdrop(BR.Backdrops.Popup)
    frame:SetBackdropColor(0.1, 0.02, 0.02, 0.98)
    frame:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)
    
    -- NOT movable
    frame:EnableMouse(true)
    
    -- Warning icon left
    local iconLeft = frame:CreateTexture(nil, "ARTWORK")
    iconLeft:SetSize(40, 40)
    iconLeft:SetPoint("TOPLEFT", 20, -20)
    iconLeft:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    
    -- Warning icon right
    local iconRight = frame:CreateTexture(nil, "ARTWORK")
    iconRight:SetSize(40, 40)
    iconRight:SetPoint("TOPRIGHT", -20, -20)
    iconRight:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("|cFFFF4444ADDON WAR DEAKTIVIERT|r")
    
    -- Warning text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", title, "BOTTOM", 0, -15)
    text:SetWidth(380)
    text:SetJustifyH("CENTER")
    
    local warningText = "|cFFFFFFFFDas AllforOne Addon war während\neiner Spielsitzung deaktiviert!"
    if not isOfficer then
        warningText = warningText .. "\n\n|cFF888888Diese Warnung kann nur von einem\nGildenoffizier zurückgesetzt werden.|r"
    end
    text:SetText(warningText)
    
    -- Player info at bottom
    local playerInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    playerInfo:SetPoint("BOTTOM", 0, 15)
    playerInfo:SetText("|cFF666666" .. self:GetCharKey() .. "|r")
    
    frame:Show()
    self.warningFrame = frame
    
    -- No close button - warning can only be reset via AdminPanel overview
    
    -- Play warning sound
    PlaySound(SOUNDKIT.RAID_WARNING)
    
    BR:Print("WARNUNG: Das Addon war deaktiviert!", "error")
end

function SecurityCheck:HideWarningWindow()
    if self.warningFrame then
        self.warningFrame:Hide()
        self.warningFrame = nil
    end
    if self.resetButton then
        self.resetButton:Hide()
        self.resetButton = nil
    end
end

function SecurityCheck:ResetWarning(resetterName)
    local charData = self:GetCharData()
    charData.wasDisabled = false
    
    self:HideWarningWindow()
    
    BR:Print("Warnung wurde von " .. resetterName .. " zurückgesetzt.", "info")
    BR:Debug("SecurityCheck: Warning reset by " .. resetterName)
end

-- Check if player can reset warnings (officer or guild master)
function SecurityCheck:CanResetWarnings()
    return BR:IsGuildOfficer()
end

BR:RegisterModule("SecurityCheck", SecurityCheck)
