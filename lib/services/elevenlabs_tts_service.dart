import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../config/api_configuration_manager.dart';
import 'elevenlabs_auth_handler.dart';
import 'elevenlabs_fallback_manager.dart';
import 'retry_manager.dart';

/// Enhanced ElevenLabs TTS Service with proper model support and error handling
class ElevenLabsTtsService {
  static ElevenLabsTtsService? _instance;
  static ElevenLabsTtsService get instance => _instance ??= ElevenLabsTtsService._();
  
  ElevenLabsTtsService._();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  ApiServiceConfig? _config;
  bool _isInitialized = false;
  
  /// Supported ElevenLabs models (updated list)
  static const List<String> supportedModels = [
    'eleven_turbo_v2_5',
    'eleven_turbo_v2',
    'eleven_multilingual_v2',
    'eleven_monolingual_v1', // Keep for fallback compatibility
  ];
  
  /// Default voice IDs for different use cases
  static const Map<String, String> defaultVoices = {
    'rachel': '21m00Tcm4TlvDq8ikWAM', // Professional female voice
    'adam': 'pNInz6obpgDQGcFmaJgB',   // Professional male voice
    'bella': 'EXAVITQu4vr4xnSDxMaL',  // Friendly female voice
    'antoni': 'ErXwobaYiN019PkySvjV', // Friendly male voice
  };
  
  /// Initialize the TTS service
  Future<void> initialize() async {
    try {
      _config = ApiConfigurationManager.instance.getServiceConfig('elevenlabs');
      
      if (_config == null) {
        throw Exception('ElevenLabs configuration not found');
      }
      
      if (!_config!.isEnabled) {
        throw Exception('ElevenLabs service is disabled');
      }
      
      // Initialize authentication handler
      await ElevenLabsAuthHandler.instance.initialize();
      
      // Initialize fallback manager
      await ElevenLabsFallbackManager.instance.initialize();
      
      // Validate authentication
      final authStatus = await ElevenLabsAuthHandler.instance.getAuthStatus();
      if (!authStatus.hasApiKey) {
        throw Exception('ElevenLabs API key is missing');
      }
      
      if (!authStatus.isValidFormat) {
        throw Exception('ElevenLabs API key format is invalid');
      }
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ ElevenLabs TTS Service initialized');
        print('✓ Available models: ${supportedModels.join(', ')}');
        print('✓ Authentication status: ${authStatus.isHealthy ? 'Healthy' : 'Issues detected'}');
        print('✓ Fallback manager ready');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize ElevenLabs TTS Service: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Check if service is ready
  bool get isReady => _isInitialized && _config != null;
  
  /// Get the best available model
  String getBestModel({String? preferredModel}) {
    final configuredModels = _config?.getConfig<List<dynamic>>('supportedModels') ?? supportedModels;
    
    // If preferred model is specified and supported, use it
    if (preferredModel != null && configuredModels.contains(preferredModel)) {
      return preferredModel;
    }
    
    // Otherwise, use the first supported model (most recent/best)
    for (final model in supportedModels) {
      if (configuredModels.contains(model)) {
        return model;
      }
    }
    
    // Fallback to the first configured model
    if (configuredModels.isNotEmpty) {
      return configuredModels.first.toString();
    }
    
    // Last resort fallback
    return supportedModels.first;
  }
  
  /// Check if a model is available
  Future<bool> isModelAvailable(String modelId) async {
    if (!isReady) return false;
    
    try {
      final response = await http.get(
        Uri.parse('${_config!.baseUrl}/models'),
        headers: _config!.headers,
      ).timeout(_config!.timeout);
      
      if (response.statusCode == 200) {
        final models = json.decode(response.body) as List<dynamic>;
        return models.any((model) => model['model_id'] == modelId);
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to check model availability: $e');
      }
      return false;
    }
  }
  
  /// Get available voices
  Future<List<Voice>> getAvailableVoices() async {
    if (!isReady) {
      throw StateError('ElevenLabs TTS Service not initialized');
    }
    
    try {
      final headers = await ElevenLabsAuthHandler.instance.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('${_config!.baseUrl}/voices'),
        headers: headers,
      ).timeout(_config!.timeout);
      
      if (response.statusCode == 200) {
        final voicesData = json.decode(response.body);
        final voicesList = voicesData['voices'] as List<dynamic>;
        
        return voicesList.map((voice) => Voice.fromJson(voice)).toList();
      } else {
        // Handle authentication errors
        final authError = ElevenLabsAuthHandler.instance.handleAuthError(
          response.statusCode, 
          response.body,
        );
        throw ElevenLabsException(authError.message, response.statusCode);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to get available voices: $e');
      }
      rethrow;
    }
  }
  
  /// Synthesize speech from text with fallback support
  Future<dynamic> synthesizeSpeechWithFallback(
    String text, {
    String? voiceId,
    String? modelId,
    VoiceSettings? voiceSettings,
  }) async {
    try {
      // Try primary TTS service first
      final result = await synthesizeSpeech(
        text,
        voiceId: voiceId,
        modelId: modelId,
        voiceSettings: voiceSettings,
      );
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Primary TTS failed, using fallback: $e');
      }
      
      // Use fallback manager
      final fallbackResult = await ElevenLabsFallbackManager.instance.handleTtsFailure(
        text,
        originalError: e is Exception ? e : Exception(e.toString()),
        voiceId: voiceId,
        modelId: modelId,
      );
      
      return fallbackResult;
    }
  }
  
