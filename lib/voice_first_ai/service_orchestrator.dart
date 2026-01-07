import 'dart:async';
import '../voice/voice_interface.dart';
import '../voice/hinglish_processor.dart';
import '../voice/conversation_context_manager.dart';
import '../nutrition/nutrition_intelligence_core.dart';
import '../nutrition/meal_logger_service.dart';
import '../services/indian_cooking_education.dart';
import '../services/user_profile_service.dart';
import '../cultural/cultural_context_engine.dart';
import '../cultural/indian_food_database.dart';
import '../models/user_model.dart';
import '../nutrition/meal_data_models.dart';

// Import aliases to resolve conflicts
import '../nutrition/nutrition_intelligence_core.dart' as nutrition_core;

/// Central orchestrator that connects all backend services for the Voice-First AI Agent
/// Handles complete end-to-end workflows from voice input to intelligent responses
class VoiceFirstAIServiceOrchestrator {
  // Core services
  late final VoiceInterface _voiceInterface;
  late final HinglishProcessor _hinglishProcessor;
  late final ConversationContextManager _contextManager;
  late final NutritionIntelligenceCore _nutritionCore;
  late final MealLoggerService _mealLogger;
  late final IndianCookingEducation _cookingEducation;
  late final UserProfileService _userProfileService;
  late final CulturalContextEngine _culturalEngine;
  late final IndianFoodDatabase _foodDatabase;

  // State management
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentSessionId;
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  /// Initialize the service orchestrator with all dependencies
  Future<bool> initialize({
    required String elevenLabsApiKey,
    String? voiceId,
  }) async {
    try {
      // Initialize core services
      _hinglishProcessor = HinglishProcessor();
      _contextManager = ConversationContextManager();
      _culturalEngine = CulturalContextEngine();
      _foodDatabase = IndianFoodDatabase();
      _userProfileService = UserProfileService();
      _cookingEducation = IndianCookingEducation();

      // Initialize voice interface
      _voiceInterface = VoiceInterface(
        elevenLabsApiKey: elevenLabsApiKey,
        voiceId: voiceId,
      );
      
      final voiceInitialized = await _voiceInterface.initialize();
      if (!voiceInitialized) {
        throw Exception('Failed to initialize voice interface');
      }

      // Initialize meal logger with dependencies
      _mealLogger = MealLoggerService();

      // Initialize nutrition intelligence core with all dependencies
      _nutritionCore = NutritionIntelligenceCore(
        hinglishProcessor: _hinglishProcessor,
        contextManager: _contextManager,
        culturalEngine: _culturalEngine,
        foodDatabase: _foodDatabase,
        mealLogger: _mealLogger,
      );

      _isInitialized = true;
      print('Voice-First AI Service Orchestrator initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize service orchestrator: $e');
      return false;
    }
  }

  /// Start a complete voice conversation session
  Future<VoiceConversationSession> startVoiceConversation({
    required String userId,
    Map<String, dynamic>? initialContext,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service orchestrator not initialized');
    }

    try {
      _currentUserId = userId;

      // Get user profile for personalized responses
      final userProfileResult = await _userProfileService.getProfile(userId);
      final userProfile = (userProfileResult.data != null && userProfileResult.error == null) ? userProfileResult.data : null;
      
      // Start conversation session with user context
      final sessionContext = {
        'userPreferences': userProfile?.toMap() ?? {},
        'currentMealContext': null,
        'recentMeals': [],
        'nutritionGoals': userProfile?.healthGoals ?? [],
        ...?initialContext,
      };

      _currentSessionId = _contextManager.startSession(
        userId: userId,
        initialContext: sessionContext,
      );

      // Start voice conversation stream
      final voiceStream = _voiceInterface.startConversation(
        userId: userId,
        initialContext: sessionContext,
      );

      // Create orchestrated conversation session
      final session = VoiceConversationSession(
        sessionId: _currentSessionId!,
        userId: userId,
        userProfile: userProfile,
        voiceStream: voiceStream,
        orchestrator: this,
      );

      // Set up voice interaction processing
      _setupVoiceInteractionProcessing(session);

      return session;
    } catch (e) {
      throw Exception('Failed to start voice conversation: $e');
    }
  }

