import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';

class SitesPage extends StatefulWidget {
  @override
  _SitesPageState createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  List<dynamic> sites = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String searchQuery = '';

  // Theme colors
  static const Color primaryBlack = Color(0xFF000000);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color textLight = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Get active sites using the correct endpoint
      final sitesList = await ApiService.getActiveSites();

      if (mounted) {
        setState(() {
          sites = sitesList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sites: $e');
      if (mounted) {
        setState(() => isLoading = false);
        Get.snackbar(
          'Error',
          'Failed to load sites',
          backgroundColor: errorRed,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _refreshSites() async {
    if (isRefreshing) return;

    setState(() => isRefreshing = true);
    await _loadSites();
    setState(() => isRefreshing = false);
  }

  List<dynamic> get filteredSites {
    if (searchQuery.isEmpty) return sites;

    return sites.where((site) {
      final siteName = site['site_name']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return siteName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Active Sites',
          style: TextStyle(
            color: primaryBlack,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlack),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isRefreshing ? Icons.refresh : Icons.refresh,
              color: primaryBlack,
            ),
            onPressed: _refreshSites,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
              decoration: const InputDecoration(
                hintText: 'Search sites...',
                prefixIcon: Icon(Icons.search, color: textLight),
                border: InputBorder.none,
              ),
            ),
          ),

          // Sites List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryBlack),
                  )
                : filteredSites.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshSites,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredSites.length,
                      itemBuilder: (context, index) {
                        final site = filteredSites[index];
                        return _buildSiteCard(site, index);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSites = sites.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSites ? Icons.search_off : Icons.location_off,
            size: 64,
            color: textLight,
          ),
          const SizedBox(height: 16),
          Text(
            hasSites ? 'No sites found' : 'No sites available',
            style: const TextStyle(
              fontSize: 18,
              color: textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSites
                ? 'Try adjusting your search query'
                : 'There are no active sites to display',
            style: const TextStyle(fontSize: 14, color: textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(dynamic site, int index) {
    final siteName = site['site_name']?.toString() ?? 'Unknown Site';
    final activeCount = site['active_count'] ?? 0;
    final activeEmployees = site['active_employees'] as List? ?? [];
    final latestLogin = site['latest_login']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: successGreen.withOpacity(0.3)),
          ),
          child: const Icon(Icons.location_on, color: successGreen, size: 24),
        ),
        title: Text(
          siteName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryBlack,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: textLight),
                const SizedBox(width: 4),
                Text(
                  '$activeCount active users',
                  style: const TextStyle(fontSize: 14, color: textLight),
                ),
              ],
            ),
            if (latestLogin.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: textLight),
                  const SizedBox(width: 4),
                  Text(
                    'Latest: ${_formatTime(latestLogin)}',
                    style: const TextStyle(fontSize: 14, color: textLight),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 12,
                  color: successGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: textLight),
        onTap: () {
          // Show site details with active employees
          _showSiteDetails(siteName, activeCount, activeEmployees);
        },
      ),
    );
  }

  String _formatTime(String timeString) {
    try {
      // Handle full datetime strings like "2026-03-30T10:26:27"
      if (timeString.contains('T') && timeString.contains(':')) {
        // Parse as DateTime and format
        final dateTime = DateTime.parse(timeString);
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      }

      // Handle time strings with microseconds like "09:15:00.000000"
      if (timeString.contains(':') && timeString.contains('.')) {
        // Split by '.' to remove microseconds, then format
        final timeWithoutMicroseconds = timeString.split('.')[0];
        final parts = timeWithoutMicroseconds.split(':');

        if (parts.length >= 2) {
          final hour = parts[0].padLeft(2, '0');
          final minute = parts[1].padLeft(2, '0');
          final second = parts.length >= 3 ? parts[2].padLeft(2, '0') : '00';
          return '$hour:$minute:$second';
        }
      }

      // If it's already in HH:MM:SS format, return as is
      if (timeString.length <= 8 && timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length == 2) {
          // HH:MM format, add seconds
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00';
        } else if (parts.length == 3) {
          // HH:MM:SS format, ensure proper padding
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:${parts[2].padLeft(2, '0')}';
        }
      }

      // If it's a full datetime string, parse and format
      final dateTime = DateTime.parse(timeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // If parsing fails, return the original string
      return timeString;
    }
  }

  void _showSiteDetails(
    String siteName,
    int activeCount,
    List activeEmployees,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(siteName),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Users: $activeCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (activeEmployees.isNotEmpty) ...[
                const Text(
                  'Currently Active:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: activeEmployees.map(
                        (employee) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  (employee['username']?.toString() ?? 'U')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  employee['username']?.toString() ?? 'Unknown',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                _formatTime(employee['time']?.toString() ?? ''),
                                style: TextStyle(fontSize: 12, color: textLight),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'No active users at this site',
                  style: TextStyle(fontSize: 14, color: textLight),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }
}
