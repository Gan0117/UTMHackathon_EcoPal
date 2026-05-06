import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/pet_room_page.dart';
import 'screens/profile_page.dart';
import 'screens/garden_page.dart';
import 'widgets/bottom_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pccyxrqilbmhmuagyxxe.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjY3l4cnFpbGJtaG11YWd5eHhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc5MDg1MzIsImV4cCI6MjA5MzQ4NDUzMn0.e-wPHS7iuo7ngto5u9h8UwaoEaU_jRIg2U7bo-3qbqM',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Living Ledger - EcoPal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5238)),
        fontFamily: 'Plus Jakarta Sans',
      ),
      home: const AuthGate(),
    );
  }
}

// ── Auth Gate ──
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GardenPage()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const GardenPage();
    }
    return const LoginPage();
  }
}


class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const GardenPage(),   // index 0 = Garden
      const SizedBox(),     // index 1 = Scanner
      const PetRoomPage(),  // index 2 = Pet
      const SizedBox(),     // index 3 = Insights
      const ProfilePage(),  // index 4 = Profile
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: EcoPalBottomBar(
        currentIndex: _currentIndex,
      ),
    );
  }
}