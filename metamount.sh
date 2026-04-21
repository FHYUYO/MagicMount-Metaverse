#!/system/bin/sh
############################################
# Magic Mount Metaverse - metamount.sh
# Enhanced v3.4.1
# Author: GitHub@FHYUYO
# 
# v3.4.1 Changes:
#   - Fixed partition save issue support
#   - Added custom ignore support (ignored_modules config)
#   - Show hidden modules support
#   - Improved module filtering logic
#   - Only modules with specific mount mode will be mounted
#   - Hidden modules won't be auto-mounted by global mount
############################################

MODDIR="${0%/*}"
EXTENDED_CONFIG="/data/adb/magic_mount/mm_extended.conf"
LOG_FILE="/data/adb/magic_mount/mm.log"

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
IGNORED_MODULES_JSON="{}"  # v3.4: 自定义忽略的模块

# ===== 支持的分区列表 =====
SUPPORTED_PARTITIONS="system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm"

# 日志函数
log_msg() {
    local msg="$1"
    local level="${2:-INFO}"
    
    # 过滤敏感关键词
    case "$msg" in
        *password*|*secret*|*key*|*token*|*credential*|*auth*)
            return
            ;;
        *unmount*)
            [ "$HIDE_MOUNTS" = "true" ] && return
            ;;
        *mounting*)
            [ "$HIDE_MOUNTS" = "true" ] && return
            ;;
    esac
    
    # 脱敏路径
    msg=$(echo "$msg" | sed \
        -e 's|/data/adb/modules|<MODULES>|g' \
        -e 's|/data/adb/magic_mount|<MM_DIR>|g' \
        -e 's|/system/system|<SYSTEM>|g')
    
    echo "[$level] $msg" >> "$LOG_FILE" 2>/dev/null
}

