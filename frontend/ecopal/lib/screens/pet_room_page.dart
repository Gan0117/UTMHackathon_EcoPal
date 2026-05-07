import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';

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
  
  // User Data State
  int _rewardPoints = 0; 
  
  // Animation & Chat State
  String _currentState = 'idle'; 
  bool _isInteracting = false;
  String? _message;
  
  final int _oneTurnDurationMs = 1000;
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    _loadPetData();

    //enable global floating pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });

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
      final petData = await ApiService.getPetStatus();
      final profileData = await ApiService.getProfile(); 
      
      setState(() {
        _name = petData['name'] ?? 'Unknown';
        _species = petData['species'] ?? 'Tabby';
        _level = petData['level'] ?? 1;
        _hunger = petData['hunger_level'] ?? 0;
        _happiness = petData['happiness_level'] ?? 0;
        
        _rewardPoints = profileData['reward_points'] ?? 0; 
        _isLoading = false;
      });

      if (petData['last_interaction'] != null) {
        DateTime lastInteraction = DateTime.parse(petData['last_interaction']);
        Duration difference = DateTime.now().difference(lastInteraction);
        int lostHappiness = difference.inHours;
        setState(() {
          _happiness = (_happiness - lostHappiness).clamp(0, 100);
          _checkSleepCondition();
        });
      }
    } catch (e) {
      print("Error loading data: $e");
      setState(() {
        _name = 'Demo Pet';
        _species = 'Tabby';
        _rewardPoints = 0; 
        _isLoading = false;
      });
    }
  }

  void _checkSleepCondition() {
    if (_happiness < 40 && !_isInteracting) {
      _currentState = 'sleep';
    } else if (_currentState == 'sleep' && _happiness >= 40) {
      _currentState = 'idle';
    }
  }

  String get _currentGifPath {
    String folder1 = _species.toLowerCase(); 
    String folder2 = _level <= 3 ? 'kitten' : 'cat'; 
    
    String prefix = '';
    if (_species == 'Tabby') {
      prefix = _level <= 3 ? 'kit_' : 'cat_';
    } else {
      prefix = _level <= 3 ? 'orkt_' : 'org_';
    }

    return 'widgets/$folder1/$folder2/$prefix$_currentState.gif';
  }

  //cat speak
  void _speak(String text) {
    setState(() => _message = text);
    // Auto-hide the message after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _message == text) {
        setState(() => _message = null);
      }
    });
  }

  void _handleTap() async {
    if (_isInteracting || _isLoading) return; 
    
    setState(() {
      _isInteracting = true;
      _currentState = 'happy';
      _happiness = (_happiness + 15).clamp(0, 100); 
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

  void _showInsufficientPointsMessage() {
    _speak('Meow! Not enough points (50 required)!\n💡 Tip: Keep a "Healthy" spending grade!');
  }

  void _handleFeed() async {
    if (_isInteracting || _isLoading) return;
    
    if (_rewardPoints < 50) {
      _showInsufficientPointsMessage();
      return; 
    }

    bool leveledUp = false; 

    setState(() {
      _rewardPoints -= 50; 
      
      _isInteracting = true;
      _currentState = 'eat';
      
      _happiness = (_happiness + 10).clamp(0, 100);
      _hunger += 30; 

      if (_hunger >= 100) {
        _level += 1;
        _hunger = _hunger - 100; 
        leveledUp = true; 
      }
    });

    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); 
    
    if (!mounted) return;

    if (leveledUp) {
      setState(() {
        _currentState = 'happy'; 
      });
      _speak("Yay! I leveled up!"); 
      await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 2)); 
    }

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
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 2),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('widgets/pet_background.gif'),
            fit: BoxFit.cover, 
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
                      color: Colors.white.withOpacity(0.85), 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_name (Lvl $_level $_species)',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5238)),
                        ),
                        const SizedBox(height: 12),
                        
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

                  // --- CENTER: THE PET & CHATBOX ---
                  DragTarget<String>(
                    onAcceptWithDetails: (details) {
                      if (details.data == 'fish_food') {
                        _handleFeed();
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      // 🔥 Replaced Column with Stack to prevent layout shifting
                      return Stack(
                        clipBehavior: Clip.none, // Allows the bubble to overflow upwards
                        alignment: Alignment.center,
                        children: [
                          // The Pet Asset
                          GestureDetector(
                            onTap: _handleTap,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Image.asset(
                                _currentGifPath, 
                                key: ValueKey<String>(_currentGifPath), 
                                width: 180, 
                                height: 180,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none, 
                              ),
                            ),
                          ),
                          
                          // 🔥 The Chat Bubble UI overlays on top of the pet/HUD
                          if (_message != null)
                            Positioned(
                              bottom: 160, // Floats just above the pet
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                constraints: const BoxConstraints(maxWidth: 250),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(4), // Gives it a speech-bubble tail look
                                  ),
                                  border: Border.all(color: const Color(0xFF0F5238).withOpacity(0.2)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Text(
                                  _message!,
                                  style: const TextStyle(color: Color(0xFF0F5238), fontWeight: FontWeight.bold, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // --- BOTTOM: INVENTORY/FOOD ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '$_rewardPoints Points',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Drag Fish to Feed (Costs 50)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        
                        GestureDetector(
                          onTap: () {
                            if (_rewardPoints < 50) {
                              _showInsufficientPointsMessage();
                            }
                          },
                          child: Opacity(
                            opacity: _rewardPoints >= 50 ? 1.0 : 0.5,
                            child: Draggable<String>(
                              data: 'fish_food', 
                              maxSimultaneousDrags: _rewardPoints >= 50 ? 1 : 0, 
                              feedback: Image.asset('widgets/fish.png', width: 120, height: 120, filterQuality: FilterQuality.none),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: Image.asset('widgets/fish.png', width: 96, height: 96, filterQuality: FilterQuality.none),
                              ),
                              child: Image.asset('widgets/fish.png', width: 96, height: 96, filterQuality: FilterQuality.none),
                            ),
                          ),
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