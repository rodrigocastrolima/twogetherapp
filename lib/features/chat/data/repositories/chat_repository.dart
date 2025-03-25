import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_conversation.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  // Collection names
  static const String _conversationsCollection = 'conversations';
  static const String _messagesCollection = 'messages';

  // Safety constraints
  static const int _maxMessageLength = 1000; // Maximum characters per message
  static const int _maxImageSizeMB = 5; // Maximum image size in MB
  static const int _messageRateLimitPerMinute =
      30; // Maximum messages per minute

  // Rate limiting
  final Map<String, List<DateTime>> _messageSendTimes = {};

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (currentUserId == null) return false;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final roleData = userData['role'];
      final String roleString = roleData is String ? roleData : 'unknown';
      final normalizedRole = roleString.trim().toLowerCase();

      return normalizedRole == 'admin';
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if user is admin: $e');
      }
      return false;
    }
  }

  // Get current user's name
  Future<String> getCurrentUserName() async {
    if (currentUserId == null) return 'Unknown User';

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return 'Unknown User';

      final userData = userDoc.data()!;
      return userData['displayName'] ?? userData['email'] ?? 'Unknown User';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user name: $e');
      }
      return 'Unknown User';
    }
  }

  // Get or create a conversation for a reseller
  Future<String> getOrCreateConversation() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this user already has a conversation
      print('Checking for existing conversation for user: $currentUserId');
      final querySnapshot =
          await _firestore
              .collection(_conversationsCollection)
              .where('resellerId', isEqualTo: currentUserId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('Found existing conversation: ${querySnapshot.docs.first.id}');
        return querySnapshot.docs.first.id;
      }

      // Create a new conversation
      print('Creating new conversation for user: $currentUserId');
      final userName = await getCurrentUserName();

      final newConversationData = {
        'resellerId': currentUserId!,
        'resellerName': userName,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hasUnreadMessages': false,
        'unreadCount': 0,
      };

      final docRef = await _firestore
          .collection(_conversationsCollection)
          .add(newConversationData);

      print('Created new conversation with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error in getOrCreateConversation: $e');
      rethrow;
    }
  }

  // Get all conversations (for admin)
  Stream<List<ChatConversation>> getConversations() {
    return _firestore
        .collection(_conversationsCollection)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatConversation.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get messages for a conversation
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatMessage.fromFirestore(doc))
                  .toList(),
        );
  }

  // Send a text message
  Future<void> sendTextMessage(String conversationId, String content) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Enforce message size limit
    if (content.length > _maxMessageLength) {
      throw Exception(
        'Message exceeds maximum length of $_maxMessageLength characters',
      );
    }

    // Apply rate limiting
    if (!_checkRateLimit(currentUserId!)) {
      throw Exception(
        'Too many messages sent in a short period. Please wait a moment.',
      );
    }

    final isAdmin = await isCurrentUserAdmin();
    final userName = await getCurrentUserName();

    // Create the message
    final message = ChatMessage(
      id: '', // Will be set by Firestore
      senderId: currentUserId!,
      senderName: userName,
      content: content,
      timestamp: DateTime.now(), // Will be overwritten by server timestamp
      isAdmin: isAdmin,
    );

    // Record this message send time for rate limiting
    _recordMessageSend(currentUserId!);

    // Add to messages subcollection
    await _firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .add(message.toMap());

    // Update conversation with last message info
    await _firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .update({
          'lastMessageContent': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'hasUnreadMessages':
              !isAdmin, // Mark as unread for admin if sent by reseller
          'unreadCount': FieldValue.increment(isAdmin ? 0 : 1),
        });
  }

  // Send an image message
  Future<void> sendImageMessage(String conversationId, File imageFile) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check file size (1MB = 1024*1024 bytes)
    final fileSize = await imageFile.length();
    if (fileSize > _maxImageSizeMB * 1024 * 1024) {
      throw Exception('Image size exceeds maximum of $_maxImageSizeMB MB');
    }

    // Apply rate limiting
    if (!_checkRateLimit(currentUserId!)) {
      throw Exception(
        'Too many messages sent in a short period. Please wait a moment.',
      );
    }

    try {
      // Upload image to Firebase Storage
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUserId!}';
      final storageRef = _storage.ref().child('chat_images/$fileName');

      // Upload the file
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;

      // Get download URL
      final imageUrl = await snapshot.ref.getDownloadURL();

      final isAdmin = await isCurrentUserAdmin();
      final userName = await getCurrentUserName();

      // Create the message
      final message = ChatMessage(
        id: '', // Will be set by Firestore
        senderId: currentUserId!,
        senderName: userName,
        content: imageUrl,
        timestamp: DateTime.now(), // Will be overwritten by server timestamp
        isAdmin: isAdmin,
        type: MessageType.image,
      );

      // Record this message send time for rate limiting
      _recordMessageSend(currentUserId!);

      // Add to messages subcollection
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .add(message.toMap());

      // Update conversation with last message info
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update({
            'lastMessageContent': 'Image',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'hasUnreadMessages':
                !isAdmin, // Mark as unread for admin if sent by reseller
            'unreadCount': FieldValue.increment(isAdmin ? 0 : 1),
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error sending image message: $e');
      }
      throw Exception('Failed to send image: $e');
    }
  }

  // Helper method for rate limiting
  bool _checkRateLimit(String userId) {
    final now = DateTime.now();

    // Initialize if this is the first message from this user
    if (!_messageSendTimes.containsKey(userId)) {
      _messageSendTimes[userId] = [];
      return true;
    }

    // Remove timestamps older than 1 minute
    _messageSendTimes[userId]!.removeWhere(
      (timestamp) => now.difference(timestamp).inMinutes >= 1,
    );

    // Check if user has exceeded the rate limit
    return _messageSendTimes[userId]!.length < _messageRateLimitPerMinute;
  }

  // Record message send time for rate limiting
  void _recordMessageSend(String userId) {
    if (!_messageSendTimes.containsKey(userId)) {
      _messageSendTimes[userId] = [];
    }

    _messageSendTimes[userId]!.add(DateTime.now());
  }

  // Mark messages as read
  Future<void> markConversationAsRead(String conversationId) async {
    final isAdmin = await isCurrentUserAdmin();

    // Only admins mark conversations as read
    if (isAdmin) {
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update({'hasUnreadMessages': false, 'unreadCount': 0});
    }
  }
}
