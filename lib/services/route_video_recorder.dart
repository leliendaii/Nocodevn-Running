import 'dart:typed_data';
import 'route_video_recorder_stub.dart'
    if (dart.library.html) 'route_video_recorder_web.dart';

class RouteVideoRecorder {
  /// Quay và xuất Video MP4 3D Flyover chính xác 100% từng pixel như màn hình app
  static Future<bool> recordExactScreen({
    required Future<Uint8List?> Function(double t) frameProvider,
    required int totalFrames,
    required double speed,
    required String sessionId,
    required Function(double progress, String status) onProgress,
  }) async {
    return await recordAndExportExactFlyoverVideo(
      frameProvider: frameProvider,
      totalFrames: totalFrames,
      speed: speed,
      sessionId: sessionId,
      onProgress: onProgress,
    );
  }
}
