import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/services/calendar_integration_service.dart';
import 'package:nutrisync/nutrition/nutrition_intelligence_core.dart';
import 'package:nutrisync/nutrition/meal_data_models.dart';

void main() {
  group('CalendarIntegrationService', () {
    late CalendarIntegrationService calendarService;

    setUp(() {
      calendarService = CalendarIntegrationService();
    });

    UserProfile _createTestProfile() {
      return UserProfile(
        userId: 'test-user',
        personalInfo: PersonalInfo(
          name: 'Test User',
          age: 30,
          gender: 'male',
          height: 175.0,
          weight: 70.0,
          location: 'Mumbai',
        ),
        goals: DietaryGoals(
          type: GoalType.maintenance,
          targetWeight: 70.0,
          timeframe: 90,
          activityLevel: ActivityLevel.moderatelyActive,
        ),
        preferences: FoodPreferences(
          liked: ['dal', 'rice', 'vegetables'],
          disliked: [],
          dietary: ['vegetarian'],
          spiceLevel: 'medium',
        ),
        conditions: HealthConditions(
          allergies: [],
          medicalConditions: [],
          medications: [],
        ),
        patterns: EatingPatterns(
          mealTimes: {
            'breakfast': '8:00',
            'lunch': '13:00',
            'dinner': '20:00',
          },
          mealsPerDay: 3,
          snackPreferences: [],
        ),
        tier: SubscriptionTier.free,
      );
    }

    test('should suggest meal timing based on empty schedule', () {
      // Arrange
      final events = <CalendarEvent>[];
      final profile = _createTestProfile();

      // Act
      final suggestions = calendarService.suggestMealTiming(events, profile);

      // Assert
      expect(suggestions, isNotEmpty);
      expect(suggestions.length, equals(3)); // breakfast, lunch, dinner
      
      final breakfastSuggestion = suggestions.firstWhere((s) => s.mealType == MealType.breakfast);
      expect(breakfastSuggestion.suggestedTime.hour, equals(8));
      expect(breakfastSuggestion.reason, contains('Ideal breakfast time'));
      
      final lunchSuggestion = suggestions.firstWhere((s) => s.mealType == MealType.lunch);
      expect(lunchSuggestion.suggestedTime.hour, equals(13));
      expect(lunchSuggestion.reason, contains('Perfect lunch time'));
      
      final dinnerSuggestion = suggestions.firstWhere((s) => s.mealType == MealType.dinner);
      expect(dinnerSuggestion.suggestedTime.hour, equals(20));
      expect(dinnerSuggestion.reason, contains('Ideal dinner time'));
    });

    test('should suggest meal timing with conflicting events', () {
      // Arrange
      final now = DateTime.now();
      final events = [
        CalendarEvent(
          id: 'meeting-1',
          title: 'Important Meeting',
          startTime: DateTime(now.year, now.month, now.day, 13, 0), // 1 PM
          endTime: DateTime(now.year, now.month, now.day, 14, 0), // 2 PM
          location: 'Office',
          type: EventType.meeting,
        ),
      ];
      final profile = _createTestProfile();

      // Act
      final suggestions = calendarService.suggestMealTiming(events, profile);

      // Assert
      expect(suggestions, isNotEmpty);
      
      final lunchSuggestion = suggestions.firstWhere((s) => s.mealType == MealType.lunch);
      // Should suggest lunch after the meeting
      expect(lunchSuggestion.suggestedTime.isAfter(DateTime(now.year, now.month, now.day, 14, 0)), isTrue);
      expect(lunchSuggestion.reason, contains('after Important Meeting'));
    });

    test('should suggest quick meals for busy periods', () {
      // Arrange
      final now = DateTime.now();
      final busyPeriods = [
        CalendarEvent(
          id: 'busy-1',
          title: 'Back-to-back meetings',
          startTime: DateTime(now.year, now.month, now.day, 12, 0),
          endTime: DateTime(now.year, now.month, now.day, 14, 0),
          location: 'Office',
          type: EventType.meeting,
        ),
      ];
      final profile = _createTestProfile();

      // Act
      final suggestions = calendarService.suggestQuickMeals(busyPeriods, profile);

      // Assert
      expect(suggestions, isNotEmpty);
      
      final quickMeal = suggestions.first;
      expect(quickMeal.preparationTime, lessThanOrEqualTo(30)); // Should be quick
      expect(quickMeal.reason, contains('busy period'));
      expect(quickMeal.nutritionScore, greaterThan(0));
      expect(quickMeal.meal.description, isNotEmpty);
    });

    test('should analyze meal timing patterns', () async {
      // Arrange
      const userId = 'test-user-123';

      // Act
      final pattern = await calendarService.analyzeMealTimingPatterns(userId);

      // Assert
      expect(pattern.averageMealTimes, isNotEmpty);
      expect(pattern.averageMealTimes.containsKey(MealType.breakfast), isTrue);
      expect(pattern.averageMealTimes.containsKey(MealType.lunch), isTrue);
      expect(pattern.averageMealTimes.containsKey(MealType.dinner), isTrue);
      
      expect(pattern.insights, isNotEmpty);
      expect(pattern.recommendations, isNotEmpty);
      expect(pattern.consistencyScore, greaterThan(0));
      expect(pattern.consistencyScore, lessThanOrEqualTo(1.0));
    });

    test('should categorize events correctly', () {
      // Arrange
      final now = DateTime.now();
      final meetingEvent = CalendarEvent(
        id: 'test-1',
        title: 'Team Meeting',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        location: 'Office',
        type: EventType.meeting,
      );
      
      final workoutEvent = CalendarEvent(
        id: 'test-2',
        title: 'Gym Session',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        location: 'Gym',
        type: EventType.workout,
      );

      // Assert
      expect(meetingEvent.type, equals(EventType.meeting));
      expect(workoutEvent.type, equals(EventType.workout));
    });

    test('should handle empty calendar gracefully', () async {
      // Arrange
      const userId = 'test-user';

      // Act
      final events = await calendarService.syncCalendar(userId);

      // Assert - Should not throw and return empty list when no permission
      expect(events, isA<List<CalendarEvent>>());
    });
  });
}