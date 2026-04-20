# Magic Mount Metaverse v3.0

## 简介

Magic Mount Metaverse 是一个增强型 Magisk/KernelSU/APatch 元模块，集成了 Magic Mount 和 OverlayFS 挂载功能。

## 主要特性

### v3.0 新增功能
- **模块识别面板**: 在 WebUI 中直接查看和管理所有已安装模块
- **独立挂载模式**: 每个模块可单独设置 Magic 或 OverlayFS 挂载模式
- **KernelSU 兼容优化**: 修复了关闭"默认卸载模块"后无法开机的 bug
- **移除 Ignore 模式**: 简化配置，仅保留 Magic 和 OverlayFS 两种挂载模式

### 核心功能
- **双挂载模式**: 支持 Magic 单目录挂载和 OverlayFS 双目录隔离挂载
- **隐身模式**: 隐藏模块存在痕迹，防止检测
- **性能优化**: 三级优化级别可选（禁用/快速/极致）
- **模块管理**: 支持跳过特定模块的挂载

## 支持环境

- KernelSU
- APatch

## 安装

1. 在 Magisk Manager/KernelSU Manager 中刷入 zip 包
2. 重启设备
3. 在模块管理界面点击 Magic Mount 进入配置界面

## 目录结构

```
MagicMount-Metaverse-v3.0/
├── bin/                      # 二进制文件
│   ├── mm_arm64            # ARM64 Magic 挂载
│   ├── mm_amd64            # x86_64 Magic 挂载
│   ├── mm_armv7            # ARMv7 Magic 挂载
│   ├── mm_overlay_arm64    # ARM64 OverlayFS 挂载
│   └── mm_overlay_amd64    # x86_64 OverlayFS 挂载
├── webroot/                 # WebUI 资源
│   ├── index.html
│   └── assets/
├── module.prop
├── metamount.sh            # 挂载脚本
├── metainstall.sh          # 安装脚本
├── metauninstall.sh        # 卸载脚本
├── service.sh              # 后台服务
├── post-mount.sh           # 挂载后脚本
├── customize.sh            # 自定义安装脚本
├── mm.conf                 # 主配置文件
├── mm_extended.conf        # 扩展配置文件
└── checksums               # 校验文件
```

## 配置文件

### mm.conf
主配置文件，包含核心设置：
- `module_dir`: 模块目录路径
- `mount_source`: 挂载源 (KSU/APatch)
- `log_file`: 日志文件路径
- `debug`: 调试模式
- `umount`: 启用卸载

### mm_extended.conf
扩展配置文件，包含：
- **隐身设置**: stealth_mode, randomize_id, hide_mount_logs
- **性能设置**: optimization_level, mount_delay, parallel_mount
- **挂载模式**: mount_mode, module_mount_modes

## 挂载模式

### Magic 模式
- 单目录挂载
- 兼容性更好
- 资源占用低

### OverlayFS 模式
- 双目录隔离（元数据 + 内容）
- 更好的隔离性
- 适用于复杂模块交互

## 性能优化级别

| 级别 | 说明 |
|------|------|
| 0 (禁用) | 标准模式，使用全局挂载设置 |
| 1 (快速) | 减少等待时间，使用全局模式 |
| 2 (极致) | 模块级挂载模式，最大性能 |

## 常见问题

### Q: 关闭"默认卸载模块"后无法开机
A: v3.0 已修复此问题。模块现在会检测 KernelSU 的卸载状态标志，自动跳过已卸载的模块。

### Q: 如何为单个模块设置挂载模式？
A: 在模块列表页面点击模块卡片展开详情，选择所需的挂载模式（Magic 或 OverlayFS）。

### Q: ignore 模式去哪了？
A: v3.0 已移除 ignore 模式。如需跳过某模块挂载，请使用模块目录下的 `skip_mount` 文件。

## 更新日志

### v3.0 (2024)
- 添加模块识别面板
- 移除 ignore 挂载模式
- 修复 KernelSU 卸载后的开机问题

### v2.3
- 基础元模块架构
- 双挂载模式支持
- 隐身模式支持

## 作者

- GitHub: [@FHYUYO](https://github.com/FHYUYO)
- 酷安: [@枫原羽悠](https://www.coolapk.com)



## 致谢

- [KernelSU](https://github.com/tiann/KernelSU)
- [APatch](https://github.com/bmax121/APatch)
- [Magisk](https://github.com/topjohnwu/Magisk)
