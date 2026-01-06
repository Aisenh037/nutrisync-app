import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';

class ElevenLabsAgentService {
  final String apiKey;
  final String agentId; // Your Eleven Labs agent ID
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _conversationId; // To maintain ongoing conversation

  ElevenLabsAgentService({required this.apiKey, required this.agentId});

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> listenAndTranscribe() async {
    if (!await requestMicrophonePermission()) return null;

    bool available = await _speech.initialize();
    if (!available) return null;

    String? recognizedText;
    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
      },
    );

    // Wait for a short time or until silence
    await Future.delayed(const Duration(seconds: 5));
    _speech.stop();

    return recognizedText;
  }

  Future<Map<String, dynamic>?> sendMessage(String message, UserModel? user, Position? location) async {
    // Build context from user data for mock AI response
    String context = '';
    if (user != null) {
      context += 'Name: ${user.name}, Dietary Needs: ${user.dietaryNeeds.join(', ')}, Health Goals: ${user.healthGoals.join(', ')}. ';
    }
    if (location != null) {
      context += 'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}. ';
    }

    // Mock AI response based on message (replace with real AI integration if needed)
    String responseText = 'Based on your profile ($context) and query "$message", I recommend a balanced meal like a salad with proteins and veggies for nutrition. Stay hydrated!';
    if (message.toLowerCase().contains('breakfast')) {
      responseText = 'For breakfast, try oatmeal with fruits and nuts. It\'s high in fiber and energy.';
    } else if (message.toLowerCase().contains('lunch')) {
      responseText = 'For lunch, a grilled chicken salad with olive oil dressing would be great for your goals.';
    } // Add more logic as needed

    // Use ElevenLabs TTS for audio
    const voiceId = '21m00Tcm4TlvDq8ikWAM'; // Default voice ID (Rachel)
    final ttsUrl = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId');

    final ttsBody = jsonEncode({
      'text': responseText,
      'model_id': 'eleven_monolingual_v1',
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.75,
      },
    });

    final ttsResponse = await http.post(
      ttsUrl,
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: ttsBody,
    );

    if (ttsResponse.statusCode == 200) {
      final audioBytes = ttsResponse.bodyBytes;
      final base64Audio = base64Encode(audioBytes);
      final audioDataUri = 'data:audio/mpeg;base64,$base64Audio';

      _conversationId ??= DateTime.now().millisecondsSinceEpoch.toString(); // Simple conversation ID

      return {
        'text': responseText,
        'audio_url': audioDataUri,
      };
    } else {
      print('TTS Error: ${ttsResponse.statusCode} - ${ttsResponse.body}');
      // Fallback to text-only response
      return {
        'text': responseText,
        'audio_url': null,
      };
    }
  }

  Future<void> playAudio(String audioUrl) async {
    await _audioPlayer.setUrl(audioUrl);
    await _audioPlayer.play();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
