----------------------------------------------------------------------
--  All for One - Settings Protection Module
--  Verschleiert SavedVariables mit berechneter Verschlüsselung
--  Keys werden zur Laufzeit berechnet - nicht im Code lesbar
----------------------------------------------------------------------

local addonName, BR = ...

local SettingsProtection = {}

----------------------------------------------------------------------
--  Berechnete Verschlüsselung (nicht hardcoded)
----------------------------------------------------------------------

-- Seed-Werte für die Berechnung (obfuskiert)
local S1, S2, S3 = 0x4F41, 0x464F, 0x5242 -- "OA", "FO", "RB"

-- Berechnet einen Hash aus einem String
local function ComputeHash(str)
    local h = S1
    for i = 1, #str do
        local c = str:byte(i)
        h = bit.bxor(h * 31 + c, S2)
        h = bit.band(h, 0xFFFFFF) -- 24-bit limit
    end
    return h
end

-- Generiert einen verschleierten Key aus dem Original
local function GenerateKey(original)
    local hash = ComputeHash(original)
    -- Format: _[hex][hex][hex][suffix]
    return string.format("_%x%x", 
        bit.band(bit.rshift(hash, 12), 0xFFF),
        bit.band(hash, 0xFFF))
end

-- Generiert einen verschleierten Wert für Boolean
local function GenerateValuePair(original)
    local h1 = ComputeHash(original .. "T" .. tostring(S3))
    local h2 = ComputeHash(original .. "F" .. tostring(S3))
    return {
        t = string.format("%X_%s", bit.band(h1, 0xFF), original:sub(1,1)),
        f = string.format("%X_%s", bit.band(h2, 0xFF), original:lower():sub(1,1))
    }
end

-- Generiert Security Key
local function GenerateSecurityKey(original)
    local hash = ComputeHash("SEC_" .. original)
    return string.format("_s%x", bit.band(hash, 0xFFF))
end

-- Liste aller geschützten Settings
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
    "MailBlockMode",
}

-- Security Data Keys
local SECURITY_KEYS = {
    "totalTimePlayed",
    "lastUpdate",
    "lastRealTime",
    "sessionActive",
    "wasDisabled",
}

-- Mappings werden zur Laufzeit berechnet (nicht im Code sichtbar)
local KEY_MAP = {}
local REVERSE_KEY_MAP = {}
local VALUE_MAP = {}

for _, name in ipairs(PROTECTED_SETTINGS) do
    local key = GenerateKey(name)
    KEY_MAP[name] = key
    REVERSE_KEY_MAP[key] = name
    if name ~= "MailBlockMode" then
        VALUE_MAP[name] = GenerateValuePair(name)
    end
end

-- MailBlockMode Werte (String statt Boolean)
local MAILMODE_HASH_F = ComputeHash("MAIL_FULL")
local MAILMODE_HASH_S = ComputeHash("MAIL_SEL")
local MAILMODE_MAP = {
    full = string.format("M%X", bit.band(MAILMODE_HASH_F, 0xFFF)),
    selective = string.format("M%X", bit.band(MAILMODE_HASH_S, 0xFFF)),
}
local REVERSE_MAILMODE_MAP = {}
for k, v in pairs(MAILMODE_MAP) do
    REVERSE_MAILMODE_MAP[v] = k
end

-- Security Key Mappings
local SECURITY_KEY_MAP = {}
local REVERSE_SECURITY_KEY_MAP = {}
for _, name in ipairs(SECURITY_KEYS) do
    local key = GenerateSecurityKey(name)
    SECURITY_KEY_MAP[name] = key
    REVERSE_SECURITY_KEY_MAP[key] = name
end

----------------------------------------------------------------------
--  Hilfsfunktionen
----------------------------------------------------------------------

-- Konvertiert Boolean zu verschleiertem Wert
local function ObfuscateBoolean(value, settingName)
    if type(value) ~= "boolean" then return value end
    
    local map = VALUE_MAP[settingName]
    if not map then return value end
    
    return value and map.t or map.f
end

-- Konvertiert verschleierten Wert zurück zu Boolean
local function DeobfuscateBoolean(value, settingName)
    if type(value) ~= "string" then return value end
    
    local map = VALUE_MAP[settingName]
    if not map then return value end
    
    if value == map.t then
        return true
    elseif value == map.f then
        return false
    end
    
    -- Unbekannter Wert = Manipulation oder Legacy
    -- Bei "A7_" prefix -> true, bei "B3_" prefix -> false
    if value:sub(1, 3) == "A7_" then
        return true
    elseif value:sub(1, 3) == "B3_" then
        return false
    end
    
    -- Legacy Boolean-Wert direkt
    if value == "true" then return true end
    if value == "false" then return false end
    
    return nil -- Manipulation
end

----------------------------------------------------------------------
--  Öffentliche API
----------------------------------------------------------------------

