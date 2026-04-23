/**
 * Magic Mount Metaverse v3.5.1
 * Material Design 3 WebUI
 * 
 * v3.5.1 主要更新:
 *   - 新增日志页面清空日志功能
 *   - 修复模块挂载状态显示bug（设置挂载模式后状态正确更新）
 *   - 添加WebUI操作日志记录功能
 *   - 日志页面实时显示全局设置状态和统计信息

 */

// ===== Configuration =====
const CONFIG_PATH = '/data/adb/Metaverse/配置.conf';
const EXTENDED_CONFIG_PATH = '/data/adb/Metaverse/扩展配置.conf';
const AOK_PATH = '/data/adb/metamodule/aok';
const MODULE_DIR = '/data/adb/modules';

// ===== State =====
const state = {
    theme: localStorage.getItem('mm-theme') || 'dark',
    lang: localStorage.getItem('mm-lang') || 'zh',
    animations: localStorage.getItem('mm-animations') !== 'false',
    autoRefresh: parseInt(localStorage.getItem('mm-refresh') || '1'),
    showMetrics: localStorage.getItem('mm-metrics') !== 'false',
    config: {},
    stealth: {},
    modules: [],
    moduleDetails: {},
    logs: { current: '', old: '' },
    currentLog: 'current',
    globalMountMode: 'magic',
    moduleModes: {},
    forceMountModules: {},
    ignoredModules: {},
    expandedModule: null,
    showHidden: false
};

// ===== Supported Partitions =====
const SUPPORTED_PARTITIONS = [
    'system', 'vendor', 'odm', 'my_product', 'system_ext', 
    'product', 'vendor_dlkm', 'odm_dlkm', 'system_dlkm'
];

// ===== 日志刷新功能 v3.5 =====
const LOG_PATH = '/data/adb/Metaverse/运行日志.log';
let log_refresh_timer = null;

