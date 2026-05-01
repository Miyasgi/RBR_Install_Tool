# project_log.md (DEV ONLY)

> Internal development log for the maintainer.
> Do NOT include this file in user release ZIP/package.
> 建议打包前删除本文件，或只打包白名单文件夹（assets/dist/scripts）+ 启动安装助手.bat + README.md。

## 1) Project Goal

Build a beginner-friendly RBR installer assistant for non-technical users:
- One-click (or double-click) start
- GUI workflow (no visible PowerShell console)
- qBittorrent guided/automated flow
- Auto or manual fallback launch of installer
- Stable packaging for sharing in group chats

## 2) Current Folder Layout (Refactored)

- assets/
  - RBR_INSTALLER.png
  - RBR_INSTALLER.ico
- dist/
  - RBR_Install_Assistant.exe
- logs/
  - RBR_Auto_Installer.log
- scripts/
  - RBR_UI_Launcher.ps1
  - RBR_Auto_Installer.ps1
- tools/
  - Build_LauncherExe.ps1
  - Generate_Logo.ps1
- README.md
- 启动安装助手.bat
- project_log.md (this file, DEV ONLY)

## 3) Main Components

### 3.1 scripts/RBR_Auto_Installer.ps1
Backend orchestration script:
- Detects qBittorrent
- Configures/uses qB API when possible; fallback non-API flow
- Adds torrent and monitors progress
- Detects installer EXE and launches it
- Logs progress/status to log file
- Supports GuiMode for non-interactive behavior
- Includes single-instance mutex

Important parameters:
- -TorrentFile
- -DownloadPath
- -InstallerFile
- -GuiMode
- -LogPath

### 3.2 scripts/RBR_UI_Launcher.ps1
WinForms UI frontend:
- Select torrent / optional installer / download path
- Drive confirmation UX
- Auto fetch/download from RSF official page
- Progress monitor window with concise logs
- Optional verbose mode
- Manual "已完成下载，启动安装器" button
- New: "我已安装 qB，继续" button for in-place continue

### 3.3 tools/Build_LauncherExe.ps1
Builds dist/RBR_Install_Assistant.exe using csc.exe:
- Embeds icon from assets/
- Compiles C# launcher
- Launcher resolves scripts from projectRoot/scripts

### 3.4 启动安装助手.bat
Simple user entry:
- Starts dist/RBR_Install_Assistant.exe
- If missing, can trigger tools/Build_LauncherExe.ps1

## 4) Key UX/Behavior Milestones

1. Beginner-friendly docs and launcher flow
2. Hidden backend execution in GUI mode
3. qB save-path handling improvements
4. Progress monitor de-noising and dedupe
5. Manual installer launch fallback in monitor
6. Single-instance protection
7. Explicit drive selector + confirmation
8. Missing qB in GuiMode auto-opens qB download page
9. Missing qB can now continue in same monitor window (no app restart)
10. Full folder structure refactor (scripts/tools/dist/logs)

## 5) Latest Changes (This Session)

### 5.1 Continue without reopening app
Implemented in scripts/RBR_UI_Launcher.ps1:
- Added monitor button: "我已安装 qB，继续"
- Trigger condition: log contains "未检测到 qBittorrent" or "仍未找到 qBittorrent"
- On click: re-launches backend with same arguments and keeps user in monitor UI
- Monitor resets internal tail state and continues in-place

### 5.2 qB missing in GuiMode auto-open fix
Implemented in scripts/RBR_Auto_Installer.ps1:
- If qB missing and GuiMode=true, auto-open https://www.qbittorrent.org/download
- Console mode keeps old Y/N prompt behavior

### 5.3 Folder cleanup/refactor
- Moved scripts to scripts/
- Moved build/logo scripts to tools/
- Moved EXE to dist/
- Moved logs to logs/
- Updated path resolution for backward compatibility
- Rebuilt EXE successfully after refactor

## 6) Packaging Guidance (User Release)

Recommended user package contents:
- 启动安装助手.bat
- README.md
- dist/
- scripts/
- assets/

Do NOT include (developer/internal):
- project_log.md
- tools/ (optional for dev only; not needed by end users if dist exe already built)
- logs/ (optional; usually not needed in fresh package)

## 7) Known Warnings / Technical Debt

- Historical PowerShell analyzer warning about assigning to automatic variable name "matches" in one old location may still appear depending on analyzer context. Runtime behavior currently not blocked.
- WinForms monitor logic is feature-rich; if future regressions occur, consider extracting monitor state machine into helper functions.

