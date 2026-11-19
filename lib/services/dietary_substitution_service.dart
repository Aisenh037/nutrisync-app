import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/dietary_substitution_models.dart';
import '../models/user_model.dart';

/// Enhanced Dietary Substitution Service for NutriSync GCP AI Enhancement
/// Implements intelligent substitution suggestions with learning capabilities
class DietarySubstitutionService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  DietarySubstitutionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get substitution suggestions for a list of ingredients
  /// Requirement 4.4: Dietary substitution suggestions
  Future<List<DietarySubstitution>> getSubstitutions({
    required List<String> ingredients,
    required List<String> dietaryRestrictions,
    required String userId,
    String? culturalContext,
  }) async {
    final substitutions = <DietarySubstitution>[];

    for (final ingredient in ingredients) {
      final ingredientSubs = await _findSubstitutionsForIngredient(
        ingredient: ingredient,
        dietaryRestrictions: dietaryRestrictions,
        userId: userId,
        culturalContext: culturalContext,
      );
      substitutions.addAll(ingredientSubs);
    }

    // Learn from user preferences
    await _updateUserPreferences(userId, substitutions);

    return substitutions;
  }

  /// Find substitutions for a specific ingredient
  Future<List<DietarySubstitution>> _findSubstitutionsForIngredient({
    required String ingredient,
    required List<String> dietaryRestrictions,
    required String userId,
    String? culturalContext,
  }) async {
    final substitutions = <DietarySubstitution>[];
    final normalizedIngredient = ingredient.toLowerCase().trim();

    // Get user preferences for personalization
    final userPrefs = await _getUserPreferences(userId);

    for (final restriction in dietaryRestrictions) {
      final restrictionLower = restriction.toLowerCase();
      
      // Check database for substitutions
      final dbSubstitutions = _getSubstitutionsFromDatabase(
        normalizedIngredient,
        restrictionLower,
        culturalContext,
      );
      
      for (final subData in dbSubstitutions) {
        // Apply user preference scoring
        final adjustedSimilarity = _adjustForUserPreferences(
          subData.nutritionalSimilarity,
          subData.substitution,
          userPrefs,
        );

        substitutions.add(DietarySubstitution(
          originalIngredient: ingredient,
          substitution: subData.substitution,
          reason: subData.reason,
          dietaryRestrictions: [restriction],
          nutritionalSimilarity: adjustedSimilarity,
          costDifference: subData.costDifference,
        ));
      }
    }

    return substitutions;
  }

  /// Get substitutions from the comprehensive database
  List<_SubstitutionData> _getSubstitutionsFromDatabase(
    String ingredient,
    String restriction,
    String? culturalContext,
  ) {
    final substitutions = <_SubstitutionData>[];

    // Dairy substitutions
    if (ingredient.contains('milk')) {
      if (restriction == 'vegan' || restriction == 'vegetarian') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('almond milk', culturalContext, {
            'indian': 'coconut milk',
            'mediterranean': 'oat milk',
            'asian': 'soy milk',
          }),
          reason: 'Plant-based milk alternative with similar consistency',
          nutritionalSimilarity: 0.7,
          costDifference: 1.5,
        ));
      }
      if (restriction == 'lactose-intolerant') {
        substitutions.add(_SubstitutionData(
          substitution: 'lactose-free milk',
          reason: 'Same nutritional profile without lactose',
          nutritionalSimilarity: 0.95,
          costDifference: 1.3,
        ));
      }
    }

    if (ingredient.contains('ghee')) {
      if (restriction == 'vegan' || restriction == 'vegetarian') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('coconut oil', culturalContext, {
            'indian': 'mustard oil',
            'western': 'olive oil',
            'mediterranean': 'olive oil',
          }),
          reason: 'Plant-based fat with similar cooking properties',
          nutritionalSimilarity: 0.8,
          costDifference: 1.2,
        ));
      }
      if (restriction == 'low-cholesterol') {
        substitutions.add(_SubstitutionData(
          substitution: 'olive oil',
          reason: 'Heart-healthy monounsaturated fats',
          nutritionalSimilarity: 0.7,
          costDifference: 1.4,
        ));
      }
    }

    if (ingredient.contains('butter')) {
      if (restriction == 'vegan' || restriction == 'vegetarian') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('vegan butter', culturalContext, {
            'indian': 'coconut oil',
            'western': 'vegan butter',
          }),
          reason: 'Plant-based butter alternative',
          nutritionalSimilarity: 0.85,
          costDifference: 1.6,
        ));
      }
      if (restriction == 'low-fat') {
        substitutions.add(_SubstitutionData(
          substitution: 'applesauce',
          reason: 'Low-fat baking substitute',
          nutritionalSimilarity: 0.4,
          costDifference: 0.8,
        ));
      }
    }

    // Grain substitutions
    if (ingredient.contains('wheat flour') || ingredient.contains('maida')) {
      if (restriction == 'gluten-free') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('rice flour', culturalContext, {
            'indian': 'rice flour',
            'western': 'almond flour',
            'asian': 'rice flour',
          }),
          reason: 'Gluten-free flour alternative',
          nutritionalSimilarity: 0.8,
          costDifference: 1.3,
        ));
      }
      if (restriction == 'low-carb') {
        substitutions.add(_SubstitutionData(
          substitution: 'almond flour',
          reason: 'Low-carb, high-protein flour alternative',
          nutritionalSimilarity: 0.6,
          costDifference: 4.0,
        ));
      }
    }

    if (ingredient.contains('rice')) {
      if (restriction == 'low-carb') {
        substitutions.add(_SubstitutionData(
          substitution: 'cauliflower rice',
          reason: 'Low-carb vegetable substitute',
          nutritionalSimilarity: 0.3,
          costDifference: 1.8,
        ));
      }
      if (restriction == 'diabetic' || restriction == 'low-glycemic') {
        substitutions.add(_SubstitutionData(
          substitution: 'brown rice',
          reason: 'Lower glycemic index, higher fiber',
          nutritionalSimilarity: 0.9,
          costDifference: 1.2,
        ));
      }
    }

    // Protein substitutions
    if (ingredient.contains('chicken') || ingredient.contains('meat')) {
      if (restriction == 'vegetarian' || restriction == 'vegan') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('tofu', culturalContext, {
            'indian': 'paneer',
            'western': 'tempeh',
            'asian': 'tofu',
          }),
          reason: 'Plant-based protein alternative',
          nutritionalSimilarity: 0.7,
          costDifference: 0.9,
        ));
      }
      if (restriction == 'low-fat') {
        substitutions.add(_SubstitutionData(
          substitution: 'chicken breast',
          reason: 'Lean protein option',
          nutritionalSimilarity: 0.95,
          costDifference: 1.1,
        ));
      }
    }

    // Sugar substitutions
    if (ingredient.contains('sugar')) {
      if (restriction == 'diabetic' || restriction == 'low-sugar') {
        substitutions.add(_SubstitutionData(
          substitution: _getCulturalSubstitution('stevia', culturalContext, {
            'indian': 'jaggery',
            'western': 'stevia',
          }),
          reason: 'Natural sweetener with no blood sugar impact',
          nutritionalSimilarity: 0.2,
          costDifference: 3.0,
        ));
      }
      if (restriction == 'low-calorie') {
        substitutions.add(_SubstitutionData(
          substitution: 'erythritol',
          reason: 'Zero-calorie natural sweetener',
          nutritionalSimilarity: 0.8,
          costDifference: 2.5,
        ));
      }
    }

    // Salt substitutions
    if (ingredient.contains('salt')) {
      if (restriction == 'low-sodium') {
        substitutions.add(_SubstitutionData(
          substitution: 'herb seasoning',
          reason: 'Flavorful alternative without sodium',
          nutritionalSimilarity: 0.3,
          costDifference: 2.0,
        ));
      }
    }

    // Oil substitutions
    if (ingredient.contains('oil') || ingredient.contains('cooking oil')) {
      if (restriction == 'low-fat') {
        substitutions.add(_SubstitutionData(
          substitution: 'vegetable broth',
          reason: 'Fat-free cooking liquid',
          nutritionalSimilarity: 0.2,
          costDifference: 0.8,
        ));
      }
      if (restriction == 'heart-healthy') {
        substitutions.add(_SubstitutionData(
          substitution: 'olive oil',
          reason: 'Heart-healthy monounsaturated fats',
          nutritionalSimilarity: 0.9,
          costDifference: 1.8,
        ));
      }
    }

    return substitutions;
  }

  /// Get cultural adaptation for substitution
  String _getCulturalSubstitution(
    String defaultSubstitution,
    String? culturalContext,
    Map<String, String> culturalAdaptations,
  ) {
    if (culturalContext != null && culturalAdaptations.containsKey(culturalContext)) {
      return culturalAdaptations[culturalContext]!;
    }
    return defaultSubstitution;
  }

  /// Adjust nutritional similarity based on user preferences
  double _adjustForUserPreferences(
    double baseSimilarity,
    String substitution,
    Map<String, double> userPrefs,
  ) {
    final prefScore = userPrefs[substitution.toLowerCase()] ?? 0.5;
    // Blend base similarity with user preference (70% base, 30% preference)
    return (baseSimilarity * 0.7) + (prefScore * 0.3);
  }

  /// Get user preferences for substitutions
  Future<Map<String, double>> _getUserPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_substitution_preferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Map<String, double>.from(data['preferences'] ?? {});
      }
    } catch (e) {
      // Return empty preferences if error
    }
    return {};
  }

  /// Update user preferences based on substitution usage
  Future<void> _updateUserPreferences(
    String userId,
    List<DietarySubstitution> substitutions,
  ) async {
    try {
      final userPrefs = await _getUserPreferences(userId);
      
      // Increment preference scores for suggested substitutions
      for (final sub in substitutions) {
        final key = sub.substitution.toLowerCase();
        userPrefs[key] = (userPrefs[key] ?? 0.5) + 0.1;
        // Cap at 1.0
        if (userPrefs[key]! > 1.0) userPrefs[key] = 1.0;
      }

      await _firestore
          .collection('user_substitution_preferences')
          .doc(userId)
          .set({
        'preferences': userPrefs,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Fail silently for preference updates
    }
  }

  /// Record user feedback on substitution quality
  Future<void> recordSubstitutionFeedback({
    required String userId,
    required String originalIngredient,
    required String substitution,
    required double rating, // 1.0 to 5.0
    String? feedback,
  }) async {
    try {
      final feedbackId = _uuid.v4();
      
      await _firestore
          .collection('substitution_feedback')
          .doc(feedbackId)
          .set({
        'userId': userId,
        'originalIngredient': originalIngredient,
        'substitution': substitution,
        'rating': rating,
        'feedback': feedback,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user preferences based on feedback
      await _updatePreferencesFromFeedback(userId, substitution, rating);
    } catch (e) {
      throw Exception('Failed to record substitution feedback: $e');
    }
  }

  /// Update user preferences based on feedback rating
  Future<void> _updatePreferencesFromFeedback(
    String userId,
    String substitution,
    double rating,
  ) async {
    try {
      final userPrefs = await _getUserPreferences(userId);
      final key = substitution.toLowerCase();
      
      // Convert rating (1-5) to preference score (0-1)
      final preferenceScore = (rating - 1) / 4; // Maps 1-5 to 0-1
      
      // Blend with existing preference (50% existing, 50% new feedback)
      final existingScore = userPrefs[key] ?? 0.5;
      userPrefs[key] = (existingScore * 0.5) + (preferenceScore * 0.5);

      await _firestore
          .collection('user_substitution_preferences')
          .doc(userId)
          .set({
        'preferences': userPrefs,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Fail silently for preference updates
    }
  }

  /// Get substitution analytics for a user
  Future<SubstitutionAnalytics> getSubstitutionAnalytics(String userId) async {
    try {
      final feedbackQuery = await _firestore
          .collection('substitution_feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final feedbacks = feedbackQuery.docs.map((doc) {
        final data = doc.data();
        return SubstitutionFeedback(
          originalIngredient: data['originalIngredient'] ?? '',
          substitution: data['substitution'] ?? '',
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          feedback: data['feedback'],
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      // Calculate analytics
      final totalFeedbacks = feedbacks.length;
      final averageRating = totalFeedbacks > 0
          ? feedbacks.fold<double>(0.0, (sum, f) => sum + f.rating) / totalFeedbacks
          : 0.0;

      final topSubstitutions = _calculateTopSubstitutions(feedbacks);
      final improvementSuggestions = _generateImprovementSuggestions(feedbacks);

      return SubstitutionAnalytics(
        totalSubstitutions: totalFeedbacks,
        averageRating: averageRating,
        topSubstitutions: topSubstitutions,
        recentFeedbacks: feedbacks.take(10).toList(),
        improvementSuggestions: improvementSuggestions,
      );
    } catch (e) {
      throw Exception('Failed to get substitution analytics: $e');
    }
  }

  /// Calculate top-rated substitutions
  List<TopSubstitution> _calculateTopSubstitutions(List<SubstitutionFeedback> feedbacks) {
    final substitutionRatings = <String, List<double>>{};
    
    for (final feedback in feedbacks) {
      substitutionRatings.putIfAbsent(feedback.substitution, () => []).add(feedback.rating);
    }

    final topSubs = substitutionRatings.entries
        .map((entry) {
          final avgRating = entry.value.fold<double>(0.0, (sum, rating) => sum + rating) / entry.value.length;
          return TopSubstitution(
            substitution: entry.key,
            averageRating: avgRating,
            usageCount: entry.value.length,
          );
        })
        .where((sub) => sub.usageCount >= 2) // Only include substitutions used multiple times
        .toList();

    topSubs.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return topSubs.take(5).toList();
  }

  /// Generate improvement suggestions based on feedback
  List<String> _generateImprovementSuggestions(List<SubstitutionFeedback> feedbacks) {
    final suggestions = <String>[];
    
    final lowRatedSubs = feedbacks.where((f) => f.rating < 3.0).toList();
    if (lowRatedSubs.isNotEmpty) {
      suggestions.add('Consider trying different alternatives for ${lowRatedSubs.first.originalIngredient}');
    }

    final highRatedSubs = feedbacks.where((f) => f.rating >= 4.0).toList();
    if (highRatedSubs.isNotEmpty) {
      suggestions.add('You seem to enjoy ${highRatedSubs.first.substitution} - try it in more recipes');
    }

    return suggestions;
  }

  /// Get popular substitutions across all users (anonymized)
  Future<List<PopularSubstitution>> getPopularSubstitutions({
    String? dietaryRestriction,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore.collection('substitution_feedback');
      
      if (dietaryRestriction != null) {
        // This would require additional indexing in a real implementation
        // For now, we'll return general popular substitutions
      }

      final snapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final substitutionCounts = <String, int>{};
      final substitutionRatings = <String, List<double>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final substitution = data['substitution'] as String;
        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

        substitutionCounts[substitution] = (substitutionCounts[substitution] ?? 0) + 1;
        substitutionRatings.putIfAbsent(substitution, () => []).add(rating);
      }

      final popularSubs = substitutionCounts.entries
          .where((entry) => entry.value >= 3) // At least 3 uses
          .map((entry) {
            final ratings = substitutionRatings[entry.key]!;
            final avgRating = ratings.fold<double>(0.0, (sum, r) => sum + r) / ratings.length;
            
            return PopularSubstitution(
              substitution: entry.key,
              usageCount: entry.value,
              averageRating: avgRating,
            );
          })
          .where((sub) => sub.averageRating >= 3.5) // Only well-rated substitutions
          .toList();

      popularSubs.sort((a, b) => b.usageCount.compareTo(a.usageCount));
      return popularSubs.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get popular substitutions: $e');
    }
  }
}

/// Internal substitution data structure
class _SubstitutionData {
  final String substitution;
  final String reason;
  final double nutritionalSimilarity;
  final double costDifference;

  const _SubstitutionData({
    required this.substitution,
    required this.reason,
    required this.nutritionalSimilarity,
    required this.costDifference,
  });
}

/// Substitution feedback data
class SubstitutionFeedback {
  final String originalIngredient;
  final String substitution;
  final double rating;
  final String? feedback;
  final DateTime timestamp;

  const SubstitutionFeedback({
    required this.originalIngredient,
    required this.substitution,
    required this.rating,
    this.feedback,
    required this.timestamp,
  });
}

/// Analytics for user substitution patterns
class SubstitutionAnalytics {
  final int totalSubstitutions;
  final double averageRating;
  final List<TopSubstitution> topSubstitutions;
  final List<SubstitutionFeedback> recentFeedbacks;
  final List<String> improvementSuggestions;

  const SubstitutionAnalytics({
    required this.totalSubstitutions,
    required this.averageRating,
    required this.topSubstitutions,
    required this.recentFeedbacks,
    required this.improvementSuggestions,
  });
}

/// Top-rated substitution
class TopSubstitution {
  final String substitution;
  final double averageRating;
  final int usageCount;

  const TopSubstitution({
    required this.substitution,
    required this.averageRating,
    required this.usageCount,
  });
}

/// Popular substitution across users
class PopularSubstitution {
  final String substitution;
  final int usageCount;
  final double averageRating;

  const PopularSubstitution({
    required this.substitution,
    required this.usageCount,
    required this.averageRating,
  });
}
        