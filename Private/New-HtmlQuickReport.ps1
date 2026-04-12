function Write-HtmlQuickReport {
<#
.SYNOPSIS
    Erstellt einen offline-faehigen HTML-Schnellreport ohne externe Abhaengigkeiten.
.DESCRIPTION
    Generiert eine HTML-Datei mit CSS-Balkenvisualisierung, Farb-Codierung
    und Metadaten. Keine externen Bibliotheken – vollstaendig offline nutzbar.
    Sonderzeichen werden mit System.Web.HttpUtility.HtmlEncode gesichert.
.PARAMETER Data
    Liste von PSCustomObject-Eintraegen aus Get-FolderSize.
.PARAMETER OutputPath
    Zieldateipfad fuer die HTML-Datei.
.PARAMETER Title
    Titel des Reports (wird in h1 und title-Tag verwendet).
.PARAMETER ScannedPath
    Gescannter Pfad – wird als Metainfo angezeigt.
.EXAMPLE
    New-HtmlQuickReport -Data $results -OutputPath 'C:\report.html' -Title 'Bericht'
.NOTES
    Private Hilfsfunktion – wird von Export-FsReport aufgerufen.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[PSCustomObject]] $Data,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [string] $ScannedPath
    )

    # System.Web fuer HtmlEncode sicherstellen
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

    $generatedAt   = Get-Date -Format 'dd.MM.yyyy HH:mm:ss'
    $totalSizeSum  = ($Data | Measure-Object -Property SizeBytes -Sum).Sum
    $totalSizeBytes = if ($null -eq $totalSizeSum) { 0L } else { [long]$totalSizeSum }
    $totalSize      = Format-FileSize -Bytes $totalSizeBytes
    $maxBytesValue = ($Data | Measure-Object -Property SizeBytes -Maximum).Maximum
    $maxBytes      = if ($null -eq $maxBytesValue) { 1L } else { [long]$maxBytesValue }

    # Tabellenzeilen mit CSS-Balken generieren
    $tableRows = foreach ($entry in $Data) {
        $barPercent  = if ($maxBytes -gt 0) { [int]($entry.SizeBytes / $maxBytes * 100) } else { 0 }
        $barColor    = '#27ae60'
        if ($entry.SizeBytes -ge 100MB) { $barColor = '#f39c12' }
        if ($entry.SizeBytes -ge 1GB)   { $barColor = '#e74c3c' }

        $safeName    = [System.Web.HttpUtility]::HtmlEncode($entry.Name)
        $lastChanged = if ($null -ne $entry.LastModified) { $entry.LastModified.ToString('dd.MM.yyyy') } else { '' }

        @"
        <tr>
            <td>$safeName</td>
            <td class="size">$($entry.SizeFormatted)</td>
            <td class="pct">$($entry.SizePercent)%</td>
            <td><div class="bar" style="width:${barPercent}%;background:$barColor"></div></td>
            <td class="num">$($entry.FileCount)</td>
            <td>$lastChanged</td>
        </tr>
"@
    }

    $safeScannedPath = [System.Web.HttpUtility]::HtmlEncode($ScannedPath)

    $htmlContent = @"
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<title>$Title</title>
<style>
  body  { font-family: Segoe UI, Arial, sans-serif; margin: 2em; background: #f5f5f5; color: #222; }
  h1    { color: #2c3e50; margin-bottom: 0.3em; }
  .meta { color: #666; font-size: 0.9em; margin-bottom: 1.5em; }
  table { border-collapse: collapse; width: 100%; background: #fff;
          box-shadow: 0 1px 4px rgba(0,0,0,0.12); }
  th    { background: #2c3e50; color: #fff; padding: 10px 14px; text-align: left; }
  td    { padding: 8px 14px; border-bottom: 1px solid #eee; }
  tr:hover { background: #f0f4f8; }
  .size { text-align: right; font-family: monospace; white-space: nowrap; }
  .pct  { text-align: right; color: #666; }
  .num  { text-align: right; }
  .bar  { height: 14px; border-radius: 3px; min-width: 2px; }
</style>
</head>
<body>
<h1>$Title</h1>
<div class="meta">
  Pfad: <strong>$safeScannedPath</strong> &nbsp;|&nbsp;
  Gesamt: <strong>$totalSize</strong> &nbsp;|&nbsp;
  Erstellt: $generatedAt
</div>
<table>
  <tr><th>Name</th><th>Groesse</th><th>Anteil</th><th>Visualisierung</th><th>Dateien</th><th>Geaendert</th></tr>
  $($tableRows -join "`n")
</table>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
}
