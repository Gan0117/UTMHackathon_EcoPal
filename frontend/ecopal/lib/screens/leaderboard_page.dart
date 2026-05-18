import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';
import '../services/api_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _leaderboard = [];

  final Color primaryColor = const Color(0xFF0F5238);
  final Color secondaryColor = const Color(0xFF006C48);
  final Color outlineVariant = const Color(0xFFBFC9C1);

  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = false;
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
  try {
    final data = await ApiService.getLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = data;
        _isLoading = false;
      });
      _staggerController.forward();
    }
  } catch (e) {
    debugPrint('Leaderboard error: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}

  String _getPetGif(String species, int level) {
    final s = species.toLowerCase();
    final folder2 = level <= 3 ? 'kitten' : 'cat';
    final prefix = s == 'tabby'
        ? (level <= 3 ? 'kit_' : 'cat_')
        : (level <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$s/$folder2/${prefix}idle.gif';
  }

  Color _medalColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return Colors.white.withOpacity(0.55);
  }

  Widget _glassCard({
    required Widget child,
    Color? borderColor,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    double borderWidth = 1.5,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.30),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _animated(int index, Widget child) {
    final start = (index * 0.07).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFirstPlaceCard(Map<String, dynamic> entry) {
    return _glassCard(
      borderColor: _gold.withOpacity(0.7),
      borderWidth: 2.5,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Gold medal
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                  colors: [Color(0xFFFFE566), _gold]),
              boxShadow: [
                BoxShadow(
                    color: _gold.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 1),
              ],
            ),
            child: const Center(
              child: Text('#1',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),

          // Pet avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE566), _gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: _gold.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFF1A2A22),
                  child: Image.asset(
                    _getPetGif(entry['species'], entry['level']),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['pet_name'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${entry['username'] ?? 'user'}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.65),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Level pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFE566), _gold]),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                    color: _gold.withOpacity(0.55),
                    blurRadius: 10,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              'Lv. ${entry['level']}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5A3A00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeCard(Map<String, dynamic> entry) {
    final rank = entry['rank'] as int;
    final mc = _medalColor(rank);

    return _glassCard(
      borderColor: mc.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mc.withOpacity(0.25),
              border: Border.all(color: mc, width: 2),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: mc)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: mc.withOpacity(0.7), width: 2),
              color: const Color(0xFF1A2A22),
            ),
            child: ClipOval(
              child: Image.asset(
                _getPetGif(entry['species'], entry['level']),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['pet_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('@${entry['username'] ?? 'user'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.55))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: mc.withOpacity(0.18),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: mc.withOpacity(0.55)),
            ),
            child: Text('Lv. ${entry['level']}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: mc)),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(Map<String, dynamic> entry) {
    final rank = entry['rank'] as int;

    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('#$rank',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.50)),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.20), width: 1.5),
              color: const Color(0xFF1A2A22),
            ),
            child: ClipOval(
              child: Image.asset(
                _getPetGif(entry['species'], entry['level']),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['pet_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('@${entry['username'] ?? 'user'}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.50))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: secondaryColor.withOpacity(0.50)),
            ),
            child: const Text('',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92F7C3))),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: secondaryColor.withOpacity(0.50)),
            ),
            child: Text('Lv. ${entry['level']}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92F7C3))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Same background as Pet Room
          Positioned.fill(
            child: Image.asset(
              'widgets/pet_background.gif',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _glassCard(
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _glassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Global Leaderboard',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3),
                              ),
                              SizedBox(width: 8),
                              Text('🏆',
                                  style: TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF92F7C3)))
                      : _leaderboard.isEmpty
                          ? Center(
                              child: Text('No rankings yet.',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.6),
                                      fontSize: 16)))
                          : RefreshIndicator(
                              onRefresh: _loadLeaderboard,
                              color: const Color(0xFF92F7C3),
                              backgroundColor:
                                  const Color(0xFF0F5238),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 120),
                                itemCount: _leaderboard.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final entry = _leaderboard[index]
                                      as Map<String, dynamic>;
                                  final rank = entry['rank'] as int;

                                  Widget card;
                                  if (rank == 1) {
                                    card =
                                        _buildFirstPlaceCard(entry);
                                  } else if (rank <= 3) {
                                    card = _buildTopThreeCard(entry);
                                  } else {
                                    card = _buildRankRow(entry);
                                  }

                                  return _animated(index, card);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 2),
    );
  }
}