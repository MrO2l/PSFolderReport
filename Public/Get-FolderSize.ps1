function Get-FolderSize {
<#
.SYNOPSIS
    Scannt ein Verzeichnis und gibt Groesse, Dateianzahl und Metadaten zurueck.
.DESCRIPTION
    Liest den Inhalt eines Verzeichnisses rekursiv ein und gibt fuer jeden
    direkten Kindelement ein strukturiertes PSCustomObject zurueck.
    Groessen beinhalten alle verschachtelten Inhalte.
    Unzugaengliche Unterordner erzeugen ein Warning, keinen Abbruch.
    Unterstuetzt Pfade ueber 260 Zeichen via Extended-Length-Prefix.
.PARAMETER Path
    Ein oder mehrere zu scannende Verzeichnispfade. Akzeptiert Pipeline-Eingabe.
.PARAMETER Depth
    Listtiefe: 0 = nur direkte Kinder (Standard), hoeherer Wert = mehr Ebenen.
    Die Groessenberechnung ist immer vollstaendig rekursiv.
.PARAMETER Top
    Begrenzt die Ausgabe auf die N groessten Eintraege (0 = alle).
.PARAMETER MinSizeBytes
    Filtert Eintraege, die kleiner als dieser Wert in Bytes sind.
.PARAMETER Filter
    Suchmuster fuer Dateinamen (Standard: '*' = alle Dateien).
.PARAMETER FilesOnly
    Wenn angegeben, werden nur Dateien (keine Ordner) aufgelistet.
.PARAMETER ShowBar
    Wenn angegeben, wird fuer jeden Eintrag ein ASCII-Balken ausgegeben.
.EXAMPLE
    Get-FolderSize -Path 'C:\Users' | Format-Table
.EXAMPLE
    Get-FolderSize -Path $env:USERPROFILE -Top 10 -ShowBar
.EXAMPLE
    Get-FolderSize -Path 'C:\Projects' -MinSizeBytes 1MB -Depth 1
.NOTES
    Autor: PSFolderReport Developer
    Phase: 1
    Rueckgabe: PSCustomObject mit Name, FullPath, SizeBytes, SizeFormatted,
               SizePercent, FileCount, FolderCount, LastModified, Depth,
               IsAccessible, Extension.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Path,

        [Parameter()]
        [ValidateRange(0, 2147483647)]
        [int] $Depth = 0,

        [Parameter()]
        [ValidateRange(0, 2147483647)]
        [int] $Top = 0,

        [Parameter()]
        [long] $MinSizeBytes = 0,

        [Parameter()]
        [string] $Filter = '*',

        [Parameter()]
        [switch] $FilesOnly,

        [Parameter()]
        [switch] $ShowBar
    )

    process {
        foreach ($inputPath in $Path) {

            if (-not (Test-Path -LiteralPath $inputPath)) {
                Write-Warning "Pfad nicht gefunden: $inputPath"
                continue
            }

            # Gesamtgroesse des Scan-Roots fuer SizePercent-Berechnung
            $rootStats     = Get-FolderSizeData -FolderPath $inputPath
            $totalRootBytes = $rootStats.SizeBytes

            $resultList = [System.Collections.Generic.List[PSCustomObject]]::new()

            $scanParams = @{
                Path           = $inputPath
                TotalRootBytes = $totalRootBytes
                CurrentDepth   = 0
                MaxDepth       = $Depth
                MinSizeBytes   = $MinSizeBytes
                SearchPattern  = $Filter
                Results        = $resultList
            }
            Add-FolderResult @scanParams

            # Wenn FilesOnly: Ordner aus Ergebnissen entfernen
            if ($FilesOnly) {
                $resultList = [System.Collections.Generic.List[PSCustomObject]](
                    $resultList | Where-Object { $PSItem.Extension -ne '' }
                )
            }

            # Absteigend nach Groesse sortieren
            $sortedResults = $resultList | Sort-Object -Property SizeBytes -Descending

            # Auf Top-N begrenzen
            if ($Top -gt 0) {
                $sortedResults = $sortedResults | Select-Object -First $Top
            }

            # ASCII-Balken ausgeben wenn gewuenscht
            if ($ShowBar -and $sortedResults) {
                $maxItemBytes = ($sortedResults | Select-Object -First 1).SizeBytes
                foreach ($resultItem in $sortedResults) {
                    Write-FolderBar -Item $resultItem -MaxBytes $maxItemBytes
                }
            }

            Write-Output $sortedResults
        }
    }
}
