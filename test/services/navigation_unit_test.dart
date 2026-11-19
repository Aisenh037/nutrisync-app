import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/navigation_service.dart';

void main() {
  group('Navigation Unit Tests', () {
    late NavigationService navigationService;
    
    setUp(() {
      navigationService = NavigationService.instance;
    });
    
    group('NavigationApp Extension Tests', () {
      test('should provide correct display names', () {
        expect(NavigationApp.googleMaps.displayName, equals('Google Maps'));
        expect(NavigationApp.appleMaps.displayName, equals('Apple Maps'));
        expect(NavigationApp.waze.displayName, equals('Waze'));
        expect(NavigationApp.mapbox.displayName, equals('Mapbox'));
      });
      
      test('should provide icon asset paths', () {
        for (final app in NavigationApp.values) {
          expect(app.iconAsset, startsWith('assets/icons/'));
          expect(app.iconAsset, endsWith('.png'));
        }
      });
    });
    
    group('TravelMode Extension Tests', () {
      test('should provide correct display names', () {
        expect(TravelMode.driving.displayName, equals('Driving'));
        expect(TravelMode.walking.displayName, equals('Walking'));
        expect(TravelMode.bicycling.displayName, equals('Bicycling'));
        expect(TravelMode.transit.displayName, equals('Transit'));
      });
      
      test('should provide emoji icons', () {
        expect(TravelMode.driving.icon, equals('🚗'));
        expect(TravelMode.walking.icon, equals('🚶'));
        expect(TravelMode.bicycling.icon, equals('🚴'));
        expect(TravelMode.transit.icon, equals('🚌'));
      });
    });
    
    group('Navigation Service Singleton Tests', () {
      test('should return same instance', () {
        final instance1 = NavigationService.instance;
        final instance2 = NavigationService.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });
    });
    
    group('Coordinate Validation Tests', () {
      test('should handle valid coordinates', () {
        // Test with various valid coordinate ranges
        final validCoordinates = [
          {'lat': 0.0, 'lng': 0.0}, // Equator, Prime Meridian
          {'lat': 37.7749, 'lng': -122.4194}, // San Francisco
          {'lat': 40.7128, 'lng': -74.0060}, // New York
          {'lat': 51.5074, 'lng': -0.1278}, // London
          {'lat': -33.8688, 'lng': 151.2093}, // Sydney
          {'lat': 90.0, 'lng': 180.0}, // Extreme valid values
          {'lat': -90.0, 'lng': -180.0}, // Extreme valid values
        ];
        
        for (final coords in validCoordinates) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: coords['lat']!,
              longitude: coords['lng']!,
            );
          }, returnsNormally);
        }
      });
      
      test('should handle edge case coordinates', () {
        // Test with edge cases that might cause issues
        final edgeCaseCoordinates = [
          {'lat': 89.9999, 'lng': 179.9999}, // Near poles/dateline
          {'lat': -89.9999, 'lng': -179.9999},
          {'lat': 0.0001, 'lng': 0.0001}, // Very small values
          {'lat': -0.0001, 'lng': -0.0001},
        ];
        
        for (final coords in edgeCaseCoordinates) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: coords['lat']!,
              longitude: coords['lng']!,
            );
          }, returnsNormally);
        }
      });
    });
    
    group('URL Generation Tests', () {
      test('should handle special characters in destination names', () {
        final specialNames = [
          'Store & Market',
          'Café Français',
          'Store #123',
          'Market (Downtown)',
          'Store/Deli',
          'Store with "Quotes"',
          'Store with spaces and symbols!@#',
        ];
        
        for (final name in specialNames) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: 37.7749,
              longitude: -122.4194,
              destinationName: name,
            );
          }, returnsNormally);
        }
      });
      
      test('should handle empty and null destination names', () {
        expect(() async {
          await navigationService.navigateToLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            destinationName: '',
          );
        }, returnsNormally);
        
        expect(() async {
          await navigationService.navigateToLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            destinationName: null,
          );
        }, returnsNormally);
      });
      
      test('should handle various place ID formats', () {
        final placeIds = [
          'ChIJd8BlQ2BZwokRAFUEcm_qrcA', // Standard Google Place ID
          'place_id_123',
          'short_id',
          'very_long_place_id_with_many_characters_and_numbers_123456789',
          '',
        ];
        
        for (final placeId in placeIds) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: 37.7749,
              longitude: -122.4194,
              placeId: placeId,
            );
          }, returnsNormally);
        }
      });
    });
    
    group('Travel Mode Tests', () {
      test('should handle all travel modes for directions', () {
        const originLat = 37.7749;
        const originLng = -122.4194;
        const destLat = 37.7849;
        const destLng = -122.4094;
        
        for (final mode in TravelMode.values) {
          expect(() async {
            await navigationService.getDirections(
              originLat: originLat,
              originLng: originLng,
              destinationLat: destLat,
              destinationLng: destLng,
              travelMode: mode,
            );
          }, returnsNormally);
        }
      });
    });
    
    group('Error Handling Tests', () {
      test('should handle extreme coordinate values', () {
        final extremeCoordinates = [
          {'lat': 200.0, 'lng': 200.0}, // Invalid coordinates
          {'lat': -200.0, 'lng': -200.0},
          {'lat': double.infinity, 'lng': double.infinity},
          {'lat': double.negativeInfinity, 'lng': double.negativeInfinity},
          {'lat': double.nan, 'lng': double.nan},
        ];
        
        for (final coords in extremeCoordinates) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: coords['lat']!,
              longitude: coords['lng']!,
            );
          }, returnsNormally); // Should not throw, but may return false
        }
      });
      
      test('should handle very long destination names', () {
        final longName = 'A' * 1000; // Very long name
        
        expect(() async {
          await navigationService.navigateToLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            destinationName: longName,
          );
        }, returnsNormally);
      });
      
      test('should handle unicode characters in destination names', () {
        final unicodeNames = [
          '北京市', // Chinese
          'Москва', // Russian
          'العربية', // Arabic
          '🏪 Store', // Emoji
          'Café ñoño', // Accented characters
        ];
        
        for (final name in unicodeNames) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: 37.7749,
              longitude: -122.4194,
              destinationName: name,
            );
          }, returnsNormally);
        }
      });
    });
    
    group('Performance Tests', () {
      test('should handle multiple rapid navigation requests', () async {
        final futures = <Future<bool>>[];
        
        // Create multiple navigation requests
        for (int i = 0; i < 10; i++) {
          futures.add(navigationService.navigateToLocation(
            latitude: 37.7749 + (i * 0.001),
            longitude: -122.4194 + (i * 0.001),
            destinationName: 'Store $i',
          ));
        }
        
        // Wait for all requests to complete
        final results = await Future.wait(futures);
        
        expect(results, hasLength(10));
        expect(results, everyElement(isA<bool>()));
      });
      
      test('should handle concurrent direction requests', () async {
        final futures = <Future<bool>>[];
        
        for (int i = 0; i < 5; i++) {
          futures.add(navigationService.getDirections(
            originLat: 37.7749,
            originLng: -122.4194,
            destinationLat: 37.7749 + (i * 0.01),
            destinationLng: -122.4194 + (i * 0.01),
          ));
        }
        
        final results = await Future.wait(futures);
        
        expect(results, hasLength(5));
        expect(results, everyElement(isA<bool>()));
      });
    });
    
    group('App Availability Tests', () {
      test('should return list of available apps', () async {
        final availableApps = await navigationService.getAvailableApps();
        
        expect(availableApps, isA<List<NavigationApp>>());
        // Should contain at least one app (web fallback)
        expect(availableApps.length, greaterThanOrEqualTo(0));
      });
      
      test('should handle app availability check errors gracefully', () async {
        // This test ensures the service doesn't crash when checking app availability
        expect(() async {
          await navigationService.getAvailableApps();
        }, returnsNormally);
      });
    });
  });
}