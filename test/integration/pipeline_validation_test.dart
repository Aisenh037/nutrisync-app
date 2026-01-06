import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/config/environment_config.dart';
import 'package:nutrisync/config/firebase_config.dart';
import 'package:nutrisync/config/app_initializer.dart';
import 'dart:convert';
import 'dart:io';

/// Integration tests for CI/CD pipeline validation
/// These tests ensure the deployment pipeline works correctly
void main() {
  group('Pipeline Validation Tests', () {
    group('Configuration Validation', () {
      test('should validate all environment configurations exist', () {
        final environments = ['development', 'staging', 'production'];
        
        for (final env in environments) {
          final configFile = File('assets/config/environments/$env.json');
          expect(configFile.existsSync(), isTrue, 
              reason: 'Configuration file for $env environment should exist');
          
          // Validate JSON structure
          final configContent = configFile.readAsStringSync();
          expect(() => json.decode(configContent), returnsNormally,
              reason: 'Configuration for $env should be valid JSON');
          
          final config = json.decode(configContent) as Map<String, dynamic>;
          
          // Validate required sections
          expect(config.containsKey('firebase'), isTrue,
              reason: '$env config should have firebase section');
          expect(config.containsKey('features'), isTrue,
              reason: '$env config should have features section');
          expect(config.containsKey('app'), isTrue,
              reason: '$env config should have app section');
          
          // Validate Firebase configuration
          final firebaseConfig = config['firebase'] as Map<String, dynamic>;
          expect(firebaseConfig.containsKey('projectId'), isTrue,
              reason: '$env Firebase config should have projectId');
          expect(firebaseConfig.containsKey('apiKey'), isTrue,
              reason: '$env Firebase config should have apiKey');
          expect(firebaseConfig.containsKey('appId'), isTrue,
              reason: '$env Firebase config should have appId');
        }
      });
      
      test('should validate environment-specific values', () {
        final configFiles = {
          'development': File('assets/config/environments/development.json'),
          'staging': File('assets/config/environments/staging.json'),
          'production': File('assets/config/environments/production.json'),
        };
        
        for (final entry in configFiles.entries) {
          final env = entry.key;
          final file = entry.value;
          
          if (file.existsSync()) {
            final config = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
            final features = config['features'] as Map<String, dynamic>;
            
            // Development should have debug mode enabled
            if (env == 'development') {
              expect(features['debugMode'], isTrue,
                  reason: 'Development should have debug mode enabled');
            }
            
            // Production should have analytics enabled
            if (env == 'production') {
              expect(features['enableAnalytics'], isTrue,
                  reason: 'Production should have analytics enabled');
              expect(features['debugMode'], isFalse,
                  reason: 'Production should have debug mode disabled');
            }
          }
        }
      });
    });
    
    group('Build Configuration Validation', () {
      test('should validate pubspec.yaml configuration', () {
        final pubspecFile = File('pubspec.yaml');
        expect(pubspecFile.existsSync(), isTrue,
            reason: 'pubspec.yaml should exist');
        
        final pubspecContent = pubspecFile.readAsStringSync();
        
        // Check for required dependencies
        expect(pubspecContent.contains('flutter_riverpod:'), isTrue,
            reason: 'Should include flutter_riverpod dependency');
        expect(pubspecContent.contains('firebase_core:'), isTrue,
            reason: 'Should include firebase_core dependency');
        expect(pubspecContent.contains('cloud_firestore:'), isTrue,
            reason: 'Should include cloud_firestore dependency');
        
        // Check for assets configuration
        expect(pubspecContent.contains('assets/config/environments/'), isTrue,
            reason: 'Should include environment config assets');
      });
      
      test('should validate Android build configuration', () {
        final buildGradleFile = File('android/app/build.gradle.kts');
        expect(buildGradleFile.existsSync(), isTrue,
            reason: 'Android build.gradle.kts should exist');
        
        final buildContent = buildGradleFile.readAsStringSync();
        
        // Check for signing configuration
        expect(buildContent.contains('signingConfigs'), isTrue,
            reason: 'Should have signing configuration');
        expect(buildContent.contains('productFlavors'), isTrue,
            reason: 'Should have product flavors for environments');
        
        // Check for environment flavors
        expect(buildContent.contains('development'), isTrue,
            reason: 'Should have development flavor');
        expect(buildContent.contains('staging'), isTrue,
            reason: 'Should have staging flavor');
        expect(buildContent.contains('production'), isTrue,
            reason: 'Should have production flavor');
      });
    });
    
    group('CI/CD Workflow Validation', () {
      test('should validate GitHub Actions workflows exist', () {
        final workflowFiles = [
          '.github/workflows/main.yml',
          '.github/workflows/android-release.yml',
          '.github/workflows/ios-release.yml',
          '.github/workflows/security.yml',
        ];
        
        for (final workflowFile in workflowFiles) {
          final file = File(workflowFile);
          expect(file.existsSync(), isTrue,
              reason: 'Workflow file $workflowFile should exist');
        }
      });
      
      test('should validate main workflow configuration', () {
        final mainWorkflowFile = File('.github/workflows/main.yml');
        if (mainWorkflowFile.existsSync()) {
          final workflowContent = mainWorkflowFile.readAsStringSync();
          
          // Check for required jobs
          expect(workflowContent.contains('test:'), isTrue,
              reason: 'Should have test job');
          expect(workflowContent.contains('build-web:'), isTrue,
              reason: 'Should have web build job');
          expect(workflowContent.contains('deploy-staging:'), isTrue,
              reason: 'Should have staging deployment job');
          expect(workflowContent.contains('deploy-production:'), isTrue,
              reason: 'Should have production deployment job');
          
          // Check for Flutter version specification
          expect(workflowContent.contains('FLUTTER_VERSION:'), isTrue,
              reason: 'Should specify Flutter version');
          
          // Check for environment configurations
          expect(workflowContent.contains('environment: staging'), isTrue,
              reason: 'Should have staging environment');
          expect(workflowContent.contains('environment: production'), isTrue,
              reason: 'Should have production environment');
        }
      });
      
      test('should validate Android workflow configuration', () {
        final androidWorkflowFile = File('.github/workflows/android-release.yml');
        if (androidWorkflowFile.existsSync()) {
          final workflowContent = androidWorkflowFile.readAsStringSync();
          
          // Check for Android-specific steps
          expect(workflowContent.contains('Setup Java'), isTrue,
              reason: 'Should have Java setup step');
          expect(workflowContent.contains('Build Android App Bundle'), isTrue,
              reason: 'Should build App Bundle');
          expect(workflowContent.contains('Deploy to Google Play Store'), isTrue,
              reason: 'Should deploy to Play Store');
          
          // Check for signing configuration
          expect(workflowContent.contains('ANDROID_KEYSTORE'), isTrue,
              reason: 'Should use Android keystore secret');
        }
      });
      
      test('should validate iOS workflow configuration', () {
        final iosWorkflowFile = File('.github/workflows/ios-release.yml');
        if (iosWorkflowFile.existsSync()) {
          final workflowContent = iosWorkflowFile.readAsStringSync();
          
          // Check for iOS-specific steps
          expect(workflowContent.contains('Setup Xcode'), isTrue,
              reason: 'Should have Xcode setup step');
          expect(workflowContent.contains('Build iOS app'), isTrue,
              reason: 'Should build iOS app');
          expect(workflowContent.contains('Upload to TestFlight'), isTrue,
              reason: 'Should upload to TestFlight');
          
          // Check for signing configuration
          expect(workflowContent.contains('IOS_CERTIFICATE'), isTrue,
              reason: 'Should use iOS certificate secrets');
          expect(workflowContent.contains('IOS_PROVISIONING_PROFILE'), isTrue,
              reason: 'Should use provisioning profile secrets');
        }
      });
    });
    
    group('Security Configuration Validation', () {
      test('should validate .gitignore excludes secrets', () {
        final gitignoreFile = File('.gitignore');
        expect(gitignoreFile.existsSync(), isTrue,
            reason: '.gitignore should exist');
        
        final gitignoreContent = gitignoreFile.readAsStringSync();
        
        // Check for secret exclusions
        expect(gitignoreContent.contains('.env'), isTrue,
            reason: 'Should exclude .env files');
        expect(gitignoreContent.contains('google-services.json'), isTrue,
            reason: 'Should exclude google-services.json');
        expect(gitignoreContent.contains('keystore.jks'), isTrue,
            reason: 'Should exclude keystore files');
        expect(gitignoreContent.contains('key.properties'), isTrue,
            reason: 'Should exclude key.properties');
        expect(gitignoreContent.contains('service-account'), isTrue,
            reason: 'Should exclude service account files');
      });
      
      test('should validate example configuration files exist', () {
        final exampleFiles = [
          'config/secrets/.env.example',
          'config/secrets/firebase-config.example.js',
          'config/secrets/google-services.example.json',
          'config/secrets/key.properties.example',
        ];
        
        for (final exampleFile in exampleFiles) {
          final file = File(exampleFile);
          expect(file.existsSync(), isTrue,
              reason: 'Example file $exampleFile should exist');
        }
      });
    });
    
    group('Documentation Validation', () {
      test('should validate required documentation exists', () {
        final docFiles = [
          'README.md',
          'CONTRIBUTING.md',
          'docs/DEPLOYMENT.md',
          'docs/FIREBASE_SETUP.md',
        ];
        
        for (final docFile in docFiles) {
          final file = File(docFile);
          expect(file.existsSync(), isTrue,
              reason: 'Documentation file $docFile should exist');
          
          // Check that files are not empty
          final content = file.readAsStringSync();
          expect(content.trim().isNotEmpty, isTrue,
              reason: 'Documentation file $docFile should not be empty');
        }
      });
      
      test('should validate README contains required sections', () {
        final readmeFile = File('README.md');
        if (readmeFile.existsSync()) {
          final readmeContent = readmeFile.readAsStringSync();
          
          // Check for required sections (with emojis as they appear in actual README)
          expect(readmeContent.contains('🌟 Features'), isTrue,
              reason: 'README should have Features section');
          expect(readmeContent.contains('🚀 Quick Start') || readmeContent.contains('🚀 Live Demo'), isTrue,
              reason: 'README should have Quick Start or Live Demo section');
          expect(readmeContent.contains('📋 Prerequisites'), isTrue,
              reason: 'README should have Prerequisites section');
          expect(readmeContent.contains('🤝 Contributing'), isTrue,
              reason: 'README should have Contributing section');
        }
      });
    });
    
    group('Property-Based Pipeline Tests', () {
      test('configuration loading should be deterministic', () {
        // Test that loading the same configuration multiple times produces same result
        final environments = ['development', 'staging', 'production'];
        
        for (final env in environments) {
          final configFile = File('assets/config/environments/$env.json');
          if (configFile.existsSync()) {
            final content1 = configFile.readAsStringSync();
            final content2 = configFile.readAsStringSync();
            
            expect(content1, equals(content2),
                reason: 'Configuration loading should be deterministic');
            
            final config1 = json.decode(content1);
            final config2 = json.decode(content2);
            
            expect(config1, equals(config2),
                reason: 'Parsed configuration should be identical');
          }
        }
      });
      
      test('all environments should have consistent structure', () {
        final environments = ['development', 'staging', 'production'];
        final requiredKeys = ['firebase', 'features', 'app', 'api'];
        
        Map<String, dynamic>? referenceStructure;
        
        for (final env in environments) {
          final configFile = File('assets/config/environments/$env.json');
          if (configFile.existsSync()) {
            final config = json.decode(configFile.readAsStringSync()) as Map<String, dynamic>;
            
            if (referenceStructure == null) {
              referenceStructure = config;
            }
            
            // Check that all environments have the same top-level keys
            for (final key in requiredKeys) {
              expect(config.containsKey(key), isTrue,
                  reason: '$env environment should have $key section');
            }
            
            // Check Firebase configuration structure
            final firebaseConfig = config['firebase'] as Map<String, dynamic>;
            final referenceFirebase = referenceStructure['firebase'] as Map<String, dynamic>;
            
            expect(firebaseConfig.keys.toSet(), equals(referenceFirebase.keys.toSet()),
                reason: '$env Firebase config should have same structure as reference');
          }
        }
      });
    });
  });
}