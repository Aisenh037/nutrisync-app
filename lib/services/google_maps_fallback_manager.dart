import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_maps_service.dart';

/// Fallback manager for Google Maps service when primary service fails
class GoogleMapsFallbackManager {
  static GoogleMapsFallbackManager? _instance;
  static GoogleMapsFallbackManager get instance => _instance ??= GoogleMapsFallbackManager._();
  
  GoogleMapsFallbackManager._();
  
  final _logger = Logger('GoogleMapsFallbackManager');
  
  /// Find nearby places with fallback strategies
  Future<PlacesSearchResult> findNearbyPlacesWithFallback({
    required double latitude,
    required double longitude,
    double radius = 5000,
    List<String> types = const ['grocery_or_supermarket', 'health', 'store'],
    int maxResults = 20,
  }) async {
    try {
      // Try primary Google Maps service first
      final primaryService = GoogleMapsService.instance;
      return await primaryService.findNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        types: types,
        maxResults: maxResults,
      );
      
    } catch (e) {
      _logger.warning('Primary Google Maps service failed: $e');
      
      // Try fallback strategies in order of preference
      final fallbackStrategies = [
        () => _tryStaticPlacesData(latitude, longitude, radius, types, maxResults),
        () => _tryCachedResults(latitude, longitude, radius, types, maxResults),
        () => _tryManualLocationEntry(latitude, longitude, radius, types, maxResults),
        () => _tryOfflineData(latitude, longitude, radius, types, maxResults),
      ];
      
      for (final strategy in fallbackStrategies) {
        try {
          final result = await strategy();
          if (result.places.isNotEmpty) {
            _logger.info('Fallback strategy succeeded with ${result.places.length} places');
            return result;
          }
        } catch (fallbackError) {
          _logger.fine('Fallback strategy failed: $fallbackError');
          continue;
        }
      }
      
      // If all fallbacks fail, return empty result with error
      return PlacesSearchResult(
        places: [],
        searchParams: SearchParams(
          location: LocationCoordinates(latitude: latitude, longitude: longitude),
          radius: radius,
          types: types,
          maxResults: maxResults,
        ),
        totalFound: 0,
        timestamp: DateTime.now().toIso8601String(),
        error: 'All location services are currently unavailable. Please try again later or enter location manually.',
      );
    }
  }
  
  /// Get place details with fallback strategies
  Future<PlaceDetails> getPlaceDetailsWithFallback(String placeId) async {
    try {
      // Try primary service first
      final primaryService = GoogleMapsService.instance;
      return await primaryService.getPlaceDetails(placeId);
      
    } catch (e) {
      _logger.warning('Primary place details service failed: $e');
      
      // Try fallback strategies
      final fallbackStrategies = [
        () => _tryStaticPlaceDetails(placeId),
        () => _tryCachedPlaceDetails(placeId),
        () => _tryBasicPlaceInfo(placeId),
      ];
      
      for (final strategy in fallbackStrategies) {
        try {
          final result = await strategy();
          if (result.name.isNotEmpty) {
            _logger.info('Place details fallback strategy succeeded');
            return result;
          }
        } catch (fallbackError) {
          _logger.fine('Place details fallback strategy failed: $fallbackError');
          continue;
        }
      }
      
      // Return minimal place details if all fallbacks fail
      return PlaceDetails(
        id: placeId,
        name: 'Unknown Location',
        address: 'Address not available',
        location: LocationCoordinates(latitude: 0.0, longitude: 0.0),
        rating: 0.0,
        userRatingsTotal: 0,
        types: ['establishment'],
        error: 'Place details are currently unavailable. Please try again later.',
      );
    }
  }
  
  /// Get directions with fallback strategies
  Future<DirectionsResult> getDirectionsWithFallback({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String travelMode = 'driving',
  }) async {
    try {
      // Try primary service first
      final primaryService = GoogleMapsService.instance;
      return await primaryService.getDirections(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        travelMode: travelMode,
      );
      
    } catch (e) {
      _logger.warning('Primary directions service failed: $e');
      
      // Try fallback strategies
      final fallbackStrategies = [
        () => _tryBasicDirections(originLat, originLng, destinationLat, destinationLng, travelMode),
        () => _tryExternalDirections(originLat, originLng, destinationLat, destinationLng, travelMode),
      ];
      
      for (final strategy in fallbackStrategies) {
        try {
          final result = await strategy();
          if (result.distance.value > 0) {
            _logger.info('Directions fallback strategy succeeded');
            return result;
          }
        } catch (fallbackError) {
          _logger.fine('Directions fallback strategy failed: $fallbackError');
          continue;
        }
      }
      
      // Return basic distance calculation if all fallbacks fail
      return _calculateBasicDirections(originLat, originLng, destinationLat, destinationLng, travelMode);
    }
  }
  
  /// Try using static places data from assets
  Future<PlacesSearchResult> _tryStaticPlacesData(
    double latitude,
    double longitude,
    double radius,
    List<String> types,
    int maxResults,
  ) async {
    try {
      final staticDataString = await rootBundle.loadString('assets/data/static_places.json');
      final staticData = json.decode(staticDataString) as Map<String, dynamic>;
      
      final allPlaces = (staticData['places'] as List<dynamic>)
          .map((place) => Place.fromJson(place as Map<String, dynamic>))
          .toList();
      
      // Filter places by distance and type
      final nearbyPlaces = allPlaces.where((place) {
        final distance = _calculateDistance(
          latitude, longitude,
          place.location.latitude, place.location.longitude,
        );
        
        final isWithinRadius = distance <= radius;
        final matchesType = types.isEmpty || 
                           types.any((type) => place.types.contains(type));
        
        return isWithinRadius && matchesType;
      }).take(maxResults).toList();
      
      // Update distances
      for (final place in nearbyPlaces) {
        final distance = _calculateDistance(
          latitude, longitude,
          place.location.latitude, place.location.longitude,
        );
        // Note: This would require modifying the Place class to be mutable
        // or creating a new instance with updated distance
      }
      
      return PlacesSearchResult(
        places: nearbyPlaces,
        searchParams: SearchParams(
          location: LocationCoordinates(latitude: latitude, longitude: longitude),
          radius: radius,
          types: types,
          maxResults: maxResults,
        ),
        totalFound: nearbyPlaces.length,
        timestamp: DateTime.now().toIso8601String(),
      );
      
    } catch (e) {
      _logger.fine('Static places data not available: $e');
      rethrow;
    }
  }
  
  /// Try using cached results from previous searches
  Future<PlacesSearchResult> _tryCachedResults(
    double latitude,
    double longitude,
    double radius,
    List<String> types,
    int maxResults,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'places_cache_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final cacheJson = json.decode(cachedData) as Map<String, dynamic>;
        final cacheTimestamp = DateTime.parse(cacheJson['timestamp'] as String);
        
        // Use cache if it's less than 1 hour old
        if (DateTime.now().difference(cacheTimestamp).inHours < 1) {
          final result = PlacesSearchResult.fromJson(cacheJson);
          
          // Filter cached results by current search criteria
          final filteredPlaces = result.places.where((place) {
            final matchesType = types.isEmpty || 
                               types.any((type) => place.types.contains(type));
            return matchesType && place.distance <= radius;
          }).take(maxResults).toList();
          
          if (filteredPlaces.isNotEmpty) {
            return PlacesSearchResult(
              places: filteredPlaces,
              searchParams: SearchParams(
                location: LocationCoordinates(latitude: latitude, longitude: longitude),
                radius: radius,
                types: types,
                maxResults: maxResults,
              ),
              totalFound: filteredPlaces.length,
              timestamp: DateTime.now().toIso8601String(),
            );
          }
        }
      }
      
      throw Exception('No valid cached results found');
      
    } catch (e) {
      _logger.fine('Cached results not available: $e');
      rethrow;
    }
  }
  
  /// Try manual location entry fallback
  Future<PlacesSearchResult> _tryManualLocationEntry(
    double latitude,
    double longitude,
    double radius,
    List<String> types,
    int maxResults,
  ) async {
    // This would typically show a UI for manual entry
    // For now, return a placeholder that indicates manual entry is needed
    
    final manualEntryPlace = Place(
      id: 'manual_entry_placeholder',
      name: 'Enter Location Manually',
      address: 'Tap to enter store location manually',
      location: LocationCoordinates(latitude: latitude, longitude: longitude),
      distance: 0,
      rating: 0.0,
      userRatingsTotal: 0,
      types: ['manual_entry'],
      metadata: {
        'is_manual_entry': true,
        'instruction': 'Tap to enter store details manually',
      },
    );
    
    return PlacesSearchResult(
      places: [manualEntryPlace],
      searchParams: SearchParams(
        location: LocationCoordinates(latitude: latitude, longitude: longitude),
        radius: radius,
        types: types,
        maxResults: maxResults,
      ),
      totalFound: 1,
      timestamp: DateTime.now().toIso8601String(),
    );
  }
  
  /// Try offline data from local database
  Future<PlacesSearchResult> _tryOfflineData(
    double latitude,
    double longitude,
    double radius,
    List<String> types,
    int maxResults,
  ) async {
    try {
      // This would query a local SQLite database with offline place data
      // For now, return common chain stores that are likely to be nearby
      
      final commonStores = [
        {
          'name': 'Walmart Supercenter',
          'types': ['grocery_or_supermarket', 'store'],
          'rating': 3.5,
        },
        {
          'name': 'Target',
          'types': ['grocery_or_supermarket', 'store'],
          'rating': 4.0,
        },
        {
          'name': 'Kroger',
          'types': ['grocery_or_supermarket'],
          'rating': 4.1,
        },
        {
          'name': 'Safeway',
          'types': ['grocery_or_supermarket'],
          'rating': 3.8,
        },
        {
          'name': 'Whole Foods Market',
          'types': ['grocery_or_supermarket', 'health'],
          'rating': 4.3,
        },
      ];
      
      final offlinePlaces = commonStores.where((store) {
        final storeTypes = store['types'] as List<String>;
        return types.isEmpty || types.any((type) => storeTypes.contains(type));
      }).take(maxResults).map((store) {
        return Place(
          id: 'offline_${store['name'].toString().toLowerCase().replaceAll(' ', '_')}',
          name: store['name'] as String,
          address: 'Location details not available offline',
          location: LocationCoordinates(
            latitude: latitude + (0.01 * (commonStores.indexOf(store) - 2)),
            longitude: longitude + (0.01 * (commonStores.indexOf(store) - 2)),
          ),
          distance: (1000 + (commonStores.indexOf(store) * 500)), // Estimated distances
          rating: store['rating'] as double,
          userRatingsTotal: 100,
          types: store['types'] as List<String>,
          metadata: {
            'is_offline_data': true,
            'note': 'Location and details are estimated. Please verify before visiting.',
          },
        );
      }).toList();
      
      return PlacesSearchResult(
        places: offlinePlaces,
        searchParams: SearchParams(
          location: LocationCoordinates(latitude: latitude, longitude: longitude),
          radius: radius,
          types: types,
          maxResults: maxResults,
        ),
        totalFound: offlinePlaces.length,
        timestamp: DateTime.now().toIso8601String(),
      );
      
    } catch (e) {
      _logger.fine('Offline data not available: $e');
      rethrow;
    }
  }
  
  /// Try static place details
  Future<PlaceDetails> _tryStaticPlaceDetails(String placeId) async {
    try {
      final staticDataString = await rootBundle.loadString('assets/data/static_places.json');
      final staticData = json.decode(staticDataString) as Map<String, dynamic>;
      
      final places = staticData['places'] as List<dynamic>;
      final placeData = places.firstWhere(
        (place) => place['id'] == placeId,
        orElse: () => throw Exception('Place not found in static data'),
      ) as Map<String, dynamic>;
      
      return PlaceDetails.fromJson(placeData);
      
    } catch (e) {
      _logger.fine('Static place details not available: $e');
      rethrow;
    }
  }
  
  /// Try cached place details
  Future<PlaceDetails> _tryCachedPlaceDetails(String placeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'place_details_$placeId';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final cacheJson = json.decode(cachedData) as Map<String, dynamic>;
        final cacheTimestamp = DateTime.parse(cacheJson['cached_at'] as String);
        
        // Use cache if it's less than 24 hours old
        if (DateTime.now().difference(cacheTimestamp).inHours < 24) {
          return PlaceDetails.fromJson(cacheJson['data'] as Map<String, dynamic>);
        }
      }
      
      throw Exception('No valid cached place details found');
      
    } catch (e) {
      _logger.fine('Cached place details not available: $e');
      rethrow;
    }
  }
  
  /// Try basic place info
  Future<PlaceDetails> _tryBasicPlaceInfo(String placeId) async {
    // Return minimal place information
    return PlaceDetails(
      id: placeId,
      name: 'Store Location',
      address: 'Address not available',
      location: LocationCoordinates(latitude: 0.0, longitude: 0.0),
      rating: 0.0,
      userRatingsTotal: 0,
      types: ['establishment'],
    );
  }
  
  /// Try basic directions calculation
  Future<DirectionsResult> _tryBasicDirections(
    double originLat,
    double originLng,
    double destinationLat,
    double destinationLng,
    String travelMode,
  ) async {
    return _calculateBasicDirections(originLat, originLng, destinationLat, destinationLng, travelMode);
  }
  
  /// Try external directions service
  Future<DirectionsResult> _tryExternalDirections(
    double originLat,
    double originLng,
    double destinationLat,
    double destinationLng,
    String travelMode,
  ) async {
    // This could integrate with other mapping services like OpenStreetMap
    // For now, fall back to basic calculation
    return _calculateBasicDirections(originLat, originLng, destinationLat, destinationLng, travelMode);
  }
  
  /// Calculate basic directions using straight-line distance
  DirectionsResult _calculateBasicDirections(
    double originLat,
    double originLng,
    double destinationLat,
    double destinationLng,
    String travelMode,
  ) {
    final distance = _calculateDistance(originLat, originLng, destinationLat, destinationLng);
    
    // Estimate travel time based on mode
    final speedKmh = _getEstimatedSpeed(travelMode);
    final durationMinutes = (distance / 1000) / speedKmh * 60;
    
    return DirectionsResult(
      distance: DistanceInfo(
        text: '${(distance / 1000).toStringAsFixed(1)} km',
        value: distance.round(),
      ),
      duration: DurationInfo(
        text: '${durationMinutes.round()} min',
        value: (durationMinutes * 60).round(),
      ),
      startAddress: 'Starting location',
      endAddress: 'Destination',
      steps: [
        DirectionStep(
          instruction: 'Head towards your destination',
          distance: '${(distance / 1000).toStringAsFixed(1)} km',
          duration: '${durationMinutes.round()} min',
          startLocation: LocationCoordinates(latitude: originLat, longitude: originLng),
          endLocation: LocationCoordinates(latitude: destinationLat, longitude: destinationLng),
        ),
      ],
      polyline: '',
      travelMode: travelMode,
      error: 'Detailed directions are not available. Distance and time are estimated.',
    );
  }
  
  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    final double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    
    final double a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        (lat1 * (3.14159265359 / 180)).cos() * (lat2 * (3.14159265359 / 180)).cos() *
        (dLon / 2).sin() * (dLon / 2).sin();
    
    final double c = 2 * (a.sqrt()).atan2((1 - a).sqrt());
    
    return earthRadius * c;
  }
  
  /// Get estimated speed for travel mode
  double _getEstimatedSpeed(String travelMode) {
    switch (travelMode.toLowerCase()) {
      case 'walking':
        return 5.0; // 5 km/h
      case 'bicycling':
        return 15.0; // 15 km/h
      case 'transit':
        return 25.0; // 25 km/h
      case 'driving':
      default:
        return 50.0; // 50 km/h
    }
  }
  
  /// Cache search results for future fallback use
  Future<void> cacheSearchResults(PlacesSearchResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final location = result.searchParams.location;
      final cacheKey = 'places_cache_${location.latitude.toStringAsFixed(3)}_${location.longitude.toStringAsFixed(3)}';
      
      final cacheData = {
        ...result.toJson(),
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
      _logger.fine('Cached search results for future fallback use');
      
    } catch (e) {
      _logger.warning('Failed to cache search results: $e');
    }
  }
  
  /// Cache place details for future fallback use
  Future<void> cachePlaceDetails(PlaceDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'place_details_${details.id}';
      
      final cacheData = {
        'data': details.toJson(),
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
      _logger.fine('Cached place details for future fallback use');
      
    } catch (e) {
      _logger.warning('Failed to cache place details: $e');
    }
  }
}

