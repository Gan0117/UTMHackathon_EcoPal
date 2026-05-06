import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle; // Required to load local JSON files

class ApiService {
  // 🔥 THE MASTER TOGGLE 🔥
  // Set to true to load from local JSON files. Set to false to use the FastAPI backend.
  static bool isMockData = false;

  static const String baseUrl = 'http://127.0.0.1:8000';

  /// Helper method to get the current Supabase session token
  static String? _getAuthToken() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  // ===========================================================================
  // 1. AI REALITY CHECK (Insights)
  // ===========================================================================
  static Future<String> getRealityCheck() async {
    if (isMockData) {
      // Load mock data
      final String jsonString = await rootBundle.loadString('assets/backend/ai_insights.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data[0]['message']; // Return the first warning message as a test
    }

    // Load real data[cite: 17]
    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/ai/reality-check'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  // ===========================================================================
  // 2. PROFILE DATA
  // ===========================================================================
  static Future<Map<String, dynamic>> getProfile() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/profiles.json');
      return jsonDecode(jsonString); // Returns the profile object[cite: 16]
    }

    // REAL DATA IMPLEMENTATION (To be connected later)
    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 3. POCKETS (Flora/Plants)
  // ===========================================================================
  static Future<List<dynamic>> getPockets() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/pockets.json');
      return jsonDecode(jsonString); // Returns the list of pockets[cite: 16]
    }

    // REAL DATA IMPLEMENTATION (To be connected later)
    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pockets'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 4. PET STATUS
  // ===========================================================================
  static Future<Map<String, dynamic>> getPetStatus() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/pets.json');
      return jsonDecode(jsonString); // Returns the pet object[cite: 16]
    }

    // REAL DATA IMPLEMENTATION (To be connected later)
    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pet'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 5. TRANSACTIONS
  // ===========================================================================
  static Future<List<dynamic>> getTransactions() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/transactions.json');
      return jsonDecode(jsonString); // Returns list of transactions[cite: 16]
    }

    // REAL DATA IMPLEMENTATION (To be connected later)
    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }
}