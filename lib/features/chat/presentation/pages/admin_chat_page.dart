import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';

class AdminChatPage extends ConsumerWidget {
  const AdminChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsStream = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Support Conversations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateConversationDialog(context, ref),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: conversationsStream.when(
          data: (conversations) {
            if (conversations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No conversations yet',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                          () => _showCreateConversationDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Start a conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _buildConversationItem(context, conversation);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(child: Text('Error: ${error.toString()}')),
        ),
      ),
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    ChatConversation conversation,
  ) {
    final formattedTime =
        conversation.lastMessageTime != null
            ? DateFormat('dd/MM • HH:mm').format(conversation.lastMessageTime!)
            : 'No messages';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatPage(
                  conversationId: conversation.id,
                  title: conversation.resellerName,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(
            conversation.hasUnreadMessages ? 30 : 15,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(26), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemIndigo.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.person_solid,
                    size: 24,
                    color: CupertinoColors.systemIndigo,
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
                            conversation.resellerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  conversation.hasUnreadMessages
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                              color: AppTheme.foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessageContent ??
                                'Start a conversation',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                              fontWeight:
                                  conversation.hasUnreadMessages
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.hasUnreadMessages) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
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
    );
  }

  // New method to show dialog for creating a new conversation
  void _showCreateConversationDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController userIdController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Start a new conversation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: 'Enter reseller ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'User Name',
                    hintText: 'Enter reseller name',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final userId = userIdController.text.trim();
                  final name = nameController.text.trim();

                  if (userId.isNotEmpty && name.isNotEmpty) {
                    _createNewConversation(userId, name, ref, context);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    ).then((_) {
      userIdController.dispose();
      nameController.dispose();
    });
  }

  // New method to create a conversation
  Future<void> _createNewConversation(
    String userId,
    String name,
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      // Get the repository
      final repository = ref.read(chatRepositoryProvider);

      // Create conversation document
      final conversationData = {
        'resellerId': userId,
        'resellerName': name,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasUnreadMessages': false,
        'unreadCount': 0,
      };

      // Add to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('conversations')
          .add(conversationData);

      // Close dialog
      Navigator.pop(context);

      // Navigate to the conversation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatPage(conversationId: docRef.id, title: name),
        ),
      );
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating conversation: $e')),
      );
      Navigator.pop(context);
    }
  }
}
