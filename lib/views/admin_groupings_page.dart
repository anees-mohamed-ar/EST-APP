//this page is dummy not using it in application


// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import '../services/api_service.dart';

// class AdminGroupingsPage extends StatefulWidget {
//   @override
//   State<AdminGroupingsPage> createState() => _AdminGroupingsPageState();
// }

// class _AdminGroupingsPageState extends State<AdminGroupingsPage> {
//   // ── Colors ────────────────────────────────────────────────────────────────
//   static const _bg          = Color(0xFFFAFAFB);
//   static const _card        = Color(0xFFFFFFFF);
//   static const _black       = Color(0xFF000000);
//   static const _green       = Color(0xFF059669);
//   static const _red         = Color(0xFFDC2626);
//   static const _amber       = Color(0xFFD97706);
//   static const _slate       = Color(0xFF94A3B8);
//   static const _textPrimary = Color(0xFF111827);
//   static const _textSecond  = Color(0xFF6B7280);
//   static const _border      = Color(0xFFE5E7EB);

//   // ── State ─────────────────────────────────────────────────────────────────
//   DateTime selectedDate   = DateTime.now();
//   List<dynamic> allUsers       = [];
//   List<dynamic> existingGroups = [];
//   bool loadingUsers  = true;
//   bool loadingGroups = true;
//   bool saving        = false;

//   // Add-form state
//   dynamic selectedManager;
//   Set<int> selectedEmployeeIds = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadUsers();
//     _loadGroupings();
//   }

//   // ── Data loading ──────────────────────────────────────────────────────────
//   Future<void> _loadUsers() async {
//     setState(() => loadingUsers = true);
//     try {
//       final users = await ApiService.getAllUsers();
//       if (mounted) setState(() { allUsers = users; loadingUsers = false; });
//     } catch (e) {
//       if (mounted) setState(() => loadingUsers = false);
//       _err('Failed to load users: $e');
//     }
//   }

//   Future<void> _loadGroupings() async {
//     setState(() => loadingGroups = true);
//     try {
//       final groups = await ApiService.getGroupings(
//           date: DateFormat('yyyy-MM-dd').format(selectedDate));
//       if (mounted) setState(() { existingGroups = groups; loadingGroups = false; });
//     } catch (e) {
//       if (mounted) setState(() => loadingGroups = false);
//       _err('Failed to load groupings: $e');
//     }
//   }

//   Future<void> _pickDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (ctx, child) => Theme(
//         data: ThemeData.light().copyWith(
//           colorScheme: const ColorScheme.light(
//             primary: _black, onPrimary: Colors.white,
//             surface: Colors.white, onSurface: _textPrimary,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null && picked != selectedDate) {
//       setState(() {
//         selectedDate = picked;
//         selectedManager = null;
//         selectedEmployeeIds.clear();
//       });
//       _loadGroupings();
//     }
//   }

//   // ── Add form actions ──────────────────────────────────────────────────────
//   Future<void> _saveGrouping() async {
//     if (selectedManager == null) { _err('Please select a manager'); return; }
//     if (selectedEmployeeIds.isEmpty) { _err('Please select at least one employee'); return; }
//     setState(() => saving = true);
//     try {
//       final result = await ApiService.createGroupings(
//         managerId: selectedManager['id'],
//         employeeIds: selectedEmployeeIds.toList(),
//         date: DateFormat('yyyy-MM-dd').format(selectedDate),
//       );
//       setState(() { saving = false; selectedManager = null; selectedEmployeeIds.clear(); });
//       _loadGroupings();
//       final added   = result['inserted_count'] ?? 0;
//       final skipped = result['skipped_count']  ?? 0;
//       Get.snackbar('Saved ✓',
//           '$added employee(s) added${skipped > 0 ? ', $skipped skipped (duplicate)' : ''}',
//           backgroundColor: _green, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14,
//           duration: const Duration(seconds: 3));
//     } catch (e) {
//       setState(() => saving = false);
//       _err('Failed to save: $e');
//     }
//   }

