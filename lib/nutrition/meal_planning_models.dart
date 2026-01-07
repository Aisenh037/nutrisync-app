import 'meal_data_models.dart';

/// Represents a complete day's meal plan
class DayMealPlan {
  final DateTime date;
  final MealData breakfast;
  final MealData lunch;
  final MealData dinner;
  final List<MealData> snacks;

  DayMealPlan({
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snacks,
  });

  /// Get all meals for the day
  List<MealData> get allMeals => [breakfast, lunch, dinner, ...snacks];

  /// Calculate total nutrition for the day
  NutritionalSummary get totalNutrition {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;
    
    final Map<String, double> totalVitamins = {};
    final Map<String, double> totalMinerals = {};

    for (final meal in allMeals) {
      totalCalories += meal.nutrition.totalCalories;
      totalProtein += meal.nutrition.totalProtein;
      totalCarbs += meal.nutrition.totalCarbs;
      totalFat += meal.nutrition.totalFat;
      totalFiber += meal.nutrition.totalFiber;

      // Aggregate vitamins
      meal.nutrition.vitamins.forEach((vitamin, amount) {
        totalVitamins[vitamin] = (totalVitamins[vitamin] ?? 0.0) + amount;
      });

      // Aggregate minerals
      meal.nutrition.minerals.forEach((mineral, amount) {
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

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'breakfast': breakfast.toMap(),
      'lunch': lunch.toMap(),
      'dinner': dinner.toMap(),
      'snacks': snacks.map((snack) => snack.toMap()).toList(),
    };
  }

  factory DayMealPlan.fromMap(Map<String, dynamic> map) {
    return DayMealPlan(
      date: DateTime.parse(map['date']),
      breakfast: MealData.fromMap(map['breakfast']),
      lunch: MealData.fromMap(map['lunch']),
      dinner: MealData.fromMap(map['dinner']),
      snacks: (map['snacks'] as List<dynamic>)
          .map((snackMap) => MealData.fromMap(snackMap))
          .toList(),
    );
  }
}

/// Represents a weekly meal plan
class WeeklyMealPlan {
  final DateTime startDate;
  final List<DayMealPlan> days;

  WeeklyMealPlan({
    required this.startDate,
    required this.days,
  });

  /// Get meal plan for a specific day
  DayMealPlan? getMealPlan(DateTime date) {
    return days.firstWhere(
      (day) => day.date.day == date.day && 
               day.date.month == date.month && 
               day.date.year == date.year,
      orElse: () => throw Exception('Meal plan not found for date: $date'),
    );
  }

  /// Calculate average daily nutrition
  NutritionalSummary get averageDailyNutrition {
    if (days.isEmpty) {
      return NutritionalSummary(
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        totalFiber: 0,
        vitamins: {},
        minerals: {},
        macroBreakdown: MacroBreakdown(
          proteinPercentage: 0,
          carbsPercentage: 0,
          fatPercentage: 0,
        ),
      );
    }

    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;
    
    final Map<String, double> totalVitamins = {};
    final Map<String, double> totalMinerals = {};

    for (final day in days) {
      final dayNutrition = day.totalNutrition;
      totalCalories += dayNutrition.totalCalories;
      totalProtein += dayNutrition.totalProtein;
      totalCarbs += dayNutrition.totalCarbs;
      totalFat += dayNutrition.totalFat;
      totalFiber += dayNutrition.totalFiber;

      // Aggregate vitamins
      dayNutrition.vitamins.forEach((vitamin, amount) {
        totalVitamins[vitamin] = (totalVitamins[vitamin] ?? 0.0) + amount;
      });

      // Aggregate minerals
      dayNutrition.minerals.forEach((mineral, amount) {
        totalMinerals[mineral] = (totalMinerals[mineral] ?? 0.0) + amount;
      });
    }

    // Calculate averages
    final dayCount = days.length.toDouble();
    totalCalories /= dayCount;
    totalProtein /= dayCount;
    totalCarbs /= dayCount;
    totalFat /= dayCount;
    totalFiber /= dayCount;

    totalVitamins.updateAll((key, value) => value / dayCount);
    totalMinerals.updateAll((key, value) => value / dayCount);

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

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'days': days.map((day) => day.toMap()).toList(),
    };
  }

  factory WeeklyMealPlan.fromMap(Map<String, dynamic> map) {
    return WeeklyMealPlan(
      startDate: DateTime.parse(map['startDate']),
      days: (map['days'] as List<dynamic>)
          .map((dayMap) => DayMealPlan.fromMap(dayMap))
          .toList(),
    );
  }
}

/// Represents a meal template for easy meal planning
class MealTemplate {
  final String id;
  final String name;
  final MealType mealType;
  final List<FoodItem> foods;
  final String description;
  final List<String> tags;
  final int preparationTimeMinutes;
  final String difficulty;
  final NutritionalSummary nutrition;

