#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSFolderReport.psd1'
    Remove-Module -Name PSFolderReport -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force

    $script:treeRoot = Join-Path -Path $TestDrive -ChildPath 'TreeTest'
    New-Item -Path (Join-Path -Path $script:treeRoot -ChildPath 'SubA\SubB') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path -Path $script:treeRoot -ChildPath 'SubA\file.txt') -Value 'Testinhalt'
}

Describe 'Show-FolderTree' {

    Context 'Aufruf und Ausgabe' {

        It 'Laeuft ohne Fehler durch' {
            { Show-FolderTree -Path $script:treeRoot -Depth 2 } | Should -Not -Throw
        }

        It 'Gibt Konsolenausgabe aus' {
            $output = Show-FolderTree -Path $script:treeRoot -Depth 1 *>&1
            $output | Should -Not -BeNullOrEmpty
        }

        It 'Gibt kein Objekt in die Pipeline zurueck' {
            $pipelineOutput = Show-FolderTree -Path $script:treeRoot -Depth 1
            $pipelineOutput | Should -BeNullOrEmpty
        }
    }

    Context 'Fehlerbehandlung' {

        It 'Nicht vorhandener Pfad erzeugt Warning, keinen Fehler' {
            { Show-FolderTree -Path 'C:\Pfad_Existiert_Nicht_XYZ' -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Cmdlet-Metadaten' {

        It 'Cmdlet ist exportiert' {
            Get-Command -Name Show-FolderTree -Module PSFolderReport | Should -Not -BeNullOrEmpty
        }

        It 'Hat Parameter Path' {
            $cmd = Get-Command -Name Show-FolderTree
            $cmd.Parameters.ContainsKey('Path') | Should -BeTrue
        }

        It 'Hat Parameter Depth' {
            $cmd = Get-Command -Name Show-FolderTree
            $cmd.Parameters.ContainsKey('Depth') | Should -BeTrue
        }
    }
}
