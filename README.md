[中文](#中文) | [English](#english)

---

<a name="中文"></a>

# RBR 自动安装助手

自动帮你下载并启动 RBR（Richard Burns Rally）官方安装器的小工具。全程图形界面，无需手动操作 qBittorrent。

---

## 使用方法

### 第一次使用

1. 解压 ZIP 压缩包到任意普通文件夹（**不要在压缩包内直接运行**）
2. 双击 `RBR_Install_Assistant.exe`
3. 弹出 UAC 窗口时点 **是**

### 正常流程

启动后会出现一个图形界面，按提示操作：

1. 选择 `.torrent` 种子文件（默认会自动从官网获取）
2. 选择下载路径（建议选 C 盘以外的盘，如 `E:\RBR`）
3. 点击 **开始下载**
4. 程序会自动启动 qBittorrent 并开始下载
5. 下载完成（qBittorrent 显示 Seeding）后，程序自动弹出提示并打开安装器
6. 安装器打开后选择 **Full Installation**，路径建议用 `E:\RBR`

---

## 常见问题

### 窗口一闪而过

- 确认已解压，不是在压缩包内运行
- 确认右键用了**管理员身份运行**

### 找不到 qBittorrent / 提示未安装

工具会自动提示下载，点击界面里的 **下载 qB 最新版** 按钮，安装完成后点 **我已安装 qB，继续** 即可，不需要重新打开工具。

### 下载完了但安装器没有自动打开

1. 等待界面出现"检测到下载完成"的弹窗，点 OK
2. 如果长时间没有弹窗，点界面里的 **已完成下载，启动安装器** 按钮
3. 或者手动去下载目录（如 `E:\RBR`）找 `Rallysimfans_Installer*.exe` 双击运行

### 杀毒软件拦截了文件

将工具所在文件夹加入杀毒软件的信任/白名单，然后恢复被隔离的文件重试。

### qBittorrent 弹出窗口，保存路径不对

在弹出的"添加种子"窗口里，手动把 **Save at / 保存到** 改为你选择的下载路径，再点 OK。

---

## 官方下载链接（备用）

如果工具无法自动获取种子文件，可以手动下载：

- 官网页面（最稳定）：`https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr`
- 种子直链（版本号可能变化）：`https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/rsf_installer_files_V4.6.torrent`

---

## 日志文件

遇到问题时，日志在：

```
logs\RBR_Auto_Installer.log
```

---

<a name="english"></a>

# RBR Auto Installer

A tool that automatically downloads and launches the official RBR (Richard Burns Rally) installer. Fully GUI-based — no need to manually operate qBittorrent.

---

## How to Use

### First Time Setup

1. Extract the ZIP to any regular folder (**do not run directly inside the ZIP preview**)
2. Double-click `RBR_Install_Assistant.exe`
3. Click **Yes** on the UAC prompt

### Normal Flow

A GUI window will appear. Follow the steps:

1. Select a `.torrent` file (the tool can fetch it automatically from the official site)
2. Choose a download path (recommended: a non-C drive, e.g. `E:\RBR`)
3. Click **Start Download**
4. The tool starts qBittorrent and begins downloading automatically
5. When the download finishes (qBittorrent shows Seeding), a popup appears and the installer opens automatically
6. In the installer, choose **Full Installation** and use a path like `E:\RBR`

---

## Common Problems

### Window closes immediately

- Make sure the ZIP is fully extracted before running
- Make sure you right-clicked and chose **Run as administrator**

### qBittorrent not found

The tool will offer to download it for you. Click **Download latest qB** in the interface, install it, then click **I've installed qB, continue** — no need to restart the tool.

### Download finished but installer didn't open

1. Wait for the "Download complete (Seeding detected)" popup and click OK
2. If no popup appears after a long wait, click the **Launch Installer** button in the interface
3. Or manually open your download folder (e.g. `E:\RBR`) and run `Rallysimfans_Installer*.exe`

### Antivirus blocked a file

Add the tool's folder to your antivirus allowlist/whitelist, restore any quarantined files, then try again.

### qBittorrent dialog shows wrong save path

In the "Add Torrent" dialog, manually change **Save at** to your chosen download path, then click OK.

---

## Official Download Links (Fallback)

If the tool cannot fetch the torrent automatically:

- Official page (most reliable): `https://www.rallysimfans.hu/rbr/download.php?download=rsfrbr`
- Torrent direct link (version may change): `https://www.rallysimfans.hu/rbr/downloads/Rallysimfans_Installer/rsf_installer_files_V4.6.torrent`

---

## Log File

If something goes wrong, share this file:

```
logs\RBR_Auto_Installer.log
```
