import 'package:flutter/material.dart';
import 'pet_room_page.dart';
import '../services/api_service.dart';
import '../widgets/floating_pet.dart';

class PetSelectionPage extends StatefulWidget {
  const PetSelectionPage({super.key});

  @override
  State<PetSelectionPage> createState() => _PetSelectionPageState();
}

class _PetSelectionPageState extends State<PetSelectionPage> {
  String? _selectedSpecies; 
  final TextEditingController _nameController = TextEditingController();
  
  bool _isLoading = true;

  final Color primaryColor = const Color(0xFF0F5238);
  final Color surfaceSoil = const Color(0xFFFDFCF8);
  final Color surfaceContainer = const Color(0xFFECEEEA);
  final Color onSurfaceVariant = const Color(0xFF404943);
  final Color outlineVariant = const Color(0xFFBFC9C1);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = false;
    });

    _loadExistingPet();
  }

  Future<void> _loadExistingPet() async {
    try {
      final petData = await ApiService.getPetStatus();
      if (mounted) {
        setState(() {
          if (petData['species'] == 'Tabby' || petData['species'] == 'Orange') {
            _selectedSpecies = petData['species'];
          }
          if (petData['name'] != null) {
            _nameController.text = petData['name'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedSpecies == null) return;

    final petName = _nameController.text.trim().isEmpty 
        ? (_selectedSpecies == 'Tabby' ? 'Ash' : 'Ginger') 
        : _nameController.text.trim();

    setState(() => _isLoading = true);

    // Completely removed Happiness from the initialized data API Payload
    final Map<String, dynamic> newPetData = {
      "name": petName,
      "species": _selectedSpecies, 
      "level": 1, 
      "hunger_level": 50, 
      "last_interaction": DateTime.now().toIso8601String(),
    };

    try {
      await ApiService.updatePetStatus(newPetData);
      reloadPetTrigger.value++; 

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PetRoomPage()));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to initialize companion.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceSoil,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: onSurfaceVariant), onPressed: () => Navigator.pop(context)),
        title: Text('EcoPal', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)), centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor)) 
          : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('Choose Your Companion', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Your partner in financial growth', style: TextStyle(fontSize: 16, color: onSurfaceVariant)),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(child: _buildPetCard(species: 'Tabby', defaultName: 'Ash', description: 'Observant & Calm', icon: Icons.psychology, gifPath: 'widgets/tabby/kitten/kit_idle.gif')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildPetCard(species: 'Orange', defaultName: 'Ginger', description: 'Playful & Energetic', icon: Icons.bolt, gifPath: 'widgets/orange/kitten/orkt_idle.gif')),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_selectedSpecies != null) ...[
                      Align(alignment: Alignment.centerLeft, child: Text('Name your pet (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: _selectedSpecies == 'Tabby' ? 'e.g., Ash' : 'e.g., Ginger',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: outlineVariant)),
                          filled: true, fillColor: Colors.white,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.1))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Your companion will live in your Garden dashboard, reacting to your financial habits.', style: TextStyle(color: onSurfaceVariant, fontSize: 14))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceSoil, border: Border(top: BorderSide(color: outlineVariant.withOpacity(0.3)))),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSpecies == null ? surfaceContainer : primaryColor,
                    foregroundColor: _selectedSpecies == null ? outlineVariant : Colors.white,
                    elevation: _selectedSpecies == null ? 0 : 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: _selectedSpecies == null ? null : _confirmSelection,
                  child: const Text('Confirm Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard({required String species, required String defaultName, required String description, required IconData icon, required String gifPath}) {
    final bool isSelected = _selectedSpecies == species;

    return GestureDetector(
      onTap: () => setState(() => _selectedSpecies = species),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB1F0CE).withOpacity(0.3) : Colors.white, 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryColor : outlineVariant.withOpacity(0.5), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8))] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: surfaceContainer, shape: BoxShape.circle, border: Border.all(color: surfaceSoil, width: 4)), child: Center(child: Image.asset(gifPath, width: 50, height: 50, fit: BoxFit.contain, filterQuality: FilterQuality.none))),
            const SizedBox(height: 12),
            Text(defaultName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: surfaceContainer, borderRadius: BorderRadius.circular(100)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: primaryColor), const SizedBox(width: 4), Text(description, style: TextStyle(fontSize: 10, color: onSurfaceVariant, fontWeight: FontWeight.w600))]),
            ),
          ],
        ),
      ),
    );
  }
}