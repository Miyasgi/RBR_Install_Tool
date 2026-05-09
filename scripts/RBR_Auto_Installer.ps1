#Requires -Version 5.1
<#
.SYNOPSIS
    RBR / Rally Sim Fans 自动安装助手
.DESCRIPTION
    自动将 .torrent 添加到 qBittorrent，监控下载进度，
    100% 完成后自动打开 RSF 安装器。
.PARAMETER TorrentFile
    .torrent 文件路径。留空时自动扫描脚本同目录。
.PARAMETER DownloadPath
    torrent 内容的保存路径，默认自动选非 C 盘，例如 E:\RBR
.PARAMETER InstallerFile
    指定安装器 EXE 路径。指定后会优先启动该文件（用于固定版本）。
.PARAMETER QbtHost
    qBittorrent Web UI 地址，默认 127.0.0.1
.PARAMETER QbtPort
    qBittorrent Web UI 端口，默认 8080
.PARAMETER QbtUser
    qBittorrent Web UI 用户名，默认 admin
.PARAMETER QbtPass
    qBittorrent Web UI 密码，默认 adminadmin
.PARAMETER PollSeconds
    进度检查间隔（秒），默认 15
.EXAMPLE
    .\RBR_Auto_Installer.ps1
.EXAMPLE
    .\RBR_Auto_Installer.ps1 -DownloadPath "D:\Games\RBR" -QbtPass "mypassword"
#>

[CmdletBinding()]
param(
    [string] $TorrentFile   = "",
    [string] $DownloadPath  = "",
    [string] $InstallerFile = "",
    [switch] $GuiMode,
    [string] $QbtHost       = "127.0.0.1",
    [int]    $QbtPort       = 8080,
    [string] $QbtUser       = "admin",
    [string] $QbtPass       = "adminadmin",
    [int]    $PollSeconds   = 15,
    [string] $LogPath       = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$script:ProjectRoot = Split-Path -Parent $script:ScriptDir
if (-not (Test-Path (Join-Path $script:ProjectRoot "assets"))) {
    # Backward compatibility for legacy flat layout.
    $script:ProjectRoot = $script:ScriptDir
}

$script:SingleInstanceMutex = $null
try {
    $createdNew = $false
    $script:SingleInstanceMutex = New-Object System.Threading.Mutex($true, "Global\\RBR_Auto_Installer_SingleInstance", [ref]$createdNew)
    if (-not $createdNew) {
        Write-Host "[!] 检测到安装助手已在运行，本次启动已取消。" -ForegroundColor Yellow
        exit 2
    }
} catch {}

$defaultLogPath = Join-Path (Join-Path $script:ProjectRoot "logs") "RBR_Auto_Installer.log"
$script:LogPath    = if ($LogPath) { $LogPath } else { $defaultLogPath }
$script:StartTime  = Get-Date
$script:RsfOfficialDownloadPage = "https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr"
$script:QbtLatestDownloadLink = "https://sourceforge.net/projects/qbittorrent/files/latest/download"

$script:TorrentAlreadyOpened = $false
$script:RunLockStream = $null
$script:RunLockPath = Join-Path $script:ProjectRoot "RBR_Auto_Installer.lock"
try {
    $lockDir = Split-Path -Parent $script:RunLockPath
    if ($lockDir -and -not (Test-Path $lockDir)) {
        New-Item -Path $lockDir -ItemType Directory -Force | Out-Null
    }

    $script:RunLockStream = [System.IO.File]::Open($script:RunLockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $lockText = "PID=$PID; START=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockText)
    $script:RunLockStream.SetLength(0)
    $script:RunLockStream.Write($bytes, 0, $bytes.Length)
    $script:RunLockStream.Flush()
} catch {
    Write-Host "[!] 检测到安装助手已在运行（文件锁占用），本次启动已取消。" -ForegroundColor Yellow
    exit 2
}

try {
    $logDir = Split-Path -Parent $script:LogPath
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    "===== Run Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====" | Set-Content -Path $script:LogPath -Encoding UTF8
} catch {}

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    try {
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -Path $script:LogPath -Value $line -Encoding UTF8
    } catch {}
}

# ─── 输出辅助函数 ──────────────────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "[*] $msg" -ForegroundColor Cyan;   Write-Log -Level "STEP" -Message $msg }
function Write-OK   { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green; Write-Log -Level "OK"   -Message $msg }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow; Write-Log -Level "WARN" -Message $msg }
function Write-Fail { param($msg) Write-Host "[X] $msg" -ForegroundColor Red;    Write-Log -Level "FAIL" -Message $msg }

function Read-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    if ($GuiMode) {
        Write-Log -Level "INFO" -Message "GuiMode input prompt skipped: $Prompt (default='$Default')"
        return $Default
    }
    return (Read-Host $Prompt)
}

