function Write-FolderBar {
<#
.SYNOPSIS
    Gibt eine farbige ASCII-Balkenzeile fuer einen Ordnereintrag aus.
.DESCRIPTION
    Stellt Name, proportionalen Fuellbalken, Groesse und prozentualen Anteil
    als farbige Konsolenzeile dar. Rot fuer Eintraege >= 1 GB,
    Gelb fuer >= 100 MB, Gruen fuer kleinere Eintraege.
.PARAMETER Item
    PSCustomObject aus Get-FolderSize mit Name, SizeBytes, SizeFormatted, SizePercent.
.PARAMETER MaxBytes
    Referenzwert fuer die Balkenskalierung (in der Regel das groesste Element).
.PARAMETER BarWidth
    Breite des Balkens in Zeichen (Standard: 40).
.EXAMPLE
    $results = Get-FolderSize -Path C:\
    Write-FolderBar -Item $results[0] -MaxBytes $results[0].SizeBytes
.NOTES
    Private Hilfsfunktion – wird von Get-FolderSize -ShowBar aufgerufen.
    Blockzeichen (U+2588) werden als Fuellzeichen verwendet.
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Farbige Konsolenausgabe ist der Zweck dieser Funktion')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Item,

        [Parameter(Mandatory = $true)]
        [long] $MaxBytes,

        [Parameter()]
        [ValidateRange(10, 100)]
        [int] $BarWidth = 40
    )

    # Fuellbreite proportional zum Maximalwert berechnen
    $filledWidth = if ($MaxBytes -gt 0) {
        [int]($Item.SizeBytes / $MaxBytes * $BarWidth)
    }
    else { 0 }

    # Blockzeichen (U+2588) als Fuellzeichen; Rest mit Leerzeichen aufpolstern
    $blockChar   = [char]0x2588
    $filledPart  = ($blockChar.ToString()) * $filledWidth
    $bar         = $filledPart.PadRight($BarWidth)

    # Farbschwellen: Rot >= 1 GB, Gelb >= 100 MB, Gruen fuer alles andere
    $barColor = 'Green'
    if ($Item.SizeBytes -ge 100MB) { $barColor = 'Yellow' }
    if ($Item.SizeBytes -ge 1GB)   { $barColor = 'Red' }

    # Name auf 30 Zeichen begrenzen und linksbuendig ausrichten
    if ($Item.Name.Length -gt 30) {
        $displayName = $Item.Name.Substring(0, 27) + '...'
    }
    else {
        $displayName = $Item.Name.PadRight(30)
    }

    Write-Host ('{0}  ' -f $displayName) -NoNewline
    Write-Host $bar -ForegroundColor $barColor -NoNewline
    Write-Host ('  {0,10}  {1,5:N1}%' -f $Item.SizeFormatted, $Item.SizePercent)
}
