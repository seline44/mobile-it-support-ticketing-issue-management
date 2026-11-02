import 'package:flutter/material.dart';
import '../services/api_service.dart';

Widget buildUserHeader(BuildContext context, {String roleTitle = 'User', Color? color}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final name = ApiService.currentUserName;
  final email = ApiService.currentUserEmail;
  final initials = ApiService.currentUserInitials;
  final role = ApiService.currentUser?['role']?.toString() ?? roleTitle;
  final activeColor = color ?? colors.primary;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: activeColor,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            role,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ),
      ],
    ),
  );
}
