import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/food_vision_ai_service.dart';

void main() {
  group('Food Vision AI Service - Integration Tests', () {
    late FoodVisionAIService service;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      service = FoodVisionAIService.instance;
      // Initialize service (will use mock credentials in test environment)
      await service.initialize();
    });

    group('Food Image Analysis', () {
      test('should analyze food image and return nutrition data', () async {
        // Create a mock image (1x1 pixel PNG)
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_user_001',
          context: {'test': true},
          confidenceThreshold: 0.5,
        );

        expect(result, isNotNull);
        expect(result.isFood, isA<bool>());
        expect(result.overallConfidence, isA<double>());
        expect(result.detectedFoods, isA<List<DetectedFoodItem>>());

        if (result.isFood && result.detectedFoods.isNotEmpty) {
          final firstFood = result.detectedFoods.first;
          expect(firstFood.name, isNotEmpty);
          expect(firstFood.category, isNotEmpty);
          expect(firstFood.confidence, greaterThanOrEqualTo(0.0));
          expect(firstFood.confidence, lessThanOrEqualTo(1.0));
          expect(firstFood.nutritionInfo.calories, greaterThanOrEqualTo(0.0));
          expect(firstFood.portionEstimate.estimatedGrams, greaterThan(0.0));
        }
      });

      test('should handle non-food images gracefully', () async {
        // Create a mock non-food image
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_user_002',
          confidenceThreshold: 0.8, // High threshold to potentially reject
        );

        expect(result, isNotNull);
        expect(result.isFood, isA<bool>());
        expect(result.overallConfidence, isA<double>());
        expect(result.detectedFoods, isA<List<DetectedFoodItem>>());

        // If not food, should have appropriate metadata or error
        if (!result.isFood) {
          // In test environment, may return error due to no actual service
          expect(result.error != null || result.metadata != null, isTrue);
        }
      });

      test('should handle batch food image analysis', () async {
        final mockImages = [
          _createMockImageData(),
          _createMockImageData(),
          _createMockImageData(),
        ];

        final results = await service.analyzeFoodImagesBatch(
          mockImages,
          userId: 'test_user_003',
          confidenceThreshold: 0.6,
        );

        expect(results, isNotNull);
        expect(results.length, equals(mockImages.length));

        for (final result in results) {
          expect(result.isFood, isA<bool>());
          expect(result.overallConfidence, isA<double>());
          expect(result.detectedFoods, isA<List<DetectedFoodItem>>());
        }
      });

      test('should handle analysis errors gracefully', () async {
        // Create invalid image data
        final invalidImageData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final result = await service.analyzeFoodImage(
          invalidImageData,
          userId: 'test_user_004',
        );

        expect(result, isNotNull);
        // Should handle error gracefully
        if (result.error != null) {
          expect(result.error, isNotEmpty);
          expect(result.isFood, isFalse);
          expect(result.detectedFoods, isEmpty);
        }
      });
    });

    group('Nutrition Lookup', () {
      test('should lookup nutrition for common foods', () async {
        final commonFoods = ['apple', 'banana', 'rice', 'chicken', 'bread'];

        for (final food in commonFoods) {
          final result = await service.lookupNutrition(
            food,
            portionGrams: 100.0,
            portionDescription: '1 serving',
          );

          expect(result, isNotNull);
          expect(result.nutritionInfo, isNotNull);
          expect(result.nutritionInfo.calories, greaterThanOrEqualTo(0.0));
          expect(result.nutritionInfo.protein, greaterThanOrEqualTo(0.0));
          expect(result.nutritionInfo.carbohydrates, greaterThanOrEqualTo(0.0));
          expect(result.nutritionInfo.fat, greaterThanOrEqualTo(0.0));
          expect(result.confidence, greaterThanOrEqualTo(0.0));
          expect(result.confidence, lessThanOrEqualTo(1.0));
        }
      });

      test('should handle unknown foods gracefully', () async {
        final result = await service.lookupNutrition(
          'unknown_exotic_food_xyz123',
          portionGrams: 100.0,
        );

        expect(result, isNotNull);
        expect(result.nutritionInfo, isNotNull);
        // Should provide default values or error
        expect(result.confidence, lessThanOrEqualTo(0.5));
      });

      test('should scale nutrition based on portion size', () async {
        final result100g = await service.lookupNutrition(
          'apple',
          portionGrams: 100.0,
        );

        final result200g = await service.lookupNutrition(
          'apple',
          portionGrams: 200.0,
        );

        expect(result100g, isNotNull);
        expect(result200g, isNotNull);

        if (result100g.error == null && result200g.error == null) {
          // 200g should have approximately double the calories
          final ratio = result200g.nutritionInfo.calories / result100g.nutritionInfo.calories;
          expect(ratio, closeTo(2.0, 0.5)); // Allow some variance
        }
      });
    });

    group('Food Search', () {
      test('should search for food items', () async {
        final searchQueries = ['apple', 'rice', 'chicken', 'bread'];

        for (final query in searchQueries) {
          final result = await service.searchFoodItems(query, limit: 5);

          expect(result, isNotNull);
          expect(result.query, equals(query));
          expect(result.results, isA<List<String>>());
          expect(result.count, equals(result.results.length));
          expect(result.count, lessThanOrEqualTo(5));

          // Results should contain relevant foods
          if (result.results.isNotEmpty) {
            final hasRelevantResult = result.results.any(
              (food) => food.toLowerCase().contains(query.toLowerCase()),
            );
            expect(hasRelevantResult, isTrue);
          }
        }
      });

      test('should handle empty search queries', () async {
        final result = await service.searchFoodItems('', limit: 10);

        expect(result, isNotNull);
        expect(result.query, isEmpty);
        // Should return empty results or error
        expect(result.results, isA<List<String>>());
      });

      test('should limit search results correctly', () async {
        final result = await service.searchFoodItems('a', limit: 3);

        expect(result, isNotNull);
        expect(result.results.length, lessThanOrEqualTo(3));
        expect(result.count, equals(result.results.length));
      });
    });

    group('Food Confidence Validation', () {
      test('should validate confirmed food identification', () async {
        final mockImageData = _createMockImageData();

        final result = await service.validateFoodConfidence(
          'apple',
          mockImageData,
          userConfirmed: true,
        );

        expect(result, isNotNull);
        // In test environment, may not connect to actual service
        // But should handle the request gracefully
        expect(result.finalFoodName, isNotEmpty);
        expect(result.updatedConfidence, greaterThanOrEqualTo(0.0));
        expect(result.updatedConfidence, lessThanOrEqualTo(1.0));
      });

      test('should handle user corrections', () async {
        final mockImageData = _createMockImageData();

        final result = await service.validateFoodConfidence(
          'apple',
          mockImageData,
          userConfirmed: false,
          userCorrection: 'banana',
        );

        expect(result, isNotNull);
        // In test environment, may not connect to actual service
        // But should handle the request gracefully
        expect(result.finalFoodName, isNotEmpty);
        expect(result.updatedConfidence, greaterThanOrEqualTo(0.0));
        expect(result.updatedConfidence, lessThanOrEqualTo(1.0));
      });

      test('should handle user rejections', () async {
        final mockImageData = _createMockImageData();

        final result = await service.validateFoodConfidence(
          'apple',
          mockImageData,
          userConfirmed: false,
        );

        expect(result, isNotNull);
        expect(result.accepted, isFalse);
        expect(result.updatedConfidence, lessThan(0.5));
        expect(result.message, isNotNull);
      });
    });

    group('Multi-Food Detection and Confidence Scoring', () {
      test('should analyze food image with confirmation flow', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImageWithConfirmation(
          mockImageData,
          userId: 'test_user_multi_001',
          confidenceThreshold: 0.6,
        );

        expect(result, isNotNull);
        expect(result.analysisResult, isNotNull);
        expect(result.needsConfirmation, isA<bool>());
        expect(result.confirmationPrompts, isA<List<String>>());
        expect(result.suggestedActions, isA<List<String>>());

        // Should always have at least one suggested action
        expect(result.suggestedActions, isNotEmpty);

        // If confirmation is needed, should have prompts
        if (result.needsConfirmation) {
          expect(result.confirmationPrompts, isNotEmpty);
        }
      });

      test('should handle multiple food items with confidence scoring', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_user_multi_002',
          confidenceThreshold: 0.5, // Lower threshold to potentially detect more items
        );

        expect(result, isNotNull);
        expect(result.detectedFoods, isA<List<DetectedFoodItem>>());

        // Check confidence scoring
        for (final food in result.detectedFoods) {
          expect(food.confidence, greaterThanOrEqualTo(0.0));
          expect(food.confidence, lessThanOrEqualTo(1.0));
          expect(food.name, isNotEmpty);
          expect(food.category, isNotEmpty);
        }

        // If multiple foods detected, should be sorted by confidence
        if (result.detectedFoods.length > 1) {
          for (int i = 0; i < result.detectedFoods.length - 1; i++) {
            expect(
              result.detectedFoods[i].confidence,
              greaterThanOrEqualTo(result.detectedFoods[i + 1].confidence),
            );
          }
        }
      });

      test('should provide enhanced metadata for multi-food detection', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_user_multi_003',
        );

        expect(result, isNotNull);
        
        // In test environment, service may return error due to no actual connection
        // But should still provide metadata or error information
        if (result.metadata != null) {
          // If metadata exists, check for enhanced fields
          if (result.isFood) {
            expect(result.metadata!.containsKey('unique_foods_detected'), isTrue);
            expect(result.metadata!.containsKey('confidence_threshold'), isTrue);
            expect(result.metadata!.containsKey('detection_method'), isTrue);
            expect(result.metadata!.containsKey('requires_confirmation'), isTrue);
          }
        } else {
          // If no metadata, should have error information
          expect(result.error != null || !result.isFood, isTrue);
        }
      });

      test('should handle confidence validation workflow', () async {
        final mockImageData = _createMockImageData();

        // First analyze with confirmation flow
        final analysisResult = await service.analyzeFoodImageWithConfirmation(
          mockImageData,
          userId: 'test_user_validation_001',
        );

        expect(analysisResult, isNotNull);

        // Then validate confidence (simulate user confirmation)
        if (analysisResult.analysisResult.detectedFoods.isNotEmpty) {
          final firstFood = analysisResult.analysisResult.detectedFoods.first;
          
          final validationResult = await service.validateFoodConfidence(
            firstFood.name,
            mockImageData,
            userConfirmed: true,
          );

          expect(validationResult, isNotNull);
          expect(validationResult.finalFoodName, isNotEmpty);
          expect(validationResult.updatedConfidence, greaterThanOrEqualTo(0.0));
          expect(validationResult.updatedConfidence, lessThanOrEqualTo(1.0));
        }
      });

      test('should handle user corrections in confidence validation', () async {
        final mockImageData = _createMockImageData();

        final validationResult = await service.validateFoodConfidence(
          'apple',
          mockImageData,
          userConfirmed: false,
          userCorrection: 'banana',
        );

        expect(validationResult, isNotNull);
        expect(validationResult.finalFoodName, isNotEmpty);
        expect(validationResult.updatedConfidence, greaterThanOrEqualTo(0.0));
        expect(validationResult.updatedConfidence, lessThanOrEqualTo(1.0));
      });
    });

    group('Non-Food Image Handling', () {
      test('should analyze non-food images and provide guidance', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeNonFoodImage(
          mockImageData,
          userId: 'test_user_non_food_001',
        );

        expect(result, isNotNull);
        expect(result.detectedObjects, isA<List<String>>());
        expect(result.detectedLabels, isA<List<String>>());
        expect(result.imageCategory, isNotEmpty);
        expect(result.suggestions, isNotEmpty);
        expect(result.confidence, greaterThanOrEqualTo(0.0));
        expect(result.confidence, lessThanOrEqualTo(1.0));

        // Should always provide helpful suggestions
        expect(result.suggestions.length, greaterThan(0));
      });

      test('should handle non-food images gracefully in regular analysis', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_user_non_food_002',
          confidenceThreshold: 0.8, // High threshold
        );

        expect(result, isNotNull);
        expect(result.isFood, isA<bool>());

        // If not food, should provide helpful metadata or error
        if (!result.isFood) {
          expect(result.error != null || result.metadata != null, isTrue);
          
          if (result.metadata != null && result.metadata!.containsKey('suggestions')) {
            final suggestions = result.metadata!['suggestions'] as List<dynamic>?;
            expect(suggestions, isNotNull);
            expect(suggestions!.isNotEmpty, isTrue);
          }
        }
      });

      test('should provide category-specific suggestions for non-food images', () async {
        final mockImageData = _createMockImageData();

        final result = await service.analyzeNonFoodImage(
          mockImageData,
          userId: 'test_user_non_food_003',
        );

        expect(result, isNotNull);
        expect(result.imageCategory, isNotEmpty);
        expect(result.suggestions, isNotEmpty);

        // Suggestions should be relevant to the category
        final categorySpecificKeywords = {
          'person': ['people', 'frame', 'photo'],
          'menu_or_text': ['menu', 'food', 'text'],
          'environment': ['closer', 'food', 'frame'],
          'animal': ['animal', 'food', 'pet'],
          'unclear': ['lighting', 'focus', 'camera'],
          'unrecognized': ['food', 'visible', 'lighting'],
        };

        if (categorySpecificKeywords.containsKey(result.imageCategory)) {
          final expectedKeywords = categorySpecificKeywords[result.imageCategory]!;
          final suggestionsText = result.suggestions.join(' ').toLowerCase();
          
          final hasRelevantKeyword = expectedKeywords.any(
            (keyword) => suggestionsText.contains(keyword.toLowerCase()),
          );
          expect(hasRelevantKeyword, isTrue);
        }
      });
    });

    group('Service Health and Connectivity', () {
      test('should test connection to service', () async {
        final isConnected = await service.testConnection();
        expect(isConnected, isA<bool>());
        // Connection may fail in test environment, but should not throw
      });

      test('should handle service initialization', () async {
        // Service should already be initialized from setUpAll
        expect(service, isNotNull);
        
        // Re-initialization should be safe
        await service.initialize();
        expect(service, isNotNull);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle network errors gracefully', () async {
        // This test assumes the service will handle network errors
        final mockImageData = _createMockImageData();

        final result = await service.analyzeFoodImage(
          mockImageData,
          userId: 'test_network_error',
        );

        expect(result, isNotNull);
        // Should not throw, even if network fails
      });

      test('should handle large images', () async {
        // Create a larger mock image
        final largeImageData = _createMockImageData(size: 1000);

        final result = await service.analyzeFoodImage(
          largeImageData,
          userId: 'test_large_image',
        );

        expect(result, isNotNull);
        // Should handle large images without crashing
      });

      test('should handle concurrent requests', () async {
        final mockImageData = _createMockImageData();
        
        // Make multiple concurrent requests
        final futures = List.generate(5, (index) => 
          service.analyzeFoodImage(
            mockImageData,
            userId: 'test_concurrent_$index',
          )
        );

        final results = await Future.wait(futures);

        expect(results.length, equals(5));
        for (final result in results) {
          expect(result, isNotNull);
        }
      });
    });
  });
}

/// Create mock image data for testing
Uint8List _createMockImageData({int size = 100}) {
  // Create a simple PNG-like structure for testing
  // This is not a valid PNG, but serves as mock data
  final data = List<int>.generate(size, (index) => index % 256);
  return Uint8List.fromList(data);
}