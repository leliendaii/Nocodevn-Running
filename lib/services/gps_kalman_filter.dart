import 'package:geolocator/geolocator.dart';

/// Kết quả sau khi lọc qua 3 lớp Kalman
class FilteredGpsResult {
  final double latitude;
  final double longitude;
  final double distanceDeltaMeters;
  final double speedKmh;
  final String rollingPace;
  final bool isStationary;
  final bool isValidMovement;

  const FilteredGpsResult({
    required this.latitude,
    required this.longitude,
    required this.distanceDeltaMeters,
    required this.speedKmh,
    required this.rollingPace,
    required this.isStationary,
    required this.isValidMovement,
  });
}

/// Phần tử lưu vết trong cửa sổ trượt 10 giây để tính Pace siêu mượt
class _PaceWindowEntry {
  final DateTime timestamp;
  final double distanceMeters;

  _PaceWindowEntry(this.timestamp, this.distanceMeters);
}

/// BỘ LỌC GPS KALMAN 3 LỚP CHUẨN THỂ THAO CHUYÊN NGHIỆP (GARMIN / STRAVA)
class GpsKalmanFilter {
  // Lớp 2: Tham số Kalman Filter (Vị trí & Phương sai)
  double? _lat;
  double? _lng;
  double _variance = -1.0;
  DateTime? _lastTimestamp;

  // Lớp 3: Cửa sổ trượt 10 giây tính Pace
  final List<_PaceWindowEntry> _rollingWindow = [];
  static const int _rollingWindowSeconds = 10;

  // Trạng thái đứng yên (Stationary / Anti-Drift)
  int _consecutiveStationaryCount = 0;
  int _consecutiveOutlierCount = 0;
  bool _isAutoPaused = false;

  // Hằng số giới hạn vật lý
  static const double _maxValidAccuracyMeters = 35.0; // Bỏ qua tọa độ có sai số quá tệ > 35m
  static const double _maxRunningSpeedMps = 20.0;     // 72 km/h (cho phép bứt tốc / chạy xe đạp mà không bị block)
  static const double _stationarySpeedKmh = 1.2;      // < 1.2 km/h coi là đứng yên

  bool get isAutoPaused => _isAutoPaused;

  /// Đặt lại toàn bộ bộ lọc khi bắt đầu phiên chạy mới
  void reset() {
    _lat = null;
    _lng = null;
    _variance = -1.0;
    _lastTimestamp = null;
    _rollingWindow.clear();
    _consecutiveStationaryCount = 0;
    _consecutiveOutlierCount = 0;
    _isAutoPaused = false;
  }

