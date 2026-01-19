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

-- Bag Overlay System ---------------------------------------------------------
-- Creates invisible overlays on bag frames to block right-click deposits
-- This is necessary because C_Container.UseContainerItem is a protected function

local bagOverlays = {}

local function CreateBagOverlay(bagFrame)
    if not bagFrame then return nil end
    
    local overlay = CreateFrame("Frame", nil, bagFrame)
    overlay:SetAllPoints(bagFrame)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(bagFrame:GetFrameLevel() + 100)
    overlay:EnableMouse(true)
    overlay:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            NotifyBlocked("deposit_item")
            BR:Debug("WarboundBlock: Blocked right-click on bag via overlay")
        end
    end)
    overlay:Hide()
    
    return overlay
end

local function ShowBagOverlays()
    -- Create overlays for all container frames
    for i = 1, 13 do
        local bagFrame = _G["ContainerFrame" .. i]
        if bagFrame and bagFrame:IsShown() then
            if not bagOverlays[i] then
                bagOverlays[i] = CreateBagOverlay(bagFrame)
            end
            if bagOverlays[i] then
                bagOverlays[i]:Show()
                BR:Debug("WarboundBlock: Showing overlay for ContainerFrame" .. i)
            end
        end
    end
    
    -- Also handle combined bags (Bagnon, AdiBags, etc. typically replace these)
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        if not bagOverlays["combined"] then
            bagOverlays["combined"] = CreateBagOverlay(ContainerFrameCombinedBags)
        end
        if bagOverlays["combined"] then
            bagOverlays["combined"]:Show()
        end
    end
end

local function HideBagOverlays()
    for _, overlay in pairs(bagOverlays) do
        if overlay then
            overlay:Hide()
        end
    end
end

local function UpdateBagOverlays()
    if ShouldBlock() and IsWarboundBankOpen() then
        ShowBagOverlays()
    else
        HideBagOverlays()
    end
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
    
    -- NOTE: C_Container.UseContainerItem and PickupContainerItem are protected functions
    -- and cannot be hooked. Item blocking is handled via UI overlays instead.
    
    -- Hook C_Bank.DepositItem to block direct deposits
    if C_Bank and C_Bank.DepositItem then
        originalFunctions.DepositItem = C_Bank.DepositItem
        C_Bank.DepositItem = function(bankType, ...)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                NotifyBlocked("deposit_item")
                BR:Debug("WarboundBlock: Blocked C_Bank.DepositItem to Account bank")
                ClearCursor()
                return
            end
            return originalFunctions.DepositItem(bankType, ...)
        end
    end
    
    -- Hook ContainerFrameItemButton clicks for Warbound bank slots AND regular bags when Warbound is open
    hooksecurefunc("ContainerFrameItemButton_OnClick", function(self, button)
        if not ShouldBlock() then return end
        
        local bagID = self:GetParent():GetID()
        
        -- Block withdrawing from Warbound bank
        if IsWarboundBankBag(bagID) then
            ClearCursor()
            NotifyBlocked("withdraw_item")
            return
        end
        
        -- Block right-click deposit from regular bags when Warbound bank is open
        if button == "RightButton" and IsWarboundBankOpen() and not IsWarboundBankBag(bagID) then
            -- Check if bagID is a player bag (0-4) or reagent bag (5)
            if bagID >= 0 and bagID <= 5 then
                ClearCursor()
                NotifyBlocked("deposit_item")
                BR:Debug("WarboundBlock: Blocked right-click deposit from bag " .. tostring(bagID))
            end
        end
    end)
    
    -- Hook clicking on AccountBankPanel item slots to block deposits
    if AccountBankPanel then
        hooksecurefunc(AccountBankPanel, "OnMouseUp", function()
            if ShouldBlock() and CursorHasItem() then
                ClearCursor()
                NotifyBlocked("deposit_item")
            end
        end)
    end
    
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

-- Store reference to hidden tabs for restoration
local hiddenWarboundTab = nil
local hiddenBaganatorTabs = {}
local tabHideTicker = nil

-- Baganator SetTab hooks storage
local baganatorHooksInstalled = {}

