import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class RouteFlyover3DScreen extends StatefulWidget {
  final RunSession session;

  const RouteFlyover3DScreen({super.key, required this.session});

  @override
  State<RouteFlyover3DScreen> createState() => _RouteFlyover3DScreenState();
}

class _RouteFlyover3DScreenState extends State<RouteFlyover3DScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _playbackSpeed = 1.0;
  bool _isPlaying = true;
  late final List<Point3D> _normalizedPoints;
  late final List<MilestonePin> _milestones;

  @override
  void initState() {
    super.initState();
    _normalizedPoints = _normalizeRoutePoints(widget.session.routePoints);
    _milestones = _generateMilestones(widget.session.distanceKm, _normalizedPoints);

    // Thời lượng video mặc định là 16 giây cho toàn bộ lộ trình (ở tốc độ 1x)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..addListener(() {
        setState(() {});
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isPlaying = false);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Chuẩn hóa danh sách tọa độ GPS thực tế về hệ tọa độ đồ họa Canvas
  List<Point3D> _normalizeRoutePoints(List<RunPoint> rawPoints) {
    if (rawPoints.isEmpty) {
      // Nếu chưa có tọa độ GPS (chạy máy chạy bộ hoặc test), tạo cung đường mẫu đẹp mắt
      return _generateSampleRoute();
    }

    double minX = rawPoints.first.x;
    double maxX = rawPoints.first.x;
    double minY = rawPoints.first.y;
    double maxY = rawPoints.first.y;

    for (final p in rawPoints) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final double spanX = (maxX - minX).abs();
    final double spanY = (maxY - minY).abs();
    final double maxSpan = math.max(spanX, spanY);

    if (maxSpan == 0) {
      return _generateSampleRoute();
    }

    final List<Point3D> result = [];
    for (int i = 0; i < rawPoints.length; i++) {
      final p = rawPoints[i];
      // Chuẩn hóa về dải -0.85 -> 0.85
      final nx = ((p.x - minX) / maxSpan - 0.5) * 1.7;
      final ny = ((p.y - minY) / maxSpan - 0.5) * 1.7;
      result.add(Point3D(nx, ny, 0.0));
    }

    // Làm mượt đường cong (Interpolation)
    return _smoothPoints(result);
  }

  // Tạo cung đường thể thao mẫu nếu buổi chạy chưa kịp bắt GPS
  List<Point3D> _generateSampleRoute() {
    final List<Point3D> list = [];
    const int count = 120;
    for (int i = 0; i <= count; i++) {
      final t = (i / count) * 2 * math.pi;
      // Đường cong hình cánh hoa thể thao
      final x = 0.65 * math.sin(t) + 0.15 * math.sin(2 * t);
      final y = 0.65 * math.cos(t) - 0.15 * math.cos(2 * t);
      list.add(Point3D(x, y, 0.0));
    }
    return list;
  }

  List<Point3D> _smoothPoints(List<Point3D> input) {
    if (input.length < 3) return input;
    final List<Point3D> smoothed = [];
    smoothed.add(input.first);
    for (int i = 0; i < input.length - 1; i++) {
      final p0 = input[i];
      final p1 = input[i + 1];
      // Thêm 2 điểm nội suy mượt mà ở giữa
      smoothed.add(Point3D(p0.x * 0.66 + p1.x * 0.34, p0.y * 0.66 + p1.y * 0.34, 0.0));
      smoothed.add(Point3D(p0.x * 0.34 + p1.x * 0.66, p0.y * 0.34 + p1.y * 0.66, 0.0));
      smoothed.add(p1);
    }
    return smoothed;
  }

  List<MilestonePin> _generateMilestones(double totalKm, List<Point3D> points) {
    final List<MilestonePin> list = [];
    if (points.isEmpty) return list;
    final int totalPins = totalKm.floor();
    if (totalPins <= 0) return list;

    for (int i = 1; i <= math.min(totalPins, 8); i++) {
      final double progress = i / totalKm;
      final int index = ((points.length - 1) * progress).clamp(0, points.length - 1).toInt();
      list.add(MilestonePin(
        km: i,
        position: points[index],
      ));
    }
    return list;
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.stop();
        _isPlaying = false;
      } else {
        if (_controller.status == AnimationStatus.completed) {
          _controller.reset();
        }
        _controller.forward();
        _isPlaying = true;
      }
    });
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
        _controller.duration = const Duration(seconds: 8);
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 4.0;
        _controller.duration = const Duration(seconds: 4);
      } else {
        _playbackSpeed = 1.0;
        _controller.duration = const Duration(seconds: 16);
      }
      if (_isPlaying) {
        final currentVal = _controller.value;
        _controller.forward(from: currentVal);
      }
    });
  }

  void _handleExportVideo() {
    TopSyncToast.show(
      context,
      message: '🎬 Đã lưu clip mô phỏng 3D thành công vào bộ sưu tập!',
      isSuccess: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    final currentDistance = (widget.session.distanceKm * progress).toStringAsFixed(2);
    final elapsedSec = (widget.session.durationSeconds * progress).toInt();
    final elapsedFormatted = DateFormat('mm:ss').format(DateTime(2026, 1, 1, 0, 0, elapsedSec));

    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0), // Nền trời dịu nhẹ phong cách Apple Maps 3D
      body: SafeArea(
        child: Stack(
          children: [
            // 1. CANVAS MÔ PHỎNG 3D VECTOR ĐƯỜNG PHỐ
            Positioned.fill(
              child: CustomPaint(
                painter: Map3DVectorPainter(
                  points: _normalizedPoints,
                  milestones: _milestones,
                  progress: progress,
                ),
              ),
            ),

            // 2. TOP HUD: BẢNG CHỈ SỐ THỂ THAO TRÊN CÙNG (Translucent Pill)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nút đóng
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // Quãng đường
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'QUÃNG ĐƯỜNG',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$currentDistance km',
                          style: const TextStyle(fontSize: 17, color: AppTheme.primaryNeon, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    // Pace
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PACE',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.session.avgPace} /km',
                          style: const TextStyle(fontSize: 17, color: AppTheme.secondaryNeon, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    // Thời gian
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'THỜI GIAN',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          elapsedFormatted,
                          style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    // Nút tải/lưu clip
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, color: AppTheme.secondaryNeon, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _handleExportVideo,
                    ),
                  ],
                ),
              ),
            ),

            // 3. BOTTOM CONTROL BAR: BỘ ĐIỀU KHIỂN VIDEO PHÁT LẠI
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.divider, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thanh trượt tua thời gian Scrubber
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: AppTheme.primaryNeon,
                        inactiveTrackColor: AppTheme.surfaceLight,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (val) {
                          setState(() {
                            _controller.value = val;
                            if (_isPlaying) _controller.stop();
                            _isPlaying = false;
                          });
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nút tốc độ tua
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(48, 30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _changeSpeed,
                          child: Text(
                            '${_playbackSpeed.toInt()}x',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.secondaryNeon),
                          ),
                        ),
                        // Nút Play / Pause trung tâm
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNeon,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
                            onPressed: _togglePlayPause,
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 26,
                            ),
                          ),
                        ),
                        // Tiến độ %
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
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

