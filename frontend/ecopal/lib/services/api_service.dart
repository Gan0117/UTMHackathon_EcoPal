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

  static Future<void> createPocket(Map<String, dynamic> data) async {
  if (isMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    return;
  }
  final token = _getAuthToken();
  final response = await http.post(
    Uri.parse('$baseUrl/pockets'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode(data),
  );
  if (response.statusCode != 200 && response.statusCode != 201) throw Exception('Backend error');
}

static Future<void> updatePocket(String id, Map<String, dynamic> data) async {
  if (isMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    return;
  }
  final token = _getAuthToken();
  final response = await http.put(
    Uri.parse('$baseUrl/pockets/$id'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode(data),
  );
  if (response.statusCode != 200) throw Exception('Backend error');
}

static Future<void> deletePocket(String id) async {
  if (isMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    return;
  }
  final token = _getAuthToken();
  final response = await http.delete(
    Uri.parse('$baseUrl/pockets/$id'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200 && response.statusCode != 204) throw Exception('Backend error');
}

  // ===========================================================================
  // 8. SAFE TO SPEND BALANCE
  // ===========================================================================
  static Future<double> getSafeToSpendBalance() async {
    if (isMockData) {
      final String jsonString = await rootBundle.loadString('assets/backend/data/profiles.json');
      final data = jsonDecode(jsonString);
      return (data['safe_to_spend_balance'] as num).toDouble();
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['safe_to_spend_balance'] as num).toDouble();
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

// ===========================================================================
  // 9. HABIT TAX (AI INSIGHTS)
  // ===========================================================================
  static Future<Map<String, dynamic>> getHabitTax() async {
    if (isMockData) {
      // Return mock data matching the required schema
      final String jsonString = await rootBundle.loadString('assets/backend/data/habit_tax.json');
      final data = jsonDecode(jsonString);
      return data;
    }

    final token = _getAuthToken();
    if (token == null) throw Exception('User is not logged in.');

    final response = await http.get(
      Uri.parse('$baseUrl/habit-tax'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Backend error: ${response.statusCode}');
    }
  }

  static Future<void> updateHabitTax(bool isAvailable) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return; 
    }
    
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/habit-tax/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({"available": isAvailable}),
    );
    if (response.statusCode != 200) throw Exception('Backend error');
  }

  // ===========================================================================
  // 10. BEHAVIOR ANALYSIS (Specific Insight for the Chart)
  // ===========================================================================
  static Future<String> getBehaviorAnalysis() async {
    if (isMockData) {
      return "Your recent grocery run at Market Street was excellent! By choosing seasonal vegetables, you've saved 15% compared to last week.";
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/ai/behavior'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['message'];
    }
    throw Exception('Backend error');
  }
}