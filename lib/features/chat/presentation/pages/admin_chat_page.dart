import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/theme/colors.dart';
import '../../domain/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';

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

class AdminChatPage extends ConsumerWidget {
  const AdminChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      // Create a map of existing conversations by reseller ID
                      final conversationsByResellerId = {
                        for (var conversation in conversations)
                          conversation.resellerId: conversation,
                      };

                      return NoScrollbarBehavior.noScrollbars(
                        context,
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: resellers.length,
                          itemBuilder: (context, index) {
                            final reseller = resellers[index];
                            // Check if a conversation exists for this reseller
                            final conversation =
                                conversationsByResellerId[reseller['id']];

                            return _buildResellerItem(
                              context,
                              reseller,
                              conversation,
                            );
                          },
                        ),
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
                                : AppTheme.primary.withAlpha(38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              hasUnreadMessages
                                  ? AppColors.amber.withAlpha(77)
                                  : AppTheme.primary.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.person_solid,
                          size: 24,
                          color:
                              hasUnreadMessages
                                  ? AppColors.amber
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
                                            : AppColors.whiteAlpha70,
                                    fontWeight:
                                        hasUnreadMessages
                                            ? FontWeight.w500
                                            : FontWeight.normal,
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
                            ],
                          ),
                        ],
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

  // Open existing chat or create a new one
  void _openOrCreateChat(
    BuildContext context,
    Map<String, dynamic> reseller,
  ) async {
    bool dialogShown = false;
    try {
      // Show loading indicator
      dialogShown = true;
      // Instead of awaiting the dialog, we'll show it and remember the context
      // This pattern allows us to dismiss it later
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
        );
      }

      // Check if a conversation already exists for this reseller
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('resellerId', isEqualTo: reseller['id'])
              .limit(1)
              .get();

      String conversationId;

      if (querySnapshot.docs.isNotEmpty) {
        // Use existing conversation
        conversationId = querySnapshot.docs.first.id;
      } else {
        // Create a new conversation
        final conversationData = {
          'resellerId': reseller['id'],
          'resellerName': reseller['name'],
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadByAdmin': false,
          'unreadByReseller': false,
          'unreadCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRef = await FirebaseFirestore.instance
            .collection('conversations')
            .add(conversationData);

        conversationId = docRef.id;
      }

      // Close the loading dialog if it's still showing
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      // Navigate to the chat page if context is still mounted
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatPage(
                  conversationId: conversationId,
                  title: reseller['name'],
                ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's still showing and context is mounted
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.destructive.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
