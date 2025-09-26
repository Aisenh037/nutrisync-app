// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:nutrisync/main.dart';
import 'package:nutrisync/providers/providers.dart';
// Ensure that MyApp is defined in main.dart and is being exported.
// If MyApp is not defined, add the following to main.dart:

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text('NutriSync')),
//         body: Center(child: Text('0')),
//         floatingActionButton: FloatingActionButton(
//           onPressed: () {},
//           child: Icon(Icons.add),
//         ),
//       ),
//     );
//   }
// }

void main() {
  group('NutriSync Main Screens', () {
    testWidgets('Login screen loads by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          ],
          child: const NutriSyncApp(),
        ),
      );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  debugPrint('Widget tree: ${tester.element(find.byType(MaterialApp)).toStringDeep()}');
  // Check for login screen widgets
  expect(find.text('Welcome to NutriSync'), findsOneWidget);
  expect(find.text('Email'), findsOneWidget);
  expect(find.text('Password'), findsOneWidget);
  expect(find.byType(TextField), findsNWidgets(2));
  expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, 'Sign Up'), findsOneWidget);
    });
  });
}
