# Android 正式签名配置

2026-10-29 按用户授权建立，适用于 V2 包 `com.pillxai.pillxai_client`。仅记录公开身份和操作说明，不包含密码或私钥。

## 正式证书

- 主体：`CN=Pillxai Android Release, O=Pillxai Project Team, C=CN`。
- 算法：RSA 4096 位；生成时有效期 10000 天。
- 密钥库格式：PKCS12；alias：`pillxai-android`。
- SHA-256：`750B500737467A051DA7AB7C21848AF4620BB47523FF8A2B507F08B9929B1670`。

后续版本必须复用该密钥，不因换电脑、版本递增或 CI 重建而重新生成。正式签名不兼容既有 debug 签名；首次切换前须确认本机任务、补传和数据保留方案。

## GitHub 配置

已在 [android-client-release](https://github.com/ma-jiale/Pillxai/settings/environments/25674173428/edit) 保存并重新加载核对：

- Deployment branches and tags：Selected branches and tags，仅分支 `main`，0 个标签规则。
- Secrets：`ANDROID_SIGNING_STORE_BASE64`、`ANDROID_SIGNING_STORE_PASSWORD`、`ANDROID_SIGNING_KEY_ALIAS`、`ANDROID_SIGNING_KEY_PASSWORD`。
- 环境变量：`ANDROID_SIGNING_CERT_SHA256`，对应上面的公开证书指纹。

没有创建每次发布的额外审批要求。正式发布工作流仍为手动触发；合并到 main 不会自动向平板发布 APK。构建成功后发布工具检查正式包名、稳定版本名、非调试构建及证书指纹。GitHub 界面只能核对 Secret 名称和保存状态，值不可读回；2026-10-30 首次运行在 Flutter 版本识别阶段失败，远端工作流取用这些 Secrets 的完整构建仍待验证。

## 本机保管与恢复

本机目录为项目根下 `.signing/android-release/`，已被 Git 忽略；目录 ACL 仅允许创建密钥的 Windows 用户和 SYSTEM 访问。

| 文件 | 用途 |
| --- | --- |
| `pillxai-android-release.p12` | 受随机密码保护的正式私钥库 |
| `password.dpapi` | 使用当前 Windows 用户 DPAPI 加密的密码；不能作为跨机器唯一恢复材料 |
| `certificate.pem`、`public-metadata.json` | 公开证书和指纹记录 |
| `verification/feature-branch-verification-only.apk` | 本地签名配置验证制品，未按 main 发布流程交付，不分发到平板 |

不要清理此目录或将其中密钥上传到仓库、普通附件、聊天或公开制品。`.gitignore` 同时忽略 `.jks`、`.p12`、`.pfx`，避免密钥移位后误提交。

独立备份尚需落实：备份应包含私钥库及存放在受控密码管理器或离线介质中的可恢复密码。仅复制 `password.dpapi` 到另一台电脑并不能保证能解密；GitHub Secrets 不能读取原值，也不能代替密钥备份。迁移前应在当前 Windows 用户下解密密码并安全保管，不在终端日志中打印。未指定独立备份位置，本轮没有将密钥复制到项目以外。

## 已验证与未执行

已使用该密钥完成本地通用 Release 构建（0.2.0 / 2），`apksigner verify --verbose --print-certs` 通过，签名方案 v2，签名者数量 1，证书 SHA-256 与以上记录一致。构建来自当前功能分支，仅验证签名配置，不作为正式发布证据。

GitHub 环境保存、分支规则和四项 Secrets 名称已验证。2026-10-30 首次远端正式构建在签名步骤之前失败；随后用本机工具链从相同 main 内容构建正式 0.2.0 / 2，正式证书验签通过，并按用户授权清除旧测试版后安装到华为平板，正常启动至登录页。实际安装包及验证见 [平板安装记录](../../docs/validation/2026-10-30-pad-release.md)。尚未上传更新服务器，不替代 HTTPS 下载和应用内系统安装验收。
