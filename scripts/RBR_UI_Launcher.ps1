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

$script:AppVersion = 'v2.1.0'

$jsGameDir    = Join-Path $projectRoot 'JSGAME'
$jsgmeExeName = 'JSGME MOD MANAGER.exe'
# Fill in the Baidu Netdisk URL for the MODS pack before distributing:
$script:ModsGiteeUrl     = 'https://gitee.com/Miyasgi/RBR_Install_Tool/releases/download/v2.4.1/RBR_MODS.zip'
$script:ModsGithubUrl    = 'https://github.com/Miyasgi/RBR_Install_Tool/releases/download/v2.2.1/RBR_MODS.zip'
$script:ModsGithubSha256 = 'f83e3ac0da86cb8218a43e27563cac48422b412c6c0d551e9c38f707e4a64927'
$script:ModsBaiduUrl     = 'https://pan.baidu.com/s/1ZiGbMfBat1Ok0I6nAU8Jxg?pwd=fxme'
$script:I18nGiteeUrl     = 'https://gitee.com/Miyasgi/RBR_Install_Tool/releases/download/v2.4.1/RBRi18n-v1.3.3.zip'

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
        'qb.status.ok'           = '✓ qBittorrent 已安装，可正常使用'
        'qb.status.missing'      = '✗ 未检测到 qBittorrent — 请先安装后再点"开始"'
        'qb.btn.dl'              = '下载 qBittorrent'
        'welcome.title'          = '欢迎使用 RBR 安装助手'
        'welcome.msg'            = "第一次使用？三步完成：`n`n① 安装 qBittorrent（若下方显示未安装，点右侧下载按钮）`n② 在本页点【自动下载】，等待游戏下载并安装`n③ 游戏装好后进【MOD 管理器】安装插件和汉化包`n`n之后打开不再显示此提示。"
        'welcome.btn'            = '知道了，开始使用'
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
        'tab.install'            = '游戏安装'
        'tab.mod'                = 'MOD 管理器'
        'mod.warn'               = '[!]  请先在【游戏安装】页完成游戏安装，再使用 MOD 管理器'
        'mod.lbl.root'           = '游戏根目录：'
        'mod.jsgme.status.none'  = 'JSGME 状态：未部署到游戏目录'
        'mod.jsgme.status.ok'    = 'JSGME 状态：已就绪 (可直接打开)'
        'mod.step1.title'        = '第一步：获取 MOD 插件集合包'
        'mod.step1.note'         = '已有文件可直接本地导入；若需下载：优先 GitHub，无法访问再用百度网盘。'
        'mod.btn.importfolder'   = '本地导入（文件夹）'
        'mod.btn.importzip'      = '本地导入（ZIP）'
        'mod.btn.githubdl'       = '在线下载'
        'mod.btn.baidudl'        = '百度网盘下载'
        'mod.import.status'      = '导入状态：等待'
        'mod.import.doing'       = '导入状态：正在复制，请稍候...'
        'mod.import.done'        = '导入状态：成功'
        'mod.import.err'         = '导入状态：失败 — {0}'
        'mod.dlg.folder'         = '选择 MOD 插件集合包 文件夹'
        'mod.dlg.zip'            = '选择 MOD 压缩包 (.zip)'
        'mod.dlg.zip.filter'     = 'ZIP 压缩包 (*.zip)|*.zip|所有文件 (*.*)|*.*'
        'mod.err.nobaiduurl'     = 'MOD 包下载链接暂未配置，请联系发布者获取。'
        'mod.step2.title'        = '第二步：将 JSGME 工具部署到游戏目录'
        'mod.btn.install'        = '一键部署 MOD 管理器'
        'mod.install.status'     = '状态：等待操作'
        'mod.install.doing'      = '状态：正在复制文件...'
        'mod.install.done'       = '状态：已成功部署到游戏目录'
        'mod.install.err'        = '状态：复制失败 — {0}'
        'mod.step3.title'        = '第三步：在 JSGME 中勾选并启用 MOD'
        'mod.btn.open'           = '打开 MOD 管理器 (JSGME)'
        'mod.err.noroot'         = '请先输入或确认游戏根目录路径。'
        'mod.err.nojsgame'       = "找不到 JSGME 工具文件，请确认 JSGAME 目录存在。`n预期路径：{0}"
        'mod.err.noexe'          = '游戏目录中未找到 JSGME，请先完成第二步部署。'
        'mod.err.launch'         = '启动 JSGME 失败：{0}'
        'mod.err.nodlurl'        = 'MOD 包下载链接暂未配置，请联系发布者获取下载地址。'
        'mod.import.extracting'  = '正在解压... {0}% ({1}/{2})'
        'mod.dl.starting'        = '正在连接 GitHub，请稍候...'
        'mod.dl.progress'        = '正在下载... {0} MB'
        'mod.dl.progress.pct'    = '正在下载... {0} MB / {1} MB ({2}%)'
        'mod.dl.extracting'      = '下载完成，正在解压...'
        'mod.dl.done'            = '✓ MOD 包下载并导入完成'
        'mod.dl.fail'            = '下载失败，请检查网络或改用百度网盘下载后本地导入'
        'mod.install.warn.nomods'= '⚠ JSGME 已部署，但 MODS 文件夹为空——请先完成第一步导入 MOD 包'
        'i18n.step.title'        = '★ 汉化包（RBRi18n）：游戏安装完成后可一键安装'
        'i18n.btn.install'       = '安装内置汉化包'
        'i18n.btn.update'        = '在线更新 ↗'
        'i18n.status.fetching'   = '正在查询最新版本...'
        'i18n.status.dl'         = '正在下载 {0}...'
        'i18n.status.extract'    = '正在解压到游戏目录...'
        'i18n.status.done'       = '✓ 汉化安装完成（{0}）'
        'i18n.status.bundled'    = '内置：{0}'
        'i18n.err.noroot'        = '请先设置游戏下载目录（第三行）'
        'i18n.err.noasset'       = '未找到可下载的汉化包文件，请检查网络'
        'i18n.err.nolocal'       = '未找到内置汉化包，请用右侧按钮从 GitHub 下载'
        'i18n.err.fail'          = '失败：{0}'
        'notify.moddl.done.title'= 'MOD 包已就绪'
        'notify.moddl.done.body' = 'MOD 包导入并部署完成，可在 MOD 管理器中启用插件了'
        'notify.qb.found.title'  = 'qBittorrent 已就绪'
        'notify.qb.found.body'   = 'qBittorrent 安装成功！现在可以点击【自动下载】继续'
        'mod.auto.deploy'        = '正在自动部署 JSGME...'
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
        'qb.status.ok'           = '✓ qBittorrent is installed — ready to use'
        'qb.status.missing'      = '✗ qBittorrent not found — please install it before clicking Start'
        'qb.btn.dl'              = 'Download qBittorrent'
        'welcome.title'          = 'Welcome to RBR Install Assistant'
        'welcome.msg'            = "First time? Three steps to finish:`n`n① Install qBittorrent (if the status bar shows missing, click the Download button)`n② Click [Auto Download] on this tab and wait for the game to install`n③ After the game installs, go to [MOD Manager] to add mods and localization`n`nThis message won't appear again."
        'welcome.btn'            = 'Got it, let''s go'
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
        'tab.install'            = 'Install Game'
        'tab.mod'                = 'MOD Manager'
        'mod.warn'               = '[!]  Complete game installation (Install Game tab) before using MOD Manager'
        'mod.lbl.root'           = 'Game root folder:'
        'mod.jsgme.status.none'  = 'JSGME status: not deployed to game folder'
        'mod.jsgme.status.ok'    = 'JSGME status: ready (can open now)'
        'mod.step1.title'        = 'Step 1: Get MOD pack'
        'mod.step1.note'         = 'Have the files? Import locally. Need to download? Try GitHub first; use Baidu if GitHub is inaccessible.'
        'mod.btn.importfolder'   = 'Import folder'
        'mod.btn.importzip'      = 'Import ZIP'
        'mod.btn.githubdl'       = 'Download Online'
        'mod.btn.baidudl'        = 'Baidu Netdisk'
        'mod.import.status'      = 'Import: waiting'
        'mod.import.doing'       = 'Import: copying, please wait...'
        'mod.import.done'        = 'Import: done'
        'mod.import.err'         = 'Import: failed — {0}'
        'mod.dlg.folder'         = 'Select MOD pack folder'
        'mod.dlg.zip'            = 'Select MOD archive (.zip)'
        'mod.dlg.zip.filter'     = 'ZIP archive (*.zip)|*.zip|All files (*.*)|*.*'
        'mod.err.nobaiduurl'     = 'MOD pack download link not configured. Please contact the publisher.'
        'mod.step2.title'        = 'Step 2: Deploy JSGME tool to game folder'
        'mod.btn.install'        = 'Deploy MOD Manager'
        'mod.install.status'     = 'Status: ready'
        'mod.install.doing'      = 'Status: copying files...'
        'mod.install.done'       = 'Status: deployed to game folder successfully'
        'mod.install.err'        = 'Status: copy failed — {0}'
        'mod.step3.title'        = 'Step 3: Check and enable MODs in JSGME'
        'mod.btn.open'           = 'Open MOD Manager (JSGME)'
        'mod.err.noroot'         = 'Please enter or confirm the game root folder path.'
        'mod.err.nojsgame'       = "JSGME tool files not found. Make sure JSGAME folder exists.`nExpected: {0}"
        'mod.err.noexe'          = 'JSGME not found in game folder. Please complete Step 2 first.'
        'mod.err.launch'         = 'Failed to launch JSGME: {0}'
        'mod.err.nodlurl'        = 'MOD pack download link not configured. Please contact the publisher for the download URL.'
        'mod.import.extracting'  = 'Extracting... {0}% ({1}/{2})'
        'mod.dl.starting'        = 'Connecting to GitHub, please wait...'
        'mod.dl.progress'        = 'Downloading... {0} MB'
        'mod.dl.progress.pct'    = 'Downloading... {0} MB / {1} MB ({2}%)'
        'mod.dl.extracting'      = 'Download complete, extracting...'
        'mod.dl.done'            = '✓ MOD pack downloaded and imported'
        'mod.dl.fail'            = 'Download failed. Check network or use Baidu Netdisk and import locally.'
        'mod.install.warn.nomods'= '⚠ JSGME deployed, but MODS folder is empty — complete Step 1 first'
        'i18n.step.title'        = '★ Chinese Localization (RBRi18n): one-click install after game setup'
        'i18n.btn.install'       = 'Install Bundled Localization'
        'i18n.btn.update'        = 'Update Online ↗'
        'i18n.status.fetching'   = 'Checking for latest version...'
        'i18n.status.dl'         = 'Downloading {0}...'
        'i18n.status.extract'    = 'Extracting to game folder...'
        'i18n.status.done'       = '✓ Localization installed ({0})'
        'i18n.status.bundled'    = 'Bundled: {0}'
        'i18n.err.noroot'        = 'Please set the game download folder first (row 3)'
        'i18n.err.noasset'       = 'No zip asset found in latest release — check your network'
        'i18n.err.nolocal'       = 'Bundled pack not found. Use the GitHub button to download.'
        'i18n.err.fail'          = 'Failed: {0}'
        'notify.moddl.done.title'= 'MOD Pack Ready'
        'notify.moddl.done.body' = 'MOD pack imported and manager deployed. Go to MOD Manager tab to enable mods.'
        'notify.qb.found.title'  = 'qBittorrent Ready'
        'notify.qb.found.body'   = 'qBittorrent installed! You can now click [Auto Download] to continue.'
        'mod.auto.deploy'        = 'Auto-deploying JSGME...'
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

