import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/electric_refresh_indicator.dart';

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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: _pureBlack,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: _pureBlack),
            onPressed: () => _showMonthPicker(),
          ),
        ],
      ),
      body: ElectricRefreshIndicator(
        onRefresh: _loadLeaderboard,
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
            : top10.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildEmptyState()],
              )
            : Stack(
                children: [
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildPodium()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            // Skip first 3 as they are in podium
                            if (index < 3) {
                              return const SizedBox.shrink();
                            }
                            final emp = top10[index];
                            return _buildListTile(emp, index + 1);
                          }, childCount: top10.length),
                        ),
                      ),
                    ],
                  ),
                  if (userRank != null) _buildUserRankBar(),
                ],
              ),
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
    final username = user['username'] != null && user['username'].toString().isNotEmpty
        ? user['username'].toString()
        : null;
    final ot = int.tryParse(user['total_ot_minutes'].toString()) ?? 0;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Distinct Aura Ring / Effect for each rank
              _RankDistinctAura(
                rank: rank,
                size: size,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank == 1
                          ? const Color(0xFFFF9500)
                          : rank == 2
                              ? const Color(0xFFB0BEC5)
                              : const Color(0xFFCD7F32),
                      width: rank == 1 ? 3.5 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (rank == 1
                                ? const Color(0xFFFF9500)
                                : rank == 2
                                    ? const Color(0xFF90A4AE)
                                    : const Color(0xFFCD7F32))
                            .withOpacity(rank == 1 ? 0.35 : 0.2),
                        blurRadius: rank == 1 ? 18 : 12,
                        offset: const Offset(0, 6),
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
              ),

              // Unique animated trophy / flame crown for each rank
              Positioned(
                top: rank == 1 ? -24 : -16,
                child: _RankTopBadge(rank: rank),
              ),

              // Rank Tag
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rank == 1 ? 12 : 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: rank == 1
                      ? const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF3D00)],
                        )
                      : rank == 2
                          ? const LinearGradient(
                              colors: [Color(0xFFCFD8DC), Color(0xFF78909C)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFD7CCC8), Color(0xFF8D6E63)],
                            ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AutoScrollingText(
            text: name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          if (username != null && username != name) ...[
            const SizedBox(height: 2),
            AutoScrollingText(
              text: username,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
    final username = user['username'] != null && user['username'].toString().isNotEmpty
        ? user['username'].toString()
        : null;
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
                AutoScrollingText(
                  text: name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _pureBlack,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 2),
                AutoScrollingText(
                  text: [
                    if (username != null && username != name) username,
                    if (designation.isNotEmpty) designation,
                  ].join(' • '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _mediumGray,
                  ),
                  textAlign: TextAlign.start,
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
    final ot =
        int.tryParse((userRank!['total_ot_minutes'] ?? 0).toString()) ?? 0;

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
            Container(height: 40, width: 1, color: _pureWhite.withOpacity(0.1)),
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
    final DateTime initial = DateTime.parse('$selectedMonth-01');

    int pickerYear = initial.year;
    String? pickedMonth;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final bool canGoBack = pickerYear > 2023;
            final bool canGoForward = pickerYear < now.year;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: _pureWhite,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year navigator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: canGoBack
                              ? () => setDialogState(() => pickerYear--)
                              : null,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: canGoBack ? _charcoal : _lightGray,
                            size: 28,
                          ),
                        ),
                        Text(
                          '$pickerYear',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: _pureBlack,
                            letterSpacing: 1,
                          ),
                        ),
                        IconButton(
                          onPressed: canGoForward
                              ? () => setDialogState(() => pickerYear++)
                              : null,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: canGoForward ? _charcoal : _lightGray,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Month grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.2,
                      ),
                      itemBuilder: (ctx, i) {
                        final month = i + 1;
                        final isFuture =
                            pickerYear == now.year && month > now.month;
                        final isSelected = pickerYear == initial.year &&
                            month == initial.month;
                        final monthStr = DateFormat('MMM').format(
                          DateTime(pickerYear, month),
                        );

                        return GestureDetector(
                          onTap: isFuture
                              ? null
                              : () {
                                  pickedMonth =
                                      '$pickerYear-${month.toString().padLeft(2, '0')}';
                                  Navigator.of(ctx).pop();
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _charcoal
                                  : isFuture
                                      ? _offWhite
                                      : _lightGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              monthStr,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSelected
                                    ? _pureWhite
                                    : isFuture
                                        ? _lightGray
                                        : _charcoal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _mediumGray),
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

    if (pickedMonth != null && pickedMonth != selectedMonth) {
      setState(() => selectedMonth = pickedMonth!);
      _loadLeaderboard();
    }
  }
}

// ============================================================================
// DISTINCT ENGAGING ANIMATIONS FOR TOP 3 PODIUM RANKS
// ============================================================================

/// Top animated badge floating above each rank
class _RankTopBadge extends StatefulWidget {
  final int rank;
  const _RankTopBadge({Key? key, required this.rank}) : super(key: key);

  @override
  State<_RankTopBadge> createState() => _RankTopBadgeState();
}

class _RankTopBadgeState extends State<_RankTopBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    // 1st place has rapid flaming energy, 2nd has swift spark, 3rd has calm warmth
    final durationMs = widget.rank == 1 ? 750 : widget.rank == 2 ? 1000 : 1300;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnim.value),
          child: _buildRankBadgeContent(),
        );
      },
    );
  }

  Widget _buildRankBadgeContent() {
    if (widget.rank == 1) {
      // 👑 #1 - BLAZING GOLDEN CROWN with FIRE PARTICLES & INTENSE GLOW
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF5722)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.6 * _glowAnim.value),
              blurRadius: 14 * _glowAnim.value,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.5),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 3),
            Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      );
    } else if (widget.rank == 2) {
      // ⚡ #2 - ELECTRIC SILVER LIGHTNING / SHINING STAR
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFF607D8B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BCD4).withOpacity(0.5 * _glowAnim.value),
              blurRadius: 10 * _glowAnim.value,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.bolt_rounded,
              color: Color(0xFF00E5FF),
              size: 15,
            ),
            SizedBox(width: 2),
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      );
    } else {
      // 🔥 #3 - WARM BRONZE EMBER
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFCC80), Color(0xFF8D6E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9800).withOpacity(0.4 * _glowAnim.value),
              blurRadius: 8 * _glowAnim.value,
            ),
          ],
        ),
        child: const Icon(
          Icons.whatshot_rounded,
          color: Colors.white,
          size: 16,
        ),
      );
    }
  }
}

