import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'monthly_summary_page.dart';
import '../widgets/electric_refresh_indicator.dart';

class AdminMonthlySummaryNewPage extends StatefulWidget {
  @override
  _AdminMonthlySummaryNewPageState createState() =>
      _AdminMonthlySummaryNewPageState();
}

class _AdminMonthlySummaryNewPageState
    extends State<AdminMonthlySummaryNewPage> {
  List<dynamic> allUsers = [];
  List<int> allUserIds = [];
  Map<String, dynamic>? summaryData;
  bool isLoading = true;
  String searchQuery = '';
  List<dynamic> filteredUsers = [];

  // Default: current month (start of month to today)
  DateTimeRange selectedRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  // Professional theme matching the React/Ant Design reference
  static const Color _primaryBlack = Color(0xFF000000);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _bgLayout = Color(0xFFFAFAFB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _hoverBg = Color(0xFFF3F4F6);
  static const Color _lightGray = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => isLoading = true);
    try {
      final users = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          allUsers = users;
          allUserIds = users.map((u) => u['id'] as int).toList();
          filteredUsers = users;
          isLoading = false;
        });
        if (users.isNotEmpty) {
          _loadSummary();
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load users: $e',
        backgroundColor: _textSecondary,
        colorText: _pureWhite,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
      );
    }
  }

  Future<void> _loadSummary() async {
    if (allUserIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final data = await ApiService.getAdminMonthlySummary(
        allUserIds,
        startDate: selectedRange.start,
        endDate: selectedRange.end,
      );
      if (mounted) setState(() => summaryData = data);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load summary: $e',
        backgroundColor: _textSecondary,
        colorText: _pureWhite,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryBlack,
            onPrimary: _pureWhite,
            surface: _pureWhite,
            onSurface: _textPrimary,
            primaryContainer: _hoverBg,
            onPrimaryContainer: _primaryBlack,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _primaryBlack),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
      _loadSummary();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      filteredUsers = allUsers
          .where(
            (user) => user['username'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLayout,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, size: 20, color: _textPrimary),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Monthly Summary',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(
                Icons.calendar_today,
                size: 16,
                color: _textPrimary,
              ),
              label: Text(
                '${DateFormat('d MMM').format(selectedRange.start)} - ${DateFormat('d MMM y').format(selectedRange.end)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                backgroundColor: _pureWhite,
                foregroundColor: _textPrimary,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderColor, height: 1),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _primaryBlack,
                backgroundColor: _hoverBg,
              ),
            )
          : Column(
              children: [
                // Search bar
                Container(
                  color: _pureWhite,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _textSecondary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _hoverBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _primaryBlack,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                // Stats summary header
                // if (summaryData != null)
                //   Container(
                //     color: _pureWhite,
                //     padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                //     child: Row(
                //       children: [
                //         Expanded(
                //           child: _buildStatChip(
                //             'Total Hours',
                //             summaryData?['total_duration'] ?? '0h',
                //             Icons.timer,
                //           ),
                //         ),
                //         const SizedBox(width: 12),
                //         Expanded(
                //           child: _buildStatChip(
                //             'Total Overtime',
                //             summaryData?['total_overtime'] ?? '0h',
                //             Icons.access_time_filled,
                //           ),
                //         ),
                //         const SizedBox(width: 12),
                //         Expanded(
                //           child: _buildStatChip(
                //             'Active Users',
                //             '${filteredUsers.length}',
                //             Icons.people,
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // User cards list
                Expanded(
                  child: ElectricRefreshIndicator(
                    onRefresh: _loadSummary,
                    color: _primaryBlack,
                    backgroundColor: _pureWhite,
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: _textSecondary.withOpacity(0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No users found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final userStats = summaryData?['user_breakdown']
                                  ?.firstWhere(
                                    (u) => u['user_id'] == user['id'],
                                    orElse: () => null,
                                  );
                              return _buildUserCard(user, userStats);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _hoverBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Widget _buildUserCard(dynamic user, dynamic userStats) {
    final String role = user['role'] ?? 'single user';
    final bool isAdmin = role == 'admin';
    final bool isManager = role == 'multi user';

    // Get the first monthly record (or null if no data)
    final monthlyRecord = userStats?['monthly_records']?.isNotEmpty == true
        ? userStats['monthly_records'][0]
        : null;
    final attendance = monthlyRecord?['attendance'] ?? {};
    final formatted = monthlyRecord?['formatted'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Get.to(
              () => MonthlySummaryPage(
                userId: user['id'],
                userName: user['username'],
                dateRange: selectedRange,
              ),
            );
          },
          hoverColor: _hoverBg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _hoverBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (user['username']?[0] ?? '?')
                              .toString()
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? _primaryBlack.withOpacity(0.05)
                                  : isManager
                                  ? _textSecondary.withOpacity(0.05)
                                  : _hoverBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role[0].toUpperCase() + role.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isAdmin
                                    ? _primaryBlack
                                    : isManager
                                    ? _textSecondary
                                    : _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (monthlyRecord != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryBlack.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          monthlyRecord['year_month'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),

                if (monthlyRecord != null) ...[
                  const SizedBox(height: 16),

                  // Main stats row
                  Row(
                    children: [
                      // Commented out Total Hours for later use
                      // Expanded(
                      //   child: _buildStatItem(
                      //     'Total Hours',
                      //     formatted['total_duration'] ?? '0h',
                      //     Icons.schedule,
                      //   ),
                      // ),
                      // Container(height: 24, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildStatItem(
                          'Regular',
                          formatted['total_regular'] ?? '0h',
                          Icons.work_outline,
                        ),
                      ),
                      Container(height: 24, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildStatItem(
                          'Total OT',
                          formatted['total_overtime'] ?? '0h',
                          Icons.timelapse,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Overtime breakdown row
                  Row(
                    children: [
                      Expanded(
                        child: _buildOvertimeItem(
                          'Weekday OT',
                          formatted['total_weekday_ot'] ?? '0h',
                          Colors.blue,
                        ),
                      ),
                      Container(height: 20, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildOvertimeItem(
                          'Sunday OT',
                          formatted['total_sunday_ot'] ?? '0h',
                          Colors.green,
                        ),
                      ),
                      Container(height: 20, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildOvertimeItem(
                          'Double OT',
                          _formatDoubleOT(formatted['total_double_ot'] ?? '0h'),
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Attendance details row
                  Row(
                    children: [
                      Expanded(
                        child: _buildAttendanceItem(
                          'Days Present',
                          '${attendance['total_days_present'] ?? 0}',
                          Icons.calendar_today,
                        ),
                      ),
                      Container(height: 20, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildAttendanceItem(
                          'Complete Days',
                          '${attendance['total_complete_days'] ?? 0}',
                          Icons.check_circle,
                        ),
                      ),
                      Container(height: 20, width: 1, color: _borderColor),
                      Expanded(
                        child: _buildAttendanceItem(
                          'Sunday Days',
                          '${attendance['total_sunday_days'] ?? 0}',
                          Icons.event,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Progress indicator for days completed
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Completion Rate',
                            style: TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                          Text(
                            '${attendance['total_complete_days'] ?? 0}/${attendance['total_days_present'] ?? 0} days',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _safeDouble(attendance['total_days_present']) > 0
                              ? _safeDouble(attendance['total_complete_days']) /
                                    _safeDouble(attendance['total_days_present'])
                              : 0,
                          backgroundColor: _hoverBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _primaryBlack,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hoverBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No attendance data for selected period',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOvertimeItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.access_time, size: 10, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: _textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAttendanceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: _textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: _textSecondary)),
      ],
    );
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
