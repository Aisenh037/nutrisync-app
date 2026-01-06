import '../models/user_model.dart';
import '../cultural/indian_food_database.dart';
import '../cultural/cultural_context_engine.dart';
import '../nutrition/meal_data_models.dart';

/// Educational component providing tips for healthier Indian cooking methods
/// and culturally appropriate nutrition explanations
class IndianCookingEducation {
  
  /// Get cooking tips for a specific Indian food item
  List<CookingTip> getCookingTips({
    required IndianFoodItem food,
    UserModel? user,
  }) {
    final tips = <CookingTip>[];
    
    // Add category-specific tips
    tips.addAll(_getCategorySpecificTips(food.category));
    
    // Add cooking method improvements
    tips.addAll(_getCookingMethodTips(food.cookingMethods.defaultMethod));
    
    // Add health-specific tips based on user profile
    if (user != null) {
      tips.addAll(_getHealthSpecificTips(food, user));
    }
    
    // Add general Indian cooking tips
    tips.addAll(_getGeneralIndianCookingTips(food));
    
    return tips;
  }

  /// Get nutrition explanation in simple, culturally appropriate terms
  NutritionExplanation explainNutrition({
    required IndianFoodItem food,
    UserModel? user,
  }) {
    final benefits = <String>[];
    final concerns = <String>[];
    final improvements = <String>[];
    
    final nutrition = food.nutrition;
    
    // Explain macronutrients in simple terms
    if (nutrition.protein > 10) {
      benefits.add('${food.name} is rich in protein (${nutrition.protein.toStringAsFixed(1)}g), which helps build strong muscles and keeps you full longer');
    }
    
    if (nutrition.fiber > 5) {
      benefits.add('High fiber content (${nutrition.fiber.toStringAsFixed(1)}g) helps with digestion and keeps your stomach healthy');
    }
    
    if (nutrition.calories > 300) {
      concerns.add('This dish is quite heavy in calories (${nutrition.calories.toStringAsFixed(0)} per serving). Consider smaller portions if you\'re watching your weight');
    }
    
    // Add vitamin and mineral explanations
    benefits.addAll(_explainMicronutrients(nutrition.vitamins, nutrition.minerals));
    
    // Add user-specific explanations
    if (user != null) {
      improvements.addAll(_getUserSpecificAdvice(food, user));
    }
    
    // Add cooking improvements
    improvements.addAll(_getCookingImprovements(food));
    
    return NutritionExplanation(
      foodName: food.name,
      benefits: benefits,
      concerns: concerns,
      improvements: improvements,
      culturalContext: _getCulturalNutritionContext(food),
    );
  }

  /// Get healthy cooking alternatives for traditional Indian methods
  List<CookingAlternative> getHealthierAlternatives({
    required String cookingMethod,
    required IndianFoodCategory category,
  }) {
    final alternatives = <CookingAlternative>[];
    
    switch (cookingMethod.toLowerCase()) {
      case 'deep frying':
      case 'frying':
        alternatives.addAll([
          CookingAlternative(
            original: 'Deep frying',
            healthier: 'Air frying or shallow frying with minimal oil',
            benefit: 'Reduces oil content by 70-80% while keeping the crispy texture',
            hinglishTip: 'Thoda sa oil use karke air fryer mein banayiye - taste same, health better!',
          ),
          CookingAlternative(
            original: 'Deep frying',
            healthier: 'Baking with light oil spray',
            benefit: 'Almost oil-free cooking that retains flavors',
            hinglishTip: 'Oven mein bake karo with oil spray - guilt-free khana!',
          ),
        ]);
        break;
        
      case 'tadka':
      case 'tempering':
        alternatives.add(
          CookingAlternative(
            original: 'Heavy oil tadka',
            healthier: 'Light tadka with mustard oil or ghee',
            benefit: 'Maintains authentic flavor while reducing excess oil',
            hinglishTip: 'Kam oil mein tadka lagao - flavor same rahega, health better hoga!',
          ),
        );
        break;
        
      case 'bhuna':
        alternatives.add(
          CookingAlternative(
            original: 'Oil-heavy bhuna',
            healthier: 'Steam-bhuna with minimal oil',
            benefit: 'Uses steam to cook while reducing oil content',
            hinglishTip: 'Pehle steam karo, phir thoda oil mein bhuno - perfect texture!',
          ),
        );
        break;
    }
    
    // Add category-specific alternatives
    alternatives.addAll(_getCategoryAlternatives(category));
    
    return alternatives;
  }

