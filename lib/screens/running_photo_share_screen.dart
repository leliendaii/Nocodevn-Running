import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/top_sync_toast.dart';
import '../widgets/photo_share/draggable_sticker.dart';
import '../widgets/photo_share/minimal_template_widget.dart';
import '../widgets/photo_share/map_template_widget.dart';
import '../widgets/photo_share/badge_template_widget.dart';

/// Màn hình Tạo ảnh Check-in Sống ảo Thể thao (Running Photo Overlay & Share)
class RunningPhotoShareScreen extends StatefulWidget {
  final RunSession session;

  const RunningPhotoShareScreen({super.key, required this.session});

  @override
  State<RunningPhotoShareScreen> createState() => _RunningPhotoShareScreenState();
}

class _RunningPhotoShareScreenState extends State<RunningPhotoShareScreen> {
  final GlobalKey _previewKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  int _selectedTemplate = 0; // 0: Tối giản, 1: Bản đồ, 2: Huy hiệu
  bool _isExporting = false;

  // Quản lý khối đang được chọn & Toạ độ / Tỷ lệ thu phóng riêng biệt của từng khối
  String? _selectedStickerId;
  final StickerTransform _headerTransform = StickerTransform();
  final StickerTransform _distanceTransform = StickerTransform();
  final StickerTransform _statsTransform = StickerTransform();
  final StickerTransform _mapRouteTransform = StickerTransform();
  final StickerTransform _mapStatsTransform = StickerTransform();
  final StickerTransform _badgeTransform = StickerTransform();

  bool get _hasAnyStickerModified =>
      _headerTransform.offset != Offset.zero || _headerTransform.scale != 1.0 ||
      _distanceTransform.offset != Offset.zero || _distanceTransform.scale != 1.0 ||
      _statsTransform.offset != Offset.zero || _statsTransform.scale != 1.0 ||
      _mapRouteTransform.offset != Offset.zero || _mapRouteTransform.scale != 1.0 ||
      _mapStatsTransform.offset != Offset.zero || _mapStatsTransform.scale != 1.0 ||
      _badgeTransform.offset != Offset.zero || _badgeTransform.scale != 1.0;

  void _resetAllStickers() {
    setState(() {
      _headerTransform.reset();
      _distanceTransform.reset();
      _statsTransform.reset();
      _mapRouteTransform.reset();
      _mapStatsTransform.reset();
      _badgeTransform.reset();
      _selectedStickerId = null;
    });
  }

  StickerTransform? _getSelectedTransform() {
    switch (_selectedStickerId) {
      case 'header':
        return _headerTransform;
      case 'distance':
        return _distanceTransform;
      case 'stats':
        return _statsTransform;
      case 'map_route':
        return _mapRouteTransform;
      case 'map_stats':
        return _mapStatsTransform;
      case 'badge':
        return _badgeTransform;
      default:
        return null;
    }
  }

  String _getSelectedStickerLabel() {
    switch (_selectedStickerId) {
      case 'header':
        return 'Logo & Thời gian';
      case 'distance':
        return 'Cự ly (KM)';
      case 'stats':
        return 'Hàng thông số';
      case 'map_route':
        return 'Đường vẽ GPS';
      case 'map_stats':
        return 'Thẻ thông số';
      case 'badge':
        return 'Huy hiệu thể thao';
      default:
        return '';
    }
  }

  // Cấu hình bật/tắt các thông số ghép vào ảnh
  bool _showLogo = true;
  bool _showTime = false; // Bật sẽ hiển thị giờ chạy (HH:mm) trước ngày
  bool _showDate = true;
  bool _showDistance = true;
  bool _showDuration = true;
  bool _showPace = true;
  bool _showCalories = true;
  bool _showSteps = true;

