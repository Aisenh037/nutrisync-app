import '../models/user_model.dart';
import '../cultural/indian_food_database.dart';
import '../nutrition/meal_data_models.dart';
import '../cultural/cultural_context_engine.dart';

/// Personalized food recommendation engine for Indian cuisine
class RecommendationEngine {
  final IndianFoodDatabase? _foodDatabase;

  RecommendationEngine({IndianFoodDatabase? foodDatabase})
      : _foodDatabase = foodDatabase;

  /// Generate personalized food recommendations based on user profile
  Future<RecommendationResult> generateRecommendations({
    required UserModel user,
    required RecommendationType type,
    int maxRecommendations = 10,
    String? mealType,
    List<String>? excludeIngredients,
  }) async {
    try {
      // Get user's dietary and health context
      final context = _buildUserContext(user);
      
      // Get available foods based on dietary restrictions
      final availableFoods = await _getAvailableFoods(user, excludeIngredients);
      
      // Score and rank foods based on user preferences and goals
      final scoredFoods = _scoreFoods(availableFoods, context, type);
      
      // Filter by meal type if specified
      final filteredFoods = mealType != null 
          ? _filterByMealType(scoredFoods, mealType)
          : scoredFoods;
      
      // Get top recommendations
      final recommendations = filteredFoods
          .take(maxRecommendations)
          .map((scored) => _createRecommendation(scored, context))
          .toList();

      return RecommendationResult(
        recommendations: recommendations,
        context: context,
        success: true,
      );
    } catch (e) {
      return RecommendationResult(
        recommendations: [],
        context: UserContext.empty(),
        success: false,
        error: 'Failed to generate recommendations: $e',
      );
    }
  }

  /// Generate meal plan recommendations for a specific period
  Future<MealPlanResult> generateMealPlan({
    required UserModel user,
    required int days,
    bool includeSnacks = true,
  }) async {
    try {
      final context = _buildUserContext(user);
      final mealPlan = <String, List<MealRecommendation>>{};
      
      for (int day = 0; day < days; day++) {
        final dayKey = 'day_${day + 1}';
        final dayMeals = <MealRecommendation>[];
        
        // Generate breakfast
        final breakfast = await generateRecommendations(
          user: user,
          type: RecommendationType.balanced,
          maxRecommendations: 2,
          mealType: 'breakfast',
        );
        dayMeals.addAll(breakfast.recommendations);
        
        // Generate lunch
        final lunch = await generateRecommendations(
          user: user,
          type: RecommendationType.balanced,
          maxRecommendations: 3,
          mealType: 'lunch',
        );
        dayMeals.addAll(lunch.recommendations);
        
        // Generate dinner
        final dinner = await generateRecommendations(
          user: user,
          type: RecommendationType.balanced,
          maxRecommendations: 3,
          mealType: 'dinner',
        );
        dayMeals.addAll(dinner.recommendations);
        
        // Generate snacks if requested
        if (includeSnacks) {
          final snacks = await generateRecommendations(
            user: user,
            type: RecommendationType.healthy,
            maxRecommendations: 2,
            mealType: 'snack',
          );
          dayMeals.addAll(snacks.recommendations);
        }
        
        mealPlan[dayKey] = dayMeals;
      }
      
      return MealPlanResult(
        mealPlan: mealPlan,
        totalDays: days,
        context: context,
        success: true,
      );
    } catch (e) {
      return MealPlanResult(
        mealPlan: {},
        totalDays: 0,
        context: UserContext.empty(),
        success: false,
        error: 'Failed to generate meal plan: $e',
      );
    }
  }

