import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class FloatingPet extends StatefulWidget {
  const FloatingPet({super.key});

  @override
  State<FloatingPet> createState() => FloatingPetState();
}

class FloatingPetState extends State<FloatingPet> {
  // Initial floating position on the screen
  Offset _position = const Offset(20, 100);

  // Dynamic Pet State
  String _species = '';
  int _level = 1;
  int _happiness = 100;
  bool _isLoading = true;

  // AI Chatbox State
  String? _message;
  Timer? _decayTimer;

  // Approximate sizes for boundary calculations
  final double _petSize = 65.0;
  final double _bubbleMaxWidth = 220.0;
  final double _bubbleHeight = 70.0; // approximate bubble height

  @override
  void initState() {
    super.initState();
    _loadPetData();

    // Ensure dynamic background decay runs continuously on ALL pages
    _decayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isLoading && _happiness > 0) {
        setState(() {
          _happiness = (_happiness - 1).clamp(0, 100);
        });

        // Trigger the lonely message dynamically if they cross the threshold while on the page
        if (_happiness == 49 && _message == null) {
          speak("I feel lonely...");
        }
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
      if (mounted) {
        setState(() {
          _species = petData['species'] ?? 'Tabby';
          _level = petData['level'] ?? 1;
          _happiness = petData['happiness_level'] ?? 100;

          if (petData['last_interaction'] != null) {
            DateTime lastInteraction = DateTime.parse(petData['last_interaction']);
            Duration difference = DateTime.now().difference(lastInteraction);
            int lostHappiness = difference.inHours;
            _happiness = (_happiness - lostHappiness).clamp(0, 100);
          }

          _isLoading = false;
        });

        if (_happiness < 50) {
          speak("I feel lonely...");
        }
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

  void _triggerAIInsight() async {
    if (_message != null && _message != "I feel lonely...") return;

    setState(() => _message = "Analyzing your spending...");

    try {
      String aiResponse = await ApiService.getRealityCheck();
      speak(aiResponse);
    } catch (e) {
      speak("Meow! Systems offline.");
    }
  }

  /// Calculates the bubble's horizontal offset relative to the pet's Positioned
  /// origin so it never escapes the screen on either side.
  ///
  /// The bubble is rendered above the pet via a Stack / Positioned(bottom:…).
  /// Its ideal position centres it over the pet, but we clamp it so that:
  ///   • left edge  >= -_position.dx               (never past screen left)
  ///   • right edge <= screenWidth - _position.dx  (never past screen right)
  double _bubbleLeftOffset(double screenWidth) {
    // Ideal: centre the bubble over the pet avatar
    final double idealLeft = (_petSize - _bubbleMaxWidth) / 2;

    // How far the bubble can slide left before it leaves the screen
    final double minLeft = -_position.dx;

    // How far the bubble can slide right before it leaves the screen
    final double maxLeft = screenWidth - _position.dx - _bubbleMaxWidth;

    return idealLeft.clamp(minLeft, maxLeft);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _species.isEmpty) return const SizedBox.shrink();

    final Size screenSize = MediaQuery.of(context).size;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;

    // Estimate bottom bar height (standard icons/text padding + safe area)
    final double bottomBarHeight = 85.0 + safePadding.bottom;

    // Pet avatar widget
    final Widget petAvatar = Container(
      width: _petSize,
      height: _petSize,
      decoration: BoxDecoration(
        color: const Color(0xFFECEEEA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F5238), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4))
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

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newX = _position.dx + details.delta.dx;
            double newY = _position.dy + details.delta.dy;

            // Prevent going above the top status bar or below the bottom nav bar
            newY = newY.clamp(
                safePadding.top,
                screenSize.height - bottomBarHeight - _petSize);

            // Prevent going off the left or right edges of the screen
            newX = newX.clamp(0.0, screenSize.width - _petSize);

            _position = Offset(newX, newY);
          });
        },
        onTap: _triggerAIInsight,

        // ── Stack keeps the bubble above the pet without affecting the
        //    Positioned widget's footprint on the screen. clipBehavior is
        //    Clip.none so the bubble can overflow the Stack bounds upward
        //    while still being clamped to stay inside the screen.
        child: SizedBox(
          width: _petSize,
          height: _petSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Pet avatar — fills the SizedBox exactly
              petAvatar,

              // Speech bubble — floats above the pet, screen-clamped
              if (_message != null)
                Positioned(
                  bottom: _petSize + 8, // gap between bubble base and pet top
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
                      border: Border.all(
                          color: const Color(0xFF0F5238).withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                          color: Color(0xFF0F5238),
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}