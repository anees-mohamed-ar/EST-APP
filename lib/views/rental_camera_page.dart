import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img_lib;
import '../services/location_service.dart';
import 'location_error_page.dart';

/// Custom Camera View dedicated to capturing Material IN and OUT photos
/// Maintains exact camera UI, GPS/Network indicators, and "SWIPE TO PROCEED" as attendance camera.
/// Returns the captured watermarked [File] via [Get.back(result: file)] or null if cancelled.
class RentalCameraPage extends StatefulWidget {
  final String title; // "Capture Material IN" or "Capture Material OUT"
  final String materialName;
  final String actionType; // "RENTAL IN" or "RENTAL OUT"
  final String? siteName;
  final Map<String, String>? extraDetails;

  const RentalCameraPage({
    Key? key,
    required this.title,
    required this.materialName,
    required this.actionType,
    this.siteName,
    this.extraDetails,
  }) : super(key: key);

  @override
  State<RentalCameraPage> createState() => _RentalCameraPageState();
}

class _RentalCameraPageState extends State<RentalCameraPage>
    with WidgetsBindingObserver {
  cam.CameraController? _controller;
  List<cam.CameraDescription>? _cameras;
  bool _initialized = false;
  bool _isCapturing = false;
  bool _isProcessingImage = false;
  File? _previewFile;
  bool _isPreviewing = false;
  int _cameraIndex = 0; // default to back camera for material photography
  geo.Position? _currentPos;
  Timer? _locationTimer;
  cam.FlashMode _flashMode = cam.FlashMode.off;
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isLocationServiceEnabled = true;
  StreamSubscription<geo.ServiceStatus>? _serviceStatusSubscription;
  StreamSubscription<geo.Position>? _positionSubscription;

  // Review screen timer
  Timer? _reviewTimer;
  int _previewCountdownSeconds = 60;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initConnectivity();
    _initLocationTracking();
    _initCamera();
    _startLocationTimer();
  }

  Future<void> _initLocationTracking() async {
    bool enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _isLocationServiceEnabled = enabled);
    if (enabled) {
      _fetchLocation();
    }

    _serviceStatusSubscription =
        geo.Geolocator.getServiceStatusStream().listen((status) {
      final isEnabled = status == geo.ServiceStatus.enabled;
      if (mounted && _isLocationServiceEnabled != isEnabled) {
        setState(() => _isLocationServiceEnabled = isEnabled);
        if (isEnabled) {
          _fetchLocation();
        } else {
          setState(() => _currentPos = null);
        }
      }
    });

    _positionSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((geo.Position pos) {
      if (mounted) {
        setState(() {
          _currentPos = pos;
          _isLocationServiceEnabled = true;
        });
      }
    }, onError: (e) {
      debugPrint('Location stream error: $e');
    });
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((res) {
      if (mounted) {
        setState(() => _isConnected = !res.contains(ConnectivityResult.none));
      }
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((res) {
      if (mounted) {
        setState(() => _isConnected = !res.contains(ConnectivityResult.none));
      }
    });
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isCapturing && !_isPreviewing) {
        _fetchLocation();
      }
    });
  }

  void _startPreviewTimer() {
    _reviewTimer?.cancel();
    _previewCountdownSeconds = 60;
    _reviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _previewCountdownSeconds--);
      if (_previewCountdownSeconds <= 0) {
        _cancelPreviewTimer();
        Get.back(); // Auto-cancel on timeout
      }
    });
  }

  void _cancelPreviewTimer() {
    _reviewTimer?.cancel();
    _reviewTimer = null;
    _previewCountdownSeconds = 60;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_initialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _fetchLocation({bool requestService = false}) async {
    try {
      bool enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled && requestService) {
        enabled = await LocationService().requestService();
      }
      if (mounted && _isLocationServiceEnabled != enabled) {
        setState(() => _isLocationServiceEnabled = enabled);
      }
      if (!enabled) return;

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;

      // 1. Instant fix from last known position if available
      if (_currentPos == null) {
        final lastKnown = await geo.Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentPos = lastKnown;
            _isLocationServiceEnabled = true;
          });
        }
      }

      // 2. High accuracy fresh GPS fix
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) {
        setState(() {
          _currentPos = pos;
          _isLocationServiceEnabled = true;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        Get.snackbar('Camera Permission', 'Camera access is required to take photos.',
            backgroundColor: Colors.red.shade800, colorText: Colors.white);
        return;
      }

      _cameras = await cam.availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        Get.snackbar('Error', 'No camera detected on this device.',
            backgroundColor: Colors.red.shade800, colorText: Colors.white);
        return;
      }

      // Default to back camera for material photography
      final backIdx = _cameras!.indexWhere(
          (c) => c.lensDirection == cam.CameraLensDirection.back);
      if (backIdx != -1) _cameraIndex = backIdx;

      await _setupController(_cameras![_cameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupController(cam.CameraDescription desc) async {
    await _controller?.dispose();
    _controller = cam.CameraController(
      desc,
      cam.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _initialized = true);
        _fetchLocation();
      }
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras!.length;
    setState(() => _initialized = false);
    await _setupController(_cameras![_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_initialized) return;
    final modes = [cam.FlashMode.off, cam.FlashMode.auto, cam.FlashMode.always];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _takePicture() async {
    if (!_isLocationServiceEnabled || _currentPos == null) {
      Get.snackbar(
        'GPS Location Mandatory',
        'Acquiring GPS location... Photo capture is locked until GPS is verified.',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      _fetchLocation(requestService: true);
      return;
    }
    if (_controller == null || !_initialized || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      HapticFeedback.mediumImpact();
      final xFile = await _controller!.takePicture();
      _previewFile = File(xFile.path);

      if (mounted) {
        setState(() {
          _isPreviewing = true;
          _isCapturing = false;
        });
        _startPreviewTimer();
      }
    } catch (e) {
      debugPrint('Take picture error: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _retake() {
    _cancelPreviewTimer();
    setState(() {
      _previewFile = null;
      _isPreviewing = false;
    });
  }

  Future<void> _confirm() async {
    if (_previewFile == null || _isProcessingImage) return;
    if (_currentPos == null) {
      Get.snackbar(
        'GPS Location Mandatory',
        'Cannot confirm photo without valid GPS coordinates. Please wait for GPS lock.',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
      return;
    }
    _cancelPreviewTimer();
    setState(() {
      _isProcessingImage = true;
      _isActionInProgress = true;
    });

    try {
      final watermarked = await _addWatermark(_previewFile!.path);
      Get.back(result: {
        'file': File(watermarked),
        'lat': _currentPos!.latitude.toString(),
        'lng': _currentPos!.longitude.toString(),
      });
    } catch (e) {
      debugPrint('Watermark error: $e');
      Get.back(result: {
        'file': _previewFile!,
        'lat': _currentPos!.latitude.toString(),
        'lng': _currentPos!.longitude.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _isActionInProgress = false;
        });
      }
    }
  }

  Future<String> _addWatermark(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      const int targetWidth = 1280;

      final ui.Codec codec =
          await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image srcImage = fi.image;

      final int outW = srcImage.width;
      final int outH = srcImage.height;
      final recorder = ui.PictureRecorder();
      final canvas =
          Canvas(recorder, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));

      canvas.drawImage(
          srcImage, Offset.zero, Paint()..filterQuality = FilterQuality.medium);

      final now = DateTime.now();
      final scale = outW / 1080.0;
      final fontSize = 26.0 * scale;
      final pad = 24.0 * scale;

      final user = GetStorage().read('user')?['username'] ?? 'User';
      final dateStr = DateFormat('dd MMM yyyy | hh:mm a').format(now);
      final matStr = widget.materialName;
      final actStr = widget.actionType.toUpperCase();
      final siteStr = widget.siteName ?? 'Not Specified';

      final locStr = _currentPos != null
          ? 'LOC: ${_currentPos!.latitude.toStringAsFixed(5)}, ${_currentPos!.longitude.toStringAsFixed(5)}'
          : 'LOC: Unknown';

      final stamp =
          'MEPL RENTAL  |  $actStr\nEQUIPMENT: $matStr\nSITE: $siteStr\nTIME: $dateStr\nBY: $user  |  $locStr';

      final tp = TextPainter(
        text: TextSpan(
          text: stamp,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
            shadows: [
              Shadow(
                color: const Color(0xD9000000),
                blurRadius: 4,
                offset: const Offset(1, 1),
              )
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 6,
      );

      // Right-side extra details if provided
      TextPainter? tpRight;
      if (widget.extraDetails != null && widget.extraDetails!.isNotEmpty) {
        final detailStr = widget.extraDetails!.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        tpRight = TextPainter(
          text: TextSpan(
            text: detailStr,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.25,
              shadows: [
                Shadow(
                  color: const Color(0xD9000000),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                )
              ],
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.right,
          maxLines: 5,
        );
      }

      tp.layout(maxWidth: outW * 0.65);
      tpRight?.layout(maxWidth: outW * 0.32);

      final double maxH = [tp.height, tpRight?.height ?? 0.0]
          .reduce((a, b) => a > b ? a : b);
      final double bannerH = maxH + (pad * 2);

      // Semi-transparent black bar at bottom (matching attendance)
      final bgRect =
          Rect.fromLTWH(0, outH - bannerH, outW.toDouble(), bannerH);
      canvas.drawRect(
        bgRect,
        Paint()..color = Colors.black.withOpacity(0.55),
      );

      // Paint left text
      tp.paint(canvas, Offset(pad, outH - bannerH + pad));

      // Paint right text
      if (tpRight != null) {
        tpRight.paint(canvas, Offset(outW - pad - tpRight.width, outH - bannerH + pad));
      }

      final pic = recorder.endRecording();
      final imgResult = await pic.toImage(outW, outH);
      final pngData =
          await imgResult.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = pngData!.buffer.asUint8List();

      // Encode as high-compression JPEG (quality 70, matching attendance)
      final decoded = img_lib.decodeImage(pngBytes);
      if (decoded == null) throw Exception('Image decoding failed');

      final jpgBytes = img_lib.encodeJpg(decoded, quality: 70);

      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/rental_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(jpgBytes);

      return outPath;
    } catch (e) {
      debugPrint('Error watermarking & compressing rental photo: $e');
      return path;
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _reviewTimer?.cancel();
    _connectivitySubscription?.cancel();
    _serviceStatusSubscription?.cancel();
    _positionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocationServiceEnabled) {
      return LocationErrorPage(
        onRetry: () async {
          debugPrint('📍 Retrying rental location check...');
          bool enabled = await geo.Geolocator.isLocationServiceEnabled();
          if (enabled) {
            if (mounted) setState(() => _isLocationServiceEnabled = true);
            _fetchLocation();
          } else {
            enabled = await LocationService().requestService();
            if (enabled && mounted) {
              setState(() => _isLocationServiceEnabled = true);
              _fetchLocation();
            }
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isPreviewing ? _buildPreview() : _buildViewfinder(),
    );
  }

  // ── Viewfinder (Exact attendance camera design) ──
  Widget _buildViewfinder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (matching attendance)
        if (_initialized && _controller != null)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 100,
                  height: 100 * _controller!.value.aspectRatio,
                  child: cam.CameraPreview(_controller!),
                ),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // GPS & Network Status Indicators (Exact attendance camera header)
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _currentPos != null ? Colors.greenAccent : Colors.redAccent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentPos == null)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                            ),
                          )
                        else
                          const Icon(Icons.location_on, color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _currentPos != null ? 'GPS LOCKED' : 'SEARCHING GPS...',
                          style: TextStyle(
                            color: _currentPos != null ? Colors.greenAccent : Colors.redAccent,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isConnected ? Colors.blueAccent : Colors.orangeAccent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isConnected ? Colors.blueAccent : Colors.orangeAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            color: _isConnected ? Colors.blueAccent : Colors.orangeAccent,
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

        // Equipment Banner below GPS indicators
        Positioned(
          top: MediaQuery.of(context).padding.top + 58,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xA6000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.actionType.toUpperCase().contains('IN')
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.actionType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.materialName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.siteName != null)
                        Text(
                          widget.siteName!,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top Bar (Close, Flash, Switch Camera matching camera_page.dart)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0x73000000),
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
                    decoration: const BoxDecoration(
                      color: Color(0x73000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _flashMode == cam.FlashMode.off
                            ? Icons.flash_off
                            : _flashMode == cam.FlashMode.auto
                                ? Icons.flash_auto
                                : Icons.flash_on,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0x73000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                      ),
                      onPressed: _flipCamera,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bottom Capture Status Pill & Capture Button
        if (!_isProcessingImage) ...[
          Positioned(
            bottom: 135,
            left: 20,
            right: 20,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: (_currentPos != null && _isLocationServiceEnabled)
                      ? const Color(0xCC16A34A)
                      : const Color(0xCCDC2626),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_currentPos != null && _isLocationServiceEnabled)
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_currentPos != null && _isLocationServiceEnabled)
                          ? Icons.check_circle_rounded
                          : Icons.location_off_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (_currentPos != null && _isLocationServiceEnabled)
                          ? 'GPS LOCKED • READY TO CAPTURE'
                          : 'GPS MANDATORY • CAPTURE LOCKED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: (_currentPos != null && _isLocationServiceEnabled) ? 1.0 : 0.45,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_currentPos != null && _isLocationServiceEnabled)
                            ? Colors.white
                            : Colors.redAccent,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_currentPos != null && _isLocationServiceEnabled)
                              ? Colors.white
                              : const Color(0x66FFFFFF),
                        ),
                        child: (_currentPos == null || !_isLocationServiceEnabled)
                            ? const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Preview & SWIPE TO PROCEED Screen (Exact camera_page.dart layout) ──
  Widget _buildPreview() {
    if (_previewFile == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Image
          Positioned.fill(
            child: Image.file(_previewFile!, fit: BoxFit.contain),
          ),

          // Top Information Banner (Matches camera_page.dart)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x80000000),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review ${widget.materialName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Ensure equipment and serial details are visible',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Area (Retake + SWIPE TO PROCEED)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: _isActionInProgress
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2),
                          SizedBox(width: 14),
                          Text('Applying stamp & processing...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Retake Button
                      GestureDetector(
                        onTap: _retake,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
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
                      // Swipe to Confirm / SWIPE TO PROCEED
                      Expanded(
                        child: _ConfirmSwipeButton(
                          onConfirm: _confirm,
                          countdownSeconds: _previewCountdownSeconds,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Swipe to Confirm Widget (From camera_page.dart) ─────────────────────────
class _ConfirmSwipeButton extends StatefulWidget {
  final VoidCallback onConfirm;
  final int countdownSeconds;
  const _ConfirmSwipeButton({required this.onConfirm, required this.countdownSeconds});

  @override
  State<_ConfirmSwipeButton> createState() => _ConfirmSwipeButtonState();
}

class _ConfirmSwipeButtonState extends State<_ConfirmSwipeButton>
    with TickerProviderStateMixin {
  final ValueNotifier<double> _posNotifier = ValueNotifier(0.0);
  bool _triggered = false;
  late final AnimationController _resetController;
  late final Animation<double> _resetAnimation;
  late final AnimationController _arrowController;
  final List<Animation<double>> _arrowAnims = [];

  @override
  void initState() {
    super.initState();
    _resetController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resetAnimation =
        CurvedAnimation(parent: _resetController, curve: Curves.elasticOut);
    _resetAnimation.addListener(() {
      _posNotifier.value = _posNotifier.value * (1.0 - _resetAnimation.value);
    });

    _arrowController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
          ..repeat();
    for (int i = 0; i < 3; i++) {
      _arrowAnims.add(TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
      ]).animate(CurvedAnimation(
        parent: _arrowController,
        curve: Interval(i * 0.15, 1.0, curve: Curves.easeInOut),
      )));
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _arrowController.dispose();
    _posNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      const thumbSize = 52.0;
      final maxSwipe = totalWidth - thumbSize - 8;
      final isTimerCritical = widget.countdownSeconds <= 10;
      final timerProgress = (widget.countdownSeconds / 60.0).clamp(0.0, 1.0);

      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: isTimerCritical
              ? Colors.red.withOpacity(0.08)
              : Colors.greenAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isTimerCritical ? Colors.red.withOpacity(0.3) : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Track Text with Animated Chevrons
            Center(
              child: Opacity(
                opacity: 0.85,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      3,
                      (i) => AnimatedBuilder(
                        animation: _arrowAnims[i],
                        builder: (_, __) => Opacity(
                          opacity: _arrowAnims[i].value,
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SWIPE TO PROCEED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Swipeable Thumb with countdown timer ring
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (context, pos, _) {
                return Positioned(
                  left: 4 + pos,
                  top: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_triggered) return;
                      _resetController.stop();
                      _posNotifier.value =
                          (_posNotifier.value + details.delta.dx).clamp(0.0, maxSwipe);
                      if (_posNotifier.value >= maxSwipe) {
                        _triggered = true;
                        HapticFeedback.vibrate();
                        widget.onConfirm();
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      if (_triggered) return;
                      if (_posNotifier.value < maxSwipe) {
                        _resetController.reset();
                        _resetController.forward();
                      }
                    },
                    child: Container(
                      width: thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: timerProgress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isTimerCritical ? Colors.red : Colors.greenAccent.shade700,
                              ),
                              backgroundColor: Colors.black12,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: isTimerCritical ? Colors.red : const Color(0xFF16A34A),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
