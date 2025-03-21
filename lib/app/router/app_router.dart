import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';

import '../../presentation/layout/main_layout.dart';
import '../../presentation/layout/admin_layout.dart';
import '../../presentation/screens/auth/login_page.dart';
import '../../presentation/screens/home/reseller_home_page.dart';
import '../../presentation/screens/clients/clients_page.dart';
import '../../presentation/screens/clients/client_details_page.dart';
import '../../presentation/screens/clients/proposal_details_page.dart';
import '../../presentation/screens/clients/document_submission_page.dart';
import '../../presentation/screens/messages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../presentation/screens/notifications/rejection_details_page.dart';
import '../../presentation/screens/services/services_page.dart';
import '../../presentation/screens/services/resubmission_form_page.dart';
import '../../presentation/screens/dashboard/dashboard_page.dart';
import '../../presentation/screens/admin/admin_home_page.dart';
import '../../presentation/screens/admin/admin_users_page.dart';
import '../../presentation/screens/admin/admin_reports_page.dart';
import '../../presentation/screens/admin/admin_settings_page.dart';

// Create a ChangeNotifier for authentication
class AuthNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;

  AuthNotifier() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      _isAdmin = prefs.getBool('is_admin') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      _isAuthenticated = false;
      _isAdmin = false;
      notifyListeners();
    }
  }

  Future<void> setAuthenticated(bool value, {bool isAdmin = false}) async {
    if (_isAuthenticated != value || _isAdmin != isAdmin) {
      _isAuthenticated = value;
      _isAdmin = isAdmin;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_authenticated', value);
        await prefs.setBool('is_admin', isAdmin);
      } catch (e) {
        debugPrint('Error saving authentication state: $e');
      }
      notifyListeners();
    }
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _adminShellNavigatorKey = GlobalKey<NavigatorState>();

  // Authentication notifier
  static final authNotifier = AuthNotifier();

  // Method to reset authentication state to false
  static void resetToLogin() async {
    await authNotifier.setAuthenticated(false);
  }

  // Lazy initialization of router
  static late final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final isAdmin = authNotifier.isAdmin;

      // Redirect to login if not authenticated
      if (!isAuthenticated && state.matchedLocation != '/login') {
        return '/login';
      }

      // Redirect to home if authenticated and on login page
      if (isAuthenticated && state.matchedLocation == '/login') {
        return isAdmin ? '/admin' : '/';
      }

      // Ensure admin users access admin routes and regular users access regular routes
      if (isAuthenticated &&
          isAdmin &&
          !state.matchedLocation.startsWith('/admin') &&
          state.matchedLocation != '/login') {
        return '/admin';
      }

      if (isAuthenticated &&
          !isAdmin &&
          state.matchedLocation.startsWith('/admin')) {
        return '/';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // Reseller routes
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(
            showNavigation: true,
            showBackButton: false,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ResellerHomePage(),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsPage(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagesPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // Admin routes
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) {
          return AdminLayout(
            showNavigation: true,
            showBackButton: false,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminHomePage(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersPage(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const AdminReportsPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsPage(),
          ),
        ],
      ),

      // Other routes (remain the same)
      GoRoute(
        path: '/client-details',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final clientData = state.extra as Map<String, dynamic>;
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: ClientDetailsPage(clientData: clientData),
          );
        },
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) {
          final preFilledData = state.extra as Map<String, dynamic>?;
          final servicesPageKey = GlobalKey<ServicesPageState>();

          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              final servicesState = servicesPageKey.currentState;
              if (servicesState != null && servicesState.currentStep > 0) {
                servicesState.handleBackPress();
              } else {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.go('/');
                }
              }
            },
            child: ServicesPage(
              key: servicesPageKey,
              preFilledData: preFilledData,
            ),
          );
        },
      ),
      GoRoute(
        path: '/proposal-details',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final proposalData = state.extra as Map<String, dynamic>;
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: ProposalDetailsPage(proposalData: proposalData),
          );
        },
      ),
      GoRoute(
        path: '/document-submission',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: const DocumentSubmissionPage(),
          );
        },
      ),
      GoRoute(
        path: '/notifications/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: RejectionDetailsPage(
              submissionId: id,
              rejectionReason: 'Missing document information',
              rejectionDate: DateTime.now(),
              isPermanentRejection: false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/resubmission-form/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: ResubmissionFormPage(submissionId: id),
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            showNavigation: true,
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.canPop(context)) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: const DashboardPage(),
          );
        },
      ),
    ],
  );

  static GoRouter get router => _router;
}
