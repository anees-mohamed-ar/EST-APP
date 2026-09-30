import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';
import '../services/location_service.dart';
import 'employee_selection_page.dart';
import 'camera_page.dart';
import 'settings_page.dart';
import 'daily_attendance_page.dart';
import 'review_page.dart';
import '../widgets/electric_refresh_indicator.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import 'payroll_download_page.dart';
import '../constants/app_config.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final storage = GetStorage();
  final LocationService _locationService = LocationService();
  bool _isLocationEnabled = true;
  StreamSubscription? _locationSub;

  List<dynamic> todaysRecords = [];
  bool isLoadingAttendance = true;

  bool _isNavigatingToCamera = false;

  // Monthly attendance data
  Map<String, dynamic>? monthlyData;
  bool isLoadingMonthly = true;

  // Monthly performance data
  Map<String, dynamic>? performanceData;
  bool isLoadingPerformance = true;

  // Sites data
  List<dynamic> sites = [];
  bool isLoadingSites = true;

  // Approval badge counts
  int _pendingLeaveCount = 0;
  int _pendingPermissionCount = 0;
  bool _isLoadingApprovalCounts = true;

  // Upload progress: null = idle, 0.0–1.0 = uploading
  double? _uploadProgress;
  String _uploadStatus = 'Uploading photo...';

  // Live clock
  DateTime _now = DateTime.now();
  late final Timer _clockTimer;
  late final Timer _carouselTimer;
  Timer? _vibrationTimer;

  // Time shimmer animation
  late final AnimationController _timeShimmerController;
  late final Animation<double> _timeShimmerAnimation;

  // Pulse animation for action button
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Sophisticated monochrome palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _darkGray = Color(0xFF616161);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);

  // Animation for streak fire
  late final AnimationController _streakFlyController;
  late final Animation<double> _streakFlyAnimation;
  bool _isStreakFlying = false;
  final GlobalKey _streakTargetKey = GlobalKey();

  // Pulse animation for streak pill (Breathing effect)
  late final AnimationController _fireController;

  // Carousel controller for streak cards
  final PageController _streakPageController = PageController();
  int _currentStreakPage = 0;
  int _displayedStreakCount = 0;
  final ScrollController _scrollController = ScrollController();

  // Accent colors kept subtle
  static const Color _softGreen = Color(0xFF29A331);
  static const Color _softRed = Color(0xFFD32F2F);

  // Birthday Celebration
  late ConfettiController _confettiController;
  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;
  List<dynamic> _todayBirthdays = [];
  bool _hasShownBirthdayWish = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService.init();
    _checkInitialLocation();
    _locationSub = _locationService.onServiceStatusChanged.listen((enabled) {
      if (mounted) setState(() => _isLocationEnabled = enabled);
    });

    _loadTodayAttendance();
    _loadMonthlyAttendance();
    _loadMonthlyPerformance();
    _loadSites();
    _loadApprovalCounts();
    _loadBirthdays();
    _loadUserProfile();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    _leftConfettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    _rightConfettiController =
        ConfettiController(duration: const Duration(seconds: 10));

    // Check for user's own birthday after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      _checkUserBirthday();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _timeShimmerController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();

    _timeShimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _timeShimmerController, curve: Curves.linear),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _streakFlyController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );
    _streakFlyAnimation = CurvedAnimation(
      parent: _streakFlyController,
      curve: Curves.easeInOutQuart,
    );

    _fireController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _streakFlyController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _vibrationTimer?.cancel();
        _vibrationTimer = null;
        HapticFeedback.vibrate(); // Strong buzz upon landing

        setState(() {
          _isStreakFlying = false;
          // Update the count only after landing
          if (performanceData?['streak'] != null) {
            _displayedStreakCount =
                (performanceData!['streak']['current_streak'] ?? 0);
          }
        });
        _streakFlyController.reset();
      }
    });

    // Auto-swipe for streak carousel
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_streakPageController.hasClients) {
        int nextPage = (_currentStreakPage + 1) % 2;
        _streakPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📍 App resumed: Re-checking location status...');
      _checkInitialLocation();
    }
  }

  Future<void> _checkInitialLocation() async {
    final enabled = await _locationService.isLocationEnabled();
    if (mounted) setState(() => _isLocationEnabled = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSub?.cancel();
    _clockTimer.cancel();
    _carouselTimer.cancel();
    _timeShimmerController.dispose();
    _pulseController.dispose();
    _streakPageController.dispose();
    _streakFlyController.dispose();
    _fireController.dispose();
    _scrollController.dispose();
    _vibrationTimer?.cancel();
    _confettiController.dispose();
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
  }

  Future<void> _loadBirthdays() async {
    try {
      final birthdays = await ApiService.getBirthdays();
      if (mounted) {
        setState(() {
          _todayBirthdays = birthdays;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading birthdays: $e');
    }
  }

  void _checkUserBirthday() {
    final user = storage.read('user');
    debugPrint('🎂 Checking birthday status: is_birthday=${user?['is_birthday']}, hasShown=$_hasShownBirthdayWish');
    if (user != null && user['is_birthday'] == true && !_hasShownBirthdayWish) {
      _hasShownBirthdayWish = true;
      _showBirthdayCelebration(
        user['full_name'] ?? user['employee_name'],
        user['pfp'] as String?,
      );
    }
  }

  void _showBirthdayCelebration(String name, String? pfp) {
    final random = math.Random();
    
    // Significantly increased, randomized delays for side bursts to create distinct "rhythms"
    Future.delayed(Duration(milliseconds: (2000 + random.nextInt(2000)).toInt()), () {
      if (mounted) _leftConfettiController.play();
    });
    Future.delayed(Duration(milliseconds: (6000 + random.nextInt(4000)).toInt()), () {
      if (mounted) _rightConfettiController.play();
    });

    Get.bottomSheet(
      WillPopScope(
        onWillPop: () async {
          _leftConfettiController.stop();
          _rightConfettiController.stop();
          return true;
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bottom Sheet Content - FIRST child so it's behind the confetti
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _pureWhite,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _lightGray,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Celebration Header: Profile Pic OR Lottie
                      if (pfp != null && pfp.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60, // Slightly larger since it's the main focus
                            backgroundColor: _offWhite,
                            backgroundImage: CachedNetworkImageProvider(
                              '${ApiService.baseUrl}$pfp',
                            ),
                          ),
                        )
                      else
                        Lottie.network(
                          'https://lottie.host/8254c2d3-176c-4b6a-9b6f-856758416d82/m6vLzS8fS0.json',
                          height: 180,
                          repeat: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.celebration, size: 100, color: Colors.amber),
                        ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'HAPPY BIRTHDAY!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _charcoal,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _mediumGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Wishing you a fantastic day filled with joy, success, and wonderful surprises!',
                        style: TextStyle(
                          fontSize: 14,
                          color: _darkGray,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _leftConfettiController.stop();
                            _rightConfettiController.stop();
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _charcoal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'THANK YOU',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Left Side Burst - AFTER content so it's on top
              Positioned(
                left: -30,
                top: MediaQuery.of(context).size.height * 0.35,
                child: ConfettiWidget(
                  confettiController: _leftConfettiController,
                  blastDirection: 0, // Burst to the right
                  blastDirectionality: BlastDirectionality.directional,
                  emissionFrequency: 0.01,
                  numberOfParticles: 15,
                  maxBlastForce: 25,
                  minBlastForce: 15,
                  gravity: 0.3,
                  shouldLoop: true,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    Colors.cyan
                  ],
                ),
              ),
              // Right Side Burst - AFTER content so it's on top
              Positioned(
                right: -30,
                top: MediaQuery.of(context).size.height * 0.45,
                child: ConfettiWidget(
                  confettiController: _rightConfettiController,
                  blastDirection: 3.14, // Burst to the left (pi)
                  blastDirectionality: BlastDirectionality.directional,
                  emissionFrequency: 0.01,
                  numberOfParticles: 15,
                  maxBlastForce: 25,
                  minBlastForce: 15,
                  gravity: 0.3,
                  shouldLoop: true,
                  colors: const [
                    Colors.purple,
                    Colors.orange,
                    Colors.cyan,
                    Colors.pink,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      enterBottomSheetDuration: const Duration(milliseconds: 600),
      exitBottomSheetDuration: const Duration(milliseconds: 1000), // Smooth and slow close
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = storage.read('user');
      if (userData == null) return;

      final updatedProfile = await ApiService.getUserProfile(userData['id']);
      if (updatedProfile != null) {
        // Merge with existing storage data to preserve local session fields if any
        final Map<String, dynamic> mergedData = Map<String, dynamic>.from(
          userData,
        );
        mergedData.addAll(updatedProfile);

        await storage.write('user', mergedData);
        if (mounted) {
          setState(() {}); // Trigger rebuild to update drawer
          _checkUserBirthday(); // Check again after profile refresh
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user profile: $e');
    }
  }

  Future<void> _loadTodayAttendance() async {
    setState(() => isLoadingAttendance = true);
    try {
      final userData = storage.read('user');
      if (userData == null) {
        storage.remove('user');
        Get.offAllNamed('/login');
        return;
      }
      final records = await ApiService.getTodaysAttendance(userData['id']);
      if (mounted)
        setState(() {
          todaysRecords = records;
          isLoadingAttendance = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoadingAttendance = false);
    }
  }

  Future<void> _loadMonthlyAttendance() async {
    setState(() => isLoadingMonthly = true);
    try {
      final userData = storage.read('user');
      if (userData == null) {
        storage.remove('user');
        Get.offAllNamed('/login');
        return;
      }
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final data = await ApiService.getMonthlySummary(
        userData['id'],
        yearMonth: yearMonth,
      );
      if (mounted)
        setState(() {
          monthlyData = data;
          isLoadingMonthly = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoadingMonthly = false);
    }
  }

  Future<void> _loadMonthlyPerformance({bool updateUI = true}) async {
    setState(() => isLoadingPerformance = true);
    try {
      final userData = storage.read('user');
      if (userData == null) return;
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final data = await ApiService.getMonthlyPerformance(
        userData['id'],
        yearMonth: yearMonth,
      );
      if (mounted) {
        setState(() {
          performanceData = data;
          isLoadingPerformance = false;
          if (updateUI && data['streak'] != null) {
            _displayedStreakCount = (data['streak']['current_streak'] ?? 0);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingPerformance = false);
    }
  }

  Future<void> _loadSites() async {
    setState(() => isLoadingSites = true);
    try {
      final data = await ApiService.getSites();
      if (mounted) {
        setState(() {
          sites = data;
          isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingSites = false);
    }
  }

  Future<void> _loadApprovalCounts() async {
    setState(() => _isLoadingApprovalCounts = true);
    try {
      final user = storage.read('user');
      if (user == null) {
        if (mounted) setState(() => _isLoadingApprovalCounts = false);
        return;
      }

      final acceptAccess = user['accept_access'] as int?;
      final userId = user['id'] as int?;
      final role = user['role'] as String?;

      // Only load counts for users with accept_access
      if (acceptAccess != 1) {
        if (mounted) setState(() => _isLoadingApprovalCounts = false);
        return;
      }

      final effectiveApproverId = userId;

      final [leaves, permissions] = await Future.wait([
        ApiService.getAdminLeaveRequests(
          status: 'pending',
          approverId: effectiveApproverId,
          limit: 100,
        ),
        ApiService.getAdminPermissionRequests(
          status: 'pending',
          approverId: effectiveApproverId,
        ),
      ]);

      print(
        'DEBUG HOME: role=$role, userId=$userId, effectiveApproverId=$effectiveApproverId',
      );
      print(
        'DEBUG HOME: Pending leaves: ${leaves.length}, Pending permissions: ${permissions.length}',
      );

      if (mounted) {
        setState(() {
          _pendingLeaveCount = leaves.length;
          _pendingPermissionCount = permissions.length;
          _isLoadingApprovalCounts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingApprovalCounts = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: _charcoal,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: _mediumGray,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: _charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    color: _softRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
      'Logout',
      'Are you sure you want to logout?',
    );
    if (confirmed) {
      storage.remove('user');
      Get.offAllNamed('/login');
    }
  }

  Future<void> _changePfp() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _charcoal.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                color: _charcoal,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _charcoal,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a photo to update your profile',
              style: TextStyle(
                fontSize: 14,
                color: _mediumGray,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (storage.read('user')?['pfp'] != null &&
                    storage.read('user')!['pfp'].toString().isNotEmpty)
                  _buildPickerOption(
                    icon: Icons.visibility_outlined,
                    label: 'View Photo',
                    onTap: () {
                      final pfp = storage.read('user')?['pfp'];
                      Navigator.pop(ctx);
                      if (pfp != null && pfp.toString().isNotEmpty) {
                        Get.to(
                          () => Scaffold(
                            backgroundColor: Colors.black,
                            appBar: AppBar(
                              backgroundColor: Colors.black,
                              iconTheme: const IconThemeData(color: Colors.white),
                              title: const Text(
                                'Profile Picture',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            body: Center(
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: '${ApiService.baseUrl}$pfp',
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          transition: Transition.fadeIn,
                        );
                      }
                    },
                  ),
                _buildPickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () async => Navigator.pop(
                    ctx,
                    await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    ),
                  ),
                ),
                _buildPickerOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () async => Navigator.pop(
                    ctx,
                    await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    try {
      final userData = storage.read('user');
      if (userData == null) return;

      setState(() {
        _uploadProgress = 0.0;
        _uploadStatus = 'Uploading profile picture...';
      });

      final result = await ApiService.updateUserProfile(
        userId: userData['id'],
        username: userData['username'],
        role: userData['role'],
        imagePath: image.path,
        onProgress: (sent, total) =>
            setState(() => _uploadProgress = total > 0 ? sent / total : 0),
      );

      final allUsers = await ApiService.getUsers();
      final updatedUser = allUsers.firstWhere(
        (u) => u['id'] == userData['id'],
        orElse: () => null,
      );
      if (updatedUser != null) {
        storage.write('user', updatedUser);
        setState(() {});
      }

      _showMessage('Profile picture updated', isSuccess: true);
    } catch (e) {
      _showMessage('Failed to update profile', isSuccess: false);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  void _previewPfp() {
    final userData = storage.read('user');
    final pfp = userData?['pfp'];

    if (pfp == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Full screen backdrop
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.8),
                ),
              ),
              // Image container
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: CachedNetworkImage(
                        imageUrl: '${ApiService.baseUrl}$pfp',
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          width: 300,
                          height: 300,
                          color: _offWhite,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 300,
                          height: 300,
                          color: _offWhite,
                          child: const Icon(
                            Icons.person_outline,
                            color: _mediumGray,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              // Preview hint
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pinch to zoom • Tap to close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _offWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _lightGray, width: 1),
            ),
            child: Icon(icon, color: _charcoal, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _charcoal,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, {bool isSuccess = true}) {
    Get.snackbar(
      isSuccess ? 'Success' : 'Error',
      msg,
      backgroundColor: _pureWhite,
      colorText: _charcoal,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      borderColor: _lightGray,
      borderWidth: 1,
      icon: Icon(
        isSuccess ? Icons.check_circle_outline : Icons.error_outline,
        color: isSuccess ? _softGreen : _softRed,
      ),
      duration: const Duration(seconds: 3),
    );
  }

  Widget _buildDrawer(dynamic userData) {
    final pfp = userData['pfp'] as String?;
    final employeeName = (userData['employee_name'] ?? userData['full_name'] ?? userData['name'] ?? userData['username'] ?? 'User').toString().trim();
    final username = userData['username']?.toString() ?? 'User';
    final initial = employeeName.isNotEmpty ? employeeName[0].toUpperCase() : (username.isNotEmpty ? username[0].toUpperCase() : '?');

    return Drawer(
      backgroundColor: _pureWhite,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            color: _offWhite,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _changePfp,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _charcoal.withOpacity(0.08),
                          border: Border.all(
                            color: _charcoal.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: pfp != null && pfp.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: '${ApiService.baseUrl}$pfp',
                                fit: BoxFit.cover,
                                memCacheWidth: 240,
                                memCacheHeight: 240,
                                placeholder: (_, __) => Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: _charcoal,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                    color: _charcoal,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _pureWhite,
                            shape: BoxShape.circle,
                            border: Border.all(color: _lightGray, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: _pureBlack.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: _charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _charcoal,
                  ),
                ),
                if ((userData['full_name'] ?? userData['employee_name']) !=
                    null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      (userData['full_name'] ?? userData['employee_name'])
                          .toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _mediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  userData['role']?.toString() ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 14,
                    color: _mediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: _charcoal,
                    size: 24,
                  ),
                  title: const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.toNamed('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.beach_access_outlined,
                    color: _charcoal,
                    size: 24,
                  ),
                  title: const Text(
                    'Holidays',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.toNamed('/holidays');
                  },
                ),
                //TODO: Re-enable when leave feature is ready
                ListTile(
                  leading: const Icon(
                    Icons.event_note_outlined,
                    color: _charcoal,
                    size: 24,
                  ),
                  title: const Text(
                    'My Leave',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.toNamed('/leave');
                  },
                ),
                if (userData['is_ot_eligible'] == 0)
                  ListTile(
                    leading: const Icon(
                      Icons.timer_outlined,
                      color: _charcoal,
                      size: 24,
                    ),
                    title: const Text(
                      'Request Permission',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      Get.toNamed('/permission');
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.leaderboard_outlined,
                    color: _charcoal,
                    size: 24,
                  ),
                  title: const Text(
                    'OT Leaderboard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.toNamed('/leaderboard');
                  },
                ),
                if (userData['driver_access'] == 'yes')
                  ListTile(
                    leading: const Icon(
                      Icons.directions_car_outlined,
                      color: _charcoal,
                      size: 24,
                    ),
                    title: const Text(
                      'Vehicle & Fuel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      Get.toNamed('/vehicle');
                    },
                  ),
                if (userData['accept_access'] == 1)
                  ListTile(
                    leading: const Icon(
                      Icons.fact_check_outlined,
                      color: _charcoal,
                      size: 24,
                    ),
                    title: const Text(
                      'Approvals',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    trailing: _isLoadingApprovalCounts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _charcoal,
                            ),
                          )
                        : (_pendingLeaveCount + _pendingPermissionCount) > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _softRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingLeaveCount + _pendingPermissionCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                    onTap: () async {
                      Get.back();
                      await Get.to(() => const ReviewPage());
                      if (mounted) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        await _loadApprovalCounts();
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: _charcoal,
                    size: 24,
                  ),
                  title: const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.to(() => SettingsPage());
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: _softRed,
                    size: 24,
                  ),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _softRed,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    _logout();
                  },
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Divider(color: _lightGray, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Developed by iMatrix Technologies Pvt Ltd © ${DateTime.now().year}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _mediumGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version ${AppConfig.appVersion}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: _mediumGray.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = storage.read('user');

    if (userData == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Get.offAllNamed('/login'),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = _now;
    final greeting = _getGreeting(now.hour);
    final name = (userData['username'] ?? 'User').toString();
    final role = (userData['role'] ?? 'Single User').toString();
    final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

    // Check if there is an active shift (Check-In exists without a Check-Out)
    // This handles both today's check-in and an overnight check-in from yesterday.
    final hasActiveShift = todaysRecords.length == 1;

    // Check if today's specific shift is complete
    final hasCheckedInToday = todaysRecords.any(
      (r) => r['date'] == todayDateStr,
    );
    final hasCheckedOutToday =
        todaysRecords.where((r) => r['date'] == todayDateStr).length >= 2;

    // For the button toggle logic:
    // 1. If today is complete, show "Shift Recorded"
    // 2. If there's an active shift (today or overnight), show "Check Out"
    // 3. Else, show "Check In"
    final hasCheckedIn = hasActiveShift;
    final hasCheckedOut = hasCheckedOutToday;

    // Status card specifically shows the current records (even if overnight)
    final cardHasCheckedIn = todaysRecords.isNotEmpty;
    final cardHasCheckedOut = todaysRecords.length >= 2;
    final firstIn = cardHasCheckedIn ? todaysRecords.first['time'] : null;
    final lastOut = cardHasCheckedOut ? todaysRecords.last['time'] : null;
    final firstInDate = cardHasCheckedIn ? todaysRecords.first['date'] : null;
    final lastOutDate = cardHasCheckedOut ? todaysRecords.last['date'] : null;

    return WillPopScope(
      onWillPop: () async {
        final confirmed = await _showConfirmationDialog(
          'Exit App',
          'Are you sure you want to exit the app?',
        );
        return confirmed;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _offWhite,
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: MediaQuery.of(context).size.width,
        drawer: (userData['is_active'] == 0 || userData['is_active'] == false || userData['is_active'] == '0')
            ? null
            : _buildDrawer(userData),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final isActiveUser = userData['is_active'] != 0 &&
                userData['is_active'] != false &&
                userData['is_active'] != '0';
            if (isActiveUser && (details.primaryVelocity ?? 0) > 200) {
              if (_scaffoldKey.currentState != null && !_scaffoldKey.currentState!.isDrawerOpen) {
                _scaffoldKey.currentState!.openDrawer();
              }
            }
          },
          child: Stack(
            children: [
              ElectricRefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadUserProfile(),
                    _loadTodayAttendance(),
                    _loadMonthlyAttendance(),
                    _loadMonthlyPerformance(),
                    _loadSites(),
                    _loadApprovalCounts(),
                  ]);
                },
                color: _charcoal,
                backgroundColor: _pureWhite,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 0,
                      floating: true,
                      pinned: true,
                      backgroundColor: _pureWhite,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      iconTheme: const IconThemeData(color: _charcoal),
                      leading: Builder(
                        builder: (context) {
                          final isActiveUser = userData['is_active'] != 0 &&
                              userData['is_active'] != false &&
                              userData['is_active'] != '0';

                          if (!isActiveUser) {
                            return const SizedBox.shrink();
                          }

                          final totalApprovals =
                              _pendingLeaveCount + _pendingPermissionCount;
                          final acceptAccess =
                              userData['accept_access'] == 1 ||
                              userData['accept_access'] == true;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu_rounded),
                                color: _charcoal,
                                onPressed: () {
                                  if (_scaffoldKey.currentState != null) {
                                    _scaffoldKey.currentState!.openDrawer();
                                  } else {
                                    Scaffold.of(context).openDrawer();
                                  }
                                },
                              ),
                              if (acceptAccess &&
                                  !_isLoadingApprovalCounts &&
                                totalApprovals > 0)
                              Positioned(
                                right: 6,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _softRed,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$totalApprovals',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    title: const Text(
                      'MEPL-Track',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: _charcoal,
                        letterSpacing: -0.5,
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: _pureWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _lightGray, width: 1),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.logout_outlined,
                            size: 20,
                            color: _charcoal,
                          ),
                          onPressed: () => _logout(),
                        ),
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Builder(
                        builder: (context) {
                          final isActiveUser = userData['is_active'] == 1 ||
                              userData['is_active'] == true ||
                              userData['is_active'] == '1' ||
                              userData['is_active'] == null;

                          if (!isActiveUser) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfileCard(greeting, name, role, now),
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: _pureWhite,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withOpacity(0.06),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFCA5A5),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.lock_person_outlined,
                                          color: Color(0xFFDC2626),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Account Inactive',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _charcoal,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You are currently not allowed to record attendance or access organization services.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _mediumGray,
                                          fontWeight: FontWeight.w400,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 18,
                                              color: Color(0xFFD97706),
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Please contact your Administrator or HR department to activate your account.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF92400E),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileCard(greeting, name, role, now),
                              const SizedBox(height: 24),
                              _buildStatusCard(
                                cardHasCheckedIn,
                                cardHasCheckedOut,
                                firstIn,
                                lastOut,
                                firstInDate,
                                lastOutDate,
                              ),
                              const SizedBox(height: 24),

                              _buildSectionHeader('QUICK ACTIONS'),
                              const SizedBox(height: 16),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildCheckInButton(
                                      hasCheckedIn,
                                      hasCheckedOut,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if ((userData['role']?.toString().toLowerCase() ==
                                      'admin'))
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.dashboard_outlined,
                                        label: 'Dashboard',
                                        sublabel: 'View overview',
                                        onTap: () =>
                                            Get.toNamed('/admin-dashboard'),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.calendar_today_outlined,
                                        label: 'History',
                                        sublabel: 'View records',
                                        onTap: () =>
                                            Get.toNamed('/daily-attendance'),
                                      ),
                                    ),
                                ],
                              ),

                              if ((userData['role']?.toString().toLowerCase() ==
                                  'admin')) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.admin_panel_settings_outlined,
                                        label: 'Admin Panel',
                                        sublabel: 'Manage attendance',
                                        onTap: () =>
                                            Get.toNamed('/admin-attendance'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.directions_car_outlined,
                                        label: 'Vehicle Reports',
                                        sublabel: 'Trips & Fuel logs',
                                        onTap: () => Get.toNamed('/fleet-reports'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.beach_access_outlined,
                                      label: 'Leaves',
                                      sublabel: 'Request Day off',
                                      onTap: () => Get.toNamed('/leave'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (userData['is_ot_eligible'] == 0)
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.timer_outlined,
                                        label: 'Permissions',
                                        sublabel: 'Request 3hr permission',
                                        onTap: () => Get.toNamed('/permission'),
                                      ),
                                    )
                                  else
                                    Expanded(child: Container()),
                                ],
                              ),

                              const SizedBox(height: 24),

                              _buildMonthlySummaryCard(),

                              // ── My Payroll download card (all users & admin) ─────
                              const SizedBox(height: 12),
                              _buildPayrollDownloadCard(userData),

                              const SizedBox(height: 24),

                              _buildSectionHeader('MONTHLY PERFORMANCE'),
                              const SizedBox(height: 16),

                              isLoadingPerformance
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40),
                                        child: CircularProgressIndicator(
                                          color: _charcoal,
                                        ),
                                      ),
                                    )
                                  : _buildMonthlyInsights(),

                              const SizedBox(height: 32),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildFlyingFire(),

            if (!_isLocationEnabled)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildLocationWarningBanner(),
              ),

            if (_uploadProgress != null)
              _buildUploadOverlay(_uploadProgress!, _uploadStatus),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMonthlySummaryCard() {
    final userData = storage.read('user');
    final role = (userData?['role'] ?? '').toString().toLowerCase();
    final isAdmin = role == 'admin';

    // For admin users, show overall summary card
    if (isAdmin) {
      return GestureDetector(
        onTap: () => Get.toNamed('/admin-monthly-summary'),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lightGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: _pureBlack.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _offWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _lightGray, width: 1),
                ),
                child: Icon(
                  Icons.bar_chart_outlined,
                  size: 24,
                  color: _charcoal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View team performance overview',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mediumGray,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: _mediumGray),
            ],
          ),
        ),
      );
    }

    // Check if monthlyData is available
    if (monthlyData == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final attendance = monthlyData!['attendance'] as Map<String, dynamic>?;
    final formatted = monthlyData!['formatted'] as Map<String, dynamic>?;

    // Handle case where attendance or formatted might be null
    if (attendance == null || formatted == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No monthly data available',
            style: TextStyle(fontSize: 14, color: _mediumGray),
          ),
        ),
      );
    }
    double _safeNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final totalWorked = formatted['total_regular'] ?? '0h 0m';
    final totalOT = formatted['total_overtime'] ?? '0h 0m';
    final completeDays = _safeNum(attendance['total_complete_days']);
    final presentDays = _safeNum(attendance['total_days_present']);

    // Check if there's actually no data (no complete days, no regular time, no OT, and no check-ins)
    final hasNoData =
        totalWorked == '0h 0m' &&
        totalOT == '0h 0m' &&
        completeDays == 0 &&
        presentDays == 0;

    if (hasNoData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _mediumGray.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 24,
                color: _mediumGray,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Attendance This Month',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check in to start tracking your attendance',
              style: TextStyle(fontSize: 13, color: _mediumGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Monthly summary will appear here once you have records',
              style: TextStyle(
                fontSize: 11,
                color: _mediumGray.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final userData = storage.read('user');
        final role = (userData?['role'] ?? '').toString().toLowerCase();
        final isAdmin = role == 'admin';

        if (isAdmin) {
          Get.toNamed('/admin-monthly-summary');
        } else {
          Get.toNamed('/monthly-summary');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _charcoal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _offWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _lightGray, width: 1),
                  ),
                  child: Text(
                    'Current Month',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _mediumGray,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: _softGreen,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Regular Hours',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _mediumGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalWorked,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: _lightGray),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: _softRed,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Overtime',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _mediumGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalOT,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _offWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _lightGray, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: _softGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completeDays complete days',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollDownloadCard(Map<String, dynamic> userData) {
    return GestureDetector(
      onTap: () {
        Get.toNamed('/payroll', arguments: {
          'userId': userData['id'] as int,
          'displayName': userData['full_name'] ?? userData['username'] ?? '',
          'username': userData['username'] ?? '',
          'isAdminView': false,
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _pureBlack,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Payroll',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Download last 3 months as PDF',
                      style: TextStyle(fontSize: 11, color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _mediumGray,
            letterSpacing: 0.8,
          ),
        ),
        if (title == "TODAY'S TIMELINE" && todaysRecords.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lightGray, width: 1),
            ),
            child: Text(
              '${todaysRecords.length} entries',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _mediumGray,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationWarningBanner() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _softRed.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _pureBlack.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: _softRed.withOpacity(0.1), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _softRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: _softRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Service is Off',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _charcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Attendance features are locked.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _mediumGray.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await _locationService.requestService();
                  bool actuallyEnabled = await _locationService
                      .isLocationEnabled();
                  if (mounted) {
                    setState(() => _isLocationEnabled = actuallyEnabled);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _softRed,
                  foregroundColor: _pureWhite,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ENABLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    String greeting,
    String name,
    String role,
    DateTime now,
  ) {
    final userData = storage.read('user');
    final pfp = userData?['pfp'];
    final employeeName = (userData?['employee_name'] ?? userData?['full_name'] ?? name).toString().trim();
    final initial = employeeName.isNotEmpty ? employeeName[0].toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final isActive = userData?['is_active'] == 1 ||
        userData?['is_active'] == true ||
        userData?['is_active'] == '1' ||
        userData?['is_active'] == null;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _timeShimmerAnimation,
        builder: (context, child) {
          final animVal = _timeShimmerAnimation.value;

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isActive
                    ? _lightGray
                    : Color.lerp(
                        const Color(0xFFFCA5A5),
                        const Color(0xFFEF4444),
                        (animVal.abs() * 2) % 1.0,
                      )!,
                width: isActive ? 1 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? _pureBlack.withOpacity(0.02)
                      : const Color(0xFFEF4444).withOpacity(0.08 + (0.06 * animVal.abs())),
                  blurRadius: isActive ? 20 : 28,
                  spreadRadius: isActive ? 0 : 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting and Greeting Card logic
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 13,
                    color: _mediumGray,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),

                // Profile Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _changePfp,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: pfp != null ? _previewPfp : null,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _offWhite,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _lightGray,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: pfp != null
                                    ? CachedNetworkImage(
                                        imageUrl: '${ApiService.baseUrl}$pfp',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: _offWhite,
                                              child: Icon(
                                                Icons.person_outline,
                                                color: _mediumGray,
                                                size: 32,
                                              ),
                                            ),
                                        errorWidget: (_, __, ___) => Icon(
                                          Icons.person_outline,
                                          color: _mediumGray,
                                          size: 32,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: _charcoal,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _pureWhite,
                                shape: BoxShape.circle,
                                border: Border.all(color: _lightGray, width: 1),
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: _charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: _charcoal,
                            ),
                          ),
                          if ((userData?['full_name'] ??
                                  userData?['employee_name']) !=
                              null)
                            Text(
                              (userData?['full_name'] ??
                                      userData?['employee_name'])
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: _mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _offWhite,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _lightGray, width: 1),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _mediumGray,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedBuilder(
                                animation: _timeShimmerAnimation,
                                builder: (context, _) {
                                  final isActive = userData?['is_active'] == 1 ||
                                      userData?['is_active'] == true ||
                                      userData?['is_active'] == '1' ||
                                      userData?['is_active'] == null; // default to active if unset

                                  final badgeBg = isActive
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFEF2F2);
                                  final badgeBorder = isActive
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFECACA);
                                  final badgeDot = isActive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444);
                                  final badgeText = isActive
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB91C1C);

                                  // Calculate pulsing wave value (between 0.0 and 1.0)
                                  final pulseValue = (_timeShimmerAnimation.value.abs() * 2) % 1.0;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: badgeBorder, width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (isActive)
                                              Transform.scale(
                                                scale: 1.0 + (pulseValue * 0.8),
                                                child: Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: badgeDot.withOpacity(0.4 * (1.0 - pulseValue)),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: badgeDot,
                                                shape: BoxShape.circle,
                                                boxShadow: isActive
                                                    ? [
                                                        BoxShadow(
                                                          color: badgeDot.withOpacity(0.6),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        )
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: badgeText,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Date and Time Footer (Strictly preserved)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(now),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _charcoal,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(now),
                          style: TextStyle(
                            fontSize: 12,
                            color: _mediumGray,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _timeShimmerAnimation,
                        builder: (context, child) {
                          final v = _timeShimmerAnimation.value;
                          return ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [_pureBlack, _mediumGray, _pureBlack],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment(v - 0.35, 0),
                              end: Alignment(v + 0.35, 0),
                            ).createShader(bounds),
                            child: child,
                          );
                        },
                        child: Text(
                          DateFormat('hh:mm a').format(now),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _pureBlack,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Positioned(
              top: -4,
              right: -4,
              child: AnimatedBuilder(
                animation: _timeShimmerAnimation,
                builder: (context, child) {
                  final v = _timeShimmerAnimation.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _pureBlack,
                          const Color(
                            0xFF444444,
                          ), // Further increased visibility
                          _pureBlack,
                        ],
                        stops: const [
                          0.2,
                          0.5,
                          0.8,
                        ], // Wider band for better shimmer presence
                        begin: Alignment(v - 0.6, -0.2),
                        end: Alignment(v + 0.6, 0.2),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _pureBlack.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: RepaintBoundary(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            key: _streakTargetKey,
                            Icons.local_fire_department,
                            color: _pureWhite,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_displayedStreakCount',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _pureWhite,
                            ),
                          ),
                        ],
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

  Widget _buildStatusCard(
    bool hasCheckedIn,
    bool hasCheckedOut,
    String? firstIn,
    String? lastOut,
    String? firstInDate,
    String? lastOutDate,
  ) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Status",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _charcoal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hasCheckedIn ? _offWhite : _pureWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _lightGray, width: 1),
                  ),
                  child: Row(
                    children: [
                      if (todaysRecords.isNotEmpty &&
                          todaysRecords.any(
                            (r) =>
                                r['is_overnight'] == 1 ||
                                r['date'] !=
                                    DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                          ))
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _softRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OVERNIGHT',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: _softRed,
                            ),
                          ),
                        ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasCheckedOut
                              ? _softGreen
                              : hasCheckedIn
                              ? _softGreen
                              : _mediumGray,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasCheckedOut
                            ? 'Shift Complete'
                            : hasCheckedIn
                            ? 'Active'
                            : 'Not started',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: hasCheckedIn ? _charcoal : _mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTimeChip(
                    'Check In',
                    firstIn,
                    Icons.login_outlined,
                    _softGreen,
                    subtitle:
                        firstInDate != null &&
                            firstInDate !=
                                DateFormat('yyyy-MM-dd').format(DateTime.now())
                        ? DateFormat(
                            'dd MMM',
                          ).format(DateTime.parse(firstInDate))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeChip(
                    'Check Out',
                    lastOut,
                    Icons.logout_outlined,
                    _softRed,
                    subtitle:
                        lastOutDate != null &&
                            lastOutDate !=
                                DateFormat('yyyy-MM-dd').format(DateTime.now())
                        ? DateFormat(
                            'dd MMM',
                          ).format(DateTime.parse(lastOutDate))
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(
    String label,
    String? time,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final hasTime = time != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasTime ? _lightGray : _lightGray, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: hasTime ? color : _mediumGray, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _mediumGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasTime ? _formatTime(time!) : '--:-- --',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: hasTime ? color : _mediumGray,
            ),
          ),
          if (hasTime && subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckInButton(bool hasCheckedIn, bool hasCheckedOut) {
    if (!_isLocationEnabled) {
      return GestureDetector(
        onTap: () async {
          debugPrint('📍 Location card tapped: Triggering system popup...');
          await _locationService.requestService();
          // ALWAYS do a fresh check after the request finishes/settings close
          bool actuallyEnabled = await _locationService.isLocationEnabled();
          if (mounted) {
            setState(() => _isLocationEnabled = actuallyEnabled);
          }
        },
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: _offWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lightGray, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _softRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  size: 24,
                  color: _softRed,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Location Disabled',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _charcoal,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'GPS is required',
                style: TextStyle(
                  fontSize: 12,
                  color: _mediumGray.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasRecord = todaysRecords.isNotEmpty;

    // ── State 3: Shift Complete ─────────────────────────────────────────────
    if (hasCheckedOut) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: _softGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _softGreen.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _softGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 26,
                color: _softGreen,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Shift Recorded',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _softGreen,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'for today',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _softGreen.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    // Protect against double clicks by showing a "Checked In Successfully" block
    if (hasCheckedIn) {
      final firstIn = todaysRecords.last['time'];
      if (firstIn != null) {
        try {
          final now = DateTime.now();
          // Handle the timer logic using the record's actual date
          final recordDate = todaysRecords.last['date'];
          final inTime = DateTime.parse('$recordDate $firstIn');
          final int elapsedSeconds = now.difference(inTime).inSeconds;
          final int remainingSeconds = 300 - elapsedSeconds;

          if (remainingSeconds > 0) {
            final double fillFraction = (remainingSeconds / 300).clamp(
              0.0,
              1.0,
            );
            final String minutesStr = (remainingSeconds ~/ 60)
                .toString()
                .padLeft(2, '0');
            final String secondsStr = (remainingSeconds % 60)
                .toString()
                .padLeft(2, '0');

            // Show massive success indicator with liquid fill
            return Container(
              height: 140,
              decoration: BoxDecoration(
                color: _charcoal, // Dark background for the "empty" portion
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _softGreen.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // The solid green liquid with dynamic wave effect
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 1),
                        curve: Curves.linear,
                        tween: Tween<double>(
                          begin: fillFraction,
                          end: fillFraction,
                        ),
                        builder: (context, value, child) {
                          return AnimatedBuilder(
                            animation: _timeShimmerController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: LiquidWavePainter(
                                  fillFraction: value,
                                  animationValue: _timeShimmerController.value,
                                  liquidColor: _softGreen,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // The content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 1200),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  // Use the raw animation but with an easeInOut curve for the rotation
                                  final rotate =
                                      Tween<double>(
                                        begin: math.pi,
                                        end: 0.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeInOut,
                                        ),
                                      );

                                  return AnimatedBuilder(
                                    animation: animation,
                                    child: child,
                                    builder: (context, child) {
                                      // Avoid "merging" icons by only showing the one that is on the "front" side
                                      if (animation.value < 0.5) {
                                        return const SizedBox.shrink();
                                      }

                                      return Transform(
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.002) // perspective
                                          ..rotateY(rotate.value),
                                        alignment: Alignment.center,
                                        child: child,
                                      );
                                    },
                                  );
                                },
                            child: (remainingSeconds ~/ 2) % 2 == 0
                                ? const Icon(
                                    Icons.check_circle,
                                    key: ValueKey('check'),
                                    size: 44,
                                    color: _pureWhite,
                                  )
                                : const Icon(
                                    Icons.lock,
                                    key: ValueKey('lock'),
                                    size: 44,
                                    color: _pureWhite,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Checked In!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _pureWhite,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _pureBlack.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: _pureWhite,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Unlocks in $minutesStr:$secondsStr',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _pureWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } catch (_) {}
      }
    }

    // ── State 1 & 2: Check In / Check Out ──────────────────────────────────
    final buttonLabel = hasCheckedIn ? 'Check Out' : 'Check In';
    final buttonColor = hasCheckedIn ? _softRed : _softGreen;
    final iconData = hasCheckedIn
        ? Icons.logout_rounded
        : Icons.photo_camera_rounded;
    final String instruction = hasCheckedIn
        ? 'Tap when leaving'
        : 'Tap to start work';

    return GestureDetector(
      onTap: () => _handleAttendanceAction(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: buttonColor.withOpacity(
                  0.3 + (_pulseAnimation.value * 0.4),
                ),
                width: 2 + (_pulseAnimation.value * 1.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withOpacity(
                    0.1 + (_pulseAnimation.value * 0.15),
                  ),
                  blurRadius: 20 + (_pulseAnimation.value * 15),
                  spreadRadius: _pulseAnimation.value * 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Soft background gradient that breathes
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        colors: [
                          buttonColor.withOpacity(
                            0.05 + (_pulseAnimation.value * 0.05),
                          ),
                          Colors.transparent,
                        ],
                        radius: 1.5 + _pulseAnimation.value * 0.5,
                      ),
                    ),
                  ),
                ),
                // Main Content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      iconData,
                      size: 42 + (_pulseAnimation.value * 3), // slight bounce
                      color: buttonColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      buttonLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: buttonColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: buttonColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          instruction,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: buttonColor.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _offWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lightGray, width: 1),
              ),
              child: Icon(icon, size: 22, color: _charcoal),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyInsights() {
    if (performanceData == null || !performanceData!.containsKey('streak')) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats_rounded,
              size: 48,
              color: _mediumGray.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Monthly Data',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need a bit more data to show your streak',
              style: TextStyle(
                fontSize: 13,
                color: _mediumGray,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    final topDay = performanceData!['top_day'] as Map<String, dynamic>? ?? {};
    final streak = performanceData!['streak'] as Map<String, dynamic>? ?? {};

    final daysData = streak['days'] as List<dynamic>? ?? [];
    final presentDays = streak['present_days'] ?? 0;

    final topDayDate = topDay['date'] as String?;
    final topDayDuration = topDay['duration'] as String? ?? '';

    String topDayName = 'No Data';
    if (topDayDate != null) {
      topDayName = DateFormat('MMMM d').format(DateTime.parse(topDayDate));
    }

    final now = DateTime.now();
    final numDays = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final formattedMonth = DateFormat('MMMM yyyy').format(now);

    final monthDataMap = <String, Map<String, dynamic>>{};
    for (var d in daysData) {
      if (d is Map<String, dynamic> && d['date'] != null) {
        monthDataMap[d['date'].toString()] = d;
      }
    }

    final currentStreak = _displayedStreakCount;

    return Column(
      children: [
        // Top Insight Carousel
        Container(
          height: 110,
          decoration: const BoxDecoration(color: Colors.transparent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView(
              controller: _streakPageController,
              onPageChanged: (idx) {
                if (mounted) setState(() => _currentStreakPage = idx);
              },
              children: [
                // Slide 1: Top Day
                _buildTopDaySlide(topDayName, topDayDuration, formattedMonth),
                // Slide 2: Monthly Attendance & Streak
                _buildAttendanceSlide(
                  presentDays,
                  currentDay,
                  formattedMonth,
                  _displayedStreakCount,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentStreakPage == index ? 24 : 8,
              height: 4,
              decoration: BoxDecoration(
                color: _currentStreakPage == index ? _charcoal : _lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Static Streak Grid
        _buildStreakGridSlide(
          formattedMonth,
          presentDays,
          currentDay,
          numDays,
          now,
          monthDataMap,
          topDayDate,
        ),
      ],
    );
  }

  Widget _buildTopDaySlide(
    String topDayName,
    String topDayDuration,
    String formattedMonth,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _RingPainter(
                    progress: _parseDurationProgress(topDayDuration),
                    color: _softRed,
                  ),
                ),
                const Icon(
                  Icons.emoji_events_rounded,
                  color: _pureWhite,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TOP DAY OF THE MONTH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _mediumGray,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  topDayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _pureWhite,
                  ),
                ),
                Text(
                  'Peak performance in $formattedMonth',
                  style: const TextStyle(fontSize: 12, color: _mediumGray),
                ),
              ],
            ),
          ),
          if (topDayDuration.isNotEmpty)
            _buildInsightPill(
              topDayDuration
                  .split(topDayDuration.contains('h') ? 'h' : 'm')[0]
                  .replaceAll(RegExp(r'[^0-9]'), '')
                  .trim(),
              topDayDuration.contains('h') ? 'HOURS' : 'MINS',
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSlide(
    int presentDays,
    int currentDay,
    String formattedMonth,
    int streak,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _RingPainter(
                    progress: currentDay > 0 ? presentDays / currentDay : 0,
                    color: _softRed,
                  ),
                ),
                Text(
                  '${((currentDay > 0 ? presentDays / currentDay : 0) * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _pureWhite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'MONTHLY ATTENDANCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _mediumGray,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$presentDays Days Present',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _pureWhite,
                  ),
                ),
                Text(
                  'Total records for $formattedMonth',
                  style: const TextStyle(fontSize: 12, color: _mediumGray),
                ),
              ],
            ),
          ),
          _buildInsightPill('$streak', 'STREAK'),
        ],
      ),
    );
  }

  Widget _buildInsightPill(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _softRed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _pureWhite,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakGridSlide(
    String formattedMonth,
    int presentDays,
    int currentDay,
    int numDays,
    DateTime now,
    Map<String, Map<String, dynamic>> monthDataMap,
    String? topDayDate,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Streak',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedMonth,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _mediumGray,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _mediumGray.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _charcoal,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_displayedStreakCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _mediumGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: (DateTime(now.year, now.month, 1).weekday - 1) + numDays,
            itemBuilder: (context, index) {
              final firstDayOffset =
                  DateTime(now.year, now.month, 1).weekday - 1;
              if (index < firstDayOffset) {
                return const SizedBox.shrink();
              }

              final dayNum = index - firstDayOffset + 1;
              final dateStr =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
              final record = monthDataMap[dateStr];
              final isFuture = dayNum > currentDay;

              Color bgColor;
              Color textColor;
              bool isPresent = false;
              bool isLeave = record != null && record['day_status'] == 'leave';

              if (isFuture) {
                bgColor = _offWhite;
                textColor = _mediumGray;
              } else {
                if (record != null && record['is_present'] == true) {
                  if (isLeave) {
                    bgColor = Colors.orange.withOpacity(0.15);
                    textColor = Colors.orange;
                    isPresent =
                        true; // Still counts for streak but styled differently
                  } else {
                    bgColor = _softGreen.withOpacity(0.15);
                    textColor = _softGreen;
                    isPresent = true;
                  }
                } else {
                  bgColor = _softRed.withOpacity(0.1);
                  textColor = _softRed;
                }
              }

              final isTopDay = topDayDate != null && dateStr == topDayDate;

              return GestureDetector(
                onTap: () {
                  if (isPresent || isTopDay) {
                    Get.to(() => DailyAttendancePage(targetDate: dateStr));
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isTopDay ? _pureBlack : bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: isTopDay
                            ? Border.all(
                                color: Colors.orange.withOpacity(0.5),
                                width: 1.5,
                              )
                            : (isFuture
                                  ? Border.all(
                                      color: _lightGray.withOpacity(0.5),
                                    )
                                  : null),
                        boxShadow: isTopDay
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (isTopDay)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: BurningFireWidget(
                                  animation: _fireController,
                                ),
                              ),
                            ),
                          Text(
                            dayNum.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (isPresent || isTopDay)
                                  ? FontWeight.w900
                                  : (isFuture
                                        ? FontWeight.w500
                                        : FontWeight.w700),
                              color: isTopDay ? _pureWhite : textColor,
                              shadows: isTopDay
                                  ? [
                                      const Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
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
        ],
      ),
    );
  }

  Widget _buildContinuousStreakSlide(int currentStreak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: _pureBlack.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Keep it up!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _mediumGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _pureBlack.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Icon(
                Icons.local_fire_department_rounded,
                size: 100,
                color: _pureBlack,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentStreak.toString(),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: _pureBlack,
              height: 1,
            ),
          ),
          const Text(
            'DAY STREAK',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _pureBlack,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your streak skips Sundays & Holidays',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _mediumGray.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay(double progress, String status) {
    final pct = (progress * 100).clamp(0, 100).toInt();
    return Positioned.fill(
      child: Container(
        color: _pureWhite.withOpacity(0.95),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _lightGray, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _pureBlack.withOpacity(0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _offWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: _lightGray, width: 1),
                  ),
                  child: Icon(
                    progress >= 1.0
                        ? Icons.check_outlined
                        : Icons.cloud_upload_outlined,
                    color: _charcoal,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  progress >= 1.0 ? 'Success' : 'Uploading',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: _mediumGray,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    height: 4,
                    color: _lightGray,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(color: _charcoal),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 11,
                        color: _mediumGray,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _charcoal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerStreakAnimation() async {
    if (!mounted) return;

    // Auto-scroll to top if greeting card is hidden
    if (_scrollController.hasClients && _scrollController.offset > 50) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // slight pause for smoothness
    }

    // More distinct vibration while flying
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      HapticFeedback.selectionClick(); // subtle but high-frequency click
    });

    setState(() => _isStreakFlying = true);
    _streakFlyController.forward();
  }

  Widget _buildFlyingFire() {
    if (!_isStreakFlying) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _streakFlyAnimation,
          builder: (context, child) {
            final t = _streakFlyAnimation.value;
            final dimOpacity = math.sin(t * math.pi) * 0.85;

            final rb =
                _streakTargetKey.currentContext?.findRenderObject()
                    as RenderBox?;
            final stackBox = context.findRenderObject() as RenderBox?;
            if (rb == null || stackBox == null) return const SizedBox.shrink();

            // Calculate target position relative to the Stack overlay
            final targetGlobalCenter = rb.localToGlobal(
              Offset(rb.size.width / 2, rb.size.height / 2),
            );
            final targetLocalPos = stackBox.globalToLocal(targetGlobalCenter);

            final size = MediaQuery.of(context).size;
            // Center of the stack (body)
            final startX = stackBox.size.width / 2;
            final startY = stackBox.size.height / 2;

            final endX = targetLocalPos.dx;
            final endY = targetLocalPos.dy;

            final x = startX + (endX - startX) * t;
            final y = startY + (endY - startY) * t;

            // Scale and rotation
            // We want it to land exactly at 0.4x scale (40 * 0.4 = 16) to match the badge icon
            final scale = (1.0 - t) * 1.5 + 0.4 + math.sin(t * math.pi) * 2.0;
            final rotation = t * math.pi * 2;

            // As fire goes "inside" the card (approaching t=1.0), it should turn white (lose orange colors)
            // We'll fade out the orange effects between t=0.7 and t=1.0
            final colorFade = (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
            final glowColor = Colors.orange.withOpacity(0.6 * colorFade);
            final shadowColor = Colors.orange.withOpacity(colorFade);

            return Stack(
              children: [
                Container(color: Colors.black.withOpacity(dimOpacity)),
                Positioned(
                  left: x - 40,
                  top: y - 40,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [glowColor, Colors.transparent],
                              ),
                            ),
                          ),
                          // Middle glow
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.yellow.withOpacity(0.8 * colorFade),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // Core Icon
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 40,
                            shadows: [
                              Shadow(
                                color: shadowColor,
                                blurRadius: 20 * colorFade,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Particles also fade out
                ...List.generate(3, (index) {
                  final offsetT = (t - (index * 0.05)).clamp(0.0, 1.0);
                  final tx = startX + (endX - startX) * offsetT;
                  final ty = startY + (endY - startY) * offsetT;
                  final pOpacity =
                      ((1.0 - t) * (1.0 - (index * 0.3)) * colorFade).clamp(
                        0.0,
                        1.0,
                      );

                  return Positioned(
                    left: tx - 5,
                    top: ty - 5,
                    child: Opacity(
                      opacity: pOpacity,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  // End of duplicated build block (removed)

  Future<void> _handleAttendanceAction() async {
    final userData = storage.read('user');
    final role = (userData?['role'] ?? '').toString().toLowerCase();
    final isManager = role == 'multi user' || role == 'admin';
    final hasRecord = todaysRecords.isNotEmpty;

    if (isManager) {
      final actionType = hasRecord ? 'check_out' : 'check_in';
      final result = await Get.to(
        () => EmployeeSelectionPage(
          action: actionType,
          managerId: userData['id'],
          managerName: userData['username'] ?? 'Multi User',
        ),
      );

      if (result == null || result is! Map) return;

      // Result from ProgressPage (which replaces everything else)
      if (result['success'] == true) {
        final bool isOut = result['isOut'] ?? false;
        await _loadTodayAttendance();
        await _loadMonthlyAttendance();
        await _loadMonthlyPerformance(updateUI: !isOut);

        if (isOut) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _triggerStreakAnimation();
          });
        }
        _showMessage(
          isOut ? 'Checked Out Successfully' : 'Checked In Successfully',
          isSuccess: true,
        );
      }
    } else {
      if (_isNavigatingToCamera) return;

      String? chosenSite;
      // --- ALWAYS SHOW SITE SELECTION (Check-in or Check-out) ---
      if (sites.isNotEmpty) {
        String searchQuery = '';
        bool searchById = false;
        final searchCtrl = TextEditingController();
        chosenSite = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setStateBtm) {
                final query = searchQuery.toLowerCase().trim();

                final filteredSites = sites.where((s) {
                  if (query.isEmpty) return true;
                  if (searchById) {
                    final siteId = (s['site_id']?.toString() ?? '')
                        .toLowerCase();
                    return siteId.startsWith(query);
                  } else {
                    final siteName = (s['site_name']?.toString() ?? '')
                        .toLowerCase();
                    return siteName.contains(query);
                  }
                }).toList();

                if (searchById && query.isNotEmpty) {
                  filteredSites.sort((a, b) {
                    final idA = (a['site_id']?.toString() ?? '')
                        .toLowerCase();
                    final idB = (b['site_id']?.toString() ?? '')
                        .toLowerCase();
                    if (idA == query && idB != query) return -1;
                    if (idB == query && idA != query) return 1;
                    return idA.compareTo(idB);
                  });
                }

                Widget _buildToggleBtn(bool isId, String label) {
                  final active = searchById == isId;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setStateBtm(() {
                          searchById = isId;
                          searchQuery = '';
                          searchCtrl.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? _charcoal : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active ? _charcoal : _lightGray,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: active ? _pureWhite : _mediumGray,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: const BoxDecoration(
                    color: _pureWhite,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: 24,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasRecord
                            ? 'Select Site for Check-out'
                            : 'Select Site for Check-in',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _charcoal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildToggleBtn(false, 'By Name'),
                          const SizedBox(width: 8),
                          _buildToggleBtn(true, 'By ID'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: searchById
                              ? 'Search by Site ID'
                              : 'Search by Site Name',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _charcoal,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _lightGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _charcoal),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (val) {
                          setStateBtm(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filteredSites.isEmpty
                              ? 1
                              : filteredSites.length + 1,
                          separatorBuilder: (_, __) =>
                              const Divider(color: _lightGray),
                          itemBuilder: (ctx, i) {
                            // "Others" tile — always shown as the last item
                            if (filteredSites.isEmpty ||
                                i == filteredSites.length) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.edit_location_alt_outlined,
                                  color: _charcoal,
                                ),
                                title: const Text(
                                  'Others',
                                  style: TextStyle(
                                    color: _charcoal,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Specify a custom site',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _mediumGray,
                                  ),
                                ),
                                onTap: () async {
                                  final otherCtrl = TextEditingController();
                                  final typed = await showDialog<String>(
                                    context: ctx,
                                    barrierDismissible: false,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Specify Site'),
                                      content: TextField(
                                        controller: otherCtrl,
                                        autofocus: true,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter site name',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _charcoal,
                                            foregroundColor: _pureWhite,
                                          ),
                                          onPressed: () {
                                            final val = otherCtrl.text.trim();
                                            if (val.isNotEmpty) {
                                              Navigator.pop(dCtx, val);
                                            }
                                          },
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (typed != null && typed.isNotEmpty) {
                                    Navigator.pop(ctx, '(others)-$typed');
                                  }
                                },
                              );
                            }
                            final s = filteredSites[i];
                            return ListTile(
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: _softRed,
                              ),
                              title: Text(
                                s['site_name'],
                                style: const TextStyle(
                                  color: _charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _charcoal.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: ${s['site_id'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _charcoal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              onTap: () => Navigator.pop(ctx, s['site_name']),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
        if (chosenSite == null) return; // cancelled site selection
      } else {
        // --- SITES LIST IS EMPTY: Force manual entry ---
        final otherCtrl = TextEditingController();
        chosenSite = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dCtx) => AlertDialog(
            title: const Text('Specify Site'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasRecord
                      ? 'No predefined sites found. Please enter your current site name to check-out.'
                      : 'No predefined sites found. Please enter your current site name to check-in.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otherCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter site name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _charcoal,
                  foregroundColor: _pureWhite,
                ),
                onPressed: () {
                  final val = otherCtrl.text.trim();
                  if (val.isNotEmpty) {
                    Navigator.pop(dCtx, val);
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (chosenSite == null) return; // cancelled site selection
      }

      _isNavigatingToCamera = true;
      try {
        final result = await Get.to(() => CameraPage(siteName: chosenSite));

        if (!mounted) return;

        if (result != null && result is Map && result['success'] == true) {
          final bool isOut = result['isOut'] ?? false;
          await _loadTodayAttendance();
          await _loadMonthlyAttendance();
          await _loadMonthlyPerformance(updateUI: !isOut);

          if (isOut) {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              _triggerStreakAnimation();
            });
          }
          _showMessage(
            isOut ? 'Checked Out Successfully' : 'Checked In Successfully',
            isSuccess: true,
          );
        }

        if (!mounted) return;
        // If success is true, we already showed success on CameraPage
        // and _handleConfirmFromCamera updated the state.
      } finally {
        _isNavigatingToCamera = false;
      }
    }
  }

  Future<bool> _handleConfirmFromCamera({
    required String imagePath,
    required String? lat,
    required String? lang,
    required String? site,
    required Function(double) onProgress,
    required Function(String status) onStatusUpdate,
    List<int>? userIds, // If provided, do bulk upload
  }) async {
    try {
      final userData = storage.read('user');
      if (userData == null) return false;

      final now = DateTime.now();

      onStatusUpdate('Uploading photo to server...');

      dynamic result;
      if (userIds != null && userIds.isNotEmpty) {
        // Bulk Upload
        result = await ApiService.createBulkAttendance(
          userIds: userIds,
          time: DateFormat('HH:mm:ss').format(now),
          date: DateFormat('yyyy-MM-dd').format(now),
          imagePath: imagePath,
          lat: lat,
          lang: lang,
          site: site,
          onProgress: (sent, total) => onProgress(total > 0 ? sent / total : 0),
        );
      } else {
        // Individual Upload
        result = await ApiService.createAttendance(
          {
            'user_id': userData['id'],
            'time': DateFormat('HH:mm:ss').format(now),
            'date': DateFormat('yyyy-MM-dd').format(now),
          },
          imagePath,
          lat: lat,
          lang: lang,
          site: site,
          onProgress: (sent, total) => onProgress(total > 0 ? sent / total : 0),
        );
      }

      if (result['success'] == true) {
        onStatusUpdate('Updating records...');
        onProgress(1.0);

        final msg = result['message'] ?? '';
        final isOut =
            msg.toLowerCase().contains('check-out') ||
            msg.toLowerCase().contains('checkout');

        // Show success msg on top of the next page
        await _loadTodayAttendance();
        await _loadMonthlyAttendance();
        await _loadMonthlyPerformance(updateUI: !isOut);

        if (isOut) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _triggerStreakAnimation();
          });
        }

        _showMessage(
          isOut ? 'Checked Out Successfully' : 'Checked In Successfully',
          isSuccess: true,
        );
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _submitAttendance(
    String imagePath, {
    String? lat,
    String? lang,
    String? site,
  }) async {
    try {
      final userData = storage.read('user');
      if (userData == null) {
        storage.remove('user');
        Get.offAllNamed('/');
        return;
      }

      setState(() {
        _uploadProgress = 0.0;
        _uploadStatus = 'Uploading photo...';
      });

      final now = DateTime.now();
      final result = await ApiService.createAttendance(
        {
          'user_id': userData['id'],
          'time': DateFormat('HH:mm:ss').format(now),
          'date': DateFormat('yyyy-MM-dd').format(now),
        },
        imagePath,
        lat: lat,
        lang: lang,
        site: site,
        onProgress: (sent, total) {
          if (mounted && total > 0)
            setState(() {
              final p = sent / total;
              _uploadProgress = p;
              _uploadStatus = p >= 1.0
                  ? 'Saving record...'
                  : 'Uploading photo...';
            });
        },
      );

      if (mounted) setState(() => _uploadProgress = null);

      if (result['success'] == true) {
        final msg = result['message'] ?? '';
        final isOut =
            msg.toLowerCase().contains('check-out') ||
            msg.toLowerCase().contains('checkout');
        _showMessage(
          isOut
              ? 'Checked out at ${DateFormat('hh:mm a').format(now)}'
              : 'Checked in at ${DateFormat('hh:mm a').format(now)}',
          isSuccess: true,
        );
        await _loadTodayAttendance();
        await _loadMonthlyAttendance();
        await _loadMonthlyPerformance(updateUI: !isOut);

        // Only trigger streak animation on check-out
        if (isOut) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _triggerStreakAnimation();
          });
        }
      } else {
        _showMessage('Failed to record attendance', isSuccess: false);
      }
    } catch (e) {
      if (mounted) setState(() => _uploadProgress = null);
      _showLocationErrorDialog(e.toString());
    }
  }

  void _showLocationErrorDialog(String error) {
    if (error.contains('DATE_MISMATCH')) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.date_range, size: 32, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Date Mismatch',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your device date is not synchronized with the server.',
                  style: TextStyle(fontSize: 18, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  'Please correct your device date and time settings and try again.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Go to Settings > Date & Time to fix this issue.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else if (error.contains('LOCATION_REQUIRED') ||
        error.contains('location')) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.location_off, size: 32, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Location Required',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please turn on your phone\'s location (GPS) to check in or check out.',
                  style: TextStyle(fontSize: 18, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  'We need to know where you are for safety.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After turning on location, try again.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Open location settings
                  // Note: You may need to add a package like 'open_app_settings' or 'app_settings'
                  // For now, we'll just close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Open Settings',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Retry the attendance submission
                  _handleAttendanceAction();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    } else if (error.contains('USER_INACTIVE') ||
        error.toLowerCase().contains('not allowed') ||
        error.toLowerCase().contains('administrator')) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.block_rounded, size: 32, color: Colors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Access Restricted',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are not allowed to record attendance.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account has been deactivated or restricted by administrator. Please contact your manager or HR.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } else {
      _showMessage(
        error.replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    }
  }

  Future<void> _submitBulkAttendance(
    String imagePath,
    List<int> userIds, {
    String? lat,
    String? lang,
    String? site,
  }) async {
    try {
      setState(() {
        _uploadProgress = 0.0;
        _uploadStatus = 'Uploading photo...';
      });

      final now = DateTime.now();
      final result = await ApiService.createBulkAttendance(
        userIds: userIds,
        time: DateFormat('HH:mm:ss').format(now),
        date: DateFormat('yyyy-MM-dd').format(now),
        imagePath: imagePath,
        lat: lat,
        lang: lang,
        site: site,
        onProgress: (sent, total) {
          if (mounted && total > 0)
            setState(() {
              final p = sent / total;
              _uploadProgress = p;
              _uploadStatus = p >= 1.0
                  ? 'Saving records...'
                  : 'Uploading photo...';
            });
        },
      );

      if (mounted) setState(() => _uploadProgress = null);

      if (result['success'] == true) {
        final msg = result['message'] ?? '';
        final count = (result['results'] as List?)?.length ?? userIds.length;
        _showMessage('$msg — $count person(s) recorded', isSuccess: true);
        final isOut =
            msg.toLowerCase().contains('check-out') ||
            msg.toLowerCase().contains('checkout');
        await _loadTodayAttendance();
        await _loadMonthlyAttendance();
        await _loadMonthlyPerformance(updateUI: !isOut);

        // Only trigger streak animation on check-out
        if (isOut) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _triggerStreakAnimation();
          });
        }
      } else {
        _showMessage('Failed to record attendance', isSuccess: false);
      }
    } catch (e) {
      if (mounted) setState(() => _uploadProgress = null);
      _showLocationErrorDialog(e.toString());
    }
  }

  String _formatTime(String t) {
    try {
      if (t.contains(':') && t.split(':').length >= 2) {
        final dt = DateFormat('HH:mm:ss').parse(t.length == 5 ? '$t:00' : t);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return t;
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  double _parseDurationProgress(String duration) {
    if (duration.isEmpty) return 0.0;
    try {
      double totalMinutes = 0;
      final parts = duration.toLowerCase().split(' ');
      for (var part in parts) {
        if (part.contains('h')) {
          totalMinutes += (double.tryParse(part.replaceAll('h', '')) ?? 0) * 60;
        } else if (part.contains('m')) {
          totalMinutes += double.tryParse(part.replaceAll('m', '')) ?? 0;
        }
      }
      return (totalMinutes / (9 * 60)).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }
}

class LiquidWavePainter extends CustomPainter {
  final double fillFraction; // 0.0 to 1.0
  final double animationValue; // continuous repeating value for moving wave
  final Color liquidColor;

  LiquidWavePainter({
    required this.fillFraction,
    required this.animationValue,
    required this.liquidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillFraction <= 0.0) return;

    final paint = Paint()
      ..color = liquidColor
      ..style = PaintingStyle.fill;

    // If practically full, just draw a rectangle
    if (fillFraction >= 0.99) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    final path = Path();

    // Y coordinate of the water level (0 is top, size.height is bottom)
    final waterLevel = size.height - (size.height * fillFraction);

    path.moveTo(0, size.height);
    path.lineTo(0, waterLevel);

    final double t = animationValue * 2 * math.pi;

    for (double i = 0; i <= size.width; i++) {
      final double x = i / size.width;

      // 3 overlapping asynchronous waves.
      // CRITICAL: The time speed multipliers MUST be integers (1.0, 2.0)
      // to ensure that when animationValue resets from 1.0 to 0.0,
      // the phase jump lands exactly on a multiple of 2*pi (seamless loop).
      final double wave1 = math.sin(x * 1.3 * 2 * math.pi + t) * 4.0;
      final double wave2 = math.sin(x * 2.7 * 2 * math.pi - (t * 2.0)) * 2.5;
      final double wave3 = math.sin(x * 4.1 * 2 * math.pi + t) * 1.5;

      final double yOffset = wave1 + wave2 + wave3;

      path.lineTo(i, waterLevel + yOffset);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidWavePainter oldDelegate) {
    return oldDelegate.fillFraction != fillFraction ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.liquidColor != liquidColor;
  }
}

class BurningFireWidget extends StatelessWidget {
  final Animation<double> animation;
  const BurningFireWidget({Key? key, required this.animation})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: CampFirePainter(animation: animation));
  }
}

class CampFirePainter extends CustomPainter {
  final Animation<double> animation;
  CampFirePainter({required this.animation}) : super(repaint: animation);

  final _rand = math.Random(42);
  double get t => animation.value * math.pi * 2;

  double noise(double x, double y) =>
      math.sin(x * 2.1 + t * 3.1) * math.cos(y * 1.7 + t * 2.3) * 0.5 +
      math.sin(x * 4.3 + t * 5.2) * 0.25 +
      math.cos(y * 3.7 + t * 4.1) * 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Ground it at 90% of cell height
    final baseY = size.height * 0.90;

    _drawAmbientGlow(canvas, size, cx, baseY);
    _drawEmberBed(canvas, cx, baseY);
    _drawFlames(canvas, cx, baseY, size);
    _drawLogs(canvas, cx, baseY, size);
  }

  void _drawAmbientGlow(Canvas canvas, Size size, double cx, double baseY) {
    final flicker = 0.55 + math.sin(t * 11) * 0.08 + math.sin(t * 7.3) * 0.06;
    // Glow limited to ~50px width
    final glowRect = Rect.fromCenter(
      center: Offset(cx, baseY + 2),
      width: 52,
      height: 28,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.orange.withOpacity(0.4 * flicker),
            Colors.deepOrange.withOpacity(0.2 * flicker),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
  }

  void _drawLog(
    Canvas canvas,
    double cx,
    double baseY,
    double offsetX,
    double angle,
    List<double> barkX,
  ) {
    canvas.save();
    canvas.translate(cx + offsetX, baseY + 2);
    canvas.rotate(angle);

    // Mini logs: 22px wide, 4px high
    final logRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-11, -2, 22, 4),
      Radius.circular(2),
    );

    // Log body
    final logPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0xFF1A0C05),
          Color(0xFF2E1508),
          Color(0xFF3A1A09),
          Color(0xFF1A0C05),
        ],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(Rect.fromLTWH(-11, -2, 22, 4));
    canvas.drawRRect(logRect, logPaint);

    // Ember glow on log
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Color(0xFFDC500A).withOpacity(0.6),
          Color(0xFFFF7814).withOpacity(0.75),
          Colors.transparent,
        ],
        stops: const [0, 0.4, 0.6, 1],
      ).createShader(Rect.fromLTWH(-11, -2, 22, 4));
    canvas.drawRRect(logRect, glowPaint);

    // Bark lines (Simplified)
    final barkPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 0.65;
    for (final x in barkX) {
      final lx = x * 0.15;
      canvas.drawLine(
        Offset(lx, -2),
        Offset(lx + angle.sign * 1.5, 2),
        barkPaint,
      );
    }

    canvas.restore();
  }

  void _drawLogs(Canvas canvas, double cx, double baseY, Size size) {
    _drawLog(canvas, cx, baseY, -2, -0.35, [-50, 20]);
    _drawLog(canvas, cx, baseY, 2, 0.35, [-30, 40]);
  }

  void _drawEmberBed(Canvas canvas, double cx, double baseY) {
    final bedRect = Rect.fromCenter(
      center: Offset(cx, baseY + 1),
      width: 22,
      height: 6,
    );
    canvas.drawOval(
      bedRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color(0xFFFF8C14).withOpacity(0.95),
            Color(0xFFDC4605).withOpacity(0.8),
            Colors.transparent,
          ],
          stops: const [0, 0.3, 1],
        ).createShader(bedRect),
    );

    // Tiny coals
    const coals = [
      [-6.0, 1.0, 1.5],
      [0.0, 0.0, 1.8],
      [6.0, 1.0, 1.6],
    ];
    for (final c in coals) {
      final flick = 0.85 + math.sin(t * 8 + c[0]) * 0.15;
      final center = Offset(cx + c[0], baseY + c[1]);
      final radius = c[2] * flick;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radius * 2, height: radius),
        Paint()..color = Color(0xFFFFDC50).withOpacity(0.95 * flick),
      );
    }
  }

  Path _flamePath(
    double cx,
    double baseY,
    double maxH,
    double width,
    double phase,
  ) {
    final flicker =
        math.sin(t * 7 + phase) * 0.06 + math.sin(t * 13 + phase * 2) * 0.03;
    final sway =
        math.sin(t * 3 + phase) * width * 0.22 +
        math.sin(t * 5.7) * width * 0.10;
    final h = maxH * (0.85 + flicker);
    const pts = 12;

    final path = Path();
    for (int i = 0; i <= pts; i++) {
      final frac = i / pts;
      final xWobble = noise(frac * 1.5, t * 1.2 + phase) * width * 0.3 * frac;
      final x =
          cx +
          sway * frac +
          math.sin(frac * math.pi) * width * (1 - frac * 0.7) +
          xWobble;
      final y = baseY - frac * h;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    for (int i = pts; i >= 0; i--) {
      final frac = i / pts;
      final xWobble =
          noise(frac * 1.5 + 1, t * 1.2 + phase) * width * 0.3 * frac;
      final x =
          cx +
          sway * frac -
          math.sin(frac * math.pi) * width * (1 - frac * 0.7) +
          xWobble;
      final y = baseY - frac * h;
      path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  void _drawSingleFlame(
    Canvas canvas,
    double cx,
    double baseY,
    double maxH,
    double width,
    double phase,
    double alpha,
    Color colBase,
    Color colMid,
    Color colTip,
  ) {
    final path = _flamePath(cx, baseY, maxH, width, phase);
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [colBase, colMid, colTip.withOpacity(0)],
          stops: const [0, 0.45, 1],
        ).createShader(bounds)
        ..color = Colors.white.withOpacity(alpha),
    );
  }

  void _drawFlames(Canvas canvas, double cx, double baseY, Size size) {
    // Mini flames: main peaks at 24px
    _drawSingleFlame(
      canvas,
      cx,
      baseY - 1,
      22,
      11,
      0,
      0.25,
      Color(0xFFC82805),
      Color(0xFFDC5005),
      Color(0xFFFFD028),
    );
    _drawSingleFlame(
      canvas,
      cx,
      baseY - 1,
      28,
      9,
      0.3,
      0.75,
      Color(0xFFB42305),
      Color(0xFFF56408),
      Color(0xFFFFC83C),
    );
    _drawSingleFlame(
      canvas,
      cx - 4,
      baseY - 1,
      16,
      6,
      1.1,
      0.65,
      Color(0xFFBE2805),
      Color(0xFFFA6E0A),
      Color(0xFFFFD246),
    );
    _drawSingleFlame(
      canvas,
      cx + 3,
      baseY - 1,
      18,
      7,
      2.2,
      0.65,
      Color(0xFFB92605),
      Color(0xFFF86C0A),
      Color(0xFFFFD041),
    );
    _drawSingleFlame(
      canvas,
      cx,
      baseY - 1,
      14,
      4,
      0.5,
      0.9,
      Color(0xFFF06408),
      Color(0xFFFFE664),
      Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CampFirePainter oldDelegate) => true;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