//   // ── Edit / remove actions — guarded by manager_checked_in ─────────────────
//   Future<void> _removeEmployee(int groupingId, String empName) async {
//     final confirm = await _confirmDialog(
//         'Remove $empName from this group?', 'Remove', _red);
//     if (!confirm) return;
//     try {
//       await ApiService.deleteGrouping(groupingId);
//       _loadGroupings();
//       _snack('Removed', '$empName removed from group', _red);
//     } catch (e) { _err('Failed to remove: $e'); }
//   }

//   Future<void> _removeManagerGroup(int managerId, String managerName) async {
//     final confirm = await _confirmDialog(
//         'Remove ALL employees under $managerName for '
//         '${DateFormat('d MMM yyyy').format(selectedDate)}?',
//         'Remove All', _red);
//     if (!confirm) return;
//     try {
//       await ApiService.deleteManagerGroupings(
//           managerId: managerId,
//           date: DateFormat('yyyy-MM-dd').format(selectedDate));
//       _loadGroupings();
//       _snack('Cleared', 'All groupings under $managerName removed', _red);
//     } catch (e) { _err('Failed to remove: $e'); }
//   }

//   /// Opens a bottom sheet to add / remove employees from an existing group.
//   void _openEditSheet(Map<dynamic, dynamic> group) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _EditGroupSheet(
//         group: group,
//         allUsers: allUsers,
//         date: DateFormat('yyyy-MM-dd').format(selectedDate),
//         onChanged: _loadGroupings,
//       ),
//     );
//   }

//   // ── Helpers ───────────────────────────────────────────────────────────────
//   void _err(String msg) =>
//       Get.snackbar('Error', msg,
//           backgroundColor: _red, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);

//   void _snack(String title, String msg, Color color) =>
//       Get.snackbar(title, msg,
//           backgroundColor: color, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);

//   Future<bool> _confirmDialog(String msg, String action, Color color) async =>
//       await showDialog<bool>(
//         context: context,
//         builder: (ctx) => AlertDialog(
//           backgroundColor: _card,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           title: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
//           content: Text(msg, style: const TextStyle(color: _textSecond)),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text('Cancel', style: TextStyle(color: _textSecond)),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(ctx, true),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: color, foregroundColor: Colors.white),
//               child: Text(action),
//             ),
//           ],
//         ),
//       ) ?? false;

//   List<dynamic> get _availableEmployees {
//     if (selectedManager == null) return allUsers;
//     return allUsers.where((u) => u['id'] != selectedManager['id']).toList();
//   }

//   Set<int> _alreadyGroupedIds(int managerId) {
//     for (final g in existingGroups) {
//       if (g['manager_id'] == managerId) {
//         return (g['employees'] as List)
//             .map<int>((e) => e['employee_id'] as int)
//             .toSet();
//       }
//     }
//     return {};
//   }

//   // ── Build ─────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) ==
//         DateFormat('yyyy-MM-dd').format(DateTime.now());

//     return Scaffold(
//       backgroundColor: _bg,
//       body: NestedScrollView(
//         headerSliverBuilder: (ctx, _) => [
//           SliverAppBar(
//             pinned: true, backgroundColor: _bg, elevation: 0,
//             leading: IconButton(
//               icon: Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: _textPrimary.withOpacity(0.06),
//                   borderRadius: BorderRadius.circular(10)),
//                 child: const Icon(Icons.arrow_back_ios_new_rounded,
//                     size: 16, color: _black),
//               ),
//               onPressed: () => Get.back(),
//             ),
//             title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               const Text('Manage Groupings',
//                   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: _textPrimary)),
//               Text(isToday ? 'Today' : DateFormat('d MMM yyyy').format(selectedDate),
//                   style: const TextStyle(fontSize: 12, color: _textSecond)),
//             ]),
//             actions: [
//               IconButton(
//                 icon: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: _black.withOpacity(0.08),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(color: _black.withOpacity(0.2))),
//                   child: const Icon(Icons.calendar_today_rounded, size: 16, color: _black),
//                 ),
//                 onPressed: _pickDate,
//               ),
//               const SizedBox(width: 8),
//             ],
//           ),
//         ],
//         body: loadingUsers
//             ? const Center(child: CircularProgressIndicator(color: _black))
//             : RefreshIndicator(
//                 onRefresh: _loadGroupings,
//                 color: _black,
//                 child: CustomScrollView(slivers: [
//                   // ── Add form ──────────────────────────────────────────────
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
//                       child: _buildAddForm(),
//                     ),
//                   ),

