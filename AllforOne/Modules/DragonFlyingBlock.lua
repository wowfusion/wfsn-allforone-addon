----------------------------------------------------------------------
--  All for One - Dragon Flying Block Module
--  Block mounting while Skyriding is active until max level
--  Uses buff detection: Skyriding (404464) vs Steady Flight (404468)
--  Dismounts player immediately if they mount with Skyriding active
----------------------------------------------------------------------

local addonName, BR = ...

local DragonFlyingBlock = {
    enabled = false,
    lastBlockTime = 0,
    wasMounted = false,
}

-- Flight style buff IDs
local BUFF_SKYRIDING = 404464      -- Flugstil: Himmelsreiten
local BUFF_STEADY_FLIGHT = 404468  -- Flugstil: Statisch

-- Max level wird aus Settings geladen (Standard: 80)
local function GetMaxLevel()
    return BR:GetSetting("DragonFlyingMaxLevel") or 80
end

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
    self:SetupEvents()
end

function DragonFlyingBlock:OnEnable()
    local maxLevel = GetMaxLevel()
    if maxLevel == 0 then return end -- 0 = deaktiviert
    self.enabled = true
    BR:Debug("DragonFlyingBlock enabled (bis Level " .. maxLevel .. ")")
end

function DragonFlyingBlock:OnDisable()
    self.enabled = false
    BR:Debug("DragonFlyingBlock disabled")
end

function DragonFlyingBlock:Refresh()
    local maxLevel = GetMaxLevel()
    self.enabled = BR:GetSetting("Enabled") and maxLevel > 0
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

function DragonFlyingBlock:ShouldBlock()
    -- Basic checks
    if not self.enabled then return false end
    if not BR:GetSetting("Enabled") then return false end
    if not BR:GetSetting("BlockDragonFlying") then return false end
    
    -- Don't block at max level
    local playerLevel = UnitLevel("player")
    if playerLevel >= GetMaxLevel() then
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

-- Create a secure button for casting Switch Flight Style
local switchFlightButton
function DragonFlyingBlock:GetOrCreateSwitchButton()
    if switchFlightButton then return switchFlightButton end
    
    -- Create secure action button that can cast spells
    switchFlightButton = CreateFrame("Button", "AllforOneSwitchFlightButton", UIParent, "SecureActionButtonTemplate")
    switchFlightButton:SetAttribute("type", "spell")
    switchFlightButton:SetAttribute("spell", "Flugstil wechseln") -- German spell name
    switchFlightButton:Hide()
    
    BR:Debug("DragonFlyingBlock: Created secure switch flight button")
    return switchFlightButton
end

function DragonFlyingBlock:SwitchToSteadyFlight()
    -- Set CVar as backup
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("dynamicFlightMountedOption", "0")
        BR:Debug("DragonFlyingBlock: Set CVar dynamicFlightMountedOption=0")
    end
    BR:Debug("DragonFlyingBlock: CVar set - player needs to use spell to fully switch")
end

function DragonFlyingBlock:ShowBlockMessage()
    -- Prevent spam (max once per 3 seconds)
    local now = GetTime()
    if now - self.lastBlockTime < 3 then return end
    self.lastBlockTime = now
    
    local playerLevel = UnitLevel("player")
    local maxLevel = GetMaxLevel()
    local msg = string.format(
        "Himmelsreiten ist erst ab Stufe %d erlaubt!\n\nAktuelle Stufe: %d",
        maxLevel, playerLevel
    )
    
    if BR.ShowWarningPopup then
        BR:ShowWarningPopup(
            "Himmelsreiten gesperrt",
            msg,
            nil, -- use default display time
            "Auf Statisch wechseln",
            function()
                DragonFlyingBlock:SwitchToSteadyFlight()
            end,
            "Flugstil wechseln" -- Spell name for SecureActionButton
        )
    else
        BR:Notify("Himmelsreiten gesperrt - Bitte auf statisches Fliegen wechseln!", "warning")
    end
end

function DragonFlyingBlock:CheckAndDismount()
    -- Called when player mounts - check if we should dismount them
    if not self:ShouldBlock() then return end
    
    -- Player just mounted with Skyriding active - dismount them!
    if IsMounted() then
        Dismount()
        self:ShowBlockMessage()
        BR:Debug("DragonFlyingBlock: Dismounted player (Skyriding active)")
    end
end

function DragonFlyingBlock:SetupEvents()
    local eventFrame = CreateFrame("Frame")
    
    -- Track mount state changes
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UNIT_AURA")
    
    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            -- Player mount state changed
            local isMounted = IsMounted()
            
            -- Only check when transitioning from not mounted to mounted
            if isMounted and not DragonFlyingBlock.wasMounted then
                -- Small delay to ensure mount is fully applied
                C_Timer.After(0.1, function()
                    DragonFlyingBlock:CheckAndDismount()
                end)
            end
            
            DragonFlyingBlock.wasMounted = isMounted
            
        elseif event == "UNIT_AURA" and unit == "player" then
            -- Check if player just mounted (backup check via mount buff)
            if IsMounted() and not DragonFlyingBlock.wasMounted then
                C_Timer.After(0.1, function()
                    DragonFlyingBlock:CheckAndDismount()
                end)
                DragonFlyingBlock.wasMounted = true
            elseif not IsMounted() then
                DragonFlyingBlock.wasMounted = false
            end
        end
    end)
    
    self.eventFrame = eventFrame
    
    -- Initialize mount state
    self.wasMounted = IsMounted()
end

BR:RegisterModule("DragonFlyingBlock", DragonFlyingBlock)
