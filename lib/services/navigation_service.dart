import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart';

/// Service for handling external navigation to maps applications
class NavigationService {
  static NavigationService? _instance;
  static NavigationService get instance => _instance ??= NavigationService._();
  
  NavigationService._();
  
  final _logger = Logger('NavigationService');
  
  /// Navigate to a location using the user's preferred maps app
  Future<bool> navigateToLocation({
    required double latitude,
    required double longitude,
    String? destinationName,
    String? placeId,
    NavigationApp? preferredApp,
  }) async {
    try {
      // Determine the best navigation app to use
      final app = preferredApp ?? await _getBestAvailableApp();
      
      switch (app) {
        case NavigationApp.googleMaps:
          return await _openGoogleMaps(
            latitude: latitude,
            longitude: longitude,
            destinationName: destinationName,
            placeId: placeId,
          );
          
        case NavigationApp.appleMaps:
          return await _openAppleMaps(
            latitude: latitude,
            longitude: longitude,
            destinationName: destinationName,
          );
          
        case NavigationApp.waze:
          return await _openWaze(
            latitude: latitude,
            longitude: longitude,
          );
          
        case NavigationApp.mapbox:
          return await _openMapbox(
            latitude: latitude,
            longitude: longitude,
          );
      }
    } catch (e, stackTrace) {
      _logger.severe('Navigation failed: $e', e, stackTrace);
      return false;
    }
  }
  
  /// Get directions between two points
  Future<bool> getDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    String? placeId,
    NavigationApp? preferredApp,
    TravelMode travelMode = TravelMode.driving,
  }) async {
    try {
      final app = preferredApp ?? await _getBestAvailableApp();
      
      switch (app) {
        case NavigationApp.googleMaps:
          return await _openGoogleMapsDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            destinationName: destinationName,
            placeId: placeId,
            travelMode: travelMode,
          );
          
        case NavigationApp.appleMaps:
          return await _openAppleMapsDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            destinationName: destinationName,
            travelMode: travelMode,
          );
          
        case NavigationApp.waze:
          return await _openWazeDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
          );
          
        case NavigationApp.mapbox:
          return await _openMapboxDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
          );
      }
    } catch (e, stackTrace) {
      _logger.severe('Directions failed: $e', e, stackTrace);
      return false;
    }
  }
  
  /// Check which navigation apps are available on the device
  Future<List<NavigationApp>> getAvailableApps() async {
    final availableApps = <NavigationApp>[];
    
    // Google Maps
    if (await _canLaunchApp('https://maps.google.com/')) {
      availableApps.add(NavigationApp.googleMaps);
    }
    
    // Apple Maps (iOS only)
    if (Platform.isIOS && await _canLaunchApp('https://maps.apple.com/')) {
      availableApps.add(NavigationApp.appleMaps);
    }
    
    // Waze
    if (await _canLaunchApp('https://waze.com/ul')) {
      availableApps.add(NavigationApp.waze);
    }
    
    // Mapbox (if installed)
    if (await _canLaunchApp('mapbox://')) {
      availableApps.add(NavigationApp.mapbox);
    }
    
    return availableApps;
  }
  
  /// Get the best available navigation app based on platform
  Future<NavigationApp> _getBestAvailableApp() async {
    final availableApps = await getAvailableApps();
    
    if (availableApps.isEmpty) {
      // Fallback to Google Maps web
      return NavigationApp.googleMaps;
    }
    
    // Prefer platform-specific apps
    if (Platform.isIOS && availableApps.contains(NavigationApp.appleMaps)) {
      return NavigationApp.appleMaps;
    }
    
    // Default to Google Maps if available
    if (availableApps.contains(NavigationApp.googleMaps)) {
      return NavigationApp.googleMaps;
    }
    
    // Return the first available app
    return availableApps.first;
  }
  
  /// Open Google Maps for navigation
  Future<bool> _openGoogleMaps({
    required double latitude,
    required double longitude,
    String? destinationName,
    String? placeId,
  }) async {
    String url;
    
    if (placeId != null) {
      // Use place ID for more accurate navigation
      url = 'https://www.google.com/maps/dir/?api=1&destination_place_id=$placeId';
    } else {
      // Use coordinates
      url = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
      if (destinationName != null) {
        url += '&destination_name=${Uri.encodeComponent(destinationName)}';
      }
    }
    
    return await _launchUrl(url);
  }
  
  /// Open Google Maps with directions
  Future<bool> _openGoogleMapsDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    String? placeId,
    TravelMode travelMode = TravelMode.driving,
  }) async {
    String url = 'https://www.google.com/maps/dir/?api=1';
    url += '&origin=$originLat,$originLng';
    
    if (placeId != null) {
      url += '&destination_place_id=$placeId';
    } else {
      url += '&destination=$destinationLat,$destinationLng';
    }
    
    // Add travel mode
    switch (travelMode) {
      case TravelMode.driving:
        url += '&travelmode=driving';
        break;
      case TravelMode.walking:
        url += '&travelmode=walking';
        break;
      case TravelMode.bicycling:
        url += '&travelmode=bicycling';
        break;
      case TravelMode.transit:
        url += '&travelmode=transit';
        break;
    }
    
    return await _launchUrl(url);
  }
  
  /// Open Apple Maps for navigation
  Future<bool> _openAppleMaps({
    required double latitude,
    required double longitude,
    String? destinationName,
  }) async {
    String url = 'https://maps.apple.com/?daddr=$latitude,$longitude';
    
    if (destinationName != null) {
      url += '&q=${Uri.encodeComponent(destinationName)}';
    }
    
    return await _launchUrl(url);
  }
  
  /// Open Apple Maps with directions
  Future<bool> _openAppleMapsDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
    TravelMode travelMode = TravelMode.driving,
  }) async {
    String url = 'https://maps.apple.com/?saddr=$originLat,$originLng&daddr=$destinationLat,$destinationLng';
    
    if (destinationName != null) {
      url += '&q=${Uri.encodeComponent(destinationName)}';
    }
    
    // Add travel mode
    switch (travelMode) {
      case TravelMode.driving:
        url += '&dirflg=d';
        break;
      case TravelMode.walking:
        url += '&dirflg=w';
        break;
      case TravelMode.transit:
        url += '&dirflg=r';
        break;
      case TravelMode.bicycling:
        // Apple Maps doesn't have a specific bicycling mode, use walking
        url += '&dirflg=w';
        break;
    }
    
    return await _launchUrl(url);
  }
  
  /// Open Waze for navigation
  Future<bool> _openWaze({
    required double latitude,
    required double longitude,
  }) async {
    final url = 'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes';
    return await _launchUrl(url);
  }
  
  /// Open Waze with directions
  Future<bool> _openWazeDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    // Waze doesn't support origin specification in URL, so just navigate to destination
    return await _openWaze(latitude: destinationLat, longitude: destinationLng);
  }
  
  /// Open Mapbox for navigation
  Future<bool> _openMapbox({
    required double latitude,
    required double longitude,
  }) async {
    final url = 'mapbox://directions?destination=$longitude,$latitude';
    return await _launchUrl(url);
  }
  
  /// Open Mapbox with directions
  Future<bool> _openMapboxDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url = 'mapbox://directions?origin=$originLng,$originLat&destination=$destinationLng,$destinationLat';
    return await _launchUrl(url);
  }
  
  /// Check if an app can be launched
  Future<bool> _canLaunchApp(String url) async {
    try {
      return await canLaunchUrl(Uri.parse(url));
    } catch (e) {
      _logger.warning('Cannot check app availability for $url: $e');
      return false;
    }
  }
  
  /// Launch a URL with error handling
  Future<bool> _launchUrl(String url) async {
    try {
      _logger.info('Launching navigation URL: $url');
      
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        _logger.warning('Failed to launch URL: $url');
      }
      
      return launched;
    } catch (e, stackTrace) {
      _logger.severe('Error launching URL $url: $e', e, stackTrace);
      return false;
    }
  }
}

