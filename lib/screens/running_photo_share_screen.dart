import 'dart:io';
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

  File? _selectedImage;
  int _selectedTemplate = 0; // 0: Tối giản, 1: Bản đồ, 2: Huy hiệu
  bool _isExporting = false;
  Offset _badgeOffset = Offset.zero; // Toạ độ kéo thả tự do của thẻ thông số

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
        setState(() {
          _selectedImage = File(picked.path);
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
                                _badgeOffset = Offset.zero;
                              });
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vị trí thẻ thông số',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Kéo thả tự do bất kỳ đâu trên ảnh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _badgeOffset = Offset.zero);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.secondaryNeon),
                            label: const Text(
                              'Đặt lại vị trí',
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
                            if (_selectedImage != null)
                              Image.file(
                                _selectedImage!,
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

                            // 3. Lớp đồ họa thể thao có thể KÉO THẢ (Drag & Drop) tự do khắp màn hình
                            GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _badgeOffset += details.delta;
                                });
                              },
                              child: Transform.translate(
                                offset: _badgeOffset,
                                child: _buildTemplateOverlay(),
                              ),
                            ),

                            // 4. Nút đổi ảnh nhanh ở góc trên bên phải
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _showImageSourceSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_camera_rounded, size: 13, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đổi ảnh',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 5. Nút phục hồi vị trí gốc nhanh nếu đã kéo lệch
                            if (_badgeOffset != Offset.zero)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: GestureDetector(
                                  onTap: () => setState(() => _badgeOffset = Offset.zero),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryNeon.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.restart_alt_rounded, size: 13, color: Colors.black),
                                        SizedBox(width: 4),
                                        Text(
                                          'Vị trí gốc',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
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
                  ),
                ),
              ),
            ),

            // Gợi ý tính năng kéo thả
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined, size: 12.5, color: AppTheme.textMuted),
                  SizedBox(width: 4),
                  Text(
                    'Chạm giữ & kéo để di chuyển vị trí thẻ thông số',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
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

  /// Lớp đồ họa đè lên ảnh theo từng Template (Đã tách thành các Widget component độc lập)
  Widget _buildTemplateOverlay() {
    final s = widget.session;
    final dateTimeStr = _formatDateTime(s.startTime);

    switch (_selectedTemplate) {
      case 1:
        return MapTemplateWidget(
          session: s,
          dateTimeStr: dateTimeStr,
          showLogo: _showLogo,
          showDistance: _showDistance,
          showDuration: _showDuration,
          showPace: _showPace,
          showCalories: _showCalories,
        );
      case 2:
        return BadgeTemplateWidget(
          session: s,
          dateTimeStr: dateTimeStr,
          showLogo: _showLogo,
          showDistance: _showDistance,
          showDuration: _showDuration,
          showPace: _showPace,
          showCalories: _showCalories,
          showSteps: _showSteps,
        );
      case 0:
      default:
        return MinimalTemplateWidget(
          session: s,
          dateTimeStr: dateTimeStr,
          showLogo: _showLogo,
          showDistance: _showDistance,
          showDuration: _showDuration,
          showPace: _showPace,
          showCalories: _showCalories,
        );
    }
  }
}
