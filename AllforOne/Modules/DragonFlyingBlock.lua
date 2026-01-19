----------------------------------------------------------------------
--  All for One - Dragon Flying Block Module
--  Block dynamic flying (Skyriding) until max level, allow static flying
----------------------------------------------------------------------

local addonName, BR = ...

local DragonFlyingBlock = {
    enabled = false,
    hooked = false,
    savedFlyingMode = nil,
    isInDragonRace = false,
    isInDragonQuest = false,
}

-- Max level constant (TWW = 80)
local MAX_LEVEL = 80

-- Dragonriding race area IDs and quest IDs to allow dynamic flying
local DRAGONRIDING_RACE_AREAS = {
    -- Dragon Isles racing areas
    [2022] = true, -- Waking Shores
    [2023] = true, -- Ohn'ahran Plains
    [2024] = true, -- Azure Span
    [2025] = true, -- Thaldraszus
    [2112] = true, -- Valdrakken
    [2151] = true, -- Forbidden Reach
    [2133] = true, -- Zaralek Cavern
    [2200] = true, -- Emerald Dream
}

-- Quest IDs related to dragonriding training/races
local DRAGONRIDING_QUEST_IDS = {
    -- Dragonriding training quests
    [68795] = true, -- Dragonriding intro
    [68796] = true, -- Dragonriding training
    [72483] = true, -- Advanced Dragonriding
}

function DragonFlyingBlock:OnInitialize()
    BR:Debug("DragonFlyingBlock module initialized")
    self:SetupHooks()
    self:SetupEvents()
end

function DragonFlyingBlock:OnEnable()
    if not BR:GetSetting("BlockDragonFlying") then return end
    self.enabled = true
    BR:Debug("DragonFlyingBlock enabled")
    
    -- Apply static flying mode if not max level
    self:EnforceStaticFlying()
end

function DragonFlyingBlock:OnDisable()
    self.enabled = false
    BR:Debug("DragonFlyingBlock disabled")
    
    -- Restore saved flying mode if we changed it
    self:RestoreFlyingMode()
end

function DragonFlyingBlock:Refresh()
    local wasEnabled = self.enabled
    self.enabled = BR:GetSetting("Enabled") and BR:GetSetting("BlockDragonFlying")
    
    if self.enabled and not wasEnabled then
        self:EnforceStaticFlying()
    elseif not self.enabled and wasEnabled then
        self:RestoreFlyingMode()
    end
end

function DragonFlyingBlock:ShouldBlock()
    if not self.enabled then return false end
    if not BR:GetSetting("Enabled") then return false end
    if not BR:GetSetting("BlockDragonFlying") then return false end
    
    -- Don't block at max level
    local playerLevel = UnitLevel("player")
    if playerLevel >= MAX_LEVEL then
        return false
    end
    
    -- Don't block during dragonriding races or quests
    if self:IsInDragonridingContent() then
        return false
    end
    
    return true
end

function DragonFlyingBlock:IsInDragonridingContent()
    -- Check if in a dragonriding race
    if self.isInDragonRace then
        return true
    end
    
    -- Check active quests for dragonriding content
    if self:HasActiveDragonridingQuest() then
        return true
    end
    
    -- Check if currently in a race (by checking for race aura or UI)
    if self:IsInActiveRace() then
        return true
    end
    
    return false
end

function DragonFlyingBlock:HasActiveDragonridingQuest()
    for questID, _ in pairs(DRAGONRIDING_QUEST_IDS) do
        if C_QuestLog.IsOnQuest(questID) then
            return true
        end
    end
    return false
end

function DragonFlyingBlock:IsInActiveRace()
    -- Check for dragonriding race world quest or event
    -- Race UI element check
    if DragonridingPanelFrame and DragonridingPanelFrame:IsShown() then
        return true
    end
    
    -- Check for race buff/aura (Race in Progress)
    local raceAuras = {369968, 377234} -- Common race aura IDs
    for _, auraID in ipairs(raceAuras) do
        if C_UnitAuras then
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(auraID)
            if auraData then
                return true
            end
        end
    end
    
    return false
end

function DragonFlyingBlock:GetCurrentFlyingMode()
    -- Check CVar for dynamic flight setting
    -- dynamicFlightMountedOption: 0 = dynamic (Skyriding), 1 = static (Steady Flight)
    local cvar = C_CVar.GetCVar("dynamicFlightMountedOption")
    if cvar then
        return tonumber(cvar) or 0
    end
    return 0 -- Default to dynamic
end

