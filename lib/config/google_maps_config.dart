import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'environment_config.dart';
import 'secure_key_manager.dart';

/// Configuration manager for Google Maps and Places API
class GoogleMapsConfig {
  static GoogleMapsConfig? _instance;
  static GoogleMapsConfig get instance => _instance ??= GoogleMapsConfig._();
  
  GoogleMapsConfig._();
  
  final _logger = Logger('GoogleMapsConfig');
  final _secureKeyManager = SecureKeyManager.instance;
  
  String? _apiKey;
  String? _functionsBaseUrl;
  List<String>? _allowedOrigins;
  List<String>? _restrictedApis;
  bool? _corsEnabled;
  bool _isInitialized = false;
  
  /// Initialize Google Maps configuration for the current environment
  Future<void> initialize() async {
    try {
      final environment = EnvironmentConfig.instance.currentEnvironment;
      _logger.info('Initializing Google Maps config for environment: $environment');
      
      // Load configuration from multiple sources with priority order:
      // 1. Secure key manager (encrypted keys)
      // 2. Environment-specific config files
      // 3. Environment variables
      // 4. Default configuration
      
      await _loadFromSecureKeyManager(environment);
      await _loadFromConfigFile(environment);
      _loadFromEnvironmentVariables();
      _setDefaults();
      
      _validateConfiguration();
      _isInitialized = true;
      
      _logger.info('Google Maps configuration initialized successfully');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Google Maps configuration: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Get the Google Maps API key
  String get apiKey {
    if (!_isInitialized) {
      throw GoogleMapsConfigException('Configuration not initialized. Call initialize() first.');
    }
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw GoogleMapsConfigException('Google Maps API key not configured');
    }
    
    if (_isPlaceholderKey(_apiKey!)) {
      throw GoogleMapsConfigException(
        'Google Maps API key is a placeholder. Please configure a valid API key.\n'
        'Current key: ${_apiKey!}\n'
        'Setup instructions: https://developers.google.com/maps/documentation/places/web-service/get-api-key'
      );
    }
    
    return _apiKey!;
  }
  
  /// Get the Firebase Functions base URL
  String get functionsBaseUrl {
    if (!_isInitialized) {
      throw GoogleMapsConfigException('Configuration not initialized. Call initialize() first.');
    }
    
    if (_functionsBaseUrl == null || _functionsBaseUrl!.isEmpty) {
      throw GoogleMapsConfigException('Firebase Functions base URL not configured');
    }
    
    return _functionsBaseUrl!;
  }
  
  /// Get allowed origins for CORS
  List<String> get allowedOrigins => _allowedOrigins ?? ['*'];
  
  /// Get restricted APIs list
  List<String> get restrictedApis => _restrictedApis ?? [];
  
  /// Check if CORS is enabled
  bool get corsEnabled => _corsEnabled ?? true;
  
  /// Check if configuration is valid
  bool get isValid {
    try {
      return _isInitialized && 
             _apiKey != null && 
             _apiKey!.isNotEmpty && 
             !_isPlaceholderKey(_apiKey!) &&
             _functionsBaseUrl != null && 
             _functionsBaseUrl!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get configuration as a map
  Map<String, dynamic> toMap() {
    return {
      'apiKey': _apiKey,
      'functionsBaseUrl': _functionsBaseUrl,
      'allowedOrigins': _allowedOrigins,
      'restrictedApis': _restrictedApis,
      'corsEnabled': _corsEnabled,
      'isValid': isValid,
    };
  }
  
  /// Load configuration from secure key manager
  Future<void> _loadFromSecureKeyManager(String environment) async {
    try {
      final secureConfig = await _secureKeyManager.getApiKeys('google_maps', environment);
      
      if (secureConfig.isNotEmpty) {
        _apiKey = secureConfig['api_key'] as String?;
        _functionsBaseUrl = secureConfig['functions_base_url'] as String?;
        
        _logger.info('Loaded Google Maps configuration from secure key manager');
      }
      
    } catch (e) {
      _logger.warning('Failed to load from secure key manager: $e');
      // Continue with other sources
    }
  }
  
  /// Load configuration from environment-specific config file
  Future<void> _loadFromConfigFile(String environment) async {
    try {
      final configPaths = [
        'assets/config/google_maps/google_maps_$environment.json',
        'assets/config/google_maps/google_maps.json',
        'assets/config/environments/$environment.json',
      ];
      
      for (final path in configPaths) {
        try {
          final configString = await rootBundle.loadString(path);
          final config = json.decode(configString) as Map<String, dynamic>;
          
          final googleMapsConfig = config['google_maps'] as Map<String, dynamic>?;
          if (googleMapsConfig != null) {
            _apiKey ??= googleMapsConfig['api_key'] as String?;
            _functionsBaseUrl ??= googleMapsConfig['functions_base_url'] as String?;
            _allowedOrigins ??= (googleMapsConfig['allowed_origins'] as List<dynamic>?)?.cast<String>();
            _restrictedApis ??= (googleMapsConfig['restricted_apis'] as List<dynamic>?)?.cast<String>();
            _corsEnabled ??= googleMapsConfig['cors_enabled'] as bool?;
            
            _logger.info('Loaded Google Maps configuration from: $path');
            break;
          }
          
        } catch (e) {
          _logger.fine('Config file not found or invalid: $path');
          continue;
        }
      }
      
    } catch (e) {
      _logger.warning('Failed to load from config files: $e');
      // Continue with other sources
    }
  }
  
  /// Load configuration from environment variables
  void _loadFromEnvironmentVariables() {
    try {
      const apiKeyEnvVars = [
        'GOOGLE_MAPS_API_KEY',
        'GOOGLE_PLACES_API_KEY',
        'MAPS_API_KEY',
      ];
      
      for (final envVar in apiKeyEnvVars) {
        final value = const String.fromEnvironment(envVar);
        if (value.isNotEmpty) {
          _apiKey ??= value;
          break;
        }
      }
      
      const functionsUrlEnvVars = [
        'FIREBASE_FUNCTIONS_BASE_URL',
        'FUNCTIONS_BASE_URL',
      ];
      
      for (final envVar in functionsUrlEnvVars) {
        final value = const String.fromEnvironment(envVar);
        if (value.isNotEmpty) {
          _functionsBaseUrl ??= value;
          break;
        }
      }
      
      if (_apiKey != null || _functionsBaseUrl != null) {
        _logger.info('Loaded Google Maps configuration from environment variables');
      }
      
    } catch (e) {
      _logger.warning('Failed to load from environment variables: $e');
      // Continue with defaults
    }
  }
  
  /// Set default configuration values
  void _setDefaults() {
    // Set default Firebase Functions URL if not configured
    _functionsBaseUrl ??= _getDefaultFunctionsUrl();
    
    // Set default CORS settings
    _corsEnabled ??= true;
    _allowedOrigins ??= ['*'];
    _restrictedApis ??= [];
  }
  
  /// Get default Firebase Functions URL
  String _getDefaultFunctionsUrl() {
    final environment = EnvironmentConfig.instance.currentEnvironment;
    
    // Default project configuration based on environment
    final projectConfigs = {
      'development': {
        'projectId': 'nutrisync-dev',
        'region': 'us-central1',
      },
      'staging': {
        'projectId': 'nutrisync-staging',
        'region': 'us-central1',
      },
      'production': {
        'projectId': 'nutrisync-ai',
        'region': 'us-central1',
      },
    };
    
    final config = projectConfigs[environment] ?? projectConfigs['production']!;
    final projectId = config['projectId'];
    final region = config['region'];
    
    return 'https://$region-$projectId.cloudfunctions.net';
  }
  
  /// Validate the configuration
  void _validateConfiguration() {
    final errors = <String>[];
    
    // Validate API key
    if (_apiKey == null || _apiKey!.isEmpty) {
      errors.add('Google Maps API key is required');
    } else if (_isPlaceholderKey(_apiKey!)) {
      errors.add('Google Maps API key is a placeholder and must be replaced with a valid key');
    } else if (!_isValidApiKeyFormat(_apiKey!)) {
      errors.add('Google Maps API key format is invalid');
    }
    
    // Validate Functions URL
    if (_functionsBaseUrl == null || _functionsBaseUrl!.isEmpty) {
      errors.add('Firebase Functions base URL is required');
    } else if (!_isValidUrl(_functionsBaseUrl!)) {
      errors.add('Firebase Functions base URL format is invalid');
    }
    
    if (errors.isNotEmpty) {
      throw GoogleMapsConfigException(
        'Google Maps configuration validation failed:\n${errors.join('\n')}\n\n'
        'Setup instructions:\n'
        '1. Get a Google Maps API key: https://developers.google.com/maps/documentation/places/web-service/get-api-key\n'
        '2. Configure the API key in your environment configuration\n'
        '3. Set up Firebase Functions URL for your project'
      );
    }
  }
  
  /// Check if the API key is a placeholder
  bool _isPlaceholderKey(String key) {
    final placeholderPatterns = [
      'YOUR_',
      'PLACEHOLDER',
      'REPLACE_',
      'CHANGE_',
      'ADD_YOUR_',
      'INSERT_',
      'EXAMPLE_',
      'TEST_KEY',
      'DEMO_KEY',
    ];
    
    final upperKey = key.toUpperCase();
    return placeholderPatterns.any((pattern) => upperKey.contains(pattern));
  }
  
  /// Validate API key format
  bool _isValidApiKeyFormat(String key) {
    // Google Maps API keys typically start with "AIza" and are 39 characters long
    // But we'll be more flexible to accommodate different key formats
    return key.length >= 20 && 
           key.length <= 100 && 
           RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key);
  }
  
  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
  
  /// Reset configuration (for testing)
  void reset() {
    _apiKey = null;
    _functionsBaseUrl = null;
    _allowedOrigins = null;
    _restrictedApis = null;
    _corsEnabled = null;
    _isInitialized = false;
  }
}

/// Exception for Google Maps configuration errors
class GoogleMapsConfigException implements Exception {
  final String message;
  
  GoogleMapsConfigException(this.message);
  
  @override
  String toString() => 'GoogleMapsConfigException: $message';
}