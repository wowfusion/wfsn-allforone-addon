# AllforOne SavedVariables Dokumentation

## Übersicht

Das AllforOne Addon verwendet zwei SavedVariables-Tabellen:
- **AllforOneDB**: Globale Einstellungen (alle Charaktere)
- **AllforOneCharDB**: Charakterspezifische Einstellungen

## Verschlüsselungssystem

Das Addon verwendet ein statisches Verschlüsselungssystem (Version 5) um kritische Einstellungen vor Manipulation zu schützen.

### Geschützte Variablen

| Original Key | Verschleiert | Wert-Typ | Beschreibung |
|-------------|--------------|----------|--------------|
| `Enabled` | `_k7x2` | Boolean | Addon aktiviert |
| `BlockTrade` | `_m3p9` | Boolean | Handel nur mit Gilde |
| `BlockGroupInvites` | `_q1w8` | Boolean | Gruppeneinladungen nur von Gilde |
| `BlockLFG` | `_r4t6` | Boolean | Dungeonbrowser blockieren |
| `BlockAuction` | `_y5u3` | Boolean | Auktionshaus blockieren |
| `BlockMail` | `_h8j1` | Boolean | Briefkasten einschränken |
| `BlockCraftingOrders` | `_n2b4` | Boolean | Handwerksaufträge einschränken |
| `BlockWarbound` | `_v6c0` | Boolean | Warbound-Bank blockieren |
| `BlockDragonFlying` | `_z9a5` | Boolean | Drachenfliegen blockieren |
| `MailBlockMode` | `_f2x7` | String | Briefkasten-Modus |

### Boolean-Werte Verschlüsselung

Booleans werden als Strings gespeichert:
- **true** = `A7_` + Suffix (z.B. `A7_E1` für Enabled=true)
- **false** = `B3_` + Suffix (z.B. `B3_E0` für Enabled=false)

| Setting | True-Wert | False-Wert |
|---------|-----------|------------|
| Enabled | `A7_E1` | `B3_E0` |
| BlockTrade | `A7_T1` | `B3_T0` |
| BlockGroupInvites | `A7_G1` | `B3_G0` |
| BlockLFG | `A7_L1` | `B3_L0` |
| BlockAuction | `A7_U1` | `B3_U0` |
| BlockMail | `A7_M1` | `B3_M0` |
| BlockCraftingOrders | `A7_C1` | `B3_C0` |
| BlockWarbound | `A7_W1` | `B3_W0` |
| BlockDragonFlying | `A7_D1` | `B3_D0` |

### MailBlockMode Verschlüsselung

| Original | Verschleiert |
|----------|--------------|
| `full` | `X4_F` |
| `selective` | `X4_S` |

### SecurityData Verschlüsselung

Die SecurityData-Tabelle wird unter `_sd` gespeichert mit verschleierten Keys:

| Original Key | Verschleiert | Beschreibung |
|-------------|--------------|--------------|
| `totalTimePlayed` | `_s1tp` | Gespielte Zeit |
| `lastUpdate` | `_s2lu` | Letztes Update |
| `lastRealTime` | `_s3rt` | Letzte Echtzeit |
| `sessionActive` | `_s4sa` | Session aktiv |
| `wasDisabled` | `_s5wd` | War deaktiviert |

## Versionen

| Version | Änderungen |
|---------|------------|
| 1-3 | Legacy (dynamische Verschlüsselung) |
| 4 | Statische Key/Value Verschlüsselung |
| 5 | + MailBlockMode + SecurityData Schutz |

## Speicherformat

### Beim Laden (Deobfuscation)

```lua
-- Verschleierte Daten werden zu lesbaren Variablen konvertiert
AllforOneCharDB._k7x2 = "A7_E1"  --> AllforOneCharDB.Enabled = true
AllforOneCharDB._sd = {...}      --> AllforOneCharDB.SecurityData = {...}
```

### Beim Speichern (Obfuscation)

```lua
-- Lesbare Variablen werden zu verschleierten Keys/Values konvertiert
AllforOneCharDB.Enabled = true   --> AllforOneCharDB._k7x2 = "A7_E1"
AllforOneCharDB.SecurityData     --> AllforOneCharDB._sd (mit verschleierten Keys)
```

## Sortierung

Geschützte Variablen werden beim Speichern ans Ende der Tabelle verschoben:

1. **Ungeschützte Variablen** (oben):
   - GuildMapEnabled
   - GuildMapShowNames
   - GuildMapPinSize
   - ShowWelcomeOnLogin
   - DebugMode
   - MuteNotificationSounds

2. **Geschützte Variablen** (unten):
   - `_k7x2`, `_m3p9`, `_q1w8`, etc.
   - `_sd` (SecurityData)
   - `_pv` (Version)

## Manipulation-Erkennung

Bei unbekannten oder ungültigen Werten:
- Booleans mit unbekanntem Suffix werden auf `true` zurückgesetzt
- Wenn Prefix weder `A7_` noch `B3_` ist → Manipulation erkannt
- MailBlockMode Fallback: `selective`

## Entwickler-Hinweise

1. **Neue geschützte Variable hinzufügen**:
   - KEY_MAP erweitern
   - VALUE_MAP erweitern (für Booleans)
   - PROTECTED_SETTINGS erweitern

2. **Version erhöhen** bei Änderungen an der Verschlüsselung

3. **Legacy-Migration** in `DeobfuscateSettings()` beachten

## Dateien

- `Modules/SettingsProtection.lua` - Verschlüsselungslogik
- `Core.lua` - GetSetting/SetSetting API
