import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../voice_first_ai/config.dart';
import 'conversation_context_manager.dart';

/// Voice Interface Layer for handling speech-to-text and text-to-speech
/// Provides seamless voice interaction with sub-3-second response times
class VoiceInterface {
  final String _elevenLabsApiKey;
  final String _voiceId;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ConversationContextManager _contextManager = ConversationContextManager();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isPlaying = false;
  String? _currentSessionId;

  VoiceInterface({
    required String elevenLabsApiKey,
    String? voiceId,
  }) : _elevenLabsApiKey = elevenLabsApiKey,
       _voiceId = voiceId ?? VoiceFirstAIConfig.defaultVoiceId;

  /// Initialize the voice interface
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw Exception('Microphone permission not granted');
      }

      // Initialize speech-to-text
      final sttAvailable = await _speechToText.initialize(
        onError: (error) => print('STT Error: ${error.errorMsg}'),
        onStatus: (status) => print('STT Status: $status'),
      );

      if (!sttAvailable) {
        throw Exception('Speech-to-text not available');
      }

      _isInitialized = true;
      print('Voice interface initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize voice interface: $e');
      return false;
    }
  }

  /// Process voice input and return transcribed text
  Future<String> processVoiceInput(Uint8List audioData) async {
    if (!_isInitialized) {
      throw Exception('Voice interface not initialized');
    }

    try {
      // Save audio data to temporary file
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/temp_audio.wav');
      await audioFile.writeAsBytes(audioData);

      // Use speech-to-text to transcribe
      String transcription = '';
      bool isListening = false;

      await _speechToText.listen(
        onResult: (result) {
          transcription = result.recognizedWords;
          isListening = result.finalResult;
        },
        listenFor: Duration(seconds: VoiceFirstAIConfig.maxRecordingDurationSeconds),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_IN', // Indian English for better Hinglish support
        cancelOnError: true,
      );

      // Wait for transcription to complete
      int attempts = 0;
      while (!isListening && attempts < 30) { // 3 seconds timeout
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      await _speechToText.stop();

      if (transcription.isEmpty) {
        throw Exception('No speech detected or transcription failed');
      }

      return transcription;
    } catch (e) {
      throw Exception('Voice input processing failed: $e');
    }
  }

  /// Record audio from microphone
  Future<Uint8List> recordAudio({int durationSeconds = 5}) async {
    if (!_isInitialized) {
      throw Exception('Voice interface not initialized');
    }

    if (_isListening) {
      throw Exception('Already recording');
    }

    try {
      _isListening = true;
      
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: recordingPath,
      );

      // Record for specified duration
      await Future.delayed(Duration(seconds: durationSeconds));

      // Stop recording
      await _audioRecorder.stop();
      _isListening = false;

      // Read recorded file
      final recordedFile = File(recordingPath);
      if (!await recordedFile.exists()) {
        throw Exception('Recording file not found');
      }

      final audioBytes = await recordedFile.readAsBytes();
      
      // Clean up temporary file
      await recordedFile.delete();

      return audioBytes;
    } catch (e) {
      _isListening = false;
      throw Exception('Audio recording failed: $e');
    }
  }

  /// Listen for voice input with real-time transcription
  Future<String> listenForVoiceInput({int timeoutSeconds = 10}) async {
    if (!_isInitialized) {
      throw Exception('Voice interface not initialized');
    }

    if (_isListening) {
      throw Exception('Already listening');
    }

    try {
      _isListening = true;
      String transcription = '';
      bool isComplete = false;

      await _speechToText.listen(
        onResult: (result) {
          transcription = result.recognizedWords;
          isComplete = result.finalResult;
        },
        listenFor: Duration(seconds: timeoutSeconds),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: 'en_IN', // Indian English for Hinglish support
        cancelOnError: true,
      );

      // Wait for final result or timeout
      int attempts = 0;
      final maxAttempts = timeoutSeconds * 10; // 100ms intervals
      
      while (!isComplete && attempts < maxAttempts && _speechToText.isListening) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      await _speechToText.stop();
      _isListening = false;

      if (transcription.isEmpty) {
        throw Exception('No speech detected');
      }

      return transcription;
    } catch (e) {
      _isListening = false;
      throw Exception('Voice listening failed: $e');
    }
  }

  /// Generate voice response from text using ElevenLabs
  Future<Uint8List> generateVoiceResponse(String text) async {
    if (text.isEmpty) {
      throw Exception('Text cannot be empty');
    }

    try {
      final url = Uri.parse('${VoiceFirstAIConfig.elevenLabsApiUrl}/text-to-speech/$_voiceId');
      
      final requestBody = {
        'text': text,
        'model_id': 'eleven_monolingual_v1',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true,
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Accept': 'audio/mpeg',
          'Content-Type': 'application/json',
          'xi-api-key': _elevenLabsApiKey,
        },
        body: jsonEncode(requestBody),
      ).timeout(Duration(milliseconds: VoiceFirstAIConfig.voiceResponseTimeoutMs));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('ElevenLabs API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Voice generation failed: $e');
    }
  }

  /// Play audio from bytes
  Future<void> playAudio(Uint8List audioBytes) async {
    if (_isPlaying) {
      await stopAudio();
    }

    try {
      _isPlaying = true;
      
      // Save audio to temporary file
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/temp_playback_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await audioFile.writeAsBytes(audioBytes);

      // Play audio file
      await _audioPlayer.setFilePath(audioFile.path);
      await _audioPlayer.play();

      // Wait for playback to complete
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          // Clean up temporary file
          audioFile.delete().catchError((e) => print('Failed to delete temp file: $e'));
        }
      });
    } catch (e) {
      _isPlaying = false;
      throw Exception('Audio playback failed: $e');
    }
  }

  /// Stop current audio playback
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  /// Start a conversation stream with context management
  Stream<VoiceInteraction> startConversation({String? userId, Map<String, dynamic>? initialContext}) async* {
    _currentSessionId = _contextManager.startSession(
      userId: userId,
      initialContext: initialContext,
    );
    
    while (true) {
      try {
        // Listen for user input
        final userInput = await listenForVoiceInput();
        
        if (userInput.isNotEmpty) {
          // Create conversation turn
          final turn = ConversationTurn(
            turnId: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            userInput: userInput,
            systemResponse: '', // Will be filled by higher-level services
            type: _determineConversationTurnType(userInput),
            metadata: {'confidence': 0.8}, // Placeholder confidence
          );

          // Add turn to context
          _contextManager.addConversationTurn(_currentSessionId!, turn);

          yield VoiceInteraction(
            sessionId: _currentSessionId!,
            timestamp: DateTime.now(),
            userInput: userInput,
            systemResponse: '', // Will be filled by higher-level services
            type: _determineInteractionType(userInput),
            context: _contextManager.getContext(_currentSessionId!)?.toJson() ?? {},
          );
        }
      } catch (e) {
        print('Conversation stream error: $e');
        // Continue listening despite errors
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Handle conversation interruption with context preservation
  void handleInterruption({String? reason}) {
    try {
      if (_isListening) {
        _speechToText.stop();
        _isListening = false;
      }
      
      if (_isPlaying) {
        _audioPlayer.stop();
        _isPlaying = false;
      }

      if (_currentSessionId != null) {
        _contextManager.handleInterruption(_currentSessionId!, reason: reason);
      }
      
      print('Voice interaction interrupted: ${reason ?? 'unknown reason'}');
    } catch (e) {
      print('Error handling interruption: $e');
    }
  }

  /// Resume interrupted conversation
  Future<String> resumeConversation() async {
    if (_currentSessionId == null) {
      throw Exception('No active session to resume');
    }

    try {
      final resumptionMessage = _contextManager.resumeConversation(_currentSessionId!);
      
      // Generate and play resumption audio
      final audioBytes = await generateVoiceResponse(resumptionMessage);
      await playAudio(audioBytes);
      
      return resumptionMessage;
    } catch (e) {
      throw Exception('Failed to resume conversation: $e');
    }
  }

  /// Generate contextual voice response
  Future<String> generateContextualResponse(String userInput, String baseResponse) async {
    if (_currentSessionId == null) {
      return baseResponse;
    }

    return _contextManager.generateContextualResponse(_currentSessionId!, userInput, baseResponse);
  }

  /// Add meal context to current conversation
  void addMealContext(Map<String, dynamic> mealData) {
    if (_currentSessionId != null) {
      _contextManager.addMealToContext(_currentSessionId!, mealData);
    }
  }

  /// Update user preferences in conversation context
  void updateUserPreferences(Map<String, dynamic> preferences) {
    if (_currentSessionId != null) {
      _contextManager.updateUserPreferences(_currentSessionId!, preferences);
    }
  }

  /// Get conversation context
  ConversationContext? getConversationContext() {
    if (_currentSessionId == null) return null;
    return _contextManager.getContext(_currentSessionId!);
  }

  /// Get conversation history
  List<ConversationTurn> getConversationHistory() {
    if (_currentSessionId == null) return [];
    return _contextManager.getConversationHistory(_currentSessionId!);
  }

  /// End current conversation session
  void endConversation() {
    if (_currentSessionId != null) {
      _contextManager.endSession(_currentSessionId!);
      _currentSessionId = null;
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if currently playing audio
  bool get isPlaying => _isPlaying;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Test ElevenLabs API connection
  Future<bool> testElevenLabsConnection() async {
    try {
      final url = Uri.parse('${VoiceFirstAIConfig.elevenLabsApiUrl}/voices');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'xi-api-key': _elevenLabsApiKey,
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('ElevenLabs connection test failed: $e');
      return false;
    }
  }

  /// Get available voices from ElevenLabs
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    try {
      final url = Uri.parse('${VoiceFirstAIConfig.elevenLabsApiUrl}/voices');
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'xi-api-key': _elevenLabsApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices'] ?? []);
      } else {
        throw Exception('Failed to get voices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting available voices: $e');
      return [];
    }
  }

  /// Dispose of resources
  void dispose() {
    try {
      _speechToText.stop();
      _audioPlayer.dispose();
      _audioRecorder.dispose();
      _contextManager.dispose();
      _isInitialized = false;
      _isListening = false;
      _isPlaying = false;
      print('Voice interface disposed');
    } catch (e) {
      print('Error disposing voice interface: $e');
    }
  }

  // Private helper methods

  ConversationTurnType _determineConversationTurnType(String userInput) {
    final lowerInput = userInput.toLowerCase();
    
    if (lowerInput.contains('hello') || lowerInput.contains('namaste') || lowerInput.contains('hi')) {
      return ConversationTurnType.greeting;
    } else if (lowerInput.contains('bye') || lowerInput.contains('goodbye') || lowerInput.contains('alvida')) {
      return ConversationTurnType.farewell;
    } else if (lowerInput.contains('khaya') || lowerInput.contains('eaten') || lowerInput.contains('meal')) {
      return ConversationTurnType.mealLogging;
    } else if (lowerInput.contains('suggest') || lowerInput.contains('recommend') || lowerInput.contains('batao')) {
      return ConversationTurnType.recommendation;
    } else if (lowerInput.contains('what') || lowerInput.contains('kya') || lowerInput.contains('how')) {
      return ConversationTurnType.clarification;
    } else {
      return ConversationTurnType.nutritionQuery;
    }
  }

  InteractionType _determineInteractionType(String userInput) {
    final turnType = _determineConversationTurnType(userInput);
    
    switch (turnType) {
      case ConversationTurnType.mealLogging:
        return InteractionType.mealLogging;
      case ConversationTurnType.recommendation:
        return InteractionType.recommendation;
      case ConversationTurnType.clarification:
        return InteractionType.clarification;
      default:
        return InteractionType.nutritionQuery;
    }
  }
}

/// Represents a voice interaction in the conversation
class VoiceInteraction {
  final String sessionId;
  final DateTime timestamp;
  final String userInput;
  final String systemResponse;
  final InteractionType type;
  final Map<String, dynamic> context;

  VoiceInteraction({
    required this.sessionId,
    required this.timestamp,
    required this.userInput,
    required this.systemResponse,
    required this.type,
    required this.context,
  });
}

enum InteractionType {
  mealLogging,
  nutritionQuery,
  recommendation,
  clarification,
}