  /// Xử lý tọa độ GPS đầu vào qua 3 Lớp lọc độc lập
  FilteredGpsResult processPosition(Position rawPos) {
    final now = DateTime.now();

    final double timeDeltaSec = _lastTimestamp != null
        ? (now.difference(_lastTimestamp!).inMilliseconds / 1000.0).clamp(0.1, 60.0)
        : 1.0;

    // ==========================================================
    // LỚP 1: LỌC ĐỘ CHÍNH XÁC VẬT LÝ (PHYSICAL BOUNDS FILTER)
    // ==========================================================
    // Nếu sai số GPS quá lớn (> 35m), nhưng nếu đã quá 5s chưa có điểm mới thì vẫn chấp nhận để không bị đứng hình
    if (rawPos.accuracy > _maxValidAccuracyMeters && timeDeltaSec < 5.0) {
      return FilteredGpsResult(
        latitude: _lat ?? rawPos.latitude,
        longitude: _lng ?? rawPos.longitude,
        distanceDeltaMeters: 0.0,
        speedKmh: 0.0,
        rollingPace: _getRollingPace(0.0, now),
        isStationary: true,
        isValidMovement: false,
      );
    }

    // Nếu là điểm đầu tiên
    if (_lat == null || _lng == null || _variance < 0.0) {
      _lat = rawPos.latitude;
      _lng = rawPos.longitude;
      _variance = rawPos.accuracy * rawPos.accuracy;
      _lastTimestamp = now;
      _consecutiveOutlierCount = 0;
      _consecutiveStationaryCount = 0;
      _isAutoPaused = false;

      return FilteredGpsResult(
        latitude: _lat!,
        longitude: _lng!,
        distanceDeltaMeters: 0.0,
        speedKmh: 0.0,
        rollingPace: '0:00',
        isStationary: false,
        isValidMovement: true,
      );
    }

    // Khoảng cách thô từ điểm trước đến điểm mới
    final double rawDistanceMeters = Geolocator.distanceBetween(
      _lat!,
      _lng!,
      rawPos.latitude,
      rawPos.longitude,
    );

    final double calcSpeedMps = rawDistanceMeters / timeDeltaSec;

    // ==========================================================
    // CHỐNG DEADLOCK NHẢY TỌA ĐỘ KHI CHẠY NHANH HOẶC GPS TRỄ NHỊP
    // ==========================================================
    if (calcSpeedMps > _maxRunningSpeedMps) {
      // Nếu chỉ là 1 xung nhiễu đơn lẻ trong thời gian ngắn -> bỏ qua 1 lần
      if (_consecutiveOutlierCount < 2 && timeDeltaSec < 4.0) {
        _consecutiveOutlierCount++;
        _lastTimestamp = now;
        return FilteredGpsResult(
          latitude: _lat!,
          longitude: _lng!,
          distanceDeltaMeters: 0.0,
          speedKmh: 0.0,
          rollingPace: _getRollingPace(0.0, now),
          isStationary: true,
          isValidMovement: false,
        );
      }

      // NẾU 2 ĐIỂM LIÊN TIẾP ĐỀU XA HOẶC KHOẢNG THỜI GIAN ĐÃ > 4S:
      // Người dùng THỰC SỰ đã di chuyển đến vị trí mới -> Đồng bộ ngay, không để kẹt vòng lặp vô tận!
      _lat = rawPos.latitude;
      _lng = rawPos.longitude;
      _variance = rawPos.accuracy * rawPos.accuracy;
      _consecutiveOutlierCount = 0;
      _consecutiveStationaryCount = 0;
      _isAutoPaused = false;
      _lastTimestamp = now;

      final double recoveredDist = (calcSpeedMps * timeDeltaSec).clamp(0.0, 100.0);
      final double currentSpeed = (rawPos.speed >= 0.0 && rawPos.speedAccuracy <= 5.0)
          ? rawPos.speed * 3.6
          : (recoveredDist / timeDeltaSec) * 3.6;

      return FilteredGpsResult(
        latitude: _lat!,
        longitude: _lng!,
        distanceDeltaMeters: recoveredDist,
        speedKmh: currentSpeed.clamp(0.0, 72.0),
        rollingPace: _getRollingPace(recoveredDist, now),
        isStationary: false,
        isValidMovement: true,
      );
    }

    _consecutiveOutlierCount = 0;

    // ==========================================================
    // LỚP 2: BỘ LỌC KALMAN 2D & CHỐNG SỤP ĐỔ PHƯƠNG SAI (ANTI-COLLAPSE)
    // ==========================================================
    // Cập nhật phương sai mô hình theo thời gian (Process noise Q)
    const double qProcessNoise = 3.0; // m/s^2
    _variance += timeDeltaSec * qProcessNoise * qProcessNoise;

    // Tính Kalman Gain K: K = Var / (Var + R)
    final double measurementNoiseR = rawPos.accuracy * rawPos.accuracy;
    // Giữ kalmanGain trong khoảng 0.08 đến 0.92 để luôn luôn nhạy bén với vị trí mới khi bắt đầu chạy lại
    final double kalmanGain = (_variance / (_variance + measurementNoiseR)).clamp(0.08, 0.92);

    // Cập nhật tọa độ tối ưu theo Kalman
    final double filteredLat = _lat! + kalmanGain * (rawPos.latitude - _lat!);
    final double filteredLng = _lng! + kalmanGain * (rawPos.longitude - _lng!);
    _variance = (1.0 - kalmanGain) * _variance;
    // Đảm bảo phương sai không bao giờ tụt về 0 khi đứng yên (ngăn chặn đứng hình khi chạy tiếp)
    if (_variance < 4.0) _variance = 4.0;

    // Tính khoảng cách di chuyển thực sau khi nắn bởi Kalman
    final double filteredDistanceMeters = Geolocator.distanceBetween(
      _lat!,
      _lng!,
      filteredLat,
      filteredLng,
    );

    // Tốc độ phần cứng GPS của điện thoại hoặc tốc độ tính toán
    final double bestSpeedKmh = (rawPos.speed >= 0.0 && rawPos.speedAccuracy >= 0.0 && rawPos.speedAccuracy <= 5.0)
        ? rawPos.speed * 3.6
        : (rawDistanceMeters / timeDeltaSec) * 3.6;

    // NHẬN DIỆN DI CHUYỂN: Có vận tốc >= 1.2 km/h hoặc dịch chuyển thô >= 1.5m
    final bool isMoving = bestSpeedKmh >= _stationarySpeedKmh || rawDistanceMeters >= 1.5;
    final bool isStationary = !isMoving;

    if (isStationary) {
      _consecutiveStationaryCount++;
      // Đứng yên liên tục từ 3 lần đọc trở lên mới bật Auto-Pause
      if (_consecutiveStationaryCount >= 3) {
        _isAutoPaused = true;
      }
    } else {
      // NGAY KHI BẮT ĐẦU CHẠY LẠI: Mở khóa tức thì, xóa Auto-Pause ngay lập tức!
      _consecutiveStationaryCount = 0;
      _isAutoPaused = false;
    }

    // ==========================================================
    // LỚP 3: TÍNH TOÁN ROLLING PACE 10 GIÂY SIÊU MƯỢT
    // ==========================================================
    double validDist = 0.0;
    double effectiveSpeedKmh = 0.0;

    if (isMoving) {
      validDist = filteredDistanceMeters;
      effectiveSpeedKmh = bestSpeedKmh.clamp(0.0, 72.0);
      _lat = filteredLat;
      _lng = filteredLng;
    } else {
      validDist = 0.0;
      effectiveSpeedKmh = 0.0;
    }
    _lastTimestamp = now;

    final String smoothPace = _getRollingPace(validDist, now);

    return FilteredGpsResult(
      latitude: _lat!,
      longitude: _lng!,
      distanceDeltaMeters: validDist,
      speedKmh: effectiveSpeedKmh,
      rollingPace: smoothPace,
      isStationary: isStationary,
      isValidMovement: isMoving,
    );
  }

