import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../models/food_models.dart';
import '../config/service_config.dart';

/// Service for nutrition database integration (USDA, custom databases)
class NutritionDatabaseService {
  static NutritionDatabaseService? _instance;
  static NutritionDatabaseService get instance => _instance ??= NutritionDatabaseService._();
  
  NutritionDatabaseService._();
  
  final _logger = Logger('NutritionDatabaseService');
  String? _usdaApiKey;
  
  /// Initialize the nutrition database service
  Future<void> initialize() async {
    try {
      _usdaApiKey = await ServiceConfig.instance.getUSDAApiKey();
      _logger.info('Nutrition Database Service initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Nutrition Database Service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Look up nutrition information for a food item
  Future<NutritionLookupResponse> lookupNutrition(NutritionLookupRequest request) async {
    try {
      // First try USDA database
      final usdaResult = await _lookupUSDANutrition(request.foodName);
      
      if (usdaResult != null) {
        // Scale nutrition values based on portion size
        final scaledNutrition = _scaleNutrition(usdaResult, request.portionGrams ?? 100.0);
        
        return NutritionLookupResponse(
          nutritionInfo: scaledNutrition,
          matchedFoods: [request.foodName],
          confidence: 0.9,
        );
      }
      
      // Fallback to local database
      final localResult = await _lookupLocalNutrition(request.foodName);
      
      if (localResult != null) {
        final scaledNutrition = _scaleNutrition(localResult, request.portionGrams ?? 100.0);
        
        return NutritionLookupResponse(
          nutritionInfo: scaledNutrition,
          matchedFoods: [request.foodName],
          confidence: 0.7,
        );
      }
      
      // Return default nutrition if no match found
      return NutritionLookupResponse(
        nutritionInfo: _getDefaultNutrition(request.portionGrams ?? 100.0),
        matchedFoods: [],
        confidence: 0.3,
        error: 'No nutrition data found for ${request.foodName}',
      );
      
    } catch (e, stackTrace) {
      _logger.severe('Nutrition lookup failed: $e', e, stackTrace);
      return NutritionLookupResponse(
        nutritionInfo: _getDefaultNutrition(request.portionGrams ?? 100.0),
        matchedFoods: [],
        confidence: 0.0,
        error: 'Nutrition lookup failed: $e',
      );
    }
  }
  
  /// Search for food items in the database
  Future<List<String>> searchFoodItems(String query, {int limit = 10}) async {
    try {
      // Search USDA database
      if (_usdaApiKey != null) {
        final usdaResults = await _searchUSDAFoods(query, limit);
        if (usdaResults.isNotEmpty) {
          return usdaResults;
        }
      }
      
      // Fallback to local search
      return _searchLocalFoods(query, limit);
      
    } catch (e, stackTrace) {
      _logger.severe('Food search failed: $e', e, stackTrace);
      return [];
    }
  }
  
  /// Look up nutrition data from USDA database
  Future<NutritionInfo?> _lookupUSDANutrition(String foodName) async {
    try {
      if (_usdaApiKey == null) {
        return null;
      }
      
      // USDA FoodData Central API
      final searchUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';
      final searchResponse = await http.get(
        Uri.parse('$searchUrl?query=${Uri.encodeComponent(foodName)}&api_key=$_usdaApiKey&pageSize=1'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (searchResponse.statusCode != 200) {
        return null;
      }
      
      final searchData = json.decode(searchResponse.body) as Map<String, dynamic>;
      final foods = searchData['foods'] as List<dynamic>?;
      
      if (foods == null || foods.isEmpty) {
        return null;
      }
      
      final foodId = foods.first['fdcId'] as int;
      
      // Get detailed nutrition data
      final detailUrl = 'https://api.nal.usda.gov/fdc/v1/food/$foodId';
      final detailResponse = await http.get(
        Uri.parse('$detailUrl?api_key=$_usdaApiKey'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (detailResponse.statusCode != 200) {
        return null;
      }
      
      final detailData = json.decode(detailResponse.body) as Map<String, dynamic>;
      return _parseUSDANutrition(detailData);
      
    } catch (e) {
      _logger.warning('USDA nutrition lookup failed: $e');
      return null;
    }
  }
  
  /// Parse USDA nutrition data
  NutritionInfo _parseUSDANutrition(Map<String, dynamic> usdaData) {
    final nutrients = usdaData['foodNutrients'] as List<dynamic>? ?? [];
    
    double calories = 0.0;
    double protein = 0.0;
    double carbohydrates = 0.0;
    double fat = 0.0;
    double fiber = 0.0;
    double sugar = 0.0;
    double sodium = 0.0;
    final vitamins = <String, double>{};
    final minerals = <String, double>{};
    
    for (final nutrient in nutrients) {
      final nutrientData = nutrient as Map<String, dynamic>;
      final nutrientInfo = nutrientData['nutrient'] as Map<String, dynamic>?;
      final amount = (nutrientData['amount'] as num?)?.toDouble() ?? 0.0;
      final unitName = nutrientInfo?['unitName'] as String? ?? '';
      final nutrientName = nutrientInfo?['name'] as String? ?? '';
      
      switch (nutrientName.toLowerCase()) {
        case 'energy':
          if (unitName.toLowerCase() == 'kcal') calories = amount;
          break;
        case 'protein':
          protein = amount;
          break;
        case 'carbohydrate, by difference':
          carbohydrates = amount;
          break;
        case 'total lipid (fat)':
          fat = amount;
          break;
        case 'fiber, total dietary':
          fiber = amount;
          break;
        case 'sugars, total including nlea':
          sugar = amount;
          break;
        case 'sodium, na':
          sodium = amount;
          break;
        case 'vitamin c, total ascorbic acid':
          vitamins['vitamin_c'] = amount;
          break;
        case 'vitamin a, rae':
          vitamins['vitamin_a'] = amount;
          break;
        case 'iron, fe':
          minerals['iron'] = amount;
          break;
        case 'calcium, ca':
          minerals['calcium'] = amount;
          break;
      }
    }
    
    return NutritionInfo(
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      vitamins: vitamins,
      minerals: minerals,
      source: 'USDA',
    );
  }
  
  /// Search USDA foods
  Future<List<String>> _searchUSDAFoods(String query, int limit) async {
    try {
      if (_usdaApiKey == null) {
        return [];
      }
      
      final searchUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';
      final response = await http.get(
        Uri.parse('$searchUrl?query=${Uri.encodeComponent(query)}&api_key=$_usdaApiKey&pageSize=$limit'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode != 200) {
        return [];
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final foods = data['foods'] as List<dynamic>? ?? [];
      
      return foods
          .map((food) => (food as Map<String, dynamic>)['description'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
    } catch (e) {
      _logger.warning('USDA food search failed: $e');
      return [];
    }
  }
  
  /// Look up nutrition data from local database
  Future<NutritionInfo?> _lookupLocalNutrition(String foodName) async {
    // Local nutrition database with common Indian and international foods
    final localDatabase = _getLocalNutritionDatabase();
    
    final normalizedName = foodName.toLowerCase().trim();
    
    // Direct match
    if (localDatabase.containsKey(normalizedName)) {
      return localDatabase[normalizedName];
    }
    
    // Partial match
    for (final entry in localDatabase.entries) {
      if (entry.key.contains(normalizedName) || normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }
  
  /// Search local foods
  List<String> _searchLocalFoods(String query, int limit) {
    final localDatabase = _getLocalNutritionDatabase();
    final normalizedQuery = query.toLowerCase().trim();
    
    final matches = localDatabase.keys
        .where((name) => name.contains(normalizedQuery) || normalizedQuery.contains(name))
        .take(limit)
        .toList();
    
    return matches;
  }
  
  /// Get local nutrition database
  Map<String, NutritionInfo> _getLocalNutritionDatabase() {
    return {
      // Fruits
      'apple': NutritionInfo(calories: 52, protein: 0.3, carbohydrates: 14, fat: 0.2, fiber: 2.4, sugar: 10, sodium: 1, source: 'local'),
      'banana': NutritionInfo(calories: 89, protein: 1.1, carbohydrates: 23, fat: 0.3, fiber: 2.6, sugar: 12, sodium: 1, source: 'local'),
      'orange': NutritionInfo(calories: 47, protein: 0.9, carbohydrates: 12, fat: 0.1, fiber: 2.4, sugar: 9, sodium: 0, source: 'local'),
      'mango': NutritionInfo(calories: 60, protein: 0.8, carbohydrates: 15, fat: 0.4, fiber: 1.6, sugar: 14, sodium: 1, source: 'local'),
      
      // Vegetables
      'potato': NutritionInfo(calories: 77, protein: 2, carbohydrates: 17, fat: 0.1, fiber: 2.2, sugar: 0.8, sodium: 6, source: 'local'),
      'tomato': NutritionInfo(calories: 18, protein: 0.9, carbohydrates: 3.9, fat: 0.2, fiber: 1.2, sugar: 2.6, sodium: 5, source: 'local'),
      'onion': NutritionInfo(calories: 40, protein: 1.1, carbohydrates: 9.3, fat: 0.1, fiber: 1.7, sugar: 4.2, sodium: 4, source: 'local'),
      'carrot': NutritionInfo(calories: 41, protein: 0.9, carbohydrates: 10, fat: 0.2, fiber: 2.8, sugar: 4.7, sodium: 69, source: 'local'),
      
      // Grains
      'rice': NutritionInfo(calories: 130, protein: 2.7, carbohydrates: 28, fat: 0.3, fiber: 0.4, sugar: 0.1, sodium: 5, source: 'local'),
      'wheat': NutritionInfo(calories: 340, protein: 13, carbohydrates: 72, fat: 2.5, fiber: 11, sugar: 0.4, sodium: 2, source: 'local'),
      'bread': NutritionInfo(calories: 265, protein: 9, carbohydrates: 49, fat: 3.2, fiber: 2.7, sugar: 5, sodium: 491, source: 'local'),
      'roti': NutritionInfo(calories: 297, protein: 11, carbohydrates: 61, fat: 1.2, fiber: 2.7, sugar: 2.6, sodium: 5, source: 'local'),
      
      // Proteins
      'chicken': NutritionInfo(calories: 165, protein: 31, carbohydrates: 0, fat: 3.6, fiber: 0, sugar: 0, sodium: 74, source: 'local'),
      'fish': NutritionInfo(calories: 206, protein: 22, carbohydrates: 0, fat: 12, fiber: 0, sugar: 0, sodium: 59, source: 'local'),
      'egg': NutritionInfo(calories: 155, protein: 13, carbohydrates: 1.1, fat: 11, fiber: 0, sugar: 1.1, sodium: 124, source: 'local'),
      'paneer': NutritionInfo(calories: 321, protein: 25, carbohydrates: 1.2, fat: 25, fiber: 0, sugar: 1.2, sodium: 18, source: 'local'),
      
      // Dairy
      'milk': NutritionInfo(calories: 42, protein: 3.4, carbohydrates: 5, fat: 1, fiber: 0, sugar: 5, sodium: 44, source: 'local'),
      'yogurt': NutritionInfo(calories: 59, protein: 10, carbohydrates: 3.6, fat: 0.4, fiber: 0, sugar: 3.2, sodium: 36, source: 'local'),
      'cheese': NutritionInfo(calories: 113, protein: 7, carbohydrates: 1, fat: 9, fiber: 0, sugar: 1, sodium: 215, source: 'local'),
      
      // Indian dishes
      'dal': NutritionInfo(calories: 116, protein: 9, carbohydrates: 20, fat: 0.4, fiber: 8, sugar: 1.5, sodium: 5, source: 'local'),
      'biryani': NutritionInfo(calories: 200, protein: 8, carbohydrates: 35, fat: 4, fiber: 2, sugar: 3, sodium: 400, source: 'local'),
      'samosa': NutritionInfo(calories: 308, protein: 6, carbohydrates: 28, fat: 19, fiber: 3, sugar: 2, sodium: 422, source: 'local'),
      'dosa': NutritionInfo(calories: 168, protein: 4, carbohydrates: 25, fat: 6, fiber: 1, sugar: 1, sodium: 178, source: 'local'),
    };
  }
  
  /// Scale nutrition values based on portion size
  NutritionInfo _scaleNutrition(NutritionInfo baseNutrition, double grams) {
    final scaleFactor = grams / 100.0; // Base nutrition is per 100g
    
    return NutritionInfo(
      calories: baseNutrition.calories * scaleFactor,
      protein: baseNutrition.protein * scaleFactor,
      carbohydrates: baseNutrition.carbohydrates * scaleFactor,
      fat: baseNutrition.fat * scaleFactor,
      fiber: baseNutrition.fiber * scaleFactor,
      sugar: baseNutrition.sugar * scaleFactor,
      sodium: baseNutrition.sodium * scaleFactor,
      vitamins: baseNutrition.vitamins.map((k, v) => MapEntry(k, v * scaleFactor)),
      minerals: baseNutrition.minerals.map((k, v) => MapEntry(k, v * scaleFactor)),
      source: baseNutrition.source,
    );
  }
  
  /// Get default nutrition values
  NutritionInfo _getDefaultNutrition(double grams) {
    final scaleFactor = grams / 100.0;
    
    return NutritionInfo(
      calories: 100 * scaleFactor,
      protein: 2 * scaleFactor,
      carbohydrates: 20 * scaleFactor,
      fat: 1 * scaleFactor,
      fiber: 1 * scaleFactor,
      sugar: 5 * scaleFactor,
      sodium: 10 * scaleFactor,
      source: 'default',
    );
  }
}