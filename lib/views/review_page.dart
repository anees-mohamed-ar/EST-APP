import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  final storage = GetStorage();
  late TabController _tabCtrl;

  DateTime? _parseDateOnly(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    return DateTime(y, mo, d);
  }

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _black = Color(0xFF111111);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _darkGray = Color(0xFF4A4A4A);
  static const Color _mediumGray = Color(0xFF888888);
  static const Color _lightGray = Color(0xFFD8D8D8);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _offWhite = Color(0xFFF7F7F7);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _softRed = Color(0xFFC62828);
  static const Color _statusGreen = Color(0xFF2E7D32);

  List<dynamic> _leaveRequests = [];
  List<dynamic> _permissionRequests = [];
  List<dynamic> _historyRequests = [];
  bool _loadingLeaves = true;
  bool _loadingPermissions = true;
  bool _loadingHistory = true;
  Set<int> _selectedLeaveIds = {};
  Set<int> _selectedPermissionIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted)
        setState(() {
          if (_tabCtrl.index == 2) _selectionMode = false;
        });
    });
    _fetchLeaves();
    _fetchPermissions();
    _fetchHistory();
  }

  Future<void> _fetchLeaves() async {
    setState(() => _loadingLeaves = true);
    try {
      final user = storage.read('user');
      final data = await ApiService.getAdminLeaveRequests(
        approverId: user['id'],
        status: 'pending',
      );
      if (mounted)
        setState(() {
          _leaveRequests = data;
          _selectedLeaveIds.clear();
        });
    } catch (e) {
      debugPrint('Fetch leave requests error: $e');
    }
    if (mounted) setState(() => _loadingLeaves = false);
  }

  Future<void> _fetchPermissions() async {
    setState(() => _loadingPermissions = true);
    try {
      final user = storage.read('user');
      final data = await ApiService.getAdminPermissionRequests(
        approverId: user['id'],
        status: 'pending',
      );
      if (mounted)
        setState(() {
          _permissionRequests = data;
          _selectedPermissionIds.clear();
        });
    } catch (e) {
      debugPrint('Fetch permission requests error: $e');
    }
    if (mounted) setState(() => _loadingPermissions = false);
  }

  Future<void> _fetchHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final user = storage.read('user') ?? {};
      final userId = user['id'];

      // Fetch leaves and permissions (without pending status to get history)
      final leaves = await ApiService.getAdminLeaveRequests(approverId: userId);
      final permissions = await ApiService.getAdminPermissionRequests(
        approverId: userId,
      );

      // Filter for processed ones
      final pLeaves = leaves.where((r) => r['status'] != 'pending').map((r) {
        r['_type'] = 'leave';
        return r;
      }).toList();

      final pPermissions = permissions
          .where((r) => r['status'] != 'pending')
          .map((r) {
            r['_type'] = 'permission';
            return r;
          })
          .toList();

      final combined = [...pLeaves, ...pPermissions];

      // Sort by reviewed_at or created_at
      combined.sort((a, b) {
        final aDateStr = a['reviewed_at'] ?? a['created_at'] ?? '';
        final bDateStr = b['reviewed_at'] ?? b['created_at'] ?? '';
        final aDate = _parseDateOnly(aDateStr) ?? DateTime(0);
        final bDate = _parseDateOnly(bDateStr) ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      if (mounted) setState(() => _historyRequests = combined);
    } catch (e) {
      debugPrint('History fetch error: $e');
    }
    if (mounted) setState(() => _loadingHistory = false);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _black,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _pureWhite,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _selectionMode ? '${_activeSelectionCount()} Selected' : 'Approvals',
          style: const TextStyle(
            color: _pureWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_selectionMode) _buildSelectAllToggle(),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: _pureWhite,
              onPressed: _exitSelectionMode,
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabCtrl,
            children: [
              _buildLeaveReviewTab(),
              _buildPermissionReviewTab(),
              _buildHistoryTab(),
            ],
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 24,
            right: 24,
            child: _selectionMode ? _buildBulkActionBar() : _buildDock(),
          ),
        ],
      ),
    );
  }

  int _activeSelectionCount() {
    return _tabCtrl.index == 0
        ? _selectedLeaveIds.length
        : _selectedPermissionIds.length;
  }

  Widget _buildSelectAllToggle() {
    final isAllSelected = _isAllSelected();
    return IconButton(
      icon: Icon(
        isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
      ),
      color: _pureWhite,
      onPressed: isAllSelected ? _deselectAll : _selectAll,
      tooltip: isAllSelected ? 'Deselect All' : 'Select All',
    );
  }

  bool _isAllSelected() {
    if (_tabCtrl.index == 0) {
      return _leaveRequests.isNotEmpty &&
          _selectedLeaveIds.length == _leaveRequests.length;
    } else {
      return _permissionRequests.isNotEmpty &&
          _selectedPermissionIds.length == _permissionRequests.length;
    }
  }

  void _selectAll() {
    setState(() {
      if (_tabCtrl.index == 0) {
        _selectedLeaveIds = _leaveRequests.map((r) => r['id'] as int).toSet();
      } else {
        _selectedPermissionIds = _permissionRequests
            .map((r) => r['id'] as int)
            .toSet();
      }
    });
  }

  void _deselectAll() {
    setState(() {
      if (_tabCtrl.index == 0) {
        _selectedLeaveIds.clear();
      } else {
        _selectedPermissionIds.clear();
      }
      _selectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedLeaveIds.clear();
      _selectedPermissionIds.clear();
    });
  }

  void _toggleSelection(int id, bool isLeave) {
    setState(() {
      if (isLeave) {
        if (_selectedLeaveIds.contains(id)) {
          _selectedLeaveIds.remove(id);
        } else {
          _selectedLeaveIds.add(id);
        }
      } else {
        if (_selectedPermissionIds.contains(id)) {
          _selectedPermissionIds.remove(id);
        } else {
          _selectedPermissionIds.add(id);
        }
      }

      if (_selectedLeaveIds.isEmpty && _selectedPermissionIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Widget _buildBulkActionBar() {
    final count = _activeSelectionCount();
    if (count == 0) return const SizedBox.shrink();

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => _handleBulkReview('rejected'),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              label: const Text(
                'Reject All',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          Expanded(
            child: TextButton.icon(
              onPressed: () => _handleBulkReview('approved'),
              icon: const Icon(Icons.check_rounded, color: Colors.white70),
              label: const Text(
                'Approve All',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkReview(String status) async {
    final isLeave = _tabCtrl.index == 0;
    final ids = isLeave
        ? _selectedLeaveIds.toList()
        : _selectedPermissionIds.toList();

    if (ids.isEmpty) return;

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text(status == 'approved' ? 'Bulk Approve' : 'Bulk Reject'),
        content: Text(
          'Are you sure you want to $status ${ids.length} requests?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? _statusGreen : _softRed,
              foregroundColor: Colors.white,
            ),
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    Get.showOverlay(
      asyncFunction: () async {
        for (final id in ids) {
          await _handleReview(id, status, isLeave: isLeave, silent: true);
        }
        await (isLeave ? _fetchLeaves() : _fetchPermissions());
        _exitSelectionMode();
        Get.snackbar(
          'Success',
          'Processed ${ids.length} requests',
          backgroundColor: _black,
          colorText: _pureWhite,
        );
      },
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
                    Icons.beach_access_rounded,
                    Icons.beach_access_outlined,
                    'Leaves',
                  ),
                  _dockDivider(),
                  _dockItem(
                    1,
                    Icons.timer_rounded,
                    Icons.timer_outlined,
                    'Permissions',
                  ),
                  _dockDivider(),
                  _dockItem(
                    2,
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
    final itemWidth = (width - 2) / 3;
    return padding + _tabCtrl.index * (itemWidth + 1.0);
  }

  double _dockPillWidth() {
    final width = (MediaQuery.of(context).size.width - 48);
    return (width - 2) / 3 - 16;
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
          final int badgeCount = index == 0
              ? _leaveRequests.length
              : index == 1
              ? _permissionRequests.length
              : 0;
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
                  child: Stack(
                    key: ValueKey(isActive),
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isActive ? active : inactive,
                        color: isActive ? _black : _mediumGray,
                        size: 24,
                      ),
                      if (badgeCount > 0 && index != 2)
                        Positioned(
                          right: -10,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _softRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
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

  Widget _buildLeaveReviewTab() {
    if (_loadingLeaves)
      return const Center(child: CircularProgressIndicator(color: _black));
    if (_leaveRequests.isEmpty) return _emptyState('No pending leave requests');
    return RefreshIndicator(
      color: _black,
      onRefresh: _fetchLeaves,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        itemCount: _leaveRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _leaveRequestCard(_leaveRequests[i]),
      ),
    );
  }

  Widget _buildPermissionReviewTab() {
    if (_loadingPermissions)
      return const Center(child: CircularProgressIndicator(color: _black));
    if (_permissionRequests.isEmpty)
      return _emptyState('No pending permissions');
    return RefreshIndicator(
      color: _black,
      onRefresh: _fetchPermissions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        itemCount: _permissionRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _permissionRequestCard(_permissionRequests[i]),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 48, color: _lightGray),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(
              color: _mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveRequestCard(Map<String, dynamic> req) {
    final fromDt = _parseDateOnly(req['from_date']);
    final toDt = _parseDateOnly(req['to_date']);
    final from = fromDt != null ? DateFormat('dd MMM').format(fromDt) : '—';
    final to = toDt != null ? DateFormat('dd MMM').format(toDt) : '—';
    final username = req['username'] ?? 'Staff';
    final totalDays = req['total_days'] ?? 0;
    final id = req['id'] as int;
    final isSelected = _selectedLeaveIds.contains(id);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        setState(() {
          _selectionMode = true;
          _selectedLeaveIds.add(id);
        });
      },
      onTap: _selectionMode ? () => _toggleSelection(id, true) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? _black.withOpacity(0.03) : _pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _black : _lightGray,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_selectionMode) ...[
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? _black : _mediumGray,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _avatarPlaceholder(username),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _black,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$totalDays Days • $from - $to',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (req['session'] != null &&
                                req['session'] != 'full') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  req['session'] == 'first_half'
                                      ? 'MORNING'
                                      : 'AFTERNOON',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _black,
                                    letterSpacing: 0.5,
                                  ),
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
            ),
            if (req['reason'] != null && req['reason'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req['reason'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: _charcoal,
                    height: 1.4,
                  ),
                ),
              ),
            if (!_selectionMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _handleReview(req['id'], 'rejected', isLeave: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _softRed,
                          side: const BorderSide(color: _softRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _handleReview(req['id'], 'approved', isLeave: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _black,
                          foregroundColor: _pureWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectionMode) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _permissionRequestCard(Map<String, dynamic> req) {
    final username = req['username'] ?? 'Staff';
    final date = req['date'] ?? '';
    final minutes = req['permission_minutes'] ?? 0;
    final type = req['permission_type'] == 'late_checkin'
        ? 'Late Check-in'
        : 'Early Check-out';
    final id = req['id'] as int;
    final isSelected = _selectedPermissionIds.contains(id);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        setState(() {
          _selectionMode = true;
          _selectedPermissionIds.add(id);
        });
      },
      onTap: _selectionMode ? () => _toggleSelection(id, false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? _black.withOpacity(0.03) : _pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _black : _lightGray,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_selectionMode) ...[
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? _black : _mediumGray,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _avatarPlaceholder(username),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _black,
                          ),
                        ),
                        Text(
                          '$type • $minutes mins',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _parseDateOnly(date) != null
                        ? DateFormat('dd MMM').format(_parseDateOnly(date)!)
                        : '—',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _black,
                    ),
                  ),
                ],
              ),
            ),
            if (req['reason'] != null && req['reason'].toString().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req['reason'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: _charcoal,
                    height: 1.4,
                  ),
                ),
              ),
            if (!_selectionMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleReview(
                          req['id'],
                          'rejected',
                          isLeave: false,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _softRed,
                          side: const BorderSide(color: _softRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleReview(
                          req['id'],
                          'approved',
                          isLeave: false,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _black,
                          foregroundColor: _pureWhite,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectionMode) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _softGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _mediumGray,
          ),
        ),
      ),
    );
  }

  Future<void> _handleReview(
    int id,
    String status, {
    required bool isLeave,
    bool silent = false,
  }) async {
    if (!silent) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: Text(
            status == 'approved' ? 'Approve Request?' : 'Reject Request?',
          ),
          content: Text(
            'Are you sure you want to $status this ${isLeave ? "leave" : "permission"} request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved' ? _statusGreen : _softRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      Get.showOverlay(
        asyncFunction: () =>
            _processReview(id, status, isLeave: isLeave, silent: false),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    } else {
      await _processReview(id, status, isLeave: isLeave, silent: true);
    }
  }

  Future<void> _processReview(
    int id,
    String status, {
    required bool isLeave,
    bool silent = false,
  }) async {
    if (!silent) {
      debugPrint('--- Review Action Initiated ---');
      debugPrint('Type: ${isLeave ? 'Leave' : 'Permission'}');
      debugPrint('Request ID: $id');
      debugPrint('Target Status: $status');
    }

    try {
      final user = storage.read('user') ?? {};
      final adminId = user['id'];

      if (adminId == null) {
        throw Exception('User session expired. Please log in again.');
      }

      if (isLeave) {
        if (!silent) debugPrint('Calling ApiService.reviewLeaveRequest...');
        final result = await ApiService.reviewLeaveRequest(
          requestId: id,
          status: status,
          reviewedBy: adminId,
          adminNote: 'Approved!!',
        );
        if (!silent) debugPrint('Leave review result: $result');
        if (!silent) _fetchLeaves();
      } else {
        if (!silent)
          debugPrint('Calling ApiService.reviewPermissionRequest...');
        final result = await ApiService.reviewPermissionRequest(
          requestId: id,
          status: status,
          reviewedBy: adminId,
          adminNote: 'Approved!!',
        );
        if (!silent) debugPrint('Permission review result: $result');
        if (!silent) _fetchPermissions();
      }
      if (!silent)
        Get.snackbar(
          'Success',
          'Request $status',
          backgroundColor: _black,
          colorText: _pureWhite,
        );
    } catch (e) {
      if (!silent) {
        debugPrint('!!! ERROR IN REVIEW ACTION !!!');
        debugPrint('Error: $e');

        String errorMsg = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Network error: ', '');
        if (errorMsg.contains('Http status error [404]')) {
          errorMsg = 'Endpoint not found (404). Check backend routes.';
        } else if (errorMsg.contains('Http status error [500]')) {
          errorMsg = 'Server error (500). Check backend logs.';
        }

        Get.snackbar(
          'Action Failed',
          errorMsg,
          backgroundColor: _softRed,
          colorText: _pureWhite,
          duration: const Duration(seconds: 4),
        );
      } else {
        rethrow;
      }
    }
    if (!silent) debugPrint('--- Review Action Finished ---');
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _black));
    }

    if (_historyRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: _lightGray),
            const SizedBox(height: 16),
            const Text(
              'No processing history found',
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

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: _black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: _historyRequests.length,
        itemBuilder: (context, index) {
          final req = _historyRequests[index];
          final type = req['_type'] as String;
          final status = req['status'] as String;
          final isLeave = type == 'leave';

          final color = status == 'approved' ? _statusGreen : _softRed;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightGray.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 6, color: color),
                    Expanded(
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
                                    Icon(
                                      isLeave
                                          ? Icons.beach_access_rounded
                                          : Icons.timer_rounded,
                                      size: 16,
                                      color: isLeave
                                          ? Colors.orange.shade700
                                          : Colors.purple.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isLeave ? 'LEAVE' : 'PERMISSION',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isLeave
                                            ? Colors.orange.shade700
                                            : Colors.purple.shade700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              req['employee_name'] ??
                                  req['full_name'] ??
                                  'Unknown User',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLeave
                                  ? '${DateFormat('dd MMM').format(_parseDateOnly(req['from_date']) ?? DateTime(0))} - ${DateFormat('dd MMM').format(_parseDateOnly(req['to_date']) ?? DateTime(0))} (${req['total_days']} days)${req['session'] != null && req['session'] != 'full' ? ' • ${req['session'] == 'first_half' ? "Morning" : "Afternoon"}' : ''}'
                                  : '${DateFormat('dd MMM').format(_parseDateOnly(req['date']) ?? DateTime(0))} • ${req['permission_minutes']} mins',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (req['admin_note'] != null &&
                                req['admin_note'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _offWhite,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Note: ${req['admin_note']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _darkGray,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
