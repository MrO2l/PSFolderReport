#Requires -Modules Pester

BeforeAll {
    # Modul laden (frisch, ohne Cache) – expliziter Pfad, unabhaengig vom PSModulePath
    $modulePath = Join-Path $PSScriptRoot '..\PSFolderReport.psd1'
    Remove-Module PSFolderReport -ErrorAction SilentlyContinue
    Import-Module $modulePath -Force
}

Describe 'PSFolderReport - Modul' {

    Context 'Manifest' {
        It 'Manifest ist valide' {
            $manifestPath = (Get-Module PSFolderReport).Path -replace '\.psm1$', '.psd1'
            { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
        }

        It 'ModuleVersion ist gesetzt' {
            (Get-Module PSFolderReport).Version | Should -Not -BeNullOrEmpty
        }

        It 'PowerShellVersion ist 5.1 oder hoeher' {
            $minVersion = [version]'5.1'
            $required   = (Get-Module PSFolderReport).PowerShellVersion
            $required   | Should -BeGreaterOrEqual $minVersion
        }
    }

    Context 'Loader' {
        It 'Import erzeugt keinen unerwuenschten Output' {
            $modulePath = Join-Path $PSScriptRoot '..\PSFolderReport.psd1'
            Remove-Module PSFolderReport -ErrorAction SilentlyContinue
            $output = Import-Module $modulePath -PassThru 4>&1
            # Nur das Modul-Objekt, kein Write-Host-Output
            ($output | Where-Object { $_ -is [string] }) | Should -BeNullOrEmpty
        }
    }
}