  /// Get portion size recommendations based on user's activity level and goals
  PortionRecommendation getPortionRecommendation({
    required UserModel user,
    required IndianFoodItem food,
    required String mealType,
  }) {
    final baseCalories = _calculateBaseCalorieNeeds(user);
    final mealCalorieTarget = _getMealCalorieTarget(baseCalories, mealType);
    
    // Calculate portion based on food's calorie density
    final foodCaloriesPerGram = food.nutrition.calories / 100; // per 100g
    final recommendedGrams = (mealCalorieTarget * 0.4) / foodCaloriesPerGram; // 40% of meal calories from this food
    
    // Convert to Indian units
    final indianPortion = _convertToIndianUnits(food, recommendedGrams);
    
    return PortionRecommendation(
      grams: recommendedGrams.round(),
      indianUnit: indianPortion.unit,
      indianQuantity: indianPortion.quantity,
      calories: (recommendedGrams * foodCaloriesPerGram).round(),
      reason: _getPortionReason(user, mealType),
    );
  }

  /// Analyze nutritional balance of a meal or day
  NutritionalBalanceAnalysis analyzeNutritionalBalance({
    required List<DetailedFoodItem> meals,
    required UserModel user,
  }) {
    final totalNutrition = _calculateTotalNutrition(meals);
    final recommendations = _calculateNutritionalNeeds(user);
    
    final analysis = NutritionalBalanceAnalysis(
      totalCalories: totalNutrition.calories,
      targetCalories: recommendations.calories,
      macroBalance: MacroBalance(
        carbs: MacroAnalysis(
          current: totalNutrition.carbs,
          target: recommendations.carbs,
          percentage: (totalNutrition.carbs / recommendations.carbs * 100).clamp(0, 200),
        ),
        protein: MacroAnalysis(
          current: totalNutrition.protein,
          target: recommendations.protein,
          percentage: (totalNutrition.protein / recommendations.protein * 100).clamp(0, 200),
        ),
        fat: MacroAnalysis(
          current: totalNutrition.fat,
          target: recommendations.fat,
          percentage: (totalNutrition.fat / recommendations.fat * 100).clamp(0, 200),
        ),
      ),
      micronutrients: _analyzeMicronutrients(totalNutrition, recommendations),
      suggestions: _generateBalanceSuggestions(totalNutrition, recommendations, user),
    );
    
    return analysis;
  }

  /// Get complementary food suggestions to improve nutritional balance
  Future<List<MealRecommendation>> getComplementaryFoods({
    required List<DetailedFoodItem> currentMeals,
    required UserModel user,
    int maxSuggestions = 5,
  }) async {
    final analysis = analyzeNutritionalBalance(meals: currentMeals, user: user);
    final deficiencies = _identifyDeficiencies(analysis);
    
    final complementaryFoods = <MealRecommendation>[];
    
    for (final deficiency in deficiencies) {
      final foods = await _getFoodsRichIn(deficiency.nutrient, user);
      final scored = _scoreFoods(foods, _buildUserContext(user), RecommendationType.complementary);
      
      complementaryFoods.addAll(
        scored.take(2).map((scored) => _createRecommendation(scored, _buildUserContext(user)))
      );
    }
    
    return complementaryFoods.take(maxSuggestions).toList();
  }

  // Private helper methods
  
  UserContext _buildUserContext(UserModel user) {
    return UserContext(
      age: user.age ?? 25,
      gender: user.gender ?? 'Unknown',
      activityLevel: user.activityLevel ?? 'Moderate',
      healthGoals: user.healthGoals,
      medicalConditions: user.medicalConditions,
      allergies: user.allergies,
      dietaryNeeds: user.dietaryNeeds,
      foodDislikes: user.foodDislikes,
      culturalPreferences: user.culturalPreferences,
      bmi: user.bmi,
      isPremium: user.isPremium,
    );
  }

  Future<List<IndianFoodItem>> _getAvailableFoods(UserModel user, List<String>? excludeIngredients) async {
    // For now, use sample data from the database
    // In a real implementation, this would query the database
    final sampleFoods = _getSampleIndianFoods();
    
    return sampleFoods.where((food) {
      // Filter by dietary restrictions
      if (!_matchesDietaryNeeds(food, user.dietaryNeeds)) return false;
      
      // Filter by allergies
      if (_containsAllergens(food, user.allergies)) return false;
      
      // Filter by food dislikes
      if (_isDislikedFood(food, user.foodDislikes)) return false;
      
      // Filter by excluded ingredients
      if (excludeIngredients != null && _containsExcludedIngredients(food, excludeIngredients)) return false;
      
      return true;
    }).toList();
  }

