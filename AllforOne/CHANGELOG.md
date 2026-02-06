# Changelog

Alle Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.5] - 2026-02-06

### Behoben
- **Kriegsmeutenbank Item-Anzeige**: Items werden jetzt korrekt einzeln mit Links aufgelistet (bis zu 4 verschiedene), statt fälschlicherweise als Zusammenfassung angezeigt zu werden
- **Sicherheitscheck**: Logik wurde vereinfacht und durch ALT+F4 sowie Spiel verlassen wurde die Warnung fälschlicherweise getriggert.
### Verbessert
- **Mail-Whitelist erweitert**: Neue NPCs zur Whitelist hinzugefügt
- **Scham-Nachrichten**: Spieler können jetzt individuell zwischen "Schande" und "Sensibel"-Nachrichten wählen (Einstellung in den lokalen Optionen)

---

## [1.0.4] - 2026-02-04

### Behoben
- **UI-Taint behoben**: Inventar-Interaktionen (Items benutzen, Reittiere erlernen, Bankfächer kaufen) wurden fälschlicherweise blockiert
- **Performance-Problem behoben**: Massive Lag-Spikes beim Öffnen der Bank wurden behoben
- **Addon war Deaktiviert**: Meldung erscheint nicht mehr fälschlicherweise nach einem Disconnect
- **Flugmeister-Bug**: Himmelsreiten-Warnung erscheint nicht mehr beim Nutzen von Flugmeistern
- **Startgebiete**: Sicherheitswarnung erscheint nicht mehr bei neutralen Pandaren (da kein Reset ohne Gilde möglich ist)
- **Tutorial-Insel**: Im Abschluss-Dungeon wird man nicht mehr aus der Gruppe entfernt
- **Post vom Kundensupport**: Mails vom Kundensupport werden nicht mehr fälschlicherweise blockiert
- **Diverse kleinere fehler behoben** wie z.B. Lua Error in Dungeons usw.

### Neu
- **Scham-Feature für Kriegsmeutenbank**: Automatische Gildenchat-Nachricht wenn jemand Gold oder Items ein-/auslagert
  - Items werden als klickbare Links angezeigt
  - Mehrere Items werden zusammengefasst (z.B. bei schnellem Einlagern)
- **Offizier-Tools im Admin-Panel**:
  - Security-Info Button: Detaillierte Sicherheitsinformationen eines Spielers abrufen
  - Reset-Counter: Zeigt wie oft eine Warnung zurückgesetzt wurde
  - Update-Hinweis: Spieler per Whisper zur Addon-Aktualisierung auffordern
  - Temporäre Flug-Freischaltung: Himmelsreiten für einzelne Spieler temporär freischalten

### Verbessert
- **Addon-Kategorie**: Das Addon erscheint jetzt unter "Wowfusion" in der Blizzard Addon-Liste
- **Mail-Whitelist erweitert**: Neue NPCs hinzugefügt (Vaskarn, Dansel Adams, Entwicklerteam, Thaumaturg Vashreen)
- **Währungsüberweisung**: "Überweisen"-Button wird jetzt komplett ausgeblendet

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
