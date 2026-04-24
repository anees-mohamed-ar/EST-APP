import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class AdminDashboardPage extends StatefulWidget {
  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final storage = GetStorage();
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  bool isRefreshing = false;

  // Pure black and white theme - no grays
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF333333);

  // Status indicator colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color errorRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
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
      if (mounted) {
        setState(() => isLoading = false);
        Get.snackbar(
          'Error',
          'Failed to load dashboard data',
          backgroundColor: errorRed,
          colorText: pureWhite,
        );
      }
    }
  }

  Future<void> _refreshData() async {
    if (isRefreshing) return;
    setState(() => isRefreshing = true);
    await _loadDashboardData();
    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // Today's status card - main focus
  Widget _buildTodayStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color statusColor,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16), // Reduced from 20
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pureBlack.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: pureBlack.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: statusColor),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, size: 14, color: darkGray),
              ],
            ),
            const SizedBox(height: 12), // Reduced from 16
            Text(
              value,
              style: const TextStyle(
                fontSize: 28, // Reduced from 32
                fontWeight: FontWeight.w700,
                color: pureBlack,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4
            Text(
              title,
              style: TextStyle(
                fontSize: 13, // Reduced from 14
                fontWeight: FontWeight.w500,
                color: darkGray,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4), // Reduced from 6
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11, // Reduced from 12
                  color: darkGray.withOpacity(0.7),
                ),
                maxLines: 2, // Prevent overflow with long text
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Quick insight card for additional metrics
  Widget _buildInsightCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ), // Reduced padding
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pureBlack.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32, // Reduced from 36
            height: 32, // Reduced from 36
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor), // Reduced from 18
          ),
          const SizedBox(width: 10), // Reduced from 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16, // Reduced from 18
                    fontWeight: FontWeight.w700,
                    color: pureBlack,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 12, color: darkGray)),
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
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final name = (userData['username'] ?? 'Admin').toString();

    if (isLoading) {
      return Scaffold(
        backgroundColor: pureWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: pureBlack,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading dashboard...',
                style: TextStyle(color: darkGray, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final stats = dashboardData?['stats'] ?? {};
    final totalEmployees = stats['totalEmployees'] ?? 0;
    final presentToday = stats['presentToday'] ?? 0;
    final absentToday = stats['absentToday'] ?? 0;
    final totalSites = stats['totalSites'] ?? 0;
    final activeSites = stats['activeSites'] ?? 0;
    final activeUsers = stats['activeUsers'] ?? 0;
    final pendingCheckouts = stats['pendingCheckouts'] ?? 0;
    final monthlyOtMinutes =
        int.tryParse(stats['monthlyOtMinutes']?.toString() ?? '0') ?? 0;
    final monthlyOtHours = monthlyOtMinutes ~/ 60;

    final attendanceRate = totalEmployees > 0
        ? ((presentToday / totalEmployees) * 100).round()
        : 0;
    final siteActivityRate = totalSites > 0
        ? ((activeSites / totalSites) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: pureBlack,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: pureBlack,
                    ),
                  )
                : Icon(Icons.refresh, color: pureBlack),
          ),
        ],
      ),
      body: ElectricRefreshIndicator(
        onRefresh: _loadDashboardData,
        color: pureBlack,
        backgroundColor: pureWhite,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $name',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: pureBlack,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat("EEEE, MMMM d, yyyy").format(now),
                            style: TextStyle(fontSize: 14, color: darkGray),
                          ),
                        ],
                      ),
                    ),

                    // Today's Status - Main Focus Area
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 4, height: 20, color: pureBlack),
                              const SizedBox(width: 8),
                              const Text(
                                "TODAY'S STATUS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: pureBlack,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                            children: [
                              _buildTodayStatusCard(
                                title: 'Present Today',
                                value: '$presentToday',
                                icon: Icons.check_circle_outline,
                                statusColor: successGreen,
                                subtitle: '$absentToday absent',
                                onTap: () => Get.toNamed('/admin-attendance'),
                              ),
                              _buildTodayStatusCard(
                                title: 'Active Sites',
                                value: '$activeSites',
                                icon: Icons.location_on_outlined,
                                statusColor: infoBlue,
                                subtitle: 'of $totalSites total sites',
                                onTap: () => Get.toNamed('/admin-sites'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Operational Reports Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 4, height: 20, color: pureBlack),
                              const SizedBox(width: 8),
                              const Text(
                                "OPERATIONAL REPORTS",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: pureBlack,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Get.toNamed('/fleet-reports'),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: pureWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: pureBlack.withOpacity(0.1), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: infoBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.airport_shuttle_rounded, size: 24, color: infoBlue),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Fleet & Vehicle Reports',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: pureBlack,
                                          ),
                                        ),
                                        Text(
                                          'Employee-wise trips & fuel logs',
                                          style: TextStyle(fontSize: 12, color: darkGray),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: darkGray.withOpacity(0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Alerts Section
                    // if (pendingCheckouts > 0) ...[
                    // Container(
                    //   padding: const EdgeInsets.all(16),
                    //   decoration: BoxDecoration(
                    //     color: warningOrange.withOpacity(0.1),
                    //     borderRadius: BorderRadius.circular(16),
                    //     border: Border.all(
                    //       color: warningOrange.withOpacity(0.3),
                    //       width: 1,
                    //     ),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Icon(
                    //         Icons.warning_amber_rounded,
                    //         color: warningOrange,
                    //         size: 24,
                    //       ),
                    //       const SizedBox(width: 12),
                    //       // Expanded(
                    //       //   child: Column(
                    //       //     crossAxisAlignment: CrossAxisAlignment.start,
                    //       //     children: [
                    //       //       Text(
                    //       //         '$pendingCheckouts employees missed check-out',
                    //       //         style: TextStyle(
                    //       //           fontSize: 14,
                    //       //           fontWeight: FontWeight.w600,
                    //       //           color: pureBlack,
                    //       //         ),
                    //       //       ),
                    //       //       Text(
                    //       //         'Requires immediate attention',
                    //       //         style: TextStyle(fontSize: 12, color: darkGray),
                    //       //       ),
                    //       //     ],
                    //       //   ),
                    //       // ),
                    //       TextButton(
                    //         onPressed: () => Get.toNamed('/admin-attendance'),
                    //         child: Text(
                    //           'View',
                    //           style: TextStyle(
                    //             color: warningOrange,
                    //             fontWeight: FontWeight.w600,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    // ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
