import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/voice/conversation_context_manager.dart';

void main() {
  // Initialize Flutter bindings for plugin tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ConversationContextManager Tests', () {
    late ConversationContextManager contextManager;

    setUp(() {
      contextManager = ConversationContextManager();
    });

    tearDown(() {
      contextManager.dispose();
    });

    group('Session Management', () {
      test('should start a new conversation session', () {
        final sessionId = contextManager.startSession(
          userId: 'test_user_123',
          initialContext: {
            'userPreferences': {'vegetarian': true},
            'nutritionGoals': {'calories': 2000},
          },
        );

        expect(sessionId, isNotNull);
        expect(sessionId.length, greaterThan(0));
        expect(contextManager.activeSessionCount, equals(1));

        final context = contextManager.getContext(sessionId);
        expect(context, isNotNull);
        expect(context!.userPreferences['vegetarian'], isTrue);
        expect(context.conversationState, equals(ConversationState.active));
      });

      test('should get active session for user', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        final foundSessionId = contextManager.getActiveSessionForUser('test_user_123');
        expect(foundSessionId, equals(sessionId));
        
        final notFoundSessionId = contextManager.getActiveSessionForUser('nonexistent_user');
        expect(notFoundSessionId, isNull);
      });

      test('should end conversation session', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        expect(contextManager.activeSessionCount, equals(1));

        contextManager.endSession(sessionId);
        
        final context = contextManager.getContext(sessionId);
        expect(context?.conversationState, equals(ConversationState.ended));
      });
    });

    group('Conversation Turns', () {
      test('should add conversation turn to session', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        final turn = ConversationTurn(
          turnId: 'turn_1',
          timestamp: DateTime.now(),
          userInput: 'Maine aaj dal chawal khaya',
          systemResponse: 'Achha! Dal chawal nutritious hai.',
          type: ConversationTurnType.mealLogging,
        );

        contextManager.addConversationTurn(sessionId, turn);
        
        final history = contextManager.getConversationHistory(sessionId);
        expect(history.length, equals(1));
        expect(history.first.userInput, equals('Maine aaj dal chawal khaya'));
        expect(history.first.type, equals(ConversationTurnType.mealLogging));
      });

      test('should get recent conversation turns', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        // Add multiple turns
        for (int i = 0; i < 10; i++) {
          final turn = ConversationTurn(
            turnId: 'turn_$i',
            timestamp: DateTime.now(),
            userInput: 'User input $i',
            systemResponse: 'System response $i',
            type: ConversationTurnType.nutritionQuery,
          );
          contextManager.addConversationTurn(sessionId, turn);
        }

        final recentTurns = contextManager.getRecentTurns(sessionId, count: 3);
        expect(recentTurns.length, equals(3));
        expect(recentTurns.last.userInput, equals('User input 9'));
        expect(recentTurns.first.userInput, equals('User input 7'));
      });

      test('should throw error when adding turn to nonexistent session', () {
        final turn = ConversationTurn(
          turnId: 'turn_1',
          timestamp: DateTime.now(),
          userInput: 'Test input',
          systemResponse: 'Test response',
          type: ConversationTurnType.nutritionQuery,
        );

        expect(
          () => contextManager.addConversationTurn('nonexistent_session', turn),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Interruption Handling', () {
      test('should handle conversation interruption', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        contextManager.handleInterruption(sessionId, reason: 'phone_call');
        
        final context = contextManager.getContext(sessionId);
        expect(context?.conversationState, equals(ConversationState.interrupted));
        expect(context?.interruptionReason, equals('phone_call'));
        expect(context?.interruptionTime, isNotNull);
      });

      test('should resume interrupted conversation', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        // Interrupt conversation
        contextManager.handleInterruption(sessionId, reason: 'phone_call');
        expect(contextManager.getContext(sessionId)?.conversationState, 
               equals(ConversationState.interrupted));

        // Resume conversation
        final resumptionMessage = contextManager.resumeConversation(sessionId);
        
        expect(resumptionMessage, isNotEmpty);
        expect(contextManager.getContext(sessionId)?.conversationState, 
               equals(ConversationState.active));
      });

      test('should throw error when resuming non-interrupted session', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        expect(
          () => contextManager.resumeConversation(sessionId),
          throwsA(isA<Exception>()),
        );
      });

      test('should generate appropriate resumption messages', () async {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        // Test short interruption
        contextManager.handleInterruption(sessionId);
        await Future.delayed(const Duration(milliseconds: 100));
        final shortMessage = contextManager.resumeConversation(sessionId);
        expect(shortMessage.toLowerCase(), contains('kya keh rahe the'));

        // Test with meal context
        contextManager.handleInterruption(sessionId);
        contextManager.addMealToContext(sessionId, {
          'type': 'lunch',
          'foods': ['dal', 'rice'],
        });
        await Future.delayed(const Duration(milliseconds: 100));
        final mealMessage = contextManager.resumeConversation(sessionId);
        expect(mealMessage.toLowerCase(), contains('meal'));
      });
    });

    group('Context Management', () {
      test('should update user preferences', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        contextManager.updateUserPreferences(sessionId, {
          'vegetarian': true,
          'spice_level': 'medium',
        });

        final context = contextManager.getContext(sessionId);
        expect(context?.userPreferences['vegetarian'], isTrue);
        expect(context?.userPreferences['spice_level'], equals('medium'));
      });

      test('should add meal to context', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        final mealData = {
          'type': 'breakfast',
          'foods': ['paratha', 'curd'],
          'timestamp': DateTime.now().toIso8601String(),
        };

        contextManager.addMealToContext(sessionId, mealData);

        final context = contextManager.getContext(sessionId);
        expect(context?.currentMealContext, equals(mealData));
        expect(context?.recentMeals.length, equals(1));
        expect(context?.recentMeals.first, equals(mealData));
      });

      test('should limit recent meals to maximum count', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        // Add more than the limit (10) meals
        for (int i = 0; i < 15; i++) {
          contextManager.addMealToContext(sessionId, {
            'type': 'meal_$i',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }

        final context = contextManager.getContext(sessionId);
        expect(context?.recentMeals.length, equals(10));
        expect(context?.recentMeals.first['type'], equals('meal_14')); // Most recent
        expect(context?.recentMeals.last['type'], equals('meal_5')); // Oldest kept
      });
    });

    group('Contextual Response Generation', () {
      test('should generate basic contextual response', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        final response = contextManager.generateContextualResponse(
          sessionId,
          'What should I eat?',
          'You should eat healthy foods.',
        );

        expect(response, equals('You should eat healthy foods.'));
      });

      test('should enhance response with user preferences', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        contextManager.updateUserPreferences(sessionId, {'vegetarian': true});
        
        final response = contextManager.generateContextualResponse(
          sessionId,
          'What should I eat?',
          'You should eat healthy foods.',
        );

        expect(response.toLowerCase(), contains('vegetarian'));
      });

      test('should enhance response with meal context', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        contextManager.addMealToContext(sessionId, {
          'type': 'breakfast',
          'foods': ['paratha'],
        });
        
        final response = contextManager.generateContextualResponse(
          sessionId,
          'How was my breakfast?',
          'Your meal was good.',
        );

        expect(response.toLowerCase(), contains('breakfast'));
      });

      test('should handle follow-up questions', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        
        // Add a turn about protein
        final proteinTurn = ConversationTurn(
          turnId: 'turn_1',
          timestamp: DateTime.now(),
          userInput: 'Tell me about protein',
          systemResponse: 'Protein is important for muscle building.',
          type: ConversationTurnType.nutritionQuery,
        );
        contextManager.addConversationTurn(sessionId, proteinTurn);
        
        final response = contextManager.generateContextualResponse(
          sessionId,
          'What foods have protein?', // This should be detected as follow-up
          'Many foods contain protein.',
        );

        // The response should be enhanced because it's a follow-up about protein
        expect(response, isNot(equals('Many foods contain protein.')));
        expect(response.toLowerCase(), anyOf([
          contains('dal'),
          contains('paneer'),
          contains('chicken'),
        ]));
      });
    });

    group('Event Handling', () {
      test('should emit events for session lifecycle', () async {
        final events = <ConversationEvent>[];
        contextManager.eventStream.listen((event) => events.add(event));

        final sessionId = contextManager.startSession(userId: 'test_user_123');
        await Future.delayed(const Duration(milliseconds: 10));

        contextManager.endSession(sessionId);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, greaterThanOrEqualTo(2));
        expect(events.first.type, equals(ConversationEventType.sessionStarted));
        expect(events.last.type, equals(ConversationEventType.sessionEnded));
      });

      test('should emit events for conversation turns', () async {
        final events = <ConversationEvent>[];
        contextManager.eventStream.listen((event) => events.add(event));

        final sessionId = contextManager.startSession(userId: 'test_user_123');
        await Future.delayed(const Duration(milliseconds: 10));

        final turn = ConversationTurn(
          turnId: 'turn_1',
          timestamp: DateTime.now(),
          userInput: 'Test input',
          systemResponse: 'Test response',
          type: ConversationTurnType.nutritionQuery,
        );
        contextManager.addConversationTurn(sessionId, turn);
        await Future.delayed(const Duration(milliseconds: 10));

        final turnEvents = events.where((e) => e.type == ConversationEventType.turnAdded);
        expect(turnEvents.length, equals(1));
        expect(turnEvents.first.sessionId, equals(sessionId));
      });

      test('should emit events for interruptions and resumptions', () async {
        final events = <ConversationEvent>[];
        contextManager.eventStream.listen((event) => events.add(event));

        final sessionId = contextManager.startSession(userId: 'test_user_123');
        await Future.delayed(const Duration(milliseconds: 10));

        contextManager.handleInterruption(sessionId, reason: 'test');
        await Future.delayed(const Duration(milliseconds: 10));

        contextManager.resumeConversation(sessionId);
        await Future.delayed(const Duration(milliseconds: 10));

        final interruptEvents = events.where((e) => e.type == ConversationEventType.interrupted);
        final resumeEvents = events.where((e) => e.type == ConversationEventType.resumed);
        
        expect(interruptEvents.length, equals(1));
        expect(resumeEvents.length, equals(1));
      });
    });

    group('Session Cleanup', () {
      test('should clean up expired sessions', () {
        // This test would require mocking time or using a test-specific timeout
        // For now, we'll test the method exists and doesn't throw
        expect(() => contextManager.cleanupExpiredSessions(), returnsNormally);
      });

      test('should handle nonexistent session gracefully', () {
        expect(() => contextManager.handleInterruption('nonexistent'), returnsNormally);
        expect(contextManager.getContext('nonexistent'), isNull);
        expect(() => contextManager.endSession('nonexistent'), returnsNormally);
      });
    });

    group('Data Serialization', () {
      test('should serialize conversation session to JSON', () {
        final sessionId = contextManager.startSession(userId: 'test_user_123');
        final context = contextManager.getContext(sessionId);
        
        expect(() => context?.toJson(), returnsNormally);
        
        final json = context?.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json?['userPreferences'], isA<Map<String, dynamic>>());
        expect(json?['conversationState'], isA<String>());
      });

      test('should serialize conversation turn to JSON', () {
        final turn = ConversationTurn(
          turnId: 'turn_1',
          timestamp: DateTime.now(),
          userInput: 'Test input',
          systemResponse: 'Test response',
          type: ConversationTurnType.nutritionQuery,
          metadata: {'confidence': 0.8},
        );

        expect(() => turn.toJson(), returnsNormally);
        
        final json = turn.toJson();
        expect(json['turnId'], equals('turn_1'));
        expect(json['userInput'], equals('Test input'));
        expect(json['metadata']['confidence'], equals(0.8));
      });

      test('should serialize conversation event to JSON', () {
        final event = ConversationEvent(
          type: ConversationEventType.sessionStarted,
          sessionId: 'session_123',
          timestamp: DateTime.now(),
          data: {'userId': 'test_user'},
        );

        expect(() => event.toJson(), returnsNormally);
        
        final json = event.toJson();
        expect(json['sessionId'], equals('session_123'));
        expect(json['data']['userId'], equals('test_user'));
      });
    });
  });
}