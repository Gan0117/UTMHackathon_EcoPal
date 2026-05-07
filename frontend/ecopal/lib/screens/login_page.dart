import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'pet_selection_page.dart';
import '../widgets/floating_pet.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isLoading = false;

  // Animation variables for the floating icon
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    //hide global floating pet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = false;
    });
    
    // Listen for focus changes to trigger UI rebuilds (Glass -> Solid)
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Setup the slow up-and-down floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 2 seconds up, 2 seconds down
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _floatController.dispose(); // Always dispose animations!
    super.dispose();
  }

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
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin, 
        );
      } else {
        const webClientId = '696185186578-07d6faaln1eio2ppnlkfg5tjtnd8deld.apps.googleusercontent.com';
        final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: webClientId);
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

  Widget _buildDynamicInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required bool isPassword,
  }) {
    final bool isFocused = focusNode.hasFocus;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : Colors.white.withOpacity(0.2), // Solid vs Glass
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? const Color(0xFF0F5238) : Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: isFocused ? [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))
        ] : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        style: TextStyle(color: isFocused ? Colors.black87 : Colors.white),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: isFocused ? const Color(0xFF0F5238) : Colors.white.withOpacity(0.9),
            fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
          ),
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0F5238); 

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('widgets/login_page.gif'),
            fit: BoxFit.cover, 
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  // Floating Animated Icon
                  AnimatedBuilder(
                    animation: _floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: Offset(0, 15 - _floatAnimation.value),
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'widgets/ecopal_icon.png', 
                              fit: BoxFit.cover, 
                            ), 
                          ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 16),
                  
                  // Title Text
                  const Text('EcoPal', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))])),
                  const Text('NATURAL FINANCE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Colors.white70)),
                  const SizedBox(height: 48),

                  // Dynamic Inputs
                  _buildDynamicInput(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    labelText: 'Email',
                    isPassword: false,
                  ),
                  const SizedBox(height: 16),
                  _buildDynamicInput(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    labelText: 'Password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Column(
                      children: [
                        
                        // Sign Up Button 
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              // 🔥 Added Hover State Support
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return primaryColor; 
                                return primaryColor.withOpacity(0.4); // Glass
                              }),
                              foregroundColor: WidgetStateProperty.all(Colors.white),
                              elevation: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return 8.0;
                                return 0.0;
                              }),
                              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                              )),
                            ),
                            onPressed: () => _handleAuth(false), 
                            child: const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              // 🔥 Added Hover State Support
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return Colors.white; 
                                return Colors.white.withOpacity(0.15); // Glass
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return primaryColor;
                                return Colors.white;
                              }),
                              elevation: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return 8.0;
                                return 0.0;
                              }),
                              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                              )),
                            ),
                            onPressed: () => _handleAuth(true), 
                            child: const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        // Google Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ButtonStyle(
                              // 🔥 Added Hover State Support
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return Colors.white; 
                                return Colors.white.withOpacity(0.2); // Glass
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return Colors.black87;
                                return Colors.white;
                              }),
                              elevation: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return 8.0;
                                return 0.0;
                              }),
                              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                              )),
                            ),
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
      ),
    );
  }
}