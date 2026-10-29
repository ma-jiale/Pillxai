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

2026-10-28 药盒准备取消修复：新增本机 `cancel_preparation` 操作，先读取排队反馈，再检查尚未开始、本机连接、当前无标识，且本次开仓完成后从未观察到药盒或已有有效取盒证据，才发送 `close_preparation`（协议仍为 04）。ACK、DONE 后保存取消事实；不写 `collection_ready`、完成批次或覆盖。准备弹窗内移走药盒不自动收仓；按用户最新要求，从未放盒的当前开仓会话也可明确关闭，不等待不存在的初始无盒反馈。52 项运行测试及 5 项协议测试通过，含正确/错误/未绑定药盒、换回正确盒、显式关闭、其他条码消失、重复关闭、缺 ACK 和收仓时重新放盒。全部使用模拟器，无本轮实机验收。

同日晚实机反馈修正：22:29–22:30 日志确认当前任务已接收到 `APPEARED` 与相同条码的 `DISAPPEARED`，但学校服务设备快照的 `barcode_removal_closes=false`。首轮实现错误地让准备取消的无盒判断依赖此开关，造成按钮无效。按该配置先复现失败，再将明确点击关闭的取盒判断与最终自动收仓策略分开；24 项准备场景覆盖开关开启/关闭、正确/错误/未绑定药盒，全部通过。未改服务端设备配置或既有任务快照；实机收仓动作仍待再次确认。
