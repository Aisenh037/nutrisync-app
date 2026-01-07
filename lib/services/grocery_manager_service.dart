import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../nutrition/meal_data_models.dart';
import '../nutrition/recommendation_engine.dart';
import '../models/user_model.dart';

/// Grocery Manager Service for shopping list generation and management
/// Handles meal plan-based shopping lists and healthy alternatives
class GroceryManagerService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  GroceryManagerService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Generate shopping list from meal plan
  Future<GroceryList> generateShoppingList(DayMealPlan mealPlan, String userId) async {
    try {
      final groceryItems = <GroceryItem>[];
      
      // Extract ingredients from all meals
      final allMeals = [
        mealPlan.breakfast,
        mealPlan.lunch,
        mealPlan.dinner,
        ...mealPlan.snacks,
      ];

      // Aggregate ingredients from all meals
      final ingredientMap = <String, GroceryItem>{};
      
      for (final meal in allMeals) {
        for (final food in meal.foods) {
          final ingredients = _extractIngredients(food);
          
          for (final ingredient in ingredients) {
            final key = ingredient.name.toLowerCase(); // Use name only for aggregation
            
            if (ingredientMap.containsKey(key)) {
              // Combine quantities for same ingredient
              final existing = ingredientMap[key]!;
              ingredientMap[key] = GroceryItem(
                name: existing.name,
                quantity: existing.quantity + ingredient.quantity,
                unit: existing.unit,
                category: existing.category,
                estimatedPrice: existing.estimatedPrice + ingredient.estimatedPrice,
                alternatives: existing.alternatives,
              );
            } else {
              ingredientMap[key] = ingredient;
            }
          }
        }
      }

      groceryItems.addAll(ingredientMap.values);
      
      // Categorize items
      final categorizedItems = categorizeItems(groceryItems);
      
      // Calculate total estimated cost
      final totalCost = groceryItems.fold<double>(
        0.0, 
        (sum, item) => sum + item.estimatedPrice,
      );

      final groceryList = GroceryList(
        id: _uuid.v4(),
        userId: userId,
        createdAt: DateTime.now(),
        categorizedItems: categorizedItems,
        estimatedCost: totalCost,
        notes: 'Generated from meal plan for ${_formatDate(mealPlan.date)}',
      );

      // Save to Firestore
      await saveGroceryList(groceryList);
      
      return groceryList;
    } catch (e) {
      throw Exception('Failed to generate shopping list: $e');
    }
  }

  /// Extract ingredients from a food item
  List<GroceryItem> _extractIngredients(FoodItem food) {
    final ingredients = <GroceryItem>[];
    
    // For Indian foods, extract common ingredients based on food type
    final ingredientData = _getIngredientData(food.name, food.quantity);
    
    for (final ingredient in ingredientData) {
      ingredients.add(GroceryItem(
        name: ingredient['name'],
        quantity: ingredient['quantity'],
        unit: ingredient['unit'],
        category: _categorizeIngredient(ingredient['name']),
        estimatedPrice: ingredient['price'],
        alternatives: ingredient['alternatives'] ?? [],
      ));
    }
    
    return ingredients;
  }

  /// Get ingredient data for Indian foods
  List<Map<String, dynamic>> _getIngredientData(String foodName, double quantity) {
    final normalizedName = foodName.toLowerCase();
    
    // Common Indian food ingredients mapping
    if (normalizedName.contains('dal') || normalizedName.contains('lentil')) {
      return [
        {
          'name': _getDalType(normalizedName),
          'quantity': quantity * 0.15, // 150g dal per serving
          'unit': 'kg',
          'price': 120.0 * (quantity * 0.15),
          'alternatives': ['moong dal', 'toor dal', 'chana dal'],
        },
        {
          'name': 'onion',
          'quantity': quantity * 0.1,
          'unit': 'kg',
          'price': 40.0 * (quantity * 0.1),
          'alternatives': ['shallots'],
        },
        {
          'name': 'tomato',
          'quantity': quantity * 0.08,
          'unit': 'kg',
          'price': 50.0 * (quantity * 0.08),
          'alternatives': ['cherry tomatoes'],
        },
      ];
    }
    
    // Handle onion-based dishes (paratha, curry, etc.)
    if (normalizedName.contains('onion')) {
      final ingredients = <Map<String, dynamic>>[];
      
      // Always add onion as main ingredient
      ingredients.add({
        'name': 'onion',
        'quantity': quantity * 0.15, // More onions for onion-based dishes
        'unit': 'kg',
        'price': 40.0 * (quantity * 0.15),
        'alternatives': ['shallots'],
      });
      
      // Add other ingredients based on dish type
      if (normalizedName.contains('paratha')) {
        ingredients.add({
          'name': 'wheat flour',
          'quantity': quantity * 0.08,
          'unit': 'kg',
          'price': 45.0 * (quantity * 0.08),
          'alternatives': ['whole wheat flour'],
        });
      }
      
      if (normalizedName.contains('curry')) {
        ingredients.addAll([
          {
            'name': 'tomato',
            'quantity': quantity * 0.1,
            'unit': 'kg',
            'price': 50.0 * (quantity * 0.1),
            'alternatives': ['cherry tomatoes'],
          },
          {
            'name': 'cooking oil',
            'quantity': quantity * 0.02,
            'unit': 'liter',
            'price': 120.0 * (quantity * 0.02),
            'alternatives': ['olive oil'],
          },
        ]);
      }
      
      return ingredients;
    }
    
    if (normalizedName.contains('rice') || normalizedName.contains('chawal')) {
      return [
        {
          'name': 'basmati rice',
          'quantity': quantity * 0.1,
          'unit': 'kg',
          'price': 150.0 * (quantity * 0.1),
          'alternatives': ['brown rice', 'jasmine rice'],
        },
      ];
    }
    
    if (normalizedName.contains('roti') || normalizedName.contains('chapati')) {
      return [
        {
          'name': 'wheat flour',
          'quantity': quantity * 0.08,
          'unit': 'kg',
          'price': 45.0 * (quantity * 0.08),
          'alternatives': ['whole wheat flour', 'multigrain flour'],
        },
      ];
    }
    
    if (normalizedName.contains('sabzi') || normalizedName.contains('vegetable')) {
      return [
        {
          'name': 'mixed vegetables',
          'quantity': quantity * 0.2,
          'unit': 'kg',
          'price': 60.0 * (quantity * 0.2),
          'alternatives': ['seasonal vegetables'],
        },
      ];
    }
    
    // Default for unknown foods
    return [
      {
        'name': foodName,
        'quantity': quantity * 0.1,
        'unit': 'kg',
        'price': 80.0 * (quantity * 0.1),
        'alternatives': <String>[],
      },
    ];
  }

  /// Get specific dal type from food name
  String _getDalType(String foodName) {
    if (foodName.contains('moong')) return 'moong dal';
    if (foodName.contains('toor') || foodName.contains('arhar')) return 'toor dal';
    if (foodName.contains('chana')) return 'chana dal';
    if (foodName.contains('masoor')) return 'masoor dal';
    if (foodName.contains('urad')) return 'urad dal';
    return 'toor dal'; // default
  }

  /// Update grocery quantities based on consumption patterns
  Future<void> updateQuantitiesFromConsumption(String userId, List<MealData> recentMeals) async {
    try {
      // Analyze consumption patterns from recent meals
      final consumptionPatterns = _analyzeConsumptionPatterns(recentMeals);
      
      // Get user's recent grocery lists
      final recentLists = await getGroceryHistory(userId);
      
      if (recentLists.isEmpty) return;
      
      // Update quantities based on actual consumption vs planned
      final latestList = recentLists.first;
      final updatedItems = <GroceryCategory, List<GroceryItem>>{};
      
      for (final category in latestList.categorizedItems.keys) {
        final items = latestList.categorizedItems[category]!;
        final updatedCategoryItems = <GroceryItem>[];
        
        for (final item in items) {
          final consumptionRate = consumptionPatterns[item.name] ?? 1.0;
          final adjustedQuantity = item.quantity * consumptionRate;
          
          updatedCategoryItems.add(GroceryItem(
            name: item.name,
            quantity: adjustedQuantity,
            unit: item.unit,
            category: item.category,
            estimatedPrice: item.estimatedPrice * consumptionRate,
            isPurchased: item.isPurchased,
            alternatives: item.alternatives,
          ));
        }
        
        updatedItems[category] = updatedCategoryItems;
      }
      
      // Save updated grocery list
      final updatedList = GroceryList(
        id: _uuid.v4(),
        userId: userId,
        createdAt: DateTime.now(),
        categorizedItems: updatedItems,
        estimatedCost: _calculateTotalCost(updatedItems),
        notes: 'Updated based on consumption patterns',
      );
      
      await saveGroceryList(updatedList);
    } catch (e) {
      throw Exception('Failed to update quantities: $e');
    }
  }

  /// Analyze consumption patterns from recent meals
  Map<String, double> _analyzeConsumptionPatterns(List<MealData> recentMeals) {
    final patterns = <String, double>{};
    final itemCounts = <String, int>{};
    
    for (final meal in recentMeals) {
      for (final food in meal.foods) {
        final ingredients = _extractIngredients(FoodItem(
          name: food.name,
          quantity: food.quantity,
          unit: food.unit,
          nutrition: food.nutrition,
          context: CulturalContext(
            region: food.culturalContext.region,
            cookingMethod: food.culturalContext.cookingStyle,
            mealType: food.culturalContext.mealType,
            commonCombinations: [],
          ),
        ));
        
        for (final ingredient in ingredients) {
          itemCounts[ingredient.name] = (itemCounts[ingredient.name] ?? 0) + 1;
        }
      }
    }
    
    // Calculate consumption rate (higher count = higher consumption)
    final maxCount = itemCounts.values.isEmpty ? 1 : itemCounts.values.reduce((a, b) => a > b ? a : b);
    
    for (final entry in itemCounts.entries) {
      patterns[entry.key] = entry.value / maxCount;
    }
    
    return patterns;
  }

  /// Suggest healthy alternatives for grocery items
  List<HealthyAlternative> suggestHealthyAlternatives(GroceryItem item, UserModel profile) {
    final alternatives = <HealthyAlternative>[];
    
    // Get healthy alternatives based on item category and user profile
    final alternativeData = _getHealthyAlternatives(item, profile);
    
    for (final altData in alternativeData) {
      alternatives.add(HealthyAlternative(
        original: item,
        alternative: GroceryItem(
          name: altData['name'],
          quantity: item.quantity,
          unit: item.unit,
          category: item.category,
          estimatedPrice: altData['price'],
          alternatives: [],
        ),
        reason: altData['reason'],
        benefits: List<String>.from(altData['benefits']),
        healthScore: altData['healthScore'],
      ));
    }
    
    return alternatives;
  }

  /// Get healthy alternatives data
  List<Map<String, dynamic>> _getHealthyAlternatives(GroceryItem item, UserModel profile) {
    final alternatives = <Map<String, dynamic>>[];
    final itemName = item.name.toLowerCase();
    
    // Consider user's health goals and medical conditions
    final hasWeightLossGoal = profile.healthGoals.contains('weight_loss');
    final hasDiabetes = profile.medicalConditions.contains('diabetes');
    final hasHighBP = profile.medicalConditions.contains('high_blood_pressure');
    
    // Rice alternatives
    if (itemName.contains('rice')) {
      if (hasWeightLossGoal || hasDiabetes) {
        alternatives.add({
          'name': 'brown rice',
          'price': item.estimatedPrice * 1.2,
          'reason': 'Lower glycemic index, higher fiber',
          'benefits': ['Better blood sugar control', 'Higher fiber content', 'More nutrients'],
          'healthScore': 8.5,
        });
        
        alternatives.add({
          'name': 'quinoa',
          'price': item.estimatedPrice * 2.5,
          'reason': 'Complete protein, gluten-free',
          'benefits': ['Complete protein', 'Gluten-free', 'Lower carbs'],
          'healthScore': 9.0,
        });
      }
    }
    
    // Oil alternatives
    if (itemName.contains('oil') || itemName.contains('refined')) {
      alternatives.add({
        'name': 'olive oil',
        'price': item.estimatedPrice * 1.8,
        'reason': 'Heart-healthy monounsaturated fats',
        'benefits': ['Heart health', 'Anti-inflammatory', 'Rich in antioxidants'],
        'healthScore': 8.8,
      });
      
      if (hasHighBP) {
        alternatives.add({
          'name': 'avocado oil',
          'price': item.estimatedPrice * 2.2,
          'reason': 'High smoke point, heart-healthy',
          'benefits': ['Heart health', 'High smoke point', 'Vitamin E'],
          'healthScore': 9.2,
        });
      }
    }
    
    // Also check for cooking oil specifically
    if (itemName.contains('cooking oil')) {
      alternatives.add({
        'name': 'olive oil',
        'price': item.estimatedPrice * 1.8,
        'reason': 'Heart-healthy monounsaturated fats',
        'benefits': ['Heart health', 'Anti-inflammatory', 'Rich in antioxidants'],
        'healthScore': 8.8,
      });
      
      if (hasHighBP) {
        alternatives.add({
          'name': 'avocado oil',
          'price': item.estimatedPrice * 2.2,
          'reason': 'High smoke point, heart-healthy for blood pressure',
          'benefits': ['Heart health', 'High smoke point', 'Vitamin E'],
          'healthScore': 9.2,
        });
      }
    }
    
    // Sugar alternatives
    if (itemName.contains('sugar')) {
      if (hasDiabetes || hasWeightLossGoal) {
        alternatives.add({
          'name': 'jaggery',
          'price': item.estimatedPrice * 1.3,
          'reason': 'Natural sweetener with minerals, better for blood sugar control',
          'benefits': ['Contains iron', 'Natural minerals', 'Less processed'],
          'healthScore': 7.5,
        });
        
        alternatives.add({
          'name': 'stevia',
          'price': item.estimatedPrice * 3.0,
          'reason': 'Zero calories, no blood sugar impact',
          'benefits': ['Zero calories', 'No blood sugar spike', 'Natural'],
          'healthScore': 9.5,
        });
      }
    }
    
    // Flour alternatives
    if (itemName.contains('flour') || itemName.contains('maida')) {
      alternatives.add({
        'name': 'whole wheat flour',
        'price': item.estimatedPrice * 1.1,
        'reason': 'Higher fiber and nutrients',
        'benefits': ['Higher fiber', 'More nutrients', 'Better digestion'],
        'healthScore': 8.0,
      });
      
      if (hasWeightLossGoal) {
        alternatives.add({
          'name': 'almond flour',
          'price': item.estimatedPrice * 4.0,
          'reason': 'Low carb, high protein',
          'benefits': ['Low carbs', 'High protein', 'Gluten-free'],
          'healthScore': 8.8,
        });
      }
    }
    
    return alternatives;
  }

  /// Categorize grocery items
  Map<GroceryCategory, List<GroceryItem>> categorizeItems(List<GroceryItem> items) {
    final categorized = <GroceryCategory, List<GroceryItem>>{};
    
    // Initialize all categories
    for (final category in GroceryCategory.values) {
      categorized[category] = [];
    }
    
    // Categorize each item
    for (final item in items) {
      final category = _categorizeIngredient(item.name);
      categorized[category]!.add(item);
    }
    
    // Remove empty categories
    categorized.removeWhere((key, value) => value.isEmpty);
    
    return categorized;
  }

  /// Categorize individual ingredient
  GroceryCategory _categorizeIngredient(String ingredientName) {
    final name = ingredientName.toLowerCase();
    
    // Vegetables
    if (name.contains('onion') || name.contains('tomato') || name.contains('potato') ||
        name.contains('carrot') || name.contains('peas') || name.contains('spinach') ||
        name.contains('cauliflower') || name.contains('cabbage') || name.contains('vegetable')) {
      return GroceryCategory.vegetables;
    }
    
    // Fruits
    if (name.contains('apple') || name.contains('banana') || name.contains('orange') ||
        name.contains('mango') || name.contains('grapes') || name.contains('fruit')) {
      return GroceryCategory.fruits;
    }
    
    // Grains
    if (name.contains('rice') || name.contains('wheat') || name.contains('flour') ||
        name.contains('oats') || name.contains('quinoa') || name.contains('barley')) {
      return GroceryCategory.grains;
    }
    
    // Pulses
    if (name.contains('dal') || name.contains('lentil') || name.contains('chickpea') ||
        name.contains('kidney bean') || name.contains('black bean')) {
      return GroceryCategory.pulses;
    }
    
    // Spices
    if (name.contains('turmeric') || name.contains('cumin') || name.contains('coriander') ||
        name.contains('garam masala') || name.contains('chili') || name.contains('ginger') ||
        name.contains('garlic') || name.contains('spice')) {
      return GroceryCategory.spices;
    }
    
    // Dairy
    if (name.contains('milk') || name.contains('yogurt') || name.contains('cheese') ||
        name.contains('butter') || name.contains('paneer') || name.contains('ghee')) {
      return GroceryCategory.dairy;
    }
    
    // Meat
    if (name.contains('chicken') || name.contains('mutton') || name.contains('fish') ||
        name.contains('egg') || name.contains('meat')) {
      return GroceryCategory.meat;
    }
    
    // Condiments
    if (name.contains('oil') || name.contains('vinegar') || name.contains('sauce') ||
        name.contains('pickle') || name.contains('chutney')) {
      return GroceryCategory.condiments;
    }
    
    // Default to condiments for unknown items
    return GroceryCategory.condiments;
  }

  /// Calculate total cost from categorized items
  double _calculateTotalCost(Map<GroceryCategory, List<GroceryItem>> categorizedItems) {
    double total = 0.0;
    for (final items in categorizedItems.values) {
      for (final item in items) {
        total += item.estimatedPrice;
      }
    }
    return total;
  }

  /// Save grocery list to Firestore
  Future<bool> saveGroceryList(GroceryList groceryList) async {
    try {
      await _firestore
          .collection('grocery_lists')
          .doc(groceryList.id)
          .set(groceryList.toMap());
      return true;
    } catch (e) {
      throw Exception('Failed to save grocery list: $e');
    }
  }

  /// Get user's grocery history
  Future<List<GroceryList>> getGroceryHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('grocery_lists')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => GroceryList.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get grocery history: $e');
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Represents a grocery list
class GroceryList {
  final String id;
  final String userId;
  final DateTime createdAt;
  final Map<GroceryCategory, List<GroceryItem>> categorizedItems;
  final double estimatedCost;
  final String notes;

