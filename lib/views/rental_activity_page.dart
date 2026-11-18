import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'rental_camera_page.dart';
import 'rental_progress_page.dart';

class RentalActivityPage extends StatefulWidget {
  const RentalActivityPage({Key? key}) : super(key: key);

  @override
  State<RentalActivityPage> createState() => _RentalActivityPageState();
}

class _RentalActivityPageState extends State<RentalActivityPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fabAnimController;
  late Animation<double> _fabSizeCurve;
  late Animation<double> _fabFadeCurve;
  final GetStorage _storage = GetStorage();

  // Exact EST App Colors (Consistent with home_page.dart & camera_page.dart)
  static const Color _charcoal = Color(0xFF1E293B);
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _lightGray = Color(0xFFE2E8F0);
  static const Color _mediumGray = Color(0xFF64748B);
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFD97706);
  static const Color _bgLight = Color(0xFFFAFAFB);

  bool _isLoading = false;
  bool _isHistoryLoading = false;
  List<dynamic> _activeRentals = [];
  List<dynamic> _allLogs = [];
  List<dynamic> _materials = [];
  List<String> _categories = [];
  List<dynamic> _sites = [];

  // Past History Filters (Default: last 30 days)
  String _historyQuery = '';
  late DateTime _historyStartDate;
  late DateTime _historyEndDate;

  bool _isFabExtended = true;

  Map<String, dynamic>? _user;
  Timer? _liveTickerTimer;
  bool _isLocationEnabled = true;
  StreamSubscription<geo.ServiceStatus>? _locServiceSub;

  @override
  void initState() {
    super.initState();
    _historyEndDate = DateTime.now();
    _historyStartDate = DateTime.now().subtract(const Duration(days: 29));
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _fabSizeCurve = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fabFadeCurve = CurvedAnimation(
      parent: _fabAnimController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.75, curve: Curves.easeIn),
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _setFabExtended(true);
      }
      if (mounted) setState(() {});
    });
    _user = _storage.read('user');
    _loadInitialData();
    _checkLocationState();

    _locServiceSub = geo.Geolocator.getServiceStatusStream().listen((status) {
      if (mounted) {
        setState(() {
          _isLocationEnabled = status == geo.ServiceStatus.enabled;
        });
      }
    });

    _liveTickerTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _setFabExtended(bool extended) {
    if (_isFabExtended == extended) return;
    _isFabExtended = extended;
    if (extended) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  Future<void> _checkLocationState() async {
    try {
      final enabled = await LocationService().isLocationEnabled();
      if (mounted) setState(() => _isLocationEnabled = enabled);
    } catch (_) {}
  }

  /// Triggers the Android native system popup dialog to turn on location without leaving the app
  Future<bool> _promptEnableLocation() async {
    try {
      await LocationService().requestService();
      final isNowEnabled = await LocationService().isLocationEnabled();
      if (mounted) {
        setState(() => _isLocationEnabled = isNowEnabled);
      }
      return isNowEnabled;
    } catch (e) {
      debugPrint('Error triggering native location popup: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _locServiceSub?.cancel();
    _liveTickerTimer?.cancel();
    _fabAnimController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchMaterials(),
      _fetchCategories(),
      _fetchSites(),
      _fetchActiveRentals(),
      _fetchAllLogs(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchMaterials() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/rental/materials'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          _materials = data['materials'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching materials: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/rental/categories'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['categories'] is List) {
          final cats = (data['categories'] as List)
              .map((c) => (c is Map ? c['name'] : c)?.toString() ?? '')
              .where((name) => name.trim().isNotEmpty)
              .toList();
          if (mounted) {
            setState(() => _categories = cats);
          } else {
            _categories = cats;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching rental categories: $e');
    }
  }

  Future<void> _fetchSites() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/sites'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _sites = data;
        }
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
  }

  Future<void> _fetchActiveRentals() async {
    try {
      final userId = _user?['id']?.toString() ?? '';
      final userParam = userId.isNotEmpty ? '?user_id=$userId' : '';
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/rental/active$userParam'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _activeRentals = data['logs'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching active rentals: $e');
    }
  }

  Future<void> _fetchAllLogs() async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_historyStartDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_historyEndDate);
      final queryParam = _historyQuery.trim().isNotEmpty
          ? '&search=${Uri.encodeComponent(_historyQuery.trim())}'
          : '';
      final userId = _user?['id']?.toString() ?? '';
      final userParam = userId.isNotEmpty ? '&user_id=$userId' : '';
      final url = '${ApiService.baseUrl}/rental/logs?startDate=$startStr&endDate=$endStr$queryParam$userParam&limit=500';

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _allLogs = data['logs'] ?? [];
            _isHistoryLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) setState(() => _isHistoryLoading = false);
    }
  }

  void _pickHistoryDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _historyStartDate, end: _historyEndDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryBlue,
            onPrimary: Colors.white,
            onSurface: _charcoal,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _historyStartDate = picked.start;
        _historyEndDate = picked.end;
        _isHistoryLoading = true;
      });
      _fetchAllLogs();
    }
  }

  String _formatLiveDuration(String? startTimeStr) {
    if (startTimeStr == null || startTimeStr.isEmpty) return '—';
    try {
      DateTime start;
      if (startTimeStr.contains('T') || startTimeStr.endsWith('Z')) {
        final parsed = DateTime.parse(startTimeStr);
        start = parsed.isUtc ? parsed.toLocal() : parsed;
      } else {
        start = DateTime.parse(startTimeStr);
      }
      final now = DateTime.now();
      final diff = now.difference(start);
      if (diff.isNegative) return '0m';
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final mins = diff.inMinutes % 60;
      if (days > 0) return '${days}d ${hours}h ${mins}m';
      if (hours > 0) return '${hours}h ${mins}m';
      return '${mins}m';
    } catch (_) {
      return '—';
    }
  }

  String _formatCompletedDuration(Map<String, dynamic> item) {
    int totalMins = 0;
    bool hasDiff = false;

    if (item['in_time'] != null && item['out_time'] != null) {
      final inStr = item['in_time'].toString();
      final outStr = item['out_time'].toString();
      final rawIn = DateTime.tryParse(inStr);
      final rawOut = DateTime.tryParse(outStr);
      if (rawIn != null && rawOut != null) {
        final inTime = rawIn.isUtc ? rawIn.toLocal() : rawIn;
        final outTime = rawOut.isUtc ? rawOut.toLocal() : rawOut;
        final diff = outTime.difference(inTime);
        totalMins = diff.isNegative ? 0 : diff.inMinutes;
        hasDiff = true;
      }
    }

    if (!hasDiff) {
      if (item['total_minutes'] != null) {
        totalMins = int.tryParse(item['total_minutes'].toString()) ?? 0;
        hasDiff = true;
      } else if (item['total_hours'] != null) {
        final th = double.tryParse(item['total_hours'].toString()) ?? 0.0;
        totalMins = (th * 60).round();
        hasDiff = true;
      }
    }

    final days = item['duration_days'] is int
        ? item['duration_days'] as int
        : (int.tryParse(item['duration_days']?.toString() ?? '0') ?? 0);
    final hours = item['duration_hours'] ?? 0;

    if (hasDiff) {
      if (totalMins < 60) {
        return '$totalMins Mins';
      }
      final d = totalMins ~/ 1440;
      final h = (totalMins % 1440) ~/ 60;
      final m = totalMins % 60;
      if (d > 0) {
        return '$d Days $h Hours';
      }
      return m > 0 ? '$h Hours $m Mins' : '$h Hours';
    }

    final numHours = num.tryParse(hours.toString()) ?? 0;
    if (days == 0 && numHours < 1) {
      final m = (numHours * 60).round();
      return '$m Mins';
    }
    return days > 0 ? '$days Days $hours Hours' : '$hours Hours';
  }

  // ── Exact Attendance Site Selection Bottom Sheet ──
  Future<Map<String, dynamic>?> _showAttendanceSiteBottomSheet({required bool isCheckOut}) async {
    if (_sites.isEmpty) {
      Get.snackbar('Notice', 'No sites configured yet.',
          backgroundColor: Colors.amber.shade700, colorText: Colors.white);
      return null;
    }

    String searchQuery = '';
    bool searchById = false;
    final searchCtrl = TextEditingController();

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateBtm) {
            final query = searchQuery.toLowerCase().trim();

            final filteredSites = _sites.where((s) {
              if (query.isEmpty) return true;
              if (searchById) {
                final siteId = (s['site_id']?.toString() ?? '').toLowerCase();
                return siteId.startsWith(query);
              } else {
                final siteName = (s['site_name']?.toString() ?? '').toLowerCase();
                return siteName.contains(query);
              }
            }).toList();

            if (searchById && query.isNotEmpty) {
              filteredSites.sort((a, b) {
                final idA = (a['site_id']?.toString() ?? '').toLowerCase();
                final idB = (b['site_id']?.toString() ?? '').toLowerCase();
                if (idA == query && idB != query) return -1;
                if (idB == query && idA != query) return 1;
                return idA.compareTo(idB);
              });
            }

            Widget buildToggleBtn(bool isId, String label) {
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
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    isCheckOut ? 'Select Site for Check-out' : 'Select Site for Check-in',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _charcoal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      buildToggleBtn(false, 'By Name'),
                      const SizedBox(width: 8),
                      buildToggleBtn(true, 'By ID'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: searchById ? 'Search by Site ID' : 'Search by Site Name',
                      prefixIcon: const Icon(Icons.search, color: _charcoal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _charcoal),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                      itemCount: filteredSites.isEmpty ? 1 : filteredSites.length + 1,
                      separatorBuilder: (_, __) => const Divider(color: _lightGray, height: 1),
                      itemBuilder: (ctx, i) {
                        // "Others" tile — always shown as the last item
                        if (filteredSites.isEmpty || i == filteredSites.length) {
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
                              style: TextStyle(fontSize: 11, color: _mediumGray),
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
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter site name',
                                      border: OutlineInputBorder(),
                                    ),
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
                              if (typed != null && typed.isNotEmpty) {
                                Navigator.pop(ctx, {
                                  'site_id': 'OTHERS',
                                  'site_name': typed,
                                });
                              }
                            },
                          );
                        }

                        final s = filteredSites[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: _charcoal,
                          ),
                          title: Text(
                            s['site_name'] ?? '',
                            style: const TextStyle(
                              color: _charcoal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${s['site_id'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _mediumGray,
                            ),
                          ),
                          onTap: () => Navigator.pop(ctx, s),
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
  }

  // ── Open Location in Google Maps (Matching Attendance Design) ──
  Future<void> _openMap(String? lat, String? lng, String label) async {
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      Get.snackbar(
        'Location Unavailable',
        'No GPS coordinates recorded for $label.',
        backgroundColor: Colors.amber.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
        icon: const Icon(Icons.location_off_outlined, color: Colors.white),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not open Google Maps',
        backgroundColor: const Color(0xFFDC2626),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // ── Show Full Image Preview Modal with Map Option ──
  void _showImageDialog(String? photoUrl, String title, {String? lat, String? lng}) {
    if (photoUrl == null || photoUrl.isEmpty) return;
    final fullUrl = '${ApiService.baseUrl}$photoUrl';
    final hasLoc = lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty && lat != 'null' && lng != 'null';

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: Colors.black87,
                    elevation: 0,
                    title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.white)),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    actions: [
                      if (hasLoc)
                        IconButton(
                          icon: const Icon(Icons.map_outlined, color: Colors.greenAccent),
                          tooltip: 'Open in Google Maps',
                          onPressed: () => _openMap(lat, lng, title),
                        ),
                    ],
                  ),
                  InteractiveViewer(
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(60.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (ctx, _, __) => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Unable to load photo', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                  if (hasLoc)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.location_on, color: Colors.greenAccent, size: 16),
                        label: const Text('View Location on Google Maps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _openMap(lat, lng, title),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Searchable Category Picker Bottom Sheet ──
  Future<String?> _showCategoryPickerBottomSheet(
    List<String> categoryOptions,
    String? currentSelection,
  ) async {
    final searchCtrl = TextEditingController();
    String searchQuery = '';

    // Separate regular categories and 'Others' so 'Others' is always shown at the end
    final regularCats = categoryOptions
        .where((c) => c.toLowerCase() != 'others')
        .toList();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = searchQuery.toLowerCase().trim();
            final filtered = regularCats.where((cat) {
              if (q.isEmpty) return true;
              return cat.toLowerCase().contains(q);
            }).toList();

            final keyboardH = MediaQuery.of(ctx).viewInsets.bottom;
            final safeTop = MediaQuery.of(ctx).padding.top;
            final screenH = MediaQuery.of(ctx).size.height;
            final sheetH = keyboardH > 0
                ? screenH - keyboardH - safeTop - 12
                : screenH * 0.72;

            return SizedBox(
              height: sheetH,
              child: Container(
                decoration: const BoxDecoration(
                  color: _pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: _lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${regularCats.length} categories available',
                      style: const TextStyle(fontSize: 12, color: _mediumGray),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search category...',
                        hintStyle: const TextStyle(fontSize: 13, color: _mediumGray),
                        prefixIcon: const Icon(Icons.search, color: _charcoal),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  searchCtrl.clear();
                                  setSheetState(() => searchQuery = '');
                                },
                                child: const Icon(Icons.close, size: 18, color: _mediumGray),
                              )
                            : null,
                        filled: true,
                        fillColor: _bgLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _charcoal),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      onChanged: (val) => setSheetState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length + 1, // Always include 'Others' at bottom
                        separatorBuilder: (_, __) => const Divider(color: _lightGray, height: 1),
                        itemBuilder: (ctx, i) {
                          if (i == filtered.length) {
                            final isSelected = currentSelection?.toLowerCase() == 'others';
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.more_horiz_rounded,
                                color: isSelected ? _primaryBlue : _charcoal,
                              ),
                              title: Text(
                                'Others',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? _primaryBlue : _charcoal,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Categorize under Others',
                                style: TextStyle(fontSize: 11, color: _mediumGray),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: _primaryBlue, size: 20)
                                  : null,
                              onTap: () => Navigator.pop(ctx, 'Others'),
                            );
                          }

                          final cat = filtered[i];
                          final isSelected = currentSelection == cat;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.category_outlined,
                              color: isSelected ? _primaryBlue : _charcoal,
                            ),
                            title: Text(
                              cat,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? _primaryBlue : _charcoal,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: _primaryBlue, size: 20)
                                : null,
                            onTap: () => Navigator.pop(ctx, cat),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── RENTAL CHECK-IN (IN) FLOW (Consistent with Attendance Check-In) ──
  Future<void> _handleRentalCheckIn() async {
    // Location check: mandatory for check-in via native popup
    bool locEnabled = await LocationService().isLocationEnabled();
    if (!locEnabled) {
      locEnabled = await _promptEnableLocation();
      if (!locEnabled) {
        Get.snackbar(
          'Location Required',
          'GPS location is required to proceed with rental check-in.',
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }

    // Step 1: Select Site using Attendance Site Bottom Sheet
    final selectedSite = await _showAttendanceSiteBottomSheet(isCheckOut: false);
    if (selectedSite == null || !mounted) return;

    if (_categories.isEmpty) {
      await _fetchCategories();
      if (!mounted) return;
    }

    // Build category list (DB categories + material categories, with 'Others' at the end)
    final List<String> categoryOptions = {
      ..._categories,
      ..._materials
          .map((m) => m['category']?.toString().trim() ?? '')
          .where((c) => c.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    categoryOptions.removeWhere((c) => c.toLowerCase() == 'others');
    categoryOptions.add('Others');

    // Step 2: Select Equipment / Material Bottom Sheet
    Map<String, dynamic>? selectedMaterial;
    bool isManualMaterial = false;
    String? selectedManualCategory;
    final descCtrl = TextEditingController();
    final matSearchCtrl = TextEditingController();
    final manualNameCtrl = TextEditingController();
    String matSearchQuery = '';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMatState) {
            final query = matSearchQuery.toLowerCase().trim();
            final filteredMaterials = _materials.where((m) {
              if (query.isEmpty) return true;
              final name = (m['name']?.toString() ?? '').toLowerCase();
              final category = (m['category']?.toString() ?? '').toLowerCase();
              return name.contains(query) || category.contains(query);
            }).toList();

            final bool canProceed = isManualMaterial
                ? (manualNameCtrl.text.trim().isNotEmpty && selectedManualCategory != null)
                : (selectedMaterial != null);

            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: _primaryBlue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Rental Equipment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _charcoal,
                                ),
                              ),
                              Text(
                                'Site: [${selectedSite['site_id']}] ${selectedSite['site_name']}',
                                style: const TextStyle(fontSize: 12, color: _mediumGray),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Header row with Manual Entry toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isManualMaterial ? 'Specify New Material *' : 'Select Equipment *',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _charcoal),
                        ),
                        GestureDetector(
                          onTap: () {
                            setMatState(() {
                              if (!isManualMaterial) {
                                isManualMaterial = true;
                                selectedMaterial = null;
                                if (manualNameCtrl.text.trim().isEmpty && matSearchCtrl.text.trim().isNotEmpty) {
                                  manualNameCtrl.text = matSearchCtrl.text.trim();
                                }
                              } else {
                                isManualMaterial = false;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isManualMaterial ? _bgLight : _primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isManualMaterial ? _lightGray : _primaryBlue.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isManualMaterial ? Icons.list_alt_rounded : Icons.add_circle_outline,
                                  size: 14,
                                  color: isManualMaterial ? _charcoal : _primaryBlue,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isManualMaterial ? 'Select from List' : 'Specify New',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isManualMaterial ? _charcoal : _primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (isManualMaterial) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _lightGray),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Material / Equipment Name *',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _charcoal),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: manualNameCtrl,
                              onChanged: (_) => setMatState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Enter new material or equipment name',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _lightGray),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _charcoal),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Category *',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _charcoal),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                FocusScope.of(ctx).unfocus();
                                final pickedCat = await _showCategoryPickerBottomSheet(
                                  categoryOptions,
                                  selectedManualCategory,
                                );
                                if (pickedCat != null) {
                                  setMatState(() => selectedManualCategory = pickedCat);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedManualCategory != null ? _charcoal : _lightGray,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedManualCategory?.toLowerCase() == 'others'
                                          ? Icons.more_horiz_rounded
                                          : Icons.category_outlined,
                                      size: 18,
                                      color: selectedManualCategory != null ? _primaryBlue : _mediumGray,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        selectedManualCategory ?? 'Tap to search & select category',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: selectedManualCategory != null
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: selectedManualCategory != null
                                              ? _charcoal
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: _mediumGray,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 13, color: _mediumGray),
                                SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'This material will be saved to the catalog on check-in.',
                                    style: TextStyle(fontSize: 11, color: _mediumGray),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Search Equipment TextField (matching Site search styling)
                      TextField(
                        controller: matSearchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search Equipment or Category',
                          hintStyle: const TextStyle(fontSize: 13, color: _mediumGray),
                          prefixIcon: const Icon(Icons.search, color: _charcoal),
                          suffixIcon: matSearchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    matSearchCtrl.clear();
                                    setMatState(() => matSearchQuery = '');
                                  },
                                  child: const Icon(Icons.close, size: 18, color: _mediumGray),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _lightGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _charcoal),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onChanged: (val) {
                          setMatState(() {
                            matSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          border: Border.all(color: _lightGray),
                          borderRadius: BorderRadius.circular(14),
                          color: _bgLight,
                        ),
                        child: filteredMaterials.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'No equipment matching search',
                                        style: TextStyle(fontSize: 13, color: _mediumGray),
                                      ),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _primaryBlue,
                                          side: BorderSide(color: _primaryBlue.withOpacity(0.5)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          matSearchCtrl.text.trim().isNotEmpty
                                              ? 'Specify "${matSearchCtrl.text.trim()}" Manually'
                                              : 'Specify New Material Manually',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onPressed: () {
                                          setMatState(() {
                                            isManualMaterial = true;
                                            selectedMaterial = null;
                                            manualNameCtrl.text = matSearchCtrl.text.trim();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredMaterials.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: _lightGray),
                                itemBuilder: (ctx, i) {
                                  final mat = filteredMaterials[i];
                                  final isSelected = selectedMaterial?['id'] == mat['id'];
                                  final matNameUpper = (mat['name']?.toString() ?? '').toUpperCase();
                                  final isManualPlaceholder = matNameUpper.contains('SPECIFY MANUAL');
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isManualPlaceholder ? Icons.edit_note_rounded : Icons.construction_outlined,
                                      color: isSelected ? _primaryBlue : _charcoal,
                                    ),
                                    title: Text(
                                      mat['name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? _primaryBlue : _charcoal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: mat['category'] != null
                                        ? Text(mat['category'], style: const TextStyle(fontSize: 11, color: _mediumGray))
                                        : null,
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: _primaryBlue, size: 22)
                                        : null,
                                    onTap: () {
                                      setMatState(() {
                                        if (isManualPlaceholder) {
                                          isManualMaterial = true;
                                          selectedMaterial = null;
                                          manualNameCtrl.clear();
                                          final cat = mat['category']?.toString().trim();
                                          if (cat != null && cat.isNotEmpty) {
                                            selectedManualCategory = categoryOptions.firstWhere(
                                              (c) => c.toLowerCase() == cat.toLowerCase(),
                                              orElse: () => 'Others',
                                            );
                                          }
                                        } else {
                                          selectedMaterial = mat;
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Description / Specs TextField
                    const Text('Description / Serial No. / Vendor Remarks',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _charcoal)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. 50 Ton Hydraulic Crane, Vendor: ABC Rentals, Ref: #104',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: _bgLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _charcoal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Proceed to Camera Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!canProceed || !_isLocationEnabled)
                              ? Colors.grey.shade400
                              : _charcoal,
                          foregroundColor: _pureWhite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: Icon(!_isLocationEnabled ? Icons.location_off_rounded : Icons.camera_alt_outlined),
                        label: Text(
                          !_isLocationEnabled
                              ? 'GPS Disabled (Enable to Proceed)'
                              : 'Proceed to Camera (IN)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: !canProceed
                            ? null
                            : (!_isLocationEnabled)
                                ? () async {
                                    final turnedOn = await _promptEnableLocation();
                                    if (turnedOn) {
                                      setMatState(() {});
                                    }
                                  }
                                : () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (!isManualMaterial && selectedMaterial == null) return;
    if (isManualMaterial && (manualNameCtrl.text.trim().isEmpty || selectedManualCategory == null)) return;

    final String chosenMaterialId = isManualMaterial ? '' : (selectedMaterial!['id']?.toString() ?? '');
    final String chosenMaterialName = isManualMaterial
        ? manualNameCtrl.text.trim()
        : (selectedMaterial!['name']?.toString() ?? '');
    final String chosenCategory = isManualMaterial
        ? (selectedManualCategory ?? 'Others')
        : (selectedMaterial!['category']?.toString() ?? '');

    // Step 3: Open Camera Page with "SWIPE TO PROCEED" (Exact Attendance Camera Flow)
    final dynamic camResult = await Get.to(
      () => RentalCameraPage(
        title: 'Capture Material IN',
        materialName: chosenMaterialName.isNotEmpty ? chosenMaterialName : 'Rental Item',
        actionType: 'RENTAL IN',
        siteName: '[${selectedSite['site_id']}] ${selectedSite['site_name']}',
        extraDetails: {
          'ACTION': 'RENTAL IN',
          'EQUIPMENT': chosenMaterialName,
          if (chosenCategory.isNotEmpty) 'CATEGORY': chosenCategory,
          'DESC': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Material Received',
        },
      ),
      transition: Transition.downToUp,
    );

    if (camResult == null) return;

    File? capturedPhoto;
    String? lat;
    String? lng;

    if (camResult is Map) {
      capturedPhoto = camResult['file'] as File?;
      lat = camResult['lat']?.toString();
      lng = camResult['lng']?.toString();
    } else if (camResult is File) {
      capturedPhoto = camResult;
    }

    if (capturedPhoto == null) return;

    // Strict validation: location is mandatory for uploading!
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      try {
        final p = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        lat = p.latitude.toString();
        lng = p.longitude.toString();
      } catch (_) {}
    }

    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      Get.snackbar(
        'GPS Location Mandatory',
        'Cannot upload rental check-in without valid GPS coordinates. Please enable location services and try again.',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Step 4: Submit via Step-by-Step Dio Progress Page (Real-time KB, Speed, ETA)
    final mobileNow = DateTime.now();
    final mobileTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(mobileNow);

    final progressResult = await Get.to(
      () => RentalProgressPage(
        isCheckOut: false,
        materialName: chosenMaterialName.isNotEmpty ? chosenMaterialName : 'Equipment',
        siteName: selectedSite['site_name'] ?? '',
        imagePath: capturedPhoto!.path,
        fields: {
          'material_id': chosenMaterialId,
          'material_name': chosenMaterialName,
          'category': chosenCategory,
          'is_new_material': isManualMaterial ? 'true' : 'false',
          'user_id': _user?['id']?.toString() ?? '0',
          'user_name': _user?['username'] ?? 'User',
          'description': descCtrl.text.trim(),
          'in_site_id': selectedSite['site_id']?.toString() ?? '',
          'in_site_name': selectedSite['site_name']?.toString() ?? '',
          'in_time': mobileTimeStr,
          'lat': lat,
          'lng': lng,
        },
      ),
      transition: Transition.fadeIn,
    );

    if (progressResult != null && progressResult['success'] == true) {
      Get.snackbar(
        'Checked In Successfully',
        '$chosenMaterialName recorded at ${selectedSite['site_name']}',
        backgroundColor: _emerald,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      _loadInitialData();
    }
  }

  List<Map<String, String>> _parseOutAttachments(Map<String, dynamic> item) {
    final List<Map<String, String>> list = [];
    final raw = item['out_attachments'];
    if (raw != null && raw.toString().trim().isNotEmpty && raw.toString() != 'null') {
      try {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map && entry['path'] != null) {
              final p = entry['path'].toString();
              final n = (entry['name'] ?? p.split('/').last).toString();
              if (p.isNotEmpty) list.add({'path': p, 'name': n});
            }
          }
        }
      } catch (_) {}
    }
    if (list.isEmpty && item['out_attachment'] != null && item['out_attachment'].toString().isNotEmpty) {
      final p = item['out_attachment'].toString();
      final n = (item['out_attachment_name'] ?? p.split('/').last).toString();
      list.add({'path': p, 'name': n});
    }
    return list;
  }

  IconData _attachmentIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    return Icons.attach_file_rounded;
  }

  Color _attachmentIconColor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFDC2626);
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return _primaryBlue;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return _emerald;
    }
    return _charcoal;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openAttachment(String path, String name) async {
    final lower = name.toLowerCase();
    final isImg = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
    if (isImg) {
      _showImageDialog(path, name);
      return;
    }
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar(
        'Unable to Open',
        'Could not open attachment: $name',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
    }
  }

  // ── RENTAL CHECK-OUT (OUT) FLOW (Consistent with Attendance Check-Out) ──
  Future<void> _handleRentalCheckOut(Map<String, dynamic> rental) async {
    // Location check: mandatory for check-out via native popup
    bool locEnabled = await LocationService().isLocationEnabled();
    if (!locEnabled) {
      locEnabled = await _promptEnableLocation();
      if (!locEnabled) {
        Get.snackbar(
          'Location Required',
          'GPS location is required to proceed with rental check-out.',
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }

    // Step 1: Select Out Site using Attendance Site Bottom Sheet (Includes out_site_id!)
    final selectedOutSite = await _showAttendanceSiteBottomSheet(isCheckOut: true);
    if (selectedOutSite == null || !mounted) return;

    // Step 2: Return remarks & optional invoice/document attachments modal
    final outDescCtrl = TextEditingController();
    final List<PlatformFile> selectedAttachments = [];
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setOutState) {
            Future<void> pickAttachmentFiles() async {
              try {
                final res = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                  type: FileType.any,
                );
                if (res == null || res.files.isEmpty) return;

                setOutState(() {
                  for (final f in res.files) {
                    if (f.path == null || f.path!.isEmpty) continue;
                    if (selectedAttachments.length >= 5) {
                      Get.snackbar(
                        'Attachment Limit',
                        'You can attach up to 5 files per check-out.',
                        backgroundColor: Colors.amber.shade800,
                        colorText: Colors.white,
                      );
                      break;
                    }
                    if (f.size > 20 * 1024 * 1024) {
                      Get.snackbar(
                        'File Too Large',
                        '${f.name} exceeds the 20 MB file size limit.',
                        backgroundColor: Colors.red.shade800,
                        colorText: Colors.white,
                      );
                      continue;
                    }
                    final alreadyAdded = selectedAttachments.any((e) => e.path == f.path);
                    if (!alreadyAdded) {
                      selectedAttachments.add(f);
                    }
                  }
                });
              } catch (e) {
                Get.snackbar(
                  'File Picker Error',
                  'Could not select attachment: $e',
                  backgroundColor: Colors.red.shade800,
                  colorText: Colors.white,
                );
              }
            }

            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _emerald.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assignment_return, color: _emerald, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rental Check-Out (OUT)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _charcoal,
                                ),
                              ),
                              Text(
                                '${rental['material_name']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryBlue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lightGray),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'IN: ${DateFormat('dd MMM yy, hh:mm a').format(DateTime.parse(rental['in_time']))}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _charcoal),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏱ ${_formatLiveDuration(rental['in_time'])}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _amber),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Out Site: [${selectedOutSite['site_id']}] ${selectedOutSite['site_name']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _emerald),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Return Remarks / Condition Notes',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _charcoal)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: outDescCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Returned in good condition, inspection verified',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: _bgLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _charcoal),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Optional Invoice / Supporting Attachments
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invoice / Attachments (Optional)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _charcoal),
                        ),
                        if (selectedAttachments.isNotEmpty)
                          Text(
                            '${selectedAttachments.length}/5 attached',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primaryBlue),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: pickAttachmentFiles,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _lightGray),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.upload_file_rounded, color: _primaryBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attach Invoice / Documents',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _charcoal),
                                  ),
                                  Text(
                                    'PDF, Image, Excel, Word or any format',
                                    style: TextStyle(fontSize: 11, color: _mediumGray),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.add_circle_outline, color: _primaryBlue, size: 20),
                          ],
                        ),
                      ),
                    ),

                    if (selectedAttachments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedAttachments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, idx) {
                          final f = selectedAttachments[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _lightGray),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _attachmentIcon(f.name),
                                  size: 18,
                                  color: _attachmentIconColor(f.name),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _charcoal),
                                      ),
                                      Text(
                                        _formatFileSize(f.size),
                                        style: const TextStyle(fontSize: 10, color: _mediumGray),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setOutState(() => selectedAttachments.removeAt(idx));
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_isLocationEnabled ? Colors.grey.shade400 : _emerald,
                          foregroundColor: _pureWhite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: Icon(!_isLocationEnabled ? Icons.location_off_rounded : Icons.camera_alt_outlined),
                        label: Text(
                          !_isLocationEnabled
                              ? 'GPS Disabled (Enable to Proceed)'
                              : 'Proceed to Camera (OUT)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: (!_isLocationEnabled)
                            ? () async {
                                final turnedOn = await _promptEnableLocation();
                                if (turnedOn) {
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, true);
                                  }
                                }
                              }
                            : () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (proceed != true) return;

    // Step 3: Open Camera Page with "SWIPE TO PROCEED" (Exact Attendance Camera Flow)
    final dynamic camResult = await Get.to(
      () => RentalCameraPage(
        title: 'Capture Material OUT',
        materialName: rental['material_name'] ?? 'Rental Item',
        actionType: 'RENTAL OUT',
        siteName: '[${selectedOutSite['site_id']}] ${selectedOutSite['site_name']}',
        extraDetails: {
          'ACTION': 'RENTAL OUT',
          'EQUIPMENT': rental['material_name'] ?? '',
          'OUT_SITE': '[${selectedOutSite['site_id']}] ${selectedOutSite['site_name']}',
          'DESC': outDescCtrl.text.trim().isNotEmpty ? outDescCtrl.text.trim() : 'Material Returned',
        },
      ),
      transition: Transition.downToUp,
    );

    if (camResult == null) return;

    File? capturedOutPhoto;
    String? lat;
    String? lng;

    if (camResult is Map) {
      capturedOutPhoto = camResult['file'] as File?;
      lat = camResult['lat']?.toString();
      lng = camResult['lng']?.toString();
    } else if (camResult is File) {
      capturedOutPhoto = camResult;
    }

    if (capturedOutPhoto == null) return;

    // Strict validation: location is mandatory for uploading!
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      try {
        final p = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        lat = p.latitude.toString();
        lng = p.longitude.toString();
      } catch (_) {}
    }

    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty || lat == 'null' || lng == 'null') {
      Get.snackbar(
        'GPS Location Mandatory',
        'Cannot upload rental check-out without valid GPS coordinates. Please enable location services and try again.',
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Step 4: Submit via Step-by-Step Dio Progress Page (Real-time KB, Speed, ETA)
    final mobileNow = DateTime.now();
    final mobileTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(mobileNow);

    final List<String> attachmentPaths = selectedAttachments
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();

    final progressResult = await Get.to(
      () => RentalProgressPage(
        isCheckOut: true,
        materialName: rental['material_name'] ?? 'Equipment',
        siteName: selectedOutSite['site_name'] ?? '',
        imagePath: capturedOutPhoto!.path,
        fields: {
          'rental_id': rental['id'].toString(),
          'out_user_id': _user?['id']?.toString() ?? '0',
          'out_user_name': _user?['username'] ?? 'User',
          'out_description': outDescCtrl.text.trim(),
          'out_site_id': selectedOutSite['site_id']?.toString() ?? '',
          'out_site_name': selectedOutSite['site_name']?.toString() ?? '',
          'out_time': mobileTimeStr,
          'attachment_paths': attachmentPaths,
          'lat': lat,
          'lng': lng,
        },
      ),
      transition: Transition.fadeIn,
    );

    if (progressResult != null && progressResult['success'] == true) {
      final resJson = progressResult['data'] ?? {};
      final durationStr = _formatCompletedDuration(Map<String, dynamic>.from(resJson));
      final matName = rental['material_name'] ?? 'Equipment';
      final outSite = selectedOutSite['site_name'] ?? 'Site';

      Get.dialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated success icon badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7), // soft emerald tint
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: _emerald,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Checked Out Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _charcoal,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  '$matName has been returned at $outSite.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _mediumGray,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),

                // Rental Duration Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _lightGray),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL RENTAL DURATION',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _mediumGray,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Primary Done Button (Charcoal)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _charcoal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
      _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Rental Materials',
          style: TextStyle(
            color: _charcoal,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _charcoal),
            onPressed: _loadInitialData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: _pureWhite,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // _xlGrey
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _lightGray),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicator: BoxDecoration(
                  color: _pureWhite,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: _charcoal.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: _charcoal,
                unselectedLabelColor: _mediumGray,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Active Rentals'),
                        if (_activeRentals.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_activeRentals.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Past History'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildSmoothExpandableFab(),
      body: Column(
        children: [
          if (!_isLocationEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade800,
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'GPS location is disabled. Rental check-in/out is locked until location is enabled.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: _promptEnableLocation,
                    child: const Text(
                      'ENABLE',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _charcoal))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.vertical) {
                        return false;
                      }
                      if (notification is UserScrollNotification) {
                        if (notification.direction == ScrollDirection.reverse) {
                          _setFabExtended(false);
                        } else if (notification.direction == ScrollDirection.forward) {
                          _setFabExtended(true);
                        }
                      } else if (notification is ScrollUpdateNotification &&
                          notification.metrics.pixels <= 8) {
                        _setFabExtended(true);
                      }
                      return false;
                    },
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveRentalsTab(),
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmoothExpandableFab() {
    return AnimatedBuilder(
      animation: _fabSizeCurve,
      builder: (context, child) {
        final t = _fabSizeCurve.value;
        final horizontalPad = 16.0 + (2.0 * t); // 16 -> 18 (collapsed 52x52 circle)
        return Material(
          color: _charcoal,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            onTap: _handleRentalCheckIn,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 52,
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _isLocationEnabled
                        ? Icons.add_a_photo_outlined
                        : Icons.location_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _fabSizeCurve.value,
                      heightFactor: 1.0,
                      child: FadeTransition(
                        opacity: _fabFadeCurve,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            _isLocationEnabled
                                ? 'Rental Check-In (IN)'
                                : 'GPS Disabled',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab 1: Active Rentals ──
  Widget _buildActiveRentalsTab() {
    if (_activeRentals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.construction_outlined, color: _mediumGray, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Active Rentals on Site',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _charcoal),
              ),
              const SizedBox(height: 6),
              const Text(
                'When equipment (crane, ladder, etc.) arrives on rent, tap "Rental Check-In (IN)" below to capture details.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _mediumGray),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _activeRentals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, i) {
          final item = _activeRentals[i];
          final rawInTime = DateTime.tryParse(item['in_time'] ?? '');
          final inTime = rawInTime != null ? (rawInTime.isUtc ? rawInTime.toLocal() : rawInTime) : null;

          return Container(
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: _lightGray),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Status badge & Running Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ON RENT',
                              style: TextStyle(color: _amber, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏱ ${_formatLiveDuration(item['in_time'])}',
                          style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Material Name & Thumbnail
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      GestureDetector(
                        onTap: () => _showImageDialog(
                          item['in_photo'],
                          '${item['material_name']} (IN Photo)',
                          lat: item['in_lat']?.toString(),
                          lng: item['in_lng']?.toString(),
                        ),
                        child: Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.black,
                            border: Border.all(color: _lightGray),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item['in_photo'] != null
                              ? Image.network(
                                  '${ApiService.baseUrl}${item['in_photo']}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, color: Colors.white54, size: 24),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.camera_alt, color: Colors.white54, size: 24),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['material_name'] ?? 'Equipment',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _charcoal,
                              ),
                            ),
                            if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item['description'],
                                style: const TextStyle(fontSize: 13, color: _mediumGray),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: _primaryBlue),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['in_site_id'] != null
                                        ? '[${item['in_site_id']}] ${item['in_site_name'] ?? ''}'
                                        : item['in_site_name'] ?? '—',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _charcoal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item['in_lat'] != null &&
                                    item['in_lat'].toString().isNotEmpty &&
                                    item['in_lat'] != 'null') ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _openMap(item['in_lat']?.toString(), item['in_lng']?.toString(), 'Arrival (IN)'),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _primaryBlue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _primaryBlue.withOpacity(0.2)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.map_outlined, size: 12, color: _primaryBlue),
                                          SizedBox(width: 4),
                                          Text('Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryBlue)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              inTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(inTime) : '—',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Return (OUT) Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocationEnabled ? _emerald : const Color(0xFFDC2626),
                        foregroundColor: _pureWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: Icon(_isLocationEnabled ? Icons.logout : Icons.location_off_rounded, size: 18),
                      label: Text(
                        _isLocationEnabled ? 'Rental Check-Out (OUT)' : 'Enable GPS to Check-Out',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      onPressed: () => _handleRentalCheckOut(item),
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

  // ── Tab 2: Past History ──
  Widget _buildHistoryTab() {
    final returnedLogs = _allLogs.where((l) => l['status'] == 'RETURNED').toList();
    final dateRangeLabel =
        '${DateFormat('dd MMM').format(_historyStartDate)} - ${DateFormat('dd MMM').format(_historyEndDate)}';

    return Column(
      children: [
        _RentalHistorySearchBar(
          initialValue: _historyQuery,
          hint: 'Search material, site, user...',
          dateRange: dateRangeLabel,
          onChanged: (val) {
            _historyQuery = val;
            _fetchAllLogs();
          },
          onFilter: _pickHistoryDateRange,
        ),
        Expanded(
          child: _isHistoryLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _charcoal, strokeWidth: 2.5),
                )
              : returnedLogs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history, color: _mediumGray, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No Past Rental History',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _historyQuery.isNotEmpty
                                  ? 'No records matching "$_historyQuery" in this date range.'
                                  : 'No completed rental records found for $dateRangeLabel.',
                              style: const TextStyle(fontSize: 12, color: _mediumGray),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _fetchAllLogs();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: returnedLogs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, i) {
          final item = returnedLogs[i];
          final rawInTime = DateTime.tryParse(item['in_time'] ?? '');
          final inTime = rawInTime != null ? (rawInTime.isUtc ? rawInTime.toLocal() : rawInTime) : null;
          final rawOutTime = DateTime.tryParse(item['out_time'] ?? '');
          final outTime = rawOutTime != null ? (rawOutTime.isUtc ? rawOutTime.toLocal() : rawOutTime) : null;
          final days = item['duration_days'] ?? 0;
          final hours = item['duration_hours'] ?? 0;

          return Container(
            decoration: BoxDecoration(
              color: _pureWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: _lightGray),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Equipment Name & Duration Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['material_name'] ?? 'Equipment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _charcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          _formatCompletedDuration(Map<String, dynamic>.from(item)),
                          style: TextStyle(
                            color: Colors.purple.shade800,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // In & Out Photos Row
                  Row(
                    children: [
                      // In Photo
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageDialog(
                              item['in_photo'],
                              '${item['material_name']} (IN)',
                              lat: item['in_lat']?.toString(),
                              lng: item['in_lng']?.toString(),
                            ),
                            child: Container(
                              width: 56,
                              height: 74,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black,
                                border: Border.all(color: _lightGray),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item['in_photo'] != null
                                  ? Image.network(
                                      '${ApiService.baseUrl}${item['in_photo']}',
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.camera_alt, color: Colors.white54),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('IN Photo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Out Photo
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageDialog(
                              item['out_photo'],
                              '${item['material_name']} (OUT)',
                              lat: item['out_lat']?.toString(),
                              lng: item['out_lng']?.toString(),
                            ),
                            child: Container(
                              width: 56,
                              height: 74,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black,
                                border: Border.all(color: _lightGray),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item['out_photo'] != null
                                  ? Image.network(
                                      '${ApiService.baseUrl}${item['out_photo']}',
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.camera_alt, color: Colors.white54),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('OUT Photo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _emerald)),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Details Column (Sites & Times)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // In Info
                            Row(
                              children: [
                                const Text('IN: ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _primaryBlue)),
                                Expanded(
                                  child: Text(
                                    inTime != null ? DateFormat('dd MMM yy, hh:mm a').format(inTime) : '—',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _charcoal),
                                  ),
                                ),
                                if (item['in_lat'] != null && item['in_lat'].toString().isNotEmpty && item['in_lat'] != 'null')
                                  InkWell(
                                    onTap: () => _openMap(item['in_lat']?.toString(), item['in_lng']?.toString(), 'Arrival (IN)'),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.map_outlined, size: 12, color: _primaryBlue),
                                          SizedBox(width: 2),
                                          Text('Map', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primaryBlue)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Site: [${item['in_site_id'] ?? '—'}] ${item['in_site_name'] ?? ''}',
                              style: const TextStyle(fontSize: 11, color: _mediumGray),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Divider(height: 10, color: _lightGray),

                            // Out Info (With Out Site ID clearly included)
                            Row(
                              children: [
                                const Text('OUT: ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _emerald)),
                                Expanded(
                                  child: Text(
                                    outTime != null ? DateFormat('dd MMM yy, hh:mm a').format(outTime) : '—',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _charcoal),
                                  ),
                                ),
                                if (item['out_lat'] != null && item['out_lat'].toString().isNotEmpty && item['out_lat'] != 'null')
                                  InkWell(
                                    onTap: () => _openMap(item['out_lat']?.toString(), item['out_lng']?.toString(), 'Return (OUT)'),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.map_outlined, size: 12, color: _emerald),
                                          SizedBox(width: 2),
                                          Text('Map', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _emerald)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Out Site: [${item['out_site_id'] ?? '—'}] ${item['out_site_name'] ?? ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _charcoal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (item['out_description'] != null && item['out_description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Remarks: ${item['out_description']}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: _mediumGray),
                    ),
                  ],

                  Builder(
                    builder: (_) {
                      final atts = _parseOutAttachments(Map<String, dynamic>.from(item));
                      if (atts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: atts.map((att) {
                            final name = att['name'] ?? 'Attachment';
                            final path = att['path'] ?? '';
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _openAttachment(path, name),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _bgLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _lightGray),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _attachmentIcon(name),
                                      size: 14,
                                      color: _attachmentIconColor(name),
                                    ),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: _charcoal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.open_in_new_rounded, size: 12, color: _primaryBlue),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ),
],
);
  }
}

class _RentalHistorySearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onFilter;
  final String? dateRange;
  final String initialValue;

  const _RentalHistorySearchBar({
    required this.onChanged,
    required this.hint,
    this.onFilter,
    this.dateRange,
    this.initialValue = '',
  });

  @override
  State<_RentalHistorySearchBar> createState() => _RentalHistorySearchBarState();
}

class _RentalHistorySearchBarState extends State<_RentalHistorySearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChange(String val) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onChanged(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 19,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onTextChange,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: const Color(0xFF64748B).withOpacity(0.65),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                setState(() {});
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                    size: 12,
                  ),
                ),
              ),
            ),
          if (widget.onFilter != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 1,
              height: 22,
              color: const Color(0xFFE2E8F0),
            ),
            InkWell(
              onTap: widget.onFilter,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
              child: SizedBox(
                height: 46,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Color(0xFF1E293B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.dateRange ?? 'Filter',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
