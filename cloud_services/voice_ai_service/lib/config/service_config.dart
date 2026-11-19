import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';

/// Configuration for the Voice AI Cloud Run service
class ServiceConfig {
  static ServiceConfig? _instance;
  static ServiceConfig get instance => _instance ??= ServiceConfig._();
  
  ServiceConfig._();
  
  final _logger = Logger('ServiceConfig');
  
  late String projectId;
  late String region;
  late Map<String, dynamic> speechConfig;
  late Map<String, dynamic> ttsConfig;
  late Map<String, dynamic> translationConfig;
  late List<String> supportedLanguages;
  late Map<String, dynamic> nutritionVocabulary;
  
  /// Initialize service configuration from environment variables and files
  static Future<void> initialize() async {
    await instance._loadConfiguration();
  }
  
  Future<void> _loadConfiguration() async {
    try {
      // Load from environment variables
      projectId = Platform.environment['GCP_PROJECT_ID'] ?? 'nutrisync-gcp-dev';
      region = Platform.environment['GCP_REGION'] ?? 'us-central1';
      
      // Load Speech-to-Text configuration
      speechConfig = {
        'languageCode': Platform.environment['STT_LANGUAGE_CODE'] ?? 'en-US',
        'model': Platform.environment['STT_MODEL'] ?? 'latest_long',
        'useEnhanced': Platform.environment['STT_USE_ENHANCED']?.toLowerCase() == 'true',
        'enableAutomaticPunctuation': true,
        'enableWordTimeOffsets': true,
        'enableWordConfidence': true,
        'maxAlternatives': 3,
        'profanityFilter': true,
      };
      
      // Load Text-to-Speech configuration
      ttsConfig = {
        'languageCode': Platform.environment['TTS_LANGUAGE_CODE'] ?? 'en-US',
        'voiceName': Platform.environment['TTS_VOICE_NAME'] ?? 'en-US-Neural2-F',
        'audioEncoding': Platform.environment['TTS_AUDIO_ENCODING'] ?? 'MP3',
        'speakingRate': double.tryParse(Platform.environment['TTS_SPEAKING_RATE'] ?? '1.0') ?? 1.0,
        'pitch': double.tryParse(Platform.environment['TTS_PITCH'] ?? '0.0') ?? 0.0,
        'volumeGainDb': double.tryParse(Platform.environment['TTS_VOLUME_GAIN'] ?? '0.0') ?? 0.0,
      };
      
      // Load Translation configuration
      translationConfig = {
        'defaultTargetLanguage': Platform.environment['TRANSLATION_DEFAULT_TARGET'] ?? 'en',
        'autoDetectLanguage': Platform.environment['TRANSLATION_AUTO_DETECT']?.toLowerCase() != 'false',
      };
      
      // Load supported languages
      final languagesEnv = Platform.environment['SUPPORTED_LANGUAGES'] ?? 'en,hi,es,fr';
      supportedLanguages = languagesEnv.split(',').map((lang) => lang.trim()).toList();
      
      // Load nutrition vocabulary
      await _loadNutritionVocabulary();
      
      _logger.info('Configuration loaded successfully');
      _logger.info('Project ID: $projectId');
      _logger.info('Region: $region');
      _logger.info('Supported languages: ${supportedLanguages.join(', ')}');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to load configuration: $e', e, stackTrace);
      rethrow;
    }
  }
  
  Future<void> _loadNutritionVocabulary() async {
    try {
      // Try to load from file first
      final vocabularyFile = File('config/nutrition_vocabulary.json');
      if (await vocabularyFile.exists()) {
        final content = await vocabularyFile.readAsString();
        nutritionVocabulary = json.decode(content) as Map<String, dynamic>;
        _logger.info('Loaded nutrition vocabulary from file');
        return;
      }
      
      // Fallback to default vocabulary
      nutritionVocabulary = _getDefaultNutritionVocabulary();
      _logger.info('Using default nutrition vocabulary');
      
    } catch (e) {
      _logger.warning('Failed to load nutrition vocabulary file, using defaults: $e');
      nutritionVocabulary = _getDefaultNutritionVocabulary();
    }
  }
  
