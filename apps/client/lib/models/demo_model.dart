import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dispense_record.dart';
import 'prescription.dart';
import 'preparation_plan.dart';
export 'prescription.dart';
export 'dispense_record.dart';

/// 任务状态：idle → running ⇄ paused → completed / cancelled。
/// 识别和核对属于准备页；取盒占用单独由 currentRecord 表达。
enum DispenseStage { idle, running, paused, completed, cancelled }

/// 设备观察输入。目前由测试模拟，匹配反馈只提供启动条件，不自动启动。
enum BoxFeedback { disconnected, opening, waiting, match, other, failed }

/// In-memory preview data only. No network, hardware commands or actual records.
/// 共享会话模型（类似 GUI 中可观察的数据对象）。页面调用语义方法，
/// 方法完成状态变更后 notifyListeners，ListenableBuilder 据此重新 build。
/// 读取 getter 没有副作用；计时器仅模拟计数，不向机器发送命令。
class DemoModel extends ChangeNotifier {
  /// 创建样例资料和可选计时器。autoTick:false 让测试自行 advance，结果可重复。
  /// 初始化时没有任务；只有用户确认有效计划后才建立任务快照。
  DemoModel({bool autoTick = true}) {
    final today = DateTime.now();
    demoCoverage['r3'] = DateTime(today.year, today.month, today.day + 4);
    residents.first.medicines.addAll(
      List.generate(
        5,
        (index) => Medicine(
          id: 'sample-${index + 5}',
          name: index < 3 ? '示例药${index + 3}' : '示例长名称药物${index + 3}（普通片）',
          strength: '${(index + 1) * 10} mg / 片',
          doses: DoseSchedule(
            morning: 2,
            noon: index.isEven ? 1 : 0,
            evening: 1,
          ),
        ),
      ),
    );
    if (autoTick) {
      _ticker = Timer.periodic(const Duration(seconds: 2), (_) => advance());
    }
  }

  final List<Resident> residents = [
    Resident(
      id: 'r1',
      avatarAsset: 'assets/images/avatars/wang.png',
      name: '王奶奶',
      bed: '208 床',
      medicines: [
        Medicine(
          id: 'm1',
          name: '示例药 A',
          strength: '10 mg / 片',
          startDate: DateTime(2026, 10, 1),
          imageAsset: 'assets/images/medicine-a.png',
        ),
        Medicine(
          id: 'm2',
          name: '示例药 B',
          strength: '5 mg / 片',
          doses: const DoseSchedule(noon: 0, evening: 0),
          startDate: DateTime(2026, 10, 1),
          imageAsset: 'assets/images/medicine-b.png',
        ),
      ],
    ),
    Resident(
      id: 'r2',
      avatarAsset: 'assets/images/avatars/zhang.png',
      name: '张爷爷',
      bed: '206 床',
      medicines: [
        Medicine(
          id: 'm3',
          name: '示例药 C',
          strength: '20 mg',
          doses: const DoseSchedule(noon: 0),
          startDate: DateTime(2026, 10, 1),
        ),
      ],
    ),
    Resident(
      id: 'r3',
      avatarAsset: 'assets/images/avatars/li.png',
      name: '李奶奶',
      bed: '203 床',
      medicines: [
        Medicine(
          id: 'm4',
          name: '示例药 D',
          strength: '5 mg',
          doses: const DoseSchedule(morning: 0, noon: 0),
          startDate: DateTime(2026, 10, 1),
        ),
      ],
    ),
    Resident(
      id: 'r4',
      name: '陈爷爷',
      bed: '201 床',
      medicines: [],
      avatarAsset: 'assets/images/avatars/chen.png',
    ),
  ];
  String selectedResidentId = 'r1';
  Resident get selectedResident =>
      residents.firstWhere((r) => r.id == selectedResidentId);
  String _taskResidentName = '';
  String _taskResidentBed = '';
  String? _taskResidentAvatar;
  List<Medicine> _taskMedicines = const [];
  int _medicineIndex = 0;
  int _count = 0;
  double _opening = .70;
  DispenseStage _stage = DispenseStage.idle;
  // 执行状态只允许通过下面的语义方法改变，页面只能读取。
  String get taskResidentName => _taskResidentName;
  String get taskResidentBed => _taskResidentBed;
  String? get taskResidentAvatar => _taskResidentAvatar;
  // 启动时已冻结列表；保持同一引用，让异步弹窗能确认任务没有被替换。
  List<Medicine> get taskMedicines => _taskMedicines;
  int get medicineIndex => _medicineIndex;
  int get count => _count;
  double get opening => _opening;
  DispenseStage get stage => _stage;

