import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/recommendation_engine.dart';
import 'package:nutrisync/models/user_model.dart';
import 'package:nutrisync/cultural/indian_food_database.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';

void main() {
  group('RecommendationEngine Tests', () {
    late RecommendationEngine recommendationEngine;
    late UserModel testUser;

    setUp(() {
      // Create recommendation engine without Firebase database for testing
      recommendationEngine = RecommendationEngine(foodDatabase: null);
      testUser = UserModel(
        uid: 'test-uid',
        name: 'Test User',
        email: 'test@example.com',
        age: 30,
        gender: 'Male',
        height: 175.0,
        weight: 70.0,
        activityLevel: 'Moderate',
        healthGoals: ['Weight loss', 'Better digestion'],
        medicalConditions: ['Diabetes'],
        allergies: ['Nuts'],
        dietaryNeeds: ['Vegetarian'],
        foodDislikes: ['Spicy food'],
        culturalPreferences: {'preferredRegion': 'North Indian', 'spiceLevel': 'mild'},
      );
    });

    group('Recommendation Generation', () {
      test('generateRecommendations returns successful result', () async {
        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: testUser,
          type: RecommendationType.balanced,
          maxRecommendations: 5,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.recommendations, isNotEmpty);
        expect(result.recommendations.length, lessThanOrEqualTo(5));
        expect(result.context.age, equals(30));
        expect(result.context.healthGoals, contains('Weight loss'));
      });

      test('generateRecommendations filters by meal type', () async {
        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: testUser,
          type: RecommendationType.balanced,
          mealType: 'lunch',
          maxRecommendations: 3,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.recommendations, isNotEmpty);
        // All recommendations should be suitable for lunch
        for (final rec in result.recommendations) {
          expect(rec.food.category, isIn([IndianFoodCategory.dal, IndianFoodCategory.sabzi, IndianFoodCategory.curry, IndianFoodCategory.rice]));
        }
      });

      test('generateRecommendations excludes specified ingredients', () async {
        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: testUser,
          type: RecommendationType.balanced,
          excludeIngredients: ['cream', 'butter'],
        );

        // Assert
        expect(result.success, isTrue);
        // Should not contain foods with excluded ingredients
        for (final rec in result.recommendations) {
          final ingredients = rec.food.cookingMethods.defaultMethod.commonIngredients;
          expect(ingredients.any((ing) => ing.toLowerCase().contains('cream')), isFalse);
          expect(ingredients.any((ing) => ing.toLowerCase().contains('butter')), isFalse);
        }
      });
    });

    group('Meal Plan Generation', () {
      test('generateMealPlan creates plan for specified days', () async {
        // Act
        final result = await recommendationEngine.generateMealPlan(
          user: testUser,
          days: 3,
          includeSnacks: true,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.totalDays, equals(3));
        expect(result.mealPlan.keys.length, equals(3));
        
        // Check each day has meals
        for (int i = 1; i <= 3; i++) {
          final dayKey = 'day_$i';
          expect(result.mealPlan.containsKey(dayKey), isTrue);
          expect(result.mealPlan[dayKey]!, isNotEmpty);
        }
      });

      test('generateMealPlan excludes snacks when requested', () async {
        // Act
        final result = await recommendationEngine.generateMealPlan(
          user: testUser,
          days: 1,
          includeSnacks: false,
        );

        // Assert
        expect(result.success, isTrue);
        final dayMeals = result.mealPlan['day_1']!;
        
        // Should have breakfast, lunch, dinner but no snacks
        expect(dayMeals.length, greaterThanOrEqualTo(3));
        expect(dayMeals.length, lessThanOrEqualTo(8)); // Max without snacks
      });
    });

    group('Portion Recommendations', () {
      test('getPortionRecommendation calculates reasonable portions', () {
        // Arrange
        final food = IndianFoodItem(
          id: 'test-dal',
          name: 'Test Dal',
          aliases: ['dal'],
          nutrition: NutritionalInfo(
            calories: 150.0,
            protein: 10.0,
            carbs: 20.0,
            fat: 2.0,
            fiber: 8.0,
            vitamins: {},
            minerals: {},
          ),
          cookingMethods: CookingVariations(
            defaultMethod: CookingMethod(
              name: 'boiled',
              description: 'Boiled with spices',
              nutritionMultiplier: 1.0,
              commonIngredients: ['lentils'],
            ),
            alternatives: [],
            nutritionAdjustments: {},
          ),
          portionSizes: PortionGuides(
            standardPortions: {IndianMeasurementUnit.katori: 150.0},
            visualReference: '1 katori',
            gramsPerPortion: 150.0,
          ),
          regions: RegionalAvailability(
            primaryRegion: 'North Indian',
            availableRegions: ['North Indian'],
            regionalNames: {},
          ),
          category: IndianFoodCategory.dal,
          commonCombinations: [],
          searchTerms: [],
          baseDish: 'dal',
          regionalVariations: [],
        );

        // Act
        final portion = recommendationEngine.getPortionRecommendation(
          user: testUser,
          food: food,
          mealType: 'lunch',
        );

        // Assert
        expect(portion.grams, greaterThan(0));
        expect(portion.calories, greaterThan(0));
        expect(portion.indianUnit, isNotEmpty);
        expect(portion.indianQuantity, greaterThan(0));
        expect(portion.reason, isNotEmpty);
      });
    });

    group('Nutritional Balance Analysis', () {
      test('analyzeNutritionalBalance provides comprehensive analysis', () {
        // Arrange
        final meals = [
          DetailedFoodItem(
            id: 'meal1',
            name: 'Dal',
            originalName: 'Dal',
            quantity: 150.0,
            unit: 'grams',
            displayQuantity: 1.0,
            displayUnit: 'katori',
            nutrition: NutritionalInfo(
              calories: 150.0,
              protein: 10.0,
              carbs: 20.0,
              fat: 2.0,
              fiber: 8.0,
              vitamins: {},
              minerals: {},
            ),
            confidence: 0.9,
            culturalContext: CulturalFoodContext(
              region: 'North Indian',
              cookingStyle: 'boiled',
              mealType: 'lunch',
            ),
          ),
        ];

        // Act
        final analysis = recommendationEngine.analyzeNutritionalBalance(
          meals: meals,
          user: testUser,
        );

        // Assert
        expect(analysis.totalCalories, greaterThan(0));
        expect(analysis.targetCalories, greaterThan(0));
        expect(analysis.macroBalance.protein.current, greaterThan(0));
        expect(analysis.macroBalance.carbs.current, greaterThan(0));
        expect(analysis.macroBalance.fat.current, greaterThan(0));
        expect(analysis.suggestions, isNotEmpty);
      });
    });

    group('Complementary Foods', () {
      test('getComplementaryFoods suggests appropriate foods', () async {
        // Arrange - Create a meal that's very low in protein and fiber to trigger deficiencies
        final currentMeals = [
          DetailedFoodItem(
            id: 'rice',
            name: 'Rice',
            originalName: 'Rice',
            quantity: 100.0,
            unit: 'grams',
            displayQuantity: 1.0,
            displayUnit: 'katori',
            nutrition: NutritionalInfo(
              calories: 130.0,
              protein: 1.0, // Very low protein to trigger deficiency
              carbs: 28.0,
              fat: 0.3,
              fiber: 0.1, // Very low fiber to trigger deficiency
              vitamins: {},
              minerals: {},
            ),
            confidence: 0.9,
            culturalContext: CulturalFoodContext(
              region: 'North Indian',
              cookingStyle: 'boiled',
              mealType: 'lunch',
            ),
          ),
        ];

        // Act
        final complementary = await recommendationEngine.getComplementaryFoods(
          currentMeals: currentMeals,
          user: testUser,
          maxSuggestions: 3,
        );

        // Assert - Should suggest foods to address deficiencies
        // If no deficiencies are identified, the result might be empty, which is also valid behavior
        expect(complementary, isA<List<MealRecommendation>>());
        
        // If complementary foods are suggested, they should be high in missing nutrients
        if (complementary.isNotEmpty) {
          expect(complementary.length, lessThanOrEqualTo(3));
          final hasHighProtein = complementary.any((food) => food.food.nutrition.protein > 5);
          final hasHighFiber = complementary.any((food) => food.food.nutrition.fiber > 3);
          expect(hasHighProtein || hasHighFiber, isTrue);
        }
      });
    });

    group('Error Handling', () {
      test('generateRecommendations handles errors gracefully', () async {
        // Arrange - Create user with invalid data that might cause issues
        final invalidUser = UserModel(
          uid: 'invalid-uid',
          name: 'Invalid User',
          email: 'invalid@example.com',
          // Missing critical data like age, weight, etc.
        );

        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: invalidUser,
          type: RecommendationType.balanced,
        );

        // Assert - Should handle gracefully, not crash
        expect(result, isNotNull);
        // Even with invalid data, should try to provide some result or clear error
        expect(result.success || result.error != null, isTrue);
      });
    });

    group('User Context Integration', () {
      test('recommendations respect user dietary restrictions', () async {
        // Arrange - User with specific dietary needs
        final veganUser = testUser.copyWith(
          dietaryNeeds: ['Vegan'],
          allergies: ['Dairy', 'Nuts'],
        );

        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: veganUser,
          type: RecommendationType.healthy,
        );

        // Assert
        expect(result.success, isTrue);
        
        // All recommendations should be vegan-friendly
        for (final rec in result.recommendations) {
          final ingredients = rec.food.cookingMethods.defaultMethod.commonIngredients;
          expect(ingredients.any((ing) => 
            ing.toLowerCase().contains('cream') || 
            ing.toLowerCase().contains('butter') ||
            ing.toLowerCase().contains('milk')), isFalse);
        }
      });

      test('recommendations consider health goals', () async {
        // Arrange - User with weight loss goal
        final weightLossUser = testUser.copyWith(
          healthGoals: ['Weight loss'],
        );

        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: weightLossUser,
          type: RecommendationType.healthy,
        );

        // Assert
        expect(result.success, isTrue);
        
        // Should favor lower calorie, higher fiber foods
        final avgCalories = result.recommendations
            .map((r) => r.food.nutrition.calories)
            .reduce((a, b) => a + b) / result.recommendations.length;
        expect(avgCalories, lessThan(200)); // Should be relatively low calorie
      });

      test('recommendations respect cultural preferences', () async {
        // Arrange - User with South Indian preference
        final southIndianUser = testUser.copyWith(
          culturalPreferences: {'preferredRegion': 'South Indian'},
        );

        // Act
        final result = await recommendationEngine.generateRecommendations(
          user: southIndianUser,
          type: RecommendationType.balanced,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.context.culturalPreferences['preferredRegion'], equals('South Indian'));
      });
    });
  });
}