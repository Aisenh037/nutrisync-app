import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api_configuration_manager.dart';
import 'environment_config.dart';

/// Configuration Validation Framework
/// Validates API configurations, provides diagnostics, and ensures system readiness
class ConfigurationValidator {
  static ConfigurationValidator? _instance;
  static ConfigurationValidator get instance => _instance ??= ConfigurationValidator._();
  
  ConfigurationValidator._();
  
  final List<ValidationRule> _validationRules = [];
  final Map<String, ValidationResult> _cachedResults = {};
  DateTime? _lastValidationTime;
  
  /// Cache duration for validation results (2 minutes)
  static const Duration _cacheDuration = Duration(minutes: 2);
  
  /// Initialize validator with default rules
  void initialize() {
    _validationRules.clear();
    
    // Add default validation rules
    _addDefaultValidationRules();
    
    if (kDebugMode) {
      print('✓ Configuration Validator initialized with ${_validationRules.length} rules');
    }
  }
  
  /// Add default validation rules
  void _addDefaultValidationRules() {
    // Environment Configuration Validation
    _validationRules.add(ValidationRule(
      name: 'environment_config',
      description: 'Validate environment configuration is loaded',
      validator: _validateEnvironmentConfig,
      severity: ValidationSeverity.critical,
    ));
    
    // API Configuration Manager Validation
    _validationRules.add(ValidationRule(
      name: 'api_config_manager',
      description: 'Validate API Configuration Manager is initialized',
      validator: _validateApiConfigManager,
      severity: ValidationSeverity.critical,
    ));
    
    // ElevenLabs Configuration Validation
    _validationRules.add(ValidationRule(
      name: 'elevenlabs_config',
      description: 'Validate ElevenLabs API configuration',
      validator: _validateElevenLabsConfig,
      severity: ValidationSeverity.high,
    ));
    
    // Google Maps Configuration Validation
    _validationRules.add(ValidationRule(
      name: 'googlemaps_config',
      description: 'Validate Google Maps API configuration',
      validator: _validateGoogleMapsConfig,
      severity: ValidationSeverity.high,
    ));
    
    // Google Places Configuration Validation
    _validationRules.add(ValidationRule(
      name: 'googleplaces_config',
      description: 'Validate Google Places API configuration',
      validator: _validateGooglePlacesConfig,
      severity: ValidationSeverity.high,
    ));
    
    // GCP Service Account Validation
    _validationRules.add(ValidationRule(
      name: 'gcp_service_account',
      description: 'Validate GCP service account configuration',
      validator: _validateGcpServiceAccount,
      severity: ValidationSeverity.high,
    ));
    
    // Network Connectivity Validation
    _validationRules.add(ValidationRule(
      name: 'network_connectivity',
      description: 'Validate network connectivity to API services',
      validator: _validateNetworkConnectivity,
      severity: ValidationSeverity.medium,
    ));
    
    // CORS Configuration Validation (Web only)
    if (kIsWeb) {
      _validationRules.add(ValidationRule(
        name: 'cors_config',
        description: 'Validate CORS configuration for web deployment',
        validator: _validateCorsConfig,
        severity: ValidationSeverity.medium,
      ));
    }
  }
  
  /// Validate all configurations
  Future<ValidationSummary> validateAll({bool useCache = true}) async {
    if (useCache && _isCacheValid()) {
      return _createSummaryFromCache();
    }
    
    final results = <ValidationResult>[];
    final issues = <ConfigurationIssue>[];
    
    for (final rule in _validationRules) {
      try {
        final result = await rule.validator();
        results.add(result);
        _cachedResults[rule.name] = result;
        
        if (!result.isValid) {
          issues.addAll(result.issues);
        }
      } catch (e) {
        final errorResult = ValidationResult(
          ruleName: rule.name,
          isValid: false,
          message: 'Validation failed: $e',
          issues: [
            ConfigurationIssue(
              service: rule.name,
              issue: 'Validation error: $e',
              solution: 'Check the configuration and try again',
              severity: rule.severity,
            ),
          ],
        );
        results.add(errorResult);
        _cachedResults[rule.name] = errorResult;
        issues.addAll(errorResult.issues);
      }
    }
    
    _lastValidationTime = DateTime.now();
    
    return ValidationSummary(
      isValid: results.every((r) => r.isValid),
      results: results,
      issues: issues,
      validationTime: _lastValidationTime!,
      environment: EnvironmentConfig.instance.environment,
    );
  }
  
