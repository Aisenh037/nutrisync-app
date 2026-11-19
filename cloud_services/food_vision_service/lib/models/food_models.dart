import 'package:json_annotation/json_annotation.dart';

part 'food_models.g.dart';

/// Request model for food image analysis
@JsonSerializable()
class FoodAnalysisRequest {
  final String imageContent; // Base64 encoded image
  final String? userId;
  final Map<String, dynamic>? context;
  final double? confidenceThreshold;

  FoodAnalysisRequest({
    required this.imageContent,
    this.userId,
    this.context,
    this.confidenceThreshold = 0.7,
  });

  factory FoodAnalysisRequest.fromJson(Map<String, dynamic> json) =>
      _$FoodAnalysisRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FoodAnalysisRequestToJson(this);
}

/// Response model for food image analysis
@JsonSerializable()
class FoodAnalysisResponse {
  final List<DetectedFood> detectedFoods;
  final bool isFood;
  final double overallConfidence;
  final String? error;
  final Map<String, dynamic>? metadata;

  FoodAnalysisResponse({
    required this.detectedFoods,
    required this.isFood,
    required this.overallConfidence,
    this.error,
    this.metadata,
  });

  factory FoodAnalysisResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodAnalysisResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FoodAnalysisResponseToJson(this);
}

/// Model for detected food item
@JsonSerializable()
class DetectedFood {
  final String name;
  final String category;
  final double confidence;
  final PortionEstimate portionEstimate;
  final NutritionInfo nutritionInfo;
  final BoundingBox? boundingBox;
  final List<String> alternativeNames;

  DetectedFood({
    required this.name,
    required this.category,
    required this.confidence,
    required this.portionEstimate,
    required this.nutritionInfo,
    this.boundingBox,
    this.alternativeNames = const [],
  });

  factory DetectedFood.fromJson(Map<String, dynamic> json) =>
      _$DetectedFoodFromJson(json);

  Map<String, dynamic> toJson() => _$DetectedFoodToJson(this);
}

/// Model for portion size estimation
@JsonSerializable()
class PortionEstimate {
  final double estimatedGrams;
  final String portionSize; // e.g., "1 cup", "1 medium apple"
  final double confidence;
  final String method; // e.g., "visual_estimation", "reference_object"

  PortionEstimate({
    required this.estimatedGrams,
    required this.portionSize,
    required this.confidence,
    required this.method,
  });

  factory PortionEstimate.fromJson(Map<String, dynamic> json) =>
      _$PortionEstimateFromJson(json);

  Map<String, dynamic> toJson() => _$PortionEstimateToJson(this);
}

/// Model for nutrition information
@JsonSerializable()
class NutritionInfo {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final Map<String, double> vitamins;
  final Map<String, double> minerals;
  final String source; // e.g., "USDA", "custom"

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    this.vitamins = const {},
    this.minerals = const {},
    required this.source,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) =>
      _$NutritionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionInfoToJson(this);
}

/// Model for bounding box coordinates
@JsonSerializable()
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) =>
      _$BoundingBoxFromJson(json);

  Map<String, dynamic> toJson() => _$BoundingBoxToJson(this);
}

/// Request model for nutrition lookup
@JsonSerializable()
class NutritionLookupRequest {
  final String foodName;
  final double? portionGrams;
  final String? portionDescription;

  NutritionLookupRequest({
    required this.foodName,
    this.portionGrams,
    this.portionDescription,
  });

  factory NutritionLookupRequest.fromJson(Map<String, dynamic> json) =>
      _$NutritionLookupRequestFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionLookupRequestToJson(this);
}

/// Response model for nutrition lookup
@JsonSerializable()
class NutritionLookupResponse {
  final NutritionInfo nutritionInfo;
  final List<String> matchedFoods;
  final double confidence;
  final String? error;

  NutritionLookupResponse({
    required this.nutritionInfo,
    required this.matchedFoods,
    required this.confidence,
    this.error,
  });

  factory NutritionLookupResponse.fromJson(Map<String, dynamic> json) =>
      _$NutritionLookupResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionLookupResponseToJson(this);
}

/// Model for food confidence validation
@JsonSerializable()
class FoodConfidenceRequest {
  final String foodName;
  final String imageContent; // Base64 encoded
  final bool userConfirmed;
  final String? userCorrection;

  FoodConfidenceRequest({
    required this.foodName,
    required this.imageContent,
    required this.userConfirmed,
    this.userCorrection,
  });

  factory FoodConfidenceRequest.fromJson(Map<String, dynamic> json) =>
      _$FoodConfidenceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FoodConfidenceRequestToJson(this);
}

/// Response model for food confidence validation
@JsonSerializable()
class FoodConfidenceResponse {
  final bool accepted;
  final String finalFoodName;
  final double updatedConfidence;
  final String? message;

  FoodConfidenceResponse({
    required this.accepted,
    required this.finalFoodName,
    required this.updatedConfidence,
    this.message,
  });

  factory FoodConfidenceResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodConfidenceResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FoodConfidenceResponseToJson(this);
}

/// Response model for food analysis with confirmation flow
@JsonSerializable()
class FoodAnalysisWithConfirmationResponse {
  final FoodAnalysisResponse analysisResult;
  final bool needsConfirmation;
  final List<String> confirmationPrompts;
  final List<String> suggestedActions;

  FoodAnalysisWithConfirmationResponse({
    required this.analysisResult,
    required this.needsConfirmation,
    required this.confirmationPrompts,
    required this.suggestedActions,
  });

  factory FoodAnalysisWithConfirmationResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodAnalysisWithConfirmationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FoodAnalysisWithConfirmationResponseToJson(this);
}

/// Response model for non-food image analysis
@JsonSerializable()
class NonFoodImageAnalysisResponse {
  final List<String> detectedObjects;
  final List<String> detectedLabels;
  final String imageCategory;
  final List<String> suggestions;
  final double confidence;
  final String? error;

  NonFoodImageAnalysisResponse({
    required this.detectedObjects,
    required this.detectedLabels,
    required this.imageCategory,
    required this.suggestions,
    required this.confidence,
    this.error,
  });

  factory NonFoodImageAnalysisResponse.fromJson(Map<String, dynamic> json) =>
      _$NonFoodImageAnalysisResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NonFoodImageAnalysisResponseToJson(this);
}

/// Helper class for image category analysis
class ImageCategoryAnalysis {
  final String category;
  final List<String> suggestions;
  final double confidence;

  ImageCategoryAnalysis({
    required this.category,
    required this.suggestions,
    required this.confidence,
  });
}