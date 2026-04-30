import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'odometer_camera_page.dart';
import 'vehicle_history_page.dart';
import '../services/location_service.dart';
import '../widgets/swipe_to_confirm.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _bg     = Color(0xFFF4F5F7);
const _white  = Color(0xFFFFFFFF);
const _black  = Color(0xFF0A0A0A);
const _grey   = Color(0xFF6B7280);
const _lgrey  = Color(0xFFE5E7EB);
const _xlGrey = Color(0xFFF3F4F6);
const _green  = Color(0xFF16A34A);
const _red    = Color(0xFFDC2626);
const _amber  = Color(0xFFD97706);
const _blue   = Color(0xFF2563EB);

// ─── Shared widget helpers (top-level so all classes can use them) ─────────────

Widget _odoField({
  required TextEditingController controller,
  required String hint,
  required bool enabled,
  bool readOnly = false,
  bool hasError = false,
  bool isLocked = false,
  VoidCallback? onTap,
}) =>
    TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly || isLocked,
      onTap: onTap,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: _black, letterSpacing: -0.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _grey.withValues(alpha: 0.5),
          fontSize: hint.contains('first') || hint.contains('last') ? 14 : 20,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: isLocked ? const Icon(Icons.lock_rounded, color: _amber, size: 18) : null,
        filled: true,
        fillColor: isLocked ? _amber.withOpacity(0.04) : (hasError ? _red.withOpacity(0.05) : (enabled ? _xlGrey : const Color(0xFFF9F9F9))),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isLocked ? _amber : (hasError ? _red : _black), width: 1.5)),
        suffixText: 'km',
        suffixStyle:
            const TextStyle(color: _grey, fontSize: 14, fontWeight: FontWeight.w600),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );

Widget _locField({
  required TextEditingController controller,
  required String hint,
  bool hasError = false,
  bool isLocked = false,
  VoidCallback? onTap,
}) =>
    TextField(
      controller: controller,
      readOnly: isLocked,
      onTap: onTap,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _grey.withValues(alpha: 0.5), fontSize: 16),
        prefixIcon: isLocked ? const Icon(Icons.lock_rounded, color: _amber, size: 16) : null,
        filled: true,
        fillColor: isLocked ? _amber.withOpacity(0.04) : (hasError ? _red.withOpacity(0.05) : _xlGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isLocked ? _amber : (hasError ? _red : _black), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );

Widget _numField({
  required TextEditingController controller,
  required String hint,
  required String suffix,
  bool hasError = false,
  bool isLocked = false,
  VoidCallback? onTap,
}) =>
    TextField(
      controller: controller,
      readOnly: isLocked,
      onTap: onTap,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _grey.withValues(alpha: 0.5), fontSize: 16),
        prefixIcon: isLocked ? const Icon(Icons.lock_rounded, color: _amber, size: 16) : null,
        filled: true,
        fillColor: isLocked ? _amber.withOpacity(0.04) : (hasError ? _red.withOpacity(0.05) : _xlGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isLocked ? const BorderSide(color: _amber, width: 1.5) : (hasError ? const BorderSide(color: _red, width: 1.5) : BorderSide.none)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isLocked ? _amber : (hasError ? _red : _black), width: 1.5)),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: _grey, fontSize: 14, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );

Widget _photoCapture({
  required File? photo,
  required VoidCallback onCapture,
  required VoidCallback onRetake,
  bool enabled = true,
  bool hasError = false,
  String captureHint = 'Tap to capture odometer photo',
}) {
  if (photo != null) {
    // ... (rest of photo logic same)
    return Stack(children: [
      GestureDetector(
        onTap: () => _showPreview(Get.context!, photo),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(photo,
              width: double.infinity, height: 150, fit: BoxFit.cover),
        ),
      ),
      Positioned(
        top: 8, right: 8,
        child: GestureDetector(
          onTap: onRetake,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                shape: BoxShape.circle),
            child: const Icon(Icons.refresh_rounded, color: _white, size: 17),
          ),
        ),
      ),
      Positioned(
        bottom: 8, left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _green.withOpacity(0.88),
              borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, color: _white, size: 13),
            SizedBox(width: 4),
            Text('Captured',
                style: TextStyle(
                    color: _white, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      Positioned(
        bottom: 8, right: 8,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
        ),
      ),
    ]);
  }
  return GestureDetector(
    onTap: enabled ? onCapture : () {
      Get.snackbar('Vehicle Required', 'Please select a vehicle before taking a photo',
          backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    },
    child: Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: hasError ? _red.withOpacity(0.05) : _xlGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasError ? _red : _lgrey, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07), blurRadius: 8)
              ],
            ),
            child: Icon(Icons.camera_alt_rounded, 
                color: hasError ? _red : (enabled ? _black : _grey), size: 22),
          ),
          const SizedBox(height: 9),
          Text(enabled ? captureHint : 'Select vehicle first',
              style: TextStyle(
                  color: hasError ? _red : _grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

Widget _buildUserFriendlyRetry(VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _red.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: _red, size: 26),
          ),
          const SizedBox(height: 12),
          const Text("Loading Problem",
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _black)),
          const SizedBox(height: 4),
          const Text("Please tap the button below to try again",
              style: TextStyle(color: _grey, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: _red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("TRY AGAIN",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showPreview(BuildContext context, File file) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}






// _bigButton kept for compatibility but no longer used for primary actions
Widget _bigButton({
  required String label,
  required IconData icon,
  required Color color,
  required bool loading,
  required VoidCallback onTap,
}) =>
    SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: _white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: _white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 21),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
      ),
    );

Widget _vCard({required Widget child, EdgeInsets? padding}) => Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lgrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );

