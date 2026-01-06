import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    group('BMI Calculations', () {
      test('BMI calculation works correctly', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          height: 175.0, // 175 cm
          weight: 70.0,  // 70 kg
        );

        // Act
        final bmi = user.bmi;
        final bmiCategory = user.bmiCategory;

        // Assert
        expect(bmi, isNotNull);
        expect(bmi!, closeTo(22.86, 0.01)); // 70 / (1.75^2) ≈ 22.86
        expect(bmiCategory, equals('Normal weight'));
      });

      test('BMI returns null when height or weight missing', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          height: 175.0, // Only height provided
        );

        // Act & Assert
        expect(user.bmi, isNull);
        expect(user.bmiCategory, isNull);
      });

      test('BMI categories are correct', () {
        final testCases = [
          {'height': 170.0, 'weight': 50.0, 'expected': 'Underweight'}, // BMI: 17.3
          {'height': 170.0, 'weight': 65.0, 'expected': 'Normal weight'}, // BMI: 22.5
          {'height': 170.0, 'weight': 80.0, 'expected': 'Overweight'}, // BMI: 27.7
          {'height': 170.0, 'weight': 95.0, 'expected': 'Obese'}, // BMI: 32.9
        ];

        for (final testCase in testCases) {
          final user = UserModel(
            uid: 'test-uid',
            name: 'Test User',
            email: 'test@example.com',
            height: testCase['height'] as double,
            weight: testCase['weight'] as double,
          );

          expect(user.bmiCategory, equals(testCase['expected']),
              reason: 'Height: ${testCase['height']}, Weight: ${testCase['weight']}');
        }
      });
    });

    group('Subscription Status', () {
      test('isPremium returns correct status for free user', () {
        // Arrange
        final freeUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'free',
        );

        // Act & Assert
        expect(freeUser.isPremium, isFalse);
      });

      test('isPremium returns correct status for active premium user', () {
        // Arrange
        final premiumUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'premium',
          subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
        );

        // Act & Assert
        expect(premiumUser.isPremium, isTrue);
      });

      test('isPremium returns false for expired premium user', () {
        // Arrange
        final expiredPremiumUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'premium',
          subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        // Act & Assert
        expect(expiredPremiumUser.isPremium, isFalse);
      });

      test('isPremium returns true for lifetime premium user', () {
        // Arrange
        final lifetimePremiumUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'premium',
          // No expiry date = lifetime
        );

        // Act & Assert
        expect(lifetimePremiumUser.isPremium, isTrue);
      });
    });

    group('Query Limits', () {
      test('hasReachedQueryLimit returns false when within limit', () {
        // Arrange
        final userWithinLimit = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 25,
          monthlyQueriesLimit: 50,
        );

        // Act & Assert
        expect(userWithinLimit.hasReachedQueryLimit, isFalse);
      });

      test('hasReachedQueryLimit returns true when at limit', () {
        // Arrange
        final userAtLimit = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 50,
          monthlyQueriesLimit: 50,
        );

        // Act & Assert
        expect(userAtLimit.hasReachedQueryLimit, isTrue);
      });

      test('remainingQueries calculates correctly', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 30,
          monthlyQueriesLimit: 50,
        );

        // Act & Assert
        expect(user.remainingQueries, equals(20));
      });

      test('remainingQueries never goes below zero', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 60,
          monthlyQueriesLimit: 50,
        );

        // Act & Assert
        expect(user.remainingQueries, equals(0));
      });
    });

    group('Medical Conditions and Allergies', () {
      test('hasMedicalCondition works case-insensitively', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          medicalConditions: ['Diabetes', 'Hypertension'],
        );

        // Act & Assert
        expect(user.hasMedicalCondition('diabetes'), isTrue); // Case insensitive
        expect(user.hasMedicalCondition('Diabetes'), isTrue);
        expect(user.hasMedicalCondition('DIABETES'), isTrue);
        expect(user.hasMedicalCondition('Heart disease'), isFalse);
      });

      test('hasAllergy works case-insensitively', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          allergies: ['Nuts', 'Dairy'],
        );

        // Act & Assert
        expect(user.hasAllergy('nuts'), isTrue); // Case insensitive
        expect(user.hasAllergy('Nuts'), isTrue);
        expect(user.hasAllergy('NUTS'), isTrue);
        expect(user.hasAllergy('Gluten'), isFalse);
      });

      test('dislikesFood works case-insensitively', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          foodDislikes: ['Spicy food', 'Bitter gourd'],
        );

        // Act & Assert
        expect(user.dislikesFood('spicy food'), isTrue); // Case insensitive
        expect(user.dislikesFood('Spicy Food'), isTrue);
        expect(user.dislikesFood('SPICY FOOD'), isTrue);
        expect(user.dislikesFood('Sweet food'), isFalse);
      });
    });

    group('Profile Completeness', () {
      test('isProfileComplete returns false for incomplete profile', () {
        // Arrange
        final incompleteUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(incompleteUser.isProfileComplete, isFalse);
      });

      test('isProfileComplete returns true for complete profile', () {
        // Arrange
        final completeUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          age: 25,
          gender: 'Female',
          height: 165.0,
          weight: 60.0,
          healthGoals: ['Weight loss'],
        );

        // Act & Assert
        expect(completeUser.isProfileComplete, isTrue);
      });

      test('isProfileComplete returns true with partial physical measurements', () {
        // Arrange - Only height provided, no weight
        final partialUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          age: 25,
          gender: 'Male',
          height: 175.0, // Only height, no weight
          healthGoals: ['Muscle building'],
        );

        // Act & Assert
        expect(partialUser.isProfileComplete, isTrue);
      });
    });

    group('Cultural Preferences', () {
      test('preferredRegionalCuisine returns default when not set', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user.preferredRegionalCuisine, equals('North Indian'));
      });

      test('preferredRegionalCuisine returns set preference', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          culturalPreferences: {'preferredRegion': 'South Indian'},
        );

        // Act & Assert
        expect(user.preferredRegionalCuisine, equals('South Indian'));
      });
    });

    group('Serialization', () {
      test('toMap and fromMap work correctly', () {
        // Arrange
        final originalUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          age: 30,
          gender: 'Male',
          height: 175.0,
          weight: 70.0,
          activityLevel: 'Active',
          dietaryNeeds: ['Vegetarian', 'Gluten-free'],
          healthGoals: ['Weight loss', 'Better digestion'],
          medicalConditions: ['Diabetes'],
          allergies: ['Nuts'],
          foodDislikes: ['Spicy food'],
          preferredLanguage: 'hinglish',
          culturalPreferences: {'preferredRegion': 'South Indian'},
          subscriptionTier: 'premium',
          dailyQueriesUsed: 25,
          monthlyQueriesLimit: 1000,
        );

        // Act
        final map = originalUser.toMap();
        final reconstructedUser = UserModel.fromMap(map);

        // Assert
        expect(reconstructedUser.uid, equals(originalUser.uid));
        expect(reconstructedUser.name, equals(originalUser.name));
        expect(reconstructedUser.email, equals(originalUser.email));
        expect(reconstructedUser.age, equals(originalUser.age));
        expect(reconstructedUser.gender, equals(originalUser.gender));
        expect(reconstructedUser.height, equals(originalUser.height));
        expect(reconstructedUser.weight, equals(originalUser.weight));
        expect(reconstructedUser.activityLevel, equals(originalUser.activityLevel));
        expect(reconstructedUser.dietaryNeeds, equals(originalUser.dietaryNeeds));
        expect(reconstructedUser.healthGoals, equals(originalUser.healthGoals));
        expect(reconstructedUser.medicalConditions, equals(originalUser.medicalConditions));
        expect(reconstructedUser.allergies, equals(originalUser.allergies));
        expect(reconstructedUser.foodDislikes, equals(originalUser.foodDislikes));
        expect(reconstructedUser.preferredLanguage, equals(originalUser.preferredLanguage));
        expect(reconstructedUser.culturalPreferences, equals(originalUser.culturalPreferences));
        expect(reconstructedUser.subscriptionTier, equals(originalUser.subscriptionTier));
        expect(reconstructedUser.dailyQueriesUsed, equals(originalUser.dailyQueriesUsed));
        expect(reconstructedUser.monthlyQueriesLimit, equals(originalUser.monthlyQueriesLimit));
      });

      test('fromMap handles missing fields gracefully', () {
        // Arrange
        final minimalMap = {
          'uid': 'test-uid',
          'name': 'Test User',
          'email': 'test@example.com',
        };

        // Act
        final user = UserModel.fromMap(minimalMap);

        // Assert
        expect(user.uid, equals('test-uid'));
        expect(user.name, equals('Test User'));
        expect(user.email, equals('test@example.com'));
        expect(user.age, isNull);
        expect(user.gender, isNull);
        expect(user.dietaryNeeds, isEmpty);
        expect(user.healthGoals, isEmpty);
        expect(user.subscriptionTier, equals('free')); // Default value
        expect(user.preferredLanguage, equals('hinglish')); // Default value
      });
    });

    group('copyWith Method', () {
      test('copyWith updates specified fields only', () {
        // Arrange
        final originalUser = UserModel(
          uid: 'test-uid',
          name: 'Original Name',
          email: 'original@example.com',
          age: 25,
          subscriptionTier: 'free',
        );

        // Act
        final updatedUser = originalUser.copyWith(
          name: 'Updated Name',
          age: 30,
        );

        // Assert
        expect(updatedUser.uid, equals(originalUser.uid)); // Unchanged
        expect(updatedUser.email, equals(originalUser.email)); // Unchanged
        expect(updatedUser.subscriptionTier, equals(originalUser.subscriptionTier)); // Unchanged
        expect(updatedUser.name, equals('Updated Name')); // Changed
        expect(updatedUser.age, equals(30)); // Changed
      });
    });
  });
}