# Android 客户端发布与应用内更新

适用 V2 Flutter Android；OTA 已由 PR #13 合入 `main`。首次安装由维护人员提供，后续自动检查/下载、人工确认安装。Android 的未知来源授权与系统安装确认必须如实处理，不承诺静默安装。

2026-10-29 用户确认当前学校服务地址为 `https://ixd.sjtu.edu.cn/pillxai`，正式打包的 `api_url` 使用此值。就绪接口 `/pillxai/health/ready` 已实测返回 200；更新接口曾因发布目录权限为 0700 返回 500，用户将目录改为 0755 后，已实测返回 200 和 `{"api_compatibility":1,"release":null}`，表示尚未发布 APK。

2026-10-29 用户确认日常只使用正式版：分发入口仅接受 `main` 的正式签名 Release，版本名为 `主.次.修订`，不发布 alpha/beta/rc。普通 Debug/Profile 使用独立 `.development` 包名和“Pillxai 开发”名称，模拟器验证使用 `.runtimecheck` 和“Pillxai 测试”；两者都不能通过正式发布工具。`run-android.ps1` 仅用于开发模拟器，不用于平板交付。

## 发布身份与构建

2026-10-30 已按用户授权在华为平板清除旧测试版并安装正式 0.2.0 / 2。首次 CI 构建因 Flutter 版本标签缺失失败，本次使用同一已合并 main 内容和固定工具链在本机构建、验签后经 USB 安装，未上传更新服务器；验证及构建来源见 [平板安装记录](../../docs/validation/2026-10-30-pad-release.md)。工作流标签修复已在本地完成，尚待合入及远端复验。

包名固定为 `com.pillxai.pillxai_client`。`versionName` 用于展示，`versionCode` 必须严格递增。正式构建必须使用长期保管的正式签名；不要提交私钥、密码或密钥库。当前测试平板曾用 debug 签名，正式签名包不能直接覆盖它；首次切换须先确定已有 V2 本机数据的保留方案，不能卸载清数据作为日常升级。

构建环境提供：

- `PILLXAI_SIGNING_STORE`：密钥库绝对路径。
- `PILLXAI_SIGNING_STORE_PASSWORD`、`PILLXAI_SIGNING_KEY_ALIAS`、`PILLXAI_SIGNING_KEY_PASSWORD`：通过进程环境或 CI Secrets 提供。

正式交付使用下述 `main` CI 制品。维护人员本地复验可调用 `scripts/flutter.cmd build apk --release --no-pub --build-name=0.2.0 --build-number=2 --dart-define=PILLXAI_API_URL=https://ixd.sjtu.edu.cn/pillxai`，不以本地未审查构建替代正式发布。正式包拒绝无签名、演示模式或调试签名绕过；`PILLXAI_ALLOW_DEBUG_SIGNING=true` 只在同时显式启用 `PILLXAI_RUNTIME_CHECK=true` 的隔离包中有效。发布工具没有允许调试包的开关。该例中的版本号须高于已安装的实际构建号。

GitHub 的 **Android Client Release** 工作流为手动触发，仅 `main` 可以运行构建，其他分支跳过，不随 main push 发布客户端。配置 `android-client-release` environment，将 Deployment branches and tags 限制为 `main`，并配置四个 Secret：`ANDROID_SIGNING_STORE_BASE64`、`ANDROID_SIGNING_STORE_PASSWORD`、`ANDROID_SIGNING_KEY_ALIAS`、`ANDROID_SIGNING_KEY_PASSWORD`。输入展示版本、构建号、HTTPS API 地址及仓库内 UTF-8 更新说明文件。工作流固定 Flutter 提交，运行客户端/执行测试，构建完整 APK 并上传发布制品。构建完成不代表已向平板发布。Environment 限制和 Secrets 需要在 GitHub 实际设置，仓库内的分支判断不代替环境保护。

2026-10-29 已实际建立上述环境、四项 Secrets 和仅 `main` 分支规则，并添加环境变量 `ANDROID_SIGNING_CERT_SHA256`。发布工具必须核对 APK 证书与该指纹一致，不能仅凭“不是 debug 签名”放行。证书身份、本地保管与验签结果见 [正式签名记录](signing.md)。工作流代码已合入 `main`，环境配置及合并本身不触发 Android 发布。

## 清单与服务器托管

HTTP 权威模型是 `apps/api/src/pillxai_api/releases.py`，OpenAPI/Dart SDK 通过 `scripts/contracts.ps1` 生成。

