# Tests/pester.config.ps1
$config = New-PesterConfiguration

$config.Run.Path         = "$PSScriptRoot"
$config.Run.Exit         = $false          # Kein Exit-Code (fuer interaktive Nutzung)
$config.Output.Verbosity = 'Detailed'      # Alle Tests ausgeben, auch bestandene

# Code Coverage nur aktivieren wenn Public-Funktionen vorhanden sind
$publicFiles = Get-ChildItem -Path "$PSScriptRoot\..\Public\*.ps1" -ErrorAction SilentlyContinue
if ($publicFiles) {
    $config.CodeCoverage.Enabled    = $true
    $config.CodeCoverage.Path       = "$PSScriptRoot\..\Public\*.ps1"
    $config.CodeCoverage.OutputPath = "$PSScriptRoot\TestResults\coverage.xml"
}

$config.TestResult.Enabled      = $true
$config.TestResult.OutputPath   = "$PSScriptRoot\TestResults\results.xml"
$config.TestResult.OutputFormat = 'NUnitXml'

return $config
