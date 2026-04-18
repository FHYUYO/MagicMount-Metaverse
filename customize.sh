#!/system/bin/sh
############################################
# Magic Mount Metaverse v2.3 Installer
# Author: GitHub@FHYUYO/酷安@枫原羽悠
############################################

am start -a android.intent.action.VIEW -d https://qm.qq.com/q/iFJs3xVgj0 >/dev/null 2>&1

SKIPUNZIP=1
MODULE_ID="Magic-Mount-Metaverse"
MODULE_DATA_DIR="/data/adb/magic_mount"
METAMODULE_LINK="/data/adb/metamodule"

ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║  Magic Mount Metaverse v2.3 Installer║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""

# 解压文件
ui_print "[*] Extracting files..."
unzip -o "${ZIPFILE}" -d "${TMPDIR}" >/dev/null 2>&1 || abort "[!] Extract failed"

# 验证校验和
if [ -f "${TMPDIR}/checksums" ]; then
    (cd "${TMPDIR}" && sha256sum -c -s checksums >/dev/null 2>&1) && \
        ui_print "[+] Checksum verified" || \
        ui_print "[!] Checksum warning"
fi

# 检测架构
ui_print ""
ui_print "[*] Detecting architecture..."
ABI=$(getprop ro.product.cpu.abi)

case "$ABI" in
    arm64-v8a)
        MM_BIN="mm_arm64"
        OVL_BIN="mm_overlay_arm64"
        ui_print "    ARM64 detected"
        ;;
    armeabi-v7a)
        MM_BIN="mm_armv7"
        OVL_BIN=""
        ui_print "    ARMv7 detected (OverlayFS not supported)"
        ;;
    x86_64)
        MM_BIN="mm_amd64"
        OVL_BIN="mm_overlay_amd64"
        ui_print "    x86_64 detected"
        ;;
    *)
        abort "[!] Unsupported architecture: $ABI"
        ;;
esac

# 创建模块目录
mkdir -p "$MODPATH"

# 安装主二进制
ui_print ""
ui_print "[*] Installing binaries..."
if [ -f "${TMPDIR}/bin/${MM_BIN}" ]; then
    cp "${TMPDIR}/bin/${MM_BIN}" "$MODPATH/mmd"
    chmod 755 "$MODPATH/mmd"
    ui_print "    [✓] mmd ($MM_BIN)"
else
    ui_print "    [!] Warning: mmd binary not found"
fi

# 安装 OverlayFS 二进制
if [ -n "$OVL_BIN" ] && [ -f "${TMPDIR}/bin/${OVL_BIN}" ]; then
    cp "${TMPDIR}/bin/${OVL_BIN}" "$MODPATH/mm_overlay"
    chmod 755 "$MODPATH/mm_overlay"
    ui_print "    [✓] mm_overlay ($OVL_BIN)"
elif [ -n "$OVL_BIN" ]; then
    ui_print "    [!] Warning: mm_overlay binary not found"
fi

# 安装脚本
ui_print ""
ui_print "[*] Installing scripts..."
for script in metainstall.sh metamount.sh metauninstall.sh uninstall.sh status_updater.sh service.sh post-mount.sh; do
    if [ -f "${TMPDIR}/$script" ]; then
        cp "${TMPDIR}/$script" "$MODPATH/$script"
        chmod 755 "$MODPATH/$script"
        ui_print "    [✓] $script"
    else
        ui_print "    [!] Missing: $script"
    fi
done

# 安装配置文件
ui_print ""
ui_print "[*] Installing configs..."
cp "${TMPDIR}/module.prop" "$MODPATH/" 2>/dev/null || ui_print "    [!] module.prop missing"
cp "${TMPDIR}/mm.conf" "$MODPATH/" 2>/dev/null || ui_print "    [!] mm.conf missing"
cp "${TMPDIR}/mm_extended.conf" "$MODPATH/" 2>/dev/null || ui_print "    [!] mm_extended.conf missing"
cp "${TMPDIR}/checksums" "$MODPATH/" 2>/dev/null
ui_print "    [✓] Config files"

# 安装 WebUI
if [ -d "${TMPDIR}/webroot" ]; then
    cp -r "${TMPDIR}/webroot" "$MODPATH/"
    ui_print "    [✓] WebUI"
else
    ui_print "    [!] WebUI not found"
fi

# 创建数据目录
mkdir -p "$MODULE_DATA_DIR"

# 安装运行时配置
ui_print ""
ui_print "[*] Setting up runtime..."
if [ -f "${TMPDIR}/mm.conf" ]; then
    cp "${TMPDIR}/mm.conf" "$MODULE_DATA_DIR/"
fi
if [ -f "${TMPDIR}/mm_extended.conf" ]; then
    cp "${TMPDIR}/mm_extended.conf" "$MODULE_DATA_DIR/"
fi
chmod 600 "$MODULE_DATA_DIR"/*.conf 2>/dev/null
ui_print "    [✓] Runtime config"

# 设置 metamodule 链接
if [ ! -e "$METAMODULE_LINK" ]; then
    ln -sf "/data/adb/modules/$MODULE_ID" "$METAMODULE_LINK" 2>/dev/null && \
        ui_print "    [✓] Metamodule link created"
fi

# 完成
ui_print ""
ui_print "═══════════════════════════════════════════"
ui_print "   Magic Mount Metaverse v2.3 Installed"
ui_print "═══════════════════════════════════════════"
ui_print "   Arch: $ABI"
ui_print "   Mode: Magic + OverlayFS"
ui_print "   Feature: Per-module mount modes"
ui_print "═══════════════════════════════════════════"
ui_print ""
ui_print "[+] Reboot to activate!"
ui_print ""

exit 0
