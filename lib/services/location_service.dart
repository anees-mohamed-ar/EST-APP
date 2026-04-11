import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc_pkg;
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  final _statusController = StreamController<bool>.broadcast();

  Stream<bool> get onServiceStatusChanged => _statusController.stream;

  void init() {
    _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
      status,
    ) {
      final enabled = status == ServiceStatus.enabled;
      debugPrint(
        '📍 Location Service Status: ${enabled ? "ENABLED" : "DISABLED"}',
      );
      _statusController.add(enabled);
    });
  }

  Future<bool> isLocationEnabled() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 Initial Location Check: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('❌ Error checking location service: $e');
      return false;
    }
  }

  /// Triggers the system's "Turn on location" popup without leaving the app.
  /// Note: Only works effectively on Android.
  Future<bool> requestService() async {
    try {
      debugPrint('📍 Requesting Location Service (System Popup)...');
      final location = loc_pkg.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }
      debugPrint('📍 Location Service Request Result: $serviceEnabled');
      return serviceEnabled;
    } catch (e) {
      debugPrint('❌ Error requesting location service: $e');
      // If popup fails, we try to open settings but return false
      // so the UI doesn't unlock prematurely.
      await openSettings();
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      debugPrint('📍 Opening Location Settings...');
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('❌ Error opening location settings: $e');
      return false;
    }
  }

  void dispose() {
    _serviceStatusSubscription?.cancel();
    _statusController.close();
  }
}
