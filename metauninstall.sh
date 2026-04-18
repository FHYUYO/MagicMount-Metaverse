#!/system/bin/sh
############################################
# Magic Mount Metaverse - metauninstall.sh
# Pre-uninstallation cleanup v2.3
# Author: GitHub@FHYUYO
############################################

MODULE_DATA_DIR="/data/adb/magic_mount"
METAMODULE_LINK="/data/adb/metamodule"
MODULE_ID="Magic-Mount-Metaverse"

# 日志函数
log() {
    local msg="[MetaUninstall] $1"
    echo "$msg" >> "$MODULE_DATA_DIR/mm.log" 2>/dev/null
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

# 清理临时文件
rm -f "$MODULE_DATA_DIR/mm.log" 2>/dev/null
rm -f "$MODULE_DATA_DIR/mm.log.old" 2>/dev/null

log "Cleanup complete"
exit 0
