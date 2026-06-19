import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

class LongAbsenteesPage extends StatefulWidget {
  const LongAbsenteesPage({Key? key}) : super(key: key);

  @override
  State<LongAbsenteesPage> createState() => _LongAbsenteesPageState();
}

class _LongAbsenteesPageState extends State<LongAbsenteesPage> {
  List<dynamic> absentees = [];
  bool isLoading = true;
  String searchQuery = '';
  int minDays = 4;
  final TextEditingController _searchCtrl = TextEditingController();

  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);
  static const Color _softRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final result = await ApiService.getLongAbsentees(
        page: 1,
        limit: 100,
        search: searchQuery,
        minDays: minDays,
      );
      if (mounted) {
        setState(() {
          absentees = result['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load long absentees',
        backgroundColor: _softRed.withOpacity(0.1),
        colorText: _softRed,
      );
    }
  }

  void _onSearch(String val) {
    setState(() => searchQuery = val);
    _loadData();
  }

  void _showFilterSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: _pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTER ABSENTEES',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _mediumGray,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            _buildFilterOption('> 4 Days', 4),
            _buildFilterOption('> 7 Days', 7),
            _buildFilterOption('> 10 Days', 10),
            _buildFilterOption('> 14 Days', 14),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, int value) {
    final isSelected = minDays == value;
    return ListTile(
      onTap: () {
        setState(() => minDays = value);
        Get.back();
        _loadData();
      },
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? _charcoal : _mediumGray,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: _charcoal) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        title: const Text(
          'LONG ABSENTEES',
          style: TextStyle(
            color: _pureBlack,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: _pureBlack,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: _pureBlack),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name or role...',
                hintStyle: const TextStyle(color: _mediumGray, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: _mediumGray),
                filled: true,
                fillColor: _lightGray.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: ElectricRefreshIndicator(
        onRefresh: _loadData,
        color: _charcoal,
        backgroundColor: _pureWhite,
        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator(color: _pureBlack)),
                ],
              )
            : absentees.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_buildEmptyState()],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: absentees.length,
                    itemBuilder: (context, index) {
                      return _buildAbsenteeCard(absentees[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.check_circle_outline_rounded, size: 64, color: _lightGray),
          const SizedBox(height: 16),
          const Text(
            'No long absentees found',
            style: TextStyle(color: _mediumGray, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenteeCard(dynamic user) {
    final pfp = user['pfp'] as String?;
    final name = user['employee_name'] ?? user['username'] ?? 'User';
    final designation = user['designation'] ?? 'N/A';
    final absentDays = user['absent_days'] ?? 0;
    final lastSeen = user['last_attendance_date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _offWhite,
            ),
            clipBehavior: Clip.antiAlias,
            child: pfp != null && pfp.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: '${ApiService.baseUrl}$pfp',
                    fit: BoxFit.cover,
                  )
                : Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _charcoal,
                      ),
                    ),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _pureBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: const TextStyle(fontSize: 12, color: _mediumGray),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.history, size: 10, color: _mediumGray),
                    const SizedBox(width: 4),
                    Text(
                      lastSeen != null
                          ? 'Last seen: ${DateFormat('dd MMM yyyy').format(DateTime.parse(lastSeen))}'
                          : 'Never seen',
                      style: const TextStyle(fontSize: 10, color: _mediumGray),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _softRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$absentDays Days',
                  style: const TextStyle(
                    color: _softRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'ABSENT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _mediumGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
