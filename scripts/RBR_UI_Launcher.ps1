#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$projectRoot = Split-Path -Parent $scriptDir
if (-not (Test-Path (Join-Path $projectRoot "assets"))) {
    # Backward compatibility for legacy flat layout.
    $projectRoot = $scriptDir
}

$autoScript = Join-Path $scriptDir "RBR_Auto_Installer.ps1"
$officialUrl = "https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr"
$qbtLatestDownloadUrl = "https://sourceforge.net/projects/qbittorrent/files/latest/download"
$assetsDir = Join-Path $projectRoot "assets"
$logoPng = Join-Path $assetsDir "RBR_INSTALLER.png"
if (-not (Test-Path $logoPng)) {
    $legacyLogo = Join-Path $projectRoot "RBR_INSTALLER.png"
    if (Test-Path $legacyLogo) { $logoPng = $legacyLogo }
}

$logDir = Join-Path $projectRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$runtimeLogPath = Join-Path $logDir "RBR_Auto_Installer.log"

$script:AppIcon = $null

if (-not (Test-Path $autoScript)) {
    [System.Windows.Forms.MessageBox]::Show("找不到 RBR_Auto_Installer.ps1，请确认文件完整。", "错误", "OK", "Error") | Out-Null
    exit 1
}

function Get-DefaultDownloadPath {
    # Most users keep game data on D: if available.
    try {
        $dDrive = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3 AND DeviceID='D:'" -ErrorAction SilentlyContinue
        if ($dDrive) {
            return "D:\RBR"
        }
    } catch {}

    # Otherwise pick the non-C fixed drive with the most free space.
    try {
        $candidates = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceID -and $_.DeviceID -notmatch '^[Cc]:$' } |
            Sort-Object FreeSpace -Descending
        if ($candidates -and $candidates.Count -gt 0) {
            return (Join-Path $candidates[0].DeviceID "RBR")
        }
    } catch {}

    try {
        $root = [System.IO.Path]::GetPathRoot($projectRoot)
        if ($root) {
            $drive = $root.TrimEnd('\\')
            if ($drive -and $drive -notmatch '^[Cc]:$') {
                return (Join-Path $drive "RBR")
            }
        }
    } catch {}
    return "E:\RBR"
}

function Get-DriveHintText {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return "盘符确认：未设置下载目录"
    }

    try {
        $root = [System.IO.Path]::GetPathRoot($Path)
        if (-not $root) {
            return "盘符确认：无法识别盘符，请检查路径"
        }
        $drive = $root.TrimEnd('\\')
        if ($drive -match '^[Cc]:$') {
            return "盘符确认：当前是 C 盘（不推荐），建议改为 D:\\RBR 或其他非 C 盘"
        }
        return "盘符确认：当前下载盘是 $drive（看起来正常）"
    } catch {
        return "盘符确认：路径解析失败，请检查"
    }
}

function Get-SelectableDrives {
    try {
        $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceID } |
            Select-Object -ExpandProperty DeviceID
        return @($drives | Sort-Object)
    } catch {
        return @("C:")
    }
}

function Resolve-AbsoluteUrl {
    param(
        [string]$BaseUrl,
        [string]$Href
    )

    if ([string]::IsNullOrWhiteSpace($Href)) { return $null }
    if ($Href -match '^(?i)https?://') { return $Href }

    try {
        $base = [System.Uri]::new($BaseUrl)
        return ([System.Uri]::new($base, $Href)).AbsoluteUri
    } catch {
        return $null
    }
}

