import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/cultural/indian_food_database.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';
import 'package:nutrisync/voice/hinglish_processor.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';

void main() {
  group('IndianFoodItem Tests', () {
    test('should create IndianFoodItem with all properties', () {
      final foodItem = IndianFoodItem(
        id: 'test_dal',
        name: 'Test Dal',
        aliases: ['test dal', 'टेस्ट दाल'],
        nutrition: NutritionalInfo(
          calories: 100.0,
          protein: 5.0,
          carbs: 15.0,
          fat: 2.0,
          fiber: 3.0,
          vitamins: {'B1': 0.1},
          minerals: {'iron': 1.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'boiled',
            description: 'Simple boiled dal',
            nutritionMultiplier: 1.0,
            commonIngredients: ['dal', 'water'],
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
          primaryRegion: 'Test Region',
          availableRegions: ['Test Region'],
          regionalNames: {'test': 'Test Dal'},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['rice'],
        searchTerms: ['test dal'],
        baseDish: 'dal',
        regionalVariations: [],
      );

      expect(foodItem.name, equals('Test Dal'));
      expect(foodItem.category, equals(IndianFoodCategory.dal));
      expect(foodItem.nutrition.calories, equals(100.0));
      expect(foodItem.aliases.length, equals(2));
    });

    test('should convert to and from Firestore format', () {
      final originalItem = IndianFoodItem(
        id: 'test_item',
        name: 'Test Item',
        aliases: ['alias1', 'alias2'],
        nutrition: NutritionalInfo(
          calories: 200.0,
          protein: 10.0,
          carbs: 20.0,
          fat: 5.0,
          fiber: 4.0,
          vitamins: {'C': 15.0},
          minerals: {'iron': 2.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'steamed',
            description: 'Steamed preparation',
            nutritionMultiplier: 1.0,
            commonIngredients: ['main ingredient'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 100.0},
          visualReference: 'test portion',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'Test Region',
          availableRegions: ['Test Region'],
          regionalNames: {'test': 'Test'},
        ),
        category: IndianFoodCategory.snack,
        commonCombinations: ['combo1'],
        searchTerms: ['test'],
        baseDish: 'test',
        regionalVariations: [],
      );

      // Convert to Firestore format
      final firestoreData = originalItem.toFirestore();
      
      // Verify key fields are present
      expect(firestoreData['name'], equals('Test Item'));
      expect(firestoreData['category'], equals('snack'));
      expect(firestoreData['aliases'], isA<List>());
      expect(firestoreData['nutrition'], isA<Map>());
      
      // Note: We can't test fromFirestore without a DocumentSnapshot mock
      // This would require additional mocking setup
    });

    test('should convert to FoodItem correctly', () {
      final indianFoodItem = IndianFoodItem(
        id: 'test_conversion',
        name: 'Test Food',
        aliases: [],
        nutrition: NutritionalInfo(
          calories: 150.0,
          protein: 8.0,
          carbs: 20.0,
          fat: 3.0,
          fiber: 5.0,
          vitamins: {},
          minerals: {},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'boiled',
            description: 'Boiled',
            nutritionMultiplier: 1.0,
            commonIngredients: [],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {},
          visualReference: '',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'Test',
          availableRegions: [],
          regionalNames: {},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['rice'],
        searchTerms: [],
        baseDish: 'dal',
        regionalVariations: [],
      );

      final foodItem = indianFoodItem.toFoodItem(quantity: 2.0, unit: 'katori');
      
      expect(foodItem.name, equals('Test Food'));
      expect(foodItem.quantity, equals(2.0));
      expect(foodItem.unit, equals('katori'));
      expect(foodItem.context.mealType, equals('main'));
      expect(foodItem.context.commonCombinations, contains('rice'));
    });
  });

  group('NutritionalInfo Tests', () {
    test('should add nutritional values correctly', () {
      final nutrition1 = NutritionalInfo(
        calories: 100.0,
        protein: 5.0,
        carbs: 15.0,
        fat: 2.0,
        fiber: 3.0,
        vitamins: {'C': 10.0, 'B1': 0.1},
        minerals: {'iron': 1.0},
      );

      final nutrition2 = NutritionalInfo(
        calories: 50.0,
        protein: 3.0,
        carbs: 8.0,
        fat: 1.0,
        fiber: 2.0,
        vitamins: {'C': 5.0, 'B6': 0.2},
        minerals: {'iron': 0.5, 'calcium': 20.0},
      );

      final combined = nutrition1 + nutrition2;

      expect(combined.calories, equals(150.0));
      expect(combined.protein, equals(8.0));
      expect(combined.vitamins['C'], equals(15.0));
      expect(combined.vitamins['B1'], equals(0.1));
      expect(combined.vitamins['B6'], equals(0.2));
      expect(combined.minerals['iron'], equals(1.5));
      expect(combined.minerals['calcium'], equals(20.0));
    });

    test('should multiply nutritional values correctly', () {
      final nutrition = NutritionalInfo(
        calories: 100.0,
        protein: 5.0,
        carbs: 15.0,
        fat: 2.0,
        fiber: 3.0,
        vitamins: {'C': 10.0},
        minerals: {'iron': 1.0},
      );

      final doubled = nutrition * 2.0;

      expect(doubled.calories, equals(200.0));
      expect(doubled.protein, equals(10.0));
      expect(doubled.vitamins['C'], equals(20.0));
      expect(doubled.minerals['iron'], equals(2.0));
    });

    test('should serialize to and from Map correctly', () {
      final nutrition = NutritionalInfo(
        calories: 120.0,
        protein: 6.0,
        carbs: 18.0,
        fat: 3.0,
        fiber: 4.0,
        vitamins: {'C': 12.0, 'B1': 0.15},
        minerals: {'iron': 1.5, 'calcium': 25.0},
      );

      final map = nutrition.toMap();
      final reconstructed = NutritionalInfo.fromMap(map);

      expect(reconstructed.calories, equals(nutrition.calories));
      expect(reconstructed.protein, equals(nutrition.protein));
      expect(reconstructed.vitamins['C'], equals(nutrition.vitamins['C']));
      expect(reconstructed.minerals['iron'], equals(nutrition.minerals['iron']));
    });
  });

  group('CookingMethod Tests', () {
    test('should serialize to and from Map correctly', () {
      final cookingMethod = CookingMethod(
        name: 'tadka',
        description: 'Tempering with spices',
        nutritionMultiplier: 1.2,
        commonIngredients: ['cumin', 'mustard seeds'],
      );

      final map = cookingMethod.toMap();
      final reconstructed = CookingMethod.fromMap(map);

      expect(reconstructed.name, equals(cookingMethod.name));
      expect(reconstructed.description, equals(cookingMethod.description));
      expect(reconstructed.nutritionMultiplier, equals(cookingMethod.nutritionMultiplier));
      expect(reconstructed.commonIngredients, equals(cookingMethod.commonIngredients));
    });
  });
}