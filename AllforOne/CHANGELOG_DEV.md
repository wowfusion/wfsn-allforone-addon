# Developer Changelog

Technische Änderungen und Details für Entwickler.

## [1.0.4] - 2026-02-02

### Modules/WarboundBlock.lua

#### KRITISCH: UI-Taint Bug behoben
- **Problem**: Direkte Hooks auf `C_Bank.DepositMoney`, `C_Bank.WithdrawMoney`, `C_Bank.DepositItem`, `C_Bank.AutoDepositItemsIntoBank` und `C_CurrencyInfo.RequestCurrencyFromAccountCharacter` verursachten "Taint"
- **Auswirkung**: ALLE geschützten UI-Aktionen wurden blockiert (Items benutzen, Reittiere erlernen, Bankfächer kaufen, etc.)
- **Fehlermeldung**: "AllforOne wurde geblockt. Die angeforderte Funktion ist der Blizzard-UI vorbehalten."
- **Lösung**: Alle direkten Hooks auf geschützte `C_Bank` und `C_CurrencyInfo` Funktionen entfernt
- **Neue Strategie**: Nur UI-basierte Blockierung (Tabs verstecken, Buttons verstecken, `hooksecurefunc` für sichere Post-Hooks)

#### Währungsüberweisung: Button ausblenden
- **Änderung**: `CurrencyTransferToggleButton` wird jetzt komplett versteckt statt nur blockiert
- **Grund**: PreClick/OnClick Hooks verhinderten nicht das Verschieben des Charakterfensters
- **Implementierung**: `transferButton:Hide()` + `OnShow` Hook um Button versteckt zu halten

#### Performance-Bug behoben: BetterBags Lag beim Looten
- **Problem**: `pairs(_G)` Iterationen in `GetBetterBagsFrames()` und `HideThirdPartyWarbandTabs()` wurden bei jedem `BAG_UPDATE_DELAYED` Event ausgeführt
- **Auswirkung**: Lag/Freeze beim Looten wenn BetterBags aktiv war (tausende globale Variablen wurden durchsucht)
- **Lösung**: 
  - `GetBetterBagsFrames()`: `_G` Iteration komplett entfernt, Frames werden jetzt gecacht
  - `HideThirdPartyWarbandTabs()`: Zwei `pairs(_G)` Iterationen entfernt, nutzt jetzt nur bekannte Frame-Namen

#### UI-Taint beim Bankfach kaufen behoben (zusätzlich)
- **Problem**: `BankFrame.TabSystem` Manipulationen verursachten Taint der `PurchaseBankTab()` blockierte
- **Lösung**: 
  - Alle direkten `Hide()` Aufrufe auf BankFrame-Elemente entfernt
  - Neuer Ansatz: Overlay-Frame + `SetAlpha(0)` um Tab unsichtbar zu machen ohne Taint
  - `hiddenAlphaTab` Variable speichert Referenz für Alpha-Wiederherstellung

#### Entfernungshämmer (Spell 460905) Blocking
- **Implementierung**: `UNIT_SPELLCAST_SUCCEEDED` Event-Handler für Spell ID 460905
- **Hinweis**: `SpellStopCasting()` ist geschützt und kann nicht verwendet werden
- **Fallback**: Bank wird sofort geschlossen wenn der Spell durchgeht

#### Gildenchat Scham-Feature
- **Neue Funktion**: `SendShameMessage(action, details)` - Sendet Scham-Nachricht in Custom-Channel (Default: `Schandelog`), Fallback: `GUILD`
- **Cooldown**: 5 Sekunden zwischen Nachrichten um Spam zu vermeiden
- **Aktionen**: `deposit_gold`, `withdraw_gold`, `deposit_item`, `withdraw_item`, `deposit_all`
- **Nachrichtenformat**: "Schande über mich! Ich habe [Item/Gold] entnommen/eingelagert!"

#### Schandelog Auto-Join
- **Neu**: `BR:EnsureShameChannelJoined()` versucht beim Login einmalig den Channel `Schandelog` (oder `ShameChannelName`) zu joinen
- **Trigger**: `PLAYER_LOGIN` mit Delay (5s)

#### Item-Tracking für Scham-Feature
- **Status**: Deaktiviert (zu unzuverlässig / False Positives)

