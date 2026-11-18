import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

// Design tokens matching EST Minimal & Obsidian system (mirrors admin_vehicle_reports_page)
const _bg = Color(0xFFF8FAFC);
const _white = Colors.white;
const _black = Color(0xFF0F172A); // Midnight Obsidian
const _grey = Color(0xFF64748B); // Cool Slate Grey
const _border = Color(0xFFE2E8F0);
const _xlGrey = Color(0xFFF1F5F9);
const _blue = Color(0xFF2563EB); // Electric Indigo Blue
const _amber = Color(0xFFD97706); // Warm Amber
const _green = Color(0xFF059669); // Emerald Green
const _purple = Color(0xFF7C3AED); // Royal Purple

class AdminRentalReportsPage extends StatefulWidget {
  const AdminRentalReportsPage({super.key});

  @override
  State<AdminRentalReportsPage> createState() => _AdminRentalReportsPageState();
}

class _AdminRentalReportsPageState extends State<AdminRentalReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  Map<String, dynamic>? _overview;

  // Logs & Audit tab state
  List<dynamic> _logs = [];
  bool _isLogsLoading = false;
  String _searchQuery = '';
  late DateTime _startDate;
  late DateTime _endDate;

  // Live active tab state
  List<dynamic> _activeLogs = [];
  Timer? _liveTicker;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 29));

    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    _fetchAll();

    _liveTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchOverview(),
      _fetchActiveRentals(),
      _fetchLogs(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchOverview() async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final res = await ApiService.getAdminRentalOverview(
        startDate: startStr,
        endDate: endStr,
      );
      if (res['success'] == true) {
        if (mounted) setState(() => _overview = res);
      }
    } catch (e) {
      debugPrint('Error fetching rental overview: $e');
    }
  }

  Future<void> _fetchActiveRentals() async {
    try {
      final res = await _getJson('${ApiService.baseUrl}/rental/active');
      if (res != null && res['success'] == true) {
        if (mounted) {
          setState(() {
            _activeLogs = res['logs'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching active: $e');
    }
  }

  Future<void> _fetchLogs() async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final q = _searchQuery.trim().isNotEmpty
          ? '&search=${Uri.encodeComponent(_searchQuery.trim())}'
          : '';
      final url =
          '${ApiService.baseUrl}/rental/logs?startDate=$startStr&endDate=$endStr$q&limit=500';

      final res = await _getJson(url);
      if (res != null && res['success'] == true) {
        if (mounted) {
          setState(() {
            _logs = res['logs'] ?? [];
            _isLogsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) setState(() => _isLogsLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('HTTP error for $url: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _black,
                      strokeWidth: 2.5,
                    ),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildOverviewTab(),
                      _buildLiveActiveTab(),
                      _buildAuditLogsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 18,
        right: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _black,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rental Admin Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _black,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Equipment, On-Rent & Audit Logs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchAll,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: _black,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Clean Pill Tabs matching MEPL App Theme
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _xlGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: false,
              indicator: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: _black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: _black,
              unselectedLabelColor: _grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Live Active'),
                Tab(text: 'Logs & Audit'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Overview Dashboard ──────────────────────────────────────────────
  Widget _buildOverviewTab() {
    if (_overview == null) return const SizedBox();
    final summary = _overview!['summary'] as Map<String, dynamic>? ?? {};
    final siteDist = _overview!['siteDistribution'] as List? ?? [];
    final topMats = _overview!['topMaterials'] as List? ?? [];
    final alerts = _overview!['longDurationAlerts'] as List? ?? [];
    final dateRangeLabel =
        '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter Banner Card
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: _black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      size: 16,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reporting Period',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _grey,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateRangeLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _black,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _xlGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 13, color: _black),
                          SizedBox(width: 5),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.55,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _metricCard(
                  'On-Rent Now',
                  '${summary['active_count'] ?? 0} items',
                  Icons.construction_rounded,
                  _amber,
                ),
                _metricCard(
                  'Billed Duration',
                  '${summary['total_hours_billed'] ?? 0} hrs',
                  Icons.timelapse_rounded,
                  _purple,
                ),
                _metricCard(
                  'Total Returned',
                  '${summary['returned_count'] ?? 0} cycles',
                  Icons.assignment_turned_in_rounded,
                  _green,
                ),
                _metricCard(
                  'Active Catalog',
                  '${summary['total_materials_count'] ?? 0} types',
                  Icons.inventory_2_rounded,
                  _blue,
                ),
              ],
            ),

            // Long Duration Alerts (Over 48 hours)
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Long Duration Alerts (> 48h)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _black,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alerts.length} Pending Attention',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...alerts.take(4).map((a) => _alertTile(a)),
            ],

            // Active Equipment by Site
            const SizedBox(height: 22),
            const Text(
              'Equipment Deployment by Site',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _black,
              ),
            ),
            const SizedBox(height: 10),
            if (siteDist.isEmpty)
              _emptyCard('No active equipment on any site')
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: siteDist.map((s) {
                    final count = int.tryParse('${s['active_count']}') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                size: 14, color: _blue),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['site_name'] ?? 'Site',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _black,
                                  ),
                                ),
                                Text(
                                  'ID: ${s['site_id'] ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: _grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: _amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count Active',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Top Rented Materials
            const SizedBox(height: 22),
            const Text(
              'High Demand Equipment (Total Volume)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _black,
              ),
            ),
            const SizedBox(height: 10),
            if (topMats.isEmpty)
              _emptyCard('No rental logs recorded yet')
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: topMats.map((m) {
                    final usage = int.tryParse('${m['usage_count']}') ?? 0;
                    final activeNow = int.tryParse('${m['active_now']}') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.handyman_rounded,
                                size: 14, color: _purple),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m['material_name'] ?? 'Equipment',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _black,
                              ),
                            ),
                          ),
                          if (activeNow > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$activeNow live',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _amber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '$usage rentals',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _grey,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            val,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: _black,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(Map<String, dynamic> a) {
    final days = int.tryParse('${a['days_active']}') ?? 0;
    final hours = int.tryParse('${a['hours_active']}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: Colors.amber.shade800, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['material_name'] ?? 'Equipment',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Site: ${a['in_site_name'] ?? '—'} (by ${a['user_name'] ?? 'User'})',
                  style: const TextStyle(fontSize: 11, color: _grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              days > 0 ? '$days d active' : '$hours hrs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Live Active Rentals ─────────────────────────────────────────────
  Widget _buildLiveActiveTab() {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Deployments Currently On-Rent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_overview?['summary']?['active_count'] ?? 0} Live',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activeLogs.isEmpty)
            _emptyCard('No active rentals deployed across any sites.')
          else ...[
            ...(_activeLogs.map((item) {
              return _liveActiveCard(item);
            })),
          ],
        ],
      ),
    );
  }

  Widget _liveActiveCard(Map<String, dynamic> item) {
    final rawIn = DateTime.tryParse(item['in_time'] ?? '');
    final inTime = rawIn != null ? (rawIn.isUtc ? rawIn.toLocal() : rawIn) : null;
    final photoUrl = item['in_photo'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['material_name'] ?? 'Equipment',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _calculateLiveElapsed(inTime),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showImageDialog(
                    photoUrl,
                    '${item['material_name'] ?? 'Equipment'} (Active Rental)',
                    lat: item['in_lat']?.toString(),
                    lng: item['in_lng']?.toString(),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '${ApiService.baseUrl}$photoUrl',
                      width: 44,
                      height: 56,
                      fit: BoxFit.cover,      
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 56,
                        color: _xlGrey,
                        child: const Icon(Icons.broken_image, size: 18, color: _grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site: [${item['in_site_id'] ?? '—'}] ${item['in_site_name'] ?? 'Site'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check-in: ${inTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(inTime) : '—'}',
                      style: const TextStyle(fontSize: 11, color: _grey),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'By: ${item['user_name'] ?? 'User'}',
                          style: const TextStyle(fontSize: 11, color: _grey),
                        ),
                        if (item['in_lat'] != null && item['in_lat'].toString().isNotEmpty && item['in_lat'] != 'null')
                          GestureDetector(
                            onTap: () => _openMap(item['in_lat'].toString(), item['in_lng']?.toString()),
                            child: const Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 13, color: _blue),
                                SizedBox(width: 2),
                                Text(
                                  'Map',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _blue,
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
            ],
          ),
        ],
      ),
    );
  }

  String _calculateLiveElapsed(DateTime? startTime) {
    if (startTime == null) return '—';
    final diff = DateTime.now().difference(startTime);
    if (diff.isNegative) return '0m';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return '${d}d ${h}h live';
    if (h > 0) return '${h}h ${m}m live';
    return '${m}m live';
  }

  void _openMap(String? lat, String? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
                          onPressed: () => _openMap(lat, lng),
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
                        onPressed: () => _openMap(lat, lng),
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

  // ── Tab 3: Complete Audit & Logs ───────────────────────────────────────────
  Widget _buildAuditLogsTab() {
    final dateRangeLabel =
        '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}';

    return Column(
      children: [
        _AdminRentalSearchBar(
          hint: 'Search material, site, employee...',
          dateRange: dateRangeLabel,
          onChanged: (val) {
            _searchQuery = val;
            _fetchLogs();
          },
          onFilter: _pickDateRange,
        ),
        Expanded(
          child: _isLogsLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _black,
                    strokeWidth: 2.5,
                  ),
                )
              : _logs.isEmpty
                  ? _emptyCard('No rental logs found for $dateRangeLabel')
                  : RefreshIndicator(
                      onRefresh: _fetchLogs,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final item = _logs[i];
                          return _auditLogItem(item);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _auditLogItem(Map<String, dynamic> item) {
    final isReturned = item['status'] == 'RETURNED';
    final rawIn = DateTime.tryParse(item['in_time'] ?? '');
    final inTime = rawIn != null ? (rawIn.isUtc ? rawIn.toLocal() : rawIn) : null;
    final rawOut = DateTime.tryParse(item['out_time'] ?? '');
    final outTime = rawOut != null ? (rawOut.isUtc ? rawOut.toLocal() : rawOut) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['material_name'] ?? 'Equipment',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReturned
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReturned
                        ? Colors.green.shade200
                        : Colors.amber.shade300,
                  ),
                ),
                child: Text(
                  isReturned
                      ? '${item['total_hours'] ?? 0} hrs (Returned)'
                      : 'Active On-Rent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isReturned
                        ? Colors.green.shade800
                        : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Side-by-side Inspection Photos Preview
          Row(
            children: [
              // Check-in preview
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      _miniThumb(
                        item['in_photo'],
                        '${item['material_name'] ?? 'Equipment'} (Check-in)',
                        lat: item['in_lat']?.toString(),
                        lng: item['in_lng']?.toString(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHECK-IN (IN)',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _blue,
                              ),
                            ),
                            Text(
                              inTime != null
                                  ? DateFormat('dd MMM, hh:mm a').format(inTime)
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              item['user_name'] ?? '—',
                              style: const TextStyle(
                                  fontSize: 10, color: _grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Return preview
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      _miniThumb(
                        item['out_photo'],
                        '${item['material_name'] ?? 'Equipment'} (Return)',
                        lat: item['out_lat']?.toString(),
                        lng: item['out_lng']?.toString(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RETURN (OUT)',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isReturned ? _green : _grey,
                              ),
                            ),
                            Text(
                              isReturned && outTime != null
                                  ? DateFormat('dd MMM, hh:mm a').format(outTime)
                                  : 'Ongoing',
                              style: const TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              item['out_user_name'] ?? '—',
                              style: const TextStyle(
                                  fontSize: 10, color: _grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Site: [${item['in_site_id'] ?? '—'}] ${item['in_site_name'] ?? 'Site'}',
            style: const TextStyle(fontSize: 11, color: _grey),
          ),

          Builder(
            builder: (_) {
              final List<Map<String, String>> atts = [];
              final raw = item['out_attachments'];
              if (raw != null && raw.toString().trim().isNotEmpty && raw.toString() != 'null') {
                try {
                  final decoded = raw is String ? jsonDecode(raw) : raw;
                  if (decoded is List) {
                    for (final entry in decoded) {
                      if (entry is Map && entry['path'] != null) {
                        final p = entry['path'].toString();
                        final n = (entry['name'] ?? p.split('/').last).toString();
                        if (p.isNotEmpty) atts.add({'path': p, 'name': n});
                      }
                    }
                  }
                } catch (_) {}
              }
              if (atts.isEmpty &&
                  item['out_attachment'] != null &&
                  item['out_attachment'].toString().isNotEmpty) {
                final p = item['out_attachment'].toString();
                final n = (item['out_attachment_name'] ?? p.split('/').last).toString();
                atts.add({'path': p, 'name': n});
              }
              if (atts.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: atts.map((att) {
                    final name = att['name'] ?? 'Attachment';
                    final path = att['path'] ?? '';
                    final lower = name.toLowerCase();
                    final isImg = lower.endsWith('.jpg') ||
                        lower.endsWith('.jpeg') ||
                        lower.endsWith('.png') ||
                        lower.endsWith('.webp') ||
                        lower.endsWith('.gif');
                    final isPdf = lower.endsWith('.pdf');
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        if (isImg) {
                          _showImageDialog(path, name);
                        } else {
                          final uri = Uri.parse('${ApiService.baseUrl}$path');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _xlGrey,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPdf
                                  ? Icons.picture_as_pdf_rounded
                                  : isImg
                                      ? Icons.image_outlined
                                      : Icons.attach_file_rounded,
                              size: 13,
                              color: isPdf ? const Color(0xFFDC2626) : _blue,
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new_rounded, size: 11, color: _grey),
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
    );
  }

  Widget _miniThumb(String? path, String label, {String? lat, String? lng}) {
    if (path == null || path.isEmpty) {
      return Container(
        width: 30,
        height: 38,
        decoration: BoxDecoration(
          color: _xlGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.hide_image_outlined, size: 14, color: _grey),
      );
    }
    return GestureDetector(
      onTap: () => _showImageDialog(path, label, lat: lat, lng: lng),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          '${ApiService.baseUrl}$path',
          width: 30,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 30,
            height: 38,
            color: _xlGrey,
            child: const Icon(Icons.broken_image, size: 14, color: _grey),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded, color: _grey, size: 28),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _grey),
          ),
        ],
      ),
    );
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _blue,
            onPrimary: Colors.white,
            onSurface: _black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isLogsLoading = true;
      });
      await Future.wait([_fetchOverview(), _fetchLogs()]);
    }
  }
}

// Compact Search bar matching vehicle report page
class _AdminRentalSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onFilter;
  final String? dateRange;

  const _AdminRentalSearchBar({
    required this.onChanged,
    required this.hint,
    this.onFilter,
    this.dateRange,
  });

  @override
  State<_AdminRentalSearchBar> createState() => _AdminRentalSearchBarState();
}

class _AdminRentalSearchBarState extends State<_AdminRentalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

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
      height: 48,
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: _grey,
              size: 19,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onTextChange,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _black,
              ),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: _grey.withOpacity(0.65),
                  fontSize: 13,
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
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _grey.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: _grey,
                    size: 13,
                  ),
                ),
              ),
            ),
          if (widget.onFilter != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 1,
              height: 24,
              color: _border,
            ),
            InkWell(
              onTap: widget.onFilter,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(14)),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: _black,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.dateRange ?? 'Filter',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _black,
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
