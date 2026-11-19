import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';
import '../config/service_config.dart';
import '../models/voice_models.dart';

/// Service for Google Cloud Text-to-Speech API integration
class GCPTTSService {
  final _logger = Logger('GCPTTSService');
  final ServiceConfig _config = ServiceConfig.instance;
  
  AutoRefreshingAuthClient? _authClient;
  
  /// Initialize the TTS service with authentication
  Future<void> initialize() async {
    try {
      final credentials = _config.serviceAccountCredentials;
      if (credentials != null) {
        final accountCredentials = ServiceAccountCredentials.fromJson(credentials);
        _authClient = await clientViaServiceAccount(
          accountCredentials,
          ['https://www.googleapis.com/auth/cloud-platform'],
        );
        _logger.info('GCP TTS service initialized with service account');
      } else {
        _logger.warning('No service account credentials found, using default credentials');
        // In production, this would use Application Default Credentials
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize GCP TTS service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Convert text to speech using GCP Text-to-Speech API
  Future<TextToSpeechResponse> textToSpeech(TextToSpeechRequest request) async {
    try {
      final apiUrl = '${_config.getApiEndpoint('texttospeech')}/text:synthesize';
      
      // Build the request payload for GCP API
      final payload = {
        'input': {
          'text': request.text,
        },
        'voice': {
          'languageCode': request.languageCode ?? _config.ttsConfig['languageCode'],
          'name': request.voiceName ?? _config.ttsConfig['voiceName'],
        },
        'audioConfig': {
          'audioEncoding': _getAudioEncoding(request.audioEncoding ?? _config.ttsConfig['audioEncoding']),
          'speakingRate': request.speakingRate ?? _config.ttsConfig['speakingRate'],
          'pitch': request.pitch ?? _config.ttsConfig['pitch'],
          'volumeGainDb': request.volumeGainDb ?? _config.ttsConfig['volumeGainDb'],
        },
      };
      
      final response = await _makeAuthenticatedRequest(apiUrl, payload);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseGCPTTSResponse(responseData, request.audioEncoding ?? _config.ttsConfig['audioEncoding']);
      } else {
        final errorMessage = 'Text-to-Speech API error: ${response.statusCode} ${response.body}';
        _logger.warning(errorMessage);
        return TextToSpeechResponse(
          error: errorMessage,
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Text-to-Speech processing failed: $e', e, stackTrace);
      return TextToSpeechResponse(
        error: 'TTS processing failed: $e',
      );
    }
  }
  
  /// Convert text to speech with language-specific voice selection
  Future<TextToSpeechResponse> textToSpeechWithLanguage(String text, String languageCode) async {
    final voiceName = _getVoiceForLanguage(languageCode);
    
    final request = TextToSpeechRequest(
      text: text,
      languageCode: languageCode,
      voiceName: voiceName,
    );
    
    return await textToSpeech(request);
  }
  
  /// Get available voices for a language
  Future<List<Map<String, dynamic>>> getAvailableVoices(String languageCode) async {
    try {
      final apiUrl = '${_config.getApiEndpoint('texttospeech')}/voices';
      
      final response = await _makeAuthenticatedRequest(apiUrl, {});
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final voices = responseData['voices'] as List<dynamic>? ?? [];
        
        // Filter voices by language code
        return voices
            .cast<Map<String, dynamic>>()
            .where((voice) {
              final voiceLanguageCodes = voice['languageCodes'] as List<dynamic>? ?? [];
              return voiceLanguageCodes.contains(languageCode);
            })
            .toList();
      } else {
        _logger.warning('Failed to get available voices: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to get available voices: $e', e, stackTrace);
      return [];
    }
  }
  
  /// Parse GCP TTS API response
  TextToSpeechResponse _parseGCPTTSResponse(Map<String, dynamic> responseData, String audioEncoding) {
    final audioContent = responseData['audioContent'] as String?;
    
    if (audioContent != null) {
      // Calculate approximate audio length (this is a rough estimate)
      final audioBytes = base64Decode(audioContent);
      final audioLength = audioBytes.length;
      
      return TextToSpeechResponse(
        audioContent: audioContent,
        audioEncoding: audioEncoding,
        audioLength: audioLength,
      );
    } else {
      return TextToSpeechResponse(
        error: 'No audio content in response',
      );
    }
  }
  
  /// Get GCP audio encoding format
  String _getAudioEncoding(String encoding) {
    switch (encoding.toUpperCase()) {
      case 'MP3':
        return 'MP3';
      case 'WAV':
        return 'LINEAR16';
      case 'OGG':
        return 'OGG_OPUS';
      case 'WEBM':
        return 'WEBM_OPUS';
      default:
        return 'MP3'; // Default to MP3
    }
  }
  
  /// Get appropriate voice for a language
  String _getVoiceForLanguage(String languageCode) {
    // Map of language codes to preferred voices
    final voiceMap = {
      'en-US': 'en-US-Neural2-F',
      'en-GB': 'en-GB-Neural2-A',
      'hi-IN': 'hi-IN-Neural2-A',
      'es-ES': 'es-ES-Neural2-A',
      'fr-FR': 'fr-FR-Neural2-A',
      'de-DE': 'de-DE-Neural2-A',
      'it-IT': 'it-IT-Neural2-A',
      'pt-BR': 'pt-BR-Neural2-A',
      'zh-CN': 'zh-CN-Neural2-A',
    };
    
    return voiceMap[languageCode] ?? voiceMap['en-US']!;
  }
  
  /// Make authenticated HTTP request to GCP API
  Future<http.Response> _makeAuthenticatedRequest(String url, Map<String, dynamic> payload) async {
    if (_authClient != null) {
      if (payload.isEmpty) {
        // GET request for voices
        return await _authClient!.get(Uri.parse(url));
      } else {
        // POST request for synthesis
        return await _authClient!.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );
      }
    } else {
      // Fallback for development/testing
      _logger.warning('Making unauthenticated request (development mode)');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer mock-token-for-development',
      };
      
      if (payload.isEmpty) {
        return http.get(Uri.parse(url), headers: headers);
      } else {
        return http.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(payload),
        );
      }
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _authClient?.close();
  }
}