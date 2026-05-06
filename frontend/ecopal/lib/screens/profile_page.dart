import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/bottom_nav_bar.dart';
// 🔥 Import the new FloatingPet widget
import '../widgets/floating_pet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;

  // User & Pet State
  String _userName = 'Loading...';
  String _petName = '';
  String _petSpecies = 'Tabby';
  int _petLevel = 1;
  int _streak = 14; // Mocked day streak
  double _totalHarvest = 4250.00;

  // Manage Companion State
  bool _isManageExpanded = false;
  final TextEditingController _nameController = TextEditingController();
  String _editSelectedSpecies = 'Tabby';

  // Theme Colors
  final Color primaryColor = const Color(0xFF0F5238);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color surfaceContainer = const Color(0xFFECEEEA);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color secondaryContainer = const Color(0xFF92F7C3);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await ApiService.getProfile();
      final petData = await ApiService.getPetStatus();

      setState(() {
        _userName = profileData['username'] ?? 'User';
        _petName = petData['name'] ?? 'Ash';
        _petSpecies = petData['species'] ?? 'Tabby';
        _petLevel = petData['level'] ?? 1;
        
        // Initialize Edit State
        _nameController.text = _petName;
        _editSelectedSpecies = _petSpecies;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Dynamically get idle gif for the Profile Icon
  String get _currentGifPath {
    String folder1 = _petSpecies.toLowerCase();
    String folder2 = _petLevel <= 3 ? 'kitten' : 'cat';
    String prefix = _petSpecies == 'Tabby' 
        ? (_petLevel <= 3 ? 'kit_' : 'cat_') 
        : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$folder1/$folder2/${prefix}idle.gif';
  }

  // Get specific gif path for the selection menu
  String _getSelectionGif(String species) {
    String f1 = species.toLowerCase();
    String f2 = _petLevel <= 3 ? 'kitten' : 'cat';
    String px = species == 'Tabby' 
        ? (_petLevel <= 3 ? 'kit_' : 'cat_') 
        : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$f1/$f2/${px}idle.gif';
  }

  Future<void> _launchSupport() async {
    final Uri url = Uri.parse('https://google.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Support URL')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false, // Clears the navigation stack
      );
    }
  }

  void _saveCompanionChanges() {
    setState(() {
      _petName = _nameController.text.trim();
      _petSpecies = _editSelectedSpecies;
      _isManageExpanded = false;
    });
    // In the future: Call ApiService to update Supabase here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Companion updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceSoil,
      
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 4),

      // 🔥 Wrapped the body in a Stack to float the pet over it
      body: Stack(
        children: [
          _isLoading
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withOpacity(0.1)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  color: surfaceContainer,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryColor, width: 2),
                                ),
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

                        // --- HARVEST STATS CARD ---
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                                  Text('\$${_totalHarvest.toStringAsFixed(0)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- MANAGE COMPANION SECTION ---
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3E9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => setState(() => _isManageExpanded = !_isManageExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Manage Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Icon(_isManageExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade700),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Expandable Content
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _isManageExpanded
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Pet Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _nameController,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.7),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor)),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            const Text('Pet Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(child: _buildSelectablePet('Tabby')),
                                                const SizedBox(width: 16),
                                                Expanded(child: _buildSelectablePet('Orange')),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  padding: const EdgeInsets.symmetric(vertical: 16)
                                                ),
                                                onPressed: _saveCompanionChanges,
                                                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- ACTION BUTTONS ---
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade800,
                            side: BorderSide(color: Colors.grey.shade300),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))
                          ),
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Support & Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: _launchSupport,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.red.shade50.withOpacity(0.5),
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade100),
                            minimumSize: const Size(double.infinity, 56),
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
          
          // 🔥 The Reusable Floating Pet
          if (!_isLoading)
            const FloatingPet(),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSelectablePet(String species) {
    bool isSelected = _editSelectedSpecies == species;
    return GestureDetector(
      onTap: () => setState(() => _editSelectedSpecies = species),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F4EA) : Colors.white,
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (isSelected) 
               Align(alignment: Alignment.topRight, child: Icon(Icons.check_circle, color: primaryColor, size: 16)),
            Image.asset(_getSelectionGif(species), width: 60, height: 60, filterQuality: FilterQuality.none),
            const SizedBox(height: 8),
            Text('$species Tabby', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12, color: primaryColor)),
          ],
        ),
      ),
    );
  }
}