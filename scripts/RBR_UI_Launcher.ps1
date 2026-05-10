#Requires -Version 5.1

$script:StartupLog = Join-Path $env:TEMP 'RBR_Installer_startup.log'
function Write-StartupLog ($Msg) {
    try { Add-Content -Path $script:StartupLog -Value "$(Get-Date -Format 'HH:mm:ss') $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}
Write-StartupLog '=== RBR UI Launcher startup ==='

try {

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
$script:LangCode = 'zh'

$script:Strings = @{
    zh = @{
        'form.title'             = 'RBR 安装助手'
        'tips'                   = '1) 选择 torrent 文件  2) 可选：指定安装器 EXE（固定版本）  3) 选择下载目录  4) 点开始'
        'lbl.torrent'            = 'Torrent 文件：'
        'lbl.installer'          = '安装器 EXE（可选）：'
        'lbl.drive'              = '下载盘符：'
        'lbl.path'               = '下载目录：'
        'btn.browse'             = '浏览...'
        'btn.official'           = '官网下载'
        'btn.auto'               = '【强烈推荐】自动获取并下载'
        'btn.start'              = '开始安装'
        'btn.cancel'             = '取消'
        'lbl.recommend'          = '新手建议：优先点这个按钮，自动下载并填好文件路径'
        'lbl.note1'              = '提示：安装器 EXE 不填也可以，脚本会自动查找。填了就优先用你选的版本。'
        'lbl.note2'              = '如果没有文件：点【官网下载】手动下载 torrent 和 exe，然后回到本窗口选择文件。'
        'status.idle'            = '状态：等待操作'
        'status.fetching'        = '状态：正在读取官网链接...'
        'status.dl.torrent'      = '状态：正在下载 torrent...'
        'status.dl.exe'          = '状态：正在下载安装器 EXE...'
        'status.dl.done'         = '状态：下载完成，已自动填入文件路径。'
        'status.dl.fail'         = '状态：自动下载失败，请改用手动下载。'
        'dlg.official.fail'      = "无法自动打开官网，请手动复制下面链接到浏览器：`n{0}"
        'dlg.dl.done'            = '下载完成！已自动填好 torrent 和 exe 路径，直接点【开始安装】即可。'
        'dlg.dl.fail'            = "自动获取失败：{0}`n`n可点击【官网下载】后手动下载，再回到这里选择文件。"
        'dlg.no.torrent'         = '请先选择有效的 torrent 文件。'
        'dlg.bad.exe'            = '安装器 EXE 路径无效，请重新选择。'
        'dlg.mkdir.fail'         = '下载目录创建失败，请换一个目录。'
        'dlg.drive.confirm'      = "请确认下载目录盘符是否正确：`n`n下载目录：{0}`n盘符：{1}`n`n确认无误后点击 Yes 继续。"
        'dlg.drive.title'        = '盘符确认'
        'dlg.start.fail'         = '启动失败：{0}'
        'dlg.torrent.title'      = '选择 torrent 文件'
        'dlg.torrent.filter'     = 'Torrent 文件 (*.torrent)|*.torrent|所有文件 (*.*)|*.*'
        'dlg.exe.title'          = '选择安装器 EXE（可选）'
        'dlg.exe.filter'         = '可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*'
        'dlg.dir.title'          = '选择下载目录'
        'drive.none'             = '盘符确认：未设置下载目录'
        'drive.invalid'          = '盘符确认：无法识别盘符，请检查路径'
        'drive.c'                = '盘符确认：当前是 C 盘（不推荐），建议改为 D:\RBR 或其他非 C 盘'
        'drive.ok'               = '盘符确认：当前下载盘是 {0}（看起来正常）'
        'drive.err'              = '盘符确认：路径解析失败，请检查'
        'mon.title'              = 'RBR 安装进度'
        'mon.verbose'            = '显示详细日志（高级）'
        'mon.btn.qbdl'           = '下载 qB 最新版'
        'mon.btn.log'            = '打开日志'
        'mon.btn.launch'         = '已完成下载，启动安装器'
        'mon.btn.continue'       = '我已安装 qB，继续'
        'mon.btn.close'          = '关闭'
        'mon.status.run'         = '状态：正在运行...'
        'mon.status.wait'        = '状态：仍在等待下载完成...'
        'mon.status.qbdl'        = '状态：已打开 qB 下载页，请安装后点击"我已安装 qB，继续"'
        'mon.status.qbdl.fail'   = '打开下载页失败，请手动访问：{0}'
        'mon.status.manual'      = '状态：已手动启动安装器（可关闭本窗口）'
        'mon.status.noexe'       = '当前未找到可用安装器文件，请先确认已下载完成。'
        'mon.status.launchfail'  = '启动安装器失败：{0}'
        'mon.status.cantcont'    = '当前无法继续，请关闭后重新开始。'
        'mon.status.running'     = '当前任务仍在运行，请先等待。'
        'mon.status.retry'       = '状态：已继续，正在重新检测 qBittorrent...'
        'mon.status.retryfail'   = '继续失败：{0}'
        'mon.status.qb.startup'  = '状态：正在启动 qBittorrent...'
        'mon.status.dl'          = '状态：正在下载安装包...'
        'mon.status.path'        = '状态：请在 qBittorrent 弹窗确认保存路径，并点击 OK'
        'mon.status.seeding'     = '状态：下载完成！请点击【已完成下载，启动安装器】继续'
        'mon.status.success'     = '状态：流程结束（成功）'
        'mon.status.dup'         = '状态：检测到已有任务在运行，请不要重复启动'
        'mon.status.bg'          = '状态：后台仍在运行，等待进度更新...'
        'mon.status.qb.wait'     = '状态：qB 尚未就绪，请安装后点击"我已安装 qB，继续"'
        'mon.status.fail'        = '状态：流程结束（失败，退出码 {0}）'
        'mon.status.err'         = '状态：读取进度时出错'
        'mon.status.noqb'        = '状态：未检测到 qB，请安装后点击"我已安装 qB，继续"'
        'mon.popup.seeding'      = "下载已完成！`n点击【确定】立即启动安装器，点击【取消】稍后手动启动。`n`n路径：{0}"
        'mon.popup.seeding.title'= 'RBR 安装助手'
        'err.noexe'              = '找不到 RBR_Auto_Installer.ps1，请确认文件完整。'
        'err.title'              = '错误'
    }
    en = @{
        'form.title'             = 'RBR Installer Assistant'
        'tips'                   = '1) Select torrent  2) Optional: specify installer EXE  3) Choose download folder  4) Click Start'
        'lbl.torrent'            = 'Torrent File:'
        'lbl.installer'          = 'Installer EXE (optional):'
        'lbl.drive'              = 'Drive:'
        'lbl.path'               = 'Download Path:'
        'btn.browse'             = 'Browse...'
        'btn.official'           = 'Official Site'
        'btn.auto'               = '[Recommended] Auto-Download'
        'btn.start'              = 'Start'
        'btn.cancel'             = 'Cancel'
        'lbl.recommend'          = 'Beginners: click this first — downloads everything automatically'
        'lbl.note1'              = 'Tip: Installer EXE is optional, the script finds it automatically. Fill it to pin a version.'
        'lbl.note2'              = 'No files? Click [Official Site] to download manually, then select them here.'
        'status.idle'            = 'Status: Ready'
        'status.fetching'        = 'Status: Fetching links from official site...'
        'status.dl.torrent'      = 'Status: Downloading torrent...'
        'status.dl.exe'          = 'Status: Downloading installer EXE...'
        'status.dl.done'         = 'Status: Download complete. Paths filled automatically.'
        'status.dl.fail'         = 'Status: Auto-download failed. Please download manually.'
        'dlg.official.fail'      = "Cannot open browser. Copy this link manually:`n{0}"
        'dlg.dl.done'            = 'Download complete! Paths are filled. Click [Start] to continue.'
        'dlg.dl.fail'            = "Auto-download failed: {0}`n`nClick [Official Site] to download manually."
        'dlg.no.torrent'         = 'Please select a valid torrent file first.'
        'dlg.bad.exe'            = 'Installer EXE path is invalid. Please select again.'
        'dlg.mkdir.fail'         = 'Failed to create download folder. Choose a different path.'
        'dlg.drive.confirm'      = "Please confirm the download drive:`n`nPath: {0}`nDrive: {1}`n`nClick Yes to continue."
        'dlg.drive.title'        = 'Confirm Drive'
        'dlg.start.fail'         = 'Launch failed: {0}'
        'dlg.torrent.title'      = 'Select torrent file'
        'dlg.torrent.filter'     = 'Torrent files (*.torrent)|*.torrent|All files (*.*)|*.*'
        'dlg.exe.title'          = 'Select installer EXE (optional)'
        'dlg.exe.filter'         = 'Executable files (*.exe)|*.exe|All files (*.*)|*.*'
        'dlg.dir.title'          = 'Select download folder'
        'drive.none'             = 'Drive: no path set'
        'drive.invalid'          = 'Drive: cannot detect drive, check path'
        'drive.c'                = 'Drive: C drive (not recommended) — use D:\RBR or another drive'
        'drive.ok'               = 'Drive: {0} selected (looks good)'
        'drive.err'              = 'Drive: path error, please check'
        'mon.title'              = 'RBR Install Progress'
        'mon.verbose'            = 'Show verbose log (advanced)'
        'mon.btn.qbdl'           = 'Download latest qB'
        'mon.btn.log'            = 'Open Log'
        'mon.btn.launch'         = 'Launch Installer'
        'mon.btn.continue'       = "I've installed qB, continue"
        'mon.btn.close'          = 'Close'
        'mon.status.run'         = 'Status: Running...'
        'mon.status.wait'        = 'Status: Still waiting for download...'
        'mon.status.qbdl'        = "Status: qB download page opened — install then click `"I've installed qB, continue`""
        'mon.status.qbdl.fail'   = 'Failed to open download page. Visit manually: {0}'
        'mon.status.manual'      = 'Status: Installer launched manually (you may close this window)'
        'mon.status.noexe'       = 'No installer file found. Please confirm the download is complete.'
        'mon.status.launchfail'  = 'Failed to launch installer: {0}'
        'mon.status.cantcont'    = 'Cannot continue. Please close and restart.'
        'mon.status.running'     = 'A task is already running. Please wait.'
        'mon.status.retry'       = 'Status: Retrying — detecting qBittorrent...'
        'mon.status.retryfail'   = 'Retry failed: {0}'
        'mon.status.qb.startup'  = 'Status: Starting qBittorrent...'
        'mon.status.dl'          = 'Status: Downloading installer package...'
        'mon.status.path'        = 'Status: Confirm save path in qBittorrent dialog, then click OK'
        'mon.status.seeding'     = 'Status: Download complete! Click [Launch Installer] to continue'
        'mon.status.success'     = 'Status: Completed successfully'
        'mon.status.dup'         = 'Status: Another instance detected — do not start twice'
        'mon.status.bg'          = 'Status: Background task still running, waiting for updates...'
        'mon.status.qb.wait'     = "Status: qB not ready — install then click `"I've installed qB, continue`""
        'mon.status.fail'        = 'Status: Failed (exit code {0})'
        'mon.status.err'         = 'Status: Error reading progress'
        'mon.status.noqb'        = "Status: qB not found — install then click `"I've installed qB, continue`""
        'mon.popup.seeding'      = "Download complete!`nClick OK to launch the installer now, or Cancel to launch manually later.`n`nPath: {0}"
        'mon.popup.seeding.title'= 'RBR Installer Assistant'
        'err.noexe'              = 'RBR_Auto_Installer.ps1 not found. Please verify file integrity.'
        'err.title'              = 'Error'
    }
}

function T {
    param([string]$Key, [object[]]$Fmt)
    $s = $script:Strings[$script:LangCode][$Key]
    if (-not $s) { $s = $script:Strings['zh'][$Key] }
    if ($Fmt) { return ($s -f $Fmt) }
    return $s
}

if (-not (Test-Path $autoScript)) {
    [System.Windows.Forms.MessageBox]::Show((T 'err.noexe'), (T 'err.title'), "OK", "Error") | Out-Null
    exit 1
}

function Test-IsAdministrator {
    try {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($id)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Test-BackendRunLockInUse {
    try {
        $m = New-Object System.Threading.Mutex($false, "Global\RBR_Auto_Installer")
        $acquired = $m.WaitOne(0)
        $m.Dispose()
        return (-not $acquired)
    } catch {
        return $false
    }
}

function Start-BackendProcess {
    param([string]$Arguments)

    if (Test-BackendRunLockInUse) {
        throw "检测到后台任务已在运行，请等待当前任务结束后再继续。"
    }

    return Start-Process -FilePath "powershell.exe" -ArgumentList $Arguments -WindowStyle Hidden -PassThru
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

    if ([string]::IsNullOrWhiteSpace($Path)) { return (T 'drive.none') }
    try {
        $root = [System.IO.Path]::GetPathRoot($Path)
        if (-not $root) { return (T 'drive.invalid') }
        $drive = $root.TrimEnd('\\')
        if ($drive -match '^[Cc]:$') { return (T 'drive.c') }
        return (T 'drive.ok' $drive)
    } catch {
        return (T 'drive.err')
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
    $mForm.Text = (T 'mon.title')
    $mForm.StartPosition = "CenterScreen"
    $mForm.Size = New-Object System.Drawing.Size(820, 520)
    $mForm.FormBorderStyle = "FixedDialog"
    $mForm.MaximizeBox = $false
    $mForm.MinimizeBox = $true
    $icon = Get-AppIcon
    if ($icon) { $mForm.Icon = $icon }

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = (T 'mon.status.run')
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
    $chkVerbose.Text = (T 'mon.verbose')
    $chkVerbose.Location = New-Object System.Drawing.Point(20, 476)
    $chkVerbose.Size = New-Object System.Drawing.Size(170, 24)
    $chkVerbose.Checked = $false
    $mForm.Controls.Add($chkVerbose)

    $btnDownloadQbt = New-Object System.Windows.Forms.Button
    $btnDownloadQbt.Text = (T 'mon.btn.qbdl')
    $btnDownloadQbt.Location = New-Object System.Drawing.Point(20, 440)
    $btnDownloadQbt.Size = New-Object System.Drawing.Size(210, 32)
    $btnDownloadQbt.Enabled = $false
    $btnDownloadQbt.Add_Click({
        try {
            Start-Process $qbtLatestDownloadUrl | Out-Null
            $lbl.Text = (T 'mon.status.qbdl')
            $btnDownloadQbt.Text = (T 'mon.btn.qbdl')
            $btnDownloadQbt.Enabled = $false
        } catch {
            [System.Windows.Forms.MessageBox]::Show((T 'mon.status.qbdl.fail' $qbtLatestDownloadUrl), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
        }
    })
    $mForm.Controls.Add($btnDownloadQbt)

    $btnOpenLog = New-Object System.Windows.Forms.Button
    $btnOpenLog.Text = (T 'mon.btn.log')
    $btnOpenLog.Location = New-Object System.Drawing.Point(250, 440)
    $btnOpenLog.Size = New-Object System.Drawing.Size(120, 32)
    $btnOpenLog.Add_Click({
        if (Test-Path $LogPath) { Start-Process notepad.exe -ArgumentList "`"$LogPath`"" | Out-Null }
    })
    $mForm.Controls.Add($btnOpenLog)

    $manualLaunchChosen = $false
    $waitingForQbtInstall = $false
    $seedingPopupShown = $false
    $currentProcess = $Process
    $timer = $null

    $btnLaunchNow = New-Object System.Windows.Forms.Button
    $btnLaunchNow.Text = (T 'mon.btn.launch')
    $btnLaunchNow.Location = New-Object System.Drawing.Point(530, 440)
    $btnLaunchNow.Size = New-Object System.Drawing.Size(150, 32)
    $btnLaunchNow.Enabled = $false
    $btnLaunchNow.Add_Click({
        try {
            if ($PreferredInstaller -and (Test-Path $PreferredInstaller)) {
                Start-Process -FilePath $PreferredInstaller | Out-Null
                $manualLaunchChosen = $true
                $phase = "manual-launched"
                $lbl.Text = (T 'mon.status.manual')
                if ($bar.Value -lt 100) { $bar.Value = 100 }
                $lblPct.Text = "100%"
                $btnLaunchNow.Enabled = $false
                $btnClose.Enabled = $true
                if ($timer) { $timer.Stop() }
            } else {
                [System.Windows.Forms.MessageBox]::Show((T 'mon.status.noexe'), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show((T 'mon.status.launchfail' "$_"), (T 'err.title'), "OK", "Error") | Out-Null
        }
    })
    $mForm.Controls.Add($btnLaunchNow)

    $btnContinueQbt = New-Object System.Windows.Forms.Button
    $btnContinueQbt.Text = (T 'mon.btn.continue')
    $btnContinueQbt.Location = New-Object System.Drawing.Point(380, 440)
    $btnContinueQbt.Size = New-Object System.Drawing.Size(140, 32)
    $btnContinueQbt.Enabled = $false
    $btnContinueQbt.Add_Click({
        if ([string]::IsNullOrWhiteSpace($RelaunchArguments)) {
            [System.Windows.Forms.MessageBox]::Show((T 'mon.status.cantcont'), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
            return
        }

        if ((Test-BackendRunLockInUse) -or ($currentProcess -and -not $currentProcess.HasExited)) {
            [System.Windows.Forms.MessageBox]::Show((T 'mon.status.running'), (T 'mon.popup.seeding.title'), "OK", "Information") | Out-Null
            return
        }

        try {
            # 清空旧日志，避免“继续”后被上一轮失败日志覆盖状态显示。
            if (Test-Path $LogPath) {
                try { Clear-Content -Path $LogPath -ErrorAction SilentlyContinue } catch {}
            }

            $newProc = Start-BackendProcess -Arguments $RelaunchArguments
            $currentProcess = $newProc
            $waitingForQbtInstall = $false
            $manualLaunchChosen = $false
            $phase = "idle"
            $btnDownloadQbt.Text = (T 'mon.btn.qbdl')
            $btnDownloadQbt.Enabled = $false
            $btnContinueQbt.Enabled = $false
            $btnClose.Enabled = $false
            $btnLaunchNow.Enabled = $false
            $txt.Clear()
            $lastLine = 0
            $lastPrintedLine = ""
            if ($bar.Value -lt 5) { $bar.Value = 5 }
            $lblPct.Text = "$($bar.Value)%"
            $lbl.Text = (T 'mon.status.retry')
            if ($timer) { $timer.Start() }
        } catch {
            [System.Windows.Forms.MessageBox]::Show((T 'mon.status.retryfail' "$_"), (T 'err.title'), "OK", "Error") | Out-Null
        }
    })
    $mForm.Controls.Add($btnContinueQbt)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = (T 'mon.btn.close')
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
                                    $lbl.Text = (T 'mon.status.wait')
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
                                if ($phase -eq “wait-user-confirm” -and $msg -match '仍在等待下载完成') {
                                    # keep current prompt
                                } elseif ($script:LangCode -eq 'zh') {
                                    $lbl.Text = “状态：$msg”
                                }
                            }

                            if ($l -match '未检测到 qBittorrent|仍未找到 qBittorrent') {
                                $waitingForQbtInstall = $true
                                $lbl.Text = (T 'mon.status.noqb')
                                $btnContinueQbt.Enabled = -not [string]::IsNullOrWhiteSpace($RelaunchArguments)
                                $btnDownloadQbt.Text = (T 'mon.btn.qbdl')
                                $btnDownloadQbt.Enabled = $true
                                $btnClose.Enabled = $true
                            }

                            if ($l -match 'Preferred installer detected:\s*(.+)$') {
                                $PreferredInstaller = $matches[1].Trim()
                            }

                            if ($l -match '\[PROGRESS\]\s*QBT_STARTUP=(\d{1,3})') {
                                $v = [int]$matches[1]
                                if ($v -gt 100) { $v = 100 }
                                if ($v -lt 0) { $v = 0 }
                                $phase = "qbt-startup"
                                if ($v -gt $bar.Value) { $bar.Value = $v }
                                $lblPct.Text = "$($bar.Value)%"
                                $lbl.Text = (T 'mon.status.qb.startup')
                            }

                            if ($l -match '\[PROGRESS\]\s*TORRENT=([0-9]+(\.[0-9]+)?)') {
                                $v = [int][double]$matches[1]
                                if ($v -gt 100) { $v = 100 }
                                if ($v -lt 0) { $v = 0 }
                                $phase = "torrent-download"
                                if ($v -gt $bar.Value) { $bar.Value = $v }
                                $lblPct.Text = "$($bar.Value)%"
                                $lbl.Text = (T 'mon.status.dl')
                            }

                            if ($l -match '已调用 qBittorrent 打开 torrent|以非 API 模式打开 Torrent|当前为非 API 模式|请在 qBittorrent 弹出的窗口里') {
                                if ($phase -ne "torrent-download") {
                                    $phase = "wait-user-confirm"
                                    if ($bar.Value -lt 95) { $bar.Value = 95 }
                                    $lblPct.Text = "$($bar.Value)%"
                                    $lbl.Text = (T 'mon.status.path')
                                    if ($PreferredInstaller -and (Test-Path $PreferredInstaller)) {
                                        $btnLaunchNow.Enabled = $true
                                    }
                                }
                            }

                            if ((-not $seedingPopupShown) -and ($l -match '\[INFO\]\s*SEEDING_LAUNCH_READY=(.+)')) {
                                $seedingPopupShown = $true
                                $launchPath = $matches[1].Trim()
                                $PreferredInstaller = $launchPath
                                $bar.Value = 100
                                $lblPct.Text = '100%'
                                $lbl.Text = (T 'mon.status.seeding')
                                $result = [System.Windows.Forms.MessageBox]::Show(
                                    (T 'mon.popup.seeding' $launchPath),
                                    (T 'mon.popup.seeding.title'),
                                    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
                                    [System.Windows.Forms.MessageBoxIcon]::Information
                                )
                                if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                                    try {
                                        Start-Process -FilePath $launchPath | Out-Null
                                        $lbl.Text = (T 'mon.status.manual')
                                        $btnLaunchNow.Enabled = $false
                                        $btnClose.Enabled = $true
                                    } catch {
                                        [System.Windows.Forms.MessageBox]::Show((T 'mon.status.launchfail' "$_"), (T 'err.title'), "OK", "Error") | Out-Null
                                    }
                                } else {
                                    $btnLaunchNow.Enabled = $true
                                    $btnLaunchNow.Font = New-Object System.Drawing.Font($btnLaunchNow.Font, [System.Drawing.FontStyle]::Bold)
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
                if ($currentProcess.ExitCode -eq 0) {
                    $timer.Stop()
                    $lbl.Text = (T 'mon.status.success')
                    $bar.Style = "Continuous"
                    $bar.Value = 100
                    $lblPct.Text = "100%"
                } elseif ($currentProcess.ExitCode -eq 2) {
                    $timer.Stop()
                    $lbl.Text = (T 'mon.status.dup')
                    $btnContinueQbt.Enabled = $true
                    $btnClose.Enabled = $true
                } else {
                    $logStillActive = $false
                    try {
                        if (Test-Path $LogPath) {
                            $lastWrite = (Get-Item -Path $LogPath -ErrorAction SilentlyContinue).LastWriteTime
                            if ($lastWrite -and (((Get-Date) - $lastWrite).TotalSeconds -le 8)) {
                                $logStillActive = $true
                            }
                        }
                    } catch {}

                    if ($logStillActive) {
                        $lbl.Text = (T 'mon.status.bg')
                        $currentProcess = $null
                        return
                    }

                    $timer.Stop()
                    if ($waitingForQbtInstall -and -not [string]::IsNullOrWhiteSpace($RelaunchArguments)) {
                        $lbl.Text = (T 'mon.status.qb.wait')
                        $btnDownloadQbt.Text = (T 'mon.btn.qbdl')
                        $btnDownloadQbt.Enabled = $true
                        $btnContinueQbt.Enabled = $true
                    } else {
                        $lbl.Text = (T 'mon.status.fail' $currentProcess.ExitCode)
                        if (-not [string]::IsNullOrWhiteSpace($RelaunchArguments)) {
                            $btnContinueQbt.Enabled = $true
                        }
                    }
                }
                if (-not $seedingPopupShown) { $btnLaunchNow.Enabled = $false }
                $btnClose.Enabled = $true
            }
        } catch {
            $lbl.Text = (T 'mon.status.err')
        }
    })

    $mForm.Add_FormClosed({
        try { $timer.Stop() } catch {}
        try {
            if ($currentProcess -and -not $currentProcess.HasExited) {
                $currentProcess.Kill()
            }
        } catch {}
    })

    $timer.Start()
    [void]$mForm.ShowDialog()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = (T 'form.title')
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(780, 370)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$icon = Get-AppIcon
if ($icon) { $form.Icon = $icon }

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Location = New-Object System.Drawing.Point(620, 8)
$cmbLang.Size = New-Object System.Drawing.Size(70, 24)
$cmbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$cmbLang.Items.Add('中文')
[void]$cmbLang.Items.Add('EN')
$cmbLang.SelectedIndex = 0
$form.Controls.Add($cmbLang)

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
$lblTips.Text = (T 'tips')
$lblTips.Location = New-Object System.Drawing.Point(20, 18)
$lblTips.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblTips)

$lblTorrent = New-Object System.Windows.Forms.Label
$lblTorrent.Text = (T 'lbl.torrent')
$lblTorrent.Location = New-Object System.Drawing.Point(20, 60)
$lblTorrent.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblTorrent)

$txtTorrent = New-Object System.Windows.Forms.TextBox
$txtTorrent.Location = New-Object System.Drawing.Point(140, 58)
$txtTorrent.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($txtTorrent)

$btnTorrent = New-Object System.Windows.Forms.Button
$btnTorrent.Text = (T 'btn.browse')
$btnTorrent.Location = New-Object System.Drawing.Point(670, 56)
$btnTorrent.Size = New-Object System.Drawing.Size(80, 28)
$btnTorrent.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = (T 'dlg.torrent.title')
    $dlg.Filter = (T 'dlg.torrent.filter')
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtTorrent.Text = $dlg.FileName
    }
})
$form.Controls.Add($btnTorrent)

$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = (T 'lbl.installer')
$lblInstaller.Location = New-Object System.Drawing.Point(20, 106)
$lblInstaller.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblInstaller)

$txtInstaller = New-Object System.Windows.Forms.TextBox
$txtInstaller.Location = New-Object System.Drawing.Point(140, 104)
$txtInstaller.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($txtInstaller)

$btnInstaller = New-Object System.Windows.Forms.Button
$btnInstaller.Text = (T 'btn.browse')
$btnInstaller.Location = New-Object System.Drawing.Point(670, 102)
$btnInstaller.Size = New-Object System.Drawing.Size(80, 28)
$btnInstaller.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = (T 'dlg.exe.title')
    $dlg.Filter = (T 'dlg.exe.filter')
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstaller.Text = $dlg.FileName
    }
})
$form.Controls.Add($btnInstaller)

$lblDownload = New-Object System.Windows.Forms.Label
$lblDownload.Text = (T 'lbl.drive')
$lblDownload.Location = New-Object System.Drawing.Point(20, 152)
$lblDownload.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($lblDownload)

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = New-Object System.Drawing.Point(140, 150)
$cmbDrive.Size = New-Object System.Drawing.Size(95, 24)
$cmbDrive.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($cmbDrive)

$lblDownloadPath = New-Object System.Windows.Forms.Label
$lblDownloadPath.Text = (T 'lbl.path')
$lblDownloadPath.Location = New-Object System.Drawing.Point(245, 152)
$lblDownloadPath.Size = New-Object System.Drawing.Size(70, 24)
$form.Controls.Add($lblDownloadPath)

$txtDownload = New-Object System.Windows.Forms.TextBox
$txtDownload.Location = New-Object System.Drawing.Point(315, 150)
$txtDownload.Size = New-Object System.Drawing.Size(345, 24)
$form.Controls.Add($txtDownload)

$btnDownload = New-Object System.Windows.Forms.Button
$btnDownload.Text = (T 'btn.browse')
$btnDownload.Location = New-Object System.Drawing.Point(670, 148)
$btnDownload.Size = New-Object System.Drawing.Size(80, 28)
$btnDownload.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = (T 'dlg.dir.title')
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
$lblDriveHint.Text = (T 'drive.none')
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
$lblNote.Text = (T 'lbl.note1')
$lblNote.Location = New-Object System.Drawing.Point(20, 198)
$lblNote.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblNote)

$lblNote2 = New-Object System.Windows.Forms.Label
$lblNote2.Text = (T 'lbl.note2')
$lblNote2.Location = New-Object System.Drawing.Point(20, 222)
$lblNote2.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblNote2)

$btnOfficial = New-Object System.Windows.Forms.Button
$btnOfficial.Text = (T 'btn.official')
$btnOfficial.Location = New-Object System.Drawing.Point(20, 270)
$btnOfficial.Size = New-Object System.Drawing.Size(120, 34)
$btnOfficial.Add_Click({
    try {
        Start-Process $officialUrl | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.official.fail' $officialUrl), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
    }
})
$form.Controls.Add($btnOfficial)

$btnAutoDownload = New-Object System.Windows.Forms.Button
$btnAutoDownload.Text = (T 'btn.auto')
$btnAutoDownload.Location = New-Object System.Drawing.Point(150, 270)
$btnAutoDownload.Size = New-Object System.Drawing.Size(250, 34)
$btnAutoDownload.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnAutoDownload)

$lblRecommend = New-Object System.Windows.Forms.Label
$lblRecommend.Text = (T 'lbl.recommend')
$lblRecommend.Location = New-Object System.Drawing.Point(150, 246)
$lblRecommend.Size = New-Object System.Drawing.Size(350, 22)
$lblRecommend.ForeColor = [System.Drawing.Color]::DarkRed
$lblRecommend.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblRecommend)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = (T 'status.idle')
$lblStatus.Location = New-Object System.Drawing.Point(20, 312)
$lblStatus.Size = New-Object System.Drawing.Size(730, 24)
$form.Controls.Add($lblStatus)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = (T 'btn.start')
$btnStart.Location = New-Object System.Drawing.Point(510, 270)
$btnStart.Size = New-Object System.Drawing.Size(115, 34)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = (T 'btn.cancel')
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
            [System.Windows.Forms.MessageBox]::Show((T 'dlg.mkdir.fail'), (T 'err.title'), "OK", "Error") | Out-Null
            return
        }
    }

    $form.UseWaitCursor = $true
    $btnAutoDownload.Enabled = $false
    $btnStart.Enabled = $false
    $lblStatus.Text = (T 'status.fetching')
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $links = Get-RsfLatestLinks -PageUrl $officialUrl

        $torrentName = [System.IO.Path]::GetFileName(([System.Uri]$links.TorrentUrl).AbsolutePath)
        $exeName = [System.IO.Path]::GetFileName(([System.Uri]$links.ExeUrl).AbsolutePath)

        $torrentPath = Join-Path $download $torrentName
        $exePath = Join-Path $download $exeName

        $lblStatus.Text = (T 'status.dl.torrent')
        [System.Windows.Forms.Application]::DoEvents()
        Invoke-WebRequest -Uri $links.TorrentUrl -OutFile $torrentPath -UseBasicParsing -ErrorAction Stop

        $lblStatus.Text = (T 'status.dl.exe')
        [System.Windows.Forms.Application]::DoEvents()
        Invoke-WebRequest -Uri $links.ExeUrl -OutFile $exePath -UseBasicParsing -ErrorAction Stop

        $txtTorrent.Text = $torrentPath
        $txtInstaller.Text = $exePath

        $lblStatus.Text = (T 'status.dl.done')
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.dl.done'), (T 'mon.popup.seeding.title'), "OK", "Information") | Out-Null
    } catch {
        $lblStatus.Text = (T 'status.dl.fail')
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.dl.fail' "$_"), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
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
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.no.torrent'), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
        $btnStart.Enabled = $true
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($installer) -and -not (Test-Path $installer)) {
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.bad.exe'), (T 'mon.popup.seeding.title'), "OK", "Warning") | Out-Null
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
            [System.Windows.Forms.MessageBox]::Show((T 'dlg.mkdir.fail'), (T 'err.title'), "OK", "Error") | Out-Null
            $btnStart.Enabled = $true
            return
        }
    }

    $driveRoot = ""
    try { $driveRoot = [System.IO.Path]::GetPathRoot($download).TrimEnd('\\') } catch {}
    $confirm = [System.Windows.Forms.MessageBox]::Show((T 'dlg.drive.confirm' $download, $driveRoot), (T 'dlg.drive.title'), "YesNo", "Question")
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
        $proc = Start-BackendProcess -Arguments $arguments
        $form.Hide()
        Show-RunMonitor -Process $proc -LogPath $logPath -PreferredInstaller $preferredInstallerForUi -RelaunchArguments $arguments
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.start.fail' "$_"), (T 'err.title'), "OK", "Error") | Out-Null
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

function Apply-MainFormLanguage {
    $form.Text         = (T 'form.title')
    $lblTips.Text      = (T 'tips')
    $lblTorrent.Text   = (T 'lbl.torrent')
    $lblInstaller.Text = (T 'lbl.installer')
    $lblDownload.Text  = (T 'lbl.drive')
    $lblDownloadPath.Text = (T 'lbl.path')
    $btnTorrent.Text   = (T 'btn.browse')
    $btnInstaller.Text = (T 'btn.browse')
    $btnDownload.Text  = (T 'btn.browse')
    $btnOfficial.Text  = (T 'btn.official')
    $btnAutoDownload.Text = (T 'btn.auto')
    $lblRecommend.Text = (T 'lbl.recommend')
    $lblNote.Text      = (T 'lbl.note1')
    $lblNote2.Text     = (T 'lbl.note2')
    $btnStart.Text     = (T 'btn.start')
    $btnCancel.Text    = (T 'btn.cancel')
    $lblStatus.Text    = (T 'status.idle')
    $lblDriveHint.Text = Get-DriveHintText -Path $txtDownload.Text.Trim()
}

$cmbLang.Add_SelectedIndexChanged({
    $script:LangCode = if ($cmbLang.SelectedIndex -eq 0) { 'zh' } else { 'en' }
    Apply-MainFormLanguage
})

Write-StartupLog 'Form ready, calling ShowDialog'
[void]$form.ShowDialog()

} catch {
    Write-StartupLog "FATAL: $_`n$($_.ScriptStackTrace)"
    try {
        [System.Windows.Forms.MessageBox]::Show(
            "$(T 'form.title') 启动失败，错误已记录到：`n$script:StartupLog`n`n$_",
            'RBR 安装助手',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Startup failed. Log: $script:StartupLog`n`n$_",
            'RBR Install Assistant',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}
