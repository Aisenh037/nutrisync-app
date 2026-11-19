/// Dietary substitution models for NutriSync GCP AI Enhancement

/// Dietary substitution for restricted ingredients
class DietarySubstitution {
  final String originalIngredient;
  final String substitution;
  final String reason;
  final List<String> dietaryRestrictions;
  final double nutritionalSimilarity; // 0.0 to 1.0
  final double costDifference; // multiplier, 1.0 = same cost

  const DietarySubstitution({
    required this.originalIngredient,
    required this.substitution,
    required this.reason,
    required this.dietaryRestrictions,
    required this.nutritionalSimilarity,
    required this.costDifference,
  });

  factory DietarySubstitution.fromJson(Map<String, dynamic> json) {
    return DietarySubstitution(
      originalIngredient: json['originalIngredient'] as String,
      substitution: json['substitution'] as String,
      reason: json['reason'] as String,
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] as List),
      nutritionalSimilarity: (json['nutritionalSimilarity'] as num).toDouble(),
      costDifference: (json['costDifference'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'originalIngredient': originalIngredient,
      'substitution': substitution,
      'reason': reason,
      'dietaryRestrictions': dietaryRestrictions,
      'nutritionalSimilarity': nutritionalSimilarity,
      'costDifference': costDifference,
    };
  }
}