//                   // ── Section header ────────────────────────────────────────
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text('EXISTING GROUPINGS',
//                               style: TextStyle(
//                                   fontSize: 11, fontWeight: FontWeight.w700,
//                                   color: _textSecond, letterSpacing: 1.4)),
//                           if (loadingGroups)
//                             const SizedBox(width: 14, height: 14,
//                                 child: CircularProgressIndicator(color: _black, strokeWidth: 2))
//                           else
//                             Text('${existingGroups.length} group(s)',
//                                 style: const TextStyle(
//                                     fontSize: 12, color: _black, fontWeight: FontWeight.w600)),
//                         ],
//                       ),
//                     ),
//                   ),

//                   // ── Groups or empty state ─────────────────────────────────
//                   if (existingGroups.isEmpty && !loadingGroups)
//                     SliverFillRemaining(
//                       hasScrollBody: false,
//                       child: Padding(
//                         padding: const EdgeInsets.all(40),
//                         child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                           Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                                 color: _black.withOpacity(0.06), shape: BoxShape.circle),
//                             child: const Icon(Icons.group_add_rounded, size: 40, color: _black),
//                           ),
//                           const SizedBox(height: 16),
//                           const Text('No groupings for this date',
//                               style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
//                           const SizedBox(height: 6),
//                           const Text('Use the form above to create groups',
//                               style: TextStyle(fontSize: 12, color: _textSecond)),
//                         ]),
//                       ),
//                     )
//                   else
//                     SliverList(
//                       delegate: SliverChildBuilderDelegate(
//                         (ctx, i) => Padding(
//                           padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
//                           child: _buildGroupCard(existingGroups[i]),
//                         ),
//                         childCount: existingGroups.length,
//                       ),
//                     ),

//                   const SliverToBoxAdapter(child: SizedBox(height: 40)),
//                 ]),
//               ),
//       ),
//     );
//   }

//   // ── Add grouping form ─────────────────────────────────────────────────────
//   Widget _buildAddForm() {
//     final alreadyGrouped = selectedManager != null
//         ? _alreadyGroupedIds(selectedManager['id'])
//         : <int>{};

//     return Container(
//       decoration: BoxDecoration(
//         color: _card,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: _black.withOpacity(0.15)),
//         boxShadow: [BoxShadow(color: _black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         // Header
//         Container(
//           padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
//           decoration: BoxDecoration(
//             color: _black.withOpacity(0.04),
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
//           child: Row(children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(color: _black.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
//               child: const Icon(Icons.group_add_rounded, color: _black, size: 18),
//             ),
//             const SizedBox(width: 12),
//             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               const Text('Add New Grouping',
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary)),
//               Text(DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
//                   style: const TextStyle(fontSize: 11, color: _textSecond)),
//             ]),
//           ]),
//         ),

//         Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             // Manager selector
//             const Text('MANAGER',
//                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecond, letterSpacing: 1.2)),
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 14),
//               decoration: BoxDecoration(
//                 border: Border.all(color: selectedManager != null ? _black.withOpacity(0.35) : _border),
//                 borderRadius: BorderRadius.circular(14),
//                 color: const Color(0xFFF8FAFC),
//               ),
//               child: DropdownButton<dynamic>(
//                 value: selectedManager,
//                 isExpanded: true,
//                 underline: const SizedBox(),
//                 hint: const Text('Select manager', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14)),
//                 items: allUsers.map((u) => DropdownMenuItem(
//                   value: u,
//                   child: Row(children: [
//                     _avatar(u['username'] ?? '?', _black),
//                     const SizedBox(width: 10),
//                     Expanded(child: Text(u['username'] ?? '',
//                         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                       decoration: BoxDecoration(color: _black.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
//                       child: Text(u['role'] ?? '',
//                           style: const TextStyle(fontSize: 10, color: _black, fontWeight: FontWeight.w600)),
//                     ),
//                   ]),
//                 )).toList(),
//                 onChanged: (val) => setState(() { selectedManager = val; selectedEmployeeIds.clear(); }),
//               ),
//             ),