  /// Get portion control advice using Indian references
  PortionAdvice getPortionAdvice({
    required IndianFoodItem food,
    required UserModel user,
  }) {
    final advice = <String>[];
    final visualGuides = <String>[];
    
    // Add portion size recommendations
    if (food.category == IndianFoodCategory.rice) {
      advice.add('Rice portion should be about 1 katori (150g) for main meals');
      visualGuides.add('1 katori = size of your cupped palm');
      
      if (user.healthGoals.contains('Weight loss')) {
        advice.add('For weight loss, try 3/4 katori rice and add more vegetables');
        visualGuides.add('Fill half your plate with sabzi, quarter with rice, quarter with dal');
      }
    }
    
    if (food.category == IndianFoodCategory.roti) {
      advice.add('2-3 medium rotis are usually enough for one meal');
      visualGuides.add('1 roti = size of a small plate (6-7 inches)');
      
      if (user.healthGoals.contains('Muscle building')) {
        advice.add('Add 1 extra roti and pair with protein-rich dal or paneer');
      }
    }
    
    if (food.category == IndianFoodCategory.dal) {
      advice.add('1 katori dal provides good protein for your meal');
      visualGuides.add('Dal should be thick enough to coat the back of a spoon');
    }
    
    // Add health-specific portion advice
    if (user.medicalConditions.contains('Diabetes')) {
      advice.add('Keep portions smaller and eat slowly to help control blood sugar');
      visualGuides.add('Use smaller plates and katoris to naturally control portions');
    }
    
    return PortionAdvice(
      foodName: food.name,
      generalAdvice: advice,
      visualGuides: visualGuides,
      healthSpecificTips: _getHealthSpecificPortionTips(user),
    );
  }

  /// Get meal combination suggestions for balanced nutrition
  List<MealCombination> getMealCombinations({
    required IndianFoodItem primaryFood,
    UserModel? user,
  }) {
    final combinations = <MealCombination>[];
    
    switch (primaryFood.category) {
      case IndianFoodCategory.rice:
        combinations.addAll([
          MealCombination(
            primary: primaryFood.name,
            companions: ['Dal', 'Mixed vegetables', 'Raita'],
            nutritionalBenefit: 'Complete protein from rice + dal, fiber from vegetables, probiotics from raita',
            culturalNote: 'Classic dal-chawal combination - comfort food that\'s nutritionally complete',
            hinglishTip: 'Rice ke saath dal aur sabzi zaroor khao - perfect balance!',
          ),
          MealCombination(
            primary: primaryFood.name,
            companions: ['Rajma', 'Pickle', 'Onion salad'],
            nutritionalBenefit: 'High protein from rajma, antioxidants from onions',
            culturalNote: 'North Indian favorite - rajma-chawal',
            hinglishTip: 'Rajma-chawal with kachumber salad - protein aur vitamins dono mil jaate hain!',
          ),
        ]);
        break;
        
      case IndianFoodCategory.roti:
        combinations.addAll([
          MealCombination(
            primary: primaryFood.name,
            companions: ['Seasonal vegetables', 'Dal', 'Curd'],
            nutritionalBenefit: 'Complex carbs from roti, vitamins from vegetables, protein from dal',
            culturalNote: 'Traditional Indian thali combination',
            hinglishTip: 'Roti ke saath different sabzi try karo - variety aur nutrition dono!',
          ),
        ]);
        break;
        
      case IndianFoodCategory.dal:
        combinations.add(
          MealCombination(
            primary: primaryFood.name,
            companions: ['Brown rice or roti', 'Green vegetables', 'Salad'],
            nutritionalBenefit: 'Complete amino acid profile, high fiber, vitamins',
            culturalNote: 'Dal is the protein powerhouse of Indian cuisine',
            hinglishTip: 'Dal mein onion, tomato, garlic add karo - taste aur nutrition boost!',
          ),
        );
        break;
        
      default:
        combinations.add(
          MealCombination(
            primary: primaryFood.name,
            companions: ['Roti or rice', 'Dal', 'Salad'],
            nutritionalBenefit: 'Balanced macronutrients and micronutrients',
            culturalNote: 'Standard Indian meal structure',
            hinglishTip: 'Har meal mein carbs, protein aur vegetables ka balance rakhiye!',
          ),
        );
    }
    
    return combinations;
  }