  /// Process a complete voice interaction workflow
  Future<VoiceInteractionResult> processVoiceInteraction({
    required String userInput,
    required String userId,
    String? sessionId,
  }) async {
    try {
      final effectiveSessionId = sessionId ?? _currentSessionId;
      if (effectiveSessionId == null) {
        throw Exception('No active session');
      }

      // Step 1: Get user profile for personalized processing
      final userProfileResult = await _userProfileService.getProfile(userId);
      final userProfile = (userProfileResult.data != null && userProfileResult.error == null) ? userProfileResult.data : null;
      
      // Step 2: Process input through Hinglish processor
      final hinglishResult = _hinglishProcessor.extractFoodItems(userInput);
      final nutritionQuery = _hinglishProcessor.parseNutritionQuery(userInput);

      // Step 3: Determine interaction type and route to appropriate service
      final interactionType = _determineInteractionType(userInput, hinglishResult, nutritionQuery);
      
      String systemResponse;
      Map<String, dynamic> responseData = {};
      List<String> suggestions = [];

      switch (interactionType) {
        case VoiceInteractionType.mealLogging:
          final result = await _processMealLogging(userInput, userId, effectiveSessionId);
          systemResponse = result.response;
          responseData = result.data;
          suggestions = result.suggestions;
          break;

        case VoiceInteractionType.nutritionQuery:
          final result = await _processNutritionQuery(userInput, userId, effectiveSessionId, userProfile);
          systemResponse = result.response;
          responseData = result.data;
          suggestions = result.suggestions;
          break;

        case VoiceInteractionType.recommendation:
          final result = await _processRecommendationRequest(userInput, userId, userProfile);
          systemResponse = result.response;
          responseData = result.data;
          suggestions = result.suggestions;
          break;

        case VoiceInteractionType.cookingEducation:
          final result = await _processCookingEducationQuery(userInput, userProfile);
          systemResponse = result.response;
          responseData = result.data;
          suggestions = result.suggestions;
          break;

        case VoiceInteractionType.groceryManagement:
          final result = await _processGroceryManagement(userInput, userId, userProfile);
          systemResponse = result.response;
          responseData = result.data;
          suggestions = result.suggestions;
          break;

        case VoiceInteractionType.generalConversation:
        default:
          systemResponse = await _processGeneralConversation(userInput, userId, effectiveSessionId);
          break;
      }

      // Step 4: Enhance response with conversation context
      final contextualResponse = await _voiceInterface.generateContextualResponse(
        userInput,
        systemResponse,
      );

      // Step 5: Update conversation context
      final conversationTurn = ConversationTurn(
        turnId: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        userInput: userInput,
        systemResponse: contextualResponse,
        type: _mapToConversationTurnType(interactionType),
        metadata: {
          'interactionType': interactionType.toString(),
          'confidence': hinglishResult.confidence,
          'hasAmbiguities': hinglishResult.ambiguities.isNotEmpty,
        },
      );

      _contextManager.addConversationTurn(effectiveSessionId, conversationTurn);

      return VoiceInteractionResult(
        userInput: userInput,
        systemResponse: contextualResponse,
        interactionType: interactionType,
        responseData: responseData,
        suggestions: suggestions,
        confidence: hinglishResult.confidence,
        requiresClarification: hinglishResult.ambiguities.isNotEmpty,
        ambiguities: hinglishResult.ambiguities,
      );

    } catch (e) {
      return VoiceInteractionResult(
        userInput: userInput,
        systemResponse: 'Maaf kijiye, kuch technical problem hui hai. Kripaya phir se try kariye.',
        interactionType: VoiceInteractionType.error,
        responseData: {'error': e.toString()},
        suggestions: ['Try speaking more clearly', 'Check your internet connection'],
        confidence: 0.0,
        requiresClarification: false,
        ambiguities: [],
      );
    }
  }

  /// Generate and play voice response
  Future<void> generateAndPlayVoiceResponse(String text) async {
    if (!_isInitialized) return;

    try {
      final audioBytes = await _voiceInterface.generateVoiceResponse(text);
      await _voiceInterface.playAudio(audioBytes);
    } catch (e) {
      print('Error generating voice response: $e');
    }
  }

