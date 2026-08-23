import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../top_sync_toast.dart';

class EditProfileDialog extends StatefulWidget {
  final AuthProvider auth;

  const EditProfileDialog({super.key, required this.auth});

  static void show(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => EditProfileDialog(auth: auth),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.auth.currentUser?.name ?? '');
    _emailController = TextEditingController(text: widget.auth.currentUser?.email ?? '');
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

    if (n.isEmpty) {
      TopSyncToast.show(context, message: 'Họ và tên không được để trống!', isSuccess: false);
      return;
    }

    final error = await widget.auth.updateProfile(
      newName: n,
      newUsername: widget.auth.currentUser?.username ?? '',
      newEmail: e.isNotEmpty ? e : (widget.auth.currentUser?.email ?? ''),
    );
    if (!mounted) return;

    if (error != null) {
      TopSyncToast.show(context, message: error, isSuccess: false);
    } else {
      Navigator.of(context).pop();
      TopSyncToast.show(context, message: 'Đã cập nhật thông tin thành công!', isSuccess: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = widget.auth.currentUser?.username ?? '';

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.primaryNeon, width: 1.5),
      ),
      title: const Row(
        children: [
          Icon(Icons.edit_note_rounded, color: AppTheme.primaryNeon),
          SizedBox(width: 10),
          Text('Đổi Thông Tin Cá Nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ô Họ và tên (Cho phép sửa)
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
              ),
            ),
            const SizedBox(height: 14),

            // Ô Username (CỐ ĐỊNH - KHÓA KHÔNG CHO PHÉP SỬA)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tên đăng nhập (Cố định, không thể đổi)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$currentUsername',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ô Email (Cho phép sửa)
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryNeon),
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
          onPressed: _handleSave,
          child: const Text('LƯU THÔNG TIN', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
