import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../voice/hinglish_processor.dart';
import '../cultural/indian_food_database.dart';
import '../cultural/cultural_context_engine.dart';
import 'meal_data_models.dart';

/// Automated meal tracking and nutritional calculation service
/// Handles voice-based meal logging with automatic nutrition computation
class MealLoggerService {
  final HinglishProcessor _hinglishProcessor = HinglishProcessor();
  final IndianFoodDatabase _foodDatabase = IndianFoodDatabase();
  final CulturalContextEngine _culturalEngine = CulturalContextEngine();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Log a meal from voice description
  Future<MealLogResult> logMealFromVoice(String voiceDescription, String userId) async {
    try {
      // Step 1: Extract food items from Hinglish description
      final extractionResult = _hinglishProcessor.extractFoodItems(voiceDescription);
      
      if (extractionResult.foodItems.isEmpty) {
        return MealLogResult(
          success: false,
          message: 'Koi khana nahi mila description mein. Kripaya phir se batayiye.',
          mealData: null,
          ambiguities: [],
          confidence: 0.0,
        );
      }

      // Step 2: Check for ambiguities that need clarification
      if (extractionResult.ambiguities.isNotEmpty) {
        final clarificationQuestions = _hinglishProcessor.generateClarificationQuestions(extractionResult.ambiguities);
        return MealLogResult(
          success: false,
          message: clarificationQuestions.first,
          mealData: null,
          ambiguities: extractionResult.ambiguities,
          confidence: extractionResult.confidence,
        );
      }

      // Step 3: Convert extracted items to detailed food items with nutrition
      final List<DetailedFoodItem> detailedFoods = [];
      double totalConfidence = 0.0;

      for (final extractedItem in extractionResult.foodItems) {
        final detailedFood = await _convertToDetailedFoodItem(extractedItem);
        if (detailedFood != null) {
          detailedFoods.add(detailedFood);
          totalConfidence += extractedItem.confidence;
        }
      }

      if (detailedFoods.isEmpty) {
        return MealLogResult(
          success: false,
          message: 'Maaf kijiye, hum ye khana samajh nahi paye. Kya aap aur detail de sakte hain?',
          mealData: null,
          ambiguities: [],
          confidence: 0.0,
        );
      }

      // Step 4: Calculate overall nutrition
      final nutritionSummary = await calculateMealNutrition(detailedFoods);

      // Step 5: Create meal data
      final mealData = MealData(
        mealId: _uuid.v4(),
        userId: userId,
        timestamp: DateTime.now(),
        mealType: _determineMealType(DateTime.now()),
        foods: detailedFoods,
        nutrition: nutritionSummary,
        voiceDescription: voiceDescription,
        confidenceScore: totalConfidence / extractionResult.foodItems.length,
      );

      // Step 6: Save to database
      final saveSuccess = await saveMeal(mealData);
      
      if (!saveSuccess) {
        return MealLogResult(
          success: false,
          message: 'Meal save karne mein problem hui. Kripaya phir se try kariye.',
          mealData: mealData,
          ambiguities: [],
          confidence: mealData.confidenceScore,
        );
      }

      // Step 7: Generate confirmation message
      final confirmationMessage = generateSpokenConfirmation(mealData);

      return MealLogResult(
        success: true,
        message: confirmationMessage,
        mealData: mealData,
        ambiguities: [],
        confidence: mealData.confidenceScore,
      );

    } catch (e) {
      print('Error logging meal from voice: $e');
      return MealLogResult(
        success: false,
        message: 'Kuch technical problem hui hai. Kripaya phir se try kariye.',
        mealData: null,
        ambiguities: [],
        confidence: 0.0,
      );
    }
  }