-- Get all Baganator bank frames
local function GetBaganatorBankFrames()
    local frames = {}
    local suffixes = {"", "dark", "light", "Dark", "Light"}
    local patterns = {
        "Baganator_SingleViewBankViewFrame",
        "Baganator_CategoryViewBankViewFrame",
    }
    
    for _, pattern in ipairs(patterns) do
        for _, suffix in ipairs(suffixes) do
            local frame = _G[pattern .. suffix]
            if frame then
                table.insert(frames, frame)
            end
        end
    end
    
    return frames
end

-- Hook Baganator SetTab to prevent switching to Warband tab
local function HookBaganatorSetTab(frame)
    if not frame or baganatorHooksInstalled[frame] then return end
    
    if frame.SetTab then
        local originalSetTab = frame.SetTab
        frame.SetTab = function(self, index)
            if ShouldBlock() and index == 2 then
                -- Block switching to Warband tab (index 2)
                NotifyBlocked("access")
                BR:Debug("WarboundBlock: Blocked Baganator SetTab(2)")
                -- Force to character tab
                return originalSetTab(self, 1)
            end
            return originalSetTab(self, index)
        end
        baganatorHooksInstalled[frame] = true
        BR:Debug("WarboundBlock: Hooked Baganator SetTab for " .. (frame:GetName() or "unnamed"))
    end
end

-- Hide Baganator Warbound Bank tabs
local function HideBaganatorWarboundTabs()
    if not ShouldBlock() then return end
    
    local frames = GetBaganatorBankFrames()
    
    for _, frame in ipairs(frames) do
        -- Hook SetTab if not already hooked
        HookBaganatorSetTab(frame)
        
        -- Hide the Warband tab (Tabs[2])
        if frame.Tabs and frame.Tabs[2] then
            frame.Tabs[2]:Hide()
            table.insert(hiddenBaganatorTabs, frame.Tabs[2])
            BR:Debug("WarboundBlock: Hidden Baganator Tabs[2]")
        end
        
        -- If currently showing Warband view, force switch to Character
        if frame.currentTab and frame.Warband and frame.currentTab == frame.Warband then
            if frame.SetTab then
                pcall(function() frame:SetTab(1) end)
            end
            if frame.Character then
                frame.Warband:Hide()
                frame.Character:Show()
                frame.currentTab = frame.Character
            end
            BR:Debug("WarboundBlock: Forced Baganator to Character tab")
        end
    end
end

-- Show Baganator tabs again
local function ShowBaganatorWarboundTabs()
    for _, tab in ipairs(hiddenBaganatorTabs) do
        if tab and tab.Show then
            pcall(function() tab:Show() end)
        end
    end
    hiddenBaganatorTabs = {}
end

-- Check if Baganator is showing Warband and close/switch
local function CheckBaganatorWarbandAccess()
    if not ShouldBlock() then return end
    
    local frames = GetBaganatorBankFrames()
    
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            -- Hook if not yet hooked
            HookBaganatorSetTab(frame)
            
            -- Hide Warband tab
            if frame.Tabs and frame.Tabs[2] then
                frame.Tabs[2]:Hide()
            end
            
            -- Check if Warband view is active
            if frame.currentTab and frame.Warband and frame.currentTab == frame.Warband then
                NotifyBlocked("access")
                BR:Debug("WarboundBlock: Detected Baganator Warband view active, switching...")
                
                -- Force to Character tab
                if frame.Character then
                    frame.Warband:Hide()
                    frame.Character:Show()
                    frame.currentTab = frame.Character
                end
                
                -- Also try SetTab
                if frame.SetTab then
                    pcall(function() frame:SetTab(1) end)
                end
            end
        end
    end
end

