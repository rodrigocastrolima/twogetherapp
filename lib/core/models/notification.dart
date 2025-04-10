import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum NotificationType {
  statusChange,
  rejection,
  payment,
  system,
  newSubmission,
}

class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> metadata;

  UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.metadata = const {},
  });

  // Create from Firestore document
  factory UserNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse the notification type from string
    NotificationType type;
    try {
      type = NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => NotificationType.system,
      );
    } catch (_) {
      type = NotificationType.system;
    }

    // Parse timestamp
    DateTime createdAt;
    final timestamp = data['createdAt'];
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return UserNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: type,
      createdAt: createdAt,
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'] ?? {},
    );
  }

  // Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    final typeString = type.toString().split('.').last;

    if (kDebugMode) {
      print(
        'Converting notification type to string: ${type.toString()} -> $typeString',
      );
    }

    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': typeString,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  // Create a copy with updated fields
  UserNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}
