// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class VideoSaveResult {
  final bool isSuccess;
  final String message;
  const VideoSaveResult({required this.isSuccess, required this.message});
}

class RealtimeVideoSession {
  final html.CanvasElement canvas;
  final html.CanvasRenderingContext2D ctx;
  final html.MediaRecorder mediaRecorder;
  final List<html.Blob> videoChunks;
  final Completer<void> completer;
  html.Blob? finalBlob;

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

  /// Đóng gói dữ liệu sau khi quay xong
  Future<bool> finishRecording() async {
    try {
      if (mediaRecorder.state != 'inactive') {
        mediaRecorder.stop();
      }
      await completer.future.timeout(const Duration(seconds: 4), onTimeout: () {});

      // Dọn dẹp canvas khỏi DOM sau khi quay xong
      try {
        html.document.body?.children.remove(canvas);
      } catch (_) {}

      if (videoChunks.isNotEmpty) {
        String mime = 'video/mp4';
        if (videoChunks.first.type.isNotEmpty) {
          mime = videoChunks.first.type;
        }
        finalBlob = html.Blob(videoChunks, mime);
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi hoàn tất quay: $e');
    }
    return false;
  }

  /// 1. LƯU VÀO ALBUM ẢNH (CAMERA ROLL TRÊN IPHONE)
  Future<VideoSaveResult> saveToPhotos(String filename) async {
    final blob = finalBlob;
    if (blob == null || blob.size == 0) {
      return const VideoSaveResult(
        isSuccess: false,
        message: 'Chưa có dữ liệu video để lưu. Vui lòng bấm xuất lại video!',
      );
    }

    try {
      final fileMime = blob.type.isNotEmpty ? blob.type : 'video/mp4';
      final file = html.File([blob], filename, {'type': fileMime});
      final dynamic nav = html.window.navigator;

      // Gọi Web Share API chính thức của Apple trên iOS Safari
      if (nav.canShare != null && nav.canShare({'files': [file]}) == true) {
        await nav.share({
          'files': [file],
          'title': 'Video 3D Flyover Chạy Bộ',
          'text': 'Lộ trình chạy bộ 3D Flyover của tôi',
        });
        return const VideoSaveResult(
          isSuccess: true,
          message: '👉 Trên bảng chia sẻ vừa hiện, hãy bấm "Lưu video" để lưu vào Thư viện Ảnh nhé!',
        );
      } else {
        // Fallback: Mở tab video riêng của Safari để chạm giữ "Lưu vào Ảnh"
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        return const VideoSaveResult(
          isSuccess: true,
          message: '🎬 Đã mở video! Bạn chạm giữ vào video 1 giây rồi chọn "Lưu vào Ảnh".',
        );
      }
    } catch (e) {
      debugPrint('Lỗi lưu vào ảnh: $e');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      return const VideoSaveResult(
        isSuccess: true,
        message: '🎬 Đã mở video! Chạm giữ vào video và chọn "Lưu vào Ảnh".',
      );
    }
  }

  /// 2. TẢI VÀO THƯ MỤC TỆP (FILES / DOWNLOADS)
  Future<VideoSaveResult> downloadToFiles(String filename) async {
    final blob = finalBlob;
    if (blob == null || blob.size == 0) {
      return const VideoSaveResult(
        isSuccess: false,
        message: 'Chưa có dữ liệu video để tải. Vui lòng xuất lại video!',
      );
    }

    try {
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);

      return const VideoSaveResult(
        isSuccess: true,
        message: '📁 Đã tải video vào thư mục Tệp (Downloads) của iPhone!',
      );
    } catch (e) {
      return VideoSaveResult(isSuccess: false, message: 'Lỗi tải tệp: $e');
    }
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  final canvas = html.CanvasElement(width: width, height: height);

  // QUAN TRỌNG CHO IOS SAFARI: Canvas PHẢI nằm trong DOM tree để WebKit Render Thread kích hoạt captureStream
  canvas.style.position = 'fixed';
  canvas.style.left = '-9999px';
  canvas.style.top = '-9999px';
  canvas.style.opacity = '0.01';
  canvas.style.pointerEvents = 'none';
  html.document.body?.children.add(canvas);

  final ctx = canvas.context2D;
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';

  // Thu thập luồng thời gian thực
  dynamic stream;
  try {
    stream = (canvas as dynamic).captureStream(fps.toInt());
  } catch (_) {
    stream = (canvas as dynamic).captureStream();
  }

  final supportedTypes = [
    'video/mp4',
    'video/mp4;codecs=avc1',
    'video/mp4;codecs=h264',
    'video/webm;codecs=vp9',
    'video/webm;codecs=vp8',
    'video/webm',
  ];

  String mimeType = '';
  for (final type in supportedTypes) {
    if (html.MediaRecorder.isTypeSupported(type)) {
      mimeType = type;
      break;
    }
  }

  final Map<String, dynamic> recorderOptions = {};
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

  mediaRecorder.start(100); // 100ms buffer chunking tối ưu nhất cho iOS WebKit

  return RealtimeVideoSession(
    canvas: canvas,
    ctx: ctx,
    mediaRecorder: mediaRecorder,
    videoChunks: chunks,
    completer: completer,
  );
}
