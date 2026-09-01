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

enum HistoryDateFilterType { all, thisWeek, thisMonth, custom }

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

  List<RunSession> _applyDateFilter(List<RunSession> list) {
    final now = DateTime.now();

    switch (_filterType) {
      case HistoryDateFilterType.all:
        return list;

      case HistoryDateFilterType.thisWeek:
        // Bắt đầu từ thứ Hai đầu tuần đến hiện tại
        final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1), 0, 0, 0);
        return list.where((s) => !s.startTime.isBefore(startOfWeek)).toList();

      case HistoryDateFilterType.thisMonth:
        // Bắt đầu từ ngày 1 của tháng hiện tại
        final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
        return list.where((s) => !s.startTime.isBefore(startOfMonth)).toList();

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

  Future<void> _openCustomDateRangePicker() async {
    final now = DateTime.now();
    final initialRange = _selectedCustomRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'CHỌN KHOẢNG NGÀY LỌC BUỔI CHẠY',
      cancelText: 'HỦY',
      confirmText: 'ÁP DỤNG',
      saveText: 'ÁP DỤNG',
      builder: (context, child) {
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
      },
    );

    if (picked != null) {
      setState(() {
        _selectedCustomRange = picked;
        _filterType = HistoryDateFilterType.custom;
        _displayedCount = _pageSize; // Reset phân trang
      });
    }
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
              // 1. THANH CHỌN BỘ LỌC NGÀY THÁNG (FILTER BAR)
              // ==========================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'TẤT CẢ',
                              isSelected: _filterType == HistoryDateFilterType.all,
                              onTap: () {
                                setState(() {
                                  _filterType = HistoryDateFilterType.all;
                                  _displayedCount = _pageSize;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'TUẦN NÀY',
                              isSelected: _filterType == HistoryDateFilterType.thisWeek,
                              onTap: () {
                                setState(() {
                                  _filterType = HistoryDateFilterType.thisWeek;
                                  _displayedCount = _pageSize;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'THÁNG NÀY',
                              isSelected: _filterType == HistoryDateFilterType.thisMonth,
                              onTap: () {
                                setState(() {
                                  _filterType = HistoryDateFilterType.thisMonth;
                                  _displayedCount = _pageSize;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildCustomFilterChip(),
                          ],
                        ),
                      ),

                      // Badge hiển thị khoảng ngày tùy chọn đang được áp dụng
                      if (_filterType == HistoryDateFilterType.custom && _selectedCustomRange != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryNeon.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.secondaryNeon.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.date_range_rounded, size: 14, color: AppTheme.secondaryNeon),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(_selectedCustomRange!.start)} ➔ ${DateFormat('dd/MM/yyyy').format(_selectedCustomRange!.end)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryNeon,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _filterType = HistoryDateFilterType.all;
                                    _selectedCustomRange = null;
                                    _displayedCount = _pageSize;
                                  });
                                },
                                child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.secondaryNeon),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ==========================================
              // 2. THẺ TỔNG QUAN ĐÃ TỰ ĐỘNG LỌC SỐ LIỆU
              // ==========================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat('TỔNG KM', '${totalKm.toStringAsFixed(1)} km', AppTheme.primaryNeon),
                        Container(width: 1, height: 40, color: AppTheme.divider),
                        _buildSummaryStat('BUỔI CHẠY', '${filteredSessions.length}', AppTheme.secondaryNeon),
                        Container(width: 1, height: 40, color: AppTheme.divider),
                        _buildSummaryStat('THỜI GIAN', '${hours}h ${minutes}p', AppTheme.textPrimary),
                      ],
                    ),
                  ),
                ),
              ),

              // ==========================================
              // 3. DANH SÁCH BUỔI CHẠY HOẶC EMPTY STATE
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
                          _filterType == HistoryDateFilterType.all
                              ? 'Chưa có buổi chạy nào'
                              : 'Không có buổi chạy nào trong khoảng ngày này',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterType == HistoryDateFilterType.all
                              ? 'Vuốt xuống để tải lại hoặc bấm "Bắt đầu chạy"!'
                              : 'Hãy chọn khoảng ngày khác hoặc bấm "Tất cả"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        if (_filterType != HistoryDateFilterType.all) ...[
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
                            onPressed: () {
                              setState(() {
                                _filterType = HistoryDateFilterType.all;
                                _selectedCustomRange = null;
                                _displayedCount = _pageSize;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                // Danh sách các buổi chạy có phân trang (15 items / lần)
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNeon : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNeon : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFilterChip() {
    final isSelected = (_filterType == HistoryDateFilterType.custom);

    return InkWell(
      onTap: _openCustomDateRangePicker,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryNeon : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryNeon : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'TÙY CHỌN',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

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

    // Tên buổi chạy
    final sessionName = session.notes.trim().isNotEmpty
        ? session.notes.trim()
        : 'Buổi chạy ${DateFormat('dd/MM/yyyy').format(session.startTime)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
              // Header: Tên người chạy + Cự ly
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
                          Text(
                            dateFormat.format(session.startTime),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              // Tên buổi chạy
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 16, color: AppTheme.secondaryNeon),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sessionName,
                      style: const TextStyle(
                        fontSize: 13.5,
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
              // Bảng 4 thông số ngắn gọn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCardStatItem('THỜI GIAN', session.formattedDuration),
                  _buildCardStatItem('PACE', '${session.pace} /km', color: AppTheme.secondaryNeon),
                  _buildCardStatItem('CALO', '${session.calories} kcal', color: AppTheme.primaryNeon),
                  _buildCardStatItem('TỐC ĐỘ', '${session.formattedAvgSpeed} km/h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStatItem(String label, String value, {Color color = AppTheme.textPrimary}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
