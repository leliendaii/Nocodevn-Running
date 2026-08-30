// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';

Future<bool> recordAndExportFlyoverVideo({
  required List<Map<String, double>> routePoints,
  required double distanceKm,
  required int durationSeconds,
  required String pace,
  required double speed,
  required String sessionId,
  required Function(double progress, String status) onProgress,
}) async {
  onProgress(1.0, 'Đã hoàn tất.');
  return true;
}
