import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/auth_page_frame.dart';

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
          title: const Text('Check your email'),
          content: Text(message),
          actions: [
            TextButton(
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
        message = 'Unable to connect to server. Please ensure the backend server is running.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurfaceVariant;

    return AuthPageFrame(
      topLeading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        tooltip: 'Back to sign in',
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurfaceVariant,
          backgroundColor: colors.surface,
          side: BorderSide(color: colors.outlineVariant),
          shape: const CircleBorder(),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(
              title: 'Forgot your password?',
              subtitle: 'Enter your email to receive a password reset link.',
              centeredBrand: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the email address associated with your '
              'TriageDesk account. If the account is eligible, '
              'we will send you a link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: textPrimary),
              onFieldSubmitted: (_) {
                if (!_isLoading) _sendResetLink();
              },
              decoration: authInputDecoration(
                context,
                hint: 'Email address',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Please enter your email address.';
                }

                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Please enter a valid email address.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Text(
                        'Send Reset Link',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Sign In'),
              style: TextButton.styleFrom(foregroundColor: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