/// Available navigation applications
enum NavigationApp {
  googleMaps,
  appleMaps,
  waze,
  mapbox,
}

/// Travel modes for navigation
enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}

/// Extension to get display names for navigation apps
extension NavigationAppExtension on NavigationApp {
  String get displayName {
    switch (this) {
      case NavigationApp.googleMaps:
        return 'Google Maps';
      case NavigationApp.appleMaps:
        return 'Apple Maps';
      case NavigationApp.waze:
        return 'Waze';
      case NavigationApp.mapbox:
        return 'Mapbox';
    }
  }
  
  String get iconAsset {
    switch (this) {
      case NavigationApp.googleMaps:
        return 'assets/icons/google_maps.png';
      case NavigationApp.appleMaps:
        return 'assets/icons/apple_maps.png';
      case NavigationApp.waze:
        return 'assets/icons/waze.png';
      case NavigationApp.mapbox:
        return 'assets/icons/mapbox.png';
    }
  }
}

/// Extension to get display names for travel modes
extension TravelModeExtension on TravelMode {
  String get displayName {
    switch (this) {
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.bicycling:
        return 'Bicycling';
      case TravelMode.transit:
        return 'Transit';
    }
  }
  
  String get icon {
    switch (this) {
      case TravelMode.driving:
        return '🚗';
      case TravelMode.walking:
        return '🚶';
      case TravelMode.bicycling:
        return '🚴';
      case TravelMode.transit:
        return '🚌';
    }
  }
}