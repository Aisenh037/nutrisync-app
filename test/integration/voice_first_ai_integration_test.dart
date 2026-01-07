import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/voice_first_ai/service_orchestrator.dart';
import '../../lib/voice/voice_interface.dart';
import '../../lib/services/user_profile_service.dart';
import '../../lib/models/user_model.dart';
import '../../lib/nutrition/meal_data_models.dart';

// Generate mocks
@GenerateMocks([VoiceInterface, UserProfileService])
import 'voice_first_ai_integration_test.mocks.dart';

void main() {
  group('Voice-First AI Integration Tests', () {
    late VoiceFirstAIServiceOrchestrator orchestrator;
    late MockVoiceInterface mockVoiceInterface;
    late MockUserProfileService mockUserProfileService;

    setUp(() {
      mockVoiceInterface = MockVoiceInterface();
      mockUserProfileService = MockUserProfileService();
      orchestrator = VoiceFirstAIServiceOrchestrator();
    });

    tearDown(() {
      orchestrator.dispose();
    });

    group('Service Initialization', () {
      test('should initialize all services successfully', () async {
        // Mock voice interface initialization
        when(mockVoiceInterface.initialize()).thenAnswer((_) async => true);
        
        final result = await orchestrator.initialize(
          elevenLabsApiKey: 'test-api-key',
        );
        
        expect(result, isTrue);
        expect(orchestrator.isInitialized, isTrue);
      });

      test('should handle initialization failure gracefully', () async {
        // Mock voice interface initialization failure
        when(mockVoiceInterface.initialize()).thenAnswer((_) async => false);
        
        final result = await orchestrator.initialize(
          elevenLabsApiKey: 'invalid-api-key',
        );
        
        expect(result, isFalse);
        expect(orchestrator.isInitialized, isFalse);
      });
    });

    group('End-to-End Voice Meal Logging', () {
      test('should process complete meal logging workflow', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final testUser = UserModel(
          uid: 'test-user-123',
          email: 'test@example.com',
          name: 'Test User',
          age: 30,
          gender: 'Male',
          height: 175.0,
          weight: 70.0,
          healthGoals: ['Weight maintenance'],
          medicalConditions: [],
          allergies: [],
          dietaryNeeds: ['vegetarian'],
          foodDislikes: [],
          culturalPreferences: {'preferredRegion': 'North Indian'},
          activityLevel: 'Moderate',
          isPremium: false,
        );

        // Mock user profile service
        when(mockUserProfileService.getUserProfile('test-user-123'))
            .thenAnswer((_) async => testUser);

        // Test meal logging
        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal chawal khaya hai',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.mealLogging));
        expect(result.systemResponse, isNotEmpty);
        expect(result.confidence, greaterThan(0.0));
      });

      test('should handle ambiguous food descriptions', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        // Test ambiguous input
        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal khaya hai',
          userId: 'test-user-123',
        );

        expect(result.requiresClarification, isTrue);
        expect(result.ambiguities, isNotEmpty);
        expect(result.systemResponse, contains('kya matlab hai'));
      });
    });

    group('Nutrition Query Processing', () {
      test('should answer calorie-related questions', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Dal mein kitni calories hain?',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.nutritionQuery));
        expect(result.systemResponse, contains('calories'));
        expect(result.suggestions, isNotEmpty);
      });

      test('should provide protein information', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Protein ke liye kya khana chahiye?',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.nutritionQuery));
        expect(result.systemResponse, contains('protein'));
        expect(result.systemResponse, anyOf([
          contains('dal'),
          contains('paneer'),
          contains('chicken'),
        ]));
      });
    });

    group('Recommendation Engine Integration', () {
      test('should generate personalized food recommendations', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final testUser = UserModel(
          uid: 'test-user-123',
          email: 'test@example.com',
          name: 'Test User',
          age: 25,
          gender: 'Female',
          height: 160.0,
          weight: 55.0,
          healthGoals: ['Weight loss'],
          medicalConditions: [],
          allergies: [],
          dietaryNeeds: ['vegetarian'],
          foodDislikes: [],
          culturalPreferences: {'preferredRegion': 'South Indian'},
          activityLevel: 'Light',
          isPremium: true,
        );

        when(mockUserProfileService.getUserProfile('test-user-123'))
            .thenAnswer((_) async => testUser);

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Kya recommend karoge weight loss ke liye?',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.recommendation));
        expect(result.systemResponse, isNotEmpty);
        expect(result.responseData, containsKey('recommendations'));
        expect(result.suggestions, isNotEmpty);
      });

      test('should handle recommendation requests without profile', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        when(mockUserProfileService.getUserProfile('test-user-123'))
            .thenAnswer((_) async => null);

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Kya khana chahiye healthy ke liye?',
          userId: 'test-user-123',
        );

        expect(result.systemResponse, contains('profile complete'));
        expect(result.suggestions, contains('Complete your profile'));
      });
    });

    group('Cooking Education Integration', () {
      test('should provide cooking tips for Indian foods', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Dal kaise banate hain healthy?',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.cookingEducation));
        expect(result.systemResponse, anyOf([
          contains('cooking'),
          contains('tip'),
          contains('healthy'),
        ]));
        expect(result.responseData, containsKey('tips'));
      });

      test('should explain nutrition benefits', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Palak ke fayde kya hain?',
          userId: 'test-user-123',
        );

        expect(result.systemResponse, anyOf([
          contains('benefit'),
          contains('vitamin'),
          contains('iron'),
          contains('healthy'),
        ]));
      });
    });

    group('Grocery Management Integration', () {
      test('should generate grocery list from meals', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        // First log some meals
        await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal chawal khaya',
          userId: 'test-user-123',
        );

        await orchestrator.processVoiceInteraction(
          userInput: 'Aloo sabzi bhi khayi',
          userId: 'test-user-123',
        );

        // Then request grocery list
        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Grocery list banao',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.groceryManagement));
        expect(result.responseData, containsKey('groceryList'));
        expect(result.responseData, containsKey('totalCost'));
      });

      test('should handle grocery request without meal history', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Shopping list chahiye',
          userId: 'new-user-456',
        );

        expect(result.systemResponse, contains('meals log'));
        expect(result.suggestions, contains('Log some meals first'));
      });
    });

    group('Conversation Context Management', () {
      test('should maintain context across multiple interactions', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final session = await orchestrator.startVoiceConversation(
          userId: 'test-user-123',
        );

        // First interaction - log meal
        final result1 = await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal chawal khaya',
          userId: 'test-user-123',
          sessionId: session.sessionId,
        );

        expect(result1.interactionType, equals(VoiceInteractionType.mealLogging));

        // Second interaction - follow-up question
        final result2 = await orchestrator.processVoiceInteraction(
          userInput: 'Isme kitni calories thi?',
          userId: 'test-user-123',
          sessionId: session.sessionId,
        );

        expect(result2.systemResponse, contains('calories'));
        // Should reference the previously logged meal
      });

      test('should handle conversation interruption and resumption', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final session = await orchestrator.startVoiceConversation(
          userId: 'test-user-123',
        );

        // Start conversation
        await orchestrator.processVoiceInteraction(
          userInput: 'Maine breakfast kiya',
          userId: 'test-user-123',
          sessionId: session.sessionId,
        );

        // Interrupt conversation
        orchestrator.handleInterruption(reason: 'Phone call');

        // Resume conversation
        final resumptionMessage = await orchestrator.resumeConversation();

        expect(resumptionMessage, isNotEmpty);
        expect(resumptionMessage, anyOf([
          contains('breakfast'),
          contains('meal'),
          contains('baat kar rahe the'),
        ]));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle empty voice input gracefully', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: '',
          userId: 'test-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.generalConversation));
        expect(result.systemResponse, isNotEmpty);
      });

      test('should handle unknown food items', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Maine xyz unknown food khaya',
          userId: 'test-user-123',
        );

        expect(result.systemResponse, anyOf([
          contains('samajh nahi paya'),
          contains('detail'),
          contains('aur batao'),
        ]));
      });

      test('should handle service errors gracefully', () async {
        // Setup with invalid configuration to trigger errors
        final result = await orchestrator.initialize(
          elevenLabsApiKey: '',
        );

        expect(result, isFalse);
        expect(orchestrator.isInitialized, isFalse);
      });
    });

    group('Premium vs Free Tier Features', () {
      test('should provide basic features for free users', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final freeUser = UserModel(
          uid: 'free-user-123',
          email: 'free@example.com',
          name: 'Free User',
          isPremium: false,
        );

        when(mockUserProfileService.getUserProfile('free-user-123'))
            .thenAnswer((_) async => freeUser);

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal khaya',
          userId: 'free-user-123',
        );

        expect(result.interactionType, equals(VoiceInteractionType.mealLogging));
        expect(result.systemResponse, isNotEmpty);
      });

      test('should provide advanced features for premium users', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');
        
        final premiumUser = UserModel(
          uid: 'premium-user-123',
          email: 'premium@example.com',
          name: 'Premium User',
          isPremium: true,
          healthGoals: ['Weight loss'],
          medicalConditions: ['Diabetes'],
        );

        when(mockUserProfileService.getUserProfile('premium-user-123'))
            .thenAnswer((_) async => premiumUser);

        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Grocery list banao',
          userId: 'premium-user-123',
        );

        // Premium users should get grocery management
        expect(result.interactionType, equals(VoiceInteractionType.groceryManagement));
      });
    });

    group('Performance and Scalability', () {
      test('should handle multiple concurrent sessions', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        // Start multiple sessions
        final session1 = await orchestrator.startVoiceConversation(
          userId: 'user-1',
        );
        
        final session2 = await orchestrator.startVoiceConversation(
          userId: 'user-2',
        );

        expect(session1.sessionId, isNotEmpty);
        expect(session2.sessionId, isNotEmpty);
        expect(session1.sessionId, isNot(equals(session2.sessionId)));
      });

      test('should process interactions within acceptable time limits', () async {
        // Setup
        await orchestrator.initialize(elevenLabsApiKey: 'test-api-key');

        final stopwatch = Stopwatch()..start();
        
        final result = await orchestrator.processVoiceInteraction(
          userInput: 'Maine dal chawal khaya',
          userId: 'test-user-123',
        );

        stopwatch.stop();

        expect(result.systemResponse, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete within 5 seconds
      });
    });
  });
}

