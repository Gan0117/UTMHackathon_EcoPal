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

  String _userName = '';
  String _petName = '';
  String _petSpecies = 'Tabby';
  int _petLevel = 1;
  int _streak = 0; 
  double _totalHarvest = 0.00;

  final Color primaryColor = const Color(0xFF0F5238);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color surfaceContainer = const Color(0xFFECEEEA);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color secondaryContainer = const Color(0xFF92F7C3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await ApiService.getProfile();
      final petData = await ApiService.getPetStatus();
      final pocketsData = await ApiService.getPockets(); 

      if (mounted) {
        setState(() {
          _userName = profileData['username'] ?? 'User';
          _petName = petData['name'] ?? 'Companion';
          _petSpecies = petData['species'] ?? 'Tabby';
          _petLevel = petData['level'] ?? 1;
          
          // Data is strictly pulled from the API
          _streak = profileData['streak'] ?? 0;

          double calculatedHarvest = (profileData['safe_to_spend_balance'] ?? 0.0).toDouble();
          for (var pocket in pocketsData) {
            calculatedHarvest += (pocket['current_balance'] ?? 0.0).toDouble();
          }
          
          _totalHarvest = calculatedHarvest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _currentGifPath {
    if (_petSpecies.isEmpty) return ''; 
    String folder1 = _petSpecies.toLowerCase();
    String folder2 = _petLevel <= 3 ? 'kitten' : 'cat';
    String prefix = _petSpecies == 'Tabby' ? (_petLevel <= 3 ? 'kit_' : 'cat_') : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$folder1/$folder2/${prefix}idle.gif';
  }

  String _getBadgeAsset(int streak) {
    if (streak >= 30) {
      return 'widgets/badges/gold_badge.png';
    } else if (streak >= 7) {
      return 'widgets/badges/silver_badge.png';
    } else {
      return 'widgets/badges/bronze_badge.png';
    }
  }

  // 🔥 Goal 1 & 2: Edit Username Logic using API Service
  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Edit Username', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'New Username',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty || newName == _userName) {
                      Navigator.pop(context);
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      await ApiService.updateProfile({'username': newName});
                      
                      if (mounted) {
                        setState(() {
                          _userName = newName;
                        });
                        Navigator.pop(context); // Close the dialog
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated successfully!')));
                      }
                    } catch (e) {
                      if (mounted) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update username.')));
                      }
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
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
          : Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('widgets/profile_background.gif'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40), 
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Row(
                            children: [
                              Container(width: 70, height: 70, decoration: BoxDecoration(color: surfaceContainer, shape: BoxShape.circle, border: Border.all(color: primaryColor, width: 2)), child: Image.asset(_currentGifPath, filterQuality: FilterQuality.none, fit: BoxFit.contain)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🔥 Updated: Username row with Edit button
                                    Row(
                                      children: [
                                        Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _showEditNameDialog, // Trigger Edit Dialog
                                          child: Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
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
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                _getBadgeAsset(_streak),
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: secondaryContainer.withOpacity(0.5), shape: BoxShape.circle), child: Icon(Icons.savings_outlined, color: primaryColor, size: 28)),
                              const SizedBox(width: 16),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL HARVEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)), Text('\$${_totalHarvest.toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor))])
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Container(
                          decoration: BoxDecoration(color: const Color(0xFFF1F3E9).withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryColor.withOpacity(0.2))),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const PetSelectionPage())).then((_) {
                                showFloatingPet.value = true;
                                setState(() => _isLoading = true);
                                _loadData();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Manage Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade700)]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9), foregroundColor: Colors.grey.shade800, side: BorderSide(color: Colors.grey.shade300), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                          icon: const Icon(Icons.help_outline), label: const Text('Support & Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _launchSupport,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(backgroundColor: Colors.red.shade50.withOpacity(0.8), foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade100), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                          icon: const Icon(Icons.logout), label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), onPressed: _signOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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