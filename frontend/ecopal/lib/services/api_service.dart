import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle; 

class ApiService {
  // 🔥 THE MASTER TOGGLE 🔥
  static bool isMockData = true;

  static const String baseUrl = 'http://127.0.0.1:8000';

  static String? _getAuthToken() {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  // ===========================================================================
  // 1. AI REALITY CHECK (Insights)
  // ===========================================================================
  static Future<String> getRealityCheck() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/ai_insights.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data[0]['message']; 
    }

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
      final String jsonString = await rootBundle.loadString('assets/backend/data/profiles.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/profile'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 3. POCKETS (Flora/Plants)
  // ===========================================================================
  static Future<List<dynamic>> getPockets() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/pockets.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pockets'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 4. PET STATUS
  // ===========================================================================
  static Future<Map<String, dynamic>> getPetStatus() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/pets.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/pet'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // ===========================================================================
  // 5. TRANSACTIONS
  // ===========================================================================
  static Future<List<dynamic>> getTransactions() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/transactions.json');
      return jsonDecode(jsonString); 
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: {'Authorization': 'Bearer $token'});
    return jsonDecode(response.body);
  }

  // 🔥 Goal 5: Ensure API service handles sending the data to backend
  static Future<void> postTransaction(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Backend error');
  }

  // ===========================================================================
  // 6. UPDATE ACTIONS 
  // ===========================================================================
  static Future<void> updatePetStatus(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pet/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/profile/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  // ===========================================================================
  // 7. INTERACTIONS (Backend-driven calculations)
  // ===========================================================================
  static Future<void> interactWithPet(String action) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pet/interact'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'action': action}),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }
}