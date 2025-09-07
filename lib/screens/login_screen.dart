import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';

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

  Future<void> _handleSignUp() async {
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
    final result = await authService.signUpWithEmail(email, password);
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
        const SnackBar(content: Text('Signup successful!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Welcome to NutriSync',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignIn,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Login'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}