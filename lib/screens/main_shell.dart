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

              // NÚT MỞ TRANG QUẢN TRỊ DÀNH RIÊNG CHO ADMIN
              if (user?.isAdmin == true) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.surface,
                        AppTheme.secondaryNeon.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.secondaryNeon, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryNeon.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.secondaryNeon, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRANG QUẢN TRỊ TOÀN HỆ THỐNG',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.secondaryNeon),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Thống kê toàn bộ runner & chỉnh sửa số KM, thời gian',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryNeon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const AdminDashboardScreen()),
                          );
                        },
                        child: const Row(
                          children: [
                            Text('MỞ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Nút Chỉnh sửa Họ tên & Email
              Container(
                padding: const EdgeInsets.all(16),
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
                        color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryNeon, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Đổi Tên, Username & Email', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.primaryNeon,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => EditProfileDialog.show(context, auth),
                      child: const Text('CHỈNH SỬA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // KHUNG GIỜ CHẠY & TỰ ĐỘNG CHỐT (CHỐNG QUÊN)
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  final startStr = '${running.autoStartHour.toString().padLeft(2, '0')}:${running.autoStartMinute.toString().padLeft(2, '0')}';
                  final endStr = '${running.autoEndHour.toString().padLeft(2, '0')}:${running.autoEndMinute.toString().padLeft(2, '0')}';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: running.autoEndEnabled
                            ? AppTheme.primaryNeon.withValues(alpha: 0.5)
                            : AppTheme.divider,
                        width: running.autoEndEnabled ? 1.5 : 1.0,
                      ),
                      boxShadow: running.autoEndEnabled
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tự động chốt buổi chạy',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Chống quên kết thúc khi chạy',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
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
                          const SizedBox(height: 14),
                          const Divider(color: AppTheme.divider, height: 1),
                          const SizedBox(height: 14),
                          const Text(
                            'Khung giờ chạy buổi sáng của bạn:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Chọn giờ Bắt đầu
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.divider),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orangeAccent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bắt đầu: $startStr',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Chọn giờ Tự động kết thúc
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.primaryNeon, width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.flag_circle_outlined, size: 16, color: AppTheme.primaryNeon),
                                        const SizedBox(width: 8),
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
                                const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryNeon),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nếu bạn quên bấm kết thúc, qua $endStr hệ thống sẽ tự động chốt số KM và lưu kết quả lên Cloud.',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
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
              const SizedBox(height: 10),

              // Nút Đổi mật khẩu
              Container(
                padding: const EdgeInsets.all(16),
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
                        color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.key_rounded, color: AppTheme.secondaryNeon, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bảo mật tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Thay đổi mật khẩu đăng nhập', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryNeon,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => ChangePasswordDialog.show(context, auth),
                      child: const Text('ĐỔI MẬT KHẨU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nút Đăng xuất
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                  label: const Text('ĐĂNG XUẤT', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
