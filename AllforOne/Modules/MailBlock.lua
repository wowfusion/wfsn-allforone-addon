----------------------------------------------------------------------
--  All for One - Mail Block Module
--  Block mail from non-guild members or block mailbox entirely
----------------------------------------------------------------------

local addonName, BR = ...

local MailBlock = {
    enabled = false,
    hooked = false,
    lastBlockedMail = nil,
}

-- Block modes:
-- "full" = Block mailbox entirely (old behavior)
-- "selective" = Only block mail from non-guild members (new default)

-- Whitelist for system senders that should always be allowed
local SENDER_WHITELIST = {
    -- German
    ["postmeister"] = true,
    ["handwerkerkonsortium"] = true,
    -- English
    ["postmaster"] = true,
    ["artisan's consortium"] = true,
    ["artisans consortium"] = true, -- safety net if apostrophes get stripped
    -- System
    -- ["system"] = true,
    -- ["blizzard"] = true,
}

-- NPC Name Whitelist (NPCs that send quest rewards via mail)
-- These are populated from BR.MailRewardNPCs database
local NPC_NAME_WHITELIST = {}

function MailBlock:OnInitialize()
    BR:Debug("MailBlock module initialized")
    self:BuildNPCWhitelist()
    self:SetupHooks()
end

-- Build NPC name whitelist from MailRewardNPCs database
function MailBlock:BuildNPCWhitelist()
    if BR.MailRewardNPCs then
        for npcID, data in pairs(BR.MailRewardNPCs) do
            -- Add all localized names from the "names" array
            if data.names then
                for _, name in ipairs(data.names) do
                    NPC_NAME_WHITELIST[name:lower()] = true
                    BR:Debug("MailBlock: Added NPC name to whitelist: " .. name)
                end
            end
            -- Also add the primary name as fallback
            if data.name then
                NPC_NAME_WHITELIST[data.name:lower()] = true
            end
        end
    end
end

function MailBlock:OnEnable()
    if not BR:GetSetting("BlockMail") then return end
    
    self.enabled = true
    BR:Debug("MailBlock enabled")
end

function MailBlock:OnDisable()
    self.enabled = false
    BR:Debug("MailBlock disabled")
end

function MailBlock:Refresh()
    if BR:GetSetting("Enabled") and BR:GetSetting("BlockMail") then
        self.enabled = true
    else
        self.enabled = false
    end
end

function MailBlock:ShouldBlock()
    return self.enabled and BR:GetSetting("Enabled") and BR:GetSetting("BlockMail")
end

function MailBlock:GetBlockMode()
    -- Return "full" or "selective" based on setting
    local mode = BR:GetSetting("MailBlockMode")
    if mode == nil then mode = "selective" end -- Default to selective
    return mode
end

function MailBlock:IsWhitelistedSender(senderName)
    if not senderName then return false end
    local senderLower = senderName:lower()
    
    -- Check exact match in system whitelist
    if SENDER_WHITELIST[senderLower] then
        return true
    end
    
    -- Check exact match in NPC whitelist (Mail Reward NPCs)
    if NPC_NAME_WHITELIST[senderLower] then
        BR:Debug("MailBlock: Sender " .. senderName .. " is whitelisted NPC")
        return true
    end
    
    -- Check partial match (for localized names)
    for pattern, _ in pairs(SENDER_WHITELIST) do
        if senderLower:find(pattern, 1, true) then
            return true
        end
    end
    
    -- Check partial match for NPCs (in case of realm suffix)
    for pattern, _ in pairs(NPC_NAME_WHITELIST) do
        if senderLower:find(pattern, 1, true) then
            BR:Debug("MailBlock: Sender " .. senderName .. " matches whitelisted NPC pattern: " .. pattern)
            return true
        end
    end
    
    return false
end

