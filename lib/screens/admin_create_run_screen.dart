import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/user_avatar.dart';

class AdminCreateRunScreen extends StatefulWidget {
  final String? initialUserId;

  const AdminCreateRunScreen({super.key, this.initialUserId});

  @override
  State<AdminCreateRunScreen> createState() => _AdminCreateRunScreenState();
}

class _AdminCreateRunScreenState extends State<AdminCreateRunScreen> {
  late String _selectedUid;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final _distanceController = TextEditingController(text: '5.0');
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '30');
  final _secondsController = TextEditingController(text: '00');
  final _notesController = TextEditingController(text: 'Do Quản trị viên tạo bổ sung');

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedUid = widget.initialUserId ?? '';
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Mở BottomSheet tìm kiếm và chọn Vận Động Viên
  void _openAthletePicker(List<Map<String, dynamic>> userList) {
    String searchKeyword = '';

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
              if (searchKeyword.isEmpty) return true;
              final name = (u['name']?.toString() ?? '').toLowerCase();
              final username = (u['username']?.toString() ?? '').toLowerCase();
              final q = searchKeyword.toLowerCase();
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CHỌN VẬN ĐỘNG VIÊN',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      Text(
                        '${userList.length} VĐV',
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryNeon, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    onChanged: (val) => setModalState(() => searchKeyword = val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên để tìm nhanh...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      suffixIcon: searchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                              onPressed: () => setModalState(() => searchKeyword = ''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'Không tìm thấy vận động viên nào',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredUsers.length,
                            separatorBuilder: (context, index) => const Divider(color: AppTheme.divider, height: 1),
                            itemBuilder: (ctx, idx) {
                              final u = filteredUsers[idx];
                              final uid = u['id']?.toString() ?? '';
                              final name = u['name']?.toString() ?? 'Runner';
                              final avatar = u['avatar_url']?.toString() ?? '';
                              final isAdmin = (u['role']?.toString().toLowerCase() == 'admin');
                              final isSelected = _selectedUid == uid;

                              return ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                tileColor: isSelected ? AppTheme.primaryNeon.withValues(alpha: 0.15) : Colors.transparent,
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
                                    color: isSelected ? AppTheme.primaryNeon : AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  isAdmin ? '🛡️ Quản trị viên' : '🏃 Vận động viên',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryNeon, size: 20)
                                    : null,
                                onTap: () {
                                  setState(() => _selectedUid = uid);
                                  Navigator.of(sheetCtx).pop();
                                },
                              );
                            },
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

  Future<void> _handleSaveRun(RunningProvider running) async {
    final double dist = double.tryParse(_distanceController.text.replaceAll(',', '.')) ?? 0.0;
    final int h = int.tryParse(_hoursController.text) ?? 0;
    final int m = int.tryParse(_minutesController.text) ?? 0;
    final int s = int.tryParse(_secondsController.text) ?? 0;
    final int totalSeconds = (h * 3600) + (m * 60) + s;

    if (_selectedUid.isEmpty) {
      TopSyncToast.show(context, message: 'Vui lòng chọn Vận động viên!', isSuccess: false);
      return;
    }

    if (dist <= 0) {
      TopSyncToast.show(context, message: 'Quãng đường chạy phải lớn hơn 0 KM!', isSuccess: false);
      return;
    }

    if (totalSeconds <= 0) {
      TopSyncToast.show(context, message: 'Thời gian chạy phải lớn hơn 0 giây!', isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);

    final DateTime finalStartTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final runnerName = running.getUserRealName(_selectedUid, 'Runner');

    await running.adminCreateRunSession(
      userId: _selectedUid,
      userName: runnerName,
      startTime: finalStartTime,
      distanceKm: dist,
      durationSeconds: totalSeconds,
      notes: _notesController.text.trim().isEmpty ? 'Do Quản trị viên tạo' : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      TopSyncToast.show(context, message: 'Đã tạo buổi chạy cho $runnerName & đồng bộ Cloud!');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    if (currentUser == null || !currentUser.isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('KHÔNG CÓ QUYỀN TRUY CẬP'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 64, color: AppTheme.danger),
                const SizedBox(height: 16),
                const Text(
                  'Quyền truy cập bị từ chối',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Trang này chỉ dành riêng cho Quản Trị Viên (Admin). Tài khoản của bạn không đủ phân quyền.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('QUAY LẠI'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final running = context.watch<RunningProvider>();
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

    // Gán mặc định nếu chưa chọn
    if (_selectedUid.isEmpty && userList.isNotEmpty) {
      _selectedUid = userList.first['id']?.toString() ?? '';
    }

    final selectedRunnerName = running.getUserRealName(_selectedUid, 'Chưa chọn VĐV');
    final selectedRunnerAvatar = running.getUserRealAvatar(_selectedUid);
    final isSelectedRunnerAdmin = running.isUserAdmin(_selectedUid);

    // Tính toán Pace & Calo ước tính
    final double dist = double.tryParse(_distanceController.text.replaceAll(',', '.')) ?? 0.0;
    final int h = int.tryParse(_hoursController.text) ?? 0;
    final int m = int.tryParse(_minutesController.text) ?? 0;
    final int s = int.tryParse(_secondsController.text) ?? 0;
    final int totalSeconds = (h * 3600) + (m * 60) + s;

    String previewPace = '--:--';
    int previewCalories = 0;
    if (dist > 0 && totalSeconds > 0) {
      final double p = (totalSeconds / 60.0) / dist;
      final int pMin = p.floor();
      final int pSec = ((p - pMin) * 60).round();
      previewPace = '$pMin:${pSec.toString().padLeft(2, '0')}';

      // Tính Calo theo công thức MET
      final double speedKmh = (dist / totalSeconds) * 3600;
      double met = 6.0;
      if (speedKmh > 12) {
        met = 12.5;
      } else if (speedKmh > 10) {
        met = 10.0;
      } else if (speedKmh > 8) {
        met = 8.3;
      }
      previewCalories = ((met * 3.5 * 65.0 / 200.0) * (totalSeconds / 60.0)).round();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TẠO DỮ LIỆU CHẠY'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. THẺ CHỌN VẬN ĐỘNG VIÊN
              _buildSectionTitle('1. VẬN ĐỘNG VIÊN ĐƯỢC GHI NHẬN'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openAthletePicker(userList),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: selectedRunnerAvatar,
                        name: selectedRunnerName,
                        radius: 22,
                        isAdmin: isSelectedRunnerAdmin,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedRunnerName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSelectedRunnerAdmin ? '🛡️ Quản trị viên' : '🏃 Vận động viên',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Đổi VĐV',
                              style: TextStyle(color: AppTheme.primaryNeon, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryNeon, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. THẺ THỜI GIAN THỰC HIỆN
              _buildSectionTitle('2. NGÀY & GIỜ XUẤT PHÁT'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    // Nút chọn Ngày
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NGÀY CHẠY', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.secondaryNeon),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Nút chọn Giờ
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GIỜ XUẤT PHÁT', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.secondaryNeon),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTime.format(context),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. THẺ THÔNG SỐ CHẠY (KM & THỜI GIAN)
              _buildSectionTitle('3. THÔNG SỐ BUỔI CHẠY'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quãng đường
                    const Text(
                      'Quãng Đường Hoàn Thành (KM):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 18),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        suffixText: 'KM',
                        prefixIcon: Icon(Icons.straighten_rounded, color: AppTheme.primaryNeon, size: 22),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Thời gian chạy
                    const Text(
                      'Thời Gian Chạy (Giờ : Phút : Giây):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hoursController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: const InputDecoration(labelText: 'Giờ'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: const InputDecoration(labelText: 'Phút'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _secondsController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: const InputDecoration(labelText: 'Giây'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Preview Pace & Calo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.speed_rounded, size: 18, color: AppTheme.secondaryNeon),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pace dự kiến', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Text(
                                    '$previewPace /km',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.secondaryNeon),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 1, height: 28, color: AppTheme.divider),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 18, color: AppTheme.accentOrange),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Calo ước tính', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Text(
                                    '$previewCalories kcal',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.accentOrange),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. THẺ TÊN BUỔI CHẠY
              _buildSectionTitle('4. TÊN BUỔI CHẠY'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Nhập tên buổi chạy (VD: Giải chạy Offline, Chạy bộ công viên...)',
                    prefixIcon: Icon(Icons.edit_note_rounded, color: AppTheme.secondaryNeon, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. NÚT LƯU BUỔI CHẠY (FULL-WIDTH NATIVE BUTTON)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : () => _handleSaveRun(running),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'LƯU BUỔI CHẠY & ĐỒNG BỘ CLOUD',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
