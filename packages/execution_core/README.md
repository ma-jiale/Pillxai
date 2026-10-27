# 执行模块公开入口

纯 Dart 公开边界包含 `DeviceTransport`、`DeviceEvent` 和可持久化 `ExecutionState`，不依赖 Flutter、Windows 或 Android。反馈不虚构任务编号，RFID 无卡不表示药盒已离轨。

状态机与存储具体实现位于 device_runtime 的 ExecutionEngine/ExecutionJournal，公开任务快照由 API 契约生成。Windows 宿主已经通过双盘模拟、重启核对、暂停恢复、受控取消与补传测试；平台实机仍待验收。工程 ProbeSession 保留为独立诊断工具，不作为正式任务执行入口。
