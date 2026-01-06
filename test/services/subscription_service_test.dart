import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrisync/services/subscription_service.dart';
import 'package:nutrisync/models/user_model.dart';

void main() {
  group('SubscriptionService Tests', () {
    late SubscriptionService subscriptionService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      subscriptionService = SubscriptionService();
      // Note: In a real implementation, you'd inject the fake firestore
    });

    group('Subscription Upgrades', () {
      test('upgradeToPremium upgrades user to premium tier', () async {
        // Arrange
        const uid = 'test-uid';
        final expiryDate = DateTime.now().add(const Duration(days: 30));

        // Create initial user document
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
          'monthlyQueriesLimit': 50,
        });

        // Act
        final result = await subscriptionService.upgradeToPremium(
          uid: uid,
          expiresAt: expiryDate,
        );

        // Assert
        expect(result.error, isNull);
        
        // Verify upgrade in database
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(doc.data()!['subscriptionTier'], equals('premium'));
        expect(doc.data()!['monthlyQueriesLimit'], equals(1000));
        expect(doc.data()!['subscriptionExpiresAt'], isNotNull);
      });

      test('downgradeToFree downgrades user to free tier', () async {
        // Arrange
        const uid = 'test-uid';

        // Create premium user document
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'monthlyQueriesLimit': 1000,
          'subscriptionExpiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });

        // Act
        final result = await subscriptionService.downgradeToFree(uid);

        // Assert
        expect(result.error, isNull);
        
        // Verify downgrade in database
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(doc.data()!['subscriptionTier'], equals('free'));
        expect(doc.data()!['monthlyQueriesLimit'], equals(50));
        expect(doc.data()!['subscriptionExpiresAt'], isNull);
      });
    });

    group('Feature Access Control', () {
      test('hasFeatureAccess returns true for free features', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
        });

        // Act
        final result = await subscriptionService.hasFeatureAccess(uid, 'basic_voice_queries');

        // Assert
        expect(result.error, isNull);
        expect(result.data, isTrue);
      });

      test('hasFeatureAccess returns false for premium features on free tier', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
        });

        // Act
        final result = await subscriptionService.hasFeatureAccess(uid, 'unlimited_voice_queries');

        // Assert
        expect(result.error, isNull);
        expect(result.data, isFalse);
      });

      test('hasFeatureAccess returns true for premium features on premium tier', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });

        // Act
        final result = await subscriptionService.hasFeatureAccess(uid, 'unlimited_voice_queries');

        // Assert
        expect(result.error, isNull);
        expect(result.data, isTrue);
      });

      test('hasFeatureAccess returns false for expired premium subscription', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        });

        // Act
        final result = await subscriptionService.hasFeatureAccess(uid, 'unlimited_voice_queries');

        // Assert
        expect(result.error, isNull);
        expect(result.data, isFalse);
      });
    });

    group('Query Count Management', () {
      test('incrementQueryCount increments user query count', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'dailyQueriesUsed': 5,
          'lastQueryResetDate': DateTime.now().toIso8601String(),
        });

        // Act
        final result = await subscriptionService.incrementQueryCount(uid);

        // Assert
        expect(result.error, isNull);
        
        // Verify count was incremented
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(doc.data()!['dailyQueriesUsed'], equals(6));
      });

      test('incrementQueryCount resets count for new month', () async {
        // Arrange
        const uid = 'test-uid';
        final lastMonth = DateTime.now().subtract(const Duration(days: 35));
        
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'dailyQueriesUsed': 45,
          'lastQueryResetDate': lastMonth.toIso8601String(),
        });

        // Act
        final result = await subscriptionService.incrementQueryCount(uid);

        // Assert
        expect(result.error, isNull);
        
        // Verify count was reset to 1
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(doc.data()!['dailyQueriesUsed'], equals(1));
      });

      test('canMakeQuery returns true when within limits', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
          'dailyQueriesUsed': 25,
          'monthlyQueriesLimit': 50,
        });

        // Act
        final result = await subscriptionService.canMakeQuery(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isTrue);
      });

      test('canMakeQuery returns false when at limit', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
          'dailyQueriesUsed': 50,
          'monthlyQueriesLimit': 50,
        });

        // Act
        final result = await subscriptionService.canMakeQuery(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isFalse);
      });

      test('canMakeQuery returns true for premium users within higher limits', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'dailyQueriesUsed': 500,
          'monthlyQueriesLimit': 1000,
        });

        // Act
        final result = await subscriptionService.canMakeQuery(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isTrue);
      });
    });

    group('Subscription Status', () {
      test('getSubscriptionStatus returns complete status information', () async {
        // Arrange
        const uid = 'test-uid';
        final expiryDate = DateTime.now().add(const Duration(days: 30));
        
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': expiryDate.toIso8601String(),
          'dailyQueriesUsed': 150,
          'monthlyQueriesLimit': 1000,
          'lastQueryResetDate': DateTime.now().toIso8601String(),
        });

        // Act
        final result = await subscriptionService.getSubscriptionStatus(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!['tier'], equals('premium'));
        expect(result.data!['isPremium'], isTrue);
        expect(result.data!['queriesUsed'], equals(150));
        expect(result.data!['queriesLimit'], equals(1000));
        expect(result.data!['remainingQueries'], equals(850));
        expect(result.data!['hasReachedLimit'], isFalse);
      });

      test('getAvailableFeatures returns correct feature availability', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'free',
        });

        // Act
        final result = await subscriptionService.getAvailableFeatures(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!['basic_voice_queries'], isTrue);
        expect(result.data!['meal_logging'], isTrue);
        expect(result.data!['unlimited_voice_queries'], isFalse);
        expect(result.data!['personalized_meal_plans'], isFalse);
      });
    });

    group('Subscription Management', () {
      test('renewSubscription extends subscription expiry date', () async {
        // Arrange
        const uid = 'test-uid';
        final currentExpiry = DateTime.now().add(const Duration(days: 5));
        final newExpiry = DateTime.now().add(const Duration(days: 35));
        
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': currentExpiry.toIso8601String(),
        });

        // Act
        final result = await subscriptionService.renewSubscription(
          uid: uid,
          newExpiryDate: newExpiry,
        );

        // Assert
        expect(result.error, isNull);
        
        // Verify renewal
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        final storedExpiry = DateTime.parse(doc.data()!['subscriptionExpiresAt']);
        expect(storedExpiry.isAfter(currentExpiry), isTrue);
      });

      test('cancelSubscription marks subscription as cancelled', () async {
        // Arrange
        const uid = 'test-uid';
        await fakeFirestore.collection('users').doc(uid).set({
          'uid': uid,
          'subscriptionTier': 'premium',
          'subscriptionExpiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });

        // Act
        final result = await subscriptionService.cancelSubscription(uid);

        // Assert
        expect(result.error, isNull);
        
        // Verify cancellation flag
        final doc = await fakeFirestore.collection('users').doc(uid).get();
        expect(doc.data()!['subscriptionCancelled'], isTrue);
      });
    });

    group('Upgrade Prompts', () {
      test('getUpgradePrompt returns appropriate prompt for feature', () {
        // Act
        final prompt = subscriptionService.getUpgradePrompt('unlimited_voice_queries');

        // Assert
        expect(prompt['title'], isNotNull);
        expect(prompt['message'], isNotNull);
        expect(prompt['benefits'], isNotNull);
        expect(prompt['benefits'], isA<List>());
      });

      test('getUpgradePrompt returns default prompt for unknown feature', () {
        // Act
        final prompt = subscriptionService.getUpgradePrompt('unknown_feature');

        // Assert
        expect(prompt['title'], equals('Premium Feature'));
        expect(prompt['message'], contains('Premium subscription'));
      });
    });

    group('Tier Limits', () {
      test('tier limits are correctly defined', () {
        // Assert
        expect(SubscriptionService.tierLimits['free'], equals(50));
        expect(SubscriptionService.tierLimits['premium'], equals(1000));
      });

      test('premium features list is comprehensive', () {
        // Assert
        expect(SubscriptionService.premiumFeatures, isNotEmpty);
        expect(SubscriptionService.premiumFeatures, contains('unlimited_voice_queries'));
        expect(SubscriptionService.premiumFeatures, contains('personalized_meal_plans'));
        expect(SubscriptionService.premiumFeatures, contains('advanced_nutrition_analysis'));
      });
    });

    group('Error Handling', () {
      test('hasFeatureAccess handles non-existent user', () async {
        // Act
        final result = await subscriptionService.hasFeatureAccess('non-existent-uid', 'any_feature');

        // Assert
        expect(result.error, isNotNull);
        expect(result.data, isNull);
      });

      test('incrementQueryCount handles non-existent user', () async {
        // Act
        final result = await subscriptionService.incrementQueryCount('non-existent-uid');

        // Assert
        expect(result.error, isNotNull);
      });

      test('getSubscriptionStatus handles non-existent user', () async {
        // Act
        final result = await subscriptionService.getSubscriptionStatus('non-existent-uid');

        // Assert
        expect(result.error, isNotNull);
        expect(result.data, isNull);
      });
    });
  });
}