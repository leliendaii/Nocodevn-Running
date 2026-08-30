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
      mediaRecorder.stop();
      await completer.future;

      if (videoChunks.isNotEmpty) {
        String mime = 'video/mp4';
        if (videoChunks.first.type.isNotEmpty) {
          mime = videoChunks.first.type;
        }
        finalBlob = html.Blob(videoChunks, mime);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Kích hoạt lưu vào Thư viện Ảnh (iPhone Web Share) hoặc tải về máy
  Future<VideoSaveResult> saveOrShare(String filename) async {
    final blob = finalBlob;
    if (blob == null) {
      return const VideoSaveResult(isSuccess: false, message: 'Chưa có dữ liệu video để lưu.');
    }
    return await _saveOrDownloadVideo(blob, filename);
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

  final supportedTypes = [
    'video/mp4;codecs=avc1',
    'video/mp4;codecs=h264',
    'video/mp4',
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

Future<VideoSaveResult> _saveOrDownloadVideo(html.Blob videoBlob, String filename) async {
  try {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
    final fileMime = videoBlob.type.isNotEmpty ? videoBlob.type : 'video/mp4';

    // 1. Trên iOS: Thử Web Share API để lưu trực tiếp vào Thư viện Ảnh (Camera Roll)
    if (isIOS) {
      try {
        final file = html.File([videoBlob], filename, {'type': fileMime});
        final dynamic nav = html.window.navigator;
        if (nav.canShare != null && nav.canShare({'files': [file]}) == true) {
          await nav.share({
            'files': [file],
            'title': 'Video 3D Flyover Chạy Bộ',
            'text': 'Lộ trình chạy bộ 3D Flyover của tôi',
          });
          return const VideoSaveResult(
            isSuccess: true,
            message: '🎉 Đã mở bảng chia sẻ! Hãy chọn "Lưu video" vào Thư viện Ảnh.',
          );
        }
      } catch (e) {
        debugPrint('iOS Web Share không thể mở trực tiếp: $e');
      }
    }

    // 2. Tải file tự động trực tiếp về máy
    final url = html.Url.createObjectUrlFromBlob(videoBlob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    // 3. Nếu trên iOS Safari, mở tab video riêng biệt để người dùng chạm giữ "Lưu video"
    if (isIOS) {
      html.window.open(url, '_blank');
      return const VideoSaveResult(
        isSuccess: true,
        message: '🎬 Đã mở video! Chạm giữ vào video và chọn "Lưu video" vào Ảnh.',
      );
    }

    return const VideoSaveResult(
      isSuccess: true,
      message: '🎉 Đã tải video MP4 thành công!',
    );
  } catch (e) {
    debugPrint('Lỗi tải video: $e');
    return VideoSaveResult(
      isSuccess: false,
      message: 'Lỗi khi lưu video: $e',
    );
  }
}
