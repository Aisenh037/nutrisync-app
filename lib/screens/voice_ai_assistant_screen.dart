import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../voice_first_ai/service_orchestrator.dart';
import '../voice/hinglish_processor.dart';
import '../widgets/premium_feature_gate.dart';

/// Voice-First AI Assistant Screen - Main UI for voice interactions
/// Integrates all services into cohesive user experience with visual feedback
class VoiceAIAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAIAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAIAssistantScreen> createState() => _VoiceAIAssistantScreenState();
}

class _VoiceAIAssistantScreenState extends ConsumerState<VoiceAIAssistantScreen> 
    with PremiumFeatureMixin, TickerProviderStateMixin {
  // Core service orchestrator
  late VoiceFirstAIServiceOrchestrator _orchestrator;
  
  // UI state
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Voice state
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  VoiceConversationSession? _currentSession;
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Initialize the service orchestrator with all dependencies
      _orchestrator = VoiceFirstAIServiceOrchestrator();

      final initialized = await _orchestrator.initialize(
        elevenLabsApiKey: 'sk_8b912284e3bb7ee8a1d07041dcece48038550ccaa9b19007',
        voiceId: 'pNInz6obpgDQGcFmaJgB', // Adam voice
      );

      if (!initialized) {
        throw Exception('Failed to initialize service orchestrator');
      }

      // Start voice conversation session
      _currentSession = await _orchestrator.startVoiceConversation(
        userId: 'demo-user',
        initialContext: {
          'preferredLanguage': 'hinglish',
          'culturalContext': 'indian',
        },
      );
      
      setState(() {
        _isInitialized = true;
        _isProcessing = false;
      });
      
      _addMessage(
        'Namaste! 🙏 Main aapka personal nutrition assistant hun.\\n\\n'
        '🍽️ Meal logging kar sakte hain\\n'
        '💡 Nutrition advice le sakte hain\\n'
        '🥗 Healthy recipes puch sakte hain\\n'
        '🛒 Grocery list banwa sakte hain\\n\\n'
        'Voice button dabayiye ya type kariye!',
        false,
        messageType: MessageType.welcome,
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _addMessage(
        'Sorry, main initialize nahi ho paya. Please restart the app.\\nError: $e',
        false,
        messageType: MessageType.error,
      );
    }
  }

  void _addMessage(String text, bool isUser, {MessageType messageType = MessageType.normal}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
        messageType: messageType,
      ));
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startVoiceInput() async {
    if (_isListening || _isProcessing || !_isInitialized) return;

    // Check query limit before processing
    final canMakeQuery = await checkQueryLimit(ref);
    if (!canMakeQuery) {
      if (mounted) {
        showUpgradeDialog(context, 'unlimited_voice_queries');
      }
      return;
    }

    setState(() {
      _isListening = true;
    });
    
    // Start pulse animation
    _pulseController.repeat(reverse: true);

    try {
      // Use orchestrator for complete voice interaction
      final result = await _orchestrator.listenAndProcess(
        userId: 'demo-user',
        timeoutSeconds: 10,
      );
      
      if (result.userInput.isNotEmpty) {
        _addMessage(result.userInput, true);
        
        // Add system response with appropriate message type
        final messageType = _mapInteractionTypeToMessageType(result.interactionType);
        _addMessage(result.systemResponse, false, messageType: messageType);
        
        // Add suggestions if available
        if (result.suggestions.isNotEmpty) {
          _addSuggestions(result.suggestions);
        }
        
        // Increment query count after successful processing
        await incrementQueryCount(ref);
      } else {
        _addMessage('Koi speech detect nahi hui. Please try again.', false, messageType: MessageType.info);
      }
    } catch (e) {
      _addMessage('Voice input error: ${e.toString()}', false, messageType: MessageType.error);
    } finally {
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _processUserInput(String input) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Use orchestrator for complete processing
      final result = await _orchestrator.processVoiceInteraction(
        userInput: input,
        userId: 'demo-user',
        sessionId: _currentSession?.sessionId,
      );
      
      // Add system response with appropriate message type
      final messageType = _mapInteractionTypeToMessageType(result.interactionType);
      _addMessage(result.systemResponse, false, messageType: messageType);
      
      // Add suggestions if available
      if (result.suggestions.isNotEmpty) {
        _addSuggestions(result.suggestions);
      }
      
      // Handle clarification requests
      if (result.requiresClarification && result.ambiguities.isNotEmpty) {
        _handleAmbiguities(result.ambiguities);
      }
      
    } catch (e) {
      _addMessage('Processing error: ${e.toString()}', false, messageType: MessageType.error);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  MessageType _mapInteractionTypeToMessageType(VoiceInteractionType interactionType) {
    switch (interactionType) {
      case VoiceInteractionType.mealLogging:
        return MessageType.success;
      case VoiceInteractionType.recommendation:
        return MessageType.recommendation;
      case VoiceInteractionType.cookingEducation:
        return MessageType.education;
      case VoiceInteractionType.groceryManagement:
        return MessageType.grocery;
      case VoiceInteractionType.nutritionQuery:
        return MessageType.info;
      case VoiceInteractionType.error:
        return MessageType.error;
      default:
        return MessageType.normal;
    }
  }

  void _addSuggestions(List<String> suggestions) {
    if (suggestions.isEmpty) return;
    
    final suggestionText = '💡 **Suggestions:**\\n${suggestions.take(3).map((s) => '• $s').join('\\n')}';
    
    _addMessage(suggestionText, false, messageType: MessageType.info);
  }

  void _handleAmbiguities(List<FoodAmbiguity> ambiguities) {
    if (ambiguities.isEmpty) return;
    
    final clarificationText = '🤔 **Clarification needed:**\\n${ambiguities.take(2).map((a) => '• ${a.term}: ${a.possibleMeanings.join(", ")}').join('\\n')}\\n\\nKripaya specify kariye!';
    
    _addMessage(clarificationText, false, messageType: MessageType.info);
  }

  Widget _buildQuickActionButton(String label, String prompt, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[100]!, Colors.blue[200]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _handleQuickAction(prompt),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickAction(String prompt) async {
    _textController.text = prompt;
    await _handleTextInput(prompt);
  }

  Future<void> _handleTextInput(String text) async {
    if (text.trim().isEmpty) return;
    
    // Check query limit for text input
    final canMakeQuery = await checkQueryLimit(ref);
    if (!canMakeQuery) {
      if (mounted) {
        showUpgradeDialog(context, 'unlimited_voice_queries');
      }
      return;
    }
    
    _addMessage(text, true);
    _textController.clear();
    await _processUserInput(text);
    
    // Increment query count after successful processing
    await incrementQueryCount(ref);
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _orchestrator.dispose();
    }
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Voice AI Nutrition Assistant'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Query limit warning
          const QueryLimitWarning(),
          
          // Status indicator with enhanced visual feedback
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getStatusGradientColors(),
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _getStatusSubtitle(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat messages with enhanced UI
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[50]!,
                    Colors.white,
                  ],
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return EnhancedChatBubble(message: message);
                },
              ),
            ),
          ),
          
          // Enhanced input area with quick actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Quick action buttons
                  if (_isInitialized && !_isProcessing && !_isListening)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickActionButton(
                              '🍽️ Log Meal',
                              'Maine khaya...',
                              Icons.restaurant,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              '💡 Get Advice',
                              'Kya khana chahiye...',
                              Icons.lightbulb,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              '👨‍🍳 Cooking Tips',
                              'Dal kaise banau...',
                              Icons.school,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionButton(
                              '🛒 Grocery List',
                              'Grocery list banao',
                              Icons.shopping_cart,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Main input row
                  Row(
                    children: [
                      // Voice input button with enhanced animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isListening 
                                      ? [Colors.red[400]!, Colors.red[600]!]
                                      : [Colors.green[400]!, Colors.green[600]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening ? Colors.red : Colors.green).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: _isListening || !_isInitialized ? null : _startVoiceInput,
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      
                      // Enhanced text input
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Type in Hindi/English... (e.g., "Maine dal chawal khaya")',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _handleTextInput,
                            enabled: _isInitialized && !_isProcessing,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Send button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isInitialized && !_isProcessing 
                              ? () => _handleTextInput(_textController.text)
                              : null,
                          icon: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for enhanced UI
  List<Color> _getStatusGradientColors() {
    if (!_isInitialized) return [Colors.orange[400]!, Colors.orange[600]!];
    if (_isListening) return [Colors.red[400]!, Colors.red[600]!];
    if (_isProcessing) return [Colors.blue[400]!, Colors.blue[600]!];
    return [Colors.green[400]!, Colors.green[600]!];
  }

  Color _getStatusColor() {
    if (!_isInitialized) return Colors.orange[600]!;
    if (_isListening) return Colors.red[600]!;
    if (_isProcessing) return Colors.blue[600]!;
    return Colors.green[600]!;
  }

  IconData _getStatusIcon() {
    if (!_isInitialized) return Icons.hourglass_empty;
    if (_isListening) return Icons.mic;
    if (_isProcessing) return Icons.psychology;
    return Icons.check_circle;
  }

  String _getStatusTitle() {
    if (!_isInitialized) return 'Initializing...';
    if (_isListening) return 'Listening...';
    if (_isProcessing) return 'Processing...';
    return 'Ready to Help!';
  }

  String _getStatusSubtitle() {
    if (!_isInitialized) return 'Setting up your AI assistant';
    if (_isListening) return 'Speak now in Hindi or English';
    if (_isProcessing) return 'Understanding your request';
    return 'Tap mic or type your message';
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 How to Use Voice AI Assistant'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('**Voice Commands:**', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('🍽️ "Maine breakfast mein poha khaya"'),
              Text('💡 "Kya khana chahiye weight loss ke liye?"'),
              Text('👨‍🍳 "Dal kaise banau healthy?"'),
              Text('🛒 "Grocery list banao"'),
              Text('📊 "Mera nutrition kaisa hai?"'),
              SizedBox(height: 16),
              Text('**Enhanced Features:**', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Intelligent meal logging with cultural context'),
              Text('• Personalized recommendations based on your profile'),
              Text('• Indian cooking education and tips'),
              Text('• Automatic grocery list generation'),
              Text('• Conversation context and memory'),
              Text('• Hinglish language support'),
              Text('• Voice & text input support'),
              SizedBox(height: 16),
              Text('**Smart Features:**', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Understands Indian food names and portions'),
              Text('• Handles ambiguous descriptions with clarification'),
              Text('• Provides culturally appropriate advice'),
              Text('• Learns from your eating patterns'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// Enhanced message types for better UI
enum MessageType {
  normal,
  welcome,
  success,
  error,
  info,
  recommendation,
  education,
  grocery,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType messageType;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageType = MessageType.normal,
  });
}

class EnhancedChatBubble extends StatelessWidget {
  final ChatMessage message;

  const EnhancedChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: _getMessageGradient(),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser && message.messageType != MessageType.normal)
                    _buildMessageTypeHeader(),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: message.isUser ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: message.isUser ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: message.isUser 
              ? [Colors.blue[400]!, Colors.blue[600]!]
              : [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        message.isUser ? Icons.person : Icons.smart_toy,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildMessageTypeHeader() {
    final typeInfo = _getMessageTypeInfo();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            typeInfo['icon'],
            size: 16,
            color: typeInfo['color'],
          ),
          const SizedBox(width: 6),
          Text(
            typeInfo['label'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: typeInfo['color'],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getMessageGradient() {
    if (message.isUser) {
      return LinearGradient(
        colors: [Colors.green[500]!, Colors.green[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    switch (message.messageType) {
      case MessageType.welcome:
        return LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case MessageType.success:
        return LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case MessageType.error:
        return LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case MessageType.recommendation:
        return LinearGradient(
          colors: [Colors.purple[50]!, Colors.purple[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case MessageType.education:
        return LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case MessageType.grocery:
        return LinearGradient(
          colors: [Colors.teal[50]!, Colors.teal[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey[100]!, Colors.grey[200]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Map<String, dynamic> _getMessageTypeInfo() {
    switch (message.messageType) {
      case MessageType.welcome:
        return {'icon': Icons.waving_hand, 'label': 'Welcome', 'color': Colors.blue[600]};
      case MessageType.success:
        return {'icon': Icons.check_circle, 'label': 'Success', 'color': Colors.green[600]};
      case MessageType.error:
        return {'icon': Icons.error, 'label': 'Error', 'color': Colors.red[600]};
      case MessageType.info:
        return {'icon': Icons.info, 'label': 'Info', 'color': Colors.blue[600]};
      case MessageType.recommendation:
        return {'icon': Icons.lightbulb, 'label': 'Recommendations', 'color': Colors.purple[600]};
      case MessageType.education:
        return {'icon': Icons.school, 'label': 'Cooking Tips', 'color': Colors.orange[600]};
      case MessageType.grocery:
        return {'icon': Icons.shopping_cart, 'label': 'Grocery List', 'color': Colors.teal[600]};
      default:
        return {'icon': Icons.chat, 'label': 'Chat', 'color': Colors.grey[600]};
    }
  }
}