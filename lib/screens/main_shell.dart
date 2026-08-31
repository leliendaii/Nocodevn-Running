import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/avatar_picker_dialog.dart';
import '../widgets/user_avatar.dart';
import 'running_screen.dart';
import 'history_screen.dart';
import 'admin_dashboard_screen.dart';
import 'auto_end_schedule_screen.dart';
import 'account_info_screen.dart';
import '../widgets/top_sync_toast.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  TimeFilter _personalFilter = TimeFilter.week;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllAppData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        '📱 [LIFECYCLE] Người dùng quay lại App từ chạy nền -> Tiếp tục theo dõi bình thường!',
      );
      _refreshAllAppData(isResumedFromBackground: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Lưu checkpoint trạng thái phòng trường hợp máy bị sập nguồn / hệ thống kill
      context.read<RunningProvider>().saveActiveCheckpointNow();
    }
  }

  void _refreshAllAppData({bool isResumedFromBackground = false}) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    auth.refreshProfileFromServer();
    final running = context.read<RunningProvider>();
    if (auth.currentUser != null) {
      running.loadAutoEndConfigForUser(auth.currentUser!.id);
    }

    // CHỈ khôi phục buổi chạy cũ khi App KHỞI ĐỘNG LẠI TỪ ĐẦU (Cold start & state idle)
    // TUYỆT ĐỐI KHÔNG được tự ý chốt lưu buổi chạy khi người dùng chỉ ẩn app chạy nền!
    if (!isResumedFromBackground && running.isIdle) {
      final recovered = await running.recoverUnfinishedRunSession();
      if (recovered != null && mounted) {
        TopSyncToast.show(
          context,
          message:
              '🛡️ Đã tự động lưu buổi chạy trước (${recovered.formattedDistance} km) do máy bị đóng đột ngột!',
        );
      }
    }

    running.refreshAllData();
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
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  // THANH ĐIỀU HƯỚNG BOTTOM NAVIGATION CAO CẤP PHONG CÁCH ATHLETIC DOCK
  Widget _buildCustomBottomNavBar() {
    final tabs = [
      {'icon': Icons.directions_run_rounded, 'label': 'Chạy'},
      {'icon': Icons.history_rounded, 'label': 'Lịch sử'},
      {'icon': Icons.insights_rounded, 'label': 'Thống kê'},
      {'icon': Icons.person_rounded, 'label': 'Cá nhân'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              final isSelected = _currentIndex == index;
              final tab = tabs[index];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentIndex = index);
                    context.read<AuthProvider>().checkUserStillExistsOnServer();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryNeon.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryNeon.withValues(alpha: 0.35)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 24,
                          color: isSelected
                              ? AppTheme.primaryNeon
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryNeon
                                : const Color(0xFF94A3B8),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
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
      appBar: AppBar(title: const Text('THỐNG KÊ CỦA TÔI')),
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
                    child: _buildMetricCard(
                      'TỔNG QUÃNG ĐƯỜNG',
                      '${totalKm.toStringAsFixed(1)} KM',
                      Icons.straighten,
                      AppTheme.primaryNeon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'THỜI GIAN CHẠY',
                      '${hours}h ${minutes}p',
                      Icons.timer_outlined,
                      AppTheme.secondaryNeon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'TỔNG CALO TIÊU THỤ',
                      '$totalCal kcal',
                      Icons.local_fire_department_outlined,
                      AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'TỔNG SỐ BUỔI CHẠY',
                      '${userRuns.length} buổi',
                      Icons.directions_run_rounded,
                      AppTheme.success,
                    ),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Icon(
                          Icons.bar_chart_rounded,
                          color: AppTheme.primaryNeon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: chartData.isEmpty || totalKm == 0
                          ? const Center(
                              child: Text(
                                'Chưa có dữ liệu cho khoảng thời gian này',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY:
                                    (chartData
                                                .map((e) => e.distanceKm)
                                                .reduce(
                                                  (a, b) => a > b ? a : b,
                                                ) *
                                            1.3)
                                        .clamp(5.0, 100.0),
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            '${chartData[groupIndex].label}\n${rod.toY.toStringAsFixed(2)} km',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, meta) {
                                        final index = val.toInt();
                                        if (index >= 0 &&
                                            index < chartData.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              chartData[index].label,
                                              style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 11,
                                              ),
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
                                barGroups: chartData.asMap().entries.map((
                                  entry,
                                ) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.distanceKm,
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppTheme.primaryNeon,
                                            AppTheme.secondaryNeon,
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        width: 14,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
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

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: MÀN HÌNH HỒ SƠ CÁ NHÂN & CÀI ĐẶT
  Widget _buildProfileTab(
    BuildContext context,
    AuthProvider auth,
    AppUser? user,
  ) {
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

                    // Nút Đăng xuất ở thẻ Profile
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

              // 2. KHỐI THỐNG KÊ TỔNG THÀNH TÍCH CHẠY BỘ (TỔNG KM, TỔNG GIỜ, TỔNG CALO)
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  // Tính tổng dồn từ lịch sử của user + phiên chạy đang diễn ra (nếu có)
                  final totalKm = running.getUserTotalDistance(user?.id);
                  final totalSeconds = running.getUserTotalDurationSeconds(user?.id);
                  final totalCalories = running.getUserTotalCalories(user?.id);

                  // Luôn tính bằng giờ (chuẩn hóa không dùng phút)
                  final totalHours = totalSeconds / 3600.0;
                  final hoursValue = totalHours >= 1000
                      ? _formatIntegerWithComma(totalHours.toInt())
                      : totalHours.toStringAsFixed(1);

                  // Định dạng KM đẹp mắt, tối ưu khi số lớn
                  final kmValue = totalKm >= 1000
                      ? _formatIntegerWithComma(totalKm.toInt())
                      : totalKm.toStringAsFixed(2);

                  // Định dạng Calories có phân cách hàng nghìn
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
                        // Cột 1: Tổng KM
                        Expanded(
                          child: _buildProfileStatItem(
                            icon: Icons.directions_run_rounded,
                            iconColor: AppTheme.primaryNeon,
                            title: 'TỔNG KM',
                            value: kmValue,
                          ),
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: AppTheme.divider,
                        ),
                        // Cột 2: Tổng Giờ Chạy (Luôn hiển thị GIỜ)
                        Expanded(
                          child: _buildProfileStatItem(
                            icon: Icons.timer_outlined,
                            iconColor: AppTheme.secondaryNeon,
                            title: 'TỔNG GIỜ',
                            value: hoursValue,
                          ),
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: AppTheme.divider,
                        ),
                        // Cột 3: Tổng Calories
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

              // 3. LỊCH VẬN ĐỘNG & CHUỖI NGÀY CHẠY (ACTIVITY HEATMAP - CHUYỂN ĐƯỢC THÁNG)
              Consumer<RunningProvider>(
                builder: (context, running, _) {
                  return _buildActivityCalendar(context, running, user);
                },
              ),
              const SizedBox(height: 16),

              // 4. KHỐI CÀI ĐẶT & TIỆN ÍCH (GỒM TÀI KHOẢN, CÀI ĐẶT LUYỆN TẬP, VỀ ỨNG DỤNG)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    // Mục 1: Tài Khoản & Bảo Mật
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

                    // Mục 2: Cài Đặt Luyện Tập (Gộp tự động chốt & nhắc nhở)
                    Consumer<RunningProvider>(
                      builder: (context, running, _) {
                        return _buildSettingsRowTile(
                          icon: Icons.tune_rounded,
                          iconColor: AppTheme.primaryNeon,
                          title: 'Cài Đặt Luyện Tập',
                          subtitle: 'Tự động lưu phiên & nhắc nhở giờ chạy',
                          statusText: running.autoEndEnabled ? 'BẬT' : 'TẮT',
                          statusColor: running.autoEndEnabled
                              ? AppTheme.primaryNeon
                              : AppTheme.textMuted,
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

                    // Mục 3: Về ứng dụng & Thông tin phiên bản
                    _buildSettingsRowTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.primaryNeon,
                      title: 'Về Ứng Dụng & Hỗ Trợ',
                      subtitle: 'Running Tracker v1.2.0 • Hướng dẫn & Bản quyền',
                      onTap: () => _showAppAboutDialog(context),
                    ),
                  ],
                ),
              ),

              // 5. THẺ QUẢN TRỊ HỆ THỐNG DÀNH RIÊNG CHO ADMIN (TÁCH THÀNH 1 CARD RIÊNG BIỆT)
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

  // Định dạng số nguyên có dấu phẩy phân cách hàng nghìn (ví dụ: 12,500)
  String _formatIntegerWithComma(num value) {
    final str = value.toInt().toString();
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
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

  // 3. LỊCH VẬN ĐỘNG & CHUỖI NGÀY CHẠY (CHUYỂN THÁNG, NÚT HÔM NAY, MÀU XANH PHỤ, GỌN GÀNG)
  Widget _buildActivityCalendar(
    BuildContext context,
    RunningProvider running,
    AppUser? user,
  ) {
    final now = DateTime.now();
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1: Mon, 7: Sun

    // Lọc các ngày mà user đã chạy trong tháng được chọn
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
          // Tiêu đề Lịch kèm Nút chuyển tháng trước/sau & Nút Hôm nay
          Row(
            children: [
              // Nút tháng trước
              InkWell(
                onTap: () {
                  setState(() {
                    _calendarMonth = DateTime(year, month - 1);
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 6),

              Text(
                'THÁNG $month/$year',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 6),

              // Nút tháng sau
              InkWell(
                onTap: isCurrentMonth
                    ? null
                    : () {
                        setState(() {
                          _calendarMonth = DateTime(year, month + 1);
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? AppTheme.surfaceLight.withValues(alpha: 0.3) : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isCurrentMonth ? AppTheme.textMuted.withValues(alpha: 0.3) : AppTheme.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút quay về Hôm nay
              InkWell(
                onTap: () {
                  setState(() {
                    _calendarMonth = DateTime(now.year, now.month);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? AppTheme.primaryNeon.withValues(alpha: 0.15)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentMonth
                          ? AppTheme.primaryNeon.withValues(alpha: 0.5)
                          : AppTheme.divider,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    'Hôm nay',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isCurrentMonth ? AppTheme.primaryNeon : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),

              const Spacer(),
              // Badge số ngày chạy (Màu xanh phụ #139EFE)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.secondaryNeon.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_run_rounded, size: 12, color: AppTheme.secondaryNeon),
                    const SizedBox(width: 4),
                    Text(
                      '${activeDaysSet.length} NGÀY',
                      style: const TextStyle(
                        fontSize: 10,
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

          // Hàng thứ trong tuần (T2 -> CN)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Lưới ngày trong tháng (Dùng Row/Column chuẩn hóa ổn định 100% không lỗi WebGL)
          Builder(
            builder: (context) {
              final totalSlots = (firstDayWeekday - 1) + daysInMonth;
              final totalWeeks = (totalSlots / 7).ceil();
              final weekWidgets = <Widget>[];

              for (int w = 0; w < totalWeeks; w++) {
                final dayCells = <Widget>[];
                for (int d = 0; d < 7; d++) {
                  final slotIndex = w * 7 + d;
                  if (slotIndex < firstDayWeekday - 1 || slotIndex >= totalSlots) {
                    dayCells.add(const Expanded(child: SizedBox(height: 28)));
                  } else {
                    final day = slotIndex - (firstDayWeekday - 1) + 1;
                    final hasRun = activeDaysSet.contains(day);
                    final isToday = (isCurrentMonth && day == now.day);

                    Color bgColor;
                    Color textColor;
                    BoxBorder? border;

                    if (hasRun) {
                      bgColor = AppTheme.secondaryNeon;
                      textColor = Colors.white;
                      border = Border.all(color: AppTheme.secondaryNeon, width: 1.2);
                    } else if (isToday) {
                      bgColor = AppTheme.surfaceLight;
                      textColor = AppTheme.primaryNeon;
                      border = Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.9), width: 1.2);
                    } else {
                      bgColor = AppTheme.surfaceLight.withValues(alpha: 0.3);
                      textColor = (isCurrentMonth && day > now.day)
                          ? AppTheme.textMuted.withValues(alpha: 0.3)
                          : AppTheme.textMuted;
                    }

                    dayCells.add(
                      Expanded(
                        child: Container(
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: border,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: (hasRun || isToday) ? FontWeight.w900 : FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }
                weekWidgets.add(Row(children: dayCells));
              }

              return Column(children: weekWidgets);
            },
          ),
          const SizedBox(height: 8),

          // Chú thích nhỏ bên dưới (Màu xanh phụ #139EFE cho Đã chạy)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.secondaryNeon,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Đã chạy',
                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 14),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryNeon, width: 1.0),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Hôm nay',
                style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modal Thông tin Ứng dụng & Hỗ trợ Chuyên Nghiệp Dành Riêng Cho Chạy Bộ
  void _showAppAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF334155), width: 1.2),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Thanh kéo Modal
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),

                // Tiêu Đề Modal
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_run_rounded,
                              color: AppTheme.primaryNeon,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'VỀ ỨNG DỤNG & HỖ TRỢ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Running Tracker • Phiên bản 1.2.0 (2026)',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 22),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 20),

                // Nội Dung Chi Tiết (Cuộn Được)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. MỤC ĐÍCH & SỨ MỆNH ỨNG DỤNG
                        _buildAboutSectionHeader('🎯 MỤC ĐÍCH & SỨ MỆNH ỨNG DỤNG'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: const Text(
                            'Running Tracker là ứng dụng thể thao chuyên sâu được thiết kế để đồng hành cùng bạn trên mọi hành trình rèn luyện sức khỏe. Ứng dụng giúp bạn theo dõi chính xác từng bước chạy, tối ưu hóa hiệu suất thể lực và bứt phá các mục tiêu cá nhân từ chạy nhẹ rèn luyện hàng ngày đến các cự ly dài.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. CÁC TÍNH NĂNG THỂ THAO NỔI BẬT
                        _buildAboutSectionHeader('🚀 TÍNH NĂNG THEO DÕI CHẠY BỘ NỔI BẬT'),
                        const SizedBox(height: 8),
                        _buildFeatureCard(
                          icon: Icons.gps_fixed_rounded,
                          iconColor: AppTheme.primaryNeon,
                          title: 'Định Vị GPS Thể Thao Độ Chính Xác Cao',
                          description:
                              'Đo đạc chính xác quãng đường (km), nhịp tốc độ (Pace phút/km), thời gian thực tế và lượng calo tiêu thụ theo thời gian thực với bộ lọc chống nhiễu chuyên dụng.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Bảo Vệ Dữ Liệu & Chống Mất Hành Trình',
                          description:
                              'Tự động ghi nhớ liên tục từng mét đường vào bộ nhớ an toàn. Nếu điện thoại vô tình sập nguồn hoặc tắt app đột ngột, toàn bộ phiên chạy sẽ được tự động khôi phục nguyên vẹn.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.videocam_rounded,
                          iconColor: AppTheme.secondaryNeon,
                          title: 'Mô Phỏng Lộ Trình 3D & Xuất Video Kỷ Niệm',
                          description:
                              'Tái hiện hành trình chạy dưới dạng mô phỏng chuyển động 3D (chế độ Toàn Cảnh bao quát & Flycam cận cảnh) và hỗ trợ lưu video chất lượng cao trực tiếp vào Album Ảnh điện thoại.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.insights_rounded,
                          iconColor: AppTheme.accentOrange,
                          title: 'Thống Kê Nhật Ký & Phân Tích Hiệu Suất',
                          description:
                              'Lưu trữ đầy đủ lịch sử các buổi tập, phân tích chi tiết tốc độ từng kilomet giúp bạn dễ dàng theo dõi sự tiến bộ và duy trì phong độ bền bỉ.',
                        ),
                        const SizedBox(height: 20),

                        // 3. HƯỚNG DẪN & TRUNG TÂM HỖ TRỢ
                        _buildAboutSectionHeader('💬 TRUNG TÂM HỖ TRỢ & HƯỚNG DẪN'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              _SupportGuideItem(
                                title: 'Cấp quyền vị trí (GPS)',
                                text:
                                    'Hãy chọn "Luôn cho phép" hoặc "Khi dùng ứng dụng" để đảm bảo tuyến đường chạy được vẽ chính xác nhất kể cả khi tắt màn hình.',
                              ),
                              SizedBox(height: 10),
                              _SupportGuideItem(
                                title: 'Quyền truy cập Album Ảnh',
                                text:
                                    'Cho phép ứng dụng lưu ảnh/video để có thể tải video mô phỏng 3D trực tiếp vào Thư viện Ảnh của iPhone.',
                              ),
                              SizedBox(height: 10),
                              _SupportGuideItem(
                                title: 'Bảo mật & Quyền riêng tư',
                                text:
                                    'Toàn bộ tọa độ GPS và thông số luyện tập của bạn được bảo mật tuyệt đối, chỉ phục vụ cho mục đích theo dõi sức khỏe của riêng bạn.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 4. BẢN QUYỀN & TÁC GIẢ
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1120),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E293B), width: 1),
                          ),
                          child: Column(
                            children: const [
                              Text(
                                'PHÁT TRIỂN & BẢN QUYỀN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tác giả: Liên Đài • 2026',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryNeon,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Chúc bạn luôn duy trì nguồn năng lượng tích cực trên từng bước chạy!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Nút Đóng Dưới Cùng
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNeon,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                        shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.4),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'ĐÃ HIỂU',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildAboutSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: AppTheme.primaryNeon,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportGuideItem extends StatelessWidget {
  final String title;
  final String text;

  const _SupportGuideItem({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 13, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
