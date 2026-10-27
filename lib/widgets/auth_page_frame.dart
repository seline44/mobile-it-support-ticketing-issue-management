import 'package:flutter/material.dart';

import 'triagedesk_logo.dart';

class AuthPageFrame extends StatelessWidget {
  final Widget child;
  final Widget? topLeading;

  const AuthPageFrame({super.key, required this.child, this.topLeading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark
        ? const Color(0xFF08191D)
        : const Color(0xFFF2F8FA);

    return Scaffold(
      backgroundColor: pageColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  topLeading == null ? 24 : 56,
                  24,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - (topLeading == null ? 48 : 80),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            if (topLeading != null)
              Positioned(left: 16, top: 4, child: topLeading!),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool centeredBrand;

  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.centeredBrand = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: centeredBrand
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (centeredBrand) ...[
          const TriageDeskLogo(size: 80),
          const SizedBox(height: 8),
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
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ] else
          Row(
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        SizedBox(height: centeredBrand ? 20 : 24),
        Text(
          title,
          textAlign: centeredBrand ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: centeredBrand ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

InputDecoration authInputDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fillColor = isDark ? const Color(0xFF122D33) : const Color(0xFFEDF5F7);
  final borderColor = isDark
      ? const Color(0xFF29464D)
      : const Color(0xFFC8DCE1);
  final iconColor = isDark ? const Color(0xFFB2C7CB) : const Color(0xFF557078);
  final shape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide(color: borderColor),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: iconColor, fontSize: 13),
    prefixIcon: Icon(icon, color: iconColor, size: 19),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: shape,
    enabledBorder: shape,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
  );
}
