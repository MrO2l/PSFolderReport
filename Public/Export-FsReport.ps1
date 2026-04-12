function Export-FsReport {
<#
.SYNOPSIS
    Exportiert Get-FolderSize-Ergebnisse als CSV- oder HTML-Report.
.DESCRIPTION
    Nimmt PSCustomObject-Eingaben aus der Pipeline entgegen und schreibt
    diese als CSV-Datei oder als offline-faehigen HTML-Report mit
    CSS-Balkenvisualisierung. Mit -Open wird die Datei nach dem Schreiben
    im Standardprogramm geoeffnet.
.PARAMETER InputObject
    PSCustomObject-Eintraege aus Get-FolderSize. Pipeline-kompatibel.
.PARAMETER Format
    Ausgabeformat: 'CSV' oder 'HTML'.
.PARAMETER OutputPath
    Vollstaendiger Dateipfad fuer die Ausgabedatei.
.PARAMETER Title
    Titel des Reports (nur fuer HTML, Standard: 'PSFolderReport Report').
.PARAMETER ScannedPath
    Gescanntes Verzeichnis – wird als Metainfo im HTML angezeigt.
.PARAMETER Open
    Wenn angegeben, wird die erzeugte Datei im Standardprogramm geoeffnet.
.EXAMPLE
    Get-FolderSize -Path 'C:\Users' | Export-FsReport -Format CSV -OutputPath 'C:\report.csv'
.EXAMPLE
    Get-FolderSize -Path 'C:\Users' | Export-FsReport -Format HTML -OutputPath 'C:\report.html' -Open -ScannedPath 'C:\Users'
.NOTES
    Autor: PSFolderReport Developer
    Phase: 1
    CSV verwendet UTF-8-Kodierung ohne BOM. HTML ist vollstaendig offline-faehig.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Benutzerrueckmeldung nach erfolgreichem Export')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject[]] $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CSV', 'HTML')]
        [string] $Format,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter()]
        [string] $Title = 'PSFolderReport Report',

        [Parameter()]
        [string] $ScannedPath = '',

        [Parameter()]
        [switch] $Open
    )

    begin {
        $collectedData = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $collectedData.Add($item)
        }
    }

    end {
        if ($collectedData.Count -eq 0) {
            Write-Warning 'Keine Daten zum Exportieren vorhanden.'
            return
        }

        switch ($Format) {
            'CSV' {
                $csvParams = @{
                    Path                = $OutputPath
                    NoTypeInformation   = $true
                    Encoding            = 'UTF8'
                }
                $collectedData | Export-Csv @csvParams
            }
            'HTML' {
                $htmlParams = @{
                    Data         = $collectedData
                    OutputPath   = $OutputPath
                    Title        = $Title
                    ScannedPath  = $ScannedPath
                }
                Write-HtmlQuickReport @htmlParams
            }
        }

        Write-Host "Report gespeichert: $OutputPath" -ForegroundColor Green

        if ($Open -and (Test-Path -LiteralPath $OutputPath)) {
            Invoke-Item -Path $OutputPath
        }
    }
}
