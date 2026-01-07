/// Configuration constants for Voice-First AI Agent
class VoiceFirstAIConfig {
  // ElevenLabs API Configuration
  static const String elevenLabsApiUrl = 'https://api.elevenlabs.io/v1';
  static const String defaultVoiceId = 'pNInz6obpgDQGcFmaJgB'; // Adam voice
  
  // Voice Processing Configuration
  static const int maxRecordingDurationSeconds = 30;
  static const int voiceResponseTimeoutMs = 5000;
  static const double minConfidenceThreshold = 0.6;
  
  // Session Management
  static const int sessionTimeoutHours = 2;
  static const int maxConversationTurns = 50;
  static const int contextHistoryLimit = 10;
  
  // Audio Configuration
  static const int audioSampleRate = 16000;
  static const int audioBitRate = 128000;
  static const String audioFormat = 'wav';
  
  // Response Configuration
  static const int maxResponseLength = 500;
  static const int maxSuggestions = 5;
  static const double defaultVoiceStability = 0.5;
  static const double defaultVoiceSimilarity = 0.75;
  
  // Cultural Context
  static const String defaultRegion = 'North Indian';
  static const String defaultLanguage = 'Hinglish';
  static const List<String> supportedLanguages = ['Hinglish', 'English', 'Hindi'];
  
  // Nutrition Configuration
  static const int maxFoodItemsPerMeal = 10;
  static const double minPortionSize = 0.1;
  static const double maxPortionSize = 10.0;
  
  // Recommendation Configuration
  static const int maxRecommendationsPerRequest = 10;
  static const int mealPlanDays = 7;
  static const int groceryListDays = 7;
  
  // Error Handling
  static const int maxRetryAttempts = 3;
  static const int retryDelayMs = 1000;
  
  // Premium Features
  static const List<String> premiumFeatures = [
    'advanced_meal_logging',
    'calendar_sync',
    'grocery_list_management',
    'detailed_nutrition_analysis',
    'personalized_meal_plans',
  ];
  
  // Free Tier Limits
  static const int freeTierMealsPerDay = 5;
  static const int freeTierQueriesPerDay = 20;
  static const int freeTierRecommendationsPerDay = 3;
}

/// Voice processing quality settings
enum VoiceQuality {
  low,
  medium,
  high,
}

extension VoiceQualityExtension on VoiceQuality {
  int get sampleRate {
    switch (this) {
      case VoiceQuality.low:
        return 8000;
      case VoiceQuality.medium:
        return 16000;
      case VoiceQuality.high:
        return 44100;
    }
  }
  
  int get bitRate {
    switch (this) {
      case VoiceQuality.low:
        return 64000;
      case VoiceQuality.medium:
        return 128000;
      case VoiceQuality.high:
        return 256000;
    }
  }
}

/// Conversation context settings
class ConversationSettings {
  final bool enableContextPreservation;
  final bool enableInterruptionHandling;
  final bool enablePersonalization;
  final int maxContextTurns;
  final Duration sessionTimeout;
  
  const ConversationSettings({
    this.enableContextPreservation = true,
    this.enableInterruptionHandling = true,
    this.enablePersonalization = true,
    this.maxContextTurns = 10,
    this.sessionTimeout = const Duration(hours: 2),
  });
}

/// Default conversation settings
const ConversationSettings defaultConversationSettings = ConversationSettings();