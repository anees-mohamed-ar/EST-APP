import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class SitesPage extends StatefulWidget {
  const SitesPage({Key? key}) : super(key: key);

  @override
  _SitesPageState createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  List<dynamic> sites = [];
  bool isLoading = true;
  String searchQuery = '';

  // Minimalist Palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _bgSoft = Color(0xFFFAFAFA);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textDim = Color(0xFF757575);
  static const Color _accent = Color(0xFF1A1A1A);
  static const Color _softGray = Color(0xFFF0F0F0);
  static const Color _success = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => isLoading = true);
    try {
      final sitesList = await ApiService.getActiveSites();
      if (mounted) {
        setState(() {
          sites = sitesList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredSites {
    if (searchQuery.isEmpty) return sites;
    return sites.where((site) {
      final siteName = site['site_name']?.toString().toLowerCase() ?? '';
      return siteName.contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgSoft,
        body: Column(
          children: [
            _buildHeader(),
            _buildSearch(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                  : ElectricRefreshIndicator(
                      onRefresh: _loadSites,
                      child: filteredSites.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              itemCount: filteredSites.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _buildMinimalCard(filteredSites[index]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 10,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textMain, size: 20),
          ),
          const Text(
            'Sites',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textMain, letterSpacing: -0.5),
          ),
          const SizedBox(width: 20), // Balance the back icon
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      height: 48,
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textMain),
        decoration: const InputDecoration(
          hintText: 'Search site...',
          hintStyle: TextStyle(color: _textDim, fontWeight: FontWeight.w400, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: _textDim, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMinimalCard(dynamic site) {
    final siteName = site['site_name']?.toString() ?? 'Unknown';
    final activeCount = site['active_count'] ?? 0;
    final activeEmployees = site['active_employees'] as List? ?? [];

    return GestureDetector(
      onTap: () => _showSiteDetails(siteName, activeCount, activeEmployees),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _softGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded, color: _textMain, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    siteName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$activeCount active right now',
                    style: const TextStyle(fontSize: 12, color: _textDim, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: _success, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  void _showSiteDetails(String siteName, int activeCount, List activeEmployees) {
    Get.bottomSheet(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: const BoxDecoration(
            color: _pureWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: _softGray, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(siteName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textMain)),
                        Text('$activeCount staff members', style: const TextStyle(fontSize: 13, color: _textDim, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close_rounded, color: _textDim, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (activeEmployees.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = activeEmployees[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 18, color: _textDim),
                            const SizedBox(width: 10),
                            Expanded(child: Text(emp['username'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textMain))),
                            Text(_formatTime(emp['time']?.toString() ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMain)),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No active users', style: TextStyle(color: _textDim)),
                ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  String _formatTime(String timeString) {
    try {
      if (timeString.contains('T')) return DateFormat('h:mm a').format(DateTime.parse(timeString));
      if (timeString.contains(':')) {
        final p = timeString.split(':');
        return DateFormat('h:mm a').format(DateTime(2024, 1, 1, int.parse(p[0]), int.parse(p[1])));
      }
      return timeString;
    } catch (_) {
      return timeString;
    }
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No sites found', style: TextStyle(color: _textDim, fontWeight: FontWeight.w600)));
  }
}
