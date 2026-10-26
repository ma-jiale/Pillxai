# residents

拥有稳定长者 UUID、当前姓名/床位及不可覆盖的资料版本。公开入口为 routes.py；其他业务通过 service.resident_row 解析身份。非空床位在整个工作区按去首尾空格的完整文本唯一，不移除中间空格或转换大小写。

列表使用 UUID 游标分页，搜索与直接编号访问均要求有效会话。保存使用 expected_revision 并检查维护权限，当前行和历史行在同一事务内提交；不硬删除长者。照片/附件尚未接入。

验证：`scripts/backend.ps1 test` 的床位唯一、账号权限、历史与重建应用场景。迁移、服务启动及客户端入口见 API README。
