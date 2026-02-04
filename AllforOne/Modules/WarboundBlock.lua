----------------------------------------------------------------------
--  All for One - Warbound Bank Block Module
--  Version 2.1 - Minimalistisch, performant, nur essentielle Features
--  
--  Features:
--  - Gold Ein-/Auszahlung: Erkennung + Gildenchat-Nachricht
--  - Item-Änderungen: Erkennung + Gildenchat-Nachricht  
--  - Währungsüberweisung: Button verstecken + Scham-Nachricht
--  - Warbound Tab verstecken (Standard Blizzard UI)
--  - KEIN Third-Party Addon Support (Performance)
----------------------------------------------------------------------

local addonName, BR = ...

local WarboundBlock = {}
local hooksInstalled = false

-- Constants
local BANK_TYPE_ACCOUNT = Enum and Enum.BankType and Enum.BankType.Account

-- #region Helpers

local function ShouldBlock()
    return BR:GetSetting("Enabled") and BR:GetSetting("BlockWarbound")
end

-- Notification mit Cooldown
local lastNotifyTime = 0
local function NotifyBlocked(action)
    local now = GetTime()
    if now - lastNotifyTime < 2 then return end
    lastNotifyTime = now
    
    local messages = {
        deposit_gold = "Gold in Warbound-Bank eingezahlt!",
        withdraw_gold = "Gold aus Warbound-Bank entnommen!",
        deposit_item = "Item in Warbound-Bank eingelagert!",
        withdraw_item = "Item aus Warbound-Bank entnommen!",
        deposit_all = "Items in Warbound-Bank eingelagert!",
        currency_transfer = "Währung an anderen Charakter überwiesen!",
    }
    
    local msg = messages[action] or "Warbound-Bank Aktion erkannt!"
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Warbound-Bank", msg, 3)
    else
        BR:Notify(msg, "warning")
    end
end

-- #endregion

-- #region Gildenchat Nachrichten
-- HINWEIS: SendChatMessage("CHANNEL") ist seit Patch 8.2.5 protected
-- und erfordert einen Hardware-Event. Daher nur Gildenchat möglich.

local lastShameTime = 0
local SHAME_COOLDOWN = 5

-- Gold in lesbaren Text umwandeln (ohne Texture-Codes)
local function FormatGoldText(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRest = copper % 100
    
    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "g") end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if copperRest > 0 or #parts == 0 then table.insert(parts, copperRest .. "c") end
    
    return table.concat(parts, " ")
end

-- Item-Name extrahieren (ohne Escape-Codes)
local function CleanItemText(itemName, stackCount)
    local name = itemName or "Item"
    if stackCount and stackCount > 1 then
        name = name .. " x" .. stackCount
    end
    return name
end

-- Nachricht senden
local function SendShameMessage(action, details)
    if not BR:GetSetting("EnableShameMessages") then return end
    if not IsInGuild() then return end
    
    local now = GetTime()
    if now - lastShameTime < SHAME_COOLDOWN then return end
    lastShameTime = now
    
    local msg = ""
    if action == "deposit_gold" then
        msg = "Schande über mich! Ich habe " .. FormatGoldText(details) .. " in die Kriegsmeutenbank eingezahlt!"
    elseif action == "withdraw_gold" then
        msg = "Schande über mich! Ich habe " .. FormatGoldText(details) .. " aus der Kriegsmeutenbank entnommen!"
    elseif action == "deposit_item" then
        msg = "Schande über mich! Ich habe " .. (details or "ein Item") .. " in die Kriegsmeutenbank eingelagert!"
    elseif action == "withdraw_item" then
        msg = "Schande über mich! Ich habe " .. (details or "ein Item") .. " aus der Kriegsmeutenbank entnommen!"
    elseif action == "deposit_all" then
        msg = "Schande über mich! Ich habe Items in die Kriegsmeutenbank eingelagert!"
    elseif action == "currency_transfer" then
        msg = "Schande über mich! Ich habe " .. (details or "Währung") .. " an einen anderen Charakter überwiesen!"
    end
    
    if msg == "" then return end
    
    -- C_Timer.After(0) um aus tainted Kontext zu entkommen
    C_Timer.After(0, function()
        if IsInGuild() then
            SendChatMessage(msg, "GUILD")
            BR:Debug("WarboundBlock: " .. msg)
        end
    end)
