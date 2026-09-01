import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/top_sync_toast.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final sessions = currentUser != null
        ? running.getUserSessions(currentUser.id, currentUser.email, currentUser.username, currentUser.name)
        : running.allSessions;
    final double totalKm = sessions.fold(0.0, (sum, s) => sum + s.distanceKm);
    final int totalSeconds = sessions.fold(0, (sum, s) => sum + s.durationSeconds);
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LỊCH SỬ CHẠY BỘ'),
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
            if (context.mounted) {
              TopSyncToast.show(
                context,
                message: '🔄 Đã cập nhật danh sách buổi chạy mới nhất!',
                isSuccess: true,
              );
            }
          },
          child: sessions.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run_outlined, size: 64, color: AppTheme.textMuted),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có buổi chạy nào',
                            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vuốt xuống để tải lại hoặc bấm "Bắt đầu chạy"!',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Thẻ tổng quan đầu trang
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryStat('TỔNG KM', '${totalKm.toStringAsFixed(1)} km', AppTheme.primaryNeon),
                              Container(width: 1, height: 40, color: AppTheme.divider),
                              _buildSummaryStat('BUỔI CHẠY', '${sessions.length}', AppTheme.secondaryNeon),
                              Container(width: 1, height: 40, color: AppTheme.divider),
                              _buildSummaryStat('THỜI GIAN', '${hours}h ${minutes}p', AppTheme.textPrimary),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Danh sách các buổi chạy
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final session = sessions[index];
                            return _buildSessionCard(context, session);
                          },
                          childCount: sessions.length,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, RunSession session) {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
    final running = context.read<RunningProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final realName = running.getUserRealName(session.userId, session.userName);
    String realAvatar = running.getUserRealAvatar(session.userId);
    if (realAvatar.isEmpty && currentUser != null && currentUser.id == session.userId && currentUser.avatarUrl.isNotEmpty) {
      realAvatar = currentUser.avatarUrl;
    }
    final isAdmin = running.isUserAdmin(session.userId);

    // Tên buổi chạy
    final sessionName = session.notes.trim().isNotEmpty
        ? session.notes.trim()
        : 'Buổi chạy ${DateFormat('dd/MM/yyyy').format(session.startTime)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tên người chạy + Cự ly
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        avatarUrl: realAvatar,
                        name: realName,
                        radius: 20,
                        isAdmin: isAdmin,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            realName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            dateFormat.format(session.startTime),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${session.formattedDistance} KM',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryNeon,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tên buổi chạy
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.secondaryNeon),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sessionName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),
              // Bảng 4 thông số ngắn gọn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCardStatItem('THỜI GIAN', session.formattedDuration),
                  _buildCardStatItem('PACE', '${session.pace} /km', color: AppTheme.secondaryNeon),
                  _buildCardStatItem('CALO', '${session.calories} kcal', color: AppTheme.primaryNeon),
                  _buildCardStatItem('TỐC ĐỘ', '${session.formattedAvgSpeed} km/h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStatItem(String label, String value, {Color color = AppTheme.textPrimary}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
