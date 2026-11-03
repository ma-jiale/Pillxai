import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/resident_labels.dart';
import '../data/save_label_pdf.dart';
import '../models/prescription_store.dart';

class ResidentLabelDialog extends StatefulWidget {
  const ResidentLabelDialog({super.key, required this.residents});
  final List<Resident> residents;
  @override
  State<ResidentLabelDialog> createState() => _ResidentLabelDialogState();
}

class _ResidentLabelDialogState extends State<ResidentLabelDialog> {
  final copies = <String, String>{};
  String query = '';
  bool busy = false;
  String? notice;
  ResidentLabelDocument? document;
  int page = 0;

  int count(String value) => int.tryParse(value) ?? 0;
  int get total => copies.values.fold(0, (n, value) => n + count(value));
  bool get valid =>
      copies.isNotEmpty &&
      copies.values.every((v) => count(v) > 0 && count(v) <= 999);

  Future<void> generate() async {
    if (busy || !valid) return;
    FocusScope.of(context).unfocus();
    final order = <LabelOrder>[
      for (final r in widget.residents)
        if (copies.containsKey(r.id))
          (
            name: r.name,
            bed: r.bed,
            barcode: r.barcode,
            copies: count(copies[r.id]!),
          ),
    ];
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final result = await ResidentLabelDocument.generate(order);
      if (mounted) {
        setState(() {
          document = result;
          page = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = e is FormatException ? e.message : '标签生成失败，请重试。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || document == null) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final saved = await saveLabelPdf(document!.pdf, '长者标签-$date.pdf');
      if (mounted && saved) {
        setState(() => notice = kIsWeb ? '已开始下载 PDF。' : 'PDF 已导出。');
      }
    } catch (_) {
      if (mounted) setState(() => notice = 'PDF 保存失败，请重新选择保存位置。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = document;
    return PopScope(
      canPop: !busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview == null ? '导出长者标签' : '标签预览',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  '已选 ${copies.length} 位长者 · $total 张 · ${LabelLayout.pages(total)} 页 A4',
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: preview == null
                      ? AbsorbPointer(absorbing: busy, child: _selection())
                      : _preview(preview),
                ),
                if (notice != null)
                  Text(notice!, style: Theme.of(context).textTheme.bodySmall),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (preview != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                document = null;
                                notice = null;
                              }),
                        child: const Text('修改选择'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: busy || !valid
                          ? null
                          : preview == null
                          ? generate
                          : save,
                      child: Text(preview == null ? '生成预览' : '导出 PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selection() {
    final rows = widget.residents
        .where(
          (r) => '${r.name} ${r.bed}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    final available = rows.where((r) => r.barcode.isNotEmpty);
    final all =
        available.isNotEmpty &&
        available.every((r) => copies.containsKey(r.id));
    return Column(
      children: [
        TextFormField(
          initialValue: query,
          decoration: const InputDecoration(
            hintText: '搜索姓名或床位',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: available.isEmpty
                ? null
                : () => setState(() {
                    for (final r in available) {
                      if (all) {
                        copies.remove(r.id);
                      } else {
                        copies.putIfAbsent(r.id, () => '1');
                      }
                    }
                    notice = null;
                  }),
            child: Text(all ? '取消选中当前结果' : '全选当前结果'),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('没有匹配的长者'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final selected = copies.containsKey(r.id);
                    void toggle() => setState(() {
                      if (selected) {
                        copies.remove(r.id);
                      } else {
                        copies[r.id] = '1';
                      }
                      notice = null;
                    });
                    return Row(
                      key: ValueKey(r.id),
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(r.name),
                            subtitle: Text(
                              r.barcode.isEmpty ? '缺少身份条码' : r.bed,
                            ),
                            value: selected,
                            onChanged: r.barcode.isEmpty
                                ? null
                                : (_) => toggle(),
                          ),
                        ),
                        if (selected)
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              key: ValueKey('copies-${r.id}'),
                              initialValue: copies[r.id],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: InputDecoration(
                                labelText: '份数',
                                isDense: true,
                                errorText: count(copies[r.id]!) == 0
                                    ? '至少 1 份'
                                    : null,
                              ),
                              onChanged: (v) => setState(() {
                                copies[r.id] = v;
                                notice = null;
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _preview(ResidentLabelDocument preview) {
    final pages = LabelLayout.pages(preview.labels.length);
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: const Color(0xffefeff1),
            child: SizedBox.expand(
              child: InteractiveViewer(
                key: ValueKey(page),
                maxScale: 8,
                child: FittedBox(
                  child: SizedBox(
                    width: LabelLayout.width,
                    height: LabelLayout.height,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Stack(
                        children: [
                          for (
                            var i = page * LabelLayout.perPage;
                            i <
                                math.min(
                                  (page + 1) * LabelLayout.perPage,
                                  preview.labels.length,
                                );
                            i++
                          )
                            Positioned(
                              left: LabelLayout.origin(i).dx,
                              top: LabelLayout.origin(i).dy,
                              width: LabelLayout.cell,
                              height: LabelLayout.cell,
                              child: CustomPaint(
                                foregroundPainter: _Bars(preview.labels[i]),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Image.memory(
                                    preview.labels[i].header,
                                    fit: BoxFit.fill,
                                    width: LabelLayout.cell,
                                    height: LabelLayout.headerHeight,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: page == 0 ? null : () => setState(() => page--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('第 ${page + 1} / $pages 页'),
            IconButton(
              tooltip: '下一页',
              onPressed: page + 1 == pages
                  ? null
                  : () => setState(() => page++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bars extends CustomPainter {
  const _Bars(this.face);
  final LabelArtwork face;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = Colors.black;
    for (final bar in face.bars) {
      canvas.drawRect(
        Rect.fromLTWH(
          LabelLayout.barLeft + bar.left,
          LabelLayout.barTop + bar.top,
          bar.width,
          bar.height,
        ),
        ink,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xffcccccc)
        ..strokeWidth = LabelLayout.rule
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => face != oldDelegate.face;
}
