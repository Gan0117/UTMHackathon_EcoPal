import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

class PetRoomPage extends StatefulWidget {
  const PetRoomPage({super.key});

  @override
  State<PetRoomPage> createState() => _PetRoomPageState();
}

class _PetRoomPageState extends State<PetRoomPage> {
  String _currentCatGif = 'widgets/cat_idle.gif';
  bool _isInteracting = false; 
  final int _oneTurnDurationMs = 1000; 

  void _handleTap() async {
    if (_isInteracting) return; 
    setState(() {
      _isInteracting = true;
      _currentCatGif = 'widgets/cat_happy.gif';
    });
    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 4));
    if (mounted) {
      setState(() {
        _currentCatGif = 'widgets/cat_idle.gif';
        _isInteracting = false;
      });
    }
  }

  void _handleFeed() async {
    if (_isInteracting) return;
    setState(() {
      _isInteracting = true;
      _currentCatGif = 'widgets/cat_eat.gif';
    });
    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 1));
    if (mounted) {
      setState(() {
        _currentCatGif = 'widgets/cat_happy.gif';
      });
    }
    await Future.delayed(Duration(milliseconds: _oneTurnDurationMs * 4));
    if (mounted) {
      setState(() {
        _currentCatGif = 'widgets/cat_idle.gif';
        _isInteracting = false;
      });
    }
  }

  // Optional: Add a logout function
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF95D4B3), // inverse-primary from design
        title: const Text('Interact with AI Pet', style: TextStyle(color: Color(0xFF002114))),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF002114)),
            onPressed: _signOut,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            DragTarget<String>(
              onAcceptWithDetails: (details) {
                if (details.data == 'fish_food') {
                  _handleFeed();
                }
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: _handleTap,
                  child: Image.asset(
                    _currentCatGif,
                    width: 150, 
                    height: 150,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none, 
                  ),
                );
              },
            ),
            const Text(
              'Drag the fish to feed, or tap to pet!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Draggable<String>(
              data: 'fish_food', 
              feedback: Image.asset('widgets/fish.gif', width: 140, height: 140, filterQuality: FilterQuality.none),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: Image.asset('widgets/fish.gif', width: 140, height: 140, filterQuality: FilterQuality.none),
              ),
              child: Image.asset('widgets/fish.gif', width: 140, height: 140, filterQuality: FilterQuality.none),
            ),
          ],
        ),
      ),
    );
  }
}