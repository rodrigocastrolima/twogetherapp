import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatConversation {
  final String id;
  final String resellerId;
  final String resellerName;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;

  // New approach: Map-based unread tracking per participant
  final Map<String, int> unreadCounts; // Map of userId -> unread count

  // For backward compatibility, we'll compute these from the map
  bool get unreadByAdmin => (unreadCounts['admin'] ?? 0) > 0;
  bool get unreadByReseller => (unreadCounts[resellerId] ?? 0) > 0;
  int get unreadCount =>
      unreadCounts.values.fold<int>(0, (sum, count) => sum + count);

  const ChatConversation({
    required this.id,
    required this.resellerId,
    required this.resellerName,
    this.lastMessageContent,
    this.lastMessageTime,
    required this.unreadCounts,
  });

  // Create from Firestore document
  factory ChatConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely handle the timestamp conversion with proper null checking
    DateTime? lastMessageTime;
    try {
      if (data['lastMessageTime'] != null) {
        lastMessageTime = (data['lastMessageTime'] as Timestamp).toDate();
      }
    } catch (e) {
      // In case of any conversion error, leave the timestamp as null
      // This catches the case when the server timestamp is still being written
      if (kDebugMode) {
        print('Error converting timestamp: $e');
      }
    }

    // Handle legacy format where unreadCounts may not exist
    Map<String, int> unreadCounts = {};

    // If the new unreadCounts field exists, use it
    if (data['unreadCounts'] != null) {
      final countsData = data['unreadCounts'] as Map<String, dynamic>;
      countsData.forEach((key, value) {
        if (value is int) {
          unreadCounts[key] = value;
        }
      });
    }
    // Otherwise, map from old format for backward compatibility
    else {
      final resellerId = data['resellerId'] ?? '';
      if (data['unreadByAdmin'] == true) {
        unreadCounts['admin'] =
            data['unreadCount'] is int ? data['unreadCount'] : 1;
      }
      if (data['unreadByReseller'] == true) {
        unreadCounts[resellerId] =
            data['unreadCount'] is int ? data['unreadCount'] : 1;
      }
    }

    return ChatConversation(
      id: doc.id,
      resellerId: data['resellerId'] ?? '',
      resellerName: data['resellerName'] ?? '',
      lastMessageContent: data['lastMessageContent'],
      lastMessageTime: lastMessageTime,
      unreadCounts: unreadCounts,
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
      'unreadCounts': unreadCounts,
      // Keep the old fields for backward compatibility
      'unreadByAdmin': unreadByAdmin,
      'unreadByReseller': unreadByReseller,
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
    Map<String, int>? unreadCounts,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      resellerId: resellerId ?? this.resellerId,
      resellerName: resellerName ?? this.resellerName,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? Map<String, int>.from(this.unreadCounts),
    );
  }
}
