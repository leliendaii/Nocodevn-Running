import 'package:flutter/material.dart';
import '../../models/run_session.dart';
import '../../theme/app_theme.dart';

/// Khối Thẻ Huy Hiệu Thể Thao Hoàn Chỉnh (Sports Badge Card Block)
class BadgeCardBlock extends StatelessWidget {
  final RunSession session;
  final String dateTimeStr;
  final bool showLogo;
  final bool showDistance;
  final bool showDuration;
  final bool showPace;
  final bool showCalories;
  final bool showSteps;

  const BadgeCardBlock({
    super.key,
    required this.session,
    required this.dateTimeStr,
    required this.showLogo,
    required this.showDistance,
    required this.showDuration,
    required this.showPace,
    required this.showCalories,
    required this.showSteps,
  });

  @override
  Widget build(BuildContext context) {
    final showTop = showLogo || dateTimeStr.isNotEmpty;

    // Danh sách các thông số phụ đi kèm
    final subStats = <Widget>[];
    if (showDuration) {
      subStats.add(_buildBadgeInlineStat(Icons.timer_outlined, session.formattedDuration, Colors.white));
    }
    if (showPace) {
      subStats.add(_buildBadgeInlineStat(Icons.speed_rounded, '${session.formattedPace}/km', AppTheme.secondaryNeon));
    }
    if (showCalories) {
      subStats.add(_buildBadgeInlineStat(Icons.local_fire_department_rounded, '${session.calories} kcal', AppTheme.accentOrange));
    }
    if (showSteps) {
      subStats.add(_buildBadgeInlineStat(Icons.directions_walk_rounded, '${session.totalSteps} bước', const Color(0xFF00E5FF)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryNeon.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Dòng Header: Chỉ có Logo App bên trái và Ngày chạy bên phải
          if (showTop) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showLogo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (dateTimeStr.isNotEmpty)
                  Text(
                    dateTimeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 7),
              height: 0.8,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ],

          // 2. Nội dung: Cự ly chính bên trái + Các thông số phụ căng đều 2 bên
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cột trái: Cự ly nổi bật
              if (showDistance) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'KM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryNeon,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],

              // Vạch ngăn cách dọc
              if (showDistance && subStats.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  height: 26,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ],

              // Cột phải: Các thông số phụ xếp thành lưới 2 cột căng đều 2 bên
              if (subStats.isNotEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < subStats.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          subStats[i],
                          if (i + 1 < subStats.length) ...[
                            const SizedBox(width: 10),
                            subStats[i + 1],
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeInlineStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
