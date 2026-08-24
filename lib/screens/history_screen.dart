import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final sessions = currentUser != null
        ? running.getUserSessions(currentUser.id)
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
        child: sessions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_run_outlined, size: 64, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có buổi chạy nào',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bấm "Bắt đầu chạy" ở tab Chạy để ghi lại lượt đầu tiên!',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Thẻ tổng quan đầu trang
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.surface,
                              AppTheme.surfaceLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('TỔNG KM', '${totalKm.toStringAsFixed(1)} km', AppTheme.primaryNeon),
                            Container(width: 1, height: 40, color: AppTheme.divider),
                            _buildStatItem('BUỔI CHẠY', '${sessions.length}', AppTheme.secondaryNeon),
                            Container(width: 1, height: 40, color: AppTheme.divider),
                            _buildStatItem('THỜI GIAN', '${hours}h ${minutes}p', AppTheme.accentOrange),
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
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
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
    final realName = running.getUserRealName(session.userId, session.userName);
    final realAvatar = running.getUserRealAvatar(session.userId);
    final isAdmin = running.isUserAdmin(session.userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetailBottomSheet(context, session),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubMetric(Icons.timer_outlined, 'Thời gian', session.formattedDuration),
                  _buildSubMetric(Icons.speed_rounded, 'Pace TB', '${session.avgPace} /km'),
                  _buildSubMetric(Icons.local_fire_department_outlined, 'Calo', '${session.calories} kcal'),
                ],
              ),
              if (session.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '💬 ${session.notes}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubMetric(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  void _showDetailBottomSheet(BuildContext context, RunSession session) {
    final dateFormat = DateFormat('EEEE, dd/MM/yyyy HH:mm', 'vi');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết buổi chạy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${session.formattedDistance} KM',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryNeon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(session.startTime),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Người chạy', session.userName),
                    const Divider(color: AppTheme.divider),
                    _buildDetailRow('Tổng thời gian', session.formattedDuration),
                    const Divider(color: AppTheme.divider),
                    _buildDetailRow('Tốc độ trung bình', '${session.avgPace} phút/km'),
                    const Divider(color: AppTheme.divider),
                    _buildDetailRow('Năng lượng tiêu thụ', '${session.calories} kcal'),
                    if (session.notes.isNotEmpty) ...[
                      const Divider(color: AppTheme.divider),
                      _buildDetailRow('Ghi chú', session.notes),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
