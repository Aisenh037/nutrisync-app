import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/indian_cooking_education.dart';
import 'package:nutrisync/models/user_model.dart';
import 'package:nutrisync/cultural/indian_food_database.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';

void main() {
  group('IndianCookingEducation Tests', () {
    late IndianCookingEducation cookingEducation;
    late UserModel testUser;
    late IndianFoodItem testDal;
    late IndianFoodItem testRice;
    late IndianFoodItem testSabzi;

    setUp(() {
      cookingEducation = IndianCookingEducation();
      
      testUser = UserModel(
        uid: 'test-uid',
        name: 'Test User',
        email: 'test@example.com',
        age: 30,
        gender: 'Male',
        healthGoals: ['Weight loss'],
        medicalConditions: ['Diabetes'],
        allergies: [],
        dietaryNeeds: ['Vegetarian'],
      );

      testDal = IndianFoodItem(
        id: 'test_dal',
        name: 'Dal Tadka',
        aliases: ['dal'],
        nutrition: NutritionalInfo(
          calories: 150.0,
          protein: 12.0,
          carbs: 20.0,
          fat: 4.0,
          fiber: 8.0,
          vitamins: {'B1': 0.3, 'C': 15.0},
          minerals: {'iron': 3.5, 'potassium': 350.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'tadka',
            description: 'Tempered with spices',
            nutritionMultiplier: 1.0,
            commonIngredients: ['lentils', 'oil', 'spices'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 150.0},
          visualReference: '1 katori',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian'],
          regionalNames: {},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['rice', 'roti'],
        searchTerms: ['dal'],
        baseDish: 'dal',
        regionalVariations: [],
      );

      testRice = IndianFoodItem(
        id: 'test_rice',
        name: 'Basmati Rice',
        aliases: ['rice'],
        nutrition: NutritionalInfo(
          calories: 130.0,
          protein: 2.7,
          carbs: 28.0,
          fat: 0.3,
          fiber: 0.4,
          vitamins: {'B1': 0.07},
          minerals: {'iron': 0.8},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'boiled',
            description: 'Boiled in water',
            nutritionMultiplier: 1.0,
            commonIngredients: ['rice', 'water'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 150.0},
          visualReference: '1 katori',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North Indian', 'South Indian'],
          regionalNames: {},
        ),
        category: IndianFoodCategory.rice,
        commonCombinations: ['dal', 'curry'],
        searchTerms: ['rice'],
        baseDish: 'rice',
        regionalVariations: [],
      );

      testSabzi = IndianFoodItem(
        id: 'test_sabzi',
        name: 'Mixed Vegetables',
        aliases: ['sabzi'],
        nutrition: NutritionalInfo(
          calories: 80.0,
          protein: 3.0,
          carbs: 15.0,
          fat: 2.0,
          fiber: 5.0,
          vitamins: {'C': 45.0, 'K': 20.0},
          minerals: {'potassium': 300.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'bhuna',
            description: 'Sautéed with spices',
            nutritionMultiplier: 1.0,
            commonIngredients: ['vegetables', 'oil', 'spices'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 100.0},
          visualReference: '1 katori',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North Indian', 'South Indian'],
          regionalNames: {},
        ),
        category: IndianFoodCategory.sabzi,
        commonCombinations: ['roti', 'rice'],
        searchTerms: ['sabzi'],
        baseDish: 'sabzi',
        regionalVariations: [],
      );
    });

    group('Cooking Tips', () {
      test('getCookingTips returns category-specific tips for dal', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testDal);

        // Assert
        expect(tips, isNotEmpty);
        expect(tips.any((tip) => tip.category.contains('Dal')), isTrue);
        expect(tips.any((tip) => tip.hinglishTip.isNotEmpty), isTrue);
        
        // Should contain dal-specific advice
        final dalTips = tips.where((tip) => tip.category.contains('Dal')).toList();
        expect(dalTips, isNotEmpty);
        expect(dalTips.any((tip) => tip.tip.toLowerCase().contains('soak')), isTrue);
      });

      test('getCookingTips includes health-specific tips for user with diabetes', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testDal, user: testUser);

        // Assert
        expect(tips, isNotEmpty);
        
        // Should contain diabetes-specific advice
        final diabetesTips = tips.where((tip) => tip.category.contains('Diabetes')).toList();
        expect(diabetesTips, isNotEmpty);
        expect(diabetesTips.first.tip.toLowerCase().contains('diabetes'), isTrue);
      });

      test('getCookingTips includes cooking method specific tips', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testDal);

        // Assert
        expect(tips, isNotEmpty);
        
        // Should contain tadka-specific advice since testDal uses tadka method
        final tadkaTips = tips.where((tip) => tip.category.contains('Tadka')).toList();
        expect(tadkaTips, isNotEmpty);
        expect(tadkaTips.first.tip.toLowerCase().contains('spice'), isTrue);
      });

      test('getCookingTips provides general Indian cooking tips', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testSabzi);

        // Assert
        expect(tips, isNotEmpty);
        
        // Should contain general tips
        final generalTips = tips.where((tip) => 
          tip.category.contains('Spice') || tip.category.contains('Fresh')).toList();
        expect(generalTips, isNotEmpty);
      });
    });

    group('Nutrition Explanation', () {
      test('explainNutrition provides comprehensive explanation for high-protein food', () {
        // Act
        final explanation = cookingEducation.explainNutrition(food: testDal);

        // Assert
        expect(explanation.foodName, equals('Dal Tadka'));
        expect(explanation.benefits, isNotEmpty);
        expect(explanation.culturalContext, isNotEmpty);
        
        // Should mention protein since dal is high in protein
        expect(explanation.benefits.any((benefit) => benefit.toLowerCase().contains('protein')), isTrue);
        
        // Should mention fiber since dal is high in fiber
        expect(explanation.benefits.any((benefit) => benefit.toLowerCase().contains('fiber')), isTrue);
      });

      test('explainNutrition includes vitamin and mineral explanations', () {
        // Act
        final explanation = cookingEducation.explainNutrition(food: testDal);

        // Assert
        expect(explanation.benefits, isNotEmpty);
        
        // Should explain iron content
        expect(explanation.benefits.any((benefit) => benefit.toLowerCase().contains('iron')), isTrue);
        
        // Should explain potassium content
        expect(explanation.benefits.any((benefit) => benefit.toLowerCase().contains('potassium')), isTrue);
      });

      test('explainNutrition provides user-specific advice', () {
        // Act
        final explanation = cookingEducation.explainNutrition(food: testRice, user: testUser);

        // Assert
        expect(explanation.improvements, isNotEmpty);
        
        // Should provide weight loss advice since user has weight loss goal
        expect(explanation.improvements.any((advice) => 
          advice.toLowerCase().contains('weight') || advice.toLowerCase().contains('portion')), isTrue);
      });

      test('explainNutrition includes cultural context', () {
        // Act
        final explanation = cookingEducation.explainNutrition(food: testDal);

        // Assert
        expect(explanation.culturalContext, isNotEmpty);
        expect(explanation.culturalContext.toLowerCase().contains('protein'), isTrue);
        expect(explanation.culturalContext.toLowerCase().contains('indian'), isTrue);
      });
    });

    group('Healthier Alternatives', () {
      test('getHealthierAlternatives provides alternatives for deep frying', () {
        // Act
        final alternatives = cookingEducation.getHealthierAlternatives(
          cookingMethod: 'deep frying',
          category: IndianFoodCategory.sabzi,
        );

        // Assert
        expect(alternatives, isNotEmpty);
        expect(alternatives.any((alt) => alt.healthier.toLowerCase().contains('air fry')), isTrue);
        expect(alternatives.any((alt) => alt.healthier.toLowerCase().contains('baking')), isTrue);
        
        // Should include Hinglish tips
        expect(alternatives.every((alt) => alt.hinglishTip.isNotEmpty), isTrue);
      });

      test('getHealthierAlternatives provides alternatives for tadka', () {
        // Act
        final alternatives = cookingEducation.getHealthierAlternatives(
          cookingMethod: 'tadka',
          category: IndianFoodCategory.dal,
        );

        // Assert
        expect(alternatives, isNotEmpty);
        expect(alternatives.first.original.toLowerCase().contains('oil'), isTrue);
        expect(alternatives.first.healthier.toLowerCase().contains('light'), isTrue);
      });

      test('getHealthierAlternatives includes category-specific alternatives', () {
        // Act
        final alternatives = cookingEducation.getHealthierAlternatives(
          cookingMethod: 'bhuna',
          category: IndianFoodCategory.sabzi,
        );

        // Assert
        expect(alternatives, isNotEmpty);
        
        // Should include sabzi-specific alternatives
        final sabziAlternatives = alternatives.where((alt) => 
          alt.healthier.toLowerCase().contains('steam')).toList();
        expect(sabziAlternatives, isNotEmpty);
      });
    });

    group('Portion Advice', () {
      test('getPortionAdvice provides rice-specific portion guidance', () {
        // Act
        final advice = cookingEducation.getPortionAdvice(food: testRice, user: testUser);

        // Assert
        expect(advice.foodName, equals('Basmati Rice'));
        expect(advice.generalAdvice, isNotEmpty);
        expect(advice.visualGuides, isNotEmpty);
        
        // Should mention katori for rice
        expect(advice.generalAdvice.any((tip) => tip.toLowerCase().contains('katori')), isTrue);
        
        // Should provide visual reference
        expect(advice.visualGuides.any((guide) => guide.toLowerCase().contains('palm')), isTrue);
      });

      test('getPortionAdvice includes health-specific tips for weight loss', () {
        // Act
        final advice = cookingEducation.getPortionAdvice(food: testRice, user: testUser);

        // Assert
        expect(advice.generalAdvice, isNotEmpty);
        
        // Should provide weight loss specific advice
        expect(advice.generalAdvice.any((tip) => 
          tip.toLowerCase().contains('weight loss') || tip.toLowerCase().contains('smaller')), isTrue);
      });

      test('getPortionAdvice provides diabetes-specific tips', () {
        // Act
        final advice = cookingEducation.getPortionAdvice(food: testRice, user: testUser);

        // Assert
        expect(advice.healthSpecificTips, isNotEmpty);
        
        // Should include diabetes advice
        expect(advice.healthSpecificTips.any((tip) => 
          tip.toLowerCase().contains('blood sugar') || tip.toLowerCase().contains('frequent')), isTrue);
      });
    });

    group('Meal Combinations', () {
      test('getMealCombinations provides appropriate combinations for rice', () {
        // Act
        final combinations = cookingEducation.getMealCombinations(primaryFood: testRice);

        // Assert
        expect(combinations, isNotEmpty);
        
        // Should suggest dal-chawal combination
        expect(combinations.any((combo) => 
          combo.companions.any((comp) => comp.toLowerCase().contains('dal'))), isTrue);
        
        // Should include nutritional benefits
        expect(combinations.every((combo) => combo.nutritionalBenefit.isNotEmpty), isTrue);
        
        // Should include cultural notes
        expect(combinations.every((combo) => combo.culturalNote.isNotEmpty), isTrue);
        
        // Should include Hinglish tips
        expect(combinations.every((combo) => combo.hinglishTip.isNotEmpty), isTrue);
      });

      test('getMealCombinations provides roti combinations', () {
        // Arrange
        final rotiFood = testRice.copyWith(category: IndianFoodCategory.roti);

        // Act
        final combinations = cookingEducation.getMealCombinations(primaryFood: rotiFood);

        // Assert
        expect(combinations, isNotEmpty);
        expect(combinations.first.companions.any((comp) => 
          comp.toLowerCase().contains('vegetables') || comp.toLowerCase().contains('dal')), isTrue);
      });

      test('getMealCombinations provides dal combinations', () {
        // Act
        final combinations = cookingEducation.getMealCombinations(primaryFood: testDal);

        // Assert
        expect(combinations, isNotEmpty);
        expect(combinations.first.companions.any((comp) => 
          comp.toLowerCase().contains('rice') || comp.toLowerCase().contains('roti')), isTrue);
        
        // Should mention complete amino acids for dal
        expect(combinations.first.nutritionalBenefit.toLowerCase().contains('amino'), isTrue);
      });
    });

    group('Integration Tests', () {
      test('all methods work together for comprehensive food education', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testDal, user: testUser);
        final explanation = cookingEducation.explainNutrition(food: testDal, user: testUser);
        final alternatives = cookingEducation.getHealthierAlternatives(
          cookingMethod: 'tadka',
          category: IndianFoodCategory.dal,
        );
        final portionAdvice = cookingEducation.getPortionAdvice(food: testDal, user: testUser);
        final combinations = cookingEducation.getMealCombinations(primaryFood: testDal, user: testUser);

        // Assert - All methods should return meaningful results
        expect(tips, isNotEmpty);
        expect(explanation.benefits, isNotEmpty);
        expect(alternatives, isNotEmpty);
        expect(portionAdvice.generalAdvice, isNotEmpty);
        expect(combinations, isNotEmpty);
        
        // All should consider user's health conditions
        expect(tips.any((tip) => tip.category.contains('Diabetes')), isTrue);
        expect(explanation.improvements.any((imp) => imp.toLowerCase().contains('weight')), isTrue);
        expect(portionAdvice.healthSpecificTips.any((tip) => tip.toLowerCase().contains('blood sugar')), isTrue);
      });

      test('provides culturally appropriate advice in Hinglish', () {
        // Act
        final tips = cookingEducation.getCookingTips(food: testSabzi);
        final alternatives = cookingEducation.getHealthierAlternatives(
          cookingMethod: 'bhuna',
          category: IndianFoodCategory.sabzi,
        );
        final combinations = cookingEducation.getMealCombinations(primaryFood: testSabzi);

        // Assert - Should include Hinglish phrases
        expect(tips.every((tip) => tip.hinglishTip.isNotEmpty), isTrue);
        expect(alternatives.every((alt) => alt.hinglishTip.isNotEmpty), isTrue);
        expect(combinations.every((combo) => combo.hinglishTip.isNotEmpty), isTrue);
        
        // Should use common Hinglish words
        final allHinglishText = [
          ...tips.map((t) => t.hinglishTip),
          ...alternatives.map((a) => a.hinglishTip),
          ...combinations.map((c) => c.hinglishTip),
        ].join(' ').toLowerCase();
        
        expect(allHinglishText.contains('karo') || allHinglishText.contains('hai') || 
               allHinglishText.contains('mein') || allHinglishText.contains('aur'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles food with minimal nutritional data', () {
        // Arrange
        final minimalFood = testRice.copyWith(
          nutrition: NutritionalInfo(
            calories: 100.0,
            protein: 1.0,
            carbs: 20.0,
            fat: 0.1,
            fiber: 0.1,
            vitamins: {},
            minerals: {},
          ),
        );

        // Act & Assert - Should not crash
        expect(() => cookingEducation.getCookingTips(food: minimalFood), returnsNormally);
        expect(() => cookingEducation.explainNutrition(food: minimalFood), returnsNormally);
        expect(() => cookingEducation.getPortionAdvice(food: minimalFood, user: testUser), returnsNormally);
      });

      test('handles user with no health conditions or goals', () {
        // Arrange
        final basicUser = UserModel(
          uid: 'basic-uid',
          name: 'Basic User',
          email: 'basic@example.com',
        );

        // Act & Assert - Should not crash and provide general advice
        final tips = cookingEducation.getCookingTips(food: testDal, user: basicUser);
        final explanation = cookingEducation.explainNutrition(food: testDal, user: basicUser);
        final portionAdvice = cookingEducation.getPortionAdvice(food: testDal, user: basicUser);

        expect(tips, isNotEmpty);
        expect(explanation.benefits, isNotEmpty);
        expect(portionAdvice.generalAdvice, isNotEmpty);
      });
    });
  });
}

// Extension method for testing
extension IndianFoodItemCopyWith on IndianFoodItem {
  IndianFoodItem copyWith({
    IndianFoodCategory? category,
    NutritionalInfo? nutrition,
  }) {
    return IndianFoodItem(
      id: id,
      name: name,
      aliases: aliases,
      nutrition: nutrition ?? this.nutrition,
      cookingMethods: cookingMethods,
      portionSizes: portionSizes,
      regions: regions,
      category: category ?? this.category,
      commonCombinations: commonCombinations,
      searchTerms: searchTerms,
      baseDish: baseDish,
      regionalVariations: regionalVariations,
    );
  }
}