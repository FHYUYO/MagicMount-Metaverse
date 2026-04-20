/**
 * Magic Mount Metaverse v3.0 - Material Design 3 UI
 * Module Identification & Dual Mount Mode Support
 * Lemon Gradient Theme + Help System + Full i18n
 * Version: v3.0
 */

// ===== Configuration =====
const CONFIG_PATH = '/data/adb/magic_mount/mm.conf';
const EXTENDED_CONFIG_PATH = '/data/adb/magic_mount/mm_extended.conf';
const AOK_PATH = '/data/adb/metamodule/aok';
const MODULE_DIR = '/data/adb/modules';

// ===== State =====
const state = {
    theme: localStorage.getItem('mm-theme') || 'dark',
    lang: localStorage.getItem('mm-lang') || 'en',
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
    expandedModule: null
};

// ===== Translations (Full i18n) =====
const i18n = {
    en: {
        status: { mount: 'Mount', stealth: 'Stealth', modules: 'Modules' },
        metrics: { cpu: 'CPU', memory: 'Memory', disk: 'Disk' },
        tabs: { config: 'Config', modules: 'Modules', logs: 'Logs', settings: 'Settings' },
        config: {
            title: 'Configuration',
            moduleDir: 'Module Directory',
            logFile: 'Log File',
            mountSource: 'Mount Source',
            debug: 'Debug Mode',
            umount: 'Enable Unmount',
            partitions: 'Extra Partitions',
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
            id: 'ID',
            version: 'Version',
            description: 'Description',
            status: 'Status',
            mounted: 'Mounted',
            unmounted: 'Unmounted',
            defaultMode: 'Default Mode',
            searchPlaceholder: 'Search modules...',
            reload: 'Reload',
            save: 'Save Changes',
            saving: 'Saving...',
            saveSuccess: 'Changes saved successfully',
            magicDesc: 'Magic mode uses a single directory for mounting',
            overlayDesc: 'OverlayFS mode uses dual directory for better isolation'
        },
        logs: { title: 'Logs', current: 'Current', old: 'Old', refresh: 'Refresh', empty: 'No logs available', loading: 'Loading...' },
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
        toast: { loadSuccess: 'Configuration loaded', loadError: 'Failed to load config', saveSuccess: 'Saved successfully', saveError: 'Save failed', modeSaved: 'Mount mode saved' },
        dialog: { help: 'Help', cancel: 'Close', confirm: 'OK' }
    },
    zh: {
        status: { mount: '挂载', stealth: '隐身', modules: '模块' },
        metrics: { cpu: 'CPU', memory: '内存', disk: '磁盘' },
        tabs: { config: '配置', modules: '模块', logs: '日志', settings: '设置' },
        config: {
            title: '配置',
            moduleDir: '模块目录',
            logFile: '日志文件',
            mountSource: '挂载源',
            debug: '调试模式',
            umount: '启用卸载',
            partitions: '额外分区',
            pathLabel: '配置路径'
        },
        modules: { 
            title: '模块', 
            loading: '正在加载模块...', 
            empty: '未找到模块',
            emptyHint: '模块目录中未找到模块',
            path: '路径',
            mountMode: '挂载模式',
            magic: 'Magic模式',
            overlayfs: 'OverlayFS模式',
            id: 'ID',
            version: '版本',
            description: '描述',
            status: '状态',
            mounted: '已挂载',
            unmounted: '未挂载',
            defaultMode: '默认模式',
            searchPlaceholder: '搜索模块...',
            reload: '刷新',
            save: '保存更改',
            saving: '保存中...',
            saveSuccess: '更改已保存',
            magicDesc: 'Magic模式使用单目录挂载',
            overlayDesc: 'OverlayFS模式使用双目录隔离'
        },
        logs: { title: '日志', current: '当前', old: '旧日志', refresh: '刷新', empty: '暂无日志', loading: '加载中...' },
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
        toast: { loadSuccess: '配置已加载', loadError: '加载配置失败', saveSuccess: '保存成功', saveError: '保存失败', modeSaved: '挂载模式已保存' },
        dialog: { help: '帮助', cancel: '关闭', confirm: '确定' }
    },
    ja: {
        status: { mount: 'マウント', stealth: 'ステルス', modules: 'モジュール' },
        metrics: { cpu: 'CPU', memory: 'メモリ', disk: 'ディスク' },
        tabs: { config: '設定', modules: 'モジュール', logs: 'ログ', settings: '設定' },
        config: {
            title: '設定',
            moduleDir: 'モジュールディレクトリ',
            logFile: 'ログファイル',
            mountSource: 'マウントソース',
            debug: 'デバッグモード',
            umount: 'アンマウント有効',
            partitions: '拡張パーティション',
            pathLabel: '設定パス'
        },
        modules: { 
            title: 'モジュール', 
            loading: 'モジュール読み込み中...', 
            empty: 'モジュールが見つかりません',
            emptyHint: 'モジュールディレクトリにモジュールが見つかりません',
            path: 'パス',
            mountMode: 'マウントモード',
            magic: 'Magic',
            overlayfs: 'OverlayFS',
            id: 'ID',
            version: 'バージョン',
            description: '説明',
            status: 'ステータス',
            mounted: 'マウント済み',
            unmounted: '未マウント',
            defaultMode: 'デフォルトモード',
            searchPlaceholder: 'モジュールを検索...',
            reload: '再読み込み',
            save: '変更を保存',
            saving: '保存中...',
            saveSuccess: '変更が保存されました',
            magicDesc: 'Magicモードは単一ディレクトリを使用',
            overlayDesc: 'OverlayFSモードは二重ディレクトリを使用'
        },
        logs: { title: 'ログ', current: '現在', old: '旧ログ', refresh: '更新', empty: 'ログがありません', loading: '読み込み中...' },
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
        btn: { reload: '再読み込み', save: '保存', apply: '適用', close: '閉じる' },
        toast: { loadSuccess: '設定を読み込みました', loadError: '設定の読み込みに失敗', saveSuccess: '保存しました', saveError: '保存に失敗', modeSaved: 'マウントモードを保存しました' },
        dialog: { help: 'ヘルプ', cancel: '閉じる', confirm: 'OK' }
    }
};

