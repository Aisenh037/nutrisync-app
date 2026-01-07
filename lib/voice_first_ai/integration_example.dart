import 'dart:async';
import 'service_orchestrator.dart';
import '../models/user_model.dart';
import '../services/user_profile_service.dart';

/// Complete integration example demonstrating Voice-First AI Agent capabilities
/// This example shows how all backend services work together seamlessly
class VoiceFirstAIIntegrationExample {
  late final VoiceFirstAIServiceOrchestrator _orchestrator;
  late final UserProfileService _userProfileService;
  
  bool _isInitialized = false;

  /// Initialize the integration example
  Future<bool> initialize() async {
    try {
      _orchestrator = VoiceFirstAIServiceOrchestrator();
      _userProfileService = UserProfileService();

      // Initialize the orchestrator with ElevenLabs API key
      // In production, this would come from secure configuration
      final success = await _orchestrator.initialize(
        elevenLabsApiKey: 'your-elevenlabs-api-key-here',
        voiceId: 'pNInz6obpgDQGcFmaJgB', // Adam voice
      );

      if (success) {
        _isInitialized = true;
        print('✅ Voice-First AI Integration initialized successfully');
        return true;
      } else {
        print('❌ Failed to initialize Voice-First AI Integration');
        return false;
      }
    } catch (e) {
      print('❌ Error initializing integration: $e');
      return false;
    }
  }

  /// Demonstrate complete meal logging workflow
  Future<void> demonstrateMealLogging() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n🍽️ === MEAL LOGGING DEMONSTRATION ===');
    
    try {
      // Create a test user
      final testUser = await _createTestUser();
      
      // Start voice conversation
      final session = await _orchestrator.startVoiceConversation(
        userId: testUser.uid,
        initialContext: {
          'userPreferences': testUser.toMap(),
          'currentGoal': 'weight_maintenance',
        },
      );

      print('📱 Started voice conversation session: ${session.sessionId}');

      // Simulate various meal logging scenarios
      final mealInputs = [
        'Maine breakfast mein dal paratha aur chai khayi',
        'Lunch mein rajma chawal khaya, bahut tasty tha',
        'Evening snack mein samosa aur chutney li',
        'Dinner mein aloo gobi, roti aur dahi khaya',
      ];

      for (final input in mealInputs) {
        print('\n🎤 User says: "$input"');
        
        final result = await _orchestrator.processVoiceInteraction(
          userInput: input,
          userId: testUser.uid,
          sessionId: session.sessionId,
        );

        print('🤖 AI responds: "${result.systemResponse}"');
        print('📊 Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        
        if (result.requiresClarification) {
          print('❓ Needs clarification: ${result.ambiguities.map((a) => a.term).join(', ')}');
        }

        if (result.responseData.containsKey('mealData')) {
          final mealData = result.responseData['mealData'];
          print('✅ Meal logged successfully with ${mealData['nutrition']['totalCalories'].toStringAsFixed(0)} calories');
        }

        // Simulate voice response
        await _orchestrator.generateAndPlayVoiceResponse(result.systemResponse);
        
        // Small delay to simulate natural conversation
        await Future.delayed(const Duration(seconds: 1));
      }

      print('\n📈 Getting meal history with recommendations...');
      final mealHistory = await _orchestrator.getMealHistoryWithRecommendations(testUser.uid);
      
      print('📋 Meal History: ${mealHistory.mealHistory.length} meals logged');
      print('💡 Recommendations: ${mealHistory.recommendations.length} suggestions');
      print('🎯 Insights: ${mealHistory.insights.join(', ')}');

    } catch (e) {
      print('❌ Error in meal logging demonstration: $e');
    }
  }

  /// Demonstrate nutrition query processing
  Future<void> demonstrateNutritionQueries() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n🧠 === NUTRITION QUERY DEMONSTRATION ===');

