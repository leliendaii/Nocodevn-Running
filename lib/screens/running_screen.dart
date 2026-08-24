import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Hộp thoại lưu buổi chạy sau khi hoàn thành
  void _showSaveRunDialog(BuildContext context, RunningProvider running, String userId, String userName) {
    final notesController = TextEditingController(text: 'Buổi chạy ngoài trời');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppTheme.primaryNeon, size: 28),
            SizedBox(width: 10),
            Text(
              'HOÀN THÀNH!',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎉 Chúc mừng bạn đã hoàn thành buổi chạy!',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('QUÃNG ĐƯỜNG', '${running.distanceKm.toStringAsFixed(2)} km', AppTheme.primaryNeon),
                  Container(width: 1, height: 36, color: AppTheme.divider),
                  _buildSummaryItem('THỜI GIAN', running.formattedCurrentDuration, AppTheme.textPrimary),
                  Container(width: 1, height: 36, color: AppTheme.divider),
                  _buildSummaryItem('CALO', '${running.calories} kcal', AppTheme.secondaryNeon),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Ghi chú buổi chạy',
                hintText: 'Cảm giác chạy, thời tiết...',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.primaryNeon),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              running.resetTracking();
              Navigator.of(ctx).pop();
            },
            child: const Text('BỎ QUA', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              running.stopAndSaveTracking(
                userId: userId,
                userName: userName,
                notes: notesController.text.trim().isEmpty ? 'Buổi chạy ngoài trời' : notesController.text.trim(),
              );
              Navigator.of(ctx).pop();
              TopSyncToast.show(context, message: 'Đã lưu & đồng bộ lên Cloud!');
            },
            child: const Text('LƯU THÀNH TÍCH'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (running.wasAutoFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          TopSyncToast.show(
            context,
            message: '⏰ Đã tự động chốt & lưu buổi chạy theo khung giờ cài đặt của bạn!',
            isSuccess: true,
            duration: const Duration(seconds: 5),
          );
          running.clearAutoFinishedFlag();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOCODE RUNNING'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // Thông tin người dùng đang chạy
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      avatarUrl: user?.avatarUrl,
                      name: user?.name ?? 'Người chạy',
                      radius: 20,
                      isAdmin: user?.isAdmin == true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Vận động viên',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            user?.isAdmin == true ? '🛡️ Quản trị viên' : '🏃‍♂️ Người chạy bộ',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: running.isRunning
                            ? AppTheme.primaryNeon.withValues(alpha: 0.2)
                            : (running.isPaused ? Colors.amber.withValues(alpha: 0.2) : AppTheme.surface),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: running.isRunning
                              ? AppTheme.primaryNeon
                              : (running.isPaused ? Colors.amber : AppTheme.divider),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: running.isRunning
                                  ? AppTheme.primaryNeon
                                  : (running.isPaused ? Colors.amber : AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            running.isRunning ? 'ĐANG CHẠY' : (running.isPaused ? 'TẠM DỪNG' : 'SẴN SÀNG'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: running.isRunning
                                  ? AppTheme.primaryNeon
                                  : (running.isPaused ? Colors.amber : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // BẢNG ĐỒNG HỒ TRUNG TÂM (Đẹp mắt, thoáng đãng, tách bạch từng chỉ số)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: running.isRunning
                          ? AppTheme.primaryNeon.withValues(alpha: 0.6)
                          : AppTheme.divider,
                      width: 1.5,
                    ),
                    boxShadow: running.isRunning
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Khung Thời gian chạy
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            Text(
                              running.formattedCurrentDuration,
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text(
                              'THỜI GIAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quãng đường KM nổi bật ở giữa
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: running.isRunning ? _pulseAnimation.value : 1.0,
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              running.distanceKm.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryNeon,
                                height: 1.0,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'KILOMETERS (KM)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryNeon,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            if (running.isRunning || running.isPaused) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.directions_walk_rounded, size: 14, color: AppTheme.secondaryNeon),
                                    const SizedBox(width: 6),
                                    Text(
                                      running.currentActivityType,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.secondaryNeon,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 2 THẺ CHỈ SỐ: PACE VÀ CALORIES (TÁCH BIỆT RÕ RÀNG, KHÔNG DÍNH NHAU)
                      Row(
                        children: [
                          // Thẻ Pace TB
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.speed_rounded, color: AppTheme.secondaryNeon, size: 24),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${running.currentPace} /km',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'PACE TB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16), // Khoảng cách rõ ràng giữa 2 ô

                          // Thẻ Calories
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: AppTheme.accentOrange, size: 24),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${running.calories} kcal',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'CALORIES',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // BỘ NÚT ĐIỀU KHIỂN THAO TÁC CHẠY
              if (running.isIdle || running.state == TrackingState.finished) ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => running.startTracking(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 32, color: Colors.white),
                    label: const Text(
                      'BẮT ĐẦU CHẠY',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNeon,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ] else if (running.isRunning) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: OutlinedButton.icon(
                          onPressed: () => running.pauseTracking(),
                          icon: const Icon(Icons.pause_rounded, color: Colors.amber, size: 28),
                          label: const Text(
                            'TẠM DỪNG',
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => _showSaveRunDialog(context, running, user?.id ?? '', user?.name ?? ''),
                          icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                          label: const Text(
                            'KẾT THÚC',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (running.isPaused) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => running.resumeTracking(),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                          label: const Text(
                            'TIẾP TỤC',
                            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => _showSaveRunDialog(context, running, user?.id ?? '', user?.name ?? ''),
                          icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
                          label: const Text(
                            'KẾT THÚC',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
