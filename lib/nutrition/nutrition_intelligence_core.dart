import '../voice/hinglish_processor.dart';
import '../voice/conversation_context_manager.dart';
import '../cultural/cultural_context_engine.dart';
import '../cultural/indian_food_database.dart';
import 'meal_data_models.dart';
import 'meal_logger_service.dart';

/// Central orchestrator for all nutrition-related services
/// Coordinates meal logging, recommendations, and user progress tracking
class NutritionIntelligenceCore {
  final HinglishProcessor _hinglishProcessor;
  final ConversationContextManager _contextManager;
  final CulturalContextEngine _culturalEngine;
  final IndianFoodDatabase _foodDatabase;
  final MealLoggerService _mealLogger;

  NutritionIntelligenceCore({
    required HinglishProcessor hinglishProcessor,
    required ConversationContextManager contextManager,
    required CulturalContextEngine culturalEngine,
    required IndianFoodDatabase foodDatabase,
    required MealLoggerService mealLogger,
  })  : _hinglishProcessor = hinglishProcessor,
        _contextManager = contextManager,
        _culturalEngine = culturalEngine,
        _foodDatabase = foodDatabase,
        _mealLogger = mealLogger;

  /// Process meal logging from voice input
  Future<MealLogResult> processMealLogging(VoiceInput input) async {
    try {
      // Use the meal logger service which already handles the complete flow
      final result = await _mealLogger.logMealFromVoice(
        input.transcription,
        input.metadata['userId'] ?? '',
      );

      // Update conversation context if successful
      if (result.success && result.mealData != null) {
        _contextManager.addMealToContext(
          input.sessionId,
          result.mealData!.toMap(),
        );
      }

      return result;
    } catch (e) {
      return MealLogResult(
        success: false,
        message: 'Error processing meal: $e',
        ambiguities: [],
        confidence: 0.0,
      );
    }
  }

  /// Generate personalized recommendations
  Future<NutritionAdvice> generateRecommendations(UserProfile profile) async {
    try {
      final recommendations = <String>[];
      final data = <String, dynamic>{};

      // Analyze user's dietary goals
      final goalAdvice = _generateGoalBasedAdvice(profile.goals);
      recommendations.addAll(goalAdvice);

      // Consider health conditions
      final healthAdvice = _generateHealthBasedAdvice(profile.conditions);
      recommendations.addAll(healthAdvice);

      // Cultural food recommendations
      final culturalAdvice = _generateCulturalAdvice(profile.preferences);
      recommendations.addAll(culturalAdvice);

      // Activity level recommendations
      final activityAdvice = _generateActivityBasedAdvice(profile.goals.activityLevel);
      recommendations.addAll(activityAdvice);

      // Generate main advice text in Hinglish
      final mainAdvice = _generateMainAdviceText(profile, recommendations);

      data['goalType'] = profile.goals.type.toString();
      data['activityLevel'] = profile.goals.activityLevel.toString();
      data['tier'] = profile.tier.toString();

      return NutritionAdvice(
        advice: mainAdvice,
        recommendations: recommendations,
        data: data,
      );
    } catch (e) {
      return NutritionAdvice(
        advice: 'Sorry, main aapke liye recommendations generate nahi kar paya. Please try again.',
        recommendations: ['Balanced diet lena', 'Regular exercise karna', 'Proper hydration maintain karna'],
        data: {'error': e.toString()},
      );
    }
  }

  /// Answer nutrition queries
  Future<String> answerNutritionQuery(String query, UserContext context) async {
    try {
      // Use the Hinglish processor to analyze the query
      final queryResult = _hinglishProcessor.parseNutritionQuery(query);
      
      // Handle different query types based on content analysis
      if (query.toLowerCase().contains('calorie') || query.toLowerCase().contains('calories')) {
        return await _answerCalorieQuery(query, context);
      } else if (query.toLowerCase().contains('protein')) {
        return await _answerProteinQuery(query, context);
      } else if (query.toLowerCase().contains('weight') || query.toLowerCase().contains('वजन')) {
        return await _answerWeightQuery(query, context);
      } else if (query.toLowerCase().contains('diabetes') || query.toLowerCase().contains('मधुमेह')) {
        return await _answerMedicalQuery(query, context);
      } else if (query.toLowerCase().contains('health') || query.toLowerCase().contains('sehat')) {
        return await _answerHealthQuery(query, context);
      } else {
        return await _answerGeneralQuery(query, context);
      }
    } catch (e) {
      return 'Sorry, main aapka question samajh nahi paya. Kya aap phir se puch sakte hain?';
    }
  }

  /// Update user progress with new meal data
  Future<void> updateUserProgress(MealData meal) async {
    try {
      // Update conversation context with meal data
      _contextManager.addMealToContext('default-session', meal.toMap());
      
      // Update adaptive learning based on user patterns
      await _updateAdaptiveLearning(meal);
    } catch (e) {
      // Log error but don't throw to avoid breaking the flow
      print('Error updating user progress: $e');
    }
  }

