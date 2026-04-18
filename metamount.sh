#!/system/bin/sh
############################################
# Magic Mount Metaverse - metamount.sh
# Enhanced mount script v2.3
# Author: GitHub@FHYUYO/酷安@枫原羽悠
# Fixed: Per-module mount mode support
############################################

MODDIR="${0%/*}"
EXTENDED_CONFIG="/data/adb/magic_mount/mm_extended.conf"
LOG_FILE="/data/adb/magic_mount/mm.log"

# 二进制文件
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

# 关联数组支持
if [ -z "$BASH_VERSION" ]; then
    # 为ash/sh准备替代方案
    get_module_mode() {
        local module_name="$1"
        local module_modes="$2"
        # 使用grep提取JSON中的模块模式
        echo "$module_modes" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | cut -d':' -f2 | tr -d '"'
    }
else
    declare -A MODULE_MODE_MAP
    get_module_mode() {
        local module_name="$1"
        echo "${MODULE_MODE_MAP[$module_name]}"
    }
fi

# 日志函数（增强过滤）
log_msg() {
    local msg="$1"
    local level="${2:-INFO}"
    
    # 过滤敏感关键词（增强版）
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
    
    # 脱敏敏感路径
    msg=$(echo "$msg" | sed \
        -e 's|/data/adb/modules|<MODULES>|g' \
        -e 's|/data/adb/magic_mount|<MM_DIR>|g' \
        -e 's|/system/system|<SYSTEM>|g' \
        -e 's|/product/system|<PRODUCT>|g' \
        -e 's|/vendor/system|<VENDOR>|g' \
        -e 's|/system_ext/system|<EXT>|g')
    
    echo "[$level] $msg" >> "$LOG_FILE" 2>/dev/null
}

# 读取配置（增强版）
read_config() {
    GLOBAL_MOUNT_MODE="magic"
    HIDE_MOUNTS="false"
    STEALTH_MODE="false"
    PARALLEL_MOUNT="false"
    OPTIMIZATION_LEVEL="0"
    MOUNT_DELAY="0"
    MODULE_MODES_JSON="{}"
    
    if [ -f "$EXTENDED_CONFIG" ]; then
        # 使用更健壮的配置读取
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

# 解析模块挂载模式（修复版）
parse_module_modes() {
    local module_modes_json="$1"
    
    # 提取JSON中的键值对
    echo "$module_modes_json" | sed 's/[{}"]//g' | tr ',' '\n' | while IFS=: read -r key value; do
        key=$(echo "$key" | tr -d ' "')
        value=$(echo "$value" | tr -d ' "')
        if [ -n "$key" ] && [ -n "$value" ]; then
            echo "$key:$value"
        fi
    done
}

# 获取模块的挂载模式
get_module_mount_mode() {
    local module_name="$1"
    local module_modes_json="$2"
    
    # 尝试从JSON中提取该模块的模式
    local mode=$(echo "$module_modes_json" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        echo "$mode" | sed 's/.*":"//' | tr -d '"'
    else
        echo "global"
    fi
}

# 设置环境变量
setup_env() {
    export MODULE_METADATA_DIR="/data/adb/modules"
    export MM_STEALTH_MODE="$STEALTH_MODE"
    export MM_HIDE_LOGS="$HIDE_MOUNTS"
}

# 延迟执行（用于性能优化）
apply_mount_delay() {
    if [ -n "$MOUNT_DELAY" ] && [ "$MOUNT_DELAY" -gt 0 ] 2>/dev/null; then
        local delay_sec=$(echo "scale=2; $MOUNT_DELAY / 1000" | bc 2>/dev/null || echo "0")
        [ -n "$delay_sec" ] && [ "$delay_sec" != "0" ] && sleep "$delay_sec"
    fi
}

# Magic 挂载（优化版）
do_magic_mount() {
    local module_name="$1"
    
    log_msg "Magic mount for: $module_name" "INFO"
    
    if [ ! -f "$MM_BINARY" ]; then
        log_msg "Binary not found: $MM_BINARY" "ERROR"
        return 1
    fi
    
    # 根据隐身模式选择输出
    if [ "$STEALTH_MODE" = "true" ]; then
        "$MM_BINARY" "$module_name" >/dev/null 2>&1
    else
        "$MM_BINARY" "$module_name"
    fi
    return $?
}

# OverlayFS 挂载（优化版）
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
        # 尝试设置SELinux上下文
        chcon u:object_r:ksu_file:s0 "$img_file" 2>/dev/null
        # 尝试挂载
        mount -t ext4 -o loop,rw,noatime "$img_file" "$mnt_dir" 2>/dev/null
        if mountpoint -q "$mnt_dir" 2>/dev/null; then
            export MODULE_CONTENT_DIR="$mnt_dir"
            log_msg "modules.img mounted at $mnt_dir" "DEBUG"
        fi
    fi
    
    # 根据隐身模式选择输出
    if [ "$STEALTH_MODE" = "true" ]; then
        "$OVERLAY_BINARY" "$module_name" >/dev/null 2>&1
    else
        "$OVERLAY_BINARY" "$module_name"
    fi
    return $?
}

# 执行挂载（根据模式选择）
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

# 清理日志（增强版）
sanitize_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        return
    fi
    
    # 创建临时文件
    local tmp_file="${LOG_FILE}.sanitized"
    
    # 深度脱敏处理
    sed -i \
        -e '/password/d' \
        -e '/secret/d' \
        -e '/token/d' \
        -e '/key=/d' \
        -e '/credential/d' \
        -e '/unmount=/d' \
        -e 's/mounting.*module:[^ ]*/Mount operation/g' \
        -e 's|/data/adb/modules|<MODULES>|g' \
        -e 's|/data/adb/magic_mount|<MM>|g' \
        -e 's|/system/system|<SYS>|g' \
        -e 's|/product/system|<PRD>|g' \
        -e 's|/vendor/system|<VND>|g' \
        "$LOG_FILE" 2>/dev/null
    # 日志行数限制已移除，无限制记录日志
}

