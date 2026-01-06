import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/api/auth_service.dart';

void main() {
  group('AuthService Property-Based Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    group('Email Validation Properties', () {
      test('Property: Valid email formats should not cause crashes', () async {
        // Property: For any valid email format, the service should handle it gracefully
        final validEmails = [
          'user@example.com',
          'user.name@example.com',
          'user+tag@example.com',
          'user123@example-domain.com',
          'a@b.co',
          'very.long.email.address@very-long-domain-name.com',
        ];

        for (final email in validEmails) {
          // Act & Assert - Should not throw exceptions
          final result = await authService.signInWithEmail(email, 'password123');
          
          // The result should either succeed or fail gracefully with an error message
          expect(result.user != null || result.error != null, isTrue,
              reason: 'Email $email should produce either a user or error');
        }
      });

      test('Property: Invalid email formats should return errors', () async {
        // Property: For any invalid email format, the service should return an error
        final invalidEmails = [
          '',
          'invalid',
          '@example.com',
          'user@',
          'user..name@example.com',
          'user@.com',
          'user@com',
          'user name@example.com', // space in email
        ];

        for (final email in invalidEmails) {
          final result = await authService.signInWithEmail(email, 'password123');
          
          // Should return an error for invalid email formats
          expect(result.error, isNotNull,
              reason: 'Invalid email $email should return an error');
          expect(result.user, isNull,
              reason: 'Invalid email $email should not return a user');
        }
      });
    });

    group('Password Validation Properties', () {
      test('Property: Empty passwords should return errors', () async {
        // Property: For any empty or whitespace-only password, should return error
        final invalidPasswords = ['', ' ', '  ', '\t', '\n'];

        for (final password in invalidPasswords) {
          final result = await authService.signInWithEmail('test@example.com', password);
          
          expect(result.error, isNotNull,
              reason: 'Empty/whitespace password "$password" should return an error');
          expect(result.user, isNull,
              reason: 'Empty/whitespace password "$password" should not return a user');
        }
      });

      test('Property: Password length validation', () async {
        // Property: Passwords of different lengths should be handled consistently
        final passwordLengths = [1, 2, 3, 4, 5, 6, 10, 20, 50, 100];

        for (final length in passwordLengths) {
          final password = 'a' * length;
          final result = await authService.signUpWithEmail('test@example.com', password);
          
          // Firebase requires minimum 6 characters
          if (length < 6) {
            expect(result.error, isNotNull,
                reason: 'Password of length $length should return an error');
          }
          
          // Should always return either user or error, never both or neither
          expect((result.user != null) != (result.error != null), isTrue,
              reason: 'Password of length $length should return exactly one of user or error');
        }
      });
    });

    group('Input Sanitization Properties', () {
      test('Property: Special characters in email should be handled', () async {
        // Property: Emails with various special characters should not cause crashes
        final specialCharEmails = [
          'user+test@example.com',
          'user.test@example.com',
          'user-test@example.com',
          'user_test@example.com',
          'user123@example.com',
        ];

        for (final email in specialCharEmails) {
          final result = await authService.signInWithEmail(email, 'password123');
          
          // Should handle gracefully without throwing exceptions
          expect(result.user != null || result.error != null, isTrue,
              reason: 'Special char email $email should be handled gracefully');
        }
      });

      test('Property: Special characters in password should be handled', () async {
        // Property: Passwords with special characters should work
        final specialCharPasswords = [
          'password!@#',
          'pass word',
          'пароль123', // Cyrillic characters
          'パスワード', // Japanese characters
          'password\n\t',
          'password"quotes"',
          "password'single'",
        ];

        for (final password in specialCharPasswords) {
          final result = await authService.signInWithEmail('test@example.com', password);
          
          // Should handle gracefully without throwing exceptions
          expect(result.user != null || result.error != null, isTrue,
              reason: 'Special char password should be handled gracefully');
        }
      });
    });

    group('Consistency Properties', () {
      test('Property: Same credentials should produce consistent results', () async {
        // Property: Calling with same credentials multiple times should be consistent
        const email = 'test@example.com';
        const password = 'password123';

        final result1 = await authService.signInWithEmail(email, password);
        final result2 = await authService.signInWithEmail(email, password);

        // Results should be consistent (both succeed or both fail with same error)
        expect(result1.error == result2.error, isTrue,
            reason: 'Same credentials should produce consistent error results');
        
        if (result1.user != null && result2.user != null) {
          expect(result1.user!.uid, equals(result2.user!.uid),
              reason: 'Same credentials should return same user');
        }
      });

      test('Property: AuthResult should never have both user and error', () async {
        // Property: AuthResult should be in a valid state (either user OR error, not both)
        final testCases = [
          ('valid@example.com', 'password123'),
          ('invalid@example.com', 'wrongpassword'),
          ('', ''),
          ('test@example.com', ''),
          ('', 'password'),
        ];

        for (final (email, password) in testCases) {
          final result = await authService.signInWithEmail(email, password);
          
          // Should never have both user and error
          expect(result.user != null && result.error != null, isFalse,
              reason: 'AuthResult should not have both user and error for $email/$password');
          
          // Should have at least one of user or error
          expect(result.user != null || result.error != null, isTrue,
              reason: 'AuthResult should have either user or error for $email/$password');
        }
      });
    });

    group('Error Handling Properties', () {
      test('Property: All errors should be user-friendly strings', () async {
        // Property: Any error returned should be a non-empty, user-readable string
        final errorCases = [
          ('', 'password'),
          ('invalid-email', 'password'),
          ('test@example.com', ''),
          ('nonexistent@example.com', 'wrongpassword'),
        ];

        for (final (email, password) in errorCases) {
          final result = await authService.signInWithEmail(email, password);
          
          if (result.error != null) {
            expect(result.error!.isNotEmpty, isTrue,
                reason: 'Error message should not be empty for $email/$password');
            expect(result.error!.trim(), isNotEmpty,
                reason: 'Error message should not be just whitespace for $email/$password');
            // Error should be reasonably short (user-friendly)
            expect(result.error!.length, lessThan(200),
                reason: 'Error message should be reasonably short for $email/$password');
          }
        }
      });
    });
  });
}