function MailBlock:IsGuildMember(senderName)
    if not senderName or senderName == "" then return false end
    
    -- Use the GuildCheck module if available
    if BR.Modules.GuildCheck and BR.Modules.GuildCheck.IsGuildMember then
        return BR.Modules.GuildCheck:IsGuildMember(senderName)
    end
    
    -- Fallback: check guild roster manually
    local numMembers = GetNumGuildMembers()
    local senderLower = senderName:lower()
    local shortSender = strsplit("-", senderLower)
    
    for i = 1, numMembers do
        local fullName = GetGuildRosterInfo(i)
        if fullName then
            local shortName = strsplit("-", fullName)
            if shortName:lower() == shortSender or fullName:lower() == senderLower then
                return true
            end
        end
    end
    
    return false
end

function MailBlock:IsSenderAllowed(senderName)
    -- Check whitelist first
    if self:IsWhitelistedSender(senderName) then
        return true
    end
    -- Then check guild membership
    return self:IsGuildMember(senderName)
end

function MailBlock:SetupHooks()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "MAIL_SHOW" then
            -- Hook the frame if not yet hooked
            if not MailBlock.hooked and MailFrame then
                MailBlock:HookMailFrame()
            end
            
            -- Full block mode: close mailbox entirely
            if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "full" then
                CloseMail()
                if MailFrame then
                    MailFrame:Hide()
                end
                MailBlock:ShowBlockMessage("full")
            end
        elseif event == "MAIL_INBOX_UPDATE" then
            -- Update mail item hooks for selective blocking
            if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                MailBlock:HookMailItems()
            end
        end
    end)
    
    self.eventFrame = eventFrame
    
    -- Hook SendMail to block sending to non-guild members
    self:HookSendMail()
end

function MailBlock:HookSendMail()
    if self.sendMailHooked then return end
    self.sendMailHooked = true
    
    -- Hook SendMail function
    if SendMail then
        local originalSendMail = SendMail
        _G.SendMail = function(recipient, subject, body, ...)
            if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                if recipient and not MailBlock:IsSenderAllowed(recipient) then
                    MailBlock:ShowBlockMessage("send", recipient)
                    return
                end
            end
            return originalSendMail(recipient, subject, body, ...)
        end
        BR:Debug("SendMail hooked")
    end
end

function MailBlock:HookMailFrame()
    if self.hooked then return end
    if not MailFrame then return end
    
    self.hooked = true
    
    -- Hook OnShow for full block mode
    MailFrame:HookScript("OnShow", function(frame)
        if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "full" then
            frame:Hide()
            CloseMail()
            MailBlock:ShowBlockMessage("full")
        elseif MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
            -- Hook mail items for selective blocking
            C_Timer.After(0.1, function()
                MailBlock:HookMailItems()
            end)
        end
    end)
    
    BR:Debug("MailFrame hooked")
end

