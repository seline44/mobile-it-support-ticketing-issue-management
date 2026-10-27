import 'package:flutter/material.dart';

import 'reporter_dashboard.dart';
import 'technician_dashboard.dart';
import 'admin_dashboard.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),

            const Text(
              'Choose your workspace',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              'Select a role to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryColor, fontSize: 15),
            ),

            const SizedBox(height: 40),

            _roleButton(
              context,
              icon: Icons.person_outline,
              title: 'Reporter',
              subtitle: 'Submit and track support tickets',
              destination: const ReporterDashboard(),
            ),

            const SizedBox(height: 16),

            _roleButton(
              context,
              icon: Icons.engineering_outlined,
              title: 'Technician',
              subtitle: 'Manage and resolve assigned tickets',
              destination: const TechnicianDashboard(),
            ),

            const SizedBox(height: 16),

            _roleButton(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Administrator',
              subtitle: 'Manage support operations and reports',
              destination: const AdminDashboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return SizedBox(
      height: 90,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 35, color: Theme.of(context).colorScheme.primary),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
