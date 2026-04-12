function Get-LongPath {
<#
.SYNOPSIS
    Wandelt einen normalen Pfad in einen Extended-Length-Pfad um.
.DESCRIPTION
    Fuegt den \\?\ Prefix hinzu, damit Windows-APIs Pfade ueber 260 Zeichen
    verarbeiten koennen. UNC-Pfade erhalten den \\?\UNC\-Prefix.
.PARAMETER Path
    Der zu konvertierende Pfad (lokal oder UNC).
.EXAMPLE
    Get-LongPath -Path 'C:\Users\Test'
    # Ausgabe: \\?\C:\Users\Test
.NOTES
    Private Hilfsfunktion – nicht exportiert.
#>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    # Bereits mit Long-Path-Prefix versehen – unveraendert zurueckgeben
    if ($Path.StartsWith('\\?\')) {
        return $Path
    }

    # UNC-Pfade benoetigen den \\?\UNC\-Prefix
    if ($Path.StartsWith('\\')) {
        return '\\?\UNC\' + $Path.TrimStart('\')
    }

    # Lokale Pfade (z.B. C:\...) benoetigen den \\?\-Prefix
    if ($Path -match '^[A-Za-z]:\\') {
        return '\\?\' + $Path
    }

    # Relative oder unbekannte Pfade unveraendert zurueckgeben
    return $Path
}

function Get-CleanPath {
<#
.SYNOPSIS
    Entfernt den Extended-Length-Prefix \\?\ fuer die Anzeige.
.DESCRIPTION
    Konvertiert interne Long-Path-Pfade zurueck in normale Anzeigeform.
    \\?\C:\... wird zu C:\... und \\?\UNC\server\... zu \\server\...
.PARAMETER Path
    Der Pfad mit potentiellem \\?\ Prefix.
.EXAMPLE
    Get-CleanPath -Path '\\?\C:\Windows'
    # Ausgabe: C:\Windows
.NOTES
    Private Hilfsfunktion – nicht exportiert.
    Verb 'Get' statt 'Remove': Funktion veraendert keinen Systemzustand.
#>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if ($Path.StartsWith('\\?\UNC\')) {
        return '\\' + $Path.Substring(8)
    }

    if ($Path.StartsWith('\\?\')) {
        return $Path.Substring(4)
    }

    return $Path
}

function Get-ChildItemLong {
<#
.SYNOPSIS
    Wrapper um System.IO.Directory-APIs fuer Long-Path-Unterstuetzung.
.DESCRIPTION
    Listet Dateisystemeintraege auch fuer Pfade > 260 Zeichen auf.
    Verwendet [System.IO.Directory]::Enumerate* statt Get-ChildItem.
    Zugriffsverweigert-Fehler werden als Debug-Meldung ausgegeben (sichtbar mit -Debug).
.PARAMETER Path
    Das zu durchsuchende Verzeichnis.
.PARAMETER SearchPattern
    Suchmuster fuer Dateinamen (Standard: '*').
.PARAMETER Recurse
    Bei Angabe wird rekursiv in Unterordnern gesucht.
.PARAMETER FilesOnly
    Gibt nur Dateien zurueck (keine Ordner).
.PARAMETER DirectoriesOnly
    Gibt nur Ordner zurueck (keine Dateien).
.PARAMETER AccessDeniedPaths
    Optionale Liste, in die Pfade eingetragen werden, auf die kein Zugriff bestand.
    Ermoeglicht dem Aufrufer zu erkennen, ob das Ergebnis unvollstaendig ist.
    Wird als [System.Collections.Generic.List[string]] uebergeben (Referenztyp).
.EXAMPLE
    Get-ChildItemLong -Path 'C:\Windows' -FilesOnly -Recurse
.EXAMPLE
    $denied = [System.Collections.Generic.List[string]]::new()
    Get-ChildItemLong -Path 'C:\' -Recurse -FilesOnly -AccessDeniedPaths $denied
    # $denied enthaelt danach alle Pfade mit Zugriffsverweigerung
.NOTES
    Private Hilfsfunktion – nicht exportiert.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter()]
        [string] $SearchPattern = '*',

        [Parameter()]
        [switch] $Recurse,

        [Parameter()]
        [switch] $FilesOnly,

        [Parameter()]
        [switch] $DirectoriesOnly,

        [Parameter()]
        [System.Collections.Generic.List[string]] $AccessDeniedPaths = $null
    )

    $longPath = Get-LongPath -Path $Path

    $searchOption = if ($Recurse) {
        [System.IO.SearchOption]::AllDirectories
    }
    else {
        [System.IO.SearchOption]::TopDirectoryOnly
    }

    try {
        if ($FilesOnly) {
            [System.IO.Directory]::EnumerateFiles($longPath, $SearchPattern, $searchOption) |
                ForEach-Object { [System.IO.FileInfo]::new($PSItem) }
        }
        elseif ($DirectoriesOnly) {
            [System.IO.Directory]::EnumerateDirectories($longPath, $SearchPattern, $searchOption) |
                ForEach-Object { [System.IO.DirectoryInfo]::new($PSItem) }
        }
        else {
            [System.IO.Directory]::EnumerateFileSystemEntries($longPath, $SearchPattern, $searchOption) |
                ForEach-Object {
                    if ([System.IO.Directory]::Exists($PSItem)) {
                        [System.IO.DirectoryInfo]::new($PSItem)
                    }
                    else {
                        [System.IO.FileInfo]::new($PSItem)
                    }
                }
        }
    }
    catch [System.UnauthorizedAccessException] {
        Write-Debug "Zugriff verweigert auf: $Path"
        if ($null -ne $AccessDeniedPaths) { [void] $AccessDeniedPaths.Add($Path) }
    }
    catch {
        Write-Debug "Fehler beim Lesen von '$Path': $($PSItem.Exception.Message)"
        if ($null -ne $AccessDeniedPaths) { [void] $AccessDeniedPaths.Add($Path) }
    }
}
