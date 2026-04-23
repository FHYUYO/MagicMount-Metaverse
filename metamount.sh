#!/system/bin/sh
#=============================================
# Magic Mount Metaverse - metamount.sh v3.5
# by GitHub@FHYUYO
#
# 主要功能：
#   - 支持Magic和OverlayFS两种挂载模式
#   - 用户可选择特定模块的挂载方式
#   - 隐藏模块自动跳过
#
# v3.5 更新:
#   - 优化挂载逻辑，用户选择后才挂载
#   - 修复若干小问题
#=============================================

MODDIR="${0%/*}"
EXTENDED_CONFIG="/data/adb/Metaverse/扩展配置.conf"
LOG_FILE="/data/adb/Metaverse/运行日志.log"

# 二进制文件路径
MM_BINARY="$MODDIR/mmd"
OVERLAY_BINARY="$MODDIR/mm_overlay"
STATUS_UPDATER="$MODDIR/status_updater.sh"

# 默认配置
GLOBAL_MOUNT_MODE="magic"
HIDE_MOUNTS="false"
STEALTH_MODE="false"
PARALLEL_MOUNT="false"
OPTIMIZATION_LEVEL="0"
MOUNT_DELAY="0"
MODULE_MODES_JSON="{}"
FORCE_MOUNT_JSON="{}"
IGNORED_MODULES_JSON="{}"

# ===== 支持的分区列表 =====
SUPPORTED_PARTITIONS="system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm"

# ===== 统计变量 =====
OVERLAYFS_SUCCESS=0
MAGIC_SUCCESS=0
MOUNT_FAILED=0
MOUNT_SKIPPED=0
SKIP_IGNORE=0
SKIP_SKIP_MOUNT=0
SKIP_DISABLED=0
SKIP_NO_PARTITION=0
SKIP_SELF=0
SKIP_HIDDEN=0

# 日志函数 - 中文输出
log_msg() {
    local msg="$1"
    local level="${2:-"信息"}"
    
    # 过滤敏感关键词
    case "$msg" in
        *password*|*secret*|*key*|*token*|*credential*|*auth*)
            return
            ;;
        *unmount*|*卸载*)
            [ "$HIDE_MOUNTS" = "true" ] && return
            ;;
        *mounting*|*挂载*)
            [ "$HIDE_MOUNTS" = "true" ] && return
            ;;
    esac
    
    # 脱敏路径
    msg=$(echo "$msg" | sed \
        -e 's|/data/adb/modules|<模块目录>|g' \
        -e 's|/data/adb/Metaverse|<配置目录>|g' \
        -e 's|/system/system|<系统>|g')
    
    echo "[$level] $(date '+%m-%d %H:%M:%S') $msg" >> "$LOG_FILE" 2>/dev/null
}

