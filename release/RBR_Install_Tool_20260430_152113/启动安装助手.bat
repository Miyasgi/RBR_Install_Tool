@echo off
setlocal
chcp 65001 >nul
title RBR 自动安装助手（小白版）

echo.
echo  ==================================================
echo   RBR 自动安装助手（双击即可）
echo  ==================================================
echo.
echo  使用说明：
echo   1) 请先把压缩包完整解压到一个文件夹
echo   2) 双击本文件即可（需要时会自动弹出管理员确认）
echo   3) 弹窗点“是”，然后等待自动下载和安装
echo.

set "BASE=%~dp0"
set "EXE=%BASE%dist\RBR_Install_Assistant.exe"
set "BUILD_PS1=%BASE%tools\Build_LauncherExe.ps1"

if exist "%EXE%" (
	echo [提示] 正在启动 EXE 版本安装助手...
	start "" "%EXE%"
	exit /b 0
)

echo [错误] 未找到 RBR_Install_Assistant.exe
echo [提示] 请确认你已完整解压安装包。
echo [提示] 若你拿到的是脚本源码，可自动构建 EXE。

if exist "%BUILD_PS1%" (
	echo.
	echo [可选] 是否现在自动生成 EXE？(Y/N)
	set /p _build=
	if /I "%_build%"=="Y" (
		powershell -NoProfile -ExecutionPolicy Bypass -File "%BUILD_PS1%"
		if exist "%EXE%" (
			echo [OK] EXE 生成成功，正在启动...
			start "" "%EXE%"
			exit /b 0
		)
	)
)

echo.
pause
exit /b 1
