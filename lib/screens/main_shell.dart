import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/avatar_picker_dialog.dart';
import '../widgets/dialogs/animated_reminder_dialog.dart';
import '../widgets/user_avatar.dart';
import 'running_screen.dart';
import 'history_screen.dart';
import 'admin_dashboard_screen.dart';
import 'auto_end_schedule_screen.dart';
import 'account_info_screen.dart';
import '../services/voice_coach_service.dart';
import '../services/live_workout_notification_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/top_sync_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  TimeFilter _personalFilter = TimeFilter.week;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Timer? _reminderCheckTimer;
  bool _isShowingReminderDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VoiceCoachService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllAppData();
    });
    // Quét định kỳ mỗi 10 giây để kích hoạt nhắc nhở đúng giờ kể cả khi đang mở app
    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkScheduledReminder();
    });
  }

  @override
  void dispose() {
    _reminderCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkScheduledReminder() {
    if (!mounted) return;
    final running = context.read<RunningProvider>();
    if (!running.reminderEnabled) return;

    final now = DateTime.now();
    // Kiểm tra đúng giờ & phút hẹn (hoặc trong khoảng 3 phút đầu khi người dùng vừa mở app lên)
    final isExactMinute = (now.hour == running.reminderHour && now.minute == running.reminderMinute);
    final isWithinWindow = (now.hour == running.reminderHour &&
        now.minute >= running.reminderMinute &&
        now.minute <= running.reminderMinute + 3);

    if (isExactMinute || isWithinWindow) {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? '';
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final userName = auth.currentUser?.name ?? running.getUserRealName(userId, 'Bạn');
      final timeStr = '${running.reminderHour.toString().padLeft(2, '0')}:${running.reminderMinute.toString().padLeft(2, '0')}';

      // 1. Chỉ bắn thông báo hệ thống ngoài màn hình NẾU HÔM NAY CHƯA BẮN (Tuyệt đối không bắn đúp)
      final lastNotifDate = LocalStorageService.getLastReminderNotificationDate(userId);
      if (lastNotifDate != todayKey) {
        LocalStorageService.saveLastReminderNotificationDate(userId, todayKey);
        LiveWorkoutNotificationService.showMorningReminderNotification(
          title: '⏰ Đã đến $timeStr rồi, $userName ơi!',
          body: 'Chào $userName, đã đến giờ chạy rồi. Cùng xỏ giày và bứt phá hôm nay nhé! 🔥🏃‍♂️',
        );
        VoiceCoachService.speakReminder(userName);
      }

      // 2. Nếu đang mở app -> Hiện sẵn popup nhắc nhở rung nhẹ nhẹ (chỉ hiện 1 lần/ngày)
      final lastPopupDate = LocalStorageService.getLastReminderPopupDate(userId);
      if (lastPopupDate != todayKey && !_isShowingReminderDialog && mounted) {
        _isShowingReminderDialog = true;
        LocalStorageService.saveLastReminderPopupDate(userId, todayKey);
        AnimatedReminderDialog.show(
          context,
          userName: userName,
          timeStr: timeStr,
          onStartRunning: () {
            setState(() => _currentIndex = 0);
          },
        ).then((_) {
          _isShowingReminderDialog = false;
        });
      }
    }
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
              'Đã tự động lưu buổi chạy trước (${recovered.formattedDistance} km)',
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
      _buildProfileTab(auth, user),
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
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final running = context.watch<RunningProvider>();

    final userRuns = running.getFilteredSessions(
      filter: _personalFilter,
      targetUserId: userId,
      targetUserEmail: user?.email,
      targetUserName: user?.name,
    );
    final chartData = running.getUserChartData(
      userId,
      _personalFilter,
      user?.email,
      user?.username,
      user?.name,
    );

    final double totalKm = userRuns.fold(0.0, (sum, s) => sum + s.distanceKm);
    final int totalSec = userRuns.fold(0, (sum, s) => sum + s.durationSeconds);
    final int totalCal = userRuns.fold(0, (sum, s) => sum + s.calories);

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;

    return Scaffold(
      appBar: AppBar(title: const Text('THỐNG KÊ CỦA TÔI')),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryNeon,
          backgroundColor: const Color(0xFF0F172A),
          strokeWidth: 2.5,
          onRefresh: () async {
            await Future.wait([
              context.read<RunningProvider>().refreshAllData(),
              context.read<AuthProvider>().checkUserStillExistsOnServer(),
            ]);
            if (mounted) {
              TopSyncToast.show(
                context,
                message: 'Đã cập nhật thống kê mới nhất',
                isSuccess: true,
              );
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 44,
                                        getTitlesWidget: (val, meta) {
                                          if (val == meta.max || val == 0) return const SizedBox.shrink();
                                          return Text(
                                            '${val.toInt()} km',
                                            style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
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
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (val) => FlLine(
                                      color: AppTheme.divider.withValues(alpha: 0.6),
                                      strokeWidth: 0.8,
                                      dashArray: [4, 4],
                                    ),
                                  ),
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
    AuthProvider auth,
    AppUser? user,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HỒ SƠ CÁ NHÂN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryNeon,
          backgroundColor: const Color(0xFF0F172A),
          strokeWidth: 2.5,
          onRefresh: () async {
            await Future.wait([
              context.read<RunningProvider>().refreshAllData(),
              context.read<AuthProvider>().checkUserStillExistsOnServer(),
            ]);
            if (mounted) {
              TopSyncToast.show(
                context,
                message: 'Đã cập nhật thông tin hồ sơ mới nhất',
                isSuccess: true,
              );
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  final totalKm = running.getUserTotalDistance(user?.id, user?.email, user?.username, user?.name);
                  final totalSeconds = running.getUserTotalDurationSeconds(user?.id, user?.email, user?.username, user?.name);
                  final totalCalories = running.getUserTotalCalories(user?.id, user?.email, user?.username, user?.name);

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
                    // Mục 1: Tài khoản & bảo mật
                    _buildSettingsRowTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppTheme.primaryNeon,
                      title: 'Tài khoản & bảo mật',
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

                    // Mục 2: Cài đặt luyện tập (Gộp tự động chốt & nhắc nhở)
                    Consumer<RunningProvider>(
                      builder: (context, running, _) {
                        return _buildSettingsRowTile(
                          icon: Icons.tune_rounded,
                          iconColor: AppTheme.primaryNeon,
                          title: 'Cài đặt luyện tập',
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

                    // Mục 3: Về ứng dụng & hỗ trợ
                    _buildSettingsRowTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppTheme.primaryNeon,
                      title: 'Về ứng dụng & hỗ trợ',
                      subtitle: 'Nocodevn Running v1.2.0 • Hướng dẫn & Bản quyền',
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
                    title: 'Trang quản trị hệ thống',
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
    final userSessionsInMonth = running.getUserSessions(
      user?.id ?? '',
      user?.email,
      user?.username,
      user?.name,
    ).where((s) => s.startTime.year == year && s.startTime.month == month).toList();

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

  // Modal Thông tin Ứng dụng & Hỗ trợ - Đơn giản, ngắn gọn, tự động co giãn không tràn màn hình
  void _showAppAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF334155), width: 1.2),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh kéo
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.directions_run_rounded,
                                size: 24,
                                color: AppTheme.primaryNeon,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'NOCODEVN RUNNING',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Phiên bản 1.2.0 • 2026',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mô tả đơn giản
                  const Text(
                    'Ứng dụng đơn giản giúp bạn ghi lại quá trình chạy bộ mỗi ngày, xem lại lộ trình trên bản đồ và tải video kỷ niệm về máy.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // Các chức năng có trong app
                  _buildQuickFeatureRow(Icons.gps_fixed_rounded, AppTheme.primaryNeon, 'Đo GPS khi chạy: Tự đo quãng đường (km), thời gian, tốc độ (pace) và calo.'),
                  const SizedBox(height: 7),
                  _buildQuickFeatureRow(Icons.videocam_rounded, AppTheme.secondaryNeon, 'Xem & Tải video 3D: Xem lại đường chạy mô phỏng và tải video về điện thoại.'),
                  const SizedBox(height: 7),
                  _buildQuickFeatureRow(Icons.history_rounded, const Color(0xFFF59E0B), 'Lịch sử chạy bộ: Lưu lại đầy đủ các lần chạy kèm bản đồ chi tiết.'),
                  const SizedBox(height: 7),
                  _buildQuickFeatureRow(Icons.shield_rounded, const Color(0xFF10B981), 'Tự động lưu: Đang chạy mà lỡ tắt app hay hết pin thì mở lại vẫn còn nguyên.'),
                  const SizedBox(height: 7),
                  _buildQuickFeatureRow(Icons.volume_up_rounded, const Color(0xFF38BDF8), 'Giọng nói nhắc nhở: Tự đọc số km và tốc độ khi chạy.'),
                  const SizedBox(height: 14),

                  // Tác giả & Link Zalo
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        try {
                          final uri = Uri.parse('https://zalo.me/0328376198');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Lỗi mở Zalo: $e');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0088FF).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0088FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Phát triển bởi: Lê Liên Đài',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nút Đóng
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNeon,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('ĐÓNG', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildQuickFeatureRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.35),
          ),
        ),
      ],
    );
  }
}
