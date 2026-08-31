import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../services/live_workout_notification_service.dart';

class AutoEndScheduleScreen extends StatelessWidget {
  const AutoEndScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final userId = user?.id ?? 'default_user';

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
          final reminderStr = '${running.reminderHour.toString().padLeft(2, '0')}:${running.reminderMinute.toString().padLeft(2, '0')}';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // PHẦN 1: TỰ ĐỘNG KẾT THÚC PHIÊN CHẠY
                // ==========================================
                Row(
                  children: const [
                    Icon(Icons.timer_off_outlined, color: AppTheme.primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'TỰ ĐỘNG KẾT THÚC PHIÊN CHẠY',
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
                              const Text(
                                'Tự động kết thúc phiên chạy',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
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
                                message: val ? 'Đã bật tự động kết thúc' : 'Đã tắt tự động kết thúc',
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined, color: AppTheme.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                const Text('Giờ bắt đầu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                TopSyncToast.show(context, message: 'Đã đổi giờ kết thúc thành ${picked.format(context)}');
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flag_circle_outlined, color: AppTheme.primaryNeon, size: 18),
                                const SizedBox(width: 10),
                                const Text('Giờ kết thúc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                const SizedBox(height: 24),

                // ==========================================
                // PHẦN 2: NHẮC NHỞ
                // ==========================================
                Row(
                  children: const [
                    Icon(Icons.notifications_active_outlined, color: AppTheme.primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'NHẮC NHỞ',
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
                              const Text(
                                'Nhắc nhở',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          Switch(
                            value: running.reminderEnabled,
                            activeThumbColor: AppTheme.primaryNeon,
                            onChanged: (val) {
                              running.updateReminderSchedule(
                                userId: userId,
                                enabled: val,
                                hour: running.reminderHour,
                                minute: running.reminderMinute,
                              );
                              TopSyncToast.show(
                                context,
                                message: val
                                    ? 'Đã bật nhắc nhở lúc $reminderStr'
                                    : 'Đã tắt nhắc nhở',
                              );
                            },
                          ),
                        ],
                      ),
                      if (running.reminderEnabled) ...[
                        const Divider(color: AppTheme.divider, height: 24),
                        // Giờ nhắc nhở
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: running.reminderHour, minute: running.reminderMinute),
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
                              running.updateReminderSchedule(
                                userId: userId,
                                enabled: true,
                                hour: picked.hour,
                                minute: picked.minute,
                              );
                              if (context.mounted) {
                                TopSyncToast.show(context, message: 'Đã đổi giờ nhắc nhở thành ${picked.format(context)}');
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alarm_rounded, color: AppTheme.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                const Text('Giờ nhắc nhở', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        const SizedBox(height: 12),
                        // Nút thử nghiệm thông báo
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryNeon,
                              side: const BorderSide(color: AppTheme.primaryNeon, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.notifications_active_rounded, size: 18),
                            label: const Text(
                              'THỬ BẮN THÔNG BÁO RA MÀN HÌNH',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            onPressed: () async {
                              await LiveWorkoutNotificationService.showMorningReminderNotification(
                                title: 'Nhắc nhở',
                                body: 'Thông báo hoạt động tốt! Giờ nhắc nhở đã cài: $reminderStr',
                              );
                              if (context.mounted) {
                                TopSyncToast.show(
                                  context,
                                  message: 'Đã gửi thông báo thử nghiệm ra màn hình!',
                                );
                              }
                            },
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
