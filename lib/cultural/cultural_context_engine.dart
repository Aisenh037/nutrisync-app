import '../nutrition/meal_data_models.dart';

/// Cultural Context Engine for understanding Indian dietary patterns
/// Provides deep understanding of Indian food context, cooking methods, and portions
class CulturalContextEngine {

  // Common Indian cooking methods with their characteristics
  static const Map<String, CookingMethodInfo> _cookingMethods = {
    'tadka': CookingMethodInfo(
      name: 'tadka',
      description: 'Tempering with spices in hot oil/ghee',
      keywords: ['tadka', 'tempering', 'chaunk', 'baghar'],
      nutritionMultiplier: 1.1,
      commonSpices: ['cumin', 'mustard seeds', 'curry leaves', 'hing'],
    ),
    'bhuna': CookingMethodInfo(
      name: 'bhuna',
      description: 'Dry roasting/sautéing until moisture evaporates',
      keywords: ['bhuna', 'bhuno', 'dry roast', 'sauté'],
      nutritionMultiplier: 1.0,
      commonSpices: ['onion', 'ginger-garlic', 'tomato'],
    ),
    'dum': CookingMethodInfo(
      name: 'dum',
      description: 'Slow cooking in sealed pot with steam',
      keywords: ['dum', 'slow cooked', 'sealed pot', 'steam'],
      nutritionMultiplier: 1.2,
      commonSpices: ['whole spices', 'saffron', 'rose water'],
    ),
    'tawa': CookingMethodInfo(
      name: 'tawa',
      description: 'Cooked on flat griddle/pan',
      keywords: ['tawa', 'griddle', 'flat pan', 'roti'],
      nutritionMultiplier: 1.0,
      commonSpices: ['minimal oil', 'salt'],
    ),
    'tandoor': CookingMethodInfo(
      name: 'tandoor',
      description: 'Clay oven high-heat cooking',
      keywords: ['tandoor', 'clay oven', 'high heat', 'charred'],
      nutritionMultiplier: 0.9,
      commonSpices: ['yogurt marinade', 'garam masala'],
    ),
    'steamed': CookingMethodInfo(
      name: 'steamed',
      description: 'Cooked with steam without oil',
      keywords: ['steamed', 'steam', 'idli', 'dhokla'],
      nutritionMultiplier: 0.8,
      commonSpices: ['minimal spices', 'fermented'],
    ),
    'fried': CookingMethodInfo(
      name: 'fried',
      description: 'Deep fried in oil',
      keywords: ['fried', 'deep fried', 'tel mein', 'crispy'],
      nutritionMultiplier: 1.5,
      commonSpices: ['oil', 'salt', 'spices'],
    ),
  };

  // Indian measurement conversions to grams
  static const Map<String, double> _indianMeasurements = {
    'katori': 150.0,      // Small bowl
    'glass': 250.0,       // Standard glass
    'roti': 30.0,         // Medium roti
    'spoon': 15.0,        // Tablespoon
    'pinch': 1.0,         // Pinch of spice
    'handful': 50.0,      // Handful of nuts/dry fruits
    'cup': 200.0,         // Indian cup measurement
    'plate': 300.0,       // Standard plate serving
  };

  // Common Indian food combinations
  static const Map<String, List<String>> _foodCombinations = {
    'dal': ['rice', 'roti', 'chawal', 'chapati'],
    'sabzi': ['roti', 'paratha', 'rice'],
    'curry': ['rice', 'naan', 'roti', 'biryani'],
    'rice': ['dal', 'curry', 'sambar', 'rasam'],
    'roti': ['dal', 'sabzi', 'curry'],
    'idli': ['sambar', 'chutney', 'rasam'],
    'dosa': ['sambar', 'chutney', 'potato curry'],
    'biryani': ['raita', 'pickle', 'boiled egg'],
  };

