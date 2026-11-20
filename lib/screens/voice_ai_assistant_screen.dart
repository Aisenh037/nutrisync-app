import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/secure_key_manager.dart';
import '../providers/providers.dart';
import '../services/conversation_memory_service.dart';
import '../services/food_vision_ai_service.dart';
import '../services/performance_service.dart';
import '../voice_first_ai/service_orchestrator.dart';
import '../widgets/food_confidence_sheet.dart';
import '../widgets/premium_feature_gate.dart';

// ── Voice AI screen ───────────────────────────────────────────────────────────

class VoiceAIAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAIAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAIAssistantScreen> createState() =>
      _VoiceAIAssistantScreenState();
}

class _VoiceAIAssistantScreenState
    extends ConsumerState<VoiceAIAssistantScreen>
    with PremiumFeatureMixin, TickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────────
  late VoiceFirstAIServiceOrchestrator _orchestrator;
  final _memory = ConversationMemoryService.instance;
  final _foodVision = FoodVisionAIService.instance;
  final _imagePicker = ImagePicker();

  // ── UI state ─────────────────────────────────────────────────────────────────
  final List<_ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isScanningFood = false;
  VoiceConversationSession? _currentSession;

  // ── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeServices();
  }

  @override
  void dispose() {
    if (_isInitialized) _orchestrator.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Initialisation ────────────────────────────────────────────────────────────

  Future<void> _initializeServices() async {
    setState(() => _isProcessing = true);
    try {
      // ── 1. API key from SecureKeyManager (never hardcoded) ──────────────────
      final elevenLabsKey =
          await SecureKeyManager.instance.getApiKey('elevenlabs') ?? '';

      _orchestrator = VoiceFirstAIServiceOrchestrator();
      final ok = await _orchestrator.initialize(
        elevenLabsApiKey: elevenLabsKey,
        voiceId: 'pNInz6obpgDQGcFmaJgB',
      );
      if (!ok) throw Exception('Orchestrator init failed');

      final userId = _currentUserId();
      _currentSession = await _orchestrator.startVoiceConversation(
        userId: userId,
        initialContext: {
          'preferredLanguage': 'hinglish',
          'culturalContext': 'indian',
        },
      );

      // ── 2. Load persisted history ───────────────────────────────────────────
      await _loadHistory(userId);

      setState(() {
        _isInitialized = true;
        _isProcessing = false;
      });

      if (_messages.isEmpty) {
        _addMessage(
          'Namaste! 🙏 Main aapka personal nutrition assistant hun.\n\n'
          '🍽️ Meal logging kar sakte hain\n'
          '📸 Khana photo se scan karein\n'
          '💡 Nutrition advice le sakte hain\n'
          '🛒 Grocery list banwa sakte hain\n\n'
          'Voice button dabayiye ya type kariye!',
          role: 'assistant',
          messageType: _MessageType.welcome,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _addMessage(
        'Sorry, initialize nahi ho paya. Please restart karein.\n$e',
        role: 'assistant',
        messageType: _MessageType.error,
      );
    }
  }

  Future<void> _loadHistory(String userId) async {
    final turns = await _memory.loadHistory(userId);
    if (turns.isEmpty) return;
    setState(() {
      for (final t in turns) {
        _messages.add(_ChatMessage(
          text: t.text,
          role: t.role,
          timestamp: t.timestamp,
          messageType: _MessageType.normal,
        ));
      }
    });
  }

  // ── Message management ────────────────────────────────────────────────────────

  void _addMessage(
    String text, {
    required String role,
    _MessageType messageType = _MessageType.normal,
  }) {
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        role: role,
        timestamp: DateTime.now(),
        messageType: messageType,
      ));
    });
    _scrollToBottom();
  }

  /// Adds a placeholder bubble and streams the text in word-by-word.
  /// Returns after the stream completes.
  Future<void> _streamMessage(
    String fullText, {
    _MessageType messageType = _MessageType.normal,
  }) async {
    final words = fullText.split(' ');
    final placeholder = _ChatMessage(
      text: '',
      role: 'assistant',
      timestamp: DateTime.now(),
      messageType: messageType,
      isStreaming: true,
    );
    setState(() => _messages.add(placeholder));
    _scrollToBottom();

    final buffer = StringBuffer();
    for (final word in words) {
      await Future<void>.delayed(const Duration(milliseconds: 28));
      buffer.write(word);
      buffer.write(' ');
      setState(() {
        _messages.last = placeholder.copyWith(text: buffer.toString().trim());
      });
      _scrollToBottom();
    }
    // Mark streaming done
    setState(() {
      _messages.last = _messages.last.copyWith(isStreaming: false);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Voice input ───────────────────────────────────────────────────────────────

  Future<void> _startVoiceInput() async {
    if (_isListening || _isProcessing || !_isInitialized) return;
    if (!await checkQueryLimit(ref)) {
      if (mounted) showUpgradeDialog(context, 'unlimited_voice_queries');
      return;
    }

    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    try {
      final userId = _currentUserId();
      final result = await PerformanceService.traceAsync(
        PerformanceService.kVoiceQuery,
        () => _orchestrator.listenAndProcess(
          userId: userId,
          timeoutSeconds: 10,
        ),
      );

      if (result.userInput.isNotEmpty) {
        _addMessage(result.userInput, role: 'user');
        await _memory.saveTurn(
          userId: userId,
          role: 'user',
          text: result.userInput,
          sessionId: _currentSession?.sessionId,
        );
        await _deliverResponse(result);
        await incrementQueryCount(ref);
      } else {
        _addMessage('Koi speech detect nahi hui. Please try again.',
            role: 'assistant', messageType: _MessageType.info);
      }
    } catch (e) {
      _addMessage('Voice input error: $e',
          role: 'assistant', messageType: _MessageType.error);
    } finally {
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ── Text input ────────────────────────────────────────────────────────────────

  Future<void> _handleTextInput(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;
    if (!await checkQueryLimit(ref)) {
      if (mounted) showUpgradeDialog(context, 'unlimited_voice_queries');
      return;
    }

    _addMessage(text.trim(), role: 'user');
    _textController.clear();
    await _memory.saveTurn(
      userId: _currentUserId(),
      role: 'user',
      text: text.trim(),
      sessionId: _currentSession?.sessionId,
    );
    setState(() => _isProcessing = true);
    try {
      final result = await _orchestrator.processVoiceInteraction(
        userInput: text.trim(),
        userId: _currentUserId(),
        sessionId: _currentSession?.sessionId,
      );
      await _deliverResponse(result);
      await incrementQueryCount(ref);
    } catch (e) {
      _addMessage('Error: $e', role: 'assistant', messageType: _MessageType.error);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deliverResponse(VoiceInteractionResult result) async {
    final type = _messageTypeFor(result.interactionType);
    await _streamMessage(result.systemResponse, messageType: type);

    await _memory.saveTurn(
      userId: _currentUserId(),
      role: 'assistant',
      text: result.systemResponse,
      sessionId: _currentSession?.sessionId,
      interactionType: result.interactionType.name,
    );

    if (result.suggestions.isNotEmpty) {
      final hint = '💡 ${result.suggestions.take(3).map((s) => '• $s').join('\n')}';
      _addMessage(hint, role: 'assistant', messageType: _MessageType.info);
    }
    if (result.requiresClarification && result.ambiguities.isNotEmpty) {
      final clarify = '🤔 ${result.ambiguities.take(2).map((a) => '• ${a.term}: ${a.possibleMeanings.join(", ")}').join('\n')}\n\nKripaya specify kariye!';
      _addMessage(clarify, role: 'assistant', messageType: _MessageType.info);
    }
  }

  // ── Food vision scan ──────────────────────────────────────────────────────────

  Future<void> _openFoodScan() async {
    if (_isScanningFood) return;
    final isPremium = ref.read(isPremiumProvider);
    final scansUsed = 0; // TODO: wire to daily counter from subscriptionStatusProvider

    if (!isPremium && scansUsed >= 3) {
      if (mounted) showUpgradeDialog(context, 'food_vision_unlimited');
      return;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _isScanningFood = true);
    _addMessage('📸 Scanning your food...', role: 'assistant', messageType: _MessageType.info);

    try {
      final bytes = await file.readAsBytes();
      final result = await PerformanceService.traceAsync(
        PerformanceService.kFoodVisionScan,
        () => _foodVision.analyzeFoodImage(
          bytes,
          userId: _currentUserId(),
          confidenceThreshold: 0.75,
        ),
      );

      if (!mounted) return;

      if (result.error != null) {
        _addMessage('Scan failed: ${result.error}',
            role: 'assistant', messageType: _MessageType.error);
        return;
      }

      await FoodConfidenceSheet.show(
        context: context,
        result: result,
        onConfirm: (items) => _logScannedItems(items),
        onRescan: _openFoodScan,
      );
    } catch (e) {
      if (mounted) {
        _addMessage('Scan error: $e', role: 'assistant', messageType: _MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isScanningFood = false);
    }
  }

  void _logScannedItems(List<DetectedFoodItem> items) {
    final names = items.map((i) => i.name).join(', ');
    final summary = 'Logged from photo: $names';
    _addMessage(summary, role: 'user');
    _handleTextInput('Maine khaya: $names');
  }

  // ── Quick actions ─────────────────────────────────────────────────────────────

  Future<void> _handleQuickAction(String prompt) async {
    _textController.text = prompt;
    await _handleTextInput(prompt);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _currentUserId() =>
      ref.read(authStateProvider).asData?.value?.uid ?? 'anonymous';

  _MessageType _messageTypeFor(VoiceInteractionType t) {
    switch (t) {
      case VoiceInteractionType.mealLogging:
        return _MessageType.success;
      case VoiceInteractionType.recommendation:
        return _MessageType.recommendation;
      case VoiceInteractionType.cookingEducation:
        return _MessageType.education;
      case VoiceInteractionType.groceryManagement:
        return _MessageType.grocery;
      case VoiceInteractionType.nutritionQuery:
        return _MessageType.info;
      case VoiceInteractionType.error:
        return _MessageType.error;
      default:
        return _MessageType.normal;
    }
  }

  List<Color> _statusGradient() {
    if (!_isInitialized) return [Colors.orange.shade400, Colors.orange.shade600];
    if (_isListening) return [Colors.red.shade400, Colors.red.shade600];
    if (_isProcessing || _isScanningFood) return [Colors.blue.shade400, Colors.blue.shade600];
    return [Colors.green.shade400, Colors.green.shade600];
  }

  IconData _statusIcon() {
    if (!_isInitialized) return Icons.hourglass_empty;
    if (_isListening) return Icons.mic;
    if (_isProcessing) return Icons.psychology;
    if (_isScanningFood) return Icons.camera_alt;
    return Icons.check_circle;
  }

  String _statusTitle() {
    if (!_isInitialized) return 'Initializing...';
    if (_isListening) return 'Listening...';
    if (_isProcessing) return 'Processing...';
    if (_isScanningFood) return 'Scanning food...';
    return 'Ready to Help!';
  }

  String _statusSubtitle() {
    if (!_isInitialized) return 'Setting up your AI assistant';
    if (_isListening) return 'Speak in Hindi or English';
    if (_isProcessing) return 'Understanding your request';
    if (_isScanningFood) return 'Analyzing your meal photo';
    return 'Tap mic, camera, or type below';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice AI Nutrition'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
            onPressed: () async {
              final uid = _currentUserId();
              await _memory.clearHistory(uid);
              setState(() => _messages.clear());
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          const QueryLimitWarning(),

          // Status bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _statusGradient(),
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: Icon(_statusIcon(), color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_statusTitle(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(_statusSubtitle(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
            ),
          ),

          // Input panel
          _InputPanel(
            controller: _textController,
            isEnabled: _isInitialized && !_isProcessing,
            isListening: _isListening,
            isScanningFood: _isScanningFood,
            pulseAnimation: _pulseAnimation,
            onVoice: _startVoiceInput,
            onScan: _openFoodScan,
            onSend: _handleTextInput,
            onQuickAction: _handleQuickAction,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How to use'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Voice & Text', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('"Maine subah poha khaya"'),
              Text('"Kya khana chahiye weight loss mein?"'),
              Text('"Dal kaise banau healthy?"'),
              SizedBox(height: 14),
              Text('Food Camera', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Tap 📸 to scan a meal and log it instantly with confidence scores.'),
              SizedBox(height: 14),
              Text('Features', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• Hinglish language support'),
              Text('• Conversation history saved'),
              Text('• Personalised to your profile'),
              Text('• Food vision with confidence UI'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// ── Input panel ───────────────────────────────────────────────────────────────

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.controller,
    required this.isEnabled,
    required this.isListening,
    required this.isScanningFood,
    required this.pulseAnimation,
    required this.onVoice,
    required this.onScan,
    required this.onSend,
    required this.onQuickAction,
  });

  final TextEditingController controller;
  final bool isEnabled;
  final bool isListening;
  final bool isScanningFood;
  final Animation<double> pulseAnimation;
  final VoidCallback onVoice;
  final VoidCallback onScan;
  final void Function(String) onSend;
  final void Function(String) onQuickAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick actions
            if (isEnabled && !isListening)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _QuickChip('🍽️ Log meal', 'Maine khaya...', onQuickAction),
                    _QuickChip('💡 Advice', 'Kya khana chahiye...', onQuickAction),
                    _QuickChip('👨‍🍳 Cooking', 'Dal kaise banau...', onQuickAction),
                    _QuickChip('🛒 Grocery', 'Grocery list banao', onQuickAction),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Mic + text field + camera + send
            Row(
              children: [
                // Voice mic
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (_, __) => Transform.scale(
                    scale: isListening ? pulseAnimation.value : 1.0,
                    child: _CircleButton(
                      onTap: isListening || !isEnabled ? null : onVoice,
                      gradient: LinearGradient(
                        colors: isListening
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : [Colors.green.shade400, Colors.green.shade600],
                      ),
                      icon: isListening ? Icons.mic : Icons.mic_none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: controller,
                      enabled: isEnabled,
                      decoration: const InputDecoration(
                        hintText: 'Type in Hindi / English...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        hintStyle: TextStyle(fontSize: 14),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: onSend,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Camera / food scan
                _CircleButton(
                  onTap: isScanningFood || !isEnabled ? null : onScan,
                  gradient: LinearGradient(
                    colors: isScanningFood
                        ? [Colors.blue.shade300, Colors.blue.shade500]
                        : [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  icon: Icons.camera_alt,
                  size: 44,
                ),
                const SizedBox(width: 6),

                // Send
                _CircleButton(
                  onTap: isEnabled ? () => onSend(controller.text) : null,
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade700],
                  ),
                  icon: Icons.send,
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.label, this.prompt, this.onTap);
  final String label;
  final String prompt;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => onTap(prompt),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.onTap,
    required this.gradient,
    required this.icon,
    this.size = 48,
  });

  final VoidCallback? onTap;
  final LinearGradient gradient;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: onTap != null ? gradient : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

// ── Chat data model ───────────────────────────────────────────────────────────

enum _MessageType {
  normal,
  welcome,
  success,
  error,
  info,
  recommendation,
  education,
  grocery,
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.messageType = _MessageType.normal,
    this.isStreaming = false,
  });

  final String text;
  final String role; // 'user' | 'assistant'
  final DateTime timestamp;
  final _MessageType messageType;
  final bool isStreaming;

  bool get isUser => role == 'user';

  _ChatMessage copyWith({String? text, bool? isStreaming}) => _ChatMessage(
        text: text ?? this.text,
        role: role,
        timestamp: timestamp,
        messageType: messageType,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                gradient: _gradient(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser && message.messageType != _MessageType.normal)
                    _TypeBadge(type: message.messageType),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ),
                      if (message.isStreaming) ...[
                        const SizedBox(width: 4),
                        const _TypingCursor(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white60
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }

  LinearGradient _gradient(bool isDark) {
    if (message.isUser) {
      return LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    }
    if (isDark) {
      return LinearGradient(
          colors: [Colors.grey.shade800, Colors.grey.shade900]);
    }
    switch (message.messageType) {
      case _MessageType.welcome:
        return LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100]);
      case _MessageType.success:
        return LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100]);
      case _MessageType.error:
        return LinearGradient(colors: [Colors.red.shade50, Colors.red.shade100]);
      case _MessageType.recommendation:
        return LinearGradient(colors: [Colors.purple.shade50, Colors.purple.shade100]);
      case _MessageType.education:
        return LinearGradient(colors: [Colors.orange.shade50, Colors.orange.shade100]);
      case _MessageType.grocery:
        return LinearGradient(colors: [Colors.teal.shade50, Colors.teal.shade100]);
      default:
        return LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200]);
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isUser});
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUser
              ? [Colors.blue.shade400, Colors.blue.shade600]
              : [Colors.green.shade400, Colors.green.shade600],
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(isUser ? Icons.person : Icons.smart_toy,
          color: Colors.white, size: 18),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final _MessageType type;

  @override
  Widget build(BuildContext context) {
    final info = _info();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(info.$1, size: 13, color: info.$2),
        const SizedBox(width: 4),
        Text(info.$3,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: info.$2)),
      ]),
    );
  }

  (IconData, Color, String) _info() {
    switch (type) {
      case _MessageType.welcome:
        return (Icons.waving_hand, Colors.blue.shade600, 'Welcome');
      case _MessageType.success:
        return (Icons.check_circle, Colors.green.shade600, 'Logged');
      case _MessageType.error:
        return (Icons.error, Colors.red.shade600, 'Error');
      case _MessageType.info:
        return (Icons.info, Colors.blue.shade600, 'Info');
      case _MessageType.recommendation:
        return (Icons.lightbulb, Colors.purple.shade600, 'Recommendation');
      case _MessageType.education:
        return (Icons.school, Colors.orange.shade600, 'Cooking Tips');
      case _MessageType.grocery:
        return (Icons.shopping_cart, Colors.teal.shade600, 'Grocery');
      default:
        return (Icons.chat, Colors.grey.shade600, '');
    }
  }
}

/// Blinking cursor shown while text is streaming in.
class _TypingCursor extends StatefulWidget {
  const _TypingCursor();
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
