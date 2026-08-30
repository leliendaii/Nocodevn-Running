import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/profile/profile_tab.dart';
import '../widgets/stats/personal_stats_tab.dart';
import '../widgets/top_sync_toast.dart';
import 'history_screen.dart';
import 'running_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

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
      PersonalStatsTab(userId: user?.id ?? ''),
      const ProfileTab(),
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
}
