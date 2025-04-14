
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/layout/main_layout.dart';
import '../../presentation/layout/admin_layout.dart';
import '../../presentation/screens/auth/login_page.dart';
import '../../presentation/screens/auth/change_password_page.dart';
import '../../presentation/screens/home/reseller_home_page.dart';
import '../../presentation/screens/clients/clients_page.dart';
import '../../presentation/screens/clients/client_details_page.dart';
import '../../presentation/screens/messages/messages_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../presentation/screens/services/services_page.dart';
import '../../presentation/screens/dashboard/dashboard_page.dart';
import '../../presentation/screens/admin/admin_home_page.dart';
import '../../presentation/screens/admin/admin_settings_page.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/user_management/presentation/pages/user_management_page.dart';
import '../../features/user_management/presentation/pages/user_detail_page.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/opportunity/presentation/pages/opportunity_verification_page.dart'
    as admin_pages;
import '../../core/services/salesforce_auth_service.dart';
import '../../features/settings/presentation/pages/profile_page.dart';

// Create a ChangeNotifier for authentication
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAuthenticated = false;
  bool _isAdmin = false;
  bool _isFirstLogin = false;
  String? _salesforceId; // Add field for Salesforce ID

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  bool get isFirstLogin => _isFirstLogin;
  String? get salesforceId => _salesforceId; // Add getter

  AuthNotifier() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Listen to Firebase Auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Check user role in Firestore
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            final roleData = data['role'];
            final String roleString = roleData is String ? roleData : 'unknown';
            final isFirstLogin = data['isFirstLogin'] as bool? ?? false;
            final salesforceIdFromDb =
                data['salesforceId'] as String?; // Read salesforceId

            _isAuthenticated = true;

            // Detailed logging for debugging role issues
            if (kDebugMode) {
              print(
                'User authenticated - Raw role value from Firestore: "$roleString"',
              );
            }

            // If role is "Admin" or "admin", set isAdmin to true
            // Handle case-insensitively with trimming to catch common formatting issues
            final normalizedRole = roleString.trim().toLowerCase();
            _isAdmin = normalizedRole == 'admin';

            if (kDebugMode) {
              print('Normalized role: "$normalizedRole", isAdmin: $_isAdmin');
            }
            if (kDebugMode) {
              print('User data: $data');
              print(
                'Fetched Salesforce ID: $salesforceIdFromDb',
              ); // Log fetched ID
            }

            _isFirstLogin = isFirstLogin;
            _salesforceId = salesforceIdFromDb; // Store salesforceId
          } else {
            // Handle case where doc doesn't exist
            // No user data found in Firestore
            if (kDebugMode) {
              print(
                'User authenticated but no Firestore data found for ID: ${user.uid}',
              );
            }
            _isAuthenticated = true;
            _isAdmin = false;
            _isFirstLogin = true;
            _salesforceId = null; // Reset salesforceId
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching user data: $e');
          }
          _isAuthenticated = true;
          _isAdmin = false;
          _isFirstLogin = false;
          _salesforceId = null; // Reset salesforceId on error
        }
      } else {
        // User is signed out
        _isAuthenticated = false;
        _isAdmin = false;
        _isFirstLogin = false;
        _salesforceId = null; // Reset salesforceId on sign out
      }
      notifyListeners();
    });
  }

  Future<void> setAuthenticated(bool value, {bool isAdmin = false}) async {
    if (value) {
      // This method is only for legacy compatibility - actual auth is handled by Firebase
      // You should use signInWithEmailAndPassword instead
      if (kDebugMode) {
        print('Warning: Using deprecated setAuthenticated method');
      }
    } else {
      // Sign out
      await _auth.signOut();
      // state is updated by the listener
    }
    // We don't manually call notifyListeners here as the authStateChanges listener handles it
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      // For web platforms, always use local persistence
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      // Force refresh the user data from Firestore to ensure correct role detection
      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final roleData = doc.data()?['role'];
            final String roleString = roleData is String ? roleData : 'unknown';
            final normalizedRole = roleString.trim().toLowerCase();

            if (kDebugMode) {
              print('Login successful - User ID: ${user.uid}');
            }
            if (kDebugMode) {
              print(
                'User role from Firestore: "$roleString", normalized: "$normalizedRole"',
              );
            }
            if (kDebugMode) {
              print('Full user data: ${doc.data()}');
            }

            // Update the state immediately for faster UI response
            _isAdmin = normalizedRole == 'admin';
            _isAuthenticated = true;
            _isFirstLogin = doc.data()?['isFirstLogin'] as bool? ?? false;

            // Ensure a reseller user has a conversation
            if (normalizedRole == 'reseller') {
              try {
                if (kDebugMode) {
                  print('Ensuring reseller has a default conversation');
                }

                // Create a chat repository and ensure the reseller has a conversation
                final chatRepository = ChatRepository();
                await chatRepository.ensureResellerHasConversation(user.uid);
              } catch (e) {
                // Don't block login if chat creation fails
                if (kDebugMode) {
                  print('Failed to ensure conversation: $e');
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching user role after login: $e');
          }
          // Don't block the login process on error, rely on the auth state listener
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Mark first login as completed
  Future<void> completeFirstLogin() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isFirstLogin': false,
          'firstLoginCompletedAt': FieldValue.serverTimestamp(),
        });
        _isFirstLogin = false;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Error updating first login status: $e');
        }
      }
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.updatePassword(newPassword);
        await completeFirstLogin();
      } catch (e) {
        rethrow;
      }
    } else {
      throw Exception('No authenticated user');
    }
  }

  // Manually check if current user is admin
  Future<bool> checkIfCurrentUserIsAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        if (kDebugMode) {
          print('User document not found in Firestore');
        }
        return false;
      }

      final data = doc.data()!;
      if (kDebugMode) {
        print('Checking admin status - User data: $data');
      }

      // Check the role field
      if (data.containsKey('role')) {
        final roleData = data['role'];
        final String roleString = roleData is String ? roleData : 'unknown';
        final normalizedRole = roleString.trim().toLowerCase();

        final isAdmin = normalizedRole == 'admin';
        if (kDebugMode) {
          print(
            'User role: "$roleString", normalized: "$normalizedRole", isAdmin: $isAdmin',
          );
        }

        // Update our cached value
        _isAdmin = isAdmin;
        notifyListeners();

        return isAdmin;
      } else {
        if (kDebugMode) {
          print('Role field not found in user document');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking admin status: $e');
      }
      return false;
    }
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'ShellReseller',
  );
  static final _adminShellNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'ShellAdmin',
  );

  // Authentication notifier
  static final authNotifier = AuthNotifier();

  // Method to reset authentication state to false
  static void resetToLogin() async {
    await authNotifier.setAuthenticated(false);
  }

  // Helper to determine current index based on route
  static int _calculateCurrentIndex(GoRouterState state) {
    final location = state.matchedLocation;
    if (location.startsWith('/') && location.length == 1) return 0; // Home
    if (location.startsWith('/clients')) return 1;
    if (location.startsWith('/messages')) return 2;
    if (location.startsWith('/settings'))
      return 3; // Renamed /profile to /settings
    return 0; // Default to home
  }

  // Initialization of router
  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      try {
        final container = ProviderScope.containerOf(context);
        final salesforceAuthState = container.read(salesforceAuthProvider);

        // Get current auth states
        final isAuthenticated = authNotifier.isAuthenticated;
        final isAdmin = authNotifier.isAdmin;
        final isFirstLogin = authNotifier.isFirstLogin;
        final currentRoute = state.matchedLocation;
        final isLoginPage = currentRoute == '/login';
        final isChangePasswordPage = currentRoute == '/change-password';

        // --- 1. User Not Authenticated ---
        if (!isAuthenticated) {
          return isLoginPage ? null : '/login';
        }

        // --- User IS Authenticated ---

        // --- 2. Handle First Login ---
        if (isFirstLogin) {
          // If it's the first login, must go to change password.
          // If already there, stay. Otherwise, redirect.
          return isChangePasswordPage ? null : '/change-password';
        }

        // --- User IS Authenticated & NOT First Login ---

        // --- 3. Redirect AWAY from Login/ChangePassword page ---
        if (isLoginPage || isChangePasswordPage) {
          if (kDebugMode) {
            print(
              '[Redirect] Authenticated, not first login. Redirecting from $currentRoute...',
            );
          }
          // Redirect to the appropriate home page based on role.
          return isAdmin ? '/admin' : '/';
        }

        // --- 4. Apply Role-Based Routing & Salesforce Checks (User is Authenticated, NOT First Login, and NOT on Login/ChangePassword) ---
        if (isAdmin) {
          // --- Admin Flow (already on an internal page) ---

          // Ensure admin stays within /admin routes. Redirect if they somehow land outside.
          if (!currentRoute.startsWith('/admin')) {
            if (kDebugMode) {
              print(
                '[Redirect] Admin detected outside /admin routes. Forcing to /admin.',
              );
            }
            return '/admin';
          }

          // Check Salesforce State (only relevant now we are on an admin page)
          switch (salesforceAuthState) {
            case SalesforceAuthState.unknown:
            case SalesforceAuthState.authenticating:
              if (kDebugMode) {
                print(
                  '[Redirect] Admin: SF State $salesforceAuthState. Waiting on current page ($currentRoute).',
                );
              }
              // Stay on the current admin page, UI should show loading based on state.
              return null;

            case SalesforceAuthState.unauthenticated:
            case SalesforceAuthState.error:
              if (kDebugMode) {
                print(
                  '[Redirect] Admin: SF State $salesforceAuthState on page $currentRoute.',
                );
              }

              // Allow navigation to proceed regardless of the trigger attempt
              return null; // Stay on current admin page

            case SalesforceAuthState.authenticated:
              if (kDebugMode) {
                print(
                  '[Redirect] Admin: SF State Authenticated on page $currentRoute.',
                );
              }
              // Already authenticated, stay on current admin page.
              return null;
          }
        } else {
          // --- Reseller Flow (already on an internal page) ---

          // Ensure reseller does not access admin routes.
          if (currentRoute.startsWith('/admin')) {
            if (kDebugMode) {
              print(
                '[Redirect] Reseller detected on admin route. Forcing to /.',
              );
            }
            return '/';
          }
          // Allow reseller to stay on any non-admin page.
          return null;
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            "[Redirect] Error accessing ProviderScope or reading providers: $e",
          );
          print("[Redirect] Ensure GoRouter is created within ProviderScope.");
        }
        // Fallback: redirect to login if providers can't be read.
        // Avoid infinite loop if error happens repeatedly on login page.
        if (state.matchedLocation != '/login') {
          return '/login';
        } else {
          return null; // Stay on login if error happens there
        }
      }
    },
    // Ensure transitions are as clean as possible
    routerNeglect: true,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey:
            _rootNavigatorKey, // Ensures it appears above shells
        builder: (context, state) => const ChangePasswordPage(),
      ),

      // Reseller routes SHELL
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Determine the current index dynamically
          final currentIndex = _calculateCurrentIndex(state);
          return MainLayout(currentIndex: currentIndex, child: child);
        },
        routes: [
          GoRoute(
            path: '/', // Home
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ResellerHomePage()),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ClientsPage()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: MessagesPage()),
          ),
          GoRoute(
            path: '/settings', // Renamed from /profile for clarity
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child:
                      SettingsPage(), // This is the main settings *tab* content
                ),
          ),
        ],
      ),

      // Admin routes SHELL
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) {
          // Admin layout might need its own logic for nav state
          return AdminLayout(
            showNavigation: true,
            showBackButton: false,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminHomePage()),
          ),
          GoRoute(
            path: '/admin/messages',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: MessagesPage(), // Can reuse MessagesPage if suitable
                ),
          ),
          GoRoute(
            path: '/admin/reports',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: AdminHomePage(), // Placeholder
                ),
          ),
          GoRoute(
            path: '/admin/settings',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminSettingsPage()),
          ),
          GoRoute(
            path: '/admin/user-management',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: UserManagementPage()),
          ),
          // --- Route to be moved BACK INSIDE ---
          GoRoute(
            path: '/admin/opportunities',
            pageBuilder: (context, state) {
              // Use MaterialPage for default transitions or CustomTransitionPage
              return const MaterialPage(
                child: admin_pages.OpportunityVerificationPage(),
              );
            },
          ),
        ],
      ),

      // --- Top-Level Secondary Routes (No Shell) ---
      GoRoute(
        path: '/admin/users/:userId',
        parentNavigatorKey: _rootNavigatorKey, // Display above admin shell
        pageBuilder: (context, state) {
          final user = state.extra as AppUser?;
          if (user == null) {
            // Simple fallback, ideally show an error or fetch user
            return const MaterialPage(
              child: Scaffold(body: Center(child: Text("User not found"))),
            );
          }
          // Use MaterialPage for default transitions or CustomTransitionPage
          return MaterialPage(child: UserDetailPage(user: user));
        },
      ),
      GoRoute(
        path: '/profile-details',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => const MaterialPage(
              fullscreenDialog: true,
              child: ProfilePage(),
            ),
      ),
      GoRoute(
        path: '/services',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final preFilledData = state.extra as Map<String, dynamic>?;
          return MaterialPage(
            fullscreenDialog: true,
            child: ServicesPage(preFilledData: preFilledData),
          );
        },
      ),
      GoRoute(
        path: '/client-details',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final clientData = state.extra as Map<String, dynamic>?;
          // Handle potentially null extra data
          if (clientData == null) {
            return const MaterialPage(
              child: Scaffold(body: Center(child: Text("Client data missing"))),
            );
          }
          return MaterialPage(
            fullscreenDialog: true,
            child: ClientDetailsPage(clientData: clientData),
          );
        },
      ),
      GoRoute(
        path: '/proposals/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          // This should likely navigate to a ProposalDetailsPage, not ClientsPage
          // Placeholder:
          return MaterialPage(
            child: Scaffold(body: Center(child: Text("Proposal Detail: $id"))),
          );
        },
      ),
      GoRoute(
        path: '/document-submission',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          // Should likely point to a dedicated document submission page
          // Placeholder:
          return MaterialPage(
            child: Scaffold(
              body: Center(child: Text("Document Submission Page")),
            ),
          );
        },
      ),
      GoRoute(
        path: '/notifications/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          // Should point to a NotificationDetailsPage
          // Placeholder:
          return MaterialPage(
            child: Scaffold(
              body: Center(child: Text("Notification Detail: $id")),
            ),
          );
        },
      ),
      GoRoute(
        path: '/resubmission-form/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          // Should point to a specific ResubmissionForm page, potentially pre-filled
          // Placeholder:
          return MaterialPage(
            child: ServicesPage(preFilledData: {'resubmissionId': id}),
          );
        },
      ),
      GoRoute(
        path:
            '/dashboard', // Is this admin or reseller specific? Assuming reseller for now.
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          // Should point to DashboardPage directly
          return const MaterialPage(child: DashboardPage());
        },
      ),
    ],
    // Optional: Add error page handling
    errorPageBuilder:
        (context, state) => MaterialPage(
          key: state.pageKey,
          child: Scaffold(
            body: Center(child: Text('Page not found: ${state.error}')),
          ),
        ),
  );

  static GoRouter get router => _router;
}
