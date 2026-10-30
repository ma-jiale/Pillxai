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

- [PR #15](https://github.com/ma-jiale/Pillxai/pull/15) 检查通过并合入 main，正式构建源码为 `1b097902dd9b124d6d71bed9db57dc6d80bba15c`。
- [V2 Server CI and CD](https://github.com/ma-jiale/Pillxai/actions/runs/41007624230) 成功；公开就绪接口 HTTP 200、`status=ready`，服务版本对应上述提交。
- [Android Client Release #2](https://github.com/ma-jiale/Pillxai/actions/runs/41013305963) 已实际触发 `0.2.3 / 5`；工具链准备、客户端检查/测试和执行模块 74 项测试通过，签名 APK 构建进行中。
- 平板 OTA 安装与数据保留待实测；当前没有 ADB 连接，不能由服务器发布成功推断设备安装成功。
