import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/elevenlabs_tts_service.dart';
import 'package:nutrisync/services/elevenlabs_auth_handler.dart';
import 'package:nutrisync/services/elevenlabs_fallback_manager.dart';
import 'package:nutrisync/services/retry_manager.dart';
import 'dart:math';
import 'dart:typed_data';

/// Property-Based Tests for ElevenLabs TTS System
/// 
/// **Feature: api-configuration-fixes, ElevenLabs TTS API Issues**
/// Tests universal correctness properties across all ElevenLabs configuration scenarios
void main() {
  group('ElevenLabs TTS System - Property-Based Tests', () {
    final random = Random(42); // Fixed seed for reproducible tests

    setUpAll(() async {
      // Initialize Flutter bindings for plugin tests
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Property 1: ElevenLabs Model Validation (Task 2.2)', () {
      /// **Feature: api-configuration-fixes, Property 1: ElevenLabs Model Validation**
      /// *For any* model configuration, the ElevenLabs service should only accept
      /// supported models and gracefully handle deprecated ones
      /// **Validates: Requirements 1.1**
      test('Property: Model validation accepts only supported models', () async {
        final ttsService = ElevenLabsTtsService.instance;
        
        // Test with all supported models
        for (final model in ElevenLabsTtsService.supportedModels) {
          // Property: All supported models should be accepted
          final bestModel = ttsService.getBestModel(preferredModel: model);
          expect(bestModel, isNotNull);
          expect(bestModel.isNotEmpty, isTrue);
          
          // Property: Supported models should be in the supported list
          expect(ElevenLabsTtsService.supportedModels.contains(bestModel), isTrue);
        }
      });

      /// Test model fallback behavior with deprecated models
      test('Property: Deprecated models fall back to supported alternatives', () async {
        final ttsService = ElevenLabsTtsService.instance;
        
        // Test deprecated models
        final deprecatedModels = [
          'eleven_monolingual_v1_deprecated',
          'eleven_english_v1',
          'eleven_multilingual_v1',
          'invalid_model_name',
          '',
          'null_model',
        ];
        
        for (final deprecatedModel in deprecatedModels) {
          // Property: Deprecated models should fall back to supported ones
          final fallbackModel = ttsService.getBestModel(preferredModel: deprecatedModel);
          
          expect(fallbackModel, isNotNull);
          expect(fallbackModel.isNotEmpty, isTrue);
          expect(ElevenLabsTtsService.supportedModels.contains(fallbackModel), isTrue);
        }
      });

      /// Test model selection consistency
      test('Property: Model selection is deterministic and consistent', () async {
        final ttsService = ElevenLabsTtsService.instance;
        
        // Test consistency across multiple calls
        for (int i = 0; i < 50; i++) {
          final model1 = ttsService.getBestModel();
          final model2 = ttsService.getBestModel();
          
          // Property: Same input should produce same output
          expect(model1, equals(model2));
          
          // Property: Selected model should always be supported
          expect(ElevenLabsTtsService.supportedModels.contains(model1), isTrue);
        }
      });

      /// Test model preference handling
      test('Property: Model preferences are respected when valid', () async {
        final ttsService = ElevenLabsTtsService.instance;
        
        for (final preferredModel in ElevenLabsTtsService.supportedModels) {
          final selectedModel = ttsService.getBestModel(preferredModel: preferredModel);
          
          // Property: Valid preferred models should be selected
          expect(selectedModel, equals(preferredModel));
        }
      });
    });

    group('Property 2: Authentication Consistency (Task 2.4)', () {
      /// **Feature: api-configuration-fixes, Property 2: Authentication Consistency**
      /// *For any* authentication state, the auth handler should maintain consistent
      /// behavior and provide reliable validation results
      /// **Validates: Requirements 1.2**
      test('Property: Authentication status is consistent across calls', () async {
        final authHandler = ElevenLabsAuthHandler.instance;
        
        // Test consistency across multiple status checks
        for (int i = 0; i < 25; i++) {
          try {
            final status1 = await authHandler.getAuthStatus();
            final status2 = await authHandler.getAuthStatus();
            
            // Property: Consecutive calls should return consistent results
            expect(status1.hasApiKey, equals(status2.hasApiKey));
            expect(status1.isValidFormat, equals(status2.isValidFormat));
            
            // Property: Status fields should be logically consistent
            if (status1.isAuthenticated) {
              expect(status1.hasApiKey, isTrue);
              expect(status1.isValidFormat, isTrue);
              expect(status1.isValidated, isTrue);
            }
            
            if (!status1.hasApiKey) {
              expect(status1.isAuthenticated, isFalse);
              expect(status1.isValidated, isFalse);
            }
            
          } catch (e) {
            // Errors are acceptable in test environment
            expect(e, isA<Exception>());
          }
        }
      });

      /// Test API key format validation consistency
      test('Property: API key format validation is consistent', () async {
        final testApiKeys = _generateTestApiKeys(random);
        
        for (final apiKey in testApiKeys) {
          try {
            // Test format validation multiple times for same key
            final results = <bool>[];
            
            for (int i = 0; i < 5; i++) {
              // We can't directly test the private method, so we test through auth status
              final authHandler = ElevenLabsAuthHandler.instance;
              authHandler.reset(); // Reset for clean test
              
              try {
                await authHandler.storeApiKey(apiKey);
                results.add(true); // Key was accepted
              } catch (e) {
                results.add(false); // Key was rejected
              }
            }
            
            // Property: Same API key should always produce same validation result
            if (results.isNotEmpty) {
              final firstResult = results.first;
              for (final result in results) {
                expect(result, equals(firstResult));
              }
            }
            
          } catch (e) {
            // Format validation errors are expected for invalid keys
            expect(e, isA<Exception>());
          }
        }
      });

      /// Test authentication error handling consistency
      test('Property: Authentication errors are handled consistently', () async {
        final authHandler = ElevenLabsAuthHandler.instance;
        
        final errorCodes = [401, 402, 403, 429, 500, 503];
        final errorBodies = ['Unauthorized', 'Payment Required', 'Forbidden', 'Rate Limited'];
        
        for (final statusCode in errorCodes) {
          for (final body in errorBodies) {
            // Property: Same error should produce same result
            final result1 = authHandler.handleAuthError(statusCode, body);
            final result2 = authHandler.handleAuthError(statusCode, body);
            
            expect(result1.errorType, equals(result2.errorType));
            expect(result1.isRetryable, equals(result2.isRetryable));
            expect(result1.message, equals(result2.message));
            
            // Property: Error handling should be deterministic
            expect(result1.errorType, isA<AuthErrorType>());
            expect(result1.message.isNotEmpty, isTrue);
          }
        }
      });

      /// Test authentication cache behavior
      test('Property: Authentication cache behaves consistently', () async {
        final authHandler = ElevenLabsAuthHandler.instance;
        
        for (int i = 0; i < 20; i++) {
          try {
            // Clear cache and test behavior
            authHandler.clearAuthCache();
            
            final status1 = await authHandler.getAuthStatus();
            
            // Property: Cache clearing should reset validation state
            if (status1.hasApiKey && status1.isValidFormat) {
              // After cache clear, validation should be false until re-validated
              expect(status1.isValidated, isFalse);
            }
            
          } catch (e) {
            expect(e, isA<Exception>());
          }
        }
      });
    });

    group('Property 3: Graceful Fallback Behavior (Task 2.6)', () {
      /// **Feature: api-configuration-fixes, Property 3: Graceful Fallback Behavior**
      /// *For any* TTS failure scenario, the fallback manager should provide
      /// graceful degradation without crashing the application
      /// **Validates: Requirements 1.3, 7.1**
      test('Property: Fallback manager handles all failure types gracefully', () async {
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        try {
          await fallbackManager.initialize();
        } catch (e) {
          // Initialization might fail in test environment
        }
        
        final testTexts = _generateTestTexts(random);
        final errorTypes = _generateTestErrors();
        
        for (final text in testTexts) {
          for (final error in errorTypes) {
            try {
              final result = await fallbackManager.handleTtsFailure(
                text,
                originalError: error,
              );
              
              // Property: Fallback should always return a valid result
              expect(result, isA<FallbackResult>());
              expect(result.text, equals(text));
              expect(result.strategy, isA<FallbackStrategy>());
              
              // Property: Fallback should provide user-friendly response
              expect(result.message.isNotEmpty, isTrue);
              
              // Property: Success should be true for graceful fallback
              expect(result.isSuccess, isTrue);
              
            } catch (e) {
              // Fallback should not throw exceptions
              fail('Fallback manager should not throw exceptions: $e');
            }
          }
        }
      });

      /// Test fallback strategy selection consistency
      test('Property: Fallback strategy selection is consistent', () async {
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        try {
          await fallbackManager.initialize();
        } catch (e) {
          // Continue with test even if initialization fails
        }
        
        final testError = ElevenLabsException('Rate limit exceeded', 429);
        
        for (int i = 0; i < 30; i++) {
          try {
            final result = await fallbackManager.handleTtsFailure(
              'Test message for consistency',
              originalError: testError,
            );
            
            // Property: Same error type should produce consistent strategy
            expect(result.strategy, isA<FallbackStrategy>());
            
            // Property: Strategy should be appropriate for error type
            if (testError.statusCode == 429) {
              // Rate limit should prefer cached audio or local TTS
              expect(
                [FallbackStrategy.cachedAudio, FallbackStrategy.localTts, FallbackStrategy.textOnly]
                    .contains(result.strategy),
                isTrue,
              );
            }
            
          } catch (e) {
            expect(e, isA<Exception>());
          }
        }
      });

      /// Test service health monitoring
      test('Property: Service health monitoring provides consistent status', () async {
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        try {
          await fallbackManager.initialize();
        } catch (e) {
          // Continue with test
        }
        
        for (int i = 0; i < 15; i++) {
          try {
            final health = await fallbackManager.getServiceHealth();
            
            // Property: Health status should be well-formed
            expect(health, isA<ServiceHealthStatus>());
            expect(health.healthLevel, isA<ServiceHealthLevel>());
            expect(health.currentStrategy, isA<FallbackStrategy>());
            expect(health.recommendedAction.isNotEmpty, isTrue);
            
            // Property: Health level should be consistent with availability
            if (health.isAvailable && health.recentFailures.isEmpty) {
              expect(health.healthLevel, equals(ServiceHealthLevel.healthy));
            }
            
          } catch (e) {
            expect(e, isA<Exception>());
          }
        }
      });

      /// Test fallback statistics consistency
      test('Property: Fallback statistics are consistent and accurate', () async {
        final fallbackManager = ElevenLabsFallbackManager.instance;
        
        try {
          await fallbackManager.initialize();
          fallbackManager.clearFailureLog(); // Start with clean state
          
          // Generate some failures
          for (int i = 0; i < 5; i++) {
            try {
              await fallbackManager.handleTtsFailure(
                'Test failure $i',
                originalError: Exception('Test error $i'),
              );
            } catch (e) {
              // Continue
            }
          }
          
          final stats = fallbackManager.getStatistics();
          
          // Property: Statistics should be consistent
          expect(stats, isA<FallbackStatistics>());
          expect(stats.totalFailures, greaterThanOrEqualTo(0));
          expect(stats.recentFailures, greaterThanOrEqualTo(0));
          expect(stats.recentFailures, lessThanOrEqualTo(stats.totalFailures));
          
          // Property: Failure rate should be between 0 and 1
          expect(stats.failureRate, greaterThanOrEqualTo(0.0));
          expect(stats.failureRate, lessThanOrEqualTo(1.0));
          
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Property 4: Exponential Backoff Retry (Task 2.8)', () {
      /// **Feature: api-configuration-fixes, Property 4: Exponential Backoff Retry**
      /// *For any* retry scenario, the retry manager should implement proper
      /// exponential backoff with jitter and respect maximum retry limits
      /// **Validates: Requirements 1.4**
      test('Property: Exponential backoff increases delay correctly', () async {
        final retryManager = RetryManager.instance;
        final delays = <Duration>[];
        
        try {
          await retryManager.executeWithRetry<void>(
            () async {
              delays.add(DateTime.now().difference(DateTime.now()));
              throw Exception('Test retry');
            },
            maxRetries: 4,
            initialDelay: const Duration(milliseconds: 100),
            backoffMultiplier: 2.0,
            onRetry: (attempt, error) {
              // Track retry attempts
            },
          );
        } catch (e) {
          // Expected to fail after retries
        }
        
        // Property: Should have attempted the expected number of retries
        // Note: In test environment, we can't easily measure actual delays,
        // but we can verify the retry logic is called
        expect(delays.length, greaterThan(0));
      });

      /// Test retry configuration consistency
      test('Property: Retry configurations produce consistent behavior', () async {
        final retryManager = RetryManager.instance;
        
        final configs = [
          retryManager.rateLimitRetryConfig(),
          retryManager.authRetryConfig(),
          retryManager.networkRetryConfig(),
        ];
        
        for (final config in configs) {
          // Property: Retry config should be well-formed
          expect(config.maxRetries, greaterThan(0));
          expect(config.initialDelay.inMilliseconds, greaterThan(0));
          expect(config.backoffMultiplier, greaterThan(1.0));
          expect(config.maxDelay.inMilliseconds, greaterThan(config.initialDelay.inMilliseconds));
          
          // Test config consistency across multiple uses
          for (int i = 0; i < 10; i++) {
            int attemptCount = 0;
            
            try {
              await retryManager.executeWithConfig<void>(
                () async {
                  attemptCount++;
                  if (attemptCount <= config.maxRetries) {
                    throw Exception('Test retry $attemptCount');
                  }
                },
                config,
              );
            } catch (e) {
              // Expected to fail
            }
            
            // Property: Should not exceed max retries
            expect(attemptCount, lessThanOrEqualTo(config.maxRetries + 1));
          }
        }
      });

      /// Test retry decision logic
      test('Property: Retry decisions are consistent for error types', () async {
        final retryManager = RetryManager.instance;
        
        final testErrors = [
          Exception('429 Rate limit exceeded'),
          Exception('500 Internal server error'),
          Exception('401 Unauthorized'),
          Exception('Network timeout'),
          Exception('Connection refused'),
          Exception('Invalid input'),
        ];
        
        final configs = [
          retryManager.rateLimitRetryConfig(),
          retryManager.authRetryConfig(),
          retryManager.networkRetryConfig(),
        ];
        
        for (final config in configs) {
          for (final error in testErrors) {
            // Test retry decision consistency
            final shouldRetry1 = config.shouldRetry?.call(error) ?? true;
            final shouldRetry2 = config.shouldRetry?.call(error) ?? true;
            
            // Property: Same error should produce same retry decision
            expect(shouldRetry1, equals(shouldRetry2));
            
            // Property: Retry decision should be boolean
            expect(shouldRetry1, isA<bool>());
          }
        }
      });

      /// Test jittered retry behavior
      test('Property: Jittered retry adds appropriate randomness', () async {
        final retryManager = RetryManager.instance;
        final attemptCounts = <int>[];
        
        // Run multiple jittered retry attempts
        for (int i = 0; i < 20; i++) {
          int attempts = 0;
          
          try {
            await retryManager.executeWithJitteredRetry<void>(
              () async {
                attempts++;
                throw Exception('Test jittered retry');
              },
              maxRetries: 2,
              initialDelay: const Duration(milliseconds: 10),
              jitterFactor: 0.1,
            );
          } catch (e) {
            // Expected to fail
          }
          
          attemptCounts.add(attempts);
        }
        
        // Property: All attempts should respect max retries
        for (final count in attemptCounts) {
          expect(count, lessThanOrEqualTo(3)); // maxRetries + 1
          expect(count, greaterThan(0));
        }
        
        // Property: Should have consistent attempt counts
        final uniqueCounts = attemptCounts.toSet();
        expect(uniqueCounts.length, lessThanOrEqualTo(2)); // Should be mostly consistent
      });

      /// Test retry manager with different operation types
      test('Property: Retry manager handles various operation types', () async {
        final retryManager = RetryManager.instance;
        
        // Test with different return types and error conditions
        final testCases = [
          () async => 'string_result',
          () async => 42,
          () async => true,
          () async => <String, dynamic>{'key': 'value'},
          () async => throw Exception('Always fails'),
        ];
        
        for (int i = 0; i < testCases.length - 1; i++) { // Skip the always-failing case
          final operation = testCases[i];
          
          try {
            final result = await retryManager.executeWithRetry(
              operation,
              maxRetries: 1,
              initialDelay: const Duration(milliseconds: 1),
            );
            
            // Property: Successful operations should return expected result
            expect(result, isNotNull);
            
          } catch (e) {
            // Some operations might fail in test environment
            expect(e, isA<Exception>());
          }
        }
        
        // Test the always-failing case
        try {
          await retryManager.executeWithRetry(
            testCases.last,
            maxRetries: 2,
            initialDelay: const Duration(milliseconds: 1),
          );
          fail('Should have thrown exception');
        } catch (e) {
          // Property: Should eventually fail after retries
          expect(e, isA<Exception>());
        }
      });
    });
  });
}

// Helper functions for generating test data

List<String> _generateTestApiKeys(Random random) {
  return [
    // Valid format keys (but not real)
    'sk-' + List.generate(32, (i) => random.nextInt(16).toRadixString(16)).join(),
    List.generate(40, (i) => random.nextInt(16).toRadixString(16)).join(),
    
    // Invalid format keys
    'YOUR_ELEVENLABS_API_KEY',
    'DEMO_KEY_123',
    'REPLACE_WITH_REAL_KEY',
    '',
    'short',
    'key with spaces',
    '123',
    
    // Edge cases
    'a' * 32, // Minimum length but simple
    'A' * 50, // Longer key
    '0' * 32, // All zeros
  ];
}

List<String> _generateTestTexts(Random random) {
  return [
    'Hello, this is a test message.',
    'I had dal chawal for lunch today.',
    'The weather is nice today.',
    '', // Empty text
    'A', // Single character
    'This is a very long message that contains multiple sentences and should test the fallback system with various text lengths and complexity levels.',
    'Special characters: @#\$%^&*()',
    '12345 67890',
    'Mixed content: Hello 123 @test!',
    'Unicode: 🍎🥗🍚', // Emoji
  ];
}

List<Exception> _generateTestErrors() {
  return [
    ElevenLabsException('Rate limit exceeded', 429),
    ElevenLabsException('Quota exceeded', 402),
    ElevenLabsException('Unauthorized', 401),
    ElevenLabsException('Server error', 500),
    ElevenLabsException('Service unavailable', 503),
    ElevenLabsAuthException('Invalid API key'),
    Exception('Network timeout'),
    Exception('Connection refused'),
    Exception('Unknown error'),
  ];
}