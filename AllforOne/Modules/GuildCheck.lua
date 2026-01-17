----------------------------------------------------------------------
--  All for One - Guild Check Module
--  Caches guild members for efficient lookups
----------------------------------------------------------------------

local addonName, BR = ...

local GuildCheck = {
    cache = {},
    lastUpdate = 0,
    updateInterval = 120, -- seconds (increased for performance)
}

function GuildCheck:OnInitialize()
    BR:Debug("GuildCheck module initialized")
end

function GuildCheck:OnEnable()
    self:RefreshCache()
end

function GuildCheck:OnDisable()
    -- Nothing to clean up
end

function GuildCheck:Refresh()
    self:RefreshCache()
end

function GuildCheck:RefreshCache()
    if not BR:IsInGuild() then
        self.cache = {}
        return
    end
    
    local now = GetTime()
    if now - self.lastUpdate < self.updateInterval then
        return
    end
    
    self.cache = {}
    local numMembers = GetNumGuildMembers()
    
    for i = 1, numMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, 
              publicNote, officerNote, isOnline, status, class, 
              achievementPoints, achievementRank, isMobile, canSoR, repStanding, guid = GetGuildRosterInfo(i)
        
        if name then
            local shortName = strsplit("-", name)
            self.cache[shortName:lower()] = {
                fullName = name,
                rank = rankName,
                rankIndex = rankIndex,
                level = level,
                class = class,
                isOnline = isOnline,
                isMobile = isMobile,
                guid = guid
            }
        end
    end
    
    self.lastUpdate = now
    BR:Debug("Guild cache refreshed: " .. numMembers .. " members")
end

function GuildCheck:IsGuildMember(playerName)
    if not playerName then return false end
    if not BR:IsInGuild() then return false end
    
    -- Refresh if cache is old
    if GetTime() - self.lastUpdate > self.updateInterval then
        self:RefreshCache()
    end
    
    local shortName = strsplit("-", playerName)
    return self.cache[shortName:lower()] ~= nil
end

function GuildCheck:GetMemberInfo(playerName)
    if not playerName then return nil end
    
    local shortName = strsplit("-", playerName)
    return self.cache[shortName:lower()]
end

function GuildCheck:GetOnlineMembers()
    local online = {}
    for name, info in pairs(self.cache) do
        if info.isOnline then
            table.insert(online, info)
        end
    end
    return online
end

BR:RegisterModule("GuildCheck", GuildCheck)
