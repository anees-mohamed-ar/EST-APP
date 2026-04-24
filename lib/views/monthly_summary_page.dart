import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_text.dart';
import '../widgets/electric_refresh_indicator.dart';
import 'package:intl/intl.dart';

class MonthlySummaryPage extends StatefulWidget {
  final int? userId;
  final String? userName;
  final DateTimeRange? dateRange;

  const MonthlySummaryPage({
    Key? key,
    this.userId,
    this.userName,
    this.dateRange,
  }) : super(key: key);

  @override
  _MonthlySummaryPageState createState() => _MonthlySummaryPageState();
}

class _MonthlySummaryPageState extends State<MonthlySummaryPage> {
  final storage = GetStorage();
  Map<String, dynamic>? monthlyData;
  bool isLoading = true;

  // Date range selection
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCustomRange = false;

  // Sophisticated monochrome palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);

  // Accent colors kept subtle
  static const Color _softGreen = Color(0xFF2E7D32);
  static const Color _softRed = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMonthlyData() async {
    setState(() => isLoading = true);
    try {
      final userId = widget.userId ?? storage.read('user')['id'];
      final startDate = widget.dateRange?.start;
      final endDate = widget.dateRange?.end;

      // Use payroll API for more detailed data
      // Default to current month if no custom range is selected
      final now = DateTime.now();
      final yearMonth = startDate != null && endDate != null
          ? '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}'
          : '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final data = await ApiService.getMonthlySummary(
        userId,
        yearMonth: yearMonth,
      );

      // Also fetch daily breakdown for detailed view
      final dailyData = await ApiService.getDailyBreakdown(
        userId,
        yearMonth: yearMonth,
      );

      if (mounted) {
        setState(() {
          monthlyData = {...data, 'daily_breakdown': dailyData['days'] ?? []};
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _charcoal,
              onPrimary: _pureWhite,
              surface: _pureWhite,
              onSurface: _charcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isCustomRange = true;
      });
      _loadMonthlyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      body: Stack(
        children: [
          ElectricRefreshIndicator(
            onRefresh: _loadMonthlyData,
            color: _charcoal,
            backgroundColor: _pureWhite,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 0,
                  floating: true,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: _offWhite,
                  elevation: 0,
                  title: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _charcoal.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_outlined,
                            size: 20,
                            color: _charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.userName != null
                            ? '${widget.userName}\'s Summary'
                            : 'Monthly Summary',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _charcoal,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                color: _charcoal,
                              ),
                            ),
                          )
                        else if (monthlyData != null)
                          _buildMonthlySummaryContent()
                        else
                          _buildErrorContent(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryContent() {
    // Handle payroll-style data structure
    final attendance =
        monthlyData!['attendance'] as Map<String, dynamic>? ?? {};
    final formatted = monthlyData!['formatted'] as Map<String, dynamic>? ?? {};

    final totalWorked = formatted['total_regular'] ?? '0h 0m';
    final totalOT = formatted['total_overtime'] ?? '0h 0m';
    final completeDays = attendance['total_complete_days'] ?? 0;
    final workingDays = attendance['total_days_present'] ?? 0;
    final sundayDays = attendance['total_sunday_days'] ?? 0;
    final holidayDays = attendance['total_holiday_days'] ?? 0;

    // Calculate completion rate
    final completionRate = workingDays > 0
        ? ((completeDays / workingDays) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with period
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lightGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: _pureBlack.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        // Date Range Picker Button
                        GestureDetector(
                          onTap: _showDateRangePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _offWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _lightGray, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: _mediumGray,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _isCustomRange
                                        ? '${_startDate != null ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}' : ''} — ${_endDate != null ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' : ''}'
                                        : 'Current Month',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _mediumGray,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.schedule_outlined,
                      iconColor: _softGreen,
                      title: 'Regular Hours',
                      value: totalWorked,
                      subtitle: 'Standard working hours',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.access_time_outlined,
                      iconColor: _softRed,
                      title: 'Total OT',
                      value: totalOT,
                      subtitle: 'All overtime hours',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Detailed breakdown
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lightGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: _pureBlack.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetric(
                      icon: Icons.calendar_today_outlined,
                      iconColor: _charcoal,
                      title: 'Days Present',
                      value: '$workingDays',
                      subtitle: 'Total worked days',
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDetailMetric(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: _softGreen,
                      title: 'Complete Days',
                      value: '$completeDays',
                      subtitle: 'Full check-in/out',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailMetric(
                      icon: Icons.weekend_outlined,
                      iconColor: _softRed,
                      title: 'Sundays',
                      value: '$sundayDays',
                      subtitle: 'Sunday work days',
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDetailMetric(
                      icon: Icons.beach_access_outlined,
                      iconColor: Colors.orange,
                      title: 'Holidays',
                      value: '$holidayDays',
                      subtitle: 'Holiday work days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Completion rate
              ShimmerEffect(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _offWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _lightGray, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _softGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.trending_up_outlined,
                          color: _softGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Completion Rate',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _charcoal,
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: completionRate.toDouble(),
                              ),
                              duration: const Duration(seconds: 1),
                              builder: (context, animatedValue, child) {
                                return Text(
                                  '${animatedValue.round()}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _softGreen,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // OT Breakdown
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lightGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: _pureBlack.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overtime Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildOTMetric(
                      icon: Icons.work_outline,
                      iconColor: Colors.blue,
                      title: 'Normal OT',
                      value: formatted['total_weekday_ot'] ?? '0h 0m',
                      subtitle: 'Weekday overtime',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOTMetric(
                      icon: Icons.weekend_outlined,
                      iconColor: Colors.orange,
                      title: 'Sunday OT',
                      value: formatted['total_sunday_ot'] ?? '0h 0m',
                      subtitle: 'Sunday overtime',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildOTMetric(
                      icon: Icons.star_outline,
                      iconColor: Colors.purple,
                      title: 'Double OT',
                      value: _formatDoubleOT(
                        formatted['total_double_ot'] ?? '0h 0m',
                      ),
                      subtitle: '2× rate (Sun/Holiday)',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOTMetric(
                      icon: Icons.access_time,
                      iconColor: _softRed,
                      title: 'Total OT',
                      value: formatted['total_overtime'] ?? '0h 0m',
                      subtitle: 'All OT combined',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Daily Breakdown
        _buildDailyBreakdown(),
      ],
    );
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

  Widget _buildOTMetric({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    final dailyBreakdown =
        monthlyData!['daily_breakdown'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 300, // Fixed height for scrollable area
            decoration: BoxDecoration(
              color: _offWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightGray, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: dailyBreakdown.isEmpty
                  ? _buildEmptyBreakdown()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      itemCount: dailyBreakdown.length,
                      itemBuilder: (context, index) {
                        // Sort daily breakdown by date in descending order (newest first)
                        final sortedBreakdown =
                            dailyBreakdown
                                .map((day) => day as Map<String, dynamic>)
                                .toList()
                              ..sort((a, b) {
                                try {
                                  final dateA = DateTime.parse(
                                    a['date'] as String,
                                  );
                                  final dateB = DateTime.parse(
                                    b['date'] as String,
                                  );
                                  return dateB.compareTo(
                                    dateA,
                                  ); // Descending order
                                } catch (e) {
                                  return 0;
                                }
                              });

                        final day = sortedBreakdown[index];
                        final date = day['date'] as String;
                        final formatted =
                            day['formatted'] as Map<String, dynamic>? ?? {};
                        final checkIn = day['check_in'] as String?;
                        final checkOut = day['check_out'] as String?;
                        final dayType = day['day_type'] as String? ?? 'Weekday';

                        final isOvernight = day['is_overnight'] == true;
                        final shiftDate = day['shift_date'] as String?;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _lightGray, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date and day type
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (_formatDate(date) == 'Today') ...[
                                          Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: _softGreen,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          _formatDate(date),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _charcoal,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: dayType == 'Sunday'
                                                ? Colors.red.withOpacity(0.1)
                                                : dayType == 'Holiday'
                                                ? Colors.orange.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            dayType,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: dayType == 'Sunday'
                                                  ? Colors.red
                                                  : dayType == 'Holiday'
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                        if (isOvernight) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '🌙 Overnight',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Times
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Check In',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        Text(
                                          checkIn != null
                                              ? checkIn
                                                    .split(':')
                                                    .take(2)
                                                    .join(':')
                                              : '—',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _charcoal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Check Out',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              checkOut != null
                                                  ? checkOut
                                                        .split(':')
                                                        .take(2)
                                                        .join(':')
                                                  : '—',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: _charcoal,
                                              ),
                                            ),
                                            if (isOvernight &&
                                                shiftDate != null) ...[
                                              const SizedBox(width: 4),
                                              Text(
                                                '(${DateFormat('MMM d').format(DateTime.parse(shiftDate))})',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Duration and OT breakdown
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Duration',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        Text(
                                          formatted['duration'] ?? '0h 0m',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _charcoal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Regular',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        Text(
                                          formatted['regular'] ?? '0h 0m',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total OT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        Text(
                                          formatted['total_overtime'] ??
                                              '0h 0m',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _softRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBreakdown() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_day_outlined,
            size: 48,
            color: _mediumGray.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _charcoal.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No check-in/check-out records found for the selected period.',
            style: TextStyle(
              fontSize: 12,
              color: _mediumGray,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: _mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: _charcoal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _mediumGray,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: _mediumGray,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_view_month_outlined,
            size: 48,
            color: _mediumGray.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Monthly Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load data',
            style: TextStyle(
              fontSize: 13,
              color: _mediumGray,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Today';
      } else if (dateOnly == yesterday) {
        return 'Yesterday';
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
