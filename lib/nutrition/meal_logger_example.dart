import 'meal_logger_service.dart';
import 'meal_data_models.dart';
import '../voice/hinglish_processor.dart';

/// Example demonstrating MealLoggerService functionality
/// Shows how to use the meal logging system with voice input
class MealLoggerExample {
  final MealLoggerService _mealLogger = MealLoggerService();

  /// Example 1: Basic meal logging from voice description
  Future<void> demonstrateBasicMealLogging() async {
    print('=== Basic Meal Logging Example ===');
    
    const userId = 'user123';
    const voiceDescription = 'Maine breakfast mein do aloo paratha aur ek glass doodh piya';
    
    print('Voice Input: "$voiceDescription"');
    
    try {
      final result = await _mealLogger.logMealFromVoice(voiceDescription, userId);
      
      if (result.success) {
        print('✅ Meal logged successfully!');
        print('Confirmation: ${result.message}');
        print('Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        
        if (result.mealData != null) {
          final meal = result.mealData!;
          print('\nMeal Details:');
          print('- Meal ID: ${meal.mealId}');
          print('- Type: ${meal.mealType.displayName}');
          print('- Foods: ${meal.foods.map((f) => f.originalName).join(', ')}');
          print('- Total Calories: ${meal.nutrition.totalCalories.round()}');
          print('- Protein: ${meal.nutrition.totalProtein.toStringAsFixed(1)}g');
          print('- Carbs: ${meal.nutrition.totalCarbs.toStringAsFixed(1)}g');
          print('- Fat: ${meal.nutrition.totalFat.toStringAsFixed(1)}g');
        }
      } else {
        print('❌ Meal logging failed: ${result.message}');
        if (result.ambiguities.isNotEmpty) {
          print('Clarification needed for: ${result.ambiguities.map((a) => a.text).join(', ')}');
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    
    print('');
  }

  /// Example 2: Handling ambiguous food descriptions
  Future<void> demonstrateAmbiguityHandling() async {
    print('=== Ambiguity Handling Example ===');
    
    const userId = 'user123';
    const ambiguousDescription = 'Maine kuch khaya tha';
    
    print('Voice Input: "$ambiguousDescription"');
    
    try {
      final result = await _mealLogger.logMealFromVoice(ambiguousDescription, userId);
      
      if (!result.success && result.ambiguities.isNotEmpty) {
        print('❓ Clarification needed:');
        print('Response: ${result.message}');
        print('Ambiguities found: ${result.ambiguities.length}');
        
        for (final ambiguity in result.ambiguities) {
          print('- ${ambiguity.text}: ${ambiguity.possibleMeanings.join(', ')}');
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    
    print('');
  }

  /// Example 3: Complex meal with multiple foods
  Future<void> demonstrateComplexMeal() async {
    print('=== Complex Meal Example ===');
    
    const userId = 'user123';
    const complexDescription = 'Lunch mein maine ek katori dal tadka, do roti, thoda chawal aur salad khaya';
    
    print('Voice Input: "$complexDescription"');
    
    try {
      final result = await _mealLogger.logMealFromVoice(complexDescription, userId);
      
      if (result.success && result.mealData != null) {
        final meal = result.mealData!;
        print('✅ Complex meal logged successfully!');
        print('Confirmation: ${result.message}');
        
        print('\nDetailed Breakdown:');
        for (int i = 0; i < meal.foods.length; i++) {
          final food = meal.foods[i];
          print('${i + 1}. ${food.name}');
          print('   - Original: "${food.originalName}"');
          print('   - Quantity: ${food.displayQuantity} ${food.displayUnit}');
          print('   - Calories: ${food.nutrition.calories.round()}');
          print('   - Cooking: ${food.cookingMethod ?? 'traditional'}');
          print('   - Confidence: ${(food.confidence * 100).toStringAsFixed(1)}%');
        }
        
        print('\nNutritional Summary:');
        print('- Total Calories: ${meal.nutrition.totalCalories.round()}');
        print('- Protein: ${meal.nutrition.totalProtein.toStringAsFixed(1)}g (${meal.nutrition.macroBreakdown.proteinPercentage.toStringAsFixed(1)}%)');
        print('- Carbs: ${meal.nutrition.totalCarbs.toStringAsFixed(1)}g (${meal.nutrition.macroBreakdown.carbsPercentage.toStringAsFixed(1)}%)');
        print('- Fat: ${meal.nutrition.totalFat.toStringAsFixed(1)}g (${meal.nutrition.macroBreakdown.fatPercentage.toStringAsFixed(1)}%)');
        print('- Fiber: ${meal.nutrition.totalFiber.toStringAsFixed(1)}g');
        
        if (meal.nutrition.vitamins.isNotEmpty) {
          print('- Vitamins: ${meal.nutrition.vitamins.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(', ')}');
        }
        
        if (meal.nutrition.minerals.isNotEmpty) {
          print('- Minerals: ${meal.nutrition.minerals.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(', ')}');
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    
    print('');
  }

  /// Example 4: Meal history and similar meals
  Future<void> demonstrateMealHistory() async {
    print('=== Meal History Example ===');
    
    const userId = 'user123';
    
    try {
      // Get recent meal history
      final history = await _mealLogger.getMealHistory(userId, days: 7);
      print('📊 Recent meals (last 7 days): ${history.length}');
      
      if (history.isNotEmpty) {
        print('\nRecent Meals:');
        for (int i = 0; i < history.take(3).length; i++) {
          final meal = history[i];
          print('${i + 1}. ${meal.mealType.displayName} - ${meal.timestamp.day}/${meal.timestamp.month}');
          print('   Foods: ${meal.foods.map((f) => f.originalName).join(', ')}');
          print('   Calories: ${meal.nutrition.totalCalories.round()}');
        }
      }
      
      // Get today's nutrition summary
      final todayNutrition = await _mealLogger.getTodaysNutrition(userId);
      if (todayNutrition != null) {
        print('\n📈 Today\'s Nutrition Summary:');
        print('- Total Calories: ${todayNutrition.totalCalories.round()}');
        print('- Total Protein: ${todayNutrition.totalProtein.toStringAsFixed(1)}g');
        print('- Total Carbs: ${todayNutrition.totalCarbs.toStringAsFixed(1)}g');
        print('- Total Fat: ${todayNutrition.totalFat.toStringAsFixed(1)}g');
        print('- Meals logged: ${todayNutrition.mealCount}');
      }
      
      // Find similar meals
      final similarMeals = await _mealLogger.findSimilarMeals(userId, ['dal', 'rice']);
      print('\n🔍 Similar meals with dal/rice: ${similarMeals.length}');
      
    } catch (e) {
      print('❌ Error: $e');
    }
    
    print('');
  }

  /// Example 5: Data model serialization
  void demonstrateDataSerialization() {
    print('=== Data Serialization Example ===');
    
    // Create sample meal data
    final mealData = MealData(
      mealId: 'example-meal-1',
      userId: 'user123',
      timestamp: DateTime.now(),
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
            vitamins: {'B1': 0.15, 'Folate': 90.0},
            minerals: {'iron': 3.0, 'magnesium': 40.0},
          ),
          cookingMethod: 'tadka',
          confidence: 0.95,
          culturalContext: CulturalFoodContext(
            region: 'India',
            cookingStyle: 'tadka',
            mealType: 'main',
          ),
        ),
      ],
      nutrition: NutritionalSummary(
        totalCalories: 180.0,
        totalProtein: 8.0,
        totalCarbs: 22.0,
        totalFat: 5.0,
        totalFiber: 6.0,
        vitamins: {'B1': 0.15, 'Folate': 90.0},
        minerals: {'iron': 3.0, 'magnesium': 40.0},
        macroBreakdown: MacroBreakdown(
          proteinPercentage: 17.8,
          carbsPercentage: 48.9,
          fatPercentage: 25.0,
        ),
      ),
      voiceDescription: 'Maine lunch mein dal tadka khaya',
      confidenceScore: 0.95,
    );
    
    // Serialize to map
    final serialized = mealData.toMap();
    print('✅ Meal data serialized to map');
    print('Map keys: ${serialized.keys.join(', ')}');
    
    // Deserialize back to object
    final deserialized = MealData.fromMap(serialized);
    print('✅ Meal data deserialized from map');
    print('Meal ID: ${deserialized.mealId}');
    print('Foods count: ${deserialized.foods.length}');
    print('Total calories: ${deserialized.nutrition.totalCalories}');
    
    print('');
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    print('🍽️ MealLoggerService Examples\n');
    
    await demonstrateBasicMealLogging();
    await demonstrateAmbiguityHandling();
    await demonstrateComplexMeal();
    await demonstrateMealHistory();
    demonstrateDataSerialization();
    
    print('✅ All examples completed!');
  }
}

/// Main function to run the examples
Future<void> main() async {
  final example = MealLoggerExample();
  await example.runAllExamples();
}