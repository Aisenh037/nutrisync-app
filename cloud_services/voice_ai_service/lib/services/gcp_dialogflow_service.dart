import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../models/voice_models.dart';

/// GCP Dialogflow service for conversation management and intent recognition
class GCPDialogflowService {
  final _logger = Logger('GCPDialogflowService');
  
  String? _projectId;
  String? _sessionId;
  String? _accessToken;
  String? _agentId;
  
  /// Initialize the Dialogflow service
  Future<void> initialize() async {
    try {
      _projectId = Platform.environment['GCP_PROJECT_ID'] ?? 'nutrisync-dev';
      _agentId = Platform.environment['DIALOGFLOW_AGENT_ID'] ?? 'nutrisync-agent-dev';
      
      // Get access token for authentication
      await _getAccessToken();
      
      _logger.info('Dialogflow service initialized for project: $_projectId');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Dialogflow service: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Detect intent from text input
  Future<DialogflowResponse> detectIntent(DialogflowRequest request) async {
    try {
      if (_projectId == null || _accessToken == null) {
        throw Exception('Dialogflow service not initialized');
      }
      
      final sessionPath = 'projects/$_projectId/locations/global/agents/$_agentId/sessions/${request.sessionId}';
      final url = 'https://dialogflow.googleapis.com/v3/$sessionPath:detectIntent';
      
      final requestBody = {
        'queryInput': {
          'text': {
            'text': request.text,
          },
          'languageCode': request.languageCode ?? 'en-US',
        },
        'queryParams': {
          'timeZone': 'Asia/Kolkata',
          if (request.context != null) 'parameters': request.context,
        },
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return _parseDialogflowResponse(responseData, request.sessionId);
      } else {
        _logger.warning('Dialogflow API error: ${response.statusCode} ${response.body}');
        return _createFallbackResponse(request.text, request.sessionId);
      }
    } catch (e, stackTrace) {
      _logger.severe('Intent detection failed: $e', e, stackTrace);
      return _createFallbackResponse(request.text, request.sessionId);
    }
  }
  
  /// Create conversation context for maintaining session state
  Future<ConversationContext> createContext(String sessionId, Map<String, dynamic> parameters) async {
    try {
      if (_projectId == null || _accessToken == null) {
        throw Exception('Dialogflow service not initialized');
      }
      
      final contextName = 'projects/$_projectId/locations/global/agents/$_agentId/sessions/$sessionId/contexts/nutrition-context';
      final url = 'https://dialogflow.googleapis.com/v3/$contextName';
      
      final requestBody = {
        'name': contextName,
        'lifespanCount': 5, // Context lasts for 5 conversation turns
        'parameters': parameters,
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return ConversationContext.fromJson(responseData);
      } else {
        _logger.warning('Failed to create context: ${response.statusCode} ${response.body}');
        return ConversationContext(
          name: contextName,
          lifespanCount: 5,
          parameters: parameters,
        );
      }
    } catch (e, stackTrace) {
      _logger.severe('Context creation failed: $e', e, stackTrace);
      return ConversationContext(
        name: 'fallback-context',
        lifespanCount: 5,
        parameters: parameters,
      );
    }
  }
  
  /// Get conversation context
  Future<ConversationContext?> getContext(String sessionId, String contextName) async {
    try {
      if (_projectId == null || _accessToken == null) {
        return null;
      }
      
      final fullContextName = 'projects/$_projectId/locations/global/agents/$_agentId/sessions/$sessionId/contexts/$contextName';
      final url = 'https://dialogflow.googleapis.com/v3/$fullContextName';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        return ConversationContext.fromJson(responseData);
      } else {
        return null;
      }
    } catch (e) {
      _logger.warning('Failed to get context: $e');
      return null;
    }
  }
  
  /// Update conversation context
  Future<ConversationContext> updateContext(String sessionId, String contextName, Map<String, dynamic> parameters) async {
    try {
      final existingContext = await getContext(sessionId, contextName);
      
      if (existingContext != null) {
        // Merge parameters
        final mergedParameters = <String, dynamic>{
          ...existingContext.parameters,
          ...parameters,
        };
        
        return await createContext(sessionId, mergedParameters);
      } else {
        return await createContext(sessionId, parameters);
      }
    } catch (e) {
      _logger.warning('Failed to update context: $e');
      return ConversationContext(
        name: contextName,
        lifespanCount: 5,
        parameters: parameters,
      );
    }
  }
  
  /// Get access token for Dialogflow API
  Future<void> _getAccessToken() async {
    try {
      // In production, this would use service account authentication
      // For development, we'll use a mock token or environment variable
      _accessToken = Platform.environment['DIALOGFLOW_ACCESS_TOKEN'] ?? 'mock-token';
      
      if (_accessToken == 'mock-token') {
        _logger.warning('Using mock access token for Dialogflow. Set DIALOGFLOW_ACCESS_TOKEN environment variable for production.');
      }
    } catch (e) {
      _logger.warning('Failed to get access token: $e');
      _accessToken = 'mock-token';
    }
  }
  
  /// Parse Dialogflow API response
  DialogflowResponse _parseDialogflowResponse(Map<String, dynamic> responseData, String sessionId) {
    try {
      final queryResult = responseData['queryResult'] as Map<String, dynamic>? ?? {};
      
      final intent = queryResult['intent'] as Map<String, dynamic>?;
      final intentName = intent?['displayName'] as String? ?? 'Default Fallback Intent';
      
      final fulfillmentMessages = queryResult['responseMessages'] as List<dynamic>? ?? [];
      String responseText = '';
      
      if (fulfillmentMessages.isNotEmpty) {
        final firstMessage = fulfillmentMessages.first as Map<String, dynamic>;
        final textMessage = firstMessage['text'] as Map<String, dynamic>?;
        final textList = textMessage?['text'] as List<dynamic>? ?? [];
        
        if (textList.isNotEmpty) {
          responseText = textList.first as String;
        }
      }
      
      final parameters = queryResult['parameters'] as Map<String, dynamic>? ?? {};
      final confidence = (queryResult['intentDetectionConfidence'] as num?)?.toDouble() ?? 0.0;
      
      return DialogflowResponse(
        sessionId: sessionId,
        intentName: intentName,
        responseText: responseText.isEmpty ? _getDefaultResponse(intentName) : responseText,
        parameters: parameters,
        confidence: confidence,
        fulfillmentText: queryResult['fulfillmentText'] as String? ?? responseText,
      );
    } catch (e) {
      _logger.warning('Failed to parse Dialogflow response: $e');
      return _createFallbackResponse('', sessionId);
    }
  }
  
  /// Create fallback response when Dialogflow is unavailable
  DialogflowResponse _createFallbackResponse(String originalText, String sessionId) {
    return DialogflowResponse(
      sessionId: sessionId,
      intentName: 'fallback.intent',
      responseText: _getContextualFallbackResponse(originalText),
      parameters: {},
      confidence: 0.5,
      fulfillmentText: 'Main aapka sawal samajh nahi paya. Kripaya phir se try kariye.',
    );
  }
  
  /// Get default response based on intent name
  String _getDefaultResponse(String intentName) {
    switch (intentName.toLowerCase()) {
      case 'meal.logging':
      case 'food.intake':
        return 'Accha! Aapka meal log ho gaya hai. Nutrition details calculate kar raha hun.';
      
      case 'nutrition.inquiry':
      case 'calorie.check':
        return 'Nutrition ke baare mein jaanna chahte hain? Main aapko detail mein bata sakta hun.';
      
      case 'recommendation.request':
      case 'meal.suggestion':
        return 'Main aapke liye healthy meal suggestions de sakta hun. Kya preference hai?';
      
      case 'greeting':
      case 'welcome':
        return 'Namaste! Main aapka nutrition assistant hun. Kaise help kar sakta hun?';
      
      default:
        return 'Main aapka nutrition assistant hun. Meal logging, nutrition advice, ya recommendations ke liye puchiye!';
    }
  }
  
  /// Get contextual fallback response based on input text
  String _getContextualFallbackResponse(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('khaya') || lowerText.contains('eaten') || lowerText.contains('food')) {
      return 'Kya khaya aapne? Thoda detail mein batayiye taaki main nutrition track kar sakun.';
    } else if (lowerText.contains('calories') || lowerText.contains('nutrition')) {
      return 'Nutrition ke baare mein kya jaanna chahte hain? Specific food ya general advice?';
    } else if (lowerText.contains('suggest') || lowerText.contains('recommend')) {
      return 'Kya type ka recommendation chahiye? Breakfast, lunch, dinner, ya snacks?';
    } else {
      return 'Main aapka nutrition assistant hun. Aap meal log kar sakte hain, nutrition puch sakte hain, ya recommendations le sakte hain. Kya help chahiye?';
    }
  }
  
  /// Dispose of resources
  void dispose() {
    // Clean up any resources if needed
    _logger.info('Dialogflow service disposed');
  }
}