  /// Validate specific service configuration
  Future<ValidationResult> validateService(String serviceName) async {
    final rule = _validationRules.firstWhere(
      (r) => r.name == '${serviceName}_config',
      orElse: () => throw ArgumentError('No validation rule found for service: $serviceName'),
    );
    
    return await rule.validator();
  }
  
  /// Check if validation cache is valid
  bool _isCacheValid() {
    if (_lastValidationTime == null || _cachedResults.isEmpty) return false;
    return DateTime.now().difference(_lastValidationTime!) < _cacheDuration;
  }
  
  /// Create summary from cached results
  ValidationSummary _createSummaryFromCache() {
    final results = _cachedResults.values.toList();
    final issues = results.expand((r) => r.issues).toList();
    
    return ValidationSummary(
      isValid: results.every((r) => r.isValid),
      results: results,
      issues: issues,
      validationTime: _lastValidationTime!,
      environment: EnvironmentConfig.instance.environment,
    );
  }
  
  /// Validate environment configuration
  Future<ValidationResult> _validateEnvironmentConfig() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final envConfig = EnvironmentConfig.instance;
      
      // Check if environment is loaded
      if (envConfig.environment.isEmpty) {
        issues.add(ConfigurationIssue(
          service: 'environment',
          issue: 'Environment not set',
          solution: 'Set ENVIRONMENT variable or initialize EnvironmentConfig',
          severity: ValidationSeverity.critical,
        ));
      }
      
      // Check Firebase configuration
      final firebaseConfig = envConfig.firebase;
      if (firebaseConfig.isEmpty || firebaseConfig['projectId'] == null) {
        issues.add(ConfigurationIssue(
          service: 'firebase',
          issue: 'Firebase configuration missing',
          solution: 'Add Firebase configuration to environment JSON file',
          severity: ValidationSeverity.high,
        ));
      }
      