function Pause-IfConsole {
    param([string]$Prompt = "按 Enter 退出")
    if (-not $GuiMode) {
        Read-Host $Prompt | Out-Null
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "  │     RBR / Rally Sim Fans  自动安装助手 v1.0      │" -ForegroundColor Magenta
    Write-Host "  │     需要 qBittorrent (推荐 4.x 以上版本)         │" -ForegroundColor Magenta
    Write-Host "  └──────────────────────────────────────────────────┘" -ForegroundColor Magenta
    Write-Host ""
}

# ─── 路径校验（不允许危险目录）────────────────────────────────────────────────
function Assert-SafePath {
    param([string]$Path)
    $forbidden = @(
        [System.Environment]::GetFolderPath("ProgramFiles"),
        [System.Environment]::GetFolderPath("ProgramFilesX86"),
        [System.Environment]::GetFolderPath("Desktop"),
        [System.Environment]::GetFolderPath("UserProfile"),
        [System.Environment]::GetFolderPath("MyDocuments")
    ) | Where-Object { $_ }

    foreach ($bad in $forbidden) {
        if ($Path.TrimEnd('\') -eq $bad.TrimEnd('\') -or
            $Path.StartsWith($bad.TrimEnd('\') + '\')) {
            return $false
        }
    }
    return $true
}

function Get-RecommendedDownloadPath {
    param([string]$ScriptDir)

    # 优先使用脚本所在盘（若为非 C 盘）
    try {
        if ($ScriptDir) {
            $root = [System.IO.Path]::GetPathRoot($ScriptDir)
            if ($root) {
                $drive = $root.TrimEnd('\\')
                if ($drive -and $drive -notmatch '^[Cc]:$') {
                    return (Join-Path $drive "RBR")
                }
            }
        }
    } catch {}

    # 其次从所有固定磁盘里选非 C 盘中剩余空间最大的盘
    try {
        $candidates = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceID -and $_.DeviceID -notmatch '^[Cc]:$' } |
            Sort-Object FreeSpace -Descending

        if ($candidates -and $candidates.Count -gt 0) {
            $drive = $candidates[0].DeviceID
            return (Join-Path $drive "RBR")
        }
    } catch {}

    # 没有非 C 盘时回退 C 盘
    return "C:\RBR"
}

function Get-QbtCachePath {
    return (Join-Path $script:ProjectRoot "qbt_path.cache")
}

function Save-QBittorrentPathCache {
    param([string]$ExePath)
    try {
        if ($ExePath -and (Test-Path $ExePath)) {
            Set-Content -Path (Get-QbtCachePath) -Value $ExePath -Encoding UTF8
            Write-Log -Level "INFO" -Message "Cached qBittorrent path: $ExePath"
        }
    } catch {}
}

# ─── 查找 qBittorrent 可执行文件 ──────────────────────────────────────────────
function Find-QBittorrent {
    # 0) 优先使用上次成功路径缓存
    try {
        $cacheFile = Get-QbtCachePath
        if (Test-Path $cacheFile) {
            $cached = (Get-Content -Path $cacheFile -Raw -ErrorAction SilentlyContinue).Trim()
            if ($cached -and (Test-Path $cached)) { return $cached }
        }
    } catch {}

    # 1) 若进程已在运行，直接取其可执行路径（最可靠）
    try {
        $runningExe = Get-CimInstance Win32_Process -Filter "Name='qbittorrent.exe'" -ErrorAction SilentlyContinue |
                      Select-Object -ExpandProperty ExecutablePath -First 1
        if ($runningExe -and (Test-Path $runningExe)) { return $runningExe }
    } catch {}

    # 2) 常见安装目录
    $candidates = @(
        "$env:ProgramFiles\qBittorrent\qbittorrent.exe",
        "${env:ProgramFiles(x86)}\qBittorrent\qbittorrent.exe",
        "$env:LOCALAPPDATA\Programs\qBittorrent\qbittorrent.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    # 2.5) 固定磁盘常见自定义目录（例如 E:\QB\qBittorrent）
    try {
        $fixedDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty DeviceID
        foreach ($d in $fixedDrives) {
            $extra = @(
                (Join-Path $d "QB\qBittorrent\qbittorrent.exe"),
                (Join-Path $d "qBittorrent\qbittorrent.exe"),
                (Join-Path $d "Apps\qBittorrent\qbittorrent.exe"),
                (Join-Path $d "Tools\qBittorrent\qbittorrent.exe")
            )
            foreach ($p in $extra) {
                if (Test-Path $p) { return $p }
            }
        }
    } catch {}
    # 3) App Paths（很多安装器会写这里，不受安装盘符影响）
    $appPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\qbittorrent.exe",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\qbittorrent.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\qbittorrent.exe"
    )
    foreach ($ap in $appPaths) {
        try {
            $defaultExe = (Get-ItemProperty $ap -ErrorAction SilentlyContinue).'(default)'
            if ($defaultExe -and (Test-Path $defaultExe)) { return $defaultExe }
        } catch {}
    }

    # 4) Uninstall 项（不同版本/安装方式键名可能不同）
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\qBittorrent",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\qBittorrent",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\qBittorrent"
    )
    foreach ($rp in $regPaths) {
        try {
            $item = Get-ItemProperty $rp -ErrorAction SilentlyContinue
            $val = $item.InstallLocation
            if ($val) {
                $exe = Join-Path $val "qbittorrent.exe"
                if (Test-Path $exe) { return $exe }
            }

            $icon = $item.DisplayIcon
            if ($icon) {
                $iconExe = ($icon -split ',')[0].Trim('"')
                if (Test-Path $iconExe) { return $iconExe }
            }
        } catch {}
    }

    # 5) 枚举 Uninstall 下所有条目，按 DisplayName 模糊匹配
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($root in $uninstallRoots) {
        try {
            $matches = Get-ItemProperty $root -ErrorAction SilentlyContinue |
                       Where-Object { $_.DisplayName -match 'qBittorrent' }
            foreach ($m in $matches) {
                if ($m.InstallLocation) {
                    $exe = Join-Path $m.InstallLocation "qbittorrent.exe"
                    if (Test-Path $exe) { return $exe }
                }
                if ($m.DisplayIcon) {
                    $iconExe = (($m.DisplayIcon -split ',')[0]).Trim('"')
                    if (Test-Path $iconExe) { return $iconExe }
                }
            }
        } catch {}
    }

    # 6) PATH 查找
    $inPath = Get-Command "qbittorrent.exe" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }

    return $null
}

function Read-QBittorrentPathFromUser {
    if ($GuiMode) {
        Write-Log -Level "INFO" -Message "GuiMode: skip manual qBittorrent path input."
        return $null
    }

    Write-Host ""
    Write-Host "  尝试打开文件选择窗口，请直接选择 qbittorrent.exe" -ForegroundColor Yellow

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop

        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = "请选择 qBittorrent 可执行文件（qbittorrent.exe）"
        $dlg.Filter = "qBittorrent (qbittorrent.exe)|qbittorrent.exe|可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*"
        $dlg.Multiselect = $false
        $dlg.CheckFileExists = $true
        $dlg.CheckPathExists = $true

        $initialDirs = @(
            "E:\\QB\\qBittorrent",
            "$env:ProgramFiles\\qBittorrent",
            "${env:ProgramFiles(x86)}\\qBittorrent",
            "$env:LOCALAPPDATA\\Programs\\qBittorrent",
            $script:ProjectRoot,
            $script:ScriptDir
        )

        foreach ($dir in $initialDirs) {
            if ($dir -and (Test-Path $dir)) {
                $dlg.InitialDirectory = $dir
                break
            }
        }

        $result = $dlg.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and (Test-Path $dlg.FileName)) {
            $picked = (Resolve-Path $dlg.FileName).Path
            Write-OK "已选择 qBittorrent：$picked"
            return $picked
        }
    } catch {
        Write-Warn "无法弹出文件选择窗口，将改为手动输入路径：$_"
    }

    Write-Host ""
    Write-Host "  也可以手动指定 qbittorrent.exe 路径（例如 E:\\QB\\qBittorrent\\qbittorrent.exe）" -ForegroundColor Yellow
    $manualPath = Read-UserInput -Prompt "  请输入完整路径（直接回车跳过）"
    if (-not $manualPath) { return $null }

    $manualPath = $manualPath.Trim('"')
    if (Test-Path $manualPath) {
        return (Resolve-Path $manualPath).Path
    }

    Write-Warn "路径无效：$manualPath"
    return $null
}

