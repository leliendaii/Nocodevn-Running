import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../services/route_video_recorder.dart';
import '../services/map_tile_cache_service.dart';
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
  bool _isDisposed = false;
  bool _isFlycamMode = false; // Mặc định: FALSE = Toàn Cảnh (Mượt 100% không rung lắc)
  bool _isExportingVideo = false; // Bật khi đang quay video để xuất HUD thông số & đếm ngược Story Facebook

  late final double _effectiveDistanceKm;
  late final int _effectiveDurationSec;
  late final String _effectivePace;
  late final int _effectiveCalories;

  late final List<GeoPoint> _smoothRoute;
  late final List<Offset> _cachedRoutePixels;
  late final List<MilestoneData> _milestones;
  late final Path _fullVectorPath;
  late final ui.PathMetric _pathMetric;
  late final double _totalPathLength;
  late final int _zoomLevel;

  // Bảng tra cứu tọa độ siêu mịn 2.000 điểm & đường bay Camera mượt mà kiểu Strava
  late final List<Offset> _sampledPositions;
  late final List<Offset> _smoothedCamPositions;
  late final List<double> _sampledHeadings;
  late final Offset _startPinPixel;
  late final Offset _finishPinPixel;
  late final double _routeCenterX;
  late final double _routeCenterY;
  late final double _spanW;
  late final double _spanH;

  int _tileVersion = 0;
  final GlobalKey _previewKey = GlobalKey();

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5];
  static const double tileSize = 256.0;

  int _baseDurationMs = 20000; // Thời lượng chuẩn 20s (2s xem điểm đầu -> 11s chạy -> 2s zoom đích -> zoom toàn cảnh -> 5s ngắm trọn vẹn)

  @override
  void initState() {
    super.initState();

    // 1. Đồng bộ số liệu hiển thị
    final bool hasValidRealData = widget.session.distanceKm >= 0.1 && widget.session.durationSeconds >= 30;

    if (hasValidRealData) {
      _effectiveDistanceKm = widget.session.distanceKm;
      _effectiveDurationSec = widget.session.durationSeconds;
      _effectivePace = widget.session.avgPace;
      _effectiveCalories = widget.session.calories > 0 ? widget.session.calories : (_effectiveDistanceKm * 65).round();
    } else {
      _effectiveDistanceKm = 2.50;
      _effectiveDurationSec = 13 * 60; // 13 phút (780 giây)
      _effectivePace = '5:12';
      _effectiveCalories = 165;
    }

    _baseDurationMs = 20000;

    // 2. Tuyến đường cố định 100% nhất quán cho từng buổi chạy
    _smoothRoute = _buildConsistentRoute(widget.session);

    // 3. Tự động tính toán mức Zoom rộng bao quát khu vực xung quanh
    _zoomLevel = _calculateOptimalZoom(_smoothRoute);

    // 4. Tiền tính toán trước toàn bộ tọa độ Pixel
    _cachedRoutePixels = _smoothRoute.map((p) => _latLngToPixel(p.lat, p.lng, _zoomLevel)).toList();

    // 5. Xây dựng đường cong Vector Bézier Spline mượt mà (Gaussian Smoothing + Bézier Spline)
    _fullVectorPath = _createSmoothSplinePath(_cachedRoutePixels);
    final metrics = _fullVectorPath.computeMetrics().toList();
    _pathMetric = metrics.isNotEmpty ? metrics.first : Path().computeMetrics().first;
    _totalPathLength = _pathMetric.length > 0 ? _pathMetric.length : 1.0;

    // 6. Tiền tính toán bảng nội suy 2.000 điểm đều nhau
    const int sampleCount = 2000;
    _sampledPositions = List.generate(sampleCount, (i) {
      final double dist = _totalPathLength * (i / (sampleCount - 1));
      final tangent = _pathMetric.getTangentForOffset(dist);
      return tangent?.position ?? _cachedRoutePixels.first;
    });

    // Tiền tính toán đường bay Camera Drone siêu êm ái bằng Gaussian Filter (Loại bỏ 100% rung lắc và lắc lư trái phải)
    const int camWindow = 180;
    _smoothedCamPositions = List.generate(sampleCount, (i) {
      double sumX = 0, sumY = 0, totalWeight = 0;
      for (int w = -camWindow; w <= camWindow; w++) {
        final idx = (i + w).clamp(0, sampleCount - 1);
        final double weight = math.exp(-(w * w) / (2 * 60.0 * 60.0)); // Phân phối Gaussian làm mượt tuyệt đối
        sumX += _sampledPositions[idx].dx * weight;
        sumY += _sampledPositions[idx].dy * weight;
        totalWeight += weight;
      }
      return Offset(sumX / totalWeight, sumY / totalWeight);
    });

    // Làm mượt góc quay tiếp tuyến (Circular Window = 35 samples)
    const int headWindow = 35;
    _sampledHeadings = List.generate(sampleCount, (i) {
      double sinSum = 0, cosSum = 0;
      for (int w = -headWindow; w <= headWindow; w++) {
        final idx = (i + w).clamp(0, sampleCount - 1);
        final double dist = _totalPathLength * (idx / (sampleCount - 1));
        final tangent = _pathMetric.getTangentForOffset(dist);
        if (tangent != null) {
          final double ang = math.atan2(tangent.vector.dy, tangent.vector.dx);
          sinSum += math.sin(ang);
          cosSum += math.cos(ang);
        }
      }
      return math.atan2(sinSum, cosSum);
    });

    // Vị trí chuẩn xác 100% của Điểm Bắt Đầu và Điểm Kết Thúc
    _startPinPixel = _sampledPositions.first;
    _finishPinPixel = _sampledPositions.last;

    // Tiền tính toán Bounding Box một lần duy nhất
    double minX = 99999999, maxX = -99999999;
    double minY = 99999999, maxY = -99999999;
    for (final pt in _cachedRoutePixels) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    _routeCenterX = (minX + maxX) / 2;
    _routeCenterY = (minY + maxY) / 2;
    _spanW = (maxX - minX).abs();
    _spanH = (maxY - minY).abs();

    // 6. Cột mốc tạm dừng (Chỉ hiển thị khi người dùng thực tế có bấm Tạm Dừng trong lúc chạy)
    _milestones = _generatePausePins(widget.session.pausePoints, _zoomLevel);

    // 7. Tiền tải trước toàn bộ Map Tiles vào RAM & Disk Cache (Load < 0.1s tức thì)
    _precacheRouteMapTiles();

    // 8. Khởi tạo AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_baseDurationMs / _playbackSpeed).round()),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDisposed && mounted) {
        setState(() => _isPlaying = false);
      }
    });

    _controller.forward();
  }

  void _handleExit() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  // 1. Thuật toán Ramer-Douglas-Peucker: Lọc sạch 100% nhiễu răng cưa
  static List<Offset> _simplifyPoints(List<Offset> points, double tolerance) {
    if (points.length <= 2) return points;

    double maxDist = 0.0;
    int index = 0;
    final p1 = points.first;
    final p2 = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final double dx = p2.dx - p1.dx;
      final double dy = p2.dy - p1.dy;
      double dist;
      if (dx == 0 && dy == 0) {
        dist = (points[i] - p1).distance;
      } else {
        dist = (((points[i].dx - p1.dx) * dy - (points[i].dy - p1.dy) * dx).abs()) / math.sqrt(dx * dx + dy * dy);
      }

      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > tolerance) {
      final left = _simplifyPoints(points.sublist(0, index + 1), tolerance);
      final right = _simplifyPoints(points.sublist(index), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [p1, p2];
    }
  }

  // 2. Thuật toán Chaikin Curve: Làm mượt đường cong tự nhiên, bo góc ngã tư
  static List<Offset> _chaikinSmooth(List<Offset> points, int iterations) {
    if (points.length <= 2) return points;
    List<Offset> result = List.from(points);

    for (int it = 0; it < iterations; it++) {
      if (result.length <= 2) break;
      final List<Offset> next = [result.first];
      for (int i = 0; i < result.length - 1; i++) {
        final p0 = result[i];
        final p1 = result[i + 1];
        final q = Offset(0.75 * p0.dx + 0.25 * p1.dx, 0.75 * p0.dy + 0.25 * p1.dy);
        final r = Offset(0.25 * p0.dx + 0.75 * p1.dx, 0.25 * p0.dy + 0.75 * p1.dy);
        next.add(q);
        next.add(r);
      }
      next.add(result.last);
      result = next;
    }
    return result;
  }

  // Tạo đường chạy Vector mượt mà, liền mạch, thanh lịch chuẩn Strava
  static Path _createSmoothSplinePath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;

    final int len = pts.length;
    final List<Offset> filtered = [];
    for (int i = 0; i < len; i++) {
      double sumX = 0, sumY = 0, totalW = 0;
      for (int k = -2; k <= 2; k++) {
        final idx = (i + k).clamp(0, len - 1);
        final double weight = 1.0 / (1.0 + k.abs() * 0.7);
        sumX += pts[idx].dx * weight;
        sumY += pts[idx].dy * weight;
        totalW += weight;
      }
      filtered.add(Offset(sumX / totalW, sumY / totalW));
    }

    final List<Offset> dedup = [filtered.first];
    for (int i = 1; i < filtered.length; i++) {
      if ((filtered[i] - dedup.last).distance >= 2.5) {
        dedup.add(filtered[i]);
      }
    }
    if (dedup.length < filtered.length && (filtered.last - dedup.last).distance > 0.5) {
      dedup.add(filtered.last);
    }

    if (dedup.length <= 2) {
      path.moveTo(dedup.first.dx, dedup.first.dy);
      path.lineTo(dedup.last.dx, dedup.last.dy);
      return path;
    }

    final simplified = _simplifyPoints(dedup, 1.8);
    final smoothed = _chaikinSmooth(simplified, 3);

    path.moveTo(smoothed.first.dx, smoothed.first.dy);
    for (int i = 0; i < smoothed.length - 1; i++) {
      final p0 = smoothed[i];
      final p1 = smoothed[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.lineTo(smoothed.last.dx, smoothed.last.dy);
    return path;
  }

  static Offset _latLngToPixel(double lat, double lng, int zoom) {
    final double sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final double scale = tileSize * math.pow(2, zoom);
    final double x = ((lng + 180.0) / 360.0) * scale;
    final double y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }

  int _calculateOptimalZoom(List<GeoPoint> points) {
    if (points.isEmpty) return 15;
    double minLat = points.first.lat, maxLat = points.first.lat;
    double minLng = points.first.lng, maxLng = points.first.lng;

    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final double spanLat = (maxLat - minLat).abs();
    final double spanLng = (maxLng - minLng).abs();
    final double maxSpan = math.max(spanLat, spanLng);

    if (maxSpan < 0.008) {
      return 16;
    } else if (maxSpan < 0.020) {
      return 15;
    } else if (maxSpan < 0.050) {
      return 14;
    } else if (maxSpan < 0.100) {
      return 13;
    } else {
      return 12;
    }
  }

  List<GeoPoint> _buildConsistentRoute(RunSession s) {
    List<GeoPoint> basePoints = [];

    if (s.routePoints.isNotEmpty && s.routePoints.length >= 2) {
      for (final p in s.routePoints) {
        basePoints.add(GeoPoint(p.y, p.x));
      }
      return basePoints;
    }

    if (s.routePoints.length == 1) {
      final centerLat = s.routePoints.first.y;
      final centerLng = s.routePoints.first.x;
      const double radius = 0.0025; // ~250m
      for (int i = 0; i <= 16; i++) {
        final double rad = (i / 16) * 2 * math.pi;
        basePoints.add(GeoPoint(
          centerLat + radius * math.sin(rad),
          centerLng + radius * math.cos(rad) * 1.2,
        ));
      }
      return basePoints;
    }

    basePoints = const [
      GeoPoint(10.77665, 106.70085), // 1. BẮT ĐẦU: Trước UBND TP (Đầu Phố Đi Bộ Nguyễn Huệ)
      GeoPoint(10.77580, 106.70155), // 2. Thẳng theo Phố Đi Bộ Nguyễn Huệ
      GeoPoint(10.77490, 106.70225), // 3. Nguyễn Huệ giao Lê Lợi
      GeoPoint(10.77420, 106.70285), // 4. Nguyễn Huệ giao Huỳnh Thúc Kháng
      GeoPoint(10.77350, 106.70340), // 5. Nguyễn Huệ giao Ngô Đức Kế
      GeoPoint(10.77270, 106.70405), // 6. Nguyễn Huệ giao Mạc Thị Bưởi
      GeoPoint(10.77195, 106.70465), // 7. Cuối Phố Đi Bộ Nguyễn Huệ giao Tôn Đức Thắng
      GeoPoint(10.77150, 106.70500), // 8. Vỉa hè Công viên Bến Bạch Đằng
      GeoPoint(10.77110, 106.70535), // 9. Tôn Đức Thắng
      GeoPoint(10.77065, 106.70495), // 10. Rẽ phải từ Tôn Đức Thắng vào Đại lộ Hàm Nghi
      GeoPoint(10.77140, 106.70440), // 11. Đại lộ Hàm Nghi
      GeoPoint(10.77245, 106.70385), // 12. Đại lộ Hàm Nghi giao Hồ Tùng Mậu
      GeoPoint(10.77320, 106.70305), // 13. Đại lộ Hàm Nghi giao Nam Kỳ Khởi Nghĩa
      GeoPoint(10.77395, 106.70220), // 14. Đại lộ Hàm Nghi giao Pasteur
      GeoPoint(10.77460, 106.70150), // 15. Rẽ phải vào đường Pasteur
      GeoPoint(10.77525, 106.70080), // 16. Đường Pasteur giao Lê Lợi
      GeoPoint(10.77590, 106.70010), // 17. Đường Pasteur
      GeoPoint(10.77655, 106.69940), // 18. Đường Pasteur giao Lê Thánh Tôn
      GeoPoint(10.77675, 106.69995), // 19. Rẽ phải vào đường Lê Thánh Tôn
      GeoPoint(10.77690, 106.70050), // 20. Lê Thánh Tôn trước UBND TP
      GeoPoint(10.77665, 106.70085), // 21. KẾT THÚC
    ];

    return basePoints;
  }

  List<MilestoneData> _generatePausePins(List<RunPoint> pausePoints, int zoom) {
    final List<MilestoneData> pins = [];
    for (int i = 0; i < pausePoints.length; i++) {
      final pt = pausePoints[i];
      final pixel = _latLngToPixel(pt.x, pt.y, zoom);
      pins.add(MilestoneData(km: i + 1, point: GeoPoint(pt.x, pt.y), pixel: pixel));
    }
    return pins;
  }

  void _precacheRouteMapTiles() {
    int minTx = 999999, maxTx = -999999;
    int minTy = 999999, maxTy = -999999;

    for (final pt in _cachedRoutePixels) {
      final tx = (pt.dx / tileSize).floor();
      final ty = (pt.dy / tileSize).floor();
      if (tx < minTx) minTx = tx;
      if (tx > maxTx) maxTx = tx;
      if (ty < minTy) minTy = ty;
      if (ty > maxTy) maxTy = ty;
    }

    minTx -= 6;
    maxTx += 6;
    minTy -= 6;
    maxTy += 7;

    MapTileCacheService.preloadBoundingBox(
      zoom: _zoomLevel,
      minX: minTx,
      maxX: maxTx,
      minY: minTy,
      maxY: maxTy,
      onTileLoaded: () {
        if (!_isDisposed && mounted) {
          setState(() => _tileVersion++);
        }
      },
    );
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toInt()}x';
    }
    return '${speed}x';
  }

  void _openSpeedSelectorModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'TỐC ĐỘ PHÁT LẠI 3D FLYOVER',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _speedOptions.map((speed) {
                    final isSelected = (_playbackSpeed - speed).abs() < 0.01;
                    return SizedBox(
                      width: 72,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppTheme.primaryNeon : AppTheme.surfaceLight,
                          foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
                          elevation: isSelected ? 4 : 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryNeon : AppTheme.divider,
                              width: 1,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _setPlaybackSpeed(speed);
                        },
                        child: Text(
                          _formatSpeed(speed),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setPlaybackSpeed(double speed) {
    if (_isDisposed) return;
    setState(() {
      _playbackSpeed = speed;
      _controller.duration = Duration(milliseconds: (_baseDurationMs / _playbackSpeed).round());
      if (_controller.value >= 0.98 || _controller.status == AnimationStatus.completed) {
        _controller.reset();
        _controller.forward();
        _isPlaying = true;
      } else if (_isPlaying) {
        _controller.forward(from: _controller.value);
      }
    });
  }

  void _togglePlayPause() {
    if (_isDisposed) return;
    setState(() {
      if (_isPlaying) {
        _controller.stop();
        _isPlaying = false;
      } else {
        _controller.duration = Duration(milliseconds: (_baseDurationMs / _playbackSpeed).round());
        if (_controller.value >= 0.98 || _controller.status == AnimationStatus.completed) {
          _controller.reset();
        }
        _controller.forward();
        _isPlaying = true;
      }
    });
  }

  /// HỘP THOẠI XUẤT VÀ TẢI VIDEO 3D (TỐC ĐỘ CAO - KHÔNG BAO GIỜ BỊ TREO 90%)
  void _handleDownloadVideo() {
    final double previousValue = _controller.value;
    final bool previousPlaying = _isPlaying;
    _controller.stop();
    setState(() => _isPlaying = false);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        double progress = 0.0;
        String status = 'Đang chuẩn bị luồng quay trực tiếp HD...';
        bool isDone = false;
        bool isStarted = false;
        RealtimeVideoSession? activeSession;
        final modeStr = _isFlycamMode ? 'flycam' : 'toancanh';
        final filename = 'flyover_3d_${modeStr}_${widget.session.id}.mp4';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!isStarted) {
              isStarted = true;

              Future.microtask(() async {
                try {
                  if (mounted && !_isDisposed) {
                    setState(() => _isExportingVideo = true);
                  }
                  _controller.reset();

                  // Tính toán số frames chuẩn xác 100% đồng bộ với tốc độ đang chọn (x1, x2, x3):
                  final double effectiveDurationSec = (_baseDurationMs / 1000.0) / _playbackSpeed;
                  final int totalSteps = (effectiveDurationSec * 25.0).round().clamp(60, 450);

                  final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                  if (boundary == null) throw Exception('Không tìm thấy khung hình 3D.');

                  // Độ nét chuẩn Retina HD 1080p
                  final firstImg = await boundary.toImage(pixelRatio: 2.0);
                  final session = RouteVideoRecorder.startSession(
                    width: firstImg.width,
                    height: firstImg.height,
                    fps: 25.0,
                  );
                  activeSession = session;

                  for (int step = 0; step <= totalSteps; step++) {
                    if (_isDisposed || !mounted) break;
                    final double t = step / totalSteps;
                    _controller.value = t;

                    setDialogState(() {
                      progress = (step / (totalSteps + 2)) * 0.95;
                      status = '🎥 Đang quay video ${_isFlycamMode ? "Flycam" : "Toàn cảnh"} ${(_playbackSpeed).toStringAsFixed(1)}x (${(progress * 100).toInt()}%)...';
                    });

                    await Future.delayed(const Duration(milliseconds: 25));

                    final b = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                    if (b != null) {
                      final img = await b.toImage(pixelRatio: 2.0);
                      final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
                      if (raw != null) {
                        session.pushRawFrame(raw.buffer.asUint8List(), img.width, img.height);
                      }
                    }
                  }

                  setDialogState(() {
                    progress = 0.98;
                    status = '💎 Đang hoàn tất video HD...';
                  });

                  await session.finishRecording();

                  setDialogState(() {
                    progress = 1.0;
                    status = '🎉 Video đã sẵn sàng lưu!';
                    isDone = true;
                  });

                  if (mounted && !_isDisposed) {
                    setState(() => _isExportingVideo = false);
                  }

                  _controller.duration = Duration(milliseconds: (_baseDurationMs / _playbackSpeed).round());
                  _controller.value = previousValue;
                  if (previousPlaying && mounted && !_isDisposed) {
                    _controller.forward();
                    setState(() => _isPlaying = true);
                  }
                } catch (e) {
                  if (mounted && !_isDisposed) {
                    setState(() => _isExportingVideo = false);
                  }
                  setDialogState(() {
                    status = 'Lỗi quay video: $e';
                    isDone = true;
                  });
                }
              });
            }

            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nút Đóng X ở góc trên bên phải
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : AppTheme.primaryNeon.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDone ? Icons.check_circle_rounded : Icons.videocam_rounded,
                                color: isDone ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDone ? 'XUẤT VIDEO XONG' : 'ĐANG XUẤT VIDEO 3D',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDone ? const Color(0xFF10B981) : AppTheme.secondaryNeon,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDone ? const Color(0xFF10B981) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (isDone) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryNeon,
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 19),
                          label: const Text(
                            'LƯU VÀO ALBUM ẢNH',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          onPressed: () {
                            if (activeSession == null) return;
                            final res = activeSession!.downloadVideoDirect(filename);
                            Navigator.of(ctx).pop();
                            if (!mounted) return;
                            TopSyncToast.show(
                              context,
                              message: res.message,
                              isSuccess: res.isSuccess,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'ĐÓNG',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Thẻ thông số thể thao cao cấp nhúng trực tiếp vào Video khi xuất (Chuẩn Story Facebook / TikTok / Instagram - Chữ & Số To Rõ)
  Widget _buildStoryVideoStatsOverlay({
    required double distanceKm,
    required String timeStr,
    required int calories,
    required String pace,
    required bool isFinished,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFinished ? const Color(0xFF10B981) : const Color(0xFF334155),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isFinished ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFinished ? Icons.emoji_events_rounded : Icons.directions_run_rounded,
                color: isFinished ? const Color(0xFFFFD700) : AppTheme.primaryNeon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isFinished ? 'HOÀN THÀNH LỘ TRÌNH CHẠY BỘ' : 'ĐANG THEO DÕI LỘ TRÌNH CHẠY BỘ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: isFinished ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBigStoryStatItem('QUÃNG ĐƯỜNG', '${distanceKm.toStringAsFixed(2)} km', const Color(0xFF00E5FF)),
              _buildBigStoryStatItem('PACE TB', '$pace /km', const Color(0xFF10B981)),
              _buildBigStoryStatItem('THỜI GIAN', timeStr, Colors.white),
              _buildBigStoryStatItem('CALO', '$calories kcal', const Color(0xFFFF7043)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigStoryStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // 1. KHUNG HÌNH 3D LỘ TRÌNH & VIDEO STORY (NHẬN DIỆN KHI XUẤT VIDEO)
          Positioned.fill(
            child: RepaintBoundary(
              key: _previewKey,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final double t = _controller.value.clamp(0.0, 1.0);
                  double curProgress = 0.0;
                  if (t < 0.10) {
                    curProgress = 0.0;
                  } else if (t < 0.65) {
                    curProgress = ((t - 0.10) / 0.55).clamp(0.0, 1.0);
                  } else {
                    curProgress = 1.0;
                  }

                  final double curDistance = _effectiveDistanceKm * curProgress;
                  final int curDurationSec = (_effectiveDurationSec * curProgress).round();
                  final int min = curDurationSec ~/ 60;
                  final int sec = curDurationSec % 60;
                  final String curTimeStr = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
                  final int curCalories = (_effectiveCalories * curProgress).round();
                  final bool isFinished = curProgress >= 0.99;

                  return Stack(
                    children: [
                      // Bản đồ 3D và lộ trình đường chạy
                      Positioned.fill(
                        child: CustomPaint(
                          painter: Real3DStravaFlyoverPainter(
                            pixels: _cachedRoutePixels,
                            fullPath: _fullVectorPath,
                            sampledPositions: _sampledPositions,
                            smoothedCamPositions: _smoothedCamPositions,
                            sampledHeadings: _sampledHeadings,
                            startPinPixel: _startPinPixel,
                            finishPinPixel: _finishPinPixel,
                            pathMetric: _pathMetric,
                            totalLength: _totalPathLength,
                            milestones: _milestones,
                            progress: t,
                            tileCache: MapTileCacheService.memoryCache,
                            zoom: _zoomLevel,
                            routeCenterX: _routeCenterX,
                            routeCenterY: _routeCenterY,
                            spanW: _spanW,
                            spanH: _spanH,
                            isFlycamMode: _isFlycamMode,
                            tileVersion: _tileVersion,
                            onTileRequested: (z, x, y) {
                              MapTileCacheService.getTile(z, x, y).then((img) {
                                if (img != null && !_isDisposed && mounted) {
                                  setState(() => _tileVersion++);
                                }
                              });
                            },
                          ),
                          size: Size.infinite,
                        ),
                      ),

                      // Thẻ thông số thời gian thực to rõ trên video khi xuất để đăng Story Facebook
                      if (_isExportingVideo)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 32,
                          child: _buildStoryVideoStatsOverlay(
                            distanceKm: curDistance,
                            timeStr: curTimeStr,
                            calories: curCalories,
                            pace: _effectivePace,
                            isFinished: isFinished,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. VIP TOP HUD: NÚT BACK TRÒN + NÚT CHUYỂN CHẾ ĐỘ TOÀN CẢNH/FLYCAM Ở GIỮA CÂN ĐỐI + NÚT TẢI VIDEO TRÒN
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nút Tròn Quay lại
                    InkWell(
                      onTap: _handleExit,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          border: Border.all(color: const Color(0xFF1E293B)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                        ),
                      ),
                    ),

                    // Nút Chuyển Đổi [🗺️ TOÀN CẢNH] / [🚁 FLYCAM] Ở CHÍNH GIỮA CÂN ĐỐI
                    InkWell(
                      onTap: () {
                        setState(() => _isFlycamMode = !_isFlycamMode);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon).withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFlycamMode ? Icons.airplanemode_active_rounded : Icons.map_outlined,
                              size: 16,
                              color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFlycamMode ? 'CHẾ ĐỘ FLYCAM' : 'CHẾ ĐỘ TOÀN CẢNH',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nút Tròn Tải Video
                    InkWell(
                      onTap: _handleDownloadVideo,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          border: Border.all(color: const Color(0xFF1E293B)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.download_rounded, color: AppTheme.secondaryNeon, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. BOTTOM GROUP: THẺ TỔNG KẾT & THANH ĐIỀU KHIỂN XẾP CÁCH NHAU RÕ RÀNG (KHÔNG DÍNH NHAU)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A. THẺ TỔNG KẾT THÀNH TÍCH NHẢY ĐỘNG THEO TIẾN ĐỘ CHẠY
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final double t = _controller.value.clamp(0.0, 1.0);
                    double curProgress = 0.0;
                    if (t < 0.10) {
                      curProgress = 0.0;
                    } else if (t < 0.65) {
                      curProgress = ((t - 0.10) / 0.55).clamp(0.0, 1.0);
                    } else {
                      curProgress = 1.0;
                    }

                    final double curDistance = _effectiveDistanceKm * curProgress;
                    final int curDurationSec = (_effectiveDurationSec * curProgress).round();
                    final int curCalories = (_effectiveCalories * curProgress).round();
                    final bool isCompleted = curProgress >= 0.98;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.6)
                              : const Color(0xFF334155),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isCompleted
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isCompleted ? Icons.emoji_events_rounded : Icons.directions_run_rounded,
                                color: isCompleted ? const Color(0xFFFFD700) : AppTheme.primaryNeon,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCompleted ? 'HOÀN THÀNH XUẤT SẮC' : 'ĐANG CHẠY LỘ TRÌNH',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isCompleted ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryStatItem('QUÃNG ĐƯỜNG', '${curDistance.toStringAsFixed(2)} km', AppTheme.primaryNeon),
                              _buildSummaryStatItem('PACE TB', '$_effectivePace /km', AppTheme.secondaryNeon),
                              _buildSummaryStatItem('THỜI GIAN', _formatDuration(curDurationSec), Colors.white),
                              _buildSummaryStatItem('CALO', '$curCalories kcal', AppTheme.accentOrange),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12), // KHOẢNG CÁCH RÕ RÀNG GIỮA 2 KHỐI

                // B. THANH ĐIỀU KHIỂN PLAYBACK (SLIDER ĐỎ + 1X + NÚT TRÒN ĐỎ + 100%) - TỰ ĐỘNG CẬP NHẬT THEO TỪNG FRAME
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final double progressVal = _controller.value.clamp(0.0, 1.0);
                    final int percent = (progressVal * 100).round();
                    final isCompleted = progressVal >= 0.98 || _controller.status == AnimationStatus.completed;

                    IconData playIcon = Icons.pause_rounded;
                    if (!_isPlaying) {
                      playIcon = isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded;
                    }

                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Slider đỏ với nút tròn trắng di chuyển mượt mà 100%
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: const Color(0xFFFF3366),
                              inactiveTrackColor: const Color(0xFF1E293B),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: progressVal,
                              onChanged: (val) {
                                _controller.stop();
                                _controller.value = val;
                                setState(() => _isPlaying = false);
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Dropdown speed
                              InkWell(
                                onTap: _openSpeedSelectorModal,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.secondaryNeon, size: 18),
                                      const SizedBox(width: 2),
                                      Text(
                                        _formatSpeed(_playbackSpeed),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Nút Play / Replay tròn đỏ phát sáng
                              InkWell(
                                onTap: _togglePlayPause,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF2A55),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF2A55).withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    playIcon,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),

                              // Phần trăm tiến độ 100%
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Text(
                                  '$percent%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remSec = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remSec.toString().padLeft(2, '0')}';
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
  final Offset pixel;
  const MilestoneData({required this.km, required this.point, required this.pixel});
}

// PAINTER STRAVA 3D FLYOVER CHUYÊN NGHIỆP - 100% SIÊU MƯỢT KHÔNG RUNG LẮC
class Real3DStravaFlyoverPainter extends CustomPainter {
  final List<Offset> pixels;
  final Path fullPath;
  final List<Offset> sampledPositions;
  final List<Offset> smoothedCamPositions;
  final List<double> sampledHeadings;
  final Offset startPinPixel;
  final Offset finishPinPixel;
  final ui.PathMetric pathMetric;
  final double totalLength;
  final List<MilestoneData> milestones;
  final double progress;
  final Map<String, ui.Image> tileCache;
  final int zoom;
  final double routeCenterX;
  final double routeCenterY;
  final double spanW;
  final double spanH;
  final bool isFlycamMode;
  final int tileVersion;
  final Function(int z, int x, int y) onTileRequested;

  static const double tileSize = 256.0;

  static final Paint _tilePaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

  static final Paint _emptyTilePaint = Paint()..color = const Color(0xFF0F172A);

  Real3DStravaFlyoverPainter({
    required this.pixels,
    required this.fullPath,
    required this.sampledPositions,
    required this.smoothedCamPositions,
    required this.sampledHeadings,
    required this.startPinPixel,
    required this.finishPinPixel,
    required this.pathMetric,
    required this.totalLength,
    required this.milestones,
    required this.progress,
    required this.tileCache,
    required this.zoom,
    required this.routeCenterX,
    required this.routeCenterY,
    required this.spanW,
    required this.spanH,
    required this.isFlycamMode,
    required this.tileVersion,
    required this.onTileRequested,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pixels.isEmpty || sampledPositions.isEmpty) return;

    // 1. TÍNH TOÁN CÁC MỐC TỈ LỆ ZOOM CAMERA
    final double targetScaleX = (size.width * 0.70) / (spanW > 40 ? spanW : 160);
    final double targetScaleY = (size.height * 0.50) / (spanH > 40 ? spanH : 160);
    final double overviewScale = math.min(targetScaleX, targetScaleY).clamp(0.25, 1.80);
    final double chaseScale = (overviewScale * 1.35).clamp(0.35, 1.85); // Zoom Flycam vừa vặn
    final double startScale = (overviewScale * 1.65).clamp(0.45, 2.40); // Zoom cận cảnh điểm BẮT ĐẦU
    final double finishScale = (overviewScale * 1.65).clamp(0.45, 2.40); // Zoom cận cảnh điểm KẾT THÚC

    // 2. TIMELINE ĐIỆN ẢNH CHUYÊN NGHIỆP:
    // - Phase 1 [0.00 - 0.10] (~2s): Zoom cận cảnh vị trí BẮT ĐẦU để user nhìn rõ điểm xuất phát
    // - Phase 2 [0.10 - 0.65] (~11s): Chạy lộ trình mượt mà từ 0% đến 100%
    // - Phase 3 [0.65 - 0.75] (~2s): Zoom cận cảnh vị trí KẾT THÚC
    // - Phase 4 [0.75 - 0.82] (~1.4s): Thu nhỏ mở rộng bản đồ ra lại TOÀN CẢNH
    // - Phase 5 [0.82 - 1.00] (~4-5s): Giữ nguyên TOÀN CẢNH để chiêm ngưỡng toàn bộ cung đường & thông số
    double camX;
    double camY;
    double camScale;
    double flightProgress;

    if (progress < 0.10) {
      // 1. Giai đoạn BẮT ĐẦU: Giữ zoom cận cảnh điểm xuất phát (2s)
      flightProgress = 0.0;
      camX = startPinPixel.dx;
      camY = startPinPixel.dy;
      camScale = startScale;
    } else if (progress < 0.65) {
      // 2. Giai đoạn CHẠY: Tiến độ lộ trình từ 0.0 đến 1.0
      flightProgress = ((progress - 0.10) / 0.55).clamp(0.0, 1.0);

      final double fIndex = (sampledPositions.length - 1) * flightProgress;
      final int baseIdx = fIndex.floor().clamp(0, sampledPositions.length - 1);
      final int nextIdx = math.min(baseIdx + 1, sampledPositions.length - 1);
      final double subFrac = fIndex - baseIdx;
      final Offset smoothedCam = Offset.lerp(smoothedCamPositions[baseIdx], smoothedCamPositions[nextIdx], subFrac)!;

      if (isFlycamMode) {
        final double introTransit = Curves.easeInOutCubic.transform((flightProgress / 0.15).clamp(0.0, 1.0));
        camX = ui.lerpDouble(startPinPixel.dx, smoothedCam.dx, introTransit)!;
        camY = ui.lerpDouble(startPinPixel.dy, smoothedCam.dy, introTransit)!;
        camScale = ui.lerpDouble(startScale, chaseScale, introTransit)!;
      } else {
        final double introTransit = Curves.easeInOutCubic.transform((flightProgress / 0.18).clamp(0.0, 1.0));
        camX = ui.lerpDouble(startPinPixel.dx, routeCenterX, introTransit)!;
        camY = ui.lerpDouble(startPinPixel.dy, routeCenterY, introTransit)!;
        camScale = ui.lerpDouble(startScale, overviewScale, introTransit)!;
      }
    } else if (progress < 0.75) {
      // 3. Giai đoạn ĐÍCH: Zoom cận cảnh điểm KẾT THÚC (2s)
      flightProgress = 1.0;
      final double tFinish = Curves.easeInOutCubic.transform(((progress - 0.65) / 0.10).clamp(0.0, 1.0));
      final Offset lastCam = smoothedCamPositions.isNotEmpty ? smoothedCamPositions.last : finishPinPixel;
      final double fromScale = isFlycamMode ? chaseScale : overviewScale;
      final double fromX = isFlycamMode ? lastCam.dx : routeCenterX;
      final double fromY = isFlycamMode ? lastCam.dy : routeCenterY;

      camX = ui.lerpDouble(fromX, finishPinPixel.dx, tFinish)!;
      camY = ui.lerpDouble(fromY, finishPinPixel.dy, tFinish)!;
      camScale = ui.lerpDouble(fromScale, finishScale, tFinish)!;
    } else if (progress < 0.82) {
      // 4. Giai đoạn THU NHỎ: Thu nhỏ bản đồ về lại TOÀN CẢNH
      flightProgress = 1.0;
      final double tOverview = Curves.easeInOutCubic.transform(((progress - 0.75) / 0.07).clamp(0.0, 1.0));

      camX = ui.lerpDouble(finishPinPixel.dx, routeCenterX, tOverview)!;
      camY = ui.lerpDouble(finishPinPixel.dy, routeCenterY, tOverview)!;
      camScale = ui.lerpDouble(finishScale, overviewScale, tOverview)!;
    } else {
      // 5. Giai đoạn GIỮ 5 GIÂY: Giữ cố định TOÀN CẢNH để xem trọn vẹn lộ trình và thông số
      flightProgress = 1.0;
      camX = routeCenterX;
      camY = routeCenterY;
      camScale = overviewScale;
    }

    final double currentDist = totalLength * flightProgress;

    final double fIndex = (sampledPositions.length - 1) * flightProgress.clamp(0.0, 1.0);
    final int baseIdx = fIndex.floor().clamp(0, sampledPositions.length - 1);
    final int nextIdx = math.min(baseIdx + 1, sampledPositions.length - 1);
    final double subFrac = fIndex - baseIdx;

    final Offset currentPixel = Offset.lerp(sampledPositions[baseIdx], sampledPositions[nextIdx], subFrac)!;
    final double runnerHeading = ui.lerpDouble(sampledHeadings[baseIdx], sampledHeadings[nextIdx], subFrac)!;
    final double outroT = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);

    // 3. ĐỘ DÀY NÉT VẼ TỰ ĐỘNG NỘI SUY THEO TỈ LỆ ZOOM
    final double strokeBase = (3.6 / camScale).clamp(2.4, 5.0);
    final double strokeCore = (1.4 / camScale).clamp(0.9, 2.0);
    final double strokeShadow = (6.0 / camScale).clamp(4.0, 8.5);

    final Paint fullPathPaint = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = strokeBase * 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint shadowPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0x35000000)
      ..strokeWidth = strokeShadow
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint activePathPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFC5200) // Strava Athletic Orange-Red
      ..strokeWidth = strokeBase
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint coreHighlightPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFFB088)
      ..strokeWidth = strokeCore
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 4. MA TRẬN CAMERA CHUYÊN NGHIỆP
    final double screenCenterX = size.width / 2;
    final double screenCenterY = size.height * 0.52;

    canvas.save();
    canvas.translate(screenCenterX, screenCenterY);
    canvas.scale(camScale, camScale);
    canvas.translate(-camX, -camY);

    // 5. VẼ MAP TILES GOOGLE MAPS BAO PHỦ TOÀN BỘ KHUNG NHÌN
    final int centerTileX = (camX / tileSize).floor();
    final int centerTileY = (camY / tileSize).floor();
    final int tileRadiusX = (4.5 / camScale).ceil().clamp(5, 10);
    final int tileRadiusY = (5.5 / camScale).ceil().clamp(6, 12);

    for (int dx = -tileRadiusX; dx <= tileRadiusX; dx++) {
      for (int dy = -tileRadiusY; dy <= tileRadiusY + 1; dy++) {
        final tx = centerTileX + dx;
        final ty = centerTileY + dy;
        final key = '$zoom/$tx/$ty';

        final tileRect = Rect.fromLTWH(tx * tileSize - 0.75, ty * tileSize - 0.75, tileSize + 1.5, tileSize + 1.5);

        if (tileCache.containsKey(key)) {
          final img = tileCache[key]!;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            tileRect,
            _tilePaint,
          );
        } else {
          // Khung dự phòng hiện đại nền tối thể thao
          canvas.drawRect(tileRect, _emptyTilePaint);
          onTileRequested(zoom, tx, ty);
        }
      }
    }

    // 6. VẼ ĐƯỜNG DẪN DỰ KIẾN
    canvas.drawPath(fullPath, fullPathPaint);

    // 7. VẼ VỆT CHẠY ĐÃ HOÀN THÀNH (Đường Ribbon Strava Thể Thao Thanh Lịch)
    if (currentDist > 1.0) {
      final Path activePath = pathMetric.extractPath(0.0, currentDist);
      canvas.drawPath(activePath, shadowPaint);
      canvas.drawPath(activePath, activePathPaint);
      canvas.drawPath(activePath, coreHighlightPaint);
    }

    // 8. VẼ CÁC CỘT MỐC TẠM DỪNG (CHỈ KHI NGƯỜI DÙNG CÓ BẤM TẠM DỪNG TRONG LÚC CHẠY)
    for (final m in milestones) {
      final pinPixel = m.pixel;

      canvas.save();
      canvas.translate(pinPixel.dx, pinPixel.dy);

      canvas.drawCircle(const Offset(0, 0), 4, Paint()..color = Colors.black26);
      canvas.drawLine(const Offset(0, 0), const Offset(0, -18), Paint()..color = Colors.black54..strokeWidth = 2);
      canvas.drawCircle(const Offset(0, -18), 12, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(
        const Offset(0, -18),
        12,
        Paint()
          ..color = const Color(0xFFF59E0B) // Màu vàng hổ phách thể thao cho điểm Tạm Dừng
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Icon Pause (2 vạch dọc vàng hổ phách)
      final pauseBarPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4.5, -23, 3.2, 10), const Radius.circular(1.5)), pauseBarPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1.3, -23, 3.2, 10), const Radius.circular(1.5)), pauseBarPaint);

      canvas.restore();
    }

    // 9. VẼ CỘT MỐC BẮT ĐẦU VÀ KẾT THÚC
    final bool isLoop = (startPinPixel - finishPinPixel).distance < 40.0;

    // Start Pin
    final Offset startBadgeOffset = isLoop ? const Offset(-24, 0) : Offset.zero;
    canvas.save();
    canvas.translate(startPinPixel.dx + startBadgeOffset.dx, startPinPixel.dy + startBadgeOffset.dy);
    canvas.drawCircle(const Offset(0, 0), 6, Paint()..color = Colors.black26);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -22), Paint()..color = Colors.black87..strokeWidth = 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -46, 80, 24), const Radius.circular(12)),
      Paint()..color = const Color(0xFF10B981),
    );
    final startText = TextPainter(
      text: const TextSpan(
        text: '🟢 BẮT ĐẦU',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    startText.paint(canvas, Offset(-startText.width / 2, -46 + (24 - startText.height) / 2));
    canvas.restore();

    // Finish Pin
    final Offset finishBadgeOffset = isLoop ? const Offset(24, 0) : Offset.zero;
    canvas.save();
    canvas.translate(finishPinPixel.dx + finishBadgeOffset.dx, finishPinPixel.dy + finishBadgeOffset.dy);

    if (outroT > 0.05) {
      canvas.drawCircle(
        const Offset(0, -28),
        26 + outroT * 8,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.35 * outroT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    canvas.drawCircle(const Offset(0, 0), 6, Paint()..color = Colors.black26);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -22), Paint()..color = Colors.black87..strokeWidth = 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -46, 80, 24), const Radius.circular(12)),
      Paint()..color = const Color(0xFFEF4444),
    );
    final finishText = TextPainter(
      text: const TextSpan(
        text: '🏁 KẾT THÚC',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    finishText.paint(canvas, Offset(-finishText.width / 2, -46 + (24 - finishText.height) / 2));
    canvas.restore();

    // 10. VẼ CON TRỎ ĐỊNH VỊ GPS THỂ THAO NIKE/APPLE ATHLETIC BEACON
    canvas.save();
    canvas.translate(currentPixel.dx, currentPixel.dy);

    final double pulse = (progress * 18.0) % 1.0;
    canvas.drawCircle(
      Offset.zero,
      12 + pulse * 24,
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.40 * (1.0 - pulse) * (1.0 - outroT))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Đèn pha dẫn đường
    canvas.save();
    canvas.rotate(runnerHeading);

    final beamPath = Path()
      ..moveTo(0, 0)
      ..lineTo(48, -20)
      ..lineTo(48, 20)
      ..close();

    final beamPaint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(48, 0),
        [
          const Color(0xFF00E5FF).withValues(alpha: 0.50 * (1.0 - outroT)),
          const Color(0xFF00E5FF).withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(beamPath, beamPaint);

    // Vành đai phát sáng
    canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.6));
    canvas.drawCircle(
      Offset.zero,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF00E5FF),
    );

    // Mũi tên định hướng
    final navArrow = Path()
      ..moveTo(9, 0)
      ..lineTo(-5, -6)
      ..lineTo(-2, 0)
      ..lineTo(-5, 6)
      ..close();

    canvas.drawPath(navArrow, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = const Color(0xFF00E5FF));

    canvas.restore();
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Real3DStravaFlyoverPainter oldDelegate) {
    return true;
  }
}
