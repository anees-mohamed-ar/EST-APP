import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class HierarchyManagementPage extends StatefulWidget {
  const HierarchyManagementPage({Key? key}) : super(key: key);

  @override
  _HierarchyManagementPageState createState() => _HierarchyManagementPageState();
}

class _HierarchyManagementPageState extends State<HierarchyManagementPage> {
  List<dynamic> employees = [];
  List<dynamic> potentialApprovers = [];
  bool isLoading = true;
  String searchQuery = '';
  
  // Selection mode for bulk assignment
  bool selectionMode = false;
  Set<int> selectedEmployeeIds = {};

  // Sophisticated monochrome palette from MonthlySummary
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final hierarchy = await ApiService.getHierarchy();
      final approvers = await ApiService.getPotentialApprovers();
      if (mounted) {
        setState(() {
          employees = hierarchy;
          potentialApprovers = approvers;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading hierarchy: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredEmployees {
    if (searchQuery.isEmpty) return employees;
    final q = searchQuery.toLowerCase();
    return employees.where((emp) {
      final name = (emp['employee_name'] ?? emp['username'] ?? '').toString().toLowerCase();
      final dept = (emp['department'] ?? '').toString().toLowerCase();
      return name.contains(q) || dept.contains(q);
    }).toList();
  }

  void _toggleSelection(int id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (selectedEmployeeIds.contains(id)) {
        selectedEmployeeIds.remove(id);
        if (selectedEmployeeIds.isEmpty) selectionMode = false;
      } else {
        selectedEmployeeIds.add(id);
        selectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _offWhite,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildSearchAndFilter(),
                Expanded(
                  child: ElectricRefreshIndicator(
                    onRefresh: _loadData,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: _charcoal, strokeWidth: 2))
                        : filteredEmployees.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                                itemCount: filteredEmployees.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => _buildEmployeeCard(filteredEmployees[index]),
                              ),
                  ),
                ),
              ],
            ),
            if (selectionMode)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 24,
                right: 24,
                child: _buildActionDock(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _charcoal, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hierarchy Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _charcoal,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                selectionMode ? '${selectedEmployeeIds.length} Selected' : 'Assign Approvers to Staff',
                style: const TextStyle(fontSize: 12, color: _mediumGray, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          if (selectionMode)
            GestureDetector(
              onTap: () => setState(() {
                selectionMode = false;
                selectedEmployeeIds.clear();
              }),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _mediumGray, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            )
          else
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _lightGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.sync_rounded, color: _charcoal, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _lightGray, width: 1),
        ),
        child: TextField(
          onChanged: (val) => setState(() => searchQuery = val),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'Search staff or department...',
            hintStyle: TextStyle(color: _mediumGray, fontSize: 14, fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.search_rounded, color: _mediumGray, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final int id = emp['id'];
    final bool isSelected = selectedEmployeeIds.contains(id);
    final String name = emp['employee_name'] ?? emp['username'] ?? 'Staff';
    final List approvers = emp['approvers'] ?? [];

    return GestureDetector(
      onLongPress: () => _toggleSelection(id),
      onTap: () {
        if (selectionMode) {
          _toggleSelection(id);
        } else {
          _showApproverPicker([id], currentApproverIds: approvers.map((a) => a['id'] as int).toList());
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _charcoal.withOpacity(0.05) : _pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _charcoal : _lightGray,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(emp['pfp'], isSelected),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _charcoal),
                  ),
                  Text(
                    '${emp['designation'] ?? 'Staff'} • ${emp['department'] ?? 'General'}',
                    style: const TextStyle(fontSize: 11, color: _mediumGray, fontWeight: FontWeight.w500),
                  ),
                  if (approvers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: approvers.map((a) => _buildApproverChip(a['username'])).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Text('No approver assigned', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            if (selectionMode)
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? _charcoal : _lightGray,
              )
            else
              const Icon(Icons.chevron_right_rounded, color: _lightGray),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? pfp, bool isSelected) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _lightGray,
        borderRadius: BorderRadius.circular(14),
        image: pfp != null ? DecorationImage(image: NetworkImage('${ApiService.baseUrl}$pfp'), fit: BoxFit.cover) : null,
      ),
      child: pfp == null ? const Icon(Icons.person_rounded, color: _mediumGray) : null,
    );
  }

  Widget _buildApproverChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _charcoal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _charcoal.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, size: 10, color: _charcoal),
          const SizedBox(width: 4),
          Text(name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _charcoal)),
        ],
      ),
    );
  }

  Widget _buildActionDock() {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: _pureWhite.withOpacity(0.8),
            child: Row(
              children: [
                Expanded(
                  child: _dockButton(
                    onTap: () => _showApproverPicker(selectedEmployeeIds.toList()),
                    icon: Icons.group_add_rounded,
                    label: 'Assign Approvers',
                    primary: true,
                  ),
                ),
                const VerticalDivider(width: 1, indent: 15, endIndent: 15, color: _lightGray),
                Expanded(
                  child: _dockButton(
                    onTap: _bulkClear,
                    icon: Icons.clear_all_rounded,
                    label: 'Clear All',
                    primary: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dockButton({required VoidCallback onTap, required IconData icon, required String label, bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primary ? _charcoal : Colors.redAccent, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primary ? _charcoal : Colors.redAccent)),
        ],
      ),
    );
  }

  Future<void> _bulkClear() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Clear Approvers?'),
        content: Text('This will remove all approvers from ${selectedEmployeeIds.length} employees.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      try {
        await ApiService.bulkAssignApprovers(selectedEmployeeIds.toList(), []);
        Get.snackbar('Success', 'Approvers cleared');
        setState(() {
          selectionMode = false;
          selectedEmployeeIds.clear();
        });
        _loadData();
      } catch (e) {
        Get.snackbar('Error', 'Failed to clear approvers');
        setState(() => isLoading = false);
      }
    }
  }

  void _showApproverPicker(List<int> targetEmployeeIds, {List<int>? currentApproverIds}) {
    List<int> selectedApprovers = List.from(currentApproverIds ?? []);

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: const BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Approvers',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _charcoal),
                    ),
                    IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const Text(
                  'Selected users can approve requests from these employees',
                  style: TextStyle(fontSize: 12, color: _mediumGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: potentialApprovers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = potentialApprovers[index];
                      final isSelected = selectedApprovers.contains(app['id']);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) selectedApprovers.remove(app['id']);
                            else selectedApprovers.add(app['id']);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? _charcoal : _offWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? _charcoal : _lightGray),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app['username'] ?? 'User',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? _pureWhite : _charcoal),
                                  ),
                                  Text(
                                    app['role'] ?? '',
                                    style: TextStyle(fontSize: 10, color: isSelected ? _pureWhite.withOpacity(0.6) : _mediumGray, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (isSelected) const Icon(Icons.check_circle_rounded, color: _pureWhite, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      setState(() => isLoading = true);
                      try {
                        await ApiService.bulkAssignApprovers(targetEmployeeIds, selectedApprovers);
                        Get.snackbar('Success', 'Approvers updated successfully');
                        setState(() {
                          selectionMode = false;
                          selectedEmployeeIds.clear();
                        });
                        _loadData();
                      } catch (e) {
                        Get.snackbar('Error', 'Failed to update approvers');
                        setState(() => isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _charcoal,
                      foregroundColor: _pureWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Update Approvers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_rounded, size: 64, color: _lightGray),
          const SizedBox(height: 16),
          const Text('No staff members found', style: TextStyle(color: _mediumGray, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
