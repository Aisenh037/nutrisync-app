/// Integration Example: Voice-First AI Agent
/// 
/// This example demonstrates how the voice and cultural components work together
/// to provide a seamless Indian food tracking experience.

import '../voice/voice_interface.dart';
import '../voice/conversation_context_manager.dart';
import '../cultural/cultural_context_engine.dart';
import '../cultural/indian_food_database.dart';

class VoiceCulturalIntegrationExample {
  final VoiceInterface _voiceInterface;
  final ConversationContextManager _contextManager;
  final CulturalContextEngine _culturalEngine;
  final IndianFoodDatabase _foodDatabase;

  VoiceCulturalIntegrationExample({
    required String elevenLabsApiKey,
  }) : _voiceInterface = VoiceInterface(elevenLabsApiKey: elevenLabsApiKey),
       _contextManager = ConversationContextManager(),
       _culturalEngine = CulturalContextEngine(),
       _foodDatabase = IndianFoodDatabase();

  /// Demonstrates complete voice-to-nutrition workflow
  Future<void> demonstrateVoiceToNutritionWorkflow() async {
    print('=== Voice-First AI Agent Integration Demo ===\n');

    // 1. Start voice conversation
    print('1. Starting voice conversation...');
    final stream = _voiceInterface.startConversation(
      userId: 'demo_user',
      initialContext: {
        'userPreferences': {
          'vegetarian': true,
          'region': 'North India',
          'preferred_units': 'indian',
        },
      },
    );
    print('✓ Voice conversation started with session: ${_voiceInterface.currentSessionId}\n');

    // 2. Simulate Hinglish voice input
    print('2. Processing Hinglish voice input...');
    const hinglishInput = 'Maine lunch mein tadka dal aur 2 roti khaya';
    print('User said: "$hinglishInput"');

    // 3. Extract cultural context
    print('\n3. Extracting cultural context...');
    final cookingMethod = _culturalEngine.identifyCookingStyle(hinglishInput);
    print('✓ Cooking method identified: ${cookingMethod.name} (nutrition multiplier: ${cookingMethod.nutritionMultiplier})');

    final dalPortion = _culturalEngine.estimateIndianPortion('dal', '1 katori');
    final rotiPortion = _culturalEngine.estimateIndianPortion('roti', '2');
    print('✓ Portions estimated:');
    print('  - Dal: ${dalPortion.quantity}g (${dalPortion.indianReference})');
    print('  - Roti: ${rotiPortion.quantity}g (${rotiPortion.indianReference})');

    // 4. Add to conversation context
    print('\n4. Adding meal to conversation context...');
    _voiceInterface.addMealContext({
      'type': 'lunch',
      'timestamp': DateTime.now().toIso8601String(),
      'foods': [
        {
          'name': 'tadka dal',
          'quantity': dalPortion.quantity,
          'cooking_method': cookingMethod.name,
          'calories': (150 * cookingMethod.nutritionMultiplier).round(),
        },
        {
          'name': 'roti',
          'quantity': rotiPortion.quantity,
          'calories': 70 * 2, // 2 rotis
        },
      ],
      'cultural_context': {
        'region': 'North India',
        'meal_pattern': 'traditional',
        'cooking_style': cookingMethod.name,
      },
    });
    print('✓ Meal context added to conversation');

    // 5. Generate contextual response
    print('\n5. Generating contextual response...');
    final context = _voiceInterface.getConversationContext();
    if (context != null) {
      final sessionId = _voiceInterface.currentSessionId!;
      final response = _contextManager.generateContextualResponse(
        sessionId,
        'How was my meal?',
        'Your meal was good.',
      );
      print('✓ Contextual response: "$response"');
    }

    // 6. Demonstrate meal expansion
    print('\n6. Suggesting meal combinations...');
    final dalFood = FoodItem(
      name: 'tadka dal',
      quantity: dalPortion.quantity,
      unit: 'grams',
      nutrition: NutritionalInfo(
        calories: 150.0,
        protein: 8.0,
        carbs: 20.0,
        fat: 2.0,
        fiber: 5.0,
        vitamins: {},
        minerals: {},
      ),
      context: CulturalContext(
        region: 'North India',
        cookingMethod: 'tadka',
        mealType: 'lunch',
        commonCombinations: [],
      ),
    );

    final suggestions = _culturalEngine.expandMealContext(dalFood);
    print('✓ Meal suggestions based on cultural context:');
    for (final suggestion in suggestions.take(3)) {
      print('  - ${suggestion.name} (${suggestion.quantity}${suggestion.unit})');
    }

    // 7. Demonstrate regional context
    print('\n7. Regional food context...');
    final regionalContext = _culturalEngine.getRegionalContext('North India', 'dal');
    print('✓ Regional context for dal in ${regionalContext.region}:');
    print('  - Common ingredients: ${regionalContext.commonIngredients.join(', ')}');
    print('  - Cooking style: ${regionalContext.cookingStyle.name}');

    // 8. Demonstrate interruption handling
    print('\n8. Testing conversation interruption...');
    if (context != null) {
      final sessionId = _voiceInterface.currentSessionId!;
      _contextManager.handleInterruption(sessionId, reason: 'phone_call');
      print('✓ Conversation interrupted (reason: phone_call)');
      
      final resumptionMessage = _contextManager.resumeConversation(sessionId);
      print('✓ Conversation resumed: "$resumptionMessage"');
    }

    // 9. Show final context state
    print('\n9. Final conversation state...');
    final finalContext = _voiceInterface.getConversationContext();
    if (finalContext != null) {
      print('✓ Session active: ${finalContext.conversationState == ConversationState.active}');
      print('✓ Meal context preserved: ${finalContext.currentMealContext != null}');
      print('✓ User preferences: ${finalContext.userPreferences}');
    }

    // 10. Clean up
    print('\n10. Cleaning up...');
    _voiceInterface.dispose();
    _contextManager.dispose();
    print('✓ Resources cleaned up');

    print('\n=== Integration Demo Complete ===');
    print('✅ Voice and cultural components successfully integrated!');
  }

