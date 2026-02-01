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
    -- Try to process the message, but catch any "secret value" errors
    local success, newMessage = pcall(function()
        -- These checks will throw if message is a "secret value"
        if type(message) ~= "string" then
            return nil
        end
        
        local msgLen = #message
        if msgLen == 0 or msgLen >= 200 then
            return nil
        end
        
        -- Extract player name from the message
        local playerName = message:match("|Hplayer:([^|]+)|h%[.-%]|h")
        if not playerName then
            playerName = message:match("|Hplayer:([^|]+)|h")
        end
        
        -- If not found, try bracket format
        if not playerName then
            playerName = message:match("%[(.-)%] flüstert:")  -- German whisper
        end
        if not playerName then
            playerName = message:match("%[(.-)%] whispers:")  -- English whisper
        end
        if not playerName then
            playerName = message:match("^%[(.-)%]:")  -- Say/Yell format
        end
        
        if playerName then
            -- Remove realm name for lookup
            local shortName = strsplit("-", playerName)
            BR:Debug("ChatFilter: Found player " .. tostring(shortName) .. " in message")
            
            -- Check if this player is a guild member
            if ChatFilter:IsGuildMember(shortName) then
                BR:Debug("ChatFilter: " .. tostring(shortName) .. " is guild member, adding icon")
                return GUILD_ICON .. " " .. message
            else
                BR:Debug("ChatFilter: " .. tostring(shortName) .. " is NOT guild member")
            end
        end
        
        return nil
    end)
    
    -- If pcall succeeded and returned a modified message (string), use it
    if success and type(newMessage) == "string" then
        return originalAddMessage[self](self, newMessage, r, g, b, chatID, ...)
    end
    
    -- Otherwise pass through the original message unchanged
    return originalAddMessage[self](self, message, r, g, b, chatID, ...)
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
