import 'package:flutter/material.dart';
import '../../models/run_session.dart';
import '../../theme/app_theme.dart';

class LiveMiniMap extends StatelessWidget {
  final List<RunPoint> routePoints;
  final bool isRunning;
  final VoidCallback? onExpand;

  const LiveMiniMap({
    super.key,
    required this.routePoints,
    required this.isRunning,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning
              ? AppTheme.primaryNeon.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isRunning
                ? AppTheme.primaryNeon.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Lưới radar thể thao
            CustomPaint(
              size: Size.infinite,
              painter: _RadarGridPainter(isRunning: isRunning),
            ),

            // Lộ trình GPS thực tế
            if (routePoints.isNotEmpty)
              CustomPaint(
                size: Size.infinite,
                painter: _LiveRoutePainter(
                  points: routePoints,
                  isRunning: isRunning,
                ),
              ),

            // Chấm định vị trung tâm nếu chưa có điểm hoặc điểm đầu tiên
            if (routePoints.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 24,
                      color: isRunning
                          ? const Color(0xFF10B981)
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRunning ? 'GPS ĐANG THEO DÕI' : 'SẴN SÀNG ĐỊNH VỊ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: isRunning
                            ? const Color(0xFF10B981)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

            // Badge Trạng thái góc trên
            Positioned(
              top: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRunning ? const Color(0xFF10B981) : AppTheme.divider,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRunning ? const Color(0xFF10B981) : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isRunning ? 'RADAR LIVE GPS' : 'GPS STANDBY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isRunning ? const Color(0xFF10B981) : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final bool isRunning;

  _RadarGridPainter({required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Vòng tròn radar đồng tâm
    canvas.drawCircle(center, 25, paint);
    canvas.drawCircle(center, 50, paint);
    canvas.drawCircle(center, 80, paint);

    // Trục chữ thập
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.isRunning != isRunning;
}

class _LiveRoutePainter extends CustomPainter {
  final List<RunPoint> points;
  final bool isRunning;

  _LiveRoutePainter({required this.points, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Tính Bounding Box tọa độ để co giãn vừa vặn khung Mini Map
    double minX = points.first.x, maxX = points.first.x;
    double minY = points.first.y, maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final double spanX = (maxX - minX).abs().clamp(0.0008, 1.0);
    final double spanY = (maxY - minY).abs().clamp(0.0008, 1.0);
    final double pad = 24.0;
    final double drawW = size.width - pad * 2;
    final double drawH = size.height - pad * 2;

    Offset toScreen(RunPoint p) {
      final double normX = (p.x - minX) / spanX;
      final double normY = (p.y - minY) / spanY;
      // Invert Y for latitude to screen coordinates
      return Offset(pad + normX * drawW, pad + (1.0 - normY) * drawH);
    }

    // Vẽ vệt chạy Neon
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(toScreen(points.first).dx, toScreen(points.first).dy);
      for (int i = 1; i < points.length; i++) {
        final pt = toScreen(points[i]);
        path.lineTo(pt.dx, pt.dy);
      }

      // Vệt sáng phát quang
      final glowPaint = Paint()
        ..color = AppTheme.primaryNeon.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glowPaint);

      // Đường chính
      final linePaint = Paint()
        ..color = AppTheme.primaryNeon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }

    // Chấm xuất phát (Xanh lá)
    final startPt = toScreen(points.first);
    canvas.drawCircle(
      startPt,
      4.5,
      Paint()..color = const Color(0xFF10B981),
    );

    // Chấm vị trí hiện tại (Đầu vệt chạy)
    final currentPt = toScreen(points.last);
    canvas.drawCircle(
      currentPt,
      7.0,
      Paint()..color = AppTheme.primaryNeon.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      currentPt,
      4.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveRoutePainter oldDelegate) => true;
}
