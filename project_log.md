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

## 13) Correction Update (2026-04-30, later)

### 13.1 Strict installer launch gating (backend)

Problem:
- Installer EXE could launch too early in non-API path (before torrent completion was confirmed).

Change:
- scripts/RBR_Auto_Installer.ps1 now enforces strict rule:
  - Only launch installer after confirmed torrent completion (fallback API confirmation).
  - If installer file is found but torrent completion is not confirmed, do NOT launch.
  - Removed non-API fallback that attempted to launch preferred installer without confirmed completion.

Outcome:
- qB detection/config issues no longer allow early installer popup.

### 13.2 qB download consent behavior aligned

Problem:
- In GuiMode, backend auto-open could conflict with UI interaction expectations.

Change:
- scripts/RBR_Auto_Installer.ps1 in GuiMode no longer auto-opens qB download page.
- Browser opening is now user-driven from UI only.

Outcome:
- No automatic jump to qB page without user action.

### 13.3 False "exit code 1" status mitigation in monitor

Problem:
- Monitor could show failure while backend was still running/logging (process handle/re-elevation tracking mismatch).

Change in scripts/RBR_UI_Launcher.ps1:
- Added Start-BackendProcess helper:
  - If already admin: start without Verb RunAs.
  - If not admin: start with Verb RunAs.
- Continue button now blocks duplicate relaunch when current process is still running.
- Exit handling now checks recent log activity; if logs are still updating, monitor keeps running instead of immediately showing failure.

Outcome:
- Reduced false negative failure state on top status label.

### 13.4 qB download UX changed from popup to explicit button

Problem:
- Repeated download prompts could trigger multiple qB downloads.

Change in scripts/RBR_UI_Launcher.ps1:
- Removed automatic Yes/No qB download popup.
- Added explicit button: "下载 qB 最新版".
- Button is enabled only when qB missing is detected; user must click manually to open latest download link.

Outcome:
- No repeated auto prompts; no accidental multiple downloads from prompt spam.

## 14) End-of-Day Debug Snapshot (2026-04-30)

### 14.1 Repeated WARN issue still observed in some runs

Observed symptom:
- Log repeatedly shows: `已发现安装器文件，但尚未确认 torrent 下载完成，暂不启动。`
- User also observed qB task already at `100% / Seeding`, but installer EXE still not launched.

Important evidence from logs/screenshots:
- During some runs, same warning appears many times across the same attempt.
- Earlier logs also showed duplicated lines like repeated `检测到安装器文件已更新` and repeated `仍在等待下载完成...`, which strongly suggests concurrent or overlapping backend instances writing to the same log.
- In one reproduced case, backend spent ~60s in WebUI startup phase, then fell back to non-API mode and entered wait loop.

### 14.2 Root-cause hypotheses narrowed down

Likely causes identified:
1. Duplicate backend instances / overlapping runs.
  - This can corrupt monitor interpretation and produce repeated WARN cadence.
2. Non-API completion confirmation too strict / unreliable.
  - WebUI timeout pushes flow into non-API mode.
  - Completion then relies on fallback heuristics around installer file presence/stability.
3. `Rallysimfans_Installer.exe` may already exist in target folder and continue changing in ways that never satisfy the fallback completion gate.

### 14.3 Fixes already applied today

Backend changes in scripts/RBR_Auto_Installer.ps1:
- Added strict rule: installer must not auto-launch before confirmed completion.
- Added file-size-based stability fallback (removed timestamp dependence) to reduce false "not finished" state during Seeding/checking.
- Added exclusive lock file: `RBR_Auto_Installer.lock`
  - Intended behavior: if lock is already held, new backend instance exits with code `2`.

UI changes in scripts/RBR_UI_Launcher.ps1:
- Added `Start-BackendProcess` helper.
- Improved handling for false non-zero exit while logs still update.
- Added special message for exit code `2` (already running).
- Added UI-side lock check before continue/start logic to prevent duplicate launch.

### 14.4 Current state before stopping

What is done:
- Code for UI-side lock detection was added.
- That last UI-side duplicate-start prevention change was edited successfully.

What was NOT completed before session end:
- Final rebuild after the most recent UI-side lock check was NOT completed because tool execution was cancelled.
- Therefore current source tree includes the latest UI lock-check code, but EXE may not yet contain that very last change unless rebuilt next session.

### 14.5 First actions for next session