      // Check API configuration
      final apiConfig = envConfig.api;
      if (apiConfig.isEmpty || apiConfig['baseUrl'] == null) {
        issues.add(ConfigurationIssue(
          service: 'api',
          issue: 'API configuration missing',
          solution: 'Add API configuration to environment JSON file',
          severity: ValidationSeverity.high,
        ));
      }
      
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'environment',
        issue: 'Failed to validate environment configuration: $e',
        solution: 'Check environment configuration files and initialization',
        severity: ValidationSeverity.critical,
      ));
    }
    
    return ValidationResult(
      ruleName: 'environment_config',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'Environment configuration is valid' : 'Environment configuration has issues',
      issues: issues,
    );
  }
  
  /// Validate API Configuration Manager
  Future<ValidationResult> _validateApiConfigManager() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final apiManager = ApiConfigurationManager.instance;
      
      if (!apiManager.isInitialized) {
        issues.add(ConfigurationIssue(
          service: 'api_manager',
          issue: 'API Configuration Manager not initialized',
          solution: 'Call ApiConfigurationManager.instance.initialize() during app startup',
          severity: ValidationSeverity.critical,
        ));
      } else {
        // Check if cache is valid
        if (!apiManager.isCacheValid) {
          issues.add(ConfigurationIssue(
            service: 'api_manager',
            issue: 'Configuration cache expired',
            solution: 'Consider calling reload() to refresh configuration',
            severity: ValidationSeverity.low,
          ));
        }
        
        // Check if any services are configured
        final configs = apiManager.getAllConfigs();
        if (configs.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'api_manager',
            issue: 'No API services configured',
            solution: 'Add API service configurations to the manager',
            severity: ValidationSeverity.high,
          ));
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'api_manager',
        issue: 'Failed to validate API Configuration Manager: $e',
        solution: 'Check API Configuration Manager initialization',
        severity: ValidationSeverity.critical,
      ));
    }
    
    return ValidationResult(
      ruleName: 'api_config_manager',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'API Configuration Manager is valid' : 'API Configuration Manager has issues',
      issues: issues,
    );
  }
  
  /// Validate ElevenLabs configuration
  Future<ValidationResult> _validateElevenLabsConfig() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final config = ApiConfigurationManager.instance.getServiceConfig('elevenlabs');
      
      if (config == null) {
        issues.add(ConfigurationIssue(
          service: 'elevenlabs',
          issue: 'ElevenLabs configuration not found',
          solution: 'Add ElevenLabs configuration to API Configuration Manager',
          severity: ValidationSeverity.high,
        ));
      } else {
        // Check if service is enabled
        if (!config.isEnabled) {
          issues.add(ConfigurationIssue(
            service: 'elevenlabs',
            issue: 'ElevenLabs service is disabled',
            solution: 'Enable ElevenLabs service in configuration or disable voice features',
            severity: ValidationSeverity.medium,
          ));
        }
        
        // Check API key
        if (!config.hasValidApiKey) {
          issues.add(ConfigurationIssue(
            service: 'elevenlabs',
            issue: 'ElevenLabs API key is missing or invalid',
            solution: 'Set ELEVENLABS_API_KEY environment variable or add to secure configuration',
            severity: ValidationSeverity.high,
          ));
        }
        
        // Check supported models
        final supportedModels = config.getConfig<List<dynamic>>('supportedModels');
        if (supportedModels == null || supportedModels.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'elevenlabs',
            issue: 'No supported models configured',
            solution: 'Add supported models list to ElevenLabs configuration',
            severity: ValidationSeverity.medium,
          ));
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'elevenlabs',
        issue: 'Failed to validate ElevenLabs configuration: $e',
        solution: 'Check ElevenLabs configuration setup',
        severity: ValidationSeverity.high,
      ));
    }
    
    return ValidationResult(
      ruleName: 'elevenlabs_config',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'ElevenLabs configuration is valid' : 'ElevenLabs configuration has issues',
      issues: issues,
    );
  }
  
  /// Validate Google Maps configuration
  Future<ValidationResult> _validateGoogleMapsConfig() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final config = ApiConfigurationManager.instance.getServiceConfig('googlemaps');
      
      if (config == null) {
        issues.add(ConfigurationIssue(
          service: 'googlemaps',
          issue: 'Google Maps configuration not found',
          solution: 'Add Google Maps configuration to API Configuration Manager',
          severity: ValidationSeverity.high,
        ));
      } else {
        // Check API key
        if (!config.hasValidApiKey) {
          issues.add(ConfigurationIssue(
            service: 'googlemaps',
            issue: 'Google Maps API key is missing or invalid',
            solution: 'Set GOOGLE_MAPS_API_KEY environment variable or add to secure configuration',
            severity: ValidationSeverity.high,
          ));
        } else {
          // Validate API key format
          final apiKey = config.apiKey!;
          if (!apiKey.startsWith('AIza') || apiKey.length != 39) {
            issues.add(ConfigurationIssue(
              service: 'googlemaps',
              issue: 'Google Maps API key format is invalid',
              solution: 'Ensure API key starts with "AIza" and is 39 characters long',
              severity: ValidationSeverity.high,
            ));
          }
        }
        
        // Check CORS configuration for web
        if (kIsWeb) {
          final corsEnabled = config.getConfig<bool>('corsEnabled', defaultValue: false);
          if (!corsEnabled!) {
            issues.add(ConfigurationIssue(
              service: 'googlemaps',
              issue: 'CORS not enabled for web deployment',
              solution: 'Enable CORS handling for Google Maps API in web environment',
              severity: ValidationSeverity.medium,
            ));
          }
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'googlemaps',
        issue: 'Failed to validate Google Maps configuration: $e',
        solution: 'Check Google Maps configuration setup',
        severity: ValidationSeverity.high,
      ));
    }
    
    return ValidationResult(
      ruleName: 'googlemaps_config',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'Google Maps configuration is valid' : 'Google Maps configuration has issues',
      issues: issues,
    );
  }
  
  /// Validate Google Places configuration
  Future<ValidationResult> _validateGooglePlacesConfig() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final config = ApiConfigurationManager.instance.getServiceConfig('googleplaces');
      
      if (config == null) {
        issues.add(ConfigurationIssue(
          service: 'googleplaces',
          issue: 'Google Places configuration not found',
          solution: 'Add Google Places configuration to API Configuration Manager',
          severity: ValidationSeverity.high,
        ));
      } else {
        // Check API key (can be same as Maps)
        if (!config.hasValidApiKey) {
          issues.add(ConfigurationIssue(
            service: 'googleplaces',
            issue: 'Google Places API key is missing or invalid',
            solution: 'Set GOOGLE_PLACES_API_KEY environment variable or use same key as Google Maps',
            severity: ValidationSeverity.high,
          ));
        }
        
        // Check place types configuration
        final types = config.getConfig<List<dynamic>>('types');
        if (types == null || types.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'googleplaces',
            issue: 'No place types configured',
            solution: 'Add place types list to Google Places configuration',
            severity: ValidationSeverity.medium,
          ));
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'googleplaces',
        issue: 'Failed to validate Google Places configuration: $e',
        solution: 'Check Google Places configuration setup',
        severity: ValidationSeverity.high,
      ));
    }
    
    return ValidationResult(
      ruleName: 'googleplaces_config',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'Google Places configuration is valid' : 'Google Places configuration has issues',
      issues: issues,
    );
  }
  
  /// Validate GCP service account configuration
  Future<ValidationResult> _validateGcpServiceAccount() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      final config = ApiConfigurationManager.instance.getServiceConfig('gcp');
      
      if (config == null) {
        issues.add(ConfigurationIssue(
          service: 'gcp',
          issue: 'GCP configuration not found',
          solution: 'Add GCP configuration to API Configuration Manager',
          severity: ValidationSeverity.high,
        ));
      } else {
        // Check service account path
        final serviceAccountPath = config.getConfig<String>('serviceAccountPath');
        if (serviceAccountPath == null || serviceAccountPath.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'gcp',
            issue: 'GCP service account path not configured',
            solution: 'Set service account path in GCP configuration',
            severity: ValidationSeverity.high,
          ));
        } else {
          // Try to load service account file
          try {
            await rootBundle.loadString(serviceAccountPath);
          } catch (e) {
            issues.add(ConfigurationIssue(
              service: 'gcp',
              issue: 'GCP service account file not found: $serviceAccountPath',
              solution: 'Add service account JSON file to assets or update path',
              severity: ValidationSeverity.high,
            ));
          }
        }
        
        // Check project ID
        final projectId = config.getConfig<String>('projectId');
        if (projectId == null || projectId.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'gcp',
            issue: 'GCP project ID not configured',
            solution: 'Set GCP project ID in configuration',
            severity: ValidationSeverity.high,
          ));
        }
        
        // Check enabled APIs
        final enabledApis = config.getConfig<List<dynamic>>('enabledApis');
        if (enabledApis == null || enabledApis.isEmpty) {
          issues.add(ConfigurationIssue(
            service: 'gcp',
            issue: 'No GCP APIs enabled',
            solution: 'Enable required GCP APIs in configuration',
            severity: ValidationSeverity.medium,
          ));
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'gcp',
        issue: 'Failed to validate GCP configuration: $e',
        solution: 'Check GCP configuration setup',
        severity: ValidationSeverity.high,
      ));
    }
    
    return ValidationResult(
      ruleName: 'gcp_service_account',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'GCP service account configuration is valid' : 'GCP service account configuration has issues',
      issues: issues,
    );
  }
  
  /// Validate network connectivity
  Future<ValidationResult> _validateNetworkConnectivity() async {
    final issues = <ConfigurationIssue>[];
    
    try {
      // Test basic internet connectivity
      final client = http.Client();
      
      try {
        final response = await client.get(
          Uri.parse('https://www.google.com'),
          headers: {'User-Agent': 'NutriSync-ConfigValidator/1.0'},
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode != 200) {
          issues.add(ConfigurationIssue(
            service: 'network',
            issue: 'Internet connectivity test failed',
            solution: 'Check internet connection and network settings',
            severity: ValidationSeverity.medium,
          ));
        }
      } catch (e) {
        issues.add(ConfigurationIssue(
          service: 'network',
          issue: 'Network connectivity test failed: $e',
          solution: 'Check internet connection, firewall, and proxy settings',
          severity: ValidationSeverity.medium,
        ));
      } finally {
        client.close();
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'network',
        issue: 'Failed to test network connectivity: $e',
        solution: 'Check network configuration',
        severity: ValidationSeverity.medium,
      ));
    }
    
    return ValidationResult(
      ruleName: 'network_connectivity',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'Network connectivity is valid' : 'Network connectivity has issues',
      issues: issues,
    );
  }
  
  /// Validate CORS configuration (Web only)
  Future<ValidationResult> _validateCorsConfig() async {
    final issues = <ConfigurationIssue>[];
    
    if (!kIsWeb) {
      return ValidationResult(
        ruleName: 'cors_config',
        isValid: true,
        message: 'CORS validation skipped (not web platform)',
        issues: [],
      );
    }
    
    try {
      // Check if CORS is properly configured for API services
      final apiManager = ApiConfigurationManager.instance;
      final configs = apiManager.getAllConfigs();
      
      for (final config in configs.values) {
        if (config.serviceName == 'googlemaps' || config.serviceName == 'googleplaces') {
          final corsEnabled = config.getConfig<bool>('corsEnabled', defaultValue: false);
          if (!corsEnabled!) {
            issues.add(ConfigurationIssue(
              service: config.serviceName,
              issue: 'CORS not enabled for ${config.serviceName}',
              solution: 'Enable CORS handling or use proxy service for web deployment',
              severity: ValidationSeverity.medium,
            ));
          }
        }
      }
    } catch (e) {
      issues.add(ConfigurationIssue(
        service: 'cors',
        issue: 'Failed to validate CORS configuration: $e',
        solution: 'Check CORS configuration for web deployment',
        severity: ValidationSeverity.medium,
      ));
    }
    
    return ValidationResult(
      ruleName: 'cors_config',
      isValid: issues.isEmpty,
      message: issues.isEmpty ? 'CORS configuration is valid' : 'CORS configuration has issues',
      issues: issues,
    );
  }
  
  /// Clear validation cache
  void clearCache() {
    _cachedResults.clear();
    _lastValidationTime = null;
  }
  
  /// Add custom validation rule
  void addValidationRule(ValidationRule rule) {
    _validationRules.add(rule);
  }
  
  /// Remove validation rule
  void removeValidationRule(String ruleName) {
    _validationRules.removeWhere((rule) => rule.name == ruleName);
  }
}

