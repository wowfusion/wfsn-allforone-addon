# 1.0.2

## Neue Features
- Post-Icon an der Minimap versteckt (funktioniert ggf. nur beim Default UI)

# 1.0.0

## Neue Features

### Chat Filter System
- **Guild Member Icons**: SC Icon wird automatisch vor Gildenmitglieder-Namen in allen Chat-Channels angezeigt
  - Unterstützt: Guild, Say, Yell, Party, Raid, Whisper (incoming/outgoing)
  - Hilft Griefer zu identifizieren die versuchen Gildenmitglieder zu imitieren
  - Nutzt GuildCache für effiziente Member-Prüfung
  - Funktioniert mit deutschen und englischen Client-Sprachen

### Deathlog Verbesserungen
- **Kompakteres Design**:
  - Minimale Größe: 250x120 (vorher 350x175)
  - Reduzierte Paddings und Zeilenhöhen
  - Kleinere Icons und Header
- **Optimierte Spalten**: Name 40%, Klasse 40%, Level 20% (vorher 55/30/15)
- **Dual-System für Kompatibilität**:
  - Primär: Addon Messages via `CHAT_MSG_ADDON`
  - Fallback: Guild Chat Parsing
  - Verhindert Konflikte mit HardcoreUnlocked und Deathlog Addon
- **Intelligente Duplikatserkennung**: Prüft letzte 10 Einträge um Doppelungen zu vermeiden

## Bugfixes

- **Deathlog Compatibility**: Behebt Nicht-Aktualisierung wenn andere Deathlog-Addons (z.B. "Deathlog" von CurseForge) parallel laufen
- **Guild Chat Fallback**: Parst nun Guild Chat Messages als Backup wenn Addon Messages blockiert werden

## Code-Qualität

- **ChatFilter.lua**: Neue dedizierte Datei (75 Zeilen)
  - Hooks `ChatFrame.AddMessage` für alle Chat-Frames
  - Pattern-Matching für verschiedene Chat-Formate
  - Effiziente Gildenmitglieder-Prüfung
- **Death.lua**: Guild Chat Fallback Handler hinzugefügt
  - Regex-Pattern für deutsche Death Messages
  - Duplikatsprüfung gegen letzte 10 Einträge
  - Extraktion von Last Words aus Chat

## Technisch

- Neue Dateien: `ChatFilter.lua`
- TOC Update: ChatFilter in Features-Sektion
- Main.lua: ChatFilter-Initialisierung hinzugefügt
- SavedVariables: Keine neuen (nutzt existierende SauercrowdOptionsDB)

---

# 0.9.2

## Neue Features

### Content Creator System
- **Twitch Handle Prompt**: Einmalige Abfrage beim ersten Login für Content Creator Identifikation
- **Account-Wide Storage**: Twitch/YouTube Handle wird account-weit gespeichert (alle Charaktere)
- **Automatische Guild Note**: Handle wird automatisch in die öffentliche Gildennotiz geschrieben
- **Tooltip Integration**: Content Creator Handles werden in Spieler-Tooltips angezeigt

## Verbesserungen

### PvP Warning Frame
- **Visuelle Konsistenz**: Frame nutzt jetzt einheitliches Backdrop-Design wie alle anderen Fenster
- **Crossed Swords Icon**: Neues visuelles Icon für bessere Erkennbarkeit
- **Optimierte Position**: Frame erscheint oben am Bildschirm (nähe Target Frames) für bessere Sichtbarkeit im Kampf
- **Reduzierter Rumble**: Shake-Effekt von 0.3s/±4px auf 0.2s/±2px reduziert für weniger Ablenkung
- **Zentriertes Layout**: Icon, Titel und Name sind vertikal zentriert
- **Timer Leak Fix**: Behebt Memory Leak durch korrekte Timer-Verwaltung
- **Position Persistence**: Rumble-Animation respektiert jetzt vom Spieler verschobene Frame-Positionen

### Code-Qualität
- **TwitchHandlePrompt**: Code von 167 auf 156 Zeilen reduziert
  - Konsolidierte Speicher-Logik
  - Vereinfachte nil-Checks
  - Lokale Frame-Erstellung mit file-level Variable
- **PvPFrame**: Verbesserte Modul-Architektur
  - Lazy Frame Creation (kein frühes Init mehr)
  - Saubere Trennung mit `Sauercrowd.PvP` Table
  - Cancellable Timer mit korrekter Cleanup-Logik
- **Input Handling**: EditBox mit korrekten Text-Insets (10px) für bessere Lesbarkeit

### Debugging
- **PvP Frame Test**: Neuer `/sdebug pvpframe` Befehl zum Testen der PvP-Warnung mit Zufallsdaten

