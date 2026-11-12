import 'dart:convert';

import 'package:http/http.dart' as http;
import 'offline_sync_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mobile-it-support-ticketing-issue.onrender.com',
  );

  static String? _accessToken;
  static Map<String, dynamic>? _currentUser;

  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get accessToken => _accessToken;
  static String get currentUserName {
    final fullName = _currentUser?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final email = currentUserEmail;
    if (email.contains('@')) return email.split('@').first;

    return _currentUser?['role']?.toString() ?? 'User';
  }

  static String get currentUserEmail =>
      _currentUser?['email']?.toString().trim() ?? '';

  static String get currentUserInitials {
    final fullName = _currentUser?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName
          .split(RegExp(r'\s+'))
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join();
    }

    final email = currentUserEmail;
    return email.isNotEmpty ? email[0].toUpperCase() : 'TD';
  }

  static void logout() {
    _accessToken = null;
    _currentUser = null;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
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
      body: jsonEncode({'email': email.trim(), 'password': password}),
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tickets'),
        headers: _headers,
      );

      final decoded = _decode(response);
      if (response.statusCode == 200 && decoded is List) {
        await OfflineSyncService.cacheTickets(decoded);
        return decoded;
      }
      throw Exception(_error(decoded, 'Could not load tickets'));
    } catch (error) {
      final cached = await OfflineSyncService.getCachedTickets();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getTicketNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tickets/notifications'),
      headers: _headers,
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load ticket notifications'));
  }

  static Future<List<dynamic>> getTicketHistory(int ticketId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tickets/$ticketId/history'),
      headers: _headers,
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load ticket activity'));
  }

  static Future<List<dynamic>> getTicketNotes(int ticketId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tickets/$ticketId/notes'),
      headers: _headers,
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load ticket notes'));
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
    String? note,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (resolution != null) body['resolution'] = resolution;
    if (note != null) body['note'] = note;

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
    bool? isInternal,
  }) async {
    final body = <String, dynamic>{'note': note};
    if (isInternal != null) body['is_internal'] = isInternal;
    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/notes'),
      headers: _headers,
      body: jsonEncode(body),
    );

    final decoded = _decode(response);
    if ((response.statusCode == 201 || response.statusCode == 200) &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not save technician note'));
  }

  static Future<Map<String, dynamic>> reopenTicket({
    required int ticketId,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/reopen'),
      headers: _headers,
      body: jsonEncode({'reason': reason.trim()}),
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not reopen ticket'));
  }

  static Future<List<dynamic>> getWhatsAppTicketNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/notifications/whatsapp'),
      headers: _headers,
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) return decoded;
    throw Exception(_error(decoded, 'Could not load WhatsApp notifications'));
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

  static Future<Map<String, dynamic>> deleteUser({required int userId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/users/$userId'),
      headers: _headers,
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not delete user'));
  }

  static Future<Map<String, dynamic>> updateUserActiveStatus({
    required int userId,
    required bool isActive,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/active'),
      headers: _headers,
      body: jsonEncode({'is_active': isActive}),
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not update account status'));
  }

  static Future<Map<String, dynamic>> linkWhatsAppNumber({
    required int userId,
    required String phoneNumber,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/users/$userId/whatsapp'),
      headers: _headers,
      body: jsonEncode({'phone_number': phoneNumber.trim()}),
    );

    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw Exception(_error(decoded, 'Could not link WhatsApp number'));
  }

  static Future<String> forgotPassword({required String email}) async {
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