  Map<String, dynamic> _getDefaultNutritionVocabulary() {
    return {
      'foods': {
        'indian': [
          'dal', 'chawal', 'roti', 'chapati', 'sabzi', 'paneer', 'dahi', 'lassi',
          'biryani', 'pulao', 'samosa', 'dosa', 'idli', 'vada', 'uttapam',
          'rajma', 'chole', 'palak', 'aloo', 'gobi', 'bhindi', 'karela',
          'paratha', 'naan', 'kulcha', 'poori', 'bhatura',
          'raita', 'pickle', 'papad', 'chutney', 'curry'
        ],
        'international': [
          'rice', 'bread', 'pasta', 'pizza', 'burger', 'sandwich', 'salad',
          'soup', 'chicken', 'fish', 'beef', 'pork', 'egg', 'cheese',
          'milk', 'yogurt', 'butter', 'oil', 'sugar', 'salt'
        ],
        'vegetables': [
          'tomato', 'onion', 'potato', 'carrot', 'spinach', 'broccoli',
          'cauliflower', 'cabbage', 'lettuce', 'cucumber', 'bell pepper'
        ],
        'fruits': [
          'apple', 'banana', 'orange', 'mango', 'grapes', 'strawberry',
          'pineapple', 'watermelon', 'papaya', 'guava', 'pomegranate'
        ]
      },
      'measurements': [
        'cup', 'cups', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
        'gram', 'grams', 'kilogram', 'kilograms', 'pound', 'pounds',
        'ounce', 'ounces', 'liter', 'liters', 'milliliter', 'milliliters',
        'piece', 'pieces', 'slice', 'slices', 'bowl', 'bowls', 'plate', 'plates'
      ],
      'cooking_methods': [
        'boiled', 'fried', 'grilled', 'baked', 'steamed', 'roasted',
        'sauteed', 'stir-fried', 'deep-fried', 'pan-fried', 'pressure-cooked'
      ],
      'meal_types': [
        'breakfast', 'lunch', 'dinner', 'snack', 'brunch',
        'nashta', 'khana', 'raat ka khana', 'tiffin'
      ],
      'nutrition_terms': [
        'calories', 'protein', 'carbohydrates', 'fat', 'fiber', 'sugar',
        'sodium', 'cholesterol', 'vitamins', 'minerals', 'antioxidants'
      ],
      'hinglish_phrases': [
        'khaya', 'khana', 'peena', 'piya', 'thoda', 'zyada', 'kam',
        'accha', 'tasty', 'spicy', 'meetha', 'namkeen', 'teekha'
      ]
    };
  }
  
  /// Get service account credentials from environment
  Map<String, dynamic>? get serviceAccountCredentials {
    final credentialsJson = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS_JSON'];
    if (credentialsJson != null) {
      try {
        return json.decode(credentialsJson) as Map<String, dynamic>;
      } catch (e) {
        _logger.warning('Failed to parse service account credentials: $e');
      }
    }
    return null;
  }
  
  /// Check if service is properly configured
  bool get isConfigured {
    return projectId.isNotEmpty && 
           region.isNotEmpty && 
           speechConfig.isNotEmpty && 
           ttsConfig.isNotEmpty;
  }
  
  /// Get API endpoint for a specific service
  String getApiEndpoint(String service) {
    switch (service) {
      case 'speech':
        return 'https://speech.googleapis.com/v1';
      case 'texttospeech':
        return 'https://texttospeech.googleapis.com/v1';
      case 'translate':
        return 'https://translation.googleapis.com/language/translate/v2';
      default:
        throw ArgumentError('Unknown service: $service');
    }
  }
  
  /// Get nutrition vocabulary for a specific category
  List<String> getNutritionVocabulary(String category) {
    final vocab = nutritionVocabulary['foods'] as Map<String, dynamic>? ?? {};
    return (vocab[category] as List<dynamic>?)?.cast<String>() ?? [];
  }
  
  /// Get all nutrition vocabulary as a flat list
  List<String> getAllNutritionVocabulary() {
    final allWords = <String>[];
    
    // Add foods
    final foods = nutritionVocabulary['foods'] as Map<String, dynamic>? ?? {};
    for (final category in foods.values) {
      if (category is List) {
        allWords.addAll(category.cast<String>());
      }
    }
    
    // Add other categories
    for (final key in ['measurements', 'cooking_methods', 'meal_types', 'nutrition_terms', 'hinglish_phrases']) {
      final category = nutritionVocabulary[key] as List<dynamic>? ?? [];
      allWords.addAll(category.cast<String>());
    }
    
    return allWords.toSet().toList(); // Remove duplicates
  }
}