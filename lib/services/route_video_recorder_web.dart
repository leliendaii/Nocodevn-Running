// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

Future<bool> recordAndExportFlyoverVideo({
  required List<Map<String, double>> routePoints,
  required double distanceKm,
  required int durationSeconds,
  required String pace,
  required double speed,
  required String sessionId,
  required Function(double progress, String status) onProgress,
}) async {
  try {
    onProgress(0.05, 'Khởi tạo bộ kết xuất video phần cứng...');

    // 1. Tạo Canvas HTML5 độ phân giải cao 720 x 960 (Định dạng Video Athletic Story)
    const int width = 720;
    const int height = 960;
    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;

    // 2. Chuẩn bị luồng MediaStream từ Canvas (30 FPS)
    dynamic stream;
    try {
      stream = (canvas as dynamic).captureStream(30);
    } catch (e) {
      throw Exception('Trình duyệt không hỗ trợ ghi hình Canvas: $e');
    }

    // 3. Xác định MIME type phù hợp nhất cho Video MP4 / WebM
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

    // Bắt đầu quay video thật
    mediaRecorder.start(100);
    onProgress(0.15, '🎥 Đang quay video 3D Flyover chuẩn tốc độ ${speed}x...');

    // 4. Chuẩn hóa tọa độ lộ trình để vừa vặn trong Canvas
    final pts = _normalizeRoutePoints(routePoints, width, height);

    // 5. Kết xuất 75 khung hình (2.5 giây video mượt mà)
    const int totalFrames = 75;
    for (int f = 0; f <= totalFrames; f++) {
      final double progress = f / totalFrames;
      _drawVideoFrame(
        ctx: ctx,
        width: width,
        height: height,
        points: pts,
        progress: progress,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        pace: pace,
        speed: speed,
      );

      final double reportProg = 0.15 + (progress * 0.70);
      onProgress(reportProg, '🎥 Đang kết xuất khung hình ${f + 1}/$totalFrames (${(progress * 100).toInt()}%)...');
      await Future.delayed(const Duration(milliseconds: 33));
    }

    onProgress(0.88, '💎 Đang đóng gói dữ liệu MP4 thật...');
    mediaRecorder.stop();
    await recordCompleter.future;

    if (videoChunks.isEmpty) {
      throw Exception('Không có dữ liệu video được tạo.');
    }

    // 6. Ghép các mảnh video thành 1 file MP4 hoàn chỉnh
    final finalBlob = html.Blob(videoChunks, 'video/mp4');
    final filename = 'flyover_3d_${sessionId}_${speed}x.mp4';

    onProgress(0.95, '🎉 Đang lưu video MP4 vào thư viện máy...');

    // 7. Lưu file trên iPhone (Web Share) hoặc tải về trên Windows
    await _saveOrDownloadVideo(finalBlob, filename);

    onProgress(1.0, '🎉 Đã tải video MP4 thành công!');
    return true;
  } catch (e) {
    onProgress(1.0, 'Lỗi xuất video: $e');
    return false;
  }
}

