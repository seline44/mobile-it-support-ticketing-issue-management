import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() =>
      _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  // ============================================================
  // TRIAGEDESK COLORS
  // Same visual system used by Reporter Dashboard
  // ============================================================

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

  void _openTicket(Ticket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ManageTicketSheet(
          ticket: ticket,
          onUpdated: _refreshTickets,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Ticket> tickets = TicketService.tickets;

    final int openTickets = TicketService.openTickets;
    final int inProgressTickets = TicketService.inProgressTickets;
    final int resolvedTickets = TicketService.resolvedTickets;

    final int urgentTickets = tickets.where((ticket) {
      return ticket.priority == 'High' ||
          ticket.priority == 'Critical';
    }).length;

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

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

              // ==================================================
              // GREETING
              // ==================================================

              const Text(
                'Hello, Technician',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'View, manage and resolve support tickets.',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // SUMMARY CARDS
              // Same structure as Reporter Dashboard
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: 'Open',
                      value: openTickets.toString(),
                      icon: Icons.pending_actions_outlined,
                      iconColor: warning,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _summaryCard(
                      title: 'Urgent',
                      value: urgentTickets.toString(),
                      icon: Icons.priority_high_rounded,
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

              const SizedBox(height: 30),

              // ==================================================
              // SUPPORT TICKETS HEADING
              // ==================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Support Tickets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),

                  Text(
                    '${tickets.length} tickets',
                    style: const TextStyle(
                      color: blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ==================================================
              // TICKETS
              // ==================================================

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

  // ============================================================
  // SUMMARY CARD
  // Matches Reporter Dashboard
  // ============================================================

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

  // ============================================================
  // TICKET CARD
  // Matches Reporter Dashboard
  // ============================================================

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
          _openTicket(ticket);
        },

        child: Padding(
          padding: const EdgeInsets.all(15),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // CATEGORY ICON
              // ==================================================

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

              // ==================================================
              // TICKET INFORMATION
              // ==================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[

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
                            borderRadius:
                                BorderRadius.circular(20),
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

                        // Ticket ID
                        Text(
                          ticket.id,
                          style: const TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        // Priority
                        Text(
                          ticket.priority,
                          style: TextStyle(
                            fontSize: 11,
                            color: _priorityColor(
                              ticket.priority,
                            ),
                            fontWeight: FontWeight.w600,
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

  // ============================================================
  // EMPTY STATE
  // ============================================================

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
            'No support tickets',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'New tickets submitted by reporters will appear here.',
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

  // ============================================================
  // STATUS COLOR
  // Same system as Reporter Dashboard
  // ============================================================

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

  // ============================================================
  // PRIORITY COLOR
  // ============================================================

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC2626);

      case 'High':
        return warning;

      case 'Medium':
        return blue;

      case 'Low':
        return textSecondary;

      default:
        return textSecondary;
    }
  }

  // ============================================================
  // CATEGORY ICON
  // ============================================================

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


// ================================================================
// MANAGE TICKET SHEET
// ================================================================

class _ManageTicketSheet extends StatefulWidget {
  final Ticket ticket;
  final VoidCallback onUpdated;

  const _ManageTicketSheet({
    required this.ticket,
    required this.onUpdated,
  });

  @override
  State<_ManageTicketSheet> createState() =>
      _ManageTicketSheetState();
}

class _ManageTicketSheetState
    extends State<_ManageTicketSheet> {

  // Same colors as Reporter Dashboard
  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);

  final String technicianName = 'Technician';

  late TextEditingController _notesController;
  late TextEditingController _resolutionController;

  @override
  void initState() {
    super.initState();

    _notesController = TextEditingController(
      text: widget.ticket.technicianNotes ?? '',
    );

    _resolutionController = TextEditingController(
      text: widget.ticket.resolution ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),

        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + 18,
          ),

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ==================================================
                // HANDLE
                // ==================================================

                Center(
                  child: Container(
                    width: 42,
                    height: 4,

                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // HEADER
                // ==================================================

                Row(
                  children: [

                    Container(
                      width: 44,
                      height: 44,

                      decoration: BoxDecoration(
                        color:
                            navy.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons.assignment_outlined,
                        color: navy,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Manage Ticket',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 3),

                          Text(
                            'Review and update this support request.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ==================================================
                // TICKET SUMMARY
                // ==================================================

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),

                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.025),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,

                        children: [

                          Text(
                            ticket.id,
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          _sheetStatusBadge(
                            ticket.status,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        ticket.title,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,

                        children: [
                          _detailChip(
                            Icons.category_outlined,
                            ticket.category,
                          ),

                          _detailChip(
                            Icons.priority_high_rounded,
                            ticket.priority,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // TICKET INFORMATION
                // ==================================================

                _sectionTitle(
                  'Ticket Information',
                  Icons.info_outline,
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),

                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),

                  child: Column(
                    children: [

                      _infoRow(
                        'Impact',
                        ticket.impact,
                      ),

                      _infoRow(
                        'Urgency',
                        ticket.urgency,
                      ),

                      _infoRow(
                        'Device',
                        ticket.device,
                      ),

                      _infoRow(
                        'Location',
                        ticket.location,
                      ),

                      _infoRow(
                        'Assigned Technician',
                        ticket.assignedTechnician ??
                            'Not assigned',
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                _sectionTitle(
                  'Problem Description',
                  Icons.description_outlined,
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),

                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),

                  child: Text(
                    ticket.description,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // ACCEPT TICKET
                // ==================================================

                if (ticket.status == 'Open')
                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton.icon(
                      onPressed: () {
                        final success =
                            TicketService.acceptTicket(
                          ticket.id,
                          technicianName,
                        );

                        if (success) {
                          setState(() {});
                          widget.onUpdated();

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Ticket accepted successfully.',
                              ),
                            ),
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),

                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),

                      label: const Text(
                        'Accept Ticket',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ==================================================
                // STATUS
                // ==================================================

                if (ticket.status == 'In Progress') ...[

                  const SizedBox(height: 4),

                  _sectionTitle(
                    'Ticket Status',
                    Icons.sync_outlined,
                  ),

                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),

                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    child:
                        DropdownButtonFormField<String>(
                      initialValue: ticket.status,

                      decoration:
                          const InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text('In Progress'),
                        ),

                        DropdownMenuItem(
                          value: 'Resolved',
                          child: Text('Resolved'),
                        ),
                      ],

                      onChanged: (value) {
                        if (value == null) return;

                        TicketService.updateStatus(
                          ticket.id,
                          value,
                        );

                        setState(() {});
                        widget.onUpdated();
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // ==================================================
                // TECHNICIAN NOTES
                // ==================================================

                _sectionTitle(
                  'Technician Notes',
                  Icons.note_alt_outlined,
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _notesController,
                  maxLines: 4,

                  decoration: InputDecoration(
                    hintText:
                        'Enter notes about the troubleshooting performed...',

                    hintStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: const BorderSide(
                        color: navy,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 48,

                  child: OutlinedButton(
                    onPressed: () {
                      if (_notesController.text
                          .trim()
                          .isEmpty) {
                        return;
                      }

                      TicketService.addTechnicianNote(
                        ticket.id,
                        _notesController.text.trim(),
                      );

                      setState(() {});
                      widget.onUpdated();

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Technician note saved.',
                          ),
                        ),
                      );
                    },

                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,

                      side: const BorderSide(
                        color: navy,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),

                    child: const Text(
                      'Save Technician Note',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ==================================================
                // RESOLUTION
                // ==================================================

                _sectionTitle(
                  'Resolution',
                  Icons.task_alt_outlined,
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _resolutionController,
                  maxLines: 4,

                  decoration: InputDecoration(
                    hintText:
                        'Describe how the issue was resolved...',

                    hintStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(14),

                      borderSide: const BorderSide(
                        color: navy,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // RESOLVE
                // ==================================================

                if (ticket.status != 'Resolved')
                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_resolutionController.text
                            .trim()
                            .isEmpty) {
                          return;
                        }

                        TicketService.addResolution(
                          ticket.id,
                          _resolutionController.text.trim(),
                        );

                        setState(() {});
                        widget.onUpdated();

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ticket resolved successfully.',
                            ),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),

                      icon: const Icon(
                        Icons.check_circle_outline,
                      ),

                      label: const Text(
                        'Resolve Ticket',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ==================================================
                // REOPEN
                // ==================================================

                if (ticket.status == 'Resolved')
                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: OutlinedButton.icon(
                      onPressed: () {
                        TicketService.reopenTicket(
                          ticket.id,
                        );

                        setState(() {});
                        widget.onUpdated();

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ticket reopened.',
                            ),
                          ),
                        );
                      },

                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,

                        side: const BorderSide(
                          color: navy,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),

                      icon: const Icon(
                        Icons.refresh,
                      ),

                      label: const Text(
                        'Reopen Ticket',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: navy,
          size: 19,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 12,
        top: 4,
      ),

      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 4,
      ),

      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                ),
              ),
            ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 145,

            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL CHIP
  // ============================================================

  Widget _detailChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 14,
            color: textSecondary,
          ),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHEET STATUS BADGE
  // Same status colors as Reporter Dashboard
  // ============================================================

  Widget _sheetStatusBadge(String status) {
    Color color;

    switch (status) {
      case 'Open':
        color = warning;
        break;

      case 'In Progress':
        color = blue;
        break;

      case 'Resolved':
        color = success;
        break;

      case 'Closed':
        color = textSecondary;
        break;

      default:
        color = textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}