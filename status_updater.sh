#!/system/bin/sh
############################################
# Dynamic Status Updater v3.4.2
# Updates module.prop description in KSU list
# Fixed: Log path unified to /data/adb/Metaverse/运行日志.log
# Enhanced: Chinese labels
############################################

MODDIR="${0%/*}"
MODULE_PROP="$MODDIR/module.prop"
CONFIG_DIR="/data/adb/Metaverse"
EXTENDED_CONFIG="/data/adb/Metaverse/扩展配置.conf"
LOG_FILE="/data/adb/Metaverse/运行日志.log"

# 默认值
GLOBAL_MODE="magic"
MODULE_MODES_JSON="{}"
FORCE_MOUNT_JSON="{}"
IGNORED_MODULES_JSON="{}"

# 日志函数
log_msg() {
    local msg="$1"
    local level="${2:-"信息"}"
    echo "[$level] $(date '+%m-%d %H:%M:%S') $msg" >> "$LOG_FILE" 2>/dev/null
}

# 检查模块是否包含可挂载的分区
is_module_mountable() {
    local mod="$1"
    for part in system vendor odm my_product system_ext product vendor_dlkm odm_dlkm system_dlkm; do
        [ -d "$mod/$part" ] && return 0
    done
    return 1
}

# 读取全局配置
read_global_config() {
    if [ -f "$EXTENDED_CONFIG" ]; then
        GLOBAL_MODE=$(grep -E "^[[:space:]]*mount_mode[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
        MODULE_MODES_JSON=$(grep -E "^[[:space:]]*module_mount_modes[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        FORCE_MOUNT_JSON=$(grep -E "^[[:space:]]*force_mount_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
        IGNORED_MODULES_JSON=$(grep -E "^[[:space:]]*ignored_modules[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//')
    fi
    
    [ -z "$GLOBAL_MODE" ] && GLOBAL_MODE="magic"
    [ -z "$MODULE_MODES_JSON" ] && MODULE_MODES_JSON="{}"
    [ -z "$FORCE_MOUNT_JSON" ] && FORCE_MOUNT_JSON="{}"
    [ -z "$IGNORED_MODULES_JSON" ] && IGNORED_MODULES_JSON="{}"
}

# 检查模块是否被强制挂载
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

# 获取模块挂载模式
get_module_mode() {
    local module_name="$1"
    local mode=""
    
    mode=$(echo "$MODULE_MODES_JSON" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        echo "$mode" | sed 's/.*":"//' | tr -d '"'
        return
    fi
    
    echo "global"
}

# 统计模块数量
count_modules() {
    local magic=0
    local overlayfs=0
    local skipped=0
    
    read_global_config
    
    local MODULE_DIR="/data/adb/modules"
    
    for mod in "$MODULE_DIR"/*; do
        # 基本检查
        [ -d "$mod" ] || continue
        is_module_mountable "$mod" || continue
        
        local name=$(basename "$mod")
        
        # 跳过自身模块
        [ "$name" = "Magic-Mount-Metaverse" ] && continue
        
        # 检查是否被KSU禁用
        if [ -e "$mod/disable" ] || [ -e "$mod/remove" ]; then
            continue
        fi
        
        # 检查是否被自定义忽略
        if is_custom_ignored "$name"; then
            continue
        fi
        
        # 检查是否有skip_mount标记 - 这些模块不应显示为已挂载
        if [ -e "$mod/skip_mount" ]; then
            # 但force_mount可以覆盖
            if ! is_force_mount "$name"; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        
        # 检查是否有原生ignore标记
        if [ -e "$mod/ignore" ]; then
            # 但force_mount可以覆盖
            if ! is_force_mount "$name"; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        
        # 获取模块挂载模式
        local mode=$(get_module_mode "$name")
        
        # 使用模块模式或全局模式
        if [ "$mode" = "global" ]; then
            mode="$GLOBAL_MODE"
        fi
        
        case "$mode" in
            overlayfs)
                overlayfs=$((overlayfs + 1))
                ;;
            magic|*)
                magic=$((magic + 1))
                ;;
        esac
    done
    
    echo "$magic|$overlayfs|$skipped"
}

# 获取状态
get_status() {
    # 检查进程
    if pgrep -f "mmd|mm_overlay" >/dev/null 2>&1; then
        echo "Running"
        return
    fi
    
    # 检查挂载点
    if mountpoint -q "/data/adb/modules/.rw" 2>/dev/null; then
        echo "Mounted"
        return
    fi
    
    # 检查modules_rw目录
    if [ -d "/data/adb/modules_rw" ] || [ -d "/data/adb/.modules_rw" ]; then
        echo "Active"
        return
    fi
    
    # 检查日志文件时间戳
    if [ -f "$LOG_FILE" ]; then
        local log_time=$(stat -c %Y "$LOG_FILE" 2>/dev/null)
        local current_time=$(date +%s 2>/dev/null)
        
        if [ -n "$log_time" ] && [ -n "$current_time" ]; then
            local diff=$((current_time - log_time))
            if [ "$diff" -lt 300 ]; then
                echo "Active"
                return
            fi
        fi
    fi
    
    echo "Ready"
}

# 获取模块列表（用于显示）
get_module_list() {
    read_global_config
    
    local MODULE_DIR="/data/adb/modules"
    local result=""
    
    for mod in "$MODULE_DIR"/*; do
        [ -d "$mod" ] || continue
        is_module_mountable "$mod" || continue
        
        local name=$(basename "$mod")
        [ "$name" = "Magic-Mount-Metaverse" ] && continue
        [ -e "$mod/disable" ] || [ -e "$mod/remove" ] && continue
        [ -e "$mod/skip_mount" ] && ! is_force_mount "$name" && continue
        [ -e "$mod/ignore" ] && ! is_force_mount "$name" && continue
        if is_custom_ignored "$name"; then
            continue
        fi
        
        local mode=$(get_module_mode "$name")
        if [ "$mode" = "global" ]; then
            mode="$GLOBAL_MODE"
        fi
        
        result="${result}${name}:${mode},"
    done
    
    echo "$result" | sed 's/,$//'
}

# 更新 module.prop
update_prop() {
    local stats=$(count_modules)
    local magic=$(echo "$stats" | cut -d'|' -f1)
    local overlayfs=$(echo "$stats" | cut -d'|' -f2)
    local skipped=$(echo "$stats" | cut -d'|' -f3)
    
    # 构建描述
    local desc=""
    
    # 根据模块数量决定显示格式
    local total=$((magic + overlayfs))
    
    if [ "$total" -eq 0 ]; then
        desc="Magic: 0 | OverlayFS: 0 | 状态: 就绪"
    else
        desc="Magic:$magic | OverlayFS:$overlayfs | 状态: 运行中"
    fi
    
    # 如果有跳过/忽略的模块
    if [ "$skipped" -gt 0 ]; then
        desc="${desc} | 跳过:$skipped"
    fi
    
    # 如果全局模式不是magic
    if [ "$GLOBAL_MODE" != "magic" ]; then
        desc="${desc} [${GLOBAL_MODE^^}]"
    fi
    
    # 更新 module.prop
    if [ -f "$MODULE_PROP" ]; then
        local tmp="${MODULE_PROP}.tmp"
        
        # 使用更安全的方式更新
        if [ -w "$MODULE_PROP" ]; then
            sed -i "s/^description=.*/description=${desc}/" "$MODULE_PROP" 2>/dev/null
            
            # 验证更新
            if grep -q "^description=${desc}" "$MODULE_PROP"; then
                log_msg "状态已更新: $desc" "调试"
                return 0
            fi
            
            # 如果sed失败，使用备份方法
            if grep -v "^description=" "$MODULE_PROP" > "${tmp}" 2>/dev/null; then
                echo "description=$desc" >> "${tmp}"
                cat "${tmp}" > "$MODULE_PROP"
                rm -f "${tmp}"
                log_msg "状态已更新(备份方法): $desc" "调试"
            fi
        fi
    fi
    
    return 0
}

# 备用更新方法
update_prop_backup() {
    local stats=$(count_modules)
    local magic=$(echo "$stats" | cut -d'|' -f1)
    local overlayfs=$(echo "$stats" | cut -d'|' -f2)
    local skipped=$(echo "$stats" | cut -d'|' -f3)
    local total=$((magic + overlayfs))
    
    local desc=""
    if [ "$total" -eq 0 ]; then
        desc="Magic: 0 | OverlayFS: 0 | 状态: 就绪"
    else
        desc="Magic:$magic | OverlayFS:$overlayfs | 状态: 运行中"
    fi
    
    if [ "$skipped" -gt 0 ]; then
        desc="${desc} | 跳过:$skipped"
    fi
    
    if [ "$GLOBAL_MODE" != "magic" ]; then
        desc="${desc} [${GLOBAL_MODE^^}]"
    fi
    
    if [ -f "$MODULE_PROP" ]; then
        > "${MODULE_PROP}.new"
        while IFS= read -r line; do
            if echo "$line" | grep -q "^description="; then
                echo "description=$desc"
            else
                echo "$line"
            fi
        done < "$MODULE_PROP" >> "${MODULE_PROP}.new"
        
        if [ -f "${MODULE_PROP}.new" ]; then
            cat "${MODULE_PROP}.new" > "$MODULE_PROP"
            rm -f "${MODULE_PROP}.new"
            log_msg "状态已更新(备用方法): $desc" "调试"
        fi
    fi
}

# 主程序
main() {
    log_msg "状态更新开始" "调试"
    update_prop || update_prop_backup
    log_msg "状态更新完成" "调试"
}

# 运行
main
