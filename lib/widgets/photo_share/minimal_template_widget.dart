import 'package:flutter/material.dart';
import '../../models/run_session.dart';
import '../../theme/app_theme.dart';

/// Template 1: Tối Giản (Minimal Overlay)
class MinimalTemplateWidget extends StatelessWidget {
  final RunSession session;
  final String dateTimeStr;
  final bool showLogo;
  final bool showDistance;
  final bool showDuration;
  final bool showPace;
  final bool showCalories;

  const MinimalTemplateWidget({
    super.key,
    required this.session,
    required this.dateTimeStr,
    required this.showLogo,
    required this.showDistance,
    required this.showDuration,
    required this.showPace,
    required this.showCalories,
  });

  @override
  Widget build(BuildContext context) {
    final bottomStats = <Widget>[];
    if (showDuration) {
      bottomStats.add(_buildMiniStat('THỜI GIAN', session.formattedDuration));
    }
    if (showPace) {
      if (bottomStats.isNotEmpty) bottomStats.add(_buildDivider());
      bottomStats.add(_buildMiniStat('PACE', '${session.formattedPace} /km'));
    }
    if (showCalories) {
      if (bottomStats.isNotEmpty) bottomStats.add(_buildDivider());
      bottomStats.add(_buildMiniStat('CALO', '${session.calories} kcal'));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Ngày ở góc trên (chỉ có logo, không có chữ)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showLogo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (dateTimeStr.isNotEmpty)
                Text(
                  dateTimeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),

          const Spacer(),

          // Thông số Cự ly Khổng lồ
          if (showDistance)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  session.distanceKm.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'KM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryNeon,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),

          if (bottomStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: bottomStats),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}