function Get-RsfLatestLinks {
    param([string]$PageUrl)

    $resp = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -ErrorAction Stop
    $torrentUrl = $null
    $exeUrl = $null

    if ($resp.Links) {
        $torrentNode = $resp.Links |
            Where-Object { $_.href -and $_.href -match 'rsf_installer_files_.*\.torrent' } |
            Select-Object -First 1
        $exeNode = $resp.Links |
            Where-Object { $_.href -and $_.href -match 'Rallysimfans_Installer\.exe' } |
            Select-Object -First 1

        if ($torrentNode) { $torrentUrl = Resolve-AbsoluteUrl -BaseUrl $PageUrl -Href $torrentNode.href }
        if ($exeNode) { $exeUrl = Resolve-AbsoluteUrl -BaseUrl $PageUrl -Href $exeNode.href }
    }

    # 兼容某些情况下 Links 解析不完整
    if (-not $torrentUrl) {
        $m = [regex]::Match($resp.Content, 'href\s*=\s*"(?<u>[^"]*rsf_installer_files_[^"]*?\.torrent)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $torrentUrl = Resolve-AbsoluteUrl -BaseUrl $PageUrl -Href $m.Groups['u'].Value }
    }
    if (-not $exeUrl) {
        $m = [regex]::Match($resp.Content, 'href\s*=\s*"(?<u>[^"]*Rallysimfans_Installer\.exe[^"]*)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $exeUrl = Resolve-AbsoluteUrl -BaseUrl $PageUrl -Href $m.Groups['u'].Value }
    }

    if (-not $torrentUrl -or -not $exeUrl) {
        throw "未能从官网页面解析到 torrent 或 installer 链接。"
    }

    return @{
        TorrentUrl = $torrentUrl
        ExeUrl = $exeUrl
    }
}

function Get-AppIcon {
    if ($script:AppIcon) { return $script:AppIcon }
    if (-not (Test-Path $logoPng)) { return $null }

    try {
        $bmp = [System.Drawing.Bitmap]::FromFile($logoPng)
        $script:AppIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        return $script:AppIcon
    } catch {
        return $null
    }
}

function Show-RunMonitor {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$LogPath,
        [string]$PreferredInstaller = "",
        [string]$RelaunchArguments = ""
    )

    $mForm = New-Object System.Windows.Forms.Form
    $mForm.Text = "RBR 安装进度"
    $mForm.StartPosition = "CenterScreen"
    $mForm.Size = New-Object System.Drawing.Size(820, 520)
    $mForm.FormBorderStyle = "FixedDialog"
    $mForm.MaximizeBox = $false
    $mForm.MinimizeBox = $true
    $icon = Get-AppIcon
    if ($icon) { $mForm.Icon = $icon }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "状态：正在运行..."
    $lbl.Location = New-Object System.Drawing.Point(20, 15)
    $lbl.Size = New-Object System.Drawing.Size(770, 24)
    $mForm.Controls.Add($lbl)

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Location = New-Object System.Drawing.Point(20, 45)
    $bar.Size = New-Object System.Drawing.Size(680, 24)
    $bar.Minimum = 0
    $bar.Maximum = 100
    $bar.Style = "Continuous"
    $bar.Value = 0
    $mForm.Controls.Add($bar)

    $lblPct = New-Object System.Windows.Forms.Label
    $lblPct.Text = "0%"
    $lblPct.Location = New-Object System.Drawing.Point(710, 46)
    $lblPct.Size = New-Object System.Drawing.Size(80, 24)
    $lblPct.TextAlign = "MiddleRight"
    $mForm.Controls.Add($lblPct)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, 80)
    $txt.Size = New-Object System.Drawing.Size(770, 350)
    $txt.Multiline = $true
    $txt.ReadOnly = $true
    $txt.ScrollBars = "Vertical"
    $txt.Font = New-Object System.Drawing.Font("Consolas", 9)
    $mForm.Controls.Add($txt)

    $chkVerbose = New-Object System.Windows.Forms.CheckBox
    $chkVerbose.Text = "显示详细日志（高级）"
    $chkVerbose.Location = New-Object System.Drawing.Point(20, 446)
    $chkVerbose.Size = New-Object System.Drawing.Size(170, 24)
    $chkVerbose.Checked = $false
    $mForm.Controls.Add($chkVerbose)

    $btnOpenLog = New-Object System.Windows.Forms.Button
    $btnOpenLog.Text = "打开日志"
    $btnOpenLog.Location = New-Object System.Drawing.Point(250, 440)
    $btnOpenLog.Size = New-Object System.Drawing.Size(120, 32)
    $btnOpenLog.Add_Click({
        if (Test-Path $LogPath) { Start-Process notepad.exe -ArgumentList "`"$LogPath`"" | Out-Null }
    })
    $mForm.Controls.Add($btnOpenLog)

    $manualLaunchChosen = $false
    $waitingForQbtInstall = $false
    $qbtDownloadPromptShown = $false
    $currentProcess = $Process
    $timer = $null

    $btnLaunchNow = New-Object System.Windows.Forms.Button
    $btnLaunchNow.Text = "已完成下载，启动安装器"
    $btnLaunchNow.Location = New-Object System.Drawing.Point(530, 440)
    $btnLaunchNow.Size = New-Object System.Drawing.Size(150, 32)
    $btnLaunchNow.Enabled = $false
    $btnLaunchNow.Add_Click({
        try {
            if ($PreferredInstaller -and (Test-Path $PreferredInstaller)) {
                Start-Process -FilePath $PreferredInstaller | Out-Null
                $manualLaunchChosen = $true
                $phase = "manual-launched"
                $lbl.Text = "状态：已手动启动安装器（可关闭本窗口）"
                if ($bar.Value -lt 100) { $bar.Value = 100 }
                $lblPct.Text = "100%"
                $btnLaunchNow.Enabled = $false
                $btnClose.Enabled = $true
                if ($timer) { $timer.Stop() }
            } else {
                [System.Windows.Forms.MessageBox]::Show("当前未找到可用安装器文件，请先确认已下载完成。", "提示", "OK", "Warning") | Out-Null
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("启动安装器失败：$_", "错误", "OK", "Error") | Out-Null
        }
    })
    $mForm.Controls.Add($btnLaunchNow)

    $btnContinueQbt = New-Object System.Windows.Forms.Button
    $btnContinueQbt.Text = "我已安装 qB，继续"
    $btnContinueQbt.Location = New-Object System.Drawing.Point(380, 440)
    $btnContinueQbt.Size = New-Object System.Drawing.Size(140, 32)
    $btnContinueQbt.Enabled = $false
    $btnContinueQbt.Add_Click({
        if ([string]::IsNullOrWhiteSpace($RelaunchArguments)) {
            [System.Windows.Forms.MessageBox]::Show("当前无法继续，请关闭后重新开始。", "提示", "OK", "Warning") | Out-Null
            return
        }

        try {
            # 清空旧日志，避免“继续”后被上一轮失败日志覆盖状态显示。
            if (Test-Path $LogPath) {
                try { Clear-Content -Path $LogPath -ErrorAction SilentlyContinue } catch {}
            }

            $newProc = Start-Process -FilePath "powershell.exe" -ArgumentList $RelaunchArguments -WindowStyle Hidden -Verb RunAs -PassThru
            $currentProcess = $newProc
            $waitingForQbtInstall = $false
            $qbtDownloadPromptShown = $false
            $manualLaunchChosen = $false
            $phase = "idle"
            $btnContinueQbt.Enabled = $false
            $btnClose.Enabled = $false
            $btnLaunchNow.Enabled = $false
            $txt.Clear()
            $lastLine = 0
            $lastPrintedLine = ""
            if ($bar.Value -lt 5) { $bar.Value = 5 }
            $lblPct.Text = "$($bar.Value)%"
            $lbl.Text = "状态：已继续，正在重新检测 qBittorrent..."
            if ($timer) { $timer.Start() }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("继续失败：$_", "错误", "OK", "Error") | Out-Null
        }
    })
    $mForm.Controls.Add($btnContinueQbt)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "关闭"
    $btnClose.Location = New-Object System.Drawing.Point(690, 440)
    $btnClose.Size = New-Object System.Drawing.Size(120, 32)
    $btnClose.Enabled = $false
    $btnClose.Add_Click({ $mForm.Close() })
    $mForm.Controls.Add($btnClose)

    $lastLine = 0
    $lastPrintedLine = ""
    $phase = "idle"
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        try {
            if (Test-Path $LogPath) {
                $all = Get-Content -Path $LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($all) {
                    # 日志文件在新一轮运行时会被覆盖重写，检测到变短时清空 UI，避免旧日志和新日志混在一起
                    if ($all.Count -lt $lastLine) {
                        $txt.Clear()
                        $lastLine = 0
                        $lastPrintedLine = ""
                    }

                    if ($all.Count -gt $lastLine) {
                        $newLines = $all[$lastLine..($all.Count - 1)]
                        foreach ($l in $newLines) {
                            if ($l -and ($l -notmatch '\[PROGRESS\]')) {
                                # 重复等待提示只更新状态，不刷屏；且避免连续相同日志重复写入
                                if ($l -match '仍在等待下载完成\.\.\.') {
                                    $lbl.Text = "状态：仍在等待下载完成..."
                                }
                                else {
                                    $showLine = $true

                                    if (-not $chkVerbose.Checked) {
                                        # 默认精简模式：只显示关键步骤/告警/失败/完成提示
                                        $showLine = ($l -match '\[(WARN|FAIL)\]') -or
                                                    ($l -match '\[STEP\].*(步骤\s*[1-7]/7|以非 API 模式打开 Torrent|等待安装器文件出现并自动启动|监控下载进度)') -or
                                                    ($l -match '\[OK\].*(已自动启动安装器|已启动安装器|安装助手任务完成)')
                                    }

                                    if ($showLine -and $l -ne $lastPrintedLine) {
                                        $txt.AppendText($l + [Environment]::NewLine)
                                        $lastPrintedLine = $l
                                    }
                                }
                            }

                            if ($l -match '\[(STEP|OK|WARN|FAIL)\]\s*(.+)$') {
                                $msg = $matches[2]
                                if ($manualLaunchChosen) { continue }
                                # 当需要用户在 qB 弹窗点击 OK 时，避免被“仍在等待下载完成”反复覆盖
                                if ($phase -eq "wait-user-confirm" -and $msg -match '仍在等待下载完成') {
                                    # keep current prompt
                                } else {
                                    $lbl.Text = "状态：$msg"
                                }
                            }

                            if ($l -match '未检测到 qBittorrent|仍未找到 qBittorrent') {
                                $waitingForQbtInstall = $true
                                $lbl.Text = '状态：未检测到 qB，请安装后点击"我已安装 qB，继续"'
                                $btnContinueQbt.Enabled = -not [string]::IsNullOrWhiteSpace($RelaunchArguments)
                                $btnClose.Enabled = $true

                                if (-not $qbtDownloadPromptShown) {
                                    $qbtDownloadPromptShown = $true
                                    $ask = [System.Windows.Forms.MessageBox]::Show(
                                        "检测到未安装 qBittorrent。是否帮你下载最新版？`n`n点击 Yes 将打开官方下载（SourceForge Latest）。",
                                        "需要安装 qBittorrent",
                                        "YesNo",
                                        "Question"
                                    )
                                    if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
                                        try {
                                            Start-Process $qbtLatestDownloadUrl | Out-Null
                                            $lbl.Text = '状态：已打开 qB 下载页，请安装后点击"我已安装 qB，继续"'
                                        } catch {
                                            [System.Windows.Forms.MessageBox]::Show("打开下载页失败，请手动访问：$qbtLatestDownloadUrl", "提示", "OK", "Warning") | Out-Null
                                        }
                                    }
                                }
                            }

                            if ($l -match 'Preferred installer detected:\s*(.+)$') {
                                $PreferredInstaller = $matches[1].Trim()
                            }

                            if ($l -match '\[PROGRESS\]\s*QBT_STARTUP=(\d{1,3})') {
                                $v = [int]$matches[1]
                                if ($v -gt 100) { $v = 100 }
                                if ($v -lt 0) { $v = 0 }
                                $phase = "qbt-startup"
                                # 进度条单向递增，不回退，不重置
                                if ($v -gt $bar.Value) { $bar.Value = $v }
                                $lblPct.Text = "$($bar.Value)%"
                                $lbl.Text = "状态：正在打开并解析 torrent 种子文件（约 10-60 秒）..."
                            }

                            if ($l -match '\[PROGRESS\]\s*TORRENT=([0-9]+(\.[0-9]+)?)') {
                                $v = [int][double]$matches[1]
                                if ($v -gt 100) { $v = 100 }
                                if ($v -lt 0) { $v = 0 }
                                $phase = "torrent-download"
                                if ($v -gt $bar.Value) { $bar.Value = $v }
                                $lblPct.Text = "$($bar.Value)%"
                                $lbl.Text = "状态：正在下载安装包..."
                            }

                            if ($l -match '已调用 qBittorrent 打开 torrent|以非 API 模式打开 Torrent|当前为非 API 模式|请在 qBittorrent 弹出的窗口里') {
                                if ($phase -ne "torrent-download") {
                                    $phase = "wait-user-confirm"
                                    if ($bar.Value -lt 95) { $bar.Value = 95 }
                                    $lblPct.Text = "$($bar.Value)%"
                                    $lbl.Text = "状态：请在 qBittorrent 弹窗确认保存路径，并点击 OK"
                                    if ($PreferredInstaller -and (Test-Path $PreferredInstaller)) {
                                        $btnLaunchNow.Enabled = $true
                                    }
                                }
                            }

                            if ($l -match '已启动安装器：') {
                                $btnLaunchNow.Enabled = $false
                            }
                        }
                        $lastLine = $all.Count
                        $txt.SelectionStart = $txt.TextLength
                        $txt.ScrollToCaret()
                    }
                }
            }

            if ($currentProcess -and $currentProcess.HasExited) {
                $timer.Stop()
                if ($currentProcess.ExitCode -eq 0) {
                    $lbl.Text = "状态：流程结束（成功）"
                    $bar.Style = "Continuous"
                    $bar.Value = 100
                    $lblPct.Text = "100%"
                } else {
                    if ($waitingForQbtInstall -and -not [string]::IsNullOrWhiteSpace($RelaunchArguments)) {
                        $lbl.Text = '状态：qB 尚未就绪，请安装后点击"我已安装 qB，继续"'
                        $btnContinueQbt.Enabled = $true
                    } else {
                        $lbl.Text = "状态：流程结束（失败，退出码 $($currentProcess.ExitCode)）"
                        if (-not [string]::IsNullOrWhiteSpace($RelaunchArguments)) {
                            $btnContinueQbt.Enabled = $true
                        }
                    }
                }
                $btnLaunchNow.Enabled = $false
                $btnClose.Enabled = $true
            }
        } catch {
            $lbl.Text = "状态：读取进度时出错"
        }
    })

    $mForm.Add_FormClosed({
        try { $timer.Stop() } catch {}
    })

    $timer.Start()
    [void]$mForm.ShowDialog()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "RBR 安装助手（文件选择版）"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(780, 370)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$icon = Get-AppIcon
if ($icon) { $form.Icon = $icon }

if (Test-Path $logoPng) {
    try {
        $picLogo = New-Object System.Windows.Forms.PictureBox
        $picLogo.Location = New-Object System.Drawing.Point(700, 8)
        $picLogo.Size = New-Object System.Drawing.Size(56, 56)
        $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picLogo.Image = [System.Drawing.Image]::FromFile($logoPng)
        $form.Controls.Add($picLogo)
    } catch {}
}

$lblTips = New-Object System.Windows.Forms.Label
$lblTips.Text = "1) 选择 torrent 文件  2) 可选：指定安装器 EXE（固定版本）  3) 选择下载目录  4) 点开始"
$lblTips.Location = New-Object System.Drawing.Point(20, 18)
$lblTips.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblTips)

$lblTorrent = New-Object System.Windows.Forms.Label
$lblTorrent.Text = "Torrent 文件："
$lblTorrent.Location = New-Object System.Drawing.Point(20, 60)
$lblTorrent.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblTorrent)

$txtTorrent = New-Object System.Windows.Forms.TextBox
$txtTorrent.Location = New-Object System.Drawing.Point(140, 58)
$txtTorrent.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($txtTorrent)

$btnTorrent = New-Object System.Windows.Forms.Button
$btnTorrent.Text = "浏览..."
$btnTorrent.Location = New-Object System.Drawing.Point(670, 56)
$btnTorrent.Size = New-Object System.Drawing.Size(80, 28)
$btnTorrent.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "选择 torrent 文件"
    $dlg.Filter = "Torrent 文件 (*.torrent)|*.torrent|所有文件 (*.*)|*.*"
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtTorrent.Text = $dlg.FileName
    }
})
$form.Controls.Add($btnTorrent)

$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = "安装器 EXE（可选）："
$lblInstaller.Location = New-Object System.Drawing.Point(20, 106)
$lblInstaller.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblInstaller)

$txtInstaller = New-Object System.Windows.Forms.TextBox
$txtInstaller.Location = New-Object System.Drawing.Point(140, 104)
$txtInstaller.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($txtInstaller)

$btnInstaller = New-Object System.Windows.Forms.Button
$btnInstaller.Text = "浏览..."
$btnInstaller.Location = New-Object System.Drawing.Point(670, 102)
$btnInstaller.Size = New-Object System.Drawing.Size(80, 28)
$btnInstaller.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "选择安装器 EXE（可选）"
    $dlg.Filter = "可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*"
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstaller.Text = $dlg.FileName
    }
})
$form.Controls.Add($btnInstaller)

$lblDownload = New-Object System.Windows.Forms.Label
$lblDownload.Text = "下载盘符："
$lblDownload.Location = New-Object System.Drawing.Point(20, 152)
$lblDownload.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblDownload)

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = New-Object System.Drawing.Point(140, 150)
$cmbDrive.Size = New-Object System.Drawing.Size(95, 24)
$cmbDrive.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($cmbDrive)

$lblDownloadPath = New-Object System.Windows.Forms.Label
$lblDownloadPath.Text = "下载目录："
$lblDownloadPath.Location = New-Object System.Drawing.Point(245, 152)
$lblDownloadPath.Size = New-Object System.Drawing.Size(70, 24)
$form.Controls.Add($lblDownloadPath)

$txtDownload = New-Object System.Windows.Forms.TextBox
$txtDownload.Location = New-Object System.Drawing.Point(315, 150)
$txtDownload.Size = New-Object System.Drawing.Size(345, 24)
$form.Controls.Add($txtDownload)

$btnDownload = New-Object System.Windows.Forms.Button
$btnDownload.Text = "浏览..."
$btnDownload.Location = New-Object System.Drawing.Point(670, 148)
$btnDownload.Size = New-Object System.Drawing.Size(80, 28)
$btnDownload.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "选择下载目录"
    if ([string]::IsNullOrWhiteSpace($txtDownload.Text)) {
        $dlg.SelectedPath = Get-DefaultDownloadPath
    } else {
        $dlg.SelectedPath = $txtDownload.Text
    }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDownload.Text = $dlg.SelectedPath
    }
})
$form.Controls.Add($btnDownload)

$lblDriveHint = New-Object System.Windows.Forms.Label
$lblDriveHint.Text = "盘符确认：未设置下载目录"
$lblDriveHint.Location = New-Object System.Drawing.Point(140, 176)
$lblDriveHint.Size = New-Object System.Drawing.Size(610, 18)
$lblDriveHint.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($lblDriveHint)

$txtDownload.Add_TextChanged({
    $lblDriveHint.Text = Get-DriveHintText -Path $txtDownload.Text.Trim()

    try {
        $root = [System.IO.Path]::GetPathRoot($txtDownload.Text.Trim())
        if ($root) {
            $drive = $root.TrimEnd('\\')
            if ($cmbDrive.Items.Contains($drive) -and $cmbDrive.SelectedItem -ne $drive) {
                $cmbDrive.SelectedItem = $drive
            }
        }
    } catch {}

    if ($txtDownload.Text.Trim() -match '^[Cc]:\\') {
        $lblDriveHint.ForeColor = [System.Drawing.Color]::DarkRed
    } else {
        $lblDriveHint.ForeColor = [System.Drawing.Color]::DarkBlue
    }
})

$cmbDrive.Add_SelectedIndexChanged({
    if (-not $cmbDrive.SelectedItem) { return }
    $drive = [string]$cmbDrive.SelectedItem
    if (-not $drive.EndsWith('\\')) { $drive = "$drive\\" }

    $cur = $txtDownload.Text.Trim()
    $newPath = (Join-Path $drive "RBR")

    if ([string]::IsNullOrWhiteSpace($cur) -or $cur -match '^[A-Za-z]:\\RBR$' -or $cur -match '^[A-Za-z]:\\$') {
        $txtDownload.Text = $newPath
    } else {
        try {
            $leaf = Split-Path -Path $cur -Leaf
            if (-not $leaf) { $leaf = "RBR" }
            $txtDownload.Text = (Join-Path $drive $leaf)
        } catch {
            $txtDownload.Text = $newPath
        }
    }
})

$lblNote = New-Object System.Windows.Forms.Label
$lblNote.Text = "提示：安装器 EXE 不填也可以，脚本会自动查找。填了就优先用你选的版本。"
$lblNote.Location = New-Object System.Drawing.Point(20, 198)
$lblNote.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblNote)

$lblNote2 = New-Object System.Windows.Forms.Label
$lblNote2.Text = "如果没有文件：点【官网下载】手动下载 torrent 和 exe，然后回到本窗口选择文件。"
$lblNote2.Location = New-Object System.Drawing.Point(20, 222)
$lblNote2.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblNote2)

$btnOfficial = New-Object System.Windows.Forms.Button
$btnOfficial.Text = "官网下载"
$btnOfficial.Location = New-Object System.Drawing.Point(20, 270)
$btnOfficial.Size = New-Object System.Drawing.Size(120, 34)
$btnOfficial.Add_Click({
    try {
        Start-Process $officialUrl | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("无法自动打开官网，请手动复制下面链接到浏览器：`n$officialUrl", "提示", "OK", "Warning") | Out-Null
    }
})
$form.Controls.Add($btnOfficial)

$btnAutoDownload = New-Object System.Windows.Forms.Button
$btnAutoDownload.Text = "【强烈推荐】自动获取并下载"
$btnAutoDownload.Location = New-Object System.Drawing.Point(150, 270)
$btnAutoDownload.Size = New-Object System.Drawing.Size(250, 34)
$btnAutoDownload.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnAutoDownload)

