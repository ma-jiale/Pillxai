# HTTP 契约

唯一模型源为 `apps/api/src/pillxai_api/contracts.py` 及 FastAPI 的实际路由声明。`openapi.json` 和 `packages/api_client` 都通过命令生成。

```powershell
.\scripts\contracts.ps1
.\scripts\contracts.ps1 -Check
```

生成器固定为 OpenAPI Generator 7.26.0，JAR 在项目 `.tools`，脚本校验 SHA-256。`generator.json` 固定配置，`templates/pubspec.mustache` 是项目维护的依赖模板，避免默认模板的旧测试依赖；修改模板后也须重新生成。发布辅助脚本不属于本 SDK，由生成脚本去掉。

`-Check` 比较重新导出的 OpenAPI、SDK 源文件清单与内容、生成 pubspec。OpenAPI 3.1 在该生成器中仍有 beta 提示；本轮实际验证了本契约使用的枚举、可空值、日期、带时区时间、精确数量和版本冲突，不能据此承诺任意复杂 schema 都受支持。

共享输入在 `tests/fixtures/contract-sample.json`。Flutter 的 `test/api_contract_test.dart` 验证本地序列化，`tool/check_backend.dart` 使用生成 SDK 真实调用 WSL 服务和 PostgreSQL。开发样例 API 不代表处方、任务或设备启动许可；生产业务将在后续阶段使用同一生成链添加。
