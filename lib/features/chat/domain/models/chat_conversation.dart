import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String id;
  final String resellerId;
  final String resellerName;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final bool hasUnreadMessages;
  final int unreadCount;

  const ChatConversation({
    required this.id,
    required this.resellerId,
    required this.resellerName,
    this.lastMessageContent,
    this.lastMessageTime,
    this.hasUnreadMessages = false,
    this.unreadCount = 0,
  });

  // Create from Firestore document
  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatConversation(
      id: doc.id,
      resellerId: data['resellerId'] ?? '',
      resellerName: data['resellerName'] ?? '',
      lastMessageContent: data['lastMessageContent'],
      lastMessageTime:
          data['lastMessageTime'] != null
              ? (data['lastMessageTime'] as Timestamp).toDate()
              : null,
      hasUnreadMessages: data['hasUnreadMessages'] ?? false,
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'resellerId': resellerId,
      'resellerName': resellerName,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime':
          lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'hasUnreadMessages': hasUnreadMessages,
      'unreadCount': unreadCount,
    };
  }

  // Create a copy with updated fields
  ChatConversation copyWith({
    String? id,
    String? resellerId,
    String? resellerName,
    String? lastMessageContent,
    DateTime? lastMessageTime,
    bool? hasUnreadMessages,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      resellerId: resellerId ?? this.resellerId,
      resellerName: resellerName ?? this.resellerName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
