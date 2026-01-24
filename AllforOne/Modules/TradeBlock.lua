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
            -- Methode 1: Prüfe mit UnitIsInMyGuild direkt auf "NPC" Unit
            -- Beim Handeln ist der Handelspartner als "NPC" Unit verfügbar
            local isGuildMember = false
            
            if UnitExists("npc") and UnitIsPlayer("npc") then
                isGuildMember = UnitIsInMyGuild("npc")
                BR:Debug("Trade: UnitIsInMyGuild('npc') = " .. tostring(isGuildMember))
            end
            
            -- Methode 2: Fallback auf Namen-Prüfung
            if not isGuildMember then
                isGuildMember = BR:IsGuildMember(tradeName)
                BR:Debug("Trade: IsGuildMember('" .. tradeName .. "') = " .. tostring(isGuildMember))
            end
            
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
    
    -- Remove realm name for display
    local displayName = strsplit("-", playerName)
    
    -- Prüfe mit UnitIsInMyGuild auf verschiedene Units
    local isGuildMember = false
    
    -- Versuche den Spieler als Unit zu finden
    local unitsToCheck = {"target", "focus", "mouseover", "npc"}
    for i = 1, 4 do
        table.insert(unitsToCheck, "party" .. i)
    end
    
    for _, unit in ipairs(unitsToCheck) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitName = UnitName(unit)
            if unitName and unitName:lower() == displayName:lower() then
                isGuildMember = UnitIsInMyGuild(unit)
                BR:Debug("Trade request: Found " .. displayName .. " as " .. unit .. ", UnitIsInMyGuild = " .. tostring(isGuildMember))
                if isGuildMember then break end
            end
        end
    end
    
    -- Fallback auf Namen-Prüfung
    if not isGuildMember then
        isGuildMember = BR:IsGuildMember(displayName)
        BR:Debug("Trade request from: " .. displayName .. " - Guild (name check): " .. tostring(isGuildMember))
    end
    
    if not isGuildMember then
        CancelTrade()
        if BR.ShowWarningPopup then
            BR:ShowWarningPopup("Handelsanfrage abgelehnt", "Anfrage von " .. displayName .. " abgelehnt.\nKein Gildenmitglied!", 4)
        else
            BR:Notify("Handelsanfrage von " .. displayName .. " abgelehnt - kein Gildenmitglied!", "warning")
        end
    end
end

-- Hook InitiateTrade to prevent player from initiating trades with non-guild members
local originalInitiateTrade = InitiateTrade
function InitiateTrade(unit)
    if TradeBlock:ShouldBlock() then
        -- Prüfe direkt mit UnitIsInMyGuild auf die Unit
        local isGuildMember = false
        local targetName = UnitName(unit) or "Unbekannt"
        
        if UnitExists(unit) and UnitIsPlayer(unit) then
            isGuildMember = UnitIsInMyGuild(unit)
            BR:Debug("InitiateTrade: UnitIsInMyGuild('" .. unit .. "') = " .. tostring(isGuildMember))
        end
        
        -- Fallback auf Namen-Prüfung
        if not isGuildMember then
            local shortName = strsplit("-", targetName)
            isGuildMember = BR:IsGuildMember(shortName)
            BR:Debug("InitiateTrade: IsGuildMember('" .. shortName .. "') = " .. tostring(isGuildMember))
        end
        
        if not isGuildMember then
            if BR.ShowWarningPopup then
                BR:ShowWarningPopup("Handel blockiert", "Handel mit " .. strsplit("-", targetName) .. " nicht erlaubt.\nKein Gildenmitglied!", 4)
            else
                BR:Notify("Handel mit " .. strsplit("-", targetName) .. " nicht möglich - kein Gildenmitglied!", "warning")
            end
            return
        end
    end
    
    return originalInitiateTrade(unit)
end

BR:RegisterModule("TradeBlock", TradeBlock)
