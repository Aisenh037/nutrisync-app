import 'package:flutter_test/flutter_test.dart';
import '../../lib/nutrition/meal_data_models.dart';
import '../../lib/voice/hinglish_processor.dart';

void main() {
  group('MealLoggerService - Data Models', () {
    test('should serialize and deserialize MealData correctly', () {
      final mealData = MealData(
        mealId: 'test-meal-1',
        userId: 'test-user',
        timestamp: DateTime(2024, 1, 15, 12, 30),
        mealType: MealType.lunch,
        foods: [
          DetailedFoodItem(
            id: 'food-1',
            name: 'Dal Makhani',
            originalName: 'dal makhani',
            quantity: 150.0,
            unit: 'grams',
            displayQuantity: 1.0,
            displayUnit: 'katori',
            nutrition: NutritionalInfo(
              calories: 200.0,
              protein: 8.0,
              carbs: 25.0,
              fat: 6.0,
              fiber: 4.0,
              vitamins: {'B1': 0.1},
              minerals: {'iron': 2.0},
            ),
            cookingMethod: 'dum',
            confidence: 0.9,
            culturalContext: CulturalFoodContext(
              region: 'North India',
              cookingStyle: 'dum',
              mealType: 'main',
            ),
          ),
        ],
        nutrition: NutritionalSummary(
          totalCalories: 200.0,
          totalProtein: 8.0,
          totalCarbs: 25.0,
          totalFat: 6.0,
          totalFiber: 4.0,
          vitamins: {'B1': 0.1},
          minerals: {'iron': 2.0},
          macroBreakdown: MacroBreakdown(
            proteinPercentage: 16.0,
            carbsPercentage: 50.0,
            fatPercentage: 27.0,
          ),
        ),
        voiceDescription: 'Maine ek katori dal makhani khayi',
        confidenceScore: 0.9,
      );

      // Test serialization
      final map = mealData.toMap();
      expect(map['mealId'], equals('test-meal-1'));
      expect(map['userId'], equals('test-user'));
      expect(map['mealType'], equals('MealType.lunch'));
      expect(map['foods'], isA<List>());
      expect(map['nutrition'], isA<Map>());
      expect(map['voiceDescription'], equals('Maine ek katori dal makhani khayi'));
      expect(map['confidenceScore'], equals(0.9));

      // Test deserialization
      final deserializedMeal = MealData.fromMap(map);
      expect(deserializedMeal.mealId, equals(mealData.mealId));
      expect(deserializedMeal.userId, equals(mealData.userId));
      expect(deserializedMeal.mealType, equals(mealData.mealType));
      expect(deserializedMeal.foods.length, equals(1));
      expect(deserializedMeal.nutrition.totalCalories, equals(200.0));
      expect(deserializedMeal.voiceDescription, equals(mealData.voiceDescription));
      expect(deserializedMeal.confidenceScore, equals(0.9));
    });

    test('should serialize and deserialize DetailedFoodItem correctly', () {
      final foodItem = DetailedFoodItem(
        id: 'food-1',
        name: 'Chapati',
        originalName: 'roti',
        quantity: 50.0,
        unit: 'grams',
        displayQuantity: 2.0,
        displayUnit: 'pieces',
        nutrition: NutritionalInfo(
          calories: 120.0,
          protein: 4.0,
          carbs: 22.0,
          fat: 1.0,
          fiber: 2.0,
          vitamins: {'B1': 0.05},
          minerals: {'iron': 1.0},
        ),
        cookingMethod: 'tawa',
        confidence: 0.95,
        culturalContext: CulturalFoodContext(
          region: 'India',
          cookingStyle: 'tawa',
          mealType: 'staple',
        ),
      );

      // Test serialization
      final map = foodItem.toMap();
      expect(map['id'], equals('food-1'));
      expect(map['name'], equals('Chapati'));
      expect(map['originalName'], equals('roti'));
      expect(map['quantity'], equals(50.0));
      expect(map['unit'], equals('grams'));
      expect(map['displayQuantity'], equals(2.0));
      expect(map['displayUnit'], equals('pieces'));
      expect(map['cookingMethod'], equals('tawa'));
      expect(map['confidence'], equals(0.95));

      // Test deserialization
      final deserializedItem = DetailedFoodItem.fromMap(map);
      expect(deserializedItem.id, equals(foodItem.id));
      expect(deserializedItem.name, equals(foodItem.name));
      expect(deserializedItem.originalName, equals(foodItem.originalName));
      expect(deserializedItem.quantity, equals(foodItem.quantity));
      expect(deserializedItem.unit, equals(foodItem.unit));
      expect(deserializedItem.displayQuantity, equals(foodItem.displayQuantity));
      expect(deserializedItem.displayUnit, equals(foodItem.displayUnit));
      expect(deserializedItem.cookingMethod, equals(foodItem.cookingMethod));
      expect(deserializedItem.confidence, equals(foodItem.confidence));
    });

    test('should serialize and deserialize NutritionalInfo correctly', () {
      final nutrition = NutritionalInfo(
        calories: 150.0,
        protein: 6.0,
        carbs: 20.0,
        fat: 4.0,
        fiber: 3.0,
        vitamins: {'A': 100.0, 'C': 50.0, 'B1': 0.1},
        minerals: {'iron': 2.0, 'calcium': 100.0},
      );

      // Test serialization
      final map = nutrition.toMap();
      expect(map['calories'], equals(150.0));
      expect(map['protein'], equals(6.0));
      expect(map['carbs'], equals(20.0));
      expect(map['fat'], equals(4.0));
      expect(map['fiber'], equals(3.0));
      expect(map['vitamins'], isA<Map<String, double>>());
      expect(map['minerals'], isA<Map<String, double>>());

      // Test deserialization
      final deserializedNutrition = NutritionalInfo.fromMap(map);
      expect(deserializedNutrition.calories, equals(nutrition.calories));
      expect(deserializedNutrition.protein, equals(nutrition.protein));
      expect(deserializedNutrition.carbs, equals(nutrition.carbs));
      expect(deserializedNutrition.fat, equals(nutrition.fat));
      expect(deserializedNutrition.fiber, equals(nutrition.fiber));
      expect(deserializedNutrition.vitamins['A'], equals(100.0));
      expect(deserializedNutrition.minerals['iron'], equals(2.0));
    });

    test('should serialize and deserialize NutritionalSummary correctly', () {
      final summary = NutritionalSummary(
        totalCalories: 500.0,
        totalProtein: 20.0,
        totalCarbs: 60.0,
        totalFat: 15.0,
        totalFiber: 8.0,
        vitamins: {'A': 200.0, 'C': 100.0},
        minerals: {'iron': 5.0, 'calcium': 200.0},
        macroBreakdown: MacroBreakdown(
          proteinPercentage: 16.0,
          carbsPercentage: 48.0,
          fatPercentage: 27.0,
        ),
      );

      // Test serialization
      final map = summary.toMap();
      expect(map['totalCalories'], equals(500.0));
      expect(map['totalProtein'], equals(20.0));
      expect(map['totalCarbs'], equals(60.0));
      expect(map['totalFat'], equals(15.0));
      expect(map['totalFiber'], equals(8.0));
      expect(map['macroBreakdown'], isA<Map>());

      // Test deserialization
      final deserializedSummary = NutritionalSummary.fromMap(map);
      expect(deserializedSummary.totalCalories, equals(summary.totalCalories));
      expect(deserializedSummary.totalProtein, equals(summary.totalProtein));
      expect(deserializedSummary.totalCarbs, equals(summary.totalCarbs));
      expect(deserializedSummary.totalFat, equals(summary.totalFat));
      expect(deserializedSummary.totalFiber, equals(summary.totalFiber));
      expect(deserializedSummary.macroBreakdown.proteinPercentage, equals(16.0));
    });
  });

  group('MealLoggerService - Utility Functions', () {
    test('should handle meal type extensions correctly', () {
      expect(MealType.breakfast.displayName, equals('Breakfast'));
      expect(MealType.lunch.displayName, equals('Lunch'));
      expect(MealType.dinner.displayName, equals('Dinner'));
      expect(MealType.snack.displayName, equals('Snack'));

      expect(MealType.breakfast.hindiName, equals('नाश्ता'));
      expect(MealType.lunch.hindiName, equals('दोपहर का खाना'));
      expect(MealType.dinner.hindiName, equals('रात का खाना'));
      expect(MealType.snack.hindiName, equals('नाश्ता'));
    });

    test('should handle empty nutrition data', () {
      final emptyNutrition = NutritionalSummary(
        totalCalories: 0.0,
        totalProtein: 0.0,
        totalCarbs: 0.0,
        totalFat: 0.0,
        totalFiber: 0.0,
        vitamins: {},
        minerals: {},
        macroBreakdown: MacroBreakdown(
          proteinPercentage: 0.0,
          carbsPercentage: 0.0,
          fatPercentage: 0.0,
        ),
      );

      expect(emptyNutrition.totalCalories, equals(0.0));
      expect(emptyNutrition.vitamins.isEmpty, isTrue);
      expect(emptyNutrition.minerals.isEmpty, isTrue);
    });

    test('should handle zero calorie macro breakdown', () {
      final zeroCalorieMacros = MacroBreakdown(
        proteinPercentage: 0.0,
        carbsPercentage: 0.0,
        fatPercentage: 0.0,
      );

      expect(zeroCalorieMacros.proteinPercentage, equals(0.0));
      expect(zeroCalorieMacros.carbsPercentage, equals(0.0));
      expect(zeroCalorieMacros.fatPercentage, equals(0.0));
    });

    test('should handle meal data with missing optional fields', () {
      final minimalMealData = MealData(
        mealId: 'minimal-meal',
        userId: 'test-user',
        timestamp: DateTime.now(),
        mealType: MealType.snack,
        foods: [],
        nutrition: NutritionalSummary(
          totalCalories: 0.0,
          totalProtein: 0.0,
          totalCarbs: 0.0,
          totalFat: 0.0,
          totalFiber: 0.0,
          vitamins: {},
          minerals: {},
          macroBreakdown: MacroBreakdown(
            proteinPercentage: 0.0,
            carbsPercentage: 0.0,
            fatPercentage: 0.0,
          ),
        ),
        voiceDescription: '',
        confidenceScore: 0.0,
      );

      expect(minimalMealData.foods.isEmpty, isTrue);
      expect(minimalMealData.voiceDescription, equals(''));
      expect(minimalMealData.confidenceScore, equals(0.0));
    });
  });

  group('MealLoggerService - Integration Scenarios', () {
    test('should handle typical breakfast logging scenario', () {
      final breakfastMeal = MealData(
        mealId: 'breakfast-1',
        userId: 'user-1',
        timestamp: DateTime(2024, 1, 15, 8, 30),
        mealType: MealType.breakfast,
        foods: [
          DetailedFoodItem(
            id: 'food-1',
            name: 'Paratha',
            originalName: 'aloo paratha',
            quantity: 100.0,
            unit: 'grams',
            displayQuantity: 2.0,
            displayUnit: 'pieces',
            nutrition: NutritionalInfo(
              calories: 250.0,
              protein: 6.0,
              carbs: 35.0,
              fat: 8.0,
              fiber: 3.0,
              vitamins: {'B1': 0.1},
              minerals: {'iron': 1.5},
            ),
            cookingMethod: 'tawa',
            confidence: 0.9,
            culturalContext: CulturalFoodContext(
              region: 'North India',
              cookingStyle: 'tawa',
              mealType: 'breakfast',
            ),
          ),
        ],
        nutrition: NutritionalSummary(
          totalCalories: 250.0,
          totalProtein: 6.0,
          totalCarbs: 35.0,
          totalFat: 8.0,
          totalFiber: 3.0,
          vitamins: {'B1': 0.1},
          minerals: {'iron': 1.5},
          macroBreakdown: MacroBreakdown(
            proteinPercentage: 9.6,
            carbsPercentage: 56.0,
            fatPercentage: 28.8,
          ),
        ),
        voiceDescription: 'Maine do aloo paratha khaye',
        confidenceScore: 0.9,
      );

      expect(breakfastMeal.mealType, equals(MealType.breakfast));
      expect(breakfastMeal.foods.length, equals(1));
      expect(breakfastMeal.foods.first.name, equals('Paratha'));
      expect(breakfastMeal.nutrition.totalCalories, equals(250.0));
    });

    test('should handle typical lunch logging scenario', () {
      final lunchMeal = MealData(
        mealId: 'lunch-1',
        userId: 'user-1',
        timestamp: DateTime(2024, 1, 15, 13, 0),
        mealType: MealType.lunch,
        foods: [
          DetailedFoodItem(
            id: 'food-1',
            name: 'Dal Tadka',
            originalName: 'dal tadka',
            quantity: 150.0,
            unit: 'grams',
            displayQuantity: 1.0,
            displayUnit: 'katori',
            nutrition: NutritionalInfo(
              calories: 180.0,
              protein: 8.0,
              carbs: 22.0,
              fat: 5.0,
              fiber: 6.0,
              vitamins: {'B1': 0.15},
              minerals: {'iron': 3.0},
            ),
            cookingMethod: 'tadka',
            confidence: 0.95,
            culturalContext: CulturalFoodContext(
              region: 'India',
              cookingStyle: 'tadka',
              mealType: 'main',
            ),
          ),
          DetailedFoodItem(
            id: 'food-2',
            name: 'Basmati Rice',
            originalName: 'chawal',
            quantity: 100.0,
            unit: 'grams',
            displayQuantity: 1.0,
            displayUnit: 'katori',
            nutrition: NutritionalInfo(
              calories: 130.0,
              protein: 2.5,
              carbs: 28.0,
              fat: 0.3,
              fiber: 0.4,
              vitamins: {'B1': 0.07},
              minerals: {'iron': 0.8},
            ),
            cookingMethod: 'steamed',
            confidence: 0.9,
            culturalContext: CulturalFoodContext(
              region: 'India',
              cookingStyle: 'steamed',
              mealType: 'staple',
            ),
          ),
        ],
        nutrition: NutritionalSummary(
          totalCalories: 310.0,
          totalProtein: 10.5,
          totalCarbs: 50.0,
          totalFat: 5.3,
          totalFiber: 6.4,
          vitamins: {'B1': 0.22},
          minerals: {'iron': 3.8},
          macroBreakdown: MacroBreakdown(
            proteinPercentage: 13.5,
            carbsPercentage: 64.5,
            fatPercentage: 15.4,
          ),
        ),
        voiceDescription: 'Maine dal chawal khaya lunch mein',
        confidenceScore: 0.925,
      );

      expect(lunchMeal.mealType, equals(MealType.lunch));
      expect(lunchMeal.foods.length, equals(2));
      expect(lunchMeal.foods.first.name, equals('Dal Tadka'));
      expect(lunchMeal.foods.last.name, equals('Basmati Rice'));
      expect(lunchMeal.nutrition.totalCalories, equals(310.0));
    });
  });
}