-- Hide the Warbound Bank tab button
local function HideWarboundBankTab()
    if not ShouldBlock() then return end
    
    -- Hide in Baganator
    HideBaganatorWarboundTabs()
    
    -- Standard BankFrame handling
    if not BankFrame then return end
    
    -- Primary method: BankFrame.TabSystem (from /fstack analysis)
    -- The Warbound bank tab is the second tab (tabID = 2)
    if BankFrame.TabSystem then
        local tabSystem = BankFrame.TabSystem
        
        -- Method 1: Check for tabs array
        if tabSystem.tabs then
            for i, tab in ipairs(tabSystem.tabs) do
                -- Tab 2 is the Warbound/Account bank tab
                if tab and (tab.tabID == 2 or i == 2) then
                    tab:Hide()
                    hiddenWarboundTab = tab
                    BR:Debug("WarboundBlock: Hidden Warbound tab via TabSystem.tabs[" .. i .. "]")
                end
            end
        end
        
        -- Method 2: Iterate TabSystem children directly
        for i = 1, tabSystem:GetNumChildren() do
            local child = select(i, tabSystem:GetChildren())
            if child then
                -- Check if this is the second tab or has tabID 2
                if child.tabID == 2 or child.bankType == BANK_TYPE_ACCOUNT then
                    child:Hide()
                    hiddenWarboundTab = child
                    BR:Debug("WarboundBlock: Hidden Warbound tab via TabSystem child " .. i)
                end
                -- Also check by text/label if available
                if child.Text then
                    local text = child.Text:GetText()
                    if text and (text:find("Kriegsmeute") or text:find("Warbound") or text:find("Account")) then
                        child:Hide()
                        hiddenWarboundTab = child
                        BR:Debug("WarboundBlock: Hidden Warbound tab by text: " .. text)
                    end
                end
            end
        end
        
        -- Method 3: Try GetTabButton if available
        if tabSystem.GetTabButton then
            local tab = tabSystem:GetTabButton(2)
            if tab then
                tab:Hide()
                hiddenWarboundTab = tab
                BR:Debug("WarboundBlock: Hidden Warbound tab via GetTabButton(2)")
            end
        end
    end
    
    -- Fallback: Search BankFrame children for TabSystem
    for i = 1, BankFrame:GetNumChildren() do
        local child = select(i, BankFrame:GetChildren())
        if child then
            local name = child:GetName() or ""
            if name:find("TabSystem") then
                for j = 1, child:GetNumChildren() do
                    local tab = select(j, child:GetChildren())
                    if tab and (tab.tabID == 2 or j == 2) then
                        tab:Hide()
                        hiddenWarboundTab = tab
                        BR:Debug("WarboundBlock: Hidden tab via BankFrame child TabSystem")
                    end
                end
            end
        end
    end
end

-- Show the Warbound Bank tab button (when blocking is disabled)
local function ShowWarboundBankTab()
    -- Restore Baganator tabs
    ShowBaganatorWarboundTabs()
    
    if not BankFrame then return end
    
    -- Restore previously hidden tab
    if hiddenWarboundTab then
        hiddenWarboundTab:Show()
        hiddenWarboundTab = nil
        BR:Debug("WarboundBlock: Restored hidden Warbound tab")
        return
    end
    
    -- Fallback: Try to find and show
    if BankFrame.TabSystem then
        local tabSystem = BankFrame.TabSystem
        
        if tabSystem.tabs then
            for i, tab in ipairs(tabSystem.tabs) do
                if tab and (tab.tabID == 2 or i == 2) then
                    tab:Show()
                end
            end
        end
        
        for i = 1, tabSystem:GetNumChildren() do
            local child = select(i, tabSystem:GetChildren())
            if child and (child.tabID == 2 or child.bankType == BANK_TYPE_ACCOUNT) then
                child:Show()
            end
        end
        
        if tabSystem.GetTabButton then
            local tab = tabSystem:GetTabButton(2)
            if tab then tab:Show() end
        end
    end
end

-- Force switch to normal bank tab (tab 1)
local function ForceNormalBankTab()
    if not ShouldBlock() then return end
    if not BankFrame or not BankFrame:IsShown() then return end
    
    -- Method 1: Use TabSystem to select tab 1
    if BankFrame.TabSystem then
        local tabSystem = BankFrame.TabSystem
        
        -- Try SetTab method
        if tabSystem.SetTab then
            pcall(function() tabSystem:SetTab(1) end)
            BR:Debug("WarboundBlock: Forced tab 1 via SetTab")
        end
        
        -- Try SelectTab method
        if tabSystem.SelectTab then
            pcall(function() tabSystem:SelectTab(1) end)
            BR:Debug("WarboundBlock: Forced tab 1 via SelectTab")
        end
        
        -- Click the first tab if available
        if tabSystem.tabs and tabSystem.tabs[1] then
            pcall(function() tabSystem.tabs[1]:Click() end)
            BR:Debug("WarboundBlock: Clicked tab 1")
        end
        
        -- Try children
        for i = 1, tabSystem:GetNumChildren() do
            local child = select(i, tabSystem:GetChildren())
            if child and (child.tabID == 1 or i == 1) then
                if child.Click then
                    pcall(function() child:Click() end)
                    BR:Debug("WarboundBlock: Clicked TabSystem child 1")
                end
                break
            end
        end
    end
    
    -- Method 2: Use BankFrame.SelectTab if available
    if BankFrame.SelectTab then
        pcall(function() BankFrame:SelectTab(1) end)
    end
    
    -- Method 3: Show BankPanel, hide AccountBankPanel
    if BankFrame.BankPanel then
        BankFrame.BankPanel:Show()
    end
    if AccountBankPanel then
        AccountBankPanel:Hide()
    end