# ─── 测试 Web UI 是否可访问 ────────────────────────────────────────────────────
function Test-QbtWebUI {
    try {
        $resp = Invoke-WebRequest "http://${script:QbtHost}:${script:QbtPort}/api/v2/app/version" `
            -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        return ($resp.StatusCode -eq 200)
    } catch { return $false }
}

function Open-TorrentInQBittorrent {
    param(
        [string]$QbtExe,
        [string]$TorrentPath,
        [string]$SavePath
    )

    # --save-path 参数让 qBittorrent 在对话框里直接预填保存路径，用户无需手动改
    $args = '--save-path="{0}" "{1}"' -f $SavePath, $TorrentPath
    try {
        Start-Process -FilePath $QbtExe -ArgumentList $args
        Write-OK "已调用 qBittorrent 打开 torrent（保存路径已预填：$SavePath）"
        Write-Host "  qBittorrent 弹出窗口后，保存路径应已自动填好，直接点 OK 即可" -ForegroundColor Green
        return $true
    } catch {
        Write-Warn "带参数启动失败，尝试不带 --save-path 参数..."
        try {
            Start-Process -FilePath $QbtExe -ArgumentList ('"{0}"' -f $TorrentPath)
            Write-OK "已调用 qBittorrent 打开 torrent 文件"
            Write-Host "  [!] 请在弹出窗口中把 Save at 手动改为：$SavePath" -ForegroundColor Yellow
            return $true
        } catch {
            Write-Warn "通过 qBittorrent EXE 打开失败，尝试系统关联方式..."
            try {
                Start-Process -FilePath $TorrentPath
                Write-OK "已通过系统关联打开 torrent 文件"
                Write-Host "  [!] 请在弹出窗口中把 Save at 手动改为：$SavePath" -ForegroundColor Yellow
                return $true
            } catch {
                Write-Fail "无法自动打开 torrent 文件：$_"
                return $false
            }
        }
    }
}

function Wait-InstallerAndLaunch {
    param(
        [string[]]$SearchPaths,
        [string]$PreferredInstaller = "",
        [int]$PollSec = 20,
        [int]$MaxMinutes = 720
    )

    Write-Step "等待安装器文件出现并自动启动"
    Write-Host "  监控目录：$($SearchPaths -join '; ')" -ForegroundColor DarkGray
    Write-Host "  超时时间：$MaxMinutes 分钟（可按 Ctrl+C 取消）" -ForegroundColor DarkGray
    Write-Log -Level "INFO" -Message ("Installer search paths: " + ($SearchPaths -join '; '))

    # 快照脚本启动时已存在的安装器，防止误启动旧文件（如开发目录里的备份 exe）
    # 记录文件指纹（大小+最后写入时间）以便识别“同一路径但已更新”的新版本
    $preExisting = @{}
    foreach ($sp in $SearchPaths) {
        $existing = Find-Installer -SearchPath $sp
        if ($existing) {
            try {
                $fi = Get-Item -Path $existing -ErrorAction Stop
                $preExisting[$existing] = @{
                    Length = [int64]$fi.Length
                }
            } catch {
                $preExisting[$existing] = @{
                    Length = -1
                }
            }
        }
    }
    if ($preExisting.Count -gt 0) {
        Write-Warn "检测到目录中已存在安装器文件，等待新下载的版本出现：$($preExisting.Keys -join ', ')"
    }

    $deadline = (Get-Date).AddMinutes($MaxMinutes)
    $lastHint = (Get-Date).AddSeconds(-60)
    $lastProbe = (Get-Date).AddSeconds(-30)
    $probeLogged = $false
    $lastNotDoneHint = (Get-Date).AddSeconds(-120)
    $stableCandidatePath = ""
    $stableSize = -1
    $stableCount = 0
    $stableRequiredCount = 3   # with PollSec=20 => about 60s stable

    while ((Get-Date) -lt $deadline) {
        $installerPath = Find-InstallerFromPaths -SearchPaths $SearchPaths
        # 跳过脚本启动前就已存在且未变化的文件，防止误启动旧备份
        # 例外：用户明确指定的 PreferredInstaller 不做此限制（已存在即可用）
        if ($installerPath -and $preExisting.ContainsKey($installerPath)) {
            $isPreferred = ($PreferredInstaller -and
                ([System.IO.Path]::GetFullPath($installerPath) -eq [System.IO.Path]::GetFullPath($PreferredInstaller)))
            if (-not $isPreferred) {
                $oldFp = $preExisting[$installerPath]
                $isUpdated = $false
                try {
                    $curLen = [int64](Get-Item -Path $installerPath -ErrorAction Stop).Length
                    if ($curLen -ne $oldFp.Length) { $isUpdated = $true }
                } catch {}
                if (-not $isUpdated) {
                    $installerPath = $null
                } else {
                    Write-OK “检测到安装器文件已更新：$installerPath”
                }
            }
        }
        # 非 API 模式严格约束：必须先确认 torrent 完成，再允许启动安装器
        if (((Get-Date) - $lastProbe).TotalSeconds -ge 15) {
            $lastProbe = Get-Date
            if (Test-QbtTorrentCompletedFallback) {
                if (-not $probeLogged) {
                    Write-Log -Level "INFO" -Message "Fallback probe matched: torrent completed by qB WebUI state."
                    $probeLogged = $true
                }
                $launchPath = if ($installerPath) { $installerPath } elseif ($PreferredInstaller -and (Test-Path $PreferredInstaller)) { $PreferredInstaller } else { $null }
                if ($launchPath) {
                    Write-OK "检测到 torrent 已完成（fallback API），即将启动安装器"
                    Write-Log -Level "INFO" -Message "SEEDING_LAUNCH_READY=$launchPath"
                    Start-Sleep -Seconds 3
                    Write-Host ""
                    Write-Host "  ┌─── 安装前必读 ───────────────────────────────────┐" -ForegroundColor Yellow
                    Write-Host "  │  1. 弹出窗口后请选择 [Full Installation]         │" -ForegroundColor Yellow
                    Write-Host "  │  2. 不建议安装到 C 盘，推荐 E:\\RBR             │" -ForegroundColor Yellow
                    Write-Host "  │  3. 如杀毒软件拦截，请选择「允许/信任」          │" -ForegroundColor Yellow
                    Write-Host "  │  4. 不要把游戏装在 Program Files 或桌面！        │" -ForegroundColor Yellow
                    Write-Host "  └──────────────────────────────────────────────────┘" -ForegroundColor Yellow
                    Write-Host ""
                    Start-Process -FilePath $launchPath
                    Write-OK "已自动启动安装器"
                    return $true
                }
            }
        }

        if ($installerPath) {
            try {
                $fi = Get-Item -Path $installerPath -ErrorAction Stop
                $curSize = [int64]$fi.Length

                if ($stableCandidatePath -ne $installerPath) {
                    $stableCandidatePath = $installerPath
                    $stableSize = $curSize
                    $stableCount = 1
                } elseif ($curSize -eq $stableSize) {
                    $stableCount += 1
                } else {
                    $stableSize = $curSize
                    $stableCount = 1
                }

                if ($stableCount -ge $stableRequiredCount -and $curSize -gt 0) {
                    Write-Warn "WebUI 未能确认完成，已按文件稳定性判定下载完成，准备启动安装器。"
                    Write-Log -Level "INFO" -Message "SEEDING_LAUNCH_READY=$installerPath"
                    Start-Sleep -Seconds 3
                    Start-Process -FilePath $installerPath
                    Write-OK "已自动启动安装器"
                    return $true
                }
            } catch {}

            if (((Get-Date) - $lastNotDoneHint).TotalSeconds -ge 60) {
                Write-Warn "已发现安装器文件，但尚未确认 torrent 下载完成，暂不启动。"
                $lastNotDoneHint = Get-Date
            }
        }

        if (((Get-Date) - $lastHint).TotalSeconds -ge 60) {
            if ($installerPath) {
                Write-Log -Level "INFO" -Message "Installer candidate detected in wait loop: $installerPath"
            }
            Write-Step "仍在等待下载完成..."
            $lastHint = Get-Date
        }

        Start-Sleep -Seconds $PollSec
    }

    Write-Warn "等待安装器超时，未检测到安装器文件"
    return $false
}

# ─── 编辑 qBittorrent.ini 启用 Web UI ─────────────────────────────────────────
# 返回 $true  = 配置已就绪，无需重启
# 返回 $false = 修改了配置，需要重启 qBittorrent
function Enable-QbtWebUIConfig {
    param([string]$PreferredSavePath)

    $configDir  = "$env:APPDATA\qBittorrent"
    $configFile = Join-Path $configDir "qBittorrent.ini"

    Write-Step "正在同步 qBittorrent 配置..."

    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    $ini = if (Test-Path $configFile) { Get-Content $configFile -Raw -Encoding UTF8 } else { "" }

    # 确保 [Preferences] 段存在
    if ($ini -notmatch '\[Preferences\]') {
        $ini = $ini.TrimEnd() + "`r`n[Preferences]`r`n"
    }

    # Web UI 必须匹配的核心设置（这些决定是否需要重启）
    $requiredSettings = [ordered]@{
        'WebUI\Enabled'       = 'true'
        'WebUI\Port'          = $script:QbtPort
        'WebUI\Address'       = '127.0.0.1'
        'WebUI\Username'      = $script:QbtUser
        'WebUI\LocalHostAuth' = 'false'
    }

    # SavePath 单独写入但不触发重启检查（路径格式差异会误判导致不必要的重启）
    $extraSettings = [ordered]@{}
    if ($PreferredSavePath) {
        $extraSettings['Downloads\SavePath'] = $PreferredSavePath
    }

    $settings = [ordered]@{}
    foreach ($kv in $requiredSettings.GetEnumerator()) { $settings[$kv.Key] = $kv.Value }
    foreach ($kv in $extraSettings.GetEnumerator())  { $settings[$kv.Key] = $kv.Value }

    # 只用核心设置判断是否需要重启
    $needsUpdate = $false
    foreach ($kv in $requiredSettings.GetEnumerator()) {
        $k = [regex]::Escape($kv.Key)
        $v = [string]$kv.Value
        $pattern = "(?m)^$k\s*=\s*" + [regex]::Escape($v) + "$"
        if ($ini -notmatch $pattern) {
            $needsUpdate = $true
            break
        }
    }
    if ((-not $needsUpdate) -and (Test-QbtWebUI)) {
        Write-OK "qBittorrent 配置已就绪，无需重启"
        return $true
    }

    # 仅在确实需要改配置时才关闭 qB
    $running = Get-Process "qbittorrent" -ErrorAction SilentlyContinue
    if ($running) {
        Write-Warn "检测到 qBittorrent 正在运行，将短暂关闭以更新配置..."
        $running | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    foreach ($kv in $settings.GetEnumerator()) {
        $k = [regex]::Escape($kv.Key)   # 转义反斜杠用于正则
        $v = $kv.Value
        if ($ini -match "(?m)^$k\s*=") {
            $ini = $ini -replace "(?m)^$k\s*=.*", "$($kv.Key)=$v"
        } else {
            # 插入到 [Preferences] 段之后
            $ini = $ini -replace "(\[Preferences\])", "`$1`r`n$($kv.Key)=$v"
        }
    }

    [System.IO.File]::WriteAllText($configFile, $ini, [System.Text.Encoding]::UTF8)
    if ($PreferredSavePath) {
        Write-OK "qBittorrent 配置已更新（启用 Web UI，端口 $($script:QbtPort)，默认下载目录：$PreferredSavePath）"
    } else {
        Write-OK "qBittorrent 配置已更新（启用 Web UI，端口 $($script:QbtPort)）"
    }
    return $false
}

