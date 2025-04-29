import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderFile {
  final String id;
  final String fileName;
  final String description;
  final String downloadUrl;
  final String fileType; // e.g., 'pdf', 'docx', 'jpg'
  final int? size; // File size in bytes (optional)
  final Timestamp uploadedAt;
  final String storagePath; // Full path in Firebase Storage

  ProviderFile({
    required this.id,
    required this.fileName,
    required this.description,
    required this.downloadUrl,
    required this.fileType,
    this.size,
    required this.uploadedAt,
    required this.storagePath,
  });

  // Factory constructor from Firestore DocumentSnapshot
  factory ProviderFile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderFile(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      description: data['description'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      fileType: data['fileType'] ?? 'unknown',
      size: data['size'], // Can be null
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
      storagePath: data['storagePath'] ?? '',
    );
  }

  // Method to convert to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'description': description,
      'downloadUrl': downloadUrl,
      'fileType': fileType,
      'size': size,
      'uploadedAt': uploadedAt,
      'storagePath': storagePath,
      // id is not stored as a field
    };
  }

  // CopyWith method
  ProviderFile copyWith({
    String? id,
    String? fileName,
    String? description,
    String? downloadUrl,
    String? fileType,
    int? size,
    Timestamp? uploadedAt,
    String? storagePath,
  }) {
    return ProviderFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileType: fileType ?? this.fileType,
      size: size ?? this.size,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fileName == other.fileName &&
          description == other.description &&
          downloadUrl == other.downloadUrl &&
          fileType == other.fileType &&
          size == other.size &&
          uploadedAt == other.uploadedAt &&
          storagePath == other.storagePath;

  @override
  int get hashCode =>
      id.hashCode ^
      fileName.hashCode ^
      description.hashCode ^
      downloadUrl.hashCode ^
      fileType.hashCode ^
      size.hashCode ^
      uploadedAt.hashCode ^
      storagePath.hashCode;
}