//             const SizedBox(height: 18),

//             // Employee multi-select
//             const Text('EMPLOYEES TO GROUP',
//                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textSecond, letterSpacing: 1.2)),
//             const SizedBox(height: 8),

//             if (selectedManager == null)
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF8FAFC),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: _border)),
//                 child: const Row(children: [
//                   Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFCBD5E1)),
//                   SizedBox(width: 8),
//                   Text('Select a manager first', style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))),
//                 ]),
//               )
//             else
//               Container(
//                 constraints: const BoxConstraints(maxHeight: 240),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: _border),
//                   borderRadius: BorderRadius.circular(14),
//                   color: const Color(0xFFF8FAFC)),
//                 child: _availableEmployees.isEmpty
//                     ? const Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Text('No other users available', style: TextStyle(color: _textSecond, fontSize: 13)),
//                       )
//                     : ListView.separated(
//                         shrinkWrap: true,
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
//                         itemCount: _availableEmployees.length,
//                         itemBuilder: (ctx, i) {
//                           final u   = _availableEmployees[i];
//                           final uid = u['id'] as int;
//                           final isSelected      = selectedEmployeeIds.contains(uid);
//                           final isAlreadyGrouped = alreadyGrouped.contains(uid);

//                           return InkWell(
//                             onTap: isAlreadyGrouped
//                                 ? null
//                                 : () => setState(() {
//                                       if (isSelected) selectedEmployeeIds.remove(uid);
//                                       else selectedEmployeeIds.add(uid);
//                                     }),
//                             borderRadius: BorderRadius.circular(8),
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                               child: Row(children: [
//                                 _avatar(u['username'] ?? '?', isAlreadyGrouped ? _textSecond : _green),
//                                 const SizedBox(width: 10),
//                                 Expanded(
//                                   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                                     Text(u['username'] ?? '',
//                                         style: TextStyle(
//                                             fontSize: 13,
//                                             fontWeight: FontWeight.w600,
//                                             color: isAlreadyGrouped ? _textSecond : _textPrimary)),
//                                     if (isAlreadyGrouped)
//                                       const Text('Already in group', style: TextStyle(fontSize: 10, color: _amber)),
//                                   ]),
//                                 ),
//                                 if (isAlreadyGrouped)
//                                   const Icon(Icons.check_circle_rounded, color: _amber, size: 18)
//                                 else
//                                   Container(
//                                     width: 20, height: 20,
//                                     decoration: BoxDecoration(
//                                       shape: BoxShape.circle,
//                                       color: isSelected ? _black : Colors.transparent,
//                                       border: Border.all(color: isSelected ? _black : _border, width: 2)),
//                                     child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
//                                   ),
//                               ]),
//                             ),
//                           );
//                         },
//                       ),
//               ),

//             const SizedBox(height: 18),

//             // Count + Save
//             Row(children: [
//               if (selectedEmployeeIds.isNotEmpty)
//                 Expanded(
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: _green.withOpacity(0.06),
//                       borderRadius: BorderRadius.circular(10),
//                       border: Border.all(color: _green.withOpacity(0.2))),
//                     child: Text('${selectedEmployeeIds.length} employee(s) selected',
//                         style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
//                   ),
//                 )
//               else
//                 const Expanded(child: SizedBox()),
//               const SizedBox(width: 12),
//               ElevatedButton.icon(
//                 onPressed: saving ? null : _saveGrouping,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _black, foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
//                 icon: saving
//                     ? const SizedBox(width: 16, height: 16,
//                         child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                     : const Icon(Icons.save_rounded, size: 18),
//                 label: Text(saving ? 'Saving...' : 'Save Group',
//                     style: const TextStyle(fontWeight: FontWeight.w700)),
//               ),
//             ]),
//           ]),
//         ),
//       ]),
//     );
//   }

//   // ── Existing group card ───────────────────────────────────────────────────
//   Widget _buildGroupCard(Map<dynamic, dynamic> group) {
//     final employees       = group['employees'] as List;
//     final managerName     = group['manager_name'] ?? 'Unknown';
//     final managerId       = group['manager_id'] as int;
//     final initial         = managerName.isNotEmpty ? managerName[0].toUpperCase() : '?';
//     // 🔒 Key flag from the backend
//     final isLocked        = group['manager_checked_in'] == true;

//     return Container(
//       decoration: BoxDecoration(
//         color: _card,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: isLocked ? _slate.withOpacity(0.3) : _border),
//         boxShadow: [BoxShadow(
//             color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         // ── Manager header ──────────────────────────────────────────────────
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
//           decoration: BoxDecoration(
//             color: isLocked ? _slate.withOpacity(0.04) : const Color(0xFFF8FAFC),
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
//           child: Row(children: [
//             // Avatar
//             Container(
//               width: 40, height: 40,
//               decoration: BoxDecoration(
//                 color: (isLocked ? _slate : _black).withOpacity(0.1),
//                 shape: BoxShape.circle,
//                 border: Border.all(color: (isLocked ? _slate : _black).withOpacity(0.2))),
//               child: Center(
//                 child: Text(initial,
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
//                         color: isLocked ? _slate : _black)),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 Row(children: [
//                   Text(managerName,
//                       style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w700,
//                           color: isLocked ? _textSecond : _textPrimary)),
//                   const SizedBox(width: 6),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: (isLocked ? _slate : _black).withOpacity(0.08),
//                       borderRadius: BorderRadius.circular(8)),
//                     child: Text(group['manager_role'] ?? '',
//                         style: TextStyle(
//                             fontSize: 9,
//                             color: isLocked ? _slate : _black,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.5)),
//                   ),
//                 ]),
//                 const SizedBox(height: 2),
//                 Text('${employees.length} employee(s) grouped',
//                     style: const TextStyle(fontSize: 11, color: _textSecond)),
//               ]),
//             ),

//             // ── Action buttons — locked vs unlocked ───────────────────────
//             if (isLocked)
//               // Locked badge
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: _amber.withOpacity(0.08),
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: _amber.withOpacity(0.2))),
//                 child: const Row(mainAxisSize: MainAxisSize.min, children: [
//                   Icon(Icons.lock_rounded, size: 12, color: _amber),
//                   SizedBox(width: 5),
//                   Text('Locked', style: TextStyle(fontSize: 11, color: _amber, fontWeight: FontWeight.w700)),
//                 ]),
//               )
//             else ...[
//               // Edit button
//               IconButton(
//                 onPressed: () => _openEditSheet(group),
//                 icon: Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: _black.withOpacity(0.07),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: _black.withOpacity(0.2))),
//                   child: const Icon(Icons.edit_rounded, color: _black, size: 15),
//                 ),
//                 tooltip: 'Edit group',
//               ),
//               // Delete all button
//               IconButton(
//                 onPressed: () => _removeManagerGroup(managerId, managerName),
//                 icon: Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: _red.withOpacity(0.07),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: _red.withOpacity(0.2))),
//                   child: const Icon(Icons.delete_sweep_rounded, color: _red, size: 15),
//                 ),
//                 tooltip: 'Remove all',
//               ),
//             ],
//           ]),
//         ),