// Extension methods to add toJson() to result classes
extension PlacesSearchResultJson on PlacesSearchResult {
  Map<String, dynamic> toJson() {
    return {
      'stores': places.map((place) => place.toJson()).toList(),
      'searchParams': searchParams.toJson(),
      'totalFound': totalFound,
      'timestamp': timestamp,
      'error': error,
    };
  }
}

extension PlaceJson on Place {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'location': location.toJson(),
      'distance': distance,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'storeTypes': types,
      'metadata': metadata,
    };
  }
}

extension LocationCoordinatesJson on LocationCoordinates {
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

extension SearchParamsJson on SearchParams {
  Map<String, dynamic> toJson() {
    return {
      'location': location.toJson(),
      'radius': radius,
      'storeTypes': types,
      'maxResults': maxResults,
    };
  }
}

extension PlaceDetailsJson on PlaceDetails {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'location': location.toJson(),
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'priceLevel': priceLevel,
      'phoneNumber': phoneNumber,
      'website': website,
      'openingHours': openingHours?.toJson(),
      'storeTypes': types,
      'photos': photos.map((photo) => photo.toJson()).toList(),
      'reviews': reviews.map((review) => review.toJson()).toList(),
      'error': error,
    };
  }
}

extension OpeningHoursJson on OpeningHours {
  Map<String, dynamic> toJson() {
    return {
      'openNow': openNow,
      'weekdayText': weekdayText,
    };
  }
}

extension PlacePhotoJson on PlacePhoto {
  Map<String, dynamic> toJson() {
    return {
      'reference': reference,
      'width': width,
      'height': height,
    };
  }
}

extension PlaceReviewJson on PlaceReview {
  Map<String, dynamic> toJson() {
    return {
      'authorName': authorName,
      'rating': rating,
      'text': text,
      'time': time,
    };
  }
}