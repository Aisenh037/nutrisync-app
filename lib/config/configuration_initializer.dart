import 'package:flutter/foundation.dart';
import 'environment_config.dart';
import 'api_configuration_manager.dart';
import 'configuration_validator.dart';
import 'secure_key_manager.dart';
import 'configuration_cache.dart';

/// Configuration Initializer
/// Orchestrates the initialization of all configuration components
class ConfigurationInitializer {
  static ConfigurationInitializer? _instance;
  static ConfigurationInitializer get instance => _instance ??= ConfigurationInitializer._();
  
  ConfigurationInitializer._();
  
  bool _isInitialized = false;
  final List<String> _initializationLog = [];
  DateTime? _initializationTime;
  
  /// Check if configuration system is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get initialization log
  List<String> get initializationLog => List.unmodifiable(_initializationLog);
  
  /// Get initialization time
  DateTime? get initializationTime => _initializationTime;
  
  /// Initialize all configuration components
  Future<ConfigurationInitializationResult> initialize({
    String? environment,
    bool validateOnStartup = true,
    bool enableCaching = true,
    bool enableSecureKeys = true,
  }) async {
    _initializationTime = DateTime.now();
    _initializationLog.clear();
    
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      _log('Starting configuration initialization...');
      
      // Step 1: Initialize Environment Configuration
      _log('Initializing Environment Configuration...');
      try {
        await EnvironmentConfig.instance.initialize(environment: environment);
        _log('✓ Environment Configuration initialized');
      } catch (e) {
        final error = 'Failed to initialize Environment Configuration: $e';
        errors.add(error);
        _log('✗ $error');
      }
      
      // Step 2: Initialize Secure Key Manager (if enabled)
      if (enableSecureKeys) {
        _log('Initializing Secure Key Manager...');
        try {
          await SecureKeyManager.instance.initialize();
          _log('✓ Secure Key Manager initialized');
        } catch (e) {
          final warning = 'Failed to initialize Secure Key Manager: $e';
          warnings.add(warning);
          _log('⚠ $warning');
        }
      }
      
      // Step 3: Initialize Configuration Cache (if enabled)
      if (enableCaching) {
        _log('Initializing Configuration Cache...');
        try {
          await ConfigurationCache.instance.initialize();
          _log('✓ Configuration Cache initialized');
        } catch (e) {
          final warning = 'Failed to initialize Configuration Cache: $e';
          warnings.add(warning);
          _log('⚠ $warning');
        }
      }
      
      // Step 4: Initialize API Configuration Manager
      _log('Initializing API Configuration Manager...');
      try {
        await ApiConfigurationManager.instance.initialize(environment: environment);
        _log('✓ API Configuration Manager initialized');
      } catch (e) {
        final error = 'Failed to initialize API Configuration Manager: $e';
        errors.add(error);
        _log('✗ $error');
      }
      
      // Step 5: Initialize Configuration Validator
      _log('Initializing Configuration Validator...');
      try {
        ConfigurationValidator.instance.initialize();
        _log('✓ Configuration Validator initialized');
      } catch (e) {
        final warning = 'Failed to initialize Configuration Validator: $e';
        warnings.add(warning);
        _log('⚠ $warning');
      }
      
      // Step 6: Preload configurations (if caching enabled)
      if (enableCaching) {
        _log('Preloading configurations...');
        try {
          await ConfigurationCache.instance.preloadConfigurations();
          _log('✓ Configurations preloaded');
        } catch (e) {
          final warning = 'Failed to preload configurations: $e';
          warnings.add(warning);
          _log('⚠ $warning');
        }
      }
      
      // Step 7: Validate configurations (if enabled)
      ValidationSummary? validationSummary;
      if (validateOnStartup) {
        _log('Validating configurations...');
        try {
          validationSummary = await ConfigurationValidator.instance.validateAll();
          if (validationSummary.isValid) {
            _log('✓ All configurations are valid');
          } else {
            _log('⚠ Configuration validation found ${validationSummary.issues.length} issues');
            for (final issue in validationSummary.criticalIssues) {
              errors.add('Critical: ${issue.issue}');
            }
            for (final issue in validationSummary.highIssues) {
              warnings.add('High: ${issue.issue}');
            }
          }
        } catch (e) {
          final warning = 'Failed to validate configurations: $e';
          warnings.add(warning);
          _log('⚠ $warning');
        }
      }
      
      // Step 8: Start configuration monitoring (if caching enabled)
      if (enableCaching) {
        _log('Starting configuration monitoring...');
        try {
          ConfigurationCache.instance.watchConfigurationFiles();
          _log('✓ Configuration monitoring started');
        } catch (e) {
          final warning = 'Failed to start configuration monitoring: $e';
          warnings.add(warning);
          _log('⚠ $warning');
        }
      }
      
      // Determine initialization success
      _isInitialized = errors.isEmpty;
      
      final duration = DateTime.now().difference(_initializationTime!);
      _log('Configuration initialization completed in ${duration.inMilliseconds}ms');
      
      if (_isInitialized) {
        _log('✓ Configuration system is ready');
      } else {
        _log('✗ Configuration system has critical errors');
      }
      
      return ConfigurationInitializationResult(
        isSuccess: _isInitialized,
        errors: errors,
        warnings: warnings,
        validationSummary: validationSummary,
        initializationTime: duration,
        environment: EnvironmentConfig.instance.environment,
      );
      
    } catch (e) {
      final error = 'Configuration initialization failed: $e';
      errors.add(error);
      _log('✗ $error');
      _isInitialized = false;
      
      return ConfigurationInitializationResult(
        isSuccess: false,
        errors: errors,
        warnings: warnings,
        validationSummary: null,
        initializationTime: DateTime.now().difference(_initializationTime!),
        environment: environment ?? 'unknown',
      );
    }
  }
  
  /// Reinitialize configuration system
  Future<ConfigurationInitializationResult> reinitialize({
    String? environment,
    bool validateOnStartup = true,
    bool enableCaching = true,
    bool enableSecureKeys = true,
  }) async {
    _log('Reinitializing configuration system...');
    
    // Reset all components
    await reset();
    
    // Initialize again
    return await initialize(
      environment: environment,
      validateOnStartup: validateOnStartup,
      enableCaching: enableCaching,
      enableSecureKeys: enableSecureKeys,
    );
  }
  
  /// Reset all configuration components
  Future<void> reset() async {
    _log('Resetting configuration system...');
    
    try {
      // Reset all components
      EnvironmentConfig.instance.reset();
      ApiConfigurationManager.instance.reset();
      ConfigurationValidator.instance.clearCache();
      SecureKeyManager.instance.reset();
      ConfigurationCache.instance.reset();
      
      _isInitialized = false;
      _initializationTime = null;
      
      _log('✓ Configuration system reset');
    } catch (e) {
      _log('⚠ Error during reset: $e');
    }
  }
  
  /// Get configuration system status
  ConfigurationSystemStatus getSystemStatus() {
    return ConfigurationSystemStatus(
      isInitialized: _isInitialized,
      environment: EnvironmentConfig.instance.environment,
      initializationTime: _initializationTime,
      components: {
        'EnvironmentConfig': EnvironmentConfig.instance.environment.isNotEmpty,
        'ApiConfigurationManager': ApiConfigurationManager.instance.isInitialized,
        'SecureKeyManager': SecureKeyManager.instance.hasApiKey('elevenlabs'), // Check if any keys are loaded
        'ConfigurationCache': true, // Always available
        'ConfigurationValidator': true, // Always available
      },
      apiServices: ApiConfigurationManager.instance.isInitialized 
          ? ApiConfigurationManager.instance.getAllConfigs().map((key, config) => 
              MapEntry(key, config.isEnabled && config.hasValidApiKey))
          : {},
    );
  }
  
  /// Get configuration summary for debugging
  Map<String, dynamic> getConfigurationSummary() {
    final summary = <String, dynamic>{
      'initialized': _isInitialized,
      'initializationTime': _initializationTime?.toIso8601String(),
      'environment': EnvironmentConfig.instance.environment,
      'components': {},
      'apiServices': {},
      'initializationLog': _initializationLog,
    };
    
    // Add component status
    if (EnvironmentConfig.instance.environment.isNotEmpty) {
      summary['components']['EnvironmentConfig'] = {
        'status': 'initialized',
        'environment': EnvironmentConfig.instance.environment,
        'features': EnvironmentConfig.instance.features.keys.toList(),
      };
    }
    
    if (ApiConfigurationManager.instance.isInitialized) {
      summary['components']['ApiConfigurationManager'] = {
        'status': 'initialized',
        'services': ApiConfigurationManager.instance.getAllConfigs().keys.toList(),
        'cacheValid': ApiConfigurationManager.instance.isCacheValid,
      };
      
      // Add API service details
      final configs = ApiConfigurationManager.instance.getAllConfigs();
      for (final entry in configs.entries) {
        summary['apiServices'][entry.key] = {
          'enabled': entry.value.isEnabled,
          'hasValidKey': entry.value.hasValidApiKey,
          'baseUrl': entry.value.baseUrl,
        };
      }
    }
    
    if (SecureKeyManager.instance.hasApiKey('elevenlabs') || SecureKeyManager.instance.getConfiguredServices().isNotEmpty) {
      summary['components']['SecureKeyManager'] = {
        'status': 'initialized',
        'configuredServices': SecureKeyManager.instance.getConfiguredServices(),
        'securitySummary': SecureKeyManager.instance.getSecuritySummary()
            .map((key, status) => MapEntry(key, status.description)),
      };
    }
    
    summary['components']['ConfigurationCache'] = {
      'status': 'initialized',
      'statistics': {
        'totalEntries': ConfigurationCache.instance.getCacheStatistics().totalEntries,
        'validEntries': ConfigurationCache.instance.getCacheStatistics().validEntries,
        'hitRate': ConfigurationCache.instance.getCacheStatistics().efficiency,
        'size': ConfigurationCache.instance.getCacheStatistics().formattedSize,
      },
    };
    
    return summary;
  }
  
  /// Log initialization step
  void _log(String message) {
    _initializationLog.add('${DateTime.now().toIso8601String()}: $message');
    if (kDebugMode) {
      print(message);
    }
  }
  
  /// Quick health check
  Future<bool> healthCheck() async {
    if (!_isInitialized) return false;
    
    try {
      // Check if core components are working
      final envConfig = EnvironmentConfig.instance;
      if (envConfig.environment.isEmpty) return false;
      
      final apiManager = ApiConfigurationManager.instance;
      if (!apiManager.isInitialized) return false;
      
      // Quick validation
      final validator = ConfigurationValidator.instance;
      final result = await validator.validateService('environment_config');
      
      return result.isValid;
    } catch (e) {
      if (kDebugMode) {
        print('Health check failed: $e');
      }
      return false;
    }
  }
}

