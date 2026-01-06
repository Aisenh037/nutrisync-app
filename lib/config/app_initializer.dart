import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'environment_config.dart';
import 'firebase_config.dart';

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
      
      // Step 1: Load environment configuration
      await _initializeEnvironmentConfig(environment);
      
      // Step 2: Initialize Firebase
      await _initializeFirebase();
      
      // Step 3: Set up system UI
      await _setupSystemUI();
      
      // Step 4: Initialize other services
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
  
  /// Initialize environment configuration
  Future<void> _initializeEnvironmentConfig(String? environment) async {
    if (kDebugMode) {
      print('📋 Loading environment configuration...');
    }
    
    await EnvironmentConfig.instance.initialize(environment: environment);
  }
  
  /// Initialize Firebase services
  Future<void> _initializeFirebase() async {
    if (kDebugMode) {
      print('🔥 Initializing Firebase...');
    }
    
    await FirebaseConfig.instance.initialize();
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
    
    // Initialize crashlytics if enabled
    if (config.isCrashlyticsEnabled) {
      if (kDebugMode) {
        print('🐛 Crashlytics enabled for ${config.environment}');
      }
      // Initialize crashlytics service
    }
  }
  
  /// Print initialization summary
  void _printInitializationSummary() {
    final config = EnvironmentConfig.instance;
    
    print('');
    print('🎯 === NutriSync Initialization Summary ===');
    print('Environment: ${config.environment}');
    print('App Name: ${config.appName}');
    print('Firebase Project: ${config.firebaseProjectId}');
    print('API Base URL: ${config.apiBaseUrl}');
    print('Debug Mode: ${config.isDebugMode}');
    print('Analytics: ${config.isAnalyticsEnabled}');
    print('Crashlytics: ${config.isCrashlyticsEnabled}');
    print('Voice Features: ${config.isFeatureEnabled('enableVoiceFeatures')}');
    print('Premium Features: ${config.isFeatureEnabled('enablePremiumFeatures')}');
    print('==========================================');
    print('');
  }
  
  /// Reset initialization state (for testing)
  void reset() {
    _isInitialized = false;
  }
}