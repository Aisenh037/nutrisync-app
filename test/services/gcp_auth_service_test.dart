import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/gcp_auth_service.dart';
import 'package:nutrisync/config/gcp_config.dart';

void main() {
  group('GCPAuthService', () {
    setUp(() {
      GCPAuthService.instance.reset();
      GCPConfig.instance.reset();
    });

    test('should initialize successfully', () async {
      await GCPAuthService.instance.initialize();
      expect(GCPAuthService.instance.isConfigured, isTrue);
    });

    test('should provide mock token in development', () async {
      await GCPAuthService.instance.initialize();
      
      final token = await GCPAuthService.instance.getAccessToken();
      expect(token, isNotNull);
      expect(token, contains('mock'));
    });

    test('should provide authentication headers', () async {
      await GCPAuthService.instance.initialize();
      
      final headers = await GCPAuthService.instance.getAuthHeaders();
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['Authorization'], startsWith('Bearer '));
      expect(headers['User-Agent'], contains('NutriSync'));
    });

    test('should handle token expiry', () async {
      await GCPAuthService.instance.initialize();
      
      // Get initial token
      final token1 = await GCPAuthService.instance.getAccessToken();
      expect(token1, isNotNull);
      
      // Clear auth to simulate expiry
      GCPAuthService.instance.clearAuth();
      expect(GCPAuthService.instance.hasValidToken, isFalse);
      
      // Get new token
      final token2 = await GCPAuthService.instance.getAccessToken();
      expect(token2, isNotNull);
    });

    test('should create authenticated HTTP client', () async {
      await GCPAuthService.instance.initialize();
      
      final client = await GCPAuthService.instance.createAuthenticatedClient();
      expect(client, isNotNull);
      
      client.close();
    });

    test('should handle authentication errors gracefully', () async {
      // Set invalid configuration
      GCPConfig.instance.setConfig({
        'projectId': '',
        'region': '',
        'apis': {}
      });
      
      await GCPAuthService.instance.initialize();
      
      // Should still provide mock token in development
      final token = await GCPAuthService.instance.getAccessToken();
      expect(token, isNotNull);
    });
  });
}