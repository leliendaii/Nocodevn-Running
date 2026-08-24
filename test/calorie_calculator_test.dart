import 'package:flutter_test/flutter_test.dart';
import 'package:running_tracker/services/calorie_calculator.dart';

void main() {
  group('Kiểm tra thuật toán tính Calo ACSM & Phân loại vận động', () {
    test('1. Phân loại đúng hình thái vận động theo tốc độ', () {
      expect(CalorieCalculator.getActivityType(speedKmh: 0.0), 'Đứng yên');
      expect(CalorieCalculator.getActivityType(speedKmh: 3.5), 'Đi bộ chậm');
      expect(CalorieCalculator.getActivityType(speedKmh: 5.0), 'Đi đều / Đi bộ');
      expect(CalorieCalculator.getActivityType(speedKmh: 6.5), 'Đi bộ nhanh (Power Walk)');
      expect(CalorieCalculator.getActivityType(speedKmh: 8.0), 'Chạy chậm (Jogging)');
      expect(CalorieCalculator.getActivityType(speedKmh: 10.0), 'Chạy bộ đều (Running)');
      expect(CalorieCalculator.getActivityType(speedKmh: 12.0), 'Chạy nhanh (Fast Run)');
      expect(CalorieCalculator.getActivityType(speedKmh: 15.0), 'Chạy nước rút (Sprint)');
    });

    test('2. So sánh Calo khi Đi bộ 5KM vs Chạy bộ 5KM (Cùng quãng đường)', () {
      // Trường hợp A: Đi bộ 5km trong 60 phút (Vận tốc 5.0 km/h -> MET = 3.3)
      final calWalking = CalorieCalculator.calculate(
        distanceKm: 5.0,
        durationSeconds: 3600, // 1 giờ
      );

      // Trường hợp B: Chạy bộ 5km trong 30 phút (Vận tốc 10.0 km/h -> MET = 9.0)
      final calRunning = CalorieCalculator.calculate(
        distanceKm: 5.0,
        durationSeconds: 1800, // 0.5 giờ
      );

      // Chạy bộ đốt cháy nhiều năng lượng hơn trên cùng đơn vị thời gian & cường độ
      expect(calWalking > 0, true);
      expect(calRunning > 0, true);
      expect(calWalking < calRunning, true);

      // Đi bộ 1h ở tốc độ 5km/h tiêu thụ ~247 kcal (MET = 3.8)
      expect(calWalking, inInclusiveRange(230, 260));
      // Chạy bộ 30p ở tốc độ 10km/h tiêu thụ ~341 kcal (MET = 10.5)
      expect(calRunning, inInclusiveRange(320, 360));
    });

    test('3. Đi đều 30 phút vs Chạy nước rút 30 phút', () {
      final calWalking30m = CalorieCalculator.calculate(
        distanceKm: 2.5,
        durationSeconds: 1800, // 30 phút đi đều (5 km/h)
      );

      final calSprint30m = CalorieCalculator.calculate(
        distanceKm: 7.0,
        durationSeconds: 1800, // 30 phút chạy nhanh (14 km/h)
      );

      expect(calSprint30m > calWalking30m * 3, true);
    });
  });
}
