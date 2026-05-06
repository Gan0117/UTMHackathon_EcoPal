import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class GardenPage extends StatelessWidget {
  const GardenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      extendBody: true, 
      backgroundColor: Colors.black, 
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 0), 
      body: Stack(
        children: [
         
          Positioned.fill(
            child: Image.asset(
              'assets/images/map.gif',
              fit: BoxFit.cover,
            ),
          ),

          
          Positioned(
            top: MediaQuery.of(context).padding.top + 20, 
            right: 16,
            child: Container(
              
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                
                color: Colors.white.withOpacity(0.9), 
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1), 
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, 
                mainAxisSize: MainAxisSize.min, 
                children: const [
                  Text(
                    'SAFE TO SPEND',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey, 
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '\$1,240.00',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20), 
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}