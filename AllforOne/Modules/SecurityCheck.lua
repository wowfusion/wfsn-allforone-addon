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
    
    -- Key mapping for deobfuscation (alle Versionen)
    -- Keys werden durch Hash berechnet, daher alle bekannten Varianten
    local keyMap = {
        -- Version 6 (manuelle Keys)
        _s1tp = "totalTimePlayed",
        _s2lu = "lastUpdate",
        _s3rt = "lastRealTime",
        _s4sa = "sessionActive",
        _s5wd = "wasDisabled",
        -- Version 7 (z_ prefix)
        zsbf2 = "totalTimePlayed",
        zsc30 = "lastUpdate",
        zsb22 = "lastRealTime",
        zs2c6 = "sessionActive",
        zsbe5 = "wasDisabled",
        -- Berechnete Keys (_s prefix, andere Hash-Varianten)
        _sbf2 = "totalTimePlayed",
        _sc30 = "lastUpdate",
        _sb22 = "lastRealTime",
        _s2c6 = "sessionActive",
        _sbe5 = "wasDisabled",
    }
    
    -- Check for obfuscated security data (zsd oder _sd) and convert to SecurityData
    local sdTable = AllforOneCharDB.zsd or AllforOneCharDB._sd
    if sdTable then
        local secData = {}
        for obfKey, value in pairs(sdTable) do
            local realKey = keyMap[obfKey] or obfKey
            secData[realKey] = value
        end
        AllforOneCharDB.SecurityData = secData
        AllforOneCharDB.zsd = nil
        AllforOneCharDB._sd = nil
    end
    
    -- Check if SecurityData exists but has obfuscated keys (migration)
    if AllforOneCharDB.SecurityData then
        -- Prüfe ob irgendein verschlüsselter Key vorhanden ist
        local needsMigration = false
        for key, _ in pairs(AllforOneCharDB.SecurityData) do
            if keyMap[key] then
                needsMigration = true
                break
            end
        end
        if needsMigration then
            local secData = {}
            for obfKey, value in pairs(AllforOneCharDB.SecurityData) do
                local realKey = keyMap[obfKey] or obfKey
                secData[realKey] = value
            end
            AllforOneCharDB.SecurityData = secData
        end
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

-- Threshold for detecting addon was disabled (in seconds)
-- Higher value to account for long loading screens and multi-PC scenarios
local INACTIVITY_THRESHOLD = 120

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
        charData.lastRealTime = time()
        BR:Debug("SecurityCheck: First time initialization")
        return
    end
    
    -- Calculate time difference
    local timeDiff = totalTimePlayed - charData.totalTimePlayed
    BR:Debug("SecurityCheck: Time difference: " .. timeDiff .. " seconds")
    
    -- Multi-PC detection: Check if real-world time passed is reasonable
    -- If someone plays on PC2, the /played on PC1 won't increase but real time will
    local realTimePassed = 0
    if charData.lastRealTime then
        realTimePassed = time() - charData.lastRealTime
    end
    BR:Debug("SecurityCheck: Real time since last update: " .. realTimePassed .. " seconds")
    
    -- Only trigger warning if:
    -- 1. Time difference exceeds threshold AND
    -- 2. Real-world time passed is less than 24 hours (to handle multi-PC scenarios)
    --    If real time > 24h, player likely just hasn't played this char in a while
    local isMultiPCScenario = realTimePassed > 86400 -- 24 hours
    
    if timeDiff > INACTIVITY_THRESHOLD and not isMultiPCScenario then
        -- Additional check: if timeDiff is very large (> 1 hour), it's likely a multi-PC scenario
        -- where the player was playing on another PC
        if timeDiff > 3600 then
            BR:Debug("SecurityCheck: Large time difference detected, likely multi-PC scenario")
            BR:Print("Hinweis: Große Zeitdifferenz erkannt (" .. math.floor(timeDiff/60) .. " Min). Möglicherweise Multi-PC Nutzung.", "info")
        else
            charData.wasDisabled = true
            BR:Debug("SecurityCheck: ADDON WAS DISABLED! Difference: " .. timeDiff)
            BR:Print("WARNUNG: Addon war deaktiviert! Zeitdifferenz: " .. timeDiff .. " Sekunden", "error")
        end
    end
    
    -- Update stored time
    charData.totalTimePlayed = totalTimePlayed
    charData.sessionActive = true
    charData.lastUpdate = time()
    charData.lastRealTime = time()
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
