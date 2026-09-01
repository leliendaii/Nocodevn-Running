import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/voice_coach_service.dart';
import '../../theme/app_theme.dart';

class AnimatedReminderDialog extends StatefulWidget {
  final String userName;
  final String timeStr;
  final VoidCallback onStartRunning;

  const AnimatedReminderDialog({
    super.key,
    required this.userName,
    required this.timeStr,
    required this.onStartRunning,
  });

  static Future<void> show(
    BuildContext context, {
    required String userName,
    required String timeStr,
    required VoidCallback onStartRunning,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimatedReminderDialog(
        userName: userName,
        timeStr: timeStr,
        onStartRunning: onStartRunning,
      ),
    );
  }

  @override
  State<AnimatedReminderDialog> createState() => _AnimatedReminderDialogState();
}

class _AnimatedReminderDialogState extends State<AnimatedReminderDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Tạo hiệu ứng rung nhẹ nhẹ và nhịp đập chuông báo
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.03), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 4), // Nghỉ 1 nhịp
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 4),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 4),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    // Rung nhẹ haptic feedback và Voice Coach phát âm thanh nhắc nhở
    HapticFeedback.vibrate();
    VoiceCoachService.speakReminder(widget.userName);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = widget.userName.trim().isNotEmpty ? widget.userName : 'Bạn';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.primaryNeon, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryNeon.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Chuông Báo với Hiệu ứng Rung Nhẹ Nhẹ
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _shakeAnimation.value,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryNeon.withValues(alpha: 0.18),
                        border: Border.all(color: AppTheme.primaryNeon, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.alarm_on_rounded,
                          size: 38,
                          color: AppTheme.primaryNeon,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            // Tiêu đề
            const Text(
              '⏰ ĐÃ ĐẾN GIỜ CHẠY BỘ!',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppTheme.primaryNeon,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Badge Giờ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.4)),
              ),
              child: Text(
                'LỊCH HẸN: ${widget.timeStr}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: AppTheme.secondaryNeon,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Lời nhắn nhắc nhở truyền cảm hứng
            Text(
              'Chào $effectiveName, đã đến giờ chạy rồi.\nCùng xỏ giày và bứt phá hôm nay nhé! 🔥🏃‍♂️',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 22),

            // Nút Bắt đầu chạy ngay & Nút Tắt
            Row(
              children: [
                // Nút Tắt thông báo
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'TẮT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Nút Bắt đầu chạy ngay
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNeon,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onStartRunning();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'CHẠY NGAY',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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
        ),
      ),
    );
  }
}
