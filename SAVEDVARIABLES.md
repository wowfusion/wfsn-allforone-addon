# AllforOne SavedVariables Dokumentation

## Übersicht

Das AllforOne Addon verwendet zwei SavedVariables-Tabellen:
- **AllforOneDB**: Globale Einstellungen (alle Charaktere)
- **AllforOneCharDB**: Charakterspezifische Einstellungen

## Verschlüsselungssystem

Das Addon verwendet ein **berechnetes Verschlüsselungssystem** (Version 6) um kritische Einstellungen vor Manipulation zu schützen.

### Prinzip

Die Keys und Values werden **zur Laufzeit berechnet** und sind nicht im Quellcode hardcoded:

```lua
-- Seed-Werte (obfuskiert)
local S1, S2, S3 = 0x4F41, 0x464F, 0x5242

-- Hash-Berechnung
local function ComputeHash(str)
    local h = S1
    for i = 1, #str do
        h = bit.bxor(h * 31 + str:byte(i), S2)
        h = bit.band(h, 0xFFFFFF)
    end
    return h
end

-- Key-Generierung
local function GenerateKey(original)
    local hash = ComputeHash(original)
    return string.format("_%x%x", 
        bit.band(bit.rshift(hash, 12), 0xFFF),
        bit.band(hash, 0xFFF))
end
```

### Geschützte Variablen

| Original Key | Wert-Typ | Beschreibung |
|-------------|----------|--------------|
| `Enabled` | Boolean | Addon aktiviert |
| `BlockTrade` | Boolean | Handel nur mit Gilde |
| `BlockGroupInvites` | Boolean | Gruppeneinladungen nur von Gilde |
| `BlockLFG` | Boolean | Dungeonbrowser blockieren |
| `BlockAuction` | Boolean | Auktionshaus blockieren |
| `BlockMail` | Boolean | Briefkasten einschränken |
| `BlockCraftingOrders` | Boolean | Handwerksaufträge einschränken |
| `BlockWarbound` | Boolean | Warbound-Bank blockieren |
| `BlockDragonFlying` | Boolean | Drachenfliegen blockieren |
| `MailBlockMode` | String | Briefkasten-Modus (full/selective) |

**Hinweis**: Die tatsächlichen verschleierten Keys werden zur Laufzeit berechnet und sind nicht vorhersagbar ohne den Hash-Algorithmus und die Seed-Werte.

### SecurityData

Die SecurityData-Tabelle wird unter `_sd` gespeichert mit berechneten Keys:

| Original Key | Beschreibung |
|-------------|--------------|
| `totalTimePlayed` | Gespielte Zeit (WICHTIG: wird bei Reset NICHT gelöscht!) |
| `lastUpdate` | Letztes Update |
| `lastRealTime` | Letzte Echtzeit |
| `sessionActive` | Session aktiv |
| `wasDisabled` | War deaktiviert |

## Versionen

| Version | Änderungen |
|---------|------------|
| 1-3 | Legacy (dynamische Verschlüsselung) |
| 4-5 | Statische Key/Value Verschlüsselung |
| 6 | Berechnete Verschlüsselung (nicht hardcoded) |

## Reset-Funktion

Beim Zurücksetzen der Einstellungen (`BR:ResetSettings()`):
- Alle Einstellungen werden auf Standardwerte gesetzt
- **SecurityData wird NICHT gelöscht** (Spielzeit-Tracking bleibt erhalten)
- Sync mit Gildenmeister/Offizier wird versucht

## Entwickler-Hinweise

1. **Neue geschützte Variable hinzufügen**:
   - `PROTECTED_SETTINGS` Liste erweitern
   - Mappings werden automatisch berechnet

2. **Version erhöhen** bei Änderungen an der Verschlüsselung (Seed-Werte ändern)

3. **Legacy-Migration** in `DeobfuscateSettings()` beachten

4. **Sicherheit**: Da Keys berechnet werden, kann niemand durch bloßes Lesen des Codes die SavedVariables manipulieren

## Dateien

- `Modules/SettingsProtection.lua` - Verschlüsselungslogik
- `Core.lua` - GetSetting/SetSetting API, ResetSettings
