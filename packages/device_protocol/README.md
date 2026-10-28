# STM32 协议

依据 `docs/04-device-contract.md` 的已确认事实独立实现，未读取旧代码。公开入口为 `Stm32Commands`、`FeedbackDecoder`、`parseFeedback`。

编码包含停转、恢复、退出本药、开关仓、显式转盘/舵机设置、4×7 行优先矩阵。值不做截断或默认填充；没有生产初值。矩阵是设备坐标，业务日期到物理位置的映射由后续计划/适配配置负责。

反馈按 LF/CRLF 分帧，支持拆包和粘包；单行默认最多 4096 字节，超限丢弃至换行并输出异常，不把尾部误认作 ACK。断开时保留未完整行的异常。ACK、DONE、FINISH、累计计数、原始脉宽、RFID 与未知消息分别表达，不在此模块判定生产完成或取盒。

```powershell
.\scripts\dart.ps1 packages/device_protocol pub get
.\scripts\dart.ps1 packages/device_protocol analyze
.\scripts\dart.ps1 packages/device_protocol test
```

本轮 4 项测试通过，包含已确认字节样例、矩阵边界、全部分片位置、过长/未完整报文。它们验证编码解析，不证明真实机器动作或反馈时序。
