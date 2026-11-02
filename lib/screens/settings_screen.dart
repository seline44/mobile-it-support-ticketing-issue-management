import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/whatsapp_contact.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  void _confirmSignOut(BuildContext context) {
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
              ApiService.logout();
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
    final name = ApiService.currentUserName;
    final email = ApiService.currentUserEmail;
    final initials = ApiService.currentUserInitials;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        leadingWidth: 60,
      ),
      body: AnimatedBuilder(
        animation: ThemeService.instance,
        builder: (context, _) {
          final currentMode = ThemeService.instance.themeMode;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // User Profile Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.accentTeal,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Appearance', style: theme.textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                'Pick what\'s easiest on your eyes. Changes apply instantly.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Visual theme tiles
              Row(
                children: [
                  Expanded(
                    child: _ThemeTile(
                      label: 'Light',
                      mode: ThemeMode.light,
                      selected: currentMode == ThemeMode.light,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeTile(
                      label: 'Dark',
                      mode: ThemeMode.dark,
                      selected: currentMode == ThemeMode.dark,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThemeTile(
                      label: 'Auto',
                      mode: ThemeMode.system,
                      selected: currentMode == ThemeMode.system,
                      onSelect: () =>
                          ThemeService.instance.setThemeMode(ThemeMode.system),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Help & Support Card
              Card(
                child: InkWell(
                  onTap: () => _launchWhatsApp(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F3F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Help & support',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chat with IT support on WhatsApp',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sign Out Card
              Card(
                child: InkWell(
                  onTap: () => _confirmSignOut(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE6E3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFE2574C),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Footer About
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TriageDeskLogo(size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TriageDesk  v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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

    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: GestureDetector(
        onTap: onSelect,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? colors.secondary : theme.dividerColor,
                  width: selected ? 2 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.secondary.withValues(alpha: 0.18),
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    final accent = dark ? AppTheme.accentTeal : AppTheme.accentTeal;

    Widget line(double w) => Container(
          height: 6,
          width: w,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Container(
      color: bg,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 7,
            width: 36,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          line(double.infinity),
          line(46),
          const SizedBox(height: 6),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }
}