# ===== 读取配置 =====
read_config() {
    GLOBAL_MOUNT_MODE="magic"
    HIDE_MOUNTS="false"
    STEALTH_MODE="false"
    PARALLEL_MOUNT="false"
    OPTIMIZATION_LEVEL="0"
    MOUNT_DELAY="0"
    MODULE_MODES_JSON="{}"
    FORCE_MOUNT_JSON="{}"
    IGNORED_MODULES_JSON="{}"
    
    if [ -f "$EXTENDED_CONFIG" ]; then
        GLOBAL_MOUNT_MODE=$(grep -E "^[[:space:]]*mount_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        HIDE_MOUNTS=$(grep -E "^[[:space:]]*hide_mount_logs[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        STEALTH_MODE=$(grep -E "^[[:space:]]*stealth_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        PARALLEL_MOUNT=$(grep -E "^[[:space:]]*parallel_mount[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        OPTIMIZATION_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        MOUNT_DELAY=$(grep -E "^[[:space:]]*mount_delay[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        MODULE_MODES_JSON=$(grep -E "^[[:space:]]*module_mount_modes[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        FORCE_MOUNT_JSON=$(grep -E "^[[:space:]]*force_mount_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        IGNORED_MODULES_JSON=$(grep -E "^[[:space:]]*ignored_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
    fi
    
    # 设置默认值
    [ -z "$GLOBAL_MOUNT_MODE" ] && GLOBAL_MOUNT_MODE="magic"
    [ -z "$HIDE_MOUNTS" ] && HIDE_MOUNTS="false"
    [ -z "$STEALTH_MODE" ] && STEALTH_MODE="false"
    [ -z "$PARALLEL_MOUNT" ] && PARALLEL_MOUNT="false"
    [ -z "$OPTIMIZATION_LEVEL" ] && OPTIMIZATION_LEVEL="0"
    [ -z "$MOUNT_DELAY" ] && MOUNT_DELAY="0"
    [ -z "$MODULE_MODES_JSON" ] && MODULE_MODES_JSON="{}"
    [ -z "$FORCE_MOUNT_JSON" ] && FORCE_MOUNT_JSON="{}"
    [ -z "$IGNORED_MODULES_JSON" ] && IGNORED_MODULES_JSON="{}"
    
    log_msg "配置已加载: 全局模式=$GLOBAL_MOUNT_MODE 隐身=$STEALTH_MODE" "调试"
}

# ===== 分区相关函数 =====

# 获取所有启用的分区列表
get_enabled_partitions() {
    local partitions=""
    local config_partitions=""
    
    if [ -f "/data/adb/Metaverse/配置.conf" ]; then
        config_partitions=$(grep -E "^[[:space:]]*partitions[[:space:]]*=" "/data/adb/Metaverse/配置.conf" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
    fi
    
    if [ -z "$config_partitions" ]; then
        partitions="$SUPPORTED_PARTITIONS"
    else
        partitions=$(echo "$config_partitions" | tr ',' ' ')
    fi
    
    echo "$partitions"
}

# 检查分区是否已挂载
is_partition_mounted() {
    local partition="$1"
    mount | grep -q "/$partition " 2>/dev/null
    return $?
}

# 强制挂载分区
ensure_partition_mounted() {
    local partition="$1"
    
    if is_partition_mounted "$partition"; then
        return 0
    fi
    
    log_msg "分区 $partition 未挂载，尝试挂载..." "警告"
    
    case "$partition" in
        system)
            [ -d "/system" ] && ! mountpoint -q "/system" 2>/dev/null && mount -o ro /system 2>/dev/null && return 0
            ;;
        vendor)
            [ -d "/vendor" ] && ! mountpoint -q "/vendor" 2>/dev/null && mount -o ro /vendor 2>/dev/null && return 0
            ;;
        product)
            [ -d "/product" ] && ! mountpoint -q "/product" 2>/dev/null && mount -o ro /product 2>/dev/null && return 0
            ;;
        system_ext)
            [ -d "/system_ext" ] && ! mountpoint -q "/system_ext" 2>/dev/null && mount -o ro /system_ext 2>/dev/null && return 0
            ;;
        odm)
            [ -d "/odm" ] && ! mountpoint -q "/odm" 2>/dev/null && mount -o ro /odm 2>/dev/null && return 0
            ;;
        my_product)
            [ -d "/my_product" ] && ! mountpoint -q "/my_product" 2>/dev/null && mount -o ro /my_product 2>/dev/null && return 0
            ;;
        vendor_dlkm)
            [ -d "/vendor_dlkm" ] && ! mountpoint -q "/vendor_dlkm" 2>/dev/null && mount -o ro /vendor_dlkm 2>/dev/null && return 0
            ;;
        odm_dlkm)
            [ -d "/odm_dlkm" ] && ! mountpoint -q "/odm_dlkm" 2>/dev/null && mount -o ro /odm_dlkm 2>/dev/null && return 0
            ;;
        system_dlkm)
            [ -d "/system_dlkm" ] && ! mountpoint -q "/system_dlkm" 2>/dev/null && mount -o ro /system_dlkm 2>/dev/null && return 0
            ;;
    esac
    
    return 1
}

