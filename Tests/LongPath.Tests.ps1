#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSFolderReport.psd1'
    Remove-Module -Name PSFolderReport -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force
}

Describe 'Long-Path Hilfsfunktionen' {

    Context 'Get-LongPath' {

        It 'Fuegt \\?\ Prefix fuer lokale Pfade hinzu' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-LongPath -Path 'C:\Users\Test' }
            $result | Should -BeLike '\\?\*'
        }

        It 'Fuegt \\?\UNC\ Prefix fuer UNC-Pfade hinzu' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-LongPath -Path '\\server\share\folder' }
            $result | Should -BeLike '\\?\UNC\*'
        }

        It 'Lokaler Pfad enthaelt den urspruenglichen Pfad nach dem Prefix' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-LongPath -Path 'C:\Windows' }
            $result | Should -Be '\\?\C:\Windows'
        }
    }

    Context 'Get-CleanPath' {

        It 'Entfernt \\?\ von lokalen Pfaden' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-CleanPath -Path '\\?\C:\Windows' }
            $result | Should -Be 'C:\Windows'
        }

        It 'Konvertiert \\?\UNC\ in \\' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-CleanPath -Path '\\?\UNC\server\share' }
            $result | Should -Be '\\server\share'
        }

        It 'Laesst normale Pfade unveraendert' {
            $moduleScope = Get-Module -Name PSFolderReport
            $result = & $moduleScope { Get-CleanPath -Path 'C:\Windows' }
            $result | Should -Be 'C:\Windows'
        }
    }

    Context 'Get-FolderSize mit normalem Pfad' {

        It 'Verarbeitet normalen Pfad ohne Fehler' {
            { Get-FolderSize -Path $env:TEMP -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Ergebnisse enthalten keine \\?\ in FullPath' {
            $result = Get-FolderSize -Path $env:TEMP -WarningAction SilentlyContinue | Select-Object -First 5
            foreach ($item in $result) {
                $item.FullPath | Should -Not -BeLike '\\?\*'
            }
        }
    }
}
