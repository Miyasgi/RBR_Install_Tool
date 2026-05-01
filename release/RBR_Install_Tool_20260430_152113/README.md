# RBR Auto Installer (Super Simple Guide) / RBR 自动安装助手（超小白说明）

This tool is made for users with very little computer experience.
If you can only download files and double-click, this guide is for you.

这个工具按“电脑小白”标准写的。
就算你只会下载文件和双击，也可以照着用。

---

## A) 3-Step Start / 三步启动

### Chinese (Recommended)

1. **先解压** ZIP 压缩包到一个普通文件夹（不要在压缩包里直接点运行）。
2. 在解压后的文件夹里，右键 **启动安装助手.bat**，点 **以管理员身份运行**。
3. 弹出系统确认窗口时，点 **是**，然后等待自动下载和自动弹出安装器。

### English

1. **Extract** the ZIP file first (do not run inside the ZIP preview).
2. In the extracted folder, right-click **启动安装助手.bat** and choose **Run as administrator**.
3. Click **Yes** on UAC prompt, then wait for automatic download and installer launch.

---

## B) Folder Layout / 文件结构（已整理）

### Chinese

请保持以下结构，不要随意改名：

1. 启动入口：启动安装助手.bat
2. 脚本目录：scripts\RBR_UI_Launcher.ps1 / scripts\RBR_Auto_Installer.ps1
3. 资源目录：assets\RBR_INSTALLER.png / assets\RBR_INSTALLER.ico
4. 构建脚本：tools\Build_LauncherExe.ps1
5. 可执行文件：dist\RBR_Install_Assistant.exe

### English

Please keep this structure (do not rename files):

1. Entry: 启动安装助手.bat
2. Scripts: scripts\RBR_UI_Launcher.ps1 / scripts\RBR_Auto_Installer.ps1
3. Assets: assets\RBR_INSTALLER.png / assets\RBR_INSTALLER.ico
4. Build script: tools\Build_LauncherExe.ps1
5. Executable: dist\RBR_Install_Assistant.exe

---

## B.1) Official Download Links (Fallback) / 官方下载链接（兜底）

### Chinese

如果你丢了文件，或者版本更新导致旧文件失效，用下面这个官网入口最稳：

1. 官网入口（推荐，长期有效概率最高）
https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr

2. 种子直链（版本号可能变化，可能过期）
https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/rsf_installer_files_V4.6.torrent

3. 安装器直链（参数可能变化，可能过期）
https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/Rallysimfans_Installer.exe?a9f2757c3ba9a6bc8b9abfa0e514cf12

### English

If files are missing or old links stop working, use this official page first:

1. Official page (recommended, most stable)
https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr

2. Torrent direct link (version may change and expire)
https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/rsf_installer_files_V4.6.torrent

3. Installer direct link (query token may change and expire)
https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/Rallysimfans_Installer.exe?a9f2757c3ba9a6bc8b9abfa0e514cf12

---

## C) What User Will See / 用户会看到什么

### Chinese

1. 脚本会自动检查 qBittorrent。
2. 没安装的话会提示你去官网下载并安装。
3. 下载过程中会显示进度条。
4. 下载完成后会自动打开安装器。
5. 安装器里请选 **Full Installation**。
6. 安装路径建议选 `E:\RBR`（不要装在 C 盘）。

### English

1. The script checks qBittorrent automatically.
2. If missing, it prompts user to install qBittorrent.
3. Download progress is shown.
4. Installer opens automatically after download.
5. Choose **Full Installation**.
6. Install to `E:\RBR` (avoid C drive).

---

## D) Most Common Problems / 最常见问题（按这个排查）

### 1) "Window closes too fast" / "窗口一闪而过"

Chinese:

1. 先确认已经解压，不是在压缩包里运行。
2. 确认 3 个必需文件都在同一个文件夹。
3. 再右键管理员运行 启动安装助手.bat。

English:

1. Make sure ZIP is extracted.
2. Make sure all 3 required files are present.
3. Run 启动安装助手.bat as administrator.

### 2) qBittorrent not found / 找不到 qBittorrent

Chinese:

1. 从官网安装：https://www.qbittorrent.org/download
2. 安装后重新运行脚本。
3. 仍然找不到时，按提示手动选择 qbittorrent.exe。

English:

1. Install from official site: https://www.qbittorrent.org/download
2. Re-run the script.
3. If still not found, manually pick qbittorrent.exe.

### 3) Download done but installer not opened / 下载完没有自动弹安装器

Chinese:

1. 到下载目录（通常是 `E:\RBR`）里找 `Rallysimfans_Installer*.exe`。
2. 手动双击它即可继续。

English:

1. Open download folder (usually `E:\RBR`).
2. Run `Rallysimfans_Installer*.exe` manually.

### 4) Antivirus blocks file / 杀毒软件拦截

Chinese:

1. 把这个工具文件夹加入信任/白名单。
2. 恢复被隔离文件后重试。

English:

1. Add this folder to AV allowlist.
2. Restore blocked files and retry.

---

## E) For Group Owner (You) / 给发群主的建议

### Chinese

建议发 ZIP，并附这句：

先解压，再右键管理员运行 启动安装助手.bat，不要在压缩包里直接打开。

### English

Send as ZIP with this one-line note:

Extract first, then run 启动安装助手.bat as administrator. Do not run from inside ZIP preview.

---

## F) Log File / 日志

If user has problems, ask for this file:

用户报错时，让他发这个文件：

logs\RBR_Auto_Installer.log
