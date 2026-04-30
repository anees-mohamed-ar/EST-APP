import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int _tab = 0; // 0=Summary, 1=Daily

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  void _setTab(int i) {
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  Future<void> _loadMonthlyData() async {
    setState(() => isLoading = true);
    try {
      final userId = widget.userId ?? storage.read('user')['id'];
      final startDate = _startDate ?? widget.dateRange?.start;
      final endDate = _endDate ?? widget.dateRange?.end;

      final now = DateTime.now();
      final yearMonth = startDate != null
          ? '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}'
          : '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final data = await ApiService.getMonthlySummary(
        userId,
        yearMonth: yearMonth,
      );

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
      debugPrint('Error loading monthly data: $e');
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _offWhite,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: ElectricRefreshIndicator(
                    onRefresh: _loadMonthlyData,
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _charcoal),
                          )
                        : monthlyData == null
                            ? _buildErrorContent()
                            : IndexedStack(
                                index: _tab,
                                children: [
                                  _buildSummaryTab(),
                                  _buildDailyTab(),
                                ],
                              ),
                  ),
                ),
              ],
            ),
            // Floating dock navigation
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 24,
              right: 24,
              child: _buildDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: _pureWhite,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _lightGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _charcoal, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName != null
                    ? '${widget.userName}\'s Summary'
                    : 'Monthly Summary',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _charcoal,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _tab == 0 ? 'Performance & Stats' : 'Day-by-day Breakdown',
                style: const TextStyle(
                  fontSize: 12,
                  color: _mediumGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadMonthlyData,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _lightGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _charcoal, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final attendance =
        monthlyData!['attendance'] as Map<String, dynamic>? ?? {};
    final formatted = monthlyData!['formatted'] as Map<String, dynamic>? ?? {};

    final totalWorked = formatted['total_regular'] ?? '0h 0m';
    final totalOT = formatted['total_overtime'] ?? '0h 0m';
    double _safeNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final double completeDays = _safeNum(attendance['total_complete_days']);
    final double workingDays = _safeNum(attendance['total_days_present']);
    final double sundayDays = _safeNum(attendance['total_sunday_days']);
    final double holidayDays = _safeNum(attendance['total_holiday_days']);

    final completionRate = workingDays > 0
        ? ((completeDays / workingDays) * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.schedule_outlined,
                  iconColor: _softGreen,
                  title: 'Regular Hours',
                  value: totalWorked,
                  subtitle: 'Monthly work',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.access_time_outlined,
                  iconColor: _softRed,
                  title: 'Total OT',
                  value: totalOT,
                  subtitle: 'Total overtime',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Attendance Breakdown'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lightGray, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailMetric(
                        icon: Icons.calendar_today_outlined,
                        iconColor: _charcoal,
                        title: 'Present',
                        value: '$workingDays',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailMetric(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: _softGreen,
                        title: 'Complete',
                        value: '$completeDays',
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: _lightGray),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailMetric(
                        icon: Icons.weekend_outlined,
                        iconColor: _softRed,
                        title: 'Sundays',
                        value: '$sundayDays',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailMetric(
                        icon: Icons.beach_access_outlined,
                        iconColor: Colors.orange,
                        title: 'Holidays',
                        value: '$holidayDays',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _charcoal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: completionRate / 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: _softGreen,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$completionRate%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Completion Rate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Your efficiency this month',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('OT Details'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOTMetric(
                  icon: Icons.work_outline,
                  iconColor: Colors.blue,
                  title: 'Normal OT',
                  value: formatted['total_weekday_ot'] ?? '0h 0m',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOTMetric(
                  icon: Icons.weekend_outlined,
                  iconColor: Colors.orange,
                  title: 'Sunday OT',
                  value: formatted['total_sunday_ot'] ?? '0h 0m',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOTMetric(
            icon: Icons.star_outline,
            iconColor: Colors.purple,
            title: 'Double OT',
            value: _formatDoubleOT(formatted['total_double_ot'] ?? '0h 0m'),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTab() {
    final dailyBreakdown =
        monthlyData!['daily_breakdown'] as List<dynamic>? ?? [];

    if (dailyBreakdown.isEmpty) {
      return _buildEmptyBreakdown();
    }

    final sortedBreakdown = dailyBreakdown
        .map((day) => day as Map<String, dynamic>)
        .toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(b['date'] as String)
              .compareTo(DateTime.parse(a['date'] as String));
        } catch (e) {
          return 0;
        }
      });

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120),
      itemCount: sortedBreakdown.length,
      itemBuilder: (context, index) {
        final day = sortedBreakdown[index];
        return _buildDailyItem(day);
      },
    );
  }

  Widget _buildDailyItem(Map<String, dynamic> day) {
    final date = day['date'] as String;
    final formatted = day['formatted'] as Map<String, dynamic>? ?? {};
    final checkIn = day['check_in'] as String?;
    final checkOut = day['check_out'] as String?;
    final dayType = day['day_type'] as String? ?? 'Weekday';
    final dayStatus = day['day_status'] as String? ?? 'present';
    final isOvernight = day['is_overnight'] == true;
    final isLeave = dayStatus == 'leave';

    final parsedDate = DateTime.parse(date);
    final dayName = DateFormat('EEEE').format(parsedDate);
    final dateShort = DateFormat('dd MMM').format(parsedDate);

    // Styling based on special status
    Color cardBg = _pureWhite;
    Color borderColor = _lightGray;
    if (isOvernight) {
      cardBg = Colors.purple.withOpacity(0.05);
      borderColor = Colors.purple.withOpacity(0.2);
    } else if (isLeave) {
      cardBg = Colors.orange.withOpacity(0.05);
      borderColor = Colors.orange.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _charcoal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateShort,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
              const Spacer(),
              if (isLeave) ...[
                _buildTypeBadge('Leave', color: Colors.orange),
                const SizedBox(width: 6),
              ],
              if (isOvernight) ...[
                _buildTypeBadge('Overnight', color: Colors.purple),
                const SizedBox(width: 6),
              ],
              _buildTypeBadge(dayType),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTimeInfo('IN', checkIn, _softGreen),
              _buildArrow(),
              _buildTimeInfo('OUT', checkOut, isOvernight ? Colors.purple : _softRed, isOvernight: isOvernight),
              const SizedBox(width: 12),
              _buildWorkInfo(formatted['regular'] ?? '--', formatted['total_overtime'] ?? '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String? time, Color color, {bool isOvernight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _mediumGray, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time != null ? _formatTime(time) : '--:--',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: time != null ? color : _mediumGray,
                ),
              ),
              if (isOvernight) ...[
                const SizedBox(width: 4),
                Icon(Icons.nights_stay, size: 11, color: color),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Icon(Icons.arrow_forward_rounded, size: 14, color: _lightGray.withOpacity(0.8)),
  );

  Widget _buildWorkInfo(String regular, String ot) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _offWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _workDetail('REG', regular),
            _workDetail('OT', ot, color: _softRed),
          ],
        ),
      ),
    );
  }

  Widget _workDetail(String label, String val, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _mediumGray)),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color ?? _charcoal)),
      ],
    );
  }

  Widget _buildTypeBadge(String type, {Color? color}) {
    Color badgeColor = color ?? _softGreen;
    if (color == null) {
      if (type == 'Sunday') badgeColor = _softRed;
      if (type == 'Holiday') badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return GestureDetector(
      onTap: _showDateRangePicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _lightGray, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 20, color: _charcoal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REPORT PERIOD',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _mediumGray)),
                  Text(
                    _isCustomRange
                        ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                        : DateFormat('MMMM yyyy').format(DateTime.now()),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _charcoal),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _mediumGray),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _mediumGray,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDock() {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                left: _dockPillLeft() + 4,
                top: 0,
                bottom: 0,
                child: Container(
                  width: _dockPillWidth() - 8,
                  decoration: BoxDecoration(
                    color: _pureWhite,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _dockItem(0, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Summary'),
                  _dockItem(1, Icons.list_alt_rounded, Icons.list_alt_outlined, 'Daily'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dockPillLeft() {
    final width = MediaQuery.of(context).size.width - 48; 
    final itemWidth = (width - 16) / 2;
    return _tab * itemWidth;
  }

  double _dockPillWidth() {
    final width = MediaQuery.of(context).size.width - 48;
    return (width - 16) / 2;
  }

  Widget _dockItem(int index, IconData active, IconData inactive, String label) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? active : inactive,
              color: isActive ? _charcoal : _mediumGray,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? _charcoal : _mediumGray,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _charcoal,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor.withOpacity(0.8)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _charcoal,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _mediumGray,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOTMetric({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: fullWidth ? double.infinity : null,
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
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBreakdown() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 48, color: _lightGray),
          SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(color: _mediumGray, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: _softRed),
          const SizedBox(height: 16),
          const Text(
            'Failed to load summary',
            style: TextStyle(color: _charcoal, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadMonthlyData,
            child: const Text('Try Again', style: TextStyle(color: _softGreen)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2024, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (e) {
      return time;
    }
  }

  String _formatDoubleOT(String doubleOT) {
    try {
      final parts = doubleOT.split(' ');
      int hours = 0;
      int minutes = 0;
      for (final part in parts) {
        if (part.endsWith('h')) hours = int.parse(part.replaceAll('h', ''));
        else if (part.endsWith('m')) minutes = int.parse(part.replaceAll('m', ''));
      }
      final totalMinutes = (hours * 60 + minutes) * 2;
      final totalHours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      String totalStr = '';
      if (totalHours > 0 && remainingMinutes > 0) totalStr = '${totalHours}h ${remainingMinutes}m';
      else if (totalHours > 0) totalStr = '${totalHours}h';
      else totalStr = '${remainingMinutes}m';
      return '2× $doubleOT = $totalStr';
    } catch (e) {
      return doubleOT;
    }
  }
}
