import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/dialogs/avatar_picker_dialog.dart';
import '../widgets/user_avatar.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
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
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final n = _nameController.text.trim();
    final e = _emailController.text.trim();
    final oldP = _oldPassController.text;
    final newP = _newPassController.text;
    final confirmP = _confirmPassController.text;
    final auth = context.read<AuthProvider>();

    if (n.isEmpty) {
      TopSyncToast.show(context, message: 'Họ và tên không được để trống!', isSuccess: false);
      return;
    }

    // Nếu người dùng nhập mật khẩu mới, kiểm tra tính hợp lệ
    final hasPasswordInput = oldP.isNotEmpty || newP.isNotEmpty || confirmP.isNotEmpty;
    if (hasPasswordInput) {
      if (oldP.isEmpty) {
        TopSyncToast.show(context, message: 'Vui lòng nhập mật khẩu hiện tại!', isSuccess: false);
        return;
      }
      if (newP.length < 6) {
        TopSyncToast.show(context, message: 'Mật khẩu mới phải có ít nhất 6 ký tự!', isSuccess: false);
        return;
      }
      if (newP != confirmP) {
        TopSyncToast.show(context, message: 'Mật khẩu xác nhận không trùng khớp!', isSuccess: false);
        return;
      }
    }

    setState(() => _isSaving = true);

    // 1. Cập nhật Profile (Họ tên, email)
    final profileError = await auth.updateProfile(
      newName: n,
      newUsername: auth.currentUser?.username ?? '',
      newEmail: e.isNotEmpty ? e : (auth.currentUser?.email ?? ''),
    );

    if (profileError != null) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      TopSyncToast.show(context, message: profileError, isSuccess: false);
      return;
    }

    // 2. Cập nhật Mật khẩu (nếu có yêu cầu đổi)
    if (hasPasswordInput) {
      final passError = await auth.changePassword(
        currentPassword: oldP,
        newPassword: newP,
      );
      if (passError != null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        TopSyncToast.show(context, message: passError, isSuccess: false);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    TopSyncToast.show(context, message: 'Đã lưu thông tin tài khoản & bảo mật thành công!', isSuccess: true);
    Navigator.of(context).pop();
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
          'Tài Khoản & Bảo Mật',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. Avatar trung tâm
            Center(
              child: Stack(
                children: [
                  UserAvatar(
                    avatarUrl: user?.avatarUrl,
                    name: user?.name ?? 'Người dùng',
                    radius: 46,
                    isAdmin: user?.isAdmin == true,
                    onTap: () => AvatarPickerDialog.show(context, auth),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => AvatarPickerDialog.show(context, auth),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryNeon,
                          border: Border.all(color: AppTheme.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user?.isAdmin == true ? '🛡️ Quản Trị Viên' : '🏃 Vận Động Viên',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNeon,
              ),
            ),
            const SizedBox(height: 20),

            // 2. KHỐI 1: THÔNG TIN HỒ SƠ
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.primaryNeon),
                      SizedBox(width: 8),
                      Text(
                        'THÔNG TIN HỒ SƠ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.divider, height: 24),

                  const Text('HỌ VÀ TÊN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Nhập họ và tên...',
                      prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryNeon),
                    ),
                  ),
                  const SizedBox(height: 14),

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
                        const Icon(Icons.alternate_email_rounded, color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          '@${user?.username ?? ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const Spacer(),
                        const Text('(Cố định)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
            const SizedBox(height: 18),

            // 3. KHỐI 2: ĐỔI MẬT KHẨU (BẢO MẬT)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.primaryNeon),
                      SizedBox(width: 8),
                      Text(
                        'ĐỔI MẬT KHẨU ĐĂNG NHẬP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.divider, height: 24),

                  const Text('MẬT KHẨU HIỆN TẠI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _oldPassController,
                    obscureText: _obscureOld,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Để trống nếu không đổi...',
                      prefixIcon: const Icon(Icons.lock_open_rounded, color: AppTheme.primaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted, size: 20),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('MẬT KHẨU MỚI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _newPassController,
                    obscureText: _obscureNew,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tối thiểu 6 ký tự...',
                      prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.primaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted, size: 20),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('XÁC NHẬN MẬT KHẨU MỚI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPassController,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập lại mật khẩu mới...',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textMuted, size: 20),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
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
                  elevation: 6,
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
