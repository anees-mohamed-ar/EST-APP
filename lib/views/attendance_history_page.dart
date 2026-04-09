import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final String? initialMonth; // Format: YYYY-MM
  const AttendanceHistoryPage({Key? key, this.initialMonth}) : super(key: key);

  @override
  _AttendanceHistoryPageState createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final storage = GetStorage();
  List<dynamic> dailyBreakdown = [];
  Map<String, dynamic>? monthlySummary;
  bool isLoading = true;
  String selectedMonth = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth =
        widget.initialMonth ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => isLoading = true);
    try {
      final userData = storage.read('user');
      if (userData != null) {
        // Fetch both monthly summary and daily breakdown
        final summaryData = await ApiService.getMonthlySummary(
          userData['id'],
          yearMonth: selectedMonth,
        );

        final dailyData = await ApiService.getDailyBreakdown(
          userData['id'],
          yearMonth: selectedMonth,
        );

        print('📊 Daily breakdown data: $dailyData'); // Debug print

        setState(() {
          monthlySummary = summaryData;
          dailyBreakdown = dailyData['days'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance: $e');
      setState(() {
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load attendance records',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _changeMonth(int delta) {
    final parts = selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    DateTime newDate = DateTime(year, month);
    newDate = delta > 0
        ? DateTime(newDate.year, newDate.month + 1)
        : DateTime(newDate.year, newDate.month - 1);

    selectedMonth =
        '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}';
    _loadAttendanceData();
  }

  String _formatMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
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
        return DateFormat('dd MMM').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formatMonth(selectedMonth),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAFAFB), Colors.white],
          ),
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.black),
                    SizedBox(height: 16),
                    Text(
                      'Loading attendance history...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAttendanceData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Monthly Summary Card
                    if (monthlySummary != null) ...[
                      _buildMonthlySummaryCard(),
                      const SizedBox(height: 24),
                    ],

                    // Daily Breakdown
                    Text(
                      'Daily Breakdown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (dailyBreakdown.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance records for ${_formatMonth(selectedMonth)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...dailyBreakdown
                          .map((day) => _buildDayCard(day))
                          .toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard() {
    final attendance =
        monthlySummary!['attendance'] as Map<String, dynamic>? ?? {};
    final formatted =
        monthlySummary!['formatted'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Regular Hours',
                  formatted['total_regular'] ?? '0h 0m',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Total OT',
                  formatted['total_overtime'] ?? '0h 0m',
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Days Present',
                  '${attendance['total_days_present'] ?? 0}',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Complete Days',
                  '${attendance['total_complete_days'] ?? 0}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final date = day['date'] as String;
    final formatted = day['formatted'] as Map<String, dynamic>? ?? {};
    final checkIn = day['check_in'] as String?;
    final checkOut = day['check_out'] as String?;
    final dayType = day['day_type'] as String? ?? 'Weekday';
    final isComplete = day['complete'] as bool? ?? false;
    final holidayName = day['holiday_name'] as String?;

    print('🔍 Day data: $day'); // Debug print for each day

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dayType == 'Sunday'
              ? Colors.red.shade200
              : dayType == 'Holiday'
              ? Colors.orange.shade200
              : Colors.green.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                      const Icon(Icons.circle, size: 6, color: Colors.green),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dayType == 'Holiday' && holidayName != null
                            ? holidayName
                            : dayType,
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
                  ],
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Times
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check In',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      checkIn != null
                          ? checkIn.split(':').take(2).join(':')
                          : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check Out',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      checkOut != null
                          ? checkOut.split(':').take(2).join(':')
                          : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Duration and OT breakdown
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      formatted['duration'] ?? '0h 0m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Regular',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      formatted['regular'] ?? '0h 0m',
                      style: const TextStyle(
                        fontSize: 14,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total OT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      formatted['total_overtime'] ?? '0h 0m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                      ),
                    ),
                  ],
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OT Breakdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if ((formatted['weekday_ot'] ?? '0h 0m') != '0h 0m') ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Normal OT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                formatted['weekday_ot'] ?? '0h 0m',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if ((formatted['sunday_ot'] ?? '0h 0m') != '0h 0m') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sunday OT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                formatted['sunday_ot'] ?? '0h 0m',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if ((formatted['double_ot'] ?? '0h 0m') != '0h 0m') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Double OT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                formatted['double_ot'] ?? '0h 0m',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
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
    );
  }
}
