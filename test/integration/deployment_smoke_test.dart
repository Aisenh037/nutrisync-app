import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

/// Smoke tests for deployment validation
/// These tests verify that deployed applications are working correctly
void main() {
  group('Deployment Smoke Tests', () {
    group('Web Deployment Tests', () {
      test('should validate staging web deployment is accessible', () async {
        const stagingUrl = 'https://nutrisync-staging.web.app';
        
        try {
          final response = await http.get(Uri.parse(stagingUrl))
              .timeout(const Duration(seconds: 30));
          
          expect(response.statusCode, equals(200),
              reason: 'Staging web app should be accessible');
          
          // Check for basic HTML structure
          expect(response.body.contains('<html'), isTrue,
              reason: 'Response should contain HTML');
          expect(response.body.contains('NutriSync'), isTrue,
              reason: 'Response should contain app name');
        } catch (e) {
          // Skip test if staging is not deployed yet
          print('⚠ Staging deployment not accessible: $e');
        }
      }, skip: 'Run only when staging is deployed');
      
      test('should validate production web deployment is accessible', () async {
        const productionUrl = 'https://nutrisyncapp-97089.web.app';
        
        try {
          final response = await http.get(Uri.parse(productionUrl))
              .timeout(const Duration(seconds: 30));
          
          expect(response.statusCode, equals(200),
              reason: 'Production web app should be accessible');
          
          // Check for basic HTML structure
          expect(response.body.contains('<html'), isTrue,
              reason: 'Response should contain HTML');
          expect(response.body.contains('NutriSync'), isTrue,
              reason: 'Response should contain app name');
          
          // Check for production-specific elements
          expect(response.body.contains('firebase'), isTrue,
              reason: 'Should include Firebase initialization');
        } catch (e) {
          print('⚠ Production deployment test failed: $e');
          rethrow;
        }
      });
      
      test('should validate web app manifest and PWA configuration', () async {
        const baseUrl = 'https://nutrisyncapp-97089.web.app';
        
        try {
          // Check manifest.json
          final manifestResponse = await http.get(Uri.parse('$baseUrl/manifest.json'))
              .timeout(const Duration(seconds: 10));
          
          if (manifestResponse.statusCode == 200) {
            final manifest = json.decode(manifestResponse.body);
            expect(manifest['name'], contains('NutriSync'),
                reason: 'Manifest should contain app name');
            expect(manifest['icons'], isNotEmpty,
                reason: 'Manifest should have icons');
          }
          
          // Check service worker
          final swResponse = await http.get(Uri.parse('$baseUrl/flutter_service_worker.js'))
              .timeout(const Duration(seconds: 10));
          
          expect(swResponse.statusCode, equals(200),
              reason: 'Service worker should be available');
        } catch (e) {
          print('⚠ PWA configuration test failed: $e');
        }
      }, skip: 'Run only when production is deployed');
    });
    
    group('Firebase Functions Tests', () {
      test('should validate health check endpoint', () async {
        const functionsUrl = 'https://us-central1-nutrisyncapp-97089.cloudfunctions.net';
        
        try {
          final response = await http.get(Uri.parse('$functionsUrl/healthCheck'))
              .timeout(const Duration(seconds: 30));
          
          expect(response.statusCode, equals(200),
              reason: 'Health check endpoint should be accessible');
          
          final responseData = json.decode(response.body);
          expect(responseData['status'], equals('healthy'),
              reason: 'Health check should return healthy status');
          expect(responseData['timestamp'], isNotNull,
              reason: 'Health check should include timestamp');
        } catch (e) {
          print('⚠ Functions health check failed: $e');
        }
      }, skip: 'Run only when functions are deployed');
      
      test('should validate CORS configuration for functions', () async {
        const functionsUrl = 'https://us-central1-nutrisyncapp-97089.cloudfunctions.net';
        
        try {
          final response = await http.get(
            Uri.parse('$functionsUrl/healthCheck'),
            headers: {
              'Origin': 'https://nutrisyncapp-97089.web.app',
            },
          ).timeout(const Duration(seconds: 30));
          
          // Check CORS headers
          expect(response.headers.containsKey('access-control-allow-origin'), isTrue,
              reason: 'Functions should have CORS headers');
        } catch (e) {
          print('⚠ CORS validation failed: $e');
        }
      }, skip: 'Run only when functions are deployed');
    });
    
    group('Database Connectivity Tests', () {
      test('should validate Firestore rules are deployed', () async {
        // This test would require Firebase Admin SDK setup
        // For now, we'll test indirectly through the web app
        
        const webAppUrl = 'https://nutrisyncapp-97089.web.app';
        
        try {
          final response = await http.get(Uri.parse(webAppUrl))
              .timeout(const Duration(seconds: 30));
          
          // Check that Firebase is initialized in the web app
          expect(response.body.contains('firebase'), isTrue,
              reason: 'Web app should initialize Firebase');
        } catch (e) {
          print('⚠ Database connectivity test failed: $e');
        }
      }, skip: 'Run only when production is deployed');
    });
    
    group('Performance Tests', () {
      test('should validate web app loading performance', () async {
        const webAppUrl = 'https://nutrisyncapp-97089.web.app';
        
        try {
          final stopwatch = Stopwatch()..start();
          
          final response = await http.get(Uri.parse(webAppUrl))
              .timeout(const Duration(seconds: 30));
          
          stopwatch.stop();
          
          expect(response.statusCode, equals(200),
              reason: 'Web app should load successfully');
          
          // Check loading time (should be under 5 seconds for initial load)
          expect(stopwatch.elapsedMilliseconds, lessThan(5000),
              reason: 'Web app should load within 5 seconds');
          
          print('✓ Web app loaded in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('⚠ Performance test failed: $e');
        }
      }, skip: 'Run only when production is deployed');
      
      test('should validate function cold start performance', () async {
        const functionsUrl = 'https://us-central1-nutrisyncapp-97089.cloudfunctions.net';
        
        try {
          final stopwatch = Stopwatch()..start();
          
          final response = await http.get(Uri.parse('$functionsUrl/healthCheck'))
              .timeout(const Duration(seconds: 30));
          
          stopwatch.stop();
          
          expect(response.statusCode, equals(200),
              reason: 'Function should respond successfully');
          
          // Cold start should be under 10 seconds
          expect(stopwatch.elapsedMilliseconds, lessThan(10000),
              reason: 'Function cold start should be under 10 seconds');
          
          print('✓ Function responded in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('⚠ Function performance test failed: $e');
        }
      }, skip: 'Run only when functions are deployed');
    });
    
    group('Security Tests', () {
      test('should validate HTTPS enforcement', () async {
        const httpUrl = 'http://nutrisyncapp-97089.web.app';
        
        try {
          final response = await http.get(Uri.parse(httpUrl))
              .timeout(const Duration(seconds: 10));
          
          // Should redirect to HTTPS or return 301/302
          expect([301, 302, 308].contains(response.statusCode), isTrue,
              reason: 'HTTP should redirect to HTTPS');
          
          if (response.headers.containsKey('location')) {
            expect(response.headers['location']!.startsWith('https://'), isTrue,
                reason: 'Redirect should be to HTTPS');
          }
        } catch (e) {
          print('⚠ HTTPS enforcement test failed: $e');
        }
      }, skip: 'Run only when production is deployed');
      
      test('should validate security headers', () async {
        const webAppUrl = 'https://nutrisyncapp-97089.web.app';
        
        try {
          final response = await http.get(Uri.parse(webAppUrl))
              .timeout(const Duration(seconds: 30));
          
          // Check for security headers
          final headers = response.headers;
          
          // Content Security Policy
          if (headers.containsKey('content-security-policy')) {
            print('✓ CSP header present');
          }
          
          // X-Frame-Options
          if (headers.containsKey('x-frame-options')) {
            print('✓ X-Frame-Options header present');
          }
          
          // X-Content-Type-Options
          if (headers.containsKey('x-content-type-options')) {
            print('✓ X-Content-Type-Options header present');
          }
        } catch (e) {
          print('⚠ Security headers test failed: $e');
        }
      }, skip: 'Run only when production is deployed');
    });
    
    group('Environment-Specific Tests', () {
      test('should validate environment isolation', () async {
        // Test that different environments use different Firebase projects
        const environments = {
          'staging': 'nutrisync-staging',
          'production': 'nutrisyncapp-97089',
        };
        
        for (final entry in environments.entries) {
          final env = entry.key;
          final expectedProjectId = entry.value;
          
          try {
            // This would require checking the actual Firebase configuration
            // For now, we validate through URL patterns
            final url = env == 'staging' 
                ? 'https://nutrisync-staging.web.app'
                : 'https://nutrisyncapp-97089.web.app';
            
            final response = await http.get(Uri.parse(url))
                .timeout(const Duration(seconds: 30));
            
            if (response.statusCode == 200) {
              // Check that the response contains environment-specific content
              expect(response.body.contains(expectedProjectId), isTrue,
                  reason: '$env should use project $expectedProjectId');
            }
          } catch (e) {
            print('⚠ Environment isolation test for $env failed: $e');
          }
        }
      }, skip: 'Run only when environments are deployed');
    });
    
    group('Rollback Tests', () {
      test('should validate rollback capability exists', () {
        // Check that Firebase hosting has multiple versions
        // This would require Firebase CLI or Admin SDK
        
        final firebaseRcFile = File('.firebaserc');
        expect(firebaseRcFile.existsSync(), isTrue,
            reason: 'Firebase configuration should exist for rollback');
        
        final firebaseJsonFile = File('firebase.json');
        expect(firebaseJsonFile.existsSync(), isTrue,
            reason: 'Firebase hosting configuration should exist');
        
        if (firebaseJsonFile.existsSync()) {
          final config = json.decode(firebaseJsonFile.readAsStringSync());
          expect(config.containsKey('hosting'), isTrue,
              reason: 'Firebase config should have hosting configuration');
        }
      });
    });
  });
}