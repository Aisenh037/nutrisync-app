import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'environment_config.dart';
import 'firebase_config.dart';
import 'gcp_config.dart';
import 'configuration_initializer.dart';
import '../services/gcp_auth_service.dart';
import '../services/revenuecat_subscription_service.dart';

/// App initialization manager
/// Handles loading configurations and initializing services
class AppInitializer {
  static AppInitializer? _instance;
  static AppInitializer get instance => _instance ??= AppInitializer._();
  
  AppInitializer._();
  
  bool _isInitialized = false;
  
  /// Check if app is initialized
  bool get isInitialized => _isInitialized;
  
  /// Initialize the application with environment-specific configuration
  Future<void> initialize({String? environment}) async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠ App already initialized');
      }
      return;
    }
    
    try {
      if (kDebugMode) {
        print('🚀 Initializing NutriSync app...');
      }
      
      // Step 1: Initialize Configuration Management Infrastructure
      await _initializeConfigurationSystem(environment);
      
      // Step 2: Initialize Firebase
      await _initializeFirebase();
      
      // Step 3: Initialize GCP services
      await _initializeGCP();
      
      // Step 4: Set up system UI
      await _setupSystemUI();
      
      // Step 5: Initialize RevenueCat
      await _initializeRevenueCat();

      // Step 6: Initialize other services
      await _initializeServices();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ App initialization completed successfully');
        _printInitializationSummary();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ App initialization failed: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }
  
  /// Initialize configuration management system
  Future<void> _initializeConfigurationSystem(String? environment) async {
    if (kDebugMode) {
      print('⚙️ Initializing Configuration Management System...');
    }
    
    final result = await ConfigurationInitializer.instance.initialize(
      environment: environment,
      validateOnStartup: true,
      enableCaching: true,
      enableSecureKeys: true,
    );
    
    if (!result.isSuccess) {
      if (kDebugMode) {
        print('⚠️ Configuration system has issues:');
        for (final error in result.errors) {
          print('  ❌ $error');
        }
        for (final warning in result.warnings) {
          print('  ⚠️ $warning');
        }
      }
      
      // Don't fail if only warnings, but fail on critical errors
      if (result.errors.isNotEmpty) {
        throw Exception('Configuration system initialization failed: ${result.errors.join(', ')}');
      }
    }
    
    if (kDebugMode) {
      print('✅ Configuration Management System initialized in ${result.initializationTime.inMilliseconds}ms');
      if (result.warnings.isNotEmpty) {
        print('⚠️ ${result.warnings.length} warnings during configuration initialization');
      }
    }
  }
  
  /// Initialize Firebase services
  Future<void> _initializeFirebase() async {
    if (kDebugMode) {
      print('🔥 Initializing Firebase...');
    }
    
    await FirebaseConfig.instance.initialize();
  }
  
  /// Initialize RevenueCat
  Future<void> _initializeRevenueCat() async {
    if (kDebugMode) print('💳 Initializing RevenueCat...');
    try {
      await RevenueCatSubscriptionService.instance.configure();
      if (kDebugMode) print('✅ RevenueCat initialized');
    } catch (e) {
      // Non-fatal — app works in free tier if RevenueCat is unavailable.
      if (kDebugMode) print('⚠️ RevenueCat init failed (continuing): $e');
    }
  }

  /// Initialize GCP services
  Future<void> _initializeGCP() async {
    if (kDebugMode) {
      print('☁️ Initializing Google Cloud Platform services...');
    }
    
    try {
      await GCPConfig.instance.initialize();
      await GCPAuthService.instance.initialize();
      
      if (kDebugMode) {
        print('✅ GCP services initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ GCP initialization failed (continuing with limited functionality): $e');
      }
      // Don't fail the entire app if GCP services are unavailable
    }
  }
  
  /// Set up system UI preferences
  Future<void> _setupSystemUI() async {
    if (kDebugMode) {
      print('🎨 Setting up system UI...');
    }
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  
  /// Initialize other app services
  Future<void> _initializeServices() async {
    if (kDebugMode) {
      print('⚙️ Initializing app services...');
    }
    
    // Initialize any other services here
    // For example: analytics, crash reporting, etc.
    
    final config = EnvironmentConfig.instance;
    
    // Initialize analytics if enabled
    if (config.isAnalyticsEnabled) {
      if (kDebugMode) {
        print('📊 Analytics enabled for ${config.environment}');
      }
      // Initialize analytics service
    }
    
    // Initialize Crashlytics
    if (config.isCrashlyticsEnabled) {
      // Collection is already toggled in main.dart; here we set user context.
      await FirebaseCrashlytics.instance.setCustomKey(
        'environment', config.environment,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_version', config.app['version'] ?? 'unknown',
      );
      if (kDebugMode) {
        print('🐛 Crashlytics context set for ${config.environment}');
      }
    }
  }
  
  /// Print initialization summary
  void _printInitializationSummary() {
    final config = EnvironmentConfig.instance;
    final gcpConfig = GCPConfig.instance;
    final configStatus = ConfigurationInitializer.instance.getSystemStatus();
    
    print('');
    print('🎯 === NutriSync Initialization Summary ===');
    print('Environment: ${config.environment}');
    print('App Name: ${config.appName}');
    print('Firebase Project: ${config.firebaseProjectId}');
    print('GCP Project: ${gcpConfig.projectId}');
    print('GCP Region: ${gcpConfig.region}');
    print('API Base URL: ${config.apiBaseUrl}');
    print('Debug Mode: ${config.isDebugMode}');
    print('Analytics: ${config.isAnalyticsEnabled}');
    print('Crashlytics: ${config.isCrashlyticsEnabled}');
    print('Voice Features: ${config.isFeatureEnabled('enableVoiceFeatures')}');
    print('Premium Features: ${config.isFeatureEnabled('enablePremiumFeatures')}');
    print('GCP APIs Enabled: ${gcpConfig.enabledApis.join(', ')}');
    print('GCP Service Account: ${gcpConfig.hasServiceAccount ? 'Configured' : 'Not configured (using defaults)'}');
    print('');
    print('Configuration System Status:');
    print('  Components: ${configStatus.componentSummary}');
    print('  API Services: ${configStatus.apiServiceSummary}');
    print('  System Health: ${configStatus.isHealthy ? 'Healthy' : 'Issues detected'}');
    print('==========================================');
    print('');
  }
  
  /// Reset initialization state (for testing)
  void reset() {
    _isInitialized = false;
  }
}