-- Verschleiert alle geschützten Settings beim Speichern
function SettingsProtection:ObfuscateSettings()
    if not AllforOneCharDB then return end
    
    for _, settingName in ipairs(PROTECTED_SETTINGS) do
        local value = AllforOneCharDB[settingName]
        local obfuscatedKey = KEY_MAP[settingName]
        
        if settingName == "MailBlockMode" then
            -- MailBlockMode ist ein String
            if type(value) == "string" and MAILMODE_MAP[value] then
                AllforOneCharDB[settingName] = nil
                AllforOneCharDB[obfuscatedKey] = MAILMODE_MAP[value]
            end
        elseif type(value) == "boolean" then
            local obfuscatedValue = ObfuscateBoolean(value, settingName)
            AllforOneCharDB[settingName] = nil
            AllforOneCharDB[obfuscatedKey] = obfuscatedValue
        end
    end
    
    -- SecurityData verschleiern
    if AllforOneCharDB.SecurityData then
        local obfSecData = {}
        for key, value in pairs(AllforOneCharDB.SecurityData) do
            local obfKey = SECURITY_KEY_MAP[key] or key
            obfSecData[obfKey] = value
        end
        AllforOneCharDB.SecurityData = nil
        AllforOneCharDB._sd = obfSecData
    end
    
    -- Version markieren
    AllforOneCharDB._pv = 6 -- Version 6 = Berechnete Verschlüsselung
    
    BR:Debug("SettingsProtection: Settings verschleiert (v6)")
end

-- Entschlüsselt alle geschützten Settings beim Laden
function SettingsProtection:DeobfuscateSettings()
    if not AllforOneCharDB then return true end
    
    local version = AllforOneCharDB._pv or AllforOneCharDB._v or 1
    
    -- Version 4+: Statische Verschlüsselung
    if version >= 4 then
        for obfuscatedKey, settingName in pairs(REVERSE_KEY_MAP) do
            local value = AllforOneCharDB[obfuscatedKey]
            if value ~= nil then
                if settingName == "MailBlockMode" then
                    -- MailBlockMode ist ein String
                    local deobfuscated = REVERSE_MAILMODE_MAP[value]
                    AllforOneCharDB[settingName] = deobfuscated or "selective"
                else
                    local deobfuscated = DeobfuscateBoolean(value, settingName)
                    if deobfuscated ~= nil then
                        AllforOneCharDB[settingName] = deobfuscated
                    else
                        AllforOneCharDB[settingName] = true
                        BR:Debug("SettingsProtection: " .. settingName .. " reset (manipulation)")
                    end
                end
                AllforOneCharDB[obfuscatedKey] = nil
            end
        end
        
        -- SecurityData entschlüsseln (Version 5+)
        if AllforOneCharDB._sd then
            local secData = {}
            for obfKey, value in pairs(AllforOneCharDB._sd) do
                local realKey = REVERSE_SECURITY_KEY_MAP[obfKey] or obfKey
                secData[realKey] = value
            end
            AllforOneCharDB._sd = nil
            AllforOneCharDB.SecurityData = secData
        end
        
        -- Cleanup
        AllforOneCharDB._pv = nil
    else
        -- Legacy-Versionen: Prüfe ob alte verschleierte Keys existieren
        -- und konvertiere sie oder lass sie als Boolean
        for _, settingName in ipairs(PROTECTED_SETTINGS) do
            local value = AllforOneCharDB[settingName]
            -- Wenn String, versuche zu deobfuscieren
            if type(value) == "string" then
                if value:sub(1, 2) == "T_" then
                    AllforOneCharDB[settingName] = true
                elseif value:sub(1, 2) == "F_" then
                    AllforOneCharDB[settingName] = false
                end
            end
        end
        -- Cleanup alte Metadaten
        AllforOneCharDB._v = nil
        AllforOneCharDB._x = nil
        AllforOneCharDB._settingsChecksum = nil
        AllforOneCharDB._settingsVersion = nil
        
        -- Entferne alte dynamisch generierte Keys (beginnen mit _)
        local keysToRemove = {}
        for key, _ in pairs(AllforOneCharDB) do
            if type(key) == "string" and key:match("^_[A-F0-9]+$") then
                table.insert(keysToRemove, key)
            end
        end
        for _, key in ipairs(keysToRemove) do
            AllforOneCharDB[key] = nil
        end
    end
    
    BR:Debug("SettingsProtection: Settings entschlüsselt")
    return true
end

-- Initialisierung
function SettingsProtection:OnInitialize()
    BR:Debug("SettingsProtection module initialized")
end

function SettingsProtection:OnEnable()
    self:DeobfuscateSettings()
end

function SettingsProtection:OnDisable()
    self:ObfuscateSettings()
end

function SettingsProtection:Refresh()
    -- Nichts zu tun
end

-- Exportiere für Core.lua
BR.SettingsProtection = SettingsProtection

BR:RegisterModule("SettingsProtection", SettingsProtection)