// ===== Help Content (Full) =====
const helpContent = {
    en: {
        moduleDir: 'Specifies the directory where modules are located. Default is /data/adb/modules. Changing this may affect module mounting.',
        logFile: 'Path to the log file where mount operations are recorded. Useful for debugging mount issues.',
        mountSource: 'Select the kernel-level framework: KSU (KernelSU) or APatch. This determines how modules are mounted.',
        debug: 'Enables verbose logging for troubleshooting. Increases log output but helps diagnose issues.',
        umount: 'Allows modules to be properly unmounted on reboot. Disable only if you need persistent mounts.',
        partitions: 'Additional system partitions to mount (comma-separated). Advanced option for custom setups.',
        stealthEnable: 'Enables stealth mode to hide the presence of mount operations from detection tools.',
        randomId: 'Randomizes module IDs to prevent apps from detecting specific module fingerprints.',
        hideLogs: 'Prevents mount operations from appearing in system logs. Reduces detectability.',
        hideFromList: 'Hides modules from Magisk Manager module list. Visual stealth option.',
        optLevel: 'Optimization level affects mount speed vs compatibility: Disabled (standard), Fast (reduced wait), Ultra (per-module processing).',
        mountDelay: 'Delay in milliseconds before mounting starts. Some devices need delay for proper initialization.',
        parallelMount: 'Mount multiple modules simultaneously instead of sequentially. Faster but may cause issues on some devices.',
        globalMountMode: 'Global mount mode applies to all modules unless overridden: Magic (standard single-directory), OverlayFS (dual-directory for better isolation).',
        magicMode: 'Magic mode uses a single directory for mounting. Standard and widely compatible.',
        overlayfsMode: 'OverlayFS mode separates metadata and content into different directories. Better for complex module interactions.'
    },
    zh: {
        moduleDir: '指定模块所在目录。默认为 /data/adb/modules。修改可能影响模块挂载。',
        logFile: '记录挂载操作的日志文件路径。用于调试挂载问题。',
        mountSource: '选择内核级框架：KSU (KernelSU) 或 APatch。决定模块如何挂载。',
        debug: '启用详细日志记录以便故障排除。增加日志输出但有助于诊断问题。',
        umount: '允许模块在重启时正确卸载。仅在需要持久挂载时禁用。',
        partitions: '要挂载的额外系统分区（逗号分隔）。高级选项。',
        stealthEnable: '启用隐身模式，从检测工具隐藏挂载操作的存在。',
        randomId: '随机化模块ID，防止应用检测特定模块指纹。',
        hideLogs: '阻止挂载操作出现在系统日志中。降低可检测性。',
        hideFromList: '在 Magisk Manager 模块列表中隐藏模块。视觉隐身选项。',
        optLevel: '优化级别影响挂载速度与兼容性：禁用（标准）、快速（减少等待）、极致（逐模块处理）。',
        mountDelay: '挂载开始前的延迟毫秒数。部分设备需要延迟以正确初始化。',
        parallelMount: '同时挂载多个模块而非顺序挂载。更快但可能在某些设备上出问题。',
        globalMountMode: '全局挂载模式应用于所有模块（除非单独覆盖）：Magic（标准单目录）、OverlayFS（双目录更好隔离）。',
        magicMode: 'Magic模式使用单个目录挂载。标准且广泛兼容。',
        overlayfsMode: 'OverlayFS模式将元数据和内容分离到不同目录。更适合复杂模块交互。'
    },
    ja: {
        moduleDir: 'モジュールが存在するディレクトリを指定します。デフォルトは/data/adb/modules。変更するとマウントに影響する可能性があります。',
        logFile: 'マウント操作が記録されるログファイルのパス。デバッグに便利です。',
        mountSource: 'カーネルレベルフレームワークを選択：KSU (KernelSU) または APatch。モジュールのマウント方法が決まります。',
        debug: 'トラブルシューティング用に詳細ログを有効にします。ログ出力が増えますが、問題の診断に役立ちます。',
        umount: '再起動時にモジュールが適切にアンマウントされることを許可します。永続マウントが必要な場合のみ無効にしてください。',
        partitions: 'マウントする追加システムパーティション（カンマ区切り）。高度なオプションです。',
        stealthEnable: '検出ツールからマウント操作の存在を非表示にするステルスモードを有効にします。',
        randomId: 'モジュールIDをランダム化して、アプリが特定のモジュールフィンガープリントを検出することを防ぎます。',
        hideLogs: 'マウント操作がシステムログに表示されるのを防ぎます。検出可能性が低下します。',
        hideFromList: 'Magisk Managerのモジュールリストからモジュールを非表示にします。視覚的なステルスオプション。',
        optLevel: '最適化レベルはマウント速度と互換性に影響します：無効（標準）、高速（待機減少）、ウルトラ（モジュールごと処理）。',
        mountDelay: 'マウント開始前の遅延（ミリ秒）。一部のデバイスでは適切な初期化に遅延が必要です。',
        parallelMount: '複数のモジュールを同時にマウントします。高速ですが、一部のデバイスで問題を起こす可能性があります。',
        globalMountMode: 'グローバルマウントモードは全モジュールに適用：Magic（標準単一ディレクトリ）、OverlayFS（分離用デュアルディレクトリ）。',
        magicMode: 'Magicモードは単一ディレクトリを使用してマウントします。標準的で広く互換性があります。',
        overlayfsMode: 'OverlayFSモードはメタデータとコンテンツを別のディレクトリに分離します。複雑なモジュール相互作用に適しています。'
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
    document.getElementById('langCode').textContent = state.lang.toUpperCase();
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
    const content = helpContent[lang]?.[key] || helpContent.en[key] || 'No help available for this item.';
    showDialog(t('dialog.help'), `<p class="help-text">${content}</p>`, { icon: 'help', showCancel: false, confirmText: t('dialog.confirm') });
}

function createHelpIcon(key) {
    const icon = document.createElement('span');
    icon.className = 'help-icon';
    icon.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16"><path fill="currentColor" d="M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5 0-2.21-1.79-4-4-4z"/></svg>';
    icon.addEventListener('click', (e) => {
        e.stopPropagation();
        showHelp(key);
    });
    return icon;
}

function initHelpIcons() {
    // Config Tab
    addHelpIcon('#moduleDir', 'moduleDir');
    addHelpIcon('#logFile', 'logFile');
    addHelpIcon('#mountSource', 'mountSource');
    addHelpIcon('#debugMode', 'debug', true);
    addHelpIcon('#umountMode', 'umount', true);
    addHelpIcon('#partitions', 'partitions');
    
    // Settings Tab (Stealth)
    addHelpIcon('#stealthMode', 'stealthEnable', true);
    addHelpIcon('#randomizeId', 'randomId', true);
    addHelpIcon('#hideMountLogs', 'hideLogs', true);
    addHelpIcon('#hideFromList', 'hideFromList', true);
    addHelpIcon('#globalMountMode', 'globalMountMode');
    addHelpIcon('#optLevel', 'optLevel');
    addHelpIcon('#mountDelay', 'mountDelay');
    addHelpIcon('#parallelMount', 'parallelMount', true);
    
    // Mode hint
    const modeHint = document.querySelector('.mode-hint');
    if (modeHint && !modeHint.querySelector('.help-icon')) {
        modeHint.appendChild(createHelpIcon('globalMountMode'));
    }
}

function addHelpIcon(selector, helpKey, isToggle = false) {
    const element = document.querySelector(selector);
    if (!element) return;
    
    const field = isToggle ? element.closest('.toggle-field') : element.closest('.text-field');
    if (field && !field.querySelector('.help-icon')) {
        field.style.position = 'relative';
        field.appendChild(createHelpIcon(helpKey));
    }
}

// ===== Theme & Language =====
function initTheme() {
    document.documentElement.setAttribute('data-theme', state.theme);
    const icon = document.querySelector('.icon-theme');
    if (icon) {
        icon.innerHTML = state.theme === 'dark' 
            ? '<path fill="currentColor" d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"/>'
            : '<path fill="currentColor" d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37c-.39-.39-1.03-.39-1.41 0-.39.39-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0 .39-.39.39-1.03 0-1.41l-1.06-1.06zm1.06-10.96c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06zM7.05 18.36c.39-.39.39-1.03 0-1.41-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06z"/>';
    }
}

function toggleTheme() {
    state.theme = state.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('mm-theme', state.theme);
    initTheme();
}

function initLangDropdown() {
    const dropdown = document.getElementById('langMenu');
    const langBtn = document.getElementById('langBtn');
    const langCode = document.getElementById('langCode');
    
    if (!dropdown || !langBtn) return;

    langCode.textContent = state.lang.toUpperCase();
    
    dropdown.querySelectorAll('.lang-option').forEach(opt => {
        if (opt.dataset.lang === state.lang) {
            opt.classList.add('active');
        }
        opt.addEventListener('click', () => {
            state.lang = opt.dataset.lang;
            localStorage.setItem('mm-lang', state.lang);
            langCode.textContent = state.lang.toUpperCase();
            dropdown.querySelectorAll('.lang-option').forEach(o => o.classList.remove('active'));
            opt.classList.add('active');
            dropdown.classList.remove('active');
            updateI18n();
            loadConfig();
            loadStealth();
            loadModules();
        });
    });

    langBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.classList.toggle('active');
    });

    document.addEventListener('click', (e) => {
        if (!dropdown.contains(e.target) && !langBtn.contains(e.target)) {
            dropdown.classList.remove('active');
        }
    });
}