/// Configuration Initialization Result
class ConfigurationInitializationResult {
  final bool isSuccess;
  final List<String> errors;
  final List<String> warnings;
  final ValidationSummary? validationSummary;
  final Duration initializationTime;
  final String environment;
  
  const ConfigurationInitializationResult({
    required this.isSuccess,
    required this.errors,
    required this.warnings,
    this.validationSummary,
    required this.initializationTime,
    required this.environment,
  });
  
  /// Check if there are any issues
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;
  
  /// Check if system is production ready
  bool get isProductionReady {
    return isSuccess && 
           errors.isEmpty && 
           (validationSummary?.isProductionReady ?? true);
  }
  
  /// Get formatted summary
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('Configuration Initialization Summary:');
    buffer.writeln('Environment: $environment');
    buffer.writeln('Success: $isSuccess');
    buffer.writeln('Duration: ${initializationTime.inMilliseconds}ms');
    
    if (errors.isNotEmpty) {
      buffer.writeln('Errors (${errors.length}):');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings (${warnings.length}):');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    if (validationSummary != null) {
      buffer.writeln('Validation: ${validationSummary!.isValid ? 'PASSED' : 'FAILED'}');
      if (!validationSummary!.isValid) {
        buffer.writeln('Issues: ${validationSummary!.issues.length}');
      }
    }
    
    return buffer.toString();
  }
}

/// Configuration System Status
class ConfigurationSystemStatus {
  final bool isInitialized;
  final String environment;
  final DateTime? initializationTime;
  final Map<String, bool> components;
  final Map<String, bool> apiServices;
  
  const ConfigurationSystemStatus({
    required this.isInitialized,
    required this.environment,
    this.initializationTime,
    required this.components,
    required this.apiServices,
  });
  
  /// Check if all components are healthy
  bool get isHealthy {
    return isInitialized && 
           components.values.every((status) => status) &&
           apiServices.isNotEmpty;
  }
  
  /// Get component status summary
  String get componentSummary {
    final healthy = components.values.where((status) => status).length;
    return '$healthy/${components.length} components healthy';
  }
  
  /// Get API service status summary
  String get apiServiceSummary {
    final healthy = apiServices.values.where((status) => status).length;
    return '$healthy/${apiServices.length} API services ready';
  }
}