  GroceryList({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.categorizedItems,
    required this.estimatedCost,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    final categorizedMap = <String, List<Map<String, dynamic>>>{};
    for (final entry in categorizedItems.entries) {
      categorizedMap[entry.key.toString()] = 
          entry.value.map((item) => item.toMap()).toList();
    }

    return {
      'id': id,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'categorizedItems': categorizedMap,
      'estimatedCost': estimatedCost,
      'notes': notes,
    };
  }

  factory GroceryList.fromMap(Map<String, dynamic> map) {
    final categorizedItems = <GroceryCategory, List<GroceryItem>>{};
    final categorizedMap = Map<String, dynamic>.from(map['categorizedItems'] ?? {});
    
    for (final entry in categorizedMap.entries) {
      final category = GroceryCategory.values.firstWhere(
        (cat) => cat.toString() == entry.key,
        orElse: () => GroceryCategory.condiments,
      );
      
      final items = (entry.value as List<dynamic>)
          .map((itemMap) => GroceryItem.fromMap(itemMap))
          .toList();
      
      categorizedItems[category] = items;
    }

    return GroceryList(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categorizedItems: categorizedItems,
      estimatedCost: (map['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
    );
  }
}

/// Individual grocery item
class GroceryItem {
  final String name;
  final double quantity;
  final String unit;
  final GroceryCategory category;
  final double estimatedPrice;
  final bool isPurchased;
  final List<String> alternatives;

  GroceryItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.estimatedPrice,
    this.isPurchased = false,
    required this.alternatives,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category.toString(),
      'estimatedPrice': estimatedPrice,
      'isPurchased': isPurchased,
      'alternatives': alternatives,
    };
  }

  factory GroceryItem.fromMap(Map<String, dynamic> map) {
    return GroceryItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      category: GroceryCategory.values.firstWhere(
        (cat) => cat.toString() == map['category'],
        orElse: () => GroceryCategory.condiments,
      ),
      estimatedPrice: (map['estimatedPrice'] as num?)?.toDouble() ?? 0.0,
      isPurchased: map['isPurchased'] ?? false,
      alternatives: List<String>.from(map['alternatives'] ?? []),
    );
  }
}

