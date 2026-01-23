----------------------------------------------------------------------
--  All for One - Group Block Module
--  Only allow group invites to/from guild members
----------------------------------------------------------------------

local addonName, BR = ...

local GroupBlock = {
    enabled = false,
    hooksInstalled = false,
    loginCooldown = true, -- Verhindert Gruppenprüfung direkt nach Login
}

function GroupBlock:OnInitialize()
    BR:Debug("GroupBlock module initialized")
    self:InstallHooks()
    self:HookGroupEvents() -- Register events early
end

function GroupBlock:OnEnable()
    if not BR:GetSetting("BlockGroupInvites") then return end
    
    self.enabled = true
    BR:Debug("GroupBlock enabled")
end

function GroupBlock:OnDisable()
    self.enabled = false
    BR:Debug("GroupBlock disabled")
end

function GroupBlock:Refresh()
    if BR:GetSetting("Enabled") and BR:GetSetting("BlockGroupInvites") then
        self.enabled = true
    else
        self.enabled = false
    end
end

function GroupBlock:ShouldBlock()
    return self.enabled and BR:GetSetting("Enabled") and BR:GetSetting("BlockGroupInvites")
end

function GroupBlock:IsGuildMember(playerName)
    if not playerName then return false end
    
    if BR.Modules.GuildCheck then
        return BR.Modules.GuildCheck:IsGuildMember(playerName)
    else
        return BR:IsGuildMember(playerName)
    end
end

function GroupBlock:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true
    
    -- Hook C_PartyInfo.InviteUnit (main invite function in retail)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        local originalInviteUnit = C_PartyInfo.InviteUnit
        C_PartyInfo.InviteUnit = function(name)
            if GroupBlock:ShouldBlock() and name then
                if not GroupBlock:IsGuildMember(name) then
                    GroupBlock:ShowBlockMessage("Einladung blockiert", name)
                    return
                end
            end
            return originalInviteUnit(name)
        end
    end
    
    -- Hook InviteUnit (fallback/classic API)
    if InviteUnit then
        local originalInviteUnit = InviteUnit
        _G.InviteUnit = function(name)
            if GroupBlock:ShouldBlock() and name then
                if not GroupBlock:IsGuildMember(name) then
                    GroupBlock:ShowBlockMessage("Einladung blockiert", name)
                    return
                end
            end
            return originalInviteUnit(name)
        end
    end
    
    -- Hook C_PartyInfo.ConfirmInviteUnit (when player is already in a group)
    if C_PartyInfo and C_PartyInfo.ConfirmInviteUnit then
        local originalConfirmInvite = C_PartyInfo.ConfirmInviteUnit
        C_PartyInfo.ConfirmInviteUnit = function(name)
            if GroupBlock:ShouldBlock() and name then
                if not GroupBlock:IsGuildMember(name) then
                    GroupBlock:ShowBlockMessage("Einladung blockiert", name)
                    StaticPopup_Hide("PARTY_INVITE_XREALM_CONFIRM")
                    StaticPopup_Hide("PARTY_INVITE")
                    return
                end
            end
            return originalConfirmInvite(name)
        end
    end
    
    -- Hook C_PartyInfo.RequestInviteFromUnit (request to join someone's group)
    if C_PartyInfo and C_PartyInfo.RequestInviteFromUnit then
        local originalRequestInvite = C_PartyInfo.RequestInviteFromUnit
        C_PartyInfo.RequestInviteFromUnit = function(name)
            if GroupBlock:ShouldBlock() and name then
                if not GroupBlock:IsGuildMember(name) then
                    GroupBlock:ShowBlockMessage("Beitrittsanfrage blockiert", name)
                    return
                end
            end
            return originalRequestInvite(name)
        end
    end
    
    -- Hook BNInviteFriend (Battle.net friend invites)
    if BNInviteFriend then
        local originalBNInvite = BNInviteFriend
        _G.BNInviteFriend = function(bnetIDGameAccount, ...)
            if GroupBlock:ShouldBlock() and bnetIDGameAccount then
                -- Get character name from Battle.net game account
                local gameAccountInfo = C_BattleNet.GetGameAccountInfoByID(bnetIDGameAccount)
                if gameAccountInfo then
                    local charName = gameAccountInfo.characterName
                    local realmName = gameAccountInfo.realmName
                    local fullName = charName
                    if realmName then
                        fullName = charName .. "-" .. realmName
                    end
                    if not GroupBlock:IsGuildMember(fullName) and not GroupBlock:IsGuildMember(charName) then
                        GroupBlock:ShowBlockMessage("Battle.net Einladung blockiert", charName or "Unbekannt")
                        return
                    end
                end
            end
            return originalBNInvite(bnetIDGameAccount, ...)
        end
    end
    
    -- Hook C_PartyInfo.InviteByBNetAccountID (alternate Battle.net invite)
    if C_PartyInfo and C_PartyInfo.InviteByBNetAccountID then
        local originalBNetInvite = C_PartyInfo.InviteByBNetAccountID
        C_PartyInfo.InviteByBNetAccountID = function(bnetAccountID, ...)
            if GroupBlock:ShouldBlock() and bnetAccountID then
                local accountInfo = C_BattleNet.GetAccountInfoByID(bnetAccountID)
                if accountInfo and accountInfo.gameAccountInfo then
                    local charName = accountInfo.gameAccountInfo.characterName
                    local realmName = accountInfo.gameAccountInfo.realmName
                    local fullName = charName
                    if realmName then
                        fullName = charName .. "-" .. realmName
                    end
                    if not GroupBlock:IsGuildMember(fullName) and not GroupBlock:IsGuildMember(charName) then
                        GroupBlock:ShowBlockMessage("Battle.net Einladung blockiert", charName or accountInfo.accountName or "Unbekannt")
                        return
                    end
                end
            end
            return originalBNetInvite(bnetAccountID, ...)
        end
    end
    
    -- Hook StaticPopup buttons for group invites to non-guild members
    hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2, data)
        if not GroupBlock:ShouldBlock() then return end
        
        -- Handle various group-related popups
        if which == "PARTY_INVITE_XREALM_CONFIRM" or which == "PARTY_INVITE_CONFIRM" then
            -- These popups appear when inviting someone already in a group
            local name = text_arg1 or data
            if name and not GroupBlock:IsGuildMember(name) then
                C_Timer.After(0.01, function()
                    StaticPopup_Hide(which)
                    GroupBlock:ShowBlockMessage("Einladung blockiert", name)
                end)
            end
        end
    end)