  // Helper methods

  List<String> _generateGoalBasedAdvice(DietaryGoals goals) {
    final advice = <String>[];
    
    switch (goals.type) {
      case GoalType.weightLoss:
        advice.addAll([
          'Portion size kam karne ki koshish kariye',
          'High fiber foods jaise sabziyan aur fruits zyada khayiye',
          'Processed foods avoid kariye',
          'Regular meal timing maintain kariye',
        ]);
        break;
      case GoalType.muscleGain:
        advice.addAll([
          'Protein intake badhayiye - dal, paneer, chicken include kariye',
          'Complex carbs jaise brown rice, oats liye',
          'Post-workout meal zaroor liye',
          'Adequate calories maintain kariye',
        ]);
        break;
      case GoalType.maintenance:
        advice.addAll([
          'Balanced diet maintain kariye',
          'Regular exercise continue rakiye',
          'Hydration proper rakiye',
          'Variety of foods include kariye',
        ]);
        break;
    }
    
    return advice;
  }

  List<String> _generateHealthBasedAdvice(HealthConditions conditions) {
    final advice = <String>[];
    
    if (conditions.medicalConditions.contains('diabetes')) {
      advice.addAll([
        'Sugar intake control kariye',
        'Complex carbs choose kariye',
        'Regular meal timing maintain kariye',
      ]);
    }
    
    if (conditions.medicalConditions.contains('hypertension')) {
      advice.addAll([
        'Namak kam kariye',
        'Potassium rich foods jaise banana, spinach liye',
        'Processed foods avoid kariye',
      ]);
    }
    
    if (conditions.allergies.isNotEmpty) {
      advice.add('Apne allergies ke foods avoid kariye: ${conditions.allergies.join(', ')}');
    }
    
    return advice;
  }

  List<String> _generateCulturalAdvice(FoodPreferences preferences) {
    final advice = <String>[];
    
    if (preferences.dietary.contains('vegetarian')) {
      advice.addAll([
        'Dal aur legumes se protein liye',
        'Variety of vegetables include kariye',
        'Nuts aur seeds add kariye',
      ]);
    }
    
    if (preferences.spiceLevel == 'low') {
      advice.add('Mild spices use kariye, digestion ke liye better hai');
    } else if (preferences.spiceLevel == 'high') {
      advice.add('Spicy food ke saath curd ya lassi liye, balance ke liye');
    }
    
    return advice;
  }

  List<String> _generateActivityBasedAdvice(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return [
          'Light exercise start kariye',
          'Calorie intake moderate rakiye',
          'Fiber rich foods zyada liye',
        ];
      case ActivityLevel.lightlyActive:
        return [
          'Protein intake adequate rakiye',
          'Pre-workout snack liye',
          'Hydration maintain kariye',
        ];
      case ActivityLevel.moderatelyActive:
        return [
          'Protein requirements increase hain',
          'Complex carbs pre-workout liye',
          'Recovery foods post-workout liye',
        ];
      case ActivityLevel.veryActive:
        return [
          'High protein diet maintain kariye',
          'Frequent meals liye energy ke liye',
          'Electrolyte balance maintain kariye',
        ];
    }
  }

  String _generateMainAdviceText(UserProfile profile, List<String> recommendations) {
    final name = profile.personalInfo.name;
    final goal = profile.goals.type.toString().split('.').last;
    
    return 'Namaste $name! Aapka goal $goal hai, toh main yeh suggest karunga: ${recommendations.take(3).join(', ')}. Regular follow-up karte rahiye apne progress ke liye!';
  }

  Future<String> _answerCalorieQuery(String query, UserContext context) async {
    // Extract food items from query
    final extractionResult = _hinglishProcessor.extractFoodItems(query);
    
    if (extractionResult.foodItems.isEmpty) {
      return 'Kya aap bata sakte hain kis food ke calories ke baare mein jaanna chahte hain?';
    }
    
    final responses = <String>[];
    for (final foodItem in extractionResult.foodItems) {
      // Try to find nutrition information
      final searchResults = await _foodDatabase.searchFood(foodItem.name);
      if (searchResults.isNotEmpty) {
        final item = searchResults.first;
        responses.add('${foodItem.name} mein approximately ${item.nutrition.calories.toInt()} calories hain per 100g');
      }
    }
    
    return responses.isEmpty 
        ? 'Sorry, main is food ke calories nahi bata paya. Koi aur food try kariye.'
        : responses.join('. ');
  }

  Future<String> _answerProteinQuery(String query, UserContext context) async {
    final extractionResult = _hinglishProcessor.extractFoodItems(query);
    
    if (extractionResult.foodItems.isEmpty) {
      return 'High protein foods: Dal, paneer, chicken, fish, eggs, nuts. Kya specific food ke baare mein jaanna hai?';
    }
    
    final responses = <String>[];
    for (final foodItem in extractionResult.foodItems) {
      final searchResults = await _foodDatabase.searchFood(foodItem.name);
      if (searchResults.isNotEmpty) {
        final item = searchResults.first;
        responses.add('${foodItem.name} mein ${item.nutrition.protein.toStringAsFixed(1)}g protein hai per 100g');
      }
    }
    
    return responses.isEmpty 
        ? 'Protein ke liye dal, paneer, chicken, fish try kariye.'
        : responses.join('. ');
  }

  Future<String> _answerHealthQuery(String query, UserContext context) async {
    if (query.toLowerCase().contains('weight loss') || query.contains('वजन कम')) {
      return 'Weight loss ke liye: portion control, fiber rich foods, regular exercise, aur proper hydration zaroori hai.';
    }
    
    if (query.toLowerCase().contains('diabetes') || query.contains('मधुमेह')) {
      return 'Diabetes control ke liye: complex carbs liye, sugar avoid kariye, regular meal timing rakiye.';
    }
    
    return 'Healthy lifestyle ke liye balanced diet, regular exercise, adequate sleep aur stress management important hai.';
  }

  Future<String> _answerWeightQuery(String query, UserContext context) async {
    final profile = context.profile;
    final goal = profile.goals.type;
    
    if (goal == GoalType.weightLoss) {
      return 'Weight loss ke liye calorie deficit maintain kariye. Protein rich foods liye, portion size control kariye.';
    } else if (goal == GoalType.muscleGain) {
      return 'Muscle gain ke liye protein intake badhayiye, strength training kariye, adequate calories liye.';
    }
    
    return 'Weight management ke liye balanced approach liye - proper diet aur regular exercise.';
  }

  Future<String> _answerMedicalQuery(String query, UserContext context) async {
    return 'Medical concerns ke liye doctor se consult karna best hai. Main general nutrition advice de sakta hun.';
  }

  Future<String> _answerGeneralQuery(String query, UserContext context) async {
    return 'Main aapki nutrition aur meal planning mein help kar sakta hun. Kya specific question hai?';
  }

  Future<void> _updateAdaptiveLearning(MealData meal) async {
    // Update user patterns based on meal data
    // This would typically involve machine learning algorithms
    // For now, we'll update conversation context
    _contextManager.updateUserPreferences(
      'default-session',
      {
        'lastMealTime': meal.timestamp.toIso8601String(),
        'preferredMealType': meal.mealType.toString(),
        'commonFoods': meal.foods.map((item) => item.name).toList(),
      },
    );
  }
}

