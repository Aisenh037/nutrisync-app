import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../lib/services/dietary_substitution_service.dart';
import '../../lib/models/dietary_substitution_models.dart';

/// Integration tests for Dietary Substitution Service
/// Tests the complete substitution workflow with Firebase integration
/// 
/// Feature: gcp-ai-enhancement
/// Task: 6.3 - Dietary Substitution Engine
void main() {
  group('DietarySubstitutionService Integration Tests', () {
    late DietarySubstitutionService service;
    late FakeFirebaseFirestore fakeFirestore;
    
    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = DietarySubstitutionService(firestore: fakeFirestore);
    });

    group('Basic Substitution Functionality', () {
      test('should provide vegan substitutions for dairy ingredients', () async {
        // Arrange
        const userId = 'test_user_1';
        const ingredients = ['milk', 'ghee', 'butter'];
        const dietaryRestrictions = ['vegan'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        expect(substitutions.length, greaterThanOrEqualTo(3));
        
        // Check milk substitution
        final milkSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'milk',
        );
        expect(milkSub.substitution, contains('milk')); // almond milk, coconut milk, etc.
        expect(milkSub.dietaryRestrictions, contains('vegan'));
        expect(milkSub.nutritionalSimilarity, greaterThan(0.0));
        expect(milkSub.costDifference, greaterThan(0.0));

        // Check ghee substitution
        final gheeSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'ghee',
        );
        expect(gheeSub.substitution, contains('oil'));
        expect(gheeSub.reason, isNotEmpty);
      });

      test('should provide gluten-free substitutions for wheat products', () async {
        // Arrange
        const userId = 'test_user_2';
        const ingredients = ['wheat flour', 'maida'];
        const dietaryRestrictions = ['gluten-free'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        
        final flourSub = substitutions.firstWhere(
          (s) => s.originalIngredient.contains('flour'),
        );
        expect(flourSub.substitution, anyOf([
          contains('rice flour'),
          contains('almond flour'),
        ]));
        expect(flourSub.dietaryRestrictions, contains('gluten-free'));
      });

      test('should provide low-sodium substitutions for salt', () async {
        // Arrange
        const userId = 'test_user_3';
        const ingredients = ['salt'];
        const dietaryRestrictions = ['low-sodium'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        
        final saltSub = substitutions.first;
        expect(saltSub.originalIngredient, 'salt');
        expect(saltSub.substitution, contains('herb'));
        expect(saltSub.dietaryRestrictions, contains('low-sodium'));
      });
    });

    group('Cultural Context Adaptation', () {
      test('should adapt substitutions for Indian cultural context', () async {
        // Arrange
        const userId = 'test_user_indian';
        const ingredients = ['milk', 'ghee'];
        const dietaryRestrictions = ['vegan'];
        const culturalContext = 'indian';

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
          culturalContext: culturalContext,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        
        // For Indian context, coconut milk and mustard oil should be preferred
        final milkSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'milk',
        );
        expect(milkSub.substitution, 'coconut milk');

        final gheeSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'ghee',
        );
        expect(gheeSub.substitution, 'mustard oil');
      });

      test('should adapt substitutions for Western cultural context', () async {
        // Arrange
        const userId = 'test_user_western';
        const ingredients = ['ghee', 'sugar'];
        const dietaryRestrictions = ['vegan', 'diabetic'];
        const culturalContext = 'western';

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
          culturalContext: culturalContext,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        
        // For Western context, olive oil and stevia should be preferred
        final gheeSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'ghee',
        );
        expect(gheeSub.substitution, 'olive oil');

        final sugarSub = substitutions.firstWhere(
          (s) => s.originalIngredient == 'sugar',
        );
        expect(sugarSub.substitution, 'stevia');
      });
    });

    group('User Preference Learning', () {
      test('should update user preferences after providing substitutions', () async {
        // Arrange
        const userId = 'test_user_learning';
        const ingredients = ['milk'];
        const dietaryRestrictions = ['vegan'];

        // Act - First call should create preferences
        await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Verify preferences were created
        final prefsDoc = await fakeFirestore
            .collection('user_substitution_preferences')
            .doc(userId)
            .get();
        
        expect(prefsDoc.exists, isTrue);
        final prefsData = prefsDoc.data() as Map<String, dynamic>;
        expect(prefsData['preferences'], isNotEmpty);
      });

      test('should record and process substitution feedback', () async {
        // Arrange
        const userId = 'test_user_feedback';
        const originalIngredient = 'milk';
        const substitution = 'almond milk';
        const rating = 4.5;
        const feedback = 'Great taste and texture!';

        // Act
        await service.recordSubstitutionFeedback(
          userId: userId,
          originalIngredient: originalIngredient,
          substitution: substitution,
          rating: rating,
          feedback: feedback,
        );

        // Assert - Check feedback was recorded
        final feedbackQuery = await fakeFirestore
            .collection('substitution_feedback')
            .where('userId', isEqualTo: userId)
            .get();
        
        expect(feedbackQuery.docs, hasLength(1));
        
        final feedbackData = feedbackQuery.docs.first.data();
        expect(feedbackData['originalIngredient'], originalIngredient);
        expect(feedbackData['substitution'], substitution);
        expect(feedbackData['rating'], rating);
        expect(feedbackData['feedback'], feedback);

        // Check user preferences were updated
        final prefsDoc = await fakeFirestore
            .collection('user_substitution_preferences')
            .doc(userId)
            .get();
        
        expect(prefsDoc.exists, isTrue);
        final prefsData = prefsDoc.data() as Map<String, dynamic>;
        final preferences = Map<String, double>.from(prefsData['preferences']);
        expect(preferences['almond milk'], greaterThan(0.5));
      });
    });

    group('Analytics and Insights', () {
      test('should generate substitution analytics for user', () async {
        // Arrange
        const userId = 'test_user_analytics';
        
        // Add some feedback data
        await service.recordSubstitutionFeedback(
          userId: userId,
          originalIngredient: 'milk',
          substitution: 'almond milk',
          rating: 4.0,
          feedback: 'Good taste',
        );
        
        await service.recordSubstitutionFeedback(
          userId: userId,
          originalIngredient: 'butter',
          substitution: 'vegan butter',
          rating: 3.5,
          feedback: 'Okay for baking',
        );

        await service.recordSubstitutionFeedback(
          userId: userId,
          originalIngredient: 'milk',
          substitution: 'oat milk',
          rating: 2.0,
          feedback: 'Too watery',
        );

        // Act
        final analytics = await service.getSubstitutionAnalytics(userId);

        // Assert
        expect(analytics.totalSubstitutions, 3);
        expect(analytics.averageRating, closeTo(3.17, 0.1));
        expect(analytics.recentFeedbacks, hasLength(3));
        expect(analytics.improvementSuggestions, isNotEmpty);
        
        // Check top substitutions (should have at least one with multiple uses)
        if (analytics.topSubstitutions.isNotEmpty) {
          final topSub = analytics.topSubstitutions.first;
          expect(topSub.averageRating, greaterThan(0.0));
          expect(topSub.usageCount, greaterThanOrEqualTo(1));
        }
      });

      test('should get popular substitutions across users', () async {
        // Arrange - Add feedback from multiple users
        const users = ['user1', 'user2', 'user3'];
        const substitution = 'almond milk';
        
        for (final user in users) {
          await service.recordSubstitutionFeedback(
            userId: user,
            originalIngredient: 'milk',
            substitution: substitution,
            rating: 4.0,
          );
        }

        // Act
        final popularSubs = await service.getPopularSubstitutions(limit: 5);

        // Assert
        expect(popularSubs, isNotEmpty);
        
        final almondMilkSub = popularSubs.firstWhere(
          (s) => s.substitution == substitution,
          orElse: () => throw Exception('Almond milk not found in popular substitutions'),
        );
        
        expect(almondMilkSub.usageCount, 3);
        expect(almondMilkSub.averageRating, 4.0);
      });
    });

    group('Multiple Dietary Restrictions', () {
      test('should handle multiple dietary restrictions for single ingredient', () async {
        // Arrange
        const userId = 'test_user_multiple';
        const ingredients = ['wheat flour'];
        const dietaryRestrictions = ['gluten-free', 'low-carb'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        expect(substitutions.length, greaterThanOrEqualTo(2));
        
        // Should have substitutions for both restrictions
        final glutenFreeSub = substitutions.where(
          (s) => s.dietaryRestrictions.contains('gluten-free'),
        );
        expect(glutenFreeSub, isNotEmpty);
        
        final lowCarbSub = substitutions.where(
          (s) => s.dietaryRestrictions.contains('low-carb'),
        );
        expect(lowCarbSub, isNotEmpty);
      });

      test('should provide comprehensive substitutions for complex dietary needs', () async {
        // Arrange
        const userId = 'test_user_complex';
        const ingredients = ['milk', 'wheat flour', 'sugar', 'salt'];
        const dietaryRestrictions = ['vegan', 'gluten-free', 'diabetic', 'low-sodium'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isNotEmpty);
        expect(substitutions.length, greaterThanOrEqualTo(4));
        
        // Verify each ingredient has appropriate substitutions
        final ingredientsCovered = substitutions
            .map((s) => s.originalIngredient)
            .toSet();
        
        expect(ingredientsCovered, containsAll(ingredients));
        
        // Verify nutritional similarity scores are reasonable
        for (final sub in substitutions) {
          expect(sub.nutritionalSimilarity, inInclusiveRange(0.0, 1.0));
          expect(sub.costDifference, greaterThan(0.0));
          expect(sub.reason, isNotEmpty);
        }
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle empty ingredients list gracefully', () async {
        // Arrange
        const userId = 'test_user_empty';
        const ingredients = <String>[];
        const dietaryRestrictions = ['vegan'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert
        expect(substitutions, isEmpty);
      });

      test('should handle unknown ingredients gracefully', () async {
        // Arrange
        const userId = 'test_user_unknown';
        const ingredients = ['unknown_ingredient_xyz'];
        const dietaryRestrictions = ['vegan'];

        // Act
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );

        // Assert - Should not throw error, may return empty list
        expect(substitutions, isA<List<DietarySubstitution>>());
      });

      test('should handle Firestore errors gracefully', () async {
        // This test would require mocking Firestore to throw errors
        // For now, we'll test that the service doesn't crash with invalid user IDs
        
        // Arrange
        const userId = ''; // Empty user ID
        const ingredients = ['milk'];
        const dietaryRestrictions = ['vegan'];

        // Act & Assert - Should not throw
        expect(
          () => service.getSubstitutions(
            ingredients: ingredients,
            dietaryRestrictions: dietaryRestrictions,
            userId: userId,
          ),
          returnsNormally,
        );
      });
    });

    group('Performance and Scalability', () {
      test('should handle large ingredient lists efficiently', () async {
        // Arrange
        const userId = 'test_user_large';
        final ingredients = List.generate(50, (i) => 'ingredient_$i');
        const dietaryRestrictions = ['vegan', 'gluten-free'];

        // Act
        final stopwatch = Stopwatch()..start();
        final substitutions = await service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        );
        stopwatch.stop();

        // Assert
        expect(substitutions, isA<List<DietarySubstitution>>());
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete within 5 seconds
      });

      test('should handle multiple concurrent requests', () async {
        // Arrange
        const userIds = ['user1', 'user2', 'user3', 'user4', 'user5'];
        const ingredients = ['milk', 'wheat flour'];
        const dietaryRestrictions = ['vegan', 'gluten-free'];

        // Act
        final futures = userIds.map((userId) => service.getSubstitutions(
          ingredients: ingredients,
          dietaryRestrictions: dietaryRestrictions,
          userId: userId,
        ));

        final results = await Future.wait(futures);

        // Assert
        expect(results, hasLength(5));
        for (final result in results) {
          expect(result, isNotEmpty);
        }
      });
    });
  });
}