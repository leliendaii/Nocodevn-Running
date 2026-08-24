import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/dialogs/avatar_picker_dialog.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    _emailController = TextEditingController(text: auth.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final n = _nameController.text.trim();
    final e = _emailController.text.trim();
    final auth = context.read<AuthProvider>();

    if (n.isEmpty) {
      TopSyncToast.show(context, message: 'Họ và tên không được để trống!', isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);
    final error = await auth.updateProfile(
      newName: n,
      newUsername: auth.currentUser?.username ?? '',
      newEmail: e.isNotEmpty ? e : (auth.currentUser?.email ?? ''),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
    } else {
      TopSyncToast.show(context, message: 'Đã lưu thông tin tài khoản thành công!', isSuccess: true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thông Tin Tài Khoản',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar trung tâm
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceLight,
                      border: Border.all(
                        color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon).withValues(alpha: 0.25),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                          ? Image.network(
                              user.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.person, size: 50, color: AppTheme.textMuted),
                            )
                          : const Icon(Icons.person, size: 50, color: AppTheme.textMuted),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => AvatarPickerDialog.show(context, auth),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
                          border: Border.all(color: AppTheme.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.isAdmin == true ? '🛡️ Quản Trị Viên' : '🏃 Vận Động Viên',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: user?.isAdmin == true ? AppTheme.secondaryNeon : AppTheme.primaryNeon,
              ),
            ),
            const SizedBox(height: 24),

            // Khối Form nhập liệu
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
                  const Text('HỌ VÀ TÊN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Nhập họ và tên...',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('TÊN ĐĂNG NHẬP (USERNAME)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '@${user?.username ?? ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        const Text('(Cố định)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('EMAIL LIÊN HỆ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Nhập địa chỉ email...',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryNeon),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút Lưu thay đổi
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
