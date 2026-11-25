import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/sound_service.dart';
import '../services/whatsapp_contact.dart';
import '../theme/app_theme.dart';
import '../theme/td_theme.dart';
import '../widgets/td_ticket_widgets.dart';
import '../widgets/td_widgets.dart';
import '../widgets/triagedesk_logo.dart';
import '../widgets/whatsapp_support_panel.dart';
import 'settings_screen.dart';
import 'ticket_details_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  // 0 Home, 1 Assigned, 2 Workload, 3 Tickets, 4 WhatsApp, 5 Profile
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
  bool _dashboardPollInProgress = false;
  bool _ticketRefreshInProgress = false;
  bool _hasLoadedTickets = false;

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
        const Duration(seconds: 5),
        (_) => _pollDashboard(),
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
        SoundService.instance.playNotificationSound();
        final latest = newNotifications.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${latest['ticket_number']}: ${latest['action']}'),
          ),
        );
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

  Future<void> _pollDashboard() async {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_dashboardPollInProgress ||
        !mounted ||
        (state != null && state != AppLifecycleState.resumed)) {
      return;
    }

    _dashboardPollInProgress = true;
    try {
      await Future.wait([
        _refreshTickets(),
        _loadNotifications(detectNew: true),
      ]);
    } finally {
      _dashboardPollInProgress = false;
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

  Future<void> _refreshTickets() async {
    if (_ticketRefreshInProgress) return;
    _ticketRefreshInProgress = true;
    if (mounted && !_hasLoadedTickets) {
      setState(() {
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
      _hasLoadedTickets = true;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      _hasLoadedTickets = true;
    } finally {
      _ticketRefreshInProgress = false;
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
      _tickets.where((t) => t.status == 'In Progress' && t.assignedTechnicianId == _technicianId).length;
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
          attachmentName: ticket.attachmentName,
        ),
      ),
    );
    if (mounted) _refreshTickets();
  }

  List<Ticket> get _mine {
    final id = _technicianId;
    if (id == null) return [];
    return _tickets.where((t) => t.assignedTechnicianId == id).toList();
  }

  Map<String, int> _countsByStatus(List<Ticket> list) => {
    'All': list.length,
    for (final s in _statusFilters.skip(1))
      s: list.where((t) => t.status == s).length,
  };

  // ---- UI --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final initials = ApiService.currentUserInitials;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _currentIndex == 4
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.deepTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const TriageDeskLogo(size: 20),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.4,
                      ),
                      children: const [
                        TextSpan(text: 'Triage'),
                        TextSpan(
                          text: 'Desk',
                          style: TextStyle(color: AppTheme.accentTeal),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          color: colors.onSurface,
                          size: 24,
                        ),
                        onPressed: _openNotifications,
                      ),
                      if (_pendingCount > 0 || _unreadNotificationIds.isNotEmpty)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2574C),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 4),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.deepTeal,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _currentIndex == 4
            ? const SettingsScreen()
            : switch (_currentIndex) {
                1 => _buildAssignedTab(),
                2 => _buildTicketsTab(),
                3 => _buildWhatsAppTab(),
                _ => _buildHomeTab(),
              },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex > 4 ? 0 : _currentIndex,
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

  // ---------------------------------------------------------------------------
  // Home Tab (Matching User UI Image)
  // ---------------------------------------------------------------------------
  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final initials = ApiService.currentUserInitials;
    final available = _availableTickets;
    final recent = (_tickets.toList()
          ..sort((a, b) => tdLastTouched(b).compareTo(tdLastTouched(a))))
        .take(3)
        .toList();

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _refreshTickets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // 1. Hero Technician Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF042D34),
                  Color(0xFF07454E),
                  Color(0xFF0A8F86),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06505A).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF7FE3D6),
                          width: 2.5,
                        ),
                        color: const Color(0xFF073C42),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E9D6B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF042D34),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _technicianName.isEmpty ? 'Technician' : _technicianName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _technicianEmail.isNotEmpty
                            ? _technicianEmail
                            : 'technician@triagedesk.app',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.build_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Technician',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headset_mic_outlined,
                      color: Colors.white.withValues(alpha: 0.45),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here to keep\ncampus connected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 9.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Metric Stat Cards Row (3 Elevated Cards)
          Row(
            children: [
              Expanded(
                child: _HeroMetricCard(
                  icon: Icons.confirmation_number_outlined,
                  iconColor: AppTheme.accentTeal,
                  count: '$_assignedCount',
                  label: 'Assigned\nto me',
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetricCard(
                  icon: Icons.sync_rounded,
                  iconColor: const Color(0xFF2F7FC1),
                  count: '$_progressCount',
                  label: 'In progress',
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetricCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF2E9D6B),
                  count: '$_pendingCount',
                  label: 'Available',
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 4. "Available to claim" Section
          _HeaderRow(
            title: 'Available to claim',
            actionLabel: 'View all',
            onAction: () => setState(() => _currentIndex = 3),
          ),
          const SizedBox(height: 12),
          if (_loadingOrError() != null)
            _loadingOrError()!
          else if (available.isEmpty)
            const TdEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No unassigned tickets',
              message: 'All incoming tickets have been claimed by technicians.',
            )
          else
            for (final t in available.take(2))
              _ClaimTicketCard(
                ticket: t,
                onTap: () => _openTicket(t),
                onAccept: () => _acceptTicket(t),
                isAccepting: _acceptingTicketIds.contains(t.id),
              ),

          const SizedBox(height: 24),

          // 5. "Recent Activity" Section
          _HeaderRow(
            title: 'Recent Activity',
            actionLabel: 'View all',
            onAction: () => _openNotifications(),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              'No recent ticket activity.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final t in recent)
              _ActivityTile(
                initials: ApiService.currentUserInitials,
                name: t.reporterName ?? t.lastModifiedBy ?? 'Reporter Seline',
                action: t.lastModifiedBy == null
                    ? 'Updated ticket status: ${t.status}'
                    : '${t.lastModifiedBy} updated ticket',
                categoryAndTime:
                    '${t.category} • ${tdFormatDateTime(context, tdLastTouched(t))}',
                timeBadge: tdTimeAgo(tdLastTouched(t)),
                onTap: () => _openTicket(t),
              ),

          const SizedBox(height: 28),

          // 6. Footer Branding
          Row(
            children: [
              Expanded(child: Divider(color: theme.dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'TriageDesk • IT support, made simpler.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.dividerColor)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Workload Analysis Tab (Shows each technician's tickets, %, and resolution rate)


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

}

// ---------------------------------------------------------------------------
// Header Row Widget with vertical teal bar indicator
// ---------------------------------------------------------------------------
class _HeaderRow extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _HeaderRow({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.accentTeal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentTeal,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppTheme.accentTeal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Metric Card Component
// ---------------------------------------------------------------------------
class _HeroMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String count;
  final String label;
  final VoidCallback onTap;

  const _HeroMetricCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Claim Ticket Card Widget (Matching Image Design)
// ---------------------------------------------------------------------------
class _ClaimTicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final bool isAccepting;

  const _ClaimTicketCard({
    required this.ticket,
    required this.onTap,
    required this.onAccept,
    this.isAccepting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = ticket.priority.toLowerCase() == 'critical';
    final isHigh = ticket.priority.toLowerCase() == 'high';
    final stripColor = isCritical
        ? const Color(0xFFE2574C)
        : isHigh
            ? const Color(0xFFE8A13A)
            : AppTheme.accentTeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tdTicketLabel(ticket),
                            style: TdFonts.monoStyle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentTeal,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF1DC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Color(0xFF9A6112),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ticket.status,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9A6112),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ticket.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (ticket.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          ticket.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.wifi_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ticket.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '|',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: stripColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 12,
                                  color: stripColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  ticket.priority,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: stripColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tdFormatDateTime(context, ticket.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 38,
                            child: FilledButton.icon(
                              onPressed: isAccepting ? null : onAccept,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.deepTeal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: isAccepting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                    ),
                              label: const Text(
                                'Accept ticket',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Tile Component (Matching Image Design)
// ---------------------------------------------------------------------------
class _ActivityTile extends StatelessWidget {
  final String initials;
  final String name;
  final String action;
  final String categoryAndTime;
  final String timeBadge;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.initials,
    required this.name,
    required this.action,
    required this.categoryAndTime,
    required this.timeBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.accentTeal,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryAndTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F3F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  timeBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
