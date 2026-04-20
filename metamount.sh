#!/system/bin/sh
############################################
# Magic Mount Metaverse - metamount.sh
# Enhanced mount script v3.0
# Author: GitHub@FHYUYO/酷安@枫原羽悠
# Fixed: Per-module mount mode, removed ignore mode
# Fixed: Boot issue with KernelSU uninstall detection
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
    
    if [ -f "$EXTENDED_CONFIG" ]; then
        GLOBAL_MOUNT_MODE=$(grep -E "^[[:space:]]*mount_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        HIDE_MOUNTS=$(grep -E "^[[:space:]]*hide_mount_logs[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        STEALTH_MODE=$(grep -E "^[[:space:]]*stealth_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        PARALLEL_MOUNT=$(grep -E "^[[:space:]]*parallel_mount[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        OPTIMIZATION_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        MOUNT_DELAY=$(grep -E "^[[:space:]]*mount_delay[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        MODULE_MODES_JSON=$(grep -E "^[[:space:]]*module_mount_modes[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
    fi
    
    # 设置默认值
    [ -z "$GLOBAL_MOUNT_MODE" ] && GLOBAL_MOUNT_MODE="magic"
    [ -z "$HIDE_MOUNTS" ] && HIDE_MOUNTS="false"
    [ -z "$STEALTH_MODE" ] && STEALTH_MODE="false"
    [ -z "$PARALLEL_MOUNT" ] && PARALLEL_MOUNT="false"
    [ -z "$OPTIMIZATION_LEVEL" ] && OPTIMIZATION_LEVEL="0"
    [ -z "$MOUNT_DELAY" ] && MOUNT_DELAY="0"
    [ -z "$MODULE_MODES_JSON" ] && MODULE_MODES_JSON="{}"
    
    log_msg "Config loaded: mode=$GLOBAL_MOUNT_MODE stealth=$STEALTH_MODE" "DEBUG"
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
    
    if [ ! -f "$MM_BINARY" ]; then
        log_msg "Binary not found: $MM_BINARY" "ERROR"
        return 1
    fi
    
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
        
        if [ $? -eq 0 ]; then
            return 0
        fi
        
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
    
    # 检查disable文件（KernelSU卸载标志）
    if [ -f "$module_path/disable" ] || [ -f "$module_path/remove" ]; then
        return 0  # 已卸载
    fi
    
    return 1  # 未卸载
}

# 检查模块是否有skip_mount标记
has_skip_mount() {
    local module_name="$1"
    local module_path="/data/adb/modules/$module_name"
    
    if [ -f "$module_path/skip_mount" ]; then
        return 0  # 跳过挂载
    fi
    
    return 1  # 正常挂载
}

# 更新状态显示
update_status() {
    if [ -f "$STATUS_UPDATER" ]; then
        sh "$STATUS_UPDATER" 2>/dev/null &
    fi
}

# 全局挂载
do_global_mount() {
    log_msg "Using global mount mode: $GLOBAL_MOUNT_MODE" "INFO"
    
    if [ ! -f "$MM_BINARY" ]; then
        log_msg "Binary not found: $MM_BINARY" "ERROR"
        return 1
    fi
    
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
    
    if [ ! -f "$OVERLAY_BINARY" ]; then
        log_msg "Overlay binary not found" "ERROR"
        return 1
    fi
    
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

log_msg "=== Mount Started v3.0 ===" "START"

# 读取配置
read_config

log_msg "Global Mode: $GLOBAL_MOUNT_MODE" "INFO"
log_msg "Stealth: $STEALTH_MODE, Hide: $HIDE_MOUNTS" "DEBUG"

# 应用挂载延迟
apply_mount_delay

EXIT_CODE=0

# 根据优化级别选择策略
case "$OPTIMIZATION_LEVEL" in
    2) # Ultra模式 - 使用模块级挂载
        log_msg "Ultra optimization mode" "DEBUG"
        
        MODULE_DIR="/data/adb/modules"
        SUCCESS_COUNT=0
        FAIL_COUNT=0
        SKIP_COUNT=0
        
        if [ -d "$MODULE_DIR" ]; then
            for mod in "$MODULE_DIR"/*; do
                [ -d "$mod" ] || continue
                [ -d "$mod/system" ] || continue
                
                MODULE_NAME=$(basename "$mod")
                
                # 跳过自身模块
                [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ] && continue
                
                # 检查是否被KernelSU卸载
                if is_module_disabled_by_ksu "$MODULE_NAME"; then
                    log_msg "Skipping: $MODULE_NAME (disabled by KSU)" "DEBUG"
                    SKIP_COUNT=$((SKIP_COUNT + 1))
                    continue
                fi
                
                # 检查skip_mount标记
                if has_skip_mount "$MODULE_NAME"; then
                    log_msg "Skipping: $MODULE_NAME (skip_mount)" "DEBUG"
                    SKIP_COUNT=$((SKIP_COUNT + 1))
                    continue
                fi
                
                # 获取模块挂载模式
                MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
                
                # 使用模块特定模式或全局模式（不再有ignore模式）
                if [ "$MODULE_MODE" != "global" ]; then
                    USE_MODE="$MODULE_MODE"
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
            
            log_msg "Mount summary: success=$SUCCESS_COUNT failed=$FAIL_COUNT skipped=$SKIP_COUNT" "INFO"
        fi
        ;;
    
    1) # Fast模式
        log_msg "Fast optimization mode" "DEBUG"
        
        if [ -f "$MM_BINARY" ]; then
            do_global_mount
            EXIT_CODE=$?
        else
            log_msg "mmd binary not found" "ERROR"
            EXIT_CODE=1
        fi
        ;;
    
    *) # 禁用模式（标准）
        log_msg "Standard mode" "DEBUG"
        
        if [ "$GLOBAL_MOUNT_MODE" = "overlayfs" ]; then
            do_global_overlayfs_mount
            EXIT_CODE=$?
        else
            do_global_mount
            EXIT_CODE=$?
        fi
        ;;
esac

# 更新状态
update_status

log_msg "=== Mount Finished ===" "END"

exit $EXIT_CODE
