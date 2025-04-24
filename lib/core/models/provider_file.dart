import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderFile {
  final String id;
  final String fileName;
  final String description;
  final String downloadUrl;
  final String fileType; // e.g., 'pdf', 'docx', 'png'
  final String storagePath; // Full path to the file in Firebase Storage
  final int? size; // File size in bytes (optional)
  final DateTime uploadedAt;

  ProviderFile({
    required this.id,
    required this.fileName,
    required this.description,
    required this.downloadUrl,
    required this.fileType,
    required this.storagePath,
    this.size,
    required this.uploadedAt,
  });

  // Factory constructor from Firestore document
  factory ProviderFile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProviderFile(
      id: doc.id,
      fileName: data['fileName'] ?? 'Unnamed File',
      description: data['description'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      fileType: data['fileType'] ?? '',
      storagePath: data['storagePath'] ?? '',
      size: data['size'] as int?,
      uploadedAt:
          (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Method to convert to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'description': description,
      'downloadUrl': downloadUrl,
      'fileType': fileType,
      'storagePath': storagePath,
      'size': size,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      // id is the document ID
    };
  }

  // Optional: copyWith
  ProviderFile copyWith({
    String? id,
    String? fileName,
    String? description,
    String? downloadUrl,
    String? fileType,
    String? storagePath,
    int? size,
    DateTime? uploadedAt,
  }) {
    return ProviderFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileType: fileType ?? this.fileType,
      storagePath: storagePath ?? this.storagePath,
      size: size ?? this.size,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}
