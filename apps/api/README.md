# Pillxai API — 账号、长者与处方

服务器部署入口见 [V2 独立部署](../../deploy/v2-server/README.md)：GitHub 构建镜像、学校 Runner 发布，独立 PostgreSQL 和 `/dispenser-v2/`，与 V1 并行。WSL 命令仍用于本机开发；正式部署不使用开发 `seed` 或开启契约探针。实际上线状态须以部署报告与健康检查为准。

中央服务独立运行于 WSL Ubuntu-24.04，Windows/Flutter 通过 HTTP 调用。这里不包含串口、蓝牙或设备命令。已实现真实账号、账号权限、长者及资料历史、处方保存/停用/恢复与版本、通用设置持久化和服务端计划预览。已新增 [tasks](src/pillxai_api/tasks/README.md)：设备/标签/独立参数、领取与启动许可、事件幂等、完整实机任务覆盖及取消/删除；双盘模拟联调已通过。资料切片证据见 [M1 报告](../../docs/validation/2026-10-26-m1.md)，本轮计划边界见 [planning](src/pillxai_api/planning/README.md)。

## 模块与契约

- 公开模型以各业务模块 `models.py` 和基础 `contracts.py` 为唯一源，统一导出 OpenAPI。精确剂量使用字符串，业务日期与带时区时间分别表达。
- `identity/`：账号、会话、权限与账号操作审计；角色和维护权限由服务端校验。
- `app_settings.py`：单例应用设置，保存天数、当天/次日起点、餐食分盘、睡前格及版本；业务时区固定 Asia/Shanghai。管理员通过版本条件更新，历史与操作人同事务保存。
- `planning/`：从处方版本和设置生成不可变预览快照；日期、分盘、逐格颗粒及原片等价量均由服务端计算。读取预览时核对版本与业务日期；不创建执行任务或覆盖。
- `residents/`：长者资料、院内非空床位唯一、游标分页及资料版本。
- `prescriptions/`：独立用药条目、药品身份、精确剂量/日期校验及不可覆盖的处方版本。
- `database.py`：事务入口和公开业务错误；事务在成功响应发出前提交，资料与历史同事务写入。
- `storage.py`：M0 开发样例的 PostgreSQL 读写，创建与修改使用数据库原子版本条件。不是生产处方仓库。
- `app.py`：应用装配与路由。默认关闭 `/dev/contract-samples`；只有显式设置 `PILLXAI_ENABLE_CONTRACT_PROBE=true` 才启用。
- `migrations`：Alembic 迁移，不在应用启动时隐式建表。
- `tools/export_openapi.py`：从应用导出 OpenAPI；`scripts/contracts.ps1` 生成 Dart SDK，不手改生成目录。

## 本机启动

从仓库根目录的 PowerShell 执行：

```powershell
.\scripts\backend.ps1 bootstrap
.\scripts\backend.ps1 db-init -DataDirectory /home/jiale/Workspace/Pillxai-Dispener/.var/postgres
.\scripts\backend.ps1 migrate
.\scripts\backend.ps1 seed
.\scripts\backend.ps1 serve
```

数据目录是用户于 2026-10-26 单独授权的 WSL 原生项目目录。当前 Windows 挂载目录不能保存 PostgreSQL 要求的 0700 权限。不要将数据目录指向旧数据库；初始化不会迁移旧资料。之后数据库可用 `db-start` / `db-stop` 单独控制，API 前台进程用 Ctrl+C 退出。

`seed` 仅在没有账号时显式创建 `local-admin`，随机密码写入忽略文件 `.var/local-login.json`；再次运行不会重置账号或覆盖业务资料。服务启动不自动 seed，不设公开默认密码。使用本机浏览器 `http://127.0.0.1:5180` 登录可维护真实持久化资料；演示账号 admin/admin123 仅属于 Flutter 显式演示构建。

当前为单工作区，只有 `admin` 和 `staff` 两类角色。接口直接使用 `/accounts`、`/residents`、`/residents/{resident_id}/prescriptions` 和 `/settings`，不保留机构 API 或字段。迁移 `20261026_single_workspace` 删除机构表和关联列、转换管理员角色并撤销原会话；长者、处方、历史和账号密码保留。前一份迁移仅作为已有数据库升级历史保留。迁移拒绝自动合并多个机构，遇到此情况先分别导出数据；不能直接丢弃数据或替用户选择归属。

账号会话有效 12 小时，令牌在服务端只存摘要；停用、改密与重置密码撤销会话。当前仅本机开发验证，生产 HTTPS、登录限流/安全加固及完整备份恢复仍待验收。开发 serve 显式允许 localhost/127.0.0.1 的 5180 预览来源；默认应用配置不开启 CORS 或 `/dev` 路由。

开发 API 默认监听 `127.0.0.1:8000`；在已配置的 WSL 镜像网络中，可使用 `scripts/backend.ps1 serve -ApiHost 0.0.0.0` 开放开发局域网访问。电脑和平板须连接同一网络，并以电脑的 WLAN IPv4 地址构建 Android 客户端；热点重连后须重新核对地址。2026-10-27 已验证实体平板通过手机热点访问 WSL 健康检查，证据见 [Android 报告](../../docs/validation/2026-10-27-android.md)。此参数不修改防火墙或 WSL 系统配置；需要新增系统规则时须单独获得授权。

PostgreSQL 继续只监听 `127.0.0.1:5432`。数据库口令自动创建，保存在未入库的 `.var/backend-password`，本地目录指针在 `.var/backend-pgdata.txt`。这些仅用于开发，正式部署需要独立配置和凭据管理。

Conda 前缀为仓库 `.tools/conda/backend`；环境和下载缓存不入库、不更改全局 PATH。`conda-linux-64.lock` 固定底层工具包，`requirements.lock` 固定 Python 包；重复 bootstrap 使用锁文件，不升级其他项目环境。WSL 发行版可由 PowerShell 的 `-Distribution` 参数指定；Conda 可通过进程变量 `PILLXAI_CONDA` 指定。

## 验证

另开终端，保留 API 运行：

```powershell
.\scripts\backend.ps1 test
.\scripts\backend.ps1 lint
.\scripts\contracts.ps1 -Check
.\scripts\dart.ps1 apps/client run tool/check_backend.dart
.\scripts\dart.ps1 apps/client run tool/check_business.dart
.\scripts\dart.ps1 apps/client run tool/check_planning.dart
```

测试仅使用 `pillxai_test`，开发检查使用 `pillxai_dev`，只新建明确标记的虚构联调资料。2026-10-26 当前 20 项测试通过，包含资料权限与历史、机构移除、设置并发版本、半片换算、未来和有限疗程、中间空日期、睡前需求、分盘、预览重读与失效。`check_planning.dart` 已经通过真实 SDK/API/PostgreSQL 验证设置保存、新客户端重读、双药双盘计划、日期数组、快照不变与设置修改后失效，并恢复测试前设置。测试库须先迁移；backend.ps1 test 要求测试数据库 URL，直接 pytest 缺少该 URL 时跳过集成用例不能算通过。

当前锁定组合仍产生一条 Starlette 对 httpx 测试客户端的弃用提示；后续升级测试适配时处理，不以隐藏警告代替兼容验证。基础数据库重启验证见 [M0 报告](../../docs/validation/2026-10-26-m0.md)，本轮业务与浏览器验证见 [M1 报告](../../docs/validation/2026-10-26-m1.md)。
