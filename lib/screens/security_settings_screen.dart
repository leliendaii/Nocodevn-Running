import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final oldP = _oldPassController.text;
    final newP = _newPassController.text;
    final confirmP = _confirmPassController.text;

    if (newP.length < 6) {
      TopSyncToast.show(context, message: 'Mật khẩu mới phải có ít nhất 6 ký tự!', isSuccess: false);
      return;
    }

    if (newP != confirmP) {
      TopSyncToast.show(context, message: 'Mật khẩu xác nhận không trùng khớp!', isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);

    final error = await context.read<AuthProvider>().changePassword(
      currentPassword: oldP,
      newPassword: newP,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
    } else {
      TopSyncToast.show(context, message: 'Đã đổi mật khẩu thành công!', isSuccess: true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Bảo Mật & Mật Khẩu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Icon Bảo Mật
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, size: 48, color: AppTheme.secondaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Đổi Mật Khẩu Đăng Nhập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Để bảo vệ tài khoản tốt nhất, hãy đặt mật khẩu mạnh',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Form Đổi Mật Khẩu
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
                  const Text('MẬT KHẨU HIỆN TẠI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _oldPassController,
                    obscureText: _obscureOld,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu hiện tại...',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.secondaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('MẬT KHẨU MỚI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _newPassController,
                    obscureText: _obscureNew,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập ít nhất 6 ký tự...',
                      prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.secondaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('XÁC NHẬN MẬT KHẨU MỚI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPassController,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập lại mật khẩu mới...',
                      prefixIcon: const Icon(Icons.check_circle_outline, color: AppTheme.secondaryNeon),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút Lưu Mật Khẩu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryNeon,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSubmitting ? null : _handleChangePassword,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('CẬP NHẬT MẬT KHẨU MỚI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
