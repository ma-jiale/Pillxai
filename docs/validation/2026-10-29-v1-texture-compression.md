# V1 三张背景图纹理压缩

用户目标：缩小 Windows 构建体积，保留现有 UI 外观和图片尺寸。用户授权采用 BC7 最佳质量方案；不承诺有损压缩逐像素一致。

## 已修改

仅修改下列图片 `.meta` 的 Standalone 覆盖块：

| 图片 | 保留的尺寸上限 |
| --- | --- |
| `Assets/Sprites/Dispense/bg-5.png` | 4096 |
| `Assets/Sprites/PutPillBoxesInAlert/bg-7.png` | 4096 |
| `Assets/Sprites/Dispense/bg-2.png` | 8192 |

启用覆盖，格式 BC7、CompressedHQ、质量 100、强制 BC6H/BC7 最佳质量；不开 Crunch。上述上限来自原有效默认设置，不采用原未启用的 Standalone 2048 上限。GUID、Sprite 参数、透明设置、Mip Maps、源 PNG、默认平台及 Android 配置保持不变。

## 已验证与限制

- 三张源 PNG SHA-256 与修改前一致。
- 与 Git 基线逐段比较，三份 `.meta` 仅 Standalone 块变化。
- 从已安装 Unity 6000.5.7f1 的 UnityEditor.CoreModule 读取枚举，确认 BC7=25、CompressedHQ=2。
- `git diff --check` 通过。
- 尝试启动已安装 Unity，执行导入、图像对比与独立 Windows 构建；Unity 进入项目后以退出码 1 结束，未运行验证方法，日志没有说明具体退出原因。没有修改系统配置或安装软件。临时 Editor 脚本已移除。
- 诊断日志位于 `.var/v1-texture-compression/unity-build.log`，原图哈希位于同目录 `source-hashes.json`。

尚未确认实际导入后的尺寸/格式、构建体积、目标设备兼容性或视觉效果。三张图合计从约 145.9 MiB 减至约 36.5 MiB 是按 BC7 块存储推算，不能当作实测结果。现有 Build/3.22 未被替换。

## 后续验收

在 Unity 中重新导入三张图，确认 BC7 和实际尺寸；重新构建 Windows 到独立目录。对比开仓提示和摆药页面的原始/压缩后截图，重点检查透明边缘、浅灰渐变、圆角阴影与细线。如有可见损伤，单独撤销对应图的覆盖后重新验证，不自动缩图。
