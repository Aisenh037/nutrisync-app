import 'dart:async';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import '../nutrition/nutrition_intelligence_core.dart';
import '../nutrition/recommendation_engine.dart';
import '../nutrition/meal_data_models.dart';

/// Calendar Integration Service for meal timing and scheduling
/// Syncs with user calendar to provide schedule-aware meal planning
class CalendarIntegrationService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  
  /// Request calendar access permission
  Future<bool> requestCalendarPermission() async {
    try {
      final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
    } catch (e) {
      debugPrint('Error requesting calendar permission: $e');
      return false;
    }
  }

  /// Sync with user's calendar
  Future<List<CalendarEvent>> syncCalendar(String userId) async {
    try {
      // Check permissions first
      final hasPermission = await requestCalendarPermission();
      if (!hasPermission) {
        debugPrint('Calendar permission not granted');
        return [];
      }

      // Get calendars
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        debugPrint('Failed to retrieve calendars');
        return [];
      }

      final calendars = calendarsResult.data!;
      final List<CalendarEvent> allEvents = [];

      // Get events from the next 7 days for meal planning
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 7));

      for (final calendar in calendars) {
        if (calendar.id == null) continue;

        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(
            startDate: now,
            endDate: endDate,
          ),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            if (event.start != null && event.end != null) {
              allEvents.add(CalendarEvent(
                id: event.eventId ?? '',
                title: event.title ?? 'Untitled Event',
                startTime: event.start!,
                endTime: event.end!,
                location: event.location ?? '',
                type: _categorizeEvent(event.title ?? ''),
              ));
            }
          }
        }
      }

      return allEvents;
    } catch (e) {
      debugPrint('Error syncing calendar: $e');
      return [];
    }
  }

  /// Categorize event based on title keywords
  EventType _categorizeEvent(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('meeting') || 
        lowerTitle.contains('call') || 
        lowerTitle.contains('conference')) {
      return EventType.meeting;
    } else if (lowerTitle.contains('gym') || 
               lowerTitle.contains('workout') || 
               lowerTitle.contains('exercise')) {
      return EventType.workout;
    } else if (lowerTitle.contains('travel') || 
               lowerTitle.contains('flight') || 
               lowerTitle.contains('trip')) {
      return EventType.travel;
    } else if (lowerTitle.contains('work') || 
               lowerTitle.contains('office')) {
      return EventType.work;
    } else {
      return EventType.personal;
    }
  }

  /// Suggest meal timing based on schedule
  List<MealTimingSuggestion> suggestMealTiming(List<CalendarEvent> events, UserProfile profile) {
    final suggestions = <MealTimingSuggestion>[];
    final now = DateTime.now();
    
    // Define ideal meal times based on Indian eating patterns
    final idealBreakfastTime = DateTime(now.year, now.month, now.day, 8, 0);
    final idealLunchTime = DateTime(now.year, now.month, now.day, 13, 0);
    final idealDinnerTime = DateTime(now.year, now.month, now.day, 20, 0);
    
    // Analyze schedule for each meal
    suggestions.addAll(_suggestBreakfastTiming(events, idealBreakfastTime));
    suggestions.addAll(_suggestLunchTiming(events, idealLunchTime));
    suggestions.addAll(_suggestDinnerTiming(events, idealDinnerTime));
    
    return suggestions;
  }

  List<MealTimingSuggestion> _suggestBreakfastTiming(List<CalendarEvent> events, DateTime idealTime) {
    final suggestions = <MealTimingSuggestion>[];
    
    // Check for early morning events
    final morningEvents = events.where((event) => 
      event.startTime.hour >= 6 && event.startTime.hour <= 10
    ).toList();
    
    if (morningEvents.isEmpty) {
      suggestions.add(MealTimingSuggestion(
        mealType: MealType.breakfast,
        suggestedTime: idealTime,
        reason: 'Ideal breakfast time with no conflicts',
        durationMinutes: 30,
      ));
    } else {
      // Find gap before first morning event
      final firstEvent = morningEvents.first;
      if (firstEvent.startTime.isAfter(idealTime.add(const Duration(minutes: 30)))) {
        suggestions.add(MealTimingSuggestion(
          mealType: MealType.breakfast,
          suggestedTime: idealTime,
          reason: 'Breakfast before ${firstEvent.title}',
          durationMinutes: 30,
        ));
      } else {
        // Suggest earlier breakfast
        final earlierTime = firstEvent.startTime.subtract(const Duration(minutes: 45));
        suggestions.add(MealTimingSuggestion(
          mealType: MealType.breakfast,
          suggestedTime: earlierTime,
          reason: 'Early breakfast before busy morning',
          durationMinutes: 30,
        ));
      }
    }
    
    return suggestions;
  }

  List<MealTimingSuggestion> _suggestLunchTiming(List<CalendarEvent> events, DateTime idealTime) {
    final suggestions = <MealTimingSuggestion>[];
    
    // Check for lunch time conflicts (12 PM - 2 PM)
    final lunchTimeEvents = events.where((event) => 
      (event.startTime.hour >= 12 && event.startTime.hour <= 14) ||
      (event.endTime.hour >= 12 && event.endTime.hour <= 14)
    ).toList();
    
    if (lunchTimeEvents.isEmpty) {
      suggestions.add(MealTimingSuggestion(
        mealType: MealType.lunch,
        suggestedTime: idealTime,
        reason: 'Perfect lunch time with no meetings',
        durationMinutes: 45,
      ));
    } else {
      // Find best available slot
      final conflictingEvent = lunchTimeEvents.first;
      if (conflictingEvent.startTime.isAfter(idealTime.add(const Duration(minutes: 45)))) {
        suggestions.add(MealTimingSuggestion(
          mealType: MealType.lunch,
          suggestedTime: idealTime,
          reason: 'Lunch before ${conflictingEvent.title}',
          durationMinutes: 45,
        ));
      } else {
        // Suggest after the event
        final laterTime = conflictingEvent.endTime.add(const Duration(minutes: 15));
        suggestions.add(MealTimingSuggestion(
          mealType: MealType.lunch,
          suggestedTime: laterTime,
          reason: 'Lunch after ${conflictingEvent.title}',
          durationMinutes: 45,
        ));
      }
    }
    
    return suggestions;
  }

  List<MealTimingSuggestion> _suggestDinnerTiming(List<CalendarEvent> events, DateTime idealTime) {
    final suggestions = <MealTimingSuggestion>[];
    
    // Check for evening events (6 PM - 9 PM)
    final eveningEvents = events.where((event) => 
      event.startTime.hour >= 18 && event.startTime.hour <= 21
    ).toList();
    
    if (eveningEvents.isEmpty) {
      suggestions.add(MealTimingSuggestion(
        mealType: MealType.dinner,
        suggestedTime: idealTime,
        reason: 'Ideal dinner time for healthy digestion',
        durationMinutes: 60,
      ));
    } else {
      // Adjust based on evening schedule
      final firstEveningEvent = eveningEvents.first;
      if (firstEveningEvent.startTime.isAfter(idealTime.add(const Duration(hours: 1)))) {
        suggestions.add(MealTimingSuggestion(
          mealType: MealType.dinner,
          suggestedTime: idealTime,
          reason: 'Dinner before evening activities',
          durationMinutes: 60,
        ));
      } else {
        // Suggest earlier or later dinner
        final adjustedTime = firstEveningEvent.startTime.subtract(const Duration(hours: 1, minutes: 30));
        if (adjustedTime.hour >= 18) {
          suggestions.add(MealTimingSuggestion(
            mealType: MealType.dinner,
            suggestedTime: adjustedTime,
            reason: 'Early dinner before ${firstEveningEvent.title}',
            durationMinutes: 60,
          ));
        } else {
          // Late dinner after events
          final lastEvent = eveningEvents.last;
          final lateTime = lastEvent.endTime.add(const Duration(minutes: 30));
          suggestions.add(MealTimingSuggestion(
            mealType: MealType.dinner,
            suggestedTime: lateTime,
            reason: 'Late dinner after evening activities',
            durationMinutes: 60,
          ));
        }
      }
    }
    
    return suggestions;
  }

  /// Suggest quick meals for busy periods
  List<QuickMealSuggestion> suggestQuickMeals(List<CalendarEvent> busyPeriods, UserProfile profile) {
    final suggestions = <QuickMealSuggestion>[];
    
    // Define quick Indian meal options
    final quickMeals = [
      _createQuickMeal('Poha with vegetables', 15, 'Light and nutritious breakfast', 8.5),
      _createQuickMeal('Upma with coconut chutney', 20, 'South Indian quick breakfast', 8.0),
      _createQuickMeal('Vegetable sandwich', 10, 'Quick and filling option', 7.5),
      _createQuickMeal('Dal khichdi', 25, 'Complete protein meal', 9.0),
      _createQuickMeal('Curd rice with pickle', 5, 'Instant comfort food', 7.0),
      _createQuickMeal('Roti with ready curry', 15, 'Traditional quick meal', 8.0),
      _createQuickMeal('Oats upma', 12, 'Healthy fiber-rich option', 8.5),
      _createQuickMeal('Sprouts salad', 8, 'Protein-packed raw meal', 9.0),
    ];
    
    // Analyze busy periods and suggest appropriate meals
    for (final busyPeriod in busyPeriods) {
      final timeAvailable = _calculateAvailableTime(busyPeriod, busyPeriods);
      
      // Filter meals based on available time
      final suitableMeals = quickMeals.where((meal) => 
        meal.preparationTime <= timeAvailable.inMinutes
      ).toList();
      
      if (suitableMeals.isNotEmpty) {
        // Sort by nutrition score and pick the best
        suitableMeals.sort((a, b) => b.nutritionScore.compareTo(a.nutritionScore));
        final bestMeal = suitableMeals.first;
        
        suggestions.add(QuickMealSuggestion(
          meal: bestMeal.meal,
          preparationTime: bestMeal.preparationTime,
          reason: 'Quick meal for busy period: ${busyPeriod.title}',
          nutritionScore: bestMeal.nutritionScore,
        ));
      }
    }
    
    return suggestions;
  }

  QuickMealSuggestion _createQuickMeal(String name, int prepTime, String reason, double score) {
    return QuickMealSuggestion(
      meal: MealPlan(
        type: MealType.lunch, // Default to lunch for quick meals
        foods: [], // Simplified for quick implementation
        nutrition: NutritionalSummary(
          totalCalories: 300.0,
          totalProtein: 15.0,
          totalCarbs: 45.0,
          totalFat: 10.0,
          totalFiber: 5.0,
          vitamins: {},
          minerals: {},
          macroBreakdown: MacroBreakdown(
            proteinPercentage: 20.0,
            carbsPercentage: 60.0,
            fatPercentage: 20.0,
          ),
        ),
        description: '$name - $reason',
      ),
      preparationTime: prepTime,
      reason: reason,
      nutritionScore: score,
    );
  }

  Duration _calculateAvailableTime(CalendarEvent currentEvent, List<CalendarEvent> allEvents) {
    // Find the next event after current one
    final nextEvents = allEvents.where((event) => 
      event.startTime.isAfter(currentEvent.endTime)
    ).toList();
    
    if (nextEvents.isEmpty) {
      return const Duration(hours: 2); // Default 2 hours if no next event
    }
    
    nextEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    final nextEvent = nextEvents.first;
    
    return nextEvent.startTime.difference(currentEvent.endTime);
  }

  /// Schedule meal reminders
  Future<void> scheduleMealReminders(List<MealReminder> reminders) async {
    // This would integrate with flutter_local_notifications
    // For now, we'll store the reminders for future implementation
    debugPrint('Scheduling ${reminders.length} meal reminders');
    
    for (final reminder in reminders) {
      debugPrint('Reminder: ${reminder.mealType} at ${reminder.reminderTime}');
    }
  }

  /// Track meal timing patterns
  Future<MealTimingPattern> analyzeMealTimingPatterns(String userId) async {
    // This would analyze historical meal data from Firestore
    // For now, return a basic pattern analysis
    
    final now = DateTime.now();
    return MealTimingPattern(
      averageMealTimes: {
        MealType.breakfast: TimeRange(
          start: DateTime(now.year, now.month, now.day, 8, 0),
          end: DateTime(now.year, now.month, now.day, 9, 0),
          duration: const Duration(hours: 1),
        ),
        MealType.lunch: TimeRange(
          start: DateTime(now.year, now.month, now.day, 13, 0),
          end: DateTime(now.year, now.month, now.day, 14, 0),
          duration: const Duration(hours: 1),
        ),
        MealType.dinner: TimeRange(
          start: DateTime(now.year, now.month, now.day, 20, 0),
          end: DateTime(now.year, now.month, now.day, 21, 0),
          duration: const Duration(hours: 1),
        ),
      },
      insights: [
        'Your meal timing is generally consistent',
        'Consider having dinner earlier for better digestion',
        'Your lunch timing aligns well with your schedule',
      ],
      recommendations: [
        'Try to maintain consistent breakfast timing',
        'Schedule meals around your calendar events',
        'Allow 2-3 hours between dinner and sleep',
      ],
      consistencyScore: 0.75,
    );
  }
}

