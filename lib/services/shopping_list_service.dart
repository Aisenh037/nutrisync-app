import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_models.dart';
import '../nutrition/meal_data_models.dart';
import '../nutrition/meal_planning_models.dart';
import '../models/user_model.dart';
import 'dietary_substitution_service.dart';

/// Enhanced Shopping List Service for NutriSync GCP AI Enhancement
/// Implements intelligent shopping list generation with AI-powered features
class ShoppingListService {
  final FirebaseFirestore _firestore;
  final DietarySubstitutionService _substitutionService;
  final Uuid _uuid = const Uuid();

  ShoppingListService({
    FirebaseFirestore? firestore,
    DietarySubstitutionService? substitutionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _substitutionService = substitutionService ?? DietarySubstitutionService(firestore: firestore);

  /// Generate shopping list from meal plan with AI enhancements
  /// Requirement 4.1: Meal plan to shopping list conversion
  Future<ShoppingList> generateFromMealPlan({
    required String mealPlanId,
    required List<DayMealPlan> mealPlans,
    required String userId,
    PantryInventory? pantryInventory,
    List<String> dietaryRestrictions = const [],
    List<String> targetStores = const [],
  }) async {
    try {
      // Extract all ingredients from meal plans
      final allIngredients = <String, _IngredientAccumulator>{};
      final sourceRecipes = <String>[];

      for (final dayPlan in mealPlans) {
        _extractIngredientsFromDayPlan(dayPlan, allIngredients, sourceRecipes);
      }

      // Check pantry inventory to avoid duplicates (Requirement 4.2)
      final filteredIngredients = await _filterAgainstPantry(
        allIngredients,
        pantryInventory,
      );

      // Consolidate ingredient quantities (Requirement 4.3)
      final consolidatedItems = _consolidateIngredients(
        filteredIngredients,
        sourceRecipes,
      );

      // Apply dietary substitutions (Requirement 4.4)
      final substitutedItems = await _applyDietarySubstitutions(
        consolidatedItems,
        dietaryRestrictions,
        userId,
      );

      // Organize by store sections (Requirement 4.5)
      final organizedItems = _organizeByStoreSections(substitutedItems);

      // Create shopping optimization
      final optimization = _createShoppingOptimization(organizedItems);

      // Calculate total cost
      final totalCost = organizedItems.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedPrice,
      );

      final shoppingList = ShoppingList(
        listId: _uuid.v4(),
        userId: userId,
        items: organizedItems,
        targetStores: targetStores,
        createdAt: DateTime.now(),
        sourceMealPlan: MealPlanReference(
          mealPlanId: mealPlanId,
          startDate: mealPlans.first.date,
          endDate: mealPlans.last.date,
          numberOfDays: mealPlans.length,
          includedMeals: ['breakfast', 'lunch', 'dinner', 'snacks'],
        ),
        optimization: optimization,
        estimatedCost: totalCost,
        notes: 'Generated from ${mealPlans.length}-day meal plan',
      );

      // Save to Firestore
      await _saveShoppingList(shoppingList);

      return shoppingList;
    } catch (e) {
      throw Exception('Failed to generate shopping list from meal plan: $e');
    }
  }

  /// Check pantry inventory to avoid duplicate purchases
  /// Requirement 4.2: Pantry inventory checking
  Future<Map<String, _IngredientAccumulator>> _filterAgainstPantry(
    Map<String, _IngredientAccumulator> ingredients,
    PantryInventory? pantryInventory,
  ) async {
    if (pantryInventory == null || pantryInventory.items.isEmpty) {
      return ingredients;
    }

    final filteredIngredients = <String, _IngredientAccumulator>{};
    final pantryMap = <String, PantryItem>{};

    // Create pantry lookup map
    for (final pantryItem in pantryInventory.items) {
      pantryMap[pantryItem.name.toLowerCase()] = pantryItem;
    }

    // Filter ingredients against pantry
    for (final entry in ingredients.entries) {
      final ingredientName = entry.key;
      final accumulator = entry.value;
      final pantryItem = pantryMap[ingredientName];

      if (pantryItem != null && pantryItem.quantity > 0) {
        // Calculate remaining quantity needed
        final neededQuantity = accumulator.totalQuantity - pantryItem.quantity;
        
        if (neededQuantity > 0) {
          // Still need some quantity
          filteredIngredients[ingredientName] = _IngredientAccumulator(
            name: accumulator.name,
            totalQuantity: neededQuantity,
            unit: accumulator.unit,
            contributions: accumulator.contributions,
            section: accumulator.section,
            estimatedPricePerUnit: accumulator.estimatedPricePerUnit,
          );
        }
        // If neededQuantity <= 0, we have enough in pantry, skip this ingredient
      } else {
        // Not in pantry or quantity is 0, add to shopping list
        filteredIngredients[ingredientName] = accumulator;
      }
    }

    return filteredIngredients;
  }

  /// Consolidate ingredient quantities from multiple recipes
  /// Requirement 4.3: Ingredient quantity consolidation
  List<ShoppingItem> _consolidateIngredients(
    Map<String, _IngredientAccumulator> ingredients,
    List<String> sourceRecipes,
  ) {
    final consolidatedItems = <ShoppingItem>[];

    for (final entry in ingredients.entries) {
      final accumulator = entry.value;
      
      final consolidation = IngredientConsolidation(
        sourceRecipes: accumulator.contributions.map((c) => c.recipeName).toSet().toList(),
        contributions: accumulator.contributions,
        totalQuantity: accumulator.totalQuantity,
        consolidatedUnit: accumulator.unit,
      );

      final shoppingItem = ShoppingItem(
        itemId: _uuid.v4(),
        name: accumulator.name,
        quantity: accumulator.totalQuantity,
        unit: accumulator.unit,
        section: accumulator.section,
        estimatedPrice: accumulator.totalQuantity * accumulator.estimatedPricePerUnit,
        consolidation: consolidation,
        priority: _calculateItemPriority(accumulator),
      );

      consolidatedItems.add(shoppingItem);
    }

    return consolidatedItems;
  }

  /// Apply dietary substitutions for restricted ingredients
  /// Requirement 4.4: Dietary substitution suggestions
  Future<List<ShoppingItem>> _applyDietarySubstitutions(
    List<ShoppingItem> items,
    List<String> dietaryRestrictions,
    String userId,
  ) async {
    if (dietaryRestrictions.isEmpty) {
      return items;
    }

    final substitutedItems = <ShoppingItem>[];

    for (final item in items) {
      // Use the enhanced dietary substitution service
      final substitutions = await _substitutionService.getSubstitutions(
        ingredients: [item.name],
        dietaryRestrictions: dietaryRestrictions,
        userId: userId,
      );

      final updatedItem = item.copyWith(substitutions: substitutions);
      substitutedItems.add(updatedItem);
    }

    return substitutedItems;
  }

  /// Organize items by store sections for efficient shopping
  /// Requirement 4.5: Store section organization
  List<ShoppingItem> _organizeByStoreSections(List<ShoppingItem> items) {
    // Sort items by store section for efficient shopping flow
    items.sort((a, b) {
      final sectionOrder = [
        StoreSection.produce,
        StoreSection.dairy,
        StoreSection.meat,
        StoreSection.bakery,
        StoreSection.pantry,
        StoreSection.frozen,
        StoreSection.spices,
        StoreSection.beverages,
        StoreSection.snacks,
        StoreSection.health,
        StoreSection.international,
        StoreSection.other,
      ];

      final aIndex = sectionOrder.indexOf(a.section);
      final bIndex = sectionOrder.indexOf(b.section);
      
      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }
      
      // Within same section, sort by priority (high to low)
      return b.priority.compareTo(a.priority);
    });

    return items;
  }