end

-- Close bank if Warbound is somehow open
local function CloseIfWarboundOpen()
    if not ShouldBlock() then return end
    
    if IsWarboundBankOpen() then
        NotifyBlocked("access")
        BR:Debug("WarboundBlock: Warbound bank detected open, closing...")
        
        -- Try to switch to normal bank first
        ForceNormalBankTab()
        
        -- If still open after a short delay, close the bank entirely
        C_Timer.After(0.1, function()
            if IsWarboundBankOpen() then
                CloseBankFrame()
                BR:Print("Die Kriegsmeutenbank ist für dich gesperrt.", "warning")
            end
        end)
    end
end

-- Start periodic ticker to keep Warbound tab hidden
-- This handles third-party addons (Baganator, AdiBags, etc.) that may re-show the tab
local function StartTabHideTicker()
    if tabHideTicker then return end -- Already running
    
    tabHideTicker = C_Timer.NewTicker(0.3, function()
        -- Check if any bank frame is open (standard or Baganator)
        local bankOpen = (BankFrame and BankFrame:IsShown())
        local baganatorFrames = GetBaganatorBankFrames()
        for _, frame in ipairs(baganatorFrames) do
            if frame:IsShown() then
                bankOpen = true
                break
            end
        end
        
        if not bankOpen then
            -- No bank open, stop ticker
            if tabHideTicker then
                tabHideTicker:Cancel()
                tabHideTicker = nil
            end
            return
        end
        
        if ShouldBlock() then
            -- Hide the tab in standard UI
            HideWarboundBankTab()
            -- Check if Warbound is somehow open and close it
            CloseIfWarboundOpen()
            -- Check Baganator specifically
            CheckBaganatorWarbandAccess()
        end
    end)
    BR:Debug("WarboundBlock: Started tab hide ticker")
end

-- Stop the periodic ticker
local function StopTabHideTicker()
    if tabHideTicker then
        tabHideTicker:Cancel()
        tabHideTicker = nil
        BR:Debug("WarboundBlock: Stopped tab hide ticker")
    end
end

-- Block AccountBankPanel interaction buttons
local function BlockWarboundButtons()
    if not ShouldBlock() then return end
    
    -- Hide the Warbound Bank tab first
    HideWarboundBankTab()
    
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
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_OPEN")
eventFrame:RegisterEvent("BAG_CLOSED")

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
                C_Timer.After(0.1, function()
                    BlockWarboundButtons()
                    UpdateBagOverlays()
                end)
            end
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        -- Hide overlays when any bank interaction ends
        HideBagOverlays()
    elseif event == "BANKFRAME_OPENED" then
        if ShouldBlock() then
            -- Hide Warbound tab immediately when bank opens
            HideWarboundBankTab()
            -- Force normal bank tab as default
            ForceNormalBankTab()
            -- Start ticker to keep tab hidden (handles third-party addons)
            StartTabHideTicker()
            C_Timer.After(0.1, function()
                HideWarboundBankTab()
                ForceNormalBankTab()
                -- If Warbound is still open, close it
                CloseIfWarboundOpen()
                if IsWarboundBankOpen() then
                    BlockWarboundButtons()
                    UpdateBagOverlays()
                end
            end)
        end
    elseif event == "BANKFRAME_CLOSED" then
        StopTabHideTicker()
        HideBagOverlays()
        ShowWarboundBankTab()
    elseif event == "BAG_OPEN" or event == "BAG_CLOSED" then
        -- Update overlays when bags open/close
        C_Timer.After(0.05, UpdateBagOverlays)
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
        UpdateBagOverlays()
    else
        HideBagOverlays()
    end
end

BR:RegisterModule("WarboundBlock", WarboundBlock)

-- Install hooks immediately if C_Bank is already available
if C_Bank then
    InstallHooks()
end
