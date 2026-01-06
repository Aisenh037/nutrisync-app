import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../voice_first_ai/config.dart';

/// Manages conversation context and session state for voice interactions
/// Handles context preservation, interruption recovery, and natural conversation flow
class ConversationContextManager {
  final Map<String, ConversationSession> _activeSessions = {};
  final Map<String, List<ConversationTurn>> _conversationHistory = {};
  final StreamController<ConversationEvent> _eventController = StreamController.broadcast();
  final Uuid _uuid = const Uuid();

  /// Get the event stream for conversation updates
  Stream<ConversationEvent> get eventStream => _eventController.stream;

  /// Start a new conversation session
  String startSession({String? userId, Map<String, dynamic>? initialContext}) {
    final sessionId = _uuid.v4();
    final session = ConversationSession(
      sessionId: sessionId,
      userId: userId,
      startTime: DateTime.now(),
      context: ConversationContext(
        userPreferences: initialContext?['userPreferences'] ?? {},
        currentMealContext: initialContext?['currentMealContext'],
        recentMeals: List<Map<String, dynamic>>.from(initialContext?['recentMeals'] ?? []),
        nutritionGoals: initialContext?['nutritionGoals'],
        activeTopics: [],
        conversationState: ConversationState.active,
      ),
    );

    _activeSessions[sessionId] = session;
    _conversationHistory[sessionId] = [];

    _eventController.add(ConversationEvent(
      type: ConversationEventType.sessionStarted,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'userId': userId},
    ));

