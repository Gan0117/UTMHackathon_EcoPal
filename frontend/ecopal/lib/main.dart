import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/garden_page.dart';
import 'widgets/floating_pet.dart'; // 🔥 Import FloatingPet

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
      // Global floating pet
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            ValueListenableBuilder<bool>(
              valueListenable: showFloatingPet,
              builder: (context, show, childWidget) {
                // Offstage keeps it mounted (saving its position & state) but hides it!
                return Offstage(
                  offstage: !show,
                  child: childWidget!,
                );
              },
              child: const Material(
                type: MaterialType.transparency,
                child: FloatingPet(),
              ),
            ),
          ],
        );
      },
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GardenPage()));
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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