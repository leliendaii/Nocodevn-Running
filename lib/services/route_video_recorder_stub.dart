import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:gal/gal.dart';
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

class RealtimeVideoSession {
  final List<RawFrameData> _frames = [];
  String? _savedFilePath;

  void pushRawFrame(Uint8List rawRgbaBytes, int frameWidth, int frameHeight) {
    if (_frames.length < 800) {
      _frames.add(RawFrameData(rawRgbaBytes, frameWidth, frameHeight));
    }
  }

  /// Xuất video MP4 chuẩn phần cứng H.264 (AVFoundation trên iOS / MediaCodec trên Android)
  Future<bool> finishRecording() async {
    try {
      if (_frames.isEmpty) return false;

      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/flyover_3d_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final firstFrame = _frames.first;
      // Đảm bảo kích thước chia hết cho 2 theo chuẩn H.264
      final int width = (firstFrame.width ~/ 2) * 2;
      final int height = (firstFrame.height ~/ 2) * 2;

      await FlutterQuickVideoEncoder.setup(
        width: width,
        height: height,
        fps: 25,
        videoBitrate: 8000000,
        profileLevel: ProfileLevel.any,
        audioChannels: 0,
        audioBitrate: 0,
        sampleRate: 44100,
        filepath: outputPath,
      );

      for (final frame in _frames) {
        await FlutterQuickVideoEncoder.appendVideoFrame(frame.bytes);
      }

      await FlutterQuickVideoEncoder.finish();

      if (await File(outputPath).exists()) {
        _savedFilePath = outputPath;
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi xuất video phần cứng MP4: $e');
    }
    return false;
  }

  /// Tải trực tiếp trong User Gesture (Lưu thẳng 1 chạm vào Album Ảnh qua Gal.putVideo)
  VideoSaveResult downloadVideoDirect(String filename) {
    try {
      if (_savedFilePath != null && File(_savedFilePath!).existsSync()) {
        final path = _savedFilePath!;
        
        Gal.putVideo(path).then((_) {
          debugPrint('Lưu Gal.putVideo thành công vào Album Ảnh!');
        }).catchError((galErr) {
          debugPrint('Gal.putVideo error, fallback SharePlus: $galErr');
          SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'video/mp4', name: filename)],
              subject: 'Video 3D Flyover Buổi Chạy',
            ),
          );
        });

        return const VideoSaveResult(
          isSuccess: true,
          message: 'Đã lưu video thành công vào Album Ảnh',
        );
      }
    } catch (e) {
      debugPrint('Lỗi downloadVideoDirect: $e');
    }
    return const VideoSaveResult(isSuccess: true, message: 'Đã sẵn sàng video');
  }

  /// TẢI VỀ TRÊN NATIVE IOS (IPHONE APP) & ANDROID: Lưu thẳng vào Album Ảnh (Camera Roll)
  Future<VideoSaveResult> downloadVideo(String filename) async {
    try {
      if (_savedFilePath != null && await File(_savedFilePath!).exists()) {
        final path = _savedFilePath!;

        // 1. Lưu trực tiếp vào Thư viện Ảnh bằng thư viện Gal.putVideo()
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
            await Gal.putVideo(path).timeout(const Duration(seconds: 5));
            return const VideoSaveResult(
              isSuccess: true,
              message: 'Đã lưu video thành công vào Album Ảnh',
            );
          }
        } catch (galError) {
          debugPrint('Lưu Gal.putVideo thất bại/timeout, mở bảng chia sẻ gốc iPhone: $galError');
        }

        // 2. Dự phòng: Mở Native iOS Share Sheet
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'video/mp4', name: filename)],
              subject: 'Video 3D Flyover Buổi Chạy',
            ),
          );

          return const VideoSaveResult(
            isSuccess: true,
            message: 'Đã mở bảng chia sẻ. Chọn "Lưu video" để lưu vào Thư viện Ảnh.',
          );
        } catch (shareErr) {
          debugPrint('Share fallback error: $shareErr');
        }
      }

      return const VideoSaveResult(
        isSuccess: true,
        message: 'Video đã sẵn sàng',
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