    return sessionId;
  }

  /// Add a conversation turn to the session
  void addConversationTurn(String sessionId, ConversationTurn turn) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    // Add to history
    _conversationHistory[sessionId]?.add(turn);

    // Update session context based on the turn
    _updateContextFromTurn(session, turn);

    // Emit event
    _eventController.add(ConversationEvent(
      type: ConversationEventType.turnAdded,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {
        'turn': turn.toJson(),
        'contextUpdated': true,
      },
    ));
  }

  /// Handle conversation interruption
  void handleInterruption(String sessionId, {String? reason}) {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    // Save current state for resumption
    session.context.conversationState = ConversationState.interrupted;
    session.context.interruptionReason = reason;
    session.context.interruptionTime = DateTime.now();

    _eventController.add(ConversationEvent(
      type: ConversationEventType.interrupted,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'reason': reason},
    ));
  }

  /// Resume interrupted conversation
  String resumeConversation(String sessionId) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    if (session.context.conversationState != ConversationState.interrupted) {
      throw Exception('Session is not in interrupted state');
    }

    session.context.conversationState = ConversationState.active;
    final interruptionDuration = session.context.interruptionTime != null
        ? DateTime.now().difference(session.context.interruptionTime!)
        : Duration.zero;

    _eventController.add(ConversationEvent(
      type: ConversationEventType.resumed,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'interruptionDuration': interruptionDuration.inSeconds},
    ));

    // Generate resumption message based on context
    return _generateResumptionMessage(session, interruptionDuration);
  }

  /// Get conversation context for a session
  ConversationContext? getContext(String sessionId) {
    return _activeSessions[sessionId]?.context;
  }

  /// Update user preferences in context
  void updateUserPreferences(String sessionId, Map<String, dynamic> preferences) {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    session.context.userPreferences.addAll(preferences);
    session.lastUpdated = DateTime.now();

    _eventController.add(ConversationEvent(
      type: ConversationEventType.contextUpdated,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {'preferencesUpdated': preferences},
    ));
  }

  /// Add meal to current context
  void addMealToContext(String sessionId, Map<String, dynamic> mealData) {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    session.context.currentMealContext = mealData;
    session.context.recentMeals.insert(0, mealData);

    // Keep only recent meals (last 10)
    if (session.context.recentMeals.length > 10) {
      session.context.recentMeals = session.context.recentMeals.take(10).toList();
    }

    session.lastUpdated = DateTime.now();
  }

  /// Get conversation history for a session
  List<ConversationTurn> getConversationHistory(String sessionId) {
    return _conversationHistory[sessionId] ?? [];
  }

  /// Get recent conversation turns (for context)
  List<ConversationTurn> getRecentTurns(String sessionId, {int count = 5}) {
    final history = _conversationHistory[sessionId] ?? [];
    return history.length <= count ? history : history.sublist(history.length - count);
  }

  /// Generate contextual response based on conversation history
  String generateContextualResponse(String sessionId, String userInput, String baseResponse) {
    final session = _activeSessions[sessionId];
    if (session == null) return baseResponse;

    final context = session.context;
    final recentTurns = getRecentTurns(sessionId, count: 3);

    // Check for follow-up questions
    if (_isFollowUpQuestion(userInput, recentTurns)) {
      final enhanced = _enhanceFollowUpResponse(baseResponse, recentTurns, context);
      if (enhanced != baseResponse) return enhanced;
    }

    // Check for meal-related context
    if (_isMealRelated(userInput) && context.currentMealContext != null) {
      return _enhanceMealResponse(baseResponse, context.currentMealContext!);
    }

    // Check for preference-based enhancement
    if (context.userPreferences.isNotEmpty) {
      return _enhanceWithPreferences(baseResponse, context.userPreferences);
    }

    return baseResponse;
  }

  /// End a conversation session
  void endSession(String sessionId) {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    session.context.conversationState = ConversationState.ended;
    session.endTime = DateTime.now();

    _eventController.add(ConversationEvent(
      type: ConversationEventType.sessionEnded,
      sessionId: sessionId,
      timestamp: DateTime.now(),
      data: {
        'duration': session.endTime!.difference(session.startTime).inMinutes,
        'turnCount': _conversationHistory[sessionId]?.length ?? 0,
      },
    ));

    // Clean up old sessions (keep for 1 hour for potential resumption)
    Timer(const Duration(hours: 1), () {
      _activeSessions.remove(sessionId);
      _conversationHistory.remove(sessionId);
    });
  }

  /// Get active session count
  int get activeSessionCount => _activeSessions.length;

  /// Get session by user ID
  String? getActiveSessionForUser(String userId) {
    for (final entry in _activeSessions.entries) {
      if (entry.value.userId == userId && 
          entry.value.context.conversationState == ConversationState.active) {
        return entry.key;
      }
    }
    return null;
  }

  /// Clean up expired sessions
  void cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredSessions = <String>[];

    for (final entry in _activeSessions.entries) {
      final session = entry.value;
      final lastActivity = session.lastUpdated ?? session.startTime;
      
      if (now.difference(lastActivity).inHours > VoiceFirstAIConfig.sessionTimeoutHours) {
        expiredSessions.add(entry.key);
      }
    }

    for (final sessionId in expiredSessions) {
      endSession(sessionId);
    }
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
    _activeSessions.clear();
    _conversationHistory.clear();
  }

  // Private helper methods

  void _updateContextFromTurn(ConversationSession session, ConversationTurn turn) {
    final context = session.context;
    
    // Extract topics from user input
    if (turn.userInput.isNotEmpty) {
      final topics = _extractTopics(turn.userInput);
      context.activeTopics.addAll(topics);
      
      // Keep only recent topics (last 5)
      if (context.activeTopics.length > 5) {
        context.activeTopics = context.activeTopics.take(5).toList();
      }
    }

    // Update meal context if meal-related
    if (_isMealRelated(turn.userInput)) {
      final mealInfo = _extractMealInfo(turn.userInput);
      if (mealInfo.isNotEmpty) {
        context.currentMealContext = mealInfo;
      }
    }

    session.lastUpdated = DateTime.now();
  }

  String _generateResumptionMessage(ConversationSession session, Duration interruptionDuration) {
    final context = session.context;
    
    if (interruptionDuration.inMinutes < 2) {
      if (context.currentMealContext != null) {
        return "Haan, hum aapke meal ke baare mein baat kar rahe the. Kya aur puchna hai? (Yes, we were talking about your meal. What else would you like to know?)";
      }
      return "Haan, aap kya keh rahe the? (Yes, what were you saying?)";
    } else if (interruptionDuration.inMinutes < 10) {
      if (context.currentMealContext != null) {
        return "Acha, hum aapke meal ke baare mein baat kar rahe the. Kya aur puchna hai? (Okay, we were talking about your meal. What else would you like to know?)";
      }
      return "Koi baat nahi, aap kya jaanna chahte hain? (No problem, what would you like to know?)";
    } else {
      return "Namaste! Main aapka nutrition assistant hun. Aaj kya khaya aapne? (Hello! I'm your nutrition assistant. What did you eat today?)";
    }
  }

  bool _isFollowUpQuestion(String userInput, List<ConversationTurn> recentTurns) {
    if (recentTurns.isEmpty) return false;
    
    final followUpIndicators = [
      'aur', 'or', 'what about', 'kya', 'how much', 'kitna', 'kitni',
      'tell me more', 'batao', 'explain', 'samjhao', 'what foods', 'which foods'
    ];
    
    final lowerInput = userInput.toLowerCase();
    
    // Check if input contains follow-up indicators
    final hasFollowUpIndicator = followUpIndicators.any((indicator) => lowerInput.contains(indicator));
    
    // Also check if the input relates to recent conversation topics
    final lastTurn = recentTurns.last;
    final hasRelatedTopic = _hasRelatedTopic(userInput, lastTurn);
    
    return hasFollowUpIndicator || hasRelatedTopic;
  }

  bool _hasRelatedTopic(String userInput, ConversationTurn lastTurn) {
    final userLower = userInput.toLowerCase();
    final lastInputLower = lastTurn.userInput.toLowerCase();
    final lastResponseLower = lastTurn.systemResponse.toLowerCase();
    
    // Check for common nutrition topics
    final nutritionTopics = ['protein', 'calorie', 'vitamin', 'mineral', 'carb', 'fat'];
    
    for (final topic in nutritionTopics) {
      if (userLower.contains(topic) && 
          (lastInputLower.contains(topic) || lastResponseLower.contains(topic))) {
        return true;
      }
    }
    
    return false;
  }

  bool _isMealRelated(String input) {
    final mealKeywords = [
      'khana', 'meal', 'breakfast', 'lunch', 'dinner', 'snack',
      'dal', 'rice', 'roti', 'sabzi', 'curry', 'khaya', 'eaten'
    ];
    
    final lowerInput = input.toLowerCase();
    return mealKeywords.any((keyword) => lowerInput.contains(keyword));
  }

  List<String> _extractTopics(String userInput) {
    final topics = <String>[];
    final lowerInput = userInput.toLowerCase();
    
    // Common nutrition topics
    if (lowerInput.contains('protein')) topics.add('protein');
    if (lowerInput.contains('calorie') || lowerInput.contains('calories')) topics.add('calories');
    if (lowerInput.contains('weight')) topics.add('weight');
    if (lowerInput.contains('diet')) topics.add('diet');
    if (lowerInput.contains('exercise') || lowerInput.contains('workout')) topics.add('exercise');
    
    return topics;
  }

  Map<String, dynamic> _extractMealInfo(String userInput) {
    // Simple meal extraction - in real implementation, this would use NLP
    final mealInfo = <String, dynamic>{};
    final lowerInput = userInput.toLowerCase();
    
    if (lowerInput.contains('breakfast')) mealInfo['type'] = 'breakfast';
    if (lowerInput.contains('lunch')) mealInfo['type'] = 'lunch';
    if (lowerInput.contains('dinner')) mealInfo['type'] = 'dinner';
    
    mealInfo['timestamp'] = DateTime.now().toIso8601String();
    mealInfo['description'] = userInput;
    
    return mealInfo;
  }

  String _enhanceFollowUpResponse(String baseResponse, List<ConversationTurn> recentTurns, ConversationContext context) {
    if (recentTurns.isEmpty) return baseResponse;
    
    final lastTurn = recentTurns.last;
    if (lastTurn.systemResponse.toLowerCase().contains('protein') || 
        lastTurn.userInput.toLowerCase().contains('protein')) {
      return "$baseResponse Protein ke liye aap dal, paneer, ya chicken le sakte hain. (For protein, you can have dal, paneer, or chicken.)";
    }
    
    return baseResponse;
  }

  String _enhanceMealResponse(String baseResponse, Map<String, dynamic> mealContext) {
    final mealType = mealContext['type'] as String?;
    if (mealType != null) {
      return "$baseResponse Aapka $mealType achha lag raha hai! (Your $mealType looks good!)";
    }
    return baseResponse;
  }

  String _enhanceWithPreferences(String baseResponse, Map<String, dynamic> preferences) {
    if (preferences.containsKey('vegetarian') && preferences['vegetarian'] == true) {
      return "$baseResponse Vegetarian options ke liye main aapko suggest kar sakta hun. (I can suggest vegetarian options for you.)";
    }
    return baseResponse;
  }
}

