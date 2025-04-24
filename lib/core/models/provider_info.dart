import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderInfo {
  final String id;
  final String name;
  final String imageUrl;
  final String storagePath; // Path to the image in Firebase Storage
  final DateTime createdAt;

  ProviderInfo({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.storagePath,
    required this.createdAt,
  });

  // Factory constructor to create a ProviderInfo from a Firestore document
  factory ProviderInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderInfo(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Provider',
      imageUrl: data['imageUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Method to convert ProviderInfo instance to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'createdAt': Timestamp.fromDate(createdAt),
      // id is not stored as a field, it's the document ID
    };
  }

  // Optional: copyWith method for easier updates
  ProviderInfo copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? storagePath,
    DateTime? createdAt,
  }) {
    return ProviderInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
