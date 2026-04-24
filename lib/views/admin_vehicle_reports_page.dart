import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// Colors - matching the premium theme
const _bg      = Color(0xFFF8FAFC);
const _white   = Colors.white;
const _black   = Color(0xFF0F172A);
const _grey    = Color(0xFF64748B);
const _xlGrey  = Color(0xFFF1F5F9);
const _blue    = Color(0xFF3B82F6);
const _amber   = Color(0xFFF59E0B);
const _green   = Color(0xFF10B981);
const _indigo  = Color(0xFF6366F1);


class AdminVehicleReportsPage extends StatefulWidget {
  const AdminVehicleReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminVehicleReportsPage> createState() => _AdminVehicleReportsPageState();
}

class _AdminVehicleReportsPageState extends State<AdminVehicleReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  Map<String, dynamic>? _overview;
  
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAdminVehicleOverview();
      if (res['success']) {
        setState(() => _overview = res);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load report: $e', 
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
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
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildOverviewTab(),
                    _buildTripsTab(),
                    _buildFuelTab(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 0, left: 20, right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _xlGrey, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            const Text('Fleet Reports', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _black, letterSpacing: -0.5)),
            const Spacer(),
            GestureDetector(
              onTap: _fetch,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _xlGrey, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.refresh_rounded, color: _black, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabCtrl,
            isScrollable: false,
            indicatorColor: _blue,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelColor: _blue,
            unselectedLabelColor: _grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Summary'),
              Tab(text: 'Logbook'),
              Tab(text: 'Fuel'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overview Tab ───────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    if (_overview == null) return const SizedBox();
    final summary = _overview!['summary'] as Map<String, dynamic>? ?? {};
    final emps = _overview!['employees'] as List? ?? [];
    final vehs = _overview!['vehicles'] as List? ?? [];
    final active = _overview!['activeTrips'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Metrics Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _metricCard('Total Distance', '${summary['totalDistance'] ?? 0} km', Icons.route_rounded, _indigo),
            _metricCard('Active Trips', '${summary['activeTripsCount'] ?? 0}', Icons.local_shipping_rounded, _green),
            _metricCard('Total Fuel', '₹${summary['totalFuelSpend'] ?? 0}', Icons.local_gas_station_rounded, _amber),
            _metricCard('Total Trips', '${summary['totalTrips'] ?? 0}', Icons.history_rounded, _blue),
          ],
        ),

        if (active.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SecHead('Current Active Trips'),
          const SizedBox(height: 12),
          ...active.take(3).map((a) => _activeTripTile(a)),
          if (active.length > 3)
            TextButton(onPressed: () => _tabCtrl.animateTo(1), child: const Text('View all active trips')),
        ],

        const SizedBox(height: 24),
        const _SecHead('Employee Wise Usage'),
        const SizedBox(height: 12),
        ...emps.take(5).map((e) => _empStatTile(e)),
        TextButton(
          onPressed: () => _showAllStats('Employees', emps, isEmp: true),
          child: const Text('View All Employees'),
        ),

        const SizedBox(height: 24),
        const _SecHead('Vehicle Wise Usage'),
        const SizedBox(height: 12),
        ...vehs.take(5).map((v) => _vehStatTile(v)),
        TextButton(
          onPressed: () => _showAllStats('Vehicles', vehs, isEmp: false),
          child: const Text('View All Vehicles'),
        ),
        
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _metricCard(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _grey)),
          ]),
          Text(val, 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _black)),
        ],
      ),
    );
  }

  Widget _activeTripTile(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark stylish card for active
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _white.withOpacity(0.1),
          backgroundImage: a['pfp'] != null ? NetworkImage('${ApiService.baseUrl}${a['pfp']}') : null,
          child: a['pfp'] == null ? const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20) : null,
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['employee_name'] ?? 'Driver', style: const TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w900)),
          Text('${a['vehicle_name']} • ${a['registration_number']}', 
              style: TextStyle(color: _white.withOpacity(0.6), fontSize: 10)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: const Text('LIVE', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _empStatTile(Map<String, dynamic> e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _xlGrey),
        boxShadow: [BoxShadow(color: _black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _xlGrey,
              backgroundImage: e['pfp'] != null ? NetworkImage('${ApiService.baseUrl}${e['pfp']}') : null,
              child: e['pfp'] == null ? const Icon(Icons.person, color: _grey, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['employee_name'] ?? 'Unknown', 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _black)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: Text('ID: ${e['employee_id'] ?? 'N/A'}', style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${e['totalFuelSpend']}', style: const TextStyle(fontWeight: FontWeight.w900, color: _amber, fontSize: 16)),
              const Text('Total Spend', style: TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: _xlGrey)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _tileMiniMetric(Icons.route_rounded, '${e['total_distance']} km', 'Distance', _indigo),
            _tileMiniMetric(Icons.history_rounded, '${e['total_trips']}', 'Trips', _blue),
            _tileMiniMetric(
              Icons.local_gas_station_rounded, 
              '₹${((double.tryParse(e['totalFuelSpend']?.toString() ?? '0') ?? 0) / (double.tryParse(e['total_trips']?.toString() ?? '1') ?? 1).clamp(1, 9999999)).toStringAsFixed(0)}', 
              'Avg/Trip', 
              _amber
            ),
          ]),
        ],
      ),
    );
  }

  Widget _vehStatTile(Map<String, dynamic> v) {
    // Safely calculate averages to avoid division by zero or type errors
    final double dist = double.tryParse(v['total_distance']?.toString() ?? '0') ?? 0;
    final int trips = int.tryParse(v['total_trips']?.toString() ?? '1') ?? 1;
    final double fuel = double.tryParse(v['totalFuelSpend']?.toString() ?? '0') ?? 0;
    
    final avgDist = dist / trips.clamp(1, 9999999);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _xlGrey),
        boxShadow: [BoxShadow(color: _black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _xlGrey, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_car_rounded, color: _blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v['name'] ?? 'Vehicle', 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _black)),
              Text(v['registration_number'] ?? '', style: const TextStyle(color: _grey, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${v['total_distance']} km', style: const TextStyle(fontWeight: FontWeight.w900, color: _indigo, fontSize: 16)),
              const Text('Total Odo', style: TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: _xlGrey)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _tileMiniMetric(Icons.history_rounded, '$trips', 'Trips', _blue),
            _tileMiniMetric(Icons.speed_rounded, '${avgDist.toStringAsFixed(1)} km', 'Avg/Trip', _green),
            _tileMiniMetric(Icons.local_gas_station_rounded, '₹${fuel.toStringAsFixed(0)}', 'Fuel Cost', _amber),
          ]),
        ],
      ),
    );
  }

  Widget _tileMiniMetric(IconData icon, String val, String label, Color color) {
    return Column(children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _black)),
      ]),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.bold)),
    ]);
  }

  void _showAllStats(String title, List<dynamic> data, {required bool isEmp}) {
    String query = '';
    String sortBy = isEmp ? 'Spend' : 'Distance';

    Get.bottomSheet(
      StatefulBuilder(builder: (context, setModalState) {
        // Filtering
        List filtered = data.where((item) {
          final name = (isEmp ? item['employee_name'] : item['name']).toString().toLowerCase();
          final sub = (isEmp ? (item['employee_id'] ?? '') : (item['registration_number'] ?? '')).toString().toLowerCase();
          return name.contains(query.toLowerCase()) || sub.contains(query.toLowerCase());
        }).toList();

        // Sorting
        filtered.sort((a, b) {
          if (sortBy == 'Distance') return (b['total_distance'] ?? 0).compareTo(a['total_distance'] ?? 0);
          if (sortBy == 'Trips') return (b['total_trips'] ?? 0).compareTo(a['total_trips'] ?? 0);
          if (sortBy == 'Spend') {
            final valA = double.tryParse((isEmp ? (a['totalFuelSpend']) : (a['totalFuelSpend']))?.toString() ?? '0') ?? 0;
            final valB = double.tryParse((isEmp ? (b['totalFuelSpend']) : (b['totalFuelSpend']))?.toString() ?? '0') ?? 0;
            return valB.compareTo(valA);
          }
          return 0;
        });

        return Container(
          height: Get.height * 0.9,
          decoration: const BoxDecoration(color: _bg, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _grey.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _black, letterSpacing: -0.5)),
                const Spacer(),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close_rounded, color: _grey)),
              ]),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                onChanged: (v) => setModalState(() => query = v),
                decoration: InputDecoration(
                  hintText: 'Search by ${isEmp ? "name or id" : "vehicle or number"}...',
                  hintStyle: const TextStyle(color: _grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
                  filled: true,
                  fillColor: _white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),

            // Sorting Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                _sortBtn('Distance', sortBy == 'Distance', () => setModalState(() => sortBy = 'Distance')),
                const SizedBox(width: 8),
                _sortBtn('Trips', sortBy == 'Trips', () => setModalState(() => sortBy = 'Trips')),
                const SizedBox(width: 8),
                _sortBtn(isEmp ? 'Spend' : 'Fuel Cost', sortBy == 'Spend', () => setModalState(() => sortBy = 'Spend')),
              ]),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: filtered.length,
                itemBuilder: (c, i) => isEmp ? _empStatTile(filtered[i]) : _vehStatTile(filtered[i]),
              ),
            ),
          ]),
        );
      }),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  Widget _sortBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _black : _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _black : _xlGrey),
          ),
          child: Text(label, 
              textAlign: TextAlign.center,
              style: TextStyle(color: active ? _white : _grey, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Trips Tab ─────────────────────────────────────────────────────────────
  Widget _buildTripsTab() {
    return _AdminTripList();
  }

  // ── Fuel Tab ──────────────────────────────────────────────────────────────
  Widget _buildFuelTab() {
    return _AdminFuelList();
  }
}

class _SecHead extends StatelessWidget {
  final String title;
  const _SecHead(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF64748B).withOpacity(0.8), letterSpacing: 1));
  }
}

