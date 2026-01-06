import 'package:cloud_firestore/cloud_firestore.dart';
import '../voice/hinglish_processor.dart';

/// Result of meal logging operation
class MealLogResult {
  final bool success;
  final String message;
  final MealData? mealData;
  final List<FoodAmbiguity> ambiguities;
  final double confidence;

  MealLogResult({
    required this.success,
    required this.message,
    this.mealData,
    required this.ambiguities,
    required this.confidence,
  });
}

/// Complete meal data with nutrition information
class MealData {
  final String mealId;
  final String userId;
  final DateTime timestamp;
  final MealType mealType;
  final List<DetailedFoodItem> foods;
  final NutritionalSummary nutrition;
  final String voiceDescription;
  final double confidenceScore;

  MealData({
    required this.mealId,
    required this.userId,
    required this.timestamp,
    required this.mealType,
    required this.foods,
    required this.nutrition,
    required this.voiceDescription,
    required this.confidenceScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'mealId': mealId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'mealType': mealType.toString(),
      'foods': foods.map((food) => food.toMap()).toList(),
      'nutrition': nutrition.toMap(),
      'voiceDescription': voiceDescription,
      'confidenceScore': confidenceScore,
    };
  }

  factory MealData.fromMap(Map<String, dynamic> map) {
    return MealData(
      mealId: map['mealId'] ?? '',
      userId: map['userId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      mealType: MealType.values.firstWhere(
        (type) => type.toString() == map['mealType'],
        orElse: () => MealType.lunch,
      ),
      foods: (map['foods'] as List<dynamic>?)
          ?.map((foodMap) => DetailedFoodItem.fromMap(foodMap))
          .toList() ?? [],
      nutrition: NutritionalSummary.fromMap(map['nutrition'] ?? {}),
      voiceDescription: map['voiceDescription'] ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Detailed food item with complete nutrition and context information
class DetailedFoodItem {
  final String id;
  final String name;
  final String originalName;
  final double quantity;
  final String unit;
  final double displayQuantity;
  final String displayUnit;
  final NutritionalInfo nutrition;
  final String? cookingMethod;
  final double confidence;
  final CulturalFoodContext culturalContext;

  DetailedFoodItem({
    required this.id,
    required this.name,
    required this.originalName,
    required this.quantity,
    required this.unit,
    required this.displayQuantity,
    required this.displayUnit,
    required this.nutrition,
    this.cookingMethod,
    required this.confidence,
    required this.culturalContext,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'originalName': originalName,
      'quantity': quantity,
      'unit': unit,
      'displayQuantity': displayQuantity,
      'displayUnit': displayUnit,
      'nutrition': nutrition.toMap(),
      'cookingMethod': cookingMethod,
      'confidence': confidence,
      'culturalContext': culturalContext.toMap(),
    };
  }

  factory DetailedFoodItem.fromMap(Map<String, dynamic> map) {
    return DetailedFoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      originalName: map['originalName'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      displayQuantity: (map['displayQuantity'] as num?)?.toDouble() ?? 0.0,
      displayUnit: map['displayUnit'] ?? '',
      nutrition: NutritionalInfo.fromMap(map['nutrition'] ?? {}),
      cookingMethod: map['cookingMethod'],
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      culturalContext: CulturalFoodContext.fromMap(map['culturalContext'] ?? {}),
    );
  }
}

/// Nutritional information for food items
class NutritionalInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final Map<String, double> vitamins;
  final Map<String, double> minerals;

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.vitamins,
    required this.minerals,
  });

  /// Create empty nutritional info
  factory NutritionalInfo.empty() {
    return NutritionalInfo(
      calories: 0.0,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      vitamins: {},
      minerals: {},
    );
  }

  /// Add two nutritional info objects together
  NutritionalInfo operator +(NutritionalInfo other) {
    final combinedVitamins = <String, double>{...vitamins};
    for (final entry in other.vitamins.entries) {
      combinedVitamins[entry.key] = (combinedVitamins[entry.key] ?? 0.0) + entry.value;
    }

    final combinedMinerals = <String, double>{...minerals};
    for (final entry in other.minerals.entries) {
      combinedMinerals[entry.key] = (combinedMinerals[entry.key] ?? 0.0) + entry.value;
    }

    return NutritionalInfo(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
      vitamins: combinedVitamins,
      minerals: combinedMinerals,
    );
  }

  /// Multiply nutritional info by a factor
  NutritionalInfo operator *(double factor) {
    final scaledVitamins = <String, double>{};
    for (final entry in vitamins.entries) {
      scaledVitamins[entry.key] = entry.value * factor;
    }

    final scaledMinerals = <String, double>{};
    for (final entry in minerals.entries) {
      scaledMinerals[entry.key] = entry.value * factor;
    }

    return NutritionalInfo(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      vitamins: scaledVitamins,
      minerals: scaledMinerals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'vitamins': vitamins,
      'minerals': minerals,
    };
  }

