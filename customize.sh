#!/system/bin/sh
############################################
# Magic Mount Metaverse v3.4.2 Installer
# Author: GitHub@FHYUYO/酷安@枫原羽悠
#
# v3.4.2 Changes:
#   - Fixed: Version bump for v3.4.2 release
#   - Enhanced: Log path updated to /data/adb/Metaverse/运行日志.log
#   - Enhanced: Config file paths updated to Chinese names
############################################

SKIPUNZIP=1
MODULE_ID="Magic-Mount-Metaverse"
MODULE_DATA_DIR="/data/adb/Metaverse"
METAMODULE_LINK="/data/adb/metamodule"

ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║  Magic Mount Metaverse v3.4.2        ║"
ui_print "║     魔法挂载元宇宙 - 安装程序          ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""

# 解压文件
ui_print "[*] 正在解压文件..."
unzip -o "${ZIPFILE}" -d "${TMPDIR}" >/dev/null 2>&1 || abort "[!] 解压失败"

# 验证校验和
if [ -f "${TMPDIR}/checksums" ]; then
    (cd "${TMPDIR}" && sha256sum -c -s checksums >/dev/null 2>&1) && \
        ui_print "[+] 校验和验证通过" || \
        ui_print "[!] 校验和警告"
fi

# 检测架构
ui_print ""
ui_print "[*] 检测CPU架构..."
ABI=$(getprop ro.product.cpu.abi)

case "$ABI" in
    arm64-v8a)
        MM_BIN="mm_arm64"
        OVL_BIN="mm_overlay_arm64"
        ui_print "    检测到 ARM64 架构"
        ;;
    armeabi-v7a)
        MM_BIN="mm_armv7"
        OVL_BIN=""
        ui_print "    检测到 ARMv7 架构 (不支持OverlayFS)"
        ;;
    x86_64)
        MM_BIN="mm_amd64"
        OVL_BIN="mm_overlay_amd64"
        ui_print "    检测到 x86_64 架构"
        ;;
    *)
        abort "[!] 不支持的架构: $ABI"
        ;;
esac

# ===== 音量键挂载模式选择 =====
ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║       选择挂载模式 (音量键选择)        ║"
ui_print "╠═══════════════════════════════════════╣"
ui_print "║  音量上键(+) = Magic 挂载模式         ║"
ui_print "║  音量下键(-) = OverlayFS 挂载模式     ║"
ui_print "║  10秒后默认选择 Magic 模式            ║"
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
    
    # 使用timeout确保getevent不会永久阻塞
    KEY_EVENT=$(timeout 0.3 getevent -l 2>/dev/null)
    
    # 检查音量上键
    if echo "$KEY_EVENT" | grep -q "KEY_VOLUMEUP"; then
        SELECTED_MODE="magic"
        ui_print "[+] 检测到: 音量上键"
        break
    fi
    
    # 检查音量下键
    if echo "$KEY_EVENT" | grep -q "KEY_VOLUMEDOWN"; then
        SELECTED_MODE="overlayfs"
        ui_print "[+] 检测到: 音量下键"
        break
    fi
    
    # 剩余时间提示
    REMAINING=$((KEY_TIMEOUT - ELAPSED))
    ui_print "\r[*] 等待选择... ($REMAINING 秒)    "
    sleep 0.3
done

# 显示选择的模式
ui_print ""
case "$SELECTED_MODE" in
    magic)
        ui_print "[+] 已选择: Magic 挂载模式"
        ;;
    overlayfs)
        ui_print "[+] 已选择: OverlayFS 挂载模式"
        ;;
esac

# 创建数据目录并清理旧配置（避免符号链接循环问题）
mkdir -p "$MODULE_DATA_DIR"

# 清理旧的符号链接和配置文件（如果存在）
rm -f "$MODULE_DATA_DIR/配置.conf" 2>/dev/null
rm -f "$MODULE_DATA_DIR/扩展配置.conf" 2>/dev/null
rm -f "$MODULE_DATA_DIR/mm.conf" 2>/dev/null
rm -f "$MODULE_DATA_DIR/mm_extended.conf" 2>/dev/null

# 保存用户选择的模式到配置
CONFIG_FILE="$MODULE_DATA_DIR/扩展配置.conf"

if [ -f "${TMPDIR}/扩展配置.conf" ]; then
    # 复制基础配置文件
    cp "${TMPDIR}/扩展配置.conf" "$CONFIG_FILE"
    
    # 更新挂载模式
    if grep -q "^mount_mode=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s/^mount_mode=.*/mount_mode=$SELECTED_MODE/" "$CONFIG_FILE"
    else
        echo "mount_mode=$SELECTED_MODE" >> "$CONFIG_FILE"
    fi
    ui_print "    [✓] 配置已保存: $CONFIG_FILE"
else
    # 如果模板不存在，创建配置文件
    cat > "$CONFIG_FILE" << 'EOFCONFIG'
# Magic Mount Metaverse Extended Config
# 扩展配置文件

# Stealth Settings
stealth_mode=false
randomize_id=false
hide_mount_logs=false
hide_from_list=false