## 8) Quick Run/Build Commands (Dev)

From project root:

- Build EXE:
  - powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build_LauncherExe.ps1

- Run UI script directly:
  - powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\RBR_UI_Launcher.ps1

- Run backend directly:
  - powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\RBR_Auto_Installer.ps1

## 9) Suggested Next Steps (When Token Is Back)

1. Add a release packaging script (e.g., tools/Pack_Release.ps1) to auto-export whitelist files and explicitly exclude dev files.
2. Add a small self-check in UI startup to verify required folders/files and show friendly fix guidance.
3. Optional: add version file and display app version in UI title.
4. Optional: split monitor parsing logic into dedicated functions for maintainability.

## 10) Maintenance Note

If you continue development later, update this log first:
- what changed
- why changed
- any regressions discovered
- packaging impact

## 11) Incident Record: UI Not Showing After Refactor

Issue reported:
- User clicked launcher/EXE, but main UI window did not appear ("点了没反应").

Root cause:
- Parse error introduced in scripts/RBR_UI_Launcher.ps1.
- Status text used Chinese quote characters directly inside double-quoted PowerShell strings, causing parser failure before form render.

Symptoms observed:
- Running UI script directly produced parser errors around text containing "我已安装 qB，继续".
- Because script failed on startup, EXE seemed to do nothing.

Fix applied:
- Rewrote affected label text to safe string form (single-quoted string with escaped internal quote markers).
- Rebuilt launcher EXE after script fix.

Related compatibility improvement:
- Build output now keeps RBR_Install_Assistant.exe in project root and also syncs a copy to dist/.
- Launcher BAT prefers root EXE, then falls back to dist EXE.
- EXE bootstrap now searches scripts in multiple locations (same dir and parent dir variants) for better resilience.

Verification:
- Syntax check passed for scripts/RBR_UI_Launcher.ps1.
- tools/Build_LauncherExe.ps1 rebuild succeeded.

Prevention note:
- For UI text containing Chinese punctuation/quotes, prefer single-quoted strings in PowerShell or escape embedded quotes explicitly.

## 12) Latest Delta Update (2026-04-30)

### 12.1 Continue button status not changing after qB install

Issue:
- User clicked "我已安装 qB，继续", but monitor status stayed on failure and did not visibly move into qB startup/torrent-open phase.

Root cause:
- Monitor reused old log content after retry, so previous failure lines could overwrite/contaminate current run status.

Fix:
- In scripts/RBR_UI_Launcher.ps1, on continue click:
  - Clear runtime log before relaunch.
  - Reset monitor state variables (`lastLine`, `lastPrintedLine`, phase).
- On non-zero exit, continue button can still re-enable (not only qB-missing-specific branch), allowing direct retry.

Result:
- Retry flow is now in-place and less likely to appear "stuck" on old failed state.

### 12.2 Optional assisted qB download (SourceForge latest)

User requirement:
- Similar to torrent assistance, allow optional help to download qB directly via fixed latest link.

Implementation:
- scripts/RBR_UI_Launcher.ps1:
  - Added a Yes/No popup when qB is missing in monitor.
  - Yes opens: https://sourceforge.net/projects/qbittorrent/files/latest/download
  - User then installs qB and clicks "我已安装 qB，继续".
- scripts/RBR_Auto_Installer.ps1:
  - Added `$script:QbtLatestDownloadLink`.
  - GuiMode missing-qB auto-open now uses SourceForge latest link.
  - Console prompt branch also opens SourceForge latest link if user confirms.
  - Console hints now show both official page and latest direct link.

### 12.3 EXE placement + launcher compatibility

Context:
- After folder refactor, user expected root EXE behavior; dist-only EXE caused confusion.

Adjustment:
- tools/Build_LauncherExe.ps1 now builds root EXE and sync-copies to dist.
- 启动安装助手.bat now prefers root EXE and falls back to dist EXE.
- EXE bootstrap script lookup made resilient across baseDir/parentDir + scripts variants.

### 12.4 Verification snapshot

- Rebuild successful:
  - RBR_Install_Assistant.exe (root)
  - dist/RBR_Install_Assistant.exe
- scripts/RBR_UI_Launcher.ps1: no syntax errors after fixes.

### 12.5 Remaining notes

- Existing analyzer warnings in scripts/RBR_Auto_Installer.ps1 (e.g., `matches`/`args` automatic variable naming, unapproved verb naming) are historical and non-blocking for runtime.
- If needed later, clean these warnings in a separate maintenance pass to reduce noise.
