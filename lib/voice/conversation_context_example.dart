import 'dart:async';
import 'conversation_context_manager.dart';

/// Example demonstrating conversation context management functionality
/// Shows how to use the ConversationContextManager for voice interactions
class ConversationContextExample {
  final ConversationContextManager _contextManager = ConversationContextManager();
  late StreamSubscription _eventSubscription;

  /// Run the conversation context example
  Future<void> runExample() async {
    print('=== Conversation Context Management Example ===\n');

    // Listen to conversation events
    _eventSubscription = _contextManager.eventStream.listen((event) {
      print('📢 Event: ${event.type} at ${event.timestamp}');
      if (event.data.isNotEmpty) {
        print('   Data: ${event.data}');
      }
    });

    await _demonstrateBasicConversation();
    await _demonstrateInterruptionHandling();
    await _demonstrateContextualResponses();
    await _demonstrateMealContext();
    await _demonstrateUserPreferences();
    await _demonstrateMultipleSessions();

    print('\n=== Example completed successfully! ===');
    
    // Clean up
    await _eventSubscription.cancel();
    _contextManager.dispose();
  }

  /// Demonstrate basic conversation flow
  Future<void> _demonstrateBasicConversation() async {
    print('1. 🗣️ Basic Conversation Flow');
    print('   Starting a new conversation session...');

    final sessionId = _contextManager.startSession(
      userId: 'demo_user_123',
      initialContext: {
        'userPreferences': {'language': 'hinglish'},
        'nutritionGoals': {'calories': 2000, 'protein': 50},
      },
    );

    print('   Session ID: $sessionId');
    print('   Active sessions: ${_contextManager.activeSessionCount}');

    // Add some conversation turns
    final turns = [
      ConversationTurn(
        turnId: 'turn_1',
        timestamp: DateTime.now(),
        userInput: 'Namaste! Main apna diet track karna chahta hun',
        systemResponse: 'Namaste! Main aapki madad karunga. Aaj kya khaya aapne?',
        type: ConversationTurnType.greeting,
      ),
      ConversationTurn(
        turnId: 'turn_2',
        timestamp: DateTime.now(),
        userInput: 'Maine breakfast mein paratha aur dahi khaya',
        systemResponse: 'Achha! Paratha aur dahi healthy breakfast hai. Kitne paratha khaye?',
        type: ConversationTurnType.mealLogging,
      ),
    ];

    for (final turn in turns) {
      _contextManager.addConversationTurn(sessionId, turn);
      print('   Added turn: ${turn.userInput}');
    }

    final history = _contextManager.getConversationHistory(sessionId);
    print('   Total conversation turns: ${history.length}');

    await Future.delayed(const Duration(milliseconds: 500));
    print('   ✅ Basic conversation completed\n');
  }

