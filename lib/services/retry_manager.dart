import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Retry Manager with Exponential Backoff
/// Handles retry logic with configurable backoff strategies
class RetryManager {
  static RetryManager? _instance;
  static RetryManager get instance => _instance ??= RetryManager._();
  
  RetryManager._();
  
  /// Execute a function with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    int attempt = 0;
    Exception? lastException;
    
    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(lastException)) {
          rethrow;
        }
        
        // If this was the last attempt, rethrow
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        // Calculate delay for next attempt
        final delay = _calculateDelay(
          attempt,
          initialDelay,
          backoffMultiplier,
          maxDelay,
        );
        
        // Call retry callback if provided
        onRetry?.call(attempt + 1, lastException);
        
        if (kDebugMode) {
          print('⚠ Attempt ${attempt + 1} failed, retrying in ${delay.inMilliseconds}ms: $e');
        }
        
        // Wait before retrying
        await Future.delayed(delay);
        attempt++;
      }
    }
    
    // This should never be reached, but just in case
    throw lastException ?? Exception('Unknown error during retry');
  }
  
  /// Calculate exponential backoff delay
  Duration _calculateDelay(
    int attempt,
    Duration initialDelay,
    double backoffMultiplier,
    Duration maxDelay,
  ) {
    final delayMs = initialDelay.inMilliseconds * math.pow(backoffMultiplier, attempt);
    final clampedDelayMs = delayMs.clamp(
      initialDelay.inMilliseconds.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );
    
    return Duration(milliseconds: clampedDelayMs.round());
  }
  
  /// Execute with jittered exponential backoff
  Future<T> executeWithJitteredRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    double jitterFactor = 0.1,
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    return executeWithRetry<T>(
      operation,
      maxRetries: maxRetries,
      initialDelay: _addJitter(initialDelay, jitterFactor),
      backoffMultiplier: backoffMultiplier,
      maxDelay: maxDelay,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
  
  /// Add jitter to delay to avoid thundering herd
  Duration _addJitter(Duration delay, double jitterFactor) {
    final jitterMs = delay.inMilliseconds * jitterFactor * (math.Random().nextDouble() - 0.5) * 2;
    final newDelayMs = delay.inMilliseconds + jitterMs.round();
    return Duration(milliseconds: math.max(0, newDelayMs));
  }
  
  /// Create a retry configuration for rate limiting
  RetryConfig rateLimitRetryConfig({
    int maxRetries = 5,
    Duration initialDelay = const Duration(seconds: 1),
  }) {
    return RetryConfig(
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      backoffMultiplier: 2.0,
      maxDelay: const Duration(minutes: 2),
      shouldRetry: (error) {
        // Retry on rate limit errors (429) and server errors (5xx)
        if (error.toString().contains('429')) return true;
        if (error.toString().contains('5')) return true;
        return false;
      },
    );
  }
  
  /// Create a retry configuration for authentication errors
  RetryConfig authRetryConfig({
    int maxRetries = 2,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) {
    return RetryConfig(
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      backoffMultiplier: 1.5,
      maxDelay: const Duration(seconds: 5),
      shouldRetry: (error) {
        // Only retry on 401 errors (might be temporary token issues)
        return error.toString().contains('401');
      },
    );
  }
  
  /// Create a retry configuration for network errors
  RetryConfig networkRetryConfig({
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) {
    return RetryConfig(
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 30),
      shouldRetry: (error) {
        final errorStr = error.toString().toLowerCase();
        // Retry on network-related errors
        return errorStr.contains('timeout') ||
               errorStr.contains('connection') ||
               errorStr.contains('network') ||
               errorStr.contains('socket');
      },
    );
  }
  
  /// Execute with predefined retry configuration
  Future<T> executeWithConfig<T>(
    Future<T> Function() operation,
    RetryConfig config, {
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    return executeWithRetry<T>(
      operation,
      maxRetries: config.maxRetries,
      initialDelay: config.initialDelay,
      backoffMultiplier: config.backoffMultiplier,
      maxDelay: config.maxDelay,
      shouldRetry: config.shouldRetry,
      onRetry: onRetry,
    );
  }
}

/// Retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool Function(Exception)? shouldRetry;
  
  const RetryConfig({
    required this.maxRetries,
    required this.initialDelay,
    required this.backoffMultiplier,
    required this.maxDelay,
    this.shouldRetry,
  });
  
  /// Create a copy with updated values
  RetryConfig copyWith({
    int? maxRetries,
    Duration? initialDelay,
    double? backoffMultiplier,
    Duration? maxDelay,
    bool Function(Exception)? shouldRetry,
  }) {
    return RetryConfig(
      maxRetries: maxRetries ?? this.maxRetries,
      initialDelay: initialDelay ?? this.initialDelay,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
      maxDelay: maxDelay ?? this.maxDelay,
      shouldRetry: shouldRetry ?? this.shouldRetry,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'maxRetries': maxRetries,
      'initialDelay': initialDelay.inMilliseconds,
      'backoffMultiplier': backoffMultiplier,
      'maxDelay': maxDelay.inMilliseconds,
    };
  }
}

/// Retry statistics
class RetryStatistics {
  final int totalAttempts;
  final int successfulRetries;
  final int failedRetries;
  final Duration totalRetryTime;
  final Map<String, int> errorCounts;
  
  const RetryStatistics({
    required this.totalAttempts,
    required this.successfulRetries,
    required this.failedRetries,
    required this.totalRetryTime,
    required this.errorCounts,
  });
  
  double get successRate {
    if (totalAttempts == 0) return 0.0;
    return successfulRetries / totalAttempts;
  }
  
  double get retryRate {
    if (totalAttempts == 0) return 0.0;
    return (successfulRetries + failedRetries) / totalAttempts;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalAttempts': totalAttempts,
      'successfulRetries': successfulRetries,
      'failedRetries': failedRetries,
      'totalRetryTime': totalRetryTime.inMilliseconds,
      'errorCounts': errorCounts,
      'successRate': successRate,
      'retryRate': retryRate,
    };
  }
}