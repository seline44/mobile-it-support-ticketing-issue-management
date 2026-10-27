
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);


  static String? _accessToken;
  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get accessToken => _accessToken;

  static void logout() {
    _accessToken = null;
    _currentUser = null;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null)
          'Authorization': 'Bearer $_accessToken',
      };

  static dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _error(dynamic decoded, String fallback) {
    if (decoded is Map) {
      return decoded['detail']?.toString() ?? fallback;
    }
    return fallback;
  }

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

    final decoded = _decode(response);

    if (response.statusCode == 200 && decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);
      _accessToken = data['access_token']?.toString();

      if (data['user'] is Map) {
        _currentUser = Map<String, dynamic>.from(data['user']);
      }
      return data;
    }

    throw Exception(_error(decoded, 'Login failed'));
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

    final decoded = _decode(response);
    if ((response.statusCode == 201 || response.statusCode == 200) &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Registration failed'));
  }

  static Future<List<dynamic>> getTickets() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tickets'),
      headers: _headers,
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) {
      return decoded;
    }
    throw Exception(_error(decoded, 'Could not load tickets'));
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

    final decoded = _decode(response);
    if ((response.statusCode == 201 || response.statusCode == 200) &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not create ticket'));
  }

  static Future<Map<String, dynamic>> acceptTicket(int ticketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/accept'),
      headers: _headers,
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not accept ticket'));
  }

  static Future<Map<String, dynamic>> updateTicketStatus({
    required int ticketId,
    required String status,
    String? resolution,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (resolution != null) body['resolution'] = resolution;

    final response = await http.patch(
      Uri.parse('$baseUrl/tickets/$ticketId/status'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not update ticket status'));
  }

  static Future<Map<String, dynamic>> addTicketNote({
    required int ticketId,
    required String note,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/notes'),
      headers: _headers,
      body: jsonEncode({'note': note}),
    );

    final decoded = _decode(response);
    if ((response.statusCode == 201 || response.statusCode == 200) &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not save technician note'));
  }

  static Future<Map<String, dynamic>> reopenTicket(int ticketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/reopen'),
      headers: _headers,
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not reopen ticket'));
  }

  static Future<List<dynamic>> getPendingUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users/pending'),
      headers: _headers,
    );
    final decoded = _decode(response);

    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load pending users'));
  }

  static Future<Map<String, dynamic>> updateUserApproval({
    required int userId,
    required String approvalStatus,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/approval'),
      headers: _headers,
      body: jsonEncode({'approval_status': approvalStatus}),
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not update account'));
  }

  static Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: _headers,
    );
    final decoded = _decode(response);

    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load users'));
  }

  static Future<String> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return decoded['message']?.toString() ??
          'If an eligible account exists, a reset link will be sent.';
    }
    throw Exception(_error(decoded, 'Could not process password reset'));
  }
}
