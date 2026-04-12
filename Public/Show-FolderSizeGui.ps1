function Show-FolderSizeGui {
<#
.SYNOPSIS
    Oeffnet die grafische Oberflaeche von PSFolderReport.
.DESCRIPTION
    Zeigt ein WinForms-Fenster mit TreeView (Ordnerhierarchie) und ListView
    (Detailansicht mit Groesse, Anteil, Dateianzahl). Ein Scan-Button startet
    die Analyse; Toolbar-Buttons exportieren Ergebnisse als CSV oder HTML.
    Farbcodierung: Rot >= 1 GB, Gelb >= 100 MB, Weiss fuer kleinere Eintraege.
    Erfordert Windows mit .NET/WinForms.
.PARAMETER StartPath
    Startverzeichnis fuer den Pfad-Eingabefeld (Standard: Benutzerprofilordner).
.EXAMPLE
    Show-FolderSizeGui
.EXAMPLE
    Show-FolderSizeGui -StartPath 'C:\Users'
.NOTES
    Autor: PSFolderReport Developer
    Phase: 1
    GUI-Tests sind nur manuell durchfuehrbar (WinForms blockiert die Pipeline).
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $StartPath = $env:USERPROFILE
    )

    # Assemblies sicherheitshalber nochmals laden (falls Modul ohne psm1-Init genutzt)
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing       -ErrorAction SilentlyContinue

    # ─────────────────────────────────────────────────────────────────────────
    # Hauptfenster
    # ─────────────────────────────────────────────────────────────────────────
    $mainForm = [System.Windows.Forms.Form]::new()
    $mainForm.Text          = 'PSFolderReport'
    $mainForm.Size          = [System.Drawing.Size]::new(1100, 700)
    $mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $mainForm.MinimumSize   = [System.Drawing.Size]::new(800, 500)

    # ─────────────────────────────────────────────────────────────────────────
    # Toolbar-Panel (oben)
    # ─────────────────────────────────────────────────────────────────────────
    $toolbarPanel           = [System.Windows.Forms.Panel]::new()
    $toolbarPanel.Dock      = [System.Windows.Forms.DockStyle]::Top
    $toolbarPanel.Height    = 44
    $toolbarPanel.BackColor = [System.Drawing.Color]::FromArgb(44, 62, 80)
    $toolbarPanel.Padding   = [System.Windows.Forms.Padding]::new(6, 6, 6, 6)

    $pathTextBox            = [System.Windows.Forms.TextBox]::new()
    $pathTextBox.Text       = $StartPath
    $pathTextBox.Width      = 580
    $pathTextBox.Location   = [System.Drawing.Point]::new(8, 10)

    $browseButton           = [System.Windows.Forms.Button]::new()
    $browseButton.Text      = '...'
    $browseButton.Width     = 30
    $browseButton.Location  = [System.Drawing.Point]::new(594, 8)
    $browseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $browseButton.ForeColor = [System.Drawing.Color]::White
    $browseButton.BackColor = [System.Drawing.Color]::FromArgb(52, 73, 94)

    $scanButton             = [System.Windows.Forms.Button]::new()
    $scanButton.Text        = 'Scannen'
    $scanButton.Width       = 90
    $scanButton.Location    = [System.Drawing.Point]::new(630, 8)
    $scanButton.FlatStyle   = [System.Windows.Forms.FlatStyle]::Flat
    $scanButton.ForeColor   = [System.Drawing.Color]::White
    $scanButton.BackColor   = [System.Drawing.Color]::FromArgb(39, 174, 96)

    $csvButton              = [System.Windows.Forms.Button]::new()
    $csvButton.Text         = 'CSV'
    $csvButton.Width        = 50
    $csvButton.Location     = [System.Drawing.Point]::new(730, 8)
    $csvButton.FlatStyle    = [System.Windows.Forms.FlatStyle]::Flat
    $csvButton.ForeColor    = [System.Drawing.Color]::White
    $csvButton.BackColor    = [System.Drawing.Color]::FromArgb(52, 73, 94)

    $htmlButton             = [System.Windows.Forms.Button]::new()
    $htmlButton.Text        = 'HTML'
    $htmlButton.Width       = 55
    $htmlButton.Location    = [System.Drawing.Point]::new(786, 8)
    $htmlButton.FlatStyle   = [System.Windows.Forms.FlatStyle]::Flat
    $htmlButton.ForeColor   = [System.Drawing.Color]::White
    $htmlButton.BackColor   = [System.Drawing.Color]::FromArgb(52, 73, 94)

    $toolbarPanel.Controls.AddRange(@($pathTextBox, $browseButton, $scanButton, $csvButton, $htmlButton))

    # ─────────────────────────────────────────────────────────────────────────
    # Statusleiste
    # ─────────────────────────────────────────────────────────────────────────
    $statusStrip    = [System.Windows.Forms.StatusStrip]::new()
    $statusLabel    = [System.Windows.Forms.ToolStripStatusLabel]::new()
    $statusLabel.Text = 'Bereit.'
    $progressBar    = [System.Windows.Forms.ToolStripProgressBar]::new()
    $progressBar.Width   = 200
    $progressBar.Visible = $false
    $statusStrip.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($statusLabel, $progressBar))

    # ─────────────────────────────────────────────────────────────────────────
    # SplitContainer mit TreeView und ListView
    # ─────────────────────────────────────────────────────────────────────────
    $splitContainer                  = [System.Windows.Forms.SplitContainer]::new()
    $splitContainer.Dock             = [System.Windows.Forms.DockStyle]::Fill
    $splitContainer.SplitterDistance = 300
    $splitContainer.Panel1MinSize    = 150

    $treeView           = [System.Windows.Forms.TreeView]::new()
    $treeView.Dock      = [System.Windows.Forms.DockStyle]::Fill
    $treeView.BackColor = [System.Drawing.Color]::White
    $splitContainer.Panel1.Controls.Add($treeView)

    $listView               = [System.Windows.Forms.ListView]::new()
    $listView.Dock          = [System.Windows.Forms.DockStyle]::Fill
    $listView.View          = [System.Windows.Forms.View]::Details
    $listView.FullRowSelect = $true
    $listView.GridLines     = $true
    $listView.BackColor     = [System.Drawing.Color]::White

    $colName     = [System.Windows.Forms.ColumnHeader]::new(); $colName.Text     = 'Name';     $colName.Width     = 260
    $colSize     = [System.Windows.Forms.ColumnHeader]::new(); $colSize.Text     = 'Groesse';  $colSize.Width     = 110
    $colPercent  = [System.Windows.Forms.ColumnHeader]::new(); $colPercent.Text  = 'Anteil';   $colPercent.Width  = 70
    $colFiles    = [System.Windows.Forms.ColumnHeader]::new(); $colFiles.Text    = 'Dateien';  $colFiles.Width    = 70
    $colModified = [System.Windows.Forms.ColumnHeader]::new(); $colModified.Text = 'Geaendert'; $colModified.Width = 110
    $listView.Columns.AddRange([System.Windows.Forms.ColumnHeader[]]@($colName, $colSize, $colPercent, $colFiles, $colModified))
    $splitContainer.Panel2.Controls.Add($listView)

    # ─────────────────────────────────────────────────────────────────────────
    # Scan-Ergebnisse (modulweit im Script-Scope des Cmdlets)
    # ─────────────────────────────────────────────────────────────────────────
    $script:currentScanResults = @()

    # ─────────────────────────────────────────────────────────────────────────
    # Hilfsfunktion: ListView und TreeView aus Scan-Ergebnissen befuellen
    # ─────────────────────────────────────────────────────────────────────────
    $populateViews = {
        param ([array] $ScanResults, [string] $RootPath)

        $treeView.Nodes.Clear()
        $listView.Items.Clear()

        $rootNodeLabel = Split-Path -Path $RootPath -Leaf
        $rootNode      = [System.Windows.Forms.TreeNode]::new($rootNodeLabel)

        foreach ($scanResult in $ScanResults) {
            $treeNode     = [System.Windows.Forms.TreeNode]::new($scanResult.Name)
            $treeNode.Tag = $scanResult
            $rootNode.Nodes.Add($treeNode) | Out-Null

            $listItem = [System.Windows.Forms.ListViewItem]::new($scanResult.Name)
            if ($null -ne $scanResult.LastModified) {
                $lastModifiedText = $scanResult.LastModified.ToString('dd.MM.yyyy')
            }
            else {
                $lastModifiedText = ''
            }

            $listItem.SubItems.AddRange([string[]]@(
                $scanResult.SizeFormatted,
                "$($scanResult.SizePercent)%",
                "$($scanResult.FileCount)",
                $lastModifiedText
            ))

            $listItem.BackColor = [System.Drawing.Color]::White
            if ($scanResult.SizeBytes -ge 100MB) { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 248, 210) }
            if ($scanResult.SizeBytes -ge 1GB)   { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 220, 220) }

            $listView.Items.Add($listItem) | Out-Null
        }

        $treeView.Nodes.Add($rootNode) | Out-Null
        $rootNode.Expand()
    }

    # ─────────────────────────────────────────────────────────────────────────
    # Ereignis: Ordner durchsuchen
    # ─────────────────────────────────────────────────────────────────────────
    $browseButton.Add_Click({
        $folderDialog = [System.Windows.Forms.FolderBrowserDialog]::new()
        $folderDialog.SelectedPath = $pathTextBox.Text
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $pathTextBox.Text = $folderDialog.SelectedPath
        }
    })

    # ─────────────────────────────────────────────────────────────────────────
    # Ereignis: Scan starten
    # ─────────────────────────────────────────────────────────────────────────
    $scanButton.Add_Click({
        $scanPath = $pathTextBox.Text.Trim()

        if (-not (Test-Path -LiteralPath $scanPath)) {
            $messageParams = @{
                Text    = "Pfad nicht gefunden:`n$scanPath"
                Caption = 'Fehler'
                Buttons = [System.Windows.Forms.MessageBoxButtons]::OK
                Icon    = [System.Windows.Forms.MessageBoxIcon]::Error
            }
            [System.Windows.Forms.MessageBox]::Show(
                $messageParams.Text, $messageParams.Caption,
                $messageParams.Buttons, $messageParams.Icon
            ) | Out-Null
            return
        }

        $statusLabel.Text    = "Scanne: $scanPath ..."
        $progressBar.Visible = $true
        $mainForm.Refresh()

        $scanResults               = Get-FolderSize -Path $scanPath
        $script:currentScanResults = $scanResults

        & $populateViews -ScanResults $scanResults -RootPath $scanPath

        $totalSizeSum   = ($scanResults | Measure-Object -Property SizeBytes -Sum).Sum
        $totalFormatted = Format-FileSize -Bytes (if ($null -eq $totalSizeSum) { 0L } else { [long]$totalSizeSum })

        $statusLabel.Text    = "Scan abgeschlossen. $($scanResults.Count) Eintraege | Gesamt: $totalFormatted"
        $progressBar.Visible = $false
    })

    # ─────────────────────────────────────────────────────────────────────────
    # Ereignis: CSV-Export
    # ─────────────────────────────────────────────────────────────────────────
    $csvButton.Add_Click({
        if ($script:currentScanResults.Count -eq 0) {
            Write-Warning 'Kein Scan-Ergebnis vorhanden. Bitte zuerst scannen.'
            return
        }

        $saveDialog            = [System.Windows.Forms.SaveFileDialog]::new()
        $saveDialog.Filter     = 'CSV-Dateien (*.csv)|*.csv'
        $saveDialog.FileName   = "PSFolderReport_$(Get-Date -Format 'yyyyMMdd').csv"

        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:currentScanResults | Export-FsReport -Format CSV -OutputPath $saveDialog.FileName
            $statusLabel.Text = "CSV gespeichert: $($saveDialog.FileName)"
        }
    })

    # ─────────────────────────────────────────────────────────────────────────
    # Ereignis: HTML-Export
    # ─────────────────────────────────────────────────────────────────────────
    $htmlButton.Add_Click({
        if ($script:currentScanResults.Count -eq 0) {
            Write-Warning 'Kein Scan-Ergebnis vorhanden. Bitte zuerst scannen.'
            return
        }

        $saveDialog            = [System.Windows.Forms.SaveFileDialog]::new()
        $saveDialog.Filter     = 'HTML-Dateien (*.html)|*.html'
        $saveDialog.FileName   = "PSFolderReport_$(Get-Date -Format 'yyyyMMdd').html"

        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $exportParams = @{
                Format      = 'HTML'
                OutputPath  = $saveDialog.FileName
                Open        = $true
                ScannedPath = $pathTextBox.Text
            }
            $script:currentScanResults | Export-FsReport @exportParams
            $statusLabel.Text = "HTML-Report geoeffnet: $($saveDialog.FileName)"
        }
    })

    # ─────────────────────────────────────────────────────────────────────────
    # Fenster zusammenbauen und anzeigen
    # ─────────────────────────────────────────────────────────────────────────
    $mainForm.Controls.AddRange([System.Windows.Forms.Control[]]@($toolbarPanel, $splitContainer, $statusStrip))
    $mainForm.ShowDialog() | Out-Null
    $mainForm.Dispose()
}