  /// Convert extracted food item to detailed food item with nutrition
  Future<DetailedFoodItem?> _convertToDetailedFoodItem(ExtractedFoodItem extractedItem) async {
    try {
      // Search for the food in database
      final searchResults = await _foodDatabase.searchFood(extractedItem.name);
      
      if (searchResults.isEmpty) {
        // Try searching with original text
        final originalResults = await _foodDatabase.searchFood(extractedItem.originalText);
        if (originalResults.isEmpty) {
          print('Food not found in database: ${extractedItem.name}');
          return null;
        }
        searchResults.addAll(originalResults);
      }

      // Take the best match (first result)
      final indianFoodItem = searchResults.first;

      // Determine quantity and unit
      double quantity = extractedItem.quantity?.amount ?? 1.0;
      String unit = extractedItem.quantity?.unit ?? 'portion';

      // Convert to standard units if needed
      final portionSize = _culturalEngine.estimateIndianPortion(extractedItem.name, '$quantity $unit');
      
      // Get nutrition for the specific quantity
      final nutrition = await _foodDatabase.getNutrition(indianFoodItem.id, portionSize.quantity, 'grams');

      // Apply cooking method adjustments
      final adjustedNutrition = _applyCookingMethodAdjustments(nutrition, extractedItem.cookingMethod);

      return DetailedFoodItem(
        id: _uuid.v4(),
        name: indianFoodItem.name,
        originalName: extractedItem.originalText,
        quantity: portionSize.quantity,
        unit: 'grams',
        displayQuantity: quantity,
        displayUnit: unit,
        nutrition: adjustedNutrition,
        cookingMethod: extractedItem.cookingMethod,
        confidence: extractedItem.confidence,
        culturalContext: CulturalFoodContext(
          region: 'India',
          cookingStyle: extractedItem.cookingMethod ?? 'traditional',
          mealType: 'main',
        ),
      );

    } catch (e) {
      print('Error converting food item ${extractedItem.name}: $e');
      return null;
    }
  }

  /// Apply cooking method adjustments to nutrition
  NutritionalInfo _applyCookingMethodAdjustments(NutritionalInfo baseNutrition, String? cookingMethod) {
    if (cookingMethod == null) return baseNutrition;

    // Get cooking method multiplier from cultural engine
    final methodInfo = _culturalEngine.getCookingMethodInfo(cookingMethod);
    final multiplier = methodInfo?.nutritionMultiplier ?? 1.0;

    return NutritionalInfo(
      calories: baseNutrition.calories * multiplier,
      protein: baseNutrition.protein,
      carbs: baseNutrition.carbs,
      fat: baseNutrition.fat * multiplier,
      fiber: baseNutrition.fiber,
      vitamins: baseNutrition.vitamins,
      minerals: baseNutrition.minerals,
    );
  }

  /// Calculate nutrition for a meal
  Future<NutritionalSummary> calculateMealNutrition(List<DetailedFoodItem> foods) async {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;
    
    final Map<String, double> totalVitamins = {};
    final Map<String, double> totalMinerals = {};

    for (final food in foods) {
      totalCalories += food.nutrition.calories;
      totalProtein += food.nutrition.protein;
      totalCarbs += food.nutrition.carbs;
      totalFat += food.nutrition.fat;
      totalFiber += food.nutrition.fiber;

      // Aggregate vitamins
      food.nutrition.vitamins.forEach((vitamin, amount) {
        totalVitamins[vitamin] = (totalVitamins[vitamin] ?? 0.0) + amount;
      });

      // Aggregate minerals
      food.nutrition.minerals.forEach((mineral, amount) {
        totalMinerals[mineral] = (totalMinerals[mineral] ?? 0.0) + amount;
      });
    }

    return NutritionalSummary(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      totalFiber: totalFiber,
      vitamins: totalVitamins,
      minerals: totalMinerals,
      macroBreakdown: MacroBreakdown(
        proteinPercentage: (totalProtein * 4) / totalCalories * 100,
        carbsPercentage: (totalCarbs * 4) / totalCalories * 100,
        fatPercentage: (totalFat * 9) / totalCalories * 100,
      ),
    );
  }

  /// Generate spoken confirmation for logged meal
  String generateSpokenConfirmation(MealData meal) {
    final foodNames = meal.foods.map((food) => food.originalName).join(', ');
    final totalCalories = meal.nutrition.totalCalories.round();
    final mealTypeHindi = _getMealTypeInHindi(meal.mealType);
    
    return 'Aapka $mealTypeHindi log ho gaya: $foodNames. '
           'Total $totalCalories calories hain. '
           'Protein ${meal.nutrition.totalProtein.toStringAsFixed(1)}g, '
           'Carbs ${meal.nutrition.totalCarbs.toStringAsFixed(1)}g, '
           'Fat ${meal.nutrition.totalFat.toStringAsFixed(1)}g hai.';
  }

