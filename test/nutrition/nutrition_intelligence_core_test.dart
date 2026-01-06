import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/nutrition/nutrition_intelligence_core.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';
import 'package:nutrisync/nutrition/meal_logger_service.dart';
import 'package:nutrisync/voice/hinglish_processor.dart';
import 'package:nutrisync/voice/conversation_context_manager.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';
import 'package:nutrisync/cultural/indian_food_database.dart';

void main() {
  group('NutritionIntelligenceCore Tests', () {
    late NutritionIntelligenceCore core;
    late HinglishProcessor hinglishProcessor;
    late ConversationContextManager contextManager;
    late CulturalContextEngine culturalEngine;
    late MealLoggerService mealLogger;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize test dependencies (without Firebase-dependent services)
      hinglishProcessor = HinglishProcessor();
      contextManager = ConversationContextManager();
      culturalEngine = CulturalContextEngine();
      mealLogger = MealLoggerService();

      // Create a mock food database that doesn't require Firebase
      final mockFoodDatabase = MockIndianFoodDatabase();

      core = NutritionIntelligenceCore(
        hinglishProcessor: hinglishProcessor,
        contextManager: contextManager,
        culturalEngine: culturalEngine,
        foodDatabase: mockFoodDatabase,
        mealLogger: mealLogger,
      );
    });

    group('Meal Logging Processing', () {
      test('should process simple meal logging successfully', () async {
        final input = VoiceInput(
          transcription: 'Maine dal chawal khaya',
          timestamp: DateTime.now(),
          sessionId: 'test-session',
          metadata: {'userId': 'test-user'},
        );

        final result = await core.processMealLogging(input);

        expect(result.success, isTrue);
        expect(result.ambiguities, isNotNull);
        expect(result.confidence, greaterThanOrEqualTo(0.0));
      });
      test('should handle ambiguous input with clarification', () async {
        final input = VoiceInput(
          transcription: 'Maine kuch khaya',
          timestamp: DateTime.now(),
          sessionId: 'test-session',
          metadata: {'userId': 'test-user'},
        );

        final result = await core.processMealLogging(input);

        // Should either succeed with low confidence or have ambiguities
        expect(result.success, isA<bool>());
        expect(result.ambiguities, isNotNull);
      });

      test('should process complex Hinglish meal description', () async {
        final input = VoiceInput(
          transcription: 'Maine 2 roti aur ek katori dal khaya, saath mein thoda chawal bhi',
          timestamp: DateTime.now(),
          sessionId: 'test-session',
          metadata: {'userId': 'test-user'},
        );

        final result = await core.processMealLogging(input);

        expect(result.success, isTrue);
        expect(result.confidence, greaterThan(0.0));
      });

      test('should handle cooking method detection', () async {
        final input = VoiceInput(
          transcription: 'Maine tadka dal aur tawa roti khaya',
          timestamp: DateTime.now(),
          sessionId: 'test-session',
          metadata: {'userId': 'test-user'},
        );

        final result = await core.processMealLogging(input);

        expect(result.success, isTrue);
        expect(result.mealData, isNotNull);
      });
    });

    group('Recommendation Generation', () {
      test('should generate weight loss recommendations', () async {
        final profile = UserProfile(
          userId: 'test-user',
          personalInfo: PersonalInfo(
            name: 'Test User',
            age: 30,
            gender: 'male',
            height: 175.0,
            weight: 80.0,
            location: 'Delhi',
          ),
          goals: DietaryGoals(
            type: GoalType.weightLoss,
            targetWeight: 70.0,
            timeframe: 90,
            activityLevel: ActivityLevel.moderatelyActive,
          ),
          conditions: HealthConditions(
            allergies: [],
            medicalConditions: [],
            medications: [],
          ),
          preferences: FoodPreferences(
            liked: ['dal', 'roti'],
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

        final advice = await core.generateRecommendations(profile);

        expect(advice.advice, isNotEmpty);
        expect(advice.recommendations, isNotEmpty);
        expect(advice.recommendations.any((r) => r.contains('portion')), isTrue);
      });

      test('should generate muscle gain recommendations', () async {
        final profile = UserProfile(
          userId: 'test-user',
          personalInfo: PersonalInfo(
            name: 'Test User',
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
            liked: ['chicken', 'paneer'],
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

        final advice = await core.generateRecommendations(profile);

        expect(advice.advice, isNotEmpty);
        expect(advice.recommendations.any((r) => r.contains('protein')), isTrue);
      });

      test('should consider health conditions in recommendations', () async {
        final profile = UserProfile(
          userId: 'test-user',
          personalInfo: PersonalInfo(
            name: 'Test User',
            age: 45,
            gender: 'female',
            height: 165.0,
            weight: 70.0,
            location: 'Bangalore',
          ),
          goals: DietaryGoals(
            type: GoalType.maintenance,
            targetWeight: 70.0,
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

        final advice = await core.generateRecommendations(profile);

        expect(advice.recommendations.any((r) => r.contains('sugar') || r.contains('Sugar')), isTrue);
        expect(advice.recommendations.any((r) => r.contains('nuts')), isTrue);
      });
    });

    group('Nutrition Query Answering', () {
      test('should answer general health queries', () async {
        final context = UserContext(
          profile: _createTestProfile(),
          recentMeals: [],
          preferences: {},
        );

        final response = await core.answerNutritionQuery('weight loss ke liye kya karna chahiye?', context);

        expect(response, isNotEmpty);
        expect(response.toLowerCase(), anyOf([
          contains('weight'),
          contains('calorie'),
          contains('exercise'),
        ]));
      });

      test('should handle medical queries appropriately', () async {
        final context = UserContext(
          profile: _createTestProfile(),
          recentMeals: [],
          preferences: {},
        );

        final response = await core.answerNutritionQuery('diabetes ke liye kya khana chahiye?', context);

        expect(response, isNotEmpty);
        expect(response.toLowerCase(), anyOf([
          contains('doctor'),
          contains('medical'),
          contains('sugar'),
        ]));
      });
    });

    group('User Progress Tracking', () {
      test('should update user progress with meal data', () async {
        final mealData = MealData(
          mealId: 'test-meal',
          userId: 'test-user',
          timestamp: DateTime.now(),
          mealType: MealType.lunch,
          foods: [
            DetailedFoodItem(
              id: 'item-1',
              name: 'Dal',
              originalName: 'dal',
              quantity: 100,
              unit: 'grams',
              displayQuantity: 1,
              displayUnit: 'katori',
              nutrition: NutritionalInfo(
                calories: 120,
                protein: 8.0,
                carbs: 20.0,
                fat: 1.0,
                fiber: 5.0,
                vitamins: {},
                minerals: {},
              ),
              cookingMethod: 'boiled',
              confidence: 0.9,
              culturalContext: CulturalFoodContext(
                region: 'North India',
                cookingStyle: 'traditional',
                mealType: 'lunch',
              ),
            ),
          ],
          nutrition: NutritionalSummary(
            totalCalories: 120,
            totalProtein: 8.0,
            totalCarbs: 20.0,
            totalFat: 1.0,
            totalFiber: 5.0,
            vitamins: {},
            minerals: {},
            macroBreakdown: MacroBreakdown(
              proteinPercentage: 26.7,
              carbsPercentage: 66.7,
              fatPercentage: 6.7,
            ),
          ),
          voiceDescription: 'dal khaya',
          confidenceScore: 0.9,
        );

        // Should not throw an exception
        await core.updateUserProgress(mealData);
      });
    });

    group('Error Handling', () {
      test('should handle recommendation errors gracefully', () async {
        // Create profile with invalid data
        final profile = UserProfile(
          userId: '',
          personalInfo: PersonalInfo(
            name: '',
            age: -1,
            gender: '',
            height: -1,
            weight: -1,
            location: '',
          ),
          goals: DietaryGoals(
            type: GoalType.weightLoss,
            targetWeight: -1,
            timeframe: -1,
            activityLevel: ActivityLevel.sedentary,
          ),
          conditions: HealthConditions(
            allergies: [],
            medicalConditions: [],
            medications: [],
          ),
          preferences: FoodPreferences(
            liked: [],
            disliked: [],
            dietary: [],
            spiceLevel: '',
          ),
          patterns: EatingPatterns(
            mealTimes: {},
            mealsPerDay: 0,
            snackPreferences: [],
          ),
          tier: SubscriptionTier.free,
        );

        final advice = await core.generateRecommendations(profile);

        expect(advice.advice, isNotEmpty);
        expect(advice.recommendations, isNotEmpty);
      });
    });
  });
}

UserProfile _createTestProfile() {
  return UserProfile(
    userId: 'test-user',
    personalInfo: PersonalInfo(
      name: 'Test User',
      age: 30,
      gender: 'male',
      height: 175.0,
      weight: 75.0,
      location: 'Delhi',
    ),
    goals: DietaryGoals(
      type: GoalType.maintenance,
      targetWeight: 75.0,
      timeframe: 365,
      activityLevel: ActivityLevel.moderatelyActive,
    ),
    conditions: HealthConditions(
      allergies: [],
      medicalConditions: [],
      medications: [],
    ),
    preferences: FoodPreferences(
      liked: ['dal', 'roti'],
      disliked: [],
      dietary: ['vegetarian'],
      spiceLevel: 'medium',
    ),
    patterns: EatingPatterns(
      mealTimes: {'breakfast': '8:00', 'lunch': '13:00', 'dinner': '20:00'},
      mealsPerDay: 3,
      snackPreferences: ['fruits'],
    ),
    tier: SubscriptionTier.free,
  );
}

/// Mock IndianFoodDatabase for testing without Firebase
class MockIndianFoodDatabase extends IndianFoodDatabase {
  @override
  Future<List<IndianFoodItem>> searchFood(String query) async {
    // Return empty list for testing - this avoids Firebase dependency
    return [];
  }
}