  /// Synthesize speech from text
  Future<TtsResult> synthesizeSpeech(
    String text, {
    String? voiceId,
    String? modelId,
    VoiceSettings? voiceSettings,
  }) async {
    if (!isReady) {
      throw StateError('ElevenLabs TTS Service not initialized');
    }
    
    if (text.isEmpty) {
      throw ArgumentError('Text cannot be empty');
    }
    
    // Use default voice if not specified
    final selectedVoiceId = voiceId ?? 
        _config!.getConfig<String>('defaultVoiceId') ?? 
        defaultVoices['rachel']!;
    
    // Get the best available model
    final selectedModelId = modelId ?? getBestModel();
    
    // Use default voice settings if not specified
    final settings = voiceSettings ?? VoiceSettings.defaultSettings();
    
    try {
      final requestBody = {
        'text': text,
        'model_id': selectedModelId,
        'voice_settings': settings.toJson(),
      };
      
      final response = await _makeRequestWithRetry(
        'POST',
        '${_config!.baseUrl}/text-to-speech/$selectedVoiceId',
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        final base64Audio = base64Encode(audioBytes);
        
        return TtsResult(
          audioBytes: audioBytes,
          base64Audio: base64Audio,
          voiceId: selectedVoiceId,
          modelId: selectedModelId,
          text: text,
        );
      } else {
        throw ElevenLabsException(
          'TTS synthesis failed: ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ TTS synthesis failed: $e');
      }
      rethrow;
    }
  }
  
  /// Make HTTP request with enhanced retry logic
  Future<http.Response> _makeRequestWithRetry(
    String method,
    String url, {
    String? body,
    int? retryCount,
  }) async {
    final maxRetries = retryCount ?? _config!.retryAttempts;
    
    // Create retry configuration based on the type of request
    final retryConfig = RetryConfig(
      maxRetries: maxRetries,
      initialDelay: const Duration(seconds: 1),
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 30),
      shouldRetry: (error) {
        final errorStr = error.toString();
        // Retry on rate limits, server errors, and network issues
        return errorStr.contains('429') ||
               errorStr.contains('5') ||
               errorStr.contains('timeout') ||
               errorStr.contains('connection');
      },
    );
    
    return await RetryManager.instance.executeWithConfig<http.Response>(
      () async {
        // Get fresh authentication headers for each attempt
        final headers = await ElevenLabsAuthHandler.instance.getAuthHeaders();
        
        late http.Response response;
        
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(
              Uri.parse(url),
              headers: headers,
            ).timeout(_config!.timeout);
            break;
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: body,
            ).timeout(_config!.timeout);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }
        
        // Handle authentication errors
        if (response.statusCode == 401 || response.statusCode == 403) {
          final authError = ElevenLabsAuthHandler.instance.handleAuthError(
            response.statusCode, 
            response.body,
          );
          
          if (!authError.isRetryable) {
            throw ElevenLabsException(authError.message, response.statusCode);
          }
          
          // Clear auth cache and let retry manager handle the retry
          ElevenLabsAuthHandler.instance.clearAuthCache();
          throw ElevenLabsException('Authentication failed, retrying', response.statusCode);
        }
        
        // Handle rate limiting
        if (response.statusCode == 429) {
          throw ElevenLabsException('Rate limit exceeded', response.statusCode);
        }
        
        // Handle server errors
        if (response.statusCode >= 500) {
          throw ElevenLabsException('Server error: ${response.statusCode}', response.statusCode);
        }
        
