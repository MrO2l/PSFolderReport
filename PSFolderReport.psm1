#Requires -Version 5.1
<#
.SYNOPSIS
    PSFolderReport - PowerShell-Modul zur Speicherplatzanalyse.
.DESCRIPTION
    Laedt alle Public- und Private-Funktionen per Dot-Sourcing.
    Public-Funktionen werden exportiert; Private-Funktionen sind
    nur modulintern sichtbar.
    Keine Seiteneffekte beim Import: kein Output, kein Scan, keine GUI.
#>

# --- WinForms Assemblies laden (benoetigt fuer GUI-Cmdlets) -------------------
Add-Type -AssemblyName System.Windows.Forms  -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing        -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Web            -ErrorAction SilentlyContinue

# --- Private Funktionen laden (nicht exportieren) -----------------------------
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFunctions) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Fehler beim Laden von '$($file.FullName)': $_"
    }
}

# --- Public Funktionen laden und exportieren ----------------------------------
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFunctions) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Fehler beim Laden von '$($file.FullName)': $_"
    }
}

# Nur Public-Funktionen exportieren (Dateiname = Funktionsname)
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}
