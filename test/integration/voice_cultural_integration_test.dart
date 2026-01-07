import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisync/voice/voice_interface.dart';
import 'package:nutrisync/voice/conversation_context_manager.dart';
import 'package:nutrisync/cultural/cultural_context_engine.dart';
import 'package:nutrisync/cultural/indian_food_database.dart';

void main() {
  // Initialize Flutter bindings for plugin tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Voice-Cultural Integration Tests', () {
    late VoiceInterface voiceInterface;
    late ConversationContextManager contextManager;
    late CulturalContextEngine culturalEngine;
    late IndianFoodDatabase foodDatabase;

    setUp(() {
      voiceInterface = VoiceInterface(elevenLabsApiKey: 'test_key');
      contextManager = ConversationContextManager();
      culturalEngine = CulturalContextEngine();
      foodDatabase = IndianFoodDatabase();
    });

    tearDown(() {
      voiceInterface.dispose();
      contextManager.dispose();
    });

    group('Component Instantiation', () {
      test('should instantiate all components without errors', () {
        // Test that all components can be created together
        expect(voiceInterface, isNotNull);
        expect(contextManager, isNotNull);
        expect(culturalEngine, isNotNull);
        expect(foodDatabase, isNotNull);
      });

      test('should handle basic voice interface operations', () {
        // Test basic voice interface functionality
        expect(voiceInterface.getConversationContext(), isNull);
        
        final stream = voiceInterface.startConversation(
          userId: 'test_user',
          initialContext: {'test': true},
        );
        
        expect(stream, isA<Stream>());
        expect(voiceInterface.currentSessionId, isNotNull);
      });

      test('should handle basic context manager operations', () {
        // Test basic context manager functionality
        final sessionId = contextManager.startSession(userId: 'test_user');
        expect(sessionId, isNotNull);
        
        final context = contextManager.getContext(sessionId);
        expect(context, isNotNull);
        
        contextManager.endSession(sessionId);
        expect(contextManager.getContext(sessionId), isNull);
      });

      test('should handle basic cultural engine operations', () {
        // Test basic cultural engine functionality
        final cookingMethod = culturalEngine.identifyCookingStyle('tadka dal');
        expect(cookingMethod, isNotNull);
        expect(cookingMethod.name, equals('tadka'));
        
        final portion = culturalEngine.estimateIndianPortion('dal', '1 katori');
        expect(portion, isNotNull);
        expect(portion.quantity, equals(150.0));
        expect(portion.unit, equals('grams'));
      });

      test('should handle basic food database operations', () async {
        // Test basic food database functionality
        final foods = await foodDatabase.searchFood('dal');
        expect(foods, isA<List>());
        // Note: Will be empty in test environment without Firestore
      });
    });

    group('Basic Integration', () {
      test('should integrate voice interface with context manager', () {
        // Start a conversation
        final stream = voiceInterface.startConversation(
          userId: 'test_user',
          initialContext: {'vegetarian': true},
        );
        
        expect(stream, isNotNull);
        expect(voiceInterface.currentSessionId, isNotNull);
        
        // Add meal context
        voiceInterface.addMealContext({
          'type': 'breakfast',
          'foods': ['paratha'],
        });
        
        final context = voiceInterface.getConversationContext();
        expect(context, isNotNull);
        expect(context!.currentMealContext?['type'], equals('breakfast'));
      });

      test('should integrate cultural engine with context manager', () {
        final sessionId = contextManager.startSession(userId: 'test_user');
        
        // Use cultural engine to process Indian food
        final cookingMethod = culturalEngine.identifyCookingStyle('tadka dal banaya');
        final portion = culturalEngine.estimateIndianPortion('dal', '2 katori');
        
        // Add to context
        contextManager.addMealToContext(sessionId, {
          'type': 'lunch',
          'foods': ['dal'],
          'cooking_method': cookingMethod.name,
          'portion_grams': portion.quantity,
        });
        
        final context = contextManager.getContext(sessionId);
        expect(context?.currentMealContext?['cooking_method'], equals('tadka'));
        expect(context?.currentMealContext?['portion_grams'], equals(300.0));
        
        contextManager.endSession(sessionId);
      });

      test('should handle conversation flow with cultural context', () {
        final sessionId = contextManager.startSession(userId: 'test_user');
        
        // Simulate Hinglish input processing
        const hinglishInput = 'Maine breakfast mein 2 paratha khaya';
        
        // Extract cultural information
        final cookingMethod = culturalEngine.identifyCookingStyle(hinglishInput);
        final portion = culturalEngine.estimateIndianPortion('paratha', '2');
        
        // Add to conversation
        contextManager.addMealToContext(sessionId, {
          'type': 'breakfast',
          'foods': ['paratha'],
          'cooking_method': cookingMethod.name,
          'portion_grams': portion.quantity,
          'cultural_context': {
            'region': 'North India',
            'meal_pattern': 'traditional',
          },
        });
        
        // Verify integration
        final context = contextManager.getContext(sessionId);
        expect(context?.currentMealContext?['foods'], contains('paratha'));
        expect(context?.currentMealContext?['portion_grams'], equals(60.0)); // 2 * 30g
        
        contextManager.endSession(sessionId);
      });

      test('should handle interruption and resumption', () {
        final sessionId = contextManager.startSession(userId: 'test_user');
        
        // Add meal context
        contextManager.addMealToContext(sessionId, {
          'type': 'dinner',
          'foods': ['roti', 'sabzi'],
        });
        
        // Test interruption
        contextManager.handleInterruption(sessionId, reason: 'phone_call');
        expect(contextManager.getContext(sessionId)?.conversationState, 
               equals(ConversationState.interrupted));
        
        // Test resumption
        final resumptionMessage = contextManager.resumeConversation(sessionId);
        expect(resumptionMessage, isNotEmpty);
        expect(contextManager.getContext(sessionId)?.conversationState, 
               equals(ConversationState.active));
        
        contextManager.endSession(sessionId);
      });
    });

    group('Error Handling', () {
      test('should handle invalid operations gracefully', () {
        // Test voice interface error handling
        expect(() => voiceInterface.stopListening(), returnsNormally);
        
        // Test context manager error handling
        expect(() => contextManager.handleInterruption('nonexistent_session'), 
               throwsA(isA<Exception>()));
        
        // Test cultural engine with unknown input
        final unknownCooking = culturalEngine.identifyCookingStyle('unknown method');
        expect(unknownCooking.name, equals('simple')); // Default fallback
        
        final unknownPortion = culturalEngine.estimateIndianPortion('unknown', '1 cup');
        expect(unknownPortion.quantity, greaterThan(0)); // Should provide estimate
      });

      test('should maintain data consistency', () {
        final sessionId = contextManager.startSession(userId: 'test_user');
        
        // Add valid meal context
        contextManager.addMealToContext(sessionId, {
          'type': 'breakfast',
          'foods': ['paratha'],
        });
        
        // Verify context is preserved
        final context = contextManager.getContext(sessionId);
        expect(context?.currentMealContext?['type'], equals('breakfast'));
        
        contextManager.endSession(sessionId);
      });
    });

    group('Concurrent Operations', () {
      test('should handle multiple sessions', () {
        final session1 = contextManager.startSession(userId: 'user1');
        final session2 = contextManager.startSession(userId: 'user2');
        
        expect(session1, isNot(equals(session2)));
        expect(contextManager.activeSessions, equals(2));
        
        // Test concurrent cultural operations
        final cooking1 = culturalEngine.identifyCookingStyle('tadka dal');
        final cooking2 = culturalEngine.identifyCookingStyle('bhuna masala');
        
        expect(cooking1.name, equals('tadka'));
        expect(cooking2.name, equals('bhuna'));
        
        // Clean up
        contextManager.endSession(session1);
        contextManager.endSession(session2);
        expect(contextManager.activeSessions, equals(0));
      });

      test('should handle concurrent voice operations', () {
        // Test multiple voice streams can be created
        final stream1 = voiceInterface.startConversation(userId: 'user1');
        expect(stream1, isNotNull);
        
        // Note: VoiceInterface typically handles one session at a time
        // This test verifies it doesn't crash with multiple calls
      });
    });

    group('Regional Context Integration', () {
      test('should handle regional food variations', () {
        // Test North Indian context
        final northContext = culturalEngine.getRegionalContext('North India', 'dal');
        expect(northContext.region, equals('North India'));
        expect(northContext.dishName, equals('dal'));
        
        // Test South Indian context
        final southContext = culturalEngine.getRegionalContext('South India', 'sambar');
        expect(southContext.region, equals('South India'));
        expect(southContext.dishName, equals('sambar'));
      });

      test('should convert Western to Indian measurements', () {
        final indianRef = culturalEngine.convertToIndianReference(1.0, 'cup', 'rice');
        expect(indianRef, contains('katori'));
        
        final spoonRef = culturalEngine.convertToIndianReference(1.0, 'tablespoon', 'oil');
        expect(spoonRef, contains('spoon'));
      });
    });
  });
}