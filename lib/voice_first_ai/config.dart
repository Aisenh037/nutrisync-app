/// Configuration constants for Voice-First AI Agent
class VoiceFirstAIConfig {
  // ElevenLabs Configuration
  static const String elevenLabsApiUrl = 'https://api.elevenlabs.io/v1';
  static const String defaultVoiceId = '21m00Tcm4TlvDq8ikWAM'; // Rachel voice
  static const int voiceResponseTimeoutMs = 3000; // 3 seconds as per requirements
  
  // Voice Processing Configuration
  static const int maxRecordingDurationSeconds = 30;
  static const double speechConfidenceThreshold = 0.7;
  static const int maxRetryAttempts = 3;
  
  // Conversation Management Configuration
  static const int sessionTimeoutHours = 2; // Sessions expire after 2 hours of inactivity
  static const int maxConversationTurns = 100; // Maximum turns per session
  static const int contextHistoryLimit = 10; // Number of recent meals to keep in context
  
  // Cultural Context Configuration
  static const List<String> supportedRegions = [
    'North India',
    'South India',
    'West India',
    'East India',
    'Northeast India',
  ];
  
  static const List<String> commonIndianCookingMethods = [
    'tadka',
    'bhuna',
    'dum',
    'tawa',
    'tandoor',
    'steamed',
    'boiled',
    'fried',
  ];
  
  // Subscription Configuration
  static const double premiumPriceMonthly = 199.0; // ₹199/month as per requirements
  static const List<String> premiumFeatures = [
    'automatic_meal_logging',
    'calendar_sync',
    'grocery_list_management',
    'advanced_recommendations',
    'unlimited_queries',
  ];
  
  // Database Configuration
  static const String foodDatabaseCollection = 'indian_foods';
  static const String userProfilesCollection = 'user_profiles';
  static const String mealHistoryCollection = 'meal_history';
  static const String groceryListsCollection = 'grocery_lists';
  
  // Nutrition Configuration
  static const Map<String, double> dailyNutritionTargets = {
    'calories': 2000.0,
    'protein': 50.0,
    'carbs': 250.0,
    'fat': 65.0,
    'fiber': 25.0,
  };
  
  // Indian Measurement Units
  static const Map<String, double> indianMeasurementUnits = {
    'katori': 150.0, // ml
    'glass': 250.0, // ml
    'roti': 30.0, // grams
    'spoon': 15.0, // ml
    'pinch': 1.0, // grams
    'handful': 50.0, // grams
  };
}