# ===== 模块分区检查 =====

# 检查模块是否包含可挂载的分区
# v3.4.3: 检查是否有 system/vendor/odm 等分区目录或文件
is_module_mountable() {
    local module_path="$1"
    for part in system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm; do
        [ -e "$module_path/$part" ] && return 0
    done
    return 1
}

# v3.4.2: 显式检查是否为隐藏模块
# 返回0表示是隐藏模块（应跳过），返回1表示非隐藏模块
is_hidden_module() {
    local module_path="$1"
    # 隐藏模块 = 无 system/vendor/odm 等任何可挂载分区
    if is_module_mountable "$module_path"; then
        return 1  # 非隐藏模块（有分区目录）
    else
        return 0  # 隐藏模块（无分区目录）
    fi
}

# ===== 挂载控制功能 =====

# 检查模块是否在强制挂载列表中
is_force_mount() {
    local module_name="$1"
    echo "$FORCE_MOUNT_JSON" | grep -o "\"$module_name\":true" >/dev/null 2>&1
    return $?
}

# 检查模块是否被自定义忽略
is_custom_ignored() {
    local module_name="$1"
    echo "$IGNORED_MODULES_JSON" | grep -o "\"$module_name\":\"ignore\"" >/dev/null 2>&1
    return $?
}

