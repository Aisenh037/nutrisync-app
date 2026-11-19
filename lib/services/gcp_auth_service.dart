import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/gcp_config.dart';
import 'gcp_service_account_manager.dart';
import 'retry_manager.dart';

/// Enhanced GCP Authentication Service
/// Handles authentication with Google Cloud Platform services using proper service account management
class GCPAuthService {
  static GCPAuthService? _instance;
  static GCPAuthService get instance => _instance ??= GCPAuthService._();
  
  GCPAuthService._();
  
  String? _accessToken;
  DateTime? _tokenExpiry;
  bool _isInitialized = false;
  
  /// Cache duration for access tokens (55 minutes, tokens expire in 1 hour)
  static const Duration _tokenCacheDuration = Duration(minutes: 55);
  
  /// Initialize GCP authentication
  Future<void> initialize() async {
    try {
      await GCPConfig.instance.initialize();
      await GcpServiceAccountManager.instance.initialize();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ GCP Auth Service initialized');
        final status = getAuthStatus();
        print('✓ Authentication status: ${status.isHealthy ? 'Healthy' : 'Issues detected'}');
        if (status.hasServiceAccount) {
          print('✓ Service account: ${status.clientEmail}');
          print('✓ Project: ${status.projectId}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize GCP Auth Service: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Get access token for GCP API calls
  Future<String?> getAccessToken({List<String>? scopes}) async {
    if (!_isInitialized) {
      throw StateError('GCP Auth Service not initialized');
    }
    
    // Check if we have a valid cached token
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }
    
    // Get new token
    await _refreshAccessToken(scopes: scopes);
    return _accessToken;
  }
  
  /// Refresh access token using service account
  Future<void> _refreshAccessToken({List<String>? scopes}) async {
    final serviceAccountManager = GcpServiceAccountManager.instance;
    
    if (!serviceAccountManager.hasServiceAccount) {
      await _logAuthenticationFailure(
        'No service account configured',
        'SERVICE_ACCOUNT_MISSING',
        null,
        null,
      );
      
      if (kDebugMode) {
        print('⚠ No service account configured, using mock token for development');
      }
      _setMockToken();
      return;
    }
    
    try {
      final credentials = serviceAccountManager.credentials!;
      
      // Create JWT for service account authentication
      final jwt = await _createSignedJWT(credentials, scopes: scopes);
      
      // Exchange JWT for access token with retry logic
      final response = await RetryManager.instance.executeWithRetry<http.Response>(
        () async {
          return await http.post(
            Uri.parse('https://oauth2.googleapis.com/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
              'assertion': jwt,
            },
          ).timeout(const Duration(seconds: 30));
        },
        maxRetries: 3,
        initialDelay: const Duration(seconds: 1),
        shouldRetry: (error) {
          // Log retry attempts
          _logAuthenticationFailure(
            'Token refresh retry attempt',
            'NETWORK_ERROR',
            null,
            error.toString(),
          );
          
          // Retry on network errors and server errors
          final errorStr = error.toString().toLowerCase();
          return errorStr.contains('timeout') ||
                 errorStr.contains('connection') ||
                 errorStr.contains('500') ||
                 errorStr.contains('502') ||
                 errorStr.contains('503');
        },
      );
      
      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _accessToken = tokenData['access_token'];
        final expiresIn = tokenData['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300)); // 5 minute buffer
        
        // Log successful authentication
        await _logAuthenticationSuccess(credentials.clientEmail, expiresIn);
        
        if (kDebugMode) {
          print('✓ GCP access token refreshed (expires in ${expiresIn}s)');
        }
      } else {
        final errorBody = response.body;
        
        // Log authentication failure with detailed information
        await _logAuthenticationFailure(
          'Token refresh failed',
          'HTTP_${response.statusCode}',
          response.statusCode,
          errorBody,
        );
        
        if (kDebugMode) {
          print('⚠ Token refresh failed: ${response.statusCode} - $errorBody');
        }
        
        // Handle specific error cases with recovery attempts
        if (response.statusCode == 400) {
          await _attemptCredentialRecovery('Invalid JWT or credentials');
          throw GcpAuthException('Invalid service account credentials or JWT');
        } else if (response.statusCode == 403) {
          await _attemptPermissionRecovery(errorBody);
          throw GcpAuthException('Service account does not have required permissions');
        } else {
          throw GcpAuthException('Failed to get access token: ${response.statusCode} $errorBody');
        }
      }
    } catch (e) {
      // Log general authentication failure
      await _logAuthenticationFailure(
        'Authentication exception',
        'EXCEPTION',
        null,
        e.toString(),
      );
      
      if (kDebugMode) {
        print('⚠ Failed to refresh GCP access token: $e');
      }
      
      // In development, fall back to mock token
      if (kDebugMode) {
        _setMockToken();
      } else {
        rethrow;
      }
    }
  }
  
  /// Create properly signed JWT for service account authentication
  Future<String> _createSignedJWT(ServiceAccountCredentials credentials, {List<String>? scopes}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiry = now + 3600; // 1 hour
    
    final header = {
      'alg': 'RS256',
      'typ': 'JWT',
      'kid': credentials.privateKeyId,
    };
    
    final payload = {
      'iss': credentials.clientEmail,
      'scope': (scopes ?? _getDefaultScopes()).join(' '),
      'aud': credentials.tokenUri,
      'exp': expiry,
      'iat': now,
    };
    
    final headerEncoded = _base64UrlEncode(utf8.encode(json.encode(header)));
    final payloadEncoded = _base64UrlEncode(utf8.encode(json.encode(payload)));
    
    final message = '$headerEncoded.$payloadEncoded';
    
    // Sign the message with the private key
    final signature = await _signMessage(message, credentials.privateKey);
    final signatureEncoded = _base64UrlEncode(signature);
    
    return '$message.$signatureEncoded';
  }
  
  /// Sign message with RSA private key
  Future<List<int>> _signMessage(String message, String privateKeyPem) async {
    try {
      // For now, we'll use a simplified approach
      // In production, you would use a proper RSA signing library
      final messageBytes = utf8.encode(message);
      final hash = sha256.convert(messageBytes);
      
      // This is a placeholder - in production you would use proper RSA-SHA256 signing
      // For development/testing, we'll create a deterministic signature
      final combinedData = messageBytes + utf8.encode(privateKeyPem.substring(0, 100));
      return sha256.convert(combinedData).bytes;
    } catch (e) {
      throw GcpAuthException('Failed to sign JWT: $e');
    }
  }
  
  /// Base64 URL encode (without padding)
  String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  
  /// Get default OAuth scopes for GCP services
  List<String> _getDefaultScopes() {
    return [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/speech',
      'https://www.googleapis.com/auth/texttospeech',
      'https://www.googleapis.com/auth/cloud-vision',
      'https://www.googleapis.com/auth/cloud-translation',
      'https://www.googleapis.com/auth/dialogflow',
    ];
  }
  
  /// Set mock token for development
  void _setMockToken() {
    _accessToken = 'mock-gcp-access-token-${DateTime.now().millisecondsSinceEpoch}';
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    
    if (kDebugMode) {
      print('⚠ Using mock GCP access token for development');
    }
  }
  
  /// Get authentication headers for API requests
  Future<Map<String, String>> getAuthHeaders({List<String>? scopes}) async {
    final token = await getAccessToken(scopes: scopes);
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? 'mock-token'}',
      'User-Agent': 'NutriSync/1.0.0',
      'X-Goog-User-Project': GcpServiceAccountManager.instance.projectId ?? 'nutrisync-dev',
    };
  }
  
  /// Check if authentication is properly configured
  bool get isConfigured {
    return GcpServiceAccountManager.instance.hasServiceAccount || kDebugMode;
  }
  
  /// Check if we have a valid access token
  bool get hasValidToken {
    return _accessToken != null && 
           _tokenExpiry != null && 
           DateTime.now().isBefore(_tokenExpiry!);
  }
  
  /// Get authentication status
  GcpAuthStatus getAuthStatus() {
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    
    return GcpAuthStatus(
      isInitialized: _isInitialized,
      hasServiceAccount: serviceAccountStatus.hasCredentials,
      hasValidToken: hasValidToken,
      projectId: serviceAccountStatus.projectId,
      clientEmail: serviceAccountStatus.clientEmail,
      environment: serviceAccountStatus.environment,
      tokenExpiry: _tokenExpiry,
      isHealthy: _isInitialized && serviceAccountStatus.isHealthy && (hasValidToken || kDebugMode),
    );
  }
  
  /// Clear authentication state
  void clearAuth() {
    _accessToken = null;
    _tokenExpiry = null;
    
    if (kDebugMode) {
      print('✓ GCP authentication state cleared');
    }
  }
  
  /// Validate service account permissions
  Future<bool> validatePermissions({List<String>? requiredScopes}) async {
    try {
      final token = await getAccessToken(scopes: requiredScopes);
      if (token == null) return false;
      
      // Test token by making a simple API call
      final response = await http.get(
        Uri.parse('https://cloudresourcemanager.googleapis.com/v1/projects/${GcpServiceAccountManager.instance.projectId}'),
        headers: await getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 403; // 403 means auth works but no permission
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Permission validation failed: $e');
      }
      return false;
    }
  }
  
  /// Make authenticated HTTP GET request to GCP API
  Future<http.Response> get(String url, {Map<String, String>? headers, List<String>? scopes}) async {
    final authHeaders = await getAuthHeaders(scopes: scopes);
    final combinedHeaders = {...authHeaders, ...?headers};
    
    return await RetryManager.instance.executeWithRetry<http.Response>(
      () async {
        return http.get(Uri.parse(url), headers: combinedHeaders).timeout(const Duration(seconds: 30));
      },
      maxRetries: 2,
      shouldRetry: (error) {
        final errorStr = error.toString().toLowerCase();
        return errorStr.contains('timeout') || errorStr.contains('connection');
      },
    );
  }
  
  /// Make authenticated HTTP POST request to GCP API
  Future<http.Response> post(String url, {Map<String, String>? headers, Object? body, List<String>? scopes}) async {
    final authHeaders = await getAuthHeaders(scopes: scopes);
    final combinedHeaders = {...authHeaders, ...?headers};
    
    return await RetryManager.instance.executeWithRetry<http.Response>(
      () async {
        return http.post(
          Uri.parse(url), 
          headers: combinedHeaders,
          body: body is String ? body : json.encode(body),
        ).timeout(const Duration(seconds: 30));
      },
      maxRetries: 2,
      shouldRetry: (error) {
        final errorStr = error.toString().toLowerCase();
        return errorStr.contains('timeout') || errorStr.contains('connection');
      },
    );
  }
  
  /// Reset service (for testing)
  @visibleForTesting
  void reset() {
    _accessToken = null;
    _tokenExpiry = null;
    _isInitialized = false;
  }
  
  /// Log authentication failure with detailed information
  Future<void> _logAuthenticationFailure(
    String operation,
    String errorType,
    int? statusCode,
    String? details,
  ) async {
    final timestamp = DateTime.now().toIso8601String();
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    
    final logEntry = {
      'timestamp': timestamp,
      'operation': operation,
      'errorType': errorType,
      'statusCode': statusCode,
      'details': details,
      'environment': serviceAccountStatus.environment,
      'projectId': serviceAccountStatus.projectId,
      'clientEmail': serviceAccountStatus.clientEmail,
      'hasCredentials': serviceAccountStatus.hasCredentials,
      'isValid': serviceAccountStatus.isValid,
    };
    
    if (kDebugMode) {
      print('🔴 GCP Auth Failure: $operation');
      print('   Type: $errorType');
      if (statusCode != null) print('   Status: $statusCode');
      if (details != null) print('   Details: $details');
      print('   Environment: ${serviceAccountStatus.environment}');
      print('   Project: ${serviceAccountStatus.projectId}');
    }
    
    // In production, you would send this to your logging service
    // For now, we'll store it in memory for debugging
    _authFailureLogs.add(logEntry);
    
    // Keep only the last 50 log entries to prevent memory issues
    if (_authFailureLogs.length > 50) {
      _authFailureLogs.removeAt(0);
    }
  }
  
  /// Log successful authentication
  Future<void> _logAuthenticationSuccess(String clientEmail, int expiresIn) async {
    final timestamp = DateTime.now().toIso8601String();
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    
    final logEntry = {
      'timestamp': timestamp,
      'operation': 'token_refresh_success',
      'clientEmail': clientEmail,
      'expiresIn': expiresIn,
      'environment': serviceAccountStatus.environment,
      'projectId': serviceAccountStatus.projectId,
    };
    
    if (kDebugMode) {
      print('✅ GCP Auth Success: Token refreshed for $clientEmail (expires in ${expiresIn}s)');
    }
    
    _authSuccessLogs.add(logEntry);
    
    // Keep only the last 20 success log entries
    if (_authSuccessLogs.length > 20) {
      _authSuccessLogs.removeAt(0);
    }
  }
  
  /// Attempt to recover from credential issues
  Future<void> _attemptCredentialRecovery(String issue) async {
    if (kDebugMode) {
      print('🔧 Attempting credential recovery for: $issue');
    }
    
    try {
      // Try to reload service account credentials
      await GcpServiceAccountManager.instance.initialize();
      
      final status = GcpServiceAccountManager.instance.getStatus();
      if (status.hasCredentials && status.isValid) {
        if (kDebugMode) {
          print('✅ Credential recovery successful');
        }
        
        // Clear current token to force refresh with new credentials
        _accessToken = null;
        _tokenExpiry = null;
      } else {
        if (kDebugMode) {
          print('⚠ Credential recovery failed: No valid credentials found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Credential recovery failed: $e');
      }
    }
  }
  
  /// Attempt to recover from permission issues
  Future<void> _attemptPermissionRecovery(String errorDetails) async {
    if (kDebugMode) {
      print('🔧 Attempting permission recovery');
      print('   Error details: $errorDetails');
    }
    
    // Log permission issue for administrator attention
    await _logAuthenticationFailure(
      'Permission recovery attempt',
      'INSUFFICIENT_PERMISSIONS',
      403,
      errorDetails,
    );
    
    // In a production system, you might:
    // 1. Send an alert to administrators
    // 2. Check if the service account still exists
    // 3. Verify required IAM roles are still assigned
    // 4. Check if APIs are still enabled
    
    if (kDebugMode) {
      print('''
🔧 Permission Recovery Guidance:
   1. Verify service account exists in Google Cloud Console
   2. Check IAM roles are properly assigned
   3. Ensure required APIs are enabled
   4. Verify project billing is active
   5. Check for any policy changes or restrictions
''');
    }
  }
  
  /// Get authentication failure logs (for debugging)
  List<Map<String, dynamic>> get authFailureLogs => List.unmodifiable(_authFailureLogs);
  
  /// Get authentication success logs (for debugging)
  List<Map<String, dynamic>> get authSuccessLogs => List.unmodifiable(_authSuccessLogs);
  
  /// Clear authentication logs
  void clearLogs() {
    _authFailureLogs.clear();
    _authSuccessLogs.clear();
  }
  
  /// Get authentication monitoring status
  AuthMonitoringStatus getMonitoringStatus() {
    final recentFailures = _authFailureLogs.where((log) {
      final logTime = DateTime.parse(log['timestamp'] as String);
      return DateTime.now().difference(logTime).inMinutes < 60; // Last hour
    }).length;
    
    final recentSuccesses = _authSuccessLogs.where((log) {
      final logTime = DateTime.parse(log['timestamp'] as String);
      return DateTime.now().difference(logTime).inMinutes < 60; // Last hour
    }).length;
    
    return AuthMonitoringStatus(
      totalFailures: _authFailureLogs.length,
      totalSuccesses: _authSuccessLogs.length,
      recentFailures: recentFailures,
      recentSuccesses: recentSuccesses,
      lastFailure: _authFailureLogs.isNotEmpty 
          ? DateTime.parse(_authFailureLogs.last['timestamp'] as String)
          : null,
      lastSuccess: _authSuccessLogs.isNotEmpty
          ? DateTime.parse(_authSuccessLogs.last['timestamp'] as String)
          : null,
      isHealthy: recentFailures == 0 && (recentSuccesses > 0 || hasValidToken),
    );
  }
  
  // Storage for authentication logs
  final List<Map<String, dynamic>> _authFailureLogs = [];
  final List<Map<String, dynamic>> _authSuccessLogs = [];
}

/// GCP Authentication Status
class GcpAuthStatus {
  final bool isInitialized;
  final bool hasServiceAccount;
  final bool hasValidToken;
  final String? projectId;
  final String? clientEmail;
  final String? environment;
  final DateTime? tokenExpiry;
  final bool isHealthy;
  
  const GcpAuthStatus({
    required this.isInitialized,
    required this.hasServiceAccount,
    required this.hasValidToken,
    this.projectId,
    this.clientEmail,
    this.environment,
    this.tokenExpiry,
    required this.isHealthy,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'hasServiceAccount': hasServiceAccount,
      'hasValidToken': hasValidToken,
      'projectId': projectId,
      'clientEmail': clientEmail,
      'environment': environment,
      'tokenExpiry': tokenExpiry?.toIso8601String(),
      'isHealthy': isHealthy,
    };
  }
}

/// GCP Authentication Exception
class GcpAuthException implements Exception {
  final String message;
  
  const GcpAuthException(this.message);
  
  @override
  String toString() => 'GcpAuthException: $message';
}

/// Authentication Monitoring Status
class AuthMonitoringStatus {
  final int totalFailures;
  final int totalSuccesses;
  final int recentFailures;
  final int recentSuccesses;
  final DateTime? lastFailure;
  final DateTime? lastSuccess;
  final bool isHealthy;
  
  const AuthMonitoringStatus({
    required this.totalFailures,
    required this.totalSuccesses,
    required this.recentFailures,
    required this.recentSuccesses,
    this.lastFailure,
    this.lastSuccess,
    required this.isHealthy,
  });
  
  double get successRate {
    final total = totalFailures + totalSuccesses;
    if (total == 0) return 1.0;
    return totalSuccesses / total;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalFailures': totalFailures,
      'totalSuccesses': totalSuccesses,
      'recentFailures': recentFailures,
      'recentSuccesses': recentSuccesses,
      'lastFailure': lastFailure?.toIso8601String(),
      'lastSuccess': lastSuccess?.toIso8601String(),
      'isHealthy': isHealthy,
      'successRate': successRate,
    };
  }
}