import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nutrisync/config/app_initializer.dart';
import 'package:nutrisync/config/environment_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AppInitializer', () {
    late AppInitializer initializer;
    
    setUp(() {
      initializer = AppInitializer.instance;
      initializer.reset(); // Reset for clean tests
    });
    
    tearDown(() {
      initializer.reset();
    });
    
    group('Initialization', () {
      test('should initialize successfully with valid configuration', () async {
        // Mock asset loading for environment config
        const testConfig = '''
        {
          "firebase": {
            "projectId": "test-project",
            "apiKey": "test-key",
            "appId": "test-app-id",
            "messagingSenderId": "123456789",
            "authDomain": "test.firebaseapp.com",
            "storageBucket": "test.appspot.com"
          },
          "features": {
            "enableAnalytics": false,
            "enableCrashlytics": false,
            "debugMode": true
          },
          "app": {
            "name": "Test App"
          }
        }
        ''';
        
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return testConfig;
            }
            return null;
          },
        );
        
        // Mock Firebase initialization
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'Firebase#initializeCore') {
              return [
                {
                  'name': '[DEFAULT]',
                  'options': {
                    'apiKey': 'test-key',
                    'appId': 'test-app-id',
                    'messagingSenderId': '123456789',
                    'projectId': 'test-project',
                  },
                  'pluginConstants': {},
                }
              ];
            }
            return null;
          },
        );
        
        expect(initializer.isInitialized, isFalse);
        
        await initializer.initialize(environment: 'test');
        
        expect(initializer.isInitialized, isTrue);
        expect(EnvironmentConfig.instance.environment, equals('test'));
      });
      
      test('should not reinitialize if already initialized', () async {
        // Mock successful initialization
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            return '{"firebase": {"projectId": "test"}, "features": {}, "app": {}}';
          },
        );
        
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            return [{'name': '[DEFAULT]', 'options': {}, 'pluginConstants': {}}];
          },
        );
        
        await initializer.initialize();
        expect(initializer.isInitialized, isTrue);
        
        // Second initialization should not throw or change state
        await initializer.initialize();
        expect(initializer.isInitialized, isTrue);
      });
      
      test('should handle initialization failure gracefully', () async {
        // Mock asset loading failure
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            throw Exception('Asset loading failed');
          },
        );
        
        // Should not throw, should use default config
        await initializer.initialize();
        
        expect(initializer.isInitialized, isTrue);
        expect(EnvironmentConfig.instance.firebaseProjectId, equals('nutrisync-dev'));
      });
    });
    
    group('Reset Functionality', () {
      test('should reset initialization state', () async {
        // Mock successful initialization
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            return '{"firebase": {"projectId": "test"}, "features": {}, "app": {}}';
          },
        );
        
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            return [{'name': '[DEFAULT]', 'options': {}, 'pluginConstants': {}}];
          },
        );
        
        await initializer.initialize();
        expect(initializer.isInitialized, isTrue);
        
        initializer.reset();
        expect(initializer.isInitialized, isFalse);
      });
    });
    
    group('Property-Based Tests', () {
      test('initialization should be idempotent', () async {
        // Mock successful initialization
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('flutter/assets'),
          (MethodCall methodCall) async {
            return '{"firebase": {"projectId": "test"}, "features": {}, "app": {}}';
          },
        );
        
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            return [{'name': '[DEFAULT]', 'options': {}, 'pluginConstants': {}}];
          },
        );
        
        // Multiple initializations should result in same state
        await initializer.initialize();
        final firstState = initializer.isInitialized;
        
        await initializer.initialize();
        final secondState = initializer.isInitialized;
        
        await initializer.initialize();
        final thirdState = initializer.isInitialized;
        
        expect(firstState, equals(secondState));
        expect(secondState, equals(thirdState));
        expect(thirdState, isTrue);
      });
    });
  });
}