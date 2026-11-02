import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import '../widgets/user_header.dart';
import 'admin_users_screen.dart';
import 'settings_screen.dart';
import 'ticket_details_screen.dart';

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
  int _currentIndex = 0;
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _loadError;

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
          lastModifiedAt: ticket.lastModifiedAt ?? ticket.updatedAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tickets = _tickets;

    final total = tickets.length;
    final open = tickets.where((t) => t.status == 'Open').length;
    final inProgress = tickets.where((t) => t.status == 'In Progress').length;
    final now = DateTime.now();
    final resolvedToday = tickets.where((ticket) {
      final resolvedAt = ticket.resolvedAt;
      return ticket.status == 'Resolved' &&
          resolvedAt != null &&
          resolvedAt.year == now.year &&
          resolvedAt.month == now.month &&
          resolvedAt.day == now.day;
    }).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colors.onSurface,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const TriageDeskLogo(size: 32),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 24),
                Positioned(
                  right: 0,
                  top: 2,
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
            const SizedBox(width: 10),
            Tooltip(
              message: ApiService.currentUserEmail.isEmpty
                  ? ApiService.currentUserName
                  : '${ApiService.currentUserName}\n${ApiService.currentUserEmail}',
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.accentTeal,
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
            const SizedBox(width: 16),
          ],
        ),
      ),
      body: switch (_currentIndex) {
        1 =>
          _isLoading && tickets.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null && tickets.isEmpty
              ? _buildLoadError(colors)
              : AdminTicketsScreen(tickets: tickets, onRefresh: _loadTickets),
        3 => AdminReportsScreen(tickets: tickets),
        _ =>
          _isLoading && tickets.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null && tickets.isEmpty
              ? _buildLoadError(colors)
              : _buildHomeTab(total, open, inProgress, resolvedToday, tickets),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        onTap: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
            );
          } else {
            setState(() => _currentIndex = index);
          }
        },
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
            icon: Icon(Icons.people_outline_rounded),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 42, color: colors.error),
            const SizedBox(height: 12),
            const Text(
              'Could not load dashboard data',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadTickets,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
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
    final colors = theme.colorScheme;
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
      final age = startOfToday
          .difference(
            DateTime(
              ticket.createdAt.year,
              ticket.createdAt.month,
              ticket.createdAt.day,
            ),
          )
          .inDays;
      if (age >= 0 && age < volume.length) volume[volume.length - 1 - age]++;
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadTickets,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildUserHeader(context, roleTitle: 'Administrator', color: adminBlue),
            const Text(
              'Admin Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              ApiService.currentUserEmail.isEmpty
                  ? 'Signed in as ${ApiService.currentUserName}'
                  : '${ApiService.currentUserName} · ${ApiService.currentUserEmail}',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _adminStatCard(
                    'Total Tickets',
                    '$total',
                    Icons.confirmation_number_outlined,
                    colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _adminStatCard(
                    'Open',
                    '$open',
                    Icons.inbox_outlined,
                    adminRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _adminStatCard(
                    'In Progress',
                    '$inProgress',
                    Icons.access_time_rounded,
                    colors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _adminStatCard(
                    'Resolved Today',
                    '$resolvedToday',
                    Icons.check_circle_outline_rounded,
                    AppTheme.accentTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ticket Volume',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: const Row(
                    children: [
                      Text('Last 7 days', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 190,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ChartPainter(
                        primaryColor: colors.primary,
                        values: volume,
                        gridColor: colors.outlineVariant,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final date = startOfToday.subtract(
                            Duration(days: 6 - index),
                          );
                          return Text(
                            '${date.month}/${date.day}',
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tickets by Category',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final category in [
                          'Network',
                          'Hardware',
                          'Software',
                          'Access',
                          'Other',
                        ])
                          _categoryBreakdownRow(
                            category,
                            '${categoryCounts[category] ?? 0}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tickets by Priority',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _priorityDotRow(
                          'High',
                          '${priorityCounts['High']}',
                          adminRed,
                        ),
                        const SizedBox(height: 12),
                        _priorityDotRow(
                          'Medium',
                          '${priorityCounts['Medium']}',
                          AppTheme.warningGold,
                        ),
                        const SizedBox(height: 12),
                        _priorityDotRow(
                          'Low',
                          '${priorityCounts['Low']}',
                          AppTheme.accentTeal,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Tickets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tickets.isEmpty)
              const Center(child: Text('No tickets available'))
            else
              ...tickets.take(2).map(_adminTicketCard),
          ],
        ),
      ),
    );
  }

  Widget _adminStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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

  Widget _categoryBreakdownRow(String label, String count) {
    final icon = switch (label) {
      'Network' => Icons.wifi_rounded,
      'Hardware' => Icons.laptop_outlined,
      'Software' => Icons.settings_outlined,
      'Access' => Icons.person_outline_rounded,
      _ => Icons.more_horiz_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.accentTeal),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text(
            count,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _priorityDotRow(String label, String count, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text(
            count,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _adminTicketCard(Ticket ticket) {
    final theme = Theme.of(context);
    final categoryIcon = switch (ticket.category.toLowerCase()) {
      'network' => Icons.wifi_rounded,
      'hardware' => Icons.laptop_outlined,
      'software' => Icons.settings_outlined,
      'email' => Icons.email_outlined,
      _ => Icons.confirmation_number_outlined,
    };
    final age = DateTime.now().difference(ticket.createdAt);
    final ageLabel = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
        ? '${age.inHours}h ago'
        : '${age.inMinutes.clamp(1, 59)}m ago';
    final priorityColor =
        ticket.priority.toLowerCase() == 'critical' ||
            ticket.priority.toLowerCase() == 'high'
        ? adminRed
        : ticket.priority.toLowerCase() == 'medium'
        ? AppTheme.warningGold
        : AppTheme.accentTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTicketDetails(ticket),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(categoryIcon, color: AppTheme.accentTeal, size: 20),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ticket.id}  ·  ${ticket.priority}',
                      style: TextStyle(fontSize: 11, color: priorityColor),
                    ),
                  ],
                ),
              ),
              Text(
                ageLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Color primaryColor;
  final List<int> values;
  final Color gridColor;

  _ChartPainter({
    required this.primaryColor,
    required this.values,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 18;
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = chartHeight * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maximum = values.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );
    final scale = maximum == 0 ? 1 : maximum;
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = primaryColor;
    final points = List.generate(values.length, (index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = chartHeight - (chartHeight * values[index] / scale);
      return Offset(x, y);
    });
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.24),
            primaryColor.withValues(alpha: 0.01),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, paint);
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.values != values;
}

// ============================================================
// ALL TICKETS
// ============================================================

class AdminTicketsScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final Future<void> Function() onRefresh;

  const AdminTicketsScreen({
    super.key,
    required this.tickets,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          buildUserHeader(context, roleTitle: 'Administrator', color: adminBlue),
          const Text(
            'All Tickets',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${tickets.length} tickets',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('No tickets available')),
            )
          else
            ...tickets.map((ticket) => _TicketListTile(ticket: ticket)),
        ],
      ),
    );
  }
}

class _TicketListTile extends StatelessWidget {
  final Ticket ticket;

  const _TicketListTile({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.confirmation_number_outlined,
          color: colors.primary,
        ),
        title: Text(ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${ticket.id} · ${ticket.category} · ${ticket.status}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailsScreen(
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
        ),
      ),
    );
  }
}

class AdminReportsScreen extends StatelessWidget {
  final List<Ticket> tickets;

  const AdminReportsScreen({super.key, required this.tickets});

  @override
  Widget build(BuildContext context) {
    final statusCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    for (final ticket in tickets) {
      statusCounts.update(
        ticket.status,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      categoryCounts.update(
        ticket.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        buildUserHeader(context, roleTitle: 'Administrator', color: adminBlue),
        const Text(
          'Reports',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ticket overview and breakdown',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.confirmation_number_outlined,
              color: colors.primary,
            ),
            title: const Text('Total tickets'),
            trailing: Text(
              '${tickets.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        for (final entry in statusCounts.entries)
          Card(
            child: ListTile(
              leading: Icon(Icons.circle, size: 12, color: colors.primary),
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'By category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final entry in categoryCounts.entries)
          Card(
            child: ListTile(
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
          ),
      ],
    );
  }
}
