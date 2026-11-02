import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import '../widgets/user_header.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'ticket_details_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  int _currentIndex = 0;
  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;
  static const Color danger = Color(0xFFDC2626);

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

  String get _technicianName => ApiService.currentUserName;
  String get _technicianEmail => ApiService.currentUserEmail;
  int? get _technicianId {
    final id = ApiService.currentUser?['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  int get _assignedCount => _tickets
      .where((ticket) => ticket.assignedTechnicianId == _technicianId)
      .length;
  int get _progressCount =>
      _tickets.where((t) => t.status == 'In Progress').length;
  int get _pendingCount => _tickets
      .where(
        (ticket) =>
            (ticket.status == 'Open' || ticket.status == 'Pending') &&
            ticket.assignedTechnicianId == null,
      )
      .length;

  Future<void> _openTicket(Ticket ticket) async {
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
          lastModifiedAt: ticket.lastModifiedAt ?? ticket.updatedAt,
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TriageDeskLogo(size: 30),
            SizedBox(width: 8),
            Text(
              'TriageDesk',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                onPressed: _refreshTickets,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: blue,
              child: Text(
                ApiService.currentUserInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: switch (_currentIndex) {
        0 => _buildHomeTab(theme, secondaryColor),
        1 => _buildAssignedTab(theme, secondaryColor),
        2 => _buildAllTicketsTab(theme, secondaryColor),
        3 => _buildProfileTab(theme),
        _ => _buildHomeTab(theme, secondaryColor),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: blue,
        unselectedItemColor: secondaryColor,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind_outlined),
            label: 'Assigned',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(ThemeData theme, Color secondaryColor) {
    return RefreshIndicator(
      color: blue,
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          buildUserHeader(context, roleTitle: 'Technician', color: blue),
          // Greeting
          Text(
            'Good morning, $_technicianName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here are your assigned tickets.',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
          const SizedBox(height: 18),

          // 3 Summary Cards (Assigned, In Progress, Pending)
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  'Assigned',
                  _assignedCount,
                  Icons.person_outline_rounded,
                  blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  'In Progress',
                  _progressCount,
                  Icons.access_time_rounded,
                  blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  'Pending',
                  _pendingCount,
                  Icons.hourglass_empty_rounded,
                  warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Assigned Tickets Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Tickets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _refreshTickets,
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ticket List
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
            )
          else if (_tickets.isEmpty)
            _messageState(
              icon: Icons.inbox_outlined,
              title: 'No assigned tickets',
              message: 'Assigned support tickets will appear here.',
            )
          else
            ..._tickets.map((t) => _ticketCard(t, secondaryColor)),

          const SizedBox(height: 24),

          // Recent Activity Section
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_tickets.isEmpty)
            Text(
              'No recent ticket activity.',
              style: TextStyle(color: secondaryColor),
            )
          else
            ...(_tickets.toList()..sort(
                  (a, b) =>
                      (b.lastModifiedAt ?? b.updatedAt ?? b.createdAt)
                          .compareTo(
                            a.lastModifiedAt ??
                                a.updatedAt ??
                                a.createdAt,
                          ),
                ))
                .take(3)
                .map(
                  (ticket) => _activityItem(
                    initials: ApiService.currentUserInitials,
                    action: ticket.lastModifiedBy == null
                        ? 'Ticket ${ticket.ticketNumber ?? ticket.id} · ${ticket.status}'
                        : '${ticket.lastModifiedBy} updated ${ticket.ticketNumber ?? ticket.id}',
                    description: ticket.title,
                    time: _timeAgo(
                      ticket.lastModifiedAt ??
                          ticket.updatedAt ??
                          ticket.createdAt,
                    ),
                    color: blue,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAssignedTab(ThemeData theme, Color secondaryColor) {
    final assignedTickets = _tickets
        .where((ticket) => ticket.assignedTechnicianId == _technicianId)
        .toList();

    return RefreshIndicator(
      color: blue,
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          buildUserHeader(context, roleTitle: 'Technician', color: blue),
          const Text(
            'Assigned Tickets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${assignedTickets.length} assigned tickets',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
          const SizedBox(height: 16),
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
            )
          else if (assignedTickets.isEmpty)
            _messageState(
              icon: Icons.inbox_outlined,
              title: 'No assigned tickets',
              message: 'Tickets assigned to you will appear here.',
            )
          else
            ...assignedTickets.map((t) => _ticketCard(t, secondaryColor)),
        ],
      ),
    );
  }

  Widget _buildAllTicketsTab(ThemeData theme, Color secondaryColor) {
    return RefreshIndicator(
      color: blue,
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          buildUserHeader(context, roleTitle: 'Technician', color: blue),
          const Text(
            'All Support Tickets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${_tickets.length} total tickets',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
          const SizedBox(height: 16),
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
            )
          else if (_tickets.isEmpty)
            _messageState(
              icon: Icons.inbox_outlined,
              title: 'No tickets available',
              message: 'Support tickets will appear here.',
            )
          else
            ..._tickets.map((t) => _ticketCard(t, secondaryColor)),
        ],
      ),
    );
  }

  Widget _buildProfileTab(ThemeData theme) {
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        buildUserHeader(context, roleTitle: 'Technician', color: blue),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: blue.withValues(alpha: 0.15),
              foregroundColor: blue,
              child: Text(ApiService.currentUserInitials),
            ),
            title: Text(
              _technicianName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _technicianEmail.isEmpty
                  ? 'Technician'
                  : '$_technicianEmail\nTechnician',
              style: TextStyle(color: secondaryColor),
            ),
            isThreeLine: _technicianEmail.isNotEmpty,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Sign out'),
            onTap: _confirmSignOut,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, int value, IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(Ticket ticket, Color secondaryColor) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(ticket.status);
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTicket(ticket),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon(ticket.category),
                  color: blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          ticket.ticketNumber ?? 'ID ${ticket.id}',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: secondaryColor)),
                        const SizedBox(width: 6),
                        Text(
                          ticket.priority,
                          style: TextStyle(
                            fontSize: 12,
                            color: _priorityColor(ticket.priority),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(
                        ticket.lastModifiedAt ??
                            ticket.updatedAt ??
                            ticket.createdAt,
                      ),
                      style: TextStyle(fontSize: 11, color: secondaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticket.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityItem({
    required String initials,
    required String action,
    required String description,
    required String time,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(fontSize: 11, color: secondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final elapsed = DateTime.now().difference(dateTime.toLocal());
    if (elapsed.inDays > 0) return '${elapsed.inDays}d ago';
    if (elapsed.inHours > 0) return '${elapsed.inHours}h ago';
    if (elapsed.inMinutes > 0) return '${elapsed.inMinutes}m ago';
    return 'Just now';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return danger;
      case 'In Progress':
        return blue;
      case 'Resolved':
        return success;
      case 'Pending':
        return warning;
      default:
        return blue;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC2626);
      case 'High':
        return danger;
      case 'Medium':
        return warning;
      default:
        return success;
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
      default:
        return Icons.help_outline_rounded;
    }
  }
}
