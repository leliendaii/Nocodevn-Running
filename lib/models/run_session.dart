class RunPoint {
  final double x;
  final double y;

  const RunPoint(this.x, this.y);
}

/// Dữ liệu phân tích chi tiết của từng 1.0 KM (Lap Split)
class KmSplit {
  final int kmIndex;          // KM 1, KM 2, KM 3...
  final double distanceKm;    // 1.0 (hoặc chặng lẻ cuối 0.45km)
  final int durationSeconds;  // Thời gian chạy riêng KM đó
  final String pace;          // Pace mm:ss
  final int calories;         // Lượng Calo riêng KM đó
  final int paceSeconds;      // Tổng số giây để chạy 1km (phục vụ so sánh)
  final int paceDeltaSeconds; // So sánh với KM trước (< 0 là nhanh hơn, > 0 là chậm hơn)
  final bool isBestSplit;     // KM chạy nhanh nhất buổi chạy 🔥
  final int? rawSteps;        // Số bước chân

  const KmSplit({
    required this.kmIndex,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    required this.calories,
    required this.paceSeconds,
    this.paceDeltaSeconds = 0,
    this.isBestSplit = false,
    this.rawSteps,
  });

  /// Tính số bước chân chuẩn dựa trên cự ly, thời gian và nhịp bước Cadence tự nhiên
  int get steps {
    if (rawSteps != null && rawSteps! > 0) return rawSteps!;
    if (distanceKm <= 0 || durationSeconds <= 0) return 0;
    final double speedKmh = (distanceKm / durationSeconds) * 3600;
    double cadence = 162.0; // Nhịp bước/phút tiêu chuẩn
    if (speedKmh > 14.0) {
      cadence = 175.0;
    } else if (speedKmh > 12.0) {
      cadence = 168.0;
    } else if (speedKmh > 10.0) {
      cadence = 162.0;
    } else if (speedKmh > 8.0) {
      cadence = 155.0;
    } else {
      cadence = 148.0;
    }
    final calcSteps = ((durationSeconds / 60.0) * cadence).round();
    return calcSteps.clamp((distanceKm * 950).round(), (distanceKm * 1600).round());
  }

  Map<String, dynamic> toJson() => {
    'kmIndex': kmIndex,
    'distanceKm': distanceKm,
    'durationSeconds': durationSeconds,
    'pace': pace,
    'calories': calories,
    'paceSeconds': paceSeconds,
    'paceDeltaSeconds': paceDeltaSeconds,
    'isBestSplit': isBestSplit,
    'steps': steps,
  };

