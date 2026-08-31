import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Bộ nhớ cache RAM lưu trữ ảnh avatar để không giải mã lại mỗi khi màn hình re-render
final Map<String, Uint8List> _avatarMemoryCache = {};

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isAdmin;
  final bool showBorder;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.isAdmin = false,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = isAdmin ? AppTheme.secondaryNeon : AppTheme.primaryNeon;
    final cleanName = name.trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'U';

    Widget avatarContent = RepaintBoundary(
      child: _buildImage(initial, effectiveBorderColor),
    );

    if (showBorder) {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: radius > 30 ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveBorderColor.withValues(alpha: 0.25),
              blurRadius: radius > 30 ? 16 : 8,
            ),
          ],
        ),
        child: ClipOval(child: avatarContent),
      );
    } else {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(child: avatarContent),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarContent);
    }
    return avatarContent;
  }

  Widget _buildImage(String initial, Color accentColor) {
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) {
      return _buildFallbackInitial(initial, accentColor);
    }

    // 1. Nếu là ảnh base64 (có tiền tố data:image hoặc chuỗi base64 thô)
    if (url.startsWith('data:image') || (url.length > 50 && !url.startsWith('http'))) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last.trim() : url;
        Uint8List? bytes = _avatarMemoryCache[base64Str];
        if (bytes == null) {
          bytes = base64Decode(base64Str);
          if (_avatarMemoryCache.length > 50) {
            _avatarMemoryCache.clear();
          }
          _avatarMemoryCache[base64Str] = bytes;
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          gaplessPlayback: true, // Chống nháy hình tuyệt đối khi widget rebuild
          errorBuilder: (_, _, _) => _buildFallbackInitial(initial, accentColor),
        );
      } catch (_) {
        return _buildFallbackInitial(initial, accentColor);
      }
    }

    // 2. Nếu là ảnh link Web HTTP/HTTPS
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        gaplessPlayback: true, // Chống nháy hình tuyệt đối khi widget rebuild
        errorBuilder: (_, _, _) => _buildFallbackInitial(initial, accentColor),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return _buildFallbackInitial(initial, accentColor);
        },
      );
    }

    // 3. Nếu chưa có ảnh -> Hiển thị chữ cái đầu tên thật với gradient sang trọng
    return _buildFallbackInitial(initial, accentColor);
  }

  Widget _buildFallbackInitial(String initial, Color accentColor) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceLight,
            accentColor.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
