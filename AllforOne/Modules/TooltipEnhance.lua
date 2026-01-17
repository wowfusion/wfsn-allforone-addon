----------------------------------------------------------------------
--  All for One - Tooltip Enhancement Module
--  Shows guild info and addon status in player tooltips
----------------------------------------------------------------------

local addonName, BR = ...

local TooltipEnhance = {
    lastGuildMember = nil,
    lastTooltipUpdate = 0,
    lastTooltipTarget = nil,
}

function TooltipEnhance:OnInitialize()
    BR:Debug("TooltipEnhance module initialized")
end

function TooltipEnhance:OnEnable()
    self:HookTooltip()
    self:HookGuildRoster()
end

function TooltipEnhance:OnDisable()
    -- Nothing to disable
end

function TooltipEnhance:Refresh()
    -- Nothing to refresh
end

-- Check if tooltip already has AllforOne info
function TooltipEnhance:TooltipHasBRInfo(tooltip)
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("AllforOne Addon") then
                return true
            end
        end
    end
    return false
end

-- Add addon status info to tooltip for a guild member
function TooltipEnhance:AddAddonInfo(tooltip, playerName)
    if not playerName then return end
    
    -- Prevent duplicate entries - check if we already added info for this player
    local now = GetTime()
    if self.lastTooltipTarget == playerName:lower() and (now - self.lastTooltipUpdate) < 0.2 then
        return
    end
    
    -- Also check if tooltip already has AllforOne info
    if self:TooltipHasBRInfo(tooltip) then
        return
    end
    
    self.lastTooltipTarget = playerName:lower()
    self.lastTooltipUpdate = now
    
    local users = AllforOneDB and AllforOneDB.AddonUsers or {}
    local info = users[playerName:lower()]
    
    tooltip:AddLine(" ")
    tooltip:AddLine("|cFF00CCFFAllforOne Addon:|r", 0.4, 0.8, 1)
    
    if info then
        local statusText = info.status == "ENABLED" and "|cFF00FF00Aktiv|r" or "|cFFFFAA00Inaktiv|r"
        local versionText = info.version and ("v" .. info.version) or ""
        tooltip:AddLine("Status: " .. statusText .. " " .. versionText, 1, 1, 1)
        if info.lastSeen then
            local timeSince = GetTime() - info.lastSeen
            if timeSince < 60 then
                tooltip:AddLine("Zuletzt gesehen: Gerade eben", 0.6, 0.6, 0.6)
            elseif timeSince < 3600 then
                tooltip:AddLine("Zuletzt gesehen: vor " .. math.floor(timeSince/60) .. " Min", 0.6, 0.6, 0.6)
            end
        end
    else
        tooltip:AddLine("Status: |cFF888888Nicht installiert|r", 0.6, 0.6, 0.6)
    end
end

function TooltipEnhance:HookTooltip()
    if self.hooked then return end
    self.hooked = true
    
    -- Use TooltipDataProcessor for retail (modern API)
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            if tooltip ~= GameTooltip then return end
            
            local _, unit = tooltip:GetUnit()
            if not unit then return end
            
            -- Only for players
            if not UnitIsPlayer(unit) then return end
            
            local playerName = UnitName(unit)
            if not playerName then return end
            
            -- Check if in same guild
            local unitGuild = GetGuildInfo(unit)
            local myGuild = GetGuildInfo("player")
            
            if unitGuild and myGuild and unitGuild == myGuild then
                -- Same guild - show addon status
                self:AddAddonInfo(tooltip, playerName)
            elseif unitGuild then
                -- Different guild
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFFFF6600[Andere Gilde: " .. unitGuild .. "]|r", 1, 0.4, 0)
            else
                -- No guild
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFF888888[Keine Gilde]|r", 0.5, 0.5, 0.5)
            end
        end)
        BR:Debug("TooltipEnhance: TooltipDataProcessor hooked")
    else
        BR:Debug("TooltipEnhance: TooltipDataProcessor not available")
    end
end

-- Hook guild roster frame for member tooltips
function TooltipEnhance:HookGuildRoster()
    -- Hook when Blizzard_Communities addon loads (retail guild UI)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if arg1 == "Blizzard_Communities" then
            TooltipEnhance:HookCommunitiesFrame()
        elseif arg1 == "Blizzard_GuildUI" then
            TooltipEnhance:HookGuildFrame()
        end
    end)
    
    -- Try to hook immediately if already loaded
    if CommunitiesFrame then
        self:HookCommunitiesFrame()
    end
    if GuildFrame then
        self:HookGuildFrame()
    end
end

-- Hook the Communities frame (retail guild UI)
function TooltipEnhance:HookCommunitiesFrame()
    if self.communitiesHooked then return end
    if not CommunitiesFrame then return end
    self.communitiesHooked = true
    
    -- Hook the member list tooltip using ScrollBox (modern retail API)
    if CommunitiesFrame.MemberList and CommunitiesFrame.MemberList.ScrollBox then
        local scrollBox = CommunitiesFrame.MemberList.ScrollBox
        
        -- Hook when frames are acquired from the pool
        scrollBox:RegisterCallback("OnAcquiredFrame", function(_, frame)
            if frame and not frame.brHooked then
                frame.brHooked = true
                frame:HookScript("OnEnter", function(btn)
                    if btn.memberInfo and btn.memberInfo.name then
                        local name = btn.memberInfo.name
                        local shortName = strsplit("-", name)
                        TooltipEnhance.lastGuildMember = shortName
                        
                        C_Timer.After(0.05, function()
                            if GameTooltip:IsShown() and TooltipEnhance.lastGuildMember then
                                TooltipEnhance:AddAddonInfo(GameTooltip, TooltipEnhance.lastGuildMember)
                                GameTooltip:Show()
                            end
                        end)
                    end
                end)
                frame:HookScript("OnLeave", function()
                    TooltipEnhance.lastGuildMember = nil
                    TooltipEnhance.lastTooltipTarget = nil
                end)
            end
        end, self)
    end
    
    BR:Debug("TooltipEnhance: CommunitiesFrame hooked")
end

-- Hook the old guild frame (if used)
function TooltipEnhance:HookGuildFrame()
    if self.guildFrameHooked then return end
    if not GuildFrame then return end
    self.guildFrameHooked = true
    
    -- Hook GuildRoster button tooltips
    hooksecurefunc("GuildRoster_Update", function()
        local scrollFrame = GuildRosterContainer
        if not scrollFrame then return end
        
        for _, button in pairs(scrollFrame.buttons or {}) do
            if button and not button.brHooked then
                button.brHooked = true
                button:HookScript("OnEnter", function(self)
                    if self.guildIndex then
                        local name = GetGuildRosterInfo(self.guildIndex)
                        if name then
                            local shortName = strsplit("-", name)
                            C_Timer.After(0.05, function()
                                if GameTooltip:IsShown() then
                                    TooltipEnhance:AddAddonInfo(GameTooltip, shortName)
                                    GameTooltip:Show()
                                end
                            end)
                        end
                    end
                end)
            end
        end
    end)
    
    BR:Debug("TooltipEnhance: GuildFrame hooked")
end

BR:RegisterModule("TooltipEnhance", TooltipEnhance)
