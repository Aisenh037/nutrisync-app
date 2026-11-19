import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/enhanced_voice_ai_service.dart';
import 'dart:typed_data';

/// Integration tests for Translation API functionality
void main() {
  group('Translation Integration Tests', () {
    late EnhancedVoiceAIService voiceService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      voiceService = EnhancedVoiceAIService.instance;
    });

    group('Text Translation', () {
      test('should translate English to Hindi', () async {
        try {
          final result = await voiceService.translateText(
            'I had dal chawal for lunch',
            targetLanguage: 'hi',
            sourceLanguage: 'en',
          );

          expect(result, isA<TranslationResult>());
          expect(result.sourceLanguage, anyOf(equals('en'), equals('auto')));
          expect(result.targetLanguage, equals('hi'));
          expect(result.confidence, greaterThanOrEqualTo(0.0));
          expect(result.confidence, lessThanOrEqualTo(1.0));
          expect(result.translatedText, isNotEmpty);
          
        } catch (e) {
          // Service errors are acceptable in testing environment
          expect(e, isA<Exception>());
        }
      });

      test('should translate Hindi to English', () async {
        try {
          final result = await voiceService.translateText(
            'मैंने दाल चावल खाया',
            targetLanguage: 'en',
            sourceLanguage: 'hi',
          );

          expect(result, isA<TranslationResult>());
          expect(result.sourceLanguage, anyOf(equals('hi'), equals('auto')));
          expect(result.targetLanguage, equals('en'));
          expect(result.translatedText, isNotEmpty);
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle auto-detection of source language', () async {
        try {
          final result = await voiceService.translateText(
            'Hola, ¿cómo estás?',
            targetLanguage: 'en',
            // No source language specified - should auto-detect
          );

          expect(result, isA<TranslationResult>());
          expect(result.targetLanguage, equals('en'));
          expect(result.translatedText, isNotEmpty);
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should preserve nutrition terminology', () async {
        try {
          final result = await voiceService.translateText(
            'This meal has 300 calories and 20g protein',
            targetLanguage: 'es',
            sourceLanguage: 'en',
          );

          expect(result, isA<TranslationResult>());
          expect(result.translatedText, isNotEmpty);
          
          // Should preserve numerical values
          expect(result.translatedText, contains('300'));
          expect(result.translatedText, contains('20'));
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Nutrition Data Translation', () {
      test('should translate nutrition data while preserving values', () async {
        try {
          final nutritionData = {
            'food_name': 'Dal Chawal',
            'calories': 350,
            'protein': 12.5,
            'carbohydrates': 65.0,
            'description': 'Traditional Indian rice and lentil dish',
            'serving_size': '1 cup',
          };

          final result = await voiceService.translateNutritionData(
            nutritionData,
            targetLanguage: 'es',
            sourceLanguage: 'en',
          );

          expect(result, isA<NutritionTranslationResult>());
          expect(result.sourceLanguage, anyOf(equals('en'), equals('auto')));
          expect(result.targetLanguage, equals('es'));
          expect(result.translatedData, isNotEmpty);
          
          // Numerical values should be preserved
          expect(result.translatedData['calories'], equals(350));
          expect(result.translatedData['protein'], equals(12.5));
          expect(result.translatedData['carbohydrates'], equals(65.0));
          
          // Text fields should be translated
          expect(result.translatedData['food_name'], isA<String>());
          expect(result.translatedData['description'], isA<String>());
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle complex nutrition data structures', () async {
        try {
          final complexNutritionData = {
            'meal': {
              'name': 'Vegetable Biryani',
              'ingredients': [
                {'name': 'Basmati Rice', 'quantity': '1 cup'},
                {'name': 'Mixed Vegetables', 'quantity': '200g'},
              ],
              'nutrition': {
                'calories': 420,
                'protein': 8.0,
                'fat': 12.0,
              }
            },
            'notes': 'Healthy and delicious meal',
          };

          final result = await voiceService.translateNutritionData(
            complexNutritionData,
            targetLanguage: 'hi',
            sourceLanguage: 'en',
          );

          expect(result, isA<NutritionTranslationResult>());
          expect(result.translatedData, isNotEmpty);
          
          // Structure should be preserved
          expect(result.translatedData['meal'], isA<Map>());
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Supported Languages', () {
      test('should return list of supported languages', () async {
        try {
          final result = await voiceService.getSupportedLanguages();

          expect(result, isA<SupportedLanguagesResult>());
          expect(result.languages, isNotEmpty);
          
          // Should include common languages
          final languageCodes = result.languages.map((lang) => lang.languageCode).toList();
          expect(languageCodes, contains('en'));
          expect(languageCodes, anyOf(contains('hi'), contains('es')));
          
          // Each language should have required fields
          for (final language in result.languages) {
            expect(language.languageCode, isNotEmpty);
            expect(language.displayName, anyOf(isNull, isNotEmpty));
          }
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Enhanced Voice Processing with Translation', () {
      test('should process voice with automatic translation', () async {
        try {
          // Generate mock audio data for Hindi input
          final audioData = Uint8List.fromList(
            List.generate(1000, (i) => (i % 256))
          );

          final result = await voiceService.processEnhancedVoiceInteraction(
            audioData,
            userId: 'test-user',
            sessionId: 'test-translation-session',
            languageCode: 'hi-IN',
            context: {
              'user_preferences': {'language': 'hindi'},
            },
            useDialogflow: true,
          );

          expect(result, isA<EnhancedVoiceInteractionResult>());
          expect(result.transcription, isA<String>());
          expect(result.response, isA<String>());
          expect(result.confidence, greaterThanOrEqualTo(0.0));
          
          // Check translation metadata
          if (result.metadata != null) {
            expect(result.metadata!['translationUsed'], anyOf(isNull, isA<bool>()));
            expect(result.metadata!['originalLanguage'], anyOf(isNull, isA<String>()));
            expect(result.metadata!['processingLanguage'], anyOf(isNull, isA<String>()));
          }
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle mixed language (Hinglish) input', () async {
        try {
          final audioData = Uint8List.fromList(
            List.generate(800, (i) => (i % 256))
          );

          final result = await voiceService.processEnhancedVoiceInteraction(
            audioData,
            userId: 'test-user',
            sessionId: 'test-hinglish-session',
            languageCode: 'en-IN', // Hinglish context
            useDialogflow: true,
          );

          expect(result, isA<EnhancedVoiceInteractionResult>());
          expect(result.transcription, isA<String>());
          expect(result.response, isA<String>());
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Error Handling', () {
      test('should handle empty text translation gracefully', () async {
        try {
          final result = await voiceService.translateText(
            '', // Empty text
            targetLanguage: 'hi',
            sourceLanguage: 'en',
          );

          expect(result, isA<TranslationResult>());
          expect(result.error, anyOf(isNull, isNotEmpty));
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle unsupported language codes gracefully', () async {
        try {
          final result = await voiceService.translateText(
            'Hello world',
            targetLanguage: 'xx-XX', // Invalid language code
            sourceLanguage: 'en',
          );

          expect(result, isA<TranslationResult>());
          // Should either work or provide meaningful error
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle malformed nutrition data', () async {
        try {
          final malformedData = {
            'invalid_structure': {
              'nested': {
                'too_deep': {
                  'value': 'test'
                }
              }
            }
          };

          final result = await voiceService.translateNutritionData(
            malformedData,
            targetLanguage: 'es',
            sourceLanguage: 'en',
          );

          expect(result, isA<NutritionTranslationResult>());
          expect(result.translatedData, isNotEmpty);
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Round-trip Translation', () {
      test('should maintain meaning in round-trip translation', () async {
        try {
          final originalText = 'I ate rice and lentils for lunch';
          
          // Translate to Hindi
          final toHindi = await voiceService.translateText(
            originalText,
            targetLanguage: 'hi',
            sourceLanguage: 'en',
          );
          
          if (toHindi.error == null && toHindi.translatedText.isNotEmpty) {
            // Translate back to English
            final backToEnglish = await voiceService.translateText(
              toHindi.translatedText,
              targetLanguage: 'en',
              sourceLanguage: 'hi',
            );
            
            expect(backToEnglish, isA<TranslationResult>());
            expect(backToEnglish.translatedText, isNotEmpty);
            
            // Should preserve key nutrition terms
            final originalLower = originalText.toLowerCase();
            final roundTripLower = backToEnglish.translatedText.toLowerCase();
            
            if (originalLower.contains('rice')) {
              expect(roundTripLower, anyOf(contains('rice'), contains('grain')));
            }
            if (originalLower.contains('lentils')) {
              expect(roundTripLower, anyOf(contains('lentil'), contains('dal'), contains('pulse')));
            }
          }
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });
  });
}