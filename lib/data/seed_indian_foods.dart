import 'package:cloud_firestore/cloud_firestore.dart';
import '../cultural/indian_food_database.dart';
import '../cultural/cultural_context_engine.dart';
import '../nutrition/meal_data_models.dart';

/// Seeds the Firestore database with Indian food data
class IndianFoodSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seeds the database with comprehensive Indian food data
  Future<void> seedIndianFoods() async {
    final batch = _firestore.batch();
    
    // Sample Indian foods with comprehensive nutrition data
    final foods = [
      // Dal varieties
      IndianFoodItem(
        id: 'dal_tadka',
        name: 'Dal Tadka',
        aliases: ['dal', 'lentils', 'arhar dal'],
        nutrition: NutritionalInfo(
          calories: 150.0,
          protein: 12.0,
          carbs: 20.0,
          fat: 4.0,
          fiber: 8.0,
          vitamins: {'B1': 0.3, 'C': 15.0, 'B6': 0.2},
          minerals: {'iron': 3.5, 'potassium': 350.0, 'magnesium': 45.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'tadka',
            description: 'Tempered with spices',
            nutritionMultiplier: 1.0,
            commonIngredients: ['lentils', 'oil', 'cumin', 'turmeric'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 150.0},
          visualReference: '1 katori (small bowl)',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'Central Indian'],
          regionalNames: {'Hindi': 'दाल तड़का', 'Punjabi': 'ਦਾਲ ਤੜਕਾ'},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['rice', 'roti', 'pickle'],
        searchTerms: ['dal', 'lentils', 'protein', 'tadka'],
        baseDish: 'dal',
        regionalVariations: [],
      ),
      
      // Rice varieties
      IndianFoodItem(
        id: 'basmati_rice',
        name: 'Basmati Rice',
        aliases: ['rice', 'chawal', 'steamed rice'],
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
            description: 'Boiled in water',
            nutritionMultiplier: 1.0,
            commonIngredients: ['rice', 'water', 'salt'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 150.0},
          visualReference: '1 katori cooked rice',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North Indian', 'South Indian', 'East Indian', 'West Indian'],
          regionalNames: {'Hindi': 'बासमती चावल', 'Tamil': 'பாஸ்மதி அரிசி'},
        ),
        category: IndianFoodCategory.rice,
        commonCombinations: ['dal', 'curry', 'raita'],
        searchTerms: ['rice', 'chawal', 'carbs', 'basmati'],
        baseDish: 'rice',
        regionalVariations: [],
      ),
      
      // Vegetable dishes
      IndianFoodItem(
        id: 'mixed_vegetables',
        name: 'Mixed Vegetables (Sabzi)',
        aliases: ['sabzi', 'vegetables', 'mixed veg'],
        nutrition: NutritionalInfo(
          calories: 80.0,
          protein: 3.0,
          carbs: 15.0,
          fat: 2.0,
          fiber: 5.0,
          vitamins: {'C': 45.0, 'K': 20.0, 'A': 15.0},
          minerals: {'potassium': 300.0, 'calcium': 40.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'bhuna',
            description: 'Sautéed with spices',
            nutritionMultiplier: 1.0,
            commonIngredients: ['vegetables', 'oil', 'onion', 'spices'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 100.0},
          visualReference: '1 katori mixed vegetables',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North Indian', 'South Indian', 'East Indian', 'West Indian'],
          regionalNames: {'Hindi': 'मिक्स सब्जी', 'Bengali': 'মিশ্র সবজি'},
        ),
        category: IndianFoodCategory.sabzi,
        commonCombinations: ['roti', 'rice', 'dal'],
        searchTerms: ['sabzi', 'vegetables', 'fiber', 'vitamins'],
        baseDish: 'sabzi',
        regionalVariations: [],
      ),
      
      // Roti/Bread
      IndianFoodItem(
        id: 'whole_wheat_roti',
        name: 'Whole Wheat Roti',
        aliases: ['roti', 'chapati', 'bread'],
        nutrition: NutritionalInfo(
          calories: 70.0,
          protein: 2.5,
          carbs: 14.0,
          fat: 0.5,
          fiber: 2.0,
          vitamins: {'B1': 0.1, 'B3': 1.0},
          minerals: {'iron': 1.0, 'magnesium': 20.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'tawa',
            description: 'Cooked on griddle',
            nutritionMultiplier: 1.0,
            commonIngredients: ['wheat flour', 'water', 'salt'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.roti: 30.0},
          visualReference: '1 medium roti (6-7 inches)',
          gramsPerPortion: 30.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'Central Indian', 'West Indian'],
          regionalNames: {'Hindi': 'रोटी', 'Punjabi': 'ਰੋਟੀ'},
        ),
        category: IndianFoodCategory.roti,
        commonCombinations: ['dal', 'sabzi', 'curry'],
        searchTerms: ['roti', 'chapati', 'bread', 'wheat'],
        baseDish: 'roti',
        regionalVariations: [],
      ),
      
      // Popular curries
      IndianFoodItem(
        id: 'rajma',
        name: 'Rajma (Kidney Bean Curry)',
        aliases: ['rajma', 'kidney beans', 'bean curry'],
        nutrition: NutritionalInfo(
          calories: 180.0,
          protein: 15.0,
          carbs: 25.0,
          fat: 3.0,
          fiber: 10.0,
          vitamins: {'B1': 0.4, 'B6': 0.3, 'C': 8.0},
          minerals: {'iron': 4.0, 'potassium': 400.0, 'magnesium': 60.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'dum',
            description: 'Slow cooked curry',
            nutritionMultiplier: 1.0,
            commonIngredients: ['kidney beans', 'onion', 'tomato', 'spices'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {IndianMeasurementUnit.katori: 150.0},
          visualReference: '1 katori rajma curry',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North Indian',
          availableRegions: ['North Indian', 'Central Indian'],
          regionalNames: {'Hindi': 'राजमा', 'Punjabi': 'ਰਾਜਮਾ'},
        ),
        category: IndianFoodCategory.curry,
        commonCombinations: ['rice', 'roti', 'pickle'],
        searchTerms: ['rajma', 'kidney beans', 'protein', 'curry'],
        baseDish: 'rajma',
        regionalVariations: [],
      ),
    ];

    // Add each food item to the batch
    for (final food in foods) {
      final docRef = _firestore.collection('indianFoods').doc(food.id);
      batch.set(docRef, food.toMap());
    }

    // Commit the batch
    await batch.commit();
    print('Successfully seeded ${foods.length} Indian food items');
  }

  /// Seeds cooking education content
  Future<void> seedCookingEducation() async {
    final batch = _firestore.batch();
    
    final educationContent = [
      {
        'id': 'healthy_cooking_tips',
        'title': 'Healthy Indian Cooking Tips',
        'category': 'General',
        'tips': [
          {
            'tip': 'Use minimal oil and prefer steaming or grilling',
            'benefit': 'Reduces calories while maintaining nutrition',
            'hinglishTip': 'Kam oil use karo aur steam ya grill karo - health ke liye achha hai!'
          },
          {
            'tip': 'Add turmeric to dal and vegetables',
            'benefit': 'Anti-inflammatory properties and better digestion',
            'hinglishTip': 'Haldi zaroor dalo - immunity badhti hai!'
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'portion_control',
        'title': 'Indian Portion Control Guide',
        'category': 'Portions',
        'tips': [
          {
            'measurement': 'katori',
            'description': 'Small bowl for dal, rice, sabzi',
            'grams': 150,
            'visualGuide': 'Size of your cupped palm'
          },
          {
            'measurement': 'roti',
            'description': 'Medium whole wheat roti',
            'grams': 30,
            'visualGuide': 'Size of a small plate (6-7 inches)'
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final content in educationContent) {
      final docRef = _firestore.collection('cookingEducation').doc(content['id'] as String);
      batch.set(docRef, content);
    }

    await batch.commit();
    print('Successfully seeded cooking education content');
  }

  /// Seeds sample user data (for testing)
  Future<void> seedSampleUserData(String userId) async {
    final batch = _firestore.batch();
    
    // Sample meal log
    final mealRef = _firestore.collection('users').doc(userId).collection('meals').doc();
    batch.set(mealRef, {
      'userId': userId,
      'mealType': 'lunch',
      'foods': [
        {
          'name': 'Dal Tadka',
          'quantity': 150.0,
          'unit': 'grams',
          'calories': 150.0,
        },
        {
          'name': 'Basmati Rice',
          'quantity': 150.0,
          'unit': 'grams',
          'calories': 130.0,
        },
      ],
      'totalCalories': 280.0,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': 'Healthy lunch with dal-chawal combination',
    });

    // Sample grocery list
    final groceryRef = _firestore.collection('users').doc(userId).collection('groceries').doc();
    batch.set(groceryRef, {
      'userId': userId,
      'items': [
        {'name': 'Arhar Dal', 'category': 'Pulses', 'quantity': '1 kg'},
        {'name': 'Basmati Rice', 'category': 'Grains', 'quantity': '2 kg'},
        {'name': 'Mixed Vegetables', 'category': 'Vegetables', 'quantity': '500g'},
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    await batch.commit();
    print('Successfully seeded sample user data');
  }
}