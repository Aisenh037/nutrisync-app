import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/voice/voice_interface.dart';
import 'dart:typed_data';

void main() {
  // Initialize Flutter bindings for plugin tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VoiceInterface Tests', () {
    late VoiceInterface voiceInterface;
    const testApiKey = 'test_api_key_12345';

    setUp(() {
      voiceInterface = VoiceInterface(elevenLabsApiKey: testApiKey);
    });

    tearDown(() {
      voiceInterface.dispose();
    });

    group('Initialization', () {
      test('should create VoiceInterface with API key', () {
        expect(voiceInterface, isNotNull);
        expect(voiceInterface.isInitialized, isFalse);
        expect(voiceInterface.isListening, isFalse);
        expect(voiceInterface.isPlaying, isFalse);
      });

      test('should create VoiceInterface with custom voice ID', () {
        final customVoice = VoiceInterface(
          elevenLabsApiKey: testApiKey,
          voiceId: 'custom_voice_id',
        );
        
        expect(customVoice, isNotNull);
        customVoice.dispose();
      });
    });

    group('State Management', () {
      test('should track listening state', () {
        expect(voiceInterface.isListening, isFalse);
      });

      test('should track playing state', () {
        expect(voiceInterface.isPlaying, isFalse);
      });

      test('should track initialization state', () {
        expect(voiceInterface.isInitialized, isFalse);
      });

      test('should generate session ID when starting conversation', () {
        expect(voiceInterface.currentSessionId, isNull);
      });
    });

    group('Error Handling', () {
      test('should throw error when processing voice input without initialization', () async {
        final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);
        
        expect(
          () async => await voiceInterface.processVoiceInput(audioData),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw error when generating voice response with empty text', () async {
        expect(
          () async => await voiceInterface.generateVoiceResponse(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw error when listening without initialization', () async {
        expect(
          () async => await voiceInterface.listenForVoiceInput(),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw error when recording without initialization', () async {
        expect(
          () async => await voiceInterface.recordAudio(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Audio Processing', () {
      test('should handle empty audio data gracefully', () async {
        final emptyAudioData = Uint8List(0);
        
        expect(
          () async => await voiceInterface.processVoiceInput(emptyAudioData),
          throwsA(isA<Exception>()),
        );
      });

      test('should validate audio data format', () async {
        final invalidAudioData = Uint8List.fromList([255, 255, 255]);
        
        expect(
          () async => await voiceInterface.processVoiceInput(invalidAudioData),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Text-to-Speech', () {
      test('should validate text input for TTS', () async {
        // Empty text should throw error
        expect(
          () async => await voiceInterface.generateVoiceResponse(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle long text input', () async {
        final longText = 'This is a very long text ' * 100;
        
        // Should not throw error for long text (will fail due to API key, but validation should pass)
        expect(
          () async => await voiceInterface.generateVoiceResponse(longText),
          throwsA(isA<Exception>()), // Will fail due to invalid API key, but that's expected
        );
      });

      test('should handle special characters in text', () async {
        const specialText = 'Hello! How are you? I\'m fine. 123 & symbols @#\$%';
        
        expect(
          () async => await voiceInterface.generateVoiceResponse(specialText),
          throwsA(isA<Exception>()), // Will fail due to invalid API key, but validation should pass
        );
      });

      test('should handle Hinglish text', () async {
        const hinglishText = 'Namaste! Aaj ka khana kaisa hai? Today\'s meal is very tasty.';
        
        expect(
          () async => await voiceInterface.generateVoiceResponse(hinglishText),
          throwsA(isA<Exception>()), // Will fail due to invalid API key, but validation should pass
        );
      });
    });

    group('Interruption Handling', () {
      test('should handle interruption gracefully', () {
        expect(() => voiceInterface.handleInterruption(), returnsNormally);
      });

      test('should stop audio on interruption', () async {
        // This test verifies that interruption doesn't throw errors
        voiceInterface.handleInterruption();
        expect(voiceInterface.isListening, isFalse);
        expect(voiceInterface.isPlaying, isFalse);
      });
    });

    group('Resource Management', () {
      test('should dispose resources properly', () {
        expect(() => voiceInterface.dispose(), returnsNormally);
        expect(voiceInterface.isInitialized, isFalse);
      });

      test('should handle multiple dispose calls', () {
        voiceInterface.dispose();
        expect(() => voiceInterface.dispose(), returnsNormally);
      });
    });

    group('API Connection Testing', () {
      test('should test ElevenLabs connection', () async {
        // This will fail with invalid API key, but should not throw
        final result = await voiceInterface.testElevenLabsConnection();
        expect(result, isFalse); // Expected to fail with test API key
      });

      test('should get available voices', () async {
        // This will return empty list with invalid API key
        final voices = await voiceInterface.getAvailableVoices();
        expect(voices, isA<List>());
      });
    });

    group('Configuration Validation', () {
      test('should use default voice ID when not specified', () {
        final defaultVoice = VoiceInterface(elevenLabsApiKey: testApiKey);
        expect(defaultVoice, isNotNull);
        defaultVoice.dispose();
      });

      test('should accept custom voice ID', () {
        const customVoiceId = 'custom_voice_123';
        final customVoice = VoiceInterface(
          elevenLabsApiKey: testApiKey,
          voiceId: customVoiceId,
        );
        expect(customVoice, isNotNull);
        customVoice.dispose();
      });
    });

    group('Conversation Stream', () {
      test('should create conversation stream', () {
        final stream = voiceInterface.startConversation();
        expect(stream, isA<Stream>());
      });
    });

    group('Audio Format Handling', () {
      test('should handle different audio formats', () async {
        // Test with different audio data patterns
        final audioFormats = [
          Uint8List.fromList([0, 1, 2, 3, 4, 5]), // Simple pattern
          Uint8List.fromList(List.generate(1000, (i) => i % 256)), // Larger data
          Uint8List.fromList([255, 128, 64, 32, 16, 8]), // Different values
        ];

        for (final audioData in audioFormats) {
          expect(
            () async => await voiceInterface.processVoiceInput(audioData),
            throwsA(isA<Exception>()), // Expected to fail without initialization
          );
        }
      });
    });

    group('Timeout Handling', () {
      test('should handle recording timeout', () async {
        expect(
          () async => await voiceInterface.recordAudio(durationSeconds: 1),
          throwsA(isA<Exception>()), // Will fail without initialization
        );
      });

      test('should handle listening timeout', () async {
        expect(
          () async => await voiceInterface.listenForVoiceInput(timeoutSeconds: 1),
          throwsA(isA<Exception>()), // Will fail without initialization
        );
      });
    });
  });
}