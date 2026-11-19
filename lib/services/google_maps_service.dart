import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../config/api_configuration_manager.dart';
import 'retry_manager.dart';

/// Enhanced Google Maps and Places API service with CORS handling and proper error management
class GoogleMapsService {
  static GoogleMapsService? _instance;
  static GoogleMapsService get instance => _instance ??= GoogleMapsService._();
  
  GoogleMapsService._();
  
  final _logger = Logger('GoogleMapsService');
  final _retryManager = RetryManager.instance;
  
  String? _apiKey;
  String? _functionsBaseUrl;
  bool _isInitialized = false;
  
  /// Initialize the Google Maps service with proper configuration
  Future<void> initialize() async {
    try {
      final config = await ApiConfigurationManager.instance.getGoogleMapsConfig();
      _apiKey = config['apiKey'] as String?;
      _functionsBaseUrl = config['functionsBaseUrl'] as String?;
      
      if (_apiKey == null || _apiKey!.isEmpty || _apiKey!.contains('YOUR_')) {
        throw GoogleMapsConfigurationException('Invalid or missing Google Maps API key');
      }
      
      if (_functionsBaseUrl == null || _functionsBaseUrl!.isEmpty) {
        throw GoogleMapsConfigurationException('Invalid or missing Firebase Functions base URL');
      }
      
      _isInitialized = true;
      _logger.info('Google Maps Service initialized successfully');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Google Maps Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Find nearby places with CORS handling for web deployment
  Future<PlacesSearchResult> findNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 5000,
    List<String> types = const ['grocery_or_supermarket', 'health', 'store'],
    int maxResults = 20,
  }) async {
    if (!_isInitialized) {
      throw GoogleMapsServiceException('Service not initialized. Call initialize() first.');
    }
    
    try {
      final requestBody = {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'storeTypes': types,
        'maxResults': maxResults,
      };
      
      _logger.info('Searching for places near $latitude, $longitude');
      
      final response = await _retryManager.executeWithRetry(() async {
        return await _makeRequest(
          '$_functionsBaseUrl/findNearbyStores',
          method: 'POST',
          body: requestBody,
        );
      });
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return PlacesSearchResult.fromJson(responseData);
      } else {
        throw GoogleMapsApiException(
          'Places search failed: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } catch (e, stackTrace) {
      _logger.severe('Places search failed: $e', e, stackTrace);
      
      if (e is GoogleMapsApiException) {
        rethrow;
      }
      
      throw GoogleMapsServiceException('Places search failed: $e');
    }
  }
  
  /// Get place details with proper error handling
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    if (!_isInitialized) {
      throw GoogleMapsServiceException('Service not initialized. Call initialize() first.');
    }
    
    try {
      _logger.info('Getting details for place: $placeId');
      
      final response = await _retryManager.executeWithRetry(() async {
        return await _makeRequest(
          '$_functionsBaseUrl/getStoreDetails?placeId=$placeId',
          method: 'GET',
        );
      });
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return PlaceDetails.fromJson(responseData);
      } else {
        throw GoogleMapsApiException(
          'Place details failed: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } catch (e, stackTrace) {
      _logger.severe('Place details failed: $e', e, stackTrace);
      
      if (e is GoogleMapsApiException) {
        rethrow;
      }
      
      throw GoogleMapsServiceException('Place details failed: $e');
    }
  }
  
  /// Get directions with retry mechanisms
  Future<DirectionsResult> getDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String travelMode = 'driving',
  }) async {
    if (!_isInitialized) {
      throw GoogleMapsServiceException('Service not initialized. Call initialize() first.');
    }
    
    try {
      final requestBody = {
        'originLat': originLat,
        'originLng': originLng,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'travelMode': travelMode,
      };
      
      _logger.info('Getting directions from $originLat,$originLng to $destinationLat,$destinationLng');
      
      final response = await _retryManager.executeWithRetry(() async {
        return await _makeRequest(
          '$_functionsBaseUrl/getDirections',
          method: 'POST',
          body: requestBody,
        );
      });
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return DirectionsResult.fromJson(responseData);
      } else {
        throw GoogleMapsApiException(
          'Directions failed: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } catch (e, stackTrace) {
      _logger.severe('Directions failed: $e', e, stackTrace);
      
      if (e is GoogleMapsApiException) {
        rethrow;
      }
      
      throw GoogleMapsServiceException('Directions failed: $e');
    }
  }
  
  /// Test service connectivity
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Test with a simple places search
      final result = await findNearbyPlaces(
        latitude: 37.7749, // San Francisco coordinates for testing
        longitude: -122.4194,
        radius: 1000,
        maxResults: 1,
      );
      
      return result.places.isNotEmpty || result.totalFound >= 0;
      
    } catch (e) {
      _logger.warning('Connection test failed: $e');
      return false;
    }
  }
  
  /// Make HTTP request with CORS handling for web deployment
  Future<http.Response> _makeRequest(
    String url, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = _buildHeaders();
      
      // Handle CORS for web deployment
      if (kIsWeb) {
        return await _makeWebRequest(url, method: method, headers: headers, body: body);
      } else {
        return await _makeMobileRequest(url, method: method, headers: headers, body: body);
      }
      
    } catch (e) {
      _logger.warning('Failed to make request to $url: $e');
      rethrow;
    }
  }
  
  /// Make request for web platform with CORS handling
  Future<http.Response> _makeWebRequest(
    String url, {
    required String method,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      // For web deployment, we might need to use a proxy or handle CORS differently
      // Add CORS headers for web requests
      final webHeaders = {
        ...headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };
      
      if (method.toUpperCase() == 'GET') {
        return await http.get(Uri.parse(url), headers: webHeaders);
      } else {
        return await http.post(
          Uri.parse(url),
          headers: webHeaders,
          body: body != null ? json.encode(body) : null,
        );
      }
      
    } catch (e) {
      // If CORS fails, try using a proxy endpoint
      if (e.toString().contains('CORS') || e.toString().contains('Cross-Origin')) {
        _logger.info('CORS error detected, attempting proxy request');
        return await _makeProxyRequest(url, method: method, headers: headers, body: body);
      }
      rethrow;
    }
  }
  
  /// Make request for mobile platforms (no CORS issues)
  Future<http.Response> _makeMobileRequest(
    String url, {
    required String method,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    if (method.toUpperCase() == 'GET') {
      return await http.get(Uri.parse(url), headers: headers);
    } else {
      return await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
    }
  }
  
  /// Make request through proxy to handle CORS issues
  Future<http.Response> _makeProxyRequest(
    String url, {
    required String method,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    // This would use a CORS proxy service or a custom proxy endpoint
    // For now, we'll try the original request and let it fail gracefully
    _logger.warning('Proxy request not implemented, falling back to direct request');
    
    if (method.toUpperCase() == 'GET') {
      return await http.get(Uri.parse(url), headers: headers);
    } else {
      return await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
    }
  }
  
  /// Build request headers
  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'NutriSync/1.0',
    };
  }
}

