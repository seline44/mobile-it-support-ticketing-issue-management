import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/ticket_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

const Color adminNavy = AppTheme.charcoal;
const Color adminBlue = AppTheme.accentTeal;
const Color adminGreen = AppTheme.accentTeal;
const Color adminAmber = AppTheme.warningGold;
const Color adminRed = Color(0xFFDC2626);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await ApiService.getTickets();
      final loaded = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tickets = TicketService.tickets;
        _isLoading = false;
      });
    }
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (mounted) {
      _loadTickets();
    }
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
    final adminBackground = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final tickets = _tickets.isEmpty && !_isLoading
        ? TicketService.tickets
        : _tickets;

    final total = tickets.length;
    final open = tickets.where((t) => t.status == 'Open').length;
    final inProgress = tickets.where((t) => t.status == 'In Progress').length;
    final resolved = tickets.where((t) => t.status == 'Resolved').length;

    final slaRisk = tickets.where((ticket) {
      final active = ticket.status != 'Resolved' && ticket.status != 'Closed';

      return active &&
          DateTime.now().difference(ticket.createdAt).inHours >= 24;
    }).length;

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TriageDeskLogo(size: 32),
            SizedBox(width: 10),
            Text(
              'Administrator Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Settings & Appearance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            const Text(
              'IT Support Overview',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor tickets, SLA performance and workload.',
              style: TextStyle(color: secondaryColor, fontSize: 14),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Tickets',
                    value: '$total',
                    icon: Icons.confirmation_number_outlined,
                    color: adminBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Open',
                    value: '$open',
                    icon: Icons.inbox_outlined,
                    color: adminAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Resolved',
                    value: '$resolved',
                    icon: Icons.check_circle_outline_rounded,
                    color: adminGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'SLA Risk*',
                    value: '$slaRisk',
                    icon: Icons.warning_amber_rounded,
                    color: adminRed,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      color: adminBlue,
                      size: 27,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently in progress',
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$inProgress tickets',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'View in-progress tickets',
                      onPressed: () => _openPage(
                        const AdminTicketsScreen(initialFilter: 'In Progress'),
                      ),
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'Administration',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),

            _AdminMenuItem(
              icon: Icons.confirmation_number_outlined,
              title: 'All Tickets',
              subtitle: 'View, inspect and update support tickets',
              color: adminBlue,
              onTap: () => _openPage(const AdminTicketsScreen()),
            ),
            _AdminMenuItem(
              icon: Icons.people_outline_rounded,
              title: 'Users and Technicians',
              subtitle: 'View the available roles and account structure',
              color: AppTheme.accentTeal,
              onTap: () => _openPage(const AdminUsersScreen()),
            ),
            _AdminMenuItem(
              icon: Icons.speed_outlined,
              title: 'SLA Monitoring',
              subtitle: 'Inspect older unresolved tickets',
              color: adminRed,
              onTap: () => _openPage(const AdminSlaScreen()),
            ),
            _AdminMenuItem(
              icon: Icons.bar_chart_rounded,
              title: 'Reports and Analytics',
              subtitle: 'Review ticket volumes and status distribution',
              color: adminGreen,
              onTap: () => _openPage(const AdminReportsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

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
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: secondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ALL TICKETS
// ============================================================

class AdminTicketsScreen extends StatefulWidget {
  final String? initialFilter;

  const AdminTicketsScreen({super.key, this.initialFilter});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  late String _filter;
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  final List<String> _filters = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? 'All';
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await ApiService.getTickets();
      final loaded = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tickets = TicketService.tickets;
        _isLoading = false;
      });
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return adminRed;
      case 'high':
        return adminAmber;
      case 'medium':
        return adminBlue;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return adminAmber;
      case 'In Progress':
        return adminBlue;
      case 'Resolved':
        return adminGreen;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Future<void> _showTicket(Ticket ticket) async {
    String selectedStatus = ticket.status;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                ticket.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ticket.id, style: TextStyle(color: secondaryColor)),
                    const SizedBox(height: 12),
                    Text(ticket.description),
                    const SizedBox(height: 18),
                    _DetailLine(label: 'Category', value: ticket.category),
                    _DetailLine(label: 'Priority', value: ticket.priority),
                    _DetailLine(label: 'Impact', value: ticket.impact),
                    _DetailLine(label: 'Urgency', value: ticket.urgency),
                    _DetailLine(label: 'Device', value: ticket.device),
                    _DetailLine(label: 'Location', value: ticket.location),
                    _DetailLine(
                      label: 'Technician',
                      value: ticket.assignedTechnician ?? 'Unassigned',
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Update status',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).cardColor,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'Resolved',
                          child: Text('Resolved'),
                        ),
                        DropdownMenuItem(
                          value: 'Closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    if (ticket.technicianNotes != null &&
                        ticket.technicianNotes!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Technician notes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(ticket.technicianNotes!),
                    ],
                    if (ticket.resolution != null &&
                        ticket.resolution!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Resolution',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(ticket.resolution!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: adminNavy),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final numericId = int.tryParse(ticket.id);
                      if (numericId != null) {
                        await ApiService.updateTicketStatus(
                          ticketId: numericId,
                          status: selectedStatus,
                        );
                      }
                      TicketService.updateStatus(ticket.id, selectedStatus);

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (mounted) {
                        _loadTickets();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${ticket.ticketNumber ?? ticket.id} updated to $selectedStatus',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not update status: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final adminBackground = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final allTickets = _tickets.isEmpty && !_isLoading
        ? TicketService.tickets
        : _tickets;

    final filteredTickets = _filter == 'All'
        ? allTickets
        : allTickets.where((t) => t.status == _filter).toList();

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminNavy,
        title: const Text('All Tickets'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh tickets',
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 65,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];

                return ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                  selectedColor: adminNavy.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: _filter == filter ? adminNavy : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: filteredTickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 52,
                          color: secondaryColor,
                        ),
                        const SizedBox(height: 12),
                        const Text('No tickets in this category.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = filteredTickets[index];

                      return Card(
                        color: cardColor,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: borderColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showTicket(ticket),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ticket.id,
                                        style: TextStyle(
                                          color: secondaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _Pill(
                                      label: ticket.priority,
                                      color: _priorityColor(ticket.priority),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ticket.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _Pill(
                                      label: ticket.status,
                                      color: _statusColor(ticket.status),
                                    ),
                                    _Pill(
                                      label: ticket.category,
                                      color: secondaryColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: secondaryColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        ticket.assignedTechnician ??
                                            'Unassigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: secondaryColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// USERS AND TECHNICIANS — ACCOUNT MANAGEMENT
// ============================================================

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';

  final Set<int> _updatingUserIds = {};

  final List<String> _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('ADMIN USERS: Starting request...');
      final users = await ApiService.getAllUsers();

      debugPrint('ADMIN USERS: Received ${users.length} users');
      debugPrint('ADMIN USERS: Data = $users');

      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('ADMIN USERS ERROR: $error');
      debugPrint('ADMIN USERS STACK TRACE: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _approvalStatus(Map<String, dynamic> user) {
    final status = (user['approval_status'] ?? 'Pending').toString().trim();

    if (status.toLowerCase() == 'approved') return 'Approved';
    if (status.toLowerCase() == 'rejected') return 'Rejected';
    if (status.toLowerCase() == 'pending') return 'Pending';

    return status.isEmpty ? 'Pending' : status;
  }

  int _countFor(String status) {
    if (status == 'All') return _users.length;

    return _users.where((item) {
      if (item is! Map) return false;

      return _approvalStatus(Map<String, dynamic>.from(item)).toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final result = <Map<String, dynamic>>[];

    for (final item in _users) {
      if (item is! Map) continue;

      final user = Map<String, dynamic>.from(item);
      final status = _approvalStatus(user);

      if (_selectedFilter == 'All' ||
          status.toLowerCase() == _selectedFilter.toLowerCase()) {
        result.add(user);
      }
    }

    result.sort((a, b) {
      final nameA = (a['full_name'] ?? a['email'] ?? '')
          .toString()
          .toLowerCase();
      final nameB = (b['full_name'] ?? b['email'] ?? '')
          .toString()
          .toLowerCase();

      return nameA.compareTo(nameB);
    });

    return result;
  }

  Future<void> _updateApproval(Map<String, dynamic> user, String status) async {
    final dynamic rawId = user['id'] ?? user['user_id'];
    final int? userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this account.')),
      );
      return;
    }

    setState(() => _updatingUserIds.add(userId));

    try {
      await ApiService.updateUserApproval(
        userId: userId,
        approvalStatus: status,
      );

      if (!mounted) return;

      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;

          final dynamic itemId = item['id'] ?? item['user_id'];

          if (itemId.toString() == userId.toString()) {
            item['approval_status'] = status;
            break;
          }
        }

        _updatingUserIds.remove(userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Approved'
                ? 'Account approved successfully.'
                : 'Account rejected successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _updatingUserIds.remove(userId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _linkWhatsAppNumber(Map<String, dynamic> user) async {
    final dynamic rawId = user['id'] ?? user['user_id'];
    final int? userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this account.')),
      );
      return;
    }

    final controller = TextEditingController();
    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? validationError;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Link WhatsApp number'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Reporter phone number',
                hintText: '+254794045207',
                helperText: 'Use international format, starting with +.',
                errorText: validationError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final phone = controller.text.trim();
                  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
                    setDialogState(
                      () => validationError =
                          'Enter a valid international number.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, phone);
                },
                child: const Text('Link number'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (phoneNumber == null) return;

    setState(() => _updatingUserIds.add(userId));
    try {
      final result = await ApiService.linkWhatsAppNumber(
        userId: userId,
        phoneNumber: phoneNumber,
      );
      if (!mounted) return;

      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final dynamic itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['whatsapp_phone_number'] = result['phone_number'];
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'WhatsApp number linked.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return adminGreen;
      case 'pending':
        return adminAmber;
      case 'rejected':
        return adminRed;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminBackground = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final visibleUsers = _filteredUsers;

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminNavy,
        title: const Text('Users and Technicians'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'User Management',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'View registered accounts and manage registration approvals.',
              style: TextStyle(color: secondaryColor, height: 1.5),
            ),
            const SizedBox(height: 20),

            if (!_isLoading && _errorMessage == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Total Users',
                      _countFor('All'),
                      adminBlue,
                      Icons.people_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      'Pending',
                      _countFor('Pending'),
                      adminAmber,
                      Icons.pending_actions_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Approved',
                      _countFor('Approved'),
                      adminGreen,
                      Icons.verified_user_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      'Rejected',
                      _countFor('Rejected'),
                      adminRed,
                      Icons.person_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Filter accounts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _filters)
                    ChoiceChip(
                      label: Text('$filter (${_countFor(filter)})'),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                      selectedColor: adminNavy.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: _selectedFilter == filter ? adminNavy : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Card(
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: adminRed,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _loadUsers,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visibleUsers.isEmpty)
              Card(
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFilter == 'Pending'
                            ? Icons.verified_user_outlined
                            : Icons.people_outline_rounded,
                        size: 48,
                        color: secondaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFilter == 'Pending'
                            ? 'No pending registrations'
                            : 'No ${_selectedFilter.toLowerCase()} users',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try another filter or refresh the list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                '${visibleUsers.length} '
                '${visibleUsers.length == 1 ? 'account' : 'accounts'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final user in visibleUsers)
                _buildUserCard(user, cardColor, borderColor, secondaryColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: secondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    Color cardColor,
    Color borderColor,
    Color secondaryColor,
  ) {
    final name =
        (user['full_name'] ??
                user['name'] ??
                user['username'] ??
                'Unnamed user')
            .toString();

    final email = (user['email'] ?? 'No email provided').toString();
    final role = (user['role'] ?? 'Reporter').toString();
    final status = _approvalStatus(user);

    final dynamic rawId = user['id'] ?? user['user_id'];
    final int? userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');

    final isUpdating = userId != null && _updatingUserIds.contains(userId);
    final isPending = status.toLowerCase() == 'pending';
    final canLinkWhatsApp =
        role.toLowerCase() == 'reporter' && status.toLowerCase() == 'approved';
    final linkedWhatsAppNumber = user['whatsapp_phone_number']?.toString();

    final roleColor = role.toLowerCase() == 'technician'
        ? adminGreen
        : role.toLowerCase() == 'administrator'
        ? adminNavy
        : adminBlue;

    final statusColor = _statusColor(status);

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Icon(
                    role.toLowerCase() == 'technician'
                        ? Icons.support_agent_rounded
                        : role.toLowerCase() == 'administrator'
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline_rounded,
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        style: TextStyle(color: secondaryColor, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(label: role, color: roleColor),
                          _Pill(label: status, color: statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isUpdating || userId == null
                          ? null
                          : () => _updateApproval(user, 'Rejected'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: adminRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isUpdating || userId == null
                          ? null
                          : () => _updateApproval(user, 'Approved'),
                      icon: isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(isUpdating ? 'Updating...' : 'Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: adminGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (canLinkWhatsApp) ...[
              const SizedBox(height: 12),
              if (linkedWhatsAppNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'WhatsApp linked: $linkedWhatsAppNumber',
                    style: TextStyle(color: secondaryColor, fontSize: 13),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: isUpdating || userId == null
                    ? null
                    : () => _linkWhatsAppNumber(user),
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(isUpdating ? 'Linking...' : 'Link WhatsApp'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SLA MONITORING — PROVISIONAL AGE-BASED MONITORING
// ============================================================

class AdminSlaScreen extends StatefulWidget {
  const AdminSlaScreen({super.key});

  @override
  State<AdminSlaScreen> createState() => _AdminSlaScreenState();
}

class _AdminSlaScreenState extends State<AdminSlaScreen> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await ApiService.getTickets();
      final loaded = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tickets = TicketService.tickets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminBackground = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final now = DateTime.now();
    final allTickets = _tickets.isEmpty && !_isLoading
        ? TicketService.tickets
        : _tickets;

    final activeTickets = allTickets.where((ticket) {
      return ticket.status != 'Resolved' && ticket.status != 'Closed';
    }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final atRisk = activeTickets.where((ticket) {
      return now.difference(ticket.createdAt).inHours >= 24;
    }).toList();

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminNavy,
        title: const Text('SLA Monitoring'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh tickets',
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Unresolved Tickets',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Active',
                  value: '${activeTickets.length}',
                  icon: Icons.pending_actions_outlined,
                  color: adminBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Over 24 Hours',
                  value: '${atRisk.length}',
                  icon: Icons.warning_amber_rounded,
                  color: adminRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (activeTickets.isEmpty)
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              child: const Padding(
                padding: EdgeInsets.all(22),
                child: Text('There are no unresolved tickets.'),
              ),
            )
          else
            for (final ticket in activeTickets)
              Card(
                color: cardColor,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: Icon(
                    now.difference(ticket.createdAt).inHours >= 24
                        ? Icons.warning_amber_rounded
                        : Icons.schedule_rounded,
                    color: now.difference(ticket.createdAt).inHours >= 24
                        ? adminRed
                        : adminBlue,
                  ),
                  title: Text(
                    ticket.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${ticket.id} • ${ticket.status}\n'
                      'Age: ${now.difference(ticket.createdAt).inHours} hours',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminTicketsScreen(initialFilter: ticket.status),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

// ============================================================
// REPORTS AND ANALYTICS
// ============================================================

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await ApiService.getTickets();
      final loaded = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tickets = TicketService.tickets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminBackground = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final tickets = _tickets.isEmpty && !_isLoading
        ? TicketService.tickets
        : _tickets;
    final total = tickets.length;

    final open = tickets.where((t) => t.status == 'Open').length;
    final inProgress = tickets.where((t) => t.status == 'In Progress').length;
    final resolved = tickets.where((t) => t.status == 'Resolved').length;
    final closed = tickets.where((t) => t.status == 'Closed').length;

    final critical = tickets.where((t) => t.priority == 'Critical').length;
    final high = tickets.where((t) => t.priority == 'High').length;
    final medium = tickets.where((t) => t.priority == 'Medium').length;
    final low = tickets.where((t) => t.priority == 'Low').length;

    final categories = <String, int>{};

    for (final ticket in tickets) {
      categories[ticket.category] = (categories[ticket.category] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: adminBackground,
      appBar: AppBar(
        backgroundColor: adminNavy,
        title: const Text('Reports and Analytics'),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ticket Analytics',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'A summary of the tickets currently available in TriageDesk.',
            style: TextStyle(color: secondaryColor),
          ),
          const SizedBox(height: 20),
          _ReportCard(
            title: 'Ticket Status',
            rows: [
              _ReportRow('Open', open, total, adminAmber),
              _ReportRow('In Progress', inProgress, total, adminBlue),
              _ReportRow('Resolved', resolved, total, adminGreen),
              _ReportRow('Closed', closed, total, secondaryColor),
            ],
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Priority Distribution',
            rows: [
              _ReportRow('Critical', critical, total, adminRed),
              _ReportRow('High', high, total, adminAmber),
              _ReportRow('Medium', medium, total, adminBlue),
              _ReportRow('Low', low, total, secondaryColor),
            ],
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Issues by Category',
            rows: categories.entries
                .map(
                  (entry) =>
                      _ReportRow(entry.key, entry.value, total, adminNavy),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Card(
            color: cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _DetailLine(label: 'Total tickets', value: '$total'),
                  _DetailLine(
                    label: 'Unresolved tickets',
                    value: '${open + inProgress}',
                  ),
                  _DetailLine(
                    label: 'Resolution rate',
                    value: total == 0
                        ? '0%'
                        : '${(resolved * 100 / total).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'These figures use the current in-memory ticket list. '
            'Historical trends, average resolution time, downloadable '
            'reports and persistent analytics are not implemented yet.',
            style: TextStyle(fontSize: 12, color: secondaryColor, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final List<_ReportRow> rows;

  const _ReportCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final progressBg = Theme.of(context).colorScheme.outlineVariant
        .withValues(alpha: 0.45);

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            for (final row in rows) ...[
              Row(
                children: [
                  Expanded(child: Text(row.label)),
                  Text(
                    '${row.value}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: row.total == 0 ? 0 : row.value / row.total,
                  backgroundColor: progressBg,
                  valueColor: AlwaysStoppedAnimation<Color>(row.color),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportRow {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ReportRow(this.label, this.value, this.total, this.color);
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(color: secondaryColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
