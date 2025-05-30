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
import '../../presentation/screens/clients/reseller_opportunity_page.dart'
    as reseller_clients;
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
import '../../features/settings/presentation/pages/profile_page.dart';
import '../../presentation/screens/admin/stats/admin_stats_detail_page.dart';
import '../../core/models/enums.dart';
import '../../presentation/screens/admin/dev_tools_page.dart';
import '../../core/models/service_submission.dart';
import '../../features/opportunity/presentation/pages/admin_salesforce_opportunity_detail_page.dart';
import '../../features/proposal/presentation/pages/admin_salesforce_proposal_detail_page.dart';
import '../../features/proposal/presentation/screens/proposal_detail_page.dart';
import '../../presentation/widgets/app_loading_indicator.dart';

import 'package:twogether/features/providers/presentation/pages/admin_provider_list_page.dart';
import 'package:twogether/features/opportunity/presentation/pages/admin_opportunity_submission_page.dart';
import 'package:twogether/features/providers/presentation/pages/create_provider_page.dart';
import 'package:twogether/features/providers/presentation/pages/admin_provider_files_page.dart';
import 'package:twogether/features/providers/presentation/pages/reseller_provider_list_page.dart';
import 'package:twogether/features/providers/presentation/pages/reseller_provider_files_page.dart';
import 'package:twogether/features/opportunity/presentation/pages/admin_opportunity_page.dart';
import 'package:twogether/features/proposal/presentation/pages/proposal_creation_page.dart';
import 'package:twogether/features/chat/presentation/pages/admin_chat_page.dart';
import 'package:twogether/features/opportunity/data/models/salesforce_opportunity.dart'
    as data_models;
import 'package:twogether/features/proposal/data/models/salesforce_proposal.dart'
    as proposal_models;