// ─── Entry ────────────────────────────────────────────────────────────────────
class VehiclePage extends StatefulWidget {
  const VehiclePage({Key? key}) : super(key: key);
  @override
  _VehiclePageState createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage>
    with TickerProviderStateMixin {
  final storage = GetStorage();
  int _tab = 0; // 0=Dashboard  1=Vehicle  2=Fuel

  // shared
  bool _isLoading = true;
  Map<String, dynamic>? _dashData;
  Map<String, dynamic>? _activeTrip;
  List<dynamic> _vehicles = [];

  // trip form
  String? _selectedVehicleId;
  bool _lastOdoLoading = false;
  bool _lastOdoFailed  = false;
  String? _lastOdoHint;
  final _startOdoCtrl = TextEditingController();
  final _endOdoCtrl   = TextEditingController();
  final _startLocCtrl = TextEditingController();
  final _endLocCtrl   = TextEditingController();
  File? _startPhoto;
  File? _endPhoto;
  bool _startTripLoading = false;
  bool _endTripLoading   = false;

  // Photo Expiry Timer
  Timer? _photoExpiryTimer;
  int _photoSecondsLeft = 0;

  // Validation errors
  bool _errStartVeh = false, _errStartOdo = false, _errStartPhoto = false, _errStartLoc = false;
  bool _errStopOdo = false, _errStopPhoto = false, _errEndLoc = false;
  bool _errFuelVeh = false, _errFuelOdo = false, _errFuelLiters = false, _errFuelAmount = false, _errFuelPhoto = false;

  // fuel form
  String? _fuelVehicleId;
  final _fuelOdoCtrl = TextEditingController();
  final _litersCtrl  = TextEditingController();
  final _amountCtrl  = TextEditingController();
  bool _fuelLoading  = false;
  File? _fuelBillPhoto;

  Map<String, dynamic>? get _user => storage.read('user');

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<bool> _confirmPhotoDiscard(bool isStart) async {
    final photo = isStart ? _startPhoto : _endPhoto;
    if (photo == null) return true;

    final res = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _white,
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: _amber, size: 24),
          SizedBox(width: 10),
          Text('Unlock Field?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        content: Text(
          'Editing this field will discard your current ${isStart ? 'start' : 'stop'} odometer photo, as the watermark data will no longer match. \n\nDo you want to discard the photo and edit?',
          style: const TextStyle(fontSize: 14, color: _grey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: _grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Discard & Edit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      barrierDismissible: false,
    );

    if (res == true) {
      setState(() {
        if (isStart) {
          _startPhoto = null;
        } else {
          _endPhoto = null;
        }
        _cancelPhotoExpiryTimer();
      });
      return true;
    }
    return false;
  }
  Future<void> _confirmPhotoDiscardFuel() async {
    if (_fuelBillPhoto == null) return;

    final res = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _white,
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: _amber, size: 24),
          SizedBox(width: 10),
          Text('Unlock Field?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        content: const Text(
          'Editing this field will discard your current fuel bill photo evidence. \n\nDo you want to discard the photo and edit?',
          style: TextStyle(fontSize: 14, color: _grey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel', style: TextStyle(color: _grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Discard & Edit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      barrierDismissible: false,
    );

    if (res == true) {
      setState(() => _fuelBillPhoto = null);
    }
  }

  Future<void> _boot() async {
    setState(() => _isLoading = true);
    // Artificial delay to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    await Future.wait([_fetchDashboard(), _fetchVehicles()]);
    setState(() => _isLoading = false);
  }

  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchDashboard() async {
    try {
      final res = await http.get(Uri.parse(
          '${ApiService.baseUrl}/vehicles/dashboard?userId=${_user?['id']}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          _dashData   = data;
          _activeTrip = data['activeTrip'];
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchVehicles() async {
    try {
      final res =
          await http.get(Uri.parse('${ApiService.baseUrl}/vehicles'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            _vehicles = data['vehicles'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchLastOdometer(String vehicleId) async {
    setState(() {
      _lastOdoLoading = true;
      _lastOdoFailed  = false;
      _lastOdoHint    = null;
      _startOdoCtrl.clear();
    });
    try {
      final res = await http.get(Uri.parse(
          '${ApiService.baseUrl}/vehicles/$vehicleId/last-odometer'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final odo  = data['lastOdometer']?.toString();
        if (odo != null && odo.isNotEmpty) {
          setState(() {
            _lastOdoHint       = odo;
            _startOdoCtrl.text = odo;
          });
        }
      } else {
        setState(() => _lastOdoFailed = true);
      }
    } catch (_) {
      setState(() => _lastOdoFailed = true);
    }
    setState(() => _lastOdoLoading = false);
  }

  // ── Trip actions ───────────────────────────────────────────────────────────
  Future<void> _capturePhoto(bool isStart) async {
    // Dismiss keyboard/remove focus from input fields
    FocusScope.of(context).unfocus();

    // 📍 STRICT LOCATION CHECK before entry
    final pos = await _getPos();
    if (pos == null) return;

    // Determine vehicle name for watermark
    String? vName;
    if (isStart) {
      final v = _vehicles.firstWhereOrNull((v) => v['id'].toString() == _selectedVehicleId);
      vName = v?['name'];
    } else {
      vName = _activeTrip?['vehicle_name'];
    }

    // Determine location name for watermark
    final locName = (isStart ? _startLocCtrl.text : _endLocCtrl.text).trim();
    if (locName.isEmpty) {
      _snack('Please enter the ${isStart ? 'starting' : 'ending'} location name first.', err: true);
      return;
    }

    final File? file = await Get.to(
      () => OdometerCameraPage(
          title: isStart
              ? 'Capture Start Odometer'
              : 'Capture End Odometer',
          vehicleName: vName,
          extraDetails: {
            'ODO': '${(isStart ? _startOdoCtrl.text : _endOdoCtrl.text).trim()} km',
            'ROUTE': locName,
          }),
      transition: Transition.downToUp,
    );

    // Call unfocus again after returning to ensure no field regains focus
    FocusScope.of(context).unfocus();

    // ⚡ ADDED DELAY: Force another unfocus after a short delay
    // This helps if Flutter's internal state restoration re-focuses a field
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).unfocus();
    });

    if (file == null) return;
    setState(() {
      if (isStart) {
        _startPhoto = file;
        _errStartPhoto = false;
      } else {
        _endPhoto = file;
        _errStopPhoto = false;
      }
    });

    _startPhotoExpiryTimer();
  }

  void _startPhotoExpiryTimer() {
    _photoExpiryTimer?.cancel();
    setState(() => _photoSecondsLeft = 60);

    _photoExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_photoSecondsLeft > 0) {
        setState(() => _photoSecondsLeft--);
      } else {
        timer.cancel();
        _handlePhotoExpiry();
      }
    });
  }

  void _handlePhotoExpiry() {
    if (_startPhoto == null && _endPhoto == null) return;
    
    setState(() {
      _startPhoto = null;
      _endPhoto = null;
      _photoSecondsLeft = 0;
    });
    
    _snack('Photo expired (60s limit). Please retake.', err: true);
  }

  void _cancelPhotoExpiryTimer() {
    _photoExpiryTimer?.cancel();
    _photoExpiryTimer = null;
    setState(() => _photoSecondsLeft = 0);
  }

  Future<Position?> _getPos() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 📍 Trigger the system "Turn on Location" popup (Native)
      serviceEnabled = await LocationService().requestService();
      if (!serviceEnabled) {
        _snack('Location services are disabled. Please enable GPS to proceed.', err: true);
        return null;
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _snack('Location permission denied. This action requires GPS tracking.', err: true);
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _snack('Location permissions are permanently denied. Please enable them in settings.', err: true);
      return null;
    }

    try {
      // 10 second timeout for a high accuracy fix
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _snack('Location error: Unable to get a GPS lock. Please move to an open area.', err: true);
      return null;
    }
  }

  Future<void> _startTrip() async {
    setState(() {
      _errStartVeh = false;
      _errStartOdo = false;
      _errStartPhoto = false;
      _errStartLoc = false;
    });

    if (_lastOdoFailed) {
      _snack('Odometer fetch failed. Please retry.', err: true);
      return;
    }
    if (_selectedVehicleId == null) {
      setState(() => _errStartVeh = true);
      _snack('Select a vehicle first', err: true); return;
    }
    if (_startOdoCtrl.text.trim().isEmpty) {
      setState(() => _errStartOdo = true);
      _snack('Enter start odometer reading', err: true); return;
    }
    if (_startLocCtrl.text.trim().isEmpty) {
      setState(() => _errStartLoc = true);
      _snack('Enter starting location name', err: true); return;
    }
    if (_startPhoto == null) {
      setState(() => _errStartPhoto = true);
      _snack('Capture odometer photo first', err: true); return;
    }
    // ... rest of start trip
    setState(() => _startTripLoading = true);
    try {
      final pos = await _getPos();
      if (pos == null) {
        setState(() => _startTripLoading = false);
        return;
      }
      
      final req = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/vehicles/start-trip'));
      req.fields['userId']        = _user?['id'].toString() ?? '';
      req.fields['vehicleId']     = _selectedVehicleId!;
      req.fields['startOdometer'] = _startOdoCtrl.text.trim();
      req.fields['startLoc']      = _startLocCtrl.text.trim();
      req.fields['lat'] = pos.latitude.toString();
      req.fields['lng'] = pos.longitude.toString();
      req.files.add(await http.MultipartFile.fromPath('photo', _startPhoto!.path));
      final resp = await req.send();
      if (resp.statusCode == 200) {
        _snack('Trip started!');
        _cancelPhotoExpiryTimer();
        _startOdoCtrl.clear();
        _startLocCtrl.clear();
        _startPhoto = null; _selectedVehicleId = null; _lastOdoHint = null;
        await _boot(); _setTab(0);
      } else {
        _snack('Failed to start trip', err: true);
      }
    } catch (_) { _snack('Network error', err: true); }
    finally { setState(() => _startTripLoading = false); }
  }

  Future<void> _endTrip() async {
    setState(() {
      _errStopOdo = false; _errStopPhoto = false; _errEndLoc = false;
    });

    if (_endOdoCtrl.text.trim().isEmpty) {
      setState(() => _errStopOdo = true);
      _snack('Enter end odometer reading', err: true); return;
    }
    if (_endLocCtrl.text.trim().isEmpty) {
      setState(() => _errEndLoc = true);
      _snack('Enter ending location name', err: true); return;
    }
    if (_endPhoto == null) {
      setState(() => _errStopPhoto = true);
      _snack('Capture odometer photo first', err: true); return;
    }
    final startOdo = double.tryParse(_activeTrip?['start_odometer'].toString() ?? '0') ?? 0;
    final endOdo = double.tryParse(_endOdoCtrl.text.trim()) ?? 0;
    final diff = endOdo - startOdo;

    if (diff < 0) {
      setState(() => _errStopOdo = true);
      _snack('End reading must be ≥ start reading ($startOdo km)', err: true); return;
    }
    if (diff > 500) {
      setState(() => _errStopOdo = true);
      _snack('Max trip distance is 500 km (Current: ${diff.toStringAsFixed(1)} km)', err: true); return;
    }
    final dist = diff.toStringAsFixed(2);

    setState(() => _endTripLoading = true);
    // ... rest of end trip
    try {
      final pos = await _getPos();
      if (pos == null) {
        setState(() => _endTripLoading = false);
        return;
      }

      final req = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/vehicles/end-trip'));
      req.fields['tripId']      = _activeTrip!['id'].toString();
      req.fields['endOdometer'] = _endOdoCtrl.text.trim();
      req.fields['distance']    = dist;
      req.fields['endLoc']      = _endLocCtrl.text.trim();
      req.fields['lat'] = pos.latitude.toString();
      req.fields['lng'] = pos.longitude.toString();
      req.files.add(await http.MultipartFile.fromPath('photo', _endPhoto!.path));
      final resp = await req.send();
      if (resp.statusCode == 200) {
        _snack('Trip ended! +$dist km');
        _cancelPhotoExpiryTimer();
        _endOdoCtrl.clear();
        _endLocCtrl.clear();
        _endPhoto = null;
        await _boot(); _setTab(0);
      } else { _snack('Failed to end trip', err: true); }
    } catch (_) { _snack('Network error', err: true); }
    finally { setState(() => _endTripLoading = false); }
  }

  Future<void> _captureFuelBill() async {
    // 📍 STRICT LOCATION CHECK before entry
    final pos = await _getPos();
    if (pos == null) return;

    final vId = _activeTrip != null ? _activeTrip!['vehicle_id'].toString() : _fuelVehicleId;
    final v = _vehicles.firstWhereOrNull((v) => v['id'].toString() == vId);
    final vName = v?['name'];

    final File? file = await Get.to(
      () => OdometerCameraPage(
        title: 'Capture Fuel Bill', 
        vehicleName: vName,
        extraDetails: {
          'ODO': '${_fuelOdoCtrl.text.trim()} km',
          'LITERS': '${_litersCtrl.text.trim()} L',
          'AMOUNT': '₹${_amountCtrl.text.trim()}',
        },
      ),
      transition: Transition.downToUp,
    );
    if (file == null) return;
    setState(() => _fuelBillPhoto = file);
  }

  Future<void> _logFuel() async {
    setState(() {
      _errFuelVeh = false; _errFuelOdo = false; 
      _errFuelLiters = false; _errFuelAmount = false;
      _errFuelPhoto = false;
    });

    final vehicleId = _activeTrip != null
        ? _activeTrip!['vehicle_id'].toString()
        : _fuelVehicleId;
    if (vehicleId == null) { 
      setState(() => _errFuelVeh = true);
      _snack('Select a vehicle', err: true); return; 
    }
    if (_fuelOdoCtrl.text.trim().isEmpty) {
      setState(() => _errFuelOdo = true);
      _snack('Enter odometer reading', err: true); return;
    }
    if (_litersCtrl.text.trim().isEmpty) {
      setState(() => _errFuelLiters = true);
      _snack('Enter litres filled', err: true); return;
    }
    if (_amountCtrl.text.trim().isEmpty) {
      setState(() => _errFuelAmount = true);
      _snack('Enter amount paid', err: true); return;
    }
    if (_fuelBillPhoto == null) {
      setState(() => _errFuelPhoto = true);
      _snack('Capture fuel bill photo', err: true); return;
    }

    setState(() => _fuelLoading = true);
    try {
      final pos = await _getPos();
      if (pos == null) {
        setState(() => _fuelLoading = false);
        return;
      }

      // Use multipart so we can upload the optional bill photo
      final req = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/vehicles/fuel'));
      req.fields['userId']          = _user?['id'].toString() ?? '';
      req.fields['vehicleId']       = vehicleId;
      req.fields['odometerReading'] = _fuelOdoCtrl.text.trim();
      req.fields['litersFilled']    = _litersCtrl.text.trim();
      req.fields['amountPaid']      = _amountCtrl.text.trim();
      req.fields['lat'] = pos.latitude.toString();
      req.fields['lng'] = pos.longitude.toString();
      if (_fuelBillPhoto != null) {
        req.files.add(await http.MultipartFile.fromPath(
            'bill_photo', _fuelBillPhoto!.path));
      }
      final resp = await req.send();
      if (resp.statusCode == 200) {
        _snack('Fuel logged!');
        _fuelOdoCtrl.clear(); _litersCtrl.clear(); _amountCtrl.clear();
        _fuelBillPhoto = null;
        if (_activeTrip == null) _fuelVehicleId = null;
        await _boot(); _setTab(0);
      } else { _snack('Failed to log fuel', err: true); }
    } catch (_) { _snack('Network error', err: true); }
    finally { setState(() => _fuelLoading = false); }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setTab(int i) {
    setState(() => _tab = i);
    if (i == 1 || i == 2) _fetchVehicles();
  }

  Future<bool> _confirmVehicleChange(File? photo) async {
    if (photo == null) return true;
    // Allow sheet to finish popping
    await Future.delayed(const Duration(milliseconds: 100));
    
    final res = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _white,
        surfaceTintColor: _white,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 28),
          const SizedBox(width: 12),
          const Text('Action Warning', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        content: const Text(
          'Changing the vehicle will IMMEDIATELY DISCARD the photo you just captured. \n\nAre you sure you want to clear the photo and switch vehicles?',
          style: TextStyle(fontWeight: FontWeight.w500, color: _black),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep Photo', style: TextStyle(color: _grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Discard & Change', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      barrierDismissible: false,
    );
    return res ?? false;
  }

  void _snack(String msg, {bool err = false}) {
    Get.snackbar(
      err ? 'Error' : 'Done', msg,
      backgroundColor: err ? _red : _green,
      colorText: _white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _photoExpiryTimer?.cancel();
    _startOdoCtrl.dispose(); _endOdoCtrl.dispose();
    _startLocCtrl.dispose(); _endLocCtrl.dispose();
    _fuelOdoCtrl.dispose(); _litersCtrl.dispose(); _amountCtrl.dispose();
    super.dispose();
  }

  void _resetFuelBillPhoto() => setState(() => _fuelBillPhoto = null);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoading
                      ? const _VehicleLoadingSplash()
                      : IndexedStack(
                          index: _tab,
                          children: [
                            _DashboardTab(
                              dashData:    _dashData,
                              activeTrip:  _activeTrip,
                              onGoVehicle: () => _setTab(1),
                              onGoFuel:    () => _setTab(2),
                            ),
                            _VehicleTab(
                              activeTrip: _activeTrip,
                              vehicles: _vehicles,
                              selectedVehicleId: _selectedVehicleId,
                              lastOdoLoading: _lastOdoLoading,
                              lastOdoFailed: _lastOdoFailed,
                              lastOdoHint: _lastOdoHint,
                              startOdoCtrl: _startOdoCtrl,
                              endOdoCtrl: _endOdoCtrl,
                              startLocCtrl: _startLocCtrl,
                              endLocCtrl: _endLocCtrl,
                              startPhoto: _startPhoto,
                              endPhoto: _endPhoto,
                              startTripLoading: _startTripLoading,
                              endTripLoading: _endTripLoading,
                              errStartVeh: _errStartVeh,
                              errStartOdo: _errStartOdo,
                              errStartPhoto: _errStartPhoto,
                              errStopOdo: _errStopOdo,
                              errStopPhoto: _errStopPhoto,
                              errStartLoc: _errStartLoc,
                              errEndLoc: _errEndLoc,
                              onSelectVehicle: (id) async {
                                if (id == _selectedVehicleId) return;
                                if (await _confirmVehicleChange(_startPhoto)) {
                                  setState(() {
                                    _selectedVehicleId = id;
                                    _startPhoto = null;
                                    _cancelPhotoExpiryTimer();
                                    _errStartVeh = false;
                                  });
                                  if (id != null) _fetchLastOdometer(id);
                                }
                              },
                              onRetryOdo: () {
                                if (_selectedVehicleId != null) _fetchLastOdometer(_selectedVehicleId!);
                              },
                              onCaptureStart: () => _capturePhoto(true),
                              onRetakeStart: () => setState(() => _startPhoto = null),
                              onCaptureEnd: () => _capturePhoto(false),
                              onRetakeEnd: () => setState(() => _endPhoto = null),
                              onStartTrip: _startTrip,
                              onEndTrip: _endTrip,
                              photoSecondsLeft: _photoSecondsLeft,
                              onConfirmDiscard: _confirmPhotoDiscard,
                            ),
                            _FuelTab(
                              activeTrip: _activeTrip,
                              vehicles: _vehicles,
                              fuelVehicleId: _fuelVehicleId,
                              fuelOdoCtrl: _fuelOdoCtrl,
                              litersCtrl: _litersCtrl,
                              amountCtrl: _amountCtrl,
                              fuelLoading: _fuelLoading,
                              fuelBillPhoto: _fuelBillPhoto,
                              errFuelVeh: _errFuelVeh,
                              errFuelOdo: _errFuelOdo,
                              errFuelLiters: _errFuelLiters,
                              errFuelAmount: _errFuelAmount,
                              errFuelPhoto: _errFuelPhoto,
                              onSelectVehicle: (v) async {
                                if (v == _fuelVehicleId) return;
                                if (await _confirmVehicleChange(_fuelBillPhoto)) {
                                  setState(() {
                                    _fuelVehicleId = v;
                                    _fuelBillPhoto = null;
                                    _errFuelVeh = false;
                                  });
                                }
                              },
                              onLogFuel: _logFuel,
                              onCaptureBill: _captureFuelBill,
                              onRetakeBill: _resetFuelBillPhoto,
                              onConfirmDiscardFuel: _confirmPhotoDiscardFuel,
                            ),
                          ],
                        ),
                ),
              ],
            ),

            // ── Telegram-style floating dock ──────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 24, right: 24,
              child: _buildDock(),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final name = (_user?['full_name'] ??
            _user?['employee_name'] ??
            _user?['username'] ??
            'Driver')
        .toString()
        .split(' ')
        .first;
    const titles = ['Dashboard', 'Vehicle', 'Fuel Log'];

    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 20, right: 20,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: _xlGrey, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _black, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[_tab],
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _black,
                  letterSpacing: -0.5)),
          Text('Hello, $name!',
              style: const TextStyle(
                  fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _boot,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: _xlGrey, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.refresh_rounded, color: _black, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── High-Aesthetic Floating Dock ──────────────────────────────────────────
  Widget _buildDock() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              // Top gloss highlight
              Positioned(
                top: 0, left: 32, right: 32, child: Container(height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ]),
                )),
              ),

