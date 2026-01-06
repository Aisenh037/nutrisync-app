import 'nutrition_intelligence_core.dart';
import 'meal_data_models.dart';
import 'meal_logger_service.dart';
import '../voice/hinglish_processor.dart';
import '../voice/conversation_context_manager.dart';
import '../cultural/cultural_context_engine.dart';

/// Example demonstrating NutritionIntelligenceCore functionality
/// This shows how to use the core service for meal logging, recommendations, and queries
class NutritionIntelligenceExample {
  late NutritionIntelligenceCore _core;

  Future<void> initialize() async {
    // Initialize all dependencies (without Firebase-dependent services for demo)
    final hinglishProcessor = HinglishProcessor();
    final contextManager = ConversationContextManager();
    final culturalEngine = CulturalContextEngine();
    final mockFoodDatabase = MockFoodDatabase();
    final mealLogger = MealLoggerService();

    _core = NutritionIntelligenceCore(
      hinglishProcessor: hinglishProcessor,
      contextManager: contextManager,
      culturalEngine: culturalEngine,
      foodDatabase: mockFoodDatabase,
      mealLogger: mealLogger,
    );

    print('✅ NutritionIntelligenceCore initialized successfully');
  }

  /// Example 1: Process voice meal logging
  Future<void> demonstrateMealLogging() async {
    print('\n🍽️ === Meal Logging Example ===');
    
    final voiceInputs = [
      'Maine breakfast mein 2 roti aur ek glass milk liya',
      'Lunch mein dal chawal khaya, thoda achar bhi',
      'Maine tadka dal aur jeera rice khaya dinner mein',
      'Snack mein samosa aur chai li',
    ];

    for (final input in voiceInputs) {
      print('\n📝 Processing: "$input"');
      
      final voiceInput = VoiceInput(
        transcription: input,
        timestamp: DateTime.now(),
        sessionId: 'demo-session',
        metadata: {'userId': 'demo-user'},
      );

      try {
        final result = await _core.processMealLogging(voiceInput);
        
        if (result.success) {
          print('✅ Success: ${result.message}');
          print('   Confidence: ${result.confidence.toStringAsFixed(2)}');
          if (result.mealData != null) {
            print('   Total calories: ${result.mealData!.nutrition.totalCalories.toInt()}');
            print('   Meal type: ${result.mealData!.mealType}');
          }
        } else {
          print('❌ Error: ${result.message}');
        }
      } catch (e) {
        print('❌ Exception: $e');
      }
    }
  }

  /// Example 2: Generate personalized recommendations
  Future<void> demonstrateRecommendations() async {
    print('\n💡 === Personalized Recommendations Example ===');
    
    final profiles = [
      _createWeightLossProfile(),
      _createMuscleGainProfile(),
      _createDiabeticProfile(),
    ];

    for (final profile in profiles) {
      print('\n👤 Profile: ${profile.personalInfo.name} (Goal: ${profile.goals.type.toString().split('.').last})');
      
      final advice = await _core.generateRecommendations(profile);
      
      print('💬 Main advice: ${advice.advice}');
      print('📋 Recommendations:');
      for (int i = 0; i < advice.recommendations.length; i++) {
        print('   ${i + 1}. ${advice.recommendations[i]}');
      }
    }
  }

  /// Example 3: Answer nutrition queries
  Future<void> demonstrateNutritionQueries() async {
    print('\n❓ === Nutrition Query Answering Example ===');
    
    final context = UserContext(
      profile: _createWeightLossProfile(),
      recentMeals: [],
      preferences: {},
    );

    final queries = [
      'dal mein kitne calories hain?',
      'paneer mein protein kitna hai?',
      'weight loss ke liye kya khana chahiye?',
      'diabetes mein kya avoid karna chahiye?',
      'muscle gain ke liye best foods kya hain?',
      'high fiber foods kya hain?',
    ];

    for (final query in queries) {
      print('\n❓ Query: "$query"');
      final response = await _core.answerNutritionQuery(query, context);
      print('💬 Response: $response');
    }
  }

