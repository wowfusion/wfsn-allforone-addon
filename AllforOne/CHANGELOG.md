# Changelog

Alle Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

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