              // Animated highlight pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutQuart,
                top: 8,
                bottom: 8,
                left: _dockPillLeft(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutQuart,
                  width: _dockPillWidth(),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                ),
              ),

              // Navigation items
              Row(children: [
                _dockItem(0, Icons.dashboard_rounded,
                    Icons.dashboard_outlined, 'Dashboard'),
                _dockDivider(),
                _dockItem(1, Icons.directions_car_rounded,
                    Icons.directions_car_outlined, 'Trip', badge: _activeTrip != null),
                _dockDivider(),
                _dockItem(2, Icons.local_gas_station_rounded,
                    Icons.local_gas_station_outlined, 'Fuel'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  double _dockPillLeft() {
    const padding = 8.0;
    final width = (MediaQuery.of(context).size.width - 48); // margin aware
    final itemWidth = (width - 2) / 3;
    return padding + _tab * (itemWidth + 1.0);
  }

  double _dockPillWidth() {
    final width = (MediaQuery.of(context).size.width - 48);
    return (width - 2) / 3 - 16; 
  }

  Widget _dockItem(int index, IconData active, IconData inactive, String label,
      {bool badge = false}) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _setTab(index);
        },
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                isActive ? active : inactive,
                key: ValueKey(isActive),
                color: isActive ? _black : _grey,
                size: 24,
              ),
            ),
            if (badge)
              Positioned(
                top: -2, right: -4,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: _green, shape: BoxShape.circle),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? _black : _grey,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dockDivider() => Container(
    width: 1, height: 32,
    color: Colors.black.withValues(alpha: 0.05),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Live Trip Banner — animated active-trip card
// ══════════════════════════════════════════════════════════════════════════════
class _LiveTripBanner extends StatefulWidget {
  final Map<String, dynamic> activeTrip;
  final VoidCallback onTap;
  const _LiveTripBanner({required this.activeTrip, required this.onTap});
  @override
  State<_LiveTripBanner> createState() => _LiveTripBannerState();
}

class _LiveTripBannerState extends State<_LiveTripBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _dotCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _ringAnim;
  late Animation<double> _dotAnim;

  Duration _elapsed = Duration.zero;
  late final DateTime? _startTime;

  // ── Colors ───────────────────────────────────────────────────────────────
  static const _bg         = Color(0xFF111827); // Gray-900 — readable dark
  static const _surface    = Color(0xFF1F2937); // Gray-800 — subtle card lift
  static const _green      = Color(0xFF22C55E); // Green-500 — unmistakable LIVE
  static const _greenDim   = Color(0xFF16A34A); // Green-600 — depth gradient
  static const _textPrimary   = Color(0xFFF8FAFC); // Slate-50
  static const _textSecondary = Color(0xFF94A3B8); // Slate-400
  static const _textMuted     = Color(0xFF475569); // Slate-600

  @override
  void initState() {
    super.initState();
    final raw = widget.activeTrip['start_time']?.toString();
    _startTime = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;

    _elapsed = _computeElapsed();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _elapsed = _computeElapsed());
      return true;
    });

    // Dot blink — slow, calm rhythm
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));

    // Pulse ring — expands outward from dot, then fades
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _ringAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

    // Subtle background radial shift
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.06, end: 0.13)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOutSine));
  }

  Duration _computeElapsed() {
    if (_startTime == null) return Duration.zero;
    final d = DateTime.now().difference(_startTime!);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }

  String _fmtStart(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM, hh:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_dotAnim, _ringAnim, _pulseAnim]),
        builder: (_, __) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _surface, width: 1.5),
              // Soft green shadow — signals "active" at a glance
              boxShadow: [
                BoxShadow(
                  color: _green.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [

                // ── Subtle green radial glow (breathes slowly) ────────────
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.5, -0.3),
                        radius: 1.4,
                        colors: [
                          _green.withOpacity(_pulseAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Top row: icon + info + arrow ───────────────────
                      Row(children: [
                        _buildIconBox(),
                        const SizedBox(width: 14),
                        Expanded(child: _buildInfo()),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white24, size: 14),
                      ]),

                      // ── Divider ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Colors.white.withOpacity(0.07),
                          height: 1, thickness: 1),
                      ),

                      // ── Stats row ──────────────────────────────────────
                      _buildStatsRow(),

                      const SizedBox(height: 12),

                      // ── Progress bar (visual cue of active state) ──────
                      _buildProgressBar(),

                      const SizedBox(height: 8),

                      // ── Helper chip ────────────────────────────────────
                      _buildStatusChip(),
                    ],
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Icon box with pulse ring ─────────────────────────────────────────────
  Widget _buildIconBox() {
    return SizedBox(
      width: 52, height: 52,
      child: Stack(alignment: Alignment.center, children: [
        // Outer pulse ring — expands and fades out
        Opacity(
          opacity: (1 - _ringAnim.value).clamp(0, 1),
          child: Container(
            width: 52 + (_ringAnim.value * 12),
            height: 52 + (_ringAnim.value * 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _green.withOpacity(0.5 * (1 - _ringAnim.value)),
                width: 1.5,
              ),
            ),
          ),
        ),
        // Icon circle
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: _green.withOpacity(0.3), width: 1.5),
          ),
          child: const Icon(Icons.directions_car_rounded,
              color: Colors.white, size: 24),
        ),
        // Blinking live dot
        Positioned(
          bottom: 11, right: 11,
          child: Opacity(
            opacity: _dotAnim.value,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: _green, shape: BoxShape.circle),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Text info ────────────────────────────────────────────────────────────
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          // LIVE badge — green pill, impossible to miss
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _green.withOpacity(0.30)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Opacity(
                opacity: _dotAnim.value,
                child: Container(
                  width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: _green, shape: BoxShape.circle),
                ),
              ),
              const Text('LIVE',
                  style: TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ]),
          ),
          const Spacer(),
          // Elapsed timer — monospaced for stability
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _fmtElapsed(_elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          widget.activeTrip['vehicle_name'] ?? 'In Transit',
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.activeTrip['registration_number'] ?? '',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.activeTrip['start_loc'] != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'LIVE FROM: ${widget.activeTrip['start_loc'].toString().toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFF86EFAC),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(children: [
      _statItem(
        icon: Icons.speed_rounded,
        iconColor: _green,
        value: '${widget.activeTrip['start_odometer'] ?? "—"} km',
        label: 'Start odometer',
      ),
      const SizedBox(width: 20),
      _statItem(
        icon: Icons.access_time_filled_rounded,
        iconColor: _textMuted,
        value: _fmtStart(widget.activeTrip['start_time']?.toString()),
        label: 'Trip started',
      ),
    ]);
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: iconColor, size: 14),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }

  // ── Animated progress bar (breathing "active" signal) ────────────────────
  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: Colors.white.withOpacity(0.06),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.38, // e.g. derived from elapsed/expected duration
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_greenDim, _green],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── "Tap to track" chip ──────────────────────────────────────────────────
  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Trip in progress — tap to track',
        style: TextStyle(
          color: Color(0xFF86EFAC), // green-300
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 0 — Dashboard
// ══════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic>? dashData;
  final Map<String, dynamic>? activeTrip;
  final VoidCallback onGoVehicle;
  final VoidCallback onGoFuel;

  const _DashboardTab({
    required this.dashData,
    required this.activeTrip,
    required this.onGoVehicle,
    required this.onGoFuel,
  });

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM, hh:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final d = dashData;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Active trip banner
        if (activeTrip != null) ...[
          _LiveTripBanner(
            activeTrip: activeTrip!,
            onTap: onGoVehicle,
          ),
          const SizedBox(height: 20),
        ],

        // Stats
        const _SecHead('My Stats'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _StatCard(icon: Icons.speed_rounded,             iconColor: _blue,  label: 'Total Distance', value: '${d?['totalDistance'] ?? '0'} km'),
            _StatCard(icon: Icons.route_rounded,             iconColor: _green, label: 'Completed Trips', value: '${d?['totalTrips'] ?? 0}'),
            _StatCard(icon: Icons.local_gas_station_rounded, iconColor: _amber, label: 'Fuel Filled',      value: '${d?['totalLiters'] ?? '0'} L'),
            _StatCard(icon: Icons.currency_rupee_rounded,    iconColor: _red,   label: 'Fuel Spent',      value: '₹${d?['totalFuelSpend'] ?? '0'}'),
          ],
        ),
        const SizedBox(height: 24),

        // Quick actions
        const _SecHead('Quick Actions'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _ActionBtn(
              icon:  activeTrip != null ? Icons.stop_circle_rounded  : Icons.play_circle_rounded,
              label: activeTrip != null ? 'Stop Trip'                : 'Start Trip',
              sublabel: activeTrip != null ? 'End current trip'      : 'Track your journey',
              color: activeTrip != null ? _red                       : _green,
              onTap: onGoVehicle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionBtn(
              icon: Icons.local_gas_station_rounded,
              label: 'Log Fuel',
              sublabel: 'Record fuel refill',
              color: _amber,
              onTap: onGoFuel,
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // Recent trips
        if (d != null && (d['recentTrips'] as List).isNotEmpty) ...[
          _SecHeadAction(
            'Recent Trips',
            onViewAll: () => Get.to(
              () => const VehicleHistoryPage(initialTab: 0),
              transition: Transition.rightToLeft,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate((d['recentTrips'] as List).length, (i) {
            final trip = (d['recentTrips'] as List)[i];
            return GestureDetector(
              onTap: () => Get.to(
                () => const VehicleHistoryPage(initialTab: 0),
                transition: Transition.rightToLeft,
              ),
              child: _TripRow(trip: trip),
            );
          }),
          const SizedBox(height: 24),
        ],

        // Recent fuel
        if (d != null && (d['recentFuel'] as List).isNotEmpty) ...[
          _SecHeadAction(
            'Recent Fuel Logs',
            onViewAll: () => Get.to(
              () => const VehicleHistoryPage(initialTab: 1),
              transition: Transition.rightToLeft,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate((d['recentFuel'] as List).length, (i) {
            final fuel = (d['recentFuel'] as List)[i];
            return GestureDetector(
              onTap: () => Get.to(
                () => const VehicleHistoryPage(initialTab: 1),
                transition: Transition.rightToLeft,
              ),
              child: _FuelRow(fuel: fuel),
            );
          }),
        ],

        const SizedBox(height: 8),
      ]),
    );
  }
}

// Dashboard sub-widgets ──────────────────────────────────────────────────────
class _SecHead extends StatelessWidget {
  final String text;
  const _SecHead(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _black,
          letterSpacing: -0.2));
}

class _SecHeadAction extends StatelessWidget {
  final String text;
  final VoidCallback onViewAll;
  const _SecHeadAction(this.text, {required this.onViewAll});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _black,
                  letterSpacing: -0.2)),
          GestureDetector(
            onTap: onViewAll,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View All',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _blue)),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: _blue),
            ]),
          ),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _StatCard(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lgrey.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _black,
                  letterSpacing: -0.6)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: _grey.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1)),
        ]),
      );
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          final v = _pulseAnim.value;
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.color.withOpacity(0.3 + (v * 0.4)),
                width: 2 + (v * 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.1 + (v * 0.15)),
                  blurRadius: 20 + (v * 15),
                  spreadRadius: v * 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft breathing gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withOpacity(0.05 + (v * 0.05)),
                          Colors.transparent,
                        ],
                        radius: 1.5 + v * 0.5,
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        widget.icon,
                        size: 42 + (v * 3),
                        color: widget.color,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: widget.color,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.sublabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.color.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final dynamic trip;
  const _TripRow({required this.trip});
  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM').format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lgrey),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.route_rounded, color: _blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip['vehicle_name'] ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _black)),
              if (trip['start_loc'] != null || trip['end_loc'] != null)
                Text(
                  '${trip['start_loc'] ?? '?'} → ${trip['end_loc'] ?? '?'}',
                  style: TextStyle(fontSize: 10, color: _blue.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
                )
              else
                Text(trip['registration_number'] ?? '',
                    style: const TextStyle(fontSize: 11, color: _grey)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${trip['distance'] ?? '—'} km',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: _black, fontSize: 14)),
            Text(_fmt(trip['end_time']?.toString()),
                style: const TextStyle(fontSize: 11, color: _grey)),
          ]),
        ]),
      );
}

