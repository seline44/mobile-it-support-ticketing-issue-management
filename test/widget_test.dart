import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triagedesk/main.dart';
import 'package:triagedesk/screens/forgot_password_screen.dart';
import 'package:triagedesk/screens/login_screen.dart';
import 'package:triagedesk/screens/register_screen.dart';
import 'package:triagedesk/screens/reporter_dashboard.dart';
import 'package:triagedesk/services/theme_service.dart';
import 'package:triagedesk/theme/app_theme.dart';
import 'package:triagedesk/widgets/triagedesk_logo.dart';

void main() {
  test('Roboto is the font for both app themes', () {
    expect(AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    expect(AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    expect(AppTheme.lightTheme.textTheme.titleLarge?.fontFamily, 'Roboto');
    expect(AppTheme.darkTheme.textTheme.titleLarge?.fontFamily, 'Roboto');
  });

  test('Teal is the primary color across light and dark themes', () {
    expect(AppTheme.lightTheme.colorScheme.primary, AppTheme.accentTeal);
    expect(AppTheme.darkTheme.colorScheme.primary, AppTheme.accentTeal);
  });

  testWidgets('TriageDeskApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TriageDeskApp());
    expect(find.bySemanticsLabel('TriageDesk logo'), findsOneWidget);
    expect(find.text('TriageDesk'), findsOneWidget);
    expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
    expect(find.text("Something broken?\nWe've got you."), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);

    final logo = tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo));
    expect(logo.size, 80);

    final headline = tester.widget<Text>(find.text("Something broken?\nWe've got you."));
    expect(headline.style?.fontSize, lessThanOrEqualTo(34));
  });

  testWidgets('login keeps account creation and password recovery actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TriageDeskApp());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo)).size, 80);
    expect(find.byType(GoogleLogoWidget), findsOneWidget);

    final welcomeHeading = tester.widget<Text>(find.text('Welcome back'));
    expect(welcomeHeading.style?.fontSize, lessThanOrEqualTo(28));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back to landing page'));
    await tester.pumpAndSettle();
    expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('login and registration render with both color themes', (
    WidgetTester tester,
  ) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const WelcomeScreen()),
        ),
      );
      expect(find.text("Something broken?\nWe've got you."), findsOneWidget);
      expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const ReporterDashboard()),
        ),
      );
      expect(find.textContaining(', Reporter'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.text('Recent Tickets'), findsOneWidget);
      expect(find.text('Unable to connect to Wi-Fi'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const LoginScreen()),
        ),
      );
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        theme.brightness == Brightness.light
            ? const Color(0xFFF2F8FA)
            : const Color(0xFF08191D),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const RegisterScreen()),
        ),
      );
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(
        tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo)).size,
        80,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        theme.brightness == Brightness.light
            ? const Color(0xFFF2F8FA)
            : const Color(0xFF08191D),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const ForgotPasswordScreen()),
        ),
      );
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.byTooltip('Back to sign in'), findsOneWidget);
      expect(
        tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo)).size,
        80,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
