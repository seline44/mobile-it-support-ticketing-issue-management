import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/celebration_dialog.dart';
import '../widgets/triagedesk_logo.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  static const Color navy = AppTheme.charcoal;
  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;

  List<Ticket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshTickets();
  }

  Future<void> _refreshTickets() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await ApiService.getTickets();
      final tickets = data
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int get _openCount => _tickets.where((t) => t.status == 'Open').length;

  int get _progressCount =>
      _tickets.where((t) => t.status == 'In Progress').length;

  int get _resolvedCount =>
      _tickets.where((t) => t.status == 'Resolved').length;

  int get _urgentCount => _tickets
      .where((t) => t.priority == 'High' || t.priority == 'Critical')
      .length;

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : navy,
      ),
    );
  }

  Future<void> _openTicket(Ticket ticket) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageTicketSheet(
        ticket: ticket,
        onUpdated: _refreshTickets,
        onMessage: _showMessage,
      ),
    );
    await _refreshTickets();
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to sign out of TriageDesk?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true && mounted) {
      ApiService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TriageDeskLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'TriageDesk',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshTickets,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh tickets',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Appearance',
          ),
          IconButton(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: navy,
        onRefresh: _refreshTickets,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            const Text(
              'Hello, Technician',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'View, manage and resolve support tickets.',
              style: TextStyle(fontSize: 14, color: secondaryColor),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Open',
                    _openCount,
                    Icons.pending_actions_outlined,
                    warning,
                    isDark,
                    secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Urgent',
                    _urgentCount,
                    Icons.priority_high_rounded,
                    warning,
                    isDark,
                    secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'In Progress',
                    _progressCount,
                    Icons.sync_outlined,
                    blue,
                    isDark,
                    secondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    'Resolved',
                    _resolvedCount,
                    Icons.check_circle_outline,
                    success,
                    isDark,
                    secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Support Tickets',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_tickets.length} tickets',
                  style: const TextStyle(
                    color: blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading && _tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _tickets.isEmpty)
              _messageState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load tickets',
                message: _error!,
                isDark: isDark,
                secondaryColor: secondaryColor,
                action: TextButton.icon(
                  onPressed: _refreshTickets,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              )
            else if (_tickets.isEmpty)
              _messageState(
                icon: Icons.inbox_outlined,
                title: 'No support tickets',
                message: 'New tickets submitted by reporters will appear here.',
                isDark: isDark,
                secondaryColor: secondaryColor,
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Refresh warning: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ..._tickets.map((t) => _ticketCard(t, isDark, secondaryColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    int value,
    IconData icon,
    Color iconColor,
    bool isDark,
    Color secondaryColor,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: secondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(Ticket ticket, bool isDark, Color secondaryColor) {
    final statusColor = _statusColor(ticket.status);
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
        onTap: () => _openTicket(ticket),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(ticket.category),
                  color: navy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
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
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ticket.category,
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
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
                        Text(
                          ticket.ticketNumber ?? 'ID ${ticket.id}',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          ticket.priority,
                          style: TextStyle(
                            fontSize: 11,
                            color: _priorityColor(ticket.priority),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: secondaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    required bool isDark,
    required Color secondaryColor,
    Widget? action,
  }) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 35),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 45, color: secondaryColor),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondaryColor, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
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
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC2626);
      case 'High':
        return warning;
      case 'Medium':
        return blue;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
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
        return Icons.help_outline_rounded;
    }
  }
}

class _ManageTicketSheet extends StatefulWidget {
  final Ticket ticket;
  final Future<void> Function() onUpdated;
  final void Function(String message, {bool isError}) onMessage;

  const _ManageTicketSheet({
    required this.ticket,
    required this.onUpdated,
    required this.onMessage,
  });

  @override
  State<_ManageTicketSheet> createState() => _ManageTicketSheetState();
}

class _ManageTicketSheetState extends State<_ManageTicketSheet> {
  static const Color navy = AppTheme.charcoal;
  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;

  late final TextEditingController _notesController;
  late final TextEditingController _resolutionController;
  bool _busy = false;
  String _status = '';

