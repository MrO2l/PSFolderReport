function Show-FolderTree {
<#
.SYNOPSIS
    Zeigt einen Verzeichnisbaum mit Groessenangaben in der Konsole.
.DESCRIPTION
    Gibt eine farbige ASCII-Baumstruktur des angegebenen Verzeichnisses aus.
    Rot fuer Eintraege >= 1 GB, Gelb fuer >= 100 MB, Gruen fuer kleinere.
    Nicht zugaengliche Ordner werden Rot mit [Kein Zugriff] markiert.
    Eintraege werden pro Ebene nach Groesse absteigend sortiert.
    Mit -Debug werden Zugriffsverweigert-Meldungen und Pfadfehler ausgegeben.
.PARAMETER Path
    Startverzeichnis fuer die Baumdarstellung.
.PARAMETER Depth
    Maximale Anzahl anzuzeigender Ebenen unter dem Startpfad (Standard: 2).
.PARAMETER MaxItemsPerLevel
    Maximale Anzahl Eintraege pro Ebene (Standard: 10).
.EXAMPLE
    Show-FolderTree -Path 'C:\Users' -Depth 3
.EXAMPLE
    Show-FolderTree -Path $env:USERPROFILE -Depth 2 -MaxItemsPerLevel 5
.EXAMPLE
    Show-FolderTree -Path 'F:\' -Depth 2 -Debug
    # Zeigt zusaetzlich Debug-Meldungen fuer nicht zugaengliche Pfade
.NOTES
    Autor: PSFolderReport Developer
    Phase: 1
    Gibt keine Objekte zurueck – Ausgabe erfolgt direkt ueber Write-Host.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Farbige Konsolenausgabe ist der Zweck dieser Funktion')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter()]
        [ValidateRange(0, 20)]
        [int] $Depth = 2,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $MaxItemsPerLevel = 10
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Pfad nicht gefunden: $Path"
        return
    }

    $rootItem    = Get-Item -LiteralPath $Path
    $rootFiles   = Get-ChildItemLong -Path $Path -Recurse -FilesOnly
    $rootSizeSum = ($rootFiles | Measure-Object -Property Length -Sum).Sum
    $rootBytes   = if ($null -eq $rootSizeSum) { 0L } else { [long]$rootSizeSum }
    $rootLabel   = Format-FileSize -Bytes $rootBytes

    # Wurzel-Eintrag in Cyan ausgeben
    Write-Host ''
    Write-Host "$($rootItem.FullName)  [$rootLabel]" -ForegroundColor Cyan

    $treeParams = @{
        Path             = $Path
        MaxDepth         = $Depth
        MaxItemsPerLevel = $MaxItemsPerLevel
        IndentPrefix     = ''
        IsLastItem       = $true
        CurrentDepth     = 0
    }
    Write-FolderTree @treeParams

    Write-Host ''
}
