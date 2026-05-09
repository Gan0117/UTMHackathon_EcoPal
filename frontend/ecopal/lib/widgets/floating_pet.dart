import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

// Global controllers to manage the pet's visibility and data state from ANY page
final ValueNotifier<bool> showFloatingPet = ValueNotifier<bool>(false);
final ValueNotifier<int> reloadPetTrigger = ValueNotifier<int>(0);

class FloatingPet extends StatefulWidget {
  const FloatingPet({super.key});

  @override
  State<FloatingPet> createState() => FloatingPetState();
}

class FloatingPetState extends State<FloatingPet> with SingleTickerProviderStateMixin {
  // Initial floating position on the screen
  Offset _position = const Offset(20, 100);

  // Dynamic Pet State
  String _species = '';
  int _level = 1;
  bool _isLoading = true;

  // AI Chatbox State
  String? _message;
  
  // Goal 1: Animation Controller for Edge Snapping
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;

  // Goal 2 & 3: Periodic Cheer Timer & State
  Timer? _cheerTimer;
  bool _isNextCheerPocket = true;

  // Goal 4: Greeting State
  bool _hasGreeted = false;

  // Approximate sizes for boundary calculations
  final double _petSize = 65.0;
  final double _bubbleMaxWidth = 220.0;
  final double _edgeMargin = 10.0;

