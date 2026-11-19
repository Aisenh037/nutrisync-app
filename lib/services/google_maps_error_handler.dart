import 'dart:convert';
import 'package:logging/logging.dart';
import 'google_maps_service.dart';

/// Enhanced error handler for Google Maps and Places API
class GoogleMapsErrorHandler {
  static GoogleMapsErrorHandler? _instance;
  static GoogleMapsErrorHandler get instance => _instance ??= GoogleMapsErrorHandler._();
  
  GoogleMapsErrorHandler._();
  
  final _logger = Logger('GoogleMapsErrorHandler');
  
  /// Handle API errors and provide appropriate responses
  GoogleMapsServiceException handleError(
    dynamic error, {
    int? statusCode,
    String? responseBody,
    String? operation,
  }) {
    _logger.warning('Handling Google Maps API error: $error (Status: $statusCode, Operation: $operation)');
    
    // Handle different types of errors
    if (error is GoogleMapsServiceException) {
      return error;
    }
    
    if (statusCode != null) {
      return _handleHttpError(statusCode, responseBody, operation);
    }
    
    if (error is Exception) {
      return _handleGeneralException(error, operation);
    }
    
    return GoogleMapsServiceException('Unknown error occurred: $error');
  }
  
  /// Handle HTTP status code errors
  GoogleMapsServiceException _handleHttpError(int statusCode, String? responseBody, String? operation) {
    final operationContext = operation != null ? ' during $operation' : '';
    
    switch (statusCode) {
      case 400:
        return _handleBadRequestError(responseBody, operationContext);
      
      case 401:
        return _handleAuthenticationError(responseBody, operationContext);
      
      case 403:
        return _handleAuthorizationError(responseBody, operationContext);
      
      case 404:
        return _handleNotFoundError(responseBody, operationContext);
      
      case 429:
        return _handleRateLimitError(responseBody, operationContext);
      
      case 500:
      case 502:
      case 503:
      case 504:
        return _handleServerError(statusCode, responseBody, operationContext);
      
      default:
        return GoogleMapsApiException(
          'HTTP error $statusCode$operationContext',
          statusCode: statusCode,
          responseBody: responseBody,
        );
    }
  }
  
  /// Handle bad request errors (400)
  GoogleMapsServiceException _handleBadRequestError(String? responseBody, String operationContext) {
    final errorDetails = _parseErrorDetails(responseBody);
    
    if (errorDetails.contains('invalid coordinates') || 
        errorDetails.contains('latitude') || 
        errorDetails.contains('longitude')) {
      return GoogleMapsApiException(
        'Invalid location coordinates provided$operationContext. '
        'Please check that latitude is between -90 and 90, and longitude is between -180 and 180.',
        statusCode: 400,
        responseBody: responseBody,
      );
    }
    
    if (errorDetails.contains('radius')) {
      return GoogleMapsApiException(
        'Invalid search radius provided$operationContext. '
        'Radius must be between 1 and 50000 meters.',
        statusCode: 400,
        responseBody: responseBody,
      );
    }
    
    if (errorDetails.contains('place_id') || errorDetails.contains('placeId')) {
      return GoogleMapsApiException(
        'Invalid place ID provided$operationContext. '
        'Please ensure the place ID is valid and not expired.',
        statusCode: 400,
        responseBody: responseBody,
      );
    }
    
    return GoogleMapsApiException(
      'Invalid request parameters$operationContext. '
      'Please check your input data and try again.',
      statusCode: 400,
      responseBody: responseBody,
    );
  }
  
  /// Handle authentication errors (401)
  GoogleMapsServiceException _handleAuthenticationError(String? responseBody, String operationContext) {
    final errorDetails = _parseErrorDetails(responseBody);
    
    if (errorDetails.contains('api key') || errorDetails.contains('key')) {
      return GoogleMapsConfigurationException(
        'Invalid Google Maps API key$operationContext. '
        'Please check your API key configuration.\n\n'
        'Setup instructions:\n'
        '1. Verify your API key is correct\n'
        '2. Ensure the key has not expired\n'
        '3. Check that the key has proper permissions\n'
        '4. Visit: https://console.cloud.google.com/apis/credentials'
      );
    }
    
    return GoogleMapsConfigurationException(
      'Authentication failed$operationContext. '
      'Please check your Google Maps API configuration.'
    );
  }
  
