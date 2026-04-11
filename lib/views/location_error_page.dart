import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'dart:async';

class LocationErrorPage extends StatefulWidget {
  final VoidCallback onRetry;

  const LocationErrorPage({Key? key, required this.onRetry}) : super(key: key);

  @override
  _LocationErrorPageState createState() => _LocationErrorPageState();
}

class _LocationErrorPageState extends State<LocationErrorPage> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Periodically check if location was enabled to auto-dismiss if possible
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled && mounted) {
        timer.cancel();
        widget.onRetry();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Explicitly prevent back navigation
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Large prominent icon
                Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 96,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Location is Required',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check-in and check-out actions are locked until your device location (GPS) is enabled.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'We need to verify your presence at the assigned work site for accurate attendance tracking.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                // Action Buttons
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await LocationService().requestService();
                          final actuallyEnabled =
                              await Geolocator.isLocationServiceEnabled();
                          if (actuallyEnabled && mounted) {
                            widget.onRetry();
                          }
                        },
                        icon: const Icon(Icons.settings_suggest_rounded),
                        label: const Text(
                          'TURN ON GPS',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'I HAVE ENABLED IT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
