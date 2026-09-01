import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Dữ liệu toạ độ và tỷ lệ thu phóng của từng khối thông số
class StickerTransform {
  Offset offset;
  double scale;

  StickerTransform({
    this.offset = Offset.zero,
    this.scale = 1.0,
  });

  void reset() {
    offset = Offset.zero;
    scale = 1.0;
  }
}

/// Khối Sticker có thể Kéo Thả (Pan Drag) và Thu Phóng (Scale) siêu mượt
class DraggableSticker extends StatelessWidget {
  final String id;
  final String label;
  final Widget child;
  final StickerTransform transform;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onPanUpdate;

  const DraggableSticker({
    super.key,
    required this.id,
    required this.label,
    required this.child,
    required this.transform,
    required this.isSelected,
    required this.onSelect,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: transform.offset,
      child: Transform.scale(
        scale: transform.scale,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSelect,
          onPanStart: (_) => onSelect(),
          onPanUpdate: (details) => onPanUpdate(details.delta),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: isSelected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.secondaryNeon,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryNeon.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }
}
