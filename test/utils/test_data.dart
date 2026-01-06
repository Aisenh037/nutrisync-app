/// Test data and utilities for authentication tests
class AuthTestData {
  // Valid test credentials
  static const validEmail = 'test@example.com';
  static const validPassword = 'password123';
  static const validName = 'Test User';

  // Invalid test data
  static const invalidEmail = 'invalid-email';
  static const shortPassword = '123';
  static const emptyEmail = '';
  static const emptyPassword = '';

  // Error messages (should match your actual error messages)
  static const emailRequiredError = 'Email and password are required.';
  static const passwordTooShortError = 'Password must be at least 6 characters.';
  static const invalidCredentialsError = 'Invalid credentials';
  static const userNotFoundError = 'No user found for that email';
  static const emailAlreadyInUseError = 'The account already exists for that email';
  static const weakPasswordError = 'The password provided is too weak';
  static const invalidEmailError = 'The email address is badly formatted';

  // Test user data for signup
  static const testUsers = [
    {
      'name': 'John Doe',
      'email': 'john.doe@example.com',
      'password': 'securepassword123',
      'dietaryNeeds': ['Vegetarian', 'Gluten-free'],
      'healthGoals': ['Weight loss', 'Better digestion'],
    },
    {
      'name': 'Jane Smith',
      'email': 'jane.smith@example.com',
      'password': 'anotherpassword456',
      'dietaryNeeds': ['Vegan'],
      'healthGoals': ['Maintain weight', 'Heart health'],
    },
    {
      'name': 'Bob Johnson',
      'email': 'bob.johnson@example.com',
      'password': 'bobspassword789',
      'dietaryNeeds': ['Keto', 'Low-carb'],
      'healthGoals': ['Weight gain', 'Muscle building'],
    },
  ];

  // Edge case test data
  static const edgeCaseEmails = [
    'a@b.co', // Very short but valid
    'very.long.email.address.with.many.dots@very-long-domain-name.com', // Very long
    'user+tag@example.com', // Plus sign
    'user.name@example.com', // Dot in name
    'user123@example-domain.com', // Numbers and hyphens
  ];

  static const edgeCasePasswords = [
    'abcdef', // Minimum length
    'a' * 100, // Very long password
    'password!@#\$%^&*()', // Special characters
    'пароль123', // Non-ASCII characters
    'pass word', // Space in password
  ];

  // Invalid email formats for testing
  static const invalidEmails = [
    '',
    'invalid',
    '@example.com',
    'user@',
    'user..name@example.com',
    'user@.com',
    'user@com',
    'user name@example.com',
    'user@domain.',
    '.user@example.com',
  ];

  // Invalid passwords for testing
  static const invalidPasswords = [
    '',
    ' ',
    '  ',
    '\t',
    '\n',
    '12345', // Too short
    'a', // Way too short
  ];
}

/// Utility functions for testing
class AuthTestUtils {
  /// Generate a random email for testing
  static String generateRandomEmail() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'test$timestamp@example.com';
  }

  /// Generate a random password for testing
  static String generateRandomPassword({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }

  /// Check if an email format is valid (basic validation)
  static bool isValidEmailFormat(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  /// Check if a password meets minimum requirements
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Create test user data
  static Map<String, dynamic> createTestUser({
    String? name,
    String? email,
    String? password,
    List<String>? dietaryNeeds,
    List<String>? healthGoals,
  }) {
    return {
      'name': name ?? 'Test User',
      'email': email ?? generateRandomEmail(),
      'password': password ?? generateRandomPassword(),
      'dietaryNeeds': dietaryNeeds ?? ['Vegetarian'],
      'healthGoals': healthGoals ?? ['General wellness'],
    };
  }
}