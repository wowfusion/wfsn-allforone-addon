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

-- Max Level ist fest auf 80 gesetzt
local MAX_LEVEL = 80

-- CVar für Flugstil (0 = Steady, 1 = Skyriding)
local CVAR_FLIGHT_STYLE = "dynamicFlightMountedOption"

-- Spell ID für Flugstil wechseln
local SPELL_SWITCH_FLIGHT_STYLE = 436854

-- Druiden Fluggestalt Spell-IDs
local DRUID_FLIGHT_FORM_SPELLS = {
    [783] = true,    -- Travel Form (beinhaltet Fluggestalt)
    [33943] = true,  -- Flight Form
    [40120] = true,  -- Swift Flight Form
    [165962] = true, -- Travel Form (Fluggestalt-Variante)
}

-- Druiden Fluggestalt Buff-IDs (zum Erkennen ob aktiv)
local DRUID_FLIGHT_FORM_BUFFS = {
    165962, -- Flight Form
    783,    -- Travel Form (kann Fluggestalt sein)
    33943,  -- Flight Form (alt)
    40120,  -- Swift Flight Form (alt)
}

-- Quest IDs related to dragonriding training/races (exceptions)
-- These quests REQUIRE Skyriding to complete
local DRAGONRIDING_QUEST_IDS = {
    [68795] = true, -- Dragonriding intro
    [68796] = true, -- Dragonriding training
    [72483] = true, -- Advanced Dragonriding
    [65118] = true, -- Dragonriding intro
    [65120] = true, -- Dragonriding quest (requires Skyriding)
    [65133] = true, -- Dragonriding quest (requires Skyriding)
    [77345] = true, -- Dragonriding quest (requires Skyriding)
    [68799] = true, -- Dragonriding quest (requires Skyriding)
}

-- Race auras (exceptions)
local RACE_AURAS = {369968, 377234}

-- Ausgenommene Zonen (Map IDs) - Skyriding wird in diesen Zonen erlaubt
-- Kann über API erweitert werden: C_Map.GetMapInfo(mapID)
local EXCEPTION_ZONE_IDS = {
    [2118] = true, -- The Forbidden Reach (Dracthyr Starting Zone - Tutorial)
    [2151] = true, -- The Forbidden Reach (Dracthyr Starting Zone - Öffentlich)
    [2133] = true, -- Zaralek Cavern (Dragonflight Season 2 Zone)
    -- Death Knight Starting Zone
    [4298] = true, -- Plaguelands: The Scarlet Enclave (DK Starting Zone)
    [4281] = true, -- Acherus: The Ebon Hold (old)
    [7679] = true, -- Acherus: The Ebon Hold (new)
}

function DragonFlyingBlock:OnInitialize()
    BR:Debug("DragonFlyingBlock module initialized")
    self:SetupEvents()
    -- Erstelle den globalen SecureActionButton beim Laden
    C_Timer.After(1, function()
        DragonFlyingBlock:CreateGlobalSwitchButton()
    end)
    -- Prüfe ob Spieler ein Druide ist
    self.isDruid = (select(2, UnitClass("player")) == "DRUID")
    BR:Debug("DragonFlyingBlock: Player is Druid: " .. tostring(self.isDruid))
end

function DragonFlyingBlock:OnEnable()
    -- Setze enabled basierend auf der Einstellung
    self.enabled = BR:GetSetting("BlockDragonFlying") ~= false
    BR:Debug("DragonFlyingBlock OnEnable - enabled: " .. tostring(self.enabled) .. ", BlockDragonFlying setting: " .. tostring(BR:GetSetting("BlockDragonFlying")))
end

function DragonFlyingBlock:OnDisable()
    self.enabled = false
    BR:Debug("DragonFlyingBlock disabled")
end

function DragonFlyingBlock:Refresh()
    local addonEnabled = BR:GetSetting("Enabled") ~= false
    local blockDragonFlying = BR:GetSetting("BlockDragonFlying") ~= false
    self.enabled = addonEnabled and blockDragonFlying
    BR:Debug("DragonFlyingBlock Refresh - enabled: " .. tostring(self.enabled))
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

