import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

// ─── Feed item types ──────────────────────────────────────────────────────────
abstract class _FeedItem {}

class _DayHeader extends _FeedItem {
  final String date;
  final int count;
  final bool isToday;
  _DayHeader({required this.date, required this.count, required this.isToday});
}

class _UserRecord extends _FeedItem {
  final Map<dynamic, dynamic> user;
  final String date;
  _UserRecord({required this.user, required this.date});
}

// ─── Main page ────────────────────────────────────────────────────────────────
class AdminAttendancePage extends StatefulWidget {
  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage>
    with SingleTickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<dynamic> _rawData = [];
  List<_FeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 500; // records per page
  Map<String, dynamic>? _paginationInfo;

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false; // debounce-loading indicator
  Timer? _debounce;

  // ── Date filter ───────────────────────────────────────────────────────────
  static DateTimeRange _defaultRange() => DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  late DateTimeRange selectedRange = _defaultRange();

  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();

  // ── Shimmer animation ─────────────────────────────────────────────────────
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF8F9FA);
  static const _card = Color(0xFFFFFFFF);
  static const _black = Color(0xFF2C2C2C); // Charcoal
  static const _green = Color(0xFF059669);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFD97706);
  static const _purple = Color(0xFF7C3AED);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE9ECEF);
  static const _shimmerBase = Color(0xFFEEEEEE);
  static const _shimmerHighlight = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Infinite scroll ───────────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _load(isLoadMore: true);
      }
    }
  }

  // ── Search with 500 ms debounce ───────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchQuery = query.trim();
    });
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _load(); // fresh load with new search
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
    _load();
  }

  // ── Load data ─────────────────────────────────────────────────────────────
  Future<void> _load({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _rawData.clear();
        _feedItems.clear();
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await ApiService.getAdminAttendance(
        startDate: DateFormat('yyyy-MM-dd').format(selectedRange.start),
        endDate: DateFormat('yyyy-MM-dd').format(selectedRange.end),
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (!mounted) return;
      setState(() {
        List<dynamic> newDays = [];
        if (result is Map<String, dynamic>) {
          newDays = result['data'] ?? [];
          _paginationInfo = result['pagination'];
          _hasMore = _paginationInfo?['has_more'] ?? false;
        } else if (result is List) {
          newDays = result;
          _hasMore = false;
        }

        if (isLoadMore) {
          _rawData.addAll(newDays);
        } else {
          _rawData = newDays;
        }

        _buildFeedItems();
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _isSearching = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load attendance: $e',
        backgroundColor: _red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  /// Flatten grouped-by-day data → flat feed list of headers + records.
  void _buildFeedItems() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final items = <_FeedItem>[];
    for (final day in _rawData) {
      final date = day['date'] as String;
      final users = day['users'] as List;
      items.add(
        _DayHeader(date: date, count: users.length, isToday: date == today),
      );
      for (final u in users) {
        items.add(_UserRecord(user: u as Map<dynamic, dynamic>, date: date));
      }
    }
    _feedItems = items;
  }

  // ── Date filter ───────────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
      _load();
    }
  }

  void _resetToCurrentMonth() {
    setState(() => selectedRange = _defaultRange());
    _load();
  }

  // ── Computed stats ────────────────────────────────────────────────────────
  int get _totalDaysLoaded => _rawData.length;

  int get _totalDaysOverall =>
      _paginationInfo?['total_days'] ?? _totalDaysLoaded;

  int get _totalRecordsLoaded {
    int c = 0;
    for (final d in _rawData) c += (d['users'] as List).length;
    return c;
  }

  int get _totalRecordsOverall =>
      _paginationInfo?['total_records'] ?? _totalRecordsLoaded;

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(String t) {
    try {
      final dt = DateFormat('HH:mm:ss').parse(t.length == 5 ? '$t:00' : t);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return t;
    }
  }

  bool _isTodayActiveShift(String date) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return date == today && DateTime.now().hour < 20;
  }

  String _calcOT(String? duration, [bool isEligible = true]) {
    if (!isEligible) return '';
    if (duration == null || duration.isEmpty) return '';
    int totalMin = 0;
    final parts = duration
        .toLowerCase()
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty);
    for (final p in parts) {
      String valStr = '';
      String unit = '';
      for (int i = 0; i < p.length; i++) {
        if (p[i].contains(RegExp(r'[0-9]'))) {
          valStr += p[i];
        } else {
          unit = p.substring(i);
          break;
        }
      }
      final v = int.tryParse(valStr) ?? 0;
      if (unit.startsWith('h'))
        totalMin += v * 60;
      else if (unit.startsWith('m'))
        totalMin += v;
    }
    final ot = totalMin - 540;
    if (ot <= 0) return '';
    final h = ot ~/ 60;
    final m = ot % 60;
    return h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: ElectricRefreshIndicator(
        onRefresh: () => _load(),
        color: _black,
        backgroundColor: Colors.white,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [_buildAppBar()],
          body: _isLoading ? _buildShimmer() : _buildFeed(),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: _bg,
      elevation: 0,
      toolbarHeight: 56,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _textPrimary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: _textPrimary,
          ),
        ),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Attendance',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: _textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // Date filter button
        GestureDetector(
          onTap: _pickDateRange,
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _black.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _black.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: _textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${DateFormat('d MMM').format(selectedRange.start)} – ${DateFormat('d MMM').format(selectedRange.end)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: _buildSearchBar(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      color: _bg,
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: _textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: _card,
          hintText: 'Search employee name or role…',
          hintStyle: TextStyle(
            color: _textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: _searchQuery.isNotEmpty ? _black : _textSecondary,
            ),
          ),
          suffixIcon: _buildSearchSuffix(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _black.withOpacity(0.4), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget? _buildSearchSuffix() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _black),
        ),
      );
    }
    if (_searchQuery.isNotEmpty) {
      return GestureDetector(
        onTap: _clearSearch,
        child: const Icon(Icons.close_rounded, color: _textSecondary, size: 18),
      );
    }
    return null;
  }

  // ── Shimmer skeleton ─────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.only(top: 12),
        itemCount: 6,
        itemBuilder: (_, i) => _shimmerDaySection(),
      ),
    );
  }

  Widget _shimmerDaySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header skeleton
          _shimmerBox(height: 18, width: 120, radius: 8),
          const SizedBox(height: 12),
          // 3 record skeletons
          ...List.generate(3, (_) => _shimmerRecord()),
        ],
      ),
    );
  }

  Widget _shimmerRecord() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _shimmerBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 12, width: 140, radius: 6),
                const SizedBox(height: 6),
                _shimmerBox(height: 10, width: 90, radius: 5),
              ],
            ),
          ),
          _shimmerBox(height: 24, width: 70, radius: 12),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    double? width,
    required double radius,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [_shimmerBase, _shimmerHighlight, _shimmerBase],
            stops: [
              (_shimmerAnim.value - 1).clamp(0.0, 1.0),
              (_shimmerAnim.value).clamp(0.0, 1.0),
              (_shimmerAnim.value + 1).clamp(0.0, 1.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feed ──────────────────────────────────────────────────────────────────
  Widget _buildFeed() {
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
          // Stats bar
          SliverToBoxAdapter(child: _buildStatsBar()),

          // Search result label
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(child: _buildSearchLabel()),

          // Empty state
          if (_feedItems.isEmpty) SliverFillRemaining(child: _buildEmpty()),

          // Main feed — FLAT virtualized list
          if (_feedItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildItem(_feedItems[i]),
                  childCount: _feedItems.length,
                ),
              ),
            ),

          // Load more indicator
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _black,
                    ),
                  ),
                ),
              ),
            ),

          // End of data
          if (!_hasMore && _feedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 32, height: 1, color: _border),
                      const SizedBox(width: 12),
                      Text(
                        'All records loaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 32, height: 1, color: _border),
                    ],
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      );
  }

  Widget _buildItem(_FeedItem item) {
    if (item is _DayHeader) return _buildDayHeader(item);
    if (item is _UserRecord) return _buildUserRow(item);
    return const SizedBox.shrink();
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statPill(
            label: 'Days',
            value: _totalDaysOverall.toString(),
            icon: Icons.calendar_today_rounded,
            color: _black,
          ),
          const SizedBox(width: 8),
          _statPill(
            label: 'Loaded',
            value: '${_totalDaysLoaded}d',
            icon: Icons.download_rounded,
            color: _textSecondary,
          ),
          const SizedBox(width: 8),
          _statPill(
            label: 'Records',
            value: _totalRecordsOverall > _totalRecordsLoaded
                ? '$_totalRecordsLoaded/$_totalRecordsOverall'
                : '$_totalRecordsLoaded',
            icon: Icons.receipt_long_rounded,
            color: _green,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 8),
            _statPill(
              label: 'Filtered',
              value: _searchQuery.length > 8
                  ? '"${_searchQuery.substring(0, 8)}…"'
                  : '"$_searchQuery"',
              icon: Icons.filter_alt_rounded,
              color: _purple,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 13, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            'Results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearSearch,
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                color: _black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Day header (sticky-style separator) ───────────────────────────────────
  Widget _buildDayHeader(_DayHeader h) {
    final date = DateTime.parse(h.date);
    final dayName = DateFormat('EEEE').format(date);
    final dayNum = DateFormat('d').format(date);
    final monthYear = DateFormat('MMMM yyyy').format(date);
    final isSunday = date.weekday == DateTime.sunday;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Day number badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: h.isToday
                  ? _black
                  : (isSunday
                        ? _red.withOpacity(0.08)
                        : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(12),
              border: h.isToday
                  ? null
                  : Border.all(
                      color: isSunday
                          ? _red.withOpacity(0.2)
                          : _border.withOpacity(0.8),
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNum,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: h.isToday
                        ? Colors.white
                        : (isSunday ? _red : _black),
                    height: 1,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: h.isToday
                        ? Colors.white.withOpacity(0.7)
                        : (isSunday
                              ? _red.withOpacity(0.7)
                              : _black.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Day info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: h.isToday
                            ? _black
                            : (isSunday ? _red : _textPrimary),
                      ),
                    ),
                    if (h.isToday) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                    if (isSunday && !h.isToday) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _red.withOpacity(0.2)),
                        ),
                        child: Text(
                          'SUNDAY',
                          style: TextStyle(
                            fontSize: 9,
                            color: _red,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  monthYear,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Employee count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _textPrimary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${h.count} emp',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User record row ───────────────────────────────────────────────────────
  Widget _buildUserRow(_UserRecord r) {
    final u = r.user;
    final date = r.date;
    final checkIn = u['check_in'];
    final checkOut = u['check_out'];
    final duration = u['duration'] as String?;
    final hasOut = checkOut != null && checkOut['time'] != null;
    final username = u['username'] as String? ?? 'Unknown';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final otText = _calcOT(duration, u['is_ot_eligible'] ?? true);
    final pfp = u['pfp'] as String?;
    final isOvernight = u['is_overnight'] == true;
    final shiftDate = u['shift_date'] as String?;
    final permissionMinutes = u['permission_minutes'] ?? 0;
    final permissionType = u['permission_type'] as String?;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // ── Top row: avatar · name · chips ─────────────────────────
              Row(
                children: [
                  // Avatar
                  _buildAvatar(pfp, initial),
                  const SizedBox(width: 10),
                  // Name + role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          u['role'] ?? 'Employee',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration + OT chips
                  _buildDurationChips(
                    duration,
                    otText,
                    hasOut,
                    date,
                    isOvernight: isOvernight,
                    permissionMinutes: permissionMinutes,
                    permissionType: permissionType,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── In / Out row ────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInOutTile(
                        label: 'IN',
                        time: checkIn?['time'] as String?,
                        image: checkIn?['image'] as String?,
                        lat: checkIn?['lat']?.toString(),
                        lng: checkIn?['lang']?.toString(),
                        date: date,
                        color: _green,
                        isNextDay: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInOutTile(
                        label: 'OUT',
                        time: checkOut?['time'] as String?,
                        image: checkOut?['image'] as String?,
                        lat: checkOut?['lat']?.toString(),
                        lng: checkOut?['lang']?.toString(),
                        date: date,
                        color: isOvernight ? Colors.indigo : _red,
                        isNextDay:
                            isOvernight || (checkOut?['is_next_day'] ?? false),
                        shiftDate: shiftDate,
                        iconOverride: isOvernight
                            ? Icons.nightlight_round
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? pfp, String initial) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _black.withOpacity(0.07),
        shape: BoxShape.circle,
        border: Border.all(color: _black.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: pfp != null && pfp.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: '${ApiService.baseUrl}$pfp',
              fit: BoxFit.cover,
              memCacheWidth: 76, // 38 logical × 2x = 76px physical
              memCacheHeight: 76,
              placeholder: (_, __) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _black,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _black,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _black,
                ),
              ),
            ),
    );
  }

  Widget _buildDurationChips(
    String? duration,
    String otText,
    bool hasOut,
    String date, {
    bool isOvernight = false,
    int permissionMinutes = 0,
    String? permissionType,
  }) {
    if (duration != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(duration, _green, Icons.schedule_rounded),
          if (otText.isNotEmpty) ...[
            const SizedBox(width: 5),
            _chip('+$otText OT', _purple, Icons.access_time_filled),
          ],
          if (isOvernight) ...[
            const SizedBox(width: 5),
            _chip('Overnight', Colors.indigo, Icons.nightlight_round),
          ],
          if (permissionMinutes > 0) ...[
            const SizedBox(width: 5),
            _chip(
              '+${permissionMinutes < 60 ? '${permissionMinutes}m' : (permissionMinutes % 60 == 0 ? '${permissionMinutes ~/ 60}h' : '${permissionMinutes ~/ 60}h ${permissionMinutes % 60}m')}',
              _amber,
              Icons.verified_user_rounded,
            ),
          ],
        ],
      );
    } else {
      final isActive = _isTodayActiveShift(date);
      return _chip(
        isActive ? 'Active' : 'Partial',
        isActive ? _green : _amber,
        isActive ? Icons.circle : Icons.warning_amber_rounded,
      );
    }
  }

  Widget _chip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── In / Out tile ─────────────────────────────────────────────────────────
  Widget _buildInOutTile({
    required String label,
    required String? time,
    required String? image,
    required String? lat,
    required String? lng,
    required String date,
    required Color color,
    bool isNextDay = false,
    String? shiftDate,
    IconData? iconOverride,
  }) {
    final hasData = time != null;
    final imageUrl = image != null ? '${ApiService.baseUrl}$image' : null;
    final hasLoc =
        lat != null && lat.isNotEmpty && lng != null && lng.isNotEmpty;

    return GestureDetector(
      onTap: imageUrl != null
          ? () => _openImagePreview(imageUrl, label, time!, date)
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasData ? color.withOpacity(0.04) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasData ? color.withOpacity(0.18) : _border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Thumbnail
                _buildThumbnail(
                  imageUrl,
                  color,
                  label,
                  iconOverride: iconOverride,
                ),
                const SizedBox(width: 8),
                // Time + label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check $label',
                        style: TextStyle(
                          fontSize: 9,
                          color: hasData ? color : _textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasData
                                ? _fmt(time!)
                                : (label == 'OUT'
                                      ? (_isTodayActiveShift(date)
                                            ? 'Active'
                                            : 'Partial')
                                      : '--:--'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: hasData
                                  ? color
                                  : (label == 'OUT'
                                        ? (_isTodayActiveShift(date)
                                              ? _green
                                              : _amber)
                                        : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          if (isNextDay && hasData) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                shiftDate != null
                                    ? '(${DateFormat('MMM d').format(DateTime.parse(shiftDate))})'
                                    : '(next day)',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (imageUrl != null)
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 9,
                              color: _textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'tap photo',
                              style: TextStyle(
                                fontSize: 9,
                                color: _textSecondary.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Map button
            if (hasData && hasLoc) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _openMap(
                  lat,
                  lng,
                  label == 'IN' ? 'Check-In' : 'Check-Out',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _black.withOpacity(0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 10,
                        color: _textSecondary,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'View on Map',
                        style: TextStyle(
                          fontSize: 9,
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Small thumbnail with lazy loading via CachedNetworkImage.
  /// Using [memCacheWidth] = 80px to cap memory usage per thumbnail.
  Widget _buildThumbnail(
    String? imageUrl,
    Color color,
    String label, {
    IconData? iconOverride,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 80,
              memCacheHeight: 80,
              // Fade in instead of jump
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (_, __) => Icon(
                iconOverride ??
                    (label == 'IN'
                        ? Icons.login_rounded
                        : Icons.logout_rounded),
                color: color.withOpacity(0.3),
                size: 16,
              ),
              errorWidget: (_, __, ___) => Icon(
                iconOverride ??
                    (label == 'IN'
                        ? Icons.login_rounded
                        : Icons.logout_rounded),
                color: color.withOpacity(0.4),
                size: 16,
              ),
            )
          : Icon(
              iconOverride ??
                  (label == 'IN' ? Icons.login_rounded : Icons.logout_rounded),
              color: color.withOpacity(0.35),
              size: 16,
            ),
    );
  }

  // ── Image & map actions ───────────────────────────────────────────────────
  void _openImagePreview(String url, String label, String time, String date) {
    Get.to(
      () => _ImagePreviewPage(url: url, label: label, time: time, date: date),
      transition: Transition.fadeIn,
    );
  }

  Future<void> _openMap(String? lat, String? lng, String label) async {
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty) {
      Get.snackbar(
        'No Location',
        'Location unavailable for $label',
        backgroundColor: _amber,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not open Google Maps',
        backgroundColor: _red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    final isFiltered = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.search_off_rounded : Icons.groups_rounded,
              size: 44,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isFiltered
                ? 'No results for "$_searchQuery"'
                : 'No attendance records',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try a different name or role'
                : 'Adjust the date range and retry',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          if (isFiltered)
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded, size: 16, color: _black),
              label: const Text(
                'Clear search',
                style: TextStyle(color: _black, fontWeight: FontWeight.w700),
              ),
            )
          else
            TextButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(
                Icons.date_range_rounded,
                size: 16,
                color: _black,
              ),
              label: const Text(
                'Change date range',
                style: TextStyle(color: _black, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── ApiService extension to support search param ─────────────────────────────
extension AdminAttendanceSearch on ApiService {
  // This extension adds search support to the existing getAdminAttendance
  // without modifying the service; search is handled via query params.
}

// ─── Full-screen image preview ────────────────────────────────────────────────
class _ImagePreviewPage extends StatelessWidget {
  final String url;
  final String label;
  final String time;
  final String date;

  const _ImagePreviewPage({
    required this.url,
    required this.label,
    required this.time,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = () {
      try {
        final dt = DateFormat(
          'HH:mm:ss',
        ).parse(time.length == 5 ? '$time:00' : time);
        return DateFormat('hh:mm:ss a').format(dt);
      } catch (_) {
        return time;
      }
    }();
    final formattedDate = () {
      try {
        return DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(date));
      } catch (_) {
        return date;
      }
    }();
    final inColor = const Color(0xFF059669);
    final outColor = const Color(0xFFDC2626);
    final tcolor = label == 'IN' ? inColor : outColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check $label Photo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white.withOpacity(0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Image unavailable',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom info strip
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tcolor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    label == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                    color: tcolor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
}
