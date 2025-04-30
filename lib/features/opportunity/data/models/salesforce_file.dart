import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

/// Represents a file linked to a Salesforce record.
@immutable
class SalesforceFile extends Equatable {
  final String id;
  final String contentVersionId;
  final String title;
  final String fileType;
  final String downloadUrl; // URL to view/download the file

  const SalesforceFile({
    required this.id,
    required this.contentVersionId,
    required this.title,
    required this.fileType,
    required this.downloadUrl,
  });

  factory SalesforceFile.fromJson(Map<String, dynamic> json) {
    // Basic validation
    if (json['id'] == null ||
        json['title'] == null ||
        json['fileType'] == null ||
        json['downloadUrl'] == null) {
      print(
        "Error parsing SalesforceFile: Missing required fields in JSON: \$json",
      );
      throw const FormatException(
        "Missing required fields in SalesforceFile JSON",
      );
    }

    return SalesforceFile(
      id: json['id'] as String,
      contentVersionId: json['contentVersionId'] as String,
      title: json['title'] as String,
      fileType: json['fileType'] as String,
      downloadUrl: json['downloadUrl'] as String,
    );
  }

  SalesforceFile copyWith({
    String? id,
    String? contentVersionId,
    String? title,
    String? fileType,
    String? downloadUrl,
  }) {
    return SalesforceFile(
      id: id ?? this.id,
      contentVersionId: contentVersionId ?? this.contentVersionId,
      title: title ?? this.title,
      fileType: fileType ?? this.fileType,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentVersionId': contentVersionId,
      'title': title,
      'fileType': fileType,
      'downloadUrl':
          downloadUrl, // Include even if not strictly needed for backend update
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          contentVersionId == other.contentVersionId &&
          title == other.title &&
          fileType == other.fileType &&
          downloadUrl == other.downloadUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      contentVersionId.hashCode ^
      title.hashCode ^
      fileType.hashCode ^
      downloadUrl.hashCode;

  @override
  String toString() {
    return 'SalesforceFile{id: \$id, title: \$title, fileType: \$fileType, downloadUrl: \$downloadUrl}';
  }

  @override
  List<Object?> get props => [
    id,
    contentVersionId,
    title,
    fileType,
    downloadUrl,
  ];
}
