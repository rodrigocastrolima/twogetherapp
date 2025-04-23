import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../presentation/layout/main_layout.dart';
import '../../presentation/layout/admin_layout.dart';
import '../../presentation/screens/auth/login_page.dart';
import '../../presentation/screens/auth/change_password_page.dart';
import '../../presentation/screens/home/reseller_home_page.dart';
import '../../presentation/screens/clients/reseller_opportunity_page.dart';
import '../../presentation/screens/clients/reseller_opportunity_details_page.dart';
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
import '../../presentation/screens/admin/stats/admin_stats_detail_page.dart';
import '../../core/models/enums.dart';
import '../../presentation/screens/admin/dev_tools_page.dart';
import '../../core/models/service_submission.dart';
import '../../features/opportunity/presentation/pages/admin_opportunity_review_page.dart';
import '../../features/opportunity/presentation/pages/salesforce_opportunity.dart';

// *** USE this Global Navigator Key consistently ***
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
// *******************************

// Create a ChangeNotifier for authentication
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  bool _isAuthenticated = false;
  bool _isAdmin = false;
  bool _isFirstLogin = false;
  bool _initialPasswordChanged = false;
  String? _salesforceId;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  bool get isFirstLogin => _isFirstLogin;
  bool get initialPasswordChanged => _initialPasswordChanged;
  String? get salesforceId => _salesforceId;

  AuthNotifier() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        if (kDebugMode)
          print(
            'Auth Listener: User is not null (UID: ${user.uid}). Entering try block...',
          );
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            final roleData = data['role'];
            final String roleString = roleData is String ? roleData : 'unknown';
            final isFirstLogin = data['isFirstLogin'] as bool? ?? false;
            final initialPasswordChanged =
                data['initialPasswordChanged'] as bool? ?? true;
            final salesforceIdFromDb = data['salesforceId'] as String?;

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
            _initialPasswordChanged = initialPasswordChanged;
            _salesforceId = salesforceIdFromDb; // Store salesforceId

            if (kDebugMode)
              print(
                'Auth Listener: User data fetched. Attempting token update...',
              );

            // *** Start FCM Token Logic ***
            // Get initial token and save it
            await _updateFcmToken();
            // Listen for token refreshes
            _firebaseMessaging.onTokenRefresh.listen((newToken) async {
              if (kDebugMode) print('FCM Token Refreshed.');
              await _updateFcmToken(
                token: newToken,
              ); // Pass the new token directly
            });
            // *** End FCM Token Logic ***
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
            _initialPasswordChanged = false;
            _salesforceId = null; // Reset salesforceId
          }
        } catch (e) {
          if (kDebugMode)
            print('Auth Listener: ERROR caught in _initAuth try block: $e');
          if (kDebugMode) {
            print('Error fetching user data: $e');
          }
          _isAuthenticated = false;
          _isAdmin = false;
          _isFirstLogin = false;
          _initialPasswordChanged = true;
          _salesforceId = null; // Reset salesforceId on error
        }
      } else {
        // User is signed out
        // *** Start FCM Token Logic ***
        // Attempt to remove the token on sign out
        await _removeFcmToken();
        // *** End FCM Token Logic ***

        _isAuthenticated = false;
        _isAdmin = false;
        _isFirstLogin = false;
        _initialPasswordChanged = false;
        _salesforceId = null; // Reset salesforceId on sign out
      }
      // Notify listeners AFTER potential delay and state update
      if (kDebugMode) {
        print(
          'AuthNotifier state updated: isAuthenticated=$_isAuthenticated, isAdmin=$_isAdmin',
        );
      }
      notifyListeners();
    });
  }

  Future<void> _updateFcmToken({String? token}) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) print('Cannot update FCM token, user is null.');
      return;
    }

    try {
      // Get token if not provided (e.g., on initial login)
      final fcmToken = token ?? await _firebaseMessaging.getToken();

      if (fcmToken != null) {
        final userRef = _firestore.collection('users').doc(user.uid);
        if (kDebugMode)
          print('Attempting to add FCM token for user ${user.uid}');
        await userRef.set(
          // Use set with merge:true to handle doc creation if needed
          {
            'fcmTokens': FieldValue.arrayUnion([fcmToken]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ), // Use merge to avoid overwriting other fields
        );
        if (kDebugMode)
          print('Successfully added FCM token for user ${user.uid}');
      } else {
        if (kDebugMode)
          print('FCM token is null, cannot update for user ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode)
        print('Error updating FCM token for user ${user.uid}: $e');
      // Decide if you want to rethrow or handle silently
    }
  }

  Future<void> _removeFcmToken() async {
    // Get the UID before potentially signing out completely
    final uidToRemoveTokenFor = _auth.currentUser?.uid;
    if (uidToRemoveTokenFor == null) {
      // No user logged in, nothing to remove. This might happen if called after sign out completes.
      if (kDebugMode) print('No user logged in, skipping FCM token removal.');
      return;
    }

    try {
      // Get the specific token for this device instance to remove it
      final fcmToken = await _firebaseMessaging.getToken();

      if (fcmToken != null) {
        final userRef = _firestore.collection('users').doc(uidToRemoveTokenFor);
        if (kDebugMode)
          print(
            'Attempting to remove FCM token for user ${uidToRemoveTokenFor}',
          );
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([fcmToken]),
        });
        if (kDebugMode)
          print(
            'Successfully removed FCM token for user ${uidToRemoveTokenFor}',
          );
      } else {
        if (kDebugMode)
          print(
            'FCM token is null, cannot remove for user ${uidToRemoveTokenFor}',
          );
      }
    } catch (e) {
      // Log error but don't prevent sign-out
      if (kDebugMode)
        print('Error removing FCM token for user ${uidToRemoveTokenFor}: $e');
      // Check if the error is due to the document not existing (already deleted?)
      if (e is FirebaseException && e.code == 'not-found') {
        if (kDebugMode)
          print(
            'User document ${uidToRemoveTokenFor} not found during token removal, might have been deleted.',
          );
      }
    }
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
    print('AuthNotifier: signInWithEmailAndPassword called.'); // LOG
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
            final data = doc.data()!;
            final roleData = data['role'];
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

            // Ensure a reseller user has a conversation
            // if (normalizedRole == 'reseller') {
            //   print('AuthNotifier: User is a reseller.'); // LOG
            //   try {
            //     final chatRepository = ChatRepository();
            //     await chatRepository.ensureResellerHasConversation(user.uid);
            //     print('Ensuring reseller conversation finished.'); // Hypothetical log
            //   } catch (e) {
            //     // Don't block login if chat creation fails
            //     if (kDebugMode) {
            //       print('Failed to ensure conversation: $e');
            //     }
            //   }
            // }
          } else {
            // Handle case where user exists in Auth but not Firestore (rare)
            if (kDebugMode) {
              print(
                'Login successful but no Firestore doc found - assuming first login/password change needed.',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching user role/data after login: $e');
          }
          // Don't block login, but set defaults cautiously
        }
      }
    } catch (e) {
      print('AuthNotifier: Error during sign in: $e'); // LOG
      rethrow;
    }
    print('AuthNotifier: signInWithEmailAndPassword finished.'); // LOG
  }

  // Mark first login as completed
  Future<void> completeFirstLogin() async {
    print(
      'AuthNotifier: completeFirstLogin called (now also sets initialPasswordChanged).',
    ); // LOG
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isFirstLogin': false,
          'initialPasswordChanged': true,
          'firstLoginCompletedAt': FieldValue.serverTimestamp(),
        });
        _isFirstLogin = false;
        _initialPasswordChanged = true;
        notifyListeners();
        print(
          'AuthNotifier: State updated - isFirstLogin: false, initialPasswordChanged: true.',
        ); // LOG
      } catch (e) {
        if (kDebugMode) {
          print('Error updating first login / password changed status: $e');
        }
        // Rethrow? Or handle more gracefully?
        rethrow; // Rethrow for ChangePasswordPage to catch
      }
    }
    print('AuthNotifier: completeFirstLogin finished.'); // LOG
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    print('AuthNotifier: updatePassword called.'); // LOG
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.updatePassword(newPassword);
        print('AuthNotifier: Firebase password updated.'); // LOG
        await completeFirstLogin();
        print('AuthNotifier: updatePassword finished successfully.'); // LOG
      } catch (e) {
        print('AuthNotifier: Error updating password: $e'); // LOG
        rethrow;
      }
    } else {
      print(
        'AuthNotifier: Error updating password - No authenticated user.',
      ); // LOG
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

  // Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        print('Password reset email sent successfully to: $email');
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Error sending password reset email: ${e.code} - ${e.message}');
      }
      // Could return specific error codes/messages if needed
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Generic error sending password reset email: $e');
      }
      return false;
    }
  }
}

