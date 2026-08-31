class RunPoint {
  final double x;
  final double y;

  const RunPoint(this.x, this.y);
}

class RunSession {
  final String id;
  final String userId;
  final String userName;
  final DateTime startTime;
  final DateTime endTime;
  int durationSeconds;
  double distanceKm;
  int calories;
  String notes;
  final List<RunPoint> routePoints;
  final List<RunPoint> pausePoints;

  RunSession({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceKm,
    required this.calories,
    this.notes = '',
    this.routePoints = const [],
    this.pausePoints = const [],
  });

  /// Tính tốc độ trung bình theo phút/km (Pace: mm:ss)
  String get avgPace {
    if (distanceKm <= 0.01 || durationSeconds <= 0) return '0:00';
    final double paceInMinutesPerKm = (durationSeconds / 60.0) / distanceKm;
    final int minutes = paceInMinutesPerKm.floor();
    final int seconds = ((paceInMinutesPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Định dạng thời gian chạy dạng HH:MM:SS hoặc MM:SS
  String get formattedDuration {
    final int hours = durationSeconds ~/ 3600;
    final int minutes = (durationSeconds % 3600) ~/ 60;
    final int seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Định dạng khoảng cách km
  String get formattedDistance {
    return distanceKm.toStringAsFixed(2);
  }

  RunSession copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceKm,
    int? calories,
    String? notes,
    List<RunPoint>? routePoints,
    List<RunPoint>? pausePoints,
  }) {
    return RunSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      notes: notes ?? this.notes,
      routePoints: routePoints ?? this.routePoints,
      pausePoints: pausePoints ?? this.pausePoints,
    );
  }
}
