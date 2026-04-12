function Write-FolderTree {
<#
.SYNOPSIS
    Gibt ein Verzeichnis rekursiv als farbige Baumstruktur in der Konsole aus.
.DESCRIPTION
    Zeigt Ordner und Dateien mit Einrueckung, Verbindungslinien und
    Groessenangaben.
    Farbcodierung (vollstaendig lesbare Ordner):
      Gruen  = kleiner 100 MB
      Gelb   = ab 100 MB
      Rot    = ab 1 GB
    Sonderfaelle:
      Weiss + (unvollst.) = Ordner teilweise nicht lesbar, Groesse unvollstaendig
      Rot   + [Kein Zugriff] = Ordner vollstaendig nicht zugaenglich
    Wird von Show-FolderTree aufgerufen.
.PARAMETER Path
    Vollstaendiger Pfad des darzustellenden Verzeichnisses.
.PARAMETER MaxDepth
    Maximale Anzahl Ebenen unter dem Startpfad (Standard: 2).
.PARAMETER MaxItemsPerLevel
    Maximale Eintraege pro Ebene, sortiert nach Groesse absteigend (Standard: 10).
.PARAMETER IndentPrefix
    Einrueckungsprefix fuer die aktuelle Ebene (wird intern befuellt).
.PARAMETER IsLastItem
    Gibt an, ob dieses Element das letzte in seiner Ebene ist (Einfluss auf Verbindungslinie).
.PARAMETER CurrentDepth
    Aktuelle Rekursionstiefe (intern verwendet).
.EXAMPLE
    Write-FolderTree -Path 'C:\Windows' -MaxDepth 2
.EXAMPLE
    Write-FolderTree -Path 'C:\Windows' -MaxDepth 2 -Debug
    # Zeigt Debug-Meldungen fuer nicht zugaengliche Pfade
.NOTES
    Private Hilfsfunktion – wird von Show-FolderTree aufgerufen.
    Verwendet Box-Drawing-Zeichen aus dem Unicode-Zeichensatz.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Farbige Konsolenausgabe ist der Zweck dieser Funktion')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter()]
        [int] $MaxDepth = 2,

        [Parameter()]
        [int] $MaxItemsPerLevel = 10,

        [Parameter()]
        [string] $IndentPrefix = '',

        [Parameter()]
        [bool] $IsLastItem = $true,

        [Parameter()]
        [int] $CurrentDepth = 0
    )

    # Box-Drawing-Zeichen als Unicode-Codepoints (ASCII-kompatible Quelldatei)
    $charBranch   = [char]0x251C + [char]0x2500 + [char]0x2500 + ' '  # ├──
    $charLast     = [char]0x2514 + [char]0x2500 + [char]0x2500 + ' '  # └──
    $charVertical = [char]0x2502 + '   '                               # │
    $charEmpty    = '    '

    # Verbindungslinie bereits hier bestimmen – wird auch im Fehlerfall benoetigt
    $branchChar = if ($IsLastItem) { $charLast } else { $charBranch }

    # Ordner-Item holen. Bestimmte Systempfade (z.B. \\?\-Pfade in $RECYCLE.BIN)
    # sind fuer Get-Item nicht erreichbar, obwohl sie existieren. In diesem Fall
    # den Ordner Rot mit [Kein Zugriff] kennzeichnen und abbrechen.
    $currentItem = $null
    try {
        if (-not [System.IO.Directory]::Exists($Path)) {
            Write-Debug "Pfad nicht gefunden: $Path"
            return
        }
        $currentItem = Get-Item -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        $folderName = [System.IO.Path]::GetFileName($Path.TrimEnd([char]'\', [char]'/'))
        if ([string]::IsNullOrEmpty($folderName)) { $folderName = $Path }
        Write-Host "$IndentPrefix$branchChar" -NoNewline
        Write-Host "$folderName  [Kein Zugriff]" -ForegroundColor Red
        Write-Debug "Fehler bei Get-Item '$Path': $($_.Exception.Message)"
        return
    }

    # Groesse berechnen; Zugriffsverweigert-Pfade in Liste sammeln
    $accessDenied = [System.Collections.Generic.List[string]]::new()
    $allFilesHere = Get-ChildItemLong -Path $Path -Recurse -FilesOnly -AccessDeniedPaths $accessDenied
    $sizeSum      = ($allFilesHere | Measure-Object -Property Length -Sum).Sum
    $sizeBytes    = if ($null -eq $sizeSum) { 0L } else { [long]$sizeSum }
    $sizeLabel    = Format-FileSize -Bytes $sizeBytes
    $hadPartialAccess = $accessDenied.Count -gt 0

    # Farbschwellen:
    #   Teilweise unlesbar  → Weiss  (Groesse unvollstaendig – keine Groessenschwellen-Farbe)
    #   Vollstaendig lesbar → Gruen / Gelb (>= 100 MB) / Rot (>= 1 GB)
    if ($hadPartialAccess) {
        $itemColor = 'White'
    }
    else {
        $itemColor = 'Green'
        if ($sizeBytes -ge 100MB) { $itemColor = 'Yellow' }
        if ($sizeBytes -ge 1GB)   { $itemColor = 'Red' }
    }

    # Verbindungslinie und Einrueckung ausgeben
    Write-Host "$IndentPrefix$branchChar" -NoNewline
    Write-Host $currentItem.Name -ForegroundColor $itemColor -NoNewline
    if ($hadPartialAccess) {
        Write-Host "  [$sizeLabel]" -NoNewline
        Write-Host '  (unvollst.)' -ForegroundColor DarkYellow
    }
    else {
        Write-Host "  [$sizeLabel]"
    }

    if ($CurrentDepth -ge $MaxDepth) { return }

    # Kinder laden und nach Groesse sortiert begrenzen
    $children = Get-ChildItemLong -Path $Path |
        Sort-Object -Property {
            if ($PSItem -is [System.IO.DirectoryInfo]) {
                $s = (Get-ChildItemLong -Path $PSItem.FullName -Recurse -FilesOnly |
                      Measure-Object -Property Length -Sum).Sum
                if ($null -eq $s) { 0L } else { [long]$s }
            }
            else { $PSItem.Length }
        } -Descending |
        Select-Object -First $MaxItemsPerLevel

    $nextIndent = $IndentPrefix + $(if ($IsLastItem) { $charEmpty } else { $charVertical })

    for ($childIndex = 0; $childIndex -lt $children.Count; $childIndex++) {
        $childItem     = $children[$childIndex]
        $childIsLast   = ($childIndex -eq $children.Count - 1)

        if ($childItem -is [System.IO.DirectoryInfo]) {
            $treeParams = @{
                Path             = $childItem.FullName
                MaxDepth         = $MaxDepth
                MaxItemsPerLevel = $MaxItemsPerLevel
                IndentPrefix     = $nextIndent
                IsLastItem       = $childIsLast
                CurrentDepth     = $CurrentDepth + 1
            }
            Write-FolderTree @treeParams
        }
        else {
            $fileSize   = Format-FileSize -Bytes $childItem.Length
            $fileBranch = if ($childIsLast) { $charLast } else { $charBranch }
            Write-Host "$nextIndent$fileBranch$($childItem.Name)  [$fileSize]" -ForegroundColor Gray
        }
    }
}