  int preparationDays = 7;
  bool splitMeals = true;
  bool bedtime = false;
  bool startTomorrow = false;
  Timer? _ticker;
  final Map<String, DateTime> demoCoverage = {};
  // 演练观察输入。新确认窗口清除上次反馈，测试从窗口外注入；尚未接真实适配器。
  final boxFeedback = ValueNotifier(BoxFeedback.disconnected);
  String? _preparedResidentId;
  DateTime? _preparedEnd;
  DateTime? _preparedStart;
  DateTime? _startedAt;
  String _taskDevice = '未连接设备';
  final List<DispenseRecord> _records = [];
  final List<RecordEvent> _taskEvents = [];
  List<DispenseRecord> get records => List.unmodifiable(_records);
  String? _currentRecordId;
  DispenseRecord? get currentRecord =>
      _records.where((r) => r.id == _currentRecordId).firstOrNull;
  bool get awaitingCollection => currentRecord != null;

  /// “执行已结束”不等于“可开下一任务”：药盒未确认离轨仍然占用。
  bool get busy => active || awaitingCollection;
  Timer? _collectionTimer;
  int _recordSequence = 0;
  bool examplesLoaded = false;
  final Map<String, MedicineResult> _medicineResults = {};
  Map<String, MedicineResult> get medicineResults =>
      Map.unmodifiable(_medicineResults);
  bool get hasSkippedMedicines => _medicineResults.values.any(
    (result) => result.outcome == MedicineOutcome.skipped,
  );

  /// 启动已核对的计划；返回 false 时不改变任何任务状态。
  ///
  /// 前置条件：没有执行/取盒占用，计划有效，最新药盒反馈为 match。
  /// 副作用：复制任务快照，清零进度，进入 running，通知监听界面。
  /// 页面和测试都通过这个入口启动；设备匹配不会自行启动任务。
  bool startPreparedTask(PreparationPlan plan, {String? device}) {
    if (busy || !plan.canStart || boxFeedback.value != BoxFeedback.match) {
      return false;
    }
    final resident = plan.resident;
    final medicines = plan.medicines;
    _taskResidentName = resident.name;
    _taskResidentBed = resident.bed;
    _taskResidentAvatar = resident.avatarAsset;
    _taskMedicines = List.unmodifiable(medicines);
    _medicineResults.clear();
    _preparedResidentId = resident.id;
    _preparedEnd = plan.end;
    _preparedStart = plan.start;
    _startedAt = DateTime.now();
    _taskDevice = device ?? '未连接设备';
    _taskEvents
      ..clear()
      ..add(RecordEvent(_startedAt!, '开始摆药（演练）'));
    _medicineIndex = 0;
    _count = 0;
    _opening = .70;
    _stage = DispenseStage.running;
    notifyListeners();
    return true;
  }

  /// 前置条件：已创建过任务。初始 idle 页面不读取这个 getter。
  Medicine get currentMedicine => _taskMedicines[_medicineIndex];
  Medicine? get nextMedicine => _medicineIndex + 1 < _taskMedicines.length
      ? _taskMedicines[_medicineIndex + 1]
      : null;
  bool get active =>
      _stage == DispenseStage.running || _stage == DispenseStage.paused;
  String get stageLabel => switch (_stage) {
    DispenseStage.idle => '等待准备',
    DispenseStage.running => '摆药进行中',
    DispenseStage.paused => '已暂停',
    DispenseStage.completed => hasSkippedMedicines ? '本次已结束 · 有跳过药物' : '本次已完成',
    DispenseStage.cancelled => '本次已取消',
  };

  void selectResident(String id) {
    selectedResidentId = id;
    notifyListeners();
  }