class _FuelRow extends StatelessWidget {
  final dynamic fuel;
  const _FuelRow({required this.fuel});
  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM').format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lgrey),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.local_gas_station_rounded,
                color: _amber, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fuel['vehicle_name'] ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _black)),
              Text(
                  '${fuel['liters_filled']} L  ·  ${fuel['odometer_reading']} km',
                  style: const TextStyle(fontSize: 11, color: _grey)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${fuel['amount_paid']}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _amber,
                    fontSize: 14)),
            Text(_fmt(fuel['created_at']?.toString()),
                style: const TextStyle(fontSize: 11, color: _grey)),
          ]),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Vehicle (Start / Stop Trip)
// ══════════════════════════════════════════════════════════════════════════════
class _VehicleTab extends StatelessWidget {
  final Map<String, dynamic>? activeTrip;
  final List<dynamic> vehicles;
  final String? selectedVehicleId;
  final bool lastOdoLoading, lastOdoFailed;
  final String? lastOdoHint;
  final TextEditingController startOdoCtrl, endOdoCtrl, startLocCtrl, endLocCtrl;
  final File? startPhoto, endPhoto;
  final bool startTripLoading, endTripLoading;
  final bool errStartVeh, errStartOdo, errStartPhoto, errStopOdo, errStopPhoto, errStartLoc, errEndLoc;
  final ValueChanged<String?> onSelectVehicle;
  final VoidCallback onRetryOdo;
  final VoidCallback onCaptureStart, onRetakeStart, onCaptureEnd, onRetakeEnd;
  final VoidCallback onStartTrip, onEndTrip;
  final int photoSecondsLeft;
  final Future<bool> Function(bool isStart) onConfirmDiscard;