  /// Get sample Indian foods for testing and development
  List<IndianFoodItem> _getSampleIndianFoods() {
    return [
      // Dal items
      IndianFoodItem(
        id: 'dal_makhani',
        name: 'Dal Makhani',
        aliases: ['dal makhni', 'makhani dal', 'black dal', 'काली दाल'],
        nutrition: NutritionalInfo(
          calories: 150.0,
          protein: 8.0,
          carbs: 18.0,
          fat: 6.0,
          fiber: 4.0,
          vitamins: {'B1': 0.2, 'B6': 0.1, 'folate': 45.0},
          minerals: {'iron': 2.5, 'magnesium': 40.0, 'potassium': 300.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'dum',
            description: 'Slow cooked with cream and butter',
            nutritionMultiplier: 1.2,
            commonIngredients: ['black lentils', 'cream', 'butter', 'tomatoes'],
          ),
          alternatives: [],
          nutritionAdjustments: {'fat': 1.5, 'calories': 1.3},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 150.0,
            IndianMeasurementUnit.spoon: 15.0,
          },
          visualReference: '1 katori (small bowl)',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'Central Indian'],
          regionalNames: {'hindi': 'काली दाल', 'english': 'Dal Makhani'},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['naan', 'roti', 'rice'],
        searchTerms: ['dal makhani', 'dal makhni', 'black dal', 'काली दाल'],
        baseDish: 'dal',
        regionalVariations: [],
      ),
      // Rice items
      IndianFoodItem(
        id: 'basmati_rice',
        name: 'Basmati Rice',
        aliases: ['basmati', 'white rice', 'चावल'],
        nutrition: NutritionalInfo(
          calories: 130.0,
          protein: 2.7,
          carbs: 28.0,
          fat: 0.3,
          fiber: 0.4,
          vitamins: {'B1': 0.07, 'B3': 1.6},
          minerals: {'iron': 0.8, 'magnesium': 25.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'boiled',
            description: 'Boiled in water until tender',
            nutritionMultiplier: 1.0,
            commonIngredients: ['basmati rice', 'water', 'salt'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 150.0,
            IndianMeasurementUnit.spoon: 20.0,
          },
          visualReference: '1 katori cooked rice',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'South Indian', 'Central Indian'],
          regionalNames: {'hindi': 'चावल', 'english': 'rice'},
        ),
        category: IndianFoodCategory.rice,
        commonCombinations: ['dal', 'curry', 'sabzi'],
        searchTerms: ['basmati rice', 'white rice', 'चावल'],
        baseDish: 'rice',
        regionalVariations: [],
      ),
      // Vegetable items
      IndianFoodItem(
        id: 'aloo_gobi',
        name: 'Aloo Gobi',
        aliases: ['potato cauliflower', 'आलू गोभी'],
        nutrition: NutritionalInfo(
          calories: 110.0,
          protein: 3.0,
          carbs: 20.0,
          fat: 3.0,
          fiber: 4.0,
          vitamins: {'C': 48.2, 'K': 15.5, 'B6': 0.3},
          minerals: {'potassium': 421.0, 'phosphorus': 44.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'bhuna',
            description: 'Dry roasted with spices',
            nutritionMultiplier: 1.1,
            commonIngredients: ['potato', 'cauliflower', 'onion', 'spices', 'oil'],
          ),
          alternatives: [],
          nutritionAdjustments: {'fat': 1.2},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 100.0,
          },
          visualReference: '1 katori serving',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'Central Indian'],
          regionalNames: {'hindi': 'आलू गोभी', 'english': 'Aloo Gobi'},
        ),
        category: IndianFoodCategory.sabzi,
        commonCombinations: ['roti', 'rice'],
        searchTerms: ['aloo gobi', 'potato cauliflower', 'आलू गोभी'],
        baseDish: 'sabzi',
        regionalVariations: [],
      ),
    ];
  }

  List<ScoredFood> _scoreFoods(List<IndianFoodItem> foods, UserContext context, RecommendationType type) {
    return foods.map((food) {
      double score = 0.0;
      
      // Base nutritional score
      score += _calculateNutritionalScore(food, context);
      
      // Health goal alignment score
      score += _calculateHealthGoalScore(food, context.healthGoals);
      
      // Medical condition consideration
      score += _calculateMedicalScore(food, context.medicalConditions);
      
      // Cultural preference score
      score += _calculateCulturalScore(food, context.culturalPreferences);
      
      // Type-specific scoring
      score += _calculateTypeScore(food, type, context);
      
      return ScoredFood(food: food, score: score);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  List<ScoredFood> _filterByMealType(List<ScoredFood> foods, String mealType) {
    return foods.where((scored) {
      final food = scored.food;
      final categoryMealType = _getMealTypeFromCategory(food.category);
      return categoryMealType == mealType.toLowerCase() || 
             categoryMealType == 'main' && (mealType.toLowerCase() == 'lunch' || mealType.toLowerCase() == 'dinner');
    }).toList();
  }

  MealRecommendation _createRecommendation(ScoredFood scored, UserContext context) {
    final food = scored.food;
    final portion = PortionRecommendation(
      grams: 100, // Default portion
      indianUnit: 'katori',
      indianQuantity: 1.0,
      calories: food.nutrition.calories.round(),
      reason: 'Standard serving size',
    );
    
    return MealRecommendation(
      food: food,
      portion: portion,
      score: scored.score,
      reasons: _generateRecommendationReasons(scored, context),
      cookingTips: _generateCookingTips(food, context),
    );
  }

  double _calculateNutritionalScore(IndianFoodItem food, UserContext context) {
    double score = 0.0;
    final nutrition = food.nutrition;
    
    // Protein score (higher is better for most goals)
    if (nutrition.protein > 10) score += 2.0;
    else if (nutrition.protein > 5) score += 1.0;
    
    // Fiber score
    if (nutrition.fiber > 5) score += 2.0;
    else if (nutrition.fiber > 2) score += 1.0;
    
    // Micronutrient density
    score += (nutrition.vitamins.length + nutrition.minerals.length) * 0.1;
    
    return score;
  }

  double _calculateHealthGoalScore(IndianFoodItem food, List<String> healthGoals) {
    double score = 0.0;
    
    for (final goal in healthGoals) {
      switch (goal.toLowerCase()) {
        case 'weight loss':
          // Favor low-calorie, high-fiber foods
          if (food.nutrition.calories < 150 && food.nutrition.fiber > 3) score += 2.0;
          break;
        case 'weight gain':
          // Favor calorie-dense, nutritious foods
          if (food.nutrition.calories > 200 && food.nutrition.protein > 8) score += 2.0;
          break;
        case 'muscle building':
          // Favor high-protein foods
          if (food.nutrition.protein > 15) score += 3.0;
          else if (food.nutrition.protein > 10) score += 2.0;
          break;
        case 'heart health':
          // Favor high-fiber foods
          if (food.nutrition.fiber > 4) score += 2.0;
          break;
        case 'blood sugar control':
          // Favor low-calorie foods with fiber
          if (food.nutrition.fiber > 5 && food.nutrition.calories < 150) score += 2.0;
          break;
      }
    }
    
    return score;
  }

  double _calculateMedicalScore(IndianFoodItem food, List<String> medicalConditions) {
    double score = 0.0;
    
    for (final condition in medicalConditions) {
      switch (condition.toLowerCase()) {
        case 'diabetes':
          // Favor high-fiber foods
          if (food.nutrition.fiber > 3) score += 1.5;
          if (food.nutrition.calories > 200) score -= 1.0; // Penalize high calorie
          break;
        case 'hypertension':
          // Favor low-calorie foods
          if (food.nutrition.calories < 150) score += 1.5;
          break;
        case 'high cholesterol':
          // Favor foods with fiber
          if (food.nutrition.fiber > 4) score += 1.0;
          break;
      }
    }
    
    return score;
  }

  double _calculateCulturalScore(IndianFoodItem food, Map<String, dynamic> culturalPreferences) {
    double score = 0.0;
    
    final preferredRegion = culturalPreferences['preferredRegion'] as String? ?? 'North Indian';
    if (food.regions.primaryRegion.toLowerCase() == preferredRegion.toLowerCase()) {
      score += 1.5;
    }
    
    return score;
  }

  double _calculateTypeScore(IndianFoodItem food, RecommendationType type, UserContext context) {
    switch (type) {
      case RecommendationType.healthy:
        return _calculateNutritionalScore(food, context) * 1.5;
      case RecommendationType.balanced:
        return 1.0; // No additional scoring
      case RecommendationType.indulgent:
        // Favor comfort foods (higher calories, familiar dishes)
        return food.nutrition.calories > 250 ? 1.5 : 0.0;
      case RecommendationType.complementary:
        return 1.0; // Scoring handled in complementary food logic
    }
  }

  bool _matchesDietaryNeeds(IndianFoodItem food, List<String> dietaryNeeds) {
    for (final need in dietaryNeeds) {
      switch (need.toLowerCase()) {
        case 'vegetarian':
          // All foods in IndianFoodDatabase are vegetarian by default
          break;
        case 'vegan':
          // Check if food contains dairy ingredients
          if (food.cookingMethods.defaultMethod.commonIngredients.any((ingredient) => 
              ingredient.toLowerCase().contains('cream') || 
              ingredient.toLowerCase().contains('butter') ||
              ingredient.toLowerCase().contains('milk') ||
              ingredient.toLowerCase().contains('paneer'))) {
            return false;
          }
          break;
        case 'gluten-free':
          // Check if food contains wheat
          if (food.cookingMethods.defaultMethod.commonIngredients.any((ingredient) => 
              ingredient.toLowerCase().contains('wheat') ||
              ingredient.toLowerCase().contains('flour'))) {
            return false;
          }
          break;
      }
    }
    return true;
  }

  bool _containsAllergens(IndianFoodItem food, List<String> allergies) {
    return allergies.any((allergy) => 
        food.cookingMethods.defaultMethod.commonIngredients.any((ingredient) => 
            ingredient.toLowerCase().contains(allergy.toLowerCase())));
  }

  bool _isDislikedFood(IndianFoodItem food, List<String> foodDislikes) {
    return foodDislikes.any((dislike) => 
        food.name.toLowerCase().contains(dislike.toLowerCase()) ||
        food.cookingMethods.defaultMethod.commonIngredients.any((ingredient) => 
            ingredient.toLowerCase().contains(dislike.toLowerCase())));
  }

  bool _containsExcludedIngredients(IndianFoodItem food, List<String> excludeIngredients) {
    return excludeIngredients.any((excluded) =>
        food.cookingMethods.defaultMethod.commonIngredients.any((ingredient) =>
            ingredient.toLowerCase().contains(excluded.toLowerCase())));
  }

  double _calculateBaseCalorieNeeds(UserModel user) {
    // Simplified BMR calculation
    if (user.age == null || user.weight == null) return 2000.0; // Default
    
    double bmr;
    if (user.gender?.toLowerCase() == 'male') {
      bmr = 88.362 + (13.397 * user.weight!) + (4.799 * (user.height ?? 175)) - (5.677 * user.age!);
    } else {
      bmr = 447.593 + (9.247 * user.weight!) + (3.098 * (user.height ?? 165)) - (4.330 * user.age!);
    }
    
    // Activity factor
    final activityMultiplier = _getActivityMultiplier(user.activityLevel ?? 'Moderate');
    return bmr * activityMultiplier;
  }

  double _getActivityMultiplier(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'sedentary': return 1.2;
      case 'light': return 1.375;
      case 'moderate': return 1.55;
      case 'active': return 1.725;
      case 'very active': return 1.9;
      default: return 1.55;
    }
  }

  double _getMealCalorieTarget(double dailyCalories, String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return dailyCalories * 0.25;
      case 'lunch': return dailyCalories * 0.35;
      case 'dinner': return dailyCalories * 0.30;
      case 'snack': return dailyCalories * 0.10;
      default: return dailyCalories * 0.25;
    }
  }

  IndianPortion _convertToIndianUnits(IndianFoodItem food, double grams) {
    // Use the food's portion guides if available
    if (food.portionSizes.standardPortions.containsKey(IndianMeasurementUnit.katori)) {
      final katori = food.portionSizes.standardPortions[IndianMeasurementUnit.katori]!;
      return IndianPortion(unit: 'katori', quantity: grams / katori);
    } else if (food.portionSizes.standardPortions.containsKey(IndianMeasurementUnit.roti)) {
      final roti = food.portionSizes.standardPortions[IndianMeasurementUnit.roti]!;
      return IndianPortion(unit: 'piece', quantity: grams / roti);
    } else {
      // Convert grams to common Indian units based on category
      switch (food.category) {
        case IndianFoodCategory.rice:
        case IndianFoodCategory.dal:
          return IndianPortion(unit: 'katori', quantity: grams / 150); // 1 katori ≈ 150g
        case IndianFoodCategory.roti:
          return IndianPortion(unit: 'piece', quantity: grams / 30); // 1 roti ≈ 30g
        case IndianFoodCategory.sabzi:
        case IndianFoodCategory.curry:
          return IndianPortion(unit: 'katori', quantity: grams / 100); // 1 katori vegetables ≈ 100g
        default:
          return IndianPortion(unit: 'grams', quantity: grams);
      }
    }
  }

  String _getPortionReason(UserModel user, String mealType) {
    final goals = user.healthGoals;
    if (goals.contains('Weight loss')) {
      return 'Portion adjusted for weight loss goals';
    } else if (goals.contains('Weight gain')) {
      return 'Larger portion to support weight gain';
    } else if (goals.contains('Muscle building')) {
      return 'Protein-rich portion for muscle building';
    } else {
      return 'Balanced portion for $mealType';
    }
  }

  NutritionalInfo _calculateTotalNutrition(List<DetailedFoodItem> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    final combinedVitamins = <String, double>{};
    final combinedMinerals = <String, double>{};
    
    for (final meal in meals) {
      final nutrition = meal.nutrition;
      final multiplier = meal.quantity / 100; // Assuming nutrition is per 100g
      
      totalCalories += nutrition.calories * multiplier;
      totalProtein += nutrition.protein * multiplier;
      totalCarbs += nutrition.carbs * multiplier;
      totalFat += nutrition.fat * multiplier;
      totalFiber += nutrition.fiber * multiplier;
      
      // Combine vitamins
      for (final entry in nutrition.vitamins.entries) {
        combinedVitamins[entry.key] = (combinedVitamins[entry.key] ?? 0.0) + (entry.value * multiplier);
      }
      
      // Combine minerals
      for (final entry in nutrition.minerals.entries) {
        combinedMinerals[entry.key] = (combinedMinerals[entry.key] ?? 0.0) + (entry.value * multiplier);
      }
    }
    
    return NutritionalInfo(
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      fiber: totalFiber,
      vitamins: combinedVitamins,
      minerals: combinedMinerals,
    );
  }

  NutritionalRecommendations _calculateNutritionalNeeds(UserModel user) {
    final baseCalories = _calculateBaseCalorieNeeds(user);
    
    return NutritionalRecommendations(
      calories: baseCalories,
      protein: baseCalories * 0.15 / 4, // 15% of calories from protein (4 cal/g)
      carbs: baseCalories * 0.55 / 4, // 55% of calories from carbs (4 cal/g)
      fat: baseCalories * 0.30 / 9, // 30% of calories from fat (9 cal/g)
      fiber: 25.0, // Standard recommendation
      sodium: 2300.0, // Standard recommendation in mg
    );
  }

  List<MicronutrientAnalysis> _analyzeMicronutrients(NutritionalInfo current, NutritionalRecommendations target) {
    final analyses = <MicronutrientAnalysis>[];
    
    // Analyze fiber
    analyses.add(MicronutrientAnalysis(
      name: 'Fiber',
      current: current.fiber,
      target: target.fiber,
      percentage: (current.fiber / target.fiber * 100).clamp(0, 200),
      status: current.fiber >= target.fiber ? 'Adequate' : 'Low',
    ));
    
    return analyses;
  }

  List<String> _generateBalanceSuggestions(NutritionalInfo current, NutritionalRecommendations target, UserModel user) {
    final suggestions = <String>[];
    
    if (current.protein < target.protein * 0.8) {
      suggestions.add('Add more protein-rich foods like dal, paneer, or legumes');
    }
    
    if (current.fiber < target.fiber * 0.8) {
      suggestions.add('Include more vegetables and whole grains for fiber');
    }
    
    if (current.calories < target.calories * 0.8) {
      suggestions.add('Consider adding healthy snacks to meet calorie needs');
    }
    
    return suggestions;
  }

  List<NutrientDeficiency> _identifyDeficiencies(NutritionalBalanceAnalysis analysis) {
    final deficiencies = <NutrientDeficiency>[];
    
    if (analysis.macroBalance.protein.percentage < 80) {
      deficiencies.add(NutrientDeficiency(nutrient: 'protein', severity: 'moderate'));
    }
    
    // Check micronutrients
    for (final micro in analysis.micronutrients) {
      if (micro.percentage < 80) {
        deficiencies.add(NutrientDeficiency(nutrient: micro.name.toLowerCase(), severity: 'mild'));
      }
    }
    
    return deficiencies;
  }

  Future<List<IndianFoodItem>> _getFoodsRichIn(String nutrient, UserModel user) async {
    final allFoods = await _getAvailableFoods(user, null);
    
    return allFoods.where((food) {
      switch (nutrient.toLowerCase()) {
        case 'protein':
          return food.nutrition.protein > 10;
        case 'fiber':
          return food.nutrition.fiber > 5;
        case 'iron':
          return food.nutrition.minerals.containsKey('iron') && 
                 (food.nutrition.minerals['iron'] ?? 0) > 2.0;
        default:
          return false;
      }
    }).toList();
  }

  List<String> _generateRecommendationReasons(ScoredFood scored, UserContext context) {
    final reasons = <String>[];
    final food = scored.food;
    
    if (food.nutrition.protein > 10) {
      reasons.add('High in protein (${food.nutrition.protein.toStringAsFixed(1)}g)');
    }
    
    if (food.nutrition.fiber > 5) {
      reasons.add('Good source of fiber (${food.nutrition.fiber.toStringAsFixed(1)}g)');
    }
    
    if (context.healthGoals.contains('Weight loss') && food.nutrition.calories < 150) {
      reasons.add('Low calorie option for weight management');
    }
    
    if (food.regions.primaryRegion.toLowerCase() == context.culturalPreferences['preferredRegion']?.toString().toLowerCase()) {
      reasons.add('Matches your regional cuisine preference');
    }
    
    return reasons;
  }

  List<String> _generateCookingTips(IndianFoodItem food, UserContext context) {
    final tips = <String>[];
    
    if (context.medicalConditions.contains('Diabetes')) {
      tips.add('Cook with minimal oil and avoid adding sugar');
    }
    
    if (context.medicalConditions.contains('Hypertension')) {
      tips.add('Use herbs and spices instead of salt for flavor');
    }
    
    if (food.category == IndianFoodCategory.sabzi) {
      tips.add('Steam or sauté lightly to retain nutrients');
    }
    
    // Add cooking method specific tips
    tips.add(food.cookingMethods.defaultMethod.description);
    
    return tips;
  }

  String _getMealTypeFromCategory(IndianFoodCategory category) {
    switch (category) {
      case IndianFoodCategory.dal:
      case IndianFoodCategory.sabzi:
      case IndianFoodCategory.curry:
        return 'main';
      case IndianFoodCategory.roti:
      case IndianFoodCategory.rice:
        return 'staple';
      case IndianFoodCategory.snack:
        return 'snack';
      case IndianFoodCategory.sweet:
        return 'dessert';
      case IndianFoodCategory.beverage:
        return 'drink';
    }
  }
}