  /// Listen for voice input and process
  Future<VoiceInteractionResult> listenAndProcess({
    required String userId,
    int timeoutSeconds = 10,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service orchestrator not initialized');
    }

    try {
      // Listen for voice input
      final userInput = await _voiceInterface.listenForVoiceInput(
        timeoutSeconds: timeoutSeconds,
      );

      // Process the voice input
      return await processVoiceInteraction(
        userInput: userInput,
        userId: userId,
      );
    } catch (e) {
      throw Exception('Failed to listen and process: $e');
    }
  }

  /// Get user's meal history with recommendations
  Future<MealHistoryWithRecommendations> getMealHistoryWithRecommendations(String userId) async {
    try {
      // Get meal history
      final mealHistory = await _mealLogger.getMealHistory(userId);
      
      // Get user profile
      final userProfileResult = await _userProfileService.getProfile(userId);
      final userProfile = (userProfileResult.data != null && userProfileResult.error == null) ? userProfileResult.data : null;
      
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      // Generate simple recommendations based on history
      final recommendations = await _generateSimpleRecommendations(userProfile);

      // Get nutritional analysis (simplified)
      final nutritionalAnalysis = _generateSimpleNutritionalAnalysis(mealHistory);

      return MealHistoryWithRecommendations(
        mealHistory: mealHistory,
        recommendations: recommendations,
        nutritionalAnalysis: nutritionalAnalysis,
        insights: _generateMealInsights(mealHistory, userProfile),
      );
    } catch (e) {
      throw Exception('Failed to get meal history with recommendations: $e');
    }
  }

  /// Generate grocery list from recent meals
  Future<GroceryList> generateGroceryListFromMeals(String userId, {int days = 7}) async {
    try {
      // Get recent meals
      final recentMeals = await _mealLogger.getMealHistory(userId, days: days);
      
      if (recentMeals.isEmpty) {
        throw Exception('No recent meals found');
      }

      // Create a simple grocery list from meal ingredients
      final groceryItems = <String, int>{};
      
      for (final meal in recentMeals) {
        for (final food in meal.foods) {
          // Extract basic ingredients from food names
          final ingredients = _extractBasicIngredients(food.name);
          for (final ingredient in ingredients) {
            groceryItems[ingredient] = (groceryItems[ingredient] ?? 0) + 1;
          }
        }
      }

      // Create a simple grocery list response
      return GroceryList(
        id: 'generated-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        items: groceryItems.entries.map((e) => '${e.key} (${e.value}x)').toList(),
        createdAt: DateTime.now(),
        estimatedCost: groceryItems.length * 50.0, // Simple estimation
      );
    } catch (e) {
      throw Exception('Failed to generate grocery list: $e');
    }
  }

  List<String> _extractBasicIngredients(String foodName) {
    // Simple ingredient extraction based on common Indian foods
    final ingredients = <String>[];
    final lowerName = foodName.toLowerCase();
    
    if (lowerName.contains('dal')) ingredients.addAll(['dal', 'onion', 'tomato', 'spices']);
    if (lowerName.contains('rice')) ingredients.add('rice');
    if (lowerName.contains('roti') || lowerName.contains('chapati')) ingredients.addAll(['wheat flour', 'oil']);
    if (lowerName.contains('sabzi') || lowerName.contains('vegetable')) ingredients.addAll(['vegetables', 'onion', 'spices']);
    if (lowerName.contains('paneer')) ingredients.add('paneer');
    if (lowerName.contains('chicken')) ingredients.add('chicken');
    if (lowerName.contains('milk')) ingredients.add('milk');
    
    // Default ingredients for any meal
    if (ingredients.isEmpty) {
      ingredients.addAll(['basic groceries']);
    }
    
    return ingredients;
  }

  /// Handle conversation interruption
  void handleInterruption({String? reason}) {
    if (_currentSessionId != null) {
      _voiceInterface.handleInterruption(reason: reason);
      _contextManager.handleInterruption(_currentSessionId!, reason: reason);
    }
  }

  /// Resume interrupted conversation
  Future<String> resumeConversation() async {
    if (_currentSessionId == null) {
      throw Exception('No active session to resume');
    }

    try {
      final resumptionMessage = _contextManager.resumeConversation(_currentSessionId!);
      await generateAndPlayVoiceResponse(resumptionMessage);
      return resumptionMessage;
    } catch (e) {
      throw Exception('Failed to resume conversation: $e');
    }
  }