# 更新状态显示
update_status() {
    if [ -f "$STATUS_UPDATER" ]; then
        sh "$STATUS_UPDATER" 2>/dev/null &
    fi
}

# 全局挂载模式（兼容旧版mmd）
do_global_mount() {
    log_msg "Using global mount mode: $GLOBAL_MOUNT_MODE" "INFO"
    
    if [ ! -f "$MM_BINARY" ]; then
        log_msg "Binary not found: $MM_BINARY" "ERROR"
        return 1
    fi
    
    # 根据隐身模式选择输出
    if [ "$STEALTH_MODE" = "true" ]; then
        "$MM_BINARY" >/dev/null 2>&1
    else
        "$MM_BINARY"
    fi
    return $?
}

# 全局OverlayFS挂载（兼容旧版mm_overlay）
do_global_overlayfs_mount() {
    log_msg "Using global OverlayFS mode" "INFO"
    
    if [ ! -f "$OVERLAY_BINARY" ]; then
        log_msg "Overlay binary not found" "ERROR"
        return 1
    fi
    
    # 挂载 modules.img
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

log_msg "=== Mount Started ===" "START"

read_config
setup_env

log_msg "Global Mode: $GLOBAL_MOUNT_MODE" "INFO"
log_msg "Stealth: $STEALTH_MODE, Hide: $HIDE_MOUNTS" "DEBUG"

# 应用挂载延迟
apply_mount_delay

# 根据优化级别选择策略
EXIT_CODE=0

case "$OPTIMIZATION_LEVEL" in
    2) # Ultra模式 - 使用新版模块级挂载
        log_msg "Ultra optimization mode" "DEBUG"
        
        # 检查是否支持模块级挂载
        if [ -f "$MM_BINARY" ] && "$MM_BINARY" --help 2>&1 | grep -q "module"; then
            # 新版mmd支持模块级挂载
            MODULE_DIR="/data/adb/modules"
            SUCCESS_COUNT=0
            FAIL_COUNT=0
            
            if [ -d "$MODULE_DIR" ]; then
                for mod in "$MODULE_DIR"/*; do
                    [ -d "$mod" ] || continue
                    [ -d "$mod/system" ] || continue
                    
                    MODULE_NAME=$(basename "$mod")
                    [ "$MODULE_NAME" = "Magic-Mount-Metaverse" ] && continue
                    [ -e "$mod/disable" ] || [ -e "$mod/remove" ] && continue
                    [ -e "$mod/skip_mount" ] && continue
                    
                    # 获取模块挂载模式
                    MODULE_MODE=$(get_module_mount_mode "$MODULE_NAME" "$MODULE_MODES_JSON")
                    
                    # 忽略模式
                    if [ "$MODULE_MODE" = "ignore" ]; then
                        log_msg "Skipping: $MODULE_NAME (ignore mode)" "DEBUG"
                        continue
                    fi
                    
                    # 使用模块特定模式或全局模式
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
                
                log_msg "Mount summary: success=$SUCCESS_COUNT failed=$FAIL_COUNT" "INFO"
            fi
        else
            # 旧版mmd，回退到全局模式
            log_msg "Legacy mode, using global mount" "DEBUG"
            do_global_mount
            EXIT_CODE=$?
        fi
        ;;
    
    1) # Fast模式 - 尝试模块级挂载，回退到全局
        log_msg "Fast optimization mode" "DEBUG"
        
        if [ -f "$MM_BINARY" ]; then
            do_global_mount
            EXIT_CODE=$?
        else
            EXIT_CODE=1
        fi
        ;;
    
    *) # 标准模式 - 使用全局模式
        log_msg "Standard mode" "DEBUG"
        
        case "$GLOBAL_MOUNT_MODE" in
            overlayfs)
                do_global_overlayfs_mount
                EXIT_CODE=$?
                ;;
            *)
                do_global_mount
                EXIT_CODE=$?
                ;;
        esac
        ;;
esac

if [ $EXIT_CODE -eq 0 ]; then
    log_msg "Mount completed successfully" "SUCCESS"
    sanitize_logs
    /data/adb/ksud kernel notify-module-mounted 2>/dev/null
    sleep 1
    update_status
else
    log_msg "Mount failed with code: $EXIT_CODE" "ERROR"
fi

log_msg "=== Mount Finished ===" "END"
exit $EXIT_CODE