  /// Extract ingredients from a day meal plan
  void _extractIngredientsFromDayPlan(
    DayMealPlan dayPlan,
    Map<String, _IngredientAccumulator> allIngredients,
    List<String> sourceRecipes,
  ) {
    final meals = [
      dayPlan.breakfast,
      dayPlan.lunch,
      dayPlan.dinner,
      ...dayPlan.snacks,
    ];

    for (final meal in meals) {
      for (final food in meal.foods) {
        final recipeName = food.name;
        sourceRecipes.add(recipeName);
        
        final ingredients = _extractIngredientsFromFood(food);
        
        for (final ingredient in ingredients) {
          final key = ingredient.name.toLowerCase();
          
          if (allIngredients.containsKey(key)) {
            // Add to existing accumulator
            final existing = allIngredients[key]!;
            existing.totalQuantity += ingredient.quantity;
            existing.contributions.add(QuantityContribution(
              recipeName: recipeName,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
              servings: 1,
            ));
          } else {
            // Create new accumulator
            allIngredients[key] = _IngredientAccumulator(
              name: ingredient.name,
              totalQuantity: ingredient.quantity,
              unit: ingredient.unit,
              contributions: [
                QuantityContribution(
                  recipeName: recipeName,
                  quantity: ingredient.quantity,
                  unit: ingredient.unit,
                  servings: 1,
                ),
              ],
              section: _determineStoreSection(ingredient.name),
              estimatedPricePerUnit: _estimatePrice(ingredient.name, ingredient.unit),
            );
          }
        }
      }
    }
  }

