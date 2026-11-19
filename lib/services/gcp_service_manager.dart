import 'package:flutter/foundation.dart';
import '../config/gcp_config.dart';
import '../config/environment_config.dart';
import 'gcp_service_account_manager.dart';
import 'gcp_auth_service.dart';
import 'gcp_error_handler.dart';

/// GCP Service Manager
/// Orchestrates all GCP services and provides unified error handling and status reporting
class GcpServiceManager {
  static GcpServiceManager? _instance;
  static GcpServiceManager get instance => _instance ??= GcpServiceManager._();
  
  GcpServiceManager._();
  
  bool _isInitialized = false;
  List<String> _initializationErrors = [];
  
  /// Initialize all GCP services
  Future<void> initialize() async {
    _initializationErrors.clear();
    
    try {
      if (kDebugMode) {
        print('🚀 Initializing GCP Service Manager...');
      }
      
      // Initialize in order: Config -> Service Account -> Auth
      await _initializeGcpConfig();
      await _initializeServiceAccount();
      await _initializeAuthentication();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ GCP Service Manager initialized successfully');
        await _printServiceStatus();
      }
    } catch (e) {
      _initializationErrors.add('GCP Service Manager initialization failed: $e');
      
      if (kDebugMode) {
        print('❌ GCP Service Manager initialization failed: $e');
        await _printErrorDiagnostics();
      }
      
      // Don't rethrow - allow graceful degradation
      _isInitialized = false;
    }
  }
  
  /// Initialize GCP configuration
  Future<void> _initializeGcpConfig() async {
    try {
      await GCPConfig.instance.initialize();
      
      if (kDebugMode) {
        print('✓ GCP Configuration initialized');
      }
    } catch (e) {
      _initializationErrors.add('GCP Config initialization failed: $e');
      
      if (kDebugMode) {
        print('⚠ GCP Config initialization failed: $e');
        print('  Using default configuration for graceful degradation');
      }
      
      // Continue with defaults - don't fail completely
    }
  }
  
  /// Initialize service account manager
  Future<void> _initializeServiceAccount() async {
    try {
      await GcpServiceAccountManager.instance.initialize();
      
      final status = GcpServiceAccountManager.instance.getStatus();
      if (!status.hasCredentials) {
        final error = 'No service account credentials found for environment: ${status.environment}';
        _initializationErrors.add(error);
        
        if (kDebugMode) {
          print('⚠ $error');
          _printServiceAccountSetupInstructions(status.environment ?? 'development');
        }
      } else {
        if (kDebugMode) {
          print('✓ Service Account Manager initialized');
          print('  Project: ${status.projectId}');
          print('  Service Account: ${status.clientEmail}');
        }
      }
    } catch (e) {
      _initializationErrors.add('Service Account Manager initialization failed: $e');
      
      if (kDebugMode) {
        print('⚠ Service Account Manager initialization failed: $e');
      }
    }
  }
  
  /// Initialize authentication service
  Future<void> _initializeAuthentication() async {
    try {
      await GCPAuthService.instance.initialize();
      
      final authStatus = GCPAuthService.instance.getAuthStatus();
      if (!authStatus.isHealthy && !kDebugMode) {
        _initializationErrors.add('GCP Authentication is not healthy');
      }
      
      if (kDebugMode) {
        print('✓ GCP Auth Service initialized');
        print('  Status: ${authStatus.isHealthy ? 'Healthy' : 'Issues detected'}');
      }
    } catch (e) {
      _initializationErrors.add('GCP Auth Service initialization failed: $e');
      
      if (kDebugMode) {
        print('⚠ GCP Auth Service initialization failed: $e');
      }
    }
  }
  
  /// Get comprehensive service status
  Future<GcpServiceStatus> getServiceStatus() async {
    final configStatus = GCPConfig.instance.getStatus();
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    final authStatus = GCPAuthService.instance.getAuthStatus();
    final diagnostics = await GcpErrorHandler.instance.getDiagnosticInfo();
    
    return GcpServiceStatus(
      isInitialized: _isInitialized,
      configStatus: configStatus,
      serviceAccountStatus: serviceAccountStatus,
      authStatus: authStatus,
      diagnostics: diagnostics,
      initializationErrors: List.from(_initializationErrors),
      overallHealth: _calculateOverallHealth(configStatus, serviceAccountStatus, authStatus),
    );
  }
  
  /// Calculate overall health status
  ServiceHealth _calculateOverallHealth(
    GcpConfigStatus configStatus,
    ServiceAccountStatus serviceAccountStatus,
    GcpAuthStatus authStatus,
  ) {
    if (!_isInitialized) {
      return ServiceHealth.critical;
    }
    
    if (_initializationErrors.isNotEmpty) {
      // Check if errors are critical
      final hasCriticalErrors = _initializationErrors.any((error) =>
          error.contains('Service Account') || error.contains('Authentication'));
      
      if (hasCriticalErrors && !kDebugMode) {
        return ServiceHealth.critical;
      } else {
        return ServiceHealth.degraded;
      }
    }
    
    if (configStatus.isHealthy && serviceAccountStatus.isHealthy && authStatus.isHealthy) {
      return ServiceHealth.healthy;
    } else if (serviceAccountStatus.hasCredentials || kDebugMode) {
      return ServiceHealth.degraded;
    } else {
      return ServiceHealth.critical;
    }
  }
  
  /// Check if GCP services are ready for use
  bool get isReady {
    return _isInitialized && (
        GcpServiceAccountManager.instance.hasServiceAccount || 
        kDebugMode // Allow development mode without service account
    );
  }
  
  /// Get user-friendly status message
  String getStatusMessage() {
    if (!_isInitialized) {
      return 'GCP services are initializing...';
    }
    
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    final authStatus = GCPAuthService.instance.getAuthStatus();
    
    if (!serviceAccountStatus.hasCredentials) {
      if (kDebugMode) {
        return 'GCP services running in development mode (no service account)';
      } else {
        return 'GCP services not configured. Service account credentials required.';
      }
    }
    
    if (!authStatus.isHealthy) {
      return 'GCP authentication issues detected. Some features may not work.';
    }
    
    return 'GCP services are ready and operational.';
  }
  
  /// Get setup instructions for missing configuration
  String getSetupInstructions() {
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    
    if (!serviceAccountStatus.hasCredentials) {
      return '''
# GCP Setup Required

To enable Google Cloud features in NutriSync:

1. **Create a Google Cloud Project**
   - Go to https://console.cloud.google.com/
   - Create a new project or select an existing one
   - Note your Project ID

2. **Create a Service Account**
   - Go to IAM & Admin > Service Accounts
   - Click "Create Service Account"
   - Name: nutrisync-ai-service
   - Grant required roles (see documentation)

3. **Download Service Account Key**
   - Click on the service account
   - Go to "Keys" tab
   - Create new JSON key
   - Download the file

4. **Add Key to App**
   - Place file at: assets/config/gcp/service-account-${serviceAccountStatus.environment ?? 'development'}.json
   - Or set environment variables (see docs)

5. **Enable Required APIs**
   - Cloud Speech-to-Text API
   - Cloud Text-to-Speech API
   - Cloud Vision API
   - Cloud Translation API
   - Dialogflow API

For detailed instructions: docs/GCP_SETUP_GUIDE.md
''';
    }
    
    return 'GCP services are configured. No additional setup required.';
  }
  
  /// Handle service account switching between environments
  Future<void> switchEnvironment(String environment) async {
    try {
      if (kDebugMode) {
        print('🔄 Switching GCP environment to: $environment');
      }
      
      final currentEnv = GcpServiceAccountManager.instance.getStatus().environment;
      
      // Update environment configuration
      await _updateEnvironmentConfiguration(environment);
      
      // Switch service account
      await GcpServiceAccountManager.instance.switchEnvironment(environment);
      
      // Re-initialize authentication with new service account
      GCPAuthService.instance.clearAuth();
      await GCPAuthService.instance.initialize();
      
      // Validate the new environment
      final validationResult = await validateServices();
      
      if (validationResult.canProceed) {
        if (kDebugMode) {
          print('✅ Successfully switched to environment: $environment');
          await _printEnvironmentSwitchStatus(currentEnv, environment);
        }
      } else {
        if (kDebugMode) {
          print('⚠ Environment switch completed with issues:');
          for (final issue in validationResult.issues) {
            print('   • $issue');
          }
        }
      }
    } catch (e) {
      final errorResult = GcpErrorHandler.instance.handleEnvironmentSwitchError(
        GcpServiceAccountManager.instance.getStatus().environment ?? 'unknown',
        environment,
        e.toString(),
      );
      
      if (kDebugMode) {
        print('❌ Failed to switch environment: ${errorResult.message}');
        print('   ${errorResult.setupInstructions}');
      }
      
      rethrow;
    }
  }
  
  /// Update environment configuration for switching
  Future<void> _updateEnvironmentConfiguration(String environment) async {
    try {
      // Reinitialize environment config for new environment
      await EnvironmentConfig.instance.initialize(environment: environment);
      
      // Reinitialize GCP config with new environment
      GCPConfig.instance.reset();
      await GCPConfig.instance.initialize();
      
      if (kDebugMode) {
        print('✓ Environment configuration updated for: $environment');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to update environment configuration: $e');
      }
      // Continue with existing configuration
    }
  }
  
  /// Get available environments
  List<String> getAvailableEnvironments() {
    return ['development', 'staging', 'production'];
  }
  
  /// Check if environment switching is supported
  bool get supportsEnvironmentSwitching => true;
  
  /// Get current environment information
  EnvironmentInfo getCurrentEnvironment() {
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    final configStatus = GCPConfig.instance.getStatus();
    final authStatus = GCPAuthService.instance.getAuthStatus();
    
    return EnvironmentInfo(
      name: serviceAccountStatus.environment ?? 'unknown',
      projectId: configStatus.projectId,
      region: configStatus.region,
      hasServiceAccount: serviceAccountStatus.hasCredentials,
      isAuthenticated: authStatus.hasValidToken,
      enabledApis: configStatus.enabledApis,
      isHealthy: serviceAccountStatus.isHealthy && authStatus.isHealthy,
    );
  }
  
  /// Switch to development environment
  Future<void> switchToDevelopment() async {
    await switchEnvironment('development');
  }
  
  /// Switch to staging environment
  Future<void> switchToStaging() async {
    await switchEnvironment('staging');
  }
  
  /// Switch to production environment
  Future<void> switchToProduction() async {
    await switchEnvironment('production');
  }
  
  /// Automatic environment detection and switching
  Future<void> autoDetectAndSwitchEnvironment() async {
    try {
      // Try to detect environment from various sources
      String? detectedEnv;
      
      // 1. Check environment variable
      const envVar = String.fromEnvironment('ENVIRONMENT');
      if (envVar.isNotEmpty) {
        detectedEnv = envVar;
      }
      
      // 2. Check build configuration
      if (detectedEnv == null) {
        if (kDebugMode) {
          detectedEnv = 'development';
        } else if (kReleaseMode) {
          detectedEnv = 'production';
        } else {
          detectedEnv = 'staging';
        }
      }
      
      // 3. Validate detected environment
      if (detectedEnv != null && getAvailableEnvironments().contains(detectedEnv)) {
        final currentEnv = getCurrentEnvironment().name;
        
        if (currentEnv != detectedEnv) {
          if (kDebugMode) {
            print('🔍 Auto-detected environment: $detectedEnv (current: $currentEnv)');
          }
          
          await switchEnvironment(detectedEnv);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Auto environment detection failed: $e');
      }
      // Continue with current environment
    }
  }
  
  /// Validate all GCP services and permissions
  Future<ValidationResult> validateServices() async {
    final issues = <String>[];
    final warnings = <String>[];
    
    try {
      // Validate configuration
      final configStatus = GCPConfig.instance.getStatus();
      if (!configStatus.isValid) {
        issues.add('GCP configuration is invalid');
      }
      
      // Validate service account
      final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
      if (!serviceAccountStatus.hasCredentials) {
        if (kDebugMode) {
          warnings.add('No service account configured (development mode)');
        } else {
          issues.add('Service account credentials not found');
        }
      } else if (!serviceAccountStatus.isValid) {
        issues.add('Service account credentials are invalid');
      }
      
      // Validate authentication
      final authStatus = GCPAuthService.instance.getAuthStatus();
      if (!authStatus.hasValidToken && serviceAccountStatus.hasCredentials) {
        warnings.add('Access token needs refresh');
      }
      
      // Test permissions (if service account is available)
      if (serviceAccountStatus.hasCredentials) {
        try {
          final hasPermissions = await GCPAuthService.instance.validatePermissions();
          if (!hasPermissions) {
            warnings.add('Service account may not have all required permissions');
          }
        } catch (e) {
          warnings.add('Could not validate service account permissions: $e');
        }
      }
      
      return ValidationResult(
        isValid: issues.isEmpty,
        issues: issues,
        warnings: warnings,
        canProceed: issues.isEmpty || kDebugMode,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        issues: ['Validation failed: $e'],
        warnings: warnings,
        canProceed: kDebugMode,
      );
    }
  }
  
  /// Print service status (debug only)
  Future<void> _printServiceStatus() async {
    if (!kDebugMode) return;
    
    print('\n📊 GCP Service Status:');
    print('  Overall Health: ${(await getServiceStatus()).overallHealth.name}');
    print('  Status Message: ${getStatusMessage()}');
    
    final configStatus = GCPConfig.instance.getStatus();
    print('  Configuration: ${configStatus.isHealthy ? '✅' : '⚠️'} ${configStatus.projectId}');
    
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    print('  Service Account: ${serviceAccountStatus.isHealthy ? '✅' : '⚠️'} ${serviceAccountStatus.clientEmail ?? 'Not configured'}');
    
    final authStatus = GCPAuthService.instance.getAuthStatus();
    print('  Authentication: ${authStatus.isHealthy ? '✅' : '⚠️'} ${authStatus.hasValidToken ? 'Token valid' : 'No token'}');
    
    if (_initializationErrors.isNotEmpty) {
      print('  Errors: ${_initializationErrors.length}');
      for (final error in _initializationErrors) {
        print('    • $error');
      }
    }
    print('');
  }
  
  /// Print error diagnostics (debug only)
  Future<void> _printErrorDiagnostics() async {
    if (!kDebugMode) return;
    
    final diagnostics = await GcpErrorHandler.instance.getDiagnosticInfo();
    
    print('\n🔍 GCP Error Diagnostics:');
    print('  Overall Health: ${diagnostics.overallHealth.name}');
    
    if (diagnostics.issues.isNotEmpty) {
      print('  Issues Found:');
      for (final issue in diagnostics.issues) {
        print('    • ${issue.title}: ${issue.message}');
        if (issue.suggestedActions.isNotEmpty) {
          print('      Actions: ${issue.suggestedActions.first}');
        }
      }
    }
    
    if (diagnostics.recommendations.isNotEmpty) {
      print('  Recommendations:');
      for (final recommendation in diagnostics.recommendations) {
        print('    • $recommendation');
      }
    }
    print('');
  }
  
  /// Print environment switch status (debug only)
  Future<void> _printEnvironmentSwitchStatus(String? fromEnv, String toEnv) async {
    if (!kDebugMode) return;
    
    print('\n🔄 Environment Switch Summary:');
    print('  From: ${fromEnv ?? 'unknown'} → To: $toEnv');
    
    final currentEnv = getCurrentEnvironment();
    print('  Project ID: ${currentEnv.projectId}');
    print('  Region: ${currentEnv.region}');
    print('  Service Account: ${currentEnv.hasServiceAccount ? '✅' : '❌'}');
    print('  Authentication: ${currentEnv.isAuthenticated ? '✅' : '❌'}');
    print('  Enabled APIs: ${currentEnv.enabledApis.length}');
    print('  Overall Health: ${currentEnv.isHealthy ? '✅ Healthy' : '⚠ Issues detected'}');
    print('');
  }
  
  /// Print service account setup instructions (debug only)
  void _printServiceAccountSetupInstructions(String environment) {
    if (!kDebugMode) return;
    
    print('''
📋 Service Account Setup Instructions for $environment:

1. Create service account in Google Cloud Console
2. Download JSON key file
3. Place at: assets/config/gcp/service-account-$environment.json
4. Or set environment variables (see docs/GCP_SETUP_GUIDE.md)

Required APIs to enable:
• Cloud Speech-to-Text API
• Cloud Text-to-Speech API  
• Cloud Vision API
• Cloud Translation API
• Dialogflow API

The app will continue in development mode without these services.
''');
  }
  
  /// Reset all services (for testing)
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _initializationErrors.clear();
    GCPConfig.instance.reset();
    GcpServiceAccountManager.instance.reset();
    GCPAuthService.instance.reset();
  }
}

