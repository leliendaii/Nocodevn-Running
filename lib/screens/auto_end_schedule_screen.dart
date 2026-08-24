import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class AutoEndScheduleScreen extends StatelessWidget {
  const AutoEndScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Khung Giờ Tự Động Chốt',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Consumer<RunningProvider>(
        builder: (context, running, _) {
          final startStr = '${running.autoStartHour.toString().padLeft(2, '0')}:${running.autoStartMinute.toString().padLeft(2, '0')}';
          final endStr = '${running.autoEndHour.toString().padLeft(2, '0')}:${running.autoEndMinute.toString().padLeft(2, '0')}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ chính bật/tắt
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: running.autoEndEnabled ? AppTheme.primaryNeon : AppTheme.divider,
                      width: running.autoEndEnabled ? 1.5 : 1.0,
                    ),
                    boxShadow: running.autoEndEnabled
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.timer_off_outlined, color: AppTheme.primaryNeon, size: 24),
                              ),
                              const SizedBox(width: 14),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tự động chốt buổi chạy',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Chống quên khi chạy sáng',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: running.autoEndEnabled,
                            activeThumbColor: AppTheme.primaryNeon,
                            onChanged: (val) {
                              running.updateAutoEndSchedule(
                                enabled: val,
                                startHour: running.autoStartHour,
                                startMinute: running.autoStartMinute,
                                endHour: running.autoEndHour,
                                endMinute: running.autoEndMinute,
                              );
                              TopSyncToast.show(
                                context,
                                message: val ? 'Đã bật tự động chốt buổi chạy!' : 'Đã tắt tự động chốt!',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Chọn khung giờ
                if (running.autoEndEnabled) ...[
                  const Text(
                    'CÀI ĐẶT KHUNG GIỜ CHẠY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Khối Giờ Bắt Đầu
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: running.autoStartHour, minute: running.autoStartMinute),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primaryNeon,
                                surface: AppTheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        running.updateAutoEndSchedule(
                          enabled: true,
                          startHour: picked.hour,
                          startMinute: picked.minute,
                          endHour: running.autoEndHour,
                          endMinute: running.autoEndMinute,
                        );
                        if (context.mounted) {
                          TopSyncToast.show(context, message: 'Đã đổi giờ bắt đầu thành ${picked.format(context)}');
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.wb_sunny_outlined, color: Colors.orangeAccent, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Giờ bắt đầu chạy sáng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                SizedBox(height: 2),
                                Text('Khung giờ bạn thường xỏ giày ra đường', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Text(
                              startStr,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.orangeAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Khối Giờ Tự Động Kết Thúc
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: running.autoEndHour, minute: running.autoEndMinute),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primaryNeon,
                                surface: AppTheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        running.updateAutoEndSchedule(
                          enabled: true,
                          startHour: running.autoStartHour,
                          startMinute: running.autoStartMinute,
                          endHour: picked.hour,
                          endMinute: picked.minute,
                        );
                        if (context.mounted) {
                          TopSyncToast.show(context, message: 'Đã đổi giờ chốt thành ${picked.format(context)}');
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryNeon, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flag_circle_outlined, color: AppTheme.primaryNeon, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Giờ tự động chốt kết quả', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                SizedBox(height: 2),
                                Text('Tự động ngắt GPS & lưu lên Cloud', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryNeon),
                            ),
                            child: Text(
                              endStr,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryNeon),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thẻ giải thích chi tiết
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.secondaryNeon, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '💡 Cách hoạt động:\nKhi bạn chạy buổi sáng mà quên bấm kết thúc, hễ đồng hồ bước qua giờ đã cài ở trên, hệ thống sẽ tự động chốt số KM, tính toán thời gian, Pace, Calo và lưu thẳng lên Supabase Cloud.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
