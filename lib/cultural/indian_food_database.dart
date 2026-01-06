import 'package:cloud_firestore/cloud_firestore.dart';
import '../voice/hinglish_processor.dart';
import '../nutrition/meal_data_models.dart';
import 'cultural_context_engine.dart';

/// Comprehensive nutritional database optimized for Indian foods
/// Contains nutritional information, regional variations, and cultural context
class IndianFoodDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'indian_foods';

  /// Search for food items by name or alias
  Future<List<IndianFoodItem>> searchFood(String query) async {
    try {
      final queryLower = query.toLowerCase().trim();
      
      // Search by name
      final nameQuery = await _firestore
          .collection(_collectionName)
          .where('searchTerms', arrayContains: queryLower)
          .limit(20)
          .get();

      final List<IndianFoodItem> results = [];
      
      for (var doc in nameQuery.docs) {
        try {
          final foodItem = IndianFoodItem.fromFirestore(doc);
          results.add(foodItem);
        } catch (e) {
          print('Error parsing food item ${doc.id}: $e');
        }
      }

      return results;
    } catch (e) {
      print('Error searching foods: $e');
      return [];
    }
  }

  /// Get detailed food information
  Future<IndianFoodItem?> getFoodDetails(String foodId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(foodId).get();
      
      if (doc.exists) {
        return IndianFoodItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting food details: $e');
      return null;
    }
  }

  /// Get nutritional information for a food item
  Future<NutritionalInfo> getNutrition(String foodId, double quantity, String unit) async {
    final foodItem = await getFoodDetails(foodId);
    if (foodItem == null) {
      throw Exception('Food item not found: $foodId');
    }

    // Convert quantity to grams for calculation
    final quantityInGrams = _convertToGrams(quantity, unit, foodItem);
    
    // Calculate nutrition per requested quantity
    final baseNutrition = foodItem.nutrition;
    final multiplier = quantityInGrams / 100.0; // Base nutrition is per 100g

    return NutritionalInfo(
      calories: baseNutrition.calories * multiplier,
      protein: baseNutrition.protein * multiplier,
      carbs: baseNutrition.carbs * multiplier,
      fat: baseNutrition.fat * multiplier,
      fiber: baseNutrition.fiber * multiplier,
      vitamins: baseNutrition.vitamins.map((k, v) => MapEntry(k, v * multiplier)),
      minerals: baseNutrition.minerals.map((k, v) => MapEntry(k, v * multiplier)),
    );
  }

  /// Get regional variations of a dish
  Future<List<RegionalVariation>> getRegionalVariations(String dishName) async {
    try {
      final query = await _firestore
          .collection(_collectionName)
          .where('baseDish', isEqualTo: dishName.toLowerCase())
          .get();

      final List<RegionalVariation> variations = [];
      
      for (var doc in query.docs) {
        final data = doc.data();
        if (data['regionalVariations'] != null) {
          final variationsData = List<Map<String, dynamic>>.from(data['regionalVariations']);
          for (var variationData in variationsData) {
            variations.add(RegionalVariation.fromMap(variationData));
          }
        }
      }

      return variations;
    } catch (e) {
      print('Error getting regional variations: $e');
      return [];
    }
  }

  /// Add new food item to database
  Future<bool> addFoodItem(IndianFoodItem foodItem) async {
    try {
      await _firestore.collection(_collectionName).doc(foodItem.id).set(foodItem.toFirestore());
      return true;
    } catch (e) {
      print('Error adding food item: $e');
      return false;
    }
  }

  /// Update food item information
  Future<bool> updateFoodItem(String foodId, IndianFoodItem updatedItem) async {
    try {
      await _firestore.collection(_collectionName).doc(foodId).update(updatedItem.toFirestore());
      return true;
    } catch (e) {
      print('Error updating food item: $e');
      return false;
    }
  }

  /// Initialize database with sample Indian foods
  Future<void> initializeSampleData() async {
    final sampleFoods = _getSampleIndianFoods();
    
    for (var food in sampleFoods) {
      final exists = await getFoodDetails(food.id);
      if (exists == null) {
        await addFoodItem(food);
      }
    }
  }

  /// Convert various units to grams
  double _convertToGrams(double quantity, String unit, IndianFoodItem foodItem) {
    switch (unit.toLowerCase()) {
      case 'g':
      case 'grams':
        return quantity;
      case 'kg':
      case 'kilograms':
        return quantity * 1000;
      case 'katori':
        return quantity * (foodItem.portionSizes.standardPortions[IndianMeasurementUnit.katori] ?? 150.0);
      case 'glass':
        return quantity * (foodItem.portionSizes.standardPortions[IndianMeasurementUnit.glass] ?? 250.0);
      case 'roti':
        return quantity * (foodItem.portionSizes.standardPortions[IndianMeasurementUnit.roti] ?? 30.0);
      case 'spoon':
      case 'tablespoon':
        return quantity * (foodItem.portionSizes.standardPortions[IndianMeasurementUnit.spoon] ?? 15.0);
      case 'cup':
        return quantity * 200.0; // Standard cup measurement
      default:
        return quantity; // Assume grams if unknown
    }
  }

  /// Get sample Indian foods for initialization
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
          primaryRegion: 'North India',
          availableRegions: ['North India', 'West India'],
          regionalNames: {'punjabi': 'Dal Makhani', 'hindi': 'काली दाल'},
        ),
        category: IndianFoodCategory.dal,
        commonCombinations: ['naan', 'roti', 'rice', 'jeera rice'],
        searchTerms: ['dal makhani', 'dal makhni', 'black dal', 'काली दाल', 'makhani dal'],
        baseDish: 'dal',
        regionalVariations: [],
      ),

      // Roti items
      IndianFoodItem(
        id: 'chapati',
        name: 'Chapati',
        aliases: ['roti', 'phulka', 'रोटी'],
        nutrition: NutritionalInfo(
          calories: 80.0,
          protein: 3.0,
          carbs: 15.0,
          fat: 0.5,
          fiber: 2.0,
          vitamins: {'B1': 0.1, 'B3': 1.0},
          minerals: {'iron': 1.0, 'magnesium': 15.0},
        ),
        cookingMethods: CookingVariations(
          defaultMethod: CookingMethod(
            name: 'tawa',
            description: 'Cooked on flat griddle',
            nutritionMultiplier: 1.0,
            commonIngredients: ['wheat flour', 'water', 'salt'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.roti: 30.0,
          },
          visualReference: '1 medium roti',
          gramsPerPortion: 30.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North India', 'South India', 'West India', 'East India'],
          regionalNames: {'hindi': 'रोटी', 'english': 'chapati'},
        ),
        category: IndianFoodCategory.roti,
        commonCombinations: ['dal', 'sabzi', 'curry'],
        searchTerms: ['chapati', 'roti', 'phulka', 'रोटी'],
        baseDish: 'roti',
        regionalVariations: [],
      ),

      // Rice items
      IndianFoodItem(
        id: 'basmati_rice',
        name: 'Basmati Rice',
        aliases: ['white rice', 'steamed rice', 'चावल'],
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
            name: 'steamed',
            description: 'Boiled in water until tender',
            nutritionMultiplier: 1.0,
            commonIngredients: ['basmati rice', 'water', 'salt'],
          ),
          alternatives: [],
          nutritionAdjustments: {},
        ),
        portionSizes: PortionGuides(
          standardPortions: {
            IndianMeasurementUnit.katori: 100.0,
            IndianMeasurementUnit.spoon: 20.0,
          },
          visualReference: '1 katori cooked rice',
          gramsPerPortion: 100.0,
        ),
        regions: RegionalAvailability(
          primaryRegion: 'All India',
          availableRegions: ['North India', 'South India', 'West India', 'East India'],
          regionalNames: {'hindi': 'चावल', 'english': 'rice'},
        ),
        category: IndianFoodCategory.rice,
        commonCombinations: ['dal', 'curry', 'sabzi', 'raita'],
        searchTerms: ['basmati rice', 'white rice', 'rice', 'चावल'],
        baseDish: 'rice',
        regionalVariations: [],
      ),
    ];
  }
}

