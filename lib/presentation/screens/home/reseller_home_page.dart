import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../widgets/logo.dart';
import 'dart:math';
import '../../../core/theme/ui_styles.dart';

class ResellerHomePage extends ConsumerStatefulWidget {
  const ResellerHomePage({super.key});

  @override
  ConsumerState<ResellerHomePage> createState() => _ResellerHomePageState();
}

class _ResellerHomePageState extends ConsumerState<ResellerHomePage> {
  bool _isEarningsVisible = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // Set up listener to detect manual pull-to-refresh
    _scrollController.addListener(() {
      // If we're overscrolling at the top (pulling down)
      if (_scrollController.position.pixels < -50) {
        // Trigger the refresh
        _refreshIndicatorKey.currentState?.show();
      }
    });
  }

  @override
  void dispose() {
    // Make sure to cancel any animations or ongoing operations
    _scrollController.dispose();
    // Clean up any resources to prevent leaks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure all resources are properly released
      if (mounted) {
        setState(() {});
      }
    });
    super.dispose();
  }

  // Perform the refresh operation
  Future<void> _onRefresh() async {
    // Simulate a network request
    await Future.delayed(const Duration(seconds: 2));

    // Update UI with the refreshed data
    if (mounted) {
      setState(() {
        // For demo, we'll toggle the earnings visibility 70% of the time
        if (Random().nextInt(10) < 7) {
          _isEarningsVisible = !_isEarningsVisible;
        }
      });
    }
  }

  // Helper method to get user initials
  String _getUserInitials(AppLocalizations l10n, String? name, String? email) {
    if (name != null && name.isNotEmpty) {
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        // If there are multiple parts, use first letter of first and last name
        return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
      } else if (nameParts.isNotEmpty) {
        // If there's only one part, use the first letter
        return nameParts.first[0].toUpperCase();
      }
    }

    // Fallback to email
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    // Default
    return l10n.userInitialsDefault;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final currentUser = ref.watch(authStateChangesProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Set background to 1/3 of screen height
    final backgroundHeight = screenSize.height * 0.33;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: ClipRect(
        child: Stack(
          children: [
            // Fixed background image (with no parallax effect)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: backgroundHeight,
              child: Stack(
                children: [
                  // Background image
                  Image.asset(
                    'assets/images/backgrounds/homepage.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  // Optional: Add a subtle gradient overlay for better text contrast
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main scrollable content
            RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _onRefresh,
              backgroundColor: theme.colorScheme.surface,
              color: theme.colorScheme.primary,
              strokeWidth: 2.5,
              displacement: statusBarHeight + 40,
              edgeOffset: 0,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Top section with transparent background (since image is behind)
                    Container(
                      height: backgroundHeight,
                      width: double.infinity,
                      child: Column(
                        children: [
                          // Empty space for the status bar
                          SizedBox(height: statusBarHeight + 20),

                          // Top row with profile and action icons
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Profile icon with user's initials
                                currentUser.when(
                                  data:
                                      (user) => GestureDetector(
                                        onTap: () => context.go('/profile'),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Center(
                                              child: Text(
                                                _getUserInitials(
                                                  l10n,
                                                  user?.displayName,
                                                  user?.email,
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  loading:
                                      () => Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface
                                              .withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  error:
                                      (_, __) => GestureDetector(
                                        onTap: () => context.go('/profile'),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Center(
                                              child: Text(
                                                l10n.userInitialsDefault,
                                                style: theme
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                ),

                                // Action icons row
                                Row(
                                  children: [
                                    // Search icon
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.search,
                                      onTap: () {},
                                    ),
                                    const SizedBox(width: 10),
                                    // Notification bell icon
                                    _buildCircleIconButton(
                                      icon: CupertinoIcons.bell_fill,
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Expanded space to vertically center the commission box
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: _buildCommissionBox(l10n),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // White content area
                    Container(
                      width: double.infinity,
                      color: theme.colorScheme.background,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickActionsSection(l10n),
                          const SizedBox(height: 30),
                          _buildNotificationsSection(l10n),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.15),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildQuickActionsSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeQuickActionsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 24),

        // Create Service button with smooth gradient and shadow
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton(
            onPressed: () => context.push('/services'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    Color.lerp(AppTheme.primary, Colors.blue, 0.4) ??
                        AppTheme.primary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.add_circled,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.homeCreateNewServiceButton,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with badge
        Row(
          children: [
            Text(
              l10n.homeNotifications,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '4',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pendentes section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                    theme.brightness == Brightness.dark
                        ? theme.colorScheme.shadow.withOpacity(0.3)
                        : theme.colorScheme.shadow.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color:
                  theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface.withOpacity(0.05)
                      : Colors.transparent,
              width: theme.brightness == Brightness.dark ? 1 : 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pendentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '-6,42',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Notification items
        ..._buildNotificationItems(l10n),
      ],
    );
  }

  List<Widget> _buildNotificationItems(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final notifications = [
      {
        'title': l10n.homeNotificationExamplePurchaseTitle(8110),
        'amount': '-10,00',
        'date': '31 mar',
        'type': 'payment',
      },
      {
        'title': l10n.homeNotificationExampleRejectionTitle,
        'description': l10n.homeNotificationExampleRejectionDesc('TR003_0001'),
        'type': 'rejection',
        'data': {
          'submissionId': 'TR003_0001',
          'rejectionReason': 'The invoice image is not clear enough.',
          'rejectionDate': DateTime.now(),
          'isPermanentRejection': false,
        },
      },
    ];

    return notifications.map((notification) {
      if (notification['type'] == 'payment') {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.phone_fill,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['date'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                notification['amount'] as String,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      } else {
        return _buildNotificationItem(
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          title: notification['title'] as String,
          description: notification['description'] as String,
          iconColor: theme.colorScheme.error,
          onTap: () {
            final data = notification['data'] as Map<String, dynamic>;
            context.go('/notifications/${data['submissionId']}');
          },
        );
      }
    }).toList();
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color:
                  theme.brightness == Brightness.dark
                      ? theme.colorScheme.shadow.withOpacity(0.2)
                      : theme.colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color:
                theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface.withOpacity(0.05)
                    : Colors.transparent,
            width: theme.brightness == Brightness.dark ? 1 : 0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: (iconColor ?? theme.colorScheme.primary).withOpacity(
                      0.1,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor ?? theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionBox(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/dashboard'),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            // Enhanced glass effect with gradient
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.3),
                theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Account title section with shimmer effect
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white,
                            Colors.white.withOpacity(0.9),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        l10n.homeCommissionBoxTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Balance amount with visibility toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEarningsVisible = !_isEarningsVisible;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Amount section
                          _isEarningsVisible
                              ? Row(
                                children: [
                                  Text(
                                    '5500,10',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.currencyCodeEUR,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.eye_fill,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.currencyCodeEUR,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.eye_slash_fill,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // VIEW DETAILS button with enhanced styling
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => context.push('/dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.homeCommissionBoxDetailsButton,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




