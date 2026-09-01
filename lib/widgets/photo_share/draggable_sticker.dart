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

/// Khối Sticker có thể Kéo Thả (Drag & Drop) và Thu Phóng (Pinch-to-zoom / Scale) độc lập
class DraggableSticker extends StatefulWidget {
  final String id;
  final String label;
  final Widget child;
  final StickerTransform transform;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDeselect;
  final VoidCallback onReset;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<double> onScaleChanged;

  const DraggableSticker({
    super.key,
    required this.id,
    required this.label,
    required this.child,
    required this.transform,
    required this.isSelected,
    required this.onSelect,
    required this.onDeselect,
    required this.onReset,
    required this.onPositionChanged,
    required this.onScaleChanged,
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
            widget.onSelect();
            _baseScale = widget.transform.scale;
          },
          onScaleUpdate: (details) {
            // 1. Di chuyển vị trí khối
            widget.onPositionChanged(details.focalPointDelta);

            // 2. Thu phóng bằng 2 ngón tay (Pinch to zoom)
            if (details.pointerCount > 1) {
              final newScale = (_baseScale * details.scale).clamp(0.4, 3.0);
              widget.onScaleChanged(newScale);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nội dung chính của khối
              Container(
                decoration: widget.isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.secondaryNeon,
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryNeon.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      )
                    : null,
                child: widget.child,
              ),

              // Thanh công cụ điều khiển nhanh (Hiển thị khi người dùng chạm chọn khối này)
              if (widget.isSelected)
                Positioned(
                  top: -38,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.secondaryNeon.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nút Giảm kích thước (-)
                          _buildScaleButton(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              final newScale = (widget.transform.scale - 0.1).clamp(0.4, 3.0);
                              widget.onScaleChanged(newScale);
                            },
                          ),
                          const SizedBox(width: 6),

                          // Tỷ lệ %
                          Text(
                            '${(widget.transform.scale * 100).round()}%',
                            style: const TextStyle(
                              color: AppTheme.secondaryNeon,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Nút Tăng kích thước (+)
                          _buildScaleButton(
                            icon: Icons.add_rounded,
                            onTap: () {
                              final newScale = (widget.transform.scale + 0.1).clamp(0.4, 3.0);
                              widget.onScaleChanged(newScale);
                            },
                          ),
                          const SizedBox(width: 8),

                          // Vạch phân cách
                          Container(
                            width: 1,
                            height: 12,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 6),

                          // Nút Đặt lại vị trí & kích thước khối này
                          GestureDetector(
                            onTap: widget.onReset,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.restart_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Nút Xong (Bỏ chọn)
                          GestureDetector(
                            onTap: widget.onDeselect,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF00E676),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}