        return response;
      },
      retryConfig,
      onRetry: (attempt, error) {
        if (kDebugMode) {
          print('⚠ ElevenLabs API request failed (attempt $attempt), retrying: $error');
        }
      },
    );
  }
  
  /// Calculate exponential backoff delay
  Duration _calculateBackoffDelay(int attempt) {
    final baseDelay = 1000; // 1 second
    final maxDelay = 30000; // 30 seconds
    final delay = (baseDelay * (1 << attempt)).clamp(baseDelay, maxDelay);
    return Duration(milliseconds: delay);
  }
  
  /// Play audio from TTS result
  Future<void> playAudio(TtsResult ttsResult) async {
    try {
      final audioDataUri = 'data:audio/mpeg;base64,${ttsResult.base64Audio}';
      await _audioPlayer.setUrl(audioDataUri);
      await _audioPlayer.play();
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to play audio: $e');
      }
      rethrow;
    }
  }
  
  /// Stop audio playback
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }
  
  /// Get service status
  ServiceStatus getStatus() {
    return ServiceStatus(
      isInitialized: _isInitialized,
      isReady: isReady,
      hasValidConfig: _config != null,
      hasValidApiKey: _config?.hasValidApiKey ?? false,
      supportedModels: supportedModels,
      currentModel: isReady ? getBestModel() : null,
    );
  }
  
  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
  
  /// Reset service (for testing)
  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _config = null;
  }
}

/// Voice model
class Voice {
  final String voiceId;
  final String name;
  final String category;
  final String description;
  final Map<String, dynamic> settings;
  
  const Voice({
    required this.voiceId,
    required this.name,
    required this.category,
    required this.description,
    required this.settings,
  });
  
  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      voiceId: json['voice_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      settings: json['settings'] as Map<String, dynamic>? ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'voice_id': voiceId,
      'name': name,
      'category': category,
      'description': description,
      'settings': settings,
    };
  }
}

/// Voice settings for TTS
class VoiceSettings {
  final double stability;
  final double similarityBoost;
  final double? style;
  final bool? useSpeakerBoost;
  
  const VoiceSettings({
    required this.stability,
    required this.similarityBoost,
    this.style,
    this.useSpeakerBoost,
  });
  
  factory VoiceSettings.defaultSettings() {
    return const VoiceSettings(
      stability: 0.5,
      similarityBoost: 0.75,
      style: 0.0,
      useSpeakerBoost: true,
    );
  }
  
  factory VoiceSettings.highQuality() {
    return const VoiceSettings(
      stability: 0.71,
      similarityBoost: 0.5,
      style: 0.0,
      useSpeakerBoost: true,
    );
  }
  
  factory VoiceSettings.fast() {
    return const VoiceSettings(
      stability: 0.5,
      similarityBoost: 0.8,
      useSpeakerBoost: false,
    );
  }
  
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'stability': stability,
      'similarity_boost': similarityBoost,
    };
    
    if (style != null) json['style'] = style;
    if (useSpeakerBoost != null) json['use_speaker_boost'] = useSpeakerBoost;
    
    return json;
  }
}

/// TTS synthesis result
class TtsResult {
  final Uint8List audioBytes;
  final String base64Audio;
  final String voiceId;
  final String modelId;
  final String text;
  
  const TtsResult({
    required this.audioBytes,
    required this.base64Audio,
    required this.voiceId,
    required this.modelId,
    required this.text,
  });
  
  /// Get audio data URI for playback
  String get audioDataUri => 'data:audio/mpeg;base64,$base64Audio';
  
  /// Get audio size in bytes
  int get sizeInBytes => audioBytes.length;
  
  /// Get formatted size
  String get formattedSize {
    final kb = sizeInBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Service status information
class ServiceStatus {
  final bool isInitialized;
  final bool isReady;
  final bool hasValidConfig;
  final bool hasValidApiKey;
  final List<String> supportedModels;
  final String? currentModel;
  
  const ServiceStatus({
    required this.isInitialized,
    required this.isReady,
    required this.hasValidConfig,
    required this.hasValidApiKey,
    required this.supportedModels,
    this.currentModel,
  });
  
  bool get isHealthy => isInitialized && isReady && hasValidConfig && hasValidApiKey;
  
  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'isReady': isReady,
      'hasValidConfig': hasValidConfig,
      'hasValidApiKey': hasValidApiKey,
      'supportedModels': supportedModels,
      'currentModel': currentModel,
      'isHealthy': isHealthy,
    };
  }
}

/// ElevenLabs specific exception
class ElevenLabsException implements Exception {
  final String message;
  final int? statusCode;
  
  const ElevenLabsException(this.message, [this.statusCode]);
  
  @override
  String toString() {
    if (statusCode != null) {
      return 'ElevenLabsException($statusCode): $message';
    }
    return 'ElevenLabsException: $message';
  }
}