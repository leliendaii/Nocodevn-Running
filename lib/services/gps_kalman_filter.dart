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
  bool _isAutoPaused = false;

  // Hằng số giới hạn vật lý
  static const double _maxValidAccuracyMeters = 25.0; // Bỏ qua tọa độ có sai số > 25m
  static const double _maxRunningSpeedMps = 12.5;     // 45 km/h (giới hạn tối đa người chạy)
  static const double _stationarySpeedKmh = 1.0;      // < 1 km/h coi là đứng yên
  static const double _minDisplacementMeters = 1.0;   // Dịch chuyển tối thiểu 1.0m mới tính KM

  bool get isAutoPaused => _isAutoPaused;

  /// Đặt lại toàn bộ bộ lọc khi bắt đầu phiên chạy mới
  void reset() {
    _lat = null;
    _lng = null;
    _variance = -1.0;
    _lastTimestamp = null;
    _rollingWindow.clear();
    _consecutiveStationaryCount = 0;
    _isAutoPaused = false;
  }

  /// Xử lý tọa độ GPS đầu vào qua 3 Lớp lọc độc lập
  FilteredGpsResult processPosition(Position rawPos) {
    final now = DateTime.now();

    // ==========================================================
    // LỚP 1: LỌC ĐỘ CHÍNH XÁC VẬT LÝ (PHYSICAL BOUNDS FILTER)
    // ==========================================================
    if (rawPos.accuracy > _maxValidAccuracyMeters) {
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

    final double timeDeltaSec = _lastTimestamp != null
        ? (now.difference(_lastTimestamp!).inMilliseconds / 1000.0).clamp(0.1, 60.0)
        : 1.0;

    // Khoảng cách thô từ điểm trước đến điểm mới
    final double rawDistanceMeters = Geolocator.distanceBetween(
      _lat!,
      _lng!,
      rawPos.latitude,
      rawPos.longitude,
    );

    final double calcSpeedMps = rawDistanceMeters / timeDeltaSec;

    // Loại bỏ bước nhảy tức thời bất thường (> 45 km/h) do lỗi nhảy sóng vệ tinh
    if (calcSpeedMps > _maxRunningSpeedMps) {
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

    // ==========================================================
    // LỚP 2: BỘ LỌC KALMAN 2D & TRIỆT TIÊU RUNG LẮC ĐỨNG YÊN
    // ==========================================================
    // Cập nhật phương sai mô hình theo thời gian (Process noise Q)
    const double qProcessNoise = 3.0; // m/s^2
    _variance += timeDeltaSec * qProcessNoise * qProcessNoise;

    // Tính Kalman Gain K: K = Var / (Var + R)
    final double measurementNoiseR = rawPos.accuracy * rawPos.accuracy;
    final double kalmanGain = _variance / (_variance + measurementNoiseR);

    // Cập nhật tọa độ tối ưu theo Kalman
    final double filteredLat = _lat! + kalmanGain * (rawPos.latitude - _lat!);
    final double filteredLng = _lng! + kalmanGain * (rawPos.longitude - _lng!);
    _variance = (1.0 - kalmanGain) * _variance;

    // Tính khoảng cách di chuyển thực sau khi nắn bởi Kalman
    final double filteredDistanceMeters = Geolocator.distanceBetween(
      _lat!,
      _lng!,
      filteredLat,
      filteredLng,
    );

    final double hwSpeedKmh = (rawPos.speed >= 0.0 && rawPos.speedAccuracy <= 4.0)
        ? rawPos.speed * 3.6
        : (filteredDistanceMeters / timeDeltaSec) * 3.6;

    // Kiểm tra trạng thái đứng yên (Stationary / Anti-Drift)
    final bool isStationary = (filteredDistanceMeters < _minDisplacementMeters && hwSpeedKmh < _stationarySpeedKmh) ||
        (filteredDistanceMeters < 0.5);

    if (isStationary) {
      _consecutiveStationaryCount++;
      if (_consecutiveStationaryCount >= 3) {
        _isAutoPaused = true;
      }
    } else {
      _consecutiveStationaryCount = 0;
      _isAutoPaused = false;
    }

    // ==========================================================
    // LỚP 3: TÍNH TOÁN ROLLING PACE 10 GIÂY SIÊU MƯỢT
    // ==========================================================
    final double validDist = isStationary ? 0.0 : filteredDistanceMeters;
    final double effectiveSpeedKmh = isStationary ? 0.0 : hwSpeedKmh.clamp(0.0, 45.0);

    if (!isStationary) {
      _lat = filteredLat;
      _lng = filteredLng;
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
      isValidMovement: !isStationary,
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

    // Giới hạn hiển thị Pace thực tế trong khoảng 2:30/km đến 20:00/km
    if (paceMinPerKm < 2.5 || paceMinPerKm > 22.0) {
      return '0:00';
    }

    final int min = paceMinPerKm.floor();
    final int sec = ((paceMinPerKm - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
