import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';
import '../models/food_models.dart';
import '../config/service_config.dart';

/// Service for GCP Vision API integration
class GCPVisionService {
  static GCPVisionService? _instance;
  static GCPVisionService get instance => _instance ??= GCPVisionService._();
  
  GCPVisionService._();
  
  final _logger = Logger('GCPVisionService');
  vision.VisionApi? _visionApi;
  
  /// Initialize the Vision API client
  Future<void> initialize() async {
    try {
      final credentials = await ServiceConfig.instance.getServiceAccountCredentials();
      final client = await clientViaServiceAccount(credentials, [vision.VisionApi.cloudPlatformScope]);
      _visionApi = vision.VisionApi(client);
      
      _logger.info('GCP Vision Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize GCP Vision Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Analyze food image using Vision API
  Future<FoodAnalysisResponse> analyzeFoodImage(FoodAnalysisRequest request) async {
    try {
      if (_visionApi == null) {
        throw Exception('Vision API not initialized');
      }
      
      final imageBytes = base64Decode(request.imageContent);
      
      // Create Vision API request
      final visionRequest = vision.BatchAnnotateImagesRequest()
        ..requests = [
          vision.AnnotateImageRequest()
            ..image = (vision.Image()..content = request.imageContent)
            ..features = [
              // Object localization for food detection
              vision.Feature()
                ..type = 'OBJECT_LOCALIZATION'
                ..maxResults = 20,
              // Label detection for food classification
              vision.Feature()
                ..type = 'LABEL_DETECTION'
                ..maxResults = 50,
              // Text detection for packaging/labels
              vision.Feature()
                ..type = 'TEXT_DETECTION'
                ..maxResults = 10,
            ]
        ];
      
      final response = await _visionApi!.images.annotate(visionRequest);
      
      if (response.responses == null || response.responses!.isEmpty) {
        return FoodAnalysisResponse(
          detectedFoods: [],
          isFood: false,
          overallConfidence: 0.0,
          error: 'No response from Vision API',
        );
      }
      
      final visionResponse = response.responses!.first;
      
      // Check for errors
      if (visionResponse.error != null) {
        return FoodAnalysisResponse(
          detectedFoods: [],
          isFood: false,
          overallConfidence: 0.0,
          error: 'Vision API error: ${visionResponse.error!.message}',
        );
      }
      
      // Process the response to detect food items
      return await _processFoodDetection(visionResponse, request.confidenceThreshold ?? 0.7);
      
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
  
  /// Process Vision API response to detect food items
  Future<FoodAnalysisResponse> _processFoodDetection(
    vision.AnnotateImageResponse visionResponse,
    double confidenceThreshold,
  ) async {
    final detectedFoods = <DetectedFood>[];
    bool isFood = false;
    double overallConfidence = 0.0;
    
    // Process object localization results
    final objects = visionResponse.localizedObjectAnnotations ?? [];
    final labels = visionResponse.labelAnnotations ?? [];
    
    // Check if image contains food
    final foodLabels = labels.where((label) => _isFoodLabel(label.description ?? '')).toList();
    isFood = foodLabels.isNotEmpty;
    
    if (!isFood) {
      return FoodAnalysisResponse(
        detectedFoods: [],
        isFood: false,
        overallConfidence: 0.0,
        metadata: {
          'detected_labels': labels.map((l) => l.description).toList(),
          'message': 'No food items detected in the image',
          'suggestion': 'Please take a clearer photo of food items',
        },
      );
    }
    
    // Process detected food objects with improved multi-food detection
    final processedObjects = <String, DetectedFood>{};
    
    for (final obj in objects) {
      final name = obj.name ?? '';
      final confidence = obj.score ?? 0.0;
      
      if (_isFoodObject(name) && confidence >= confidenceThreshold) {
        final boundingBox = obj.boundingPoly?.normalizedVertices != null
            ? _extractBoundingBox(obj.boundingPoly!.normalizedVertices!)
            : null;
        
        // Check for overlapping detections (same food item detected multiple times)
        final normalizedName = _normalizeFoodName(name);
        if (processedObjects.containsKey(normalizedName)) {
          // Keep the detection with higher confidence
          if (confidence > processedObjects[normalizedName]!.confidence) {
            processedObjects[normalizedName] = await _createDetectedFood(
              name, confidence, boundingBox, confidenceThreshold);
          }
        } else {
          processedObjects[normalizedName] = await _createDetectedFood(
            name, confidence, boundingBox, confidenceThreshold);
        }
      }
    }
    
    detectedFoods.addAll(processedObjects.values);
    
    // If no objects detected, try to infer from labels with improved logic
    if (detectedFoods.isEmpty && foodLabels.isNotEmpty) {
      final processedLabels = <String, DetectedFood>{};
      
      for (final label in foodLabels.take(5)) { // Increased from 3 to 5
        final name = label.description ?? '';
        final confidence = label.score ?? 0.0;
        
        if (confidence >= confidenceThreshold) {
          final normalizedName = _normalizeFoodName(name);
          
          // Avoid duplicate detections from labels
          if (!processedLabels.containsKey(normalizedName)) {
            processedLabels[normalizedName] = await _createDetectedFood(
              name, confidence, null, confidenceThreshold);
          }
        }
      }
      
      detectedFoods.addAll(processedLabels.values);
    }
    
    // Sort detected foods by confidence (highest first)
    detectedFoods.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Calculate overall confidence with improved algorithm
    if (detectedFoods.isNotEmpty) {
      // Weighted average based on confidence scores
      final totalWeight = detectedFoods.map((f) => f.confidence).reduce((a, b) => a + b);
      final weightedSum = detectedFoods.map((f) => f.confidence * f.confidence).reduce((a, b) => a + b);
      overallConfidence = weightedSum / totalWeight;
    }
    
    return FoodAnalysisResponse(
      detectedFoods: detectedFoods,
      isFood: isFood,
      overallConfidence: overallConfidence,
      metadata: {
        'total_objects': objects.length,
        'total_labels': labels.length,
        'food_labels': foodLabels.length,
        'unique_foods_detected': detectedFoods.length,
        'confidence_threshold': confidenceThreshold,
        'detection_method': detectedFoods.isNotEmpty ? 
          (objects.isNotEmpty ? 'object_detection' : 'label_detection') : 'none',
      },
    );
  }
  
  /// Create a detected food item with all necessary information
  Future<DetectedFood> _createDetectedFood(
    String name, 
    double confidence, 
    BoundingBox? boundingBox,
    double confidenceThreshold,
  ) async {
    // Estimate portion size based on bounding box
    final portionEstimate = _estimatePortionSize(name, boundingBox);
    
    // Get nutrition information
    final nutritionInfo = await _getNutritionInfo(name, portionEstimate.estimatedGrams);
    
    return DetectedFood(
      name: _normalizeFoodName(name),
      category: _getFoodCategory(name),
      confidence: confidence,
      portionEstimate: portionEstimate,
      nutritionInfo: nutritionInfo,
      boundingBox: boundingBox,
      alternativeNames: _getAlternativeNames(name),
    );
  }
  
  /// Check if a label indicates food
  bool _isFoodLabel(String label) {
    final foodKeywords = [
      'food', 'dish', 'meal', 'cuisine', 'ingredient', 'fruit', 'vegetable',
      'meat', 'dairy', 'bread', 'rice', 'pasta', 'salad', 'soup', 'dessert',
      'snack', 'beverage', 'drink', 'breakfast', 'lunch', 'dinner',
      // Indian food terms
      'dal', 'curry', 'roti', 'naan', 'biryani', 'samosa', 'dosa', 'idli',
      'sabzi', 'paneer', 'masala', 'tandoori', 'pulao', 'kheer',
      // Additional food terms
      'pizza', 'burger', 'sandwich', 'cake', 'cookie', 'pie', 'taco',
      'sushi', 'noodle', 'cereal', 'yogurt', 'cheese', 'egg', 'fish',
      'chicken', 'beef', 'pork', 'lamb', 'turkey', 'seafood',
    ];
    
    final nonFoodKeywords = [
      'person', 'people', 'human', 'face', 'hand', 'finger',
      'car', 'vehicle', 'building', 'house', 'room', 'furniture',
      'phone', 'computer', 'screen', 'television', 'book', 'paper',
      'clothing', 'shirt', 'pants', 'shoe', 'bag', 'wallet',
      'animal', 'dog', 'cat', 'bird', 'plant', 'flower', 'tree',
      'sky', 'cloud', 'mountain', 'water', 'ocean', 'river',
      'tool', 'machine', 'equipment', 'device', 'instrument',
    ];
    
    final lowerLabel = label.toLowerCase();
    
    // Check for explicit non-food items first
    if (nonFoodKeywords.any((keyword) => lowerLabel.contains(keyword))) {
      return false;
    }
    
    // Then check for food items
    return foodKeywords.any((keyword) => lowerLabel.contains(keyword));
  }
  
  /// Check if an object name indicates food
  bool _isFoodObject(String objectName) {
    final foodObjects = [
      'food', 'fruit', 'vegetable', 'meat', 'fish', 'bread', 'cake',
      'pizza', 'burger', 'sandwich', 'salad', 'soup', 'pasta', 'rice',
      'apple', 'banana', 'orange', 'tomato', 'carrot', 'potato',
      'chicken', 'beef', 'pork', 'egg', 'cheese', 'milk', 'yogurt',
      'cookie', 'pie', 'taco', 'sushi', 'noodle', 'cereal',
    ];
    
    final nonFoodObjects = [
      'person', 'car', 'building', 'phone', 'computer', 'book',
      'clothing', 'animal', 'plant', 'tool', 'furniture', 'vehicle',
    ];
    
    final lowerObjectName = objectName.toLowerCase();
    
    // Check for explicit non-food objects first
    if (nonFoodObjects.any((obj) => lowerObjectName.contains(obj))) {
      return false;
    }
    
    // Then check for food objects
    return foodObjects.any((food) => lowerObjectName.contains(food));
  }
  
  /// Extract bounding box from normalized vertices
  BoundingBox? _extractBoundingBox(List<vision.NormalizedVertex> vertices) {
    if (vertices.length < 2) return null;
    
    final xs = vertices.map((v) => v.x ?? 0.0).toList();
    final ys = vertices.map((v) => v.y ?? 0.0).toList();
    
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    
    return BoundingBox(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }
  
  /// Estimate portion size based on food name and bounding box
  PortionEstimate _estimatePortionSize(String foodName, BoundingBox? boundingBox) {
    // Simple portion estimation logic
    // In a real implementation, this would use more sophisticated algorithms
    
    double estimatedGrams = 100.0; // Default portion
    String portionSize = '1 serving';
    double confidence = 0.6;
    String method = 'default_estimation';
    
    if (boundingBox != null) {
      // Estimate based on bounding box size
      final area = boundingBox.width * boundingBox.height;
      
      if (area > 0.3) {
        estimatedGrams = 200.0;
        portionSize = '1 large serving';
        confidence = 0.7;
      } else if (area > 0.1) {
        estimatedGrams = 150.0;
        portionSize = '1 medium serving';
        confidence = 0.8;
      } else {
        estimatedGrams = 75.0;
        portionSize = '1 small serving';
        confidence = 0.7;
      }
      
      method = 'visual_estimation';
    }
    
    // Adjust based on food type
    final normalizedName = foodName.toLowerCase();
    if (normalizedName.contains('apple') || normalizedName.contains('orange')) {
      estimatedGrams = 150.0;
      portionSize = '1 medium fruit';
      confidence = 0.8;
    } else if (normalizedName.contains('rice') || normalizedName.contains('pasta')) {
      estimatedGrams = 200.0;
      portionSize = '1 cup cooked';
      confidence = 0.7;
    } else if (normalizedName.contains('bread') || normalizedName.contains('roti')) {
      estimatedGrams = 30.0;
      portionSize = '1 slice/piece';
      confidence = 0.8;
    }
    
    return PortionEstimate(
      estimatedGrams: estimatedGrams,
      portionSize: portionSize,
      confidence: confidence,
      method: method,
    );
  }
  
  /// Get nutrition information for a food item
  Future<NutritionInfo> _getNutritionInfo(String foodName, double grams) async {
    // This would integrate with USDA database or other nutrition APIs
    // For now, returning sample data based on common foods
    
    final normalizedName = foodName.toLowerCase();
    
    // Sample nutrition data (per 100g, then scaled to actual portion)
    Map<String, Map<String, double>> nutritionDatabase = {
      'apple': {
        'calories': 52, 'protein': 0.3, 'carbohydrates': 14, 'fat': 0.2,
        'fiber': 2.4, 'sugar': 10, 'sodium': 1,
      },
      'banana': {
        'calories': 89, 'protein': 1.1, 'carbohydrates': 23, 'fat': 0.3,
        'fiber': 2.6, 'sugar': 12, 'sodium': 1,
      },
      'rice': {
        'calories': 130, 'protein': 2.7, 'carbohydrates': 28, 'fat': 0.3,
        'fiber': 0.4, 'sugar': 0.1, 'sodium': 5,
      },
      'chicken': {
        'calories': 165, 'protein': 31, 'carbohydrates': 0, 'fat': 3.6,
        'fiber': 0, 'sugar': 0, 'sodium': 74,
      },
      'bread': {
        'calories': 265, 'protein': 9, 'carbohydrates': 49, 'fat': 3.2,
        'fiber': 2.7, 'sugar': 5, 'sodium': 491,
      },
    };
    
    // Find matching nutrition data
    Map<String, double> baseNutrition = {'calories': 100, 'protein': 2, 'carbohydrates': 20, 'fat': 1, 'fiber': 1, 'sugar': 5, 'sodium': 10};
    
    for (final food in nutritionDatabase.keys) {
      if (normalizedName.contains(food)) {
        baseNutrition = nutritionDatabase[food]!;
        break;
      }
    }
    
    // Scale nutrition values based on portion size
    final scaleFactor = grams / 100.0;
    
    return NutritionInfo(
      calories: baseNutrition['calories']! * scaleFactor,
      protein: baseNutrition['protein']! * scaleFactor,
      carbohydrates: baseNutrition['carbohydrates']! * scaleFactor,
      fat: baseNutrition['fat']! * scaleFactor,
      fiber: baseNutrition['fiber']! * scaleFactor,
      sugar: baseNutrition['sugar']! * scaleFactor,
      sodium: baseNutrition['sodium']! * scaleFactor,
      vitamins: {
        'vitamin_c': normalizedName.contains('fruit') ? 10.0 * scaleFactor : 0.0,
        'vitamin_a': normalizedName.contains('carrot') ? 835.0 * scaleFactor : 0.0,
      },
      minerals: {
        'iron': normalizedName.contains('meat') ? 2.7 * scaleFactor : 0.5 * scaleFactor,
        'calcium': normalizedName.contains('dairy') ? 113.0 * scaleFactor : 10.0 * scaleFactor,
      },
      source: 'sample_database',
    );
  }
  
  /// Normalize food name for consistency
  String _normalizeFoodName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }
  
  /// Get food category
  String _getFoodCategory(String name) {
    final normalizedName = name.toLowerCase();
    
    if (normalizedName.contains('fruit') || ['apple', 'banana', 'orange', 'grape'].any((f) => normalizedName.contains(f))) {
      return 'Fruits';
    } else if (normalizedName.contains('vegetable') || ['carrot', 'tomato', 'potato', 'onion'].any((v) => normalizedName.contains(v))) {
      return 'Vegetables';
    } else if (['chicken', 'beef', 'pork', 'fish', 'meat'].any((m) => normalizedName.contains(m))) {
      return 'Protein';
    } else if (['rice', 'bread', 'pasta', 'noodle'].any((g) => normalizedName.contains(g))) {
      return 'Grains';
    } else if (['milk', 'cheese', 'yogurt', 'dairy'].any((d) => normalizedName.contains(d))) {
      return 'Dairy';
    } else {
      return 'Other';
    }
  }
  
  /// Analyze non-food image and provide helpful guidance
  Future<NonFoodImageAnalysisResponse> analyzeNonFoodImage(FoodAnalysisRequest request) async {
    try {
      if (_visionApi == null) {
        throw Exception('Vision API not initialized');
      }
      
      final imageBytes = base64Decode(request.imageContent);
      
      // Create Vision API request for general object detection
      final visionRequest = vision.BatchAnnotateImagesRequest()
        ..requests = [
          vision.AnnotateImageRequest()
            ..image = (vision.Image()..content = request.imageContent)
            ..features = [
              // Object localization
              vision.Feature()
                ..type = 'OBJECT_LOCALIZATION'
                ..maxResults = 20,
              // Label detection
              vision.Feature()
                ..type = 'LABEL_DETECTION'
                ..maxResults = 50,
              // Text detection for menus, packaging, etc.
              vision.Feature()
                ..type = 'TEXT_DETECTION'
                ..maxResults = 10,
            ]
        ];
      
      final response = await _visionApi!.images.annotate(visionRequest);
      
      if (response.responses == null || response.responses!.isEmpty) {
        return NonFoodImageAnalysisResponse(
          detectedObjects: [],
          detectedLabels: [],
          imageCategory: 'unknown',
          suggestions: ['Please try taking another photo with better lighting'],
          confidence: 0.0,
        );
      }
      
      final visionResponse = response.responses!.first;
      
      if (visionResponse.error != null) {
        return NonFoodImageAnalysisResponse(
          detectedObjects: [],
          detectedLabels: [],
          imageCategory: 'error',
          suggestions: ['Image analysis failed. Please try a different photo'],
          confidence: 0.0,
          error: 'Vision API error: ${visionResponse.error!.message}',
        );
      }
      
      // Process the response
      final objects = visionResponse.localizedObjectAnnotations ?? [];
      final labels = visionResponse.labelAnnotations ?? [];
      
      final detectedObjects = objects.map((obj) => obj.name ?? '').where((name) => name.isNotEmpty).toList();
      final detectedLabels = labels.map((label) => label.description ?? '').where((desc) => desc.isNotEmpty).toList();
      
      // Determine image category and provide specific suggestions
      final categoryAnalysis = _analyzeImageCategory(detectedObjects, detectedLabels);
      
      return NonFoodImageAnalysisResponse(
        detectedObjects: detectedObjects,
        detectedLabels: detectedLabels,
        imageCategory: categoryAnalysis.category,
        suggestions: categoryAnalysis.suggestions,
        confidence: categoryAnalysis.confidence,
      );
      
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
  
  /// Analyze image category and provide specific suggestions
  ImageCategoryAnalysis _analyzeImageCategory(List<String> objects, List<String> labels) {
    final allItems = [...objects, ...labels].map((item) => item.toLowerCase()).toList();
    
    // Check for specific categories
    if (allItems.any((item) => ['person', 'people', 'human', 'face', 'hand'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'person',
        suggestions: [
          'Try taking a photo without people in the frame',
          'Focus on the food items only',
          'Ask someone else to take the photo for you',
        ],
        confidence: 0.9,
      );
    }
    
    if (allItems.any((item) => ['menu', 'text', 'document', 'paper', 'book'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'menu_or_text',
        suggestions: [
          'Take a photo of the actual food, not the menu',
          'Focus on your plate or food items',
          'Avoid photos with too much text or packaging',
        ],
        confidence: 0.8,
      );
    }
    
    if (allItems.any((item) => ['table', 'furniture', 'room', 'kitchen', 'restaurant'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'environment',
        suggestions: [
          'Get closer to the food items',
          'Fill the frame with the food rather than the surroundings',
          'Try taking the photo from directly above the food',
        ],
        confidence: 0.7,
      );
    }
    
    if (allItems.any((item) => ['animal', 'dog', 'cat', 'pet', 'bird'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'animal',
        suggestions: [
          'This appears to be a photo of an animal',
          'Please take a photo of food items instead',
          'Make sure your pet is not in the frame',
        ],
        confidence: 0.9,
      );
    }
    
    if (allItems.any((item) => ['car', 'vehicle', 'building', 'house', 'street'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'outdoor_or_vehicle',
        suggestions: [
          'This appears to be an outdoor or vehicle photo',
          'Please take a photo of food items',
          'Try taking the photo indoors with good lighting',
        ],
        confidence: 0.8,
      );
    }
    
    if (allItems.any((item) => ['phone', 'computer', 'screen', 'device', 'electronics'].any((keyword) => item.contains(keyword)))) {
      return ImageCategoryAnalysis(
        category: 'electronics',
        suggestions: [
          'This appears to be a photo of electronic devices',
          'Please take a photo of food items instead',
          'Make sure no screens or devices are in the frame',
        ],
        confidence: 0.8,
      );
    }
    
    // Check for blurry or unclear images
    if (allItems.isEmpty || allItems.length < 3) {
      return ImageCategoryAnalysis(
        category: 'unclear',
        suggestions: [
          'The image appears to be unclear or blurry',
          'Try taking the photo with better lighting',
          'Make sure the camera is focused on the food',
          'Clean the camera lens if necessary',
        ],
        confidence: 0.6,
      );
    }
    
    // Default case - unrecognized content
    return ImageCategoryAnalysis(
      category: 'unrecognized',
      suggestions: [
        'No food items were detected in this image',
        'Make sure the food is clearly visible and well-lit',
        'Try taking the photo from a different angle',
        'Ensure the food takes up most of the image frame',
      ],
      confidence: 0.5,
    );
  }
  List<String> _getAlternativeNames(String name) {
    final normalizedName = name.toLowerCase();
    
    final alternatives = <String, List<String>>{
      'apple': ['seb', 'सेब'],
      'banana': ['kela', 'केला'],
      'rice': ['chawal', 'चावल', 'bhat'],
      'bread': ['roti', 'रोटी', 'chapati'],
      'chicken': ['murgi', 'मुर्गी'],
      'potato': ['aloo', 'आलू'],
      'tomato': ['tamatar', 'टमाटर'],
    };
    
    for (final entry in alternatives.entries) {
      if (normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return [];
  }
}