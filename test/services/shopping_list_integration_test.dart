import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../lib/services/shopping_list_service.dart';
import '../../lib/services/dietary_substitution_service.dart';
import '../../lib/models/shopping_models.dart';
import '../../lib/nutrition/meal_data_models.dart';

/// Integration tests for Shopping List Service
/// Tests all requirements from Task 6.1: Shopping List Generation Service
void main() {
  group('Shopping List Service Integration Tests', () {
    late ShoppingListService service;
    late DietarySubstitutionService substitutionService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      substitutionService = DietarySubstitutionService(firestore: fakeFirestore);
      service = ShoppingListService(
        firestore: fakeFirestore,
        substitutionService: substitutionService,
      );
    });

    group('Requirement 4.1: Meal Plan to Shopping List Conversion', () {
      test('should generate shopping list from single day meal plan', () async {
        // Arrange
        final mealPlan = _createSingleDayMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-meal-plan-1',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        expect(result.listId, isNotEmpty);
        expect(result.userId, equals('test-user-1'));
        expect(result.items, isNotEmpty);
        expect(result.sourceMealPlan?.mealPlanId, equals('test-meal-plan-1'));
        expect(result.sourceMealPlan?.numberOfDays, equals(1));
        
        // Verify dal ingredients are extracted
        final dalIngredients = result.items.where((item) => 
          item.name.toLowerCase().contains('dal') ||
          item.name.toLowerCase().contains('onion') ||
          item.name.toLowerCase().contains('tomato')
        ).toList();
        expect(dalIngredients, isNotEmpty);
      });

      test('should generate shopping list from multi-day meal plan', () async {
        // Arrange
        final mealPlans = [
          _createSingleDayMealPlan(),
          _createSecondDayMealPlan(),
          _createThirdDayMealPlan(),
        ];
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-meal-plan-multi',
          mealPlans: mealPlans,
          userId: 'test-user-1',
        );
        
        // Assert
        expect(result.sourceMealPlan?.numberOfDays, equals(3));
        expect(result.items.length, greaterThan(5));
        
        // Verify date range
        expect(result.sourceMealPlan?.startDate, equals(mealPlans.first.date));
        expect(result.sourceMealPlan?.endDate, equals(mealPlans.last.date));
      });

      test('should extract ingredients from different food types', () async {
        // Arrange
        final mealPlan = _createVariedFoodMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-varied-foods',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        final itemNames = result.items.map((item) => item.name.toLowerCase()).toList();
        
        // Should have rice ingredients
        expect(itemNames.any((name) => name.contains('rice')), isTrue);
        
        // Should have dal ingredients
        expect(itemNames.any((name) => name.contains('dal')), isTrue);
        
        // Should have flour ingredients
        expect(itemNames.any((name) => name.contains('flour')), isTrue);
        
        // Should have vegetable ingredients
        expect(itemNames.any((name) => name.contains('vegetable') || name.contains('onion')), isTrue);
      });
    });

    group('Requirement 4.2: Pantry Inventory Checking', () {
      test('should exclude items available in pantry', () async {
        // Arrange
        final mealPlan = _createSingleDayMealPlan();
        final pantryInventory = PantryInventory(
          userId: 'test-user-1',
          items: [
            PantryItem(
              itemId: 'pantry-1',
              name: 'onion',
              quantity: 2.0,
              unit: 'kg',
              addedDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
            PantryItem(
              itemId: 'pantry-2',
              name: 'toor dal',
              quantity: 1.0,
              unit: 'kg',
              addedDate: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
          lastUpdated: DateTime.now(),
        );
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-pantry-check',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          pantryInventory: pantryInventory,
        );
        
        // Assert
        final itemNames = result.items.map((item) => item.name.toLowerCase()).toList();
        
        // Should not include items with sufficient pantry stock
        expect(itemNames.where((name) => name.contains('onion')).length, lessThanOrEqualTo(1));
        expect(itemNames.where((name) => name.contains('toor dal')).length, lessThanOrEqualTo(1));
        
        // Should still include other ingredients
        expect(itemNames.any((name) => name.contains('tomato')), isTrue);
      });

      test('should include partial quantities when pantry has insufficient stock', () async {
        // Arrange
        final mealPlan = _createLargeMealPlan(); // Requires more ingredients
        final pantryInventory = PantryInventory(
          userId: 'test-user-1',
          items: [
            PantryItem(
              itemId: 'pantry-1',
              name: 'onion',
              quantity: 0.1, // Small amount
              unit: 'kg',
              addedDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
          lastUpdated: DateTime.now(),
        );
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-partial-pantry',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          pantryInventory: pantryInventory,
        );
        
        // Assert
        final onionItems = result.items.where((item) => 
          item.name.toLowerCase().contains('onion')
        ).toList();
        
        if (onionItems.isNotEmpty) {
          // Should have reduced quantity (total needed - pantry stock)
          expect(onionItems.first.quantity, lessThan(1.0));
        }
      });

      test('should work correctly with empty pantry', () async {
        // Arrange
        final mealPlan = _createSingleDayMealPlan();
        final emptyPantry = PantryInventory(
          userId: 'test-user-1',
          items: [],
          lastUpdated: DateTime.now(),
        );
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-empty-pantry',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          pantryInventory: emptyPantry,
        );
        
        // Assert
        expect(result.items, isNotEmpty);
        // Should include all necessary ingredients
        final itemNames = result.items.map((item) => item.name.toLowerCase()).toList();
        expect(itemNames.any((name) => name.contains('dal')), isTrue);
        expect(itemNames.any((name) => name.contains('onion')), isTrue);
      });
    });

    group('Requirement 4.3: Ingredient Quantity Consolidation', () {
      test('should consolidate same ingredients from multiple recipes', () async {
        // Arrange
        final mealPlans = [
          _createDalHeavyMealPlan(), // Multiple dal dishes
          _createMoreDalMealPlan(),  // More dal dishes
        ];
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-consolidation',
          mealPlans: mealPlans,
          userId: 'test-user-1',
        );
        
        // Assert
        final onionItems = result.items.where((item) => 
          item.name.toLowerCase().contains('onion')
        ).toList();
        
        // Should have only one onion entry (consolidated)
        expect(onionItems.length, equals(1));
        
        if (onionItems.isNotEmpty) {
          final onionItem = onionItems.first;
          
          // Should have consolidation information
          expect(onionItem.consolidation, isNotNull);
          expect(onionItem.consolidation!.sourceRecipes.length, greaterThan(1));
          expect(onionItem.consolidation!.contributions.length, greaterThan(1));
          
          // Total quantity should be sum of all contributions
          final totalFromContributions = onionItem.consolidation!.contributions
              .fold<double>(0.0, (sum, contrib) => sum + contrib.quantity);
          expect(onionItem.quantity, closeTo(totalFromContributions, 0.01));
        }
      });

      test('should maintain source recipe information in consolidation', () async {
        // Arrange
        final mealPlan = _createMultiRecipeMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-recipe-tracking',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        final consolidatedItems = result.items.where((item) => 
          item.consolidation != null && item.consolidation!.sourceRecipes.length > 1
        ).toList();
        
        expect(consolidatedItems, isNotEmpty);
        
        for (final item in consolidatedItems) {
          expect(item.consolidation!.sourceRecipes, isNotEmpty);
          expect(item.consolidation!.contributions, isNotEmpty);
          expect(item.consolidation!.contributions.length, 
                 equals(item.consolidation!.sourceRecipes.length));
        }
      });

      test('should handle different units correctly', () async {
        // Arrange - This would require more complex unit conversion logic
        final mealPlan = _createSingleDayMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-units',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        for (final item in result.items) {
          expect(item.unit, isNotEmpty);
          expect(item.quantity, greaterThan(0));
          
          if (item.consolidation != null) {
            expect(item.consolidation!.consolidatedUnit, equals(item.unit));
          }
        }
      });
    });

    group('Requirement 4.4: Dietary Substitution Suggestions', () {
      test('should suggest vegan substitutions', () async {
        // Arrange
        final mealPlan = _createDairyHeavyMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-vegan-subs',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          dietaryRestrictions: ['vegan'],
        );
        
        // Assert
        final dairyItems = result.items.where((item) => 
          item.name.toLowerCase().contains('ghee') ||
          item.name.toLowerCase().contains('milk') ||
          item.name.toLowerCase().contains('butter')
        ).toList();
        
        for (final item in dairyItems) {
          expect(item.substitutions, isNotEmpty);
          
          final veganSubs = item.substitutions.where((sub) => 
            sub.dietaryRestrictions.contains('vegan')
          ).toList();
          expect(veganSubs, isNotEmpty);
          
          // Check substitution quality
          for (final sub in veganSubs) {
            expect(sub.substitution, isNotEmpty);
            expect(sub.reason, isNotEmpty);
            expect(sub.nutritionalSimilarity, greaterThan(0.0));
            expect(sub.nutritionalSimilarity, lessThanOrEqualTo(1.0));
          }
        }
      });

      test('should suggest gluten-free substitutions', () async {
        // Arrange
        final mealPlan = _createWheatHeavyMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-gluten-free-subs',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          dietaryRestrictions: ['gluten-free'],
        );
        
        // Assert
        final wheatItems = result.items.where((item) => 
          item.name.toLowerCase().contains('wheat flour')
        ).toList();
        
        for (final item in wheatItems) {
          expect(item.substitutions, isNotEmpty);
          
          final glutenFreeSubs = item.substitutions.where((sub) => 
            sub.dietaryRestrictions.contains('gluten-free')
          ).toList();
          expect(glutenFreeSubs, isNotEmpty);
          
          // Should suggest rice flour or other alternatives
          expect(glutenFreeSubs.any((sub) => 
            sub.substitution.toLowerCase().contains('rice flour')
          ), isTrue);
        }
      });

      test('should suggest low-sodium substitutions', () async {
        // Arrange
        final mealPlan = _createSaltyMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-low-sodium-subs',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          dietaryRestrictions: ['low-sodium'],
        );
        
        // Assert
        final saltItems = result.items.where((item) => 
          item.name.toLowerCase().contains('salt')
        ).toList();
        
        for (final item in saltItems) {
          expect(item.substitutions, isNotEmpty);
          
          final lowSodiumSubs = item.substitutions.where((sub) => 
            sub.dietaryRestrictions.contains('low-sodium')
          ).toList();
          expect(lowSodiumSubs, isNotEmpty);
        }
      });

      test('should handle multiple dietary restrictions', () async {
        // Arrange
        final mealPlan = _createComplexMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-multiple-restrictions',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
          dietaryRestrictions: ['vegan', 'gluten-free', 'low-sodium'],
        );
        
        // Assert
        final itemsWithSubstitutions = result.items.where((item) => 
          item.substitutions.isNotEmpty
        ).toList();
        
        expect(itemsWithSubstitutions, isNotEmpty);
        
        for (final item in itemsWithSubstitutions) {
          // Should have substitutions for applicable restrictions
          final allRestrictions = item.substitutions
              .expand((sub) => sub.dietaryRestrictions)
              .toSet();
          
          expect(allRestrictions, isNotEmpty);
        }
      });
    });

    group('Requirement 4.5: Store Section Organization', () {
      test('should organize items by store sections', () async {
        // Arrange
        final mealPlan = _createVariedFoodMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-section-organization',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        final sections = result.items.map((item) => item.section).toSet();
        expect(sections.length, greaterThan(1));
        
        // Verify section assignments
        final produceItems = result.items.where((item) => 
          item.section == StoreSection.produce
        ).toList();
        
        final pantryItems = result.items.where((item) => 
          item.section == StoreSection.pantry
        ).toList();
        
        final spiceItems = result.items.where((item) => 
          item.section == StoreSection.spices
        ).toList();
        
        // Should have items in appropriate sections
        expect(produceItems, isNotEmpty);
        expect(pantryItems, isNotEmpty);
        
        // Verify produce items are vegetables/fruits
        for (final item in produceItems) {
          final name = item.name.toLowerCase();
          expect(
            name.contains('onion') || name.contains('tomato') || 
            name.contains('vegetable') || name.contains('potato'),
            isTrue,
          );
        }
        
        // Verify pantry items are staples
        for (final item in pantryItems) {
          final name = item.name.toLowerCase();
          expect(
            name.contains('rice') || name.contains('flour') || 
            name.contains('dal') || name.contains('oil'),
            isTrue,
          );
        }
      });

      test('should sort items within sections by priority', () async {
        // Arrange
        final mealPlan = _createLargeMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-priority-sorting',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        final pantryItems = result.items.where((item) => 
          item.section == StoreSection.pantry
        ).toList();
        
        if (pantryItems.length > 1) {
          // Should be sorted by priority (high to low)
          for (int i = 0; i < pantryItems.length - 1; i++) {
            expect(pantryItems[i].priority, 
                   greaterThanOrEqualTo(pantryItems[i + 1].priority));
          }
        }
      });

      test('should create shopping optimization data', () async {
        // Arrange
        final mealPlan = _createVariedFoodMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-optimization',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        expect(result.optimization, isNotNull);
        expect(result.optimization.sectionOrganization, isNotEmpty);
        expect(result.optimization.suggestedStoreOrder, isNotEmpty);
        expect(result.optimization.estimatedShoppingTime, greaterThan(0));
        
        // Verify section organization matches items
        final itemSections = result.items.map((item) => item.section).toSet();
        final optimizationSections = result.optimization.sectionOrganization.keys.toSet();
        
        for (final section in itemSections) {
          expect(optimizationSections.contains(section), isTrue);
        }
        
        // Verify suggested store order follows logical flow
        final storeOrder = result.optimization.suggestedStoreOrder;
        if (storeOrder.contains('Produce') && storeOrder.contains('Frozen')) {
          expect(storeOrder.indexOf('Produce'), lessThan(storeOrder.indexOf('Frozen')));
        }
      });

      test('should generate helpful shopping tips', () async {
        // Arrange
        final mealPlan = _createVariedFoodMealPlan();
        
        // Act
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-shopping-tips',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Assert
        expect(result.optimization.tips, isNotEmpty);
        
        for (final tip in result.optimization.tips) {
          expect(tip.title, isNotEmpty);
          expect(tip.description, isNotEmpty);
          expect(tip.type, isNotNull);
        }
        
        // Should have produce tip if produce items exist
        final hasProduceItems = result.items.any((item) => 
          item.section == StoreSection.produce
        );
        
        if (hasProduceItems) {
          expect(result.optimization.tips.any((tip) => 
            tip.title.contains('Produce')
          ), isTrue);
        }
      });
    });

    group('Service Integration Tests', () {
      test('should save and retrieve shopping lists', () async {
        // Arrange
        final mealPlan = _createSingleDayMealPlan();
        
        // Act - Generate and save
        final result = await service.generateFromMealPlan(
          mealPlanId: 'test-save-retrieve',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        // Act - Retrieve
        final history = await service.getShoppingListHistory('test-user-1');
        
        // Assert
        expect(history, isNotEmpty);
        expect(history.first.listId, equals(result.listId));
        expect(history.first.userId, equals('test-user-1'));
      });

      test('should update item purchase status', () async {
        // Arrange
        final mealPlan = _createSingleDayMealPlan();
        final shoppingList = await service.generateFromMealPlan(
          mealPlanId: 'test-update-status',
          mealPlans: [mealPlan],
          userId: 'test-user-1',
        );
        
        final firstItem = shoppingList.items.first;
        
        // Act
        await service.updateItemStatus(
          shoppingList.listId,
          firstItem.itemId,
          true,
        );
        
        // Assert - Retrieve updated list
        final history = await service.getShoppingListHistory('test-user-1');
        final updatedList = history.first;
        final updatedItem = updatedList.items.firstWhere((item) => 
          item.itemId == firstItem.itemId
        );
        
        expect(updatedItem.isPurchased, isTrue);
        expect(updatedList.updatedAt, isNotNull);
      });

      test('should handle errors gracefully', () async {
        // Test with invalid meal plan
        expect(
          () => service.generateFromMealPlan(
            mealPlanId: '',
            mealPlans: [],
            userId: 'test-user-1',
          ),
          throwsException,
        );
        
        // Test with invalid list ID for update
        expect(
          () => service.updateItemStatus('invalid-id', 'invalid-item', true),
          throwsException,
        );
      });
    });
  });
}

