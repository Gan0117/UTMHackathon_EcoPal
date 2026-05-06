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
      ), // Note: Removed the stray 'z' that was here!
      home: const AuthGate(),
    );
  }
}

// ✅ FIX: Changed from StatefulWidget to StatelessWidget
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Using StreamBuilder instead of Navigator
    return StreamBuilder<AuthState>(
      // This stream constantly listens to Supabase for login/logout events
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        
        // 1. Show a loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0F5238)),
            ),
          );
        }

        // 2. Extract the session from the stream
        final session = snapshot.data?.session;

        // 3. Traffic Cop Logic: Session exists? Pet Room. No Session? Login Page.
        if (session != null) {
          return const PetRoomPage();
        }

        return const LoginPage();
      },
    );
  }
}