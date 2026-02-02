# Changelog

Alle Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.4] - 2026-02-02

### Behoben
- **Kritischer Bug: UI-Taint behoben**: Inventar-Interaktionen (Items benutzen, Reittiere erlernen, Bankfächer kaufen) wurden fälschlicherweise blockiert
- **Performance-Bug mit BetterBags**: Lag/Freeze beim Looten behoben wenn BetterBags und AllforOne gleichzeitig aktiv waren
- **Entfernungshämmer blockiert**: Der Fernzugriff auf die Kriegsmeutenbank wird jetzt sofort geschlossen
- **Disconnect-Warnung**: "Addon war deaktiviert" Meldung erscheint nicht mehr nach einem Disconnect
- **Flugmeister-Bug**: Himmelsreiten-Warnung erscheint nicht mehr beim Nutzen von Flugmeistern (Taxi-Flüge)
- **Pandaren Startgebiet**: Sicherheitswarnung erscheint nicht mehr bei neutralen Pandaren (Level 1-10)
- **Death Knight Startgebiet**: Himmelsreiten-Warnung erscheint nicht mehr beim Scourge Gryphon
- **Post vom Kundensupport**: Mails vom Kundensupport/Kundendienst werden nicht mehr fälschlicherweise blockiert

### Neu
- **Scham-Feature (Schandelog-Channel)**: Wenn jemand trotz Block Gold in der Kriegsmeutenbank ein-/auszahlt, wird automatisch eine Nachricht im Channel "Schandelog" gepostet (falls vorhanden, sonst im Gildenchat)
- **Schandelog Auto-Join**: Der Channel "Schandelog" wird beim Login automatisch beigetreten (wenn möglich)

### Verbessert
- **Himmelsreiten-Sperre mit Pfadfinder**: Neue intelligente Logik für Himmelsreiten:
  - Level unter 70: Himmelsreiten immer blockiert (Statisches Fliegen erzwungen)
  - Level 70+: Spieler MIT "The War Within Pfadfinder" Achievement → Himmelsreiten blockiert
  - Level 70+: Spieler OHNE Pfadfinder → Himmelsreiten erlaubt (für Content benötigt)
- **Kriegsmeutenbank-Block verstärkt**: Zusätzliche Hooks für Gold Ein-/Auszahlung
- **Third-Party Bank-Addons deaktiviert**: Baganator, BetterBags, Bagnon, AdiBags, ElvUI etc. werden beim Öffnen der Bank versteckt - nur das Standard-Blizzard-BankFrame wird angezeigt für 100% Warbound-Schutz
- **Kriegsmeutenbank-Tab**: Der Tab wird jetzt unsichtbar gemacht statt mit einem Overlay verdeckt
- **Addon-Kategorie**: Das Addon erscheint jetzt unter "Guild" in der Blizzard Addon-Liste
- **Mail Reward NPC Datenbank erweitert**: Neue NPCs hinzugefügt (Vaskarn, Dansel Adams, Das Entwicklerteam von WoW)
- **Himmelsreiten Quest-Ausnahmen**: Weitere Quest IDs hinzugefügt die Himmelsreiten benötigen (65120, 65133, 77345, 68799)
- **Währungsüberweisung**: "Überweisen"-Button wird jetzt komplett ausgeblendet statt nur blockiert

---

## [1.0.3] - 2026-01-29

### Neu
- **Währungsüberweisung blockiert**: Warbound-Währungstransfer zwischen Charakteren wird jetzt blockiert (Abzeichen-Tab)
- **Mail Reward NPC Datenbank**: Liste von NPCs die Quest-Belohnungen per Post verschicken (Exarch Akama, Grakis)

### Verbessert
- **Himmelsreiten-Sperre**: Zonen-Ausnahmen hinzugefügt - Himmelsreiten ist jetzt in bestimmten Gebieten erlaubt (z.B. Dracthyr Startzone "Die Verbotene Reichweite")

### Behoben
- **Sicherheitswarnung**: Die Warnung erscheint jetzt korrekt wenn das Addon deaktiviert und wieder aktiviert wurde
- **Linux/Mac Installation**: Das Addon wird jetzt korrekt in den richtigen Unterordner entpackt (CurseForge)
- **Chat-Filter Fehler**: "Secret value" Fehler im Gildenchat behoben

---

## [1.0.2] - 2026-01-24

### Verbessert
- **Kriegsmeutenbank-Block für externe Addons**: 
  - BetterBags wird jetzt vollständig blockiert (Warband-Tabs werden versteckt)
  - Baganator wird jetzt vollständig blockiert (automatischer Wechsel zum Charakter-Tab)
- **Cross-Faction Gildenhandel**: Handel zwischen Horde und Allianz Gildenmitgliedern funktioniert jetzt korrekt
- **Gildenkarten Pin-Größe**: Standard-Größe ist jetzt 10px (vorher 16px)
- **Gildenkalender-Integration**: Der Gildentreffpunkt-Tooltip zeigt jetzt das nächste geplante Gildenmeeting an
- **Gildentreffpunkt auf Minimap**: Der Gildentreffpunkt wird jetzt auch auf der Minimap angezeigt
- **Himmelsreiten-Sperre**: Erkennt jetzt zuverlässig ob Statisches Fliegen oder Himmelsreiten aktiv ist

### Behoben
- **Tooltip "Keine Gilde" Bug**: Gildenmitglieder werden im Gruppen-Tooltip jetzt korrekt erkannt
- **UseContainerItem() Taint-Fehler**: Geschützte Funktionen werden jetzt korrekt verzögert aufgerufen
- **TooltipEnhance Fehler**: "Secret value" Fehler bei Unit-Tooltips behoben
- **Gildenleiter-Einstellungen beim Login**: Gildenmeister und Offiziere können jetzt direkt nach dem Einloggen ihre Einstellungen ändern
- **Gildenkarten Pin-Größe**: Pins werden jetzt auf allen Karten gleich groß angezeigt

### Geändert
- **Startnachrichten**: Nur noch Version und Hilfe-Hinweis beim Login
- **Motivations-Nachricht**: Neue Gildenmotivation beim Login
- **Status-Anfragen**: Nur noch für Offiziere und Gildenmeister sichtbar
- **Status-Sync**: Zählung zeigt jetzt korrekt alle Online-Mitglieder an

### Neu
- **Einstellungen zurücksetzen**: Neuer Button in den Addon-Optionen
- **Gildenkarte**: Zeigt die Positionen aller Gildenmitglieder auf der Weltkarte an

## [1.0.1] - 2026-01-17

### Hinzugefügt
- Initiale Release-Version
- Guild Check, Trade Block, Group Block, LFG Block Module
- Auction Block, Mail Block, Crafting Order Block, Warbound Block Module
- Admin Panel, Welcome Screen, Minimap Icon
- Security Check, Chat Filter, Tooltip Enhance Module
