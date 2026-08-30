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
  Future<VideoSaveResult> saveToPhotos(String filename) async {
    return const VideoSaveResult(
      isSuccess: true,
      message: '👉 Hãy chọn "Lưu video" trên bảng chia sẻ để lưu vào Album Ảnh.',
    );
  }

  Future<VideoSaveResult> downloadToFiles(String filename) async {
    return const VideoSaveResult(
      isSuccess: true,
      message: '📁 Đã tải video vào thư mục Tệp / Downloads!',
    );
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  return RealtimeVideoSession();
}