function DragonFlyingBlock:SetFlyingMode(mode)
    -- mode: 0 = dynamic (Skyriding), 1 = static (Steady Flight)
    if C_CVar.SetCVar then
        C_CVar.SetCVar("dynamicFlightMountedOption", tostring(mode))
        BR:Debug("DragonFlyingBlock: Set flying mode to " .. (mode == 1 and "static" or "dynamic"))
    end
end

function DragonFlyingBlock:EnforceStaticFlying()
    if not self:ShouldBlock() then return end
    
    local currentMode = self:GetCurrentFlyingMode()
    
    -- Save current mode if it's dynamic, so we can restore later
    if currentMode == 0 then
        self.savedFlyingMode = 0
        self:SetFlyingMode(1) -- Set to static
        BR:Debug("DragonFlyingBlock: Enforced static flying mode")
    end
end

function DragonFlyingBlock:RestoreFlyingMode()
    if self.savedFlyingMode ~= nil then
        self:SetFlyingMode(self.savedFlyingMode)
        self.savedFlyingMode = nil
        BR:Debug("DragonFlyingBlock: Restored flying mode")
    end
end

function DragonFlyingBlock:SetupEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_REMOVED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LEVEL_UP" then
            local newLevel = ...
            if newLevel and newLevel >= MAX_LEVEL then
                -- Reached max level, restore flying mode
                DragonFlyingBlock:RestoreFlyingMode()
                BR:Debug("DragonFlyingBlock: Max level reached, dynamic flying allowed")
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Re-apply on login/reload
            C_Timer.After(2, function()
                DragonFlyingBlock:EnforceStaticFlying()
            end)
        elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
            -- Check if dragonriding quest status changed
            C_Timer.After(0.5, function()
                if DragonFlyingBlock:HasActiveDragonridingQuest() then
                    DragonFlyingBlock:RestoreFlyingMode()
                else
                    DragonFlyingBlock:EnforceStaticFlying()
                end
            end)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            -- Re-check on zone change
            C_Timer.After(1, function()
                if DragonFlyingBlock:IsInActiveRace() then
                    DragonFlyingBlock:RestoreFlyingMode()
                else
                    DragonFlyingBlock:EnforceStaticFlying()
                end
            end)
        end
    end)
    
    self.eventFrame = eventFrame
end

function DragonFlyingBlock:SetupHooks()
    if self.hooked then return end
    self.hooked = true
    
    -- Hook mount usage to enforce static flying before mounting
    if C_MountJournal and C_MountJournal.SummonByID then
        local originalSummonByID = C_MountJournal.SummonByID
        C_MountJournal.SummonByID = function(mountID, ...)
            if DragonFlyingBlock:ShouldBlock() then
                -- Ensure static flying is set before mounting
                DragonFlyingBlock:EnforceStaticFlying()
            end
            return originalSummonByID(mountID, ...)
        end
    end
    
    -- Hook random favorite mount
    if C_MountJournal and C_MountJournal.SummonRandomFavorite then
        local originalSummonRandom = C_MountJournal.SummonRandomFavorite
        C_MountJournal.SummonRandomFavorite = function(...)
            if DragonFlyingBlock:ShouldBlock() then
                DragonFlyingBlock:EnforceStaticFlying()
            end
            return originalSummonRandom(...)
        end
    end
    
    -- Hook CVar changes to prevent manual override
    if C_CVar and C_CVar.SetCVar then
        local originalSetCVar = C_CVar.SetCVar
        C_CVar.SetCVar = function(cvar, value, ...)
            if cvar == "dynamicFlightMountedOption" and DragonFlyingBlock:ShouldBlock() then
                if value == "0" or value == 0 then
                    -- Trying to enable dynamic flying, block it
                    BR:Debug("DragonFlyingBlock: Blocked attempt to enable dynamic flying")
                    DragonFlyingBlock:ShowBlockMessage()
                    return originalSetCVar(cvar, "1", ...) -- Force static
                end
            end
            return originalSetCVar(cvar, value, ...)
        end
    end
    
    BR:Debug("DragonFlyingBlock: Hooks installed")
end

function DragonFlyingBlock:ShowBlockMessage()
    local playerLevel = UnitLevel("player")
    local msg = string.format(
        "Drachenfliegen ist bis Level %d gesperrt!\nAktuelles Level: %d\nStatisches Fliegen ist erlaubt.",
        MAX_LEVEL, playerLevel
    )
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Drachenfliegen gesperrt", msg, 4)
    else
        BR:Notify("Drachenfliegen gesperrt - " .. msg, "warning")
    end
end

BR:RegisterModule("DragonFlyingBlock", DragonFlyingBlock)