// ===== WebUI操作日志记录功能 v3.5.1 =====
async function logOperation(action, detail, success = true) {
    try {
        const timestamp = new Date().toISOString();
        const status = success ? '成功' : '失败';
        const logLine = `[${timestamp}] [WebUI] ${action}: ${detail} - ${status}\n`;
        // 转义单引号避免命令注入
        const escapedLogLine = logLine.replace(/'/g, "'\\''");
        const cmd = `mkdir -p '/data/adb/Metaverse' && echo '${escapedLogLine}' >> '${LOG_PATH}'`;
        await exec(cmd);
    } catch (e) {
        console.error('Log operation error:', e);
    }
}

// ===== 实时统计功能 v3.5.1 =====
function updateLogStats() {
    // 计算统计数据
    let mountedCount = 0;
    let unmountedCount = 0;
    let ignoredCount = 0;
    let skippedCount = 0;
    
    state.modules.forEach(mod => {
        const isForced = isForceMount(mod.id);
        const isIgnored = isCustomIgnored(mod.id);
        
        if (isIgnored || mod.ignored) {
            ignoredCount++;
        } else if (!mod.hasSystem) {
            unmountedCount++;
        } else if (mod.skip) {
            skippedCount++;
            if (isForced) {
                mountedCount++;
            }
        } else if (mod.disabled) {
            unmountedCount++;
        } else {
            mountedCount++;
        }
    });
    
    // 更新UI
    const statsContainer = document.getElementById('logStatsContainer');
    if (statsContainer) {
        statsContainer.innerHTML = `
            <div class="log-stats-grid">
                <div class="log-stats-item">
                    <div class="log-stats-label">${t('logs.mountedCount')}</div>
                    <div class="log-stats-value mounted">${mountedCount}</div>
                </div>
                <div class="log-stats-item">
                    <div class="log-stats-label">${t('logs.unmountedCount')}</div>
                    <div class="log-stats-value unmounted">${unmountedCount}</div>
                </div>
                <div class="log-stats-item">
                    <div class="log-stats-label">${t('logs.ignoredCount')}</div>
                    <div class="log-stats-value ignored">${ignoredCount}</div>
                </div>
                <div class="log-stats-item">
                    <div class="log-stats-label">${t('logs.skippedCount')}</div>
                    <div class="log-stats-value skipped">${skippedCount}</div>
                </div>
            </div>
        `;
    }
    
    // 更新全局设置显示
    const settingsContainer = document.getElementById('globalSettingsDisplay');
    if (settingsContainer) {
        const mountModeText = state.globalMountMode === 'overlayfs' ? 'OverlayFS' : 'Magic';
        const stealthText = state.stealth.stealth_mode ? 
            (state.stealth.randomize_id ? '完整隐身' : '已启用') : '未启用';
        settingsContainer.innerHTML = `
            <div class="global-settings-row">
                <span class="global-settings-label">${t('logs.mountMode')}:</span>
                <span class="global-settings-value">${mountModeText}</span>
            </div>
            <div class="global-settings-row">
                <span class="global-settings-label">${t('logs.stealthMode')}:</span>
                <span class="global-settings-value">${stealthText}</span>
            </div>
        `;
    }
}

// ===== 清空日志功能 v3.5.1 =====
async function clearLogFile() {
    try {
        const cmd = `> '${LOG_PATH}'`;
        await exec(cmd);
        showToast(t('logs.clearSuccess'), 'success');
        await logOperation('清空日志', '用户清空了运行日志', true);
        load_logs();
    } catch (e) {
        console.error('Clear log error:', e);
        showToast(t('logs.clearFailed'), 'error');
        await logOperation('清空日志', '清空日志失败: ' + e.message, false);
    }
}

function start_log_refresh() {
    if (log_refresh_timer) return;
    log_refresh_timer = setInterval(load_logs, 2000);
}

function stop_log_refresh() {
    if (log_refresh_timer) {
        clearInterval(log_refresh_timer);
        log_refresh_timer = null;
    }
}

function toggle_log_refresh() {
    const btn = document.getElementById('autoRefreshLogBtn');
    if (!btn) return;
    
    if (log_refresh_timer) {
        stop_log_refresh();
        btn.classList.remove('active');
        btn.textContent = '自动刷新';
    } else {
        start_log_refresh();
        btn.classList.add('active');
        btn.textContent = '刷新中';
    }
}

async function load_logs() {
    const log_el = document.getElementById('logContent');
    if (!log_el) return;
    
    try {
        const script = `tail -n 100 "${LOG_PATH}" 2>/dev/null || echo "日志文件不存在"`;
        const { stdout } = await exec(script);
        log_el.textContent = stdout || '暂无日志';
        log_el.scrollTop = log_el.scrollHeight;
    } catch (e) {
        log_el.textContent = '读取日志失败: ' + e.message;
    }
}

function clear_log_content() {
    const log_el = document.getElementById('logContent');
    if (log_el) log_el.textContent = '';
}

// ===== Translations (Full i18n) =====
const i18n = {
    zh: {
        status: { mount: '挂载', stealth: '隐身', modules: '模块' },
        sysinfo: { android: '安卓版本', kernel: '内核版本', device: '机型信息' },
        tabs: { config: '配置', modules: '模块', logs: '日志', about: '关于', settings: '设置' },
        config: {
            title: '配置',
            moduleDir: '模块目录',
            logFile: '日志文件',
            mountSource: '挂载源',
            debug: '调试模式',
            umount: '启用卸载',
            partitions: '分区',
            partitionsDesc: '选择要挂载的分区',
            pathLabel: '配置路径'
        },
        modules: { 
            title: '模块', 
            loading: '正在加载模块...', 
            empty: '未找到模块',
            emptyHint: '模块目录中未找到模块',
            path: '路径',
            mountMode: '挂载模式',
            magic: 'Magic',
            overlayfs: 'OverlayFS',
            ignore: '忽略',
            id: 'ID',
            version: '版本',
            description: '描述',
            status: '状态',
            mounted: '已挂载',
            unmounted: '未挂载',
            ignored: '已忽略',
            customIgnored: '自定义忽略',
            defaultMode: '默认模式',
            searchPlaceholder: '搜索模块...',
            reload: '刷新',
            save: '保存更改',
            saving: '保存中...',
            saveSuccess: '更改已保存',
            magicDesc: 'Magic模式使用单目录挂载',
            overlayDesc: 'OverlayFS模式使用双目录隔离',
            ignoreDesc: '忽略后跳过不被magic和overlayfs挂载',
            showHidden: '显示模块',
            hideHidden: '隐藏模块',
            forceMount: '强制挂载',
            forceMounted: '已强制挂载',
            unforceMount: '取消强制',
            ignoreMarker: '包含忽略标记(原生)',
            ignoreHint: '此模块有ignore标记，但已启用强制挂载',
            customIgnore: '自定义忽略',
            customIgnoreDesc: '忽略此模块，不进行overlayfs和magic挂载',
            forceMountDesc: '即使模块有skip_mount标记也强制挂载',
            hiddenModule: '隐藏模块',
            hiddenModuleHint: '此模块不需要挂载（无system目录）'
        },
        about: {
            projectInfo: '项目信息',
            links: '相关链接',
            projectAddr: 'GitHub项目',
            qqGroup: 'QQ群',
            tutorial: '使用教程',
            tut1: { title: '配置页面', desc: '选择要挂载的分区，配置挂载源' },
            tut2: { title: '模块页面', desc: '设置每个模块的挂载模式，强制挂载或忽略特定模块' },
            tut3: { title: '设置页面', desc: '启用隐身模式和性能优化' },
            tut4: { title: '重启', desc: '重启设备以应用更改' },
            donate: '☕ 支持开发',
            donateHint: '扫码捐赠'
        },
        settings: {
            title: '设置',
            animations: '启用动画',
            refresh: '自动刷新 (秒)',
            metrics: '显示监控',
            theme: '主题',
            themeDark: '深色',
            themeLight: '浅色',
            about: '关于',
            version: '版本',
            stealthSettings: '隐身设置',
            general: '常规',
            enable: '启用隐身模式',
            randomId: '随机化模块ID',
            hideLogs: '隐藏挂载日志',
            hideFromList: '隐藏模块列表',
            mountMode: '挂载模式',
            mountModeGlobal: '全局挂载模式',
            magicMode: 'Magic',
            overlayfsMode: 'OverlayFS',
            performance: '性能',
            optLevel: '优化级别',
            optOff: '禁用',
            optFast: '快速',
            optUltra: '极致',
            mountDelay: '挂载延迟 (毫秒)',
            parallelMount: '并行挂载'
        },
        btn: { reload: '重新加载', save: '保存', apply: '应用', close: '关闭' },
        toast: { 
            loadSuccess: '配置已加载', 
            loadError: '加载配置失败', 
            saveSuccess: '保存成功', 
            saveError: '保存失败', 
            modeSaved: '挂载模式已保存', 
            forceSaved: '强制挂载设置已保存',
            ignoreSaved: '忽略设置已保存'
        },
        logs: {
            clearLog: '清空日志',
            clearSuccess: '日志已清空',
            clearFailed: '清空日志失败',
            globalSettings: '全局设置',
            mountMode: '挂载模式',
            stealthMode: '隐身模式',
            stats: '统计信息',
            mountedCount: '已挂载',
            unmountedCount: '未挂载',
            ignoredCount: '已忽略',
            skippedCount: '跳过标记',
            tryingMount: '尝试挂载'
        },
        dialog: { help: '帮助', cancel: '关闭', confirm: '确定' }
    },
    en: {
        status: { mount: 'Mount', stealth: 'Stealth', modules: 'Modules' },
        sysinfo: { android: 'Android', kernel: 'Kernel', device: 'Device' },
        tabs: { config: 'Config', modules: 'Modules', logs: 'Logs', about: 'About', settings: 'Settings' },
        config: {
            title: 'Configuration',
            moduleDir: 'Module Directory',
            logFile: 'Log File',
            mountSource: 'Mount Source',
            debug: 'Debug Mode',
            umount: 'Enable Unmount',
            partitions: 'Partitions',
            partitionsDesc: 'Select partitions to mount',
            pathLabel: 'Config Path'
        },
        modules: { 
            title: 'Modules', 
            loading: 'Loading modules...', 
            empty: 'No modules found',
            emptyHint: 'No modules found in the module directory',
            path: 'Path',
            mountMode: 'Mount Mode',
            magic: 'Magic',
            overlayfs: 'OverlayFS',
            ignore: 'Ignore',
            id: 'ID',
            version: 'Version',
            description: 'Description',
            status: 'Status',
            mounted: 'Mounted',
            unmounted: 'Unmounted',
            ignored: 'Ignored',
            customIgnored: 'Custom Ignored',
            defaultMode: 'Default Mode',
            searchPlaceholder: 'Search modules...',
            reload: 'Reload',
            save: 'Save Changes',
            saving: 'Saving...',
            saveSuccess: 'Changes saved successfully',
            magicDesc: 'Magic mode uses a single directory for mounting',
            overlayDesc: 'OverlayFS mode uses dual directory for better isolation',
            ignoreDesc: 'Skip from both magic and overlayfs mounting',
            showHidden: 'Show Modules',
            hideHidden: 'Hide Modules',
            forceMount: 'Force Mount',
            forceMounted: 'Force Mounted',
            unforceMount: 'Remove Force',
            ignoreMarker: 'Has ignore marker (native)',
            ignoreHint: 'This module has an ignore marker but force mount is enabled',
            customIgnore: 'Custom Ignore',
            customIgnoreDesc: 'Ignore this module from overlayfs and magic mount',
            forceMountDesc: 'Force mount even if module has skip_mount marker',
            hiddenModule: 'Hidden Module',
            hiddenModuleHint: 'This module does not need mounting (no system dir)'
        },
        about: {
            projectInfo: 'Project Info',
            links: 'Links',
            projectAddr: 'GitHub Project',
            qqGroup: 'QQ Group',
            tutorial: 'Usage Tutorial',
            tut1: { title: 'Config Tab', desc: 'Select partitions to mount and configure mount source' },
            tut2: { title: 'Modules Tab', desc: 'Set mount mode for each module, force mount or ignore specific modules' },
            tut3: { title: 'Settings Tab', desc: 'Enable stealth mode and performance optimization' },
            tut4: { title: 'Reboot', desc: 'Reboot device to apply changes' },
            donate: '☕ Support Development',
            donateHint: 'Scan QR code to donate'
        },
        settings: {
            title: 'Settings',
            animations: 'Enable Animations',
            refresh: 'Auto Refresh (sec)',
            metrics: 'Show Metrics',
            theme: 'Theme',
            themeDark: 'Dark',
            themeLight: 'Light',
            about: 'About',
            version: 'Version',
            stealthSettings: 'Stealth Settings',
            general: 'General',
            enable: 'Enable Stealth Mode',
            randomId: 'Randomize Module ID',
            hideLogs: 'Hide Mount Logs',
            hideFromList: 'Hide from Module List',
            mountMode: 'Mount Mode',
            mountModeGlobal: 'Global Mount Mode',
            magicMode: 'Magic',
            overlayfsMode: 'OverlayFS',
            performance: 'Performance',
            optLevel: 'Optimization Level',
            optOff: 'Disabled',
            optFast: 'Fast',
            optUltra: 'Ultra',
            mountDelay: 'Mount Delay (ms)',
            parallelMount: 'Parallel Mounting'
        },
        btn: { reload: 'Reload', save: 'Save', apply: 'Apply', close: 'Close' },
        toast: { 
            loadSuccess: 'Configuration loaded', 
            loadError: 'Failed to load config', 
            saveSuccess: 'Saved successfully', 
            saveError: 'Save failed', 
            modeSaved: 'Mount mode saved', 
            forceSaved: 'Force mount setting saved',
            ignoreSaved: 'Ignore setting saved'
        },
        logs: {
            clearLog: 'Clear Log',
            clearSuccess: 'Log cleared',
            clearFailed: 'Failed to clear log',
            globalSettings: 'Global Settings',
            mountMode: 'Mount Mode',
            stealthMode: 'Stealth Mode',
            stats: 'Statistics',
            mountedCount: 'Mounted',
            unmountedCount: 'Unmounted',
            ignoredCount: 'Ignored',
            skippedCount: 'Skipped',
            tryingMount: 'Trying Mount'
        },
        dialog: { help: 'Help', cancel: 'Close', confirm: 'OK' }
    },
    ja: {
        status: { mount: 'マウント', stealth: 'ステルス', modules: 'モジュール' },
        sysinfo: { android: 'Android', kernel: 'カーネル', device: 'デバイス' },
        tabs: { config: '設定', modules: 'モジュール', logs: 'ログ', about: 'について', settings: '設定' },
        config: {
            title: '設定',
            moduleDir: 'モジュールディレクトリ',
            logFile: 'ログファイル',
            mountSource: 'マウントソース',
            debug: 'デバッグモード',
            umount: 'アンマウント有効',
            partitions: 'パーティション',
            partitionsDesc: 'マウントするパーティションを選択',
            pathLabel: '設定パス'
        },
        modules: { 
            title: 'モジュール', 
            loading: 'モジュールを読み込み中...', 
            empty: 'モジュールが見つかりません',
            emptyHint: 'モジュールディレクトリにモジュールが見つかりません',
            path: 'パス',
            mountMode: 'マウントモード',
            magic: 'Magic',
            overlayfs: 'OverlayFS',
            ignore: '無視',
            id: 'ID',
            version: 'バージョン',
            description: '説明',
            status: 'ステータス',
            mounted: 'マウント済み',
            unmounted: '未マウント',
            ignored: '無視',
            customIgnored: 'カスタム無視',
            defaultMode: 'デフォルトモード',
            searchPlaceholder: 'モジュールを検索...',
            reload: '再読み込み',
            save: '変更を保存',
            saving: '保存中...',
            saveSuccess: '変更が保存されました',
            magicDesc: 'Magicモードは単一ディレクトリを使用',
            overlayDesc: 'OverlayFSモードはデュアルディレクトリを使用',
            ignoreDesc: 'magicとoverlayfsのマウントをスキップ',
            showHidden: 'モジュールを表示',
            hideHidden: 'モジュールを非表示',
            forceMount: '強制マウント',
            forceMounted: '強制マウント済み',
            unforceMount: '強制解除',
            ignoreMarker: 'ignoreマーカーあり(ネイティブ)',
            ignoreHint: 'このモジュールにはignoreマーカーがありますが、強制マウントが有効です',
            customIgnore: 'カスタム無視',
            customIgnoreDesc: 'このモジュールをoverlayfsとmagicマウントから除外',
            forceMountDesc: 'モジュールにskip_mountマーカーがあっても強制マウント',
            hiddenModule: '隠しモジュール',
            hiddenModuleHint: 'このモジュールはマウント不要(systemディレクトリなし)'
        },
        about: {
            projectInfo: 'プロジェクト情報',
            links: 'リンク',
            projectAddr: 'GitHubプロジェクト',
            qqGroup: 'QQグループ',
            tutorial: '使い方チュートリアル',
            tut1: { title: '設定タブ', desc: 'マウントするパーティションを選択し、マウントソースを設定' },
            tut2: { title: 'モジュールタブ', desc: '各モジュールのマウントモードを設定、強制マウントまたは特定のモジュールを無視' },
            tut3: { title: '設定タブ', desc: 'ステルスモードとパフォーマンス最適化を有効にする' },
            tut4: { title: '再起動', desc: 'デバイスを再起動して変更を適用' },
            donate: '☕ 開発をサポート',
            donateHint: 'QRコードをスキャンして寄付'
        },
        settings: {
            title: '設定',
            animations: 'アニメーション有効',
            refresh: '自動更新 (秒)',
            metrics: 'モニタ表示',
            theme: 'テーマ',
            themeDark: 'ダーク',
            themeLight: 'ライト',
            about: 'について',
            version: 'バージョン',
            stealthSettings: 'ステルス設定',
            general: '一般',
            enable: 'ステルスモード有効',
            randomId: 'モジュールIDランダム化',
            hideLogs: 'マウントログ非表示',
            hideFromList: 'モジュールリスト非表示',
            mountMode: 'マウントモード',
            mountModeGlobal: 'グローバルマウントモード',
            magicMode: 'Magic',
            overlayfsMode: 'OverlayFS',
            performance: 'パフォーマンス',
            optLevel: '最適化レベル',
            optOff: '無効',
            optFast: '高速',
            optUltra: 'ウルトラ',
            mountDelay: 'マウント遅延 (ms)',
            parallelMount: '並列マウント'
        },
        btn: { 再読み込み: '再読み込み', save: '保存', apply: '適用', close: '閉じる' },
        toast: { 
            loadSuccess: '設定を読み込みました', 
            loadError: '設定の読み込みに失敗', 
            saveSuccess: '保存しました', 
            saveError: '保存に失敗', 
            modeSaved: 'マウントモードを保存しました', 
            forceSaved: '強制マウント設定を保存しました',
            ignoreSaved: '無視設定を保存しました'
        },
        logs: {
            clearLog: 'ログをクリア',
            clearSuccess: 'ログをクリアしました',
            clearFailed: 'ログのクリアに失敗',
            globalSettings: 'グローバル設定',
            mountMode: 'マウントモード',
            stealthMode: 'ステルスモード',
            stats: '統計情報',
            mountedCount: 'マウント済み',
            unmountedCount: '未マウント',
            ignoredCount: '無視済み',
            skippedCount: 'スキップマーカー',
            tryingMount: 'マウント試行'
        },
        dialog: { help: 'ヘルプ', cancel: '閉じる', confirm: 'OK' }
    }
};

// ===== Help Content =====
const helpContent = {
    zh: {
        partitions: '选择要处理模块挂载的系统分区。默认：所有分区。',
        partitionsSelect: '点击选择/取消选择分区。选中的分区将被挂载。',
        showHidden: '显示不需要挂载的模块（如纯shell模块、无system目录的模块）。',
        customIgnore: '启用后，此模块将完全跳过overlayfs和magic挂载操作。',
        forceMount: '即使模块有skip_mount标记或被禁用，也强制挂载此模块。'
    },
    en: {
        partitions: 'Select which system partitions to handle for module mounting. Default: all partitions.',
        partitionsSelect: 'Click to select/deselect partitions. Selected partitions will be mounted.',
        showHidden: 'Show modules that do not need mounting (e.g., pure shell modules, no system directory).',
        customIgnore: 'When enabled, this module will be completely skipped from overlayfs and magic mount operations.',
        forceMount: 'Force mount this module even if it has skip_mount marker or is disabled.'
    },
    ja: {
        partitions: 'モジュールマウント用に処理するシステムパーティションを選びます。デフォルト：全て。',
        partitionsSelect: 'クリックしてパーティションを選択/選択解除。選択したパーティションがマウントされます。',
        showHidden: 'マウント不要なモジュールを表示（例：純粋なシェルモジュール、systemディレクトリなし）。',
        customIgnore: '有効にすると、このモジュールはoverlayfsとmagicマウント操作から完全にスキップされます。',
        forceMount: 'モジュールにskip_mountマーカーがある거나無効でも、このモジュールを強制マウントします。'
    }
};

// ===== Utilities =====
function t(key) {
    const keys = key.split('.');
    let value = i18n[state.lang];
    for (const k of keys) {
        value = value?.[k];
    }
    return value || key;
}

function updateI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        el.textContent = t(key);
    });
    document.getElementById('langCode').textContent = state.lang === 'zh' ? '中' : (state.lang === 'ja' ? '日' : 'EN');
    
    // Update language dropdown active state
    document.querySelectorAll('.lang-option').forEach(opt => {
        if (opt.dataset.lang === state.lang) {
            opt.classList.add('active');
        } else {
            opt.classList.remove('active');
        }
    });
    
    // Update partition display
    updatePartitionDisplay();
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
}