/// GCP Service Status
class GcpServiceStatus {
  final bool isInitialized;
  final GcpConfigStatus configStatus;
  final ServiceAccountStatus serviceAccountStatus;
  final GcpAuthStatus authStatus;
  final GcpDiagnosticInfo diagnostics;
  final List<String> initializationErrors;
  final ServiceHealth overallHealth;
  
  const GcpServiceStatus({
    required this.isInitialized,
    required this.configStatus,
    required this.serviceAccountStatus,
    required this.authStatus,
    required this.diagnostics,
    required this.initializationErrors,
    required this.overallHealth,
  });
  
  bool get isHealthy => overallHealth == ServiceHealth.healthy;
  bool get canProceed => isInitialized && (serviceAccountStatus.hasCredentials || kDebugMode);
  
  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'configStatus': configStatus.toJson(),
      'serviceAccountStatus': serviceAccountStatus.toJson(),
      'authStatus': authStatus.toJson(),
      'diagnostics': diagnostics.toJson(),
      'initializationErrors': initializationErrors,
      'overallHealth': overallHealth.name,
      'isHealthy': isHealthy,
      'canProceed': canProceed,
    };
  }
}

/// Validation Result
class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final bool canProceed;
  
  const ValidationResult({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.canProceed,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'issues': issues,
      'warnings': warnings,
      'canProceed': canProceed,
    };
  }
}

/// Service Health Levels
enum ServiceHealth {
  healthy,
  degraded,
  critical,
}

/// Environment Information
class EnvironmentInfo {
  final String name;
  final String projectId;
  final String region;
  final bool hasServiceAccount;
  final bool isAuthenticated;
  final List<String> enabledApis;
  final bool isHealthy;
  
  const EnvironmentInfo({
    required this.name,
    required this.projectId,
    required this.region,
    required this.hasServiceAccount,
    required this.isAuthenticated,
    required this.enabledApis,
    required this.isHealthy,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'projectId': projectId,
      'region': region,
      'hasServiceAccount': hasServiceAccount,
      'isAuthenticated': isAuthenticated,
      'enabledApis': enabledApis,
      'isHealthy': isHealthy,
    };
  }
}