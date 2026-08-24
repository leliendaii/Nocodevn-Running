import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/run_session.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';

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
  DateTime? _lastPositionTime;
  StreamSubscription<Position>? _positionStream;

  // Cấu hình Khung giờ chạy & Tự động kết thúc (Chống quên)
  bool _autoEndEnabled = true;
  int _autoStartHour = 5;
  int _autoStartMinute = 0;
  int _autoEndHour = 7;
  int _autoEndMinute = 30;
  bool _wasAutoFinished = false;

  // Danh sách toàn bộ lịch sử các buổi chạy
  final List<RunSession> _sessions = [];

  // Cache hồ sơ thật của tất cả người dùng trong hệ thống
  final Map<String, Map<String, dynamic>> _userProfiles = {};

  RunningProvider() {
    _loadInitialSessions();
    _loadUserProfiles();
    _loadAutoEndConfig();
  }

  /// Tải danh sách profile thật của tất cả user từ Cloud
  Future<void> _loadUserProfiles() async {
    final list = await SupabaseService.fetchAllProfiles();
    if (list != null && list.isNotEmpty) {
      _userProfiles.clear();
      for (final p in list) {
        final id = p['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          _userProfiles[id] = p;
        }
      }
      notifyListeners();
    }
  }

  /// Làm mới toàn bộ profile và buổi chạy từ Cloud
  Future<void> refreshAllData() async {
    await Future.wait([
      _loadInitialSessions(),
      _loadUserProfiles(),
    ]);
  }

  /// Lấy Tên Thật của User theo ID (Nếu chưa có thì dùng tên lưu trong session)
  String getUserRealName(String userId, [String fallbackName = '']) {
    final p = _userProfiles[userId];
    if (p != null && p['name'] != null && (p['name'] as String).trim().isNotEmpty) {
      return (p['name'] as String).trim();
    }
    return fallbackName.isNotEmpty ? fallbackName : 'Người chạy';
  }

  /// Lấy Avatar Thật của User theo ID
  String getUserRealAvatar(String userId) {
    final p = _userProfiles[userId];
    if (p != null && p['avatar_url'] != null) {
      return (p['avatar_url'] as String).trim();
    }
    return '';
  }

  /// Lấy Username Thật của User theo ID
  String getUserRealUsername(String userId) {
    final p = _userProfiles[userId];
    if (p != null && p['username'] != null) {
      return (p['username'] as String).trim();
    }
    return '';
  }

  /// Kiểm tra User có phải Admin hay không
  bool isUserAdmin(String userId) {
    final p = _userProfiles[userId];
    if (p != null && p['role'] != null) {
      return (p['role'] as String).toLowerCase() == 'admin';
    }
    return false;
  }

  Map<String, Map<String, dynamic>> get allUserProfiles => _userProfiles;

  /// Tải cấu hình khung giờ chạy
  Future<void> _loadAutoEndConfig() async {
    final schedule = await LocalStorageService.loadAutoEndSchedule();
    _autoEndEnabled = schedule['enabled'] ?? true;
    _autoStartHour = schedule['startHour'] ?? 5;
    _autoStartMinute = schedule['startMinute'] ?? 0;
    _autoEndHour = schedule['endHour'] ?? 7;
    _autoEndMinute = schedule['endMinute'] ?? 30;
    notifyListeners();
  }

  /// Cập nhật khung giờ chạy và giờ tự động chốt
  Future<void> updateAutoEndSchedule({
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    _autoEndEnabled = enabled;
    _autoStartHour = startHour;
    _autoStartMinute = startMinute;
    _autoEndHour = endHour;
    _autoEndMinute = endMinute;
    await LocalStorageService.saveAutoEndSchedule(
      enabled: enabled,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    );
    notifyListeners();
  }

  /// Tải dữ liệu kết hợp Offline Cache & Supabase Cloud
  Future<void> _loadInitialSessions() async {
    // 1. Tải nhanh từ bộ nhớ máy (Offline Cache) để hiển thị tức thì
    final cached = await LocalStorageService.loadCachedRunSessions();
    if (cached.isNotEmpty) {
      _sessions.clear();
      _sessions.addAll(cached);
      notifyListeners();
    }

    // 2. Tải dữ liệu mới nhất từ Supabase Cloud
    final cloudList = await SupabaseService.fetchRunSessions();
    if (cloudList != null && cloudList.isNotEmpty) {
      _sessions.clear();
      _sessions.addAll(cloudList);
      await LocalStorageService.cacheAllRunSessions(_sessions);
      notifyListeners();
    }

    // 3. Tự động đồng bộ các buổi chạy chưa đẩy lên Cloud (Pending sync)
    _syncPendingOfflineRuns();
  }

  /// Tự động đẩy các buổi chạy offline lên Supabase khi có mạng
  Future<void> _syncPendingOfflineRuns() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final pending = await LocalStorageService.loadPendingOfflineRuns();
      for (final run in pending) {
        final success = await SupabaseService.insertRunSession(run);
        if (success) {
          await LocalStorageService.removePendingOfflineRun(run.id);
        }
      }
    } catch (e) {
      debugPrint('Lỗi auto sync pending offline runs: $e');
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

  // Getters cho cấu hình khung giờ tự động kết thúc (Chống quên)
  bool get autoEndEnabled => _autoEndEnabled;
  int get autoStartHour => _autoStartHour;
  int get autoStartMinute => _autoStartMinute;
  int get autoEndHour => _autoEndHour;
  int get autoEndMinute => _autoEndMinute;
  bool get wasAutoFinished => _wasAutoFinished;

  void clearAutoFinishedFlag() {
    _wasAutoFinished = false;
    notifyListeners();
  }

  void _updateDurationFromWallClock() {
    if (_state == TrackingState.running && _runStartTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_runStartTime!).inSeconds;
      _durationSeconds = (elapsed - _totalPausedSeconds).clamp(0, 99999999);

      // KIỂM TRA TỰ ĐỘNG CHỐT KHI QUA GIỜ CÀI ĐẶT (CHỐNG QUÊN)
      if (_autoEndEnabled) {
        final cutoffToday = DateTime(now.year, now.month, now.day, _autoEndHour, _autoEndMinute);
        if (now.isAfter(cutoffToday) && _runStartTime!.isBefore(cutoffToday)) {
          debugPrint('⏰ [AUTO-FINISH] Đã qua mốc giờ $_autoEndHour:$_autoEndMinute, tự động chốt buổi chạy!');
          _wasAutoFinished = true;
          stopAndSaveTracking(
            userId: 'current_user',
            userName: 'Người chạy',
            notes: 'Tự động chốt lúc ${_autoEndHour.toString().padLeft(2, '0')}:${_autoEndMinute.toString().padLeft(2, '0')} (Chống quên)',
          );
        }
      }
    }
  }

  // Bắt đầu chạy đo GPS thực tế & Bộ lọc nhiễu chính xác (Zero Jitter)
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
    _lastPositionTime = null;

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
        
        LocationSettings locationSettings;
        if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          locationSettings = AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            distanceFilter: 3, // Lọc dịch chuyển tối thiểu 3m
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );
        } else {
          locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          );
        }

        _positionStream?.cancel();
        _positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (_state != TrackingState.running) return;

          // Cập nhật lại thời gian chính xác
          _updateDurationFromWallClock();

          // 1. Lọc bỏ tọa độ kém chính xác (nhiễu nhà cao tầng > 25m)
          if (position.accuracy > 25.0) {
            return;
          }

          final now = DateTime.now();

          if (_lastPosition != null) {
            final double distanceInMeters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            final double timeDeltaSec = _lastPositionTime != null 
                ? now.difference(_lastPositionTime!).inMilliseconds / 1000.0 
                : 1.0;

            final double speedMps = timeDeltaSec > 0 ? (distanceInMeters / timeDeltaSec) : 0.0;

            // 2. Lọc nhiễu đứng yên (> 2.0m) & Lọc bước nhảy ảo (> 11.5 m/s ~ 41.4 km/h)
            if (distanceInMeters >= 2.0 && speedMps < 11.5) {
              _distanceKm += distanceInMeters / 1000.0;
              _calories = (_distanceKm * 62).round();
              _currentRoute.add(RunPoint(position.longitude, position.latitude));
              _lastPosition = position;
              _lastPositionTime = now;
            }
          } else {
            _currentRoute.add(RunPoint(position.longitude, position.latitude));
            _lastPosition = position;
            _lastPositionTime = now;
          }

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

  // Kết thúc và lưu buổi chạy (Offline-First an toàn tuyệt đối)
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
    _lastPositionTime = null;

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
    
    // Tự động reset về trạng thái idle
    _state = TrackingState.idle;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _currentRoute.clear();
    _runStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    notifyListeners();

    // 1. Lưu Offline Cache & Pending Sync
    LocalStorageService.cacheAllRunSessions(_sessions);
    LocalStorageService.savePendingOfflineRun(newSession);

    // 2. Đẩy lên Supabase Cloud
    if (SupabaseService.isConfigured) {
      SupabaseService.insertRunSession(newSession).then((success) {
        if (success) {
          LocalStorageService.removePendingOfflineRun(newSession.id);
        }
      });
    }

    return newSession;
  }

  void resetTracking() {
    _timer?.cancel();
    _timer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
    _lastPositionTime = null;
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

  // Quản trị viên cập nhật KM & thời gian
  void editRunSession(
    String sessionId, {
    required double newDistanceKm,
    required int newDurationSeconds,
    String? newNotes,
  }) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final old = _sessions[index];
      final updated = old.copyWith(
        distanceKm: newDistanceKm,
        durationSeconds: newDurationSeconds,
        calories: (newDistanceKm * 62).round(),
        notes: newNotes ?? old.notes,
      );
      _sessions[index] = updated;
      LocalStorageService.cacheAllRunSessions(_sessions);
      notifyListeners();

      SupabaseService.updateRunSession(
        sessionId,
        newDistanceKm: newDistanceKm,
        newDurationSeconds: newDurationSeconds,
        newNotes: newNotes,
      );
    }
  }

  // Quản trị viên xóa buổi chạy
  void deleteRunSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    LocalStorageService.cacheAllRunSessions(_sessions);
    notifyListeners();

    SupabaseService.deleteRunSession(sessionId);
  }

  // Lọc dữ liệu thống kê
  List<RunSession> getSessionsByTimeFilter(TimeFilter filter) {
    final now = DateTime.now();
    return _sessions.where((session) {
      switch (filter) {
        case TimeFilter.day:
          return session.startTime.year == now.year &&
              session.startTime.month == now.month &&
              session.startTime.day == now.day;
        case TimeFilter.week:
          final weekAgo = now.subtract(const Duration(days: 7));
          return session.startTime.isAfter(weekAgo);
        case TimeFilter.month:
          return session.startTime.year == now.year &&
              session.startTime.month == now.month;
        case TimeFilter.year:
          return session.startTime.year == now.year;
      }
    }).toList();
  }

  double getTotalDistance(TimeFilter filter) {
    return getSessionsByTimeFilter(filter)
        .fold(0.0, (sum, item) => sum + item.distanceKm);
  }

  int getTotalDuration(TimeFilter filter) {
    return getSessionsByTimeFilter(filter)
        .fold(0, (sum, item) => sum + item.durationSeconds);
  }

  int getTotalCalories(TimeFilter filter) {
    return getSessionsByTimeFilter(filter)
        .fold(0, (sum, item) => sum + item.calories);
  }

  List<ChartDataPoint> getChartData(TimeFilter filter) {
    final sessions = getSessionsByTimeFilter(filter);
    final now = DateTime.now();
    final List<ChartDataPoint> points = [];

    switch (filter) {
      case TimeFilter.day:
        for (int i = 0; i < 24; i += 4) {
          final hourSessions = sessions.where((s) => s.startTime.hour >= i && s.startTime.hour < i + 4);
          final dist = hourSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = hourSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: '${i}h', distanceKm: dist, durationMinutes: dur));
        }
        break;

      case TimeFilter.week:
        const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        for (int i = 6; i >= 0; i--) {
          final targetDay = now.subtract(Duration(days: i));
          final daySessions = sessions.where((s) =>
              s.startTime.year == targetDay.year &&
              s.startTime.month == targetDay.month &&
              s.startTime.day == targetDay.day);
          final dist = daySessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = daySessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(
            label: weekdays[targetDay.weekday - 1],
            distanceKm: dist,
            durationMinutes: dur,
          ));
        }
        break;

      case TimeFilter.month:
        for (int w = 1; w <= 4; w++) {
          final weekSessions = sessions.where((s) => ((s.startTime.day - 1) ~/ 7) + 1 == w);
          final dist = weekSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = weekSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: 'Tuần $w', distanceKm: dist, durationMinutes: dur));
        }
        break;

      case TimeFilter.year:
        const months = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
        for (int m = 1; m <= 12; m++) {
          final mSessions = sessions.where((s) => s.startTime.month == m);
          final dist = mSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = mSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: months[m - 1], distanceKm: dist, durationMinutes: dur));
        }
        break;
    }

    return points;
  }

  // Alias cho Admin Dashboard
  List<RunSession> getSessionsByFilter(TimeFilter filter) => getSessionsByTimeFilter(filter);
  int getTotalDurationSeconds(TimeFilter filter) => getTotalDuration(filter);

  int getUniqueAthletesCount(TimeFilter filter) {
    return getSessionsByTimeFilter(filter).map((s) => s.userId).toSet().length;
  }

  // Lấy danh sách buổi chạy của riêng một User
  List<RunSession> getUserSessions(String userId) {
    return _sessions.where((s) => s.userId == userId).toList();
  }

  // Lấy dữ liệu biểu đồ cho riêng một User
  List<ChartDataPoint> getUserChartData(String userId, TimeFilter filter) {
    final userSessions = getUserSessions(userId);
    final now = DateTime.now();
    final List<ChartDataPoint> points = [];

    switch (filter) {
      case TimeFilter.day:
        for (int i = 0; i < 24; i += 4) {
          final hourSessions = userSessions.where((s) => s.startTime.hour >= i && s.startTime.hour < i + 4);
          final dist = hourSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = hourSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: '${i}h', distanceKm: dist, durationMinutes: dur));
        }
        break;

      case TimeFilter.week:
        const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        for (int i = 6; i >= 0; i--) {
          final targetDay = now.subtract(Duration(days: i));
          final daySessions = userSessions.where((s) =>
              s.startTime.year == targetDay.year &&
              s.startTime.month == targetDay.month &&
              s.startTime.day == targetDay.day);
          final dist = daySessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = daySessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(
            label: weekdays[targetDay.weekday - 1],
            distanceKm: dist,
            durationMinutes: dur,
          ));
        }
        break;

      case TimeFilter.month:
        for (int w = 1; w <= 4; w++) {
          final weekSessions = userSessions.where((s) => ((s.startTime.day - 1) ~/ 7) + 1 == w);
          final dist = weekSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = weekSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: 'Tuần $w', distanceKm: dist, durationMinutes: dur));
        }
        break;

      case TimeFilter.year:
        const months = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9', 'T10', 'T11', 'T12'];
        for (int m = 1; m <= 12; m++) {
          final mSessions = userSessions.where((s) => s.startTime.month == m);
          final dist = mSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
          final dur = mSessions.fold(0, (sum, s) => sum + s.durationSeconds) / 60.0;
          points.add(ChartDataPoint(label: months[m - 1], distanceKm: dist, durationMinutes: dur));
        }
        break;
    }

    return points;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}
