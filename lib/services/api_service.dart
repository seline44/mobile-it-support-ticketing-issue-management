
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator address for a backend running on your Windows PC.
  static const String baseUrl = 'http://127.0.0.1:8000';

  static String? _accessToken;

  static String? get accessToken => _accessToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null)
          'Authorization': 'Bearer $_accessToken',
      };

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(decoded);
      _accessToken = data['access_token'] as String?;
      return data;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Login failed'
        : 'Login failed';

    throw Exception(message);
  }


  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(decoded);
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Registration failed'
        : 'Registration failed';

    throw Exception(message);
  }



  static Future<List<dynamic>> getTickets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tickets'),
      headers: _headers,
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is List) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Could not load tickets'
        : 'Could not load tickets';

    throw Exception(message);
  }

  static Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    required String category,
    required String impact,
    required String urgency,
    String device = '',
    String location = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tickets'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'impact': impact,
        'urgency': urgency,
        'device': device,
        'location': location,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded);
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Could not create ticket'
        : 'Could not create ticket';

    throw Exception(message);
  }

  
  static Future<List<dynamic>> getPendingUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users/pending'),
      headers: _headers,
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is List) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Could not load pending users'
        : 'Could not load pending users';

    throw Exception(message);
  }

  static Future<Map<String, dynamic>> updateUserApproval({
    required int userId,
    required String approvalStatus,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/approval'),
      headers: _headers,
      body: jsonEncode({
        'approval_status': approvalStatus,
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        decoded is Map<String, dynamic>) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ?? 'Could not update account'
        : 'Could not update account';

    throw Exception(message);
  }

  

static Future<List<dynamic>> getAllUsers() async {
  final response = await http.get(
    Uri.parse('$baseUrl/admin/users'),
    headers: _headers,
  );

  final dynamic decoded = jsonDecode(response.body);

  if (response.statusCode == 200 && decoded is List) {
    return decoded;
  }

  final message = decoded is Map<String, dynamic>
      ? decoded['detail']?.toString() ?? 'Could not load users'
      : 'Could not load users';

  throw Exception(message);
}

  static Future<String> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
      }),
    );

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        decoded is Map<String, dynamic>) {
      return decoded['message']?.toString() ??
          'If an eligible account exists, a reset link will be sent.';
    }

    final message = decoded is Map<String, dynamic>
        ? decoded['detail']?.toString() ??
            'Could not process the password-reset request.'
        : 'Could not process the password-reset request.';

    throw Exception(message);
  }


}
