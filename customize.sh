#!/system/bin/sh
############################################
# Magic Mount Metaverse v3.4.1 Installer
# Author: GitHub@FHYUYO/酷安@枫原羽悠
#
# v3.4.1 Changes:
#   - Fixed volume key mount mode selection
#   - Volume UP = Magic mode
#   - Volume DOWN = OverlayFS mode
#   - Improved key detection reliability
############################################

SKIPUNZIP=1
MODULE_ID="Magic-Mount-Metaverse"
MODULE_DATA_DIR="/data/adb/magic_mount"
METAMODULE_LINK="/data/adb/metamodule"

ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║  Magic Mount Metaverse v3.4.1        ║"
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

# ===== 音量键挂载模式选择 =====
ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║     Select Mount Mode (音量键选择)     ║"
ui_print "╠═══════════════════════════════════════╣"
ui_print "║  音量上键(+)= Magic 挂载模式          ║"
ui_print "║  音量下键(-)= OverlayFS 挂载模式       ║"
ui_print "║  5秒后默认选择 Magic 模式             ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""

SELECTED_MODE="magic"

# 等待音量键输入
KEY_TIMEOUT=10
KEY_PRESSED=""
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $KEY_TIMEOUT ]; then
        break
    fi
    
    # 使用timeout确保getevent不会永久阻塞，并使用-l参数获取可读的key名称
    KEY_EVENT=$(timeout 0.3 getevent -l 2>/dev/null)
    
    # 检查音量上键
    if echo "$KEY_EVENT" | grep -q "KEY_VOLUMEUP"; then
        SELECTED_MODE="magic"
        ui_print "[+] Detected: Volume Up Key"
        break
    fi
    
    # 检查音量下键
    if echo "$KEY_EVENT" | grep -q "KEY_VOLUMEDOWN"; then
        SELECTED_MODE="overlayfs"
        ui_print "[+] Detected: Volume Down Key"
        break
    fi
    
    # 剩余时间提示
    REMAINING=$((KEY_TIMEOUT - ELAPSED))
    ui_print "\r[*] Waiting... ($REMAINING s left)    "
    sleep 0.3
done

# 显示选择的模式
ui_print ""
case "$SELECTED_MODE" in
    magic)
        ui_print "[+] Selected: Magic Mount Mode"
        ;;
    overlayfs)
        ui_print "[+] Selected: OverlayFS Mount Mode"
        ;;
esac

# 保存用户选择的模式到配置
mkdir -p "$MODULE_DATA_DIR"
if [ -f "${TMPDIR}/mm_extended.conf" ]; then
    cp "${TMPDIR}/mm_extended.conf" "$MODULE_DATA_DIR/"
    # 更新配置文件中的挂载模式
    if grep -q "^mount_mode=" "$MODULE_DATA_DIR/mm_extended.conf" 2>/dev/null; then
        sed -i "s/^mount_mode=.*/mount_mode=\"$SELECTED_MODE\"/" "$MODULE_DATA_DIR/mm_extended.conf"
    else
        echo "mount_mode=\"$SELECTED_MODE\"" >> "$MODULE_DATA_DIR/mm_extended.conf"
    fi
fi

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

# 安装二进制文件目录
if [ -d "${TMPDIR}/bin" ]; then
    cp -r "${TMPDIR}/bin" "$MODPATH/"
fi

# 创建数据目录（确保已存在）
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
ui_print "   Magic Mount Metaverse v3.4.1 Installed"
ui_print "═══════════════════════════════════════════"
ui_print "   Arch: $ABI"
ui_print "   Mode: $SELECTED_MODE"
ui_print "   Feature: Per-module mount modes"
ui_print "═══════════════════════════════════════════"
ui_print ""
ui_print "[+] Reboot to activate!"
ui_print ""

exit 0
