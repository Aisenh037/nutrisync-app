import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../config/gcp_config.dart';
import '../services/gcp_auth_service.dart';
import '../services/performance_service.dart';

/// Flutter service for food vision AI integration
class FoodVisionAIService {
  static FoodVisionAIService? _instance;
  static FoodVisionAIService get instance => _instance ??= FoodVisionAIService._();
  
  FoodVisionAIService._();
  
  final _logger = Logger('FoodVisionAIService');
  String? _serviceUrl;
  
  /// Initialize the food vision AI service
  Future<void> initialize() async {
    try {
      await GCPConfig.instance.initialize();
      await GCPAuthService.instance.initialize();
      
      // Get the Cloud Run service URL from environment or config
      _serviceUrl = _getServiceUrl();
      
      _logger.info('Food Vision AI Service initialized');
      _logger.info('Service URL: $_serviceUrl');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Food Vision AI Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Analyze food image and get nutrition information
  Future<FoodAnalysisResult> analyzeFoodImage(
    Uint8List imageData, {
    String? userId,
    Map<String, dynamic>? context,
    double? confidenceThreshold,
  }) async {
    return PerformanceService.traceAsync(PerformanceService.kFoodVisionScan, () async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }

      final imageContent = base64Encode(imageData);
      
      final requestBody = {
        'imageContent': imageContent,
        'userId': userId,
        'context': context,
        'confidenceThreshold': confidenceThreshold ?? 0.7,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/analyze-food',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return FoodAnalysisResult.fromJson(responseData);
      } else {
        throw Exception('Food analysis failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Food image analysis failed: $e', e, stackTrace);
      return FoodAnalysisResult(
        detectedFoods: [],
        isFood: false,
        overallConfidence: 0.0,
        error: 'Food analysis failed: $e',
      );
    }
    }); // end traceAsync
  }