# Scan common locations for an existing RBR installation.
# Use .NET IO methods instead of Test-Path to avoid PowerShell provider
# errors (null-path exceptions) on optical/network/removable drives.
function Find-ExistingRbrPath {
    $drives = @('C','D','E','F','G','H')
    $subs   = @('RSF\RBR', 'Games\RBR', 'RBR', 'Program Files\RBR', 'game\RBR')
    foreach ($drv in $drives) {
        foreach ($sub in $subs) {
            try {
                $p = [System.IO.Path]::Combine("${drv}:\", $sub)
                if ([System.IO.File]::Exists([System.IO.Path]::Combine($p, 'RichardBurnsRally_SSE.exe')) -or
                    [System.IO.Directory]::Exists([System.IO.Path]::Combine($p, 'Plugins'))) {
                    return $p
                }
            } catch {}
        }
    }
    return $null
}

function Test-QBittorrentInstalled {
    # Check common install locations
    $exePaths = @(
        "$env:ProgramFiles\qBittorrent\qbittorrent.exe",
        "${env:ProgramFiles(x86)}\qBittorrent\qbittorrent.exe",
        "$env:LOCALAPPDATA\Programs\qBittorrent\qbittorrent.exe"
    )
    foreach ($ep in $exePaths) {
        if (Test-Path $ep) { return $true }
    }
    # Check add/remove programs registry
    $regBases = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($base in $regBases) {
        try {
            $hit = Get-ChildItem $base -ErrorAction SilentlyContinue |
                Get-ItemProperty -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -match 'qBittorrent' } |
                Select-Object -First 1
            if ($hit) { return $true }
        } catch {}
    }
    return $false
}

$script:RbrStatePath = Join-Path $logDir 'rbr_state.json'

