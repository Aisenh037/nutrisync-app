import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisync/providers/providers.dart';
import 'package:nutrisync/models/user_model.dart';

/// SignupScreen provides a comprehensive signup form that collects user information
/// including name, dietary needs, and health goals during registration.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dietaryController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Predefined options for dietary needs and health goals
  final List<String> _dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
    'Keto',
    'Low-carb',
    'Mediterranean',
    'Paleo',
    'Halal',
    'Kosher',
  ];

  final List<String> _goalOptions = [
    'Weight loss',
    'Weight gain',
    'Muscle building',
    'Maintain weight',
    'Improve energy',
    'Better digestion',
    'Heart health',
    'Blood sugar control',
    'Sports performance',
    'General wellness',
  ];

  final Set<String> _selectedDietaryNeeds = {};
  final Set<String> _selectedGoals = {};

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _dietaryController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final firestoreService = ref.read(firestoreServiceProvider);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    // Validation
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email, password, and name are required.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email, password, and name are required.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password.length < 6) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Password must be at least 6 characters.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // Sign up with Firebase Auth
      final authResult = await authService.signUpWithEmail(email, password);
      if (authResult.error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = authResult.error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authResult.error!), backgroundColor: Colors.red),
        );
        return;
      }

      final user = authResult.user;
      if (user != null) {
        // Create user profile with additional information
        final userModel = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          dietaryNeeds: _selectedDietaryNeeds.toList(),
          healthGoals: _selectedGoals.toList(),
        );

        // Create a dummy user document immediately after signup
        final dummyUserModel = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          dietaryNeeds: _selectedDietaryNeeds.toList(),
          healthGoals: _selectedGoals.toList(),
        );

        final dummyResult = await firestoreService.setUser(dummyUserModel);
        if (dummyResult.error != null) {
          setState(() {
            _isLoading = false;
            _errorMessage = dummyResult.error;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account created but profile setup failed: ${dummyResult.error}'), backgroundColor: Colors.orange),
          );
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });

        // Clear form
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
        _dietaryController.clear();
        _goalsController.clear();
        _selectedDietaryNeeds.clear();
        _selectedGoals.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!'), backgroundColor: Colors.green),
        );

        // Navigate back to login or home
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Signup failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D5B42)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                    'images/crate a app icon for nutrisync app_1 -  personalized food_diet app.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.restaurant, size: 48, color: Colors.green[700]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('NutriSync',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42))),
              const SizedBox(height: 8),
              const Text('Create your account',
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
                      // Basic Information
                      const Text('Basic Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42))),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: Colors.green[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.green[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.green[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                      ),

                      // Dietary Needs Section
                      const SizedBox(height: 24),
                      const Text('Dietary Preferences',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42))),
                      const SizedBox(height: 8),
                      const Text('Select all that apply (optional)',
                          style: TextStyle(fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _dietaryOptions.map((option) {
                          final isSelected = _selectedDietaryNeeds.contains(option);
                          return FilterChip(
                            label: Text(option),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDietaryNeeds.add(option);
                                } else {
                                  _selectedDietaryNeeds.remove(option);
                                }
                              });
                            },
                            selectedColor: Colors.green[100],
                            checkmarkColor: const Color(0xFF2D5B42),
                          );
                        }).toList(),
                      ),

                      // Health Goals Section
                      const SizedBox(height: 24),
                      const Text('Health Goals',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42))),
                      const SizedBox(height: 8),
                      const Text('Select all that apply (optional)',
                          style: TextStyle(fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _goalOptions.map((option) {
                          final isSelected = _selectedGoals.contains(option);
                          return FilterChip(
                            label: Text(option),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedGoals.add(option);
                                } else {
                                  _selectedGoals.remove(option);
                                }
                              });
                            },
                            selectedColor: Colors.green[100],
                            checkmarkColor: const Color(0xFF2D5B42),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5B42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : _handleSignUp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create Account', style: TextStyle(fontSize: 16)),
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
