# identity

拥有账号、密码摘要、可撤销会话与账号操作审计。`service.py` 提供 AccountDep/ConnectionDep 与 require_admin/require_maintain，其他模块不自行解码身份。`models.py` 为公开 HTTP 模型，`tables.py` 为内部存储。

只有管理员和工作人员。管理员可创建账号并管理其他账号，工作人员默认只读，授权后可维护资料。本人改密使用独立入口；停用/改密撤销会话。账号审计当前保留动作、版本、人员和时间，管理审计页面、完整权限快照与生产登录防护仍待后续实现。

数据库迁移与运行见 `apps/api/README.md`；权限、撤销与改密验证在 `tests/test_business.py`。仅显式 `backend.ps1 seed` 创建本地开发凭据，不在服务启动时自动建立账号。
