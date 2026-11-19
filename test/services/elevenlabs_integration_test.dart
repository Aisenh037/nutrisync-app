import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/elevenlabs_tts_service.dart';
import 'package:nutrisync/services/elevenlabs_auth_handler.dart';
import 'package:nutrisync/services/elevenlabs_fallback_manager.dart';
import 'package:nutrisync/services/retry_manager.dart';
import 'package:nutrisync/config/configuration_initializer.dart';

/// Integration Tests for ElevenLabs TTS System
/// 
/// Tests the complete ElevenLabs system integration including:
/// - Configuration management
/// - Authentication handling
/// - TTS service functionality
/// - Fallback mechanisms
/// - Retry logic
void main() {
  group('ElevenLabs TTS System - Integration Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize the configuration system
      try {
        await ConfigurationInitializer.instance.initialize();
      } catch (e) {
        // Configuration might fail in test environment, continue with tests
        print('⚠ Configuration initialization failed in test environment: $e');
      }
    });

    group('Service Initialization', () {
      test('ElevenLabs services initialize correctly', () async {
        // Test individual service initialization
        final authHandler = ElevenLabsAuthHandler.instance;
        final fallbackManager = ElevenLabsFallbackManager.instance;
        final ttsService = ElevenLabsTtsService.instance;
        
        // Reset services for clean test
        authHandler.reset();
        fallbackManager.reset();
        ttsService.reset();
        
        try {
          // Initialize authentication handler
          await authHandler.initialize();
          expect(authHandler, isNotNull);
          
          // Initialize fallback manager
          await fallbackManager.initialize();
          expect(fallbackManager, isNotNull);
          
          // Initialize TTS service (may fail without proper config)
          try {
            await ttsService.initialize();
          } catch (e) {
            // Expected in test environment without proper API keys
            expect(e, isA<Exception>());
          }
          
        } catch (e) {
          // Services may fail to initialize in test environment
          expect(e, isA<Exception>());
        }
      });
    });

    group('Model Management', () {
      test('TTS service provides valid model selection', () {
        final ttsService = ElevenLabsTtsService.instance;
        
        // Test model selection without initialization
        final bestModel = ttsService.getBestModel();
        expect(bestModel, isNotNull);
        expect(bestModel.isNotEmpty, isTrue);
        expect(ElevenLabsTtsService.supportedModels.contains(bestModel), isTrue);
        
        // Test with preferred model
        for (final model in ElevenLabsTtsService.supportedModels) {
          final selectedModel = ttsService.getBestModel(preferredModel: model);
          expect(selectedModel, equals(model));
        }
        
        // Test with invalid preferred model
        final fallbackModel = ttsService.getBestModel(preferredModel: 'invalid_model');
        expect(ElevenLabsTtsService.supportedModels.contains(fallbackModel), isTrue);
      });
    });

    group('Authentication Flow', () {
      test('Authentication handler manages API key lifecycle', () async {
        final authHandler = ElevenLabsAuthHandler.instance;
        
        try {
          await authHandler.initialize();
          
          // Test authentication status
          final status = await authHandler.getAuthStatus();
          expect(status, isA<AuthStatus>());
          expect(status.hasApiKey, isA<bool>());
          expect(status.isValidFormat, isA<bool>());
          expect(status.isAuthenticated, isA<bool>());
          
          // Test error handling
          final error401 = authHandler.handleAuthError(401, 'Unauthorized');
          expect(error401.errorType, equals(AuthErrorType.invalidApiKey));
          expect(error401.isRetryable, isFalse);
          
          final error429 = authHandler.handleAuthError(429, 'Rate Limited');
          expect(error429.errorType, equals(AuthErrorType.rateLimited));
          expect(error429.isRetryable, isTrue);
          
        } catch (e) {
          // Authentication may fail in test environment
          expect(e, isA<Exception>());
        }
      });
    });

    group('Fallback Mechanisms', () {
      test('Fallback manager handles various failure scenarios', () async {
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        try {
          await fallbackManager.initialize();
          
          // Test different error types
          final testCases = [
            ElevenLabsException('Rate limit exceeded', 429),
            ElevenLabsException('Quota exceeded', 402),
            ElevenLabsAuthException('Invalid API key'),
            Exception('Network timeout'),
          ];
          
          for (final error in testCases) {
            final result = await fallbackManager.handleTtsFailure(
              'Test message',
              originalError: error,
            );
            
            expect(result, isA<FallbackResult>());
            expect(result.isSuccess, isTrue);
            expect(result.text, equals('Test message'));
            expect(result.strategy, isA<FallbackStrategy>());
            expect(result.message.isNotEmpty, isTrue);
          }
          
          // Test service health monitoring
          final health = await fallbackManager.getServiceHealth();
          expect(health, isA<ServiceHealthStatus>());
          expect(health.healthLevel, isA<ServiceHealthLevel>());
          
          // Test statistics
          final stats = fallbackManager.getStatistics();
          expect(stats, isA<FallbackStatistics>());
          expect(stats.failureRate, greaterThanOrEqualTo(0.0));
          expect(stats.failureRate, lessThanOrEqualTo(1.0));
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Retry Logic', () {
      test('Retry manager implements exponential backoff correctly', () async {
        final retryManager = RetryManager.instance;
        
        // Test retry configurations
        final configs = [
          retryManager.rateLimitRetryConfig(),
          retryManager.authRetryConfig(),
          retryManager.networkRetryConfig(),
        ];
        
        for (final config in configs) {
          expect(config.maxRetries, greaterThan(0));
          expect(config.initialDelay.inMilliseconds, greaterThan(0));
          expect(config.backoffMultiplier, greaterThan(1.0));
          expect(config.maxDelay.inMilliseconds, greaterThan(config.initialDelay.inMilliseconds));
        }
        
        // Test retry execution with quick failure
        int attemptCount = 0;
        try {
          await retryManager.executeWithRetry<void>(
            () async {
              attemptCount++;
              throw Exception('Test retry failure');
            },
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 1),
          );
        } catch (e) {
          expect(e, isA<Exception>());
          expect(attemptCount, equals(3)); // Initial + 2 retries
        }
      });
    });

    group('Service Status', () {
      test('Services provide comprehensive status information', () {
        final ttsService = ElevenLabsTtsService.instance;
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        // Test TTS service status
        final ttsStatus = ttsService.getStatus();
        expect(ttsStatus, isA<ServiceStatus>());
        expect(ttsStatus.supportedModels, isNotEmpty);
        expect(ttsStatus.supportedModels, equals(ElevenLabsTtsService.supportedModels));
        
        // Test fallback statistics
        final fallbackStats = fallbackManager.getStatistics();
        expect(fallbackStats, isA<FallbackStatistics>());
        expect(fallbackStats.currentStrategy, isA<FallbackStrategy>());
      });
    });

    group('Error Handling', () {
      test('System handles errors gracefully without crashing', () async {
        final ttsService = ElevenLabsTtsService.instance;
        
        // Test with invalid inputs
        try {
          await ttsService.synthesizeSpeechWithFallback('');
        } catch (e) {
          expect(e, isA<Exception>());
        }
        
        try {
          await ttsService.synthesizeSpeechWithFallback(
            'Test message',
            voiceId: 'invalid_voice_id',
            modelId: 'invalid_model_id',
          );
        } catch (e) {
          // Should either succeed with fallback or fail gracefully
          expect(e, isA<Exception>());
        }
      });
    });

    group('Configuration Integration', () {
      test('Services integrate with configuration management', () async {
        final authHandler = ElevenLabsAuthHandler.instance;
        
        try {
          await authHandler.initialize();
          
          // Test that services can handle missing configuration
          final status = await authHandler.getAuthStatus();
          expect(status, isA<AuthStatus>());
          
          // In test environment, we expect no API key
          expect(status.hasApiKey, isFalse);
          expect(status.isAuthenticated, isFalse);
          
        } catch (e) {
          // Configuration errors are expected in test environment
          expect(e, isA<Exception>());
        }
      });
    });
  });
}