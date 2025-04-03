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
  final bool isDefault;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isAdmin,
    this.isRead = false,
    this.type = MessageType.text,
    this.isDefault = false,
  });

  // Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely handle the timestamp conversion
    DateTime timestamp;
    try {
      timestamp =
          data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();
    } catch (e) {
      // Default to current time if there's any issue with the timestamp
      timestamp = DateTime.now();
    }

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: timestamp,
      isAdmin: data['isAdmin'] ?? false,
      isRead: data['isRead'] ?? false,
      type: data['type'] == 'image' ? MessageType.image : MessageType.text,
      isDefault: data['isDefault'] ?? false,
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
      'isDefault': isDefault,
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
    bool? isDefault,
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
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