  /// Extract ingredients from a food item
  List<_BasicIngredient> _extractIngredientsFromFood(FoodItem food) {
    final ingredients = <_BasicIngredient>[];
    final foodName = food.name.toLowerCase();
    
    // Indian food ingredient mapping with enhanced logic
    if (foodName.contains('dal') || foodName.contains('lentil')) {
      ingredients.addAll(_getDalIngredients(foodName, food.quantity));
    } else if (foodName.contains('rice') || foodName.contains('chawal')) {
      ingredients.addAll(_getRiceIngredients(foodName, food.quantity));
    } else if (foodName.contains('roti') || foodName.contains('chapati')) {
      ingredients.addAll(_getRotiBreadIngredients(foodName, food.quantity));
    } else if (foodName.contains('curry') || foodName.contains('sabzi')) {
      ingredients.addAll(_getCurryIngredients(foodName, food.quantity));
    } else if (foodName.contains('paratha')) {
      ingredients.addAll(_getParathaIngredients(foodName, food.quantity));
    } else {
      // Generic ingredient extraction
      ingredients.add(_BasicIngredient(
        name: food.name,
        quantity: food.quantity * 0.1,
        unit: 'kg',
      ));
    }
    
    return ingredients;
  }

  /// Get dal-specific ingredients
  List<_BasicIngredient> _getDalIngredients(String foodName, double servings) {
    final dalType = _getDalType(foodName);
    return [
      _BasicIngredient(name: dalType, quantity: servings * 0.15, unit: 'kg'),
      _BasicIngredient(name: 'onion', quantity: servings * 0.1, unit: 'kg'),
      _BasicIngredient(name: 'tomato', quantity: servings * 0.08, unit: 'kg'),
      _BasicIngredient(name: 'turmeric powder', quantity: servings * 0.005, unit: 'kg'),
      _BasicIngredient(name: 'cumin seeds', quantity: servings * 0.003, unit: 'kg'),
      _BasicIngredient(name: 'cooking oil', quantity: servings * 0.02, unit: 'liter'),
    ];
  }

  /// Get rice-specific ingredients
  List<_BasicIngredient> _getRiceIngredients(String foodName, double servings) {
    return [
      _BasicIngredient(name: 'basmati rice', quantity: servings * 0.1, unit: 'kg'),
      _BasicIngredient(name: 'salt', quantity: servings * 0.002, unit: 'kg'),
    ];
  }

  /// Get roti/bread-specific ingredients
  List<_BasicIngredient> _getRotiBreadIngredients(String foodName, double servings) {
    return [
      _BasicIngredient(name: 'whole wheat flour', quantity: servings * 0.08, unit: 'kg'),
      _BasicIngredient(name: 'salt', quantity: servings * 0.001, unit: 'kg'),
      _BasicIngredient(name: 'cooking oil', quantity: servings * 0.01, unit: 'liter'),
    ];
  }

  /// Get curry-specific ingredients
  List<_BasicIngredient> _getCurryIngredients(String foodName, double servings) {
    return [
      _BasicIngredient(name: 'mixed vegetables', quantity: servings * 0.2, unit: 'kg'),
      _BasicIngredient(name: 'onion', quantity: servings * 0.12, unit: 'kg'),
      _BasicIngredient(name: 'tomato', quantity: servings * 0.1, unit: 'kg'),
      _BasicIngredient(name: 'ginger-garlic paste', quantity: servings * 0.01, unit: 'kg'),
      _BasicIngredient(name: 'cooking oil', quantity: servings * 0.03, unit: 'liter'),
      _BasicIngredient(name: 'garam masala', quantity: servings * 0.002, unit: 'kg'),
    ];
  }

