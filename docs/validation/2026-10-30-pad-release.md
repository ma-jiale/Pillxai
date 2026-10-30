# 2026-10-30 平板切换正式版

目标：通过用户已连接的 USB，将华为 BTKR-W00 平板上的 V2 应用更新为正式签名版。用户明确确认旧版仅用于测试，授权清除其本机数据后安装正式版；服务器数据未操作。

## 安装来源与结果

- 原安装：`com.pillxai.pillxai_client`，0.1.0 / 1，带 `DEBUGGABLE` 标志，使用开发签名。安装前任务页显示设备未连接，无进行中的任务界面。
- 新安装：同包名，0.2.0 / 2，正式 Release，不带 `DEBUGGABLE` 标志。平板 Android API 31 / arm64，满足 APK 的最低 API 24 和架构要求。
- 客户端、依赖包、资源和构建脚本与已合并 `main` 提交 `701d6b31fd0d33cb1aeb3d3e512c11712a64a189` 的内容一致；未包含工作区中的服务端权限修复。
- API 地址：`https://ixd.sjtu.edu.cn/pillxai`。
- 正式证书 SHA-256：`750B500737467A051DA7AB7C21848AF4620BB47523FF8A2B507F08B9929B1670`，`apksigner verify` 通过。
- APK SHA-256：`669435D127A0F680E82E9E288492F02A7BA52E91CBAEA3E6EAA7097D69B1D68A`。
- 用户授权后卸载旧开发签名包并安装正式包，两步均返回 `Success`；启动返回 `Status: ok`。读取平板安装后的 APK 哈希，与已验证包一致；实际画面正常显示登录页。

本次是首次签名切换，旧应用本机数据已清除，需要重新登录、配置本机设备并授予蓝牙权限。后续同一正式签名的递增版本应采用保留数据的覆盖安装。

## 构建验证与 CI 限制

实际触发了 [Android Client Release #1](https://github.com/ma-jiale/Pillxai/actions/runs/40989090451)，参数为 main、0.2.0、2、上述 API 地址及 `docs/validation/2026-10-29-ota.md`。该次运行在依赖解析阶段失败：仅浅拉取固定 Flutter 提交，缺少版本标签，SDK 被识别为 `0.0.0-unknown`，不能满足 `file_selector` 的 Flutter 版本约束；未生成远端制品。

本次 USB 安装改用本机同一 Flutter 提交 `6655482ec06e547f90abf8ae7590466f4415978d`（3.47.1）构建，并使用已保管的正式密钥签名。安装包不是上述失败工作流的 CI 制品。本地完成与发布流程对应的验证：依赖锁定检查通过、Flutter analyze 无问题、20 项客户端测试和 74 项设备执行核心测试通过，Release 构建及正式签名核对通过。

工作流修复为获取 `3.47.1` 标签、验证其对应固定提交，再检出固定提交；actionlint 通过。该修复随 `codex/fix-ota-release-permissions` 分支交付，尚待合入 main 并在 GitHub 重新运行。

本地安装包和公开构建记录保存在 Git 忽略目录 `.var/pad-update-2026-10-30/`。本次未上传 APK 到更新服务器；未测试登录后的真实业务、蓝牙摆药和应用内下载/系统安装。USB 安装成功不替代这些验收。
