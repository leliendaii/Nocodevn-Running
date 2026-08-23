import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/run_session.dart';
import '../services/supabase_service.dart';

enum TrackingState { idle, running, paused, finished }

enum TimeFilter { day, week, month, year }

class ChartDataPoint {
  final String label;
  final double distanceKm;
  final double durationMinutes;

  const ChartDataPoint({
    required this.label,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RunningProvider with ChangeNotifier {
  // Trạng thái buổi chạy hiện tại
  TrackingState _state = TrackingState.idle;
  int _durationSeconds = 0;
  double _distanceKm = 0.0;
  int _calories = 0;
  DateTime? _runStartTime;
  DateTime? _pauseStartTime;
  int _totalPausedSeconds = 0;
  Timer? _timer;
  final List<RunPoint> _currentRoute = [];
  Position? _lastPosition;
  StreamSubscription<Position>? _positionStream;

  // Danh sách toàn bộ lịch sử các buổi chạy (có sẵn dữ liệu mẫu thực tế)
  final List<RunSession> _sessions = [];

  RunningProvider() {
    _initMockData();
    _loadCloudSessions();
  }

  Future<void> _loadCloudSessions() async {
    final cloudList = await SupabaseService.fetchRunSessions();
    if (cloudList != null && cloudList.isNotEmpty) {
      _sessions.clear();
      _sessions.addAll(cloudList);
      notifyListeners();
    }
  }

  // Getters cho buổi chạy hiện tại
  TrackingState get state => _state;
  bool get isRunning => _state == TrackingState.running;
  bool get isPaused => _state == TrackingState.paused;
  bool get isIdle => _state == TrackingState.idle;
  int get durationSeconds => _durationSeconds;
  double get distanceKm => _distanceKm;
  int get calories => _calories;
  List<RunPoint> get currentRoute => List.unmodifiable(_currentRoute);
  List<RunSession> get allSessions => List.unmodifiable(_sessions);

  String get currentPace {
    if (_distanceKm <= 0.01 || _durationSeconds <= 0) return '0:00';
    final double pace = (_durationSeconds / 60.0) / _distanceKm;
    final int min = pace.floor();
    final int sec = ((pace - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedCurrentDuration {
    final int hours = _durationSeconds ~/ 3600;
    final int minutes = (_durationSeconds % 3600) ~/ 60;
    final int seconds = _durationSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _updateDurationFromWallClock() {
    if (_state == TrackingState.running && _runStartTime != null) {
      final elapsed = DateTime.now().difference(_runStartTime!).inSeconds;
      _durationSeconds = (elapsed - _totalPausedSeconds).clamp(0, 99999999);
    }
  }

  // Bắt đầu chạy đo GPS thực tế & Hỗ trợ chạy ngầm khi tắt màn hình iPhone
  Future<void> startTracking() async {
    _state = TrackingState.running;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _runStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    _currentRoute.clear();
    _lastPosition = null;

    // Timer cập nhật thời gian theo đồng hồ thực tế (Wall-clock)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == TrackingState.running) {
        _updateDurationFromWallClock();
        notifyListeners();
      }
    });

    // Lắng nghe tín hiệu GPS thực tế và chạy ngầm trên iPhone
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        
        // Cấu hình GPS nền chuyên dụng cho iOS (AppleSettings) và các nền tảng khác
        LocationSettings locationSettings;
        if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          locationSettings = AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            distanceFilter: 2,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );
        } else {
          locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
          );
        }

        _positionStream?.cancel();
        _positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (_state != TrackingState.running) return;

          // Cập nhật lại thời gian chính xác ngay khi nhận tọa độ ngầm
          _updateDurationFromWallClock();

          if (_lastPosition != null) {
            final double distanceInMeters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            // Lọc nhiễu đứng yên: Chỉ cộng Km khi di chuyển thật > 1.5 mét
            if (distanceInMeters >= 1.5 && position.accuracy <= 35.0) {
              _distanceKm += distanceInMeters / 1000.0;
              _calories = (_distanceKm * 62).round();
              _currentRoute.add(RunPoint(position.longitude, position.latitude));
            }
          } else {
            _currentRoute.add(RunPoint(position.longitude, position.latitude));
          }

          _lastPosition = position;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Lỗi GPS: $e');
    }

    notifyListeners();
  }