  @override
  void initState() {
    super.initState();
    _loadPetData();
    
    reloadPetTrigger.addListener(_loadPetData);
    showFloatingPet.addListener(_handleVisibilityChange); // Goal 4 listener

    // Goal 1: Initialize Animation Controller
    _snapController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 350)
    );
    _snapController.addListener(() {
      setState(() {
        _position = _snapAnimation.value;
      });
    });

    // Goal 2 & 3: Start the cheerleader timer (runs every 3 minutes)
    _cheerTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _triggerPeriodicCheer();
    });
  }

  @override
  void dispose() {
    reloadPetTrigger.removeListener(_loadPetData);
    showFloatingPet.removeListener(_handleVisibilityChange);
    _snapController.dispose();
    _cheerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPetData() async {
    try {
      final petData = await ApiService.getPetStatus();
      if (mounted) {
        setState(() {
          _species = petData['species'] ?? 'Tabby';
          _level = petData['level'] ?? 1;
          _isLoading = false;
        });
        _handleVisibilityChange(); // Trigger greeting if data just loaded and pet is visible
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _species = 'Tabby';
          _isLoading = false;
        });
      }
    }
  }

  // --- Goal 4: Greeting Logic ---
  void _handleVisibilityChange() {
    // Only greet if the pet is visible, data is loaded, and we haven't greeted yet this session
    if (showFloatingPet.value && !_isLoading && _species.isNotEmpty && !_hasGreeted) {
      _hasGreeted = true;
      
      final hour = DateTime.now().hour;
      String greeting;
      
      if (hour < 12) {
        greeting = "Good morning!";
      } else if (hour < 18) {
        greeting = "Good afternoon!";
      } else {
        greeting = "Good evening!";
      }
      
      speak(greeting);
    }
  }

  // --- Goal 2 & 3: Periodic Cheer Logic ---
  Future<void> _triggerPeriodicCheer() async {
    // Don't interrupt if the pet is hidden, loading, or already talking
    if (!showFloatingPet.value || _isLoading || _message != null) return;

    try {
      if (_isNextCheerPocket) {
        // Goal 2: The Garden Cheerleader (Pocket Progress)
        final pockets = await ApiService.getPockets();
        double bestRatio = -1.0;
        String? bestPocketName;

        for (var p in pockets) {
          double current = (p['current_balance'] ?? 0).toDouble();
          double target = (p['target_amount'] ?? 0).toDouble();
          bool isLocked = p['is_locked'] ?? false;

          if (target > 0 && !isLocked) {
            double ratio = current / target;
            // We only want to cheer for pockets that are in progress
            if (ratio > bestRatio && ratio < 1.0) {
              bestRatio = ratio;
              bestPocketName = p['name'];
            }
          }
        }

        if (bestRatio > 0 && bestPocketName != null) {
          speak("You are ${(bestRatio * 100).toInt()}% of the way to your '$bestPocketName' goal! Keep going!");
          _isNextCheerPocket = false; 
        } else {
          // If no pocket is currently active, instantly fallback to checking Habit Tax
          _isNextCheerPocket = false;
          _triggerPeriodicCheer(); 
        }

      } else {
        // Goal 3: Habit Tax Celebrations
        final taxData = await ApiService.getHabitTax();
        bool isAvailable = taxData['available'] ?? false;
        double amount = (taxData['amount'] ?? 0).toDouble();

        if (isAvailable && amount > 0) {
          speak("You've secretly saved RM ${amount.toStringAsFixed(2)} in your Habit Tabung just by having fun!");
        }
        
        _isNextCheerPocket = true; 
      }
    } catch (e) {
      debugPrint("Cheer error: $e"); // Fails silently to prevent disrupting the user experience
    }
  }

  String get _gifPath {
    String f1 = _species.toLowerCase();
    String f2 = _level <= 3 ? 'kitten' : 'cat';
    String px = _species == 'Tabby' ? (_level <= 3 ? 'kit_' : 'cat_') : (_level <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$f1/$f2/${px}idle.gif';
  }

  void speak(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _message == text) {
        setState(() => _message = null);
      }
    });
  }

  // 🔥 Replaced _triggerAIInsight with this to fulfill Goal 1
  void _triggerSavingsTip() async {
    setState(() => _message = "Thinking...");

    try {
      String tip = await ApiService.getSavingsTip();
      speak("💡 Tip: $tip");
    } catch (e) {
      speak("Meow! Systems offline.");
    }
  }

  double _bubbleLeftOffset(double screenWidth) {
    final double idealLeft = (_petSize - _bubbleMaxWidth) / 2;
    final double minLeft = -_position.dx;
    final double maxLeft = screenWidth - _position.dx - _bubbleMaxWidth;
    return idealLeft.clamp(minLeft, maxLeft);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _species.isEmpty) return const SizedBox.shrink();

    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;
    final double bottomBarHeight = 85.0 + safePadding.bottom;

    final Widget petAvatar = Container(
      width: _petSize,
      height: _petSize,
      decoration: BoxDecoration(
        color: const Color(0xFFECEEEA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F5238), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Center(
        child: Image.asset(
          _gifPath,
          width: 45,
          height: 45,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, 
              onPanUpdate: (details) {
                // Goal 1: Stop any active snapping animation if the user grabs the pet mid-flight
                if (_snapController.isAnimating) {
                  _snapController.stop();
                }

                setState(() {
                  double newX = _position.dx + details.delta.dx;
                  double newY = _position.dy + details.delta.dy;
                  
                  newY = newY.clamp(safePadding.top, screenSize.height - bottomBarHeight - _petSize);
                  newX = newX.clamp(0.0, screenSize.width - _petSize);
                  
                  _position = Offset(newX, newY);
                });
              },
              
              // Goal 1: Trigger Edge Snapping on release
              onPanEnd: (details) {
                final double leftEdgeDist = _position.dx;
                final double rightEdgeDist = screenSize.width - _petSize - _position.dx;
                
                // Determine which edge is closer
                final double targetX = leftEdgeDist < rightEdgeDist 
                    ? _edgeMargin 
                    : (screenSize.width - _petSize - _edgeMargin);
                
                _snapAnimation = Tween<Offset>(
                  begin: _position,
                  end: Offset(targetX, _position.dy),
                ).animate(CurvedAnimation(
                  parent: _snapController, 
                  curve: Curves.easeOutCubic,
                ));
                
                _snapController.forward(from: 0.0);
              },
              onTap: _triggerSavingsTip, // 🔥 Swapped to the new Savings Tip logic!
              child: SizedBox(
                width: _petSize,
                height: _petSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    petAvatar,
                    if (_message != null)
                      Positioned(
                        bottom: _petSize + 8, 
                        left: _bubbleLeftOffset(screenSize.width),
                        width: _bubbleMaxWidth,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                            border: Border.all(color: const Color(0xFF0F5238).withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Text(
                            _message!,
                            style: const TextStyle(color: Color(0xFF0F5238), fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}