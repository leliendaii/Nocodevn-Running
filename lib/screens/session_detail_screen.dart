import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/run_session.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/splits_breakdown_card.dart';
import '../widgets/top_sync_toast.dart';
import 'route_flyover_3d_screen.dart';

/// Màn hình Xem Chi Tiết 1 Buổi Chạy (Trang riêng Navigation, Flat 2 màu Đỏ & Xanh)
class SessionDetailScreen extends StatefulWidget {
  final RunSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final running = context.watch<RunningProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    final isOwnerOrAdmin =
        currentUser != null &&
        (currentUser.id == session.userId || currentUser.isAdmin);

    // Tên buổi chạy
    final sessionDisplayName = session.notes.trim().isNotEmpty
        ? session.notes.trim()
        : 'Buổi chạy ${dateFormat.format(session.startTime)}';

    final startTimeStr = timeFormat.format(session.startTime);
    final endTimeStr = timeFormat.format(
      session.startTime.add(Duration(seconds: session.durationSeconds)),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CHI TIẾT BUỔI CHẠY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isOwnerOrAdmin)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.danger,
                size: 22,
              ),
              tooltip: 'Xóa buổi chạy',
              onPressed: () => _confirmDeleteSession(context, running),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ==========================================
                // 1. THẺ THÔNG TIN BUỔI CHẠY (CĂN GIỮA TOÀN BỘ)
                // ==========================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badge Ngày chạy căn giữa đưa lên trên đầu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          dateFormat.format(session.startTime),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryNeon,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tên buổi chạy căn giữa nổi bật ở dưới ngày
                      Text(
                        sessionDisplayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AppTheme.divider, height: 1),
                      const SizedBox(height: 14),

                      // 3 thông số Bắt đầu - Kết thúc - Tọa độ GPS (Căn giữa hoàn hảo)
                      Row(
                        children: [
                          Expanded(
                            child: _buildCenteredMetaItem(
                              icon: Icons.play_circle_outline_rounded,
                              iconColor: AppTheme.secondaryNeon,
                              label: 'BẮT ĐẦU',
                              value: startTimeStr,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: AppTheme.divider,
                          ),
                          Expanded(
                            child: _buildCenteredMetaItem(
                              icon: Icons.flag_outlined,
                              iconColor: AppTheme.primaryNeon,
                              label: 'KẾT THÚC',
                              value: endTimeStr,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: AppTheme.divider,
                          ),
                          Expanded(
                            child: _buildCenteredMetaItem(
                              icon: Icons.directions_walk_rounded,
                              iconColor: AppTheme.secondaryNeon,
                              label: 'SỐ BƯỚC',
                              value: session.formattedTotalSteps,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ==========================================
                // 2. BẢNG CHỈ SỐ THỐNG KÊ (CĂN GIỮA TOÀN BỘ, 2 MÀU ĐỎ & XANH)
                // ==========================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // CỰ LY CHÍNH
                      const Text(
                        'TỔNG QUÃNG ĐƯỜNG',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            session.formattedDistance,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryNeon, // Màu Đỏ #FF2A42
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryNeon,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.divider, height: 1),
                      const SizedBox(height: 16),

                      // LƯỚI 4 CHỈ SỐ PHỤ ĐỐI XỨNG (CĂN GIỮA)
                      Row(
                        children: [
                          Expanded(
                            child: _buildCenteredStatBox(
                              icon: Icons.timer_outlined,
                              iconColor: AppTheme.secondaryNeon,
                              label: 'THỜI GIAN',
                              value: session.formattedDuration,
                              valueColor: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: AppTheme.divider,
                          ),
                          Expanded(
                            child: _buildCenteredStatBox(
                              icon: Icons.speed_rounded,
                              iconColor: AppTheme.secondaryNeon,
                              label: 'PACE TRUNG BÌNH',
                              value: '${session.pace} /km',
                              valueColor:
                                  AppTheme.secondaryNeon, // Màu Xanh #139EFE
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AppTheme.divider, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCenteredStatBox(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: AppTheme.primaryNeon,
                              label: 'CALO TIÊU THỤ',
                              value: '${session.calories} kcal',
                              valueColor:
                                  AppTheme.primaryNeon, // Màu Đỏ #FF2A42
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: AppTheme.divider,
                          ),
                          Expanded(
                            child: _buildCenteredStatBox(
                              icon: Icons.bolt_rounded,
                              iconColor: AppTheme.secondaryNeon,
                              label: 'TỐC ĐỘ TRUNG BÌNH',
                              value: '${session.formattedAvgSpeed} km/h',
                              valueColor: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ==========================================
                // 3. BẢNG PHÂN TÍCH TỪNG KM (SPLITS BREAKDOWN)
                // ==========================================
                if (session.effectiveSplits.isNotEmpty) ...[
                  SplitsBreakdownCard(splits: session.effectiveSplits),
                ],
              ],
            ),
          ),

          // Nút 'Xem quá trình' sát xuống gần dưới, cách bottom đúng 15px
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(child: _buildAnimatedProcessButton(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedProcessButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryNeon, // Màu Xanh #139EFE
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 11,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
            ),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        RouteFlyover3DScreen(session: widget.session),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 240),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 180,
                    ),
                  ),
                );
              },
              child: const Text(
                'Video tổng quan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildCenteredMetaItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCenteredStatBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteSession(BuildContext context, RunningProvider running) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.danger, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
            SizedBox(width: 8),
            Text(
              'Xóa buổi chạy?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn buổi chạy này khỏi lịch sử và không thể hoàn tác.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'HỦY',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await running.deleteRunSession(widget.session.id);
              if (context.mounted) {
                TopSyncToast.show(
                  context,
                  message: 'Đã xóa buổi chạy thành công!',
                );
                Navigator.of(context).pop(); // Quay lại trang lịch sử
              }
            },
            child: const Text(
              'XÓA',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
