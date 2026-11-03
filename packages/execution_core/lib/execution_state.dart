/// One terminal's durable execution state. No widget or platform dependencies.
enum ExecutionPhase {
  idle,
  opening,
  recognizing,
  closingPreparation,
  ready,
  starting,
  running,
  pausing,
  paused,
  resuming,
  reviewingSkip,
  skipping,
  openingForReview,
  reviewingCount,
  awaitingNextBatch,
  changingTray,
  collecting,
  closing,
  completed,
  recovery,
  stopping,
  awaitingSafeConfirmation,
  cancelled,
  deleting,
}

class ExecutionState {
  ExecutionState();
  ExecutionPhase phase = ExecutionPhase.idle;
  int batch = 0;
  int count = 0;
  double? gate;
  String message = '';
  String? uid;
  DateTime? uidAt;
  String? barcode;
  DateTime? barcodeAt;
  bool permitted = false;
  bool matrixIssued = false;
  bool cancelRequested = false;
  bool skipWasRunning = false;
  Map<String, dynamic>? skipRequest;
  bool resetObserved = false;
  List<int> stalledMotors = [];
  bool connected = false;
  bool disconnectedDiscard = false;
  String? pending;
  bool acknowledged = false;
  String openPurpose = 'initial';
  int? counterErrorBatch;
  bool reviewTrayRemoved = false;
  bool trayPresent = false;
  DateTime? absentAt;
  bool closeDone = false;
  bool readyObserved = false;
  int sequence = 0;

  bool get active => ![
    ExecutionPhase.idle,
    ExecutionPhase.completed,
    ExecutionPhase.cancelled,
  ].contains(phase);
  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'batch': batch,
    'count': count,
    'gate': gate,
    'message': message,
    'uid': uid,
    'uid_at': uidAt?.toUtc().toIso8601String(),
    'barcode': barcode,
    'barcode_at': barcodeAt?.toUtc().toIso8601String(),
    'permitted': permitted,
    'matrix_issued': matrixIssued,
    'cancel_requested': cancelRequested,
    'skip_was_running': skipWasRunning,
    'skip_request': skipRequest,
    'reset_observed': resetObserved,
    'stalled_motors': stalledMotors,
    'connected': connected,
    'disconnected_discard': disconnectedDiscard,
    'pending': pending,
    'acknowledged': acknowledged,
    'open_purpose': openPurpose,
    'counter_error_batch': counterErrorBatch,
    'review_tray_removed': reviewTrayRemoved,
    'tray_present': trayPresent,
    'absent_at': absentAt?.toUtc().toIso8601String(),
    'close_done': closeDone,
    'ready_observed': readyObserved,
    'sequence': sequence,
  };

  factory ExecutionState.fromJson(Map<String, dynamic> json) => ExecutionState()
    ..phase = ExecutionPhase.values.byName(json['phase'] as String)
    ..batch = json['batch'] as int
    ..count = json['count'] as int
    ..gate = (json['gate'] as num?)?.toDouble()
    ..message = json['message'] as String
    ..uid = json['uid'] as String?
    ..uidAt = DateTime.tryParse(json['uid_at'] as String? ?? '')
    ..barcode = json['barcode'] as String?
    ..barcodeAt = DateTime.tryParse(json['barcode_at'] as String? ?? '')
    ..permitted = json['permitted'] as bool
    ..matrixIssued = json['matrix_issued'] as bool? ?? false
    ..cancelRequested = json['cancel_requested'] as bool? ?? false
    ..skipWasRunning = json['skip_was_running'] as bool? ?? false
    ..skipRequest = json['skip_request'] == null
        ? null
        : Map<String, dynamic>.from(json['skip_request'] as Map)
    ..resetObserved = json['reset_observed'] as bool
    ..stalledMotors = (json['stalled_motors'] as List? ?? [])
        .cast<int>()
        .toList()
    ..connected = json['connected'] as bool
    ..disconnectedDiscard = json['disconnected_discard'] as bool? ?? false
    ..pending = json['pending'] as String?
    ..acknowledged = json['acknowledged'] as bool
    ..openPurpose = json['open_purpose'] as String
    ..counterErrorBatch = json['counter_error_batch'] as int?
    ..reviewTrayRemoved = json['review_tray_removed'] == true
    ..trayPresent = json['tray_present'] as bool
    ..absentAt = DateTime.tryParse(json['absent_at'] as String? ?? '')
    ..closeDone = json['close_done'] as bool
    ..readyObserved = json['ready_observed'] as bool
    ..sequence = json['sequence'] as int;
}
