import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

const residentAvatarPresets = [
  'assets/images/avatars/wang.png',
  'assets/images/avatars/zhang.png',
  'assets/images/avatars/li.png',
  'assets/images/avatars/chen.png',
];

Future<String?> pickResidentAvatar() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: '图片',
        extensions: ['jpg', 'jpeg', 'png'],
        mimeTypes: ['image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 10 * 1024 * 1024) {
    throw const FormatException('请选择小于 10 MB 的图片。');
  }
  return thumbnailAvatar(await file.readAsBytes());
}

/// Decode and resize before sending; the original file is never uploaded.
Future<String> thumbnailAvatar(Uint8List bytes) async {
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
      256 / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * ratio).round()),
      targetHeight: math.max(1, (descriptor.height * ratio).round()),
    );
    decoded = (await codec.getNextFrame()).image;
    final png = await decoded.toByteData(format: ui.ImageByteFormat.png);
    if (png == null || png.lengthInBytes > 270000) {
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
