import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // Replace this with your actual FastAPI backend URL.
  // If running on an Android emulator connecting to local FastAPI, use 'http://10.0.2.2:8000'
  // If running on Web connecting to local FastAPI, use 'http://127.0.0.1:8000'
  static const String baseUrl = 'http://127.0.0.1:8000';

  /// Helper method to get the current Supabase session token
  static String? _getAuthToken() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  /// Calls the /ai/reality-check endpoint on your FastAPI backend
  static Future<String> getRealityCheck() async {
    final token = _getAuthToken();

    if (token == null) {
      throw Exception('User is not logged in.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai/reality-check'), // The FastAPI endpoint[cite: 15]
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Passing the token to FastAPI's HTTPBearer[cite: 15]
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message']; // Returns: "Hello <user_id>, I am analyzing your spending..."[cite: 15]
      } else {
        throw Exception('Backend error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }
}