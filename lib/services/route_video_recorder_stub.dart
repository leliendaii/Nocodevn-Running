// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';

class VideoSaveResult {
  final bool isSuccess;
  final String message;
  const VideoSaveResult({required this.isSuccess, required this.message});
}

class RealtimeVideoSession {
  void pushRawFrame(Uint8List rawRgbaBytes, int frameWidth, int frameHeight) {}
  Future<bool> finishRecording() async => true;
  Future<VideoSaveResult> saveOrShare(String filename) async {
    return const VideoSaveResult(isSuccess: true, message: 'Đã tải video thành công!');
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  return RealtimeVideoSession();
}
