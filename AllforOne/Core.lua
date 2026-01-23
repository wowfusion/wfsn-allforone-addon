----------------------------------------------------------------------
--  All for One 1.0.0 - Guildfound Addon für WoW Retail
--  wowfusion.de
----------------------------------------------------------------------

-- Create global addon namespace
local addonName, BR = ...
_G.AllforOne = BR

-- Initialize databases
_G.AllforOneDB = _G.AllforOneDB or {}
_G.AllforOneCharDB = _G.AllforOneCharDB or {}

-- Local references (Colors, Backdrops, etc. are defined in Constants.lua)
BR.Modules = {}
BR.Events = CreateFrame("Frame")

----------------------------------------------------------------------
--  Utility Functions
----------------------------------------------------------------------

function BR:Print(msg, msgType)
    local color = self.Colors.White
    if msgType == "error" then
        color = self.Colors.Error
    elseif msgType == "warning" then
        color = self.Colors.Warning
    elseif msgType == "info" then
        color = self.Colors.White
    end
    DEFAULT_CHAT_FRAME:AddMessage(self.Colors.Gold .. "[All for One]|r " .. color .. msg .. "|r")
end

function BR:ShowScreenMessage(msg, msgType, duration)
    duration = duration or 3
    
    -- Create screen message frame if it doesn't exist
    if not self.ScreenMessageFrame then
        local frame = CreateFrame("Frame", "AllforOneScreenMessage", UIParent, "BackdropTemplate")
        frame:SetSize(400, 70)
        frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetFrameLevel(500)
        
        -- Simple dark backdrop
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        
        -- Colored accent bar on left
        local accentBar = frame:CreateTexture(nil, "ARTWORK")
        accentBar:SetPoint("TOPLEFT", 6, -6)
        accentBar:SetPoint("BOTTOMLEFT", 6, 6)
        accentBar:SetWidth(4)
        accentBar:SetColorTexture(1, 0.2, 0.2, 1)
        frame.accentBar = accentBar
        
        -- Icon with simple mask
        local iconBg = frame:CreateTexture(nil, "ARTWORK")
        iconBg:SetSize(38, 38)
        iconBg:SetPoint("LEFT", 18, 0)
        iconBg:SetColorTexture(0, 0, 0, 0.5)
        
        local icon = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        icon:SetSize(32, 32)
        icon:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.icon = icon
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 12, -2)
        frame.title = title
        
        -- Message text
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        text:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        frame.text = text
        
        -- Addon name at bottom right
        local addonName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addonName:SetPoint("BOTTOMRIGHT", -12, 8)
        addonName:SetText("|cFF666666All for One|r")
        frame.addonName = addonName
        
        frame:Hide()
        self.ScreenMessageFrame = frame
    end
    
    local frame = self.ScreenMessageFrame
    
    -- Set colors and icon based on message type
    if msgType == "error" or msgType == "warning" then
        frame:SetBackdropBorderColor(0.6, 0.1, 0.1, 1)
        frame.accentBar:SetColorTexture(1, 0.2, 0.2, 1)
        frame.title:SetText("|cFFFF4444BLOCKIERT|r")
        frame.icon:SetTexture("Interface\\AddOns\\AllforOne\\media\\icon-allforone.png")
        frame.text:SetTextColor(1, 0.85, 0.75)
    elseif msgType == "info" then
        frame:SetBackdropBorderColor(0.1, 0.3, 0.6, 1)
        frame.accentBar:SetColorTexture(0.3, 0.6, 1, 1)
        frame.title:SetText("|cFF66AAFFInformation|r")
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_06")
        frame.text:SetTextColor(0.85, 0.9, 1)
    else
        frame:SetBackdropBorderColor(0.1, 0.5, 0.1, 1)
        frame.accentBar:SetColorTexture(0.2, 0.8, 0.2, 1)
        frame.title:SetText("|cFF44FF44Erfolgreich|r")
        frame.icon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
        frame.text:SetTextColor(0.85, 1, 0.85)
    end
    
    frame.text:SetText(msg)
    frame:Show()
    
    -- Animate fade out
    if frame.fadeTimer then
        frame.fadeTimer:Cancel()
    end
    
    frame:SetAlpha(1)
    frame.fadeTimer = C_Timer.NewTimer(duration, function()
        -- Fade out animation
        local fadeOut = frame:CreateAnimationGroup()
        local alpha = fadeOut:CreateAnimation("Alpha")
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(0)
        alpha:SetDuration(0.5)
        fadeOut:SetScript("OnFinished", function()
            frame:Hide()
            frame:SetAlpha(1)
        end)
        fadeOut:Play()
    end)
end

function BR:Notify(msg, msgType, duration)
    -- Show chat message and screen message (popups handle their own sound)
    self:Print(msg, msgType)
    self:ShowScreenMessage(msg, msgType, duration)
