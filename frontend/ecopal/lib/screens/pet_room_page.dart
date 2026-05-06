import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/bottom_nav_bar.dart';

class PetRoomPage extends StatefulWidget {
  const PetRoomPage({super.key});

  @override
  State<PetRoomPage> createState() => _PetRoomPageState();
}

class _PetRoomPageState extends State<PetRoomPage> {
  bool _isLoading = true;

  // Pet Data State
  String _name = 'Loading...';
  String _species = 'Tabby';
  int _level = 1;
  int _hunger = 0;
  int _happiness = 100;
  
  // Animation State
  String _currentState = 'idle'; // 'idle', 'happy', 'eat', 'sleep'
  bool _isInteracting = false;
  final int _oneTurnDurationMs = 1000;
  
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    _loadPetData();

    // Rule 6: Happiness reduces when user didn't interact in a period
    // We run a timer every 3 seconds to slowly drain happiness if not interacting
    _decayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isInteracting && !_isLoading) {
        setState(() {
          _happiness = (_happiness - 1).clamp(0, 100);
          _checkSleepCondition();
        });
      }
    });
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPetData() async {
    try {
      // Fetch data from our ApiService (which can pull from pets.json)
      final petData = await ApiService.getPetStatus();
      
      setState(() {
        _name = petData['name'] ?? 'Unknown';
        _species = petData['species'] ?? 'Tabby';
        _level = petData['level'] ?? 1;
        _hunger = petData['hunger_level'] ?? 50;
        _happiness = petData['happiness_level'] ?? 80;
        _isLoading = false;
      });

      // Calculate offline happiness decay based on last interaction[cite: 16, 23]
      if (petData['last_interaction'] != null) {
        DateTime lastInteraction = DateTime.parse(petData['last_interaction']);
        Duration difference = DateTime.now().difference(lastInteraction);
        // E.g., Lose 1 happiness for every hour away
        int lostHappiness = difference.inHours;
        setState(() {
          _happiness = (_happiness - lostHappiness).clamp(0, 100);
          _checkSleepCondition();
        });
      }
    } catch (e) {
      // Fallback for hackathon demo if API fails
      setState(() {
        _name = 'Demo Pet';
        _species = 'Tabby';
        _isLoading = false;
      });
    }
  }

  // Rule 5: Cat enters sleep when happiness < 40
  void _checkSleepCondition() {
    if (_happiness < 40 && !_isInteracting) {
      _currentState = 'sleep';
    } else if (_currentState == 'sleep' && _happiness >= 40) {
      _currentState = 'idle';
    }
  }

  // Dynamically generate the GIF path based on rules 1 & 2
  String get _currentGifPath {
    String folder1 = _species.toLowerCase(); // 'tabby' or 'orange'
    String folder2 = _level <= 3 ? 'kitten' : 'cat'; // <= 3 is kitten, > 3 is cat
    
    String prefix = '';
    if (_species == 'Tabby') {
      prefix = _level <= 3 ? 'kit_' : 'cat_';
    } else {
      prefix = _level <= 3 ? 'orkt_' : 'org_';
    }

    return 'widgets/$folder1/$folder2/$prefix$_currentState.gif';
  }

  // Rule 7: Touch the cat to add happiness_level
  void _handleTap() async {
    if (_isInteracting || _isLoading) return; 
    
    setState(() {
      _isInteracting = true;
      _currentState = 'happy';
      _happiness = (_happiness + 15).clamp(0, 100); // Add happiness
    });

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2));
    
    if (mounted) {
      setState(() {
        _isInteracting = false;
        _currentState = 'idle';
        _checkSleepCondition();
      });
    }
  }

  // Rule 4 & 7: Feeding fish adds hunger_level and happiness_level
  void _handleFeed() async {
    if (_isInteracting || _isLoading) return;
    
    setState(() {
      _isInteracting = true;
      _currentState = 'eat';
      
      _happiness = (_happiness + 10).clamp(0, 100);
      _hunger += 30; // Add hunger

      // Rule 3: Hunger reach 100 -> level + 1, hunger return to 0
      if (_hunger >= 100) {
        _level += 1;
        _hunger = _hunger - 100; // Carry over remainder
      }
    });

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); // Eating animation
    
    if (mounted) {
      setState(() {
        _currentState = 'happy'; // Happy after eating
      });
    }

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); // Happy animation
    
    if (mounted) {
      setState(() {
        _isInteracting = false;
        _currentState = 'idle';
        _checkSleepCondition();
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: const Color(0xFF95D4B3),
      //   title: const Text('Interact with AI Pet', style: TextStyle(color: Color(0xFF002114), fontWeight: FontWeight.bold)),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.logout, color: Color(0xFF002114)),
      //       onPressed: _signOut,
      //     )
      //   ],
      // ),
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 2),

      // Apply the Background GIF
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('widgets/pet_background.gif'),
            fit: BoxFit.cover, // Ensures the background covers the whole screen
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  // --- TOP STATS HUD ---
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85), // Semi-transparent glass effect
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Column(
                      children: [
                        // Rule 8: Display custom name and dynamic level
                        Text(
                          '$_name (Lvl $_level $_species)',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5238)),
                        ),
                        const SizedBox(height: 12),
                        
                        // Happiness Bar
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _happiness / 100,
                                backgroundColor: Colors.grey.shade300,
                                color: _happiness < 40 ? Colors.blueGrey : Colors.redAccent,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Hunger Bar
                        Row(
                          children: [
                            const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _hunger / 100,
                                backgroundColor: Colors.grey.shade300,
                                color: Colors.orange,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- CENTER: THE PET ---
                  DragTarget<String>(
                    onAcceptWithDetails: (details) {
                      if (details.data == 'fish_food') {
                        _handleFeed();
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        onTap: _handleTap,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            _currentGifPath, // Dynamically pulled based on state, species, and level
                            key: ValueKey<String>(_currentGifPath), // Forces refresh when path changes
                            width: 180, 
                            height: 180,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none, // Keep pixel art sharp
                          ),
                        ),
                      );
                    },
                  ),

                  // --- BOTTOM: INVENTORY/FOOD ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Drag Fish to Feed',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Draggable<String>(
                          data: 'fish_food', 
                          feedback: Image.asset('widgets/fish.gif', width: 80, height: 80, filterQuality: FilterQuality.none),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: Image.asset('widgets/fish.gif', width: 64, height: 64, filterQuality: FilterQuality.none),
                          ),
                          child: Image.asset('widgets/fish.gif', width: 64, height: 64, filterQuality: FilterQuality.none),
                        ),
                      ],
                    ),
                  ),
                  
                ],
              ),
            ),
      ),
    );
  }
}