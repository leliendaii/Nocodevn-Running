import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/running_provider.dart';
import '../../screens/account_info_screen.dart';
import '../../screens/admin_dashboard_screen.dart';
import '../../screens/auto_end_schedule_screen.dart';
import '../../services/voice_coach_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/avatar_picker_dialog.dart';
import '../user_avatar.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  DateTime _calendarMonth = DateTime.now();

  String _formatIntegerWithComma(num value) {
    final str = value.toInt().toString();
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HỒ SƠ CÁ NHÂN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // 1. THẺ HỒ SƠ NGƯỜI DÙNG KÈM NÚT ĐĂNG XUẤT
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    // Avatar với nút Camera
                    Stack(
                      children: [
                        UserAvatar(
                          avatarUrl: user?.avatarUrl,
                          name: user?.name ?? 'Người dùng',
                          radius: 28,
                          isAdmin: user?.isAdmin == true,
                          onTap: () => AvatarPickerDialog.show(context, auth),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => AvatarPickerDialog.show(context, auth),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryNeon,
                                border: Border.all(
                                  color: AppTheme.background,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Tên hiển thị + Email + Role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.name ?? 'Người dùng',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user?.isAdmin == true ? '🛡️ Admin' : '🏃 Runner',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryNeon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Nút Đăng xuất
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Đăng xuất',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.danger,
                        size: 22,
                      ),
                      onPressed: () => auth.logout(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. KHỐI THỐNG KÊ TỔNG THÀNH TÍCH CHẠY BỘ
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  final totalKm = running.getUserTotalDistance(user?.id);
                  final totalSeconds = running.getUserTotalDurationSeconds(user?.id);
                  final totalCalories = running.getUserTotalCalories(user?.id);

                  final totalHours = totalSeconds / 3600.0;
                  final hoursValue = totalHours >= 1000
                      ? _formatIntegerWithComma(totalHours.toInt())
                      : totalHours.toStringAsFixed(1);

                  final kmValue = totalKm >= 1000
                      ? _formatIntegerWithComma(totalKm.toInt())
                      : totalKm.toStringAsFixed(2);

                  final calValue = _formatIntegerWithComma(totalCalories);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildProfileStatItem(
                            icon: Icons.directions_run_rounded,
                            iconColor: AppTheme.primaryNeon,
                            title: 'TỔNG KM',
                            value: kmValue,
                          ),
                        ),
                        Container(height: 36, width: 1, color: AppTheme.divider),
                        Expanded(
                          child: _buildProfileStatItem(
                            icon: Icons.timer_outlined,
                            iconColor: AppTheme.secondaryNeon,
                            title: 'TỔNG GIỜ',
                            value: hoursValue,
                          ),
                        ),
                        Container(height: 36, width: 1, color: AppTheme.divider),
                        Expanded(
                          child: _buildProfileStatItem(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppTheme.primaryNeon,
                            title: 'TỔNG CALO',
                            value: calValue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 3. LỊCH VẬN ĐỘNG & CHUỖI NGÀY CHẠY
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  return _buildActivityCalendar(context, running, user);
                },
              ),
              const SizedBox(height: 16),

              // 4. KHỐI CÀI ĐẶT & TIỆN ÍCH
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    // Mục 1: Huấn Luyện Viên Giọng Nói (Voice Coach)
                    _buildSettingsRowTile(
                      icon: Icons.record_voice_over_rounded,
                      iconColor: AppTheme.secondaryNeon,
                      title: 'Huấn Luyện Viên Tiếng Việt',
                      subtitle: 'Đọc to 1km, Pace & thành tích qua tai nghe',
                      statusText: VoiceCoachService.isEnabled ? 'BẬT' : 'TẮT',
                      statusColor: VoiceCoachService.isEnabled ? const Color(0xFF10B981) : AppTheme.textMuted,
                      onTap: () async {
                        final next = !VoiceCoachService.isEnabled;
                        await VoiceCoachService.setEnabled(next);
                        if (mounted) setState(() {});
                        if (next) {
                          VoiceCoachService.speak('Huấn luyện viên giọng nói tiếng Việt đã được bật!');
                        }
                      },
                    ),
                    const Divider(color: AppTheme.divider, height: 1, indent: 52),

                    // Mục 2: Tài Khoản & Bảo Mật
                    _buildSettingsRowTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppTheme.primaryNeon,
                      title: 'Tài Khoản & Bảo Mật',
                      subtitle: 'Họ tên, email & đổi mật khẩu',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const AccountInfoScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppTheme.divider, height: 1, indent: 52),

                    // Mục 3: Cài Đặt Luyện Tập
                    Consumer<RunningProvider>(
                      builder: (context, running, _) {
                        return _buildSettingsRowTile(
                          icon: Icons.tune_rounded,
                          iconColor: AppTheme.primaryNeon,
                          title: 'Cài Đặt Luyện Tập',
                          subtitle: 'Tự động lưu phiên & nhắc nhở giờ chạy',
                          statusText: running.autoEndEnabled ? 'BẬT' : 'TẮT',
                          statusColor: running.autoEndEnabled ? AppTheme.primaryNeon : AppTheme.textMuted,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const AutoEndScheduleScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const Divider(color: AppTheme.divider, height: 1, indent: 52),

                    // Mục 4: Về ứng dụng
                    _buildSettingsRowTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.primaryNeon,
                      title: 'Về Ứng Dụng & Hỗ Trợ',
                      subtitle: 'NoCode Running v2.0.0 • Bản quyền 2026',
                      onTap: () => _showAppAboutDialog(context),
                    ),
                  ],
                ),
              ),

              // 5. THẺ QUẢN TRỊ DÀNH CHO ADMIN
              if (user?.isAdmin == true) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryNeon.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: _buildSettingsRowTile(
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: AppTheme.primaryNeon,
                    title: 'Trang Quản Trị Hệ Thống',
                    subtitle: 'Quản lý runners & phân quyền dữ liệu',
                    statusText: 'ADMIN',
                    statusColor: AppTheme.primaryNeon,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStatItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String unit = '',
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRowTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? statusText,
    Color? statusColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (statusText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (statusColor ?? AppTheme.textMuted).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor ?? AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textMuted,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCalendar(
    BuildContext context,
    RunningProvider running,
    AppUser? user,
  ) {
    final now = DateTime.now();
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday;

    final userSessionsInMonth = running.sessions.where((s) {
      final isSameUser = (user?.id != null && user!.id.isNotEmpty)
          ? s.userId == user.id
          : true;
      return isSameUser &&
          s.startTime.year == year &&
          s.startTime.month == month;
    }).toList();

    final activeDaysSet = userSessionsInMonth.map((s) => s.startTime.day).toSet();
    if (running.isRunning && year == now.year && month == now.month) {
      activeDaysSet.add(now.day);
    }

    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final isCurrentMonth = (year == now.year && month == now.month);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _calendarMonth = DateTime(year, month - 1, 1);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Tháng $month/$year',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _calendarMonth = DateTime(year, month + 1, 1);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              if (!isCurrentMonth)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _calendarMonth = DateTime(now.year, now.month, 1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Text(
                      'Hôm nay',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNeon,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: AppTheme.secondaryNeon,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${activeDaysSet.length} ngày',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.secondaryNeon,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays
                .map(
                  (w) => SizedBox(
                    width: 28,
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final offset = firstDayWeekday - 1;
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final isToday = isCurrentMonth && dayNumber == now.day;
              final hasRun = activeDaysSet.contains(dayNumber);

              Color bgColor;
              Color textColor;
              Border? border;

              if (hasRun) {
                bgColor = AppTheme.secondaryNeon.withValues(alpha: 0.22);
                textColor = AppTheme.secondaryNeon;
                border = Border.all(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.6),
                  width: 1,
                );
              } else if (isToday) {
                bgColor = AppTheme.primaryNeon.withValues(alpha: 0.15);
                textColor = AppTheme.primaryNeon;
                border = Border.all(color: AppTheme.primaryNeon, width: 1);
              } else {
                bgColor = AppTheme.surfaceLight.withValues(alpha: 0.4);
                textColor = AppTheme.textMuted;
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: border,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: (hasRun || isToday)
                          ? FontWeight.w900
                          : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAppAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.divider),
        ),
        title: const Row(
          children: [
            Icon(Icons.directions_run_rounded, color: AppTheme.primaryNeon),
            SizedBox(width: 10),
            Text(
              'Running Tracker Pro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên bản: 2.0.0 (Athletic Edition)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Hệ thống theo dõi chạy bộ chuyên nghiệp tích hợp Mô phỏng 3D Flyover, Voice Coach tiếng Việt & Tự động kết thúc thông minh.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Đóng',
              style: TextStyle(color: AppTheme.primaryNeon),
            ),
          ),
        ],
      ),
    );
  }
}
