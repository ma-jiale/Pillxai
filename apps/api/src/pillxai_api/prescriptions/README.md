# prescriptions

拥有药品身份、稳定处方药物条目、当前版本及不可覆盖的历史。models.py 为公开契约；routes.py 接收当前账号，通过 residents 的公开入口确认长者身份。精确剂量为字符串，日期与时间分开，不包含计划计算或设备命令。

新增同名条目仍建立独立身份；修改/停止/恢复沿用条目身份并创建新版本。药品名称、规格或单位改变时建立新的药品身份，旧版本不变。当前不合并药品目录，也未实现出药参数学习。

原子版本条件拒绝并发旧写入；当前行、药品身份与版本同事务保存，失败不会遗留孤立药品。实际 PostgreSQL 并发、半片、日期、停用/恢复与历史测试见 tests/test_business.py；Windows SDK 验证见 apps/client/tool/check_business.dart。