  /// Identify cooking style from description
  CookingMethod identifyCookingStyle(String description) {
    final descLower = description.toLowerCase();
    
    // Check for cooking method keywords
    for (var entry in _cookingMethods.entries) {
      final methodInfo = entry.value;
      for (var keyword in methodInfo.keywords) {
        if (descLower.contains(keyword)) {
          return CookingMethod(
            name: methodInfo.name,
            description: methodInfo.description,
            nutritionMultiplier: methodInfo.nutritionMultiplier,
            commonIngredients: methodInfo.commonSpices,
          );
        }
      }
    }

    // Default to simple cooking if no specific method found
    return CookingMethod(
      name: 'simple',
      description: 'Basic cooking method',
      nutritionMultiplier: 1.0,
      commonIngredients: ['basic spices'],
    );
  }

  /// Estimate portion using Indian measurement units
  PortionSize estimateIndianPortion(String foodItem, String portionDesc) {
    final portionLower = portionDesc.toLowerCase().trim();
    
    // Extract quantity and unit from description
    final quantityMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(\w+)').firstMatch(portionLower);
    
    double quantity = 1.0;
    String unit = 'katori'; // default
    
    if (quantityMatch != null) {
      quantity = double.tryParse(quantityMatch.group(1) ?? '1') ?? 1.0;
      unit = quantityMatch.group(2) ?? 'katori';
    } else {
      // Try to identify unit without explicit quantity
      for (var measurementUnit in _indianMeasurements.keys) {
        if (portionLower.contains(measurementUnit)) {
          unit = measurementUnit;
          break;
        }
      }
    }

    // Convert to grams
    final gramsPerUnit = _indianMeasurements[unit] ?? 150.0;
    final totalGrams = quantity * gramsPerUnit;

    // Generate Indian reference
    String indianReference = _generateIndianReference(quantity, unit, foodItem);

    return PortionSize(
      quantity: totalGrams,
      unit: 'grams',
      indianReference: indianReference,
      confidenceScore: _calculateConfidenceScore(portionDesc, unit),
    );
  }

  /// Expand meal context with common combinations
  List<FoodItem> expandMealContext(FoodItem primaryFood) {
    final foodName = primaryFood.name.toLowerCase();
    final suggestions = <FoodItem>[];

    // Find the food category
    String? category;
    for (var cat in _foodCombinations.keys) {
      if (foodName.contains(cat)) {
        category = cat;
        break;
      }
    }

    if (category != null) {
      final combinations = _foodCombinations[category] ?? [];
      
      for (var combo in combinations) {
        // Create suggested food items
        suggestions.add(FoodItem(
          name: combo,
          quantity: _getDefaultQuantity(combo),
          unit: _getDefaultUnit(combo),
          nutrition: NutritionalInfo(
            calories: 0.0, // Will be filled when actual food is selected
            protein: 0.0,
            carbs: 0.0,
            fat: 0.0,
            fiber: 0.0,
            vitamins: {},
            minerals: {},
          ),
          context: CulturalContext(
            region: primaryFood.context.region,
            cookingMethod: 'traditional',
            mealType: primaryFood.context.mealType,
            commonCombinations: [primaryFood.name],
          ),
        ));
      }
    }

    return suggestions;
  }

  /// Get regional context for dishes
  RegionalVariation getRegionalContext(String location, String dish) {
    final locationLower = location.toLowerCase();

    // Regional cooking styles
    final Map<String, Map<String, dynamic>> regionalStyles = {
      'north': {
        'cookingStyle': 'rich_gravy',
        'commonIngredients': ['cream', 'butter', 'paneer', 'wheat'],
        'spiceLevel': 'medium',
      },
      'south': {
        'cookingStyle': 'coconut_based',
        'commonIngredients': ['coconut', 'curry leaves', 'tamarind', 'rice'],
        'spiceLevel': 'high',
      },
      'west': {
        'cookingStyle': 'sweet_savory',
        'commonIngredients': ['jaggery', 'peanuts', 'sesame', 'gram flour'],
        'spiceLevel': 'medium',
      },
      'east': {
        'cookingStyle': 'fish_rice',
        'commonIngredients': ['fish', 'rice', 'mustard oil', 'poppy seeds'],
        'spiceLevel': 'mild',
      },
    };

    // Determine region based on location
    String region = 'north'; // default
    if (locationLower.contains('south') || locationLower.contains('tamil') || 
        locationLower.contains('kerala') || locationLower.contains('karnataka') ||
        locationLower.contains('chennai') || locationLower.contains('bangalore') ||
        locationLower.contains('hyderabad')) {
      region = 'south';
    } else if (locationLower.contains('west') || locationLower.contains('gujarat') || 
               locationLower.contains('maharashtra') || locationLower.contains('mumbai') ||
               locationLower.contains('pune') || locationLower.contains('goa')) {
      region = 'west';
    } else if (locationLower.contains('east') || locationLower.contains('bengal') || 
               locationLower.contains('odisha') || locationLower.contains('kolkata') ||
               locationLower.contains('bhubaneswar')) {
      region = 'east';
    }

    final style = regionalStyles[region]!;
    
    return RegionalVariation(
      region: '${region.substring(0, 1).toUpperCase()}${region.substring(1)} India',
      dishName: dish,
      commonIngredients: List<String>.from(style['commonIngredients']),
      cookingStyle: CookingMethod(
        name: style['cookingStyle'],
        description: 'Regional ${region} Indian cooking style',
        nutritionMultiplier: 1.0,
        commonIngredients: List<String>.from(style['commonIngredients']),
      ),
      nutritionAdjustments: _getRegionalNutritionAdjustments(region),
    );
  }

