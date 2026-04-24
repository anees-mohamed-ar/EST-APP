import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final storage = GetStorage();
  Map<String, dynamic>? employeeData;
  bool isLoading = true;
  late TabController _tabController;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF4F6FA);
  static const _cardColor = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF2C2C2C); // Charcoal primary
  static const _accent = Color(0xFF2C2C2C);
  static const _accentLight = Color(0xFFF5F5F5);
  static const _success = Color(0xFF12B76A);
  static const _danger = Color(0xFFEF4444);
  static const _gray400 = Color(0xFF9CA3AF);
  static const _gray600 = Color(0xFF4B5563);
  static const _border = Color(0xFFE8ECF4);
  static const _shadow = Color(0xFF1A2340);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadEmployeeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeeData() async {
    try {
      final userData = storage.read('user');
      if (userData == null) {
        Get.offAllNamed('/login');
        return;
      }
      final data = await ApiService.getEmployeeById(userData['id']);
      if (data != null && mounted) {
        // Sync with local storage to keep other pages (like Home) updated
        final updatedUser = Map<String, dynamic>.from(userData);
        if (data['username'] != null)
          updatedUser['username'] = data['username'];
        if (data['role'] != null) updatedUser['role'] = data['role'];
        if (data['pfp'] != null) updatedUser['pfp'] = data['pfp'];
        if (data['full_name'] != null)
          updatedUser['full_name'] = data['full_name'];
        if (data['employee_name'] != null)
          updatedUser['employee_name'] = data['employee_name'];
        storage.write('user', updatedUser);

        setState(() {
          employeeData = data;
          isLoading = false;
        });
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load profile data',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _danger,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return '—';
    }
  }

  // Clean family_members field by removing numeric PHS ID values
  List<String> _cleanFamilyMembers(String? familyMembers) {
    if (familyMembers == null || familyMembers.isEmpty) return [];

    final parts = familyMembers.split(',').map((e) => e.trim()).toList();
    final cleanedParts = parts.where((part) {
      // Remove if the part is purely numeric (PHS ID)
      return !RegExp(r'^\d+$').hasMatch(part);
    }).toList();

    return cleanedParts;
  }

  // Widget to display family members as chips
  Widget _familyMembersChips(List<String> members) {
    if (members.isEmpty) {
      return Text(
        '—',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: members.map((member) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withOpacity(0.2), width: 1),
          ),
          child: Text(
            member,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helper: copy-to-clipboard with haptic ─────────────────────────────────
  void _copyValue(String label, String value) {
    if (value == '—' || value == 'N/A') return;
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    Get.snackbar(
      'Copied',
      '$label copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _primary,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  // ── Atoms ──────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _primary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  Widget _divider() => const Divider(height: 1, thickness: 1, color: _border);

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
    Color? valueColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: copyable ? () => _copyValue(label, value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _gray400),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _gray400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? _primary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (copyable && value != '—' && value != 'N/A')
              const Icon(Icons.copy_rounded, size: 14, color: _gray400),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border, width: 1),
      boxShadow: [
        BoxShadow(
          color: _shadow.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _statusBadge(String text, bool isActive) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isActive ? _success.withOpacity(0.10) : _danger.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? _success : _danger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? _success : _danger,
          ),
        ),
      ],
    ),
  );

  // ── ID CARD MODAL ─────────────────────────────────────────────────────────
  void _showEnlargedIDCard({
    required String title,
    required String idNumber,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final isNA = idNumber == '—' || idNumber == 'N/A' || idNumber.isEmpty;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, __, ___) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: GestureDetector(
                  onTap:
                      () {}, // Prevent tap from closing when clicking on card
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color.withOpacity(0.9), color],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (subtitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isNA ? 'NOT ISSUED' : 'VERIFIED',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Body
                            Container(
                              color: _cardColor,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID NUMBER',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _gray400,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: color.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isNA ? 'Not Available' : idNumber,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isNA ? _gray400 : _primary,
                                        letterSpacing: isNA ? 0 : 2,
                                        fontFamily: isNA ? null : 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          icon: const Icon(Icons.close),
                                          label: const Text('Close'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _gray600,
                                            side: BorderSide(color: _border),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!isNA) ...[
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () {
                                              _copyValue(title, idNumber);
                                            },
                                            icon: const Icon(Icons.copy),
                                            label: const Text('Copy'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: color,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── ID CARD widget ─────────────────────────────────────────────────────────
  Widget _idProofCard({
    required String title,
    required String idNumber,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final isNA = idNumber == '—' || idNumber == 'N/A' || idNumber.isEmpty;
    return Semantics(
      button: true,
      label: '$title card, tap to view details',
      child: GestureDetector(
        onTap: () => _showEnlargedIDCard(
          title: title,
          idNumber: idNumber,
          icon: icon,
          color: color,
          subtitle: subtitle,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 1),
            boxShadow: [
              BoxShadow(
                color: _shadow.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Card header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.85), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label: title,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Semantics(
                                label: subtitle,
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isNA ? 'NOT ISSUED' : 'VERIFIED',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card body
                Container(
                  color: _cardColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label: 'ID Number',
                              child: Text(
                                'ID NUMBER',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _gray400,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Semantics(
                              label: isNA ? 'Not Available' : idNumber,
                              value: isNA ? 'Not Available' : idNumber,
                              child: Text(
                                isNA ? 'Not Available' : idNumber,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isNA ? _gray400 : _primary,
                                  letterSpacing: isNA ? 0 : 1.5,
                                  fontFamily: isNA ? null : 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isNA)
                        GestureDetector(
                          onTap: () => _copyValue(title, idNumber),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (employeeData == null) return const SizedBox();
    final isActive = employeeData!['is_active'] == 1;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          // Quick stats row
          Row(
            children: [
              _quickStat(
                'Experience',
                '${employeeData!['experience_years'] ?? 0} Yrs',
                Icons.workspace_premium_outlined,
                const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 10),
              _quickStat(
                'Status',
                isActive ? 'Active' : 'Inactive',
                isActive ? Icons.verified_rounded : Icons.block_rounded,
                isActive ? _success : _danger,
              ),
              const SizedBox(width: 10),
              _quickStat(
                'Role',
                employeeData!['role']?.toString() ?? 'N/A',
                Icons.admin_panel_settings_outlined,
                _accent,
              ),
            ],
          ),
          const SizedBox(height: 6),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'EMPLOYMENT DETAILS',
                  Icons.work_history_outlined,
                ),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.badge_outlined,
                  label: 'Employee ID',
                  value: employeeData!['employee_id']?.toString() ?? '—',
                  copyable: true,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.person_outline,
                  label: 'Designation',
                  value: employeeData!['designation']?.toString() ?? '—',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: employeeData!['department']?.toString() ?? '—',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date of Joining',
                  value: _formatDate(employeeData!['date_of_joining']),
                ),
                if (employeeData!['date_of_exit'] != null) ...[
                  _divider(),
                  _infoRow(
                    icon: Icons.exit_to_app_outlined,
                    label: 'Date of Exit',
                    value: _formatDate(employeeData!['date_of_exit']),
                  ),
                ],
              ],
            ),
          ),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'ATTENDANCE & ENTITLEMENTS',
                  Icons.schedule_outlined,
                ),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.access_time_outlined,
                  label: 'OT Eligible',
                  value: employeeData!['is_ot_eligible'] == 1 ? 'Yes' : 'No',
                  valueColor: employeeData!['is_ot_eligible'] == 1
                      ? _success
                      : _gray600,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.credit_card_outlined,
                  label: 'ID Card Printed',
                  value: employeeData!['id_card_printed'] == 1 ? 'Yes' : 'No',
                  valueColor: employeeData!['id_card_printed'] == 1
                      ? _success
                      : _gray600,
                ),
              ],
            ),
          ),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('ACCOUNT STATUS', Icons.security_outlined),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account Status',
                  value: isActive ? 'Active' : 'Inactive',
                  trailing: _statusBadge(
                    isActive ? 'Active' : 'Inactive',
                    isActive,
                  ),
                ),
                _divider(),
                _infoRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'System Role',
                  value: employeeData!['role']?.toString() ?? '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _gray400,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPersonalTab() {
    if (employeeData == null) return const SizedBox();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'PERSONAL INFORMATION',
                  Icons.person_pin_outlined,
                ),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: _formatDate(employeeData!['dob']),
                ),
                _divider(),
                _infoRow(
                  icon: Icons.bloodtype_outlined,
                  label: 'Blood Group',
                  value: employeeData!['blood_group']?.toString() ?? '—',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.favorite_border,
                  label: 'Marital Status',
                  value: employeeData!['marital_status']?.toString() ?? '—',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.family_restroom_outlined,
                  label: 'Father / Husband Name',
                  value:
                      employeeData!['father_or_husband_name']?.toString() ??
                      '—',
                ),
              ],
            ),
          ),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('CONTACT DETAILS', Icons.contact_phone_outlined),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.phone_outlined,
                  label: 'Mobile Number',
                  value: employeeData!['mobile']?.toString() ?? '—',
                  copyable: true,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.perm_identity_outlined,
                  label: 'Aadhar Number',
                  value: employeeData!['aadhar_no']?.toString() ?? '—',
                  copyable: true,
                ),
                if (employeeData!['aadhar_linked_mobile'] != null) ...[
                  _divider(),
                  _infoRow(
                    icon: Icons.link_rounded,
                    label: 'Aadhar Linked Mobile',
                    value:
                        employeeData!['aadhar_linked_mobile']?.toString() ??
                        '—',
                    copyable: true,
                  ),
                ],
                if (employeeData!['wc_no'] != null) ...[
                  _divider(),
                  _infoRow(
                    icon: Icons.workspaces_outlined,
                    label: 'WC Number',
                    value: employeeData!['wc_no']?.toString() ?? '—',
                    copyable: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressTab() {
    if (employeeData == null) return const SizedBox();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('PERMANENT ADDRESS', Icons.home_outlined),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: employeeData!['permanent_address']?.toString() ?? '—',
                ),
              ],
            ),
          ),
          if (employeeData!['present_address'] != null)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    'PRESENT ADDRESS',
                    Icons.location_city_outlined,
                  ),
                  _divider(),
                  const SizedBox(height: 4),
                  _infoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: employeeData!['present_address']?.toString() ?? '—',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    if (employeeData == null) return const SizedBox();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('PF & ESIC', Icons.account_balance_outlined),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.account_balance_outlined,
                  label: 'UAN No (EPF)',
                  value: employeeData!['uan_no_epf']?.toString() ?? '—',
                  copyable: true,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'ESIC Number',
                  value: employeeData!['esic_no']?.toString() ?? '—',
                  copyable: true,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.check_circle_outline,
                  label: 'ESIC Eligibility',
                  value: employeeData!['esic_eligibility']?.toString() ?? '—',
                ),
                if (employeeData!['esic_value'] != null) ...[
                  _divider(),
                  _infoRow(
                    icon: Icons.payments_outlined,
                    label: 'ESIC Value',
                    value: employeeData!['esic_value']?.toString() ?? '—',
                  ),
                ],
                _divider(),
                _infoRow(
                  icon: Icons.assignment_ind_outlined,
                  label: 'PHS ID',
                  value: employeeData!['phs_id']?.toString() ?? '—',
                  copyable: true,
                ),
              ],
            ),
          ),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'BANK ACCOUNT',
                  Icons.account_balance_wallet_outlined,
                ),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.credit_card_outlined,
                  label: 'Account Number',
                  value: employeeData!['bank_account_no']?.toString() ?? '—',
                  copyable: true,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.qr_code_rounded,
                  label: 'IFSC Code',
                  value: employeeData!['ifsc_code']?.toString() ?? '—',
                  copyable: true,
                ),
              ],
            ),
          ),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('INSURANCE', Icons.shield_outlined),
                _divider(),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.person_outline,
                  label: 'Primary Insured Person',
                  value:
                      employeeData!['primary_insured_person']?.toString() ??
                      '—',
                ),
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 17,
                        color: _gray400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Family Members',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _gray400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _familyMembersChips(
                              _cleanFamilyMembers(
                                employeeData!['family_members']?.toString(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ID PROOFS TAB ──────────────────────────────────────────────────────────
  Widget _buildIDProofsTab() {
    if (employeeData == null) return const SizedBox();

    final emp = employeeData!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          // Instruction banner
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap the copy icon on any ID to copy it for client verification.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _accent.withOpacity(0.90),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _idProofCard(
            title: 'Employee ID',
            idNumber: emp['employee_id']?.toString() ?? '—',
            icon: Icons.badge_rounded,
            color: _accent,
            subtitle: 'Internal company identifier',
          ),
          _idProofCard(
            title: 'Aadhar Card',
            idNumber: emp['aadhar_no']?.toString() ?? '—',
            icon: Icons.perm_identity_rounded,
            color: const Color(0xFF0891B2),
            subtitle: 'Government issued unique ID',
          ),
          _idProofCard(
            title: 'UAN (EPF)',
            idNumber: emp['uan_no_epf']?.toString() ?? '—',
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF059669),
            subtitle: 'Universal Account Number — Provident Fund',
          ),
          _idProofCard(
            title: 'ESIC Number',
            idNumber: emp['esic_no']?.toString() ?? '—',
            icon: Icons.health_and_safety_rounded,
            color: const Color(0xFFD97706),
            subtitle: 'Employees State Insurance Corporation',
          ),
          _idProofCard(
            title: 'PHS ID',
            idNumber: emp['phs_id']?.toString() ?? '—',
            icon: Icons.local_hospital_rounded,
            color: const Color(0xFF7C3AED),
            subtitle: 'Personal Health Scheme',
          ),
          _idProofCard(
            title: 'Bank Account',
            idNumber: emp['bank_account_no']?.toString() ?? '—',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFDB2777),
            subtitle: 'IFSC: ${emp['ifsc_code']?.toString() ?? '—'}',
          ),
          _idProofCard(
            title: 'WC Number',
            idNumber: emp['wc_no']?.toString() ?? '—',
            icon: Icons.workspaces_rounded,
            color: const Color(0xFF64748B),
            subtitle: 'Workmen Compensation',
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userData = storage.read('user');
    final username = userData?['username']?.toString() ?? 'User';
    final fullName =
        employeeData?['full_name'] ??
        employeeData?['employee_name'] ??
        username;
    final pfp = employeeData?['pfp'];
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final isActive = employeeData?['is_active'] == 1;

    return Scaffold(
      backgroundColor: _bg,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ElectricRefreshIndicator(
              onRefresh: _loadEmployeeData,
              color: _accent,
              backgroundColor: _cardColor,
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // ── Sliver App Bar ─────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: _primary,
                    expandedHeight: 200,
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                    ),
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => Get.back(),
                    ),
                    title: AnimatedOpacity(
                      opacity: innerBoxIsScrolled ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                        child: Row(
                          children: [
                            // Avatar
                            GestureDetector(
                              onTap: () {
                                if (pfp != null && pfp.isNotEmpty) {
                                  Get.to(
                                    () => Scaffold(
                                      backgroundColor: Colors.black,
                                      appBar: AppBar(
                                        backgroundColor: Colors.black,
                                        iconTheme: const IconThemeData(
                                          color: Colors.white,
                                        ),
                                      ),
                                      body: Center(
                                        child: InteractiveViewer(
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                '${ApiService.baseUrl}$pfp',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.35),
                                        width: 2.5,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: pfp != null && pfp.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                '${ApiService.baseUrl}$pfp',
                                            fit: BoxFit.cover,
                                            memCacheWidth: 152,
                                            memCacheHeight: 152,
                                            placeholder: (_, __) => Center(
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: isActive ? _success : _danger,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1A2340),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    employeeData?['designation']?.toString() ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.60),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          employeeData?['department']
                                                  ?.toString() ??
                                              '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(
                                              0.60,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _statusBadge(
                                    isActive ? 'Active Employee' : 'Inactive',
                                    isActive,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Tab Bar ────────────────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: _accent,
                        unselectedLabelColor: _gray400,
                        indicatorColor: _accent,
                        indicatorWeight: 2.5,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        tabs: const [
                          Tab(text: 'OVERVIEW'),
                          Tab(text: 'PERSONAL'),
                          Tab(text: 'ADDRESS'),
                          Tab(text: 'DOCUMENTS'),
                          Tab(text: 'ID PROOFS'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildPersonalTab(),
                    _buildAddressTab(),
                    _buildDocumentsTab(),
                    _buildIDProofsTab(),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Sticky TabBar delegate ─────────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
