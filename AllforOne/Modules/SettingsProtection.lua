----------------------------------------------------------------------
--  All for One - Settings Protection Module
--  Verschleiert und schützt SavedVariables vor Manipulation
--  Nutzt XOR-Verschlüsselung + Checksumme zur Integritätsprüfung
----------------------------------------------------------------------

local addonName, BR = ...

local SettingsProtection = {}

-- Verschlüsselungsschlüssel (wird mit Charakter-spezifischen Daten kombiniert)
local BASE_KEY = "AFO_GF_2024_WFSN_SECURE"

-- Liste der zu schützenden Settings (Boolean-Werte die manipuliert werden könnten)
local PROTECTED_SETTINGS = {
    "Enabled",
    "BlockTrade",
    "BlockGroupInvites",
    "BlockLFG",
    "BlockAuction",
    "BlockMail",
    "BlockCraftingOrders",
    "BlockWarbound",
    "BlockDragonFlying",
}

-- Generiert einen eindeutigen Schlüssel basierend auf Charakter-Daten
local function GetUniqueKey()
    local charName = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    local guid = UnitGUID("player") or ""
    return BASE_KEY .. charName .. realm .. guid
end

-- Einfache Hash-Funktion (djb2)
local function CalculateHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = bit.band(hash * 33 + string.byte(str, i), 0xFFFFFFFF)
    end
    return string.format("%08X", hash)
end

-- Konvertiert Boolean zu verschleiertem Wert
local function ObfuscateBoolean(value, key, settingName)
    if type(value) ~= "boolean" then return value end
    
    local combined = key .. settingName
    local hash = CalculateHash(combined)
    
    if value then
        return "T_" .. hash:sub(1, 4)
    else
        return "F_" .. hash:sub(1, 4)
    end
end

-- Konvertiert verschleierten Wert zurück zu Boolean
local function DeobfuscateBoolean(value, key, settingName)
    if type(value) ~= "string" then return value end
    
    local combined = key .. settingName
    local hash = CalculateHash(combined)
    local expectedHashPart = hash:sub(1, 4)
    
    if value:sub(1, 2) == "T_" then
        local storedHash = value:sub(3, 6)
        if storedHash == expectedHashPart then
            return true
        else
            -- Hash stimmt nicht überein - Manipulation erkannt
            BR:Debug("SettingsProtection: Manipulation erkannt bei " .. settingName)
            return nil -- nil signalisiert Manipulation
        end
    elseif value:sub(1, 2) == "F_" then
        local storedHash = value:sub(3, 6)
        if storedHash == expectedHashPart then
            return false
        else
            BR:Debug("SettingsProtection: Manipulation erkannt bei " .. settingName)
            return nil
        end
    end
    
    -- Unverschlüsselter Wert (Legacy) - konvertieren
    if value == true then return true end
    if value == false then return false end
    
    return value
end

-- Berechnet Checksumme über alle geschützten Settings
local function CalculateSettingsChecksum(settings)
    local str = ""
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = settings[settingName]
        if value ~= nil then
            str = str .. settingName .. "=" .. tostring(value) .. ";"
        end
    end
    str = str .. GetUniqueKey()
    return CalculateHash(str)
end

----------------------------------------------------------------------
--  Öffentliche API
----------------------------------------------------------------------

-- Verschleiert alle geschützten Settings beim Speichern
function SettingsProtection:ObfuscateSettings()
    if not AllforOneCharDB then return end
    
    local key = GetUniqueKey()
    
    -- Speichere temporär die Klartext-Werte für Checksumme
    local cleartextValues = {}
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = AllforOneCharDB[settingName]
        if type(value) == "boolean" then
            cleartextValues[settingName] = value
        end
    end
    
    -- Berechne Checksumme über Klartext-Werte
    local checksum = CalculateSettingsChecksum(cleartextValues)
    
    -- Verschleiere die Werte
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = AllforOneCharDB[settingName]
        if type(value) == "boolean" then
            AllforOneCharDB[settingName] = ObfuscateBoolean(value, key, settingName)
        end
    end
    
    -- Speichere Checksumme
    AllforOneCharDB._settingsChecksum = checksum
    AllforOneCharDB._settingsVersion = 2 -- Version für Migration
    
    BR:Debug("SettingsProtection: Settings verschleiert, Checksum: " .. checksum)
end

-- Entschlüsselt und validiert alle geschützten Settings beim Laden
function SettingsProtection:DeobfuscateSettings()
    if not AllforOneCharDB then return true end
    
    -- Prüfe ob verschleiert (Version 2+)
    if not AllforOneCharDB._settingsVersion or AllforOneCharDB._settingsVersion < 2 then
        -- Legacy-Daten: Beim nächsten Speichern verschleiern
        BR:Debug("SettingsProtection: Legacy-Daten erkannt, werden beim Logout verschleiert")
        return true
    end
    
    local key = GetUniqueKey()
    local manipulationDetected = false
    local deobfuscatedValues = {}
    
    -- Entschlüssle die Werte
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = AllforOneCharDB[settingName]
        if type(value) == "string" then
            local deobfuscated = DeobfuscateBoolean(value, key, settingName)
            if deobfuscated == nil then
                manipulationDetected = true
                -- Bei Manipulation: Setze auf Standard (true = blockiert)
                deobfuscatedValues[settingName] = true
                BR:Debug("SettingsProtection: " .. settingName .. " auf Standard zurückgesetzt")
            else
                deobfuscatedValues[settingName] = deobfuscated
            end
        elseif type(value) == "boolean" then
            -- Bereits entschlüsselt oder Legacy
            deobfuscatedValues[settingName] = value
        end
    end
    
    -- Validiere Checksumme
    local storedChecksum = AllforOneCharDB._settingsChecksum
    local calculatedChecksum = CalculateSettingsChecksum(deobfuscatedValues)
    
    if storedChecksum and storedChecksum ~= calculatedChecksum then
        BR:Debug("SettingsProtection: Checksummen-Mismatch! Gespeichert: " .. tostring(storedChecksum) .. ", Berechnet: " .. calculatedChecksum)
        manipulationDetected = true
    end
    
    -- Wende entschlüsselte Werte an
    for settingName, value in pairs(deobfuscatedValues) do
        AllforOneCharDB[settingName] = value
    end
    
    if manipulationDetected then
        BR:Print("Einstellungen wurden manipuliert! Sicherheitsrelevante Einstellungen wurden zurückgesetzt.", "error")
        -- Setze SecurityData Flag
        if AllforOneCharDB.SecurityData then
            AllforOneCharDB.SecurityData.manipulationDetected = true
            AllforOneCharDB.SecurityData.manipulationTime = time()
        end
    end
    
    return not manipulationDetected
end

-- Initialisierung
function SettingsProtection:OnInitialize()
    BR:Debug("SettingsProtection module initialized")
end

function SettingsProtection:OnEnable()
    -- Entschlüssle Settings nach dem Laden
    self:DeobfuscateSettings()
end

function SettingsProtection:OnDisable()
    -- Verschleiere Settings vor dem Speichern
    self:ObfuscateSettings()
end

function SettingsProtection:Refresh()
    -- Nichts zu tun
end

-- Exportiere Funktionen für Core.lua
BR.SettingsProtection = SettingsProtection

BR:RegisterModule("SettingsProtection", SettingsProtection)
