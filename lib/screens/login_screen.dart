import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:nutrisync/screens/signup_screen.dart';

/// LoginScreen provides login and signup forms, with loading and error feedback.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email and password are required.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.'), backgroundColor: Colors.red),
      );
      return;
    }
    final result = await authService.signInWithEmail(email, password);
    if (result.error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      _emailController.clear();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithGoogle();
    if (result.error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign in successful!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo/avatar
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'images/crate a app icon for nutrisync app_1 -  personalized food_diet app.jpg', // Using existing app icon
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.restaurant, size: 48, color: Colors.green[700]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('NutriSync',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42))),
              const SizedBox(height: 8),
              const Text('Eat smart. Live better.',
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 32),
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.green[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.green[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword ?? true,
                      ),
                      const SizedBox(height: 12),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5B42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : _handleSignIn,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Login', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF2D5B42)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: const Text('Sign Up', style: TextStyle(fontSize: 16, color: Color(0xFF2D5B42))),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('or continue with', style: TextStyle(color: Colors.black54)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Image.asset('images/goolge logo.png', height: 28, width: 28, errorBuilder: (c, e, s) => Icon(Icons.g_mobiledata, color: Colors.red, size: 28)),
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            tooltip: 'Google',
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Image.asset('images/apple logo.png', height: 28, width: 28, errorBuilder: (c, e, s) => Icon(Icons.apple, color: Colors.black, size: 28)),
                            onPressed: () {}, // TODO: Implement Apple login
                            tooltip: 'Apple',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('© 2025 NutriSync', style: TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
