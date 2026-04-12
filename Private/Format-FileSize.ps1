function Format-FileSize {
<#
.SYNOPSIS
    Konvertiert Bytes in eine lesbare Groessenangabe.
.DESCRIPTION
    Gibt Bytes als TB, GB, MB, KB oder Bytes mit zwei Dezimalstellen zurueck.
    Wird intern von mehreren Cmdlets als Anzeigehilfe genutzt.
.PARAMETER Bytes
    Dateigroesse in Bytes. Muss eine nicht-negative ganze Zahl sein.
.EXAMPLE
    Format-FileSize -Bytes 1073741824
    # Ausgabe: 1.00 GB
.NOTES
    Private Hilfsfunktion – nicht exportiert.
#>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [long] $Bytes
    )

    if ($Bytes -ge 1TB) { return '{0:N2} TB' -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}