/// Represents an Indian food item with comprehensive information
class IndianFoodItem {
  final String id;
  final String name;
  final List<String> aliases;
  final NutritionalInfo nutrition;
  final CookingVariations cookingMethods;
  final PortionGuides portionSizes;
  final RegionalAvailability regions;
  final IndianFoodCategory category;
  final List<String> commonCombinations;
  final List<String> searchTerms;
  final String baseDish;
  final List<RegionalVariation> regionalVariations;

  IndianFoodItem({
    required this.id,
    required this.name,
    required this.aliases,
    required this.nutrition,
    required this.cookingMethods,
    required this.portionSizes,
    required this.regions,
    required this.category,
    required this.commonCombinations,
    required this.searchTerms,
    required this.baseDish,
    required this.regionalVariations,
  });

  /// Convert to FoodItem for use in other services
  FoodItem toFoodItem({required double quantity, required String unit}) {
    return FoodItem(
      name: name,
      quantity: quantity,
      unit: unit,
      nutrition: nutrition,
      context: CulturalContext(
        region: regions.primaryRegion,
        cookingMethod: cookingMethods.defaultMethod.name,
        mealType: _getMealTypeFromCategory(category),
        commonCombinations: commonCombinations,
      ),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'aliases': aliases,
      'nutrition': nutrition.toMap(),
      'cookingMethods': cookingMethods.toMap(),
      'portionSizes': portionSizes.toMap(),
      'regions': regions.toMap(),
      'category': category.toString().split('.').last,
      'commonCombinations': commonCombinations,
      'searchTerms': searchTerms,
      'baseDish': baseDish,
      'regionalVariations': regionalVariations.map((v) => v.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create from Firestore document
  factory IndianFoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return IndianFoodItem(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? '',
      aliases: List<String>.from(data['aliases'] ?? []),
      nutrition: NutritionalInfo.fromMap(data['nutrition'] ?? {}),
      cookingMethods: CookingVariations.fromMap(data['cookingMethods'] ?? {}),
      portionSizes: PortionGuides.fromMap(data['portionSizes'] ?? {}),
      regions: RegionalAvailability.fromMap(data['regions'] ?? {}),
      category: _categoryFromString(data['category'] ?? 'dal'),
      commonCombinations: List<String>.from(data['commonCombinations'] ?? []),
      searchTerms: List<String>.from(data['searchTerms'] ?? []),
      baseDish: data['baseDish'] ?? '',
      regionalVariations: (data['regionalVariations'] as List<dynamic>? ?? [])
          .map((v) => RegionalVariation.fromMap(v as Map<String, dynamic>))
          .toList(),
    );
  }

  static IndianFoodCategory _categoryFromString(String categoryStr) {
    switch (categoryStr.toLowerCase()) {
      case 'dal':
        return IndianFoodCategory.dal;
      case 'sabzi':
        return IndianFoodCategory.sabzi;
      case 'roti':
        return IndianFoodCategory.roti;
      case 'rice':
        return IndianFoodCategory.rice;
      case 'curry':
        return IndianFoodCategory.curry;
      case 'snack':
        return IndianFoodCategory.snack;
      case 'sweet':
        return IndianFoodCategory.sweet;
      case 'beverage':
        return IndianFoodCategory.beverage;
      default:
        return IndianFoodCategory.dal;
    }
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

/// Cooking variations for a food item
class CookingVariations {
  final CookingMethod defaultMethod;
  final List<CookingMethod> alternatives;
  final Map<String, double> nutritionAdjustments;

  CookingVariations({
    required this.defaultMethod,
    required this.alternatives,
    required this.nutritionAdjustments,
  });

  Map<String, dynamic> toMap() {
    return {
      'defaultMethod': defaultMethod.toMap(),
      'alternatives': alternatives.map((a) => a.toMap()).toList(),
      'nutritionAdjustments': nutritionAdjustments,
    };
  }

  factory CookingVariations.fromMap(Map<String, dynamic> map) {
    return CookingVariations(
      defaultMethod: CookingMethod.fromMap(map['defaultMethod'] ?? {}),
      alternatives: (map['alternatives'] as List<dynamic>? ?? [])
          .map((a) => CookingMethod.fromMap(a as Map<String, dynamic>))
          .toList(),
      nutritionAdjustments: Map<String, double>.from(map['nutritionAdjustments'] ?? {}),
    );
  }
}

/// Portion guides for Indian measurements
class PortionGuides {
  final Map<IndianMeasurementUnit, double> standardPortions;
  final String visualReference;
  final double gramsPerPortion;

  PortionGuides({
    required this.standardPortions,
    required this.visualReference,
    required this.gramsPerPortion,
  });

  Map<String, dynamic> toMap() {
    return {
      'standardPortions': standardPortions.map((k, v) => MapEntry(k.toString().split('.').last, v)),
      'visualReference': visualReference,
      'gramsPerPortion': gramsPerPortion,
    };
  }

  factory PortionGuides.fromMap(Map<String, dynamic> map) {
    final standardPortionsMap = <IndianMeasurementUnit, double>{};
    final portionsData = map['standardPortions'] as Map<String, dynamic>? ?? {};
    
    for (var entry in portionsData.entries) {
      final unit = _unitFromString(entry.key);
      if (unit != null) {
        standardPortionsMap[unit] = (entry.value as num).toDouble();
      }
    }

    return PortionGuides(
      standardPortions: standardPortionsMap,
      visualReference: map['visualReference'] ?? '',
      gramsPerPortion: (map['gramsPerPortion'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static IndianMeasurementUnit? _unitFromString(String unitStr) {
    switch (unitStr.toLowerCase()) {
      case 'katori':
        return IndianMeasurementUnit.katori;
      case 'glass':
        return IndianMeasurementUnit.glass;
      case 'roti':
        return IndianMeasurementUnit.roti;
      case 'spoon':
        return IndianMeasurementUnit.spoon;
      case 'pinch':
        return IndianMeasurementUnit.pinch;
      case 'handful':
        return IndianMeasurementUnit.handful;
      default:
        return null;
    }
  }
}

/// Regional availability information
class RegionalAvailability {
  final String primaryRegion;
  final List<String> availableRegions;
  final Map<String, String> regionalNames;

  RegionalAvailability({
    required this.primaryRegion,
    required this.availableRegions,
    required this.regionalNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'primaryRegion': primaryRegion,
      'availableRegions': availableRegions,
      'regionalNames': regionalNames,
    };
  }

  factory RegionalAvailability.fromMap(Map<String, dynamic> map) {
    return RegionalAvailability(
      primaryRegion: map['primaryRegion'] ?? '',
      availableRegions: List<String>.from(map['availableRegions'] ?? []),
      regionalNames: Map<String, String>.from(map['regionalNames'] ?? {}),
    );
  }
}