/// Validation Rule Definition
class ValidationRule {
  final String name;
  final String description;
  final Future<ValidationResult> Function() validator;
  final ValidationSeverity severity;
  
  const ValidationRule({
    required this.name,
    required this.description,
    required this.validator,
    required this.severity,
  });
}

/// Validation Result
class ValidationResult {
  final String ruleName;
  final bool isValid;
  final String message;
  final List<ConfigurationIssue> issues;
  final Map<String, dynamic> diagnostics;
  
  const ValidationResult({
    required this.ruleName,
    required this.isValid,
    required this.message,
    required this.issues,
    this.diagnostics = const {},
  });
}

/// Validation Summary
class ValidationSummary {
  final bool isValid;
  final List<ValidationResult> results;
  final List<ConfigurationIssue> issues;
  final DateTime validationTime;
  final String environment;
  
  const ValidationSummary({
    required this.isValid,
    required this.results,
    required this.issues,
    required this.validationTime,
    required this.environment,
  });
  
  /// Get issues by severity
  List<ConfigurationIssue> getIssuesBySeverity(ValidationSeverity severity) {
    return issues.where((issue) => issue.severity == severity).toList();
  }
  
  /// Get critical issues
  List<ConfigurationIssue> get criticalIssues => getIssuesBySeverity(ValidationSeverity.critical);
  
  /// Get high priority issues
  List<ConfigurationIssue> get highIssues => getIssuesBySeverity(ValidationSeverity.high);
  
  /// Get medium priority issues
  List<ConfigurationIssue> get mediumIssues => getIssuesBySeverity(ValidationSeverity.medium);
  
  /// Get low priority issues
  List<ConfigurationIssue> get lowIssues => getIssuesBySeverity(ValidationSeverity.low);
  
  /// Check if system is ready for production
  bool get isProductionReady => criticalIssues.isEmpty && highIssues.isEmpty;
}

/// Configuration Issue
class ConfigurationIssue {
  final String service;
  final String issue;
  final String solution;
  final ValidationSeverity severity;
  
  const ConfigurationIssue({
    required this.service,
    required this.issue,
    required this.solution,
    required this.severity,
  });
  
  @override
  String toString() {
    return '${severity.name.toUpperCase()}: [$service] $issue - $solution';
  }
}

/// Validation Severity Levels
enum ValidationSeverity {
  critical,
  high,
  medium,
  low,
}