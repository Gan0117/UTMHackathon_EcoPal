import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'pet_selection_page.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;

  // Dynamic User & Pet State
  String _userName = 'Loading...';
  String _petName = '';
  String _petSpecies = 'Tabby';
  int _petLevel = 1;
  int _streak = 0; 
  double _totalHarvest = 0.00;

  // Theme Colors
  final Color primaryColor = const Color(0xFF0F5238);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color surfaceContainer = const Color(0xFFECEEEA);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color secondaryContainer = const Color(0xFF92F7C3);

  @override
  void initState() {
    super.initState();

    // Re-enable global pet visibility 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Fetch all required data from ApiService
      final profileData = await ApiService.getProfile();
      final petData = await ApiService.getPetStatus();
      final pocketsData = await ApiService.getPockets(); // Fetch pockets for calculation

      if (mounted) {
        setState(() {
          // 2. Set Basic Profile & Pet Info
          _userName = profileData['username'] ?? 'User';
          _petName = petData['name'] ?? 'Ash';
          _petSpecies = petData['species'] ?? 'Tabby';
          _petLevel = petData['level'] ?? 1;
          
          // 3. Calculate Day Streak based on account creation date
          if (profileData['created_at'] != null) {
            DateTime createdAt = DateTime.parse(profileData['created_at']);
            int calculatedStreak = DateTime.now().difference(createdAt).inDays;
            _streak = calculatedStreak < 1 ? 1 : calculatedStreak; // Minimum 1 day streak
          }

          // 4. Calculate Total Harvest (Safe Balance + All Pocket Balances)
          double calculatedHarvest = (profileData['safe_to_spend_balance'] ?? 0.0).toDouble();
          
          for (var pocket in pocketsData) {
            calculatedHarvest += (pocket['current_balance'] ?? 0.0).toDouble();
          }
          
          _totalHarvest = calculatedHarvest;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _currentGifPath {
    String folder1 = _petSpecies.toLowerCase();
    String folder2 = _petLevel <= 3 ? 'kitten' : 'cat';
    String prefix = _petSpecies == 'Tabby' ? (_petLevel <= 3 ? 'kit_' : 'cat_') : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$folder1/$folder2/${prefix}idle.gif';
  }

  Future<void> _launchSupport() async {
    final Uri url = Uri.parse('https://google.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Support URL')));
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceSoil,
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 4),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40), 
                child: Column(
                  children: [
                    // --- HEADER SECTION ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withOpacity(0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(color: surfaceContainer, shape: BoxShape.circle, border: Border.all(color: primaryColor, width: 2)),
                            child: Image.asset(_currentGifPath, filterQuality: FilterQuality.none, fit: BoxFit.contain),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildBadge('Level $_petLevel', primaryColor),
                                    const SizedBox(width: 8),
                                    _buildBadge('$_streak Day Streak', const Color(0xFFF59E0B)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- DYNAMIC HARVEST STATS CARD ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor.withOpacity(0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: secondaryContainer.withOpacity(0.5), shape: BoxShape.circle),
                            child: Icon(Icons.savings_outlined, color: primaryColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL HARVEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                              Text('\$${_totalHarvest.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- MANAGE COMPANION SECTION ---
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF1F3E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.2))),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PetSelectionPage()),
                          ).then((_) {
                            showFloatingPet.value = true;
                            setState(() => _isLoading = true);
                            _loadData(); // Re-fetch all dynamic data when returning
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Manage Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade700),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- ACTION BUTTONS ---
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade300), minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
                      ),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Support & Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _launchSupport,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.red.shade50.withOpacity(0.5), foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade100), minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}