function Save-RbrState {
    param([hashtable]$Updates)
    try {
        $state = @{}
        if (Test-Path $script:RbrStatePath) {
            $existing = Get-Content $script:RbrStatePath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($existing) { $existing.PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value } }
        }
        foreach ($k in $Updates.Keys) { $state[$k] = $Updates[$k] }
        $state | ConvertTo-Json | Set-Content $script:RbrStatePath -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Load-RbrState {
    try {
        if (Test-Path $script:RbrStatePath) {
            return (Get-Content $script:RbrStatePath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json)
        }
    } catch {}
    return $null
}

function Show-BalloonTip {
    param([string]$Title, [string]$Text, [int]$Timeout = 6000)
    try {
        $script:NotifyIcon.BalloonTipTitle = $Title
        $script:NotifyIcon.BalloonTipText  = $Text
        $script:NotifyIcon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info
        $script:NotifyIcon.ShowBalloonTip($Timeout)
    } catch {}
}

# Deploy JSGME tool into game folder silently (called automatically after MOD import).
function Invoke-ModDeploy {
    param([string]$GameRoot)
    $jsgmeSrc = Join-Path $jsGameDir $jsgmeExeName
    if (-not (Test-Path $jsgmeSrc)) { return }
    try {
        if (-not (Test-Path $GameRoot)) {
            New-Item -Path $GameRoot -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path "$jsGameDir\*" -Destination $GameRoot -Recurse -Force
        $jsgmeDest = Join-Path $GameRoot $jsgmeExeName
        if (Test-Path $jsgmeDest) {
            Update-ModStatus -GameRoot $GameRoot
            Save-RbrState -Updates @{ gameRoot = $GameRoot }
        }
    } catch {}
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
$form.Text = "$(T 'form.title')  $script:AppVersion"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(780, 560)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$icon = Get-AppIcon
if ($icon) { $form.Icon = $icon }

# System-tray icon for balloon notifications — created once, disposed on close
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = (T 'form.title')
$appIconForNotify = Get-AppIcon
$script:NotifyIcon.Icon = if ($appIconForNotify) { $appIconForNotify } else { [System.Drawing.SystemIcons]::Application }
$script:NotifyIcon.Visible = $true

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = [System.Windows.Forms.DockStyle]::Fill

$tabPage1 = New-Object System.Windows.Forms.TabPage
$tabPage1.Text = (T 'tab.install')
$tabPage1.UseVisualStyleBackColor = $true

$tabPage2 = New-Object System.Windows.Forms.TabPage
$tabPage2.Text = (T 'tab.mod')
$tabPage2.UseVisualStyleBackColor = $true

[void]$tabControl.TabPages.Add($tabPage1)
[void]$tabControl.TabPages.Add($tabPage2)

$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text      = '语言/Language:'
$lblLang.Location  = New-Object System.Drawing.Point(530, 11)
$lblLang.Size      = New-Object System.Drawing.Size(88, 20)
$lblLang.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$tabPage1.Controls.Add($lblLang)

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Location = New-Object System.Drawing.Point(622, 8)
$cmbLang.Size = New-Object System.Drawing.Size(70, 24)
$cmbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$cmbLang.Items.Add('中文')
[void]$cmbLang.Items.Add('EN')
$cmbLang.SelectedIndex = 0
$tabPage1.Controls.Add($cmbLang)

if (Test-Path $logoPng) {
    try {
        $picLogo = New-Object System.Windows.Forms.PictureBox
        $picLogo.Location = New-Object System.Drawing.Point(716, 8)
        $picLogo.Size = New-Object System.Drawing.Size(28, 28)
        $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picLogo.Image = [System.Drawing.Image]::FromFile($logoPng)
        $tabPage1.Controls.Add($picLogo)
    } catch {}
}

$lblTips = New-Object System.Windows.Forms.Label
$lblTips.Text = (T 'tips')
$lblTips.Location = New-Object System.Drawing.Point(20, 18)
$lblTips.Size = New-Object System.Drawing.Size(730, 24)
$tabPage1.Controls.Add($lblTips)

$lblTorrent = New-Object System.Windows.Forms.Label
$lblTorrent.Text = (T 'lbl.torrent')
$lblTorrent.Location = New-Object System.Drawing.Point(20, 60)
$lblTorrent.Size = New-Object System.Drawing.Size(120, 24)
$tabPage1.Controls.Add($lblTorrent)

$txtTorrent = New-Object System.Windows.Forms.TextBox
$txtTorrent.Location = New-Object System.Drawing.Point(140, 58)
$txtTorrent.Size = New-Object System.Drawing.Size(520, 24)
$tabPage1.Controls.Add($txtTorrent)

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
$tabPage1.Controls.Add($btnTorrent)

$lblInstaller = New-Object System.Windows.Forms.Label
$lblInstaller.Text = (T 'lbl.installer')
$lblInstaller.Location = New-Object System.Drawing.Point(20, 106)
$lblInstaller.Size = New-Object System.Drawing.Size(120, 24)
$tabPage1.Controls.Add($lblInstaller)

$txtInstaller = New-Object System.Windows.Forms.TextBox
$txtInstaller.Location = New-Object System.Drawing.Point(140, 104)
$txtInstaller.Size = New-Object System.Drawing.Size(520, 24)
$tabPage1.Controls.Add($txtInstaller)

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
$tabPage1.Controls.Add($btnInstaller)

$lblDownload = New-Object System.Windows.Forms.Label
$lblDownload.Text = (T 'lbl.drive')
$lblDownload.Location = New-Object System.Drawing.Point(20, 152)
$lblDownload.Size = New-Object System.Drawing.Size(120, 24)
$tabPage1.Controls.Add($lblDownload)

$cmbDrive = New-Object System.Windows.Forms.ComboBox
$cmbDrive.Location = New-Object System.Drawing.Point(140, 150)
$cmbDrive.Size = New-Object System.Drawing.Size(95, 24)
$cmbDrive.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$tabPage1.Controls.Add($cmbDrive)

$lblDownloadPath = New-Object System.Windows.Forms.Label
$lblDownloadPath.Text = (T 'lbl.path')
$lblDownloadPath.Location = New-Object System.Drawing.Point(245, 152)
$lblDownloadPath.Size = New-Object System.Drawing.Size(70, 24)
$tabPage1.Controls.Add($lblDownloadPath)

$txtDownload = New-Object System.Windows.Forms.TextBox
$txtDownload.Location = New-Object System.Drawing.Point(315, 150)
$txtDownload.Size = New-Object System.Drawing.Size(345, 24)
$tabPage1.Controls.Add($txtDownload)

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
$tabPage1.Controls.Add($btnDownload)

$lblDriveHint = New-Object System.Windows.Forms.Label
$lblDriveHint.Text = (T 'drive.none')
$lblDriveHint.Location = New-Object System.Drawing.Point(140, 176)
$lblDriveHint.Size = New-Object System.Drawing.Size(610, 18)
$lblDriveHint.ForeColor = [System.Drawing.Color]::DarkBlue
$tabPage1.Controls.Add($lblDriveHint)

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
$tabPage1.Controls.Add($lblNote)

$lblNote2 = New-Object System.Windows.Forms.Label
$lblNote2.Text = (T 'lbl.note2')
$lblNote2.Location = New-Object System.Drawing.Point(20, 222)
$lblNote2.Size = New-Object System.Drawing.Size(730, 24)
$tabPage1.Controls.Add($lblNote2)

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
$tabPage1.Controls.Add($btnOfficial)

$btnAutoDownload = New-Object System.Windows.Forms.Button
$btnAutoDownload.Text = (T 'btn.auto')
$btnAutoDownload.Location = New-Object System.Drawing.Point(150, 270)
$btnAutoDownload.Size = New-Object System.Drawing.Size(250, 34)
$btnAutoDownload.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage1.Controls.Add($btnAutoDownload)

$lblRecommend = New-Object System.Windows.Forms.Label
$lblRecommend.Text = (T 'lbl.recommend')
$lblRecommend.Location = New-Object System.Drawing.Point(150, 246)
$lblRecommend.Size = New-Object System.Drawing.Size(350, 22)
$lblRecommend.ForeColor = [System.Drawing.Color]::DarkRed
$lblRecommend.Font = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage1.Controls.Add($lblRecommend)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = (T 'status.idle')
$lblStatus.Location = New-Object System.Drawing.Point(20, 312)
$lblStatus.Size = New-Object System.Drawing.Size(730, 24)
$tabPage1.Controls.Add($lblStatus)

# Marquee progress bar shown while auto-download is running
$pbAutoDownload = New-Object System.Windows.Forms.ProgressBar
$pbAutoDownload.Location = New-Object System.Drawing.Point(20, 340)
$pbAutoDownload.Size     = New-Object System.Drawing.Size(730, 14)
$pbAutoDownload.Style    = [System.Windows.Forms.ProgressBarStyle]::Marquee
$pbAutoDownload.MarqueeAnimationSpeed = 35
$pbAutoDownload.Visible  = $false
$tabPage1.Controls.Add($pbAutoDownload)

# qBittorrent status row (y=360, clear of the progress bar)
$lblQbStatus = New-Object System.Windows.Forms.Label
$lblQbStatus.Location = New-Object System.Drawing.Point(20, 360)
$lblQbStatus.Size     = New-Object System.Drawing.Size(560, 22)
$tabPage1.Controls.Add($lblQbStatus)

$script:QbtPollTimer = $null

$btnQbDl = New-Object System.Windows.Forms.Button
$btnQbDl.Text     = (T 'qb.btn.dl')
$btnQbDl.Location = New-Object System.Drawing.Point(590, 357)
$btnQbDl.Size     = New-Object System.Drawing.Size(150, 26)
$btnQbDl.Add_Click({
    try { Start-Process $qbtLatestDownloadUrl | Out-Null } catch {}
    # Poll every 8 s — update status automatically once qB is installed
    if ($script:QbtPollTimer) { try { $script:QbtPollTimer.Stop() } catch {} }
    $script:QbtPollTimer = New-Object System.Windows.Forms.Timer
    $script:QbtPollTimer.Interval = 8000
    $script:QbtPollTimer.Add_Tick({
        if (Test-QBittorrentInstalled) {
            $script:QbtPollTimer.Stop()
            $script:QbtInstalled   = $true
            $lblQbStatus.Text      = (T 'qb.status.ok')
            $lblQbStatus.ForeColor = [System.Drawing.Color]::DarkGreen
            $btnQbDl.Visible       = $false
            Show-BalloonTip -Title (T 'notify.qb.found.title') -Text (T 'notify.qb.found.body')
        }
    })
    $script:QbtPollTimer.Start()
})
$tabPage1.Controls.Add($btnQbDl)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = (T 'btn.start')
$btnStart.Location = New-Object System.Drawing.Point(510, 270)
$btnStart.Size = New-Object System.Drawing.Size(115, 34)
$tabPage1.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = (T 'btn.cancel')
$btnCancel.Location = New-Object System.Drawing.Point(635, 270)
$btnCancel.Size = New-Object System.Drawing.Size(115, 34)
$btnCancel.Add_Click({ $form.Close() })
$tabPage1.Controls.Add($btnCancel)

# ─── Tab 1: i18n section ─────────────────────────────────────────────────────

# 共享解压逻辑
function Expand-I18nZip {
    param([string]$ZipPath, [string]$GameRoot)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '[/\\]$') { continue }
        $destPath = Join-Path $GameRoot $entry.FullName
        $destDir  = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
    }
    $zip.Dispose()
}

# Expand a MOD ZIP into DestPath with per-entry DoEvents for UI responsiveness.
# StatusLabel: optional Label control to display progress text.
function Expand-ModZip {
    param(
        [string]$ZipPath,
        [string]$DestPath,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip   = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $total = $zip.Entries.Count
    $i     = 0
    foreach ($entry in $zip.Entries) {
        $i++
        # Skip directory entries and Windows system files that are often locked
        if ($entry.FullName -match '[/\\]$') { continue }
        if ($entry.Name -match '^(desktop\.ini|thumbs\.db|\.DS_Store)$') { continue }
        $destFile = Join-Path $DestPath $entry.FullName
        $destDir  = Split-Path $destFile -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        try {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destFile, $true)
        } catch {
            # Skip files we can't write (locked system files, etc.) and continue
        }
        if (($StatusLabel -or $ProgressBar) -and ($i % 20 -eq 0 -or $i -eq $total)) {
            $pct = [int]($i * 100 / [Math]::Max($total, 1))
            if ($StatusLabel) { $StatusLabel.Text = (T 'mod.import.extracting' @($pct, $i, $total)) }
            if ($ProgressBar)  { $ProgressBar.Value = [math]::Min(100, $pct) }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    $zip.Dispose()
}

$sepI18n = New-Object System.Windows.Forms.Label
$sepI18n.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$sepI18n.Location    = New-Object System.Drawing.Point(12, 392)
$sepI18n.Size        = New-Object System.Drawing.Size(740, 2)
$tabPage1.Controls.Add($sepI18n)

$lblI18nTitle = New-Object System.Windows.Forms.Label
$lblI18nTitle.Text     = (T 'i18n.step.title')
$lblI18nTitle.Location = New-Object System.Drawing.Point(20, 402)
$lblI18nTitle.Size     = New-Object System.Drawing.Size(740, 20)
$lblI18nTitle.Font     = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage1.Controls.Add($lblI18nTitle)

$btnI18n = New-Object System.Windows.Forms.Button
$btnI18n.Text     = (T 'i18n.btn.install')
$btnI18n.Location = New-Object System.Drawing.Point(20, 426)
$btnI18n.Size     = New-Object System.Drawing.Size(163, 34)
$tabPage1.Controls.Add($btnI18n)

$btnI18nUpdate = New-Object System.Windows.Forms.Button
$btnI18nUpdate.Text     = (T 'i18n.btn.update')
$btnI18nUpdate.Location = New-Object System.Drawing.Point(191, 426)
$btnI18nUpdate.Size     = New-Object System.Drawing.Size(130, 34)
$tabPage1.Controls.Add($btnI18nUpdate)

$lblI18nStatus = New-Object System.Windows.Forms.Label
$lblI18nStatus.Location = New-Object System.Drawing.Point(330, 433)
$lblI18nStatus.Size     = New-Object System.Drawing.Size(420, 20)
$tabPage1.Controls.Add($lblI18nStatus)

# 启动时显示内置版本名称
$script:I18nLocalZip = Get-ChildItem -Path $projectRoot -Filter 'RBRi18n*.zip' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if ($script:I18nLocalZip) {
    $lblI18nStatus.Text      = (T 'i18n.status.bundled' $script:I18nLocalZip.Name)
    $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkBlue
} else {
    $lblI18nStatus.Text      = (T 'i18n.err.nolocal')
    $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkOrange
}

# 安装内置版本
$btnI18n.Add_Click({
    $gameRoot = $txtDownload.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'i18n.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }
    $localZip = Get-ChildItem -Path $projectRoot -Filter 'RBRi18n*.zip' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $localZip) {
        $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkOrange
        $lblI18nStatus.Text      = (T 'i18n.err.nolocal')
        return
    }
    $btnI18n.Enabled         = $false
    $lblI18nStatus.ForeColor = $form.ForeColor
    $lblI18nStatus.Text      = (T 'i18n.status.extract')
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Expand-I18nZip -ZipPath $localZip.FullName -GameRoot $gameRoot
        $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        $lblI18nStatus.Text      = (T 'i18n.status.done' $localZip.Name)
    } catch {
        $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkRed
        $lblI18nStatus.Text      = (T 'i18n.err.fail' "$_")
    } finally {
        $btnI18n.Enabled = $true
    }
})

# 在线更新汉化包：优先 Gitee（国内），失败再试 GitHub API
$btnI18nUpdate.Add_Click({
    $gameRoot = $txtDownload.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'i18n.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }
    $btnI18nUpdate.Enabled   = $false
    $lblI18nStatus.ForeColor = $form.ForeColor
    $lblI18nStatus.Text      = (T 'i18n.status.fetching')
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $tmpZip   = Join-Path $env:TEMP 'RBRi18n_tmp.zip'
        $fileName = ''

        # Try Gitee direct link first (no VPN needed for Chinese users)
        $usedGitee = $false
        if (-not [string]::IsNullOrWhiteSpace($script:I18nGiteeUrl)) {
            try {
                $fileName = [System.IO.Path]::GetFileName(([uri]$script:I18nGiteeUrl).AbsolutePath)
                $lblI18nStatus.Text = (T 'i18n.status.dl' $fileName)
                [System.Windows.Forms.Application]::DoEvents()
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
                $wc.DownloadFile($script:I18nGiteeUrl, $tmpZip)
                $usedGitee = $true
            } catch {
                $usedGitee = $false
                try { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue } catch {}
            }
        }

        # Fallback: GitHub API (for users with VPN or outside China)
        if (-not $usedGitee) {
            $lblI18nStatus.Text = (T 'i18n.status.fetching')
            [System.Windows.Forms.Application]::DoEvents()
            $apiUrl  = 'https://api.github.com/repos/geekerlw/RBRi18n/releases/latest'
            $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
            $asset   = @($release.assets) | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
            if (-not $asset) { throw (T 'i18n.err.noasset') }
            $fileName = $asset.name
            $lblI18nStatus.Text = (T 'i18n.status.dl' $fileName)
            [System.Windows.Forms.Application]::DoEvents()
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
        }

        $lblI18nStatus.Text = (T 'i18n.status.extract')
        [System.Windows.Forms.Application]::DoEvents()
        Expand-I18nZip -ZipPath $tmpZip -GameRoot $gameRoot
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue

        $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        $lblI18nStatus.Text      = (T 'i18n.status.done' $fileName)
    } catch {
        $lblI18nStatus.ForeColor = [System.Drawing.Color]::DarkRed
        $lblI18nStatus.Text      = (T 'i18n.err.fail' "$_")
    } finally {
        $btnI18nUpdate.Enabled = $true
    }
})