/// Exception classes for Google Maps service
class GoogleMapsServiceException implements Exception {
  final String message;
  
  GoogleMapsServiceException(this.message);
  
  @override
  String toString() => 'GoogleMapsServiceException: $message';
}

class GoogleMapsConfigurationException extends GoogleMapsServiceException {
  GoogleMapsConfigurationException(String message) : super(message);
  
  @override
  String toString() => 'GoogleMapsConfigurationException: $message';
}

class GoogleMapsApiException extends GoogleMapsServiceException {
  final int? statusCode;
  final String? responseBody;
  
  GoogleMapsApiException(
    String message, {
    this.statusCode,
    this.responseBody,
  }) : super(message);
  
  @override
  String toString() => 'GoogleMapsApiException: $message (Status: $statusCode)';
}

/// Data models for Google Maps service
class PlacesSearchResult {
  final List<Place> places;
  final SearchParams searchParams;
  final int totalFound;
  final String timestamp;
  final String? error;

  PlacesSearchResult({
    required this.places,
    required this.searchParams,
    required this.totalFound,
    required this.timestamp,
    this.error,
  });

  factory PlacesSearchResult.fromJson(Map<String, dynamic> json) {
    final placesJson = json['stores'] as List<dynamic>? ?? [];
    final places = placesJson
        .map((place) => Place.fromJson(place as Map<String, dynamic>))
        .toList();

    return PlacesSearchResult(
      places: places,
      searchParams: SearchParams.fromJson(json['searchParams'] as Map<String, dynamic>? ?? {}),
      totalFound: json['totalFound'] as int? ?? 0,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      error: json['error'] as String?,
    );
  }
}

class SearchParams {
  final LocationCoordinates location;
  final double radius;
  final List<String> types;
  final int maxResults;

  SearchParams({
    required this.location,
    required this.radius,
    required this.types,
    required this.maxResults,
  });

  factory SearchParams.fromJson(Map<String, dynamic> json) {
    return SearchParams(
      location: LocationCoordinates.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      radius: (json['radius'] as num?)?.toDouble() ?? 5000.0,
      types: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      maxResults: json['maxResults'] as int? ?? 20,
    );
  }
}

