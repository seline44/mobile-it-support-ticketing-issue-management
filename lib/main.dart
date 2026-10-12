import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TriageDeskApp());
}

class TriageDeskApp extends StatelessWidget {
  const TriageDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TriageDesk',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12355B),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
          child: Column(
            children: [
              const Spacer(),

              // App logo
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 28),

              // App name
              const Text(
                'TriageDesk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: navy,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 10),

              // Short tagline
              const Text(
                'IT support, made simpler.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // Supporting description
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Report issues, track requests, and stay updated from one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Feature indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _featureItem(
                    icon: Icons.add_task_rounded,
                    label: 'Report',
                  ),
                  const SizedBox(width: 18),
                  _featureItem(
                    icon: Icons.track_changes_rounded,
                    label: 'Track',
                  ),
                  const SizedBox(width: 18),
                  _featureItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Updates',
                  ),
                ],
              ),

              const Spacer(),

              // Get Started button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 9),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Simple • Organized • Responsive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _featureItem({
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: blue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
      ],
    );
    
from fastapi import FastAPI

app = FastAPI(
    title="TriageDesk API",
    description="Backend API for the TriageDesk IT Support Ticketing System",
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "application": "TriageDesk",
        "message": "Backend is running",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "TriageDesk API",
    }

  }
}