  // Private helper methods
  
  List<CookingTip> _getCategorySpecificTips(IndianFoodCategory category) {
    switch (category) {
      case IndianFoodCategory.dal:
        return [
          CookingTip(
            category: 'Dal Cooking',
            tip: 'Soak lentils for 30 minutes before cooking to reduce cooking time and improve digestibility',
            benefit: 'Better nutrient absorption and easier digestion',
            hinglishTip: 'Dal ko pehle bhigo kar rakhiye - jaldi pakegi aur pet mein bhi achhi lagegi!',
          ),
          CookingTip(
            category: 'Dal Seasoning',
            tip: 'Add turmeric and a pinch of hing (asafoetida) while cooking dal',
            benefit: 'Anti-inflammatory properties and better digestion',
            hinglishTip: 'Haldi aur hing dal mein zaroor daliye - health ke liye bahut achha hai!',
          ),
        ];
        
      case IndianFoodCategory.sabzi:
        return [
          CookingTip(
            category: 'Vegetable Cooking',
            tip: 'Don\'t overcook vegetables - they should retain some crunch and bright color',
            benefit: 'Preserves vitamins and minerals',
            hinglishTip: 'Sabzi ko zyada mat pakao - vitamins kharab ho jaate hain!',
          ),
          CookingTip(
            category: 'Oil Usage',
            tip: 'Use 1-2 teaspoons of oil per serving instead of heavy oil',
            benefit: 'Reduces calories while maintaining taste',
            hinglishTip: 'Kam oil mein banao sabzi - taste same, calories kam!',
          ),
        ];
        
      case IndianFoodCategory.rice:
        return [
          CookingTip(
            category: 'Rice Preparation',
            tip: 'Wash rice thoroughly and use 1.5 cups water per cup of rice',
            benefit: 'Removes excess starch and prevents sticky rice',
            hinglishTip: 'Chawal ko achhe se dho kar pakao - fluffy aur separate grains milenge!',
          ),
        ];
        
      case IndianFoodCategory.roti:
        return [
          CookingTip(
            category: 'Roti Making',
            tip: 'Use whole wheat flour and add a pinch of salt to the dough',
            benefit: 'More fiber and better taste',
            hinglishTip: 'Gehun ka atta use karo aur thoda namak dalo - soft roti banegi!',
          ),
        ];
        
      default:
        return [];
    }
  }

  List<CookingTip> _getCookingMethodTips(CookingMethod method) {
    final tips = <CookingTip>[];
    
    switch (method.name.toLowerCase()) {
      case 'dum':
        tips.add(
          CookingTip(
            category: 'Dum Cooking',
            tip: 'Use heavy-bottomed pot and cook on low heat for authentic dum cooking',
            benefit: 'Even cooking and enhanced flavors',
            hinglishTip: 'Dum cooking ke liye heavy bottom ka bartan use karo - flavors achhe aate hain!',
          ),
        );
        break;
        
      case 'tadka':
        tips.add(
          CookingTip(
            category: 'Tadka Technique',
            tip: 'Heat oil until it shimmers, then add whole spices first',
            benefit: 'Maximum flavor extraction from spices',
            hinglishTip: 'Tadka mein pehle sabut masale dalo, phir powder - aroma achha aayega!',
          ),
        );
        break;
        
      case 'bhuna':
        tips.add(
          CookingTip(
            category: 'Bhuna Method',
            tip: 'Cook on medium heat and stir frequently to prevent sticking',
            benefit: 'Even browning and rich flavor development',
            hinglishTip: 'Bhuna karte time medium heat pe rakhiye aur chalate rahiye!',
          ),
        );
        break;
    }
    
    return tips;
  }