  /// Analyze food image with confirmation flow
  Future<FoodAnalysisWithConfirmationResult> analyzeFoodImageWithConfirmation(
    Uint8List imageData, {
    String? userId,
    Map<String, dynamic>? context,
    double? confidenceThreshold,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final imageContent = base64Encode(imageData);
      
      final requestBody = {
        'imageContent': imageContent,
        'userId': userId,
        'context': context,
        'confidenceThreshold': confidenceThreshold ?? 0.7,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/analyze-food-with-confirmation',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return FoodAnalysisWithConfirmationResult.fromJson(responseData);
      } else {
        throw Exception('Food analysis with confirmation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Food image analysis with confirmation failed: $e', e, stackTrace);
      return FoodAnalysisWithConfirmationResult(
        analysisResult: FoodAnalysisResult(
          detectedFoods: [],
          isFood: false,
          overallConfidence: 0.0,
          error: 'Analysis with confirmation failed: $e',
        ),
        needsConfirmation: false,
        confirmationPrompts: [],
        suggestedActions: ['Please try taking another photo'],
      );
    }
  }
  
  /// Analyze multiple food images in batch
  Future<List<FoodAnalysisResult>> analyzeFoodImagesBatch(
    List<Uint8List> imageDataList, {
    String? userId,
    Map<String, dynamic>? context,
    double? confidenceThreshold,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requests = imageDataList.map((imageData) => {
        'imageContent': base64Encode(imageData),
        'userId': userId,
        'context': context,
        'confidenceThreshold': confidenceThreshold ?? 0.7,
      }).toList();
      
      final requestBody = {
        'requests': requests,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/analyze-food-batch',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final results = responseData['results'] as List<dynamic>;
        
        return results
            .map((result) => FoodAnalysisResult.fromJson(result as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Batch food analysis failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Batch food image analysis failed: $e', e, stackTrace);
      return imageDataList.map((imageData) => FoodAnalysisResult(
        detectedFoods: [],
        isFood: false,
        overallConfidence: 0.0,
        error: 'Batch analysis failed: $e',
      )).toList();
    }
  }
  
  /// Look up nutrition information for a specific food
  Future<NutritionLookupResult> lookupNutrition(
    String foodName, {
    double? portionGrams,
    String? portionDescription,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'foodName': foodName,
        'portionGrams': portionGrams,
        'portionDescription': portionDescription,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/lookup-nutrition',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return NutritionLookupResult.fromJson(responseData);
      } else {
        throw Exception('Nutrition lookup failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Nutrition lookup failed: $e', e, stackTrace);
      return NutritionLookupResult(
        nutritionInfo: NutritionData(
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
  Future<FoodSearchResult> searchFoodItems(String query, {int limit = 10}) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/search-foods?query=${Uri.encodeComponent(query)}&limit=$limit',
        null,
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return FoodSearchResult.fromJson(responseData);
      } else {
        throw Exception('Food search failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Food search failed: $e', e, stackTrace);
      return FoodSearchResult(
        query: query,
        results: [],
        count: 0,
        error: 'Food search failed: $e',
      );
    }
  }
  
  /// Validate food confidence with user feedback
  Future<FoodConfidenceResult> validateFoodConfidence(
    String foodName,
    Uint8List imageData, {
    required bool userConfirmed,
    String? userCorrection,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final requestBody = {
        'foodName': foodName,
        'imageContent': base64Encode(imageData),
        'userConfirmed': userConfirmed,
        'userCorrection': userCorrection,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/validate-confidence',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return FoodConfidenceResult.fromJson(responseData);
      } else {
        throw Exception('Confidence validation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Food confidence validation failed: $e', e, stackTrace);
      return FoodConfidenceResult(
        accepted: false,
        finalFoodName: foodName,
        updatedConfidence: 0.0,
        message: 'Validation failed: $e',
      );
    }
  }
  
  /// Analyze non-food image and get guidance
  Future<NonFoodImageAnalysisResult> analyzeNonFoodImage(
    Uint8List imageData, {
    String? userId,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (_serviceUrl == null) {
        throw Exception('Service not initialized');
      }
      
      final imageContent = base64Encode(imageData);
      
      final requestBody = {
        'imageContent': imageContent,
        'userId': userId,
        'context': context,
      };
      
      final response = await _makeAuthenticatedRequest(
        '$_serviceUrl/analyze-non-food',
        requestBody,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return NonFoodImageAnalysisResult.fromJson(responseData);
      } else {
        throw Exception('Non-food analysis failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Non-food image analysis failed: $e', e, stackTrace);
      return NonFoodImageAnalysisResult(
        detectedObjects: [],
        detectedLabels: [],
        imageCategory: 'error',
        suggestions: ['Analysis failed. Please try taking another photo'],
        confidence: 0.0,
        error: 'Non-food analysis failed: $e',
      );
    }
  }
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
    return 'https://food-vision-service-${projectId.hashCode.abs()}-${region}.a.run.app';
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

/// Result classes for the food vision AI service

class FoodAnalysisResult {
  final List<DetectedFoodItem> detectedFoods;
  final bool isFood;
  final double overallConfidence;
  final String? error;
  final Map<String, dynamic>? metadata;

  FoodAnalysisResult({
    required this.detectedFoods,
    required this.isFood,
    required this.overallConfidence,
    this.error,
    this.metadata,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final detectedFoodsJson = json['detectedFoods'] as List<dynamic>? ?? [];
    final detectedFoods = detectedFoodsJson
        .map((food) => DetectedFoodItem.fromJson(food as Map<String, dynamic>))
        .toList();

    return FoodAnalysisResult(
      detectedFoods: detectedFoods,
      isFood: json['isFood'] as bool? ?? false,
      overallConfidence: (json['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class DetectedFoodItem {
  final String name;
  final String category;
  final double confidence;
  final PortionEstimateData portionEstimate;
  final NutritionData nutritionInfo;
  final BoundingBoxData? boundingBox;
  final List<String> alternativeNames;

  DetectedFoodItem({
    required this.name,
    required this.category,
    required this.confidence,
    required this.portionEstimate,
    required this.nutritionInfo,
    this.boundingBox,
    this.alternativeNames = const [],
  });

  factory DetectedFoodItem.fromJson(Map<String, dynamic> json) {
    return DetectedFoodItem(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      portionEstimate: PortionEstimateData.fromJson(json['portionEstimate'] as Map<String, dynamic>? ?? {}),
      nutritionInfo: NutritionData.fromJson(json['nutritionInfo'] as Map<String, dynamic>? ?? {}),
      boundingBox: json['boundingBox'] != null
          ? BoundingBoxData.fromJson(json['boundingBox'] as Map<String, dynamic>)
          : null,
      alternativeNames: (json['alternativeNames'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class PortionEstimateData {
  final double estimatedGrams;
  final String portionSize;
  final double confidence;
  final String method;

  PortionEstimateData({
    required this.estimatedGrams,
    required this.portionSize,
    required this.confidence,
    required this.method,
  });

  factory PortionEstimateData.fromJson(Map<String, dynamic> json) {
    return PortionEstimateData(
      estimatedGrams: (json['estimatedGrams'] as num?)?.toDouble() ?? 100.0,
      portionSize: json['portionSize'] as String? ?? '1 serving',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.6,
      method: json['method'] as String? ?? 'default_estimation',
    );
  }
}

class NutritionData {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final Map<String, double> vitamins;
  final Map<String, double> minerals;
  final String source;

  NutritionData({
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

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
      vitamins: (json['vitamins'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
      ) ?? {},
      minerals: (json['minerals'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
      ) ?? {},
      source: json['source'] as String? ?? 'unknown',
    );
  }
}

class BoundingBoxData {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBoxData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingBoxData.fromJson(Map<String, dynamic> json) {
    return BoundingBoxData(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NutritionLookupResult {
  final NutritionData nutritionInfo;
  final List<String> matchedFoods;
  final double confidence;
  final String? error;

  NutritionLookupResult({
    required this.nutritionInfo,
    required this.matchedFoods,
    required this.confidence,
    this.error,
  });

  factory NutritionLookupResult.fromJson(Map<String, dynamic> json) {
    return NutritionLookupResult(
      nutritionInfo: NutritionData.fromJson(json['nutritionInfo'] as Map<String, dynamic>? ?? {}),
      matchedFoods: (json['matchedFoods'] as List<dynamic>?)?.cast<String>() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}

class FoodSearchResult {
  final String query;
  final List<String> results;
  final int count;
  final String? error;

  FoodSearchResult({
    required this.query,
    required this.results,
    required this.count,
    this.error,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      query: json['query'] as String? ?? '',
      results: (json['results'] as List<dynamic>?)?.cast<String>() ?? [],
      count: json['count'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

class FoodConfidenceResult {
  final bool accepted;
  final String finalFoodName;
  final double updatedConfidence;
  final String? message;

  FoodConfidenceResult({
    required this.accepted,
    required this.finalFoodName,
    required this.updatedConfidence,
    this.message,
  });

  factory FoodConfidenceResult.fromJson(Map<String, dynamic> json) {
    return FoodConfidenceResult(
      accepted: json['accepted'] as bool? ?? false,
      finalFoodName: json['finalFoodName'] as String? ?? '',
      updatedConfidence: (json['updatedConfidence'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
    );
  }
}

class FoodAnalysisWithConfirmationResult {
  final FoodAnalysisResult analysisResult;
  final bool needsConfirmation;
  final List<String> confirmationPrompts;
  final List<String> suggestedActions;

  FoodAnalysisWithConfirmationResult({
    required this.analysisResult,
    required this.needsConfirmation,
    required this.confirmationPrompts,
    required this.suggestedActions,
  });

  factory FoodAnalysisWithConfirmationResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisWithConfirmationResult(
      analysisResult: FoodAnalysisResult.fromJson(json['analysisResult'] as Map<String, dynamic>? ?? {}),
      needsConfirmation: json['needsConfirmation'] as bool? ?? false,
      confirmationPrompts: (json['confirmationPrompts'] as List<dynamic>?)?.cast<String>() ?? [],
      suggestedActions: (json['suggestedActions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class NonFoodImageAnalysisResult {
  final List<String> detectedObjects;
  final List<String> detectedLabels;
  final String imageCategory;
  final List<String> suggestions;
  final double confidence;
  final String? error;

  NonFoodImageAnalysisResult({
    required this.detectedObjects,
    required this.detectedLabels,
    required this.imageCategory,
    required this.suggestions,
    required this.confidence,
    this.error,
  });

  factory NonFoodImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return NonFoodImageAnalysisResult(
      detectedObjects: (json['detectedObjects'] as List<dynamic>?)?.cast<String>() ?? [],
      detectedLabels: (json['detectedLabels'] as List<dynamic>?)?.cast<String>() ?? [],
      imageCategory: json['imageCategory'] as String? ?? 'unknown',
      suggestions: (json['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}