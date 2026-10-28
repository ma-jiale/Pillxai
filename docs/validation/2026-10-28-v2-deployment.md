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
| V2 部署工具单元测试 | 初版 10 项通过；main CD 调整后 12 项通过，新增拒绝开发分支及过期 main 制品检查；Docker 命令模拟，覆盖 V1 路径/端口隔离、制品篡改、活动任务、迁移失败、首次失败、数据库版本变更与回退条件 |
| Ruff | 新后端与部署代码通过 |
| OpenAPI/Dart SDK | `scripts/contracts.ps1 -Check` 重新生成检查通过，无契约漂移 |
| GitHub 工作流 | main CD 触发条件通过本机 actionlint；学校 Runner 自定义标签按已知配置忽略未知标签提示 |
| Compose | 本机官方 Compose `config --quiet` 通过 |
| 学校 Runner | GitHub 页面观察 `user-Super-Server`，标签 `self-hosted Linux X64 pillxa-server`，状态 Idle |
| 本机 Docker 镜像/容器 | 本机无 Docker Engine，未运行；必须由 GitHub 构建实际证明 |
| GitHub V2 CI / 镜像制品 | [Actions #5](https://github.com/ma-jiale/Pillxai/actions/runs/40679227511) 成功，代码提交 `668c37b31ef647e91f6b588a29a369071c5ace07`；test 1m26s，package 2m53s，deploy skipped |
| GitHub 实际 Docker / Compose | 镜像 HTTP、认证、重启后会话、隔离备份恢复通过；正式 Compose 首次初始化、非超级用户数据库账号、二次更新、数据库容器 ID 与管理员凭据保留、发布前备份及临时库恢复通过；仅在 GitHub 临时主机执行 |
| 学校 V2 内部服务 | 尚未部署 |
| HTTPS、新旧共存、恢复演练 | 尚未实测 |

## 发布状态

首次推送被自动审批拦截后，用户先选择仅保留本地。随后用户明确授权推送到 `ma-jiale/Pillxai`，运行 CI 与镜像验证，暂不开启服务器部署。该阶段已推送 `codex/v2-server-deployment` 并将 `deploy` job 显式设为 false，Actions #5 确认 deploy skipped（0s）。

同日用户进一步要求主分支更新触发 CD：配置已改为 main 每次 push → test → package → deploy，deploy 要求仓库变量 `V2_CD_ENABLED=true`；开发分支、PR、手动运行均不部署，宿主工具仅接受远程 main 当前提交。已补充首次启用与合并步骤，见 [部署说明](../../deploy/v2-server/README.md)。当前修改在开发分支；尚未合入 main，未设置 GitHub 部署环境或变量，未修改学校服务、V1 和系统代理。先前镜像成功记录不等同于这次触发规则已在生产执行。

镜像制品 [v2-server-668c37b31ef647e91f6b588a29a369071c5ace07](https://github.com/ma-jiale/Pillxai/actions/runs/40679227511/artifacts/12811643957) 已上传，252 MB，保留 14 天；GitHub 制品摘要 `sha256:cd99835b889e0c844103e5bb00f67e07d65530deae95f59fc41e9c4836439629`。这表示 CI 制品可下载，不表示学校服务器已经上线。后续本记录的文档提交不改变该已验证代码提交。

实际 CI 暴露并修复了三个本地模拟无法验证的问题：API 需要额外 ingress 网络才能发布宿主端口，数据库继续留在内部网络；使用 Docker 临时端口的测试须在重启后重新读取映射；PostgreSQL 18 的挂载父目录须允许 postgres 用户穿过（0755），其实际 `18/docker` 数据目录仍为 PostgreSQL 所有、0700，宿主 shared 仍为 0700。失败日志现在先脱敏再输出。前四轮失败保留在 Actions 中，最终结论以第五轮完整成功为准。

后续以实际 Actions、主机健康与公开入口结果更新本记录，不将配置存在或本地单元测试通过写成上线完成。