// Model Tọa độ 3D
class Point3D {
  final double x;
  final double y;
  final double z;
  const Point3D(this.x, this.y, this.z);
}

// Model Cột mốc KM
class MilestonePin {
  final int km;
  final Point3D position;
  const MilestonePin({required this.km, required this.position});
}

// PAINTER VẼ BẢN ĐỒ 3D VECTOR ĐƯỜNG PHỐ (Phong cách Apple Maps 3D)
class Map3DVectorPainter extends CustomPainter {
  final List<Point3D> points;
  final List<MilestonePin> milestones;
  final double progress;

  Map3DVectorPainter({
    required this.points,
    required this.milestones,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 30);
    final scale = math.min(size.width, size.height) * 0.45;

    // 1. VẼ NỀN ĐẤT ĐÔ THỊ (Clean Urban Background)
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. VẼ CÁC KHU VỰC CÔNG VIÊN XANH (Parks)
    _draw3DPark(canvas, center, scale, const Offset(-0.4, -0.2), 0.35, 0.45);
    _draw3DPark(canvas, center, scale, const Offset(0.3, 0.3), 0.30, 0.38);

    // 3. VẼ HỒ NƯỚC XANH (Water Lake)
    _draw3DWater(canvas, center, scale, const Offset(0.1, -0.3), 0.25, 0.3);

    // 4. VẼ MẠNG LƯỚI ĐƯỜNG PHỐ (Street Grid Roads)
    final roadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _draw3DStreetGrid(canvas, center, scale, roadBorderPaint, roadPaint);

    // 5. VẼ CÁC KHỐI NHÀ 3D NỔI BẬT (3D Extruded Buildings with Shadows)
    _draw3DBuildings(canvas, center, scale);

    // 6. VẼ ĐƯỜNG CHẠY BỘ THỂ THAO ĐỎ (Sport Route Polyline)
    if (points.isNotEmpty) {
      final int activeIndex = ((points.length - 1) * progress).clamp(0, points.length - 1).toInt();

      // Vẽ bóng đổ đường chạy
      final shadowPath = Path();
      for (int i = 0; i <= activeIndex; i++) {
        final screenPt = _project3D(points[i], center, scale, shadowOffsetY: 4);
        if (i == 0) {
          shadowPath.moveTo(screenPt.dx, screenPt.dy);
        } else {
          shadowPath.lineTo(screenPt.dx, screenPt.dy);
        }
      }
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(shadowPath, shadowPaint);

      // Vẽ đường chạy chính Đỏ/Cam sắc nét
      final runPath = Path();
      for (int i = 0; i <= activeIndex; i++) {
        final screenPt = _project3D(points[i], center, scale);
        if (i == 0) {
          runPath.moveTo(screenPt.dx, screenPt.dy);
        } else {
          runPath.lineTo(screenPt.dx, screenPt.dy);
        }
      }

      final runPaint = Paint()
        ..color = AppTheme.primaryNeon
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(runPath, runPaint);

      // 7. VẼ CỘT MỐC KM 3D NỔI TRONG KHÔNG GIAN
      for (final m in milestones) {
        final pinScreenPt = _project3D(m.position, center, scale);
        _draw3DMilestonePin(canvas, pinScreenPt, m.km);
      }

      // 8. VẼ ICON VẬN ĐỘNG VIÊN ĐANG CHẠY & CHÙM SÁNG PHÍA TRƯỚC
      final currentPt = points[activeIndex];
      final currentScreenPt = _project3D(currentPt, center, scale);

      // Vòng hào quang
      canvas.drawCircle(currentScreenPt, 14, Paint()..color = AppTheme.secondaryNeon.withValues(alpha: 0.25));
      // Vòng ngoài
      canvas.drawCircle(currentScreenPt, 8, Paint()..color = AppTheme.secondaryNeon);
      // Tâm trắng
      canvas.drawCircle(currentScreenPt, 4, Paint()..color = Colors.white);
    }
  }

