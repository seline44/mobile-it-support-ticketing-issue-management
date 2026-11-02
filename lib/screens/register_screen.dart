import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/triagedesk_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _role = 'Reporter';
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(dialogContext).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: Theme.of(dialogContext).colorScheme.primary,
              size: 32,
            ),
          ),
          title: const Text('You\'re all set'),
          content: Text(
            result['message']?.toString() ??
                'Your account has been created and is awaiting '
                    'administrator approval.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to sign in'),
            ),
          ],
        ),
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

  int _strength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 12) score++;
    if (v.length >= 16) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'\d').hasMatch(v) || RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      score++;
    }
    if (v.length < 12) return 1; // too short is always "Weak"
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strength = _strength(_passwordController.text);
    const labels = ['', 'Weak', 'Okay', 'Good', 'Strong'];
    const strengthColors = [
      Colors.transparent,
      Color(0xFFE2574C),
      Color(0xFFE8A13A),
      AppTheme.accentTeal,
      Color(0xFF2E9D6B),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Back to sign in',
                      icon: Icon(Icons.arrow_back_rounded,
                          color: colors.onSurface),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.deepTeal,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(
                        child: TriageDeskLogo(size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'It takes about a minute. We\'ll check it and let you in.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),

                // Role cards (replaces the dropdown)
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Reporter',
                        detail: 'Report issues and track fixes',
                        selected: _role == 'Reporter',
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _role = 'Reporter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.build_outlined,
                        title: 'Technician',
                        detail: 'Resolve assigned tickets',
                        selected: _role == 'Technician',
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _role = 'Technician'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Full name
                const Text(
                  'Full name',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Amina Wanjiru',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter your full name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email address
                const Text(
                  'Email address',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'At least 12 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 12) {
                      return 'Password must be at least 12 characters.';
                    }
                    if (value.length > 128) {
                      return 'Password cannot exceed 128 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 1; i <= 4; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= strength
                                ? strengthColors[strength]
                                : theme.dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 4) const SizedBox(width: 6),
                    ],
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      child: Text(
                        labels[strength],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: strengthColors[strength],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Use at least 12 characters. A short sentence works well.',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Confirm password
                const Text(
                  'Confirm password',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isLoading ? null : _register(),
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      tooltip: _hideConfirmPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () => setState(
                          () => _hideConfirmPassword = !_hideConfirmPassword),
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Approval notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF1DC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 18, color: Color(0xFFB97A12)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'An administrator reviews every new account before '
                          'you can sign in.',
                          style: TextStyle(
                            color: Color(0xFF6E4A0F),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Create account button
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _register,
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
                            'Create account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'By creating an account, you agree to our Terms of Service '
                  'and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already registered? ',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        )),
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 13,
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
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.secondary : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon,
                      size: 22,
                      color: selected ? colors.primary : colors.onSurfaceVariant),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? colors.secondary
                            : theme.dividerColor,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  )),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
