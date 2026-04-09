import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../controllers/login_controller.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginController controller = Get.put(LoginController());

  // Focus nodes for keyboard navigation
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  static const _bg = Color(0xFFFAFAFB);
  static const _black = Color(0xFF000000);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF64748B);

  // Secret-tap state
  int _tapCount = 0;
  bool _showDevButton = false;

  void _onTitleTap() {
    setState(() {
      _tapCount++;
      if (_tapCount > 0 && _tapCount % 5 == 0) {
        _showDevButton = !_showDevButton;
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _openDevMode() {
    // Show password verification dialog first
    _showPasswordDialog();
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_rounded, color: _black, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Developer Access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter password to access developer settings',
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter developer password',
                prefixIcon: const Icon(Icons.key_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _black, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _verifyPassword(passwordController.text, ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => _verifyPassword(passwordController.text, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Verify',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _verifyPassword(String password, BuildContext dialogContext) {
    // Replace 'admin123' with your desired secure password
    const String correctPassword = 'admin123';

    if (password == correctPassword) {
      Navigator.pop(dialogContext); // Close password dialog
      _showIpConfigModal(); // Show IP configuration modal
    } else {
      // Shake animation for wrong password
      HapticFeedback.heavyImpact();
      Get.snackbar(
        'Access Denied',
        'Incorrect password. Please try again.',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );

      // Clear password field
      final passwordController =
          (dialogContext as Element)
                  .findAncestorWidgetOfExactType<TextField>()
                  ?.decoration
              as InputDecoration?;
    }
  }

  void _showIpConfigModal() {
    final storage = GetStorage();
    final currentUrl = ApiService.baseUrl;

    // Parse existing ip:port
    final uri = Uri.tryParse(currentUrl);
    final ipCtrl = TextEditingController(text: uri?.host ?? dotenv.env['DEFAULT_SERVER_IP'] ?? '192.168.1.166');
    final portCtrl = TextEditingController(
      text: uri?.port.toString() ?? dotenv.env['DEFAULT_SERVER_PORT'] ?? '8002',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.developer_mode_rounded,
                            color: _black,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Developer Settings',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Network configuration',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Current URL display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active: ${ApiService.baseUrl}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // IP field
                    const Text(
                      'Server IP Address',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ipCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '192.168.1.100',
                        prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF000000),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Port field
                    const Text(
                      'Port',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '8002',
                        prefixIcon: const Icon(
                          Icons.settings_ethernet_rounded,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF000000),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.preview_rounded,
                            size: 14,
                            color: _black,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ValueListenableBuilder(
                              valueListenable: ipCtrl,
                              builder: (_, __, ___) => ValueListenableBuilder(
                                valueListenable: portCtrl,
                                builder: (_, __, ___) => Text(
                                  'http://${ipCtrl.text.trim()}:${portCtrl.text.trim()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Buttons row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final ip = ipCtrl.text.trim();
                              final port = portCtrl.text.trim();
                              if (ip.isEmpty || port.isEmpty) {
                                Get.snackbar(
                                  'Invalid',
                                  'IP and Port cannot be empty',
                                  backgroundColor: const Color(0xFFDC2626),
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                  margin: const EdgeInsets.all(16),
                                );
                                return;
                              }
                              final newUrl = 'http://$ip:$port';
                              ApiService.baseUrl = newUrl;
                              storage.write('dev_base_url', newUrl);
                              Navigator.pop(ctx);
                              Get.snackbar(
                                '✓ Applied',
                                'Server set to $newUrl',
                                backgroundColor: const Color(0xFF059669),
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 14,
                                duration: const Duration(seconds: 3),
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text(
                              'Save & Apply',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // Logo + branding (title tap = secret tap counter)
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF000000), Color(0xFF1F2937)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _black.withOpacity(0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tappable title
                        GestureDetector(
                          onTap: _onTitleTap,
                          behavior: HitTestBehavior.opaque,
                          child: const Text(
                            'MEPL-Track',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        const Text(
                          'EMPLOYEE SHIFT MANAGEMENT',
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 56),

                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to continue',
                    style: TextStyle(fontSize: 15, color: _textSecondary),
                  ),

                  const SizedBox(height: 36),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Username
                        TextField(
                          controller: controller.usernameController,
                          focusNode: _usernameFocusNode,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'Enter your username',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          onSubmitted: (_) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_passwordFocusNode);
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password
                        Obx(
                          () => TextField(
                            controller: controller.passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: controller.isPasswordHidden.value,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  controller.isPasswordHidden.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: controller.togglePasswordVisibility,
                              ),
                            ),
                            onSubmitted: (_) => controller.login(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login button
                        Obx(
                          () => SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : controller.login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _black,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _black.withOpacity(
                                  0.5,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: controller.isLoading.value
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Demo credentials hint
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: _black.withOpacity(0.05),
                  //     borderRadius: BorderRadius.circular(16),
                  //     border: Border.all(color: _black.withOpacity(0.12)),
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       Container(
                  //         padding: const EdgeInsets.all(8),
                  //         decoration: BoxDecoration(
                  //           color: _black.withOpacity(0.1),
                  //           borderRadius: BorderRadius.circular(10),
                  //         ),
                  //         child: const Icon(
                  //           Icons.info_outline_rounded,
                  //           color: _black,
                  //           size: 16,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 12),
                  //       const Column(
                  //         crossAxisAlignment: CrossAxisAlignment.start,
                  //         children: [
                  //           Text(
                  //             'admin  ·  admin123',
                  //             style: TextStyle(
                  //               color: _textPrimary,
                  //               fontSize: 13,
                  //               fontWeight: FontWeight.w600,
                  //             ),
                  //           ),
                  //           SizedBox(height: 2),
                  //           Text(
                  //             'Demo credentials',
                  //             style: TextStyle(
                  //               color: _textSecondary,
                  //               fontSize: 11,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  //
                  // const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),

      // ── Developer-mode floating button (appears after 5 taps on title) ──────
      floatingActionButton: _showDevButton
          ? FloatingActionButton(
              onPressed: _openDevMode,
              backgroundColor: const Color(0xFF000000),
              elevation: 6,
              tooltip: 'Developer Settings',
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