# Mount Mode Settings
EOFCONFIG
    echo "mount_mode=$SELECTED_MODE" >> "$CONFIG_FILE"
    ui_print "    [✓] 创建配置文件: $CONFIG_FILE"
fi

# 同时在TMPDIR中更新（用于后续复制到MODPATH）
if grep -q "^mount_mode=" "${TMPDIR}/扩展配置.conf" 2>/dev/null; then
    sed -i "s/^mount_mode=.*/mount_mode=$SELECTED_MODE/" "${TMPDIR}/扩展配置.conf"
else
    echo "mount_mode=$SELECTED_MODE" >> "${TMPDIR}/扩展配置.conf"
fi

# 创建模块目录
mkdir -p "$MODPATH"

# 安装主二进制
ui_print ""
ui_print "[*] 安装二进制文件..."
if [ -f "${TMPDIR}/bin/${MM_BIN}" ]; then
    cp "${TMPDIR}/bin/${MM_BIN}" "$MODPATH/mmd"
    chmod 755 "$MODPATH/mmd"
    ui_print "    [✓] mmd ($MM_BIN)"
else
    ui_print "    [!] 警告: mmd 二进制文件未找到"
fi

# 安装 OverlayFS 二进制
if [ -n "$OVL_BIN" ] && [ -f "${TMPDIR}/bin/${OVL_BIN}" ]; then
    cp "${TMPDIR}/bin/${OVL_BIN}" "$MODPATH/mm_overlay"
    chmod 755 "$MODPATH/mm_overlay"
    ui_print "    [✓] mm_overlay ($OVL_BIN)"
elif [ -n "$OVL_BIN" ]; then
    ui_print "    [!] 警告: mm_overlay 二进制文件未找到"
fi

# 安装脚本
ui_print ""
ui_print "[*] 安装脚本文件..."
for script in metainstall.sh metamount.sh metauninstall.sh uninstall.sh status_updater.sh service.sh post-mount.sh; do
    if [ -f "${TMPDIR}/$script" ]; then
        cp "${TMPDIR}/$script" "$MODPATH/$script"
        chmod 755 "$MODPATH/$script"
        ui_print "    [✓] $script"
    else
        ui_print "    [!] 缺失: $script"
    fi
done

# 安装配置文件
ui_print ""
ui_print "[*] 安装配置文件..."
cp "${TMPDIR}/module.prop" "$MODPATH/" 2>/dev/null || ui_print "    [!] module.prop 缺失"
cp "${TMPDIR}/配置.conf" "$MODPATH/" 2>/dev/null || ui_print "    [!] 配置.conf 缺失"
cp "${TMPDIR}/扩展配置.conf" "$MODPATH/" 2>/dev/null || ui_print "    [!] 扩展配置.conf 缺失"
cp "${TMPDIR}/checksums" "$MODPATH/" 2>/dev/null
ui_print "    [✓] 配置文件"

# 安装 WebUI
if [ -d "${TMPDIR}/webroot" ]; then
    cp -r "${TMPDIR}/webroot" "$MODPATH/"
    ui_print "    [✓] WebUI界面"
else
    ui_print "    [!] WebUI未找到"
fi

# 安装二进制文件目录
if [ -d "${TMPDIR}/bin" ]; then
    cp -r "${TMPDIR}/bin" "$MODPATH/"
fi

# 确保数据目录已存在
mkdir -p "$MODULE_DATA_DIR"

# 直接复制配置文件到数据目录（不使用符号链接避免循环问题）
if [ -f "$MODPATH/配置.conf" ]; then
    cp -f "$MODPATH/配置.conf" "$MODULE_DATA_DIR/配置.conf"
    ui_print "    [✓] 配置文件已复制"
fi

# 扩展配置已经在前面处理过了，确保它存在
if [ ! -f "$MODULE_DATA_DIR/扩展配置.conf" ]; then
    # 如果前面没有创建，从模块目录复制
    if [ -f "$MODPATH/扩展配置.conf" ]; then
        cp -f "$MODPATH/扩展配置.conf" "$MODULE_DATA_DIR/扩展配置.conf"
    fi
fi

# 设置权限
chmod 600 "$MODULE_DATA_DIR"/*.conf 2>/dev/null

# 设置 metamodule 链接
if [ ! -e "$METAMODULE_LINK" ]; then
    ln -sf "/data/adb/modules/$MODULE_ID" "$METAMODULE_LINK" 2>/dev/null && \
        ui_print "    [✓] Metamodule链接已创建"
fi

# 完成
ui_print ""
ui_print "═══════════════════════════════════════════"
ui_print "   Magic Mount Metaverse v3.4.2 安装完成"
ui_print "═══════════════════════════════════════════"
ui_print "   架构: $ABI"
ui_print "   模式: $SELECTED_MODE"
ui_print "   特性: 模块级挂载模式"
ui_print "═══════════════════════════════════════════"
ui_print ""
ui_print "[+] 请重启设备以激活模块!"
ui_print ""

exit 0
