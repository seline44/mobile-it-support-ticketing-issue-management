import 'package:flutter/material.dart';

class TicketDetailsScreen extends StatelessWidget {
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

  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  Color _statusColor() {
    switch (status.toLowerCase()) {
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
    if (impact.toLowerCase() == 'critical' ||
        urgency.toLowerCase() == 'critical') {
      return danger;
    }

    if (urgency.toLowerCase() == 'high') {
      return warning;
    }

    return blue;
  }

  String _calculatedPriority() {
    if (impact.toLowerCase() == 'critical' ||
        urgency.toLowerCase() == 'critical') {
      return 'Critical';
    }

    if (impact.toLowerCase() == 'high' ||
        urgency.toLowerCase() == 'high') {
      return 'High';
    }

    if (impact.toLowerCase() == 'medium' ||
        urgency.toLowerCase() == 'medium') {
      return 'Medium';
    }

    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final priority = _calculatedPriority();
    final priorityColor = _priorityColor();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ticket Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ticket ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                _statusBadge(status, statusColor),
              ],
            ),

            const SizedBox(height: 12),

            // Ticket title
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 10),

            // Category
            Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  category,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Priority card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      color: priorityColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Priority',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          priority,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: blue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Problem description
            _sectionTitle('Problem Description'),

            const SizedBox(height: 10),

            _whiteCard(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Ticket information
            _sectionTitle('Ticket Information'),

            const SizedBox(height: 10),

            _whiteCard(
              child: Column(
                children: [
                  _infoRow(
                    Icons.confirmation_number_outlined,
                    'Ticket ID',
                    id,
                  ),
                  _divider(),
                  _infoRow(
                    Icons.category_outlined,
                    'Category',
                    category,
                  ),
                  _divider(),
                  _infoRow(
                    Icons.speed_outlined,
                    'Impact',
                    impact,
                  ),
                  _divider(),
                  _infoRow(
                    Icons.priority_high_outlined,
                    'Urgency',
                    urgency,
                  ),
                  _divider(),
                  _infoRow(
                    Icons.laptop_mac_outlined,
                    'Device',
                    device,
                  ),
                  _divider(),
                  _infoRow(
                    Icons.location_on_outlined,
                    'Location',
                    location,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Activity
            _sectionTitle('Ticket Activity'),

            const SizedBox(height: 10),

            _whiteCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 18,
                          color: blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket Created',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your support request has been submitted successfully.',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Back button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Back to My Tickets',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(
                    color: navy,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    );
  }

  Widget _whiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 19,
              color: navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}