# ─── Tab 2: MOD Manager ──────────────────────────────────────────────────────

function Update-ModStatus {
    param([string]$GameRoot)
    if (-not [string]::IsNullOrWhiteSpace($GameRoot) -and
        (Test-Path (Join-Path $GameRoot $jsgmeExeName))) {
        $lblModJsgmeStatus.Text     = (T 'mod.jsgme.status.ok')
        $lblModJsgmeStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        $btnModOpen.Enabled          = $true
    } else {
        $lblModJsgmeStatus.Text     = (T 'mod.jsgme.status.none')
        $lblModJsgmeStatus.ForeColor = [System.Drawing.Color]::DarkOrange
        $btnModOpen.Enabled          = $false
    }
}

$lblModWarn = New-Object System.Windows.Forms.Label
$lblModWarn.Text      = (T 'mod.warn')
$lblModWarn.Location  = New-Object System.Drawing.Point(12, 12)
$lblModWarn.Size      = New-Object System.Drawing.Size(740, 20)
$lblModWarn.ForeColor = [System.Drawing.Color]::DarkOrange
$tabPage2.Controls.Add($lblModWarn)

$lblModRoot = New-Object System.Windows.Forms.Label
$lblModRoot.Text     = (T 'mod.lbl.root')
$lblModRoot.Location = New-Object System.Drawing.Point(12, 44)
$lblModRoot.Size     = New-Object System.Drawing.Size(115, 24)
$tabPage2.Controls.Add($lblModRoot)

