#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSFolderReport.psd1'
    Remove-Module -Name PSFolderReport -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force
}

Describe 'Show-FolderSizeGui' {

    Context 'Cmdlet-Metadaten' {

        It 'Cmdlet ist exportiert und auffindbar' {
            Get-Command -Name Show-FolderSizeGui -Module PSFolderReport | Should -Not -BeNullOrEmpty
        }

        It 'Hat Parameter StartPath' {
            $cmd = Get-Command -Name Show-FolderSizeGui
            $cmd.Parameters.ContainsKey('StartPath') | Should -BeTrue
        }

        It 'StartPath ist nicht Mandatory (hat Standardwert)' {
            $cmd           = Get-Command -Name Show-FolderSizeGui
            $paramAttribs  = $cmd.Parameters['StartPath'].Attributes |
                             Where-Object { $PSItem -is [System.Management.Automation.ParameterAttribute] }
            $isMandatory   = $paramAttribs | ForEach-Object { $PSItem.Mandatory }
            # Standardwert vorhanden = Parameter ist nicht Mandatory
            $isMandatory | Should -BeFalse
        }
    }

    # Hinweis: GUI-Tests (ShowDialog) sind nur manuell durchfuehrbar,
    # da WinForms die aufrufende Pipeline blockiert und kein Headless-Rendering
    # ohne zusaetzliche Frameworks moeglich ist.
}