1. Rebuild EXE immediately:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build_LauncherExe.ps1`
2. Test with exactly one fresh launch of root EXE.
3. If repeated WARN still occurs after rebuild:
  - inspect whether `RBR_Auto_Installer.lock` is working as intended;
  - inspect whether installer file size is actually stable while qB shows Seeding;
  - consider adding an explicit fallback rule: if qB UI visually reaches `100% / Seeding` and installer file exists, allow immediate launch in non-API mode.

### 14.6 Practical note for tomorrow

- Start from source, not from assumption.
- First confirm whether duplicate backend instances still happen after the new lock checks.
- If duplicate runs are eliminated and issue remains, focus only on the non-API completion heuristic in `Wait-InstallerAndLaunch`.

## 15) Session Update (2026-05-08)

### 15.1 Changes made this session (NOT YET fully tested)

scripts/RBR_Auto_Installer.ps1:
- Removed `Downloads\SavePath` from restart-trigger check in `Enable-QbtWebUIConfig`.
  **Why:** SavePath format differences (trailing slash, etc.) caused needless qBittorrent restart every run → Web UI startup delay.
- Restructured steps 4-5: open torrent immediately, poll Web UI in background (non-blocking).
  **Why:** Previously waited up to 60s for Web UI BEFORE opening torrent. Now torrent opens instantly.
- Added `$script:TorrentAlreadyOpened` flag to prevent duplicate torrent open in non-API block.
- Fixed `Wait-InstallerAndLaunch`: `PreferredInstaller` now bypasses pre-existing file size check.
  **Why:** Pre-existing check was blocking launch when file already existed from previous download with same size.
- Added `SEEDING_LAUNCH_READY=<path>` log signal + 3s delay before auto-launching installer.
- Fixed qBittorrent restart logic: kill existing process BEFORE starting new one when config updated.

scripts/RBR_UI_Launcher.ps1:
- Added `FormClosed` handler to kill backend process when monitor window closes.
  **Why:** Backend was orphaned after UI close, holding lock file → next run blocked.
- Added UI handler for `SEEDING_LAUNCH_READY` log signal → shows MessageBox popup.
- Updated QBT_STARTUP label to show elapsed seconds instead of "约 10-60 秒".

### 15.2 Still broken / not confirmed fixed

1. **Two backend instances running simultaneously** — lock file not preventing duplicate launches.
   - Log shows identical timestamps for both sets of step entries (20:21:29).
   - Lock file mechanism exists but may be failing silently.
   - Priority: investigate why lock is not working before anything else.

2. **Web UI still not connecting (2 min timeout)** — SavePath fix not yet tested.
   - All logs shown still from old code. Need fresh test with new code.

3. **Pre-existing installer file detection** — fixed in code but not yet confirmed.

### 15.3 First actions next session

1. Clear log: `Clear-Content .\logs\RBR_Auto_Installer.log`
2. Run fresh test via start.bat (admin).
3. Check if TWO instances still appear in log — if yes, debug lock file mechanism first.
4. Check if Web UI connects faster (SavePath fix should eliminate needless restarts).
5. Check if installer launches when already at Seeding state.

## 17) Session Update (2026-05-10) — 中文系统兼容性大修

### 17.1 背景

用户反馈：发布给朋友使用后，出现两类问题：
1. 允许 SmartScreen 后没反应、UI 不弹出
2. 中文 Win10/Win11 系统完全无法使用

### 17.2 问题一：UAC 弹窗不可见

**根因：**
EXE 本身没有请求管理员权限的 manifest，但在代码里用 `Verb = "runas"` 让 PowerShell 以管理员启动。这个 UAC 弹窗是异步的——EXE 自己立刻退出，UAC 孤立在后台任务栏闪烁，用户看不见，PowerShell 从未启动，UI 永远不出现。

**修复：**
- `Build_LauncherExe.ps1`：给 EXE 嵌入 UAC manifest，`requestedExecutionLevel = asInvoker`（工具本身不需要管理员权限）
- `RBR_UI_Launcher.ps1`：`Start-BackendProcess` 去掉 `Verb RunAs`，直接以当前权限启动后端
- 安装器本身（`Rallysimfans_Installer.exe`）运行时会自己弹 UAC

### 17.3 问题二：中文路径下 PowerShell 无法启动脚本

**根因 A：ShellExecute ANSI 编码问题**
EXE 原来用 `UseShellExecute = true` 启动 PowerShell，ShellExecuteEx 走 ANSI 接口，中文路径字节被截断或损坏，PowerShell 找不到脚本文件，静默退出，无任何日志。

**修复 A：**
- 改为 `UseShellExecute = false` + `CreateNoWindow = true`，走 `CreateProcess` Unicode 接口
- 进一步改用 `WorkingDirectory = scriptDir`，只传文件名给 `-File`，彻底避免中文出现在命令行参数里

**根因 B（真正根因）：PS1 脚本 UTF-8 无 BOM**
中文 Windows 系统的 PowerShell 5.1 默认用系统 ANSI 编码（GBK/CP936）读取脚本。脚本保存为 UTF-8 无 BOM，系统读取时将 UTF-8 字节当 GBK 解析，中文字符串全部乱码，PowerShell 在解析阶段就报语法错误退出，一行代码都不会执行（包括启动日志）。

症状截图：`'lbl.torrent' = 'Torrent 鏂囦欢锛?` — 典型 UTF-8 被 GBK 误读的乱码。

