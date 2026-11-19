// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpeechToTextRequest _$SpeechToTextRequestFromJson(Map<String, dynamic> json) =>
    SpeechToTextRequest(
      audioContent: json['audioContent'] as String,
      languageCode: json['languageCode'] as String?,
      model: json['model'] as String?,
      useEnhanced: json['useEnhanced'] as bool?,
      maxAlternatives: (json['maxAlternatives'] as num?)?.toInt(),
      enableAutomaticPunctuation: json['enableAutomaticPunctuation'] as bool?,
      enableWordTimeOffsets: json['enableWordTimeOffsets'] as bool?,
      enableWordConfidence: json['enableWordConfidence'] as bool?,
      speechContexts: (json['speechContexts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SpeechToTextRequestToJson(
        SpeechToTextRequest instance) =>
    <String, dynamic>{
      'audioContent': instance.audioContent,
      'languageCode': instance.languageCode,
      'model': instance.model,
      'useEnhanced': instance.useEnhanced,
      'maxAlternatives': instance.maxAlternatives,
      'enableAutomaticPunctuation': instance.enableAutomaticPunctuation,
      'enableWordTimeOffsets': instance.enableWordTimeOffsets,
      'enableWordConfidence': instance.enableWordConfidence,
      'speechContexts': instance.speechContexts,
    };

SpeechToTextResponse _$SpeechToTextResponseFromJson(
        Map<String, dynamic> json) =>
    SpeechToTextResponse(
      results: (json['results'] as List<dynamic>)
          .map((e) =>
              SpeechRecognitionResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      languageCode: json['languageCode'] as String?,
    );

Map<String, dynamic> _$SpeechToTextResponseToJson(
        SpeechToTextResponse instance) =>
    <String, dynamic>{
      'results': instance.results,
      'error': instance.error,
      'confidence': instance.confidence,
      'languageCode': instance.languageCode,
    };

SpeechRecognitionResult _$SpeechRecognitionResultFromJson(
        Map<String, dynamic> json) =>
    SpeechRecognitionResult(
      alternatives: (json['alternatives'] as List<dynamic>)
          .map((e) =>
              SpeechRecognitionAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
      languageCode: json['languageCode'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SpeechRecognitionResultToJson(
        SpeechRecognitionResult instance) =>
    <String, dynamic>{
      'alternatives': instance.alternatives,
      'languageCode': instance.languageCode,
      'confidence': instance.confidence,
    };

SpeechRecognitionAlternative _$SpeechRecognitionAlternativeFromJson(
        Map<String, dynamic> json) =>
    SpeechRecognitionAlternative(
      transcript: json['transcript'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      words: (json['words'] as List<dynamic>?)
          ?.map((e) => WordInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SpeechRecognitionAlternativeToJson(
        SpeechRecognitionAlternative instance) =>
    <String, dynamic>{
      'transcript': instance.transcript,
      'confidence': instance.confidence,
      'words': instance.words,
    };

WordInfo _$WordInfoFromJson(Map<String, dynamic> json) => WordInfo(
      word: json['word'] as String,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$WordInfoToJson(WordInfo instance) => <String, dynamic>{
      'word': instance.word,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'confidence': instance.confidence,
    };

TextToSpeechRequest _$TextToSpeechRequestFromJson(Map<String, dynamic> json) =>
    TextToSpeechRequest(
      text: json['text'] as String,
      languageCode: json['languageCode'] as String?,
      voiceName: json['voiceName'] as String?,
      audioEncoding: json['audioEncoding'] as String?,
      speakingRate: (json['speakingRate'] as num?)?.toDouble(),
      pitch: (json['pitch'] as num?)?.toDouble(),
      volumeGainDb: (json['volumeGainDb'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TextToSpeechRequestToJson(
        TextToSpeechRequest instance) =>
    <String, dynamic>{
      'text': instance.text,
      'languageCode': instance.languageCode,
      'voiceName': instance.voiceName,
      'audioEncoding': instance.audioEncoding,
      'speakingRate': instance.speakingRate,
      'pitch': instance.pitch,
      'volumeGainDb': instance.volumeGainDb,
    };

TextToSpeechResponse _$TextToSpeechResponseFromJson(
        Map<String, dynamic> json) =>
    TextToSpeechResponse(
      audioContent: json['audioContent'] as String?,
      error: json['error'] as String?,
      audioEncoding: json['audioEncoding'] as String?,
      audioLength: (json['audioLength'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TextToSpeechResponseToJson(
        TextToSpeechResponse instance) =>
    <String, dynamic>{
      'audioContent': instance.audioContent,
      'error': instance.error,
      'audioEncoding': instance.audioEncoding,
      'audioLength': instance.audioLength,
    };

VoiceProcessingRequest _$VoiceProcessingRequestFromJson(
        Map<String, dynamic> json) =>
    VoiceProcessingRequest(
      audioContent: json['audioContent'] as String,
      userId: json['userId'] as String?,
      sessionId: json['sessionId'] as String?,
      languageCode: json['languageCode'] as String?,
      context: json['context'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$VoiceProcessingRequestToJson(
        VoiceProcessingRequest instance) =>
    <String, dynamic>{
      'audioContent': instance.audioContent,
      'userId': instance.userId,
      'sessionId': instance.sessionId,
      'languageCode': instance.languageCode,
      'context': instance.context,
    };

VoiceProcessingResponse _$VoiceProcessingResponseFromJson(
        Map<String, dynamic> json) =>
    VoiceProcessingResponse(
      transcription: json['transcription'] as String?,
      response: json['response'] as String?,
      audioResponse: json['audioResponse'] as String?,
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$VoiceProcessingResponseToJson(
        VoiceProcessingResponse instance) =>
    <String, dynamic>{
      'transcription': instance.transcription,
      'response': instance.response,
      'audioResponse': instance.audioResponse,
      'detectedLanguage': instance.detectedLanguage,
      'confidence': instance.confidence,
      'error': instance.error,
      'metadata': instance.metadata,
    };

LanguageDetectionRequest _$LanguageDetectionRequestFromJson(
        Map<String, dynamic> json) =>
    LanguageDetectionRequest(
      text: json['text'] as String,
    );

Map<String, dynamic> _$LanguageDetectionRequestToJson(
        LanguageDetectionRequest instance) =>
    <String, dynamic>{
      'text': instance.text,
    };

LanguageDetectionResponse _$LanguageDetectionResponseFromJson(
        Map<String, dynamic> json) =>
    LanguageDetectionResponse(
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$LanguageDetectionResponseToJson(
        LanguageDetectionResponse instance) =>
    <String, dynamic>{
      'detectedLanguage': instance.detectedLanguage,
      'confidence': instance.confidence,
      'error': instance.error,
    };

NutritionVocabularyResponse _$NutritionVocabularyResponseFromJson(
        Map<String, dynamic> json) =>
    NutritionVocabularyResponse(
      vocabulary: (json['vocabulary'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      totalWords: (json['totalWords'] as num).toInt(),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$NutritionVocabularyResponseToJson(
        NutritionVocabularyResponse instance) =>
    <String, dynamic>{
      'vocabulary': instance.vocabulary,
      'totalWords': instance.totalWords,
      'categories': instance.categories,
    };

DialogflowRequest _$DialogflowRequestFromJson(Map<String, dynamic> json) =>
    DialogflowRequest(
      text: json['text'] as String,
      sessionId: json['sessionId'] as String,
      languageCode: json['languageCode'] as String?,
      context: json['context'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DialogflowRequestToJson(DialogflowRequest instance) =>
    <String, dynamic>{
      'text': instance.text,
      'sessionId': instance.sessionId,
      'languageCode': instance.languageCode,
      'context': instance.context,
    };

DialogflowResponse _$DialogflowResponseFromJson(Map<String, dynamic> json) =>
    DialogflowResponse(
      sessionId: json['sessionId'] as String,
      intentName: json['intentName'] as String,
      responseText: json['responseText'] as String,
      parameters: json['parameters'] as Map<String, dynamic>,
      confidence: (json['confidence'] as num).toDouble(),
      fulfillmentText: json['fulfillmentText'] as String?,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$DialogflowResponseToJson(DialogflowResponse instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'intentName': instance.intentName,
      'responseText': instance.responseText,
      'parameters': instance.parameters,
      'confidence': instance.confidence,
      'fulfillmentText': instance.fulfillmentText,
      'error': instance.error,
    };

ConversationContext _$ConversationContextFromJson(Map<String, dynamic> json) =>
    ConversationContext(
      name: json['name'] as String,
      lifespanCount: (json['lifespanCount'] as num).toInt(),
      parameters: json['parameters'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ConversationContextToJson(
        ConversationContext instance) =>
    <String, dynamic>{
      'name': instance.name,
      'lifespanCount': instance.lifespanCount,
      'parameters': instance.parameters,
    };

EnhancedVoiceProcessingRequest _$EnhancedVoiceProcessingRequestFromJson(
        Map<String, dynamic> json) =>
    EnhancedVoiceProcessingRequest(
      audioContent: json['audioContent'] as String,
      userId: json['userId'] as String?,
      sessionId: json['sessionId'] as String?,
      languageCode: json['languageCode'] as String?,
      context: json['context'] as Map<String, dynamic>?,
      useDialogflow: json['useDialogflow'] as bool?,
    );

Map<String, dynamic> _$EnhancedVoiceProcessingRequestToJson(
        EnhancedVoiceProcessingRequest instance) =>
    <String, dynamic>{
      'audioContent': instance.audioContent,
      'userId': instance.userId,
      'sessionId': instance.sessionId,
      'languageCode': instance.languageCode,
      'context': instance.context,
      'useDialogflow': instance.useDialogflow,
    };

EnhancedVoiceProcessingResponse _$EnhancedVoiceProcessingResponseFromJson(
        Map<String, dynamic> json) =>
    EnhancedVoiceProcessingResponse(
      transcription: json['transcription'] as String,
      response: json['response'] as String,
      audioResponse: json['audioResponse'] as String?,
      detectedLanguage: json['detectedLanguage'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      intentName: json['intentName'] as String?,
      intentParameters: json['intentParameters'] as Map<String, dynamic>?,
      conversationContext: json['conversationContext'] == null
          ? null
          : ConversationContext.fromJson(
              json['conversationContext'] as Map<String, dynamic>),
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$EnhancedVoiceProcessingResponseToJson(
        EnhancedVoiceProcessingResponse instance) =>
    <String, dynamic>{
      'transcription': instance.transcription,
      'response': instance.response,
      'audioResponse': instance.audioResponse,
      'detectedLanguage': instance.detectedLanguage,
      'confidence': instance.confidence,
      'intentName': instance.intentName,
      'intentParameters': instance.intentParameters,
      'conversationContext': instance.conversationContext,
      'error': instance.error,
      'metadata': instance.metadata,
    };

TranslationRequest _$TranslationRequestFromJson(Map<String, dynamic> json) =>
    TranslationRequest(
      text: json['text'] as String,
      targetLanguage: json['targetLanguage'] as String,
      sourceLanguage: json['sourceLanguage'] as String?,
    );

Map<String, dynamic> _$TranslationRequestToJson(TranslationRequest instance) =>
    <String, dynamic>{
      'text': instance.text,
      'targetLanguage': instance.targetLanguage,
      'sourceLanguage': instance.sourceLanguage,
    };

TranslationResponse _$TranslationResponseFromJson(Map<String, dynamic> json) =>
    TranslationResponse(
      translatedText: json['translatedText'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$TranslationResponseToJson(
        TranslationResponse instance) =>
    <String, dynamic>{
      'translatedText': instance.translatedText,
      'sourceLanguage': instance.sourceLanguage,
      'targetLanguage': instance.targetLanguage,
      'confidence': instance.confidence,
      'error': instance.error,
    };

NutritionTranslationRequest _$NutritionTranslationRequestFromJson(
        Map<String, dynamic> json) =>
    NutritionTranslationRequest(
      nutritionData: json['nutritionData'] as Map<String, dynamic>,
      targetLanguage: json['targetLanguage'] as String,
      sourceLanguage: json['sourceLanguage'] as String?,
    );

Map<String, dynamic> _$NutritionTranslationRequestToJson(
        NutritionTranslationRequest instance) =>
    <String, dynamic>{
      'nutritionData': instance.nutritionData,
      'targetLanguage': instance.targetLanguage,
      'sourceLanguage': instance.sourceLanguage,
    };

NutritionTranslationResponse _$NutritionTranslationResponseFromJson(
        Map<String, dynamic> json) =>
    NutritionTranslationResponse(
      translatedData: json['translatedData'] as Map<String, dynamic>,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$NutritionTranslationResponseToJson(
        NutritionTranslationResponse instance) =>
    <String, dynamic>{
      'translatedData': instance.translatedData,
      'sourceLanguage': instance.sourceLanguage,
      'targetLanguage': instance.targetLanguage,
      'error': instance.error,
    };

SupportedLanguage _$SupportedLanguageFromJson(Map<String, dynamic> json) =>
    SupportedLanguage(
      languageCode: json['languageCode'] as String,
      displayName: json['displayName'] as String?,
    );

Map<String, dynamic> _$SupportedLanguageToJson(SupportedLanguage instance) =>
    <String, dynamic>{
      'languageCode': instance.languageCode,
      'displayName': instance.displayName,
    };

SupportedLanguagesResponse _$SupportedLanguagesResponseFromJson(
        Map<String, dynamic> json) =>
    SupportedLanguagesResponse(
      languages: (json['languages'] as List<dynamic>)
          .map((e) => SupportedLanguage.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$SupportedLanguagesResponseToJson(
        SupportedLanguagesResponse instance) =>
    <String, dynamic>{
      'languages': instance.languages,
      'error': instance.error,
    };