    try {
      final testUser = await _createTestUser();
      
      final nutritionQueries = [
        'Dal mein kitni protein hoti hai?',
        'Weight loss ke liye kya khana chahiye?',
        'Diabetes mein kya avoid karna chahiye?',
        'Protein ke liye best Indian foods kya hain?',
        'Calcium ke liye kya khana chahiye?',
      ];

      for (final query in nutritionQueries) {
        print('\n🎤 User asks: "$query"');
        
        final result = await _orchestrator.processVoiceInteraction(
          userInput: query,
          userId: testUser.uid,
        );

        print('🤖 AI explains: "${result.systemResponse}"');
        print('📚 Query type: ${result.interactionType}');
        
        if (result.suggestions.isNotEmpty) {
          print('💡 Suggestions: ${result.suggestions.take(3).join(', ')}');
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('❌ Error in nutrition query demonstration: $e');
    }
  }

  /// Demonstrate personalized recommendations
  Future<void> demonstrateRecommendations() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n🎯 === PERSONALIZED RECOMMENDATIONS DEMONSTRATION ===');

    try {
      // Create users with different profiles
      final users = [
        await _createTestUser(
          name: 'Priya',
          healthGoals: ['Weight loss'],
          medicalConditions: [],
          dietaryNeeds: ['vegetarian'],
        ),
        await _createTestUser(
          name: 'Rahul',
          healthGoals: ['Muscle building'],
          medicalConditions: [],
          dietaryNeeds: ['vegetarian'],
        ),
        await _createTestUser(
          name: 'Sunita',
          healthGoals: ['Health maintenance'],
          medicalConditions: ['Diabetes'],
          dietaryNeeds: ['vegetarian'],
        ),
      ];

      for (final user in users) {
        print('\n👤 User: ${user.name} (Goals: ${user.healthGoals.join(', ')})');
        
        final result = await _orchestrator.processVoiceInteraction(
          userInput: 'Mere liye kya recommend karoge?',
          userId: user.uid,
        );

        print('🤖 AI recommends: "${result.systemResponse}"');
        
        if (result.responseData.containsKey('recommendations')) {
          final recommendations = result.responseData['recommendations'] as List;
          print('📋 Specific recommendations:');
          for (int i = 0; i < recommendations.length && i < 3; i++) {
            final rec = recommendations[i];
            print('   ${i + 1}. ${rec['food']} - ${rec['portion']} (${rec['calories']} cal)');
          }
        }
      }
    } catch (e) {
      print('❌ Error in recommendations demonstration: $e');
    }
  }

  /// Demonstrate cooking education features
  Future<void> demonstrateCookingEducation() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n👨‍🍳 === COOKING EDUCATION DEMONSTRATION ===');

