import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';

class ReporterDashboard extends StatefulWidget {
  const ReporterDashboard({super.key});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard> {
  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);

  void _refreshTickets() {
    setState(() {});
  }

  Future<void> _openCreateTicket() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTicketScreen(),
      ),
    );

    _refreshTickets();
  }

  void _openTicketDetails(Ticket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailsScreen(
          id: ticket.id,
          title: ticket.title,
          description: ticket.description,
          category: ticket.category,
          impact: ticket.impact,
          urgency: ticket.urgency,
          device: ticket.device,
          location: ticket.location,
          status: ticket.status,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Ticket> tickets = TicketService.tickets;

    final int totalTickets = TicketService.totalTickets;
    final int openTickets = TicketService.openTickets;
    final int inProgressTickets = TicketService.inProgressTickets;
    final int resolvedTickets = TicketService.resolvedTickets;

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'TriageDesk',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
            tooltip: 'Notifications',
          ),
        ],
      ),

      body: RefreshIndicator(
        color: navy,
        onRefresh: () async {
          _refreshTickets();
        },

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            22,
            20,
            30,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Greeting
              const Text(
                'Hello, Reporter',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Track and manage your IT support requests.',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: 'Total',
                      value: totalTickets.toString(),
                      icon: Icons.confirmation_number_outlined,
                      iconColor: blue,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _summaryCard(
                      title: 'Open',
                      value: openTickets.toString(),
                      icon: Icons.pending_actions_outlined,
                      iconColor: warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: 'In Progress',
                      value: inProgressTickets.toString(),
                      icon: Icons.sync_outlined,
                      iconColor: blue,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _summaryCard(
                      title: 'Resolved',
                      value: resolvedTickets.toString(),
                      icon: Icons.check_circle_outline,
                      iconColor: success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // Create ticket button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openCreateTicket,
                  icon: const Icon(
                    Icons.add_rounded,
                  ),
                  label: const Text(
                    'Create Support Ticket',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // My Tickets heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),

                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Tickets
              if (tickets.isEmpty)
                _emptyTicketsState()
              else
                ...tickets.map(
                  (ticket) => _ticketCard(ticket),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTicketsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),

      child: const Column(
        children: [

          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: textSecondary,
          ),

          SizedBox(height: 14),

          Text(
            'No tickets yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Your submitted support tickets will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(Ticket ticket) {
    final Color statusColor = _statusColor(ticket.status);
    final IconData icon = _categoryIcon(ticket.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        onTap: () {
          _openTicketDetails(ticket);
        },

        child: Padding(
          padding: const EdgeInsets.all(15),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Category icon
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(
                  icon,
                  color: navy,
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              // Ticket information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      ticket.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      ticket.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Row(
                      children: [

                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: Text(
                            ticket.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Real ticket ID
                        Text(
                          ticket.id,
                          style: const TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 5),

              const Icon(
                Icons.chevron_right_rounded,
                color: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return warning;

      case 'In Progress':
        return blue;

      case 'Resolved':
        return success;

      case 'Closed':
        return textSecondary;

      default:
        return textSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Hardware':
        return Icons.devices_outlined;

      case 'Software':
        return Icons.apps_outlined;

      case 'Network':
        return Icons.wifi_rounded;

      case 'Email':
        return Icons.email_outlined;

      case 'Account Access':
        return Icons.lock_outline_rounded;

      case 'Printing':
        return Icons.print_outlined;

      default:
        return Icons.help_outline_rounded;
    }
  }
}