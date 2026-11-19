import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/config/gcp_config.dart';

void main() {
  group('GCPConfig', () {
    setUp(() {
      GCPConfig.instance.reset();
    });

    test('should initialize with default configuration', () async {
      await GCPConfig.instance.initialize();
      
      expect(GCPConfig.instance.projectId, isNotEmpty);
      expect(GCPConfig.instance.region, isNotEmpty);
      expect(GCPConfig.instance.isValid, isTrue);
    });

    test('should have required APIs enabled by default', () async {
      await GCPConfig.instance.initialize();
      
      final requiredApis = [
        'speechToText',
        'textToSpeech',
        'vision',
        'translation',
        'dialogflow',
        'maps',
        'places'
      ];
      
      for (final api in requiredApis) {
        expect(GCPConfig.instance.isApiEnabled(api), isTrue,
            reason: 'API $api should be enabled by default');
      }
    });

    test('should provide API configurations', () async {
      await GCPConfig.instance.initialize();
      
      final speechConfig = GCPConfig.instance.speechToTextConfig;
      expect(speechConfig['enabled'], isTrue);
      expect(speechConfig['languageCode'], isNotEmpty);
      
      final visionConfig = GCPConfig.instance.visionConfig;
      expect(visionConfig['enabled'], isTrue);
      expect(visionConfig['features'], isA<List>());
    });

    test('should handle custom configuration', () {
      final customConfig = {
        'projectId': 'test-project',
        'region': 'us-west1',
        'apis': {
          'speechToText': {
            'enabled': false,
            'languageCode': 'es-ES'
          }
        }
      };
      
      GCPConfig.instance.setConfig(customConfig);
      
      expect(GCPConfig.instance.projectId, equals('test-project'));
      expect(GCPConfig.instance.region, equals('us-west1'));
      expect(GCPConfig.instance.isApiEnabled('speechToText'), isFalse);
    });

    test('should validate configuration', () async {
      // Valid configuration
      await GCPConfig.instance.initialize();
      expect(GCPConfig.instance.isValid, isTrue);
      
      // Invalid configuration
      GCPConfig.instance.setConfig({
        'projectId': '',
        'region': '',
        'apis': {}
      });
      expect(GCPConfig.instance.isValid, isFalse);
    });

    test('should provide service configurations', () async {
      await GCPConfig.instance.initialize();
      
      final cloudRunConfig = GCPConfig.instance.cloudRunConfig;
      expect(cloudRunConfig['region'], isNotEmpty);
      expect(cloudRunConfig['maxInstances'], isA<int>());
      
      final functionsConfig = GCPConfig.instance.cloudFunctionsConfig;
      expect(functionsConfig['region'], isNotEmpty);
      expect(functionsConfig['runtime'], isNotEmpty);
    });

    test('should provide monitoring configuration', () async {
      await GCPConfig.instance.initialize();
      
      expect(GCPConfig.instance.isMonitoringEnabled, isTrue);
      expect(GCPConfig.instance.isAlertingEnabled, isTrue);
      expect(GCPConfig.instance.costThreshold, isA<double>());
    });

    test('should handle service account credentials', () {
      const mockServiceAccount = '''
      {
        "type": "service_account",
        "project_id": "test-project",
        "client_email": "test@test-project.iam.gserviceaccount.com"
      }
      ''';
      
      GCPConfig.instance.setConfig({}, serviceAccountKey: mockServiceAccount);
      
      expect(GCPConfig.instance.hasServiceAccount, isTrue);
      expect(GCPConfig.instance.serviceAccountCredentials, isNotNull);
      expect(GCPConfig.instance.serviceAccountCredentials!['project_id'], 
             equals('test-project'));
    });
  });
}