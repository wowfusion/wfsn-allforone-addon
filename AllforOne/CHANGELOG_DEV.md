# Developer Changelog

Technische Änderungen und Details für Entwickler.

## [1.0.3] - 2026-01-29

### Modules/SecurityCheck.lua

#### Bug-Fix: Warnung erscheint nicht nach Addon-Reaktivierung
- **Problem**: Wenn `timeDiff > 3600` (1 Stunde), wurde es fälschlicherweise als "Multi-PC Szenario" behandelt und `wasDisabled` wurde nicht gesetzt
- **Lösung**: Multi-PC Erkennung verbessert - nur wenn `realTimePassed > timeDiff * 2` (Real-Time ist mehr als doppelt so groß wie /played Differenz)
- **Neue Logik in `CheckSessionStatus()`**:
  - Multi-PC Szenario: `realTimePassed > 86400` (> 24h) ODER `timeDiff > 3600 AND realTimePassed > timeDiff * 2`
  - Addon deaktiviert: `timeDiff > INACTIVITY_THRESHOLD` UND kein Multi-PC Szenario

### build.ps1

#### Bug-Fix: Linux/Mac CurseForge Installation
- **Problem**: `Compress-Archive` erstellt ZIP-Dateien mit Backslashes (`\`) in den Pfaden
- **Auswirkung**: CurseForge auf Linux/Mac interpretiert Backslashes als Teil des Dateinamens statt als Verzeichnistrenner
- **Lösung**: Manuelle ZIP-Erstellung mit .NET `ZipArchive` Klasse und expliziten Forward-Slashes
- **Geänderte Logik**:
  ```powershell
  $entryName = "AllforOne/" + ($relativePath -replace '\\', '/')
  ```

### Modules/DragonFlyingBlock.lua

#### Zonen-Ausnahmen
- **Neue `EXCEPTION_ZONE_IDS` Tabelle**: Map-IDs für Zonen, in denen Skyriding erlaubt ist
  - `2118`: The Forbidden Reach (Dracthyr Tutorial Zone)
  - `2151`: The Forbidden Reach (Öffentliche Zone)
  - `2133`: Zaralek Cavern (Dragonflight Season 2)

- **Neue Funktion `IsInExceptionZone()`**: 
  - Prüft aktuelle Map-ID via `C_Map.GetBestMapForUnit("player")`
  - Prüft auch Parent-Maps für Subzonen via `C_Map.GetMapInfo(mapID).parentMapID`
  - Debug-Logging bei Erkennung

- **Integration in `IsInDragonridingException()`**: Ruft `IsInExceptionZone()` auf

---

## [1.0.2] - 2026-01-24

### Core.lua

#### Status-Sync System
- **PendingPingResponses Migration**: Von `AllforOneDB` (account-weit) zu `AllforOneCharDB` (per-character) verschoben
  - Problem: Bei mehreren gleichzeitig eingeloggten Charakteren wurde die Liste überschrieben
  - Betrifft: `PingGuildMembers()`, `CheckPingResponses()`
  - Geänderte Variablen: `AllforOneCharDB.PendingPingResponses`, `AllforOneCharDB.LastPingTime`

- **Eigenen Spieler bei Ping ausschließen**: `PingGuildMembers()` schließt jetzt den eigenen Spieler aus der Liste aus
  - Vergleich mit `UnitName("player"):lower()`
  - Anzeige: "Status-Anfrage an X Online-Mitglieder" zeigt nur andere Spieler

- **Status-Sync Zählung korrigiert**: `CheckPingResponses()` zeigt jetzt `(responseCount + 1) / (totalOnline + 1)`
  - +1 für den eigenen Spieler, der immer antwortet

- **Status-Nachrichten nur für Offiziere/GM**: `IsGuildOfficer()` Check vor `Print()` Aufrufen
  - Betrifft: "Status-Anfrage an X gesendet", "Status-Sync abgeschlossen"

#### Startnachrichten
- Entfernt: "Addon aktiviert für diesen Charakter" / "Addon ist deaktiviert" bei PLAYER_LOGIN
- Hinzugefügt: Motivations-Nachricht nach Version-Print
  - `BR:Print("Für die Gilde, für den Zusammenhalt – bleibt fair zueinander und genießt jeden Moment in Azeroth.", "info")`

### Modules/CraftingOrderBlock.lua
- Entfernt: `BR:Print("Handwerksaufträge-Block aktiv", "info")` in `HookCraftingOrdersAPI()`

### Modules/WarboundBlock.lua

#### BetterBags Hook
- Rekursive `HideFramesWithText()` Funktion zum Verstecken von Warband-Tabs
- Hook auf `BetterBags.Bags.Bank` wenn verfügbar

#### Baganator Hook
- Hook auf `Baganator.UnifiedViews.BankViewWarbandMixin:UpdateForCharacter()`
- Automatischer Wechsel zum Character-Tab wenn Warband blockiert ist
- Kontinuierlicher Ticker zum Verstecken von Warband-Tabs

#### Bagnon Support (übersprungen)
- Komplexe Multi-Addon Struktur (Bagnon, BagBrother, Bagnon_Bank)
- Globaler Hook auf `Addon_SetBankType` implementiert aber nicht vollständig funktional
- Entscheidung: Support übersprungen wegen geringer Nutzung

### TradeBlock
- **Cross-Faction Fix**: `UnitIsInMyGuild("npc")` für zuverlässigere Erkennung
- Fallback auf `BR:IsGuildMember(tradeName)` wenn Unit-Check fehlschlägt

### TooltipEnhance
- **pcall Wrapper**: Alle Unit-Operationen in `pcall()` gewrappt
- Verhindert "secret value" Lua-Fehler bei geschützten Unit-Daten

### GuildCheck
- **IsGuildMember() verbessert**: 
  - Methode 1: `UnitIsInMyGuild(unit)` für Unit-IDs
  - Methode 2: Unit-ID Suche (target, focus, party1-4, raid1-4)
  - Methode 3: Gildenliste durchsuchen (inkl. Offline-Mitglieder)

---

## [1.0.1] - 2026-01-17

### Initiale Struktur
- Core.lua: Haupt-Addon-Logik, Event-Handling, Kommunikation
- Modulares System mit `BR.Modules` Table
- SavedVariables: `AllforOneDB` (account), `AllforOneCharDB` (character)
- Addon-Kommunikation über `C_ChatInfo.SendAddonMessage()`

### Module
- GuildCheck: Gildenmitgliedschaft-Prüfung
- TradeBlock: Handel nur mit Gildenmitgliedern
- GroupBlock: Gruppeneinladungen nur von/an Gildenmitglieder
- LFGBlock: Dungeonbrowser/LFG blockieren
- AuctionBlock: Auktionshaus blockieren
- MailBlock: Briefkasten blockieren (selektiv oder komplett)
- CraftingOrderBlock: Handwerksaufträge nur für Gilde
- WarboundBlock: Kriegsmeutenbank blockieren
- AdminPanel: Übersicht aller Addon-Nutzer
- WelcomeScreen: Willkommensbildschirm beim Login
- MinimapIcon: Minimap-Button
- SecurityCheck: Spielzeit-Tracking und Manipulationsschutz
- ChatFilter: Chat-Filterung
- TooltipEnhance: Tooltip-Erweiterungen
