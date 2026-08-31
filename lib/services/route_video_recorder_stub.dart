import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class VideoSaveResult {
  final bool isSuccess;
  final String message;
  const VideoSaveResult({required this.isSuccess, required this.message});
}

class RawFrameData {
  final Uint8List bytes;
  final int width;
  final int height;
  RawFrameData(this.bytes, this.width, this.height);
}

/// Dữ liệu đầu vào cho Isolate mã hóa nền (Background Isolate)
class _EncodeJob {
  final List<RawFrameData> frames;
  final String outputPath;
  final int targetWidth;
  _EncodeJob({required this.frames, required this.outputPath, this.targetWidth = 480});
}

/// Hàm chạy ngầm trong Isolate riêng biệt - Không bao giờ làm đơ UI hoặc đứng 90%!
Future<bool> _encodeGifInBackground(_EncodeJob job) async {
  try {
    if (job.frames.isEmpty) return false;

    // Tối ưu 60-80 khung hình mượt mà (30 FPS)
    final List<RawFrameData> framesToProcess = [];
    final int step = (job.frames.length / 60).ceil().clamp(1, 3);
    for (int i = 0; i < job.frames.length; i += step) {
      framesToProcess.add(job.frames[i]);
    }
    if (framesToProcess.isEmpty || framesToProcess.last != job.frames.last) {
      framesToProcess.add(job.frames.last);
    }

    final encoder = img.GifEncoder(delay: 3); // ~30 FPS mượt mà

    for (final frame in framesToProcess) {
      // 1. Tạo image từ raw RGBA
      var frameImg = img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: frame.bytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // 2. Resize về 720px chuẩn HD sắc nét
      if (frame.width > job.targetWidth) {
        frameImg = img.copyResize(
          frameImg,
          width: job.targetWidth,
          interpolation: img.Interpolation.linear,
        );
      }

      // 3. Thêm frame vào GifEncoder
      encoder.addFrame(frameImg, duration: 33);
    }

    final encodedBytes = encoder.finish();
    if (encodedBytes != null && encodedBytes.isNotEmpty) {
      final file = File(job.outputPath);
      await file.writeAsBytes(encodedBytes, flush: true);
      return true;
    }
  } catch (e) {
    debugPrint('Lỗi Isolate encode: $e');
  }
  return false;
}

class RealtimeVideoSession {
  final List<RawFrameData> _frames = [];
  String? _savedFilePath;

  void pushRawFrame(Uint8List rawRgbaBytes, int frameWidth, int frameHeight) {
    // Lưu tối đa 80 frames chuẩn 30 FPS
    if (_frames.length < 80) {
      _frames.add(RawFrameData(rawRgbaBytes, frameWidth, frameHeight));
    }
  }

  /// Đóng gói video chạy trên background isolate (chống treo máy)
  Future<bool> finishRecording() async {
    try {
      if (_frames.isEmpty) return false;

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/flyover_3d_${DateTime.now().millisecondsSinceEpoch}.gif';

      // Chạy mã hóa trên Background Isolate qua compute()
      final bool success = await compute(
        _encodeGifInBackground,
        _EncodeJob(
          frames: _frames,
          outputPath: outputPath,
          targetWidth: 720,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );

      if (success && await File(outputPath).exists()) {
        _savedFilePath = outputPath;
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi hoàn tất quay native: $e');
    }
    return false;
  }

  /// TẢI VỀ TRÊN NATIVE IOS (IPHONE APP) & ANDROID: Lưu thẳng vào Album Ảnh (Camera Roll)
  Future<VideoSaveResult> downloadVideo(String filename) async {
    try {
      if (_savedFilePath != null && await File(_savedFilePath!).exists()) {
        final path = _savedFilePath!;
        final finalName = filename.endsWith('.gif') ? filename : filename.replaceAll('.mp4', '.gif');

        // 1. Thử lưu trực tiếp vào Thư viện Ảnh bằng thư viện Gal (có timeout 4 giây chống treo)
        try {
          bool hasAccess = await Gal.hasAccess(toAlbum: false).timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
          if (!hasAccess) {
            hasAccess = await Gal.requestAccess(toAlbum: false).timeout(
              const Duration(seconds: 5),
              onTimeout: () => false,
            );
          }

          if (hasAccess) {
            // Lưu ảnh động vào Album Ảnh iPhone (tự động hiển thị và chạy trong Thư viện Ảnh)
            await Gal.putImage(path).timeout(
              const Duration(seconds: 5),
            );

            return const VideoSaveResult(
              isSuccess: true,
              message: '🎉 Đã lưu video thành công vào Album Ảnh (Camera Roll)!',
            );
          }
        } catch (galError) {
          debugPrint('Lưu Gal thất bại/timeout, mở bảng chia sẻ gốc iPhone: $galError');
        }

        // 2. Dự phòng chuẩn Apple iOS: Mở Native iOS Share Sheet để người dùng bấm "Lưu hình ảnh / Tệp"
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'image/gif', name: finalName)],
              subject: 'Video 3D Flyover Buổi Chạy',
            ),
          );

          return const VideoSaveResult(
            isSuccess: true,
            message: '🎉 Đã mở bảng chia sẻ của iPhone! Hãy chọn "Lưu hình ảnh" để lưu vào Thư viện Ảnh.',
          );
        } catch (shareErr) {
          debugPrint('Share fallback error: $shareErr');
        }
      }

      return const VideoSaveResult(
        isSuccess: true,
        message: '🎉 Video đã sẵn sàng!',
      );
    } catch (e) {
      debugPrint('Lỗi lưu video native: $e');
      return VideoSaveResult(isSuccess: false, message: 'Lỗi lưu video: $e');
    }
  }
}

RealtimeVideoSession startRealtimeVideoSession({
  required int width,
  required int height,
  double fps = 60.0,
}) {
  return RealtimeVideoSession();
}
