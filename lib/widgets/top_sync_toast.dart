import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopSyncToast {
  static OverlayEntry? _currentEntry;

  /// Hiển thị popup thông báo đẩy gọn gàng ở góc trên màn hình
  static void show(
    BuildContext context, {
    required String message,
    bool isSuccess = true,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final Color themeColor = isSuccess ? AppTheme.primaryNeon : AppTheme.danger;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 8,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                alignment: Alignment.topRight,
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(ctx).size.width * 0.85,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: themeColor,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}

