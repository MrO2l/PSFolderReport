# PSFolderReport

PowerShell-Modul zur Speicherplatzanalyse unter Windows – eine CLI- und GUI-Alternative zu TreeSize.

Scannt Verzeichnisse rekursiv, berechnet Ordnergroessen, visualisiert Ergebnisse in der Konsole und exportiert Reports als CSV oder HTML. Eine WinForms-GUI steht ebenfalls zur Verfuegung.

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Schnellstart](#schnellstart)
- [Funktionen](#funktionen)
  - [Get-FolderSize](#get-foldersize)
  - [Show-FolderTree](#show-foldertree)
  - [Export-FsReport](#export-fsreport)
  - [Show-FolderSizeGui](#show-foldersizegui)
- [Beispiele](#beispiele)
- [Projektstruktur](#projektstruktur)

---

## Voraussetzungen

| Anforderung | Version |
|---|---|
| Windows PowerShell | 5.1 oder hoeher |
| PowerShell 7 (pwsh) | 7.x (empfohlen) |
| Windows | Windows 10 / Windows Server 2016 oder neuer |
| .NET / WinForms | Enthalten in Windows (fuer GUI-Cmdlet) |

---

## Installation

> **Wichtig – Verzeichnisstruktur verstehen**
>
> Das Repository enthaelt einen Unterordner `PSFolderReport\`, der das eigentliche Modul ist.
> PowerShell sucht Module nach dem Schema `<PSModulePath>\<ModulName>\<ModulName>.psd1`.
> Der **Elternordner des Repositories** (nicht der Modul-Unterordner selbst) muss im `PSModulePath` stehen.
>
> ```
> D:\Nextcloud\03_Ai\PSFolderReport\      <-- Elternordner (dieser Pfad kommt in PSModulePath)
>     PSFolderReport\                     <-- Modul-Ordner (Name muss dem Modul entsprechen)
>         PSFolderReport.psd1
>         PSFolderReport.psm1
>         Public\
>         Private\
> ```

---

### Option 1 – Direkt per Pfad laden (sofort, keine Konfiguration)

Der einfachste Weg: Modul direkt ueber den vollstaendigen `.psd1`-Pfad importieren.

```powershell
# Einmalig in der aktuellen Session:
Import-Module "D:\Nextcloud\03_Ai\PSFolderReport\PSFolderReport\PSFolderReport.psd1" -Force

# Pruefen ob das richtige Modul geladen ist (Version muss 1.0.0 sein):
Get-Module PSFolderReport
```

Erwartete Ausgabe:

```
ModuleType  Version  Name          ExportedCommands
----------  -------  ----          ----------------
Script      1.0.0    PSFolderReport  {Export-FsReport, Get-FolderSize, Show-FolderSizeGui, Show-FolderTree}
```

> **Falls eine andere Version angezeigt wird** (z.B. 1.7.3 mit nur `Get-FolderSize`), ist ein
> gleichnamiges Modul aus dem PSGallery bereits geladen. `-Force` loedt es neu:
>
> ```powershell
> Remove-Module PSFolderReport -Force -ErrorAction SilentlyContinue
> Import-Module "D:\Nextcloud\03_Ai\PSFolderReport\PSFolderReport\PSFolderReport.psd1" -Force
> ```

---

### Option 2 – PSModulePath dauerhaft einrichten (empfohlen)

Damit `Import-Module PSFolderReport` ohne vollstaendigen Pfad funktioniert, muss der
**Elternordner** des Modul-Verzeichnisses dauerhaft in das PowerShell-Profil eingetragen werden.

```powershell
# Schritt 1: Profil-Datei ermitteln (wird ggf. automatisch angelegt)
if (-not (Test-Path -Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}

# Schritt 2: Elternordner des Repositories eintragen
# Passe den Pfad auf deinen tatsaechlichen Speicherort an:
$repoParent = "D:\Nextcloud\03_Ai\PSFolderReport"

$profileEntry = "`nif (`$repoParent -notin (`$env:PSModulePath -split ';')) { `$env:PSModulePath += ';$repoParent' }"
Add-Content -Path $PROFILE -Value $profileEntry

# Schritt 3: Profil neu laden (oder PowerShell neu starten)
. $PROFILE
```

Danach steht das Modul in jeder neuen PowerShell-Session zur Verfuegung:

```powershell
Import-Module PSFolderReport
Get-Module PSFolderReport -ListAvailable
```

---

### Option 3 – Modul in Standard-Modulordner kopieren

Alternativ kann der Modul-Ordner in einen Pfad kopiert werden, der bereits im `PSModulePath` liegt.

```powershell
# Zielordner fuer PS7 (PowerShell 7 / pwsh):
$destination = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) `
                         -ChildPath 'PowerShell\Modules\PSFolderReport'

# Zielordner fuer PS5.1 (Windows PowerShell):
# $destination = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) `
#                          -ChildPath 'WindowsPowerShell\Modules\PSFolderReport'

# Modul-Unterordner (nicht das Repository-Root) kopieren:
Copy-Item -Path "D:\Nextcloud\03_Ai\PSFolderReport\PSFolderReport" -Destination $destination -Recurse -Force

# Danach direkt importierbar:
Import-Module PSFolderReport
Get-Module PSFolderReport -ListAvailable
```

---

### Abhaengigkeiten fuer Entwicklung und Tests

Fuer Pester-Tests und statische Code-Analyse werden folgende Module benoetigt:

```powershell
# Pester 5 (Testframework)
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force

# PSScriptAnalyzer (Linter)
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
```

---

## Schnellstart

```powershell
Import-Module PSFolderReport

# Groesste Ordner im Benutzerprofil anzeigen
Get-FolderSize -Path $env:USERPROFILE -Top 10 | Format-Table

# Verzeichnisbaum mit Farbcodierung
Show-FolderTree -Path $env:USERPROFILE -Depth 2

# HTML-Report erstellen und oeffnen
Get-FolderSize -Path C:\Windows | Export-FsReport -Format HTML -OutputPath "$env:TEMP\report.html" -Open

# Grafische Oberflaeche starten
Show-FolderSizeGui
```

---

## Funktionen

### Get-FolderSize

Kernfunktion des Moduls. Scannt ein oder mehrere Verzeichnisse rekursiv und gibt strukturierte Objekte zurueck, die durch die PowerShell-Pipeline weitergeleitet werden koennen.

**Syntax**

```powershell
Get-FolderSize
    -Path <string[]>
    [-Depth <int>]
    [-Top <int>]
    [-MinSizeBytes <long>]
    [-Filter <string>]
    [-FilesOnly]
    [-ShowBar]
```

**Parameter**

| Parameter | Typ | Standard | Beschreibung |
|---|---|---|---|
| `-Path` | String[] | (Pflicht) | Zu scannende Verzeichnisse. Pipeline-kompatibel. |
| `-Depth` | Int | `0` | Listtiefe: 0 = nur direkte Kinder, 1 = eine Ebene tiefer usw. |
| `-Top` | Int | `0` (alle) | Begrenzt Ausgabe auf die N groessten Eintraege. |
| `-MinSizeBytes` | Long | `0` | Filtert Eintraege unterhalb dieser Groesse (in Bytes). |
| `-Filter` | String | `*` | Suchmuster fuer Dateinamen, z.B. `*.log`. |
| `-FilesOnly` | Switch | — | Gibt nur Dateien aus, keine Ordner. |
| `-ShowBar` | Switch | — | Gibt zusaetzlich farbige ASCII-Balken auf der Konsole aus. |

**Rueckgabe-Eigenschaften**

| Eigenschaft | Typ | Beschreibung |
|---|---|---|
| `Name` | String | Ordner- oder Dateiname |
| `FullPath` | String | Vollstaendiger Pfad |
| `SizeBytes` | Long | Groesse in Bytes (rekursiv summiert) |
| `SizeFormatted` | String | Lesbare Groesse, z.B. `4.20 GB` |
| `SizePercent` | Double | Prozentualer Anteil am Scan-Root (0–100) |
| `FileCount` | Int | Anzahl enthaltener Dateien (rekursiv) |
| `FolderCount` | Int | Anzahl enthaltener Unterordner |
| `LastModified` | DateTime | Datum der juengsten Datei |
| `Depth` | Int | Verschachtelungstiefe relativ zum Startpfad |
| `IsAccessible` | Bool | `False` wenn Zugriff verweigert wurde |
| `Extension` | String | Dateiendung (leer bei Ordnern) |

**Beispiele**

```powershell
# Top 5 nach Groesse, mit ASCII-Balken
Get-FolderSize -Path C:\Users -Top 5 -ShowBar

# Nur .log-Dateien groesser als 10 MB
Get-FolderSize -Path C:\Windows\Logs -Filter '*.log' -MinSizeBytes 10MB -FilesOnly

# Mehrere Pfade via Pipeline
'C:\Windows', 'C:\Program Files' | Get-FolderSize -Top 5 | Sort-Object SizeBytes -Descending
```

---

### Show-FolderTree

Gibt eine farbig formatierte Baumstruktur mit Groessenangaben direkt in der Konsole aus.

**Farbcodierung**

| Farbe | Bedeutung |
|---|---|
| Gruen | Ordner kleiner als 100 MB (vollstaendig lesbar) |
| Gelb | Ordner ab 100 MB (vollstaendig lesbar) |
| Rot | Ordner ab 1 GB (vollstaendig lesbar) |
| Weiss + `(unvollst.)` | Ordner konnte nur teilweise gelesen werden – mindestens ein Unterordner war nicht zugaenglich, die Groessenangabe ist unvollstaendig |
| Rot + `[Kein Zugriff]` | Ordner vollstaendig nicht zugaenglich |
| Grau | Einzelne Dateien im Baum |
| Cyan | Wurzelverzeichnis (Startpfad) |

> **Hinweis:** Weiss/`(unvollst.)` zeigt an, dass die Groesse moeglicherweise kleiner ist als die
> tatsaechliche – der Ordner koennte also groesser als angezeigt sein. Mit `-Debug` werden
> alle nicht zugaenglichen Pfade als Debug-Meldungen ausgegeben.

**Syntax**

```powershell
Show-FolderTree
    -Path <string>
    [-Depth <int>]
    [-MaxItemsPerLevel <int>]
    [-Debug]
```

**Parameter**

| Parameter | Typ | Standard | Beschreibung |
|---|---|---|---|
| `-Path` | String | (Pflicht) | Startverzeichnis fuer die Baumdarstellung. |
| `-Depth` | Int | `2` | Maximale Anzahl anzuzeigender Ebenen. |
| `-MaxItemsPerLevel` | Int | `10` | Maximale Eintraege pro Ebene (nach Groesse sortiert). |
| `-Debug` | Switch | — | Gibt Debug-Meldungen fuer alle nicht zugaenglichen Pfade aus. |

**Beispiel**

```
F:\  [3,87 KB]
└── F:\  [3,87 KB]
    ├── Epic Games  [1,45 GB]
    │   ├── Launcher  [1,45 GB]
    │   └── DirectXRedist  [4,13 MB]
    ├── SomeLockedFolder  [240 MB]  (unvollst.)
    ├── $RECYCLE.BIN  [Kein Zugriff]
    └── System Volume Information  [Kein Zugriff]
```

```powershell
# Baumdarstellung mit 3 Ebenen
Show-FolderTree -Path $env:USERPROFILE -Depth 3 -MaxItemsPerLevel 5

# Mit Debug-Ausgabe fuer Zugriffsprobleme
Show-FolderTree -Path 'F:\' -Depth 2 -Debug
```

---

### Export-FsReport

Exportiert `Get-FolderSize`-Ergebnisse als CSV-Datei oder als offline-faehigen HTML-Report mit CSS-Balkenvisualisierung.

**Syntax**

```powershell
Export-FsReport
    -InputObject <PSCustomObject[]>
    -Format <'CSV' | 'HTML'>
    -OutputPath <string>
    [-Title <string>]
    [-ScannedPath <string>]
    [-Open]
```

**Parameter**

| Parameter | Typ | Standard | Beschreibung |
|---|---|---|---|
| `-InputObject` | PSCustomObject[] | (Pflicht, Pipeline) | Ergebnisse aus `Get-FolderSize`. |
| `-Format` | String | (Pflicht) | `CSV` oder `HTML`. |
| `-OutputPath` | String | (Pflicht) | Zieldateipfad. |
| `-Title` | String | `PSFolderReport Report` | Titel des HTML-Reports. |
| `-ScannedPath` | String | — | Wird als Metainfo im HTML-Report angezeigt. |
| `-Open` | Switch | — | Oeffnet die erzeugte Datei nach dem Schreiben. |

**HTML-Report-Merkmale**

- Vollstaendig offline – keine externen Bibliotheken oder CDN-Abhaengigkeiten
- Farbcodierte CSS-Balken: Rot >= 1 GB, Gelb >= 100 MB, Gruen sonst
- Tabelle mit Name, Groesse, Anteil, Dateianzahl, letztem Aenderungsdatum
- Sonderzeichen werden HTML-kodiert (XSS-sicher)

**Beispiele**

```powershell
# CSV-Export
Get-FolderSize -Path C:\Projects | Export-FsReport -Format CSV -OutputPath C:\report.csv

# HTML-Report erstellen und direkt im Browser oeffnen
Get-FolderSize -Path C:\Windows -Top 20 |
    Export-FsReport -Format HTML -OutputPath "$env:TEMP\windows.html" -ScannedPath C:\Windows -Open
```

---

### Show-FolderSizeGui

Oeffnet eine grafische WinForms-Oberflaeche mit Ordner-Scan, Ergebnisdarstellung und Export-Funktionen.

**Syntax**

```powershell
Show-FolderSizeGui [-StartPath <string>]
```

**Parameter**

| Parameter | Typ | Standard | Beschreibung |
|---|---|---|---|
| `-StartPath` | String | `$env:USERPROFILE` | Voreingestellter Pfad im Pfadeingabefeld. |

**Funktionen der GUI**

| Element | Beschreibung |
|---|---|
| Pfadeingabe + `...`-Button | Verzeichnis manuell eingeben oder per Dialog auswaehlen |
| `Scannen`-Button | Startet den Scan und befuellt TreeView und ListView |
| TreeView (links) | Zeigt Ordnerhierarchie des Scan-Ergebnisses |
| ListView (rechts) | Detailansicht: Name, Groesse, Anteil, Dateien, Aenderungsdatum |
| Farbcodierung | Rot >= 1 GB, Gelb >= 100 MB in der ListView |
| `CSV`-Button | Oeffnet Speichern-Dialog und exportiert als CSV |
| `HTML`-Button | Oeffnet Speichern-Dialog, exportiert HTML und oeffnet Browser |
| Statusleiste | Zeigt Scan-Status, Ergebnisanzahl und Gesamtgroesse |

```powershell
# GUI mit vordefiniertem Startpfad starten
Show-FolderSizeGui -StartPath 'C:\Projects'
```

---

## Beispiele

### Speicherplatz-Report fuer einen Server-Freigabe

```powershell
Import-Module PSFolderReport

# Top 20 Ordner nach Groesse
$results = Get-FolderSize -Path '\\server\freigabe' -Top 20

# In der Konsole anzeigen
$results | Format-Table -AutoSize

# Als HTML-Report speichern
$results | Export-FsReport -Format HTML -OutputPath 'C:\Reports\server.html' -ScannedPath '\\server\freigabe' -Open
```

### Grosse Log-Dateien finden und auflisten

```powershell
Get-FolderSize -Path C:\Windows\Logs -Filter '*.log' -MinSizeBytes 1MB -FilesOnly |
    Format-Table Name, SizeFormatted, LastModified -AutoSize
```

### Mehrere Laufwerke vergleichen

```powershell
'C:\', 'D:\' | Get-FolderSize -Top 5 | Sort-Object SizeBytes -Descending | Format-Table
```

### ASCII-Balken in der Konsole

```powershell
Get-FolderSize -Path $env:USERPROFILE -Top 10 -ShowBar
```

Beispielausgabe:

```
AppData                         ████████████████████████████████████████    8.20 GB   65.9%
Documents                       █████████████████████                        3.80 GB   30.5%
Downloads                       ████                                         0.45 GB    3.6%
```

---

## Projektstruktur

```
PSFolderReport/
├── PSFolderReport.psd1          # Modul-Manifest (Version, Metadaten, Exports)
├── PSFolderReport.psm1          # Loader: dot-sourcet Public/ und Private/
├── Public/                    # Exportierte Cmdlets
│   ├── Get-FolderSize.ps1
│   ├── Show-FolderTree.ps1
│   ├── Export-FsReport.ps1
│   └── Show-FolderSizeGui.ps1
├── Private/                   # Interne Hilfsfunktionen (nicht exportiert)
│   ├── Format-FileSize.ps1
│   ├── Format-CliBar.ps1
│   ├── Format-CliTree.ps1
│   ├── Get-LongPath.ps1
│   ├── Get-FolderSizeData.ps1
│   └── New-HtmlQuickReport.ps1
├── Templates/                 # Vorlagen (Phase 2+)
└── Tests/
    ├── pester.config.ps1
    ├── Invoke-Tests.ps1
    ├── PSFolderReport.Module.Tests.ps1
    ├── Get-FolderSize.Tests.ps1
    ├── Show-FolderTree.Tests.ps1
    ├── Export-FsReport.Tests.ps1
    ├── LongPath.Tests.ps1
    └── Show-FolderSizeGui.Tests.ps1
```

---

## Tests ausfuehren

```powershell
& ".\PSFolderReport\Tests\Invoke-Tests.ps1"
```

Aktueller Stand: **42 Tests, alle gruen. 0 PSScriptAnalyzer-Warnungen.**

---

## Bekannte Einschraenkungen (Phase 1)

- `Show-FolderSizeGui` erfordert eine Windows-Umgebung mit grafischer Oberflaeche (kein Headless/SSH)
- Netzwerkpfade koennen bei sehr grossen Freigaben langsam sein (Multithreading folgt in Phase 2)
- Der HTML-Report enthaelt keine interaktive Treemap (folgt in Phase 2 via D3.js)
- Excel-Export (`*.xlsx`) ist noch nicht implementiert (Phase 2)

---

## Versionsverlauf

| Version | Phase | Inhalt |
|---|---|---|
| `0.1.0` | Phase 0 | Modulgeruest, Manifest, Loader, Pester-Infrastruktur |
| `1.0.0` | Phase 1 | Get-FolderSize, Show-FolderTree, Export-FsReport, Show-FolderSizeGui, Long-Path-Unterstuetzung |

---

## Lizenz

(c) PSFolderReport Developer. All rights reserved.
