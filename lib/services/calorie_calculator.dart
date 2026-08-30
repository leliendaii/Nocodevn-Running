/// Tiện ích tính toán Calo (Kcal) theo chuẩn Y học Thể thao Quốc tế ACSM (American College of Sports Medicine)
/// & Bảng phân loại hoạt động thể lực (Compendium of Physical Activities).
class CalorieCalculator {
  // Cân nặng tiêu chuẩn trung bình của người Việt Nam (kg)
  static const double defaultWeightKg = 65.0;

  /// Phân loại hình thái vận động dựa trên tốc độ tức thời (km/h)
  static String getActivityType({required double speedKmh}) {
    if (speedKmh < 0.8) return 'Đứng yên';
    if (speedKmh < 4.5) return 'Đi bộ';
    if (speedKmh < 6.5) return 'Đi bộ nhanh (Power Walk)';
    if (speedKmh < 8.5) return 'Chạy chậm (Jogging)';
    if (speedKmh < 12.0) return 'Chạy bộ đều (Running)';
    if (speedKmh < 15.0) return 'Chạy nhanh (Fast Run)';
    return 'Chạy nước rút (Sprint)';
  }

  /// Lấy chỉ số MET (Metabolic Equivalent of Task) chuẩn y khoa
  static double getMetBySpeed({required double speedKmh}) {
    if (speedKmh <= 0.5) return 1.0; // Nghỉ ngơi
    if (speedKmh < 4.0) return 2.8;  // Đi dạo thư thả (~3 km/h)
    if (speedKmh < 5.0) return 3.3;  // Đi bộ bình thường (~4.5 km/h)
    if (speedKmh < 5.8) return 3.8;  // Đi đều nhịp nhàng (~5.3 km/h)
    if (speedKmh < 7.0) return 5.0;  // Đi bộ nhanh, thể dục (~6.4 km/h)
    if (speedKmh < 8.5) return 7.5;  // Chạy bước nhỏ, Jogging (~8 km/h)
    if (speedKmh < 10.0) return 9.0; // Chạy bộ vừa phải (~9.5 km/h)
    if (speedKmh < 11.5) return 10.5; // Chạy tốc độ tốt (~10.8 km/h)
    if (speedKmh < 13.0) return 11.8; // Chạy nhanh (~12 km/h)
    if (speedKmh < 15.0) return 12.8; // Chạy cường độ cao (~14 km/h)
    return 14.5; // Chạy nước rút (>= 15 km/h)
  }

  /// Tính Calo tiêu hao chính xác dựa trên Quãng đường (km) và Thời gian (giây)
  /// Công thức chuẩn: Kcal = MET × Cân nặng (kg) × Thời gian (giờ)
  static int calculate({
    required double distanceKm,
    required int durationSeconds,
    double weightKg = defaultWeightKg,
  }) {
    if (distanceKm <= 0.01 || durationSeconds <= 0) return 0;

    final double durationHours = durationSeconds / 3600.0;
    final double speedKmh = distanceKm / durationHours;

    // Lọc tốc độ bất thường do nhảy GPS (giới hạn tối đa 35 km/h)
    final double clampedSpeed = speedKmh.clamp(0.0, 35.0);

    final double met = getMetBySpeed(speedKmh: clampedSpeed);

    // Tính Kcal theo công thức MET
    final double calories = met * weightKg * durationHours;

    return calories.round();
  }

  /// Tính Calo tiêu hao cho một bước nhảy thời gian thực (realtime segment)
  static double calculateSegment({
    required double distanceMeters,
    required double timeSeconds,
    double weightKg = defaultWeightKg,
  }) {
    if (timeSeconds <= 0 || distanceMeters <= 0) return 0.0;

    final double speedKmh = (distanceMeters / timeSeconds) * 3.6;
    final double clampedSpeed = speedKmh.clamp(0.0, 35.0);
    final double met = getMetBySpeed(speedKmh: clampedSpeed);

    final double hours = timeSeconds / 3600.0;
    return met * weightKg * hours;
  }
}