/// Helper function to create test meal data
MealData createTestMealData({
  required String userId,
  required MealType mealType,
  List<String> foodNames = const ['dal', 'rice'],
}) {
  final foods = foodNames.map((name) => FoodItem(
    name: name,
    quantity: 150.0,
    unit: 'grams',
    nutrition: NutritionalInfo(
      calories: 150.0,
      protein: 8.0,
      carbs: 25.0,
      fat: 2.0,
      fiber: 4.0,
      vitamins: {'B1': 0.2},
      minerals: {'iron': 2.0},
    ),
    context: CulturalContext(
      region: 'North Indian',
      cookingMethod: 'traditional',
      mealType: 'main',
      commonCombinations: [],
    ),
  )).toList();

  return MealData(
    mealId: 'test-meal-${DateTime.now().millisecondsSinceEpoch}',
    userId: userId,
    timestamp: DateTime.now(),
    mealType: mealType,
    foods: foods,
    nutrition: NutritionalSummary(
      totalCalories: 300.0,
      totalProtein: 16.0,
      totalCarbs: 50.0,
      totalFat: 4.0,
      totalFiber: 8.0,
      vitamins: {'B1': 0.4},
      minerals: {'iron': 4.0},
      macroBreakdown: MacroBreakdown(
        proteinPercentage: 21.3,
        carbsPercentage: 66.7,
        fatPercentage: 12.0,
      ),
    ),
    voiceDescription: 'Test meal description',
    confidenceScore: 0.9,
  );
}