  /// Thuật toán cửa sổ trượt 10 giây tính Pace trung bình làm mịn không gián đoạn
  String _getRollingPace(double addedDistanceMeters, DateTime now) {
    _rollingWindow.add(_PaceWindowEntry(now, addedDistanceMeters));

    // Loại bỏ các mẫu cũ quá 10 giây
    final cutoffTime = now.subtract(const Duration(seconds: _rollingWindowSeconds));
    _rollingWindow.removeWhere((entry) => entry.timestamp.isBefore(cutoffTime));

    if (_rollingWindow.length < 2) return '0:00';

    double totalDistM = 0.0;
    for (final entry in _rollingWindow) {
      totalDistM += entry.distanceMeters;
    }

    final int windowSeconds = now.difference(_rollingWindow.first.timestamp).inSeconds.clamp(1, _rollingWindowSeconds);

    if (totalDistM < 1.5 || windowSeconds <= 0) {
      return '0:00';
    }

    final double distKm = totalDistM / 1000.0;
    final double paceMinPerKm = (windowSeconds / 60.0) / distKm;

    // Giới hạn hiển thị Pace thực tế trong khoảng 2:00/km đến 25:00/km
    if (paceMinPerKm < 2.0 || paceMinPerKm > 25.0) {
      return '0:00';
    }

    final int min = paceMinPerKm.floor();
    final int sec = ((paceMinPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
