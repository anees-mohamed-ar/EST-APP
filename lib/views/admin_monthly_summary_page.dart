import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class AdminMonthlySummaryPage extends StatefulWidget {
  const AdminMonthlySummaryPage({Key? key}) : super(key: key);

  @override
  State<AdminMonthlySummaryPage> createState() => _AdminMonthlySummaryPageState();
}

class _AdminMonthlySummaryPageState extends State<AdminMonthlySummaryPage> {
  List<dynamic> allUsers = [];
  List<int> selectedUserIds = [];
  Map<String, dynamic>? summaryData;
  bool isLoading = true;
  bool isSelectingUsers = false;

  static DateTimeRange _defaultRange() => DateTimeRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      );
  late DateTimeRange selectedRange = _defaultRange();

  // Minimalist Palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _bgSoft = Color(0xFFFAFAFA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textDim = Color(0xFF757575);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _accent = Color(0xFF1A1A1A);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);

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
          if (users.isNotEmpty) {
            selectedUserIds = users.map((u) => u['id'] as int).toList();
          }
        });
        if (selectedUserIds.isNotEmpty) {
          _loadSummary();
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadSummary() async {
    if (selectedUserIds.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getAdminMonthlySummary(
        selectedUserIds,
        startDate: selectedRange.start,
        endDate: selectedRange.end,
      );
      if (mounted) setState(() => summaryData = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgSoft,
        body: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                  : ElectricRefreshIndicator(
                      onRefresh: _loadSummary,
                      child: summaryData == null ? _buildEmptyState() : _buildContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 10,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 20),
          ),
          const Text(
            'Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textMain, letterSpacing: -0.5),
          ),
          GestureDetector(
            onTap: () => _showUserSelector(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _pureWhite, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
              ]),
              child: const Icon(Icons.people_alt_rounded, color: _textMain, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDateRange(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _pureWhite,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: _textDim),
                    const SizedBox(width: 10),
                    Text(
                      '${DateFormat('MMM d').format(selectedRange.start)} - ${DateFormat('MMM d').format(selectedRange.end)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final summary = summaryData!['summary'] as Map<String, dynamic>;
    final breakdown = summaryData!['user_breakdown'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        _buildStatsGrid(summary),
        const SizedBox(height: 32),
        const Text('Staff Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textMain)),
        const SizedBox(height: 16),
        ...breakdown.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> summary) {
    return Column(
      children: [
        Row(
          children: [
            _buildGridStat('Duration', summary['total_worked_hours'] ?? '0h', _info),
            const SizedBox(width: 12),
            _buildGridStat('Overtime', summary['total_ot_hours'] ?? '0h', _danger),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGridStat('Completion', summary['completion_rate'] ?? '0%', _success),
            const SizedBox(width: 12),
            _buildGridStat('Daily Avg', summary['average_daily_hours'] ?? '0h', _textMain),
          ],
        ),
      ],
    );
  }

  Widget _buildGridStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDim)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(user['username'] ?? 'User', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textMain)),
              Text('${user['complete_days']} days', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDim)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Worked', user['total_duration'], _info),
              _miniStat('OT', user['total_overtime'], _danger),
              _miniStat('Avg', user['average_daily'], _textMain),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _textDim)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  void _showUserSelector() {
    Get.bottomSheet(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textMain)),
                  TextButton(onPressed: () => setState(() => selectedUserIds = allUsers.map((u) => u['id'] as int).toList()), child: const Text('All')),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allUsers.map((u) {
                    final isSel = selectedUserIds.contains(u['id']);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSel) selectedUserIds.remove(u['id']);
                          else selectedUserIds.add(u['id']);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? _accent : _softGray,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          u['username'],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSel ? _pureWhite : _textDim),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    _loadSummary();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Apply Selection', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent, onPrimary: _pureWhite, surface: _pureWhite, onSurface: _accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedRange = picked);
      _loadSummary();
    }
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No data found', style: TextStyle(color: _textDim, fontWeight: FontWeight.w600)));
  }
}
