import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../nutrition/nutrition_intelligence_core.dart';
import '../nutrition/meal_logger_service.dart';
import '../voice/hinglish_processor.dart';
import '../voice/conversation_context_manager.dart';
import '../voice/voice_interface.dart';
import '../cultural/cultural_context_engine.dart';
import '../cultural/indian_food_database.dart';
import '../widgets/premium_feature_gate.dart';
import '../providers/providers.dart';

/// Voice-First AI Assistant Screen using our implemented components
class VoiceAIAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAIAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAIAssistantScreen> createState() => _VoiceAIAssistantScreenState();
}

class _VoiceAIAssistantScreenState extends ConsumerState<VoiceAIAssistantScreen> 
    with PremiumFeatureMixin {
  late NutritionIntelligenceCore _nutritionCore;
  late VoiceInterface _voiceInterface;
  late ConversationContextManager _contextManager;
  
  final List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Initialize all voice-first AI components
      final hinglishProcessor = HinglishProcessor();
      _contextManager = ConversationContextManager();
      final culturalEngine = CulturalContextEngine();
      final foodDatabase = IndianFoodDatabase();
      final mealLogger = MealLoggerService();

      _nutritionCore = NutritionIntelligenceCore(
        hinglishProcessor: hinglishProcessor,
        contextManager: _contextManager,
        culturalEngine: culturalEngine,
        foodDatabase: foodDatabase,
        mealLogger: mealLogger,
      );

      _voiceInterface = VoiceInterface(
        elevenLabsApiKey: 'sk_8b912284e3bb7ee8a1d07041dcece48038550ccaa9b19007',
        voiceId: 'pNInz6obpgDQGcFmaJgB', // Adam voice
      );

      // Start a conversation session
      _currentSessionId = _contextManager.startSession(userId: 'demo-user');
      
      _addMessage('Namaste! Main aapka nutrition assistant hun. Aap mujhse meal logging, nutrition advice, ya health questions puch sakte hain. Voice button dabayiye ya type kariye!', false);
    } catch (e) {
      _addMessage('Sorry, main initialize nahi ho paya. Error: $e', false);
    }
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser, timestamp: DateTime.now()));
    });
  }

  Future<void> _startVoiceInput() async {
    if (_isListening || _isProcessing) return;

    // Check query limit before processing
    final canMakeQuery = await checkQueryLimit(ref);
    if (!canMakeQuery) {
      showUpgradeDialog(context, 'unlimited_voice_queries');
      return;
    }

    setState(() {
      _isListening = true;
    });

    try {
      await _voiceInterface.initialize();
      final transcription = await _voiceInterface.listenForVoiceInput();
      
      if (transcription.isNotEmpty) {
        _addMessage(transcription, true);
        await _processUserInput(transcription);
        
        // Increment query count after successful processing
        await incrementQueryCount(ref);
      }
    } catch (e) {
      _addMessage('Voice input error: $e', false);
    } finally {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _processUserInput(String input) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Determine if this is a meal logging request or nutrition query
      if (_isMealLoggingRequest(input)) {
        await _processMealLogging(input);
      } else {
        await _processNutritionQuery(input);
      }
    } catch (e) {
      _addMessage('Processing error: $e', false);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  bool _isMealLoggingRequest(String input) {
    final mealKeywords = ['khaya', 'khayi', 'breakfast', 'lunch', 'dinner', 'snack', 'meal', 'log'];
    return mealKeywords.any((keyword) => input.toLowerCase().contains(keyword));
  }

  Future<void> _processMealLogging(String input) async {
    final voiceInput = VoiceInput(
      transcription: input,
      timestamp: DateTime.now(),
      sessionId: _currentSessionId ?? 'default',
      metadata: {'userId': 'demo-user'},
    );

    final result = await _nutritionCore.processMealLogging(voiceInput);
    
    if (result.success) {
      String response = 'Great! Maine aapka meal log kar diya hai. ';
      if (result.mealData != null) {
        final calories = result.mealData!.nutrition.totalCalories.toInt();
        response += 'Total calories: $calories. ';
      }
      response += 'Kya aur kuch help chahiye?';
      _addMessage(response, false);
      
      // Generate voice response
      await _generateVoiceResponse(response);
    } else {
      _addMessage(result.message, false);
      await _generateVoiceResponse(result.message);
    }
  }

  Future<void> _processNutritionQuery(String input) async {
    // Create user context
    final userProfile = _createDemoUserProfile();
    final context = UserContext(
      profile: userProfile,
      recentMeals: [],
      preferences: {},
    );

    final response = await _nutritionCore.answerNutritionQuery(input, context);
    _addMessage(response, false);
    
    // Generate voice response
    await _generateVoiceResponse(response);
  }

  Future<void> _generateVoiceResponse(String text) async {
    try {
      await _voiceInterface.generateVoiceResponse(text);
    } catch (e) {
      print('Voice generation error: $e');
    }
  }

  UserProfile _createDemoUserProfile() {
    return UserProfile(
      userId: 'demo-user',
      personalInfo: PersonalInfo(
        name: 'Demo User',
        age: 30,
        gender: 'male',
        height: 175.0,
        weight: 75.0,
        location: 'Delhi',
      ),
      goals: DietaryGoals(
        type: GoalType.maintenance,
        targetWeight: 75.0,
        timeframe: 365,
        activityLevel: ActivityLevel.moderatelyActive,
      ),
      conditions: HealthConditions(
        allergies: [],
        medicalConditions: [],
        medications: [],
      ),
      preferences: FoodPreferences(
        liked: ['dal', 'roti'],
        disliked: [],
        dietary: ['vegetarian'],
        spiceLevel: 'medium',
      ),
      patterns: EatingPatterns(
        mealTimes: {'breakfast': '8:00', 'lunch': '13:00', 'dinner': '20:00'},
        mealsPerDay: 3,
        snackPreferences: ['fruits'],
      ),
      tier: SubscriptionTier.free,
    );
  }

  @override
  void dispose() {
    _voiceInterface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice AI Nutrition Assistant'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Query limit warning
          const QueryLimitWarning(),
          
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isListening 
                ? Colors.red[100] 
                : _isProcessing 
                    ? Colors.orange[100] 
                    : Colors.green[100],
            child: Text(
              _isListening 
                  ? '🎤 Listening... Speak now!'
                  : _isProcessing 
                      ? '🤔 Processing your request...'
                      : '✅ Ready - Tap mic or type message',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isListening 
                    ? Colors.red[800] 
                    : _isProcessing 
                        ? Colors.orange[800] 
                        : Colors.green[800],
              ),
            ),
          ),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Voice input button
                Container(
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isListening ? null : _startVoiceInput,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Text input
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Type your message in Hindi/English...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (text) async {
                      if (text.trim().isNotEmpty) {
                        // Check query limit for text input too
                        final canMakeQuery = await checkQueryLimit(ref);
                        if (!canMakeQuery) {
                          showUpgradeDialog(context, 'unlimited_voice_queries');
                          return;
                        }
                        
                        _addMessage(text, true);
                        await _processUserInput(text);
                        
                        // Increment query count after successful processing
                        await incrementQueryCount(ref);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.green[600] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isUser ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}