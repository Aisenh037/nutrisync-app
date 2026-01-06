import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/user_model.dart';

/// Comprehensive profile setup screen for voice-first AI agent
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Form data
  String? _gender;
  String? _activityLevel;
  String? _preferredLanguage = 'hinglish';
  final Set<String> _selectedDietaryNeeds = {};
  final Set<String> _selectedHealthGoals = {};
  final Set<String> _selectedMedicalConditions = {};
  final Set<String> _selectedAllergies = {};
  final Set<String> _selectedFoodDislikes = {};
  String _preferredRegion = 'North Indian';

  // Options
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _activityLevels = [
    'Sedentary (little/no exercise)',
    'Light (light exercise 1-3 days/week)',
    'Moderate (moderate exercise 3-5 days/week)',
    'Active (hard exercise 6-7 days/week)',
    'Very Active (very hard exercise, physical job)',
  ];
  final List<String> _languageOptions = ['Hindi', 'English', 'Hinglish'];
  final List<String> _dietaryOptions = [
    'Vegetarian', 'Vegan', 'Jain', 'Gluten-free', 'Dairy-free', 'Keto', 
    'Low-carb', 'Mediterranean', 'Paleo', 'Halal', 'Kosher', 'Raw food'
  ];
  final List<String> _healthGoalOptions = [
    'Weight loss', 'Weight gain', 'Muscle building', 'Maintain weight',
    'Improve energy', 'Better digestion', 'Heart health', 'Blood sugar control',
    'Sports performance', 'General wellness', 'Reduce inflammation', 'Better sleep'
  ];
  final List<String> _medicalConditionOptions = [
    'Diabetes', 'Hypertension', 'Heart disease', 'Thyroid disorder',
    'PCOS/PCOD', 'Kidney disease', 'Liver disease', 'Arthritis',
    'High cholesterol', 'Anemia', 'Gastritis', 'IBS'
  ];
  final List<String> _allergyOptions = [
    'Nuts', 'Dairy', 'Gluten', 'Soy', 'Eggs', 'Fish', 'Shellfish',
    'Sesame', 'Mustard', 'Sulfites', 'Food additives'
  ];
  final List<String> _foodDislikeOptions = [
    'Spicy food', 'Sweet food', 'Bitter gourd', 'Okra', 'Brinjal',
    'Cauliflower', 'Cabbage', 'Onions', 'Garlic', 'Cilantro',
    'Coconut', 'Paneer', 'Fish', 'Chicken', 'Mutton'
  ];
  final List<String> _regionalCuisines = [
    'North Indian', 'South Indian', 'Bengali', 'Gujarati', 'Maharashtrian',
    'Punjabi', 'Rajasthani', 'Tamil', 'Kerala', 'Andhra', 'Kashmiri'
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final profileService = ref.read(userProfileServiceProvider);
      
      final culturalPreferences = {
        'preferredRegion': _preferredRegion,
        'spiceLevel': 'medium', // Default
        'cookingStyle': 'traditional', // Default
      };

      final result = await profileService.updateProfile(
        uid: user.uid,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        activityLevel: _activityLevel,
        dietaryNeeds: _selectedDietaryNeeds.toList(),
        healthGoals: _selectedHealthGoals.toList(),
        medicalConditions: _selectedMedicalConditions.toList(),
        allergies: _selectedAllergies.toList(),
        foodDislikes: _selectedFoodDislikes.toList(),
        preferredLanguage: _preferredLanguage,
        culturalPreferences: culturalPreferences,
      );

      if (result.error != null) {
        throw Exception(result.error);
      }

      // Refresh user provider
      ref.invalidate(userProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        title: const Text('Complete Your Profile', style: TextStyle(color: Color(0xFF2D5B42))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D5B42)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 6,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D5B42)),
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildBasicInfoPage(),
                _buildPhysicalMeasurementsPage(),
                _buildDietaryPreferencesPage(),
                _buildHealthGoalsPage(),
                _buildMedicalInfoPage(),
                _buildCulturalPreferencesPage(),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2D5B42)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous', style: TextStyle(color: Color(0xFF2D5B42))),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5B42),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_currentPage == 5 ? 'Complete Setup' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Help us understand you better for personalized recommendations.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: _genderOptions.map((gender) {
              return DropdownMenuItem(value: gender, child: Text(gender));
            }).toList(),
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _preferredLanguage,
            decoration: const InputDecoration(
              labelText: 'Preferred Language',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.language),
            ),
            items: _languageOptions.map((lang) {
              return DropdownMenuItem(value: lang.toLowerCase(), child: Text(lang));
            }).toList(),
            onChanged: (value) => setState(() => _preferredLanguage = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalMeasurementsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Physical Measurements',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'These help us calculate your nutritional needs accurately.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.height),
              helperText: 'e.g., 170',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monitor_weight),
              helperText: 'e.g., 65',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(
              labelText: 'Activity Level',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center),
            ),
            items: _activityLevels.map((level) {
              return DropdownMenuItem(value: level, child: Text(level, style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: (value) => setState(() => _activityLevel = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all dietary preferences that apply to you.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
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
          
          const SizedBox(height: 24),
          const Text(
            'Foods You Dislike',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll avoid suggesting these in your meal plans.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _foodDislikeOptions.map((option) {
              final isSelected = _selectedFoodDislikes.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFoodDislikes.add(option);
                    } else {
                      _selectedFoodDislikes.remove(option);
                    }
                  });
                },
                selectedColor: Colors.red[100],
                checkmarkColor: Colors.red[700],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGoalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Goals',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'What are your primary health and fitness goals?',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _healthGoalOptions.map((option) {
              final isSelected = _selectedHealthGoals.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHealthGoals.add(option);
                    } else {
                      _selectedHealthGoals.remove(option);
                    }
                  });
                },
                selectedColor: Colors.blue[100],
                checkmarkColor: Colors.blue[700],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medical Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'This information helps us provide safer recommendations. (Optional)',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Medical Conditions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _medicalConditionOptions.map((option) {
              final isSelected = _selectedMedicalConditions.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedMedicalConditions.add(option);
                    } else {
                      _selectedMedicalConditions.remove(option);
                    }
                  });
                },
                selectedColor: Colors.orange[100],
                checkmarkColor: Colors.orange[700],
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Allergies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _allergyOptions.map((option) {
              final isSelected = _selectedAllergies.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAllergies.add(option);
                    } else {
                      _selectedAllergies.remove(option);
                    }
                  });
                },
                selectedColor: Colors.red[100],
                checkmarkColor: Colors.red[700],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCulturalPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cultural Preferences',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Help us suggest foods that match your cultural preferences.',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Preferred Regional Cuisine',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _regionalCuisines.map((cuisine) {
              final isSelected = _preferredRegion == cuisine;
              return ChoiceChip(
                label: Text(cuisine),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _preferredRegion = cuisine);
                  }
                },
                selectedColor: Colors.green[100],
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 48),
                const SizedBox(height: 16),
                const Text(
                  'You\'re all set!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your profile will help our AI provide personalized nutrition advice in your preferred language and cultural context.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}