#### Verstärkte Post-Hooks
- **Neu**: `hooksecurefunc(C_Bank, "WithdrawMoney")` - Erkennt Gold-Entnahme
- **Neu**: `hooksecurefunc(C_Bank, "AutoDepositItemsIntoBank")` - Erkennt Auto-Einlagerung
- **Alle Hooks**: Lösen jetzt Scham-Nachricht aus wenn Warbound-Bank betroffen

#### Third-Party Bank-Addon Deaktivierung
- **Neue Funktion**: `ForceBlizzardBankFrame()` - Versteckt alle Third-Party Bank-Frames
- **Unterstützte Addons**: Baganator, BetterBags, Bagnon, AdiBags, ArkInventory, Inventorian, Combuctor, ElvUI
- **Aufruf**: Bei `BANKFRAME_OPENED` und im Ticker alle 0.3 Sekunden
- **Grund**: 100% Warbound-Schutz durch Erzwingen des Standard-Blizzard-BankFrames
- **Benachrichtigung**: User wird informiert wenn Third-Party Frame versteckt wird

### Modules/AdminPanel.lua

#### Developer-Check entfernt
- **Grund**: Hash-basierter Developer-Check war nicht sicher da Code auf CurseForge öffentlich ist
- **Entfernt**: `SimpleHash()`, `DEVELOPER_HASHES`, `IsDeveloper()` Funktionen
- **Jetzt**: Nur Gildenoffiziere (Rang 0-1) haben Zugang zum AdminPanel

### Core.lua

#### Developer-Fallback entfernt
- **Entfernt**: Hardcoded Character-Name Check in `IsGuildOfficer()`

### AllforOne.toc

#### Addon-Kategorie
- **Hinzugefügt**: `## Category: Guild` für Blizzard Addon-Manager Kategorisierung

### Modules/DragonFlyingBlock.lua

#### Pfadfinder-basierte Himmelsreiten-Logik
- **Neue Konstanten**:
  - `PATHFINDER_CHECK_LEVEL = 70`: Level ab dem Pfadfinder-Check greift
  - `TWW_PATHFINDER_ACHIEVEMENT_ID = 40231`: The War Within Pathfinder Achievement
- **Neue Funktion**: `HasPathfinderAchievement()` - Prüft ob Spieler Achievement 40231 hat
- **Geänderte Logik in `ShouldBlock()`**:
  - Level < 70: Himmelsreiten immer blockiert (Statisches Fliegen erzwungen)
  - Level 70+, HAT Pfadfinder: Himmelsreiten blockiert (kann Statisch fliegen)
  - Level 70+, KEIN Pfadfinder: Himmelsreiten erlaubt (braucht es für TWW Content)
- **Grund**: Spieler ohne Pfadfinder können in Khaz Algar nur mit Himmelsreiten fliegen

### Modules/SecurityCheck.lua

#### Disconnect-Erkennung implementiert
- **Problem**: "Addon war deaktiviert" Meldung erschien fälschlicherweise nach einem DC
- **Lösung**: "Clean Logout" Flag implementiert
- **Neue Funktionen**:
  - `MarkCleanLogout()`: Setzt `charData.cleanLogout = true` bei `PLAYER_LEAVING_WORLD`/`PLAYER_LOGOUT`
  - `WasCleanLogout()`: Prüft ob letzter Logout sauber war
- **Logik**: Bei DC wird `PLAYER_LEAVING_WORLD` trotzdem aufgerufen wenn Addon aktiv war. Nur wenn Addon deaktiviert war, wird es NICHT aufgerufen.
- **Neues Event**: `PLAYER_LOGOUT` registriert

#### Pandaren Startgebiet Ausnahme
- **Problem**: Neutrale Pandaren (Level 1-10) können keiner Gilde beitreten
- **Lösung**: `UnitFactionGroup("player")` Check - wenn `nil` oder `"Neutral"`, wird SecurityCheck übersprungen

### Modules/DragonFlyingBlock.lua

#### Flugmeister (Taxi) Ausnahme
- **Problem**: Himmelsreiten-Warnung erschien beim Nutzen von Flugmeistern
- **Lösung**: `UnitOnTaxi("player")` Check in `CheckAndDismount()` und `CheckDruidFlightForm()`

#### Death Knight Startgebiet Ausnahme
- **Problem**: Scourge Gryphon im DK Startgebiet löste Himmelsreiten-Warnung aus
- **Lösung**: Neue Zonen in `EXCEPTION_ZONE_IDS`:
  - `4298`: Plaguelands: The Scarlet Enclave (DK Starting Zone)
  - `4281`: Acherus: The Ebon Hold (old)
  - `7679`: Acherus: The Ebon Hold (new)

