import 'package:flutter/material.dart';
import '../../models/run_session.dart';
import '../../theme/app_theme.dart';

/// Khối Lộ Trình GPS Neon Art
class MapRouteBlock extends StatelessWidget {
  final List<RunPoint> routePoints;

  const MapRouteBlock({
    super.key,
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.length < 2) return const SizedBox.shrink();

    return SizedBox(
      width: 240,
      height: 200,
      child: CustomPaint(
        painter: GpsRouteOverlayPainter(routePoints),
      ),
    );
  }
}

/// Khối Thông Số Đáy Dạng Thẻ Bo Tròn Của Bản Đồ
class MapStatsBlock extends StatelessWidget {
  final RunSession session;
  final bool showDistance;
  final bool showDuration;
  final bool showPace;
  final bool showCalories;

  const MapStatsBlock({
    super.key,
    required this.session,
    required this.showDistance,
    required this.showDuration,
    required this.showPace,
    required this.showCalories,
  });

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[];
    if (showDistance) {
      stats.add(_buildCompactStat('${session.distanceKm.toStringAsFixed(2)} KM', 'Quãng đường', AppTheme.primaryNeon));
    }
    if (showDuration) {
      stats.add(_buildCompactStat(session.formattedDuration, 'Thời gian', Colors.white));
    }
    if (showPace) {
      stats.add(_buildCompactStat(session.formattedPace, 'Pace TB', AppTheme.secondaryNeon));
    }
    if (showCalories) {
      stats.add(_buildCompactStat('${session.calories}', 'Calo', AppTheme.accentOrange));
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            stats[i],
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter vẽ đường chạy GPS Neon Art trên ảnh
class GpsRouteOverlayPainter extends CustomPainter {
  final List<RunPoint> routePoints;

  GpsRouteOverlayPainter(this.routePoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    double minX = routePoints.first.x;
    double maxX = routePoints.first.x;
    double minY = routePoints.first.y;
    double maxY = routePoints.first.y;

    for (final p in routePoints) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final double rangeX = (maxX - minX == 0) ? 0.0001 : maxX - minX;
    final double rangeY = (maxY - minY == 0) ? 0.0001 : maxY - minY;

    final double padding = size.width * 0.1;
    final double drawW = size.width - padding * 2;
    final double drawH = size.height - padding * 2;

    final path = Path();
    for (int i = 0; i < routePoints.length; i++) {
      final p = routePoints[i];
      final double dx = padding + ((p.x - minX) / rangeX) * drawW;
      final double dy = padding + (1.0 - ((p.y - minY) / rangeY)) * drawH;

      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    // Vẽ bóng phát sáng neon (Glow effect)
    final glowPaint = Paint()
      ..color = AppTheme.secondaryNeon.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawPath(path, glowPaint);

    // Vẽ đường line chính phát sáng rực rỡ
    final linePaint = Paint()
      ..color = AppTheme.secondaryNeon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Vẽ điểm bắt đầu (Xanh lá) & Kết thúc (Đỏ neon)
    final startPt = Offset(
      padding + ((routePoints.first.x - minX) / rangeX) * drawW,
      padding + (1.0 - ((routePoints.first.y - minY) / rangeY)) * drawH,
    );
    final endPt = Offset(
      padding + ((routePoints.last.x - minX) / rangeX) * drawW,
      padding + (1.0 - ((routePoints.last.y - minY) / rangeY)) * drawH,
    );

    final startPaint = Paint()..color = const Color(0xFF00E676);
    final endPaint = Paint()..color = AppTheme.primaryNeon;

    canvas.drawCircle(startPt, 5, startPaint);
    canvas.drawCircle(startPt, 2.5, Paint()..color = Colors.white);

    canvas.drawCircle(endPt, 5, endPaint);
    canvas.drawCircle(endPt, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant GpsRouteOverlayPainter oldDelegate) {
    return oldDelegate.routePoints != routePoints;
  }
}
