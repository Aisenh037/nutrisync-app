import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';
import 'package:nutrisync/voice/hinglish_processor.dart';

void main() {
  group('CulturalContextEngine Tests', () {
    late CulturalContextEngine engine;

    setUp(() {
      engine = CulturalContextEngine();
    });

    group('Cooking Style Identification', () {
      test('should identify tadka cooking method', () {
        final result = engine.identifyCookingStyle('dal with tadka of cumin seeds');
        
        expect(result.name, equals('tadka'));
        expect(result.description, contains('Tempering'));
        expect(result.nutritionMultiplier, equals(1.1));
        expect(result.commonIngredients, contains('cumin'));
      });

      test('should identify bhuna cooking method', () {
        final result = engine.identifyCookingStyle('bhuna masala with onions');
        
        expect(result.name, equals('bhuna'));
        expect(result.description, contains('Dry roasting'));
        expect(result.nutritionMultiplier, equals(1.0));
      });

      test('should identify dum cooking method', () {
        final result = engine.identifyCookingStyle('slow cooked dum biryani');
        
        expect(result.name, equals('dum'));
        expect(result.description, contains('Slow cooking'));
        expect(result.nutritionMultiplier, equals(1.2));
      });

      test('should return default method for unknown cooking style', () {
        final result = engine.identifyCookingStyle('some unknown cooking method');
        
        expect(result.name, equals('simple'));
        expect(result.nutritionMultiplier, equals(1.0));
      });
    });

    group('Indian Portion Estimation', () {
      test('should estimate katori portion correctly', () {
        final result = engine.estimateIndianPortion('dal', '2 katori');
        
        expect(result.quantity, equals(300.0)); // 2 * 150g
        expect(result.unit, equals('grams'));
        expect(result.indianReference, contains('2.0 katori'));
        expect(result.confidenceScore, greaterThan(0.5));
      });

      test('should estimate roti portion correctly', () {
        final result = engine.estimateIndianPortion('chapati', '3 roti');
        
        expect(result.quantity, equals(90.0)); // 3 * 30g
        expect(result.unit, equals('grams'));
        expect(result.indianReference, contains('3.0 roti'));
      });

      test('should handle single portion without number', () {
        final result = engine.estimateIndianPortion('rice', 'one glass');
        
        expect(result.quantity, equals(250.0)); // 1 * 250g
        expect(result.unit, equals('grams'));
        expect(result.indianReference, contains('glass'));
      });

      test('should default to katori for unknown units', () {
        final result = engine.estimateIndianPortion('curry', 'some portion');
        
        expect(result.quantity, equals(150.0)); // default katori
        expect(result.unit, equals('grams'));
      });
    });

    group('Meal Context Expansion', () {
      test('should suggest combinations for dal', () {
        final primaryFood = FoodItem(
          name: 'dal makhani',
          quantity: 1.0,
          unit: 'katori',
          nutrition: NutritionalInfo(
            calories: 150.0,
            protein: 8.0,
            carbs: 18.0,
            fat: 6.0,
            fiber: 4.0,
            vitamins: {},
            minerals: {},
          ),
          context: CulturalContext(
            region: 'North India',
            cookingMethod: 'dum',
            mealType: 'main',
            commonCombinations: [],
          ),
        );

        final suggestions = engine.expandMealContext(primaryFood);
        
        expect(suggestions.isNotEmpty, isTrue);
        final suggestionNames = suggestions.map((s) => s.name).toList();
        expect(suggestionNames, contains('rice'));
        expect(suggestionNames, contains('roti'));
      });

      test('should suggest combinations for rice', () {
        final primaryFood = FoodItem(
          name: 'basmati rice',
          quantity: 1.0,
          unit: 'katori',
          nutrition: NutritionalInfo(
            calories: 130.0,
            protein: 2.7,
            carbs: 28.0,
            fat: 0.3,
            fiber: 0.4,
            vitamins: {},
            minerals: {},
          ),
          context: CulturalContext(
            region: 'All India',
            cookingMethod: 'steamed',
            mealType: 'staple',
            commonCombinations: [],
          ),
        );

        final suggestions = engine.expandMealContext(primaryFood);
        
        expect(suggestions.isNotEmpty, isTrue);
        final suggestionNames = suggestions.map((s) => s.name).toList();
        expect(suggestionNames, contains('dal'));
        expect(suggestionNames, contains('curry'));
      });
    });

    group('Regional Context', () {
      test('should identify North Indian regional context', () {
        final result = engine.getRegionalContext('Delhi', 'butter chicken');
        
        expect(result.region, equals('North India'));
        expect(result.commonIngredients, contains('cream'));
        expect(result.commonIngredients, contains('butter'));
        expect(result.nutritionAdjustments['fat'], equals(1.3));
      });

      test('should identify South Indian regional context', () {
        final result = engine.getRegionalContext('Chennai', 'sambar');
        
        expect(result.region, equals('South India'));
        expect(result.commonIngredients, contains('coconut'));
        expect(result.commonIngredients, contains('curry leaves'));
        expect(result.nutritionAdjustments['fiber'], equals(1.2));
      });

      test('should identify West Indian regional context', () {
        final result = engine.getRegionalContext('Mumbai', 'dhokla');
        
        expect(result.region, equals('West India'));
        expect(result.commonIngredients, contains('jaggery'));
        expect(result.commonIngredients, contains('gram flour'));
      });

      test('should identify East Indian regional context', () {
        final result = engine.getRegionalContext('Kolkata', 'fish curry');
        
        expect(result.region, equals('East India'));
        expect(result.commonIngredients, contains('fish'));
        expect(result.commonIngredients, contains('mustard oil'));
      });
    });

    group('Indian Cooking Method Recognition', () {
      test('should recognize tadka as Indian cooking method', () {
        expect(engine.isIndianCookingMethod('tadka'), isTrue);
        expect(engine.isIndianCookingMethod('tempering'), isTrue);
        expect(engine.isIndianCookingMethod('chaunk'), isTrue);
      });

      test('should recognize bhuna as Indian cooking method', () {
        expect(engine.isIndianCookingMethod('bhuna'), isTrue);
        expect(engine.isIndianCookingMethod('bhuno'), isTrue);
      });

      test('should not recognize non-Indian cooking methods', () {
        expect(engine.isIndianCookingMethod('grilling'), isFalse);
        expect(engine.isIndianCookingMethod('baking'), isFalse);
        expect(engine.isIndianCookingMethod('broiling'), isFalse);
      });
    });

    group('Unit Conversion to Indian References', () {
      test('should convert cups to katori for rice', () {
        final result = engine.convertToIndianReference(2.0, 'cup', 'rice');
        expect(result, equals('3.0 katori'));
      });

      test('should convert tablespoons to spoons', () {
        final result = engine.convertToIndianReference(3.0, 'tablespoon', 'oil');
        expect(result, equals('3.0 spoon'));
      });

      test('should convert teaspoons to spoons', () {
        final result = engine.convertToIndianReference(3.0, 'teaspoon', 'salt');
        expect(result, equals('1.0 spoon'));
      });

      test('should handle unknown units', () {
        final result = engine.convertToIndianReference(5.0, 'unknown', 'food');
        expect(result, equals('5.0 unknown'));
      });
    });

    group('Helper Methods', () {
      test('should get cooking method information', () {
        final info = engine.getCookingMethodInfo('tadka');
        
        expect(info, isNotNull);
        expect(info!.name, equals('tadka'));
        expect(info.keywords, contains('tadka'));
        expect(info.nutritionMultiplier, equals(1.1));
      });

      test('should get supported measurements', () {
        final measurements = engine.getSupportedMeasurements();
        
        expect(measurements, isNotEmpty);
        expect(measurements['katori'], equals(150.0));
        expect(measurements['glass'], equals(250.0));
        expect(measurements['roti'], equals(30.0));
      });

      test('should get food combinations', () {
        final combinations = engine.getFoodCombinations('dal');
        
        expect(combinations, isNotEmpty);
        expect(combinations, contains('rice'));
        expect(combinations, contains('roti'));
      });

      test('should return empty list for unknown food category', () {
        final combinations = engine.getFoodCombinations('unknown');
        expect(combinations, isEmpty);
      });
    });
  });
}