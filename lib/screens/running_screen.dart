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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // HEADER GỘP: THÔNG TIN USER + TRẠNG THÁI + NÚT ĐĂNG XUẤT
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.name ?? 'Vận động viên',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.isAdmin == true ? '🛡️ Quản trị viên' : '🏃‍♂️ Người chạy bộ',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Badge Trạng thái
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: running.isRunning
                            ? AppTheme.primaryNeon.withValues(alpha: 0.15)
                            : (running.isPaused ? AppTheme.secondaryNeon.withValues(alpha: 0.15) : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: running.isRunning
                              ? AppTheme.primaryNeon
                              : (running.isPaused ? AppTheme.secondaryNeon : AppTheme.divider),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: running.isRunning
                                  ? AppTheme.primaryNeon
                                  : (running.isPaused ? AppTheme.secondaryNeon : AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            running.isRunning ? 'ĐANG CHẠY' : (running.isPaused ? 'TẠM DỪNG' : 'SẴN SÀNG'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: running.isRunning
                                  ? AppTheme.primaryNeon
                                  : (running.isPaused ? AppTheme.secondaryNeon : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nút Đăng xuất gọn gàng
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Đăng xuất',
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted, size: 20),
                      onPressed: () => auth.logout(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // KHÔNG GIAN ĐỒNG HỒ THỂ THAO THOÁNG ĐÃNG (PRO SPORT DASHBOARD)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Khung Thời gian chạy (Thoáng đãng, thanh lịch)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'THỜI GIAN CHẠY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          running.formattedCurrentDuration,
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    // 2. Khối Quãng đường HERO (0.00 KM) - Cực lớn, thoáng đãng, trung tâm
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: running.isRunning ? _pulseAnimation.value : 1.0,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                running.distanceKm.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 92,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryNeon,
                                  height: 0.95,
                                  letterSpacing: -3.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'KM',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryNeon,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Badge trạng thái hoạt động
                          Builder(
                            builder: (context) {
                              final activity = running.currentActivityType;
                              IconData icon;
                              Color color;

                              switch (activity) {
                                case 'Đứng yên':
                                  icon = Icons.pause_circle_outline_rounded;
                                  color = AppTheme.textMuted;
                                  break;
                                case 'Đi bộ':
                                  icon = Icons.directions_walk_rounded;
                                  color = AppTheme.secondaryNeon;
                                  break;
                                case 'Chạy bộ':
                                  icon = Icons.directions_run_rounded;
                                  color = AppTheme.primaryNeon;
                                  break;
                                case 'Bứt tốc':
                                  icon = Icons.bolt_rounded;
                                  color = AppTheme.accentOrange;
                                  break;
                                default:
                                  icon = Icons.directions_run_rounded;
                                  color = AppTheme.primaryNeon;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.15),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 16, color: color),
                                    const SizedBox(width: 8),
                                    Text(
                                      activity.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: color,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 3. 2 Thẻ Chỉ số Dưới: PACE TB & CALORIES (Riêng biệt, thoáng, cao cấp)
                    Row(
                      children: [
                        // Thẻ Pace TB
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.speed_rounded, color: AppTheme.secondaryNeon, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'PACE TB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${running.currentPace} /km',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Thẻ Calories
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.local_fire_department_rounded, color: AppTheme.primaryNeon, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'CALORIES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${running.calories} kcal',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
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
              const SizedBox(height: 20),

              // BỘ NÚT ĐIỀU KHIỂN THAO TÁC CHẠY
              if (running.isIdle || running.state == TrackingState.finished) ...[
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => running.startTracking(user?.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNeon,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'BẮT ĐẦU CHẠY',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (running.isRunning) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: OutlinedButton(
                          onPressed: () => running.pauseTracking(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.secondaryNeon, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pause_rounded, color: AppTheme.secondaryNeon, size: 22),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'TẠM DỪNG',
                                  maxLines: 1,
                                  style: TextStyle(color: AppTheme.secondaryNeon, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => _showSaveRunDialog(context, running, user?.id ?? '', user?.name ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'KẾT THÚC',
                                  maxLines: 1,
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
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
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => running.resumeTracking(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryNeon,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'TIẾP TỤC',
                                  maxLines: 1,
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () => _showSaveRunDialog(context, running, user?.id ?? '', user?.name ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'KẾT THÚC',
                                  maxLines: 1,
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
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