  /// Get paratha-specific ingredients
  List<_BasicIngredient> _getParathaIngredients(String foodName, double servings) {
    final baseIngredients = [
      _BasicIngredient(name: 'whole wheat flour', quantity: servings * 0.1, unit: 'kg'),
      _BasicIngredient(name: 'ghee', quantity: servings * 0.02, unit: 'kg'),
      _BasicIngredient(name: 'salt', quantity: servings * 0.001, unit: 'kg'),
    ];

    // Add specific ingredients based on paratha type
    if (foodName.contains('aloo')) {
      baseIngredients.add(_BasicIngredient(name: 'potato', quantity: servings * 0.15, unit: 'kg'));
    } else if (foodName.contains('gobi')) {
      baseIngredients.add(_BasicIngredient(name: 'cauliflower', quantity: servings * 0.15, unit: 'kg'));
    } else if (foodName.contains('onion')) {
      baseIngredients.add(_BasicIngredient(name: 'onion', quantity: servings * 0.15, unit: 'kg'));
    }

    return baseIngredients;
  }

  /// Determine dal type from food name
  String _getDalType(String foodName) {
    if (foodName.contains('moong')) return 'moong dal';
    if (foodName.contains('toor') || foodName.contains('arhar')) return 'toor dal';
    if (foodName.contains('chana')) return 'chana dal';
    if (foodName.contains('masoor')) return 'masoor dal';
    if (foodName.contains('urad')) return 'urad dal';
    return 'toor dal'; // default
  }

  /// Determine store section for an ingredient
  StoreSection _determineStoreSection(String ingredientName) {
    final name = ingredientName.toLowerCase();
    
    if (name.contains('onion') || name.contains('tomato') || name.contains('potato') ||
        name.contains('cauliflower') || name.contains('vegetable') || name.contains('ginger')) {
      return StoreSection.produce;
    }
    
    if (name.contains('milk') || name.contains('yogurt') || name.contains('cheese') ||
        name.contains('butter') || name.contains('ghee') || name.contains('paneer')) {
      return StoreSection.dairy;
    }
    
    if (name.contains('chicken') || name.contains('mutton') || name.contains('fish') ||
        name.contains('egg') || name.contains('meat')) {
      return StoreSection.meat;
    }
    
    if (name.contains('bread') || name.contains('naan') || name.contains('bun')) {
      return StoreSection.bakery;
    }
    
    if (name.contains('rice') || name.contains('flour') || name.contains('dal') ||
        name.contains('lentil') || name.contains('oil') || name.contains('salt') ||
        name.contains('sugar')) {
      return StoreSection.pantry;
    }
    
    if (name.contains('ice cream') || name.contains('frozen')) {
      return StoreSection.frozen;
    }
    
    if (name.contains('turmeric') || name.contains('cumin') || name.contains('masala') ||
        name.contains('spice') || name.contains('coriander') || name.contains('chili')) {
      return StoreSection.spices;
    }
    
    if (name.contains('juice') || name.contains('tea') || name.contains('coffee') ||
        name.contains('water') || name.contains('soda')) {
      return StoreSection.beverages;
    }
    
    return StoreSection.other;
  }

  /// Estimate price per unit for an ingredient
  double _estimatePrice(String ingredientName, String unit) {
    final name = ingredientName.toLowerCase();
    
    // Price estimates in INR per kg/liter
    if (name.contains('rice')) return 150.0;
    if (name.contains('dal') || name.contains('lentil')) return 120.0;
    if (name.contains('flour')) return 45.0;
    if (name.contains('onion')) return 40.0;
    if (name.contains('tomato')) return 50.0;
    if (name.contains('potato')) return 30.0;
    if (name.contains('oil')) return 120.0;
    if (name.contains('ghee')) return 500.0;
    if (name.contains('milk')) return 60.0;
    if (name.contains('vegetable')) return 60.0;
    if (name.contains('spice') || name.contains('masala')) return 200.0;
    
    return 80.0; // default price
  }

  /// Calculate item priority based on nutritional importance and frequency
  double _calculateItemPriority(
    _IngredientAccumulator accumulator,
  ) {
    double priority = 0.5; // base priority
    
    // Higher priority for staples
    final name = accumulator.name.toLowerCase();
    if (name.contains('rice') || name.contains('flour') || name.contains('dal')) {
      priority += 0.3;
    }
    
    // Higher priority for vegetables and proteins
    if (name.contains('vegetable') || name.contains('onion') || name.contains('tomato')) {
      priority += 0.2;
    }
    
    // Higher priority based on frequency (more recipes using it)
    final recipeCount = accumulator.contributions.length;
    priority += (recipeCount - 1) * 0.1;
    
    return math.min(1.0, priority);
  }

