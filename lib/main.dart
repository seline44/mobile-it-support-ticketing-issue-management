import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/login_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/viewport_wrapper.dart';

// ---------------------------------------------------------------------------
// Config: replace with your real WhatsApp support number (country code, no
// plus sign or spaces), e.g. Kenya: 2547XXXXXXXX
// ---------------------------------------------------------------------------
const String kWhatsAppNumber = '254700000000';
const String kWhatsAppPrefill = 'Hi, I need help with an IT issue.';

// Design tokens
const Color _deepTeal = Color(0xFF06505A);
const Color _mintGlow = Color(0xFF7FE3D6);
const Color _whatsApp = Color(0xFF25D366);
const String _sans = 'PlusJakartaSans';
const String _mono = 'JetBrainsMono';

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
        builder: (context, child) =>
            ViewportWrapper(child: child ?? const SizedBox()),
        home: const WelcomeScreen(),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/$kWhatsAppNumber'
      '?text=${Uri.encodeComponent(kWhatsAppPrefill)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _getStarted(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _deepTeal,
      body: Stack(
        children: [
          // Background gradient
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.7, -1.0),
                  radius: 1.4,
                  colors: [
                    Color(0xFF0FA89C),
                    Color(0xFF06505A),
                    Color(0xFF04323A),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Pulse line (brand motif)
          Positioned(
            left: 0,
            right: 0,
            top: height * 0.58,
            height: 120,
            child: Opacity(
              opacity: 0.30,
              child: CustomPaint(painter: _PulsePainter()),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _BrandRow(),
                            const SizedBox(height: 32),
                            const Text(
                              'IT help that feels like\nasking a colleague.',
                              style: TextStyle(
                                fontFamily: _sans,
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Report a problem in a minute, see who\'s '
                              'fixing it, and hear back without chasing '
                              'anyone.',
                              style: TextStyle(
                                fontFamily: _sans,
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const _HowItWorksPanel(),
                            const Spacer(),
                            const SizedBox(height: 24),
                            _WhatsAppCard(onTap: () => _openWhatsApp(context)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: () => _getStarted(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _deepTeal,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Get started',
                                      style: TextStyle(
                                        fontFamily: _sans,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 9),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Text(
                                'By continuing you agree to our Terms and '
                                'Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: _sans,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand row: logo mark + name
// ---------------------------------------------------------------------------
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: CustomPaint(painter: _MarkPainter()),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'TriageDesk',
          style: TextStyle(
            fontFamily: _sans,
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "How it works" glass panel (3 real steps in sequence)
// ---------------------------------------------------------------------------
class _HowItWorksPanel extends StatelessWidget {
  const _HowItWorksPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Column(
        children: [
          _Step(
            number: 1,
            title: 'Tell us what\'s wrong',
            detail: 'Pick a category and add a photo if it helps.',
          ),
          _Step(
            number: 2,
            title: 'A technician picks it up',
            detail: 'You\'ll see their name and every update.',
          ),
          _Step(
            number: 3,
            title: 'Fixed, and you\'re told',
            detail: 'We notify you the moment it\'s resolved.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  final bool isLast;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.13),
                  border: Border.all(color: _mintGlow, width: 1.5),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontFamily: _mono,
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _mintGlow.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: _sans,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: _sans,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WhatsApp card (no sign-in needed)
// ---------------------------------------------------------------------------
class _WhatsAppCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WhatsAppCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _whatsApp.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _whatsApp.withValues(alpha: 0.40)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _whatsApp,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat with us on WhatsApp',
                      style: TextStyle(
                        fontFamily: _sans,
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'No account or sign-in needed',
                      style: TextStyle(
                        fontFamily: _sans,
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9EF0C3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Logo mark: a small heartbeat trace.
class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    final path = Path()
      ..moveTo(2 * sx, 12 * sy)
      ..lineTo(7 * sx, 12 * sy)
      ..lineTo(9.5 * sx, 6 * sy)
      ..lineTo(13.5 * sx, 18 * sy)
      ..lineTo(16 * sx, 12 * sy)
      ..lineTo(22 * sx, 12 * sy);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * sx
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wide decorative pulse line behind the content.
class _PulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 120;

    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final path = Path()
      ..moveTo(p(0, 70).dx, p(0, 70).dy)
      ..lineTo(p(90, 70).dx, p(90, 70).dy)
      ..lineTo(p(104, 36).dx, p(104, 36).dy)
      ..lineTo(p(126, 102).dx, p(126, 102).dy)
      ..lineTo(p(144, 54).dx, p(144, 54).dy)
      ..lineTo(p(156, 70).dx, p(156, 70).dy)
      ..lineTo(p(230, 70).dx, p(230, 70).dy)
      ..lineTo(p(244, 44).dx, p(244, 44).dy)
      ..lineTo(p(264, 98).dx, p(264, 98).dy)
      ..lineTo(p(280, 64).dx, p(280, 64).dy)
      ..lineTo(p(290, 76).dx, p(290, 76).dy)
      ..lineTo(p(390, 76).dx, p(390, 76).dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = _mintGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