// ===== Config Operations =====
async function loadConfig() {
    try {
        const { stdout } = await exec(`cat "${CONFIG_PATH}" 2>/dev/null || echo ""`);
        const lines = stdout.split('\n');
        
        state.config = {
            module_dir: '/data/adb/modules',
            log_file: '/data/adb/magic_mount/mm.log',
            mount_source: 'KSU',
            debug: false,
            umount: true,
            partitions: ''
        };

        lines.forEach(line => {
            line = line.trim();
            if (!line || line.startsWith('#')) return;
            const [key, ...valueParts] = line.split('=');
            const value = valueParts.join('=').trim();
            if (!key) return;
            
            switch (key.trim()) {
                case 'module_dir': state.config.module_dir = value; break;
                case 'log_file': state.config.log_file = value; break;
                case 'mount_source': state.config.mount_source = value; break;
                case 'debug': state.config.debug = parseBool(value); break;
                case 'umount': state.config.umount = parseBool(value); break;
                case 'partitions': state.config.partitions = value; break;
            }
        });

        try {
            const { stdout: aokData } = await exec(`cat "${AOK_PATH}" 2>/dev/null || echo ""`);
            if (aokData.includes('APATCH')) {
                state.config.isApatch = true;
            }
        } catch {}

        updateConfigUI();
        updateStatusUI();
        
        document.getElementById('configPath').textContent = `${t('config.pathLabel')}: ${CONFIG_PATH}`;
        
    } catch (e) {
        console.error('Load config error:', e);
        showToast(t('toast.loadError'), 'error');
    }
}

