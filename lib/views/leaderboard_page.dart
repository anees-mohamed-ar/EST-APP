import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final storage = GetStorage();
  List<dynamic> top10 = [];
  Map<String, dynamic>? userRank;
  bool isLoading = true;
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Sophisticated monochrome palette
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _offWhite = Color(0xFFF8F8F8);
  static const Color _lightGray = Color(0xFFEEEEEE);
  static const Color _mediumGray = Color(0xFF9E9E9E);
  static const Color _charcoal = Color(0xFF2C2C2C);
  static const Color _pureBlack = Color(0xFF000000);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => isLoading = true);
    try {
      final userData = storage.read('user');
      final userId = userData != null ? userData['id'] : null;
      
      final result = await ApiService.getLeaderboard(
        userId: userId,
        month: selectedMonth,
      );

      if (mounted) {
        setState(() {
          top10 = result['top10'] ?? [];
          userRank = result['userRank'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load leaderboard',
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  String _formatMinutes(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      appBar: AppBar(
        backgroundColor: _pureWhite,
        elevation: 0,
        title: const Text(
          'OT LEADERBOARD',
          style: TextStyle(
            color: _pureBlack,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _pureBlack, size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: _pureBlack),
            onPressed: () => _showMonthPicker(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _pureBlack))
          : top10.isEmpty
              ? _buildEmptyState()
              : Stack(
                  children: [
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildPodium(),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                // Skip first 3 as they are in podium
                                if (index < 3) return const SizedBox.shrink();
                                final emp = top10[index];
                                return _buildListTile(emp, index + 1);
                              },
                              childCount: top10.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userRank != null) _buildUserRankBar(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 64, color: _lightGray),
          const SizedBox(height: 16),
          const Text(
            'No records found for this month',
            style: TextStyle(color: _mediumGray, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    if (top10.isEmpty) return const SizedBox.shrink();

    final first = top10.length > 0 ? top10[0] : null;
    final second = top10.length > 1 ? top10[1] : null;
    final third = top10.length > 2 ? top10[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second Place
          if (second != null) _buildPodiumUser(second, 2, _silver, 70),
          const SizedBox(width: 12),
          // First Place
          if (first != null) _buildPodiumUser(first, 1, _gold, 90),
          const SizedBox(width: 12),
          // Third Place
          if (third != null) _buildPodiumUser(third, 3, _bronze, 70),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(dynamic user, int rank, Color color, double size) {
    final pfp = user['pfp'] as String?;
    final name = user['employee_name'] ?? user['username'] ?? 'User';
    final ot = int.tryParse(user['total_ot_minutes'].toString()) ?? 0;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lightGray,
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
                            style: TextStyle(
                              fontSize: size * 0.4,
                              fontWeight: FontWeight.bold,
                              color: _charcoal,
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _charcoal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatMinutes(ot),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'TOTAL OT',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(dynamic user, int rank) {
    final pfp = user['pfp'] as String?;
    final name = user['employee_name'] ?? user['username'] ?? 'User';
    final ot = int.tryParse(user['total_ot_minutes'].toString()) ?? 0;
    final designation = user['designation'] ?? '';

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
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _mediumGray,
                fontSize: 14,
              ),
            ),
          ),
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
                if (designation.isNotEmpty)
                  Text(
                    designation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _mediumGray,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMinutes(ot),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _charcoal,
                ),
              ),
              const Text(
                'HRS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _mediumGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankBar() {
    final rank = userRank!['rank'];
    final ot = int.tryParse((userRank!['total_ot_minutes'] ?? 0).toString()) ?? 0;

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: _charcoal,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _pureBlack.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'YOUR RANK',
                  style: TextStyle(
                    color: _mediumGray,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '#$rank',
                  style: const TextStyle(
                    color: _pureWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              height: 40,
              width: 1,
              color: _pureWhite.withOpacity(0.1),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TOTAL OT',
                  style: TextStyle(
                    color: _mediumGray,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _formatMinutes(ot),
                  style: const TextStyle(
                    color: _pureWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$selectedMonth-01'),
      firstDate: DateTime(2023, 1),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _charcoal,
              onPrimary: _pureWhite,
              onSurface: _charcoal,
            ),
          ),
          child: child!,
        );
      },
      // Month selection only logic is tricky with basic showDatePicker,
      // usually a custom picker is better, but this handles simple cases.
    );

    if (picked != null) {
      final newMonth = DateFormat('yyyy-MM').format(picked);
      if (newMonth != selectedMonth) {
        setState(() => selectedMonth = newMonth);
        _loadLeaderboard();
      }
    }
  }
}
