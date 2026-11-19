import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';
import '../config/service_config.dart';
import '../models/voice_models.dart';

/// Service for Google Cloud Speech-to-Text API integration
class GCPSpeechService {
  final _logger = Logger('GCPSpeechService');
  final ServiceConfig _config = ServiceConfig.instance;
  
  AutoRefreshingAuthClient? _authClient;
  
  /// Initialize the speech service with authentication
  Future<void> initialize() async {
    try {
      final credentials = _config.serviceAccountCredentials;
      if (credentials != null) {
        final accountCredentials = ServiceAccountCredentials.fromJson(credentials);
        _authClient = await clientViaServiceAccount(
          accountCredentials,
          ['https://www.googleapis.com/auth/cloud-platform'],
        );
        _logger.info('GCP Speech service initialized with service account');
      } else {
        _logger.warning('No service account credentials found, using default credentials');
        // In production, this would use Application Default Credentials
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize GCP Speech service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Convert speech to text using GCP Speech-to-Text API
  Future<SpeechToTextResponse> speechToText(SpeechToTextRequest request) async {
    try {
      final apiUrl = '${_config.getApiEndpoint('speech')}/speech:recognize';
      
      // Build the request payload for GCP API
      final payload = {
        'config': {
          'encoding': 'WEBM_OPUS', // Assuming WebM Opus encoding
          'sampleRateHertz': 48000,
          'languageCode': request.languageCode ?? _config.speechConfig['languageCode'],
          'model': request.model ?? _config.speechConfig['model'],
          'useEnhanced': request.useEnhanced ?? _config.speechConfig['useEnhanced'],
          'enableAutomaticPunctuation': request.enableAutomaticPunctuation ?? 
              _config.speechConfig['enableAutomaticPunctuation'],
          'enableWordTimeOffsets': request.enableWordTimeOffsets ?? 
              _config.speechConfig['enableWordTimeOffsets'],
          'enableWordConfidence': request.enableWordConfidence ?? 
              _config.speechConfig['enableWordConfidence'],
          'maxAlternatives': request.maxAlternatives ?? _config.speechConfig['maxAlternatives'],
          'profanityFilter': _config.speechConfig['profanityFilter'],
          if (request.speechContexts != null || _hasNutritionContext())
            'speechContexts': [
              {
                'phrases': [
                  ...?request.speechContexts,
                  ..._getNutritionVocabularyPhrases(),
                ],
                'boost': 10.0, // Boost nutrition-related terms
              }
            ],
        },
        'audio': {
          'content': request.audioContent,
        },
      };
      
      final response = await _makeAuthenticatedRequest(apiUrl, payload);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseGCPSpeechResponse(responseData);
      } else {
        final errorMessage = 'Speech-to-Text API error: ${response.statusCode} ${response.body}';
        _logger.warning(errorMessage);
        return SpeechToTextResponse(
          results: [],
          error: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Speech-to-Text processing failed: $e', e, stackTrace);
      return SpeechToTextResponse(
        results: [],
        error: 'Speech processing failed: $e',
      );
    }
  }
  
  /// Detect language from audio
  Future<LanguageDetectionResponse> detectLanguage(Uint8List audioData) async {
    try {
      // Use a simplified speech recognition request for language detection
      final request = SpeechToTextRequest(
        audioContent: base64Encode(audioData),
        maxAlternatives: 1,
      );
      
      // Try multiple language codes to detect the most likely one
      final languagesToTry = _config.supportedLanguages;
      double bestConfidence = 0.0;
      String? bestLanguage;
      
      for (final languageCode in languagesToTry) {
        final testRequest = SpeechToTextRequest(
          audioContent: request.audioContent,
          languageCode: languageCode,
          maxAlternatives: 1,
        );
        
        final response = await speechToText(testRequest);
        if (response.results.isNotEmpty && response.confidence != null) {
          if (response.confidence! > bestConfidence) {
            bestConfidence = response.confidence!;
            bestLanguage = languageCode;
          }
        }
      }
      
      return LanguageDetectionResponse(
        detectedLanguage: bestLanguage,
        confidence: bestConfidence,
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Language detection failed: $e', e, stackTrace);
      return LanguageDetectionResponse(
        error: 'Language detection failed: $e',
      );
    }
  }
  
  /// Parse GCP Speech API response
  SpeechToTextResponse _parseGCPSpeechResponse(Map<String, dynamic> responseData) {
    final results = <SpeechRecognitionResult>[];
    double? overallConfidence;
    String? detectedLanguage;
    
    final gcpResults = responseData['results'] as List<dynamic>? ?? [];
    
    for (final gcpResult in gcpResults) {
      final alternatives = <SpeechRecognitionAlternative>[];
      final gcpAlternatives = gcpResult['alternatives'] as List<dynamic>? ?? [];
      
      for (final gcpAlternative in gcpAlternatives) {
        final words = <WordInfo>[];
        final gcpWords = gcpAlternative['words'] as List<dynamic>? ?? [];
        
        for (final gcpWord in gcpWords) {
          words.add(WordInfo(
            word: gcpWord['word'] as String,
            startTime: gcpWord['startTime'] as String?,
            endTime: gcpWord['endTime'] as String?,
            confidence: (gcpWord['confidence'] as num?)?.toDouble(),
          ));
        }
        
        alternatives.add(SpeechRecognitionAlternative(
          transcript: gcpAlternative['transcript'] as String,
          confidence: (gcpAlternative['confidence'] as num?)?.toDouble(),
          words: words.isNotEmpty ? words : null,
        ));
      }
      
      final resultConfidence = (gcpResult['confidence'] as num?)?.toDouble();
      if (overallConfidence == null || (resultConfidence != null && resultConfidence > overallConfidence)) {
        overallConfidence = resultConfidence;
      }
      
      results.add(SpeechRecognitionResult(
        alternatives: alternatives,
        languageCode: gcpResult['languageCode'] as String?,
        confidence: resultConfidence,
      ));
    }
    
    // Extract detected language from the first result
    if (results.isNotEmpty) {
      detectedLanguage = results.first.languageCode;
    }
    
    return SpeechToTextResponse(
      results: results,
      confidence: overallConfidence,
      languageCode: detectedLanguage,
    );
  }
  
  /// Check if nutrition context should be added
  bool _hasNutritionContext() {
    return _config.nutritionVocabulary.isNotEmpty;
  }
  
  /// Get nutrition vocabulary phrases for speech context
  List<String> _getNutritionVocabularyPhrases() {
    final phrases = <String>[];
    
    // Add high-priority nutrition terms
    phrases.addAll(_config.getNutritionVocabulary('indian'));
    phrases.addAll(_config.getNutritionVocabulary('international'));
    
    // Add measurements and meal types
    final measurements = _config.nutritionVocabulary['measurements'] as List<dynamic>? ?? [];
    phrases.addAll(measurements.cast<String>());
    
    final mealTypes = _config.nutritionVocabulary['meal_types'] as List<dynamic>? ?? [];
    phrases.addAll(mealTypes.cast<String>());
    
    // Add Hinglish phrases
    final hinglishPhrases = _config.nutritionVocabulary['hinglish_phrases'] as List<dynamic>? ?? [];
    phrases.addAll(hinglishPhrases.cast<String>());
    
    return phrases.take(500).toList(); // Limit to 500 phrases for performance
  }
  
  /// Make authenticated HTTP request to GCP API
  Future<http.Response> _makeAuthenticatedRequest(String url, Map<String, dynamic> payload) async {
    if (_authClient != null) {
      return await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
    } else {
      // Fallback for development/testing
      _logger.warning('Making unauthenticated request (development mode)');
      return http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer mock-token-for-development',
        },
        body: json.encode(payload),
      );
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _authClient?.close();
  }
}