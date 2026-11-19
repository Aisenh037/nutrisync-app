import 'package:json_annotation/json_annotation.dart';
import 'dietary_substitution_models.dart';

/// Shopping list data models for NutriSync GCP AI Enhancement

/// Enhanced shopping list with AI-powered features
class ShoppingList {
  final String listId;
  final String userId;
  final List<ShoppingItem> items;
  final List<String> targetStores;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final MealPlanReference? sourceMealPlan;
  final ShoppingOptimization optimization;
  final double estimatedCost;
  final String notes;

  const ShoppingList({
    required this.listId,
    required this.userId,
    required this.items,
    required this.targetStores,
    required this.createdAt,
    this.updatedAt,
    this.sourceMealPlan,
    required this.optimization,
    required this.estimatedCost,
    this.notes = '',
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      listId: json['listId'] as String,
      userId: json['userId'] as String,
      items: (json['items'] as List)
          .map((item) => ShoppingItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      targetStores: List<String>.from(json['targetStores'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      sourceMealPlan: json['sourceMealPlan'] != null
          ? MealPlanReference.fromJson(json['sourceMealPlan'] as Map<String, dynamic>)
          : null,
      optimization: ShoppingOptimization.fromJson(json['optimization'] as Map<String, dynamic>),
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listId': listId,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'targetStores': targetStores,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sourceMealPlan': sourceMealPlan?.toJson(),
      'optimization': optimization.toJson(),
      'estimatedCost': estimatedCost,
      'notes': notes,
    };
  }

  ShoppingList copyWith({
    String? listId,
    String? userId,
    List<ShoppingItem>? items,
    List<String>? targetStores,
    DateTime? createdAt,
    DateTime? updatedAt,
    MealPlanReference? sourceMealPlan,
    ShoppingOptimization? optimization,
    double? estimatedCost,
    String? notes,
  }) {
    return ShoppingList(
      listId: listId ?? this.listId,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      targetStores: targetStores ?? this.targetStores,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceMealPlan: sourceMealPlan ?? this.sourceMealPlan,
      optimization: optimization ?? this.optimization,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notes: notes ?? this.notes,
    );
  }
}

/// Individual shopping item with enhanced features
class ShoppingItem {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final StoreSection section;
  final double estimatedPrice;
  final bool isPurchased;
  final List<String> alternatives;
  final List<DietarySubstitution> substitutions;
  final IngredientConsolidation? consolidation;
  final double priority; // 0.0 to 1.0, higher = more important

  const ShoppingItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.section,
    required this.estimatedPrice,
    this.isPurchased = false,
    this.alternatives = const [],
    this.substitutions = const [],
    this.consolidation,
    this.priority = 0.5,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      itemId: json['itemId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      section: StoreSection.values.firstWhere(
        (e) => e.toString() == json['section'],
        orElse: () => StoreSection.other,
      ),
      estimatedPrice: (json['estimatedPrice'] as num).toDouble(),
      isPurchased: json['isPurchased'] as bool? ?? false,
      alternatives: List<String>.from(json['alternatives'] as List? ?? []),
      substitutions: (json['substitutions'] as List? ?? [])
          .map((sub) => DietarySubstitution.fromJson(sub as Map<String, dynamic>))
          .toList(),
      consolidation: json['consolidation'] != null
          ? IngredientConsolidation.fromJson(json['consolidation'] as Map<String, dynamic>)
          : null,
      priority: (json['priority'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'section': section.toString(),
      'estimatedPrice': estimatedPrice,
      'isPurchased': isPurchased,
      'alternatives': alternatives,
      'substitutions': substitutions.map((sub) => sub.toJson()).toList(),
      'consolidation': consolidation?.toJson(),
      'priority': priority,
    };
  }

  ShoppingItem copyWith({
    String? itemId,
    String? name,
    double? quantity,
    String? unit,
    StoreSection? section,
    double? estimatedPrice,
    bool? isPurchased,
    List<String>? alternatives,
    List<DietarySubstitution>? substitutions,
    IngredientConsolidation? consolidation,
    double? priority,
  }) {
    return ShoppingItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      section: section ?? this.section,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      isPurchased: isPurchased ?? this.isPurchased,
      alternatives: alternatives ?? this.alternatives,
      substitutions: substitutions ?? this.substitutions,
      consolidation: consolidation ?? this.consolidation,
      priority: priority ?? this.priority,
    );
  }
}

/// Store section organization for efficient shopping
enum StoreSection {
  produce,
  dairy,
  meat,
  bakery,
  pantry,
  frozen,
  spices,
  beverages,
  snacks,
  health,
  international,
  other,
}

extension StoreSectionExtension on StoreSection {
  String get displayName {
    switch (this) {
      case StoreSection.produce:
        return 'Produce';
      case StoreSection.dairy:
        return 'Dairy';
      case StoreSection.meat:
        return 'Meat & Seafood';
      case StoreSection.bakery:
        return 'Bakery';
      case StoreSection.pantry:
        return 'Pantry';
      case StoreSection.frozen:
        return 'Frozen';
      case StoreSection.spices:
        return 'Spices & Seasonings';
      case StoreSection.beverages:
        return 'Beverages';
      case StoreSection.snacks:
        return 'Snacks';
      case StoreSection.health:
        return 'Health & Wellness';
      case StoreSection.international:
        return 'International';
      case StoreSection.other:
        return 'Other';
    }
  }

  String get hindiName {
    switch (this) {
      case StoreSection.produce:
        return 'फल-सब्जी';
      case StoreSection.dairy:
        return 'डेयरी';
      case StoreSection.meat:
        return 'मांस-मछली';
      case StoreSection.bakery:
        return 'बेकरी';
      case StoreSection.pantry:
        return 'किराना';
      case StoreSection.frozen:
        return 'फ्रोजन';
      case StoreSection.spices:
        return 'मसाले';
      case StoreSection.beverages:
        return 'पेय पदार्थ';
      case StoreSection.snacks:
        return 'नाश्ता';
      case StoreSection.health:
        return 'स्वास्थ्य';
      case StoreSection.international:
        return 'अंतर्राष्ट्रीय';
      case StoreSection.other:
        return 'अन्य';
    }
  }
}



/// Ingredient consolidation information
class IngredientConsolidation {
  final List<String> sourceRecipes;
  final List<QuantityContribution> contributions;
  final double totalQuantity;
  final String consolidatedUnit;

  const IngredientConsolidation({
    required this.sourceRecipes,
    required this.contributions,
    required this.totalQuantity,
    required this.consolidatedUnit,
  });

  factory IngredientConsolidation.fromJson(Map<String, dynamic> json) {
    return IngredientConsolidation(
      sourceRecipes: List<String>.from(json['sourceRecipes'] as List),
      contributions: (json['contributions'] as List)
          .map((contrib) => QuantityContribution.fromJson(contrib as Map<String, dynamic>))
          .toList(),
      totalQuantity: (json['totalQuantity'] as num).toDouble(),
      consolidatedUnit: json['consolidatedUnit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceRecipes': sourceRecipes,
      'contributions': contributions.map((contrib) => contrib.toJson()).toList(),
      'totalQuantity': totalQuantity,
      'consolidatedUnit': consolidatedUnit,
    };
  }
}

/// Quantity contribution from each recipe
class QuantityContribution {
  final String recipeName;
  final double quantity;
  final String unit;
  final int servings;

  const QuantityContribution({
    required this.recipeName,
    required this.quantity,
    required this.unit,
    required this.servings,
  });

  factory QuantityContribution.fromJson(Map<String, dynamic> json) {
    return QuantityContribution(
      recipeName: json['recipeName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      servings: json['servings'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipeName': recipeName,
      'quantity': quantity,
      'unit': unit,
      'servings': servings,
    };
  }
}

/// Shopping optimization data
class ShoppingOptimization {
  final Map<StoreSection, List<String>> sectionOrganization;
  final List<String> suggestedStoreOrder;
  final double estimatedShoppingTime; // in minutes
  final List<ShoppingTip> tips;

  const ShoppingOptimization({
    required this.sectionOrganization,
    required this.suggestedStoreOrder,
    required this.estimatedShoppingTime,
    this.tips = const [],
  });

  factory ShoppingOptimization.fromJson(Map<String, dynamic> json) {
    final sectionOrgMap = <StoreSection, List<String>>{};
    final sectionOrgJson = json['sectionOrganization'] as Map<String, dynamic>;
    
    for (final entry in sectionOrgJson.entries) {
      final section = StoreSection.values.firstWhere(
        (e) => e.toString() == entry.key,
        orElse: () => StoreSection.other,
      );
      sectionOrgMap[section] = List<String>.from(entry.value as List);
    }

    return ShoppingOptimization(
      sectionOrganization: sectionOrgMap,
      suggestedStoreOrder: List<String>.from(json['suggestedStoreOrder'] as List),
      estimatedShoppingTime: (json['estimatedShoppingTime'] as num).toDouble(),
      tips: (json['tips'] as List? ?? [])
          .map((tip) => ShoppingTip.fromJson(tip as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final sectionOrgJson = <String, List<String>>{};
    for (final entry in sectionOrganization.entries) {
      sectionOrgJson[entry.key.toString()] = entry.value;
    }

    return {
      'sectionOrganization': sectionOrgJson,
      'suggestedStoreOrder': suggestedStoreOrder,
      'estimatedShoppingTime': estimatedShoppingTime,
      'tips': tips.map((tip) => tip.toJson()).toList(),
    };
  }
}

/// Shopping tip for better experience
class ShoppingTip {
  final String title;
  final String description;
  final ShoppingTipType type;

  const ShoppingTip({
    required this.title,
    required this.description,
    required this.type,
  });

  factory ShoppingTip.fromJson(Map<String, dynamic> json) {
    return ShoppingTip(
      title: json['title'] as String,
      description: json['description'] as String,
      type: ShoppingTipType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ShoppingTipType.cost,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.toString(),
    };
  }
}

enum ShoppingTipType {
  cost,
  time,
  health,
  seasonal,
  storage,
}

/// Meal plan reference for shopping list generation
class MealPlanReference {
  final String mealPlanId;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final List<String> includedMeals; // breakfast, lunch, dinner, snacks

  const MealPlanReference({
    required this.mealPlanId,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.includedMeals,
  });

  factory MealPlanReference.fromJson(Map<String, dynamic> json) {
    return MealPlanReference(
      mealPlanId: json['mealPlanId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      numberOfDays: json['numberOfDays'] as int,
      includedMeals: List<String>.from(json['includedMeals'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealPlanId': mealPlanId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'numberOfDays': numberOfDays,
      'includedMeals': includedMeals,
    };
  }
}

/// Pantry inventory for duplicate checking
class PantryInventory {
  final String userId;
  final List<PantryItem> items;
  final DateTime lastUpdated;

  const PantryInventory({
    required this.userId,
    required this.items,
    required this.lastUpdated,
  });

  factory PantryInventory.fromJson(Map<String, dynamic> json) {
    return PantryInventory(
      userId: json['userId'] as String,
      items: (json['items'] as List)
          .map((item) => PantryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Individual pantry item
class PantryItem {
  final String itemId;
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final DateTime addedDate;
  final bool isRunningLow;

  const PantryItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    required this.addedDate,
    this.isRunningLow = false,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      itemId: json['itemId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate'] as String) 
          : null,
      addedDate: DateTime.parse(json['addedDate'] as String),
      isRunningLow: json['isRunningLow'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': expiryDate?.toIso8601String(),
      'addedDate': addedDate.toIso8601String(),
      'isRunningLow': isRunningLow,
    };
  }
}