# ─── qBittorrent Web API 封装 ──────────────────────────────────────────────────
$script:QbtSession  = $null
$script:QbtBaseUrl  = ""
$script:QbtHost     = $QbtHost
$script:QbtPort     = $QbtPort
$script:QbtUser     = $QbtUser
$script:QbtPass     = $QbtPass
$script:RunTag      = "rbr_auto_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")

function Connect-Qbt {
    $script:QbtBaseUrl = "http://${script:QbtHost}:${script:QbtPort}/api/v2"

    # LocalHostAuth=false 时无需登录，直接用空 session 也能访问
    # 先试无密码访问
    try {
        $test = Invoke-WebRequest "$script:QbtBaseUrl/app/version" `
            -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        if ($test.StatusCode -eq 200) {
            # 即使不需要 auth，也做一次 login 以获得 session cookie
            $body = "username=$($script:QbtUser)&password=$($script:QbtPass)"
            Invoke-WebRequest "$script:QbtBaseUrl/auth/login" `
                -Method POST -Body $body `
                -ContentType "application/x-www-form-urlencoded" `
                -SessionVariable "sess" -UseBasicParsing | Out-Null
            $script:QbtSession = $sess
            Write-OK "已连接 qBittorrent Web API（本地免认证模式）"
            return $true
        }
    } catch {}

    # 尝试带密码登录
    try {
        $body = "username=$($script:QbtUser)&password=$($script:QbtPass)"
        $resp = Invoke-WebRequest "$script:QbtBaseUrl/auth/login" `
            -Method POST -Body $body `
            -ContentType "application/x-www-form-urlencoded" `
            -SessionVariable "sess" -UseBasicParsing -ErrorAction Stop

        if ($resp.Content -eq "Ok.") {
            $script:QbtSession = $sess
            Write-OK "已连接 qBittorrent Web API（用户名/密码认证）"
            return $true
        }
        Write-Fail "qBittorrent 登录失败，响应：$($resp.Content)"
        return $false
    } catch {
        Write-Fail "无法连接 qBittorrent Web API：$_"
        return $false
    }
}

function Add-QbtTorrent {
    param(
        [string]$TorrentPath,
        [string]$SavePath
    )

    $torrentBytes = [System.IO.File]::ReadAllBytes($TorrentPath)
    $torrentName  = [System.IO.Path]::GetFileName($TorrentPath)
    $boundary     = [System.Guid]::NewGuid().ToString("N")
    $CRLF         = "`r`n"

    $buf = [System.Collections.Generic.List[byte]]::new()

    # savepath 字段
    $part = "--$boundary${CRLF}Content-Disposition: form-data; name=`"savepath`"${CRLF}${CRLF}${SavePath}${CRLF}"
    $buf.AddRange([System.Text.Encoding]::UTF8.GetBytes($part))

    # tags 字段（用于精准识别本次脚本添加的 torrent）
    $part = "--$boundary${CRLF}Content-Disposition: form-data; name=`"tags`"${CRLF}${CRLF}$($script:RunTag)${CRLF}"
    $buf.AddRange([System.Text.Encoding]::UTF8.GetBytes($part))

    # torrents 文件字段
    $part = "--$boundary${CRLF}Content-Disposition: form-data; name=`"torrents`"; filename=`"$torrentName`"${CRLF}Content-Type: application/x-bittorrent${CRLF}${CRLF}"
    $buf.AddRange([System.Text.Encoding]::UTF8.GetBytes($part))
    $buf.AddRange($torrentBytes)
    $buf.AddRange([System.Text.Encoding]::UTF8.GetBytes($CRLF))

    # 结束边界
    $buf.AddRange([System.Text.Encoding]::UTF8.GetBytes("--$boundary--${CRLF}"))

    try {
        $resp = Invoke-WebRequest "$script:QbtBaseUrl/torrents/add" `
            -Method POST `
            -Body $buf.ToArray() `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -WebSession $script:QbtSession `
            -UseBasicParsing -ErrorAction Stop

        if ($resp.Content -eq "Ok.") {
            Write-OK "Torrent 已成功添加到 qBittorrent（Tag: $($script:RunTag)）"
            return $true
        }
        Write-Fail "添加 Torrent 失败，qBt 响应：$($resp.Content)"
        return $false
    } catch {
        Write-Fail "添加 Torrent 时出错：$_"
        return $false
    }
}

