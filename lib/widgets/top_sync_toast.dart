import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopSyncToast {
  static OverlayEntry? _currentEntry;

  /// Hiển thị popup thông báo đồng bộ ở góc trên bên phải
  static void show(
    BuildContext context, {
    required String message,
    bool isSuccess = true,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                alignment: Alignment.topRight,
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSuccess ? AppTheme.primaryNeon : AppTheme.danger,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isSuccess ? AppTheme.primaryNeon : AppTheme.danger).withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSuccess ? AppTheme.primaryNeon : AppTheme.danger,
                            boxShadow: [
                              BoxShadow(
                                color: (isSuccess ? AppTheme.primaryNeon : AppTheme.danger).withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          icon ?? (isSuccess ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                          color: isSuccess ? AppTheme.primaryNeon : AppTheme.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
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
