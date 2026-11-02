import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagedesk/main.dart';
import 'package:triagedesk/screens/admin_dashboard.dart';
import 'package:triagedesk/screens/technician_dashboard.dart';
import 'package:triagedesk/screens/ticket_details_screen.dart';
import 'package:triagedesk/screens/forgot_password_screen.dart';
import 'package:triagedesk/screens/login_screen.dart';
import 'package:triagedesk/screens/register_screen.dart';
import 'package:triagedesk/screens/reporter_dashboard.dart';
import 'package:triagedesk/services/api_service.dart';
import 'package:triagedesk/theme/app_theme.dart';
import 'package:triagedesk/widgets/triagedesk_logo.dart';

void main() {
  test('Plus Jakarta Sans is the font for both app themes', () {
    expect(
      AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily,
      'PlusJakartaSans',
    );
    expect(
      AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily,
      'PlusJakartaSans',
    );
    expect(
      AppTheme.lightTheme.textTheme.titleLarge?.fontFamily,
      'PlusJakartaSans',
    );
    expect(
      AppTheme.darkTheme.textTheme.titleLarge?.fontFamily,
      'PlusJakartaSans',
    );
  });

  test('Teal is the primary color across light and dark themes', () {
    expect(AppTheme.lightTheme.colorScheme.primary, AppTheme.deepTeal);
    expect(AppTheme.darkTheme.colorScheme.primary, AppTheme.accentTeal);
  });

  testWidgets('TriageDeskApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TriageDeskApp());
    final logo = find.bySemanticsLabel('TriageDesk logo');
    expect(logo, findsOneWidget);
    expect(tester.getSize(logo), const Size(88, 88));
    expect(
      tester.getCenter(logo).dx,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        1,
      ),
    );
    expect(find.text('TriageDesk'), findsOneWidget);
    expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
    expect(find.text('No account or sign-in needed'), findsOneWidget);
    expect(
      find.text('IT help that feels like\nasking a colleague.'),
      findsOneWidget,
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text("Tell us what's wrong"), findsOneWidget);
    expect(find.text('A technician picks it up'), findsOneWidget);
    expect(find.text("Fixed, and you're told"), findsOneWidget);
  });

  testWidgets('welcome screen handles a temporarily zero-height viewport', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(height: 0, child: WelcomeScreen())),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('login keeps account creation and password recovery actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TriageDeskApp());
    await tester.scrollUntilVisible(
      find.text('Get started'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo)).size, 36);
    expect(find.byType(GoogleLogoWidget), findsOneWidget);

    final welcomeHeading = tester.widget<Text>(find.text('Welcome back.'));
    expect(welcomeHeading.style?.fontSize, lessThanOrEqualTo(30));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back to landing page'));
    await tester.pumpAndSettle();
    expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
    expect(find.text('Welcome back.'), findsNothing);
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
      expect(
        find.text('IT help that feels like\nasking a colleague.'),
        findsOneWidget,
      );
      expect(find.text('Chat with us on WhatsApp'), findsOneWidget);
      expect(find.text('No account or sign-in needed'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final reporterClient = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'reporter-token',
              'token_type': 'bearer',
              'user': {
                'id': 14,
                'full_name': 'Selina Wanjiku',
                'email': 'selina@example.org',
                'role': 'Reporter',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/tickets') {
          return http.Response(
            jsonEncode([
              {
                'id': 21,
                'ticket_number': 'TD-21',
                'title': 'My live account ticket',
                'description': 'A real ticket returned by the API.',
                'category': 'Network',
                'impact': 'Medium',
                'urgency': 'Low',
                'priority': 'Low',
                'device': 'Laptop',
                'location': 'Office',
                'status': 'Open',
                'created_at': DateTime.now().toIso8601String(),
              },
            ]),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      await http.runWithClient(() async {
        await ApiService.login(email: 'selina@example.org', password: 'pass');
        await tester.pumpWidget(
          MaterialApp(
            home: Theme(data: theme, child: const ReporterDashboard()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Selina Wanjiku'), findsWidgets);
        expect(find.text('Need help?'), findsOneWidget);
        expect(find.text('Create Ticket'), findsOneWidget);
        expect(find.text('My Tickets'), findsNothing);
        expect(find.text('WhatsApp Support'), findsNothing);
        expect(find.text('Help & Support'), findsNothing);
        expect(find.text('View all'), findsOneWidget);
        expect(find.text('Open'), findsWidgets);
        expect(find.text('Recent Tickets'), findsOneWidget);
        expect(find.text('My live account ticket'), findsOneWidget);
        expect(find.text('Unable to connect to Wi-Fi'), findsNothing);
        expect(find.text('Tickets'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.text('Help'), findsOneWidget);
        expect(find.text('Profile'), findsWidgets);
        expect(
          tester.getTopLeft(find.text('Recent Tickets')).dy,
          greaterThan(tester.getBottomLeft(find.text('Need help?')).dy),
        );
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
        expect(find.text('Selina Wanjiku'), findsWidgets);
        expect(find.text('selina@example.org'), findsWidgets);
        expect(tester.takeException(), isNull);
      }, () => reporterClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const LoginScreen()),
        ),
      );
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        theme.scaffoldBackgroundColor,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const RegisterScreen()),
        ),
      );
      expect(find.text('Create your account'), findsOneWidget);
      expect(
        tester.widget<TriageDeskLogo>(find.byType(TriageDeskLogo)).size,
        24,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        theme.scaffoldBackgroundColor,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(data: theme, child: const ForgotPasswordScreen()),
        ),
      );
      expect(find.text('Locked out? It happens.'), findsOneWidget);
      expect(find.byTooltip('Back to sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('admin dashboard tabs and WhatsApp linking work', (
    WidgetTester tester,
  ) async {
    String? linkedPhone;
    String? updatedApproval;
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'admin-token',
            'user': {
              'id': 1,
              'full_name': 'Triage Admin',
              'email': 'admin@example.org',
              'role': 'Administrator',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/tickets' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 42,
              'title': 'Wi-Fi not connecting',
              'description': 'Cannot access the network.',
              'category': 'Network',
              'impact': 'High',
              'urgency': 'High',
              'priority': 'Critical',
              'device': 'Laptop',
              'location': 'Office',
              'status': 'Open',
              'assigned_technician_id': 9,
              'assigned_technician_name': 'Jordan Technician',
              'created_at': DateTime.now().toIso8601String(),
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/admin/users' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'full_name': 'Amina Reporter',
              'email': 'amina@example.com',
              'role': 'Reporter',
              'approval_status': 'Approved',
            },
            {
              'id': 8,
              'full_name': 'Jordan Technician',
              'email': 'jordan@example.com',
              'role': 'Technician',
              'approval_status': 'Pending',
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/admin/users/8/approval' &&
          request.method == 'PATCH') {
        updatedApproval =
            (jsonDecode(request.body)
                    as Map<String, dynamic>)['approval_status']
                as String;
        return http.Response(
          jsonEncode({
            'id': 8,
            'full_name': 'Jordan Technician',
            'email': 'jordan@example.com',
            'role': 'Technician',
            'approval_status': updatedApproval,
            'message': 'Account approved.',
          }),
          200,
        );
      }
      if (request.url.path == '/admin/users/7/whatsapp' &&
          request.method == 'PUT') {
        linkedPhone =
            (jsonDecode(request.body) as Map<String, dynamic>)['phone_number']
                as String;
        return http.Response(jsonEncode({'phone_number': linkedPhone}), 200);
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await ApiService.login(email: 'admin@example.org', password: 'pass');
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const AdminDashboard()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Triage Admin'), findsWidgets);
      expect(find.text('Total tickets'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Wi-Fi not connecting'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Wi-Fi not connecting'), findsOneWidget);

      await tester.tap(find.text('Tickets').last);
      await tester.pumpAndSettle();
      expect(find.text('All tickets'), findsOneWidget);
      expect(find.textContaining('Network'), findsOneWidget);

      await tester.tap(find.text('Wi-Fi not connecting').last);
      await tester.pumpAndSettle();
      expect(find.text('Ticket Details'), findsOneWidget);
      expect(find.text('Jordan Technician'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      expect(find.text('People'), findsOneWidget);
      expect(find.text('User management'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      await tester.tap(find.text('Pending (1)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Jordan Technician'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(updatedApproval, 'Approved');

      await tester.scrollUntilVisible(
        find.text('All (2)'),
        -250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('All (2)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Link WhatsApp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link WhatsApp'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '+254794045207');
      await tester.tap(find.text('Link number'));
      await tester.pumpAndSettle();
      expect(linkedPhone, '+254794045207');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('By category'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('admin Users and Reports remain available if tickets fail', (
    WidgetTester tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'admin-token',
            'user': {
              'id': 1,
              'full_name': 'Triage Admin',
              'email': 'admin@example.org',
              'role': 'Administrator',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/tickets') {
        return http.Response('Service unavailable', 503);
      }
      if (request.url.path == '/admin/users') {
        return http.Response('[]', 200);
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await ApiService.login(email: 'admin@example.org', password: 'pass');
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const AdminDashboard()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load dashboard data'), findsOneWidget);

      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      expect(find.text('User management'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('By category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('technician dashboard uses the logged-in user and API tickets', (
    WidgetTester tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'technician-token',
            'user': {
              'id': 4,
              'full_name': 'Asha Njeri',
              'email': 'asha@example.org',
              'role': 'Technician',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/tickets') {
        return http.Response(
          jsonEncode([
            {
              'id': 51,
              'ticket_number': 'TD-51',
              'title': 'Assigned to this technician',
              'description': 'API ticket.',
              'category': 'Network',
              'impact': 'High',
              'urgency': 'High',
              'priority': 'Critical',
              'device': 'Laptop',
              'location': 'Office',
              'status': 'In Progress',
              'assigned_technician_id': 4,
              'assigned_technician_name': 'Asha Njeri',
              'last_modified_by_name': 'Asha Njeri',
              'last_modified_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            },
          ]),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await ApiService.login(email: 'asha@example.org', password: 'pass');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TechnicianDashboard(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Asha'), findsWidgets);
      expect(find.text('Assigned to this technician'), findsWidgets);
      expect(find.text('John Doe updated ticket #TKT-0011'), findsNothing);
      expect(find.text('Sarah K. created ticket #TKT-0012'), findsNothing);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Njeri'), findsWidgets);
      expect(find.textContaining('asha@example.org'), findsWidgets);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('technician can accept an unassigned open ticket', (
    WidgetTester tester,
  ) async {
    var acceptedTicket = false;
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'technician-token',
            'user': {
              'id': 4,
              'full_name': 'Asha Njeri',
              'email': 'asha@example.org',
              'role': 'Technician',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/tickets' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 52,
              'ticket_number': 'TD-52',
              'title': 'Unclaimed laptop issue',
              'description': 'The laptop will not start.',
              'category': 'Hardware',
              'impact': 'Medium',
              'urgency': 'High',
              'priority': 'High',
              'device': 'Laptop',
              'location': 'Office',
              'status': acceptedTicket ? 'In Progress' : 'Open',
              'assigned_technician_id': acceptedTicket ? 4 : null,
              'assigned_technician_name': acceptedTicket ? 'Asha Njeri' : null,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/tickets/52/accept' &&
          request.method == 'POST') {
        acceptedTicket = true;
        return http.Response(
          jsonEncode({
            'id': 52,
            'ticket_number': 'TD-52',
            'title': 'Unclaimed laptop issue',
            'description': 'The laptop will not start.',
            'category': 'Hardware',
            'impact': 'Medium',
            'urgency': 'High',
            'priority': 'High',
            'device': 'Laptop',
            'location': 'Office',
            'status': 'In Progress',
            'assigned_technician_id': 4,
            'assigned_technician_name': 'Asha Njeri',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await ApiService.login(email: 'asha@example.org', password: 'pass');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TechnicianDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Available to claim'), findsOneWidget);
      expect(find.text('Accept ticket'), findsOneWidget);
      await tester.ensureVisible(find.text('Accept ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept ticket'));
      await tester.pumpAndSettle();

      expect(acceptedTicket, isTrue);
      expect(find.text('TD-52 accepted.'), findsOneWidget);
      expect(find.text('Accept ticket'), findsNothing);
      await tester.tap(find.text('Tickets').last);
      await tester.pumpAndSettle();
      expect(find.text('In Progress'), findsWidgets);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('technician saves closure, resolution, and work note', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? submitted;
    final client = MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'technician-token',
            'user': {
              'id': 4,
              'full_name': 'Asha Njeri',
              'email': 'asha@example.org',
              'role': 'Technician',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/tickets/53/history' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'ticket_id': 53,
              'actor_id': 4,
              'actor_name': 'Asha Njeri',
              'action': 'Ticket closed',
              'old_status': 'In Progress',
              'new_status': 'Closed',
              'details': 'Resolution: Replaced the power adapter.',
              'created_at': DateTime.now().toIso8601String(),
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/tickets/53/notes' && request.method == 'GET') {
        return http.Response(
          jsonEncode(
            submitted == null
                ? []
                : [
                    {
                      'id': 1,
                      'ticket_id': 53,
                      'author_id': 4,
                      'author_name': 'Asha Njeri',
                      'note': submitted!['note'],
                      'created_at': DateTime.now().toIso8601String(),
                    },
                  ],
          ),
          200,
        );
      }
      if (request.url.path == '/tickets/53/status' &&
          request.method == 'PATCH') {
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 53,
            'ticket_number': 'TD-53',
            'status': 'Closed',
            'resolution': submitted!['resolution'],
            'resolved_at': DateTime.now().toIso8601String(),
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await http.runWithClient(() async {
      await ApiService.login(email: 'asha@example.org', password: 'pass');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TicketDetailsScreen(
            id: '53',
            title: 'Laptop will not start',
            description: 'The laptop will not start.',
            category: 'Hardware',
            impact: 'Medium',
            urgency: 'High',
            device: 'Laptop',
            location: 'Office',
            status: 'In Progress',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve or close ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Closed').last);
      await tester.pumpAndSettle();
      final completionFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        completionFields.first,
        'Replaced the power adapter.',
      );
      await tester.enterText(
        completionFields.last,
        'Reporter notified of the repair.',
      );
      await tester.tap(find.text('Save update'));
      await tester.pumpAndSettle();

      expect(submitted?['status'], 'Closed');
      expect(submitted?['resolution'], 'Replaced the power adapter.');
      expect(submitted?['note'], 'Reporter notified of the repair.');
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Replaced the power adapter.'), findsWidgets);
      expect(
        find.textContaining('Reporter notified of the repair.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
