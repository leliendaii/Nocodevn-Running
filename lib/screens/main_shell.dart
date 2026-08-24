import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/edit_profile_dialog.dart';
import '../widgets/dialogs/change_password_dialog.dart';
import '../widgets/dialogs/avatar_picker_dialog.dart';
import 'running_screen.dart';
import 'history_screen.dart';
import 'admin_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  TimeFilter _personalFilter = TimeFilter.week;
  String _activeProfileGroup = 'schedule'; // 'schedule', 'profile', 'security', 'admin', or ''

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfileFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final List<Widget> pages = [
      const RunningScreen(),
      const HistoryScreen(),
      _buildPersonalStatsTab(user?.id ?? ''),
      _buildProfileTab(context, auth, user),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.primaryNeon.withValues(alpha: 0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            context.read<AuthProvider>().checkUserStillExistsOnServer();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_run_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.directions_run, color: AppTheme.primaryNeon),
              label: 'Chạy',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primaryNeon),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppTheme.primaryNeon),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryNeon),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: THỐNG KÊ CÁ NHÂN CỦA NGƯỜI DÙNG (DÙNG CHUNG CHO CẢ USER VÀ ADMIN KHI CHẠY)
  Widget _buildPersonalStatsTab(String userId) {
    final running = context.watch<RunningProvider>();
    final userRuns = running.getUserSessions(userId);
    final chartData = running.getUserChartData(userId, _personalFilter);

    final double totalKm = userRuns.fold(0.0, (sum, s) => sum + s.distanceKm);
    final int totalSec = userRuns.fold(0, (sum, s) => sum + s.durationSeconds);
    final int totalCal = userRuns.fold(0, (sum, s) => sum + s.calories);

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('THỐNG KÊ CỦA TÔI'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bộ lọc thời gian: Ngày / Tuần / Tháng / Năm
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    _buildFilterBtn('Ngày', TimeFilter.day),
                    _buildFilterBtn('Tuần', TimeFilter.week),
                    _buildFilterBtn('Tháng', TimeFilter.month),
                    _buildFilterBtn('Năm', TimeFilter.year),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Thẻ tổng quan 3 chỉ số chính
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('TỔNG QUÃNG ĐƯỜNG', '${totalKm.toStringAsFixed(1)} KM', Icons.straighten, AppTheme.primaryNeon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard('THỜI GIAN CHẠY', '${hours}h ${minutes}p', Icons.timer_outlined, AppTheme.secondaryNeon),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard('TỔNG CALO TIÊU THỤ', '$totalCal kcal', Icons.local_fire_department_outlined, AppTheme.accentOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard('TỔNG SỐ BUỔI CHẠY', '${userRuns.length} buổi', Icons.directions_run_rounded, AppTheme.success),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Biểu đồ cột phân nhóm
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BIỂU ĐỒ QUÃNG ĐƯỜNG (KM)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        Icon(Icons.bar_chart_rounded, color: AppTheme.primaryNeon),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: chartData.isEmpty || totalKm == 0
                          ? const Center(
                              child: Text('Chưa có dữ liệu cho khoảng thời gian này', style: TextStyle(color: AppTheme.textMuted)),
                            )
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: (chartData.map((e) => e.distanceKm).reduce((a, b) => a > b ? a : b) * 1.3).clamp(5.0, 100.0),
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        '${chartData[groupIndex].label}\n${rod.toY.toStringAsFixed(2)} km',
                                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) {
                                        final index = val.toInt();
                                        if (index >= 0 && index < chartData.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              chartData[index].label,
                                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: chartData.asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.distanceKm,
                                        color: AppTheme.primaryNeon,
                                        width: 14,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBtn(String label, TimeFilter filter) {
    final isSelected = _personalFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _personalFilter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryNeon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // TAB 4: MÀN HÌNH HỒ SƠ CÁ NHÂN & CÀI ĐẶT
  Widget _buildProfileTab(BuildContext context, AuthProvider auth, AppUser? user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HỒ SƠ CÁ NHÂN'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Avatar với nút Tải ảnh lên
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceLight,
                        border: Border.all(
                          color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(user?.avatarUrl ?? '', user?.isAdmin == true),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => AvatarPickerDialog.show(context, auth),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                            border: Border.all(color: AppTheme.background, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.name ?? 'Người dùng',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (user?.username != null && user!.username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: AppTheme.secondaryNeon, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              Text(
                user?.email ?? '',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: user?.isAdmin == true
                      ? AppTheme.secondaryNeon.withValues(alpha: 0.15)
                      : AppTheme.primaryNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.isAdmin == true ? '🛡️ QUẢN TRỊ VIÊN' : '🏃 VẬN ĐỘNG VIÊN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 20),

              // ==========================================
              // NHÓM 1: ⏰ KHUNG GIỜ CHẠY & TỰ ĐỘNG CHỐT (CHỐNG QUÊN)
              // ==========================================
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  final isExpanded = _activeProfileGroup == 'schedule';
                  final startStr = '${running.autoStartHour.toString().padLeft(2, '0')}:${running.autoStartMinute.toString().padLeft(2, '0')}';
                  final endStr = '${running.autoEndHour.toString().padLeft(2, '0')}:${running.autoEndMinute.toString().padLeft(2, '0')}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? AppTheme.primaryNeon : AppTheme.divider,
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                      boxShadow: isExpanded
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        // Header Nhóm
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeProfileGroup = isExpanded ? '' : 'schedule';
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.timer_off_outlined, color: AppTheme.primaryNeon, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Khung Giờ Chạy & Tự Động Chốt',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        running.autoEndEnabled
                                            ? 'Đang bật: $startStr ➔ $endStr (Chống quên)'
                                            : 'Đang tắt tự động chốt',
                                        style: TextStyle(
                                          color: running.autoEndEnabled ? AppTheme.secondaryNeon : AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nội dung chi tiết (Chỉ mở khi bấm)
                        if (isExpanded) ...[
                          const Divider(color: AppTheme.divider, height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tự động kết thúc khi qua giờ',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                                      },
                                    ),
                                  ],
                                ),
                                if (running.autoEndEnabled) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Giờ Bắt đầu
                                      Expanded(
                                        child: InkWell(
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
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceLight,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.divider),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orangeAccent),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Bắt đầu: $startStr',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Giờ Kết thúc
                                      Expanded(
                                        child: InkWell(
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
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceLight,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.primaryNeon, width: 1.2),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.flag_circle_outlined, size: 16, color: AppTheme.primaryNeon),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Chốt lúc: $endStr',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.primaryNeon),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryNeon.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.primaryNeon),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Nếu quên bấm kết thúc, qua $endStr hệ thống sẽ tự động chốt và lưu kết quả lên Cloud.',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // ==========================================
              // NHÓM 2: 👤 THÔNG TIN CÁ NHÂN & TÀI KHOẢN
              // ==========================================
              Builder(
                builder: (context) {
                  final isExpanded = _activeProfileGroup == 'profile';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? AppTheme.primaryNeon : AppTheme.divider,
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                      boxShadow: isExpanded
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        // Header Nhóm
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeProfileGroup = isExpanded ? '' : 'profile';
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryNeon, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Thông Tin Cá Nhân',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.name ?? 'Chưa cập nhật',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nội dung chi tiết (Chỉ mở khi bấm)
                        if (isExpanded) ...[
                          const Divider(color: AppTheme.divider, height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildProfileDetailRow(Icons.badge_outlined, 'Họ và tên', user?.name ?? 'Chưa đặt'),
                                const SizedBox(height: 10),
                                _buildProfileDetailRow(Icons.alternate_email_rounded, 'Tên đăng nhập', '@${user?.username ?? ''} (Cố định)'),
                                const SizedBox(height: 10),
                                _buildProfileDetailRow(Icons.email_outlined, 'Email', user?.email ?? 'Chưa có'),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryNeon,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => EditProfileDialog.show(context, auth),
                                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                                    label: const Text('CHỈNH SỬA THÔNG TIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

              // ==========================================
              // NHÓM 3: 🔒 BẢO MẬT & MẬT KHẨU
              // ==========================================
              Builder(
                builder: (context) {
                  final isExpanded = _activeProfileGroup == 'security';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? AppTheme.secondaryNeon : AppTheme.divider,
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                      boxShadow: isExpanded
                          ? [
                              BoxShadow(
                                color: AppTheme.secondaryNeon.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        // Header Nhóm
                        InkWell(
                          onTap: () {
                            setState(() {
                              _activeProfileGroup = isExpanded ? '' : 'security';
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_reset_rounded, color: AppTheme.secondaryNeon, size: 22),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bảo Mật & Mật Khẩu',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Thay đổi mật khẩu đăng nhập',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nội dung chi tiết (Chỉ mở khi bấm)
                        if (isExpanded) ...[
                          const Divider(color: AppTheme.divider, height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Để bảo vệ tài khoản tốt nhất, hãy đặt mật khẩu có ít nhất 6 ký tự.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.secondaryNeon,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => ChangePasswordDialog.show(context, auth),
                                    icon: const Icon(Icons.key_rounded, size: 18),
                                    label: const Text('ĐỔI MẬT KHẨU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
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

              // ==========================================
              // NHÓM 4: 🛡️ QUẢN TRỊ TOÀN HỆ THỐNG (CHỈ ADMIN)
              // ==========================================
              if (user?.isAdmin == true)
                Builder(
                  builder: (context) {
                    final isExpanded = _activeProfileGroup == 'admin';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isExpanded ? AppTheme.secondaryNeon : AppTheme.divider,
                          width: isExpanded ? 1.5 : 1.0,
                        ),
                        boxShadow: isExpanded
                            ? [
                                BoxShadow(
                                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          // Header Nhóm
                          InkWell(
                            onTap: () {
                              setState(() {
                                _activeProfileGroup = isExpanded ? '' : 'admin';
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryNeon.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.secondaryNeon, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Trang Quản Trị Hệ Thống',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryNeon),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Dành riêng cho Quản Trị Viên',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.secondaryNeon),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Nội dung chi tiết (Chỉ mở khi bấm)
                          if (isExpanded) ...[
                            const Divider(color: AppTheme.divider, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Toàn quyền quản lý danh sách runner, theo dõi tổng KM chạy và chỉnh sửa số liệu buổi chạy.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.secondaryNeon,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (ctx) => const AdminDashboardScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                                      label: const Text('MỞ TRANG QUẢN TRỊ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
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

              const SizedBox(height: 16),

              // ==========================================
              // NÚT ĐĂNG XUẤT
              // ==========================================
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                  label: const Text('ĐĂNG XUẤT TÀI KHOẢN', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryNeon),
          const SizedBox(width: 10),
          Text('$label:', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String avatarUrl, bool isAdmin) {
    if (avatarUrl.startsWith('data:image')) {
      try {
        final base64Data = avatarUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person,
            size: 55,
            color: isAdmin ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
          ),
        );
      } catch (e) {
        debugPrint('Lỗi decode base64 avatar: $e');
      }
    } else if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.person,
          size: 55,
          color: isAdmin ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
        ),
      );
    }
    return Icon(
      Icons.person,
      size: 55,
      color: isAdmin ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
    );
  }
}