  /// End current conversation session
  void endConversation() {
    if (_currentSessionId != null) {
      _contextManager.endSession(_currentSessionId!);
      _voiceInterface.endConversation();
      
      // Clean up subscriptions
      for (final subscription in _activeSubscriptions.values) {
        subscription.cancel();
      }
      _activeSubscriptions.clear();
      
      _currentSessionId = null;
      _currentUserId = null;
    }
  }

  /// Check if orchestrator is initialized
  bool get isInitialized => _isInitialized;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Dispose of all resources
  void dispose() {
    endConversation();
    if (_isInitialized) {
      _voiceInterface.dispose();
      _contextManager.dispose();
    }
    _isInitialized = false;
  }

  // Private helper methods

  void _setupVoiceInteractionProcessing(VoiceConversationSession session) {
    // Listen to voice interactions and process them
    final subscription = session.voiceStream.listen(
      (voiceInteraction) async {
        try {
          final result = await processVoiceInteraction(
            userInput: voiceInteraction.userInput,
            userId: session.userId,
            sessionId: session.sessionId,
          );

          // Generate and play voice response
          await generateAndPlayVoiceResponse(result.systemResponse);
        } catch (e) {
          print('Error processing voice interaction: $e');
        }
      },
      onError: (error) {
        print('Voice stream error: $error');
      },
    );

    _activeSubscriptions[session.sessionId] = subscription;
  }

  VoiceInteractionType _determineInteractionType(
    String userInput,
    FoodExtractionResult hinglishResult,
    NutritionQueryResult nutritionQuery,
  ) {
    final lowerInput = userInput.toLowerCase();

    // Check for meal logging indicators
    if (hinglishResult.foodItems.isNotEmpty && 
        (lowerInput.contains('khaya') || lowerInput.contains('eaten') || 
         lowerInput.contains('had') || lowerInput.contains('meal'))) {
      return VoiceInteractionType.mealLogging;
    }

    // Check for recommendation requests
    if (lowerInput.contains('suggest') || lowerInput.contains('recommend') || 
        lowerInput.contains('batao') || lowerInput.contains('what should')) {
      return VoiceInteractionType.recommendation;
    }

    // Check for cooking education queries
    if (lowerInput.contains('how to cook') || lowerInput.contains('recipe') || 
        lowerInput.contains('kaise banau') || lowerInput.contains('cooking tip')) {
      return VoiceInteractionType.cookingEducation;
    }

    // Check for grocery management
    if (lowerInput.contains('grocery') || lowerInput.contains('shopping') || 
        lowerInput.contains('buy') || lowerInput.contains('kharidna')) {
      return VoiceInteractionType.groceryManagement;
    }

    // Check for nutrition queries
    if (nutritionQuery.queryType != NutritionQueryType.generalNutrition) {
      return VoiceInteractionType.nutritionQuery;
    }

    return VoiceInteractionType.generalConversation;
  }

  Future<ProcessingResult> _processMealLogging(String userInput, String userId, String sessionId) async {
    try {
      final voiceInput = VoiceInput(
        transcription: userInput,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        metadata: {'userId': userId},
      );

      final result = await _nutritionCore.processMealLogging(voiceInput);
      
      if (result.success && result.mealData != null) {
        // Update conversation context with meal data
        _voiceInterface.addMealContext(result.mealData!.toMap());
        
        return ProcessingResult(
          response: result.message,
          data: {
            'mealData': result.mealData!.toMap(),
            'nutrition': result.mealData!.nutrition.toMap(),
          },
          suggestions: [
            'Log another meal',
            'Get nutrition recommendations',
            'View meal history',
          ],
        );
      } else {
        return ProcessingResult(
          response: result.message,
          data: {'ambiguities': result.ambiguities.map((a) => a.term).toList()},
          suggestions: result.ambiguities.isNotEmpty 
              ? _hinglishProcessor.generateClarificationQuestions(result.ambiguities)
              : ['Try describing your meal differently'],
        );
      }
    } catch (e) {
      return ProcessingResult(
        response: 'Meal log karne mein problem hui. Kripaya phir se try kariye.',
        data: {'error': e.toString()},
        suggestions: ['Try again', 'Speak more clearly'],
      );
    }
  }

