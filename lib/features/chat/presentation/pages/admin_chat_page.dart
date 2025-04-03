import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/theme/colors.dart';
import '../../domain/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/chat_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    // Watch both conversations and resellers
    final conversationsStream = ref.watch(conversationsProvider);
    final resellersStream = ref.watch(resellersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chat with Resellers',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        // Add actions for the filter toggle
        actions: [
          // Filter toggle button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                _showOnlyActive ? Icons.filter_list : Icons.filter_list_off,
                color: _showOnlyActive ? Colors.amber : Colors.white70,
              ),
              onPressed: _toggleActiveFilter,
              tooltip:
                  _showOnlyActive
                      ? 'Showing active conversations only'
                      : 'Showing all conversations',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            color: AppColors.whiteAlpha50,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No resellers found',
                            style: AppTextStyles.body1.copyWith(
                              color: AppColors.whiteAlpha70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return conversationsStream.when(
                    data: (conversations) {
                      // Get all conversations or filter active ones based on state
                      final List<ChatConversation> filteredConversations =
                          _showOnlyActive
                              ? conversations
                                  .where((c) => c.active ?? false)
                                  .toList()
                              : conversations;

                      // Display a message if there are no conversations to show
                      if (filteredConversations.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showOnlyActive
                                    ? CupertinoIcons.chat_bubble_2
                                    : CupertinoIcons.square_stack_3d_down_right,
                                size: 48,
                                color: AppColors.whiteAlpha50,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _showOnlyActive
                                    ? 'No active conversations found'
                                    : 'No conversations found',
                                style: AppTextStyles.body1.copyWith(
                                  color: AppColors.whiteAlpha70,
                                ),
                              ),
                              if (_showOnlyActive) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showOnlyActive = false;
                                    });
                                  },
                                  child: Text(
                                    'Show all conversations',
                                    style: TextStyle(color: Colors.amber),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      // Sort conversations by newest message first, putting active ones at the top
                      filteredConversations.sort((a, b) {
                        // First sort by active status
                        if ((a.active ?? false) != (b.active ?? false)) {
                          return (a.active ?? false)
                              ? -1
                              : 1; // Active conversations first
                        }
                        // Then sort by time
                        if (a.lastMessageTime == null &&
                            b.lastMessageTime == null) {
                          return 0;
                        } else if (a.lastMessageTime == null) {
                          return 1;
                        } else if (b.lastMessageTime == null) {
                          return -1;
                        }
                        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
                      });

                      // Create a map of all filtered conversations by reseller ID
                      final conversationsByResellerId = {
                        for (var conversation in filteredConversations)
                          conversation.resellerId: conversation,
                      };

                      // Get all resellers that have any conversation (active or inactive)
                      final resellersWithConversations =
                          resellers
                              .where(
                                (reseller) => conversationsByResellerId
                                    .containsKey(reseller['id']),
                              )
                              .toList();

                      return Column(
                        children: [
                          // Filter indicator - make it tappable to toggle
                          GestureDetector(
                            onTap: _toggleActiveFilter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _showOnlyActive
                                        ? Colors.amber.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _showOnlyActive
                                          ? Colors.amber.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showOnlyActive
                                        ? Icons.filter_alt
                                        : Icons.filter_alt_off,
                                    size: 14,
                                    color:
                                        _showOnlyActive
                                            ? Colors.amber
                                            : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showOnlyActive
                                        ? 'Active only (${filteredConversations.length})'
                                        : 'All conversations (${filteredConversations.length})',
                                    style: TextStyle(
                                      color:
                                          _showOnlyActive
                                              ? Colors.amber
                                              : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Main list
                          Expanded(
                            child: NoScrollbarBehavior.noScrollbars(
                              context,
                              ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: resellersWithConversations.length,
                                itemBuilder: (context, index) {
                                  final reseller =
                                      resellersWithConversations[index];
                                  // Get the conversation for this reseller
                                  final conversation =
                                      conversationsByResellerId[reseller['id']];

                                  return _buildResellerItem(
                                    context,
                                    reseller,
                                    conversation,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading:
                        () => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
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
                                  color: Colors.amber,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading conversations',
                                  style: AppTextStyles.body1.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  error.toString(),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body2.copyWith(
                                    color: AppColors.whiteAlpha70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  );
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
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
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading resellers',
                              style: AppTextStyles.body1.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.whiteAlpha70,
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
    // Format time if conversation exists and has a last message
    final formattedTime =
        conversation?.lastMessageTime != null
            ? DateFormat('dd/MM • HH:mm').format(conversation!.lastMessageTime!)
            : 'No messages yet';

    // Check if there are unread messages for admin
    final hasUnreadMessages =
        conversation != null && conversation.unreadByAdmin;
    final unreadCount = conversation?.unreadCount ?? 0;

    // Check if conversation is inactive (only has welcome message)
    final bool isInactive =
        conversation != null && !(conversation.active ?? false);

    // Determine message content to display - show appropriate text if no messages
    final String messageContent =
        conversation?.lastMessageContent ?? 'Start a conversation';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AppStyles.glassCardWithHighlight(
        isHighlighted: hasUnreadMessages,
        context: context,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to chat with this reseller
                _openOrCreateChat(context, reseller);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            hasUnreadMessages
                                ? AppColors.amber.withAlpha(38)
                                : isInactive
                                ? Colors.grey.withAlpha(38)
                                : AppTheme.primary.withAlpha(38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              hasUnreadMessages
                                  ? AppColors.amber.withAlpha(77)
                                  : isInactive
                                  ? Colors.grey.withAlpha(77)
                                  : AppTheme.primary.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isInactive
                              ? CupertinoIcons.person
                              : CupertinoIcons.person_solid,
                          size: 24,
                          color:
                              hasUnreadMessages
                                  ? AppColors.amber
                                  : isInactive
                                  ? Colors.grey
                                  : AppColors.whiteAlpha90,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

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
                                  style: AppTextStyles.body1.copyWith(
                                    fontWeight:
                                        hasUnreadMessages
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                    color:
                                        hasUnreadMessages
                                            ? Colors.white
                                            : isInactive
                                            ? AppColors.whiteAlpha70
                                            : AppColors.whiteAlpha90,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: AppTextStyles.caption.copyWith(
                                  color:
                                      hasUnreadMessages
                                          ? AppColors.amber
                                          : isInactive
                                          ? AppColors.whiteAlpha30
                                          : AppColors.whiteAlpha50,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  messageContent,
                                  style: AppTextStyles.body2.copyWith(
                                    color:
                                        hasUnreadMessages
                                            ? AppColors.whiteAlpha90
                                            : isInactive
                                            ? AppColors.whiteAlpha50
                                            : AppColors.whiteAlpha70,
                                    fontWeight:
                                        hasUnreadMessages
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                    fontStyle:
                                        isInactive
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasUnreadMessages) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (isInactive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'New',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
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
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onPressed:
                          () =>
                              _showActionsMenu(context, reseller, conversation),
                      tooltip: 'More actions',
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

  // Show a popup menu with actions for the conversation
  void _showActionsMenu(
    BuildContext context,
    Map<String, dynamic> reseller,
    ChatConversation? conversation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Divider(height: 1, color: Colors.grey),

                // Reset conversation option
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.amber),
                  title: const Text(
                    'Reset Conversation',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Clears all messages but keeps the conversation',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the modal first
                    _showResetConfirmation(
                      context,
                      conversation,
                      reseller['name'],
                    );
                  },
                ),

                // Delete option
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Conversation',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Permanently removes all messages',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the modal first
                    _showDeleteConfirmation(
                      context,
                      conversation,
                      reseller['name'],
                    );
                  },
                ),

                // Cancel button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                // Padding for bottom safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
    );
  }

  // Show confirmation dialog before resetting a conversation
  void _showResetConfirmation(
    BuildContext context,
    ChatConversation? conversation,
    String resellerName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Reset Conversation?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'This will clear all messages with $resellerName but keep the conversation. '
              'The conversation will become inactive until new messages are sent.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.amber),
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
            content: Text('Error resetting conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show confirmation dialog before deleting
  void _showDeleteConfirmation(
    BuildContext context,
    ChatConversation? conversation,
    String resellerName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Delete Conversation?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'This will permanently delete all messages with $resellerName. This action cannot be undone.',
              style: const TextStyle(color: Colors.white70),
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
            content: Text('Error deleting conversation: ${e.toString()}'),
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
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  // Add a method to toggle the filter
  void _toggleActiveFilter() {
    setState(() {
      _showOnlyActive = !_showOnlyActive;
    });
  }
}
