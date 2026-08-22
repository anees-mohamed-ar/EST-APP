import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../constants/app_config.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  /// Tracks whether we are currently waiting for the user to return
  /// from the system Settings screen (after tapping "Turn On").
  bool _waitingForLocationSettings = false;

  late AnimationController _animCtrl;
  late AnimationController _electricCtrl;
  late AnimationController _fillCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _fillAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _electricCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Fill animation that reveals/fills the logo from the bottom-up or center as pulses arrive
    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );

    _fillAnim = CurvedAnimation(
      parent: _fillCtrl,
      curve: Curves.easeInOutCubic,
    );

    _animCtrl.forward();
    // Start filling the logo after the first wave of pulses reaches the center
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fillCtrl.forward();
    });

    _checkRequirements();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    _electricCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  /// Called whenever the app lifecycle state changes.
  /// When the user comes back from Settings, the state becomes [resumed].
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForLocationSettings) {
      _waitingForLocationSettings = false;
      // Give the OS a moment to restore network connectivity before checking.
      Future.delayed(const Duration(milliseconds: 800), _checkRequirements);
    }
  }

  /// Checks for a real internet connection with up to [maxRetries] attempts,
  /// waiting [retryDelay] between each try. This prevents false negatives
  /// right after returning from the system Settings screen, where Android
  /// needs a brief moment to re-establish the network stack.
  Future<bool> _hasRealInternetConnection({
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final List<ConnectivityResult> result = await Connectivity()
          .checkConnectivity();

      bool connected =
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      // Fallback for older plugin versions that return a single enum value
      if (result is ConnectivityResult) {
        connected = (result as ConnectivityResult) != ConnectivityResult.none;
      }

      if (connected) return true;

      // Not connected yet — wait before trying again (unless last attempt)
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }
    return false;
  }

  Future<void> _checkRequirements() async {
    // 1. Check Internet — retry up to 3× to avoid false negatives after
    //    returning from the Location Settings screen.
    final bool hasConnection = await _hasRealInternetConnection();

    if (!hasConnection) {
      _showErrorDialog(
        title: 'No Internet Connection',
        message: 'Please turn on Mobile Data or Wi-Fi to use the app.',
        onRetry: _checkRequirements,
      );
      return;
    }

    // 1b. Check App Version & Server Reachability
    try {
      final versionData = await ApiService.checkVersion(AppConfig.appVersion);
      if (versionData['allowed'] == false) {
        final bool isUnreachable = versionData['unreachable'] == true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isUnreachable) {
            _showErrorDialog(
              title: 'Unable to Reach Server',
              message: versionData['message'] ?? 'Cannot connect to the server. Please check your network or server status and try again.',
              onRetry: _checkRequirements,
            );
          } else {
            _showUpdateDialog(versionData['message'] ?? 'You are using an older version of the app. Please update to continue.');
          }
        });
        return;
      }
    } catch (e) {
      print('⚠️ Version check error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(
          title: 'Unable to Reach Server',
          message: 'Unable to connect to the server ($e). Please verify your connection and try again.',
          onRetry: _checkRequirements,
        );
      });
      return;
    }

    // 2. Check Location Services
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      return;
    }

    // 3. Routing — delay to allow the electric circuit charging and logo fill animation to complete smoothly
    await Future.delayed(const Duration(milliseconds: 3000));

    final storage = GetStorage();
    final userData = storage.read('user');
    if (userData != null) {
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/login');
    }
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Location Services Disabled',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please turn on your GPS / Location Services to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkRequirements();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              bool enabled = await Geolocator.isLocationServiceEnabled();
              if (enabled) {
                Navigator.pop(context);
                _checkRequirements();
              } else {
                // 📍 Trigger the system "Turn on Location" popup (Native)
                bool actuallyTurnedOn = await LocationService().requestService();
                
                if (actuallyTurnedOn) {
                  Navigator.pop(context);
                  _checkRequirements();
                } else {
                  // Fallback: If they cancelled or the popup didn't work,
                  // we wait for them to come back from manual settings or try again.
                  _waitingForLocationSettings = true;
                }
              }
            },
            child: const Text('RETRY / TURN ON'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text(
            '⚠️ Update Required',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are using a  Old version',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text(
                'Contact Your Admin For new App',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      body: Stack(
        children: [
          // ── Subtle Electric Circuit Background ─────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _electricCtrl,
              builder: (context, _) => CustomPaint(
                painter: _ElectricCircuitPainter(
                  progress: _electricCtrl.value,
                ),
              ),
            ),
          ),

          // ── Foreground Brand Content ──────────────────────────────────
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Brand logo with electric charging and fill reveal (sitting right at circuit focus)
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_electricCtrl, _fillAnim]),
                        builder: (context, _) {
                          final fillProgress = _fillAnim.value;
                          final pulseGlow = (math.sin(_electricCtrl.value * math.pi * 2) * 0.5 + 0.5) * fillProgress;

                          return Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                // Base elevation shadow
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                                // Charcoal electric energy charging glow (pulses as it fills)
                                BoxShadow(
                                  color: const Color(0xFF111111).withOpacity(0.12 * pulseGlow),
                                  blurRadius: 20 * pulseGlow,
                                  spreadRadius: 4 * pulseGlow,
                                ),
                              ],
                              border: Border.all(
                                color: Color.lerp(
                                  const Color(0xFFE5E7EB),
                                  const Color(0xFF111111),
                                  0.35 * fillProgress,
                                )!,
                                width: 1.2 + (0.6 * pulseGlow),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background subtle wireframe watermark
                                  Opacity(
                                    opacity: 0.12,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Image.asset(
                                        'assets/images/me-logo-clean.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  // Electric fill layer: reveals from bottom to top as pulses flow in
                                  ClipRect(
                                    clipper: _VerticalFillClipper(progress: fillProgress),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Image.asset(
                                        'assets/images/me-logo-clean.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  // Moving electric energy charge line at the fill frontier
                                  if (fillProgress > 0.02 && fillProgress < 0.98)
                                    Positioned(
                                      bottom: 94 * fillProgress - 1,
                                      left: 10,
                                      right: 10,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              const Color(0xFF111111).withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2C2C2C).withOpacity(0.6),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: const [
                        Text(
                          'MEPL-Track',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'EMPLOYEE SHIFT MANAGEMENT',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),

                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkTrialPeriod() async {
    // Logic removed - handled by version check now
  }
}

class TrialExpiredScreen extends StatelessWidget {
  const TrialExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.lock, size: 40, color: Colors.red),
                  ),
                  const SizedBox(height: 32),

                  // Expired message
                  const Text(
                    'Trial Period Expired',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Your trial period has expired on April 30, 2026.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Contact information
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Contact iMatrix Technologies Pvt Ltd',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '📞 +91-9500625633',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.email, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '📧 development@imatrixtechnologies.com',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '🌐 www.imatrixtechnologies.com/',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'To access the full version of the app,\nplease contact us for licensing information.',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App info
                  Text(
                    'MEPL-Track v1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'iMatrix Technologies Pvt Ltd © ${DateTime.now().year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Authentic PCB Circuit Board & Electric Current Custom Painter ──────────
class _ElectricCircuitPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 animation loop

  _ElectricCircuitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    // Exactly at center Y of the screen
    final cy = h / 2 - 80;
    const logoR = 47.0; // Perimeter radius of the logo box

    // ── Paints ─────────────────────────────────────────────────────────────
    // Primary PCB copper traces (clean, sharp lines)
    final pcbMainPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.08)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Secondary fine bus traces
    final pcbFinePaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.04)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Via copper pad rings (donut pads)
    final viaRingPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final viaHolePaint = Paint()
      ..color = const Color(0xFFFAFAFB)
      ..style = PaintingStyle.fill;

    final viaDotPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.14)
      ..style = PaintingStyle.fill;

    // Animated Electric Current Paints (Charcoal #111111)
    final pulseGlowPaint = Paint()
      ..color = const Color(0xFF111111).withOpacity(0.18)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pulseCorePaint = Paint()
      ..color = const Color(0xFF111111).withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sparkHeadPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;

    // ── 1. Realistic Multi-Branch PCB Traces (45° chamfered routing) ─────────
    final List<Path> mainTraces = [
      // Track 1: Top-Left Header Bus -> Inward
      Path()
        ..moveTo(w * 0.05, h * 0.06)
        ..lineTo(w * 0.22, h * 0.06)
        ..lineTo(w * 0.36, cy - 130)
        ..lineTo(w * 0.36, cy - 80)
        ..lineTo(cx - 28, cy - logoR),

      // Track 2: Top-Left Secondary
      Path()
        ..moveTo(w * 0.12, 0)
        ..lineTo(w * 0.12, h * 0.10)
        ..lineTo(w * 0.26, cy - 110)
        ..lineTo(cx - 10, cy - logoR),

      // Track 3: Top Direct Power Rail
      Path()
        ..moveTo(cx, 0)
        ..lineTo(cx, cy - 120)
        ..lineTo(cx + 8, cy - 100)
        ..lineTo(cx + 8, cy - logoR),

      // Track 4: Top-Right High-Speed Data Track
      Path()
        ..moveTo(w * 0.95, h * 0.06)
        ..lineTo(w * 0.78, h * 0.06)
        ..lineTo(w * 0.64, cy - 130)
        ..lineTo(w * 0.64, cy - 80)
        ..lineTo(cx + 28, cy - logoR),

      // Track 5: Top-Right Secondary
      Path()
        ..moveTo(w * 0.88, 0)
        ..lineTo(w * 0.88, h * 0.10)
        ..lineTo(w * 0.74, cy - 110)
        ..lineTo(cx + 10, cy - logoR),

      // Track 6: West Lateral Infeed
      Path()
        ..moveTo(0, cy - 45)
        ..lineTo(w * 0.18, cy - 45)
        ..lineTo(w * 0.28, cy - 18)
        ..lineTo(cx - logoR, cy - 18),

      // Track 7: West Dual Parallel Infeed
      Path()
        ..moveTo(0, cy + 30)
        ..lineTo(w * 0.14, cy + 30)
        ..lineTo(w * 0.26, cy + 18)
        ..lineTo(cx - logoR, cy + 18),

      // Track 8: East Lateral Infeed
      Path()
        ..moveTo(w, cy - 45)
        ..lineTo(w * 0.82, cy - 45)
        ..lineTo(w * 0.72, cy - 18)
        ..lineTo(cx + logoR, cy - 18),

      // Track 9: East Dual Parallel Infeed
      Path()
        ..moveTo(w, cy + 30)
        ..lineTo(w * 0.86, cy + 30)
        ..lineTo(w * 0.74, cy + 18)
        ..lineTo(cx + logoR, cy + 18),

      // Track 10: South-West Ground Rail
      Path()
        ..moveTo(w * 0.06, h * 0.94)
        ..lineTo(w * 0.24, h * 0.94)
        ..lineTo(w * 0.38, cy + 120)
        ..lineTo(w * 0.38, cy + 65)
        ..lineTo(cx - 24, cy + logoR - 22),

      // Track 11: South Direct Bus
      Path()
        ..moveTo(cx - 6, h)
        ..lineTo(cx - 6, cy + 110)
        ..lineTo(cx - 6, cy + logoR - 22),

      // Track 12: South-East Power Bus
      Path()
        ..moveTo(w * 0.94, h * 0.94)
        ..lineTo(w * 0.76, h * 0.94)
        ..lineTo(w * 0.62, cy + 120)
        ..lineTo(w * 0.62, cy + 65)
        ..lineTo(cx + 24, cy + logoR - 22),
    ];

    // Secondary decorative PCB bus lines (for realistic circuit density)
    final List<Path> decorTraces = [
      Path()..moveTo(w * 0.05, h * 0.09)..lineTo(w * 0.20, h * 0.09)..lineTo(w * 0.30, cy - 140),
      Path()..moveTo(w * 0.95, h * 0.09)..lineTo(w * 0.80, h * 0.09)..lineTo(w * 0.70, cy - 140),
      Path()..moveTo(0, cy - 65)..lineTo(w * 0.12, cy - 65)..lineTo(w * 0.20, cy - 85),
      Path()..moveTo(w, cy - 65)..lineTo(w * 0.88, cy - 65)..lineTo(w * 0.80, cy - 85),
      Path()..moveTo(0, cy + 50)..lineTo(w * 0.10, cy + 50)..lineTo(w * 0.18, cy + 75),
      Path()..moveTo(w, cy + 50)..lineTo(w * 0.90, cy + 50)..lineTo(w * 0.82, cy + 75),
      Path()..moveTo(w * 0.06, h * 0.91)..lineTo(w * 0.18, h * 0.91)..lineTo(w * 0.28, cy + 140),
      Path()..moveTo(w * 0.94, h * 0.91)..lineTo(w * 0.82, h * 0.91)..lineTo(w * 0.72, cy + 140),
    ];

    // Draw static decorative secondary traces
    for (final path in decorTraces) {
      canvas.drawPath(path, pcbFinePaint);
    }

    // Draw static main copper circuit tracks
    for (final path in mainTraces) {
      canvas.drawPath(path, pcbMainPaint);
    }

    // ── 2. Draw Realistic Solder Pads & Vias at Junctions ──────────────────
    final List<Offset> vias = [
      Offset(w * 0.05, h * 0.06),
      Offset(w * 0.22, h * 0.06),
      Offset(w * 0.36, cy - 130),
      Offset(w * 0.12, h * 0.10),
      Offset(w * 0.26, cy - 110),
      Offset(cx, cy - 120),
      Offset(w * 0.95, h * 0.06),
      Offset(w * 0.78, h * 0.06),
      Offset(w * 0.64, cy - 130),
      Offset(w * 0.88, h * 0.10),
      Offset(w * 0.74, cy - 110),
      Offset(w * 0.18, cy - 45),
      Offset(w * 0.28, cy - 18),
      Offset(w * 0.14, cy + 30),
      Offset(w * 0.26, cy + 18),
      Offset(w * 0.82, cy - 45),
      Offset(w * 0.72, cy - 18),
      Offset(w * 0.86, cy + 30),
      Offset(w * 0.74, cy + 18),
      Offset(w * 0.06, h * 0.94),
      Offset(w * 0.24, h * 0.94),
      Offset(w * 0.38, cy + 120),
      Offset(cx - 6, cy + 110),
      Offset(w * 0.94, h * 0.94),
      Offset(w * 0.76, h * 0.94),
      Offset(w * 0.62, cy + 120),
      // Terminal endpoints inside logo
      Offset(cx - 28, cy - logoR),
      Offset(cx + 28, cy - logoR),
      Offset(cx - logoR, cy - 18),
      Offset(cx + logoR, cy - 18),
      Offset(cx - logoR, cy + 18),
      Offset(cx + logoR, cy + 18),
      Offset(cx - 24, cy + logoR - 22),
      Offset(cx + 24, cy + logoR - 22),
    ];

    for (final via in vias) {
      // Outer copper ring
      canvas.drawCircle(via, 3.2, viaRingPaint);
      // Center isolation hole
      canvas.drawCircle(via, 1.8, viaHolePaint);
      // Center connection dot
      canvas.drawCircle(via, 1.2, viaDotPaint);
    }

    // ── 3. Draw High-Performance Travelling Electric Currents ─────────────
    for (int i = 0; i < mainTraces.length; i++) {
      final path = mainTraces[i];
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) continue;

      final metric = metrics.first;
      final totalLen = metric.length;
      if (totalLen <= 0) continue;

      // Staggered timing across the 12 tracks
      final offsetPct = (progress + (i * 0.11)) % 1.0;
      final sparkCenter = totalLen * offsetPct;
      final sparkLength = 36.0;

      final start = math.max(0.0, sparkCenter - sparkLength / 2);
      final end = math.min(totalLen, sparkCenter + sparkLength / 2);

      if (end > start) {
        final extracted = metric.extractPath(start, end);
        // Soft aura glow
        canvas.drawPath(extracted, pulseGlowPaint);
        // High-definition charcoal current core
        canvas.drawPath(extracted, pulseCorePaint);

        // Leading electric head spark
        final tangent = metric.getTangentForOffset(sparkCenter);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.8, sparkHeadPaint);
          canvas.drawCircle(tangent.position, 1.2, viaHolePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricCircuitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom clipper that reveals content from bottom to top as energy fills
class _VerticalFillClipper extends CustomClipper<Rect> {
  final double progress; // 0.0 -> 1.0

  _VerticalFillClipper({required this.progress});

  @override
  Rect getClip(Size size) {
    final top = size.height * (1.0 - progress.clamp(0.0, 1.0));
    return Rect.fromLTRB(0, top, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _VerticalFillClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
