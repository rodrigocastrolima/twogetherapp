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
import '../../features/salesforce/presentation/pages/salesforce_setup_page.dart';
import '../../features/admin/presentation/pages/admin_submissions_page.dart';
import '../../presentation/screens/admin/admin_opportunities_page.dart';
import '../../features/chat/data/repositories/chat_repository.dart';

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
  Future<void> signInWithEmailAndPassword(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      // Set persistence based on rememberMe flag only on web platforms
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      // Force refresh the user data from Firestore to ensure correct role detection
      if (user != null) {
        try {
          // Save the rememberMe preference if needed
          if (rememberMe) {
            // Store rememberMe preference to local storage if needed
            // This is just for reference in case you need it later
            await _storeRememberMePreference(user.uid, rememberMe);
          }

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

            notifyListeners();

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

  // Add this private method to store rememberMe preference
  Future<void> _storeRememberMePreference(
    String userId,
    bool rememberMe,
  ) async {
    try {
      // Store the preference in Firestore (optional)
      await _firestore.collection('users').doc(userId).update({
        'rememberMe': rememberMe,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('RememberMe preference stored: $rememberMe');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to store rememberMe preference: $e');
      }
      // Non-critical error, so just log it and continue
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
      // Skip redirection for non-main routes
      if (state.fullPath?.startsWith('/resources/') == true) {
        return null;
      }

      // Get authentication state from the notifier
      final isAuthenticated = authNotifier.isAuthenticated;
      final isAdmin = authNotifier.isAdmin;
      final isFirstLogin = authNotifier.isFirstLogin;

      // Don't redirect if we're already going to the login page
      final isLoggingIn = state.matchedLocation == '/login';
      final isChangingPassword = state.matchedLocation == '/change-password';

      // Collect redirect info (for debugging only, can be removed in production)
      // Redirect logic based on auth state
      if (!isAuthenticated) {
        // If not authenticated, redirect to login
        if (!isLoggingIn) {
          return '/login';
        }
      } else if (isFirstLogin) {
        // If it's the first login, redirect to change password page
        if (!isChangingPassword) {
          return '/change-password';
        }
      } else if (isLoggingIn || isChangingPassword) {
        // If authenticated and on login/change-password, redirect to appropriate home
        return isAdmin ? '/admin' : '/';
      } else if (isAdmin && !state.matchedLocation.startsWith('/admin')) {
        // Admin trying to access non-admin pages, redirect to admin home
        return '/admin';
      } else if (!isAdmin && state.matchedLocation.startsWith('/admin')) {
        // Non-admin trying to access admin pages, redirect to user home
        return '/';
      }

      // No redirection needed
      return null;
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
          return MainLayout(child: child, currentIndex: 0);
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
            path: '/admin/salesforce-setup',
            builder: (context, state) => const SalesforceSetupPage(),
          ),
          GoRoute(
            path: '/admin/submissions',
            builder: (context, state) => const AdminSubmissionsPage(),
          ),
          GoRoute(
            path: '/admin/opportunities',
            builder: (context, state) => const AdminOpportunitiesPage(),
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
            child: ClientDetailsPage(clientData: clientData),
            currentIndex: 0,
          );
        },
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) {
          final preFilledData = state.extra as Map<String, dynamic>?;
          final servicesPageKey = GlobalKey<ServicesPageState>();

          return MainLayout(
            child: ServicesPage(
              key: servicesPageKey,
              preFilledData: preFilledData,
            ),
            currentIndex: 1,
          );
        },
      ),
      GoRoute(
        path: '/proposal-details',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final proposalData = state.extra as Map<String, dynamic>;
          return MainLayout(
            child: ProposalDetailsPage(proposalData: proposalData),
            currentIndex: 0,
          );
        },
      ),
      GoRoute(
        path: '/document-submission',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            child: const DocumentSubmissionPage(),
            currentIndex: 2,
          );
        },
      ),
      GoRoute(
        path: '/notifications/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MainLayout(
            child: RejectionDetailsPage(
              submissionId: id,
              rejectionReason: 'Missing document information',
              rejectionDate: DateTime.now(),
              isPermanentRejection: false,
            ),
            currentIndex: 0,
          );
        },
      ),
      GoRoute(
        path: '/resubmission-form/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MainLayout(
            child: ResubmissionFormPage(submissionId: id),
            currentIndex: 1,
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(child: const DashboardPage(), currentIndex: 3);
        },
      ),
      GoRoute(
        path: '/salesforce-setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          return MainLayout(
            child: const SalesforceSetupPage(),
            currentIndex: 3,
          );
        },
      ),
    ],
  );

  static GoRouter get router => _router;
}
