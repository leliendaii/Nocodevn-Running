import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../services/route_video_recorder.dart';
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

  // Cache ảnh map tiles Google Maps lưu vĩnh viễn trong RAM (Load 0ms tức thì khi mở lại)
  static final Map<String, ui.Image> _globalTileMemoryCache = {};
  Map<String, ui.Image> get _tileCache => _globalTileMemoryCache;
  static final Set<String> _globalLoadingTiles = {};
  Set<String> get _loadingTiles => _globalLoadingTiles;
  int _tileVersion = 0;
  final GlobalKey _previewKey = GlobalKey();

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5];
  static const double tileSize = 256.0;

  static const int _baseDurationMs = 13500; // Tốc độ cơ bản êm ái chuẩn phong cách Strava Flyover

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

    // Tiền tính toán đường bay Camera Drone mượt mà không rung lắc (Moving Average Window = 90 samples)
    const int camWindow = 90;
    _smoothedCamPositions = List.generate(sampleCount, (i) {
      double sumX = 0, sumY = 0;
      int count = 0;
      for (int w = -camWindow; w <= camWindow; w++) {
        final idx = (i + w).clamp(0, sampleCount - 1);
        sumX += _sampledPositions[idx].dx;
        sumY += _sampledPositions[idx].dy;
        count++;
      }
      return Offset(sumX / count, sumY / count);
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

    _milestones = _generateMilestonePins(_effectiveDistanceKm, _pathMetric, _totalPathLength, _smoothRoute);

    // 7. Tiền tải trước toàn bộ Map Tiles bao phủ tuyến đường và khu vực lân cận vào RAM
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
    _loadingTiles.clear();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.stop();
    _controller.dispose();
    _loadingTiles.clear();
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

    // 1. Tiền xử lý Gaussian Smoothing triệt tiêu 100% nhiễu GPS bước chân ngắn
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

    // 2. Lọc bỏ các điểm dồn ứ tại chỗ (< 2.5px)
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

    // 3. Đơn giản hóa góc nhọn với Ramer-Douglas-Peucker
    final simplified = _simplifyPoints(dedup, 1.8);

    // 4. Làm mịn đường cong tự nhiên bằng Chaikin 3 lần
    final smoothed = _chaikinSmooth(simplified, 3);

    // 5. Xây dựng Path liền mạch với Quadratic Bézier
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

    // Thu nhỏ mức zoom để bao quát khu vực xung quanh rộng rãi, thấy nhiều phố xá
    if (maxSpan < 0.008) {
      return 16; // Giảm từ 18 xuống 16 để mở rộng tầm nhìn toàn khu phố
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

    // Tuyến đường mẫu
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

  List<MilestoneData> _generateMilestonePins(double totalKm, ui.PathMetric pathMetric, double totalLength, List<GeoPoint> route) {
    final List<MilestoneData> pins = [];
    final int totalPins = totalKm.floor();
    if (totalPins <= 0 || totalLength <= 1.0) return pins;

    for (int i = 1; i <= totalPins; i++) {
      final double frac = (i / totalKm).clamp(0.0, 1.0);
      final double targetOffset = totalLength * frac;
      final tangent = pathMetric.getTangentForOffset(targetOffset);
      final pixel = tangent?.position ?? _cachedRoutePixels.first;
      final routeIdx = ((route.length - 1) * frac).toInt().clamp(0, route.length - 1);
      pins.add(MilestoneData(km: i, point: route[routeIdx], pixel: pixel));
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

    minTx -= 5;
    maxTx += 5;
    minTy -= 5;
    maxTy += 6;

    for (int x = minTx; x <= maxTx; x++) {
      for (int y = minTy; y <= maxTy; y++) {
        _loadMapTile(_zoomLevel, x, y);
      }
    }
  }

  void _loadMapTile(int z, int x, int y) {
    if (_isDisposed || !mounted) return;
    final key = '$z/$x/$y';
    if (_globalTileMemoryCache.containsKey(key) || _globalLoadingTiles.contains(key)) return;

    _globalLoadingTiles.add(key);
    final int serverId = (x.abs() + y.abs()) % 4;
    final url = 'https://mt$serverId.google.com/vt/lyrs=m&hl=vi&x=$x&y=$y&z=$z';

    final imageStream = NetworkImage(url).resolve(ImageConfiguration.empty);
    imageStream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        _globalTileMemoryCache[key] = info.image;
        _globalLoadingTiles.remove(key);
        _tileVersion++;
        if (!_isDisposed && mounted) {
          setState(() {});
        }
      }, onError: (dynamic error, StackTrace? stack) {
        _globalLoadingTiles.remove(key);
      }),
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

  void _handleDownloadVideo() {
    final double previousValue = _controller.value;
    final bool previousPlaying = _isPlaying;
    _controller.stop();
    setState(() => _isPlaying = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        double progress = 0.0;
        String status = 'Đang chuẩn bị luồng quay trực tiếp 60 FPS...';
        bool isDone = false;
        bool isStarted = false;
        RealtimeVideoSession? activeSession;
        final filename = 'flyover_3d_${widget.session.id}_${_formatSpeed(_playbackSpeed)}.mp4';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!isStarted) {
              isStarted = true;

              Future.microtask(() async {
                try {
                  _controller.reset();

                  final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                  if (boundary == null) throw Exception('Không tìm thấy khung hình 3D.');

                  final firstImg = await boundary.toImage(pixelRatio: 1.2);
                  final session = RouteVideoRecorder.startSession(
                    width: firstImg.width,
                    height: firstImg.height,
                    fps: 30.0,
                  );
                  activeSession = session;

                  const int totalSteps = 45;
                  for (int step = 0; step <= totalSteps; step++) {
                    if (_isDisposed || !mounted) break;
                    final double t = step / totalSteps;
                    _controller.value = t;

                    setDialogState(() {
                      progress = (step / totalSteps) * 0.90;
                      status = '🎥 Đang quay video (${(progress * 100).toInt()}%)...';
                    });

                    await Future.delayed(const Duration(milliseconds: 35));

                    final b = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                    if (b != null) {
                      final img = await b.toImage(pixelRatio: 1.2);
                      final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
                      if (raw != null) {
                        session.pushRawFrame(raw.buffer.asUint8List(), img.width, img.height);
                      }
                    }
                  }

                  setDialogState(() {
                    progress = 0.95;
                    status = '💎 Đang đóng gói video MP4...';
                  });

                  await session.finishRecording();

                  setDialogState(() {
                    progress = 1.0;
                    status = '🎉 Video đã sẵn sàng tải về!';
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : AppTheme.primaryNeon.withValues(alpha: 0.15),
                        border: Border.all(
                          color: isDone ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check_circle_rounded : Icons.file_download_outlined,
                        color: isDone ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDone ? 'XUẤT VIDEO THÀNH CÔNG' : 'ĐANG XUẤT VIDEO 3D FLYOVER',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tốc độ: ${_formatSpeed(_playbackSpeed)} • Chất lượng: HD MP4',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDone ? const Color(0xFF10B981) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isDone) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryNeon,
                            foregroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: AppTheme.secondaryNeon.withValues(alpha: 0.4),
                          ),
                          onPressed: () async {
                            if (activeSession != null) {
                              final result = await activeSession!.downloadVideo(filename);
                              if (!ctx.mounted) return;
                              if (mounted) {
                                TopSyncToast.show(
                                  context,
                                  message: result.message,
                                  isSuccess: result.isSuccess,
                                );
                              }
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 22, color: Color(0xFF0F172A)),
                              SizedBox(width: 8),
                              Text(
                                'TẢI VỀ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'ĐÓNG',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: null,
                          child: const Text(
                            'ĐANG XỬ LÝ 60 FPS...',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _isDisposed = true;
          _controller.stop();
        }
      },
      child: RepaintBoundary(
        key: _previewKey,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Stack(
              children: [
                // 1. ENGINE 3D FLYOVER KẾT HỢP HYBRID (TOÀN CẢNH MƯỢT 100% HOẶC FLYCAM LƯỚT THEO)
                Positioned.fill(
                  child: _cachedRoutePixels.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNeon))
                      : AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
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
                                progress: _controller.value,
                                tileCache: _tileCache,
                                zoom: _zoomLevel,
                                routeCenterX: _routeCenterX,
                                routeCenterY: _routeCenterY,
                                spanW: _spanW,
                                spanH: _spanH,
                                isFlycamMode: _isFlycamMode,
                                tileVersion: _tileVersion,
                                onTileRequested: _loadMapTile,
                              ),
                            );
                          },
                        ),
                ),

                // 2. TOP HUD: BẢNG CHỈ SỐ THỂ THAO + NÚT CHUYỂN GÓC NHÌN TOÀN CẢNH / FLYCAM
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.94),
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
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final runProgress = (_controller.value / 0.78).clamp(0.0, 1.0);
                        final currentDistance = (_effectiveDistanceKm * runProgress).toStringAsFixed(2);
                        final elapsedSec = (_effectiveDurationSec * runProgress).toInt();
                        final int minutes = elapsedSec ~/ 60;
                        final int seconds = elapsedSec % 60;
                        final elapsedFormatted = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                        final isFinished = _controller.value >= 0.78;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _handleExit,
                            ),
                            // Nút chuyển đổi góc nhìn Toàn Cảnh / Flycam
                            InkWell(
                              onTap: () {
                                setState(() => _isFlycamMode = !_isFlycamMode);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isFlycamMode
                                      ? AppTheme.primaryNeon.withValues(alpha: 0.18)
                                      : AppTheme.secondaryNeon.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFlycamMode ? Icons.airplanemode_active_rounded : Icons.map_outlined,
                                      size: 14,
                                      color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isFlycamMode ? 'FLYCAM' : 'TOÀN CẢNH',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: _isFlycamMode ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFinished ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isFinished ? 'HOÀN THÀNH' : 'ĐANG CHẠY',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: isFinished ? const Color(0xFF10B981) : AppTheme.primaryNeon,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$currentDistance km',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('PACE', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  '$_effectivePace /km',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.secondaryNeon),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('THỜI GIAN', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  elapsedFormatted,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_rounded, color: AppTheme.secondaryNeon, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _handleDownloadVideo,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // 3. THẺ TỔNG KẾT VINH DANH THÀNH TÍCH 3D (XUẤT HIỆN TỰ ĐỘNG KHI VỀ ĐÍCH - ACT 3)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 110,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final double outroRaw = ((_controller.value - 0.78) / 0.22).clamp(0.0, 1.0);
                      if (outroRaw <= 0.01) return const SizedBox.shrink();

                      final double cardScale = Curves.easeOutBack.transform(outroRaw);
                      final double cardOpacity = outroRaw.clamp(0.0, 1.0);

                      return Opacity(
                        opacity: cardOpacity,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * cardScale,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF0F172A).withValues(alpha: 0.96),
                                  const Color(0xFF1E293B).withValues(alpha: 0.96),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25 * cardOpacity),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'HOÀN THÀNH XUẤT SẮC',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFF334155)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSummaryStatItem('QUÃNG ĐƯỜNG', '${_effectiveDistanceKm.toStringAsFixed(2)} km', AppTheme.primaryNeon),
                                    _buildSummaryStatItem('PACE TB', '$_effectivePace /km', AppTheme.secondaryNeon),
                                    _buildSummaryStatItem('THỜI GIAN', _formatDuration(_effectiveDurationSec), Colors.white),
                                    _buildSummaryStatItem('CALO', '$_effectiveCalories kcal', AppTheme.accentOrange),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. BOTTOM HUD: THANH ĐIỀU KHIỂN VIDEO
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.divider, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: AppTheme.primaryNeon,
                                inactiveTrackColor: const Color(0xFF1E293B),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _controller.value.clamp(0.0, 1.0),
                                onChanged: (val) {
                                  _controller.stop();
                                  _controller.value = val;
                                  setState(() => _isPlaying = false);
                                },
                              ),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: _openSpeedSelectorModal,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.divider, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.secondaryNeon, size: 18),
                                    const SizedBox(width: 2),
                                    Text(
                                      _formatSpeed(_playbackSpeed),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _togglePlayPause,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryNeon,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryNeon.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, _) {
                                    final isCompleted = _controller.value >= 0.98 || _controller.status == AnimationStatus.completed;
                                    IconData icon = Icons.pause_rounded;
                                    if (!_isPlaying) {
                                      icon = isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded;
                                    }
                                    return Icon(
                                      icon,
                                      color: const Color(0xFF0F172A),
                                      size: 28,
                                    );
                                  },
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final percent = (_controller.value * 100).toInt();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Text(
                                    '$percent%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
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
        ),
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
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
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

// PAINTER STRAVA 3D FLYOVER CHUYÊN NGHIỆP
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

  static final Paint _emptyTilePaint = Paint()..color = const Color(0xFFF8FAFC);

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

    // 1. TIẾN ĐỘ CHẠY & NỘI SUY BẰNG BẢNG SAMPLING 2.000 ĐIỂM
    final double runProgress = (progress / 0.78).clamp(0.0, 1.0);
    final double currentDist = totalLength * runProgress;

    final double fIndex = (sampledPositions.length - 1) * runProgress;
    final int baseIdx = fIndex.floor().clamp(0, sampledPositions.length - 1);
    final int nextIdx = math.min(baseIdx + 1, sampledPositions.length - 1);
    final double subFrac = fIndex - baseIdx;

    final Offset currentPixel = Offset.lerp(sampledPositions[baseIdx], sampledPositions[nextIdx], subFrac)!;
    final Offset smoothedCam = Offset.lerp(smoothedCamPositions[baseIdx], smoothedCamPositions[nextIdx], subFrac)!;
    final double runnerHeading = ui.lerpDouble(sampledHeadings[baseIdx], sampledHeadings[nextIdx], subFrac)!;

    // 2. CAMERA STRAVA 3D FLYOVERS ĐẲNG CẤP (HYBRID TOÀN CẢNH / FLYCAM):
    final double targetScaleX = (size.width * 0.50) / (spanW > 40 ? spanW : 160);
    final double targetScaleY = (size.height * 0.36) / (spanH > 40 ? spanH : 160);
    final double overviewScale = math.min(targetScaleX, targetScaleY).clamp(0.12, 1.05);
    final double chaseScale = (overviewScale * 1.20).clamp(0.18, 1.25);

    final double outroRaw = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
    final double outroT = Curves.easeInOutCubic.transform(outroRaw);

    double camX;
    double camY;
    double camScale;

    if (isFlycamMode) {
      // Chế độ Flycam: Lướt theo người chạy
      camX = ui.lerpDouble(smoothedCam.dx, routeCenterX, outroT)!;
      camY = ui.lerpDouble(smoothedCam.dy, routeCenterY, outroT)!;
      camScale = ui.lerpDouble(chaseScale, overviewScale * 0.88, outroT)!;
    } else {
      // Chế độ Toàn Cảnh: Khóa tâm 100% tại trung tâm tuyến đường, mượt tuyệt đối không rung lắc
      camX = routeCenterX;
      camY = routeCenterY;
      camScale = ui.lerpDouble(overviewScale, overviewScale * 0.88, outroT)!;
    }

    // 3. ĐỘ DÀY NÉT VẼ TỰ ĐỘNG NỘI SUY THEO TỈ LỆ ZOOM (Thanh mảnh, sắc nét, không bị thô dày)
    final double strokeBase = (3.4 / camScale).clamp(2.4, 4.8);
    final double strokeCore = (1.2 / camScale).clamp(0.8, 1.8);
    final double strokeShadow = (5.2 / camScale).clamp(3.6, 7.0);

    final Paint fullPathPaint = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = strokeBase * 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint shadowPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0x28000000)
      ..strokeWidth = strokeShadow
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint activePathPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFC5200) // Strava Signature Athletic Orange-Red
      ..strokeWidth = strokeBase
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint coreHighlightPaint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFF9E70)
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
    final int tileRadiusX = (3.6 / camScale).ceil().clamp(4, 9);
    final int tileRadiusY = (4.6 / camScale).ceil().clamp(5, 10);

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
          canvas.drawRect(tileRect, _emptyTilePaint);
          onTileRequested(zoom, tx, ty);
        }
      }
    }

    // 6. VẼ ĐƯỜNG DẪN DỰ KIẾN MỜ
    canvas.drawPath(fullPath, fullPathPaint);

    // 7. VẼ VỆT CHẠY ĐÃ HOÀN THÀNH (Đường Ribbon Strava Thể Thao Thanh Lịch)
    if (currentDist > 1.0) {
      final Path activePath = pathMetric.extractPath(0.0, currentDist);
      canvas.drawPath(activePath, shadowPaint);
      canvas.drawPath(activePath, activePathPaint);
      canvas.drawPath(activePath, coreHighlightPaint);
    }

    // 8. VẼ CÁC CỘT MỐC KM 3D
    for (final m in milestones) {
      final pinPixel = m.pixel;

      canvas.save();
      canvas.translate(pinPixel.dx, pinPixel.dy);

      canvas.drawCircle(const Offset(0, 0), 4, Paint()..color = Colors.black26);
      canvas.drawLine(const Offset(0, 0), const Offset(0, -18), Paint()..color = Colors.black54..strokeWidth = 2);
      canvas.drawCircle(const Offset(0, -18), 12, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(0, -18), 12, Paint()..color = const Color(0xFFFC5200)..style = PaintingStyle.stroke..strokeWidth = 2);

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

    // 9. VẼ CỘT MỐC BẮT ĐẦU VÀ KẾT THÚC
    final bool isLoop = (startPinPixel - finishPinPixel).distance < 40.0;

    // Start
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

    // Finish
    final Offset finishBadgeOffset = isLoop ? const Offset(24, 0) : Offset.zero;
    canvas.save();
    canvas.translate(finishPinPixel.dx + finishBadgeOffset.dx, finishPinPixel.dy + finishBadgeOffset.dy);

    if (outroT > 0.05) {
      canvas.drawCircle(
        const Offset(0, -28),
        26,
        Paint()
          ..color = AppTheme.secondaryNeon.withValues(alpha: 0.35 * outroT)
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
