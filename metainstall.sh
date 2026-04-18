#!/system/bin/sh
############################################
# Magic Mount Metaverse - metainstall.sh
# Post-installation script v2.3
# Author: GitHub@FHYUYO
############################################

MODULE_DATA_DIR="/data/adb/magic_mount"
EXTENDED_CONFIG="$MODULE_DATA_DIR/mm_extended.conf"

# 日志函数
log() {
    local msg="[MetaInstall] $1"
    echo "$msg" >> /data/adb/magic_mount/mm.log 2>/dev/null
}

log "Magic Mount Metaverse v2.3 post-install started"

# 确保数据目录存在
if [ ! -d "$MODULE_DATA_DIR" ]; then
    mkdir -p "$MODULE_DATA_DIR"
    log "Created data directory: $MODULE_DATA_DIR"
fi

# 设置权限
chmod 700 "$MODULE_DATA_DIR" 2>/dev/null

# 检查并初始化配置文件
if [ ! -f "$EXTENDED_CONFIG" ]; then
    log "Creating default extended config"
    cat > "$EXTENDED_CONFIG" << 'EOF'
# ===== Magic Mount Metaverse Extended Config =====
# Author: GitHub@FHYUYO/酷安@枫原羽悠
# Version: v2.3
# This file contains extended settings for shell scripts only.
# These settings are NOT parsed by mmd binary.

# ====== Stealth Settings ======
stealth_mode=false
randomize_id=false
hide_mount_logs=false
alternate_path=
spoof_name=
hide_from_list=false

# ====== Anti-Detection Settings ======
bypass_detection=true

# ====== Performance Settings ======
optimization_level=0
mount_delay=0
parallel_mount=false

# ====== Mount Mode Settings ======
mount_mode=magic
module_mount_modes={}
enable_modules_img=true
modules_img_size=2048

# ====== Auto Backup ======
auto_backup=true
backup_dir=/data/adb/magic_mount/backup
EOF
    chmod 600 "$EXTENDED_CONFIG"
    log "Extended config initialized"
fi

# 检查二进制文件
MODDIR="${0%/*}"
if [ ! -f "$MODDIR/mmd" ]; then
    log "Warning: mmd binary not found"
fi

if [ ! -f "$MODDIR/mm_overlay" ]; then
    log "Note: mm_overlay binary not found (optional)"
fi

# 创建备份目录
BACKUP_DIR="/data/adb/magic_mount/backup"
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    log "Created backup directory"
fi

log "Post-installation complete"
exit 0