function Get-QbtTorrents {
    $resp = Invoke-WebRequest "$script:QbtBaseUrl/torrents/info" `
        -WebSession $script:QbtSession -UseBasicParsing -ErrorAction Stop
    return $resp.Content | ConvertFrom-Json
}

function Test-QbtTorrentCompletedFallback {
    try {
        if (-not (Test-QbtWebUI)) { return $false }
        if (-not $script:QbtSession) {
            if (-not (Connect-Qbt)) { return $false }
        }

        $torrents = @(Get-QbtTorrents)
        if (-not $torrents -or $torrents.Count -eq 0) { return $false }

        $target = $torrents |
            Where-Object { $_.name -match "RSF|RBR|Rallysimfans|rsf_installer" } |
            Sort-Object added_on -Descending |
            Select-Object -First 1

        if (-not $target) {
            $target = $torrents | Sort-Object added_on -Descending | Select-Object -First 1
        }
        if (-not $target) { return $false }

        $doneStates = @("uploading","stalledUP","pausedUP","queuedUP","checkingUP","forcedUP","completed")
        $isDoneByProgress = ($target.progress -ge 0.9999)
        $isDoneByLeft     = ($null -ne $target.amount_left -and [double]$target.amount_left -le 0)
        $isDoneByState    = ($target.state -in $doneStates)
        return ($isDoneByProgress -or $isDoneByLeft -or $isDoneByState)
    } catch {
        return $false
    }
}

function Test-HasQbtTag {
    param(
        [string]$Tags,
        [string]$ExpectedTag
    )

    if (-not $Tags -or -not $ExpectedTag) { return $false }
    $all = $Tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return ($all -contains $ExpectedTag)
}

# ─── 在下载目录中查找 RSF 安装器 EXE ──────────────────────────────────────────
function Find-Installer {
    param([string]$SearchPath)
    $patterns = @("Rallysimfans_Installer*.exe", "RSF_Installer*.exe", "RBR*Installer*.exe")
    foreach ($pat in $patterns) {
        $found = Get-ChildItem -Path $SearchPath -Filter $pat -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Get-InstallerSearchPaths {
    param(
        [string]$PrimaryPath,
        [string]$TorrentPath
    )

    $paths = New-Object System.Collections.Generic.List[string]

    if ($PrimaryPath) { $paths.Add($PrimaryPath) }
    if ($script:ProjectRoot) { $paths.Add($script:ProjectRoot) }
    if ($script:ScriptDir) { $paths.Add($script:ScriptDir) }

    try {
        if ($TorrentPath) {
            $torrentDir = Split-Path -Path $TorrentPath -Parent
            if ($torrentDir) { $paths.Add($torrentDir) }
        }
    } catch {}

    $paths.Add($PWD.Path)

    $resolved = $paths |
        Where-Object { $_ } |
        ForEach-Object {
            try { (Resolve-Path -Path $_ -ErrorAction Stop).Path } catch { $_ }
        } |
        Where-Object { Test-Path $_ } |
        Select-Object -Unique

    return @($resolved)
}

function Find-InstallerFromPaths {
    param([string[]]$SearchPaths)

    foreach ($path in $SearchPaths) {
        $found = Find-Installer -SearchPath $path
        if ($found) { return $found }
    }
    return $null
}

function Resolve-PreferredInstaller {
    param(
        [string]$UserInstallerFile,
        [string]$DownloadPath,
        [string]$ScriptDir
    )

    if ($UserInstallerFile -and (Test-Path $UserInstallerFile)) {
        try { return (Resolve-Path -Path $UserInstallerFile -ErrorAction Stop).Path } catch {}
    }

    if ($DownloadPath -and (Test-Path $DownloadPath)) {
        $fromDownload = Find-Installer -SearchPath $DownloadPath
        if ($fromDownload) { return $fromDownload }
    }

    $bundled = Join-Path $ScriptDir "Rallysimfans_Installer.exe"
    if (-not (Test-Path $bundled) -and $script:ProjectRoot) {
        $bundled = Join-Path $script:ProjectRoot "Rallysimfans_Installer.exe"
    }
    if (Test-Path $bundled) {
        try { return (Resolve-Path -Path $bundled -ErrorAction Stop).Path } catch {}
    }

    return $null
}

# ─── 格式化 ETA ────────────────────────────────────────────────────────────────
function Format-ETA {
    param([long]$Seconds)
    if ($Seconds -le 0 -or $Seconds -ge 8640000) { return "计算中..." }
    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.Hours -gt 0)   { return "$($ts.Hours)h $($ts.Minutes)m" }
    if ($ts.Minutes -gt 0) { return "$($ts.Minutes)m $($ts.Seconds)s" }
    return "$($ts.Seconds)s"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════════════════════════════════════

Clear-Host
Show-Banner
Write-Host "  日志文件：$script:LogPath" -ForegroundColor DarkGray
Write-Host ""
Write-Log -Level "INFO" -Message "Log file path: $script:LogPath"

# ── 步骤 1：定位 .torrent 文件 ─────────────────────────────────────────────────
Write-Step "步骤 1/7：定位 .torrent 文件"

if (-not $TorrentFile) {
    $found = @(
        Get-ChildItem -Path $script:ProjectRoot -Filter "*.torrent" -ErrorAction SilentlyContinue
        Get-ChildItem -Path $script:ScriptDir -Filter "*.torrent" -ErrorAction SilentlyContinue
    ) | Select-Object -First 1
    if ($found) {
        $TorrentFile = $found.FullName
        Write-OK "自动找到：$($found.Name)"
    } else {
        Write-Fail "未找到 .torrent 文件"
        Write-Host "  请将 .torrent 文件放在脚本同目录，或通过 -TorrentFile 参数指定路径" -ForegroundColor Yellow
        Write-Host "  官方下载页（推荐）：$script:RsfOfficialDownloadPage" -ForegroundColor Cyan
        $openPage = Read-UserInput -Prompt "  是否现在打开官方下载页？(Y/N)" -Default "N"
        if ($openPage -match '^[Yy]') {
            Start-Process $script:RsfOfficialDownloadPage
        }
        Pause-IfConsole "`n按 Enter 退出"
        exit 1
    }
}