// *** ADD Provider for the AuthNotifier ***
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  // Return the existing static instance from AppRouter
  // Note: This assumes AppRouter.authNotifier is initialized before this provider is first read.
  // A better approach might be to instantiate AuthNotifier directly here and pass it to AppRouter.
  return AppRouter.authNotifier;
});
// ***************************************

class AppRouter {
  // *** REMOVE potentially duplicate static key if it exists ***
  // static final rootNavigatorKey = GlobalKey<NavigatorState>();
  // Use the global _rootNavigatorKey directly

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
    // Use the global key consistently
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      print(
        'GoRouter Redirect: Checking auth state... Current location: ${state.uri.toString()}',
      ); // LOG
      try {
        final container = ProviderScope.containerOf(context);
        final salesforceAuthState = container.read(salesforceAuthProvider);

        // Get current auth states
        final isAuthenticated = authNotifier.isAuthenticated;
        final isAdmin = authNotifier.isAdmin;
        final currentRoute = state.matchedLocation;
        final isLoginPage = currentRoute == '/login';

        // --- 1. User Not Authenticated ---
        if (!isAuthenticated) {
          print(
            'GoRouter Redirect: Not logged in, redirecting to /login from ${state.uri.toString()}',
          ); // LOG
          return isLoginPage ? null : '/login'; // Stay if already on login
        }

        // --- User IS Authenticated ---

        // --- 3. Redirect AWAY from Login page ONLY ---
        if (isLoginPage) {
          if (kDebugMode) {
            print(
              '[Redirect] Authenticated. Redirecting from $currentRoute...',
            );
          }
          // Redirect to the appropriate home page based on role.
          final target = isAdmin ? '/admin' : '/';
          print(
            'GoRouter Redirect: Logged in, redirecting to $target from ${state.uri.toString()}',
          ); // LOG
          return target;
        }

        // --- 4. Apply Role-Based Routing & Salesforce Checks ---
        if (isAdmin) {
          // --- Admin Flow (already on an internal page) ---

          // Ensure admin stays within /admin routes. Redirect if they somehow land outside.
          if (!currentRoute.startsWith('/admin')) {
            if (kDebugMode) {
              print(
                '[Redirect] Admin detected outside /admin routes. Forcing to /admin.',
              );
            }
            print(
              'GoRouter Redirect: Admin detected outside /admin routes, redirecting to /admin from ${state.uri.toString()}',
            ); // LOG
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
            print(
              'GoRouter Redirect: Reseller detected on admin route, redirecting to /reseller from ${state.uri.toString()}',
            ); // LOG
            return '/reseller';
          }
          // Allow reseller to stay on any non-admin page.
          return null;
        }

        // Allow access
        if (kDebugMode)
          print(
            'GoRouter Redirect: Role matches route or route is allowed. Allowing access.',
          );

        return null; // Allow navigation
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
        pageBuilder:
            (context, state) => MaterialPage(
              key: const ValueKey('__changePasswordPageKey__'),
              fullscreenDialog: true,
              child: const ChangePasswordPage(),
            ),
      ),

