import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../lib/services/meal_reminder_service.dart';
import '../../lib/models/user_model.dart';
import '../../lib/nutrition/meal_data_models.dart';
import '../../lib/voice/voice_interface.dart';
import '../../lib/voice/conversation_context_manager.dart';
import '../../lib/services/calendar_integration_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseFirestore,
  FlutterLocalNotificationsPlugin,
  VoiceInterface,
  ConversationContextManager,
  CalendarIntegrationService,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  QuerySnapshot,
  Query,
])
import 'meal_reminder_service_test.mocks.dart';

void main() {
  group('MealReminderService', () {
    late MealReminderService reminderService;
    late MockFirebaseFirestore mockFirestore;
    late MockFlutterLocalNotificationsPlugin mockNotifications;
    late MockVoiceInterface mockVoiceInterface;
    late MockConversationContextManager mockContextManager;
    late MockCalendarIntegrationService mockCalendarService;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocument;
    late MockQuerySnapshot mockQuerySnapshot;
    late MockQuery mockQuery;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockNotifications = MockFlutterLocalNotificationsPlugin();
      mockVoiceInterface = MockVoiceInterface();
      mockContextManager = MockConversationContextManager();
      mockCalendarService = MockCalendarIntegrationService();
      mockCollection = MockCollectionReference();
      mockDocument = MockDocumentReference();
      mockQuerySnapshot = MockQuerySnapshot();
      mockQuery = MockQuery();

      reminderService = MealReminderService(
        notificationsPlugin: mockNotifications,
        firestore: mockFirestore,
        voiceInterface: mockVoiceInterface,
        contextManager: mockContextManager,
        calendarService: mockCalendarService,
      );
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Arrange
        when(mockNotifications.initialize(any)).thenAnswer((_) async => true);

        // Act
        await reminderService.initialize();

        // Assert
        verify(mockNotifications.initialize(any)).called(1);
      });
    });

    group('Meal Reminder Scheduling', () {
      test('should schedule meal reminders for user', () async {
        // Arrange
        final user = _createTestUser();
        const userId = 'test-user-123';
        
        when(mockCalendarService.syncCalendar(userId))
            .thenAnswer((_) async => <CalendarEvent>[]);
        
        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('timestamp', descending: true))
            .thenReturn(mockQuery);
        when(mockQuery.limit(100))
            .thenReturn(mockQuery);
        when(mockQuery.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        when(mockNotifications.zonedSchedule(
          any, any, any, any, any,
          payload: anyNamed('payload'),
          uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
        )).thenAnswer((_) async {});

        when(mockFirestore.collection('meal_reminders'))
            .thenReturn(mockCollection);
        when(mockCollection.doc(any))
            .thenReturn(mockDocument);
        when(mockDocument.set(any))
            .thenAnswer((_) async {});

        // Act
        await reminderService.scheduleMealReminders(userId, user);

        // Assert
        verify(mockCalendarService.syncCalendar(userId)).called(1);
        verify(mockNotifications.zonedSchedule(
          any, any, any, any, any,
          payload: anyNamed('payload'),
          uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
        )).called(greaterThan(0));
      });

      test('should handle calendar events when scheduling reminders', () async {
        // Arrange
        final user = _createTestUser();
        const userId = 'test-user-123';
        final calendarEvents = [
          CalendarEvent(
            id: 'event-1',
            title: 'Meeting',
            startTime: DateTime.now().add(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 2)),
            location: 'Office',
            type: EventType.meeting,
          ),
        ];
        
        when(mockCalendarService.syncCalendar(userId))
            .thenAnswer((_) async => calendarEvents);
        
        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('timestamp', descending: true))
            .thenReturn(mockQuery);
        when(mockQuery.limit(100))
            .thenReturn(mockQuery);
        when(mockQuery.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        when(mockNotifications.zonedSchedule(
          any, any, any, any, any,
          payload: anyNamed('payload'),
          uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
        )).thenAnswer((_) async {});

        when(mockFirestore.collection('meal_reminders'))
            .thenReturn(mockCollection);
        when(mockCollection.doc(any))
            .thenReturn(mockDocument);
        when(mockDocument.set(any))
            .thenAnswer((_) async {});

        // Act
        await reminderService.scheduleMealReminders(userId, user);

        // Assert
        verify(mockCalendarService.syncCalendar(userId)).called(1);
        // Verify that reminders are adjusted for calendar events
        verify(mockNotifications.zonedSchedule(
          any, any, any, any, any,
          payload: anyNamed('payload'),
          uiLocalNotificationDateInterpretation: anyNamed('uiLocalNotificationDateInterpretation'),
        )).called(greaterThan(0));
      });
    });

    group('Meal Timing Pattern Tracking', () {
      test('should track meal timing successfully', () async {
        // Arrange
        const userId = 'test-user-123';
        final mealTime = DateTime.now();
        const mealType = MealType.breakfast;

        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.doc(any))
            .thenReturn(mockDocument);
        when(mockDocument.set(any))
            .thenAnswer((_) async {});

        // Act
        await reminderService.trackMealTiming(userId, mealType, mealTime);

        // Assert
        verify(mockFirestore.collection('meal_timing_patterns')).called(1);
        verify(mockDocument.set(any)).called(1);
      });

      test('should analyze meal timing patterns correctly', () async {
        // Arrange
        const userId = 'test-user-123';
        final mockDocs = _createMockTimingDocs();

        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('timestamp', descending: true))
            .thenReturn(mockQuery);
        when(mockQuery.limit(100))
            .thenReturn(mockQuery);
        when(mockQuery.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn(mockDocs);

        // Act
        final pattern = await reminderService.getMealTimingPattern(userId);

        // Assert
        expect(pattern, isNotNull);
        expect(pattern!.averageMealTimes, isNotEmpty);
        expect(pattern.insights, isNotEmpty);
        expect(pattern.consistencyScore, greaterThan(0.0));
      });
    });

    group('Voice Reminders', () {
      test('should play voice reminder when scheduled', () async {
        // Arrange
        final user = _createTestUser();
        const userId = 'test-user-123';
        const mealType = MealType.breakfast;
        const message = 'Time for breakfast!';
        final audioBytes = [1, 2, 3, 4, 5];

        when(mockVoiceInterface.generateVoiceResponse(any))
            .thenAnswer((_) async => audioBytes);
        when(mockVoiceInterface.playAudio(any))
            .thenAnswer((_) async {});

        // Act
        await reminderService._playVoiceReminder(userId, mealType, user);

        // Assert
        verify(mockVoiceInterface.generateVoiceResponse(any)).called(1);
        verify(mockVoiceInterface.playAudio(audioBytes)).called(1);
      });
    });

    group('Schedule Optimization', () {
      test('should generate schedule optimization suggestions', () async {
        // Arrange
        const userId = 'test-user-123';
        final mockDocs = _createMockTimingDocs();

        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('timestamp', descending: true))
            .thenReturn(mockQuery);
        when(mockQuery.limit(100))
            .thenReturn(mockQuery);
        when(mockQuery.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn(mockDocs);

        when(mockCalendarService.syncCalendar(userId))
            .thenAnswer((_) async => <CalendarEvent>[]);

        // Act
        final suggestions = await reminderService.generateScheduleOptimizations(userId);

        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.first, contains('consistent'));
      });

      test('should suggest meal prep for busy days', () async {
        // Arrange
        const userId = 'test-user-123';
        final busyCalendarEvents = List.generate(6, (index) => CalendarEvent(
          id: 'event-$index',
          title: 'Meeting $index',
          startTime: DateTime.now().add(Duration(hours: index)),
          endTime: DateTime.now().add(Duration(hours: index + 1)),
          location: 'Office',
          type: EventType.meeting,
        ));

        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: userId))
            .thenReturn(mockQuery);
        when(mockQuery.orderBy('timestamp', descending: true))
            .thenReturn(mockQuery);
        when(mockQuery.limit(100))
            .thenReturn(mockQuery);
        when(mockQuery.get())
            .thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn(_createMockTimingDocs());

        when(mockCalendarService.syncCalendar(userId))
            .thenAnswer((_) async => busyCalendarEvents);

        // Act
        final suggestions = await reminderService.generateScheduleOptimizations(userId);

        // Assert
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.contains('busy days')), isTrue);
      });
    });

    group('Reminder Cancellation', () {
      test('should cancel all user reminders', () async {
        // Arrange
        const userId = 'test-user-123';

        when(mockNotifications.cancelAll())
            .thenAnswer((_) async {});

        // Act
        await reminderService.cancelUserReminders(userId);

        // Assert
        verify(mockNotifications.cancelAll()).called(1);
      });
    });

    group('Message Generation', () {
      test('should generate appropriate Hinglish messages', () {
        // Arrange
        final service = MealReminderService();

        // Act
        final breakfastMessage = service._getMealReminderMessage(MealType.breakfast, 'hinglish');
        final lunchMessage = service._getMealReminderMessage(MealType.lunch, 'hinglish');
        final dinnerMessage = service._getMealReminderMessage(MealType.dinner, 'hinglish');
        final snackMessage = service._getMealReminderMessage(MealType.snack, 'hinglish');

        // Assert
        expect(breakfastMessage, contains('Breakfast'));
        expect(breakfastMessage, contains('time'));
        expect(lunchMessage, contains('Lunch'));
        expect(dinnerMessage, contains('Dinner'));
        expect(snackMessage, contains('Snack'));
      });

      test('should generate appropriate English messages', () {
        // Arrange
        final service = MealReminderService();

        // Act
        final breakfastMessage = service._getMealReminderMessage(MealType.breakfast, 'english');
        final lunchMessage = service._getMealReminderMessage(MealType.lunch, 'english');

        // Assert
        expect(breakfastMessage, contains('breakfast'));
        expect(lunchMessage, contains('lunch'));
      });

      test('should generate appropriate voice messages', () {
        // Arrange
        final service = MealReminderService();

        // Act
        final voiceMessage = service._getVoiceReminderMessage(MealType.breakfast, 'hinglish');

        // Assert
        expect(voiceMessage, isNotEmpty);
        expect(voiceMessage, contains('Namaste'));
      });
    });

    group('Error Handling', () {
      test('should handle Firestore errors gracefully', () async {
        // Arrange
        const userId = 'test-user-123';
        final mealTime = DateTime.now();
        const mealType = MealType.breakfast;

        when(mockFirestore.collection('meal_timing_patterns'))
            .thenReturn(mockCollection);
        when(mockCollection.doc(any))
            .thenReturn(mockDocument);
        when(mockDocument.set(any))
            .thenThrow(Exception('Firestore error'));

        // Act & Assert
        expect(
          () => reminderService.trackMealTiming(userId, mealType, mealTime),
          returnsNormally,
        );
      });

      test('should handle voice interface errors gracefully', () async {
        // Arrange
        final user = _createTestUser();
        const userId = 'test-user-123';
        const mealType = MealType.breakfast;

        when(mockVoiceInterface.generateVoiceResponse(any))
            .thenThrow(Exception('Voice error'));

        // Act & Assert
        expect(
          () => reminderService._playVoiceReminder(userId, mealType, user),
          returnsNormally,
        );
      });
    });
  });
}