-- Prüft den CVar für den Flugstil (zuverlässiger als Buff-Check)
function DragonFlyingBlock:IsSkyridingEnabled()
    -- Methode 1: Buff-Check (am zuverlässigsten wenn gemountet)
    -- Steady Flight Buff bedeutet definitiv kein Skyriding - NUR dann nicht blockieren
    if self:HasSteadyFlightBuff() then
        BR:Debug("DragonFlyingBlock: Steady Flight Buff gefunden - NICHT blockieren")
        return false
    end
    
    -- Skyriding Buff bedeutet definitiv Skyriding
    if self:HasSkyridingBuff() then
        BR:Debug("DragonFlyingBlock: Skyriding Buff gefunden - blockieren")
        return true
    end
    
    -- Methode 2: CVar Check als Fallback
    if C_CVar and C_CVar.GetCVar then
        local value = C_CVar.GetCVar(CVAR_FLIGHT_STYLE)
        BR:Debug("DragonFlyingBlock: CVar dynamicFlightMountedOption = '" .. tostring(value) .. "'")
        -- CVar "1" = Skyriding, "0" = Steady Flight
        if value == "0" then
            BR:Debug("DragonFlyingBlock: CVar sagt Steady Flight - NICHT blockieren")
            return false
        elseif value == "1" then
            BR:Debug("DragonFlyingBlock: CVar sagt Skyriding - blockieren")
            return true
        end
    end
    
    -- Methode 3: Wenn weder Buff noch CVar eindeutig ist, blockieren wir sicherheitshalber
    -- Der Spieler soll explizit auf Statisches Fliegen wechseln
    BR:Debug("DragonFlyingBlock: Kein eindeutiger Flugstil erkannt - blockieren (sicherheitshalber)")
    return true
end

-- Prüft ob der Spieler in einer ausgenommenen Zone ist
function DragonFlyingBlock:IsInExceptionZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return false end
    
    -- Direkte Map-ID prüfen
    if EXCEPTION_ZONE_IDS[mapID] then
        BR:Debug("DragonFlyingBlock: In exception zone (mapID: " .. mapID .. ")")
        return true
    end
    
    -- Prüfe auch Parent-Maps (für Subzonen)
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.parentMapID then
        if EXCEPTION_ZONE_IDS[mapInfo.parentMapID] then
            BR:Debug("DragonFlyingBlock: In exception zone via parent (mapID: " .. mapID .. ", parentMapID: " .. mapInfo.parentMapID .. ")")
            return true
        end
    end
    
    return false
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
    
    -- Prüfe Zonen-Ausnahmen
    if self:IsInExceptionZone() then
        return true
    end
    
    return false
end

function DragonFlyingBlock:ShouldBlock()
    -- Basic checks
    if not self.enabled then 
        BR:Debug("DragonFlyingBlock:ShouldBlock - Module disabled")
        return false 
    end
    if not BR:GetSetting("Enabled") then 
        BR:Debug("DragonFlyingBlock:ShouldBlock - Addon disabled")
        return false 
    end
    if not BR:GetSetting("BlockDragonFlying") then 
        BR:Debug("DragonFlyingBlock:ShouldBlock - BlockDragonFlying setting disabled")
        return false 
    end
    
    -- Don't block at max level
    local playerLevel = UnitLevel("player")
    if playerLevel >= MAX_LEVEL then
        BR:Debug("DragonFlyingBlock:ShouldBlock - Player at max level (" .. playerLevel .. ")")
        return false
    end
    
    -- Don't block during dragonriding quests/races
    if self:IsInDragonridingException() then
        BR:Debug("DragonFlyingBlock:ShouldBlock - In dragonriding exception")
        return false
    end
    
    -- Block if Skyriding is enabled (check CVar first, then buff)
    local skyridingEnabled = self:IsSkyridingEnabled()
    local hasSkyridingBuff = self:HasSkyridingBuff()
    
    BR:Debug("DragonFlyingBlock:ShouldBlock - Skyriding CVar: " .. tostring(skyridingEnabled) .. ", Buff: " .. tostring(hasSkyridingBuff))
    
    if skyridingEnabled or hasSkyridingBuff then
        return true
    end
    
    return false