      // Reseller routes SHELL
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          // Determine the current index dynamically
          final currentIndex = _calculateCurrentIndex(state);
          final location = state.matchedLocation;
          return MainLayout(
            currentIndex: currentIndex,
            location: location,
            child: child,
          );
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
        path: '/admin/dev-tools', // Path for the new page
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder:
            (context, state) => const MaterialPage(
              child: DevToolsPage(), // Navigate to the new DevToolsPage
            ),
      ),
      GoRoute(
        path: '/admin/users/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final user = state.extra as AppUser?;
          if (user == null) {
            return MaterialPage(
              key: ValueKey(state.uri.toString()),
              child: Scaffold(body: Center(child: Text("User not found"))),
            );
          }
          return MaterialPage(
            key: ValueKey(state.uri.toString()),
            child: UserDetailPage(user: user),
          );
        },
      ),
      GoRoute(
        path: '/profile-details',
        pageBuilder:
            (context, state) => MaterialPage(
              key: const ValueKey('__profilePageKey__'),
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
          // This route is currently not used since we've refactored to opportunity details
          // We'll keep it for backwards compatibility but redirect to home
          return MaterialPage(
            child: Scaffold(body: Center(child: Text("Page has been moved"))),
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
        path: '/admin/stats-detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          // Extract data from 'extra'
          final Map<String, dynamic>? args =
              state.extra as Map<String, dynamic>?;
          // final ChartType? chartType = args?['chartType'] as ChartType?; // REMOVE ChartType
          final TimeFilter? timeFilter = args?['timeFilter'] as TimeFilter?;

          // Basic validation
          if ( /* chartType == null || */ timeFilter == null) {
            // REMOVE ChartType check
            return const MaterialPage(
              child: Scaffold(body: Center(child: Text("Missing chart data"))),
            );
          }

          return MaterialPage(
            child: AdminStatsDetailPage(
              // chartType: chartType, // REMOVE ChartType
              timeFilter: timeFilter,
            ),
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
      GoRoute(
        path: '/admin/opportunity-detail', // New route for detail page
        parentNavigatorKey:
            _rootNavigatorKey, // Use root navigator to appear above shell
        pageBuilder: (context, state) {
          final submission = state.extra as ServiceSubmission?;
          if (submission == null) {
            // Handle error case where submission data is missing
            return const MaterialPage(
              child: Scaffold(
                body: Center(child: Text("Submission data missing")),
              ),
            );
          }
          return MaterialPage(
            // Consider adding a unique key if needed: key: ValueKey(submission.id),
            fullscreenDialog: false, // Display as a standard page push
            child: OpportunityDetailFormView(submission: submission),
          );
        },
      ),
      GoRoute(
        path: '/opportunity-details',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final opportunity = state.extra as SalesforceOpportunity?;
          if (opportunity == null) {
            return const MaterialPage(
              child: Scaffold(
                body: Center(child: Text("Opportunity data missing")),
              ),
            );
          }
          return MaterialPage(
            fullscreenDialog: false,
            child: OpportunityDetailsPage(opportunity: opportunity),
          );
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

  // *** Make the root key accessible for ChangePasswordPage ***
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;
  // **********************************************************
}
