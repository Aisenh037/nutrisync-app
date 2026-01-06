import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Environment configuration loader for NutriSync
/// Handles loading environment-specific configurations at build time
class EnvironmentConfig {
  static EnvironmentConfig? _instance;
  static EnvironmentConfig get instance => _instance ??= EnvironmentConfig._();
  
  EnvironmentConfig._();
  
  Map<String, dynamic>? _config;
  String? _environment;
  
  /// Current environment (development, staging, production)
  String get environment => _environment ?? 'development';
  
  /// Firebase configuration
  Map<String, dynamic> get firebase => _config?['firebase'] ?? {};
  
  /// Feature flags
  Map<String, dynamic> get features => _config?['features'] ?? {};
  
  /// API configuration
  Map<String, dynamic> get api => _config?['api'] ?? {};
  
  /// App configuration
  Map<String, dynamic> get app => _config?['app'] ?? {};
  
  /// Reset configuration (for testing)
  @visibleForTesting
  void reset() {
    _config = null;
    _environment = null;
  }
  
  /// Set configuration directly (for testing)
  @visibleForTesting
  void setConfig(Map<String, dynamic> config, String environment) {
    _config = config;
    _environment = environment;
  }
  
  /// Initialize configuration from environment-specific JSON file
  Future<void> initialize({String? environment}) async {
    _environment = environment ?? _getEnvironmentFromFlavor();
    
    try {
      // Load environment-specific configuration
      final configPath = 'assets/config/environments/${_environment}.json';
      final configString = await rootBundle.loadString(configPath);
      _config = json.decode(configString) as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('✓ Loaded configuration for environment: $_environment');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load config for $_environment, using defaults: $e');
      }
      _config = _getDefaultConfig();
    }
  }
  
  /// Get environment from build flavor or default to development
  String _getEnvironmentFromFlavor() {
    // In Flutter, we can use const values set at build time
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    return environment;
  }
  
  /// Default configuration fallback
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'firebase': {
        'projectId': 'nutrisync-dev',
        'apiKey': 'demo-api-key',
        'authDomain': 'nutrisync-dev.firebaseapp.com',
        'storageBucket': 'nutrisync-dev.appspot.com',
        'messagingSenderId': '123456789',
        'appId': '1:123456789:web:demo'
      },
      'features': {
        'enableAnalytics': false,
        'enableCrashlytics': false,
        'debugMode': true,
        'enableVoiceFeatures': true,
        'enablePremiumFeatures': false
      },
      'api': {
        'baseUrl': 'https://nutrisync-dev.web.app/api',
        'timeout': 30000,
        'retryAttempts': 3
      },
      'app': {
        'name': 'NutriSync Dev',
        'version': '1.0.0',
        'buildNumber': '1'
      }
    };
  }
  
  /// Get configuration value by key path (e.g., 'firebase.projectId')
  T? getValue<T>(String keyPath, {T? defaultValue}) {
    final keys = keyPath.split('.');
    dynamic current = _config;
    
    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return defaultValue;
      }
    }
    
    // Safe type casting
    try {
      if (current is T) {
        return current;
      } else if (current == null) {
        return defaultValue;
      } else {
        // Try to convert common types
        if (T == String && current != null) {
          return current.toString() as T;
        } else if (T == bool && current != null) {
          if (current is bool) return current as T;
          if (current is String) {
            return (current.toLowerCase() == 'true') as T;
          }
          return defaultValue;
        } else if (T == int && current != null) {
          if (current is int) return current as T;
          if (current is String) {
            return int.tryParse(current) as T? ?? defaultValue;
          }
          return defaultValue;
        }
        return defaultValue;
      }
    } catch (e) {
      return defaultValue;
    }
  }
  
  /// Check if a feature is enabled
  bool isFeatureEnabled(String featureName) {
    return getValue<bool>('features.$featureName', defaultValue: false) ?? false;
  }
  
  /// Get Firebase project ID for current environment
  String get firebaseProjectId => getValue<String>('firebase.projectId', defaultValue: 'nutrisync-dev') ?? 'nutrisync-dev';
  
  /// Get API base URL for current environment
  String get apiBaseUrl => getValue<String>('api.baseUrl', defaultValue: 'https://nutrisync-dev.web.app/api') ?? 'https://nutrisync-dev.web.app/api';
  
  /// Check if running in debug mode
  bool get isDebugMode => getValue<bool>('features.debugMode', defaultValue: kDebugMode) ?? kDebugMode;
  
  /// Check if analytics is enabled
  bool get isAnalyticsEnabled => getValue<bool>('features.enableAnalytics', defaultValue: false) ?? false;
  
  /// Check if crashlytics is enabled
  bool get isCrashlyticsEnabled => getValue<bool>('features.enableCrashlytics', defaultValue: false) ?? false;
  
  /// Get app display name
  String get appName => getValue<String>('app.name', defaultValue: 'NutriSync') ?? 'NutriSync';
}

/// Extension to make configuration access easier
extension EnvironmentConfigExtension on EnvironmentConfig {
  /// Quick access to common configuration values
  bool get isDevelopment => environment == 'development';
  bool get isStaging => environment == 'staging';
  bool get isProduction => environment == 'production';
}