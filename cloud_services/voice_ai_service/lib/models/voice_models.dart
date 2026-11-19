import 'package:json_annotation/json_annotation.dart';

part 'voice_models.g.dart';

/// Request model for Speech-to-Text API
@JsonSerializable()
class SpeechToTextRequest {
  final String audioContent; // Base64 encoded audio
  final String? languageCode;
  final String? model;
  final bool? useEnhanced;
  final int? maxAlternatives;
  final bool? enableAutomaticPunctuation;
  final bool? enableWordTimeOffsets;
  final bool? enableWordConfidence;
  final List<String>? speechContexts; // Nutrition vocabulary hints

  SpeechToTextRequest({
    required this.audioContent,
    this.languageCode,
    this.model,
    this.useEnhanced,
    this.maxAlternatives,
    this.enableAutomaticPunctuation,
    this.enableWordTimeOffsets,
    this.enableWordConfidence,
    this.speechContexts,
  });

  factory SpeechToTextRequest.fromJson(Map<String, dynamic> json) =>
      _$SpeechToTextRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechToTextRequestToJson(this);
}

/// Response model for Speech-to-Text API
@JsonSerializable()
class SpeechToTextResponse {
  final List<SpeechRecognitionResult> results;
  final String? error;
  final double? confidence;
  final String? languageCode;

  SpeechToTextResponse({
    required this.results,
    this.error,
    this.confidence,
    this.languageCode,
  });

  factory SpeechToTextResponse.fromJson(Map<String, dynamic> json) =>
      _$SpeechToTextResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechToTextResponseToJson(this);
}

/// Speech recognition result
@JsonSerializable()
class SpeechRecognitionResult {
  final List<SpeechRecognitionAlternative> alternatives;
  final String? languageCode;
  final double? confidence;

  SpeechRecognitionResult({
    required this.alternatives,
    this.languageCode,
    this.confidence,
  });

  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionResultFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechRecognitionResultToJson(this);
}

/// Speech recognition alternative
@JsonSerializable()
class SpeechRecognitionAlternative {
  final String transcript;
  final double? confidence;
  final List<WordInfo>? words;

  SpeechRecognitionAlternative({
    required this.transcript,
    this.confidence,
    this.words,
  });

  factory SpeechRecognitionAlternative.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionAlternativeFromJson(json);

  Map<String, dynamic> toJson() => _$SpeechRecognitionAlternativeToJson(this);
}

/// Word information with timing
@JsonSerializable()
class WordInfo {
  final String word;
  final String? startTime;
  final String? endTime;
  final double? confidence;

  WordInfo({
    required this.word,
    this.startTime,
    this.endTime,
    this.confidence,
  });

  factory WordInfo.fromJson(Map<String, dynamic> json) =>
      _$WordInfoFromJson(json);

  Map<String, dynamic> toJson() => _$WordInfoToJson(this);
}

/// Request model for Text-to-Speech API
@JsonSerializable()
class TextToSpeechRequest {
  final String text;
  final String? languageCode;
  final String? voiceName;
  final String? audioEncoding;
  final double? speakingRate;
  final double? pitch;
  final double? volumeGainDb;

  TextToSpeechRequest({
    required this.text,
    this.languageCode,
    this.voiceName,
    this.audioEncoding,
    this.speakingRate,
    this.pitch,
    this.volumeGainDb,
  });

  factory TextToSpeechRequest.fromJson(Map<String, dynamic> json) =>
      _$TextToSpeechRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TextToSpeechRequestToJson(this);
}

/// Response model for Text-to-Speech API
@JsonSerializable()
class TextToSpeechResponse {
  final String? audioContent; // Base64 encoded audio
  final String? error;
  final String? audioEncoding;
  final int? audioLength;

  TextToSpeechResponse({
    this.audioContent,
    this.error,
    this.audioEncoding,
    this.audioLength,
  });

