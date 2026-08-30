import 'route_video_recorder_stub.dart'
    if (dart.library.html) 'route_video_recorder_web.dart';

export 'route_video_recorder_stub.dart'
    if (dart.library.html) 'route_video_recorder_web.dart';

class RouteVideoRecorder {
  /// Khởi tạo phiên quay video 60 FPS theo thời gian thực (Real-time VSync)
  static RealtimeVideoSession startSession({
    required int width,
    required int height,
    double fps = 60.0,
  }) {
    return startRealtimeVideoSession(width: width, height: height, fps: fps);
  }
}
