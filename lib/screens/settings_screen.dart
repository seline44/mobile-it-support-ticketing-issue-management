import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/sound_service.dart';
import '../services/theme_service.dart';
import '../services/whatsapp_contact.dart';
import '../theme/app_theme.dart';
import '../widgets/td_widgets.dart';
import '../widgets/triagedesk_logo.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _submittedCount = 0;
  int _resolvedCount = 0;
  int _inProgressCount = 0;
  int _thisMonthCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadTicketStats();
  }

  Future<void> _loadTicketStats() async {
    try {
      final response = await ApiService.getTickets();
      final loaded = response
          .whereType<Map>()
          .map((item) => Ticket.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final now = DateTime.now();
      int resolved = 0;
      int inProgress = 0;
      int thisMonth = 0;

      for (final t in loaded) {
        if (t.status == 'Resolved' || t.status == 'Closed') {
          resolved++;
        } else if (t.status == 'In Progress' || t.status == 'Pending') {
          inProgress++;
        }
        final createdAt = t.createdAt.toLocal();
        if (createdAt.year == now.year && createdAt.month == now.month) {
          thisMonth++;
        }
      }

      if (!mounted) return;
      setState(() {
        _submittedCount = loaded.length;
        _resolvedCount = resolved;
        _inProgressCount = inProgress;
        _thisMonthCount = thisMonth;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/$whatsappSupportNumber'
      '?text=${Uri.encodeComponent(whatsappSupportMessage)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showTdSignOutDialog(context);
    if (!confirmed || !context.mounted) return;

    ApiService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showAppearanceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: ThemeService.instance,
          builder: (context, _) {
            final currentMode = ThemeService.instance.themeMode;
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Appearance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select theme preference for TriageDesk.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeTile(
                            label: 'Light',
                            mode: ThemeMode.light,
                            selected: currentMode == ThemeMode.light,
                            onSelect: () => ThemeService.instance
                                .setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ThemeTile(
                            label: 'Dark',
                            mode: ThemeMode.dark,
                            selected: currentMode == ThemeMode.dark,
                            onSelect: () => ThemeService.instance
                                .setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ThemeTile(
                            label: 'Auto',
                            mode: ThemeMode.system,
                            selected: currentMode == ThemeMode.system,
                            onSelect: () => ThemeService.instance
                                .setThemeMode(ThemeMode.system),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPersonalInformationModal(BuildContext context) {
    final theme = Theme.of(context);
    final user = ApiService.currentUser ?? {};
    final name = ApiService.currentUserName;
    final email = ApiService.currentUserEmail;
    final role = user['role']?.toString() ?? 'Reporter';
    final id = user['id']?.toString() ?? '1024';
    final approval = user['approval_status']?.toString() ?? 'Approved';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _infoRow(theme, 'Full Name', name),
                _infoRow(theme, 'Email Address', email.isNotEmpty ? email : 'Not provided'),
                _infoRow(theme, 'Role', role),
                _infoRow(theme, 'User ID', 'TD-$id'),
                _infoRow(theme, 'Account Status', approval),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showSecurityModal(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Security & Password',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppTheme.accentTeal),
                  ),
                  title: const Text('Account Protection', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Your session is protected with secure JWT authentication.'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset link sent to your email.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_reset_rounded),
                    label: const Text('Reset Password'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNotificationsModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recent updates'),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: const [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('TD-21: Ticket resolved'),
                subtitle: Text('Access restored'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ApiService.currentUser ?? {};
    final name = ApiService.currentUserName;
    final email = ApiService.currentUserEmail;
    final initials = ApiService.currentUserInitials;
    final role = user['role']?.toString() ?? 'Reporter';
    final userId = user['id']?.toString() ?? '1024';

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: canPop ? 8 : 20,
        title: Row(
          children: [
            if (canPop)
              IconButton(
                tooltip: 'Back to landing page',
                icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                onPressed: () => Navigator.maybePop(context),
              ),
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
                  icon: Icon(Icons.notifications_none_rounded, color: colors.onSurface, size: 24),
                  onPressed: () => _openNotificationsModal(context),
                ),
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
            CircleAvatar(
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
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // 1. Hero Profile Card
            // -----------------------------------------------------------------
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
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
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email.isNotEmpty ? email : 'user@triagedesk.app',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
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
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        role,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                        Icons.circle,
                                        size: 8,
                                        color: Color(0xFF2E9D6B),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Active',
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
                          ],
                        ),
                      ),
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      Text(
                        'Member since: Oct 2026',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        '|',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        'ID: TD-$userId',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -----------------------------------------------------------------
            // 2. Metrics Summary Bar Card
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: _isLoadingStats
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.compare_arrows_rounded,
                            iconColor: AppTheme.accentTeal,
                            value: '$_submittedCount',
                            label: 'Tickets Submitted',
                          ),
                        ),
                        Container(width: 1, height: 32, color: theme.dividerColor),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF2E9D6B),
                            value: '$_resolvedCount',
                            label: 'Resolved',
                          ),
                        ),
                        Container(width: 1, height: 32, color: theme.dividerColor),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.access_time_rounded,
                            iconColor: const Color(0xFF2F7FC1),
                            value: '$_inProgressCount',
                            label: 'In Progress',
                          ),
                        ),
                        Container(width: 1, height: 32, color: theme.dividerColor),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.calendar_today_rounded,
                            iconColor: const Color(0xFFE8A13A),
                            value: '$_thisMonthCount',
                            label: 'This Month',
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // 3. PREFERENCES & ACCOUNT Section Header
            // -----------------------------------------------------------------
            Row(
              children: [
                Text(
                  'PREFERENCES & ACCOUNT',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: 14),

            // -----------------------------------------------------------------
            // 4. Action List Tiles
            // -----------------------------------------------------------------
            _AccountTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: 'Theme, colours and display (Light, Dark, Auto)',
              onTap: () => _showAppearanceModal(context),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: SoundService.instance,
              builder: (context, _) => _AccountTile(
                icon: SoundService.instance.soundEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                title: 'Notifications',
                subtitle: SoundService.instance.soundEnabled
                    ? 'Ticket updates and sound alerts (On)'
                    : 'Ticket updates and sound alerts (Muted)',
                onTap: () {
                  final enabled = !SoundService.instance.soundEnabled;
                  SoundService.instance.setSoundEnabled(enabled);
                  if (enabled) {
                    SoundService.instance.playNotificationSound();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        enabled
                            ? 'Audio alert sound enabled'
                            : 'Audio alert sound muted',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _AccountTile(
              icon: Icons.shield_outlined,
              title: 'Security',
              subtitle: 'Password and account security',
              onTap: () => _showSecurityModal(context),
            ),
            const SizedBox(height: 10),
            _AccountTile(
              icon: Icons.person_outline_rounded,
              title: 'Personal Information',
              subtitle: 'Manage your account details',
              onTap: () => _showPersonalInformationModal(context),
            ),
            const SizedBox(height: 10),
            _AccountTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'Chat with IT support on WhatsApp',
              onTap: () => _launchWhatsApp(context),
            ),
            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // 5. Sign Out Button Card
            // -----------------------------------------------------------------
            Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF3B1E1C)
                    : const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2574C).withValues(alpha: 0.25),
                ),
              ),
              child: InkWell(
                onTap: () => _confirmSignOut(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2574C).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFE2574C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Sign out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE2574C),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFE2574C),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // -----------------------------------------------------------------
            // 6. Branding Footer
            // -----------------------------------------------------------------
            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TriageDesk • IT support, made simpler.',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricColumn({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.accentTeal, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onSelect;

  const _ThemeTile({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onSelect,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.secondary : theme.dividerColor,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: mode == ThemeMode.system
                  ? const Row(
                      children: [
                        Expanded(child: _MiniUi(dark: false)),
                        Expanded(child: _MiniUi(dark: true)),
                      ],
                    )
                  : _MiniUi(dark: mode == ThemeMode.dark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniUi extends StatelessWidget {
  final bool dark;
  const _MiniUi({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF10262C) : Colors.white;
    final bar = dark ? const Color(0xFF2A4650) : AppTheme.lightBorder;
    final accent = AppTheme.accentTeal;

    Widget line(double w) => Container(
          height: 5,
          width: w,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            width: 28,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          line(double.infinity),
          line(36),
        ],
      ),
    );
  }
}
