import 'dart:typed_data';
import 'voice_interface.dart';

/// Example usage of the VoiceInterface
/// Demonstrates how to use the voice interface for Indian food context
class VoiceInterfaceExample {
  late VoiceInterface _voiceInterface;
  bool _isInitialized = false;

  /// Initialize the voice interface with API key
  Future<bool> initialize(String elevenLabsApiKey) async {
    try {
      _voiceInterface = VoiceInterface(elevenLabsApiKey: elevenLabsApiKey);
      _isInitialized = await _voiceInterface.initialize();
      
      if (_isInitialized) {
        print('✅ Voice interface initialized successfully');
        
        // Test API connection
        final connectionOk = await _voiceInterface.testElevenLabsConnection();
        print('🔗 ElevenLabs connection: ${connectionOk ? 'OK' : 'Failed'}');
        
        return true;
      } else {
        print('❌ Failed to initialize voice interface');
        return false;
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      return false;
    }
  }

  /// Demonstrate basic voice input/output
  Future<void> demonstrateBasicVoiceIO() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Basic Voice Input/Output Demo ===');
    
    try {
      // Test text-to-speech with Indian food context
      const hinglishText = 'Namaste! Aaj aapne kya khaya? Please tell me about your meal in Hindi or English.';
      print('🔊 Converting text to speech: "$hinglishText"');
      
      final audioBytes = await _voiceInterface.generateVoiceResponse(hinglishText);
      print('✅ Generated ${audioBytes.length} bytes of audio');
      
      // Play the generated audio
      print('🎵 Playing generated audio...');
      await _voiceInterface.playAudio(audioBytes);
      
      // Wait for playback to complete
      while (_voiceInterface.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      print('✅ Audio playback completed');
      
    } catch (e) {
      print('❌ Basic voice I/O error: $e');
    }
  }

  /// Demonstrate voice recording and transcription
  Future<void> demonstrateVoiceRecording() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Voice Recording Demo ===');
    
    try {
      print('🎤 Starting 3-second recording...');
      print('💬 Please say something about your meal (in Hindi or English)');
      
      final audioData = await _voiceInterface.recordAudio(durationSeconds: 3);
      print('✅ Recorded ${audioData.length} bytes of audio');
      
      print('🔄 Processing voice input...');
      final transcription = await _voiceInterface.processVoiceInput(audioData);
      print('📝 Transcription: "$transcription"');
      
    } catch (e) {
      print('❌ Voice recording error: $e');
    }
  }

  /// Demonstrate real-time voice listening
  Future<void> demonstrateRealTimeListening() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Real-time Voice Listening Demo ===');
    
