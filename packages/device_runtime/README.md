# 本机设备执行运行模块

公开入口见 `lib/device_runtime.dart`。当前交付 Windows COM、字节协议模拟器、任务状态机、SQLite 原子快照/事件/补传队列和独立 Isolate 工作宿主。模块只依赖公开 SDK、execution_core 和 device_protocol，不依赖页面、FastAPI 内部或中央数据库。

- Windows 以显式 COM 打开 115200、8N1、无流控连接。候选枚举不核实 HC-06 身份，连接不自动发命令；读操作立即返回可用字节，写超时有界，部分写入或错误不重试。
- `ProbeSession` 记录打开、原始输入、解析事件、发送意图/写出结果和错误；一次最多发送一个明确命令。写出不表示 ACK，观察结束不表示机器停止。
- `DiagnosticJournal` 以 SQLite WAL/FULL 保存工程记录，原始接收与解析事件同事务写入；未结束会话重开仍保留原证据，不补写成功。它不是生产任务快照或结果补传队列。
- `SimulatedTransport` 实现同一字节传输接口。模拟器输入仅用于软件验证，不伪造实机任务身份或取盒能力。

`ExecutionEngine` 独占动作与反馈关联；`ExecutionJournal` 用 SQLite WAL/FULL 将任务状态和事件同事务保存；`MachineSimulator` 消费真实编码并产生计数/完成/位置反馈。`TerminalSession` 串行处理轮询与命令；Windows `terminalWorker` 在独立 Isolate 中装配 COM，UI 和网络不持有串口。首次矩阵需要中央启动许可，后续快照可离线执行；重启进入现场核对，绝不自动重发矩阵。`NativeTerminalHost` 在客户端建立进程间文件锁阻止双重宿主。Android 客户端以独立前台服务 FlutterEngine 装配同一会话，已实现 RFCOMM 与后台补传并通过 Android 15 模拟器生命周期测试；Android USB 尚未实现，两端真实 HC-06 均待验收，见 [Android 报告](../../docs/validation/2026-10-27-android.md)。

```powershell
.\scripts\dart.ps1 packages/device_runtime pub get
.\scripts\dart.ps1 packages/device_runtime analyze
.\scripts\dart.ps1 packages/device_runtime test
```

2026-10-27 复验 10 项运行模块测试通过；真实服务双盘闭环和 Windows 宿主测试也通过，具体见 [执行报告](../../docs/validation/2026-10-26-execution.md)。SQLite 原生库由 sqlite3 包的构建钩子下载并校验，依赖和缓存均在项目目录。无实机任务 ID 的协议不能完全区分迟到反馈；矛盾或重叠应答进入核对。跳过后继续及人工补齐仍待实现。
