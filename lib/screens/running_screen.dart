import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';

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
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showFinishDialog(BuildContext context, RunSession session) {
    final noteController = TextEditingController(text: session.notes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppTheme.primaryNeon, size: 48),
              ),
              const SizedBox(height: 12),
              const Text(
                'HOÀN THÀNH BUỔI CHẠY!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryNeon),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Quãng đường', '${session.formattedDistance} km', Icons.straighten),
                    _buildSummaryItem('Thời gian', session.formattedDuration, Icons.timer_outlined),
                    _buildSummaryItem('Pace', '${session.avgPace} /km', Icons.speed),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Ghi chú buổi chạy',
                  hintText: 'Cảm nhận, thời tiết, địa điểm...',
                  prefixIcon: Icon(Icons.edit_note, color: AppTheme.primaryNeon),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNeon,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                context.read<RunningProvider>().editRunSession(
                  session.id,
                  newNotes: noteController.text.trim(),
                );
                context.read<RunningProvider>().resetTracking();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('✅ Đã lưu buổi chạy thành công vào hệ thống!'),
                  ),
                );
              },
              child: const Text('LƯU BUỔI CHẠY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryNeon, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryNeon.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: AppTheme.primaryNeon, size: 20),
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
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: running.isRunning
                            ? AppTheme.success.withValues(alpha: 0.2)
                            : (running.isPaused ? Colors.amber.withValues(alpha: 0.2) : AppTheme.surface),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: running.isRunning
                                  ? AppTheme.success
                                  : (running.isPaused ? Colors.amber : AppTheme.textMuted),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            running.isRunning ? 'ĐANG CHẠY' : (running.isPaused ? 'TẠM DỪNG' : 'SẴN SÀNG'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: running.isRunning
                                  ? AppTheme.success
                                  : (running.isPaused ? Colors.amber : AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Đồng hồ chính & Quãng đường lớn trung tâm
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: running.isRunning
                          ? AppTheme.primaryNeon.withValues(alpha: 0.5)
                          : AppTheme.divider,
                      width: 1.5,
                    ),
                    boxShadow: running.isRunning
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                              blurRadius: 25,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      // Bản vẽ lộ trình chạy mô phỏng ngầm
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: CustomPaint(
                            painter: RoutePainter(
                              points: running.currentRoute,
                              color: AppTheme.primaryNeon.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ),

                      // Nội dung chỉ số đo lường trung tâm
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Đồng hồ thời gian lớn
                                Text(
                                  running.formattedCurrentDuration,
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                            const Text(
                              'THỜI GIAN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Quãng đường Km lớn
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
                                      fontSize: 68,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryNeon,
                                      height: 1.0,
                                    ),
                                  ),
                                  const Text(
                                    'KILOMETERS (KM)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Chỉ số phụ: Pace & Calories
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildMetricCard(
                                    title: 'PACE TB',
                                    value: '${running.currentPace} /km',
                                    icon: Icons.speed_rounded,
                                    color: AppTheme.secondaryNeon,
                                  ),
                                  _buildMetricCard(
                                    title: 'CALORIES',
                                    value: '${running.calories} kcal',
                                    icon: Icons.local_fire_department_rounded,
                                    color: AppTheme.accentOrange,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BỘ NÚT ĐIỀU KHIỂN (Bắt đầu, Tạm dừng, Kết thúc)
              if (running.isIdle) ...[
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    onPressed: () => running.startTracking(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.black),
                    label: const Text(
                      'BẮT ĐẦU CHẠY',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNeon,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ] else if (running.isRunning) ...[
                Row(
                  children: [
                    // Nút Tạm dừng
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: OutlinedButton.icon(
                          onPressed: () => running.pauseTracking(),
                          icon: const Icon(Icons.pause_rounded, color: Colors.amber),
                          label: const Text(
                            'TẠM DỪNG',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Nút Kết thúc
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final session = running.stopAndSaveTracking(
                              userId: user?.id ?? 'runner_01',
                              userName: user?.name ?? 'Nguyễn Văn Chạy',
                            );
                            if (session != null) {
                              _showFinishDialog(context, session);
                            }
                          },
                          icon: const Icon(Icons.stop_rounded, color: Colors.white),
                          label: const Text(
                            'KẾT THÚC',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (running.isPaused) ...[
                Row(
                  children: [
                    // Nút Tiếp tục
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => running.resumeTracking(),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                          label: const Text(
                            'TIẾP TỤC',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNeon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Nút Kết thúc
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final session = running.stopAndSaveTracking(
                              userId: user?.id ?? 'runner_01',
                              userName: user?.name ?? 'Nguyễn Văn Chạy',
                            );
                            if (session != null) {
                              _showFinishDialog(context, session);
                            }
                          },
                          icon: const Icon(Icons.stop_rounded, color: Colors.white),
                          label: const Text(
                            'KẾT THÚC',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vẽ đồ họa mô phỏng đường chạy theo thời gian thực
class RoutePainter extends CustomPainter {
  final List<RunPoint> points;
  final Color color;

  RoutePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    path.moveTo(centerX + points.first.x, centerY + points.first.y);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(centerX + points[i].x, centerY + points[i].y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) => true;
}
