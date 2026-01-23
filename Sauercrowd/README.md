# Sauercrowd - WoW Hardcore Addon

Offizielles Addon für das Sauercrowd WoW HC Event

---

## 🎮 Hauptfunktionen

### 💀 Death Tracking & Announcements
Alle Tode werden in der Gilde geteilt und angezeigt.

**Features:**
- Automatische Benachrichtigung bei Gildentodesfällen
- Popup-Anzeige mit Todesdetails
- **Mini-Deathlog**: Kompaktes, resizable Fenster zeigt letzte Tode
  - Spalten: Name (40%), Klasse (40%), Level (20%)
  - Tooltip mit vollständigen Details inkl. letzten Worten
  - Optimierte Größe: 250x120 Minimum für minimalen Platzbedarf
- Anzeige von letzten Worten und Todesursache im Guild Chat
- **Dual-System für maximale Kompatibilität**:
  - Primär: Addon Messages (`CHAT_MSG_ADDON`)
  - Fallback: Guild Chat Parsing (funktioniert auch wenn andere Deathlog-Addons aktiv sind)
- **Keine Konflikte**: Kompatibel mit HardcoreUnlocked und Deathlog Addon

**Informationen die geteilt werden:**
- Name, Klasse, Level
- Zone des Todes
- Woran gestorben (falls im Kampf)
- Letzte Worte (letzte Chat-Nachricht vor dem Tod)

---

### 💬 Chat Features
**Guild Member Icons**: SC Icon-Präfix für alle Gildenmitglieder in allen Chat-Channels

**Features:**
- Funktioniert in: Guild, Say, Yell, Party, Raid, Whisper
- Hilft Griefer zu identifizieren die Gildenmitglieder imitieren
- Automatische Erkennung über GuildCache

---

### 🎯 Content Creator System
Streamer und Content Creators können sich identifizieren.

**Features:**
- **Twitch Handle Prompt**: Einmalige Abfrage beim ersten Login für Content Creator Identifikation
- **Account-Wide Storage**: Twitch/YouTube Handle wird account-weit gespeichert (alle Charaktere)
- **Automatische Guild Note**: Handle wird automatisch in die öffentliche Gildennotiz geschrieben
- **Tooltip Integration**: Content Creator Handles werden in Spieler-Tooltips angezeigt
- Format: "DeinHandle (Tode: X)"

**Einrichtung:**
Beim ersten Login erscheint automatisch ein Fenster. Gib einfach deinen Twitch oder YouTube Namen ein.

---

### 🛡️ Hardcore Rules Enforcement
Das Addon erzwingt automatisch die Hardcore-Regeln.

**Was wird blockiert:**
- ✉️ **Briefkasten** - Wird automatisch geschlossen
- 🏛️ **Auktionshaus** - Wird automatisch geschlossen
- 🤝 **Handel mit Nicht-Gildenmitgliedern** - Wird automatisch abgebrochen
- 👥 **Gruppen mit Nicht-Gildenmitgliedern** - Du wirst automatisch aus der Gruppe entfernt

**Wichtig:** Diese Blockaden sind still - keine nervigen Nachrichten!

---

### ⚔️ PvP-Warnsystem
Warnt wenn du PvP-aktivierte NPCs oder Spieler targetierst.

**Features:**
- Warnung bei Targeting von PvP-aktivierten NPCs und Spielern
- Visuelles Warning-Fenster mit Crossed-Swords Icon
- Optionaler Warnton
- Positioniert oben am Bildschirm für beste Sichtbarkeit

---

### 🎉 Levelbenachrichtigungen
Das Addon gratuliert automatisch bei wichtigen Level-Meilensteinen.

**Glückwünsche bei:**
- Level 10, 20, 30, 40, 50, 60

Gratulationen erscheinen automatisch im Gildenchat.

---

### 👁️ Tooltip Erweiterungen
Erweitert Tooltips mit nützlichen Informationen.

**Zeigt an:**
- Gildenrang
- Online-Status
- Content Creator Handles
- Zusätzliche Charakterinformationen

---

### 🗺️ Minimap Icon
Zentraler Zugriffspunkt für alle Funktionen.

**Funktionen:**
- **Linksklick:** Death Log anzeigen
- **Rechtsklick:** Offi-Fenster (nur für Offiziere mit Einlade-Rechten)

**Tooltip zeigt:**
- Addon Version
- Verfügbare Funktionen

---

### 🔧 Automatische Optimierungen
Das Addon optimiert einige Einstellungen automatisch.

**Was wird automatisch gemacht:**
- Verlassen von globalen Channels (Allgemein/Handel)
- Reduziert Spam und Ablenkungen
- Verbessert die Performance

---

## 📥 Installation

1. Download des Addons (siehe Root README für Build-Anleitung)
2. Entpacke den Ordner in `World of Warcraft\_classic_era_\Interface\AddOns\`
3. Starte WoW neu oder `/reload` in-game
4. Minimap-Icon erscheint für schnellen Zugriff auf alle Features

## 🎮 Befehle

- `/sdebug pvpframe` - PvP Warning Frame testen

## ⚙️ Einstellungen

Die meisten Funktionen laufen automatisch. Es gibt einige optionale Einstellungen über das Options-Menü.

## 💡 Tipps

1. **Death Log:** Linksklick auf Minimap Icon
2. **Content Creator:** Handle wird automatisch beim ersten Login abgefragt

## 📋 Technische Details

- **Interface-Version**: 11508 (WoW Classic Era 1.15.x)
- **SavedVariables**:
  - `SauercrowdOptionsDB` (per Character)
  - `SauercrowdTwitchHandles` (Account-wide)
- **Addon Message Prefixes**:
  - `Sauercrowd` (Death Announcements)
- **Libraries**:
  - LibStub
  - LibDataBroker-1.1
  - LibDBIcon-1.0

## ⚠️ Bekannte Einschränkungen

- **Guild Only**: Alle Features funktionieren nur mit Guild Members auf gleichem Realm

## 📝 Wichtige Hinweise

- Alle Blockaden (Briefkasten, AH, etc.) sind **still** - du bekommst keine Nachrichten
- Dein **Todeszähler** ist account-weit und wird in deiner Gildennotiz angezeigt
- Das Addon ist speziell für die **Sauercrowd Hardcore Gilde** entwickelt

## 🆘 Support & Feedback

Bei Problemen oder Feedback:
- Melde dich bei den Addon-Entwicklern in der Gilde
- Erstelle ein Issue auf GitHub

## 👥 Autoren

- Cricksu
- Pudi
- Canasterzaster

---

**Viel Erfolg und viel Glück - möge dein Hardcore-Charakter lange leben! 💀**