  Future<ProcessingResult> _processNutritionQuery(
    String userInput, 
    String userId, 
    String sessionId, 
    UserModel? userModel,
  ) async {
    try {
      final userProfile = userModel != null ? _convertUserModelToUserProfile(userModel) : _createDefaultUserProfile(userId);
      
      final userContext = nutrition_core.UserContext(
        profile: userProfile,
        recentMeals: await _mealLogger.getMealHistory(userId, days: 3),
        preferences: _contextManager.getContext(sessionId)?.userPreferences ?? {},
      );

      final response = await _nutritionCore.answerNutritionQuery(userInput, userContext);
      
      return ProcessingResult(
        response: response,
        data: {'queryType': 'nutrition', 'userContext': userProfile.userId},
        suggestions: [
          'Ask about specific foods',
          'Get meal recommendations',
          'Learn about cooking tips',
        ],
      );
    } catch (e) {
      return ProcessingResult(
        response: 'Nutrition question ka answer dene mein problem hui. Kripaya phir se puchiye.',
        data: {'error': e.toString()},
        suggestions: ['Ask a different question', 'Be more specific'],
      );
    }
  }

  Future<ProcessingResult> _processRecommendationRequest(
    String userInput, 
    String userId, 
    UserModel? userModel,
  ) async {
    try {
      if (userModel == null) {
        return ProcessingResult(
          response: 'Recommendations ke liye pehle aapka profile complete kariye.',
          data: {},
          suggestions: ['Complete your profile', 'Set health goals'],
        );
      }

      final recommendations = await _generateSimpleRecommendations(userModel);

      if (recommendations.isNotEmpty) {
        final responseText = _formatSimpleRecommendationsResponse(recommendations);
        
        return ProcessingResult(
          response: responseText,
          data: {
            'recommendations': recommendations.map((r) => {
              'food': r,
              'reason': 'Good for your health goals',
            }).toList(),
          },
          suggestions: [
            'Get cooking tips',
            'Ask about nutrition',
          ],
        );
      } else {
        return ProcessingResult(
          response: 'Recommendations generate karne mein problem hui. Kripaya phir se try kariye.',
          data: {'error': 'No recommendations available'},
          suggestions: ['Update your profile', 'Try again later'],
        );
      }
    } catch (e) {
      return ProcessingResult(
        response: 'Recommendations dene mein problem hui. Kripaya phir se try kariye.',
        data: {'error': e.toString()},
        suggestions: ['Check your profile', 'Try again'],
      );
    }
  }

  Future<ProcessingResult> _processCookingEducationQuery(String userInput, UserModel? userModel) async {
    try {
      // Extract food items from the query
      final extractionResult = _hinglishProcessor.extractFoodItems(userInput);
      
      if (extractionResult.foodItems.isEmpty) {
        return ProcessingResult(
          response: 'Kya aap kisi specific food ke baare mein cooking tips jaanna chahte hain?',
          data: {},
          suggestions: ['Ask about dal cooking', 'Ask about sabzi tips', 'Ask about roti making'],
        );
      }

      final foodName = extractionResult.foodItems.first.name;
      final searchResults = await _foodDatabase.searchFood(foodName);
      
      if (searchResults.isEmpty) {
        return ProcessingResult(
          response: 'Is food ke baare mein cooking tips nahi mil paye. Koi aur food try kariye.',
          data: {},
          suggestions: ['Try common Indian foods', 'Ask about general cooking tips'],
        );
      }

      final food = searchResults.first;
      final cookingTips = _cookingEducation.getCookingTips(food: food, user: userModel);
      final nutritionExplanation = _cookingEducation.explainNutrition(food: food, user: userModel);
      
      final responseText = _formatCookingEducationResponse(cookingTips, nutritionExplanation);
      
      return ProcessingResult(
        response: responseText,
        data: {
          'food': food.name,
          'tips': cookingTips.map((tip) => tip.hinglishTip).toList(),
          'benefits': nutritionExplanation.benefits,
        },
        suggestions: [
          'Get more cooking tips',
          'Ask about nutrition',
          'Get healthy alternatives',
        ],
      );
    } catch (e) {
      return ProcessingResult(
        response: 'Cooking tips dene mein problem hui. Kripaya phir se try kariye.',
        data: {'error': e.toString()},
        suggestions: ['Try a different food', 'Ask general cooking questions'],
      );
    }
  }