//         const Divider(height: 1, color: _border),

//         // ── Employee list ─────────────────────────────────────────────────
//         ...employees.asMap().entries.map((entry) {
//           final idx     = entry.key;
//           final emp     = entry.value;
//           final empName = emp['employee_name'] ?? 'Unknown';
//           final empInit = empName.isNotEmpty ? empName[0].toUpperCase() : '?';

//           return Column(children: [
//             if (idx > 0) const Divider(height: 1, color: _border),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
//               child: Row(children: [
//                 Container(
//                   width: 34, height: 34,
//                   decoration: BoxDecoration(
//                     color: (isLocked ? _slate : _green).withOpacity(0.08),
//                     shape: BoxShape.circle,
//                     border: Border.all(color: (isLocked ? _slate : _green).withOpacity(0.15))),
//                   child: Center(child: Text(empInit,
//                       style: TextStyle(
//                           fontSize: 13, fontWeight: FontWeight.w800,
//                           color: isLocked ? _slate : _green))),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                     Text(empName,
//                         style: TextStyle(
//                             fontSize: 13, fontWeight: FontWeight.w600,
//                             color: isLocked ? _textSecond : _textPrimary)),
//                     Text(emp['employee_role'] ?? '',
//                         style: const TextStyle(fontSize: 10, color: _textSecond)),
//                   ]),
//                 ),
//                 // Auto badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: (isLocked ? _slate : _black).withOpacity(0.06),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: (isLocked ? _slate : _black).withOpacity(0.15))),
//                   child: Row(mainAxisSize: MainAxisSize.min, children: [
//                     Icon(Icons.sync_rounded, size: 11, color: isLocked ? _slate : _black),
//                     const SizedBox(width: 4),
//                     Text('Auto', style: TextStyle(
//                         fontSize: 10,
//                         color: isLocked ? _slate : _black,
//                         fontWeight: FontWeight.w700)),
//                   ]),
//                 ),
//                 const SizedBox(width: 4),
//                 // Per-employee remove — only when unlocked
//                 if (!isLocked)
//                   IconButton(
//                     onPressed: () => _removeEmployee(emp['grouping_id'], empName),
//                     icon: const Icon(Icons.remove_circle_outline_rounded, color: _red, size: 20),
//                     padding: EdgeInsets.zero,
//                     constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
//                     tooltip: 'Remove $empName',
//                   )
//                 else
//                   const SizedBox(width: 32),
//               ]),
//             ),
//           ]);
//         }),