**修复 B：**
- 给 `scripts/RBR_UI_Launcher.ps1` 和 `scripts/RBR_Auto_Installer.ps1` 都加上 UTF-8 BOM（EF BB BF）
- PowerShell 看到 BOM 后不论系统语言设置，都会用 UTF-8 读取脚本

### 17.4 其他改进

**启动崩溃日志：**
- `RBR_UI_Launcher.ps1` 顶部加了 `try { ... } catch { }` 包裹全脚本
- 任何启动失败写入 `%TEMP%\RBR_Installer_startup.log`（路径永远可写）
- 如果 WinForms 已加载，额外弹 MessageBox 告知日志位置

**build.bat 优化：**
- 原来只在 EXE 不存在时才重新编译，每次打包可能带入旧版 EXE
- 改为每次都强制删旧 EXE 重新编译再打包

**csc 编译修复：**
- 发现 Edit 工具写入 C# 代码时会将直引号替换为 Unicode 弯引号（U+201C/201D），导致 csc.exe 报 CS1056
- 将 `$code` 从双引号 here-string（`@"..."@`）改为单引号 here-string（`@'...'@`），避免 PowerShell 字符处理
- 同时用 PowerShell 批量替换文件内残留弯引号

**工程改进：**
- 添加 `.gitignore`：排除 `release/`、`.claude/`、`logs/`、`qbt_path.cache`
- CI build.yml 打包方式验证正常

### 17.5 发布历史

| 版本 | 说明 |
|------|------|
| v1.0.6 | 修复 UAC 不可见、去掉 RunAs、改 CreateProcess |
| v1.0.7（CI 中） | 加 UTF-8 BOM，修复中文系统 GBK 解析崩溃（根本原因） |

### 17.6 经验教训

1. PowerShell 5.1 在非英文系统上读取无 BOM 的 UTF-8 文件会用系统 ANSI 编码，导致乱码崩溃。**所有 PS1 脚本必须带 UTF-8 BOM。**
2. ShellExecuteEx 走 ANSI 接口，中文路径有风险。用 CreateProcess（`UseShellExecute = false`）+ `WorkingDirectory` 更可靠。
3. 工具本身不需要管理员权限时，不要用 `requireAdministrator` manifest，用 `asInvoker` 直接运行，避免 UAC 干扰用户体验。
4. 如果脚本完全没有输出/日志，优先怀疑 PowerShell 解析阶段就失败了（语法/编码问题），而不是运行时错误。

## 18) Session Update (2026-05-18) — MOD 管理器功能集成

### 18.1 需求背景

用户现有流程：手动解压 MOD 文件夹 → 拖到游戏根目录 → 运行 JSGME。对新手不友好。
目标：把 MOD 管理器流程整合进现有 UI，加一个新 Tab。

### 18.2 主要变更

**scripts/RBR_UI_Launcher.ps1：**
- Form 高度从 370 → 450
- 新增 TabControl，两个 TabPage：
  - Tab 1：游戏安装（原有所有控件迁移进来，`$form.Controls.Add` → `$tabPage1.Controls.Add`）
  - Tab 2：MOD 管理器（全新）
- Tab 2 布局（三步走）：
  - 顶部：警告标签（请先装完游戏再用 MOD 管理器）+ 游戏根目录输入框（随 Tab 切换自动同步 Tab 1 路径）
  - 第一步：本地导入（文件夹/ZIP）+ GitHub 下载 + 百度网盘下载（共 4 个按钮）
  - 第二步：一键部署 JSGME 工具（Copy-Item "$jsGameDir\*" → 游戏根目录）
  - 第三步：打开 JSGME（部署成功后按钮才可用）
