import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class DailyAttendancePage extends StatefulWidget {
  @override
  _DailyAttendancePageState createState() => _DailyAttendancePageState();
}

class _DailyAttendancePageState extends State<DailyAttendancePage> with SingleTickerProviderStateMixin {
  final storage = GetStorage();
  List<dynamic> attendanceSummary = [];
  List<dynamic> filteredSummary = [];
  Map<String, dynamic>? monthlySummary;
  Map<String, dynamic>? dailyBreakdown;
  bool isLoading = true;

  // Default: start of current month → today
  late DateTimeRange? selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  static const _bg = Color(0xFFFAFAFB);
  static const _card = Color(0xFFFFFFFF);
  static const _black = Color(0xFF000000);
  static const _green = Color(0xFF059669);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFD97706);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);
  static const _orange = Color(0xFFF97316);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _shimmerBase = Color(0xFFEEEEEE);
  static const _shimmerHighlight = Color(0xFFF5F5F5);

  // ── Shimmer animation ─────────────────────────────────────────────────────
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    loadAttendanceSummary();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _getAttendanceStatus(bool hasCheckOut, String date) {
    if (hasCheckOut) {
      return 'Complete';
    }

    // No check-out found, determine if active or partial incomplete
    final recordDate = DateTime.parse(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoffTime = DateTime(now.year, now.month, now.day, 18, 0, 0);

    // If not today, it's partial incomplete
    if (recordDate.isBefore(today) || recordDate.isAfter(today)) {
      return 'Partial Incomplete';
    }

    // If today and before 18:00, it's active
    if (now.isBefore(cutoffTime)) {
      return 'Active';
    }

    // Today but after 18:00, partial incomplete
    return 'Partial Incomplete';
  }

  String _getDayType(String date) {
    // First check if we have payroll data for this specific day
    final dailyData = _getDailyDataForDate(date);
    if (dailyData != null) {
      // Use the day_type from payroll API if available
      final dayType = dailyData['day_type'] as String?;
      if (dayType != null) {
        return dayType;
      }
    }

    // Fallback to basic day detection if no payroll data
    final dateObj = DateTime.parse(date);
    final dayOfWeek = dateObj.weekday;

    // Sunday = 7 in DateTime.weekday (Monday = 1)
    if (dayOfWeek == 7) {
      return 'Sunday';
    }

    // Saturday = 6
    if (dayOfWeek == 6) {
      return 'Saturday';
    }

    // Monday to Friday are weekdays
    return 'Weekday';
  }

  Color _getDayTypeColor(String dayType) {
    switch (dayType) {
      case 'Sunday':
        return Colors.red.withOpacity(0.1);
      case 'Saturday':
        return Colors.blue.withOpacity(0.1);
      case 'Holiday':
        return Colors.orange.withOpacity(0.1);
      case 'Weekday':
      default:
        return Colors.green.withOpacity(0.1);
    }
  }

  Color _getDayTypeTextColor(String dayType) {
    switch (dayType) {
      case 'Sunday':
        return Colors.red;
      case 'Saturday':
        return Colors.blue;
      case 'Holiday':
        return Colors.orange;
      case 'Weekday':
      default:
        return Colors.green;
    }
  }

  String _getDayTypeDisplay(String dayType, String? holidayName) {
    if (dayType == 'Holiday' && holidayName != null) {
      return holidayName;
    }
    return dayType;
  }

  String _formatDoubleOT(String doubleOT) {
    // Parse the double OT value and show the calculation
    // e.g., "2× 2h = 4h" or "2× 30m = 1h"
    try {
      // Extract hours and minutes from the input string
      final parts = doubleOT.split(' ');
      int hours = 0;
      int minutes = 0;

      for (final part in parts) {
        if (part.endsWith('h')) {
          hours = int.parse(part.replaceAll('h', ''));
        } else if (part.endsWith('m')) {
          minutes = int.parse(part.replaceAll('m', ''));
        }
      }

      // Calculate total (2×)
      final totalMinutes = (hours * 60 + minutes) * 2;
      final totalHours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;

      String totalStr = '';
      if (totalHours > 0 && remainingMinutes > 0) {
        totalStr = '${totalHours}h ${remainingMinutes}m';
      } else if (totalHours > 0) {
        totalStr = '${totalHours}h';
      } else {
        totalStr = '${remainingMinutes}m';
      }

      // Show original and calculated: "2× 2h = 4h"
      return '2× $doubleOT = $totalStr';
    } catch (e) {
      // Fallback to original value if parsing fails
      return doubleOT;
    }
  }

  String calculateOT(String? duration) {
    if (duration == null || duration.isEmpty || duration == 'N/A') {
      print('❌ calculateOT - Invalid duration: $duration');
      return '';
    }

    print('🔢 calculateOT - Input duration: "$duration"');

    // Parse duration string like "8h 30m", "10h 15m", where value and unit are combined
    int totalMinutes = 0;
    final parts = duration
        .toLowerCase()
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    print('🔢 calculateOT - Parsed parts: $parts');

    for (final part in parts) {
      // Extract value and unit from combined format like "12h" or "30m"
      String valueStr = '';
      String unit = '';

      for (int i = 0; i < part.length; i++) {
        final char = part[i];
        if (char.contains(RegExp(r'[0-9]'))) {
          valueStr += char;
        } else {
          unit = part.substring(i);
          break;
        }
      }

      final value = int.tryParse(valueStr) ?? 0;

      if (unit.startsWith('h')) {
        totalMinutes += value * 60;
        print('🔢 calculateOT - Added ${value * 60} minutes for ${value}h');
      } else if (unit.startsWith('m')) {
        totalMinutes += value;
        print('🔢 calculateOT - Added $value minutes for ${value}m');
      }

      print(
        '🔢 calculateOT - Processed: "$part" → value: $value, unit: "$unit"',
      );
    }

    print('🔢 calculateOT - Total minutes: $totalMinutes');

    // Calculate overtime (anything beyond 9 hours = 540 minutes)
    final otMinutes = totalMinutes - 540;
    print('🔢 calculateOT - OT minutes: $otMinutes (540 standard minutes)');

    if (otMinutes <= 0) {
      print('❌ calculateOT - No OT (otMinutes: $otMinutes <= 0)');
      return '';
    }

    // Format OT time
    final hours = otMinutes ~/ 60;
    final minutes = otMinutes % 60;
    final result = hours > 0
        ? (minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h')
        : '${minutes}m';

    print('✅ calculateOT - Result: "$result"');
    return result;
  }

  /// Called after data loads — applies the default date range.
  void _applyDefaultFilter() {
    _applyFilter();
  }

  Future<void> loadAttendanceSummary() async {
    setState(() => isLoading = true);
    try {
      final userData = storage.read('user');
      if (userData != null) {
        // Load both current attendance summary and payroll data
        final summary = await ApiService.getAttendanceSummary(userData['id']);

        // Also fetch payroll data for detailed breakdown
        final now = DateTime.now();
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        try {
          final monthlyData = await ApiService.getMonthlySummary(
            userData['id'],
            yearMonth: yearMonth,
          );

          final dailyData = await ApiService.getDailyBreakdown(
            userData['id'],
            yearMonth: yearMonth,
          );

          if (mounted) {
            setState(() {
              attendanceSummary = summary;
              monthlySummary = monthlyData;
              dailyBreakdown = dailyData;
              filteredSummary = List.from(summary);
              isLoading = false;
            });
            // Apply the default (or current) date range after data is loaded
            _applyDefaultFilter();
          }
        } catch (e) {
          print('Failed to load payroll data: $e');
          // Fallback to basic attendance summary
          if (mounted) {
            setState(() {
              attendanceSummary = summary;
              filteredSummary = List.from(summary);
              isLoading = false;
            });
            _applyDefaultFilter();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load attendance records',
        backgroundColor: _red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  void _applyFilter() {
    if (selectedDateRange != null) {
      filteredSummary = attendanceSummary.where((day) {
        final dayDate = DateTime.parse(day['date']);
        return !dayDate.isBefore(selectedDateRange!.start) &&
            !dayDate.isAfter(selectedDateRange!.end);
      }).toList();
    } else {
      filteredSummary = List.from(attendanceSummary);
    }
    setState(() {});
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: _black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDateRange = picked);
      _applyFilter();
    }
  }

  void _clearFilters() {
    setState(() => selectedDateRange = null);
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
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
              'Attendance History',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedDateRange != null
                        ? _black.withOpacity(0.08)
                        : _textPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: selectedDateRange != null
                        ? Border.all(color: _black.withOpacity(0.3))
                        : null,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: selectedDateRange != null ? _black : _textPrimary,
                  ),
                ),
                onPressed: _selectDateRange,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: isLoading
            ? _buildShimmer()
            : RefreshIndicator(
                onRefresh: loadAttendanceSummary,
                color: _black,
                backgroundColor: _card,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 16),

                            if (selectedDateRange != null)
                              _buildActiveFilterChip(),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDateRange != null
                                      ? 'FILTERED RESULTS'
                                      : 'ALL RECORDS',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textSecondary,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                Text(
                                  '${filteredSummary.length} days',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    filteredSummary.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  12,
                                ),
                                child: _buildDayCard(filteredSummary[i]),
                              ),
                              childCount: filteredSummary.length,
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
        itemCount: 6,
        itemBuilder: (_, i) => _shimmerDaySection(),
      ),
    );
  }

  Widget _shimmerDaySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(width: 48, height: 48, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 100, height: 16, radius: 6),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 80, height: 12, radius: 6),
                  ],
                ),
              ),
              _shimmerBox(width: 60, height: 24, radius: 12),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 60, radius: 12)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 60, radius: 12)),
            ],
          ),
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

  Widget _buildStatsRow() {
    final totalDays = filteredSummary.length;
    final completeDays = filteredSummary.where((d) {
      final checkOut = d['check_out'];
      return checkOut != null &&
          checkOut['time'] != null &&
          checkOut['time'].toString().isNotEmpty;
    }).length;

    // Partial includes both "Partial Incomplete" and "Active"
    final partialDays = totalDays - completeDays;

    // Get payroll data if available
    final attendance =
        monthlySummary?['attendance'] as Map<String, dynamic>? ?? {};
    final formatted =
        monthlySummary?['formatted'] as Map<String, dynamic>? ?? {};

    final totalRegular = formatted['total_regular'] ?? '0h 0m';
    final totalOT = formatted['total_overtime'] ?? '0h 0m';
    final daysPresent = attendance['total_days_present'] ?? totalDays;
    final completeDaysPayroll =
        attendance['total_complete_days'] ?? completeDays;

    return Column(
      children: [
        // Payroll Summary Row (if available)
        if (monthlySummary != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  label: 'Regular Hours',
                  value: totalRegular,
                  icon: Icons.schedule_rounded,
                  color: _green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  label: 'Total OT',
                  value: totalOT,
                  icon: Icons.access_time_filled,
                  color: _purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  label: 'Days Present',
                  value: daysPresent.toString(),
                  icon: Icons.calendar_today_rounded,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  label: 'Complete Days',
                  value: completeDaysPayroll.toString(),
                  icon: Icons.check_circle_rounded,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Original Stats Row
        Row(
          children: [
            Expanded(
              child: _buildStatChip(
                label: 'Total Days',
                value: totalDays.toString(),
                icon: Icons.calendar_today_rounded,
                color: _black,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatChip(
                label: 'Partial',
                value: partialDays.toString(),
                icon: Icons.pending_outlined,
                color: _amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _black.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: _black),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('d MMM').format(selectedDateRange!.start)} – ${DateFormat('d MMM y').format(selectedDateRange!.end)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearFilters,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(Map<dynamic, dynamic> day) {
    final date = DateTime.parse(day['date']);
    final isToday =
        DateFormat('yyyy-MM-dd').format(DateTime.now()) == day['date'];
    final checkIn = day['check_in'];
    final checkOut = day['check_out'];
    final hasCheckOut =
        checkOut != null &&
        checkOut['time'] != null &&
        checkOut['time'].toString().isNotEmpty;
    final duration = day['duration'] ?? '';

    // Get payroll data for this specific day
    final dayType = _getDayType(day['date']);
    final dailyData = _getDailyDataForDate(day['date']);
    final formatted = dailyData?['formatted'] as Map<String, dynamic>? ?? {};
    final holidayName = dailyData?['holiday_name'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? _black.withOpacity(0.3) : _border,
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? _black.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: isToday
                  ? _black.withOpacity(0.04)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                // Calendar date block
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? _black : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isToday ? Colors.white : _black,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? Colors.white.withOpacity(0.8)
                              : _black.withOpacity(0.7),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormat('EEEE').format(date),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${day['total_checkins'] ?? 0} check-in${(day['total_checkins'] ?? 0) == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Day type indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getDayTypeColor(dayType),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getDayTypeDisplay(dayType, holidayName),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getDayTypeTextColor(dayType),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _getAttendanceStatus(hasCheckOut, day['date']) ==
                            'Complete'
                        ? _green.withOpacity(0.08)
                        : _amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _getAttendanceStatus(hasCheckOut, day['date']) ==
                              'Complete'
                          ? _green.withOpacity(0.25)
                          : _amber.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    _getAttendanceStatus(hasCheckOut, day['date']),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          _getAttendanceStatus(hasCheckOut, day['date']) ==
                              'Complete'
                          ? _green
                          : _amber,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Times row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildInOutCell(
                    label: 'Check In',
                    time: checkIn?['time'],
                    image: checkIn?['image'],
                    lat: checkIn?['lat']?.toString(),
                    lang: checkIn?['lang']?.toString(),
                    icon: Icons.login_rounded,
                    color: _green,
                    date: day['date'],
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: _border,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _buildInOutCell(
                    label: 'Check Out',
                    time: checkOut?['time'],
                    image: checkOut?['image'],
                    lat: checkOut?['lat']?.toString(),
                    lang: checkOut?['lang']?.toString(),
                    icon: Icons.logout_rounded,
                    color: _red,
                    date: day['date'],
                  ),
                ),
                if (hasCheckOut && duration.isNotEmpty) ...[
                  Container(
                    width: 1,
                    height: 60,
                    color: _border,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _buildInOutCell(
                      label: 'Duration',
                      time: duration,
                      image: null,
                      icon: Icons.schedule_rounded,
                      color: _black,
                      date: day['date'],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Enhanced OT breakdown section
          if (hasCheckOut && dailyData != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: _border),
                  const SizedBox(height: 12),

                  // Regular hours and total OT
                  Row(
                    children: [
                      Expanded(
                        child: _buildOTCell(
                          label: 'Regular',
                          value: formatted['regular'] ?? '0h 0m',
                          color: _green,
                          icon: Icons.work_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOTCell(
                          label: 'Total OT',
                          value: formatted['total_overtime'] ?? '0h 0m',
                          color: _purple,
                          icon: Icons.access_time_filled,
                        ),
                      ),
                    ],
                  ),

                  // Detailed OT breakdown (only show if there's OT)
                  if ((formatted['weekday_ot'] ?? '0h 0m') != '0h 0m' ||
                      (formatted['sunday_ot'] ?? '0h 0m') != '0h 0m' ||
                      (formatted['double_ot'] ?? '0h 0m') != '0h 0m') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OT Breakdown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if ((formatted['weekday_ot'] ?? '0h 0m') !=
                                  '0h 0m') ...[
                                Expanded(
                                  child: _buildOTCell(
                                    label: 'Normal OT',
                                    value: formatted['weekday_ot'] ?? '0h 0m',
                                    color: _blue,
                                    icon: Icons.work_outline,
                                  ),
                                ),
                              ],
                              if ((formatted['sunday_ot'] ?? '0h 0m') !=
                                  '0h 0m') ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildOTCell(
                                    label: 'Sunday OT',
                                    value: formatted['sunday_ot'] ?? '0h 0m',
                                    color: _orange,
                                    icon: Icons.weekend_outlined,
                                  ),
                                ),
                              ],
                              if ((formatted['double_ot'] ?? '0h 0m') !=
                                  '0h 0m') ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildOTCell(
                                    label: 'Double OT',
                                    value: _formatDoubleOT(
                                      formatted['double_ot'] ?? '0h 0m',
                                    ),
                                    color: _purple,
                                    icon: Icons.star_outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? _getDailyDataForDate(String date) {
    if (dailyBreakdown == null) return null;

    final days = dailyBreakdown!['days'] as List<dynamic>? ?? [];
    try {
      return days.firstWhere((day) => day['date'] == date, orElse: () => null)
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Widget _buildOTCell({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInOutCell({
    required String label,
    required String? time,
    required String? image,
    required IconData icon,
    required Color color,
    required String date,
    String? lat,
    String? lang,
  }) {
    final hasTime = time != null && time.isNotEmpty;
    final imageUrl = image != null ? '${ApiService.baseUrl}$image' : null;
    final isDuration = label == 'Duration';
    final hasLoc =
        !isDuration &&
        lat != null &&
        lat.isNotEmpty &&
        lang != null &&
        lang.isNotEmpty;

    return GestureDetector(
      onTap: (!isDuration && imageUrl != null)
          ? () => Get.to(
              () => _ImagePreviewPage(
                url: imageUrl,
                label: label == 'Check In' ? 'IN' : 'OUT',
                time: time!,
                date: date,
              ),
              transition: Transition.fadeIn,
            )
          : null,
      child: Column(
        children: [
          if (!isDuration && imageUrl != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                placeholder: (_, __) => Container(color: color.withOpacity(0.1)),
                errorWidget: (_, __, ___) =>
                    Icon(icon, color: color, size: 20),
              ),
            )
          else
            Icon(
              icon,
              color: hasTime ? color : const Color(0xFFCBD5E1),
              size: 22,
            ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasTime ? _formatTime(time!) : '--:--',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasTime ? color : const Color(0xFFCBD5E1),
            ),
          ),
          if (!isDuration && imageUrl != null)
            const Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 9,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 2),
                Text(
                  'view',
                  style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),

          // Map button — only when location recorded
          if (hasTime && hasLoc) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openMap(lat, lang, label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _black.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded, size: 10, color: _black),
                    SizedBox(width: 3),
                    Text(
                      'Map',
                      style: TextStyle(
                        fontSize: 9,
                        color: _black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMap(String? lat, String? lang, String label) async {
    if (lat == null || lang == null || lat.isEmpty || lang.isEmpty) {
      Get.snackbar(
        'No Location',
        'Location not available for this $label',
        backgroundColor: const Color(0xFFD97706),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
        icon: const Icon(Icons.location_off_rounded, color: Colors.white),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lang',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not open Google Maps',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  String _formatTime(String t) {
    try {
      if (t.contains(':') && t.split(':').length >= 2) {
        final parts = t.split(':');
        return '${parts[0]}:${parts[1]}'; // HH:mm format
      }
    } catch (_) {}
    return t;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 48, color: _black),
          ),
          const SizedBox(height: 20),
          Text(
            selectedDateRange != null
                ? 'No records in selected range'
                : 'No attendance records yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedDateRange != null
                ? 'Try a different date range'
                : 'Start checking in to see your history',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
          if (selectedDateRange != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_rounded, size: 16, color: _black),
              label: const Text(
                'Clear filter',
                style: TextStyle(color: _black, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen zoomable image preview
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePreviewPage extends StatelessWidget {
  final String url;
  final String label; // 'IN' or 'OUT'
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
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
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  progressIndicatorBuilder: (ctx, url, progress) {
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.progress,
                        color: const Color(0xFF2563EB),
                      ),
                    );
                  },
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
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        (label == 'IN'
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626))
                            .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    label == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                    color: label == 'IN'
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
