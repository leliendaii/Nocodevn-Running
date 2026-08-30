// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> recordAndExportExactFlyoverVideo({
  required Future<Uint8List?> Function(double t) frameProvider,
  required int totalFrames,
  required double speed,
  required String sessionId,
  required Function(double progress, String status) onProgress,
}) async {
  try {
    onProgress(0.05, 'Khởi tạo bộ quay video 3D màn hình thực tế...');

    // 1. Lấy khung hình mẫu đầu tiên để xác định độ phân giải chính xác của màn hình
    final firstFrameBytes = await frameProvider(0.0);
    if (firstFrameBytes == null || firstFrameBytes.isEmpty) {
      throw Exception('Không thể chụp khung hình 3D.');
    }

    final firstBlob = html.Blob([firstFrameBytes], 'image/png');
    final firstUrl = html.Url.createObjectUrlFromBlob(firstBlob);
    final sampleImg = html.ImageElement(src: firstUrl);
    await sampleImg.onLoad.first;
    final int width = sampleImg.naturalWidth > 0 ? sampleImg.naturalWidth : 720;
    final int height = sampleImg.naturalHeight > 0 ? sampleImg.naturalHeight : 1280;
    html.Url.revokeObjectUrl(firstUrl);

    // 2. Tạo Canvas HTML5 khớp 100% kích thước màn hình 3D Flyover
    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImage(sampleImg, 0, 0);

    // 3. Chuẩn bị luồng MediaStream từ Canvas (30 FPS)
    dynamic stream;
    try {
      stream = (canvas as dynamic).captureStream(30);
    } catch (e) {
      throw Exception('Trình duyệt không hỗ trợ ghi hình Canvas: $e');
    }

    // 4. Chọn MIME type tương thích cao nhất cho MP4 / WebM
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

    final mediaRecorder = mimeType.isNotEmpty
        ? html.MediaRecorder(stream, {'mimeType': mimeType})
        : html.MediaRecorder(stream);

    final List<html.Blob> videoChunks = [];
    final Completer<void> recordCompleter = Completer<void>();

    mediaRecorder.addEventListener('dataavailable', (event) {
      final blob = (event as dynamic).data as html.Blob?;
      if (blob != null && blob.size > 0) {
        videoChunks.add(blob);
      }
    });

    mediaRecorder.addEventListener('stop', (_) {
      if (!recordCompleter.isCompleted) {
        recordCompleter.complete();
      }
    });

    mediaRecorder.start(100);
    onProgress(0.12, '🎥 Đang quay video 3D Flyover chính xác 100% từ màn hình...');

    // 5. Chụp và ghi từng khung hình 3D thực tế (bao gồm Google Maps, góc nghiêng 3D, vệt Neon, Runner Beacon và HUD)
    for (int f = 0; f <= totalFrames; f++) {
      final double t = f / totalFrames;
      final frameBytes = await frameProvider(t);

      if (frameBytes != null && frameBytes.isNotEmpty) {
        final blob = html.Blob([frameBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final img = html.ImageElement(src: url);
        await img.onLoad.first;
        ctx.clearRect(0, 0, width, height);
        ctx.drawImage(img, 0, 0);
        html.Url.revokeObjectUrl(url);
      }

      final double reportProg = 0.12 + (t * 0.76);
      onProgress(reportProg, '🎥 Đang ghi hình 3D khung hình ${f + 1}/$totalFrames (${(t * 100).toInt()}%)...');
    }

    onProgress(0.90, '💎 Đang đóng gói dữ liệu video MP4...');
    mediaRecorder.stop();
    await recordCompleter.future;

    if (videoChunks.isEmpty) {
      throw Exception('Không có dữ liệu video được tạo.');
    }

    // 6. Ghép thành file MP4 và kích hoạt lưu/tải
    final finalBlob = html.Blob(videoChunks, 'video/mp4');
    final filename = 'flyover_3d_${sessionId}_${speed}x.mp4';

    onProgress(0.96, '🎉 Đang lưu video vào thư viện thiết bị...');
    await _saveOrDownloadVideo(finalBlob, filename);

    onProgress(1.0, '🎉 Đã tải video MP4 3D Flyover thành công!');
    return true;
  } catch (e) {
    onProgress(1.0, 'Lỗi xuất video: $e');
    return false;
  }
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
        'text': 'Lộ trình chạy bộ 3D Flyover siêu đẹp của tôi',
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
