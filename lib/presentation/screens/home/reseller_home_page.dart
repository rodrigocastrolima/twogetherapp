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
    _scrollController.dispose();
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
  String _getUserInitials(String? name, String? email) {
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
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.4; // Increased to show more background
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final currentUser = ref.watch(authStateChangesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: Image.asset(
              'assets/images/backgrounds/homepage.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // Use RefreshIndicator with a custom color and shape
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _onRefresh,
            backgroundColor: Colors.white,
            color: const Color(0xFF1A2337),
            strokeWidth: 2.5,
            displacement: statusBarHeight + 40,
            edgeOffset: 0,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Empty space for the status bar
                  SizedBox(height: statusBarHeight + 20),

                  // Top row with profile and action icons - NO LOGO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Center(
                                      child: Text(
                                        _getUserInitials(
                                          user?.displayName,
                                          user?.email,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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
                                  color: Colors.white.withOpacity(0.2),
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
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Center(
                                      child: const Text(
                                        'U',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),

                        // Action icons row - logo completely removed
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

                  // Space before commission box - center it vertically in the visible area
                  SizedBox(height: imageHeight * 0.1),

                  // Commission Box (centered and less blurry)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildCommissionBox(),
                  ),

                  // Space after commission box - matching the space before it
                  SizedBox(height: imageHeight * 0.1),

                  // White content area - with straight edges
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(0), // Straight edges
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      60,
                    ), // Reduced padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickActionsSection(),
                        const SizedBox(height: 30), // Slightly reduced spacing
                        _buildNotificationsSection(),
                        const SizedBox(height: 40), // Reduced bottom spacing
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2337),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildQuickActionItem(
              icon: CupertinoIcons.arrow_right,
              label: 'Transferir\nNacional',
              onTap: () => {},
            ),
            _buildQuickActionItem(
              icon: CupertinoIcons.doc_text,
              label: 'Pagar\nserviços',
              onTap: () => {},
            ),
            _buildQuickActionItem(
              icon: CupertinoIcons.phone,
              label: 'Carregar\ntelemóvel',
              onTap: () => {},
            ),
            _buildQuickActionItem(
              icon: CupertinoIcons.paperplane,
              label: 'Partilhar\nIBAN',
              onTap: () => {},
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Dark button
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2337),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton.icon(
            onPressed: () => context.push('/services'),
            icon: const Icon(
              CupertinoIcons.add_circled,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Create New Service',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // --- TEMPORARY BUTTON ---
        ElevatedButton(
          onPressed: () {
            // Make sure you define this route in your GoRouter config
            context.push('/admin-retail-users');
          },
          child: const Text('TEMP: Go to Admin Retail Users'),
        ),

        // --- END TEMPORARY BUTTON ---
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1A2337), size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF1A2337).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with badge
        Row(
          children: [
            const Text(
              'Notificações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2337),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Pendentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2337),
                ),
              ),
              Text(
                '-6,42',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Notification items
        ..._buildNotificationItems(),
      ],
    );
  }

  List<Widget> _buildNotificationItems() {
    final notifications = [
      {
        'title': 'COMPRA 8110',
        'amount': '-10,00',
        'date': '31 mar',
        'type': 'payment',
      },
      {
        'title': 'Submission Rejected',
        'description':
            'Your solar commercial submission TR003_0001 was rejected',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                        color: const Color(0xFF1A2337).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['title'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2337),
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
          iconColor: AppTheme.destructive,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: (iconColor ?? AppTheme.primary).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2337),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A2337).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: const Color(0xFF1A2337).withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionBox() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Empty handler to ensure the InkWell captures touches
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1), // Less blur
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Account title section
                    Text(
                      'COMISSÕES',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.5,
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
                                  const Text(
                                    '5500,10',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'EUR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Icon(
                                    CupertinoIcons.eye_fill,
                                    size: 22,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ],
                              )
                              : Row(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'EUR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Eye icon toggle
                                  Icon(
                                    CupertinoIcons.eye_slash_fill,
                                    size: 22,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // VER DETALHE button to navigate to dashboard page
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/dashboard');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          minimumSize: const Size(140, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'VER DETALHE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
