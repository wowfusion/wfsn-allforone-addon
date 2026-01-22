----------------------------------------------------------------------
--  All for One - Settings Protection Module
--  Verschleiert SavedVariables mit statischer Verschlüsselung
--  Einfach aber effektiv - keine dynamischen Keys
----------------------------------------------------------------------

local addonName, BR = ...

local SettingsProtection = {}

-- Statisches Mapping: Original-Name -> Verschleierter Name
-- Diese Namen sind fix und ändern sich nie
local KEY_MAP = {
    Enabled = "_k7x2",
    BlockTrade = "_m3p9",
    BlockGroupInvites = "_q1w8",
    BlockLFG = "_r4t6",
    BlockAuction = "_y5u3",
    BlockMail = "_h8j1",
    BlockCraftingOrders = "_n2b4",
    BlockWarbound = "_v6c0",
    BlockDragonFlying = "_z9a5",
}

-- Reverse Mapping für Deobfuscation
local REVERSE_KEY_MAP = {}
for original, obfuscated in pairs(KEY_MAP) do
    REVERSE_KEY_MAP[obfuscated] = original
end

-- Statische Verschlüsselungswerte für Booleans
-- true = "A7" prefix, false = "B3" prefix + setting-spezifischer suffix
local VALUE_MAP = {
    Enabled = { t = "A7_E1", f = "B3_E0" },
    BlockTrade = { t = "A7_T1", f = "B3_T0" },
    BlockGroupInvites = { t = "A7_G1", f = "B3_G0" },
    BlockLFG = { t = "A7_L1", f = "B3_L0" },
    BlockAuction = { t = "A7_U1", f = "B3_U0" },
    BlockMail = { t = "A7_M1", f = "B3_M0" },
    BlockCraftingOrders = { t = "A7_C1", f = "B3_C0" },
    BlockWarbound = { t = "A7_W1", f = "B3_W0" },
    BlockDragonFlying = { t = "A7_D1", f = "B3_D0" },
}

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
}

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
        if type(value) == "boolean" then
            local obfuscatedKey = KEY_MAP[settingName]
            local obfuscatedValue = ObfuscateBoolean(value, settingName)
            
            -- Entferne Original-Key und setze verschleierten Key
            AllforOneCharDB[settingName] = nil
            AllforOneCharDB[obfuscatedKey] = obfuscatedValue
        end
    end
    
    -- Version markieren
    AllforOneCharDB._pv = 4 -- Version 4 = statische Verschlüsselung
    
    BR:Debug("SettingsProtection: Settings verschleiert (v4)")
end

-- Entschlüsselt alle geschützten Settings beim Laden
function SettingsProtection:DeobfuscateSettings()
    if not AllforOneCharDB then return true end
    
    local version = AllforOneCharDB._pv or AllforOneCharDB._v or 1
    
    -- Version 4: Statische Verschlüsselung
    if version >= 4 then
        for obfuscatedKey, settingName in pairs(REVERSE_KEY_MAP) do
            local value = AllforOneCharDB[obfuscatedKey]
            if value ~= nil then
                local deobfuscated = DeobfuscateBoolean(value, settingName)
                if deobfuscated ~= nil then
                    AllforOneCharDB[settingName] = deobfuscated
                else
                    -- Manipulation erkannt - Standardwert setzen
                    AllforOneCharDB[settingName] = true
                    BR:Debug("SettingsProtection: " .. settingName .. " reset (manipulation)")
                end
                -- Entferne verschleierten Key
                AllforOneCharDB[obfuscatedKey] = nil
            end
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
