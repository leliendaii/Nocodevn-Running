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

  /// Đẩy khung hình raw GPU (RGBA) trực tiếp vào Canvas
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

  /// TẢI VỀ: Tự động lưu vào Album Ảnh (trên iPhone) hoặc Tải file về máy
  /// Gọi đồng bộ trực tiếp trong User Gesture (Đảm bảo 100% mở Share Sheet trên iPhone Safari)
  VideoSaveResult downloadVideoDirect(String filename) {
    final blob = finalBlob;
    if (blob == null || blob.size == 0) {
      return const VideoSaveResult(
        isSuccess: false,
        message: 'Chưa có dữ liệu video. Hãy thử bấm xuất lại!',
      );
    }

    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
      final fileMime = blob.type.isNotEmpty ? blob.type : 'video/mp4';

      String finalName = filename;
      if (fileMime.contains('webm') && finalName.endsWith('.mp4')) {
        finalName = finalName.replaceAll('.mp4', '.webm');
      }

      final file = html.File([blob], finalName, {'type': fileMime});
      final dynamic nav = html.window.navigator;

      // 1. TRÊN IPHONE (iOS SAFARI): Web Share API được gọi TRỰC TIẾP và ĐỒNG BỘ trong click handler
      if (isIOS && nav.canShare != null && nav.canShare({'files': [file]}) == true) {
        nav.share({
          'files': [file],
          'title': 'Lộ trình chạy 3D Flyover',
        }).catchError((err) {
          debugPrint('iOS Share error: $err');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.window.open(url, '_blank');
        });

        return const VideoSaveResult(
          isSuccess: true,
          message: 'Đã mở bảng chia sẻ. Chọn "Lưu video" để lưu vào Thư viện Ảnh.',
        );
      }

      // 2. Mở trực tiếp video / Tải file
      final url = html.Url.createObjectUrlFromBlob(blob);
      if (isIOS) {
        try {
          html.window.open(url, '_blank');
        } catch (_) {
          html.window.location.href = url;
        }
        return const VideoSaveResult(
          isSuccess: true,
          message: 'Đã mở video. Nhấn Chia sẻ để lưu vào Album Ảnh.',
        );
      }

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', finalName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);

      return const VideoSaveResult(
        isSuccess: true,
        message: 'Đã tải video thành công về thiết bị',
      );
    } catch (e) {
      return VideoSaveResult(isSuccess: false, message: 'Lỗi tải video: $e');
    }
  }

  Future<VideoSaveResult> downloadVideo(String filename) async {
    return downloadVideoDirect(filename);
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  final canvas = html.CanvasElement(width: width, height: height);

  // Canvas gắn vào DOM với kích thước hiển thị nhỏ để WebKit không ngắt tiến trình vẽ
  canvas.style.position = 'fixed';
  canvas.style.right = '0px';
  canvas.style.bottom = '0px';
  canvas.style.width = '2px';
  canvas.style.height = '2px';
  canvas.style.opacity = '0.9';
  canvas.style.zIndex = '-999';
  canvas.style.pointerEvents = 'none';
  html.document.body?.children.add(canvas);

  final ctx = canvas.context2D;
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';

  dynamic stream;
  try {
    stream = (canvas as dynamic).captureStream(fps.toInt());
  } catch (_) {
    stream = (canvas as dynamic).captureStream();
  }

  final supportedTypes = [
    'video/mp4;codecs=avc1.42E01E,mp4a.40.2',
    'video/mp4;codecs=avc1',
    'video/mp4;codecs=h264',
    'video/mp4',
    'video/webm;codecs=h264',
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
  recorderOptions['videoBitsPerSecond'] = 8000000; // 8 Mbps HD siêu sắc nét

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

  mediaRecorder.start(100);

  return RealtimeVideoSession(
    canvas: canvas,
    ctx: ctx,
    mediaRecorder: mediaRecorder,
    videoChunks: chunks,
    completer: completer,
  );
}
