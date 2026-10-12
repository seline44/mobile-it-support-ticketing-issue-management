import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IT Support Overview',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Monitor tickets, SLA performance and workload.',
              style: TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                _statCard('Total', '42'),
                _statCard('Open', '18'),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _statCard('Resolved', '20'),
                _statCard('SLA Risk', '4'),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              'Administration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            _menuItem(
              Icons.confirmation_number_outlined,
              'All Tickets',
            ),

            _menuItem(
              Icons.people_outline,
              'Users and Technicians',
            ),

            _menuItem(
              Icons.speed_outlined,
              'SLA Monitoring',
            ),

            _menuItem(
              Icons.bar_chart_outlined,
              'Reports and Analytics',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}