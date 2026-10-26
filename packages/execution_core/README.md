# 执行模块公开入口

当前 M0 只建立 `DeviceTransport` 与 `DeviceEvent` 的纯 Dart 公开边界，不依赖 Flutter、Windows 或 Android。反馈不虚构任务编号，RFID 无卡不表示药盒已离轨。

生产任务状态机、启动许可、本地任务快照、允许动作、同步队列与恢复流程将在 M3 实现。本包目前不能启动生产摆药；不要将工程 ProbeSession 当作任务执行器。