end

-- #endregion

-- #region Item-Tracking

local accountBankSnapshot = {}
local isTrackingEnabled = false

-- Batch-System für mehrere Items
local pendingAdded = {}
local pendingRemoved = {}
local batchTimer = nil
local BATCH_DELAY = 1.5 -- Sekunden warten bevor Nachricht gesendet wird

-- Forward declaration
local ProcessBatchedItems

-- Snapshot der Account Bank erstellen
local function SnapshotAccountBank()
    accountBankSnapshot = {}
    
    if not Enum or not Enum.BagIndex then return end
    
    local first = Enum.BagIndex.AccountBankTab_1
    local last = Enum.BagIndex.AccountBankTab_5
    if not first or not last then return end
    
    local count = 0
    for tab = first, last do
        local slots = C_Container.GetContainerNumSlots(tab)
        if slots and slots > 0 then
            accountBankSnapshot[tab] = {}
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(tab, slot)
                if info then
                    accountBankSnapshot[tab][slot] = {
                        itemID = info.itemID,
                        stackCount = info.stackCount,
                        itemName = info.itemName or "",
                        hyperlink = info.hyperlink or ""
                    }
                    count = count + 1
                end
            end
        end
    end
    
    isTrackingEnabled = true
    BR:Debug("WarboundBlock: Snapshot erstellt mit " .. count .. " Items")
end