/// Represents a conversation session
class ConversationSession {
  final String sessionId;
  final String? userId;
  final DateTime startTime;
  DateTime? endTime;
  DateTime? lastUpdated;
  final ConversationContext context;

  ConversationSession({
    required this.sessionId,
    this.userId,
    required this.startTime,
    this.endTime,
    this.lastUpdated,
    required this.context,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'context': context.toJson(),
  };
}

/// Represents conversation context and state
class ConversationContext {
  Map<String, dynamic> userPreferences;
  Map<String, dynamic>? currentMealContext;
  List<Map<String, dynamic>> recentMeals;
  Map<String, dynamic>? nutritionGoals;
  List<String> activeTopics;
  ConversationState conversationState;
  String? interruptionReason;
  DateTime? interruptionTime;

  ConversationContext({
    required this.userPreferences,
    this.currentMealContext,
    required this.recentMeals,
    this.nutritionGoals,
    required this.activeTopics,
    required this.conversationState,
    this.interruptionReason,
    this.interruptionTime,
  });

  Map<String, dynamic> toJson() => {
    'userPreferences': userPreferences,
    'currentMealContext': currentMealContext,
    'recentMeals': recentMeals,
    'nutritionGoals': nutritionGoals,
    'activeTopics': activeTopics,
    'conversationState': conversationState.toString(),
    'interruptionReason': interruptionReason,
    'interruptionTime': interruptionTime?.toIso8601String(),
  };
}

/// Represents a single conversation turn
class ConversationTurn {
  final String turnId;
  final DateTime timestamp;
  final String userInput;
  final String systemResponse;
  final ConversationTurnType type;
  final Map<String, dynamic> metadata;

  ConversationTurn({
    required this.turnId,
    required this.timestamp,
    required this.userInput,
    required this.systemResponse,
    required this.type,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'turnId': turnId,
    'timestamp': timestamp.toIso8601String(),
    'userInput': userInput,
    'systemResponse': systemResponse,
    'type': type.toString(),
    'metadata': metadata,
  };
}

/// Represents conversation events
class ConversationEvent {
  final ConversationEventType type;
  final String sessionId;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  ConversationEvent({
    required this.type,
    required this.sessionId,
    required this.timestamp,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'sessionId': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };
}

/// Conversation state enumeration
enum ConversationState {
  active,
  interrupted,
  paused,
  ended,
}

/// Conversation turn type enumeration
enum ConversationTurnType {
  mealLogging,
  nutritionQuery,
  recommendation,
  clarification,
  greeting,
  farewell,
}

/// Conversation event type enumeration
enum ConversationEventType {
  sessionStarted,
  sessionEnded,
  turnAdded,
  interrupted,
  resumed,
  contextUpdated,
}