  factory TextToSpeechResponse.fromJson(Map<String, dynamic> json) =>
      _$TextToSpeechResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TextToSpeechResponseToJson(this);
}

/// Request model for enhanced voice processing
@JsonSerializable()
class VoiceProcessingRequest {
  final String audioContent; // Base64 encoded audio
  final String? userId;
  final String? sessionId;
  final String? languageCode;
  final Map<String, dynamic>? context; // User context for personalized responses

  VoiceProcessingRequest({
    required this.audioContent,
    this.userId,
    this.sessionId,
    this.languageCode,
    this.context,
  });

  factory VoiceProcessingRequest.fromJson(Map<String, dynamic> json) =>
      _$VoiceProcessingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$VoiceProcessingRequestToJson(this);
}

/// Response model for enhanced voice processing
@JsonSerializable()
class VoiceProcessingResponse {
  final String? transcription;
  final String? response;
  final String? audioResponse; // Base64 encoded audio response
  final String? detectedLanguage;
  final double? confidence;
  final String? error;
  final Map<String, dynamic>? metadata;

  VoiceProcessingResponse({
    this.transcription,
    this.response,
    this.audioResponse,
    this.detectedLanguage,
    this.confidence,
    this.error,
    this.metadata,
  });

  factory VoiceProcessingResponse.fromJson(Map<String, dynamic> json) =>
      _$VoiceProcessingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$VoiceProcessingResponseToJson(this);
}

/// Request model for language detection
@JsonSerializable()
class LanguageDetectionRequest {
  final String text;

  LanguageDetectionRequest({
    required this.text,
  });

  factory LanguageDetectionRequest.fromJson(Map<String, dynamic> json) =>
      _$LanguageDetectionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LanguageDetectionRequestToJson(this);
}

/// Response model for language detection
@JsonSerializable()
class LanguageDetectionResponse {
  final String? detectedLanguage;
  final double? confidence;
  final String? error;

  LanguageDetectionResponse({
    this.detectedLanguage,
    this.confidence,
    this.error,
  });

  factory LanguageDetectionResponse.fromJson(Map<String, dynamic> json) =>
      _$LanguageDetectionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LanguageDetectionResponseToJson(this);
}

/// Nutrition vocabulary response
@JsonSerializable()
class NutritionVocabularyResponse {
  final Map<String, List<String>> vocabulary;
  final int totalWords;
  final List<String> categories;

  NutritionVocabularyResponse({
    required this.vocabulary,
    required this.totalWords,
    required this.categories,
  });

  factory NutritionVocabularyResponse.fromJson(Map<String, dynamic> json) =>
      _$NutritionVocabularyResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionVocabularyResponseToJson(this);
}
/// Request model for Dialogflow intent detection
@JsonSerializable()
class DialogflowRequest {
  final String text;
  final String sessionId;
  final String? languageCode;
  final Map<String, dynamic>? context;

  DialogflowRequest({
    required this.text,
    required this.sessionId,
    this.languageCode,
    this.context,
  });

  factory DialogflowRequest.fromJson(Map<String, dynamic> json) =>
      _$DialogflowRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DialogflowRequestToJson(this);
}

/// Response model for Dialogflow intent detection
@JsonSerializable()
class DialogflowResponse {
  final String sessionId;
  final String intentName;
  final String responseText;
  final Map<String, dynamic> parameters;
  final double confidence;
  final String? fulfillmentText;
  final String? error;

  DialogflowResponse({
    required this.sessionId,
    required this.intentName,
    required this.responseText,
    required this.parameters,
    required this.confidence,
    this.fulfillmentText,
    this.error,
  });

  factory DialogflowResponse.fromJson(Map<String, dynamic> json) =>
      _$DialogflowResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DialogflowResponseToJson(this);
}

/// Model for conversation context management
@JsonSerializable()
class ConversationContext {
  final String name;
  final int lifespanCount;
  final Map<String, dynamic> parameters;

  ConversationContext({
    required this.name,
    required this.lifespanCount,
    required this.parameters,
  });

