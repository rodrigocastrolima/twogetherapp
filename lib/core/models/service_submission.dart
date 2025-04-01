import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_types.dart';

class ServiceSubmission {
  final String? id; // Null when creating, set when stored
  final String resellerId;
  final String resellerName;
  final ServiceCategory serviceCategory;
  final EnergyType? energyType;
  final ClientType clientType;
  final Provider provider;
  final String? companyName; // Only for commercial clients
  final String responsibleName;
  final String nif;
  final String email;
  final String phone;
  final List<String> documentUrls; // URLs of uploaded images
  final DateTime submissionDate;
  final String status; // For tracking submission status

  ServiceSubmission({
    this.id,
    required this.resellerId,
    required this.resellerName,
    required this.serviceCategory,
    this.energyType,
    required this.clientType,
    required this.provider,
    this.companyName,
    required this.responsibleName,
    required this.nif,
    required this.email,
    required this.phone,
    required this.documentUrls,
    DateTime? submissionDate,
    this.status = 'pending', // Default status
  }) : this.submissionDate = submissionDate ?? DateTime.now();

  // Create from Firestore document
  factory ServiceSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ServiceSubmission(
      id: doc.id,
      resellerId: data['resellerId'] ?? '',
      resellerName: data['resellerName'] ?? '',
      serviceCategory: ServiceCategory.values.byName(data['serviceCategory']),
      energyType:
          data['energyType'] != null
              ? EnergyType.values.byName(data['energyType'])
              : null,
      clientType: ClientType.values.byName(data['clientType']),
      provider: Provider.values.byName(data['provider']),
      companyName: data['companyName'],
      responsibleName: data['responsibleName'] ?? '',
      nif: data['nif'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      submissionDate: (data['submissionDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'resellerId': resellerId,
      'resellerName': resellerName,
      'serviceCategory': serviceCategory.name,
      'energyType': energyType?.name,
      'clientType': clientType.name,
      'provider': provider.name,
      'companyName': companyName,
      'responsibleName': responsibleName,
      'nif': nif,
      'email': email,
      'phone': phone,
      'documentUrls': documentUrls,
      'submissionDate': Timestamp.fromDate(submissionDate),
      'status': status,
      // Add fields that might be needed for Salesforce integration
      'salesforceId': null,
      'salesforceSyncDate': null,
      'salesforceStatus': null,
    };
  }

  // Create a copy with updated fields
  ServiceSubmission copyWith({
    String? id,
    String? resellerId,
    String? resellerName,
    ServiceCategory? serviceCategory,
    EnergyType? energyType,
    ClientType? clientType,
    Provider? provider,
    String? companyName,
    String? responsibleName,
    String? nif,
    String? email,
    String? phone,
    List<String>? documentUrls,
    DateTime? submissionDate,
    String? status,
  }) {
    return ServiceSubmission(
      id: id ?? this.id,
      resellerId: resellerId ?? this.resellerId,
      resellerName: resellerName ?? this.resellerName,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      energyType: energyType ?? this.energyType,
      clientType: clientType ?? this.clientType,
      provider: provider ?? this.provider,
      companyName: companyName ?? this.companyName,
      responsibleName: responsibleName ?? this.responsibleName,
      nif: nif ?? this.nif,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      documentUrls: documentUrls ?? this.documentUrls,
      submissionDate: submissionDate ?? this.submissionDate,
      status: status ?? this.status,
    );
  }
}