# v3.4.2: 检查模块是否被用户选择挂载（非global模式）
# 只有用户明确在 module_mount_modes 中设置模式的模块才会被挂载
is_user_selected() {
    local module_name="$1"
    local mode=$(echo "$MODULE_MODES_JSON" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        local mode_value=$(echo "$mode" | sed 's/.*":"//' | tr -d '"')
        # 如果模式是 "global" 则视为未选择
        [ "$mode_value" != "global" ] && return 0
    fi
    return 1
}

# 检查模块是否被原生忽略（ignore文件）
is_native_ignored() {
    local module_path="/data/adb/modules/$1"
    [ -f "$module_path/ignore" ]
    return $?
}

# 检查模块是否应该被跳过（返回0表示跳过，返回1表示不跳过）
# v3.4.3: 修改逻辑，先检查自定义忽略，再检查用户选择
should_skip_module() {
    local module_name="$1"
    local module_path="/data/adb/modules/$module_name"
    
    # 0. 首先检查是否为隐藏模块（无分区目录或文件）
    # 隐藏模块完全跳过挂载逻辑
    if is_hidden_module "$module_path"; then
        log_msg "跳过: $module_name (隐藏模块/无分区)" "调试"
        SKIP_HIDDEN=$((SKIP_HIDDEN + 1))
        return 0
    fi
    
    # 1. 检查自定义忽略（最高优先级）
    if is_custom_ignored "$module_name"; then
        log_msg "跳过: $module_name (自定义忽略)" "调试"
        SKIP_IGNORE=$((SKIP_IGNORE + 1))
        return 0
    fi
    
    # 2. 检查原生ignore文件（但force_mount可以覆盖）
    if is_native_ignored "$module_name"; then
        if is_force_mount "$module_name"; then
            log_msg "模块 $module_name 有ignore标记但已启用强制挂载" "调试"
            return 1
        fi
        log_msg "跳过: $module_name (原生ignore标记)" "调试"
        SKIP_IGNORE=$((SKIP_IGNORE + 1))
        return 0
    fi
    
    # 3. 检查是否被用户选择挂载
    if ! is_user_selected "$module_name"; then
        log_msg "跳过: $module_name (未选择挂载模式)" "调试"
        SKIP_SKIP_MOUNT=$((SKIP_SKIP_MOUNT + 1))
        return 0
    fi
    
    return 1
}

# 获取模块的挂载模式
get_module_mount_mode() {
    local module_name="$1"
    local module_modes_json="$2"
    
    local mode=$(echo "$module_modes_json" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        echo "$mode" | sed 's/.*":"//' | tr -d '"'
    else
        echo "global"
    fi
}

# 延迟执行
apply_mount_delay() {
    if [ -n "$MOUNT_DELAY" ] && [ "$MOUNT_DELAY" -gt 0 ] 2>/dev/null; then
        local delay_sec=$(echo "scale=2; $MOUNT_DELAY / 1000" | bc 2>/dev/null || echo "0")
        [ -n "$delay_sec" ] && [ "$delay_sec" != "0" ] && sleep "$delay_sec"
    fi
}

# ===== 挂载函数 =====

# Magic 挂载
do_magic_mount() {
    local module_name="$1"
    
    log_msg "Magic挂载: $module_name" "信息"
    
    [ ! -f "$MM_BINARY" ] && log_msg "二进制文件不存在: $MM_BINARY" "错误" && return 1
    
    if [ "$STEALTH_MODE" = "true" ]; then
        "$MM_BINARY" "$module_name" >/dev/null 2>&1
    else
        "$MM_BINARY" "$module_name"
    fi
    return $?
}

# OverlayFS 挂载
do_overlayfs_mount() {
    local module_name="$1"
    
    log_msg "OverlayFS挂载: $module_name" "信息"
    
    if [ ! -f "$OVERLAY_BINARY" ]; then
        log_msg "OverlayFS二进制不存在，回退到Magic模式" "警告"
        do_magic_mount "$module_name"
        return $?
    fi
    
    local img_file="$MODDIR/modules.img"
    local mnt_dir="$MODDIR/mnt"
    
    if [ -f "$img_file" ] && ! mountpoint -q "$mnt_dir" 2>/dev/null; then
        mkdir -p "$mnt_dir" 2>/dev/null
        chcon u:object_r:ksu_file:s0 "$img_file" 2>/dev/null
        mount -t ext4 -o loop,rw,noatime "$img_file" "$mnt_dir" 2>/dev/null
        if mountpoint -q "$mnt_dir" 2>/dev/null; then
            export MODULE_CONTENT_DIR="$mnt_dir"
            log_msg "modules.img 已挂载到 $mnt_dir" "调试"
        fi
    fi
    
    if [ "$STEALTH_MODE" = "true" ]; then
        "$OVERLAY_BINARY" "$module_name" >/dev/null 2>&1
    else
        "$OVERLAY_BINARY" "$module_name"
    fi
    return $?
}

# 执行挂载
execute_mount() {
    local module_name="$1"
    local mount_mode="$2"
    local retry_count=0
    local max_retries=2
    
    while [ $retry_count -le $max_retries ]; do
        case "$mount_mode" in
            overlayfs)
                do_overlayfs_mount "$module_name"
                ;;
            magic|*)
                do_magic_mount "$module_name"
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -le $max_retries ]; then
            log_msg "重试 $retry_count/$max_retries: $module_name" "警告"
            sleep 1
        fi
    done
    
    log_msg "挂载失败: $module_name (模式: $mount_mode)" "错误"
    return 1
}

# 检查模块是否被KernelSU卸载
is_module_disabled_by_ksu() {
    local module_name="$1"
    local module_path="/data/adb/modules/$module_name"
    
    [ -f "$module_path/disable" ] || [ -f "$module_path/remove" ]
    return $?
}

# 更新状态显示
update_status() {
    [ -f "$STATUS_UPDATER" ] && sh "$STATUS_UPDATER" 2>/dev/null &
}

