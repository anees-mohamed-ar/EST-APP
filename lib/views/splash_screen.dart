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
    with WidgetsBindingObserver {
  /// Tracks whether we are currently waiting for the user to return
  /// from the system Settings screen (after tapping "Turn On").
  bool _waitingForLocationSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkRequirements();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // 1b. Check App Version
    try {
      final versionData = await ApiService.checkVersion(AppConfig.appVersion);
      if (versionData['allowed'] == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUpdateDialog(versionData['message'] ?? 'Please update your app.');
        });
        return;
      }
    } catch (e) {
      print('⚠️ Version check error: $e');
      // Continue anyway on error to prevent blocking the user
    }

    // 2. Check Location Services
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      return;
    }

    // 3. Routing — short delay for a smooth splash visual
    await Future.delayed(const Duration(milliseconds: 800));


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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Brand logo — matches HomeScreen app bar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF000000), Color(0xFF1F2937)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
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
            const SizedBox(height: 24),
            const Text(
              'MEPL-Track',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'EMPLOYEE SHIFT MANAGEMENT',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
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
                    '© 2026 iMatrix Technologies Pvt Ltd',
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