$txtModRoot = New-Object System.Windows.Forms.TextBox
$txtModRoot.Location = New-Object System.Drawing.Point(130, 42)
$txtModRoot.Size     = New-Object System.Drawing.Size(500, 24)
$tabPage2.Controls.Add($txtModRoot)

$btnModBrowse = New-Object System.Windows.Forms.Button
$btnModBrowse.Text     = (T 'btn.browse')
$btnModBrowse.Location = New-Object System.Drawing.Point(638, 40)
$btnModBrowse.Size     = New-Object System.Drawing.Size(90, 28)
$btnModBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = (T 'mod.lbl.root')
    if (-not [string]::IsNullOrWhiteSpace($txtModRoot.Text)) {
        $dlg.SelectedPath = $txtModRoot.Text.Trim()
    }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtModRoot.Text = $dlg.SelectedPath
    }
})
$tabPage2.Controls.Add($btnModBrowse)

$lblModJsgmeStatus = New-Object System.Windows.Forms.Label
$lblModJsgmeStatus.Text      = (T 'mod.jsgme.status.none')
$lblModJsgmeStatus.Location  = New-Object System.Drawing.Point(12, 74)
$lblModJsgmeStatus.Size      = New-Object System.Drawing.Size(720, 20)
$lblModJsgmeStatus.ForeColor = [System.Drawing.Color]::DarkOrange
$tabPage2.Controls.Add($lblModJsgmeStatus)

$txtModRoot.Add_TextChanged({
    Update-ModStatus -GameRoot $txtModRoot.Text.Trim()
})

$sep1 = New-Object System.Windows.Forms.Label
$sep1.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$sep1.Location    = New-Object System.Drawing.Point(12, 102)
$sep1.Size        = New-Object System.Drawing.Size(740, 2)
$tabPage2.Controls.Add($sep1)

$lblModStep1 = New-Object System.Windows.Forms.Label
$lblModStep1.Text     = (T 'mod.step1.title')
$lblModStep1.Location = New-Object System.Drawing.Point(12, 112)
$lblModStep1.Size     = New-Object System.Drawing.Size(740, 20)
$lblModStep1.Font     = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage2.Controls.Add($lblModStep1)

$lblModStep1Note = New-Object System.Windows.Forms.Label
$lblModStep1Note.Text     = (T 'mod.step1.note')
$lblModStep1Note.Location = New-Object System.Drawing.Point(28, 135)
$lblModStep1Note.Size     = New-Object System.Drawing.Size(710, 18)
$tabPage2.Controls.Add($lblModStep1Note)

$btnModImportFolder = New-Object System.Windows.Forms.Button
$btnModImportFolder.Text     = (T 'mod.btn.importfolder')
$btnModImportFolder.Location = New-Object System.Drawing.Point(28, 156)
$btnModImportFolder.Size     = New-Object System.Drawing.Size(138, 30)
$btnModImportFolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = (T 'mod.dlg.folder')
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $gameRoot = $txtModRoot.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show((T 'mod.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }
    $lblModImportStatus.Text = (T 'mod.import.doing')
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $destFolder = Join-Path $gameRoot (Split-Path $dlg.SelectedPath -Leaf)
        Copy-Item -Path $dlg.SelectedPath -Destination $destFolder -Recurse -Force
        $lblModImportStatus.Text = (T 'mod.import.done')
    } catch {
        $lblModImportStatus.Text = (T 'mod.import.err' "$_")
    }
})
$tabPage2.Controls.Add($btnModImportFolder)

