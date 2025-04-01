import 'salesforce_record.dart';

/// Salesforce Account object model
class Account extends SalesforceRecord {
  /// Account name
  final String name;

  /// Account number
  final String? accountNumber;

  /// Industry
  final String? industry;

  /// Type of account (Customer, Partner, etc.)
  final String? accountType;

  /// Annual revenue
  final double? annualRevenue;

  /// Phone number
  final String? phone;

  /// Website URL
  final String? website;

  /// Billing address components
  final String? billingStreet;
  final String? billingCity;
  final String? billingState;
  final String? billingPostalCode;
  final String? billingCountry;

  /// Description of the account
  final String? description;

  /// Number of employees
  final int? numberOfEmployees;

  /// Owner ID
  final String? ownerId;

  Account({
    required super.id,
    required this.name,
    required super.type,
    super.url,
    required super.createdDate,
    required super.lastModifiedDate,
    super.createdById,
    super.lastModifiedById,
    this.accountNumber,
    this.industry,
    this.accountType,
    this.annualRevenue,
    this.phone,
    this.website,
    this.billingStreet,
    this.billingCity,
    this.billingState,
    this.billingPostalCode,
    this.billingCountry,
    this.description,
    this.numberOfEmployees,
    this.ownerId,
  });

  /// Create from JSON map
  factory Account.fromJson(Map<String, dynamic> json) {
    final baseRecord = SalesforceRecord.fromJson(json);

    return Account(
      id: baseRecord.id,
      name: json['Name'] as String? ?? 'Unknown Account',
      type: baseRecord.type,
      url: baseRecord.url,
      createdDate: baseRecord.createdDate,
      lastModifiedDate: baseRecord.lastModifiedDate,
      createdById: baseRecord.createdById,
      lastModifiedById: baseRecord.lastModifiedById,
      accountNumber: json['AccountNumber'] as String?,
      industry: json['Industry'] as String?,
      accountType: json['Type'] as String?,
      annualRevenue:
          json['AnnualRevenue'] != null
              ? double.tryParse(json['AnnualRevenue'].toString())
              : null,
      phone: json['Phone'] as String?,
      website: json['Website'] as String?,
      billingStreet: json['BillingStreet'] as String?,
      billingCity: json['BillingCity'] as String?,
      billingState: json['BillingState'] as String?,
      billingPostalCode: json['BillingPostalCode'] as String?,
      billingCountry: json['BillingCountry'] as String?,
      description: json['Description'] as String?,
      numberOfEmployees:
          json['NumberOfEmployees'] != null
              ? int.tryParse(json['NumberOfEmployees'].toString())
              : null,
      ownerId: json['OwnerId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();

    return {
      ...baseJson,
      'Name': name,
      if (accountNumber != null) 'AccountNumber': accountNumber,
      if (industry != null) 'Industry': industry,
      if (accountType != null) 'Type': accountType,
      if (annualRevenue != null) 'AnnualRevenue': annualRevenue,
      if (phone != null) 'Phone': phone,
      if (website != null) 'Website': website,
      if (billingStreet != null) 'BillingStreet': billingStreet,
      if (billingCity != null) 'BillingCity': billingCity,
      if (billingState != null) 'BillingState': billingState,
      if (billingPostalCode != null) 'BillingPostalCode': billingPostalCode,
      if (billingCountry != null) 'BillingCountry': billingCountry,
      if (description != null) 'Description': description,
      if (numberOfEmployees != null) 'NumberOfEmployees': numberOfEmployees,
      if (ownerId != null) 'OwnerId': ownerId,
    };
  }

  factory Account.createNew({
    required String name,
    String? accountNumber,
    String? industry,
    String? accountType,
    double? annualRevenue,
    String? phone,
    String? website,
    String? billingStreet,
    String? billingCity,
    String? billingState,
    String? billingPostalCode,
    String? billingCountry,
    String? description,
    int? numberOfEmployees,
    String? ownerId,
  }) {
    final now = DateTime.now();
    return Account(
      id: '', // Empty ID as this is a new record
      type: 'Account',
      name: name,
      createdDate: now,
      lastModifiedDate: now,
      accountNumber: accountNumber,
      industry: industry,
      accountType: accountType,
      annualRevenue: annualRevenue,
      phone: phone,
      website: website,
      billingStreet: billingStreet,
      billingCity: billingCity,
      billingState: billingState,
      billingPostalCode: billingPostalCode,
      billingCountry: billingCountry,
      description: description,
      numberOfEmployees: numberOfEmployees,
      ownerId: ownerId,
    );
  }

  @override
  String toString() {
    return 'Account: $name ($id)';
  }
}