// ── Trip Log View ──────────────────────────────────────────────────────────
class _AdminTripList extends StatefulWidget {
  @override
  State<_AdminTripList> createState() => _AdminTripListState();
}

class _AdminTripListState extends State<_AdminTripList> {
  final List<dynamic> _trips = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String _query = '';
  Timer? _debounce;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _query = q;
          _trips.clear();
          _page = 1;
          _hasMore = true;
          _loading = true;
        });
        _fetch();
      }
    });
  }

  Future<void> _fetch() async {
    if (!_hasMore) return;
    try {
      final res = await ApiService.getAdminTrips(
        page: _page, 
        search: _query,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );
      if (res['success']) {
        final List newTrips = res['trips'];
        setState(() {
          _trips.addAll(newTrips);
          _loading = false;
          _page++;
          if (newTrips.length < 30) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue, onPrimary: Colors.white, onSurface: _black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _trips.clear();
        _page = 1;
        _hasMore = true;
        _loading = true;
      });
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactSearch(
          onChanged: _onSearch, 
          hint: 'Search by employee or vehicle...',
          onFilter: _pickDateRange,
          dateRange: '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
        ),
        Expanded(
          child: _loading && _trips.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : NotificationListener<ScrollNotification>(
                  onNotification: (sn) {
                    if (sn is ScrollEndNotification && sn.metrics.extentAfter < 500) _fetch();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: _trips.length + (_hasMore ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == _trips.length)
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      final t = _trips[i];
                      return _tripItem(t);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tripItem(Map<String, dynamic> t) {
    final start = DateTime.tryParse(t['start_time'] ?? '')?.toLocal();
    final end = DateTime.tryParse(t['end_time'] ?? '')?.toLocal();
    final dateStr = start != null ? DateFormat('dd MMM, yyyy').format(start) : '--';
    
    final sPhoto = t['start_photo'] ?? t['start_odo_photo'] ?? t['start_odo_image'];
    final ePhoto = t['end_photo'] ?? t['end_odo_photo'] ?? t['end_odo_image'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: t['pfp'] != null ? NetworkImage('${ApiService.baseUrl}${t['pfp']}') : null,
            child: t['pfp'] == null ? const Icon(Icons.person, size: 14) : null,
          ),
          const SizedBox(width: 10),
          Text(t['employee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const Spacer(),
          Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('VEHICLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            Text(t['vehicle_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            Text(t['registration_number'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('${t['distance']} km', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900, fontSize: 15)),
              const Text('DISTANCE', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 8, fontWeight: FontWeight.w800)),
            ]),
          )
        ]),
        const SizedBox(height: 12),
        // Route Section
        if (t['start_loc'] != null || t['end_loc'] != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: _blue),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _locLink(t['start_loc'], t['start_lat'], t['start_lng']),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ),
                    _locLink(t['end_loc'], t['end_lat'], t['end_lng']),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _odoPoint('START', t['start_odometer']?.toString() ?? '0', start),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
          _odoPoint('END', t['end_odometer']?.toString() ?? '0', end),
        ]),

        // Photo Previews
        if (sPhoto != null || ePhoto != null) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          const Text('ODOMETER VERIFICATION', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(children: [
            if (sPhoto != null)
              Expanded(child: _PhotoBtn(label: 'START PHOTO', path: sPhoto, color: _blue)),
            if (sPhoto != null && ePhoto != null)
              const SizedBox(width: 10),
            if (ePhoto != null)
              Expanded(child: _PhotoBtn(label: 'END PHOTO', path: ePhoto, color: _green)),
          ]),
        ],
      ]),
    );
  }



  Widget _odoPoint(String label, String val, DateTime? time) {
    final tStr = time != null ? DateFormat('hh:mm a').format(time) : '--:--';
    return Column(crossAxisAlignment: label == 'START' ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
      Text('$val km', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
      Text(tStr, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _locLink(String? name, dynamic lat, dynamic lng) {
    final hasCoords = lat != null && lng != null;
    return GestureDetector(
      onTap: hasCoords ? () => _launchMaps(lat, lng) : null,
      child: Text(
        name ?? '—',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: hasCoords ? _blue : const Color(0xFF475569),
          decoration: hasCoords ? TextDecoration.underline : null,
          decorationColor: _blue.withOpacity(0.4),
        ),
      ),
    );
  }

  Future<void> _launchMaps(dynamic lat, dynamic lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

// ── Fuel Log View ───────────────────────────────────────────────────────────
class _AdminFuelList extends StatefulWidget {
  @override
  State<_AdminFuelList> createState() => _AdminFuelListState();
}

class _AdminFuelListState extends State<_AdminFuelList> {
  final List<dynamic> _fuels = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String _query = '';
  Timer? _debounce;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _query = q;
          _fuels.clear();
          _page = 1;
          _hasMore = true;
          _loading = true;
        });
        _fetch();
      }
    });
  }

  Future<void> _fetch() async {
    if (!_hasMore) return;
    try {
      final res = await ApiService.getAdminFuel(
        page: _page, 
        search: _query,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );
      if (res['success']) {
        final List newFuels = res['fuels'];
        setState(() {
          _fuels.addAll(newFuels);
          _loading = false;
          _page++;
          if (newFuels.length < 30) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _amber, onPrimary: Colors.white, onSurface: _black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _fuels.clear();
        _page = 1;
        _hasMore = true;
        _loading = true;
      });
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactSearch(
          onChanged: _onSearch, 
          hint: 'Search fuel logs...',
          onFilter: _pickDateRange,
          dateRange: '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
        ),
        Expanded(
          child: _loading && _fuels.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _amber))
              : NotificationListener<ScrollNotification>(
                  onNotification: (sn) {
                    if (sn is ScrollEndNotification && sn.metrics.extentAfter < 500) _fetch();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: _fuels.length + (_hasMore ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == _fuels.length)
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      final f = _fuels[i];
                      return _fuelItem(f);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _fuelItem(Map<String, dynamic> f) {
    final date = DateTime.tryParse(f['created_at'] ?? '')?.toLocal();
    final dateStr = date != null ? DateFormat('dd MMM, hh:mm a').format(date) : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f['employee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(f['vehicle_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
              Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${f['amount_paid']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
              Text('${f['liters_filled']} Liters', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
            ]),
          ]),
          
          if (f['bill_photo'] != null && f['bill_photo'] != '') ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
            _PhotoBtn(label: 'VIEW FUEL BILL', path: f['bill_photo']!, color: _amber),
          ],
        ],
      ),
    );
  }

}

// ── Shared photo button widget ──────────────────────────────────────────────
class _PhotoBtn extends StatelessWidget {
  final String label;
  final String path;
  final Color color;

  const _PhotoBtn({required this.label, required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhoto(context, path, label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showPhoto(BuildContext context, String path, String title) {
    final fullUrl = path.startsWith('http') ? path : '${ApiService.baseUrl}$path';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    title: Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
                    centerTitle: true,
                    leading: const SizedBox(),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(color: Color(0xFF0F172A)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, color: Color(0xFF64748B), size: 32),
                            SizedBox(height: 8),
                            Text('Photo unavailable', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onFilter;
  final String? dateRange;
  const _CompactSearch({required this.onChanged, required this.hint, this.onFilter, this.dateRange});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 48,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _black),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 4),
            Container(width: 1.5, height: 20, color: _grey.withOpacity(0.15)),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onFilter,
              icon: const Icon(Icons.calendar_today_rounded, size: 13, color: _blue),
              label: Text(dateRange ?? 'Filter', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _blue)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


