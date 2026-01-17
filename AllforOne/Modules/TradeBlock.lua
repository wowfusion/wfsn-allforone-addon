----------------------------------------------------------------------
--  All for One - Trade Block Module
--  Only allow trading with guild members
----------------------------------------------------------------------

local addonName, BR = ...

local TradeBlock = {
    enabled = false,
    eventsHooked = false,
}

function TradeBlock:OnInitialize()
    -- Always hook events on initialize so they're ready
    self:HookTradeEvents()
    BR:Debug("TradeBlock module initialized")
end

function TradeBlock:OnEnable()
    self.enabled = BR:GetSetting("BlockTrade")
    BR:Debug("TradeBlock enabled: " .. tostring(self.enabled))
end

function TradeBlock:OnDisable()
    self.enabled = false
    BR:Debug("TradeBlock disabled")
end

function TradeBlock:Refresh()
    self.enabled = BR:GetSetting("Enabled") and BR:GetSetting("BlockTrade")
end

function TradeBlock:ShouldBlock()
    return BR:GetSetting("Enabled") and BR:GetSetting("BlockTrade")
end

function TradeBlock:HookTradeEvents()
    if self.eventsHooked then return end
    self.eventsHooked = true
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRADE_SHOW")
    eventFrame:RegisterEvent("TRADE_REQUEST")
    eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if not TradeBlock:ShouldBlock() then return end
        
        if event == "TRADE_SHOW" then
            TradeBlock:OnTradeShow()
        elseif event == "TRADE_REQUEST" then
            TradeBlock:OnTradeRequest(...)
        elseif event == "TRADE_ACCEPT_UPDATE" then
            TradeBlock:OnTradeShow()
        end
    end)
    
    self.eventFrame = eventFrame
end

function TradeBlock:GetTradeName()
    -- Try multiple methods to get trade partner name
    local tradeName = nil
    
    -- Method 1: TradeFrame text
    if TradeFrameRecipientNameText then
        tradeName = TradeFrameRecipientNameText:GetText()
    end
    
    -- Method 2: GetUnitName for NPC (trade target)
    if not tradeName or tradeName == "" then
        tradeName = GetUnitName("NPC", true)
    end
    
    -- Method 3: UnitName for NPC
    if not tradeName or tradeName == "" then
        tradeName = UnitName("NPC")
    end
    
    -- Remove realm name if present
    if tradeName then
        tradeName = strsplit("-", tradeName)
    end
    
    return tradeName
end

function TradeBlock:OnTradeShow()
    -- Small delay to ensure trade frame is fully loaded
    C_Timer.After(0.1, function()
        if not TradeBlock:ShouldBlock() then return end
        
        local tradeName = TradeBlock:GetTradeName()
        BR:Debug("Trade opened with: " .. tostring(tradeName))
        
        if tradeName and tradeName ~= "" then
            local isGuildMember = BR:IsGuildMember(tradeName)
            BR:Debug("Is guild member: " .. tostring(isGuildMember))
            
            if not isGuildMember then
                -- Close trade immediately
                CloseTrade()
                CancelTrade()
                
                if BR.ShowWarningPopup then
                    BR:ShowWarningPopup("Handel blockiert", "Handel mit " .. tradeName .. " nicht erlaubt.\nKein Gildenmitglied!", 4)
                else
                    BR:Notify("Handel mit " .. tradeName .. " blockiert - kein Gildenmitglied!", "warning")
                end
            end
        end
    end)
end

function TradeBlock:OnTradeRequest(playerName)
    if not playerName then return end
    
    -- Remove realm name
    playerName = strsplit("-", playerName)
    
    local isGuildMember = BR:IsGuildMember(playerName)
    BR:Debug("Trade request from: " .. playerName .. " - Guild: " .. tostring(isGuildMember))
    
    if not isGuildMember then
        CancelTrade()
        if BR.ShowWarningPopup then
            BR:ShowWarningPopup("Handelsanfrage abgelehnt", "Anfrage von " .. playerName .. " abgelehnt.\nKein Gildenmitglied!", 4)
        else
            BR:Notify("Handelsanfrage von " .. playerName .. " abgelehnt - kein Gildenmitglied!", "warning")
        end
    end
end

-- Hook InitiateTrade to prevent player from initiating trades with non-guild members
local originalInitiateTrade = InitiateTrade
function InitiateTrade(unit)
    if TradeBlock:ShouldBlock() then
        local targetName = UnitName(unit)
        if targetName then
            targetName = strsplit("-", targetName)
            local isGuildMember = BR:IsGuildMember(targetName)
            
            if not isGuildMember then
                if BR.ShowWarningPopup then
                    BR:ShowWarningPopup("Handel blockiert", "Handel mit " .. targetName .. " nicht erlaubt.\nKein Gildenmitglied!", 4)
                else
                    BR:Notify("Handel mit " .. targetName .. " nicht möglich - kein Gildenmitglied!", "warning")
                end
                return
            end
        end
    end
    
    return originalInitiateTrade(unit)
end

BR:RegisterModule("TradeBlock", TradeBlock)
