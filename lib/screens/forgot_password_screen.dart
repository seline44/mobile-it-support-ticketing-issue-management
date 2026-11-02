import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final message = await ApiService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
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
          title: const Text('Check your email'),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      String message = error.toString().replaceFirst('Exception: ', '');
      if (message.contains('Connection refused') ||
          message.contains('Failed host lookup') ||
          message.contains('ClientException')) {
        message =
            'Unable to connect to server. Please ensure the backend server is running.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back to sign in',
                    icon: Icon(Icons.arrow_back_rounded,
                        color: colors.onSurface),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(height: 32),

                // Key icon with a small "mail" badge
                Center(
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(Icons.vpn_key_outlined,
                              size: 42, color: colors.primary),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Icon(Icons.mark_email_read_outlined,
                                size: 17, color: colors.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Locked out? It happens.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Enter the email you registered with and we\'ll send a '
                    'link to choose a new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Email address',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _sendResetLink();
                  },
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
                const SizedBox(height: 20),

                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _sendResetLink,
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
                            'Send reset link',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text(
                    'Back to sign in',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 20, color: colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For your security, we show the same message '
                          'whether or not the email has an account.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
