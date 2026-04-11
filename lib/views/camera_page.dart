import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'capture_progress_page.dart';
import 'location_error_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart' as cam;
import '../controllers/camera_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_storage/get_storage.dart';
import '../services/location_service.dart';

class CameraPage extends StatefulWidget {
  final String? siteName;
  final List<int>? userIds;
  final bool isBulk;

  /// Optional callback to handle the upload logic on the same page (DEPRECATED: using ProgressPage now).
  final Future<bool> Function({
    required String imagePath,
    required String? lat,
    required String? lang,
    required Function(double) onProgress,
    required Function(String status) onStatusUpdate,
  })?
  onConfirm;

  const CameraPage({
    Key? key,
    this.siteName,
    this.userIds,
    this.isBulk = false,
    this.onConfirm,
  }) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final CameraPageController _cameraCtrl = Get.put(CameraPageController());
  final LocationService _locationService = LocationService();

  String? capturedImagePath;
  geo.Position? currentPosition;
  bool hasLocationPermission = false;
  bool hasCameraPermission = false;
  bool isCheckingPermissions = true;
  bool _isProcessingImage = false; // stamp overlay being applied
  bool _cameraFailedToOpen = false;
  bool _isPreviewing = false;
  String? _tempCapturedPath;

  // Single-page loading states
  bool _isActionInProgress = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = 'Initializing...';
  final List<String> _completedSteps = [];
  StreamSubscription<geo.Position>? _locationSubscription;
  StreamSubscription<geo.ServiceStatus>? _serviceStatusSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isLocationRefreshing = false;
  bool _isLocationServiceEnabled = true;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    try {
      _locationService.init();
      _checkInitialStates();
      checkPermissions();
      _startLocationStream();
      _startServiceStatusStream();
      _startConnectivityStream();
    } catch (e) {
      debugPrint('❌ Initialization Error: $e');
      if (mounted) setState(() => isCheckingPermissions = false);
      Get.snackbar(
        'Initialization Error',
        'Failed to initialize camera page: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Future.delayed(const Duration(seconds: 2), () => Get.back());
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _serviceStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialStates() async {
    bool loc = await _locationService.isLocationEnabled();
    var conn = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isLocationServiceEnabled = loc;
        _isConnected = conn.any(
          (element) => element != ConnectivityResult.none,
        );
      });
    }
  }

  void _startConnectivityStream() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      bool connected = results.any(
        (element) => element != ConnectivityResult.none,
      );
      if (mounted && _isConnected != connected) {
        setState(() => _isConnected = connected);
        if (!connected) {
          Get.snackbar(
            'Internet Lost',
            'Please check your internet connection.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    });
  }

  void _startServiceStatusStream() {
    _serviceStatusSubscription = geo.Geolocator.getServiceStatusStream().listen(
      (status) {
        bool enabled = status == geo.ServiceStatus.enabled;
        if (mounted && _isLocationServiceEnabled != enabled) {
          setState(() => _isLocationServiceEnabled = enabled);
          // Removed _showLocationServiceDialog() to avoid showing popup
          // while LocationErrorPage is being shown via build()
        }
      },
    );
  }

  void _startLocationStream() {
    _locationSubscription =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (geo.Position position) {
            if (mounted) {
              setState(() {
                currentPosition = position;
              });
            }
          },
          onError: (e) {
            debugPrint('Location Stream Error: $e');
          },
        );
  }

  static const _bg = Color(0xFFFAFAFB);
  static const _card = Color(0xFFFFFFFF);
  static const _accent = Color(0xFF000000);

  Widget _buildCenteredScaffold({required Widget child}) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionScreen({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onPressed,
  }) {
    return _buildCenteredScaffold(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFFFF5252)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: const Color(0xFF0A0E21),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => openAppSettings(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Open Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> checkPermissions() async {
    if (mounted) setState(() => isCheckingPermissions = true);

    try {
      // Request camera permission first
      PermissionStatus cameraStatus = await Permission.camera.request();
      hasCameraPermission = cameraStatus.isGranted;

      // If permanently denied, open app settings
      if (cameraStatus.isPermanentlyDenied) {
        await openAppSettings();
        // Re-check after returning from settings
        cameraStatus = await Permission.camera.status;
        hasCameraPermission = cameraStatus.isGranted;
      }

      // Request location permission
      PermissionStatus locationStatus = await Permission.location.request();
      hasLocationPermission = locationStatus.isGranted;

      // If permanently denied, open app settings
      if (locationStatus.isPermanentlyDenied) {
        await openAppSettings();
        // Re-check after returning from settings
        locationStatus = await Permission.location.status;
        hasLocationPermission = locationStatus.isGranted;
      }
    } catch (e) {
      Get.snackbar(
        'Permission Error',
        'Failed to request permissions: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      if (mounted) setState(() => isCheckingPermissions = false);
      return;
    }

    // Get current location if permissions granted
    if (hasLocationPermission) {
      try {
        // Request location service enable if needed
        bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        if (mounted) setState(() => _isLocationServiceEnabled = serviceEnabled);

        if (!serviceEnabled) {
          // No longer calling _showLocationServiceDialog() here
          if (mounted) setState(() => isCheckingPermissions = false);
          return;
        }

        currentPosition = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        Get.snackbar(
          'Location Error',
          'Unable to get current location. Please check GPS settings.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }

    if (mounted) setState(() => isCheckingPermissions = false);

    // Using custom camera UI via CameraPageController
    if (hasCameraPermission && hasLocationPermission) {
      await _cameraCtrl.initializeCamera();
      if (!mounted) return;
    }
  }

  Future<void> _captureInternal() async {
    // Re-check location service status immediately before capture
    bool serviceEnabled = await _locationService.isLocationEnabled();
    if (!serviceEnabled) {
      debugPrint('📍 Capture blocked: Location service is DISABLED');
      if (mounted) setState(() => _isLocationServiceEnabled = false);
      return;
    }

    if (!hasLocationPermission || !hasCameraPermission) {
      debugPrint(
        '📍 Capture blocked: Permissions missing (Loc: $hasLocationPermission, Cam: $hasCameraPermission)',
      );
      return;
    }

    // STRICT GPS CHECK: Ensure we have a location before even allowing the capture flow to proceed
    if (currentPosition == null) {
      debugPrint('📍 Capture: No current position, attempting fresh fix...');
      setState(() => _isLocationRefreshing = true);
      try {
        currentPosition = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        debugPrint(
          '📍 Capture: Fresh fix obtained: ${currentPosition?.latitude}, ${currentPosition?.longitude}',
        );
      } catch (e) {
        debugPrint('📍 Capture: Failed to get fresh fix: $e');
      } finally {
        if (mounted) setState(() => _isLocationRefreshing = false);
      }

      if (currentPosition == null) {
        debugPrint('📍 Capture blocked: Still no GPS lock');
        // Instead of showing a popup, we set _isLocationServiceEnabled to false
        // to trigger the full-screen LocationErrorPage if we can't get a lock
        // or show a snackbar if service is on but signal is weak
        Get.snackbar(
          'GPS Signal Weak',
          'Could not get a precise location lock. Please move to an open area and try again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return;
      }
    }

    setState(() => _isProcessingImage = true);

    try {
      final cam.XFile? image = await _cameraCtrl.takePicture();

      if (image == null) {
        if (mounted) setState(() => _isProcessingImage = false);
        return;
      }

      final imagePath = image.path;

      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _tempCapturedPath = imagePath;
          _isPreviewing = true;
          // Release camera resources immediately once photo is taken to avoid buffer hangs
          _cameraCtrl.isCameraInitialized.value = false;
          _cameraCtrl.onClose();
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to capture photo: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _handleConfirm() async {
    if (_tempCapturedPath == null || _isActionInProgress) return;

    setState(() => _isActionInProgress = true);

    // Release camera resources immediately once photo is taken to avoid buffer hangs
    _cameraCtrl.isCameraInitialized.value = false;
    _cameraCtrl.onClose();

    // IMPORTANT: Move user to the dedicated progress page as requested
    final result = await Get.to(
      () => CaptureProgressPage(
        imagePath: _tempCapturedPath!,
        lat: currentPosition?.latitude.toString(),
        lang: currentPosition?.longitude.toString(),
        siteName: widget.siteName,
        userIds: widget.userIds,
        isBulk: widget.isBulk,
      ),
    );

    if (result != null && result is Map && result['success'] == true) {
      // Successfully returned from progress, close the camera page and pass results back
      Get.back(result: result);
    } else {
      // User cancelled or failed - allow retake or re-attempt
      setState(() => _isActionInProgress = false);
      // Re-open camera for retake/viewfinder?
      // Let's re-init just to be safe if they go back to camera view
      _isPreviewing = false; // go back to viewfinder
      _tempCapturedPath = null;
      checkPermissions();
    }
  }

  void _handleRetake() {
    setState(() {
      _isPreviewing = false;
      _tempCapturedPath = null;
    });
    // Re-initialize camera for retake
    checkPermissions();
  }

  Future<String> addTimestampAndLocationOverlay(String imagePath) async {
    if (GetPlatform.isWeb) return imagePath;

    try {
      final File imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();

      // ── Cap decode to 1920 px wide to prevent OOM / process death ─────────
      // (decoding full-res images can cause the app to be killed while the
      //  camera app is in foreground, which looks like the app "restarts")
      const int maxWidth = 1920;

      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image srcImage = fi.image;

      final int outW = srcImage.width;
      final int outH = srcImage.height;
      final double srcW = outW.toDouble();
      final double srcH = outH.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      );

      // Draw the source image scaled to output size
      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(0, 0, srcW, srcH),
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final now = DateTime.now();
      final imgW = outW.toDouble();
      final imgH = outH.toDouble();

      // Scale text/bar to output width for readability
      final scale = imgW / 1080.0;
      final fontSize = 26.0 * scale;
      final barPadV = 18.0 * scale;
      final barPadH = 24.0 * scale;

      final dateStr = DateFormat('d MMM yyyy').format(now);
      final timeStr = DateFormat('hh:mm:ss a').format(now);
      final locStr = currentPosition != null
          ? '${currentPosition!.latitude.toStringAsFixed(4)}°N  ${currentPosition!.longitude.toStringAsFixed(4)}°E'
          : 'No GPS';

      final userData = GetStorage().read('user');
      final username = userData != null ? userData['username'] : 'N/A';
      final siteStr = widget.siteName != null && widget.siteName!.isNotEmpty
          ? widget.siteName
          : 'N/A';

      final stampText =
          'EST TRACK | $dateStr | $timeStr | $locStr\n'
          'SITE: $siteStr\n'
          'Captured by : $username';

      final tp = TextPainter(
        text: TextSpan(
          text: stampText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            height: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 3,
      );
      tp.layout(maxWidth: imgW - barPadH * 2);

      final barH = tp.height + barPadV * 2;

      // Semi-transparent black bar at bottom
      canvas.drawRect(
        Rect.fromLTWH(0, imgH - barH, imgW, barH),
        Paint()..color = Colors.black.withOpacity(0.55),
      );

      tp.paint(canvas, Offset(barPadH, imgH - barH + barPadV));

      // Render and save
      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(outW, outH);
      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final rgba = byteData!.buffer.asUint8List();

      final decoded = img.Image.fromBytes(
        width: outW,
        height: outH,
        bytes: rgba.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );

      final jpegBytes = img.encodeJpg(decoded, quality: 80);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/processed_${now.millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(jpegBytes);

      return tempFile.path;
    } catch (e) {
      print('Error adding overlay: $e');
      return imagePath;
    }
  }

  Future<bool?> _showImageConfirmationDialog(String imagePath) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Confirm Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),

                // Image preview
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GetPlatform.isWeb
                          ? Image.network(imagePath, fit: BoxFit.contain)
                          : Image.file(File(imagePath), fit: BoxFit.contain),
                    ),
                  ),
                ),

                // Action buttons
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(false); // Retake
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Retake'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(true); // Proceed
                        },
                        icon: Icon(Icons.check),
                        label: Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
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

  @override
  Widget build(BuildContext context) {
    if (!_isLocationServiceEnabled) {
      return LocationErrorPage(
        onRetry: () async {
          debugPrint('📍 Retrying location check...');
          bool enabled = await _locationService.isLocationEnabled();
          if (enabled) {
            debugPrint('📍 Location enabled! Returning to camera.');
            if (mounted) setState(() => _isLocationServiceEnabled = true);
            checkPermissions();
          } else {
            debugPrint('📍 Location still disabled.');
          }
        },
      );
    }

    if (_isPreviewing) {
      return _buildPreviewUI();
    }

    if (isCheckingPermissions) {
      return _buildCenteredScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: _accent, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            const Text(
              'Preparing check-in...',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Requesting camera & location',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isProcessingImage) {
      return _buildCenteredScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: _accent, strokeWidth: 3),
            ),
            SizedBox(height: 20),
            Text(
              'Processing photo...',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Adding timestamp & location stamp',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!hasCameraPermission) {
      return _buildPermissionScreen(
        icon: Icons.camera_alt,
        title: 'Camera permission required',
        message:
            'Camera permission is required to capture your attendance photo.',
        onPressed: () async {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            setState(() => hasCameraPermission = true);
            checkPermissions();
          } else if (status.isPermanentlyDenied) {
            await openAppSettings();
          } else {
            Get.snackbar(
              'Permission Denied',
              'Camera permission is required to continue.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
      );
    }

    if (!hasLocationPermission) {
      return _buildPermissionScreen(
        icon: Icons.location_off,
        title: 'Location permission required',
        message:
            'Location permission is required to record your check-in location.',
        onPressed: () async {
          final status = await Permission.location.request();
          if (status.isGranted) {
            setState(() => hasLocationPermission = true);
            checkPermissions();
          } else if (status.isPermanentlyDenied) {
            await openAppSettings();
          } else {
            Get.snackbar(
              'Permission Denied',
              'Location permission is required to continue.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
      );
    }

    if (_cameraFailedToOpen) {
      return _buildCenteredScaffold(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: Color(0xFFFF5252),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Camera Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Could not open the camera. Please try again or check your permissions.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _cameraFailedToOpen = false;
                    });
                    checkPermissions();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF0A0E21),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  label: const Text(
                    'Go Back',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (hasCameraPermission && hasLocationPermission) {
      return Obx(() {
        if (!_cameraCtrl.isCameraInitialized.value) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 100,
                      height:
                          100 * _cameraCtrl.cameraController!.value.aspectRatio,
                      child: cam.CameraPreview(_cameraCtrl.cameraController!),
                    ),
                  ),
                ),
              ),

              // GPS & Network Status Indicators
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // GPS Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: currentPosition != null
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentPosition == null ||
                                  _isLocationRefreshing)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.redAccent,
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.greenAccent,
                                  size: 14,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                currentPosition != null
                                    ? 'GPS LOCKED'
                                    : 'SEARCHING GPS...',
                                style: TextStyle(
                                  color: currentPosition != null
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Network Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isConnected
                                  ? Colors.blueAccent
                                  : Colors.orangeAccent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isConnected ? Icons.wifi : Icons.wifi_off,
                                color: _isConnected
                                    ? Colors.blueAccent
                                    : Colors.orangeAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isConnected ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: _isConnected
                                      ? Colors.blueAccent
                                      : Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
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

              // Top Bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _cameraCtrl.flashMode.value == cam.FlashMode.off
                                  ? Icons.flash_off
                                  : _cameraCtrl.flashMode.value ==
                                        cam.FlashMode.auto
                                  ? Icons.flash_auto
                                  : Icons.flash_on,
                              color: Colors.white,
                            ),
                            onPressed: () => _cameraCtrl.toggleFlash(),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                            ),
                            onPressed: () => _cameraCtrl.switchCamera(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Capture Button
              if (!_isProcessingImage)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _captureInternal,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      });
    }

    return _buildCenteredScaffold(child: const Text('Loading...'));
  }

  Widget _buildPreviewUI() {
    if (_tempCapturedPath == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Image
          Positioned.fill(
            child: Image.file(File(_tempCapturedPath!), fit: BoxFit.contain),
          ),

          // Top Information Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Captured Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ensure all details are visible',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Area
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _isActionInProgress
                ? _buildActionProgress()
                : Row(
                    children: [
                      // Retake Button
                      GestureDetector(
                        onTap: _handleRetake,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              Text(
                                'RETAKE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Swipe to Confirm
                      Expanded(
                        child: _ConfirmSwipeButton(onConfirm: _handleConfirm),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _uploadStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
              minHeight: 6,
            ),
          ),
          if (_completedSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            ..._completedSteps.map((step) => _buildStepItem(step, true)),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? Colors.greenAccent : Colors.white24,
            size: 16,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDone ? Colors.white70 : Colors.white24,
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSwipeButton extends StatefulWidget {
  final VoidCallback onConfirm;

  const _ConfirmSwipeButton({required this.onConfirm});

  @override
  State<_ConfirmSwipeButton> createState() => _ConfirmSwipeButtonState();
}

class _ConfirmSwipeButtonState extends State<_ConfirmSwipeButton>
    with TickerProviderStateMixin {
  final ValueNotifier<double> _posNotifier = ValueNotifier(0.0);
  bool _triggered = false;

  late final AnimationController _resetController;
  late final Animation<double> _resetAnimation;

  // Guiding arrows animation
  late final AnimationController _arrowController;
  final List<Animation<double>> _arrowAnims = [];

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resetAnimation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.elasticOut,
    );
    _resetAnimation.addListener(() {
      _posNotifier.value = _posNotifier.value * (1.0 - _resetAnimation.value);
    });

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    for (int i = 0; i < 3; i++) {
      _arrowAnims.add(
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
        ]).animate(
          CurvedAnimation(
            parent: _arrowController,
            curve: Interval(i * 0.15, 1.0, curve: Curves.easeInOut),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _arrowController.dispose();
    _posNotifier.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double maxSwipe) {
    if (_triggered) return;
    _resetController.stop();
    _posNotifier.value = (_posNotifier.value + details.delta.dx).clamp(
      0.0,
      maxSwipe,
    );

    if (_posNotifier.value >= maxSwipe) {
      _triggered = true;
      HapticFeedback.vibrate();
      widget.onConfirm();
    }
  }

  void _onPanEnd(DragEndDetails details, double maxSwipe) {
    if (_triggered) return;
    if (_posNotifier.value < maxSwipe) {
      _resetController.reset();
      _resetController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const thumbSize = 52.0;
        final maxSwipe = totalWidth - thumbSize - 8;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.greenAccent.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // ── Animated guiding arrows ───────────────────────────────────
              Positioned.fill(
                child: ValueListenableBuilder<double>(
                  valueListenable: _posNotifier,
                  builder: (_, pos, __) {
                    final t = (pos / maxSwipe).clamp(0.0, 1.0);
                    final opacity = (1.0 - t * 2.0).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 40),
                          const Text(
                            'SWIPE TO PROCEED',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ...List.generate(3, (i) {
                            return AnimatedBuilder(
                              animation: _arrowAnims[i],
                              builder: (_, __) {
                                return Opacity(
                                  opacity: _arrowAnims[i].value,
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.greenAccent,
                                    size: 18,
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Thumb ──────────────────────────────────────────────────────
              ValueListenableBuilder<double>(
                valueListenable: _posNotifier,
                builder: (context, pos, child) {
                  return Positioned(
                    left: 4 + pos,
                    top: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) => _onPanUpdate(d, maxSwipe),
                      onHorizontalDragEnd: (d) => _onPanEnd(d, maxSwipe),
                      child: Container(
                        width: thumbSize,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
