import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  Timer? _timer;
  final List<RunPoint> _currentRoute = [];
  double _simulatedAngle = 0.0;

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

  // Bắt đầu chạy
  void startTracking() {
    _state = TrackingState.running;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _runStartTime = DateTime.now();
    _currentRoute.clear();
    _simulatedAngle = 0.0;
    _currentRoute.add(const RunPoint(0, 0));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == TrackingState.running) {
        _durationSeconds++;

        // Mô phỏng tốc độ chạy thực tế ~ 10-12 km/h khi test dev
        // (tương đương ~3 mét mỗi giây)
        final double deltaDistance = 0.003 + (Random().nextDouble() * 0.001);
        _distanceKm += deltaDistance;

        // Tính calo dựa trên quãng đường chạy (trung bình ~62 kcal/km)
        _calories = (_distanceKm * 62).round();

        // Tạo điểm lộ trình chạy mô phỏng
        _simulatedAngle += (Random().nextDouble() - 0.5) * 0.2;
        final double lastX = _currentRoute.isNotEmpty ? _currentRoute.last.x : 0;
        final double lastY = _currentRoute.isNotEmpty ? _currentRoute.last.y : 0;
        _currentRoute.add(
          RunPoint(
            lastX + cos(_simulatedAngle) * 2,
            lastY + sin(_simulatedAngle) * 2,
          ),
        );

        notifyListeners();
      }
    });

    notifyListeners();
  }

  // Tạm dừng chạy
  void pauseTracking() {
    _state = TrackingState.paused;
    notifyListeners();
  }

  // Tiếp tục chạy
  void resumeTracking() {
    _state = TrackingState.running;
    notifyListeners();
  }

  // Kết thúc và lưu buổi chạy
  RunSession? stopAndSaveTracking({
    required String userId,
    required String userName,
    String notes = 'Buổi chạy ngoài trời',
  }) {
    _timer?.cancel();
    _timer = null;

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
    _state = TrackingState.finished;
    notifyListeners();

    // Đồng bộ lên Supabase Cloud
    SupabaseService.insertRunSession(newSession);

    return newSession;
  }

  void resetTracking() {
    _timer?.cancel();
    _timer = null;
    _state = TrackingState.idle;
    _durationSeconds = 0;
    _distanceKm = 0.0;
    _calories = 0;
    _currentRoute.clear();
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
        distanceKm: updatedDistance,
        durationSeconds: updatedDuration,
        calories: updatedCalories,
        notes: updatedNotes,
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

  // Khởi tạo sẵn một số buổi chạy mẫu phong phú để xem thống kê ngay
  void _initMockData() {
    final now = DateTime.now();

    _sessions.addAll([
      // Hôm nay
      RunSession(
        id: 'mock_01',
        userId: 'runner_01',
        userName: 'Nguyễn Văn Chạy',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(hours: 2, minutes: 25)),
        durationSeconds: 2100, // 35 phút
        distanceKm: 6.25,
        calories: 388,
        notes: 'Chạy sáng công viên bờ sông, thời tiết đẹp.',
      ),
      RunSession(
        id: 'mock_02',
        userId: 'runner_02',
        userName: 'Trần Thị Thể Thao',
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.subtract(const Duration(hours: 4, minutes: 40)),
        durationSeconds: 1200, // 20 phút
        distanceKm: 3.50,
        calories: 217,
        notes: 'Khởi động nhẹ buổi sáng.',
      ),
      // Tuần này - các ngày trước
      RunSession(
        id: 'mock_03',
        userId: 'runner_01',
        userName: 'Nguyễn Văn Chạy',
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        durationSeconds: 3600, // 60 phút
        distanceKm: 10.50,
        calories: 651,
        notes: 'Thử thách chạy dài cuối tuần 10km.',
      ),
      RunSession(
        id: 'mock_04',
        userId: 'runner_03',
        userName: 'Lê Hoàng Long',
        startTime: now.subtract(const Duration(days: 2)),
        endTime: now.subtract(const Duration(days: 2)).add(const Duration(minutes: 42)),
        durationSeconds: 2520,
        distanceKm: 7.80,
        calories: 483,
        notes: 'Chạy interval tốc độ cao.',
      ),
      RunSession(
        id: 'mock_05',
        userId: 'runner_01',
        userName: 'Nguyễn Văn Chạy',
        startTime: now.subtract(const Duration(days: 3)),
        endTime: now.subtract(const Duration(days: 3)).add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        distanceKm: 5.12,
        calories: 317,
        notes: 'Chạy duy trì thể lực.',
      ),
      // Tháng này
      RunSession(
        id: 'mock_06',
        userId: 'runner_02',
        userName: 'Trần Thị Thể Thao',
        startTime: now.subtract(const Duration(days: 10)),
        endTime: now.subtract(const Duration(days: 10)).add(const Duration(minutes: 50)),
        durationSeconds: 3000,
        distanceKm: 8.40,
        calories: 520,
        notes: 'Chạy địa hình dốc.',
      ),
      RunSession(
        id: 'mock_07',
        userId: 'runner_03',
        userName: 'Lê Hoàng Long',
        startTime: now.subtract(const Duration(days: 18)),
        endTime: now.subtract(const Duration(days: 18)).add(const Duration(hours: 1, minutes: 15)),
        durationSeconds: 4500,
        distanceKm: 12.60,
        calories: 781,
        notes: 'Chạy đường dài nửa marathon.',
      ),
    ]);
  }
}