  /// Example 4: User progress tracking
  Future<void> demonstrateProgressTracking() async {
    print('\n📊 === User Progress Tracking Example ===');
    
    final sampleMeals = [
      _createSampleMeal('breakfast', ['roti', 'milk'], DateTime.now().subtract(Duration(hours: 2))),
      _createSampleMeal('lunch', ['dal', 'rice'], DateTime.now().subtract(Duration(hours: 1))),
      _createSampleMeal('snack', ['fruits'], DateTime.now().subtract(Duration(minutes: 30))),
    ];

    for (final meal in sampleMeals) {
      print('\n📝 Tracking meal: ${meal.mealType} - ${meal.items.map((i) => i.name).join(', ')}');
      await _core.updateUserProgress(meal);
      print('✅ Progress updated successfully');
    }
  }

  /// Example 5: Complete workflow demonstration
  Future<void> demonstrateCompleteWorkflow() async {
    print('\n🔄 === Complete Workflow Example ===');
    
    // Step 1: User logs a meal via voice
    print('\n1️⃣ User says: "Maine breakfast mein poha aur chai li"');
    final voiceInput = VoiceInput(
      transcription: 'Maine breakfast mein poha aur chai li',
      timestamp: DateTime.now(),
      sessionId: 'workflow-session',
      metadata: {'userId': 'workflow-user'},
    );

    try {
      final logResult = await _core.processMealLogging(voiceInput);
      print('   Meal logged: ${logResult.success ? 'Success' : 'Failed'}');

      // Step 2: Generate recommendations based on user profile
      print('\n2️⃣ Generating personalized recommendations...');
      final profile = _createWeightLossProfile();
      final advice = await _core.generateRecommendations(profile);
      print('   Advice: ${advice.advice}');

      // Step 3: User asks a follow-up question
      print('\n3️⃣ User asks: "Poha healthy hai kya?"');
      final context = UserContext(
        profile: profile,
        recentMeals: logResult.mealData != null ? [logResult.mealData!] : [],
        preferences: {},
      );
      final response = await _core.answerNutritionQuery('Poha healthy hai kya?', context);
      print('   Response: $response');

      // Step 4: Update progress
      print('\n4️⃣ Updating user progress...');
      if (logResult.mealData != null) {
        await _core.updateUserProgress(logResult.mealData!);
        print('   Progress updated successfully');
      }
    } catch (e) {
      print('❌ Error in workflow: $e');
    }
  }

  // Helper methods to create test profiles and data

  UserProfile _createWeightLossProfile() {
    return UserProfile(
      userId: 'user-weightloss',
      personalInfo: PersonalInfo(
        name: 'Priya Sharma',
        age: 28,
        gender: 'female',
        height: 165.0,
        weight: 70.0,
        location: 'Delhi',
      ),
      goals: DietaryGoals(
        type: GoalType.weightLoss,
        targetWeight: 60.0,
        timeframe: 90,
        activityLevel: ActivityLevel.moderatelyActive,
      ),
      conditions: HealthConditions(
        allergies: [],
        medicalConditions: [],
        medications: [],
      ),
      preferences: FoodPreferences(
        liked: ['dal', 'sabzi', 'roti'],
        disliked: ['fish'],
        dietary: ['vegetarian'],
        spiceLevel: 'medium',
      ),
      patterns: EatingPatterns(
        mealTimes: {'breakfast': '8:00', 'lunch': '13:00', 'dinner': '20:00'},
        mealsPerDay: 3,
        snackPreferences: ['fruits', 'nuts'],
      ),
      tier: SubscriptionTier.free,
    );
  }

  UserProfile _createMuscleGainProfile() {
    return UserProfile(
      userId: 'user-musclegain',
      personalInfo: PersonalInfo(
        name: 'Rahul Kumar',
        age: 25,
        gender: 'male',
        height: 180.0,
        weight: 70.0,
        location: 'Mumbai',
      ),
      goals: DietaryGoals(
        type: GoalType.muscleGain,
        targetWeight: 80.0,
        timeframe: 120,
        activityLevel: ActivityLevel.veryActive,
      ),
      conditions: HealthConditions(
        allergies: [],
        medicalConditions: [],
        medications: [],
      ),
      preferences: FoodPreferences(
        liked: ['chicken', 'paneer', 'dal'],
        disliked: [],
        dietary: [],
        spiceLevel: 'high',
      ),
      patterns: EatingPatterns(
        mealTimes: {'breakfast': '7:00', 'lunch': '12:00', 'dinner': '19:00'},
        mealsPerDay: 4,
        snackPreferences: ['protein bars', 'nuts'],
      ),
      tier: SubscriptionTier.premium,
    );
  }