  List<CookingTip> _getHealthSpecificTips(IndianFoodItem food, UserModel user) {
    final tips = <CookingTip>[];
    
    if (user.medicalConditions.contains('Diabetes')) {
      tips.add(
        CookingTip(
          category: 'Diabetes-Friendly',
          tip: 'Add extra vegetables and reduce oil to make ${food.name} more diabetes-friendly',
          benefit: 'Lower glycemic index and better blood sugar control',
          hinglishTip: 'Diabetes hai to zyada sabzi aur kam oil use karo - sugar control rahega!',
        ),
      );
    }
    
    if (user.medicalConditions.contains('Hypertension')) {
      tips.add(
        CookingTip(
          category: 'Heart-Healthy',
          tip: 'Use herbs and spices instead of extra salt for flavoring ${food.name}',
          benefit: 'Reduces sodium intake while maintaining taste',
          hinglishTip: 'BP high hai to namak kam karo, masale zyada use karo - taste bhi achha, health bhi!',
        ),
      );
    }
    
    if (user.healthGoals.contains('Weight loss')) {
      tips.add(
        CookingTip(
          category: 'Weight Management',
          tip: 'Steam or grill instead of frying, and add more vegetables to ${food.name}',
          benefit: 'Reduces calories while increasing nutrient density',
          hinglishTip: 'Weight loss ke liye fry mat karo, steam ya grill karo - calories kam, nutrition zyada!',
        ),
      );
    }
    
    return tips;
  }

  List<CookingTip> _getGeneralIndianCookingTips(IndianFoodItem food) {
    return [
      CookingTip(
        category: 'Spice Usage',
        tip: 'Toast whole spices lightly before grinding for better flavor',
        benefit: 'Enhanced aroma and taste',
        hinglishTip: 'Masale ko halka sa bhun kar piso - smell aur taste dono achha aayega!',
      ),
      CookingTip(
        category: 'Fresh Ingredients',
        tip: 'Use fresh ginger-garlic paste instead of store-bought for better nutrition',
        benefit: 'More antioxidants and authentic flavor',
        hinglishTip: 'Ghar ka bana adrak-lehsun paste use karo - fresh aur healthy!',
      ),
    ];
  }

  List<String> _explainMicronutrients(Map<String, double> vitamins, Map<String, double> minerals) {
    final explanations = <String>[];
    
    if (vitamins.containsKey('C') && vitamins['C']! > 10) {
      explanations.add('Rich in Vitamin C which boosts immunity and helps fight infections');
    }
    
    if (vitamins.containsKey('B1') && vitamins['B1']! > 0.1) {
      explanations.add('Contains Vitamin B1 which helps convert food into energy');
    }
    
    if (minerals.containsKey('iron') && minerals['iron']! > 2) {
      explanations.add('Good source of iron which prevents anemia and keeps you energetic');
    }
    
    if (minerals.containsKey('potassium') && minerals['potassium']! > 200) {
      explanations.add('High in potassium which is good for heart health and blood pressure');
    }
    
    return explanations;
  }

  List<String> _getUserSpecificAdvice(IndianFoodItem food, UserModel user) {
    final advice = <String>[];
    
    if (user.healthGoals.contains('Weight loss')) {
      if (food.nutrition.calories > 200) {
        advice.add('For weight loss, have smaller portions and pair with salad or vegetables');
      } else if (food.category == IndianFoodCategory.rice || food.nutrition.carbs > 20) {
        advice.add('For weight loss, control portion size and pair with protein and vegetables');
      } else if (food.category == IndianFoodCategory.dal) {
        advice.add('For weight loss, dal is great for protein but watch portion sizes');
      }
    }
    
    if (user.healthGoals.contains('Muscle building') && food.nutrition.protein < 10) {
      advice.add('Add paneer, dal, or nuts to increase protein content for muscle building');
    }
    
    if (user.medicalConditions.contains('Diabetes') && food.nutrition.carbs > 20) {
      advice.add('Eat this with fiber-rich vegetables to slow down sugar absorption');
    }
    
    return advice;
  }

