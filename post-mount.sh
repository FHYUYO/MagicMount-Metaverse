#!/system/bin/sh
############################################
# Magic Mount Metaverse - post-mount.sh
# Post-mount hook v3.0
# Author: GitHub@FHYUYO
############################################

MODDIR="${0%/*}"
STATUS_UPDATER="$MODDIR/status_updater.sh"
CONFIG_DIR="/data/adb/magic_mount"
EXTENDED_CONFIG="$CONFIG_DIR/mm_extended.conf"

# 读取优化级别
OPT_LEVEL="0"
if [ -f "$EXTENDED_CONFIG" ]; then
    OPT_LEVEL=$(grep -E "^[[:space:]]*optimization_level[[:space:]]*=" "$EXTENDED_CONFIG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' "\r\n')
    [ -z "$OPT_LEVEL" ] && OPT_LEVEL="0"
fi

# 根据优化级别决定等待时间
case "$OPT_LEVEL" in
    2) INITIAL_WAIT=1 ;;
    1) INITIAL_WAIT=2 ;;
    *) INITIAL_WAIT=2 ;;
esac

sleep "$INITIAL_WAIT"

# 更新状态
if [ -f "$STATUS_UPDATER" ]; then
    sh "$STATUS_UPDATER"
fi

exit 0