if (-not (Test-Path $TorrentFile)) {
    Write-Fail "指定的 .torrent 文件不存在：$TorrentFile"
    Write-Host "  官方下载页（推荐）：$script:RsfOfficialDownloadPage" -ForegroundColor Cyan
    $openPage = Read-UserInput -Prompt "  是否现在打开官方下载页？(Y/N)" -Default "N"
    if ($openPage -match '^[Yy]') {
        Start-Process $script:RsfOfficialDownloadPage
    }
    Pause-IfConsole "`n按 Enter 退出"
    exit 1
}

if ($InstallerFile) {
    if (Test-Path $InstallerFile) {
        try {
            $InstallerFile = (Resolve-Path -Path $InstallerFile -ErrorAction Stop).Path
            Write-OK "已指定安装器：$InstallerFile"
            Write-Log -Level "INFO" -Message "User specified installer file: $InstallerFile"
        } catch {
            Write-Warn "指定安装器路径解析失败，将自动查找：$InstallerFile"
            Write-Log -Level "WARN" -Message "InstallerFile resolve failed: $InstallerFile"
            $InstallerFile = ""
        }
    } else {
        Write-Warn "指定安装器不存在，将自动查找：$InstallerFile"
        Write-Log -Level "WARN" -Message "InstallerFile does not exist: $InstallerFile"
        $InstallerFile = ""
    }
}

# ── 步骤 2：确认下载路径 ────────────────────────────────────────────────────────
Write-Step "步骤 2/7：确认下载路径"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }

if (-not $DownloadPath) {
    $DownloadPath = Get-RecommendedDownloadPath -ScriptDir $scriptDir
    Write-OK "未指定下载路径，已自动选择：$DownloadPath"
}

if (-not (Assert-SafePath -Path $DownloadPath)) {
    Write-Warn "检测到危险路径：$DownloadPath"
    Write-Warn "RSF 官方不建议安装到 Program Files、桌面或用户目录！"
    $DownloadPath = Get-RecommendedDownloadPath -ScriptDir $scriptDir
    Write-Warn "已自动更正为：$DownloadPath"
}

Write-OK "下载路径：$DownloadPath"

if ($DownloadPath -match '^[Cc]:\\') {
    Write-Warn "当前下载路径位于 C 盘。为了后续维护和磁盘空间，建议改到 E:\\RBR 或其他非 C 盘路径。"
}

if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
    Write-OK "目录不存在，已创建"
}

# ── 步骤 3：检查 qBittorrent 安装 ──────────────────────────────────────────────
Write-Step "步骤 3/7：检查 qBittorrent"

$qbtExe = Find-QBittorrent

