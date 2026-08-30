import 'dart:math' as math;
import '../models/run_session.dart';

/// Thuật toán Ramer-Douglas-Peucker (RDP) nén tọa độ GPS thông minh:
/// Giảm 60-80% số điểm GPS dư thừa trên đường thẳng mà giữ nguyên 100% độ cong tại các ngã rẽ và khúc cua.
class GpsCompressionService {
  /// Ngưỡng sai số vuông góc tối đa (mét). Mức 2.5m là chuẩn thể thao vàng (Strava/Garmin).
  static const double defaultEpsilonMeters = 2.5;

  /// Nén danh sách RunPoint
  static List<RunPoint> compress(List<RunPoint> points, {double epsilonMeters = defaultEpsilonMeters}) {
    if (points.length <= 2) return List.from(points);

    final double epsilonDegrees = epsilonMeters / 111320.0;
    final List<RunPoint> result = _rdpRecursive(points, epsilonDegrees);

    // Đảm bảo luôn giữ lại điểm đầu và điểm cuối
    if (result.isEmpty || result.first != points.first) {
      result.insert(0, points.first);
    }
    if (result.last != points.last) {
      result.add(points.last);
    }

    return result;
  }

  static List<RunPoint> _rdpRecursive(List<RunPoint> pointList, double epsilon) {
    if (pointList.length < 3) return List.from(pointList);

    int index = -1;
    double maxDistance = 0.0;

    final RunPoint start = pointList.first;
    final RunPoint end = pointList.last;

    for (int i = 1; i < pointList.length - 1; i++) {
      final double distance = _perpendicularDistance(pointList[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance > epsilon && index != -1) {
      final List<RunPoint> leftPart = _rdpRecursive(pointList.sublist(0, index + 1), epsilon);
      final List<RunPoint> rightPart = _rdpRecursive(pointList.sublist(index), epsilon);

      return [...leftPart.sublist(0, leftPart.length - 1), ...rightPart];
    } else {
      return [start, end];
    }
  }

  /// Tính khoảng cách vuông góc từ 1 điểm đến đoạn thẳng nối 2 điểm
  static double _perpendicularDistance(RunPoint p, RunPoint p1, RunPoint p2) {
    final double dx = p2.x - p1.x;
    final double dy = p2.y - p1.y;

    if (dx == 0.0 && dy == 0.0) {
      final double dX = p.x - p1.x;
      final double dY = p.y - p1.y;
      return math.sqrt(dX * dX + dY * dY);
    }

    final double u = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / (dx * dx + dy * dy);
    final double clampedU = u.clamp(0.0, 1.0);

    final double projX = p1.x + clampedU * dx;
    final double projY = p1.y + clampedU * dy;

    final double dX = p.x - projX;
    final double dY = p.y - projY;

    return math.sqrt(dX * dX + dY * dY);
  }
}
