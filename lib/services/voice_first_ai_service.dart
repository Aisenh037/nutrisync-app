import 'dart:typed_data';
import '../voice/voice_interface.dart';
import '../voice/hinglish_processor.dart';
import '../nutrition/nutrition_intelligence_core.dart';
import '../nutrition/meal_logger_service.dart';
import '../nutrition/recommendation_engine.dart';
import '../cultural/cultural_context_engine.dart';
import '../cultural/indian_food_database.dart';
import 'grocery_manager_service.dart';
import 'calendar_integration_service.dart';
import '../api/eleven_labs_agent_service.dart';

/// Main service coordinator for the Voice-First AI Agent
/// Orchestrates all components to provide seamless voice-based nutrition guidance
class VoiceFirstAIService {
  final VoiceInterface _voiceInterface;
  final HinglishProcessor _hinglishProcessor;
  final NutritionIntelligenceCore _nutritionCore;
  final MealLoggerService _mealLogger;
  final RecommendationEngine _recommendationEngine;
  final CulturalContextEngine _culturalEngine;
  final IndianFoodDatabase _foodDatabase;
  final GroceryManagerService _groceryManager;
  final CalendarIntegrationService _calendarService;
  final ElevenLabsAgentService _elevenLabsService;

  VoiceFirstAIService({
    required VoiceInterface voiceInterface,
    required HinglishProcessor hinglishProcessor,
    required NutritionIntelligenceCore nutritionCore,
    required MealLoggerService mealLogger,
    required RecommendationEngine recommendationEngine,
    required CulturalContextEngine culturalEngine,
    required IndianFoodDatabase foodDatabase,
    required GroceryManagerService groceryManager,
    required CalendarIntegrationService calendarService,
    required ElevenLabsAgentService elevenLabsService,
  })  : _voiceInterface = voiceInterface,
        _hinglishProcessor = hinglishProcessor,
        _nutritionCore = nutritionCore,
        _mealLogger = mealLogger,
        _recommendationEngine = recommendationEngine,
        _culturalEngine = culturalEngine,
        _foodDatabase = foodDatabase,
        _groceryManager = groceryManager,
        _calendarService = calendarService,
        _elevenLabsService = elevenLabsService;

  /// Process voice input and provide appropriate response
  Future<VoiceResponse> processVoiceInput(String voiceInput, String userId) async {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Voice input processing not yet implemented');
  }

  /// Start a voice conversation session
  Stream<VoiceInteraction> startVoiceConversation(String userId) {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Voice conversation not yet implemented');
  }

  /// Log meal via voice
  Future<MealLogResult> logMealViaVoice(String voiceDescription, String userId) async {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Voice meal logging not yet implemented');
  }

  /// Get nutrition advice via voice
  Future<VoiceResponse> getNutritionAdvice(String query, String userId) async {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Voice nutrition advice not yet implemented');
  }

  /// Generate meal recommendations via voice
  Future<VoiceResponse> getVoiceMealRecommendations(String userId) async {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Voice meal recommendations not yet implemented');
  }

  /// Initialize all services
  Future<void> initialize() async {
    // Implementation will be added in subsequent tasks
    throw UnimplementedError('Service initialization not yet implemented');
  }

  /// Dispose of all services
  void dispose() {
    _elevenLabsService.dispose();
  }
}

/// Response from voice processing
class VoiceResponse {
  final String textResponse;
  final Uint8List? audioResponse;
  final Map<String, dynamic> data;
  final bool requiresClarification;
  final List<String> clarificationQuestions;

  VoiceResponse({
    required this.textResponse,
    this.audioResponse,
    required this.data,
    this.requiresClarification = false,
    this.clarificationQuestions = const [],
  });
}