- `GET /releases/android`：接口兼容代号和当前清单；未发布时 `release=null`，损坏清单返回失败。
- `GET /releases/android/packages/{sha256}`：当前发布 APK，撤回后不再提供。
- 当前兼容代号为 1；每次发布声明 `min_api`/`max_api`。它是维护的接口兼容代号，不是 git 提交号；破坏性接口变化必须递增并验证旧客户端的结果补传。

发布工具使用现有项目 Python 环境（需要 API 依赖）及 Android SDK 的 `aapt`、`apksigner`：

```sh
python scripts/publish-client-release.py \
  --apk /absolute/path/app-release.apk \
  --output /absolute/path/client-releases \
  --aapt /absolute/path/build-tools/aapt \
  --apksigner /absolute/path/build-tools/apksigner \
  --expected-certificate-sha256 "$ANDROID_SIGNING_CERT_SHA256" \
  --notes /absolute/path/notes.txt --min-api 1 --max-api 1
```

输出为 `<sha256>.apk` 和 `current.json`。工具验签、从 APK 读取元数据、拒绝非递增构建，最后原子替换清单；`.publish-lock` 避免并发发布。中断留下锁时，确认无其他发布进程后再处理，不能直接覆盖清单。保持文件对容器 UID 10001 可读，目录可遍历。

本地运行时将 `ANDROID_SIGNING_CERT_SHA256` 设置为正式签名记录中的公开指纹；CI 从 GitHub Environment 变量读取。缺少或不匹配的指纹都会拒绝发布。

V2 Compose 自动将 `shared/client-releases` 只读挂载到 API 的 `/client-releases`，空目录表示尚未发布；部署工具升级时创建该目录且保留已有制品。非 Compose 的院内服务设置 `PILLXAI_CLIENT_RELEASES_DIRECTORY`。发布包不包含长者资料。正式服务必须 HTTPS，反向代理保留原 API 路径前缀；发布文件不得被代理长期缓存。

CI 制品先放入独立待验目录，核对来源提交和 APK SHA-256，再将 APK 放入上述发布目录，最后原子替换 `current.json`。首次发布先在测试平板验证，再公开同一制品。回撤时移走 `current.json`，保留 APK 供诊断；客户端安装前会重新查询当前发布。修复已安装坏版本时发布更高构建号，不假定 Android 允许降级，也不假定旧代码支持新 SQLite 格式。

## 本机保护与恢复

应用登录后检查，运行期间每六小时检查，恢复前台时补查过期信息。默认自动下载，开关持久化；进程终止后不承诺后台继续下载，再打开时重新检查并从头下载。下载有超时、大小上限、剩余空间检查及临时文件，拒绝 HTTP 和重定向。完成和安装前均校验 SHA-256、包名、版本及与当前应用一致的签名。

安装由工作人员发起，并再次核对当前部署与发布兼容性。执行宿主串行检查活动任务、未知领取、未上传记录、未完成设备动作和存储失败，持久化更新锁后断开空闲连接。锁期间拒绝新任务、开仓、连接和退出服务，允许读取状态。Android 系统负责 APK 替换；失败或取消后先结束安装会话，再使用原 token 解锁。重开应用时核对版本/会话，未知安装仍保留锁，可明确取消；不自动驱动硬件。

当前没有应用数据格式迁移；不会清空 SQLite、绑定或设置。账号令牌仍按原设计仅存于内存，升级重启后需重新登录。中央升级审计、断点续传、Windows/iOS 更新与无界面自动安装尚未实现。

## 验证入口

```powershell
.\scripts\dart.ps1 packages/device_runtime test
.\scripts\flutter.cmd test --no-pub test/app_update_test.dart test/business_ui_test.dart
.\scripts\flutter.cmd analyze --no-pub
.\scripts\contracts.ps1 -Check
.\scripts\check-ota-android.ps1 -DeviceId emulator-5554
```

最后一项只接受模拟器与独立 `runtimecheck` 包，重置的是隔离测试应用。它构建 1001→1002 两个包及错误签名样例，验证原生校验、取消、系统确认覆盖安装和数据/更新锁恢复。证据保存在 `.var/ota-check/`；测试密钥只是隔离样例，不能用于发布。测试不连接真实蓝牙、业务 API 或实体机器。发布接口/发布工具测试为 `apps/api/tests/test_releases.py` 和 `test_client_publisher.py`。实际通过及未测范围见 `docs/validation/2026-10-29-ota.md`。

若 Play Protect 拦截测试签名，脚本报告系统安装未通过，不关闭系统保护。可在该测试状态保留时另跑 `scripts/check-ota-android.ps1 -DeviceId emulator-5554 -RecoveryOnly`，仅通过 ADB 覆盖隔离包以检查数据和锁恢复；该结果不代表应用内系统安装流程通过。
