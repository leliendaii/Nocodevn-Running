// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';

Future<bool> recordAndExportExactFlyoverVideo({
  required Future<Uint8List?> Function(double t) frameProvider,
  required int totalFrames,
  required double speed,
  required String sessionId,
  required Function(double progress, String status) onProgress,
}) async {
  onProgress(1.0, 'Đã hoàn tất.');
  return true;
}
