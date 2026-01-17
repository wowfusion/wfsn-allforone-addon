----------------------------------------------------------------------
--  All for One - Warbound Bank Block Module
--  Block access to Warbound (Account) Bank - items and gold
----------------------------------------------------------------------

local addonName, BR = ...

local WarboundBlock = {}
local lastNotifyTime = 0
local hooksInstalled = false
local originalFunctions = {}

local PLAYER_INTERACTION = Enum and Enum.PlayerInteractionType
local BANK_TYPE_ACCOUNT = Enum and Enum.BankType and Enum.BankType.Account

-- Helpers --------------------------------------------------------------------
local function ShouldBlock()
    return BR:GetSetting("Enabled") and BR:GetSetting("BlockWarbound")
end

local function NotifyBlocked(action)
    local now = GetTime()
    if now - lastNotifyTime < 2 then
        return
    end
    lastNotifyTime = now
    
    local msg = "Warbound-Bank blockiert!"
    if action == "deposit_gold" then
        msg = "Gold einzahlen in Warbound-Bank blockiert!"
    elseif action == "withdraw_gold" then
        msg = "Gold abheben aus Warbound-Bank blockiert!"
    elseif action == "deposit_item" then
        msg = "Items einlagern in Warbound-Bank blockiert!"
    elseif action == "withdraw_item" then
        msg = "Items entnehmen aus Warbound-Bank blockiert!"
    elseif action == "deposit_all" then
        msg = "Alle Kriegsmeute-Items einlagern blockiert!"
    end
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Warbound-Bank blockiert", msg .. "\nIm Guildfound-Modus nicht erlaubt!", 4)
    else
        BR:Notify(msg, "warning")
    end
end

-- Check if a bag ID is a Warbound bank bag
local function IsWarboundBankBag(bagID)
    if not bagID then return false end
    -- Warbound bank bags are in the range of Enum.BagIndex.AccountBankTab_1 to AccountBankTab_5
    -- These are typically bagID 13-17 (ACCOUNT_BANK_FIRST_TAB to ACCOUNT_BANK_FIRST_TAB + 4)
    if Syndicator and Syndicator.Constants and Syndicator.Constants.AllWarbandIndexes then
        for _, warbandBagID in ipairs(Syndicator.Constants.AllWarbandIndexes) do
            if bagID == warbandBagID then
                return true
            end
        end
    end
    -- Fallback: Check Blizzard constants
    if Enum and Enum.BagIndex then
        local accountBankFirst = Enum.BagIndex.AccountBankTab_1
        local accountBankLast = Enum.BagIndex.AccountBankTab_5
        if accountBankFirst and accountBankLast then
            return bagID >= accountBankFirst and bagID <= accountBankLast
        end
    end
    -- Another fallback using known values (13-17)
    return bagID >= 13 and bagID <= 17
end

-- Check if the bank is currently showing Warbound tab
local function IsWarboundBankOpen()
    if not BankFrame or not BankFrame:IsShown() then
        return false
    end
    -- Check if AccountBankPanel is visible
    if AccountBankPanel and AccountBankPanel:IsShown() then
        return true
    end
    -- Check BankFrame's active tab type
    if BankFrame.activeTabIndex then
        -- Tab index for Warbound is typically 2 or defined in constants
        local warboundTabIndex = 2
        if BankFrame.activeTabIndex == warboundTabIndex then
            return true
        end
    end
    -- Check BankPanel's bankType
    if BankFrame.BankPanel and BankFrame.BankPanel.GetBankType then
        local bankType = BankFrame.BankPanel:GetBankType()
        if bankType == BANK_TYPE_ACCOUNT then
            return true
        end
    end
    return false
end

