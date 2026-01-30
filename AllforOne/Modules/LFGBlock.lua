----------------------------------------------------------------------
--  All for One - LFG Block Module
--  Block access to Dungeon Finder / LFG Tool
----------------------------------------------------------------------

local addonName, BR = ...

local LFGBlock = {
    enabled = false,
    hooked = false,
    lastNotifyTime = 0,
    originalFunctions = {},
}

function LFGBlock:OnInitialize()
    BR:Debug("LFGBlock module initialized")
    self:SetupHooks()
end

function LFGBlock:OnEnable()
    if not BR:GetSetting("BlockLFG") then return end
    self.enabled = true
    BR:Debug("LFGBlock enabled")
end

function LFGBlock:OnDisable()
    self.enabled = false
    BR:Debug("LFGBlock disabled")
end

function LFGBlock:Refresh()
    self.enabled = BR:GetSetting("Enabled") and BR:GetSetting("BlockLFG")
end

function LFGBlock:GetCurrentMapId()
    local mapId
    local ok, id = pcall(function() return C_Map.GetBestMapForUnit("player") end)
    if ok and id then mapId = id end
    
    if not mapId then
        ok, id = pcall(function() return GetCurrentMapAreaID() end)
        if ok and id then mapId = id end
    end
    
    return mapId
end

function LFGBlock:ShouldBlock()
    if not (self.enabled and BR:GetSetting("Enabled") and BR:GetSetting("BlockLFG")) then
        return false
    end
    
    -- Ausnahme: Insel der Verbannten (Exile's Reach) - Tutorial-Gebiet
    -- Dort muss LFG erlaubt sein für den Tutorial-Dungeon
    local mapId = self:GetCurrentMapId()
    if mapId == 1409 then
        return false
    end
    
    return true
end

function LFGBlock:SetupHooks()
    -- Hook C_LFGList functions to prevent creating/applying
    if C_LFGList then
        if C_LFGList.CreateListing then
            self.originalFunctions.CreateListing = C_LFGList.CreateListing
            C_LFGList.CreateListing = function(...)
                if LFGBlock:ShouldBlock() then
                    LFGBlock:ShowBlockMessage()
                    return
                end
                return LFGBlock.originalFunctions.CreateListing(...)
            end
        end
        
        if C_LFGList.ApplyToGroup then
            self.originalFunctions.ApplyToGroup = C_LFGList.ApplyToGroup
            C_LFGList.ApplyToGroup = function(...)
                if LFGBlock:ShouldBlock() then
                    LFGBlock:ShowBlockMessage()
                    return
                end
                return LFGBlock.originalFunctions.ApplyToGroup(...)
            end
        end
    end
    
    -- Hook PVEFrame when addon loads
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if arg1 == "Blizzard_PVPUI" or arg1 == "Blizzard_LookingForGroupUI" then
            LFGBlock:HookPVEFrame()
        end
    end)
    
    self.eventFrame = eventFrame
    
    -- Try to hook immediately if already loaded
    if PVEFrame then
        self:HookPVEFrame()
    end
end

function LFGBlock:HookPVEFrame()
    if self.hooked then return end
    if not PVEFrame then return end
    self.hooked = true
    
    -- Hook OnShow - move off-screen and close
    PVEFrame:HookScript("OnShow", function(frame)
        if LFGBlock:ShouldBlock() then
            LFGBlock:BlockLFGFrame()
        end
    end)
    
    BR:Debug("PVEFrame OnShow hooked")
end

function LFGBlock:BlockLFGFrame()
    -- Close the PVE frame immediately
    if PVEFrame then
        HideUIPanel(PVEFrame)
        PVEFrame:Hide()
    end
    
    -- Show notification (debounced)
    local now = GetTime()
    if now - self.lastNotifyTime > 1 then
        self.lastNotifyTime = now
        self:ShowBlockMessage()
    end
end

function LFGBlock:ShowBlockMessage()
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Dungeonbrowser blockiert", "Der Dungeonbrowser/LFG ist im Guildfound-Modus gesperrt.", 4)
    else
        BR:Notify("Dungeonbrowser blockiert! Nur Gildengruppen erlaubt.", "warning")
    end
end

BR:RegisterModule("LFGBlock", LFGBlock)
