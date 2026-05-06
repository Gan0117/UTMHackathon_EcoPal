import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/pet_room_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with your backend credentials
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5238)), // primary color
        fontFamily: 'Plus Jakarta Sans', // From your HTML design
      ),
      // System must route to login/signup page when starting
      home: const AuthGate(),
    );
  }
}

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
        // ✅ Fired after Google OAuth redirect completes
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PetRoomPage()),
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
    // Check if already logged in on app start (e.g. returning user)
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const PetRoomPage();
    }
    return const LoginPage();
  }
}