class Place {
  final String id;
  final String name;
  final String address;
  final LocationCoordinates location;
  final int distance;
  final double rating;
  final int userRatingsTotal;
  final List<String> types;
  final Map<String, dynamic>? metadata;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.distance,
    required this.rating,
    required this.userRatingsTotal,
    required this.types,
    this.metadata,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      location: LocationCoordinates.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      distance: json['distance'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['userRatingsTotal'] as int? ?? 0,
      types: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class LocationCoordinates {
  final double latitude;
  final double longitude;

  LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) {
    return LocationCoordinates(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PlaceDetails {
  final String id;
  final String name;
  final String address;
  final LocationCoordinates location;
  final double rating;
  final int userRatingsTotal;
  final int? priceLevel;
  final String? phoneNumber;
  final String? website;
  final OpeningHours? openingHours;
  final List<String> types;
  final List<PlacePhoto> photos;
  final List<PlaceReview> reviews;
  final String? error;

  PlaceDetails({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.rating,
    required this.userRatingsTotal,
    this.priceLevel,
    this.phoneNumber,
    this.website,
    this.openingHours,
    required this.types,
    this.photos = const [],
    this.reviews = const [],
    this.error,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final photos = photosJson
        .map((photo) => PlacePhoto.fromJson(photo as Map<String, dynamic>))
        .toList();

    final reviewsJson = json['reviews'] as List<dynamic>? ?? [];
    final reviews = reviewsJson
        .map((review) => PlaceReview.fromJson(review as Map<String, dynamic>))
        .toList();

    return PlaceDetails(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      location: LocationCoordinates.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['userRatingsTotal'] as int? ?? 0,
      priceLevel: json['priceLevel'] as int?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      openingHours: json['openingHours'] != null
          ? OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>)
          : null,
      types: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      photos: photos,
      reviews: reviews,
      error: json['error'] as String?,
    );
  }
}

class OpeningHours {
  final bool openNow;
  final List<String>? weekdayText;

  OpeningHours({
    required this.openNow,
    this.weekdayText,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      openNow: json['openNow'] as bool? ?? false,
      weekdayText: (json['weekdayText'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

class PlacePhoto {
  final String reference;
  final int width;
  final int height;

  PlacePhoto({
    required this.reference,
    required this.width,
    required this.height,
  });

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    return PlacePhoto(
      reference: json['reference'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }
}

class PlaceReview {
  final String authorName;
  final double rating;
  final String text;
  final int time;

  PlaceReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.time,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      authorName: json['authorName'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
      time: json['time'] as int? ?? 0,
    );
  }
}

class DirectionsResult {
  final DistanceInfo distance;
  final DurationInfo duration;
  final String startAddress;
  final String endAddress;
  final List<DirectionStep> steps;
  final String polyline;
  final String travelMode;
  final String? error;

  DirectionsResult({
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.polyline,
    required this.travelMode,
    this.error,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    final steps = stepsJson
        .map((step) => DirectionStep.fromJson(step as Map<String, dynamic>))
        .toList();

    return DirectionsResult(
      distance: DistanceInfo.fromJson(json['distance'] as Map<String, dynamic>? ?? {}),
      duration: DurationInfo.fromJson(json['duration'] as Map<String, dynamic>? ?? {}),
      startAddress: json['startAddress'] as String? ?? '',
      endAddress: json['endAddress'] as String? ?? '',
      steps: steps,
      polyline: json['polyline'] as String? ?? '',
      travelMode: json['travelMode'] as String? ?? 'driving',
      error: json['error'] as String?,
    );
  }
}

class DistanceInfo {
  final String text;
  final int value;

  DistanceInfo({
    required this.text,
    required this.value,
  });

  factory DistanceInfo.fromJson(Map<String, dynamic> json) {
    return DistanceInfo(
      text: json['text'] as String? ?? '',
      value: json['value'] as int? ?? 0,
    );
  }
}

class DurationInfo {
  final String text;
  final int value;

  DurationInfo({
    required this.text,
    required this.value,
  });

  factory DurationInfo.fromJson(Map<String, dynamic> json) {
    return DurationInfo(
      text: json['text'] as String? ?? '',
      value: json['value'] as int? ?? 0,
    );
  }
}

class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final LocationCoordinates startLocation;
  final LocationCoordinates endLocation;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  factory DirectionStep.fromJson(Map<String, dynamic> json) {
    return DirectionStep(
      instruction: json['instruction'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      startLocation: LocationCoordinates.fromJson(json['startLocation'] as Map<String, dynamic>? ?? {}),
      endLocation: LocationCoordinates.fromJson(json['endLocation'] as Map<String, dynamic>? ?? {}),
    );
  }
}