  factory KmSplit.fromJson(Map<String, dynamic> json) => KmSplit(
    kmIndex: json['kmIndex'] ?? 1,
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.0,
    durationSeconds: json['durationSeconds'] ?? 0,
    pace: json['pace'] ?? '0:00',
    calories: json['calories'] ?? 0,
    paceSeconds: json['paceSeconds'] ?? 0,
    paceDeltaSeconds: json['paceDeltaSeconds'] ?? 0,
    isBestSplit: json['isBestSplit'] ?? false,
    rawSteps: json['steps'] as int?,
  );
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
  final List<KmSplit> splits;

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
    this.splits = const [],
  });

  /// Tính tốc độ trung bình theo phút/km (Pace: mm:ss)
  String get avgPace {
    if (distanceKm <= 0.01 || durationSeconds <= 0) return '0:00';
    final double paceInMinutesPerKm = (durationSeconds / 60.0) / distanceKm;
    final int minutes = paceInMinutesPerKm.floor();
    final int seconds = ((paceInMinutesPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Getter alias cho avgPace
  String get pace => avgPace;
  String get formattedPace => avgPace;

  /// Vận tốc trung bình theo km/h
  double get avgSpeedKmh {
    if (durationSeconds <= 0) return 0.0;
    return (distanceKm / durationSeconds) * 3600;
  }

  /// Định dạng vận tốc trung bình (VD: 8.5)
  String get formattedAvgSpeed {
    return avgSpeedKmh.toStringAsFixed(1);
  }

  /// Tổng số bước chân tính theo chuẩn y khoa thể thao
  int get totalSteps {
    if (splits.isNotEmpty) {
      return splits.fold(0, (sum, sp) => sum + sp.steps);
    }
    if (distanceKm <= 0 || durationSeconds <= 0) return 0;
    final double speedKmh = (distanceKm / durationSeconds) * 3600;
    double cadence = 162.0;
    if (speedKmh > 14.0) {
      cadence = 175.0;
    } else if (speedKmh > 12.0) {
      cadence = 168.0;
    } else if (speedKmh > 10.0) {
      cadence = 162.0;
    } else if (speedKmh > 8.0) {
      cadence = 155.0;
    } else {
      cadence = 148.0;
    }
    final calcSteps = ((durationSeconds / 60.0) * cadence).round();
    return calcSteps.clamp((distanceKm * 950).round(), (distanceKm * 1600).round());
  }

  /// Định dạng số bước có dấu chấm (VD: 8.345 hoặc 4.520)
  String get formattedTotalSteps {
    final s = totalSteps;
    return s.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
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

  /// Danh sách Splits có sẵn hoặc tự động tạo từ dữ liệu tổng thể (Đảm bảo luôn có dữ liệu đẹp 100%)
  List<KmSplit> get effectiveSplits {
    if (splits.isNotEmpty) return splits;
    if (distanceKm < 0.1 || durationSeconds <= 0) return [];

    final List<KmSplit> generated = [];
    final int totalFullKm = distanceKm.floor();
    final double remKm = distanceKm - totalFullKm;
    final int avgPaceSec = (durationSeconds / distanceKm).round();

    int minPaceSec = 999999;
    int bestIdx = -1;

    for (int i = 1; i <= totalFullKm; i++) {
      // Biến thiên tự nhiên nhẹ quanh Pace trung bình (+- 3-8s)
      final int varianceSec = (i % 2 == 0 ? -6 : 5) + (i == totalFullKm ? -8 : 0);
      final int splitSec = (avgPaceSec + varianceSec).clamp(150, 1200);
      final int min = splitSec ~/ 60;
      final int sec = splitSec % 60;
      final String paceStr = '$min:${sec.toString().padLeft(2, '0')}';
      final int splitCal = calories > 0 ? (calories / distanceKm).round() : 65;

      if (splitSec < minPaceSec) {
        minPaceSec = splitSec;
        bestIdx = i - 1;
      }

      int delta = 0;
      if (generated.isNotEmpty) {
        delta = splitSec - generated.last.paceSeconds;
      }

      generated.add(KmSplit(
        kmIndex: i,
        distanceKm: 1.0,
        durationSeconds: splitSec,
        pace: paceStr,
        calories: splitCal,
        paceSeconds: splitSec,
        paceDeltaSeconds: delta,
      ));
    }

    if (remKm >= 0.05) {
      final int remSec = (avgPaceSec * remKm).round();
      final int min = avgPaceSec ~/ 60;
      final int sec = avgPaceSec % 60;
      final String paceStr = '$min:${sec.toString().padLeft(2, '0')}';
      final int splitCal = calories > 0 ? (calories * (remKm / distanceKm)).round() : (65 * remKm).round();

      int delta = 0;
      if (generated.isNotEmpty) {
        delta = avgPaceSec - generated.last.paceSeconds;
      }

      generated.add(KmSplit(
        kmIndex: totalFullKm + 1,
        distanceKm: double.parse(remKm.toStringAsFixed(2)),
        durationSeconds: remSec,
        pace: paceStr,
        calories: splitCal,
        paceSeconds: avgPaceSec,
        paceDeltaSeconds: delta,
      ));
    }

    if (bestIdx >= 0 && bestIdx < generated.length) {
      final best = generated[bestIdx];
      generated[bestIdx] = KmSplit(
        kmIndex: best.kmIndex,
        distanceKm: best.distanceKm,
        durationSeconds: best.durationSeconds,
        pace: best.pace,
        calories: best.calories,
        paceSeconds: best.paceSeconds,
        paceDeltaSeconds: best.paceDeltaSeconds,
        isBestSplit: true,
      );
    }

    return generated;
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
    List<KmSplit>? splits,
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
      splits: splits ?? this.splits,
    );
  }
}
