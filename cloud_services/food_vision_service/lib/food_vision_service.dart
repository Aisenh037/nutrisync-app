import 'dart:convert';
import 'package:logging/logging.dart';
import 'models/food_models.dart';
import 'services/gcp_vision_service.dart';
import 'services/nutrition_database_service.dart';
import 'config/service_config.dart';

/// Main service class for food vision recognition
class FoodVisionService {
  static FoodVisionService? _instance;
  static FoodVisionService get instance => _instance ??= FoodVisionService._();
  
  FoodVisionService._();
  
  final _logger = Logger('FoodVisionService');
  bool _initialized = false;
  
  /// Initialize the food vision service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _logger.info('Initializing Food Vision Service...');
      
      // Initialize configuration
      await ServiceConfig.instance.initialize();
      
      // Initialize GCP Vision service
      await GCPVisionService.instance.initialize();
      
      // Initialize nutrition database service
      await NutritionDatabaseService.instance.initialize();
      
      _initialized = true;
      _logger.info('Food Vision Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Food Vision Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Analyze food image and return nutrition information with confidence scoring
  Future<FoodAnalysisResponse> analyzeFoodImage(FoodAnalysisRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Analyzing food image for user: ${request.userId}');
      
      // Use GCP Vision API to analyze the image
      final visionResult = await GCPVisionService.instance.analyzeFoodImage(request);
      
      // If no food detected, return early with helpful suggestions
      if (!visionResult.isFood || visionResult.detectedFoods.isEmpty) {
        return _enhanceNonFoodResponse(visionResult);
      }
      
      // Enhance nutrition information for detected foods
      final enhancedFoods = <DetectedFood>[];
      
      for (final food in visionResult.detectedFoods) {
        try {
          // Look up more accurate nutrition information
          final nutritionRequest = NutritionLookupRequest(
            foodName: food.name,
            portionGrams: food.portionEstimate.estimatedGrams,
            portionDescription: food.portionEstimate.portionSize,
          );
          
          final nutritionResult = await NutritionDatabaseService.instance.lookupNutrition(nutritionRequest);
          
          // Create enhanced food item with better nutrition data and confidence assessment
          final enhancedFood = DetectedFood(
            name: food.name,
            category: food.category,
            confidence: _calculateEnhancedConfidence(food, nutritionResult),
            portionEstimate: food.portionEstimate,
            nutritionInfo: nutritionResult.nutritionInfo,
            boundingBox: food.boundingBox,
            alternativeNames: food.alternativeNames,
          );
          
          enhancedFoods.add(enhancedFood);
        } catch (e) {
          _logger.warning('Failed to enhance nutrition for ${food.name}: $e');
          // Keep original food data if enhancement fails
          enhancedFoods.add(food);
        }
      }
      
      // Sort by confidence and apply confidence-based filtering
      enhancedFoods.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      // Calculate enhanced overall confidence
      final enhancedOverallConfidence = _calculateOverallConfidence(enhancedFoods);
      
      return FoodAnalysisResponse(
        detectedFoods: enhancedFoods,
        isFood: visionResult.isFood,
        overallConfidence: enhancedOverallConfidence,
        metadata: {
          ...visionResult.metadata ?? {},
          'enhanced_nutrition': true,
          'confidence_enhanced': true,
          'processing_time': DateTime.now().toIso8601String(),
          'requires_confirmation': enhancedOverallConfidence < 0.8,
          'high_confidence_foods': enhancedFoods.where((f) => f.confidence >= 0.8).length,
          'low_confidence_foods': enhancedFoods.where((f) => f.confidence < 0.6).length,
        },
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Food image analysis failed: $e', e, stackTrace);
      return FoodAnalysisResponse(
        detectedFoods: [],
        isFood: false,
        overallConfidence: 0.0,
        error: 'Food analysis failed: $e',
      );
    }
  }
  
  /// Enhance non-food response with helpful suggestions
  FoodAnalysisResponse _enhanceNonFoodResponse(FoodAnalysisResponse originalResponse) {
    final suggestions = <String>[];
    
    if (originalResponse.metadata != null) {
      final detectedLabels = originalResponse.metadata!['detected_labels'] as List<dynamic>? ?? [];
      
      // Provide specific suggestions based on what was detected
      if (detectedLabels.any((label) => label.toString().toLowerCase().contains('person'))) {
        suggestions.add('Try taking a photo without people in the frame');
      }
      if (detectedLabels.any((label) => label.toString().toLowerCase().contains('text'))) {
        suggestions.add('Focus on the food rather than menus or packaging');
      }
      if (detectedLabels.any((label) => label.toString().toLowerCase().contains('table'))) {
        suggestions.add('Get closer to the food items for better recognition');
      }
      if (detectedLabels.isEmpty) {
        suggestions.add('Ensure good lighting and focus on the food');
      }
    }
    
    // Default suggestions
    if (suggestions.isEmpty) {
      suggestions.addAll([
        'Make sure the food is clearly visible and well-lit',
        'Try taking the photo from directly above the food',
        'Ensure the food takes up most of the image frame',
      ]);
    }
    
    return FoodAnalysisResponse(
      detectedFoods: originalResponse.detectedFoods,
      isFood: originalResponse.isFood,
      overallConfidence: originalResponse.overallConfidence,
      error: originalResponse.error,
      metadata: {
        ...originalResponse.metadata ?? {},
        'suggestions': suggestions,
        'user_guidance': 'No food detected in image',
      },
    );
  }
  
  /// Calculate enhanced confidence score combining vision and nutrition data
  double _calculateEnhancedConfidence(DetectedFood food, NutritionLookupResponse nutritionResult) {
    double baseConfidence = food.confidence;
    
    // Boost confidence if nutrition data was found with high confidence
    if (nutritionResult.confidence > 0.8) {
      baseConfidence = (baseConfidence + nutritionResult.confidence) / 2;
    }
    
    // Reduce confidence if nutrition lookup failed
    if (nutritionResult.error != null) {
      baseConfidence *= 0.8;
    }
    
    // Boost confidence for foods with bounding boxes (more precise detection)
    if (food.boundingBox != null) {
      baseConfidence = (baseConfidence + 0.1).clamp(0.0, 1.0);
    }
    
    return baseConfidence;
  }
  
  /// Calculate overall confidence for multiple detected foods
  double _calculateOverallConfidence(List<DetectedFood> foods) {
    if (foods.isEmpty) return 0.0;
    
    // Use weighted average where higher confidence foods have more weight
    double totalWeight = 0.0;
    double weightedSum = 0.0;
    
    for (final food in foods) {
      final weight = food.confidence;
      totalWeight += weight;
      weightedSum += food.confidence * weight;
    }
    
    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }
  
  /// Analyze food image with user confirmation flow
  Future<FoodAnalysisWithConfirmationResponse> analyzeFoodImageWithConfirmation(
    FoodAnalysisRequest request,
  ) async {
    try {
      // First, perform standard analysis
      final analysisResult = await analyzeFoodImage(request);
      
      // Determine if confirmation is needed
      final needsConfirmation = _determineConfirmationNeeds(analysisResult);
      
      return FoodAnalysisWithConfirmationResponse(
        analysisResult: analysisResult,
        needsConfirmation: needsConfirmation,
        confirmationPrompts: _generateConfirmationPrompts(analysisResult),
        suggestedActions: _generateSuggestedActions(analysisResult),
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Food analysis with confirmation failed: $e', e, stackTrace);
      return FoodAnalysisWithConfirmationResponse(
        analysisResult: FoodAnalysisResponse(
          detectedFoods: [],
          isFood: false,
          overallConfidence: 0.0,
          error: 'Analysis failed: $e',
        ),
        needsConfirmation: false,
        confirmationPrompts: [],
        suggestedActions: ['Please try taking another photo'],
      );
    }
  }
  
  /// Determine if user confirmation is needed based on analysis results
  bool _determineConfirmationNeeds(FoodAnalysisResponse analysis) {
    // No confirmation needed if no food detected
    if (!analysis.isFood || analysis.detectedFoods.isEmpty) {
      return false;
    }
    
    // Confirmation needed if overall confidence is low
    if (analysis.overallConfidence < 0.7) {
      return true;
    }
    
    // Confirmation needed if any detected food has very low confidence
    if (analysis.detectedFoods.any((food) => food.confidence < 0.5)) {
      return true;
    }
    
    // Confirmation needed if multiple foods detected with mixed confidence
    if (analysis.detectedFoods.length > 1) {
      final confidenceRange = analysis.detectedFoods.map((f) => f.confidence).reduce((a, b) => a > b ? a : b) -
                             analysis.detectedFoods.map((f) => f.confidence).reduce((a, b) => a < b ? a : b);
      if (confidenceRange > 0.3) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Generate confirmation prompts for uncertain detections
  List<String> _generateConfirmationPrompts(FoodAnalysisResponse analysis) {
    final prompts = <String>[];
    
    if (!analysis.isFood || analysis.detectedFoods.isEmpty) {
      return prompts;
    }
    
    for (final food in analysis.detectedFoods) {
      if (food.confidence < 0.7) {
        prompts.add('Is this ${food.name}? (Confidence: ${(food.confidence * 100).toStringAsFixed(0)}%)');
      }
    }
    
    if (analysis.detectedFoods.length > 1) {
      prompts.add('Did we detect all the food items correctly?');
    }
    
    return prompts;
  }
  
  /// Generate suggested actions based on analysis results
  List<String> _generateSuggestedActions(FoodAnalysisResponse analysis) {
    final actions = <String>[];
    
    if (!analysis.isFood) {
      actions.addAll([
        'Take a clearer photo of food items',
        'Ensure good lighting',
        'Focus on the food rather than the background',
      ]);
      return actions;
    }
    
    if (analysis.overallConfidence < 0.6) {
      actions.addAll([
        'Retake the photo with better lighting',
        'Move closer to the food',
        'Manually enter the food name if recognition fails',
      ]);
    } else if (analysis.overallConfidence < 0.8) {
      actions.addAll([
        'Confirm the detected food items',
        'Correct any misidentified foods',
      ]);
    } else {
      actions.add('Proceed with the detected nutrition information');
    }
    
    return actions;
  }
  
  /// Look up nutrition information for a specific food
  Future<NutritionLookupResponse> lookupNutrition(NutritionLookupRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Looking up nutrition for: ${request.foodName}');
      
      return await NutritionDatabaseService.instance.lookupNutrition(request);
      
    } catch (e, stackTrace) {
      _logger.severe('Nutrition lookup failed: $e', e, stackTrace);
      return NutritionLookupResponse(
        nutritionInfo: NutritionInfo(
          calories: 0,
          protein: 0,
          carbohydrates: 0,
          fat: 0,
          fiber: 0,
          sugar: 0,
          sodium: 0,
          source: 'error',
        ),
        matchedFoods: [],
        confidence: 0.0,
        error: 'Nutrition lookup failed: $e',
      );
    }
  }
  
  /// Search for food items in the database
  Future<List<String>> searchFoodItems(String query, {int limit = 10}) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Searching for food items: $query');
      
      return await NutritionDatabaseService.instance.searchFoodItems(query, limit: limit);
      
    } catch (e, stackTrace) {
      _logger.severe('Food search failed: $e', e, stackTrace);
      return [];
    }
  }
  
  /// Validate food confidence with user feedback
  Future<FoodConfidenceResponse> validateFoodConfidence(FoodConfidenceRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Validating food confidence for: ${request.foodName}');
      
      if (request.userConfirmed) {
        // User confirmed the detection
        return FoodConfidenceResponse(
          accepted: true,
          finalFoodName: request.foodName,
          updatedConfidence: 1.0,
          message: 'Food identification confirmed by user',
        );
      } else if (request.userCorrection != null) {
        // User provided a correction
        final correctedName = request.userCorrection!;
        
        // Validate the corrected name exists in database
        final searchResults = await searchFoodItems(correctedName, limit: 1);
        
        if (searchResults.isNotEmpty) {
          return FoodConfidenceResponse(
            accepted: true,
            finalFoodName: correctedName,
            updatedConfidence: 0.9,
            message: 'Food identification corrected by user',
          );
        } else {
          return FoodConfidenceResponse(
            accepted: false,
            finalFoodName: request.foodName,
            updatedConfidence: 0.3,
            message: 'Corrected food name not found in database',
          );
        }
      } else {
        // User rejected the detection
        return FoodConfidenceResponse(
          accepted: false,
          finalFoodName: request.foodName,
          updatedConfidence: 0.1,
          message: 'Food identification rejected by user',
        );
      }
      
    } catch (e, stackTrace) {
      _logger.severe('Food confidence validation failed: $e', e, stackTrace);
      return FoodConfidenceResponse(
        accepted: false,
        finalFoodName: request.foodName,
        updatedConfidence: 0.0,
        message: 'Validation failed: $e',
      );
    }
  }
  
