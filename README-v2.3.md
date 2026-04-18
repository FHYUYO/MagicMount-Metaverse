# Magic Mount Metaverse v2.3

## 简介

Magic Mount Metaverse 是一个用于 KernelSU/APatch 的元模块，用于挂载其他模块到系统分区。它支持 Magic 模式和 OverlayFS 模式，并且可以在 WebUI 中为每个模块单独设置挂载模式。

## 主要功能

### 1. 核心挂载功能
- **Magic 模式**: 使用单目录挂载，简单高效
- **OverlayFS 模式**: 使用双目录挂载（元数据+内容分离），性能更好
- **模块级挂载**: 可以为每个模块单独设置挂载模式

### 2. WebUI 控制面板
- 实时监控挂载状态
- 模块管理（启用/禁用/跳过）
- 挂载模式设置
- 日志查看
- 隐身设置

### 3. 优化选项
- **Standard 模式**: 标准行为
- **Fast 模式**: 减少等待时间
- **Ultra 模式**: 完整模块级挂载支持

## 安装

1. 下载模块 zip 包
2. 通过 KernelSU Manager 或 APatch Manager 安装
3. 重启设备

## 配置

### 配置文件位置
- 主配置: `/data/adb/magic_mount/mm.conf`
- 扩展配置: `/data/adb/magic_mount/mm_extended.conf`

### 全局挂载模式
```conf
mount_mode=magic  # 或 overlayfs
```

### 模块级挂载模式 (JSON格式)
```conf
module_mount_modes={"ModuleName":"overlayfs","AnotherModule":"magic"}
```

支持的模式:
- `magic`: 使用 Magic 挂载
- `overlayfs`: 使用 OverlayFS 挂载
- `ignore`: 跳过该模块

### 优化级别
```conf
optimization_level=0  # 标准
optimization_level=1  # 快速
optimization_level=2  # 极致 (推荐)
```

## 使用示例

### 通过 WebUI 设置

1. 打开 Magic Mount WebUI
2. 进入 "Modules" 标签页
3. 为每个模块选择挂载模式
4. 设置会自动保存

### 手动编辑配置

```bash
# 编辑配置
vi /data/adb/magic_mount/mm_extended.conf

# 设置示例
mount_mode=magic
optimization_level=2
module_mount_modes={
  "Riru":"overlayfs",
  "LSPosed":"magic",
  "SomeModule":"ignore"
}
```

## 更新日志 v2.3

### 核心修复
- ✅ 修复挂载模式冲突问题
- ✅ 实现完整的模块级挂载模式支持
- ✅ 修复配置读取逻辑

### 稳定性优化
- ✅ 增加错误重试机制
- ✅ 优化挂载算法
- ✅ 改进日志管理

### 隐藏性能
- ✅ 增强日志过滤
- ✅ 敏感信息脱敏
- ✅ 路径信息隐藏

## 兼容性

- ✅ KernelSU
- ✅ APatch
- ✅ ARM64
- ✅ ARMv7 (Magic模式)
- ✅ x86_64

## 文件结构

```
MagicMount-Metaverse/
├── bin/
│   ├── mm_arm64          # Magic 模式二进制 (ARM64)
│   ├── mm_armv7          # Magic 模式二进制 (ARMv7)
│   ├── mm_amd64          # Magic 模式二进制 (x86_64)
│   ├── mm_overlay_arm64  # OverlayFS 二进制 (ARM64)
│   └── mm_overlay_amd64  # OverlayFS 二进制 (x86_64)
├── webroot/              # WebUI 文件
├── metamount.sh          # 挂载脚本
├── status_updater.sh     # 状态更新脚本
├── service.sh            # 后台服务
├── mm.conf               # 主配置文件
├── mm_extended.conf      # 扩展配置文件
└── customize.sh          # 安装脚本
```

## 常见问题

### Q: 模块没有使用我设置的挂载模式
A: 确保 `optimization_level=2`，并且模块名与目录名完全匹配。

### Q: ARMv7 无法使用 OverlayFS
A: 这是设计如此，ARMv7 架构只支持 Magic 模式。

### Q: 如何查看日志
A: 在 WebUI 中进入 "Logs" 标签页，或查看 `/data/adb/magic_mount/mm.log`

### Q: 恢复默认设置
A: 删除 `/data/adb/magic_mount/` 目录后重新安装模块。

## 开发者信息

- GitHub: https://github.com/FHYUYO/MagicMount-Metaverse
- 酷安: @枫原羽悠

## License

MIT License
