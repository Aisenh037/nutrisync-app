import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:logging/logging.dart';
import 'config/service_config.dart';
import 'services/gcp_speech_service.dart';
import 'services/gcp_tts_service.dart';
import 'services/gcp_dialogflow_service.dart';
import 'services/gcp_translation_service.dart';
import 'models/voice_models.dart';

/// Main Voice AI Service that orchestrates speech processing
class VoiceAIService {
  final _logger = Logger('VoiceAIService');
  
  late final GCPSpeechService _speechService;
  late final GCPTTSService _ttsService;
  late final GCPDialogflowService _dialogflowService;
  late final GCPTranslationService _translationService;
  late final ServiceConfig _config;
  
  /// Initialize the voice AI service
  Future<void> initialize() async {
    try {
      _config = ServiceConfig.instance;
      
      // Initialize GCP services
      _speechService = GCPSpeechService();
      await _speechService.initialize();
      
      _ttsService = GCPTTSService();
      await _ttsService.initialize();
      
      _dialogflowService = GCPDialogflowService();
      await _dialogflowService.initialize();
      
      _translationService = GCPTranslationService();
      await _translationService.initialize();
      
      _logger.info('Voice AI Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Voice AI Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Handle Speech-to-Text requests
  Future<Response> handleSpeechToText(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final sttRequest = SpeechToTextRequest.fromJson(requestData);
      final response = await _speechService.speechToText(sttRequest);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Speech-to-Text request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Speech-to-Text processing failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle Text-to-Speech requests
  Future<Response> handleTextToSpeech(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final ttsRequest = TextToSpeechRequest.fromJson(requestData);
      final response = await _ttsService.textToSpeech(ttsRequest);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Text-to-Speech request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Text-to-Speech processing failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle enhanced voice processing with Dialogflow (STT + Dialogflow + TTS)
  Future<Response> handleEnhancedVoiceProcessing(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final voiceRequest = EnhancedVoiceProcessingRequest.fromJson(requestData);
      
      // Step 1: Convert speech to text
      final sttRequest = SpeechToTextRequest(
        audioContent: voiceRequest.audioContent,
        languageCode: voiceRequest.languageCode,
        speechContexts: _config.getAllNutritionVocabulary(),
      );
      
      final sttResponse = await _speechService.speechToText(sttRequest);
      
      if (sttResponse.error != null || sttResponse.results.isEmpty) {
        return Response.ok(
          json.encode(EnhancedVoiceProcessingResponse(
            transcription: '',
            response: 'Maaf kijiye, main aapki awaaz samajh nahi paya. Kripaya phir se try kariye.',
            confidence: 0.0,
            error: sttResponse.error ?? 'No speech detected',
          ).toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final transcription = sttResponse.results.first.alternatives.first.transcript;
      final detectedLanguage = sttResponse.languageCode ?? voiceRequest.languageCode ?? 'en-US';
      
      // Step 2: Detect and translate input if needed
      String processedTranscription = transcription;
      String processingLanguage = detectedLanguage;
      
      // Auto-detect language if not English
      if (!detectedLanguage.startsWith('en')) {
        final languageDetectionRequest = LanguageDetectionRequest(text: transcription);
        final languageDetectionResponse = await _translationService.detectLanguage(languageDetectionRequest);
        
        if (languageDetectionResponse.error == null && languageDetectionResponse.confidence! > 0.7) {
          processingLanguage = languageDetectionResponse.detectedLanguage!;
          
          // Translate to English for processing if not already English
          if (!processingLanguage.startsWith('en')) {
            final translationRequest = TranslationRequest(
              text: transcription,
              targetLanguage: 'en',
              sourceLanguage: processingLanguage,
            );
            
            final translationResponse = await _translationService.translateText(translationRequest);
            
            if (translationResponse.error == null) {
              processedTranscription = translationResponse.translatedText;
              _logger.info('Translated input from $processingLanguage to English: $processedTranscription');
            }
          }
        }
      }
      
      // Step 3: Process with Dialogflow for intent recognition
      String responseText;
      String? intentName;
      Map<String, dynamic>? intentParameters;
      ConversationContext? conversationContext;
      
      if (voiceRequest.useDialogflow == true) {
        final dialogflowRequest = DialogflowRequest(
          text: processedTranscription, // Use translated text for processing
          sessionId: voiceRequest.sessionId ?? 'default-session',
          languageCode: 'en', // Process in English
          context: voiceRequest.context,
        );
        
        final dialogflowResponse = await _dialogflowService.detectIntent(dialogflowRequest);
        
        responseText = dialogflowResponse.responseText;
        intentName = dialogflowResponse.intentName;
        intentParameters = dialogflowResponse.parameters;
        
        // Update conversation context
        if (intentParameters.isNotEmpty) {
          conversationContext = await _dialogflowService.updateContext(
            dialogflowRequest.sessionId,
            'nutrition-context',
            intentParameters,
          );
        }
      } else {
        // Fallback to simple processing
        responseText = await _processNutritionQuery(
          processedTranscription, // Use translated text
          voiceRequest.userId,
          voiceRequest.context,
        );
      }
      
      // Step 4: Translate response back to user's language if needed
      String finalResponseText = responseText;
      if (!processingLanguage.startsWith('en') && processingLanguage != detectedLanguage) {
        final responseTranslationRequest = TranslationRequest(
          text: responseText,
          targetLanguage: processingLanguage,
          sourceLanguage: 'en',
        );
        
        final responseTranslationResponse = await _translationService.translateText(responseTranslationRequest);
        
        if (responseTranslationResponse.error == null) {
          finalResponseText = responseTranslationResponse.translatedText;
          _logger.info('Translated response from English to $processingLanguage: $finalResponseText');
        }
      }
      
      // Step 5: Convert response to speech
      final ttsRequest = TextToSpeechRequest(
        text: finalResponseText, // Use translated response
        languageCode: processingLanguage, // Use user's original language
      );
      
      final ttsResponse = await _ttsService.textToSpeech(ttsRequest);
      
      // Step 6: Return enhanced response
      final enhancedResponse = EnhancedVoiceProcessingResponse(
        transcription: transcription, // Original transcription
        response: finalResponseText, // Translated response
        audioResponse: ttsResponse.audioContent,
        detectedLanguage: processingLanguage, // User's language
        confidence: sttResponse.confidence ?? 0.0,
        intentName: intentName,
        intentParameters: intentParameters,
        conversationContext: conversationContext,
        metadata: {
          'processingTime': DateTime.now().toIso8601String(),
          'userId': voiceRequest.userId,
          'sessionId': voiceRequest.sessionId,
          'useDialogflow': voiceRequest.useDialogflow,
          'originalLanguage': detectedLanguage,
          'processingLanguage': processingLanguage,
          'translationUsed': !processingLanguage.startsWith('en'),
        },
      );
      
      return Response.ok(
        json.encode(enhancedResponse.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Enhanced voice processing request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Enhanced voice processing failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  Future<Response> handleVoiceProcessing(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final voiceRequest = VoiceProcessingRequest.fromJson(requestData);
      
      // Step 1: Convert speech to text
      final sttRequest = SpeechToTextRequest(
        audioContent: voiceRequest.audioContent,
        languageCode: voiceRequest.languageCode,
        speechContexts: _config.getAllNutritionVocabulary(),
      );
      
      final sttResponse = await _speechService.speechToText(sttRequest);
      
      if (sttResponse.error != null || sttResponse.results.isEmpty) {
        return Response.ok(
          json.encode(VoiceProcessingResponse(
            error: sttResponse.error ?? 'No speech detected',
          ).toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final transcription = sttResponse.results.first.alternatives.first.transcript;
      final detectedLanguage = sttResponse.languageCode ?? voiceRequest.languageCode ?? 'en-US';
      
      // Step 2: Process the transcription (generate response)
      final responseText = await _processNutritionQuery(
        transcription,
        voiceRequest.userId,
        voiceRequest.context,
      );
      
      // Step 3: Convert response to speech
      final ttsRequest = TextToSpeechRequest(
        text: responseText,
        languageCode: detectedLanguage,
      );
      
      final ttsResponse = await _ttsService.textToSpeech(ttsRequest);
      
      // Step 4: Return complete response
      final voiceResponse = VoiceProcessingResponse(
        transcription: transcription,
        response: responseText,
        audioResponse: ttsResponse.audioContent,
        detectedLanguage: detectedLanguage,
        confidence: sttResponse.confidence,
        metadata: {
          'processingTime': DateTime.now().toIso8601String(),
          'userId': voiceRequest.userId,
          'sessionId': voiceRequest.sessionId,
        },
      );
      
      return Response.ok(
        json.encode(voiceResponse.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Voice processing request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Voice processing failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle Dialogflow intent detection requests
  Future<Response> handleIntentDetection(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final dialogflowRequest = DialogflowRequest.fromJson(requestData);
      final response = await _dialogflowService.detectIntent(dialogflowRequest);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Intent detection request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Intent detection failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle conversation context management requests
  Future<Response> handleContextManagement(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final sessionId = requestData['sessionId'] as String;
      final contextName = requestData['contextName'] as String? ?? 'nutrition-context';
      final parameters = requestData['parameters'] as Map<String, dynamic>? ?? {};
      final action = requestData['action'] as String? ?? 'update';
      
      ConversationContext? context;
      
      switch (action) {
        case 'create':
          context = await _dialogflowService.createContext(sessionId, parameters);
          break;
        case 'get':
          context = await _dialogflowService.getContext(sessionId, contextName);
          break;
        case 'update':
          context = await _dialogflowService.updateContext(sessionId, contextName, parameters);
          break;
        default:
          throw Exception('Invalid action: $action');
      }
      
      return Response.ok(
        json.encode(context?.toJson() ?? {}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Context management request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Context management failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  /// Handle text translation requests
  Future<Response> handleTextTranslation(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final translationRequest = TranslationRequest.fromJson(requestData);
      final response = await _translationService.translateText(translationRequest);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Text translation request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Text translation failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle nutrition data translation requests
  Future<Response> handleNutritionTranslation(Request request) async {
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final nutritionRequest = NutritionTranslationRequest.fromJson(requestData);
      final response = await _translationService.translateNutritionData(nutritionRequest);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Nutrition translation request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Nutrition translation failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle supported languages requests
  Future<Response> handleGetSupportedLanguages(Request request) async {
    try {
      final response = await _translationService.getSupportedLanguages();
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Get supported languages request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Get supported languages failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
    try {
      final body = await request.readAsString();
      final requestData = json.decode(body) as Map<String, dynamic>;
      
      final detectionRequest = LanguageDetectionRequest.fromJson(requestData);
      
      // Convert text to audio bytes for language detection
      // In a real implementation, this would be audio data
      final audioBytes = Uint8List.fromList(utf8.encode(detectionRequest.text));
      
      final response = await _speechService.detectLanguage(audioBytes);
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Language detection request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Language detection failed: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Handle nutrition vocabulary requests
  Future<Response> handleGetNutritionVocabulary(Request request) async {
    try {
      final vocabulary = <String, List<String>>{};
      final categories = <String>[];
      
      // Extract vocabulary by categories
      final foods = _config.nutritionVocabulary['foods'] as Map<String, dynamic>? ?? {};
      for (final entry in foods.entries) {
        if (entry.value is List) {
          vocabulary[entry.key] = (entry.value as List).cast<String>();
          categories.add(entry.key);
        }
      }
      
      // Add other categories
      for (final category in ['measurements', 'cooking_methods', 'meal_types', 'nutrition_terms', 'hinglish_phrases']) {
        final words = _config.nutritionVocabulary[category] as List<dynamic>? ?? [];
        if (words.isNotEmpty) {
          vocabulary[category] = words.cast<String>();
          categories.add(category);
        }
      }
      
      final totalWords = vocabulary.values.fold<int>(0, (sum, list) => sum + list.length);
      
      final response = NutritionVocabularyResponse(
        vocabulary: vocabulary,
        totalWords: totalWords,
        categories: categories,
      );
      
      return Response.ok(
        json.encode(response.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.severe('Nutrition vocabulary request failed: $e', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Failed to get nutrition vocabulary: $e',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Process nutrition-related queries and generate responses
  Future<String> _processNutritionQuery(
    String query,
    String? userId,
    Map<String, dynamic>? context,
  ) async {
    try {
      final lowerQuery = query.toLowerCase();
      
      // Simple nutrition query processing
      // In a real implementation, this would integrate with Dialogflow or a more sophisticated NLP service
      
      if (lowerQuery.contains('khaya') || lowerQuery.contains('eaten') || lowerQuery.contains('had')) {
        return _processMealLogging(query, context);
      } else if (lowerQuery.contains('calories') || lowerQuery.contains('nutrition')) {
        return _processNutritionInquiry(query, context);
      } else if (lowerQuery.contains('suggest') || lowerQuery.contains('recommend') || lowerQuery.contains('batao')) {
        return _processRecommendationRequest(query, context);
      } else if (lowerQuery.contains('hello') || lowerQuery.contains('namaste') || lowerQuery.contains('hi')) {
        return _processGreeting(query, context);
      } else {
        return _processGeneralQuery(query, context);
      }
    } catch (e) {
      _logger.warning('Failed to process nutrition query: $e');
      return 'Maaf kijiye, main aapka sawal samajh nahi paya. Kripaya phir se try kariye.';
    }
  }
  
  String _processMealLogging(String query, Map<String, dynamic>? context) {
    // Extract food items from the query
    final foods = _extractFoodItems(query);
    
    if (foods.isNotEmpty) {
      final foodList = foods.join(', ');
      return 'Accha! Aapne $foodList khaya hai. Main iska nutrition calculate kar raha hun. '
             'Yeh healthy choice hai! Kya aur kuch khaya hai?';
    } else {
      return 'Kya khaya aapne? Thoda detail mein batayiye taaki main nutrition track kar sakun.';
    }
  }
  
  String _processNutritionInquiry(String query, Map<String, dynamic>? context) {
    return 'Nutrition ke baare mein jaanna chahte hain? Main aapko balanced diet ke baare mein bata sakta hun. '
           'Protein, carbohydrates, aur vitamins sabka balance important hai. Koi specific food ke baare mein puchna hai?';
  }
  
  String _processRecommendationRequest(String query, Map<String, dynamic>? context) {
    final timeOfDay = DateTime.now().hour;
    
    if (timeOfDay < 10) {
      return 'Breakfast ke liye main recommend karta hun: Oats with fruits, ya phir poha with vegetables. '
             'Protein aur fiber dono milega!';
    } else if (timeOfDay < 15) {
      return 'Lunch ke liye try kariye: Dal chawal with sabzi, ya phir quinoa salad. '
             'Balanced nutrition ke liye perfect hai!';
    } else {
      return 'Dinner ke liye light khana best hai: Vegetable soup with roti, ya phir grilled vegetables. '
             'Raat mein heavy food avoid kariye!';
    }
  }
  
  String _processGreeting(String query, Map<String, dynamic>? context) {
    return 'Namaste! Main aapka nutrition assistant hun. Aaj kya khaya aapne? '
           'Ya phir koi nutrition advice chahiye?';
  }
  
  String _processGeneralQuery(String query, Map<String, dynamic>? context) {
    return 'Main aapka nutrition assistant hun. Aap meal log kar sakte hain, '
           'nutrition ke baare mein puch sakte hain, ya healthy food recommendations le sakte hain. '
           'Kya help chahiye?';
  }
  
  /// Extract food items from query text
  List<String> _extractFoodItems(String query) {
    final foods = <String>[];
    final lowerQuery = query.toLowerCase();
    
    // Check against nutrition vocabulary
    final allFoods = [
      ..._config.getNutritionVocabulary('indian'),
      ..._config.getNutritionVocabulary('international'),
      ..._config.getNutritionVocabulary('vegetables'),
      ..._config.getNutritionVocabulary('fruits'),
    ];
    
    for (final food in allFoods) {
      if (lowerQuery.contains(food.toLowerCase())) {
        foods.add(food);
      }
    }
    
    return foods;
  }
  
  /// Dispose of resources
  Future<void> dispose() async {
    _speechService.dispose();
    _ttsService.dispose();
    _dialogflowService.dispose();
    _translationService.dispose();
  }
}