end

function GroupBlock:HookGroupEvents()
    if self.eventFrame then return end
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("GROUP_JOINED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Login-Cooldown aktivieren - verhindert sofortiges Kicken nach Login
            GroupBlock.loginCooldown = true
            BR:Debug("GroupBlock: Login detected, cooldown active")
            -- Cooldown nach 5 Sekunden aufheben (Zeit für Gildendaten-Laden)
            C_Timer.After(5, function()
                GroupBlock.loginCooldown = false
                BR:Debug("GroupBlock: Login cooldown ended")
            end)
            return
        end
        
        if event == "GUILD_ROSTER_UPDATE" then
            -- Gildendaten wurden geladen - Cache aktualisieren
            if BR.Modules.GuildCheck then
                BR.Modules.GuildCheck.lastUpdate = 0 -- Force refresh
                BR.Modules.GuildCheck:RefreshCache()
            end
            return
        end
        
        if not GroupBlock:ShouldBlock() then return end
        
        if event == "PARTY_INVITE_REQUEST" then
            GroupBlock:OnPartyInvite(...)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "GROUP_JOINED" then
            GroupBlock:CheckGroupMembers()
        end
    end)
    
    self.eventFrame = eventFrame
end

-- Check all group members and leave if non-guild member PLAYER is present
-- NPCs are allowed in the group (e.g. quest NPCs, followers)
function GroupBlock:CheckGroupMembers()
    if not IsInGroup() then return end
    if IsInRaid() then return end -- Don't check raids
    
    -- Nicht prüfen während Login-Cooldown (Gildendaten noch nicht geladen)
    if self.loginCooldown then
        BR:Debug("GroupBlock: Skipping check during login cooldown")
        return
    end
    
    -- Nicht prüfen wenn nicht in Gilde oder Gildendaten nicht verfügbar
    if not BR:IsInGuild() then
        BR:Debug("GroupBlock: Skipping check - not in guild or guild data not loaded")
        return
    end
    
    -- Prüfen ob GuildCheck-Cache gefüllt ist
    if BR.Modules.GuildCheck then
        local cacheSize = 0
        for _ in pairs(BR.Modules.GuildCheck.cache) do
            cacheSize = cacheSize + 1
        end
        if cacheSize == 0 then
            BR:Debug("GroupBlock: Skipping check - guild cache empty")
            return
        end
    end
    
    local numMembers = GetNumGroupMembers()
    if numMembers <= 1 then return end
    
    for i = 1, numMembers do
        local unit = "party" .. i
        if UnitExists(unit) then
            -- Skip NPCs - only check players
            if not UnitIsPlayer(unit) then
                BR:Debug("GroupBlock: Skipping NPC in party: " .. (UnitName(unit) or "unknown"))
            else
                local name = UnitName(unit)
                if name and name ~= UnitName("player") then
                    local fullName = name
                    local realm = GetRealmName()
                    local unitRealm = select(2, UnitName(unit))
                    if unitRealm and unitRealm ~= "" then
                        fullName = name .. "-" .. unitRealm
                    end
                    
                    if not self:IsGuildMember(name) and not self:IsGuildMember(fullName) then
                        -- Non-guild member player found - leave group
                        C_Timer.After(0.5, function()
                            if BR.ShowWarningPopup then
                                BR:ShowWarningPopup("Gruppe verlassen", name .. " ist kein Gildenmitglied!\nGruppe wird automatisch verlassen.", 4)
                            end
                            C_Timer.After(1, function()
                                C_PartyInfo.LeaveParty()
                            end)
                        end)
                        return
                    end
                end
            end
        end
    end
end

function GroupBlock:OnPartyInvite(inviterName, ...)
    if not inviterName then return end
    
    if not self:IsGuildMember(inviterName) then
        -- Decline the invite
        DeclineGroup()
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
        
        GroupBlock:ShowBlockMessage("Einladung abgelehnt", inviterName)
    end
end

function GroupBlock:ShowBlockMessage(title, name)
    local msg = (name or "Unbekannt") .. " ist kein Gildenmitglied!"
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup(title, msg, 3)
    else
        BR:Notify(title .. " - " .. msg, "warning")
    end
end

BR:RegisterModule("GroupBlock", GroupBlock)