  Future<ProcessingResult> _processGroceryManagement(
    String userInput, 
    String userId, 
    UserModel? userModel,
  ) async {
    try {
      final groceryList = await generateGroceryListFromMeals(userId);
      
      final responseText = _formatGroceryListResponse(groceryList);
      
      return ProcessingResult(
        response: responseText,
        data: {
          'groceryList': groceryList.toMap(),
          'totalCost': groceryList.estimatedCost,
          'itemCount': groceryList.items.length,
        },
        suggestions: [
          'Get healthy alternatives',
          'Update quantities',
          'View shopping history',
        ],
      );
    } catch (e) {
      return ProcessingResult(
        response: 'Grocery list banane mein problem hui. Pehle kuch meals log kariye.',
        data: {'error': e.toString()},
        suggestions: ['Log some meals first', 'Try again later'],
      );
    }
  }

  Future<String> _processGeneralConversation(String userInput, String userId, String sessionId) async {
    // Handle general conversation with context
    final context = _contextManager.getContext(sessionId);
    
    if (userInput.toLowerCase().contains('hello') || userInput.toLowerCase().contains('namaste')) {
      return 'Namaste! Main aapka nutrition assistant hun. Aaj kya khaya aapne?';
    }
    
    if (userInput.toLowerCase().contains('help') || userInput.toLowerCase().contains('madad')) {
      return 'Main aapki nutrition aur meal planning mein help kar sakta hun. '
             'Aap meal log kar sakte hain, nutrition questions puch sakte hain, '
             'ya cooking tips le sakte hain. Kya chahiye?';
    }
    
    return 'Main samajh nahi paya. Kya aap meal log karna chahte hain, '
           'nutrition ke baare mein puchna chahte hain, ya cooking tips chahiye?';
  }

  ConversationTurnType _mapToConversationTurnType(VoiceInteractionType interactionType) {
    switch (interactionType) {
      case VoiceInteractionType.mealLogging:
        return ConversationTurnType.mealLogging;
      case VoiceInteractionType.recommendation:
        return ConversationTurnType.recommendation;
      case VoiceInteractionType.nutritionQuery:
        return ConversationTurnType.nutritionQuery;
      default:
        return ConversationTurnType.nutritionQuery;
    }
  }

  UserProfile _createDefaultUserProfile(String userId) {
    return UserProfile(
      userId: userId,
      personalInfo: PersonalInfo(
        name: 'User',
        age: 25,
        gender: 'Unknown',
        height: 165.0,
        weight: 65.0,
        location: 'India',
      ),
      goals: DietaryGoals(
        type: GoalType.maintenance,
        targetWeight: 65.0,
        timeframe: 90,
        activityLevel: ActivityLevel.moderatelyActive,
      ),
      conditions: HealthConditions(
        allergies: [],
        medicalConditions: [],
        medications: [],
      ),
      preferences: FoodPreferences(
        liked: [],
        disliked: [],
        dietary: ['vegetarian'],
        spiceLevel: 'medium',
      ),
      patterns: EatingPatterns(
        mealTimes: {
          'breakfast': '8:00',
          'lunch': '13:00',
          'dinner': '20:00',
        },
        mealsPerDay: 3,
        snackPreferences: [],
      ),
      tier: SubscriptionTier.free,
    );
  }

  UserProfile _convertUserModelToUserProfile(UserModel userModel) {
    return UserProfile(
      userId: userModel.uid,
      personalInfo: PersonalInfo(
        name: userModel.name,
        age: userModel.age ?? 25,
        gender: userModel.gender ?? 'Unknown',
        height: userModel.height ?? 165.0,
        weight: userModel.weight ?? 65.0,
        location: userModel.culturalPreferences['region'] ?? 'India',
      ),
      goals: DietaryGoals(
        type: _mapHealthGoalToGoalType(userModel.healthGoals.isNotEmpty ? userModel.healthGoals.first : 'maintenance'),
        targetWeight: userModel.weight ?? 65.0, // Default to current weight
        timeframe: 90,
        activityLevel: _mapActivityLevel(userModel.activityLevel ?? 'moderate'),
      ),
      conditions: HealthConditions(
        allergies: [],
        medicalConditions: userModel.medicalConditions,
        medications: [],
      ),
      preferences: FoodPreferences(
        liked: [],
        disliked: [],
        dietary: userModel.dietaryNeeds,
        spiceLevel: 'medium',
      ),
      patterns: EatingPatterns(
        mealTimes: {
          'breakfast': '8:00',
          'lunch': '13:00',
          'dinner': '20:00',
        },
        mealsPerDay: 3,
        snackPreferences: [],
      ),
      tier: SubscriptionTier.free,
    );
  }