  /// Get meal type in Hindi
  String _getMealTypeInHindi(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  /// Determine meal type based on time
  MealType _determineMealType(DateTime timestamp) {
    final hour = timestamp.hour;
    
    if (hour >= 6 && hour < 11) {
      return MealType.breakfast;
    } else if (hour >= 11 && hour < 16) {
      return MealType.lunch;
    } else if (hour >= 16 && hour < 19) {
      return MealType.snack;
    } else {
      return MealType.dinner;
    }
  }

  /// Save meal to database
  Future<bool> saveMeal(MealData meal) async {
    try {
      await _firestore.collection('meals').doc(meal.mealId).set(meal.toMap());
      
      // Also update user's daily nutrition summary
      await _updateDailyNutritionSummary(meal);
      
      return true;
    } catch (e) {
      print('Error saving meal: $e');
      return false;
    }
  }

  /// Update user's daily nutrition summary
  Future<void> _updateDailyNutritionSummary(MealData meal) async {
    try {
      final dateKey = '${meal.timestamp.year}-${meal.timestamp.month.toString().padLeft(2, '0')}-${meal.timestamp.day.toString().padLeft(2, '0')}';
      final docRef = _firestore.collection('daily_nutrition').doc('${meal.userId}_$dateKey');
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          // Update existing summary
          final data = doc.data()!;
          final currentCalories = (data['totalCalories'] as num?)?.toDouble() ?? 0.0;
          final currentProtein = (data['totalProtein'] as num?)?.toDouble() ?? 0.0;
          final currentCarbs = (data['totalCarbs'] as num?)?.toDouble() ?? 0.0;
          final currentFat = (data['totalFat'] as num?)?.toDouble() ?? 0.0;
          
          transaction.update(docRef, {
            'totalCalories': currentCalories + meal.nutrition.totalCalories,
            'totalProtein': currentProtein + meal.nutrition.totalProtein,
            'totalCarbs': currentCarbs + meal.nutrition.totalCarbs,
            'totalFat': currentFat + meal.nutrition.totalFat,
            'mealCount': (data['mealCount'] as int? ?? 0) + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new summary
          transaction.set(docRef, {
            'userId': meal.userId,
            'date': dateKey,
            'totalCalories': meal.nutrition.totalCalories,
            'totalProtein': meal.nutrition.totalProtein,
            'totalCarbs': meal.nutrition.totalCarbs,
            'totalFat': meal.nutrition.totalFat,
            'mealCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating daily nutrition summary: $e');
    }
  }

  /// Get user's meal history
  Future<List<MealData>> getMealHistory(String userId, {int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      final querySnapshot = await _firestore
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final List<MealData> meals = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          final mealData = MealData.fromMap(doc.data());
          meals.add(mealData);
        } catch (e) {
          print('Error parsing meal data ${doc.id}: $e');
        }
      }

      return meals;
    } catch (e) {
      print('Error getting meal history: $e');
      return [];
    }
  }

  /// Get today's nutrition summary
  Future<DailyNutritionSummary?> getTodaysNutrition(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore.collection('daily_nutrition').doc('${userId}_$dateKey').get();
      
      if (doc.exists) {
        return DailyNutritionSummary.fromMap(doc.data()!);
      }
      
      return null;
    } catch (e) {
      print('Error getting today\'s nutrition: $e');
      return null;
    }
  }

  /// Search for similar meals in history
  Future<List<MealData>> findSimilarMeals(String userId, List<String> foodNames) async {
    try {
      final querySnapshot = await _firestore
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final List<MealData> similarMeals = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          final mealData = MealData.fromMap(doc.data());
          
          // Check if meal contains any of the specified foods
          final mealFoodNames = mealData.foods.map((f) => f.name.toLowerCase()).toSet();
          final searchFoodNames = foodNames.map((f) => f.toLowerCase()).toSet();
          
          if (mealFoodNames.intersection(searchFoodNames).isNotEmpty) {
            similarMeals.add(mealData);
          }
        } catch (e) {
          print('Error parsing meal data ${doc.id}: $e');
        }
      }

      return similarMeals.take(10).toList();
    } catch (e) {
      print('Error finding similar meals: $e');
      return [];
    }
  }
}