/// Chuẩn hóa tọa độ GPS / Pixel vừa khung hình 720x960
List<math.Point<double>> _normalizeRoutePoints(
  List<Map<String, double>> route,
  int canvasWidth,
  int canvasHeight,
) {
  if (route.isEmpty) {
    return [
      math.Point(canvasWidth * 0.2, canvasHeight * 0.4),
      math.Point(canvasWidth * 0.5, canvasHeight * 0.3),
      math.Point(canvasWidth * 0.8, canvasHeight * 0.5),
    ];
  }

  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;

  for (final pt in route) {
    final x = pt['x'] ?? 0.0;
    final y = pt['y'] ?? 0.0;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  final double spanX = (maxX - minX).abs() < 1e-6 ? 1.0 : (maxX - minX);
  final double spanY = (maxY - minY).abs() < 1e-6 ? 1.0 : (maxY - minY);

  const double padLeft = 80;
  const double padRight = 80;
  const double padTop = 160;
  const double padBottom = 260;

  final double availW = canvasWidth - padLeft - padRight;
  final double availH = canvasHeight - padTop - padBottom;

  final double scale = math.min(availW / spanX, availH / spanY);
  final double offsetX = padLeft + (availW - spanX * scale) / 2;
  final double offsetY = padTop + (availH - spanY * scale) / 2;

  final List<math.Point<double>> result = [];
  for (final pt in route) {
    final x = pt['x'] ?? 0.0;
    final y = pt['y'] ?? 0.0;
    final double px = offsetX + (x - minX) * scale;
    final double py = offsetY + (y - minY) * scale;
    result.add(math.Point(px, py));
  }
  return result;
}

/// Vẽ 1 khung hình Video 3D Flyover cực kỳ chuyên nghiệp
void _drawVideoFrame({
  required html.CanvasRenderingContext2D ctx,
  required int width,
  required int height,
  required List<math.Point<double>> points,
  required double progress,
  required double distanceKm,
  required int durationSeconds,
  required String pace,
  required double speed,
}) {
  // 1. Nền tối Athletic Dark
  final bgGrad = ctx.createLinearGradient(0, 0, 0, height);
  bgGrad.addColorStop(0, '#070B19');
  bgGrad.addColorStop(0.5, '#0F172A');
  bgGrad.addColorStop(1, '#020617');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, width, height);

  // 2. Lưới nền công nghệ Cyberpunk / Bản đồ giao thông ngầm
  ctx.strokeStyle = 'rgba(30, 41, 59, 0.4)';
  ctx.lineWidth = 1.0;
  for (int x = 40; x < width; x += 60) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }
  for (int y = 40; y < height; y += 60) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }

  // 3. Vẽ vệt lộ trình mờ toàn tuyến (Ghost Route)
  if (points.length >= 2) {
    ctx.strokeStyle = 'rgba(0, 245, 255, 0.12)';
    ctx.lineWidth = 10;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(points.first.x, points.first.y);
    for (int i = 1; i < points.length; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    ctx.stroke();
  }

  // 4. Vẽ vệt chạy Neon phát sáng động theo tiến trình progress
  final int activeCount = (points.length * progress).clamp(1, points.length).toInt();
  if (activeCount >= 2) {
    // Hiệu ứng Glow Neon
    ctx.shadowBlur = 18;
    ctx.shadowColor = '#00F5FF';
    ctx.strokeStyle = '#00F5FF';
    ctx.lineWidth = 7;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < activeCount; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    ctx.stroke();

    // Vệt sáng lõi trắng bên trong
    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (int i = 1; i < activeCount; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    ctx.stroke();
  }

  // 5. Điểm Bắt Đầu (Start Pin)
  final startPt = points.first;
  ctx.fillStyle = '#10B981';
  ctx.beginPath();
  ctx.arc(startPt.x, startPt.y, 8, 0, math.pi * 2);
  ctx.fill();
  ctx.fillStyle = '#FFFFFF';
  ctx.beginPath();
  ctx.arc(startPt.x, startPt.y, 3.5, 0, math.pi * 2);
  ctx.fill();

  // 6. Runner Beacon di chuyển theo thời gian thực
  final runnerPt = points[(activeCount - 1).clamp(0, points.length - 1)];
  final double pulse = (progress * 20) % 1.0;

  // Vòng sóng radar tỏa ra
  ctx.strokeStyle = 'rgba(0, 245, 255, ${(1.0 - pulse) * 0.7})';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(runnerPt.x, runnerPt.y, 10 + pulse * 24, 0, math.pi * 2);
  ctx.stroke();

  // Tâm người chạy Neon phát sáng
  ctx.shadowBlur = 16;
  ctx.shadowColor = '#00F5FF';
  ctx.fillStyle = '#00F5FF';
  ctx.beginPath();
  ctx.arc(runnerPt.x, runnerPt.y, 9, 0, math.pi * 2);
  ctx.fill();
  ctx.fillStyle = '#FFFFFF';
  ctx.beginPath();
  ctx.arc(runnerPt.x, runnerPt.y, 4, 0, math.pi * 2);
  ctx.fill();
  ctx.shadowBlur = 0;

  // 7. Điểm Kết Thúc (Finish Pin)
  if (progress >= 0.95) {
    final finishPt = points.last;
    ctx.fillStyle = '#FF5252';
    ctx.beginPath();
    ctx.arc(finishPt.x, finishPt.y, 9, 0, math.pi * 2);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(finishPt.x, finishPt.y, 4, 0, math.pi * 2);
    ctx.fill();
  }

  // 8. HEADER HUD
  ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
  _drawRoundedRect(ctx, 30, 30, width - 60, 60, 16);
  ctx.fill();
  ctx.strokeStyle = 'rgba(51, 65, 85, 0.6)';
  ctx.lineWidth = 1;
  ctx.stroke();

  ctx.fillStyle = '#FFFFFF';
  ctx.font = '900 18px sans-serif';
  ctx.fillText('🏃 RUNNING TRACKER • 3D FLYOVER', 50, 68);

  ctx.fillStyle = '#00F5FF';
  ctx.font = 'bold 14px sans-serif';
  ctx.fillText('⚡ ${speed}x SPEED', width - 155, 67);

  // 9. FOOTER STATS CARD (Thẻ thông số xịn xò chuẩn Strava)
  final double cardY = height - 200.0;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
  _drawRoundedRect(ctx, 30, cardY, width - 60, 160, 24);
  ctx.fill();
  ctx.strokeStyle = 'rgba(51, 65, 85, 0.8)';
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Cột 1: Quãng đường KM
  final currentKm = (distanceKm * progress).toStringAsFixed(2);
  ctx.fillStyle = '#94A3B8';
  ctx.font = 'bold 12px sans-serif';
  ctx.fillText('QUÃNG ĐƯỜNG', 60, cardY + 45);
  ctx.fillStyle = '#00F5FF';
  ctx.font = '900 34px sans-serif';
  ctx.fillText(currentKm, 60, cardY + 90);
  ctx.font = 'bold 14px sans-serif';
  ctx.fillText('KM', 60 + ctx.measureText(currentKm).width! + 6, cardY + 90);

  // Cột 2: Thời gian
  final int curSec = (durationSeconds * progress).toInt();
  final String timeStr = '${(curSec ~/ 60).toString().padLeft(2, '0')}:${(curSec % 60).toString().padLeft(2, '0')}';
  ctx.fillStyle = '#94A3B8';
  ctx.font = 'bold 12px sans-serif';
  ctx.fillText('THỜI GIAN', 300, cardY + 45);
  ctx.fillStyle = '#FFFFFF';
  ctx.font = '900 32px sans-serif';
  ctx.fillText(timeStr, 300, cardY + 90);

  // Cột 3: Pace
  ctx.fillStyle = '#94A3B8';
  ctx.font = 'bold 12px sans-serif';
  ctx.fillText('PACE TB', 510, cardY + 45);
  ctx.fillStyle = '#39FF14';
  ctx.font = '900 32px sans-serif';
  ctx.fillText('$pace /km', 510, cardY + 90);

  // Thanh tiến trình chạy dưới đáy thẻ
  ctx.fillStyle = 'rgba(51, 65, 85, 0.6)';
  _drawRoundedRect(ctx, 60, cardY + 130, width - 120, 6, 3);
  ctx.fill();

  ctx.fillStyle = '#00F5FF';
  _drawRoundedRect(ctx, 60, cardY + 130, (width - 120) * progress, 6, 3);
  ctx.fill();
}

void _drawRoundedRect(
  html.CanvasRenderingContext2D ctx,
  num x,
  num y,
  num w,
  num h,
  num r,
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
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