  /// Handle authorization errors (403)
  GoogleMapsServiceException _handleAuthorizationError(String? responseBody, String operationContext) {
    final errorDetails = _parseErrorDetails(responseBody);
    
    if (errorDetails.contains('quota') || errorDetails.contains('billing')) {
      return GoogleMapsApiException(
        'Google Maps API quota exceeded or billing not enabled$operationContext. '
        'Please check your Google Cloud Console:\n\n'
        '1. Verify billing is enabled for your project\n'
        '2. Check your API quotas and limits\n'
        '3. Consider upgrading your plan if needed\n'
        '4. Visit: https://console.cloud.google.com/billing',
        statusCode: 403,
        responseBody: responseBody,
      );
    }
    
    if (errorDetails.contains('restriction') || errorDetails.contains('referer')) {
      return GoogleMapsConfigurationException(
        'API key restrictions prevent access$operationContext. '
        'Please check your API key restrictions:\n\n'
        '1. Verify HTTP referrer restrictions\n'
        '2. Check IP address restrictions\n'
        '3. Ensure API is enabled for your key\n'
        '4. Visit: https://console.cloud.google.com/apis/credentials'
      );
    }
    
    if (errorDetails.contains('disabled') || errorDetails.contains('api')) {
      return GoogleMapsConfigurationException(
        'Google Maps API is not enabled$operationContext. '
        'Please enable the required APIs:\n\n'
        '1. Go to Google Cloud Console\n'
        '2. Enable Places API\n'
        '3. Enable Directions API (if using directions)\n'
        '4. Visit: https://console.cloud.google.com/apis/library'
      );
    }
    
    return GoogleMapsApiException(
      'Access denied$operationContext. '
      'Please check your API key permissions and restrictions.',
      statusCode: 403,
      responseBody: responseBody,
    );
  }
  
  /// Handle not found errors (404)
  GoogleMapsServiceException _handleNotFoundError(String? responseBody, String operationContext) {
    final errorDetails = _parseErrorDetails(responseBody);
    
    if (errorDetails.contains('place') || operationContext.contains('place details')) {
      return GoogleMapsApiException(
        'Place not found$operationContext. '
        'The requested place may no longer exist or the place ID may be invalid.',
        statusCode: 404,
        responseBody: responseBody,
      );
    }
    
    if (errorDetails.contains('route') || operationContext.contains('directions')) {
      return GoogleMapsApiException(
        'No route found$operationContext. '
        'Unable to find a route between the specified locations. '
        'Please check the coordinates and try different locations.',
        statusCode: 404,
        responseBody: responseBody,
      );
    }
    
    return GoogleMapsApiException(
      'Resource not found$operationContext. '
      'The requested resource could not be located.',
      statusCode: 404,
      responseBody: responseBody,
    );
  }
  
  /// Handle rate limit errors (429)
  GoogleMapsServiceException _handleRateLimitError(String? responseBody, String operationContext) {
    return GoogleMapsApiException(
      'Rate limit exceeded$operationContext. '
      'Too many requests have been made. Please try again later.\n\n'
      'Suggestions:\n'
      '1. Wait a few minutes before retrying\n'
      '2. Reduce the frequency of requests\n'
      '3. Consider caching results\n'
      '4. Check your quota limits in Google Cloud Console',
      statusCode: 429,
      responseBody: responseBody,
    );
  }
  
