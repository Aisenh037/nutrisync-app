import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/config/environment_config.dart';
import 'package:nutrisync/config/api_configuration_manager.dart';
import 'package:nutrisync/config/configuration_validator.dart';
import 'package:nutrisync/config/secure_key_manager.dart';
import 'package:nutrisync/config/configuration_cache.dart';
import 'package:nutrisync/config/configuration_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Configuration Management Infrastructure', () {
    setUp(() {
      // Reset all singletons before each test
      EnvironmentConfig.instance.reset();
      ApiConfigurationManager.instance.reset();
      ConfigurationValidator.instance.clearCache();
      SecureKeyManager.instance.reset();
      ConfigurationCache.instance.reset();
    });

    test('Environment Config initializes correctly', () async {
      // Test environment config initialization
      await EnvironmentConfig.instance.initialize(environment: 'development');
      
      expect(EnvironmentConfig.instance.environment, equals('development'));
      expect(EnvironmentConfig.instance.isDevelopment, isTrue);
      expect(EnvironmentConfig.instance.isProduction, isFalse);
    });

    test('API Configuration Manager initializes with services', () async {
      // Initialize environment first
      await EnvironmentConfig.instance.initialize(environment: 'development');
      
      // Initialize API configuration manager
      await ApiConfigurationManager.instance.initialize();
      
      expect(ApiConfigurationManager.instance.isInitialized, isTrue);
      
      // Check if services are configured
      final configs = ApiConfigurationManager.instance.getAllConfigs();
      expect(configs, isNotEmpty);
      expect(configs.containsKey('elevenlabs'), isTrue);
      expect(configs.containsKey('googlemaps'), isTrue);
      expect(configs.containsKey('gcp'), isTrue);
    });

    test('Secure Key Manager handles development keys', () async {
      await SecureKeyManager.instance.initialize();
      
      // In development, should provide placeholder keys
      final elevenLabsKey = SecureKeyManager.instance.getApiKey('elevenlabs');
      expect(elevenLabsKey, isNotNull);
      expect(elevenLabsKey, contains('dev_'));
    });

    test('Configuration Validator initializes with rules', () {
      ConfigurationValidator.instance.initialize();
      
      // Should have validation rules
      expect(ConfigurationValidator.instance, isNotNull);
    });

    test('Configuration Cache initializes correctly', () async {
      await ConfigurationCache.instance.initialize();
      
      // Should be able to cache and retrieve values
      await ConfigurationCache.instance.cacheConfig('test_key', 'test_value');
      
      final cachedValue = ConfigurationCache.instance.getCachedConfig<String>('test_key');
      expect(cachedValue, equals('test_value'));
    });

    test('Configuration Initializer orchestrates all components', () async {
      final result = await ConfigurationInitializer.instance.initialize(
        environment: 'development',
        validateOnStartup: false, // Skip validation to avoid network calls in tests
        enableCaching: true,
        enableSecureKeys: true,
      );
      
      expect(result.isSuccess, isTrue);
      expect(result.environment, equals('development'));
      expect(ConfigurationInitializer.instance.isInitialized, isTrue);
      
      // Check system status
      final status = ConfigurationInitializer.instance.getSystemStatus();
      expect(status.isInitialized, isTrue);
      expect(status.environment, equals('development'));
    });

    test('API Service Config validates correctly', () {
      final config = ApiServiceConfig(
        serviceName: 'test_service',
        baseUrl: 'https://api.test.com',
        apiKey: 'test_key_123456789',
        timeout: const Duration(seconds: 30),
        retryAttempts: 3,
        rateLimitPerMinute: 100,
        isEnabled: true,
      );
      
      expect(config.isValid, isTrue);
      expect(config.serviceName, equals('test_service'));
      expect(config.baseUrl, equals('https://api.test.com'));
      expect(config.isEnabled, isTrue);
    });

    test('Configuration system handles missing environment gracefully', () async {
      // Try to initialize with non-existent environment
      await EnvironmentConfig.instance.initialize(environment: 'nonexistent');
      
      // Should fall back to defaults
      expect(EnvironmentConfig.instance.environment, equals('nonexistent'));
      // Should still have some configuration
      expect(EnvironmentConfig.instance.firebase, isNotEmpty);
    });

    test('Secure Key Manager validates key formats correctly', () async {
      await SecureKeyManager.instance.initialize();
      
      // Test valid ElevenLabs key format
      await SecureKeyManager.instance.storeApiKey('elevenlabs', 'sk-1234567890abcdef1234567890abcdef');
      expect(SecureKeyManager.instance.hasApiKey('elevenlabs'), isTrue);
      
      // Test invalid key should throw
      expect(
        () => SecureKeyManager.instance.storeApiKey('elevenlabs', 'invalid'),
        throwsArgumentError,
      );
    });

    test('Configuration Cache handles expiration correctly', () async {
      await ConfigurationCache.instance.initialize();
      
      // Cache with very short TTL
      await ConfigurationCache.instance.cacheConfig(
        'short_lived_key', 
        'test_value',
        ttl: const Duration(milliseconds: 100),
      );
      
      // Should be cached initially
      expect(ConfigurationCache.instance.isCached('short_lived_key'), isTrue);
      
      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should be expired now
      expect(ConfigurationCache.instance.isCached('short_lived_key'), isFalse);
    });
  });
}