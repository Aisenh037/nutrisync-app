import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'environment_config.dart';

/// Firebase configuration manager for different environments
class FirebaseConfig {
  static FirebaseConfig? _instance;
  static FirebaseConfig get instance => _instance ??= FirebaseConfig._();
  
  FirebaseConfig._();
  
  /// Initialize Firebase with environment-specific configuration
  Future<void> initialize() async {
    final config = EnvironmentConfig.instance;
    
    // Get Firebase configuration from environment config
    final firebaseConfig = config.firebase;
    
    final options = FirebaseOptions(
      apiKey: firebaseConfig['apiKey'] ?? '',
      appId: firebaseConfig['appId'] ?? '',
      messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
      projectId: firebaseConfig['projectId'] ?? '',
      authDomain: firebaseConfig['authDomain'],
      storageBucket: firebaseConfig['storageBucket'],
      measurementId: firebaseConfig['measurementId'],
    );
    
    try {
      await Firebase.initializeApp(options: options);
      
      if (kDebugMode) {
        print('✓ Firebase initialized for environment: ${config.environment}');
        print('✓ Project ID: ${options.projectId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Firebase initialization failed: $e');
      }
      rethrow;
    }
  }
  
  /// Get Firebase options for current environment
  FirebaseOptions getFirebaseOptions() {
    final config = EnvironmentConfig.instance;
    final firebaseConfig = config.firebase;
    
    return FirebaseOptions(
      apiKey: firebaseConfig['apiKey'] ?? '',
      appId: firebaseConfig['appId'] ?? '',
      messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
      projectId: firebaseConfig['projectId'] ?? '',
      authDomain: firebaseConfig['authDomain'],
      storageBucket: firebaseConfig['storageBucket'],
      measurementId: firebaseConfig['measurementId'],
    );
  }
  
  /// Get project ID for current environment
  String get projectId {
    return EnvironmentConfig.instance.firebaseProjectId;
  }
  
  /// Check if Firebase is properly configured
  bool get isConfigured {
    try {
      final config = EnvironmentConfig.instance.firebase;
      return config['projectId'] != null && 
             config['apiKey'] != null && 
             config['appId'] != null;
    } catch (e) {
      return false;
    }
  }
}