  GoalType _mapHealthGoalToGoalType(String healthGoal) {
    switch (healthGoal.toLowerCase()) {
      case 'weight_loss':
      case 'weight loss':
        return GoalType.weightLoss;
      case 'muscle_gain':
      case 'muscle gain':
        return GoalType.muscleGain;
      default:
        return GoalType.maintenance;
    }
  }

  ActivityLevel _mapActivityLevel(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        return ActivityLevel.sedentary;
      case 'light':
      case 'lightly_active':
        return ActivityLevel.lightlyActive;
      case 'moderate':
      case 'moderately_active':
        return ActivityLevel.moderatelyActive;
      case 'very_active':
        return ActivityLevel.veryActive;
      default:
        return ActivityLevel.moderatelyActive;
    }
  }

  String _formatRecommendationsResponse(List<String> recommendations) {
    if (recommendations.isEmpty) {
      return 'Koi recommendations nahi mil paye. Profile update kariye.';
    }

    final buffer = StringBuffer('Aapke liye yeh recommendations hain:\n');
    
    for (int i = 0; i < recommendations.length && i < 3; i++) {
      buffer.write('${i + 1}. ${recommendations[i]}\n');
    }
    
    return buffer.toString();
  }

  Future<List<String>> _generateSimpleRecommendations(UserModel? userModel) async {
    // Simple recommendation logic based on user profile
    final recommendations = <String>[];
    
    if (userModel?.healthGoals.contains('weight_loss') == true) {
      recommendations.addAll([
        'Dal with less oil - high protein, low calories',
        'Vegetable salad - fiber rich, filling',
        'Green tea - metabolism booster',
      ]);
    } else if (userModel?.healthGoals.contains('muscle_gain') == true) {
      recommendations.addAll([
        'Paneer curry - high protein',
        'Sprouts salad - complete protein',
        'Almonds and nuts - healthy fats',
      ]);
    } else {
      recommendations.addAll([
        'Dal chawal - balanced nutrition',
        'Mixed vegetable sabzi - vitamins and minerals',
        'Roti with ghee - energy and taste',
      ]);
    }
    
    return recommendations;
  }

  String _formatSimpleRecommendationsResponse(List<String> recommendations) {
    if (recommendations.isEmpty) {
      return 'Koi recommendations nahi mil paye. Profile update kariye.';
    }

    final buffer = StringBuffer('Aapke liye yeh recommendations hain:\n');
    
    for (int i = 0; i < recommendations.length && i < 3; i++) {
      buffer.write('${i + 1}. ${recommendations[i]}\n');
    }
    
    return buffer.toString();
  }

  SimpleNutritionalAnalysis _generateSimpleNutritionalAnalysis(List<MealData> mealHistory) {
    if (mealHistory.isEmpty) {
      return SimpleNutritionalAnalysis(
        averageCalories: 0,
        proteinAdequate: false,
        balanceScore: 0,
        suggestions: ['Start logging meals to get analysis'],
      );
    }

    final avgCalories = mealHistory
        .map((meal) => meal.nutrition.totalCalories)
        .reduce((a, b) => a + b) / mealHistory.length;
    
    final avgProtein = mealHistory
        .map((meal) => meal.nutrition.totalCalories) // Using calories as proxy since protein might not be available
        .reduce((a, b) => a + b) / mealHistory.length;

    return SimpleNutritionalAnalysis(
      averageCalories: avgCalories,
      proteinAdequate: avgProtein > 1500, // Simple threshold based on calories
      balanceScore: avgCalories > 1500 && avgCalories < 2500 ? 8 : 6,
      suggestions: [
        if (avgCalories < 1500) 'Increase your calorie intake',
        if (avgCalories > 2500) 'Consider portion control',
        if (avgProtein < 1500) 'Add more protein sources like dal, paneer',
      ],
    );
  }

  String _formatCookingEducationResponse(
    List<CookingTip> tips, 
    NutritionExplanation explanation,
  ) {
    final buffer = StringBuffer();
    
    if (tips.isNotEmpty) {
      buffer.write('Cooking tips: ');
      buffer.write(tips.first.hinglishTip);
      buffer.write('\n');
    }
    
    if (explanation.benefits.isNotEmpty) {
      buffer.write('Health benefits: ');
      buffer.write(explanation.benefits.first);
      buffer.write('\n');
    }
    
    if (explanation.culturalContext.isNotEmpty) {
      buffer.write(explanation.culturalContext);
    }
    
    return buffer.toString();
  }

  String _formatGroceryListResponse(GroceryList groceryList) {
    final totalItems = groceryList.items.length;
    
    return 'Aapki grocery list ready hai! '
           'Total $totalItems items hain, '
           'estimated cost ₹${groceryList.estimatedCost.toStringAsFixed(0)} hai. '
           'App mein dekh sakte hain detailed list.';
  }

  List<String> _generateMealInsights(List<MealData> mealHistory, UserModel? userProfile) {
    final insights = <String>[];
    
    if (mealHistory.isEmpty) {
      insights.add('Start logging meals to get personalized insights');
      return insights;
    }

    // Analyze meal frequency
    final avgMealsPerDay = mealHistory.length / 7.0;
    if (avgMealsPerDay < 3) {
      insights.add('Aap kam meals log kar rahe hain. Regular meals important hain health ke liye.');
    }

    // Analyze nutrition patterns
    final avgCalories = mealHistory
        .map((meal) => meal.nutrition.totalCalories)
        .reduce((a, b) => a + b) / mealHistory.length;
    
    if (avgCalories < 1500) {
      insights.add('Aapke calories kam lag rahe hain. Balanced diet lena important hai.');
    } else if (avgCalories > 2500) {
      insights.add('Calories thode zyada hain. Portion control try kariye.');
    }

    return insights;
  }
}