    try {
      print('👂 Listening for voice input (10 seconds timeout)...');
      print('💬 Please describe your meal in Hindi or English');
      
      final transcription = await _voiceInterface.listenForVoiceInput(timeoutSeconds: 10);
      print('📝 You said: "$transcription"');
      
      // Generate a response
      final response = _generateFoodResponse(transcription);
      print('🤖 AI Response: "$response"');
      
      // Convert response to speech
      final responseAudio = await _voiceInterface.generateVoiceResponse(response);
      print('🔊 Playing AI response...');
      await _voiceInterface.playAudio(responseAudio);
      
    } catch (e) {
      print('❌ Real-time listening error: $e');
    }
  }

  /// Demonstrate conversation flow
  Future<void> demonstrateConversation() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Conversation Flow Demo ===');
    
    try {
      print('💬 Starting conversation about Indian food...');
      
      // Initial greeting
      const greeting = 'Hello! I am your AI nutrition assistant. Aap kya khana chahte hain? What would you like to eat today?';
      final greetingAudio = await _voiceInterface.generateVoiceResponse(greeting);
      await _voiceInterface.playAudio(greetingAudio);
      
      // Wait for playback to complete
      while (_voiceInterface.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Listen for user response
      print('👂 Listening for your food preference...');
      final userInput = await _voiceInterface.listenForVoiceInput(timeoutSeconds: 8);
      print('📝 User input: "$userInput"');
      
      // Generate contextual response
      final response = _generateNutritionAdvice(userInput);
      print('🤖 Nutrition advice: "$response"');
      
      // Speak the response
      final responseAudio = await _voiceInterface.generateVoiceResponse(response);
      await _voiceInterface.playAudio(responseAudio);
      
    } catch (e) {
      print('❌ Conversation error: $e');
    }
  }

  /// Demonstrate interruption handling
  Future<void> demonstrateInterruption() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Interruption Handling Demo ===');
    
    try {
      // Start a long audio playback
      const longText = 'This is a long message about Indian nutrition. Dal is very healthy and provides protein. Rice gives you energy. Vegetables provide vitamins and minerals. Roti is made from wheat and gives fiber.';
      
      print('🔊 Starting long audio playback...');
      final audioBytes = await _voiceInterface.generateVoiceResponse(longText);
      
      // Start playback (non-blocking)
      _voiceInterface.playAudio(audioBytes);
      
      // Wait a bit, then interrupt
      await Future.delayed(const Duration(seconds: 2));
      print('⏹️ Interrupting playback...');
      _voiceInterface.handleInterruption();
      
      print('✅ Interruption handled successfully');
      
    } catch (e) {
      print('❌ Interruption demo error: $e');
    }
  }

  /// Demonstrate error handling
  Future<void> demonstrateErrorHandling() async {
    print('\n=== Error Handling Demo ===');
    
    try {
      // Test with invalid audio data
      print('🧪 Testing with invalid audio data...');
      final invalidAudio = Uint8List.fromList([255, 255, 255]);
      
      try {
        await _voiceInterface.processVoiceInput(invalidAudio);
      } catch (e) {
        print('✅ Caught expected error: ${e.toString().substring(0, 50)}...');
      }
      
      // Test with empty text
      print('🧪 Testing with empty text...');
      try {
        await _voiceInterface.generateVoiceResponse('');
      } catch (e) {
        print('✅ Caught expected error: ${e.toString().substring(0, 50)}...');
      }
      
    } catch (e) {
      print('❌ Error handling demo error: $e');
    }
  }

  /// Get available voices from ElevenLabs
  Future<void> demonstrateVoiceSelection() async {
    if (!_isInitialized) {
      print('❌ Voice interface not initialized');
      return;
    }

    print('\n=== Voice Selection Demo ===');
    
    try {
      print('🎭 Getting available voices...');
      final voices = await _voiceInterface.getAvailableVoices();
      
      if (voices.isNotEmpty) {
        print('✅ Found ${voices.length} available voices:');
        for (int i = 0; i < voices.length && i < 5; i++) {
          final voice = voices[i];
          print('  ${i + 1}. ${voice['name']} (${voice['voice_id']})');
        }
      } else {
        print('⚠️ No voices available (check API key)');
      }
      
    } catch (e) {
      print('❌ Voice selection error: $e');
    }
  }

  /// Run all demonstrations
  Future<void> runAllDemonstrations(String elevenLabsApiKey) async {
    print('🎤 Voice Interface Demonstration 🎤\n');
    
    // Initialize
    final initialized = await initialize(elevenLabsApiKey);
    if (!initialized) {
      print('❌ Cannot run demonstrations without proper initialization');
      return;
    }
    
    // Run demonstrations
    await demonstrateBasicVoiceIO();
    await demonstrateVoiceRecording();
    await demonstrateRealTimeListening();
    await demonstrateConversation();
    await demonstrateInterruption();
    await demonstrateErrorHandling();
    await demonstrateVoiceSelection();
    
    // Cleanup
    _voiceInterface.dispose();
    print('\n✅ All voice interface demonstrations completed!');
  }

  /// Generate a simple food response
  String _generateFoodResponse(String userInput) {
    final input = userInput.toLowerCase();
    
    if (input.contains('dal') || input.contains('lentil')) {
      return 'Dal is excellent! It provides protein and fiber. Ek katori dal mein around 120 calories hain.';
    } else if (input.contains('rice') || input.contains('chawal')) {
      return 'Rice gives you energy! Ek katori rice mein around 130 calories hain. Vegetables ke saath khayiye.';
    } else if (input.contains('roti') || input.contains('chapati')) {
      return 'Roti is very healthy! Ek roti mein around 80 calories hain. Sabzi ke saath perfect combination hai.';
    } else if (input.contains('curry') || input.contains('sabzi')) {
      return 'Vegetables are full of vitamins! Sabzi mein fiber aur nutrients hote hain. Very good choice!';
    } else {
      return 'That sounds delicious! Kya aap mujhe aur details bata sakte hain? Please tell me more about your meal.';
    }
  }

  /// Generate nutrition advice based on user input
  String _generateNutritionAdvice(String userInput) {
    final input = userInput.toLowerCase();
    
    if (input.contains('hungry') || input.contains('bhookh')) {
      return 'Agar bhookh lagi hai, toh dal-chawal ya roti-sabzi try kariye. Balanced meal hai aur healthy bhi!';
    } else if (input.contains('weight') || input.contains('vajan')) {
      return 'Weight management ke liye vegetables aur dal zyada khayiye. Rice kam kariye aur roti prefer kariye.';
    } else if (input.contains('energy') || input.contains('shakti')) {
      return 'Energy ke liye complex carbs chahiye. Brown rice, whole wheat roti, aur fruits khayiye.';
    } else {
      return 'Aapka choice achha hai! Balanced nutrition ke liye protein, carbs, aur vegetables include kariye. Kya aur help chahiye?';
    }
  }
}