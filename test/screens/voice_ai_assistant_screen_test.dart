import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/screens/voice_ai_assistant_screen.dart';

void main() {
  group('VoiceAIAssistantScreen Tests', () {
    testWidgets('should render voice AI assistant screen', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Verify the screen renders
      expect(find.text('🤖 Voice AI Nutrition Assistant'), findsOneWidget);
      expect(find.byType(VoiceAIAssistantScreen), findsOneWidget);
    });

    testWidgets('should show help dialog when info button is pressed', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Find and tap the info button
      final infoButton = find.byIcon(Icons.info_outline);
      expect(infoButton, findsOneWidget);
      
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      // Verify help dialog appears
      expect(find.text('🤖 How to Use Voice AI Assistant'), findsOneWidget);
      expect(find.text('**Voice Commands:**'), findsOneWidget);
    });

    testWidgets('should show status indicator', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Wait for initialization
      await tester.pump();

      // Verify status indicator is present
      expect(find.text('Initializing...'), findsOneWidget);
    });

    testWidgets('should have voice input button', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Verify voice input button is present
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('should have text input field', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Verify text input field is present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type in Hindi/English... (e.g., "Maine dal chawal khaya")'), findsOneWidget);
    });

    testWidgets('should have send button', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const VoiceAIAssistantScreen(),
          ),
        ),
      );

      // Verify send button is present
      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });
}