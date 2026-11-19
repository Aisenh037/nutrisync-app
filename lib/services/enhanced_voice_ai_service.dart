import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../config/gcp_config.dart';
import '../services/gcp_auth_service.dart';

/// Enhanced Voice AI Service that integrates with the Cloud Run voice processing service
class EnhancedVoiceAIService {
  static EnhancedVoiceAIService? _instance;
  static EnhancedVoiceAIService get instance => _instance ??= EnhancedVoiceAIService._();
  
  EnhancedVoiceAIService._();
  
  final _logger = Logger('EnhancedVoiceAIService');
  String? _serviceUrl;
  
  /// Initialize the enhanced voice AI service
  Future<void> initialize() async {
    try {
      await GCPConfig.instance.initialize();
      await GCPAuthService.instance.initialize();
      
      // Get the Cloud Run service URL from environment or config
      _serviceUrl = _getServiceUrl();
      
      _logger.info('Enhanced Voice AI Service initialized');
      _logger.info('Service URL: $_serviceUrl');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Enhanced Voice AI Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Process voice input with enhanced GCP Speech-to-Text
  Future<SpeechToTextResult> processVoiceInput(
    Uint8List audioData, {
    String? languageCode,
    String? userId,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final audioContent = base64Encode(audioData);
      
      final requestBody = {
        'audioContent': audioContent,
        'languageCode': languageCode,
        'userId': userId,
        'speechContexts': _getNutritionVocabulary(),
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/speech-to-text',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return SpeechToTextResult.fromJson(responseData);
      } else {
        throw Exception('Speech-to-Text failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Voice input processing failed: $e', e, stackTrace);
      return SpeechToTextResult(
        transcription: '',
        confidence: 0.0,
        error: 'Voice processing failed: $e',
      );
    }
  }
  
  /// Generate voice response with enhanced GCP Text-to-Speech
  Future<TextToSpeechResult> generateVoiceResponse(
    String text, {
    String? languageCode,
    String? voiceName,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'text': text,
        'languageCode': languageCode ?? 'en-US',
        'voiceName': voiceName,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/text-to-speech',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return TextToSpeechResult.fromJson(responseData);
      } else {
        throw Exception('Text-to-Speech failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Voice response generation failed: $e', e, stackTrace);
      return TextToSpeechResult(
        audioContent: null,
        error: 'Voice generation failed: $e',
      );
    }
  }
  
  /// Process complete voice interaction (STT + processing + TTS)
  Future<VoiceInteractionResult> processVoiceInteraction(
    Uint8List audioData, {
    String? userId,
    String? sessionId,
    String? languageCode,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final audioContent = base64Encode(audioData);
      
      final requestBody = {
        'audioContent': audioContent,
        'userId': userId,
        'sessionId': sessionId,
        'languageCode': languageCode,
        'context': context,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/process-voice',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return VoiceInteractionResult.fromJson(responseData);
      } else {
        throw Exception('Voice interaction failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Voice interaction processing failed: $e', e, stackTrace);
      return VoiceInteractionResult(
        transcription: '',
        response: 'Maaf kijiye, kuch technical problem hui hai. Kripaya phir se try kariye.',
        audioResponse: null,
        confidence: 0.0,
        error: 'Voice interaction failed: $e',
      );
    }
  }
  
  /// Detect language from audio
  Future<LanguageDetectionResult> detectLanguage(String text) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'text': text,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/detect-language',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return LanguageDetectionResult.fromJson(responseData);
      } else {
        throw Exception('Language detection failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Language detection failed: $e', e, stackTrace);
      return LanguageDetectionResult(
        detectedLanguage: 'en-US',
        confidence: 0.0,
        error: 'Language detection failed: $e',
      );
    }
  }
  
  /// Get nutrition vocabulary from the service
  Future<NutritionVocabularyResult> getNutritionVocabulary() async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/nutrition-vocabulary',
        null,
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return NutritionVocabularyResult.fromJson(responseData);
      } else {
        throw Exception('Failed to get nutrition vocabulary: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to get nutrition vocabulary: $e', e, stackTrace);
      return NutritionVocabularyResult(
        vocabulary: {},
        totalWords: 0,
        categories: [],
        error: 'Failed to get vocabulary: $e',
      );
    }
  }
  
