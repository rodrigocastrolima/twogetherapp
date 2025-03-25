import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isAdmin;
  final bool isRead;
  final MessageType type;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isAdmin,
    this.isRead = false,
    this.type = MessageType.text,
  });

  // Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isAdmin: data['isAdmin'] ?? false,
      isRead: data['isRead'] ?? false,
      type: data['type'] == 'image' ? MessageType.image : MessageType.text,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isAdmin': isAdmin,
      'isRead': isRead,
      'type': type == MessageType.image ? 'image' : 'text',
    };
  }

  // Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isAdmin,
    bool? isRead,
    MessageType? type,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isAdmin: isAdmin ?? this.isAdmin,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}
