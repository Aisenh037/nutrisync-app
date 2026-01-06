import 'hinglish_processor.dart';

/// Example demonstrating HinglishProcessor functionality
/// Shows how to process mixed Hindi-English food descriptions and nutrition queries
void main() {
  final processor = HinglishProcessor();
  
  print('=== Hinglish Food Processing Examples ===\n');
  
  // Example 1: Simple meal logging
  print('1. Simple Meal Logging:');
  final result1 = processor.extractFoodItems('maine dal chawal khaya');
  print('Input: "maine dal chawal khaya"');
  print('Extracted foods: ${result1.foodItems.map((item) => '${item.name} (${item.originalText})').join(', ')}');
  print('Confidence: ${(result1.confidence * 100).toStringAsFixed(1)}%\n');
  
  // Example 2: Meal with quantities
  print('2. Meal with Quantities:');
  final result2 = processor.extractFoodItems('do katori dal aur teen roti khaya');
  print('Input: "do katori dal aur teen roti khaya"');
  for (final item in result2.foodItems) {
    print('- ${item.name}: ${item.quantity?.amount} ${item.quantity?.unit}');
  }
  print('');
  
  // Example 3: Cooking methods
  print('3. Cooking Methods:');
  final result3 = processor.extractFoodItems('tadka dal aur tawa roti banaya');
  print('Input: "tadka dal aur tawa roti banaya"');
  for (final item in result3.foodItems) {
    print('- ${item.name} (${item.cookingMethod ?? 'no method'})');
  }
  print('');
  
  // Example 4: Mixed Hindi-English
  print('4. Mixed Hindi-English:');
  final result4 = processor.extractFoodItems('I had aloo sabzi with rice and chai');
  print('Input: "I had aloo sabzi with rice and chai"');
  print('Extracted foods: ${result4.foodItems.map((item) => item.name).join(', ')}\n');
  
  // Example 5: Ambiguous terms
  print('5. Ambiguous Terms:');
  final result5 = processor.extractFoodItems('dal aur sabzi khaya');
  print('Input: "dal aur sabzi khaya"');
  print('Foods: ${result5.foodItems.map((item) => item.name).join(', ')}');
  print('Ambiguities found: ${result5.ambiguities.length}');
  for (final amb in result5.ambiguities) {
    print('- ${amb.term}: ${amb.possibleMeanings.join(', ')}');
  }
  
  // Generate clarification questions
  if (result5.ambiguities.isNotEmpty) {
    print('Clarification questions:');
    final questions = processor.generateClarificationQuestions(result5.ambiguities);
    for (final question in questions) {
      print('- $question');
    }
  }
  print('');
  
  // Example 6: Complex meal description
  print('6. Complex Meal Description:');
  final result6 = processor.extractFoodItems(
    'breakfast mein do aloo paratha, thoda dahi aur ek cup masala chai li'
  );
  print('Input: "breakfast mein do aloo paratha, thoda dahi aur ek cup masala chai li"');
  print('Foods found: ${result6.foodItems.length}');
  for (final item in result6.foodItems) {
    final quantity = item.quantity != null ? '${item.quantity!.amount} ${item.quantity!.unit}' : 'unspecified';
    print('- ${item.name} ($quantity) - confidence: ${(item.confidence * 100).toStringAsFixed(1)}%');
  }
  print('');
  
  print('=== Nutrition Query Processing Examples ===\n');
  
  // Example 7: Calorie inquiry
  print('7. Calorie Inquiry:');
  final query1 = processor.parseNutritionQuery('dal mein kitni calorie hai?');
  print('Input: "dal mein kitni calorie hai?"');
  print('Query type: ${query1.queryType}');
  print('Foods mentioned: ${query1.foodItems.map((item) => item.name).join(', ')}\n');
  
  // Example 8: Health inquiry with concerns
  print('8. Health Inquiry with Medical Concerns:');
  final query2 = processor.parseNutritionQuery(
    'diabetes mein kya khana chahiye? weight loss bhi karna hai'
  );
  print('Input: "diabetes mein kya khana chahiye? weight loss bhi karna hai"');
  print('Query type: ${query2.queryType}');
  print('Medical concerns: ${query2.nutritionConcerns.join(', ')}');
  print('Requires clarification: ${query2.requiresClarification}\n');
  
  // Example 9: Mixed language nutrition query
  print('9. Mixed Language Nutrition Query:');
  final query3 = processor.parseNutritionQuery(
    'Kya paneer makhani healthy hai? Mujhe weight loss karna hai'
  );
  print('Input: "Kya paneer makhani healthy hai? Mujhe weight loss karna hai"');
  print('Query type: ${query3.queryType}');
  print('Foods mentioned: ${query3.foodItems.map((item) => item.name).join(', ')}');
  print('Concerns: ${query3.nutritionConcerns.join(', ')}\n');
  
  // Example 10: Typical user interaction flow
  print('10. Typical User Interaction Flow:');
  print('User says: "maine lunch mein dal chawal khaya, kitni calorie thi?"');
  
  // First extract the meal
  final mealResult = processor.extractFoodItems('maine lunch mein dal chawal khaya');
  print('Meal extraction:');
  for (final item in mealResult.foodItems) {
    print('- ${item.name} (original: ${item.originalText})');
  }
  
  // Then process the nutrition query
  final nutritionQuery = processor.parseNutritionQuery('kitni calorie thi?');
  print('Nutrition query type: ${nutritionQuery.queryType}');
  
  // Check for ambiguities
  if (mealResult.ambiguities.isNotEmpty) {
    print('Clarification needed for: ${mealResult.ambiguities.map((amb) => amb.term).join(', ')}');
    final clarifications = processor.generateClarificationQuestions(mealResult.ambiguities);
    print('Bot would ask: ${clarifications.first}');
  } else {
    print('No clarification needed - can proceed with calorie calculation');
  }
  
  print('\n=== Summary ===');
  print('The HinglishProcessor successfully handles:');
  print('✓ Mixed Hindi-English food descriptions');
  print('✓ Quantity extraction with Indian measurements');
  print('✓ Cooking method recognition');
  print('✓ Ambiguity detection and clarification');
  print('✓ Various nutrition query types');
  print('✓ Medical concern identification');
  print('✓ Confidence scoring for reliability');
}

