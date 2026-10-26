import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dispense_record.dart';
export 'dispense_record.dart';

/// Prescription doses are expressed in the original unit, never machine counts.
class DoseSchedule {
  const DoseSchedule({
    this.morning = 1,
    this.noon = 1,
    this.evening = 1,
    this.night = 0,
  });

  final double morning;
  final double noon;
  final double evening;
  final double night;

  List<double> get values => [morning, noon, evening, night];
  bool get hasDose => values.any((dose) => dose > 0);

  String describe(String unit) {
    const labels = ['早', '午', '晚', '睡前'];
    return [
      for (var index = 0; index < values.length; index++)
        if (values[index] > 0)
          '${labels[index]} ${formatDose(values[index])} $unit',
    ].join(' · ');
  }
}

String formatDose(double dose) =>
    dose == dose.roundToDouble() ? dose.toInt().toString() : dose.toString();

class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.strength,
    this.form = '整片',
    this.doses = const DoseSchedule(),
    this.unit = '片',
    this.meal = '饭后',
    this.target = 21,
    this.startDate,
    this.endDate,
    this.stopped = false,
    this.imageAsset,
  });
  final String id;
  final String name;
  final String strength;
  final String form;
  final DoseSchedule doses;
  final String unit;
  final String meal;
  // This fixed count drives the animation only; it is not a prescription plan.
  final int target;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool stopped;
  final String? imageAsset;

  String get schedule => doses.describe(unit);

  bool isEffectiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !stopped &&
        doses.hasDose &&
        (startDate == null || !day.isBefore(startDate!)) &&
        (endDate == null || !day.isAfter(endDate!));
  }

  Medicine copyWith({
    String? name,
    String? strength,
    String? form,
    DoseSchedule? doses,
    String? unit,
    String? meal,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? stopped,
    int? target,
  }) => Medicine(
    id: id,
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    doses: doses ?? this.doses,
    unit: unit ?? this.unit,
    meal: meal ?? this.meal,
    target: target ?? this.target,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    stopped: stopped ?? this.stopped,
    imageAsset: imageAsset,
  );
}

class Resident {
  Resident({
    required this.id,
    required this.name,
    required this.bed,
    required this.medicines,
    this.avatarAsset,
  });
  final String id;
  String name;
  String bed;
  final List<Medicine> medicines;
  final String? avatarAsset;
}

enum DispenseStage {
  awaitingVerification,
  ready,
  running,
  paused,
  completed,
  cancelled,
}

enum BoxFeedback { disconnected, opening, waiting, match, other, failed }

/// In-memory preview data only. No network, hardware commands or actual records.
class DemoModel extends ChangeNotifier {
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
    prepareTask(residents.first, notify: false);
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
          target: 7,
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
          target: 14,
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
          target: 7,
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
  String taskResidentName = '';
  String taskResidentBed = '';
  String? taskResidentAvatar;
  List<Medicine> taskMedicines = [];
  int medicineIndex = 0;
  int count = 0;
  double opening = .70;
  DispenseStage stage = DispenseStage.awaitingVerification;
  int preparationDays = 7;
  bool splitMeals = true;
  bool bedtime = false;
  bool startTomorrow = false;
  Timer? _ticker;
  final Map<String, DateTime> demoCoverage = {};
  // Read-only in the UI. A future device adapter supplies session observations.
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

  bool startPreparedTask(
    Resident resident,
    List<Medicine> medicines, {
    DateTime? end,
    DateTime? startDate,
    String? device,
  }) {
    if (busy || medicines.isEmpty) return false;
    taskResidentName = resident.name;
    taskResidentBed = resident.bed;
    taskResidentAvatar = resident.avatarAsset;
    taskMedicines = List.unmodifiable(medicines);
    _medicineResults.clear();
    _preparedResidentId = resident.id;
    _preparedEnd = end;
    _preparedStart = startDate;
    _startedAt = DateTime.now();
    _taskDevice = device ?? '未连接设备';
    _taskEvents
      ..clear()
      ..add(RecordEvent(_startedAt!, '开始摆药（演练）'));
    medicineIndex = 0;
    count = 0;
    opening = .70;
    stage = DispenseStage.running;
    notifyListeners();
    return true;
  }

