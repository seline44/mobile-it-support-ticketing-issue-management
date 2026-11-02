import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';
import 'admin_dashboard.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'reporter_dashboard.dart';
import 'technician_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final user = Map<String, dynamic>.from(result['user'] as Map);
      final role = user['role']?.toString();
      late final Widget dashboard;

      switch (role) {
        case 'Reporter':
          dashboard = const ReporterDashboard();
          break;
        case 'Technician':
          dashboard = const TechnicianDashboard();
          break;
        case 'Administrator':
          dashboard = const AdminDashboard();
          break;
        default:
          throw Exception('Your account has an unrecognized role.');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // Gradient header with pulse line
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.4, -1),
                  end: Alignment(0.6, 1),
                  colors: [Color(0xFF04404A), AppTheme.accentTeal],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 38,
                    height: 90,
                    child: Opacity(
                      opacity: 0.28,
                      child: CustomPaint(painter: _PulsePainter()),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Back to landing page',
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.maybePop(context),
                              ),
                              const SizedBox(width: 8),
                              const TriageDeskLogo(size: 36),
                              const SizedBox(width: 10),
                              const Text(
                                'TriageDesk',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Welcome back.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pick up your tickets where you left off. A real '
                            'person is always on the other side.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form sheet overlapping the header
            Transform.translate(
              offset: const Offset(0, -32),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email field
                      const Text(
                        'Email address',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'you@school.ac.ke',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Please enter your email address.';
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _isLoading ? null : _login(),
                        decoration: InputDecoration(
                          hintText: 'Your password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Keep me signed in',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    ),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Sign in button
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.deepTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: theme.textTheme.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Google button
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Google sign-in is not configured for this app.',
                                ),
                              ),
                            );
                          },
                          icon: const GoogleLogoWidget(),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New here? ',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 13.5)),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.secondary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Create an account',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 90;

    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final path = Path()
      ..moveTo(p(0, 50).dx, p(0, 50).dy)
      ..lineTo(p(90, 50).dx, p(90, 50).dy)
      ..lineTo(p(104, 20).dx, p(104, 20).dy)
      ..lineTo(p(126, 80).dx, p(126, 80).dy)
      ..lineTo(p(144, 35).dx, p(144, 35).dy)
      ..lineTo(p(156, 50).dx, p(156, 50).dy)
      ..lineTo(p(230, 50).dx, p(230, 50).dy)
      ..lineTo(p(244, 30).dx, p(244, 30).dy)
      ..lineTo(p(264, 75).dx, p(264, 75).dy)
      ..lineTo(p(280, 45).dx, p(280, 45).dy)
      ..lineTo(p(290, 55).dx, p(290, 55).dy)
      ..lineTo(p(390, 55).dx, p(390, 55).dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7FE3D6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoWidget extends StatelessWidget {
  const GoogleLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;
    final strokeWidth = size.width * 0.22;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    void drawArc(Color color, double startDegrees, double sweepDegrees) {
      paint.color = color;
      canvas.drawArc(
        bounds,
        startDegrees * 3.141592653589793 / 180,
        sweepDegrees * 3.141592653589793 / 180,
        false,
        paint,
      );
    }

    drawArc(const Color(0xFFEA4335), 195, 70);
    drawArc(const Color(0xFF4285F4), 265, 130);
    drawArc(const Color(0xFF34A853), 35, 90);
    drawArc(const Color(0xFFFBBC05), 125, 70);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final barHeight = strokeWidth * 0.95;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - 1,
        center.dy - barHeight / 2,
        size.width - size.width * 0.08,
        center.dy + barHeight / 2,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