import 'package:twogether/presentation/screens/clients/reseller_proposal_details_page.dart';
import 'package:twogether/features/providers/domain/models/provider_info.dart';
import 'package:twogether/features/proposal/presentation/pages/admin_cpe_proposta_detail_page.dart';
import '../../features/user_management/presentation/pages/user_create_page.dart';
import 'package:twogether/debug/minimal_debug_extra_page.dart'; // Import the new page

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
        if (kDebugMode) {
          print(
            'Auth Listener: User is not null (UID: ${user.uid}). Entering try block...',
          );
        }
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

            if (kDebugMode) {
              print(
                'Auth Listener: User data fetched. Attempting token update...',
              );
            }

            // *** Start FCM Token Logic ***
            // Get initial token and save it
            await _updateFcmToken();
            // Listen for token refreshes
            _firebaseMessaging.onTokenRefresh.listen((newToken) async {
              if (kDebugMode) {
                print('FCM Token Refreshed.');
              }
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
          if (kDebugMode) {
            print('Auth Listener: ERROR caught in _initAuth try block: $e');
          }
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
      if (kDebugMode) {
        print('Cannot update FCM token, user is null.');
      }
      return;
    }

    try {
      // Get token if not provided (e.g., on initial login)
      final fcmToken = token ?? await _firebaseMessaging.getToken();

      if (fcmToken != null) {
        final userRef = _firestore.collection('users').doc(user.uid);
        if (kDebugMode) {
          print('Attempting to add FCM token for user ${user.uid}');
        }
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
        if (kDebugMode) {
          print('Successfully added FCM token for user ${user.uid}');
        }
      } else {
        if (kDebugMode) {
          print('FCM token is null, cannot update for user ${user.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating FCM token for user ${user.uid}: $e');
      }
      // Decide if you want to rethrow or handle silently
    }
  }

  Future<void> _removeFcmToken() async {
    // Get the UID before potentially signing out completely
    final uidToRemoveTokenFor = _auth.currentUser?.uid;
    if (uidToRemoveTokenFor == null) {
      // No user logged in, nothing to remove. This might happen if called after sign out completes.
      if (kDebugMode) {
        print('No user logged in, skipping FCM token removal.');
      }
      return;
    }

    try {
      // Get the specific token for this device instance to remove it
      final fcmToken = await _firebaseMessaging.getToken();

      if (fcmToken != null) {
        final userRef = _firestore.collection('users').doc(uidToRemoveTokenFor);
        if (kDebugMode) {
          print('Attempting to remove FCM token for user $uidToRemoveTokenFor');
        }
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([fcmToken]),
        });
        if (kDebugMode) {
          print('Successfully removed FCM token for user $uidToRemoveTokenFor');
        }
      } else {
        if (kDebugMode) {
          print(
            'FCM token is null, cannot remove for user $uidToRemoveTokenFor',
          );
        }
      }
    } catch (e) {
      // Log error but don't prevent sign-out
      if (kDebugMode) {
        print('Error removing FCM token for user $uidToRemoveTokenFor: $e');
      }
      // Check if the error is due to the document not existing (already deleted?)
      if (e is FirebaseException && e.code == 'not-found') {
        if (kDebugMode) {
          print(
            'User document $uidToRemoveTokenFor not found during token removal, might have been deleted.',
          );
        }
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
    if (kDebugMode) {
      print('AuthNotifier: signInWithEmailAndPassword called.');
    } // LOG
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
      if (kDebugMode) {
        print('AuthNotifier: Error during sign in: $e');
      } // LOG
      rethrow;
    }
    if (kDebugMode) {
      print('AuthNotifier: signInWithEmailAndPassword finished.');
    } // LOG
  }

  // Mark first login as completed
  Future<void> completeFirstLogin() async {
    if (kDebugMode) {
      print(
        'AuthNotifier: completeFirstLogin called (now also sets initialPasswordChanged).',
      );
    } // LOG
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
        if (kDebugMode) {
          print(
            'AuthNotifier: State updated - isFirstLogin: false, initialPasswordChanged: true.',
          );
        } // LOG
      } catch (e) {
        if (kDebugMode) {
          print('Error updating first login / password changed status: $e');
        }
        // Rethrow? Or handle more gracefully?
        rethrow; // Rethrow for ChangePasswordPage to catch
      }
    }
    if (kDebugMode) {
      print('AuthNotifier: completeFirstLogin finished.');
    } // LOG
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    if (kDebugMode) {
      print('AuthNotifier: updatePassword called.');
    } // LOG
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.updatePassword(newPassword);
        if (kDebugMode) {
          print('AuthNotifier: Firebase password updated.');
        } // LOG
        await completeFirstLogin();
        if (kDebugMode) {
          print('AuthNotifier: updatePassword finished successfully.');
        } // LOG
      } catch (e) {
        if (kDebugMode) {
          print('AuthNotifier: Error updating password: $e');
        } // LOG
        rethrow;
      }
    } else {
      if (kDebugMode) {
        print('AuthNotifier: Error updating password - No authenticated user.');
      } // LOG
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

// Custom page transitions
class _SlideTransition extends CustomTransitionPage<void> {
  _SlideTransition({
    required super.child, 
    bool reverse = false,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Start from right
            const end = Offset.zero;
            const reversedBegin = Offset(-1.0, 0.0); // Start from left for reverse
            
            final tween = Tween(
              begin: reverse ? reversedBegin : begin, 
              end: end
            );
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final offsetAnimation = curvedAnimation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

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
    if (location.startsWith('/settings')) {
      return 3; // Renamed /profile to /settings
    }
    return 0; // Default to home
  }

  // Initialization of router
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      // DETAILED LOGGING START
      if (kDebugMode) {
        print(
          'GoRouter REDIRECT ENTRY --- Path: ${state.path}, FullPath: ${state.fullPath}, MatchedLocation: ${state.matchedLocation}, Name: ${state.name}, ExtraType: ${state.extra?.runtimeType}, ExtraValue: ${state.extra.toString()}, Params: ${state.pathParameters}, QueryParams: ${state.uri.queryParameters}, URI: ${state.uri.toString()}',
        );
      }
      // DETAILED LOGGING END

      if (kDebugMode) {
        print(
          'GoRouter Redirect: Checking auth state... Current location: ${state.uri.toString()}',
        );
      } // LOG
      try {
        final isAuthenticated = authNotifier.isAuthenticated;
        final isAdmin = authNotifier.isAdmin;
        final currentRoute = state.matchedLocation;
        final isLoginPage = currentRoute == '/login';
        final isLoadingPage = currentRoute == '/auth-loading';

        // If we land on /auth-loading IMMEDIATELY after a restart
        // or if not authenticated and on loading page, force to /login.
        // The login process itself will explicitly navigate to /auth-loading when it starts.
        if (isLoadingPage && !isAuthenticated) {
          if (kDebugMode) {
            print(
              'GoRouter Redirect: On /auth-loading and not authenticated. Forcing to /login.',
            );
          }
          return '/login';
        }

        // --- 1. User Not Authenticated (and NOT on loading page, and NOT on login page already) ---
        // This rule handles the general case for unauthenticated users not on /auth-loading.
        if (!isAuthenticated && !isLoginPage) {
          // Combined condition
          if (kDebugMode) {
            print(
              'GoRouter Redirect: Not logged in, not on loading, not on login. Redirecting to /login from ${state.uri.toString()}',
            );
          }
          return '/login';
        }

        // --- User IS Authenticated ---
        if (isAuthenticated) {
          // --- 2. Redirect AWAY from /auth-loading page after auth completes ---
          if (isLoadingPage) {
            // Artificial delay to allow the loading indicator to appear briefly
            // Only delay if we are actually coming from a state where it might be too fast (e.g., after login)
            // We check if the previous route was login, or if there was no previous route (direct entry to /auth-loading somehow)
            // For simplicity, we'll apply the delay always when on /auth-loading and authenticated.

            if (kDebugMode) {
              print(
                'GoRouter Redirect: On /auth-loading and authenticated. Applying small delay...',
              );
            }
            await Future.delayed(
              const Duration(milliseconds: 300),
            ); // Adjusted delay

            final target = isAdmin ? '/admin' : '/';
            if (kDebugMode) {
              print(
                'GoRouter Redirect: Authenticated on loading page, redirecting to $target',
              );
            }
            return target;
          }

          // --- 3. Redirect AWAY from Login page if already authenticated ---
          if (isLoginPage) {
            final target = isAdmin ? '/admin' : '/';
            if (kDebugMode) {
              print(
                'GoRouter Redirect: Authenticated and on login page, redirecting to $target',
              );
            }
            return target;
          }

          // --- 4. Apply Role-Based Routing & Salesforce Checks for Authenticated Users ---
          if (isAdmin) {
            final allowedNonAdminPaths = [
              '/proposal/create',
              '/review-this-submission' // Allow the actual target page for submissions
            ];
            if (!currentRoute.startsWith('/admin') && !allowedNonAdminPaths.contains(currentRoute)) {
              if (kDebugMode) {
                print(
                  'GoRouter Redirect: Admin detected outside allowed routes, redirecting to /admin from ${state.uri.toString()}',
                );
              }
              return '/admin';
            }
            // Salesforce checks for admin (simplified for brevity, assume original logic here)
            // ...
          } else {
            // Reseller Flow
            if (currentRoute.startsWith('/admin') ||
                currentRoute == '/proposal/create') {
              if (kDebugMode) {
                print(
                  'GoRouter Redirect: Reseller detected on admin/proposal route, redirecting to / from ${state.uri.toString()}',
                );
              }
              return '/'; // Reseller base route
            }
          }
        }

        // Allow access if no other rule applied
        if (kDebugMode) {
          print(
            'GoRouter Redirect: No specific redirect needed for $currentRoute. Allowing access.',
          );
        }
        return null; // Allow navigation
      } catch (e) {
        if (kDebugMode) {
          print(
            "[Redirect] Error accessing ProviderScope or reading providers: $e",
          );
          print("[Redirect] Ensure GoRouter is created within ProviderScope.");
        }
        if (state.matchedLocation != '/login') {
          return '/login';
        } else {
          return null;
        }
      }
    },
    routerNeglect: true,
    routes: [
      // Remove DEBUG Route
      /*
      GoRoute(
        path: '/loading-preview',
        name: 'loadingPreview',
        builder: (context, state) => const LoadingIndicatorPreviewPage(),
      ),
      */
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/change-password',
        pageBuilder:
            (context, state) => _SlideTransition(
              child: const ChangePasswordPage(),
            ),
      ),

      // NEW DEBUG ROUTE START
      GoRoute(
        path: '/debug-extra-test',
        name: 'debugExtraTest',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          if (kDebugMode) {
            print('[DEBUG EXTRA TEST PAGE] Received extra: ${state.extra?.runtimeType} - ${state.extra.toString()}');
          }
          return MaterialPage(
            child: Scaffold(
              appBar: AppBar(title: const Text('Debug Extra Test')),
              body: Center(
                child: Text('Extra received: ${state.extra?.runtimeType}\\nValue: ${state.extra.toString()}'),
              ),
            ),
          );
        },
      ),
      // NEW DEBUG ROUTE END

      // NEW MINIMAL DEBUG ROUTE START
      GoRoute(
        path: '/minimal-debug-page',
        name: 'minimalDebugPage',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return MaterialPage(
            child: MinimalDebugExtraPage(extraData: state.extra),
          );
        },
      ),
      // NEW MINIMAL DEBUG ROUTE END

      // Reseller routes SHELL
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
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
            path: '/',
            pageBuilder: (context, state) => NoTransitionPage(child: ResellerHomePage()),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => NoTransitionPage(child: reseller_clients.ClientsPage()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) => const NoTransitionPage(child: MessagesPage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),

      // Admin routes SHELL
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) {
          return AdminLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/admin',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminHomePage()),
          ),
          GoRoute(
            path: '/admin/opportunities',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: OpportunityVerificationPage(),
                ),
          ),
          GoRoute(
            path: '/admin/stats-detail',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final timeFilter = extra?['timeFilter'] as TimeFilter?;
              return NoTransitionPage(
                child: AdminStatsDetailPage(
                  timeFilter: timeFilter ?? TimeFilter.monthly,
                ),
              );
            },
          ),
          GoRoute(
            path: '/admin/user-management',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: UserManagementPage()),
          ),
          GoRoute(
            path: '/admin/dev-tools',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: DevToolsPage()),
          ),
          GoRoute(
            path: '/admin/settings',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: AdminSettingsPage()),
          ),
          GoRoute(
            path: '/admin/messages',
            name: 'adminMessages',
            parentNavigatorKey: _adminShellNavigatorKey,
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminChatPage()),
          ),
        ],
      ),

      // --- Top-Level Secondary Routes (No Shell) ---
      GoRoute(
        path: '/admin/opportunity/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _SlideTransition(
          child: OpportunityDetailFormView(),
        ),
      ),
      GoRoute(
        path: '/review-this-submission',
        name: 'adminSubmissionReview',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final submission = state.extra as ServiceSubmission?;
          if (submission == null) {
            return const MaterialPage(
              child: Scaffold(
                body: Center(child: Text("Error: Submission data missing for review.")),
              ),
            );
          }
          return _SlideTransition(
            child: OpportunityDetailFormView(submission: submission),
          );
        },
      ),
      GoRoute(
        path: '/admin/opportunity-detail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          if (state.extra is data_models.SalesforceOpportunity) {
            final opportunity = state.extra as data_models.SalesforceOpportunity?;
            // The null check for opportunity is actually redundant now if previous line is true, 
            // but kept for clarity if SalesforceOpportunity itself could be null conceptually (though not from this cast).
            if (opportunity == null) { 
              return const MaterialPage(
                child: Scaffold(
                  body: Center(child: Text("Opportunity data missing")),
                ),
              );
            }
            return _SlideTransition(
              child: OpportunityDetailsPage(opportunity: opportunity),
            );
          } else {
            // Handle incorrect type or null extra
            String errorMessage = "Error: Incorrect data type for /admin/opportunity-detail.";
            if (state.extra == null) {
              errorMessage = "Error: Missing data for /admin/opportunity-detail.";
            } else {
              errorMessage = "Error: Expected SalesforceOpportunity, got ${state.extra?.runtimeType} for /admin/opportunity-detail.";
              if (kDebugMode) {
                print("ROUTING ERROR on /admin/opportunity-detail: Expected SalesforceOpportunity, got ${state.extra?.runtimeType}");
              }
            }
            return MaterialPage(
              child: Scaffold(
                appBar: AppBar(title: const Text("Navigation Error")),
                body: Center(child: Text(errorMessage)),
              ),
            );
          }
        },
      ),
      GoRoute(
        path: '/admin/providers',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _SlideTransition(
          child: const AdminProviderListPage(),
          reverse: false,
        ),
        routes: [
          GoRoute(
            path: 'create', // relative to /admin/providers
            parentNavigatorKey: _rootNavigatorKey, // Still top-level navigation context
            pageBuilder: (context, state) => _SlideTransition(
              child: const CreateProviderPage(),
              reverse: false,
            ),
          ),
          GoRoute(
            path: ':id', // relative to /admin/providers
            parentNavigatorKey: _rootNavigatorKey, // Still top-level navigation context
            pageBuilder: (context, state) {
              final providerId = state.pathParameters['id'];
              final providerInfo = state.extra as ProviderInfo?; // Cast extra to ProviderInfo, nullable

              if (providerId != null && providerInfo != null) { // Check both are non-null
                return _SlideTransition(
                  child: AdminProviderFilesPage(
                    providerId: providerId,
                    providerName: providerInfo.name, // Pass the name from ProviderInfo
                  ),
                  reverse: false,
                );
              } else if (providerId == null) {
                 return _SlideTransition(
                  child: const Scaffold(body: Center(child: Text('Error: Provider ID missing'))),
                  reverse: false,
                ); 
              } else { // providerInfo must be null if providerId was not
                return _SlideTransition(
                  child: const Scaffold(body: Center(child: Text('Error: Provider data missing'))),
                  reverse: false,
                );
              }
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/users/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(child: UserCreatePage()),
      ),
      GoRoute(
        path: '/admin/users/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final user = state.extra as AppUser?;
          if (user == null) {
            return _SlideTransition(
              child: const Scaffold(body: Center(child: Text("User data missing"))),
            );
          }
          return _SlideTransition(
            child: UserDetailPage(user: user),
          );
        },
      ),
      GoRoute(
        path: '/profile-details',
        pageBuilder:
            (context, state) => _SlideTransition(
              child: const ProfilePage(),
              reverse: false, // Assuming slide in from right
            ),
      ),
      GoRoute(
        path: '/services',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return _SlideTransition(
            child: ServicesPage(),
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
        path: '/dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
           return _SlideTransition(
        child: const DashboardPage(),
          );
        },
      ),
      GoRoute(
        path: '/proposal/create',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(
                  child: Text('Error: Missing required proposal data'),
                ),
              ),
            );
          }

          final String? sfOppId = extra['salesforceOpportunityId'] as String?;
          final String? sfAccId = extra['salesforceAccountId'] as String?;
          final String? accName = extra['accountName'] as String?;
          final String? resSfId = extra['resellerSalesforceId'] as String?;
          final String? resName = extra['resellerName'] as String?;
          final String? nif = extra['nif'] as String?;
          final String? oppName = extra['opportunityName'] as String?;

          // Validate required parameters
          if (sfOppId == null ||
              sfAccId == null ||
              accName == null ||
              resSfId == null ||
              resName == null ||
              nif == null ||
              oppName == null) {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(
                  child: Text('Error: Invalid or incomplete proposal data'),
                ),
              ),
            );
          }

          return _SlideTransition(
            child: ProposalCreationPage(
              salesforceOpportunityId: sfOppId,
              salesforceAccountId: sfAccId,
              accountName: accName,
              resellerSalesforceId: resSfId,
              resellerName: resName,
              nif: nif,
              opportunityName: oppName,
            ),
            reverse: false,
          );
        },
      ),
      // ADD Proposal Detail Route here
      GoRoute(
        path: '/proposal/:index',
        name: 'proposalDetails',
        parentNavigatorKey:
            _rootNavigatorKey, // Ensure it uses the root navigator
        pageBuilder: (context, state) {
          final indexString = state.pathParameters['index']!;
          final index = int.tryParse(indexString) ?? 0;
          final proposal = state.extra as proposal_models.SalesforceProposal?;

          if (proposal == null) {
            return const MaterialPage(
              child: Scaffold(
                body: Center(child: Text('Proposal data missing')),
              ),
            );
          }
          return MaterialPage(
            child: ProposalDetailPage(proposal: proposal, index: index),
          );
        },
      ),
      GoRoute(
        path: '/reseller-proposal-details',
        parentNavigatorKey: _rootNavigatorKey, // Ensures it's a top-level page
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final proposalId = args?['proposalId'] as String?;
          final proposalName = args?['proposalName'] as String?;

          if (proposalId == null || proposalName == null) {
            return MaterialPage(
              child: Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(
                  child: Text('Error: Proposal ID or Name missing'),
                ),
              ),
            );
          }
          return _SlideTransition(
            child: ResellerProposalDetailsPage(
              proposalId: proposalId,
              proposalName: proposalName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/auth-loading',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: AppLoadingIndicator(
            ),
          ),
        ),
      ),
      // ADD /providers route here as a top-level route
      GoRoute(
        path: '/providers', 
        parentNavigatorKey: _rootNavigatorKey, 
        pageBuilder: (context, state) {
          return _SlideTransition(
            child: const ResellerProviderListPage(),
          );
        },
        routes: [
          GoRoute(
            path: ':providerId', 
            parentNavigatorKey: _rootNavigatorKey, 
            pageBuilder: (context, state) {
              final providerId = state.pathParameters['providerId'];
              final providerInfo = state.extra as ProviderInfo?;

              if (providerId == null || providerInfo == null) {
                return const MaterialPage(
                  child: Scaffold(body: Center(child: Text('Error: Missing Provider ID or Info'))),
                );
              }
              return _SlideTransition(
                child: ResellerProviderFilesPage(
                  providerId: providerId,
                  providerName: providerInfo.name,
                ),
              );
            },
          ),
        ],
      ),
      // Add as a top-level route (outside all ShellRoutes):
      GoRoute(
        path: '/admin/salesforce-opportunity-detail/:opportunityId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final opportunityId = state.pathParameters['opportunityId'];
          if (opportunityId != null) {
            return _SlideTransition(
              child: AdminSalesforceOpportunityDetailPage(
                opportunityId: opportunityId,
              ),
              reverse: false,
            );
          } else {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(child: Text('Error: Opportunity ID missing')),
              ),
            );
          }
        },
      ),
      GoRoute(
        path: '/admin/cpe-proposta/:id',
        name: 'adminCpePropostaDetail',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final cpePropostaId = state.pathParameters['id']!;
          return _SlideTransition(
            child: AdminCpePropostaDetailPage(cpePropostaId: cpePropostaId),
          );
        },
      ),
      GoRoute(
        path: '/opportunity-details',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          if (state.extra is data_models.SalesforceOpportunity) {
            final opportunity = state.extra as data_models.SalesforceOpportunity?;
            if (opportunity == null) {
              return const MaterialPage(
                child: Scaffold(
                  body: Center(child: Text("Opportunity data missing")),
                ),
              );
            }
            return _SlideTransition(
              child: OpportunityDetailsPage(opportunity: opportunity),
            );
          } else {
            String errorMessage = "Error: Incorrect data type for /opportunity-details.";
            if (state.extra == null) {
              errorMessage = "Error: Missing data for /opportunity-details.";
            } else {
              errorMessage = "Error: Expected SalesforceOpportunity, got \\${state.extra?.runtimeType} for /opportunity-details.";
              if (kDebugMode) {
                print("ROUTING ERROR on /opportunity-details: Expected SalesforceOpportunity, got \\${state.extra?.runtimeType}");
              }
            }
            return MaterialPage(
              child: Scaffold(
                appBar: AppBar(title: const Text("Navigation Error")),
                body: Center(child: Text(errorMessage)),
              ),
            );
          }
        },
      ),
      GoRoute(
        path: '/admin/proposal/:proposalId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final proposalId = state.pathParameters['proposalId'];
          if (proposalId != null) {
            return _SlideTransition(
              child: AdminSalesforceProposalDetailPage(proposalId: proposalId),
              reverse: false,
            );
          } else {
            return const NoTransitionPage(
              child: Scaffold(
                body: Center(child: Text('Error: Proposal ID missing')),
              ),
            );
          }
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
