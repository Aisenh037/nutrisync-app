import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../error/app_exception.dart';

/// Singleton Dio client used by all services that call external HTTP APIs.
///
/// Configured interceptors:
///   1. [_AuthInterceptor]    — injects Firebase ID token on every request
///   2. [_RetryInterceptor]   — retries on 5xx / network errors (up to 3×, exponential back-off)
///   3. [_LogInterceptor]     — logs requests + responses in debug only
class ApiClient {
  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  late final Dio _dio = _buildDio();

  Dio get dio => _dio;

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'NutriSync/1.0',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      _RetryInterceptor(dio),
      if (kDebugMode) _LogInterceptor(),
    ]);

    return dio;
  }
}

// ── Auth interceptor ──────────────────────────────────────────────────────────

/// Injects the current Firebase ID token as a Bearer header.
/// Skips injection for Google / GCP API key calls (they use query params).
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip token injection for external APIs that use API keys
    final skipHosts = [
      'maps.googleapis.com',
      'places.googleapis.com',
      'api.elevenlabs.io',
      'api.resend.com',
    ];
    final host = options.uri.host;
    if (skipHosts.any((h) => host.contains(h))) {
      return handler.next(options);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      if (kDebugMode) print('⚠ ApiClient: failed to get ID token: $e');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token may be expired — force refresh and retry once
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken(true); // force refresh
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          final resp = await Dio().fetch(opts);
          return handler.resolve(resp);
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}

// ── Retry interceptor ─────────────────────────────────────────────────────────

/// Retries failed requests up to [maxRetries] times with exponential back-off.
/// Retries on: network errors, 500, 502, 503, 504.
/// Does NOT retry on 4xx (client errors) except 429 (rate limit).
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;
  static const maxRetries = 3;

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final retryCount =
        (err.requestOptions.extra['retryCount'] as int?) ?? 0;

    final shouldRetry = retryCount < maxRetries &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            statusCode == 429 ||
            (statusCode != null && statusCode >= 500));

    if (shouldRetry) {
      final delay = Duration(milliseconds: 300 * (retryCount + 1));
      if (kDebugMode) {
        print('🔄 ApiClient: retry ${retryCount + 1}/$maxRetries '
            'after ${delay.inMilliseconds}ms (status: $statusCode)');
      }
      await Future.delayed(delay);
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      try {
        final resp = await _dio.fetch(err.requestOptions);
        return handler.resolve(resp);
      } catch (e) {
        return handler.next(err);
      }
    }

    // Convert DioException → AppException for callers
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: _toAppException(err),
      ),
    );
  }

  AppException _toAppException(DioException err) {
    final status = err.response?.statusCode;
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      return const NetworkException('No internet connection. Please check your network.');
    }
    if (err.type == DioExceptionType.receiveTimeout) {
      return const NetworkException('Request timed out. Please try again.');
    }
    if (status == 401) return const AuthException('Session expired. Please sign in again.');
    if (status == 403) return const AuthException('You don\'t have permission for this action.');
    if (status == 404) return const NetworkException('Resource not found.');
    if (status == 429) return const NetworkException('Too many requests. Please slow down.');
    if (status != null && status >= 500) {
      return const ServerException('Server error. Please try again later.');
    }
    return NetworkException('Unexpected error: ${err.message}');
  }
}

// ── Log interceptor ───────────────────────────────────────────────────────────

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('✗ ${err.response?.statusCode ?? 'ERR'} '
        '${err.requestOptions.uri} — ${err.message}');
    handler.next(err);
  }
}
