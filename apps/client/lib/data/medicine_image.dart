import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:image_picker/image_picker.dart';

enum MedicineImageSource { camera, file }

/// A restarted app has no original prescription draft to safely attach to.
/// Detect this case and ask the worker to reselect instead of assigning it elsewhere.
Future<bool> discardedInterruptedMedicinePhoto() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final lost = await ImagePicker().retrieveLostData();
    return !lost.isEmpty;
  } catch (_) {
    return false;
  }
}

Future<String?> pickMedicineImage(MedicineImageSource source) async {
  final XFile? file;
  if (source == MedicineImageSource.camera) {
    file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
    );
  } else {
    file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '药品图片',
          extensions: ['jpg', 'jpeg', 'png'],
          mimeTypes: ['image/jpeg', 'image/png'],
          uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
        ),
      ],
    );
  }
  if (file == null) return null;
  if (await file.length() > 10 * 1024 * 1024) {
    throw const FormatException('请选择小于 10 MB 的图片。');
  }
  return thumbnailMedicineImage(await file.readAsBytes());
}

Future<String> thumbnailMedicineImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? decoded;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 24000000) {
      throw const FormatException('图片尺寸过大，请选择较小的图片。');
    }
    final ratio = math.min(
      1.0,
      512 / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * ratio).round()),
      targetHeight: math.max(1, (descriptor.height * ratio).round()),
    );
    decoded = (await codec.getNextFrame()).image;
    final png = await decoded.toByteData(format: ui.ImageByteFormat.png);
    if (png == null || png.lengthInBytes > 1100000) {
      throw const FormatException('图片处理失败，请换一张图片。');
    }
    return 'data:image/png;base64,${base64Encode(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes))}';
  } finally {
    decoded?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

ImageProvider? medicineImageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  const prefix = 'data:image/png;base64,';
  if (value.startsWith(prefix)) {
    try {
      return MemoryImage(base64Decode(value.substring(prefix.length)));
    } on FormatException {
      return null;
    }
  }
  return AssetImage(value);
}
