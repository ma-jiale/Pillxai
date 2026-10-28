# 2026-10-28 V2 服务器部署

用户要求按照同机并行方案部署新版，并新开分支。工作分支为 `codex/v2-server-deployment`，基于 `NT`。V1 与 V2 使用独立端口、Compose 项目、数据库、目录、凭据和发布流程。

## 已完成的仓库实现

- V2 API 镜像、Compose API/PostgreSQL/备份服务、一次性迁移入口。
- GitHub 托管机真实 PostgreSQL CI、镜像启动/认证/重启/恢复检查、实际 Compose 首次部署及二次更新检查。
- 学校 Runner 制品校验、V1 健康与资源预检、首次空库和随机管理员初始化、活动任务双重检查、备份、升级与条件回退。
- 每日数据库备份、摘要、备份健康状态、独立临时库恢复检查。
- 独立 HTTPS 代理片段与操作说明；未自动应用系统代理配置。
- API 环境配置支持只读数据库凭据文件、代理前缀、实际构建版本和生产登录请求预算。公开响应结构保持不变。

## 实际验证

| 验证 | 结果 |
| --- | --- |
| 项目 WSL PostgreSQL 后端回归 | 61 项通过，0 跳过；保留 Starlette/httpx 弃用与 Pydantic 既有提示 |
| V2 部署工具单元测试 | 10 项通过；Docker 命令模拟，覆盖 V1 路径/端口隔离、制品篡改、活动任务、迁移失败、首次失败、数据库版本变更与回退条件 |
| Ruff | 新后端与部署代码通过 |
| OpenAPI/Dart SDK | `scripts/contracts.ps1 -Check` 重新生成检查通过，无契约漂移 |
| GitHub 工作流 | 本机 actionlint 通过，学校自定义 Runner 标签按已知配置校验 |
| Compose | 本机官方 Compose `config --quiet` 通过 |
| 学校 Runner | GitHub 页面观察 `user-Super-Server`，标签 `self-hosted Linux X64 pillxa-server`，状态 Idle |
| 本机 Docker 镜像/容器 | 本机无 Docker Engine，未运行；必须由 GitHub 构建实际证明 |
| 学校 V2 内部服务 | 尚未部署 |
| HTTPS、新旧共存、恢复演练 | 尚未实测 |

## 发布状态

首次推送被自动审批拦截，理由为尚未明确确认可向具体 GitHub 远程 `ma-jiale/Pillxai` 上传分支源码；已向用户请求这项明确授权。截止本记录，未推送、未触发学校部署、未修改 V1 或系统代理。

后续以实际 Actions、主机健康与公开入口结果更新本记录，不将配置存在或本地单元测试通过写成上线完成。
