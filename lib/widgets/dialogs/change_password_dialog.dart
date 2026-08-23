import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../top_sync_toast.dart';

class ChangePasswordDialog extends StatefulWidget {
  final AuthProvider auth;

  const ChangePasswordDialog({super.key, required this.auth});

  static void show(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => ChangePasswordDialog(auth: auth),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final cur = _currentPassController.text.trim();
    final n1 = _newPassController.text.trim();
    final n2 = _confirmPassController.text.trim();

    if (n1 != n2) {
      TopSyncToast.show(
        context,
        message: 'Mật khẩu mới xác nhận không khớp!',
        isSuccess: false,
      );
      return;
    }

    final error = await widget.auth.changePassword(
      currentPassword: cur,
      newPassword: n1,
    );

    if (!mounted) return;

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
    } else {
      Navigator.of(context).pop();
      TopSyncToast.show(context, message: 'Đã đổi mật khẩu thành công!', isSuccess: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPassController,
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
              controller: _newPassController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (ít nhất 6 ký tự)',
                prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPassController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
                prefixIcon: Icon(Icons.lock_reset, color: AppTheme.primaryNeon),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('HỦY', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryNeon,
            foregroundColor: Colors.black,
          ),
          onPressed: _handleSave,
          child: const Text('LƯU MẬT KHẨU', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
