import 'package:flutter/foundation.dart';

/// Parameters required to create a Salesforce Opportunity via Cloud Function.
@immutable
class CreateOppParams {
  final String submissionId;
  final String accessToken;
  final String instanceUrl;
  final String resellerSalesforceId;
  final String opportunityName;
  final String nif;
  final String companyName;
  final String segment;
  final String solution;
  final String closeDate; // <-- Changed to String
  final String opportunityType;
  final String phase;
  final List<String>? fileUrls; // Optional

  const CreateOppParams({
    required this.submissionId,
    required this.accessToken,
    required this.instanceUrl,
    required this.resellerSalesforceId,
    required this.opportunityName,
    required this.nif,
    required this.companyName,
    required this.segment,
    required this.solution,
    required this.closeDate, // <-- Expecting String
    required this.opportunityType,
    required this.phase,
    this.fileUrls,
  });

  // Convert to Map for sending to Cloud Function
  Map<String, dynamic> toJson() => {
    'submissionId': submissionId,
    'accessToken': accessToken,
    'instanceUrl': instanceUrl,
    'resellerSalesforceId': resellerSalesforceId,
    'opportunityName': opportunityName,
    'nif': nif,
    'companyName': companyName,
    'segment': segment,
    'solution': solution,
    'closeDate': closeDate, // <-- Pass string directly
    'opportunityType': opportunityType,
    'phase': phase,
    'fileUrls': fileUrls, // Pass list directly (or null)
  };

  // Optional: Add equality and hashCode for use in providers
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateOppParams &&
          runtimeType == other.runtimeType &&
          submissionId == other.submissionId &&
          accessToken == other.accessToken &&
          instanceUrl == other.instanceUrl &&
          resellerSalesforceId == other.resellerSalesforceId &&
          opportunityName == other.opportunityName &&
          nif == other.nif &&
          companyName == other.companyName &&
          segment == other.segment &&
          solution == other.solution &&
          closeDate == other.closeDate && // <-- Compare as String
          opportunityType == other.opportunityType &&
          phase == other.phase &&
          listEquals(fileUrls, other.fileUrls);

  @override
  int get hashCode =>
      submissionId.hashCode ^
      accessToken.hashCode ^
      instanceUrl.hashCode ^
      resellerSalesforceId.hashCode ^
      opportunityName.hashCode ^
      nif.hashCode ^
      companyName.hashCode ^
      segment.hashCode ^
      solution.hashCode ^
      closeDate.hashCode ^ // <-- Hash as String
      opportunityType.hashCode ^
      phase.hashCode ^
      fileUrls.hashCode;
}

/// Result received from the createSalesforceOpportunity Cloud Function.
@immutable
class CreateOppResult {
  final bool success;
  final String? opportunityId;
  final String? error;
  final bool sessionExpired;

  const CreateOppResult({
    required this.success,
    this.opportunityId,
    this.error,
    this.sessionExpired = false,
  });

  factory CreateOppResult.fromJson(Map<String, dynamic> json) {
    // Safely access the sessionExpired field from details if present
    bool expired = false;
    if (json['details'] is Map<String, dynamic>) {
      expired =
          (json['details'] as Map<String, dynamic>)['sessionExpired'] == true;
    } else {
      // Fallback check directly on the root (if function returns it there)
      expired = json['sessionExpired'] == true;
    }

    return CreateOppResult(
      success: json['success'] as bool? ?? false, // Provide default
      opportunityId: json['opportunityId'] as String?,
      error: json['error'] as String?,
      sessionExpired: expired, // Use extracted value
    );
  }
}