//         // ── Footer ───────────────────────────────────────────────────────
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
//           decoration: BoxDecoration(
//             color: isLocked ? _amber.withOpacity(0.03) : const Color(0xFFF8FAFC),
//             borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17))),
//           child: Row(children: [
//             Icon(
//               isLocked ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
//               size: 13,
//               color: isLocked ? _amber : _textSecond),
//             const SizedBox(width: 6),
//             Expanded(
//               child: Text(
//                 isLocked
//                     ? '$managerName has already checked in — this group is locked and cannot be edited.'
//                     : 'When $managerName checks in/out, attendance is auto-recorded for all grouped employees.',
//                 style: TextStyle(fontSize: 11, color: isLocked ? _amber : _textSecond),
//               ),
//             ),
//           ]),
//         ),
//       ]),
//     );
//   }

//   // ── Shared avatar widget ──────────────────────────────────────────────────
//   Widget _avatar(String name, Color color) {
//     final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
//     return Container(
//       width: 30, height: 30,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         shape: BoxShape.circle,
//         border: Border.all(color: color.withOpacity(0.2))),
//       child: Center(child: Text(initial,
//           style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Edit group bottom sheet
// // ─────────────────────────────────────────────────────────────────────────────
// class _EditGroupSheet extends StatefulWidget {
//   final Map<dynamic, dynamic> group;
//   final List<dynamic> allUsers;
//   final String date;
//   final VoidCallback onChanged;

//   const _EditGroupSheet({
//     required this.group,
//     required this.allUsers,
//     required this.date,
//     required this.onChanged,
//   });

//   @override
//   State<_EditGroupSheet> createState() => _EditGroupSheetState();
// }

// class _EditGroupSheetState extends State<_EditGroupSheet> {
//   static const _black  = Color(0xFF000000);
//   static const _green  = Color(0xFF059669);
//   static const _red    = Color(0xFFDC2626);
//   static const _amber  = Color(0xFFD97706);
//   static const _textPrimary = Color(0xFF111827);
//   static const _textSecond  = Color(0xFF6B7280);
//   static const _border      = Color(0xFFE5E7EB);

//   Set<int> toAdd = {};
//   bool saving = false;

//   List<dynamic> get _currentEmployees => widget.group['employees'] as List;

//   Set<int> get _currentIds =>
//       _currentEmployees.map<int>((e) => e['employee_id'] as int).toSet();

//   List<dynamic> get _addableUsers => widget.allUsers
//       .where((u) =>
//           u['id'] != widget.group['manager_id'] && !_currentIds.contains(u['id']))
//       .toList();