  List<String> _getCookingImprovements(IndianFoodItem food) {
    final improvements = <String>[];
    
    if (food.cookingMethods.defaultMethod.commonIngredients.any((ing) => ing.toLowerCase().contains('oil'))) {
      improvements.add('Try using less oil or switch to healthier oils like mustard or olive oil');
    }
    
    if (food.category == IndianFoodCategory.sabzi) {
      improvements.add('Add colorful vegetables to increase vitamin and antioxidant content');
    }
    
    improvements.add('Use fresh herbs like coriander and mint for extra vitamins and flavor');
    
    return improvements;
  }

  String _getCulturalNutritionContext(IndianFoodItem food) {
    switch (food.category) {
      case IndianFoodCategory.dal:
        return 'Dal is considered the protein backbone of Indian vegetarian diet. Our ancestors knew that dal + rice gives complete protein!';
      case IndianFoodCategory.rice:
        return 'Rice provides quick energy and is easily digestible. In Indian tradition, rice is often the first solid food given to babies.';
      case IndianFoodCategory.sabzi:
        return 'Vegetables in Indian cooking are not just side dishes - they\'re packed with spices that have medicinal properties.';
      case IndianFoodCategory.roti:
        return 'Roti made from whole wheat is a complete food that provides sustained energy throughout the day.';
      default:
        return 'This food is part of India\'s rich culinary tradition that balances taste with nutrition.';
    }
  }

  List<CookingAlternative> _getCategoryAlternatives(IndianFoodCategory category) {
    switch (category) {
      case IndianFoodCategory.sabzi:
        return [
          CookingAlternative(
            original: 'Heavy oil sabzi',
            healthier: 'Steam-sauté with minimal oil',
            benefit: 'Retains nutrients and reduces calories',
            hinglishTip: 'Sabzi ko pehle steam karo, phir thoda oil mein toss karo!',
          ),
        ];
      case IndianFoodCategory.dal:
        return [
          CookingAlternative(
            original: 'Heavy tadka dal',
            healthier: 'Light tadka with mustard oil',
            benefit: 'Authentic flavor with less oil',
            hinglishTip: 'Dal mein sarson ka tel use karo - healthy aur tasty!',
          ),
        ];
      default:
        return [];
    }
  }

  List<String> _getHealthSpecificPortionTips(UserModel user) {
    final tips = <String>[];
    
    if (user.medicalConditions.contains('Diabetes')) {
      tips.add('Eat smaller, frequent meals to keep blood sugar stable');
      tips.add('Fill half your plate with vegetables, quarter with protein, quarter with carbs');
    }
    
    if (user.healthGoals.contains('Weight loss')) {
      tips.add('Use smaller plates and bowls to naturally control portions');
      tips.add('Eat slowly and chew well - it takes 20 minutes to feel full');
    }
    
    if (user.healthGoals.contains('Muscle building')) {
      tips.add('Include protein in every meal - aim for palm-sized portions');
      tips.add('Don\'t skip meals - eat every 3-4 hours to support muscle growth');
    }
    
    return tips;
  }
}

// Data classes for cooking education

class CookingTip {
  final String category;
  final String tip;
  final String benefit;
  final String hinglishTip;

  CookingTip({
    required this.category,
    required this.tip,
    required this.benefit,
    required this.hinglishTip,
  });
}

class NutritionExplanation {
  final String foodName;
  final List<String> benefits;
  final List<String> concerns;
  final List<String> improvements;
  final String culturalContext;

  NutritionExplanation({
    required this.foodName,
    required this.benefits,
    required this.concerns,
    required this.improvements,
    required this.culturalContext,
  });
}

class CookingAlternative {
  final String original;
  final String healthier;
  final String benefit;
  final String hinglishTip;

  CookingAlternative({
    required this.original,
    required this.healthier,
    required this.benefit,
    required this.hinglishTip,
  });
}

class PortionAdvice {
  final String foodName;
  final List<String> generalAdvice;
  final List<String> visualGuides;
  final List<String> healthSpecificTips;

  PortionAdvice({
    required this.foodName,
    required this.generalAdvice,
    required this.visualGuides,
    required this.healthSpecificTips,
  });
}

class MealCombination {
  final String primary;
  final List<String> companions;
  final String nutritionalBenefit;
  final String culturalNote;
  final String hinglishTip;

  MealCombination({
    required this.primary,
    required this.companions,
    required this.nutritionalBenefit,
    required this.culturalNote,
    required this.hinglishTip,
  });
}