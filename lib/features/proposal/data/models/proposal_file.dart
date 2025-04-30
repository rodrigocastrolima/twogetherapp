import 'package:flutter/foundation.dart';

@immutable
class ProposalFile {
  final String id; // ContentDocument ID
  final String title;
  final String fileType;
  final String? fileExtension;
  final String contentVersionId; // LatestPublishedVersionId

  const ProposalFile({
    required this.id,
    required this.title,
    required this.fileType,
    this.fileExtension,
    required this.contentVersionId,
  });

  // Factory to parse from the nested structure within ContentDocumentLink query result
  factory ProposalFile.fromJson(Map<String, dynamic> linkJson) {
    final doc = linkJson['ContentDocument'] as Map<String, dynamic>?;
    return ProposalFile(
      id: doc?['Id'] as String? ?? '',
      title: doc?['Title'] as String? ?? 'Unknown File',
      fileType: doc?['FileType'] as String? ?? '',
      fileExtension: doc?['FileExtension'] as String?,
      contentVersionId: doc?['LatestPublishedVersionId'] as String? ?? '',
    );
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    // Required for comparison if DetailedSalesforceProposal.toJson needs it
    return {
      'id': id,
      'title': title,
      'fileType': fileType,
      'fileExtension': fileExtension,
      'contentVersionId': contentVersionId,
    };
  }

  // --- Placeholder Methods (Implement later if needed) ---

  ProposalFile copyWith({
    String? id,
    String? title,
    String? fileType,
    String? fileExtension,
    String? contentVersionId,
  }) {
    throw UnimplementedError('copyWith has not been implemented.');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProposalFile && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  String toString() {
    return 'ProposalFile(id: $id, title: $title, fileType: $fileType, contentVersionId: $contentVersionId)';
  }
}