function updateConfigUI() {
    const c = state.config;
    document.getElementById('moduleDir').value = c.module_dir || '/data/adb/modules';
    document.getElementById('logFile').value = c.log_file || '/data/adb/magic_mount/mm.log';
    document.getElementById('mountSource').value = c.mount_source || 'KSU';
    document.getElementById('debugMode').checked = c.debug || false;
    document.getElementById('umountMode').checked = c.umount !== false;
    document.getElementById('partitions').value = c.partitions || '';
}

async function saveConfig() {
    try {
        const config = {
            module_dir: document.getElementById('moduleDir').value,
            log_file: document.getElementById('logFile').value,
            mount_source: document.getElementById('mountSource').value,
            debug: document.getElementById('debugMode').checked,
            umount: document.getElementById('umountMode').checked,
            partitions: document.getElementById('partitions').value
        };

        const lines = [
            '# ===== Magic Mount Metaverse v3.0 =====',
            '# Author: GitHub@FHYUYO/酷安@枫原羽悠',
            '# Version: v3.0',
            '',
            '# ====== Core Settings ======',
            `module_dir=${config.module_dir}`,
            `mount_source=${config.mount_source}`,
            `log_file=${config.log_file}`,
            `debug=${config.debug}`,
            '',
            '# ====== Unmount Settings ======',
            `umount=${config.umount}`,
            '',
            '# ====== Extended Partitions ======',
            `partitions=${config.partitions}`
        ];

        const content = lines.join('\n').replace(/'/g, "'\\''");
        const cmd = `mkdir -p "$(dirname '${CONFIG_PATH}')" && printf '%s\n' '${content}' > '${CONFIG_PATH}'`;
        
        await exec(cmd);
        state.config = { ...state.config, ...config };
        showToast(t('toast.saveSuccess'), 'success');
        
    } catch (e) {
        console.error('Save config error:', e);
        showToast(t('toast.saveError'), 'error');
    }
}

// ===== Stealth/Settings Operations =====
async function loadStealth() {
    try {
        const { stdout } = await exec(`cat "${EXTENDED_CONFIG_PATH}" 2>/dev/null || echo ""`);
        const lines = stdout.split('\n');
        
        state.stealth = {
            stealth_mode: false,
            randomize_id: false,
            hide_mount_logs: false,
            hide_from_list: false,
            optimization_level: '0',
            mount_delay: '0',
            parallel_mount: false,
            mount_mode: 'magic',
            module_mount_modes: '{}'
        };

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
                case 'mount_mode': state.stealth.mount_mode = value; break;
                case 'module_mount_modes': state.stealth.module_mount_modes = value; break;
            }
        });

        state.globalMountMode = state.stealth.mount_mode || 'magic';
        state.moduleModes = parseModuleModes(state.stealth.module_mount_modes);

        updateStealthUI();
        updateStatusUI();
        
    } catch (e) {
        console.error('Load stealth error:', e);
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

async function saveStealth() {
    try {
        const { stdout } = await exec(`cat "${EXTENDED_CONFIG_PATH}" 2>/dev/null || echo ""`);
        
        const stealthSettings = {
            stealth_mode: document.getElementById('stealthMode').checked,
            randomize_id: document.getElementById('randomizeId').checked,
            hide_mount_logs: document.getElementById('hideMountLogs').checked,
            hide_from_list: document.getElementById('hideFromList').checked,
            optimization_level: document.getElementById('optLevel').value,
            mount_delay: document.getElementById('mountDelay').value,
            parallel_mount: document.getElementById('parallelMount').checked,
            mount_mode: document.getElementById('globalMountMode')?.value || 'magic',
            module_mount_modes: JSON.stringify(state.moduleModes)
        };

        const lines = stdout.split('\n');
        const newLines = [];
        let foundSection = false;
        
        lines.forEach(line => {
            if (line.includes('Stealth Settings') || line.includes('Mount Mode Settings')) {
                foundSection = true;
            }
            if (!foundSection) {
                newLines.push(line);
            }
        });

        newLines.push('');
        newLines.push('# ====== Stealth Settings (v3.0) ======');
        newLines.push(`stealth_mode=${stealthSettings.stealth_mode}`);
        newLines.push(`randomize_id=${stealthSettings.randomize_id}`);
        newLines.push(`hide_mount_logs=${stealthSettings.hide_mount_logs}`);
        newLines.push(`hide_from_list=${stealthSettings.hide_from_list}`);
        newLines.push('');
        newLines.push('# ====== Mount Mode Settings ======');
        newLines.push(`mount_mode=${stealthSettings.mount_mode}`);
        newLines.push(`module_mount_modes=${stealthSettings.module_mount_modes}`);
        newLines.push('');
        newLines.push('# ====== Performance Settings ======');
        newLines.push(`optimization_level=${stealthSettings.optimization_level}`);
        newLines.push(`mount_delay=${stealthSettings.mount_delay}`);
        newLines.push(`parallel_mount=${stealthSettings.parallel_mount}`);

        const content = newLines.join('\n').replace(/'/g, "'\\''");
        const cmd = `printf '%s\n' '${content}' > '${EXTENDED_CONFIG_PATH}'`;
        
        await exec(cmd);
        state.stealth = { ...state.stealth, ...stealthSettings };
        state.globalMountMode = stealthSettings.mount_mode;
        updateStatusUI();
        showToast(t('toast.saveSuccess'), 'success');
        
    } catch (e) {
        console.error('Save stealth error:', e);
        showToast(t('toast.saveError'), 'error');
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
        
        Array.from(listEl.children).forEach(child => {
            if (child !== loadingEl && child !== emptyEl) {
                child.remove();
            }
        });

        const moduleDir = state.config.module_dir || MODULE_DIR;
        pathEl.textContent = `${t('modules.path')}: ${moduleDir}`;

        const script = `
            MOD_DIR="${moduleDir}"
            if [ ! -d "$MOD_DIR" ]; then
                exit 0
            fi
            
            for m in "$MOD_DIR"/*; do
                [ -d "$m" ] || continue
                [ -d "$m/system" ] || continue
                
                MOD_NAME=$(basename "$m")
                
                PROP_FILE="$m/module.prop"
                MOD_ID="$MOD_NAME"
                MOD_VERSION=""
                MOD_AUTHOR=""
                MOD_DESC=""
                MOD_META=""
                
                if [ -f "$PROP_FILE" ]; then
                    MOD_ID=$(grep -E "^id=" "$PROP_FILE" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' \r\n')
                    MOD_VERSION=$(grep -E "^version=" "$PROP_FILE" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' \r\n')
                    MOD_AUTHOR=$(grep -E "^author=" "$PROP_FILE" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' \r\n')
                    MOD_DESC=$(grep -E "^description=" "$PROP_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' \r\n')
                    MOD_META=$(grep -E "^metamodule=" "$PROP_FILE" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' \r\n')
                fi
                
                [ -z "$MOD_ID" ] && MOD_ID="$MOD_NAME"
                
                DISABLED=0
                SKIP=0
                [ -e "$m/disable" ] || [ -e "$m/remove" ] && DISABLED=1
                [ -e "$m/skip_mount" ] && SKIP=1
                
                MOUNTED=0
                if mount | grep -q "$m/system"; then
                    MOUNTED=1
                fi
                
                printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \
                    "$MOD_NAME" "$MOD_ID" "$MOD_VERSION" "$MOD_AUTHOR" "$MOD_DESC" \
                    "$MOD_META" "$DISABLED" "$SKIP" "$MOUNTED"
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
                    isMounted: parts[8] === '1'
                };
            });

        state.modules = modules;
        state.moduleDetails = {};
        modules.forEach(m => {
            state.moduleDetails[m.id] = m;
        });
        
        document.getElementById('moduleCount').textContent = modules.length;

        loadingEl.style.display = 'none';
        
        if (modules.length === 0) {
            emptyEl.style.display = 'flex';
        } else {
            renderModules(modules);
        }

    } catch (e) {
        console.error('Load modules error:', e);
        loadingEl.style.display = 'none';
        emptyEl.style.display = 'flex';
        document.getElementById('moduleCount').textContent = '0';
    }
}

function getModuleMountMode(moduleName) {
    return state.moduleModes[moduleName] || 'global';
}

function renderModules(modules) {
    const listEl = document.getElementById('moduleList');
    
    modules.forEach((mod, index) => {
        const item = document.createElement('div');
        item.className = 'module-card';
        item.dataset.moduleId = mod.id;
        item.style.animationDelay = `${index * 0.05}s`;
        
        const mountMode = getModuleMountMode(mod.id);
        const modeClass = mountMode === 'overlayfs' ? 'overlayfs' : (mountMode === 'magic' ? 'magic' : 'global');
        const modeLabel = mountMode === 'overlayfs' ? t('modules.overlayfs') : (mountMode === 'magic' ? t('modules.magic') : 'Global');
        const statusClass = mod.skip ? 'unmounted' : (mod.isMounted ? 'mounted' : 'mounted');
        const statusText = mod.skip ? t('modules.unmounted') : (mod.disabled ? t('modules.unmounted') : t('modules.mounted'));
        
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
                <div class="module-card-section">
                    <div class="module-card-section-title">${t('modules.mountMode')}</div>
                    <div class="module-card-strategy">
                        <button class="strategy-btn ${mountMode === 'magic' ? 'selected' : ''}" 
                                onclick="setModuleMode('${escapeHtml(mod.id)}', 'magic')">
                            <div class="strategy-btn-title">${t('modules.magic')}</div>
                            <div class="strategy-btn-sub">${t('modules.magicDesc')}</div>
                        </button>
                        <button class="strategy-btn ${mountMode === 'overlayfs' ? 'selected' : ''}" 
                                onclick="setModuleMode('${escapeHtml(mod.id)}', 'overlayfs')">
                            <div class="strategy-btn-title">${t('modules.overlayfs')}</div>
                            <div class="strategy-btn-sub">${t('modules.overlayDesc')}</div>
                        </button>
                    </div>
                    <div style="font-size:11px;color:var(--md3-on-surface-variant);margin-top:8px;">
                        Current: <span class="mode-indicator ${modeClass}">${modeLabel}</span>
                    </div>
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
    state.moduleModes[moduleId] = mode;
    
    try {
        const { stdout } = await exec(`cat "${EXTENDED_CONFIG_PATH}" 2>/dev/null || echo ""`);
        let lines = stdout.split('\n');
        
        let found = false;
        const newLines = [];
        lines.forEach(line => {
            if (line.startsWith('module_mount_modes=')) {
                newLines.push(`module_mount_modes=${JSON.stringify(state.moduleModes)}`);
                found = true;
            } else {
                newLines.push(line);
            }
        });
        
        if (!found) {
            newLines.push(`module_mount_modes=${JSON.stringify(state.moduleModes)}`);
        }
        
        const content = newLines.join('\n').replace(/'/g, "'\\''");
        await exec(`printf '%s\n' '${content}' > '${EXTENDED_CONFIG_PATH}'`);
        
        const card = document.querySelector(`.module-card[data-module-id="${moduleId}"]`);
        if (card) {
            const btns = card.querySelectorAll('.strategy-btn');
            btns.forEach(btn => {
                btn.classList.remove('selected');
                if (btn.onclick.toString().includes(`'${mode}'`)) {
                    btn.classList.add('selected');
                }
            });
            
            const indicator = card.querySelector('.mode-indicator');
            if (indicator) {
                indicator.className = `mode-indicator ${mode}`;
                indicator.textContent = mode === 'overlayfs' ? t('modules.overlayfs') : t('modules.magic');
            }
        }
        
        showToast(t('toast.modeSaved'), 'success');
        
    } catch (e) {
        console.error('Save module mode error:', e);
        showToast(t('toast.saveError'), 'error');
    }
}

// ===== Log Operations =====
async function loadLogs() {
    const contentEl = document.getElementById('logContent');
    const viewEl = document.getElementById('logView');
    
    try {
        contentEl.textContent = t('logs.loading');
        
        const baseLogFile = '/data/adb/magic_mount/mm.log';
        let logFile;
        
        if (state.currentLog === 'old') {
            logFile = '/data/adb/magic_mount/mm_old.log';
        } else {
            logFile = baseLogFile;
        }
        
        const { stdout } = await exec(`
            if [ -f "${logFile}" ]; then
                cat "${logFile}"
            elif [ -f "${logFile}.old" ]; then
                cat "${logFile}.old"
            else
                echo ""
            fi
        `);
        
        if (!stdout.trim()) {
            contentEl.textContent = t('logs.empty');
        } else {
            contentEl.textContent = stdout;
            viewEl.scrollTop = viewEl.scrollHeight;
        }
        
    } catch (e) {
        console.error('Load logs error:', e);
        contentEl.textContent = t('logs.empty');
    }
}

// ===== Status Updates =====
function updateStatusUI() {
    const mountStatus = document.getElementById('mountStatus');
    if (state.config.mount_source) {
        const modeText = state.globalMountMode === 'overlayfs' ? 'OverlayFS' : 
                         state.globalMountMode === 'magic' ? 'Magic' : 
                         state.config.mount_source;
        mountStatus.textContent = modeText;
        mountStatus.style.color = state.globalMountMode === 'overlayfs' ? 'var(--md3-tertiary)' : 'var(--md3-primary)';
    }

    const stealthStatus = document.getElementById('stealthStatus');
    if (state.stealth.stealth_mode) {
        stealthStatus.textContent = state.stealth.randomize_id ? 'Full' : 'Active';
        stealthStatus.style.color = 'var(--md3-tertiary)';
    } else {
        stealthStatus.textContent = 'Disabled';
        stealthStatus.style.color = 'var(--md3-outline)';
    }
}

// ===== Metrics =====
async function updateMetrics() {
    if (!state.showMetrics) return;
    
    try {
        const cpuScript = `cat /proc/stat | grep 'cpu ' | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}'`;
        const { stdout: cpu } = await exec(cpuScript);
        const cpuVal = parseInt(cpu) || 0;
        document.getElementById('cpuBar').style.width = `${cpuVal}%`;
        document.getElementById('cpuValue').textContent = `${cpuVal}%`;

        const memScript = `cat /proc/meminfo | awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END {printf "%.0f", (t-a)*100/t}'`;
        const { stdout: mem } = await exec(memScript);
        const memVal = parseInt(mem) || 0;
        document.getElementById('memBar').style.width = `${memVal}%`;
        document.getElementById('memValue').textContent = `${memVal}%`;

        const diskScript = `df /data | tail -1 | awk '{print $5}' | tr -d '%'`;
        const { stdout: disk } = await exec(diskScript);
        const diskVal = parseInt(disk) || 0;
        document.getElementById('diskBar').style.width = `${diskVal}%`;
        document.getElementById('diskValue').textContent = `${diskVal}%`;
        
    } catch (e) {
        // Silently fail
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
                loadLogs();
            }
        });
    });
}

