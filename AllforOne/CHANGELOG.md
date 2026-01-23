# Changelog
EileMarc ist der neue Entwickler
Alle Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.3] - 2026-01-22

### Neu
- **Gildentreffpunkt auf Minimap**: Der Gildentreffpunkt wird jetzt auch auf der Minimap angezeigt
  - Verwendet HereBeDragons Library für korrekte Positionierung
  - Icon bleibt am Rand sichtbar wenn außerhalb des Minimap-Bereichs
  - Unterstützt Minimap-Rotation
- **Einstellungen zurücksetzen**: Neuer Button in den Addon-Optionen
  - Setzt alle Einstellungen auf Standardwerte zurück
  - Synchronisiert automatisch mit Gildenmeister/Offizier wenn online

### Verbessert
- **Erweiterte Einstellungs-Verschlüsselung**: Zusätzliche Schutzmaßnahmen
  - Briefkasten-Modus wird jetzt ebenfalls verschlüsselt
  - Spielzeit-Daten (totalTimePlayed) sind geschützt
  - Geschützte Variablen werden sortiert gespeichert
- **Gildentreffpunkt Icon**: Neues verbessertes Icon (icon2-allforone)

### Behoben
- Minimap-Pin für Gildentreffpunkt bewegt sich nicht mehr mit dem Spieler
- Korrektes Icon für Gildentreffpunkt auf Welt- und Minikarte

## [1.0.2] - 2026-01-17

### Neu
- **Gildenkarte**: Zeigt die Positionen aller Gildenmitglieder auf der Weltkarte an
  - Automatische Synchronisation der Positionen alle 5 Sekunden
  - Farbige Punkte in Klassenfarben für bessere Übersicht
  - Tooltip mit Name, Level und Zone beim Überfahren
  - Rechtsklick auf Pin öffnet Flüster-Chat
  - Pins werden immer über dem eigenen Spielerpfeil angezeigt
  - **Pin-Größe einstellbar** in den Optionen (16-64 Pixel)

### Sonstige Änderungen:
- Briefkasten-Modus kann jetzt zwischen "Komplett blockieren" und "Nur Fremde blockieren" umgestellt werden
- Kriegsmeutenbank wird jetzt vollständig blockiert (Tab wird ausgeblendet)
- Unterstützung für Baganator und andere Taschen-Addons bei der Kriegsmeutenbank-Blockierung
- **Himmelsreiten-Sperre**: Aufmounten wird blockiert wenn "Flugstil: Himmelsreiten" aktiv ist (bis Max-Level)
  - Erkennung basiert auf Buff-IDs (Himmelsreiten: 404464, Statisch: 404468)
  - Button zum direkten Wechsel auf statisches Fliegen im Popup
  - Ausnahmen für Drachenreit-Quests und Rennen
- Popup-Meldungen werden jetzt länger angezeigt (+2 Sekunden)
- Gruppeneinladungen: NPCs (Quest-Begleiter) sind jetzt in Gruppen erlaubt

### Verbessert
- Neues, übersichtlicheres Einstellungsfenster
- Dungeonsuche funktioniert jetzt im Tutorial-Gebiet (Insel der Verbannten)
- Einstellungen werden schneller zwischen Gildenmitgliedern synchronisiert

### Behoben
- Lokale Einstellungen (Töne, Willkommensbildschirm) werden jetzt korrekt gespeichert
- Kriegsmeutenbank: Items können nicht mehr per Rechtsklick eingelagert werden
- Post vom Handwerkerkonsortium / Artisan's Consortium wird trotz Block aktiv zugestellt
- Willkommensbildschirm: URL-Kopie-Dialog funktioniert wieder zuverlässig

## [1.0.1] - 2026-01-17

### Hinzugefügt
- Initiale Release-Version
- Guild Check Modul
- Trade Block Modul
- Group Block Modul
- LFG Block Modul
- Auction Block Modul
- Mail Block Modul
- Crafting Order Block Modul
- Warbound Block Modul
- Admin Panel
- Welcome Screen
- Minimap Icon
- Security Check Modul
- Chat Filter Modul
- Tooltip Enhance Modul

### Geändert
- Keine

### Behoben
- Keine
