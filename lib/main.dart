import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/triagedesk_logo.dart';
import 'widgets/viewport_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.instance.init();
  runApp(const TriageDeskApp());
}

class TriageDeskApp extends StatelessWidget {
  const TriageDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TriageDesk',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeService.instance.themeMode,
        builder: (context, child) => ViewportWrapper(child: child ?? const SizedBox()),
        home: const WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/254700000000?text=Hi,%20I%20need%20help%20with%20a%20TriageDesk%20issue.');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp. Please check your browser or device.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF08191D) : const Color(0xFFF2F8FA);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      const TriageDeskLogo(size: 80),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Triage', style: TextStyle(color: colors.onSurface)),
                            TextSpan(text: 'Desk', style: TextStyle(color: colors.primary)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IT SUPPORT, MADE SIMPLE',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Something broken?\nWe\'ve got you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Get IT help your way. Report an issue, track a request, or chat with our support team.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary CTA: Chat with us on WhatsApp
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => _launchWhatsApp(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // WhatsApp green
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 20),
                          label: const Text(
                            'Chat with us on WhatsApp',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Divider / "or"
                      Row(
                        children: [
                          Expanded(child: Divider(color: colors.outlineVariant)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: colors.outlineVariant)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Secondary CTA: Sign in
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Sign in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('Already have an account?', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tertiary CTA: Create an account
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Create an account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('Access your personal ticket history', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),
                      Text(
                        'Quick help · Ticket tracking · Technician support',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
