#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSFolderReport.psd1'
    Remove-Module -Name PSFolderReport -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force

    # Testverzeichnis mit definierten Dateigroessen aufbauen
    $script:testRoot = Join-Path -Path $TestDrive -ChildPath 'ScanTest'
    New-Item -Path $script:testRoot -ItemType Directory -Force | Out-Null

    New-Item -Path (Join-Path -Path $script:testRoot -ChildPath 'FolderA') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path -Path $script:testRoot -ChildPath 'FolderA\file1.txt') -Value ('X' * 1024)
    Set-Content -Path (Join-Path -Path $script:testRoot -ChildPath 'FolderA\file2.txt') -Value ('X' * 2048)

    New-Item -Path (Join-Path -Path $script:testRoot -ChildPath 'FolderB') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path -Path $script:testRoot -ChildPath 'FolderB\big.log') -Value ('X' * 10240)
}

Describe 'Get-FolderSize' {

    Context 'Rueckgabewerte' {

        It 'Gibt Ergebnisse zurueck' {
            $result = Get-FolderSize -Path $script:testRoot
            $result | Should -Not -BeNullOrEmpty
        }

        It 'SizeBytes ist groesser als 0' {
            $result = Get-FolderSize -Path $script:testRoot
            foreach ($item in $result) {
                $item.SizeBytes | Should -BeGreaterThan 0
            }
        }

        It 'SizeFormatted ist nicht leer' {
            $result = Get-FolderSize -Path $script:testRoot
            foreach ($item in $result) {
                $item.SizeFormatted | Should -Not -BeNullOrEmpty
            }
        }

        It 'Alle Pflichteigenschaften sind vorhanden' {
            $result = Get-FolderSize -Path $script:testRoot
            $firstItem = $result | Select-Object -First 1
            $firstItem.PSObject.Properties.Name | Should -Contain 'Name'
            $firstItem.PSObject.Properties.Name | Should -Contain 'FullPath'
            $firstItem.PSObject.Properties.Name | Should -Contain 'SizeBytes'
            $firstItem.PSObject.Properties.Name | Should -Contain 'SizeFormatted'
            $firstItem.PSObject.Properties.Name | Should -Contain 'SizePercent'
            $firstItem.PSObject.Properties.Name | Should -Contain 'FileCount'
            $firstItem.PSObject.Properties.Name | Should -Contain 'FolderCount'
            $firstItem.PSObject.Properties.Name | Should -Contain 'LastModified'
            $firstItem.PSObject.Properties.Name | Should -Contain 'Depth'
            $firstItem.PSObject.Properties.Name | Should -Contain 'IsAccessible'
        }
    }

    Context 'Sortierung und Filter' {

        It 'Sortiert absteigend nach Groesse' {
            $result = Get-FolderSize -Path $script:testRoot
            $result[0].SizeBytes | Should -BeGreaterOrEqual $result[-1].SizeBytes
        }

        It 'Top-N Parameter begrenzt die Ergebnisse' {
            $result = Get-FolderSize -Path $script:testRoot -Top 1
            $result.Count | Should -Be 1
        }

        It 'MinSizeBytes filtert kleine Eintraege heraus' {
            $largeThreshold = 5000
            $result = Get-FolderSize -Path $script:testRoot -MinSizeBytes $largeThreshold
            foreach ($item in $result) {
                $item.SizeBytes | Should -BeGreaterOrEqual $largeThreshold
            }
        }
    }

    Context 'SizePercent' {

        It 'SizePercent summiert sich auf annaehernd 100 Prozent' {
            $result = Get-FolderSize -Path $script:testRoot
            $percentSum = ($result | Measure-Object -Property SizePercent -Sum).Sum
            # Direktkinder sollen ~100% ergeben; Rundungsdifferenz bis 5% toleriert
            $percentSum | Should -BeGreaterThan 90
        }

        It 'SizePercent ist zwischen 0 und 100' {
            $result = Get-FolderSize -Path $script:testRoot
            foreach ($item in $result) {
                $item.SizePercent | Should -BeGreaterOrEqual 0
                $item.SizePercent | Should -BeLessOrEqual 100
            }
        }
    }

    Context 'Fehlerbehandlung' {

        It 'Nicht vorhandener Pfad erzeugt Warning, keinen Fehler' {
            { Get-FolderSize -Path 'C:\Pfad_Existiert_Nicht_XYZ' -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Pipeline-Eingabe wird korrekt verarbeitet' {
            $result = 'C:\Pfad_Existiert_Nicht_XYZ' | Get-FolderSize -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'ShowBar' {

        It 'ShowBar loest keinen Fehler aus' {
            { Get-FolderSize -Path $script:testRoot -ShowBar } | Should -Not -Throw
        }
    }
}
