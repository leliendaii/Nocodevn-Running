import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class AutoEndScheduleScreen extends StatefulWidget {
  const AutoEndScheduleScreen({super.key});

  @override
  State<AutoEndScheduleScreen> createState() => _AutoEndScheduleScreenState();
}

class _AutoEndScheduleScreenState extends State<AutoEndScheduleScreen> {
  bool _reminderEnabled = true;
  int _reminderHour = 5;
  int _reminderMinute = 30;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'default_user';

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
          'Cài Đặt Luyện Tập',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Consumer<RunningProvider>(
        builder: (context, running, _) {
          final startStr = '${running.autoStartHour.toString().padLeft(2, '0')}:${running.autoStartMinute.toString().padLeft(2, '0')}';
          final endStr = '${running.autoEndHour.toString().padLeft(2, '0')}:${running.autoEndMinute.toString().padLeft(2, '0')}';
          final reminderStr = '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // PHẦN 1: TỰ ĐỘNG KẾT THÚC & LƯU PHIÊN CHẠY
                // ==========================================
                Row(
                  children: const [
                    Icon(Icons.timer_off_outlined, color: AppTheme.primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'TỰ ĐỘNG KẾT THÚC & LƯU PHIÊN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Thẻ bật/tắt Tự động kết thúc
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryNeon, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tự động chốt phiên chạy',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Chống quên tắt khi chạy xong',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                                userId: userId,
                                enabled: val,
                                startHour: running.autoStartHour,
                                startMinute: running.autoStartMinute,
                                endHour: running.autoEndHour,
                                endMinute: running.autoEndMinute,
                              );
                              TopSyncToast.show(
                                context,
                                message: val ? 'Đã bật tự động chốt phiên chạy!' : 'Đã tắt tự động chốt!',
                              );
                            },
                          ),
                        ],
                      ),
                      if (running.autoEndEnabled) ...[
                        const Divider(color: AppTheme.divider, height: 24),

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
                                userId: userId,
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
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined, color: AppTheme.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Khung giờ bắt đầu chạy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      SizedBox(height: 1),
                                      Text('Giờ thường xỏ giày ra đường', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: Text(
                                    startStr,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

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
                                userId: userId,
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
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flag_circle_outlined, color: AppTheme.primaryNeon, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Giờ tự động chốt kết quả', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      SizedBox(height: 1),
                                      Text('Ngắt GPS & lưu lên Cloud', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    endStr,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.primaryNeon),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Thẻ giải thích chi tiết
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.secondaryNeon, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '💡 Khi bạn chạy trong khung giờ trên mà quên bấm dừng, hễ đồng hồ bước qua giờ chốt, hệ thống sẽ tự động hoàn tất và lưu bài chạy thẳng lên Cloud.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // PHẦN 2: NHẮC NHỞ LUYỆN TẬP HÀNG NGÀY
                // ==========================================
                Row(
                  children: const [
                    Icon(Icons.notifications_active_outlined, color: AppTheme.primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'NHẮC NHỞ LUYỆN TẬP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.alarm_on_rounded, color: AppTheme.primaryNeon, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thông báo nhắc chạy bộ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Duy trì kỷ luật mỗi ngày',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _reminderEnabled,
                            activeThumbColor: AppTheme.primaryNeon,
                            onChanged: (val) {
                              setState(() => _reminderEnabled = val);
                              TopSyncToast.show(
                                context,
                                message: val ? 'Đã bật nhắc nhở luyện tập hàng ngày!' : 'Đã tắt nhắc nhở!',
                              );
                            },
                          ),
                        ],
                      ),
                      if (_reminderEnabled) ...[
                        const Divider(color: AppTheme.divider, height: 24),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
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
                              setState(() {
                                _reminderHour = picked.hour;
                                _reminderMinute = picked.minute;
                              });
                              if (context.mounted) {
                                TopSyncToast.show(context, message: 'Đã đổi giờ nhắc nhở thành ${picked.format(context)}');
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alarm_rounded, color: AppTheme.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                const Text('Giờ nhắc nhở mỗi sáng:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    reminderStr,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryNeon),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}


