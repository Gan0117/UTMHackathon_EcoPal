import 'package:flutter/material.dart';
import 'dart:ui'; // Required for the blur effect
import '../screens/pet_room_page.dart';
import '../screens/profile_page.dart';
import '../screens/scanner_page.dart';
import '../screens/garden_page.dart';

class EcoPalBottomBar extends StatelessWidget {
  final int currentIndex;

  const EcoPalBottomBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Do nothing if tapping the active tab

    Widget page;
    switch (index) {
      case 0: 
        page = const GardenPage();
        break;
      case 1: 
        page = const ScannerPage();
        break;
      case 2: // Index 2 is the Pet Room
        page = const PetRoomPage();
        break;
      case 4: // Index 4 is the Profile Page
        page = const ProfilePage();
        break;
      default:
        // Placeholder for Garden, Scanner, and Insights (for the hackathon demo)
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
    // Colors from your HTML design
    const Color surfaceContainer = Color(0xFFECEEEA);
    const Color outlineVariant = Color(0xFFBFC9C1);
    
    // Outer container provides the drop shadow
    return Container(
      // 🔥 Add mainAxisSize constraint to prevent it from forcing excess height
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -4))
        ],
      ),
      // ClipRRect ensures the blur doesn't bleed outside our rounded top corners
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceContainer.withOpacity(0.30),
              border: Border(top: BorderSide(color: outlineVariant.withOpacity(0.3))),
            ),
            // 🔥 FIX: Set top to false so it stops adding the phone notch padding to the top of the bar!
            child: SafeArea(
              top: false, 
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(context, icon: Icons.yard, label: 'Garden', index: 0),
                    _buildNavItem(context, icon: Icons.qr_code_scanner, label: 'Scanner', index: 1),
                    _buildNavItem(context, icon: Icons.pets, label: 'Pet', index: 2),
                    _buildNavItem(context, icon: Icons.analytics, label: 'Insights', index: 3),
                    _buildNavItem(context, icon: Icons.person, label: 'Profile', index: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, { IconData? icon, required String label, required int index}) {
    final bool isActive = currentIndex == index;
    const Color secondaryContainer = Color(0xFF92F7C3);
    const Color onSurfaceVariant = Color(0xFF404943);

    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      // AnimatedContainer smoothly morphs the padding and background color
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut, // Smooth swelling curve
        padding: isActive ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8) : const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: isActive ? const Color(0xFF00734D) : onSurfaceVariant),
            // Smoothly animates the gap between the icon and text
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: isActive ? 2 : 4,
            ),
            // AnimatedDefaultTextStyle smoothly tweens the font size & weight!
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              style: isActive 
                  ? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00734D))
                  : const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onSurfaceVariant),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}