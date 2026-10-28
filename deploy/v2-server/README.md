# V2 服务器独立部署

V2 使用学校现有 `pillxa-server` Runner 接收 GitHub 构建的 Docker 制品，与 V1 同机运行。V1 的 `/dispenser/`、5068、`pillxa-v1` 和 SQLite 数据保持独立。V2 使用 `/dispenser-v2/`、8068、`pillxai-v2` 及专用 PostgreSQL 18 数据库；不导入 V1 或开发电脑上的业务资料。

## 发布与目录

工作流 `.github/workflows/v2-server.yml` 在 `main`、`NT` 或 `codex/v2-server-deployment` 更新后运行。按用户要求，`main` 的每次 push（含 PR 合并、文档或客户端更新）都执行测试和镜像验证；通过且仓库变量 `V2_CD_ENABLED=true` 时才自动部署。`NT`、开发分支及手动运行只验证，不部署；PR 只测试。V1 工作流保持独立。

测试连接真实 PostgreSQL，禁止跳过集成用例；检查 OpenAPI 与源码一致性。打包阶段固定解析出的基础镜像摘要，真实验证镜像登录、重启、备份恢复，再验证正式 Compose 的首次部署和第二次更新。镜像和部署文件一起打包，校验提交、文件 SHA-256、镜像 ID 和架构。学校服务器不需要访问 Docker Hub 或 PyPI。

当前仅验证目标架构 `linux/amd64`。宿主 Python 要求 3.12+；学校已有 `/home/deploy/miniforge3/bin/python3`。应用 Python 位于镜像，不向服务器 Conda 环境安装业务依赖。

```text
~/projects/pillxa-dispenser/v2/
  releases/                     每次已校验的发布配置与清单
  shared/
    server.env                  非密钥配置
    postgres/                   PostgreSQL 18 的整个持久目录
    postgres-password           数据库维护凭据
    app-password                非超级用户 pillxai_v2 的密码
    database-url                API 连接串
    initial-admin.json          首次管理员账号和随机密码，仅服务器账号可读
    DEPLOYMENT_READY
  backups/                      每日及发布前的数据库备份
  current.json                  最近成功版本
  previous.json                 上一成功版本
  pending.json                  更新未完成时保留，不代表成功
```

数据和密钥不进入镜像或 Git。shared 父目录权限 0700；供不同容器 UID 使用的三个只读凭据文件为 0444，仅以单文件挂载提供，其他文件 0600。PostgreSQL 拥有内部数据目录；不把它 chmod 成普通用户可读。

## 首次开启

2026-10-28 用户要求改为主分支更新触发 CD。工作流与宿主部署工具均只接受 `main`；宿主还会核对制品提交是否仍为远程 `main` 最新提交，拒绝排队期间过时的制品。当前分支尚未合入 `main`，本轮配置修改本身不会部署服务器。

首次启用顺序：

1. 确认学校 Runner 在线，标签包含 `self-hosted`、`linux`、`pillxa-server`，部署账号可用 Docker Compose 与 Python 3.12+，V1 健康且资源足够。
2. 在 GitHub Settings → Environments 建立 `v2-production`，Deployment branches and tags 选择仅允许分支 `main`。需要全自动 CD 时不设置每次人工审批。
3. 在 Settings → Secrets and variables → Actions → Variables 设置下表的**仓库变量**。`V2_CD_ENABLED` 不放在 Environment variables 中，因为 job 是否调度到该环境之前就要读取它。
4. 将包含完整 V2 代码的 `codex/v2-server-deployment` 分支通过 PR 合入 `main`。当前 main 和开发分支已有分叉，合并时保留 main 上现有 V1 变更，不强推覆盖 main。该次合并即触发首次 CD；以后合并到 main 自动重复测试、构建和部署。
5. 在 Actions 查看 `test → package → deploy` 全部成功，并确认本机 `http://127.0.0.1:8068/health/ready` 的版本对应该次 main 提交。首次 HTTPS 代理配置和公开入口验收按下一节执行。

| 变量 | 值 |
| --- | --- |
| `V2_CD_ENABLED` | `true` 允许 main push 通过验证后部署；缺省或 `false` 只验证 |
| `V2_SERVER_PYTHON` | `/home/deploy/miniforge3/bin/python3`，省略时使用此路径 |

若代码已经合入 main 才打开开关，设置变量本身不会触发工作流；可重跑该 main push 对应的工作流（必须仍是 main 最新提交），或提交新的 main 更新。手动 Run workflow 仅用于验证，不执行 CD。暂停后续 CD 时将 `V2_CD_ENABLED` 改为 `false`；已运行的部署需要单独观察处理。

首次部署先检查 V1 健康、容器身份、服务器资源。V2 根目录不存在时才初始化；已经存在但配置不全时停止，不覆盖重建。自动创建随机管理员密码，Actions 不输出密码。管理员在服务器上以部署账号安全查看 `shared/initial-admin.json`，首次登录后改密。重复初始化和升级不重置已有账号。

