import 'package:flutter/material.dart';
import 'dart:ui'; // Required for the blur effect
import '../screens/pet_room_page.dart';
import '../screens/profile_page.dart';
import '../screens/garden_page.dart';

class EcoPalBottomBar extends StatelessWidget {
  final int currentIndex;

  const EcoPalBottomBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Do nothing if tapping the active tab

    Widget page;
    switch (index) {
      case 0: // Index 0 is the Garden
        page = const GardenPage();
        break;
      case 2: // Index 2 is the Pet Room
        page = const PetRoomPage();
        break;
      case 4: // Index 4 is the Profile Page
        page = const ProfilePage();
        break;
      default:
        // Placeholder for Scanner and Insights
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feature coming soon!')),
        );
        return;
    }

    // Navigate without animation for a seamless "tab" feel
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 90, 
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4), 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(context, icon: Icons.yard_rounded, label: 'Garden', index: 0),
                  _buildNavItem(context, icon: Icons.qr_code_scanner, label: 'Scanner', index: 1),
                  _buildNavItem(context, icon: Icons.pets, label: 'Pet', index: 2),
                  _buildNavItem(context, icon: Icons.analytics_outlined, label: 'Insights', index: 3),
                  _buildNavItem(context, icon: Icons.person_outline, label: 'Profile', index: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

 
  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, required int index}) {
    final bool isActive = currentIndex == index;
    
    const Color activeBgColor = Color(0xFFA7FFEB); 
    const Color activeIconColor = Color(0xFF00734D); 
    const Color inactiveIconColor = Color(0xFF404943); 

    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isActive ? 12 : 8), 
            decoration: BoxDecoration(
              color: isActive ? activeBgColor : Colors.transparent,
              shape: BoxShape.circle, 
            ),
            child: Icon(
              icon,
              size: isActive ? 26 : 24,
              color: isActive ? activeIconColor : inactiveIconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? activeIconColor : inactiveIconColor,
            ),
          ),
        ],
      ),
    );
  }
}