  /// Demonstrates concurrent operations
  void demonstrateConcurrentOperations() {
    print('\n=== Concurrent Operations Demo ===');

    // Multiple cultural operations
    final cooking1 = _culturalEngine.identifyCookingStyle('tadka dal');
    final cooking2 = _culturalEngine.identifyCookingStyle('bhuna masala');
    final cooking3 = _culturalEngine.identifyCookingStyle('dum biryani');

    print('✓ Concurrent cooking method identification:');
    print('  - tadka dal → ${cooking1.name}');
    print('  - bhuna masala → ${cooking2.name}');
    print('  - dum biryani → ${cooking3.name}');

    // Multiple portion estimations
    final portion1 = _culturalEngine.estimateIndianPortion('dal', '2 katori');
    final portion2 = _culturalEngine.estimateIndianPortion('rice', '1 plate');
    final portion3 = _culturalEngine.estimateIndianPortion('roti', '3');

    print('✓ Concurrent portion estimations:');
    print('  - 2 katori dal → ${portion1.quantity}g');
    print('  - 1 plate rice → ${portion2.quantity}g');
    print('  - 3 roti → ${portion3.quantity}g');

    print('✅ Concurrent operations working correctly!');
  }

  /// Demonstrates error handling
  void demonstrateErrorHandling() {
    print('\n=== Error Handling Demo ===');

    // Test unknown cooking methods
    final unknownCooking = _culturalEngine.identifyCookingStyle('unknown cooking method');
    print('✓ Unknown cooking method fallback: ${unknownCooking.name}');

    // Test invalid session operations
    try {
      _contextManager.handleInterruption('invalid_session');
    } catch (e) {
      print('✓ Invalid session error handled: ${e.runtimeType}');
    }

    // Test voice interface error handling
    try {
      _voiceInterface.stopListening(); // Should not crash
      print('✓ Voice interface error handling works');
    } catch (e) {
      print('✗ Unexpected voice interface error: $e');
    }

    print('✅ Error handling working correctly!');
  }
}

// Data classes for the example (these would normally be imported)
class FoodItem {
  final String name;
  final double quantity;
  final String unit;
  final NutritionalInfo nutrition;
  final CulturalContext context;

  FoodItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.nutrition,
    required this.context,
  });
}

class NutritionalInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final Map<String, double> vitamins;
  final Map<String, double> minerals;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.vitamins,
    required this.minerals,
  });
}

class CulturalContext {
  final String region;
  final String cookingMethod;
  final String mealType;
  final List<String> commonCombinations;

  CulturalContext({
    required this.region,
    required this.cookingMethod,
    required this.mealType,
    required this.commonCombinations,
  });
}

/// Example usage
Future<void> main() async {
  final example = VoiceCulturalIntegrationExample(
    elevenLabsApiKey: 'your_elevenlabs_api_key_here',
  );

  await example.demonstrateVoiceToNutritionWorkflow();
  example.demonstrateConcurrentOperations();
  example.demonstrateErrorHandling();
}