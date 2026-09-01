import 'package:flutter/material.dart';
import '../../models/run_session.dart';
import '../../theme/app_theme.dart';

/// Khối Header: Logo App & Ngày/Giờ chạy
class PhotoShareHeaderBlock extends StatelessWidget {
  final bool showLogo;
  final String dateTimeStr;

  const PhotoShareHeaderBlock({
    super.key,
    required this.showLogo,
    required this.dateTimeStr,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLogo && dateTimeStr.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
            ),
          if (showLogo && dateTimeStr.isNotEmpty) const SizedBox(width: 10),
          if (dateTimeStr.isNotEmpty)
            Text(
              dateTimeStr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

/// Khối Cự ly số khổng lồ (Distance Block)
class MinimalDistanceBlock extends StatelessWidget {
  final double distanceKm;

  const MinimalDistanceBlock({
    super.key,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            distanceKm.toStringAsFixed(2),
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
    );
  }
}

/// Khối hàng thông số phụ Tối giản (Thời gian, Pace, Calo)
class MinimalStatsBlock extends StatelessWidget {
  final RunSession session;
  final bool showDuration;
  final bool showPace;
  final bool showCalories;

  const MinimalStatsBlock({
    super.key,
    required this.session,
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

    if (bottomStats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: bottomStats,
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.75),
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
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}
