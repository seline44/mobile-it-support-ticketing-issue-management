import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/whatsapp_contact.dart';
import '../theme/td_theme.dart';
import '../widgets/td_ticket_widgets.dart';
import '../widgets/td_widgets.dart';
import '../widgets/whatsapp_support_panel.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'ticket_details_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  // 0 Home, 1 Assigned, 2 Tickets, 3 WhatsApp, 4 Profile
  int _currentIndex = 0;

  List<Ticket> _tickets = [];
  final Set<String> _acceptingTicketIds = {};
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];
  final Set<int> _unreadNotificationIds = {};
  Timer? _notificationTimer;
  bool _notificationsInitialized = false;
  String? _notificationError;
  Future<void>? _notificationLoad;

  String _assignedFilter = 'All';
  String _ticketFilter = 'All';
  final _searchController = TextEditingController();

  static const _statusFilters = [
    'All',
    'Open',
    'In Progress',
    'Pending',
    'Resolved',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _refreshTickets();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTest) {
      _loadNotifications();
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadNotifications(detectNew: true),
      );
    }
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
    setState(() => _unreadNotificationIds.clear());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 420,
          child: _notificationError != null
              ? Text(_notificationError!)
              : _notifications.isEmpty
              ? const Text('No ticket updates yet.')
              : ListView(
                  shrinkWrap: true,
                  children: _notifications.map((notification) {
                    final details = notification['details']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: Text(
                        '${notification['ticket_number']}: '
                        '${notification['action']}',
                      ),
                      subtitle: Text(
                        [
                          if (details != null && details.isNotEmpty) details,
                          if (notification['ticket_title'] != null)
                            notification['ticket_title'].toString(),
                        ].join('\n'),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---- Data logic (unchanged) ----------------------------------------------
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

  List<Ticket> get _availableTickets => _tickets
      .where(
        (ticket) =>
            (ticket.status == 'Open' || ticket.status == 'Pending') &&
            ticket.assignedTechnicianId == null,
      )
      .toList();

  Future<void> _acceptTicket(Ticket ticket) async {
    final ticketId = int.tryParse(ticket.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept this ticket.')),
      );
      return;
    }

    setState(() => _acceptingTicketIds.add(ticket.id));
    try {
      final response = await ApiService.acceptTicket(ticketId);
      final acceptedTicket = Ticket.fromJson(response);
      if (!mounted) return;

      setState(() {
        _tickets = _tickets
            .map((item) => item.id == ticket.id ? acceptedTicket : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tdTicketLabel(ticket)} accepted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _acceptingTicketIds.remove(ticket.id));
      }
    }
  }

  Future<void> _openTicket(Ticket ticket) async {
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
          createdAt: ticket.createdAt,
          lastModifiedAt: ticket.lastModifiedAt ?? ticket.updatedAt,
          resolvedAt: ticket.resolvedAt,
        ),
      ),
    );
    // The technician may have changed the ticket, so refresh on return.
    if (mounted) _refreshTickets();
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showTdSignOutDialog(context);
    if (shouldSignOut && mounted) {
      ApiService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ---- Derived data ----------------------------------------------------------
  /// Tickets assigned to this technician (never matches when id is unknown).
  List<Ticket> get _mine {
    final id = _technicianId;
    if (id == null) return [];
    return _tickets.where((t) => t.assignedTechnicianId == id).toList();
  }

  List<Ticket> get _myActive => _mine.where(tdIsActive).toList();

  /// Most urgent active ticket: highest priority, then oldest first.
  Ticket? get _upNext {
    final active = _myActive;
    if (active.isEmpty) return null;
    active.sort((a, b) {
      final byPriority = TdSignalBars.levelFor(b.priority)
          .compareTo(TdSignalBars.levelFor(a.priority));
      if (byPriority != 0) return byPriority;
      return a.createdAt.compareTo(b.createdAt);
    });
    return active.first;
  }

  String get _firstName {
    final name = _technicianName.trim();
    if (name.isEmpty) return 'there';
    return name.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Map<String, int> _countsByStatus(List<Ticket> list) => {
    'All': list.length,
    for (final s in _statusFilters.skip(1))
      s: list.where((t) => t.status == s).length,
  };

  // ---- UI --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TdBrandedAppBar(
        initials: ApiService.currentUserInitials,
        showNotificationDot:
            _pendingCount > 0 || _unreadNotificationIds.isNotEmpty,
        onNotificationsTap: _openNotifications,
        onAvatarTap: () => setState(() => _currentIndex = 4),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            TdUserHeader(
              name: _technicianName.isEmpty ? 'Technician' : _technicianName,
              role: 'Technician',
              email: _technicianEmail,
              initials: ApiService.currentUserInitials,
              onAvatarTap: () => setState(() => _currentIndex = 4),
            ),
            Expanded(
              child: switch (_currentIndex) {
                1 => _buildAssignedTab(),
                2 => _buildTicketsTab(),
                3 => _buildWhatsAppTab(),
                4 => _buildProfileTab(),
                _ => _buildHomeTab(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_ind_outlined),
            selectedIcon: Icon(Icons.assignment_ind_rounded),
            label: 'Assigned',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'WhatsApp',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Text('WhatsApp Support', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        WhatsAppSupportPanel(onOpen: _openWhatsApp),
      ],
    );
  }

  // ---- Shared body states ----------------------------------------------------
  Widget? _loadingOrError() {
    if (_loading && _tickets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _tickets.isEmpty) {
      return TdEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load tickets',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _refreshTickets,
      );
    }
    return null;
  }

  // ---- Home --------------------------------------------------------------------
  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final next = _upNext;
    final others = _myActive.where((t) => !identical(t, next)).take(3).toList();
    final urgent = _myActive
        .where((t) => TdSignalBars.levelFor(t.priority) >= 3)
        .length;

    final recent =
        (_tickets.toList()
              ..sort((a, b) => tdLastTouched(b).compareTo(tdLastTouched(a))))
            .take(3)
            .toList();
    final available = _availableTickets.take(3).toList();

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 20),
        children: [
          Text(
            '$_greeting, $_firstName.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tdDashboardTitleStyle(context),
          ),
          const SizedBox(height: 4),
          Text(
            urgent > 0
                ? 'You have $urgent ticket${urgent == 1 ? '' : 's'} that need${urgent == 1 ? 's' : ''} attention first.'
                : 'Here\'s what\'s on your plate today.',
            style: tdDashboardSubtitleStyle(context),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TdStatCard(
                  value: _assignedCount,
                  label: 'Assigned',
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TdStatCard(
                  value: _progressCount,
                  label: 'In progress',
                  color: TdColors.progressFg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TdStatCard(
                  value: _pendingCount,
                  label: 'Unclaimed',
                  color: TdColors.openFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loadingOrError() != null)
            _loadingOrError()!
          else ...[
            if (next != null) ...[
              _UpNextCard(ticket: next, onOpen: () => _openTicket(next)),
              const SizedBox(height: 22),
            ],
            if (_mine.isEmpty && available.isEmpty)
              const TdEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Nothing assigned yet',
                message: 'Tickets assigned to you will show up here.',
              )
            else if (others.isNotEmpty) ...[
              TdSectionHeader(
                title: 'Assigned to you',
                actionLabel: 'View all',
                onAction: () => setState(() => _currentIndex = 1),
              ),
              for (final t in others)
                TdTicketCard(ticket: t, onTap: () => _openTicket(t)),
            ],
            if (available.isNotEmpty) ...[
              const SizedBox(height: 14),
              const TdSectionHeader(title: 'Available to claim'),
              for (final t in available)
                TdTicketCard(
                  ticket: t,
                  onTap: () => _openTicket(t),
                  onAccept: () => _acceptTicket(t),
                  isAccepting: _acceptingTicketIds.contains(t.id),
                ),
            ],
            const SizedBox(height: 14),
            const TdSectionHeader(title: 'Recent activity'),
            if (recent.isEmpty)
              Text(
                'No recent ticket activity.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final t in recent)
                TdActivityItem(
                  initials: ApiService.currentUserInitials,
                  action: t.lastModifiedBy == null
                      ? '${tdTicketLabel(t)} · ${t.status}'
                      : '${t.lastModifiedBy} updated ${tdTicketLabel(t)}',
                  description: t.title,
                  time: tdFormatDateTime(context, tdLastTouched(t)),
                ),
          ],
        ],
      ),
    );
  }

  // ---- Assigned ---------------------------------------------------------------
  Widget _buildAssignedTab() {
    final theme = Theme.of(context);
    final mine = _mine;
    final visible = _assignedFilter == 'All'
        ? mine
        : mine.where((t) => t.status == _assignedFilter).toList();

    return RefreshIndicator(
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text('Assigned to me', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),
          TdFilterChips(
            options: _statusFilters,
            selected: _assignedFilter,
            counts: _countsByStatus(mine),
            onSelected: (v) => setState(() => _assignedFilter = v),
          ),
          const SizedBox(height: 16),
          if (_loadingOrError() != null)
            _loadingOrError()!
          else if (visible.isEmpty)
            TdEmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: mine.isEmpty ? 'Nothing assigned yet' : 'No tickets here',
              message: mine.isEmpty
                  ? 'Tickets assigned to you will show up here.'
                  : 'Try a different status filter.',
            )
          else
            for (final t in visible)
              TdTicketCard(
                ticket: t,
                onTap: () => _openTicket(t),
                onAccept: t.status == 'Open' && t.assignedTechnicianId == null
                    ? () => _acceptTicket(t)
                    : null,
                isAccepting: _acceptingTicketIds.contains(t.id),
              ),
        ],
      ),
    );
  }

  // ---- All tickets ----------------------------------------------------------
  Widget _buildTicketsTab() {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();

    final visible = _tickets.where((t) {
      final matchesFilter = _ticketFilter == 'All' || t.status == _ticketFilter;
      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          tdTicketLabel(t).toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text('All tickets', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by title, ID or category',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 19),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TdFilterChips(
            options: _statusFilters,
            selected: _ticketFilter,
            counts: _countsByStatus(_tickets),
            onSelected: (v) => setState(() => _ticketFilter = v),
          ),
          const SizedBox(height: 16),
          if (_loadingOrError() != null)
            _loadingOrError()!
          else if (visible.isEmpty)
            const TdEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No tickets found',
              message: 'Try a different search or filter.',
            )
          else
            for (final t in visible)
              TdTicketCard(
                ticket: t,
                onTap: () => _openTicket(t),
                onAccept: (t.status == 'Open' || t.status == 'Pending') &&
                        t.assignedTechnicianId == null
                    ? () => _acceptTicket(t)
                    : null,
                isAccepting: _acceptingTicketIds.contains(t.id),
              ),
        ],
      ),
    );
  }

  // ---- Profile ----------------------------------------------------------------
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
              TdAvatar(initials: ApiService.currentUserInitials, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _technicianName.isEmpty ? 'Technician' : _technicianName,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (_technicianEmail.isNotEmpty)
                      Text(_technicianEmail, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    const TdPill(
                      label: 'Technician',
                      background: TdColors.progressBg,
                      foreground: TdColors.progressFg,
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
}

// ---------------------------------------------------------------------------
// "Up next" hero card
// ---------------------------------------------------------------------------
class _UpNextCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onOpen;
  const _UpNextCard({required this.ticket, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF04404A), TdColors.teal],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Up next',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  ticket.priority,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tdTicketLabel(ticket)} · ${ticket.category} · '
            '${tdFormatDateTime(context, ticket.createdAt)}',
            style: TdFonts.monoStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: TdColors.deepTeal,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text('Open ticket'),
            ),
          ),
        ],
      ),
    );
  }
}
