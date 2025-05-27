import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_conversation.dart';
import 'package:twogether/features/auth/presentation/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
final conversationsProvider =
    StreamProvider.autoDispose<List<ChatConversation>>((ref) {
      final repository = ref.watch(chatRepositoryProvider);
      return repository.getConversations();
    });

// Provider for messages in a conversation
final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, conversationId) {
      final repository = ref.watch(chatRepositoryProvider);
      return repository.getMessages(conversationId);
    });

// Provider for total unread messages count
final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated || FirebaseAuth.instance.currentUser == null) {
    return Stream.value(0);
  }
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUnreadMessagesCountStream();
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

  Future<void> sendImageMessage(
    String conversationId,
    dynamic imageFile,
  ) async {
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

  Future<void> sendFileMessage(
    String conversationId,
    dynamic file,
    String fileName,
    String fileType,
    int fileSize,
  ) async {
    try {
      state = const AsyncValue.loading();
      await _repository.sendFileMessage(
        conversationId,
        file,
        fileName,
        fileType,
        fileSize,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error sending file: $e');
      }
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      // Check if current user is admin
      final isAdmin = await _repository.isCurrentUserAdmin();
      await _repository.markConversationAsRead(conversationId, isAdmin);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as read: $e');
      }
    }
  }

  Future<void> setUserActiveInConversation(
    String conversationId,
    bool isActive,
  ) async {
    try {
      await _repository.setUserActiveInConversation(conversationId, isActive);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting user active status: $e');
      }
    }
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
      final repository = ref.watch(chatRepositoryProvider);
      return ChatNotifier(repository);
    });
