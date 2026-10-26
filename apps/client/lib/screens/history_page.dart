import 'package:flutter/material.dart';

import '../models/demo_model.dart';
import '../theme/app_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import '../widgets/profile_avatar.dart';
import 'results_page.dart';

/// 会话历史查询。筛选条件和页码归本页面；记录快照归共享模型。
class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.model,
    required this.onClose,
    this.residentId,
  });
  final DemoModel model;
  final VoidCallback onClose;
  final String? residentId;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();
  String _query = '';
  String _result = 'all';
  String _device = 'all';
  String _operator = 'all';
  DateTimeRange? _dates;
  bool _newest = true;
  bool _moreFilters = false;
  int _page = 0;
  static const _pageSize = 10;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 筛选后创建新列表再排序，不改变模型中记录顺序。日期按日比较并包含两端。
  List<DispenseRecord> get _filtered {
    final query = _query.trim().toLowerCase().replaceAll(' ', '');
    final records = widget.model.records.where((r) {
      if (widget.residentId != null && r.residentId != widget.residentId) {
        return false;
      }
      if (_result == 'review'
          ? !r.needsReview
          : _result != 'all' && r.outcome.name != _result) {
        return false;
      }
      if (_device != 'all' && r.device != _device) return false;
      if (_operator != 'all' && r.operatorName != _operator) return false;
      if (_dates != null) {
        final day = DateTime(
          r.finishedAt.year,
          r.finishedAt.month,
          r.finishedAt.day,
        );
        if (day.isBefore(_dates!.start) || day.isAfter(_dates!.end)) {
          return false;
        }
      }
      return '${r.name} ${r.bed} ${r.medicines.map((m) => m.name).join(' ')}'
          .toLowerCase()
          .replaceAll(' ', '')
          .contains(query);
    }).toList();
    records.sort(
      (a, b) => _newest
          ? b.finishedAt.compareTo(a.finishedAt)
          : a.finishedAt.compareTo(b.finishedAt),
    );
    return records;
  }

  void _clear() => setState(() {
    _search.clear();
    _query = '';
    _result = 'all';
    _device = 'all';
    _operator = 'all';
    _dates = null;
    _page = 0;
  });

  /// 日期选择是异步操作；返回后只有页面仍挂载时才更新筛选与页码。
  Future<void> _chooseDates() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dates,
      helpText: '选择摆药日期',
      saveText: '确定',
    );
    if (selected != null && mounted) {
      setState(() {
        _dates = selected;
        _page = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final records = _filtered;
      final pages = (records.length / _pageSize).ceil().clamp(1, 1000000);
      final currentPage = _page.clamp(0, pages - 1);
      final shown = records.skip(currentPage * _pageSize).take(_pageSize);
      final devices = widget.model.records.map((r) => r.device).toSet();
      final operators = widget.model.records.map((r) => r.operatorName).toSet();
      return SingleChildScrollView(
        key: const ValueKey('history-page'),
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
                      '演练记录 · 仅保留本次会话',
                      style: TextStyle(fontSize: 12, color: Color(0xff777777)),
                    ),
                  ],
                ),
                TextButton.icon(
                  key: const ValueKey('close-history'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(
                    widget.model.awaitingCollection ? '返回首页' : '关闭记录',
                  ),
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
                      final search = TextField(
                        key: const ValueKey('history-search'),
                        controller: _search,
                        onSubmitted: (_) => setState(() {
                          _query = _search.text;
                          _page = 0;
                        }),
                        decoration: const InputDecoration(
                          hintText: '搜索姓名、床位或药物',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      );
                      final queryButton = FilledButton(
                        onPressed: () => setState(() {
                          _query = _search.text;
                          _page = 0;
                        }),
                        child: const Text('查询'),
                      );
                      if (bounds.maxWidth < 420) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            search,
                            const SizedBox(height: 10),
                            queryButton,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 12),
                          queryButton,
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
                          value: _result,
                          label: '结果',
                          options: const [
                            AppSelectOption('all', '全部结果'),
                            AppSelectOption('completed', '全部完成'),
                            AppSelectOption('partial', '未全部完成'),
                            AppSelectOption('cancelled', '已取消'),
                            AppSelectOption('review', '待核实'),
                          ],
                          onChanged: (v) => setState(() {
                            _result = v;
                            _page = 0;
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _chooseDates,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _dates == null
                              ? '摆药日期'
                              : '${recordDate(_dates!.start)} — ${recordDate(_dates!.end)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _moreFilters = !_moreFilters),
                        child: Text(_moreFilters ? '收起筛选' : '更多筛选'),
                      ),
                      TextButton(onPressed: _clear, child: const Text('清除')),
                    ],
                  ),
                  if (_moreFilters)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 190,
                            child: AppSelect<String>(
                              value: _device,
                              label: '设备',
                              options: [
                                const AppSelectOption('all', '全部设备'),
                                for (final d in devices) AppSelectOption(d, d),
                              ],
                              onChanged: (v) => setState(() {
                                _device = v;
                                _page = 0;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: AppSelect<String>(
                              value: _operator,
                              label: '人员',
                              options: [
                                const AppSelectOption('all', '全部人员'),
                                for (final o in operators)
                                  AppSelectOption(o, o),
                              ],
                              onChanged: (v) => setState(() {
                                _operator = v;
                                _page = 0;
                              }),
                            ),
                          ),
                        ],
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
                    '共 ${records.length} 条',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff777777),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _newest = !_newest;
                    _page = 0;
                  }),
                  icon: const Icon(Icons.swap_vert, size: 18),
                  label: Text(_newest ? '最新在前' : '最早在前'),
                ),
              ],
            ),
            if (shown.isEmpty)
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
                        widget.model.records.isEmpty ? '暂无摆药记录' : '没有符合条件的记录',
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.model.records.isEmpty
                            ? '本次摆药结束后，结果会出现在这里。'
                            : '调整筛选条件后重新查询。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xff777777)),
                      ),
                      if (!widget.model.examplesLoaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: OutlinedButton(
                            key: const ValueKey('load-examples'),
                            onPressed: widget.model.loadExampleRecords,
                            child: const Text('载入演练示例'),
                          ),
                        ),
                      if (widget.model.records.isNotEmpty)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('清除筛选'),
                        ),
                    ],
                  ),
                ),
              ),
            for (final record in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: InkWell(
                    key: ValueKey('history-${record.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final previousRecordId = widget.model.currentRecord?.id;
                      await showResultDetails(context, widget.model, record.id);
                      if (mounted &&
                          previousRecordId != record.id &&
                          widget.model.currentRecord?.id == record.id) {
                        widget.onClose();
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final identity = ResidentIdentity(
                          name: record.name,
                          bed: record.bed,
                          asset: record.avatar,
                        );
                        final result = Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ResultBadge(
                              record.label,
                              attention:
                                  record.outcome != TaskOutcome.completed,
                            ),
                            if (record.needsReview)
                              const ResultBadge('待核实', attention: true),
                            const ResultBadge('演练'),
                          ],
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (bounds.maxWidth < 560) ...[
                              identity,
                              const SizedBox(height: 12),
                              result,
                            ] else
                              Row(
                                children: [
                                  Expanded(child: identity),
                                  const SizedBox(width: 16),
                                  result,
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xff999999),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 20,
                              runSpacing: 6,
                              children: [
                                Text(recordTime(record.finishedAt)),
                                Text(
                                  '${record.completedCount} / ${record.medicines.length} 种药完成',
                                ),
                                Text(record.collectionLabel),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${record.device} · ${record.operatorName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff777777),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (records.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一页',
                    onPressed: currentPage > 0
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${currentPage + 1} / $pages'),
                  IconButton(
                    tooltip: '下一页',
                    onPressed: currentPage + 1 < pages
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
