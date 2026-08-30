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

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  TimeFilter _selectedFilter = TimeFilter.week;
  String? _selectedUserId; // null = Tất cả vận động viên
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Hộp thoại Tạo Mới Buổi Chạy Thủ Công Cho User (Tính năng Admin)
  void _showCreateRunDialog(BuildContext context, RunningProvider running) {
    final profiles = running.allUserProfiles;
    final List<Map<String, dynamic>> userList = profiles.values.toList();

    // Nếu profiles trống, lấy danh sách userId duy nhất từ sessions
    if (userList.isEmpty) {
      final userIds = running.allSessions.map((s) => s.userId).toSet();
      for (final uid in userIds) {
        userList.add({
          'id': uid,
          'name': running.getUserRealName(uid, 'Runner'),
          'avatar_url': running.getUserRealAvatar(uid),
          'role': running.isUserAdmin(uid) ? 'admin' : 'user',
        });
      }
    }

    if (userList.isEmpty) {
      TopSyncToast.show(
        context,
        message: 'Chưa có thông tin vận động viên nào trong hệ thống!',
        isSuccess: false,
      );
      return;
    }

    String selectedUid = _selectedUserId ?? userList.first['id']?.toString() ?? '';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final distanceController = TextEditingController(text: '5.0');
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '30');
    final secondsController = TextEditingController(text: '00');
    final notesController = TextEditingController(text: 'Do Quản trị viên tạo bổ sung');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final double dist = double.tryParse(distanceController.text.replaceAll(',', '.')) ?? 0.0;
            final int h = int.tryParse(hoursController.text) ?? 0;
            final int m = int.tryParse(minutesController.text) ?? 0;
            final int s = int.tryParse(secondsController.text) ?? 0;
            final int totalSeconds = (h * 3600) + (m * 60) + s;

            // Tính Pace ước tính
            String previewPace = '--:--';
            if (dist > 0 && totalSeconds > 0) {
              final double p = (totalSeconds / 60.0) / dist;
              final int pMin = p.floor();
              final int pSec = ((p - pMin) * 60).round();
              previewPace = '$pMin:${pSec.toString().padLeft(2, '0')}';
            }

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_task_rounded, color: AppTheme.primaryNeon, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tạo Dữ Liệu Chạy Mới',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Chọn Vận Động Viên
                    const Text(
                      'Chọn Vận Động Viên:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedUid,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          items: userList.map((u) {
                            final uid = u['id']?.toString() ?? '';
                            final name = u['name']?.toString() ?? 'Runner';
                            final avatar = u['avatar_url']?.toString() ?? '';
                            final isAdmin = (u['role']?.toString().toLowerCase() == 'admin');

                            return DropdownMenuItem<String>(
                              value: uid,
                              child: Row(
                                children: [
                                  UserAvatar(
                                    avatarUrl: avatar,
                                    name: name,
                                    radius: 14,
                                    isAdmin: isAdmin,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedUid = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Chọn Ngày & Giờ Chạy
                    const Text(
                      'Thời Gian Thực Hiện:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Chọn ngày
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: dialogCtx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.secondaryNeon),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(selectedDate),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Chọn giờ
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: dialogCtx,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDialogState(() => selectedTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.secondaryNeon),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      selectedTime.format(dialogCtx),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Quãng đường (KM)
                    const Text(
                      'Quãng Đường (KM):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 15),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        suffixText: 'KM',
                        prefixIcon: Icon(Icons.straighten_rounded, color: AppTheme.primaryNeon, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Thời gian chạy
                    const Text(
                      'Thời Gian Chạy (Giờ : Phút : Giây):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Giờ',
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: minutesController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Phút',
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: secondsController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Giây',
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Thẻ Pace ước tính
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pace dự kiến:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Text(
                            '$previewPace /km',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.secondaryNeon),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Ghi chú
                    const Text(
                      'Ghi Chú:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Lý do tạo bổ sung / Ghi chú...',
                        prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.secondaryNeon, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                    backgroundColor: AppTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (dist <= 0 || totalSeconds <= 0) {
                      TopSyncToast.show(
                        context,
                        message: 'Vui lòng nhập Quãng đường và Thời gian hợp lệ!',
                        isSuccess: false,
                      );
                      return;
                    }

                    final DateTime finalStartTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final runnerName = running.getUserRealName(selectedUid, 'Runner');

                    await running.adminCreateRunSession(
                      userId: selectedUid,
                      userName: runnerName,
                      startTime: finalStartTime,
                      distanceKm: dist,
                      durationSeconds: totalSeconds,
                      notes: notesController.text.trim().isEmpty ? 'Do Quản trị viên tạo' : notesController.text.trim(),
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      TopSyncToast.show(
                        context,
                        message: 'Đã tạo buổi chạy cho $runnerName & đồng bộ Cloud!',
                      );
                    }
                  },
                  child: const Text('TẠO BUỔI CHẠY', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
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
            borderRadius: BorderRadius.circular(20),
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
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.secondaryNeon, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chỉnh Sửa Buổi Chạy',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                const SizedBox(height: 16),

                // Chỉnh sửa Quãng đường (KM)
                const Text(
                  'Quãng đường chạy (KM):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    suffixText: 'KM',
                    prefixIcon: Icon(Icons.straighten_rounded, color: AppTheme.secondaryNeon, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                // Chỉnh sửa Thời gian
                const Text(
                  'Thời gian chạy (Giờ : Phút : Giây):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Giờ'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Phút'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Giây'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chỉnh sửa Ghi chú
                const Text(
                  'Ghi chú bổ sung:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Lý do chỉnh sửa / ghi chú của Admin...',
                    prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.secondaryNeon, size: 20),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    // Tính toán số liệu thống kê dựa trên CẢ MỐC THỜI GIAN VÀ USER ĐƯỢC CHỌN
    final totalKm = running.getFilteredTotalDistance(_selectedFilter, _selectedUserId);
    final totalSec = running.getFilteredTotalDurationSeconds(_selectedFilter, _selectedUserId);
    final filteredSessions = running.getFilteredSessions(filter: _selectedFilter, targetUserId: _selectedUserId);
    final totalRuns = filteredSessions.length;
    final totalUsers = running.getFilteredUniqueAthletesCount(_selectedFilter, _selectedUserId);
    final totalCalories = running.getFilteredTotalCalories(_selectedFilter, _selectedUserId);
    final chartData = running.getFilteredChartData(_selectedFilter, _selectedUserId);

    // Lấy danh sách tất cả các User Profiles để hiển thị thanh chọn
    final profiles = running.allUserProfiles;
    final List<Map<String, dynamic>> userList = profiles.values.toList();
    if (userList.isEmpty) {
      final userIds = running.allSessions.map((s) => s.userId).toSet();
      for (final uid in userIds) {
        userList.add({
          'id': uid,
          'name': running.getUserRealName(uid, 'Runner'),
          'avatar_url': running.getUserRealAvatar(uid),
          'role': running.isUserAdmin(uid) ? 'admin' : 'user',
        });
      }
    }

    // Lọc danh sách quản lý buổi chạy theo từ khóa tìm kiếm & User đã chọn
    final displaySessions = running.allSessions.where((s) {
      if (_selectedUserId != null && _selectedUserId!.isNotEmpty && s.userId != _selectedUserId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final realName = running.getUserRealName(s.userId, s.userName);
      return realName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.notes.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;

    // Tên của đối tượng đang lọc
    final selectedRunnerName = _selectedUserId == null
        ? 'Tất cả vận động viên'
        : running.getUserRealName(_selectedUserId!, 'Vận động viên');

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUẢN TRỊ & THỐNG KÊ'),
        actions: [
          // Nút Thêm Buổi Chạy Mới Thủ Công
          IconButton(
            tooltip: 'Tạo buổi chạy mới',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryNeon, size: 24),
            onPressed: () => _showCreateRunDialog(context, running),
          ),
          // Nút Làm Mới Dữ Liệu từ Supabase Cloud
          IconButton(
            tooltip: 'Làm mới dữ liệu Cloud',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 22),
            onPressed: () async {
              await running.refreshAllData();
              if (context.mounted) {
                TopSyncToast.show(context, message: 'Đã đồng bộ dữ liệu mới nhất từ Cloud!');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRunDialog(context, running),
        backgroundColor: AppTheme.primaryNeon,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'THÊM BUỔI CHẠY',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. THANH CHỌN ĐỐI TƯỢNG (TẤT CẢ HOẶC TỪNG RUNNER)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ĐỐI TƯỢNG THỐNG KÊ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text(
                      selectedRunnerName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryNeon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Danh sách cuộn ngang chọn User
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Chip Tất cả
                    _buildUserFilterChip(
                      label: 'TẤT CẢ VẬN ĐỘNG VIÊN',
                      userId: null,
                      isSelected: _selectedUserId == null,
                      icon: Icons.groups_rounded,
                    ),
                    const SizedBox(width: 8),
                    // Từng Runner
                    ...userList.map((u) {
                      final uid = u['id']?.toString() ?? '';
                      final name = u['name']?.toString() ?? 'Runner';
                      final avatar = u['avatar_url']?.toString() ?? '';
                      final isAdmin = (u['role']?.toString().toLowerCase() == 'admin');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildUserFilterChip(
                          label: name,
                          userId: uid,
                          avatarUrl: avatar,
                          isAdmin: isAdmin,
                          isSelected: _selectedUserId == uid,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. THANH CHỌN MỐC THỜI GIAN (HÔM NAY, TUẦN NÀY, THÁNG NÀY, NĂM NÀY)
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
              const SizedBox(height: 18),

              // 3. 4 THẺ CHỈ SỐ KPI TỔNG QUAN (ĐỒNG BỘ THEO BỘ LỌC)
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      'TỔNG QUÃNG ĐƯỜNG',
                      '${totalKm.toStringAsFixed(1)} km',
                      Icons.straighten_rounded,
                      AppTheme.primaryNeon,
                    ),
                  ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 10),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedUserId == null
                        ? _buildKpiCard(
                            'VẬN ĐỘNG VIÊN',
                            '$totalUsers người',
                            Icons.group_rounded,
                            const Color(0xFFA855F7),
                          )
                        : _buildKpiCard(
                            'CALORIES ĐỐT CHÁY',
                            '$totalCalories kcal',
                            Icons.local_fire_department_rounded,
                            AppTheme.danger,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. BIỂU ĐỒ TRỰC QUAN THỐNG KÊ QUÃNG ĐƯỜNG (fl_chart)
              Container(
                padding: const EdgeInsets.all(18),
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
                        Flexible(
                          child: Text(
                            'BIỂU ĐỒ KM - ${_getFilterTitle(_selectedFilter).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Kilometers',
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryNeon, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: chartData.isEmpty
                          ? const Center(
                              child: Text(
                                'Không có dữ liệu trong khoảng thời gian này',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            )
                          : BarChart(
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
                                        const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        children: [
                                          TextSpan(
                                            text: '${rod.toY.toStringAsFixed(2)} km',
                                            style: const TextStyle(
                                              color: AppTheme.primaryNeon,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
                                      reservedSize: 28,
                                      getTitlesWidget: (val, meta) {
                                        if (val % 2 == 0) {
                                          return Text(
                                            '${val.toInt()}k',
                                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
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
                                            padding: const EdgeInsets.only(top: 6.0),
                                            child: Text(
                                              chartData[idx].label,
                                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
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
                                        width: 12,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
              const SizedBox(height: 24),

              // 5. DANH SÁCH QUẢN LÝ & CHỈNH SỬA BUỔI CHẠY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUẢN LÝ DỮ LIỆU CHẠY',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${displaySessions.length} buổi chạy',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Ô tìm kiếm User
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên vận động viên hoặc ghi chú...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              // Danh sách từng buổi chạy với nút SỬA & XÓA
              if (displaySessions.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.directions_run_outlined, size: 40, color: AppTheme.textMuted),
                      SizedBox(height: 10),
                      Text(
                        'Chưa có dữ liệu buổi chạy nào phù hợp',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displaySessions.length,
                  itemBuilder: (context, index) {
                    final session = displaySessions[index];
                    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                    final realName = running.getUserRealName(session.userId, session.userName);
                    final realAvatar = running.getUserRealAvatar(session.userId);
                    final isAdmin = running.isUserAdmin(session.userId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  avatarUrl: realAvatar,
                                  name: realName,
                                  radius: 18,
                                  isAdmin: isAdmin,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        realName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        dateFormat.format(session.startTime),
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                // Nút SỬA
                                IconButton(
                                  tooltip: 'Chỉnh sửa KM & Thời gian',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.secondaryNeon, size: 16),
                                  onPressed: () => _showEditRunDialog(context, session),
                                ),
                                const SizedBox(width: 6),
                                // Nút XÓA
                                IconButton(
                                  tooltip: 'Xóa buổi chạy',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 16),
                                  onPressed: () => _confirmDelete(context, session),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
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
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '📝 ${session.notes}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 70), // Khoảng trống cho FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserFilterChip({
    required String label,
    required String? userId,
    String? avatarUrl,
    bool isAdmin = false,
    required bool isSelected,
    IconData? icon,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedUserId = userId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNeon : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNeon : AppTheme.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
            ] else ...[
              UserAvatar(
                avatarUrl: avatarUrl,
                name: label,
                radius: 9,
                isAdmin: isAdmin,
                showBorder: false,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(vertical: 9),
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
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
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
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
      ],
    );
  }

  String _getFilterTitle(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.day:
        return 'Hôm nay';
      case TimeFilter.week:
        return '7 Ngày qua';
      case TimeFilter.month:
        return 'Tháng này';
      case TimeFilter.year:
        return 'Năm nay';
    }
  }
}