  const _VehicleTab({
    required this.activeTrip,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.lastOdoLoading,
    required this.lastOdoFailed,
    required this.lastOdoHint,
    required this.startOdoCtrl,
    required this.endOdoCtrl,
    required this.startLocCtrl,
    required this.endLocCtrl,
    required this.startPhoto,
    required this.endPhoto,
    required this.startTripLoading,
    required this.endTripLoading,
    required this.errStartVeh,
    required this.errStartOdo,
    required this.errStartPhoto,
    required this.errStopOdo,
    required this.errStopPhoto,
    required this.errStartLoc,
    required this.errEndLoc,
    required this.onSelectVehicle,
    required this.onRetryOdo,
    required this.onCaptureStart,
    required this.onRetakeStart,
    required this.onCaptureEnd,
    required this.onRetakeEnd,
    required this.onStartTrip,
    required this.onEndTrip,
    required this.photoSecondsLeft,
    required this.onConfirmDiscard,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: activeTrip != null
            ? _buildStop(context)
            : _buildStart(context),
      );

  // ── Start Trip ─────────────────────────────────────────────────────────────
  Widget _buildStart(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecHead('Start a New Trip'),
          const SizedBox(height: 16),

          _vCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Vehicle
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLbl('SELECT VEHICLE'),
                      const SizedBox(height: 10),
                      _VehicleBottomSheetPicker(
                        selectedId: selectedVehicleId,
                        vehicles: vehicles,
                        onSelected: onSelectVehicle,
                        hasError: errStartVeh,
                      ),
                    ],
                  ),
                ),
                
                Divider(color: _lgrey.withValues(alpha: 0.5), height: 1),

                // Section 2: Odometer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(child: _FieldLbl('START ODOMETER (km)')),
                        if (lastOdoLoading)
                          const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _grey))
                        else if (lastOdoHint != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _blue.withValues(alpha: 0.25)),
                            ),
                            child: const Text('Auto-filled · Read-only',
                                style: TextStyle(fontSize: 10, color: _blue, fontWeight: FontWeight.w600)),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      if (lastOdoFailed)
                        _buildUserFriendlyRetry(onRetryOdo)
                      else
                        _odoField(
                          controller: startOdoCtrl,
                          hint: selectedVehicleId == null
                              ? 'Select a vehicle first'
                              : (lastOdoLoading ? 'Fetching last reading…' : '0'),
                          enabled: selectedVehicleId != null && !lastOdoLoading,
                          readOnly: true,
                          isLocked: startPhoto != null,
                          onTap: startPhoto != null ? () => onConfirmDiscard(true) : null,
                          hasError: errStartOdo,
                        ),
                      const SizedBox(height: 20),
                      const _FieldLbl('STARTING FROM (LOCATION)'),
                      const SizedBox(height: 8),
                      _locField(
                        controller: startLocCtrl,
                        hint: 'e.g. Office, Site A',
                        isLocked: startPhoto != null,
                        onTap: startPhoto != null ? () => onConfirmDiscard(true) : null,
                        hasError: errStartLoc,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Photo Section (Keep separate as it's a primary action)
          _vCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLbl('ODOMETER PHOTO'),
              const SizedBox(height: 12),
              _photoCapture(
                photo: startPhoto,
                enabled: selectedVehicleId != null,
                onCapture: onCaptureStart,
                onRetake: onRetakeStart,
                hasError: errStartPhoto,
              ),
            ]),
          ),
          const SizedBox(height: 24),

          SwipeToConfirm(
            label: 'Swipe to Start Trip',
            icon: Icons.directions_car_rounded,
            color: _black,
            loading: startTripLoading,
            onConfirmed: onStartTrip,
            countdown: photoSecondsLeft,
          ),
          const SizedBox(height: 40),
        ],
      );

  // ── Stop Trip ──────────────────────────────────────────────────────────────
  Widget _buildStop(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeTrip != null) ...[
            _LiveTripBanner(
              activeTrip: activeTrip!,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildViewDocsBtn(context),
          ],
          const SizedBox(height: 24),

          const _SecHead('Stop Trip'),
          const SizedBox(height: 14),

          _vCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLbl('END ODOMETER (km)'),
                      const SizedBox(height: 8),
                      _odoField(
                        controller: endOdoCtrl, 
                        hint: '0', 
                        enabled: true, 
                        isLocked: endPhoto != null,
                        onTap: endPhoto != null ? () => onConfirmDiscard(false) : null,
                        hasError: errStopOdo
                      ),
                      const SizedBox(height: 20),
                      const _FieldLbl('ENDING AT (LOCATION)'),
                      const SizedBox(height: 8),
                      _locField(
                        controller: endLocCtrl,
                        hint: 'e.g. Office, Yard',
                        isLocked: endPhoto != null,
                        onTap: endPhoto != null ? () => onConfirmDiscard(false) : null,
                        hasError: errEndLoc,
                      ),
                    ],
                  ),
                ),
                Divider(color: _lgrey.withValues(alpha: 0.5), height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLbl('Odometer Photo'),
                      const SizedBox(height: 12),
                      _photoCapture(
                          photo: endPhoto,
                          onCapture: onCaptureEnd,
                          onRetake: onRetakeEnd,
                          hasError: errStopPhoto),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SwipeToConfirm(
            label: 'Swipe to Stop Trip',
            icon: Icons.directions_car_rounded,
            color: _red,
            loading: endTripLoading,
            onConfirmed: onEndTrip,
            countdown: photoSecondsLeft,
          ),
          const SizedBox(height: 40),
        ],
      );

  Widget _buildViewDocsBtn(BuildContext context) {
    if (activeTrip == null) return const SizedBox();
    final vId = activeTrip!['vehicle_id']?.toString();
    if (vId == null) return const SizedBox();
    
    final vehicle = vehicles.firstWhereOrNull((v) => v['id'].toString() == vId);
    if (vehicle == null) return const SizedBox();
    
    final rawDocs = vehicle['documents'];
    if (rawDocs == null) return const SizedBox();
    
    List docs = [];
    try {
      docs = rawDocs is String ? json.decode(rawDocs) : rawDocs;
    } catch (_) {}
    
    if (docs.isEmpty) return const SizedBox();
    
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.folder_shared_rounded, size: 18),
        label: Text('View Vehicle Documents (${docs.length})'),
        onPressed: () => _showDocsModal(context, vehicle, docs),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          backgroundColor: _white,
          side: BorderSide(color: _blue.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showDocsModal(BuildContext context, dynamic vehicle, List docs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_copy_rounded, color: _blue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
                        Text('${vehicle['name'] ?? ''} - ${vehicle['registration_number'] ?? ''}', style: const TextStyle(fontSize: 13, color: _grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final isObj = doc is Map;
                  final path = isObj ? doc['path']?.toString() ?? '' : doc.toString();
                  final remark = isObj ? doc['remark']?.toString() ?? '' : '';
                  
                  final fileName = path.split('/').last;
                  final isPdf = fileName.toLowerCase().endsWith('.pdf');
                  
                  // Construct full URL
                  final url = '${ApiService.baseUrl.replaceAll('/api', '')}$path';
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _lgrey),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (isPdf) {
                            // Launch download URL
                            final vehicleName = vehicle['name'] ?? 'Vehicle';
                            final regNumber = vehicle['registration_number'] ?? '';
                            final dlFilename = '$vehicleName - $fileName - $regNumber';
                            final dlUrl = '${ApiService.baseUrl}/vehicles/download-document?path=${Uri.encodeComponent(path)}&filename=${Uri.encodeComponent(dlFilename)}';
                            launchUrl(Uri.parse(dlUrl), mode: LaunchMode.externalApplication);
                          } else {
                            // Show image preview
                            _showImagePreview(context, url);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPdf ? _red.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                  color: isPdf ? _red : _green,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _black), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (remark.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(remark, style: const TextStyle(fontSize: 12, color: _grey)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                isPdf ? Icons.download_rounded : Icons.open_in_full_rounded,
                                color: _grey,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: _white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 300,
                      color: _white,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: _grey, size: 48),
                          SizedBox(height: 12),
                          const Text('Failed to load image', style: TextStyle(color: _grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Fuel
// ══════════════════════════════════════════════════════════════════════════════
class _FuelTab extends StatelessWidget {
  final Map<String, dynamic>? activeTrip;
  final List<dynamic> vehicles;
  final String? fuelVehicleId;
  final TextEditingController fuelOdoCtrl, litersCtrl, amountCtrl;
  final bool fuelLoading;
  final File? fuelBillPhoto;
  final bool errFuelVeh, errFuelOdo, errFuelLiters, errFuelAmount, errFuelPhoto;
  final ValueChanged<String?> onSelectVehicle;
   final VoidCallback onLogFuel;
  final VoidCallback onCaptureBill;
  final VoidCallback onRetakeBill;
  final VoidCallback onConfirmDiscardFuel;

  const _FuelTab({
    required this.activeTrip,
    required this.vehicles,
    required this.fuelVehicleId,
    required this.fuelOdoCtrl,
    required this.litersCtrl,
    required this.amountCtrl,
    required this.fuelLoading,
    required this.fuelBillPhoto,
    required this.errFuelVeh,
    required this.errFuelOdo,
    required this.errFuelLiters,
    required this.errFuelAmount,
    required this.errFuelPhoto,
    required this.onSelectVehicle,
    required this.onLogFuel,
    required this.onCaptureBill,
    required this.onRetakeBill,
    required this.onConfirmDiscardFuel,
  });

  @override
  Widget build(BuildContext context) {
    final hasActive = activeTrip != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SecHead('Log Fuel Fill-Up'),
        const SizedBox(height: 16),

        _vCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Selector (or Active Banner)
              if (hasActive)
                _buildActiveVehicleBanner()
              else
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLbl('SELECT VEHICLE'),
                      const SizedBox(height: 10),
                      _VehicleBottomSheetPicker(
                        selectedId: fuelVehicleId,
                        vehicles: vehicles,
                        onSelected: onSelectVehicle,
                        hasError: errFuelVeh,
                      ),
                    ],
                  ),
                ),
              
              Divider(color: _lgrey.withOpacity(0.5), height: 1),

              // Readings Group
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLbl('ODOMETER READING (km)'),
                    const SizedBox(height: 8),
                    _odoField(
                        controller: fuelOdoCtrl,
                        hint: 'Current odometer',
                        enabled: true,
                        isLocked: fuelBillPhoto != null,
                        onTap: fuelBillPhoto != null ? onConfirmDiscardFuel : null,
                        hasError: errFuelOdo),
                    const SizedBox(height: 24),
                    
                    const _FieldLbl('LITRES FILLED'),
                    const SizedBox(height: 8),
                    _numField(
                        controller: litersCtrl,
                        hint: '0.00',
                        suffix: 'L',
                        isLocked: fuelBillPhoto != null,
                        onTap: fuelBillPhoto != null ? onConfirmDiscardFuel : null,
                        hasError: errFuelLiters),
                    const SizedBox(height: 24),

                    const _FieldLbl('AMOUNT PAID'),
                    const SizedBox(height: 8),
                    _numField(
                        controller: amountCtrl,
                        hint: '0.00',
                        suffix: '₹',
                        isLocked: fuelBillPhoto != null,
                        onTap: fuelBillPhoto != null ? onConfirmDiscardFuel : null,
                        hasError: errFuelAmount),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bill Photo Section
        _vCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: _FieldLbl('FUEL BILL PHOTO')),
              if (fuelBillPhoto != null)
                GestureDetector(
                  onTap: onRetakeBill,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 14, color: _amber),
                    const SizedBox(width: 4),
                    const Text('Retake',
                        style: TextStyle(
                            fontSize: 11,
                            color: _amber,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            _photoCapture(
              photo: fuelBillPhoto,
              enabled: fuelVehicleId != null || activeTrip != null,
              onCapture: onCaptureBill,
              onRetake: onRetakeBill,
              captureHint: 'Tap to capture fuel bill',
              hasError: errFuelPhoto,
            ),
          ]),
        ),
        const SizedBox(height: 24),

        SwipeToConfirm(
          label: 'Swipe to Submit Fuel',
          icon: Icons.local_gas_station_rounded,
          color: _amber,
          loading: fuelLoading,
          onConfirmed: onLogFuel,
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildActiveVehicleBanner() {
    // ...Banner build logic
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.directions_car_rounded,
              color: Color(0xFF00E5FF), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACTIVE VEHICLE (AUTO-SELECTED)',
                style: TextStyle(
                    color: const Color(0xFF00E5FF).withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(activeTrip!['vehicle_name'],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

}

// ─── Loading Splash ───────────────────────────────────────────────────────────
class _VehicleLoadingSplash extends StatefulWidget {
  const _VehicleLoadingSplash();
  @override
  State<_VehicleLoadingSplash> createState() => _VehicleLoadingSplashState();
}

class _VehicleLoadingSplashState extends State<_VehicleLoadingSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Animated background ring
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _blue.withOpacity(0.1 * _opacity.value),
                    ),
                  ),
                  // Icons
                  Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _black.withOpacity(0.05),
                            blurRadius: 20, spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.directions_car_rounded, 
                            color: _blue.withOpacity(_opacity.value), size: 32),
                        const SizedBox(width: 8),
                        Icon(Icons.local_gas_station_rounded, 
                            color: _amber.withOpacity(_opacity.value), size: 30),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Opacity(
                opacity: _opacity.value,
                child: const Column(children: [
                  Text('VEHICLE & FUEL',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _black,
                          letterSpacing: 2.0)),
                  SizedBox(height: 6),
                  Text('Fetching terminal data...',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _grey,
                          letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(height: 60),
              // Track-style progress
              Container(
                width: 140, height: 3,
                decoration: BoxDecoration(
                  color: _lgrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(children: [
                  Positioned(
                    left: 40 * _ctrl.value,
                    child: Container(
                      width: 60, height: 3,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────
class _FieldLbl extends StatelessWidget {
  final String text;
  const _FieldLbl(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          color: _grey,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));
}

// ══════════════════════════════════════════════════════════════════════════════
// Vehicle Bottom-Sheet Picker
// ══════════════════════════════════════════════════════════════════════════════
class _VehicleBottomSheetPicker extends StatefulWidget {
  final String? selectedId;
  final List<dynamic> vehicles;
  final ValueChanged<String?> onSelected;
  final bool hasError;

  const _VehicleBottomSheetPicker({
    required this.selectedId,
    required this.vehicles,
    required this.onSelected,
    this.hasError = false,
  });

  @override
  State<_VehicleBottomSheetPicker> createState() =>
      _VehicleBottomSheetPickerState();
}

class _VehicleBottomSheetPickerState
    extends State<_VehicleBottomSheetPicker> {
  Map<String, dynamic>? get _selected => widget.vehicles.firstWhereOrNull(
      (v) => v['id'].toString() == widget.selectedId);

  Future<void> _open() async {
    String searchQuery = '';
    bool searchByReg   = false;
    final searchCtrl   = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final query = searchQuery.toLowerCase().trim();

          final filtered = widget.vehicles.where((v) {
            if (query.isEmpty) return true;
            final field = searchByReg
                ? (v['registration_number']?.toString() ?? '')
                : (v['name']?.toString() ?? '');
            return field.toLowerCase().contains(query);
          }).toList();

          Widget toggleBtn(bool isReg, String label) {
            final active = searchByReg == isReg;
            return Expanded(
              child: GestureDetector(
                onTap: () => setSheet(() {
                  searchByReg  = isReg;
                  searchQuery  = '';
                  searchCtrl.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? _black : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? _black : _lgrey),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                          color: active ? _white : _grey,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13)),
                ),
              ),
            );
          }

          // Dynamic height accounts for keyboard
          final keyboardH = MediaQuery.of(context).viewInsets.bottom;
          final safeTop   = MediaQuery.of(context).padding.top;
          final screenH   = MediaQuery.of(context).size.height;
          final sheetH = keyboardH > 0
              ? screenH - keyboardH - safeTop - 8
              : screenH * 0.82;

          return SizedBox(
            height: sheetH,
            child: Container(
              decoration: const BoxDecoration(
                color: _white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(
                  top: 20, left: 20, right: 20, bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: _lgrey,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // Title
                  const Text('Select Vehicle',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _black,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text('${widget.vehicles.length} vehicles available',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _grey,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // Toggles
                  Row(children: [
                    toggleBtn(false, 'By Name'),
                    const SizedBox(width: 8),
                    toggleBtn(true, 'By Reg No'),
                  ]),
                  const SizedBox(height: 12),

                  // Search
                  TextField(
                    controller: searchCtrl,
                    autofocus: false,
                    style: const TextStyle(
                        fontSize: 14,
                        color: _black,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: searchByReg
                          ? 'Search by registration number'
                          : 'Search by vehicle name',
                      hintStyle: const TextStyle(
                          color: _grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _grey, size: 20),
                      filled: true,
                      fillColor: _xlGrey,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: _black, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    onChanged: (val) =>
                        setSheet(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),

                  // List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                Icon(Icons.search_off_rounded,
                                    size: 36,
                                    color: _grey.withValues(alpha: 0.4)),
                                const SizedBox(height: 8),
                                const Text('No vehicles found',
                                    style: TextStyle(
                                        color: _grey, fontSize: 13)),
                              ]))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: _lgrey, height: 1),
                            itemBuilder: (ctx, i) {
                              final v = filtered[i];
                              final isSel = v['id'].toString() == widget.selectedId;
                              final isTaken = (v['taken']?.toString().toLowerCase() ?? 'no') == 'yes';

                              return ListTile(
                                enabled: !isTaken,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _black
                                        : (isTaken ? _lgrey : _blue.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                      Icons.directions_car_rounded,
                                      color: isSel ? _white : (isTaken ? _grey : _blue),
                                      size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Text(v['name'] ?? '—',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isTaken ? _grey : (isSel ? _blue : _black))),
                                    if (isTaken) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _red.withOpacity(0.2)),
                                        ),
                                        child: const Text('TAKEN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _red)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                    v['registration_number'] ?? '',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _grey.withOpacity(isTaken ? 0.5 : 1.0),
                                        fontWeight: FontWeight.w500)),
                                trailing: isSel
                                    ? const Icon(Icons.check_circle_rounded, color: _blue, size: 20)
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _xlGrey,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('ID ${v['id']}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: _grey,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                onTap: isTaken ? null : () {
                                  final id = v['id'].toString();
                                  Navigator.pop(ctx);
                                  widget.onSelected(id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return GestureDetector(
      onTap: widget.vehicles.isEmpty ? null : _open,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _xlGrey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel != null
                ? _blue.withValues(alpha: 0.4)
                : _lgrey,
            width: sel != null ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: sel != null
                  ? _blue.withValues(alpha: 0.1)
                  : _white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.directions_car_rounded,
                size: 18,
                color: sel != null ? _blue : _grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: sel != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sel['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _black)),
                      Text(sel['registration_number'],
                          style: const TextStyle(
                              fontSize: 11, color: _grey)),
                    ])
                : Text(
                    widget.vehicles.isEmpty
                        ? 'No vehicles available'
                        : 'Tap to select vehicle',
                    style: const TextStyle(
                        color: _grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: sel != null ? _blue : _grey, size: 22),
        ]),
      ),
    );
  }
}
