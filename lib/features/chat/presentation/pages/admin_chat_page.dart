import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:async';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../domain/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/chat_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Provider to fetch all resellers
final resellersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'reseller')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['displayName'] ?? data['email'] ?? 'Unknown User',
                'email': data['email'] ?? '',
              };
            }).toList(),
      );
});

class AdminChatPage extends ConsumerStatefulWidget {
  const AdminChatPage({super.key});

  @override
  ConsumerState<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends ConsumerState<AdminChatPage> {
  // State variable to track if we're showing only active conversations
  bool _showOnlyActive = true;

  // Search query
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Add a PageController to manage the page view
  final PageController _pageController = PageController(initialPage: 0);
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Add listener to page controller to update the current page value
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
        // Update the filter state when page changes
        _showOnlyActive = _currentPage < 0.5;
      });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Watch both conversations and resellers
    final conversationsStream = ref.watch(conversationsProvider);
    final resellersStream = ref.watch(resellersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: Text(
          l10n.messagesPageTitle,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.left,
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: BackdropFilter(
            filter: AppStyles.standardBlur,
            child: Container(
              decoration: AppStyles.glassCard(context),
              child: resellersStream.when(
                data: (resellers) {
                  if (resellers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.person_3_fill,
                            size: 48,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noRetailUsersFound,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return conversationsStream.when(
                    data: (conversations) {
                      // Get all conversations or filter active ones based on state
                      final List<ChatConversation> activeConversations =
                          conversations
                              .where((c) => c.active ?? false)
                              .toList();

                      final List<ChatConversation> inactiveConversations =
                          conversations
                              .where((c) => !(c.active ?? false))
                              .toList();

                      // Apply search filter if there's a query
                      final List<ChatConversation>
                      searchFilteredActiveConversations =
                          _searchQuery.isEmpty
                              ? activeConversations
                              : activeConversations.where((c) {
                                // Find the reseller for this conversation
                                final reseller = resellers.firstWhere(
                                  (r) => r['id'] == c.resellerId,
                                  orElse: () => {'name': '', 'email': ''},
                                );

                                // Search in name, email, and last message
                                return (reseller['name'] ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery) ||
                                    (reseller['email'] ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery) ||
                                    (c.lastMessageContent ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery);
                              }).toList();

                      final List<ChatConversation>
                      searchFilteredInactiveConversations =
                          _searchQuery.isEmpty
                              ? inactiveConversations
                              : inactiveConversations.where((c) {
                                // Find the reseller for this conversation
                                final reseller = resellers.firstWhere(
                                  (r) => r['id'] == c.resellerId,
                                  orElse: () => {'name': '', 'email': ''},
                                );

                                // Search in name, email, and last message
                                return (reseller['name'] ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery) ||
                                    (reseller['email'] ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery) ||
                                    (c.lastMessageContent ?? '')
                                        .toLowerCase()
                                        .contains(_searchQuery);
                              }).toList();

                      // Create maps of conversations by reseller ID for both filtered lists
                      final activeConversationsByResellerId = {
                        for (var conversation
                            in searchFilteredActiveConversations)
                          conversation.resellerId: conversation,
                      };

                      final inactiveConversationsByResellerId = {
                        for (var conversation
                            in searchFilteredInactiveConversations)
                          conversation.resellerId: conversation,
                      };

                      // Get all resellers that have conversations from each filtered list
                      final resellersWithActiveConversations =
                          resellers
                              .where(
                                (reseller) => activeConversationsByResellerId
                                    .containsKey(reseller['id']),
                              )
                              .toList();

                      final resellersWithInactiveConversations =
                          resellers
                              .where(
                                (reseller) => inactiveConversationsByResellerId
                                    .containsKey(reseller['id']),
                              )
                              .toList();

                      return Column(
                        children: [
                          // Search bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    theme.brightness == Brightness.dark
                                        ? theme.colorScheme.surface.withOpacity(
                                          0.7,
                                        )
                                        : theme.colorScheme.surface.withOpacity(
                                          0.9,
                                        ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (255 * 0.1).round(),
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor.withAlpha(
                                      (255 * 0.05).round(),
                                    ),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Search conversations...",
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha((255 * 0.5).round()),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                  prefixIcon: Icon(
                                    CupertinoIcons.search,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha((255 * 0.5).round()),
                                    size: 18,
                                  ),
                                  suffixIcon:
                                      _searchQuery.isNotEmpty
                                          ? IconButton(
                                            icon: Icon(
                                              CupertinoIcons.clear,
                                              color: theme.colorScheme.onSurface
                                                  .withAlpha(
                                                    (255 * 0.5).round(),
                                                  ),
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                            },
                                          )
                                          : null,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),

                          // Segmented control (Apple-style)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE5E5EA,
                                ), // iOS gray background
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Active Tab
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!_showOnlyActive) {
                                          setState(() {
                                            _showOnlyActive = true;
                                            _pageController.jumpToPage(0);
                                          });
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              _showOnlyActive
                                                  ? Colors.white
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          boxShadow:
                                              _showOnlyActive
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 1,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ]
                                                  : null,
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                l10n.active,
                                                style: TextStyle(
                                                  color:
                                                      _showOnlyActive
                                                          ? const Color(
                                                            0xFF007AFF,
                                                          )
                                                          : Colors.black87,
                                                  fontWeight:
                                                      _showOnlyActive
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (searchFilteredActiveConversations
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        _showOnlyActive
                                                            ? const Color(
                                                              0xFF007AFF,
                                                            ).withAlpha(
                                                              (255 * 0.2)
                                                                  .round(),
                                                            )
                                                            : Colors.black
                                                                .withAlpha(
                                                                  (255 * 0.1)
                                                                      .round(),
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${searchFilteredActiveConversations.length}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          _showOnlyActive
                                                              ? const Color(
                                                                0xFF007AFF,
                                                              )
                                                              : Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Inactive Tab
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (_showOnlyActive) {
                                          setState(() {
                                            _showOnlyActive = false;
                                            _pageController.jumpToPage(1);
                                          });
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              !_showOnlyActive
                                                  ? Colors.white
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          boxShadow:
                                              !_showOnlyActive
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 1,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ]
                                                  : null,
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                l10n.inactive,
                                                style: TextStyle(
                                                  color:
                                                      !_showOnlyActive
                                                          ? const Color(
                                                            0xFF007AFF,
                                                          )
                                                          : Colors.black87,
                                                  fontWeight:
                                                      !_showOnlyActive
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (searchFilteredInactiveConversations
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        !_showOnlyActive
                                                            ? const Color(
                                                              0xFF007AFF,
                                                            ).withAlpha(
                                                              (255 * 0.2)
                                                                  .round(),
                                                            )
                                                            : Colors.black
                                                                .withAlpha(
                                                                  (255 * 0.1)
                                                                      .round(),
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${searchFilteredInactiveConversations.length}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          !_showOnlyActive
                                                              ? const Color(
                                                                0xFF007AFF,
                                                              )
                                                              : Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Page View for the content
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (page) {
                                if ((_showOnlyActive && page == 1) ||
                                    (!_showOnlyActive && page == 0)) {
                                  setState(() {
                                    _showOnlyActive = page == 0;
                                  });
                                }
                              },
                              children: [
                                // Active conversations page
                                _buildConversationsContent(
                                  searchFilteredActiveConversations,
                                  resellersWithActiveConversations,
                                  activeConversationsByResellerId,
                                  l10n,
                                  theme,
                                  true,
                                ),

                                // Inactive conversations page
                                _buildConversationsContent(
                                  searchFilteredInactiveConversations,
                                  resellersWithInactiveConversations,
                                  inactiveConversationsByResellerId,
                                  l10n,
                                  theme,
                                  false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading:
                        () => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                l10n.commonLoading,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (255 * 0.7).round(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    error:
                        (error, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  size: 48,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.chatErrorLoading,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha((255 * 0.7).round()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  );
                },
                loading:
                    () => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            l10n.commonLoading,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withAlpha(
                                (255 * 0.7).round(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                error:
                    (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.chatErrorLoading,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  (255 * 0.7).round(),
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
        ),
      ),
    );
  }

  Widget _buildResellerItem(
    BuildContext context,
    Map<String, dynamic> reseller,
    ChatConversation? conversation,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Format time if conversation exists and has a last message
    final formattedTime =
        conversation?.lastMessageTime != null
            ? DateFormat('dd/MM • HH:mm').format(conversation!.lastMessageTime!)
            : '';

    // Check if there are unread messages for admin
    final hasUnreadMessages =
        conversation != null && conversation.unreadByAdmin;
    final unreadCount = conversation?.unreadCount ?? 0;

    // Check if conversation is inactive (only has welcome message)
    final bool isInactive =
        conversation != null && !(conversation.active ?? false);

    // Get email for display in the subtitle for inactive conversations
    final String email = reseller['email'] ?? '';

    // Get last message content for active conversations
    final String lastMessage = conversation?.lastMessageContent ?? '';

    // Determine which text to display in the subtitle
    final String subtitleText = isInactive ? email : lastMessage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            hasUnreadMessages
                ? theme.colorScheme.primary.withOpacity(0.07)
                : theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              hasUnreadMessages
                  ? theme.colorScheme.primary.withAlpha((255 * 0.3).round())
                  : theme.colorScheme.onSurface.withAlpha((255 * 0.1).round()),
          width: hasUnreadMessages ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha((255 * 0.05).round()),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Navigate to chat with this reseller
              _openOrCreateChat(context, reseller);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          hasUnreadMessages
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : isInactive
                              ? theme.colorScheme.onSurface.withAlpha(
                                (255 * 0.08).round(),
                              )
                              : theme.colorScheme.secondary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            hasUnreadMessages
                                ? theme.colorScheme.primary.withAlpha(
                                  (255 * 0.3).round(),
                                )
                                : isInactive
                                ? theme.colorScheme.onSurface.withAlpha(
                                  (255 * 0.1).round(),
                                )
                                : theme.colorScheme.secondary.withAlpha(
                                  (255 * 0.3).round(),
                                ),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isInactive
                            ? CupertinoIcons.person
                            : CupertinoIcons.person_solid,
                        size: 22,
                        color:
                            hasUnreadMessages
                                ? theme.colorScheme.primary
                                : isInactive
                                ? theme.colorScheme.onSurface.withAlpha(
                                  (255 * 0.5).round(),
                                )
                                : theme.colorScheme.onSurface.withAlpha(
                                  (255 * 0.9).round(),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reseller['name'],
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight:
                                      hasUnreadMessages
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                  color:
                                      hasUnreadMessages
                                          ? theme.colorScheme.onSurface
                                          : isInactive
                                          ? theme.colorScheme.onSurface
                                              .withAlpha((255 * 0.7).round())
                                          : theme.colorScheme.onSurface
                                              .withAlpha((255 * 0.9).round()),
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (formattedTime.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color:
                                      hasUnreadMessages
                                          ? theme.colorScheme.primary
                                          : isInactive
                                          ? theme.colorScheme.onSurface
                                              .withAlpha((255 * 0.3).round())
                                          : theme.colorScheme.onSurface
                                              .withAlpha((255 * 0.5).round()),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitleText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (255 * 0.6).round(),
                                  ),
                                  fontWeight: FontWeight.normal,
                                  fontStyle:
                                      isInactive
                                          ? FontStyle.normal
                                          : FontStyle.normal,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnreadMessages) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Add the menu button for all conversations (including inactive ones)
                  _buildActionsButton(context, reseller, conversation),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget for the actions button with menu
  Widget _buildActionsButton(
    BuildContext context,
    Map<String, dynamic> reseller,
    ChatConversation? conversation,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;

    // More reliable detection - only use desktop UI on screens wider than 1024px
    // For mobile and tablets (and browser tests), use the bottom sheet
    final bool useDesktopUI = width >= 1024 && !kIsWeb;

    // Use different widget types based on screen size
    if (useDesktopUI) {
      // Desktop: Use PopupMenuButton with themed styling
      return PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
          size: 20,
        ),
        padding: EdgeInsets.zero,
        tooltip: l10n.commonMore,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        color: theme.colorScheme.surface,
        itemBuilder: (BuildContext context) {
          return <PopupMenuEntry<String>>[
            // Heading with reseller name
            PopupMenuItem<String>(
              enabled: false,
              height: 36,
              value: 'header',
              child: Center(
                child: Text(
                  reseller['name'],
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const PopupMenuDivider(),
            // Clear conversation option
            PopupMenuItem<String>(
              value: 'clear',
              height: 48,
              child: Row(
                children: [
                  Icon(
                    Icons.cleaning_services_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clear Conversation',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Remove all messages',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(
                              (255 * 0.6).round(),
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Delete option
            PopupMenuItem<String>(
              value: 'delete',
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.delete, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Conversation',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Permanently delete this conversation',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(
                              (255 * 0.6).round(),
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        onSelected: (String value) {
          if (value == 'clear') {
            _showClearConfirmation(context, conversation, reseller['name']);
          } else if (value == 'delete') {
            _showDeleteConfirmation(context, conversation, reseller['name']);
          }
        },
      );
    } else {
      // Mobile/Tablet: Use IconButton that shows a bottom sheet
      return IconButton(
        icon: Icon(
          Icons.more_vert,
          color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
          size: 20,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: l10n.commonMore,
        onPressed: () => _showBottomSheetMenu(context, reseller, conversation),
      );
    }
  }

  // Show a bottom sheet menu for actions on mobile
  void _showBottomSheetMenu(
    BuildContext context,
    Map<String, dynamic> reseller,
    ChatConversation? conversation,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                // This will handle taps on the empty area to dismiss
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),

                // The actual bottom sheet content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    // Prevent taps on the sheet from dismissing
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with reseller name
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              reseller['name'],
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Divider(
                            height: 1,
                            color: Colors.grey.withOpacity(0.3),
                          ),

                          // Clear conversation option (formerly "Atualizar")
                          ListTile(
                            leading: Icon(
                              Icons.cleaning_services_outlined,
                              color: Colors.blue,
                            ),
                            title: Text(
                              'Clear Conversation', // New label
                              style: TextStyle(color: Colors.black87),
                            ),
                            subtitle: Text(
                              'Remove all messages',
                              style: TextStyle(color: Colors.black54),
                            ),
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pop(); // Close the modal first
                              _showClearConfirmation(
                                context,
                                conversation,
                                reseller['name'],
                              );
                            },
                          ),

                          // Delete option
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              'Delete Conversation',
                              style: TextStyle(color: Colors.black87),
                            ),
                            subtitle: Text(
                              'Permanently delete this conversation',
                              style: TextStyle(color: Colors.black54),
                            ),
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pop(); // Close the modal first
                              _showDeleteConfirmation(
                                context,
                                conversation,
                                reseller['name'],
                              );
                            },
                          ),

                          // Cancel button - iOS style
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),

                          // Padding for bottom safe area
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Slide animation from bottom
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  // Update the confirmation dialogs to match the style
  void _showClearConfirmation(
    BuildContext context,
    ChatConversation? conversation,
    String resellerName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Clear Conversation',
              style: TextStyle(color: Colors.black87),
            ),
            content: Text(
              'Are you sure you want to clear all messages with $resellerName?',
              style: const TextStyle(color: Colors.black54),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.blue),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetConversation(context, conversation?.id, resellerName);
                },
              ),
            ],
          ),
    );
  }

  // Update the delete confirmation dialog
  void _showDeleteConfirmation(
    BuildContext context,
    ChatConversation? conversation,
    String resellerName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Delete Conversation',
              style: TextStyle(color: Colors.black87),
            ),
            content: Text(
              'Are you sure you want to permanently delete your conversation with $resellerName?',
              style: const TextStyle(color: Colors.black54),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteConversation(context, conversation?.id, resellerName);
                },
              ),
            ],
          ),
    );
  }

  // Call the repository to reset the conversation
  Future<void> _resetConversation(
    BuildContext context,
    String? conversationId,
    String resellerName,
  ) async {
    if (conversationId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Conversation ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('Calling repository.resetConversation()');
      }

      // Get the repository and call reset
      final repository = ChatRepository();
      await repository.resetConversation(conversationId);

      if (kDebugMode) {
        print('Repository call completed successfully');
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with $resellerName has been reset'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh conversations
        if (context is ConsumerState) {
          final ConsumerState consumerState = context as ConsumerState;
          consumerState.ref.invalidate(conversationsProvider);
        }
      }

      if (kDebugMode) {
        print('Reset operation complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting conversation: $e');
      }

      // Show error message if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Call the Firebase function to delete the conversation
  Future<void> _deleteConversation(
    BuildContext context,
    String? conversationId,
    String resellerName,
  ) async {
    if (conversationId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Conversation ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('Calling Firebase Function deleteConversation');
      }

      // Call the Firebase Function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('deleteConversation');
      final result = await callable.call({'conversationId': conversationId});

      if (kDebugMode) {
        print('Function call completed successfully: ${result.data}');
      }

      // Show success message if context is still valid
      if (context.mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with $resellerName deleted'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh conversations by invalidating the provider
        ref.invalidate(conversationsProvider);
      }

      if (kDebugMode) {
        print('Delete operation complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting conversation: $e');
      }

      // Show error message if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Open existing chat or create a new one
  Future<void> _openOrCreateChat(
    BuildContext context,
    Map<String, dynamic> reseller,
  ) async {
    if (kDebugMode) {
      print(
        'Opening or creating chat for reseller: ${reseller['name']} (${reseller['id']})',
      );
    }

    try {
      // Find existing conversation for this reseller
      String conversationId = '';
      bool isNewConversation = false;

      // Query for conversations with this reseller
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('resellerId', isEqualTo: reseller['id'])
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        // Use existing conversation
        conversationId = snapshot.docs.first.id;

        if (kDebugMode) {
          print('Found existing conversation: $conversationId');
        }

        final conversationData =
            snapshot.docs.first.data() as Map<String, dynamic>;
        final bool isInactive = !(conversationData['active'] ?? false);

        // Always ensure admin is in activeUsers
        List<dynamic> activeUsers = List<dynamic>.from(
          conversationData['activeUsers'] ?? ['admin', reseller['id']],
        );
        if (!activeUsers.contains('admin')) {
          activeUsers.add('admin');
        }

        // If conversation is inactive, DO NOT mark it as active yet
        // Just update activeUsers to include admin
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .update({'activeUsers': activeUsers});

        if (kDebugMode) {
          print(
            'Updated activeUsers for conversation: $conversationId, active status remains: ${!isInactive}',
          );
        }
      } else {
        // Create a new conversation - keep it inactive until a message is sent
        isNewConversation = true;

        if (kDebugMode) {
          print('Creating new conversation for reseller: ${reseller['name']}');
        }

        final conversationData = {
          'resellerId': reseller['id'],
          'resellerName': reseller['name'],
          'lastMessageContent': null, // No message content initially
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageIsFromAdmin': null,
          'active': false, // Start as inactive
          'unreadByAdmin': false,
          'unreadByReseller': false,
          'unreadCount': 0,
          'unreadCounts': {},
          'createdAt': FieldValue.serverTimestamp(),
          'participants': ['admin', reseller['id']],
          'activeUsers': ['admin', reseller['id']],
        };

        final docRef = await FirebaseFirestore.instance
            .collection('conversations')
            .add(conversationData);

        conversationId = docRef.id;

        if (kDebugMode) {
          print('Created new conversation with ID: $conversationId');
        }
      }

      // Only send a welcome message for truly new conversations (not for reactivated ones)
      if (isNewConversation) {
        // Get admin's name
        String adminName = "Support";
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();
            if (userDoc.exists) {
              adminName = userDoc.data()?['displayName'] ?? "Support";
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error getting admin name: $e');
          }
          // Continue with default name
        }

        // Add the welcome message
        try {
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .add({
                'content': 'Hello! How can I help you today?',
                'timestamp': FieldValue.serverTimestamp(),
                'isAdmin': true,
                'isRead': false,
                'senderId': 'admin',
                'senderName': adminName,
                'type': 'text',
                'isDefault': false, // Not a default welcome message
              });

          // Now mark conversation as active since we added a real message
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .update({
                'active': true,
                'lastMessageContent': 'Hello! How can I help you today?',
                'lastMessageTime': FieldValue.serverTimestamp(),
                'lastMessageIsFromAdmin': true,
                'unreadByReseller': true,
                'unreadCounts': {reseller['id']: 1},
                'unreadCount': 1,
              });

          if (kDebugMode) {
            print('Added welcome message to conversation: $conversationId');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error adding welcome message: $e');
          }
          // Continue even if welcome message fails
        }
      }

      // Navigate to the chat page if context is still mounted
      if (context.mounted) {
        if (kDebugMode) {
          print('Navigating to chat page for conversation: $conversationId');
        }

        // Navigate to the chat page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatPage(
                  conversationId: conversationId,
                  title: reseller['name'] ?? 'Chat',
                  isAdminView: true,
                  showAppBar: true,
                ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _openOrCreateChat: $e');
      }

      // Show error message if context is still valid
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Show dialog to select a reseller to start a new conversation
  void _showStartNewChatDialog(BuildContext context, WidgetRef ref) {
    // Watch conversations and resellers
    final conversationsStream = ref.watch(conversationsProvider);
    final resellersStream = ref.watch(resellersProvider);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start New Conversation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                resellersStream.when(
                  data: (resellers) {
                    return conversationsStream.when(
                      data: (conversations) {
                        // Get all active conversations by reseller ID
                        final activeConversationsByResellerId = {
                          for (var conv in conversations.where(
                            (c) => c.active ?? false,
                          ))
                            conv.resellerId: conv,
                        };

                        // Filter resellers that don't have an active conversation
                        final resellersWithoutActiveConversation =
                            resellers
                                .where(
                                  (reseller) =>
                                      !activeConversationsByResellerId
                                          .containsKey(reseller['id']),
                                )
                                .toList();

                        if (resellersWithoutActiveConversation.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              'All resellers already have active conversations.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount:
                                resellersWithoutActiveConversation.length,
                            itemBuilder: (context, index) {
                              final reseller =
                                  resellersWithoutActiveConversation[index];
                              return ListTile(
                                title: Text(
                                  reseller['name'] ?? 'Unknown',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  reseller['email'] ?? '',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary,
                                  child: Text(
                                    (reseller['name'] as String? ?? 'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _openOrCreateChat(context, reseller);
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error:
                          (_, __) => Text(
                            'Error loading conversations',
                            style: TextStyle(color: Colors.red),
                          ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error:
                      (_, __) => Text(
                        'Error loading resellers',
                        style: TextStyle(color: Colors.red),
                      ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationsContent(
    List<ChatConversation> conversations,
    List<Map<String, dynamic>> resellers,
    Map<String, ChatConversation> conversationsByResellerId,
    AppLocalizations l10n,
    ThemeData theme,
    bool showOnlyActive,
  ) {
    // Conversation content
    if (conversations.isNotEmpty) {
      return NoScrollbarBehavior.noScrollbars(
        context,
        ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: resellers.length,
          itemBuilder: (context, index) {
            final reseller = resellers[index];
            // Get the conversation for this reseller
            final conversation = conversationsByResellerId[reseller['id']];
            return _buildResellerItem(context, reseller, conversation);
          },
        ),
      );
    } else {
      // Empty state for no conversations
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? CupertinoIcons.search
                    : showOnlyActive
                    ? CupertinoIcons.chat_bubble_2
                    : CupertinoIcons.square_stack_3d_down_right,
                size: 42,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? "No results found"
                  : showOnlyActive
                  ? "No active conversations"
                  : "No inactive conversations",
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              child: Text(
                _searchQuery.isNotEmpty
                    ? l10n.clientsEmptyStateMessage
                    : showOnlyActive
                    ? "Try viewing inactive conversations or start a new one"
                    : "No inactive conversations found",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isNotEmpty)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: theme.colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                child: Text(
                  l10n.commonClear,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  _searchController.clear();
                },
              )
            else
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.plus,
                      color: theme.colorScheme.onPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Start Conversation",
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                onPressed: () => _showStartNewChatDialog(context, ref),
              ),
          ],
        ),
      );
    }
  }
}
