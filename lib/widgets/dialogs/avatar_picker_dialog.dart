import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../top_sync_toast.dart';

class AvatarPickerDialog {
  static void show(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cập nhật Ảnh Đại Diện',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryNeon,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 70);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    auth.updateAvatar(base64String);
                    if (context.mounted) {
                      TopSyncToast.show(context, message: 'Đã cập nhật ảnh đại diện mới!', isSuccess: true);
                    }
                  }
                } catch (e) {
                  debugPrint('Lỗi chọn ảnh: $e');
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.secondaryNeon,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Chụp ảnh từ Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 400, imageQuality: 70);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    auth.updateAvatar(base64String);
                    if (context.mounted) {
                      TopSyncToast.show(context, message: 'Đã chụp ảnh đại diện mới!', isSuccess: true);
                    }
                  }
                } catch (e) {
                  debugPrint('Lỗi chụp ảnh: $e');
                }
              },
            ),
            const Divider(color: AppTheme.divider),
            const Text('Hoặc chọn Avatar thể thao mẫu:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=150',
                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
              ].map((url) {
                return GestureDetector(
                  onTap: () {
                    auth.updateAvatar(url);
                    Navigator.pop(ctx);
                    TopSyncToast.show(context, message: 'Đã cập nhật avatar mẫu!', isSuccess: true);
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(url),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