# ===== 日志统计输出 =====
print_mount_summary() {
    local opt_mode="$1"
    
    echo "" >> "$LOG_FILE" 2>/dev/null
    echo "═══════════════════════════════════════════════" >> "$LOG_FILE" 2>/dev/null
    echo "           Magic Mount Metaverse v3.5       " >> "$LOG_FILE" 2>/dev/null
    echo "              挂载统计报告                     " >> "$LOG_FILE" 2>/dev/null
    echo "═══════════════════════════════════════════════" >> "$LOG_FILE" 2>/dev/null
    echo "" >> "$LOG_FILE" 2>/dev/null
    
    echo "【全局设置】" >> "$LOG_FILE" 2>/dev/null
    echo "  • 全局挂载模式: $GLOBAL_MOUNT_MODE" >> "$LOG_FILE" 2>/dev/null
    echo "  • 优化级别: $opt_mode" >> "$LOG_FILE" 2>/dev/null
    echo "  • 隐身模式: $STEALTH_MODE" >> "$LOG_FILE" 2>/dev/null
    echo "" >> "$LOG_FILE" 2>/dev/null
    
    echo "【挂载结果】" >> "$LOG_FILE" 2>/dev/null
    echo "  ✓ OverlayFS 挂载成功: $OVERLAYFS_SUCCESS 个" >> "$LOG_FILE" 2>/dev/null
    echo "  ✓ Magic 挂载成功: $MAGIC_SUCCESS 个" >> "$LOG_FILE" 2>/dev/null
    echo "  ✗ 挂载失败: $MOUNT_FAILED 个" >> "$LOG_FILE" 2>/dev/null
    echo "" >> "$LOG_FILE" 2>/dev/null
    
    echo "【跳过统计】" >> "$LOG_FILE" 2>/dev/null
    echo "  • 隐藏模块(无system): $SKIP_HIDDEN 个" >> "$LOG_FILE" 2>/dev/null
    echo "  • 被忽略/自定义忽略: $SKIP_IGNORE 个" >> "$LOG_FILE" 2>/dev/null
    echo "  • skip_mount标记: $SKIP_SKIP_MOUNT 个" >> "$LOG_FILE" 2>/dev/null
    echo "  • 被KSU禁用: $SKIP_DISABLED 个" >> "$LOG_FILE" 2>/dev/null
    echo "  • 跳过自身模块: $SKIP_SELF 个" >> "$LOG_FILE" 2>/dev/null
    echo "" >> "$LOG_FILE" 2>/dev/null
    
    # 总结
    local total_attempt=$((OVERLAYFS_SUCCESS + MAGIC_SUCCESS + MOUNT_FAILED))
    local total_skipped=$((SKIP_HIDDEN + SKIP_IGNORE + SKIP_SKIP_MOUNT + SKIP_DISABLED + SKIP_SELF))
    
    if [ $total_attempt -gt 0 ]; then
        echo "【成功率】" >> "$LOG_FILE" 2>/dev/null
        local success_total=$((OVERLAYFS_SUCCESS + MAGIC_SUCCESS))
        local success_rate=$((success_total * 100 / total_attempt))
        echo "  尝试挂载: $total_attempt 个 | 成功: $success_total 个 | 失败: $MOUNT_FAILED 个" >> "$LOG_FILE" 2>/dev/null
        echo "  成功率: ${success_rate}%" >> "$LOG_FILE" 2>/dev/null
        echo "" >> "$LOG_FILE" 2>/dev/null
    fi
    
    echo "═══════════════════════════════════════════════" >> "$LOG_FILE" 2>/dev/null
    
    # 状态输出到终端
    echo "" >&2
    echo "╔═══════════════════════════════════════════════╗" >&2
    echo "║        Magic Mount Metaverse v3.5           ║" >&2
    echo "║           挂载统计报告                         ║" >&2
    echo "╠═══════════════════════════════════════════════╣" >&2
    echo "║  OverlayFS成功: $OVERLAYFS_SUCCESS  Magic成功: $MAGIC_SUCCESS  失败: $MOUNT_FAILED    ║" >&2
    echo "║  跳过(隐藏): $SKIP_HIDDEN  (忽略): $SKIP_IGNORE  skip_mount: $SKIP_SKIP_MOUNT       ║" >&2
    echo "╚═══════════════════════════════════════════════╝" >&2
    echo "" >&2
}

