/* ============================================================
   PAYROLL DOWNLOAD PAGE — Commented out, kept for future reference.
   Replaced by payslip_page.dart which shows admin-uploaded payslips.
   ============================================================ */
/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../services/payroll_pdf_service.dart';
import '../services/payroll_excel_service.dart';
import '../services/payroll_file_service.dart';
import '../models/payroll_month_data.dart';

class PayrollDownloadPage extends StatefulWidget {
  final int userId;
  final String displayName;
  final String username;
  final bool isAdminView;

  const PayrollDownloadPage({
    Key? key,
    required this.userId,
    required this.displayName,
    required this.username,
    this.isAdminView = false,
  }) : super(key: key);

  @override
  State<PayrollDownloadPage> createState() => _PayrollDownloadPageState();
}

class _PayrollDownloadPageState extends State<PayrollDownloadPage>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFFAFAFB);
  static const _white = Color(0xFFFFFFFF);
  static const _black = Color(0xFF000000);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _lightGray = Color(0xFFF9FAFB);
  static const _green = Color(0xFF059669);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);
  static const _red = Color(0xFFDC2626);
  static const _orange = Color(0xFFC2410C);

  late TabController _tabController;
  List<PayrollMonthData> _months = [];
  bool _isLoading = true;
  bool _isExporting = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTab) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final months = await ApiService.getPayrollThreeMonths(widget.userId);
      if (mounted) setState(() => _months = months);
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Failed to load payroll data',
            backgroundColor: _red,
            colorText: _white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PayrollMonthData? get _currentData =>
      _months.isNotEmpty && _selectedTab < _months.length
          ? _months[_selectedTab]
          : null;

  // ── Export ───────────────────────────────────────────────────────────────────
  void _showDownloadSheet() {
    final data = _currentData;
    if (data == null || data.isEmpty) {
      Get.snackbar('No Data', 'No payroll data available for this month',
          backgroundColor: _textSecondary,
          colorText: _white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Download as…',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 16),
            _downloadOption(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF Document',
              subtitle: 'Formatted report with daily breakdown',
              color: _red,
              onTap: () { Navigator.pop(context); _export('pdf'); },
            ),
            const SizedBox(height: 12),
            _downloadOption(
              icon: Icons.table_chart_rounded,
              label: 'Excel Spreadsheet',
              subtitle: 'Editable .xlsx with styled rows',
              color: _green,
              onTap: () { Navigator.pop(context); _export('xlsx'); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _lightGray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(String type) async {
    final data = _currentData;
    if (data == null) return;

    setState(() => _isExporting = true);
    try {
      Uint8List bytes;
      if (type == 'pdf') {
        bytes = await PayrollPdfService.generate(
          data: data,
          employeeName: widget.displayName,
          username: widget.username,
        );
      } else {
        bytes = PayrollExcelService.generate(
          data: data,
          employeeName: widget.displayName,
          username: widget.username,
        );
      }

      final file = await PayrollFileService.saveFile(
        bytes: bytes,
        employeeName: widget.username,
        yearMonth: data.yearMonth,
        extension: type == 'pdf' ? 'pdf' : 'xlsx',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: '),
          backgroundColor: _black,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(file.path),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: '),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _black))
            : _months.isEmpty
                ? _buildEmptyFull()
                : Column(
                    children: [
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: _months.map(_buildMonthContent).toList(),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _textPrimary, size: 22),
        onPressed: () => Get.back(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
          const Text('Payroll Reports',
              style: TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        if (widget.isAdminView)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Admin View',
                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _white,
      child: TabBar(
        controller: _tabController,
        tabs: _months.map((m) => Tab(text: m.displayLabel)).toList(),
        labelColor: _black,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: _black,
        indicatorWeight: 2,
      ),
    );
  }

  Widget _buildMonthContent(PayrollMonthData data) {
    if (data.isEmpty) return _buildEmptyMonth(data.displayLabel);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 4),
        _buildSummarySection(data),
        const SizedBox(height: 20),
        if (data.days.isNotEmpty) ...[
          Row(children: [
            const Text('Daily Breakdown',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _lightGray,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(' days',
                  style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 10),
          ...data.days.map((d) => _ExpandableDayRow(record: d)),
        ],
      ],
    );
  }

  Widget _buildSummarySection(PayrollMonthData data) {
    final normalOtMins = data.totalWeekdayOtMinutes + data.totalSundayOtMinutes;
    final doubleOtMins = data.totalDoubleOtMinutes;
    final billedDouble = doubleOtMins * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statCard('Days Present', data.totalDaysPresent.toString(), Icons.calendar_today_outlined, _textPrimary)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Sundays', data.totalSundayDays.toString(), Icons.brightness_7_outlined, _red)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Holidays', data.totalHolidayDays.toString(), Icons.star_outline_rounded, _orange)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statCard('Regular Hrs', data.totalRegular, Icons.schedule_outlined, _green)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Normal OT', _fmtMins(normalOtMins), Icons.access_time_outlined, _blue)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Total OT', data.totalOvertime, Icons.timelapse_outlined, _textPrimary)),
        ]),
        if (doubleOtMins > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.double_arrow_rounded, color: _purple, size: 18),
              const SizedBox(width: 10),
              Text('2× Double OT: ${_fmtMins(doubleOtMins)} → billed as ${_fmtMins(billedDouble)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _purple)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyMonth(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _lightGray,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: _textSecondary),
          ),
          const SizedBox(height: 16),
          Text('No Payroll Data', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 6),
          Text('No records found for ',
              style: const TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyFull() {
    return Center(
      child: Text('No payroll data available.', style: const TextStyle(color: _textSecondary, fontSize: 14)),
    );
  }

  Widget _buildBottomBar() {
    final hasData = _currentData != null && !_currentData!.isEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_isExporting || !hasData) ? null : _showDownloadSheet,
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(_isExporting ? 'Generating…' : 'Download Payroll Sheet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _lightGray,
              disabledForegroundColor: _textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _fmtMins(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class _ExpandableDayRow extends StatefulWidget {
  final Map<String, dynamic> record;
  const _ExpandableDayRow({Key? key, required this.record}) : super(key: key);

  @override
  State<_ExpandableDayRow> createState() => _ExpandableDayRowState();
}

class _ExpandableDayRowState extends State<_ExpandableDayRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final dayType = r['day_type'] ?? 'Weekday';
    final isSunday = dayType == 'Sunday';
    final isHoliday = dayType == 'Holiday';
    final isOvernight = r['is_overnight'] == true;
    final isComplete = r['complete'] == true;
    final dateRaw = r['date'] ?? '';

    String dateLabel = dateRaw;
    String weekday = '';
    try {
      final parts = dateRaw.split('-');
      if (parts.length == 3) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        weekday = days[dt.weekday - 1];
        dateLabel = '${parts[2]} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1]}';
      }
    } catch (_) {}

    Color typeBg = const Color(0xFFF0FDF4);
    Color typeColor = const Color(0xFF059669);
    String typeLabel = dayType;
    if (isSunday) { typeBg = const Color(0xFFFEF2F2); typeColor = const Color(0xFFDC2626); }
    if (isHoliday) {
      typeBg = const Color(0xFFFFF7ED);
      typeColor = const Color(0xFFC2410C);
      typeLabel = r['holiday_name'] ?? 'Holiday';
    }

    final fmt = (r['formatted'] as Map<String, dynamic>?) ?? {};
    final mins = (r['minutes'] as Map<String, dynamic>?) ?? {};

    final durationMins = _safeInt(mins['duration_minutes']);
    final regularMins = _safeInt(mins['regular_minutes']);
    final weekdayOtMins = _safeInt(mins['weekday_ot_minutes']);
    final sundayOtMins = _safeInt(mins['sunday_ot_minutes']);
    final earlyOtMins = _safeInt(mins['early_ot_minutes']);
    final doubleOtMins = _safeInt(mins['double_ot_minutes']);

    final normalOtMins = weekdayOtMins + sundayOtMins;
    final totalOtMins = normalOtMins + (doubleOtMins * 2);

    final totalOtStr = (fmt['total_overtime'] != null && fmt['total_overtime'] != '0h 0m' && fmt['total_overtime'] != '0m')
        ? fmt['total_overtime'].toString()
        : _fmtMins(totalOtMins);
    final hasOt = totalOtMins > 0 || (totalOtStr != '0h 0m' && totalOtStr != '0m' && totalOtStr != '--');

    final checkIn = (r['check_in'] ?? '').toString().length >= 5 ? r['check_in'].toString().substring(0, 5) : '--';
    final checkOut = (r['check_out'] ?? '').toString().length >= 5 ? r['check_out'].toString().substring(0, 5) : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSunday ? const Color(0xFFDC2626).withOpacity(0.2)
              : isHoliday ? const Color(0xFFC2410C).withOpacity(0.2)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          // Header Summary Row (Tappable)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Date
                  SizedBox(
                    width: 46,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        Text(weekday, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(typeLabel, style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  // Times
                  Expanded(
                    child: Row(
                      children: [
                        _timeChip(Icons.login_rounded, checkIn, const Color(0xFF059669)),
                        const SizedBox(width: 4),
                        _timeChip(Icons.logout_rounded, checkOut, const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  // Hours & OT summary
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmt['regular'] ?? '--',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                          if (hasOt) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('|', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w400)),
                            ),
                            Text('OT: $totalOtStr',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          ],
                        ],
                      ),
                      if (normalOtMins > 0)
                        Text('+${_fmtMins(normalOtMins)} OT',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      if (doubleOtMins > 0)
                        Text('+2× ${_fmtMins(doubleOtMins)} (${_fmtMins(doubleOtMins * 2)})',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6B7280),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Detailed Breakdown Expandable Panel
          if (_isExpanded) ...[
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Row(
                    children: [
                      _badge(
                        isComplete ? 'Complete Day' : 'Incomplete',
                        isComplete ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                      if (isOvernight) ...[
                        const SizedBox(width: 6),
                        _badge('Overnight Shift', const Color(0xFF7C3AED)),
                      ],
                      if (r['shift_date'] != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Shift: ${r['shift_date']}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Detailed breakdown grid header
                  const Text('Detailed Hours Breakdown',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _detailTile('On-Site Duration', fmt['duration'] ?? _fmtMins(durationMins), const Color(0xFF111827)),
                      _detailTile('Regular Hours', fmt['regular'] ?? _fmtMins(regularMins), const Color(0xFF059669)),
                      if (weekdayOtMins > 0)
                        _detailTile('Weekday OT', fmt['weekday_ot'] ?? _fmtMins(weekdayOtMins), const Color(0xFF2563EB)),
                      if (sundayOtMins > 0)
                        _detailTile('Sunday OT', fmt['sunday_ot'] ?? _fmtMins(sundayOtMins), const Color(0xFFDC2626)),
                      if (earlyOtMins > 0)
                        _detailTile('Early OT', fmt['early_ot'] ?? _fmtMins(earlyOtMins), const Color(0xFFC2410C)),
                      if (doubleOtMins > 0)
                        _detailTile('2× Double OT', '${_fmtMins(doubleOtMins)} → billed as ${_fmtMins(doubleOtMins * 2)}', const Color(0xFF7C3AED)),
                      _detailTile('Total Billed OT', totalOtStr, const Color(0xFF111827)),
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _detailTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _timeChip(IconData icon, String time, Color color) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(time, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _fmtMins(int mins) {
    if (mins <= 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final d = double.tryParse(val);
      if (d != null) return d.toInt();
      final i = int.tryParse(val);
      if (i != null) return i;
    }
    return 0;
  }
}
*/ // end of PayrollDownloadPage — use payslip_page.dart instead
