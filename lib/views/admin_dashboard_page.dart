import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final storage = GetStorage();
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  int _tab = 0; // 0=Overview, 1=Live, 2=Insights

  // Premium monochrome palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);

  // Accent colors
  static const Color _softGreen = Color(0xFF10B981);
  static const Color _softRed = Color(0xFFEF4444);
  static const Color _infoBlue = Color(0xFF3B82F6);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _setTab(int i) {
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getDashboardStats();
      if (mounted) {
        setState(() {
          dashboardData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _offWhite,
        body: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: _charcoal))
                      : dashboardData == null
                          ? _buildErrorContent()
                          : ElectricRefreshIndicator(
                              onRefresh: _loadDashboardData,
                              child: IndexedStack(
                                index: _tab,
                                children: [
                                  _buildOverviewTab(),
                                  _buildLiveTab(),
                                  _buildInsightsTab(),
                                ],
                              ),
                            ),
                ),
              ],
            ),
            // Floating dock navigation
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 20,
              right: 20,
              child: _buildDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final userData = storage.read('user') ?? {};
    final name = userData['username'] ?? 'Admin';

    return Container(
      color: _pureWhite,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _charcoal,
            child: Text(
              name.toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(color: _pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _charcoal,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: _mediumGray, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadDashboardData,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _lightGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.refresh_rounded, color: _charcoal, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  Widget _buildOverviewTab() {
    final stats = dashboardData?['stats'] ?? {};
    final weeklyTrend = dashboardData?['weeklyTrend'] as List<dynamic>? ?? [];
    
    final presentToday = _toInt(stats['presentToday']);
    final totalEmployees = _toInt(stats['totalEmployees']);
    final absentToday = _toInt(stats['absentToday']);
    final lateArrivals = _toInt(stats['lateArrivals']);
    
    final turnout = totalEmployees > 0 ? (presentToday / totalEmployees) : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTurnoutCard(turnout, presentToday, absentToday, totalEmployees),
          const SizedBox(height: 24),
          _buildSectionTitle('Attendance Trend (7 Days)'),
          const SizedBox(height: 12),
          _buildTrendChart(weeklyTrend),
          const SizedBox(height: 24),
          // const SizedBox(height: 24),
          // _buildStatCard(
          //   icon: Icons.account_tree_outlined,
          //   color: _charcoal,
          //   label: 'Approval Hierarchy',
          //   value: 'Reporting Lines',
          //   subtext: 'Manage who approves requests',
          //   onTap: () => Get.toNamed('/hierarchy'),
          // ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people_outline_rounded,
                  color: _infoBlue,
                  label: 'Total Staff',
                  value: '$totalEmployees',
                  subtext: '$lateArrivals late today',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer_outlined,
                  color: _purple,
                  label: 'Monthly OT',
                  value: '${_toInt(stats['monthlyOtMinutes']) ~/ 60}h',
                  subtext: 'Total hours',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    final recentActivity = dashboardData?['recentActivity'] as List<dynamic>? ?? [];
    final topSites = dashboardData?['topSites'] as List<dynamic>? ?? [];
    final activeSitesCount = (dashboardData?['stats'] ?? {})['activeSites'] ?? 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Active Sites ($activeSitesCount)'),
              TextButton(
                onPressed: () => Get.toNamed('/admin-sites'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('View All', style: TextStyle(color: _infoBlue, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSitesList(topSites),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Recent Activity'),
              TextButton(
                onPressed: () => Get.toNamed('/admin-attendance'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('View All', style: TextStyle(color: _infoBlue, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildActivityList(recentActivity),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    final topOt = dashboardData?['topOtEmployees'] as List<dynamic>? ?? [];
    final longAbsents = dashboardData?['topLongAbsents'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('OT Heavylifters (Month)'),
              TextButton(
                onPressed: () => Get.toNamed('/fleet-reports'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('View All', style: TextStyle(color: _purple, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildOTLeaderboard(topOt),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Long Absences (>4 Days)'),
              TextButton(
                onPressed: () => Get.toNamed('/admin-attendance'), // Assuming attendance is the best view for this
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('View All', style: TextStyle(color: _softRed, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildLongAbsentsList(longAbsents),
        ],
      ),
    );
  }

  Widget _buildTurnoutCard(double percent, int present, int absent, int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _pureBlack.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 8,
                  backgroundColor: _pureWhite.withOpacity(0.1),
                  color: _softGreen,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(color: _pureWhite, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Turnout",
                  style: TextStyle(color: _pureWhite, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$present of $total staff present',
                  style: TextStyle(color: _pureWhite.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _turnoutMiniStat('ABSENT', '$absent', _softRed),
                    const SizedBox(width: 16),
                    _turnoutMiniStat('ON-SITE', '$present', _softGreen),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnoutMiniStat(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _pureWhite.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w700)),
        Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildTrendChart(List<dynamic> trend) {
    if (trend.isEmpty) return _buildEmptyState('No trend data');
    
    final maxCount = trend.map((e) => _toInt(e['present_count'])).reduce((a, b) => a > b ? a : b);
    final displayMax = maxCount == 0 ? 10 : maxCount;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _lightGray),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: trend.map((day) {
          final count = _toInt(day['present_count']);
          final heightFactor = count / displayMax;
          final isToday = day['day_name'] == DateFormat('EEE').format(DateTime.now());

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isToday ? _charcoal : _mediumGray)),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 80 * heightFactor + 4,
                decoration: BoxDecoration(
                  color: isToday ? _charcoal : _lightGray,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
              const SizedBox(height: 6),
              Text(day['day_name'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _mediumGray)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color color, required String label, required String value, required String subtext, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _lightGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _charcoal)),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _mediumGray)),
            const SizedBox(height: 4),
            Text(subtext, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSitesList(List<dynamic> sites) {
    if (sites.isEmpty) return _buildEmptyState('No active sites');
    return Container(
      decoration: BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: _lightGray)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sites.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _lightGray, indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final s = sites[index];
          return ListTile(
            onTap: () => Get.toNamed('/admin-sites', parameters: {'site': s['site']}),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.location_on_outlined, color: _infoBlue),
            title: Text(s['site'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _charcoal)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _infoBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
              child: Text('${s['count']} Active', style: const TextStyle(color: _infoBlue, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityList(List<dynamic> activities) {
    if (activities.isEmpty) return _buildEmptyState('No activity today');
    return Container(
      decoration: BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: _lightGray)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _lightGray, indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final act = activities[index];
          final isIN = act['s_no'] == 1;
          return ListTile(
            onTap: () => Get.toNamed('/admin-attendance'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: _lightGray,
              backgroundImage: act['pfp'] != null ? NetworkImage('${ApiService.baseUrl}${act['pfp']}') : null,
              child: act['pfp'] == null ? Text(act['username'].toString()[0].toUpperCase()) : null,
            ),
            title: Text(act['username'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _charcoal)),
            subtitle: Text(act['site'] ?? 'N/A', style: const TextStyle(fontSize: 11, color: _mediumGray)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(act['time'].toString().substring(0, 5), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _charcoal)),
                Text(isIN ? 'CHECK-IN' : 'CHECK-OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isIN ? _softGreen : _softRed)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOTLeaderboard(List<dynamic> ot) {
    if (ot.isEmpty) return _buildEmptyState('No OT data yet');
    return Container(
      decoration: BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: _lightGray)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ot.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _lightGray, indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final emp = ot[index];
          final otMins = _toInt(emp['total_ot']);
          return ListTile(
            onTap: () => Get.toNamed('/fleet-reports'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: _mediumGray)),
            title: Text(emp['username'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _charcoal)),
            trailing: Text('${otMins ~/ 60}h ${otMins % 60}m', style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
          );
        },
      ),
    );
  }

  Widget _buildLongAbsentsList(List<dynamic> absents) {
    if (absents.isEmpty) return _buildEmptyState('All on track ✓');
    return Container(
      decoration: BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: _lightGray)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: absents.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _lightGray, indent: 20, endIndent: 20),
        itemBuilder: (context, index) {
          final emp = absents[index];
          return ListTile(
            onTap: () => Get.toNamed('/admin-attendance'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text(emp['username'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _charcoal)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _softRed.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
              child: Text('${emp['absent_days']} Days', style: const TextStyle(color: _softRed, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _mediumGray, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _pureWhite, borderRadius: BorderRadius.circular(24), border: Border.all(color: _lightGray)),
      child: Center(child: Text(msg, style: const TextStyle(color: _mediumGray, fontSize: 13, fontWeight: FontWeight.w500))),
    );
  }

  Widget _buildDock() {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                left: _dockPillLeft() + 4,
                top: 0,
                bottom: 0,
                child: Container(
                  width: _dockPillWidth() - 8,
                  decoration: BoxDecoration(
                    color: _pureWhite,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Row(
                children: [
                  _dockItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Status'),
                  _dockItem(1, Icons.sensors_rounded, Icons.sensors_outlined, 'Live'),
                  _dockItem(2, Icons.analytics_rounded, Icons.analytics_outlined, 'Analysis'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dockPillLeft() {
    final width = MediaQuery.of(context).size.width - 40; 
    final itemWidth = (width - 16) / 3;
    return _tab * itemWidth;
  }

  double _dockPillWidth() {
    final width = MediaQuery.of(context).size.width - 40;
    return (width - 16) / 3;
  }

  Widget _dockItem(int index, IconData active, IconData inactive, String label) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? active : inactive, 
              color: isActive ? _charcoal : _mediumGray, 
              size: 20
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? _charcoal : _mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: _softRed),
          const SizedBox(height: 16),
          const Text('Failed to load dashboard', style: TextStyle(color: _charcoal, fontSize: 16, fontWeight: FontWeight.w600)),
          TextButton(onPressed: _loadDashboardData, child: const Text('Try Again', style: TextStyle(color: _softGreen))),
        ],
      ),
    );
  }
}
