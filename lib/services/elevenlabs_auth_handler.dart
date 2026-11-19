import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_configuration_manager.dart';
import '../config/secure_key_manager.dart';

/// ElevenLabs Authentication Handler
/// Manages API key validation, authentication errors, and secure key storage
class ElevenLabsAuthHandler {
  static ElevenLabsAuthHandler? _instance;
  static ElevenLabsAuthHandler get instance => _instance ??= ElevenLabsAuthHandler._();
  
  ElevenLabsAuthHandler._();
  
  ApiServiceConfig? _config;
  String? _validatedApiKey;
  DateTime? _lastValidation;
  bool _isInitialized = false;
  
  /// Cache duration for API key validation (1 hour)
  static const Duration _validationCacheDuration = Duration(hours: 1);
  
  /// Initialize authentication handler
  Future<void> initialize() async {
    try {
      _config = ApiConfigurationManager.instance.getServiceConfig('elevenlabs');
      
      if (_config == null) {
        throw ElevenLabsAuthException('ElevenLabs configuration not found');
      }
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ ElevenLabs Auth Handler initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize ElevenLabs Auth Handler: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Get API key with validation
  Future<String> getValidatedApiKey() async {
    if (!_isInitialized) {
      throw StateError('ElevenLabsAuthHandler not initialized');
    }
    
    // Check if we have a cached valid key
    if (_validatedApiKey != null && _isValidationCacheValid()) {
      return _validatedApiKey!;
    }
    
    // Get API key from secure storage or configuration
    final apiKey = await _getApiKey();
    
    if (apiKey == null || apiKey.isEmpty) {
      throw ElevenLabsAuthException('ElevenLabs API key not found');
    }
    
    // Validate the API key format
    if (!_isValidApiKeyFormat(apiKey)) {
      throw ElevenLabsAuthException('Invalid ElevenLabs API key format');
    }
    
    // Validate the API key with ElevenLabs API
    await _validateApiKeyWithService(apiKey);
    
    // Cache the validated key
    _validatedApiKey = apiKey;
    _lastValidation = DateTime.now();
    
    return apiKey;
  }
  
  /// Get API key from secure storage or configuration
  Future<String?> _getApiKey() async {
    // First try to get from secure key manager
    final secureKey = SecureKeyManager.instance.getApiKey('elevenlabs');
    if (secureKey != null && secureKey.isNotEmpty && !secureKey.startsWith('YOUR_')) {
      return secureKey;
    }
    
    // Fallback to configuration
    final configKey = _config?.apiKey;
    if (configKey != null && configKey.isNotEmpty && !configKey.startsWith('YOUR_')) {
      return configKey;
    }
    
    // Check environment variables
    const envKey = String.fromEnvironment('ELEVENLABS_API_KEY');
    if (envKey.isNotEmpty && !envKey.startsWith('YOUR_')) {
      return envKey;
    }
    
    return null;
  }
  
  /// Validate API key format
  bool _isValidApiKeyFormat(String apiKey) {
    // ElevenLabs API keys should be at least 32 characters and not contain spaces
    return apiKey.length >= 32 && 
           !apiKey.contains(' ') && 
           !apiKey.startsWith('YOUR_') &&
           !apiKey.startsWith('DEMO_') &&
           !apiKey.startsWith('REPLACE_');
  }
  
  /// Validate API key with ElevenLabs service
  Future<void> _validateApiKeyWithService(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('${_config!.baseUrl}/user'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(_config!.timeout);
      
      if (response.statusCode == 200) {
        // API key is valid
        if (kDebugMode) {
          final userData = json.decode(response.body);
          print('✓ ElevenLabs API key validated for user: ${userData['email'] ?? 'unknown'}');
        }
        return;
      } else if (response.statusCode == 401) {
        throw ElevenLabsAuthException('Invalid ElevenLabs API key');
      } else if (response.statusCode == 429) {
        throw ElevenLabsAuthException('Rate limit exceeded. Please try again later.');
      } else {
        throw ElevenLabsAuthException('API key validation failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ElevenLabsAuthException) {
        rethrow;
      }
      throw ElevenLabsAuthException('Failed to validate API key: $e');
    }
  }
  
  /// Check if validation cache is still valid
  bool _isValidationCacheValid() {
    if (_lastValidation == null) return false;
    return DateTime.now().difference(_lastValidation!) < _validationCacheDuration;
  }
  
  /// Handle authentication errors
  AuthErrorResult handleAuthError(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        return AuthErrorResult(
          errorType: AuthErrorType.invalidApiKey,
          message: 'Invalid or expired ElevenLabs API key',
          solution: 'Please check your API key in the ElevenLabs dashboard and update it in the app configuration',
          isRetryable: false,
        );
      
      case 402:
        return AuthErrorResult(
          errorType: AuthErrorType.quotaExceeded,
          message: 'ElevenLabs quota exceeded',
          solution: 'Upgrade your ElevenLabs plan or wait for quota reset',
          isRetryable: false,
        );
      
      case 429:
        return AuthErrorResult(
          errorType: AuthErrorType.rateLimited,
          message: 'Rate limit exceeded',
          solution: 'Wait before making more requests. Consider implementing exponential backoff.',
          isRetryable: true,
        );
      
      case 403:
        return AuthErrorResult(
          errorType: AuthErrorType.forbidden,
          message: 'Access forbidden',
          solution: 'Check API key permissions and account status',
          isRetryable: false,
        );
      
      default:
        return AuthErrorResult(
          errorType: AuthErrorType.unknown,
          message: 'Authentication error: $statusCode',
          solution: 'Check API configuration and network connectivity',
          isRetryable: true,
        );
    }
  }
  
  /// Get authentication headers
  Future<Map<String, String>> getAuthHeaders() async {
    final apiKey = await getValidatedApiKey();
    
    return {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json',
      'User-Agent': 'NutriSync/1.0.0',
    };
  }
  
  /// Check if API key is configured
  Future<bool> hasValidApiKey() async {
    try {
      await getValidatedApiKey();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get authentication status
  Future<AuthStatus> getAuthStatus() async {
    try {
      final apiKey = await _getApiKey();
      
      if (apiKey == null) {
        return AuthStatus(
          isAuthenticated: false,
          hasApiKey: false,
          isValidFormat: false,
          isValidated: false,
          error: 'No API key found',
        );
      }
      
      final isValidFormat = _isValidApiKeyFormat(apiKey);
      if (!isValidFormat) {
        return AuthStatus(
          isAuthenticated: false,
          hasApiKey: true,
          isValidFormat: false,
          isValidated: false,
          error: 'Invalid API key format',
        );
      }
      
      // Check if we have a cached validation
      final isValidated = _validatedApiKey == apiKey && _isValidationCacheValid();
      
      return AuthStatus(
        isAuthenticated: isValidated,
        hasApiKey: true,
        isValidFormat: true,
        isValidated: isValidated,
        lastValidation: _lastValidation,
      );
    } catch (e) {
      return AuthStatus(
        isAuthenticated: false,
        hasApiKey: false,
        isValidFormat: false,
        isValidated: false,
        error: e.toString(),
      );
    }
  }
  
  /// Store API key securely
  Future<void> storeApiKey(String apiKey) async {
    if (!_isValidApiKeyFormat(apiKey)) {
      throw ArgumentError('Invalid API key format');
    }
    
    // Store in secure key manager
    await SecureKeyManager.instance.storeApiKey('elevenlabs', apiKey);
    
    // Clear validation cache to force re-validation
    _validatedApiKey = null;
    _lastValidation = null;
    
    if (kDebugMode) {
      print('✓ ElevenLabs API key stored securely');
    }
  }
  
  /// Clear authentication cache
  void clearAuthCache() {
    _validatedApiKey = null;
    _lastValidation = null;
    
    if (kDebugMode) {
      print('✓ ElevenLabs auth cache cleared');
    }
  }
  
  /// Reset handler (for testing)
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _config = null;
    _validatedApiKey = null;
    _lastValidation = null;
  }
}

/// Authentication status information
class AuthStatus {
  final bool isAuthenticated;
  final bool hasApiKey;
  final bool isValidFormat;
  final bool isValidated;
  final DateTime? lastValidation;
  final String? error;
  
  const AuthStatus({
    required this.isAuthenticated,
    required this.hasApiKey,
    required this.isValidFormat,
    required this.isValidated,
    this.lastValidation,
    this.error,
  });
  
  bool get isHealthy => isAuthenticated && hasApiKey && isValidFormat && isValidated;
  
  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      'hasApiKey': hasApiKey,
      'isValidFormat': isValidFormat,
      'isValidated': isValidated,
      'lastValidation': lastValidation?.toIso8601String(),
      'error': error,
      'isHealthy': isHealthy,
    };
  }
}

/// Authentication error result
class AuthErrorResult {
  final AuthErrorType errorType;
  final String message;
  final String solution;
  final bool isRetryable;
  
  const AuthErrorResult({
    required this.errorType,
    required this.message,
    required this.solution,
    required this.isRetryable,
  });
}

/// Authentication error types
enum AuthErrorType {
  invalidApiKey,
  quotaExceeded,
  rateLimited,
  forbidden,
  unknown,
}

/// ElevenLabs authentication exception
class ElevenLabsAuthException implements Exception {
  final String message;
  
  const ElevenLabsAuthException(this.message);
  
  @override
  String toString() => 'ElevenLabsAuthException: $message';
}