import 'cultural_context_engine.dart';
import '../voice/hinglish_processor.dart';

/// Example usage of the Cultural Context Engine
/// Demonstrates how to use the engine for Indian food context understanding
class CulturalContextExample {
  final CulturalContextEngine _engine = CulturalContextEngine();

  /// Demonstrate cooking method identification
  void demonstrateCookingMethods() {
    print('=== Cooking Method Identification ===');
    
    final descriptions = [
      'dal with tadka of cumin seeds',
      'bhuna masala with onions',
      'slow cooked dum biryani',
      'tawa roti on griddle',
      'tandoor chicken with marinade',
      'steamed idli',
      'deep fried samosa',
    ];

    for (var desc in descriptions) {
      final method = _engine.identifyCookingStyle(desc);
      print('Description: "$desc"');
      print('Method: ${method.name} (${method.nutritionMultiplier}x nutrition)');
      print('Ingredients: ${method.commonIngredients.join(', ')}');
      print('---');
    }
  }

  /// Demonstrate Indian portion estimation
  void demonstratePortionEstimation() {
    print('\n=== Indian Portion Estimation ===');
    
    final portions = [
      {'food': 'dal', 'portion': '2 katori'},
      {'food': 'rice', 'portion': '1 glass'},
      {'food': 'chapati', 'portion': '3 roti'},
      {'food': 'curry', 'portion': '1 plate'},
      {'food': 'sabzi', 'portion': 'handful'},
    ];

    for (var item in portions) {
      final portion = _engine.estimateIndianPortion(item['food']!, item['portion']!);
      print('Food: ${item['food']}, Portion: ${item['portion']}');
      print('Estimated: ${portion.quantity}g (${portion.indianReference})');
      print('Confidence: ${(portion.confidenceScore * 100).toStringAsFixed(1)}%');
      print('---');
    }
  }

  /// Demonstrate meal context expansion
  void demonstrateMealContext() {
    print('\n=== Meal Context Expansion ===');
    
    // Create a sample dal food item
    final dalItem = FoodItem(
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

    final suggestions = _engine.expandMealContext(dalItem);
    print('Primary Food: ${dalItem.name}');
    print('Suggested Combinations:');
    for (var suggestion in suggestions) {
      print('- ${suggestion.name} (${suggestion.quantity} ${suggestion.unit})');
    }
  }

  /// Demonstrate regional context understanding
  void demonstrateRegionalContext() {
    print('\n=== Regional Context Understanding ===');
    
    final locations = [
      {'location': 'Delhi', 'dish': 'butter chicken'},
      {'location': 'Chennai', 'dish': 'sambar'},
      {'location': 'Mumbai', 'dish': 'dhokla'},
      {'location': 'Kolkata', 'dish': 'fish curry'},
    ];

    for (var item in locations) {
      final context = _engine.getRegionalContext(item['location']!, item['dish']!);
      print('Location: ${item['location']}, Dish: ${item['dish']}');
      print('Region: ${context.region}');
      print('Cooking Style: ${context.cookingStyle.name}');
      print('Common Ingredients: ${context.commonIngredients.join(', ')}');
      print('Nutrition Adjustments: ${context.nutritionAdjustments}');
      print('---');
    }
  }

  /// Demonstrate unit conversion
  void demonstrateUnitConversion() {
    print('\n=== Unit Conversion to Indian References ===');
    
    final conversions = [
      {'quantity': 2.0, 'unit': 'cup', 'food': 'rice'},
      {'quantity': 3.0, 'unit': 'tablespoon', 'food': 'oil'},
      {'quantity': 6.0, 'unit': 'teaspoon', 'food': 'salt'},
      {'quantity': 8.0, 'unit': 'ounce', 'food': 'paneer'},
    ];

    for (var item in conversions) {
      final converted = _engine.convertToIndianReference(
        item['quantity'] as double,
        item['unit'] as String,
        item['food'] as String,
      );
      print('${item['quantity']} ${item['unit']} of ${item['food']} = $converted');
    }
  }

  /// Demonstrate cooking method recognition
  void demonstrateCookingMethodRecognition() {
    print('\n=== Indian Cooking Method Recognition ===');
    
    final methods = [
      'tadka', 'tempering', 'bhuna', 'dum', 'tawa',
      'grilling', 'baking', 'broiling', 'sautéing'
    ];

    for (var method in methods) {
      final isIndian = _engine.isIndianCookingMethod(method);
      print('$method: ${isIndian ? 'Indian' : 'Non-Indian'} cooking method');
    }
  }

  /// Run all demonstrations
  void runAllDemonstrations() {
    print('🍛 Cultural Context Engine Demonstration 🍛\n');
    
    demonstrateCookingMethods();
    demonstratePortionEstimation();
    demonstrateMealContext();
    demonstrateRegionalContext();
    demonstrateUnitConversion();
    demonstrateCookingMethodRecognition();
    
    print('\n✅ All demonstrations completed!');
  }
}