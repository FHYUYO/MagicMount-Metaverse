#!/system/bin/sh
############################################
# Dynamic Status Updater v3.0
# Updates module.prop description in KSU list
# Fixed: Enhanced per-module mount mode parsing
############################################

MODDIR="${0%/*}"
MODULE_PROP="$MODDIR/module.prop"
CONFIG_DIR="/data/adb/magic_mount"
EXTENDED_CONFIG="$CONFIG_DIR/mm_extended.conf"
LOG_FILE="$CONFIG_DIR/mm.log"

# 默认值
GLOBAL_MODE="magic"
MODULE_MODES_JSON="{}"


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
    fi
    
    [ -z "$GLOBAL_MODE" ] && GLOBAL_MODE="magic"
    [ -z "$MODULE_MODES_JSON" ] && MODULE_MODES_JSON="{}"
}

# 获取模块挂载模式
get_module_mode() {
    local module_name="$1"
    local mode=""
    
    # 从JSON中提取模块模式
    mode=$(echo "$MODULE_MODES_JSON" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        echo "$mode" | sed 's/.*":"//' | tr -d '"'
        return
    fi
    
    # 默认使用全局模式
    echo "global"
}

# 统计模块数量
count_modules() {
    local magic=0
    local overlayfs=0
    
    read_global_config
    
    local MODULE_DIR="/data/adb/modules"
    
    # 统计
    for mod in "$MODULE_DIR"/*; do
        # 基本检查
        [ -d "$mod" ] || continue
        is_module_mountable "$mod" || continue
        
        local name=$(basename "$mod")
        
        # 跳过自身和禁用的模块
        [ "$name" = "Magic-Mount-Metaverse" ] && continue
        [ -e "$mod/disable" ] || [ -e "$mod/remove" ] && continue
        [ -e "$mod/skip_mount" ] && continue
        
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
    
    echo "$magic|$overlayfs"
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
        [ -e "$mod/skip_mount" ] && continue
        
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
    
    # 构建描述
    local desc=""
    
    # 根据模块数量决定显示格式
    local total=$((magic + overlayfs))
    
    if [ "$total" -eq 0 ]; then
        desc="Magic: 0 | Overlayfs: 0 | Ready"
    else
        desc="Magic:$magic | Overlayfs:$overlayfs | Ready"
    fi
    
    # 如果有全局模式信息
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
                return 0
            fi
            
            # 如果sed失败，使用备份方法
            if grep -v "^description=" "$MODULE_PROP" > "${tmp}" 2>/dev/null; then
                echo "description=${desc}" >> "${tmp}"
                cat "${tmp}" > "$MODULE_PROP"
                rm -f "${tmp}"
            fi
        fi
    fi
    
    return 0
}

# 备用更新方法（处理并发）
update_prop_backup() {
    local stats=$(count_modules)
    local magic=$(echo "$stats" | cut -d'|' -f1)
    local overlayfs=$(echo "$stats" | cut -d'|' -f2)
    local total=$((magic + overlayfs))
    
    local desc=""
    if [ "$total" -eq 0 ]; then
        desc="Magic: 0 | Overlayfs: 0 | Ready"
    else
        desc="Magic:$magic | Overlayfs:$overlayfs | Ready"
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
        fi
    fi
}

# 主程序
main() {
    update_prop || update_prop_backup
}

# 运行
main
