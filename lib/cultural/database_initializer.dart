import 'package:cloud_firestore/cloud_firestore.dart';
import 'indian_food_database.dart';
import 'cultural_context_engine.dart';
import '../voice/hinglish_processor.dart';

/// Service to initialize the Indian Food Database with comprehensive data
class DatabaseInitializer {
  final IndianFoodDatabase _database = IndianFoodDatabase();

  /// Initialize the database with comprehensive Indian food data
  Future<void> initializeDatabase() async {
    print('Initializing Indian Food Database...');
    
    try {
      // Initialize with sample data first
      await _database.initializeSampleData();
      
      // Add more comprehensive food items
      await _addComprehensiveFoodData();
      
      print('Database initialization completed successfully');
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  /// Add comprehensive Indian food data
  Future<void> _addComprehensiveFoodData() async {
    final foods = _getComprehensiveFoodList();
    
    for (var food in foods) {
      final exists = await _database.getFoodDetails(food.id);
      if (exists == null) {
        await _database.addFoodItem(food);
        print('Added food item: ${food.name}');
      }
    }
  }

  /// Get comprehensive list of Indian foods
  List<IndianFoodItem> _getComprehensiveFoodList() {
    return [
      // More Dal varieties
      IndianFoodItem(
        id: 'toor_dal',
        name: 'Toor Dal',
        aliases: ['arhar dal', 'pigeon pea', 'तूर दाल'],
        nutrition: NutritionalInfo(
          calories: 120.0,
          protein: 7.0,
          carbs: 20.0,
          fat: 1.0,
          fiber: 5.0,
          vitamins: {'B1': 0.15, 'folate': 35.0},
          minerals: {'iron': 2.0, 'potassium': 250.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'pressure_cooked',
            description: 'Pressure cooked with turmeric and salt',
            nutritionMultiplier: 1.0,
            commonIngredients: ['toor dal', 'turmeric', 'salt', 'water'],
          ),
          alternatives: [
            CookingMethod(
              name: 'tadka',
              description: 'Cooked dal with tempering',
              nutritionMultiplier: 1.1,
              commonIngredients: ['toor dal', 'cumin', 'mustard seeds', 'curry leaves'],
            ),
          ],
          nutritionAdjustments: {},
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
          primaryRegion: 'All India',
          availableRegions: ['North India', 'South India', 'West India', 'East India'],
          regionalNames: {'hindi': 'तूर दाल', 'english': 'toor dal'},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['rice', 'roti', 'sabzi'],
        searchTerms: ['toor dal', 'arhar dal', 'pigeon pea', 'तूर दाल'],
        baseDish: 'dal',
        regionalVariations: [
          RegionalVariation(
            region: 'South India',
            dishName: 'Sambar',
            commonIngredients: ['toor dal', 'tamarind', 'vegetables', 'sambar powder'],
            cookingStyle: CookingMethod(
              name: 'sambar_style',
              description: 'Cooked with tamarind and vegetables',
              nutritionMultiplier: 1.2,
              commonIngredients: ['toor dal', 'tamarind', 'vegetables'],
            ),
            nutritionAdjustments: {'fiber': 1.5, 'vitamins': 1.3},
          ),
        ],
      ),

      // Sabzi varieties
      IndianFoodItem(
        id: 'aloo_gobi',
        name: 'Aloo Gobi',
        aliases: ['potato cauliflower', 'आलू गोभी'],
        nutrition: NutritionalInfo(
          calories: 90.0,
          protein: 3.0,
          carbs: 15.0,
          fat: 2.5,
          fiber: 3.0,
          vitamins: {'C': 25.0, 'K': 15.0},
          minerals: {'potassium': 200.0, 'phosphorus': 40.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'bhuna',
            description: 'Dry cooked with spices',
            nutritionMultiplier: 1.0,
            commonIngredients: ['potato', 'cauliflower', 'onion', 'spices'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 120.0,
            IndianMeasurementUnit.spoon: 20.0,
          },
          visualReference: '1 katori serving',
          gramsPerPortion: 120.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'North India',
          availableRegions: ['North India', 'West India'],
          regionalNames: {'hindi': 'आलू गोभी', 'punjabi': 'Aloo Gobi'},
        ),
        category: IndianFoodCategory.sabzi,
        commonCombinations: ['roti', 'paratha', 'rice'],
        searchTerms: ['aloo gobi', 'potato cauliflower', 'आलू गोभी'],
        baseDish: 'sabzi',
        regionalVariations: [],
      ),

      // South Indian items
      IndianFoodItem(
        id: 'idli',
        name: 'Idli',
        aliases: ['steamed rice cake', 'इडली'],
        nutrition: NutritionalInfo(
          calories: 60.0,
          protein: 2.0,
          carbs: 12.0,
          fat: 0.5,
          fiber: 1.0,
          vitamins: {'B1': 0.05, 'B12': 0.1},
          minerals: {'iron': 0.5, 'calcium': 15.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'steamed',
            description: 'Fermented batter steamed in molds',
            nutritionMultiplier: 1.0,
            commonIngredients: ['rice', 'urad dal', 'fenugreek'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.roti: 40.0, // 1 idli ≈ 40g
          },
          visualReference: '1 medium idli',
          gramsPerPortion: 40.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'South India',
          availableRegions: ['South India', 'All India'],
          regionalNames: {'tamil': 'இட்லி', 'english': 'idli'},
        ),
        category: IndianFoodCategory.snack,
        commonCombinations: ['sambar', 'chutney', 'rasam'],
        searchTerms: ['idli', 'steamed rice cake', 'इडली'],
        baseDish: 'idli',
        regionalVariations: [],
      ),

      // Curry items
      IndianFoodItem(
        id: 'chicken_curry',
        name: 'Chicken Curry',
        aliases: ['murgh curry', 'चिकन करी'],
        nutrition: NutritionalInfo(
          calories: 180.0,
          protein: 20.0,
          carbs: 8.0,
          fat: 8.0,
          fiber: 2.0,
          vitamins: {'B6': 0.3, 'B12': 0.5},
          minerals: {'iron': 1.5, 'zinc': 2.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'curry',
            description: 'Cooked in spiced gravy',
            nutritionMultiplier: 1.0,
            commonIngredients: ['chicken', 'onion', 'tomato', 'spices'],
          ),
          alternatives: [
            CookingMethod(
              name: 'dum',
              description: 'Slow cooked in sealed pot',
              nutritionMultiplier: 1.1,
              commonIngredients: ['chicken', 'yogurt', 'spices'],
            ),
          ],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 150.0,
          },
          visualReference: '1 katori curry',
          gramsPerPortion: 150.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North India', 'South India', 'West India', 'East India'],
          regionalNames: {'hindi': 'चिकन करी', 'english': 'chicken curry'},
        ),
        category: IndianFoodCategory.curry,
        commonCombinations: ['rice', 'roti', 'naan'],
        searchTerms: ['chicken curry', 'murgh curry', 'चिकन करी'],
        baseDish: 'curry',
        regionalVariations: [
          RegionalVariation(
            region: 'South India',
            dishName: 'Chicken Chettinad',
            commonIngredients: ['chicken', 'coconut', 'curry leaves', 'black pepper'],
            cookingStyle: CookingMethod(
              name: 'chettinad_style',
              description: 'Spicy South Indian style with coconut',
              nutritionMultiplier: 1.2,
              commonIngredients: ['chicken', 'coconut', 'spices'],
            ),
            nutritionAdjustments: {'fat': 1.3, 'fiber': 1.5},
          ),
        ],
      ),

      // Snack items
      IndianFoodItem(
        id: 'samosa',
        name: 'Samosa',
        aliases: ['samosa', 'समोसा'],
        nutrition: NutritionalInfo(
          calories: 150.0,
          protein: 4.0,
          carbs: 18.0,
          fat: 7.0,
          fiber: 2.0,
          vitamins: {'C': 5.0},
          minerals: {'iron': 1.0, 'potassium': 150.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'fried',
            description: 'Deep fried pastry with filling',
            nutritionMultiplier: 1.0,
            commonIngredients: ['flour', 'potato', 'peas', 'oil'],
          ),
          alternatives: [
            CookingMethod(
              name: 'baked',
              description: 'Baked version for healthier option',
              nutritionMultiplier: 0.7,
              commonIngredients: ['flour', 'potato', 'peas'],
            ),
          ],
          nutritionAdjustments: {'fat': 0.5},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.roti: 50.0, // 1 samosa ≈ 50g
          },
          visualReference: '1 medium samosa',
          gramsPerPortion: 50.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North India', 'South India', 'West India', 'East India'],
          regionalNames: {'hindi': 'समोसा', 'english': 'samosa'},
        ),
        category: IndianFoodCategory.snack,
        commonCombinations: ['chutney', 'tea', 'chole'],
        searchTerms: ['samosa', 'समोसा'],
        baseDish: 'samosa',
        regionalVariations: [],
      ),
    ];
  }

  /// Check if database is already initialized
  Future<bool> isDatabaseInitialized() async {
    try {
      final result = await _database.searchFood('dal makhani');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Reset database (for testing purposes)
  Future<void> resetDatabase() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final collection = firestore.collection('indian_foods');
      
      final docs = await collection.get();
      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
      
      print('Database reset completed');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
}