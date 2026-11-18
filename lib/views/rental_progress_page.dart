import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img_lib;
import '../services/api_service.dart';

/// Step-by-step progress page for Rental IN & OUT submissions.
/// Shows real-time Dio upload progress with updated KB sent, total size, speed (KB/s), and ETA.
/// Matches the exact design and animation of [CaptureProgressPage].
class RentalProgressPage extends StatefulWidget {
  final bool isCheckOut;
  final String materialName;
  final String siteName;
  final String imagePath;
  final Map<String, dynamic> fields;

  const RentalProgressPage({
    Key? key,
    required this.isCheckOut,
    required this.materialName,
    required this.siteName,
    required this.imagePath,
    required this.fields,
  }) : super(key: key);

  @override
  State<RentalProgressPage> createState() => _RentalProgressPageState();
}

class _RentalProgressPageState extends State<RentalProgressPage>
    with TickerProviderStateMixin {
  int _currentStep = 1;
  final int _totalSteps = 3;
  double _progress = 0.0;
  String _status = 'Initializing...';
  String? _errorMessage;
  bool _isSuccess = false;
  int _sentBytes = 0;
  int _totalBytes = 0;
  DateTime? _startTime;
  String _speedText = '';
  String _etaText = '';
  Map<String, dynamic>? _responseResult;
  String _processedImagePath = '';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startWorkflow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    return ((bytes / math.pow(1024, i)).toStringAsFixed(decimals)) +
        ' ' +
        suffixes[i];
  }

  Future<String> _compressImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) return imagePath;

      final bytes = await imageFile.readAsBytes();

      // If already a small JPEG (under 350KB), use as is
      if (imagePath.endsWith('.jpg') && bytes.lengthInBytes < 350 * 1024) {
        return imagePath;
      }

      // Resize to 1280px width (matching attendance compression in capture_progress_page.dart)
      const int targetWidth = 1280;
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image srcImage = fi.image;

      final double w = srcImage.width.toDouble();
      final double h = srcImage.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
      canvas.drawImage(
        srcImage,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      final finalUiImg = await picture.toImage(w.toInt(), h.toInt());

      final pngData = await finalUiImg.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return imagePath;
      final pngBytes = pngData.buffer.asUint8List();

      final decoded = img_lib.decodeImage(pngBytes);
      if (decoded == null) return imagePath;

      // Encode as high-compression JPEG with quality 70 (exact attendance standard)
      final jpgBytes = img_lib.encodeJpg(decoded, quality: 70);

      final directory = imageFile.parent.path;
      final String newPath =
          '$directory/rental_opt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(newPath).writeAsBytes(jpgBytes);

      return newPath;
    } catch (e) {
      debugPrint('Error compressing rental image: $e');
      return imagePath;
    }
  }

  Future<void> _startWorkflow() async {
    try {
      // ── STEP 1: Processing Image & Compression ──
      setState(() {
        _currentStep = 1;
        _status = widget.isCheckOut
            ? 'Optimizing & compressing return photo...'
            : 'Optimizing & compressing arrival photo...';
        _progress = 0.2;
      });

      _processedImagePath = await _compressImage(widget.imagePath);
      final file = File(_processedImagePath);
      if (await file.exists()) {
        _totalBytes = await file.length();
      }

      final List<String> attachmentPaths = (widget.fields['attachment_paths'] is List)
          ? (widget.fields['attachment_paths'] as List).map((e) => e.toString()).toList()
          : const [];

      for (final attPath in attachmentPaths) {
        final attFile = File(attPath);
        if (await attFile.exists()) {
          _totalBytes += await attFile.length();
        }
      }

      await Future.delayed(const Duration(milliseconds: 600));

      // ── STEP 2: Real-time Dio Upload to Server ──
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _status = widget.isCheckOut
            ? (attachmentPaths.isNotEmpty
                ? 'Uploading return photo & attachments...'
                : 'Uploading return photo to server...')
            : 'Uploading rental photo to server...';
        _progress = 0.35;
      });

      _startTime = DateTime.now();

      Map<String, dynamic> result;
      if (widget.isCheckOut) {
        result = await ApiService.submitRentalOut(
          rentalId: widget.fields['rental_id']?.toString() ?? '',
          outUserId: widget.fields['out_user_id']?.toString() ?? '',
          outUserName: widget.fields['out_user_name']?.toString() ?? '',
          outDescription: widget.fields['out_description']?.toString() ?? '',
          outSiteId: widget.fields['out_site_id']?.toString() ?? '',
          outSiteName: widget.fields['out_site_name']?.toString() ?? '',
          outTime: widget.fields['out_time']?.toString() ?? '',
          imagePath: _processedImagePath,
          attachmentPaths: attachmentPaths,
          lat: widget.fields['lat']?.toString(),
          lng: widget.fields['lng']?.toString(),
          onProgress: (sent, total) {
            _handleUploadProgress(sent, total);
          },
        );
      } else {
        result = await ApiService.submitRentalIn(
          materialId: widget.fields['material_id']?.toString() ?? '',
          materialName: widget.fields['material_name']?.toString() ?? '',
          category: widget.fields['category']?.toString(),
          isNewMaterial: widget.fields['is_new_material'] == 'true' || widget.fields['is_new_material'] == true,
          userId: widget.fields['user_id']?.toString() ?? '',
          userName: widget.fields['user_name']?.toString() ?? '',
          description: widget.fields['description']?.toString() ?? '',
          inSiteId: widget.fields['in_site_id']?.toString() ?? '',
          inSiteName: widget.fields['in_site_name']?.toString() ?? '',
          inTime: widget.fields['in_time']?.toString() ?? '',
          imagePath: _processedImagePath,
          lat: widget.fields['lat']?.toString(),
          lng: widget.fields['lng']?.toString(),
          onProgress: (sent, total) {
            _handleUploadProgress(sent, total);
          },
        );
      }

      _responseResult = result;

      // ── STEP 3: Finalizing Record ──
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _status = 'Finalizing rental record...';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _status = widget.isCheckOut
              ? 'Material Returned Successfully!'
              : 'Material Checked In Successfully!';
        });
        await Future.delayed(const Duration(milliseconds: 900));
        Get.back(result: {
          'success': true,
          'isCheckOut': widget.isCheckOut,
          'data': _responseResult,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _status = 'Submission Failed';
        });
      }
    }
  }

  void _handleUploadProgress(int sent, int total) {
    if (total <= 0) return;
    final now = DateTime.now();
    _startTime ??= now;

    final elapsed = now.difference(_startTime!).inMilliseconds;
    if (elapsed > 100) {
      final speedBytesPerMs = sent / elapsed;
      final speedKBps = (speedBytesPerMs * 1000) / 1024;

      final remainingBytes = total - sent;
      final remainingMs = speedBytesPerMs > 0 ? remainingBytes / speedBytesPerMs : 0;
      final etaSec = (remainingMs / 1000).ceil();

      if (mounted) {
        setState(() {
          _speedText = speedKBps > 1024
              ? '${(speedKBps / 1024).toStringAsFixed(1)} MB/s'
              : '${speedKBps.toStringAsFixed(1)} KB/s';
          _etaText = etaSec > 60
              ? '${(etaSec / 60).floor()}m ${etaSec % 60}s'
              : '${etaSec}s remaining';
          _sentBytes = sent;
          _totalBytes = total;
          _progress = 0.35 + ((sent / total) * 0.60);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _sentBytes = sent;
          _totalBytes = total;
          _progress = 0.35 + ((sent / total) * 0.60);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress Circle with Pulsing Transition
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _errorMessage != null
                        ? const Color(0x1AE53935)
                        : (_isSuccess
                            ? const Color(0x1A16A34A)
                            : const Color(0x0D000000)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _errorMessage != null
                                ? const Color(0xFFE53935)
                                : (_isSuccess ? const Color(0xFF16A34A) : Colors.black),
                          ),
                          backgroundColor: const Color(0x0D000000),
                        ),
                      ),
                      Icon(
                        _errorMessage != null
                            ? Icons.error_outline
                            : (_isSuccess
                                ? Icons.check_circle_rounded
                                : Icons.cloud_upload_outlined),
                        size: 44,
                        color: _errorMessage != null
                            ? const Color(0xFFE53935)
                            : (_isSuccess ? const Color(0xFF16A34A) : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Step Counter Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'STEP $_currentStep OF $_totalSteps',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Equipment & Site Name Tag
              Text(
                '${widget.materialName}  •  ${widget.siteName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 8),

              // Status Text
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              // Real-time Upload Stats: Sent / Total (Percentage), Speed & ETA
              if (_currentStep == 2 && _totalBytes > 0) ...[
                const SizedBox(height: 14),
                Text(
                  '${_formatBytes(_sentBytes, 1)} / ${_formatBytes(_totalBytes, 1)} (${((_sentBytes / _totalBytes) * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_speedText.isNotEmpty)
                      Text(
                        _speedText,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_speedText.isNotEmpty && _etaText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    if (_etaText.isNotEmpty)
                      Text(
                        _etaText,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              if (_errorMessage == null)
                Text(
                  'Please do not close the app',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.45),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _startWorkflow(),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry Submission', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
                ),
              ],

              const SizedBox(height: 50),

              // Animated Step Indicators (Three Pill Bars)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalSteps, (index) {
                  final stepNum = index + 1;
                  final isActive = stepNum == _currentStep;
                  final isDone = stepNum < _currentStep || _isSuccess;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 10,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isDone
                          ? const Color(0xFF16A34A)
                          : (isActive ? Colors.black : Colors.black.withOpacity(0.1)),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