if (-not $qbtExe) {
    Write-Warn "未检测到 qBittorrent"
    Write-Host ""
    Write-Host "  说明：安装在 E 盘本身没有问题；只要脚本能找到 qbittorrent.exe 即可。" -ForegroundColor DarkYellow
    Write-Host "  qBittorrent 是免费开源的 BT 客户端，下载地址：" -ForegroundColor Yellow
    Write-Host "  官网：https://www.qbittorrent.org/download" -ForegroundColor Cyan
    Write-Host "  直链（最新版）：$script:QbtLatestDownloadLink" -ForegroundColor Cyan
    Write-Host ""
    if ($GuiMode) {
        # GuiMode 下由 UI 弹出 Yes/No 决定是否打开下载页，后端不再自动跳转。
        Write-Log -Level "INFO" -Message "qBittorrent not found in GuiMode; waiting for UI user confirmation to open download page."
    } else {
        $answer = Read-UserInput -Prompt "  是否现在打开下载页？(Y/N)" -Default "N"
        if ($answer -match '^[Yy]') {
            Start-Process $script:QbtLatestDownloadLink
        }
    }
    Write-Host ""
    Pause-IfConsole "  安装完成后，按 Enter 继续..."
    $qbtExe = Find-QBittorrent

    if (-not $qbtExe) {
        $qbtExe = Read-QBittorrentPathFromUser
    }

    if (-not $qbtExe) {
        Write-Fail "仍未找到 qBittorrent，请确认安装后重新运行脚本"
        Pause-IfConsole "`n按 Enter 退出"
        exit 1
    }
}

Write-OK "qBittorrent：$qbtExe"
Save-QBittorrentPathCache -ExePath $qbtExe

# ── 步骤 4：配置 Web UI 并启动 qBittorrent ────────────────────────────────────
Write-Step "步骤 4/7：配置并启动 qBittorrent"

$alreadyReady = Enable-QbtWebUIConfig -PreferredSavePath $DownloadPath
$useQbtApi = $false
$webUiWaitTimeoutSec = 60

$qbtRunning = Get-Process "qbittorrent" -ErrorAction SilentlyContinue
if ($qbtRunning -and -not $alreadyReady) {
    Write-Step "配置已更新，重启 qBittorrent 使 Web UI 生效..."
    $qbtRunning | Stop-Process -Force
    Start-Sleep -Seconds 2
    $qbtRunning = $null
}

# ── 步骤 5：连接 API ───────────────────────────────────────────────────────────
Write-Step "步骤 5/7：连接 qBittorrent API"

if ($alreadyReady -and $qbtRunning -and (Test-QbtWebUI)) {
    # 最快路径：qBittorrent 已在运行且 Web UI 就绪，直接连接
    Write-OK "qBittorrent Web UI 已就绪（端口 $QbtPort）"
    $connected = Connect-Qbt
    if ($connected) { $useQbtApi = $true }
} else {
    # 需要启动 qBittorrent：立刻打开 torrent，同时后台等待 Web UI
    Write-Step "启动 qBittorrent 并打开 torrent..."
    Open-TorrentInQBittorrent -QbtExe $qbtExe -TorrentPath $TorrentFile -SavePath $DownloadPath
    $script:TorrentAlreadyOpened = $true

    Write-Log -Level "PROGRESS" -Message "QBT_STARTUP=5"
    $waited  = 0
    $pollSec = 2
    while (-not (Test-QbtWebUI)) {
        Start-Sleep -Seconds $pollSec
        $waited += $pollSec
        if ($waited -ge $webUiWaitTimeoutSec) { break }
        $pct = [int]([math]::Min(5 + $waited * 90 / $webUiWaitTimeoutSec, 99))
        Write-Log -Level "PROGRESS" -Message ("QBT_STARTUP={0}" -f $pct)
    }

    if (Test-QbtWebUI) {
        Write-Log -Level "PROGRESS" -Message "QBT_STARTUP=100"
        Write-OK "qBittorrent Web UI 已就绪（端口 $QbtPort）"
        $connected = Connect-Qbt
        if ($connected) { $useQbtApi = $true }
    } else {
        Write-Warn "qBittorrent Web UI 未响应，使用非 API 模式监控进度"
    }
}

if (-not $useQbtApi) {
    Write-Step "步骤 6/7：以非 API 模式打开 Torrent"

    if (-not $script:TorrentAlreadyOpened) {
        Write-Host "  文件：$TorrentFile"
        Write-Host "  保存：$DownloadPath"
        $opened = Open-TorrentInQBittorrent -QbtExe $qbtExe -TorrentPath $TorrentFile -SavePath $DownloadPath
        if (-not $opened) {
            Pause-IfConsole "`n按 Enter 退出"
            exit 1
        }
    }

    Write-Host ""
    Write-Warn "当前为非 API 模式：脚本无法自动读取下载进度。"
    Write-Host "  已自动转为目录轮询模式：检测到安装器后会自动启动。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  !! 重要 !! 请在 qBittorrent 弹出的窗口里：    ║" -ForegroundColor Red
    Write-Host "  ║                                                  ║" -ForegroundColor Red
    Write-Host "  ║  把 [Save at / 保存到] 手动改为：               ║" -ForegroundColor Red
    Write-Host ("  ║    {0,-49}║" -f "  $DownloadPath") -ForegroundColor Red
    Write-Host "  ║                                                  ║" -ForegroundColor Red
    Write-Host "  ║  改完再点 OK/确定，否则会下载到 C 盘！          ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""

    $preferredInstaller = Resolve-PreferredInstaller -UserInstallerFile $InstallerFile -DownloadPath $DownloadPath -ScriptDir $script:ScriptDir
    if ($preferredInstaller) {
        Write-Log -Level "INFO" -Message "Preferred installer detected: $preferredInstaller"
        Write-Host "  提示：当前是非 API 模式，脚本无法自动读取 qBittorrent 的做种状态。" -ForegroundColor DarkYellow
        Write-Host "  现在采用严格模式：仅在确认 torrent 完成后才会自动启动安装器。" -ForegroundColor DarkYellow
        $manualLaunch = Read-UserInput -Prompt "  已看到 Seeding/做种？输入 Y 立即启动安装器（直接回车=继续自动等待）" -Default ""
        if ($manualLaunch -match '^[Yy]') {
            if (Test-QbtTorrentCompletedFallback) {
                try {
                    Start-Process -FilePath $preferredInstaller -ErrorAction Stop
                    Write-OK "已启动安装器：$preferredInstaller"
                    Write-Host ""
                    Write-OK "安装助手任务完成！祝游戏顺利！"
                    Write-Host ""
                    Pause-IfConsole "按 Enter 退出"
                    exit 0
                } catch {
                    Write-Fail "启动安装器失败：$_"
                    Write-Log -Level "FAIL" -Message "Manual launch failed: $_"
                }
            } else {
                Write-Warn "尚未确认 torrent 完成，已阻止提前启动安装器。"
            }
        }
    } else {
        Write-Log -Level "WARN" -Message "No preferred installer found."
    }

    $installerSearchPaths = Get-InstallerSearchPaths -PrimaryPath $DownloadPath -TorrentPath $TorrentFile
    $launched = Wait-InstallerAndLaunch -SearchPaths $installerSearchPaths -PreferredInstaller $preferredInstaller -PollSec 20 -MaxMinutes 720
    if (-not $launched) {
        Write-Warn "未确认 torrent 完整下载，已阻止自动启动安装器。"
        Write-Warn "请先在 qBittorrent 中确认该任务已完成（100% / Seeding），再手动运行安装器。"
        Start-Process "explorer.exe" -ArgumentList $DownloadPath
    }

    Write-Host ""
    Write-OK "安装助手任务完成！祝游戏顺利！"
    Write-Host ""
    Pause-IfConsole "按 Enter 退出"
    exit 0
}

