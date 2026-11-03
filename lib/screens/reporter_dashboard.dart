import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/whatsapp_contact.dart';
import '../theme/app_theme.dart';
import '../theme/td_theme.dart';
import '../widgets/triagedesk_logo.dart';
import '../widgets/td_widgets.dart';
import '../widgets/user_header.dart';
import '../widgets/whatsapp_support_panel.dart';
import 'create_ticket_screen.dart';
import 'ticket_details_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ReporterDashboard extends StatefulWidget {
  const ReporterDashboard({super.key});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard> {
  int _currentIndex = 0;
  String _ticketFilter = 'All';
  List<Ticket> _tickets = [];
  bool _isLoadingTickets = true;
  String? _ticketError;
  List<Map<String, dynamic>> _notifications = [];
  final Set<int> _unreadNotificationIds = {};
  Timer? _notificationTimer;
  bool _notificationsInitialized = false;
  String? _notificationError;
  Future<void>? _notificationLoad;
  final TextEditingController _searchController = TextEditingController();

  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;

  @override
  void initState() {
    super.initState();
    _refreshTickets();
    _loadNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadNotifications(detectNew: true),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications({bool detectNew = false}) async {
    final pendingLoad = _notificationLoad;
    if (pendingLoad != null) {
      await pendingLoad;
      return;
    }

    final load = _fetchNotifications(detectNew: detectNew);
    _notificationLoad = load;
    try {
      await load;
    } finally {
      if (identical(_notificationLoad, load)) _notificationLoad = null;
    }
  }

  Future<void> _fetchNotifications({required bool detectNew}) async {
    try {
      final response = await ApiService.getTicketNotifications();
      final notifications = response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final previousIds = _notifications
          .map((notification) => int.tryParse(notification['id'].toString()))
          .whereType<int>()
          .toSet();
      final newNotifications = _notificationsInitialized && detectNew
          ? notifications.where((notification) {
              final id = int.tryParse(notification['id'].toString());
              return id != null && !previousIds.contains(id);
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _notificationError = null;
        for (final notification in newNotifications) {
          final id = int.tryParse(notification['id'].toString());
          if (id != null) _unreadNotificationIds.add(id);
        }
        _notificationsInitialized = true;
      });

      if (newNotifications.isNotEmpty) {
        final latest = newNotifications.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${latest['ticket_number']}: ${latest['action']}'),
          ),
        );
        await _refreshTickets();
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _notificationError = error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) return;
    setState(() {
      _unreadNotificationIds.clear();
      _currentIndex = 3;
    });
  }

  Future<void> _refreshTickets() async {
    if (mounted) {
      setState(() {
        _isLoadingTickets = true;
        _ticketError = null;
      });
    }
    try {
      final response = await ApiService.getTickets();
      final tickets = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _isLoadingTickets = false;
        _ticketError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingTickets = false;
        _ticketError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCreateTicket() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTicketScreen()),
    );
    _refreshTickets();
  }

  Future<void> _openTicketDetails(Ticket ticket) async {
    await Navigator.push(
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
          resolution: ticket.resolution,
          assignedTechnician: ticket.assignedTechnician,
          reporterName: ticket.reporterName,
          reporterPhone: ticket.reporterPhone,
          lastModifiedAt: ticket.lastModifiedAt ?? ticket.updatedAt,
        ),
      ),
    );
    if (mounted) _refreshTickets();
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.https('wa.me', '/$whatsappSupportNumber', {
      'text': whatsappSupportMessage,
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp: $error')),
      );
    }
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
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colors.onSurface,
        elevation: 0,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              children: [
                const TriageDeskLogo(size: 34),
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
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: _openNotifications,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 23),
                      if (_unreadNotificationIds.isNotEmpty)
                        Positioned(
                          right: -1,
                          top: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF5B64),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                InkWell(
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
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildCurrentTabBody(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        elevation: 8,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Tickets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'WhatsApp',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline_rounded),
            label: 'Help',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String get _displayName {
    final name = ApiService.currentUserName;
    return name.isEmpty ? 'Reporter' : name;
  }

  String get _userEmail {
    return ApiService.currentUserEmail;
  }

  String get _userInitials {
    return ApiService.currentUserInitials;
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
      case 2:
        return _buildWhatsAppTab();
      case 3:
        return _buildHelpTab();
      case 4:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  // --- TAB 0: HOME ---
  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final tickets = _tickets;

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _refreshTickets,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildUserHeader(context, roleTitle: 'Reporter'),
            Text(
              '$_greeting, $_displayName 👋',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF123D59),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Here’s what’s happening with your requests.',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 16),
            _homeHelpBanner(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Tickets',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF123D59),
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
                    'View all',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (_isLoadingTickets && tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_ticketError != null && tickets.isEmpty)
              _loadTicketsError(_ticketError!)
            else if (tickets.isEmpty)
              _emptyTicketsState()
            else
              ...tickets
                  .take(3)
                  .map((ticket) => _ticketCard(ticket, compact: true)),
          ],
        ),
      ),
    );
  }

  Widget _loadTicketsError(String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 38),
            const SizedBox(height: 8),
            const Text(
              'Could not load your tickets',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(error, textAlign: TextAlign.center),
            TextButton(
              onPressed: _refreshTickets,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeHelpBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D59), Color(0xFF00B5A7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008F8A).withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Report an issue, track your tickets\nor get support on WhatsApp.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: _openCreateTicket,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF009E94),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create Ticket',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
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

  // --- TAB 1: TICKETS ---
  Widget _buildTicketsTab() {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    final query = _searchController.text.trim().toLowerCase();
    final allTickets = _tickets;

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
          buildUserHeader(context, roleTitle: 'Reporter'),
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
              children: ['All', 'Open', 'In Progress', 'Resolved', 'Closed']
                  .map((filter) {
                    final selected = _ticketFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _ticketFilter = filter),
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
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingTickets && allTickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _ticketError != null && allTickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load your tickets: $_ticketError',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary),
                        ),
                        TextButton(
                          onPressed: _refreshTickets,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : filteredTickets.isEmpty
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
                    onRefresh: _refreshTickets,
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

  // --- TAB 3: HELP & SUPPORT ---
  Widget _buildHelpTab() {
    final theme = Theme.of(context);
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        buildUserHeader(context, roleTitle: 'Reporter'),
        Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Quick answers and updates about your support requests.',
          style: TextStyle(color: textSecondary),
        ),
        const SizedBox(height: 16),
        _supportInfoCard(
          icon: Icons.confirmation_number_outlined,
          title: 'Create a support ticket',
          detail: 'Tell us what is wrong and track progress from My Tickets.',
        ),
        const SizedBox(height: 10),
        _supportInfoCard(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Get help on WhatsApp',
          detail: 'Send a message describing your IT issue. The assistant will guide you through the ticket.',
        ),
        const SizedBox(height: 22),
        Text(
          'Recent updates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        if (_notificationError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _notificationError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                  TextButton(
                    onPressed: _loadNotifications,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        else if (_notifications.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'No ticket updates yet',
                style: TextStyle(color: textSecondary),
              ),
            ),
          )
        else
          ..._notifications.map((notification) {
            Ticket? ticket;
            for (final item in _tickets) {
              if (item.id == notification['ticket_id'].toString()) {
                ticket = item;
                break;
              }
            }
            final action =
                notification['action']?.toString() ?? 'Ticket updated';
            final actor = notification['actor_name']?.toString();
            final details = notification['details']?.toString();
            final timestamp = DateTime.tryParse(
              notification['created_at']?.toString() ?? '',
            );
            final isComplete =
                action.contains('resolved') || action.contains('closed');
            final icon = isComplete
                ? Icons.check_circle_outline_rounded
                : action.contains('Note') || action.contains('note')
                ? Icons.note_alt_outlined
                : Icons.sync_outlined;
            final color = isComplete ? success : theme.colorScheme.primary;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: ticket == null
                    ? null
                    : () => _openTicketDetails(ticket!),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  '${notification['ticket_number']}: $action',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if (actor != null && actor.isNotEmpty) actor,
                      if (details != null && details.isNotEmpty) details,
                      if (timestamp != null) _formattedTicketDate(timestamp),
                    ].join('\n'),
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWhatsAppTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        buildUserHeader(context, roleTitle: 'Reporter'),
        Text('WhatsApp Support', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        WhatsAppSupportPanel(onOpen: _openWhatsApp),
      ],
    );
  }

  Widget _supportInfoCard({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(detail),
        ),
      ),
    );
  }

  // --- TAB 4: PROFILE & SETTINGS ---
  Widget _buildProfileTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              TdAvatar(initials: _userInitials, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName.isEmpty ? 'Reporter' : _displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (_userEmail.isNotEmpty)
                      Text(_userEmail, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    const TdPill(
                      label: 'Reporter',
                      background: TdColors.mint,
                      foreground: TdColors.deepTeal,
                      showDot: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TdMenuTile(
          icon: Icons.tune_rounded,
          title: 'Settings',
          subtitle: 'Appearance and app info',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        TdMenuTile(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          color: TdColors.coral,
          onTap: _confirmSignOut,
        ),
      ],
    );
  }

  // --- REUSABLE COMPONENTS ---
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
                width: compact ? 34 : 44,
                height: compact ? 34 : 44,
                decoration: BoxDecoration(
                  color: compact
                      ? const Color(0xFF00A99D)
                      : statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(compact ? 9 : 12),
                ),
                child: Icon(
                  icon,
                  color: compact ? Colors.white : statusColor,
                  size: compact ? 19 : 21,
                ),
              ),
              SizedBox(width: compact ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 15,
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
                    ] else ...[
                      const SizedBox(height: 3),
                      Text(
                        '#${ticket.ticketNumber ?? ticket.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formattedTicketDate(ticket.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (compact) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusChipBackground(ticket.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ticket.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _statusChipForeground(ticket.status),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                      size: 18,
                    ),
                  ],
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

  String _formattedTicketDate(DateTime createdAt) {
    final date = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ticketDay = DateTime(date.year, date.month, date.day);
    if (ticketDay == today) {
      return 'Today, ${TimeOfDay.fromDateTime(date).format(context)}';
    }
    if (ticketDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${TimeOfDay.fromDateTime(date).format(context)}';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (date.year == now.year) {
      return '${months[date.month - 1]} ${date.day}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _statusChipBackground(String status) {
    switch (status) {
      case 'Open':
        return const Color(0xFFFFE3E6);
      case 'In Progress':
        return const Color(0xFFDDF2FF);
      case 'Resolved':
      case 'Closed':
        return const Color(0xFFDDF4E2);
      default:
        return const Color(0xFFE9EDF0);
    }
  }

  Color _statusChipForeground(String status) {
    switch (status) {
      case 'Open':
        return const Color(0xFFD84C5C);
      case 'In Progress':
        return const Color(0xFF1780B1);
      case 'Resolved':
      case 'Closed':
        return const Color(0xFF198653);
      default:
        return const Color(0xFF68747B);
    }
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