  /// Get service health status
  Map<String, dynamic> getHealthStatus() {
    return {
      'service': 'FoodVisionService',
      'initialized': _initialized,
      'timestamp': DateTime.now().toIso8601String(),
      'config': ServiceConfig.instance.getHealthInfo(),
    };
  }
  
  /// Analyze non-food image and provide guidance
  Future<NonFoodImageAnalysisResponse> analyzeNonFoodImage(FoodAnalysisRequest request) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Analyzing non-food image for user: ${request.userId}');
      
      return await GCPVisionService.instance.analyzeNonFoodImage(request);
      
    } catch (e, stackTrace) {
      _logger.severe('Non-food image analysis failed: $e', e, stackTrace);
      return NonFoodImageAnalysisResponse(
        detectedObjects: [],
        detectedLabels: [],
        imageCategory: 'error',
        suggestions: ['Analysis failed. Please try taking another photo'],
        confidence: 0.0,
        error: 'Non-food analysis failed: $e',
      );
    }
  }
  Future<List<FoodAnalysisResponse>> analyzeFoodImagesBatch(List<FoodAnalysisRequest> requests) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      _logger.info('Processing batch of ${requests.length} food images');
      
      final results = <FoodAnalysisResponse>[];
      
      // Process images concurrently (with limit to avoid overwhelming the API)
      const batchSize = 3;
      for (int i = 0; i < requests.length; i += batchSize) {
        final batch = requests.skip(i).take(batchSize).toList();
        final batchResults = await Future.wait(
          batch.map((request) => analyzeFoodImage(request)),
        );
        results.addAll(batchResults);
      }
      
      return results;
      
    } catch (e, stackTrace) {
      _logger.severe('Batch food analysis failed: $e', e, stackTrace);
      return requests.map((request) => FoodAnalysisResponse(
        detectedFoods: [],
        isFood: false,
        overallConfidence: 0.0,
        error: 'Batch analysis failed: $e',
      )).toList();
    }
  }
}