// Data classes for recommendations

enum RecommendationType { healthy, balanced, indulgent, complementary }

class RecommendationResult {
  final List<MealRecommendation> recommendations;
  final UserContext context;
  final bool success;
  final String? error;

  RecommendationResult({
    required this.recommendations,
    required this.context,
    required this.success,
    this.error,
  });
}

class MealPlanResult {
  final Map<String, List<MealRecommendation>> mealPlan;
  final int totalDays;
  final UserContext context;
  final bool success;
  final String? error;

  MealPlanResult({
    required this.mealPlan,
    required this.totalDays,
    required this.context,
    required this.success,
    this.error,
  });
}

class MealRecommendation {
  final IndianFoodItem food;
  final PortionRecommendation portion;
  final double score;
  final List<String> reasons;
  final List<String> cookingTips;

  MealRecommendation({
    required this.food,
    required this.portion,
    required this.score,
    required this.reasons,
    required this.cookingTips,
  });
}

class PortionRecommendation {
  final int grams;
  final String indianUnit;
  final double indianQuantity;
  final int calories;
  final String reason;

  PortionRecommendation({
    required this.grams,
    required this.indianUnit,
    required this.indianQuantity,
    required this.calories,
    required this.reason,
  });
}

class UserContext {
  final int age;
  final String gender;
  final String activityLevel;
  final List<String> healthGoals;
  final List<String> medicalConditions;
  final List<String> allergies;
  final List<String> dietaryNeeds;
  final List<String> foodDislikes;
  final Map<String, dynamic> culturalPreferences;
  final double? bmi;
  final bool isPremium;

