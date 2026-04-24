import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage>
    with SingleTickerProviderStateMixin {
  final storage = GetStorage();

  // ── palette (matches home_page) ─────────────────────────────────────────
  static const Color _pureWhite  = Color(0xFFFFFFFF);
  static const Color _offWhite   = Color(0xFFF8F8F8);
  static const Color _lightGray  = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal   = Color(0xFF2C2C2C);
  static const Color _softGreen  = Color(0xFF29A331);
  static const Color _softRed    = Color(0xFFD32F2F);
  static const Color _accentBlue = Color(0xFF1565C0);

  late TabController _tabCtrl;

  // balance
  Map<String, dynamic>? _balance;
  bool _loadingBalance = true;

  // leave history
  List<dynamic> _requests = [];
  bool _loadingRequests = true;

  // calendar data (blocked days)
  Set<String> _blockedDates  = {};  // 'YYYY-MM-DD'
  Map<String, String> _holidayNames = {}; // date -> name

  // apply-leave form
  DateTime? _fromDate;
  DateTime? _toDate;
  int _computedDays = 0;
  double _elDays = 0;
  double _clDays = 0;
  String _reason = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBalance();
    _loadRequests();
    _loadCalendar(DateTime.now());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── data loaders ─────────────────────────────────────────────────────────

  Future<void> _loadBalance() async {
    setState(() => _loadingBalance = true);
    try {
      final user = storage.read('user');
      if (user == null) return;
      final data = await ApiService.getLeaveBalance(user['id'] as int);
      if (mounted) setState(() => _balance = data['balance']);
    } catch (_) {}
    if (mounted) setState(() => _loadingBalance = false);
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final user = storage.read('user');
      if (user == null) return;
      final list = await ApiService.getMyLeaveRequests(user['id'] as int);
      if (mounted) setState(() => _requests = list);
    } catch (_) {}
    if (mounted) setState(() => _loadingRequests = false);
  }

  Future<void> _loadCalendar(DateTime month) async {
    try {
      final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final data = await ApiService.getLeaveCalendar(ym);
      final blocked = data['blockedDays'] as List<dynamic>? ?? [];
      final Set<String> dates = {};
      final Map<String, String> names = {};
      for (final b in blocked) {
        final d = b['date'] as String;
        dates.add(d);
        names[d] = b['name'] as String;
      }
      if (mounted) setState(() { _blockedDates = dates; _holidayNames = names; });
    } catch (_) {}
  }

  // ── sandwich rule (mirrors backend logic) ────────────────────────────────

  List<String> _applyRangeWithSandwich(DateTime from, DateTime to) {
    final all = <String>[];
    var cur = from;
    while (!cur.isAfter(to)) {
      all.add(DateFormat('yyyy-MM-dd').format(cur));
      cur = cur.add(const Duration(days: 1));
    }
    bool isOff(String d) => _blockedDates.contains(d);
    final workDays = all.where((d) => !isOff(d)).toList();
    if (workDays.isEmpty) return [];
    final first = workDays.first;
    final last  = workDays.last;
    return all.where((d) => d.compareTo(first) >= 0 && d.compareTo(last) <= 0).toList();
  }

  void _recalcDays() {
    if (_fromDate == null || _toDate == null) {
      setState(() => _computedDays = 0);
      return;
    }
    final days = _applyRangeWithSandwich(_fromDate!, _toDate!);
    setState(() {
      _computedDays = days.length;
      // reset split when range changes
      _elDays = 0;
      _clDays = 0;
    });
  }

  // ── pick date range ───────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    // Ensure calendar data loaded for current month
    await _loadCalendar(_fromDate ?? DateTime.now());

    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _charcoal,
              onPrimary: Colors.white,
              surface: _pureWhite,
              onSurface: _charcoal,
            ),
            dialogBackgroundColor: _pureWhite,
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _fromDate = result.start;
        _toDate   = result.end;
      });
      // Load calendar for the selected month(s)
      await _loadCalendar(result.start);
      _recalcDays();
    }
  }

  // ── submit leave ──────────────────────────────────────────────────────────

  Future<void> _submitLeave() async {
    final user = storage.read('user');
    if (user == null || _fromDate == null || _toDate == null) return;

    if (_elDays + _clDays != _computedDays) {
      _snack('EL + CL days must equal $_computedDays (the counted leave days)', isError: true);
      return;
    }
    final elBal = (_balance?['el_balance'] ?? 0).toDouble();
    final clBal = (_balance?['cl_balance'] ?? 0).toDouble();
    if (_elDays > elBal) {
      _snack('Not enough EL balance (available: $elBal)', isError: true);
      return;
    }
    if (_clDays > clBal) {
      _snack('Not enough CL balance (available: $clBal)', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ApiService.submitLeaveRequest(
        userId: user['id'] as int,
        fromDate: DateFormat('yyyy-MM-dd').format(_fromDate!),
        toDate:   DateFormat('yyyy-MM-dd').format(_toDate!),
        elDays: _elDays,
        clDays: _clDays,
        reason: _reason.isEmpty ? null : _reason,
      );
      _snack('Leave request submitted! ${result['totalDays']} day(s) applied.', isError: false);
      setState(() {
        _fromDate = null; _toDate = null;
        _computedDays = 0; _elDays = 0; _clDays = 0; _reason = '';
      });
      await Future.wait([_loadBalance(), _loadRequests()]);
      _tabCtrl.animateTo(1); // go to history tab
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _softRed : _softGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        title: const Text(
          'Leave Management',
          style: TextStyle(
            color: _charcoal,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: _charcoal),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: _charcoal,
          unselectedLabelColor: _mediumGray,
          indicatorColor: _charcoal,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Apply Leave'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildApplyTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ── Apply Tab ─────────────────────────────────────────────────────────────

  Widget _buildApplyTab() {
    final elBal = (_balance?['el_balance'] ?? 0).toDouble();
    final clBal = (_balance?['cl_balance'] ?? 0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Cards
          if (_loadingBalance)
            const Center(child: CircularProgressIndicator(color: _charcoal))
          else
            Row(
              children: [
                Expanded(child: _balanceCard('EL Balance', elBal, _accentBlue)),
                const SizedBox(width: 12),
                Expanded(child: _balanceCard('CL Balance', clBal, _softGreen)),
              ],
            ),

          const SizedBox(height: 24),
          _sectionLabel('Select Leave Dates'),
          const SizedBox(height: 10),

          // Date Range Picker Button
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _pureWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lightGray, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: _charcoal),
                  const SizedBox(width: 12),
                  Text(
                    (_fromDate == null || _toDate == null)
                        ? 'Tap to select date range'
                        : '${DateFormat('dd MMM yyyy').format(_fromDate!)}  →  ${DateFormat('dd MMM yyyy').format(_toDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: (_fromDate == null) ? _mediumGray : _charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_fromDate != null)
                    Icon(Icons.edit_outlined, size: 16, color: _mediumGray),
                ],
              ),
            ),
          ),

          // Sandwich info + computed days
          if (_computedDays > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_computedDays leave day(s) counted (sandwich rule applied — holidays/Sundays between leave days are included)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF57F17),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Blocked days legend
          if (_blockedDates.isNotEmpty && _fromDate != null) ...[
            const SizedBox(height: 10),
            _buildBlockedDaysLegend(),
          ],

          if (_computedDays > 0) ...[
            const SizedBox(height: 24),
            _sectionLabel('Leave Type Split'),
            const SizedBox(height: 4),
            Text(
              'EL + CL must equal $_computedDays day(s)',
              style: const TextStyle(fontSize: 12, color: _mediumGray),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _leaveTypeInput(
                    label: 'EL Days',
                    value: _elDays,
                    max: elBal,
                    color: _accentBlue,
                    onChanged: (v) => setState(() => _elDays = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _leaveTypeInput(
                    label: 'CL Days',
                    value: _clDays,
                    max: clBal,
                    color: _softGreen,
                    onChanged: (v) => setState(() => _clDays = v),
                  ),
                ),
              ],
            ),

            // Running total validation
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  (_elDays + _clDays == _computedDays)
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: (_elDays + _clDays == _computedDays) ? _softGreen : _mediumGray,
                ),
                const SizedBox(width: 6),
                Text(
                  'Total: ${_elDays + _clDays} / $_computedDays',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: (_elDays + _clDays == _computedDays) ? _softGreen : _softRed,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _sectionLabel('Reason (optional)'),
            const SizedBox(height: 10),
            TextField(
              maxLines: 3,
              onChanged: (v) => _reason = v,
              decoration: InputDecoration(
                hintText: 'Add a reason for your leave...',
                hintStyle: const TextStyle(color: _mediumGray, fontSize: 14),
                filled: true,
                fillColor: _pureWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _charcoal, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _elDays + _clDays != _computedDays)
                    ? null
                    : _submitLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _charcoal,
                  disabledBackgroundColor: _lightGray,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Submit Leave Request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBlockedDaysLegend() {
    // Show upcoming blocked days in the selected range
    if (_fromDate == null || _toDate == null) return const SizedBox.shrink();
    final blocked = <Map<String, String>>[];
    var cur = _fromDate!;
    while (!cur.isAfter(_toDate!)) {
      final ds = DateFormat('yyyy-MM-dd').format(cur);
      if (_blockedDates.contains(ds)) {
        blocked.add({'date': ds, 'name': _holidayNames[ds] ?? 'Sunday'});
      }
      cur = cur.add(const Duration(days: 1));
    }
    if (blocked.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sundays / Holidays in selected range:',
            style: TextStyle(fontSize: 11, color: _mediumGray, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...blocked.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: _softRed),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('EEE, dd MMM').format(DateTime.parse(b['date']!.substring(0, 10)))}  —  ${b['name']}',
                  style: const TextStyle(fontSize: 12, color: _charcoal),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _leaveTypeInput({
    required String label,
    required double value,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lightGray, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          Row(
            children: [
              _counterBtn(
                icon: Icons.remove,
                onTap: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color,
                    ),
                  ),
                ),
              ),
              _counterBtn(
                icon: Icons.add,
                onTap: value < max && (_elDays + _clDays) < _computedDays
                    ? () => onChanged(value + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Max: ${max.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: _mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _counterBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap != null ? () { HapticFeedback.lightImpact(); onTap(); } : null,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? _charcoal : _lightGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? _pureWhite : _mediumGray),
      ),
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator(color: _charcoal));
    }
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, size: 56, color: _mediumGray),
            SizedBox(height: 12),
            Text(
              'No leave requests yet',
              style: TextStyle(fontSize: 16, color: _mediumGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _charcoal,
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _requestCard(_requests[i]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pending';

    // Slice to 'YYYY-MM-DD' before parsing — avoids UTC midnight → IST -1 day shift
    DateTime? _parseDate(dynamic val) {
      if (val == null) return null;
      final s = val.toString();
      if (s.length >= 10) return DateTime.parse(s.substring(0, 10));
      return null;
    }

    final fromDt = _parseDate(req['from_date']);
    final toDt   = _parseDate(req['to_date']);
    final from   = fromDt != null ? DateFormat('dd MMM yyyy').format(fromDt) : '—';
    final to     = toDt   != null ? DateFormat('dd MMM yyyy').format(toDt)   : '—';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = _softGreen;
        statusIcon  = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = _softRed;
        statusIcon  = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon  = Icons.access_time_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                req['created_at'] != null
                    ? DateFormat('dd MMM').format(DateTime.parse(req['created_at'].toString()))
                    : '',
                style: const TextStyle(fontSize: 12, color: _mediumGray),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Date range
          Row(
            children: [
              const Icon(Icons.date_range_outlined, size: 14, color: _mediumGray),
              const SizedBox(width: 6),
              Text(
                '$from  →  $to',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _charcoal),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // EL/CL breakdown
          Row(
            children: [
              _leaveChip('EL: ${req['el_days']}', _accentBlue),
              const SizedBox(width: 8),
              _leaveChip('CL: ${req['cl_days']}', _softGreen),
              const SizedBox(width: 8),
              _leaveChip('Total: ${req['total_days']} day(s)', _charcoal),
            ],
          ),
          if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req['reason'].toString(),
              style: const TextStyle(fontSize: 13, color: _mediumGray),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (req['admin_note'] != null && req['admin_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _offWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 13, color: _mediumGray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req['admin_note'].toString(),
                      style: const TextStyle(fontSize: 12, color: _mediumGray),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _leaveChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: _charcoal,
      letterSpacing: -0.1,
    ),
  );

  Widget _balanceCard(String title, double balance, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightGray, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _mediumGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            balance.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'days available',
            style: TextStyle(fontSize: 11, color: _mediumGray),
          ),
        ],
      ),
    );
  }
}