  int get _ticketId {
    final id = int.tryParse(widget.ticket.id);
    if (id == null) {
      throw Exception('This ticket has an invalid database ID.');
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
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

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await action();
      if (!mounted) return;
      await widget.onUpdated();
      if (!mounted) return;
      widget.onMessage(successMessage);
    } catch (error) {
      if (mounted) {
        widget.onMessage(
          error.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Manage Ticket',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Review and update this support request.',
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.ticketNumber ?? 'Ticket ${ticket.id}',
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ticket.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${ticket.category} • ${ticket.priority}'),
                      const SizedBox(height: 8),
                      Text(
                        'Status: $_status',
                        style: TextStyle(
                          color: _status == 'Resolved' ? success : blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Ticket Information'),
                const SizedBox(height: 8),
                _info('Impact', ticket.impact, secondaryColor),
                _info('Urgency', ticket.urgency, secondaryColor),
                _info('Device', ticket.device, secondaryColor),
                _info('Location', ticket.location, secondaryColor),
                _info(
                  'Assigned Technician',
                  ticket.assignedTechnician ?? 'Not assigned',
                  secondaryColor,
                ),
                const SizedBox(height: 18),
                _sectionTitle('Problem Description'),
                const SizedBox(height: 8),
                Text(
                  ticket.description,
                  style: TextStyle(color: secondaryColor, height: 1.5),
                ),
                const SizedBox(height: 22),

                if (_status == 'Open')
                  _button(
                    'Accept Ticket',
                    Icons.check_circle_outline,
                    () => _runAction(() async {
                      await ApiService.acceptTicket(_ticketId);
                      if (mounted) setState(() => _status = 'In Progress');
                    }, 'Ticket accepted successfully.'),
                  ),

                if (_status == 'In Progress') ...[
                  _sectionTitle('Ticket Status'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    dropdownColor: cardColor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
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
                    onChanged: _busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            if (value == 'Resolved') {
                              if (_resolutionController.text.trim().isEmpty) {
                                widget.onMessage(
                                  'Enter the resolution before resolving the ticket.',
                                  isError: true,
                                );
                                return;
                              }
                              await _resolveTicket();
                            } else {
                              await _runAction(() async {
                                await ApiService.updateTicketStatus(
                                  ticketId: _ticketId,
                                  status: value,
                                );
                                if (mounted) setState(() => _status = value);
                              }, 'Ticket status updated.');
                            }
                          },
                  ),
                  const SizedBox(height: 18),
                ],

                _sectionTitle('Technician Notes'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter troubleshooting notes...',
                    hintStyle: TextStyle(color: secondaryColor),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _button('Save Technician Note', Icons.note_alt_outlined, () {
                  final note = _notesController.text.trim();
                  if (note.isEmpty) {
                    widget.onMessage(
                      'Enter a note before saving.',
                      isError: true,
                    );
                    return;
                  }
                  _runAction(() async {
                    await ApiService.addTicketNote(
                      ticketId: _ticketId,
                      note: note,
                    );
                  }, 'Technician note saved.');
                }, outlined: true),
                const SizedBox(height: 20),

                _sectionTitle('Resolution'),
                const SizedBox(height: 8),
                TextField(
                  controller: _resolutionController,
                  maxLines: 4,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe how the issue was resolved...',
                    hintStyle: TextStyle(color: secondaryColor),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (_status != 'Resolved')
                  _button(
                    'Resolve Ticket',
                    Icons.task_alt_outlined,
                    _resolveTicket,
                  ),

                if (_status == 'Resolved')
                  _button(
                    'Reopen Ticket',
                    Icons.refresh,
                    () => _runAction(() async {
                      await ApiService.reopenTicket(_ticketId);
                      if (mounted) setState(() => _status = 'Open');
                    }, 'Ticket reopened.'),
                    outlined: true,
                  ),

                if (_busy) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolveTicket() async {
    final resolution = _resolutionController.text.trim();
    if (resolution.isEmpty) {
      widget.onMessage(
        'Enter the resolution before resolving the ticket.',
        isError: true,
      );
      return;
    }

    await _runAction(() async {
      await ApiService.updateTicketStatus(
        ticketId: _ticketId,
        status: 'Resolved',
        resolution: resolution,
      );
      if (mounted) {
        setState(() => _status = 'Resolved');
        Navigator.pop(context);
        CelebrationDialog.show(
          context,
          title: 'Ticket Resolved! 🎉',
          message: 'Great job! The ticket has been marked as resolved and the reporter has been notified.',
        );
      }
    }, 'Ticket resolved successfully.');
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _info(String label, String value, Color secondaryColor) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _button(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            side: const BorderSide(color: navy),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
