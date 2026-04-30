import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/leave_calendar_widget.dart';
import '../controllers/leave_calendar_controller.dart';
import '../widgets/swipe_to_confirm.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage>
    with SingleTickerProviderStateMixin {
  final storage = GetStorage();

  // ── Palette: Charcoal / Black / White (core) ──────────────────────────────
  static const Color _black = Color(0xFF111111);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _darkGray = Color(0xFF4A4A4A);
  static const Color _mediumGray = Color(0xFF888888);
  static const Color _lightGray = Color(0xFFD8D8D8);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _offWhite = Color(0xFFF7F7F7);
  static const Color _pureWhite = Color(0xFFFFFFFF);

  // ── Functional accent colors (used only where meaning requires it) ─────────
  static const Color _elBlue = Color(0xFF1565C0); // EL — Earned Leave
  static const Color _clTeal = Color(0xFF00796B); // CL — Casual Leave
  static const Color _statusGreen = Color(0xFF2E7D32); // Approved
  static const Color _statusAmber = Color(0xFFE65100); // Pending
  static const Color _softRed = Color(0xFFC62828); // Rejected / danger

  late TabController _tabCtrl;

  // balance
  Map<String, dynamic>? _balance;
  bool _loadingBalance = true;

  // leave history
  List<dynamic> _requests = [];
  bool _loadingRequests = true;

  bool get _hasPendingRequest {
    return _requests.any(
      (req) => (req['status'] as String? ?? 'pending') == 'pending',
    );
  }

  // apply-leave form
  DateTime? _fromDate;
  DateTime? _toDate;
  double _computedDays = 0;
  double _elDays = 0;
  double _clDays = 0;
  bool _isHalfDay = false;
  String _selectedSession = 'first_half';
  String _reason = '';
  bool _submitting = false;

  int? _editingRequestId;

  final Set<int> _expandedRequestIds = <int>{};

  // ── Approver Logic ────────────────────────────────────────────────────────
  List<dynamic> _fixedApprovers = [];
  List<dynamic> _potentialApprovers = [];
  int? _selectedApproverId;
  bool _loadingApproverStatus = true;
  bool _hasAcceptAccess = false;
  bool _approverLoadError = false;
  int _approverRetryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    final user = storage.read('user') ?? {};
    final role = user['role'] as String? ?? 'single user';
    _hasAcceptAccess =
        user['accept_access'] == 1 || user['accept_access'] == true;
    final bool canReview =
        role == 'admin' || role == 'manager' || _hasAcceptAccess;

    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBalance();
    _loadRequests();
    _loadApproverStatus();
  }

  Future<void> _loadApproverStatus() async {
    if (!mounted) return;
    setState(() => _loadingApproverStatus = true);
    setState(() => _approverLoadError = false);
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
            _approverRetryCount = 0;
            final hasSelected = _selectedApproverId != null;
            final selectedStillValid =
                hasSelected &&
                _potentialApprovers.any((a) => a['id'] == _selectedApproverId);
            if (!selectedStillValid) {
              _selectedApproverId = null; // User must manually select
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fixedApprovers = fixed;
            _potentialApprovers = [];
            // Keep any previous manual selection intact; fixed approvers are handled by backend hierarchy
            _approverRetryCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading approver status: $e');
      if (mounted) {
        setState(() {
          _approverLoadError = true;
          _approverRetryCount++;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingApproverStatus = false);
    }
  }

  List<dynamic> _reviewRequests = [];
  bool _loadingReview = true;

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────

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

  // ── Pick date range ───────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final controller = Get.put(LeaveCalendarController());

    final user = storage.read('user');
    if (user != null) {
      await controller.fetchApprovedLeaveDays(user['id'] as int);
    }
    controller.isHalfDayMode.value = _isHalfDay;

    if (_fromDate != null) {
      controller.rangeStart.value = DateTime(
        _fromDate!.year,
        _fromDate!.month,
        _fromDate!.day,
      );
      if (_toDate != null) {
        controller.rangeEnd.value = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
        );
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: LeaveCalendarWidget(
            controller: controller,
            onRangeConfirmed: (start, end, workingDays) {
              setState(() {
                _fromDate = start;
                _toDate = end;
                _computedDays = _isHalfDay ? 0.5 : workingDays.toDouble();
                _elDays = 0;
                _clDays = 0;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );

    Get.delete<LeaveCalendarController>();
  }

  // ── Submit leave ──────────────────────────────────────────────────────────

  Future<void> _submitLeave() async {
    if (_submitting) return;
    final user = storage.read('user');
    if (user == null || _fromDate == null || _toDate == null) return;

    if (_reason.trim().isEmpty) {
      _snack('Please provide a reason for your leave', isError: true);
      return;
    }

    // Validate approver selection for new requests
    // Skip if user has accept_access (handled by backend hierarchy)
    if (_hasAcceptAccess &&
        _editingRequestId == null &&
        _fixedApprovers.isEmpty) {
      _snack(
        'No approver hierarchy found. Please contact your admin to set your reporting hierarchy.',
        isError: true,
      );
      return;
    }

    if (!_hasAcceptAccess &&
        _editingRequestId == null &&
        _fixedApprovers.isEmpty &&
        _selectedApproverId == null) {
      _snack(
        'Please select an approver to send your request to',
        isError: true,
      );
      return;
    }

    final double totalRequested = _elDays + _clDays;
    final double maxAllowed = _isHalfDay ? 0.5 : _computedDays;

    if (totalRequested > maxAllowed) {
      _snack('EL + CL days cannot exceed $maxAllowed', isError: true);
      return;
    }

    final String sessionToSend = _isHalfDay
        ? (_selectedSession == 'full' ? 'first_half' : _selectedSession)
        : 'full';

    final int? fallbackFixedApproverId = _fixedApprovers.isNotEmpty
        ? (_fixedApprovers.first['id'] as int?)
        : null;

    final int? approverIdToSend = !_hasAcceptAccess
        ? (_selectedApproverId ?? fallbackFixedApproverId)
        : null;

    print(
      'DEBUG LEAVE SUBMIT: hasAcceptAccess=$_hasAcceptAccess selectedApproverId=$_selectedApproverId selectedType=${_selectedApproverId.runtimeType} fixedCount=${_fixedApprovers.length} fallbackFixedApproverId=$fallbackFixedApproverId approverIdToSend=$approverIdToSend sessionToSend=$sessionToSend',
    );

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
      if (_editingRequestId != null) {
        await ApiService.updateLeaveRequest(
          requestId: _editingRequestId!,
          fromDate: DateFormat('yyyy-MM-dd').format(_fromDate!),
          toDate: _isHalfDay
              ? DateFormat('yyyy-MM-dd').format(_fromDate!)
              : DateFormat('yyyy-MM-dd').format(_toDate!),
          elDays: _elDays,
          clDays: _clDays,
          reason: _reason.isEmpty ? null : _reason,
          session: _isHalfDay ? _selectedSession : 'full',
        );
        _snack('Leave request updated successfully', isError: false);
      } else {
        final result = await ApiService.submitLeaveRequest(
          userId: user['id'],
          fromDate: DateFormat('yyyy-MM-dd').format(_fromDate!),
          toDate: _isHalfDay
              ? DateFormat('yyyy-MM-dd').format(_fromDate!)
              : DateFormat('yyyy-MM-dd').format(_toDate!),
          elDays: _elDays,
          clDays: _clDays,
          reason: _reason.isEmpty ? null : _reason,
          approverId: _hasAcceptAccess
              ? null
              : (_selectedApproverId ?? fallbackFixedApproverId),
          session: sessionToSend,
        );
        _snack(
          'Leave submitted — ${result['totalDays']} day(s) applied',
          isError: false,
        );
      }
      setState(() {
        _fromDate = null;
        _toDate = null;
        _computedDays = 0;
        _elDays = 0;
        _clDays = 0;
        _reason = '';
        _submitting = false;
        _editingRequestId = null;
      });
      _loadRequests();
      _loadBalance();
    } catch (e) {
      setState(() => _submitting = false);
      _snack(e.toString(), isError: true);
    }
  }

  // ── Edit request ──────────────────────────────────────────────────────────

  void _editRequest(Map<String, dynamic> req) {
    setState(() {
      _editingRequestId = req['id'] as int;
      _fromDate = DateTime.parse(req['from_date'].toString().substring(0, 10));
      _toDate = DateTime.parse(req['to_date'].toString().substring(0, 10));
      _elDays = double.tryParse(req['el_days'].toString()) ?? 0.0;
      _clDays = double.tryParse(req['cl_days'].toString()) ?? 0.0;
      _computedDays = double.tryParse(req['total_days'].toString()) ?? 0.0;
      _isHalfDay = _computedDays == 0.5;
      _selectedSession = req['session']?.toString() ?? 'full';
      _reason = req['reason']?.toString() ?? '';
    });
    _tabCtrl.animateTo(0);
  }

  // ── Delete request ────────────────────────────────────────────────────────

  Future<void> _deleteRequest(int requestId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Request',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _black,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this leave request? This cannot be undone.',
          style: TextStyle(fontSize: 15, color: _darkGray, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _lightGray, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _darkGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await ApiService.deleteLeaveRequest(requestId);
                      _snack('Leave request deleted', isError: false);
                      _loadRequests();
                    } catch (e) {
                      _snack(e.toString(), isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _softRed,
                    foregroundColor: _pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: _pureWhite,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _softRed : _statusGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleRequestExpanded(int requestId) {
    setState(() {
      if (_expandedRequestIds.contains(requestId)) {
        _expandedRequestIds.remove(requestId);
      } else {
        _expandedRequestIds.add(requestId);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    await Future.wait([_loadBalance(), _loadRequests(), _loadApproverStatus()]);
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
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (context, _) {
              final subtitle = _tabCtrl.index == 0
                  ? 'Request Day off'
                  : 'View your history';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Leaves',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _mediumGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          GestureDetector(
            onTap: _refresh,
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _offWhite,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
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

  // ── High-Aesthetic Floating Dock ──────────────────────────────────────────

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
              AnimatedBuilder(
                animation: _tabCtrl,
                builder: (context, child) => AnimatedPositioned(
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
              ),
              Row(
                children: [
                  _dockItem(
                    0,
                    Icons.edit_calendar_rounded,
                    Icons.edit_calendar_outlined,
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
    return padding + _tabCtrl.index * (itemWidth + 1.0);
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
    return Expanded(
      child: AnimatedBuilder(
        animation: _tabCtrl,
        builder: (context, child) {
          final isActive = _tabCtrl.index == index;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _tabCtrl.animateTo(index);
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
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? _black : _mediumGray,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dockDivider() => Container(
    width: 1,
    height: 32,
    color: Colors.black.withValues(alpha: 0.05),
  );

  // ── Apply Tab ─────────────────────────────────────────────────────────────

  Widget _buildApplyTab() {
    final elBal = (_balance?['el_balance'] ?? 0).toDouble();
    final clBal = (_balance?['cl_balance'] ?? 0).toDouble();
    final bool isLocked = _hasPendingRequest && _editingRequestId == null;

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
                color: _softRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _softRed.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _softRed,
                    size: 20,
                  ),
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
                          'Please contact your admin to set your reporting hierarchy before applying for leave.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _darkGray,
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
          // ── Balance Cards ──────────────────────────────────────────────
          if (_loadingBalance)
            _loadingPlaceholder(height: 96)
          else
            Row(
              children: [
                Expanded(child: _balanceCard('Earned Leave', elBal, _elBlue)),
                const SizedBox(width: 12),
                Expanded(child: _balanceCard('Casual Leave', clBal, _clTeal)),
              ],
            ),

          const SizedBox(height: 28),

          // ── Pending Warning ────────────────────────────────────────────
          if (isLocked) ...[
            _pendingWarningBanner(),
            const SizedBox(height: 24),
          ],

          // ── Editing Banner ─────────────────────────────────────────────
          if (_editingRequestId != null) ...[
            _editingBanner(),
            const SizedBox(height: 24),
          ],

          // ── Date Selection ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Select Date'),
              Row(
                children: [
                  const Text(
                    'Half Day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mediumGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _isHalfDay,
                    activeColor: _black,
                    onChanged: (v) => setState(() {
                      _isHalfDay = v;
                      _fromDate = null;
                      _toDate = null;
                      _computedDays = 0;
                      _elDays = 0;
                      _clDays = 0;
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _dateSelectorButton(isLocked: isLocked),

          // ── Sandwich info ──────────────────────────────────────────────
          if (_computedDays > 0) ...[
            const SizedBox(height: 10),
            _sandwichInfoBanner(),
          ],

          // ── Leave Type Split ───────────────────────────────────────────
          if (_computedDays > 0) ...[
            const SizedBox(height: 28),
            _sectionLabel('Split Leave Type'),
            const SizedBox(height: 6),
            Text(
              'EL + CL days must be ≤ $_computedDays day${_computedDays == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 14,
                color: _mediumGray,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _leaveTypeInput(
                    label: 'EL Days',
                    sublabel: 'Earned Leave',
                    value: _elDays,
                    max: elBal,
                    accentColor: _elBlue,
                    onChanged: (v) => setState(() => _elDays = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _leaveTypeInput(
                    label: 'CL Days',
                    sublabel: 'Casual Leave',
                    value: _clDays,
                    max: clBal,
                    accentColor: _clTeal,
                    onChanged: (v) => setState(() => _clDays = v),
                  ),
                ),
              ],
            ),

            // Running total
            const SizedBox(height: 14),
            if (_isHalfDay) ...[
              const Text(
                'Select Session',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _black,
                ),
              ),
              const SizedBox(height: 10),
              _sessionSelector(),
              const SizedBox(height: 16),
            ],
            _totalValidationRow(),

            // ── Reason ─────────────────────────────────────────────────
            const SizedBox(height: 28),
            _sectionLabel('Reason *'),
            const SizedBox(height: 4),
            const Text(
              'Required',
              style: TextStyle(fontSize: 13, color: _mediumGray),
            ),
            const SizedBox(height: 10),
            _reasonField(),

            // ── Approver Selection ─────────────────────────────────────
            if (_loadingApproverStatus) ...[
              const SizedBox(height: 28),
              _sectionLabel('Send Request To'),
              const SizedBox(height: 10),
              _loadingPlaceholder(height: 60),
            ] else if (_approverLoadError) ...[
              const SizedBox(height: 28),
              _sectionLabel('Send Request To'),
              const SizedBox(height: 4),
              const Text(
                'Could not load approvers',
                style: TextStyle(fontSize: 13, color: _mediumGray),
              ),
              const SizedBox(height: 10),
              _approverErrorWidget(),
            ] else if (_fixedApprovers.isNotEmpty) ...[
              const SizedBox(height: 28),
              _sectionLabel('Reporting To'),
              const SizedBox(height: 10),
              _fixedApproversInfo(),
            ] else if (!_hasAcceptAccess && _potentialApprovers.isNotEmpty) ...[
              const SizedBox(height: 28),
              _sectionLabel('Send Request To *'),
              const SizedBox(height: 4),
              const Text(
                'Select the person who should review your leave',
                style: TextStyle(fontSize: 13, color: _mediumGray),
              ),
              const SizedBox(height: 10),
              _approverSelectorButton(),
            ],

            // ── Submit / Update ────────────────────────────────────────
            const SizedBox(height: 28),
            _submitRow(isLocked: isLocked),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _approverErrorWidget() {
    final canRetry = _approverRetryCount < _maxRetries;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: _softRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to load approvers',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _darkGray,
                  ),
                ),
              ),
            ],
          ),
          if (canRetry) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadApproverStatus,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry (${_approverRetryCount}/$_maxRetries)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _black,
                foregroundColor: _pureWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Please check your connection and try again later',
              style: TextStyle(fontSize: 12, color: _mediumGray),
            ),
          ],
        ],
      ),
    );
  }

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
            color: isSelected ? _charcoal : _lightGray,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.person_search_rounded,
              size: 22,
              color: isSelected ? _statusGreen : _mediumGray,
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
                  : Text(
                      'Tap to select an approver',
                      style: TextStyle(
                        fontSize: 15,
                        color: _darkGray,
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
          print(
            'DEBUG LEAVE: onApproverSelected id=$id type=${id.runtimeType}',
          );
          setState(() => _selectedApproverId = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _fixedApproversInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Column(
        children: _fixedApprovers.map((appr) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: _darkGray),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${appr['employee_name'] ?? appr['username']} (${appr['designation'] ?? appr['role']})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _darkGray,
                    ),
                  ),
                ),
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: _statusGreen,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Reusable UI Pieces ─────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: _black,
      letterSpacing: -0.3,
    ),
  );

  Widget _loadingPlaceholder({double height = 80}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: _softGray,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: CircularProgressIndicator(color: _charcoal, strokeWidth: 2),
    ),
  );

  /// Balance card — coloured accent number on white card
  Widget _balanceCard(String title, double balance, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            balance.toStringAsFixed(1).replaceAll('.0', ''),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'days available',
            style: TextStyle(fontSize: 12, color: _mediumGray),
          ),
        ],
      ),
    );
  }

  /// Pending leave warning — charcoal banner, no orange
  Widget _pendingWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _pureWhite.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  size: 22,
                  color: _pureWhite,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _pureWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'You have a leave request awaiting approval',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBBBBBB),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _tabCtrl.animateTo(1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pureWhite,
                    side: const BorderSide(
                      color: Color(0xFF666666),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'View Request',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final pendingReq = _requests.firstWhere(
                      (r) => (r['status'] as String? ?? 'pending') == 'pending',
                      orElse: () => {},
                    );
                    if (pendingReq.isNotEmpty) _editRequest(pendingReq);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pureWhite,
                    foregroundColor: _black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Edit Request',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Editing mode banner
  Widget _editingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lightGray, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: _darkGray),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Editing existing request',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkGray,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _editingRequestId = null;
              _fromDate = null;
              _toDate = null;
              _computedDays = 0;
              _elDays = 0;
              _clDays = 0;
              _reason = '';
            }),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _mediumGray,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Date selector button
  Widget _dateSelectorButton({required bool isLocked}) {
    final hasRange = _fromDate != null && _toDate != null;
    final fromStr = hasRange
        ? DateFormat('dd MMM yyyy').format(_fromDate!)
        : null;
    final toStr = hasRange ? DateFormat('dd MMM yyyy').format(_toDate!) : null;

    return Semantics(
      button: true,
      label: isLocked
          ? 'Date selection locked due to pending request'
          : hasRange
          ? 'Selected dates: $fromStr to $toStr. Tap to change.'
          : 'Tap to select leave date range',
      child: InkWell(
        onTap: isLocked ? null : () => _pickDateRange(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLocked ? _softGray : _pureWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLocked ? _lightGray : _charcoal,
              width: isLocked ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isLocked
                    ? Icons.lock_outline_rounded
                    : Icons.calendar_month_outlined,
                size: 22,
                color: isLocked ? _mediumGray : _black,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: hasRange
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected dates',
                            style: TextStyle(
                              fontSize: 11,
                              color: _mediumGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$fromStr  →  $toStr',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _black,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        isLocked
                            ? 'Locked — pending request active'
                            : 'Tap to choose dates',
                        style: TextStyle(
                          fontSize: 15,
                          color: isLocked ? _mediumGray : _darkGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (!isLocked)
                Icon(
                  hasRange ? Icons.edit_outlined : Icons.chevron_right_rounded,
                  size: 20,
                  color: _mediumGray,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sandwich rule info
  Widget _sandwichInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lightGray),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: _darkGray),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: _darkGray,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$_computedDays day${_computedDays == 1 ? '' : 's'} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _black,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'counted — sandwich rule applied (holidays & Sundays between leave days are included)',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Leave type counter input
  Widget _leaveTypeInput({
    required String label,
    required String sublabel,
    required double value,
    required double max,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    final bool canDecrement = value > 0;
    final bool canIncrement =
        value < max && (_elDays + _clDays) < _computedDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 11, color: _mediumGray),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _counterBtn(
                icon: Icons.remove_rounded,
                enabled: canDecrement,
                onTap: canDecrement
                    ? () {
                        HapticFeedback.lightImpact();
                        onChanged(value - 0.5);
                      }
                    : null,
              ),
              Text(
                value.toStringAsFixed(1).replaceAll('.0', ''),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: -1,
                ),
              ),
              _counterBtn(
                icon: Icons.add_rounded,
                enabled: canIncrement,
                onTap: canIncrement
                    ? () {
                        HapticFeedback.lightImpact();
                        onChanged(value + 0.5);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${max.toStringAsFixed(1).replaceAll('.0', '')} available',
            style: const TextStyle(fontSize: 12, color: _mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _sessionSelector() {
    return Row(
      children: [
        Expanded(
          child: _sessionBtn(
            label: 'First Half',
            sub: 'Morning',
            value: 'first_half',
            isSelected: _selectedSession == 'first_half',
            onTap: () => setState(() => _selectedSession = 'first_half'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _sessionBtn(
            label: 'Second Half',
            sub: 'Afternoon',
            value: 'second_half',
            isSelected: _selectedSession == 'second_half',
            onTap: () => setState(() => _selectedSession = 'second_half'),
          ),
        ),
      ],
    );
  }

  Widget _sessionBtn({
    required String label,
    required String sub,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _black : _pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _black : _lightGray,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? _pureWhite : _black,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? _lightGray : _mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterBtn({
    required IconData icon,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? _black : _softGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: enabled ? _pureWhite : _lightGray),
        ),
      ),
    );
  }

  Widget _totalValidationRow() {
    final total = _elDays + _clDays;
    final isValid = total == _computedDays;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isValid
            ? _statusGreen.withOpacity(0.06)
            : total > 0
            ? _softRed.withOpacity(0.06)
            : _softGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? _statusGreen.withOpacity(0.3)
              : total > 0
              ? _softRed.withOpacity(0.25)
              : _lightGray,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isValid
                ? _statusGreen
                : total > 0
                ? _softRed
                : _mediumGray,
          ),
          const SizedBox(width: 8),
          Text(
            'Total allocated: ${total.toStringAsFixed(1).replaceAll('.0', '')} / ${(_computedDays).toStringAsFixed(1).replaceAll('.0', '')} day${_computedDays == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isValid
                  ? _statusGreen
                  : total > 0
                  ? _softRed
                  : _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonField() {
    return TextField(
      maxLines: 3,
      onChanged: (v) => _reason = v,
      style: const TextStyle(fontSize: 15, color: _black, height: 1.5),
      decoration: InputDecoration(
        hintText: 'e.g. Family function, Personal work...',
        hintStyle: const TextStyle(color: _lightGray, fontSize: 14),
        filled: true,
        fillColor: _pureWhite,
        contentPadding: const EdgeInsets.all(16),
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
          borderSide: const BorderSide(color: _black, width: 1.5),
        ),
      ),
    );
  }

  Widget _submitRow({required bool isLocked}) {
    final bool canSubmit =
        !_submitting &&
        !isLocked &&
        (_elDays + _clDays) > 0 &&
        (_elDays + _clDays) <= _computedDays &&
        _computedDays > 0;

    return Column(
      children: [
        SwipeToConfirm(
          label: _editingRequestId != null
              ? 'Swipe to Update Request'
              : 'Swipe to Submit Leave',
          icon: Icons.calendar_month_rounded,
          color: canSubmit ? _black : _lightGray,
          loading: _submitting,
          onConfirmed: () {
            if (canSubmit) {
              _submitLeave();
            } else {
              _snack(
                'Please fill all required fields correctly',
                isError: true,
              );
            }
          },
        ),
        if (_editingRequestId != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() {
                _editingRequestId = null;
                _fromDate = null;
                _toDate = null;
                _computedDays = 0;
                _elDays = 0;
                _clDays = 0;
                _reason = '';
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _lightGray),
                ),
              ),
              child: const Text(
                'Cancel Edit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _mediumGray,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_loadingRequests) {
      return const Center(
        child: CircularProgressIndicator(color: _charcoal, strokeWidth: 2),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _softGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: _mediumGray,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No requests yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _black,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your submitted leave requests will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _mediumGray, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _charcoal,
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _requestCard(_requests[i]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final requestId = int.tryParse(req['id'].toString()) ?? 0;
    final isExpanded = _expandedRequestIds.contains(requestId);

    DateTime? _parseDate(dynamic val) {
      if (val == null) return null;
      final s = val.toString();
      if (s.length >= 10) return DateTime.parse(s.substring(0, 10));
      return null;
    }

    final fromDt = _parseDate(req['from_date']);
    final toDt = _parseDate(req['to_date']);
    final from = fromDt != null
        ? DateFormat('dd MMM yyyy').format(fromDt)
        : '—';
    final to = toDt != null ? DateFormat('dd MMM yyyy').format(toDt) : '—';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = _statusGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = _softRed;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = _statusAmber;
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = 'Pending';
    }

    final DateTime? createdAt = req['created_at'] != null
        ? DateTime.tryParse(req['created_at'].toString())
        : null;
    final DateTime? reviewedAt = req['reviewed_at'] != null
        ? DateTime.tryParse(req['reviewed_at'].toString())
        : null;

    final createdAtText = createdAt != null
        ? DateFormat('dd MMM yyyy').format(createdAt)
        : '';
    final createdAtFullText = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
        : '';
    final reviewedAtFullText = reviewedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(reviewedAt)
        : '';

    return Semantics(
      label:
          'Leave request #$requestId, status: $statusLabel, from $from to $to',
      child: Container(
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _lightGray, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 15, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Request ID
                  Text(
                    '#$requestId',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _mediumGray,
                    ),
                  ),
                  const Spacer(),
                  // Action buttons for pending
                  if (isPending) ...[
                    _iconActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit request',
                      onTap: () => _editRequest(req),
                    ),
                    const SizedBox(width: 4),
                    _iconActionButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete request',
                      onTap: () => _deleteRequest(req['id'] as int),
                      isDanger: true,
                    ),
                  ] else if (createdAtText.isNotEmpty) ...[
                    Text(
                      createdAtText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _mediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Dates Row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: _mediumGray,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$from  →  $to',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _black,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Leave type vertical card ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _leaveTypeCard(req)),
                  if (req['session'] != null && req['session'] != 'full') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _softGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _lightGray),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: _mediumGray,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            req['session'] == 'first_half'
                                ? 'Morning'
                                : 'Afternoon',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Expand / collapse footer ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _toggleRequestExpanded(requestId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _mediumGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded ? 'Hide details' : 'Show details',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expanded section ──────────────────────────────────────────
            if (isExpanded) ...[
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamps
                    if (createdAtFullText.isNotEmpty)
                      _detailRow(
                        icon: Icons.schedule_rounded,
                        label: 'Applied',
                        value: createdAtFullText,
                      ),
                    if (reviewedAtFullText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _detailRow(
                        icon: Icons.rate_review_outlined,
                        label: 'Reviewed',
                        value: reviewedAtFullText,
                      ),
                    ],
                    // ── Approval Info ──────────────────────────────────────────
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_search_rounded,
                            size: 16,
                            color: _mediumGray,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Target Approver: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: _mediumGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              req['approver_name'] ??
                                  req['approver_username'] ??
                                  'Hierarchy',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (req['reviewed_by_username'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            req['status'] == 'approved'
                                ? 'Approved by: '
                                : 'Rejected by: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: _mediumGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              req['reviewed_by_username'].toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Reason
                    if (req['reason'] != null &&
                        req['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailBlock(
                        icon: Icons.notes_rounded,
                        label: 'Reason',
                        value: req['reason'].toString(),
                      ),
                    ],
                    // Admin note
                    if (req['admin_note'] != null &&
                        req['admin_note'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _detailBlock(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin Note',
                        value: req['admin_note'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDanger ? _softRed.withOpacity(0.07) : _softGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: isDanger ? _softRed : _darkGray),
        ),
      ),
    );
  }

  Widget _leaveTypeCard(Map<String, dynamic> req) {
    final elDays = req['el_days']?.toString() ?? '0';
    final clDays = req['cl_days']?.toString() ?? '0';
    final totalDays = req['total_days']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lightGray, width: 1),
      ),
      child: Row(
        children: [
          // EL column
          Expanded(
            child: _leaveTypeColumn(
              label: 'EL',
              value: elDays,
              accentColor: _elBlue,
            ),
          ),
          const SizedBox(width: 8),
          // CL column
          Expanded(
            child: _leaveTypeColumn(
              label: 'CL',
              value: clDays,
              accentColor: _clTeal,
            ),
          ),
          const SizedBox(width: 8),
          // Total column
          Expanded(
            child: _leaveTypeColumn(
              label: 'Total',
              value: totalDays,
              accentColor: _black,
              isTotal: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveTypeColumn({
    required String label,
    required String value,
    required Color accentColor,
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTotal ? _black : accentColor.withOpacity(0.2),
          width: isTotal ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isTotal ? _black : accentColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isTotal ? _black : accentColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'day${value == '1' ? '' : 's'}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: _mediumGray),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: _mediumGray,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _darkGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailBlock({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _mediumGray),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _mediumGray,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: _charcoal,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
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
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredApprovers = [];
  bool _searchById = false;

  static const Color _black = Color(0xFF111111);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _darkGray = Color(0xFF4A4A4A);
  static const Color _mediumGray = Color(0xFF888888);
  static const Color _lightGray = Color(0xFFD8D8D8);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _pureWhite = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _filteredApprovers = widget.approvers;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (_searchById) {
        _filteredApprovers = widget.approvers.where((appr) {
          final username = (appr['username'] ?? '').toString().toLowerCase();
          return username.startsWith(query);
        }).toList();

        // Sort by username when searching by ID - exact matches first
        if (query.isNotEmpty) {
          _filteredApprovers.sort((a, b) {
            final usernameA = (a['username'] ?? '').toString().toLowerCase();
            final usernameB = (b['username'] ?? '').toString().toLowerCase();
            if (usernameA == query && usernameB != query) return -1;
            if (usernameB == query && usernameA != query) return 1;
            return usernameA.compareTo(usernameB);
          });
        }
      } else {
        _filteredApprovers = widget.approvers.where((appr) {
          final name = (appr['employee_name'] ?? appr['username'] ?? '')
              .toString()
              .toLowerCase();
          final designation = (appr['designation'] ?? appr['role'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(query) || designation.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearchMode(bool isIdMode) {
    setState(() {
      _searchById = isIdMode;
      _searchController.clear();
      _filteredApprovers = widget.approvers;
    });
  }

  Widget _buildToggleBtn(bool isIdMode, String label) {
    final active = _searchById == isIdMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleSearchMode(isIdMode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? _black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _black : _lightGray),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? _pureWhite : _darkGray,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Select Approver',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _darkGray),
                ),
              ],
            ),
          ),
          // Search mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildToggleBtn(false, 'By Name'),
                const SizedBox(width: 8),
                _buildToggleBtn(true, 'By ID'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: _softGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _searchById
                      ? 'Search by Employee ID'
                      : 'Search by name or designation...',
                  hintStyle: const TextStyle(color: _mediumGray),
                  prefixIcon: const Icon(Icons.search, color: _darkGray),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Approver list
          Expanded(
            child: _filteredApprovers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: _lightGray),
                        const SizedBox(height: 12),
                        const Text(
                          'No approvers found',
                          style: TextStyle(fontSize: 16, color: _darkGray),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredApprovers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final approver = _filteredApprovers[index];
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
                                    Text(
                                      approver['designation'] ??
                                          approver['role'] ??
                                          'N/A',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _mediumGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_searchById)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '@${approver['username'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _black,
                                      fontWeight: FontWeight.w600,
                                    ),
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
        ],
      ),
    );
  }
}
