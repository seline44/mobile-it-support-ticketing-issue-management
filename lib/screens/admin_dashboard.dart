import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/report_export_service.dart';
import '../theme/td_theme.dart';
import '../widgets/td_ticket_widgets.dart';
import '../widgets/td_widgets.dart';
import 'admin_users_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'ticket_details_screen.dart';

// Kept for any other file that imports these names from here.
const Color adminNavy = TdColors.deepTeal;
const Color adminBlue = TdColors.teal;
const Color adminGreen = TdColors.green;
const Color adminAmber = TdColors.amber;
const Color adminRed = TdColors.coral;

Future<void> _openTicketDetails(
  BuildContext context,
  Ticket ticket, {
  VoidCallback? onReturn,
}) async {
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
  onReturn?.call();
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _loadError;
  int _pendingApprovals = 0;
  List<Map<String, dynamic>> _whatsAppNotifications = [];
  final Set<int> _unreadWhatsAppNotificationIds = {};
  Timer? _notificationTimer;
  bool _notificationsInitialized = false;
  String? _notificationError;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTest) {
      _loadPendingApprovals();
      _loadWhatsAppNotifications();
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadWhatsAppNotifications(detectNew: true),
      );
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // ---- Data logic ------------------------------------------------------------
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
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  /// Best effort: powers the "accounts waiting" banner. Errors are ignored so
  /// the dashboard still works if the users endpoint is unavailable.
  Future<void> _loadPendingApprovals() async {
    try {
      final users = await ApiService.getAllUsers();
      final pending = users.where((u) {
        if (u is! Map) return false;
        final s = (u['approval_status'] ?? 'Pending')
            .toString()
            .trim()
            .toLowerCase();
        return s.isEmpty || s == 'pending';
      }).length;
      if (!mounted) return;
      setState(() => _pendingApprovals = pending);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadTickets(),
      _loadPendingApprovals(),
      _loadWhatsAppNotifications(detectNew: true),
    ]);
  }

  Future<void> _loadWhatsAppNotifications({bool detectNew = false}) async {
    try {
      final response = await ApiService.getWhatsAppTicketNotifications();
      final notifications = response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final previousIds = _whatsAppNotifications
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
        _whatsAppNotifications = notifications;
        _notificationError = null;
        for (final notification in newNotifications) {
          final id = int.tryParse(notification['id'].toString());
          if (id != null) _unreadWhatsAppNotificationIds.add(id);
        }
        _notificationsInitialized = true;
      });

      if (newNotifications.isNotEmpty) {
        await _loadTickets();
        if (!mounted) return;
        final latest = newNotifications.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New WhatsApp ticket ${latest['ticket_number']}: ${latest['title']}',
            ),
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

  Future<void> _openNotifications() async {
    await _refreshAll();
    if (!mounted) return;
    setState(() => _unreadWhatsAppNotificationIds.clear());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_pendingApprovals > 0)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(
                    '$_pendingApprovals account'
                    '${_pendingApprovals == 1 ? '' : 's'} awaiting review',
                  ),
                ),
              if (_notificationError != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_notificationError!),
                )
              else if (_whatsAppNotifications.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'No tickets have been raised through WhatsApp yet.',
                  ),
                )
              else
                ..._whatsAppNotifications.map((notification) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(notification['ticket_number'].toString()),
                    subtitle: Text(notification['title'].toString()),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (_pendingApprovals > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openUsers();
              },
              child: const Text('Review accounts'),
            ),
          if (_whatsAppNotifications.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() => _currentIndex = 1);
              },
              child: const Text('View tickets'),
            ),
        ],
      ),
    );
  }

  Future<void> _openUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
    );
    if (mounted) _loadPendingApprovals();
  }

  Future<void> _signOut() async {
    final confirmed = await showTdSignOutDialog(context);
    if (confirmed && mounted) {
      ApiService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _openAccountSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TdAvatar(initials: ApiService.currentUserInitials, size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ApiService.currentUserName.isEmpty
                              ? 'Administrator'
                              : ApiService.currentUserName,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (ApiService.currentUserEmail.isNotEmpty)
                          Text(
                            ApiService.currentUserEmail,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TdMenuTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                color: TdColors.coral,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- UI --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final tickets = _tickets;

    final total = tickets.length;
    final open = tickets.where((t) => t.status == 'Open').length;
    final inProgress = tickets.where((t) => t.status == 'In Progress').length;
    final now = DateTime.now();
    final resolvedToday = tickets.where((ticket) {
      final resolvedAt = ticket.resolvedAt?.toLocal();
      return ticket.status == 'Resolved' &&
          resolvedAt != null &&
          resolvedAt.year == now.year &&
          resolvedAt.month == now.month &&
          resolvedAt.day == now.day;
    }).length;

    final Widget body = switch (_currentIndex) {
      1 =>
        _isLoading && tickets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && tickets.isEmpty
            ? _buildLoadError()
            : AdminTicketsScreen(tickets: tickets, onRefresh: _loadTickets),
      3 => AdminReportsScreen(tickets: tickets),
      _ =>
        _isLoading && tickets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && tickets.isEmpty
            ? _buildLoadError()
            : _buildHomeTab(total, open, inProgress, resolvedToday, tickets),
    };

    return Scaffold(
      appBar: TdBrandedAppBar(
        initials: ApiService.currentUserInitials,
        showNotificationDot:
            _pendingApprovals > 0 || _unreadWhatsAppNotificationIds.isNotEmpty,
        onNotificationsTap: _openNotifications,
        onAvatarTap: _openAccountSheet,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            TdUserHeader(
              name: ApiService.currentUserName.isEmpty
                  ? 'Administrator'
                  : ApiService.currentUserName,
              role: 'Administrator',
              email: ApiService.currentUserEmail,
              initials: ApiService.currentUserInitials,
              onAvatarTap: _openAccountSheet,
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          } else if (index == 2) {
            _openUsers();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TdEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load dashboard data',
          message: _loadError ?? 'Please check your connection and try again.',
          actionLabel: 'Try again',
          onAction: _loadTickets,
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    int total,
    int open,
    int inProgress,
    int resolvedToday,
    List<Ticket> tickets,
  ) {
    final theme = Theme.of(context);

    final categoryCounts = <String, int>{};
    final priorityCounts = <String, int>{'High': 0, 'Medium': 0, 'Low': 0};
    final volume = List<int>.filled(7, 0);
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    for (final ticket in tickets) {
      final category = switch (ticket.category.toLowerCase()) {
        'network' => 'Network',
        'hardware' => 'Hardware',
        'software' => 'Software',
        'email' || 'account access' || 'access' => 'Access',
        _ => 'Other',
      };
      categoryCounts.update(category, (count) => count + 1, ifAbsent: () => 1);
      final priority = switch (ticket.priority.toLowerCase()) {
        'critical' || 'high' => 'High',
        'medium' => 'Medium',
        _ => 'Low',
      };
      priorityCounts.update(priority, (count) => count + 1);
      final createdAt = ticket.createdAt.toLocal();
      final age = startOfToday
          .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
          .inDays;
      if (age >= 0 && age < volume.length) volume[volume.length - 1 - age]++;
    }

    final newThisWeek = volume.fold<int>(0, (a, b) => a + b);
    final openCritical = tickets
        .where(
          (t) => t.status == 'Open' && t.priority.toLowerCase() == 'critical',
        )
        .length;
    final techs = tickets
        .where(
          (t) => t.status == 'In Progress' && t.assignedTechnicianId != null,
        )
        .map((t) => t.assignedTechnicianId)
        .toSet()
        .length;

    final recent =
        (tickets.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .take(3)
            .toList();

    final categoryEntries = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCategory = categoryEntries.isEmpty
        ? 1
        : categoryEntries.first.value;

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 20),
        children: [
          Text('Overview', style: tdDashboardTitleStyle(context)),
          const SizedBox(height: 2),
          Text(
            _pendingApprovals > 0
                ? '$_pendingApprovals account${_pendingApprovals == 1 ? ' is' : 's are'} waiting for your approval.'
                : 'Here\'s how support is doing.',
            style: tdDashboardSubtitleStyle(context),
          ),
          const SizedBox(height: 14),

          if (_pendingApprovals > 0) ...[
            _ApprovalBanner(count: _pendingApprovals, onTap: _openUsers),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  value: total,
                  label: 'Total tickets',
                  note: '+$newThisWeek this week',
                  color: TdColors.teal,
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  value: open,
                  label: 'Open',
                  note: '$openCritical critical',
                  color: TdColors.coral,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  value: inProgress,
                  label: 'In progress',
                  note: techs == 0
                      ? 'unassigned'
                      : 'with $techs tech${techs == 1 ? '' : 's'}',
                  color: TdColors.blue,
                  icon: Icons.build_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  value: resolvedToday,
                  label: 'Resolved today',
                  note: 'today',
                  color: TdColors.green,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Ticket volume
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ticket volume', style: theme.textTheme.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Last 7 days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _VolumePainter(
                      color: theme.colorScheme.secondary,
                      gridColor: theme.dividerColor,
                      values: volume,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Text(
                        _weekday(
                          startOfToday.subtract(Duration(days: 6 - i)).weekday,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // By category
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By category', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                if (categoryEntries.isEmpty)
                  Text('No tickets yet.', style: theme.textTheme.bodySmall)
                else
                  for (final e in categoryEntries.take(5))
                    _BarRow(
                      label: e.key,
                      value: e.value,
                      fraction: e.value / maxCategory,
                      color: theme.colorScheme.secondary,
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // By priority
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By priority', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                _StackedBar(
                  segments: [
                    (priorityCounts['High'] ?? 0, TdColors.coral),
                    (priorityCounts['Medium'] ?? 0, TdColors.amber),
                    (priorityCounts['Low'] ?? 0, TdColors.teal),
                  ],
                ),
                const SizedBox(height: 14),
                _LegendRow(
                  label: 'High',
                  value: priorityCounts['High'] ?? 0,
                  color: TdColors.coral,
                ),
                _LegendRow(
                  label: 'Medium',
                  value: priorityCounts['Medium'] ?? 0,
                  color: TdColors.amber,
                ),
                _LegendRow(
                  label: 'Low',
                  value: priorityCounts['Low'] ?? 0,
                  color: TdColors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          TdSectionHeader(
            title: 'Recent tickets',
            actionLabel: 'View all',
            onAction: () => setState(() => _currentIndex = 1),
          ),
          if (recent.isEmpty)
            const TdEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No tickets yet',
              message: 'New tickets will appear here as they come in.',
            )
          else
            for (final t in recent)
              TdTicketCard(
                ticket: t,
                onTap: () =>
                    _openTicketDetails(context, t, onReturn: _loadTickets),
              ),
        ],
      ),
    );
  }

  String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final int value;
  final String label;
  final String note;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.value,
    required this.label,
    required this.note,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              Flexible(
                child: Text(
                  note,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$value', style: TdFonts.monoStyle.copyWith(fontSize: 26)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ApprovalBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TdColors.openBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.how_to_reg_outlined,
                size: 20,
                color: Color(0xFFB97A12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count new account${count == 1 ? '' : 's'} to review',
                  style: const TextStyle(
                    color: Color(0xFF6E4A0F),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Review',
                style: TextStyle(
                  color: Color(0xFF9A6112),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF9A6112),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final double fraction;
  final Color color;
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: theme.dividerColor,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TdFonts.monoStyle.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final List<(int, Color)> segments;
  const _StackedBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (a, s) => a + s.$1);
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: total == 0
            ? Container(color: theme.dividerColor)
            : Row(
                children: [
                  for (final s in segments)
                    if (s.$1 > 0)
                      Expanded(
                        flex: s.$1,
                        child: Container(color: s.$2),
                      ),
                ],
              ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
            ),
          ),
          Text('$value', style: TdFonts.monoStyle.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume chart
// ---------------------------------------------------------------------------
class _VolumePainter extends CustomPainter {
  final Color color;
  final Color gridColor;
  final List<int> values;

  _VolumePainter({
    required this.color,
    required this.gridColor,
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height;
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = (chartHeight - 4) * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maximum = values.fold<int>(0, (a, b) => b > a ? b : a);
    final scale = maximum == 0 ? 1 : maximum;
    final usable = chartHeight - 12;

    final points = List.generate(values.length, (i) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = 6 + usable - (usable * values[i] / scale);
      return Offset(x, y);
    });

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(points[i].dx, points[i].dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight today (last point)
    canvas.drawCircle(points.last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(
      points.last,
      5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _VolumePainter old) =>
      old.color != color || old.gridColor != gridColor || old.values != values;
}

// ============================================================
// ALL TICKETS
// ============================================================
class AdminTicketsScreen extends StatefulWidget {
  final List<Ticket> tickets;
  final Future<void> Function() onRefresh;

  const AdminTicketsScreen({
    super.key,
    required this.tickets,
    required this.onRefresh,
  });

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  static const _filters = [
    'All',
    'Open',
    'In Progress',
    'Pending',
    'Resolved',
    'Closed',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tickets = widget.tickets;
    final query = _search.text.trim().toLowerCase();

    final counts = <String, int>{
      'All': tickets.length,
      for (final f in _filters.skip(1))
        f: tickets.where((t) => t.status == f).length,
    };

    final visible = tickets.where((t) {
      final okFilter = _filter == 'All' || t.status == _filter;
      final okQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          tdTicketLabel(t).toLowerCase().contains(query);
      return okFilter && okQuery;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text('All tickets', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(
            '${tickets.length} in total',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by title, ID or category',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 19),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TdFilterChips(
            options: _filters,
            selected: _filter,
            counts: counts,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            TdEmptyState(
              icon: Icons.search_off_rounded,
              title: tickets.isEmpty
                  ? 'No tickets available'
                  : 'No tickets found',
              message: tickets.isEmpty
                  ? 'New tickets will appear here.'
                  : 'Try a different search or filter.',
            )
          else
            for (final t in visible)
              TdTicketCard(
                ticket: t,
                onTap: () =>
                    _openTicketDetails(context, t, onReturn: widget.onRefresh),
              ),
        ],
      ),
    );
  }
}

// ============================================================
// REPORTS
// ============================================================
class AdminReportsScreen extends StatefulWidget {
  final List<Ticket> tickets;

  const AdminReportsScreen({super.key, required this.tickets});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  TicketReportFormat? _exportingFormat;

  Future<void> _exportReport(TicketReportFormat format) async {
    setState(() => _exportingFormat = format);
    try {
      final saved = await ReportExportService.export(widget.tickets, format);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Report exported successfully.'
                : 'Report export was canceled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not export report: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return TdColors.amber;
      case 'In Progress':
        return TdColors.blue;
      case 'Resolved':
      case 'Closed':
        return TdColors.green;
      case 'Pending':
        return TdColors.muted;
      default:
        return TdColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    for (final ticket in widget.tickets) {
      statusCounts.update(ticket.status, (c) => c + 1, ifAbsent: () => 1);
      categoryCounts.update(ticket.category, (c) => c + 1, ifAbsent: () => 1);
    }

    final total = widget.tickets.length;
    final resolved =
        (statusCounts['Resolved'] ?? 0) + (statusCounts['Closed'] ?? 0);
    final rate = total == 0 ? 0 : (resolved * 100 / total).round();
    final activeNow = widget.tickets.where(tdIsActive).length;

    final statusEntries = statusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryEntries = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCategory = categoryEntries.isEmpty
        ? 1
        : categoryEntries.first.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Text('Reports', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          'Ticket overview and breakdown',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5),
        ),
        const SizedBox(height: 16),
        Text('Download report', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _exportButton(
              format: TicketReportFormat.pdf,
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
            ),
            _exportButton(
              format: TicketReportFormat.word,
              label: 'Word',
              icon: Icons.description_outlined,
            ),
            _exportButton(
              format: TicketReportFormat.excel,
              label: 'Excel',
              icon: Icons.table_chart_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary
        Row(
          children: [
            Expanded(
              child: TdStatCard(
                value: total,
                label: 'Total tickets',
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TdStatCard(
                value: activeNow,
                label: 'Still active',
                color: TdColors.openFg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TdStatCard(
                value: rate,
                label: '% resolved',
                color: TdColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('By status', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              if (statusEntries.isEmpty)
                Text('No tickets yet.', style: theme.textTheme.bodySmall)
              else ...[
                _StackedBar(
                  segments: [
                    for (final e in statusEntries)
                      (e.value, _statusColor(e.key)),
                  ],
                ),
                const SizedBox(height: 14),
                for (final e in statusEntries)
                  _LegendRow(
                    label: e.key,
                    value: e.value,
                    color: _statusColor(e.key),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('By category', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              if (categoryEntries.isEmpty)
                Text('No tickets yet.', style: theme.textTheme.bodySmall)
              else
                for (final e in categoryEntries)
                  _BarRow(
                    label: e.key,
                    value: e.value,
                    fraction: e.value / maxCategory,
                    color: theme.colorScheme.secondary,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exportButton({
    required TicketReportFormat format,
    required String label,
    required IconData icon,
  }) {
    final isExporting = _exportingFormat == format;
    return OutlinedButton.icon(
      onPressed: _exportingFormat == null ? () => _exportReport(format) : null,
      icon: isExporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(isExporting ? 'Preparing...' : label),
    );
  }
}
