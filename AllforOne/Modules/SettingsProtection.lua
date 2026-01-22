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

-- Generiert einen verschleierten Key-Namen
local function ObfuscateKeyName(settingName, key)
    local combined = key .. settingName .. "_KEY"
    local hash = CalculateHash(combined)
    return "_" .. hash:sub(1, 8)
end

-- Mapping von verschleierten Keys zu Original-Namen (für Deobfuscation)
local function BuildKeyMapping(key)
    local mapping = {}
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local obfuscatedKey = ObfuscateKeyName(settingName, key)
        mapping[obfuscatedKey] = settingName
        mapping[settingName] = obfuscatedKey
    end
    return mapping
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
    local keyMapping = BuildKeyMapping(key)
    
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
    
    -- Verschleiere die Werte UND die Key-Namen
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = AllforOneCharDB[settingName]
        if type(value) == "boolean" then
            local obfuscatedKey = keyMapping[settingName]
            local obfuscatedValue = ObfuscateBoolean(value, key, settingName)
            -- Entferne Original-Key und setze verschleierten Key
            AllforOneCharDB[settingName] = nil
            AllforOneCharDB[obfuscatedKey] = obfuscatedValue
        end
    end
    
    -- Speichere Checksumme mit verschleiertem Namen
    AllforOneCharDB._x = checksum
    AllforOneCharDB._v = 3 -- Version 3 = verschleierte Keys
    
    BR:Debug("SettingsProtection: Settings vollständig verschleiert")
end

-- Entschlüsselt und validiert alle geschützten Settings beim Laden
function SettingsProtection:DeobfuscateSettings()
    if not AllforOneCharDB then return true end
    
    local key = GetUniqueKey()
    local keyMapping = BuildKeyMapping(key)
    local manipulationDetected = false
    local deobfuscatedValues = {}
    
    -- Prüfe Version
    local version = AllforOneCharDB._v or AllforOneCharDB._settingsVersion or 1
    
    if version < 2 then
        -- Legacy-Daten (Version 1): Beim nächsten Speichern verschleiern
        BR:Debug("SettingsProtection: Legacy-Daten erkannt")
        return true
    elseif version == 2 then
        -- Version 2: Nur Werte verschleiert, Keys noch lesbar
        for _, settingName in ipairs(PROTECTED_SETTINGS) do
            local value = AllforOneCharDB[settingName]
            if type(value) == "string" then
                local deobfuscated = DeobfuscateBoolean(value, key, settingName)
                if deobfuscated == nil then
                    manipulationDetected = true
                    deobfuscatedValues[settingName] = true
                else
                    deobfuscatedValues[settingName] = deobfuscated
                end
            elseif type(value) == "boolean" then
                deobfuscatedValues[settingName] = value
            end
        end
        -- Checksumme prüfen
        local storedChecksum = AllforOneCharDB._settingsChecksum
        local calculatedChecksum = CalculateSettingsChecksum(deobfuscatedValues)
        if storedChecksum and storedChecksum ~= calculatedChecksum then
            manipulationDetected = true
        end
    else
        -- Version 3+: Keys und Werte verschleiert
        for _, settingName in ipairs(PROTECTED_SETTINGS) do
            local obfuscatedKey = keyMapping[settingName]
            local value = AllforOneCharDB[obfuscatedKey]
            
            if type(value) == "string" then
                local deobfuscated = DeobfuscateBoolean(value, key, settingName)
                if deobfuscated == nil then
                    manipulationDetected = true
                    deobfuscatedValues[settingName] = true
                    BR:Debug("SettingsProtection: " .. settingName .. " manipulation detected")
                else
                    deobfuscatedValues[settingName] = deobfuscated
                end
                -- Entferne verschleierten Key
                AllforOneCharDB[obfuscatedKey] = nil
            elseif value == nil then
                -- Setting fehlt - Standard setzen
                deobfuscatedValues[settingName] = true
            end
        end
        -- Checksumme prüfen (verschleierter Name)
        local storedChecksum = AllforOneCharDB._x
        local calculatedChecksum = CalculateSettingsChecksum(deobfuscatedValues)
        if storedChecksum and storedChecksum ~= calculatedChecksum then
            BR:Debug("SettingsProtection: Checksum mismatch")
            manipulationDetected = true
        end
        -- Cleanup verschleierte Metadaten
        AllforOneCharDB._x = nil
        AllforOneCharDB._v = nil
    end
    
    -- Cleanup alte Metadaten
    AllforOneCharDB._settingsChecksum = nil
    AllforOneCharDB._settingsVersion = nil
    
    -- Wende entschlüsselte Werte an
    for settingName, value in pairs(deobfuscatedValues) do
        AllforOneCharDB[settingName] = value
    end
    
    if manipulationDetected then
        BR:Print("Einstellungen wurden manipuliert! Sicherheitsrelevante Einstellungen wurden zurückgesetzt.", "error")
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
