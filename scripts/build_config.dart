#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

/// Build configuration script for NutriSync
/// Generates environment-specific configuration files during build
void main(List<String> arguments) {
  final environment = arguments.isNotEmpty ? arguments[0] : 'development';
  
  print('🔧 Generating build configuration for: $environment');
  
  try {
    // Generate environment-specific configuration
    generateEnvironmentConfig(environment);
    
    // Generate Firebase configuration
    generateFirebaseConfig(environment);
    
    // Generate build info
    generateBuildInfo(environment);
    
    print('✅ Build configuration generated successfully');
  } catch (e) {
    print('❌ Failed to generate build configuration: $e');
    exit(1);
  }
}

/// Generate environment-specific configuration
void generateEnvironmentConfig(String environment) {
  print('📋 Generating environment config for: $environment');
  
  final configFile = File('assets/config/environments/$environment.json');
  
  if (!configFile.existsSync()) {
    print('⚠ Configuration file not found: ${configFile.path}');
    print('Using default configuration');
    return;
  }
  
  final config = json.decode(configFile.readAsStringSync());
  
  // Update build-time values
  config['app']['buildTime'] = DateTime.now().toIso8601String();
  config['app']['buildEnvironment'] = environment;
  
  // Write updated configuration
  configFile.writeAsStringSync(json.encode(config));
  
  print('✓ Environment config updated');
}

/// Generate Firebase configuration for web
void generateFirebaseConfig(String environment) {
  print('🔥 Generating Firebase config for web');
  
  final configFile = File('assets/config/environments/$environment.json');
  
  if (!configFile.existsSync()) {
    print('⚠ Environment config not found, skipping Firebase config');
    return;
  }
  
  final config = json.decode(configFile.readAsStringSync());
  final firebaseConfig = config['firebase'];
  
  final webConfigContent = '''
// Firebase configuration for $environment
const firebaseConfig = {
  apiKey: "${firebaseConfig['apiKey']}",
  authDomain: "${firebaseConfig['authDomain']}",
  projectId: "${firebaseConfig['projectId']}",
  storageBucket: "${firebaseConfig['storageBucket']}",
  messagingSenderId: "${firebaseConfig['messagingSenderId']}",
  appId: "${firebaseConfig['appId']}"
};

// Initialize Firebase
import { initializeApp } from 'firebase/app';
const app = initializeApp(firebaseConfig);

export default app;
''';
  
  final webConfigFile = File('web/firebase-config.js');
  webConfigFile.writeAsStringSync(webConfigContent);
  
  print('✓ Firebase web config generated');
}

/// Generate build information
void generateBuildInfo(String environment) {
  print('ℹ️ Generating build info');
  
  final buildInfo = {
    'environment': environment,
    'buildTime': DateTime.now().toIso8601String(),
    'buildNumber': Platform.environment['BUILD_NUMBER'] ?? '1',
    'gitCommit': _getGitCommit(),
    'gitBranch': _getGitBranch(),
  };
  
  final buildInfoFile = File('lib/config/build_info.dart');
  final buildInfoContent = '''
// Generated build information - DO NOT EDIT
class BuildInfo {
  static const String environment = '${buildInfo['environment']}';
  static const String buildTime = '${buildInfo['buildTime']}';
  static const String buildNumber = '${buildInfo['buildNumber']}';
  static const String gitCommit = '${buildInfo['gitCommit']}';
  static const String gitBranch = '${buildInfo['gitBranch']}';
}
''';
  
  buildInfoFile.writeAsStringSync(buildInfoContent);
  
  print('✓ Build info generated');
}

/// Get current git commit hash
String _getGitCommit() {
  try {
    final result = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
  } catch (e) {
    // Git not available or not in a git repository
  }
  return 'unknown';
}

/// Get current git branch
String _getGitBranch() {
  try {
    final result = Process.runSync('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
  } catch (e) {
    // Git not available or not in a git repository
  }
  return 'unknown';
}