  /// Process enhanced voice interaction with Dialogflow integration
  Future<EnhancedVoiceInteractionResult> processEnhancedVoiceInteraction(
    Uint8List audioData, {
    String? userId,
    String? sessionId,
    String? languageCode,
    Map<String, dynamic>? context,
    bool useDialogflow = true,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final audioContent = base64Encode(audioData);
      
      final requestBody = {
        'audioContent': audioContent,
        'userId': userId,
        'sessionId': sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
        'languageCode': languageCode,
        'context': context,
        'useDialogflow': useDialogflow,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/process-voice-enhanced',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return EnhancedVoiceInteractionResult.fromJson(responseData);
      } else {
        throw Exception('Enhanced voice interaction failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Enhanced voice interaction processing failed: $e', e, stackTrace);
      return EnhancedVoiceInteractionResult(
        transcription: '',
        response: 'Maaf kijiye, kuch technical problem hui hai. Kripaya phir se try kariye.',
        audioResponse: null,
        confidence: 0.0,
        intentName: 'fallback.intent',
        error: 'Enhanced voice interaction failed: $e',
      );
    }
  }
  
  /// Detect intent from text using Dialogflow
  Future<IntentDetectionResult> detectIntent(
    String text, {
    String? sessionId,
    String? languageCode,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'text': text,
        'sessionId': sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
        'languageCode': languageCode ?? 'en-US',
        'context': context,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/detect-intent',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return IntentDetectionResult.fromJson(responseData);
      } else {
        throw Exception('Intent detection failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Intent detection failed: $e', e, stackTrace);
      return IntentDetectionResult(
        sessionId: sessionId ?? 'default-session',
        intentName: 'fallback.intent',
        responseText: 'Main aapka sawal samajh nahi paya. Kripaya phir se try kariye.',
        parameters: {},
        confidence: 0.0,
        error: 'Intent detection failed: $e',
      );
    }
  }
  
  /// Manage conversation context
  Future<ConversationContextResult> manageContext(
    String sessionId, {
    String? contextName,
    Map<String, dynamic>? parameters,
    String action = 'update',
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'sessionId': sessionId,
        'contextName': contextName ?? 'nutrition-context',
        'parameters': parameters ?? {},
        'action': action,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/manage-context',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return ConversationContextResult.fromJson(responseData);
      } else {
        throw Exception('Context management failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Context management failed: $e', e, stackTrace);
      return ConversationContextResult(
        name: contextName ?? 'nutrition-context',
        lifespanCount: 5,
        parameters: parameters ?? {},
        error: 'Context management failed: $e',
      );
    }
  }
  /// Translate text using GCP Translation API
  Future<TranslationResult> translateText(
    String text, {
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'text': text,
        'targetLanguage': targetLanguage,
        'sourceLanguage': sourceLanguage,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/translate-text',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return TranslationResult.fromJson(responseData);
      } else {
        throw Exception('Text translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Text translation failed: $e', e, stackTrace);
      return TranslationResult(
        translatedText: text, // Return original text as fallback
        sourceLanguage: sourceLanguage ?? 'auto',
        targetLanguage: targetLanguage,
        confidence: 0.0,
        error: 'Text translation failed: $e',
      );
    }
  }
  
  /// Translate nutrition data while preserving accuracy
  Future<NutritionTranslationResult> translateNutritionData(
    Map<String, dynamic> nutritionData, {
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'nutritionData': nutritionData,
        'targetLanguage': targetLanguage,
        'sourceLanguage': sourceLanguage,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/translate-nutrition',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return NutritionTranslationResult.fromJson(responseData);
      } else {
        throw Exception('Nutrition translation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Nutrition translation failed: $e', e, stackTrace);
      return NutritionTranslationResult(
        translatedData: nutritionData, // Return original data as fallback
        sourceLanguage: sourceLanguage ?? 'auto',
        targetLanguage: targetLanguage,
        error: 'Nutrition translation failed: $e',
      );
    }
  }
  
  /// Get list of supported languages
  Future<SupportedLanguagesResult> getSupportedLanguages() async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/supported-languages',
        null,
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return SupportedLanguagesResult.fromJson(responseData);
      } else {
        throw Exception('Get supported languages failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Get supported languages failed: $e', e, stackTrace);
      return SupportedLanguagesResult(
        languages: [
          SupportedLanguageInfo(languageCode: 'en', displayName: 'English'),
          SupportedLanguageInfo(languageCode: 'hi', displayName: 'Hindi'),
          SupportedLanguageInfo(languageCode: 'es', displayName: 'Spanish'),
        ],
        error: 'Get supported languages failed: $e',
      );
    }
  }
  
  /// Test connection to the Cloud Run service
  Future<bool> testConnection() async {
    try {
      if (_serviceUrl == null) {
        return false;
      }
      
      final response = await http.get(Uri.parse('$_serviceUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      _logger.warning('Connection test failed: $e');
      return false;
    }
  }
  
  /// Get the Cloud Run service URL
  String _getServiceUrl() {
    // In production, this would come from environment variables or service discovery
    final gcpConfig = GCPConfig.instance;
    final projectId = gcpConfig.projectId;
    final region = gcpConfig.region;
    
    // Cloud Run service URL format
    return 'https://voice-ai-service-${projectId.hashCode.abs()}-${region}.a.run.app';
  }
  
  /// Get nutrition vocabulary for speech context
  List<String> _getNutritionVocabulary() {
    // Return a subset of nutrition vocabulary for speech context
    return [
      // Common Indian foods
      'dal', 'chawal', 'roti', 'sabzi', 'paneer', 'dahi',
      'biryani', 'pulao', 'samosa', 'dosa', 'idli',
      
      // Common international foods
      'rice', 'bread', 'chicken', 'fish', 'egg', 'milk',
      'salad', 'soup', 'pasta', 'pizza',
      
      // Measurements
      'cup', 'tablespoon', 'teaspoon', 'gram', 'piece', 'bowl',
      
      // Hinglish phrases
      'khaya', 'khana', 'thoda', 'zyada', 'accha', 'tasty',
    ];
  }
  
  /// Make authenticated HTTP request to the Cloud Run service
  Future<http.Response> _makeAuthenticatedRequest(
    String url,
    Map<String, dynamic>? body, {
    String method = 'POST',
  }) async {
    try {
      final headers = await GCPAuthService.instance.getAuthHeaders();
      
      if (method == 'GET') {
        return await http.get(Uri.parse(url), headers: headers);
      } else {
        return await http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      }
    } catch (e) {
      _logger.warning('Failed to make authenticated request: $e');
      // Fallback to unauthenticated request for development
      final headers = {'Content-Type': 'application/json'};
      
      if (method == 'GET') {
        return await http.get(Uri.parse(url), headers: headers);
      } else {
        return await http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      }
    }
  }
}

/// Result classes for the enhanced voice AI service

class SpeechToTextResult {
  final String transcription;
  final double confidence;
  final String? languageCode;
  final String? error;
  final List<Map<String, dynamic>>? alternatives;

  SpeechToTextResult({
    required this.transcription,
    required this.confidence,
    this.languageCode,
    this.error,
    this.alternatives,
  });

  factory SpeechToTextResult.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List<dynamic>? ?? [];
    String transcription = '';
    double confidence = 0.0;
    
    if (results.isNotEmpty) {
      final firstResult = results.first as Map<String, dynamic>;
      final alternatives = firstResult['alternatives'] as List<dynamic>? ?? [];
      
      if (alternatives.isNotEmpty) {
        final firstAlternative = alternatives.first as Map<String, dynamic>;
        transcription = firstAlternative['transcript'] as String? ?? '';
        confidence = (firstAlternative['confidence'] as num?)?.toDouble() ?? 0.0;
      }
    }
    
    return SpeechToTextResult(
      transcription: transcription,
      confidence: confidence,
      languageCode: json['languageCode'] as String?,
      error: json['error'] as String?,
    );
  }
}

