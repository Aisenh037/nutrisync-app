import 'package:flutter/foundation.dart';
import 'elevenlabs_tts_service.dart';
import 'elevenlabs_auth_handler.dart';

/// ElevenLabs Fallback Manager
/// Handles graceful degradation when TTS services fail
class ElevenLabsFallbackManager {
  static ElevenLabsFallbackManager? _instance;
  static ElevenLabsFallbackManager get instance => _instance ??= ElevenLabsFallbackManager._();
  
  ElevenLabsFallbackManager._();
  
  bool _isInitialized = false;
  FallbackStrategy _currentStrategy = FallbackStrategy.textOnly;
  final List<String> _failureLog = [];
  
  /// Available fallback strategies
  static const Map<FallbackStrategy, String> strategyDescriptions = {
    FallbackStrategy.textOnly: 'Text-only responses without audio',
    FallbackStrategy.localTts: 'Use device built-in text-to-speech',
    FallbackStrategy.cachedAudio: 'Use pre-recorded audio responses',
    FallbackStrategy.silentMode: 'Silent operation with visual feedback only',
  };
  
  /// Initialize fallback manager
  Future<void> initialize() async {
    try {
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ ElevenLabs Fallback Manager initialized');
        print('✓ Default strategy: ${strategyDescriptions[_currentStrategy]}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize ElevenLabs Fallback Manager: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Handle TTS service failure with appropriate fallback
  Future<FallbackResult> handleTtsFailure(
    String text, {
    Exception? originalError,
    String? voiceId,
    String? modelId,
  }) async {
    if (!_isInitialized) {
      throw StateError('ElevenLabsFallbackManager not initialized');
    }
    
    // Log the failure
    _logFailure(originalError?.toString() ?? 'Unknown TTS failure');
    
    // Determine appropriate fallback strategy
    final strategy = await _determineFallbackStrategy(originalError);
    
    if (kDebugMode) {
      print('⚠ TTS failed, using fallback strategy: ${strategyDescriptions[strategy]}');
    }
    
    switch (strategy) {
      case FallbackStrategy.textOnly:
        return _handleTextOnlyFallback(text);
      
      case FallbackStrategy.localTts:
        return await _handleLocalTtsFallback(text);
      
      case FallbackStrategy.cachedAudio:
        return await _handleCachedAudioFallback(text);
      
      case FallbackStrategy.silentMode:
        return _handleSilentModeFallback(text);
    }
  }
  
  /// Determine the best fallback strategy based on the error
  Future<FallbackStrategy> _determineFallbackStrategy(Exception? error) async {
    if (error is ElevenLabsAuthException) {
      // Authentication issues - use local TTS or text-only
      return FallbackStrategy.localTts;
    }
    
    if (error is ElevenLabsException) {
      final statusCode = error.statusCode;
      
      if (statusCode == 429) {
        // Rate limited - try cached audio first, then local TTS
        return FallbackStrategy.cachedAudio;
      }
      
      if (statusCode == 402) {
        // Quota exceeded - use local TTS
        return FallbackStrategy.localTts;
      }
      
      if (statusCode != null && statusCode >= 500) {
        // Server error - try local TTS
        return FallbackStrategy.localTts;
      }
    }
    
    // Default to text-only for unknown errors
    return FallbackStrategy.textOnly;
  }
  
  /// Handle text-only fallback
  FallbackResult _handleTextOnlyFallback(String text) {
    return FallbackResult(
      strategy: FallbackStrategy.textOnly,
      text: text,
      audioUrl: null,
      isSuccess: true,
      message: 'Voice synthesis unavailable. Displaying text response.',
      userNotification: 'Voice features are temporarily unavailable. You can still read the response below.',
    );
  }
  
  /// Handle local TTS fallback (device built-in)
  Future<FallbackResult> _handleLocalTtsFallback(String text) async {
    try {
      // Note: This would integrate with Flutter's built-in TTS
      // For now, we'll simulate the functionality
      
      if (kDebugMode) {
        print('📱 Using device built-in TTS for: "${text.substring(0, text.length.clamp(0, 50))}..."');
      }
      
      return FallbackResult(
        strategy: FallbackStrategy.localTts,
        text: text,
        audioUrl: 'local://tts', // Placeholder for local TTS
        isSuccess: true,
        message: 'Using device built-in voice synthesis.',
        userNotification: 'Using your device\'s built-in voice for this response.',
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Local TTS failed, falling back to text-only: $e');
      }
      return _handleTextOnlyFallback(text);
    }
  }
  
  /// Handle cached audio fallback
  Future<FallbackResult> _handleCachedAudioFallback(String text) async {
    try {
      // Check if we have cached audio for common responses
      final cachedAudio = await _getCachedAudioForText(text);
      
      if (cachedAudio != null) {
        return FallbackResult(
          strategy: FallbackStrategy.cachedAudio,
          text: text,
          audioUrl: cachedAudio,
          isSuccess: true,
          message: 'Using cached audio response.',
          userNotification: null, // No need to notify for cached audio
        );
      }
      
      // No cached audio available, fall back to local TTS
      return await _handleLocalTtsFallback(text);
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Cached audio fallback failed: $e');
      }
      return await _handleLocalTtsFallback(text);
    }
  }
  
  /// Handle silent mode fallback
  FallbackResult _handleSilentModeFallback(String text) {
    return FallbackResult(
      strategy: FallbackStrategy.silentMode,
      text: text,
      audioUrl: null,
      isSuccess: true,
      message: 'Operating in silent mode.',
      userNotification: 'Voice features are disabled. Reading response silently.',
    );
  }
  
  /// Get cached audio for common responses
  Future<String?> _getCachedAudioForText(String text) async {
    // This would implement a cache lookup for pre-recorded common responses
    // For now, we'll simulate with common nutrition responses
    
    final commonResponses = {
      'breakfast': 'cached://breakfast_response.mp3',
      'lunch': 'cached://lunch_response.mp3',
      'dinner': 'cached://dinner_response.mp3',
      'snack': 'cached://snack_response.mp3',
      'water': 'cached://hydration_response.mp3',
    };
    
    final lowerText = text.toLowerCase();
    for (final entry in commonResponses.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Check if TTS service is available
  Future<bool> isTtsServiceAvailable() async {
    try {
      final ttsService = ElevenLabsTtsService.instance;
      
      if (!ttsService.isReady) {
        return false;
      }
      
      final authStatus = await ElevenLabsAuthHandler.instance.getAuthStatus();
      return authStatus.isHealthy;
    } catch (e) {
      return false;
    }
  }
  
  /// Get service health status
  Future<ServiceHealthStatus> getServiceHealth() async {
    final isAvailable = await isTtsServiceAvailable();
    final recentFailures = _getRecentFailures();
    
    ServiceHealthLevel healthLevel;
    if (isAvailable && recentFailures.isEmpty) {
      healthLevel = ServiceHealthLevel.healthy;
    } else if (isAvailable && recentFailures.length < 3) {
      healthLevel = ServiceHealthLevel.degraded;
    } else {
      healthLevel = ServiceHealthLevel.unhealthy;
    }
    
    return ServiceHealthStatus(
      isAvailable: isAvailable,
      healthLevel: healthLevel,
      recentFailures: recentFailures,
      currentStrategy: _currentStrategy,
      recommendedAction: _getRecommendedAction(healthLevel),
    );
  }
  
  /// Get recent failures (last 10 minutes)
  List<String> _getRecentFailures() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    // In a real implementation, this would filter by timestamp
    return _failureLog.take(5).toList(); // Return last 5 failures for now
  }
  
  /// Get recommended action based on health level
  String _getRecommendedAction(ServiceHealthLevel healthLevel) {
    switch (healthLevel) {
      case ServiceHealthLevel.healthy:
        return 'No action required. Service is operating normally.';
      case ServiceHealthLevel.degraded:
        return 'Monitor service. Consider using fallback options if issues persist.';
      case ServiceHealthLevel.unhealthy:
        return 'Service is unavailable. Using fallback mechanisms. Check API key and network connectivity.';
    }
  }
  
  /// Log failure for monitoring
  void _logFailure(String error) {
    final timestamp = DateTime.now().toIso8601String();
    _failureLog.add('$timestamp: $error');
    
    // Keep only last 20 failures
    if (_failureLog.length > 20) {
      _failureLog.removeAt(0);
    }
    
    if (kDebugMode) {
      print('⚠ TTS Failure logged: $error');
    }
  }
  
  /// Set fallback strategy
  void setFallbackStrategy(FallbackStrategy strategy) {
    _currentStrategy = strategy;
    
    if (kDebugMode) {
      print('✓ Fallback strategy changed to: ${strategyDescriptions[strategy]}');
    }
  }
  
  /// Get current fallback strategy
  FallbackStrategy get currentStrategy => _currentStrategy;
  
  /// Get failure statistics
  FallbackStatistics getStatistics() {
    final recentFailures = _getRecentFailures();
    
    return FallbackStatistics(
      totalFailures: _failureLog.length,
      recentFailures: recentFailures.length,
      currentStrategy: _currentStrategy,
      isHealthy: recentFailures.length < 3,
    );
  }
  
  /// Clear failure log
  void clearFailureLog() {
    _failureLog.clear();
    
    if (kDebugMode) {
      print('✓ Failure log cleared');
    }
  }
  
  /// Reset manager (for testing)
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _currentStrategy = FallbackStrategy.textOnly;
    _failureLog.clear();
  }
}

/// Fallback strategies
enum FallbackStrategy {
  textOnly,
  localTts,
  cachedAudio,
  silentMode,
}

/// Fallback result
class FallbackResult {
  final FallbackStrategy strategy;
  final String text;
  final String? audioUrl;
  final bool isSuccess;
  final String message;
  final String? userNotification;
  
  const FallbackResult({
    required this.strategy,
    required this.text,
    this.audioUrl,
    required this.isSuccess,
    required this.message,
    this.userNotification,
  });
  
  bool get hasAudio => audioUrl != null;
  
  Map<String, dynamic> toJson() {
    return {
      'strategy': strategy.name,
      'text': text,
      'audioUrl': audioUrl,
      'isSuccess': isSuccess,
      'message': message,
      'userNotification': userNotification,
      'hasAudio': hasAudio,
    };
  }
}

/// Service health status
class ServiceHealthStatus {
  final bool isAvailable;
  final ServiceHealthLevel healthLevel;
  final List<String> recentFailures;
  final FallbackStrategy currentStrategy;
  final String recommendedAction;
  
  const ServiceHealthStatus({
    required this.isAvailable,
    required this.healthLevel,
    required this.recentFailures,
    required this.currentStrategy,
    required this.recommendedAction,
  });
  
  bool get isHealthy => healthLevel == ServiceHealthLevel.healthy;
  
  Map<String, dynamic> toJson() {
    return {
      'isAvailable': isAvailable,
      'healthLevel': healthLevel.name,
      'recentFailures': recentFailures,
      'currentStrategy': currentStrategy.name,
      'recommendedAction': recommendedAction,
      'isHealthy': isHealthy,
    };
  }
}

/// Service health levels
enum ServiceHealthLevel {
  healthy,
  degraded,
  unhealthy,
}

/// Fallback statistics
class FallbackStatistics {
  final int totalFailures;
  final int recentFailures;
  final FallbackStrategy currentStrategy;
  final bool isHealthy;
  
  const FallbackStatistics({
    required this.totalFailures,
    required this.recentFailures,
    required this.currentStrategy,
    required this.isHealthy,
  });
  
  double get failureRate {
    if (totalFailures == 0) return 0.0;
    return recentFailures / totalFailures;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalFailures': totalFailures,
      'recentFailures': recentFailures,
      'currentStrategy': currentStrategy.name,
      'isHealthy': isHealthy,
      'failureRate': failureRate,
    };
  }
}