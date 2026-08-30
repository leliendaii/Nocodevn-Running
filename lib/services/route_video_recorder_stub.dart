// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';

class RealtimeVideoSession {
  void pushRawFrame(Uint8List rawRgbaBytes, int frameWidth, int frameHeight) {}
  Future<bool> finishRecording() async => true;
  Future<bool> saveOrShare(String filename) async => true;
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  return RealtimeVideoSession();
}
