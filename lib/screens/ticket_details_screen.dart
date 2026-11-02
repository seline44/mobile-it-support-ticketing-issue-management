import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TicketDetailsScreen extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final String category;
  final String impact;
  final String urgency;
  final String device;
  final String location;
  final String status;
  final DateTime? lastModifiedAt;

  const TicketDetailsScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.impact,
    required this.urgency,
    required this.device,
    required this.location,
    required this.status,
    this.lastModifiedAt,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _updates = [];
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;
  static const Color danger = Color(0xFFDC2626);

  Color _statusColor() {
    switch (widget.status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return success;
      case 'in progress':
        return blue;
      case 'open':
      default:
        return warning;
    }
  }

  Color _priorityColor() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return danger;
    }
    if (widget.urgency.toLowerCase() == 'high' ||
        widget.impact.toLowerCase() == 'high') {
      return warning;
    }
    return blue;
  }

  String _calculatedPriority() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return 'Critical';
    }
    if (widget.impact.toLowerCase() == 'high' ||
        widget.urgency.toLowerCase() == 'high') {
      return 'High';
    }
    if (widget.impact.toLowerCase() == 'medium' ||
        widget.urgency.toLowerCase() == 'medium') {
      return 'Medium';
    }
    return 'Low';
  }

  IconData _categoryIcon() {
    switch (widget.category.toLowerCase()) {
      case 'hardware':
        return Icons.devices_outlined;
      case 'software':
        return Icons.apps_outlined;
      case 'network':
        return Icons.wifi_rounded;
      case 'email':
        return Icons.email_outlined;
      case 'account access':
        return Icons.lock_outline_rounded;
      case 'printer':
      case 'printing':
        return Icons.print_outlined;
      default:
        return Icons.laptop_mac_outlined;
    }
  }

  Future<void> _loadHistory() async {
    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      setState(() {
        _historyError = 'Ticket activity is unavailable for this ticket ID.';
        _isLoadingHistory = false;
      });
      return;
    }

    try {
      final history = await ApiService.getTicketHistory(ticketId);
      if (!mounted) return;
      setState(() {
        _updates
          ..clear()
          ..addAll(
            history.whereType<Map>().map((item) {
              final entry = Map<String, dynamic>.from(item);
              final actor = entry['actor_name']?.toString();
              final action = entry['action']?.toString() ?? 'Ticket updated';
              final details = entry['details']?.toString();
              final title = [
                if (actor != null && actor.isNotEmpty) '$actor: ',
                action,
                if (details != null && details.isNotEmpty) ' - $details',
              ].join();
              final createdAt = DateTime.parse(entry['created_at'].toString());
              return {'title': title, 'time': _formatHistoryTime(createdAt)};
            }),
          );
        _historyError = null;
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  String _formatHistoryTime(DateTime createdAt) {
    final date = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final time = TimeOfDay.fromDateTime(date).format(context);
    if (dateOnly == today) return 'Today, $time';
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${date.month}/${date.day}/${date.year}, $time';
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this ticket.')),
      );
      return;
    }
    try {
      await ApiService.addTicketNote(ticketId: ticketId, note: comment);
      if (!mounted) return;
      _commentController.clear();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add comment: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;

    final statusColor = _statusColor();
    final priority = _calculatedPriority();
    final priorityColor = _priorityColor();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Options',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_categoryIcon(), color: blue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.id.startsWith('#')
                                  ? widget.id
                                  : '#${widget.id}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                if (widget.lastModifiedAt != null)
                                  Text(
                                    _formatHistoryTime(widget.lastModifiedAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Metadata Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _metaRow(
                          'Category',
                          widget.category,
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Priority',
                          priority,
                          priorityColor,
                          textSecondary,
                          isBold: true,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Created',
                          'Today, 10:24 AM',
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Assigned to',
                          'IT Support Team',
                          textPrimary,
                          textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Updates Timeline Section
                  Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingHistory)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_historyError != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  _historyError!,
                                  style: TextStyle(color: textSecondary),
                                ),
                                TextButton(
                                  onPressed: _loadHistory,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_updates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No activity recorded yet.',
                              style: TextStyle(color: textSecondary),
                            ),
                          )
                        else
                          for (int i = 0; i < _updates.length; i++)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: blue.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: blue,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < _updates.length - 1)
                                      Container(
                                        width: 2,
                                        height: 38,
                                        color: blue.withValues(alpha: 0.3),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _updates[i]['title']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _updates[i]['time']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Comment & Send Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: blue, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: blue,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _addComment,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(
    String label,
    String value,
    Color valueColor,
    Color textSecondary, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