  factory NutritionalInfo.fromMap(Map<String, dynamic> map) {
    return NutritionalInfo(
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      vitamins: Map<String, double>.from(map['vitamins'] ?? {}),
      minerals: Map<String, double>.from(map['minerals'] ?? {}),
    );
  }
}

/// Summary of nutritional content for a complete meal
class NutritionalSummary {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final Map<String, double> vitamins;
  final Map<String, double> minerals;
  final MacroBreakdown macroBreakdown;

  NutritionalSummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.vitamins,
    required this.minerals,
    required this.macroBreakdown,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'totalFiber': totalFiber,
      'vitamins': vitamins,
      'minerals': minerals,
      'macroBreakdown': macroBreakdown.toMap(),
    };
  }

  factory NutritionalSummary.fromMap(Map<String, dynamic> map) {
    return NutritionalSummary(
      totalCalories: (map['totalCalories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (map['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (map['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (map['totalFat'] as num?)?.toDouble() ?? 0.0,
      totalFiber: (map['totalFiber'] as num?)?.toDouble() ?? 0.0,
      vitamins: Map<String, double>.from(map['vitamins'] ?? {}),
      minerals: Map<String, double>.from(map['minerals'] ?? {}),
      macroBreakdown: MacroBreakdown.fromMap(map['macroBreakdown'] ?? {}),
    );
  }
}

/// Breakdown of macronutrients as percentages
class MacroBreakdown {
  final double proteinPercentage;
  final double carbsPercentage;
  final double fatPercentage;

  MacroBreakdown({
    required this.proteinPercentage,
    required this.carbsPercentage,
    required this.fatPercentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'proteinPercentage': proteinPercentage,
      'carbsPercentage': carbsPercentage,
      'fatPercentage': fatPercentage,
    };
  }

  factory MacroBreakdown.fromMap(Map<String, dynamic> map) {
    return MacroBreakdown(
      proteinPercentage: (map['proteinPercentage'] as num?)?.toDouble() ?? 0.0,
      carbsPercentage: (map['carbsPercentage'] as num?)?.toDouble() ?? 0.0,
      fatPercentage: (map['fatPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Cultural context for food items
class CulturalFoodContext {
  final String region;
  final String cookingStyle;
  final String mealType;

  CulturalFoodContext({
    required this.region,
    required this.cookingStyle,
    required this.mealType,
  });

  Map<String, dynamic> toMap() {
    return {
      'region': region,
      'cookingStyle': cookingStyle,
      'mealType': mealType,
    };
  }

  factory CulturalFoodContext.fromMap(Map<String, dynamic> map) {
    return CulturalFoodContext(
      region: map['region'] ?? '',
      cookingStyle: map['cookingStyle'] ?? '',
      mealType: map['mealType'] ?? '',
    );
  }
}

/// Daily nutrition summary for tracking
class DailyNutritionSummary {
  final String userId;
  final String date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int mealCount;
  final DateTime createdAt;
  final DateTime lastUpdated;

  DailyNutritionSummary({
    required this.userId,
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.mealCount,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'mealCount': mealCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory DailyNutritionSummary.fromMap(Map<String, dynamic> map) {
    return DailyNutritionSummary(
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      totalCalories: (map['totalCalories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (map['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (map['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (map['totalFat'] as num?)?.toDouble() ?? 0.0,
      mealCount: map['mealCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Types of meals
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
}

/// Extension to get meal type display names
extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  String get hindiName {
    switch (this) {
      case MealType.breakfast:
        return 'नाश्ता';
      case MealType.lunch:
        return 'दोपहर का खाना';
      case MealType.dinner:
        return 'रात का खाना';
      case MealType.snack:
        return 'नाश्ता';
    }
  }
}

/// Food item for cultural context and meal expansion
class FoodItem {
  final String name;
  final double quantity;
  final String unit;
  final NutritionalInfo nutrition;
  final CulturalContext context;

  FoodItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.nutrition,
    required this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'nutrition': nutrition.toMap(),
      'context': context.toMap(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      nutrition: NutritionalInfo.fromMap(map['nutrition'] ?? {}),
      context: CulturalContext.fromMap(map['context'] ?? {}),
    );
  }
}

/// Cultural context for food items
class CulturalContext {
  final String region;
  final String cookingMethod;
  final String mealType;
  final List<String> commonCombinations;

  CulturalContext({
    required this.region,
    required this.cookingMethod,
    required this.mealType,
    required this.commonCombinations,
  });

  Map<String, dynamic> toMap() {
    return {
      'region': region,
      'cookingMethod': cookingMethod,
      'mealType': mealType,
      'commonCombinations': commonCombinations,
    };
  }

  factory CulturalContext.fromMap(Map<String, dynamic> map) {
    return CulturalContext(
      region: map['region'] ?? '',
      cookingMethod: map['cookingMethod'] ?? '',
      mealType: map['mealType'] ?? '',
      commonCombinations: List<String>.from(map['commonCombinations'] ?? []),
    );
  }
}