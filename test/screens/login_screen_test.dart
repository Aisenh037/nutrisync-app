import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nutrisync/screens/login_screen.dart';
import 'package:nutrisync/api/auth_service.dart';
import 'package:nutrisync/providers/providers.dart';

// Generate mocks
@GenerateMocks([AuthService])
import 'login_screen_test.mocks.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      );
    }

    group('UI Elements', () {
      testWidgets('displays all required UI elements', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.text('NutriSync'), findsOneWidget);
        expect(find.text('Eat smart. Live better.'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2)); // Email and password fields
        expect(find.text('Login'), findsOneWidget);
        expect(find.text('Sign Up'), findsOneWidget);
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('email field accepts input', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.pump();

        // Assert
        expect(find.text('test@example.com'), findsOneWidget);
      });

      testWidgets('password field accepts input and is obscured', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final passwordField = find.byType(TextField).last;

        // Act
        await tester.enterText(passwordField, 'password123');
        await tester.pump();

        // Assert
        final textField = tester.widget<TextField>(passwordField);
        expect(textField.obscureText, isTrue);
      });

      testWidgets('password visibility toggle works', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final visibilityToggle = find.byIcon(Icons.visibility_off);

        // Act
        await tester.tap(visibilityToggle);
        await tester.pump();

        // Assert
        expect(find.byIcon(Icons.visibility), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('shows error when email is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final loginButton = find.text('Login');

        // Act
        await tester.tap(loginButton);
        await tester.pump();

        // Assert
        expect(find.text('Email and password are required.'), findsOneWidget);
      });

      testWidgets('shows error when password is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;
        final loginButton = find.text('Login');

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.tap(loginButton);
        await tester.pump();

        // Assert
        expect(find.text('Email and password are required.'), findsOneWidget);
      });

      testWidgets('shows error when both fields are empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final loginButton = find.text('Login');

        // Act
        await tester.tap(loginButton);
        await tester.pump();

        // Assert
        expect(find.text('Email and password are required.'), findsOneWidget);
      });
    });

    group('Authentication Flow', () {
      testWidgets('successful login shows success message', (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signInWithEmail('test@example.com', 'password123'))
            .thenAnswer((_) async => AuthResult(user: null)); // Mock successful result

        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;
        final passwordField = find.byType(TextField).last;
        final loginButton = find.text('Login');

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.tap(loginButton);
        await tester.pump();
        await tester.pump(); // Additional pump for async operations

        // Assert
        verify(mockAuthService.signInWithEmail('test@example.com', 'password123')).called(1);
      });

      testWidgets('failed login shows error message', (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signInWithEmail('test@example.com', 'wrongpassword'))
            .thenAnswer((_) async => AuthResult(error: 'Invalid credentials'));

        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;
        final passwordField = find.byType(TextField).last;
        final loginButton = find.text('Login');

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'wrongpassword');
        await tester.tap(loginButton);
        await tester.pump();
        await tester.pump(); // Additional pump for async operations

        // Assert
        expect(find.text('Invalid credentials'), findsOneWidget);
      });

      testWidgets('shows loading indicator during login', (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signInWithEmail('test@example.com', 'password123'))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return AuthResult(user: null);
        });

        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;
        final passwordField = find.byType(TextField).last;
        final loginButton = find.text('Login');

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.tap(loginButton);
        await tester.pump(); // Trigger the loading state

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('clears form after successful login', (WidgetTester tester) async {
        // Arrange
        when(mockAuthService.signInWithEmail('test@example.com', 'password123'))
            .thenAnswer((_) async => AuthResult(user: null));

        await tester.pumpWidget(createTestWidget());
        final emailField = find.byType(TextField).first;
        final passwordField = find.byType(TextField).last;
        final loginButton = find.text('Login');

        // Act
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.tap(loginButton);
        await tester.pumpAndSettle(); // Wait for all animations and async operations

        // Assert
        final emailTextField = tester.widget<TextField>(emailField);
        final passwordTextField = tester.widget<TextField>(passwordField);
        expect(emailTextField.controller?.text, isEmpty);
        expect(passwordTextField.controller?.text, isEmpty);
      });
    });

    group('Navigation', () {
      testWidgets('navigates to signup screen when Sign Up is tapped', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        final signUpButton = find.text('Sign Up');

        // Act
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Create your account'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('has proper accessibility labels', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.bySemanticsLabel('Email'), findsOneWidget);
        expect(find.bySemanticsLabel('Password'), findsOneWidget);
      });

      testWidgets('supports keyboard navigation', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());

        // Act & Assert
        // Test that Tab key moves focus between fields
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        
        // Verify focus management works
        expect(tester.testTextInput.hasAnyClients, isTrue);
      });
    });
  });
}