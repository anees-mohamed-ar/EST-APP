import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/api_service.dart';

// ─── Design tokens (mirror vehicle_page) ──────────────────────────────────
const _bg     = Color(0xFFF4F5F7);
const _white  = Color(0xFFFFFFFF);
const _black  = Color(0xFF0A0A0A);
const _grey   = Color(0xFF6B7280);
const _lgrey  = Color(0xFFE5E7EB);
const _xlGrey = Color(0xFFF3F4F6);
const _green  = Color(0xFF16A34A);
const _amber  = Color(0xFFD97706);
const _blue   = Color(0xFF2563EB);

/// Opens with [initialTab]: 0 = Trips, 1 = Fuel
class VehicleHistoryPage extends StatefulWidget {
  final int initialTab;
  const VehicleHistoryPage({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<VehicleHistoryPage> createState() => _VehicleHistoryPageState();
}

class _VehicleHistoryPageState extends State<VehicleHistoryPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final storage = GetStorage();
  Map<String, dynamic>? get _user => storage.read('user');

  // ── Trips state ────────────────────────────────────────────────────────────
  List<dynamic> _trips = [];
  bool _tripsLoading = true;
  bool _tripsLoadingMore = false;
  int _tripsPage = 1;
  int _tripsTotal = 0;
  static const int _limit = 20;
  final ScrollController _tripsScroll = ScrollController();

  // ── Fuel state ─────────────────────────────────────────────────────────────
  List<dynamic> _fuels = [];
  bool _fuelsLoading = true;
  bool _fuelsLoadingMore = false;
  int _fuelsPage = 1;
  int _fuelsTotal = 0;
  final ScrollController _fuelsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
        setState(() {});
      }
    });
    _loadTrips(refresh: true);
    _loadFuels(refresh: true);
    _tripsScroll.addListener(_onTripsScroll);
    _fuelsScroll.addListener(_onFuelsScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripsScroll.dispose();
    _fuelsScroll.dispose();
    super.dispose();
  }

  // ── Pagination scroll listeners ────────────────────────────────────────────
  void _onTripsScroll() {
    if (_tripsScroll.position.pixels >= _tripsScroll.position.maxScrollExtent - 100 &&
        !_tripsLoadingMore && _trips.length < _tripsTotal) {
      _loadTrips();
    }
  }

  void _onFuelsScroll() {
    if (_fuelsScroll.position.pixels >= _fuelsScroll.position.maxScrollExtent - 100 &&
        !_fuelsLoadingMore && _fuels.length < _fuelsTotal) {
      _loadFuels();
    }
  }

  // ── API calls ──────────────────────────────────────────────────────────────
  Future<void> _loadTrips({bool refresh = false}) async {
    if (refresh) {
      setState(() { _tripsLoading = true; _tripsPage = 1; _trips = []; });
    } else {
      setState(() => _tripsLoadingMore = true);
    }

    try {
      final page = refresh ? 1 : _tripsPage;
      final res = await http.get(Uri.parse(
        '${ApiService.baseUrl}/vehicles/trips/history?userId=${_user?['id']}&page=$page&limit=$_limit',
      ));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            if (refresh) {
              _trips = data['trips'];
            } else {
              _trips.addAll(data['trips']);
            }
            _tripsTotal = data['total'];
            _tripsPage  = page + 1;
          });
        }
      }
    } catch (_) {}

    setState(() { _tripsLoading = false; _tripsLoadingMore = false; });
  }

  Future<void> _loadFuels({bool refresh = false}) async {
    if (refresh) {
      setState(() { _fuelsLoading = true; _fuelsPage = 1; _fuels = []; });
    } else {
      setState(() => _fuelsLoadingMore = true);
    }

    try {
      final page = refresh ? 1 : _fuelsPage;
      final res = await http.get(Uri.parse(
        '${ApiService.baseUrl}/vehicles/fuel/history?userId=${_user?['id']}&page=$page&limit=$_limit',
      ));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            if (refresh) {
              _fuels = data['fuels'];
            } else {
              _fuels.addAll(data['fuels']);
            }
            _fuelsTotal = data['total'];
            _fuelsPage  = page + 1;
          });
        }
      }
    } catch (_) {}

    setState(() { _fuelsLoading = false; _fuelsLoadingMore = false; });
  }

  // ── Formatters ─────────────────────────────────────────────────────────────
  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) { return iso; }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }

  String _fmtDuration(String? startIso, String? endIso) {
    if (startIso == null || endIso == null) return '—';
    try {
      final diff = DateTime.parse(endIso).difference(DateTime.parse(startIso));
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
      return '${diff.inMinutes}m';
    } catch (_) { return '—'; }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripsList(),
                  _buildFuelsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 20, right: 20,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: _xlGrey, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black, letterSpacing: -0.5)),
              Text('Full trip & fuel records',
                style: TextStyle(fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _xlGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: _black,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: _white,
          unselectedLabelColor: _grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Trips${_tripsTotal > 0 ? ' ($_tripsTotal)' : ''}'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_gas_station_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Fuel${_fuelsTotal > 0 ? ' ($_fuelsTotal)' : ''}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trips list ─────────────────────────────────────────────────────────────
  Widget _buildTripsList() {
    if (_tripsLoading) {
      return const Center(child: CircularProgressIndicator(color: _black));
    }
    if (_trips.isEmpty) {
      return _buildEmpty('No trips recorded yet', Icons.route_rounded, _blue);
    }

    return RefreshIndicator(
      color: _black,
      onRefresh: () => _loadTrips(refresh: true),
      child: ListView.builder(
        controller: _tripsScroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _trips.length + (_tripsLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _trips.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: _black, strokeWidth: 2)),
            );
          }
          return _TripCard(trip: _trips[i], fmtDate: _fmtDate, fmtTime: _fmtTime, fmtDuration: _fmtDuration);
        },
      ),
    );
  }

  // ── Fuel list ──────────────────────────────────────────────────────────────
  Widget _buildFuelsList() {
    if (_fuelsLoading) {
      return const Center(child: CircularProgressIndicator(color: _black));
    }
    if (_fuels.isEmpty) {
      return _buildEmpty('No fuel logs yet', Icons.local_gas_station_rounded, _amber);
    }

    return RefreshIndicator(
      color: _black,
      onRefresh: () => _loadFuels(refresh: true),
      child: ListView.builder(
        controller: _fuelsScroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _fuels.length + (_fuelsLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _fuels.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: _black, strokeWidth: 2)),
            );
          }
          return _FuelCard(fuel: _fuels[i], fmtDate: _fmtDate, fmtTime: _fmtTime);
        },
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: _grey, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Trip card ──────────────────────────────────────────────────────────────
class _TripCard extends StatefulWidget {
  final dynamic trip;
  final String Function(String?) fmtDate;
  final String Function(String?) fmtTime;
  final String Function(String?, String?) fmtDuration;