class TextToSpeechResult {
  final String? audioContent; // Base64 encoded
  final String? audioEncoding;
  final int? audioLength;
  final String? error;

  TextToSpeechResult({
    this.audioContent,
    this.audioEncoding,
    this.audioLength,
    this.error,
  });

  factory TextToSpeechResult.fromJson(Map<String, dynamic> json) {
    return TextToSpeechResult(
      audioContent: json['audioContent'] as String?,
      audioEncoding: json['audioEncoding'] as String?,
      audioLength: json['audioLength'] as int?,
      error: json['error'] as String?,
    );
  }
}

class VoiceInteractionResult {
  final String transcription;
  final String response;
  final String? audioResponse; // Base64 encoded
  final String? detectedLanguage;
  final double confidence;
  final String? error;
  final Map<String, dynamic>? metadata;

  VoiceInteractionResult({
    required this.transcription,
    required this.response,
    this.audioResponse,
    this.detectedLanguage,
    required this.confidence,
    this.error,
    this.metadata,
  });

  factory VoiceInteractionResult.fromJson(Map<String, dynamic> json) {
    return VoiceInteractionResult(
      transcription: json['transcription'] as String? ?? '',
      response: json['response'] as String? ?? '',
      audioResponse: json['audioResponse'] as String?,
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class LanguageDetectionResult {
  final String detectedLanguage;
  final double confidence;
  final String? error;

  LanguageDetectionResult({
    required this.detectedLanguage,
    required this.confidence,
    this.error,
  });

  factory LanguageDetectionResult.fromJson(Map<String, dynamic> json) {
    return LanguageDetectionResult(
      detectedLanguage: json['detectedLanguage'] as String? ?? 'en-US',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}

class NutritionVocabularyResult {
  final Map<String, List<String>> vocabulary;
  final int totalWords;
  final List<String> categories;
  final String? error;

  NutritionVocabularyResult({
    required this.vocabulary,
    required this.totalWords,
    required this.categories,
    this.error,
  });

  factory NutritionVocabularyResult.fromJson(Map<String, dynamic> json) {
    final vocab = json['vocabulary'] as Map<String, dynamic>? ?? {};
    final vocabularyMap = <String, List<String>>{};
    
    for (final entry in vocab.entries) {
      if (entry.value is List) {
        vocabularyMap[entry.key] = (entry.value as List).cast<String>();
      }
    }
    
    return NutritionVocabularyResult(
      vocabulary: vocabularyMap,
      totalWords: json['totalWords'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
      error: json['error'] as String?,
    );
  }
}
class EnhancedVoiceInteractionResult {
  final String transcription;
  final String response;
  final String? audioResponse; // Base64 encoded
  final String? detectedLanguage;
  final double confidence;
  final String? intentName;
  final Map<String, dynamic>? intentParameters;
  final ConversationContextResult? conversationContext;
  final String? error;
  final Map<String, dynamic>? metadata;

  EnhancedVoiceInteractionResult({
    required this.transcription,
    required this.response,
    this.audioResponse,
    this.detectedLanguage,
    required this.confidence,
    this.intentName,
    this.intentParameters,
    this.conversationContext,
    this.error,
    this.metadata,
  });

  factory EnhancedVoiceInteractionResult.fromJson(Map<String, dynamic> json) {
    return EnhancedVoiceInteractionResult(
      transcription: json['transcription'] as String? ?? '',
      response: json['response'] as String? ?? '',
      audioResponse: json['audioResponse'] as String?,
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      intentName: json['intentName'] as String?,
      intentParameters: json['intentParameters'] as Map<String, dynamic>?,
      conversationContext: json['conversationContext'] != null
          ? ConversationContextResult.fromJson(json['conversationContext'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class IntentDetectionResult {
  final String sessionId;
  final String intentName;
  final String responseText;
  final Map<String, dynamic> parameters;
  final double confidence;
  final String? fulfillmentText;
  final String? error;

  IntentDetectionResult({
    required this.sessionId,
    required this.intentName,
    required this.responseText,
    required this.parameters,
    required this.confidence,
    this.fulfillmentText,
    this.error,
  });

  factory IntentDetectionResult.fromJson(Map<String, dynamic> json) {
    return IntentDetectionResult(
      sessionId: json['sessionId'] as String? ?? 'default-session',
      intentName: json['intentName'] as String? ?? 'fallback.intent',
      responseText: json['responseText'] as String? ?? '',
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fulfillmentText: json['fulfillmentText'] as String?,
      error: json['error'] as String?,
    );
  }
}

class ConversationContextResult {
  final String name;
  final int lifespanCount;
  final Map<String, dynamic> parameters;
  final String? error;

  ConversationContextResult({
    required this.name,
    required this.lifespanCount,
    required this.parameters,
    this.error,
  });

  factory ConversationContextResult.fromJson(Map<String, dynamic> json) {
    return ConversationContextResult(
      name: json['name'] as String? ?? 'nutrition-context',
      lifespanCount: json['lifespanCount'] as int? ?? 5,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      error: json['error'] as String?,
    );
  }
}
class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final String? error;

  TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    this.error,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      translatedText: json['translatedText'] as String? ?? '',
      sourceLanguage: json['sourceLanguage'] as String? ?? 'auto',
      targetLanguage: json['targetLanguage'] as String? ?? 'en',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}

class NutritionTranslationResult {
  final Map<String, dynamic> translatedData;
  final String sourceLanguage;
  final String targetLanguage;
  final String? error;

  NutritionTranslationResult({
    required this.translatedData,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.error,
  });

  factory NutritionTranslationResult.fromJson(Map<String, dynamic> json) {
    return NutritionTranslationResult(
      translatedData: json['translatedData'] as Map<String, dynamic>? ?? {},
      sourceLanguage: json['sourceLanguage'] as String? ?? 'auto',
      targetLanguage: json['targetLanguage'] as String? ?? 'en',
      error: json['error'] as String?,
    );
  }
}

class SupportedLanguageInfo {
  final String languageCode;
  final String? displayName;

  SupportedLanguageInfo({
    required this.languageCode,
    this.displayName,
  });

  factory SupportedLanguageInfo.fromJson(Map<String, dynamic> json) {
    return SupportedLanguageInfo(
      languageCode: json['languageCode'] as String? ?? '',
      displayName: json['displayName'] as String?,
    );
  }
}

class SupportedLanguagesResult {
  final List<SupportedLanguageInfo> languages;
  final String? error;

  SupportedLanguagesResult({
    required this.languages,
    this.error,
  });

  factory SupportedLanguagesResult.fromJson(Map<String, dynamic> json) {
    final languagesList = json['languages'] as List<dynamic>? ?? [];
    final languages = languagesList
        .map((lang) => SupportedLanguageInfo.fromJson(lang as Map<String, dynamic>))
        .toList();
    
    return SupportedLanguagesResult(
      languages: languages,
      error: json['error'] as String?,
    );
  }
}