// Data classes for orchestrator

class VoiceConversationSession {
  final String sessionId;
  final String userId;
  final UserModel? userProfile;
  final Stream<VoiceInteraction> voiceStream;
  final VoiceFirstAIServiceOrchestrator orchestrator;

  VoiceConversationSession({
    required this.sessionId,
    required this.userId,
    this.userProfile,
    required this.voiceStream,
    required this.orchestrator,
  });
}

class VoiceInteractionResult {
  final String userInput;
  final String systemResponse;
  final VoiceInteractionType interactionType;
  final Map<String, dynamic> responseData;
  final List<String> suggestions;
  final double confidence;
  final bool requiresClarification;
  final List<FoodAmbiguity> ambiguities;

  VoiceInteractionResult({
    required this.userInput,
    required this.systemResponse,
    required this.interactionType,
    required this.responseData,
    required this.suggestions,
    required this.confidence,
    required this.requiresClarification,
    required this.ambiguities,
  });
}

class ProcessingResult {
  final String response;
  final Map<String, dynamic> data;
  final List<String> suggestions;

  ProcessingResult({
    required this.response,
    required this.data,
    required this.suggestions,
  });
}

class MealHistoryWithRecommendations {
  final List<MealData> mealHistory;
  final List<String> recommendations;
  final SimpleNutritionalAnalysis nutritionalAnalysis;
  final List<String> insights;

  MealHistoryWithRecommendations({
    required this.mealHistory,
    required this.recommendations,
    required this.nutritionalAnalysis,
    required this.insights,
  });
}

class SimpleNutritionalAnalysis {
  final double averageCalories;
  final bool proteinAdequate;
  final int balanceScore;
  final List<String> suggestions;

  SimpleNutritionalAnalysis({
    required this.averageCalories,
    required this.proteinAdequate,
    required this.balanceScore,
    required this.suggestions,
  });
}

enum VoiceInteractionType {
  mealLogging,
  nutritionQuery,
  recommendation,
  cookingEducation,
  groceryManagement,
  generalConversation,
  error,
}

// Simple GroceryList class for the orchestrator
class GroceryList {
  final String id;
  final String userId;
  final List<String> items;
  final DateTime createdAt;
  final double estimatedCost;

  GroceryList({
    required this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    required this.estimatedCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items,
      'createdAt': createdAt.toIso8601String(),
      'estimatedCost': estimatedCost,
    };
  }
}