    try {
      final testUser = await _createTestUser();
      
      final cookingQueries = [
        'Dal kaise banau healthy?',
        'Sabzi mein oil kam kaise karu?',
        'Roti soft kaise banegi?',
        'Palak ke fayde kya hain?',
        'Diabetes mein kya cooking tips hain?',
      ];

      for (final query in cookingQueries) {
        print('\n🎤 User asks: "$query"');
        
        final result = await _orchestrator.processVoiceInteraction(
          userInput: query,
          userId: testUser.uid,
        );

        print('👨‍🍳 AI teaches: "${result.systemResponse}"');
        
        if (result.responseData.containsKey('tips')) {
          final tips = result.responseData['tips'] as List;
          if (tips.isNotEmpty) {
            print('💡 Key tip: ${tips.first}');
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('❌ Error in cooking education demonstration: $e');
    }
  }

  /// Demonstrate grocery management
  Future<void> demonstrateGroceryManagement() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n🛒 === GROCERY MANAGEMENT DEMONSTRATION ===');

    try {
      final testUser = await _createTestUser();
      
      // First, log some meals to generate grocery list
      final mealInputs = [
        'Maine dal chawal khaya',
        'Aloo sabzi bhi khayi',
        'Roti aur dahi liya',
      ];

      print('📝 Logging meals for grocery list generation...');
      for (final input in mealInputs) {
        await _orchestrator.processVoiceInteraction(
          userInput: input,
          userId: testUser.uid,
        );
      }

      // Generate grocery list
      print('\n🛒 Generating grocery list...');
      final result = await _orchestrator.processVoiceInteraction(
        userInput: 'Grocery list banao mere liye',
        userId: testUser.uid,
      );

      print('🤖 AI responds: "${result.systemResponse}"');
      
      if (result.responseData.containsKey('groceryList')) {
        final groceryData = result.responseData['groceryList'];
        print('💰 Estimated cost: ₹${result.responseData['totalCost'].toStringAsFixed(0)}');
        print('📦 Total items: ${result.responseData['itemCount']}');
      }

      // Demonstrate direct grocery list generation
      print('\n📋 Generating detailed grocery list...');
      final groceryList = await _orchestrator.generateGroceryListFromMeals(testUser.uid);
      
      print('🛒 Generated grocery list with ${groceryList.categorizedItems.length} categories');
      for (final category in groceryList.categorizedItems.keys) {
        final items = groceryList.categorizedItems[category]!;
        print('   ${category.toString().split('.').last}: ${items.length} items');
      }

    } catch (e) {
      print('❌ Error in grocery management demonstration: $e');
    }
  }

  /// Demonstrate conversation context and interruption handling
  Future<void> demonstrateConversationContext() async {
    if (!_isInitialized) {
      print('❌ Integration not initialized');
      return;
    }

    print('\n💬 === CONVERSATION CONTEXT DEMONSTRATION ===');

    try {
      final testUser = await _createTestUser();
      
      // Start conversation session
      final session = await _orchestrator.startVoiceConversation(
        userId: testUser.uid,
      );

      print('📱 Started conversation session: ${session.sessionId}');

      // Multi-turn conversation
      final conversationFlow = [
        'Maine dal chawal khaya lunch mein',
        'Isme kitni calories thi?',
        'Aur protein kitni thi?',
        'Weight loss ke liye kya suggest karoge?',
      ];

      for (int i = 0; i < conversationFlow.length; i++) {
        final input = conversationFlow[i];
        print('\n🎤 Turn ${i + 1}: "$input"');
        
        final result = await _orchestrator.processVoiceInteraction(
          userInput: input,
          userId: testUser.uid,
          sessionId: session.sessionId,
        );

        print('🤖 AI responds: "${result.systemResponse}"');
        
        // Simulate interruption in the middle
        if (i == 2) {
          print('\n📞 Simulating interruption (phone call)...');
          _orchestrator.handleInterruption(reason: 'Phone call');
          
          await Future.delayed(const Duration(seconds: 2));
          
          print('📱 Resuming conversation...');
          final resumptionMessage = await _orchestrator.resumeConversation();
          print('🤖 AI resumes: "$resumptionMessage"');
        }

        await Future.delayed(const Duration(milliseconds: 800));
      }

      // End conversation
      _orchestrator.endConversation();
      print('\n✅ Conversation ended gracefully');

    } catch (e) {
      print('❌ Error in conversation context demonstration: $e');
    }
  }

  /// Run complete integration demonstration
  Future<void> runCompleteDemo() async {
    print('🚀 === VOICE-FIRST AI AGENT COMPLETE INTEGRATION DEMO ===\n');
    
    if (!await initialize()) {
      print('❌ Failed to initialize. Exiting demo.');
      return;
    }

    try {
      await demonstrateMealLogging();
      await Future.delayed(const Duration(seconds: 2));
      
      await demonstrateNutritionQueries();
      await Future.delayed(const Duration(seconds: 2));
      
      await demonstrateRecommendations();
      await Future.delayed(const Duration(seconds: 2));
      
      await demonstrateCookingEducation();
      await Future.delayed(const Duration(seconds: 2));
      
      await demonstrateGroceryManagement();
      await Future.delayed(const Duration(seconds: 2));
      
      await demonstrateConversationContext();
      
      print('\n🎉 === INTEGRATION DEMO COMPLETED SUCCESSFULLY ===');
      print('✅ All backend services are properly integrated and working together!');
      
    } catch (e) {
      print('❌ Error during complete demo: $e');
    } finally {
      dispose();
    }
  }

  /// Create a test user for demonstrations
  Future<UserModel> _createTestUser({
    String name = 'Test User',
    List<String> healthGoals = const ['Weight maintenance'],
    List<String> medicalConditions = const [],
    List<String> dietaryNeeds = const ['vegetarian'],
  }) async {
    final user = UserModel(
      uid: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
      email: 'demo@nutrisync.com',
      name: name,
      age: 28,
      gender: 'Female',
      height: 165.0,
      weight: 60.0,
      healthGoals: healthGoals,
      medicalConditions: medicalConditions,
      allergies: [],
      dietaryNeeds: dietaryNeeds,
      foodDislikes: [],
      culturalPreferences: {
        'preferredRegion': 'North Indian',
        'spiceLevel': 'medium',
      },
      activityLevel: 'Moderate',
      isPremium: true, // Enable all features for demo
    );

    // Save user profile
    await _userProfileService.createUserProfile(user);
    
    return user;
  }

  /// Dispose of resources
  void dispose() {
    if (_isInitialized) {
      _orchestrator.dispose();
      _isInitialized = false;
      print('🧹 Resources cleaned up');
    }
  }
}

/// Main function to run the integration example
Future<void> main() async {
  final example = VoiceFirstAIIntegrationExample();
  await example.runCompleteDemo();
}

/// Utility function to demonstrate specific workflow
Future<void> demonstrateSpecificWorkflow(String workflow) async {
  final example = VoiceFirstAIIntegrationExample();
  
  if (!await example.initialize()) {
    print('❌ Failed to initialize');
    return;
  }

  try {
    switch (workflow.toLowerCase()) {
      case 'meal_logging':
        await example.demonstrateMealLogging();
        break;
      case 'nutrition_queries':
        await example.demonstrateNutritionQueries();
        break;
      case 'recommendations':
        await example.demonstrateRecommendations();
        break;
      case 'cooking_education':
        await example.demonstrateCookingEducation();
        break;
      case 'grocery_management':
        await example.demonstrateGroceryManagement();
        break;
      case 'conversation_context':
        await example.demonstrateConversationContext();
        break;
      default:
        print('❌ Unknown workflow: $workflow');
        print('Available workflows: meal_logging, nutrition_queries, recommendations, cooking_education, grocery_management, conversation_context');
    }
  } finally {
    example.dispose();
  }
}