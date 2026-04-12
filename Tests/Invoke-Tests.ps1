# Tests\Invoke-Tests.ps1
# Alle Pester-Tests ausfuehren und Zusammenfassung anzeigen.
# Aufruf: & "<Pfad>\Tests\Invoke-Tests.ps1"

$resultsDir = Join-Path $PSScriptRoot 'TestResults'
if (-not (Test-Path $resultsDir)) {
    New-Item -Path $resultsDir -ItemType Directory | Out-Null
}

$configPath = Join-Path $PSScriptRoot 'pester.config.ps1'
$config = & $configPath
Invoke-Pester -Configuration $config