#### Neue Quest-Ausnahmen
- **Quest IDs hinzugefügt**: 65120, 65133, 77345, 68799
- **Grund**: Diese Quests benötigen Himmelsreiten zum Abschließen

### Data/MailRewardNPCs.lua

#### Datenbank erweitert
- **Neue NPCs**:
  - `[203404]` Vaskarn (Zaralek Cavern / Valdrakken)
  - `[28930]` Dansel Adams (Plaguewood)
  - `[32842]` The WoW Dev Team / Das Entwicklerteam von WoW (System)
- **Struktur erweitert**: `names` Array für lokalisierte Namen
  ```lua
  names = {"the wow dev team", "das entwicklerteam von wow", ...}
  ```

#### MailBlock Integration
- **Geändert**: `BuildNPCWhitelist()` lädt jetzt alle Namen aus dem `names` Array

---

## [1.0.3] - 2026-01-29

### Modules/SecurityCheck.lua

#### Bug-Fix: Warnung erscheint nicht nach Addon-Reaktivierung
- **Problem**: Wenn `timeDiff > 3600` (1 Stunde), wurde es fälschlicherweise als "Multi-PC Szenario" behandelt und `wasDisabled` wurde nicht gesetzt
- **Lösung**: Multi-PC Erkennung verbessert - nur wenn `realTimePassed > timeDiff * 2` (Real-Time ist mehr als doppelt so groß wie /played Differenz)

#### Hinweis: DC vs Addon-Deaktivierung
- **Problem**: DC und "Addon deaktiviert" können technisch NICHT unterschieden werden
- **Grund**: In beiden Fällen ist `timeDiff ≈ realTimePassed`
- **Entscheidung**: Sicherheit geht vor Komfort - Warnung erscheint auch bei DCs
- **Aktuelle Logik in `CheckSessionStatus()`**:
  - Multi-PC Szenario: `realTimePassed > 86400` (> 24h) ODER `timeDiff > 3600 AND realTimePassed > timeDiff * 2` -> KEIN Alarm
  - Sonst: `timeDiff > INACTIVITY_THRESHOLD` -> ALARM (auch bei DC)

### Data/MailRewardNPCs.lua (NEU)

#### Mail Reward NPC Datenbank
- **Zweck**: NPCs die Quest-Belohnungen per Post verschicken, aber direktes Abholen erlauben
- **Struktur**: `BR.MailRewardNPCs[NPC_ID] = { name, zone, note }`
- **Initiale NPCs**:
  - `[84973]` Exarch Akama (Shadowmoon Valley)
  - `[87365]` Grakis (Stormshield)
- **Helper-Funktionen**:
  - `BR:IsMailRewardNPC(npcID)` - Prüft ob NPC in der Liste ist
  - `BR:GetMailRewardNPCInfo(npcID)` - Gibt NPC-Info zurück
  - `BR:PrintMailRewardNPCs()` - Debug-Ausgabe aller NPCs

### Modules/WarboundBlock.lua

#### Neu: Währungsüberweisung blockiert
- **Feature**: `CurrencyTransferMenu` (Warbound-Währungstransfer) wird jetzt blockiert
- **Implementierung**: Hook auf `OnShow` Event des `CurrencyTransferMenu` Frames
- **Lazy Loading**: Wartet auf `Blizzard_TokenUI` Addon-Load da das Frame on-demand geladen wird
- **Neue Funktionen**:
  - `BlockCurrencyTransfer()`: Versteckt das Menu und zeigt Warnung
  - `HookCurrencyTransferWhenReady()`: Registriert Hook wenn Blizzard_TokenUI geladen wird

### Modules/ChatFilter.lua

#### Bug-Fix: "Secret value" Fehler im Gildenchat
- **Problem**: WoW gibt manchmal geschützte "secret value" Werte als `message` Parameter zurück
- **Fehler**: `attempt to index local 'message' (a secret value)` in Zeile 91
- **Lösung**: `pcall` Wrapper um die message-Prüfung, um geschützte Werte sicher zu erkennen
- **Geänderte Logik in `AddMessage_Hook()`**:
  ```lua
  local success, result = pcall(function()
      if not message or type(message) ~= "string" then
          return nil
      end
      return message
  end)
  if not success or not result then
      return originalAddMessage[self](self, message, r, g, b, chatID, ...)
  end
  ```

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
