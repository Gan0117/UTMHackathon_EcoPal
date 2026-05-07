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

class FloatingPetState extends State<FloatingPet> {
  // Initial floating position on the screen
  Offset _position = const Offset(20, 100);

  // Dynamic Pet State
  String _species = '';
  int _level = 1;
  bool _isLoading = true;

  // AI Chatbox State
  String? _message;

  // Approximate sizes for boundary calculations
  final double _petSize = 65.0;
  final double _bubbleMaxWidth = 220.0;

  @override
  void initState() {
    super.initState();
    _loadPetData();
    reloadPetTrigger.addListener(_loadPetData);
  }

  @override
  void dispose() {
    reloadPetTrigger.removeListener(_loadPetData);
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
    setState(() => _message = "Analyzing your spending...");

    try {
      String aiResponse = await ApiService.getRealityCheck();
      speak(aiResponse);
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
                setState(() {
                  double newX = _position.dx + details.delta.dx;
                  double newY = _position.dy + details.delta.dy;
                  
                  newY = newY.clamp(safePadding.top, screenSize.height - bottomBarHeight - _petSize);
                  newX = newX.clamp(0.0, screenSize.width - _petSize);
                  
                  _position = Offset(newX, newY);
                });
              },
              onTap: _triggerAIInsight,
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