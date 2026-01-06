import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nutrisync/config/environment_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('EnvironmentConfig', () {
    late EnvironmentConfig config;
    
    setUp(() {
      config = EnvironmentConfig.instance;
    });
    
    tearDown(() {
      // Reset singleton for clean tests
      config.reset();
    });
    
    group('Configuration Loading', () {
      test('should load development configuration', () async {
        // Mock asset loading
        const developmentConfig = '''
        {
          "firebase": {
            "projectId": "test-dev",
            "apiKey": "test-key"
          },
          "features": {
            "debugMode": true,
            "enableAnalytics": false
          },
          "app": {
            "name": "Test App Dev"
          }
        }
        ''';
        
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString' &&
                methodCall.arguments == 'assets/config/environments/development.json') {
              return developmentConfig;
            }
            return null;
          },
        );
        
        await config.initialize(environment: 'development');
        
        expect(config.environment, equals('development'));
        expect(config.getValue<String>('firebase.projectId'), equals('test-dev'));
        expect(config.getValue<bool>('features.debugMode'), isTrue);
        expect(config.appName, equals('Test App Dev'));
      });
      
      test('should use default configuration when file not found', () async {
        // Mock asset loading to throw exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            throw Exception('Asset not found');
          },
        );
        
        await config.initialize(environment: 'nonexistent');
        
        expect(config.environment, equals('nonexistent'));
        expect(config.firebaseProjectId, equals('nutrisync-dev'));
        expect(config.isDebugMode, isTrue);
      });
    });
    
    group('Configuration Access', () {
      setUp(() async {
        // Set up test configuration
        config.setConfig({
          'firebase': {
            'projectId': 'test-project',
            'apiKey': 'test-api-key'
          },
          'features': {
            'enableAnalytics': true,
            'enableVoiceFeatures': false,
            'debugMode': false
          },
          'api': {
            'baseUrl': 'https://test-api.com',
            'timeout': 5000
          },
          'app': {
            'name': 'Test App',
            'version': '2.0.0'
          }
        }, 'test');
      });
      
      test('should get nested configuration values', () {
        expect(config.getValue<String>('firebase.projectId'), equals('test-project'));
        expect(config.getValue<String>('firebase.apiKey'), equals('test-api-key'));
        expect(config.getValue<int>('api.timeout'), equals(5000));
      });
      
      test('should return default values for missing keys', () {
        expect(config.getValue<String>('missing.key', defaultValue: 'default'), equals('default'));
        expect(config.getValue<bool>('missing.flag', defaultValue: true), isTrue);
      });
      
      test('should check feature flags correctly', () {
        expect(config.isFeatureEnabled('enableAnalytics'), isTrue);
        expect(config.isFeatureEnabled('enableVoiceFeatures'), isFalse);
        expect(config.isFeatureEnabled('nonexistentFeature'), isFalse);
      });
      
      test('should provide convenience getters', () {
        expect(config.firebaseProjectId, equals('test-project'));
        expect(config.apiBaseUrl, equals('https://test-api.com'));
        expect(config.appName, equals('Test App'));
        expect(config.isDebugMode, isFalse);
      });
      
      test('should identify environment correctly', () {
        config.setConfig({}, 'development');
        expect(config.isDevelopment, isTrue);
        expect(config.isStaging, isFalse);
        expect(config.isProduction, isFalse);
        
        config.setConfig({}, 'staging');
        expect(config.isDevelopment, isFalse);
        expect(config.isStaging, isTrue);
        expect(config.isProduction, isFalse);
        
        config.setConfig({}, 'production');
        expect(config.isDevelopment, isFalse);
        expect(config.isStaging, isFalse);
        expect(config.isProduction, isTrue);
      });
    });
    
    group('Environment Detection', () {
      test('should detect environment from build flavor', () {
        // This would be set during build time
        expect(config.environment, equals('development'));
      });
    });
    
    group('Property-Based Tests', () {
      test('getValue should handle any valid key path', () {
        config.setConfig({
          'level1': {
            'level2': {
              'level3': 'deep-value'
            }
          }
        }, 'test');
        
        expect(config.getValue<String>('level1.level2.level3'), equals('deep-value'));
        expect(config.getValue<Map<String, dynamic>>('level1.level2'), isNotNull);
        expect(config.getValue<String>('invalid.path'), isNull);
      });
      
      test('isFeatureEnabled should always return boolean', () {
        config.setConfig({
          'features': {
            'stringFeature': 'true',
            'boolFeature': true,
            'nullFeature': null
          }
        }, 'test');
        
        // Should handle non-boolean values gracefully
        expect(config.isFeatureEnabled('stringFeature'), isTrue);
        expect(config.isFeatureEnabled('boolFeature'), isTrue);
        expect(config.isFeatureEnabled('nullFeature'), isFalse);
        expect(config.isFeatureEnabled('missingFeature'), isFalse);
      });
    });
  });
}