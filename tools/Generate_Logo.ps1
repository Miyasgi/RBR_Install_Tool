#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$projectRoot = Split-Path -Parent $scriptDir
if (-not (Test-Path (Join-Path $projectRoot "scripts"))) {
    $projectRoot = $scriptDir
}

$assetsDir = Join-Path $projectRoot "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -Path $assetsDir -ItemType Directory -Force | Out-Null
}
$pngPath = Join-Path $assetsDir "RBR_Assistant_Logo.png"
$icoPath = Join-Path $assetsDir "RBR_Assistant_Logo.ico"

function New-LogoBitmap {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear([System.Drawing.Color]::FromArgb(18, 33, 74))

    $rect = [System.Drawing.Rectangle]::new(0, 0, $Size, $Size)
    $brushBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(32, 86, 188),
        [System.Drawing.Color]::FromArgb(20, 35, 80),
        45
    )
    $g.FillRectangle($brushBg, $rect)

    $ringPad = [int]($Size * 0.1)
    $ringRect = [System.Drawing.Rectangle]::new($ringPad, $ringPad, ($Size - ($ringPad * 2)), ($Size - ($ringPad * 2)))
    $penRing = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(100, 255, 255, 255), [float]($Size * 0.06))
    $g.DrawEllipse($penRing, $ringRect)

    $innerPad = [int]($Size * 0.24)
    $innerRect = [System.Drawing.Rectangle]::new($innerPad, $innerPad, ($Size - ($innerPad * 2)), ($Size - ($innerPad * 2)))
    $brushInner = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 33, 188, 120))
    $g.FillEllipse($brushInner, $innerRect)

    $fontSize = [float]($Size * 0.22)
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $brushText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.DrawString("RBR", $font, $brushText, [System.Drawing.RectangleF]$rect, $sf)

    $brushBg.Dispose()
    $penRing.Dispose()
    $brushInner.Dispose()
    $font.Dispose()
    $sf.Dispose()
    $brushText.Dispose()
    $g.Dispose()

    return $bmp
}

$bmpPng = New-LogoBitmap -Size 256
$bmpPng.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmpPng.Dispose()

$bmpIco = New-LogoBitmap -Size 64
$icon = [System.Drawing.Icon]::FromHandle($bmpIco.GetHicon())
$fs = [System.IO.File]::Create($icoPath)
$icon.Save($fs)
$fs.Dispose()
$icon.Dispose()
$bmpIco.Dispose()

Write-Host "Logo generated:" -ForegroundColor Green
Write-Host "  $pngPath"
Write-Host "  $icoPath"