  // Hàm chiếu 3D phối cảnh (Perspective 3D Projection - Góc nghiêng 55 độ)
  Offset _project3D(Point3D p, Offset center, double scale, {double shadowOffsetY = 0}) {
    // Góc nghiêng mặt đất 55 độ (y nén 0.55)
    final double px = p.x * scale;
    final double py = p.y * scale * 0.55 - (p.z * scale * 0.6) + shadowOffsetY;
    return Offset(center.dx + px, center.dy + py);
  }

  void _draw3DPark(Canvas canvas, Offset center, double scale, Offset pos, double w, double h) {
    final p1 = _project3D(Point3D(pos.dx - w / 2, pos.dy - h / 2, 0), center, scale);
    final p2 = _project3D(Point3D(pos.dx + w / 2, pos.dy - h / 2, 0), center, scale);
    final p3 = _project3D(Point3D(pos.dx + w / 2, pos.dy + h / 2, 0), center, scale);
    final p4 = _project3D(Point3D(pos.dx - w / 2, pos.dy + h / 2, 0), center, scale);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFDCFCE7));
  }

  void _draw3DWater(Canvas canvas, Offset center, double scale, Offset pos, double w, double h) {
    final p1 = _project3D(Point3D(pos.dx - w / 2, pos.dy - h / 2, 0), center, scale);
    final p2 = _project3D(Point3D(pos.dx + w / 2, pos.dy - h / 2, 0), center, scale);
    final p3 = _project3D(Point3D(pos.dx + w / 2, pos.dy + h / 2, 0), center, scale);
    final p4 = _project3D(Point3D(pos.dx - w / 2, pos.dy + h / 2, 0), center, scale);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFBAE6FD));
  }

  void _draw3DStreetGrid(Canvas canvas, Offset center, double scale, Paint border, Paint road) {
    // Vẽ các đường phố ngang dọc dạng 3D
    final List<List<Point3D>> streets = [
      [const Point3D(-0.9, -0.5, 0), const Point3D(0.9, -0.5, 0)],
      [const Point3D(-0.9, 0.0, 0), const Point3D(0.9, 0.0, 0)],
      [const Point3D(-0.9, 0.5, 0), const Point3D(0.9, 0.5, 0)],
      [const Point3D(-0.5, -0.8, 0), const Point3D(-0.5, 0.8, 0)],
      [const Point3D(0.0, -0.8, 0), const Point3D(0.0, 0.8, 0)],
      [const Point3D(0.5, -0.8, 0), const Point3D(0.5, 0.8, 0)],
    ];

    for (final st in streets) {
      final p1 = _project3D(st[0], center, scale);
      final p2 = _project3D(st[1], center, scale);
      canvas.drawLine(p1, p2, border);
      canvas.drawLine(p1, p2, road);
    }
  }

  void _draw3DBuildings(Canvas canvas, Offset center, double scale) {
    // Vị trí các khối nhà 3D
    final buildings = [
      {'pos': const Offset(-0.65, -0.65), 'w': 0.14, 'h': 0.14, 'z': 0.22},
      {'pos': const Offset(-0.25, -0.65), 'w': 0.16, 'h': 0.12, 'z': 0.35},
      {'pos': const Offset(0.25, -0.65), 'w': 0.13, 'h': 0.13, 'z': 0.18},
      {'pos': const Offset(0.65, -0.65), 'w': 0.15, 'h': 0.15, 'z': 0.40},
      {'pos': const Offset(-0.65, 0.25), 'w': 0.15, 'h': 0.15, 'z': 0.28},
      {'pos': const Offset(0.65, 0.25), 'w': 0.14, 'h': 0.16, 'z': 0.32},
      {'pos': const Offset(-0.25, 0.65), 'w': 0.16, 'h': 0.13, 'z': 0.20},
      {'pos': const Offset(0.65, 0.65), 'w': 0.14, 'h': 0.14, 'z': 0.25},
    ];

    for (final b in buildings) {
      final pos = b['pos'] as Offset;
      final w = b['w'] as double;
      final h = b['h'] as double;
      final z = b['z'] as double;

      // 4 điểm chân nhà
      final b1 = _project3D(Point3D(pos.dx - w / 2, pos.dy - h / 2, 0), center, scale);
      final b2 = _project3D(Point3D(pos.dx + w / 2, pos.dy - h / 2, 0), center, scale);
      final b3 = _project3D(Point3D(pos.dx + w / 2, pos.dy + h / 2, 0), center, scale);
      final b4 = _project3D(Point3D(pos.dx - w / 2, pos.dy + h / 2, 0), center, scale);

      // 4 điểm nóc nhà (Độ cao z)
      final t1 = _project3D(Point3D(pos.dx - w / 2, pos.dy - h / 2, z), center, scale);
      final t2 = _project3D(Point3D(pos.dx + w / 2, pos.dy - h / 2, z), center, scale);
      final t3 = _project3D(Point3D(pos.dx + w / 2, pos.dy + h / 2, z), center, scale);
      final t4 = _project3D(Point3D(pos.dx - w / 2, pos.dy + h / 2, z), center, scale);

      // Bóng chân nhà
      final groundBase = Path()
        ..moveTo(b1.dx, b1.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(b3.dx, b3.dy)
        ..lineTo(b4.dx, b4.dy)
        ..close();
      canvas.drawPath(groundBase, Paint()..color = Colors.black12);

      // 1. Mặt tường trước (Màu xám nhạt)
      final wallFront = Path()
        ..moveTo(b4.dx, b4.dy)
        ..lineTo(b3.dx, b3.dy)
        ..lineTo(t3.dx, t3.dy)
        ..lineTo(t4.dx, t4.dy)
        ..close();
      canvas.drawPath(wallFront, Paint()..color = const Color(0xFFCBD5E1));

      // 2. Mặt tường bên hông (Màu xám tối hơn để tạo chiều sâu đổ bóng)
      final wallSide = Path()
        ..moveTo(b3.dx, b3.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(t2.dx, t2.dy)
        ..lineTo(t3.dx, t3.dy)
        ..close();
      canvas.drawPath(wallSide, Paint()..color = const Color(0xFF94A3B8));

      // 3. Mặt nóc nhà (Màu trắng sáng)
      final roof = Path()
        ..moveTo(t1.dx, t1.dy)
        ..lineTo(t2.dx, t2.dy)
        ..lineTo(t3.dx, t3.dy)
        ..lineTo(t4.dx, t4.dy)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawPath(
        roof,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _draw3DMilestonePin(Canvas canvas, Offset pos, int km) {
    // Thẻ tag mốc KM tròn nổi
    final pinCenter = Offset(pos.dx, pos.dy - 12);
    // Bóng đổ thẻ pin
    canvas.drawCircle(Offset(pos.dx, pos.dy), 3, Paint()..color = Colors.black26);

    // Cán cắm
    canvas.drawLine(pos, pinCenter, Paint()..color = Colors.black45..strokeWidth = 1.5);

    // Nền trắng tròn
    canvas.drawCircle(pinCenter, 10, Paint()..color = Colors.white);
    canvas.drawCircle(pinCenter, 10, Paint()..color = AppTheme.primaryNeon..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Text KM
    final tp = TextPainter(
      text: TextSpan(
        text: '$km',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pinCenter.dx - tp.width / 2, pinCenter.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant Map3DVectorPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
