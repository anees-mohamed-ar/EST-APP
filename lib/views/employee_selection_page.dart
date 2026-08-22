import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'camera_page.dart';

/// Shown when a Multi User taps Check-In or Check-Out.
/// 1. Loads all users with today's attendance count.
/// 2. Multi User picks employees to include (searchable list).
/// 3. Navigates to camera internally.
/// 4. Returns {'imagePath': String, 'selectedIds': List<int>} to caller,
///    where selectedIds already includes the Multi User's own ID.
class EmployeeSelectionPage extends StatefulWidget {
  final String action;
  final int managerId;
  final String managerName;
  final Future<bool> Function({
    required String imagePath,
    required String? lat,
    required String? lang,
    required Function(double) onProgress,
    required Function(String status) onStatusUpdate,
    required List<int> userIds,
  })?
  onConfirm;

  const EmployeeSelectionPage({
    required this.action,
    required this.managerId,
    required this.managerName,
    this.onConfirm,
  });

  @override
  State<EmployeeSelectionPage> createState() => _EmployeeSelectionPageState();
}

class _EmployeeSelectionPageState extends State<EmployeeSelectionPage> {
  static const _bg = Color(0xFFFAFAFB);
  static const _card = Color(0xFFFFFFFF);
  static const _black = Color(0xFF000000);
  static const _green = Color(0xFF059669);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFD97706);
  static const _slate = Color(0xFF94A3B8);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecond = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  List<dynamic> allUsers = [];
  Set<int> selectedIds = {};
  bool loading = true;
  bool proceeding = false;
  int _swipeKeyCounter = 0;

  List<dynamic> sites = [];

  final _searchCtrl = TextEditingController();
  String _query = '';

  bool get isCheckIn => widget.action == 'check_in';
  String get todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<dynamic> get _filtered {
    if (_query.isEmpty) return allUsers;
    final q = _query.toLowerCase();
    return allUsers.where((u) {
      final username = (u['username'] ?? '').toString().toLowerCase();
      final fullName = (u['full_name'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return username.contains(q) || fullName.contains(q) || role.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadSites();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      final users = await ApiService.getUsersOnly(date: todayStr);
      final filtered = users.where((u) {
        final isNotManager = u['id'] != widget.managerId;
        final isAdmin = (u['role'] ?? '').toString().toLowerCase() == 'admin';
        final isActive = u['is_active'] == 1 || u['is_active'] == true || u['is_active'] == '1' || u['is_active'] == null;
        return isNotManager && !isAdmin && isActive;
      }).toList();
      if (mounted)
        setState(() {
          allUsers = filtered;
          loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => loading = false);
      Get.snackbar(
        'Error',
        'Failed to load employees: $e',
        backgroundColor: _red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  Future<void> _loadSites() async {
    try {
      final s = await ApiService.getSites();
      if (mounted)
        setState(() {
          sites = s;
        });
    } catch (_) {}
  }

  Future<void> _proceed() async {
    if (proceeding) return;

    String? chosenSite;
    if (sites.isNotEmpty) {
      String searchQuery = '';
      bool searchById = false;
      final searchCtrl = TextEditingController();
      chosenSite = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setStateBtm) {
              final query = searchQuery.toLowerCase().trim();

              final filteredSites = sites.where((s) {
                if (query.isEmpty) return true;
                if (searchById) {
                  final siteId = (s['site_id']?.toString() ?? '').toLowerCase();
                  return siteId.startsWith(query);
                } else {
                  final siteName = (s['site_name']?.toString() ?? '')
                      .toLowerCase();
                  return siteName.contains(query);
                }
              }).toList();

              if (searchById && query.isNotEmpty) {
                filteredSites.sort((a, b) {
                  final idA = (a['site_id']?.toString() ?? '').toLowerCase();
                  final idB = (b['site_id']?.toString() ?? '').toLowerCase();
                  if (idA == query && idB != query) return -1;
                  if (idB == query && idA != query) return 1;
                  return idA.compareTo(idB);
                });
              }

              Widget _buildToggleBtn(bool isId, String label) {
                final active = searchById == isId;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setStateBtm(() {
                        searchById = isId;
                        searchQuery = '';
                        searchCtrl.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? _textPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? _textPrimary : _border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? _card : _textSecond,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: const BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  top: 24,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Site for ${isCheckIn ? 'Check-in' : 'Check-out'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildToggleBtn(false, 'By Name'),
                        const SizedBox(width: 8),
                        _buildToggleBtn(true, 'By ID'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: searchById
                            ? 'Search by Site ID'
                            : 'Search by Site Name',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _textPrimary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _textPrimary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (val) {
                        setStateBtm(() {
                          searchQuery = val;
                        });
                      },
                      style: const TextStyle(color: _textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredSites.isEmpty
                            ? 1
                            : filteredSites.length + 1,
                        separatorBuilder: (_, __) =>
                            const Divider(color: _border),
                        itemBuilder: (ctx, i) {
                          // "Others" tile — always shown as the last item
                          if (filteredSites.isEmpty ||
                              i == filteredSites.length) {
                            return ListTile(
                              leading: const Icon(
                                Icons.edit_location_alt_outlined,
                                color: _textPrimary,
                              ),
                              title: const Text(
                                'Others',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              subtitle: const Text(
                                'Specify a custom site',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSecond,
                                ),
                              ),
                              onTap: () async {
                                final otherCtrl = TextEditingController();
                                final typed = await showDialog<String>(
                                  context: ctx,
                                  barrierDismissible: false,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Specify Site'),
                                    content: TextField(
                                      controller: otherCtrl,
                                      autofocus: true,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter site name',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _textPrimary,
                                          foregroundColor: _card,
                                        ),
                                        onPressed: () {
                                          final val = otherCtrl.text.trim();
                                          if (val.isNotEmpty) {
                                            Navigator.pop(dCtx, val);
                                          }
                                        },
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );
                                if (typed != null && typed.isNotEmpty) {
                                  Navigator.pop(ctx, '(others)-$typed');
                                }
                              },
                            );
                          }
                          final s = filteredSites[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: _red,
                            ),
                            title: Text(
                              s['site_name'],
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _textPrimary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ID: ${s['site_id'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, s['site_name']),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      if (chosenSite == null) {
        setState(() => _swipeKeyCounter++);
        return; // user cancelled checkin
      }
    }

    setState(() => proceeding = true);
    try {
      final finalSelectedIds = [widget.managerId, ...selectedIds.toList()];

      final cameraResult = await Get.to(
        () => CameraPage(
          siteName: chosenSite,
          userIds: finalSelectedIds,
          isBulk: true,
        ),
      );

      if (cameraResult == null || cameraResult is! Map) {
        return;
      }

      if (cameraResult['success'] == true) {
        Get.back(result: cameraResult);
        return;
      }

      Get.back(
        result: {
          'imagePath': cameraResult['imagePath'] as String?,
          'lat': cameraResult['lat'],
          'lang': cameraResult['lang'],
          'site': chosenSite,
          'selectedIds': finalSelectedIds,
        },
      );
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => proceeding = false);
    }
  }

  Color get _accentColor => isCheckIn ? _green : _red;
  IconData get _accentIcon =>
      isCheckIn ? Icons.login_rounded : Icons.logout_rounded;

  _StatusInfo _statusFor(dynamic user) {
    final count = (user['attendance_count'] ?? 0) as int;
    if (isCheckIn) {
      if (count == 0) return _StatusInfo('Not checked in', _green, true);
      if (count == 1) return _StatusInfo('Already checked in', _amber, false);
      return _StatusInfo('Checked out', _slate, false);
    } else {
      if (count == 1)
        return _StatusInfo('Checked in — can check out', _black, true);
      if (count >= 2) return _StatusInfo('Already checked out', _slate, false);
      return _StatusInfo('Not checked in', _slate, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = isCheckIn ? 'Check-In' : 'Check-Out';
    final filtered = _filtered;
    final eligibleCount = allUsers.where((u) => _statusFor(u).eligible).length;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: _card,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _textPrimary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: _textPrimary,
                            ),
                          ),
                          onPressed: () => Get.back(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Employees for $actionLabel',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                'Multi User: ${widget.managerName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSecond,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _accentColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_accentIcon, color: _accentColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCheckIn
                                      ? 'Selecting employees to Check-In with you'
                                      : 'Selecting employees to Check-Out with you',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _accentColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isCheckIn
                                      ? 'Employees who haven\'t checked in yet are highlighted'
                                      : 'Employees who have checked in are eligible for check-out',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _accentColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${selectedIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Search bar ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by name or role…',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: _slate,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: _slate,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: _slate,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: _border),

          // ── Employee list ────────────────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _black))
                : allUsers.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    color: _black,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _query.isEmpty
                                      ? 'EMPLOYEES  ($eligibleCount eligible)'
                                      : '${filtered.length} result${filtered.length == 1 ? '' : 's'} for "$_query"',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _textSecond,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                if (selectedIds.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => selectedIds.clear()),
                                    child: const Text(
                                      'Clear all',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        if (filtered.isEmpty && _query.isNotEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: _slate.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No employees match "$_query"',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textSecond,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _searchCtrl.clear(),
                                    child: const Text(
                                      'Clear search',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildUserTile(filtered[i]),
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),

      // ── Bottom bar ───────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Multi User info chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _black.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.manage_accounts_rounded,
                      size: 16,
                      color: _black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.managerName} (you) will always be included',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Swipe button (extracted widget — zero lag) ─────────────────
              _SwipeButton(
                key: ValueKey('swipe_$_swipeKeyCounter'),
                accentColor: _accentColor,
                accentIcon: _accentIcon,
                proceeding: proceeding,
                totalCount: selectedIds.length + 1,
                onConfirm: _proceed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(dynamic user) {
    final uid = user['id'] as int;
    final name = user['username'] ?? 'Unknown';
    final fullName = user['full_name'] ?? '';
    final role = user['role'] ?? '';
    final status = _statusFor(user);
    final isSelected = selectedIds.contains(uid);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget nameWidget;
    if (_query.isNotEmpty &&
        name.toString().toLowerCase().contains(_query.toLowerCase())) {
      final lower = name.toString().toLowerCase();
      final start = lower.indexOf(_query.toLowerCase());
      final end = start + _query.length;
      nameWidget = RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: status.eligible ? _textPrimary : _textSecond,
          ),
          children: [
            if (start > 0) TextSpan(text: name.toString().substring(0, start)),
            TextSpan(
              text: name.toString().substring(start, end),
              style: TextStyle(
                backgroundColor: _black.withOpacity(0.12),
                color: _black,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (end < name.toString().length)
              TextSpan(text: name.toString().substring(end)),
          ],
        ),
      );
    } else {
      nameWidget = Text(
        name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: status.eligible ? _textPrimary : _textSecond,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: status.eligible
              ? () => setState(() {
                  if (isSelected)
                    selectedIds.remove(uid);
                  else
                    selectedIds.add(uid);
                })
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withOpacity(0.05)
                  : status.eligible
                  ? _card
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? _accentColor.withOpacity(0.35)
                    : status.eligible
                    ? _border
                    : _border.withOpacity(0.5),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected || !status.eligible
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        (isSelected
                                ? _accentColor
                                : status.eligible
                                ? _black
                                : _slate)
                            .withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          (isSelected
                                  ? _accentColor
                                  : status.eligible
                                  ? _black
                                  : _slate)
                              .withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? _accentColor
                            : status.eligible
                            ? _black
                            : _slate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      nameWidget,
                      if (fullName.isNotEmpty && fullName != name)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            fullName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: status.eligible
                                  ? _textSecond
                                  : _textSecond.withOpacity(0.6),
                            ),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status.color,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: status.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _slate.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                fontSize: 9,
                                color: _textSecond,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Checkbox
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? _accentColor
                          : status.eligible
                          ? _border
                          : _border.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 13)
                      : !status.eligible
                      ? Icon(
                          Icons.block_rounded,
                          color: _slate.withOpacity(0.4),
                          size: 12,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: _black,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No other employees found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You can still proceed — only you will be recorded.',
            style: TextStyle(fontSize: 12, color: _textSecond),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-to-proceed button
// Uses ValueNotifier so only the thumb/fill rebuilds on each drag tick,
// not the entire page. Arrow animations are driven by AnimationController.
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeButton extends StatefulWidget {
  final Color accentColor;
  final IconData accentIcon;
  final bool proceeding;
  final int totalCount;
  final VoidCallback onConfirm;

  const _SwipeButton({
    super.key,
    required this.accentColor,
    required this.accentIcon,
    required this.proceeding,
    required this.totalCount,
    required this.onConfirm,
  });

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton>
    with TickerProviderStateMixin {
  /// Swipe position in logical pixels — only this notifier triggers rebuilds.
  final _posNotifier = ValueNotifier<double>(0.0);
  bool _triggered = false;

  late final AnimationController _arrowCtrl;
  late final List<Animation<double>> _arrowAnims;

  // Snap-back controller — recreated on each pan end
  AnimationController? _snapCtrl;

  @override
  void initState() {
    super.initState();

    // Looping arrow pulse
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    // Three staggered animations: each occupies a 70% window, offset by 15%
    _arrowAnims = List.generate(3, (i) {
      final start = i * 0.15;
      final end = (start + 0.70).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.25,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.25,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 50,
        ),
      ]).animate(
        CurvedAnimation(parent: _arrowCtrl, curve: Interval(start, end)),
      );
    });
  }

  @override
  void didUpdateWidget(_SwipeButton old) {
    super.didUpdateWidget(old);
    // If proceeding just turned true from outside, stop arrows
    if (widget.proceeding && !old.proceeding) {
      _arrowCtrl.stop();
    }
    // If proceeding just turned false (returning from camera), reset swipe state
    if (!widget.proceeding && old.proceeding) {
      _posNotifier.value = 0.0;
      _triggered = false;
      _arrowCtrl.repeat(); // Restart arrow animations
    }
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    _posNotifier.dispose();
    _snapCtrl?.dispose();
    super.dispose();
  }

  // ── Gesture handlers ────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    _snapCtrl?.stop();
    _snapCtrl?.dispose();
    _snapCtrl = null;
  }

  void _onPanUpdate(DragUpdateDetails details, double maxSwipe) {
    if (_triggered || widget.proceeding) return;
    final newPos = (_posNotifier.value + details.delta.dx).clamp(0.0, maxSwipe);
    _posNotifier.value = newPos;

    if (newPos >= maxSwipe * 1.00) {
      // Changed from 0.88 to 0.95
      _triggered = true;
      widget.onConfirm();
    }
  }

  void _onPanEnd(DragEndDetails details, double maxSwipe) {
    if (_triggered || widget.proceeding) return;

    // Fling support: if released with velocity toward right, let it fly
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity > 800 && _posNotifier.value >= maxSwipe * 0.5) {
      _triggered = true;
      widget.onConfirm();
      return;
    }

    // Animate snap-back with easeOut curve
    final startPos = _posNotifier.value;
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curve = CurvedAnimation(
      parent: _snapCtrl!,
      curve: Curves.easeOutCubic,
    );
    curve.addListener(() {
      _posNotifier.value = startPos * (1 - curve.value);
    });
    _snapCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _snapCtrl?.dispose();
        _snapCtrl = null;
      }
    });
    _snapCtrl!.forward();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // maxSwipe: full width minus thumb (48) minus left padding (4) minus right padding (4)
        final maxSwipe = constraints.maxWidth - 56.0;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Swipe fill track ─────────────────────────────────────────────
              ValueListenableBuilder<double>(
                valueListenable: _posNotifier,
                builder: (_, pos, __) => Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (pos + 56).clamp(56.0, constraints.maxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),

              // ── Centre label (fades as thumb advances) ───────────────────────
              ValueListenableBuilder<double>(
                valueListenable: _posNotifier,
                builder: (_, pos, __) {
                  final t = (pos / maxSwipe).clamp(0.0, 1.0);
                  final opacity = (1.0 - t * 2.2).clamp(0.0, 1.0);
                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        widget.proceeding
                            ? 'Opening camera...'
                            : widget.totalCount <= 1
                            ? 'Swipe to proceed (only you)'
                            : 'Swipe to proceed · ${widget.totalCount} people',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Animated guide arrows ────────────────────────────────────────
              // Three chevrons, increasing size, staggered pulse, fade on swipe
              ValueListenableBuilder<double>(
                valueListenable: _posNotifier,
                builder: (_, pos, __) {
                  final t = (pos / maxSwipe).clamp(0.0, 1.0);
                  final containerOpacity = (1.0 - t * 3.0).clamp(0.0, 1.0);
                  return Positioned(
                    right: 20, // Increased from 58 to 78 for more space
                    top: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: containerOpacity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _arrowAnims[i],
                            builder: (_, __) {
                              final v = _arrowAnims[i].value;
                              return Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  // subtle rightward nudge at peak opacity
                                  offset: Offset((v - 0.25) * 5, 0),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    // sizes: 16, 20, 25
                                    size: 16.0 + i * 4.5,
                                    color: color.withOpacity(0.45 + i * 0.2),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),

              // ── Draggable thumb ──────────────────────────────────────────────
              ValueListenableBuilder<double>(
                valueListenable: _posNotifier,
                builder: (_, pos, __) => Positioned(
                  left: 4 + pos,
                  top: 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: widget.proceeding ? null : _onPanStart,
                    onPanUpdate: widget.proceeding
                        ? null
                        : (d) => _onPanUpdate(d, maxSwipe),
                    onPanEnd: widget.proceeding
                        ? null
                        : (d) => _onPanEnd(d, maxSwipe),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.proceeding
                            ? color.withOpacity(0.55)
                            : color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: widget.proceeding
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              widget.accentIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusInfo {
  final String label;
  final Color color;
  final bool eligible;
  const _StatusInfo(this.label, this.color, this.eligible);
}