## Bugfixes

- **Twitch Prompt Init**: Behebt "InitializeTwitchHandlePrompt is nil" Fehler durch Entfernung von local shadowing
- **Guild Note Silent Mode**: Verhindert unnötige Fehlermeldungen bei automatischen Updates auf neuen Charakteren
- **Escape Key Crash**: Entfernt problematischen OnEscapePressed Handler
- **Text Clipping**: Behebt Input-Field Text-Offset Problem
- **Rumble Position Bug**: Frame kehrt nach Rumble-Animation zur korrekten Position zurück

## Technisch

- SavedVariables: `SauercrowdTwitchHandles` (account-wide)
- Neue Dateien: `interfaces/TwitchHandlePrompt.lua`, `Tooltip.lua`
- Guild Note API: Nutzt `GuildRosterSetPublicNote()` mit 2-Sekunden Delay für Roster-Loading
- EventManager Integration: PLAYER_ENTERING_WORLD für Prompt, PLAYER_TARGET_CHANGED für PvP

---

# 0.8.0

## Verbesserungen

### Code-Qualität
- Vereinfacht: Auction House Blockierung nutzt jetzt nur Frame Hook (robuster)
- Bereinigt: Auskommentierter Debug-Code in DeathAnnouncement.lua entfernt
- Konsistenz: API-Aufrufe verwenden durchgehend moderne C_* Namespaces
- Vereinfacht: Rules.lua Gruppenprüfung nutzt bewährte, getestete Implementierung

### Debugging
- Hinzugefügt: Umfangreiches Debug-Logging für Gruppenprüfungen (mit `/godbg on` aktivierbar)
- Hinzugefügt: Cache-Statistiken und Validierungslogs in GuildCache
- Entfernt: Überflüssiges Debug-Logging nach Bugfixes

## Architektur

### GuildCache
- Cache wird jetzt nur noch für UI-Performance verwendet (Inaktivitätsliste)
- Rules-System nutzt direkte API-Aufrufe für Echtzeit-Validierung
- Vereinfachte Event-Handler ohne redundante `RequestUpdate()` Aufrufe
- Cache-Aktualisierung nur noch bei tatsächlichem `GUILD_ROSTER_UPDATE` Event

### Performance
- Gruppenprüfungen sind jetzt synchron und zuverlässig
- Auction House Blockierung funktioniert auch bei Blizzard-Fehlern
- Keine Race Conditions mehr durch vereinfachte Cache-Logik

## Bekannte Einschränkungen

- GuildCache wird nicht mehr für Rules verwendet (bewusste Designentscheidung für Zuverlässigkeit)
- Debug-Logging kann bei aktiviertem Debug-Modus verbose sein

## Technisch

- Alle kritischen Bugs aus der Codebase-Prüfung behoben
- Code-Qualität: B+ (zuvor: C mit kritischen Bugs)
- Keine deprecated API-Aufrufe
- Interface-Version 11508 (WoW Classic Era 1.15.x)

---

# 0.0.5

## Architektur-Überarbeitung

- **EventManager**: Zentralisiertes Event-Handling mit Prioritätssystem und Fehler-Isolation
- **Constants**: Alle Konfigurationswerte und Magic Numbers in eine Datei ausgelagert
- **GuildCache**: Performance-Optimierung mit 60-Sekunden Cache für Gildenlisten-Abfragen (95% Reduktion der API-Aufrufe)
- **Debug-Tools**: Neue Debug-Befehle für Entwickler (`/schlingeldebug`)
- **MiniMapIcon**: Minimap-Icon-Code in separate Datei ausgelagert für bessere Code-Organisation

## Refactoring

- Death.lua: Umstellung auf EventManager-Pattern
- Rules.lua: Nutzt jetzt EventManager und GuildCache
- LevelUp.lua: Verwendet EventManager und Constants
- PvPFrame.lua: Nutzt EventManager und Constants für Alerts
- OffiInterface.lua: Verwendet GuildCache für optimierte Performance
- Main.lua: EventManager-first Initialisierung
- Global.lua: Aufgeräumt, nur noch Kern-Funktionen

## Performance

- Gilden-Roster API-Aufrufe um 95% reduziert durch Caching
- Zentralisiertes Event-Handling verhindert redundante Event-Frames
- Fehler-Isolation durch pcall() in allen Event-Handlern

## Technisch

- Interface-Version auf 11508 aktualisiert
- TOC-Datei reorganisiert mit klaren Sektionen
- Alle hardcodierten Werte in Constants.lua verschoben

# 0.0.1

- Implementing basic rules enforcement for new guild. Also removing all the extra stuff from Schlingel Inc.