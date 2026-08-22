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
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  final TextEditingController _searchCtrl = TextEditingController();

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

    // Default to current month for history
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );

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
          RepaintBoundary(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildLeaveReviewTab(),
                _buildPermissionReviewTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 24,
            right: 24,
            child: RepaintBoundary(
              child: _selectionMode ? _buildBulkActionBar() : _buildDock(),
            ),
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

    final noteController = TextEditingController();
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(status == 'approved' ? 'Bulk Approve' : 'Bulk Reject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to $status ${ids.length} requests?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Common Note (Optional)',
                labelStyle: const TextStyle(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Enter a note for all...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: _mediumGray)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? _statusGreen : _softRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(status == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final commonNote = noteController.text.trim();

    Get.showOverlay(
      asyncFunction: () async {
        for (final id in ids) {
          await _handleReview(id, status, isLeave: isLeave, silent: true, note: commonNote);
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
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
                animation: _tabCtrl.animation!,
                builder: (context, child) => Positioned(
                  top: 8,
                  bottom: 8,
                  left: _dockPillLeft(),
                  child: Container(
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
    return padding + (_tabCtrl.animation?.value ?? _tabCtrl.index) * (itemWidth + 1.0);
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
    final displayName = req['full_name'] ?? req['employee_name'] ?? req['username'] ?? 'Staff';
    final username = req['username'] ?? '—';
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
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _black,
                          ),
                        ),
                        Text(
                          '($username)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.w600,
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
    final displayName = req['full_name'] ?? req['employee_name'] ?? req['username'] ?? 'Staff';
    final username = req['username'] ?? '—';
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
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _black,
                          ),
                        ),
                        Text(
                          '($username)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.w600,
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
    String? note,
  }) async {
    if (!silent) {
      final noteController = TextEditingController();
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            status == 'approved' ? 'Approve Request?' : 'Reject Request?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to $status this ${isLeave ? "leave" : "permission"} request?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  labelStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Enter a reason or note...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel', style: TextStyle(color: _mediumGray)),
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
      final finalNote = noteController.text.trim();

      Get.showOverlay(
        asyncFunction: () =>
            _processReview(id, status, isLeave: isLeave, silent: false, note: finalNote.isEmpty ? null : finalNote),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    } else {
      await _processReview(id, status, isLeave: isLeave, silent: true, note: note);
    }
  }

  Future<void> _processReview(
    int id,
    String status, {
    required bool isLeave,
    bool silent = false,
    String? note,
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
          adminNote: note ?? (status == 'approved' ? 'Approved!' : 'Rejected'),
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
          adminNote: note ?? (status == 'approved' ? 'Approved!' : 'Rejected'),
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

  List<dynamic> get _filteredHistory {
    return _historyRequests.where((req) {
      // 1. Search Query Filter
      final query = _searchQuery.toLowerCase();
      final name = (req['employee_name'] ?? req['full_name'] ?? '').toString().toLowerCase();
      final username = (req['username'] ?? '').toString().toLowerCase();
      final reason = (req['reason'] ?? '').toString().toLowerCase();
      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          reason.contains(query);

      // 2. Date Range Filter
      bool matchesDate = true;
      if (_dateRange != null) {
        final dateStr = req['reviewed_at'] ?? req['created_at'] ?? '';
        final reqDate = _parseDateOnly(dateStr);
        if (reqDate != null) {
          // Compare only dates (strip time)
          final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
          final target = DateTime(reqDate.year, reqDate.month, reqDate.day);
          
          matchesDate = (target.isAtSameMomentAs(start) || target.isAfter(start)) &&
                        (target.isAtSameMomentAs(end) || target.isBefore(end));
        }
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: _black));
    }

    final filtered = _filteredHistory;

    return Column(
      children: [
        // ── Filter Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: _pureWhite,
            border: Border(bottom: BorderSide(color: _softGray)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _offWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search history...',
                          hintStyle: TextStyle(fontSize: 14, color: _mediumGray),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: _mediumGray),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        initialDateRange: _dateRange,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _black,
                                onPrimary: _pureWhite,
                                onSurface: _black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _dateRange = picked);
                      }
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.date_range_rounded, color: _pureWhite, size: 20),
                    ),
                  ),
                ],
              ),
              if (_dateRange != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _mediumGray,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _dateRange = null),
                      child: const Text(
                        'Clear Range',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _softRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── History List ───────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _emptyState('No history matches your filters')
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  color: _black,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final req = filtered[index];
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
                                      isLeave
                                          ? 'LEAVE'
                                          : (req['permission_type'] == 'late_checkin'
                                              ? 'LATE CHECK-IN'
                                              : (req['permission_type'] == 'early_checkout'
                                                  ? 'EARLY CHECK-OUT'
                                                  : 'PERMISSION')),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isLeave
                                            ? Colors.orange.shade700
                                            : Colors.purple.shade700,
                                        letterSpacing: 0.8,
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
                              req['employee_name'] ?? req['full_name'] ?? req['username'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _black,
                              ),
                            ),
                            Text(
                              '(${req['username'] ?? '—'})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLeave
                                  ? '${DateFormat('dd MMM').format(_parseDateOnly(req['from_date']) ?? DateTime(0))} - ${DateFormat('dd MMM').format(_parseDateOnly(req['to_date']) ?? DateTime(0))} (${req['total_days']} days)${req['session'] != null && req['session'] != 'full' ? ' • ${req['session'] == 'first_half' ? "Morning" : "Afternoon"}' : ''}'
                                  : '${req['permission_type'] == 'late_checkin' ? 'Late Check-in' : (req['permission_type'] == 'early_checkout' ? 'Early Check-out' : 'Permission')} • ${DateFormat('dd MMM').format(_parseDateOnly(req['date']) ?? DateTime(0))} • ${req['permission_minutes'] ?? 0} mins',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (req['reason'] != null &&
                                req['reason'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _offWhite,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Reason: ${req['reason']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _charcoal,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Note: ${req['admin_note']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _darkGray,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    if (req['reviewed_by_name'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Processed by: ${req['reviewed_by_name']} (${req['reviewed_by_username']})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _mediumGray.withOpacity(0.8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
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
    ),
  ),
],
);
}
}