  // Tạm dừng chạy
  void pauseTracking() {
    _state = TrackingState.paused;
    _pauseStartTime = DateTime.now();
    _positionStream?.pause();
    notifyListeners();
  }

  // Tiếp tục chạy
  void resumeTracking() {
    if (_pauseStartTime != null) {
      _totalPausedSeconds += DateTime.now().difference(_pauseStartTime!).inSeconds;
      _pauseStartTime = null;
    }
    _state = TrackingState.running;
    _positionStream?.resume();
    _updateDurationFromWallClock();
    notifyListeners();
  }

  // Kết thúc và lưu buổi chạy
  RunSession? stopAndSaveTracking({
    required String userId,
    required String userName,
    String notes = 'Buổi chạy ngoài trời',
  }) {
    _updateDurationFromWallClock();
    _timer?.cancel();
    _timer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;

    final RunSession newSession = RunSession(
      id: 'run_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      startTime: _runStartTime ?? DateTime.now().subtract(Duration(seconds: _durationSeconds)),
      endTime: DateTime.now(),
      durationSeconds: _durationSeconds,
      distanceKm: _distanceKm,
      calories: _calories,
      notes: notes,
      routePoints: List.from(_currentRoute),
    );

    _sessions.insert(0, newSession);
    
    // Tự động reset về trạng thái Sẵn Sàng để người dùng có thể bắt đầu buổi chạy mới ngay lập tức
    _state = TrackingState.idle;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _currentRoute.clear();
    _runStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    notifyListeners();

    // Đồng bộ lên Supabase Cloud
    SupabaseService.insertRunSession(newSession);

    return newSession;
  }

  void resetTracking() {
    _timer?.cancel();
    _timer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
    _state = TrackingState.idle;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _currentRoute.clear();
    _runStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    notifyListeners();
  }

  // ==========================================
  // CHỨC NĂNG DÀNH CHO ADMIN: CHỈNH SỬA & QUẢN TRỊ
  // ==========================================

  /// Chỉnh sửa số KM và Thời gian chạy của bất kỳ buổi chạy nào
  void editRunSession(
    String id, {
    double? newDistanceKm,
    int? newDurationSeconds,
    String? newNotes,
  }) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      final old = _sessions[index];
      final double updatedDistance = newDistanceKm ?? old.distanceKm;
      final int updatedDuration = newDurationSeconds ?? old.durationSeconds;
      final int updatedCalories = (updatedDistance * 62).round();
      final String updatedNotes = newNotes ?? old.notes;

      _sessions[index] = old.copyWith(
        distanceKm: updatedDistance,
        durationSeconds: updatedDuration,
        calories: updatedCalories,
        notes: updatedNotes,
      );
      notifyListeners();

