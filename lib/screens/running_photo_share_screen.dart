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
  int _selectedTemplate = 0; // 0: Tối giản (Strava), 1: Line GPS Art, 2: Huy hiệu Pro
  bool _isExporting = false;

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

  /// Render ảnh preview thành file ảnh PNG độ nét cao
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
        title: const Text('Tạo ảnh check-in'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_rounded, color: AppTheme.secondaryNeon),
            tooltip: 'Đổi ảnh',
            onPressed: _showImageSourceSheet,
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

            // THANH CHỌN MẪU TEM (TEMPLATE SELECTOR)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  _buildTemplateChip(0, 'Tối giản Strava', Icons.space_dashboard_rounded),
                  const SizedBox(width: 8),
                  _buildTemplateChip(1, 'Line GPS Art', Icons.route_rounded),
                  const SizedBox(width: 8),
                  _buildTemplateChip(2, 'Huy hiệu Pro', Icons.military_tech_rounded),
                ],
              ),
            ),

            // NÚT THAO TÁC: LƯU VÀO MÁY & CHIA SẺ
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
              child: Row(
                children: [
                  // Nút đổi ảnh nhanh nếu chưa chọn
                  IconButton.filledTonal(
                    onPressed: _showImageSourceSheet,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.textPrimary),
                    tooltip: 'Chụp hoặc chọn ảnh',
                  ),
                  const SizedBox(width: 10),

                  // Nút Lưu vào máy
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _saveToGallery,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded, color: Colors.white),
                        label: const Text(
                          'LƯU VÀO MÁY',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Nút Chia sẻ
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _shareImage,
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        label: const Text(
                          'CHIA SẺ',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNeon,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

  /// Nút chọn Mẫu Template
  Widget _buildTemplateChip(int index, String label, IconData icon) {
    final isSelected = _selectedTemplate == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTemplate = index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryNeon.withValues(alpha: 0.2)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryNeon : AppTheme.divider,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primaryNeon : AppTheme.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nền thể thao mặc định nếu người dùng chưa chụp ảnh
  Widget _buildDefaultSportsBackground() {
    return Container(
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                size: 48,
                color: AppTheme.primaryNeon,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chạm vào icon máy ảnh\nđể thêm bức ảnh của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lớp đồ họa đè lên ảnh theo từng Template
  Widget _buildTemplateOverlay() {
    switch (_selectedTemplate) {
      case 1:
        return _buildGpsArtTemplate();
      case 2:
        return _buildBadgeTemplate();
      case 0:
      default:
        return _buildMinimalStravaTemplate();
    }
  }

  // ==========================================
  // TEMPLATE 1: TỐI GIẢN (CHUẨN STRAVA MINIMAL)
  // ==========================================
  Widget _buildMinimalStravaTemplate() {
    final s = widget.session;
    final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(s.startTime);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Tên ứng dụng ở góc trên
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_run_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NOCODEVN RUNNING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Thông số Cự ly Khổng lồ
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

          const SizedBox(height: 12),

          // Bộ 3 thông số: Thời gian, Pace, Calo
          Row(
            children: [
              _buildMiniStat('THỜI GIAN', s.formattedDuration),
              _buildDivider(),
              _buildMiniStat('PACE', '${s.formattedPace} /km'),
              _buildDivider(),
              _buildMiniStat('CALORIES', '${s.calories} kcal'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 2: NEON GPS ART (VẼ LỘ TRÌNH GPS NỔI)
  // ==========================================
  Widget _buildGpsArtTemplate() {
    final s = widget.session;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Logo top
          Row(
            children: const [
              Icon(Icons.share_location_rounded, color: AppTheme.secondaryNeon, size: 18),
              SizedBox(width: 6),
              Text(
                'LỘ TRÌNH CHẠY BỘ GPS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondaryNeon,
                  letterSpacing: 1.0,
                ),
              ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactStat('${s.distanceKm.toStringAsFixed(2)} KM', 'Quãng đường', AppTheme.primaryNeon),
                _buildCompactStat(s.formattedDuration, 'Thời gian', Colors.white),
                _buildCompactStat(s.formattedPace, 'Pace TB', AppTheme.secondaryNeon),
                _buildCompactStat('${s.calories}', 'Calo', AppTheme.accentOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 3: STORY BADGE (HUY HIỆU THỂ THAO PRO)
  // ==========================================
  Widget _buildBadgeTemplate() {
    final s = widget.session;
    final dateStr = DateFormat('dd/MM/yyyy').format(s.startTime);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),

          // Khung Badge Thể Thao Pro
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.primaryNeon, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNeon.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryNeon, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'NOCODEVN RUNNING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: AppTheme.primaryNeon,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.divider, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          s.distanceKm.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'KM',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          s.formattedPace,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.secondaryNeon,
                          ),
                        ),
                        const Text(
                          'PACE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          s.formattedDuration,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'THỜI GIAN',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ],
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
