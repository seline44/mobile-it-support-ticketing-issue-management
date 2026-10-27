import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: ThemeService.instance,
        builder: (context, _) {
          final currentMode = ThemeService.instance.themeMode;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how TriageDesk looks on your device.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Appearance selector card
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
                        onSelect: () => ThemeService.instance.setThemeMode(
                          ThemeMode.system,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // About card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'About TriageDesk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'TriageDesk v1.0.0\n'
                        'Theme changes take effect instantly across all dashboards, forms, and dialogs.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
