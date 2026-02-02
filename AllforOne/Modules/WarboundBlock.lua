----------------------------------------------------------------------
--  All for One - Warbound Bank Block Module
--  Block access to Warbound (Account) Bank - items and gold
----------------------------------------------------------------------

local addonName, BR = ...

local WarboundBlock = {}
local lastNotifyTime = 0
local hooksInstalled = false
local originalFunctions = {}

-- Forward declarations für Funktionen die später definiert werden
local CheckBagnonWarbandAccess

local PLAYER_INTERACTION = Enum and Enum.PlayerInteractionType
local BANK_TYPE_ACCOUNT = Enum and Enum.BankType and Enum.BankType.Account

-- Warband Bank Distance Inhibitor Item ID and Spell ID
local WARBAND_DISTANCE_INHIBITOR_ID = 216665
local WARBAND_DISTANCE_INHIBITOR_SPELL_ID = 460905

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
    elseif action == "remote_access" then
        msg = "Fernzugriff auf Kriegsmeutenbank blockiert!"
    elseif action == "access" then
        msg = "Zugriff auf Kriegsmeutenbank blockiert!"
    elseif action == "currency_transfer" then
        msg = "Währungsüberweisung zwischen Charakteren blockiert!"
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
-- NOTE: We use pcall to avoid any potential taint from reading BankFrame properties
local function IsWarboundBankOpen()
    -- Only check AccountBankPanel visibility - this is safe and doesn't cause taint
    if AccountBankPanel and AccountBankPanel:IsShown() then
        return true
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
-- IMPORTANT: We do NOT hook C_Bank functions directly because they are PROTECTED.
-- Hooking protected functions causes "taint" which blocks ALL protected UI actions
-- (using items, buying bank slots, learning mounts, etc.)
-- Instead, we use UI-based blocking: hiding tabs, buttons, and using hooksecurefunc

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    
    -- NOTE: C_Bank.DepositMoney, C_Bank.WithdrawMoney, C_Bank.DepositItem, 
    -- C_Bank.AutoDepositItemsIntoBank are ALL protected functions.
    -- We CANNOT hook them without causing taint.
    -- Instead, we hide the Warbound bank tab completely so users can't access it.
    
    -- Use hooksecurefunc for safe post-hooks (these don't cause taint)
    -- They run AFTER the original function, so they can't block, but can warn
    
    if C_Bank and C_Bank.DepositMoney then
        hooksecurefunc(C_Bank, "DepositMoney", function(bankType, amount)
            if ShouldBlock() and bankType == BANK_TYPE_ACCOUNT then
                BR:Debug("WarboundBlock: Warning - gold deposited to Account bank")
            end
        end)
    end
    
    -- Hook clicking on AccountBankPanel item slots to clear cursor (safe)
    if AccountBankPanel then
        hooksecurefunc(AccountBankPanel, "OnMouseUp", function()
            if ShouldBlock() and CursorHasItem() then
                C_Timer.After(0, function()
                    ClearCursor()
                    NotifyBlocked("deposit_item")
                end)
            end
        end)
    end
    
    BR:Debug("WarboundBlock: Safe hooks installed (no protected function overrides)")
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

-- Hook Baganator Warband View Mixin
local baganatorMixinHooked = false
local function HookBaganatorWarbandMixin()
    if baganatorMixinHooked then return end
    
    -- Hook das globale Mixin wenn es existiert
    if BaganatorItemViewCommonBankViewWarbandViewMixin then
        baganatorMixinHooked = true
        BR:Debug("WarboundBlock: Found BaganatorItemViewCommonBankViewWarbandViewMixin")
        
        -- Hook OnShow um Warband-Zugriff zu blockieren
        local originalOnShow = BaganatorItemViewCommonBankViewWarbandViewMixin.OnShow
        if originalOnShow then
            BaganatorItemViewCommonBankViewWarbandViewMixin.OnShow = function(self, ...)
                if ShouldBlock() then
                    NotifyBlocked("access")
                    BR:Debug("WarboundBlock: Blocked Baganator Warband OnShow")
                    -- Verstecke die View
                    self:Hide()
                    -- Versuche zur Character Bank zu wechseln
                    if self:GetParent() and self:GetParent().SetTab then
                        pcall(function() self:GetParent():SetTab(1) end)
                    end
                    return
                end
                return originalOnShow(self, ...)
            end
            BR:Debug("WarboundBlock: Hooked Baganator OnShow")
        end
        
        -- Hook ShowTab
        local originalShowTab = BaganatorItemViewCommonBankViewWarbandViewMixin.ShowTab
        if originalShowTab then
            BaganatorItemViewCommonBankViewWarbandViewMixin.ShowTab = function(self, tabIndex, isLive, ...)
                if ShouldBlock() then
                    NotifyBlocked("access")
                    BR:Debug("WarboundBlock: Blocked Baganator ShowTab")
                    self:Hide()
                    return
                end
                return originalShowTab(self, tabIndex, isLive, ...)
            end
            BR:Debug("WarboundBlock: Hooked Baganator ShowTab")
        end
        
        -- Hook UpdateView
        local originalUpdateView = BaganatorItemViewCommonBankViewWarbandViewMixin.UpdateView
        if originalUpdateView then
            BaganatorItemViewCommonBankViewWarbandViewMixin.UpdateView = function(self, ...)
                if ShouldBlock() then
                    self:Hide()
                    return
                end
                return originalUpdateView(self, ...)
            end
            BR:Debug("WarboundBlock: Hooked Baganator UpdateView")
        end
        
        -- Hook UpdateTabs um Warband-Tabs zu verstecken
        local originalUpdateTabs = BaganatorItemViewCommonBankViewWarbandViewMixin.UpdateTabs
        if originalUpdateTabs then
            BaganatorItemViewCommonBankViewWarbandViewMixin.UpdateTabs = function(self, ...)
                local result = originalUpdateTabs(self, ...)
                -- Verstecke alle Tabs wenn blockiert
                if ShouldBlock() and self.Tabs then
                    for _, tab in ipairs(self.Tabs) do
                        tab:Hide()
                    end
                    BR:Debug("WarboundBlock: Hidden all Baganator Warband tabs")
                end
                return result
            end
            BR:Debug("WarboundBlock: Hooked Baganator UpdateTabs")
        end
    end
    
    -- Hook auch die SingleView und CategoryView Mixins
    if BaganatorSingleViewBankViewWarbandViewMixin then
        local originalOnShow = BaganatorSingleViewBankViewWarbandViewMixin.OnShow
        if originalOnShow and not BaganatorSingleViewBankViewWarbandViewMixin._brHooked then
            BaganatorSingleViewBankViewWarbandViewMixin._brHooked = true
            BaganatorSingleViewBankViewWarbandViewMixin.OnShow = function(self, ...)
                if ShouldBlock() then
                    NotifyBlocked("access")
                    self:Hide()
                    return
                end
                return originalOnShow(self, ...)
            end
            BR:Debug("WarboundBlock: Hooked BaganatorSingleViewBankViewWarbandViewMixin")
        end
    end
    
    if BaganatorCategoryViewBankViewWarbandViewMixin then
        local originalOnShow = BaganatorCategoryViewBankViewWarbandViewMixin.OnShow
        if originalOnShow and not BaganatorCategoryViewBankViewWarbandViewMixin._brHooked then
            BaganatorCategoryViewBankViewWarbandViewMixin._brHooked = true
            BaganatorCategoryViewBankViewWarbandViewMixin.OnShow = function(self, ...)
                if ShouldBlock() then
                    NotifyBlocked("access")
                    self:Hide()
                    return
                end
                return originalOnShow(self, ...)
            end
            BR:Debug("WarboundBlock: Hooked BaganatorCategoryViewBankViewWarbandViewMixin")
        end
    end
end

-- Rekursive Funktion um alle Frames mit bestimmtem Text zu finden und zu verstecken
local function HideFramesWithText(frame, searchTexts, depth)
    if not frame or depth > 10 then return end
    depth = depth or 0
    
    -- Prüfe ob dieses Frame Text hat
    if frame.GetText then
        local text = frame:GetText()
        if text then
            for _, searchText in ipairs(searchTexts) do
                if text:find(searchText) then
                    frame:Hide()
                    BR:Debug("WarboundBlock: Hidden frame with text: " .. text)
                    return true
                end
            end
        end
    end
    
    -- Prüfe FontStrings
    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.GetText then
                local text = region:GetText()
                if text then
                    for _, searchText in ipairs(searchTexts) do
                        if text:find(searchText) then
                            frame:Hide()
                            BR:Debug("WarboundBlock: Hidden frame (via region): " .. text)
                            return true
                        end
                    end
                end
            end
        end
    end
    
    -- Rekursiv durch Kinder
    if frame.GetChildren then
        for i = 1, select("#", frame:GetChildren()) do
            local child = select(i, frame:GetChildren())
            if child then
                HideFramesWithText(child, searchTexts, depth + 1)
            end
        end
    end
    
    return false
end

-- Verstecke Baganator und Bagnon Warband Tab-Buttons
local function HideThirdPartyWarbandTabs()
    if not ShouldBlock() then return end
    
    local searchTexts = {"Kriegsmeute", "Warband", "Account Bank"}
    
    -- Suche in allen sichtbaren Frames nach Warband-Tabs
    local framesToCheck = {}
    
    -- Baganator und Bagnon Frames
    for frameName, frame in pairs(_G) do
        if type(frameName) == "string" and type(frame) == "table" then
            if frameName:find("Baganator") or frameName:find("Bagnon") then
                if frame.IsShown and pcall(function() return frame:IsShown() end) and frame:IsShown() then
                    table.insert(framesToCheck, frame)
                end
            end
        end
    end
    
    -- Durchsuche alle gefundenen Frames
    for _, frame in ipairs(framesToCheck) do
        HideFramesWithText(frame, searchTexts, 0)
    end
    
    -- Spezifische Baganator Tab-Suche und Tab-Wechsel
    local baganatorFrames = GetBaganatorBankFrames()
    for _, frame in ipairs(baganatorFrames) do
        if frame:IsShown() then
            -- Suche nach TabSystem
            if frame.Tabs then
                -- Tab 2 ist typischerweise der Warband-Tab (Tab 1 ist "Alles", Tab 2+ sind die einzelnen Tabs)
                -- Verstecke alle Tabs außer dem ersten (Charakter)
                for i, tab in ipairs(frame.Tabs) do
                    if i > 1 then
                        tab:Hide()
                        BR:Debug("WarboundBlock: Hidden Baganator Tab " .. i)
                    end
                end
            end
            
            -- Wenn die Warband-View aktiv ist, wechsle zur Charakter-View
            -- Baganator Bank hat typischerweise Character und Warband als Kinder
            if frame.Warband and frame.Warband:IsShown() then
                frame.Warband:Hide()
                if frame.Character then
                    frame.Character:Show()
                end
                -- Versuche SetTab aufzurufen
                if frame.SetTab then
                    pcall(function() frame:SetTab(1) end)
                end
                NotifyBlocked("access")
                BR:Debug("WarboundBlock: Switched Baganator from Warband to Character")
            end
            
            -- Suche nach Buttons mit Kriegsmeute Text
            for i = 1, frame:GetNumChildren() do
                local child = select(i, frame:GetChildren())
                if child and child:IsShown() then
                    HideFramesWithText(child, searchTexts, 0)
                end
            end
        end
    end
    
    -- Bagnon spezifische Suche
    if Bagnon then
        local bankFrame = _G["BagnonFramebank"] or (Bagnon.frames and Bagnon.frames.bank)
        if bankFrame and bankFrame:IsShown() then
            HideFramesWithText(bankFrame, searchTexts, 0)
            -- Erzwinge normale Bank
            if _G["Addon_SetBankType"] then
                pcall(function() _G["Addon_SetBankType"](0) end)
            end
            
            -- Suche nach TabGroup/Sidebar in Bagnon
            if bankFrame.TabGroup then
                for i = 1, bankFrame.TabGroup:GetNumChildren() do
                    local child = select(i, bankFrame.TabGroup:GetChildren())
                    if child then
                        HideFramesWithText(child, searchTexts, 0)
                    end
                end
            end
        end
    end
    
    -- Suche nach allen Bagnon Frames mit "Kriegsmeute" Text
    for frameName, frame in pairs(_G) do
        if type(frameName) == "string" and frameName:find("Bagnon") and type(frame) == "table" then
            if frame.IsShown and pcall(function() return frame:IsShown() end) and frame:IsShown() then
                -- Suche nach Kindern mit Kriegsmeute Text
                if frame.GetChildren then
                    for i = 1, select("#", frame:GetChildren()) do
                        local child = select(i, frame:GetChildren())
                        if child then
                            -- Prüfe ob es ein Tab/Button mit Kriegsmeute ist
                            if child.GetText then
                                local text = child:GetText()
                                if text and text:find("Kriegsmeute") then
                                    child:Hide()
                                    BR:Debug("WarboundBlock: Hidden Bagnon child with text: " .. text)
                                end
                            end
                            -- Prüfe auch Regionen (FontStrings)
                            if child.GetRegions then
                                for j = 1, select("#", child:GetRegions()) do
                                    local region = select(j, child:GetRegions())
                                    if region and region.GetText then
                                        local text = region:GetText()
                                        if text and text:find("Kriegsmeute") then
                                            child:Hide()
                                            BR:Debug("WarboundBlock: Hidden Bagnon frame via region: " .. text)
                                        end
                                    end
                                end
                            end
                            -- Rekursiv durch Kinder
                            HideFramesWithText(child, searchTexts, 0)
                        end
                    end
                end
            end
        end
    end
end

-- Hook Baganator SetTab to prevent switching to Warband tab
local function HookBaganatorSetTab(frame)
    if not frame or baganatorHooksInstalled[frame] then return end
    
    -- Versuche zuerst das Mixin zu hooken
    HookBaganatorWarbandMixin()
    
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

-- Overlay frame to cover the Warbound tab button (makes it unclickable and invisible)
local warboundTabOverlay = nil
-- Store reference to hidden tab for alpha restoration
local hiddenAlphaTab = nil

-- Hide the Warbound Bank tab button
-- We use an overlay with SetAlpha(0) approach to avoid taint from Hide()
-- The overlay covers the tab and blocks clicks while making it appear hidden
local function HideWarboundBankTab()
    if not ShouldBlock() then return end
    
    -- Hide in Baganator (third-party addon, safe to manipulate directly)
    HideBaganatorWarboundTabs()
    
    -- Standard BankFrame handling - use overlay instead of Hide() to avoid taint
    if not BankFrame or not BankFrame:IsShown() then return end
    
    -- Defer to next frame to avoid taint during protected actions
    C_Timer.After(0, function()
        if not BankFrame or not BankFrame:IsShown() then return end
        if not ShouldBlock() then return end
        
        -- Find the Warbound tab and cover it with an overlay
        if BankFrame.TabSystem then
            local tabSystem = BankFrame.TabSystem
            local warboundTab = nil
            
            -- Find the Warbound tab (tab 2)
            if tabSystem.tabs and tabSystem.tabs[2] then
                warboundTab = tabSystem.tabs[2]
            elseif tabSystem.GetTabButton then
                warboundTab = tabSystem:GetTabButton(2)
            end
            
            if warboundTab and warboundTab:IsShown() then
                -- Create overlay if it doesn't exist
                if not warboundTabOverlay then
                    warboundTabOverlay = CreateFrame("Frame", "AllforOneWarboundTabOverlay", UIParent)
                    warboundTabOverlay:SetFrameStrata("DIALOG")
                    warboundTabOverlay:SetFrameLevel(100)
                    -- Completely transparent - just blocks clicks
                    warboundTabOverlay:EnableMouse(true) -- Block clicks
                    warboundTabOverlay:SetScript("OnMouseDown", function()
                        NotifyBlocked("access")
                    end)
                end
                
                -- Make the actual tab invisible using SetAlpha
                warboundTab:SetAlpha(0)
                hiddenAlphaTab = warboundTab
                
                -- Position overlay over the Warbound tab
                warboundTabOverlay:ClearAllPoints()
                warboundTabOverlay:SetPoint("TOPLEFT", warboundTab, "TOPLEFT", 0, 0)
                warboundTabOverlay:SetPoint("BOTTOMRIGHT", warboundTab, "BOTTOMRIGHT", 0, 0)
                warboundTabOverlay:Show()
                
                BR:Debug("WarboundBlock: Covered Warbound tab with overlay")
            end
        end
    end)
end

-- Show the Warbound Bank tab button (when blocking is disabled)
local function ShowWarboundBankTab()
    -- Restore Baganator tabs (third-party, safe)
    ShowBaganatorWarboundTabs()
    
    -- Hide the overlay
    if warboundTabOverlay then
        warboundTabOverlay:Hide()
    end
    
    -- Restore alpha on the tab
    if hiddenAlphaTab then
        hiddenAlphaTab:SetAlpha(1)
        hiddenAlphaTab = nil
    end
    
    -- Clear the reference (no longer used, but keep for compatibility)
    hiddenWarboundTab = nil
    
    BR:Debug("WarboundBlock: ShowWarboundBankTab called - overlay hidden, alpha restored")
end

-- Force switch to normal bank tab (tab 1)
-- NOTE: We no longer manipulate BankFrame.TabSystem to avoid taint!
-- Instead, we rely on CloseIfWarboundOpen() to close the bank if user clicks Warbound tab
local function ForceNormalBankTab()
    if not ShouldBlock() then return end
    
    -- We intentionally do NOT touch BankFrame.TabSystem anymore
    -- This was causing taint that blocked PurchaseBankTab()
    
    BR:Debug("WarboundBlock: ForceNormalBankTab called (no-op to avoid taint)")
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
            -- Verstecke Third-Party Warband Tabs (Baganator, Bagnon)
            HideThirdPartyWarbandTabs()
            -- Prüfe Bagnon spezifisch
            CheckBagnonWarbandAccess()
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

-- Block Warband Bank Distance Inhibitor usage via spell cast detection
-- NOTE: We cannot cancel the cast (SpellStopCasting is protected), but we can close the bank immediately after
local distanceInhibitorFrame = CreateFrame("Frame")
distanceInhibitorFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
distanceInhibitorFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not ShouldBlock() then return end
    
    if spellID == WARBAND_DISTANCE_INHIBITOR_SPELL_ID then
        -- Cast succeeded - close the bank immediately
        BR:Debug("WarboundBlock: Distance Inhibitor spell detected (ID: " .. spellID .. "), closing bank...")
        C_Timer.After(0.1, function()
            if IsWarboundBankOpen() then
                CloseBankFrame()
                NotifyBlocked("remote_access")
                BR:Print("Fernzugriff auf die Kriegsmeutenbank ist blockiert!", "warning")
            end
        end)
    end
end)