  /// Handle server errors (5xx)
  GoogleMapsServiceException _handleServerError(int statusCode, String? responseBody, String operationContext) {
    final errorMessage = statusCode == 503 
        ? 'Google Maps service is temporarily unavailable'
        : 'Google Maps server error';
    
    return GoogleMapsApiException(
      '$errorMessage$operationContext (Status: $statusCode). '
      'This is a temporary issue. Please try again in a few moments.\n\n'
      'If the problem persists:\n'
      '1. Check Google Cloud Status: https://status.cloud.google.com/\n'
      '2. Verify your internet connection\n'
      '3. Try again with a smaller request',
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }
  
  /// Handle general exceptions
  GoogleMapsServiceException _handleGeneralException(Exception error, String? operation) {
    final errorString = error.toString().toLowerCase();
    final operationContext = operation != null ? ' during $operation' : '';
    
    if (errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout')) {
      return GoogleMapsServiceException(
        'Network connection failed$operationContext. '
        'Please check your internet connection and try again.\n\n'
        'Troubleshooting:\n'
        '1. Verify internet connectivity\n'
        '2. Check if you\'re behind a firewall\n'
        '3. Try switching networks (WiFi/Mobile data)\n'
        '4. Restart the app if the problem persists'
      );
    }
    
    if (errorString.contains('cors') || errorString.contains('cross-origin')) {
      return GoogleMapsServiceException(
        'Cross-origin request blocked$operationContext. '
        'This is a web browser security restriction.\n\n'
        'Solutions:\n'
        '1. Use the mobile app instead of web browser\n'
        '2. Contact support for web access configuration\n'
        '3. Try using a different browser'
      );
    }
    
    if (errorString.contains('ssl') || errorString.contains('certificate')) {
      return GoogleMapsServiceException(
        'SSL certificate error$operationContext. '
        'There\'s an issue with the secure connection.\n\n'
        'Solutions:\n'
        '1. Check your device\'s date and time settings\n'
        '2. Update your app to the latest version\n'
        '3. Try connecting from a different network'
      );
    }
    
    return GoogleMapsServiceException(
      'An unexpected error occurred$operationContext: ${error.toString()}'
    );
  }
  
  /// Parse error details from response body
  String _parseErrorDetails(String? responseBody) {
    if (responseBody == null || responseBody.isEmpty) {
      return '';
    }
    
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      
      // Try different error message fields
      final errorFields = ['error', 'message', 'error_message', 'details'];
      
      for (final field in errorFields) {
        final value = json[field];
        if (value != null) {
          return value.toString().toLowerCase();
        }
      }
      
      // If no specific error field, return the whole response
      return responseBody.toLowerCase();
      
    } catch (e) {
      // If JSON parsing fails, return the raw response
      return responseBody.toLowerCase();
    }
  }
  
  /// Check if an error is retryable
  bool isRetryableError(GoogleMapsServiceException error) {
    if (error is GoogleMapsApiException) {
      final retryableStatusCodes = [429, 500, 502, 503, 504];
      return retryableStatusCodes.contains(error.statusCode);
    }
    
    final errorString = error.toString().toLowerCase();
    final retryablePatterns = [
      'network',
      'connection',
      'timeout',
      'temporary',
      'unavailable',
      'server error',
    ];
    
    return retryablePatterns.any((pattern) => errorString.contains(pattern));
  }
  
  /// Get retry delay for an error
  Duration getRetryDelay(GoogleMapsServiceException error, int attemptNumber) {
    if (error is GoogleMapsApiException && error.statusCode == 429) {
      // For rate limiting, use longer delays
      return Duration(seconds: (attemptNumber * 30).clamp(30, 300));
    }
    
    // For other retryable errors, use exponential backoff
    final baseDelay = Duration(seconds: 2);
    final exponentialDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * (1 << (attemptNumber - 1))).clamp(
        baseDelay.inMilliseconds,
        60000, // Max 60 seconds
      ),
    );
    
    return exponentialDelay;
  }
  
  /// Get user-friendly error message
  String getUserFriendlyMessage(GoogleMapsServiceException error) {
    if (error is GoogleMapsConfigurationException) {
      return 'Configuration issue detected. Please check your settings or contact support.';
    }
    
    if (error is GoogleMapsApiException) {
      switch (error.statusCode) {
        case 400:
          return 'Invalid request. Please check your input and try again.';
        case 401:
        case 403:
          return 'Access denied. Please check your account settings.';
        case 404:
          return 'Location not found. Please try a different search.';
        case 429:
          return 'Too many requests. Please wait a moment and try again.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Service temporarily unavailable. Please try again later.';
      }
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet and try again.';
    }
    
    if (errorString.contains('cors')) {
      return 'Browser security restriction. Please try using the mobile app.';
    }
    
    return 'An error occurred. Please try again or contact support if the problem persists.';
  }
}