import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../models/voice_models.dart';

/// GCP Translation service for multi-language support
class GCPTranslationService {
  final _logger = Logger('GCPTranslationService');
  
  String? _projectId;
  String? _accessToken;
  
  /// Initialize the Translation service
  Future<void> initialize() async {
    try {
      _projectId = Platform.environment['GCP_PROJECT_ID'] ?? 'nutrisync-dev';
      
      // Get access token for authentication
      await _getAccessToken();
      
      _logger.info('Translation service initialized for project: $_projectId');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Translation service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Translate text from source language to target language
  Future<TranslationResponse> translateText(TranslationRequest request) async {
    try {
      if (_projectId == null || _accessToken == null) {
        throw Exception('Translation service not initialized');
      }
      
      final url = 'https://translation.googleapis.com/v3/projects/$_projectId/locations/global:translateText';
      
      final requestBody = {
        'contents': [request.text],
        'targetLanguageCode': request.targetLanguage,
        if (request.sourceLanguage != null) 'sourceLanguageCode': request.sourceLanguage,
        'mimeType': 'text/plain',
        'model': 'projects/$_projectId/locations/global/models/general/nmt',
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseTranslationResponse(responseData, request);
      } else {
        _logger.warning('Translation API error: ${response.statusCode} ${response.body}');
        return _createFallbackTranslationResponse(request);
      }
    } catch (e, stackTrace) {
      _logger.severe('Translation failed: $e', e, stackTrace);
      return _createFallbackTranslationResponse(request);
    }
  }
  
  /// Detect language of the given text
  Future<LanguageDetectionResponse> detectLanguage(LanguageDetectionRequest request) async {
    try {
      if (_projectId == null || _accessToken == null) {
        throw Exception('Translation service not initialized');
      }
      
      final url = 'https://translation.googleapis.com/v3/projects/$_projectId/locations/global:detectLanguage';
      
      final requestBody = {
        'content': request.text,
        'mimeType': 'text/plain',
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseLanguageDetectionResponse(responseData);
      } else {
        _logger.warning('Language detection API error: ${response.statusCode} ${response.body}');
        return _createFallbackLanguageDetectionResponse();
      }
    } catch (e, stackTrace) {
      _logger.severe('Language detection failed: $e', e, stackTrace);
      return _createFallbackLanguageDetectionResponse();
    }
  }
  
  /// Get list of supported languages
  Future<SupportedLanguagesResponse> getSupportedLanguages() async {
    try {
      if (_projectId == null || _accessToken == null) {
        throw Exception('Translation service not initialized');
      }
      
      final url = 'https://translation.googleapis.com/v3/projects/$_projectId/locations/global/supportedLanguages';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseSupportedLanguagesResponse(responseData);
      } else {
        _logger.warning('Supported languages API error: ${response.statusCode} ${response.body}');
        return _createFallbackSupportedLanguagesResponse();
      }
    } catch (e, stackTrace) {
      _logger.severe('Get supported languages failed: $e', e, stackTrace);
      return _createFallbackSupportedLanguagesResponse();
    }
  }
  
  /// Translate nutrition data while preserving accuracy
  Future<NutritionTranslationResponse> translateNutritionData(NutritionTranslationRequest request) async {
    try {
      final translatedData = <String, dynamic>{};
      
      // Translate food names while preserving nutritional values
      for (final entry in request.nutritionData.entries) {
        if (_isNutritionValue(entry.key)) {
          // Preserve numerical nutrition values
          translatedData[entry.key] = entry.value;
        } else if (_isFoodName(entry.key)) {
          // Translate food names with cultural adaptation
          final translationRequest = TranslationRequest(
            text: entry.value.toString(),
            targetLanguage: request.targetLanguage,
            sourceLanguage: request.sourceLanguage,
          );
          
          final translationResponse = await translateText(translationRequest);
          
          if (translationResponse.error == null) {
            translatedData[entry.key] = _adaptFoodNameCulturally(
              translationResponse.translatedText,
              request.targetLanguage,
            );
          } else {
            // Fallback to original if translation fails
            translatedData[entry.key] = entry.value;
          }
        } else {
          // Translate other text fields
          final translationRequest = TranslationRequest(
            text: entry.value.toString(),
            targetLanguage: request.targetLanguage,
            sourceLanguage: request.sourceLanguage,
          );
          
          final translationResponse = await translateText(translationRequest);
          translatedData[entry.key] = translationResponse.error == null 
              ? translationResponse.translatedText 
              : entry.value;
        }
      }
      
      return NutritionTranslationResponse(
        translatedData: translatedData,
        sourceLanguage: request.sourceLanguage ?? 'auto',
        targetLanguage: request.targetLanguage,
      );
    } catch (e, stackTrace) {
      _logger.severe('Nutrition data translation failed: $e', e, stackTrace);
      return NutritionTranslationResponse(
        translatedData: request.nutritionData,
        sourceLanguage: request.sourceLanguage ?? 'auto',
        targetLanguage: request.targetLanguage,
        error: 'Nutrition translation failed: $e',
      );
    }
  }
  
  /// Get access token for Translation API
  Future<void> _getAccessToken() async {
    try {
      // In production, this would use service account authentication
      // For development, we'll use a mock token or environment variable
      _accessToken = Platform.environment['TRANSLATION_ACCESS_TOKEN'] ?? 'mock-token';
      
      if (_accessToken == 'mock-token') {
        _logger.warning('Using mock access token for Translation API. Set TRANSLATION_ACCESS_TOKEN environment variable for production.');
      }
    } catch (e) {
      _logger.warning('Failed to get access token: $e');
      _accessToken = 'mock-token';
    }
  }
  
  /// Parse Translation API response
  TranslationResponse _parseTranslationResponse(Map<String, dynamic> responseData, TranslationRequest request) {
    try {
      final translations = responseData['translations'] as List<dynamic>? ?? [];
      
      if (translations.isNotEmpty) {
        final firstTranslation = translations.first as Map<String, dynamic>;
        final translatedText = firstTranslation['translatedText'] as String? ?? '';
        final detectedSourceLanguage = firstTranslation['detectedSourceLanguage'] as String?;
        
        return TranslationResponse(
          translatedText: translatedText,
          sourceLanguage: detectedSourceLanguage ?? request.sourceLanguage ?? 'auto',
          targetLanguage: request.targetLanguage,
          confidence: 0.95, // GCP Translation API typically has high confidence
        );
      } else {
        return _createFallbackTranslationResponse(request);
      }
    } catch (e) {
      _logger.warning('Failed to parse translation response: $e');
      return _createFallbackTranslationResponse(request);
    }
  }
  
  /// Parse Language Detection API response
  LanguageDetectionResponse _parseLanguageDetectionResponse(Map<String, dynamic> responseData) {
    try {
      final languages = responseData['languages'] as List<dynamic>? ?? [];
      
      if (languages.isNotEmpty) {
        final firstLanguage = languages.first as Map<String, dynamic>;
        final languageCode = firstLanguage['languageCode'] as String? ?? 'en';
        final confidence = (firstLanguage['confidence'] as num?)?.toDouble() ?? 0.0;
        
        return LanguageDetectionResponse(
          detectedLanguage: languageCode,
          confidence: confidence,
        );
      } else {
        return _createFallbackLanguageDetectionResponse();
      }
    } catch (e) {
      _logger.warning('Failed to parse language detection response: $e');
      return _createFallbackLanguageDetectionResponse();
    }
  }
  
  /// Parse Supported Languages API response
  SupportedLanguagesResponse _parseSupportedLanguagesResponse(Map<String, dynamic> responseData) {
    try {
      final languages = responseData['languages'] as List<dynamic>? ?? [];
      final supportedLanguages = <SupportedLanguage>[];
      
      for (final lang in languages) {
        if (lang is Map<String, dynamic>) {
          supportedLanguages.add(SupportedLanguage(
            languageCode: lang['languageCode'] as String? ?? '',
            displayName: lang['displayName'] as String?,
          ));
        }
      }
      
      return SupportedLanguagesResponse(
        languages: supportedLanguages,
      );
    } catch (e) {
      _logger.warning('Failed to parse supported languages response: $e');
      return _createFallbackSupportedLanguagesResponse();
    }
  }
  
  /// Create fallback translation response
  TranslationResponse _createFallbackTranslationResponse(TranslationRequest request) {
    return TranslationResponse(
      translatedText: request.text, // Return original text as fallback
      sourceLanguage: request.sourceLanguage ?? 'auto',
      targetLanguage: request.targetLanguage,
      confidence: 0.0,
      error: 'Translation service unavailable',
    );
  }
  
  /// Create fallback language detection response
  LanguageDetectionResponse _createFallbackLanguageDetectionResponse() {
    return LanguageDetectionResponse(
      detectedLanguage: 'en',
      confidence: 0.5,
      error: 'Language detection service unavailable',
    );
  }
  
  /// Create fallback supported languages response
  SupportedLanguagesResponse _createFallbackSupportedLanguagesResponse() {
    return SupportedLanguagesResponse(
      languages: [
        SupportedLanguage(languageCode: 'en', displayName: 'English'),
        SupportedLanguage(languageCode: 'hi', displayName: 'Hindi'),
        SupportedLanguage(languageCode: 'es', displayName: 'Spanish'),
        SupportedLanguage(languageCode: 'fr', displayName: 'French'),
        SupportedLanguage(languageCode: 'de', displayName: 'German'),
      ],
      error: 'Supported languages service unavailable',
    );
  }
  
  /// Check if a key represents a nutrition value (should not be translated)
  bool _isNutritionValue(String key) {
    final nutritionKeys = [
      'calories', 'protein', 'carbohydrates', 'fat', 'fiber',
      'sugar', 'sodium', 'cholesterol', 'vitamins', 'minerals',
      'serving_size', 'weight', 'quantity'
    ];
    return nutritionKeys.contains(key.toLowerCase());
  }
  
  /// Check if a key represents a food name (should be translated)
  bool _isFoodName(String key) {
    final foodNameKeys = [
      'name', 'food_name', 'dish_name', 'ingredient_name',
      'recipe_name', 'meal_name', 'item_name'
    ];
    return foodNameKeys.contains(key.toLowerCase());
  }
  
  /// Adapt food name culturally for the target language
  String _adaptFoodNameCulturally(String translatedName, String targetLanguage) {
    // Cultural adaptations for specific languages
    switch (targetLanguage.toLowerCase()) {
      case 'hi':
      case 'hi-in':
        // Hindi adaptations - preserve common Indian food names
        final indianFoods = {
          'rice': 'चावल',
          'lentils': 'दाल',
          'bread': 'रोटी',
          'vegetables': 'सब्जी',
          'curry': 'करी',
          'yogurt': 'दही',
        };
        
        for (final entry in indianFoods.entries) {
          if (translatedName.toLowerCase().contains(entry.key)) {
            return translatedName.replaceAll(entry.key, entry.value);
          }
        }
        break;
        
      case 'es':
      case 'es-es':
        // Spanish adaptations - use local food terms
        final spanishFoods = {
          'rice': 'arroz',
          'chicken': 'pollo',
          'vegetables': 'verduras',
          'soup': 'sopa',
        };
        
        for (final entry in spanishFoods.entries) {
          if (translatedName.toLowerCase().contains(entry.key)) {
            return translatedName.replaceAll(entry.key, entry.value);
          }
        }
        break;
    }
    
    return translatedName;
  }
  
  /// Dispose of resources
  void dispose() {
    _logger.info('Translation service disposed');
  }
}