/// Distinct aura surrounding each podium rank avatar
class _RankDistinctAura extends StatefulWidget {
  final Widget child;
  final double size;
  final int rank;

  const _RankDistinctAura({
    Key? key,
    required this.child,
    required this.size,
    required this.rank,
  }) : super(key: key);

  @override
  State<_RankDistinctAura> createState() => _RankDistinctAuraState();
}

class _RankDistinctAuraState extends State<_RankDistinctAura>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    final duration = widget.rank == 1
        ? const Duration(milliseconds: 1400)
        : widget.rank == 2
            ? const Duration(milliseconds: 1800)
            : const Duration(milliseconds: 2200);

    _ctrl = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _rotate = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rank == 1) {
      // #1: Fiery pulsating sunburst aura with dual layer glow
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3D00).withOpacity(0.45 * _pulse.value),
                  blurRadius: 28 * _pulse.value,
                  spreadRadius: 6 * _pulse.value,
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.35 * _pulse.value),
                  blurRadius: 14 * _pulse.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: widget.child,
          );
        },
      );
    } else if (widget.rank == 2) {
      // #2: Cool electric-cyan/silver rhythmic shimmer
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35 * _pulse.value),
                  blurRadius: 18 * _pulse.value,
                  spreadRadius: 2 * _pulse.value,
                ),
              ],
            ),
            child: widget.child,
          );
        },
      );
    } else {
      // #3: Gentle warm amber ember glow
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9100).withOpacity(0.25 * _pulse.value),
                  blurRadius: 12 * _pulse.value,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: widget.child,
          );
        },
      );
    }
  }
}

/// A smooth auto-scrolling marquee text widget for long employee names.
/// If the text fits, it stays centered/aligned normally.
/// If it overflows, it automatically scrolls back and forth smoothly with pauses.
class AutoScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const AutoScrollingText({
    Key? key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
  }) : super(key: key);

  @override
  State<AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<AutoScrollingText> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScroll());
  }

  @override
  void didUpdateWidget(covariant AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _isScrolling = false;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScroll());
    }
  }

  void _checkAndScroll() async {
    if (!mounted || !_scrollCtrl.hasClients) return;

    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    if (maxScroll > 2 && !_isScrolling) {
      _isScrolling = true;
      _startLoop();
    }
  }

  Future<void> _startLoop() async {
    while (mounted && _isScrolling) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted || !_scrollCtrl.hasClients) break;

      final maxScroll = _scrollCtrl.position.maxScrollExtent;
      if (maxScroll <= 0) break;

      final durationMs = (maxScroll * 35).clamp(1200, 5000).toInt();

      // Scroll to end
      await _scrollCtrl.animateTo(
        maxScroll,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted || !_scrollCtrl.hasClients) break;

      // Scroll back to start
      await _scrollCtrl.animateTo(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              widget.text,
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