- Tab 切换事件：每次切到 Tab 2 都强制同步路径，不管是否为空
- 新变量：`$jsGameDir`、`$jsgmeExeName`、`$script:ModsGithubUrl`、`$script:ModsBaiduUrl`
- `Update-ModStatus` 函数：检测游戏目录是否有 JSGME EXE，控制第三步按钮状态
- 双语 i18n 字符串：`tab.install`、`tab.mod`、`mod.*` 系列全部覆盖

**JSGAME/ 目录：**
- 新增 `JSGAME/JSGME MOD MANAGER.exe`（已提交进仓库）
- 新增 `JSGAME/JSGME.ini`（`Name=MODS`，游戏目录 FullPath 为占位符）
- `JSGAME/MODS/`：**不提交**（文件太大）

**build.bat：**
- 新增 JSGAME 文件复制逻辑：打包时把 `JSGME MOD MANAGER.exe` + `JSGME.ini` 复制进 ZIP
- 不包含 MODS 文件夹（通过 GitHub Releases / 百度网盘分发）

**.gitignore：**
- 新增 `JSGAME/*.zip`（排除 RBR_MODS.zip）
- 新增 `JSGAME/MODS/`（排除大型 MOD 文件夹）

### 18.3 MOD 包分发方案

- GitHub Releases：`https://github.com/Miyasgi/RBR_Install_Tool/releases/download/v2.0.1/RBR_MODS.zip`
- 百度网盘（备用）：`https://pan.baidu.com/s/1ZiGbMfBat1Ok0I6nAU8Jxg?pwd=fxme`
- UI 提示：优先 GitHub，无法访问再用百度

### 18.4 关键设计决策

| 决策 | 原因 |
|------|------|
| 部署时不做 JSGME 文件存在性校验 | 直接 Copy-Item，用户自己保证 JSGAME 目录内容正确 |
| Tab 2 路径永远从 Tab 1 同步 | 避免两个 Tab 路径不一致导致部署错位置 |
| MODS 文件夹不进 git | 110MB 二进制文件不适合 git，走 Releases 分发 |
| JSGME.ini `Name=MODS` | 对应本地 MODS 文件夹名，确保 JSGME 找到正确目录 |

### 18.5 当前状态

- 分支：`feature-mod-installer`
- 最新 commits：`bc8af7d`（MOD Manager 主功能）、`a150800`（加 GitHub 下载按钮）
- 待完成：本地测试（start.bat）→ 通过后创建 PR 合并 main

### 18.6 打包说明更新

发布 ZIP 新增内容：
- `JSGAME/JSGME MOD MANAGER.exe`
- `JSGAME/JSGME.ini`

不包含（通过外部链接分发）：
- `JSGAME/MODS/`
- `JSGAME/*.zip`

## 16) Session Update (2026-05-09)

### 16.1 Confirmed working

- Seeding detection now works: script detects 100%/Seeding and auto-launches installer.
- UI shows popup "检测到下载完成（Seeding），安装器将在 3 秒后自动启动".
- Single-instance Mutex (Local\RBR_Auto_Installer) prevents duplicate backend processes.
- Popup only shows once per monitor session ($seedingPopupShown flag).

### 16.2 Fixes applied this session

scripts/RBR_Auto_Installer.ps1:
- Fixed Test-QbtWebUI: added null guard for $_.Exception.Response (crash when port not open yet).
- Fixed Test-QbtWebUI: now treats 401/403 as "Web UI is up" (was rejecting valid responses requiring auth).
- Replaced file-lock with named Mutex (Local\RBR_Auto_Installer) for single-instance enforcement.
- Fixed Wait-InstallerAndLaunch: PreferredInstaller bypasses pre-existing file size check.

scripts/RBR_UI_Launcher.ps1:
- Added $seedingPopupShown flag to prevent duplicate popups when multiple log entries appear.
- Replaced file-lock check with Mutex check in Test-BackendRunLockInUse.

### 16.3 Release workflow — still broken

Current state:
- workflow_dispatch trigger added to release.yml.
- softprops/action-gh-release@v2 replaced with gh CLI (gh release create).
- Tag auto-creation added for manual trigger, with skip-if-exists guard.
- BUT: main branch keeps rejecting push (non-fast-forward) — remote main has diverged.
- Every attempt to push fix hits "rejected: non-fast-forward" → requires git pull --rebase each time.

### 16.4 First actions next session

1. Fix the git push issue: `git pull origin main --rebase && git push origin main`
2. Go to GitHub → Actions → Release → Run workflow → select correct branch → fill version.
3. If gh release create still fails, check exact error message from the step.
4. Consider just using tag push (git tag v1.0.x && git push origin v1.0.x) as the primary release method — simpler and more reliable than workflow_dispatch.