  /// Recognize Indian cooking methods
  bool isIndianCookingMethod(String method) {
    final methodLower = method.toLowerCase();
    return _cookingMethods.keys.any((key) => 
      _cookingMethods[key]!.keywords.any((keyword) => 
        methodLower.contains(keyword)));
  }

  /// Convert Western units to Indian references
  String convertToIndianReference(double quantity, String unit, String foodType) {
    final unitLower = unit.toLowerCase();
    
    // Convert common Western units to Indian equivalents
    switch (unitLower) {
      case 'cup':
      case 'cups':
        if (foodType.contains('rice') || foodType.contains('dal')) {
          return '${(quantity * 1.5).toStringAsFixed(1)} katori';
        }
        return '${quantity.toStringAsFixed(1)} cup';
      
      case 'tablespoon':
      case 'tbsp':
        return '${quantity.toStringAsFixed(1)} spoon';
      
      case 'teaspoon':
      case 'tsp':
        return '${(quantity / 3).toStringAsFixed(1)} spoon';
      
      case 'ounce':
      case 'oz':
        final grams = quantity * 28.35;
        return _convertGramsToIndianReference(grams, foodType);
      
      case 'pound':
      case 'lb':
        final grams = quantity * 453.59;
        return _convertGramsToIndianReference(grams, foodType);
      
      default:
        return '$quantity $unit';
    }
  }

  /// Get cooking method information
  CookingMethodInfo? getCookingMethodInfo(String methodName) {
    return _cookingMethods[methodName.toLowerCase()];
  }

  /// Get all supported Indian measurements
  Map<String, double> getSupportedMeasurements() {
    return Map.from(_indianMeasurements);
  }

  /// Get food combinations for a category
  List<String> getFoodCombinations(String foodCategory) {
    return _foodCombinations[foodCategory.toLowerCase()] ?? [];
  }

  // Helper methods

  String _generateIndianReference(double quantity, String unit, String foodItem) {
    if (quantity == 1.0) {
      switch (unit) {
        case 'katori':
          return '1 katori (small bowl)';
        case 'glass':
          return '1 glass';
        case 'roti':
          return '1 roti';
        case 'plate':
          return '1 plate serving';
        default:
          return '1 $unit';
      }
    } else {
      return '${quantity.toStringAsFixed(1)} $unit';
    }
  }

  double _calculateConfidenceScore(String description, String identifiedUnit) {
    double score = 0.5; // base score
    
    // Higher confidence if explicit measurement mentioned
    if (description.contains(identifiedUnit)) {
      score += 0.3;
    }
    
    // Higher confidence if number is mentioned
    if (RegExp(r'\d+').hasMatch(description)) {
      score += 0.2;
    }
    
    return score.clamp(0.0, 1.0);
  }

  double _getDefaultQuantity(String foodName) {
    switch (foodName.toLowerCase()) {
      case 'rice':
      case 'dal':
        return 1.0; // 1 katori
      case 'roti':
      case 'chapati':
        return 2.0; // 2 rotis
      case 'sabzi':
        return 0.5; // half katori
      default:
        return 1.0;
    }
  }

