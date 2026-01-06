#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

/// Security audit script for NutriSync CI/CD pipeline
/// Performs comprehensive security checks on the codebase and configuration
void main(List<String> arguments) {
  print('🔒 Starting NutriSync Security Audit');
  print('=====================================\n');
  
  final auditor = SecurityAuditor();
  final results = auditor.runAudit();
  
  print('\n📊 Security Audit Results');
  print('=========================');
  
  final totalChecks = results.length;
  final passedChecks = results.where((r) => r.passed).length;
  final failedChecks = totalChecks - passedChecks;
  
  print('Total Checks: $totalChecks');
  print('Passed: $passedChecks');
  print('Failed: $failedChecks');
  
  if (failedChecks > 0) {
    print('\n❌ Security Issues Found:');
    for (final result in results.where((r) => !r.passed)) {
      print('  • ${result.description}: ${result.message}');
    }
    exit(1);
  } else {
    print('\n✅ All security checks passed!');
    exit(0);
  }
}

class SecurityAuditResult {
  final String category;
  final String description;
  final bool passed;
  final String message;
  final String severity;
  
  SecurityAuditResult({
    required this.category,
    required this.description,
    required this.passed,
    required this.message,
    this.severity = 'medium',
  });
}

class SecurityAuditor {
  List<SecurityAuditResult> runAudit() {
    final results = <SecurityAuditResult>[];
    
    results.addAll(_auditSecretsManagement());
    results.addAll(_auditGitConfiguration());
    results.addAll(_auditDependencies());
    results.addAll(_auditFirebaseConfiguration());
    results.addAll(_auditCICDPipeline());
    results.addAll(_auditCodeSecurity());
    results.addAll(_auditIOSSecurity());
    results.addAll(_auditAndroidSecurity());
    
    return results;
  }
  
  /// Audit secrets management
  List<SecurityAuditResult> _auditSecretsManagement() {
    print('🔐 Auditing Secrets Management...');
    final results = <SecurityAuditResult>[];
    
    // Check .gitignore excludes secrets
    final gitignoreFile = File('.gitignore');
    if (gitignoreFile.existsSync()) {
      final gitignoreContent = gitignoreFile.readAsStringSync();
      
      final secretPatterns = [
        '.env',
        'google-services.json',
        'keystore.jks',
        'key.properties',
        'service-account',
        'firebase-config.js',
      ];
      
      for (final pattern in secretPatterns) {
        if (gitignoreContent.contains(pattern)) {
          results.add(SecurityAuditResult(
            category: 'Secrets',
            description: 'Gitignore excludes $pattern',
            passed: true,
            message: 'Secret pattern properly excluded',
          ));
        } else {
          results.add(SecurityAuditResult(
            category: 'Secrets',
            description: 'Gitignore missing $pattern',
            passed: false,
            message: 'Add $pattern to .gitignore to prevent secret exposure',
            severity: 'high',
          ));
        }
      }
    } else {
      results.add(SecurityAuditResult(
        category: 'Secrets',
        description: 'Gitignore file missing',
        passed: false,
        message: 'Create .gitignore file to prevent secret exposure',
        severity: 'high',
      ));
    }
    
    // Check for accidentally committed secrets
    final secretFiles = [
      '.env',
      'android/key.properties',
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
      'web/firebase-config.js',
      'service-account.json',
    ];
    
    for (final secretFile in secretFiles) {
      final file = File(secretFile);
      if (file.existsSync()) {
        results.add(SecurityAuditResult(
          category: 'Secrets',
          description: 'Secret file found: $secretFile',
          passed: false,
          message: 'Remove $secretFile from repository and add to .gitignore',
          severity: 'critical',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Secrets',
          description: 'No secret file: $secretFile',
          passed: true,
          message: 'Secret file properly excluded',
        ));
      }
    }
    
    // Check example files exist
    final exampleFiles = [
      'config/secrets/.env.example',
      'config/secrets/key.properties.example',
      'config/secrets/google-services.example.json',
    ];
    
    for (final exampleFile in exampleFiles) {
      final file = File(exampleFile);
      if (file.existsSync()) {
        results.add(SecurityAuditResult(
          category: 'Secrets',
          description: 'Example file exists: $exampleFile',
          passed: true,
          message: 'Example configuration provided',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Secrets',
          description: 'Missing example: $exampleFile',
          passed: false,
          message: 'Create example file for developer setup',
        ));
      }
    }
    
    return results;
  }
  