      // Đồng bộ cập nhật lên Supabase Cloud
      SupabaseService.updateRunSession(
        id,
        newDistanceKm: updatedDistance,
        newDurationSeconds: updatedDuration,
        newNotes: updatedNotes,
      );
    }
  }

  /// Xóa buổi chạy
  void deleteRunSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();

    // Đồng bộ xóa trên Supabase Cloud
    SupabaseService.deleteRunSession(id);
  }

  // ==========================================
  // THỐNG KÊ CHO ADMIN (NGÀY, TUẦN, THÁNG, NĂM)
  // ==========================================

  List<RunSession> getSessionsByFilter(TimeFilter filter) {
    final now = DateTime.now();
    return _sessions.where((session) {
      final date = session.startTime;
      switch (filter) {
        case TimeFilter.day:
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case TimeFilter.week:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final beginningOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          return date.isAfter(beginningOfWeek.subtract(const Duration(seconds: 1)));
        case TimeFilter.month:
          return date.year == now.year && date.month == now.month;
        case TimeFilter.year:
          return date.year == now.year;
      }
    }).toList();
  }

  double getTotalDistance(TimeFilter filter) {
    return getSessionsByFilter(filter).fold(0.0, (sum, item) => sum + item.distanceKm);
  }

  int getTotalDurationSeconds(TimeFilter filter) {
    return getSessionsByFilter(filter).fold(0, (sum, item) => sum + item.durationSeconds);
  }

  int getTotalCalories(TimeFilter filter) {
    return getSessionsByFilter(filter).fold(0, (sum, item) => sum + item.calories);
  }

  int getUniqueAthletesCount(TimeFilter filter) {
    final list = getSessionsByFilter(filter);
    return list.map((e) => e.userId).toSet().length;
  }

  /// Tạo dữ liệu biểu đồ phân nhóm trực quan
  List<ChartDataPoint> getChartData(TimeFilter filter) {
    final now = DateTime.now();
    final List<ChartDataPoint> points = [];

    switch (filter) {
      case TimeFilter.day:
        // Chia theo các khung giờ trong ngày (6h, 9h, 12h, 15h, 18h, 21h)
        for (int h = 6; h <= 22; h += 3) {
          final label = '$h:00';
          final runs = _sessions.where((s) {
            return s.startTime.year == now.year &&
                s.startTime.month == now.month &&
                s.startTime.day == now.day &&
                s.startTime.hour >= h - 2 &&
                s.startTime.hour <= h;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.week:
        // 7 ngày trong tuần (T2 -> CN)
        final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        for (int i = 1; i <= 7; i++) {
          final targetDate = now.subtract(Duration(days: now.weekday - i));
          final runs = _sessions.where((s) {
            return s.startTime.year == targetDate.year &&
                s.startTime.month == targetDate.month &&
                s.startTime.day == targetDate.day;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: weekDays[i - 1], distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.month:
        // 4 tuần trong tháng
        for (int w = 1; w <= 4; w++) {
          final label = 'Tuần $w';
          final startDay = (w - 1) * 7 + 1;
          final endDay = w * 7;
          final runs = _sessions.where((s) {
            return s.startTime.year == now.year &&
                s.startTime.month == now.month &&
                s.startTime.day >= startDay &&
                s.startTime.day <= endDay;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.year:
        // 12 tháng trong năm
        for (int m = 1; m <= 12; m++) {
          final label = 'T$m';
          final runs = _sessions.where((s) {
            return s.startTime.year == now.year && s.startTime.month == m;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;
    }
    return points;
  }

  /// Lấy danh sách buổi chạy của riêng một người dùng cụ thể
  List<RunSession> getUserSessions(String userId) {
    return _sessions.where((s) => s.userId == userId).toList();
  }

  /// Thống kê biểu đồ của riêng một người dùng cụ thể
  List<ChartDataPoint> getUserChartData(String userId, TimeFilter filter) {
    final now = DateTime.now();
    final List<ChartDataPoint> points = [];
    final userRuns = getUserSessions(userId);

    switch (filter) {
      case TimeFilter.day:
        for (int h = 6; h <= 22; h += 3) {
          final label = '$h:00';
          final runs = userRuns.where((s) {
            return s.startTime.year == now.year &&
                s.startTime.month == now.month &&
                s.startTime.day == now.day &&
                s.startTime.hour >= h - 2 &&
                s.startTime.hour <= h;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.week:
        final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        for (int i = 1; i <= 7; i++) {
          final targetDate = now.subtract(Duration(days: now.weekday - i));
          final runs = userRuns.where((s) {
            return s.startTime.year == targetDate.year &&
                s.startTime.month == targetDate.month &&
                s.startTime.day == targetDate.day;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: weekDays[i - 1], distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.month:
        for (int w = 1; w <= 4; w++) {
          final label = 'Tuần $w';
          final startDay = (w - 1) * 7 + 1;
          final endDay = w * 7;
          final runs = userRuns.where((s) {
            return s.startTime.year == now.year &&
                s.startTime.month == now.month &&
                s.startTime.day >= startDay &&
                s.startTime.day <= endDay;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;

      case TimeFilter.year:
        for (int m = 1; m <= 12; m++) {
          final label = 'T$m';
          final runs = userRuns.where((s) {
            return s.startTime.year == now.year && s.startTime.month == m;
          });
          final dist = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
          final durMin = runs.fold(0, (sum, r) => sum + r.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: label, distanceKm: dist, durationMinutes: durMin));
        }
        break;
    }
    return points;
  }

  // Dữ liệu khởi đầu trắng hoàn toàn (dữ liệu thật sẽ tải từ Supabase Cloud)
  void _initMockData() {
    // Không nạp dữ liệu mẫu nào
  }
}
