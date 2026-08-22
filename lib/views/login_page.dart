import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../controllers/login_controller.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final LoginController controller = Get.put(LoginController());

  // Focus nodes for keyboard navigation
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  // Ticker for 60fps real-time physics lightning simulation
  late Ticker _ticker;
  final _LightningSimulator _lightningSimulator = _LightningSimulator();

  // Modern Slate Backdrop for prominent card elevation and separation
  static const _bg = Color(0xFFE8EEF5);
  static const _primaryDark = Color(0xFF0F172A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _textMuted = Color(0xFF94A3B8);
  static const _borderLight = Color(0xFFCBD5E1);

  // Secret-tap state for developer access
  int _tapCount = 0;
  bool _showDevButton = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _lightningSimulator.update();
      if (mounted) {
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onTitleTap() {
    setState(() {
      _tapCount++;
      if (_tapCount > 0 && _tapCount % 5 == 0) {
        _showDevButton = !_showDevButton;
        HapticFeedback.mediumImpact();
        Get.snackbar(
          _showDevButton ? 'Developer Mode Enabled' : 'Developer Mode Disabled',
          _showDevButton ? 'Settings button is now visible' : 'Settings button hidden',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primaryDark,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    });
  }

  void _openDevMode() {
    _showPasswordDialog();
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: _primaryDark, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Developer Access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
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
              'Enter password to access server network settings',
              style: TextStyle(fontSize: 13, color: _textSecondary),
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
                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryDark, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onSubmitted: (_) => _verifyPassword(passwordController.text, ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => _verifyPassword(passwordController.text, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _verifyPassword(String password, BuildContext dialogContext) {
    const String correctPassword = 'admin123';

    if (password == correctPassword) {
      Navigator.pop(dialogContext);
      _showIpConfigModal();
    } else {
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
    }
  }

  void _showIpConfigModal() {
    final currentUrl = ApiService.baseUrl;
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryDark.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.developer_mode_rounded, color: _primaryDark, size: 22),
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
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              'Server network configuration',
                              style: TextStyle(fontSize: 12, color: _textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active: ${ApiService.baseUrl}',
                              style: const TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Server IP Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ipCtrl,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. 192.168.1.100',
                        prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryDark, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Port', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: '8002',
                        prefixIcon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryDark, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final defaultIp = dotenv.env['DEFAULT_SERVER_IP'] ?? '103.160.163.70';
                              final defaultPort = dotenv.env['DEFAULT_SERVER_PORT'] ?? '8002';
                              GetStorage().remove('dev_base_url');
                              ApiService.baseUrl = 'http://$defaultIp:$defaultPort';
                              Navigator.pop(ctx);
                              Get.snackbar(
                                'Reset Complete',
                                'Reverted to default server configuration',
                                backgroundColor: _primaryDark,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 12,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _borderLight),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset Default', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final ip = ipCtrl.text.trim();
                              final port = portCtrl.text.trim();
                              if (ip.isEmpty) return;
                              final newUrl = port.isNotEmpty ? 'http://$ip:$port' : 'http://$ip';
                              GetStorage().write('dev_base_url', newUrl);
                              ApiService.baseUrl = newUrl;
                              Navigator.pop(ctx);
                              Get.snackbar(
                                'Settings Applied',
                                'Server URL updated: $newUrl',
                                backgroundColor: const Color(0xFF10B981),
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 12,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save & Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
      body: Stack(
        children: [
          // ── Realistic Random Lightning Arc Canvas ───────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _lightningSimulator.updateSize(Size(constraints.maxWidth, constraints.maxHeight));
                return CustomPaint(
                  painter: _RealisticLightningPainter(
                    arcs: _lightningSimulator.arcs,
                  ),
                );
              },
            ),
          ),

          // ── Main Scrollable View ───────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      // ── Brand Logo & Identity in Frosted Glass Container ────
                      GestureDetector(
                        onTap: _onTitleTap,
                        behavior: HitTestBehavior.opaque,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Clean Logo Card
                                  Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Padding(
                                        padding: const EdgeInsets.all(11),
                                        child: Image.asset(
                                          'assets/images/me-logo-clean.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Company Header
                                  const Text(
                                    'MENAKA ELECTRICALS PVT LTD',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _textSecondary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // App Main Title
                                  const Text(
                                    'MEPL-Track',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: _textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Subtitle Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _primaryDark.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _primaryDark.withValues(alpha: 0.10)),
                                    ),
                                    child: const Text(
                                      'EMPLOYEE SHIFT MANAGEMENT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Frosted Glass Sign-In Form Container ─────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _primaryDark.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                        color: _primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Employee Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter your assigned MEPL ID & password',
                                  style: TextStyle(fontSize: 12, color: _textSecondary),
                                ),
                                const SizedBox(height: 22),

                                // ── Username Input ─────────────────────────────
                                const Text(
                                  'Username / Employee ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: controller.usernameController,
                                  focusNode: _usernameFocusNode,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. MEPL001',
                                    hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: _textSecondary),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.75),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: _primaryDark, width: 1.8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                                  },
                                ),

                                const SizedBox(height: 16),

                                // ── Password Input ─────────────────────────────
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Obx(
                                  () => TextField(
                                    controller: controller.passwordController,
                                    focusNode: _passwordFocusNode,
                                    obscureText: controller.isPasswordHidden.value,
                                    textInputAction: TextInputAction.done,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter your password',
                                      hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: _textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          controller.isPasswordHidden.value
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: _textMuted,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          controller.togglePasswordVisibility();
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.75),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: _primaryDark, width: 1.8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    onSubmitted: (_) => controller.login(),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ── Sign In Button ─────────────────────────────
                                Obx(
                                  () => SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: controller.isLoading.value ? null : controller.login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryDark,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: _primaryDark.withValues(alpha: 0.6),
                                        elevation: 0,
                                        shadowColor: Colors.black.withValues(alpha: 0.2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: controller.isLoading.value
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Sign In',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward_rounded, size: 18),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Footer Copyright & Identification ───────────────────
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'System Online & Encrypted',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Developed by iMatrix Technologies Pvt Ltd © ${DateTime.now().year}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _textMuted,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Developer Floating Button ─────────────────────────────────────────
      floatingActionButton: _showDevButton
          ? FloatingActionButton(
              onPressed: _openDevMode,
              backgroundColor: _primaryDark,
              elevation: 6,
              tooltip: 'Developer Settings',
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 22,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── Realistic Lightning Arc Data Models ───────────────────────────────────────
class _LightningBranch {
  final List<Offset> points;
  final double startFraction;

  _LightningBranch({required this.points, required this.startFraction});
}

class _LightningArc {
  final List<Offset> points;
  final List<_LightningBranch> branches;
  final Color color;
  final double strokeWidth;
  final int growFrames;
  final int holdFrames;
  final int decayFrames;
  final int totalFrames;
  int life = 0;

  _LightningArc({
    required this.points,
    required this.branches,
    required this.color,
    required this.strokeWidth,
    required this.growFrames,
    required this.holdFrames,
    required this.decayFrames,
  }) : totalFrames = growFrames + holdFrames + decayFrames;
}

// ── Realistic Lightning Physics Simulator (Port of Web Lightning Engine) ──────
class _LightningSimulator {
  final List<_LightningArc> arcs = [];
  final math.Random _rng = math.Random();
  DateTime _lastSpawnTime = DateTime.now();
  int _nextDelayMs = 1500;
  Size _lastSize = const Size(400, 800);

  void updateSize(Size size) {
    if (size.width > 20 && size.height > 20) {
      _lastSize = size;
    }
  }

  // Recursive midpoint displacement for authentic jagged fractal lightning bolts
  List<Offset> _buildArc(Offset p1, Offset p2, double roughness, int depth) {
    if (depth == 0) return [p1, p2];

    final mx = (p1.dx + p2.dx) / 2;
    final my = (p1.dy + p2.dy) / 2;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return [p1, p2];

    final perp = (_rng.nextDouble() - 0.5) * roughness * len;
    final nx = -dy / len;
    final ny = dx / len;

    final pm = Offset(mx + nx * perp, my + ny * perp);

    final left = _buildArc(p1, pm, roughness * 0.82, depth - 1);
    final right = _buildArc(pm, p2, roughness * 0.82, depth - 1);

    return [...left, ...right.sublist(1)];
  }

  void _spawnArc() {
    final w = _lastSize.width;
    final h = _lastSize.height;
    if (w < 40 || h < 40) return;

    double jitter() => (_rng.nextDouble() - 0.5) * 40;

    // Corner / edge boundaries
    final corners = [
      Offset(jitter(), jitter()),
      Offset(w + jitter(), jitter()),
      Offset(w + jitter(), h + jitter()),
      Offset(jitter(), h + jitter()),
    ];

    final startIdx = _rng.nextInt(4);
    int endIdx = _rng.nextInt(3);
    if (endIdx >= startIdx) endIdx++;

    final p1 = corners[startIdx];
    final p2 = corners[endIdx];

    final depth = 6 + _rng.nextInt(3); // 6 to 8 recursive subdivs
    final roughness = 0.30 + _rng.nextDouble() * 0.32;
    final points = _buildArc(p1, p2, roughness, depth);

    // Dynamic branched forks (40% chance of high-voltage forks)
    final branches = <_LightningBranch>[];
    if (_rng.nextDouble() < 0.40 && points.length > 8) {
      final branchIndex = (points.length * (0.25 + _rng.nextDouble() * 0.45)).floor();
      final bp1 = points[branchIndex];

      final mainAngle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      final bAngle = mainAngle + (_rng.nextBool() ? 1 : -1) * (0.4 + _rng.nextDouble() * 0.9);
      final bDist = math.min(w, h) * (0.18 + _rng.nextDouble() * 0.28);
      final bp2 = Offset(bp1.dx + math.cos(bAngle) * bDist, bp1.dy + math.sin(bAngle) * bDist);

      branches.add(_LightningBranch(
        points: _buildArc(bp1, bp2, roughness * 0.7, depth - 2),
        startFraction: branchIndex / points.length,
      ));
    }

    // Authentic Phase Timing: GROW (~100-180ms) -> HOLD (~400-800ms) -> DECAY (~800-1400ms)
    final growFrames = 6 + _rng.nextInt(6);
    final holdFrames = 25 + _rng.nextInt(25);
    final decayFrames = 45 + _rng.nextInt(40);

    // Theme-aligned Electric Plasma colors (Strictly Black & Mid-Grey)
    final roll = _rng.nextDouble();
    final color = roll < 0.45
        ? const Color(0xFF0F172A) // Deep Obsidian Black
        : roll < 0.80
            ? const Color(0xFF334155) // Mid Slate Grey
            : const Color(0xFF64748B); // Cool Mid Grey

    final strokeWidth = 1.0 + _rng.nextDouble() * 1.2;

    arcs.add(_LightningArc(
      points: points,
      branches: branches,
      color: color,
      strokeWidth: strokeWidth,
      growFrames: growFrames,
      holdFrames: holdFrames,
      decayFrames: decayFrames,
    ));
  }

  void update() {
    // Advance lifecycle of active arcs
    for (int i = arcs.length - 1; i >= 0; i--) {
      arcs[i].life++;
      if (arcs[i].life >= arcs[i].totalFrames) {
        arcs.removeAt(i);
        // When the arc finishes completely, schedule the delay for the NEXT single arc
        _lastSpawnTime = DateTime.now();
        _nextDelayMs = 1800 + _rng.nextInt(4500); // 1.8s to 6.3s pause between solitary strikes
      }
    }

    // STRICTLY ONE AT A TIME: Only spawn if no arcs are currently active on screen
    if (arcs.isEmpty) {
      final now = DateTime.now();
      if (now.difference(_lastSpawnTime).inMilliseconds > _nextDelayMs) {
        _spawnArc();
        _lastSpawnTime = now;
      }
    }
  }
}

// ── Realistic Lightning Custom Painter with Plasma Glow ──────────────────────
class _RealisticLightningPainter extends CustomPainter {
  final List<_LightningArc> arcs;

  _RealisticLightningPainter({required this.arcs});

  void _drawPolyline(
    Canvas canvas,
    List<Offset> points,
    double visibleFraction,
    double alpha,
    Color color,
    double width,
  ) {
    if (points.length < 2 || alpha <= 0.005) return;

    final total = points.length - 1;
    final visibleCount = (visibleFraction * total).ceil().clamp(1, total);
    final pts = points.sublist(0, visibleCount + 1);

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    // 1. Plasma Outer Glow Pass
    final glowPaint = Paint()
      ..color = color.withValues(alpha: (alpha * 0.22).clamp(0.0, 1.0))
      ..strokeWidth = width * 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawPath(path, glowPaint);

    // 2. Bright Core Discharge Pass
    final corePaint = Paint()
      ..color = color.withValues(alpha: (alpha * 0.85).clamp(0.0, 1.0))
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, corePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Crisp Engineering Nodal Grid
    final gridDotPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    const spacing = 36.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, gridDotPaint);
      }
    }

    // 2. Realistic Electric Lightning Arcs
    for (final arc in arcs) {
      final life = arc.life;
      final growFrames = arc.growFrames;
      final holdFrames = arc.holdFrames;
      final decayFrames = arc.decayFrames;

      double visibleFraction = 1.0;
      double alpha = 1.0;

      if (life <= growFrames) {
        // GROW: Arc shoots forward with quadratic ease-out
        final t = life / growFrames;
        visibleFraction = 1.0 - math.pow(1.0 - t, 2.5);
        alpha = t;
      } else if (life <= growFrames + holdFrames) {
        // HOLD: Peak intensity
        visibleFraction = 1.0;
        alpha = 1.0;
      } else {
        // DECAY: Plasma dimming curve
        final t = (life - growFrames - holdFrames) / decayFrames;
        visibleFraction = 1.0;
        alpha = math.pow((1.0 - t).clamp(0.0, 1.0), 2.2).toDouble();
      }

      alpha = alpha.clamp(0.0, 1.0) * 0.85;

      if (alpha > 0.005) {
        _drawPolyline(canvas, arc.points, visibleFraction, alpha, arc.color, arc.strokeWidth);

        // Render branched lightning
        for (final branch in arc.branches) {
          if (visibleFraction >= branch.startFraction) {
            final bFrac = visibleFraction >= 1.0
                ? 1.0
                : (visibleFraction - branch.startFraction) / (1.0 - branch.startFraction);
            _drawPolyline(
              canvas,
              branch.points,
              bFrac.clamp(0.0, 1.0),
              alpha * 0.65,
              arc.color,
              arc.strokeWidth * 0.7,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticLightningPainter oldDelegate) => true;
}
