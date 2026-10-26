# 本机设备基础运行模块

公开入口见 `lib/device_runtime.dart`。当前交付 Windows COM 传输、脚本字节模拟器、工程联调会话与 SQLite 诊断日志。模块不依赖页面和 FastAPI 内部。

- Windows 以显式 COM 打开 115200、8N1、无流控连接。候选枚举不核实 HC-06 身份，连接不自动发命令；读操作立即返回可用字节，写超时有界，部分写入或错误不重试。
- `ProbeSession` 记录打开、原始输入、解析事件、发送意图/写出结果和错误；一次最多发送一个明确命令。写出不表示 ACK，观察结束不表示机器停止。
- `DiagnosticJournal` 以 SQLite WAL/FULL 保存工程记录，原始接收与解析事件同事务写入；未结束会话重开仍保留原证据，不补写成功。它不是生产任务快照或结果补传队列。
- `SimulatedTransport` 实现同一字节传输接口。模拟器输入仅用于软件验证，不伪造实机任务身份或取盒能力。

当前同步 COM I/O 用于独立 CLI。接入 Flutter UI 时需放入独立运行宿主/工作 isolate，不能占用渲染 isolate；Android RFCOMM、USB 和前台服务尚未实现。实机连接、断联行为及机械动作尚未验证。

```powershell
.\scripts\dart.ps1 packages/device_runtime pub get
.\scripts\dart.ps1 packages/device_runtime analyze
.\scripts\dart.ps1 packages/device_runtime test
```

本轮 3 项测试通过：监听不下发、日志关闭再打开、未知写出只尝试一次、未结束会话不变成完成。SQLite 原生库由 sqlite3 包的构建钩子下载并校验；包与构建缓存均在项目范围。
