# Windows 工程联调入口

此工具复用新协议和本机模块，独立于后端与 GUI。不会创建长者任务、生产结果或覆盖。当前真实执行链与自动逐药流程尚未接入。

从仓库根目录执行：

```powershell
.\scripts\dart.ps1 tools/device_probe pub get
.\scripts\device-probe.ps1 list
.\scripts\device-probe.ps1 simulate --seconds 1
.\scripts\device-probe.ps1 history
```

本轮候选枚举结果为 COM3、COM4、COM7、COM10；尚未核实哪一个是当前 HC-06 出站口。不要按列表顺序或历史 COM7 自动选择。

核实端口后，只监听的命令如下。将 `<实际出站COM>` 替换为当前设备端口：

```powershell
.\scripts\device-probe.ps1 listen --port <实际出站COM> --seconds 30
```

离线编码可先核对，不打开设备：

```powershell
.\scripts\device-probe.ps1 encode --command gate --value 0.7
```

0.7 是文档中的编码样例，不是生产初值。`send` 才会实际写出，必须指定 `--port`、`--command` 和 `--confirm-physical-command`；gate/turntable 还须提供现场确认的 `--value`，matrix 须提供 `--matrix` JSON 文件（4 行、每行 7 个整数）。支持 stop、resume、exit、open、close、gate、turntable、matrix；每次只发一条，不自动串联动作、不重试。

参数→矩阵、停转 ACK→退出 ACK/DONE→下一动作仍需按设备约定现场逐步核对。工具只展示原始反馈与解析，不声称无任务号协议可以可靠识别迟到反馈。Ctrl+C 或监听超时只结束观察并关闭连接，不发送停转、不表示机器已停稳。

默认日志为仓库 `.var/device-probe/diagnostics.sqlite`，可用 `--database` 指定本项目内其他诊断文件。记录区分 simulator/hardware，包含原始字节、事件、时间、会话和结果；`history` 查看会话，不删除记录。实机前须核对当前设备身份、现场状态、允许参数和位置映射，详见 `docs/09-agent-development.md` 第 10 节。
