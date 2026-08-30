import 'route_video_recorder_stub.dart'
    if (dart.library.html) 'route_video_recorder_web.dart';

class RouteVideoRecorder {
  /// Quay và xuất Video MP4 3D Flyover thật 100% với khung hình động chuyển động
  static Future<bool> recordAndExport({
    required List<Map<String, double>> routePoints,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    required double speed,
    required String sessionId,
    required Function(double progress, String status) onProgress,
  }) async {
    return await recordAndExportFlyoverVideo(
      routePoints: routePoints,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: pace,
      speed: speed,
      sessionId: sessionId,
      onProgress: onProgress,
    );
  }
}
