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

  // Enhanced to support specific invoice photo metadata
  final InvoicePhoto? invoicePhoto;

  // Track review status and details
  final ReviewDetails? reviewDetails;

  // Track Salesforce synchronization
  final SalesforceSync? salesforceSync;

  // Changed to Timestamp for direct Firestore compatibility
  final Timestamp submissionTimestamp;

  // List of document URLs (e.g., for additional documents)
  final List<String>? documentUrls;

  // Status tracking submission workflow
  final String
  status; // 'pending_review', 'approved', 'rejected', 'sync_failed'

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
    this.invoicePhoto,
    this.reviewDetails,
    this.salesforceSync,
    Timestamp? submissionTimestamp,
    this.documentUrls,
    this.status = 'pending_review', // Default status changed to pending_review
  }) : this.submissionTimestamp = submissionTimestamp ?? Timestamp.now();

  // Getter for submissionDate - converts submissionTimestamp to DateTime
  DateTime get submissionDate => submissionTimestamp.toDate();

  // Create from Firestore document
  factory ServiceSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle documentUrls as a list of strings
    List<String>? documentUrls;
    if (data['documentUrls'] != null) {
      documentUrls = List<String>.from(data['documentUrls']);
    }

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
      invoicePhoto:
          data['invoicePhoto'] != null
              ? InvoicePhoto.fromMap(data['invoicePhoto'])
              : null,
      reviewDetails:
          data['reviewDetails'] != null
              ? ReviewDetails.fromMap(data['reviewDetails'])
              : null,
      salesforceSync:
          data['salesforceSync'] != null
              ? SalesforceSync.fromMap(data['salesforceSync'])
              : null,
      submissionTimestamp: data['submissionTimestamp'] ?? Timestamp.now(),
      documentUrls: documentUrls,
      status: data['status'] ?? 'pending_review',
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
      'invoicePhoto': invoicePhoto?.toMap(),
      'reviewDetails': reviewDetails?.toMap(),
      'salesforceSync': salesforceSync?.toMap(),
      'submissionTimestamp': submissionTimestamp,
      'documentUrls': documentUrls,
      'status': status,
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
    InvoicePhoto? invoicePhoto,
    ReviewDetails? reviewDetails,
    SalesforceSync? salesforceSync,
    Timestamp? submissionTimestamp,
    List<String>? documentUrls,
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
      invoicePhoto: invoicePhoto ?? this.invoicePhoto,
      reviewDetails: reviewDetails ?? this.reviewDetails,
      salesforceSync: salesforceSync ?? this.salesforceSync,
      submissionTimestamp: submissionTimestamp ?? this.submissionTimestamp,
      documentUrls: documentUrls ?? this.documentUrls,
      status: status ?? this.status,
    );
  }

  // Helper to get client details as a map (useful for Salesforce integration)
  Map<String, dynamic> getClientDetails() {
    return {
      'name': responsibleName,
      'companyName': companyName,
      'nif': nif,
      'email': email,
      'phone': phone,
      'serviceCategory': serviceCategory.name,
      'energyType': energyType?.name,
      'clientType': clientType.name,
      'provider': provider.name,
    };
  }
}

// Class to hold invoice photo metadata
class InvoicePhoto {
  final String storagePath;
  final String fileName;
  final String contentType;
  final Timestamp uploadedTimestamp;
  final String uploadedBy;

  InvoicePhoto({
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.uploadedTimestamp,
    required this.uploadedBy,
  });

  // Create from map
  factory InvoicePhoto.fromMap(Map<String, dynamic> map) {
    return InvoicePhoto(
      storagePath: map['storagePath'] ?? '',
      fileName: map['fileName'] ?? '',
      contentType: map['contentType'] ?? '',
      uploadedTimestamp: map['uploadedTimestamp'] ?? Timestamp.now(),
      uploadedBy: map['uploadedBy'] ?? '',
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'storagePath': storagePath,
      'fileName': fileName,
      'contentType': contentType,
      'uploadedTimestamp': uploadedTimestamp,
      'uploadedBy': uploadedBy,
    };
  }

  // Create a copy with updated fields
  InvoicePhoto copyWith({
    String? storagePath,
    String? fileName,
    String? contentType,
    Timestamp? uploadedTimestamp,
    String? uploadedBy,
  }) {
    return InvoicePhoto(
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
      uploadedTimestamp: uploadedTimestamp ?? this.uploadedTimestamp,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }
}

// Class to hold review details
class ReviewDetails {
  final String reviewerId;
  final Timestamp reviewTimestamp;
  final String? notes;

  ReviewDetails({
    required this.reviewerId,
    required this.reviewTimestamp,
    this.notes,
  });

  // Create from map
  factory ReviewDetails.fromMap(Map<String, dynamic> map) {
    return ReviewDetails(
      reviewerId: map['reviewerId'] ?? '',
      reviewTimestamp: map['reviewTimestamp'] ?? Timestamp.now(),
      notes: map['notes'],
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'reviewerId': reviewerId,
      'reviewTimestamp': reviewTimestamp,
      'notes': notes,
    };
  }

  // Create a copy with updated fields
  ReviewDetails copyWith({
    String? reviewerId,
    Timestamp? reviewTimestamp,
    String? notes,
  }) {
    return ReviewDetails(
      reviewerId: reviewerId ?? this.reviewerId,
      reviewTimestamp: reviewTimestamp ?? this.reviewTimestamp,
      notes: notes ?? this.notes,
    );
  }
}

// Class to hold Salesforce sync details
class SalesforceSync {
  final String status; // 'pending', 'synced', 'failed'
  final Timestamp syncTimestamp;
  final String? salesforceRecordId;
  final String? errorMessage;

  SalesforceSync({
    required this.status,
    required this.syncTimestamp,
    this.salesforceRecordId,
    this.errorMessage,
  });

  // Create from map
  factory SalesforceSync.fromMap(Map<String, dynamic> map) {
    return SalesforceSync(
      status: map['status'] ?? 'pending',
      syncTimestamp: map['syncTimestamp'] ?? Timestamp.now(),
      salesforceRecordId: map['salesforceRecordId'],
      errorMessage: map['errorMessage'],
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'syncTimestamp': syncTimestamp,
      'salesforceRecordId': salesforceRecordId,
      'errorMessage': errorMessage,
    };
  }

  // Create a copy with updated fields
  SalesforceSync copyWith({
    String? status,
    Timestamp? syncTimestamp,
    String? salesforceRecordId,
    String? errorMessage,
  }) {
    return SalesforceSync(
      status: status ?? this.status,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      salesforceRecordId: salesforceRecordId ?? this.salesforceRecordId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