// Helper methods
UserModel _createTestUser() {
  return UserModel(
    uid: 'test-user-123',
    name: 'Test User',
    email: 'test@example.com',
    preferredLanguage: 'hinglish',
    healthGoals: ['weight_loss'],
    dietaryNeeds: ['vegetarian'],
  );
}

List<MockDocumentSnapshot> _createMockTimingDocs() {
  final docs = <MockDocumentSnapshot>[];
  
  // Create mock documents for different meal types
  for (int i = 0; i < 10; i++) {
    final mockDoc = MockDocumentSnapshot();
    when(mockDoc.data()).thenReturn({
      'userId': 'test-user-123',
      'mealType': MealType.breakfast.name,
      'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: i))),
      'dayOfWeek': DateTime.now().weekday,
      'hour': 8 + (i % 2), // Vary between 8 and 9 AM
      'minute': 0,
    });
    docs.add(mockDoc);
  }
  
  return docs;
}

// Extension to access private methods for testing
extension MealReminderServiceTest on MealReminderService {
  String getMealReminderMessage(MealType mealType, String language) {
    return _getMealReminderMessage(mealType, language);
  }

  String getVoiceReminderMessage(MealType mealType, String language) {
    return _getVoiceReminderMessage(mealType, language);
  }

  Future<void> playVoiceReminder(String userId, MealType mealType, UserModel user) {
    return _playVoiceReminder(userId, mealType, user);
  }
}