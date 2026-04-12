function Get-FolderSizeData {
<#
.SYNOPSIS
    Berechnet Gesamtgroesse und Metadaten fuer ein Verzeichnis.
.DESCRIPTION
    Liest alle Dateien rekursiv ein und summiert Groesse, Anzahl sowie
    den juengsten Aenderungszeitstempel. Nutzt Get-ChildItemLong fuer
    Long-Path-Unterstuetzung.
.PARAMETER FolderPath
    Vollstaendiger Pfad des zu analysierenden Ordners.
.EXAMPLE
    Get-FolderSizeData -FolderPath 'C:\Windows'
.NOTES
    Private Hilfsfunktion – nicht exportiert.
    Gibt ein PSCustomObject mit SizeBytes, FileCount, FolderCount, LastModified zurueck.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FolderPath
    )

    $allFiles   = Get-ChildItemLong -Path $FolderPath -Recurse -FilesOnly
    $allFolders = Get-ChildItemLong -Path $FolderPath -Recurse -DirectoriesOnly

    $sizeSum        = ($allFiles | Measure-Object -Property Length -Sum).Sum
    $totalSizeBytes = if ($null -eq $sizeSum) { 0L } else { [long]$sizeSum }

    $newestFile   = $allFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    $lastModified = if ($null -ne $newestFile) { $newestFile.LastWriteTime } else { $null }

    return [PSCustomObject]@{
        SizeBytes   = $totalSizeBytes
        FileCount   = ($allFiles   | Measure-Object).Count
        FolderCount = ($allFolders | Measure-Object).Count
        LastModified = $lastModified
    }
}

function Add-FolderResult {
<#
.SYNOPSIS
    Liest Eintraege eines Verzeichnisses und fuegt sie der Ergebnisliste hinzu.
.DESCRIPTION
    Private Hilfsfunktion fuer Get-FolderSize. Verarbeitet ein Verzeichnis
    auf der angegebenen Tiefe. Ruft sich selbst rekursiv auf, wenn
    CurrentDepth < MaxDepth und das Element ein Unterordner ist.
.PARAMETER Path
    Zu scannender Verzeichnispfad.
.PARAMETER TotalRootBytes
    Gesamtgroesse des Scan-Wurzelverzeichnisses (fuer SizePercent-Berechnung).
.PARAMETER CurrentDepth
    Aktuelle Rekursionstiefe (0 = direkte Kinder des Scan-Roots).
.PARAMETER MaxDepth
    Maximale Listentiefe. 0 = nur direkte Kinder des Scan-Roots.
.PARAMETER MinSizeBytes
    Elemente unterhalb dieser Grenze werden uebersprungen.
.PARAMETER SearchPattern
    Suchmuster fuer Dateinamen (Standard: '*').
.PARAMETER Results
    Ergebnisliste, in die Eintraege geschrieben werden (Referenztyp).
.NOTES
    Private Hilfsfunktion – nicht exportiert.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [long] $TotalRootBytes,

        [Parameter(Mandatory = $true)]
        [int] $CurrentDepth,

        [Parameter(Mandatory = $true)]
        [int] $MaxDepth,

        [Parameter(Mandatory = $true)]
        [long] $MinSizeBytes,

        [Parameter(Mandatory = $true)]
        [string] $SearchPattern,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[PSCustomObject]] $Results
    )

    $children = Get-ChildItemLong -Path $Path -SearchPattern $SearchPattern

    foreach ($child in $children) {

        # Groesse und Metadaten ermitteln
        if ($child -is [System.IO.DirectoryInfo]) {
            $stats = Get-FolderSizeData -FolderPath $child.FullName
        }
        else {
            $stats = [PSCustomObject]@{
                SizeBytes   = $child.Length
                FileCount   = 1
                FolderCount = 0
                LastModified = $child.LastWriteTime
            }
        }

        if ($stats.SizeBytes -lt $MinSizeBytes) { continue }

        $sizePercent = if ($TotalRootBytes -gt 0) {
            [math]::Round(($stats.SizeBytes / $TotalRootBytes) * 100, 1)
        }
        else { 0.0 }

        $Results.Add([PSCustomObject]@{
            Name          = $child.Name
            FullPath      = Get-CleanPath -Path $child.FullName
            SizeBytes     = $stats.SizeBytes
            SizeFormatted = Format-FileSize -Bytes $stats.SizeBytes
            SizePercent   = $sizePercent
            FileCount     = $stats.FileCount
            FolderCount   = $stats.FolderCount
            LastModified  = $stats.LastModified
            Depth         = $CurrentDepth
            IsAccessible  = $true
            Extension     = $child.Extension
        })

        # Rekursiv in Unterordner gehen, wenn Tiefenlimit es erlaubt
        if ($child -is [System.IO.DirectoryInfo] -and $CurrentDepth -lt $MaxDepth) {
            $recursionParams = @{
                Path           = $child.FullName
                TotalRootBytes = $TotalRootBytes
                CurrentDepth   = $CurrentDepth + 1
                MaxDepth       = $MaxDepth
                MinSizeBytes   = $MinSizeBytes
                SearchPattern  = $SearchPattern
                Results        = $Results
            }
            Add-FolderResult @recursionParams
        }
    }
}
