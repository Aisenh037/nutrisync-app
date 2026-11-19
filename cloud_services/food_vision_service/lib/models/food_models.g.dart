// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoodAnalysisRequest _$FoodAnalysisRequestFromJson(Map<String, dynamic> json) =>
    FoodAnalysisRequest(
      imageContent: json['imageContent'] as String,
      userId: json['userId'] as String?,
      context: json['context'] as Map<String, dynamic>?,
      confidenceThreshold:
          (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.7,
    );

Map<String, dynamic> _$FoodAnalysisRequestToJson(
        FoodAnalysisRequest instance) =>
    <String, dynamic>{
      'imageContent': instance.imageContent,
      'userId': instance.userId,
      'context': instance.context,
      'confidenceThreshold': instance.confidenceThreshold,
    };

FoodAnalysisResponse _$FoodAnalysisResponseFromJson(
        Map<String, dynamic> json) =>
    FoodAnalysisResponse(
      detectedFoods: (json['detectedFoods'] as List<dynamic>)
          .map((e) => DetectedFood.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFood: json['isFood'] as bool,
      overallConfidence: (json['overallConfidence'] as num).toDouble(),
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$FoodAnalysisResponseToJson(
        FoodAnalysisResponse instance) =>
    <String, dynamic>{
      'detectedFoods': instance.detectedFoods,
      'isFood': instance.isFood,
      'overallConfidence': instance.overallConfidence,
      'error': instance.error,
      'metadata': instance.metadata,
    };

DetectedFood _$DetectedFoodFromJson(Map<String, dynamic> json) => DetectedFood(
      name: json['name'] as String,
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      portionEstimate: PortionEstimate.fromJson(
          json['portionEstimate'] as Map<String, dynamic>),
      nutritionInfo:
          NutritionInfo.fromJson(json['nutritionInfo'] as Map<String, dynamic>),
      boundingBox: json['boundingBox'] == null
          ? null
          : BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>),
      alternativeNames: (json['alternativeNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DetectedFoodToJson(DetectedFood instance) =>
    <String, dynamic>{
      'name': instance.name,
      'category': instance.category,
      'confidence': instance.confidence,
      'portionEstimate': instance.portionEstimate,
      'nutritionInfo': instance.nutritionInfo,
      'boundingBox': instance.boundingBox,
      'alternativeNames': instance.alternativeNames,
    };

PortionEstimate _$PortionEstimateFromJson(Map<String, dynamic> json) =>
    PortionEstimate(
      estimatedGrams: (json['estimatedGrams'] as num).toDouble(),
      portionSize: json['portionSize'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      method: json['method'] as String,
    );

Map<String, dynamic> _$PortionEstimateToJson(PortionEstimate instance) =>
    <String, dynamic>{
      'estimatedGrams': instance.estimatedGrams,
      'portionSize': instance.portionSize,
      'confidence': instance.confidence,
      'method': instance.method,
    };

NutritionInfo _$NutritionInfoFromJson(Map<String, dynamic> json) =>
    NutritionInfo(
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbohydrates: (json['carbohydrates'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fiber: (json['fiber'] as num).toDouble(),
      sugar: (json['sugar'] as num).toDouble(),
      sodium: (json['sodium'] as num).toDouble(),
      vitamins: (json['vitamins'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          const {},
      minerals: (json['minerals'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          const {},
      source: json['source'] as String,
    );

Map<String, dynamic> _$NutritionInfoToJson(NutritionInfo instance) =>
    <String, dynamic>{
      'calories': instance.calories,
      'protein': instance.protein,
      'carbohydrates': instance.carbohydrates,
      'fat': instance.fat,
      'fiber': instance.fiber,
      'sugar': instance.sugar,
      'sodium': instance.sodium,
      'vitamins': instance.vitamins,
      'minerals': instance.minerals,
      'source': instance.source,
    };

BoundingBox _$BoundingBoxFromJson(Map<String, dynamic> json) => BoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );

Map<String, dynamic> _$BoundingBoxToJson(BoundingBox instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
    };

NutritionLookupRequest _$NutritionLookupRequestFromJson(
        Map<String, dynamic> json) =>
    NutritionLookupRequest(
      foodName: json['foodName'] as String,
      portionGrams: (json['portionGrams'] as num?)?.toDouble(),
      portionDescription: json['portionDescription'] as String?,
    );

Map<String, dynamic> _$NutritionLookupRequestToJson(
        NutritionLookupRequest instance) =>
    <String, dynamic>{
      'foodName': instance.foodName,
      'portionGrams': instance.portionGrams,
      'portionDescription': instance.portionDescription,
    };

NutritionLookupResponse _$NutritionLookupResponseFromJson(
        Map<String, dynamic> json) =>
    NutritionLookupResponse(
      nutritionInfo:
          NutritionInfo.fromJson(json['nutritionInfo'] as Map<String, dynamic>),
      matchedFoods: (json['matchedFoods'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$NutritionLookupResponseToJson(
        NutritionLookupResponse instance) =>
    <String, dynamic>{
      'nutritionInfo': instance.nutritionInfo,
      'matchedFoods': instance.matchedFoods,
      'confidence': instance.confidence,
      'error': instance.error,
    };

FoodConfidenceRequest _$FoodConfidenceRequestFromJson(
        Map<String, dynamic> json) =>
    FoodConfidenceRequest(
      foodName: json['foodName'] as String,
      imageContent: json['imageContent'] as String,
      userConfirmed: json['userConfirmed'] as bool,
      userCorrection: json['userCorrection'] as String?,
    );

Map<String, dynamic> _$FoodConfidenceRequestToJson(
        FoodConfidenceRequest instance) =>
    <String, dynamic>{
      'foodName': instance.foodName,
      'imageContent': instance.imageContent,
      'userConfirmed': instance.userConfirmed,
      'userCorrection': instance.userCorrection,
    };

FoodConfidenceResponse _$FoodConfidenceResponseFromJson(
        Map<String, dynamic> json) =>
    FoodConfidenceResponse(
      accepted: json['accepted'] as bool,
      finalFoodName: json['finalFoodName'] as String,
      updatedConfidence: (json['updatedConfidence'] as num).toDouble(),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$FoodConfidenceResponseToJson(
        FoodConfidenceResponse instance) =>
    <String, dynamic>{
      'accepted': instance.accepted,
      'finalFoodName': instance.finalFoodName,
      'updatedConfidence': instance.updatedConfidence,
      'message': instance.message,
    };

FoodAnalysisWithConfirmationResponse
    _$FoodAnalysisWithConfirmationResponseFromJson(Map<String, dynamic> json) =>
        FoodAnalysisWithConfirmationResponse(
          analysisResult: FoodAnalysisResponse.fromJson(
              json['analysisResult'] as Map<String, dynamic>),
          needsConfirmation: json['needsConfirmation'] as bool,
          confirmationPrompts: (json['confirmationPrompts'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
          suggestedActions: (json['suggestedActions'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
        );

Map<String, dynamic> _$FoodAnalysisWithConfirmationResponseToJson(
        FoodAnalysisWithConfirmationResponse instance) =>
    <String, dynamic>{
      'analysisResult': instance.analysisResult,
      'needsConfirmation': instance.needsConfirmation,
      'confirmationPrompts': instance.confirmationPrompts,
      'suggestedActions': instance.suggestedActions,
    };

NonFoodImageAnalysisResponse _$NonFoodImageAnalysisResponseFromJson(
        Map<String, dynamic> json) =>
    NonFoodImageAnalysisResponse(
      detectedObjects: (json['detectedObjects'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      detectedLabels: (json['detectedLabels'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      imageCategory: json['imageCategory'] as String,
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$NonFoodImageAnalysisResponseToJson(
        NonFoodImageAnalysisResponse instance) =>
    <String, dynamic>{
      'detectedObjects': instance.detectedObjects,
      'detectedLabels': instance.detectedLabels,
      'imageCategory': instance.imageCategory,
      'suggestions': instance.suggestions,
      'confidence': instance.confidence,
      'error': instance.error,
    };