-- Änderungen erkennen
local function DetectChanges()
    BR:Debug("WarboundBlock: DetectChanges() - ShouldBlock=" .. tostring(ShouldBlock()) .. ", isTracking=" .. tostring(isTrackingEnabled))
    
    if not ShouldBlock() then 
        BR:Debug("WarboundBlock: DetectChanges abgebrochen - ShouldBlock=false")
        return 
    end
    
    if not isTrackingEnabled then
        BR:Debug("WarboundBlock: Kein Tracking aktiv, erstelle Snapshot...")
        SnapshotAccountBank()
        return
    end
    
    if not Enum or not Enum.BagIndex then return end
    
    local first = Enum.BagIndex.AccountBankTab_1
    local last = Enum.BagIndex.AccountBankTab_5
    if not first or not last then return end
    
    local added, removed = {}, {}
    
    for tab = first, last do
        local slots = C_Container.GetContainerNumSlots(tab)
        if slots and slots > 0 then
            local oldTab = accountBankSnapshot[tab] or {}
            
            for slot = 1, slots do
                local old = oldTab[slot]
                local new = C_Container.GetContainerItemInfo(tab, slot)
                
                if not old and new then
                    table.insert(added, { 
                        name = new.itemName or "Item", 
                        count = new.stackCount,
                        link = new.hyperlink or ""
                    })
                elseif old and not new then
                    table.insert(removed, { 
                        name = old.itemName or "Item", 
                        count = old.stackCount,
                        link = old.hyperlink or ""
                    })
                elseif old and new and old.itemID == new.itemID then
                    local diff = new.stackCount - old.stackCount
                    if diff > 0 then
                        table.insert(added, { 
                            name = new.itemName or "Item", 
                            count = diff,
                            link = new.hyperlink or ""
                        })
                    elseif diff < 0 then
                        table.insert(removed, { 
                            name = old.itemName or "Item", 
                            count = math.abs(diff),
                            link = old.hyperlink or ""
                        })
                    end
                end
            end
        end
    end
    
    BR:Debug("WarboundBlock: Gefunden: " .. #added .. " hinzugefügt, " .. #removed .. " entfernt")
    
    -- Items zur Batch-Liste hinzufügen
    for _, item in ipairs(added) do
        table.insert(pendingAdded, item)
        BR:Debug("WarboundBlock: Item eingelagert (batch): " .. (item.name or "?"))
    end
    
    for _, item in ipairs(removed) do
        table.insert(pendingRemoved, item)
        BR:Debug("WarboundBlock: Item entnommen (batch): " .. (item.name or "?"))
    end
    
    -- Timer zurücksetzen/starten für Batch-Verarbeitung
    if batchTimer then
        batchTimer:Cancel()
    end
    
    if #pendingAdded > 0 or #pendingRemoved > 0 then
        batchTimer = C_Timer.NewTimer(BATCH_DELAY, ProcessBatchedItems)
    end
    
    -- Snapshot aktualisieren
    SnapshotAccountBank()
end

-- Batch-Verarbeitung: Alle gesammelten Items zusammenfassen
ProcessBatchedItems = function()
    batchTimer = nil
    
    -- Eingelagerte Items verarbeiten
    if #pendingAdded > 0 then
        local itemTexts = {}
        for _, item in ipairs(pendingAdded) do
            local text = item.link ~= "" and item.link or item.name
            if item.count > 1 then
                text = text .. " x" .. item.count
            end
            table.insert(itemTexts, text)
        end
        
        local combinedText = table.concat(itemTexts, ", ")
        SendShameMessage("deposit_item", combinedText)
        NotifyBlocked("deposit_item")
        
        BR:Debug("WarboundBlock: Batch deposit: " .. #pendingAdded .. " Items")
        wipe(pendingAdded)
    end
    
    -- Entnommene Items verarbeiten
    if #pendingRemoved > 0 then
        local itemTexts = {}
        for _, item in ipairs(pendingRemoved) do
            local text = item.link ~= "" and item.link or item.name
            if item.count > 1 then
                text = text .. " x" .. item.count
            end
            table.insert(itemTexts, text)
        end
        
        local combinedText = table.concat(itemTexts, ", ")
        SendShameMessage("withdraw_item", combinedText)
        NotifyBlocked("withdraw_item")
        
        BR:Debug("WarboundBlock: Batch withdraw: " .. #pendingRemoved .. " Items")
        wipe(pendingRemoved)
    end
end

-- #endregion

-- #region Hooks

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    
    -- Gold Einzahlung
    if C_Bank and C_Bank.DepositMoney then
        hooksecurefunc(C_Bank, "DepositMoney", function(bankType, amount)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                SendShameMessage("deposit_gold", amount)
                NotifyBlocked("deposit_gold")
            end
        end)
    end
    
    -- Gold Entnahme
    if C_Bank and C_Bank.WithdrawMoney then
        hooksecurefunc(C_Bank, "WithdrawMoney", function(bankType, amount)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                SendShameMessage("withdraw_gold", amount)
                NotifyBlocked("withdraw_gold")
            end
        end)
    end
    
    -- Auto-Einlagerung
    if C_Bank and C_Bank.AutoDepositItemsIntoBank then
        hooksecurefunc(C_Bank, "AutoDepositItemsIntoBank", function(bankType)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                SendShameMessage("deposit_all", nil)
                NotifyBlocked("deposit_all")
            end
        end)
    end
    
    -- Währungsüberweisung Hook
    -- Signatur: RequestCurrencyFromAccountCharacter(sourceCharacterGUID, currencyID, quantity)
    if C_CurrencyInfo and C_CurrencyInfo.RequestCurrencyFromAccountCharacter then
        hooksecurefunc(C_CurrencyInfo, "RequestCurrencyFromAccountCharacter", function(sourceCharacterGUID, currencyID, quantity)
            if ShouldBlock() then
                -- Währungsname holen
                local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
                local currencyName = currencyInfo and currencyInfo.name or "Währung"
                local text = (quantity or 1) .. "x " .. currencyName
                SendShameMessage("currency_transfer", text)
                NotifyBlocked("currency_transfer")
            end
        end)
    end
    
    BR:Debug("WarboundBlock: Hooks installiert")
end

-- #endregion

-- #region Tab verstecken & Währungsbutton

local hiddenTab = nil
local currencyButtonHooked = false

-- Währungsüberweisungs-Button verstecken
local function HideCurrencyTransferButton()
    if not ShouldBlock() then return end
    
    -- TokenFramePopup.CurrencyTransferToggleButton
    if TokenFramePopup and TokenFramePopup.CurrencyTransferToggleButton then
        TokenFramePopup.CurrencyTransferToggleButton:Hide()
        
        -- Hook um Button versteckt zu halten
        if not currencyButtonHooked then
            currencyButtonHooked = true
            TokenFramePopup.CurrencyTransferToggleButton:HookScript("OnShow", function(self)
                if ShouldBlock() then
                    self:Hide()
                end
            end)
        end
    end
end

local function HideWarboundTab()
    if not ShouldBlock() or not BankFrame or not BankFrame:IsShown() then return end
    
    if BankFrame.TabSystem then
        local tabSystem = BankFrame.TabSystem
        
        -- Methode 1: tabs Array
        if tabSystem.tabs then
            for i, tab in ipairs(tabSystem.tabs) do
                if tab and (tab.tabID == 2 or i == 2) then
                    tab:Hide()
                    hiddenTab = tab
                end
            end
        end
        
        -- Methode 2: Children
        for i = 1, tabSystem:GetNumChildren() do
            local child = select(i, tabSystem:GetChildren())
            if child and (child.tabID == 2 or child.bankType == BANK_TYPE_ACCOUNT) then
                child:Hide()
                hiddenTab = child
            end
        end
    end
end

local function ShowWarboundTab()
    if hiddenTab then
        hiddenTab:Show()
        hiddenTab = nil
    end
end

-- #endregion

-- #region Events

-- Prüft ob eine BagID zur Account Bank gehört
local function IsAccountBankBag(bagID)
    if not bagID or not Enum or not Enum.BagIndex then return false end
    local first = Enum.BagIndex.AccountBankTab_1
    local last = Enum.BagIndex.AccountBankTab_5
    if not first or not last then return false end
    return bagID >= first and bagID <= last
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_AccountBank" or arg1 == addonName then
            InstallHooks()
        end
        -- TokenFrame wird on-demand geladen
        if arg1 == "Blizzard_TokenUI" then
            C_Timer.After(0.1, HideCurrencyTransferButton)
        end
        
    elseif event == "BANKFRAME_OPENED" then
        SnapshotAccountBank()
        if ShouldBlock() then
            HideWarboundTab()
        end
        
    elseif event == "BANKFRAME_CLOSED" then
        isTrackingEnabled = false
        ShowWarboundTab()
        
    elseif event == "BAG_UPDATE" then
        if IsAccountBankBag(arg1) then
            C_Timer.After(0.2, DetectChanges)
        end
        
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Button verstecken wenn Währungsfenster aktualisiert wird
        C_Timer.After(0.1, HideCurrencyTransferButton)
    end
end)

-- #endregion

-- #region Module API

function WarboundBlock:OnInitialize()
    InstallHooks()
    BR:Debug("WarboundBlock: Modul initialisiert")
end

function WarboundBlock:OnEnable()
    BR:Debug("WarboundBlock: Aktiviert = " .. tostring(ShouldBlock()))
end

function WarboundBlock:OnDisable()
    BR:Debug("WarboundBlock: Deaktiviert")
end

function WarboundBlock:Refresh()
    if ShouldBlock() and BankFrame and BankFrame:IsShown() then
        HideWarboundTab()
    else
        ShowWarboundTab()
    end
end

BR:RegisterModule("WarboundBlock", WarboundBlock)

-- Hooks sofort installieren wenn C_Bank verfügbar
if C_Bank then
    InstallHooks()
end

-- #endregion