function MailBlock:HookMailItems()
    if not MailFrame or not MailFrame:IsShown() then return end
    if not self:ShouldBlock() then return end
    if self:GetBlockMode() ~= "selective" then return end
    
    -- Hook each mail item button to block opening non-allowed mail
    for i = 1, INBOXITEMS_TO_DISPLAY or 7 do
        local button = _G["MailItem" .. i .. "Button"]
        if button and not button.brHooked then
            button.brHooked = true
            button:HookScript("OnClick", function(self, mouseButton)
                local index = self.index
                if index then
                    local _, _, sender = GetInboxHeaderInfo(index)
                    if sender and not MailBlock:IsSenderAllowed(sender) then
                        MailBlock.lastBlockedMail = sender
                        MailBlock:ShowBlockMessage("selective", sender)
                        -- Close the OpenMailFrame immediately
                        C_Timer.After(0.01, function()
                            if OpenMailFrame and OpenMailFrame:IsShown() then
                                OpenMailFrame:Hide()
                            end
                        end)
                    end
                end
            end)
        end
    end
    
    -- Hook OpenMailFrame to close if blocked sender
    if OpenMailFrame and not self.openMailHooked then
        self.openMailHooked = true
        OpenMailFrame:HookScript("OnShow", function()
            if not MailBlock:ShouldBlock() then return end
            if MailBlock:GetBlockMode() ~= "selective" then return end
            
            local index = InboxFrame.openMailID
            if index then
                local _, _, sender = GetInboxHeaderInfo(index)
                if sender and not MailBlock:IsSenderAllowed(sender) then
                    MailBlock:ShowBlockMessage("selective", sender)
                    OpenMailFrame:Hide()
                end
            end
        end)
    end
    
    -- Hook the actual mail taking functions (NOT GetInboxText - that breaks UI)
    if not self.functionsHooked then
        self.functionsHooked = true
        
        -- Hook TakeInboxMoney
        if TakeInboxMoney then
            local originalTakeInboxMoney = TakeInboxMoney
            _G.TakeInboxMoney = function(index, ...)
                if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                    local _, _, sender = GetInboxHeaderInfo(index)
                    if sender and not MailBlock:IsSenderAllowed(sender) then
                        MailBlock:ShowBlockMessage("selective", sender)
                        return
                    end
                end
                return originalTakeInboxMoney(index, ...)
            end
        end
        
        -- Hook TakeInboxItem
        if TakeInboxItem then
            local originalTakeInboxItem = TakeInboxItem
            _G.TakeInboxItem = function(index, itemIndex, ...)
                if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                    local _, _, sender = GetInboxHeaderInfo(index)
                    if sender and not MailBlock:IsSenderAllowed(sender) then
                        MailBlock:ShowBlockMessage("selective", sender)
                        return
                    end
                end
                return originalTakeInboxItem(index, itemIndex, ...)
            end
        end
        
        -- Hook AutoLootMailItem
        if AutoLootMailItem then
            local originalAutoLootMailItem = AutoLootMailItem
            _G.AutoLootMailItem = function(index, ...)
                if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                    local _, _, sender = GetInboxHeaderInfo(index)
                    if sender and not MailBlock:IsSenderAllowed(sender) then
                        MailBlock:ShowBlockMessage("selective", sender)
                        return
                    end
                end
                return originalAutoLootMailItem(index, ...)
            end
        end
        
        -- Hook DeleteInboxItem
        if DeleteInboxItem then
            local originalDeleteInboxItem = DeleteInboxItem
            _G.DeleteInboxItem = function(index, ...)
                if MailBlock:ShouldBlock() and MailBlock:GetBlockMode() == "selective" then
                    local _, _, sender = GetInboxHeaderInfo(index)
                    if sender and not MailBlock:IsSenderAllowed(sender) then
                        MailBlock:ShowBlockMessage("selective", sender)
                        return
                    end
                end
                return originalDeleteInboxItem(index, ...)
            end
        end
        
        BR:Debug("Mail functions hooked for selective blocking")
    end
end

function MailBlock:ShowBlockMessage(mode, sender)
    local now = GetTime()
    if self.lastMessageTime and (now - self.lastMessageTime) < 2 then return end
    self.lastMessageTime = now
    
    local title, msg
    if mode == "full" then
        title = "Briefkasten blockiert"
        msg = "Die Briefkasten-Nutzung ist im Guildfound-Modus vollständig gesperrt."
    elseif mode == "send" then
        title = "Versand blockiert"
        msg = "Post-Versand an Nicht-Gildenmitglieder ist nicht erlaubt."
        if sender then
            msg = msg .. "\n\nEmpfänger: " .. sender
        end
    else
        title = "Post blockiert"
        msg = "Annahme von Post von Nicht-Gildenmitgliedern ist nicht erlaubt."
        if sender then
            msg = msg .. "\n\nAbsender: " .. sender
        end
    end
    
    -- Use Popup if available, fallback to Notify
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup(title, msg, 4)
    else
        BR:Notify(title .. "\n" .. msg, "warning")
    end
end

BR:RegisterModule("MailBlock", MailBlock)
