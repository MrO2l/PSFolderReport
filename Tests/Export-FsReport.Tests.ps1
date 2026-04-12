#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSFolderReport.psd1'
    Remove-Module -Name PSFolderReport -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force

    $script:exportRoot = Join-Path -Path $TestDrive -ChildPath 'ExportTest'
    New-Item -Path (Join-Path -Path $script:exportRoot -ChildPath 'FolderA') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path -Path $script:exportRoot -ChildPath 'FolderA\file.txt') -Value ('X' * 5000)

    $script:scanData = Get-FolderSize -Path $script:exportRoot
}

Describe 'Export-FsReport - CSV' {

    It 'Erstellt eine CSV-Datei' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result.csv'
        $script:scanData | Export-FsReport -Format CSV -OutputPath $outputFile
        Test-Path -LiteralPath $outputFile | Should -BeTrue
    }

    It 'CSV-Datei enthaelt Header-Zeile mit Name' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result_header.csv'
        $script:scanData | Export-FsReport -Format CSV -OutputPath $outputFile
        $firstLine = Get-Content -Path $outputFile -TotalCount 1
        $firstLine | Should -Match 'Name'
    }

    It 'CSV-Datei enthaelt Datensatz-Zeilen' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result_rows.csv'
        $script:scanData | Export-FsReport -Format CSV -OutputPath $outputFile
        $lineCount = (Get-Content -Path $outputFile).Count
        # Mindestens Header + 1 Datenzeile
        $lineCount | Should -BeGreaterThan 1
    }
}

Describe 'Export-FsReport - HTML' {

    It 'Erstellt eine HTML-Datei' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result.html'
        $script:scanData | Export-FsReport -Format HTML -OutputPath $outputFile -ScannedPath $script:exportRoot
        Test-Path -LiteralPath $outputFile | Should -BeTrue
    }

    It 'HTML-Datei enthaelt DOCTYPE-Deklaration' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result_doctype.html'
        $script:scanData | Export-FsReport -Format HTML -OutputPath $outputFile -ScannedPath $script:exportRoot
        $htmlContent = Get-Content -Path $outputFile -Raw
        $htmlContent | Should -Match '<!DOCTYPE html>'
    }

    It 'HTML-Datei enthaelt Tabellen-Element' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result_table.html'
        $script:scanData | Export-FsReport -Format HTML -OutputPath $outputFile -ScannedPath $script:exportRoot
        $htmlContent = Get-Content -Path $outputFile -Raw
        $htmlContent | Should -Match '<table'
    }

    It 'HTML-Datei enthaelt CSS-Balken-Element' {
        $outputFile = Join-Path -Path $TestDrive -ChildPath 'result_bar.html'
        $script:scanData | Export-FsReport -Format HTML -OutputPath $outputFile -ScannedPath $script:exportRoot
        $htmlContent = Get-Content -Path $outputFile -Raw
        $htmlContent | Should -Match 'class="bar"'
    }
}

Describe 'Export-FsReport - Fehlerbehandlung' {

    It 'Leere Pipeline erzeugt Warning, keinen Fehler' {
        { @() | Export-FsReport -Format CSV -OutputPath (Join-Path $TestDrive 'empty.csv') -WarningAction SilentlyContinue } | Should -Not -Throw
    }
}
