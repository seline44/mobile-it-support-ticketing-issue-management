import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/ticket_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';
import 'login_screen.dart';

class ReporterDashboard extends StatefulWidget {
  const ReporterDashboard({super.key});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard> {
  int _currentIndex = 0;
  String _ticketFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshTickets() {
    setState(() {});
  }

  Future<void> _openCreateTicket() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTicketScreen()),
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

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of TriageDesk?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final initials = _userInitials;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colors.onSurface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TriageDeskLogo(size: 30),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Triage',
                    style: TextStyle(color: colors.onSurface),
                  ),
                  TextSpan(
                    text: 'Desk',
                    style: TextStyle(color: colors.primary),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => setState(() => _currentIndex = 4),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: colors.primary,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildCurrentTabBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        elevation: 8,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        onTap: (index) {
          if (index == 2) {
            _openCreateTicket();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            label: 'Add',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String get _displayName {
    final user = ApiService.currentUser;
    final fullName = user?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final email = user?['email']?.toString().trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Reporter';
  }

  String get _userEmail {
    final user = ApiService.currentUser;
    final email = user?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    return 'reporter@triagedesk.com';
  }

  String get _userInitials {
    final user = ApiService.currentUser;
    final fullName = user?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      return parts.take(2).map((part) => part[0].toUpperCase()).join();
    }

    final email = user?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'TD';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildCurrentTabBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildTicketsTab();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  // --- TAB 0: HOME ---
  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final greetingSurface = isDark
        ? const Color(0xFF122D33)
        : const Color(0xFFEAF5F7);
    final List<Ticket> tickets = TicketService.tickets;

    final int totalTickets = TicketService.totalTickets;
    final int openTickets = TicketService.openTickets;
    final int inProgressTickets = TicketService.inProgressTickets;
    final int resolvedTickets = TicketService.resolvedTickets;

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: () async => _refreshTickets(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: greetingSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.waving_hand_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, $_displayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Here’s what’s happening today.',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    title: 'Total',
                    value: totalTickets.toString(),
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFF12A99B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    title: 'Open',
                    value: openTickets.toString(),
                    icon: Icons.schedule_rounded,
                    iconColor: const Color(0xFF12A99B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    title: 'In Progress',
                    value: inProgressTickets.toString(),
                    icon: Icons.hourglass_top_rounded,
                    iconColor: const Color(0xFF12A99B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    title: 'Resolved',
                    value: resolvedTickets.toString(),
                    icon: Icons.check_circle_outline,
                    iconColor: const Color(0xFF16A879),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Tickets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (tickets.isEmpty)
              _emptyTicketsState()
            else
              ...tickets
                  .take(4)
                  .map((ticket) => _ticketCard(ticket, compact: true)),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: TICKETS ---
  Widget _buildTicketsTab() {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    final query = _searchController.text.trim().toLowerCase();
    final allTickets = TicketService.tickets;

    final filteredTickets = allTickets.where((t) {
      final matchesFilter = _ticketFilter == 'All' || t.status == _ticketFilter;
      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          t.id.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search tickets...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Open', 'In Progress', 'Resolved'].map((
                filter,
              ) {
                final selected = _ticketFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) => setState(() => _ticketFilter = filter),
                    selectedColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? theme.colorScheme.primary
                          : textSecondary,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredTickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching tickets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _refreshTickets(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: filteredTickets
                          .map((t) => _ticketCard(t))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _dynamicNotifications {
    final tickets = TicketService.tickets;
    final List<Map<String, dynamic>> list = [];

    for (var ticket in tickets) {
      if (ticket.status == 'Resolved') {
        list.add({
          'title': 'Ticket Resolved (${ticket.id})',
          'subtitle': ticket.resolution != null && ticket.resolution!.isNotEmpty
              ? 'Resolution: ${ticket.resolution}'
              : 'Your ticket "${ticket.title}" has been resolved.',
          'time': 'Recent',
          'icon': Icons.check_circle_outline_rounded,
          'color': success,
          'ticket': ticket,
        });
      } else if (ticket.technicianNotes != null &&
          ticket.technicianNotes!.isNotEmpty) {
        list.add({
          'title': 'Technician Note Added (${ticket.id})',
          'subtitle': 'Note: ${ticket.technicianNotes}',
          'time': 'Recent',
          'icon': Icons.note_alt_outlined,
          'color': Theme.of(context).colorScheme.primary,
          'ticket': ticket,
        });
      } else if (ticket.status == 'In Progress') {
        list.add({
          'title': 'Ticket In Progress (${ticket.id})',
          'subtitle':
              'Your ticket "${ticket.title}" is being handled by ${ticket.assignedTechnician ?? 'IT Support'}.',
          'time': 'Recent',
          'icon': Icons.sync_outlined,
          'color': Theme.of(context).colorScheme.secondary,
          'ticket': ticket,
        });
      } else {
        list.add({
          'title': 'Ticket Created (${ticket.id})',
          'subtitle': 'Support request "${ticket.title}" submitted successfully.',
          'time': 'Recent',
          'icon': Icons.confirmation_number_outlined,
          'color': warning,
          'ticket': ticket,
        });
      }
    }
    return list;
  }

  // --- TAB 3: NOTIFICATIONS ---
  Widget _buildNotificationsTab() {
    final theme = Theme.of(context);
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final notifications = _dynamicNotifications;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Recent Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        if (notifications.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'No notifications yet',
                style: TextStyle(color: textSecondary),
              ),
            ),
          )
        else
          ...notifications.map(
            (n) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _openTicketDetails(n['ticket'] as Ticket),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (n['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n['icon'] as IconData, color: n['color'] as Color),
                ),
                title: Text(
                  n['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    n['subtitle'] as String,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  // --- TAB 4: PROFILE & SETTINGS ---
  Widget _buildProfileTab() {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        final currentMode = ThemeService.instance.themeMode;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        _userInitials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Reporter',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _ThemeOptionTile(
                      mode: ThemeMode.light,
                      currentMode: currentMode,
                      title: 'Light Mode',
                      subtitle: 'Clean light background with dark text',
                      icon: Icons.light_mode_rounded,
                      iconColor: theme.colorScheme.tertiary,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.light),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ThemeOptionTile(
                      mode: ThemeMode.dark,
                      currentMode: currentMode,
                      title: 'Dark Mode',
                      subtitle: 'Dark background comfortable in low light',
                      icon: Icons.dark_mode_rounded,
                      iconColor: theme.colorScheme.secondary,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.dark),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ThemeOptionTile(
                      mode: ThemeMode.system,
                      currentMode: currentMode,
                      title: 'System Default',
                      subtitle: 'Automatically matches your device settings',
                      icon: Icons.settings_system_daydream_rounded,
                      iconColor: theme.colorScheme.primary,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.system),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTicketsState() {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: textSecondary),
          const SizedBox(height: 14),
          Text(
            'No tickets yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your submitted support tickets will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _ticketCard(Ticket ticket, {bool compact = false}) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final Color statusColor = _statusColor(ticket.status);
    final IconData icon = _categoryIcon(ticket.category);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 7 : 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: compact ? 0.025 : 0.035),
            blurRadius: compact ? 5 : 8,
            offset: Offset(0, compact ? 2 : 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        onTap: () => _openTicketDetails(ticket),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 15),
          child: Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 30 : 44,
                height: compact ? 30 : 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(compact ? 9 : 12),
                ),
                child: Icon(icon, color: statusColor, size: compact ? 17 : 21),
              ),
              SizedBox(width: compact ? 9 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 5),
                      Text(
                        ticket.category,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      const SizedBox(height: 9),
                    ] else
                      const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ticket.id,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 9 : 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('•', style: TextStyle(color: statusColor)),
                        const SizedBox(width: 4),
                        Text(
                          ticket.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 9 : 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (compact) ...[
                const SizedBox(width: 6),
                Text(
                  _timeAgo(ticket.createdAt),
                  style: TextStyle(fontSize: 9, color: textSecondary),
                ),
              ] else ...[
                const SizedBox(width: 5),
                Icon(Icons.chevron_right_rounded, color: textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime createdAt) {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inDays >= 1) return '${elapsed.inDays}d ago';
    if (elapsed.inHours >= 1) return '${elapsed.inHours}h ago';
    if (elapsed.inMinutes >= 1) return '${elapsed.inMinutes}m ago';
    return 'Now';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return warning;
      case 'In Progress':
        return Theme.of(context).colorScheme.secondary;
      case 'Resolved':
        return success;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
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

class _ThemeOptionTile extends StatelessWidget {
  final ThemeMode mode;
  final ThemeMode currentMode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onSelect;

  const _ThemeOptionTile({
    required this.mode,
    required this.currentMode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == currentMode;

    return ListTile(
      onTap: onSelect,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.circle_outlined, color: Colors.grey),
    );
  }
}