  /// Demonstrate interruption and resumption
  Future<void> _demonstrateInterruptionHandling() async {
    print('2. ⏸️ Interruption Handling');

    final sessionId = _contextManager.startSession(userId: 'demo_user_456');
    
    // Add some context before interruption
    _contextManager.addMealToContext(sessionId, {
      'type': 'lunch',
      'foods': ['dal', 'rice', 'sabzi'],
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('   Simulating conversation interruption...');
    _contextManager.handleInterruption(sessionId, reason: 'phone_call');

    final context = _contextManager.getContext(sessionId);
    print('   Conversation state: ${context?.conversationState}');
    print('   Interruption reason: ${context?.interruptionReason}');

    await Future.delayed(const Duration(milliseconds: 200));

    print('   Resuming conversation...');
    final resumptionMessage = _contextManager.resumeConversation(sessionId);
    print('   Resumption message: "$resumptionMessage"');

    final resumedContext = _contextManager.getContext(sessionId);
    print('   Resumed state: ${resumedContext?.conversationState}');
    print('   ✅ Interruption handling completed\n');
  }

  /// Demonstrate contextual response generation
  Future<void> _demonstrateContextualResponses() async {
    print('3. 🧠 Contextual Response Generation');

    final sessionId = _contextManager.startSession(userId: 'demo_user_789');

    // Add a conversation about protein
    final proteinTurn = ConversationTurn(
      turnId: 'protein_turn',
      timestamp: DateTime.now(),
      userInput: 'Protein ke baare mein batao',
      systemResponse: 'Protein muscle building ke liye important hai.',
      type: ConversationTurnType.nutritionQuery,
    );
    _contextManager.addConversationTurn(sessionId, proteinTurn);

    // Test follow-up question
    print('   Testing follow-up question enhancement...');
    final followUpResponse = _contextManager.generateContextualResponse(
      sessionId,
      'What foods have protein?',
      'Many foods contain protein.',
    );
    print('   Follow-up response: "$followUpResponse"');

    // Test basic response (no context)
    final basicResponse = _contextManager.generateContextualResponse(
      sessionId,
      'What is nutrition?',
      'Nutrition is about healthy eating.',
    );
    print('   Basic response: "$basicResponse"');
    print('   ✅ Contextual responses completed\n');
  }

  /// Demonstrate meal context management
  Future<void> _demonstrateMealContext() async {
    print('4. 🍽️ Meal Context Management');

    final sessionId = _contextManager.startSession(userId: 'demo_user_meal');

    // Add multiple meals
    final meals = [
      {
        'type': 'breakfast',
        'foods': ['paratha', 'curd', 'pickle'],
        'calories': 450,
        'timestamp': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      },
      {
        'type': 'lunch',
        'foods': ['dal', 'rice', 'sabzi'],
        'calories': 600,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      },
    ];

    for (final meal in meals) {
      _contextManager.addMealToContext(sessionId, meal);
      print('   Added ${meal['type']}: ${meal['foods']}');
    }

    final context = _contextManager.getContext(sessionId);
    print('   Current meal context: ${context?.currentMealContext?['type']}');
    print('   Recent meals count: ${context?.recentMeals.length}');

    // Test meal-related response
    final mealResponse = _contextManager.generateContextualResponse(
      sessionId,
      'How was my lunch?',
      'Your meal was good.',
    );
    print('   Meal response: "$mealResponse"');
    print('   ✅ Meal context completed\n');
  }

  /// Demonstrate user preferences
  Future<void> _demonstrateUserPreferences() async {
    print('5. 👤 User Preferences Management');

    final sessionId = _contextManager.startSession(userId: 'demo_user_prefs');

    // Update preferences
    _contextManager.updateUserPreferences(sessionId, {
      'vegetarian': true,
      'spice_level': 'medium',
      'allergies': ['nuts'],
      'preferred_cuisine': 'north_indian',
    });

    final context = _contextManager.getContext(sessionId);
    print('   User preferences: ${context?.userPreferences}');

    // Test preference-enhanced response
    final prefResponse = _contextManager.generateContextualResponse(
      sessionId,
      'What should I eat for dinner?',
      'You should eat healthy foods.',
    );
    print('   Preference-enhanced response: "$prefResponse"');
    print('   ✅ User preferences completed\n');
  }

  /// Demonstrate multiple concurrent sessions
  Future<void> _demonstrateMultipleSessions() async {
    print('6. 👥 Multiple Concurrent Sessions');

    final sessions = <String>[];
    
    // Create multiple sessions
    for (int i = 1; i <= 3; i++) {
      final sessionId = _contextManager.startSession(userId: 'user_$i');
      sessions.add(sessionId);
      print('   Created session $i: ${sessionId.substring(0, 8)}...');
    }

    print('   Total active sessions: ${_contextManager.activeSessionCount}');

    // Add different context to each session
    for (int i = 0; i < sessions.length; i++) {
      _contextManager.updateUserPreferences(sessions[i], {
        'user_type': 'type_${i + 1}',
        'session_number': i + 1,
      });
    }

    // Test session isolation
    for (int i = 0; i < sessions.length; i++) {
      final context = _contextManager.getContext(sessions[i]);
      print('   Session ${i + 1} preferences: ${context?.userPreferences}');
    }

    // End sessions
    for (final sessionId in sessions) {
      _contextManager.endSession(sessionId);
    }

    print('   Active sessions after cleanup: ${_contextManager.activeSessionCount}');
    print('   ✅ Multiple sessions completed\n');
  }
}

/// Run the conversation context example
Future<void> main() async {
  final example = ConversationContextExample();
  await example.runExample();
}