async function exec(command, args = {}) {
    return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}_${Math.random().toString(36).substr(2)}`;
        window[callbackId] = (errno, stdout, stderr) => {
            delete window[callbackId];
            if (errno === 0) {
                resolve({ errno: 0, stdout, stderr });
            } else {
                reject(new Error(stderr || 'Command failed'));
            }
        };
        try {
            ksu.exec(command, JSON.stringify(args), callbackId);
        } catch (e) {
            delete window[callbackId];
            reject(e);
        }
    });
}

function parseBool(value) {
    if (typeof value === 'boolean') return value;
    const str = String(value).toLowerCase().trim();
    return ['1', 'true', 'yes', 'on', 'enabled'].includes(str);
}

function parseModuleModes(jsonStr) {
    try {
        return JSON.parse(jsonStr || '{}');
    } catch {
        return {};
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// ===== Dialog System =====
function showDialog(title, content, options = {}) {
    const overlay = document.createElement('div');
    overlay.className = 'md3-dialog-overlay';
    
    const dialog = document.createElement('div');
    dialog.className = 'md3-dialog';
    
    const icon = options.icon || 'info';
    const iconSvg = getDialogIcon(icon);
    
    dialog.innerHTML = `
        <div class="md3-dialog-header">
            <div class="md3-dialog-icon">${iconSvg}</div>
            <h3 class="md3-dialog-title">${title}</h3>
        </div>
        <div class="md3-dialog-content">${content}</div>
        <div class="md3-dialog-actions">
            ${options.showCancel !== false ? `<button class="md3-dialog-btn md3-dialog-btn-cancel">${t('dialog.cancel')}</button>` : ''}
            ${options.confirmText ? `<button class="md3-dialog-btn md3-dialog-btn-confirm">${options.confirmText}</button>` : ''}
        </div>
    `;
    
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    
    requestAnimationFrame(() => {
        overlay.classList.add('active');
        dialog.classList.add('active');
    });
    
    const closeDialog = () => {
        overlay.classList.remove('active');
        dialog.classList.remove('active');
        setTimeout(() => overlay.remove(), 300);
    };
    
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) closeDialog();
    });
    
    dialog.querySelector('.md3-dialog-btn-cancel')?.addEventListener('click', closeDialog);
    dialog.querySelector('.md3-dialog-btn-confirm')?.addEventListener('click', () => {
        if (options.onConfirm) options.onConfirm();
        closeDialog();
    });
    
    return { close: closeDialog };
}

function getDialogIcon(type) {
    const icons = {
        info: '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>',
        help: '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/></svg>',
        success: '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>'
    };
    return icons[type] || icons.info;
}

// ===== Help System =====
function showHelp(key) {
    const lang = state.lang || 'en';
    const content = helpContent[lang]?.[key] || helpContent.en[key] || 'No help available.';
    showDialog(t('dialog.help'), `<p class="help-text">${content}</p>`, { icon: 'help', showCancel: false, confirmText: t('dialog.confirm') });
}

function createHelpIcon(key) {
    const icon = document.createElement('span');
    icon.className = 'help-icon';
    icon.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5 0-2.21-1.79-4-4-4z"/>';
    icon.addEventListener('click', (e) => {
        e.stopPropagation();
        showHelp(key);
    });
    return icon;
}

function initHelpIcons() {
    document.querySelectorAll('[data-help]').forEach(el => {
        const key = el.dataset.help;
        el.appendChild(createHelpIcon(key));
    });
}

// ===== Theme System =====
function initTheme() {
    const isDark = state.theme === 'dark';
    document.documentElement.setAttribute('data-theme', state.theme);
    document.querySelector('.icon-theme').innerHTML = isDark 
        ? '<path fill="currentColor" d="M6.76 4.84l-1.8-1.79-1.41 1.41 1.79 1.79 1.42-1.41zM4 10.5H1v2h3v-2zm9-9.95h-2V3.5h2V.55zm7.45 3.91l-1.41-1.41-1.79 1.79 1.41 1.41 1.79-1.79zm-3.21 13.7l1.79 1.8 1.41-1.41-1.8-1.79-1.4 1.4zM20 10.5v2h3v-2h-3zm-8-5c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm-1 16.95h2V19.5h-2v2.95zm-7.45-3.91l1.41 1.41 1.79-1.8-1.41-1.41-1.79 1.8z"/>'
        : '<path fill="currentColor" d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"/>';
}

function toggleTheme() {
    state.theme = state.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('mm-theme', state.theme);
    initTheme();
}

// ===== Language System - Fixed =====
function initLangDropdown() {
    const btn = document.getElementById('langBtn');
    const menu = document.getElementById('langMenu');
    
    // Click on language button to toggle dropdown
    btn.addEventListener('click', (e) => {
        e.stopPropagation();
        menu.classList.toggle('show');
    });
    
    // Language option click handlers
    document.querySelectorAll('.lang-option').forEach(opt => {
        opt.addEventListener('click', () => {
            const newLang = opt.dataset.lang;
            if (newLang !== state.lang) {
                state.lang = newLang;
                localStorage.setItem('mm-lang', state.lang);
                updateI18n();
                loadModules();
                showToast(t('toast.loadSuccess'), 'success');
            }
            menu.classList.remove('show');
        });
    });
    
    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
        if (!menu.contains(e.target) && !btn.contains(e.target)) {
            menu.classList.remove('show');
        }
    });
    
    // Prevent click propagation on menu
    menu.addEventListener('click', (e) => {
        e.stopPropagation();
    });
}

// ===== Config Operations =====
async function loadConfig() {
    try {
        const { stdout } = await exec(`cat "${CONFIG_PATH}" 2>/dev/null || echo ""`);
        const lines = stdout.split('\n');
        
        state.config = {
            module_dir: '/data/adb/modules',
            log_file: '/data/adb/Metaverse/运行日志.log',
            mount_source: 'KSU',
            debug: false,
            umount: true,
            partitions: 'system,vendor,odm,my_product,system_ext,product,vendor_dlkm,odm_dlkm,system_dlkm'
        };

        lines.forEach(line => {
            line = line.trim();
            if (!line || line.startsWith('#')) return;
            const [key, ...valueParts] = line.split('=');
            const value = valueParts.join('=').trim();
            if (!key) return;
            
            switch (key.trim()) {
                case 'module_dir': state.config.module_dir = value; break;
                case 'mount_source': state.config.mount_source = value; break;
                case 'log_file': state.config.log_file = value; break;
                case 'debug': state.config.debug = parseBool(value); break;
                case 'umount': state.config.umount = parseBool(value); break;
                case 'partitions': state.config.partitions = value; break;
            }
        });

        updateConfigUI();
        
    } catch (e) {
        console.error('Load config error:', e);
    }
}

function updateConfigUI() {
    document.getElementById('moduleDir').value = state.config.module_dir || '';
    document.getElementById('logFile').value = state.config.log_file || '';
    document.getElementById('mountSource').value = state.config.mount_source || 'KSU';
    document.getElementById('debugMode').checked = state.config.debug || false;
    document.getElementById('umountMode').checked = state.config.umount !== false;
    
    updatePartitionDisplay();
    document.getElementById('configPath').textContent = `${t('config.pathLabel')}: ${CONFIG_PATH}`;
}

function updatePartitionDisplay() {
    const partitionDisplay = document.getElementById('partitionDisplay');
    const selectedPartitions = (state.config.partitions || '').split(',').filter(p => p.trim());
    
    if (selectedPartitions.length === SUPPORTED_PARTITIONS.length || selectedPartitions.length === 0) {
        partitionDisplay.textContent = state.lang === 'zh' ? '全部' : (state.lang === 'ja' ? '全て' : 'All');
    } else {
        partitionDisplay.textContent = `${selectedPartitions.length} ${state.lang === 'zh' ? '个已选' : (state.lang === 'ja' ? '個選択' : 'selected')}`;
    }
}

// v3.4.1-fixed-v6: JSON save mechanism - no base64 encoding
// v3.4.3: Fixed partition save bug - preserve existing partitions when selector is closed
async function saveConfig() {
    try {
        const selectedPartitions = getSelectedPartitions();
        // 如果选择器对话框已关闭，使用当前 state 中的分区设置
        const partitions = selectedPartitions.length > 0 
            ? selectedPartitions.join(',') 
            : (state.config.partitions || SUPPORTED_PARTITIONS.join(','));
        
        const config = {
            module_dir: document.getElementById('moduleDir').value,
            log_file: document.getElementById('logFile').value,
            mount_source: document.getElementById('mountSource').value,
            debug: document.getElementById('debugMode').checked,
            umount: document.getElementById('umountMode').checked,
            partitions: partitions
        };

        const lines = [
            '# Magic Mount Metaverse v3.5.1 Configuration',
            '# Author: GitHub@FHYUYO',
            '',
            'module_dir=' + config.module_dir,
            'mount_source=' + config.mount_source,
            'log_file=' + config.log_file,
            'debug=' + config.debug,
            '',
            'umount=' + config.umount,
            '',
            '# Supported partitions: system, vendor, odm, my_product, system_ext, product, vendor_dlkm, odm_dlkm, system_dlkm',
            'partitions=' + config.partitions
        ];

        // v3.4.2: Use cat with heredoc for better compatibility
        const content = lines.join('\n');
        const cmd = `mkdir -p '/data/adb/Metaverse' && cat > '/data/adb/Metaverse/配置.conf' << 'MMEOF'\n${content}\nMMEOF`;
        
        await exec(cmd);
        state.config = { ...state.config, ...config };
        updatePartitionDisplay();
        showToast(t('toast.saveSuccess'), 'success');
        await logOperation('保存配置', `分区: ${partitions}, 调试: ${config.debug}, 卸载: ${config.umount}`, true);
        updateLogStats(); // v3.5.1: 更新日志页面统计
        
    } catch (e) {
        console.error('Save config error:', e);
        showToast(t('toast.saveError'), 'error');
        await logOperation('保存配置', '保存失败: ' + e.message, false);
    }
}

// ===== Partition Selection =====
function getSelectedPartitions() {
    const selected = [];
    document.querySelectorAll('.partition-chip.selected').forEach(chip => {
        selected.push(chip.dataset.partition);
    });
    return selected;
}

function togglePartition(part) {
    const chip = document.querySelector(`.partition-chip[data-partition="${part}"]`);
    if (chip) {
        chip.classList.toggle('selected');
        updatePartitionDisplay();
    }
}

function showPartitionSelector() {
    const currentPartitions = state.config.partitions?.split(',').filter(p => p.trim()) || [];
    
    const content = `
        <div class="partition-selector">
            <p style="margin-bottom:16px;">${t('config.partitionsDesc')}</p>
            <div class="partition-grid">
                ${SUPPORTED_PARTITIONS.map(part => `
                    <button class="partition-chip ${currentPartitions.includes(part) ? 'selected' : ''}" 
                            data-partition="${part}" 
                            onclick="togglePartition('${part}')">
                        ${part}
                    </button>
                `).join('')}
            </div>
            <div style="margin-top:16px;">
                <button class="md3-btn-secondary" onclick="selectAllPartitions()">${state.lang === 'zh' ? '全选' : (state.lang === 'ja' ? '全て選択' : 'Select All')}</button>
                <button class="md3-btn-secondary" onclick="deselectAllPartitions()">${state.lang === 'zh' ? '取消' : (state.lang === 'ja' ? '選択解除' : 'Deselect')}</button>
            </div>
        </div>
    `;
    
    showDialog(state.lang === 'zh' ? '选择分区' : (state.lang === 'ja' ? 'パーティション選択' : 'Select Partitions'), content, {
        showCancel: true,
        confirmText: t('dialog.confirm'),
        onConfirm: async () => {
            const selected = getSelectedPartitions();
            state.config.partitions = selected.join(',');
            updatePartitionDisplay();
            // Auto save after selection
            await saveConfig();
            await logOperation('选择分区', `已选分区: ${selected.join(',') || '全部'}`, true);
        }
    });
}

function selectAllPartitions() {
    document.querySelectorAll('.partition-chip').forEach(chip => {
        chip.classList.add('selected');
    });
    updatePartitionDisplay();
}

function deselectAllPartitions() {
    document.querySelectorAll('.partition-chip').forEach(chip => {
        chip.classList.remove('selected');
    });
    updatePartitionDisplay();
}

// ===== Stealth/Settings Operations =====
// v3.4.1-fixed-v6: Enhanced config reading with better error handling
async function loadStealth() {
    try {
        // Try to read the config file
        const { stdout } = await exec(`cat "${EXTENDED_CONFIG_PATH}" 2>/dev/null`);
        const lines = (stdout || '').split('\n');
        
        // Initialize with defaults
        state.stealth = {
            stealth_mode: false,
            randomize_id: false,
            hide_mount_logs: false,
            hide_from_list: false,
            optimization_level: '0',
            mount_delay: '0',
            parallel_mount: false,
            mount_mode: 'magic',  // Default
            module_mount_modes: '{}',
            force_mount_modules: '{}',
            ignored_modules: '{}'
        };

        // Parse config file
        let foundMountMode = false;
        lines.forEach(line => {
            line = line.trim();
            if (!line || line.startsWith('#')) return;
            const [key, ...valueParts] = line.split('=');
            const value = valueParts.join('=').trim();
            if (!key) return;
            
            switch (key.trim()) {
                case 'stealth_mode': state.stealth.stealth_mode = parseBool(value); break;
                case 'randomize_id': state.stealth.randomize_id = parseBool(value); break;
                case 'hide_mount_logs': state.stealth.hide_mount_logs = parseBool(value); break;
                case 'hide_from_list': state.stealth.hide_from_list = parseBool(value); break;
                case 'optimization_level': state.stealth.optimization_level = value; break;
                case 'mount_delay': state.stealth.mount_delay = value; break;
                case 'parallel_mount': state.stealth.parallel_mount = parseBool(value); break;
                case 'mount_mode': 
                    state.stealth.mount_mode = value; 
                    foundMountMode = true;
                    break;
                case 'module_mount_modes': state.stealth.module_mount_modes = value; break;
                case 'force_mount_modules': state.stealth.force_mount_modules = value; break;
                case 'ignored_modules': state.stealth.ignored_modules = value; break;
            }
        });

        // Set global mount mode - ensure it's correctly read from config
        state.globalMountMode = (foundMountMode && state.stealth.mount_mode) ? state.stealth.mount_mode : 'magic';
        
        // Validate mount_mode is either 'magic' or 'overlayfs'
        if (state.globalMountMode !== 'magic' && state.globalMountMode !== 'overlayfs') {
            state.globalMountMode = 'magic';
        }
        
        state.moduleModes = parseModuleModes(state.stealth.module_mount_modes);
        state.forceMountModules = parseModuleModes(state.stealth.force_mount_modules);
        state.ignoredModules = parseModuleModes(state.stealth.ignored_modules);

        updateStealthUI();
        updateStatusUI();
        
    } catch (e) {
        console.error('Load stealth error:', e);
        // Try to read from a fallback location
        try {
            const fallbackPath = '/data/adb/modules/Magic-Mount-Metaverse/扩展配置.conf';
            const { stdout } = await exec(`cat "${fallbackPath}" 2>/dev/null || echo ""`);
            if (stdout && stdout.includes('mount_mode=')) {
                const match = stdout.match(/mount_mode=([^\s\n]+)/);
                if (match) {
                    state.globalMountMode = (match[1] === 'overlayfs') ? 'overlayfs' : 'magic';
                    updateStatusUI();
                }
            }
        } catch (e2) {
            console.error('Fallback config read also failed:', e2);
        }
    }
}

function updateStealthUI() {
    const s = state.stealth;
    document.getElementById('stealthMode').checked = s.stealth_mode || false;
    document.getElementById('randomizeId').checked = s.randomize_id || false;
    document.getElementById('hideMountLogs').checked = s.hide_mount_logs || false;
    document.getElementById('hideFromList').checked = s.hide_from_list || false;
    document.getElementById('optLevel').value = s.optimization_level || '0';
    document.getElementById('mountDelay').value = s.mount_delay || '0';
    document.getElementById('parallelMount').checked = s.parallel_mount || false;
    
    const mountModeSelect = document.getElementById('globalMountMode');
    if (mountModeSelect) {
        mountModeSelect.value = state.globalMountMode;
    }
}

// v3.4.1-fixed-v6: JSON save mechanism - no base64 encoding
async function saveStealth() {
    try {
        const stealthSettings = {
            stealth_mode: document.getElementById('stealthMode').checked,
            randomize_id: document.getElementById('randomizeId').checked,
            hide_mount_logs: document.getElementById('hideMountLogs').checked,
            hide_from_list: document.getElementById('hideFromList').checked,
            optimization_level: document.getElementById('optLevel').value,
            mount_delay: document.getElementById('mountDelay').value,
            parallel_mount: document.getElementById('parallelMount').checked,
            mount_mode: document.getElementById('globalMountMode')?.value || 'magic',
            module_mount_modes: JSON.stringify(state.moduleModes),
            force_mount_modules: JSON.stringify(state.forceMountModules),
            ignored_modules: JSON.stringify(state.ignoredModules)
        };

        const lines = [
            '# Magic Mount Metaverse Extended Config v3.5.1',
            '# Author: GitHub@FHYUYO',
            '',
            '# Stealth Settings',
            'stealth_mode=' + stealthSettings.stealth_mode,
            'randomize_id=' + stealthSettings.randomize_id,
            'hide_mount_logs=' + stealthSettings.hide_mount_logs,
            'hide_from_list=' + stealthSettings.hide_from_list,
            '',
            '# Mount Mode Settings',
            'mount_mode=' + stealthSettings.mount_mode,
            'module_mount_modes=' + stealthSettings.module_mount_modes,
            '',
            '# Force Mount Settings',
            'force_mount_modules=' + stealthSettings.force_mount_modules,
            '',
            '# Custom Ignore Settings',
            'ignored_modules=' + stealthSettings.ignored_modules,
            '',
            '# Performance Settings',
            'optimization_level=' + stealthSettings.optimization_level,
            'mount_delay=' + stealthSettings.mount_delay,
            'parallel_mount=' + stealthSettings.parallel_mount
        ];

        const content = lines.join('\n');
        // v3.4.2: Use cat with heredoc for better compatibility
        const cmd = `mkdir -p '/data/adb/Metaverse' && cat > '/data/adb/Metaverse/扩展配置.conf' << 'MMEOF'\n${content}\nMMEOF`;
        
        await exec(cmd);
        state.stealth = { ...state.stealth, ...stealthSettings };
        state.globalMountMode = stealthSettings.mount_mode;
        updateStatusUI();
        showToast(t('toast.saveSuccess'), 'success');
        await logOperation('保存隐身设置', `挂载模式: ${stealthSettings.mount_mode}, 隐身: ${stealthSettings.stealth_mode}, 随机ID: ${stealthSettings.randomize_id}`, true);
        updateLogStats(); // v3.5.1: 更新日志页面统计
        
    } catch (e) {
        console.error('Save stealth error:', e);
        showToast(t('toast.saveError'), 'error');
        await logOperation('保存隐身设置', '保存失败: ' + e.message, false);
    }
}

// ===== Module Operations =====
async function loadModules() {
    const listEl = document.getElementById('moduleList');
    const loadingEl = document.getElementById('modulesLoading');
    const emptyEl = document.getElementById('modulesEmpty');
    const pathEl = document.getElementById('modulePath');
    
    try {
        loadingEl.style.display = 'flex';
        emptyEl.style.display = 'none';
        
        // Remove old cards
        Array.from(listEl.children).forEach(child => {
            if (child !== loadingEl && child !== emptyEl) {
                child.remove();
            }
        });
        
        const script = `
            MOD_DIR="${MODULE_DIR}"
            for mod in "$MOD_DIR"/*; do
                [ -d "$mod" ] || continue
                MOD_NAME=$(basename "$mod")
                
                # Skip self module
                [ "$MOD_NAME" = "Magic-Mount-Metaverse" ] && continue
                
                # Read module.prop
                MOD_ID="$MOD_NAME"
                MOD_VERSION=""
                MOD_AUTHOR=""
                MOD_DESC=""
                MOD_META="0"
                DISABLED="0"
                SKIP="0"
                IGNORE="0"
                MOUNTED="0"
                HAS_SYSTEM="0"
                
                if [ -f "$mod/module.prop" ]; then
                    while IFS='=' read -r key value; do
                        case "$key" in
                            id) MOD_ID="$value" ;;
                            version) MOD_VERSION="$value" ;;
                            author) MOD_AUTHOR="$value" ;;
                            description) MOD_DESC="$value" ;;
                        esac
                    done < "$mod/module.prop"
                fi
                
                # Check flags
                [ -f "$mod/disable" ] || [ -f "$mod/remove" ] && DISABLED="1"
                [ -f "$mod/skip_mount" ] && SKIP="1"
                [ -f "$mod/ignore" ] && IGNORE="1"
                # Check for all supported partitions (system, vendor, odm, etc.)
                HAS_SYSTEM="0"
                for part in system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm; do
                    [ -e "$mod/$part" ] && HAS_SYSTEM="1" && break
                done
                
                # Check if metamodule
                [ -f "$mod/metamodule" ] || [ -d "$mod/system/metamodule" ] && MOD_META="1"
                
                # Output format: name|id|version|author|desc|meta|disabled|skip|ignore|hasSystem
                printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \
                    "$MOD_NAME" "$MOD_ID" "$MOD_VERSION" "$MOD_AUTHOR" "$MOD_DESC" \
                    "$MOD_META" "$DISABLED" "$SKIP" "$IGNORE" "$HAS_SYSTEM"
            done
        `;

        const { stdout } = await exec(script);
        const modules = stdout.trim().split('\n')
            .filter(line => line.trim())
            .map(line => {
                const parts = line.split('|');
                return {
                    name: parts[0] || '',
                    id: parts[1] || parts[0] || '',
                    version: parts[2] || '',
                    author: parts[3] || '',
                    description: parts[4] || '',
                    isMetamodule: parts[5] === '1',
                    disabled: parts[6] === '1',
                    skip: parts[7] === '1',
                    ignored: parts[8] === '1',
                    hasSystem: parts[9] === '1',
                    isHidden: parts[9] !== '1'
                };
            });

        state.modules = modules;
        state.moduleDetails = {};
        modules.forEach(m => {
            state.moduleDetails[m.id] = m;
        });
        
        updateModuleCount();
        loadingEl.style.display = 'none';
        
        const visibleModules = getVisibleModules();
        if (visibleModules.length === 0) {
            emptyEl.style.display = 'flex';
        } else {
            renderModules(visibleModules);
        }
        
        // v3.5.1: 模块加载完成后更新日志页面统计
        updateLogStats();

    } catch (e) {
        console.error('Load modules error:', e);
        loadingEl.style.display = 'none';
        emptyEl.style.display = 'flex';
        document.getElementById('moduleCount').textContent = '0';
    }
}

function getVisibleModules() {
    let modules = [...state.modules];
    
    // Filter by hidden status
    if (!state.showHidden) {
        modules = modules.filter(m => m.hasSystem);
    }
    
    return modules;
}

function updateModuleCount() {
    const visibleModules = getVisibleModules();
    const totalModules = state.modules.length;
    
    const countText = state.showHidden 
        ? `${visibleModules.length}/${totalModules}`
        : `${visibleModules.length}`;
    
    document.getElementById('moduleCount').textContent = countText;
}

function getModuleMountMode(moduleName) {
    // 如果模块有特定模式，返回该模式
    if (state.moduleModes[moduleName]) {
        return state.moduleModes[moduleName];
    }
    // 否则返回全局模式（不是"global"字符串）
    return state.globalMountMode;
}

function isForceMount(moduleName) {
    return state.forceMountModules[moduleName] === true;
}

function isCustomIgnored(moduleName) {
    return state.ignoredModules[moduleName] === 'ignore';
}

async function toggleCustomIgnore(moduleId) {
    try {
        const isNowIgnored = state.ignoredModules[moduleId] !== 'ignore';
        if (state.ignoredModules[moduleId] === 'ignore') {
            delete state.ignoredModules[moduleId];
        } else {
            state.ignoredModules[moduleId] = 'ignore';
        }
        
        await saveModuleSettings('ignored_modules', state.ignoredModules);
        loadModules();
        showToast(t('toast.ignoreSaved'), 'success');
        await logOperation('切换自定义忽略', `模块: ${moduleId}, ${isNowIgnored ? '启用' : '禁用'}忽略`, true);
        // loadModules() 会自动调用 updateLogStats()
        
    } catch (e) {
        console.error('Save ignore error:', e);
        showToast(t('toast.saveError'), 'error');
        await logOperation('切换自定义忽略', `模块: ${moduleId}, 失败: ${e.message}`, false);
    }
}

// v3.4.2: JSON save mechanism with heredoc
async function saveModuleSettings(settingName, data) {
    // Read existing config or create new
    let existingContent = '';
    try {
        const { stdout } = await exec(`cat '/data/adb/Metaverse/扩展配置.conf' 2>/dev/null || echo ""`);
        existingContent = stdout || '';
    } catch (e) {
        existingContent = '';
    }
    
    let lines = existingContent.split('\n');
    
    let found = false;
    const newLines = [];
    lines.forEach(line => {
        if (line.startsWith(settingName + '=')) {
            newLines.push(settingName + '=' + JSON.stringify(data));
            found = true;
        } else {
            newLines.push(line);
        }
    });
    
    if (!found) {
        newLines.push(settingName + '=' + JSON.stringify(data));
    }
    
    const content = newLines.join('\n');
    // v3.4.2: Use cat with heredoc for better compatibility
    const cmd = `mkdir -p '/data/adb/Metaverse' && cat > '/data/adb/Metaverse/扩展配置.conf' << 'MMEOF'\n${content}\nMMEOF`;
    await exec(cmd);
}

function renderModules(modules) {
    const listEl = document.getElementById('moduleList');
    
    modules.forEach((mod, index) => {
        const item = document.createElement('div');
        item.className = 'module-card';
        if (mod.isHidden) item.classList.add('hidden-type');
        item.dataset.moduleId = mod.id;
        item.style.animationDelay = `${index * 0.05}s`;
        
        const mountMode = getModuleMountMode(mod.id);
        const hasSpecificMode = !!state.moduleModes[mod.id];  // 是否有特定模式
        const modeClass = mountMode === 'overlayfs' ? 'overlayfs' : (mountMode === 'magic' ? 'magic' : 'global');
        const modeLabel = mountMode === 'overlayfs' ? t('modules.overlayfs') : (mountMode === 'magic' ? t('modules.magic') : t('modules.defaultMode'));
        // 判断按钮是否应该选中（模块有特定模式且匹配）
        const magicSelected = hasSpecificMode && mountMode === 'magic';
        const overlayfsSelected = hasSpecificMode && mountMode === 'overlayfs';
        
        const isForced = isForceMount(mod.id);
        const isIgnored = isCustomIgnored(mod.id);
        
        // v3.5.1 修复: 用户设置挂载模式后状态正确更新
        // Determine status - 根据用户设置和模块状态综合判断
        let statusClass = 'mounted';
        let statusText = t('modules.mounted');
        
        // 自定义忽略优先判断
        if (isIgnored) {
            statusClass = 'custom-ignored';
            statusText = t('modules.customIgnored');
        }
        // 用户设置了挂载模式或强制挂载，尝试挂载
        else if (hasSpecificMode || isForced) {
            // 有特定模式或强制挂载 - 显示尝试挂载状态
            if (mod.ignored) {
                statusClass = 'forced';
                statusText = t('modules.forceMounted');
            } else if (mod.skip) {
                statusClass = 'forced';
                statusText = t('logs.tryingMount');
            } else {
                statusClass = 'mounted';
                statusText = t('modules.mounted');
            }
        }
        // 原生ignore标记（无强制挂载）
        else if (mod.ignored) {
            statusClass = 'ignored';
            statusText = t('modules.ignored');
        }
        // skip_mount标记（无强制挂载）
        else if (mod.skip) {
            statusClass = 'unmounted';
            statusText = t('modules.unmounted');
        }
        // 隐藏模块（无system目录）
        else if (!mod.hasSystem) {
            statusClass = 'unmounted';
            statusText = t('modules.unmounted');
        }
        // 禁用状态
        else if (mod.disabled) {
            statusClass = 'unmounted';
            statusText = t('modules.unmounted');
        }
        
        let extraOptions = '';
        
        // Hidden module hint
        if (mod.isHidden && state.showHidden) {
            extraOptions += `
                <div style="margin-bottom:12px;padding:8px 12px;background:var(--md3-surface-variant);border-radius:8px;font-size:12px;color:var(--md3-on-surface-variant);">
                    <strong>${t('modules.hiddenModule')}</strong>: ${t('modules.hiddenModuleHint')}
                </div>
            `;
        }
        
        // skip_mount marker notice - 这些模块不应该被全局模式挂载
        if (mod.skip) {
            extraOptions += `
                <div class="force-mount-section">
                    <div class="ignore-notice" style="background:rgba(255,152,0,0.1);border-color:#FF9800;">
                        <svg viewBox="0 0 24 24" width="16" height="16"><path fill="#FF9800" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                        <span style="color:#FF9800;">${state.lang === 'zh' ? '包含skip_mount标记(原生)' : (state.lang === 'ja' ? 'skip_mountマーカーあり(ネイティブ)' : 'Has skip_mount marker (native)')}</span>
                    </div>
                    <button class="force-mount-btn ${isForced ? 'active' : ''}" 
                            onclick="toggleForceMount('${escapeHtml(mod.id)}')">
                        <svg viewBox="0 0 24 24" width="18" height="18">
                            <path fill="currentColor" d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
                        </svg>
                        ${isForced ? (state.lang === 'zh' ? '取消强制' : (state.lang === 'ja' ? '強制解除' : 'Remove Force')) : (state.lang === 'zh' ? '强制挂载' : (state.lang === 'ja' ? '強制マウント' : 'Force Mount'))}
                    </button>
                    ${isForced ? `<div class="force-hint">${state.lang === 'zh' ? '此模块有skip_mount标记但已启用强制挂载' : (state.lang === 'ja' ? 'このモジュールにはskip_mountマーカーがありますが強制マウントが有効です' : 'This module has skip_mount marker but force mount is enabled')}</div>` : ''}
                </div>
            `;
        }
        
        // Native ignore marker (if exists)
        if (mod.ignored) {
            extraOptions += `
                <div class="force-mount-section">
                    <div class="ignore-notice">
                        <svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                        <span>${t('modules.ignoreMarker')}</span>
                    </div>
                    <button class="force-mount-btn ${isForced ? 'active' : ''}" 
                            onclick="toggleForceMount('${escapeHtml(mod.id)}')">
                        <svg viewBox="0 0 24 24" width="18" height="18">
                            <path fill="currentColor" d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
                        </svg>
                        ${isForced ? t('modules.unforceMount') : t('modules.forceMount')}
                    </button>
                    ${isForced ? `<div class="force-hint">${t('modules.ignoreHint')}</div>` : ''}
                </div>
            `;
        }
        
        // Custom Ignore Option (shown for all modules)
        extraOptions += `
            <div class="ignore-option">
                <div class="ignore-option-header">
                    <span class="ignore-option-label">${t('modules.customIgnore')}</span>
                    <label class="module-toggle-switch">
                        <input type="checkbox" ${isIgnored ? 'checked' : ''} 
                               onchange="toggleCustomIgnore('${escapeHtml(mod.id)}')">
                        <span class="module-toggle-slider"></span>
                    </label>
                </div>
                <div class="ignore-option-hint">${t('modules.customIgnoreDesc')}</div>
            </div>
        `;
        
        // Force Mount Option (only for non-ignored modules)
        if (!mod.ignored) {
            extraOptions += `
                <div class="force-mount-section" style="margin-top:12px;">
                    <div style="display:flex;align-items:center;justify-content:space-between;">
                        <div>
                            <div style="font-size:13px;font-weight:500;">${t('modules.forceMount')}</div>
                            <div style="font-size:11px;color:var(--md3-on-surface-variant);margin-top:2px;">${t('modules.forceMountDesc')}</div>
                        </div>
                        <button class="force-mount-btn ${isForced ? 'active' : ''}" 
                                style="padding:8px 16px;font-size:13px;"
                                onclick="toggleForceMount('${escapeHtml(mod.id)}')">
                            <svg viewBox="0 0 24 24" width="18" height="18">
                                <path fill="currentColor" d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
                            </svg>
                            ${isForced ? t('modules.unforceMount') : t('modules.forceMount')}
                        </button>
                    </div>
                </div>
            `;
        }
        
        item.innerHTML = `
            <div class="module-card-header" onclick="toggleModuleCard('${escapeHtml(mod.id)}')">
                <div class="module-card-icon">
                    <svg viewBox="0 0 24 24" width="24" height="24">
                        <path fill="currentColor" d="M20 6h-8l-2-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2z"/>
                    </svg>
                </div>
                <div class="module-card-info">
                    <div class="module-card-name">${escapeHtml(mod.name)}</div>
                    <div class="module-card-meta">
                        <span>${escapeHtml(mod.id)}</span>
                        ${mod.version ? `<span>v${escapeHtml(mod.version)}</span>` : ''}
                        <span class="module-card-badge ${statusClass}">${statusText}</span>
                    </div>
                </div>
                <div class="module-card-expand">
                    <svg viewBox="0 0 24 24" width="24" height="24">
                        <path fill="currentColor" d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z"/>
                    </svg>
                </div>
            </div>
            <div class="module-card-body">
                <div class="module-card-desc">${escapeHtml(mod.description) || '-'}</div>
                ${mod.author ? `<div style="font-size:12px;color:var(--md3-on-surface-variant);margin-bottom:12px;">Author: ${escapeHtml(mod.author)}</div>` : ''}
                
                ${extraOptions}
                
                <div class="module-card-section">
                    <div class="module-card-section-title">${t('modules.mountMode')}</div>
                    ${isIgnored ? `<div style="padding:12px;background:var(--md3-surface-variant);border-radius:8px;font-size:13px;color:var(--md3-on-surface-variant);text-align:center;">${state.lang === 'zh' ? '已启用自定义忽略，挂载模式已锁定' : (state.lang === 'ja' ? 'カスタム無視が有効、マウントモードはロックされています' : 'Custom ignore enabled, mount mode locked')}</div>` : `
                    <div class="module-card-strategy">
                        <button class="strategy-btn ${magicSelected ? 'selected' : ''}" 
                                ${isIgnored ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''}
                                onclick="setModuleMode('${escapeHtml(mod.id)}', 'magic')">
                            <div class="strategy-btn-title">${t('modules.magic')}</div>
                            <div class="strategy-btn-sub">${t('modules.magicDesc')}</div>
                        </button>
                        <button class="strategy-btn ${overlayfsSelected ? 'selected' : ''}" 
                                ${isIgnored ? 'disabled style="opacity:0.5;pointer-events:none;"' : ''}
                                onclick="setModuleMode('${escapeHtml(mod.id)}', 'overlayfs')">
                            <div class="strategy-btn-title">${t('modules.overlayfs')}</div>
                            <div class="strategy-btn-sub">${t('modules.overlayDesc')}</div>
                        </button>
                    </div>
                    <div style="font-size:11px;color:var(--md3-on-surface-variant);margin-top:8px;">
                        ${hasSpecificMode ? '' : `<span style="color:var(--md3-outline);">[${t('modules.defaultMode')}]</span> `}<span class="mode-indicator ${modeClass}">${modeLabel}</span>
                    </div>
                    `}
                </div>
            </div>
        `;
        
        listEl.appendChild(item);
    });
}

function toggleModuleCard(moduleId) {
    const card = document.querySelector(`.module-card[data-module-id="${moduleId}"]`);
    if (card) {
        if (state.expandedModule === moduleId) {
            card.classList.remove('expanded');
            state.expandedModule = null;
        } else {
            document.querySelectorAll('.module-card.expanded').forEach(c => {
                c.classList.remove('expanded');
            });
            card.classList.add('expanded');
            state.expandedModule = moduleId;
        }
    }
}

async function setModuleMode(moduleId, mode) {
    // If clicking the same mode that's already selected, toggle it off (back to global)
    const isRemovingMode = state.moduleModes[moduleId] === mode;
    if (isRemovingMode) {
        delete state.moduleModes[moduleId];
        mode = state.globalMountMode;  // 回到全局模式
    } else {
        state.moduleModes[moduleId] = mode;
    }
    
    try {
        await saveModuleSettings('module_mount_modes', state.moduleModes);
        
        const card = document.querySelector(`.module-card[data-module-id="${moduleId}"]`);
        if (card) {
            const btns = card.querySelectorAll('.strategy-btn');
            const hasSpecificMode = !!state.moduleModes[moduleId];
            btns.forEach(btn => {
                btn.classList.remove('selected');
                // Check if this button matches the current mode
                const btnMode = btn.getAttribute('onclick')?.match(/setModuleMode\([^,]+,\s*'([^']+)'/)?.[1];
                // 只有模块有特定模式时才选中按钮
                if (hasSpecificMode && btnMode === mode) {
                    btn.classList.add('selected');
                }
            });
            
            const indicator = card.querySelector('.mode-indicator');
            if (indicator) {
                indicator.className = `mode-indicator ${mode === 'overlayfs' ? 'overlayfs' : 'magic'}`;
                indicator.textContent = mode === 'overlayfs' ? t('modules.overlayfs') : t('modules.magic');
            }
        }
        
        showToast(t('toast.modeSaved'), 'success');
        await logOperation('设置模块挂载模式', `模块: ${moduleId}, 模式: ${isRemovingMode ? '恢复全局' : mode}`, true);
        updateLogStats(); // v3.5.1: 更新日志页面统计
        
    } catch (e) {
        console.error('Save module mode error:', e);
        showToast(t('toast.saveError'), 'error');
        await logOperation('设置模块挂载模式', `模块: ${moduleId}, 失败: ${e.message}`, false);
    }
}

async function toggleForceMount(moduleId) {
    try {
        const isNowForced = state.forceMountModules[moduleId] !== true;
        if (state.forceMountModules[moduleId] === true) {
            delete state.forceMountModules[moduleId];
        } else {
            state.forceMountModules[moduleId] = true;
        }
        
        await saveModuleSettings('force_mount_modules', state.forceMountModules);
        loadModules();
        showToast(t('toast.forceSaved'), 'success');
        await logOperation('切换强制挂载', `模块: ${moduleId}, ${isNowForced ? '启用' : '禁用'}强制挂载`, true);
        // loadModules() 会自动调用 updateLogStats()
        
    } catch (e) {
        console.error('Save force mount error:', e);
        showToast(t('toast.saveError'), 'error');
        await logOperation('切换强制挂载', `模块: ${moduleId}, 失败: ${e.message}`, false);
    }
}

// ===== Show/Hide Hidden Modules =====
function toggleShowHidden() {
    state.showHidden = !state.showHidden;
    
    const btn = document.getElementById('showHiddenBtn');
    if (btn) {
        if (state.showHidden) {
            btn.classList.add('active');
            btn.innerHTML = `
                <svg viewBox="0 0 24 24" width="20" height="20">
                    <path fill="currentColor" d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
                </svg>
                ${t('modules.hideHidden')}
            `;
        } else {
            btn.classList.remove('active');
            btn.innerHTML = `
                <svg viewBox="0 0 24 24" width="20" height="20">
                    <path fill="currentColor" d="M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.26-.36 1.83l2.92 2.92c1.51-1.26 2.7-2.89 3.43-4.75-1.73-4.39-6-7.5-11-7.5-1.4 0-2.74.25-3.98.7l2.16 2.16C10.74 7.13 11.35 7 12 7zM2 4.27l2.28 2.28.46.46C3.08 8.3 1.78 10.02 1 12c1.73 4.39 6 7.5 11 7.5 1.55 0 3.03-.3 4.38-.84l.42.42L19.73 22 21 20.73 3.27 3 2 4.27zM7.53 9.8l1.55 1.55c-.05.21-.08.43-.08.65 0 1.66 1.34 3 3 3 .22 0 .44-.03.65-.08l1.55 1.55c-.67.33-1.41.53-2.2.53-2.76 0-5-2.24-5-5 0-.79.2-1.53.53-2.2zm4.31-.78l3.15 3.15.02-.16c0-1.66-1.34-3-3-3l-.17.01z"/>
                </svg>
                ${t('modules.showHidden')}
            `;
        }
    }
    
    updateModuleCount();
    loadModules();
}

// ===== System Info =====
async function updateSystemInfo() {
    try {
        // Get Android version
        const androidScript = `getprop ro.build.version.release 2>/dev/null || echo "-"`;
        const { stdout: android } = await exec(androidScript);
        document.getElementById('androidVersion').textContent = android.trim() || '-';
        
        // Get Kernel version
        const kernelScript = `uname -r 2>/dev/null || uname -v 2>/dev/null || echo "-"`;
        const { stdout: kernel } = await exec(kernelScript);
        const kernelText = kernel.trim();
        // Shorten kernel version if too long
        document.getElementById('kernelVersion').textContent = kernelText.length > 25 ? kernelText.substring(0, 22) + '...' : (kernelText || '-');
        
        // Get Device model
        const deviceScript = `getprop ro.product.model 2>/dev/null || getprop ro.product.device 2>/dev/null || echo "-"`;
        const { stdout: device } = await exec(deviceScript);
        document.getElementById('deviceModel').textContent = device.trim() || '-';
        
    } catch (e) {
        console.error('Update system info error:', e);
    }
}

// ===== Status Updates =====
// v3.4.1-fixed-v6: Ensure global mount mode is displayed correctly
function updateStatusUI() {
    const mountStatus = document.getElementById('mountStatus');
    if (mountStatus) {
        const modeText = state.globalMountMode === 'overlayfs' ? 'OverlayFS' : 
                         state.globalMountMode === 'magic' ? 'Magic' : 
                         'Magic';
        mountStatus.textContent = modeText;
        mountStatus.style.color = state.globalMountMode === 'overlayfs' ? 'var(--md3-tertiary)' : 'var(--md3-primary)';
    }

    const stealthStatus = document.getElementById('stealthStatus');
    if (stealthStatus) {
        if (state.stealth.stealth_mode) {
            stealthStatus.textContent = state.stealth.randomize_id ? 'Full' : 'Active';
            stealthStatus.style.color = 'var(--md3-tertiary)';
        } else {
            stealthStatus.textContent = 'Disabled';
            stealthStatus.style.color = 'var(--md3-outline)';
        }
    }
    
    // v3.4.1-fixed-v6: Also update the settings dropdown to sync
    const mountModeSelect = document.getElementById('globalMountMode');
    if (mountModeSelect) {
        mountModeSelect.value = state.globalMountMode;
    }
}

// ===== Tab Navigation =====
function initTabs() {
    const navTabs = document.querySelectorAll('.nav-tab');
    const tabPanels = document.querySelectorAll('.tab-panel');
    
    navTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;
            navTabs.forEach(t => t.classList.remove('active'));
            tabPanels.forEach(p => p.classList.remove('active'));
            tab.classList.add('active');
            document.getElementById(`${tabName}Panel`).classList.add('active');
            
            if (tabName === 'modules') {
                loadModules();
            } else if (tabName === 'logs') {
                // v3.5.1: 切换到日志页面时更新统计
                updateLogStats();
                load_logs();
            }
        });
    });
}

// ===== Event Listeners =====
function initEventListeners() {
    // Theme toggle
    document.getElementById('themeToggle').addEventListener('click', toggleTheme);
    
    // Language dropdown
    initLangDropdown();
    
    // Config save
    document.getElementById('saveConfig').addEventListener('click', saveConfig);
    
    // Partition selection
    document.getElementById('partitionSelect').addEventListener('click', showPartitionSelector);
    
    // Module reload
    document.getElementById('reloadModules').addEventListener('click', loadModules);
    
    // Show hidden modules toggle
    document.getElementById('showHiddenBtn').addEventListener('click', toggleShowHidden);
    
    // Stealth settings save
    document.getElementById('saveStealth').addEventListener('click', saveStealth);
    
    // Global mount mode change listener - v3.4.1-fixed-v6: Update immediately
    const globalMountModeSelect = document.getElementById('globalMountMode');
    if (globalMountModeSelect) {
        globalMountModeSelect.addEventListener('change', (e) => {
            // Immediately update state for UI consistency
            state.globalMountMode = e.target.value;
            updateStatusUI();
        });
    }
}

// ===== Initialization =====
async function init() {
    console.log('Magic Mount Metaverse v3.5.1 initializing...');
    
    // Initialize theme
    initTheme();
    
    // Initialize tabs
    initTabs();
    
    // Initialize event listeners
    initEventListeners();
    
    // Initialize help icons
    initHelpIcons();
    
    // Load config
    await loadConfig();
    
    // Load stealth/settings
    await loadStealth();
    
    // Load modules
    await loadModules();
    
    // Update system info
    await updateSystemInfo();
    
    // Update status UI
    updateStatusUI();
    
    // Update i18n
    updateI18n();
    
    console.log('Initialization complete');
}

// Start
document.addEventListener('DOMContentLoaded', init);