# ── 步骤 6：添加 Torrent ───────────────────────────────────────────────────────
Write-Step "步骤 6/7：添加 Torrent 到下载队列"
Write-Host "  文件：$TorrentFile"
Write-Host "  保存：$DownloadPath"

if (-not (Add-QbtTorrent -TorrentPath $TorrentFile -SavePath $DownloadPath)) {
    Pause-IfConsole "`n按 Enter 退出"
    exit 1
}

# ── 步骤 7：监控下载进度 ────────────────────────────────────────────────────────
Write-Step "步骤 7/7：监控下载进度（每 $PollSeconds 秒刷新）"
Write-Host ""
Write-Host "  提示：关闭此窗口会中止监控，但 qBittorrent 仍会继续下载" -ForegroundColor DarkGray
Write-Host "        下载完成后它会自动打开安装器" -ForegroundColor DarkGray
Write-Host ""

# 等待 qBt 注册 torrent
Start-Sleep -Seconds 5

$completed    = $false
$lastProgress = -1.0
$doneStates   = @("uploading","stalledUP","pausedUP","queuedUP","checkingUP","forcedUP","completed")

while (-not $completed) {
    try {
        $torrents = @(Get-QbtTorrents)

        if ($torrents.Count -gt 0) {
            # 优先按本次运行的唯一 Tag 精确匹配
            $target = $torrents |
                Where-Object { Test-HasQbtTag -Tags $_.tags -ExpectedTag $script:RunTag } |
                Sort-Object added_on -Descending |
                Select-Object -First 1

            # 兼容旧任务：没有 tag 时再走名称匹配
            if (-not $target) {
                $target = $torrents |
                Where-Object { $_.name -match "RSF|RBR|Rallysimfans|rsf_installer" } |
                Sort-Object added_on -Descending |
                Select-Object -First 1
            }

            if (-not $target) {
                $target = $torrents | Sort-Object added_on -Descending | Select-Object -First 1
            }

            $pct       = [math]::Round($target.progress * 100, 1)
            $speedMBs  = [math]::Round($target.dlspeed / 1MB, 2)
            $sizeGB    = [math]::Round($target.size / 1GB, 2)
            $doneGB    = [math]::Round($target.completed / 1GB, 2)
            $eta       = Format-ETA -Seconds $target.eta
            $state     = $target.state
            $ts        = Get-Date -Format "HH:mm:ss"

            if ($pct -ne $lastProgress) {
                $bar     = [math]::Floor($pct / 5)
                $barStr  = ("█" * $bar).PadRight(20, "░")
                Write-Host "  [$ts] [$barStr] $pct%  ${speedMBs} MB/s  $doneGB/$sizeGB GB  ETA: $eta  ($state)" -ForegroundColor White
                Write-Log -Level "PROGRESS" -Message ("TORRENT={0};STATE={1};SPEEDMB={2}" -f $pct, $state, $speedMBs)
                $lastProgress = $pct
            }

            $isDoneByProgress = ($target.progress -ge 0.9999)
            $isDoneByLeft     = ($null -ne $target.amount_left -and [double]$target.amount_left -le 0)
            $isDoneByState    = ($state -in $doneStates)

            if ($isDoneByProgress -or $isDoneByLeft -or $isDoneByState) {
                $completed = $true
            }
        } else {
            Write-Warn "暂未检测到 torrent，等待中..."
        }
    } catch {
        Write-Warn "检查进度出错（$_），$PollSeconds 秒后重试"
    }

    if (-not $completed) {
        Start-Sleep -Seconds $PollSeconds
    }
}

# ─── 下载完成 ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "  │              下载完成！(100%)                    │" -ForegroundColor Green
Write-Host "  └──────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 2

$installerSearchPaths = Get-InstallerSearchPaths -PrimaryPath $DownloadPath -TorrentPath $TorrentFile
$preferredInstaller = Resolve-PreferredInstaller -UserInstallerFile $InstallerFile -DownloadPath $DownloadPath -ScriptDir $script:ScriptDir
$installerPath = if ($preferredInstaller) { $preferredInstaller } else { Find-InstallerFromPaths -SearchPaths $installerSearchPaths }

if ($installerPath) {
    Write-OK "找到安装器：$installerPath"
    Write-Host ""
    Write-Host "  ┌─── 安装前必读 ───────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  1. 弹出窗口后请选择 [Full Installation]         │" -ForegroundColor Yellow
    Write-Host "  │  2. 不建议安装到 C 盘，推荐 E:\\RBR             │" -ForegroundColor Yellow
    Write-Host "  │  3. 如杀毒软件拦截，请选择「允许/信任」          │" -ForegroundColor Yellow
    Write-Host "  │  4. 不要把游戏装在 Program Files 或桌面！        │" -ForegroundColor Yellow
    Write-Host "  └──────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    Start-Process $installerPath
    Write-OK "已自动启动安装器"
} else {
    Write-Warn "未自动找到安装器 EXE，正在打开下载目录..."
    Write-Host "  请手动运行目录中的 Rallysimfans_Installer_*.exe" -ForegroundColor Yellow
    Start-Process "explorer.exe" -ArgumentList $DownloadPath
}

Write-Host ""
Write-OK "安装助手任务完成！祝游戏顺利！"
Write-Host ""
Pause-IfConsole "按 Enter 退出"

try {
    if ($script:RunLockStream) {
        $script:RunLockStream.Dispose()
    }
    if ($script:SingleInstanceMutex) {
        $script:SingleInstanceMutex.ReleaseMutex() | Out-Null
        $script:SingleInstanceMutex.Dispose()
    }
} catch {}
