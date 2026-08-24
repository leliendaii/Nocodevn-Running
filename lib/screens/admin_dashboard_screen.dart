import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  TimeFilter _selectedFilter = TimeFilter.week;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Hộp thoại chỉnh sửa số KM và Thời gian chạy của User
  void _showEditRunDialog(BuildContext context, RunSession session) {
    final distanceController = TextEditingController(text: session.distanceKm.toStringAsFixed(2));
    final hours = session.durationSeconds ~/ 3600;
    final minutes = (session.durationSeconds % 3600) ~/ 60;
    final seconds = session.durationSeconds % 60;

    final hoursController = TextEditingController(text: hours.toString());
    final minutesController = TextEditingController(text: minutes.toString());
    final secondsController = TextEditingController(text: seconds.toString());
    final notesController = TextEditingController(text: session.notes);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.secondaryNeon, width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.secondaryNeon, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chỉnh sửa buổi chạy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vận động viên: ${session.userName}',
                  style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Ngày chạy: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // Chỉnh sửa Quãng đường (KM)
                const Text(
                  'Quãng đường chạy (KM):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    suffixText: 'KM',
                    prefixIcon: Icon(Icons.straighten, color: AppTheme.secondaryNeon),
                  ),
                ),
                const SizedBox(height: 16),

                // Chỉnh sửa Thời gian (Giờ - Phút - Giây)
                const Text(
                  'Thời gian chạy (Giờ : Phút : Giây):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '0',
                          labelText: 'Giờ',
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '30',
                          labelText: 'Phút',
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '00',
                          labelText: 'Giây',
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chỉnh sửa Ghi chú
                const Text(
                  'Ghi chú bổ sung:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Lý do chỉnh sửa / ghi chú của Admin...',
                    prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.secondaryNeon),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryNeon,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final double? newDistance = double.tryParse(distanceController.text.replaceAll(',', '.'));
                final int h = int.tryParse(hoursController.text) ?? 0;
                final int m = int.tryParse(minutesController.text) ?? 0;
                final int s = int.tryParse(secondsController.text) ?? 0;
                final int totalSec = (h * 3600) + (m * 60) + s;

                if (newDistance == null || newDistance <= 0 || totalSec <= 0) {
                  TopSyncToast.show(
                    context,
                    message: 'Vui lòng nhập Quãng đường và Thời gian hợp lệ!',
                    isSuccess: false,
                  );
                  return;
                }

                context.read<RunningProvider>().editRunSession(
                  session.id,
                  newDistanceKm: newDistance,
                  newDurationSeconds: totalSec,
                  newNotes: notesController.text.trim(),
                );

                Navigator.of(ctx).pop();
                TopSyncToast.show(context, message: 'Đã cập nhật lên Supabase Cloud!');
              },
              child: const Text('LƯU THAY ĐỔI', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Xác nhận xóa buổi chạy
  void _confirmDelete(BuildContext context, RunSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa', style: TextStyle(color: AppTheme.danger)),
        content: Text('Bạn có chắc chắn muốn xóa buổi chạy (${session.formattedDistance} km) của ${session.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () {
              context.read<RunningProvider>().deleteRunSession(session.id);
              Navigator.of(ctx).pop();
              TopSyncToast.show(context, message: 'Đã xóa buổi chạy khỏi Cloud!', isSuccess: false);
            },
            child: const Text('XÓA BUỔI CHẠY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final totalKm = running.getTotalDistance(_selectedFilter);
    final totalSec = running.getTotalDurationSeconds(_selectedFilter);
    final totalRuns = running.getSessionsByFilter(_selectedFilter).length;
    final totalUsers = running.getUniqueAthletesCount(_selectedFilter);
    final chartData = running.getChartData(_selectedFilter);

    // Lọc danh sách theo từ khóa tìm kiếm
    final allSessions = running.allSessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.notes.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUẢN TRỊ & THỐNG KÊ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh chọn Mốc Thời Gian (Ngày, Tuần, Tháng, Năm)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    _buildFilterTab('HÔM NAY', TimeFilter.day),
                    _buildFilterTab('TUẦN NÀY', TimeFilter.week),
                    _buildFilterTab('THÁNG NÀY', TimeFilter.month),
                    _buildFilterTab('NĂM NAY', TimeFilter.year),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4 THẺ CHỈ SỐ KPI TỔNG QUAN
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      'TỔNG KM',
                      '${totalKm.toStringAsFixed(1)} km',
                      Icons.straighten_rounded,
                      AppTheme.primaryNeon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      'TỔNG THỜI GIAN',
                      '${hours}h ${minutes}p',
                      Icons.timer_outlined,
                      AppTheme.secondaryNeon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      'TỔNG LƯỢT CHẠY',
                      '$totalRuns lượt',
                      Icons.directions_run_rounded,
                      AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      'VẬN ĐỘNG VIÊN',
                      '$totalUsers người',
                      Icons.group_rounded,
                      const Color(0xFFA855F7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BIỂU ĐỒ TRỰC QUAN THỐNG KÊ (fl_chart)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BIỂU ĐỒ QUÃNG ĐƯỜNG (KM)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Kilometers',
                            style: TextStyle(fontSize: 11, color: AppTheme.primaryNeon, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (chartData.map((e) => e.distanceKm).fold(0.0, (a, b) => a > b ? a : b) * 1.3)
                              .clamp(5.0, 100.0),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => AppTheme.surfaceLight,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${chartData[group.x.toInt()].label}\n',
                                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  children: [
                                    TextSpan(
                                      text: '${rod.toY.toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                        color: AppTheme.primaryNeon,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (val, meta) {
                                  if (val % 2 == 0) {
                                    return Text(
                                      '${val.toInt()}k',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < chartData.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        chartData[idx].label,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.divider, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(chartData.length, (i) {
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: chartData[i].distanceKm,
                                  color: AppTheme.primaryNeon,
                                  width: 14,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: (chartData.map((e) => e.distanceKm).fold(0.0, (a, b) => a > b ? a : b) * 1.3)
                                        .clamp(5.0, 100.0),
                                    color: AppTheme.surfaceLight,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // DANH SÁCH QUẢN LÝ & CHỈNH SỬA BUỔI CHẠY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUẢN LÝ DỮ LIỆU CHẠY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '${allSessions.length} buổi chạy',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ô tìm kiếm User
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên vận động viên...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),

              // Danh sách từng buổi chạy với nút SỬA & XÓA
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allSessions.length,
                itemBuilder: (context, index) {
                  final session = allSessions[index];
                  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                  final realName = running.getUserRealName(session.userId, session.userName);
                  final realAvatar = running.getUserRealAvatar(session.userId);
                  final isAdmin = running.isUserAdmin(session.userId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      realName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      dateFormat.format(session.startTime),
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              // Nút SỬA (Chỉnh sửa số KM và Thời gian)
                              IconButton(
                                tooltip: 'Chỉnh sửa KM & Thời gian',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                                ),
                                icon: const Icon(Icons.edit_rounded, color: AppTheme.secondaryNeon, size: 18),
                                onPressed: () => _showEditRunDialog(context, session),
                              ),
                              const SizedBox(width: 6),
                              // Nút XÓA
                              IconButton(
                                tooltip: 'Xóa buổi chạy',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                                onPressed: () => _confirmDelete(context, session),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniStat('Quãng đường', '${session.formattedDistance} km', AppTheme.primaryNeon),
                                _buildMiniStat('Thời gian', session.formattedDuration, AppTheme.textPrimary),
                                _buildMiniStat('Pace', '${session.avgPace} /km', AppTheme.secondaryNeon),
                                _buildMiniStat('Calo', '${session.calories}', AppTheme.accentOrange),
                              ],
                            ),
                          ),
                          if (session.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '📝 ${session.notes}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, TimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryNeon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }
}