/// Grocery categories for organization
enum GroceryCategory {
  vegetables,
  fruits,
  grains,
  pulses,
  spices,
  dairy,
  meat,
  snacks,
  beverages,
  condiments,
}

/// Extension for grocery category display names
extension GroceryCategoryExtension on GroceryCategory {
  String get displayName {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'Vegetables';
      case GroceryCategory.fruits:
        return 'Fruits';
      case GroceryCategory.grains:
        return 'Grains & Cereals';
      case GroceryCategory.pulses:
        return 'Pulses & Lentils';
      case GroceryCategory.spices:
        return 'Spices & Herbs';
      case GroceryCategory.dairy:
        return 'Dairy Products';
      case GroceryCategory.meat:
        return 'Meat & Eggs';
      case GroceryCategory.snacks:
        return 'Snacks';
      case GroceryCategory.beverages:
        return 'Beverages';
      case GroceryCategory.condiments:
        return 'Condiments & Oils';
    }
  }

  String get hindiName {
    switch (this) {
      case GroceryCategory.vegetables:
        return 'सब्जियां';
      case GroceryCategory.fruits:
        return 'फल';
      case GroceryCategory.grains:
        return 'अनाज';
      case GroceryCategory.pulses:
        return 'दालें';
      case GroceryCategory.spices:
        return 'मसाले';
      case GroceryCategory.dairy:
        return 'डेयरी उत्पाद';
      case GroceryCategory.meat:
        return 'मांस और अंडे';
      case GroceryCategory.snacks:
        return 'नाश्ता';
      case GroceryCategory.beverages:
        return 'पेय पदार्थ';
      case GroceryCategory.condiments:
        return 'मसाले और तेल';
    }
  }
}

/// Healthy alternative suggestion
class HealthyAlternative {
  final GroceryItem original;
  final GroceryItem alternative;
  final String reason;
  final List<String> benefits;
  final double healthScore;

  HealthyAlternative({
    required this.original,
    required this.alternative,
    required this.reason,
    required this.benefits,
    required this.healthScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'original': original.toMap(),
      'alternative': alternative.toMap(),
      'reason': reason,
      'benefits': benefits,
      'healthScore': healthScore,
    };
  }

  factory HealthyAlternative.fromMap(Map<String, dynamic> map) {
    return HealthyAlternative(
      original: GroceryItem.fromMap(map['original'] ?? {}),
      alternative: GroceryItem.fromMap(map['alternative'] ?? {}),
      reason: map['reason'] ?? '',
      benefits: List<String>.from(map['benefits'] ?? []),
      healthScore: (map['healthScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}