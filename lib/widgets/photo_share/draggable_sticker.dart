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

/// Khối Sticker có thể Kéo Thả (Pan Drag) và Thu Phóng (Scale / Pinch) siêu mượt
class DraggableSticker extends StatefulWidget {
  final String id;
  final String label;
  final Widget child;
  final StickerTransform transform;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onPanUpdate;
  final ValueChanged<double>? onScaleUpdate;

  const DraggableSticker({
    super.key,
    required this.id,
    required this.label,
    required this.child,
    required this.transform,
    required this.isSelected,
    required this.onSelect,
    required this.onPanUpdate,
    this.onScaleUpdate,
  });

  @override
  State<DraggableSticker> createState() => _DraggableStickerState();
}

class _DraggableStickerState extends State<DraggableSticker> {
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: widget.transform.offset,
      child: Transform.scale(
        scale: widget.transform.scale,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelect,
          onScaleStart: (details) {
            // Chỉ kích hoạt chọn nếu chưa chọn, tránh rebuild giật trong lúc bắt đầu kéo
            if (!widget.isSelected) {
              widget.onSelect();
            }
            _baseScale = widget.transform.scale;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount > 1 && widget.onScaleUpdate != null) {
              // 2 ngón tay: Chụm/mở để phóng to hoặc thu nhỏ
              final newScale = (_baseScale * details.scale).clamp(0.4, 2.5);
              widget.onScaleUpdate!(newScale);
            } else {
              // 1 ngón tay hoặc chuột: Kéo di chuyển khối tự do
              widget.onPanUpdate(details.focalPointDelta);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: widget.isSelected
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
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
