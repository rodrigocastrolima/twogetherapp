import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/chat/presentation/pages/chat_page.dart';
import '../../../features/chat/presentation/pages/admin_chat_page.dart';

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

    // Display different UI based on user role
    return isAdminAsync.when(
      data: (isAdmin) {
        if (isAdmin) {
          // For admin users - show list of all conversations
          return const AdminChatPage();
        } else {
          // For reseller users - direct chat with support
          return _ResellerChatView();
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: ${error.toString()}')),
    );
  }
}

// Direct chat view for resellers
class _ResellerChatView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(resellerConversationProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: true,
        top: false,
        child: conversationAsync.when(
          data: (conversationId) {
            return ChatPage(conversationId: conversationId, showAppBar: false);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load chat',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.foreground.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.refresh(resellerConversationProvider);
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
