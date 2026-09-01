import 'package:flutter/material.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';

/// Thẻ Bảng Phân Tích Từng KM (Splits / Lap Breakdown) chuẩn thể thao chuyên nghiệp (Garmin / Strava)
class SplitsBreakdownCard extends StatelessWidget {
  final List<KmSplit> splits;
  final bool isCollapsible;
  final bool initiallyExpanded;

  const SplitsBreakdownCard({
    super.key,
    required this.splits,
    this.isCollapsible = false,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return const SizedBox.shrink();
    }

    // 1. Tìm pace nhanh nhất & chậm nhất để scale thanh bar
    int minPaceSec = 999999;
    int maxPaceSec = 0;
    double totalDistanceKm = 0.0;
    int totalDurationSec = 0;
    int totalCalories = 0;
    int totalSteps = 0;

    for (final sp in splits) {
      totalDistanceKm += sp.distanceKm;
      totalDurationSec += sp.durationSeconds;
      totalCalories += sp.calories;
      totalSteps += sp.steps;

      if (sp.paceSeconds > 0) {
        if (sp.paceSeconds < minPaceSec) minPaceSec = sp.paceSeconds;
        if (sp.paceSeconds > maxPaceSec) maxPaceSec = sp.paceSeconds;
      }
    }
    if (minPaceSec == 999999) minPaceSec = 300;
    if (maxPaceSec <= minPaceSec) maxPaceSec = minPaceSec + 60;

    // 2. Tính Pace và Tốc độ trung bình tổng
    String totalAvgPace = '0:00';
    if (totalDistanceKm > 0 && totalDurationSec > 0) {
      final double p = (totalDurationSec / 60.0) / totalDistanceKm;
      final int min = p.floor();
      final int sec = ((p - min) * 60).round();
      totalAvgPace = '$min:${sec.toString().padLeft(2, '0')}';
    }

    String totalAvgSpeed = '0.0 km/h';
    if (totalDurationSec > 0) {
      final double speed = (totalDistanceKm / totalDurationSec) * 3600;
      totalAvgSpeed = '${speed.toStringAsFixed(1)} km/h';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header khối
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bar_chart_rounded, color: AppTheme.primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'PHÂN TÍCH TỪNG KM (SPLITS)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${splits.length} CHẶNG',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryNeon,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),

          // Header các cột (KM, PACE, BIỂU ĐỒ, BƯỚC, CALO)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 44,
                  child: Text(
                    'KM',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    'PACE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'BIỂU ĐỒ TỐC ĐỘ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    'BƯỚC',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'CALO',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),

          // Danh sách từng KM Split
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: splits.length,
            separatorBuilder: (context, index) => const Divider(color: AppTheme.divider, height: 1),
            itemBuilder: (context, index) {
              final sp = splits[index];
              final isBest = sp.isBestSplit;

              // Định dạng số KM: Chặng lẻ hiển thị 2 chữ số thập phân (0.51, 0.12), không có chữ 'k'
              final String kmLabel = sp.distanceKm < 1.0
                  ? sp.distanceKm.toStringAsFixed(2)
                  : '${sp.kmIndex}';

              // Tỉ lệ độ dài thanh Bar
              final double ratio = maxPaceSec > minPaceSec
                  ? (1.0 - ((sp.paceSeconds - minPaceSec) / (maxPaceSec - minPaceSec))).clamp(0.25, 1.0)
                  : 1.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: isBest ? AppTheme.primaryNeon.withValues(alpha: 0.08) : Colors.transparent,
                child: Row(
                  children: [
                    // 1. Cột KM
                    SizedBox(
                      width: 44,
                      child: Row(
                        children: [
                          Text(
                            kmLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: isBest ? AppTheme.primaryNeon : AppTheme.textPrimary,
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 2),
                            const Text('🔥', style: TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                    ),

                    // 2. Cột Pace
                    SizedBox(
                      width: 68,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${sp.pace} /km',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: isBest ? AppTheme.primaryNeon : AppTheme.textPrimary,
                            ),
                          ),
                          if (sp.paceDeltaSeconds != 0)
                            Text(
                              sp.paceDeltaSeconds < 0
                                  ? '▲ -${sp.paceDeltaSeconds.abs()}s'
                                  : '▼ +${sp.paceDeltaSeconds}s',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: sp.paceDeltaSeconds < 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 3. Biểu đồ thanh ngang so sánh độ nhanh
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isBest
                                      ? const [Color(0xFFFF2A42), Color(0xFFFF7043)]
                                      : const [Color(0xFF139EFE), Color(0xFF00E5FF)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 4. Cột Số Bước (Trước cột Calo)
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${sp.steps}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryNeon,
                        ),
                      ),
                    ),

                    // 5. Cột Calo (Chỉ hiển thị con số, KHÔNG có chữ kcal)
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${sp.calories}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ==========================================
          // DÒNG TỔNG KẾT TOÀN CHẶNG RÕ RÀNG & ĐẸP MẮT
          // ==========================================
          const Divider(color: AppTheme.divider, height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              children: [
                // Hàng 1: Badge TỔNG CỘNG + Quãng đường lớn + Tốc độ trung bình
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2A42), Color(0xFFFF6B00)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2A42).withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            'TỔNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${totalDistanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 13, color: AppTheme.secondaryNeon),
                          const SizedBox(width: 3),
                          Text(
                            totalAvgSpeed,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF1E293B), height: 1),
                const SizedBox(height: 8),

                // Hàng 2: Chi tiết 3 thông số rõ ràng (Pace TB, Tổng bước, Tổng calo)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PACE TB',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalAvgPace /km',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.secondaryNeon,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFF1E293B)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'TỔNG BƯỚC',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatNumber(totalSteps),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.secondaryNeon,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFF1E293B)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TỔNG CALO',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalCalories kcal',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryNeon,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int val) {
    final str = val.toString();
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