  /// 按稳定 id 新增或替换资料，选中保存对象，再一次性通知界面。
  void saveResident(Resident resident) {
    final index = residents.indexWhere((item) => item.id == resident.id);
    if (index < 0) {
      residents.add(resident);
    } else {
      residents[index] = resident;
    }
    selectedResidentId = resident.id;
    notifyListeners();
  }

  /// 返回占用该非空床位的另一位长者；忽略空白和大小写，编辑本人时排除本人。
  Resident? bedConflict(String bed, {String? excludingId}) {
    String normalize(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final normalized = normalize(bed);
    if (normalized.isEmpty) return null;
    return residents
        .where(
          (resident) =>
              resident.id != excludingId &&
              normalize(resident.bed) == normalized,
        )
        .firstOrNull;
  }

  /// 根据当前覆盖和机构偏好生成一个新计划，不启动任务、不修改模型。
  /// now 可注入固定日期，避免测试依赖运行当天；默认本次仍为七天。
  PreparationPlan planFor(Resident resident, {int days = 7, DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final coverage = demoCoverage[resident.id];
    final start = coverage != null && !coverage.isBefore(today)
        ? DateTime(coverage.year, coverage.month, coverage.day + 1)
        : DateTime(
            today.year,
            today.month,
            today.day + (startTomorrow ? 1 : 0),
          );
    return PreparationPlan(resident, start, days, bedtime: bedtime);
  }

  /// 用新药物对象替换处方条目，不修改已开始任务中的原对象。
  void saveMedicine(String residentId, Medicine medicine) {
    final list = residents.firstWhere((r) => r.id == residentId).medicines;
    final index = list.indexWhere((m) => m.id == medicine.id);
    if (index < 0) {
      list.add(medicine);
    } else {
      list[index] = medicine;
    }
    notifyListeners();
  }

  /// 只恢复暂停的同一任务。首次启动必须走 startPreparedTask。
  void resume() {
    if (_stage != DispenseStage.paused) return;
    _stage = DispenseStage.running;
    _taskEvents.add(RecordEvent(DateTime.now(), '继续摆药（演练）'));
    notifyListeners();
  }

  /// running → paused。重复调用无效果；计数和药物索引保持原值。
  void pause() {
    if (_stage != DispenseStage.running) return;
    _stage = DispenseStage.paused;
    notifyListeners();
  }

  /// 一次模拟反馈增加一颗。只有 running 接受计数；达到目标时记录结果并推进。
  /// 测试可反复调用它替代等待真实时间，不需要直接修改 _count。
  void advance() {
    if (_stage != DispenseStage.running) return;
    _count++;
    if (_count >= currentMedicine.target) {
      _count = currentMedicine.target;
      _medicineResults[currentMedicine.id] = MedicineResult(
        outcome: MedicineOutcome.completed,
        countedParticles: _count,
      );
      _moveToNext(startNext: true);
    }
    notifyListeners();
  }

  /// 内部转换，不自行通知监听者；外层操作完成全部修改后统一通知。
  /// 不变量：索引始终指向任务药物；只有全部完成才增加完整周期覆盖。
  void _moveToNext({required bool startNext}) {
    if (nextMedicine != null) {
      _medicineIndex++;
      _count = 0;
      _opening = .70;
      _stage = startNext ? DispenseStage.running : DispenseStage.paused;
    } else {
      _stage = DispenseStage.completed;
      // A resident-wide coverage date is only valid when every medicine is done.
      if (_medicineResults.length == _taskMedicines.length &&
          !hasSkippedMedicines &&
          _preparedResidentId != null &&
          _preparedEnd != null) {
        demoCoverage[_preparedResidentId!] = _preparedEnd!;
      }
      _finishRecord(
        hasSkippedMedicines ? TaskOutcome.partial : TaskOutcome.completed,
      );
    }
  }

  /// 跳过只改变当前药的结果。人工确认量与原始计数分开保存，不能伪造计数。
  /// startNext 决定下一药运行还是暂停，供取消/暂停场景保持用户意图。
  void skipCurrent({bool markPrepared = false, bool startNext = true}) {
    if (!active) return;
    _medicineResults[currentMedicine.id] = MedicineResult(
      outcome: markPrepared
          ? MedicineOutcome.confirmedPrepared
          : MedicineOutcome.skipped,
      countedParticles: _count,
      confirmedParticles: markPrepared ? currentMedicine.target : null,
    );
    _taskEvents.add(
      RecordEvent(
        DateTime.now(),
        '${currentMedicine.name}：${markPrepared ? '人工确认已摆好' : '跳过'}，保留原计数 $_count 颗',
      ),
    );
    _moveToNext(startNext: startNext);
    notifyListeners();
  }

  /// 批量标记当前及剩余药物为跳过；已经完成的结果保持不变。
  void skipRemaining() {
    if (!active) return;
    for (var index = _medicineIndex; index < _taskMedicines.length; index++) {
      _medicineResults[_taskMedicines[index].id] = MedicineResult(
        outcome: MedicineOutcome.skipped,
        countedParticles: index == _medicineIndex ? _count : 0,
      );
    }
    _stage = DispenseStage.completed;
    _taskEvents.add(RecordEvent(DateTime.now(), '跳过当前及全部剩余药物'));
    _finishRecord(TaskOutcome.partial);
    notifyListeners();
  }

  void setOpening(double value) {
    _opening = value.clamp(0, 1);
    notifyListeners();
  }

  /// 主动结束：当前药待核实、后续药未执行，保留已发生计数并等待取盒。
  void cancel() {
    if (!active) return;
    for (var index = _medicineIndex; index < _taskMedicines.length; index++) {
      _medicineResults[_taskMedicines[index].id] = MedicineResult(
        outcome: index == _medicineIndex
            ? MedicineOutcome.unverified
            : MedicineOutcome.notStarted,
        countedParticles: index == _medicineIndex ? _count : 0,
      );
    }
    _stage = DispenseStage.cancelled;
    _taskEvents.add(RecordEvent(DateTime.now(), '人工结束本次摆药，当前药待核实，剩余药未执行'));
    _finishRecord(TaskOutcome.cancelled);
    notifyListeners();
  }

  /// 一次任务最多创建一条结果。复制资料、逐药结果和事件，避免后续编辑改写历史。
  void _finishRecord(TaskOutcome outcome) {
    if (_currentRecordId != null) return;
    final now = DateTime.now();
    final record = DispenseRecord(
      id: 'session-${++_recordSequence}',
      residentId: _preparedResidentId ?? '',
      name: _taskResidentName,
      bed: _taskResidentBed,
      avatar: _taskResidentAvatar,
      startedAt: _startedAt ?? now,
      finishedAt: now,
      coverageStart: _preparedStart,
      coverageEnd: _preparedEnd,
      outcome: outcome,
      device: _taskDevice,
      medicines: [
        for (final medicine in _taskMedicines)
          RecordedMedicine(
            id: medicine.id,
            name: medicine.name,
            strength: medicine.strength,
            form: medicine.form,
            schedule: medicine.schedule,
            target: medicine.target,
            result:
                _medicineResults[medicine.id] ??
                const MedicineResult(
                  outcome: MedicineOutcome.unverified,
                  countedParticles: 0,
                ),
          ),
      ],
      events: [..._taskEvents, RecordEvent(now, '摆药处理结束，等待取盒')],
    );
    _records.insert(0, record);
    _currentRecordId = record.id;
  }

  /// UI-only feedback input. Null means unavailable, never a removed box.
  /// Record identity prevents late feedback from releasing a different task.
  /// 只有当前 recordId 的反馈可改变取盒状态；未知和失败不能解除占用。
  /// “离轨且设备就绪”才释放任务；重复相同反馈不重复追加事件。
  void updateCollectionFeedback({
    required String recordId,
    required bool? boxOnTrack,
    bool trackReady = false,
    bool retractionFailed = false,
  }) {
    final record = currentRecord;
    if (record == null || record.id != recordId) return;
    final next = boxOnTrack == null
        ? CollectionStage.detectionFailed
        : boxOnTrack
        ? CollectionStage.waiting
        : retractionFailed
        ? CollectionStage.retractionFailed
        : trackReady
        ? CollectionStage.complete
        : CollectionStage.retracting;
    if (record.collection == next) return;
    final description = switch (next) {
      CollectionStage.waiting => '演练反馈：药盒仍在轨道上',
      CollectionStage.detectionFailed => '演练反馈暂不可用，保留结果等待恢复',
      CollectionStage.retracting => '演练反馈：药盒已离轨，等待轨道就绪',
      CollectionStage.retractionFailed => '演练反馈：轨道收回未确认',
      CollectionStage.complete => '演练反馈：药盒已离轨且轨道就绪，取盒结束',
    };
    final index = _records.indexWhere((r) => r.id == recordId);
    _records[index] = record.withCollection(
      next,
      RecordEvent(DateTime.now(), description),
    );
    if (next == CollectionStage.complete) {
      _collectionTimer?.cancel();
      _currentRecordId = null;
    }
    notifyListeners();
  }

  /// 显式演练入口。仅示例记录可使用定时器模拟离轨；普通任务不靠超时猜测。
  bool openExampleCollection(String recordId) {
    if (busy) return false;
    final record = _records.where((r) => r.id == recordId).firstOrNull;
    if (record == null ||
        !record.isExample ||
        record.collection == CollectionStage.complete) {
      return false;
    }
    _currentRecordId = recordId;
    _stage = DispenseStage.completed;
    _collectionTimer?.cancel();
    _collectionTimer = Timer(const Duration(seconds: 2), () {
      updateCollectionFeedback(recordId: recordId, boxOnTrack: false);
      _collectionTimer = Timer(const Duration(milliseconds: 900), () {
        updateCollectionFeedback(
          recordId: recordId,
          boxOnTrack: false,
          trackReady: true,
        );
      });
    });
    notifyListeners();
    return true;
  }

  /// 按需加载一次示例历史，不写入任何长者的完成覆盖。
  void loadExampleRecords() {
    if (examplesLoaded) return;
    examplesLoaded = true;
    final today = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final resident = residents[i];
      final at = today.subtract(Duration(days: i, hours: 1));
      final medicines = PreparationPlan(
        resident,
        DateTime(at.year, at.month, at.day),
        7,
        bedtime: true,
      ).medicines;
      _records.add(
        DispenseRecord(
          id: 'example-$i',
          residentId: resident.id,
          name: resident.name,
          bed: resident.bed,
          avatar: resident.avatarAsset,
          startedAt: at.subtract(const Duration(minutes: 12)),
          finishedAt: at,
          coverageStart: DateTime(at.year, at.month, at.day),
          coverageEnd: DateTime(at.year, at.month, at.day + 6),
          outcome: TaskOutcome.values[i],
          collection: i == 0
              ? CollectionStage.waiting
              : CollectionStage.complete,
          device: '演练设备 ${i + 1}',
          isExample: true,
          medicines: [
            for (var j = 0; j < medicines.length; j++)
              RecordedMedicine(
                id: medicines[j].id,
                name: medicines[j].name,
                strength: medicines[j].strength,
                form: medicines[j].form,
                schedule: medicines[j].schedule,
                target: medicines[j].target,
                result: MedicineResult(
                  outcome: i == 2
                      ? MedicineOutcome.unverified
                      : i == 1
                      ? MedicineOutcome.skipped
                      : j == 1
                      ? MedicineOutcome.confirmedPrepared
                      : MedicineOutcome.completed,
                  countedParticles: i == 0
                      ? (j == 1 ? 2 : medicines[j].target)
                      : 2,
                  confirmedParticles: i == 0 && j == 1
                      ? medicines[j].target
                      : null,
                ),
              ),
          ],
          events: [RecordEvent(at, '载入演练示例，仅供界面体验')],
        ),
      );
    }
    notifyListeners();
  }

  /// 保存会话偏好并通知页面。已经启动的任务保留自己的计划数量。
  void saveSettings({
    required int days,
    required bool split,
    required bool night,
    required bool tomorrow,
  }) {
    preparationDays = days;
    splitMeals = split;
    bedtime = night;
    startTomorrow = tomorrow;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _collectionTimer?.cancel();
    boxFeedback.dispose();
    super.dispose();
  }
}
