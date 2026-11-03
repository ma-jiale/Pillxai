import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<bool> saveLabelPdf(Uint8List bytes, String filename) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return await const MethodChannel('pillxai/pdf')
            .invokeMethod<bool>('save', {'bytes': bytes, 'name': filename}) ??
        false;
  }
  final file = XFile.fromData(
    bytes,
    mimeType: 'application/pdf',
    name: filename,
  );
  if (kIsWeb) {
    await file.saveTo(filename);
    return true;
  }
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}
