import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nutrisync/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Integration Tests', () {
    testWidgets('complete login flow with valid credentials', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Find the email and password fields
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final loginButton = find.byKey(const Key('login_button'));

      // Enter valid test credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'testpassword123');
      
      // Tap login button
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify successful login (adjust based on your app's behavior)
      // This might navigate to home screen or show success message
      expect(find.text('Login successful!'), findsOneWidget);
    });

    testWidgets('login flow with invalid credentials shows error', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Find the email and password fields
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final loginButton = find.byKey(const Key('login_button'));

      // Enter invalid credentials
      await tester.enterText(emailField, 'invalid@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      
      // Tap login button
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.textContaining('failed'), findsOneWidget);
    });

    testWidgets('signup flow creates new account', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to signup screen
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Fill out signup form
      final nameField = find.byKey(const Key('name_field'));
      final emailField = find.byKey(const Key('signup_email_field'));
      final passwordField = find.byKey(const Key('signup_password_field'));
      final createAccountButton = find.text('Create Account');

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'newuser@example.com');
      await tester.enterText(passwordField, 'newpassword123');

      // Tap create account button
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      // Verify account creation success
      expect(find.text('Account created successfully!'), findsOneWidget);
    });

    testWidgets('form validation prevents empty submissions', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Try to login with empty fields
      final loginButton = find.byKey(const Key('login_button'));
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Email and password are required.'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Find password field and visibility toggle
      final passwordField = find.byKey(const Key('password_field'));
      final visibilityToggle = find.byIcon(Icons.visibility_off);

      // Enter password
      await tester.enterText(passwordField, 'testpassword');
      
      // Verify password is initially obscured
      TextField textField = tester.widget(passwordField);
      expect(textField.obscureText, isTrue);

      // Tap visibility toggle
      await tester.tap(visibilityToggle);
      await tester.pump();

      // Verify password is now visible
      textField = tester.widget(passwordField);
      expect(textField.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('logout functionality works', (WidgetTester tester) async {
      // Launch the app and login first
      app.main();
      await tester.pumpAndSettle();

      // Login with valid credentials
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final loginButton = find.byKey(const Key('login_button'));

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'testpassword123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Find and tap logout button (adjust based on your UI)
      final logoutButton = find.byKey(const Key('logout_button'));
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Verify user is logged out (back to login screen)
      expect(find.text('NutriSync'), findsOneWidget);
      expect(find.text('Eat smart. Live better.'), findsOneWidget);
    });
  });
}