end

-- Globaler SecureActionButton für Flugstil-Wechsel (wird einmalig erstellt)
local switchFlightButton = nil

function DragonFlyingBlock:CreateGlobalSwitchButton()
    if switchFlightButton then return switchFlightButton end
    
    -- Hole lokalisierten Spell-Namen
    local spellName = C_Spell.GetSpellName(SPELL_SWITCH_FLIGHT_STYLE)
    if not spellName then
        BR:Debug("DragonFlyingBlock: Spell name not found for ID " .. SPELL_SWITCH_FLIGHT_STYLE)
        return nil
    end
    
    BR:Debug("DragonFlyingBlock: Creating global switch button with spell: " .. spellName)
    
    -- Create secure action button that can cast spells
    switchFlightButton = CreateFrame("Button", "AllforOneSwitchFlightButton", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    switchFlightButton:SetSize(180, 26)
    switchFlightButton:SetText("Auf Statisch wechseln")
    switchFlightButton:SetAttribute("type", "spell")
    switchFlightButton:SetAttribute("spell", spellName)
    switchFlightButton:RegisterForClicks("AnyUp", "AnyDown") -- Beide für SecureActionButton
    switchFlightButton:Hide()
    
    -- Flag um doppelte Nachrichten zu verhindern
    local lastClickTime = 0
    switchFlightButton:SetScript("PostClick", function()
        local now = GetTime()
        if now - lastClickTime < 0.5 then return end -- Ignoriere schnelle Doppelklicks
        lastClickTime = now
        
        BR:Print("Flugstil wird gewechselt...", "info")
        C_Timer.After(0.5, function()
            if DragonFlyingBlock.blockPopup then
                DragonFlyingBlock.blockPopup:Hide()
            end
        end)
    end)
    
    BR:Debug("DragonFlyingBlock: Global switch flight button created")
    return switchFlightButton
end

function DragonFlyingBlock:SwitchToSteadyFlight()
    -- Versuche CVar zu setzen
    local success = false
    if C_CVar and C_CVar.SetCVar then
        -- Versuche den CVar zu setzen
        local result = C_CVar.SetCVar("dynamicFlightMountedOption", "0")
        BR:Debug("DragonFlyingBlock: SetCVar result = " .. tostring(result))
        
        -- Prüfe ob es funktioniert hat
        local newValue = C_CVar.GetCVar("dynamicFlightMountedOption")
        BR:Debug("DragonFlyingBlock: New CVar value = " .. tostring(newValue))
        
        if newValue == "0" then
            success = true
            BR:Print("Flugstil auf Statisches Fliegen umgestellt! Bitte erneut aufmounten.", "info")
        end
    end
    
    if not success then
        -- CVar konnte nicht gesetzt werden - zeige Anleitung
        BR:Print("Flugstil konnte nicht automatisch umgestellt werden.", "warning")
        BR:Print("Bitte öffne das Reittier-Fenster (Shift+P) und klicke unten links auf 'Flugstil wechseln'.", "info")
        
        -- Öffne das Mount Journal falls möglich
        if MountJournal_Toggle then
            MountJournal_Toggle()
        elseif ToggleCollectionsJournal then
            ToggleCollectionsJournal(1) -- 1 = Mount tab
        end
    end
end

function DragonFlyingBlock:ShowBlockMessage()
    -- Prevent spam (max once per 3 seconds)
    local now = GetTime()
    if now - self.lastBlockTime < 3 then return end
    self.lastBlockTime = now
    
    local playerLevel = UnitLevel("player")
    
    -- Zeige eigenes Popup mit SecureActionButton
    self:ShowSkyridingBlockPopup(playerLevel)
end

-- Eigenes Popup mit SecureActionButton für Flugstil-Wechsel
function DragonFlyingBlock:ShowSkyridingBlockPopup(playerLevel)
    -- Schließe altes Popup falls vorhanden
    if self.blockPopup then
        self.blockPopup:Hide()
    end
    
    -- Erstelle Popup-Frame
    local frame = CreateFrame("Frame", "AllforOneSkyridingBlockPopup", UIParent, "BackdropTemplate")
    frame:SetSize(380, 140)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetBackdrop(BR.Backdrops.Popup)
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Titel
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("|cFFFF4444Himmelsreiten gesperrt|r")
    
    -- Nachricht
    local msg = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("TOP", title, "BOTTOM", 0, -10)
    msg:SetWidth(340)
    msg:SetJustifyH("CENTER")
    msg:SetText(string.format(
        "Himmelsreiten ist erst ab Stufe %d erlaubt!\n\nAktuelle Stufe: %d",
        MAX_LEVEL, playerLevel
    ))
    
    -- Verwende den globalen SecureActionButton oder erstelle Fallback
    local switchBtn = self:CreateGlobalSwitchButton()
    
    if switchBtn then
        -- Setze den Button als Kind des Popups und positioniere ihn
        switchBtn:SetParent(frame)
        switchBtn:ClearAllPoints()
        switchBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 25)
        switchBtn:Show()
    else
        -- Fallback: Normaler Button mit CVar-Wechsel
        switchBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        switchBtn:SetSize(180, 26)
        switchBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 25)
        switchBtn:SetText("Auf Statisch wechseln")
        switchBtn:SetScript("OnClick", function()
            DragonFlyingBlock:SwitchToSteadyFlight()
            frame:Hide()
        end)
    end
    
    -- Schließen Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Beim Schließen des Popups den globalen Button wieder verstecken
    frame:SetScript("OnHide", function()
        if switchFlightButton then
            switchFlightButton:SetParent(UIParent)
            switchFlightButton:ClearAllPoints()
            switchFlightButton:Hide()
        end
    end)
    
    -- Sound abspielen
    if not BR:GetSetting("MuteNotificationSounds") then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
    
    -- Auto-Hide nach 10 Sekunden
    C_Timer.After(10, function()
        if frame:IsShown() then
            frame:Hide()
        end
    end)
    
    frame:Show()
    self.blockPopup = frame
    
    -- ESC zum Schließen
    tinsert(UISpecialFrames, "AllforOneSkyridingBlockPopup")