//   Future<void> _removeEmployee(int groupingId, String empName) async {
//     try {
//       await ApiService.deleteGrouping(groupingId);
//       widget.onChanged();
//       // Update local state so the sheet refreshes without closing
//       setState(() {
//         (widget.group['employees'] as List)
//             .removeWhere((e) => e['grouping_id'] == groupingId);
//       });
//       Get.snackbar('Removed', '$empName removed',
//           backgroundColor: _red, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);
//     } catch (e) {
//       Get.snackbar('Error', 'Failed: $e',
//           backgroundColor: _red, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);
//     }
//   }

//   Future<void> _addSelected() async {
//     if (toAdd.isEmpty) return;
//     setState(() => saving = true);
//     try {
//       final result = await ApiService.createGroupings(
//         managerId: widget.group['manager_id'],
//         employeeIds: toAdd.toList(),
//         date: widget.date,
//       );
//       widget.onChanged();
//       setState(() { toAdd.clear(); saving = false; });
//       final added = result['inserted_count'] ?? 0;
//       Get.snackbar('Added ✓', '$added employee(s) added to group',
//           backgroundColor: _green, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);
//     } catch (e) {
//       setState(() => saving = false);
//       Get.snackbar('Error', 'Failed: $e',
//           backgroundColor: _red, colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16), borderRadius: 14);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final managerName = widget.group['manager_name'] ?? 'Manager';

//     return Container(
//       decoration: const BoxDecoration(
//         color: Color(0xFFFFFFFF),
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//       padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
//       child: Column(mainAxisSize: MainAxisSize.min, children: [
//         // Handle bar
//         const SizedBox(height: 12),
//         Container(width: 40, height: 4,
//             decoration: BoxDecoration(
//                 color: _border, borderRadius: BorderRadius.circular(2))),
//         const SizedBox(height: 16),

//         // Title
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20),
//           child: Row(children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                   color: _black.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
//               child: const Icon(Icons.edit_rounded, color: _black, size: 18),
//             ),
//             const SizedBox(width: 12),
//             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               const Text('Edit Group',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
//               Text('Manager: $managerName',
//                   style: const TextStyle(fontSize: 12, color: _textSecond)),
//             ]),
//             const Spacer(),
//             IconButton(
//               onPressed: () => Get.back(),
//               icon: const Icon(Icons.close_rounded, color: _textSecond),
//             ),
//           ]),
//         ),

//         const SizedBox(height: 16),
//         const Divider(height: 1, color: _border),

//         ConstrainedBox(
//           constraints: BoxConstraints(
//               maxHeight: MediaQuery.of(context).size.height * 0.65),
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

//               // ── Current employees ─────────────────────────────────────────
//               const Text('CURRENT EMPLOYEES',
//                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
//                       color: _textSecond, letterSpacing: 1.2)),
//               const SizedBox(height: 10),

//               if (_currentEmployees.isEmpty)
//                 Container(
//                   padding: const EdgeInsets.all(14),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF8FAFC),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: _border)),
//                   child: const Text('No employees in this group',
//                       style: TextStyle(color: _textSecond, fontSize: 13)),
//                 )
//               else
//                 Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: _border),
//                     borderRadius: BorderRadius.circular(14),
//                     color: const Color(0xFFF8FAFC)),
//                   child: Column(children: _currentEmployees.asMap().entries.map((entry) {
//                     final idx = entry.key;
//                     final emp = entry.value;
//                     final empName = emp['employee_name'] ?? 'Unknown';
//                     final init = empName.isNotEmpty ? empName[0].toUpperCase() : '?';

