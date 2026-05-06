import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'pet_room_page.dart';
import 'package:flutter/foundation.dart';
import 'pet_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- STANDARD EMAIL AUTH ---
  Future<void> _handleAuth(bool isLogin) async {
    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      
      _routeToPetRoom();
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An unexpected error occurred')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE SIGN IN AUTH ---
Future<void> _googleSignIn() async {
  setState(() => _isLoading = true);
  try {
    if (kIsWeb) {
      // ✅ Web: Use Supabase OAuth redirect (no google_sign_in package needed)
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin, // automatically uses current localhost/domain
      );
      // No manual routing needed — Supabase handles the redirect back
    } else {
      // ✅ Mobile (Android/iOS): Use google_sign_in package
      const webClientId = '696185186578-07d6faaln1eio2ppnlkfg5tjtnd8deld.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw 'Sign in aborted by user.';

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) throw 'Missing Google Auth Tokens.';

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _routeToPetRoom() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PetSelectionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0F5238); 
    const Color surfaceSoil = Color(0xFFFDFCF8); 
    const Color onSurfaceVariant = Color(0xFF404943); 

    return Scaffold(
      backgroundColor: surfaceSoil,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9E5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Image.asset('widgets/ecopal_icon.png', width: 48, height: 48), 
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text('EcoPal', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor)),
                const Text('NATURAL FINANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: onSurfaceVariant)),
                const SizedBox(height: 32),

                // Inputs
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const CircularProgressIndicator(color: primaryColor)
                else
                  Column(
                    children: [
                      // Email/Password Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleAuth(false), 
                          child: const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Colors.grey, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleAuth(true), 
                          child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade400)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade400)),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Google Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          // A standard Google 'G' logo placeholder icon
                          icon: Image.network('https://img.icons8.com/?size=100&id=17949&format=png&color=000000', height: 24),
                          label: const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          onPressed: _googleSignIn,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}