API 限制 1 CPU/1 GiB，数据库 1 CPU/2 GiB，备份容器 0.5 CPU/256 MiB；这是初始运行限制，不是容量验收结论。部署前至少要求 4 GiB 可用内存。数据库不映射宿主端口，API 仅绑定 127.0.0.1。应用不启用开发探针，单工作进程全局每分钟最多 60 次登录请求，不信任任意客户端转发头。代理来源需现场确认后填入 `V2_FORWARDED_ALLOW_IPS`。

## HTTPS 代理与客户端

`nginx-location.conf` 是待管理员应用到**现有 HTTPS server 块**的新增片段，不是完整站点配置。新增 `/dispenser-v2/` 后运行 `nginx -t`，通过才 reload；不能替换现有 `/dispenser/` location。代理配置属于系统变更，需用户明确同意具体范围后实施。

预期公开就绪地址为 `https://ixd.sjtu.edu.cn/dispenser-v2/health/ready`。API `/health/ready` 验证数据库修订，返回 `0.1.0+<完整提交号>`，同时检查本机和 HTTPS 入口；本机 ready 不代表代理已经上线。

平板构建 `PILLXAI_API_URL=https://ixd.sjtu.edu.cn/dispenser-v2`（末尾无斜线）。更换服务器前必须完成任务、取盒和全部补传；新库不认识开发库任务、账号及设备身份。重新建立新版服务器资料与设备配置，不能把旧队列上传到新库。

## 更新和失败处理

部署按 V2 环境串行排队，主机文件锁再次防止重复更新。先校验和加载镜像；活动任务存在时拒绝更新。暂停 API 后再次检查活动任务，消除检查与停止之间的领取竞态；备份成功后执行 Alembic，再启动 API 并检查准确版本。迁移与运行使用同一镜像，API 不自动建表。

PostgreSQL 镜像 ID 改变时拒绝自动更新，数据库升级单独安排。原数据目录丢失时拒绝重新初始化。程序失败时仅在数据库修订与上一镜像声明完全相同的情况下尝试恢复旧 API；不自动恢复数据库备份，也不假定任意旧应用兼容新结构。

失败保留 `pending.json`、发布清单和备份；下一次自动发布被拦截。`recover` 是人工明确执行的候选版本继续恢复，会再次检查空闲、执行迁移并要求精确修订匹配，保留所有业务数据。若迁移本身有误，先审查和修正；不要反复盲目 recover。数据库备份覆盖生产库不自动执行。

主机管理入口位于某一已验证发布目录中的 `manage.py`，用实际路径替换下例：

```bash
PY=/home/deploy/miniforge3/bin/python3
TOOL="$HOME/projects/pillxa-dispenser/v2/releases/<release>/manage.py"
"$PY" "$TOOL" status
"$PY" "$TOOL" backup
"$PY" "$TOOL" restore-check --backup "$HOME/projects/pillxa-dispenser/v2/backups/<backup>.dump"
"$PY" "$TOOL" recover
```

`restore-check` 校验备份摘要，恢复到随机命名的临时数据库，检查修订和账号表，再删除该临时库，不覆盖业务库。正式灾难恢复需先停止 V2 写入、保存现状并选定备份时间点；恢复后核对终端未上传事实及已取消任务，不能只恢复程序。

## 每日备份与观察

备份容器启动后立即备份，此后每 24 小时一次；失败每 5 分钟重试。使用非超级用户连接 V2 数据库、`pg_dump -Fc`、目录可读性检查及 SHA-256，成功后更新 `last-success`。超过 25 小时无成功备份显示 unhealthy。发布前备份额外生成 schema/提交清单。所有备份和业务历史不自动删除，观察磁盘容量；同磁盘备份不能覆盖主机损坏，独立副本位置及传输仍需运维落实。

```bash
docker ps --filter label=com.docker.compose.project=pillxai-v2
docker logs --tail 80 pillxai-v2-api-1
docker logs --tail 80 pillxai-v2-backup-1
curl --fail http://127.0.0.1:8068/health/ready
curl --fail https://ixd.sjtu.edu.cn/dispenser-v2/health/ready
curl --fail http://127.0.0.1:5068/__deployment_health
```

日志有大小轮转；应用访问日志默认关闭，避免记录业务 URL。日备份健康状态还需要接入外部告警，GitHub 日志和 Docker 状态不能替代通知系统。首次上线不等于已完成 200 人/6 设备、8 小时负载、独立备份副本、服务器重启和现场平板验收。

## 本地验证

```powershell
.\scripts\backend.ps1 test
.\scripts\backend.ps1 lint
.\scripts\contracts.ps1 -Check
```

另外用项目 Python 执行 `python -m unittest discover -s deploy/v2-server/tests -v`；actionlint 检查工作流，Compose `config --quiet` 检查配置。Docker/Compose 集成由 GitHub 的实际容器执行，不把模拟 Docker 命令测试当作镜像通过。
