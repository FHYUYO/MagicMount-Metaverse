#!/system/bin/sh
############################################
# Magic Mount Metaverse - service.sh
# Background service v3.4.2
# Author: GitHub@FHYUYO
# Enhanced: Log path unified to /data/adb/Metaverse/运行日志.log
############################################

MODDIR="${0%/*}"
UPDATER="$MODDIR/status_updater.sh"
CONFIG_DIR="/data/adb/Metaverse"
EXTENDED_CONFIG="/data/adb/Metaverse/扩展配置.conf"
LOG_FILE="/data/adb/Metaverse/运行日志.log"

# 日志函数
log_msg() {
    local msg="$1"
    local level="${2:-"信息"}"
    echo "[$level] $(date '+%m-%d %H:%M:%S') $msg" >> "$LOG_FILE" 2>/dev/null
}

# 初始等待时间
INITIAL_WAIT=10
if [ -f "$EXTENDED_CONFIG" ]; then
    OPT_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
    # 根据优化级别调整等待时间
    case "$OPT_LEVEL" in
        2) INITIAL_WAIT=3 && log_msg "极致模式: 等待3秒后启动" "信息" ;;
        1) INITIAL_WAIT=5 && log_msg "快速模式: 等待5秒后启动" "信息" ;;
        *) INITIAL_WAIT=10 && log_msg "标准模式: 等待10秒后启动" "信息" ;;
    esac
fi

log_msg "服务启动，等待 $INITIAL_WAIT 秒..." "信息"
sleep "$INITIAL_WAIT"

# 首次更新状态
if [ -f "$UPDATER" ]; then
    log_msg "执行首次状态更新" "信息"
    sh "$UPDATER"
fi

# 后台循环更新状态
log_msg "进入后台状态监控循环" "信息"
while [ -f "$MODDIR/module.prop" ]; do
    sleep 30
    
    # 检查模块是否仍然存在
    if [ ! -d "/data/adb/modules/Magic-Mount-Metaverse" ]; then
        log_msg "检测到模块已移除，退出服务" "信息"
        break
    fi
    
    # 更新状态
    if [ -f "$UPDATER" ]; then
        sh "$UPDATER"
    fi
done

log_msg "服务已退出" "信息"
exit 0
