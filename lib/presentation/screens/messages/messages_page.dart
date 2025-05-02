import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart'
    hide isAdminProvider; // Hide isAdminProvider from chat_provider
import '../../../features/chat/presentation/pages/chat_page.dart';
import '../../../features/chat/presentation/pages/admin_chat_page.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

// Revert MessagesPage to a simpler ConsumerWidget that routes based on role
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key}); // Use super parameter

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      isAdminProvider,
    ); // Get the boolean value directly

    // Display different UI based on user role using a simple if/else
    if (isAdmin) {
      // For admin users - show the dedicated AdminChatPage
      return const AdminChatPage();
    } else {
      // For reseller users - show the direct chat view
      return const _ResellerChatView(); // Use the existing reseller view
    }
  }
}

// Direct chat view for resellers (keep this part)
class _ResellerChatView extends ConsumerWidget {
  const _ResellerChatView({Key? key})
    : super(key: key); // Keep key here for now

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(resellerConversationProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: conversationAsync.when(
          data: (conversationId) {
            return ChatPage(
              conversationId: conversationId,
              showAppBar: false,
              isAdminView: false,
            );
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
                        // color: AppTheme.foreground.withOpacity(0.7),
                        color: AppTheme.foreground.withAlpha(
                          (255 * 0.7).round(),
                        ), // Fix deprecated use
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
