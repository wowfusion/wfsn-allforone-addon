----------------------------------------------------------------------
--  All for One - Dragon Flying Block Module
--  Block mounting while Skyriding is active until max level
--  Uses buff detection: Skyriding (404464) vs Steady Flight (404468)
----------------------------------------------------------------------

local addonName, BR = ...

local DragonFlyingBlock = {
    enabled = false,
    hooked = false,
    lastBlockTime = 0,
}

-- Flight style buff IDs
local BUFF_SKYRIDING = 404464      -- Flugstil: Himmelsreiten
local BUFF_STEADY_FLIGHT = 404468  -- Flugstil: Statisch

-- Max level constant (TWW = 80)
local MAX_LEVEL = 80

-- Quest IDs related to dragonriding training/races (exceptions)
local DRAGONRIDING_QUEST_IDS = {
    [68795] = true, -- Dragonriding intro
    [68796] = true, -- Dragonriding training
    [72483] = true, -- Advanced Dragonriding
}

-- Race auras (exceptions)
local RACE_AURAS = {369968, 377234}

function DragonFlyingBlock:OnInitialize()
    BR:Debug("DragonFlyingBlock module initialized")
    self:SetupHooks()
    self:SetupEvents()
end

function DragonFlyingBlock:OnEnable()
    if not BR:GetSetting("BlockDragonFlying") then return end
    self.enabled = true
    BR:Debug("DragonFlyingBlock enabled")
end

function DragonFlyingBlock:OnDisable()
    self.enabled = false
    BR:Debug("DragonFlyingBlock disabled")
end

function DragonFlyingBlock:Refresh()
    self.enabled = BR:GetSetting("Enabled") and BR:GetSetting("BlockDragonFlying")
end

function DragonFlyingBlock:HasSkyridingBuff()
    if not C_UnitAuras then return false end
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(BUFF_SKYRIDING)
    return auraData ~= nil
end

function DragonFlyingBlock:HasSteadyFlightBuff()
    if not C_UnitAuras then return false end
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(BUFF_STEADY_FLIGHT)
    return auraData ~= nil
end

function DragonFlyingBlock:IsInDragonridingException()
    -- Check active quests for dragonriding content
    for questID, _ in pairs(DRAGONRIDING_QUEST_IDS) do
        if C_QuestLog.IsOnQuest(questID) then
            return true
        end
    end
    
    -- Check for race auras
    if C_UnitAuras then
        for _, auraID in ipairs(RACE_AURAS) do
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(auraID)
            if auraData then
                return true
            end
        end
    end
    
    -- Check for race UI
    if DragonridingPanelFrame and DragonridingPanelFrame:IsShown() then
        return true
    end
    
    return false
end

function DragonFlyingBlock:ShouldBlockMount()
    -- Basic checks
    if not self.enabled then return false end
    if not BR:GetSetting("Enabled") then return false end
    if not BR:GetSetting("BlockDragonFlying") then return false end
    
    -- Don't block at max level
    local playerLevel = UnitLevel("player")
    if playerLevel >= MAX_LEVEL then
        return false
    end
    
    -- Don't block during dragonriding quests/races
    if self:IsInDragonridingException() then
        return false
    end
    
    -- Block if Skyriding buff is active
    if self:HasSkyridingBuff() then
        return true
    end
    
    return false
end

function DragonFlyingBlock:ShowBlockMessage()
    -- Prevent spam (max once per 3 seconds)
    local now = GetTime()
    if now - self.lastBlockTime < 3 then return end
    self.lastBlockTime = now
    
    local playerLevel = UnitLevel("player")
    local msg = string.format(
        "Himmelsreiten ist erst ab Stufe %d erlaubt!\n\nAktuelle Stufe: %d\n\nBitte wechsle auf statisches Fliegen:\nCharakter > Reiten > Flugstil: Statisch",
        MAX_LEVEL, playerLevel
    )
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup("Himmelsreiten gesperrt", msg, 5)
    else
        BR:Notify("Himmelsreiten gesperrt - Bitte auf statisches Fliegen wechseln!", "warning")
    end
end

function DragonFlyingBlock:SetupEvents()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Check on login if Skyriding is active and show reminder
            C_Timer.After(3, function()
                if DragonFlyingBlock:ShouldBlockMount() then
                    DragonFlyingBlock:ShowBlockMessage()
                end
            end)
        end
    end)
    
    self.eventFrame = eventFrame
end

function DragonFlyingBlock:SetupHooks()
    if self.hooked then return end
    self.hooked = true
    
    -- Hook C_MountJournal.SummonByID
    if C_MountJournal and C_MountJournal.SummonByID then
        local originalSummonByID = C_MountJournal.SummonByID
        C_MountJournal.SummonByID = function(mountID, ...)
            if DragonFlyingBlock:ShouldBlockMount() then
                DragonFlyingBlock:ShowBlockMessage()
                return -- Block the mount
            end
            return originalSummonByID(mountID, ...)
        end
    end
    
    -- Hook C_MountJournal.SummonRandomFavorite
    if C_MountJournal and C_MountJournal.SummonRandomFavorite then
        local originalSummonRandom = C_MountJournal.SummonRandomFavorite
        C_MountJournal.SummonRandomFavorite = function(...)
            if DragonFlyingBlock:ShouldBlockMount() then
                DragonFlyingBlock:ShowBlockMessage()
                return -- Block the mount
            end
            return originalSummonRandom(...)
        end
    end
    
    -- Hook UseItemByName (for mount items)
    if UseItemByName then
        local originalUseItemByName = UseItemByName
        _G.UseItemByName = function(itemName, ...)
            if DragonFlyingBlock:ShouldBlockMount() then
                -- Check if this is a mount item by trying to get mount info
                -- For now, block all item usage when Skyriding is active
                -- This is a broad hook but safer
                local itemID = C_Item and C_Item.GetItemIDForItemInfo and C_Item.GetItemIDForItemInfo(itemName)
                if itemID then
                    local mountID = C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(itemID)
                    if mountID then
                        DragonFlyingBlock:ShowBlockMessage()
                        return
                    end
                end
            end
            return originalUseItemByName(itemName, ...)
        end
    end
    
    BR:Debug("DragonFlyingBlock: Hooks installed (buff-based detection)")
end

BR:RegisterModule("DragonFlyingBlock", DragonFlyingBlock)