$btnModImportZip = New-Object System.Windows.Forms.Button
$btnModImportZip.Text     = (T 'mod.btn.importzip')
$btnModImportZip.Location = New-Object System.Drawing.Point(174, 156)
$btnModImportZip.Size     = New-Object System.Drawing.Size(116, 30)
$btnModImportZip.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title           = (T 'mod.dlg.zip')
    $dlg.Filter          = (T 'mod.dlg.zip.filter')
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $gameRoot = $txtModRoot.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show((T 'mod.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }
    $btnModImportZip.Enabled    = $false
    $btnModImportFolder.Enabled = $false
    $btnModGithubDl.Enabled     = $false
    $pbModDl.Value   = 0
    $pbModDl.Style   = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $pbModDl.Visible = $true
    $lblModImportStatus.Text = (T 'mod.import.doing')
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Expand-ModZip -ZipPath $dlg.FileName -DestPath $gameRoot -StatusLabel $lblModImportStatus -ProgressBar $pbModDl
        # Validate that something was actually extracted
        $modsFolder = Join-Path $gameRoot 'MODS'
        $hasContent = (Test-Path $modsFolder) -and (Get-ChildItem -Path $modsFolder -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hasContent -or (Get-ChildItem -Path $gameRoot -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            $pbModDl.Visible         = $false
            $lblModImportStatus.Text = (T 'mod.import.done')
            # Auto-deploy JSGME so user doesn't need to click Step 2
            $lblModInstallStatus.Text = (T 'mod.auto.deploy')
            [System.Windows.Forms.Application]::DoEvents()
            Invoke-ModDeploy -GameRoot $gameRoot
            $hasModsContent = (Test-Path $modsFolder) -and ($null -ne (Get-ChildItem -Path $modsFolder -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1))
            $lblModInstallStatus.Text = if ($hasModsContent) { (T 'mod.install.done') } else { (T 'mod.install.warn.nomods') }
            Show-BalloonTip -Title (T 'notify.moddl.done.title') -Text (T 'notify.moddl.done.body')
        } else {
            $pbModDl.Visible         = $false
            $lblModImportStatus.Text = (T 'mod.import.err' '解压后目录为空，请确认 ZIP 文件内容')
        }
    } catch {
        $pbModDl.Visible         = $false
        $lblModImportStatus.Text = (T 'mod.import.err' "$_")
    } finally {
        $btnModImportZip.Enabled    = $true
        $btnModImportFolder.Enabled = $true
        $btnModGithubDl.Enabled     = $true
    }
})
$tabPage2.Controls.Add($btnModImportZip)

$btnModGithubDl = New-Object System.Windows.Forms.Button
$btnModGithubDl.Text     = (T 'mod.btn.githubdl')
$btnModGithubDl.Location = New-Object System.Drawing.Point(298, 156)
$btnModGithubDl.Size     = New-Object System.Drawing.Size(116, 30)
$script:ModsDlJob      = $null
$script:ModsDlTmpPath  = $null
$script:ModsDlTimer    = $null
$script:ModsDlTotalMB  = 0

$btnModGithubDl.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:ModsGithubUrl)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.nodlurl'), (T 'err.title'), 'OK', 'Information') | Out-Null
        return
    }
    $gameRoot = $txtModRoot.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }

    $tmpZip = Join-Path $env:TEMP 'RBR_MODS_download.zip'
    $script:ModsDlTmpPath = $tmpZip

    # Disable all Step-1 buttons while downloading
    $btnModGithubDl.Enabled     = $false
    $btnModBaiduDl.Enabled      = $false
    $btnModImportZip.Enabled    = $false
    $btnModImportFolder.Enabled = $false
    $lblModImportStatus.Text    = (T 'mod.dl.starting')
    [System.Windows.Forms.Application]::DoEvents()

    # Remove stale temp file
    try { if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue } } catch {}

    # Auto-select download source: try Gitee first (no VPN), fall back to GitHub
    $dlUrl = $script:ModsGithubUrl
    $script:ModsDlTotalMB = 0
    if (-not [string]::IsNullOrWhiteSpace($script:ModsGiteeUrl)) {
        try {
            $chk = [System.Net.HttpWebRequest]::Create([uri]$script:ModsGiteeUrl)
            $chk.Method = 'HEAD'; $chk.Timeout = 3000; $chk.UserAgent = 'Mozilla/5.0'
            $chkResp = $chk.GetResponse()
            $cl2 = $chkResp.ContentLength
            $chkResp.Close()
            $dlUrl = $script:ModsGiteeUrl
            if ($cl2 -gt 0) { $script:ModsDlTotalMB = [math]::Round($cl2 / 1MB, 1) }
        } catch {
            # Gitee unreachable — use GitHub; get file size from GitHub HEAD
            try {
                $req = [System.Net.HttpWebRequest]::Create([uri]$dlUrl)
                $req.Method = 'HEAD'; $req.Timeout = 5000; $req.UserAgent = 'Mozilla/5.0'
                $resp = $req.GetResponse()
                $cl   = $resp.ContentLength
                $resp.Close()
                if ($cl -gt 0) { $script:ModsDlTotalMB = [math]::Round($cl / 1MB, 1) }
            } catch {}
        }
    } else {
        # No Gitee URL configured — GitHub HEAD for file size
        try {
            $req = [System.Net.HttpWebRequest]::Create([uri]$dlUrl)
            $req.Method = 'HEAD'; $req.Timeout = 5000; $req.UserAgent = 'Mozilla/5.0'
            $resp = $req.GetResponse()
            $cl   = $resp.ContentLength
            $resp.Close()
            if ($cl -gt 0) { $script:ModsDlTotalMB = [math]::Round($cl / 1MB, 1) }
        } catch {}
    }

    # Background download job (separate PS process — no UI access needed)
    $script:ModsDlJob = Start-Job -ScriptBlock {
        param($url, $dest)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
        $wc.DownloadFile($url, $dest)
    } -ArgumentList $dlUrl, $tmpZip

    $pbModDl.Value   = 0
    $pbModDl.Style   = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $pbModDl.Visible = $true

    # WinForms Timer polls on UI thread — safe to update controls directly
    $script:ModsDlTimer = New-Object System.Windows.Forms.Timer
    $script:ModsDlTimer.Interval = 800
    $script:ModsDlTimer.Add_Tick({
        $job = $script:ModsDlJob
        if ($null -eq $job) { $script:ModsDlTimer.Stop(); return }

        # Show downloaded size while running
        if ($job.State -in 'Running','NotStarted') {
            $tp = $script:ModsDlTmpPath
            if ($tp -and (Test-Path $tp)) {
                try {
                    $mb  = [math]::Round((Get-Item $tp -ErrorAction Stop).Length / 1MB, 1)
                    $tot = $script:ModsDlTotalMB
                    if ($tot -gt 0) {
                        $pct = [math]::Min(99, [int]($mb * 100 / $tot))
                        $lblModImportStatus.Text = (T 'mod.dl.progress.pct' @($mb, $tot, $pct))
                        $pbModDl.Value = $pct
                    } else {
                        $lblModImportStatus.Text = (T 'mod.dl.progress' "$mb")
                    }
                } catch {}
            }
            return
        }

        # Job finished (Completed / Failed / Stopped)
        $script:ModsDlTimer.Stop()
        Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job  $job -Force -ErrorAction SilentlyContinue
        $script:ModsDlJob = $null

        # Re-enable buttons
        $btnModGithubDl.Enabled     = $true
        $btnModBaiduDl.Enabled      = $true
        $btnModImportZip.Enabled    = $true
        $btnModImportFolder.Enabled = $true

        $tp2 = $script:ModsDlTmpPath
        $fileOk = $tp2 -and (Test-Path $tp2) -and ((Get-Item $tp2 -ErrorAction SilentlyContinue).Length -gt 10240)
        if (-not $fileOk) {
            $pbModDl.Visible         = $false
            $lblModImportStatus.Text = (T 'mod.dl.fail')
            return
        }

        # SHA256 verification (if a hash is configured)
        $expectedHash = $script:ModsGithubSha256
        if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
            $lblModImportStatus.Text = '正在校验文件完整性...'
            [System.Windows.Forms.Application]::DoEvents()
            try {
                $actualHash = (Get-FileHash -Path $tp2 -Algorithm SHA256).Hash.ToLower()
                if ($actualHash -ne $expectedHash.ToLower()) {
                    try { Remove-Item $tp2 -Force -ErrorAction SilentlyContinue } catch {}
                    $pbModDl.Visible         = $false
                    $lblModImportStatus.Text = "校验失败：文件已损坏，请重试（SHA256 不匹配）"
                    $btnModGithubDl.Enabled  = $true
                    return
                }
            } catch {
                # Hash check failed to run — non-fatal, proceed anyway
            }
        }

        # Extract on UI thread with per-entry DoEvents
        $gr = $txtModRoot.Text.Trim()
        $pbModDl.Value           = 0
        $lblModImportStatus.Text = (T 'mod.dl.extracting')
        [System.Windows.Forms.Application]::DoEvents()
        try {
            Expand-ModZip -ZipPath $tp2 -DestPath $gr -StatusLabel $lblModImportStatus -ProgressBar $pbModDl
            $pbModDl.Visible         = $false
            $lblModImportStatus.Text = (T 'mod.dl.done')
            # Auto-deploy JSGME so user doesn't need to click Step 2
            $lblModInstallStatus.Text = (T 'mod.auto.deploy')
            [System.Windows.Forms.Application]::DoEvents()
            Invoke-ModDeploy -GameRoot $gr
            $modsFolder = Join-Path $gr 'MODS'
            $hasContent = (Test-Path $modsFolder) -and ($null -ne (Get-ChildItem -Path $modsFolder -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1))
            $lblModInstallStatus.Text = if ($hasContent) { (T 'mod.install.done') } else { (T 'mod.install.warn.nomods') }
            Show-BalloonTip -Title (T 'notify.moddl.done.title') -Text (T 'notify.moddl.done.body')
        } catch {
            $pbModDl.Visible         = $false
            $lblModImportStatus.Text = (T 'mod.import.err' "$_")
        }
        try { Remove-Item $tp2 -Force -ErrorAction SilentlyContinue } catch {}
    })
    $script:ModsDlTimer.Start()
})
$tabPage2.Controls.Add($btnModGithubDl)

