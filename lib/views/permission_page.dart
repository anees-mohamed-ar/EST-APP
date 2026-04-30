import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/swipe_to_confirm.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with TickerProviderStateMixin {
  final storage = GetStorage();

  static const Color _bg = Color(0xFFF4F5F7);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F9FA);
  static const Color _charcoal = Color(0xFF1E293B);
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _lightGray = Color(0xFFE2E8F0);
  static const Color _mediumGray = Color(0xFF64748B);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _orange = Color(0xFFF59E0B);

  int _tab = 0; // 0=Apply, 1=History

  DateTime _selectedDate = DateTime.now();
  int _selectedMinutes = 30;
  String _selectedType = 'late_checkin';
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingHistory = true;
  List<dynamic> _myPermissions = [];

  // ── Approver Logic ────────────────────────────────────────────────────────
  List<dynamic> _fixedApprovers = [];
  List<dynamic> _potentialApprovers = [];
  int? _selectedApproverId;
  bool _loadingApproverStatus = true;
  bool _hasAcceptAccess = false;

  final List<int> _durations = [30, 60, 90, 120, 150, 180];
  final Map<String, String> _types = {
    'late_checkin': 'Late Check-in',
    'early_checkout': 'Early Check-out',
  };

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    final user = storage.read('user') ?? {};
    _hasAcceptAccess =
        user['accept_access'] == 1 || user['accept_access'] == true;
    _loadApproverStatus();
  }

  Future<void> _loadApproverStatus() async {
    if (!mounted) return;
    setState(() => _loadingApproverStatus = true);
    try {
      final user = storage.read('user') ?? {};
      final userId = user['id'];

      // 1. Get fixed approvers (hierarchy)
      final fixed = await ApiService.getUserApprovers(userId);

      // 2. If no fixed approvers, get potential ones
      if (fixed.isEmpty) {
        final potential = await ApiService.getPotentialApprovers();
        if (mounted) {
          setState(() {
            _fixedApprovers = [];
            _potentialApprovers = potential;
            _selectedApproverId = null; // No default selection
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fixedApprovers = fixed;
            _potentialApprovers = [];
            _selectedApproverId = null; // No need to select if fixed exists
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading approver status: $e');
    } finally {
      if (mounted) setState(() => _loadingApproverStatus = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final user = storage.read('user');
      final result = await ApiService.getPermissions(user['id']);
      if (mounted) {
        setState(() {
          _myPermissions = result;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch permissions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  int _usedMinutesForMonth(DateTime monthRef) {
    int used = 0;
    for (var p in _myPermissions) {
      if (p['status'] == 'rejected') continue;
      final dt = DateTime.tryParse(p['date'] ?? '') ?? DateTime(0);
      if (dt.year == monthRef.year && dt.month == monthRef.month) {
        used += (p['permission_minutes'] ?? 0) as int;
      }
    }
    return used;
  }

  int get _usedMinutesThisMonth => _usedMinutesForMonth(_selectedDate);

  int get _remainingMinutes =>
      (180 - _usedMinutesForMonth(_selectedDate)).clamp(0, 180);

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_reasonController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a reason',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_hasAcceptAccess && _fixedApprovers.isEmpty) {
      Get.snackbar(
        'Error',
        'No approver hierarchy found. Please contact your admin to set your reporting hierarchy.',
        backgroundColor: _red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
      return;
    }

    // Validate approver selection
    if (!_hasAcceptAccess &&
        _fixedApprovers.isEmpty &&
        _selectedApproverId == null) {
      Get.snackbar(
        'Error',
        'Please select an approver',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_selectedMinutes > _remainingMinutes) {
      Get.snackbar(
        'Limit Exceeded',
        'You only have $_remainingMinutes mins remaining for the selected month.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = storage.read('user');
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      await ApiService.requestPermission({
        'user_id': user['id'],
        'date': dateStr,
        'permission_minutes': _selectedMinutes,
        'permission_type': _selectedType,
        'reason': _reasonController.text.trim(),
        'approver_id': _selectedApproverId,
      });

      Get.snackbar(
        'Success',
        'Permission requested successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      _reasonController.clear();
      _selectedApproverId = null; // Clear selected approver
      await _fetchHistory();
      setState(() => _tab = 1); // Switch to history tab on success
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _setTab(int i) {
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
    if (i == 1) _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [_buildApplyTab(), _buildHistoryTab()],
                  ),
                ),
              ],
            ),
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _black,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff Permissions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _black,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _tab == 0 ? 'Request time off' : 'View your history',
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
            onTap: _fetchHistory,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _lightGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.refresh_rounded, color: _black, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyTab() {
    final bool showHierarchyMissing =
        _hasAcceptAccess && !_loadingApproverStatus && _fixedApprovers.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHierarchyMissing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _red.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: _red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Reporting hierarchy not set',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please contact your admin to set your reporting hierarchy before applying for permission.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_charcoal, _black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_remainingMinutes',
                          style: const TextStyle(
                            color: _pureWhite,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'mins',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_usedMinutesThisMonth mins used',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '180 mins total',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Date',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final today = DateTime.now();
              final first = DateTime(today.year, today.month, today.day);
              if (_selectedDate.isBefore(first)) {
                setState(() => _selectedDate = first);
              }
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: first,
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _pureWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lightGray),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: _black,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Duration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightGray),
            ),
            child: () {
              // Calculate max allowed based on balance and 30-min steps
              final int maxAllowed = (_remainingMinutes ~/ 30) * 30;

              if (maxAllowed < 30) {
                return Column(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Insufficient Balance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You only have $_remainingMinutes mins remaining for the selected month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _mediumGray),
                    ),
                  ],
                );
              }

              // Ensure _selectedMinutes is within new bounds if it was higher before
              if (_selectedMinutes > maxAllowed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedMinutes = maxAllowed);
                });
              }
              if (_selectedMinutes < 30) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedMinutes = 30);
                });
              }

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        () {
                          int h = _selectedMinutes ~/ 60;
                          int m = _selectedMinutes % 60;
                          if (h == 0) return '$m mins';
                          if (m == 0) return '$h hr${h > 1 ? 's' : ''}';
                          return '$h hr $m mins';
                        }(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Available',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _black,
                      inactiveTrackColor: _lightGray,
                      thumbColor: _black,
                      overlayColor: _black.withOpacity(0.1),
                      valueIndicatorColor: _black,
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Slider(
                      value: _selectedMinutes.toDouble().clamp(
                        30.0,
                        maxAllowed.toDouble(),
                      ),
                      min: 30,
                      max: maxAllowed.toDouble(),
                      divisions: maxAllowed > 30 ? (maxAllowed - 30) ~/ 30 : 1,
                      label: '${_selectedMinutes}m',
                      onChanged: (v) =>
                          setState(() => _selectedMinutes = v.round()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '30m',
                          style: TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${maxAllowed}m',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }(),
          ),
          const SizedBox(height: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _pureWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _lightGray),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _mediumGray,
                    ),
                    items: _types.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _charcoal,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Reason',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _lightGray),
            ),
            child: TextField(
              controller: _reasonController,
              maxLines: 3,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: _charcoal,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter reason for permission...',
                hintStyle: TextStyle(
                  color: _mediumGray,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          // ── Approver Selection ─────────────────────────────────────
          if (!_loadingApproverStatus &&
              _fixedApprovers.isEmpty &&
              _potentialApprovers.isNotEmpty &&
              !_hasAcceptAccess) ...[
            const SizedBox(height: 24),
            _buildSectionLabel('Send Request To'),
            const SizedBox(height: 8),
            _approverSelectorButton(),
          ] else if (!_loadingApproverStatus && _fixedApprovers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel('Reporting To'),
            const SizedBox(height: 8),
            _buildFixedApproversInfo(),
          ],

          const SizedBox(height: 32),

          SwipeToConfirm(
            label: 'Swipe to Submit Request',
            icon: Icons.send_rounded,
            color: _black,
            loading: _isSubmitting,
            onConfirmed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _black));
    }

    if (_myPermissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: _lightGray),
            const SizedBox(height: 16),
            const Text(
              'No permissions found',
              style: TextStyle(
                color: _mediumGray,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
      itemCount: _myPermissions.length,
      itemBuilder: (context, index) {
        final p = _myPermissions[index];
        final status = p['status'].toString();
        final isPending = status == 'pending';
        final isAppr = status == 'approved';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _lightGray.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: _charcoal,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              () {
                                try {
                                  final d = p['date'].toString();
                                  return DateFormat(
                                    'dd MMM yyyy',
                                  ).format(DateTime.parse(d).toLocal());
                                } catch (e) {
                                  return p['date'].toString();
                                }
                              }(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _charcoal,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${p['permission_minutes']} mins • ${_types[p['permission_type']]}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPending
                            ? _orange.withOpacity(0.1)
                            : isAppr
                            ? _green.withOpacity(0.1)
                            : _red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isPending
                              ? _orange
                              : isAppr
                              ? _green
                              : _red,
                        ),
                      ),
                    ),
                  ],
                ),
                if (p['reason'] != null &&
                    p['reason'].toString().isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Divider(height: 1, color: _bg),
                  ),
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontSize: 11,
                      color: _mediumGray.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p['reason'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: _charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (!isPending &&
                    p['admin_note'] != null &&
                    p['admin_note'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Note:',
                          style: TextStyle(
                            fontSize: 10,
                            color: _mediumGray.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p['admin_note'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: _charcoal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDock() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 32,
                right: 32,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
                top: 8,
                bottom: 8,
                left: _dockPillLeft(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutQuart,
                  width: _dockPillWidth(),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _dockItem(
                    0,
                    Icons.add_circle_rounded,
                    Icons.add_circle_outline_rounded,
                    'Apply',
                  ),
                  _dockDivider(),
                  _dockItem(
                    1,
                    Icons.history_rounded,
                    Icons.history_outlined,
                    'History',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dockPillLeft() {
    const padding = 8.0;
    final width = (MediaQuery.of(context).size.width - 48);
    final itemWidth = (width - 1) / 2;
    return padding + _tab * (itemWidth + 1.0);
  }

  double _dockPillWidth() {
    final width = (MediaQuery.of(context).size.width - 48);
    return (width - 1) / 2 - 16;
  }

  Widget _dockItem(
    int index,
    IconData active,
    IconData inactive,
    String label,
  ) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _setTab(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                isActive ? active : inactive,
                key: ValueKey(isActive),
                color: isActive ? _black : _mediumGray,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? _black : _mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockDivider() => Container(
    width: 1,
    height: 32,
    color: Colors.black.withValues(alpha: 0.05),
  );

  Widget _approverSelectorButton() {
    final selectedApprover = _potentialApprovers.firstWhere(
      (appr) => appr['id'] == _selectedApproverId,
      orElse: () => {},
    );
    final isSelected = selectedApprover.isNotEmpty;

    return InkWell(
      onTap: _showApproverBottomSheet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _black : _lightGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.person_search_rounded,
              size: 22,
              color: isSelected ? _green : _mediumGray,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: isSelected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected approver',
                          style: TextStyle(
                            fontSize: 11,
                            color: _mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${selectedApprover['employee_name'] ?? selectedApprover['username']} (${selectedApprover['designation'] ?? selectedApprover['role']})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _black,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Tap to select an approver',
                      style: TextStyle(
                        fontSize: 15,
                        color: _charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: _mediumGray,
            ),
          ],
        ),
      ),
    );
  }

  void _showApproverBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApproverBottomSheet(
        approvers: _potentialApprovers,
        selectedApproverId: _selectedApproverId,
        onApproverSelected: (id) {
          setState(() => _selectedApproverId = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildFixedApproversInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        children: _fixedApprovers.map((appr) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: _charcoal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${appr['employee_name'] ?? appr['username']} (${appr['designation'] ?? appr['role']})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle_outline, size: 16, color: _green),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _charcoal,
      ),
    );
  }
}

class _ApproverBottomSheet extends StatefulWidget {
  final List<dynamic> approvers;
  final int? selectedApproverId;
  final Function(int) onApproverSelected;

  const _ApproverBottomSheet({
    required this.approvers,
    required this.selectedApproverId,
    required this.onApproverSelected,
  });

  @override
  State<_ApproverBottomSheet> createState() => _ApproverBottomSheetState();
}

class _ApproverBottomSheetState extends State<_ApproverBottomSheet> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Colors matching PermissionPage palette
  static const Color _black = Color(0xFF1D1D1F);
  static const Color _charcoal = Color(0xFF333333);
  static const Color _mediumGray = Color(0xFF8E8E93);
  static const Color _lightGray = Color(0xFFE5E5EA);
  static const Color _offWhite = Color(0xFFF2F2F7);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _softGray = Color(0xFFF5F5F7);

  @override
  Widget build(BuildContext context) {
    final filtered = widget.approvers.where((a) {
      final name = (a['employee_name'] ?? '').toString().toLowerCase();
      final username = (a['username'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Approver',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _softGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or username...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _mediumGray,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No approvers found',
                      style: TextStyle(color: _mediumGray),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final approver = filtered[index];
                      final isSelected =
                          approver['id'] == widget.selectedApproverId;
                      return InkWell(
                        onTap: () => widget.onApproverSelected(approver['id']),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _black.withOpacity(0.05)
                                : _softGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _charcoal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    (approver['employee_name'] ??
                                            approver['username'] ??
                                            '?')
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _pureWhite,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      approver['employee_name'] ??
                                          approver['username'] ??
                                          'Unknown',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          approver['designation'] ??
                                              approver['role'] ??
                                              'N/A',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: _mediumGray,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _black.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '@${approver['username'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _black,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: _black,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
