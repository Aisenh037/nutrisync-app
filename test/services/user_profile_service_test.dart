import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrisync/services/user_profile_service.dart';
import 'package:nutrisync/models/user_model.dart';

// Mock UserProfileService that uses FakeFirebaseFirestore
class MockUserProfileService extends UserProfileService {
  final FakeFirebaseFirestore _fakeFirestore;
  
  MockUserProfileService(this._fakeFirestore);
  
  // Override the firestore instance
  @override
  get _db => _fakeFirestore;
}

void main() {
  group('UserProfileService Tests', () {
    late MockUserProfileService profileService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      profileService = MockUserProfileService(fakeFirestore);
    });

    group('Profile Creation', () {
      test('createProfile creates new user with default values', () async {
        // Arrange
        const uid = 'test-uid';
        const name = 'Test User';
        const email = 'test@example.com';

        // Act
        final result = await profileService.createProfile(
          uid: uid,
          name: name,
          email: email,
        );

        // Assert
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!.uid, equals(uid));
        expect(result.data!.name, equals(name));
        expect(result.data!.email, equals(email));
        expect(result.data!.subscriptionTier, equals('free'));
        expect(result.data!.monthlyQueriesLimit, equals(50));
        expect(result.data!.dailyQueriesUsed, equals(0));
        expect(result.data!.createdAt, isNotNull);
        expect(result.data!.updatedAt, isNotNull);
      });

      test('createProfile with dietary needs and health goals', () async {
        // Arrange
        const uid = 'test-uid';
        const name = 'Test User';
        const email = 'test@example.com';
        const dietaryNeeds = ['Vegetarian', 'Gluten-free'];
        const healthGoals = ['Weight loss', 'Better digestion'];

        // Act
        final result = await profileService.createProfile(
          uid: uid,
          name: name,
          email: email,
          dietaryNeeds: dietaryNeeds,
          healthGoals: healthGoals,
        );

        // Assert
        expect(result.error, isNull);
        expect(result.data!.dietaryNeeds, equals(dietaryNeeds));
        expect(result.data!.healthGoals, equals(healthGoals));
      });
    });

    group('Profile Updates', () {
      test('updateProfile updates existing profile', () async {
        // Arrange
        const uid = 'test-uid';
        
        // Create initial profile
        await profileService.createProfile(
          uid: uid,
          name: 'Initial Name',
          email: 'initial@example.com',
        );

        // Act
        final result = await profileService.updateProfile(
          uid: uid,
          name: 'Updated Name',
          age: 25,
          gender: 'Female',
          height: 165.0,
          weight: 60.0,
          activityLevel: 'Moderate',
        );

        // Assert
        expect(result.error, isNull);
        expect(result.data!.name, equals('Updated Name'));
        expect(result.data!.age, equals(25));
        expect(result.data!.gender, equals('Female'));
        expect(result.data!.height, equals(165.0));
        expect(result.data!.weight, equals(60.0));
        expect(result.data!.activityLevel, equals('Moderate'));
        expect(result.data!.updatedAt, isNotNull);
      });

      test('updateProfile handles non-existent user', () async {
        // Act
        final result = await profileService.updateProfile(
          uid: 'non-existent-uid',
          name: 'Test Name',
        );

        // Assert
        expect(result.error, isNotNull);
        expect(result.data, isNull);
      });
    });

    group('Medical Information Management', () {
      test('addMedicalCondition adds condition to profile', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act
        final result = await profileService.addMedicalCondition(uid, 'Diabetes');

        // Assert
        expect(result.error, isNull);
        
        // Verify condition was added
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.medicalConditions, contains('Diabetes'));
      });

      test('removeMedicalCondition removes condition from profile', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );
        await profileService.addMedicalCondition(uid, 'Diabetes');

        // Act
        final result = await profileService.removeMedicalCondition(uid, 'Diabetes');

        // Assert
        expect(result.error, isNull);
        
        // Verify condition was removed
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.medicalConditions, isNot(contains('Diabetes')));
      });

      test('addAllergy adds allergy to profile', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act
        final result = await profileService.addAllergy(uid, 'Nuts');

        // Assert
        expect(result.error, isNull);
        
        // Verify allergy was added
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.allergies, contains('Nuts'));
      });
    });

    group('Dietary Preferences', () {
      test('updateDietaryPreferences updates dietary needs and dislikes', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        const dietaryNeeds = ['Vegetarian', 'Low-carb'];
        const foodDislikes = ['Spicy food', 'Bitter gourd'];

        // Act
        final result = await profileService.updateDietaryPreferences(
          uid: uid,
          dietaryNeeds: dietaryNeeds,
          foodDislikes: foodDislikes,
        );

        // Assert
        expect(result.error, isNull);
        
        // Verify preferences were updated
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.dietaryNeeds, equals(dietaryNeeds));
        expect(profileResult.data!.foodDislikes, equals(foodDislikes));
      });

      test('updateHealthGoals updates health goals', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        const healthGoals = ['Weight loss', 'Better digestion', 'Improve energy'];

        // Act
        final result = await profileService.updateHealthGoals(uid, healthGoals);

        // Assert
        expect(result.error, isNull);
        
        // Verify goals were updated
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.healthGoals, equals(healthGoals));
      });
    });

    group('Cultural Preferences', () {
      test('updateCulturalPreferences updates cultural settings', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        const culturalPreferences = {
          'preferredRegion': 'South Indian',
          'spiceLevel': 'high',
          'cookingStyle': 'traditional',
        };

        // Act
        final result = await profileService.updateCulturalPreferences(
          uid: uid,
          culturalPreferences: culturalPreferences,
        );

        // Assert
        expect(result.error, isNull);
        
        // Verify preferences were updated
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.culturalPreferences, equals(culturalPreferences));
      });
    });

    group('Physical Measurements', () {
      test('updatePhysicalMeasurements updates body measurements', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act
        final result = await profileService.updatePhysicalMeasurements(
          uid: uid,
          age: 30,
          gender: 'Male',
          height: 175.0,
          weight: 70.0,
          activityLevel: 'Active',
        );

        // Assert
        expect(result.error, isNull);
        
        // Verify measurements were updated
        final profileResult = await profileService.getProfile(uid);
        expect(profileResult.data!.age, equals(30));
        expect(profileResult.data!.gender, equals('Male'));
        expect(profileResult.data!.height, equals(175.0));
        expect(profileResult.data!.weight, equals(70.0));
        expect(profileResult.data!.activityLevel, equals('Active'));
      });
    });

    group('Profile Validation', () {
      test('validateProfileCompleteness returns completeness status', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
        );

        // Act
        final result = await profileService.validateProfileCompleteness(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!['basicInfo'], isTrue); // Name and email provided
        expect(result.data!['physicalMeasurements'], isFalse); // Age and gender not provided
        expect(result.data!['healthGoals'], isFalse); // No health goals
        expect(result.data!['dietaryPreferences'], isFalse); // No dietary needs
      });

      test('getProfileCompletionPercentage calculates completion percentage', () async {
        // Arrange
        const uid = 'test-uid';
        await profileService.createProfile(
          uid: uid,
          name: 'Test User',
          email: 'test@example.com',
          healthGoals: ['Weight loss'],
        );

        // Act
        final result = await profileService.getProfileCompletionPercentage(uid);

        // Assert
        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!, greaterThan(0));
        expect(result.data!, lessThanOrEqualTo(100));
      });
    });

    group('UserModel Helper Methods', () {
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

      test('isPremium returns correct status', () {
        // Arrange
        final freeUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'free',
        );

        final premiumUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'premium',
          subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
        );

        final expiredPremiumUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          subscriptionTier: 'premium',
          subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        // Act & Assert
        expect(freeUser.isPremium, isFalse);
        expect(premiumUser.isPremium, isTrue);
        expect(expiredPremiumUser.isPremium, isFalse);
      });

      test('hasReachedQueryLimit returns correct status', () {
        // Arrange
        final userWithinLimit = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 25,
          monthlyQueriesLimit: 50,
        );

        final userAtLimit = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          dailyQueriesUsed: 50,
          monthlyQueriesLimit: 50,
        );

        // Act & Assert
        expect(userWithinLimit.hasReachedQueryLimit, isFalse);
        expect(userAtLimit.hasReachedQueryLimit, isTrue);
      });

      test('helper methods for medical conditions and allergies work', () {
        // Arrange
        final user = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
          medicalConditions: ['Diabetes', 'Hypertension'],
          allergies: ['Nuts', 'Dairy'],
          foodDislikes: ['Spicy food', 'Bitter gourd'],
        );

        // Act & Assert
        expect(user.hasMedicalCondition('diabetes'), isTrue); // Case insensitive
        expect(user.hasMedicalCondition('Diabetes'), isTrue);
        expect(user.hasMedicalCondition('Heart disease'), isFalse);

        expect(user.hasAllergy('nuts'), isTrue); // Case insensitive
        expect(user.hasAllergy('Nuts'), isTrue);
        expect(user.hasAllergy('Gluten'), isFalse);

        expect(user.dislikesFood('spicy food'), isTrue); // Case insensitive
        expect(user.dislikesFood('Sweet food'), isFalse);
      });

      test('isProfileComplete returns correct status', () {
        // Arrange
        final incompleteUser = UserModel(
          uid: 'test-uid',
          name: 'Test User',
          email: 'test@example.com',
        );

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
        expect(incompleteUser.isProfileComplete, isFalse);
        expect(completeUser.isProfileComplete, isTrue);
      });
    });
  });
}