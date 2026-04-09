import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AdminMonthlySummaryPage extends StatefulWidget {
  @override
  State<AdminMonthlySummaryPage> createState() =>
      _AdminMonthlySummaryPageState();
}

class _AdminMonthlySummaryPageState extends State<AdminMonthlySummaryPage> {
  List<dynamic> allUsers = [];
  List<int> selectedUserIds = [];
  Map<String, dynamic>? summaryData;
  bool isLoading = true;
  bool isSelectingUsers = false;

  // Default: start of current month → today
  static DateTimeRange _defaultRange() => DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  late DateTimeRange? selectedRange = _defaultRange();

  // Sophisticated monochrome palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);

  // Accent colors
  static const Color _softGreen = Color(0xFF2E7D32);
  static const Color _softRed = Color(0xFFC62828);
  static const Color _softBlue = Color(0xFF1976D2);

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
          isLoading = false;
        });
        // Auto-load summary for all users
        if (users.isNotEmpty) {
          selectedUserIds = users.map((u) => u['id'] as int).toList();
          _loadSummary();
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load users: $e',
        backgroundColor: _softRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  Future<void> _loadSummary() async {
    if (selectedUserIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final data = await ApiService.getAdminMonthlySummary(
        selectedUserIds,
        startDate: selectedRange?.start,
        endDate: selectedRange?.end,
      );
      if (mounted) setState(() => summaryData = data);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load summary: $e',
        backgroundColor: _softRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
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
            primary: _charcoal,
            onPrimary: _pureWhite,
            surface: _pureWhite,
            onSurface: _charcoal,
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

  void _toggleUserSelection(int userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  void _selectAllUsers() {
    setState(() {
      selectedUserIds = allUsers.map((u) => u['id'] as int).toList();
    });
  }

  void _clearUserSelection() {
    setState(() => selectedUserIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: _offWhite,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
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
              onPressed: () => Get.back(),
            ),
            title: const Text(
              'Monthly Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: _charcoal,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _charcoal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelectingUsers ? Icons.check : Icons.people,
                    size: 18,
                    color: _charcoal,
                  ),
                ),
                onPressed: () =>
                    setState(() => isSelectingUsers = !isSelectingUsers),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _charcoal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: _charcoal,
                  ),
                ),
                onPressed: _pickDateRange,
              ),
            ],
          ),
        ],
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: _charcoal))
            : RefreshIndicator(
                onRefresh: _loadSummary,
                color: _charcoal,
                backgroundColor: _pureWhite,
                child: CustomScrollView(
                  slivers: [
                    if (isSelectingUsers) ...[
                      SliverToBoxAdapter(child: _buildUserSelection()),
                    ],
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summaryData != null) ...[
                              _buildSummaryStats(),
                              const SizedBox(height: 24),
                              _buildUserBreakdown(),
                            ] else
                              _buildEmptyState(),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUserSelection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _charcoal,
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _selectAllUsers,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        foregroundColor: _mediumGray,
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('All'),
                    ),
                    TextButton(
                      onPressed: _clearUserSelection,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        foregroundColor: _mediumGray,
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: selectedUserIds.isNotEmpty
                          ? _loadSummary
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _charcoal,
                        foregroundColor: _pureWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allUsers.map((user) {
              final isSelected = selectedUserIds.contains(user['id']);
              return FilterChip(
                label: Text(user['username'] ?? 'Unknown'),
                selected: isSelected,
                onSelected: (_) => _toggleUserSelection(user['id']),
                backgroundColor: _offWhite,
                selectedColor: _charcoal.withOpacity(0.1),
                checkmarkColor: _charcoal,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    final summary = summaryData!['summary'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _lightGray, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.date_range, color: _mediumGray, size: 20),
              const SizedBox(width: 12),
              Text(
                '${DateFormat('d MMM y').format(selectedRange!.start)} — ${DateFormat('d MMM y').format(selectedRange!.end)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: _charcoal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Total Duration',
                summary['total_worked_hours'] ?? '0h 0m',
                Icons.schedule,
                _softGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Total Overtime',
                summary['total_ot_hours'] ?? '0h 0m',
                Icons.access_time,
                _softRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Days Attended',
                '${summary['total_days_with_checkout'] ?? 0}',
                Icons.check_circle,
                _softBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Incomplete Days',
                '${summary['total_days_with_records'] ?? 0 - (summary['total_days_with_checkout'] ?? 0)}',
                Icons.warning,
                _mediumGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Completion Rate',
                summary['completion_rate'] ?? '0%',
                Icons.trending_up,
                _softGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Avg Daily Hours',
                summary['average_daily_hours'] ?? '0h 0m',
                Icons.bar_chart,
                _softBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBreakdown() {
    final breakdown = summaryData!['user_breakdown'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Member Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _charcoal,
          ),
        ),
        const SizedBox(height: 16),
        ...breakdown.map(
          (user) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightGray, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user['username'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    Text(
                      '${user['complete_days']}/${user['total_days']} days',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _mediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'Duration',
                        user['total_duration'],
                        _softGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStat(
                        'Overtime',
                        user['total_overtime'],
                        _softRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStat(
                        'Avg Daily',
                        user['average_daily'],
                        _softBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _mediumGray,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: _mediumGray.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Monthly Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select members to view aggregated monthly statistics',
            style: TextStyle(
              fontSize: 14,
              color: _mediumGray,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
