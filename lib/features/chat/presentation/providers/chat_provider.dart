import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_conversation.dart';

// Provider for the ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

// Provider to check if current user is admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.isCurrentUserAdmin();
});

// Provider for the reseller conversation
final resellerConversationProvider = FutureProvider<String>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getOrCreateConversation();
});

// Provider for all conversations (admin view)
final conversationsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversations();
});

// Provider for messages in a conversation
final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(conversationId);
});

// NotifierProvider for chat functionality
class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;

  ChatNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> sendTextMessage(String conversationId, String content) async {
    if (content.trim().isEmpty) return;

    try {
      state = const AsyncValue.loading();
      await _repository.sendTextMessage(conversationId, content);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> sendImageMessage(String conversationId, File imageFile) async {
    try {
      state = const AsyncValue.loading();
      await _repository.sendImageMessage(conversationId, imageFile);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error sending image: $e');
      }
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _repository.markConversationAsRead(conversationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as read: $e');
      }
    }
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
      final repository = ref.watch(chatRepositoryProvider);
      return ChatNotifier(repository);
    });
