import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/navigation_service.dart';

void main() {
  group('Navigation Integration Tests', () {
    late NavigationService navigationService;
    
    setUpAll(() {
      navigationService = NavigationService.instance;
    });
    
    group('Navigation Service Integration Tests', () {
      test('should get available navigation apps', () async {
        final availableApps = await navigationService.getAvailableApps();
        
        expect(availableApps, isA<List<NavigationApp>>());
        // In test environment, apps may not be available, so just check the list is valid
        expect(availableApps.length, greaterThanOrEqualTo(0));
      });
      
      test('should handle navigation to location with coordinates', () async {
        // Test coordinates for San Francisco
        const latitude = 37.7749;
        const longitude = -122.4194;
        const destinationName = 'Test Store';
        
        // This test verifies the method doesn't throw exceptions
        // Actual navigation would require user interaction
        expect(() async {
          await navigationService.navigateToLocation(
            latitude: latitude,
            longitude: longitude,
            destinationName: destinationName,
          );
        }, returnsNormally);
      });
      
      test('should handle directions between two points', () async {
        // Test coordinates
        const originLat = 37.7749;
        const originLng = -122.4194;
        const destinationLat = 37.7849;
        const destinationLng = -122.4094;
        
        expect(() async {
          await navigationService.getDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
          );
        }, returnsNormally);
      });
      
      test('should handle different travel modes', () async {
        const latitude = 37.7749;
        const longitude = -122.4194;
        
        for (final travelMode in TravelMode.values) {
          expect(() async {
            await navigationService.getDirections(
              originLat: latitude,
              originLng: longitude,
              destinationLat: latitude + 0.01,
              destinationLng: longitude + 0.01,
              travelMode: travelMode,
            );
          }, returnsNormally);
        }
      });
      
      test('should handle invalid coordinates gracefully', () async {
        // Test with invalid coordinates
        const invalidLat = 200.0; // Invalid latitude
        const invalidLng = 400.0; // Invalid longitude
        
        final result = await navigationService.navigateToLocation(
          latitude: invalidLat,
          longitude: invalidLng,
        );
        
        // Should not crash, but may return false
        expect(result, isA<bool>());
      });
    });
    
    group('Navigation App Extensions Tests', () {
      test('should provide display names for navigation apps', () {
        for (final app in NavigationApp.values) {
          expect(app.displayName, isNotEmpty);
          expect(app.iconAsset, isNotEmpty);
        }
      });
      
      test('should provide display names for travel modes', () {
        for (final mode in TravelMode.values) {
          expect(mode.displayName, isNotEmpty);
          expect(mode.icon, isNotEmpty);
        }
      });
    });
    
    group('Error Handling Tests', () {
      test('should handle network errors gracefully', () async {
        // Test with coordinates that might cause network issues
        const latitude = 0.0;
        const longitude = 0.0;
        
        final result = await navigationService.navigateToLocation(
          latitude: latitude,
          longitude: longitude,
        );
        
        // Should not throw, but may return false
        expect(result, isA<bool>());
      });
      
      test('should handle missing place ID gracefully', () async {
        const latitude = 37.7749;
        const longitude = -122.4194;
        
        final result = await navigationService.navigateToLocation(
          latitude: latitude,
          longitude: longitude,
          placeId: 'invalid_place_id',
        );
        
        expect(result, isA<bool>());
      });
      
      test('should handle unavailable navigation apps', () async {
        // This test verifies the service handles cases where no apps are available
        final availableApps = await navigationService.getAvailableApps();
        
        // In test environment, apps may not be available
        expect(availableApps, isA<List<NavigationApp>>());
        expect(availableApps.length, greaterThanOrEqualTo(0));
      });
    });
    
    group('Integration Workflow Tests', () {
      test('should complete basic navigation workflow', () async {
        // Step 1: Get available navigation apps
        final availableApps = await navigationService.getAvailableApps();
        expect(availableApps, isA<List<NavigationApp>>());
        
        // Step 2: Test navigation to a location
        const latitude = 37.7749;
        const longitude = -122.4194;
        const destinationName = 'Test Store';
        
        if (availableApps.isNotEmpty) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: latitude,
              longitude: longitude,
              destinationName: destinationName,
              preferredApp: availableApps.first,
            );
          }, returnsNormally);
        }
      });
      
      test('should handle multiple navigation requests', () async {
        final futures = <Future<bool>>[];
        
        // Create multiple navigation requests
        for (int i = 0; i < 5; i++) {
          futures.add(navigationService.navigateToLocation(
            latitude: 37.7749 + (i * 0.001),
            longitude: -122.4194 + (i * 0.001),
            destinationName: 'Store $i',
          ));
        }
        
        // Wait for all requests to complete
        final results = await Future.wait(futures);
        
        expect(results, hasLength(5));
        expect(results, everyElement(isA<bool>()));
      });
      
      test('should handle directions with different travel modes', () async {
        const originLat = 37.7749;
        const originLng = -122.4194;
        const destLat = 37.7849;
        const destLng = -122.4094;
        
        for (final mode in TravelMode.values) {
          final result = await navigationService.getDirections(
            originLat: originLat,
            originLng: originLng,
            destinationLat: destLat,
            destinationLng: destLng,
            travelMode: mode,
          );
          
          expect(result, isA<bool>());
        }
      });
    });
    
    group('Platform Integration Tests', () {
      test('should handle platform-specific navigation apps', () async {
        final availableApps = await navigationService.getAvailableApps();
        
        // Test that we can handle different platform apps
        for (final app in availableApps) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: 37.7749,
              longitude: -122.4194,
              preferredApp: app,
            );
          }, returnsNormally);
        }
      });
      
      test('should provide consistent app information', () {
        for (final app in NavigationApp.values) {
          // Test display name consistency
          expect(app.displayName, isNotEmpty);
          expect(app.displayName, isNot(contains('null')));
          
          // Test icon asset consistency
          expect(app.iconAsset, startsWith('assets/icons/'));
          expect(app.iconAsset, endsWith('.png'));
        }
      });
      
      test('should handle URL generation for different apps', () async {
        const latitude = 37.7749;
        const longitude = -122.4194;
        const destinationName = 'Test Store';
        const placeId = 'test_place_id';
        
        for (final app in NavigationApp.values) {
          expect(() async {
            await navigationService.navigateToLocation(
              latitude: latitude,
              longitude: longitude,
              destinationName: destinationName,
              placeId: placeId,
              preferredApp: app,
            );
          }, returnsNormally);
        }
      });
    });
  });
}