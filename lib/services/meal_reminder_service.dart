import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/user_model.dart';
import '../voice/voice_interface.dart';
import '../voice/conversation_context_manager.dart';
import '../nutrition/meal_data_models.dart';
import 'calendar_integration_service.dart';

/// Meal Reminder Service - Handles meal time reminders and timing pattern tracking
/// Provides voice and text reminders, analyzes eating patterns, and suggests optimizations
class MealReminderService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final FirebaseFirestore _firestore;
  final VoiceInterface? _voiceInterface;
  final ConversationContextManager? _contextManager;
  final CalendarIntegrationService _calendarService;
  
  // Reminder tracking
  final Map<String, Timer> _activeReminders = {};
  final Map<String, MealTimingData> _userTimingPatterns = {};

  MealReminderService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    FirebaseFirestore? firestore,
    VoiceInterface? voiceInterface,
    ConversationContextManager? contextManager,
    CalendarIntegrationService? calendarService,
  }) : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _voiceInterface = voiceInterface,
       _contextManager = contextManager,
       _calendarService = calendarService ?? CalendarIntegrationService();

  /// Initialize the reminder service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _loadUserTimingPatterns();
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload);
      _handleReminderAction(data);
    }
  }

  /// Handle reminder action when user taps notification
  void _handleReminderAction(Map<String, dynamic> data) {
    final mealType = MealType.values.firstWhere(
      (type) => type.name == data['mealType'],
      orElse: () => MealType.breakfast,
    );
    
    // Log that user received reminder
    _logReminderInteraction(data['userId'], mealType, 'tapped');
  }

  /// Schedule meal reminders for a user
  Future<void> scheduleMealReminders(String userId, UserModel user) async {
    try {
      // Cancel existing reminders
      await cancelUserReminders(userId);
      
      // Get user's meal timing preferences
      final timingPattern = await getMealTimingPattern(userId);
      final calendarEvents = await _calendarService.syncCalendar(userId);
      
      // Schedule reminders for each meal type
      for (final mealType in MealType.values) {
        await _scheduleMealTypeReminders(userId, user, mealType, timingPattern, calendarEvents);
      }
      
      print('✅ Scheduled meal reminders for user: $userId');
    } catch (e) {
      print('❌ Error scheduling meal reminders: $e');
      rethrow;
    }
  }

  /// Schedule reminders for a specific meal type
  Future<void> _scheduleMealTypeReminders(
    String userId,
    UserModel user,
    MealType mealType,
    MealTimingPattern? pattern,
    List<CalendarEvent> calendarEvents,
  ) async {
    // Get optimal timing for this meal type
    final optimalTime = _getOptimalMealTime(mealType, pattern, calendarEvents);
    
    if (optimalTime == null) return;
    
    // Schedule main reminder
    await _scheduleNotificationReminder(
      userId,
      mealType,
      optimalTime,
      _getMealReminderMessage(mealType, user.preferredLanguage ?? 'hinglish'),
    );
    
    // Schedule voice reminder if user prefers voice
    if (user.preferredLanguage == 'hinglish' && _voiceInterface != null) {
      await _scheduleVoiceReminder(userId, mealType, optimalTime, user);
    }
    
    // Schedule follow-up reminder if meal not logged
    final followUpTime = optimalTime.add(const Duration(minutes: 30));
    await _scheduleFollowUpReminder(userId, mealType, followUpTime);
  }

  /// Get optimal meal time based on patterns and calendar
  DateTime? _getOptimalMealTime(
    MealType mealType,
    MealTimingPattern? pattern,
    List<CalendarEvent> calendarEvents,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Default meal times
    final defaultTimes = {
      MealType.breakfast: today.add(const Duration(hours: 8)),
      MealType.lunch: today.add(const Duration(hours: 13)),
      MealType.dinner: today.add(const Duration(hours: 19)),
      MealType.snack: today.add(const Duration(hours: 16)),
    };
    
    var optimalTime = defaultTimes[mealType]!;
    
    // Adjust based on user's historical pattern
    if (pattern != null && pattern.averageMealTimes.containsKey(mealType)) {
      final avgTime = pattern.averageMealTimes[mealType]!;
      optimalTime = DateTime(
        today.year,
        today.month,
        today.day,
        avgTime.start.hour,
        avgTime.start.minute,
      );
    }
    
    // Adjust based on calendar events
    optimalTime = _adjustForCalendarEvents(optimalTime, calendarEvents);
    
    // Don't schedule reminders for past times
    if (optimalTime.isBefore(now)) {
      optimalTime = optimalTime.add(const Duration(days: 1));
    }
    
    return optimalTime;
  }

  /// Adjust meal time based on calendar events
  DateTime _adjustForCalendarEvents(DateTime mealTime, List<CalendarEvent> events) {
    for (final event in events) {
      // If meal time conflicts with an event, adjust it
      if (mealTime.isAfter(event.startTime.subtract(const Duration(minutes: 15))) &&
          mealTime.isBefore(event.endTime.add(const Duration(minutes: 15)))) {
        
        // Try to schedule before the event
        final beforeEvent = event.startTime.subtract(const Duration(minutes: 30));
        if (beforeEvent.isAfter(DateTime.now())) {
          return beforeEvent;
        }
        
        // Otherwise schedule after the event
        return event.endTime.add(const Duration(minutes: 15));
      }
    }
    
    return mealTime;
  }

  /// Schedule notification reminder
  Future<void> _scheduleNotificationReminder(
    String userId,
    MealType mealType,
    DateTime reminderTime,
    String message,
  ) async {
    final id = _generateReminderId(userId, mealType, 'notification');
    
    await _notificationsPlugin.zonedSchedule(
      id.hashCode,
      '🍽️ ${_getMealTypeEmoji(mealType)} ${mealType.name.toUpperCase()} Time!',
      message,
      _convertToTZDateTime(reminderTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders',
          'Meal Reminders',
          channelDescription: 'Reminders for meal times',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'userId': userId,
        'mealType': mealType.name,
        'type': 'meal_reminder',
      }),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    // Store reminder info
    await _storeReminderInfo(userId, mealType, reminderTime, ReminderType.notification);
  }

  /// Schedule voice reminder
  Future<void> _scheduleVoiceReminder(
    String userId,
    MealType mealType,
    DateTime reminderTime,
    UserModel user,
  ) async {
    final delay = reminderTime.difference(DateTime.now());
    
    if (delay.isNegative) return;
    
    final timer = Timer(delay, () async {
      await _playVoiceReminder(userId, mealType, user);
    });
    
    final reminderId = _generateReminderId(userId, mealType, 'voice');
    _activeReminders[reminderId] = timer;
    
    // Store reminder info
    await _storeReminderInfo(userId, mealType, reminderTime, ReminderType.voice);
  }

  /// Play voice reminder
  Future<void> _playVoiceReminder(String userId, MealType mealType, UserModel user) async {
    if (_voiceInterface == null) return;
    
    try {
      final message = _getVoiceReminderMessage(mealType, user.preferredLanguage ?? 'hinglish');
      final audioBytes = await _voiceInterface!.generateVoiceResponse(message);
      await _voiceInterface!.playAudio(audioBytes);
      
      // Log voice reminder played
      _logReminderInteraction(userId, mealType, 'voice_played');
    } catch (e) {
      print('❌ Error playing voice reminder: $e');
    }
  }

  /// Schedule follow-up reminder
  Future<void> _scheduleFollowUpReminder(
    String userId,
    MealType mealType,
    DateTime followUpTime,
  ) async {
    final delay = followUpTime.difference(DateTime.now());
    
    if (delay.isNegative) return;
    
    final timer = Timer(delay, () async {
      // Check if meal was logged
      final mealLogged = await _checkIfMealLogged(userId, mealType);
      
      if (!mealLogged) {
        await _sendFollowUpNotification(userId, mealType);
      }
    });
    
    final reminderId = _generateReminderId(userId, mealType, 'followup');
    _activeReminders[reminderId] = timer;
  }

  /// Send follow-up notification
  Future<void> _sendFollowUpNotification(String userId, MealType mealType) async {
    final id = _generateReminderId(userId, mealType, 'followup');
    
    await _notificationsPlugin.show(
      id.hashCode,
      '🤔 Did you have your ${mealType.name}?',
      'Tap to log your meal quickly!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_followup',
          'Meal Follow-up',
          channelDescription: 'Follow-up reminders for missed meals',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: jsonEncode({
        'userId': userId,
        'mealType': mealType.name,
        'type': 'meal_followup',
      }),
    );
  }

  /// Check if meal was logged
  Future<bool> _checkIfMealLogged(String userId, MealType mealType) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final query = await _firestore
        .collection('meal_logs')
        .where('userId', isEqualTo: userId)
        .where('mealType', isEqualTo: mealType.name)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty;
  }

  /// Track meal timing patterns
  Future<void> trackMealTiming(String userId, MealType mealType, DateTime mealTime) async {
    try {
      final timingData = MealTimingData(
        userId: userId,
        mealType: mealType,
        timestamp: mealTime,
        dayOfWeek: mealTime.weekday,
        hour: mealTime.hour,
        minute: mealTime.minute,
      );
      
      // Store in Firestore
      await _firestore
          .collection('meal_timing_patterns')
          .doc('${userId}_${mealType.name}_${mealTime.millisecondsSinceEpoch}')
          .set(timingData.toMap());
      
      // Update local cache
      _updateLocalTimingPattern(userId, timingData);
      
      print('✅ Tracked meal timing: ${mealType.name} at ${mealTime.hour}:${mealTime.minute}');
    } catch (e) {
      print('❌ Error tracking meal timing: $e');
    }
  }

  /// Update local timing pattern cache
  void _updateLocalTimingPattern(String userId, MealTimingData data) {
    if (!_userTimingPatterns.containsKey(userId)) {
      _userTimingPatterns[userId] = data;
    } else {
      // Update running average (simplified)
      final existing = _userTimingPatterns[userId]!;
      existing.hour = ((existing.hour + data.hour) / 2).round();
      existing.minute = ((existing.minute + data.minute) / 2).round();
    }
  }

  /// Get meal timing pattern for user
  Future<MealTimingPattern?> getMealTimingPattern(String userId) async {
    try {
      final query = await _firestore
          .collection('meal_timing_patterns')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      if (query.docs.isEmpty) return null;
      
      return _analyzeMealTimingPattern(query.docs);
    } catch (e) {
      print('❌ Error getting meal timing pattern: $e');
      return null;
    }
  }

  /// Analyze meal timing pattern from historical data
  MealTimingPattern _analyzeMealTimingPattern(List<QueryDocumentSnapshot> docs) {
    final mealTimes = <MealType, List<DateTime>>{};
    
    // Group meals by type
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final mealType = MealType.values.firstWhere(
        (type) => type.name == data['mealType'],
        orElse: () => MealType.breakfast,
      );
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      
      mealTimes.putIfAbsent(mealType, () => []).add(timestamp);
    }
    
    // Calculate average times and patterns
    final averageTimes = <MealType, TimeRange>{};
    final insights = <String>[];
    final recommendations = <String>[];
    
    for (final entry in mealTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;
      
      // Calculate average time
      final avgHour = times.map((t) => t.hour).reduce((a, b) => a + b) / times.length;
      final avgMinute = times.map((t) => t.minute).reduce((a, b) => a + b) / times.length;
      
      final avgTime = DateTime(2024, 1, 1, avgHour.round(), avgMinute.round());
      averageTimes[entry.key] = TimeRange(
        start: avgTime,
        end: avgTime.add(const Duration(minutes: 30)),
        duration: const Duration(minutes: 30),
      );
      
      // Generate insights
      _generateTimingInsights(entry.key, times, insights, recommendations);
    }
    
    // Calculate consistency score
    final consistencyScore = _calculateConsistencyScore(mealTimes);
    
    return MealTimingPattern(
      averageMealTimes: averageTimes,
      insights: insights,
      recommendations: recommendations,
      consistencyScore: consistencyScore,
    );
  }

  /// Generate timing insights and recommendations
  void _generateTimingInsights(
    MealType mealType,
    List<DateTime> times,
    List<String> insights,
    List<String> recommendations,
  ) {
    if (times.length < 3) return;
    
    // Calculate variance
    final avgHour = times.map((t) => t.hour).reduce((a, b) => a + b) / times.length;
    final variance = times.map((t) => (t.hour - avgHour) * (t.hour - avgHour)).reduce((a, b) => a + b) / times.length;
    
    if (variance > 2) {
      insights.add('Your ${mealType.name} timing varies significantly');
      recommendations.add('Try to have ${mealType.name} at a more consistent time');
    } else {
      insights.add('You have consistent ${mealType.name} timing');
    }
    
    // Check for optimal timing
    final optimalHours = {
      MealType.breakfast: 8,
      MealType.lunch: 13,
      MealType.dinner: 19,
      MealType.snack: 16,
    };
    
    final optimal = optimalHours[mealType] ?? 12;
    if ((avgHour - optimal).abs() > 2) {
      recommendations.add('Consider having ${mealType.name} closer to ${optimal}:00 for better metabolism');
    }
  }

  /// Calculate consistency score
  double _calculateConsistencyScore(Map<MealType, List<DateTime>> mealTimes) {
    if (mealTimes.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    int mealTypeCount = 0;
    
    for (final times in mealTimes.values) {
      if (times.length < 2) continue;
      
      final avgHour = times.map((t) => t.hour).reduce((a, b) => a + b) / times.length;
      final variance = times.map((t) => (t.hour - avgHour) * (t.hour - avgHour)).reduce((a, b) => a + b) / times.length;
      
      // Convert variance to consistency score (lower variance = higher consistency)
      final consistency = 1.0 / (1.0 + variance);
      totalScore += consistency;
      mealTypeCount++;
    }
    
    return mealTypeCount > 0 ? totalScore / mealTypeCount : 0.0;
  }

  /// Generate schedule optimization suggestions
  Future<List<String>> generateScheduleOptimizations(String userId) async {
    final pattern = await getMealTimingPattern(userId);
    final calendarEvents = await _calendarService.syncCalendar(userId);
    
    final suggestions = <String>[];
    
    if (pattern == null) {
      suggestions.add('Start logging meals consistently to get personalized timing suggestions');
      return suggestions;
    }
    
    // Analyze consistency
    if (pattern.consistencyScore < 0.7) {
      suggestions.add('Try to eat meals at more consistent times for better metabolism');
    }
    
    // Check meal gaps
    final mealTimes = pattern.averageMealTimes.values.map((range) => range.start).toList()
      ..sort();
    
    for (int i = 0; i < mealTimes.length - 1; i++) {
      final gap = mealTimes[i + 1].difference(mealTimes[i]).inHours;
      if (gap > 6) {
        suggestions.add('Consider adding a healthy snack between meals to maintain energy levels');
        break;
      }
    }
    
    // Calendar-based suggestions
    if (calendarEvents.isNotEmpty) {
      final busyDays = _identifyBusyDays(calendarEvents);
      if (busyDays.isNotEmpty) {
        suggestions.add('On busy days, prepare quick meals in advance or use meal prep strategies');
      }
    }
    
    return suggestions;
  }

  /// Identify busy days from calendar events
  List<DateTime> _identifyBusyDays(List<CalendarEvent> events) {
    final dayEventCount = <DateTime, int>{};
    
    for (final event in events) {
      final day = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      dayEventCount[day] = (dayEventCount[day] ?? 0) + 1;
    }
    
    return dayEventCount.entries
        .where((entry) => entry.value >= 5) // 5+ events = busy day
        .map((entry) => entry.key)
        .toList();
  }

  /// Cancel all reminders for a user
  Future<void> cancelUserReminders(String userId) async {
    // Cancel local timers
    final userReminders = _activeReminders.keys
        .where((key) => key.startsWith(userId))
        .toList();
    
    for (final reminderId in userReminders) {
      _activeReminders[reminderId]?.cancel();
      _activeReminders.remove(reminderId);
    }
    
    // Cancel scheduled notifications
    await _notificationsPlugin.cancelAll();
    
    print('✅ Cancelled all reminders for user: $userId');
  }

  /// Store reminder information
  Future<void> _storeReminderInfo(
    String userId,
    MealType mealType,
    DateTime reminderTime,
    ReminderType type,
  ) async {
    await _firestore
        .collection('meal_reminders')
        .doc('${userId}_${mealType.name}_${type.name}')
        .set({
      'userId': userId,
      'mealType': mealType.name,
      'reminderTime': Timestamp.fromDate(reminderTime),
      'type': type.name,
      'createdAt': Timestamp.now(),
    });
  }

  /// Log reminder interaction
  void _logReminderInteraction(String userId, MealType mealType, String action) {
    _firestore
        .collection('reminder_interactions')
        .add({
      'userId': userId,
      'mealType': mealType.name,
      'action': action,
      'timestamp': Timestamp.now(),
    });
  }

  /// Load user timing patterns from cache
  Future<void> _loadUserTimingPatterns() async {
    // Implementation for loading cached patterns
    // This would typically load from local storage or database
  }

  /// Helper methods
  String _generateReminderId(String userId, MealType mealType, String type) {
    return '${userId}_${mealType.name}_$type';
  }

  String _getMealTypeEmoji(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.snack:
        return '🍎';
    }
  }

  String _getMealReminderMessage(MealType mealType, String language) {
    if (language == 'hinglish') {
      switch (mealType) {
        case MealType.breakfast:
          return 'Good morning! Breakfast ka time ho gaya hai. Kuch healthy khayiye! 🌅';
        case MealType.lunch:
          return 'Lunch time! Kuch nutritious khana khayiye. 🍽️';
        case MealType.dinner:
          return 'Dinner ka time! Light aur healthy khana prefer kariye. 🌙';
        case MealType.snack:
          return 'Snack time! Kuch healthy munch kar sakte hain. 🍎';
      }
    } else {
      switch (mealType) {
        case MealType.breakfast:
          return 'Good morning! Time for a healthy breakfast! 🌅';
        case MealType.lunch:
          return 'Lunch time! Have something nutritious! 🍽️';
        case MealType.dinner:
          return 'Dinner time! Keep it light and healthy! 🌙';
        case MealType.snack:
          return 'Snack time! Choose something healthy! 🍎';
      }
    }
  }

  String _getVoiceReminderMessage(MealType mealType, String language) {
    if (language == 'hinglish') {
      switch (mealType) {
        case MealType.breakfast:
          return 'Namaste! Breakfast ka time ho gaya hai. Aaj kya khane ka plan hai?';
        case MealType.lunch:
          return 'Lunch time! Kuch tasty aur healthy banayiye. Main help kar sakta hun!';
        case MealType.dinner:
          return 'Dinner ka time! Light khana better hota hai evening mein.';
        case MealType.snack:
          return 'Snack time! Kuch healthy munch karte hain?';
      }
    } else {
      switch (mealType) {
        case MealType.breakfast:
          return 'Good morning! Time for breakfast. What are you planning to eat today?';
        case MealType.lunch:
          return 'Lunch time! Make something tasty and healthy. I can help you choose!';
        case MealType.dinner:
          return 'Dinner time! Light meals are better in the evening.';
        case MealType.snack:
          return 'Snack time! Let\'s choose something healthy to munch on!';
      }
    }
  }

  /// Convert DateTime to TZDateTime (simplified)
  dynamic _convertToTZDateTime(DateTime dateTime) {
    // This would typically use timezone package
    // For now, returning the DateTime as-is
    return dateTime;
  }

  /// Dispose resources
  void dispose() {
    for (final timer in _activeReminders.values) {
      timer.cancel();
    }
    _activeReminders.clear();
  }
}

/// Meal timing data for pattern analysis
class MealTimingData {
  final String userId;
  final MealType mealType;
  final DateTime timestamp;
  final int dayOfWeek;
  int hour;
  int minute;

  MealTimingData({
    required this.userId,
    required this.mealType,
    required this.timestamp,
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mealType': mealType.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'dayOfWeek': dayOfWeek,
      'hour': hour,
      'minute': minute,
    };
  }

  factory MealTimingData.fromMap(Map<String, dynamic> map) {
    return MealTimingData(
      userId: map['userId'],
      mealType: MealType.values.firstWhere((type) => type.name == map['mealType']),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      dayOfWeek: map['dayOfWeek'],
      hour: map['hour'],
      minute: map['minute'],
    );
  }
}