$btnModBaiduDl = New-Object System.Windows.Forms.Button
$btnModBaiduDl.Text     = (T 'mod.btn.baidudl')
$btnModBaiduDl.Location = New-Object System.Drawing.Point(422, 156)
$btnModBaiduDl.Size     = New-Object System.Drawing.Size(116, 30)
$btnModBaiduDl.Add_Click({
    if ([string]::IsNullOrWhiteSpace($script:ModsBaiduUrl)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.nobaiduurl'), (T 'err.title'), 'OK', 'Information') | Out-Null
        return
    }
    try {
        Start-Process $script:ModsBaiduUrl | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("$_", (T 'err.title'), 'OK', 'Warning') | Out-Null
    }
})
$tabPage2.Controls.Add($btnModBaiduDl)

$lblModImportStatus = New-Object System.Windows.Forms.Label
$lblModImportStatus.Text     = (T 'mod.import.status')
$lblModImportStatus.Location = New-Object System.Drawing.Point(28, 192)
$lblModImportStatus.Size     = New-Object System.Drawing.Size(700, 18)
$tabPage2.Controls.Add($lblModImportStatus)

# Progress bar for MOD download/extraction (hidden until download starts)
$pbModDl = New-Object System.Windows.Forms.ProgressBar
$pbModDl.Location = New-Object System.Drawing.Point(28, 213)
$pbModDl.Size     = New-Object System.Drawing.Size(700, 14)
$pbModDl.Minimum  = 0
$pbModDl.Maximum  = 100
$pbModDl.Value    = 0
$pbModDl.Visible  = $false
$tabPage2.Controls.Add($pbModDl)

$sep2 = New-Object System.Windows.Forms.Label
$sep2.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$sep2.Location    = New-Object System.Drawing.Point(12, 234)
$sep2.Size        = New-Object System.Drawing.Size(740, 2)
$tabPage2.Controls.Add($sep2)

$lblModStep2 = New-Object System.Windows.Forms.Label
$lblModStep2.Text     = (T 'mod.step2.title')
$lblModStep2.Location = New-Object System.Drawing.Point(12, 244)
$lblModStep2.Size     = New-Object System.Drawing.Size(740, 20)
$lblModStep2.Font     = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage2.Controls.Add($lblModStep2)

$btnModInstall = New-Object System.Windows.Forms.Button
$btnModInstall.Text     = (T 'mod.btn.install')
$btnModInstall.Location = New-Object System.Drawing.Point(28, 269)
$btnModInstall.Size     = New-Object System.Drawing.Size(200, 32)
$tabPage2.Controls.Add($btnModInstall)

$lblModInstallStatus = New-Object System.Windows.Forms.Label
$lblModInstallStatus.Text     = (T 'mod.install.status')
$lblModInstallStatus.Location = New-Object System.Drawing.Point(240, 278)
$lblModInstallStatus.Size     = New-Object System.Drawing.Size(490, 18)
$tabPage2.Controls.Add($lblModInstallStatus)

