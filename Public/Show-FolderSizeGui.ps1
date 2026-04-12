function Show-FolderSizeGui {
<#
.SYNOPSIS
    Oeffnet die grafische Oberflaeche von PSFolderReport.
.DESCRIPTION
    Zeigt ein WinForms-Fenster mit TreeView (Ordnerhierarchie) und ListView
    (Detailansicht mit Groesse, Anteil, Dateianzahl). Ein Scan-Button startet
    die Analyse; Toolbar-Buttons exportieren Ergebnisse als CSV oder HTML.

    Farbcodierung (identisch zu Show-FolderTree):
      Dunkelgruen   = kleiner 100 MB, vollstaendig lesbar
      Dunkelgelb    = ab 100 MB, vollstaendig lesbar
      Dunkelrot     = ab 1 GB, vollstaendig lesbar
      Rot + Text    = vollstaendig nicht zugaenglich ([Kein Zugriff])
      Cyan          = Wurzelverzeichnis (Root-Node)

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

    $colName     = [System.Windows.Forms.ColumnHeader]::new(); $colName.Text     = 'Name';      $colName.Width     = 280
    $colSize     = [System.Windows.Forms.ColumnHeader]::new(); $colSize.Text     = 'Groesse';   $colSize.Width     = 110
    $colPercent  = [System.Windows.Forms.ColumnHeader]::new(); $colPercent.Text  = 'Anteil';    $colPercent.Width  = 70
    $colFiles    = [System.Windows.Forms.ColumnHeader]::new(); $colFiles.Text    = 'Dateien';   $colFiles.Width    = 70
    $colModified = [System.Windows.Forms.ColumnHeader]::new(); $colModified.Text = 'Geaendert'; $colModified.Width = 110
    $listView.Columns.AddRange([System.Windows.Forms.ColumnHeader[]]@($colName, $colSize, $colPercent, $colFiles, $colModified))
    $splitContainer.Panel2.Controls.Add($listView)

    # ─────────────────────────────────────────────────────────────────────────
    # Scan-Ergebnisse (modulweit im Script-Scope des Cmdlets)
    # ─────────────────────────────────────────────────────────────────────────
    $script:currentScanResults = @()

    # ─────────────────────────────────────────────────────────────────────────
    # Hilfsfunktion: ListView und TreeView aus Scan-Ergebnissen befuellen
    #
    # Farbschema (analog zu Show-FolderTree / CLI):
    #   DarkCyan      – Root-Node (Startverzeichnis)
    #   DarkGreen     – vollstaendig lesbar, kleiner 100 MB
    #   DarkGoldenrod – vollstaendig lesbar, ab 100 MB
    #   DarkRed       – vollstaendig lesbar, ab 1 GB
    #   Red           – nicht zugaenglich, [Kein Zugriff] im Namen
    # ─────────────────────────────────────────────────────────────────────────
    $populateViews = {
        param ([array] $ScanResults, [string] $RootPath)

        $treeView.Nodes.Clear()
        $listView.Items.Clear()

        # Split-Path gibt fuer Laufwerkswurzeln (z.B. 'F:\') einen leeren String zurueck
        $rootNodeLabel = Split-Path -Path $RootPath -Leaf
        if ([string]::IsNullOrEmpty($rootNodeLabel)) { $rootNodeLabel = $RootPath }

        $rootNode           = [System.Windows.Forms.TreeNode]::new($rootNodeLabel)
        $rootNode.ForeColor = [System.Drawing.Color]::DarkCyan

        foreach ($scanResult in $ScanResults) {

            # ── TreeView: Name + Groesse + Farbe ──────────────────────────────
            if (-not $scanResult.IsAccessible) {
                $nodeLabel = "$($scanResult.Name)  [Kein Zugriff]"
                $nodeColor = [System.Drawing.Color]::Red
            }
            else {
                $nodeLabel = "$($scanResult.Name)  [$($scanResult.SizeFormatted)]"
                if ($scanResult.SizeBytes -ge 1GB) {
                    $nodeColor = [System.Drawing.Color]::DarkRed
                }
                elseif ($scanResult.SizeBytes -ge 100MB) {
                    $nodeColor = [System.Drawing.Color]::DarkGoldenrod
                }
                else {
                    $nodeColor = [System.Drawing.Color]::DarkGreen
                }
            }

            $treeNode           = [System.Windows.Forms.TreeNode]::new($nodeLabel)
            $treeNode.ForeColor = $nodeColor
            $treeNode.Tag       = $scanResult
            $rootNode.Nodes.Add($treeNode) | Out-Null

            # ── ListView: Name (mit Zugriffsmarkierung) ───────────────────────
            $displayName = if (-not $scanResult.IsAccessible) {
                "$($scanResult.Name)  [Kein Zugriff]"
            }
            else {
                $scanResult.Name
            }

            $listItem = [System.Windows.Forms.ListViewItem]::new($displayName)

            $lastModifiedText = if ($null -ne $scanResult.LastModified) {
                $scanResult.LastModified.ToString('dd.MM.yyyy')
            }
            else { '' }

            $listItem.SubItems.AddRange([string[]]@(
                $scanResult.SizeFormatted,
                "$($scanResult.SizePercent)%",
                "$($scanResult.FileCount)",
                $lastModifiedText
            ))

            # ── ListView Farbcodierung ─────────────────────────────────────────
            if (-not $scanResult.IsAccessible) {
                $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 220, 220)
                $listItem.ForeColor = [System.Drawing.Color]::DarkRed
            }
            elseif ($scanResult.SizeBytes -ge 1GB) {
                $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 220, 220)
                $listItem.ForeColor = [System.Drawing.Color]::DarkRed
            }
            elseif ($scanResult.SizeBytes -ge 100MB) {
                $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 248, 210)
                $listItem.ForeColor = [System.Drawing.Color]::FromArgb(130, 95, 0)
            }
            else {
                $listItem.BackColor = [System.Drawing.Color]::White
                $listItem.ForeColor = [System.Drawing.Color]::FromArgb(0, 110, 0)
            }

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
            [System.Windows.Forms.MessageBox]::Show(
                "Pfad nicht gefunden:`n$scanPath", 'Fehler',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }

        $statusLabel.Text    = "Scanne: $scanPath ..."
        $progressBar.Visible = $true
        $mainForm.Refresh()

        try {
            $scanResults               = Get-FolderSize -Path $scanPath
            $script:currentScanResults = $scanResults

            & $populateViews -ScanResults $scanResults -RootPath $scanPath

            $totalSizeSum   = ($scanResults | Measure-Object -Property SizeBytes -Sum).Sum
            $totalBytes     = if ($null -eq $totalSizeSum) { 0L } else { [long]$totalSizeSum }
            $totalFormatted = Format-FileSize -Bytes $totalBytes

            $statusLabel.Text = "Scan abgeschlossen. $($scanResults.Count) Eintraege | Gesamt: $totalFormatted"
        }
        catch {
            $statusLabel.Text = "Fehler beim Scan: $($_.Exception.Message)"
        }
        finally {
            $progressBar.Visible = $false
        }
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
    #
    # WICHTIG – Reihenfolge beim Hinzufuegen (WinForms Dock-Layout):
    # Controls werden in umgekehrter Z-Order-Reihenfolge gedockt.
    # Das Fill-Control (splitContainer) muss als ERSTES in die Collection,
    # damit es zuletzt gedockt wird und den verbleibenden Bereich korrekt fuellt.
    # Reihenfolge: Fill → Bottom (statusStrip) → Top (toolbarPanel)
    # ─────────────────────────────────────────────────────────────────────────
    $mainForm.Controls.AddRange([System.Windows.Forms.Control[]]@(
        $splitContainer,   # Fill  – wird zuletzt gedockt (korrekte Restflaeche)
        $statusStrip,      # Bottom
        $toolbarPanel      # Top   – wird zuerst gedockt, kein Overlap
    ))
    $mainForm.ShowDialog() | Out-Null
    $mainForm.Dispose()
}
