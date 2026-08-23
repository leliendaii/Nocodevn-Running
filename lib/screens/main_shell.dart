import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'running_screen.dart';
import 'history_screen.dart';
import 'admin_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final List<Widget> screens = [
      const RunningScreen(),
      const HistoryScreen(),
      const AdminDashboardScreen(),
      _buildProfileTab(context, auth),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(
            top: BorderSide(color: AppTheme.divider, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.directions_run_rounded, 'Chạy bộ'),
                _buildNavItem(1, Icons.history_rounded, 'Lịch sử'),
                _buildNavItem(
                  2,
                  Icons.admin_panel_settings_rounded,
                  'Quản trị',
                  badge: user?.isAdmin == true ? 'ADMIN' : null,
                ),
                _buildNavItem(3, Icons.person_rounded, 'Cá nhân'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {String? badge}) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNeon.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryNeon : AppTheme.textMuted,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryNeon : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryNeon,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HỒ SƠ CÁ NHÂN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.surfaceLight,
                      child: Icon(
                        user?.isAdmin == true ? Icons.admin_panel_settings : Icons.directions_run,
                        size: 50,
                        color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                        ),
                        child: const Icon(Icons.check, size: 16, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Người dùng',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: user?.isAdmin == true
                      ? AppTheme.secondaryNeon.withValues(alpha: 0.15)
                      : AppTheme.primaryNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.isAdmin == true ? '🛡️ QUẢN TRỊ VIÊN' : '🏃 VẬN ĐỘNG VIÊN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Thao tác chuyển đổi vai trò nhanh để kiểm thử
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHUYỂN ĐỔI VAI TRÒ ĐỂ KIỂM THỬ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: user?.isAdmin != true ? AppTheme.primaryNeon.withValues(alpha: 0.1) : null,
                        leading: const Icon(Icons.directions_run, color: AppTheme.primaryNeon),
                        title: const Text('Vận động viên (Runner)', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Chuyên chạy bộ và theo dõi chỉ số cá nhân', style: TextStyle(fontSize: 11)),
                        trailing: user?.isAdmin != true ? const Icon(Icons.radio_button_checked, color: AppTheme.primaryNeon) : null,
                        onTap: () => auth.loginAsRunner(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: user?.isAdmin == true ? AppTheme.secondaryNeon.withValues(alpha: 0.1) : null,
                        leading: const Icon(Icons.admin_panel_settings, color: AppTheme.secondaryNeon),
                        title: const Text('Quản trị viên (Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Xem thống kê ngày/tuần/tháng/năm & sửa KM/thời gian', style: TextStyle(fontSize: 11)),
                        trailing: user?.isAdmin == true ? const Icon(Icons.radio_button_checked, color: AppTheme.secondaryNeon) : null,
                        onTap: () => auth.loginAsAdmin(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Nút Chỉnh sửa Họ tên & Email
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryNeon, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Đổi Tên người dùng & Email', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.primaryNeon,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showEditProfileDialog(context, auth),
                      child: const Text('SỬA TÊN/MAIL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Nút Đổi mật khẩu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.key_rounded, color: AppTheme.secondaryNeon, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bảo mật tài khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Thay đổi mật khẩu đăng nhập', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.secondaryNeon,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showChangePasswordDialog(context, auth),
                      child: const Text('ĐỔI MK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Nút Đăng xuất
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                  label: const Text('ĐĂNG XUẤT', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    final emailController = TextEditingController(text: auth.currentUser?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryNeon),
            SizedBox(width: 10),
            Text('Đổi Tên & Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Họ và tên mới',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email mới',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryNeon),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nameController.text.trim();
              final e = emailController.text.trim();

              final error = auth.updateProfile(newName: n, newEmail: e);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppTheme.danger, content: Text(error)),
                );
              } else {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('✅ Đã cập nhật Tên và Email thành công!'),
                  ),
                );
              }
            },
            child: const Text('LƯU THÔNG TIN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.secondaryNeon, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.secondaryNeon),
            SizedBox(width: 10),
            Text('Đổi Mật Khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                hintText: 'Nhập mật khẩu đang dùng',
                prefixIcon: Icon(Icons.key, color: AppTheme.secondaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: newPassController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (ít nhất 6 ký tự)',
                prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
                prefixIcon: Icon(Icons.lock_reset, color: AppTheme.primaryNeon),
              ),
            ),
          ],
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
              final cur = currentPassController.text.trim();
              final n1 = newPassController.text.trim();
              final n2 = confirmPassController.text.trim();

              if (n1 != n2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.danger,
                    content: Text('Mật khẩu mới xác nhận không khớp!'),
                  ),
                );
                return;
              }

              final error = auth.changePassword(
                currentPassword: cur,
                newPassword: n1,
              );

              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppTheme.danger, content: Text(error)),
                );
              } else {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('✅ Đã đổi mật khẩu thành công!'),
                  ),
                );
              }
            },
            child: const Text('LƯU MẬT KHẨU', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
