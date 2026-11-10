import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncService {
  static const String _ticketsKey = 'cached_tickets';
  static const String _outboxKey = 'pending_outbox_actions';

  // Save tickets locally
  static Future<void> cacheTickets(List<dynamic> tickets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ticketsKey, jsonEncode(tickets));
    } catch (_) {}
  }

  // Load cached tickets when offline
  static Future<List<dynamic>> getCachedTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_ticketsKey);
      if (raw == null) return [];
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // Queue a write action if offline
  static Future<void> queueAction(String type, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_outboxKey) ?? [];
      queue.add(jsonEncode({
        'type': type,
        'data': data,
        'time': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList(_outboxKey, queue);
    } catch (_) {}
  }

  // Get pending outbox actions count
  static Future<int> getPendingActionsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_outboxKey) ?? [];
      return queue.length;
    } catch (_) {
      return 0;
    }
  }
}
