#!/system/bin/sh
############################################
# Magic Mount Metaverse - uninstall.sh
# Version: v3.3
############################################

MODPATH="/data/adb/modules/Magic-Mount-Metaverse"

ui_print ""
ui_print "Uninstalling Magic Mount Metaverse v3.3..."

# 清理二进制文件
if [ -f "$MODPATH/mmd" ]; then
    rm -f "$MODPATH/mmd"
fi

if [ -f "$MODPATH/mm_overlay" ]; then
    rm -f "$MODPATH/mm_overlay"
fi

# 清理脚本
for script in metamount.sh metainstall.sh metauninstall.sh post-mount.sh service.sh status_updater.sh; do
    if [ -f "$MODPATH/$script" ]; then
        rm -f "$MODPATH/$script"
    fi
done

# 清理配置文件（可选）
# 取消注释以下行以清除用户数据
# rm -rf /data/adb/magic_mount

# 清理链接
if [ -L "/data/adb/metamodule" ]; then
    rm -f "/data/adb/metamodule"
fi

ui_print ""
ui_print "[+] Magic Mount Metaverse v3.3 uninstalled"
ui_print "[+] Please reboot to complete uninstallation"
ui_print ""

exit 0
