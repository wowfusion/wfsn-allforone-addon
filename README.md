![AllforOne Banner](./AllforOne/media/banner-allforone.png)

# AllforOne Addon

WoW Guildfound Addon von wowfusion.de für Retail (Dragonflight+). Dieses Repository enthält den Addon-Code sowie Skripte zum Paketieren und Installieren.

## Voraussetzungen

- Windows mit PowerShell 5.1 oder neuer
- WoW Retail Installation (AddOn Pfad bekannt)

## Build (ZIP erstellen)

```powershell
# Standardausgabe: .\Releases
# Version wird aus AllforOne.toc gelesen
./build.ps1

# Optional: Version oder Ausgabeordner überschreiben
./build.ps1 -Version 1.0.2 -OutputDir "D:\Temp\Releases"
```

Das Skript liest die Versionsnummer aus der `AllforOne.toc` (oder nutzt `-Version`) und erstellt `AllforOne-<Version>.zip` im angegebenen Ordner.

## Installation ins WoW-Verzeichnis

```powershell
# Standard-WoW-Pfad: D:\Programme\World of Warcraft\_retail_\Interface\AddOns
./install.ps1

# Optional: Anderen WoW-Pfad oder Quelle verwenden
./install.ps1 -WoWPath "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns" -SourcePath "E:\Builds\AllforOne"
```

Das Skript entfernt ggf. alte Versionen im Zielordner und kopiert das Addon neu hinein.

## Mitwirken

Siehe [CONTRIBUTING.md](./CONTRIBUTING.md) für Hinweise zu Branches, Commits und Pull Requests.

## Releases

Fertige ZIPs liegen standardmäßig im Ordner `Releases`. Jede ZIP-Datei enthält den kompletten `AllforOne` Ordner und ist bereit für Curse/Wago oder manuelle Installation.