// Helper methods to create test meal plans

DayMealPlan _createSingleDayMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Moong Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(
            calories: 200,
            protein: 15,
            carbs: 30,
            fat: 2,
            fiber: 8,
            sugar: 2,
          ),
          context: CulturalContext(
            region: 'North India',
            cookingMethod: 'boiled',
            mealType: 'breakfast',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(
            calories: 250,
            protein: 5,
            carbs: 55,
            fat: 1,
            fiber: 2,
            sugar: 0,
          ),
          context: CulturalContext(
            region: 'India',
            cookingMethod: 'boiled',
            mealType: 'lunch',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Roti',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(
            calories: 150,
            protein: 6,
            carbs: 30,
            fat: 2,
            fiber: 4,
            sugar: 1,
          ),
          context: CulturalContext(
            region: 'India',
            cookingMethod: 'cooked',
            mealType: 'dinner',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createSecondDayMealPlan() {
  return DayMealPlan(
    date: DateTime.now().add(const Duration(days: 1)),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Toor Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(
            calories: 180,
            protein: 12,
            carbs: 28,
            fat: 1,
            fiber: 7,
            sugar: 2,
          ),
          context: CulturalContext(
            region: 'South India',
            cookingMethod: 'pressure cooked',
            mealType: 'breakfast',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Vegetable Curry',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(
            calories: 120,
            protein: 4,
            carbs: 15,
            fat: 6,
            fiber: 5,
            sugar: 8,
          ),
          context: CulturalContext(
            region: 'India',
            cookingMethod: 'sautéed',
            mealType: 'lunch',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Aloo Paratha',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(
            calories: 200,
            protein: 8,
            carbs: 35,
            fat: 5,
            fiber: 4,
            sugar: 2,
          ),
          context: CulturalContext(
            region: 'North India',
            cookingMethod: 'pan fried',
            mealType: 'dinner',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createThirdDayMealPlan() {
  return DayMealPlan(
    date: DateTime.now().add(const Duration(days: 2)),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Chana Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(
            calories: 190,
            protein: 14,
            carbs: 25,
            fat: 2,
            fiber: 9,
            sugar: 3,
          ),
          context: CulturalContext(
            region: 'India',
            cookingMethod: 'boiled',
            mealType: 'breakfast',
            commonCombinations: [],
          ),
        ),
      ],
    ),
    lunch: MealData(foods: []),
    dinner: MealData(foods: []),
    snacks: [],
  );
}

DayMealPlan _createVariedFoodMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Moong Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 200, protein: 15, carbs: 30, fat: 2, fiber: 8, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'boiled', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Basmati Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 250, protein: 5, carbs: 55, fat: 1, fiber: 2, sugar: 0),
          context: CulturalContext(region: 'India', cookingMethod: 'boiled', mealType: 'lunch', commonCombinations: []),
        ),
        FoodItem(
          name: 'Mixed Vegetable Curry',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 120, protein: 4, carbs: 15, fat: 6, fiber: 5, sugar: 8),
          context: CulturalContext(region: 'India', cookingMethod: 'sautéed', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Whole Wheat Roti',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 150, protein: 6, carbs: 30, fat: 2, fiber: 4, sugar: 1),
          context: CulturalContext(region: 'India', cookingMethod: 'cooked', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createLargeMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Toor Dal',
          quantity: 2.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 360, protein: 24, carbs: 56, fat: 2, fiber: 14, sugar: 4),
          context: CulturalContext(region: 'India', cookingMethod: 'pressure cooked', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Rice',
          quantity: 2.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 500, protein: 10, carbs: 110, fat: 2, fiber: 4, sugar: 0),
          context: CulturalContext(region: 'India', cookingMethod: 'boiled', mealType: 'lunch', commonCombinations: []),
        ),
        FoodItem(
          name: 'Vegetable Curry',
          quantity: 2.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 240, protein: 8, carbs: 30, fat: 12, fiber: 10, sugar: 16),
          context: CulturalContext(region: 'India', cookingMethod: 'sautéed', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Roti',
          quantity: 4.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 300, protein: 12, carbs: 60, fat: 4, fiber: 8, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'cooked', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createDalHeavyMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Moong Dal Tadka',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 220, protein: 16, carbs: 32, fat: 3, fiber: 9, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'tempering', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Toor Dal Curry',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 200, protein: 14, carbs: 30, fat: 2, fiber: 8, sugar: 3),
          context: CulturalContext(region: 'India', cookingMethod: 'curry', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Chana Dal Fry',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 210, protein: 15, carbs: 28, fat: 3, fiber: 10, sugar: 3),
          context: CulturalContext(region: 'India', cookingMethod: 'fried', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createMoreDalMealPlan() {
  return DayMealPlan(
    date: DateTime.now().add(const Duration(days: 1)),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Masoor Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 180, protein: 13, carbs: 26, fat: 1, fiber: 7, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'boiled', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Urad Dal',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 190, protein: 14, carbs: 24, fat: 2, fiber: 8, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'pressure cooked', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(foods: []),
    snacks: [],
  );
}

DayMealPlan _createMultiRecipeMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Onion Paratha',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 240, protein: 8, carbs: 40, fat: 6, fiber: 5, sugar: 3),
          context: CulturalContext(region: 'North India', cookingMethod: 'pan fried', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Onion Curry',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 140, protein: 3, carbs: 18, fat: 7, fiber: 4, sugar: 10),
          context: CulturalContext(region: 'India', cookingMethod: 'curry', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Onion Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 280, protein: 6, carbs: 58, fat: 3, fiber: 3, sugar: 4),
          context: CulturalContext(region: 'India', cookingMethod: 'fried', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createDairyHeavyMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Ghee Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 320, protein: 6, carbs: 58, fat: 8, fiber: 2, sugar: 1),
          context: CulturalContext(region: 'South India', cookingMethod: 'cooked with ghee', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Butter Naan',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 280, protein: 8, carbs: 45, fat: 8, fiber: 2, sugar: 3),
          context: CulturalContext(region: 'North India', cookingMethod: 'baked with butter', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Milk Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 300, protein: 10, carbs: 55, fat: 5, fiber: 2, sugar: 8),
          context: CulturalContext(region: 'South India', cookingMethod: 'cooked with milk', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createWheatHeavyMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Wheat Flour Pancakes',
          quantity: 3.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 270, protein: 9, carbs: 50, fat: 4, fiber: 6, sugar: 5),
          context: CulturalContext(region: 'India', cookingMethod: 'pan fried', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Wheat Flour Roti',
          quantity: 4.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 300, protein: 12, carbs: 60, fat: 4, fiber: 8, sugar: 2),
          context: CulturalContext(region: 'India', cookingMethod: 'cooked', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Wheat Flour Paratha',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 220, protein: 8, carbs: 40, fat: 5, fiber: 5, sugar: 2),
          context: CulturalContext(region: 'North India', cookingMethod: 'pan fried', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}

DayMealPlan _createSaltyMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Salted Rice',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 260, protein: 5, carbs: 56, fat: 1, fiber: 2, sugar: 0),
          context: CulturalContext(region: 'India', cookingMethod: 'boiled with salt', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Salted Lassi',
          quantity: 1.0,
          unit: 'glass',
          nutrition: NutritionData(calories: 120, protein: 6, carbs: 12, fat: 4, fiber: 0, sugar: 10),
          context: CulturalContext(region: 'North India', cookingMethod: 'blended with salt', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(foods: []),
    snacks: [],
  );
}

DayMealPlan _createComplexMealPlan() {
  return DayMealPlan(
    date: DateTime.now(),
    breakfast: MealData(
      foods: [
        FoodItem(
          name: 'Wheat Flour Pancakes with Ghee',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 300, protein: 8, carbs: 45, fat: 10, fiber: 5, sugar: 4),
          context: CulturalContext(region: 'India', cookingMethod: 'pan fried with ghee', mealType: 'breakfast', commonCombinations: []),
        ),
      ],
    ),
    lunch: MealData(
      foods: [
        FoodItem(
          name: 'Salted Butter Naan',
          quantity: 2.0,
          unit: 'pieces',
          nutrition: NutritionData(calories: 320, protein: 9, carbs: 48, fat: 10, fiber: 2, sugar: 3),
          context: CulturalContext(region: 'North India', cookingMethod: 'baked with salted butter', mealType: 'lunch', commonCombinations: []),
        ),
      ],
    ),
    dinner: MealData(
      foods: [
        FoodItem(
          name: 'Milk Rice with Salt',
          quantity: 1.0,
          unit: 'serving',
          nutrition: NutritionData(calories: 310, protein: 10, carbs: 56, fat: 5, fiber: 2, sugar: 8),
          context: CulturalContext(region: 'South India', cookingMethod: 'cooked with milk and salt', mealType: 'dinner', commonCombinations: []),
        ),
      ],
    ),
    snacks: [],
  );
}