  factory ConversationContext.fromJson(Map<String, dynamic> json) =>
      _$ConversationContextFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationContextToJson(this);
}

/// Enhanced voice processing request with Dialogflow integration
@JsonSerializable()
class EnhancedVoiceProcessingRequest {
  final String audioContent;
  final String? userId;
  final String? sessionId;
  final String? languageCode;
  final Map<String, dynamic>? context;
  final bool? useDialogflow;

  EnhancedVoiceProcessingRequest({
    required this.audioContent,
    this.userId,
    this.sessionId,
    this.languageCode,
    this.context,
    this.useDialogflow,
  });

  factory EnhancedVoiceProcessingRequest.fromJson(Map<String, dynamic> json) =>
      _$EnhancedVoiceProcessingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EnhancedVoiceProcessingRequestToJson(this);
}

/// Enhanced voice processing response with Dialogflow integration
@JsonSerializable()
class EnhancedVoiceProcessingResponse {
  final String transcription;
  final String response;
  final String? audioResponse;
  final String? detectedLanguage;
  final double confidence;
  final String? intentName;
  final Map<String, dynamic>? intentParameters;
  final ConversationContext? conversationContext;
  final String? error;
  final Map<String, dynamic>? metadata;

  EnhancedVoiceProcessingResponse({
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

  factory EnhancedVoiceProcessingResponse.fromJson(Map<String, dynamic> json) =>
      _$EnhancedVoiceProcessingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EnhancedVoiceProcessingResponseToJson(this);
}
/// Request model for text translation
@JsonSerializable()
class TranslationRequest {
  final String text;
  final String targetLanguage;
  final String? sourceLanguage;

  TranslationRequest({
    required this.text,
    required this.targetLanguage,
    this.sourceLanguage,
  });

  factory TranslationRequest.fromJson(Map<String, dynamic> json) =>
      _$TranslationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationRequestToJson(this);
}

/// Response model for text translation
@JsonSerializable()
class TranslationResponse {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final String? error;

  TranslationResponse({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    this.error,
  });

  factory TranslationResponse.fromJson(Map<String, dynamic> json) =>
      _$TranslationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationResponseToJson(this);
}

/// Request model for nutrition data translation
@JsonSerializable()
class NutritionTranslationRequest {
  final Map<String, dynamic> nutritionData;
  final String targetLanguage;
  final String? sourceLanguage;

  NutritionTranslationRequest({
    required this.nutritionData,
    required this.targetLanguage,
    this.sourceLanguage,
  });

  factory NutritionTranslationRequest.fromJson(Map<String, dynamic> json) =>
      _$NutritionTranslationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionTranslationRequestToJson(this);
}

/// Response model for nutrition data translation
@JsonSerializable()
class NutritionTranslationResponse {
  final Map<String, dynamic> translatedData;
  final String sourceLanguage;
  final String targetLanguage;
  final String? error;

  NutritionTranslationResponse({
    required this.translatedData,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.error,
  });

  factory NutritionTranslationResponse.fromJson(Map<String, dynamic> json) =>
      _$NutritionTranslationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionTranslationResponseToJson(this);
}

/// Supported language model
@JsonSerializable()
class SupportedLanguage {
  final String languageCode;
  final String? displayName;

  SupportedLanguage({
    required this.languageCode,
    this.displayName,
  });

  factory SupportedLanguage.fromJson(Map<String, dynamic> json) =>
      _$SupportedLanguageFromJson(json);

  Map<String, dynamic> toJson() => _$SupportedLanguageToJson(this);
}

/// Response model for supported languages
@JsonSerializable()
class SupportedLanguagesResponse {
  final List<SupportedLanguage> languages;
  final String? error;

  SupportedLanguagesResponse({
    required this.languages,
    this.error,
  });

  factory SupportedLanguagesResponse.fromJson(Map<String, dynamic> json) =>
      _$SupportedLanguagesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SupportedLanguagesResponseToJson(this);
}