  /// Định dạng chuỗi Thời gian (Giờ - Ngày) theo tuỳ chọn bật/tắt của người dùng
  String _formatDateTime(DateTime dt) {
    final timeStr = DateFormat('HH:mm').format(dt);
    final dateStr = DateFormat('dd/MM/yyyy').format(dt);

    if (_showTime && _showDate) {
      return '$timeStr - $dateStr';
    } else if (_showTime) {
      return timeStr;
    } else if (_showDate) {
      return dateStr;
    }
    return '';
  }

  /// Chọn ảnh từ máy ảnh hoặc thư viện
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        TopSyncToast.show(
          context,
          message: 'Không thể mở ảnh: $e',
          isSuccess: false,
        );
      }
    }
  }

  /// Hiển thị Modal chọn nguồn ảnh
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
            const SizedBox(height: 18),
            const Text(
              'CHỌN ẢNH CHECK-IN BUỔI CHẠY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryNeon),
              ),
              title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Chụp selfie hoặc đường chạy của bạn', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.secondaryNeon),
              ),
              title: const Text('Chọn từ thư viện', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Lấy ảnh đẹp đã chụp trong điện thoại', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị Modal tuỳ chỉnh bật/tắt các thông số ghép vào ảnh
  void _showOverlaySettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TUỲ CHỈNH THÔNG SỐ ẢNH',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showLogo = true;
                                _showTime = false;
                                _showDate = true;
                                _showDistance = true;
                                _showDuration = true;
                                _showPace = true;
                                _showCalories = true;
                                _showSteps = true;
                              });
                              _resetAllStickers();
                              setModalState(() {});
                            },
                            child: const Text(
                              'Mặc định',
                              style: TextStyle(
                                color: AppTheme.secondaryNeon,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSettingSwitch(
                        title: 'Logo ứng dụng',
                        icon: Icons.directions_run_rounded,
                        value: _showLogo,
                        onChanged: (val) {
                          setState(() => _showLogo = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Giờ chạy (Time)',
                        icon: Icons.access_time_rounded,
                        value: _showTime,
                        onChanged: (val) {
                          setState(() => _showTime = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Ngày chạy (Date)',
                        icon: Icons.calendar_today_rounded,
                        value: _showDate,
                        onChanged: (val) {
                          setState(() => _showDate = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Cự ly (KM)',
                        icon: Icons.straighten_rounded,
                        value: _showDistance,
                        onChanged: (val) {
                          setState(() => _showDistance = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Thời gian chạy',
                        icon: Icons.timer_rounded,
                        value: _showDuration,
                        onChanged: (val) {
                          setState(() => _showDuration = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Nhịp Pace (/km)',
                        icon: Icons.speed_rounded,
                        value: _showPace,
                        onChanged: (val) {
                          setState(() => _showPace = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Lượng Calo (kcal)',
                        icon: Icons.local_fire_department_rounded,
                        value: _showCalories,
                        onChanged: (val) {
                          setState(() => _showCalories = val);
                          setModalState(() {});
                        },
                      ),
                      _buildSettingSwitch(
                        title: 'Số bước chân',
                        icon: Icons.directions_walk_rounded,
                        value: _showSteps,
                        onChanged: (val) {
                          setState(() => _showSteps = val);
                          setModalState(() {});
                        },
                      ),
                      const Divider(color: AppTheme.divider, height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vị trí & Kích thước khối',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Chạm khối để kéo thả hoặc chỉnh to nhỏ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              _resetAllStickers();
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.secondaryNeon),
                            label: const Text(
                              'Đặt lại tất cả',
                              style: TextStyle(
                                color: AppTheme.secondaryNeon,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? AppTheme.primaryNeon : AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: value ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppTheme.primaryNeon,
            activeTrackColor: AppTheme.primaryNeon.withValues(alpha: 0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
  Future<File?> _renderImageFile() async {
    try {
      // Tắt chọn khối để ẩn viền xanh và thanh công cụ khi xuất ảnh
      if (_selectedStickerId != null) {
        setState(() => _selectedStickerId = null);
        await Future.delayed(const Duration(milliseconds: 60));
      }

      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nocodevn_running_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint('Lỗi render ảnh: $e');
      return null;
    }
  }

  /// Lưu ảnh vào thư viện thiết bị
  Future<void> _saveToGallery() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final file = await _renderImageFile();
      if (file == null) throw Exception('Không thể tạo ảnh');

      await Gal.putImage(file.path);

      if (mounted) {
        TopSyncToast.show(
          context,
          message: 'Đã lưu ảnh thành công vào thư viện máy! 🎉',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        TopSyncToast.show(
          context,
          message: 'Lưu ảnh thất bại: $e',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Chia sẻ ảnh lên mạng xã hội
  Future<void> _shareImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final file = await _renderImageFile();
      if (file == null) throw Exception('Không thể tạo ảnh');

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Buổi chạy ${widget.session.distanceKm.toStringAsFixed(2)}km cùng Nocodevn Running! 🏃‍♂️🔥',
      );
    } catch (e) {
      if (mounted) {
        TopSyncToast.show(
          context,
          message: 'Chia sẻ thất bại: $e',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tạo ảnh'),
        actions: [
          if (_hasAnyStickerModified)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.6)),
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: AppTheme.secondaryNeon,
                  size: 18,
                ),
              ),
              tooltip: 'Đặt lại vị trí gốc',
              onPressed: _resetAllStickers,
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: AppTheme.textPrimary,
                size: 18,
              ),
            ),
            tooltip: 'Tuỳ chỉnh thông số',
            onPressed: _showOverlaySettingsSheet,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // KHUNG PREVIEW ẢNH CHÍNH (Tỉ lệ Story 4:5 hoặc 9:16)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: RepaintBoundary(
                      key: _previewKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Ảnh nền (Ảnh user chọn hoặc Nền chạy bộ marathon mặc định siêu nét)
                            if (_selectedImageBytes != null)
                              Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                              )
                            else
                              Image.asset(
                                'assets/images/default_running_bg.jpg',
                                fit: BoxFit.cover,
                              ),

                            // 2. Dải Gradient bảo vệ chữ luôn nổi bật
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.35),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.black.withValues(alpha: 0.88),
                                    ],
                                    stops: const [0.0, 0.25, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // 3. Các lớp khối đồ họa thể thao ĐỘC LẬP (Mỗi khối kéo thả & thu phóng riêng)
                            ..._buildTemplateLayers(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // THANH ĐIỀU KHIỂN KHỐI THÔNG SỐ (DOCKED TOOLBAR DƯỚI ẢNH KHI ĐƯỢC CHỌN)
            if (_selectedStickerId != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.secondaryNeon.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Tên khối đang chọn
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryNeon.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSelectedStickerLabel(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryNeon,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Nút Giảm cỡ (-)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 19),
                      tooltip: 'Thu nhỏ (-10%)',
                      onPressed: () {
                        final t = _getSelectedTransform();
                        if (t != null) {
                          setState(() {
                            t.scale = (t.scale - 0.1).clamp(0.4, 2.5);
                          });
                        }
                      },
                    ),

                    // Thanh kéo Slider tỷ lệ kích thước
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: AppTheme.secondaryNeon,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppTheme.secondaryNeon,
                        ),
                        child: Slider(
                          value: (_getSelectedTransform()?.scale ?? 1.0).clamp(0.4, 2.5),
                          min: 0.4,
                          max: 2.5,
                          onChanged: (val) {
                            final t = _getSelectedTransform();
                            if (t != null) {
                              setState(() {
                                t.scale = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    // Nút Tăng cỡ (+)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 19),
                      tooltip: 'Phóng to (+10%)',
                      onPressed: () {
                        final t = _getSelectedTransform();
                        if (t != null) {
                          setState(() {
                            t.scale = (t.scale + 0.1).clamp(0.4, 2.5);
                          });
                        }
                      },
                    ),

                    // Tỷ lệ %
                    Text(
                      '${((_getSelectedTransform()?.scale ?? 1.0) * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Nút Đặt lại khối này (↺)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 18),
                      tooltip: 'Đặt lại khối này',
                      onPressed: () {
                        final t = _getSelectedTransform();
                        if (t != null) {
                          setState(() {
                            t.reset();
                          });
                        }
                      },
                    ),

                    // Nút Xong (✓)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 21),
                      tooltip: 'Xong',
                      onPressed: () => setState(() => _selectedStickerId = null),
                    ),
                  ],
                ),
              )
            else
              // Gợi ý tính năng kéo thả & thu phóng từng khối
              const Padding(
                padding: EdgeInsets.only(top: 3, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 12.5, color: AppTheme.secondaryNeon),
                    SizedBox(width: 5),
                    Text(
                      'Chạm từng khối để kéo di chuyển hoặc chỉnh to nhỏ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // THANH CHỌN KIỂU HIỂN THỊ (SEGMENTED TABS) - TỐI GỌN, ĐƠN GIẢN
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  _buildSegmentItem(0, 'Tối giản'),
                  _buildSegmentItem(1, 'Bản đồ'),
                  _buildSegmentItem(2, 'Huy hiệu'),
                ],
              ),
            ),

            // THANH HÀNH ĐỘNG: ĐỔI ẢNH, LƯU ẢNH, CHIA SẺ
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: Row(
                children: [
                  // Nút đổi ảnh
                  InkWell(
                    onTap: _showImageSourceSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nút Lưu ảnh
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _saveToGallery,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Lưu ảnh',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nút Chia sẻ
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _shareImage,
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Chia sẻ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNeon,
                          elevation: 4,
                          shadowColor: AppTheme.primaryNeon.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút chọn Mẫu Tab Segmented
  Widget _buildSegmentItem(int index, String title) {
    final isSelected = _selectedTemplate == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTemplate = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryNeon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryNeon.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Danh sách các khối đồ họa thể thao độc lập có thể kéo thả & thu phóng riêng biệt
  List<Widget> _buildTemplateLayers() {
    final s = widget.session;
    final dateTimeStr = _formatDateTime(s.startTime);
    final layers = <Widget>[];

    // Khối 1: Logo & Thời gian (Dùng chung cho cả Mẫu Tối giản & Bản đồ)
    if (_selectedTemplate == 0 || _selectedTemplate == 1) {
      if (_showLogo || dateTimeStr.isNotEmpty) {
        layers.add(
          Positioned(
            top: 20,
            left: 18,
            right: 18,
            child: Align(
              alignment: Alignment.topLeft,
              child: DraggableSticker(
                id: 'header',
                label: 'Logo & Thời gian',
                transform: _headerTransform,
                isSelected: _selectedStickerId == 'header',
                onSelect: () => setState(() => _selectedStickerId = 'header'),
                onPanUpdate: (delta) => setState(() => _headerTransform.offset += delta),
                onScaleUpdate: (scale) => setState(() => _headerTransform.scale = scale),
                child: PhotoShareHeaderBlock(
                  showLogo: _showLogo,
                  dateTimeStr: dateTimeStr,
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_selectedTemplate == 0) {
      // ==========================================
      // MẪU 1: TỐI GIẢN (MINIMAL)
      // ==========================================

      // Khối 2: Cự ly số khổng lồ (Distance Block)
      if (_showDistance) {
        layers.add(
          Positioned(
            bottom: 74,
            left: 18,
            child: DraggableSticker(
              id: 'distance',
              label: 'Cự ly (KM)',
              transform: _distanceTransform,
              isSelected: _selectedStickerId == 'distance',
              onSelect: () => setState(() => _selectedStickerId = 'distance'),
              onPanUpdate: (delta) => setState(() => _distanceTransform.offset += delta),
              onScaleUpdate: (scale) => setState(() => _distanceTransform.scale = scale),
              child: MinimalDistanceBlock(
                distanceKm: s.distanceKm,
              ),
            ),
          ),
        );
      }

      // Khối 3: Hàng thông số phụ (Thời gian, Pace, Calo)
      if (_showDuration || _showPace || _showCalories) {
        layers.add(
          Positioned(
            bottom: 20,
            left: 18,
            right: 18,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: DraggableSticker(
                id: 'stats',
                label: 'Hàng thông số',
                transform: _statsTransform,
                isSelected: _selectedStickerId == 'stats',
                onSelect: () => setState(() => _selectedStickerId = 'stats'),
                onPanUpdate: (delta) => setState(() => _statsTransform.offset += delta),
                onScaleUpdate: (scale) => setState(() => _statsTransform.scale = scale),
                child: MinimalStatsBlock(
                  session: s,
                  showDuration: _showDuration,
                  showPace: _showPace,
                  showCalories: _showCalories,
                ),
              ),
            ),
          ),
        );
      }
    } else if (_selectedTemplate == 1) {
      // ==========================================
      // MẪU 2: BẢN ĐỒ GPS (ROUTE OVERLAY)
      // ==========================================

      // Khối 2: Đường vẽ chạy GPS Neon Art
      if (s.routePoints.length >= 2) {
        layers.add(
          Positioned.fill(
            child: Center(
              child: DraggableSticker(
                id: 'map_route',
                label: 'Đường vẽ GPS',
                transform: _mapRouteTransform,
                isSelected: _selectedStickerId == 'map_route',
                onSelect: () => setState(() => _selectedStickerId = 'map_route'),
                onPanUpdate: (delta) => setState(() => _mapRouteTransform.offset += delta),
                onScaleUpdate: (scale) => setState(() => _mapRouteTransform.scale = scale),
                child: MapRouteBlock(
                  routePoints: s.routePoints,
                ),
              ),
            ),
          ),
        );
      }

      // Khối 3: Thẻ thông số đáy bo tròn
      if (_showDistance || _showDuration || _showPace || _showCalories) {
        layers.add(
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Center(
              child: DraggableSticker(
                id: 'map_stats',
                label: 'Thẻ thông số',
                transform: _mapStatsTransform,
                isSelected: _selectedStickerId == 'map_stats',
                onSelect: () => setState(() => _selectedStickerId = 'map_stats'),
                onPanUpdate: (delta) => setState(() => _mapStatsTransform.offset += delta),
                onScaleUpdate: (scale) => setState(() => _mapStatsTransform.scale = scale),
                child: MapStatsBlock(
                  session: s,
                  showDistance: _showDistance,
                  showDuration: _showDuration,
                  showPace: _showPace,
                  showCalories: _showCalories,
                ),
              ),
            ),
          ),
        );
      }
    } else if (_selectedTemplate == 2) {
      // ==========================================
      // MẪU 3: HUY HIỆU THỂ THAO (STORY BADGE)
      // ==========================================
      layers.add(
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Center(
            child: DraggableSticker(
              id: 'badge',
              label: 'Thẻ Huy hiệu',
              transform: _badgeTransform,
              isSelected: _selectedStickerId == 'badge',
              onSelect: () => setState(() => _selectedStickerId = 'badge'),
              onPanUpdate: (delta) => setState(() => _badgeTransform.offset += delta),
              onScaleUpdate: (scale) => setState(() => _badgeTransform.scale = scale),
              child: BadgeCardBlock(
                session: s,
                dateTimeStr: dateTimeStr,
                showLogo: _showLogo,
                showDistance: _showDistance,
                showDuration: _showDuration,
                showPace: _showPace,
                showCalories: _showCalories,
                showSteps: _showSteps,
              ),
            ),
          ),
        ),
      );
    }

    return layers;
  }
}
