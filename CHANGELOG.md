# Magic Mount Metaverse v2.3 修复日志

## 版本信息
- **版本号**: v2.3
- **修复日期**: 2026年
- **修复内容**: 挂载模式冲突修复

---

## 🔧 主要修复

### 1. 挂载模式冲突 (核心问题)

#### 问题描述
- WebUI可以正常保存模块的挂载模式到 `module_mount_modes` (JSON格式)
- `metamount.sh` 的 `read_config()` 函数只读取了全局 `mount_mode`
- 完全忽略了 `module_mount_modes` 配置，导致所有模块都使用全局模式

#### 解决方案
- 新增 `get_module_mount_mode()` 函数，从JSON中解析模块级挂载模式
- 修改主程序逻辑，根据 `optimization_level` 选择不同策略
- **Ultra模式(优化级别2)**: 遍历所有模块，为每个模块应用对应的挂载模式
- 优先使用模块单独设置，模块无设置则使用全局模式

### 2. Bug修复

#### metamount.sh
- **第59行**: `log_msg "Binary not found: mm_binary"` → 修正为 `$MM_BINARY`
- **增强配置解析**: 使用更健壮的正则表达式提取配置值
- **变量初始化**: 确保所有变量都有默认值
- **错误处理**: 添加了重试机制 (最多2次重试)

#### status_updater.sh
- **增强JSON解析**: 使用更健壮的方式从JSON提取模块模式
- **状态检测**: 增加了对 `/data/adb/modules_rw` 和 `/data/adb/.modules_rw` 的检查
- **备份更新方法**: 添加了 `update_prop_backup()` 防止并发更新失败

#### 所有Shell脚本
- 统一变量命名和日志格式
- 添加更完善的错误处理
- 确保权限设置正确

---

## 📈 稳定性优化

### 错误重试机制
```shell
local retry_count=0
local max_retries=2
while [ $retry_count -le $max_retries ]; do
    execute_mount "$MODULE_NAME" "$USE_MODE"
    if [ $? -eq 0 ]; then
        return 0
    fi
    retry_count=$((retry_count + 1))
    sleep 1
done
```

### 挂载延迟机制
- 支持配置 `mount_delay` (毫秒)
- 根据优化级别自动调整等待时间

### 日志管理
- 自动限制日志大小 (保留最后100行)
- 深度脱敏处理

---

## 🔒 隐藏性能增强

### 日志过滤增强
过滤关键词:
- password, secret, token, credential, auth
- unmount, mounting (根据 hide_mount_logs 设置)

### 路径脱敏
```
/data/adb/modules → <MODULES>
/data/adb/magic_mount → <MM_DIR>
/system/system → <SYSTEM>
/product/system → <PRODUCT>
/vendor/system → <VENDOR>
```

### 敏感信息保护
- 配置值过滤
- 模块路径隐藏
- 操作日志隐藏

---

## 🎯 性能优化

### 优化级别 (optimization_level)

| 级别 | 名称 | 行为 |
|------|------|------|
| 0 | Standard | 使用全局模式，标准等待时间 |
| 1 | Fast | 减少等待时间，使用全局模式 |
| 2 | Ultra | 完整模块级模式支持，最大性能 |

### 模块级挂载模式

| 模式 | 说明 |
|------|------|
| magic | 使用 mmd 单目录挂载 |
| overlayfs | 使用 mm_overlay 双目录挂载 |
| ignore | 跳过该模块的挂载 |
| global | 使用全局设置 |

---

## 📋 配置文件

### mm_extended.conf 新增字段
```conf
# Per-module mount modes (JSON format)
module_mount_modes={}
# 格式: {"module_id": "overlayfs", "another_module": "magic"}
```

### WebUI支持
- 模块列表页显示每个模块的挂载模式
- 可单独设置每个模块的挂载模式
- 设置后自动保存到 `module_mount_modes`

---

## 🧪 测试验证

### 兼容性
- ✅ KernelSU 兼容
- ✅ APatch 兼容
- ✅ ARM64, ARMv7, x86_64 架构

### 功能验证
- [x] 全局挂载模式正常工作
- [x] 模块级挂载模式正常工作
- [x] ignore 模式跳过指定模块
- [x] 配置文件读写正常
- [x] 日志功能正常
- [x] 隐身模式正常工作

---

## 📁 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| metamount.sh | 核心修复 | 增加模块级挂载模式支持 |
| status_updater.sh | 功能增强 | 改进JSON解析和状态检测 |
| metainstall.sh | Bug修复 | 完善错误处理 |
| metauninstall.sh | 稳定性优化 | 改进卸载逻辑 |
| service.sh | 性能优化 | 根据优化级别调整等待 |
| post-mount.sh | 性能优化 | 减少不必要的等待 |
| customize.sh | 完善 | 增强安装流程 |
| uninstall.sh | 完善 | 改进卸载界面 |
| mm_extended.conf | 文档完善 | 增强注释说明 |

---

## 使用方法

### 1. WebUI设置模块挂载模式
1. 打开 Magic Mount WebUI
2. 进入 "Modules" 标签页
3. 为每个模块选择挂载模式 (Magic/Overlay/Ignore)
4. 设置自动保存

### 2. 手动编辑配置
```json
{
  "SomeModule": "overlayfs",
  "AnotherModule": "magic",
  "BatteryModule": "ignore"
}
```

### 3. 命令行设置
```bash
# 编辑配置文件
vim /data/adb/magic_mount/mm_extended.conf

# 设置全局模式为 overlayfs
mount_mode=overlayfs

# 设置优化级别为 Ultra
optimization_level=2
```

---

## ⚠️ 注意事项

1. **重置后生效**: 修改配置文件后需要重启才能生效
2. **模块名匹配**: JSON中的模块ID必须与 /data/adb/modules/ 下的目录名完全匹配
3. **二进制支持**: Ultra模式需要新版 mmd 支持模块级挂载参数
4. **ARMv7限制**: ARMv7架构不支持 OverlayFS 模式

---

## 📞 支持

- GitHub: https://github.com/FHYUYO/MagicMount-Metaverse
- 酷安: @枫原羽悠
