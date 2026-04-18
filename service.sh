#!/system/bin/sh
############################################
# Magic Mount Metaverse - service.sh
# Background service v2.3
# Author: GitHub@FHYUYO
############################################

MODDIR="${0%/*}"
UPDATER="$MODDIR/status_updater.sh"
CONFIG_DIR="/data/adb/magic_mount"
EXTENDED_CONFIG="$CONFIG_DIR/mm_extended.conf"

# 初始等待
INITIAL_WAIT=10
[ -f "$EXTENDED_CONFIG" ] && {
    OPT_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
    # Ultra模式下减少等待
    [ "$OPT_LEVEL" = "2" ] && INITIAL_WAIT=3
    [ "$OPT_LEVEL" = "1" ] && INITIAL_WAIT=5
}

sleep "$INITIAL_WAIT"

# 首次更新状态
if [ -f "$UPDATER" ]; then
    sh "$UPDATER"
fi

# 后台循环更新状态
while [ -f "$MODDIR/module.prop" ]; do
    sleep 30
    
    # 检查模块是否仍然存在
    if [ ! -d "/data/adb/modules/Magic-Mount-Metaverse" ]; then
        break
    fi
    
    # 更新状态
    if [ -f "$UPDATER" ]; then
        sh "$UPDATER"
    fi
done

exit 0