$lblRecommend = New-Object System.Windows.Forms.Label
$lblRecommend.Text = "新手建议：优先点这个按钮，自动下载并填好文件路径"
$lblRecommend.Location = New-Object System.Drawing.Point(150, 246)
$lblRecommend.Size = New-Object System.Drawing.Size(350, 22)
$lblRecommend.ForeColor = [System.Drawing.Color]::DarkRed
$lblRecommend.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblRecommend)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "状态：等待操作"
$lblStatus.Location = New-Object System.Drawing.Point(20, 312)
$lblStatus.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblStatus)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "开始安装"
$btnStart.Location = New-Object System.Drawing.Point(510, 270)
$btnStart.Size = New-Object System.Drawing.Size(115, 34)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "取消"
$btnCancel.Location = New-Object System.Drawing.Point(635, 270)
$btnCancel.Size = New-Object System.Drawing.Size(115, 34)
$btnCancel.Add_Click({ $form.Close() })
$form.Controls.Add($btnCancel)

$btnAutoDownload.Add_Click({
    $download = $txtDownload.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($download)) {
        $download = Get-DefaultDownloadPath
        $txtDownload.Text = $download
    }

    if (-not (Test-Path $download)) {
        try {
            New-Item -Path $download -ItemType Directory -Force | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("下载目录创建失败，请换一个目录。", "错误", "OK", "Error") | Out-Null
            return
        }
    }

    $form.UseWaitCursor = $true
    $btnAutoDownload.Enabled = $false
    $btnStart.Enabled = $false
    $lblStatus.Text = "状态：正在读取官网链接..."
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $links = Get-RsfLatestLinks -PageUrl $officialUrl

        $torrentName = [System.IO.Path]::GetFileName(([System.Uri]$links.TorrentUrl).AbsolutePath)
        $exeName = [System.IO.Path]::GetFileName(([System.Uri]$links.ExeUrl).AbsolutePath)

        $torrentPath = Join-Path $download $torrentName
        $exePath = Join-Path $download $exeName

        $lblStatus.Text = "状态：正在下载 torrent..."
        [System.Windows.Forms.Application]::DoEvents()
        Invoke-WebRequest -Uri $links.TorrentUrl -OutFile $torrentPath -UseBasicParsing -ErrorAction Stop

        $lblStatus.Text = "状态：正在下载安装器 EXE..."
        [System.Windows.Forms.Application]::DoEvents()
        Invoke-WebRequest -Uri $links.ExeUrl -OutFile $exePath -UseBasicParsing -ErrorAction Stop

        $txtTorrent.Text = $torrentPath
        $txtInstaller.Text = $exePath

        $lblStatus.Text = "状态：下载完成，已自动填入文件路径。"
        [System.Windows.Forms.MessageBox]::Show("下载完成！已自动填好 torrent 和 exe 路径，直接点【开始安装】即可。", "完成", "OK", "Information") | Out-Null
    } catch {
        $lblStatus.Text = "状态：自动下载失败，请改用手动下载。"
        [System.Windows.Forms.MessageBox]::Show("自动获取失败：$_`n`n可点击【官网下载】后手动下载，再回到这里选择文件。", "提示", "OK", "Warning") | Out-Null
    } finally {
        $form.UseWaitCursor = $false
        $btnAutoDownload.Enabled = $true
        $btnStart.Enabled = $true
    }
})

