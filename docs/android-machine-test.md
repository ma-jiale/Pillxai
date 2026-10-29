# Android 平板联调

更新：2026-10-29。用户确认日常平板只使用正式版。正式安装来自 `main` 的签名 Release，步骤见 [Android 发布说明](../deploy/android-client/README.md)。开发模拟器、Windows 的已验证行为和正式版实际 HC-06 的行为分别验收。

## 构建与安装

仓库根执行：

```powershell
# 只构建独立开发包；不安装、不连接机器
.\scripts\run-android.ps1

# 指定开发模拟器，并将同机 API 映射到模拟器 localhost
.\scripts\run-android.ps1 -DeviceId emulator-5554 -ReverseLocalApi

# 使用指定服务器
.\scripts\run-android.ps1 -ApiUrl https://your-server.example -DeviceId emulator-5554
```

脚本使用已有 Android SDK，不安装全局工具；Flutter/Gradle/临时缓存留在仓库 `.tools`。输出为 `apps/client/build/app/outputs/flutter-apk/app-debug.apk`，独立包名 `.development`，名称“Pillxai 开发”。脚本拒绝实体设备，检测到开发包进程时拒绝覆盖安装。平板只安装已验证的正式签名制品，升级前须完成任务、取盒和同步；不要清除应用数据或卸载仍有待同步记录的应用。

同机后端按 `apps/api/README.md` 启动。模拟器 reverse 需要保持 ADB 连接。Debug/Profile 允许开发 HTTP；正式 Release 禁止明文 HTTP，须配置 HTTPS 和正式签名，不能再沿用开发密钥。实机验收使用正式制品和对应的 HTTPS 服务。

开发模拟器使用电脑局域网 API 时，本机已配置的 WSL 镜像网络可提供 API。先停止已有 API 进程，再执行：

```powershell
.\scripts\backend.ps1 db-start
.\scripts\backend.ps1 serve -ApiHost 0.0.0.0
# 在另一个终端构建；地址应替换为当次电脑 WLAN IPv4
.\scripts\run-android.ps1 -ApiUrl http://192.168.26.246:8000 -DeviceId emulator-5554
```

此方式不使用 `-ReverseLocalApi`。用模拟器浏览器打开同一地址的 `/health/ready`，并核对服务端响应，才能确认局域网连通；仅 IP 同网段不能代替验证。地址改变后需要重新构建开发包。API 进程和电脑须保持运行；这不是正式平板部署方式。

## 首次连接 HC-06

1. 在 Android 系统蓝牙设置中配对已确认的机器。应用只列出已配对设备，不扫描附近设备、不猜测 PIN 或自动选择机器。
2. 登录后进入“摆药 → 连接设备”，选择“Android 蓝牙 HC-06”，点击“读取已配对设备”。授予“附近设备”权限；建议允许通知，以便查看后台执行状态。
3. 按名称和蓝牙地址核对机器，选择后保存连接。地址作为本机连接目标，设备业务身份与终端归属仍由服务器保存。任务期间禁止换机或更改配置。
4. 逐项核实物理行列、每药参数及在轨/离轨/就绪反馈。没有实测依据时不填写假反馈、不使用模拟参数开始实机任务。具体事实清单沿用 `04-device-contract.md` 和 Windows 上机指南。
5. 点击“连接”只建立 RFCOMM 通道，不自动下发动作；“开仓读取标签”和领取任务均属于显式操作。按原流程领取、识别并取得服务端启动许可后开始。

本版实现经典蓝牙 SPP（标准 UUID），不是 BLE；Android USB 串口尚未实现。连接超时、权限拒绝、蓝牙关闭、读取失败与接收缓冲区溢出均显示失败，不自动重连或重发矩阵。尚需实际 HC-06 验证配对和通信兼容性。

## 生命周期与数据

- `TerminalService` 持有独立 FlutterEngine，运行同一 `TerminalSession/ExecutionEngine`。Activity 仅转发命令并显示快照，切页和界面重新连接不会新建执行状态机。
- 连接时从前台启动 `connectedDevice` 服务并展示常驻通知；通知仅含阶段，不含长者姓名、药物或凭据。任务需要设备反馈时持有有超时、可释放的 partial wake lock，并由服务心跳续期；空闲、结束、断联及销毁时释放。
- SQLite 位于 Android `noBackupFilesDir/terminal`，并关闭应用自动备份。事件、快照、待同步队列由同一原子写入保存；登录令牌仅在服务内存中。
- 后台服务独立补传事件；界面回来重新读取真实快照。没有网络或登录已失效时保留记录；进程重启后登录原账号再补传，不离线领取或首次启动任务。
- 用户于 2026-10-27 确认划掉最近任务仍继续后台运行，只通过应用内操作结束任务。根页面系统返回同样退到后台；弹窗返回仅关闭弹窗。应用内结束仍须停止、现场确认和同步，不能直接销毁服务。系统强制停止/崩溃不会被记录为“已经机械停机”；重开必须核对现场，不自动连接或重发矩阵。
- 划掉最近任务仅移除界面，保留已启动服务；这是用户已确认的行为。系统主动杀进程时不能保证服务继续，必须按异常恢复处理。

平台依据：[Android 蓝牙权限](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)、[connectedDevice 前台服务要求](https://developer.android.com/develop/background-work/services/fgs/service-types#connected-device)、[FlutterEngine 后台执行](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/FlutterEngine.html)。这些平台机制不是平板实测通过的证据。

## 模拟器复验

```powershell
.\scripts\check-android.ps1 -DeviceId emulator-5580
```

必须使用专用模拟器。脚本只安装和清除独立包 `com.pillxai.pillxai_client.runtimecheck`，不清除普通客户端；测试入口必须显式使用 `PILLXAI_RUNTIME_CHECK=true`。运行内容包括服务 IPC、模拟双盘、关闭屏幕继续执行、模拟器本地 HTTP 接收分页补传，以及 force-stop 后恢复核对、禁止自动重发。HTTP 接收端是测试替身，不代表真实 API/PostgreSQL 联调已通过。日志保存在 `.tools/android-runtime-check.log`。

该测试入口含虚构任务和确认回执，仅用于工程验证；普通 `lib/main.dart` 不提供这些绕过服务端许可的入口。正式交付使用 `main` 的 Android Client Release 制品，不能交付该测试包或 `run-android.ps1` 开发包。

## 实体平板待验收

- Android 版本、厂商电池策略、真实 HC-06 连接与断联、权限拒绝后重试。
- 从真实 API 建资料和领取任务，经蓝牙执行完整多药/双盘、换盘识别与取盒反馈。
- 切后台、锁屏、长时运行、来电/其他应用、断网后续执行和恢复网络补传。
- 系统返回、最近任务移除、强制停止、终端断电与机器复位分别核对；不得把断开连接当作机械已停。
- 200 位长者/6 台机器负载、生产 HTTPS/签名安装包、云端与院内备份恢复仍是后续交付。

实际结果见 `validation/2026-10-27-android.md`，不能以本指南代替完成证据。
