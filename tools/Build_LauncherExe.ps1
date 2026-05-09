#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$projectRoot = Split-Path -Parent $scriptDir
if (-not (Test-Path (Join-Path $projectRoot "scripts"))) {
    # Backward compatibility: if script is not inside tools/, treat current folder as project root.
    $projectRoot = $scriptDir
}

$scriptsDir = Join-Path $projectRoot "scripts"
$distDir = Join-Path $projectRoot "dist"
if (-not (Test-Path $distDir)) {
    New-Item -Path $distDir -ItemType Directory -Force | Out-Null
}
$outExe = Join-Path $projectRoot "RBR_Install_Assistant.exe"
$distExe = Join-Path $distDir "RBR_Install_Assistant.exe"

$assetsDir = Join-Path $projectRoot "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -Path $assetsDir -ItemType Directory -Force | Out-Null
}
$logoPng = Join-Path $assetsDir "RBR_INSTALLER.png"
if (-not (Test-Path $logoPng)) {
    $legacyLogo = Join-Path $projectRoot "RBR_INSTALLER.png"
    if (Test-Path $legacyLogo) { $logoPng = $legacyLogo }
}
$logoIco = Join-Path $assetsDir "RBR_INSTALLER.ico"

function Ensure-ExeIcon {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    if (Test-Path $IcoPath) {
        Remove-Item -Path $IcoPath -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $PngPath)) {
        return $null
    }

    $img = [System.Drawing.Image]::FromFile($PngPath)
    try {
        $size = 256
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.DrawImage($img, 0, 0, $size, $size)
            } finally {
                $g.Dispose()
            }

            $pngStream = New-Object System.IO.MemoryStream
            try {
                $bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $pngBytes = $pngStream.ToArray()

                $fs = [System.IO.File]::Create($IcoPath)
                $bw = New-Object System.IO.BinaryWriter($fs)
                try {
                    # ICONDIR
                    $bw.Write([UInt16]0)
                    $bw.Write([UInt16]1)
                    $bw.Write([UInt16]1)

                    # ICONDIRENTRY
                    $bw.Write([Byte]0)   # 0 means 256
                    $bw.Write([Byte]0)   # 0 means 256
                    $bw.Write([Byte]0)
                    $bw.Write([Byte]0)
                    $bw.Write([UInt16]1)
                    $bw.Write([UInt16]32)
                    $bw.Write([UInt32]$pngBytes.Length)
                    $bw.Write([UInt32]22)

                    # image data
                    $bw.Write($pngBytes)
                } finally {
                    $bw.Dispose()
                    $fs.Dispose()
                }
            } finally {
                $pngStream.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }
    } finally {
        $img.Dispose()
    }

    if (Test-Path $IcoPath) { return $IcoPath }
    return $null
}

$iconForExe = Ensure-ExeIcon -PngPath $logoPng -IcoPath $logoIco

$code = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

public static class RbrLauncher
{
    [STAThread]
    public static void Main()
    {
        string baseDir = AppDomain.CurrentDomain.BaseDirectory;
        string parentDir = Path.GetFullPath(Path.Combine(baseDir, ".."));

        string[] scriptDirs = new string[]
        {
            Path.Combine(baseDir, "scripts"),
            Path.Combine(parentDir, "scripts"),
            baseDir,
            parentDir
        };

        string target = null;
        foreach (string dir in scriptDirs)
        {
            string uiScript = Path.Combine(dir, "RBR_UI_Launcher.ps1");
            string fallbackScript = Path.Combine(dir, "RBR_Auto_Installer.ps1");
            if (File.Exists(uiScript)) { target = uiScript; break; }
            if (File.Exists(fallbackScript)) { target = fallbackScript; break; }
        }

        if (!File.Exists(target))
        {
            MessageBox.Show(
                "找不到启动脚本。请确认包含 scripts 文件夹，且其中有 RBR_UI_Launcher.ps1 或 RBR_Auto_Installer.ps1。",
                "RBR 安装助手",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
            return;
        }

        string args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + target + "\"";

        try
        {
            var psi = new ProcessStartInfo("powershell.exe", args)
            {
                UseShellExecute = true,
                Verb = "runas",
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process.Start(psi);
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            if (ex.NativeErrorCode == 1223)
            {
                MessageBox.Show(
                    "你取消了管理员授权（UAC）。请重新打开并点击“是”。",
                    "RBR 安装助手",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning
                );
                return;
            }

            MessageBox.Show(
                "启动失败：" + ex.Message,
                "RBR 安装助手",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "启动失败：" + ex.Message,
                "RBR 安装助手",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
    }
}
"@

if (Test-Path $outExe) {
    Remove-Item -Path $outExe -Force
}
if (Test-Path $distExe) {
    Remove-Item -Path $distExe -Force
}

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)

# Also search Visual Studio Roslyn csc (needed on GitHub Actions / VS 2022+)
$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsInstallPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2>$null
    if ($vsInstallPath) {
        $roslynCsc = Join-Path $vsInstallPath "MSBuild\Current\Bin\Roslyn\csc.exe"
        $cscCandidates += $roslynCsc
    }
}

$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) {
    throw "未找到 csc.exe，无法构建 EXE。已搜索路径：$($cscCandidates -join ', ')"
}

$tmpCs = Join-Path $distDir "__rbr_launcher_tmp.cs"
Set-Content -Path $tmpCs -Value $code -Encoding UTF8

try {
    $args = @(
        "/nologo",
        "/target:winexe",
        "/out:$outExe",
        "/reference:System.dll",
        "/reference:System.Windows.Forms.dll"
    )
    if ($iconForExe) {
        $args += "/win32icon:$iconForExe"
    }
    $args += $tmpCs

    & $csc @args
    if ($LASTEXITCODE -ne 0) {
        throw "csc 编译失败，退出码：$LASTEXITCODE"
    }
}
finally {
    if (Test-Path $tmpCs) { Remove-Item -Path $tmpCs -Force -ErrorAction SilentlyContinue }
}

Copy-Item -Path $outExe -Destination $distExe -Force

Write-Host "EXE 构建完成：$outExe" -ForegroundColor Green
Write-Host "已同步到：$distExe" -ForegroundColor Green
if ($iconForExe) {
    Write-Host "已嵌入图标：$iconForExe" -ForegroundColor Green
} else {
    Write-Host "未找到图标文件（RBR_INSTALLER.png / RBR_INSTALLER.ico），使用默认图标。" -ForegroundColor Yellow
}
