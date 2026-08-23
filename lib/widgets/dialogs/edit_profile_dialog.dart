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
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.auth.currentUser?.name ?? '');
    _usernameController = TextEditingController(text: widget.auth.currentUser?.username ?? '');
    _emailController = TextEditingController(text: widget.auth.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final n = _nameController.text.trim();
    final u = _usernameController.text.trim();
    final e = _emailController.text.trim();

    final error = await widget.auth.updateProfile(newName: n, newUsername: u, newEmail: e);
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
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryNeon),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập (Username)',
                prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.secondaryNeon),
              ),
            ),
            const SizedBox(height: 14),
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