//                     return Column(children: [
//                       if (idx > 0) const Divider(height: 1, color: _border),
//                       Padding(
//                         padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
//                         child: Row(children: [
//                           Container(
//                             width: 32, height: 32,
//                             decoration: BoxDecoration(
//                               color: _green.withOpacity(0.08),
//                               shape: BoxShape.circle,
//                               border: Border.all(color: _green.withOpacity(0.15))),
//                             child: Center(child: Text(init,
//                                 style: const TextStyle(
//                                     fontSize: 12, fontWeight: FontWeight.w800, color: _green))),
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                             Text(empName, style: const TextStyle(
//                                 fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
//                             Text(emp['employee_role'] ?? '',
//                                 style: const TextStyle(fontSize: 10, color: _textSecond)),
//                           ])),
//                           IconButton(
//                             onPressed: () => _removeEmployee(emp['grouping_id'], empName),
//                             icon: const Icon(Icons.remove_circle_outline_rounded,
//                                 color: _red, size: 20),
//                             padding: EdgeInsets.zero,
//                             constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
//                             tooltip: 'Remove',
//                           ),
//                         ]),
//                       ),
//                     ]);
//                   }).toList()),
//                 ),

//               const SizedBox(height: 22),

//               // ── Add more employees ────────────────────────────────────────
//               const Text('ADD MORE EMPLOYEES',
//                   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
//                       color: _textSecond, letterSpacing: 1.2)),
//               const SizedBox(height: 10),

//               if (_addableUsers.isEmpty)
//                 Container(
//                   padding: const EdgeInsets.all(14),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF8FAFC),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: _border)),
//                   child: const Text('All users are already in this group',
//                       style: TextStyle(color: _textSecond, fontSize: 13)),
//                 )
//               else
//                 Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: _border),
//                     borderRadius: BorderRadius.circular(14),
//                     color: const Color(0xFFF8FAFC)),
//                   child: Column(children: _addableUsers.asMap().entries.map((entry) {
//                     final idx = entry.key;
//                     final u   = entry.value;
//                     final uid = u['id'] as int;
//                     final sel = toAdd.contains(uid);
//                     final name = u['username'] ?? '';
//                     final init = name.isNotEmpty ? name[0].toUpperCase() : '?';

//                     return Column(children: [
//                       if (idx > 0) const Divider(height: 1, color: _border),
//                       InkWell(
//                         onTap: () => setState(() {
//                           if (sel) toAdd.remove(uid); else toAdd.add(uid);
//                         }),
//                         borderRadius: BorderRadius.circular(8),
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                           child: Row(children: [
//                             Container(
//                               width: 32, height: 32,
//                               decoration: BoxDecoration(
//                                 color: (sel ? _black : _textSecond).withOpacity(0.08),
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                     color: (sel ? _black : _textSecond).withOpacity(0.15))),
//                               child: Center(child: Text(init,
//                                   style: TextStyle(
//                                       fontSize: 12, fontWeight: FontWeight.w800,
//                                       color: sel ? _black : _textSecond))),
//                             ),
//                             const SizedBox(width: 10),
//                             Expanded(child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start, children: [
//                               Text(name, style: TextStyle(
//                                   fontSize: 13, fontWeight: FontWeight.w600,
//                                   color: sel ? _textPrimary : _textSecond)),
//                               Text(u['role'] ?? '',
//                                   style: const TextStyle(fontSize: 10, color: _textSecond)),
//                             ])),
//                             Container(
//                               width: 20, height: 20,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: sel ? _black : Colors.transparent,
//                                 border: Border.all(color: sel ? _black : _border, width: 2)),
//                               child: sel
//                                   ? const Icon(Icons.check, color: Colors.white, size: 12)
//                                   : null,
//                             ),
//                           ]),
//                         ),
//                       ),
//                     ]);
//                   }).toList()),
//                 ),

//               // Add button
//               if (_addableUsers.isNotEmpty) ...[
//                 const SizedBox(height: 16),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton.icon(
//                     onPressed: (saving || toAdd.isEmpty) ? null : _addSelected,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: _black, foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 14),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                       disabledBackgroundColor: _black.withOpacity(0.3)),
//                     icon: saving
//                         ? const SizedBox(width: 16, height: 16,
//                             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                         : const Icon(Icons.person_add_rounded, size: 18),
//                     label: Text(
//                       saving
//                           ? 'Adding...'
//                           : toAdd.isEmpty
//                               ? 'Select employees above'
//                               : 'Add ${toAdd.length} Employee(s)',
//                       style: const TextStyle(fontWeight: FontWeight.w700)),
//                   ),
//                 ),
//               ],
//             ]),
//           ),
//         ),
//       ]),
//     );
//   }
// }
