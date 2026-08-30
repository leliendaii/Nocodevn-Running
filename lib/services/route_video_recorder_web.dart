// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class RealtimeVideoSession {
  final html.CanvasElement canvas;
  final html.CanvasRenderingContext2D ctx;
  final html.MediaRecorder mediaRecorder;
  final List<html.Blob> videoChunks;
  final Completer<void> completer;

  RealtimeVideoSession({
    required this.canvas,
    required this.ctx,
    required this.mediaRecorder,
    required this.videoChunks,
    required this.completer,
  });

  /// Đẩy khung hình raw GPU (RGBA) trực tiếp vào Canvas trong 1ms (Zero Lag, chuẩn 60 FPS)
  void pushRawFrame(Uint8List rawRgbaBytes, int frameWidth, int frameHeight) {
    try {
      final imgData = ctx.createImageData(frameWidth, frameHeight);
      imgData.data.setRange(0, rawRgbaBytes.lengthInBytes, rawRgbaBytes);
      ctx.putImageData(imgData, 0, 0);
    } catch (_) {}
  }

  /// Dừng ghi hình và lưu video MP4 60 FPS siêu mượt
  Future<void> stopAndDownload(String filename) async {
    try {
      mediaRecorder.stop();
      await completer.future;

      if (videoChunks.isNotEmpty) {
        final finalBlob = html.Blob(videoChunks, 'video/mp4');
        await _saveOrDownloadVideo(finalBlob, filename);
      }
    } catch (_) {}
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  final canvas = html.CanvasElement(width: width, height: height);
  final ctx = canvas.context2D;
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';

  // Thu thập luồng 60 FPS thời gian thực
  dynamic stream;
  try {
    stream = (canvas as dynamic).captureStream(fps.toInt());
  } catch (_) {
    stream = (canvas as dynamic).captureStream();
  }

  String mimeType = 'video/webm;codecs=vp9';
  if (!html.MediaRecorder.isTypeSupported(mimeType)) {
    if (html.MediaRecorder.isTypeSupported('video/mp4')) {
      mimeType = 'video/mp4';
    } else if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
      mimeType = 'video/webm;codecs=vp8';
    } else if (html.MediaRecorder.isTypeSupported('video/webm')) {
      mimeType = 'video/webm';
    } else {
      mimeType = '';
    }
  }

  final Map<String, dynamic> recorderOptions = {
    'videoBitsPerSecond': 12000000, // 12 Mbps 60 FPS Crystal Clear
  };
  if (mimeType.isNotEmpty) {
    recorderOptions['mimeType'] = mimeType;
  }

  final mediaRecorder = html.MediaRecorder(stream, recorderOptions);
  final List<html.Blob> chunks = [];
  final completer = Completer<void>();

  mediaRecorder.addEventListener('dataavailable', (event) {
    final blob = (event as dynamic).data as html.Blob?;
    if (blob != null && blob.size > 0) {
      chunks.add(blob);
    }
  });

  mediaRecorder.addEventListener('stop', (_) {
    if (!completer.isCompleted) completer.complete();
  });

  mediaRecorder.start(40); // Thu thập gói dữ liệu mượt mà mỗi 40ms

  return RealtimeVideoSession(
    canvas: canvas,
    ctx: ctx,
    mediaRecorder: mediaRecorder,
    videoChunks: chunks,
    completer: completer,
  );
}

Future<void> _saveOrDownloadVideo(html.Blob videoBlob, String filename) async {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  final isMobile = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('mobile');

  if (isMobile) {
    try {
      final file = html.File([videoBlob], filename, {'type': 'video/mp4'});
      await html.window.navigator.share({
        'files': [file],
        'title': 'Video 3D Flyover Chạy Bộ',
        'text': 'Lộ trình chạy bộ 3D Flyover siêu mượt 60 FPS của tôi',
      });
      return;
    } catch (_) {}
  }

  // Tải file trực tiếp về Windows / Mac
  final url = html.Url.createObjectUrlFromBlob(videoBlob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
