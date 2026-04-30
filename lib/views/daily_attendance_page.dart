import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class DailyAttendancePage extends StatefulWidget {
  final String? targetDate; // Format: YYYY-MM-DD for highlighting/scrolling
  const DailyAttendancePage({Key? key, this.targetDate}) : super(key: key);

  @override
  _DailyAttendancePageState createState() => _DailyAttendancePageState();
}

class _DailyAttendancePageState extends State<DailyAttendancePage>
    with TickerProviderStateMixin {
  final storage = GetStorage();
  List<dynamic> attendanceSummary = [];
  List<dynamic> filteredSummary = [];
  Map<String, dynamic>? monthlySummary;
  Map<String, dynamic>? dailyBreakdown;
  bool isLoading = true;
  final GlobalKey _targetKey = GlobalKey();

  // Expansion state for OT details
  Set<String> _expandedDates = {};

  // Highlight animation
  late AnimationController _blinkCtrl;
  bool _highlightVisible = true;
  Timer? _highlightTimer;

  // Default: start of current month → today
  late DateTimeRange? selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);

  // Subtle accent colors
  static const Color _softGreen = Color(0xFF2E7D32);
  static const Color _softRed = Color(0xFFC62828);
  static const Color _softAmber = Color(0xFFD97706);
  static const Color _softBlue = Color(0xFF1976D2);
  static const Color _softPurple = Color(0xFF7B1FA2);
  static const Color _softOrange = Color(0xFFE65100);

  // Map theme variables for consistency
  static const _bg = _offWhite;
  static const _card = _pureWhite;
  static const _border = _lightGray;

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
    _shimmerAnim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350), // Throb faster
    )..repeat(reverse: true);

    if (widget.targetDate != null) {
      _highlightTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() => _highlightVisible = false);
        }
      });
    }

    loadAttendanceSummary();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _blinkCtrl.dispose();
    _highlightTimer?.cancel();
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

  Color _getDayTypeTextColor(String dayType) {
    switch (dayType) {
      case 'Sunday':
        return _softRed;
      case 'Saturday':
        return _softBlue;
      case 'Holiday':
        return _softPurple;
      case 'Weekday':
      default:
        return _softGreen;
    }
  }

  String _getDayTypeDisplay(String dayType, String? holidayName) {
    if (dayType == 'Holiday' && holidayName != null) {
      return holidayName;
    }
    return dayType;
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

  Future<void> loadAttendanceSummary() async {
    setState(() => isLoading = true);
    try {
      final userData = storage.read('user');
      if (userData != null) {
        final summary = await ApiService.getAttendanceSummary(userData['id']);
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
              isLoading = false;

              if (selectedDateRange != null) {
                filteredSummary = attendanceSummary.where((day) {
                  final dayDate = DateTime.parse(day['date']);
                  return !dayDate.isBefore(selectedDateRange!.start) &&
                      !dayDate.isAfter(selectedDateRange!.end);
                }).toList();
              } else {
                filteredSummary = List.from(attendanceSummary);
              }
            });

            if (widget.targetDate != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Increased delay to ensure all dynamic heights (including bottom spacer) are included
                Future.delayed(const Duration(milliseconds: 1300), () {
                  if (_targetKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _targetKey.currentContext!,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      alignment: 0.1,
                    );

                    Future.delayed(const Duration(milliseconds: 820), () {
                      if (_targetKey.currentContext != null) {
                        Scrollable.ensureVisible(
                          _targetKey.currentContext!,
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutCubic,
                          alignment: 0.3,
                        );
                      }
                    });
                  }
                });
              });
            }
          }
        } catch (e) {
          print('Failed to load payroll data: $e');
          if (mounted) {
            setState(() {
              attendanceSummary = summary;
              filteredSummary = List.from(summary);
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load attendance records',
        backgroundColor: _softRed,
        colorText: _pureWhite,
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
              primary: _charcoal,
              onPrimary: _pureWhite,
              surface: _pureWhite,
              onSurface: _charcoal,
            ),
            dialogBackgroundColor: _pureWhite,
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
      body: ElectricRefreshIndicator(
        onRefresh: loadAttendanceSummary,
        color: _charcoal,
        backgroundColor: _card,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: _bg,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _charcoal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: _charcoal,
                  ),
                ),
                onPressed: () => Get.back(),
              ),
              title: const Text(
                'Attendance History',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _charcoal,
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedDateRange != null
                          ? _charcoal.withOpacity(0.08)
                          : _charcoal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: selectedDateRange != null
                          ? Border.all(color: _charcoal.withOpacity(0.3))
                          : null,
                    ),
                    child: Icon(Icons.tune_rounded, size: 18, color: _charcoal),
                  ),
                  onPressed: _selectDateRange,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
          body: isLoading
              ? _buildShimmer()
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 10000,
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
                                    color: _mediumGray,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                Text(
                                  '${filteredSummary.length} days',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _charcoal,
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
                                  4,
                                  20,
                                  12,
                                ),
                                child: _buildDayCard(filteredSummary[i]),
                              ),
                              childCount: filteredSummary.length,
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmerBox(width: 50, height: 50, radius: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 120, height: 16, radius: 6),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 90, height: 12, radius: 4),
                  ],
                ),
              ),
              _shimmerBox(width: 70, height: 24, radius: 12),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _lightGray, thickness: 0.5),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 36, radius: 10)),
              const SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 36, radius: 10)),
              const SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 36, radius: 10)),
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
            colors: const [_lightGray, _offWhite, _lightGray],
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

    double _safeNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final totalRegular = formatted['total_regular'] ?? '0h 0m';
    final totalOT = formatted['total_overtime'] ?? '0h 0m';
    final daysPresent = _safeNum(attendance['total_days_present'] ?? totalDays);
    final completeDaysPayroll =
        _safeNum(attendance['total_complete_days'] ?? completeDays);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildMiniStat(
            'Regular',
            totalRegular,
            Icons.timer_outlined,
            _softGreen,
          ),
          _buildMiniStat(
            'Overtime',
            totalOT,
            Icons.auto_awesome_rounded,
            _softPurple,
          ),
          _buildMiniStat(
            'Present',
            '$daysPresent d',
            Icons.calendar_today_rounded,
            _softBlue,
          ),
          _buildMiniStat(
            'Complete',
            '$completeDaysPayroll d',
            Icons.check_circle_outline_rounded,
            _softGreen,
          ),
          _buildMiniStat(
            'Partial',
            '$partialDays d',
            Icons.pending_actions_rounded,
            _softAmber,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: _mediumGray,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _charcoal,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              color: _charcoal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _charcoal.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 14,
                  color: _charcoal,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('d MMM').format(selectedDateRange!.start)} – ${DateFormat('d MMM y').format(selectedDateRange!.end)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearFilters,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _charcoal,
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
    final dateStr = day['date'] as String;
    final date = DateTime.parse(dateStr);
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
    final checkIn = day['check_in'];
    final checkOut = day['check_out'];
    final hasCheckOut =
        checkOut != null &&
        checkOut['time'] != null &&
        checkOut['time'].toString().isNotEmpty;
    final duration = day['duration'] ?? '';

    final dayType = _getDayType(dateStr);
    final dailyData = _getDailyDataForDate(dateStr);
    final formatted = dailyData?['formatted'] as Map<String, dynamic>? ?? {};
    final holidayName = dailyData?['holiday_name'] as String?;
    final isOvernight = dailyData?['is_overnight'] == true;
    final shiftDate = dailyData?['shift_date'] as String?;

    final isTargetMatch =
        widget.targetDate != null && dateStr == widget.targetDate;

    return AnimatedBuilder(
      animation: _blinkCtrl,
      builder: (context, child) {
        final blinkingColor = Color.lerp(
          _softRed,
          _charcoal,
          _blinkCtrl.value,
        )!;
        final isHighlighted = isTargetMatch && _highlightVisible;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          key: isTargetMatch ? _targetKey : null,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHighlighted
                  ? blinkingColor
                  : (isToday ? _charcoal.withOpacity(0.2) : _border),
              width: isHighlighted ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? blinkingColor.withOpacity(0.15)
                    : _pureBlack.withOpacity(0.02),
                blurRadius: isHighlighted ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              child!,
              if (isHighlighted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (context, _) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment(_shimmerAnim.value - 1, -0.5),
                              end: Alignment(_shimmerAnim.value, 0.5),
                              colors: [
                                Colors.white.withOpacity(0),
                                _softRed.withOpacity(0.05),
                                _softRed.withOpacity(0.02),
                                Colors.white.withOpacity(0),
                              ],
                              stops: const [0.35, 0.5, 0.65, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Date + Day Type + Status ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                // Minimal Date Circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isToday ? _charcoal : _offWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: _lightGray, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isToday ? _pureWhite : _charcoal,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isToday
                              ? _pureWhite.withOpacity(0.7)
                              : _mediumGray,
                          letterSpacing: 0.5,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _charcoal,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _charcoal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _pureWhite,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildDayTypeBadge(dayType, holidayName),
                          const SizedBox(width: 8),
                          Text(
                            '• ${day['total_checkins'] ?? 0} logs',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _mediumGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(hasCheckOut, day['date'], isOvernight),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Divider(height: 1, color: _lightGray, thickness: 0.5),
          ),

          // ── Main Times Row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeCell(
                    label: 'IN',
                    time: checkIn?['time'],
                    image: checkIn?['image'],
                    icon: Icons.login_outlined,
                    color: _softGreen,
                    date: day['date'],
                    lat: checkIn?['lat']?.toString(),
                    lang: checkIn?['lang']?.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 70,
                  color: _lightGray,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                Expanded(
                  child: _buildTimeCell(
                    label: 'OUT',
                    time: checkOut?['time'],
                    image: checkOut?['image'],
                    icon: isOvernight
                        ? Icons.nightlight_round
                        : Icons.logout_outlined,
                    color: isOvernight ? Colors.indigo : _softRed,
                    date: day['date'],
                    lat: checkOut?['lat']?.toString(),
                    lang: checkOut?['lang']?.toString(),
                    isNextDay:
                        isOvernight || (checkOut?['is_next_day'] ?? false),
                    shiftDate: shiftDate,
                  ),
                ),
                if (hasCheckOut && duration.isNotEmpty) ...[
                  Container(
                    width: 1,
                    height: 36,
                    color: _lightGray,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  Expanded(
                    child: _buildTimeCell(
                      label: 'TOTAL',
                      time: duration,
                      image: null,
                      icon: Icons.schedule_outlined,
                      color: _charcoal,
                      date: day['date'],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── OT Footer (Expandable) ───────────────────────────────────────
          if (hasCheckOut && dailyData != null)
            _buildExpandableOTFooter(dateStr, formatted),
        ],
      ),
    );
  }

  Widget _buildDayTypeBadge(String dayType, String? holidayName) {
    final color = _getDayTypeTextColor(dayType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Text(
        _getDayTypeDisplay(dayType, holidayName).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool hasCheckOut, String date, bool isOvernight) {
    if (isOvernight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withOpacity(0.1), width: 1),
        ),
        child: const Text(
          '🌙 OVERNIGHT',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.indigo,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final status = _getAttendanceStatus(hasCheckOut, date);
    final isComplete = status == 'Complete';
    final color = isComplete ? _softGreen : _softAmber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimeCell({
    required String label,
    required String? time,
    required String? image,
    required IconData icon,
    required Color color,
    required String date,
    String? lat,
    String? lang,
    bool isNextDay = false,
    String? shiftDate,
  }) {
    final hasTime = time != null && time.isNotEmpty;
    final imageUrl = image != null ? '${ApiService.baseUrl}$image' : null;
    final hasLoc =
        lat != null && lat.isNotEmpty && lang != null && lang.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _mediumGray,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasLoc) ...[
              const SizedBox(width: 4),
              Semantics(
                label: 'Open location for $label in maps',
                button: true,
                child: GestureDetector(
                  onTap: () => _openMap(lat, lang, label),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _charcoal.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      size: 12,
                      color: _charcoal,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (imageUrl != null)
          GestureDetector(
            onTap: () => Get.to(
              () => _ImagePreviewPage(
                url: imageUrl,
                label: label == 'IN' ? 'IN' : 'OUT',
                time: time ?? '',
                date: date,
              ),
              transition: Transition.fadeIn,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _offWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _pureBlack.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 88,
                memCacheHeight: 88,
                placeholder: (_, __) => Container(color: _lightGray),
                errorWidget: (_, __, ___) => Icon(icon, color: color, size: 20),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (hasTime ? color : _mediumGray).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: hasTime ? color : _mediumGray, size: 20),
          ),
        const SizedBox(height: 8),
        Column(
          children: [
            Text(
              hasTime ? _formatTime(time) : '--:--',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: hasTime ? color : _mediumGray,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isNextDay && hasTime) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shiftDate != null
                      ? '(${DateFormat('MMM d').format(DateTime.parse(shiftDate))})'
                      : '(next day)',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildExpandableOTFooter(String date, Map<String, dynamic> formatted) {
    final isExpanded = _expandedDates.contains(date);
    final hasOT = (formatted['total_overtime'] ?? '0h 0m') != '0h 0m';
    if (!hasOT) return const SizedBox.shrink();

    final weekdayOT = formatted['weekday_ot'] ?? '0h 0m';
    final sundayOT = formatted['sunday_ot'] ?? '0h 0m';
    final doubleOT = formatted['double_ot'] ?? '0h 0m';

    return Column(
      children: [
        Semantics(
          label: isExpanded ? 'Collapse OT details' : 'Expand OT details',
          button: true,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(date);
                } else {
                  _expandedDates.add(date);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _offWhite,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(isExpanded ? 0 : 24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _softPurple.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      size: 14,
                      color: _softPurple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OT EARNED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          color: _mediumGray,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        formatted['total_overtime'] ?? '0h 0m',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _charcoal,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!isExpanded) ...[
                    if (weekdayOT != '0h 0m') _buildMiniOTPill('W', _softBlue),
                    if (sundayOT != '0h 0m') _buildMiniOTPill('S', _softOrange),
                    if (doubleOT != '0h 0m') _buildMiniOTPill('D', _softPurple),
                    const SizedBox(width: 12),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  decoration: BoxDecoration(
                    color: _offWhite,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Divider(
                        height: 1,
                        color: _lightGray,
                        thickness: 0.5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (weekdayOT != '0h 0m')
                            Expanded(
                              child: _buildDetailOTCard(
                                'Weekday',
                                weekdayOT,
                                _softBlue,
                                Icons.work_history_outlined,
                              ),
                            ),
                          if (weekdayOT != '0h 0m' &&
                              (sundayOT != '0h 0m' || doubleOT != '0h 0m'))
                            const SizedBox(width: 10),
                          if (sundayOT != '0h 0m')
                            Expanded(
                              child: _buildDetailOTCard(
                                'Sunday',
                                sundayOT,
                                _softOrange,
                                Icons.weekend_outlined,
                              ),
                            ),
                          if (sundayOT != '0h 0m' && doubleOT != '0h 0m')
                            const SizedBox(width: 10),
                          if (doubleOT != '0h 0m')
                            Expanded(
                              child: _buildDetailOTCard(
                                'Double',
                                doubleOT,
                                _softPurple,
                                Icons.bolt_outlined,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDetailOTCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: _mediumGray,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniOTPill(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Map<String, dynamic>? _getDailyDataForDate(String date) {
    if (dailyBreakdown == null) return null;

    final days = dailyBreakdown?['days'] as List<dynamic>? ?? [];
    try {
      return days.firstWhere((day) => day['date'] == date, orElse: () => null)
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _openMap(String? lat, String? lang, String label) async {
    if (lat == null || lang == null || lat.isEmpty || lang.isEmpty) {
      Get.snackbar(
        'No Location',
        'Location not available for this $label',
        backgroundColor: _softAmber,
        colorText: _pureWhite,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
        icon: const Icon(Icons.location_off_outlined, color: _pureWhite),
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
              color: _charcoal.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 48,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            selectedDateRange != null
                ? 'No records in selected range'
                : 'No attendance records yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedDateRange != null
                ? 'Try a different date range'
                : 'Start checking in to see your history',
            style: const TextStyle(fontSize: 13, color: _mediumGray),
          ),
          if (selectedDateRange != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_rounded, size: 16, color: _charcoal),
              label: const Text(
                'Clear filter',
                style: TextStyle(color: _charcoal, fontWeight: FontWeight.w600),
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