# 读取配置
read_config() {
    GLOBAL_MOUNT_MODE="magic"
    HIDE_MOUNTS="false"
    STEALTH_MODE="false"
    PARALLEL_MOUNT="false"
    OPTIMIZATION_LEVEL="0"
    MOUNT_DELAY="0"
    MODULE_MODES_JSON="{}"
    FORCE_MOUNT_JSON="{}"
    IGNORED_MODULES_JSON="{}"  # v3.4
    
    if [ -f "$EXTENDED_CONFIG" ]; then
        GLOBAL_MOUNT_MODE=$(grep -E "^[[:space:]]*mount_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        HIDE_MOUNTS=$(grep -E "^[[:space:]]*hide_mount_logs[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        STEALTH_MODE=$(grep -E "^[[:space:]]*stealth_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        PARALLEL_MOUNT=$(grep -E "^[[:space:]]*parallel_mount[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        OPTIMIZATION_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        MOUNT_DELAY=$(grep -E "^[[:space:]]*mount_delay[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
        MODULE_MODES_JSON=$(grep -E "^[[:space:]]*module_mount_modes[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        FORCE_MOUNT_JSON=$(grep -E "^[[:space:]]*force_mount_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        IGNORED_MODULES_JSON=$(grep -E "^[[:space:]]*ignored_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')  # v3.4
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
    [ -z "$IGNORED_MODULES_JSON" ] && IGNORED_MODULES_JSON="{}"  # v3.4
    
    log_msg "Config loaded: mode=$GLOBAL_MOUNT_MODE stealth=$STEALTH_MODE force=$FORCE_MOUNT_JSON ignore=$IGNORED_MODULES_JSON" "DEBUG"
}

# ===== 分区相关函数 =====

# 获取所有启用的分区列表
get_enabled_partitions() {
    local partitions=""
    local config_partitions=""
    
    # 从主配置文件读取分区
    if [ -f "/data/adb/magic_mount/mm.conf" ]; then
        config_partitions=$(grep -E "^[[:space:]]*partitions[[:space:]]*=" "/data/adb/magic_mount/mm.conf" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "'\''`\r\n')
    fi
    
    # 默认启用所有常见分区
    if [ -z "$config_partitions" ]; then
        partitions="$SUPPORTED_PARTITIONS"
    else
        # 解析用户配置的分区
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

# 强制挂载分区（如果需要）
ensure_partition_mounted() {
    local partition="$1"
    
    if is_partition_mounted "$partition"; then
        return 0
    fi
    
    log_msg "Partition $partition not mounted, attempting to mount..." "WARN"
    
    # 尝试挂载分区
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
# 检查模块是否包含可挂载的分区目录
is_module_mountable() {
    local module_path="$1"
    # 支持所有常见分区
    for part in system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm; do
        [ -d "$module_path/$part" ] && return 0
    done
    return 1
}

# ===== 挂载控制功能 =====

# 检查模块是否在强制挂载列表中
is_force_mount() {
    local module_name="$1"
    echo "$FORCE_MOUNT_JSON" | grep -o "\"$module_name\":true" >/dev/null 2>&1
    return $?
}

# 检查模块是否被自定义忽略 v3.4
is_custom_ignored() {
    local module_name="$1"
    echo "$IGNORED_MODULES_JSON" | grep -o "\"$module_name\":\"ignore\"" >/dev/null 2>&1
    return $?
}

# 检查模块是否被原生忽略（ignore文件）
is_native_ignored() {
    local module_path="/data/adb/modules/$1"
    [ -f "$module_path/ignore" ]
    return $?
}

# 检查模块是否应该被跳过
should_skip_module() {
    local module_name="$1"
    local module_path="/data/adb/modules/$module_name"
    
    # 0. 首先检查模块是否包含可挂载的分区
    if ! is_module_mountable "$module_path"; then
        log_msg "Skipping: $module_name (no mountable partitions)" "DEBUG"
        return 0
    fi
    
    # 1. 检查自定义忽略（优先级最高）
    if is_custom_ignored "$module_name"; then
        log_msg "Skipping: $module_name (custom ignore)" "DEBUG"
        return 0
    fi
    
    # 2. 检查原生ignore文件（但force_mount可以覆盖）
    if is_native_ignored "$module_name"; then
        if is_force_mount "$module_name"; then
            log_msg "Module $module_name has ignore marker but force_mount is enabled" "DEBUG"
            return 1  # 不跳过
        fi
        log_msg "Skipping: $module_name (native ignore marker)" "DEBUG"
        return 0  # 跳过
    fi
    
    # 3. 检查skip_mount标记
    if [ -f "$module_path/skip_mount" ]; then
        # 但force_mount可以覆盖skip_mount
        if is_force_mount "$module_name"; then
            log_msg "Module $module_name has skip_mount marker but force_mount is enabled" "DEBUG"
            return 1  # 不跳过
        fi
        log_msg "Skipping: $module_name (skip_mount marker)" "DEBUG"
        return 0  # 跳过
    fi
    
    return 1  # 不跳过
}

# 获取模块的挂载模式
get_module_mount_mode() {
    local module_name="$1"
    local module_modes_json="$2"
    
    # 从JSON中提取该模块的模式
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

# Magic 挂载
do_magic_mount() {
    local module_name="$1"
    
    log_msg "Magic mount for: $module_name" "INFO"
    
    [ ! -f "$MM_BINARY" ] && log_msg "Binary not found: $MM_BINARY" "ERROR" && return 1
    
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
    
    log_msg "OverlayFS mount for: $module_name" "INFO"
    
    if [ ! -f "$OVERLAY_BINARY" ]; then
        log_msg "Overlay binary not found, fallback to magic" "WARN"
        do_magic_mount "$module_name"
        return $?
    fi
    
    # 挂载 modules.img（仅首次）
    local img_file="$MODDIR/modules.img"
    local mnt_dir="$MODDIR/mnt"
    
    if [ -f "$img_file" ] && ! mountpoint -q "$mnt_dir" 2>/dev/null; then
        mkdir -p "$mnt_dir" 2>/dev/null
        chcon u:object_r:ksu_file:s0 "$img_file" 2>/dev/null
        mount -t ext4 -o loop,rw,noatime "$img_file" "$mnt_dir" 2>/dev/null
        if mountpoint -q "$mnt_dir" 2>/dev/null; then
            export MODULE_CONTENT_DIR="$mnt_dir"
            log_msg "modules.img mounted at $mnt_dir" "DEBUG"
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
        
        [ $? -eq 0 ] && return 0
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -le $max_retries ]; then
            log_msg "Retry $retry_count for: $module_name" "WARN"
            sleep 1
        fi
    done
    
    log_msg "Failed after retries: $module_name" "ERROR"
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

# 全局挂载
do_global_mount() {
    log_msg "Using global mount mode: $GLOBAL_MOUNT_MODE" "INFO"
    
    [ ! -f "$MM_BINARY" ] && log_msg "Binary not found: $MM_BINARY" "ERROR" && return 1
    
    if [ "$STEALTH_MODE" = "true" ]; then
        "$MM_BINARY" >/dev/null 2>&1
    else
        "$MM_BINARY"
    fi
    return $?
}

# 全局OverlayFS挂载
do_global_overlayfs_mount() {
    log_msg "Using global OverlayFS mode" "INFO"
    
    [ ! -f "$OVERLAY_BINARY" ] && log_msg "Overlay binary not found" "ERROR" && return 1
    
    local img_file="$MODDIR/modules.img"
    local mnt_dir="$MODDIR/mnt"
    
    if [ -f "$img_file" ] && ! mountpoint -q "$mnt_dir" 2>/dev/null; then
        mkdir -p "$mnt_dir" 2>/dev/null
        chcon u:object_r:ksu_file:s0 "$img_file" 2>/dev/null
        mount -t ext4 -o loop,rw,noatime "$img_file" "$mnt_dir" 2>/dev/null
        export MODULE_CONTENT_DIR="$mnt_dir"
    fi
    
    if [ "$STEALTH_MODE" = "true" ]; then
        "$OVERLAY_BINARY" >/dev/null 2>&1
    else
        "$OVERLAY_BINARY"
    fi
    return $?
}

############################################
# 主程序
############################################

log_msg "=== Mount Started v3.4 ===" "START"

# 读取配置
read_config

log_msg "Global Mode: $GLOBAL_MOUNT_MODE" "INFO"
log_msg "Stealth: $STEALTH_MODE, Hide: $HIDE_MOUNTS" "DEBUG"
log_msg "Force Mount Modules: $FORCE_MOUNT_JSON" "DEBUG"
log_msg "Ignored Modules: $IGNORED_MODULES_JSON" "DEBUG"

# 确保所有必要的分区已挂载
ENABLED_PARTITIONS=$(get_enabled_partitions)
for partition in $ENABLED_PARTITIONS; do
    if ! is_partition_mounted "$partition"; then
        log_msg "Ensuring partition $partition is mounted" "DEBUG"
        ensure_partition_mounted "$partition" || log_msg "Could not mount $partition" "WARN"
    fi
done

# 应用挂载延迟
apply_mount_delay

EXIT_CODE=0

# v3.4.1 修复版：只有用户选择挂载模式的模块才会被挂载
# 显示/隐藏的模块不会自动被全局挂载
# 检查模块是否有指定的挂载模式（不在global状态）
has_module_specific_mode() {
    local module_name="$1"
    local module_mode=$(get_module_mount_mode "$module_name" "$MODULE_MODES_JSON")
    [ "$module_mode" != "global" ]
}

# 根据优化级别选择策略
case "$OPTIMIZATION_LEVEL" in
    2) # Ultra模式 - 使用模块级挂载
        log_msg "Ultra optimization mode" "DEBUG"
        
        MODULE_DIR="/data/adb/modules"
        SUCCESS_COUNT=0
        FAIL_COUNT=0
        SKIP_COUNT=0
        FORCE_COUNT=0
        IGNORE_COUNT=0
        NO_MODE_COUNT=0
        
        if [ -d "$MODULE_DIR" ]; then
            for mod in "$MODULE_DIR"/*; do
                [ -d "$mod" ] || continue
                
                MODULE_NAME=$(basename "$mod")
                
                # 跳过自身模块
                [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ] && continue
                
                # 检查是否被KernelSU卸载
                if is_module_disabled_by_ksu "$MODULE_NAME"; then
                    log_msg "Skipping: $MODULE_NAME (disabled by KSU)" "DEBUG"
                    SKIP_COUNT=$((SKIP_COUNT + 1))
                    continue
                fi
                
                # v3.4: 检查是否应该跳过（自定义忽略、原生ignore、skip_mount）
                if should_skip_module "$MODULE_NAME"; then
                    SKIP_COUNT=$((SKIP_COUNT + 1))
                    if is_custom_ignored "$MODULE_NAME"; then
                        IGNORE_COUNT=$((IGNORE_COUNT + 1))
                    fi
                    continue
                fi
                
                # v3.4.1: 检查模块是否有指定的挂载模式
                # 只有用户选择了特定挂载模式的模块才会被挂载
                if ! has_module_specific_mode "$MODULE_NAME"; then
                    # 检查是否是强制挂载
                    if ! is_force_mount "$MODULE_NAME"; then
                        log_msg "Skipping: $MODULE_NAME (no specific mount mode selected)" "DEBUG"
                        NO_MODE_COUNT=$((NO_MODE_COUNT + 1))
                        continue
                    fi
                fi
                
                # 获取模块挂载模式
                MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
                
                # 检查是否强制挂载
                if is_force_mount "$MODULE_NAME"; then
                    MODULE_MODE="force"
                    FORCE_COUNT=$((FORCE_COUNT + 1))
                fi
                
                # 使用模块特定模式或全局模式
                if [ "$MODULE_MODE" != "global" ] && [ "$MODULE_MODE" != "force" ]; then
                    USE_MODE="$MODULE_MODE"
                elif [ "$MODULE_MODE" = "force" ]; then
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                    log_msg "Force mounting: $MODULE_NAME with mode=$USE_MODE" "INFO"
                else
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                fi
                
                log_msg "Mounting: $MODULE_NAME with mode=$USE_MODE" "INFO"
                
                execute_mount "$MODULE_NAME" "$USE_MODE"
                if [ $? -eq 0 ]; then
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                else
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            done
            
            log_msg "Mount summary: success=$SUCCESS_COUNT failed=$FAIL_COUNT skipped=$SKIP_COUNT forced=$FORCE_COUNT ignored=$IGNORE_COUNT no_mode=$NO_MODE_COUNT" "INFO"
        fi
        ;;
    
    1) # Fast模式 - 只挂载用户选择的模块
        log_msg "Fast optimization mode" "DEBUG"
        
        MODULE_DIR="/data/adb/modules"
        SUCCESS_COUNT=0
        FAIL_COUNT=0
        NO_MODE_COUNT=0
        
        if [ -d "$MODULE_DIR" ]; then
            for mod in "$MODULE_DIR"/*; do
                [ -d "$mod" ] || continue
                
                MODULE_NAME=$(basename "$mod")
                
                # 跳过自身模块
                [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ] && continue
                
                # 检查是否被KernelSU卸载
                if is_module_disabled_by_ksu "$MODULE_NAME"; then
                    continue
                fi
                
                # 检查是否应该跳过
                if should_skip_module "$MODULE_NAME"; then
                    continue
                fi
                
                # 检查是否有指定的挂载模式
                if ! has_module_specific_mode "$MODULE_NAME"; then
                    if ! is_force_mount "$MODULE_NAME"; then
                        NO_MODE_COUNT=$((NO_MODE_COUNT + 1))
                        continue
                    fi
                fi
                
                # 获取模块挂载模式
                MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
                
                if is_force_mount "$MODULE_NAME"; then
                    MODULE_MODE="force"
                fi
                
                # 使用模块特定模式或全局模式
                if [ "$MODULE_MODE" != "global" ] && [ "$MODULE_MODE" != "force" ]; then
                    USE_MODE="$MODULE_MODE"
                elif [ "$MODULE_MODE" = "force" ]; then
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                else
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                fi
                
                execute_mount "$MODULE_NAME" "$USE_MODE"
                if [ $? -eq 0 ]; then
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                else
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            done
            
            log_msg "Fast mount summary: success=$SUCCESS_COUNT failed=$FAIL_COUNT no_mode=$NO_MODE_COUNT" "INFO"
        fi
        ;;
    
    *) # 禁用模式（标准）- 只挂载用户选择的模块
        log_msg "Standard mode" "DEBUG"
        
        MODULE_DIR="/data/adb/modules"
        SUCCESS_COUNT=0
        FAIL_COUNT=0
        NO_MODE_COUNT=0
        
        if [ -d "$MODULE_DIR" ]; then
            for mod in "$MODULE_DIR"/*; do
                [ -d "$mod" ] || continue
                
                MODULE_NAME=$(basename "$mod")
                
                # 跳过自身模块
                [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ] && continue
                
                # 检查是否被KernelSU卸载
                if is_module_disabled_by_ksu "$MODULE_NAME"; then
                    continue
                fi
                
                # 检查是否应该跳过
                if should_skip_module "$MODULE_NAME"; then
                    continue
                fi
                
                # 检查是否有指定的挂载模式
                if ! has_module_specific_mode "$MODULE_NAME"; then
                    if ! is_force_mount "$MODULE_NAME"; then
                        NO_MODE_COUNT=$((NO_MODE_COUNT + 1))
                        continue
                    fi
                fi
                
                # 获取模块挂载模式
                MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
                
                if is_force_mount "$MODULE_NAME"; then
                    MODULE_MODE="force"
                fi
                
                # 使用模块特定模式或全局模式
                if [ "$MODULE_MODE" != "global" ] && [ "$MODULE_MODE" != "force" ]; then
                    USE_MODE="$MODULE_MODE"
                elif [ "$MODULE_MODE" = "force" ]; then
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                else
                    USE_MODE="$GLOBAL_MOUNT_MODE"
                fi
                
                log_msg "Mounting: $MODULE_NAME with mode=$USE_MODE" "INFO"
                
                execute_mount "$MODULE_NAME" "$USE_MODE"
                if [ $? -eq 0 ]; then
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                else
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            done
            
            log_msg "Standard mount summary: success=$SUCCESS_COUNT failed=$FAIL_COUNT no_mode=$NO_MODE_COUNT" "INFO"
        fi
        ;;
esac

# 更新状态
update_status

log_msg "=== Mount Finished ===" "END"

exit $EXIT_CODE
