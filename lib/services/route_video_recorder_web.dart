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
  Future<VideoSaveResult> downloadVideo(String filename) async {
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

      // Xác định đúng đuôi file tương thích
      String finalName = filename;
      if (fileMime.contains('webm') && finalName.endsWith('.mp4')) {
        finalName = finalName.replaceAll('.mp4', '.webm');
      }

      // 1. Trên iOS: Web Share API trực tiếp mở bảng iOS để người dùng bấm "Lưu video" vào Album Ảnh
      if (isIOS) {
        try {
          final file = html.File([blob], finalName, {'type': fileMime});
          final dynamic nav = html.window.navigator;
          if (nav.canShare != null && nav.canShare({'files': [file]}) == true) {
            await nav.share({
              'files': [file],
              'title': 'Video 3D Flyover',
            });
            return const VideoSaveResult(
              isSuccess: true,
              message: '🎉 Đã mở bảng chia sẻ iPhone! Hãy chọn "Lưu video" để lưu vào Thư viện Ảnh.',
            );
          }
        } catch (shareErr) {
          debugPrint('iOS Share error: $shareErr');
        }
      }

      final url = html.Url.createObjectUrlFromBlob(blob);

      // 1. Trên iOS: Web Share API trực tiếp mở bảng iOS để người dùng bấm "Lưu video" vào Album Ảnh
      if (isIOS) {
        try {
          final file = html.File([blob], finalName, {'type': fileMime});
          final dynamic nav = html.window.navigator;
          if (nav.canShare != null && nav.canShare({'files': [file]}) == true) {
            await nav.share({
              'files': [file],
              'title': 'Video 3D Flyover',
            });
            return const VideoSaveResult(
              isSuccess: true,
              message: '🎉 Đã mở bảng chia sẻ iPhone! Hãy chọn "Lưu video" để lưu vào Thư viện Ảnh.',
            );
          }
        } catch (shareErr) {
          debugPrint('iOS Share error: $shareErr');
        }

        // Trên iOS: Tự động mở video trực tiếp trong tab mới để xem và bấm Lưu vào Ảnh
        try {
          html.window.open(url, '_blank');
        } catch (_) {
          html.window.location.href = url;
        }

        return const VideoSaveResult(
          isSuccess: true,
          message: '🎉 Đã mở video! Nhấn vào biểu tượng Chia sẻ [↑] ➔ chọn "Lưu video" để lưu vào Album Ảnh nhé!',
        );
      }

      // 2. Kích hoạt tải file trực tiếp về máy (Android & PC)
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', finalName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);

      return const VideoSaveResult(
        isSuccess: true,
        message: '🎉 Đã tải video thành công về thiết bị!',
      );
    } catch (e) {
      return VideoSaveResult(isSuccess: false, message: 'Lỗi tải video: $e');
    }
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
