import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderInfo {
  final String id;
  final String name;
  final String imageUrl;
  final String storagePath; // Storage path for the image
  final Timestamp createdAt;

  ProviderInfo({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.storagePath,
    required this.createdAt,
  });

  // Factory constructor to create a ProviderInfo from a Firestore DocumentSnapshot
  factory ProviderInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderInfo(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(), // Provide default
    );
  }

  // Method to convert a ProviderInfo instance to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'createdAt': createdAt,
      // id is not stored as a field in the document itself
    };
  }

  // CopyWith method for immutability
  ProviderInfo copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? storagePath,
    Timestamp? createdAt,
  }) {
    return ProviderInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          imageUrl == other.imageUrl &&
          storagePath == other.storagePath &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      imageUrl.hashCode ^
      storagePath.hashCode ^
      createdAt.hashCode;
}
