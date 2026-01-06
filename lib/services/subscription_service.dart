import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Service for managing user subscriptions and tier-based access control
class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Subscription tier limits
  static const Map<String, int> tierLimits = {
    'free': 50,      // 50 queries per month
    'premium': 1000, // 1000 queries per month
  };

  // Premium features list
  static const List<String> premiumFeatures = [
    'unlimited_voice_queries',
    'personalized_meal_plans',
    'advanced_nutrition_analysis',
    'grocery_list_optimization',
    'calendar_integration',
    'priority_support',
    'export_data',
    'family_profiles',
  ];

  /// Upgrade user to premium subscription
  Future<FirestoreResult<void>> upgradeToPremium({
    required String uid,
    DateTime? expiresAt,
  }) async {
    try {
      final updateData = {
        'subscriptionTier': 'premium',
        'monthlyQueriesLimit': tierLimits['premium'],
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (expiresAt != null) {
        updateData['subscriptionExpiresAt'] = expiresAt.toIso8601String();
      }

      await _db.collection('users').doc(uid).update(updateData);
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to upgrade subscription: $e');
    }
  }

  /// Downgrade user to free subscription
  Future<FirestoreResult<void>> downgradeToFree(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'subscriptionTier': 'free',
        'monthlyQueriesLimit': tierLimits['free'],
        'subscriptionExpiresAt': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to downgrade subscription: $e');
    }
  }

  /// Check if user has access to a specific feature
  Future<FirestoreResult<bool>> hasFeatureAccess(String uid, String feature) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return FirestoreResult<bool>(error: 'User not found');
      }

      final user = UserModel.fromMap(doc.data()!);
      
      // Free features are always accessible
      if (!premiumFeatures.contains(feature)) {
        return FirestoreResult<bool>(data: true);
      }

      // Check premium access
      final hasAccess = user.isPremium;
      return FirestoreResult<bool>(data: hasAccess);
    } catch (e) {
      return FirestoreResult<bool>(error: 'Failed to check feature access: $e');
    }
  }

  /// Increment user's query count
  Future<FirestoreResult<void>> incrementQueryCount(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return FirestoreResult<void>(error: 'User not found');
      }

      final user = UserModel.fromMap(doc.data()!);
      final now = DateTime.now();
      
      // Reset count if it's a new month
      bool shouldReset = false;
      if (user.lastQueryResetDate == null) {
        shouldReset = true;
      } else {
        final lastReset = user.lastQueryResetDate!;
        shouldReset = now.month != lastReset.month || now.year != lastReset.year;
      }

      final newCount = shouldReset ? 1 : user.dailyQueriesUsed + 1;
      
      await _db.collection('users').doc(uid).update({
        'dailyQueriesUsed': newCount,
        'lastQueryResetDate': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to increment query count: $e');
    }
  }

  /// Check if user can make a query (within limits)
  Future<FirestoreResult<bool>> canMakeQuery(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return FirestoreResult<bool>(error: 'User not found');
      }

      final user = UserModel.fromMap(doc.data()!);
      
      // Premium users have higher limits
      if (user.isPremium) {
        return FirestoreResult<bool>(data: !user.hasReachedQueryLimit);
      }

      // Free users have lower limits
      return FirestoreResult<bool>(data: !user.hasReachedQueryLimit);
    } catch (e) {
      return FirestoreResult<bool>(error: 'Failed to check query limit: $e');
    }
  }

  /// Get subscription status and usage information
  Future<FirestoreResult<Map<String, dynamic>>> getSubscriptionStatus(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return FirestoreResult<Map<String, dynamic>>(error: 'User not found');
      }

      final user = UserModel.fromMap(doc.data()!);
      
      final status = {
        'tier': user.subscriptionTier,
        'isPremium': user.isPremium,
        'expiresAt': user.subscriptionExpiresAt?.toIso8601String(),
        'queriesUsed': user.dailyQueriesUsed,
        'queriesLimit': user.monthlyQueriesLimit,
        'remainingQueries': user.remainingQueries,
        'hasReachedLimit': user.hasReachedQueryLimit,
        'lastResetDate': user.lastQueryResetDate?.toIso8601String(),
      };

      return FirestoreResult<Map<String, dynamic>>(data: status);
    } catch (e) {
      return FirestoreResult<Map<String, dynamic>>(error: 'Failed to get subscription status: $e');
    }
  }

  /// Get list of available features for user's tier
  Future<FirestoreResult<Map<String, bool>>> getAvailableFeatures(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return FirestoreResult<Map<String, bool>>(error: 'User not found');
      }

      final user = UserModel.fromMap(doc.data()!);
      final features = <String, bool>{};

      // Basic features (always available)
      features['basic_voice_queries'] = true;
      features['meal_logging'] = true;
      features['basic_nutrition_info'] = true;
      features['hinglish_support'] = true;

      // Premium features
      for (final feature in premiumFeatures) {
        features[feature] = user.isPremium;
      }

      return FirestoreResult<Map<String, bool>>(data: features);
    } catch (e) {
      return FirestoreResult<Map<String, bool>>(error: 'Failed to get available features: $e');
    }
  }

  /// Show upgrade prompt for premium features
  Map<String, dynamic> getUpgradePrompt(String feature) {
    final prompts = {
      'unlimited_voice_queries': {
        'title': 'Unlimited Voice Queries',
        'message': 'Get unlimited voice interactions with our AI nutritionist. Upgrade to Premium!',
        'benefits': ['Unlimited monthly queries', 'Priority response time', '24/7 availability'],
      },
      'personalized_meal_plans': {
        'title': 'Personalized Meal Plans',
        'message': 'Get custom meal plans tailored to your health goals and preferences.',
        'benefits': ['Custom meal planning', 'Regional cuisine focus', 'Dietary restriction support'],
      },
      'advanced_nutrition_analysis': {
        'title': 'Advanced Nutrition Analysis',
        'message': 'Deep dive into your nutrition with detailed analysis and recommendations.',
        'benefits': ['Detailed nutrient breakdown', 'Deficiency detection', 'Supplement suggestions'],
      },
      'grocery_list_optimization': {
        'title': 'Smart Grocery Lists',
        'message': 'Automatically generate optimized grocery lists from your meal plans.',
        'benefits': ['Auto-generated lists', 'Budget optimization', 'Healthy alternatives'],
      },
      'calendar_integration': {
        'title': 'Calendar Integration',
        'message': 'Sync your meal plans with your calendar for perfect timing.',
        'benefits': ['Calendar sync', 'Meal reminders', 'Schedule optimization'],
      },
    };

    return prompts[feature] ?? {
      'title': 'Premium Feature',
      'message': 'This feature is available with Premium subscription.',
      'benefits': ['Enhanced functionality', 'Priority support', 'Advanced features'],
    };
  }

  /// Process subscription renewal
  Future<FirestoreResult<void>> renewSubscription({
    required String uid,
    required DateTime newExpiryDate,
  }) async {
    try {
      await _db.collection('users').doc(uid).update({
        'subscriptionExpiresAt': newExpiryDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to renew subscription: $e');
    }
  }

  /// Cancel subscription (user keeps premium until expiry)
  Future<FirestoreResult<void>> cancelSubscription(String uid) async {
    try {
      // Don't immediately downgrade, let it expire naturally
      await _db.collection('users').doc(uid).update({
        'subscriptionCancelled': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to cancel subscription: $e');
    }
  }

  /// Check and process expired subscriptions (should be run periodically)
  Future<FirestoreResult<List<String>>> processExpiredSubscriptions() async {
    try {
      final now = DateTime.now();
      final query = _db
          .collection('users')
          .where('subscriptionTier', isEqualTo: 'premium')
          .where('subscriptionExpiresAt', isLessThan: now.toIso8601String());

      final snapshot = await query.get();
      final expiredUsers = <String>[];

      for (final doc in snapshot.docs) {
        final uid = doc.id;
        await downgradeToFree(uid);
        expiredUsers.add(uid);
      }

      return FirestoreResult<List<String>>(data: expiredUsers);
    } catch (e) {
      return FirestoreResult<List<String>>(error: 'Failed to process expired subscriptions: $e');
    }
  }
}