  UserProfile _createDiabeticProfile() {
    return UserProfile(
      userId: 'user-diabetic',
      personalInfo: PersonalInfo(
        name: 'Sunita Agarwal',
        age: 45,
        gender: 'female',
        height: 160.0,
        weight: 65.0,
        location: 'Bangalore',
      ),
      goals: DietaryGoals(
        type: GoalType.maintenance,
        targetWeight: 65.0,
        timeframe: 365,
        activityLevel: ActivityLevel.lightlyActive,
      ),
      conditions: HealthConditions(
        allergies: ['nuts'],
        medicalConditions: ['diabetes'],
        medications: ['metformin'],
      ),
      preferences: FoodPreferences(
        liked: ['vegetables', 'dal'],
        disliked: ['sweets'],
        dietary: ['vegetarian'],
        spiceLevel: 'low',
      ),
      patterns: EatingPatterns(
        mealTimes: {'breakfast': '8:00', 'lunch': '13:00', 'dinner': '19:00'},
        mealsPerDay: 3,
        snackPreferences: ['fruits'],
      ),
      tier: SubscriptionTier.free,
    );
  }

  MealData _createSampleMeal(String mealType, List<String> foodNames, DateTime timestamp) {
    final items = foodNames.map((name) => DetailedFoodItem(
      id: '${name}_${timestamp.millisecondsSinceEpoch}',
      name: name,
      originalName: name.toLowerCase(),
      quantity: 100,
      unit: 'grams',
      displayQuantity: 1,
      displayUnit: 'serving',
      nutrition: NutritionalInfo(
        calories: 100,
        protein: 5.0,
        carbs: 15.0,
        fat: 2.0,
        fiber: 3.0,
        vitamins: {},
        minerals: {},
      ),
      cookingMethod: 'cooked',
      confidence: 0.8,
      culturalContext: CulturalFoodContext(
        region: 'North India',
        cookingStyle: 'traditional',
        mealType: mealType,
      ),
    )).toList();

    return MealData(
      mealId: 'meal_${timestamp.millisecondsSinceEpoch}',
      userId: 'sample-user',
      timestamp: timestamp,
      mealType: MealType.values.firstWhere(
        (type) => type.toString().split('.').last == mealType,
        orElse: () => MealType.lunch,
      ),
      foods: items,
      nutrition: NutritionalSummary(
        totalCalories: items.length * 100,
        totalProtein: items.length * 5.0,
        totalCarbs: items.length * 15.0,
        totalFat: items.length * 2.0,
        totalFiber: items.length * 3.0,
        vitamins: {},
        minerals: {},
        macroBreakdown: MacroBreakdown(
          proteinPercentage: 20.0,
          carbsPercentage: 60.0,
          fatPercentage: 20.0,
        ),
      ),
      voiceDescription: '${foodNames.join(' and ')} khaya',
      confidenceScore: 0.8,
    );
  }
}

/// Mock food database for demo purposes
class MockFoodDatabase {
  Future<List<dynamic>> searchFood(String query) async {
    // Return empty list for demo - in real app this would search Firebase
    return [];
  }
}
}

/// Run all examples
Future<void> runNutritionIntelligenceExamples() async {
  final example = NutritionIntelligenceExample();
  
  try {
    await example.initialize();
    await example.demonstrateMealLogging();
    await example.demonstrateRecommendations();
    await example.demonstrateNutritionQueries();
    await example.demonstrateProgressTracking();
    await example.demonstrateCompleteWorkflow();
    
    print('\n🎉 All examples completed successfully!');
  } catch (e) {
    print('❌ Error running examples: $e');
  }
}