############################################
# 主程序
############################################

log_msg "=== Magic Mount Metaverse v3.5 挂载开始 ===" "启动"

# 读取配置
read_config

log_msg "全局模式: $GLOBAL_MOUNT_MODE" "信息"
log_msg "隐身: $STEALTH_MODE, 隐藏日志: $HIDE_MOUNTS" "调试"

# 确保所有必要的分区已挂载
ENABLED_PARTITIONS=$(get_enabled_partitions)
for partition in $ENABLED_PARTITIONS; do
    if ! is_partition_mounted "$partition"; then
        log_msg "确保分区 $partition 已挂载" "调试"
        ensure_partition_mounted "$partition" || log_msg "无法挂载分区 $partition" "警告"
    fi
done

# 应用挂载延迟
apply_mount_delay

EXIT_CODE=0
MODULE_DIR="/data/adb/modules"

# 遍历所有模块
if [ -d "$MODULE_DIR" ]; then
    for mod in "$MODULE_DIR"/*; do
        [ -d "$mod" ] || continue
        
        MODULE_NAME=$(basename "$mod")
        
        # 跳过自身模块
        if [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ]; then
            log_msg "跳过自身模块: $MODULE_NAME" "调试"
            SKIP_SELF=$((SKIP_SELF + 1))
            continue
        fi
        
        # 检查是否被KernelSU卸载
        if is_module_disabled_by_ksu "$MODULE_NAME"; then
            log_msg "跳过: $MODULE_NAME (被KSU禁用)" "调试"
            SKIP_DISABLED=$((SKIP_DISABLED + 1))
            continue
        fi
        
        # v3.4.2: 检查是否为隐藏模块（无分区目录）
        # 隐藏模块完全跳过挂载逻辑
        if is_hidden_module "$mod"; then
            log_msg "跳过隐藏模块: $MODULE_NAME (无system目录)" "调试"
            SKIP_HIDDEN=$((SKIP_HIDDEN + 1))
            continue
        fi
        
        # 检查是否应该跳过（自定义忽略、原生ignore、skip_mount）
        if should_skip_module "$MODULE_NAME"; then
            MOUNT_SKIPPED=$((MOUNT_SKIPPED + 1))
            continue
        fi
        
        # 获取模块挂载模式
        MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
        
        # 检查是否强制挂载
        if is_force_mount "$MODULE_NAME"; then
            MODULE_MODE="force"
            log_msg "强制挂载: $MODULE_NAME" "信息"
        fi
        
        # 确定使用的挂载模式
        if [ "$MODULE_MODE" != "global" ] && [ "$MODULE_MODE" != "force" ]; then
            USE_MODE="$MODULE_MODE"
        elif [ "$MODULE_MODE" = "force" ]; then
            USE_MODE="$GLOBAL_MOUNT_MODE"
        else
            USE_MODE="$GLOBAL_MOUNT_MODE"
        fi
        
        # 执行挂载
        if execute_mount "$MODULE_NAME" "$USE_MODE"; then
            if [ "$USE_MODE" = "overlayfs" ]; then
                OVERLAYFS_SUCCESS=$((OVERLAYFS_SUCCESS + 1))
            else
                MAGIC_SUCCESS=$((MAGIC_SUCCESS + 1))
            fi
        else
            MOUNT_FAILED=$((MOUNT_FAILED + 1))
            EXIT_CODE=1
        fi
    done
fi

# 优化模式
OPT_MODE="标准"
case "$OPTIMIZATION_LEVEL" in
    1) OPT_MODE="快速" ;;
    2) OPT_MODE="极致" ;;
esac

# 输出统计
print_mount_summary "$OPT_MODE"

# 更新状态
update_status

log_msg "=== Magic Mount Metaverse 挂载完成 ===" "启动"

exit $EXIT_CODE