-- Check for Better Bags addon frames
local function GetBetterBagsFrames()
    local frames = {}
    
    -- Better Bags verwendet verschiedene Frame-Namen
    local patterns = {
        "BetterBagsBankFrame",
        "BetterBags_BankFrame",
        "BetterBagsBagFrame",
    }
    
    for _, pattern in ipairs(patterns) do
        local frame = _G[pattern]
        if frame then
            table.insert(frames, frame)
        end
    end
    
    -- Suche nach Frames die "BetterBags" im Namen haben
    for frameName, frame in pairs(_G) do
        if type(frameName) == "string" and frameName:find("BetterBags") and type(frame) == "table" and frame.IsShown then
            if not tContains(frames, frame) then
                table.insert(frames, frame)
            end
        end
    end
    
    return frames
end

-- Bagnon Support
local bagnonHooked = false
local originalAddonSetBankType = nil

local function HookBagnon()
    if bagnonHooked then return end
    
    -- Hook Addon_SetBankType global (BagBrother definiert diese Funktion)
    -- Dies muss zuerst passieren, auch wenn Bagnon noch nicht geladen ist
    if _G["Addon_SetBankType"] and not originalAddonSetBankType then
        originalAddonSetBankType = _G["Addon_SetBankType"]
        _G["Addon_SetBankType"] = function(bankType, ...)
            if ShouldBlock() and bankType == 2 then
                NotifyBlocked("access")
                BR:Debug("WarboundBlock: Blocked Addon_SetBankType(2) - forcing type 0")
                -- Setze auf normale Bank (Type 0)
                return originalAddonSetBankType(0, ...)
            end
            return originalAddonSetBankType(bankType, ...)
        end
        BR:Debug("WarboundBlock: Hooked global Addon_SetBankType")
    end
    
    -- Bagnon verwendet globale Addon-Tabelle
    if not Bagnon then return end
    
    bagnonHooked = true
    BR:Debug("WarboundBlock: Bagnon detected")
    
    -- Hook Bagnon.Frames wenn verfügbar
    if Bagnon.Frames then
        -- Hook die Show-Funktion für Bank-Frames
        local originalShow = Bagnon.Frames.Show
        if originalShow then
            Bagnon.Frames.Show = function(self, frameID, ...)
                -- Prüfe ob es ein Warband/Account Bank Frame ist
                if ShouldBlock() and frameID and (frameID == "warband" or frameID == "accountbank" or frameID == "warbandbank") then
                    NotifyBlocked("access")
                    BR:Debug("WarboundBlock: Blocked Bagnon frame: " .. tostring(frameID))
                    return
                end
                return originalShow(self, frameID, ...)
            end
            BR:Debug("WarboundBlock: Hooked Bagnon.Frames.Show")
        end
    end
    
    -- Hook die Bank-Klasse wenn verfügbar
    if Bagnon.Bank then
        -- Hook UpdateBankType
        local originalUpdateBankType = Bagnon.Bank.UpdateBankType
        if originalUpdateBankType then
            Bagnon.Bank.UpdateBankType = function(self, ...)
                if ShouldBlock() then
                    -- Erzwinge normale Bank (Type 0)
                    if originalAddonSetBankType then
                        originalAddonSetBankType(0)
                    elseif _G["Addon_SetBankType"] then
                        _G["Addon_SetBankType"](0)
                    end
                    BR:Debug("WarboundBlock: Blocked Bagnon UpdateBankType - forcing type 0")
                    return
                end
                return originalUpdateBankType(self, ...)
            end
            BR:Debug("WarboundBlock: Hooked Bagnon.Bank.UpdateBankType")
        end
    end