  Medicine get currentMedicine => taskMedicines[medicineIndex];
  Medicine? get nextMedicine => medicineIndex + 1 < taskMedicines.length
      ? taskMedicines[medicineIndex + 1]
      : null;
  bool get active =>
      stage == DispenseStage.running || stage == DispenseStage.paused;
  String get stageLabel => switch (stage) {
    DispenseStage.awaitingVerification => '等待药盒识别',
    DispenseStage.ready => '已核验，可以开始',
    DispenseStage.running => '摆药进行中',
    DispenseStage.paused => '已暂停',
    DispenseStage.completed => hasSkippedMedicines ? '本次已结束 · 有跳过药物' : '本次已完成',
    DispenseStage.cancelled => '本次已取消',
  };

  void selectResident(String id) {
    selectedResidentId = id;
    notifyListeners();
  }

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

  String? preparationIssue(Resident resident) {
    if (busy) return '当前任务尚未结束，请先完成摆药和取盒。';
    final medicines = resident.medicines
        .where((medicine) => medicine.isEffectiveOn(DateTime.now()))
        .toList();
    if (medicines.isEmpty) return '没有今日有效用药，请先添加或核对用药期间。';
    if (!bedtime && medicines.any((medicine) => medicine.doses.night > 0)) {
      return '处方包含睡前用药，请先在设置中启用睡前格。';
    }
    return null;
  }

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

  bool prepareTask(Resident resident, {bool notify = true}) {
    if (preparationIssue(resident) != null) return false;
    _preparedResidentId = resident.id;
    _preparedEnd = null;
    _preparedStart = null;
    _startedAt = null;
    _taskDevice = '未连接设备';
    _taskEvents.clear();
    _medicineResults.clear();
    taskResidentName = resident.name;
    taskResidentBed = resident.bed;
    taskResidentAvatar = resident.avatarAsset;
    taskMedicines = resident.medicines
        .where((medicine) => medicine.isEffectiveOn(DateTime.now()))
        .toList();
    medicineIndex = 0;
    count = 0;
    opening = .70;
    stage = DispenseStage.awaitingVerification;
    if (notify) notifyListeners();
    return true;
  }

  void verifyBox() {
    if (stage != DispenseStage.awaitingVerification) return;
    stage = DispenseStage.ready;
    notifyListeners();
  }

  void start() {
    if (stage != DispenseStage.ready && stage != DispenseStage.paused) {
      return;
    }
    stage = DispenseStage.running;
    _startedAt ??= DateTime.now();
    _taskEvents.add(RecordEvent(DateTime.now(), '开始或继续摆药（演练）'));
    notifyListeners();
  }

  void pause() {
    if (stage != DispenseStage.running) return;
    stage = DispenseStage.paused;
    notifyListeners();
  }

  void advance() {
    if (stage != DispenseStage.running) return;
    count++;
    if (count >= currentMedicine.target) {
      count = currentMedicine.target;
      _medicineResults[currentMedicine.id] = MedicineResult(
        outcome: MedicineOutcome.completed,
        countedParticles: count,
      );
      _moveToNext(startNext: true);
    }
    notifyListeners();
  }