/// Represents voice input from the user
class VoiceInput {
  final String transcription;
  final DateTime timestamp;
  final String sessionId;
  final Map<String, dynamic> metadata;

  VoiceInput({
    required this.transcription,
    required this.timestamp,
    required this.sessionId,
    required this.metadata,
  });
}

/// Nutrition advice response
class NutritionAdvice {
  final String advice;
  final List<String> recommendations;
  final Map<String, dynamic> data;

  NutritionAdvice({
    required this.advice,
    required this.recommendations,
    required this.data,
  });
}

/// User context for personalized responses
class UserContext {
  final UserProfile profile;
  final List<MealData> recentMeals;
  final Map<String, dynamic> preferences;

  UserContext({
    required this.profile,
    required this.recentMeals,
    required this.preferences,
  });
}

/// User profile for personalized nutrition
class UserProfile {
  final String userId;
  final PersonalInfo personalInfo;
  final DietaryGoals goals;
  final HealthConditions conditions;
  final FoodPreferences preferences;
  final EatingPatterns patterns;
  final SubscriptionTier tier;

  UserProfile({
    required this.userId,
    required this.personalInfo,
    required this.goals,
    required this.conditions,
    required this.preferences,
    required this.patterns,
    required this.tier,
  });
}

class PersonalInfo {
  final String name;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final String location;

  PersonalInfo({
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.location,
  });
}

class DietaryGoals {
  final GoalType type;
  final double targetWeight;
  final int timeframe;
  final ActivityLevel activityLevel;

  DietaryGoals({
    required this.type,
    required this.targetWeight,
    required this.timeframe,
    required this.activityLevel,
  });
}

enum GoalType {
  weightLoss,
  muscleGain,
  maintenance,
}

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
}

class HealthConditions {
  final List<String> allergies;
  final List<String> medicalConditions;
  final List<String> medications;

  HealthConditions({
    required this.allergies,
    required this.medicalConditions,
    required this.medications,
  });
}

class FoodPreferences {
  final List<String> liked;
  final List<String> disliked;
  final List<String> dietary;
  final String spiceLevel;

  FoodPreferences({
    required this.liked,
    required this.disliked,
    required this.dietary,
    required this.spiceLevel,
  });
}

class EatingPatterns {
  final Map<String, String> mealTimes;
  final int mealsPerDay;
  final List<String> snackPreferences;

  EatingPatterns({
    required this.mealTimes,
    required this.mealsPerDay,
    required this.snackPreferences,
  });
}

enum SubscriptionTier {
  free,
  premium,
}