  String _getDefaultUnit(String foodName) {
    switch (foodName.toLowerCase()) {
      case 'roti':
      case 'chapati':
        return 'roti';
      case 'rice':
      case 'dal':
      case 'sabzi':
        return 'katori';
      default:
        return 'katori';
    }
  }

  Map<String, double> _getRegionalNutritionAdjustments(String region) {
    switch (region) {
      case 'south':
        return {'fiber': 1.2, 'fat': 1.1}; // More coconut and vegetables
      case 'north':
        return {'fat': 1.3, 'protein': 1.1}; // More dairy and meat
      case 'west':
        return {'carbs': 1.2, 'fiber': 1.1}; // More grains and legumes
      case 'east':
        return {'protein': 1.2, 'fat': 1.1}; // More fish
      default:
        return {};
    }
  }

  String _convertGramsToIndianReference(double grams, String foodType) {
    if (foodType.contains('rice') || foodType.contains('dal')) {
      final katoris = grams / 150.0;
      return '${katoris.toStringAsFixed(1)} katori';
    } else if (foodType.contains('roti') || foodType.contains('bread')) {
      final rotis = grams / 30.0;
      return '${rotis.toStringAsFixed(0)} roti';
    } else {
      return '${grams.toStringAsFixed(0)}g';
    }
  }
}

/// Represents Indian cooking methods
class CookingMethod {
  final String name;
  final String description;
  final double nutritionMultiplier;
  final List<String> commonIngredients;

  CookingMethod({
    required this.name,
    required this.description,
    required this.nutritionMultiplier,
    required this.commonIngredients,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'nutritionMultiplier': nutritionMultiplier,
      'commonIngredients': commonIngredients,
    };
  }

  factory CookingMethod.fromMap(Map<String, dynamic> map) {
    return CookingMethod(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      nutritionMultiplier: (map['nutritionMultiplier'] as num?)?.toDouble() ?? 1.0,
      commonIngredients: List<String>.from(map['commonIngredients'] ?? []),
    );
  }
}

/// Represents portion size in Indian context
class PortionSize {
  final double quantity;
  final String unit;
  final String indianReference;
  final double confidenceScore;

  PortionSize({
    required this.quantity,
    required this.unit,
    required this.indianReference,
    required this.confidenceScore,
  });
}

/// Regional variation of dishes
class RegionalVariation {
  final String region;
  final String dishName;
  final List<String> commonIngredients;
  final CookingMethod cookingStyle;
  final Map<String, double> nutritionAdjustments;

  RegionalVariation({
    required this.region,
    required this.dishName,
    required this.commonIngredients,
    required this.cookingStyle,
    required this.nutritionAdjustments,
  });

  Map<String, dynamic> toMap() {
    return {
      'region': region,
      'dishName': dishName,
      'commonIngredients': commonIngredients,
      'cookingStyle': cookingStyle.toMap(),
      'nutritionAdjustments': nutritionAdjustments,
    };
  }

  factory RegionalVariation.fromMap(Map<String, dynamic> map) {
    return RegionalVariation(
      region: map['region'] ?? '',
      dishName: map['dishName'] ?? '',
      commonIngredients: List<String>.from(map['commonIngredients'] ?? []),
      cookingStyle: CookingMethod.fromMap(map['cookingStyle'] ?? {}),
      nutritionAdjustments: Map<String, double>.from(map['nutritionAdjustments'] ?? {}),
    );
  }
}

/// Indian food categories
enum IndianFoodCategory {
  dal,
  sabzi,
  roti,
  rice,
  curry,
  snack,
  sweet,
  beverage,
}

/// Common Indian measurement units
enum IndianMeasurementUnit {
  katori,
  glass,
  roti,
  spoon,
  pinch,
  handful,
}

/// Information about cooking methods
class CookingMethodInfo {
  final String name;
  final String description;
  final List<String> keywords;
  final double nutritionMultiplier;
  final List<String> commonSpices;

  const CookingMethodInfo({
    required this.name,
    required this.description,
    required this.keywords,
    required this.nutritionMultiplier,
    required this.commonSpices,
  });
}