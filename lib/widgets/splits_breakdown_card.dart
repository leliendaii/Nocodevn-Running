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

    // Tìm pace nhanh nhất (giây nhỏ nhất) và chậm nhất để vẽ thanh bar tỷ lệ
    int minPaceSec = 999999;
    int maxPaceSec = 0;
    for (final sp in splits) {
      if (sp.paceSeconds > 0) {
        if (sp.paceSeconds < minPaceSec) minPaceSec = sp.paceSeconds;
        if (sp.paceSeconds > maxPaceSec) maxPaceSec = sp.paceSeconds;
      }
    }
    if (minPaceSec == 999999) minPaceSec = 300;
    if (maxPaceSec <= minPaceSec) maxPaceSec = minPaceSec + 60;

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
          // Tiêu đề khối
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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

          // Header các cột
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 48,
                  child: Text(
                    'KM',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    'PACE',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'BIỂU ĐỒ TỐC ĐỘ',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    'CALO',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
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

              // Tỉ lệ độ dài thanh Bar (Pace càng nhanh/nhỏ thì thanh càng dài và đẹp)
              final double ratio = maxPaceSec > minPaceSec
                  ? (1.0 - ((sp.paceSeconds - minPaceSec) / (maxPaceSec - minPaceSec))).clamp(0.25, 1.0)
                  : 1.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: isBest ? const Color(0xFFFF2A55).withValues(alpha: 0.08) : Colors.transparent,
                child: Row(
                  children: [
                    // 1. Cột KM (Số thứ tự chặng)
                    SizedBox(
                      width: 48,
                      child: Row(
                        children: [
                          Text(
                            sp.distanceKm < 1.0 ? '${sp.distanceKm}k' : '${sp.kmIndex}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isBest ? const Color(0xFFFF2A55) : AppTheme.textPrimary,
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 2),
                            const Text('🔥', style: TextStyle(fontSize: 10)),
                          ],
                        ],
                      ),
                    ),

                    // 2. Cột Pace
                    SizedBox(
                      width: 76,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${sp.pace} /km',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: isBest ? const Color(0xFFFF2A55) : AppTheme.textPrimary,
                            ),
                          ),
                          if (sp.paceDeltaSeconds != 0)
                            Text(
                              sp.paceDeltaSeconds < 0
                                  ? '▲ -${sp.paceDeltaSeconds.abs()}s'
                                  : '▼ +${sp.paceDeltaSeconds}s',
                              style: TextStyle(
                                fontSize: 9.5,
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
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: isBest ? AppTheme.primaryNeon : AppTheme.secondaryNeon,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 4. Cột Calo
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${sp.calories} kcal',
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
        ],
      ),
    );
  }
}