$btnModInstall.Add_Click({
    $gameRoot = $txtModRoot.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gameRoot)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.noroot'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }

    # Check JSGME source exists
    $jsgmeSrc = Join-Path $jsGameDir $jsgmeExeName
    if (-not (Test-Path $jsgmeSrc)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.nojsgame' $jsGameDir), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }

    $lblModInstallStatus.Text = (T 'mod.install.doing')
    [System.Windows.Forms.Application]::DoEvents()
    try {
        if (-not (Test-Path $gameRoot)) {
            New-Item -Path $gameRoot -ItemType Directory -Force | Out-Null
        }
        Copy-Item -Path "$jsGameDir\*" -Destination $gameRoot -Recurse -Force

        # Verify JSGME exe landed in game folder
        $jsgmeDest = Join-Path $gameRoot $jsgmeExeName
        if (-not (Test-Path $jsgmeDest)) {
            $lblModInstallStatus.Text = (T 'mod.install.err' 'JSGME 文件复制后未找到，请检查 JSGAME 目录')
            return
        }

        Update-ModStatus -GameRoot $gameRoot

        # Warn if MODS folder is still empty (Step 1 not done)
        $modsFolder = Join-Path $gameRoot 'MODS'
        $hasContent = (Test-Path $modsFolder) -and `
                      ($null -ne (Get-ChildItem -Path $modsFolder -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1))
        if (-not $hasContent) {
            $lblModInstallStatus.Text = (T 'mod.install.warn.nomods')
        } else {
            $lblModInstallStatus.Text = (T 'mod.install.done')
        }
        Save-RbrState -Updates @{ gameRoot = $gameRoot }
    } catch {
        $lblModInstallStatus.Text = (T 'mod.install.err' "$_")
    }
})

$sep3 = New-Object System.Windows.Forms.Label
$sep3.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$sep3.Location    = New-Object System.Drawing.Point(12, 315)
$sep3.Size        = New-Object System.Drawing.Size(740, 2)
$tabPage2.Controls.Add($sep3)

$lblModStep3 = New-Object System.Windows.Forms.Label
$lblModStep3.Text     = (T 'mod.step3.title')
$lblModStep3.Location = New-Object System.Drawing.Point(12, 325)
$lblModStep3.Size     = New-Object System.Drawing.Size(740, 20)
$lblModStep3.Font     = New-Object System.Drawing.Font($form.Font, [System.Drawing.FontStyle]::Bold)
$tabPage2.Controls.Add($lblModStep3)

$btnModOpen = New-Object System.Windows.Forms.Button
$btnModOpen.Text     = (T 'mod.btn.open')
$btnModOpen.Location = New-Object System.Drawing.Point(28, 350)
$btnModOpen.Size     = New-Object System.Drawing.Size(240, 32)
$btnModOpen.Enabled  = $false
$btnModOpen.Add_Click({
    $gameRoot    = $txtModRoot.Text.Trim()
    $jsgmeInRoot = Join-Path $gameRoot $jsgmeExeName
    if (-not (Test-Path $jsgmeInRoot)) {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.noexe'), (T 'err.title'), 'OK', 'Warning') | Out-Null
        return
    }
    try {
        Start-Process -FilePath $jsgmeInRoot -WorkingDirectory $gameRoot | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            (T 'mod.err.launch' "$_"), (T 'err.title'), 'OK', 'Error') | Out-Null
    }
})
$tabPage2.Controls.Add($btnModOpen)

# ─── End Tab 2 ───────────────────────────────────────────────────────────────

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
    $pbAutoDownload.Visible = $true
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

        $pbAutoDownload.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
        $pbAutoDownload.Value = 100
        $lblStatus.Text = (T 'status.dl.done')
        [System.Windows.Forms.MessageBox]::Show((T 'dlg.dl.done'), (T 'mon.popup.seeding.title'), "OK", "Information") | Out-Null
    } catch {
        $pbAutoDownload.Visible = $false
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

# Startup: scan for existing RBR installation and load saved state
$script:AutoDetectedRbrPath = Find-ExistingRbrPath
$savedState = Load-RbrState
if ($savedState -and $savedState.gameRoot -and (Test-Path $savedState.gameRoot)) {
    $script:AutoDetectedRbrPath = $savedState.gameRoot
}

# qBittorrent prerequisite check
$script:QbtInstalled = Test-QBittorrentInstalled
if ($script:QbtInstalled) {
    $lblQbStatus.Text      = (T 'qb.status.ok')
    $lblQbStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    $btnQbDl.Visible       = $false
} else {
    $lblQbStatus.Text      = (T 'qb.status.missing')
    $lblQbStatus.ForeColor = [System.Drawing.Color]::DarkRed
    $btnQbDl.Visible       = $true
}

# First-run welcome dialog
$isFirstRun = (-not $savedState) -or (-not $savedState.PSObject.Properties['firstRunDone']) -or (-not $savedState.firstRunDone)
if ($isFirstRun) {
    [System.Windows.Forms.MessageBox]::Show(
        (T 'welcome.msg'), (T 'welcome.title'), 'OK', 'Information') | Out-Null
    Save-RbrState -Updates @{ firstRunDone = $true }
}

$txtDownload.Text = Get-DefaultDownloadPath
# If we have a confirmed existing game path, use it for Tab1 download path too
if ($script:AutoDetectedRbrPath -and (Test-Path $script:AutoDetectedRbrPath)) {
    $txtDownload.Text = $script:AutoDetectedRbrPath
}
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
    $form.Text         = "$(T 'form.title')  $script:AppVersion"
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
    $btnQbDl.Text      = (T 'qb.btn.dl')
    if ($script:QbtInstalled) {
        $lblQbStatus.Text = (T 'qb.status.ok')
    } else {
        $lblQbStatus.Text = (T 'qb.status.missing')
    }
    $lblDriveHint.Text = Get-DriveHintText -Path $txtDownload.Text.Trim()
    $lblI18nTitle.Text    = (T 'i18n.step.title')
    $btnI18n.Text         = (T 'i18n.btn.install')
    $btnI18nUpdate.Text   = (T 'i18n.btn.update')

    $tabPage1.Text         = (T 'tab.install')
    $tabPage2.Text         = (T 'tab.mod')
    $lblModWarn.Text       = (T 'mod.warn')
    $lblModRoot.Text       = (T 'mod.lbl.root')
    $btnModBrowse.Text     = (T 'btn.browse')
    $lblModStep1.Text          = (T 'mod.step1.title')
    $lblModStep1Note.Text      = (T 'mod.step1.note')
    $btnModImportFolder.Text   = (T 'mod.btn.importfolder')
    $btnModImportZip.Text      = (T 'mod.btn.importzip')
    $btnModGithubDl.Text       = (T 'mod.btn.githubdl')
    $btnModBaiduDl.Text        = (T 'mod.btn.baidudl')
    $lblModStep2.Text      = (T 'mod.step2.title')
    $btnModInstall.Text    = (T 'mod.btn.install')
    $lblModStep3.Text      = (T 'mod.step3.title')
    $btnModOpen.Text       = (T 'mod.btn.open')
    Update-ModStatus -GameRoot $txtModRoot.Text.Trim()
}

$cmbLang.Add_SelectedIndexChanged({
    $script:LangCode = if ($cmbLang.SelectedIndex -eq 0) { 'zh' } else { 'en' }
    Apply-MainFormLanguage
})

$tabControl.Add_SelectedIndexChanged({
    if ($tabControl.SelectedIndex -eq 1) {
        # Only auto-fill when user hasn't typed anything
        if ([string]::IsNullOrWhiteSpace($txtModRoot.Text)) {
            $fill = $txtDownload.Text.Trim()
            # Fallback: saved state or auto-detected path
            if ([string]::IsNullOrWhiteSpace($fill)) {
                $fill = $script:AutoDetectedRbrPath
            }
            if (-not [string]::IsNullOrWhiteSpace($fill)) {
                $txtModRoot.Text = $fill
            }
        }
        Update-ModStatus -GameRoot $txtModRoot.Text.Trim()
    }
})

# Dispose NotifyIcon and stop background timers when the main form closes
$form.Add_FormClosed({
    try { $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() } catch {}
    try { if ($script:QbtPollTimer) { $script:QbtPollTimer.Stop(); $script:QbtPollTimer.Dispose() } } catch {}
    try { if ($script:ModsDlTimer)  { $script:ModsDlTimer.Stop()  } } catch {}
})

# ─── 底部开发者信息条（两个 Tab 均可见）────────────────────────────────────────
$pnlCredits = New-Object System.Windows.Forms.Panel
$pnlCredits.Dock      = [System.Windows.Forms.DockStyle]::Bottom
$pnlCredits.Height    = 20
$pnlCredits.BackColor = [System.Drawing.SystemColors]::ControlLight

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text      = "miyasgi  ·  魔法界的天空"
$lblCredits.Dock      = [System.Windows.Forms.DockStyle]::Fill
$lblCredits.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblCredits.Font      = New-Object System.Drawing.Font($form.Font.FontFamily, 7.5)
$lblCredits.ForeColor = [System.Drawing.Color]::Gray
$pnlCredits.Controls.Add($lblCredits)

# Bottom 控件必须在 Fill 控件之前加入，布局才正确
$form.Controls.Add($pnlCredits)
$form.Controls.Add($tabControl)

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