/// Demonstration of advanced HinglishProcessor features
void demonstrateAdvancedFeatures() {
  final processor = HinglishProcessor();
  
  print('\n=== Advanced Features Demo ===\n');
  
  // Regional food variations
  print('Regional Food Variations:');
  final regionalFoods = [
    'south indian idli sambar khaya',
    'punjabi makki di roti sarson da saag',
    'bengali machher jhol bhat',
    'gujarati dhokla khaman'
  ];
  
  for (final food in regionalFoods) {
    final result = processor.extractFoodItems(food);
    print('$food -> ${result.foodItems.map((item) => item.name).join(', ')}');
  }
  
  print('\nQuantity Variations:');
  final quantities = [
    'thoda sa dal',
    'zyada chawal',
    'aadha katori sabzi',
    'poora plate khana'
  ];
  
  for (final qty in quantities) {
    final result = processor.extractFoodItems(qty);
    for (final item in result.foodItems) {
      if (item.quantity != null) {
        print('$qty -> ${item.name}: ${item.quantity!.amount} ${item.quantity!.unit}');
      }
    }
  }
  
  print('\nCooking Method Recognition:');
  final cookingMethods = [
    'bhuna masala',
    'dum biryani',
    'tandoor roti',
    'steamed idli',
    'fried pakora'
  ];
  
  for (final method in cookingMethods) {
    final result = processor.extractFoodItems(method);
    for (final item in result.foodItems) {
      print('$method -> ${item.name} (${item.cookingMethod ?? 'no method detected'})');
    }
  }
}