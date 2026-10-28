import 'dart:typed_data';

export 'execution_state.dart';

/// Transport owns a single connection. Opening it must not send machine commands.
abstract interface class DeviceTransport {
  Future<void> open();
  Future<Uint8List> read();
  Future<void> write(Uint8List bytes);
  Future<void> close();
}

enum DeviceEventKind {
  acknowledged,
  actionDone,
  batchFinished,
  counterError,
  initialized,
  count,
  outputCount,
  recoveredCount,
  rfid,
  noCard,
  barcodeAppeared,
  barcodeDisappeared,
  stalled,
  unknown,
  malformed,
}

/// Feedback carries no invented task ID. Association belongs to the executor.
/// NO CARD is only an RFID observation, never proof of tray removal/readiness.
final class DeviceEvent {
  const DeviceEvent(
    this.kind,
    this.raw, {
    this.count,
    this.width,
    this.uid,
    this.barcode,
  });

  final DeviceEventKind kind;
  final String raw;
  final int? count;
  final String? width;
  final String? uid;
  final String? barcode;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'raw': raw,
    if (count != null) 'count': count,
    if (width != null) 'width': width,
    if (uid != null) 'uid': uid,
    if (barcode != null) 'barcode': barcode,
  };
}