end

function DragonFlyingBlock:CheckAndDismount()
    -- Called when player mounts - check if we should dismount them
    if not self:ShouldBlock() then return end
    
    -- Ignore taxi flights (flight master NPCs)
    if UnitOnTaxi("player") then
        BR:Debug("DragonFlyingBlock: Player is on taxi - ignoring")
        return
    end
    
    -- Player just mounted with Skyriding active - dismount them!
    if IsMounted() then
        Dismount()
        self:ShowBlockMessage()
        BR:Debug("DragonFlyingBlock: Dismounted player (Skyriding active)")
    end
end

-- Prüft ob der Spieler sich aktuell in Druiden-Fluggestalt befindet
function DragonFlyingBlock:IsInDruidFlightForm()
    if not self.isDruid then return false end
    if not C_UnitAuras then return false end
    
    for _, buffID in ipairs(DRUID_FLIGHT_FORM_BUFFS) do
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
        if auraData then
            -- Bei Travel Form (783) prüfen ob wir wirklich fliegen
            if buffID == 783 then
                -- Nur als Fluggestalt zählen wenn wir fliegen können/sind
                if IsFlying() or IsFlyableArea() then
                    BR:Debug("DragonFlyingBlock: Druid in Travel Form (flying context)")
                    return true
                end
            else
                BR:Debug("DragonFlyingBlock: Druid in Flight Form (buff " .. buffID .. ")")
                return true
            end
        end
    end
    return false
