# Magic Mount Metaverse v3.5

## 版本说明

Magic Mount Metaverse 是基于 MagicMount 原版增强的元宇宙模块框架。

### 核心功能

#### 1. 双模式挂载
- **Magic 模式**: 使用单目录挂载方式
- **OverlayFS 模式**: 使用双目录隔离方式，提供更好的隔离性

#### 2. 精细化模块管理
- 支持为每个模块单独设置挂载模式
- 只有用户选择挂载模式的模块才会被挂载
- 隐藏模块（无 system 目录）不会自动被全局挂载

#### 3. 强制挂载功能
- 即使模块有 `ignore` 标记也能强制挂载
- 即使模块有 `skip_mount` 标记也能强制挂载

#### 4. 自定义忽略功能
- 可以单独设置忽略某个模块
- 被忽略的模块完全不会参与挂载操作

#### 5. 支持所有常见挂载分区
- system, vendor, odm, my_product
- system_ext, product, vendor_dlkm
- odm_dlkm, system_dlkm

### 使用说明

1. 安装模块后重启设备
2. 打开 WebUI 配置分区和挂载选项
3. 在模块列表中：
   - 点击模块卡片展开详情
   - 选择 Magic 或 OverlayFS 挂载模式
   - 再次点击已选模式可取消选择
   - 使用强制挂载或忽略功能
4. 保存配置后重启生效

### 页面说明

- **配置页面**: 选择要挂载的分区，配置挂载源
- **模块页面**: 为每个模块设置挂载模式、强制挂载或忽略
- **设置页面**: 启用隐身模式、性能优化选项
- **关于页面**: 项目信息、相关链接、使用教程

### 配置文件

#### mm.conf
```
module_dir=/data/adb/modules
mount_source=KSU
partitions=system,vendor,odm,my_product,system_ext,product,vendor_dlkm,odm_dlkm,system_dlkm
```

#### mm_extended.conf
```
mount_mode=magic
module_mount_modes={"模块名":"magic"}
force_mount_modules={"模块名":true}
ignored_modules={"模块名":"ignore"}
optimization_level=2
```

### 技术细节

- 所有 shell 脚本使用 `/bin/sh` 兼容语法
- 支持 KernelSU 和 APatch
- 二进制文件: mmd (Magic 挂载), mm_overlay (OverlayFS 挂载)

### 作者

- GitHub: @FHYUYO
- 酷安: @枫原羽悠

### 致谢

- MagicMount 原版开发者