$btnStart.Add_Click({
    $btnStart.Enabled = $false
    $torrent = $txtTorrent.Text.Trim()
    $installer = $txtInstaller.Text.Trim()
    $download = $txtDownload.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($torrent) -or -not (Test-Path $torrent)) {
        [System.Windows.Forms.MessageBox]::Show("请先选择有效的 torrent 文件。", "提示", "OK", "Warning") | Out-Null
        $btnStart.Enabled = $true
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($installer) -and -not (Test-Path $installer)) {
        [System.Windows.Forms.MessageBox]::Show("安装器 EXE 路径无效，请重新选择。", "提示", "OK", "Warning") | Out-Null
        $btnStart.Enabled = $true
        return
    }

    if ([string]::IsNullOrWhiteSpace($download)) {
        $download = Get-DefaultDownloadPath
        $txtDownload.Text = $download
    }

    if (-not (Test-Path $download)) {
        try {
            New-Item -Path $download -ItemType Directory -Force | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show("下载目录创建失败，请换一个目录。", "错误", "OK", "Error") | Out-Null
            $btnStart.Enabled = $true
            return
        }
    }

    $driveRoot = ""
    try { $driveRoot = [System.IO.Path]::GetPathRoot($download).TrimEnd('\\') } catch {}
    $confirmMsg = "请确认下载目录盘符是否正确：`n`n下载目录：$download`n盘符：$driveRoot`n`n确认无误后点击 Yes 继续。"
    $confirm = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "盘符确认", "YesNo", "Question")
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        $btnStart.Enabled = $true
        return
    }

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$autoScript`"",
        "-GuiMode",
        "-TorrentFile", "`"$torrent`"",
        "-DownloadPath", "`"$download`"",
        "-LogPath", "`"$runtimeLogPath`""
    )

    if (-not [string]::IsNullOrWhiteSpace($installer)) {
        $argList += @("-InstallerFile", "`"$installer`"")
    }

    $arguments = $argList -join " "

    try {
        $logPath = $runtimeLogPath
        $preferredInstallerForUi = ""
        if (-not [string]::IsNullOrWhiteSpace($installer)) {
            $preferredInstallerForUi = $installer
        } else {
            $candidate = Join-Path $download "Rallysimfans_Installer.exe"
            if (Test-Path $candidate) { $preferredInstallerForUi = $candidate }
        }
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -Verb RunAs -PassThru
        $form.Hide()
        Show-RunMonitor -Process $proc -LogPath $logPath -PreferredInstaller $preferredInstallerForUi -RelaunchArguments $arguments
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("启动失败：$_", "错误", "OK", "Error") | Out-Null
        $btnStart.Enabled = $true
    }
})

$defaultTorrent = @(
    Get-ChildItem -Path $projectRoot -Filter "*.torrent" -ErrorAction SilentlyContinue
    Get-ChildItem -Path $scriptDir -Filter "*.torrent" -ErrorAction SilentlyContinue
) | Select-Object -First 1
if ($defaultTorrent) { $txtTorrent.Text = $defaultTorrent.FullName }

$defaultInstaller = Join-Path $projectRoot "Rallysimfans_Installer.exe"
if (-not (Test-Path $defaultInstaller)) {
    $defaultInstaller = Join-Path $scriptDir "Rallysimfans_Installer.exe"
}
if (Test-Path $defaultInstaller) { $txtInstaller.Text = $defaultInstaller }

$drives = Get-SelectableDrives
foreach ($d in $drives) { [void]$cmbDrive.Items.Add($d) }

$txtDownload.Text = Get-DefaultDownloadPath
$defaultRoot = ""
try { $defaultRoot = [System.IO.Path]::GetPathRoot($txtDownload.Text).TrimEnd('\\') } catch {}
if ($defaultRoot -and $cmbDrive.Items.Contains($defaultRoot)) {
    $cmbDrive.SelectedItem = $defaultRoot
} elseif ($cmbDrive.Items.Count -gt 0) {
    $cmbDrive.SelectedIndex = 0
}

$lblDriveHint.Text = Get-DriveHintText -Path $txtDownload.Text
if ($txtDownload.Text.Trim() -match '^[Cc]:\\') {
    $lblDriveHint.ForeColor = [System.Drawing.Color]::DarkRed
}

[void]$form.ShowDialog()
