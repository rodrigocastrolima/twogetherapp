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
import '../../presentation/screens/clients/proposal_details_page.dart';
import '../../presentation/screens/clients/document_submission_page.dart';
import '../../presentation/screens/messages/messages_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../presentation/screens/notifications/rejection_details_page.dart';
import '../../presentation/screens/services/services_page.dart';
import '../../presentation/screens/services/resubmission_form_page.dart';
import '../../presentation/screens/dashboard/dashboard_page.dart';
import '../../presentation/screens/admin/admin_home_page.dart';
import '../../presentation/screens/admin/admin_reports_page.dart';
import '../../presentation/screens/admin/admin_settings_page.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/user_management/presentation/pages/user_management_page.dart';
import '../../features/user_management/presentation/pages/user_detail_page.dart';
import '../../presentation/screens/admin/admin_opportunities_page.dart';
import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/opportunity/presentation/pages/opportunity_verification_page.dart';
import '../../core/services/salesforce_auth_service.dart';
import '../../features/salesforce/presentation/pages/salesforce_setup_page.dart';

// Create a ChangeNotifier for authentication
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAuthenticated = false;
  bool _isAdmin = false;
  bool _isFirstLogin = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  bool get isFirstLogin => _isFirstLogin;

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
            final roleData = doc.data()?['role'];
            final String roleString = roleData is String ? roleData : 'unknown';
            final isFirstLogin = doc.data()?['isFirstLogin'] as bool? ?? false;

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
              print('User data: ${doc.data()}');
            }

            _isFirstLogin = isFirstLogin;
          } else {
            // No user data found in Firestore
            if (kDebugMode) {
              print(
                'User authenticated but no Firestore data found for ID: ${user.uid}',
              );
            }
            _isAuthenticated = true;
            _isAdmin = false;
            _isFirstLogin = true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching user data: $e');
          }
          _isAuthenticated = true;
          _isAdmin = false;
          _isFirstLogin = false;
        }
      } else {
        // User is signed out
        _isAuthenticated = false;
        _isAdmin = false;
        _isFirstLogin = false;
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
    }
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
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _adminShellNavigatorKey = GlobalKey<NavigatorState>();

  // Authentication notifier
  static final authNotifier = AuthNotifier();

  // Method to reset authentication state to false
  static void resetToLogin() async {
    await authNotifier.setAuthenticated(false);
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
        final salesforceAuthNotifier = container.read(
          salesforceAuthProvider.notifier,
        );
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
              if (kDebugMode)
                print(
                  '[Redirect] Admin: SF State $salesforceAuthState. Waiting on current page ($currentRoute).',
                );
              // Stay on the current admin page, UI should show loading based on state.
              return null;

            case SalesforceAuthState.unauthenticated:
            case SalesforceAuthState.error:
              // Check if we've already tried the automatic sign-in this session
              final alreadyAttempted =
                  salesforceAuthNotifier.initialSignInAttempted;

              if (kDebugMode)
                print(
                  '[Redirect] Admin: SF State $salesforceAuthState on page $currentRoute. Initial attempt done: $alreadyAttempted',
                );

              // Trigger automatic sign-in ONLY if it hasn't been attempted yet
              if (!alreadyAttempted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Double-check state and flag inside callback
                  if ((container.read(salesforceAuthProvider) ==
                              SalesforceAuthState.unauthenticated ||
                          container.read(salesforceAuthProvider) ==
                              SalesforceAuthState.error) &&
                      !container
                          .read(salesforceAuthProvider.notifier)
                          .initialSignInAttempted) {
                    // Mark as attempted BEFORE calling signIn
                    salesforceAuthNotifier.markInitialSignInAttempted();

                    salesforceAuthNotifier.signIn().catchError((e) {
                      if (kDebugMode)
                        print("Error triggering signIn from redirect: $e");
                    });
                  }
                });
              }

              // Allow navigation to proceed regardless of the trigger attempt
              return null; // Stay on current admin page

            case SalesforceAuthState.authenticated:
              if (kDebugMode)
                print(
                  '[Redirect] Admin: SF State Authenticated on page $currentRoute.',
                );
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
    routerNeglect: true, // Avoid unnecessarily rebuilding the navigator
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),

      // Reseller routes
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(currentIndex: 0, child: child);
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
            builder: (context, state) => const SettingsPage(),
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
            path: '/admin/messages',
            builder: (context, state) => const MessagesPage(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const AdminReportsPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsPage(),
          ),
          GoRoute(
            path: '/admin/user-management',
            builder: (context, state) => const UserManagementPage(),
          ),
          GoRoute(
            path: '/admin/users/:userId',
            builder: (context, state) {
              final user = state.extra as AppUser?;

              if (user == null) {
                // TODO: Handle case where user data is not provided
                // For now, redirect back to user management page
                return const UserManagementPage();
              }

              return UserDetailPage(user: user);
            },
          ),
          GoRoute(
            path: '/admin/resellers/:userId',
            builder: (context, state) {
              final reseller = state.extra as AppUser?;

              if (reseller == null) {
                // Handle case where reseller data is not provided
                // Redirect back to user management page
                return const UserManagementPage();
              }

              // Remove the ResellerDetailPage route since it's been deleted
              return const UserManagementPage();
            },
          ),
          GoRoute(
            path: '/admin/salesforce-setup',
            builder: (context, state) => const SalesforceSetupPage(),
          ),
          GoRoute(
            path: '/admin/home',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: AdminLayout(
                    child: AdminHomePage(),
                    pageTitle: 'Admin Dashboard',
                  ),
                ),
          ),
          GoRoute(
            path: '/admin/opportunities',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: OpportunityVerificationPage(),
                ),
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
            currentIndex: 0,
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
            currentIndex: 1,
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
            currentIndex: 0,
            child: ProposalDetailsPage(proposalData: proposalData),
          );
        },
      ),
      GoRoute(
        path: '/document-submission',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            currentIndex: 2,
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
            currentIndex: 0,
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
            currentIndex: 1,
            child: ResubmissionFormPage(submissionId: id),
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(currentIndex: 3, child: const DashboardPage());
        },
      ),
      GoRoute(
        path: '/salesforce-setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            currentIndex: 3,
            child: const SalesforceSetupPage(),
          );
        },
      ),
    ],
  );

  static GoRouter get router => _router;
}