  void _moveToNext({required bool startNext}) {
    if (nextMedicine != null) {
      medicineIndex++;
      count = 0;
      opening = .70;
      stage = startNext ? DispenseStage.running : DispenseStage.paused;
    } else {
      stage = DispenseStage.completed;
      // A resident-wide coverage date is only valid when every medicine is done.
      if (_medicineResults.length == taskMedicines.length &&
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

  void skipCurrent({bool markPrepared = false, bool startNext = true}) {
    if (!active) return;
    _medicineResults[currentMedicine.id] = MedicineResult(
      outcome: markPrepared
          ? MedicineOutcome.confirmedPrepared
          : MedicineOutcome.skipped,
      countedParticles: count,
      confirmedParticles: markPrepared ? currentMedicine.target : null,
    );
    _taskEvents.add(
      RecordEvent(
        DateTime.now(),
        '${currentMedicine.name}：${markPrepared ? '人工确认已摆好' : '跳过'}，保留原计数 $count 颗',
      ),
    );
    _moveToNext(startNext: startNext);
    notifyListeners();
  }

  void skipRemaining() {
    if (!active) return;
    for (var index = medicineIndex; index < taskMedicines.length; index++) {
      _medicineResults[taskMedicines[index].id] = MedicineResult(
        outcome: MedicineOutcome.skipped,
        countedParticles: index == medicineIndex ? count : 0,
      );
    }
    stage = DispenseStage.completed;
    _taskEvents.add(RecordEvent(DateTime.now(), '跳过当前及全部剩余药物'));
    _finishRecord(TaskOutcome.partial);
    notifyListeners();
  }

  void setOpening(double value) {
    opening = value.clamp(0, 1);
    notifyListeners();
  }

  void cancel() {
    if (!active) return;
    for (var index = medicineIndex; index < taskMedicines.length; index++) {
      _medicineResults[taskMedicines[index].id] = MedicineResult(
        outcome: index == medicineIndex
            ? MedicineOutcome.unverified
            : MedicineOutcome.notStarted,
        countedParticles: index == medicineIndex ? count : 0,
      );
    }
    stage = DispenseStage.cancelled;
    _taskEvents.add(RecordEvent(DateTime.now(), '人工结束本次摆药，当前药待核实，剩余药未执行'));
    _finishRecord(TaskOutcome.cancelled);
    notifyListeners();
  }

  void _finishRecord(TaskOutcome outcome) {
    if (_currentRecordId != null) return;
    final now = DateTime.now();
    final record = DispenseRecord(
      id: 'session-${++_recordSequence}',
      residentId: _preparedResidentId ?? '',
      name: taskResidentName,
      bed: taskResidentBed,
      avatar: taskResidentAvatar,
      startedAt: _startedAt ?? now,
      finishedAt: now,
      coverageStart: _preparedStart,
      coverageEnd: _preparedEnd,
      outcome: outcome,
      device: _taskDevice,
      medicines: [
        for (final medicine in taskMedicines)
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

  bool openExampleCollection(String recordId) {
    if (busy) return false;
    final record = _records.where((r) => r.id == recordId).firstOrNull;
    if (record == null ||
        !record.isExample ||
        record.collection == CollectionStage.complete) {
      return false;
    }
    _currentRecordId = recordId;
    stage = DispenseStage.completed;
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

  void loadExampleRecords() {
    if (examplesLoaded) return;
    examplesLoaded = true;
    final today = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final resident = residents[i];
      final at = today.subtract(Duration(days: i, hours: 1));
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
            for (var j = 0; j < resident.medicines.length; j++)
              RecordedMedicine(
                id: resident.medicines[j].id,
                name: resident.medicines[j].name,
                strength: resident.medicines[j].strength,
                form: resident.medicines[j].form,
                schedule: resident.medicines[j].schedule,
                target: resident.medicines[j].target,
                result: MedicineResult(
                  outcome: i == 2
                      ? MedicineOutcome.unverified
                      : i == 1
                      ? MedicineOutcome.skipped
                      : j == 1
                      ? MedicineOutcome.confirmedPrepared
                      : MedicineOutcome.completed,
                  countedParticles: i == 0
                      ? (j == 1 ? 2 : resident.medicines[j].target)
                      : 2,
                  confirmedParticles: i == 0 && j == 1
                      ? resident.medicines[j].target
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

  void resetDemo() {
    if (busy) return;
    stage = DispenseStage.cancelled;
    final candidate = residents
        .where((resident) => preparationIssue(resident) == null)
        .firstOrNull;
    if (candidate != null) {
      prepareTask(candidate);
    } else {
      count = 0;
      opening = .70;
      notifyListeners();
    }
  }

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
