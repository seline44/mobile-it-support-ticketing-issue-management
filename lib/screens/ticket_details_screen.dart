import 'package:flutter/material.dart';

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
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, String>> _updates = [
    {
      'title': 'Your request has been received',
      'time': 'Today, 10:24 AM',
    },
    {
      'title': 'IT team is investigating the issue',
      'time': 'Today, 11:05 AM',
    },
    {
      'title': 'Still working on it',
      'time': 'Today, 11:45 AM',
    },
  ];

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

  void _addComment() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() {
      _updates.add({
        'title': comment,
        'time': 'Just now',
      });
      _commentController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment added successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                              widget.id.startsWith('#') ? widget.id : '#${widget.id}',
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
                                Text(
                                  '2h ago',
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
                        _metaRow('Category', widget.category, textPrimary, textSecondary),
                        const Divider(height: 20),
                        _metaRow('Priority', priority, priorityColor, textSecondary, isBold: true),
                        const Divider(height: 20),
                        _metaRow('Created', 'Today, 10:24 AM', textPrimary, textSecondary),
                        const Divider(height: 20),
                        _metaRow('Assigned to', 'IT Support Team', textPrimary, textSecondary),
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
                                      border: Border.all(color: blue, width: 2),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
        Text(
          label,
          style: TextStyle(fontSize: 14, color: textSecondary),
        ),
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