  UserContext({
    required this.age,
    required this.gender,
    required this.activityLevel,
    required this.healthGoals,
    required this.medicalConditions,
    required this.allergies,
    required this.dietaryNeeds,
    required this.foodDislikes,
    required this.culturalPreferences,
    this.bmi,
    required this.isPremium,
  });

  factory UserContext.empty() {
    return UserContext(
      age: 25,
      gender: 'Unknown',
      activityLevel: 'Moderate',
      healthGoals: [],
      medicalConditions: [],
      allergies: [],
      dietaryNeeds: [],
      foodDislikes: [],
      culturalPreferences: {},
      isPremium: false,
    );
  }
}

class ScoredFood {
  final IndianFoodItem food;
  final double score;

  ScoredFood({required this.food, required this.score});
}

class NutritionalBalanceAnalysis {
  final double totalCalories;
  final double targetCalories;
  final MacroBalance macroBalance;
  final List<MicronutrientAnalysis> micronutrients;
  final List<String> suggestions;

  NutritionalBalanceAnalysis({
    required this.totalCalories,
    required this.targetCalories,
    required this.macroBalance,
    required this.micronutrients,
    required this.suggestions,
  });
}

class MacroBalance {
  final MacroAnalysis carbs;
  final MacroAnalysis protein;
  final MacroAnalysis fat;

  MacroBalance({
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}

class MacroAnalysis {
  final double current;
  final double target;
  final double percentage;

  MacroAnalysis({
    required this.current,
    required this.target,
    required this.percentage,
  });
}

class MicronutrientAnalysis {
  final String name;
  final double current;
  final double target;
  final double percentage;
  final String status;

  MicronutrientAnalysis({
    required this.name,
    required this.current,
    required this.target,
    required this.percentage,
    required this.status,
  });
}

class NutritionalRecommendations {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;

  NutritionalRecommendations({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
  });
}

class NutrientDeficiency {
  final String nutrient;
  final String severity;

  NutrientDeficiency({required this.nutrient, required this.severity});
}

class IndianPortion {
  final String unit;
  final double quantity;

  IndianPortion({required this.unit, required this.quantity});
}