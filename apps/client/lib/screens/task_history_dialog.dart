import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../theme/app_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/result_details.dart';
import '../widgets/server_plan_pattern.dart';

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
String _time(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _state(api.TaskView task) =>
    const {
      'claimed': '已领取',
      'started': '执行中',
      'awaiting_collection': '摆药完成，待取盒',
      'completed': '已完成',
      'cancelled': '已取消',
    }[task.state.toJson()] ??
    '待核实';

/// The existing API returns at most 200 recent records. Filters explicitly apply
/// to that loaded set, rather than claiming to search the complete archive.
class TaskHistoryDialog extends StatefulWidget {
  const TaskHistoryDialog({
    super.key,
    required this.terminal,
    this.residentId,
    this.onClose,
  });
  final TerminalController terminal;
  final String? residentId;
  final VoidCallback? onClose;
  @override
  State<TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<TaskHistoryDialog> {
  final search = TextEditingController();
  List<api.TaskView> tasks = [];
  String? error;
  bool loading = true;
  String query = '', result = 'all', device = 'all';
  DateTimeRange? dates;
  bool newest = true, more = false;
  int page = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows =
          await widget.terminal.backend.request(
            widget.terminal.execution.listTasks(active: false),
          ) ??
          [];
      if (mounted) setState(() => tasks = rows);
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void clear() => setState(() {
    search.clear();
    query = '';
    result = device = 'all';
    dates = null;
    page = 0;
  });
  List<api.TaskView> get filtered {
    final needle = query.trim().toLowerCase();
    final rows = tasks.where((task) {
      if (widget.residentId != null &&
          task.plan.residentId != widget.residentId) {
        return false;
      }
      if (result != 'all' && task.state.toJson() != result) return false;
      if (device != 'all' && task.deviceId != device) return false;
      final at = (task.startedAt ?? task.updatedAt).toLocal();
      final day = DateTime(at.year, at.month, at.day);
      if (dates != null &&
          (day.isBefore(dates!.start) || day.isAfter(dates!.end))) {
        return false;
      }
      return '${task.plan.residentName} ${task.plan.bed} ${task.batches.map((b) => b.name).join(' ')}'
          .toLowerCase()
          .contains(needle);
    }).toList();
    rows.sort(
      (a, b) => newest
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = filtered;
    final pages = (rows.length / 10).ceil().clamp(1, 100000);
    final current = page.clamp(0, pages - 1);
    final devices = {
      for (final task in tasks) task.deviceId: task.device.configuration.name,
    };
    final content = SingleChildScrollView(
      padding: AppPage.insets(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.residentId == null ? '历史记录' : '长者摆药记录',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '最近 200 条已结束记录 · 筛选当前已加载范围',
                    style: TextStyle(fontSize: 12, color: Color(0xff777777)),
                  ),
                ],
              ),
              TextButton.icon(
                key: const ValueKey('close-history'),
                onPressed: widget.onClose ?? () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('关闭记录'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, bounds) {
                    final field = TextField(
                      key: const ValueKey('history-search'),
                      controller: search,
                      onSubmitted: (_) => setState(() {
                        query = search.text;
                        page = 0;
                      }),
                      decoration: const InputDecoration(
                        hintText: '搜索姓名、床位或药物',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    );
                    final button = FilledButton(
                      onPressed: () => setState(() {
                        query = search.text;
                        page = 0;
                      }),
                      child: const Text('查询'),
                    );
                    return bounds.maxWidth < 420
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              field,
                              const SizedBox(height: 10),
                              button,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: field),
                              const SizedBox(width: 12),
                              button,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      child: AppSelect<String>(
                        value: result,
                        label: '结果',
                        options: const [
                          AppSelectOption('all', '全部结果'),
                          AppSelectOption('completed', '已完成'),
                          AppSelectOption('cancelled', '已取消'),
                        ],
                        onChanged: (value) => setState(() {
                          result = value;
                          page = 0;
                        }),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDateRange: dates,
                          helpText: '选择摆药日期',
                          saveText: '确定',
                        );
                        if (value != null && mounted) {
                          setState(() {
                            dates = value;
                            page = 0;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        dates == null
                            ? '摆药日期'
                            : '${_date(dates!.start)} — ${_date(dates!.end)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => more = !more),
                      child: Text(more ? '收起筛选' : '更多筛选'),
                    ),
                    TextButton(onPressed: clear, child: const Text('清除')),
                  ],
                ),
                if (more)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: 190,
                      child: AppSelect<String>(
                        value: device,
                        label: '设备',
                        options: [
                          const AppSelectOption('all', '全部设备'),
                          for (final d in devices.entries)
                            AppSelectOption(d.key, d.value),
                        ],
                        onChanged: (value) => setState(() {
                          device = value;
                          page = 0;
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${rows.length} 条',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff777777),
                  ),
                ),
              ),
              IconButton(
                tooltip: '刷新记录',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  newest = !newest;
                  page = 0;
                }),
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(newest ? '最新在前' : '最早在前'),
              ),
            ],
          ),
          if (loading)
            const LinearProgressIndicator()
          else if (error != null)
            Surface(
              child: Column(
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('重新加载')),
                ],
              ),
            )
          else if (rows.isEmpty)
            Surface(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 40,
                      color: Color(0xffaaaaaa),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tasks.isEmpty ? '暂无摆药记录' : '没有符合条件的记录',
                      style: const TextStyle(fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '结束并同步的任务会显示在这里。',
                      style: TextStyle(color: Color(0xff777777)),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final task in rows.skip(current * 10).take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HistoryRecordCard(
                  key: ValueKey('history-${task.id}'),
                  name: task.plan.residentName,
                  bed: task.plan.bed,
                  badges: [
                    ResultBadge(
                      _state(task),
                      attention: task.state != api.TaskState.completed,
                    ),
                    if (task.device.configuration.mode ==
                        api.DeviceMode.simulator)
                      const ResultBadge('演练'),
                  ],
                  facts: [
                    _time(task.startedAt ?? task.updatedAt),
                    '${task.completedBatches.length} / ${task.batches.length} 批次收到完成反馈',
                    '${_date(task.plan.dates.first)} — ${_date(task.plan.dates.last)}',
                  ],
                  caption: task.device.configuration.name,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => TaskResultDetails(
                      terminal: widget.terminal,
                      task: task,
                    ),
                  ),
                ),
              ),
          if (rows.isNotEmpty && !loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一页',
                  onPressed: current == 0
                      ? null
                      : () => setState(() => page = current - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${current + 1} / $pages'),
                IconButton(
                  tooltip: '下一页',
                  onPressed: current + 1 >= pages
                      ? null
                      : () => setState(() => page = current + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
    return widget.onClose != null
        ? content
        : Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(width: 1000, child: content),
          );
  }
}

class TaskResultDetails extends StatefulWidget {
  const TaskResultDetails({
    super.key,
    required this.terminal,
    required this.task,
  });
  final TerminalController terminal;
  final api.TaskView task;
  @override
  State<TaskResultDetails> createState() => _TaskResultDetailsState();
}

class _TaskResultDetailsState extends State<TaskResultDetails> {
  List<api.StoredEvent> events = [];
  bool loading = false, loaded = false, hasMore = true;
  String? error;
  Future<void> loadEvents() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows =
          await widget.terminal.backend.request(
            widget.terminal.execution.listTaskEvents(
              widget.task.id,
              after: events.isEmpty ? 0 : events.last.sequence,
            ),
          ) ??
          [];
      if (mounted) {
        setState(() {
          events.addAll(rows);
          hasMore = rows.length == 200;
          loaded = true;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return ResultDetailsSheet(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResidentIdentity(name: task.plan.residentName, bed: task.plan.bed),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResultBadge(
                _state(task),
                attention: task.state != api.TaskState.completed,
              ),
              if (task.device.configuration.mode == api.DeviceMode.simulator)
                const ResultBadge('演练'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${task.completedBatches.length} / ${task.batches.length} 批次收到完成反馈',
          ),
          const SizedBox(height: 8),
          Text(
            '摆药时间  ${_time(task.startedAt ?? task.updatedAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
          ),
          const SizedBox(height: 6),
          Text(
            '计划日期  ${_date(task.plan.dates.first)} — ${_date(task.plan.dates.last)}',
            style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
          ),
          const SizedBox(height: 6),
          Text(
            task.device.configuration.name,
            style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
          ),
          const SizedBox(height: 28),
          const Text(
            '逐药结果',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '以下是机器累计计数；不代表逐格实测数量。',
            style: TextStyle(fontSize: 12, color: Color(0xff777777)),
          ),
          const SizedBox(height: 12),
          for (final batch in task.batches)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          batch.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        ResultBadge(
                          task.completedBatches.contains(batch.index)
                              ? '收到完成反馈'
                              : '未确认完成',
                          attention: !task.completedBatches.contains(
                            batch.index,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${batch.strength} · ${batch.feedForm} · ${batch.purpose}',
                      style: const TextStyle(color: Color(0xff777777)),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Text('计划 ${batch.total} 颗'),
                        Text(
                          batch.index < task.counts.length
                              ? '反馈 ${task.counts[batch.index]} 颗'
                              : '尚无计数反馈',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('原计划', style: TextStyle(fontSize: 14)),
            children: [
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ServerPlanPattern(snapshot: task.plan),
                ),
                child: const Text('查看原计划图案'),
              ),
              for (final batch in task.batches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(batch.name),
                  subtitle: Text('${batch.purpose} · ${batch.total} 颗'),
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('处理经过', style: TextStyle(fontSize: 14)),
            onExpansionChanged: (open) {
              if (open && !loaded) loadEvents();
            },
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (loaded && events.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('尚无已同步处理事件'),
                ),
              for (final event in events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    event.detail['message']?.toString() ??
                        const {
                          'count': '收到累计计数',
                          'finish': '收到完成反馈',
                          'paused': '已暂停',
                          'resumed': '已继续',
                          'cancelled': '本次已取消',
                          'completed': '任务已完成',
                        }[event.kind] ??
                        '收到设备处理反馈',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${_time(event.at)} · 第 ${event.batch + 1} 批次',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (error != null || loaded && hasMore)
                TextButton(
                  onPressed: loading ? null : loadEvents,
                  child: Text(error != null ? '重试' : '加载更多'),
                ),
            ],
          ),
          if (task.learningResults.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('参数学习', style: TextStyle(fontSize: 14)),
              children: [
                for (final result in task.learningResults)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      result.batch < task.batches.length
                          ? task.batches[result.batch].name
                          : '第 ${result.batch + 1} 批次',
                    ),
                    subtitle: Text(
                      '${result.message}${result.gate != null && result.turntable != null ? "\n初速度 ${result.turntable!.toStringAsFixed(3)} · 舵机 ${result.gate!.toStringAsFixed(4)}" : ""}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
