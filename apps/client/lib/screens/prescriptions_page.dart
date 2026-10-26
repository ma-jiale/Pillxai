import 'package:flutter/material.dart';

import '../widgets/app_menu.dart';
import 'history_page.dart';

import '../models/demo_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_page.dart';
import '../widgets/prescription_forms.dart';
import '../widgets/profile_avatar.dart';

/// 当前资料的浏览与编辑入口。搜索/滚动属于页面，长者与处方属于共享模型。
class PrescriptionsPage extends StatefulWidget {
  const PrescriptionsPage({super.key, required this.model});
  final DemoModel model;

  @override
  State<PrescriptionsPage> createState() => _PrescriptionsPageState();
}

class _PrescriptionsPageState extends State<PrescriptionsPage> {
  static const _searchBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(999)),
    borderSide: BorderSide.none,
  );
  final _search = TextEditingController();
  final _residentScroll = ScrollController();
  final _detailsScroll = ScrollController();
  final _pageScroll = ScrollController();
  final _detailsKey = GlobalKey();
  bool _narrow = false;

  /// 纯查询：先规范化搜索文本，再筛姓名或床位，不改写原始资料。
  List<Resident> get _visibleResidents {
    final query = _search.text.trim().toLowerCase().replaceAll(' ', '');
    return widget.model.residents
        .where(
          (resident) =>
              (resident.name.toLowerCase().contains(query) ||
              resident.bed.toLowerCase().replaceAll(' ', '').contains(query)),
        )
        .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    _residentScroll.dispose();
    _detailsScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  /// 选择只改变浏览对象。平板详情独立回到顶部；窄屏滚动到详情区域。
  /// 布局坐标必须等这一帧重建后再读取，因此使用帧结束回调。
  void _showDetails() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_narrow && _detailsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _detailsKey.currentContext!,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
        );
      } else if (_detailsScroll.hasClients) {
        _detailsScroll.jumpTo(0);
      }
    });
  }

  void _updateSelection() {
    final residents = _visibleResidents;
    if (residents.isNotEmpty &&
        !residents.any(
          (resident) => resident.id == widget.model.selectedResidentId,
        )) {
      widget.model.selectResident(residents.first.id);
    }
    setState(() {});
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 等待表单返回新资料；取消返回 null。await 期间页面可能销毁，先检查 mounted。
  /// 只有这里把成功结果交给模型；表单内部的输入不会提前污染列表。
  Future<void> _editResident([Resident? resident]) async {
    final updated = await showDialog<Resident>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ResidentForm(model: widget.model, resident: resident),
    );
    if (!mounted || updated == null) return;
    _search.clear();
    widget.model.saveResident(updated);
    _showDetails();
    _notify('已保存${updated.name}的资料');
  }

  /// 编辑得到一个新 Medicine，再替换当前处方；执行中的快照不受影响。
  Future<void> _editMedicine(Resident resident, [Medicine? medicine]) async {
    final updated = await showDialog<Medicine>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicineForm(
        resident: resident,
        medicine: medicine,
        bedtimeEnabled: widget.model.bedtime,
      ),
    );
    if (!mounted || updated == null) return;
    widget.model.saveMedicine(resident.id, updated);
    _notify('已保存${updated.name}');
  }

  Future<void> _toggleMedicine(Resident resident, Medicine medicine) async {
    final action = medicine.stopped ? '恢复' : '停用';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action${medicine.name}？'),
        content: Text(
          medicine.stopped
              ? '恢复后沿用原用药条目及日期，请核对剂量和疗程。'
              : '条目会保留在已停用用药中。正在进行的任务仍使用原来的用药安排。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认$action'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.model.saveMedicine(
      resident.id,
      medicine.copyWith(stopped: !medicine.stopped),
    );
    _notify('已$action${medicine.name}');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final residents = _visibleResidents;
      final selected = residents
          .where((resident) => resident.id == widget.model.selectedResidentId)
          .firstOrNull;
      return Padding(
        padding: AppPage.insets(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _narrow = constraints.maxWidth < 740 || constraints.maxHeight < 300;
            final list = _residentList(residents);
            final details = KeyedSubtree(
              key: _detailsKey,
              child: selected == null
                  ? const Surface(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 76),
                        child: Center(child: Text('未找到长者，请调整搜索内容。')),
                      ),
                    )
                  : _residentDetails(selected),
            );
            if (_narrow) {
              return SingleChildScrollView(
                controller: _pageScroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    SizedBox(height: 360, child: list),
                    const SizedBox(height: 20),
                    details,
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 1000 ? 232 : 260,
                  child: list,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('resident-details-scroll'),
                    controller: _detailsScroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: details,
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  /// 搜索和添加固定在名单上下方，中间按需构建条目，避免200人名单推走操作。
  Widget _residentList(List<Resident> residents) => Surface(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => _updateSelection(),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '搜索姓名、床位',
            border: _searchBorder,
            enabledBorder: _searchBorder,
            focusedBorder: _searchBorder.copyWith(
              borderSide: const BorderSide(color: Color(0xffd5d5d5)),
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _search.clear();
                      _updateSelection();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
          child: Text(
            '${residents.length} 位长者',
            style: const TextStyle(fontSize: 12, color: Color(0xff858585)),
          ),
        ),
        if (residents.isNotEmpty)
          Flexible(
            child: Scrollbar(
              controller: _residentScroll,
              thumbVisibility: true,
              child: ListView.builder(
                key: const ValueKey('resident-list-scroll'),
                controller: _residentScroll,
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: residents.length,
                itemBuilder: (_, index) => _residentTile(residents[index]),
              ),
            ),
          ),
        if (residents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              '没有匹配的长者',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff737373)),
            ),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _editResident(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('添加长者'),
        ),
      ],
    ),
  );

  Widget _residentTile(Resident resident) {
    final selected = resident.id == widget.model.selectedResidentId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? const Color(0xffefeff1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          key: ValueKey('resident-${resident.id}'),
          onTap: () {
            widget.model.selectResident(resident.id);
            _showDetails();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: ResidentIdentity(
                    name: resident.name,
                    bed: resident.bed,
                    asset: resident.avatarAsset,
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xff777777),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _residentDetails(Resident resident) {
    final medicines = resident.medicines
        .where((medicine) => !medicine.stopped)
        .toList();
    final stopped = resident.medicines
        .where((medicine) => medicine.stopped)
        .toList();
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final identity = ResidentIdentity(
                name: resident.name,
                bed: resident.bed,
                asset: resident.avatarAsset,
                size: 44,
                nameSize: 18,
              );
              final edit = Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('resident-history-${resident.id}'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: 1000,
                          child: HistoryPage(
                            model: widget.model,
                            residentId: resident.id,
                            onClose: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('摆药记录'),
                  ),
                  TextButton.icon(
                    onPressed: () => _editResident(resident),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('编辑资料'),
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: edit),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  edit,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '当前用药',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${medicines.length} 种',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff858585),
                    ),
                  ),
                ],
              ),

              TextButton.icon(
                onPressed: () => _editMedicine(resident),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加药物'),
              ),
            ],
          ),
          if (medicines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 46),
              child: Column(
                children: [
                  const Icon(
                    Icons.medication_outlined,
                    size: 30,
                    color: Color(0xffb4b4b4),
                  ),
                  const SizedBox(height: 14),
                  const Text('还没有用药条目'),
                  const SizedBox(height: 5),
                  Text(
                    '添加药物，开始维护这位长者的处方。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff858585),
                    ),
                  ),
                ],
              ),
            ),
          for (var index = 0; index < medicines.length; index++) ...[
            _medicineRow(resident, medicines[index]),
            if (index < medicines.length - 1) const Divider(height: 1),
          ],
          if (stopped.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              key: ValueKey('stopped-${resident.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                '已停用用药 · ${stopped.length}',
                style: const TextStyle(fontSize: 13, color: Color(0xff777777)),
              ),
              children: [
                for (final medicine in stopped)
                  _medicineRow(resident, medicine),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _medicineActions(
    Resident resident,
    Medicine medicine, {
    bool vertical = false,
  }) {
    final actions = <Widget>[
      IconButton(
        tooltip: '编辑${medicine.name}',
        onPressed: () => _editMedicine(resident, medicine),
        icon: const Icon(Icons.edit_outlined, size: 17),
      ),
      AppActionMenu(
        tooltip: '${medicine.name}更多操作',
        actions: [
          AppMenuAction(
            medicine.stopped ? '恢复用药' : '停用用药',
            () => _toggleMedicine(resident, medicine),
            icon: medicine.stopped
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
          ),
        ],
      ),
    ];
    return vertical
        ? Column(children: actions)
        : Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  Widget _medicineRow(Resident resident, Medicine medicine) {
    final now = DateTime.now();
    final status = medicine.stopped
        ? '已停用'
        : medicine.endDate != null &&
              DateTime(now.year, now.month, now.day).isAfter(medicine.endDate!)
        ? '疗程已结束'
        : medicine.startDate != null && now.isBefore(medicine.startDate!)
        ? '尚未开始'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 370;
          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicine.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${medicine.strength} · ${medicine.form}',
                style: const TextStyle(fontSize: 12, color: Color(0xff858585)),
              ),
              const SizedBox(height: 11),
              Text(medicine.schedule, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 5),
              Text(
                '${medicine.meal} · ${medicinePeriod(medicine)}',
                style: const TextStyle(fontSize: 12, color: Color(0xff858585)),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff777777),
                    ),
                  ),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _medicineThumbnail(medicine, 64),
                    _medicineActions(resident, medicine),
                  ],
                ),
                const SizedBox(height: 14),
                description,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _medicineThumbnail(medicine, 84),
              const SizedBox(width: 18),
              Expanded(child: description),
              const SizedBox(width: 8),
              _medicineActions(resident, medicine, vertical: true),
            ],
          );
        },
      ),
    );
  }

  Widget _medicineThumbnail(Medicine medicine, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: size,
      height: size,
      color: const Color(0xfff5f5f5),
      child: medicine.imageAsset == null
          ? const Icon(
              Icons.medication_outlined,
              size: 26,
              color: Color(0xffa5a5a5),
            )
          : Image.asset(
              medicine.imageAsset!,
              fit: BoxFit.cover,
              semanticLabel: '${medicine.name} 药品图片',
            ),
    ),
  );
}
