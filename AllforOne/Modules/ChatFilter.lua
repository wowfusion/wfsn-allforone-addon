----------------------------------------------------------------------
--  All for One - Chat Filter Module
--  Adds guild icon prefix to guild member messages in chat
----------------------------------------------------------------------

local addonName, BR = ...

local ChatFilter = {}

-- Icon texture path
local GUILD_ICON = "|TInterface\\AddOns\\AllforOne\\media\\icon-allforone.tga:14:14:0:0|t"

-- Store original AddMessage functions for each chat frame
local originalAddMessage = {}

-- Quick guild member lookup cache
local guildMemberCache = {}
local cacheLastUpdate = 0
local CACHE_DURATION = 60 -- seconds

function ChatFilter:OnInitialize()
    BR:Debug("ChatFilter module initialized")
end

function ChatFilter:OnEnable()
    self:UpdateGuildCache()
    self:HookChatFrames()
    
    -- Register for guild roster updates
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
        self.eventFrame:SetScript("OnEvent", function()
            ChatFilter:UpdateGuildCache()
        end)
    end
end

function ChatFilter:OnDisable()
    -- Restore original AddMessage functions
    for chatFrame, originalFunc in pairs(originalAddMessage) do
        if chatFrame and originalFunc then
            chatFrame.AddMessage = originalFunc
        end
    end
    wipe(originalAddMessage)
end

function ChatFilter:Refresh()
    self:UpdateGuildCache()
end

function ChatFilter:UpdateGuildCache()
    local now = GetTime()
    if (now - cacheLastUpdate) < CACHE_DURATION then return end
    
    wipe(guildMemberCache)
    
    if not IsInGuild() then return end
    
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name = GetGuildRosterInfo(i)
        if name then
            local shortName = strsplit("-", name)
            guildMemberCache[shortName:lower()] = true
        end
    end
    
    cacheLastUpdate = now
    BR:Debug("ChatFilter: Guild cache updated with " .. numMembers .. " members")
end

function ChatFilter:IsGuildMember(playerName)
    if not playerName then return false end
    local shortName = strsplit("-", playerName)
    return guildMemberCache[shortName:lower()] == true
end

-- Hook function to add icon for guild members
local function AddMessage_Hook(self, message, r, g, b, chatID, ...)
    -- Safety check using pcall to handle "secret value" errors
    local success, result = pcall(function()
        if not message or type(message) ~= "string" then
            return nil
        end
        return message
    end)
    
    -- If pcall failed or message is not a valid string, pass through unchanged
    if not success or not result then
        return originalAddMessage[self](self, message, r, g, b, chatID, ...)
    end
    
    -- Now we know message is a safe string
    local safeMessage = result
    
    -- Extract player name from the message
    local playerName = nil
    
    -- Try to extract from hyperlink format (covers most cases)
    playerName = safeMessage:match("|Hplayer:([^|]+)|h%[.-%]|h")
    if not playerName then
        playerName = safeMessage:match("|Hplayer:([^|]+)|h")
    end
    
    -- If not found, try bracket format
    if not playerName then
        playerName = safeMessage:match("%[(.-)%] flüstert:")  -- German whisper
        if not playerName then
            playerName = safeMessage:match("%[(.-)%] whispers:")  -- English whisper
        end
        if not playerName then
            playerName = safeMessage:match("^%[(.-)%]:")  -- Say/Yell format
        end
    end
    
    if playerName then
        -- Remove realm name for lookup
        local shortName = strsplit("-", playerName)
        
        -- Check if this player is a guild member
        if ChatFilter:IsGuildMember(shortName) then
            -- Check message length to avoid truncation
            if #safeMessage < 200 then
                safeMessage = GUILD_ICON .. " " .. safeMessage
            end
        end
    end
    
    -- Call the original AddMessage
    return originalAddMessage[self](self, safeMessage, r, g, b, chatID, ...)
end

function ChatFilter:HookChatFrames()
    -- Hook AddMessage for all default chat frames
    local maxChatWindows = NUM_CHAT_WINDOWS or 10
    
    for i = 1, maxChatWindows do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame.AddMessage and not originalAddMessage[chatFrame] then
            originalAddMessage[chatFrame] = chatFrame.AddMessage
            chatFrame.AddMessage = AddMessage_Hook
        end
    end
    
    BR:Debug("ChatFilter: Hooked " .. maxChatWindows .. " chat frames")
end

BR:RegisterModule("ChatFilter", ChatFilter)
