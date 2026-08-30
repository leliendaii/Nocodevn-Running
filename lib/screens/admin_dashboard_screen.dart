import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';
import 'admin_create_run_screen.dart';

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

  // Modal Bottom Sheet Tìm kiếm & Chọn Vận Động Viên (Hỗ trợ hàng trăm user mượt mà)
  void _showUserSelectorSheet(BuildContext context, List<Map<String, dynamic>> userList) {
    String sheetSearch = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredUsers = userList.where((u) {
              if (sheetSearch.isEmpty) return true;
              final name = (u['name']?.toString() ?? '').toLowerCase();
              final username = (u['username']?.toString() ?? '').toLowerCase();
              final q = sheetSearch.toLowerCase();
              return name.contains(q) || username.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.7,
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh kéo handle
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
                  const SizedBox(height: 12),

                  // Tiêu đề
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CHỌN ĐỐI TƯỢNG THỐNG KÊ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${userList.length} VĐV',
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ô tìm kiếm User
                  TextField(
                    autofocus: false,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    onChanged: (val) => setModalState(() => sheetSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên hoặc username để tìm...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      suffixIcon: sheetSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                              onPressed: () => setModalState(() => sheetSearch = ''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Danh sách lựa chọn
                  Expanded(
                    child: ListView(
                      children: [
                        // Tùy chọn: Tất cả vận động viên
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: _selectedUserId == null
                              ? AppTheme.primaryNeon.withValues(alpha: 0.15)
                              : Colors.transparent,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedUserId == null
                                  ? AppTheme.primaryNeon
                                  : AppTheme.surfaceLight,
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 20,
                              color: _selectedUserId == null ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                          title: Text(
                            'TẤT CẢ VẬN ĐỘNG VIÊN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedUserId == null ? AppTheme.primaryNeon : AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Xem thống kê tổng hợp toàn hệ thống',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          trailing: _selectedUserId == null
                              ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryNeon, size: 18)
                              : null,
                          onTap: () {
                            setState(() => _selectedUserId = null);
                            Navigator.of(sheetCtx).pop();
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.divider),

                        // Danh sách từng Runner
                        if (filteredUsers.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'Không tìm thấy vận động viên nào',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ),
                          ),
                        ] else ...[
                          ...filteredUsers.map((u) {
                            final uid = u['id']?.toString() ?? '';
                            final name = u['name']?.toString() ?? 'Runner';
                            final avatar = u['avatar_url']?.toString() ?? '';
                            final isAdmin = (u['role']?.toString().toLowerCase() == 'admin');
                            final isSelected = _selectedUserId == uid;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              tileColor: isSelected
                                  ? AppTheme.secondaryNeon.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              leading: UserAvatar(
                                avatarUrl: avatar,
                                name: name,
                                radius: 18,
                                isAdmin: isAdmin,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.secondaryNeon : AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                isAdmin ? '🛡️ Quản trị viên' : '🏃 Vận động viên',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryNeon, size: 18)
                                  : null,
                              onTap: () {
                                setState(() => _selectedUserId = uid);
                                Navigator.of(sheetCtx).pop();
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.secondaryNeon, width: 1.5),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.secondaryNeon, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chỉnh Sửa Buổi Chạy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  'Ngày chạy: ${DateFormat('dd/MM/yyyy HH:mm').format(session.startTime)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),

                // Chỉnh sửa Quãng đường (KM)
                const Text(
                  'Quãng đường chạy (KM):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 'KM',
                    prefixIcon: Icon(Icons.straighten_rounded, color: AppTheme.secondaryNeon, size: 18),
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  ),
                ),
                const SizedBox(height: 8),

                // Chỉnh sửa Thời gian
                const Text(
                  'Thời gian (Giờ : Phút : Giây):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Giờ',
                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(':', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Phút',
                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(':', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Giây',
                          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Chỉnh sửa Ghi chú
                const Text(
                  'Ghi chú bổ sung:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Lý do chỉnh sửa...',
                    prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.secondaryNeon, size: 18),
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryNeon,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              child: const Text('LƯU THAY ĐỔI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận xóa', style: TextStyle(color: AppTheme.danger, fontSize: 16)),
        content: Text(
          'Bạn có chắc chắn muốn xóa buổi chạy (${session.formattedDistance} km) của ${session.userName}?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

    // Tên và avatar của đối tượng đang lọc
    final selectedRunnerName = _selectedUserId == null
        ? 'Tất cả vận động viên'
        : running.getUserRealName(_selectedUserId!, 'Vận động viên');
    final selectedRunnerAvatar = _selectedUserId != null
        ? running.getUserRealAvatar(_selectedUserId!)
        : '';
    final isSelectedRunnerAdmin = _selectedUserId != null
        ? running.isUserAdmin(_selectedUserId!)
        : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QUẢN TRỊ & THỐNG KÊ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        actions: [
          // Nút Chuyển sang Trang Tạo Buổi Chạy Mới Riêng Biệt
          IconButton(
            tooltip: 'Tạo buổi chạy mới',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryNeon, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminCreateRunScreen(initialUserId: _selectedUserId),
                ),
              );
            },
          ),
          // Nút Làm Mới Dữ Liệu từ Supabase Cloud
          IconButton(
            tooltip: 'Làm mới dữ liệu Cloud',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 20),
            onPressed: () async {
              await running.refreshAllData();
              if (context.mounted) {
                TopSyncToast.show(context, message: 'Đã đồng bộ dữ liệu mới nhất từ Cloud!');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. THANH CHỌN ĐỐI TƯỢNG GỌN GÀNG & CÓ TÌM KIẾM
              InkWell(
                onTap: () => _showUserSelectorSheet(context, userList),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedUserId != null ? AppTheme.secondaryNeon : AppTheme.divider,
                      width: _selectedUserId != null ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedUserId == null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                          ),
                          child: const Icon(Icons.groups_rounded, size: 18, color: AppTheme.primaryNeon),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ĐỐI TƯỢNG THỐNG KÊ',
                                style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Tất cả vận động viên',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        UserAvatar(
                          avatarUrl: selectedRunnerAvatar,
                          name: selectedRunnerName,
                          radius: 16,
                          isAdmin: isSelectedRunnerAdmin,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VẬN ĐỘNG VIÊN ĐANG CHỌN',
                                style: TextStyle(fontSize: 10, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                selectedRunnerName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                          tooltip: 'Xem tất cả',
                          onPressed: () => setState(() => _selectedUserId = null),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Đổi VĐV',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. THANH CHỌN MỐC THỜI GIAN (HÔM NAY, TUẦN NÀY, THÁNG NÀY, NĂM NAY)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 14),

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
              const SizedBox(height: 8),
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
              const SizedBox(height: 18),

              // 4. BIỂU ĐỒ TRỰC QUAN THỐNG KÊ QUÃNG ĐƯỜNG (fl_chart)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
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
              const SizedBox(height: 20),

              // 5. DANH SÁCH QUẢN LÝ & CHỈNH SỬA BUỔI CHẠY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QUẢN LÝ DỮ LIỆU CHẠY',
                    style: TextStyle(
                      fontSize: 14,
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
              const SizedBox(height: 8),

              // Ô tìm kiếm User
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên vận động viên hoặc ghi chú...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),

              // Danh sách từng buổi chạy với nút SỬA & XÓA
              if (displaySessions.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.directions_run_outlined, size: 36, color: AppTheme.textMuted),
                      SizedBox(height: 8),
                      Text(
                        'Chưa có dữ liệu buổi chạy nào phù hợp',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  avatarUrl: realAvatar,
                                  name: realName,
                                  radius: 16,
                                  isAdmin: isAdmin,
                                ),
                                const SizedBox(width: 8),
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
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                // Nút SỬA
                                IconButton(
                                  tooltip: 'Chỉnh sửa KM & Thời gian',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                                    padding: const EdgeInsets.all(6),
                                  ),
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.secondaryNeon, size: 15),
                                  onPressed: () => _showEditRunDialog(context, session),
                                ),
                                const SizedBox(width: 4),
                                // Nút XÓA
                                IconButton(
                                  tooltip: 'Xóa buổi chạy',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                                    padding: const EdgeInsets.all(6),
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 15),
                                  onPressed: () => _confirmDelete(context, session),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
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
                              const SizedBox(height: 4),
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
              const SizedBox(height: 16),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryNeon : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
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
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              Icon(icon, color: color, size: 15),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
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
