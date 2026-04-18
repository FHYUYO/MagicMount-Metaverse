#!/system/bin/sh
############################################
# Magic Mount Metaverse Uninstall Script v2.3
# Author: GitHub@FHYUYO
############################################

MODULE_DATA_DIR="/data/adb/magic_mount"

ui_print ""
ui_print "========================================"
ui_print "  Magic Mount Metaverse Uninstaller"
ui_print "========================================"
ui_print ""

# 清理符号链接
METAMODULE_LINK="/data/adb/metamodule"
if [ -L "$METAMODULE_LINK" ]; then
    rm -f "$METAMODULE_LINK" 2>/dev/null
    ui_print "[*] Removed metamodule link"
fi

# 清理挂载
MODDIR="/data/adb/modules/Magic-Mount-Metaverse"
if [ -d "$MODDIR/mnt" ]; then
    umount -l "$MODDIR/mnt" 2>/dev/null
    rmdir "$MODDIR/mnt" 2>/dev/null
    ui_print "[*] Cleaned up mount points"
fi

# 提示用户
ui_print ""
ui_print "[*] Module will be removed on next reboot"
ui_print ""

exit 0
