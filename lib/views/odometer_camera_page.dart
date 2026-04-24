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
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/location_service.dart';

/// A lightweight, full-screen camera dedicated to capturing odometer photos.
/// Returns the captured [File] via [Get.back(result: file)] or null if cancelled.
class OdometerCameraPage extends StatefulWidget {
  final String title; // e.g. "Start Odometer" or "End Odometer"
  final String? vehicleName;
  final Map<String, String>? extraDetails;
  const OdometerCameraPage({Key? key, required this.title, this.vehicleName, this.extraDetails}) : super(key: key);

  @override
  State<OdometerCameraPage> createState() => _OdometerCameraPageState();
}

class _OdometerCameraPageState extends State<OdometerCameraPage>
    with WidgetsBindingObserver {
  cam.CameraController? _controller;
  List<cam.CameraDescription>? _cameras;
  bool _initialized = false;
  bool _isCapturing = false;
  bool _isProcessingImage = false;
  File? _previewFile;
  bool _isPreviewing = false;
  int _cameraIndex = 0; // start with back camera for odometer
  geo.Position? _currentPos;
  Timer? _locationTimer;
  cam.FlashMode _flashMode = cam.FlashMode.off;
  
  // Timer for review screen
  Timer? _reviewTimer;
  int _previewCountdownSeconds = 60;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
    _startLocationTimer();
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
      if (!mounted) { timer.cancel(); return; }
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

  Future<void> _fetchLocation({bool sync = false, bool requestService = false}) async {
    try {
      bool enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled && requestService) {
        enabled = await LocationService().requestService();
      }

      if (!enabled) {
        if (mounted) setState(() => _currentPos = null);
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: sync ? 8 : 5));
      if (mounted) setState(() => _currentPos = pos);
    } catch (e) {
      if (mounted) setState(() => _currentPos = null);
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      Get.back();
      return;
    }

    final cameras = await cam.availableCameras();
    if (cameras.isEmpty) {
      Get.back();
      return;
    }
    _cameras = cameras;

    // Prefer back camera for odometer
    _cameraIndex = cameras.indexWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.back,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _controller?.dispose();
    _controller = cam.CameraController(
      cameras[_cameraIndex],
      cam.ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (mounted) setState(() => _initialized = true);
      _fetchLocation();
    } catch (_) {
      Get.back();
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_initialized) return;
    
    cam.FlashMode nextMode;
    if (_flashMode == cam.FlashMode.off) {
      nextMode = cam.FlashMode.torch;
    } else if (_flashMode == cam.FlashMode.torch) {
      nextMode = cam.FlashMode.auto;
    } else {
      nextMode = cam.FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_controller == null || !_initialized || _isCapturing) return;
    
    // Strict GPS Check: Try to get a fresh fix if we don't have one
    if (_currentPos == null) {
      setState(() => _isCapturing = true);
      await _fetchLocation(sync: true, requestService: true);
      if (_currentPos == null) {
        setState(() => _isCapturing = false);
        Get.snackbar(
          'Location Required',
          'GPS lock is missing. Please enable location services and move to an open area.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          icon: const Icon(Icons.location_off, color: Colors.white),
        );
        return;
      }
      setState(() => _isCapturing = false);
    }

    setState(() => _isCapturing = true);
    try {
      final xfile = await _controller!.takePicture();
      if (mounted) {
        setState(() {
          _previewFile = File(xfile.path);
          _isPreviewing = true;
          _isCapturing = false;
        });
        _startPreviewTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
      Get.snackbar('Error', 'Failed to capture: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
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
    _cancelPreviewTimer();
    setState(() {
      _isProcessingImage = true;
      _isActionInProgress = true;
    });

    try {
      final watermarked = await _addWatermark(_previewFile!.path);
      Get.back(result: File(watermarked));
    } catch (e) {
      Get.snackbar('Error', 'Failed to process image: $e');
      Get.back(result: _previewFile);
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
      const int maxWidth = 1920; 

      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image srcImage = fi.image;

      final int outW = srcImage.width;
      final int outH = srcImage.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()));

      canvas.drawImage(srcImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);

      final now = DateTime.now();
      final scale = outW / 1080.0;
      final fontSize = 26.0 * scale;
      final pad = 24.0 * scale;

      final user = GetStorage().read('user')?['username'] ?? 'User';
      final dateStr = DateFormat('dd MMM yyyy | hh:mm a').format(now);
      final vehStr = widget.vehicleName ?? 'Not Selected';
      final locStr = _currentPos != null 
          ? 'LOC: ${_currentPos!.latitude.toStringAsFixed(5)}, ${_currentPos!.longitude.toStringAsFixed(5)}' 
          : 'LOC: Unknown';
      final stamp = 'MEPL-Track  |  $dateStr\nOPERATOR: $user\nVEHICLE: $vehStr\n$locStr';

      final tp = TextPainter(
        text: TextSpan(
          text: stamp,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(1,1))]
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 5,
      );
      // Prepare extra details (right aligned) if provided
      TextPainter? tpRight;
      if (widget.extraDetails != null && widget.extraDetails!.isNotEmpty) {
        final detailStr = widget.extraDetails!.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        tpRight = TextPainter(
          text: TextSpan(
            text: detailStr,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
              shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(1,1))]
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.right,
          maxLines: 5,
        );
        tpRight.layout(maxWidth: (outW - pad * 3) * 0.35);
      }

      tp.layout(maxWidth: tpRight != null ? (outW - pad * 3) * 0.65 : outW - pad * 2);

      final double maxH = tpRight != null ? (tp.height > tpRight.height ? tp.height : tpRight.height) : tp.height;
      final barH = maxH + pad * 2;

      canvas.drawRect(
        Rect.fromLTWH(0, outH - barH, outW.toDouble(), barH),
        Paint()..color = Colors.black.withOpacity(0.45),
      );

      tp.paint(canvas, Offset(pad, outH - barH + pad));
      if (tpRight != null) {
        tpRight.paint(canvas, Offset(outW - tpRight.width - pad, outH - barH + pad));
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(outW, outH);
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = byteData!.buffer.asUint8List();

      final decoded = img.Image.fromBytes(
        width: outW,
        height: outH,
        bytes: rgba.buffer,
        format: img.Format.uint8,
        numChannels: 4,
      );

      final jpeg = img.encodeJpg(decoded, quality: 85);
      final tempDir = await getTemporaryDirectory();
      final outFile = File('${tempDir.path}/odo_${now.millisecondsSinceEpoch}.jpg');
      await outFile.writeAsBytes(jpeg);
      
      return outFile.path;
    } catch (_) {
      return path;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _reviewTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isActionInProgress) {
      return _buildProcessingUI();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isPreviewing ? _buildPreview() : _buildViewfinder(),
      ),
    );
  }

  Widget _buildProcessingUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 4),
            ),
            const SizedBox(height: 30),
            const Text(
              'PROCESSING PHOTO',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Applying location & vehicle stamps...',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (Matches camera_page.dart scaling)
        if (_initialized && _controller != null)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain, // Consistency with attendance camera
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

        // GPS status indicator (Top center)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
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
                  const SizedBox(width: 8),
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
          ),
        ),

        // Top Controls (Matches camera_page.dart style)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              Container(
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ),

              // Flash button
              Container(
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
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
            ],
          ),
        ),

        // Guide frame overlay (Modernized)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Stack(
                  children: [
                    for (final alignment in [
                      Alignment.topLeft,
                      Alignment.topRight,
                      Alignment.bottomLeft,
                      Alignment.bottomRight,
                    ])
                      Align(
                        alignment: alignment,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border(
                              top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                                  ? const BorderSide(color: Colors.white, width: 4)
                                  : BorderSide.none,
                              bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                                  ? const BorderSide(color: Colors.white, width: 4)
                                  : BorderSide.none,
                              left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                                  ? const BorderSide(color: Colors.white, width: 4)
                                  : BorderSide.none,
                              right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                                  ? const BorderSide(color: Colors.white, width: 4)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text(
                  'ALIGN ODOMETER WITHIN FRAME',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Controls Area
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              top: 20,
            ),
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _capture,
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
                      child: _isCapturing 
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)))
                        : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview image
        Positioned.fill(
          child: Image.file(_previewFile!, fit: BoxFit.contain),
        ),

        // Top Banner (Matches camera_page.dart)
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
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
                  child: const Icon(Icons.photo_library_outlined, color: Colors.greenAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Captured Photo',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ensure details are clearly visible',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom action area (Matches camera_page.dart)
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Row(
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
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Swipe to Confirm
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

class _ConfirmSwipeButtonState extends State<_ConfirmSwipeButton> with TickerProviderStateMixin {
  final ValueNotifier<double> _posNotifier = ValueNotifier(0.0);
  bool _triggered = false;
  late final AnimationController _resetController;
  late final Animation<double> _resetAnimation;
  late final AnimationController _arrowController;
  final List<Animation<double>> _arrowAnims = [];

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resetAnimation = CurvedAnimation(parent: _resetController, curve: Curves.elasticOut);
    _resetAnimation.addListener(() {
      _posNotifier.value = _posNotifier.value * (1.0 - _resetAnimation.value);
    });

    _arrowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
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
          color: isTimerCritical ? Colors.red.withOpacity(0.08) : Colors.greenAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isTimerCritical ? Colors.red.withOpacity(0.3) : Colors.white24),
        ),
        child: Stack(
          children: [
            // Track Text
            Center(
              child: Opacity(
                opacity: 0.7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(3, (i) => AnimatedBuilder(
                      animation: _arrowAnims[i],
                      builder: (_, __) => Opacity(
                        opacity: _arrowAnims[i].value,
                        child: const Icon(Icons.chevron_right_rounded, color: Colors.greenAccent, size: 20),
                      ),
                    )),
                    const SizedBox(width: 8),
                    const Text('SWIPE TO PROCEED',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),
            // Swipeable Thumb
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (context, pos, _) {
                return Positioned(
                  left: 4 + pos, top: 4, bottom: 4,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_triggered) return;
                      _resetController.stop();
                      _posNotifier.value = (_posNotifier.value + details.delta.dx).clamp(0.0, maxSwipe);
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
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 44, height: 44,
                            child: CircularProgressIndicator(
                              value: timerProgress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(isTimerCritical ? Colors.red : Colors.greenAccent),
                              backgroundColor: Colors.black12,
                            ),
                          ),
                          Text('${widget.countdownSeconds}',
                            style: TextStyle(color: isTimerCritical ? Colors.red : Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
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
