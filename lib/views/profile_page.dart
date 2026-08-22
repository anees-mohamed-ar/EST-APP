import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _changePfp() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: _primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _primary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a photo to update your profile',
              style: TextStyle(
                fontSize: 14,
                color: _gray600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (employeeData?['pfp'] != null &&
                    employeeData!['pfp'].toString().isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      final pfp = employeeData!['pfp'];
                      Navigator.pop(ctx);
                      Get.to(
                        () => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            iconTheme: const IconThemeData(color: Colors.white),
                            title: const Text(
                              'Profile Picture',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          body: Center(
                            child: InteractiveViewer(
                              child: CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}$pfp',
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        transition: Transition.fadeIn,
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.visibility_outlined,
                            color: _primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'View Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: () async => Navigator.pop(
                    ctx,
                    await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: _primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Camera',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async => Navigator.pop(
                    ctx,
                    await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: _primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gallery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    try {
      final userData = storage.read('user');
      if (userData == null) return;

      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        barrierDismissible: false,
      );

      final result = await ApiService.updateUserProfile(
        userId: userData['id'],
        username: userData['username'],
        role: userData['role'],
        imagePath: image.path,
      );

      Get.back(); // close progress dialog

      await _loadEmployeeData();
      Get.snackbar(
        'Success',
        'Profile picture updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _success,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.back(); // close progress dialog if open
      Get.snackbar(
        'Error',
        'Failed to update profile picture: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _danger,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
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
    bool isCopyable = false,
  }) {
    final isNA = value == '—' || value == 'N/A';
    return InkWell(
      onTap: isCopyable && !isNA ? () => _copyValue(label, value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: _gray400),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: _gray600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isNA ? _gray400 : _primary,
                      ),
                    ),
                  ),
                  if (isCopyable && !isNA) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 13, color: _gray400),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContainer({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _shadow.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _quickStat(
    String label,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: _shadow.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _primary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: _gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Enlarged ID Card Modal ──────────────────────────────────────────────────
  void _showEnlargedIDCard({
    required String title,
    required String idNumber,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final isNA = idNumber == '—' || idNumber == 'N/A' || idNumber.isEmpty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Card container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.9), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative background icon
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Icon(
                          icon,
                          size: 140,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Employee info snippet
                            if (employeeData != null) ...[
                              Text(
                                (employeeData!['full_name'] ??
                                        employeeData!['employee_name'] ??
                                        '')
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],

                            // ID Number display
                            SelectableText(
                              idNumber,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isNA ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: isNA ? 0 : 2.0,
                                fontFamily: isNA ? null : 'Monospace',
                              ),
                            ),

                            if (!isNA) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: [
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
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color: Colors.white,
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
                        child: Text(
                          idNumber,
                          style: TextStyle(
                            fontSize: isNA ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            color: isNA ? _gray400 : _primary,
                            letterSpacing: isNA ? 0 : 1.2,
                            fontFamily: isNA ? null : 'Monospace',
                          ),
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
          const SizedBox(height: 16),

          // Basic employment info card
          _cardContainer(
            children: [
              _sectionHeader('EMPLOYMENT INFO', Icons.badge_outlined),
              _infoRow(
                icon: Icons.tag_rounded,
                label: 'Employee ID',
                value: employeeData!['employee_id']?.toString() ?? '—',
                isCopyable: true,
              ),
              _divider(),
              _infoRow(
                icon: Icons.business_outlined,
                label: 'Department',
                value: employeeData!['department']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.work_outline_rounded,
                label: 'Designation',
                value: employeeData!['designation']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.event_available_outlined,
                label: 'Date of Joining',
                value: _formatDate(employeeData!['date_of_joining']),
              ),
              if (employeeData!['date_of_exit'] != null) ...[
                _divider(),
                _infoRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Date of Exit',
                  value: _formatDate(employeeData!['date_of_exit']),
                ),
              ],
            ],
          ),

          // Personal summary card
          _cardContainer(
            children: [
              _sectionHeader('PERSONAL DETAILS', Icons.person_outline_rounded),
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
                icon: Icons.favorite_border_rounded,
                label: 'Marital Status',
                value: employeeData!['marital_status']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.people_outline_rounded,
                label: 'Father / Husband',
                value:
                    employeeData!['father_or_husband_name']?.toString() ?? '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTab() {
    if (employeeData == null) return const SizedBox();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _cardContainer(
            children: [
              _sectionHeader('CONTACT & DEMOGRAPHICS', Icons.contact_phone_outlined),
              _infoRow(
                icon: Icons.phone_android_rounded,
                label: 'Mobile Number',
                value: employeeData!['mobile']?.toString() ?? '—',
                isCopyable: true,
              ),
              _divider(),
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
                icon: Icons.favorite_border_rounded,
                label: 'Marital Status',
                value: employeeData!['marital_status']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.people_outline_rounded,
                label: 'Father / Husband',
                value:
                    employeeData!['father_or_husband_name']?.toString() ?? '—',
              ),
            ],
          ),

          _cardContainer(
            children: [
              _sectionHeader('ADDRESS INFORMATION', Icons.location_on_outlined),
              _infoRow(
                icon: Icons.home_outlined,
                label: 'Present Address',
                value: employeeData!['present_address']?.toString() ?? '—',
                isCopyable: true,
              ),
              _divider(),
              _infoRow(
                icon: Icons.location_city_outlined,
                label: 'Permanent Address',
                value: employeeData!['permanent_address']?.toString() ?? '—',
                isCopyable: true,
              ),
            ],
          ),

          _cardContainer(
            children: [
              _sectionHeader('INSURANCE & DEPENDENTS', Icons.family_restroom_rounded),
              _infoRow(
                icon: Icons.shield_outlined,
                label: 'Primary Insured',
                value:
                    employeeData!['primary_insured_person']?.toString() ?? '—',
              ),
              _divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 17,
                      color: _gray400,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      flex: 4,
                      child: Text(
                        'Family Members',
                        style: TextStyle(
                          fontSize: 13,
                          color: _gray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _familyMembersChips(
                          _cleanFamilyMembers(
                            employeeData!['family_members']?.toString(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialTab() {
    if (employeeData == null) return const SizedBox();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _cardContainer(
            children: [
              _sectionHeader('ORGANIZATION & ROLE', Icons.work_outline_rounded),
              _infoRow(
                icon: Icons.tag_rounded,
                label: 'Employee ID',
                value: employeeData!['employee_id']?.toString() ?? '—',
                isCopyable: true,
              ),
              _divider(),
              _infoRow(
                icon: Icons.business_outlined,
                label: 'Department',
                value: employeeData!['department']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.work_history_outlined,
                label: 'Designation',
                value: employeeData!['designation']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'System Role',
                value: employeeData!['role']?.toString() ?? '—',
              ),
              _divider(),
              _infoRow(
                icon: Icons.directions_car_outlined,
                label: 'Driver Access',
                value:
                    (employeeData!['driver_access']?.toString().toLowerCase() ==
                            'yes')
                        ? 'Granted'
                        : 'Not Granted',
              ),
              _divider(),
              _infoRow(
                icon: Icons.timelapse_outlined,
                label: 'OT Eligibility',
                value: employeeData!['is_ot_eligible'] == 1
                    ? 'Eligible'
                    : 'Not Eligible',
              ),
            ],
          ),

          _cardContainer(
            children: [
              _sectionHeader('TIMELINE & DATES', Icons.calendar_month_outlined),
              _infoRow(
                icon: Icons.event_available_outlined,
                label: 'Date of Joining',
                value: _formatDate(employeeData!['date_of_joining']),
              ),
              if (employeeData!['date_of_exit'] != null) ...[
                _divider(),
                _infoRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Date of Exit',
                  value: _formatDate(employeeData!['date_of_exit']),
                ),
              ],
              _divider(),
              _infoRow(
                icon: Icons.history_toggle_off_rounded,
                label: 'Total Experience',
                value: '${employeeData!['experience_years'] ?? 0} Years',
              ),
              _divider(),
              _infoRow(
                icon: Icons.credit_card_outlined,
                label: 'ID Card Printed',
                value:
                    (employeeData!['id_card_printed']?.toString().toLowerCase() ==
                            'yes')
                        ? 'Printed'
                        : 'Pending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab() {
    if (employeeData == null) return const SizedBox();
    final emp = employeeData!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: [
          _idProofCard(
            title: 'Aadhar Card',
            idNumber: emp['aadhar_no']?.toString() ?? '—',
            icon: Icons.fingerprint_rounded,
            color: const Color(0xFF2563EB),
            subtitle:
                'Linked Mobile: ${emp['aadhar_linked_mobile']?.toString() ?? '—'}',
          ),
          _idProofCard(
            title: 'UAN / EPF Number',
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
                            // Avatar with upload option
                            GestureDetector(
                              onTap: _changePfp,
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
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1A2340),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 13,
                                        color: _primary,
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
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    employeeData?['designation']?.toString() ??
                                        'Employee',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.75),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'ID: ${employeeData?['employee_id'] ?? '—'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isActive ? _success : _danger)
                                              .withOpacity(0.25),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isActive ? _success : _danger,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? _success
                                                    : _danger,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isActive ? 'ACTIVE' : 'INACTIVE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isActive
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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

                  // ── Persistent TabBar ──────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: _accent,
                        indicatorWeight: 3,
                        labelColor: _primary,
                        unselectedLabelColor: _gray600,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Personal'),
                          Tab(text: 'Official'),
                          Tab(text: 'Identity & Cards'),
                          Tab(text: 'Documents'),
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
                    _buildOfficialTab(),
                    _buildIdentityTab(),
                    const Center(
                      child: Text(
                        'No documents uploaded yet',
                        style: TextStyle(color: _gray600),
                      ),
                    ),
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