// ===== Event Listeners =====
function initEventListeners() {
    document.getElementById('themeToggle')?.addEventListener('click', toggleTheme);
    document.getElementById('saveConfig')?.addEventListener('click', saveConfig);
    document.getElementById('saveStealth')?.addEventListener('click', saveStealth);
    document.getElementById('reloadModules')?.addEventListener('click', loadModules);
    document.getElementById('refreshLogs')?.addEventListener('click', loadLogs);
    
    document.querySelectorAll('.log-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.log-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            state.currentLog = tab.dataset.log;
            loadLogs();
        });
    });
}

// ===== Initialization =====
async function init() {
    initTheme();
    initLangDropdown();
    initTabs();
    initEventListeners();
    
    await loadConfig();
    await loadStealth();
    await loadModules();
    
    updateI18n();
    initHelpIcons();
    
    if (state.showMetrics) {
        updateMetrics();
        setInterval(updateMetrics, 1000);
    }
    
    setInterval(() => {
        const moduleCountEl = document.getElementById('moduleCount');
        if (moduleCountEl) {
            moduleCountEl.textContent = state.modules.length;
        }
    }, 1000);
}

document.addEventListener('DOMContentLoaded', init);

// 导出给全局使用
window.toggleModuleCard = toggleModuleCard;
window.setModuleMode = setModuleMode;