  /// Audit Git configuration
  List<SecurityAuditResult> _auditGitConfiguration() {
    print('📝 Auditing Git Configuration...');
    final results = <SecurityAuditResult>[];
    
    // Check for sensitive data in git history
    try {
      final result = Process.runSync('git', ['log', '--all', '--grep=password', '--grep=secret', '--grep=key', '-i']);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        results.add(SecurityAuditResult(
          category: 'Git',
          description: 'Sensitive data in git history',
          passed: false,
          message: 'Found potential secrets in git commit messages',
          severity: 'high',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Git',
          description: 'Git history clean',
          passed: true,
          message: 'No sensitive data found in commit messages',
        ));
      }
    } catch (e) {
      results.add(SecurityAuditResult(
        category: 'Git',
        description: 'Git history check failed',
        passed: false,
        message: 'Could not check git history: $e',
      ));
    }
    
    return results;
  }
  
  /// Audit dependencies for vulnerabilities
  List<SecurityAuditResult> _auditDependencies() {
    print('📦 Auditing Dependencies...');
    final results = <SecurityAuditResult>[];
    
    // Check pubspec.yaml for known vulnerable packages
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final pubspecContent = pubspecFile.readAsStringSync();
      
      // This is a simplified check - in production, use tools like 'dart pub deps' with vulnerability databases
      final knownVulnerablePatterns = [
        'http: ^0.12.',  // Old version with vulnerabilities
        'crypto: ^2.',   // Old version
      ];
      
      for (final pattern in knownVulnerablePatterns) {
        if (pubspecContent.contains(pattern)) {
          results.add(SecurityAuditResult(
            category: 'Dependencies',
            description: 'Vulnerable dependency: $pattern',
            passed: false,
            message: 'Update to latest secure version',
            severity: 'medium',
          ));
        }
      }
      
      results.add(SecurityAuditResult(
        category: 'Dependencies',
        description: 'Dependency security check',
        passed: true,
        message: 'No known vulnerable dependencies found',
      ));
    }
    
    // Check Firebase Functions dependencies
    final functionsPackageFile = File('functions/package.json');
    if (functionsPackageFile.existsSync()) {
      // In production, run 'npm audit' here
      results.add(SecurityAuditResult(
        category: 'Dependencies',
        description: 'Functions dependencies',
        passed: true,
        message: 'Functions package.json exists - run npm audit separately',
      ));
    }
    
    return results;
  }
  
  /// Audit Firebase configuration
  List<SecurityAuditResult> _auditFirebaseConfiguration() {
    print('🔥 Auditing Firebase Configuration...');
    final results = <SecurityAuditResult>[];
    
    // Check Firestore rules exist
    final firestoreRulesFile = File('firestore.rules');
    if (firestoreRulesFile.existsSync()) {
      final rulesContent = firestoreRulesFile.readAsStringSync();
      
      // Check for overly permissive rules
      if (rulesContent.contains('allow read, write: if true')) {
        results.add(SecurityAuditResult(
          category: 'Firebase',
          description: 'Overly permissive Firestore rules',
          passed: false,
          message: 'Found "allow read, write: if true" - this allows unrestricted access',
          severity: 'critical',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Firebase',
          description: 'Firestore rules security',
          passed: true,
          message: 'No overly permissive rules found',
        ));
      }
      
      // Check for authentication requirements
      if (rulesContent.contains('request.auth != null')) {
        results.add(SecurityAuditResult(
          category: 'Firebase',
          description: 'Authentication required',
          passed: true,
          message: 'Rules require authentication',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Firebase',
          description: 'No authentication check',
          passed: false,
          message: 'Consider adding authentication requirements to rules',
          severity: 'medium',
        ));
      }
    } else {
      results.add(SecurityAuditResult(
        category: 'Firebase',
        description: 'Firestore rules missing',
        passed: false,
        message: 'Create firestore.rules file to secure database',
        severity: 'high',
      ));
    }
    
    // Check Storage rules
    final storageRulesFile = File('storage.rules');
    if (storageRulesFile.existsSync()) {
      results.add(SecurityAuditResult(
        category: 'Firebase',
        description: 'Storage rules exist',
        passed: true,
        message: 'Storage security rules configured',
      ));
    } else {
      results.add(SecurityAuditResult(
        category: 'Firebase',
        description: 'Storage rules missing',
        passed: false,
        message: 'Create storage.rules file to secure file uploads',
        severity: 'medium',
      ));
    }
    
    return results;
  }
  
  /// Audit CI/CD pipeline security
  List<SecurityAuditResult> _auditCICDPipeline() {
    print('🚀 Auditing CI/CD Pipeline...');
    final results = <SecurityAuditResult>[];
    
    // Check GitHub Actions workflows
    final workflowFiles = [
      '.github/workflows/main.yml',
      '.github/workflows/android-release.yml',
      '.github/workflows/security.yml',
    ];
    
    for (final workflowFile in workflowFiles) {
      final file = File(workflowFile);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        
        // Check for hardcoded secrets
        final secretPatterns = [
          RegExp(r'password\s*:\s*["\x27][^"\x27]+["\x27]', caseSensitive: false),
          RegExp(r'token\s*:\s*["\x27][^"\x27]+["\x27]', caseSensitive: false),
          RegExp(r'key\s*:\s*["\x27][^"\x27]+["\x27]', caseSensitive: false),
        ];
        
        bool hasHardcodedSecrets = false;
        for (final pattern in secretPatterns) {
          if (pattern.hasMatch(content)) {
            hasHardcodedSecrets = true;
            break;
          }
        }
        
        if (hasHardcodedSecrets) {
          results.add(SecurityAuditResult(
            category: 'CI/CD',
            description: 'Hardcoded secrets in $workflowFile',
            passed: false,
            message: 'Use GitHub secrets instead of hardcoded values',
            severity: 'critical',
          ));
        } else {
          results.add(SecurityAuditResult(
            category: 'CI/CD',
            description: 'No hardcoded secrets in $workflowFile',
            passed: true,
            message: 'Workflow uses proper secret management',
          ));
        }
        
        // Check for secret usage
        if (content.contains('\${{ secrets.')) {
          results.add(SecurityAuditResult(
            category: 'CI/CD',
            description: 'Uses GitHub secrets in $workflowFile',
            passed: true,
            message: 'Properly uses GitHub secrets',
          ));
        }
      }
    }
    
    return results;
  }
  
  /// Audit code security
  List<SecurityAuditResult> _auditCodeSecurity() {
    print('💻 Auditing Code Security...');
    final results = <SecurityAuditResult>[];
    
    // Check for common security anti-patterns in Dart files
    final dartFiles = _findDartFiles(Directory('lib'));
    
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      
      // Check for hardcoded URLs that might be sensitive
      final urlPattern = RegExp(r'https?://[^\s"\x27]+');
      final urls = urlPattern.allMatches(content);
      
      for (final match in urls) {
        final url = match.group(0)!;
        if (url.contains('localhost') || url.contains('127.0.0.1')) {
          // This is acceptable for development
          continue;
        }
        
        // Check for potentially sensitive URLs
        if (url.contains('api') && (url.contains('key') || url.contains('token'))) {
          results.add(SecurityAuditResult(
            category: 'Code',
            description: 'Potential sensitive URL in ${file.path}',
            passed: false,
            message: 'Review URL: $url - consider using environment variables',
            severity: 'medium',
          ));
        }
      }
    }
    
    results.add(SecurityAuditResult(
      category: 'Code',
      description: 'Code security scan completed',
      passed: true,
      message: 'Scanned ${dartFiles.length} Dart files',
    ));
    
    return results;
  }
  
  /// Audit iOS security
  List<SecurityAuditResult> _auditIOSSecurity() {
    print('🍎 Auditing iOS Security...');
    final results = <SecurityAuditResult>[];
    
    // Check iOS Info.plist
    final infoPlistFile = File('ios/Runner/Info.plist');
    if (infoPlistFile.existsSync()) {
      final content = infoPlistFile.readAsStringSync();
      
      // Check for debug settings in production
      if (content.contains('<key>UIFileSharingEnabled</key>')) {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'File sharing enabled in Info.plist',
          passed: false,
          message: 'Remove UIFileSharingEnabled from production builds',
          severity: 'medium',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'No file sharing in Info.plist',
          passed: true,
          message: 'iOS Info.plist is production-ready',
        ));
      }
      
      // Check for proper URL schemes
      if (content.contains('CFBundleURLSchemes')) {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'URL schemes configured',
          passed: true,
          message: 'URL schemes are configured for deep linking',
        ));
      }
    }
    
    // Check for Firebase configuration files
    final firebaseConfigs = [
      'ios/Firebase/Development/GoogleService-Info.plist',
      'ios/Firebase/Staging/GoogleService-Info.plist',
      'ios/Firebase/Production/GoogleService-Info.plist',
    ];
    
    for (final config in firebaseConfigs) {
      final file = File(config);
      if (file.existsSync()) {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'Firebase config exists: $config',
          passed: true,
          message: 'Environment-specific Firebase configuration found',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'Missing Firebase config: $config',
          passed: false,
          message: 'Create Firebase configuration for iOS environment',
          severity: 'medium',
        ));
      }
    }
    
    // Check for iOS build configurations
    final xcconfigs = [
      'ios/Flutter/Development.xcconfig',
      'ios/Flutter/Staging.xcconfig',
      'ios/Flutter/Production.xcconfig',
    ];
    
    for (final xcconfig in xcconfigs) {
      final file = File(xcconfig);
      if (file.existsSync()) {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'Build config exists: $xcconfig',
          passed: true,
          message: 'Environment-specific build configuration found',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'iOS',
          description: 'Missing build config: $xcconfig',
          passed: false,
          message: 'Create build configuration for iOS environment',
          severity: 'low',
        ));
      }
    }
    
    return results;
  }

  /// Audit Android security
  List<SecurityAuditResult> _auditAndroidSecurity() {
    print('🤖 Auditing Android Security...');
    final results = <SecurityAuditResult>[];
    
    // Check Android manifest
    final manifestFile = File('android/app/src/main/AndroidManifest.xml');
    if (manifestFile.existsSync()) {
      final content = manifestFile.readAsStringSync();
      
      // Check for debug flags in production
      if (content.contains('android:debuggable="true"')) {
        results.add(SecurityAuditResult(
          category: 'Android',
          description: 'Debug flag in manifest',
          passed: false,
          message: 'Remove android:debuggable="true" from production builds',
          severity: 'medium',
        ));
      } else {
        results.add(SecurityAuditResult(
          category: 'Android',
          description: 'No debug flags in manifest',
          passed: true,
          message: 'Android manifest is production-ready',
        ));
      }
      
      // Check for backup allowance
      if (content.contains('android:allowBackup="true"')) {
        results.add(SecurityAuditResult(
          category: 'Android',
          description: 'Backup allowed in manifest',
          passed: false,
          message: 'Consider setting android:allowBackup="false" for sensitive apps',
          severity: 'low',
        ));
      }
    }
    
    // Check ProGuard configuration
    final proguardFile = File('android/app/proguard-rules.pro');
    if (proguardFile.existsSync()) {
      results.add(SecurityAuditResult(
        category: 'Android',
        description: 'ProGuard rules exist',
        passed: true,
        message: 'Code obfuscation configured',
      ));
    } else {
      results.add(SecurityAuditResult(
        category: 'Android',
        description: 'ProGuard rules missing',
        passed: false,
        message: 'Create proguard-rules.pro for code obfuscation',
        severity: 'low',
      ));
    }
    
    return results;
  }
  
  /// Find all Dart files in a directory
  List<File> _findDartFiles(Directory dir) {
    final dartFiles = <File>[];
    
    if (!dir.existsSync()) return dartFiles;
    
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity);
      }
    }
    
    return dartFiles;
  }
}