end

-- Hook BagBrother separat (wird vor Bagnon geladen)
local bagBrotherHooked = false
local function HookBagBrother()
    if bagBrotherHooked then return end
    
    -- Hook Addon_SetBankType wenn es existiert
    if _G["Addon_SetBankType"] and not originalAddonSetBankType then
        originalAddonSetBankType = _G["Addon_SetBankType"]
        _G["Addon_SetBankType"] = function(bankType, ...)
            if ShouldBlock() and bankType == 2 then
                NotifyBlocked("access")
                BR:Debug("WarboundBlock: Blocked Addon_SetBankType(2) via BagBrother hook")
                return originalAddonSetBankType(0, ...)
            end
            return originalAddonSetBankType(bankType, ...)
        end
        bagBrotherHooked = true
        BR:Debug("WarboundBlock: Hooked Addon_SetBankType via BagBrother")
    end
end

-- Prüfe Bagnon Frames und verstecke Warband-Tabs
CheckBagnonWarbandAccess = function()
    if not ShouldBlock() then return end
    
    -- Suche nach Bagnon Bank Frame (verschiedene mögliche Namen)
    local bankFrame = _G["BagnonFramebank"] or _G["BagnonBankFrame"]
    
    -- Versuche auch über Bagnon.frames
    if not bankFrame and Bagnon and Bagnon.frames then
        bankFrame = Bagnon.frames.bank
    end
    
    if bankFrame and bankFrame:IsShown() then
        -- Suche nach BagGroup (enthält die Bag-Buttons/Tabs)
        local bagGroup = bankFrame.BagGroup
        if bagGroup then
            -- Durchsuche alle Kinder des BagGroup
            for i = 1, bagGroup:GetNumChildren() do
                local child = select(i, bagGroup:GetChildren())
                if child then
                    -- Prüfe ob es ein AccountBag ist (ID > LastBankBag)
                    if child.IsAccountBag and child:IsAccountBag() then
                        child:Hide()
                        BR:Debug("WarboundBlock: Hidden Bagnon AccountBag via IsAccountBag()")
                    elseif child.GetType and child:GetType() == 2 then
                        child:Hide()
                        BR:Debug("WarboundBlock: Hidden Bagnon bag with type 2")
                    elseif child.GetID then
                        local id = child:GetID()
                        -- Account Bank Bags haben IDs > 13 (nach den normalen Bank-Bags)
                        if id and id > 13 then
                            child:Hide()
                            BR:Debug("WarboundBlock: Hidden Bagnon bag with ID " .. id)
                        end
                    end
                    -- Prüfe auch den Namen/Tooltip
                    if child.name and (child.name:find("Kriegsmeute") or child.name:find("Warband") or child.name:find("Account")) then
                        child:Hide()
                        BR:Debug("WarboundBlock: Hidden Bagnon bag with name: " .. child.name)
                    end
                end
            end
        end
        
        -- Verstecke Warband-Tabs in der Sidebar
        if bankFrame.TabGroup then
            -- Suche nach Tabs mit "Kriegsmeute" oder "Warband" Text
            for i = 1, bankFrame.TabGroup:GetNumChildren() do
                local child = select(i, bankFrame.TabGroup:GetChildren())
                if child and child.GetText then
                    local text = child:GetText()
                    if text and (text:find("Kriegsmeute") or text:find("Warband") or text:find("Account")) then
                        child:Hide()
                        BR:Debug("WarboundBlock: Hidden Bagnon tab: " .. text)
                    end
                end
            end
        end
        
        -- Erzwinge normale Bank
        if Addon_SetBankType then
            Addon_SetBankType(0)
        end
    end
