import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/run_session.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/splits_breakdown_card.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';
import 'route_flyover_3d_screen.dart';

/// Màn hình Xem Chi Tiết 1 Buổi Chạy (Trang riêng Navigation, Flat 2 màu Đỏ & Xanh)
class SessionDetailScreen extends StatelessWidget {
  final RunSession session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm:ss');
    final running = context.watch<RunningProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    final realName = running.getUserRealName(session.userId, session.userName);
    String realAvatar = running.getUserRealAvatar(session.userId);
    if (realAvatar.isEmpty &&
        currentUser != null &&
        currentUser.id == session.userId &&
        currentUser.avatarUrl.isNotEmpty) {
      realAvatar = currentUser.avatarUrl;
    }
    final isAdmin = running.isUserAdmin(session.userId);
    final isOwnerOrAdmin = currentUser != null &&
        (currentUser.id == session.userId || currentUser.isAdmin);

    // Tên buổi chạy (lấy từ session.notes hoặc tên tự sinh)
    final sessionDisplayName = session.notes.trim().isNotEmpty
        ? session.notes.trim()
        : 'Buổi chạy ${DateFormat('dd/MM/yyyy').format(session.startTime)}';

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
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 22),
              tooltip: 'Xóa buổi chạy',
              onPressed: () => _confirmDeleteSession(context, running),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. TÊN BUỔI CHẠY ĐƯA LÊN ĐẦU TIÊN (HERO)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'TÊN BUỔI CHẠY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppTheme.secondaryNeon,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(session.startTime),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sessionDisplayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.divider, height: 1),
                  const SizedBox(height: 12),
                  // Thông tin người chạy & Giờ bắt đầu
                  Row(
                    children: [
                      UserAvatar(
                        avatarUrl: realAvatar,
                        name: realName,
                        radius: 16,
                        isAdmin: isAdmin,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              realName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              dateFormat.format(session.startTime),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ==========================================
            // 2. BẢNG CHỈ SỐ THỐNG KÊ (2 MÀU ĐỎ & XANH - GỌN GÀNG)
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  // CỰ LY CHÍNH
                  const Text(
                    'TỔNG QUÃNG ĐƯỜNG',
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

                  // LƯỚI 4 CHỈ SỐ PHỤ ĐỐI XỨNG
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.timer_outlined,
                          iconColor: AppTheme.secondaryNeon,
                          label: 'THỜI GIAN',
                          value: session.formattedDuration,
                          valueColor: AppTheme.textPrimary,
                        ),
                      ),
                      Container(width: 1, height: 50, color: AppTheme.divider),
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.speed_rounded,
                          iconColor: AppTheme.secondaryNeon,
                          label: 'PACE TRUNG BÌNH',
                          value: '${session.pace} /km',
                          valueColor: AppTheme.secondaryNeon, // Màu Xanh #139EFE
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.divider, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.primaryNeon,
                          label: 'CALO TIÊU THỤ',
                          value: '${session.calories} kcal',
                          valueColor: AppTheme.primaryNeon, // Màu Đỏ #FF2A42
                        ),
                      ),
                      Container(width: 1, height: 50, color: AppTheme.divider),
                      Expanded(
                        child: _buildStatBox(
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
              const SizedBox(height: 14),
            ],

            // ==========================================
            // 4. THÔNG TIN CHI TIẾT KỸ THUẬT
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  _buildMetaRow(
                    'Thời gian bắt đầu',
                    DateFormat('HH:mm:ss - dd/MM/yyyy').format(session.startTime),
                  ),
                  const Divider(color: AppTheme.divider, height: 16),
                  _buildMetaRow(
                    'Thời gian kết thúc',
                    DateFormat('HH:mm:ss - dd/MM/yyyy').format(
                      session.startTime.add(Duration(seconds: session.durationSeconds)),
                    ),
                  ),
                  const Divider(color: AppTheme.divider, height: 16),
                  _buildMetaRow(
                    'Số điểm tọa độ GPS',
                    '${session.routePoints.length} điểm ghi nhận',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 5. NÚT XEM VIDEO QUÁ TRÌNH 3D (XANH #139EFE)
            // ==========================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryNeon, // Màu Xanh #139EFE
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 22, color: Colors.white),
                label: const Text(
                  'XEM VIDEO QUÁ TRÌNH 3D',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RouteFlyover3DScreen(session: session),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
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
            child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await running.deleteRunSession(session.id);
              if (context.mounted) {
                TopSyncToast.show(context, message: 'Đã xóa buổi chạy thành công!');
                Navigator.of(context).pop(); // Quay lại trang lịch sử
              }
            },
            child: const Text('XÓA', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
