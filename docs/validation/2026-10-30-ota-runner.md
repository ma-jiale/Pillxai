# 2026-10-30 Runner OTA 发布

目标：使用已有服务器 Runner 发布正式 0.2.3 / 5，供用户当前 0.2.2 / 4 平板从 OTA 更新；不使用 USB 安装。

## 原因与变更

此前 `/pillxai/releases/android` 返回 HTTP 200、`release=null`：只读接口已启用，但未发布 APK。旧 Android Client Release 工作流只保存 GitHub Artifact，缺少服务器发布步骤。首次 CI 构建还因固定 Flutter 提交缺少 Git 标签而失败；此前平板 0.2.0 是本地正式构建经 USB 首次安装，不能作为 OTA 成功证据。

本次整合已提交的发布目录权限及 CI 标签修复，新增 main 构建后通过 `pillxa-server` Runner 发布的作业。构建验签和 API 模型校验保留；Runner 校验同次构建清单哈希、来源提交、版本、APK 大小和哈希，再原子切换清单。只有公开接口匹配且完整 APK 下载哈希一致后，publish 作业成功。

## 本地验证

- 发布脚本 9 项测试通过：严格 umask/旧目录权限、同制品重试、损坏制品、来源与版本不符、禁止回退/替换同号、并发锁、符号链接、清单切换中断恢复、公开下载完整性。
- Ruff 与 Android 发布工作流 actionlint 通过。
- 当前改动不改变客户端安装锁或机器执行逻辑；侧栏代码来自已合并 PR #14。

## 远端与平板

- [PR #15](https://github.com/ma-jiale/Pillxai/pull/15) 检查通过并合入 main，补齐 Runner 发布及目录权限修复。
- [Android Client Release #2](https://github.com/ma-jiale/Pillxai/actions/runs/41013305963) 构建出 APK，但在证书指纹检查处失败，未发布文件。原工作流自动选择安装目录中版本最大的 Build Tools；失败时未输出实际证书报告，不能据此断言私钥错误。
- [PR #16](https://github.com/ma-jiale/Pillxai/pull/16) 固定验签工具为本地验证过的 Build Tools 36.0.0，并增加构建前密钥库公开指纹核对。重新运行证明 CI 密钥库和实际 APK 证书均与原正式证书一致，签名校验通过。
- 正式构建源码：`e62a9125c8762b2c297a0738da951dccf1eed51f`。[V2 Server CI and CD](https://github.com/ma-jiale/Pillxai/actions/runs/41014350206) 部署成功，公开就绪接口 HTTP 200、`status=ready`。
- [Android Client Release #3](https://github.com/ma-jiale/Pillxai/actions/runs/41014363265) 实际构建 `0.2.3 / 5`，客户端检查/测试和执行模块 74 项测试通过，正式 APK 验签通过；Runner 已将 APK 与清单发布到服务器。
- 2026-10-30 14:45（北京时间）独立公网验证通过：`/pillxai/releases/android` 返回 `0.2.3 / 5`；完整下载 88,738,358 字节，SHA-256 为 `e51cdc83057ddfeedaf3225a60bf3f3272306e9305c3f547992e5ae84235b457`，与清单和 CI 一致。
- 下载后的 APK 使用本机 apksigner 36.0.0 复验通过，证书 SHA-256 为 `750b500737467a051da7ab7c21848af4620bb47523ff8a2b507f08b9929b1670`，与 0.2.2 / 4 一致。aapt 确认正式包名、0.2.3 / 5、最低 Android API 24，包含 arm64-v8a、armeabi-v7a、x86_64。原始记录 `.var/ota-0.2.3/verification.json`。
- 平板 OTA 安装与数据保留待实测；当前没有 ADB 连接，不能由服务器发布成功推断设备安装成功。

## 平板验收入口

登录后打开左下角用户菜单 → 设置 → 关于 → 检查更新。应显示当前 0.2.2（4）和新版本 0.2.3；空闲时自动下载，或点击“下载更新”。下载完成后点击“允许安装更新”（首次授权）或“安装更新”，根据 Android 提示确认；若应用显示“继续系统安装”，点击继续。任务、收仓和结果补传未结束时安装入口保持禁用。

重新打开应用并登录，在关于页面核对 0.2.3（5），确认设备绑定、设置和业务记录仍保留。无需卸载旧版或清除数据。