end

-- Hook Better Bags to block Warband access
local betterBagsHooked = false
local function HookBetterBags()
    if betterBagsHooked then return end
    
    -- BetterBags verwendet LibStub AceAddon
    local BetterBagsAddon = LibStub and LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("BetterBags", true)
    
    if BetterBagsAddon then
        betterBagsHooked = true
        BR:Debug("WarboundBlock: Better Bags detected via AceAddon")
        
        -- Hook das BankBehavior Modul
        local bankModule = BetterBagsAddon:GetModule("BankBehavior", true)
        if bankModule and bankModule.proto then
            -- Hook SwitchToAccountBank um Warband-Zugriff zu blockieren
            local originalSwitchToAccountBank = bankModule.proto.SwitchToAccountBank
            if originalSwitchToAccountBank then
                bankModule.proto.SwitchToAccountBank = function(self, ctx, tabIndex)
                    if ShouldBlock() then
                        NotifyBlocked("access")
                        BR:Debug("WarboundBlock: Blocked BetterBags SwitchToAccountBank")
                        -- Wechsle stattdessen zur normalen Bank
                        if self.SwitchToBank then
                            self:SwitchToBank(ctx)
                        end
                        return false
                    end
                    return originalSwitchToAccountBank(self, ctx, tabIndex)
                end
                BR:Debug("WarboundBlock: Hooked BetterBags SwitchToAccountBank")
            end
            
            -- Hook GenerateWarbankTabs um Tabs zu verstecken
            local originalGenerateWarbankTabs = bankModule.proto.GenerateWarbankTabs
            if originalGenerateWarbankTabs then
                bankModule.proto.GenerateWarbankTabs = function(self, ctx)
                    if ShouldBlock() then
                        -- Verstecke alle Warbank Tabs
                        if self.bag and self.bag.tabs then
                            local tabData = C_Bank and C_Bank.FetchPurchasedBankTabData and C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
                            if tabData then
                                for _, data in pairs(tabData) do
                                    if self.bag.tabs.HideTabByID then
                                        pcall(function() self.bag.tabs:HideTabByID(data.ID) end)
                                    end
                                end
                            end
                        end
                        BR:Debug("WarboundBlock: Blocked BetterBags GenerateWarbankTabs")
                        return
                    end
                    return originalGenerateWarbankTabs(self, ctx)
                end
                BR:Debug("WarboundBlock: Hooked BetterBags GenerateWarbankTabs")
            end
            
            -- Hook OnShow um atWarbank zu prüfen
            local originalOnShow = bankModule.proto.OnShow
            if originalOnShow then
                bankModule.proto.OnShow = function(self, ctx)
                    -- Wenn wir bei der Warbank sind und blockieren sollen
                    if ShouldBlock() and BetterBagsAddon.atWarbank then
                        NotifyBlocked("access")
                        BR:Debug("WarboundBlock: Blocked BetterBags Warbank OnShow")
                        -- Setze atWarbank auf false und öffne normale Bank
                        BetterBagsAddon.atWarbank = false
                    end
                    return originalOnShow(self, ctx)
                end
                BR:Debug("WarboundBlock: Hooked BetterBags OnShow")
            end
        end
    end
