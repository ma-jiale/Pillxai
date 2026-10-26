enum MedicineOutcome {
  completed,
  confirmedPrepared,
  skipped,
  unverified,
  notStarted,
}

class MedicineResult {
  const MedicineResult({
    required this.outcome,
    required this.countedParticles,
    this.confirmedParticles,
  });
  final MedicineOutcome outcome;
  final int countedParticles;
  final int? confirmedParticles;
  String get label => switch (outcome) {
    MedicineOutcome.completed => '已完成',
    MedicineOutcome.confirmedPrepared => '人工确认',
    MedicineOutcome.skipped => '已跳过',
    MedicineOutcome.unverified => '待核实',
    MedicineOutcome.notStarted => '未执行',
  };
}

enum TaskOutcome { completed, partial, cancelled }

enum CollectionStage {
  waiting,
  detectionFailed,
  retracting,
  retractionFailed,
  complete,
}

class RecordedMedicine {
  const RecordedMedicine({
    required this.id,
    required this.name,
    required this.strength,
    required this.form,
    required this.schedule,
    required this.target,
    required this.result,
  });
  final String id;
  final String name;
  final String strength;
  final String form;
  final String schedule;
  final int target;
  final MedicineResult result;
}

class RecordEvent {
  const RecordEvent(this.at, this.description);
  final DateTime at;
  final String description;
}

/// Immutable session snapshots. These are preview records, never device evidence.
class DispenseRecord {
  DispenseRecord({
    required this.id,
    required this.residentId,
    required this.name,
    required this.bed,
    this.avatar,
    required this.startedAt,
    required this.finishedAt,
    this.coverageStart,
    this.coverageEnd,
    required this.outcome,
    required List<RecordedMedicine> medicines,
    required List<RecordEvent> events,
    this.collection = CollectionStage.waiting,
    this.device = '未连接设备',
    this.operatorName = '管理员',
    this.isExample = false,
  }) : medicines = List.unmodifiable(medicines),
       events = List.unmodifiable(events);
  final String id;
  final String residentId;
  final String name;
  final String bed;
  final String? avatar;
  final DateTime startedAt;
  final DateTime finishedAt;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final TaskOutcome outcome;
  final List<RecordedMedicine> medicines;
  final List<RecordEvent> events;
  final CollectionStage collection;
  final String device;
  final String operatorName;
  final bool isExample;

  String get label => switch (outcome) {
    TaskOutcome.completed => '全部完成',
    TaskOutcome.partial => completedCount == 0 ? '未完成' : '部分完成',
    TaskOutcome.cancelled => '已取消',
  };
  bool get needsReview =>
      medicines.any((m) => m.result.outcome == MedicineOutcome.unverified);
  int get completedCount => medicines
      .where(
        (m) =>
            m.result.outcome == MedicineOutcome.completed ||
            m.result.outcome == MedicineOutcome.confirmedPrepared,
      )
      .length;
  String get collectionLabel => switch (collection) {
    CollectionStage.waiting => '等待取盒',
    CollectionStage.detectionFailed => '取盒待核对',
    CollectionStage.retracting => '正在收回轨道',
    CollectionStage.retractionFailed => '收回未确认',
    CollectionStage.complete => '取盒已结束',
  };

  DispenseRecord withCollection(CollectionStage value, RecordEvent event) =>
      DispenseRecord(
        id: id,
        residentId: residentId,
        name: name,
        bed: bed,
        avatar: avatar,
        startedAt: startedAt,
        finishedAt: finishedAt,
        coverageStart: coverageStart,
        coverageEnd: coverageEnd,
        outcome: outcome,
        medicines: medicines,
        events: [...events, event],
        collection: value,
        device: device,
        operatorName: operatorName,
        isExample: isExample,
      );
}

String recordDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
String recordTime(DateTime date) =>
    '${recordDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
