import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/run_session.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../services/calorie_calculator.dart';
import '../services/gps_compression_service.dart';

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
  double _instantSpeedKmh = 0.0; // Vận tốc tức thời thời gian thực (phản hồi tức thì)
  DateTime? _runStartTime;
  DateTime? _pauseStartTime;
  int _totalPausedSeconds = 0;
  Timer? _timer;
  final List<RunPoint> _currentRoute = [];
  Position? _lastPosition;
  DateTime? _lastPositionTime;
  StreamSubscription<Position>? _positionStream;

  // Cấu hình Khung giờ chạy & Tự động kết thúc (Chống quên) - Theo từng User
  String? _activeUserId;
  bool _autoEndEnabled = true;
  int _autoStartHour = 5;
  int _autoStartMinute = 0;
  int _autoEndHour = 7;
  int _autoEndMinute = 30;
  bool _wasAutoFinished = false;

  // Haptic & Milestone callback cho mỗi 1 KM hoàn thành (giống Nike Run Club / Strava)
  int _lastMilestoneKm = 0;
  void Function(int kmCount, String pace)? onKilometerMilestone;

  // Danh sách toàn bộ lịch sử các buổi chạy
  final List<RunSession> _sessions = [];

  // Cache hồ sơ thật của tất cả người dùng trong hệ thống
  final Map<String, Map<String, dynamic>> _userProfiles = {};

  RunningProvider() {
    _loadInitialSessions();
    _loadUserProfiles();
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
    if (p != null && p['avatar_url'] != null && (p['avatar_url'] as String).trim().isNotEmpty) {
      return (p['avatar_url'] as String).trim();
    }
    final savedUser = LocalStorageService.getSavedUserSessionFast();
    if (savedUser != null && savedUser.id == userId && savedUser.avatarUrl.trim().isNotEmpty) {
      return savedUser.avatarUrl.trim();
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

  /// Tải cấu hình khung giờ chạy của riêng User đang đăng nhập
  Future<void> loadAutoEndConfigForUser(String userId) async {
    _activeUserId = userId;
    final schedule = await LocalStorageService.loadAutoEndSchedule(userId);
    _autoEndEnabled = schedule['enabled'] ?? true;
    _autoStartHour = schedule['startHour'] ?? 5;
    _autoStartMinute = schedule['startMinute'] ?? 0;
    _autoEndHour = schedule['endHour'] ?? 7;
    _autoEndMinute = schedule['endMinute'] ?? 30;
    notifyListeners();
  }

  /// Cập nhật khung giờ chạy và giờ tự động chốt cho riêng User đang đăng nhập
  Future<void> updateAutoEndSchedule({
    required String userId,
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    _activeUserId = userId;
    _autoEndEnabled = enabled;
    _autoStartHour = startHour;
    _autoStartMinute = startMinute;
    _autoEndHour = endHour;
    _autoEndMinute = endMinute;
    await LocalStorageService.saveAutoEndSchedule(
      userId: userId,
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
    // 0. Kiểm tra và tự động khôi phục ngay buổi chạy bị ngắt đột ngột (nếu có)
    await recoverUnfinishedRunSession();

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
  double get instantSpeedKmh => _instantSpeedKmh;
  List<RunPoint> get currentRoute => List.unmodifiable(_currentRoute);
  List<RunSession> get allSessions => List.unmodifiable(_sessions);

  /// Vận tốc trung bình cả buổi (km/h)
  double get currentSpeedKmh {
    if (_distanceKm <= 0.005 || _durationSeconds <= 0) return 0.0;
    final double hours = _durationSeconds / 3600.0;
    return (_distanceKm / hours).clamp(0.0, 35.0);
  }

  /// Trạng thái hoạt động thể chất nhận diện tự động tức thì (Đứng yên, Đi bộ, Chạy bộ, Sprint...)
  String get currentActivityType {
    if (_state == TrackingState.idle) return 'Sẵn sàng';
    if (_state == TrackingState.paused) return 'Tạm dừng';
    if (_state == TrackingState.finished) return 'Hoàn thành';
    return CalorieCalculator.getActivityType(speedKmh: _instantSpeedKmh);
  }

  String get currentPace {
    if (_distanceKm <= 0.005 || _durationSeconds <= 0) {
      if (_instantSpeedKmh >= 1.5) {
        final double pace = 60.0 / _instantSpeedKmh;
        final int min = pace.floor().clamp(1, 30);
        final int sec = ((pace - min) * 60).round().clamp(0, 59);
        return '$min:${sec.toString().padLeft(2, '0')}';
      }
      return '0:00';
    }
    final double pace = (_durationSeconds / 60.0) / _distanceKm;
    final int min = pace.floor().clamp(1, 35);
    final int sec = ((pace - min) * 60).round().clamp(0, 59);
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

      // CẬP NHẬT CALORIES THEO CHUẨN ACSM KHI THỜI GIAN TRÔI QUA
      _calories = CalorieCalculator.calculate(
        distanceKm: _distanceKm,
        durationSeconds: _durationSeconds,
      );

      // KIỂM TRA PHÂN RÃ TỐC ĐỘ TỨC THỜI KHI ĐỨNG YÊN (NẾU 2S KHÔNG CÓ TỌA ĐỘ MỚI -> 0 KM/H)
      if (_lastPositionTime != null) {
        final secSinceLastPos = now.difference(_lastPositionTime!).inSeconds;
        if (secSinceLastPos >= 2 && _instantSpeedKmh > 0.0) {
          _instantSpeedKmh = 0.0;
        }
      }

      // GHI CHECKPOINT LIÊN TỤC MỖI GIÂY (CHỐNG MẤT DỮ LIỆU KHI TẮT APP ĐỘT NGỘT)
      saveActiveCheckpointNow();

      // KIỂM TRA TỰ ĐỘNG CHỐT KHI QUA GIỜ CÀI ĐẶT CỦA USER (CHỐNG QUÊN)
      if (_autoEndEnabled) {
        final cutoffToday = DateTime(now.year, now.month, now.day, _autoEndHour, _autoEndMinute);
        if (now.isAfter(cutoffToday) && _runStartTime!.isBefore(cutoffToday)) {
          debugPrint('⏰ [AUTO-FINISH] Đã qua mốc giờ $_autoEndHour:$_autoEndMinute, tự động chốt buổi chạy cho user $_activeUserId!');
          _wasAutoFinished = true;
          stopAndSaveTracking(
            userId: _activeUserId ?? 'current_user',
            userName: getUserRealName(_activeUserId ?? '', 'Người chạy'),
            notes: 'Tự động chốt lúc ${_autoEndHour.toString().padLeft(2, '0')}:${_autoEndMinute.toString().padLeft(2, '0')} (Chống quên)',
          );
        }
      }
    }
  }

  /// Ghi trạng thái phiên chạy tức thì xuống bộ nhớ máy (Checkpoint)
  void saveActiveCheckpointNow() {
    if ((_state == TrackingState.running || _state == TrackingState.paused) && _runStartTime != null) {
      LocalStorageService.saveActiveTrackingCheckpoint(
        userId: _activeUserId ?? 'unknown_user',
        userName: getUserRealName(_activeUserId ?? '', 'Người chạy'),
        startTime: _runStartTime!,
        durationSeconds: _durationSeconds,
        distanceKm: _distanceKm,
        calories: _calories,
        isPaused: _state == TrackingState.paused,
        routePoints: _currentRoute.map((p) => {'x': p.x, 'y': p.y}).toList(),
      );
    }
  }

  // Bắt đầu chạy đo GPS thực tế & Bộ lọc nhiễu chính xác (Zero Jitter & Anti-Drift)
  Future<void> startTracking([String? userId]) async {
    if (userId != null && userId.isNotEmpty) {
      _activeUserId = userId;
    }
    _state = TrackingState.running;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _instantSpeedKmh = 0.0;
    _runStartTime = DateTime.now();
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    _currentRoute.clear();
    _lastPosition = null;
    _lastPositionTime = null;
    _lastMilestoneKm = 0;

    // Lưu ngay checkpoint điểm xuất phát
    saveActiveCheckpointNow();

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
            distanceFilter: 2, // Lọc dịch chuyển tối thiểu 2m chống rung lắc GPS
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

        // 1. Lấy ngay vị trí xuất phát tức thì tại thời điểm bấm bắt đầu (Gò Vấp / Điểm thật)
        try {
          Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          ).then((initialPos) {
            if (_state == TrackingState.running && _currentRoute.isEmpty) {
              _lastPosition = initialPos;
              _lastPositionTime = DateTime.now();
              _currentRoute.add(RunPoint(initialPos.longitude, initialPos.latitude));
              saveActiveCheckpointNow();
              notifyListeners();
            }
          }).catchError((e) {
            debugPrint('Lấy vị trí GPS ban đầu: $e');
          });
        } catch (e) {
          debugPrint('Lỗi khởi tạo GPS ban đầu: $e');
        }

        // 2. Lắng nghe dòng tọa độ di chuyển liên tục
        _positionStream?.cancel();
        _positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (_state != TrackingState.running) return;

          // Lọc bỏ tọa độ quá nhiễu (> 18m) để tránh cộng dồn sai số vệ tinh
          if (position.accuracy > 18.0) {
            return;
          }

          final now = DateTime.now();
          _updateDurationFromWallClock();

          // Lấy vận tốc tức thời từ chipset GPS phần cứng (m/s)
          final double hwSpeedMps = (position.speed >= 0.0 && position.speedAccuracy <= 3.0)
              ? position.speed
              : -1.0;

          if (_lastPosition != null) {
            final double distanceInMeters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            final double timeDeltaSec = _lastPositionTime != null
                ? (now.difference(_lastPositionTime!).inMilliseconds / 1000.0).clamp(0.1, 30.0)
                : 1.0;

            final double calcSpeedMps = distanceInMeters / timeDeltaSec;
            final double effectiveSpeedMps = (hwSpeedMps >= 0.2) ? hwSpeedMps : calcSpeedMps;
            final double speedKmh = (effectiveSpeedMps * 3.6).clamp(0.0, 35.0);

            // Cập nhật Vận tốc tức thời mượt mà (đi bộ 3-6 km/h, chạy 7-20 km/h)
            if (speedKmh >= 0.8) {
              _instantSpeedKmh = speedKmh;
            } else if (distanceInMeters < 1.5 && timeDeltaSec > 2.0) {
              _instantSpeedKmh = 0.0;
            }

            // BỘ LỌC CHỐNG TRÔI GPS KHI ĐI BỘ / ĐỨNG YÊN (Chuẩn Strava & Garmin):
            // 1. Loại bỏ nhảy ảo bất thường (tốc độ > 35 km/h hoặc khoảng cách nhảy vọt > 50m trong tích tắc)
            final bool isAbnormalJump = calcSpeedMps > 10.0 || distanceInMeters > 50.0;

            // 2. Chống cộng dồn trôi ảo khi đứng yên / di chuyển siêu nhỏ (< 2.0m khi tốc độ < 0.5 m/s)
            final bool isStationaryDrift = (distanceInMeters < 2.2 && effectiveSpeedMps < 0.5) || (distanceInMeters < 1.4);

            // 3. Điều kiện di chuyển thực tế hợp lệ (đi bộ thật hoặc chạy thật)
            final bool isValidMovement = !isAbnormalJump && !isStationaryDrift && (distanceInMeters >= 2.2 || (effectiveSpeedMps >= 0.6 && distanceInMeters >= 1.6));

            if (isValidMovement) {
              _distanceKm += distanceInMeters / 1000.0;
              _calories = CalorieCalculator.calculate(
                distanceKm: _distanceKm,
                durationSeconds: _durationSeconds,
              );
              _currentRoute.add(RunPoint(position.longitude, position.latitude));
              _lastPosition = position;
              _lastPositionTime = now;

              // KIỂM TRA MỐC KM ĐẠT ĐƯỢC (1.0km, 2.0km, 3.0km...) ĐỂ KÍCH HOẠT RUNG & THÔNG BÁO
              final int currentKm = _distanceKm.floor();
              if (currentKm > _lastMilestoneKm && currentKm > 0) {
                _lastMilestoneKm = currentKm;
                onKilometerMilestone?.call(currentKm, currentPace);
              }
            } else if (!isAbnormalJump && distanceInMeters >= 4.0) {
              // Cập nhật mốc tọa độ định kỳ để tránh tích tụ sai số khoảng cách
              _lastPosition = position;
              _lastPositionTime = now;
            }
          } else {
            // Tọa độ đầu tiên hợp lệ khi vừa bấm chạy
            _currentRoute.add(RunPoint(position.longitude, position.latitude));
            _lastPosition = position;
            _lastPositionTime = now;
            _instantSpeedKmh = (hwSpeedMps >= 0.2) ? (hwSpeedMps * 3.6) : 0.0;
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
    _instantSpeedKmh = 0.0;
    _pauseStartTime = DateTime.now();
    _positionStream?.pause();
    saveActiveCheckpointNow();
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
    saveActiveCheckpointNow();
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
    _instantSpeedKmh = 0.0;

    final compressedRoute = GpsCompressionService.compress(_currentRoute);

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
      routePoints: compressedRoute,
    );

    _sessions.insert(0, newSession);
    
    // Tự động reset về trạng thái idle
    _state = TrackingState.idle;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _instantSpeedKmh = 0.0;
    _currentRoute.clear();
    _runStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    notifyListeners();

    // Dọn sạch checkpoint phiên chạy cũ vì đã lưu xong
    LocalStorageService.clearActiveTrackingCheckpoint();

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
    _instantSpeedKmh = 0.0;
    _currentRoute.clear();
    _runStartTime = null;
    _pauseStartTime = null;
    _totalPausedSeconds = 0;
    _lastMilestoneKm = 0;
    LocalStorageService.clearActiveTrackingCheckpoint();
    notifyListeners();
  }

  /// Tự động khôi phục và lưu buổi chạy nếu người dùng vô tình vuốt tắt hẳn app hoặc máy sập nguồn (Cold Start)
  Future<RunSession?> recoverUnfinishedRunSession() async {
    // Nếu app đang trong phiên chạy (đang chạy nền / tạm dừng), TUYỆT ĐỐI KHÔNG can thiệp!
    if (_state != TrackingState.idle) {
      return null;
    }

    try {
      final checkpoint = await LocalStorageService.loadActiveTrackingCheckpoint();
      if (checkpoint == null) return null;

      final double distanceKm = (checkpoint['distance_km'] as num?)?.toDouble() ?? 0.0;
      final int durationSec = (checkpoint['duration_seconds'] as num?)?.toInt() ?? 0;
      final String userId = checkpoint['user_id'] as String? ?? _activeUserId ?? 'unknown_user';
      final String userName = checkpoint['user_name'] as String? ?? getUserRealName(userId, 'Người chạy');
      final String? startTimeStr = checkpoint['start_time'] as String?;
      final DateTime startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) ?? DateTime.now() : DateTime.now();

      // Dọn checkpoint cũ
      await LocalStorageService.clearActiveTrackingCheckpoint();

      final routePointsData = checkpoint['route_points'] as List<dynamic>? ?? [];
      final List<RunPoint> routePoints = [];
      for (final pt in routePointsData) {
        if (pt is Map) {
          routePoints.add(RunPoint(
            (pt['x'] as num?)?.toDouble() ?? 0.0,
            (pt['y'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      final int actualDuration = durationSec > 0 ? durationSec : 1;
      final recoveredSession = RunSession(
        id: 'run_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        userName: userName,
        startTime: startTime,
        endTime: startTime.add(Duration(seconds: actualDuration)),
        durationSeconds: actualDuration,
        distanceKm: distanceKm,
        calories: (checkpoint['calories'] as num?)?.toInt() ?? CalorieCalculator.calculate(distanceKm: distanceKm, durationSeconds: actualDuration),
        notes: 'Tự động lưu khi thoát app đột ngột',
        routePoints: routePoints,
      );

      // Tránh trùng lặp nếu session id đã tồn tại
      _sessions.removeWhere((s) => s.id == recoveredSession.id);
      _sessions.insert(0, recoveredSession);
      notifyListeners();

      // 1. Lưu Offline Cache & Pending Sync
      await LocalStorageService.cacheAllRunSessions(_sessions);
      await LocalStorageService.savePendingOfflineRun(recoveredSession);

      // 2. Đẩy lên Supabase Cloud
      if (SupabaseService.isConfigured) {
        SupabaseService.insertRunSession(recoveredSession).then((success) {
          if (success) {
            LocalStorageService.removePendingOfflineRun(recoveredSession.id);
          }
        });
      }

      debugPrint('🛡️ [AUTO-RECOVERY] Đã tự động lưu buổi chạy bị đóng app: ${recoveredSession.distanceKm} km, ${recoveredSession.durationSeconds}s');
      return recoveredSession;
    } catch (e) {
      debugPrint('Lỗi phục hồi phiên chạy: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // Quản trị viên tạo mới một buổi chạy thủ công cho bất kỳ User nào
  Future<RunSession> adminCreateRunSession({
    required String userId,
    required String userName,
    required DateTime startTime,
    required double distanceKm,
    required int durationSeconds,
    String notes = 'Do Quản trị viên tạo',
  }) async {
    final newSession = RunSession(
      id: 'run_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      startTime: startTime,
      endTime: startTime.add(Duration(seconds: durationSeconds)),
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      calories: CalorieCalculator.calculate(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
      ),
      notes: notes,
      routePoints: const [],
    );

    _sessions.insert(0, newSession);
    notifyListeners();

    // 1. Lưu Offline Cache
    await LocalStorageService.cacheAllRunSessions(_sessions);

    // 2. Đẩy lên Supabase Cloud
    if (SupabaseService.isConfigured) {
      await SupabaseService.insertRunSession(newSession);
    }

    return newSession;
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
        calories: CalorieCalculator.calculate(
          distanceKm: newDistanceKm,
          durationSeconds: newDurationSeconds,
        ),
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

  // ==========================================================
  // HỆ THỐNG LỌC THỐNG KÊ ĐA CHIỀU (TẤT CẢ HOẶC TỪNG USER CỤ THỂ)
  // ==========================================================
  List<RunSession> getFilteredSessions({
    required TimeFilter filter,
    String? targetUserId,
  }) {
    final now = DateTime.now();
    return _sessions.where((session) {
      if (targetUserId != null && targetUserId.isNotEmpty && session.userId != targetUserId) {
        return false;
      }
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

  double getFilteredTotalDistance(TimeFilter filter, [String? targetUserId]) {
    return getFilteredSessions(filter: filter, targetUserId: targetUserId)
        .fold(0.0, (sum, item) => sum + item.distanceKm);
  }

  int getFilteredTotalDurationSeconds(TimeFilter filter, [String? targetUserId]) {
    return getFilteredSessions(filter: filter, targetUserId: targetUserId)
        .fold(0, (sum, item) => sum + item.durationSeconds);
  }

  int getFilteredTotalCalories(TimeFilter filter, [String? targetUserId]) {
    return getFilteredSessions(filter: filter, targetUserId: targetUserId)
        .fold(0, (sum, item) => sum + item.calories);
  }

  int getFilteredUniqueAthletesCount(TimeFilter filter, [String? targetUserId]) {
    final list = getFilteredSessions(filter: filter, targetUserId: targetUserId);
    return list.map((s) => s.userId).toSet().length;
  }

  List<ChartDataPoint> getFilteredChartData(TimeFilter filter, [String? targetUserId]) {
    final sessions = getFilteredSessions(filter: filter, targetUserId: targetUserId);
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

  // Alias tương thích cũ
  List<RunSession> getSessionsByTimeFilter(TimeFilter filter) => getFilteredSessions(filter: filter);
  double getTotalDistance(TimeFilter filter) => getFilteredTotalDistance(filter);
  int getTotalDuration(TimeFilter filter) => getFilteredTotalDurationSeconds(filter);
  int getTotalDurationSeconds(TimeFilter filter) => getFilteredTotalDurationSeconds(filter);
  int getTotalCalories(TimeFilter filter) => getFilteredTotalCalories(filter);
  int getUniqueAthletesCount(TimeFilter filter) => getFilteredUniqueAthletesCount(filter);
  List<ChartDataPoint> getChartData(TimeFilter filter) => getFilteredChartData(filter);
  List<RunSession> getSessionsByFilter(TimeFilter filter) => getFilteredSessions(filter: filter);

  // Lấy danh sách buổi chạy của riêng một User
  List<RunSession> getUserSessions(String userId) {
    return _sessions.where((s) => s.userId == userId).toList();
  }

  // Lấy dữ liệu biểu đồ cho riêng một User
  List<ChartDataPoint> getUserChartData(String userId, TimeFilter filter) =>
      getFilteredChartData(filter, userId);

  // Danh sách tất cả buổi chạy
  List<RunSession> get sessions => List.unmodifiable(_sessions);

  // Lấy tổng quãng đường (KM) của riêng một User (kèm cộng dồn khi đang chạy)
  double getUserTotalDistance(String? userId) {
    final history = (userId == null || userId.isEmpty)
        ? _sessions.fold(0.0, (sum, s) => sum + s.distanceKm)
        : _sessions.where((s) => s.userId == userId).fold(0.0, (sum, s) => sum + s.distanceKm);
    return history + (isRunning ? _distanceKm : 0.0);
  }

  // Lấy tổng thời gian (giây) của riêng một User (kèm cộng dồn khi đang chạy)
  int getUserTotalDurationSeconds(String? userId) {
    final history = (userId == null || userId.isEmpty)
        ? _sessions.fold(0, (sum, s) => sum + s.durationSeconds)
        : _sessions.where((s) => s.userId == userId).fold(0, (sum, s) => sum + s.durationSeconds);
    return history + (isRunning ? _durationSeconds : 0);
  }

  // Lấy tổng Calo của riêng một User (kèm cộng dồn khi đang chạy)
  int getUserTotalCalories(String? userId) {
    final history = (userId == null || userId.isEmpty)
        ? _sessions.fold(0, (sum, s) => sum + s.calories)
        : _sessions.where((s) => s.userId == userId).fold(0, (sum, s) => sum + s.calories);
    return history + (isRunning ? _calories : 0);
  }
}
