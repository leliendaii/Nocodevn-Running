import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../services/voice_coach_service.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';
import '../widgets/splits_breakdown_card.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({super.key});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen>
    with SingleTickerProviderStateMixin {
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

    // Khởi tạo Huấn luyện viên giọng nói tiếng Việt
    VoiceCoachService.initialize();

    // Đăng ký thông báo Rung Haptic & Voice Coach mỗi khi hoàn thành 1 KM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final running = context.read<RunningProvider>();
        running.onKilometerMilestone = (int kmCount, String pace, int durationSeconds) {
          HapticFeedback.heavyImpact();
          VoiceCoachService.speakMilestone(kmCount, durationSeconds);
          if (mounted) {
            TopSyncToast.show(
              context,
              message: 'Đã hoàn thành $kmCount km (${VoiceCoachService.formatDurationSpeech(durationSeconds)}, Pace $pace)',
              isSuccess: true,
            );
          }
        };
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Hộp thoại lưu buổi chạy sau khi hoàn thành
  void _showSaveRunDialog(
    BuildContext context,
    RunningProvider running,
    String userId,
    String userName,
  ) {
    // 🛡️ CHỐNG BẤM NHẦM / BUỔI CHẠY QUÁ NGẮN (< 50m & < 20 giây - Giống Strava / NRC)
    if (running.distanceKm < 0.05 && running.durationSeconds < 20) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppTheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.danger, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.danger,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Buổi chạy quá ngắn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quãng đường < 50m. Bạn có muốn hủy bỏ để tránh lưu dữ liệu rác không?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                // 3 NÚT NẰM TRÊN 1 HÀNG GỌN GÀNG (XANH, ĐỎ, CAM)
                Row(
                  children: [
                    // 1. NÚT MÀU XANH: TIẾP TỤC
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryNeon,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'TIẾP TỤC',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2. NÚT MÀU ĐỎ: HỦY
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            running.resetTracking();
                            Navigator.of(ctx).pop();
                            TopSyncToast.show(
                              context,
                              message: 'Đã hủy buổi chạy',
                              isSuccess: false,
                            );
                          },
                          child: const Text(
                            'HỦY BỎ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. NÚT MÀU KHÁC (CAM/VÀNG THỂ THAO): VẪN LƯU
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentOrange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openSaveRunDialogModal(context, running, userId, userName);
                          },
                          child: const Text(
                            'VẪN LƯU',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    _openSaveRunDialogModal(context, running, userId, userName);
  }

  void _openSaveRunDialogModal(
    BuildContext context,
    RunningProvider running,
    String userId,
    String userName,
  ) {
    final defaultNote = running.generateDefaultRunNote(userId);
    final notesController = TextEditingController(text: defaultNote);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryNeon, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppTheme.primaryNeon,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'HOÀN THÀNH!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '🎉 Chúc mừng bạn đã hoàn thành buổi chạy!',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              // BẢNG TỔNG KẾT NHỎ GỌN
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'QUÃNG ĐƯỜNG',
                      '${running.distanceKm.toStringAsFixed(2)} km',
                      AppTheme.primaryNeon,
                    ),
                    Container(width: 1, height: 28, color: AppTheme.divider),
                    _buildSummaryItem(
                      'THỜI GIAN',
                      running.formattedCurrentDuration,
                      AppTheme.textPrimary,
                    ),
                    Container(width: 1, height: 28, color: AppTheme.divider),
                    _buildSummaryItem(
                      'CALO',
                      '${running.calories} kcal',
                      AppTheme.secondaryNeon,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Ô NHẬP GHI CHÚ GỌN GÀNG
              TextField(
                controller: notesController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Ghi chú buổi chạy',
                  hintText: 'Cảm giác chạy, thời tiết...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: Icon(
                    Icons.note_alt_outlined,
                    color: AppTheme.primaryNeon,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 2 NÚT NẰM TRÊN 1 HÀNG (ĐỎ & XANH)
              Row(
                children: [
                  // 1. NÚT ĐỎ: BỎ QUA
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          running.resetTracking();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'BỎ QUA',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 2. NÚT XANH: LƯU THÀNH TÍCH
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryNeon,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final double savedKm = running.distanceKm;
                          final int savedSec = running.durationSeconds;
                          final int savedCalories = running.calories;
                          final String savedPace = running.currentPace;
                          VoiceCoachService.speakFinish(savedKm, savedSec, savedCalories, savedPace);
                          running.stopAndSaveTracking(
                            userId: userId,
                            userName: userName,
                            notes: notesController.text.trim().isEmpty
                                ? defaultNote
                                : notesController.text.trim(),
                          );
                          Navigator.of(ctx).pop();
                          TopSyncToast.show(
                            context,
                            message: 'Đã lưu buổi chạy thành công',
                            isSuccess: true,
                          );
                        },
                        child: const Text(
                          'LƯU THÀNH TÍCH',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
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
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
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
            if (context.mounted) {
              TopSyncToast.show(
                context,
                message: 'Đã cập nhật dữ liệu mới nhất',
                isSuccess: true,
              );
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    children: [
              // HEADER GỘP: THÔNG TIN USER + TRẠNG THÁI + NÚT VOICE COACH + NÚT ĐĂNG XUẤT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.isAdmin == true
                                ? '🛡️ Quản trị viên'
                                : '🏃‍♂️ Người chạy bộ',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge Trạng thái Header Tối ưu bằng Selector
                    Selector<RunningProvider, (bool, bool)>(
                      selector: (_, p) => (p.isRunning, p.isPaused),
                      builder: (context, state, _) {
                        final isRunning = state.$1;
                        final isPaused = state.$2;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : (isPaused
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                      : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRunning
                                  ? const Color(0xFF10B981)
                                  : (isPaused
                                        ? const Color(0xFFF59E0B)
                                        : AppTheme.divider),
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
                                  color: isRunning
                                      ? const Color(0xFF10B981)
                                      : (isPaused
                                            ? const Color(0xFFF59E0B)
                                            : AppTheme.textMuted),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isRunning
                                    ? 'ĐANG CHẠY'
                                    : (isPaused ? 'TẠM DỪNG' : 'SẴN SÀNG'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isRunning
                                      ? const Color(0xFF10B981)
                                      : (isPaused
                                            ? const Color(0xFFF59E0B)
                                            : AppTheme.textMuted),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    // Nút Bật/Tắt Voice Coach
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: VoiceCoachService.isEnabled ? 'Tắt Voice Coach' : 'Bật Voice Coach',
                      icon: Icon(
                        VoiceCoachService.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: VoiceCoachService.isEnabled ? AppTheme.secondaryNeon : AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          VoiceCoachService.toggleVoiceCoach(!VoiceCoachService.isEnabled);
                        });
                        TopSyncToast.show(
                          context,
                          message: VoiceCoachService.isEnabled ? 'Bật tiếng' : 'Tắt tiếng',
                          isSuccess: VoiceCoachService.isEnabled,
                        );
                      },
                    ),
                    const SizedBox(width: 2),
                    // Nút Đăng xuất gọn gàng
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Đăng xuất',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
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
                    // 1. Khung Thời gian chạy (Tối ưu bằng Selector)
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
                        Selector<RunningProvider, String>(
                          selector: (_, p) => p.formattedCurrentDuration,
                          builder: (context, durationStr, _) {
                            return Text(
                              durationStr,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.0,
                                color: AppTheme.textPrimary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // 2. Khối Quãng đường HERO (0.00 KM) - Tối ưu bằng Selector
                    Selector<RunningProvider, (double, bool)>(
                      selector: (_, p) => (p.distanceKm, p.isRunning),
                      builder: (context, data, child) {
                        final distanceKm = data.$1;
                        final isRunning = data.$2;

                        return AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: isRunning ? _pulseAnimation.value : 1.0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    distanceKm.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 96,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryNeon,
                                      height: 0.95,
                                      letterSpacing: -2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'KILOMET',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryNeon,
                                      letterSpacing: 3.5,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Badge trạng thái hoạt động
                                  Selector<RunningProvider, (String, double, bool)>(
                                    selector: (_, p) => (p.currentActivityType, p.instantSpeedKmh, p.isRunning),
                                    builder: (context, activityData, _) {
                                      final activity = activityData.$1;
                                      final speed = activityData.$2;
                                      final runningState = activityData.$3;

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

                                      final String labelText = runningState && speed > 0.5
                                          ? '${activity.toUpperCase()} • ${speed.toStringAsFixed(1)} KM/H'
                                          : activity.toUpperCase();

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 7,
                                        ),
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
                                              labelText,
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
                            );
                          },
                        );
                      },
                    ),

                    // 3. 2 Thẻ Chỉ số Dưới: PACE TB & CALORIES (Tối ưu bằng Selector)
                    Row(
                      children: [
                        // Thẻ Pace TB
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
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
                                    Icon(
                                      Icons.speed_rounded,
                                      color: AppTheme.secondaryNeon,
                                      size: 20,
                                    ),
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
                                Selector<RunningProvider, String>(
                                  selector: (_, p) => p.currentPace,
                                  builder: (context, pace, _) {
                                    return Text(
                                      '$pace /km',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textPrimary,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Thẻ Calories
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
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
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: AppTheme.primaryNeon,
                                      size: 20,
                                    ),
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
                                Selector<RunningProvider, int>(
                                  selector: (_, p) => p.calories,
                                  builder: (context, calories, _) {
                                    return Text(
                                      '$calories kcal',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textPrimary,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 4. Thanh Từng KM Trực Tiếp (Live Splits Bar)
                    Selector<RunningProvider, (List<KmSplit>, bool)>(
                      selector: (_, p) => (p.currentSplits, p.isRunning || p.isPaused),
                      builder: (context, data, _) {
                        final splits = data.$1;
                        final isActive = data.$2;
                        if (!isActive || splits.isEmpty) return const SizedBox.shrink();

                        final lastSplit = splits.last;
                        return Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.flag_rounded, color: AppTheme.primaryNeon, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'KM ${lastSplit.kmIndex}: ${lastSplit.pace}/km',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (lastSplit.isBestSplit) ...[
                                    const SizedBox(width: 4),
                                    const Text('🔥', style: TextStyle(fontSize: 11)),
                                  ],
                                ],
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    useRootNavigator: true,
                                    isScrollControlled: true,
                                    backgroundColor: AppTheme.surface,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    builder: (ctx) => SafeArea(
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context).size.height * 0.75,
                                        ),
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Center(
                                                child: Container(
                                                  width: 36,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.divider,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SplitsBreakdownCard(splits: splits),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Xem ${splits.length} KM',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.primaryNeon,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryNeon),
                                    ],
                                  ),
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
              const SizedBox(height: 20),

              // BỘ NÚT ĐIỀU KHIỂN THAO TÁC CHẠY (Tối ưu bằng Selector)
              Selector<RunningProvider, TrackingState>(
                selector: (_, p) => p.state,
                builder: (context, state, _) {
                  final running = context.read<RunningProvider>();

                  if (state == TrackingState.idle || state == TrackingState.finished) {
                    return SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          VoiceCoachService.speakStart();
                          running.startTracking(user?.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNeon,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'BẮT ĐẦU CHẠY',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (state == TrackingState.running) {
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 58,
                            child: OutlinedButton(
                              onPressed: () {
                                VoiceCoachService.speakPause();
                                running.pauseTracking();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppTheme.secondaryNeon,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pause_rounded,
                                    size: 22,
                                    color: AppTheme.secondaryNeon,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TẠM DỪNG',
                                    style: TextStyle(
                                      color: AppTheme.secondaryNeon,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
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
                              onPressed: () => _showSaveRunDialog(
                                context,
                                running,
                                user?.id ?? 'user_default',
                                user?.name ?? 'Người chạy',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 8,
                                shadowColor: AppTheme.accentOrange.withValues(alpha: 0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'KẾT THÚC',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Trạng thái TẠM DỪNG (Paused)
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: () {
                                VoiceCoachService.speakResume();
                                running.resumeTracking();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryNeon,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 8,
                                shadowColor: AppTheme.secondaryNeon.withValues(alpha: 0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 22,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TIẾP TỤC',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
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
                              onPressed: () => _showSaveRunDialog(
                                context,
                                running,
                                user?.id ?? 'user_default',
                                user?.name ?? 'Người chạy',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 8,
                                shadowColor: AppTheme.accentOrange.withValues(alpha: 0.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'KẾT THÚC',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
),
);
}
}
