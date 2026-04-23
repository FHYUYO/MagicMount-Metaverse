#!/system/bin/sh
############################################
# Magic Mount Metaverse - metauninstall.sh
# Pre-uninstallation cleanup v3.4.2
# Author: GitHub@FHYUYO
# v3.4.2: Log path unified to /data/adb/Metaverse/运行日志.log
############################################

MODULE_DATA_DIR="/data/adb/Metaverse"
METAMODULE_LINK="/data/adb/metamodule"
MODULE_ID="Magic-Mount-Metaverse"
LOG_FILE="/data/adb/Metaverse/运行日志.log"
OLD_LOG_FILE="$MODULE_DATA_DIR/运行日志.log"

# 日志函数
log() {
    local msg="[MetaUninstall] $1"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null
}

log "Cleanup started for Magic Mount Metaverse"

# 移除 metamodule 符号链接
if [ -L "$METAMODULE_LINK" ]; then
    link_target=$(realpath "$METAMODULE_LINK" 2>/dev/null)
    if [ -n "$link_target" ]; then
        if [ "$(basename "$link_target")" = "$MODULE_ID" ]; then
            rm -f "$METAMODULE_LINK"
            log "Removed metamodule link"
        fi
    else
        # 如果realpath失败，直接删除链接
        rm -f "$METAMODULE_LINK"
        log "Removed invalid metamodule link"
    fi
fi

# 获取模块目录
MODDIR="${0%/*}"

# 清理挂载点
if [ -d "$MODDIR/mnt" ]; then
    # 尝试多种方式卸载
    umount -l "$MODDIR/mnt" 2>/dev/null
    umount "$MODDIR/mnt" 2>/dev/null
    rmdir "$MODDIR/mnt" 2>/dev/null
    log "Cleaned up mount point"
fi

# 卸载 modules.img
if [ -f "$MODDIR/modules.img" ]; then
    if mountpoint -q "$MODDIR/mnt" 2>/dev/null; then
        umount -l "$MODDIR/mnt" 2>/dev/null
    fi
    log "modules.img unmounted"
fi

# 清理临时文件（同时清理新旧日志文件路径）
rm -f "$LOG_FILE" 2>/dev/null
rm -f "$OLD_LOG_FILE" 2>/dev/null
rm -f "$OLD_LOG_FILE.old" 2>/dev/null

log "Cleanup complete"
exit 0
