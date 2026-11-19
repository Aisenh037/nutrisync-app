import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Service for Google Maps and Places API integration
class MapsIntegrationService {
  static MapsIntegrationService? _instance;
  static MapsIntegrationService get instance => _instance ??= MapsIntegrationService._();
  
  MapsIntegrationService._();
  
  final _logger = Logger('MapsIntegrationService');
  String? _functionsBaseUrl;
  
  /// Initialize the maps integration service
  Future<void> initialize() async {
    try {
      // Get the Firebase Functions base URL
      _functionsBaseUrl = _getFunctionsBaseUrl();
      
      _logger.info('Maps Integration Service initialized');
      _logger.info('Functions URL: $_functionsBaseUrl');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Maps Integration Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Find nearby grocery stores based on location and dietary preferences
  Future<StoreSearchResult> findNearbyStores({
    required double latitude,
    required double longitude,
    double radius = 5000, // Default 5km radius
    List<String> storeTypes = const ['grocery_or_supermarket', 'health', 'store'],
    List<String> dietaryPreferences = const [],
    int maxResults = 20,
  }) async {
    try {
      if (_functionsBaseUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'storeTypes': storeTypes,
        'dietaryPreferences': dietaryPreferences,
        'maxResults': maxResults,
      };
      
      _logger.info('Searching for stores near $latitude, $longitude');
      
      final response = await _makeAuthenticatedRequest(
        '$_functionsBaseUrl/findNearbyStores',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return StoreSearchResult.fromJson(responseData);
      } else {
        throw Exception('Store search failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Store search failed: $e', e, stackTrace);
      return StoreSearchResult(
        stores: [],
        searchParams: StoreSearchParams(
          location: LocationCoordinates(latitude: latitude, longitude: longitude),
          radius: radius,
          storeTypes: storeTypes,
          dietaryPreferences: dietaryPreferences,
          maxResults: maxResults,
        ),
        totalFound: 0,
        timestamp: DateTime.now().toIso8601String(),
        error: 'Store search failed: $e',
      );
    }
  }
  
  /// Get detailed information about a specific store
  Future<StoreDetails> getStoreDetails(String placeId) async {
    try {
      if (_functionsBaseUrl == null) {
        throw Exception('Service not initialized');
      }
      
      _logger.info('Getting details for store: $placeId');
      
      final response = await _makeAuthenticatedRequest(
        '$_functionsBaseUrl/getStoreDetails?placeId=$placeId',
        null,
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return StoreDetails.fromJson(responseData);
      } else {
        throw Exception('Store details failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Store details failed: $e', e, stackTrace);
      return StoreDetails(
        id: placeId,
        name: 'Unknown Store',
        address: 'Address not available',
        location: LocationCoordinates(latitude: 0.0, longitude: 0.0),
        rating: 0.0,
        userRatingsTotal: 0,
        storeTypes: [],
        photos: [],
        reviews: [],
        error: 'Store details failed: $e',
      );
    }
  }
  
  /// Get navigation directions to a store
  Future<NavigationDirections> getDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String travelMode = 'driving',
  }) async {
    try {
      if (_functionsBaseUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'originLat': originLat,
        'originLng': originLng,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'travelMode': travelMode,
      };
      
      _logger.info('Getting directions from $originLat,$originLng to $destinationLat,$destinationLng');
      
      final response = await _makeAuthenticatedRequest(
        '$_functionsBaseUrl/getDirections',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return NavigationDirections.fromJson(responseData);
      } else {
        throw Exception('Directions failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Directions failed: $e', e, stackTrace);
      return NavigationDirections(
        distance: DistanceInfo(text: 'Unknown', value: 0),
        duration: DurationInfo(text: 'Unknown', value: 0),
        startAddress: 'Unknown',
        endAddress: 'Unknown',
        steps: [],
        polyline: '',
        travelMode: travelMode,
        error: 'Directions failed: $e',
      );
    }
  }
  
  /// Search for stores with specific dietary requirements
  Future<StoreSearchResult> searchStoresForDiet({
    required double latitude,
    required double longitude,
    required List<String> dietaryRequirements,
    double radius = 10000, // Larger radius for specialized stores
    int maxResults = 15,
  }) async {
    // Enhanced store types for dietary requirements
    final enhancedStoreTypes = [
      'grocery_or_supermarket',
      'health',
      'store',
      'food',
      'supermarket',
    ];
    
    return await findNearbyStores(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      storeTypes: enhancedStoreTypes,
      dietaryPreferences: dietaryRequirements,
      maxResults: maxResults,
    );
  }
  
  /// Find stores optimized for shopping lists
  Future<StoreSearchResult> findOptimalStoresForShopping({
    required double latitude,
    required double longitude,
    required List<String> shoppingItems,
    List<String> dietaryPreferences = const [],
    double radius = 8000,
    int maxResults = 10,
  }) async {
    try {
      // Determine optimal store types based on shopping items
      final storeTypes = _determineOptimalStoreTypes(shoppingItems);
      
      final result = await findNearbyStores(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        storeTypes: storeTypes,
        dietaryPreferences: dietaryPreferences,
        maxResults: maxResults,
      );
      
      // Enhance results with shopping optimization scores
      final enhancedStores = result.stores.map((store) {
        final optimizationScore = _calculateShoppingOptimizationScore(store, shoppingItems);
        return store.copyWith(
          metadata: {
            ...store.metadata ?? {},
            'shopping_optimization_score': optimizationScore,
            'recommended_for_items': _getRecommendedItems(store, shoppingItems),
          },
        );
      }).toList();
      
      // Sort by optimization score
      enhancedStores.sort((a, b) {
        final scoreA = a.metadata?['shopping_optimization_score'] as double? ?? 0.0;
        final scoreB = b.metadata?['shopping_optimization_score'] as double? ?? 0.0;
        return scoreB.compareTo(scoreA);
      });
      
      return result.copyWith(stores: enhancedStores);
      
    } catch (e, stackTrace) {
      _logger.severe('Optimal store search failed: $e', e, stackTrace);
      return StoreSearchResult(
        stores: [],
        searchParams: StoreSearchParams(
          location: LocationCoordinates(latitude: latitude, longitude: longitude),
          radius: radius,
          storeTypes: [],
          dietaryPreferences: dietaryPreferences,
          maxResults: maxResults,
        ),
        totalFound: 0,
        timestamp: DateTime.now().toIso8601String(),
        error: 'Optimal store search failed: $e',
      );
    }
  }
  
  /// Test connection to Firebase Functions
  Future<bool> testConnection() async {
    try {
      if (_functionsBaseUrl == null) {
        return false;
      }
      
      // Test with a simple store search
      final result = await findNearbyStores(
        latitude: 37.7749, // San Francisco coordinates for testing
        longitude: -122.4194,
        radius: 1000,
        maxResults: 1,
      );
      
      return result.error == null;
    } catch (e) {
      _logger.warning('Connection test failed: $e');
      return false;
    }
  }
  
  /// Get the Firebase Functions base URL
  String _getFunctionsBaseUrl() {
    // For now, use a default project configuration
    // This should be configured based on your Firebase project
    const projectId = 'nutrisync-ai'; // Replace with your actual project ID
    const region = 'us-central1'; // Replace with your actual region
    
    // Firebase Functions URL format
    return 'https://$region-$projectId.cloudfunctions.net';
  }
  
  /// Determine optimal store types based on shopping items
  List<String> _determineOptimalStoreTypes(List<String> shoppingItems) {
    final baseTypes = ['grocery_or_supermarket', 'supermarket', 'store'];
    
    // Check for specialty items
    final itemsLower = shoppingItems.map((item) => item.toLowerCase()).toList();
    
    if (itemsLower.any((item) => 
        item.contains('organic') || item.contains('natural') || item.contains('health'))) {
      baseTypes.add('health');
    }
    
    if (itemsLower.any((item) => 
        item.contains('pharmacy') || item.contains('vitamin') || item.contains('supplement'))) {
      baseTypes.add('pharmacy');
    }
    
    if (itemsLower.any((item) => 
        item.contains('bakery') || item.contains('bread') || item.contains('cake'))) {
      baseTypes.add('bakery');
    }
    
    return baseTypes;
  }
  
  /// Calculate shopping optimization score for a store
  double _calculateShoppingOptimizationScore(StoreInfo store, List<String> shoppingItems) {
    double score = 0.5; // Base score
    
    // Higher score for larger stores (likely to have more items)
    if (store.storeTypes.contains('grocery_or_supermarket') || 
        store.storeTypes.contains('supermarket')) {
      score += 0.3;
    }
    
    // Bonus for high ratings
    if (store.rating > 4.0) {
      score += 0.1;
    }
    
    // Bonus for health stores if health items are in the list
    final itemsLower = shoppingItems.map((item) => item.toLowerCase()).toList();
    if (store.storeTypes.contains('health') && 
        itemsLower.any((item) => item.contains('organic') || item.contains('health'))) {
      score += 0.2;
    }
    
    // Distance penalty (closer is better)
    if (store.distance < 2000) { // Within 2km
      score += 0.1;
    } else if (store.distance > 10000) { // More than 10km
      score -= 0.2;
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Get recommended items for a store based on shopping list
  List<String> _getRecommendedItems(StoreInfo store, List<String> shoppingItems) {
    final recommended = <String>[];
    
    // All items are potentially available at grocery stores
    if (store.storeTypes.contains('grocery_or_supermarket') || 
        store.storeTypes.contains('supermarket')) {
      recommended.addAll(shoppingItems);
    }
    
    // Health stores for organic/health items
    if (store.storeTypes.contains('health')) {
      final healthItems = shoppingItems.where((item) => 
          item.toLowerCase().contains('organic') || 
          item.toLowerCase().contains('health') ||
          item.toLowerCase().contains('vitamin')).toList();
      recommended.addAll(healthItems);
    }
    
    return recommended;
  }
  
  /// Make authenticated HTTP request to Firebase Functions
  Future<http.Response> _makeAuthenticatedRequest(
    String url,
    Map<String, dynamic>? body, {
    String method = 'POST',
  }) async {
    try {
      // For now, use basic headers without authentication
      // In production, this should use proper Firebase authentication
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (method == 'GET') {
        return await http.get(Uri.parse(url), headers: headers);
      } else {
        return await http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      }
    } catch (e) {
      _logger.warning('Failed to make request: $e');
      rethrow;
    }
  }
}

/// Result classes for the maps integration service

class StoreSearchResult {
  final List<StoreInfo> stores;
  final StoreSearchParams searchParams;
  final int totalFound;
  final String timestamp;
  final String? error;

  StoreSearchResult({
    required this.stores,
    required this.searchParams,
    required this.totalFound,
    required this.timestamp,
    this.error,
  });

  factory StoreSearchResult.fromJson(Map<String, dynamic> json) {
    final storesJson = json['stores'] as List<dynamic>? ?? [];
    final stores = storesJson
        .map((store) => StoreInfo.fromJson(store as Map<String, dynamic>))
        .toList();

    return StoreSearchResult(
      stores: stores,
      searchParams: StoreSearchParams.fromJson(json['searchParams'] as Map<String, dynamic>? ?? {}),
      totalFound: json['totalFound'] as int? ?? 0,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      error: json['error'] as String?,
    );
  }

  StoreSearchResult copyWith({
    List<StoreInfo>? stores,
    StoreSearchParams? searchParams,
    int? totalFound,
    String? timestamp,
    String? error,
  }) {
    return StoreSearchResult(
      stores: stores ?? this.stores,
      searchParams: searchParams ?? this.searchParams,
      totalFound: totalFound ?? this.totalFound,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
    );
  }
}

class StoreSearchParams {
  final LocationCoordinates location;
  final double radius;
  final List<String> storeTypes;
  final List<String> dietaryPreferences;
  final int maxResults;

  StoreSearchParams({
    required this.location,
    required this.radius,
    required this.storeTypes,
    required this.dietaryPreferences,
    required this.maxResults,
  });

  factory StoreSearchParams.fromJson(Map<String, dynamic> json) {
    return StoreSearchParams(
      location: LocationCoordinates.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      radius: (json['radius'] as num?)?.toDouble() ?? 5000.0,
      storeTypes: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      dietaryPreferences: (json['dietaryPreferences'] as List<dynamic>?)?.cast<String>() ?? [],
      maxResults: json['maxResults'] as int? ?? 20,
    );
  }
}

class StoreInfo {
  final String id;
  final String name;
  final String address;
  final LocationCoordinates location;
  final int distance;
  final double rating;
  final int userRatingsTotal;
  final int? priceLevel;
  final String? phoneNumber;
  final String? website;
  final OpeningHours? openingHours;
  final List<String> storeTypes;
  final DietaryCompatibility dietaryCompatibility;
  final List<StorePhoto> photos;
  final Map<String, dynamic>? metadata;

  StoreInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.distance,
    required this.rating,
    required this.userRatingsTotal,
    this.priceLevel,
    this.phoneNumber,
    this.website,
    this.openingHours,
    required this.storeTypes,
    required this.dietaryCompatibility,
    this.photos = const [],
    this.metadata,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final photos = photosJson
        .map((photo) => StorePhoto.fromJson(photo as Map<String, dynamic>))
        .toList();

    return StoreInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      location: LocationCoordinates.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      distance: json['distance'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['userRatingsTotal'] as int? ?? 0,
      priceLevel: json['priceLevel'] as int?,
      phoneNumber: json['phoneNumber'] as String?,
      website: json['website'] as String?,
      openingHours: json['openingHours'] != null
          ? OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>)
          : null,
      storeTypes: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      dietaryCompatibility: DietaryCompatibility.fromJson(
          json['dietaryCompatibility'] as Map<String, dynamic>? ?? {}),
      photos: photos,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  StoreInfo copyWith({
    String? id,
    String? name,
    String? address,
    LocationCoordinates? location,
    int? distance,
    double? rating,
    int? userRatingsTotal,
    int? priceLevel,
    String? phoneNumber,
    String? website,
    OpeningHours? openingHours,
    List<String>? storeTypes,
    DietaryCompatibility? dietaryCompatibility,
    List<StorePhoto>? photos,
    Map<String, dynamic>? metadata,
  }) {
    return StoreInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      priceLevel: priceLevel ?? this.priceLevel,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      storeTypes: storeTypes ?? this.storeTypes,
      dietaryCompatibility: dietaryCompatibility ?? this.dietaryCompatibility,
      photos: photos ?? this.photos,
      metadata: metadata ?? this.metadata,
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

class OpeningHours {
  final bool openNow;
  final List<String>? weekdayText;
  final List<OpeningPeriod>? periods;

  OpeningHours({
    required this.openNow,
    this.weekdayText,
    this.periods,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    final periodsJson = json['periods'] as List<dynamic>? ?? [];
    final periods = periodsJson
        .map((period) => OpeningPeriod.fromJson(period as Map<String, dynamic>))
        .toList();

    return OpeningHours(
      openNow: json['openNow'] as bool? ?? false,
      weekdayText: (json['weekdayText'] as List<dynamic>?)?.cast<String>(),
      periods: periods.isNotEmpty ? periods : null,
    );
  }
}

class OpeningPeriod {
  final OpeningTime? open;
  final OpeningTime? close;

  OpeningPeriod({
    this.open,
    this.close,
  });

  factory OpeningPeriod.fromJson(Map<String, dynamic> json) {
    return OpeningPeriod(
      open: json['open'] != null
          ? OpeningTime.fromJson(json['open'] as Map<String, dynamic>)
          : null,
      close: json['close'] != null
          ? OpeningTime.fromJson(json['close'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OpeningTime {
  final int day;
  final String time;

  OpeningTime({
    required this.day,
    required this.time,
  });

  factory OpeningTime.fromJson(Map<String, dynamic> json) {
    return OpeningTime(
      day: json['day'] as int? ?? 0,
      time: json['time'] as String? ?? '',
    );
  }
}

class DietaryCompatibility {
  final double score;
  final List<String> reasons;

  DietaryCompatibility({
    required this.score,
    required this.reasons,
  });

  factory DietaryCompatibility.fromJson(Map<String, dynamic> json) {
    return DietaryCompatibility(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      reasons: (json['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class StorePhoto {
  final String reference;
  final int width;
  final int height;

  StorePhoto({
    required this.reference,
    required this.width,
    required this.height,
  });

  factory StorePhoto.fromJson(Map<String, dynamic> json) {
    return StorePhoto(
      reference: json['reference'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }
}

class StoreDetails {
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
  final List<String> storeTypes;
  final List<StorePhoto> photos;
  final List<StoreReview> reviews;
  final String? error;

  StoreDetails({
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
    required this.storeTypes,
    this.photos = const [],
    this.reviews = const [],
    this.error,
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) {
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final photos = photosJson
        .map((photo) => StorePhoto.fromJson(photo as Map<String, dynamic>))
        .toList();

    final reviewsJson = json['reviews'] as List<dynamic>? ?? [];
    final reviews = reviewsJson
        .map((review) => StoreReview.fromJson(review as Map<String, dynamic>))
        .toList();

    return StoreDetails(
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
      storeTypes: (json['storeTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      photos: photos,
      reviews: reviews,
      error: json['error'] as String?,
    );
  }
}

class StoreReview {
  final String authorName;
  final double rating;
  final String text;
  final int time;

  StoreReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.time,
  });

  factory StoreReview.fromJson(Map<String, dynamic> json) {
    return StoreReview(
      authorName: json['authorName'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
      time: json['time'] as int? ?? 0,
    );
  }
}

class NavigationDirections {
  final DistanceInfo distance;
  final DurationInfo duration;
  final String startAddress;
  final String endAddress;
  final List<NavigationStep> steps;
  final String polyline;
  final String travelMode;
  final String? error;

  NavigationDirections({
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.steps,
    required this.polyline,
    required this.travelMode,
    this.error,
  });

  factory NavigationDirections.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    final steps = stepsJson
        .map((step) => NavigationStep.fromJson(step as Map<String, dynamic>))
        .toList();

    return NavigationDirections(
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

class NavigationStep {
  final String instruction;
  final String distance;
  final String duration;
  final LocationCoordinates startLocation;
  final LocationCoordinates endLocation;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      startLocation: LocationCoordinates.fromJson(json['startLocation'] as Map<String, dynamic>? ?? {}),
      endLocation: LocationCoordinates.fromJson(json['endLocation'] as Map<String, dynamic>? ?? {}),
    );
  }
}