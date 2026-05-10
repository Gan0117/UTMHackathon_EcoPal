import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle; 

class ApiService {
  static bool isMockData = false;

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
  // 7. INTERACTIONS
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

  static Future<void> releasePocket(String id, double amountToRelease) async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    final token = _getAuthToken();
    final response = await http.post(
      Uri.parse('$baseUrl/pockets/$id/release'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'amount': amountToRelease})
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
  // 9. HABIT TAX
  // ===========================================================================
  static Future<Map<String, dynamic>> getHabitTax() async {
    if (isMockData) {
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
  // 10. BEHAVIOR ANALYSIS
  // ===========================================================================
  static Future<String> getBehaviorAnalysis() async {
    if (isMockData) {
      return "Your recent grocery run at Market Street was excellent! By choosing seasonal vegetables, you've saved 15% compared to last week.";
    }

    final token = _getAuthToken();
    final response = await http.get(Uri.parse('$baseUrl/ai/behavior'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      // 🔥 FIX: Swapped 'message' to 'analysis' to match Python!
      return jsonDecode(response.body)['analysis'] ?? 'Mochi is still calculating...';
    }
    throw Exception('Backend error');
  }

  // ===========================================================================
  // 11. SAVINGS TIPS (For the Floating Pet)
  // ===========================================================================
  static final List<String> _savingsTips = [
    "Track every expense using a budgeting app or notebook daily.",
    "Cook meals at home instead of ordering food frequently.",
    "Set monthly savings goals and reward yourself responsibly afterward.",
    "Avoid impulse purchases by waiting 24 hours before buying anything.",
    "Use student discounts whenever shopping, dining, or subscribing online.",
    "Bring a reusable water bottle and avoid buying expensive drinks.",
    "Save spare change and small notes in a separate container.",
    "Compare prices online before purchasing gadgets, clothes, or accessories.",
    "Limit entertainment subscriptions and share family plans when possible.",
    "Use public transport or carpool to reduce transportation expenses.",
    "Sedikit-dikit, lama-lama menjadi bukit!",
    "Gong Xi Fa Cai!"
  ];

  static Future<String> getSavingsTip() async {
    if (isMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    // Randomize and return one of the tips
    _savingsTips.shuffle();
    return _savingsTips.first;
  }

  // Send the receipt file to FastAPI for AI Analysis
  static Future<Map<String, dynamic>> scanReceipt(dynamic file) async {
    // 1. Get the Supabase Auth Token so Python doesn't reject us
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null) throw Exception('User not logged in');

    // 2. Set up the URL (Make sure '/scan' matches your Python endpoint!)
    final uri = Uri.parse('$baseUrl/scan');
    
    // 3. Create a "Multipart" request because we are sending a file
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    // 4. Attach the file (Handles both path-based Files and web-based bytes)
    if (file is String) {
      // If the file is passed as a string file path
      request.files.add(await http.MultipartFile.fromPath('file', file));
    } else if (file.path != null) {
      // If the file is passed as an XFile or standard File object
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    } else {
      throw Exception('Unsupported file format sent to scanner');
    }

    // 5. Send it to Python and wait for Gemini to do its magic!
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Backend AI scan failed: ${response.statusCode}');
    }
  }
}