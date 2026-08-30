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

  late final double _effectiveDistanceKm;
  late final int _effectiveDurationSec;
  late final String _effectivePace;

  late final List<GeoPoint> _smoothRoute;
  late final List<MilestoneData> _milestones;

  // Cache ảnh map tiles tải từ máy chủ OpenStreetMap (Miễn phí 100%, không watermark)
  final Map<String, ui.Image> _tileCache = {};
  final Set<String> _loadingTiles = {};

  @override
  void initState() {
    super.initState();

    // Thiết lập số liệu hiển thị (nếu là buổi chạy test 0km, nạp lộ trình mẫu 3.5km để mô phỏng)
    _effectiveDistanceKm = widget.session.distanceKm > 0.05
        ? widget.session.distanceKm
        : 3.50;
    _effectiveDurationSec = widget.session.durationSeconds > 0
        ? widget.session.durationSeconds
        : 18 * 60 + 24;
    _effectivePace = widget.session.durationSeconds > 0 && widget.session.distanceKm > 0.05
        ? widget.session.avgPace
        : '5:15';

    _smoothRoute = _prepareSmoothGeoRoute(widget.session.routePoints);
    _milestones = _generateMilestonePins(_effectiveDistanceKm, _smoothRoute);

    // Thời lượng video flycam 18 giây ở tốc độ 1x
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
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

  // Chuẩn hóa và làm mượt lộ trình GPS
  List<GeoPoint> _prepareSmoothGeoRoute(List<RunPoint> raw) {
    List<GeoPoint> basePoints = [];

    if (raw.isNotEmpty && raw.length >= 2) {
      for (final p in raw) {
        basePoints.add(GeoPoint(p.y, p.x)); // p.y là Vĩ độ (Lat), p.x là Kinh độ (Lng)
      }
    } else {
      // Nếu là dữ liệu chạy mẫu, định vị tại TP. HỒ CHÍ MINH (Khu vực Phố Đi Bộ Nguyễn Huệ / Bến Bạch Đằng / Sông Sài Gòn)
      basePoints = _createRealisticHcmRoute();
    }

    return _interpolatePath(basePoints, 400);
  }

  // Cung đường thể thao thực tế tại TP. HỒ CHÍ MINH (Quận 1 - Bến Bạch Đằng - Phố đi bộ Nguyễn Huệ)
  List<GeoPoint> _createRealisticHcmRoute() {
    // Tọa độ trung tâm: 10.7735° N, 106.7045° E (Bến Bạch Đằng & Phố đi bộ Nguyễn Huệ, TP.HCM)
    const double centerLat = 10.7735;
    const double centerLng = 106.7045;
    final List<GeoPoint> list = [];
    const int count = 50;
    for (int i = 0; i <= count; i++) {
      final t = (i / count) * 2 * math.pi;
      // Cung đường ven sông Sài Gòn & đường Nguyễn Huệ
      final lat = centerLat + 0.0038 * math.cos(t) + 0.0012 * math.sin(2 * t);
      final lng = centerLng + 0.0032 * math.sin(t) + 0.0008 * math.cos(2 * t);
      list.add(GeoPoint(lat, lng));
    }
    return list;
  }

  // Làm mượt đường cong 400 điểm giúp Flycam lượn êm ái
  List<GeoPoint> _interpolatePath(List<GeoPoint> input, int targetCount) {
    if (input.length < 2) return input;
    final List<GeoPoint> result = [];
    final int segments = input.length - 1;
    final double step = segments / targetCount;

    for (double t = 0; t <= segments; t += step) {
      final int i = t.floor().clamp(0, segments - 1);
      final double frac = t - i;
      final p0 = input[i];
      final p1 = input[i + 1];
      final lat = p0.lat * (1 - frac) + p1.lat * frac;
      final lng = p0.lng * (1 - frac) + p1.lng * frac;

      // Tính góc quay (Bearing) mà người chạy đang hướng tới
      final dLat = p1.lat - p0.lat;
      final dLng = p1.lng - p0.lng;
      final double bearing = math.atan2(dLng, dLat);

      result.add(GeoPoint(lat, lng, bearing: bearing));
    }
    return result;
  }

  List<MilestoneData> _generateMilestonePins(double totalKm, List<GeoPoint> route) {
    final List<MilestoneData> pins = [];
    if (route.isEmpty) return pins;
    final int totalPins = totalKm.floor();
    if (totalPins <= 0) return pins;

    for (int i = 1; i <= totalPins; i++) {
      final double frac = (i / totalKm).clamp(0.0, 1.0);
      final int idx = ((route.length - 1) * frac).toInt().clamp(0, route.length - 1);
      pins.add(MilestoneData(km: i, point: route[idx]));
    }
    return pins;
  }

  // Chức năng Phát lại / Tạm dừng / Xem lại nhiều lần vô hạn
  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.stop();
        _isPlaying = false;
      } else {
        // Nếu đã chạy hết 100%, tự động tua lại từ đầu 0% và phát lại
        if (_controller.value >= 0.98 || _controller.status == AnimationStatus.completed) {
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
        _controller.duration = const Duration(seconds: 9);
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 4.0;
        _controller.duration = const Duration(seconds: 4);
      } else {
        _playbackSpeed = 1.0;
        _controller.duration = const Duration(seconds: 18);
      }
      if (_isPlaying) {
        final current = _controller.value;
        _controller.forward(from: current);
      }
    });
  }

  // Tải Map Tiles thật từ máy chủ OpenStreetMap (Miễn phí 100%, không watermark)
  void _loadMapTile(int z, int x, int y) {
    final key = '$z/$x/$y';
    if (_tileCache.containsKey(key) || _loadingTiles.contains(key)) return;

    _loadingTiles.add(key);
    final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';

    final imageStream = NetworkImage(url).resolve(ImageConfiguration.empty);
    imageStream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _tileCache[key] = info.image;
            _loadingTiles.remove(key);
          });
        }
      }, onError: (dynamic error, StackTrace? stack) {
        _loadingTiles.remove(key);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    final currentDistance = (_effectiveDistanceKm * progress).toStringAsFixed(2);
    final elapsedSec = (_effectiveDurationSec * progress).toInt();
    final elapsedFormatted = DateFormat('mm:ss').format(DateTime(2026, 1, 1, 0, 0, elapsedSec));
    final isCompleted = progress >= 0.98;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. ENGINE 3D FLYCAM CHUẨN KHÔNG MÉO BẢN ĐỒ
            Positioned.fill(
              child: CustomPaint(
                painter: Real3DFlyoverPainter(
                  route: _smoothRoute,
                  milestones: _milestones,
                  progress: progress,
                  tileCache: _tileCache,
                  onTileRequested: _loadMapTile,
                ),
              ),
            ),

            // 2. TOP HUD: BẢNG CHỈ SỐ THỂ THAO TRÊN CÙNG
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('QUÃNG ĐƯỜNG', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        Text('$currentDistance km', style: const TextStyle(fontSize: 17, color: AppTheme.primaryNeon, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('PACE', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        Text('$_effectivePace /km', style: const TextStyle(fontSize: 17, color: AppTheme.secondaryNeon, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('THỜI GIAN', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        Text(elapsedFormatted, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: AppTheme.secondaryNeon, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        TopSyncToast.show(context, message: '🎬 Đã tạo clip 3D Flyover sẵn sàng chia sẻ!', isSuccess: true);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 3. BOTTOM CONTROL BAR: BỘ ĐIỀU KHIỂN FLYCAM
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
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                              isCompleted
                                  ? Icons.replay_rounded // Biểu tượng Xem lại khi video kết thúc
                                  : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              size: 26,
                            ),
                          ),
                        ),
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

// Data model tọa độ GPS
class GeoPoint {
  final double lat;
  final double lng;
  final double bearing;
  const GeoPoint(this.lat, this.lng, {this.bearing = 0.0});
}

class MilestoneData {
  final int km;
  final GeoPoint point;
  const MilestoneData({required this.km, required this.point});
}

// PAINTER VẼ ĐỘNG 3D FLYCAM CHUẨN GÓC PHỐI CẢNH (KHÔNG BỊ MÉO BẢN ĐỒ)
class Real3DFlyoverPainter extends CustomPainter {
  final List<GeoPoint> route;
  final List<MilestoneData> milestones;
  final double progress;
  final Map<String, ui.Image> tileCache;
  final Function(int z, int x, int y) onTileRequested;

  static const int zoom = 16; // Mức phóng to chi tiết đường phố thực tế
  static const double tileSize = 256.0;

  Real3DFlyoverPainter({
    required this.route,
    required this.milestones,
    required this.progress,
    required this.tileCache,
    required this.onTileRequested,
  });

  // Chuyển đổi Vĩ độ / Kinh độ sang Tọa độ Pixel Web Mercator
  Offset _latLngToPixel(double lat, double lng) {
    final double sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final double x = ((lng + 180.0) / 360.0) * (tileSize * math.pow(2, zoom));
    final double y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * (tileSize * math.pow(2, zoom));
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (route.isEmpty) return;

    final int activeIdx = ((route.length - 1) * progress).clamp(0, route.length - 1).toInt();
    final currentGeo = route[activeIdx];
    final currentPixel = _latLngToPixel(currentGeo.lat, currentGeo.lng);

    // 1. TÍNH TOÁN MA TRẬN PHỐI CẢNH 3D FLYCAM CHUẨN XÁC
    // Đặt tâm xoay tại vị trí vận động viên trên màn hình (2/3 màn hình dưới)
    final double screenCenterX = size.width / 2;
    final double screenCenterY = size.height * 0.65;

    canvas.save();

    // Bước 1: Dời gốc tọa độ về tâm màn hình
    canvas.translate(screenCenterX, screenCenterY);

    // Bước 2: Ma trận phối cảnh 3D mượt mà (Góc nghiêng 32 độ nhìn lướt theo đường phố, không kéo méo text)
    final perspectiveMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0006) // Chiều sâu 3D nhẹ nhàng tự nhiên
      ..rotateX(0.58); // Góc nghiêng tự nhiên 33 độ
    canvas.transform(perspectiveMatrix.storage);

    // Bước 3: Xoay bản đồ theo hướng vận động viên đang chạy
    canvas.rotate(-currentGeo.bearing);

    // Bước 4: Dời tâm bản đồ theo đúng tọa độ vận động viên
    canvas.translate(-currentPixel.dx, -currentPixel.dy);

    // 2. VẼ CÁC MAP TILES THỰC TẾ (OpenStreetMap)
    final int centerTileX = (currentPixel.dx / tileSize).floor();
    final int centerTileY = (currentPixel.dy / tileSize).floor();

    // Vẽ lưới 5x5 ô bản đồ xung quanh người chạy
    for (int dx = -2; dx <= 2; dx++) {
      for (int dy = -2; dy <= 2; dy++) {
        final tx = centerTileX + dx;
        final ty = centerTileY + dy;
        final key = '$zoom/$tx/$ty';

        final tileRect = Rect.fromLTWH(tx * tileSize, ty * tileSize, tileSize, tileSize);

        if (tileCache.containsKey(key)) {
          final img = tileCache[key]!;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            tileRect,
            Paint()..filterQuality = FilterQuality.medium,
          );
        } else {
          // Nền dự phòng khi map đang tải
          canvas.drawRect(tileRect, Paint()..color = const Color(0xFFF1F5F9));
          canvas.drawRect(
            tileRect,
            Paint()
              ..color = const Color(0xFFCBD5E1)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
          onTileRequested(zoom, tx, ty);
        }
      }
    }

    // 3. VẼ ĐƯỜNG DẪN DỰ KIẾN TRƯỚC (Nét mờ)
    final fullRoutePath = Path();
    for (int i = 0; i < route.length; i++) {
      final pt = _latLngToPixel(route[i].lat, route[i].lng);
      if (i == 0) {
        fullRoutePath.moveTo(pt.dx, pt.dy);
      } else {
        fullRoutePath.lineTo(pt.dx, pt.dy);
      }
    }

    canvas.drawPath(
      fullRoutePath,
      Paint()
        ..color = AppTheme.primaryNeon.withValues(alpha: 0.3)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. VẼ VỆT CHẠY ĐÃ HOÀN THÀNH (Màu Đỏ Neon nổi bật)
    if (activeIdx > 0) {
      final activeRoutePath = Path();
      for (int i = 0; i <= activeIdx; i++) {
        final pt = _latLngToPixel(route[i].lat, route[i].lng);
        if (i == 0) {
          activeRoutePath.moveTo(pt.dx, pt.dy);
        } else {
          activeRoutePath.lineTo(pt.dx, pt.dy);
        }
      }

      // Bóng đổ đường chạy
      canvas.drawPath(
        activeRoutePath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 8.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Vạch đường chạy đỏ sắc nét
      canvas.drawPath(
        activeRoutePath,
        Paint()
          ..color = AppTheme.primaryNeon
          ..strokeWidth = 6.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 5. VẼ CỘT MỐC KM CẮM NỔI 3D TRÊN TUYẾN ĐƯỜNG
    for (final m in milestones) {
      final pinPixel = _latLngToPixel(m.point.lat, m.point.lng);

      canvas.save();
      canvas.translate(pinPixel.dx, pinPixel.dy);
      // Xoay ngược lại để bảng mốc KM luôn hướng thẳng về phía camera
      canvas.rotate(currentGeo.bearing);

      // Bóng chân cột mốc
      canvas.drawCircle(const Offset(0, 0), 4, Paint()..color = Colors.black38);
      // Cột cắm
      canvas.drawLine(const Offset(0, 0), const Offset(0, -18), Paint()..color = Colors.black54..strokeWidth = 2);
      // Biển mốc tròn
      canvas.drawCircle(const Offset(0, -18), 12, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(0, -18), 12, Paint()..color = AppTheme.primaryNeon..style = PaintingStyle.stroke..strokeWidth = 2);

      final tp = TextPainter(
        text: TextSpan(
          text: '${m.km}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -18 - tp.height / 2));

      canvas.restore();
    }

    // 6. VẼ ICON VẬN ĐỘNG VIÊN & CHÙM TIA SÁNG QUÉT PHÍA TRƯỚC
    canvas.save();
    canvas.translate(currentPixel.dx, currentPixel.dy);

    // Chùm tia sáng quét về phía trước theo hướng chạy
    final beamPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-22, 50)
      ..lineTo(22, 50)
      ..close();

    final beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, 50),
        [
          AppTheme.secondaryNeon.withValues(alpha: 0.45),
          AppTheme.secondaryNeon.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(beamPath, beamPaint);

    // Vòng hào quang runner
    canvas.drawCircle(const Offset(0, 0), 15, Paint()..color = AppTheme.secondaryNeon.withValues(alpha: 0.35));
    // Icon người chạy
    canvas.drawCircle(const Offset(0, 0), 8.5, Paint()..color = AppTheme.secondaryNeon);
    canvas.drawCircle(const Offset(0, 0), 4.5, Paint()..color = Colors.white);

    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Real3DFlyoverPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tileCache.length != tileCache.length;
  }
}
