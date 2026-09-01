import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
  bool _isFlycamMode = true; // Mặc định: TRUE = Theo Dõi (Bám mượt theo người chạy)

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

  double _userScaleMultiplier = 1.0;
  Offset _userPanOffset = Offset.zero;
  double _baseScaleMultiplier = 1.0;
  Offset _basePanOffset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  String _selectedMapType = 'terrain'; // 'terrain' | 'satellite'

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5];
  static const double tileSize = 256.0;

  int _baseDurationMs = 15000;

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

    _baseDurationMs = 15000;

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

    minTx -= 2;
    maxTx += 2;
    minTy -= 2;
    maxTy += 3;

    MapTileCacheService.preloadBoundingBox(
      zoom: _zoomLevel,
      minX: minTx,
      maxX: maxTx,
      minY: minTy,
      maxY: maxTy,
      mapType: _selectedMapType,
      onTileLoaded: () {
        if (!_isDisposed && mounted) {
          setState(() => _tileVersion++);
        }
      },
    );
  }

  void _resetView() {
    setState(() {
      _userScaleMultiplier = 1.0;
      _userPanOffset = Offset.zero;
    });
  }

  void _toggleMapType() {
    setState(() {
      _selectedMapType = (_selectedMapType == 'satellite') ? 'terrain' : 'satellite';
      _tileVersion++;
    });
    _precacheRouteMapTiles();
  }

  Widget _buildCompactStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color),
        ),
      ],
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
                  _controller.reset();

                  // Tính toán số frames chuẩn xác 100% đồng bộ với tốc độ đang chọn (x1, x2, x3):
                  final double effectiveDurationSec = (_baseDurationMs / 1000.0) / _playbackSpeed;
                  final int totalSteps = (effectiveDurationSec * 25.0).round().clamp(60, 450);

                  // KÍCH THƯỚC CHUẨN 100% FACEBOOK STORY / INSTAGRAM / TIKTOK: 720 x 1280 (TỶ LỆ 9:16)
                  // Tối ưu phần cứng siêu mượt, không tốn RAM, không bao giờ bị tràn bộ nhớ hay thoát app
                  const double exportWidth = 720.0;
                  const double exportHeight = 1280.0;

                  final session = RouteVideoRecorder.startSession(
                    width: exportWidth.toInt(),
                    height: exportHeight.toInt(),
                    fps: 25.0,
                  );
                  activeSession = session;

                  for (int step = 0; step <= totalSteps; step++) {
                    if (_isDisposed || !mounted) break;
                    final double t = step / totalSteps;
                    _controller.value = t;

                    setDialogState(() {
                      progress = (step / (totalSteps + 125)) * 0.95;
                      status = 'Đang xuất video Story ${_isFlycamMode ? "Theo dõi" : "Toàn cảnh"} ${(_playbackSpeed).toStringAsFixed(1)}x (${(progress * 100).toInt()}%)...';
                    });

                    // Render khung hình 3D + Thẻ thông số trực tiếp vào Canvas 9:16 và giải phóng GPU texture tức thì
                    final frameBytes = await _renderStoryFrameBytes(
                      t: t,
                      width: exportWidth,
                      height: exportHeight,
                    );
                    if (frameBytes != null) {
                      await session.pushRawFrame(frameBytes, exportWidth.toInt(), exportHeight.toInt());

                      // Ở frame cuối (t = 1.0), giữ nguyên toàn cảnh để thấy trọn vẹn thông số:
                      // - Video Theo dõi: để đó tầm 5s (125 frames ở 25 fps)
                      // - Video Toàn cảnh: để đó tầm 2s (50 frames ở 25 fps)
                      if (step == totalSteps) {
                        final int holdFrames = _isFlycamMode ? 125 : 50;
                        for (int hold = 0; hold < holdFrames; hold++) {
                          await session.pushRawFrame(frameBytes, exportWidth.toInt(), exportHeight.toInt());
                        }
                      }
                    }

                    // Tạm dừng 1ms để hệ điều hành dọn dẹp rác (GC) chống tràn RAM
                    await Future.delayed(const Duration(milliseconds: 1));
                  }

                  setDialogState(() {
                    progress = 0.98;
                    status = 'Đang hoàn tất video Story 9:16...';
                  });

                  await session.finishRecording();

                  setDialogState(() {
                    progress = 1.0;
                    status = 'Video đã sẵn sàng lưu!';
                    isDone = true;
                  });

                  _controller.duration = Duration(milliseconds: (_baseDurationMs / _playbackSpeed).round());
                  _controller.value = previousValue;
                  if (previousPlaying && mounted && !_isDisposed) {
                    _controller.forward();
                    setState(() => _isPlaying = true);
                  }
                } catch (e) {
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
  /// Render khung hình chuẩn 720 x 1280 (Tỷ lệ 9:16 chuyên dụng Facebook Story / Reels / TikTok)
  Future<Uint8List?> _renderStoryFrameBytes({
    required double t,
    required double width,
    required double height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final painter = Real3DStravaFlyoverPainter(
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
      userScaleMultiplier: _userScaleMultiplier,
      userPanOffset: _userPanOffset,
      mapType: _selectedMapType,
      onTileRequested: (z, x, y) {},
    );

    // 1. Vẽ bản đồ 3D và lộ trình đường chạy trên khung hình 9:16
    painter.paint(canvas, Size(width, height));

    // 2. Tính toán các chỉ số thành tích thời gian thực
    double curProgress = 0.0;
    if (t < 0.18) {
      curProgress = 0.0;
    } else if (t < 0.70) {
      curProgress = ((t - 0.18) / 0.52).clamp(0.0, 1.0);
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

    // 3. Vẽ Thẻ thống số nổi bật ở vùng an toàn đáy Story (Không vẽ watermark Nocodevn Running theo yêu cầu)
    _drawStoryStatsCard(
      canvas: canvas,
      size: Size(width, height),
      distanceKm: curDistance,
      timeStr: curTimeStr,
      calories: curCalories,
      pace: _effectivePace,
      isFinished: isFinished,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    picture.dispose(); // Giải phóng GPU Picture ngay

    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose(); // Giải phóng GPU Texture ngay lập tức chống tràn RAM

    if (raw != null) {
      return raw.buffer.asUint8List();
    }
    return null;
  }

  void _drawStoryStatsCard({
    required Canvas canvas,
    required Size size,
    required double distanceKm,
    required String timeStr,
    required int calories,
    required String pace,
    required bool isFinished,
  }) {
    final double cardW = size.width * 0.90;
    final double cardH = size.height * 0.145;
    final double cardX = (size.width - cardW) / 2;
    final double cardY = size.height - cardH - (size.height * 0.09); // Vùng an toàn trên thanh comment Story

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardW, cardH),
      const Radius.circular(28),
    );

    // Nền thẻ kính mờ cao cấp
    final bgPaint = Paint()..color = const Color(0xEE0F172A);
    canvas.drawRRect(rrect, bgPaint);

    // Viền thẻ
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = isFinished ? const Color(0xFF10B981) : const Color(0xFF334155);
    canvas.drawRRect(rrect, borderPaint);

    // Tiêu đề trạng thái
    final String title = isFinished ? 'HOÀN THÀNH LỘ TRÌNH CHẠY BỘ' : 'ĐANG THEO DÕI LỘ TRÌNH CHẠY BỘ';
    final Color titleColor = isFinished ? const Color(0xFF10B981) : const Color(0xFF00E5FF);

    _drawCanvasText(
      canvas: canvas,
      text: title,
      center: Offset(size.width / 2, cardY + (cardH * 0.18)),
      fontSize: size.width * 0.024,
      fontWeight: FontWeight.w900,
      color: titleColor,
      letterSpacing: 0.8,
      maxWidth: cardW - 30,
    );

    // Đường gạch ngang tinh tế
    final divPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(cardX + 25, cardY + (cardH * 0.34)),
      Offset(cardX + cardW - 25, cardY + (cardH * 0.34)),
      divPaint,
    );

    // 4 Cột thông số
    final colW = cardW / 4;
    final double yVal = cardY + (cardH * 0.58);
    final double yLbl = cardY + (cardH * 0.82);

    // Cột 1: Quãng đường
    _drawCanvasText(
      canvas: canvas,
      text: '${distanceKm.toStringAsFixed(2)} km',
      center: Offset(cardX + colW * 0.5, yVal),
      fontSize: size.width * 0.034,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF00E5FF),
      maxWidth: colW,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'QUÃNG ĐƯỜNG',
      center: Offset(cardX + colW * 0.5, yLbl),
      fontSize: size.width * 0.017,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF94A3B8),
      letterSpacing: 0.4,
      maxWidth: colW,
    );

    // Cột 2: Pace TB
    _drawCanvasText(
      canvas: canvas,
      text: '$pace /km',
      center: Offset(cardX + colW * 1.5, yVal),
      fontSize: size.width * 0.034,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF10B981),
      maxWidth: colW,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'PACE TB',
      center: Offset(cardX + colW * 1.5, yLbl),
      fontSize: size.width * 0.017,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF94A3B8),
      letterSpacing: 0.4,
      maxWidth: colW,
    );

    // Cột 3: Thời gian
    _drawCanvasText(
      canvas: canvas,
      text: timeStr,
      center: Offset(cardX + colW * 2.5, yVal),
      fontSize: size.width * 0.034,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      maxWidth: colW,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'THỜI GIAN',
      center: Offset(cardX + colW * 2.5, yLbl),
      fontSize: size.width * 0.017,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF94A3B8),
      letterSpacing: 0.4,
      maxWidth: colW,
    );

    // Cột 4: Calo
    _drawCanvasText(
      canvas: canvas,
      text: '$calories kcal',
      center: Offset(cardX + colW * 3.5, yVal),
      fontSize: size.width * 0.034,
      fontWeight: FontWeight.w900,
      color: const Color(0xFFFF7043),
      maxWidth: colW,
    );
    _drawCanvasText(
      canvas: canvas,
      text: 'CALO',
      center: Offset(cardX + colW * 3.5, yLbl),
      fontSize: size.width * 0.017,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF94A3B8),
      letterSpacing: 0.4,
      maxWidth: colW,
    );
  }

  void _drawCanvasText({
    required Canvas canvas,
    required String text,
    required Offset center,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
    double maxWidth = 300.0,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
    builder.pushStyle(ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    ));
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - (maxWidth / 2), center.dy - (paragraph.height / 2)),
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

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      _baseScaleMultiplier = _userScaleMultiplier;
                      _basePanOffset = _userPanOffset;
                      _lastFocalPoint = details.localFocalPoint;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        _userScaleMultiplier = (_baseScaleMultiplier * details.scale).clamp(0.35, 3.5);
                        final delta = details.localFocalPoint - _lastFocalPoint;
                        _userPanOffset = _basePanOffset + delta;
                      });
                    },
                    child: Stack(
                      children: [
                        // Bản đồ 3D và lộ trình đường chạy
                        Positioned.fill(
                          child: ValueListenableBuilder<int>(
                            valueListenable: MapTileCacheService.tileNotifier,
                            builder: (context, tileCount, _) {
                              return CustomPaint(
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
                                  tileVersion: tileCount,
                                  userScaleMultiplier: _userScaleMultiplier,
                                  userPanOffset: _userPanOffset,
                                  mapType: _selectedMapType,
                                  onTileRequested: (z, x, y) {
                                    MapTileCacheService.getTile(z, x, y, mapType: _selectedMapType);
                                  },
                                ),
                                size: Size.infinite,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. VIP TOP HUD: NÚT BACK + NÚT CHUYỂN TOÀN CẢNH/FLYCAM + NÚT LỚP MAP + NÚT TẢI VIDEO
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nút Quay lại
                    InkWell(
                      onTap: _handleExit,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          border: Border.all(color: const Color(0xFF1E293B)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),

                    // Nút chuyển chế độ [🎯 THEO DÕI] / [🗺️ TOÀN CẢNH]
                    InkWell(
                      onTap: () {
                        setState(() => _isFlycamMode = !_isFlycamMode);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon).withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFlycamMode ? Icons.gps_fixed_rounded : Icons.map_outlined,
                              size: 14,
                              color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isFlycamMode ? 'THEO DÕI' : 'TOÀN CẢNH',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nhóm Nút Bên Phải: Đổi Vệ Tinh/Địa Hình 1-Chạm + Nút Tải Video
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút Đổi Lớp Bản Đồ [🛰️ VỆ TINH] / [🏔️ ĐỊA HÌNH] (1-Chạm tức thì)
                        InkWell(
                          onTap: _toggleMapType,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedMapType == 'satellite' ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_selectedMapType == 'satellite' ? const Color(0xFF00E5FF) : const Color(0xFF10B981))
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedMapType == 'satellite' ? Icons.satellite_alt_rounded : Icons.terrain_rounded,
                                  color: _selectedMapType == 'satellite' ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _selectedMapType == 'satellite' ? 'VỆ TINH' : 'ĐỊA HÌNH',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _selectedMapType == 'satellite' ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Nút Tròn Tải Video
                        InkWell(
                          onTap: _handleDownloadVideo,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                              border: Border.all(color: const Color(0xFF1E293B)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.download_rounded, color: AppTheme.secondaryNeon, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. NÚT ĐẶT LẠI GÓC NHÌN (CHỈ HIỆN KHI BẠN ĐÃ DÙNG TAY ZOOM HOẶC KÉO MAP)
          if (_userScaleMultiplier != 1.0 || _userPanOffset != Offset.zero)
            Positioned(
              top: 68,
              right: 14,
              child: SafeArea(
                child: InkWell(
                  onTap: _resetView,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.primaryNeon, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryNeon.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.center_focus_strong_rounded, size: 13, color: AppTheme.primaryNeon),
                        SizedBox(width: 5),
                        Text(
                          'ĐẶT LẠI GÓC',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppTheme.primaryNeon),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. BOTTOM GROUP: THANH ĐIỀU KHIỂN & THÔNG SỐ SIÊU GỌN (CHỈ 1 KHỐI DUY NHẤT)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double t = _controller.value.clamp(0.0, 1.0);
                double curProgress = 0.0;
                if (t < 0.18) {
                  curProgress = 0.0;
                } else if (t < 0.70) {
                  curProgress = ((t - 0.18) / 0.52).clamp(0.0, 1.0);
                } else {
                  curProgress = 1.0;
                }

                final double curDistance = _effectiveDistanceKm * curProgress;
                final int curDurationSec = (_effectiveDurationSec * curProgress).round();
                final int curCalories = (_effectiveCalories * curProgress).round();
                final int percent = (t * 100).round();
                final isCompleted = t >= 0.98 || _controller.status == AnimationStatus.completed;

                IconData playIcon = Icons.pause_rounded;
                if (!_isPlaying) {
                  playIcon = isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.8), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hàng 1: 4 thông số chính tinh gọn
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCompactStatItem('QUÃNG ĐƯỜNG', '${curDistance.toStringAsFixed(2)} km', AppTheme.primaryNeon),
                          _buildCompactStatItem('PACE TB', '$_effectivePace/km', AppTheme.secondaryNeon),
                          _buildCompactStatItem('THỜI GIAN', _formatDuration(curDurationSec), Colors.white),
                          _buildCompactStatItem('CALO', '$curCalories kcal', AppTheme.accentOrange),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Hàng 2: Slider timeline siêu mỏng
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: const Color(0xFFFF3366),
                          inactiveTrackColor: const Color(0xFF1E293B),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: t,
                          onChanged: (val) {
                            _controller.stop();
                            _controller.value = val;
                            setState(() => _isPlaying = false);
                          },
                        ),
                      ),

                      // Hàng 3: Tốc độ + Nút Play ở giữa + Tiến độ %
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Nút chọn tốc độ nhỏ gọn
                          InkWell(
                            onTap: _openSpeedSelectorModal,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatSpeed(_playbackSpeed),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.secondaryNeon),
                                  ),
                                  const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.secondaryNeon, size: 14),
                                ],
                              ),
                            ),
                          ),

                          // Nút Play / Pause tròn đỏ neon chính giữa
                          InkWell(
                            onTap: _togglePlayPause,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF2A55),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2A55).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(playIcon, color: Colors.white, size: 20),
                            ),
                          ),

                          // Phần trăm tiến độ
                          Text(
                            '$percent%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  final double userScaleMultiplier;
  final Offset userPanOffset;
  final String mapType;
  final Function(int z, int x, int y) onTileRequested;

  static const double tileSize = 256.0;

  static final Paint _tilePaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.medium;

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
    this.userScaleMultiplier = 1.0,
    this.userPanOffset = Offset.zero,
    this.mapType = 'terrain',
    required this.onTileRequested,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pixels.isEmpty || sampledPositions.isEmpty) return;

    // 1. TÍNH TOÁN CÁC MỐC TỈ LỆ ZOOM CAMERA
    final double targetScaleX = (size.width * 0.70) / (spanW > 40 ? spanW : 160);
    final double targetScaleY = (size.height * 0.50) / (spanH > 40 ? spanH : 160);
    final double overviewScale = math.min(targetScaleX, targetScaleY).clamp(0.25, 1.80);
    final double chaseScale = (overviewScale * 1.45).clamp(0.35, 1.85); // Zoom Theo dõi vừa vặn
    final double startScale = (overviewScale * 1.70).clamp(0.45, 2.40); // Zoom cận cảnh điểm BẮT ĐẦU
    final double wideOverviewScale = overviewScale * 0.90; // Zoom nhỏ lại 1 tí để thấy hết toàn bộ quãng đường

    double camX;
    double camY;
    double camScale;
    double flightProgress;

    if (isFlycamMode) {
      // ==========================================
      // CHẾ ĐỘ VIDEO THEO DÕI (FLYCAM TRACKING)
      // ==========================================
      if (progress < 0.10) {
        // 1. Mới vô: Map nhỏ lại (Toàn cảnh) load được cả quãng đường đã chạy (~1.5s)
        flightProgress = 0.0;
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = overviewScale;
      } else if (progress < 0.18) {
        // 2. Sau 1.5s: Zoom mượt đến chỗ BẮT ĐẦU (~1.2s)
        flightProgress = 0.0;
        final double tTransit = Curves.easeInOutCubic.transform(((progress - 0.10) / 0.08).clamp(0.0, 1.0));
        camX = ui.lerpDouble(routeCenterX, startPinPixel.dx, tTransit)!;
        camY = ui.lerpDouble(routeCenterY, startPinPixel.dy, tTransit)!;
        camScale = ui.lerpDouble(overviewScale, chaseScale, tTransit)!;
      } else if (progress < 0.70) {
        // 3. Chạy theo dõi mượt mà từ điểm bắt đầu đến điểm KẾT THÚC (~7.8s)
        flightProgress = ((progress - 0.18) / 0.52).clamp(0.0, 1.0);
        final double fIndex = (sampledPositions.length - 1) * flightProgress;
        final int baseIdx = fIndex.floor().clamp(0, sampledPositions.length - 1);
        final int nextIdx = math.min(baseIdx + 1, sampledPositions.length - 1);
        final double subFrac = fIndex - baseIdx;
        final Offset smoothedCam = Offset.lerp(smoothedCamPositions[baseIdx], smoothedCamPositions[nextIdx], subFrac)!;

        camX = smoothedCam.dx;
        camY = smoothedCam.dy;
        camScale = chaseScale;
      } else if (progress < 0.75) {
        // 4. Về đích: Đợi 0.75s tại điểm KẾT THÚC (giữ nguyên góc nhìn camera đích)
        flightProgress = 1.0;
        final Offset lastCam = smoothedCamPositions.isNotEmpty ? smoothedCamPositions.last : finishPinPixel;
        camX = lastCam.dx;
        camY = lastCam.dy;
        camScale = chaseScale;
      } else if (progress < 0.85) {
        // 5. Sau 0.75s: Zoom nhỏ lại để xem toàn bộ quãng đường đã chạy (~1.5s)
        flightProgress = 1.0;
        final double tOverview = Curves.easeInOutCubic.transform(((progress - 0.75) / 0.10).clamp(0.0, 1.0));
        final Offset lastCam = smoothedCamPositions.isNotEmpty ? smoothedCamPositions.last : finishPinPixel;
        camX = ui.lerpDouble(lastCam.dx, routeCenterX, tOverview)!;
        camY = ui.lerpDouble(lastCam.dy, routeCenterY, tOverview)!;
        camScale = ui.lerpDouble(chaseScale, overviewScale, tOverview)!;
      } else {
        // 6. Để yên toàn cảnh tầm 2s và kết thúc (TĨNH 100%, KHÔNG CÓ HIỆU ỨNG RUNG LẮC)
        flightProgress = 1.0;
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = overviewScale;
      }
    } else {
      // ==========================================
      // CHẾ ĐỘ VIDEO TOÀN CẢNH (OVERVIEW TRACKING)
      // ==========================================
      if (progress < 0.10) {
        // 1. Mới vô: Map ở điểm BẮT ĐẦU (cận cảnh điểm bắt đầu), đợi tầm 1.5s
        flightProgress = 0.0;
        camX = startPinPixel.dx;
        camY = startPinPixel.dy;
        camScale = startScale;
      } else if (progress < 0.18) {
        // 2. Sau 1.5s: Zoom to lên mở rộng thấy được cả quãng đường đã chạy (~1.2s)
        flightProgress = 0.0;
        final double tTransit = Curves.easeInOutCubic.transform(((progress - 0.10) / 0.08).clamp(0.0, 1.0));
        camX = ui.lerpDouble(startPinPixel.dx, routeCenterX, tTransit)!;
        camY = ui.lerpDouble(startPinPixel.dy, routeCenterY, tTransit)!;
        camScale = ui.lerpDouble(startScale, overviewScale, tTransit)!;
      } else if (progress < 0.70) {
        // 3. Chạy trên toàn cảnh từ điểm bắt đầu đến điểm KẾT THÚC (~7.8s)
        flightProgress = ((progress - 0.18) / 0.52).clamp(0.0, 1.0);
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = overviewScale;
      } else if (progress < 0.75) {
        // 4. Về đích: Đợi 0.75s tại điểm KẾT THÚC
        flightProgress = 1.0;
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = overviewScale;
      } else if (progress < 0.85) {
        // 5. Sau 0.75s: Zoom nhỏ lại 1 tí thôi để xem được hết quãng đường đã chạy (~1.5s)
        flightProgress = 1.0;
        final double tOverview = Curves.easeInOutCubic.transform(((progress - 0.75) / 0.10).clamp(0.0, 1.0));
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = ui.lerpDouble(overviewScale, wideOverviewScale, tOverview)!;
      } else {
        // 6. Để yên toàn cảnh tầm 2s và kết thúc (TĨNH 100%, KHÔNG CÓ HIỆU ỨNG RUNG LẮC)
        flightProgress = 1.0;
        camX = routeCenterX;
        camY = routeCenterY;
        camScale = wideOverviewScale;
      }
    }

    final double currentDist = totalLength * flightProgress;

    final double fIndex = (sampledPositions.length - 1) * flightProgress.clamp(0.0, 1.0);
    final int baseIdx = fIndex.floor().clamp(0, sampledPositions.length - 1);
    final int nextIdx = math.min(baseIdx + 1, sampledPositions.length - 1);
    final double subFrac = fIndex - baseIdx;

    final Offset currentPixel = Offset.lerp(sampledPositions[baseIdx], sampledPositions[nextIdx], subFrac)!;
    final double runnerHeading = ui.lerpDouble(sampledHeadings[baseIdx], sampledHeadings[nextIdx], subFrac)!;
    final double outroT = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);

    // 3. ĐỘ DÀY NÉT VẼ TỰ ĐỘNG NỘI SUY THEO TỈ LỆ ZOOM (KÈM ZOOM TAY)
    final double effectiveCamScale = camScale * userScaleMultiplier;
    final double strokeBase = (3.6 / effectiveCamScale).clamp(2.4, 5.0);
    final double strokeCore = (1.4 / effectiveCamScale).clamp(0.9, 2.0);
    final double strokeShadow = (6.0 / effectiveCamScale).clamp(4.0, 8.5);

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

    // 4. MA TRẬN CAMERA CHUYÊN NGHIỆP (KẾT HỢP TỈ LỆ ZOOM & CĂN CHỈNH TAY CỦA NGƯỜI DÙNG)
    final double screenCenterX = size.width / 2 + userPanOffset.dx;
    final double screenCenterY = size.height * 0.52 + userPanOffset.dy;

    canvas.save();
    canvas.translate(screenCenterX, screenCenterY);
    canvas.scale(effectiveCamScale, effectiveCamScale);
    canvas.translate(-camX, -camY);

    // 5. VẼ MAP TILES GOOGLE MAPS BAO PHỦ VÙNG NHÌN THỰC TẾ (LOAD SIÊU TỐC, KHÔNG CÓ Ô ĐEN)
    final int centerTileX = (camX / tileSize).floor();
    final int centerTileY = (camY / tileSize).floor();
    final int tileRadiusX = (((size.width / 2) / effectiveCamScale) / tileSize).ceil().clamp(2, 6);
    final int tileRadiusY = (((size.height / 2) / effectiveCamScale) / tileSize).ceil().clamp(2, 7);

    // Nền đồng nhất liền mạch cho bản đồ trong tích tắc đang tải (Loại bỏ hoàn toàn ô đen)
    final Color mapBgColor = mapType == 'satellite'
        ? const Color(0xFF0F172A)
        : mapType == 'terrain'
            ? const Color(0xFFE2E8F0)
            : const Color(0xFFF1F5F9);
    final totalMapRect = Rect.fromLTRB(
      (centerTileX - tileRadiusX) * tileSize,
      (centerTileY - tileRadiusY) * tileSize,
      (centerTileX + tileRadiusX + 1) * tileSize,
      (centerTileY + tileRadiusY + 1) * tileSize,
    );
    canvas.drawRect(totalMapRect, Paint()..color = mapBgColor);

    for (int dx = -tileRadiusX; dx <= tileRadiusX; dx++) {
      for (int dy = -tileRadiusY; dy <= tileRadiusY + 1; dy++) {
        final tx = centerTileX + dx;
        final ty = centerTileY + dy;
        final key = '$mapType/$zoom/$tx/$ty';

        final tileRect = Rect.fromLTWH(tx * tileSize - 0.5, ty * tileSize - 0.5, tileSize + 1.0, tileSize + 1.0);

        if (tileCache.containsKey(key)) {
          final img = tileCache[key]!;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            tileRect,
            _tilePaint,
          );
        } else {
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

    final Offset finishBadgeOffset = isLoop ? const Offset(24, 0) : Offset.zero;
    canvas.save();
    canvas.translate(finishPinPixel.dx + finishBadgeOffset.dx, finishPinPixel.dy + finishBadgeOffset.dy);

    if (progress >= 0.58) {
      final double rippleT = ((progress - 0.58) * 8) % 1.0;
      canvas.drawCircle(
        const Offset(0, -22),
        14 + rippleT * 28,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: (1.0 - rippleT) * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(
        const Offset(0, -22),
        7 + rippleT * 15,
        Paint()
          ..color = const Color(0xFFFC5200).withValues(alpha: (1.0 - rippleT) * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
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