end

-- Prüfe ob der Spieler bei einem Banker steht (für Distance Inhibitor Erkennung)
local function IsNearBanker()
    -- Prüfe ob ein Banker-NPC in der Nähe ist
    -- Wenn nicht, wurde die Bank wahrscheinlich remote geöffnet (Distance Inhibitor)
    for i = 1, 40 do
        local unit = "npc" .. i
        if UnitExists(unit) and UnitIsUnit(unit, "npc") then
            -- Prüfe ob es ein Banker ist (schwierig zu erkennen)
            return true
        end
    end
    
    -- Alternative: Prüfe ob wir ein Target haben das ein Banker sein könnte
    if UnitExists("target") then
        local npcID = select(6, strsplit("-", UnitGUID("target") or ""))
        -- Banker NPCs haben bestimmte IDs, aber das ist nicht zuverlässig
        -- Stattdessen prüfen wir die Entfernung
        if CheckInteractDistance("target", 3) then -- Trade distance
            return true
        end
    end
    
    -- Prüfe ob wir in einer Bank-Zone sind (grob)
    -- Dies ist nicht 100% zuverlässig, aber besser als nichts
    return false
end

-- Block Distance Inhibitor: Wenn Bank remote geöffnet wird, sofort schließen
local function CheckRemoteBankAccess()
    if not ShouldBlock() then return end
    
    -- Wenn die Warbound Bank offen ist und wir nicht bei einem Banker stehen,
    -- wurde sie wahrscheinlich mit dem Distance Inhibitor geöffnet
    if IsWarboundBankOpen() then
        -- Schließe die Bank sofort
        C_Timer.After(0, function()
            if IsWarboundBankOpen() then
                CloseBankFrame()
                NotifyBlocked("remote_access")
                BR:Print("Fernzugriff auf die Kriegsmeutenbank ist blockiert!", "warning")
            end
        end)
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
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_AccountBank" or arg1 == addonName then
            InstallHooks()
        end
        -- Hook Better Bags wenn es geladen wird
        if arg1 == "BetterBags" then
            C_Timer.After(0.5, HookBetterBags)
        end
        -- Hook Baganator wenn es geladen wird
        if arg1 == "Baganator" then
            C_Timer.After(0.5, function()
                -- Hook die globalen Mixins
                HookBaganatorWarbandMixin()
                local frames = GetBaganatorBankFrames()
                for _, frame in ipairs(frames) do
                    HookBaganatorSetTab(frame)
                end
            end)
        end
        -- Hook Bagnon wenn es geladen wird
        if arg1 == "Bagnon" then
            C_Timer.After(0.5, HookBagnon)
        end
        -- Hook BagBrother wenn es geladen wird (Basis für Bagnon)
        if arg1 == "BagBrother" then
            C_Timer.After(0.5, HookBagBrother)
        end
        -- Hook Bagnon_Bank wenn es geladen wird
        if arg1 == "Bagnon_Bank" then
            C_Timer.After(0.5, function()
                HookBagBrother()
                HookBagnon()
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        -- Ensure hooks are installed after login
        InstallHooks()
        -- Try to hook third-party addons
        C_Timer.After(1, HookBetterBags)
        C_Timer.After(1, HookBagBrother)
        C_Timer.After(1, HookBagnon)
        C_Timer.After(1, function()
            -- Hook Baganator Mixins
            HookBaganatorWarbandMixin()
            local frames = GetBaganatorBankFrames()
            for _, frame in ipairs(frames) do
                HookBaganatorSetTab(frame)
            end
        end)
        -- Nochmal nach 3 Sekunden versuchen (falls Addons später laden)
        C_Timer.After(3, function()
            HookBaganatorWarbandMixin()
            HookBetterBags()
            HookBagBrother()
            HookBagnon()
        end)
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Prüfe ob Better Bags, Baganator oder Bagnon Frames offen sind
        if ShouldBlock() then
            HookBetterBags()
            HookBagBrother()
            HookBagnon()
            CheckBaganatorWarbandAccess()
            CheckBagnonWarbandAccess()
            HideThirdPartyWarbandTabs()
            -- Prüfe Better Bags Frames
            local betterBagsFrames = GetBetterBagsFrames()
            for _, frame in ipairs(betterBagsFrames) do
                if frame:IsShown() then
                    -- Versuche Warband Tab zu verstecken
                    if frame.Tabs then
                        for i, tab in ipairs(frame.Tabs) do
                            if tab.tabID == 2 or (tab.GetText and tab:GetText() and (tab:GetText():find("Kriegsmeute") or tab:GetText():find("Warband"))) then
                                tab:Hide()
                            end
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if PLAYER_INTERACTION then
            -- AccountBankPanel interaction type
            local accountBankType = PLAYER_INTERACTION.AccountBankPanel
            if arg1 == accountBankType and ShouldBlock() then
                -- Prüfe ob dies ein Remote-Zugriff ist (Distance Inhibitor)
                -- Wenn ja, schließe die Bank sofort
                CheckRemoteBankAccess()
                
                C_Timer.After(0.1, function()
                    BlockWarboundButtons()
                    UpdateBagOverlays()
                    -- Nochmal prüfen nach kurzer Verzögerung
                    CheckRemoteBankAccess()
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
            -- Verstecke Baganator und Bagnon Warband Tabs
            HideThirdPartyWarbandTabs()
            CheckBagnonWarbandAccess()
            C_Timer.After(0.1, function()
                HideWarboundBankTab()
                ForceNormalBankTab()
                HideThirdPartyWarbandTabs()
                CheckBagnonWarbandAccess()
                -- If Warbound is still open, close it
                CloseIfWarboundOpen()
                if IsWarboundBankOpen() then
                    BlockWarboundButtons()
                    UpdateBagOverlays()
                end
            end)
            -- Nochmal nach 0.5 Sekunden (für langsam ladende Addons)
            C_Timer.After(0.5, function()
                HideThirdPartyWarbandTabs()
                CheckBagnonWarbandAccess()
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

-- Currency Transfer Block ----------------------------------------------------
-- Block the CurrencyTransferMenu (Warband currency transfers between characters)
-- NOTE: We only hide the UI, we do NOT hook C_CurrencyInfo functions as they are protected

local function BlockCurrencyTransferMenu()
    -- Hook CurrencyTransferMenu frame if it exists
    if CurrencyTransferMenu and not CurrencyTransferMenu.allforoneHooked then
        -- Hook OnShow - hide immediately
        CurrencyTransferMenu:HookScript("OnShow", function(self)
            if ShouldBlock() then
                -- Hide immediately without delay
                self:Hide()
                NotifyBlocked("currency_transfer")
            end
        end)
        
        -- Also hook the toggle button if it exists
        if CurrencyTransferMenu.SourceSelector and CurrencyTransferMenu.SourceSelector.Dropdown then
            -- This prevents the dropdown from opening
        end
        
        CurrencyTransferMenu.allforoneHooked = true
        BR:Debug("WarboundBlock: CurrencyTransferMenu OnShow hooked")
    end
    
    -- Hide the "Überweisen" / "Transfer" button in TokenFramePopup completely
    if TokenFramePopup and TokenFramePopup.CurrencyTransferToggleButton and not TokenFramePopup.CurrencyTransferToggleButton.allforoneHooked then
        local transferButton = TokenFramePopup.CurrencyTransferToggleButton
        
        -- Hide the button if blocking is enabled
        if ShouldBlock() then
            transferButton:Hide()
        end
        
        -- Hook OnShow to keep it hidden
        transferButton:HookScript("OnShow", function(self)
            if ShouldBlock() then
                self:Hide()
            end
        end)
        
        -- Also hook TokenFramePopup OnShow to hide the button when popup opens
        if not TokenFramePopup.allforoneHooked then
            TokenFramePopup:HookScript("OnShow", function(self)
                if ShouldBlock() and self.CurrencyTransferToggleButton then
                    self.CurrencyTransferToggleButton:Hide()
                end
            end)
            TokenFramePopup.allforoneHooked = true
        end
        
        transferButton.allforoneHooked = true
        BR:Debug("WarboundBlock: CurrencyTransferToggleButton hidden")
    end
end

-- NOTE: We do NOT hook C_CurrencyInfo.RequestCurrencyFromAccountCharacter because it's a
-- protected Blizzard function. Hooking it would "taint" the UI and block ALL protected actions
-- (like using items, learning mounts, etc.). Instead, we only hide the UI button.

local function BlockCurrencyTransfer()
    BlockCurrencyTransferMenu()
    
    -- Also hide the menu if it's currently shown
    if ShouldBlock() and CurrencyTransferMenu and CurrencyTransferMenu:IsShown() then
        CurrencyTransferMenu:Hide()
        NotifyBlocked("currency_transfer")
    end
end

-- Hook when Blizzard_TokenUI loads (it's loaded on demand)
local function HookCurrencyTransferWhenReady()
    if CurrencyTransferMenu then
        BlockCurrencyTransfer()
    else
        -- Wait for Blizzard_TokenUI to load
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_TokenUI" then
                C_Timer.After(0.1, BlockCurrencyTransfer)
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Module API -----------------------------------------------------------------
function WarboundBlock:OnInitialize()
    InstallHooks()
    HookCurrencyTransferWhenReady()
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
