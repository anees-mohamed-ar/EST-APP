import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class CaptureProgressPage extends StatefulWidget {
  final String imagePath;
  final String? lat;
  final String? lang;
  final String? siteName;
  final List<int>? userIds;
  final bool isBulk;

  const CaptureProgressPage({
    Key? key,
    required this.imagePath,
    this.lat,
    this.lang,
    this.siteName,
    this.userIds,
    this.isBulk = false,
  }) : super(key: key);

  @override
  _CaptureProgressPageState createState() => _CaptureProgressPageState();
}

class _CaptureProgressPageState extends State<CaptureProgressPage> with TickerProviderStateMixin {
  int _currentStep = 1;
  final int _totalSteps = 3;
  double _progress = 0.0;
  String _status = 'Initializing...';
  bool _isCheckOut = false;
  String? _errorMessage;
  bool _isSuccess = false;
  int _sentBytes = 0;
  int _totalBytes = 0;
  DateTime? _startTime;
  String _speedText = '';
  String _etaText = '';

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
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return ((bytes / math.pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
  }

  Future<void> _startWorkflow() async {
    try {
      // STEP 1: Processing Metadata
      setState(() {
        _currentStep = 1;
        _status = 'Applying location and timestamps...';
        _progress = 0.1;
      });

      final processedPath = await _addOverlay(widget.imagePath);
      await Future.delayed(const Duration(milliseconds: 800));

      // STEP 2: Uploading to Server
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _status = 'Uploading...';
        _progress = 0.4;
      });

      final success = await _performUpload(processedPath);
      
      if (!success) {
        throw Exception('Server upload failed');
      }

      // STEP 3: Finalizing
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _status = 'Finalizing...';
        _progress = 1.0;
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _status = 'Successfully recorded!';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        Get.back(result: {'success': true, 'isOut': _isCheckOut});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _status = 'Task Failed';
        });
      }
    }
  }

  Future<bool> _performUpload(String imagePath) async {
    final storage = ApiService.storage;
    final userData = storage.read('user');
    if (userData == null) return false;

    final now = DateTime.now();
    
    dynamic result;
    if (widget.isBulk && widget.userIds != null) {
      result = await ApiService.createBulkAttendance(
        userIds: widget.userIds!,
        time: DateFormat('HH:mm:ss').format(now),
        date: DateFormat('yyyy-MM-dd').format(now),
        imagePath: imagePath,
        lat: widget.lat,
        lang: widget.lang,
        site: widget.siteName,
        maxRetries: 8,
        onProgress: (sent, total) {
          if (total > 0) {
            final now = DateTime.now();
            _startTime ??= now;
            
            final elapsed = now.difference(_startTime!).inMilliseconds;
            if (elapsed > 100) { // update speed every 100ms
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
                  _progress = 0.4 + ((sent / total) * 0.55);
                });
              }
            } else {
               if (mounted) {
                 setState(() {
                   _sentBytes = sent;
                   _totalBytes = total;
                   _progress = 0.4 + ((sent / total) * 0.55);
                 });
               }
            }
          }
        },
      );
    } else {
      result = await ApiService.createAttendance(
        {
          'user_id': userData['id'],
          'time': DateFormat('HH:mm:ss').format(now),
          'date': DateFormat('yyyy-MM-dd').format(now),
        },
        imagePath,
        lat: widget.lat,
        lang: widget.lang,
        site: widget.siteName,
        maxRetries: 8,
        onProgress: (sent, total) {
          if (total > 0) {
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
                  _progress = 0.4 + ((sent / total) * 0.55);
                });
              }
            } else {
               if (mounted) {
                 setState(() {
                   _sentBytes = sent;
                   _totalBytes = total;
                   _progress = 0.4 + ((sent / total) * 0.55);
                 });
               }
            }
          }
        },
      );
    }
    
    if (result['success'] == true) {
      final msg = (result['message'] ?? '').toString().toLowerCase();
      _isCheckOut = msg.contains('check-out') || msg.contains('checkout');
      return true;
    }
    return false;
  }

  Future<String> _addOverlay(String imagePath) async {
    // Basic reuse of the logic from CameraPage (Simplified for the progress page context)
    final File imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    const int maxWidth = 1920;
    
    final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image srcImage = fi.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, srcImage.width.toDouble(), srcImage.height.toDouble()));
    
    canvas.drawImage(srcImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    
    final h = srcImage.height.toDouble();
    final w = srcImage.width.toDouble();
    
    final userData = ApiService.storage.read('user');
    final username = userData != null ? userData['username'] : 'N/A';
    final siteName = widget.siteName != null && widget.siteName!.isNotEmpty ? widget.siteName : 'N/A';

    final watermarkText = 
      'MEPL-TRACK | ${DateFormat('MMM d, yyyy  hh:mm a').format(DateTime.now())} | LOC: ${widget.lat ?? "N/A"}, ${widget.lang ?? "N/A"}\n'
      'SITE: $siteName\n'
      'Captured by: $username';

    final tp = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: TextStyle(
          color: Colors.white, 
          fontSize: w * 0.018, 
          fontWeight: FontWeight.bold,
          height: 1.2
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout(maxWidth: w - 40);
    
    // Render the watermark background rectangle based on text height
    const padding = 20.0;
    final finalBarH = tp.height + padding * 2;
    canvas.drawRect(
      Rect.fromLTWH(0, h - finalBarH, w, finalBarH), 
      Paint()..color = Colors.black.withOpacity(0.5)
    );
    
    tp.paint(canvas, Offset(20, h - finalBarH + padding));

    final picture = recorder.endRecording();
    final img = await picture.toImage(srcImage.width, srcImage.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    
    final directory = await File(imagePath).parent.path;
    final String newPath = '$directory/processed_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(newPath).writeAsBytes(buffer);
    return newPath;
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
              // Progress Circle
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _errorMessage != null ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.05),
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
                            _errorMessage != null ? Colors.red : Colors.black,
                          ),
                          backgroundColor: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      Icon(
                        _errorMessage != null 
                          ? Icons.error_outline 
                          : (_isSuccess ? Icons.check_circle : Icons.cloud_upload_outlined),
                        size: 40,
                        color: _errorMessage != null ? Colors.red : Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Step Counter
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
              const SizedBox(height: 16),
              
              // Status Text
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (_currentStep == 2 && _totalBytes > 0) ...[
                 const SizedBox(height: 12),
                 Text(
                   '${_formatBytes(_sentBytes, 1)} / ${_formatBytes(_totalBytes, 1)} (${((_sentBytes/_totalBytes)*100).toStringAsFixed(1)}%)',
                   style: const TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.w600,
                     color: Colors.black54,
                     fontFamily: 'monospace'
                   ),
                 ),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text(
                       _speedText,
                       style: TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.bold),
                     ),
                     Container(
                       margin: const EdgeInsets.symmetric(horizontal: 10),
                       width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.1)),
                     ),
                     Text(
                       _etaText,
                       style: TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.bold),
                     ),
                   ],
                 )
              ],
              const SizedBox(height: 8),
              
              if (_errorMessage == null)
                Text(
                  'Please do not close the app',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.5),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                
              const SizedBox(height: 60),
              
              // Animated Step Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalSteps, (index) {
                  final stepNum = index + 1;
                  final isActive = _currentStep == stepNum;
                  final isDone = _currentStep > stepNum;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    width: isActive ? 40 : 20,
                    decoration: BoxDecoration(
                      color: isDone ? Colors.black : (isActive ? Colors.black : Colors.black12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => Get.back(),
                    child: const Text('GO BACK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
