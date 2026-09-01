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

  // Cấu hình bật/tắt các thông số ghép vào ảnh
  bool _showLogo = true;
  bool _showDate = true;
  bool _showDistance = true;
  bool _showDuration = true;
  bool _showPace = true;
  bool _showCalories = true;
  bool _showSteps = true;

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                  const SizedBox(height: 16),
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
                            _showDate = true;
                            _showDistance = true;
                            _showDuration = true;
                            _showPace = true;
                            _showCalories = true;
                            _showSteps = true;
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
                  const SizedBox(height: 10),
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
                    title: 'Ngày chạy',
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
                ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
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
                            // 1. Ảnh nền (Ảnh user chọn hoặc Nền thể thao mặc định)
                            if (_selectedImage != null)
                              Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              )
                            else
                              _buildDefaultSportsBackground(),

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

                            // 3. Lớp đồ họa thể thao theo Template được chọn
                            _buildTemplateOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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

  /// Nền thể thao mặc định nếu người dùng chưa chụp ảnh
  Widget _buildDefaultSportsBackground() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F111E),
              Color(0xFF1E2139),
              Color(0xFF0D0E15),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryNeon.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppTheme.primaryNeon.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 40,
                  color: AppTheme.primaryNeon,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chạm để chọn hoặc chụp ảnh',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lớp đồ họa đè lên ảnh theo từng Template
  Widget _buildTemplateOverlay() {
    switch (_selectedTemplate) {
      case 1:
        return _buildMapTemplate();
      case 2:
        return _buildBadgeTemplate();
      case 0:
      default:
        return _buildMinimalTemplate();
    }
  }
  Widget _buildMinimalTemplate() {
    final s = widget.session;
    final dateStr = DateFormat('dd/MM/yyyy').format(s.startTime);

    final bottomStats = <Widget>[];
    if (_showDuration) {
      bottomStats.add(_buildMiniStat('THỜI GIAN', s.formattedDuration));
    }
    if (_showPace) {
      if (bottomStats.isNotEmpty) bottomStats.add(_buildDivider());
      bottomStats.add(_buildMiniStat('PACE', '${s.formattedPace} /km'));
    }
    if (_showCalories) {
      if (bottomStats.isNotEmpty) bottomStats.add(_buildDivider());
      bottomStats.add(_buildMiniStat('CALO', '${s.calories} kcal'));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Ngày ở góc trên (chỉ có logo, không có chữ)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_showLogo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_showDate)
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),

          const Spacer(),

          // Thông số Cự ly Khổng lồ
          if (_showDistance)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  s.distanceKm.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'KM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryNeon,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),

          if (bottomStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: bottomStats),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 2: BẢN ĐỒ GPS (ROUTE OVERLAY)
  // ==========================================
  Widget _buildMapTemplate() {
    final s = widget.session;
    final dateStr = DateFormat('dd/MM/yyyy').format(s.startTime);

    final stats = <Widget>[];
    if (_showDistance) {
      stats.add(_buildCompactStat('${s.distanceKm.toStringAsFixed(2)} KM', 'Quãng đường', AppTheme.primaryNeon));
    }
    if (_showDuration) {
      stats.add(_buildCompactStat(s.formattedDuration, 'Thời gian', Colors.white));
    }
    if (_showPace) {
      stats.add(_buildCompactStat(s.formattedPace, 'Pace TB', AppTheme.secondaryNeon));
    }
    if (_showCalories) {
      stats.add(_buildCompactStat('${s.calories}', 'Calo', AppTheme.accentOrange));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Logo & Ngày góc trên
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_showLogo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_showDate)
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),

          // Vùng vẽ line GPS Art thu nhỏ
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: s.routePoints.length >= 2
                    ? CustomPaint(
                        painter: _GpsRouteOverlayPainter(s.routePoints),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          // Thẻ thông số đáy
          if (stats.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: stats,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 3: STORY BADGE (HUY HIỆU THỂ THAO)
  // ==========================================
  Widget _buildBadgeTemplate() {
    final s = widget.session;
    final dateStr = DateFormat('dd/MM/yyyy').format(s.startTime);
    final showTop = _showLogo || _showDate;

    // Danh sách các thông số phụ đi kèm
    final subStats = <Widget>[];
    if (_showDuration) {
      subStats.add(_buildBadgeInlineStat(Icons.timer_outlined, s.formattedDuration, Colors.white));
    }
    if (_showPace) {
      subStats.add(_buildBadgeInlineStat(Icons.speed_rounded, '${s.formattedPace}/km', AppTheme.secondaryNeon));
    }
    if (_showCalories) {
      subStats.add(_buildBadgeInlineStat(Icons.local_fire_department_rounded, '${s.calories} kcal', AppTheme.accentOrange));
    }
    if (_showSteps) {
      subStats.add(_buildBadgeInlineStat(Icons.directions_walk_rounded, '${s.totalSteps} bước', const Color(0xFF00E5FF)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          const Spacer(),

          // Thẻ Huy Hiệu Thể Thao Tinh Gọn (Không box-shadow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryNeon.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Dòng Header: Chỉ có Logo App bên trái và Ngày chạy bên phải (đã bỏ text Huy hiệu hoàn thành)
                if (showTop) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_showLogo)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (_showDate)
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    height: 0.8,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ],

                // 2. Nội dung: Cự ly chính bên trái + Các thông số phụ căng đều 2 bên
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cột trái: Cự ly nổi bật
                    if (_showDistance) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.distanceKm.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryNeon,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Vạch ngăn cách dọc
                    if (_showDistance && subStats.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        height: 26,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ],

                    // Cột phải: Các thông số phụ xếp thành lưới 2 cột căng đều 2 bên
                    if (subStats.isNotEmpty)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < subStats.length; i += 2) ...[
                              if (i > 0) const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(child: subStats[i]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: (i + 1 < subStats.length)
                                        ? subStats[i + 1]
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeInlineStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.95),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

/// CustomPainter vẽ đường chạy GPS Neon Art trên ảnh
class _GpsRouteOverlayPainter extends CustomPainter {
  final List<RunPoint> routePoints;

  _GpsRouteOverlayPainter(this.routePoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    double minX = routePoints.first.x;
    double maxX = routePoints.first.x;
    double minY = routePoints.first.y;
    double maxY = routePoints.first.y;

    for (final p in routePoints) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final double rangeX = (maxX - minX == 0) ? 0.0001 : maxX - minX;
    final double rangeY = (maxY - minY == 0) ? 0.0001 : maxY - minY;

    final double padding = size.width * 0.1;
    final double drawW = size.width - padding * 2;
    final double drawH = size.height - padding * 2;

    final path = Path();
    for (int i = 0; i < routePoints.length; i++) {
      final p = routePoints[i];
      final double dx = padding + ((p.x - minX) / rangeX) * drawW;
      final double dy = padding + (1.0 - ((p.y - minY) / rangeY)) * drawH;

      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    // Vẽ bóng phát sáng neon (Glow effect)
    final glowPaint = Paint()
      ..color = AppTheme.secondaryNeon.withValues(alpha: 0.4)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Vẽ đường line chính Neon
    final linePaint = Paint()
      ..color = AppTheme.secondaryNeon
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Điểm bắt đầu (Chấm xanh lá)
    final startP = routePoints.first;
    final double startDx = padding + ((startP.x - minX) / rangeX) * drawW;
    final double startDy = padding + (1.0 - ((startP.y - minY) / rangeY)) * drawH;
    final startDot = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(Offset(startDx, startDy), 6, startDot);

    // Điểm kết thúc (Chấm đỏ neon)
    final endP = routePoints.last;
    final double endDx = padding + ((endP.x - minX) / rangeX) * drawW;
    final double endDy = padding + (1.0 - ((endP.y - minY) / rangeY)) * drawH;
    final endDot = Paint()..color = AppTheme.primaryNeon;
    canvas.drawCircle(Offset(endDx, endDy), 6, endDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