end

function BR:Debug(msg)
    if self:GetSetting("DebugMode") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF888888[AfO Debug]|r " .. tostring(msg))
    end
end

----------------------------------------------------------------------
--  SavedVariables Obfuscation (XOR + Base64)
----------------------------------------------------------------------

local OBFUSCATION_KEY = "AllforOneGuildSecure2024"

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64decode(data)
    data = string.gsub(data, '[^'..b64chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b64chars:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function xorEncrypt(str, key)
    local result = {}
    local keyLen = #key
    for i = 1, #str do
        local charCode = string.byte(str, i)
        local keyChar = string.byte(key, ((i - 1) % keyLen) + 1)
        result[i] = string.char(bit.bxor(charCode, keyChar))
    end
    return table.concat(result)
end

function BR:ObfuscateString(str)
    if type(str) ~= "string" then return str end
    local encrypted = xorEncrypt(str, OBFUSCATION_KEY)
    return base64encode(encrypted)
end

function BR:DeobfuscateString(str)
    if type(str) ~= "string" then return str end
    local decoded = base64decode(str)
    return xorEncrypt(decoded, OBFUSCATION_KEY)
end

function BR:ObfuscateTable(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "string" then
            result[k] = self:ObfuscateString(v)
        elseif type(v) == "table" then
            result[k] = self:ObfuscateTable(v)
        else
            result[k] = v
        end
    end
    return result
end

function BR:DeobfuscateTable(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "string" then
            result[k] = self:DeobfuscateString(v)
        elseif type(v) == "table" then
            result[k] = self:DeobfuscateTable(v)
        else
            result[k] = v
        end
    end
    return result
end

function BR:ObfuscateSavedVariables()
    if AllforOneDB.AddonUsers then
        local obfuscated = {}
        for name, data in pairs(AllforOneDB.AddonUsers) do
            local obfName = self:ObfuscateString(name)
            if type(data) == "table" then
                obfuscated[obfName] = self:ObfuscateTable(data)
            else
                obfuscated[obfName] = data
            end
        end
        AllforOneDB.AddonUsers = obfuscated
        AllforOneDB._obfuscated = true
    end
end

function BR:DeobfuscateSavedVariables()
    if not AllforOneDB._obfuscated then return end
    
    if AllforOneDB.AddonUsers then
        local deobfuscated = {}
        for name, data in pairs(AllforOneDB.AddonUsers) do
            local realName = self:DeobfuscateString(name)
            if type(data) == "table" then
                deobfuscated[realName] = self:DeobfuscateTable(data)
            else
                deobfuscated[realName] = data
            end
        end
        AllforOneDB.AddonUsers = deobfuscated
    end
    
    AllforOneDB._obfuscated = nil
end

----------------------------------------------------------------------
--  Settings Management
----------------------------------------------------------------------

function BR:GetSetting(key)
    if AllforOneCharDB[key] ~= nil then
        return AllforOneCharDB[key]
    end
    return AllforOneDB[key]
end

function BR:SetSetting(key, value, perCharacter)
    if perCharacter then
        AllforOneCharDB[key] = value
    else
        AllforOneDB[key] = value
    end
end

-- Setzt alle Einstellungen zurück und synchronisiert mit Gildenmeister/Offizier
-- WICHTIG: SecurityData (playedTime etc.) wird NICHT gelöscht!
function BR:ResetSettings(callback)
    self:Print("Einstellungen werden zurückgesetzt...", "info")
    
    -- SecurityData sichern BEVOR wir löschen
    local securityData = AllforOneCharDB.SecurityData
    local securityDataObf = AllforOneCharDB._sd
    
    -- Lösche alle Character-spezifischen Einstellungen
    wipe(AllforOneCharDB)
    
    -- SecurityData wiederherstellen
    if securityData then
        AllforOneCharDB.SecurityData = securityData
    elseif securityDataObf then
        AllforOneCharDB._sd = securityDataObf
    end
    
    -- Initialisiere Standardwerte
    self:InitializeDefaults()
    
    -- Versuche Settings von Gildenmeister/Offizier zu synchronisieren
    if self:IsInGuild() and not self:IsGuildMaster() then
        -- Flag setzen dass wir auf Sync warten
        self.waitingForSettingsSync = true
        self.settingsSyncCallback = callback
        
        -- Request Settings von der Gilde
        self:RequestGuildSettings()
        
        -- Timeout nach 5 Sekunden - falls niemand antwortet, Standardwerte behalten
        C_Timer.After(5, function()
            if self.waitingForSettingsSync then
                self.waitingForSettingsSync = false
                self.settingsSyncCallback = nil
                self:Print("Keine Antwort von Gildenleitung - Standardwerte werden verwendet.", "warning")
                self:RefreshModules()
                if callback then callback(false) end
            end
        end)
    else
        -- Gildenmeister oder keine Gilde - sofort fertig
        self:RefreshModules()
        self:Print("Einstellungen wurden auf Standardwerte zurückgesetzt.", "info")
        if callback then callback(true) end
    end
end

function BR:InitializeDefaults()
    local defaults = {
        Enabled = true,
        BlockTrade = true,
        BlockGroupInvites = true,
        BlockLFG = true,
        BlockAuction = true,
        BlockMail = true,
        BlockCraftingOrders = true,
        BlockWarbound = true,
        BlockDragonFlying = true, -- Himmelsreiten bis Level 80 blockieren
        MailBlockMode = "selective", -- "full" or "selective"
        DebugMode = false,
        MuteNotificationSounds = false,
        ShowWelcomeOnLogin = true,
        GuildMapEnabled = true, -- Gildenkarte aktiviert
        GuildMapShowNames = true, -- Spielernamen anzeigen
        GuildMapPinSize = 32, -- Größe der Gildenkarten-Pins (16-64)
    }
    
    for key, value in pairs(defaults) do
        if AllforOneCharDB[key] == nil then
            AllforOneCharDB[key] = value
        end
    end
    
    -- Global defaults
    if AllforOneDB.AddonUsers == nil then
        AllforOneDB.AddonUsers = {}
    end
end

----------------------------------------------------------------------
--  Guild Functions
----------------------------------------------------------------------

function BR:IsInGuild()
    return IsInGuild()
end

function BR:GetGuildName()
    if not self:IsInGuild() then return nil end
    local guildName = GetGuildInfo("player")
    return guildName
end

function BR:IsGuildMember(playerName)
    if not self:IsInGuild() then return false end
    
    -- Remove realm name if present
    local name = playerName
    if name then
        name = strsplit("-", name)
    end
    
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local guildMemberName = GetGuildRosterInfo(i)
        if guildMemberName then
            local guildMemberShort = strsplit("-", guildMemberName)
            if guildMemberShort and name and guildMemberShort:lower() == name:lower() then
                return true
            end
        end
    end
    return false
end

function BR:IsGuildOfficer()
    if not self:IsInGuild() then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    -- Rank 0 = Guild Master, Rank 1 = typically first officer rank
    -- We consider ranks 0 and 1 as officers, but this may vary per guild
    return rankIndex ~= nil and rankIndex <= 1
end

function BR:IsGuildMaster()
    if not self:IsInGuild() then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    return rankIndex == 0
end

----------------------------------------------------------------------
--  Module System
----------------------------------------------------------------------

function BR:RegisterModule(name, module)
    self.Modules[name] = module
    if module.OnInitialize then
        module:OnInitialize()
    end
end

function BR:EnableModules()
    for name, module in pairs(self.Modules) do
        if module.OnEnable and self:GetSetting("Enabled") then
            module:OnEnable()
            self:Debug("Module enabled: " .. name)
        end
    end
end

function BR:DisableModules()
    for name, module in pairs(self.Modules) do
        if module.OnDisable then
            module:OnDisable()
            self:Debug("Module disabled: " .. name)
        end
    end
end

function BR:RefreshModules()
    for name, module in pairs(self.Modules) do
        if module.Refresh then
            module:Refresh()
        end
    end
end

----------------------------------------------------------------------
--  Addon Communication
----------------------------------------------------------------------

local COMM_PREFIX = "AllforOne"
local commRegistered = false

function BR:InitializeComm()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local success = C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        if success then
            commRegistered = true
            self:Debug("Addon message prefix registered")
        end
    end
end

function BR:SendAddonMessage(msg, channel, target)
    if not commRegistered then return end
    
    channel = channel or "GUILD"
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, msg, channel, target)
    end
end

function BR:BroadcastStatus()
    if not self:IsInGuild() then return end
    
    local status = self:GetSetting("Enabled") and "ENABLED" or "DISABLED"
    local playerName = UnitName("player")
    local msg = string.format("STATUS:%s:%s:%s", playerName, status, self.Version)
    self:SendAddonMessage(msg, "GUILD")
    
    -- Also update own entry immediately (we don't receive our own messages)
    if not AllforOneDB.AddonUsers then
        AllforOneDB.AddonUsers = {}
    end
    local key = playerName:lower()
    AllforOneDB.AddonUsers[key] = {
        status = status,
        version = self.Version,
        lastSeen = time(),
        sender = playerName,
        displayName = playerName
    }
    
    self:Debug("Status broadcasted: " .. status)
end

-- Setup periodic heartbeat to keep status up to date
function BR:SetupStatusHeartbeat()
    if self.heartbeatTimer then return end
    
    -- Broadcast status every 5 minutes (reduced frequency for performance)
    self.heartbeatTimer = C_Timer.NewTicker(300, function()
        if BR:IsInGuild() then
            BR:BroadcastStatus()
        end
    end)
    
    self:Debug("Status heartbeat started (every 5 min)")
end

-- Ping all online guild members and track who responds
function BR:PingGuildMembers()
    if not self:IsInGuild() then return end
    
    -- Store timestamp of when we pinged
    AllforOneDB.LastPingTime = time()
    AllforOneDB.PendingPingResponses = {}
    
    -- Get list of online guild members
    local numMembers = GetNumGuildMembers()
    local onlineCount = 0
    
    for i = 1, numMembers do
        local fullName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if fullName and isOnline then
            local shortName = strsplit("-", fullName)
            AllforOneDB.PendingPingResponses[shortName:lower()] = true
            onlineCount = onlineCount + 1
        end
    end
    
    -- Send the ping
    self:SendAddonMessage("PING", "GUILD")
    self:Debug("Pinged guild - " .. onlineCount .. " online members")
    self:Print("Status-Anfrage an " .. onlineCount .. " Online-Mitglieder gesendet...", "info")
    
    -- After 10 seconds, check who didn't respond
    C_Timer.After(10, function()
        BR:CheckPingResponses()
    end)
    
    return onlineCount
end

-- Check who responded to the ping
function BR:CheckPingResponses()
    if not AllforOneDB.PendingPingResponses then return end
    if not AllforOneDB.LastPingTime then return end
    
    local pingTime = AllforOneDB.LastPingTime
    local noResponseCount = 0
    local responseCount = 0
    local totalOnline = 0
    
    -- Check each pending response
    for name, pending in pairs(AllforOneDB.PendingPingResponses) do
        totalOnline = totalOnline + 1
        local info = AllforOneDB.AddonUsers and AllforOneDB.AddonUsers[name]
        
        if info and info.lastSeen and info.lastSeen >= pingTime then
            -- Got a response after the ping
            responseCount = responseCount + 1
            self:Debug("Response received from: " .. name)
        else
            -- No response - mark as no addon
            noResponseCount = noResponseCount + 1
            if not AllforOneDB.AddonUsers then
                AllforOneDB.AddonUsers = {}
            end
            -- Mark as no addon (nil status means no addon)
            AllforOneDB.AddonUsers[name] = nil
            self:Debug("No response from online player: " .. name .. " (no addon)")
        end
    end
    
    -- Clear pending list
    AllforOneDB.PendingPingResponses = nil
    
    -- Show summary
    self:Print("Status-Sync abgeschlossen: " .. responseCount .. "/" .. totalOnline .. " haben geantwortet.", "info")
    if noResponseCount > 0 then
        self:Debug(noResponseCount .. " online players have no addon installed")
    end
    
    -- Refresh admin panel if open
    if BR.Modules.AdminPanel and BR.Modules.AdminPanel.Refresh then
        BR.Modules.AdminPanel:Refresh()
    end
end

-- Clean up old addon user entries that haven't responded
function BR:CleanupOldAddonUsers()
    if not AllforOneDB.AddonUsers then return end
    
    local now = time()
    local cutoff = 7 * 24 * 60 * 60 -- 7 days
    local cleaned = 0
    
    for name, info in pairs(AllforOneDB.AddonUsers) do
        if info.lastSeen and (now - info.lastSeen) > cutoff then
            AllforOneDB.AddonUsers[name] = nil
            cleaned = cleaned + 1
            self:Debug("Cleaned up old entry: " .. name)
        end
    end
    
    if cleaned > 0 then
        self:Debug("Cleaned up " .. cleaned .. " old entries")
    end
end

function BR:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    
    local msgType, data1, data2, data3 = strsplit(":", message)
    
    if msgType == "STATUS" then
        -- Store user status for admin panel
        local playerName, status, version = data1, data2, data3
        if not AllforOneDB.AddonUsers then
            AllforOneDB.AddonUsers = {}
        end
        local shortName = playerName and strsplit("-", playerName) or playerName
        local key = shortName and shortName:lower() or playerName:lower()
        
        local oldInfo = AllforOneDB.AddonUsers[key]
        local isNew = not oldInfo
        local statusChanged = oldInfo and oldInfo.status ~= status
        
        AllforOneDB.AddonUsers[key] = {
            status = status,
            version = version,
            lastSeen = time(),
            sender = sender,
            displayName = playerName
        }
        
        -- Remove from pending responses if we're tracking
        if AllforOneDB.PendingPingResponses then
            AllforOneDB.PendingPingResponses[key] = nil
        end
        
        if isNew then
            self:Debug("New addon user: " .. playerName .. " (" .. status .. ", v" .. (version or "?") .. ")")
        elseif statusChanged then
            self:Debug("Status changed: " .. playerName .. " -> " .. status)
        else
            self:Debug("Status update: " .. playerName .. " (" .. status .. ")")
        end
    elseif msgType == "PING" then
        -- Respond to status request immediately
        self:BroadcastStatus()
    elseif msgType == "GUILD_SETTINGS" or msgType == "OFFICER_SETTINGS" then
        -- Received guild-wide settings from GM or officer
        self:HandleGuildSettings(message, sender)
    elseif msgType == "REQUEST_HASH" then
        -- Someone is requesting the current settings hash
        -- Priority: Guild Master > Officer
        if self:IsGuildMaster() then
            self:RespondToHashRequest(sender)
        elseif self:IsGuildOfficer() then
            -- Officer responds after a small delay to let GM respond first
            C_Timer.After(0.5, function()
                self:RespondToHashRequest(sender)
            end)
        end
    elseif msgType == "HASH_RESPONSE" then
        -- Received hash response, compare with local hash
        self:HandleHashResponse(message, sender)
    elseif msgType == "REQUEST_SETTINGS" then
        -- Someone is requesting current guild settings
        -- Priority: Guild Master > Officer
        if self:IsGuildMaster() then
            -- Guild master always responds
            self:BroadcastGuildSettings()
        elseif self:IsGuildOfficer() then
            -- Officer responds with their settings (includes hash for comparison)
            C_Timer.After(0.5, function()
                self:BroadcastGuildSettingsAsOfficer()
            end)
        end
    elseif msgType == "GUILD_RULES_UPDATE" then
        -- Guild master updated rules
        self:HandleGuildRulesUpdate(message, sender)
    elseif msgType == "RESET_WARNING" then
        -- Officer wants to reset a player's warning
        local targetPlayer = data1
        local myName = UnitName("player")
        if targetPlayer and targetPlayer:lower() == myName:lower() then
            -- This reset is for me
            if BR.Modules.SecurityCheck then
                BR.Modules.SecurityCheck:ResetWarning(sender)
            end
        end
    elseif msgType == "GUILDMAP" then
        -- GuildMap position update
        if BR.Modules.GuildMap and BR.Modules.GuildMap.HandlePositionMessage then
            BR.Modules.GuildMap:HandlePositionMessage(message, sender)
        end
    end
end

-- Handle hash response from GM or Officer
function BR:HandleHashResponse(message, sender)
    local parts = {strsplit(":", message)}
    if parts[1] ~= "HASH_RESPONSE" then return end
    
    local remoteHash = parts[2] or ""
    local isFromGM = parts[3] == "1"
    local localHash = self:GetStoredHash()
    
    -- If we already received a GM response, ignore officer responses
    if BR.receivedGMHash and not isFromGM then
        self:Debug("Ignoring officer hash response (already have GM hash)")
        return
    end
    
    if isFromGM then
        BR.receivedGMHash = true
    end
    
    self:Debug("Hash response from " .. sender .. " (GM: " .. tostring(isFromGM) .. "): " .. remoteHash .. " vs local: " .. localHash)
    
    -- Compare hashes
    if remoteHash ~= localHash then
        -- Hash is different, request full settings
        self:Debug("Hash mismatch! Requesting full settings...")
        self:RequestGuildSettings()
    else
        self:Debug("Hash matches, settings are up to date")
    end
end

function BR:HandleGuildSettings(message, sender)
    local parts = {strsplit(":", message)}
    if parts[1] ~= "GUILD_SETTINGS" and parts[1] ~= "OFFICER_SETTINGS" then return end
    
    local isFromGuildMaster = parts[1] == "GUILD_SETTINGS"
    local isFromOfficer = parts[1] == "OFFICER_SETTINGS"
    
    -- Parse settings: GUILD_SETTINGS:BlockTrade:BlockGroup:BlockLFG:BlockAuction:BlockMail:BlockWarbound:BlockCrafting:MailBlockMode(binary):BlockDragonFlying:hash
    local settings = {
        BlockTrade = parts[2] == "1",
        BlockGroupInvites = parts[3] == "1",
        BlockLFG = parts[4] == "1",
        BlockAuction = parts[5] == "1",
        BlockMail = parts[6] == "1",
        BlockWarbound = parts[7] == "1",
        BlockCraftingOrders = parts[8] == "1",
        MailBlockMode = parts[9] == "1" and "full" or "selective",
        BlockDragonFlying = parts[10] == "1",
    }
    local receivedHash = parts[11] or ""
    
    -- Priority logic:
    -- 1. Guild Master settings ALWAYS override everything
    -- 2. Officer settings only apply if we don't have recent GM settings
    
    local storedFromGM = AllforOneDB.GuildSettingsFromGM or false
    local shouldApply = false
    
    if isFromGuildMaster then
        -- Guild Master always wins
        shouldApply = true
        AllforOneDB.GuildSettingsFromGM = true
        self:Debug("Received settings from Guild Master: " .. sender .. " - Hash: " .. receivedHash)
    elseif isFromOfficer then
        -- Officer settings only apply if no recent GM settings
        if not storedFromGM then
            shouldApply = true
            AllforOneDB.GuildSettingsFromGM = false
            self:Debug("Received settings from Officer: " .. sender .. " - Hash: " .. receivedHash)
        else
            self:Debug("Ignored Officer settings - have GM settings")
        end
    end
    
    if shouldApply then
        AllforOneDB.GuildSettings = settings
        AllforOneDB.GuildSettingsSender = sender
        
        -- Store the hash
        self:SetStoredHash(receivedHash)
        
        -- Apply settings if not the guild master (guild master sets their own)
        -- Only apply guild-synced settings, NOT local settings like DebugMode
        if not self:IsGuildMaster() then
            local guildSyncedSettings = {
                "BlockTrade", "BlockGroupInvites", "BlockLFG", "BlockAuction",
                "BlockMail", "BlockWarbound", "BlockCraftingOrders", "MailBlockMode",
                "BlockDragonFlying"
            }
            for _, key in ipairs(guildSyncedSettings) do
                if settings[key] ~= nil then
                    AllforOneCharDB[key] = settings[key]
                end
            end
            self:RefreshModules()
            self:Debug("Guild settings applied from " .. sender)
        end
    end
end

-- Calculate a hash from current settings (changes only when settings change)
function BR:CalculateSettingsHash()
    local mailMode = self:GetSetting("MailBlockMode") or "selective"
    local hashParts = {
        self:GetSetting("BlockTrade") and "1" or "0",
        self:GetSetting("BlockGroupInvites") and "1" or "0",
        self:GetSetting("BlockLFG") and "1" or "0",
        self:GetSetting("BlockAuction") and "1" or "0",
        self:GetSetting("BlockMail") and "1" or "0",
        self:GetSetting("BlockWarbound") and "1" or "0",
        self:GetSetting("BlockCraftingOrders") and "1" or "0",
        mailMode == "full" and "1" or "0",
        self:GetSetting("BlockDragonFlying") and "1" or "0",
    }
    return table.concat(hashParts, "")
end

-- Get stored hash from DB
function BR:GetStoredHash()
    return AllforOneDB.GuildSettingsHash or ""
end

-- Store hash in DB
function BR:SetStoredHash(hash)
    AllforOneDB.GuildSettingsHash = hash
end

function BR:BroadcastGuildSettings(forceNewHash)
    if not self:IsGuildMaster() then return end
    if not self:IsInGuild() then return end
    
    local currentHash = self:CalculateSettingsHash()
    
    -- Only update stored hash if settings actually changed (or forced)
    if forceNewHash or currentHash ~= self:GetStoredHash() then
        self:SetStoredHash(currentHash)
    end
    
    local mailMode = self:GetSetting("MailBlockMode") or "selective"
    local settings = {
        self:GetSetting("BlockTrade") and "1" or "0",
        self:GetSetting("BlockGroupInvites") and "1" or "0",
        self:GetSetting("BlockLFG") and "1" or "0",
        self:GetSetting("BlockAuction") and "1" or "0",
        self:GetSetting("BlockMail") and "1" or "0",
        self:GetSetting("BlockWarbound") and "1" or "0",
        self:GetSetting("BlockCraftingOrders") and "1" or "0",
        mailMode == "full" and "1" or "0",
        self:GetSetting("BlockDragonFlying") and "1" or "0",
        currentHash
    }
    
    local msg = "GUILD_SETTINGS:" .. table.concat(settings, ":")
    self:SendAddonMessage(msg, "GUILD")
    
    -- Also store locally
    AllforOneDB.GuildSettings = {
        BlockTrade = self:GetSetting("BlockTrade"),
        BlockGroupInvites = self:GetSetting("BlockGroupInvites"),
        BlockLFG = self:GetSetting("BlockLFG"),
        BlockAuction = self:GetSetting("BlockAuction"),
        BlockMail = self:GetSetting("BlockMail"),
        BlockWarbound = self:GetSetting("BlockWarbound"),
        BlockCraftingOrders = self:GetSetting("BlockCraftingOrders"),
        MailBlockMode = self:GetSetting("MailBlockMode"),
        BlockDragonFlying = self:GetSetting("BlockDragonFlying"),
    }
    AllforOneDB.GuildSettingsFromGM = true
    
    self:Debug("Guild settings broadcasted (Guild Master) - Hash: " .. currentHash)
end

-- Send settings without changing hash (manual sync button)
function BR:SendGuildSettings()
    if not self:IsGuildMaster() then return end
    self:BroadcastGuildSettings(false) -- Don't force new hash
    self:Print("Einstellungen an alle Online-Gildenmitglieder gesendet.", "info")
end

-- Officer can broadcast settings when GM is offline
function BR:BroadcastGuildSettingsAsOfficer()
    if not self:IsGuildOfficer() then return end
    if self:IsGuildMaster() then return end -- GM uses BroadcastGuildSettings
    if not self:IsInGuild() then return end
    
    -- Use stored guild settings and hash
    local storedSettings = AllforOneDB.GuildSettings
    local storedHash = self:GetStoredHash()
    
    local settings
    if storedSettings then
        local mailMode = storedSettings.MailBlockMode or "selective"
        settings = {
            storedSettings.BlockTrade and "1" or "0",
            storedSettings.BlockGroupInvites and "1" or "0",
            storedSettings.BlockLFG and "1" or "0",
            storedSettings.BlockAuction and "1" or "0",
            storedSettings.BlockMail and "1" or "0",
            storedSettings.BlockWarbound and "1" or "0",
            storedSettings.BlockCraftingOrders and "1" or "0",
            mailMode == "full" and "1" or "0",
            (storedSettings.BlockDragonFlying ~= false) and "1" or "0",
            storedHash
        }
    else
        -- No stored settings, use current character settings
        local currentHash = self:CalculateSettingsHash()
        local mailMode = self:GetSetting("MailBlockMode") or "selective"
        settings = {
            self:GetSetting("BlockTrade") and "1" or "0",
            self:GetSetting("BlockGroupInvites") and "1" or "0",
            self:GetSetting("BlockLFG") and "1" or "0",
            self:GetSetting("BlockAuction") and "1" or "0",
            self:GetSetting("BlockMail") and "1" or "0",
            self:GetSetting("BlockWarbound") and "1" or "0",
            self:GetSetting("BlockCraftingOrders") and "1" or "0",
            mailMode == "full" and "1" or "0",
            self:GetSetting("BlockDragonFlying") and "1" or "0",
            currentHash
        }
    end
    
    local msg = "OFFICER_SETTINGS:" .. table.concat(settings, ":")
    self:SendAddonMessage(msg, "GUILD")
    
    self:Debug("Guild settings broadcasted (Officer) - Hash: " .. (storedHash or "none"))
end

-- Respond to hash request (GM or Officer)
function BR:RespondToHashRequest(requester)
    if not self:IsInGuild() then return end
    
    local storedHash = self:GetStoredHash()
    if storedHash == "" then return end -- No hash stored, don't respond
    
    local isGM = self:IsGuildMaster() and "1" or "0"
    local msg = "HASH_RESPONSE:" .. storedHash .. ":" .. isGM
    self:SendAddonMessage(msg, "WHISPER", requester)
    
    self:Debug("Hash response sent to " .. requester .. " - Hash: " .. storedHash)
end

-- Request hash from guild (called on login)
function BR:RequestGuildHash()
    if not self:IsInGuild() then return end
    if self:IsGuildMaster() then return end -- GM doesn't need to request
    
    self:SendAddonMessage("REQUEST_HASH", "GUILD")
    self:Debug("Requesting hash from guild...")
end

function BR:RequestGuildSettings()
    if not self:IsInGuild() then return end
    self:SendAddonMessage("REQUEST_SETTINGS", "GUILD")
    self:Debug("Requesting full settings from guild...")
end

function BR:BroadcastGuildRules(rules)
    if not self:IsGuildMaster() then return end
    if not self:IsInGuild() then return end
    
    -- Rules are too long for single message, so we store locally and sync timestamp
    AllforOneDB.GuildRules = rules
    AllforOneDB.GuildRulesTimestamp = time()
    
    -- Send sync signal with timestamp (rules will be requested separately)
    local msg = "GUILD_RULES_UPDATE:" .. tostring(time())
    self:SendAddonMessage(msg, "GUILD")
    
    self:Debug("Guild rules broadcasted")
end

function BR:HandleGuildRulesUpdate(message, sender)
    local parts = {strsplit(":", message)}
    if parts[1] ~= "GUILD_RULES_UPDATE" then return end
    
    local timestamp = tonumber(parts[2]) or 0
    local storedTimestamp = AllforOneDB.GuildRulesTimestamp or 0
    
    -- Request full rules if newer
    if timestamp > storedTimestamp then
        self:SendAddonMessage("REQUEST_RULES", "WHISPER", sender)
    end
end

----------------------------------------------------------------------
--  Event Handling
----------------------------------------------------------------------

BR.Events:RegisterEvent("ADDON_LOADED")
BR.Events:RegisterEvent("PLAYER_LOGIN")
BR.Events:RegisterEvent("PLAYER_ENTERING_WORLD")
BR.Events:RegisterEvent("PLAYER_LOGOUT")
BR.Events:RegisterEvent("CHAT_MSG_ADDON")
BR.Events:RegisterEvent("GUILD_ROSTER_UPDATE")

BR.Events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            BR:InitializeDefaults()
            BR:DeobfuscateSavedVariables()
            BR:InitializeComm()
            BR:Debug("Addon loaded")
        end
    elseif event == "PLAYER_LOGOUT" then
        BR:ObfuscateSavedVariables()
        -- Verschleiere geschützte Settings
        if BR.SettingsProtection then
            BR.SettingsProtection:ObfuscateSettings()
        end
    elseif event == "PLAYER_LOGIN" then
        BR:EnableModules()
        
        -- Reset hash response tracking
        BR.receivedGMHash = false
        
        C_Timer.After(3, function()
            -- Request hash first (more efficient than full settings)
            -- If hash differs, full settings will be requested automatically
            BR:RequestGuildHash()
        end)
        C_Timer.After(5, function()
            BR:BroadcastStatus()
            -- If guild master, also broadcast current settings with hash
            if BR:IsGuildMaster() then
                BR:BroadcastGuildSettings(true) -- Force hash update on login
            end
        end)
        -- Ping all guild members after 15 seconds (give time for everything to load)
        C_Timer.After(15, function()
            BR:PingGuildMembers()
        end)
        -- Setup periodic status broadcast (heartbeat every 5 minutes)
        BR:SetupStatusHeartbeat()
        
        if BR:GetSetting("Enabled") then
            BR:Print("Addon aktiviert für diesen Charakter", "info")
        else
            BR:Print("Addon ist deaktiviert. Nutze /br enable zum Aktivieren.", "warning")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        BR:RefreshModules()
    elseif event == "CHAT_MSG_ADDON" then
        BR:HandleAddonMessage(...)
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- Refresh guild member cache
        if BR.Modules.GuildCheck and BR.Modules.GuildCheck.RefreshCache then
            BR.Modules.GuildCheck:RefreshCache()
        end
    end
end)

----------------------------------------------------------------------
--  Slash Commands
----------------------------------------------------------------------

SLASH_ALLFORONE1 = "/allforone"
SLASH_ALLFORONE2 = "/afo"

SlashCmdList["ALLFORONE"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    cmd = cmd and cmd:lower() or ""
    
    if cmd == "" or cmd == "config" or cmd == "options" then
        BR:OpenConfig()
    elseif cmd == "status" then
        BR:Print("Gilde: " .. (BR:GetGuildName() or "Keine"))
        BR:Print("Gildenmeister: " .. (BR:IsGuildMaster() and "Ja" or "Nein"))
    elseif cmd == "admin" or cmd == "overview" or cmd == "list" then
        BR:OpenAddonOverview()
    elseif cmd == "ping" then
        BR:PingGuildMembers()
    elseif cmd == "debug" then
        local current = BR:GetSetting("DebugMode")
        BR:SetSetting("DebugMode", not current, true)
        BR:Print("Debug-Modus: " .. (not current and "aktiviert" or "deaktiviert"))
    elseif cmd == "reset" then
        -- Reset security warning for a player (officers only)
        if not BR:IsGuildOfficer() then
            BR:Print("Nur Offiziere können Warnungen zurücksetzen!", "error")
            return
        end
        if not arg or arg == "" then
            BR:Print("Verwendung: /br reset <Spielername>", "warning")
            return
        end
        -- Send reset message to the target player
        BR:SendAddonMessage("RESET_WARNING:" .. arg, "GUILD")
        BR:Print("Reset-Befehl für " .. arg .. " gesendet.", "info")
    elseif cmd == "hilfe" or cmd == "help" then
        BR:Print("|cFFFFCC00=== All for One Befehle ===|r")
        BR:Print("|cFF00FF00Addon:|r")
        BR:Print("  /afo - Einstellungen öffnen")
        BR:Print("  /afo status - Status anzeigen")
        BR:Print("  /afo debug - Debug-Modus umschalten")
        if BR:IsGuildOfficer() then
            BR:Print("|cFF00FF00Offizier:|r")
            BR:Print("  /afo admin - Offizier-Übersicht öffnen")
            BR:Print("  /afo ping - Gildenmitglieder pingen")
            BR:Print("  /afo reset <Name> - Warnung zurücksetzen")
        end
        BR:Print("|cFF00FF00QoL Shortcuts:|r")
        BR:Print("  /rl - UI neu laden")
        BR:Print("  /rc - Ready Check")
        BR:Print("  /inv <Name> - Spieler einladen")
        BR:Print("  /pt [Sek] - Pull Timer (Standard: 10)")
        BR:Print("  /pt stop - Pull Timer abbrechen")
    else
        BR:Print("Unbekannter Befehl. /afo hilfe für alle Befehle.")
    end
end

BR:Print("v" .. BR.Version .. " geladen. /afo für Hilfe.", "info")