end

-- Bricht die Druiden-Fluggestalt ab
function DragonFlyingBlock:CancelDruidFlightForm()
    if not self.isDruid then return end
    
    -- CancelShapeshiftForm() bricht die aktuelle Gestaltwandlung ab
    if CancelShapeshiftForm then
        CancelShapeshiftForm()
        self:ShowBlockMessage()
        BR:Debug("DragonFlyingBlock: Cancelled Druid Flight Form (Skyriding active)")
    end
end

-- Prüft und blockiert Druiden-Fluggestalt wenn nötig
function DragonFlyingBlock:CheckDruidFlightForm()
    if not self.isDruid then return end
    if not self:ShouldBlock() then return end
    
    -- Ignore taxi flights (flight master NPCs)
    if UnitOnTaxi("player") then
        BR:Debug("DragonFlyingBlock: Druid on taxi - ignoring")
        return
    end
    
    -- Prüfe ob Druide in Fluggestalt ist
    if self:IsInDruidFlightForm() then
        self:CancelDruidFlightForm()
    end
end

function DragonFlyingBlock:SetupEvents()
    local eventFrame = CreateFrame("Frame")
    
    -- Track mount state changes
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") -- Für Mount-Spell Erkennung
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM") -- Für Druiden-Gestaltwandlung
    
    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            -- Player mount state changed
            local isMounted = IsMounted()
            BR:Debug("DragonFlyingBlock: PLAYER_MOUNT_DISPLAY_CHANGED - isMounted: " .. tostring(isMounted) .. ", wasMounted: " .. tostring(DragonFlyingBlock.wasMounted))
            
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
                BR:Debug("DragonFlyingBlock: UNIT_AURA detected mount")
                C_Timer.After(0.1, function()
                    DragonFlyingBlock:CheckAndDismount()
                end)
                DragonFlyingBlock.wasMounted = true
            elseif not IsMounted() then
                DragonFlyingBlock.wasMounted = false
            end
            
            -- Druiden-Fluggestalt Check
            if DragonFlyingBlock.isDruid then
                C_Timer.After(0.1, function()
                    DragonFlyingBlock:CheckDruidFlightForm()
                end)
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            -- Check if a mount spell was cast
            local spellID = select(3, ...)
            if spellID then
                -- Prüfe ob es ein Druiden-Fluggestalt-Spell ist
                if DragonFlyingBlock.isDruid and DRUID_FLIGHT_FORM_SPELLS[spellID] then
                    BR:Debug("DragonFlyingBlock: Druid Flight Form spell detected (ID: " .. spellID .. ")")
                    -- Kurze Verzögerung damit die Form aktiviert wird
                    C_Timer.After(0.15, function()
                        DragonFlyingBlock:CheckDruidFlightForm()
                    end)
                else
                    -- Prüfe nach kurzer Verzögerung ob wir gemountet sind
                    C_Timer.After(0.2, function()
                        if IsMounted() then
                            BR:Debug("DragonFlyingBlock: Mount spell detected (ID: " .. spellID .. ")")
                            DragonFlyingBlock:CheckAndDismount()
                        end
                    end)
                end
            end
        elseif event == "UPDATE_SHAPESHIFT_FORM" then
            -- Druide hat Gestalt gewechselt
            if DragonFlyingBlock.isDruid then
                BR:Debug("DragonFlyingBlock: UPDATE_SHAPESHIFT_FORM triggered")
                C_Timer.After(0.1, function()
                    DragonFlyingBlock:CheckDruidFlightForm()
                end)
            end
        end
    end)
    
    self.eventFrame = eventFrame
    
    -- Initialize mount state
    self.wasMounted = IsMounted()
    BR:Debug("DragonFlyingBlock: Events registered, initial mount state: " .. tostring(self.wasMounted))
end

BR:RegisterModule("DragonFlyingBlock", DragonFlyingBlock)
