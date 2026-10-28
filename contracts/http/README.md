# HTTP 契约

唯一模型源为 API 各业务模块的 Pydantic 模型及 FastAPI 路由声明。`openapi.json` 和 `packages/api_client` 都通过命令生成。

```powershell
.\scripts\contracts.ps1
.\scripts\contracts.ps1 -Check
```

生成器固定为 OpenAPI Generator 7.26.0，JAR 在项目 `.tools`，脚本校验 SHA-256。`generator.json` 固定配置，`templates/pubspec.mustache` 是项目维护的依赖模板，避免默认模板的旧测试依赖；修改模板后也须重新生成。发布辅助脚本不属于本 SDK，由生成脚本去掉。

`-Check` 比较重新导出的 OpenAPI、SDK 源文件清单与内容、生成 pubspec。OpenAPI 3.1 在该生成器中仍有 beta 提示；本轮实际验证了本契约使用的枚举、可空值、日期、带时区时间、精确数量和版本冲突，不能据此承诺任意复杂 schema 都受支持。

计划快照新增日期数组。7.26.0 对数组产生不存在的 `DateTime.listFromJson` 调用，`scripts/contracts.ps1` 在生成流程内统一转换为逐项 DateTime.parse，漂移检查执行相同修正；不手工修改 SDK。真实 SDK 往返与页面测试均覆盖此路径。

首次上机的处方尚无独立参数时，参数查询按契约返回 JSON `null`。7.26.0 为 `ParameterView` 生成了不可空的响应转换，导致上机准备误报连接失败；生成脚本统一修正该响应转换为可空类型。`test/prepare_execution_test.dart` 覆盖无参数及已有参数的 SDK 响应，以及首次上机加载、保留空参数和绑定标签、不发送机器动作的页面流程。

共享输入在 `tests/fixtures/contract-sample.json`。Flutter 的 `test/api_contract_test.dart` 验证本地序列化，`tool/check_backend.dart` 使用生成 SDK 真实调用 WSL 服务和 PostgreSQL。开发样例 API 不代表处方、任务或设备启动许可；生产业务将在后续阶段使用同一生成链添加。