/// Represents a calendar event
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final EventType type;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
  });
}

enum EventType {
  meeting,
  workout,
  travel,
  personal,
  work,
}

/// Meal timing suggestion
class MealTimingSuggestion {
  final MealType mealType;
  final DateTime suggestedTime;
  final String reason;
  final int durationMinutes;

  MealTimingSuggestion({
    required this.mealType,
    required this.suggestedTime,
    required this.reason,
    required this.durationMinutes,
  });
}

/// Quick meal suggestion for busy periods
class QuickMealSuggestion {
  final MealPlan meal;
  final int preparationTime;
  final String reason;
  final double nutritionScore;

  QuickMealSuggestion({
    required this.meal,
    required this.preparationTime,
    required this.reason,
    required this.nutritionScore,
  });
}

/// Meal reminder
class MealReminder {
  final String id;
  final MealType mealType;
  final DateTime reminderTime;
  final String message;
  final ReminderType type;

  MealReminder({
    required this.id,
    required this.mealType,
    required this.reminderTime,
    required this.message,
    required this.type,
  });
}

enum ReminderType {
  voice,
  text,
  notification,
}

/// Meal timing pattern analysis
class MealTimingPattern {
  final Map<MealType, TimeRange> averageMealTimes;
  final List<String> insights;
  final List<String> recommendations;
  final double consistencyScore;

  MealTimingPattern({
    required this.averageMealTimes,
    required this.insights,
    required this.recommendations,
    required this.consistencyScore,
  });
}

/// Time range for meal timing
class TimeRange {
  final DateTime start;
  final DateTime end;
  final Duration duration;

  TimeRange({
    required this.start,
    required this.end,
    required this.duration,
  });
}