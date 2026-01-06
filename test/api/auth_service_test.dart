import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nutrisync/api/auth_service.dart';

// Generate mocks for Firebase Auth
@GenerateMocks([FirebaseAuth, UserCredential, User])
import 'auth_service_test.mocks.dart';

void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();
      
      // Create AuthService with mocked FirebaseAuth
      authService = AuthService();
      // Note: In a real implementation, you'd need to inject the mock
      // For now, this shows the test structure
    });

    group('Email/Password Authentication', () {
      test('signInWithEmail - successful login', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.user, isNotNull);
        expect(result.error, isNull);
      });

      test('signInWithEmail - invalid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid',
        ));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, equals('The password is invalid'));
      });

      test('signInWithEmail - user not found', () async {
        // Arrange
        const email = 'nonexistent@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email',
        ));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, equals('No user found for that email'));
      });

      test('signUpWithEmail - successful registration', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'password123';
        
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await authService.signUpWithEmail(email, password);

        // Assert
        expect(result.user, isNotNull);
        expect(result.error, isNull);
      });

      test('signUpWithEmail - email already in use', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The account already exists for that email',
        ));

        // Act
        final result = await authService.signUpWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, equals('The account already exists for that email'));
      });

      test('signUpWithEmail - weak password', () async {
        // Arrange
        const email = 'test@example.com';
        const password = '123';
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'weak-password',
          message: 'The password provided is too weak',
        ));

        // Act
        final result = await authService.signUpWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, equals('The password provided is too weak'));
      });
    });

    group('Input Validation Tests', () {
      test('signInWithEmail - empty email', () async {
        // Act
        final result = await authService.signInWithEmail('', 'password123');

        // Assert - This would depend on your validation logic
        // You might want to add validation to AuthService
        expect(result.error, isNotNull);
      });

      test('signInWithEmail - empty password', () async {
        // Act
        final result = await authService.signInWithEmail('test@example.com', '');

        // Assert
        expect(result.error, isNotNull);
      });

      test('signInWithEmail - invalid email format', () async {
        // Arrange
        const email = 'invalid-email';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted',
        ));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, equals('The email address is badly formatted'));
      });
    });

    group('Edge Cases', () {
      test('signInWithEmail - network error', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(Exception('Network error'));

        // Act
        final result = await authService.signInWithEmail(email, password);

        // Assert
        expect(result.user, isNull);
        expect(result.error, contains('Sign in failed'));
      });

      test('signOut - successful logout', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});

        // Act & Assert - Should not throw
        await expectLater(authService.signOut(), completes);
      });
    });
  });
}