  const _TripCard({
    required this.trip,
    required this.fmtDate,
    required this.fmtTime,
    required this.fmtDuration,
  });

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dist = widget.trip['distance'] ?? '—';
    final startDate = widget.fmtDate(widget.trip['start_time']?.toString());
    final startTime = widget.fmtTime(widget.trip['start_time']?.toString());
    final endTime   = widget.fmtTime(widget.trip['end_time']?.toString());
    final duration  = widget.fmtDuration(widget.trip['start_time']?.toString(), widget.trip['end_time']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lgrey),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_rounded, color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.trip['vehicle_name'] ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _black)),
                      Text(widget.trip['registration_number'] ?? '',
                        style: const TextStyle(fontSize: 12, color: _grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$dist km',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _black, fontSize: 18,
                        letterSpacing: -0.5)),
                    Text('distance',
                      style: const TextStyle(fontSize: 11, color: _grey)),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: _lgrey),

          // Detail row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _Detail(icon: Icons.calendar_today_rounded, label: 'Date', value: startDate, color: _blue),
                const SizedBox(width: 12),
                _Detail(
                  icon: Icons.play_arrow_rounded, 
                  label: 'Start', 
                  value: startTime, 
                  color: _green,
                ),
                const SizedBox(width: 12),
                _Detail(
                  icon: Icons.stop_rounded, 
                  label: 'End', 
                  value: endTime, 
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                _Detail(icon: Icons.timer_rounded, label: 'Duration', value: duration, color: _amber),
              ],
            ),
          ),

  // Odometer row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _xlGrey,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: _lgrey.withOpacity(0.5))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 14, color: _grey),
                      const SizedBox(width: 8),
                      Text(
                        'Odometer: ',
                        style: TextStyle(fontSize: 11, color: _grey.withOpacity(0.8), fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Text(
                          '${widget.trip['start_odometer']} km   →   ${widget.trip['end_odometer']} km',
                          style: const TextStyle(fontSize: 12, color: _black, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _grey,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.trip['start_photo'] != null)
                          Expanded(child: _PhotoBtn(label: 'START PHOTO', path: widget.trip['start_photo'], color: _blue)),
                        if (widget.trip['start_photo'] != null && widget.trip['end_photo'] != null)
                          const SizedBox(width: 10),
                        if (widget.trip['end_photo'] != null)
                          Expanded(child: _PhotoBtn(label: 'END PHOTO', path: widget.trip['end_photo'], color: _green)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Detail({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, 
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 12, color: _black, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Fuel card ──────────────────────────────────────────────────────────────
class _FuelCard extends StatelessWidget {
  final dynamic fuel;
  final String Function(String?) fmtDate;
  final String Function(String?) fmtTime;

  const _FuelCard({required this.fuel, required this.fmtDate, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final date = fmtDate(fuel['created_at']?.toString());
    final time = fmtTime(fuel['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lgrey),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: _amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fuel['vehicle_name'] ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _black)),
                      Text(fuel['registration_number'] ?? '',
                        style: const TextStyle(fontSize: 12, color: _grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${fuel['amount_paid']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _amber, fontSize: 18,
                        letterSpacing: -0.5)),
                    Text('paid',
                      style: const TextStyle(fontSize: 11, color: _grey)),
                  ],
                ),
              ],
            ),
          ),

          Container(height: 1, color: _lgrey),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _Detail(icon: Icons.calendar_today_rounded, label: 'Date', value: date, color: _blue),
                const SizedBox(width: 12),
                _Detail(icon: Icons.access_time_rounded, label: 'Time', value: time, color: _grey),
                const SizedBox(width: 12),
                _Detail(icon: Icons.water_drop_rounded, label: 'Litres', value: '${fuel['liters_filled']} L', color: _amber),
                const SizedBox(width: 12),
                _Detail(icon: Icons.speed_rounded, label: 'Odometer', value: '${fuel['odometer_reading']} km', color: _green),
              ],
            ),
          ),

          if (fuel['bill_photo'] != null)
            Container(
              decoration: const BoxDecoration(
                color: _xlGrey,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Receipt attached',
                    style: TextStyle(fontSize: 11, color: _grey, fontWeight: FontWeight.w600),
                  ),
                  _PhotoBtn(
                    label: 'VIEW BILL',
                    path: fuel['bill_photo'],
                    color: _amber,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
// ─── Shared photo button widget ──────────────────────────────────────────────
class _PhotoBtn extends StatelessWidget {
  final String label;
  final String path;
  final Color color;

  const _PhotoBtn({required this.label, required this.path, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPhoto(context, path, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  static void showPhoto(BuildContext context, String path, String title) {
    final fullUrl = '${ApiService.baseUrl}$path';
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
              decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: _white,
                    elevation: 0,
                    title: Text(title, style: const TextStyle(color: _black, fontSize: 16, fontWeight: FontWeight.w700)),
                    centerTitle: true,
                    leading: const SizedBox(),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _grey),
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
                          child: CircularProgressIndicator(
                            color: _black,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, color: _grey, size: 32),
                            SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: _grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
