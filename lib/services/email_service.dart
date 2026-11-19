import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for sending emails using Resend API.
///
/// The Resend API key must be injected at build time:
///   flutter build apk --dart-define=RESEND_API_KEY=re_xxxx
/// or stored in flutter_secure_storage via SecureKeyManager.storeApiKey('resend', key).
class EmailService {
  static const String _baseUrl = 'https://api.resend.com';

  // Injected at build time via --dart-define=RESEND_API_KEY=...
  // Never hardcode a real key here.
  static const String _apiKey = String.fromEnvironment('RESEND_API_KEY');

  bool get _isConfigured => _apiKey.isNotEmpty;

  /// Send a welcome email to new users
  Future<bool> sendWelcomeEmail({
    required String toEmail,
    required String userName,
  }) async {
    if (!_isConfigured) {
      if (kDebugMode) print('⚠ EmailService: RESEND_API_KEY not set, skipping email.');
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'NutriSync <noreply@nutrisync.app>',
          'to': [toEmail],
          'subject': 'Welcome to NutriSync - Your AI Nutrition Assistant!',
          'html': _getWelcomeEmailHtml(userName),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending welcome email: $e');
      return false;
    }
  }

  /// Send meal plan email to users
  Future<bool> sendMealPlanEmail({
    required String toEmail,
    required String userName,
    required Map<String, dynamic> mealPlan,
  }) async {
    if (!_isConfigured) {
      if (kDebugMode) print('⚠ EmailService: RESEND_API_KEY not set, skipping email.');
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/emails'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'NutriSync <noreply@nutrisync.app>',
          'to': [toEmail],
          'subject': 'Your Personalized Meal Plan from NutriSync',
          'html': _getMealPlanEmailHtml(userName, mealPlan),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending meal plan email: $e');
      return false;
    }
  }

  /// Send grocery list email to users
  Future<bool> sendGroceryListEmail({
    required String toEmail,
    required String userName,
    required List<Map<String, dynamic>> groceryItems,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}/send-grocery-list'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'toEmail': toEmail,
          'userName': userName,
          'groceryItems': groceryItems,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending grocery list email: $e');
      return false;
    }
  }
}