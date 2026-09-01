import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/running_provider.dart';
import '../models/run_session.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/top_sync_toast.dart';
import 'session_detail_screen.dart';

enum HistoryDateFilterType { all, today, thisWeek, thisMonth, last7Days, last30Days, lastMonth, custom }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 15;
  int _displayedCount = _pageSize;
  bool _isLoadingMore = false;
  bool _showScrollToTop = false;

  HistoryDateFilterType _filterType = HistoryDateFilterType.all;
  DateTimeRange? _selectedCustomRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 1. Ẩn/Hiện nút Lên đầu trang
    final showTop = _scrollController.hasClients && _scrollController.offset > 350;
    if (showTop != _showScrollToTop) {
      setState(() => _showScrollToTop = showTop);
    }

    // 2. Tự động tải thêm khi cuộn gần đáy
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final running = context.read<RunningProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final allSessions = currentUser != null
        ? running.getUserSessions(currentUser.id, currentUser.email, currentUser.username, currentUser.name)
        : running.allSessions;

    final filtered = _applyDateFilter(allSessions);

    if (_isLoadingMore || _displayedCount >= filtered.length) return;

    setState(() => _isLoadingMore = true);

    // Độ trễ nhẹ tạo hiệu ứng cuộn mượt mà
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _displayedCount = (_displayedCount + _pageSize).clamp(0, filtered.length);
        _isLoadingMore = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _clearFilter() {
    setState(() {
      _filterType = HistoryDateFilterType.all;
      _selectedCustomRange = null;
      _displayedCount = _pageSize;
    });
  }

  String _getActiveFilterLabel() {
    switch (_filterType) {
      case HistoryDateFilterType.all:
        return 'Tất cả';
      case HistoryDateFilterType.today:
        return 'Hôm nay';
      case HistoryDateFilterType.thisWeek:
        return 'Tuần này';
      case HistoryDateFilterType.thisMonth:
        return 'Tháng này';
      case HistoryDateFilterType.last7Days:
        return '7 ngày qua';
      case HistoryDateFilterType.last30Days:
        return '30 ngày qua';
      case HistoryDateFilterType.lastMonth:
        return 'Tháng trước';
      case HistoryDateFilterType.custom:
        if (_selectedCustomRange != null) {
          final fmt = DateFormat('dd/MM');
          return '${fmt.format(_selectedCustomRange!.start)} - ${fmt.format(_selectedCustomRange!.end)}';
        }
        return 'Tùy chọn';
    }
  }

  List<RunSession> _applyDateFilter(List<RunSession> list) {
    final now = DateTime.now();

    switch (_filterType) {
      case HistoryDateFilterType.all:
        return list;

      case HistoryDateFilterType.today:
        final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
        return list.where((s) => !s.startTime.isBefore(startOfToday)).toList();

      case HistoryDateFilterType.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1), 0, 0, 0);
        return list.where((s) => !s.startTime.isBefore(startOfWeek)).toList();

      case HistoryDateFilterType.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
        return list.where((s) => !s.startTime.isBefore(startOfMonth)).toList();

      case HistoryDateFilterType.last7Days:
        final start7 = now.subtract(const Duration(days: 7));
        return list.where((s) => !s.startTime.isBefore(start7)).toList();

      case HistoryDateFilterType.last30Days:
        final start30 = now.subtract(const Duration(days: 30));
        return list.where((s) => !s.startTime.isBefore(start30)).toList();

      case HistoryDateFilterType.lastMonth:
        final startLastMonth = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
        final endLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
        return list.where((s) => !s.startTime.isBefore(startLastMonth) && !s.startTime.isAfter(endLastMonth)).toList();

      case HistoryDateFilterType.custom:
        if (_selectedCustomRange == null) return list;
        final start = DateTime(
          _selectedCustomRange!.start.year,
          _selectedCustomRange!.start.month,
          _selectedCustomRange!.start.day,
          0, 0, 0,
        );
        final end = DateTime(
          _selectedCustomRange!.end.year,
          _selectedCustomRange!.end.month,
          _selectedCustomRange!.end.day,
          23, 59, 59,
        );
        return list.where((s) => !s.startTime.isBefore(start) && !s.startTime.isAfter(end)).toList();
    }
  }

  /// Modal Bottom Sheet Bộ Lọc Thời Gian
  void _openFilterBottomSheet() {
    final now = DateTime.now();
    HistoryDateFilterType tempType = _filterType;
    DateTime tempStart = _selectedCustomRange?.start ?? now.subtract(const Duration(days: 7));
    DateTime tempEnd = _selectedCustomRange?.end ?? now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateFormat = DateFormat('dd/MM/yyyy');

            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: modalCtx,
                initialDate: tempStart,
                firstDate: DateTime(2020),
                lastDate: tempEnd,
                helpText: 'CHỌN NGÀY BẮT ĐẦU',
                cancelText: 'HỦY',
                confirmText: 'CHỌN',
                builder: (context, child) => _buildDatePickerTheme(context, child),
              );
              if (picked != null) {
                setModalState(() {
                  tempStart = picked;
                  tempType = HistoryDateFilterType.custom;
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: modalCtx,
                initialDate: tempEnd,
                firstDate: tempStart,
                lastDate: DateTime(now.year + 1),
                helpText: 'CHỌN NGÀY KẾT THÚC',
                cancelText: 'HỦY',
                confirmText: 'CHỌN',
                builder: (context, child) => _buildDatePickerTheme(context, child),
              );
              if (picked != null) {
                setModalState(() {
                  tempEnd = picked;
                  tempType = HistoryDateFilterType.custom;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh handle kéo
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Modal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tune_rounded, color: AppTheme.primaryNeon, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'BỘ LỌC THỜI GIAN',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. CHỌN NHANH
                  const Text(
                    'CHỌN NHANH:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalChip(
                        label: 'Tất cả',
                        isSelected: tempType == HistoryDateFilterType.all,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.all),
                      ),
                      _buildModalChip(
                        label: 'Hôm nay',
                        isSelected: tempType == HistoryDateFilterType.today,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.today),
                      ),
                      _buildModalChip(
                        label: 'Tuần này',
                        isSelected: tempType == HistoryDateFilterType.thisWeek,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.thisWeek),
                      ),
                      _buildModalChip(
                        label: 'Tháng này',
                        isSelected: tempType == HistoryDateFilterType.thisMonth,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.thisMonth),
                      ),
                      _buildModalChip(
                        label: '7 ngày qua',
                        isSelected: tempType == HistoryDateFilterType.last7Days,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.last7Days),
                      ),
                      _buildModalChip(
                        label: '30 ngày qua',
                        isSelected: tempType == HistoryDateFilterType.last30Days,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.last30Days),
                      ),
                      _buildModalChip(
                        label: 'Tháng trước',
                        isSelected: tempType == HistoryDateFilterType.lastMonth,
                        onTap: () => setModalState(() => tempType = HistoryDateFilterType.lastMonth),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. TÙY CHỌN KHOẢNG NGÀY
                  const Text(
                    'TÙY CHỌN KHOẢNG NGÀY:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Card Từ Ngày
                      Expanded(
                        child: InkWell(
                          onTap: pickStartDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: tempType == HistoryDateFilterType.custom
                                    ? AppTheme.secondaryNeon
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.event_available_rounded, size: 14, color: AppTheme.secondaryNeon),
                                    SizedBox(width: 6),
                                    Text(
                                      'TỪ NGÀY',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(tempStart),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Card Đến Ngày
                      Expanded(
                        child: InkWell(
                          onTap: pickEndDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: tempType == HistoryDateFilterType.custom
                                    ? AppTheme.primaryNeon
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.flag_outlined, size: 14, color: AppTheme.primaryNeon),
                                    SizedBox(width: 6),
                                    Text(
                                      'ĐẾN NGÀY',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(tempEnd),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 3. NÚT ÁP DỤNG & XÓA BỘ LỌC
                  Row(
                    children: [
                      // Nút Xóa bộ lọc
                      if (tempType != HistoryDateFilterType.all || _filterType != HistoryDateFilterType.all) ...[
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                side: const BorderSide(color: AppTheme.divider),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                _clearFilter();
                                Navigator.of(ctx).pop();
                              },
                              child: const Text(
                                'XÓA LỌC',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Nút Áp Dụng
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNeon,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _filterType = tempType;
                                if (tempType == HistoryDateFilterType.custom) {
                                  _selectedCustomRange = DateTimeRange(start: tempStart, end: tempEnd);
                                } else {
                                  _selectedCustomRange = null;
                                }
                                _displayedCount = _pageSize;
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: const Text(
                              'ÁP DỤNG',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.primaryNeon,
          onPrimary: Colors.white,
          surface: AppTheme.surface,
          onSurface: AppTheme.textPrimary,
          secondary: AppTheme.secondaryNeon,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppTheme.surface,
        ),
      ),
      child: child!,
    );
  }

  Widget _buildModalChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNeon : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNeon : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = context.watch<RunningProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final allUserSessions = currentUser != null
        ? running.getUserSessions(currentUser.id, currentUser.email, currentUser.username, currentUser.name)
        : running.allSessions;

    // Áp dụng bộ lọc theo ngày
    final filteredSessions = _applyDateFilter(allUserSessions);

    // Tính toán số liệu tổng kết dựa trên kết quả ĐÃ LỌC
    final double totalKm = filteredSessions.fold(0.0, (sum, s) => sum + s.distanceKm);
    final int totalSeconds = filteredSessions.fold(0, (sum, s) => sum + s.durationSeconds);
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;

    final isFiltered = _filterType != HistoryDateFilterType.all;

    // Danh sách đã phân trang (Load More)
    final visibleCount = _displayedCount.clamp(0, filteredSessions.length);
    final visibleSessions = filteredSessions.take(visibleCount).toList();
    final hasMore = visibleCount < filteredSessions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LỊCH SỬ CHẠY BỘ'),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.extended(
              onPressed: _scrollToTop,
              backgroundColor: AppTheme.primaryNeon,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              label: const Text(
                'LÊN ĐẦU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryNeon,
          backgroundColor: const Color(0xFF0F172A),
          strokeWidth: 2.5,
          onRefresh: () async {
            await Future.wait([
              context.read<RunningProvider>().refreshAllData(),
              context.read<AuthProvider>().checkUserStillExistsOnServer(),
            ]);
            if (!mounted) return;
            setState(() {
              _displayedCount = _pageSize; // Reset về trang 1
            });
            if (context.mounted) {
              TopSyncToast.show(
                context,
                message: '🔄 Đã cập nhật danh sách buổi chạy mới nhất!',
                isSuccess: true,
              );
            }
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ==========================================
              // 1. THẺ TỔNG QUAN THỂ THAO RỘNG RÃI & TỐI ƯU SỐ DÀI
              // ==========================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isFiltered ? AppTheme.primaryNeon.withValues(alpha: 0.5) : AppTheme.divider,
                        width: isFiltered ? 1.2 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng tiêu đề thẻ tổng quan + Nút Bộ lọc
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_outlined,
                                    color: AppTheme.primaryNeon,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'TỔNG KẾT THÀNH TÍCH',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),

                            // Nút Bộ Lọc Tinh Tế
                            InkWell(
                              onTap: _openFilterBottomSheet,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isFiltered
                                      ? AppTheme.primaryNeon.withValues(alpha: 0.18)
                                      : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isFiltered ? AppTheme.primaryNeon : AppTheme.divider,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 13,
                                      color: isFiltered ? AppTheme.primaryNeon : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isFiltered ? _getActiveFilterLabel() : 'Bộ lọc',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isFiltered ? AppTheme.primaryNeon : AppTheme.textSecondary,
                                      ),
                                    ),
                                    if (isFiltered) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: _clearFilter,
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: AppTheme.primaryNeon,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppTheme.divider),
                        const SizedBox(height: 18),

                        // 3 Chỉ số lớn thể thao - Căn chỉnh rộng rãi & Tự co dãn chống tràn số to
                        Row(
                          children: [
                            // 1. Tổng Cự Ly
                            Expanded(
                              flex: 11,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          totalKm.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.primaryNeon,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Text(
                                          'KM',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.primaryNeon,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'TỔNG KM',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(width: 1, height: 40, color: AppTheme.divider),

                            // 2. Buổi chạy
                            Expanded(
                              flex: 9,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${filteredSessions.length}',
                                        style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.secondaryNeon,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'BUỔI CHẠY',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Container(width: 1, height: 40, color: AppTheme.divider),

                            // 3. Thời gian
                            Expanded(
                              flex: 11,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        hours > 0 ? '${hours}h ${minutes}p' : '${minutes}p',
                                        style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.textPrimary,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'THỜI GIAN',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
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

              // ==========================================
              // 2. DANH SÁCH BUỔI CHẠY (PREMIUM SESSION CARDS)
              // ==========================================
              if (filteredSessions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_run_outlined, size: 56, color: AppTheme.textMuted),
                        const SizedBox(height: 14),
                        Text(
                          !isFiltered
                              ? 'Chưa có buổi chạy nào'
                              : 'Không có buổi chạy nào trong khoảng thời gian này',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !isFiltered
                              ? 'Vuốt xuống để tải lại hoặc bấm "Bắt đầu chạy"!'
                              : 'Hãy chọn mốc thời gian khác hoặc bấm "Xóa bộ lọc"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        if (isFiltered) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceLight,
                              foregroundColor: AppTheme.textPrimary,
                              elevation: 0,
                              side: const BorderSide(color: AppTheme.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('XEM TẤT CẢ BUỔI CHẠY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _clearFilter,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = visibleSessions[index];
                        return _buildSessionCard(context, session);
                      },
                      childCount: visibleSessions.length,
                    ),
                  ),
                ),

                // Footer báo trạng thái: Đang tải thêm hoặc Đã xem hết
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      children: [
                        if (_isLoadingMore) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryNeon,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Đang tải thêm buổi chạy...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ] else if (!hasMore && filteredSessions.length > _pageSize) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Text(
                              '🏁 Bạn đã xem hết tất cả ${filteredSessions.length} buổi chạy',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Thẻ Buổi Chạy Đầy Đủ (Avatar + Tên người chạy + Tên buổi chạy + 4 Chỉ số thoáng đẹp)
  Widget _buildSessionCard(BuildContext context, RunSession session) {
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
    final running = context.read<RunningProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final realName = running.getUserRealName(session.userId, session.userName);
    String realAvatar = running.getUserRealAvatar(session.userId);
    if (realAvatar.isEmpty && currentUser != null && currentUser.id == session.userId && currentUser.avatarUrl.isNotEmpty) {
      realAvatar = currentUser.avatarUrl;
    }
    final isAdmin = running.isUserAdmin(session.userId);

    // Tên buổi chạy nổi bật
    final sessionName = session.notes.trim().isNotEmpty
        ? session.notes.trim()
        : 'Buổi chạy ${DateFormat('dd/MM/yyyy').format(session.startTime)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionDetailScreen(session: session),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER: AVATAR + TÊN NGƯỜI CHẠY + NGÀY GIỜ + CỰ LY (KM)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          avatarUrl: realAvatar,
                          name: realName,
                          radius: 20,
                          isAdmin: isAdmin,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              realName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(session.startTime),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Badge Cự Ly Nổi Bật Bên Phải
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNeon.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryNeon.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${session.formattedDistance} KM',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryNeon,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. TÊN BUỔI CHẠY (In đậm, rõ ràng)
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.secondaryNeon),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sessionName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 12),

                // 3. KHỐI 4 THÔNG SỐ THỂ THAO (DÃN CÁCH RỘNG RÃI & TỰ CO DÃN CHỐNG TRÀN)
                Row(
                  children: [
                    _buildMetricBox('THỜI GIAN', session.formattedDuration, AppTheme.textPrimary),
                    _buildVerticalDivider(),
                    _buildMetricBox('PACE', '${session.pace} /km', AppTheme.secondaryNeon),
                    _buildVerticalDivider(),
                    _buildMetricBox('CALO', '${session.calories} kcal', AppTheme.primaryNeon),
                    _buildVerticalDivider(),
                    _buildMetricBox('TỐC ĐỘ', '${session.formattedAvgSpeed} km/h', AppTheme.textPrimary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.divider,
    );
  }
}
