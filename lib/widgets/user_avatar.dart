import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

    Widget avatarContent = _buildImage(initial, effectiveBorderColor);

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

    // 1. Nếu là ảnh base64
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
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
        errorBuilder: (_, _, _) => _buildFallbackInitial(initial, accentColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppTheme.surfaceLight,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryNeon),
              ),
            ),
          );
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
            color: accentColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