-- Hook Functions -------------------------------------------------------------

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    
    -- Hook C_Bank.DepositMoney
    if C_Bank and C_Bank.DepositMoney then
        originalFunctions.DepositMoney = C_Bank.DepositMoney
        C_Bank.DepositMoney = function(bankType, amount)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                NotifyBlocked("deposit_gold")
                BR:Debug("WarboundBlock: Blocked gold deposit to Account bank")
                return
            end
            return originalFunctions.DepositMoney(bankType, amount)
        end
    end
    
    -- Hook C_Bank.WithdrawMoney
    if C_Bank and C_Bank.WithdrawMoney then
        originalFunctions.WithdrawMoney = C_Bank.WithdrawMoney
        C_Bank.WithdrawMoney = function(bankType, amount)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                NotifyBlocked("withdraw_gold")
                BR:Debug("WarboundBlock: Blocked gold withdrawal from Account bank")
                return
            end
            return originalFunctions.WithdrawMoney(bankType, amount)
        end
    end
    
    -- Hook C_Container.UseContainerItem to block item transfers
    if C_Container and C_Container.UseContainerItem then
        originalFunctions.UseContainerItem = C_Container.UseContainerItem
        C_Container.UseContainerItem = function(containerIndex, slotIndex, unitToken, reagentBankOpen)
            if ShouldBlock() then
                -- Block if source is Warbound bank (withdrawing)
                if IsWarboundBankBag(containerIndex) then
                    NotifyBlocked("withdraw_item")
                    BR:Debug("WarboundBlock: Blocked item withdrawal from Warbound bank bag " .. tostring(containerIndex))
                    return
                end
                -- Block if Warbound bank is open and we're depositing from bags
                if IsWarboundBankOpen() and not IsWarboundBankBag(containerIndex) then
                    NotifyBlocked("deposit_item")
                    BR:Debug("WarboundBlock: Blocked item deposit to Warbound bank")
                    return
                end
            end
            return originalFunctions.UseContainerItem(containerIndex, slotIndex, unitToken, reagentBankOpen)
        end
    end
    
    -- Hook C_Container.PickupContainerItem
    if C_Container and C_Container.PickupContainerItem then
        originalFunctions.PickupContainerItem = C_Container.PickupContainerItem
        C_Container.PickupContainerItem = function(containerIndex, slotIndex)
            if ShouldBlock() then
                -- Block if picking up from Warbound bank
                if IsWarboundBankBag(containerIndex) then
                    NotifyBlocked("withdraw_item")
                    BR:Debug("WarboundBlock: Blocked pickup from Warbound bank bag " .. tostring(containerIndex))
                    ClearCursor()
                    return
                end
            end
            return originalFunctions.PickupContainerItem(containerIndex, slotIndex)
        end
    end
    
    -- Hook ContainerFrameItemButton clicks for Warbound bank slots
    hooksecurefunc("ContainerFrameItemButton_OnClick", function(self, button)
        if not ShouldBlock() then return end
        
        local bagID = self:GetParent():GetID()
        if IsWarboundBankBag(bagID) then
            ClearCursor()
            NotifyBlocked("withdraw_item")
        end
    end)
    
    -- Hook C_Bank.AutoDepositItemsIntoBank to block "Deposit All Warband Items" button
    if C_Bank and C_Bank.AutoDepositItemsIntoBank then
        originalFunctions.AutoDepositItemsIntoBank = C_Bank.AutoDepositItemsIntoBank
        C_Bank.AutoDepositItemsIntoBank = function(bankType)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                NotifyBlocked("deposit_all")
                BR:Debug("WarboundBlock: Blocked auto-deposit all items to Account bank")
                return
            end
            return originalFunctions.AutoDepositItemsIntoBank(bankType)
        end
    end
    
    BR:Debug("WarboundBlock: All hooks installed")
end

-- Block AccountBankPanel interaction buttons
local function BlockWarboundButtons()
    if not ShouldBlock() then return end
    
    if AccountBankPanel then
        -- Disable deposit/withdraw money buttons
        if AccountBankPanel.DepositButton then
            AccountBankPanel.DepositButton:Disable()
        end
        if AccountBankPanel.WithdrawButton then
            AccountBankPanel.WithdrawButton:Disable()
        end
        
        -- Disable "Deposit All Warband Items" button
        if AccountBankPanel.DepositButton then
            AccountBankPanel.DepositButton:Disable()
        end
        -- Try to find and disable the auto-deposit button (may have different names)
        if AccountBankPanel.AutoDepositButton then
            AccountBankPanel.AutoDepositButton:Disable()
        end
        if AccountBankPanel.DepositAllButton then
            AccountBankPanel.DepositAllButton:Disable()
        end
    end
    
    -- Also block in BankFrame if it has deposit buttons for Account bank
    if BankFrame and BankFrame.AccountBankPanel then
        local panel = BankFrame.AccountBankPanel
        if panel.DepositButton then panel.DepositButton:Disable() end
        if panel.AutoDepositButton then panel.AutoDepositButton:Disable() end
    end
end

-- Events ---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_AccountBank" or arg1 == addonName then
            InstallHooks()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Ensure hooks are installed after login
        InstallHooks()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if PLAYER_INTERACTION then
            -- AccountBankPanel interaction type
            local accountBankType = PLAYER_INTERACTION.AccountBankPanel
            if arg1 == accountBankType and ShouldBlock() then
                C_Timer.After(0.1, BlockWarboundButtons)
            end
        end
    elseif event == "BANKFRAME_OPENED" then
        if ShouldBlock() then
            C_Timer.After(0.1, function()
                if IsWarboundBankOpen() then
                    BlockWarboundButtons()
                end
            end)
        end
    end
end)

-- Module API -----------------------------------------------------------------
function WarboundBlock:OnInitialize()
    InstallHooks()
    BR:Debug("WarboundBlock module initialized")
end

function WarboundBlock:OnEnable()
    BR:Debug("WarboundBlock enabled: " .. tostring(ShouldBlock()))
end

function WarboundBlock:OnDisable()
    BR:Debug("WarboundBlock disabled")
end

function WarboundBlock:Refresh()
    -- Refresh state when settings change
    if ShouldBlock() and IsWarboundBankOpen() then
        BlockWarboundButtons()
    end
end

BR:RegisterModule("WarboundBlock", WarboundBlock)

-- Install hooks immediately if C_Bank is already available
if C_Bank then
    InstallHooks()
end