  /// Save shopping list to Firestore
  Future<void> _saveShoppingList(ShoppingList shoppingList) async {
    await _firestore
        .collection('shopping_lists')
        .doc(shoppingList.listId)
        .set(shoppingList.toJson());
  }

  /// Create shopping optimization data
  ShoppingOptimization _createShoppingOptimization(List<ShoppingItem> items) {
    final sectionOrganization = <StoreSection, List<String>>{};
    final tips = <ShoppingTip>[];
    
    // Organize items by section
    for (final item in items) {
      sectionOrganization.putIfAbsent(item.section, () => []).add(item.name);
    }
    
    // Calculate estimated shopping time (2 minutes per section + 1 minute per 5 items)
    final sectionCount = sectionOrganization.keys.length;
    final itemCount = items.length;
    final estimatedTime = (sectionCount * 2.0) + (itemCount / 5.0);
    
    // Generate shopping tips
    if (items.any((item) => item.section == StoreSection.produce)) {
      tips.add(const ShoppingTip(
        title: 'Fresh Produce First',
        description: 'Shop for fruits and vegetables first to ensure freshness',
        type: ShoppingTipType.time,
      ));
    }
    
    if (items.any((item) => item.section == StoreSection.frozen)) {
      tips.add(const ShoppingTip(
        title: 'Frozen Items Last',
        description: 'Pick up frozen items last to maintain temperature',
        type: ShoppingTipType.storage,
      ));
    }
    
    final totalCost = items.fold<double>(0.0, (sum, item) => sum + item.estimatedPrice);
    if (totalCost > 2000) {
      tips.add(const ShoppingTip(
        title: 'Budget Consideration',
        description: 'Consider buying in bulk for staples to save money',
        type: ShoppingTipType.cost,
      ));
    }
    
    return ShoppingOptimization(
      sectionOrganization: sectionOrganization,
      suggestedStoreOrder: _getSuggestedStoreOrder(sectionOrganization.keys.toList()),
      estimatedShoppingTime: estimatedTime,
      tips: tips,
    );
  }

  /// Get suggested store order for efficient shopping
  List<String> _getSuggestedStoreOrder(List<StoreSection> sections) {
    final optimalOrder = [
      StoreSection.produce,
      StoreSection.bakery,
      StoreSection.dairy,
      StoreSection.meat,
      StoreSection.pantry,
      StoreSection.spices,
      StoreSection.beverages,
      StoreSection.snacks,
      StoreSection.health,
      StoreSection.international,
      StoreSection.frozen,
      StoreSection.other,
    ];
    
    return optimalOrder
        .where((section) => sections.contains(section))
        .map((section) => section.displayName)
        .toList();
  }

  /// Get user's shopping list history
  Future<List<ShoppingList>> getShoppingListHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('shopping_lists')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => ShoppingList.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get shopping list history: $e');
    }
  }

  /// Update shopping list item status
  Future<void> updateItemStatus(
    String listId,
    String itemId,
    bool isPurchased,
  ) async {
    try {
      final docRef = _firestore.collection('shopping_lists').doc(listId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Shopping list not found');
      }
      
      final shoppingList = ShoppingList.fromJson(doc.data()!);
      final updatedItems = shoppingList.items.map((item) {
        if (item.itemId == itemId) {
          return item.copyWith(isPurchased: isPurchased);
        }
        return item;
      }).toList();
      
      final updatedList = shoppingList.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      
      await docRef.set(updatedList.toJson());
    } catch (e) {
      throw Exception('Failed to update item status: $e');
    }
  }
}

/// Internal class for accumulating ingredient quantities
class _IngredientAccumulator {
  final String name;
  double totalQuantity;
  final String unit;
  final List<QuantityContribution> contributions;
  final StoreSection section;
  final double estimatedPricePerUnit;

  _IngredientAccumulator({
    required this.name,
    required this.totalQuantity,
    required this.unit,
    required this.contributions,
    required this.section,
    required this.estimatedPricePerUnit,
  });
}

/// Internal class for basic ingredient data
class _BasicIngredient {
  final String name;
  final double quantity;
  final String unit;

  _BasicIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}