@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "OUT_DIR=%ROOT%\release"
set "STAGE_DIR=%OUT_DIR%\_stage"
set "APP_NAME=RBR_Install_Tool"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%i"
set "ZIP_NAME=%APP_NAME%_%STAMP%.zip"
set "ZIP_PATH=%OUT_DIR%\%ZIP_NAME%"

echo.
echo ==============================================
echo   RBR Release Build (ZIP)
echo ==============================================
echo.

if exist "%ROOT%\tools\Build_LauncherExe.ps1" (
    echo [0/4] 重新编译 EXE...
    if exist "%ROOT%\RBR_Install_Assistant.exe" del /f /q "%ROOT%\RBR_Install_Assistant.exe"
    if exist "%ROOT%\dist\RBR_Install_Assistant.exe" del /f /q "%ROOT%\dist\RBR_Install_Assistant.exe"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\tools\Build_LauncherExe.ps1"
    if errorlevel 1 (
        echo [错误] EXE 构建失败，已中止。
        exit /b 1
    )
) else (
    echo [错误] 缺少 tools\Build_LauncherExe.ps1，无法构建 EXE。
    exit /b 1
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"

echo [1/4] 复制发布文件...

copy /y "%ROOT%\启动安装助手.bat" "%STAGE_DIR%\" >nul
if errorlevel 1 (
    echo [错误] 缺少 启动安装助手.bat
    exit /b 1
)

copy /y "%ROOT%\README.md" "%STAGE_DIR%\" >nul
if errorlevel 1 (
    echo [错误] 缺少 README.md
    exit /b 1
)

copy /y "%ROOT%\RBR_Install_Assistant.exe" "%STAGE_DIR%\" >nul
if errorlevel 1 (
    echo [错误] 缺少 RBR_Install_Assistant.exe
    exit /b 1
)

xcopy "%ROOT%\assets" "%STAGE_DIR%\assets\" /E /I /Y >nul
if errorlevel 1 (
    echo [错误] 复制 assets 失败
    exit /b 1
)

xcopy "%ROOT%\dist" "%STAGE_DIR%\dist\" /E /I /Y >nul
if errorlevel 1 (
    echo [错误] 复制 dist 失败
    exit /b 1
)

xcopy "%ROOT%\scripts" "%STAGE_DIR%\scripts\" /E /I /Y >nul
if errorlevel 1 (
    echo [错误] 复制 scripts 失败
    exit /b 1
)

if exist "%ROOT%\JSGAME\JSGME MOD MANAGER.exe" (
    if not exist "%STAGE_DIR%\JSGAME" mkdir "%STAGE_DIR%\JSGAME"
    copy /y "%ROOT%\JSGAME\JSGME MOD MANAGER.exe" "%STAGE_DIR%\JSGAME\" >nul
    if exist "%ROOT%\JSGAME\JSGME.ini" copy /y "%ROOT%\JSGAME\JSGME.ini" "%STAGE_DIR%\JSGAME\" >nul
) else (
    echo [警告] JSGAME\JSGME MOD集合程序.exe 不存在，跳过 MOD 工具复制。
)

if exist "%ROOT%\*.torrent" (
    copy /y "%ROOT%\*.torrent" "%STAGE_DIR%\" >nul
)

echo [2/4] 生成 ZIP...
if exist "%ZIP_PATH%" del /f /q "%ZIP_PATH%" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Compress-Archive -Path '%STAGE_DIR%\*' -DestinationPath '%ZIP_PATH%' -CompressionLevel Optimal"
if errorlevel 1 (
    echo [错误] 压缩失败
    exit /b 1
)

echo [3/4] 清理临时目录...
rmdir /s /q "%STAGE_DIR%"

echo [4/4] 完成
echo [OK] 发布包：%ZIP_PATH%
echo.
exit /b 0
