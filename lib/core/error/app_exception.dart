import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sealed base class for all application exceptions.
///
/// Usage:
///   throw const NetworkException('No internet');
///
/// Catching:
///   catch (e) {
///     if (e is AppException) showError(e.userMessage);
///   }
///
/// In Riverpod AsyncValue.error:
///   error: (e, _) => ErrorView(message: AppException.messageFor(e)),
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Developer-facing message (logged to Crashlytics).
  final String message;

  /// Optional error code from the backend/API.
  final String? code;

  /// Original exception that caused this, if any.
  final Object? cause;

  /// User-facing message — safe to show in the UI.
  String get userMessage => message;

  /// Log to Crashlytics (non-fatal) with structured context.
  void log({Map<String, String>? context}) {
    if (kDebugMode) print('[$runtimeType] $message (code: $code)');
    FirebaseCrashlytics.instance.recordError(
      this,
      StackTrace.current,
      reason: message,
      fatal: false,
      information: [
        DiagnosticsNode.message('type: $runtimeType'),
        DiagnosticsNode.message('code: ${code ?? 'none'}'),
        if (context != null)
          ...context.entries.map((e) => DiagnosticsNode.message('${e.key}: ${e.value}')),
      ],
    );
  }

  /// Returns a user-friendly message for any exception type.
  /// Handles both [AppException] subtypes and raw [Exception]s gracefully.
  static String messageFor(Object? error) {
    if (error is AppException) return error.userMessage;
    if (error is Exception) return 'Something went wrong. Please try again.';
    return 'An unexpected error occurred.';
  }

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

// ── Subtypes ──────────────────────────────────────────────────────────────────

/// Network / HTTP errors — connectivity, timeouts, non-2xx responses.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});

  @override
  String get userMessage {
    if (message.contains('internet') || message.contains('network')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (message.contains('timed out') || message.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return 'Network error. Please try again.';
  }
}

/// Firebase Auth errors — sign-in failures, token expiry, insufficient permissions.
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});

  @override
  String get userMessage {
    switch (code) {
      case 'user-not-found':     return 'No account found with this email.';
      case 'wrong-password':     return 'Incorrect password. Please try again.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password':      return 'Password is too weak. Use at least 8 characters.';
      case 'too-many-requests':  return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed': return 'Network error during sign-in. Check your connection.';
      default:                   return message;
    }
  }
}

/// Firestore / database read-write failures.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.cause});

  @override
  String get userMessage => 'Failed to save your data. Please try again.';
}

/// Remote server returned a 5xx error.
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.cause});

  @override
  String get userMessage => 'Our servers are having issues. Please try again later.';
}

/// AI / ML service failures (ElevenLabs, OpenAI, GCP Speech, Vision, etc.).
class AiServiceException extends AppException {
  const AiServiceException(super.message, {super.code, super.cause, this.service});
  final String? service;

  @override
  String get userMessage => 'AI assistant is temporarily unavailable. Please try again.';
}

/// Voice recording / playback / STT failures.
class VoiceException extends AppException {
  const VoiceException(super.message, {super.code, super.cause});

  @override
  String get userMessage => 'Voice feature unavailable. Check microphone permissions.';
}

/// Location / Maps / Places API failures.
class LocationException extends AppException {
  const LocationException(super.message, {super.code, super.cause});

  @override
  String get userMessage {
    if (message.contains('permission') || message.contains('denied')) {
      return 'Location permission denied. Enable it in Settings to find nearby stores.';
    }
    return 'Location unavailable. Please check your GPS settings.';
  }
}

/// Subscription / paywall enforcement failures.
class SubscriptionException extends AppException {
  const SubscriptionException(super.message, {super.code, super.cause});

  @override
  String get userMessage => 'This feature requires a premium subscription.';
}

/// Input validation failures — bad user data, missing required fields, etc.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});

  @override
  String get userMessage => message; // Validation messages are always user-safe
}

// ── Riverpod async error widget ───────────────────────────────────────────────

/// Drop-in widget for `AsyncValue.error` callbacks.
/// Shows the right message for every exception type.
///
/// Usage in a ConsumerWidget:
///   mealPlanAsync.when(
///     error: (e, _) => AsyncErrorView(error: e),
///     ...
///   )

class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = AppException.messageFor(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