  MealTemplate({
    required this.id,
    required this.name,
    required this.mealType,
    required this.foods,
    required this.description,
    required this.tags,
    required this.preparationTimeMinutes,
    required this.difficulty,
    required this.nutrition,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType.toString(),
      'foods': foods.map((food) => food.toMap()).toList(),
      'description': description,
      'tags': tags,
      'preparationTimeMinutes': preparationTimeMinutes,
      'difficulty': difficulty,
      'nutrition': nutrition.toMap(),
    };
  }

  factory MealTemplate.fromMap(Map<String, dynamic> map) {
    return MealTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      mealType: MealType.values.firstWhere(
        (type) => type.toString() == map['mealType'],
        orElse: () => MealType.lunch,
      ),
      foods: (map['foods'] as List<dynamic>)
          .map((foodMap) => FoodItem.fromMap(foodMap))
          .toList(),
      description: map['description'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      preparationTimeMinutes: map['preparationTimeMinutes'] ?? 30,
      difficulty: map['difficulty'] ?? 'medium',
      nutrition: NutritionalSummary.fromMap(map['nutrition'] ?? {}),
    );
  }
}

/// Represents meal planning preferences
class MealPlanningPreferences {
  final List<String> preferredCuisines;
  final List<String> dietaryRestrictions;
  final List<String> dislikedFoods;
  final int maxPreparationTime;
  final String preferredDifficulty;
  final bool includeSnacks;
  final int mealsPerDay;
  final Map<String, String> mealTimes;
  final double budgetPerDay;
  final bool prioritizeHealth;
  final bool prioritizeTaste;
  final bool prioritizeConvenience;

  MealPlanningPreferences({
    required this.preferredCuisines,
    required this.dietaryRestrictions,
    required this.dislikedFoods,
    required this.maxPreparationTime,
    required this.preferredDifficulty,
    required this.includeSnacks,
    required this.mealsPerDay,
    required this.mealTimes,
    required this.budgetPerDay,
    required this.prioritizeHealth,
    required this.prioritizeTaste,
    required this.prioritizeConvenience,
  });

  Map<String, dynamic> toMap() {
    return {
      'preferredCuisines': preferredCuisines,
      'dietaryRestrictions': dietaryRestrictions,
      'dislikedFoods': dislikedFoods,
      'maxPreparationTime': maxPreparationTime,
      'preferredDifficulty': preferredDifficulty,
      'includeSnacks': includeSnacks,
      'mealsPerDay': mealsPerDay,
      'mealTimes': mealTimes,
      'budgetPerDay': budgetPerDay,
      'prioritizeHealth': prioritizeHealth,
      'prioritizeTaste': prioritizeTaste,
      'prioritizeConvenience': prioritizeConvenience,
    };
  }

  factory MealPlanningPreferences.fromMap(Map<String, dynamic> map) {
    return MealPlanningPreferences(
      preferredCuisines: List<String>.from(map['preferredCuisines'] ?? []),
      dietaryRestrictions: List<String>.from(map['dietaryRestrictions'] ?? []),
      dislikedFoods: List<String>.from(map['dislikedFoods'] ?? []),
      maxPreparationTime: map['maxPreparationTime'] ?? 60,
      preferredDifficulty: map['preferredDifficulty'] ?? 'medium',
      includeSnacks: map['includeSnacks'] ?? true,
      mealsPerDay: map['mealsPerDay'] ?? 3,
      mealTimes: Map<String, String>.from(map['mealTimes'] ?? {}),
      budgetPerDay: (map['budgetPerDay'] as num?)?.toDouble() ?? 500.0,
      prioritizeHealth: map['prioritizeHealth'] ?? true,
      prioritizeTaste: map['prioritizeTaste'] ?? true,
      prioritizeConvenience: map['prioritizeConvenience'] ?? false,
    );
  }

  factory MealPlanningPreferences.defaultPreferences() {
    return MealPlanningPreferences(
      preferredCuisines: ['Indian', 'North Indian', 'South Indian'],
      dietaryRestrictions: ['vegetarian'],
      dislikedFoods: [],
      maxPreparationTime: 45,
      preferredDifficulty: 'medium',
      includeSnacks: true,
      mealsPerDay: 3,
      mealTimes: {
        'breakfast': '08:00',
        'lunch': '13:00',
        'dinner': '20:00',
      },
      budgetPerDay: 400.0,
      prioritizeHealth: true,
      prioritizeTaste: true,
      prioritizeConvenience: false,
    );
  }
}